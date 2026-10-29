const std = @import("std");

pub const TICKS_PER_SECOND: u32 = 20;
pub const WARDEN_MAX_HEALTH: f32 = 500.0;
pub const WARDEN_MELEE_DAMAGE: f32 = 30.0;
pub const WARDEN_HOSTILE_SPEED: f32 = 4.2;
pub const WARDEN_SNIFF_RANGE: f32 = 16.0;
pub const WARDEN_SNIFF_INTERVAL_TICKS: u32 = 100;
pub const WARDEN_OPTICAL_SIGHT_RANGE: f32 = 0.0;
pub const VIBRATION_AGITATION: u16 = 35;
pub const ROAR_AGITATION_THRESHOLD: u16 = 80;
pub const HOSTILE_AGITATION_THRESHOLD: u16 = 150;
pub const EMERGENCE_TICKS: u32 = 134;
pub const CALM_BURROW_TICKS: u32 = 1200;
pub const SONIC_BOOM_RANGE: f32 = 15.0;
pub const SONIC_BOOM_DAMAGE: f32 = 10.0;
pub const SONIC_BOOM_CHARGE_TICKS: u32 = 34;
pub const SONIC_BOOM_COOLDOWN_TICKS: u32 = 100;
pub const SONIC_BOOM_VERTICAL_IMPULSE: f32 = 6.0;
pub const SONIC_BOOM_HORIZONTAL_IMPULSE: f32 = 8.0;
pub const DARKNESS_RADIUS: f32 = 20.0;
pub const DARKNESS_PULSE_TICKS: u32 = 120;
pub const MELEE_RANGE: f32 = 3.0;

pub const Position = struct { x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0 };

pub fn distance(a: Position, b: Position) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const dz = a.z - b.z;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

pub const SonicBoomImpulse = struct { vx: f32, vy: f32, vz: f32 };

/// The beam passes through blocks and bypasses armor and shields. Direction is
/// computed from Warden to target; a coincident target receives a vertical lift.
pub fn sonicBoomImpulse(warden: Position, target: Position) SonicBoomImpulse {
    const dx = target.x - warden.x;
    const dz = target.z - warden.z;
    const horizontal = @sqrt(dx * dx + dz * dz);
    if (horizontal <= 0.0001) return .{ .vx = 0.0, .vy = SONIC_BOOM_VERTICAL_IMPULSE, .vz = 0.0 };
    return .{
        .vx = dx / horizontal * SONIC_BOOM_HORIZONTAL_IMPULSE,
        .vy = SONIC_BOOM_VERTICAL_IMPULSE,
        .vz = dz / horizontal * SONIC_BOOM_HORIZONTAL_IMPULSE,
    };
}

