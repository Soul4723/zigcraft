const std = @import("std");

pub const Vec3 = [3]f32;
pub const minimum_frame_blocks: u8 = 16;
pub const complete_frame_blocks: u8 = 42;
pub const minimum_range_m: f32 = 32.0;
pub const maximum_range_m: f32 = 96.0;
pub const hostile_zap_range_m: f32 = 8.0;
pub const hostile_zap_damage: f32 = 4.0;
pub const hostile_zap_interval_ticks: u8 = 40;

pub const FrameBlock = enum {
    prismarine,
    dark_prismarine,
    prismarine_bricks,
    sea_lantern,
    other,
};

pub fn isValidFrameBlock(block: FrameBlock) bool {
    return block != .other;
}

/// Counts only valid frame materials. Counts above the complete frame are capped.
pub fn countFrameBlocks(blocks: []const FrameBlock) u8 {
    var count: u8 = 0;
    for (blocks) |block| {
        if (isValidFrameBlock(block) and count < complete_frame_blocks) count += 1;
    }
    return count;
}

pub const Activation = struct {
    active: bool,
    complete_frame: bool,
    frame_block_count: u8,
    range_m: f32,
};

/// A conduit is active only while immersed in water and surrounded by at least
/// sixteen valid frame blocks. Range interpolates linearly between 16 and 42.
pub fn evaluateActivation(is_submerged_in_water: bool, frame_block_count: u8) Activation {
    const count = @min(frame_block_count, complete_frame_blocks);
    const active = is_submerged_in_water and count >= minimum_frame_blocks;
    if (!active) return .{
        .active = false,
        .complete_frame = false,
        .frame_block_count = count,
        .range_m = 0.0,
    };

    const progress: f32 = @as(f32, @floatFromInt(count - minimum_frame_blocks)) /
        @as(f32, @floatFromInt(complete_frame_blocks - minimum_frame_blocks));
    return .{
        .active = true,
        .complete_frame = count == complete_frame_blocks,
        .frame_block_count = count,
        .range_m = minimum_range_m + progress * (maximum_range_m - minimum_range_m),
    };
}

pub const ConduitPower = struct {
    underwater_sight: bool = false,
    water_breathing: bool = false,
    underwater_mining_penalty_removed: bool = false,
    air_meter: u16,
};

/// Grants the conduit effect inside its range and restores air to full while
/// water breathing is active. `distance_m` is measured from the conduit.
pub fn applyConduitPower(
    activation: Activation,
    player_is_underwater: bool,
    distance_m: f32,
    current_air: u16,
    maximum_air: u16,
) ConduitPower {
    const in_range = activation.active and player_is_underwater and distance_m >= 0.0 and
        distance_m <= activation.range_m;
    return .{
        .underwater_sight = in_range,
        .water_breathing = in_range,
        .underwater_mining_penalty_removed = in_range,
        .air_meter = if (in_range) maximum_air else current_air,
    };
}

pub const HostileAquaticMob = enum { drowned, guardian, elder_guardian, other };

pub const Mob = struct {
    kind: HostileAquaticMob,
    position: Vec3,
    health: f32,
};

pub const ZapEvent = struct {
    target_index: ?usize = null,
    damage: f32 = 0.0,
    glowing_bubble_particles: bool = false,
};

pub const ZapState = struct {
    ticks_until_zap: u8 = hostile_zap_interval_ticks,
};

/// Advances the complete-frame artillery by one game tick. On each 40th tick,
/// zaps the nearest eligible Drowned, Guardian, or Elder Guardian within 8 m.
/// Ineligible ticks do not pause the cadence; callers should invoke once per
/// game tick while the conduit exists.
pub fn tickHostileZap(
    activation: Activation,
    conduit_position: Vec3,
    mobs: []Mob,
    state: *ZapState,
) ZapEvent {
    if (!activation.active or !activation.complete_frame) {
        state.ticks_until_zap = hostile_zap_interval_ticks;
        return .{};
    }

    if (state.ticks_until_zap > 1) {
        state.ticks_until_zap -= 1;
        return .{};
    }
    state.ticks_until_zap = hostile_zap_interval_ticks;

    var nearest_index: ?usize = null;
    var nearest_distance_sq: f32 = hostile_zap_range_m * hostile_zap_range_m;
    for (mobs, 0..) |mob, index| {
        if (!isHostileAquatic(mob.kind) or mob.health <= 0.0) continue;
        const distance_sq = distanceSquared(conduit_position, mob.position);
        if (distance_sq <= nearest_distance_sq) {
            nearest_distance_sq = distance_sq;
            nearest_index = index;
        }
    }

    const target_index = nearest_index orelse return .{};
    mobs[target_index].health = @max(0.0, mobs[target_index].health - hostile_zap_damage);
    return .{
        .target_index = target_index,
        .damage = hostile_zap_damage,
        .glowing_bubble_particles = true,
    };
}

