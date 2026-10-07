const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

pub const Sprout = struct { x: i32, y: i32, z: i32, t: f32 };
pub const grow_time: f32 = 30.0;
pub const trunk_height: i32 = 3;
pub const sprout_cap: usize = 16;

pub fn isReady(t: f32) bool {
    return t >= grow_time;
}

pub fn trunkTopY(base_y: i32) i32 {
    return base_y + trunk_height + 1;
}

test "sapling growth timing" {
    try std.testing.expect(!isReady(0.0));
    try std.testing.expect(!isReady(29.9));
    try std.testing.expect(isReady(30.0));
    try std.testing.expect(isReady(45.0));
}

test "trunk top sits one above trunk" {
    try std.testing.expectEqual(trunkTopY(10), 14);
    try std.testing.expectEqual(trunkTopY(0), 4);
}
