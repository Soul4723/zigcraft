const std = @import("std");

pub const TICKS_PER_SECOND: u32 = 20;
pub const SHRIEK_COOLDOWN_TICKS: u32 = 200;
pub const WARNING_DECAY_TICKS: u32 = 12_000;
pub const DARKNESS_RADIUS: f32 = 40.0;
pub const DARKNESS_RADIUS_SQ: f32 = DARKNESS_RADIUS * DARKNESS_RADIUS;
pub const DARKNESS_DURATION_TICKS: u32 = 240;
pub const FOG_PERIOD_TICKS: u32 = 80;
pub const WARDEN_EMERGENCE_TICKS: u32 = 134;
pub const MAX_WARNING_LEVEL: u8 = 4;

pub const Position = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn distanceSquared(a: Position, b: Position) f32 {
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const dz = a.z - b.z;
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn distance(a: Position, b: Position) f32 {
        return @sqrt(distanceSquared(a, b));
    }
};

pub const FogDistances = struct { start: f32, end: f32 };

/// Returns a repeating clear-to-gloom-to-clear sine envelope over four seconds.
/// `elapsed_ticks` is relative to the most recent shrieker activation.
pub fn fogIntensity(elapsed_ticks: u32) f32 {
    const phase_ticks = elapsed_ticks % FOG_PERIOD_TICKS;
    const phase = @as(f32, @floatFromInt(phase_ticks)) * (2.0 * std.math.pi / @as(f32, @floatFromInt(FOG_PERIOD_TICKS)));
    return 0.5 - 0.5 * @cos(phase);
}

/// Interpolates between clear vision (25m/35m) and blinding gloom (2m/6m).
pub fn fogDistances(intensity: f32) FogDistances {
    const t = std.math.clamp(intensity, 0.0, 1.0);
    return .{ .start = 25.0 + (2.0 - 25.0) * t, .end = 35.0 + (6.0 - 35.0) * t };
}

pub const Player = struct {
    id: u32,
    position: Position = .{},
    warning_level: u8 = 0,
    calm_ticks: u32 = 0,
    darkness_ticks_remaining: u32 = 0,

    pub fn init(id: u32, position: Position) Player {
        return .{ .id = id, .position = position };
    }

    pub fn tick(self: *Player, ticks: u32) void {
        self.darkness_ticks_remaining -|= ticks;
        if (self.warning_level == 0) {
            self.calm_ticks = 0;
            return;
        }
        var remaining = ticks;
        while (remaining > 0 and self.warning_level > 0) {
            const until_decay = WARNING_DECAY_TICKS - self.calm_ticks;
            if (remaining < until_decay) {
                self.calm_ticks += remaining;
                return;
            }
            remaining -= until_decay;
            self.warning_level -= 1;
            self.calm_ticks = 0;
        }
    }

    pub fn darknessActive(self: Player) bool {
        return self.darkness_ticks_remaining > 0;
    }

    pub fn currentFog(self: Player) FogDistances {
        if (!self.darknessActive()) return fogDistances(0.0);
        return fogDistances(fogIntensity(DARKNESS_DURATION_TICKS - self.darkness_ticks_remaining));
    }
};

pub const WardenEmergence = struct {
    position: Position,
    is_emerging: bool = true,
    ticks_remaining: u32 = WARDEN_EMERGENCE_TICKS,

    pub fn tick(self: *WardenEmergence, ticks: u32) void {
        self.ticks_remaining -|= ticks;
        if (self.ticks_remaining == 0) self.is_emerging = false;
    }
};

pub const Activation = struct {
    activated: bool = false,
    warning_level: u8 = 0,
    affected_players: u32 = 0,
    summon_warden: bool = false,
    emergence: ?WardenEmergence = null,
};

/// One shrieker owns its independent 200-tick reactivation cooldown.
pub const SculkShrieker = struct {
    position: Position,
    can_summon: bool,
    cooldown_ticks_remaining: u32 = 0,

    pub fn init(position: Position, can_summon: bool) SculkShrieker {
        return .{ .position = position, .can_summon = can_summon };
    }

    pub fn tick(self: *SculkShrieker, ticks: u32) void {
        self.cooldown_ticks_remaining -|= ticks;
    }

    /// A valid activation pulses darkness for nearby players. Only a natural
    /// shrieker advances warning tiers or creates an emergence event.
    pub fn activate(self: *SculkShrieker, player: *Player, players: []Player) Activation {
        if (self.cooldown_ticks_remaining != 0) return .{ .warning_level = player.warning_level };

        self.cooldown_ticks_remaining = SHRIEK_COOLDOWN_TICKS;
        player.calm_ticks = 0;
        var result = Activation{ .activated = true, .warning_level = player.warning_level };
        for (players) |*nearby| {
            if (Position.distanceSquared(self.position, nearby.position) <= DARKNESS_RADIUS_SQ) {
                nearby.darkness_ticks_remaining = DARKNESS_DURATION_TICKS;
                result.affected_players += 1;
            }
        }
        // The activating player may be represented by a separate tracker in the
        // caller's slice; ensure they receive the aura in either arrangement.
        if (Position.distanceSquared(self.position, player.position) <= DARKNESS_RADIUS_SQ) {
            player.darkness_ticks_remaining = DARKNESS_DURATION_TICKS;
            var found_player = false;
            for (players) |nearby| if (nearby.id == player.id) {
                found_player = true;
            };
            if (!found_player) result.affected_players += 1;
        }

        if (self.can_summon) {
            const previous_warning_level = player.warning_level;
            if (player.warning_level < MAX_WARNING_LEVEL) player.warning_level += 1;
            result.warning_level = player.warning_level;
            if (previous_warning_level == MAX_WARNING_LEVEL - 1 and player.warning_level == MAX_WARNING_LEVEL) {
                result.summon_warden = true;
                result.emergence = .{ .position = self.position };
            }
        }
        return result;
    }
};

