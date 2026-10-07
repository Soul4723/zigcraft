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
