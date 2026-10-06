const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

pub const FallSand = struct {
    x: i32,
    y: i32,
    z: i32,
    t: f32,
    dist: i32,
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
