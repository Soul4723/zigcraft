const std = @import("std");

pub const TICKS_PER_SECOND: u32 = 20;
pub const SCENT_RANGE: f32 = 16.0;
pub const SCENT_INTERVAL_TICKS: u32 = 84;
pub const SCENT_SUSPICION: u16 = 35;
pub const CALM_SUSPICION_LIMIT: u16 = 40;
pub const ROAR_SUSPICION_LIMIT: u16 = 80;
pub const CHASE_SUSPICION_LIMIT: u16 = 150;
pub const ROAR_DURATION_TICKS: u32 = 40;
pub const CALM_DECAY_INTERVAL_TICKS: u32 = 20;
pub const CALM_WANDER_SPEED: f32 = 1.0;
pub const CHASE_SPEED: f32 = 4.2;
pub const SONIC_BLAST_REACH: f32 = 15.0;
pub const SONIC_BLAST_DAMAGE: f32 = 10.0;
pub const SONIC_BLAST_VERTICAL_KNOCKBACK: f32 = 6.0;
pub const SONIC_BLAST_HORIZONTAL_KNOCKBACK: f32 = 8.0;

pub const Position = struct { x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0 };

pub fn distance(a: Position, b: Position) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const dz = a.z - b.z;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

pub const Player = struct {
    id: u32,
    position: Position = .{},
    suspicion: u16 = 0,
    health: f32 = 20.0,
    armor_points: f32 = 0.0,
    shield_blocking: bool = false,
    velocity: Velocity = .{},
};

pub const Velocity = struct { x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0 };

pub const State = enum { calm, agitated, roaring, chasing };

pub const TickEvents = struct {
    sniff_animation: bool = false,
    sniffed_player_id: ?u32 = null,
    roar_started: bool = false,
    turned_toward_player_id: ?u32 = null,
};

pub const Warden = struct {
    position: Position = .{},
    state: State = .calm,
    target_player_id: ?u32 = null,
    sniff_ticks: u32 = 0,
    calm_decay_ticks: u32 = 0,
    roar_ticks_remaining: u32 = 0,
    heard_vibration_this_tick: bool = false,

    pub fn init(position: Position) Warden {
        return .{ .position = position };
    }

    pub fn movementSpeed(self: Warden) f32 {
        return switch (self.state) {
            .calm => CALM_WANDER_SPEED,
            .agitated, .roaring => 0.0,
            .chasing => CHASE_SPEED,
        };
    }

    pub fn isChasing(self: Warden) bool {
        return self.state == .chasing;
    }

    /// A vibration identifies its source and raises that player's suspicion by
    /// the caller-supplied amount. Sniffing independently contributes 35 points.
    pub fn hearVibration(self: *Warden, player: *Player, suspicion: u16) void {
        player.suspicion = @min(std.math.maxInt(u16), player.suspicion +| suspicion);
        self.target_player_id = player.id;
        self.heard_vibration_this_tick = true;
        self.refreshState(player);
    }

    fn refreshState(self: *Warden, player: *Player) void {
        if (player.suspicion >= CHASE_SUSPICION_LIMIT) {
            self.state = .chasing;
            self.target_player_id = player.id;
            self.roar_ticks_remaining = 0;
        } else if (player.suspicion >= ROAR_SUSPICION_LIMIT) {
            if (self.state != .roaring) {
                self.state = .roaring;
                self.roar_ticks_remaining = ROAR_DURATION_TICKS;
            }
            self.target_player_id = player.id;
        } else if (player.suspicion >= CALM_SUSPICION_LIMIT) {
            self.state = .agitated;
            self.target_player_id = player.id;
            self.roar_ticks_remaining = 0;
        } else if (self.state != .chasing) {
            self.state = .calm;
            self.roar_ticks_remaining = 0;
        }
    }

    fn nearestPlayer(self: Warden, players: []Player) ?usize {
        var nearest: ?usize = null;
        var nearest_distance = SCENT_RANGE;
        for (players, 0..) |player, index| {
            const player_distance = distance(self.position, player.position);
            if (player_distance <= nearest_distance) {
                if (nearest == null or player_distance < nearest_distance) {
                    nearest = index;
                    nearest_distance = player_distance;
                }
            }
        }
        return nearest;
    }

    /// Advances one 20 Hz tick and returns animation/targeting events. Players
    /// are mutable because scent adds directly to their suspicion meters.
    pub fn tick(self: *Warden, players: []Player) TickEvents {
        const initial_state = self.state;
        var events = TickEvents{};

        if (self.state == .roaring) {
            if (self.roar_ticks_remaining > 0) self.roar_ticks_remaining -= 1;
            if (self.roar_ticks_remaining == 0) self.state = .agitated;
        }

        if (self.state != .chasing) {
            self.sniff_ticks += 1;
            if (self.sniff_ticks >= SCENT_INTERVAL_TICKS) {
                self.sniff_ticks = 0;
                events.sniff_animation = true;
                if (self.nearestPlayer(players)) |index| {
                    const suspect = &players[index];
                    suspect.suspicion = @min(std.math.maxInt(u16), suspect.suspicion +| SCENT_SUSPICION);
                    self.target_player_id = suspect.id;
                    events.sniffed_player_id = suspect.id;
                    self.refreshState(suspect);
                }
            }
        } else {
            self.sniff_ticks = 0;
        }

        if (self.state == .agitated) {
            if (self.target_player_id) |target_id| events.turned_toward_player_id = target_id;
        }

        if (self.state == .calm and !self.heard_vibration_this_tick) {
            self.calm_decay_ticks += 1;
            if (self.calm_decay_ticks >= CALM_DECAY_INTERVAL_TICKS) {
                self.calm_decay_ticks = 0;
                for (players) |*player| {
                    if (player.suspicion > 0) player.suspicion -= 1;
                }
            }
        } else {
            self.calm_decay_ticks = 0;
        }
        events.roar_started = initial_state != .roaring and self.state == .roaring;
        self.heard_vibration_this_tick = false;
        return events;
    }
};

