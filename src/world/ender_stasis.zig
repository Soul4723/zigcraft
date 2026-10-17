const std = @import("std");

/// Ender pearls suspended by an upward Soul Sand bubble column do not time out.
pub const bubble_stasis_vertical_velocity: f32 = 0.0;
pub const ender_pearl_impact_damage: f32 = 5.0;
pub const endermite_spawn_roll_modulus: u32 = 20;
pub const chorus_search_radius: i32 = 8;
pub const chorus_cooldown_seconds: f32 = 1.0;
pub const chorus_fall_distance_reset: f32 = 0.0;

/// The simulation state for one thrown Ender Pearl.
///
/// The protection flags are optional status context for the impact result. They
/// default to false so callers only interested in projectile motion can use the
/// five core fields described by the entity model.
pub const StasisPearl = struct {
    owner_id: u32,
    pos: [3]f32,
    vel: [3]f32,
    in_upward_bubble_column: bool,
    is_alive: bool,
    has_feather_falling: bool = false,
    has_slow_falling: bool = false,
};

pub const StasisTickResult = struct {
    teleported: bool,
    target_pos: [3]f32,
    fall_damage: f32,
    spawned_endermite: bool,
};

/// The Endermite proc is deliberately deterministic: owner IDs provide the
/// per-pearl roll while retaining exactly one success out of every 20 values.
/// The integration layer can use the same helper when it owns a random stream.
pub fn shouldSpawnEndermite(roll: u32) bool {
    return roll % endermite_spawn_roll_modulus == 0;
}

fn resultFor(pearl: *const StasisPearl) StasisTickResult {
    return .{
        .teleported = false,
        .target_pos = pearl.pos,
        .fall_damage = 0.0,
        .spawned_endermite = false,
    };
}

fn tickStasisPearlInternal(
    pearl: *StasisPearl,
    dt: f32,
    in_soul_sand_bubble_column: bool,
    hit_solid_or_closed_trapdoor: bool,
) StasisTickResult {
    var result = resultFor(pearl);
    if (!pearl.is_alive) return result;

    pearl.in_upward_bubble_column = in_soul_sand_bubble_column;

    // A trapdoor closing at the chamber mouth is an immediate collision. Do
    // this before motion so the owner lands exactly at the pearl's current
    // coordinates, matching a same-tick impact.
    if (hit_solid_or_closed_trapdoor) {
        pearl.is_alive = false;
        result.teleported = true;
        result.target_pos = pearl.pos;
        result.fall_damage = if (pearl.has_feather_falling or pearl.has_slow_falling)
            0.0
        else
            ender_pearl_impact_damage;
        result.spawned_endermite = shouldSpawnEndermite(pearl.owner_id);
        return result;
    }

    if (in_soul_sand_bubble_column) {
        // Bubble columns hold a pearl indefinitely. In particular, do not
        // decrement a lifetime here: StasisPearl intentionally has no expiry.
        pearl.vel[1] = bubble_stasis_vertical_velocity;
    }

    const step_dt = @max(dt, 0.0);
    pearl.pos[0] += pearl.vel[0] * step_dt;
    pearl.pos[1] += pearl.vel[1] * step_dt;
    pearl.pos[2] += pearl.vel[2] * step_dt;
    result.target_pos = pearl.pos;
    return result;
}

/// Advances a live pearl and handles bubble-column stasis or a trapdoor hit.
/// A trapdoor hit teleports the owner, consumes the pearl, applies 5 HP of
/// impact damage (or zero when either protection flag is active), and performs
/// the 5% Endermite roll.
pub fn tickStasisPearl(
    pearl: *StasisPearl,
    dt: f32,
    in_soul_sand_bubble_column: bool,
    hit_solid_or_closed_trapdoor: bool,
) StasisTickResult {
    return tickStasisPearlInternal(pearl, dt, in_soul_sand_bubble_column, hit_solid_or_closed_trapdoor);
}

/// Searches the supplied relative destinations in order. The callback owns the
/// world query and should return true only when the destination has a solid
/// floor and two clear air blocks above it. Candidates outside the vanilla
/// Chorus Fruit +/-8 block search cube are ignored.
pub fn computeChorusFruitTeleport(
    origin: [3]i32,
    candidate_offsets: []const [3]i32,
    is_safe_standable_fn: *const fn (x: i32, y: i32, z: i32) bool,
) ?[3]i32 {
    for (candidate_offsets) |offset| {
        if (@abs(offset[0]) > chorus_search_radius or
            @abs(offset[1]) > chorus_search_radius or
            @abs(offset[2]) > chorus_search_radius)
        {
            continue;
        }

        const candidate = .{
            origin[0] + offset[0],
            origin[1] + offset[1],
            origin[2] + offset[2],
        };
        if (is_safe_standable_fn(candidate[0], candidate[1], candidate[2])) {
            return candidate;
        }
    }
    return null;
}