pub const Warden = struct {
    position: Position = .{},
    health: f32 = WARDEN_MAX_HEALTH,
    agitation: u16 = 0,
    is_emerging: bool = true,
    emergence_ticks_remaining: u32 = EMERGENCE_TICKS,
    is_burrowing: bool = false,
    despawned: bool = false,
    hostile: bool = false,
    roaring: bool = false,
    tracked_target: bool = false,
    calm_ticks: u32 = 0,
    sniff_ticks: u32 = 0,
    boom_charge_ticks: u32 = 0,
    boom_cooldown_ticks: u32 = 0,
    darkness_ticks: u32 = DARKNESS_PULSE_TICKS,
    darkness_pulsed: bool = false,

    pub fn init(position: Position) Warden {
        return .{ .position = position };
    }

    pub fn movementSpeed(self: Warden) f32 {
        return if (self.hostile) WARDEN_HOSTILE_SPEED else 0.0;
    }

    /// Emergence is invulnerable, and burrowing/despawned Wardens cannot be hit.
    pub fn takeDamage(self: *Warden, amount: f32) f32 {
        if (self.is_emerging or self.is_burrowing or self.despawned or amount <= 0.0) return 0.0;
        const dealt = @min(amount, self.health);
        self.health -= dealt;
        return dealt;
    }

    fn resetCalm(self: *Warden) void {
        self.calm_ticks = 0;
        self.tracked_target = true;
    }

    pub fn hearVibration(self: *Warden) void {
        if (self.despawned) return;
        self.resetCalm();
        self.agitation = @min(HOSTILE_AGITATION_THRESHOLD, self.agitation + VIBRATION_AGITATION);
        self.roaring = self.agitation >= ROAR_AGITATION_THRESHOLD;
        self.hostile = self.agitation >= HOSTILE_AGITATION_THRESHOLD;
    }

    /// Scent is a periodic, omnidirectional target sense within 16m. It locates
    /// and keeps the target active without changing the vibration agitation score.
    pub fn sniffTarget(self: *Warden, target: Position) bool {
        if (distance(self.position, target) > WARDEN_SNIFF_RANGE) return false;
        self.resetCalm();
        return true;
    }

    pub fn canStartSonicBoom(self: Warden, target: Position) bool {
        const range = distance(self.position, target);
        return !self.is_emerging and !self.is_burrowing and !self.despawned and
            self.hostile and range > MELEE_RANGE and range <= SONIC_BOOM_RANGE and
            self.boom_charge_ticks == 0 and self.boom_cooldown_ticks == 0;
    }

    /// Advances fixed 20Hz simulation. The return value reports a newly fired
    /// boom; when a target remains eligible it charges for 34 ticks first.
    pub fn tick(self: *Warden, target: ?Position) bool {
        if (self.despawned) return false;
        self.darkness_pulsed = false;
        var just_emerged = false;
        if (self.is_emerging) {
            if (self.emergence_ticks_remaining > 0) self.emergence_ticks_remaining -= 1;
            if (self.emergence_ticks_remaining == 0) {
                self.is_emerging = false;
                just_emerged = true;
            }
        }

        if (self.boom_cooldown_ticks > 0) self.boom_cooldown_ticks -= 1;
        var fired = false;
        if (self.boom_charge_ticks > 0) {
            self.boom_charge_ticks -= 1;
            if (self.boom_charge_ticks == 0) {
                self.boom_cooldown_ticks = SONIC_BOOM_COOLDOWN_TICKS;
                fired = true;
            }
        } else if (target) |player| {
            if (self.canStartSonicBoom(player)) self.boom_charge_ticks = SONIC_BOOM_CHARGE_TICKS;
        }

        if (self.darkness_ticks > 0) self.darkness_ticks -= 1;
        if (self.darkness_ticks == 0) {
            self.darkness_pulsed = true;
            self.darkness_ticks = DARKNESS_PULSE_TICKS;
        }

        self.sniff_ticks += 1;
        if (self.sniff_ticks >= WARDEN_SNIFF_INTERVAL_TICKS) {
            self.sniff_ticks = 0;
            if (target) |player| _ = self.sniffTarget(player);
        }

        if (!just_emerged and !self.is_emerging and self.agitation == 0 and !self.tracked_target) {
            self.calm_ticks += 1;
            if (self.calm_ticks >= CALM_BURROW_TICKS) {
                self.is_burrowing = true;
                self.despawned = true;
            }
        }
        self.tracked_target = false;
        return fired;
    }

    pub fn darknessAffects(self: Warden, player: Position) bool {
        return distance(self.position, player) <= DARKNESS_RADIUS;
    }

    pub fn emitsDarknessTo(self: Warden, player: Position) bool {
        return self.darkness_pulsed and self.darknessAffects(player);
    }
};

pub const BoomResult = struct { hit: bool, damage: f32, impulse: SonicBoomImpulse };

pub const PlayerCombatState = struct {
    health: f32 = 20.0,
    armor_points: f32 = 0.0,
    shield_blocking: bool = false,
    velocity: SonicBoomImpulse = .{ .vx = 0.0, .vy = 0.0, .vz = 0.0 },
};

pub fn resolveSonicBoom(warden: Position, target: Position) BoomResult {
    if (distance(warden, target) > SONIC_BOOM_RANGE) return .{
        .hit = false,
        .damage = 0.0,
        .impulse = .{ .vx = 0.0, .vy = 0.0, .vz = 0.0 },
    };
    return .{ .hit = true, .damage = SONIC_BOOM_DAMAGE, .impulse = sonicBoomImpulse(warden, target) };
}

/// Applies a valid beam hit directly, deliberately ignoring armor and shield state.
pub fn hitPlayerWithSonicBoom(warden: Position, target: Position, player: *PlayerCombatState) bool {
    const result = resolveSonicBoom(warden, target);
    if (!result.hit) return false;
    player.health = @max(0.0, player.health - result.damage);
    player.velocity = result.impulse;
    return true;
}

test "attributes specify 500 health and 30 melee damage" {
    const w = Warden.init(.{});
    try std.testing.expectEqual(@as(f32, 500.0), w.health);
    try std.testing.expectEqual(@as(f32, 500.0), WARDEN_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 30.0), WARDEN_MELEE_DAMAGE);
    try std.testing.expectEqual(@as(f32, 0.0), WARDEN_OPTICAL_SIGHT_RANGE);
}

