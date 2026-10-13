const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

pub const FallSand = struct {
    x: i32,
    y: i32,
    z: i32,
    t: f32,
    dist: i32,
    block_type: BlockId = .sand,
};

pub const FallAction = enum {
    none,
    drop_into_air,
    splash_into_water,
    crush_non_solid,
    land,
};

pub fn evaluateFallingStep(below: BlockId, current_y: i32) FallAction {
    if (current_y <= 0) return .land;
    if (below == .air) return .drop_into_air;
    if (below == .water) return .splash_into_water;
    if (!below.is_solid()) return .crush_non_solid;
    return .land;
}

pub fn calculateImpactDamage(distance: i32) u8 {
    if (distance < 3) return 0;
    return @intCast(@min(@divTrunc(distance, 3), 20));
}

test "falling step evaluation" {
    try std.testing.expectEqual(evaluateFallingStep(.air, 5), .drop_into_air);
    try std.testing.expectEqual(evaluateFallingStep(.water, 5), .splash_into_water);
    try std.testing.expectEqual(evaluateFallingStep(.torch, 5), .crush_non_solid);
    try std.testing.expectEqual(evaluateFallingStep(.stone, 5), .land);
    try std.testing.expectEqual(evaluateFallingStep(.air, 0), .land);
}

test "falling impact damage calculation" {
    try std.testing.expectEqual(calculateImpactDamage(0), 0);
    try std.testing.expectEqual(calculateImpactDamage(2), 0);
    try std.testing.expectEqual(calculateImpactDamage(3), 1);
    try std.testing.expectEqual(calculateImpactDamage(6), 2);
    try std.testing.expectEqual(calculateImpactDamage(30), 10);
    try std.testing.expectEqual(calculateImpactDamage(90), 20); // capped at 20
}

pub const fall_interval: f32 = 0.15;
pub const falling_cap: usize = 32;

pub fn findFalling(items: []const FallSand, n: usize, x: i32, y: i32, z: i32) ?usize {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (items[i].x == x and items[i].y == y and items[i].z == z) return i;
    }
    return null;
}

pub fn isHitByBlock(entity_x: f32, entity_y: f32, entity_z: f32, bx: i32, by: i32, bz: i32) bool {
    const ex: i32 = @intFromFloat(@floor(entity_x));
    const ey: i32 = @intFromFloat(@floor(entity_y));
    const ez: i32 = @intFromFloat(@floor(entity_z));
    return ex == bx and (ey == by or ey == by + 1) and ez == bz;
}

test "falling block find and hit detection" {
    var sand = [_]FallSand{.{ .x = 10, .y = 5, .z = 10, .t = 0.0, .dist = 0 }} ** 2;
    try std.testing.expectEqual(findFalling(&sand, 1, 10, 5, 10), @as(?usize, 0));
    try std.testing.expectEqual(findFalling(&sand, 1, 0, 0, 0), @as(?usize, null));

    // Entity feet at y=5, block at y=5
    try std.testing.expect(isHitByBlock(10.2, 5.0, 10.1, 10, 5, 10));
    // Entity feet at y=4, block at y=5 (head at y=5 would be ey=4, so ey+1=5 == by)
    try std.testing.expect(isHitByBlock(10.2, 4.0, 10.1, 10, 4, 10));
    // Entity at y=5 (feet at block level)
    try std.testing.expect(isHitByBlock(10.0, 5.0, 10.0, 10, 5, 10));
    // Entity away
    try std.testing.expect(!isHitByBlock(12.0, 5.0, 10.0, 10, 5, 10));
}

pub fn calculateAnvilImpactDamage(distance: i32) u8 {
    if (distance < 1) return 0;
    // Anvils deal heavy concussive crush damage: 2 dmg per meter, capped at 40
    return @intCast(@min(distance * 2, 40));
}

test "anvil impact damage calculation" {
    try std.testing.expectEqual(calculateAnvilImpactDamage(0), 0);
    try std.testing.expectEqual(calculateAnvilImpactDamage(1), 2);
    try std.testing.expectEqual(calculateAnvilImpactDamage(5), 10);
    try std.testing.expectEqual(calculateAnvilImpactDamage(15), 30);
    try std.testing.expectEqual(calculateAnvilImpactDamage(30), 40); // capped at 40
}