test "1. constants encode requested tick durations and radius" {
    try std.testing.expectEqual(@as(u32, 20), TICKS_PER_SECOND);
    try std.testing.expectEqual(@as(u32, 200), SHRIEK_COOLDOWN_TICKS);
    try std.testing.expectEqual(@as(u32, 12_000), WARNING_DECAY_TICKS);
    try std.testing.expectEqual(@as(u32, 240), DARKNESS_DURATION_TICKS);
    try std.testing.expectEqual(@as(u32, 80), FOG_PERIOD_TICKS);
    try std.testing.expectEqual(@as(u32, 134), WARDEN_EMERGENCE_TICKS);
    try std.testing.expectEqual(@as(f32, 40.0), DARKNESS_RADIUS);
}

test "2. position distance is three dimensional Euclidean distance" {
    try std.testing.expectEqual(@as(f32, 13.0), Position.distance(.{}, .{ .x = 3, .y = 4, .z = 12 }));
}

test "3. natural shrieker increments warning from zero to one" {
    var p = Player.init(1, .{});
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expect(a.activated);
    try std.testing.expectEqual(@as(u8, 1), p.warning_level);
}

test "4. natural warning escalation reaches tier two" {
    var p = Player.init(1, .{});
    p.warning_level = 1;
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u8, 2), p.warning_level);
}

test "5. natural warning escalation reaches tier three" {
    var p = Player.init(1, .{});
    p.warning_level = 2;
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u8, 3), p.warning_level);
}

test "6. natural warning escalation reaches tier four and summons" {
    var p = Player.init(1, .{});
    p.warning_level = 3;
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u8, 4), p.warning_level);
    try std.testing.expect(a.summon_warden);
}

test "7. natural warning level caps at four" {
    var p = Player.init(1, .{});
    p.warning_level = 4;
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u8, 4), p.warning_level);
}

test "8. placed shrieker leaves warning and summon state unchanged" {
    var p = Player.init(1, .{});
    p.warning_level = 3;
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, false);
    const a = s.activate(&p, &ps);
    try std.testing.expect(a.activated);
    try std.testing.expectEqual(@as(u8, 3), p.warning_level);
    try std.testing.expect(!a.summon_warden);
}

test "9. placed shrieker at tier four never summons" {
    var p = Player.init(1, .{});
    p.warning_level = 4;
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, false);
    const a = s.activate(&p, &ps);
    try std.testing.expect(!a.summon_warden);
    try std.testing.expect(a.emergence == null);
}

test "10. activation starts exact 200 tick cooldown" {
    var p = Player.init(1, .{});
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 200), s.cooldown_ticks_remaining);
}

test "11. cooldown rejects retrigger before 200 ticks" {
    var p = Player.init(1, .{});
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    s.tick(199);
    const a = s.activate(&p, &ps);
    try std.testing.expect(!a.activated);
    try std.testing.expectEqual(@as(u8, 1), p.warning_level);
}

test "12. cooldown permits retrigger at exactly 200 ticks" {
    var p = Player.init(1, .{});
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    s.tick(200);
    try std.testing.expect((s.activate(&p, &ps)).activated);
    try std.testing.expectEqual(@as(u8, 2), p.warning_level);
}

test "13. calm decay does not occur before 12000 ticks" {
    var p = Player.init(1, .{});
    p.warning_level = 2;
    p.tick(11_999);
    try std.testing.expectEqual(@as(u8, 2), p.warning_level);
}

test "14. calm decay removes one tier after 12000 ticks" {
    var p = Player.init(1, .{});
    p.warning_level = 2;
    p.tick(12_000);
    try std.testing.expectEqual(@as(u8, 1), p.warning_level);
    try std.testing.expectEqual(@as(u32, 0), p.calm_ticks);
}

test "15. calm decay applies one tier per additional ten minutes" {
    var p = Player.init(1, .{});
    p.warning_level = 4;
    p.tick(36_000);
    try std.testing.expectEqual(@as(u8, 1), p.warning_level);
}

test "16. activation resets calm timer" {
    var p = Player.init(1, .{});
    p.warning_level = 2;
    p.tick(11_000);
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 0), p.calm_ticks);
}

test "17. darkness aura includes player at the shrieker" {
    var p = Player.init(1, .{});
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 1), a.affected_players);
    try std.testing.expectEqual(@as(u32, 240), p.darkness_ticks_remaining);
}

