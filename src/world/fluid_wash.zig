const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

pub const wash_radius_sq: f32 = 144.0;

pub fn isWashable(cell: BlockId, above: BlockId) bool {
    return cell == .water or above == .water;
}

pub fn inPickupRange(bx: f32, bz: f32, px: f32, pz: f32) bool {
    const dx = bx - px;
    const dz = bz - pz;
    return dx * dx + dz * dz < wash_radius_sq;
}

test "washable cells" {
    try std.testing.expect(isWashable(.water, .air));
    try std.testing.expect(isWashable(.torch, .water));
    try std.testing.expect(!isWashable(.stone, .air));
    try std.testing.expect(!isWashable(.torch, .air));
}

test "pickup range" {
    try std.testing.expect(inPickupRange(0, 0, 0, 0));
    try std.testing.expect(inPickupRange(11, 0, 0, 0));
    try std.testing.expect(!inPickupRange(13, 0, 0, 0));
}

pub const flow_tick: f32 = 0.4;
pub const max_spread: i32 = 7;

pub const FlowDir = struct { dx: i32, dz: i32 };
pub const flow_dirs = [_]FlowDir{ .{ .dx = 1, .dz = 0 }, .{ .dx = -1, .dz = 0 }, .{ .dx = 0, .dz = 1 }, .{ .dx = 0, .dz = -1 } };

pub fn canFlowInto(cell: BlockId) bool {
    return cell == .air;
}

pub fn shouldFlowDown(below: BlockId) bool {
    return below == .air;
}

test "flow targets air only" {
    try std.testing.expect(canFlowInto(.air));
    try std.testing.expect(!canFlowInto(.water));
    try std.testing.expect(!canFlowInto(.stone));
    try std.testing.expect(!canFlowInto(.torch));
}

test "flow prefers falling straight down" {
    try std.testing.expect(shouldFlowDown(.air));
    try std.testing.expect(!shouldFlowDown(.water));
    try std.testing.expect(!shouldFlowDown(.stone));
}