/// Player-side state for Chorus Fruit's one-second cooldown and fall reset.
pub const ChorusFruitState = struct {
    fall_distance: f32 = 0.0,
    cooldown: f32 = 0.0,

    pub fn tick(self: *ChorusFruitState, dt: f32) void {
        self.cooldown = @max(0.0, self.cooldown - @max(dt, 0.0));
    }
};

/// Applies the side effects that cannot be represented by the pure destination
/// query: a successful teleport resets fall distance and starts its cooldown.
pub fn applyChorusFruitTeleport(
    state: *ChorusFruitState,
    origin: [3]i32,
    candidate_offsets: []const [3]i32,
    is_safe_standable_fn: *const fn (x: i32, y: i32, z: i32) bool,
) ?[3]i32 {
    if (state.cooldown > 0.0) return null;
    const target = computeChorusFruitTeleport(origin, candidate_offsets, is_safe_standable_fn) orelse return null;
    state.fall_distance = chorus_fall_distance_reset;
    state.cooldown = chorus_cooldown_seconds;
    return target;
}

fn alwaysSafe(_: i32, _: i32, _: i32) bool {
    return true;
}

fn safeAtOrigin(x: i32, y: i32, z: i32) bool {
    return x == 10 and y == 65 and z == -4;
}

test "bubble column zeroes vertical velocity and preserves pearl" {
    var pearl = StasisPearl{
        .owner_id = 7,
        .pos = .{ 1.0, 30.0, 2.0 },
        .vel = .{ 3.0, -12.0, 4.0 },
        .in_upward_bubble_column = false,
        .is_alive = true,
    };
    const result = tickStasisPearl(&pearl, 2.0, true, false);
    try std.testing.expect(pearl.is_alive);
    try std.testing.expect(pearl.in_upward_bubble_column);
    try std.testing.expectEqual(@as(f32, 0.0), pearl.vel[1]);
    try std.testing.expectEqual(@as(f32, 30.0), pearl.pos[1]);
    try std.testing.expect(!result.teleported);
}

test "bubble stasis remains indefinite across repeated ticks" {
    var pearl = StasisPearl{ .owner_id = 1, .pos = .{ 0, 12, 0 }, .vel = .{ 0, 9, 0 }, .in_upward_bubble_column = false, .is_alive = true };
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        _ = tickStasisPearl(&pearl, 10.0, true, false);
    }
    try std.testing.expect(pearl.is_alive);
    try std.testing.expectEqual(@as(f32, 12.0), pearl.pos[1]);
}

test "bubble stasis still carries horizontal velocity" {
    var pearl = StasisPearl{ .owner_id = 2, .pos = .{ 0, 4, 0 }, .vel = .{ 2, 5, -1 }, .in_upward_bubble_column = false, .is_alive = true };
    _ = tickStasisPearl(&pearl, 0.5, true, false);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), pearl.pos[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), pearl.pos[2], 0.001);
}

test "pearl moves normally outside bubble column" {
    var pearl = StasisPearl{ .owner_id = 3, .pos = .{ 1, 2, 3 }, .vel = .{ 2, -4, 1 }, .in_upward_bubble_column = true, .is_alive = true };
    const result = tickStasisPearl(&pearl, 0.25, false, false);
    try std.testing.expect(!pearl.in_upward_bubble_column);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), result.target_pos[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result.target_pos[1], 0.001);
}

test "closed trapdoor teleports immediately and consumes pearl" {
    var pearl = StasisPearl{ .owner_id = 1, .pos = .{ 4.5, 18.0, -2.0 }, .vel = .{ 9, 9, 9 }, .in_upward_bubble_column = true, .is_alive = true };
    const result = tickStasisPearl(&pearl, 100.0, true, true);
    try std.testing.expect(result.teleported);
    try std.testing.expectEqual(pearl.pos, result.target_pos);
    try std.testing.expect(!pearl.is_alive);
    try std.testing.expectEqual(@as(f32, 5.0), result.fall_damage);
}

test "trapdoor impact does not move pearl before teleport" {
    var pearl = StasisPearl{ .owner_id = 1, .pos = .{ 2, 3, 4 }, .vel = .{ 100, 100, 100 }, .in_upward_bubble_column = false, .is_alive = true };
    const result = tickStasisPearl(&pearl, 1.0, false, true);
    try std.testing.expectEqual([3]f32{ 2, 3, 4 }, result.target_pos);
}

test "dead pearl cannot trigger a second teleport" {
    var pearl = StasisPearl{ .owner_id = 0, .pos = .{ 1, 1, 1 }, .vel = .{ 0, 0, 0 }, .in_upward_bubble_column = false, .is_alive = false };
    const result = tickStasisPearl(&pearl, 0.0, false, true);
    try std.testing.expect(!result.teleported);
    try std.testing.expectEqual(@as(f32, 0.0), result.fall_damage);
}

test "impact damage is five HP without protection" {
    var pearl = StasisPearl{ .owner_id = 1, .pos = .{ 0, 0, 0 }, .vel = .{ 0, 0, 0 }, .in_upward_bubble_column = false, .is_alive = true };
    const result = tickStasisPearl(&pearl, 0, false, true);
    try std.testing.expectEqual(ender_pearl_impact_damage, result.fall_damage);
}

