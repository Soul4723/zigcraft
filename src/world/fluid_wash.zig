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

const Cell = struct { x: i32, y: i32, z: i32 };
const max_edits = 8;

/// Advance nearby water once, reading all candidates before applying edits.
/// World provides getBlockWorld and editAndRemesh; edit failures propagate.
// ponytail: copied water remains a source; finite levels and drainage need persisted fluid metadata.
pub fn step(world: anytype, center: [3]i32) !usize {
    var edits: [max_edits]Cell = undefined;
    var count: usize = 0;
    var x = center[0] - max_spread;
    while (x <= center[0] + max_spread and count < edits.len) : (x += 1) {
        var z = center[2] - max_spread;
        while (z <= center[2] + max_spread and count < edits.len) : (z += 1) {
            var y = @min(center[1] + 2, 15);
            while (y >= @max(center[1] - 3, 0) and count < edits.len) : (y -= 1) {
                if (world.getBlockWorld(x, y, z) != .water) continue;
                if (y > 0 and shouldFlowDown(world.getBlockWorld(x, y - 1, z))) {
                    queue(&edits, &count, .{ .x = x, .y = y - 1, .z = z });
                    continue;
                }
                for (flow_dirs) |dir| {
                    const nx = x + dir.dx;
                    const nz = z + dir.dz;
                    if (canFlowInto(world.getBlockWorld(nx, y, nz))) {
                        queue(&edits, &count, .{ .x = nx, .y = y, .z = nz });
                    }
                }
            }
        }
    }
    var changed: usize = 0;
    for (edits[0..count]) |cell| {
        if (try world.editAndRemesh(cell.x, cell.y, cell.z, .water)) changed += 1;
    }
    return changed;
}

fn queue(edits: *[max_edits]Cell, count: *usize, cell: Cell) void {
    if (count.* == edits.len) return;
    for (edits[0..count.*]) |old| {
        if (std.meta.eql(old, cell)) return;
    }
    edits[count.*] = cell;
    count.* += 1;
}

const TestWorld = struct {
    blocks: [5][5][5]BlockId = @splat(@splat(@splat(.stone))),
    fail: bool = false,
    reject: bool = false,

    pub fn getBlockWorld(self: *const TestWorld, x: i32, y: i32, z: i32) BlockId {
        if (x < 0 or x >= 5 or y < 0 or y >= 5 or z < 0 or z >= 5) return .stone;
        return self.blocks[@intCast(y)][@intCast(z)][@intCast(x)];
    }

    pub fn editAndRemesh(self: *TestWorld, x: i32, y: i32, z: i32, block: BlockId) !bool {
        if (self.fail) return error.TestRemeshFailed;
        if (self.reject) return false;
        if (x < 0 or x >= 5 or y < 0 or y >= 5 or z < 0 or z >= 5) return false;
        self.blocks[@intCast(y)][@intCast(z)][@intCast(x)] = block;
        return true;
    }
};

test "water spreads over solid floor without same-tick cascades" {
    var world = TestWorld{};
    world.blocks[1] = @splat(@splat(.air));
    world.blocks[1][2][2] = .water;
    try std.testing.expectEqual(@as(usize, 4), try step(&world, .{ 2, 1, 2 }));
    try std.testing.expectEqual(BlockId.water, world.getBlockWorld(3, 1, 2));
    try std.testing.expectEqual(BlockId.water, world.getBlockWorld(1, 1, 2));
    try std.testing.expectEqual(BlockId.water, world.getBlockWorld(2, 1, 3));
    try std.testing.expectEqual(BlockId.water, world.getBlockWorld(2, 1, 1));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(4, 1, 2));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(2, 1, 0));
}

test "water falls before spreading and descends one cell per tick" {
    var world = TestWorld{};
    world.blocks[2] = @splat(@splat(.air));
    world.blocks[2][2][2] = .water;
    world.blocks[1][2][2] = .air;
    world.blocks[0][2][2] = .air;
    try std.testing.expectEqual(@as(usize, 1), try step(&world, .{ 2, 2, 2 }));
    try std.testing.expectEqual(BlockId.water, world.getBlockWorld(2, 1, 2));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(2, 0, 2));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(3, 2, 2));
}

test "water crosses ledges but preserves occupied cells" {
    var world = TestWorld{};
    world.blocks[1][2][2] = .water;
    world.blocks[1][2][3] = .air;
    world.blocks[0][2][3] = .air;
    world.blocks[1][2][1] = .torch;
    try std.testing.expectEqual(@as(usize, 1), try step(&world, .{ 2, 1, 2 }));
    try std.testing.expectEqual(BlockId.water, world.getBlockWorld(3, 1, 2));
    try std.testing.expectEqual(BlockId.torch, world.getBlockWorld(1, 1, 2));
}

test "water tick deduplicates edits and caps work" {
    var world = TestWorld{};
    world.blocks[1] = @splat(@splat(.air));
    world.blocks[1][1][1] = .water;
    world.blocks[1][1][3] = .water;
    try std.testing.expectEqual(@as(usize, 7), try step(&world, .{ 2, 1, 2 }));
    world.blocks[1] = @splat(@splat(.air));
    world.blocks[1][1][1] = .water;
    world.blocks[1][3][3] = .water;
    world.blocks[1][1][3] = .water;
    try std.testing.expectEqual(@as(usize, 8), try step(&world, .{ 2, 1, 2 }));
}

test "water remesh errors propagate" {
    var world = TestWorld{ .fail = true };
    world.blocks[1][2][2] = .water;
    world.blocks[0][2][2] = .air;
    try std.testing.expectError(error.TestRemeshFailed, step(&world, .{ 2, 1, 2 }));
}

test "water respects bottom boundary and rejected edits" {
    var world = TestWorld{};
    world.blocks[0][2][2] = .water;
    world.blocks[0][2][3] = .air;
    try std.testing.expectEqual(@as(usize, 1), try step(&world, .{ 2, 0, 2 }));
    world.blocks[0][2][3] = .air;
    world.reject = true;
    try std.testing.expectEqual(@as(usize, 0), try step(&world, .{ 2, 0, 2 }));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(3, 0, 2));
    try std.testing.expectEqual(@as(usize, 0), try step(&world, .{ 2, 20, 2 }));
}