fn isHostileAquatic(kind: HostileAquaticMob) bool {
    return kind == .drowned or kind == .guardian or kind == .elder_guardian;
}

fn distanceSquared(a: Vec3, b: Vec3) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

test "the four prismarine and sea lantern materials are valid frame blocks" {
    try std.testing.expect(isValidFrameBlock(.prismarine));
    try std.testing.expect(isValidFrameBlock(.dark_prismarine));
    try std.testing.expect(isValidFrameBlock(.prismarine_bricks));
    try std.testing.expect(isValidFrameBlock(.sea_lantern));
    try std.testing.expect(!isValidFrameBlock(.other));
}

test "frame counter ignores invalid materials and caps at forty-two" {
    const blocks = [_]FrameBlock{.prismarine} ** 42 ++ [_]FrameBlock{.other} ** 2;
    try std.testing.expectEqual(@as(u8, 42), countFrameBlocks(&blocks));
}

test "frame counts below sixteen do not activate" {
    for (0..16) |count| {
        const result = evaluateActivation(true, @intCast(count));
        try std.testing.expect(!result.active);
        try std.testing.expectEqual(@as(f32, 0.0), result.range_m);
    }
}

test "water immersion is required even with a complete frame" {
    const result = evaluateActivation(false, 42);
    try std.testing.expect(!result.active);
    try std.testing.expect(!result.complete_frame);
    try std.testing.expectEqual(@as(f32, 0.0), result.range_m);
}

test "sixteen frame blocks activate at thirty-two metres" {
    const result = evaluateActivation(true, 16);
    try std.testing.expect(result.active);
    try std.testing.expect(!result.complete_frame);
    try std.testing.expectEqual(@as(f32, 32.0), result.range_m);
}

test "forty-two frame blocks activate full range and artillery" {
    const result = evaluateActivation(true, 42);
    try std.testing.expect(result.active);
    try std.testing.expect(result.complete_frame);
    try std.testing.expectEqual(@as(f32, 96.0), result.range_m);
}

test "excess frame blocks are capped at the complete-frame range" {
    const result = evaluateActivation(true, 255);
    try std.testing.expectEqual(@as(u8, 42), result.frame_block_count);
    try std.testing.expectEqual(@as(f32, 96.0), result.range_m);
}

test "range scales linearly for every valid count from sixteen through forty-two" {
    for (16..43) |count| {
        const expected = 32.0 + (@as(f32, @floatFromInt(count - 16)) * (64.0 / 26.0));
        const actual = evaluateActivation(true, @intCast(count)).range_m;
        try std.testing.expectApproxEqAbs(expected, actual, 0.0001);
    }
}

test "twenty-nine frame blocks yield the linear midpoint range" {
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), evaluateActivation(true, 29).range_m, 0.0001);
}

test "power grants underwater sight breathing mining and restores air" {
    const buff = applyConduitPower(evaluateActivation(true, 42), true, 40.0, 12, 300);
    try std.testing.expect(buff.underwater_sight);
    try std.testing.expect(buff.water_breathing);
    try std.testing.expect(buff.underwater_mining_penalty_removed);
    try std.testing.expectEqual(@as(u16, 300), buff.air_meter);
}

test "power effects work at the inclusive edge of the aura" {
    const buff = applyConduitPower(evaluateActivation(true, 16), true, 32.0, 1, 300);
    try std.testing.expect(buff.water_breathing);
    try std.testing.expectEqual(@as(u16, 300), buff.air_meter);
}

test "power does not apply beyond aura range" {
    const buff = applyConduitPower(evaluateActivation(true, 16), true, 32.01, 10, 300);
    try std.testing.expect(!buff.underwater_sight);
    try std.testing.expect(!buff.water_breathing);
    try std.testing.expect(!buff.underwater_mining_penalty_removed);
    try std.testing.expectEqual(@as(u16, 10), buff.air_meter);
}

test "power does not apply to a player outside water" {
    const buff = applyConduitPower(evaluateActivation(true, 42), false, 0.0, 10, 300);
    try std.testing.expect(!buff.water_breathing);
    try std.testing.expectEqual(@as(u16, 10), buff.air_meter);
}

test "power does not apply when conduit is dry or inactive" {
    const buff = applyConduitPower(evaluateActivation(false, 42), true, 0.0, 10, 300);
    try std.testing.expect(!buff.underwater_sight);
    try std.testing.expectEqual(@as(u16, 10), buff.air_meter);
}