pub const SonicBlastResult = struct {
    hit: bool,
    damage: f32 = 0.0,
    knockback: Velocity = .{},
};

/// Horizontal reach models the penetrating beam: terrain and walls do not
/// occlude it. Vertical separation does not shorten its horizontal travel.
pub fn resolveSonicBlast(warden: Position, target: Position) SonicBlastResult {
    const dx = target.x - warden.x;
    const dz = target.z - warden.z;
    const horizontal_distance = @sqrt(dx * dx + dz * dz);
    if (horizontal_distance > SONIC_BLAST_REACH) return .{ .hit = false };
    if (horizontal_distance <= 0.0001) return .{
        .hit = true,
        .damage = SONIC_BLAST_DAMAGE,
        .knockback = .{ .y = SONIC_BLAST_VERTICAL_KNOCKBACK },
    };
    return .{
        .hit = true,
        .damage = SONIC_BLAST_DAMAGE,
        .knockback = .{
            .x = dx / horizontal_distance * SONIC_BLAST_HORIZONTAL_KNOCKBACK,
            .y = SONIC_BLAST_VERTICAL_KNOCKBACK,
            .z = dz / horizontal_distance * SONIC_BLAST_HORIZONTAL_KNOCKBACK,
        },
    };
}

/// Applies the penetrating hit directly, bypassing armor and shields.
pub fn hitPlayerWithSonicBlast(warden: Position, player: *Player) bool {
    const result = resolveSonicBlast(warden, player.position);
    if (!result.hit) return false;
    player.health = @max(0.0, player.health - result.damage);
    player.velocity = result.knockback;
    return true;
}

