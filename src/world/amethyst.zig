const std = @import("std");

pub const max_budding_nodes: usize = 32;
pub const crystal_growth_interval: f32 = 30.0;
pub const bell_highlight_radius_sq: f32 = 1024.0;
pub const bell_glow_duration: f32 = 12.0;

pub const BuddingNode = struct {
    x: i32,
    y: i32,
    z: i32,
    timer: f32 = 0.0,
    cycles: u8 = 0,
};

pub fn tickBuddingNode(node: *BuddingNode, dt: f32) bool {
    node.timer += dt;
    if (node.timer >= crystal_growth_interval) {
        node.timer -= crystal_growth_interval;
        node.cycles +%= 1;
        return true;
    }
    return false;
}

pub fn findBuddingNode(nodes: []const BuddingNode, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, nodes.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const node = nodes[i];
        if (node.x == x and node.y == y and node.z == z) return i;
    }
    return null;
}

pub fn clusterShardYield(mined_with_pickaxe: bool) u8 {
    return if (mined_with_pickaxe) 4 else 2;
}

pub fn isWithinBellHighlightRange(bx: i32, by: i32, bz: i32, mx: f32, my: f32, mz: f32) bool {
    const cx = @as(f32, @floatFromInt(bx)) + 0.5;
    const cy = @as(f32, @floatFromInt(by)) + 0.5;
    const cz = @as(f32, @floatFromInt(bz)) + 0.5;
    const dx = cx - mx;
    const dy = cy - my;
    const dz = cz - mz;
    const dist_sq = dx * dx + dy * dy + dz * dz;
    return dist_sq <= bell_highlight_radius_sq;
}

pub fn chimePitchMultiplier(step_index: u8) f32 {
    return 1.0 + @as(f32, @floatFromInt(step_index % 5)) * 0.12;
}

test "constants" {
    try std.testing.expectEqual(@as(usize, 32), max_budding_nodes);
    try std.testing.expectEqual(@as(f32, 30.0), crystal_growth_interval);
    try std.testing.expectEqual(@as(f32, 1024.0), bell_highlight_radius_sq);
    try std.testing.expectEqual(@as(f32, 12.0), bell_glow_duration);
}

test "BuddingNode defaults" {
    const node = BuddingNode{ .x = 1, .y = 2, .z = 3 };
    try std.testing.expectEqual(@as(i32, 1), node.x);
    try std.testing.expectEqual(@as(i32, 2), node.y);
    try std.testing.expectEqual(@as(i32, 3), node.z);
    try std.testing.expectEqual(@as(f32, 0.0), node.timer);
    try std.testing.expectEqual(@as(u8, 0), node.cycles);
}

test "tickBuddingNode below interval" {
    var node = BuddingNode{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!tickBuddingNode(&node, 10.0));
    try std.testing.expectEqual(@as(f32, 10.0), node.timer);
    try std.testing.expectEqual(@as(u8, 0), node.cycles);
    try std.testing.expect(!tickBuddingNode(&node, 19.9));
    try std.testing.expectEqual(@as(u8, 0), node.cycles);
}

test "tickBuddingNode reaching interval" {
    var node = BuddingNode{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!tickBuddingNode(&node, 29.9));
    try std.testing.expect(tickBuddingNode(&node, 0.1));
    try std.testing.expectEqual(@as(u8, 1), node.cycles);
    try std.testing.expectEqual(@as(f32, 0.0), node.timer);
}

test "tickBuddingNode subtracts one interval and keeps remainder" {
    var node = BuddingNode{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(tickBuddingNode(&node, 35.0));
    try std.testing.expectEqual(@as(u8, 1), node.cycles);
    try std.testing.expectEqual(@as(f32, 5.0), node.timer);
}

test "tickBuddingNode cycles wrap around" {
    var node = BuddingNode{ .x = 0, .y = 0, .z = 0, .cycles = 255 };
    try std.testing.expect(tickBuddingNode(&node, crystal_growth_interval));
    try std.testing.expectEqual(@as(u8, 0), node.cycles);
}

test "findBuddingNode" {
    var nodes: [max_budding_nodes]BuddingNode = undefined;
    nodes[0] = .{ .x = 1, .y = 2, .z = 3 };
    nodes[1] = .{ .x = 4, .y = 5, .z = 6 };
    nodes[2] = .{ .x = 1, .y = 2, .z = 3 };

    try std.testing.expectEqual(@as(?usize, 0), findBuddingNode(&nodes, 3, 1, 2, 3));
    try std.testing.expectEqual(@as(?usize, 1), findBuddingNode(&nodes, 3, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, null), findBuddingNode(&nodes, 3, 9, 9, 9));
    try std.testing.expectEqual(@as(?usize, null), findBuddingNode(&nodes, 1, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, null), findBuddingNode(&nodes, 0, 1, 2, 3));
    try std.testing.expectEqual(@as(?usize, null), findBuddingNode(&nodes, 100, 100, 100, 100));
}

test "clusterShardYield" {
    try std.testing.expectEqual(@as(u8, 4), clusterShardYield(true));
    try std.testing.expectEqual(@as(u8, 2), clusterShardYield(false));
}

test "isWithinBellHighlightRange inside and on center" {
    try std.testing.expect(isWithinBellHighlightRange(0, 0, 0, 0.5, 0.5, 0.5));
    try std.testing.expect(isWithinBellHighlightRange(0, 0, 0, 0.0, 0.0, 0.0));
}

test "isWithinBellHighlightRange at radius boundary" {
    try std.testing.expect(isWithinBellHighlightRange(0, 0, 0, 32.5, 0.5, 0.5));
    try std.testing.expect(!isWithinBellHighlightRange(0, 0, 0, 32.5001, 0.5, 0.5));
    try std.testing.expect(!isWithinBellHighlightRange(0, 0, 0, 33.0, 0.5, 0.5));
}

test "isWithinBellHighlightRange negative coordinates" {
    try std.testing.expect(isWithinBellHighlightRange(-10, -10, -10, -9.5, -9.5, -9.5));
    try std.testing.expect(!isWithinBellHighlightRange(-10, -10, -10, 100.0, 100.0, 100.0));
}

test "isWithinBellHighlightRange diagonal just outside" {
    const dx: f32 = 20.0;
    try std.testing.expect(!isWithinBellHighlightRange(0, 0, 0, dx, dx, dx));
}

test "chimePitchMultiplier" {
    try std.testing.expectEqual(@as(f32, 1.0), chimePitchMultiplier(0));
    try std.testing.expectEqual(@as(f32, 1.12), chimePitchMultiplier(1));
    try std.testing.expectEqual(@as(f32, 1.24), chimePitchMultiplier(2));
    try std.testing.expectEqual(@as(f32, 1.36), chimePitchMultiplier(3));
    try std.testing.expectEqual(@as(f32, 1.48), chimePitchMultiplier(4));
}

test "chimePitchMultiplier wraps every five steps" {
    try std.testing.expectEqual(@as(f32, 1.0), chimePitchMultiplier(5));
    try std.testing.expectEqual(@as(f32, 1.12), chimePitchMultiplier(6));
    try std.testing.expectEqual(@as(f32, 1.36), chimePitchMultiplier(253));
    try std.testing.expectEqual(@as(f32, 1.48), chimePitchMultiplier(254));
}