test "18. darkness radius includes exact 40 meter boundary" {
    var p = Player.init(1, .{ .x = 40.0 });
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 1), a.affected_players);
}

test "19. darkness radius excludes player just outside 40 meters" {
    var p = Player.init(1, .{ .x = 40.01 });
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 0), a.affected_players);
    try std.testing.expect(!p.darknessActive());
}

test "20. darkness radius uses vertical distance" {
    var p = Player.init(1, .{ .y = 40.0 });
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    try std.testing.expectEqual(@as(u32, 1), (s.activate(&p, &ps)).affected_players);
}

test "21. all nearby players receive the darkness pulse" {
    var p = Player.init(1, .{});
    var ps = [_]Player{ p, Player.init(2, .{ .x = 39.0 }), Player.init(3, .{ .x = 41.0 }) };
    var s = SculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 2), a.affected_players);
    try std.testing.expect(ps[1].darknessActive());
    try std.testing.expect(!ps[2].darknessActive());
}

test "22. placed shrieker activation still pulses darkness aura" {
    var p = Player.init(1, .{});
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, false);
    const a = s.activate(&p, &ps);
    try std.testing.expect(a.activated);
    try std.testing.expect(p.darknessActive());
}

test "23. darkness lasts exactly 240 game ticks" {
    var p = Player.init(1, .{});
    p.darkness_ticks_remaining = 240;
    p.tick(239);
    try std.testing.expect(p.darknessActive());
    p.tick(1);
    try std.testing.expect(!p.darknessActive());
}

test "24. fog starts clear at pulse onset" {
    const fog = fogDistances(fogIntensity(0));
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), fog.start, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 35.0), fog.end, 0.0001);
}

test "25. fog reaches blinding values after two seconds" {
    const fog = fogDistances(fogIntensity(40));
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), fog.start, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), fog.end, 0.0001);
}

test "26. fog clears after one complete four second wave" {
    try std.testing.expectApproxEqAbs(fogIntensity(0), fogIntensity(80), 0.0001);
    const fog = fogDistances(fogIntensity(80));
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), fog.start, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 35.0), fog.end, 0.0001);
}

test "27. fog sine wave interpolates smoothly at quarter period" {
    const low = fogDistances(fogIntensity(0));
    const mid = fogDistances(fogIntensity(20));
    const high = fogDistances(fogIntensity(40));
    try std.testing.expect(mid.start < low.start and mid.start > high.start);
    try std.testing.expect(mid.end < low.end and mid.end > high.end);
}

test "28. fog interpolation clamps intensity to the supported range" {
    try std.testing.expectEqual(fogDistances(0), fogDistances(-2));
    try std.testing.expectEqual(fogDistances(1), fogDistances(2));
}

test "29. fog defaults to clear when darkness expires" {
    var p = Player.init(1, .{});
    p.darkness_ticks_remaining = 1;
    p.tick(1);
    const fog = p.currentFog();
    try std.testing.expectEqual(@as(f32, 25.0), fog.start);
    try std.testing.expectEqual(@as(f32, 35.0), fog.end);
}

test "30. tier four activation returns an emerging Warden for 134 ticks" {
    var p = Player.init(1, .{});
    p.warning_level = 3;
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{ .x = 1.5, .y = -20.0, .z = 2.5 }, true);
    const a = s.activate(&p, &ps);
    try std.testing.expect(a.summon_warden);
    const warden = a.emergence.?;
    try std.testing.expect(warden.is_emerging);
    try std.testing.expectEqual(@as(u32, 134), warden.ticks_remaining);
    try std.testing.expectEqual(s.position, warden.position);
}

test "31. Warden emergence completes after exactly 134 ticks" {
    var w = WardenEmergence{ .position = .{} };
    w.tick(133);
    try std.testing.expect(w.is_emerging);
    w.tick(1);
    try std.testing.expect(!w.is_emerging);
    try std.testing.expectEqual(@as(u32, 0), w.ticks_remaining);
}

test "32. tier four already reached does not repeatedly summon" {
    var p = Player.init(1, .{});
    p.warning_level = 4;
    var ps = [_]Player{p};
    var s = SculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expect(!a.summon_warden);
    try std.testing.expectEqual(@as(u8, 4), p.warning_level);
}

test "33. separate shriekers keep independent cooldowns" {
    var p = Player.init(1, .{});
    var ps = [_]Player{p};
    var a = SculkShrieker.init(.{}, true);
    var b = SculkShrieker.init(.{ .x = 2 }, true);
    _ = a.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 200), a.cooldown_ticks_remaining);
    try std.testing.expectEqual(@as(u32, 0), b.cooldown_ticks_remaining);
    try std.testing.expect((b.activate(&p, &ps)).activated);
}

test "34. warning trackers decay independently per player" {
    var a = Player.init(1, .{});
    var b = Player.init(2, .{});
    a.warning_level = 3;
    b.warning_level = 1;
    a.tick(12_000);
    b.tick(6_000);
    try std.testing.expectEqual(@as(u8, 2), a.warning_level);
    try std.testing.expectEqual(@as(u8, 1), b.warning_level);
}