test "Feather Falling suppresses pearl impact damage" {
    var pearl = StasisPearl{ .owner_id = 1, .pos = .{ 0, 0, 0 }, .vel = .{ 0, 0, 0 }, .in_upward_bubble_column = false, .is_alive = true, .has_feather_falling = true };
    const result = tickStasisPearl(&pearl, 0, false, true);
    try std.testing.expectEqual(@as(f32, 0.0), result.fall_damage);
}

test "Slow Falling suppresses pearl impact damage" {
    var pearl = StasisPearl{ .owner_id = 1, .pos = .{ 0, 0, 0 }, .vel = .{ 0, 0, 0 }, .in_upward_bubble_column = false, .is_alive = true, .has_slow_falling = true };
    const result = tickStasisPearl(&pearl, 0, false, true);
    try std.testing.expectEqual(@as(f32, 0.0), result.fall_damage);
}

test "Endermite roll has exactly one success per twenty values" {
    var successes: usize = 0;
    var roll: u32 = 0;
    while (roll < endermite_spawn_roll_modulus) : (roll += 1) {
        if (shouldSpawnEndermite(roll)) successes += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), successes);
    try std.testing.expect(shouldSpawnEndermite(0));
    try std.testing.expect(!shouldSpawnEndermite(1));
}

test "trapdoor impact uses owner roll for Endermite spawn" {
    var spawning = StasisPearl{ .owner_id = 0, .pos = .{ 0, 0, 0 }, .vel = .{ 0, 0, 0 }, .in_upward_bubble_column = false, .is_alive = true };
    var quiet = StasisPearl{ .owner_id = 1, .pos = .{ 0, 0, 0 }, .vel = .{ 0, 0, 0 }, .in_upward_bubble_column = false, .is_alive = true };
    try std.testing.expect(tickStasisPearl(&spawning, 0, false, true).spawned_endermite);
    try std.testing.expect(!tickStasisPearl(&quiet, 0, false, true).spawned_endermite);
}

test "chorus search accepts a safe destination in range" {
    const offsets = [_][3]i32{ .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    const target = computeChorusFruitTeleport(.{ 9, 65, -4 }, &offsets, safeAtOrigin) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual([3]i32{ 10, 65, -4 }, target);
}

test "chorus search skips unsafe candidates and preserves candidate order" {
    const offsets = [_][3]i32{ .{ 1, 0, 0 }, .{ 2, 0, 0 }, .{ 3, 0, 0 } };
    const target = computeChorusFruitTeleport(.{ 0, 0, 0 }, &offsets, alwaysSafe) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual([3]i32{ 1, 0, 0 }, target);
}

test "chorus search rejects candidates outside eight-block cube" {
    const offsets = [_][3]i32{ .{ 9, 0, 0 }, .{ 0, -9, 0 }, .{ 0, 0, 9 } };
    try std.testing.expect(computeChorusFruitTeleport(.{ 0, 0, 0 }, &offsets, alwaysSafe) == null);
}

test "chorus search returns null when no floor is safe" {
    const offsets = [_][3]i32{ .{ 0, 0, 0 }, .{ 1, 1, 1 } };
    try std.testing.expect(computeChorusFruitTeleport(.{ 9, 65, -4 }, &offsets, safeAtOrigin) == null);
}

test "chorus application resets fall distance and starts cooldown" {
    const offsets = [_][3]i32{.{ 1, 0, 0 }};
    var state = ChorusFruitState{ .fall_distance = 23.5, .cooldown = 0.0 };
    const target = applyChorusFruitTeleport(&state, .{ 9, 65, -4 }, &offsets, safeAtOrigin) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual([3]i32{ 10, 65, -4 }, target);
    try std.testing.expectEqual(chorus_fall_distance_reset, state.fall_distance);
    try std.testing.expectEqual(chorus_cooldown_seconds, state.cooldown);
}

test "chorus cooldown blocks a second teleport until it expires" {
    const offsets = [_][3]i32{.{ 1, 0, 0 }};
    var state = ChorusFruitState{ .fall_distance = 3.0 };
    _ = applyChorusFruitTeleport(&state, .{ 9, 65, -4 }, &offsets, safeAtOrigin);
    try std.testing.expect(applyChorusFruitTeleport(&state, .{ 9, 65, -4 }, &offsets, safeAtOrigin) == null);
    state.tick(1.0);
    try std.testing.expect(applyChorusFruitTeleport(&state, .{ 9, 65, -4 }, &offsets, safeAtOrigin) != null);
}

test "chorus cooldown tick clamps at zero" {
    var state = ChorusFruitState{ .cooldown = 0.25 };
    state.tick(2.0);
    try std.testing.expectEqual(@as(f32, 0.0), state.cooldown);
    state.tick(-1.0);
    try std.testing.expectEqual(@as(f32, 0.0), state.cooldown);
}
