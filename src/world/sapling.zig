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

pub fn canPlant(soil: BlockId, hit_ny: i32, py: i32) bool {
    return (soil == .grass or soil == .dirt) and hit_ny == 1 and py + 2 < 16;
}

test "canPlant check" {
    try std.testing.expect(canPlant(.grass, 1, 5));
    try std.testing.expect(canPlant(.dirt, 1, 5));
    try std.testing.expect(!canPlant(.stone, 1, 5));
    try std.testing.expect(!canPlant(.grass, -1, 5));
    try std.testing.expect(!canPlant(.grass, 1, 14)); // 14 + 2 is not < 16
    try std.testing.expect(canPlant(.grass, 1, 13)); // 13 + 2 is 15 < 16
}

pub const TreeBlockOffset = struct {
    dx: i32,
    dy: i32,
    dz: i32,
    block: BlockId,
};

pub const tree_structure: [12]TreeBlockOffset = init: {
    var offsets: [12]TreeBlockOffset = undefined;
    var idx: usize = 0;
    var gi: i32 = 1;
    while (gi <= trunk_height) : (gi += 1) {
        offsets[idx] = .{ .dx = 0, .dy = gi, .dz = 0, .block = .wood };
        idx += 1;
    }
    var ox: i32 = -1;
    while (ox <= 1) : (ox += 1) {
        var oz: i32 = -1;
        while (oz <= 1) : (oz += 1) {
            if (ox == 0 and oz == 0) continue;
            offsets[idx] = .{ .dx = ox, .dy = trunk_height + 1, .dz = oz, .block = .leaves };
            idx += 1;
        }
    }
    offsets[idx] = .{ .dx = 0, .dy = trunk_height + 1, .dz = 0, .block = .leaves };
    break :init offsets;
};

test "tree structure count and blocks" {
    try std.testing.expectEqual(@as(usize, 12), tree_structure.len);
    var wood_count: usize = 0;
    var leaf_count: usize = 0;
    for (tree_structure) |b| {
        if (b.block == .wood) wood_count += 1;
        if (b.block == .leaves) leaf_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), wood_count);
    try std.testing.expectEqual(@as(usize, 9), leaf_count);
}