test "negative distance is rejected" {
    const buff = applyConduitPower(evaluateActivation(true, 42), true, -1.0, 10, 300);
    try std.testing.expect(!buff.water_breathing);
}

test "artillery cannot fire before the full frame" {
    const activation = evaluateActivation(true, 41);
    var state = ZapState{};
    var mobs = [_]Mob{.{ .kind = .drowned, .position = .{ 1, 0, 0 }, .health = 20 }};
    for (0..80) |_| try std.testing.expectEqual(@as(?usize, null), tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state).target_index);
    try std.testing.expectEqual(@as(f32, 20.0), mobs[0].health);
}

test "artillery waits exactly forty ticks then deals four damage with bubbles" {
    const activation = evaluateActivation(true, 42);
    var state = ZapState{};
    var mobs = [_]Mob{.{ .kind = .guardian, .position = .{ 0, 0, 8 }, .health = 20 }};
    for (0..39) |_| try std.testing.expectEqual(@as(?usize, null), tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state).target_index);
    const event = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(?usize, 0), event.target_index);
    try std.testing.expectEqual(@as(f32, 4.0), event.damage);
    try std.testing.expect(event.glowing_bubble_particles);
    try std.testing.expectEqual(@as(f32, 16.0), mobs[0].health);
}

test "artillery repeats once every forty ticks" {
    const activation = evaluateActivation(true, 42);
    var state = ZapState{};
    var mobs = [_]Mob{.{ .kind = .drowned, .position = .{ 1, 0, 0 }, .health = 20 }};
    for (0..40) |_| _ = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(f32, 16.0), mobs[0].health);
    for (0..39) |_| _ = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(f32, 16.0), mobs[0].health);
    _ = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(f32, 12.0), mobs[0].health);
}

test "artillery includes the eight metre boundary" {
    const activation = evaluateActivation(true, 42);
    var state = ZapState{};
    var mobs = [_]Mob{.{ .kind = .elder_guardian, .position = .{ 0, 0, 8 }, .health = 80 }};
    for (0..39) |_| _ = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    const event = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(?usize, 0), event.target_index);
}

test "artillery excludes targets beyond eight metres" {
    const activation = evaluateActivation(true, 42);
    var state = ZapState{};
    var mobs = [_]Mob{.{ .kind = .drowned, .position = .{ 8.01, 0, 0 }, .health = 20 }};
    for (0..40) |_| _ = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(f32, 20.0), mobs[0].health);
}

test "artillery ignores non aquatic hostiles and dead mobs" {
    const activation = evaluateActivation(true, 42);
    var state = ZapState{};
    var mobs = [_]Mob{
        .{ .kind = .other, .position = .{ 1, 0, 0 }, .health = 20 },
        .{ .kind = .guardian, .position = .{ 2, 0, 0 }, .health = 0 },
    };
    for (0..40) |_| _ = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(f32, 20.0), mobs[0].health);
    try std.testing.expectEqual(@as(f32, 0.0), mobs[1].health);
}

test "artillery chooses the nearest eligible hostile aquatic mob" {
    const activation = evaluateActivation(true, 42);
    var state = ZapState{};
    var mobs = [_]Mob{
        .{ .kind = .drowned, .position = .{ 6, 0, 0 }, .health = 20 },
        .{ .kind = .guardian, .position = .{ 2, 0, 0 }, .health = 20 },
    };
    for (0..40) |_| _ = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(f32, 20.0), mobs[0].health);
    try std.testing.expectEqual(@as(f32, 16.0), mobs[1].health);
}

test "artillery reduces lethal damage to zero health" {
    const activation = evaluateActivation(true, 42);
    var state = ZapState{};
    var mobs = [_]Mob{.{ .kind = .drowned, .position = .{ 1, 0, 0 }, .health = 3 }};
    for (0..40) |_| _ = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(f32, 0.0), mobs[0].health);
}

test "losing the complete frame disables and resets the zap cadence" {
    var state = ZapState{};
    var mobs = [_]Mob{.{ .kind = .guardian, .position = .{ 1, 0, 0 }, .health = 20 }};
    const inactive = evaluateActivation(true, 41);
    for (0..10) |_| _ = tickHostileZap(inactive, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(hostile_zap_interval_ticks, state.ticks_until_zap);
}

test "empty scan consumes cadence without producing a zap event" {
    const activation = evaluateActivation(true, 42);
    var state = ZapState{};
    var mobs: [0]Mob = .{};
    var event: ZapEvent = .{};
    for (0..40) |_| event = tickHostileZap(activation, .{ 0, 0, 0 }, &mobs, &state);
    try std.testing.expectEqual(@as(?usize, null), event.target_index);
    try std.testing.expectEqual(hostile_zap_interval_ticks, state.ticks_until_zap);
}