test "scent cadence does not animate during first 83 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 2 } }};
    for (0..83) |_| try std.testing.expect(!(w.tick(&p).sniff_animation));
}
test "sniff animation fires on tick 84" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..83) |_| _ = w.tick(&p);
    try std.testing.expect(w.tick(&p).sniff_animation);
}
test "sniff cadence repeats after another 84 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..84) |_| _ = w.tick(&p);
    for (0..83) |_| try std.testing.expect(!w.tick(&p).sniff_animation);
    try std.testing.expect(w.tick(&p).sniff_animation);
}
test "sniff detects player at exactly 16 meters" {
    var w = Warden.init(.{});
    // Start the calm decay window at its boundary so this asserts the direct
    // +35 acquisition before any subsequent calm decay can occur.
    w.calm_decay_ticks = CALM_DECAY_INTERVAL_TICKS - 1;
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 16 } }};
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 35), p[0].suspicion);
}
test "sniff excludes player beyond 16 meters" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 16.01 } }};
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "scent range uses three dimensional Euclidean distance" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 12, .y = 12 } }};
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "sniff selects nearest of multiple players" {
    var w = Warden.init(.{});
    var p = [_]Player{ .{ .id = 1, .position = .{ .x = 9 } }, .{ .id = 2, .position = .{ .x = 3 } } };
    for (0..83) |_| _ = w.tick(&p);
    const event = w.tick(&p);
    try std.testing.expectEqual(@as(?u32, 2), event.sniffed_player_id);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
    try std.testing.expectEqual(@as(u16, 35), p[1].suspicion);
}
test "sniff animation occurs with no player in range" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 17 } }};
    for (0..83) |_| _ = w.tick(&p);
    const event = w.tick(&p);
    try std.testing.expect(event.sniff_animation);
    try std.testing.expectEqual(@as(?u32, null), event.sniffed_player_id);
}
test "scent adds 35 suspicion on each periodic acquisition" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..168) |_| _ = w.tick(&p);
    // The first 35-point increase is followed by four calm decay ticks before
    // the second sniff, so the net total is 66.
    try std.testing.expectEqual(@as(u16, 66), p[0].suspicion);
}
test "suspicion reaches agitated threshold at 40" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 39 }};
    w.hearVibration(&p[0], 1);
    try std.testing.expectEqual(State.agitated, w.state);
}
test "suspicion below 40 stays calm" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 39 }};
    w.hearVibration(&p[0], 0);
    try std.testing.expectEqual(State.calm, w.state);
}
test "agitated state turns toward identified suspect" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 7, .suspicion = 40 }};
    w.target_player_id = 7;
    w.state = .agitated;
    try std.testing.expectEqual(@as(?u32, 7), w.tick(&p).turned_toward_player_id);
}
test "suspicion 79 remains agitated" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 79 }};
    w.hearVibration(&p[0], 0);
    try std.testing.expectEqual(State.agitated, w.state);
}
test "suspicion reaches roar at 80" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 79 }};
    w.hearVibration(&p[0], 1);
    try std.testing.expectEqual(State.roaring, w.state);
    try std.testing.expectEqual(@as(u32, 40), w.roar_ticks_remaining);
}
test "suspicion 149 remains below chase" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 149 }};
    w.hearVibration(&p[0], 0);
    try std.testing.expectEqual(State.roaring, w.state);
}
test "suspicion reaches relentless chase at 150" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 149 }};
    w.hearVibration(&p[0], 1);
    try std.testing.expectEqual(State.chasing, w.state);
}
test "sniff accumulation escalates calm player through suspicion tiers" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..84 * 4) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 136), p[0].suspicion);
    try std.testing.expectEqual(State.roaring, w.state);
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(State.chasing, w.state);
}
test "tick reports the start of the roar animation" {
    var w = Warden.init(.{});
    w.sniff_ticks = SCENT_INTERVAL_TICKS - 1;
    w.calm_decay_ticks = CALM_DECAY_INTERVAL_TICKS - 1;
    var p = [_]Player{.{ .id = 1, .suspicion = 45 }};
    try std.testing.expect(w.tick(&p).roar_started);
}
test "roar lasts exactly 40 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 80 }};
    w.hearVibration(&p[0], 0);
    for (0..39) |_| _ = w.tick(&p);
    try std.testing.expectEqual(State.roaring, w.state);
    _ = w.tick(&p);
    try std.testing.expectEqual(State.agitated, w.state);
}
test "chasing suppresses periodic sniff animation" {
    var w = Warden.init(.{});
    w.state = .chasing;
    var p = [_]Player{.{ .id = 1 }};
    for (0..168) |_| try std.testing.expect(!w.tick(&p).sniff_animation);
}
test "calm speed is one meter per second" {
    try std.testing.expectEqual(@as(f32, 1.0), Warden.init(.{}).movementSpeed());
}
test "agitated and roaring wardens stop moving" {
    var w = Warden.init(.{});
    w.state = .agitated;
    try std.testing.expectEqual(@as(f32, 0.0), w.movementSpeed());
    w.state = .roaring;
    try std.testing.expectEqual(@as(f32, 0.0), w.movementSpeed());
}
test "chase speed is 4.2 meters per second" {
    var w = Warden.init(.{});
    w.state = .chasing;
    try std.testing.expectEqual(@as(f32, 4.2), w.movementSpeed());
}
test "calm suspicion decays after 20 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 3 }};
    for (0..19) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 3), p[0].suspicion);
    _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 2), p[0].suspicion);
}
test "calm suspicion decays once per 20 tick interval" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 2 }};
    for (0..40) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "vibration interrupts the calm decay timer" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 5 }};
    for (0..19) |_| _ = w.tick(&p);
    w.hearVibration(&p[0], 0);
    _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 5), p[0].suspicion);
}
test "decay never underflows zero suspicion" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..40) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "blast hits target at 15 horizontal meters" {
    const result = resolveSonicBlast(.{}, .{ .x = 15 });
    try std.testing.expect(result.hit);
}
test "blast misses beyond 15 horizontal meters" {
    const result = resolveSonicBlast(.{}, .{ .x = 15.01 });
    try std.testing.expect(!result.hit);
}
test "blast uses horizontal reach despite vertical separation" {
    const result = resolveSonicBlast(.{}, .{ .x = 15, .y = 100 });
    try std.testing.expect(result.hit);
}
test "blast penetrates terrain because resolution has no block input" {
    const solid_wall_between = true;
    const result = resolveSonicBlast(.{}, .{ .x = 10 });
    try std.testing.expect(solid_wall_between);
    try std.testing.expect(result.hit);
}
test "blast damage is exactly ten health" {
    try std.testing.expectEqual(@as(f32, 10.0), resolveSonicBlast(.{}, .{ .x = 1 }).damage);
}
test "blast vertical knockback is six meters per second" {
    try std.testing.expectEqual(@as(f32, 6.0), resolveSonicBlast(.{}, .{ .x = 1 }).knockback.y);
}
test "blast horizontal knockback magnitude is eight meters per second" {
    const impulse = resolveSonicBlast(.{}, .{ .x = 3, .z = 4 }).knockback;
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), @sqrt(impulse.x * impulse.x + impulse.z * impulse.z), 0.0001);
}
test "blast applies unmitigated health loss and replaces velocity" {
    var player = Player{ .id = 1, .position = .{ .x = 2 }, .armor_points = 20, .shield_blocking = true };
    player.velocity = .{ .x = -1, .y = 1, .z = -1 };
    try std.testing.expect(hitPlayerWithSonicBlast(.{}, &player));
    try std.testing.expectEqual(@as(f32, 10.0), player.health);
    try std.testing.expectEqual(@as(f32, 8.0), player.velocity.x);
    try std.testing.expectEqual(@as(f32, 6.0), player.velocity.y);
}
test "blast does not alter player outside reach" {
    var player = Player{ .id = 1, .position = .{ .x = 16 } };
    try std.testing.expect(!hitPlayerWithSonicBlast(.{}, &player));
    try std.testing.expectEqual(@as(f32, 20.0), player.health);
}
test "blast damage cannot reduce health below zero" {
    var player = Player{ .id = 1, .position = .{ .x = 1 }, .health = 4 };
    _ = hitPlayerWithSonicBlast(.{}, &player);
    try std.testing.expectEqual(@as(f32, 0.0), player.health);
}