test "vibration adds 35 agitation" {
    var w = Warden.init(.{});
    w.hearVibration();
    try std.testing.expectEqual(@as(u16, 35), w.agitation);
}
test "second vibration remains below roar threshold" {
    var w = Warden.init(.{});
    w.hearVibration();
    w.hearVibration();
    try std.testing.expect(!w.roaring);
}
test "roaring starts at exact 80 agitation threshold" {
    var w = Warden.init(.{});
    w.agitation = 79;
    w.hearVibration();
    try std.testing.expect(w.roaring);
}
test "fifth vibration reaches hostile chase at 150" {
    var w = Warden.init(.{});
    for (0..4) |_| w.hearVibration();
    try std.testing.expectEqual(@as(u16, 140), w.agitation);
    try std.testing.expect(!w.hostile);
    w.hearVibration();
    try std.testing.expectEqual(@as(u16, 150), w.agitation);
    try std.testing.expect(w.hostile);
}
test "agitation caps at 150" {
    var w = Warden.init(.{});
    for (0..8) |_| w.hearVibration();
    try std.testing.expectEqual(@as(u16, 150), w.agitation);
}
test "hostile movement speed is 4.2 meters per second" {
    var w = Warden.init(.{});
    w.hostile = true;
    try std.testing.expectEqual(@as(f32, 4.2), w.movementSpeed());
}
test "calm Warden has no hostile chase speed" {
    const w = Warden.init(.{});
    try std.testing.expectEqual(@as(f32, 0.0), w.movementSpeed());
}
test "emergence lasts exactly 134 ticks" {
    var w = Warden.init(.{});
    for (0..133) |_| _ = w.tick(null);
    try std.testing.expect(w.is_emerging);
    _ = w.tick(null);
    try std.testing.expect(!w.is_emerging);
}
test "emerging Warden is invulnerable" {
    var w = Warden.init(.{});
    try std.testing.expectEqual(@as(f32, 0.0), w.takeDamage(100));
    try std.testing.expectEqual(@as(f32, 500.0), w.health);
}
test "emergence damage works after the final tick" {
    var w = Warden.init(.{});
    for (0..134) |_| _ = w.tick(null);
    try std.testing.expectEqual(@as(f32, 10.0), w.takeDamage(10));
}
test "calm burrowing begins at 1200 quiet ticks" {
    var w = Warden.init(.{});
    for (0..134) |_| _ = w.tick(null);
    for (0..1199) |_| _ = w.tick(null);
    try std.testing.expect(!w.despawned);
    _ = w.tick(null);
    try std.testing.expect(w.is_burrowing);
    try std.testing.expect(w.despawned);
}
test "vibration resets calm despawn countdown" {
    var w = Warden.init(.{});
    for (0..134) |_| _ = w.tick(null);
    for (0..1100) |_| _ = w.tick(null);
    w.hearVibration();
    for (0..200) |_| _ = w.tick(null);
    try std.testing.expect(!w.despawned);
}
test "scent detection finds target at 16m" {
    var w = Warden.init(.{});
    try std.testing.expect(w.sniffTarget(.{ .x = 16 }));
}
test "scent detection rejects target beyond 16m" {
    var w = Warden.init(.{});
    try std.testing.expect(!w.sniffTarget(.{ .x = 16.01 }));
}
test "scent tracking resets calm countdown without adding agitation" {
    var w = Warden.init(.{});
    w.calm_ticks = 100;
    try std.testing.expect(w.sniffTarget(.{ .x = 4 }));
    try std.testing.expectEqual(@as(u32, 0), w.calm_ticks);
    try std.testing.expectEqual(@as(u16, 0), w.agitation);
}
test "periodic sniff detects nearby target" {
    var w = Warden.init(.{});
    for (0..100) |_| _ = w.tick(.{ .x = 8 });
    try std.testing.expectEqual(@as(u32, 0), w.calm_ticks);
}
test "sonic boom reaches exact 15m boundary" {
    const r = resolveSonicBoom(.{}, .{ .x = 15 });
    try std.testing.expect(r.hit);
}
test "sonic boom rejects target beyond 15m" {
    const r = resolveSonicBoom(.{}, .{ .x = 15.001 });
    try std.testing.expect(!r.hit);
}
test "sonic boom deals ten unmitigated damage through armor and shield" {
    var player = PlayerCombatState{ .health = 20, .armor_points = 20, .shield_blocking = true };
    try std.testing.expect(hitPlayerWithSonicBoom(.{}, .{ .x = 5 }, &player));
    try std.testing.expectEqual(@as(f32, 10), player.health);
}
test "sonic boom attack can target elevated players within spherical range" {
    const r = resolveSonicBoom(.{}, .{ .y = 14 });
    try std.testing.expect(r.hit);
}
test "sonic boom does not start within melee range" {
    var w = Warden.init(.{});
    w.is_emerging = false;
    w.hostile = true;
    try std.testing.expect(!w.canStartSonicBoom(.{ .x = 2 }));
}
test "sonic boom requires hostile state" {
    var w = Warden.init(.{});
    w.is_emerging = false;
    try std.testing.expect(!w.canStartSonicBoom(.{ .x = 8 }));
}
test "sonic boom requires a completed emergence" {
    var w = Warden.init(.{});
    w.hostile = true;
    try std.testing.expect(!w.canStartSonicBoom(.{ .x = 8 }));
}
test "sonic boom charge lasts exactly 34 ticks then fires" {
    var w = Warden.init(.{});
    w.is_emerging = false;
    w.hostile = true;
    const target = Position{ .x = 8 };
    try std.testing.expect(!w.tick(target));
    try std.testing.expectEqual(@as(u32, 34), w.boom_charge_ticks);
    for (0..33) |_| try std.testing.expect(!w.tick(null));
    try std.testing.expect(w.tick(null));
}
test "sonic boom cooldown lasts 100 ticks" {
    var w = Warden.init(.{});
    w.is_emerging = false;
    w.hostile = true;
    _ = w.tick(.{ .x = 8 });
    for (0..34) |_| _ = w.tick(null);
    try std.testing.expectEqual(@as(u32, 100), w.boom_cooldown_ticks);
    for (0..99) |_| _ = w.tick(.{ .x = 8 });
    try std.testing.expectEqual(@as(u32, 1), w.boom_cooldown_ticks);
    _ = w.tick(.{ .x = 8 });
    try std.testing.expectEqual(@as(u32, 0), w.boom_cooldown_ticks);
}
test "sonic boom applies upward velocity impulse of six" {
    const i = sonicBoomImpulse(.{}, .{ .x = 1 });
    try std.testing.expectEqual(@as(f32, 6), i.vy);
}
test "sonic boom applies horizontal push of eight along positive X" {
    const i = sonicBoomImpulse(.{}, .{ .x = 3 });
    try std.testing.expectEqual(@as(f32, 8), i.vx);
    try std.testing.expectEqual(@as(f32, 0), i.vz);
}
test "sonic boom horizontal push follows diagonal target direction" {
    const i = sonicBoomImpulse(.{}, .{ .x = 3, .z = 4 });
    try std.testing.expectApproxEqAbs(@as(f32, 4.8), i.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.4), i.vz, 0.001);
}
test "sonic boom coincident target still receives upward impulse" {
    const i = sonicBoomImpulse(.{}, .{});
    try std.testing.expectEqual(@as(f32, 6), i.vy);
}
test "darkness aura includes player at 20m boundary" {
    const w = Warden.init(.{});
    try std.testing.expect(w.darknessAffects(.{ .z = 20 }));
}
test "darkness aura excludes player beyond 20m" {
    const w = Warden.init(.{});
    try std.testing.expect(!w.darknessAffects(.{ .z = 20.01 }));
}
test "darkness pulse emits effect to nearby player only during pulse" {
    var w = Warden.init(.{});
    try std.testing.expect(!w.emitsDarknessTo(.{ .x = 2 }));
    for (0..120) |_| _ = w.tick(null);
    try std.testing.expect(w.emitsDarknessTo(.{ .x = 2 }));
    try std.testing.expect(!w.emitsDarknessTo(.{ .x = 21 }));
}
test "darkness pulse is emitted every 120 ticks" {
    var w = Warden.init(.{});
    for (0..119) |_| {
        _ = w.tick(null);
        try std.testing.expect(!w.darkness_pulsed);
    }
    _ = w.tick(null);
    try std.testing.expect(w.darkness_pulsed);
    try std.testing.expectEqual(@as(u32, 120), w.darkness_ticks);
}
test "burrowing Warden ignores damage" {
    var w = Warden.init(.{});
    w.is_emerging = false;
    w.is_burrowing = true;
    try std.testing.expectEqual(@as(f32, 0), w.takeDamage(50));
}
test "despawned Warden cannot be reactivated by a later vibration" {
    var w = Warden.init(.{});
    w.despawned = true;
    w.is_burrowing = true;
    w.hearVibration();
    try std.testing.expect(w.despawned);
    try std.testing.expectEqual(@as(u16, 0), w.agitation);
}
test "damage clamps health at zero" {
    var w = Warden.init(.{});
    w.is_emerging = false;
    try std.testing.expectEqual(@as(f32, 500), w.takeDamage(900));
    try std.testing.expectEqual(@as(f32, 0), w.health);
}
