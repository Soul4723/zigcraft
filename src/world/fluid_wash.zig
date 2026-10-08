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
/// World provides getBlockWorld, getWaterLevel, setWaterLevel, and editAndRemesh;
/// edit failures propagate.
///
/// Levels bound lateral spread: level-7 cells are infinite sources (sea, placed
/// water); flowing water spends one unit per tick it spreads and level-0 films
/// evaporate. Falling moves the whole cell down. Cells resupplied the same tick
/// skip depletion, so connected bodies hold their level.
pub fn step(world: anytype, center: [3]i32) !usize {
    var edits: [max_edits]FlowEdit = undefined;
    var count: usize = 0;
    var drains: [max_edits]Cell = undefined;
    var drain_count: usize = 0;
    var depletes: [max_edits]Cell = undefined;
    var deplete_count: usize = 0;
    var x = center[0] - max_spread;
    while (x <= center[0] + max_spread and count < edits.len) : (x += 1) {
        var z = center[2] - max_spread;
        while (z <= center[2] + max_spread and count < edits.len) : (z += 1) {
            var y = @min(center[1] + 2, 15);
            while (y >= @max(center[1] - 3, 0) and count < edits.len) : (y -= 1) {
                if (world.getBlockWorld(x, y, z) != .water) continue;
                const level: u4 = world.getWaterLevel(x, y, z);
                if (y > 0 and shouldFlowDown(world.getBlockWorld(x, y - 1, z))) {
                    // Falling moves the water down; the cell above empties.
                    queueLevel(&edits, &count, .{ .x = x, .y = y - 1, .z = z }, level);
                    queueDrain(&drains, &drain_count, .{ .x = x, .y = y, .z = z });
                    continue;
                }
                if (level == 0) {
                    queueDrain(&drains, &drain_count, .{ .x = x, .y = y, .z = z });
                    continue;
                }
                var spread = false;
                for (flow_dirs) |dir| {
                    const nx = x + dir.dx;
                    const nz = z + dir.dz;
                    if (canFlowInto(world.getBlockWorld(nx, y, nz))) {
                        queueLevel(&edits, &count, .{ .x = nx, .y = y, .z = nz }, level - 1);
                        spread = true;
                    }
                }
                // Level-7 sources are infinite; flowing water spends one unit per spread.
                if (spread and level < 7) {
                    queueDeplete(&depletes, &deplete_count, .{ .x = x, .y = y, .z = z });
                }
            }
        }
    }
    var changed: usize = 0;
    for (edits[0..count]) |edit| {
        if (try world.editAndRemesh(edit.cell.x, edit.cell.y, edit.cell.z, .water)) {
            _ = world.setWaterLevel(edit.cell.x, edit.cell.y, edit.cell.z, edit.level);
            changed += 1;
        }
    }
    for (drains[0..drain_count]) |cell| {
        if (try world.editAndRemesh(cell.x, cell.y, cell.z, .air)) changed += 1;
    }
    for (depletes[0..deplete_count]) |cell| {
        // Skip cells that received water this tick (mutual top-up).
        var topped = false;
        for (edits[0..count]) |edit| {
            if (std.meta.eql(edit.cell, cell)) {
                topped = true;
                break;
            }
        }
        if (topped) continue;
        if (world.getBlockWorld(cell.x, cell.y, cell.z) != .water) continue;
        const cur: u4 = world.getWaterLevel(cell.x, cell.y, cell.z);
        switch (evaluateDeplete(false, cur).action) {
            .keep => {},
            .to_air => {
                if (try world.editAndRemesh(cell.x, cell.y, cell.z, .air)) changed += 1;
            },
            .to_level => {
                if (world.setWaterLevel(cell.x, cell.y, cell.z, cur - 1)) changed += 1;
            },
        }
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

const FlowEdit = struct { cell: Cell, level: u4 };

fn queueLevel(edits: *[max_edits]FlowEdit, count: *usize, cell: Cell, level: u4) void {
    if (count.* == edits.len) return;
    for (edits[0..count.*]) |old| {
        if (std.meta.eql(old.cell, cell)) return;
    }
    edits[count.*] = .{ .cell = cell, .level = level };
    count.* += 1;
}

fn queueDrain(drains: *[max_edits]Cell, count: *usize, cell: Cell) void {
    queue(drains, count, cell);
}

fn queueDeplete(depletes: *[max_edits]Cell, count: *usize, cell: Cell) void {
    queue(depletes, count, cell);
}

pub const DepleteAction = enum { to_air, to_level, keep };

pub const DepleteOutcome = struct { action: DepleteAction, level: u4 };

pub fn evaluateDeplete(received_topup: bool, level: u4) DepleteOutcome {
    if (received_topup) return .{ .action = .keep, .level = level };
    if (level == 0) return .{ .action = .to_air, .level = 0 };
    return .{ .action = .to_level, .level = level - 1 };
}

test "evaluateDeplete outcomes" {
    try std.testing.expectEqual(DepleteAction.keep, evaluateDeplete(true, 5).action);
    try std.testing.expectEqual(DepleteAction.to_air, evaluateDeplete(false, 0).action);
    const d = evaluateDeplete(false, 4);
    try std.testing.expectEqual(DepleteAction.to_level, d.action);
    try std.testing.expectEqual(@as(u4, 3), d.level);
}

const TestWorld = struct {
    blocks: [5][5][5]BlockId = @splat(@splat(@splat(.stone))),
    levels: [5][5][5]u4 = @splat(@splat(@splat(0))),
    fail: bool = false,
    reject: bool = false,

    pub fn getBlockWorld(self: *const TestWorld, x: i32, y: i32, z: i32) BlockId {
        if (x < 0 or x >= 5 or y < 0 or y >= 5 or z < 0 or z >= 5) return .stone;
        return self.blocks[@intCast(y)][@intCast(z)][@intCast(x)];
    }

    pub fn getWaterLevel(self: *const TestWorld, x: i32, y: i32, z: i32) u4 {
        if (x < 0 or x >= 5 or y < 0 or y >= 5 or z < 0 or z >= 5) return 0;
        if (self.blocks[@intCast(y)][@intCast(z)][@intCast(x)] != .water) return 0;
        return self.levels[@intCast(y)][@intCast(z)][@intCast(x)];
    }

    pub fn setWaterLevel(self: *TestWorld, x: i32, y: i32, z: i32, level: u4) bool {
        if (x < 0 or x >= 5 or y < 0 or y >= 5 or z < 0 or z >= 5) return false;
        if (self.blocks[@intCast(y)][@intCast(z)][@intCast(x)] != .water) return false;
        self.levels[@intCast(y)][@intCast(z)][@intCast(x)] = level;
        return true;
    }

    pub fn editAndRemesh(self: *TestWorld, x: i32, y: i32, z: i32, block: BlockId) !bool {
        if (self.fail) return error.TestRemeshFailed;
        if (self.reject) return false;
        if (x < 0 or x >= 5 or y < 0 or y >= 5 or z < 0 or z >= 5) return false;
        self.blocks[@intCast(y)][@intCast(z)][@intCast(x)] = block;
        if (block != .water) self.levels[@intCast(y)][@intCast(z)][@intCast(x)] = 0;
        return true;
    }

    pub fn setWater(self: *TestWorld, x: usize, y: usize, z: usize, level: u4) void {
        self.blocks[y][z][x] = .water;
        self.levels[y][z][x] = level;
    }
};

test "water spreads over solid floor without same-tick cascades" {
    var world = TestWorld{};
    world.blocks[1] = @splat(@splat(.air));
    world.setWater(2, 1, 2, 7);
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
    world.setWater(2, 2, 2, 5);
    world.blocks[1][2][2] = .air;
    world.blocks[0][2][2] = .air;
    // Move = 1 edit below (water) + 1 edit above (drained to air).
    try std.testing.expectEqual(@as(usize, 2), try step(&world, .{ 2, 2, 2 }));
    try std.testing.expectEqual(BlockId.water, world.getBlockWorld(2, 1, 2));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(2, 2, 2));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(2, 0, 2));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(3, 2, 2));
}

test "water crosses ledges but preserves occupied cells" {
    var world = TestWorld{};
    world.setWater(2, 1, 2, 7);
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
    world.setWater(1, 1, 1, 7);
    world.setWater(3, 1, 1, 7);
    try std.testing.expectEqual(@as(usize, 7), try step(&world, .{ 2, 1, 2 }));
    world.blocks[1] = @splat(@splat(.air));
    world.levels[1] = @splat(@splat(0));
    world.setWater(1, 1, 1, 7);
    world.setWater(3, 1, 3, 7);
    world.setWater(3, 1, 1, 7);
    try std.testing.expectEqual(@as(usize, 8), try step(&world, .{ 2, 1, 2 }));
}

test "water remesh errors propagate" {
    var world = TestWorld{ .fail = true };
    world.setWater(2, 1, 2, 7);
    world.blocks[0][2][2] = .air;
    try std.testing.expectError(error.TestRemeshFailed, step(&world, .{ 2, 1, 2 }));
}

test "water respects bottom boundary and rejected edits" {
    var world = TestWorld{};
    world.setWater(2, 0, 2, 7);
    world.blocks[0][2][3] = .air;
    try std.testing.expectEqual(@as(usize, 1), try step(&world, .{ 2, 0, 2 }));
    world.blocks[0][2][3] = .air;
    world.reject = true;
    try std.testing.expectEqual(@as(usize, 0), try step(&world, .{ 2, 0, 2 }));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(3, 0, 2));
    try std.testing.expectEqual(@as(usize, 0), try step(&world, .{ 2, 20, 2 }));
}

test "flowing non-source water depletes when spreading" {
    var world = TestWorld{};
    world.blocks[1] = @splat(@splat(.air));
    // Level 3 spreads laterally to 4 neighbors and spends 1 unit (drops to 2).
    world.setWater(2, 1, 2, 3);
    _ = try step(&world, .{ 2, 1, 2 });
    try std.testing.expectEqual(@as(u4, 2), world.getWaterLevel(2, 1, 2));
}

test "level seven sources remain full when spreading" {
    var world = TestWorld{};
    world.blocks[1] = @splat(@splat(.air));
    world.setWater(2, 1, 2, 7);
    _ = try step(&world, .{ 2, 1, 2 });
    try std.testing.expectEqual(@as(u4, 7), world.getWaterLevel(2, 1, 2));
}

test "lateral spread decrements level" {
    var world = TestWorld{};
    world.blocks[1] = @splat(@splat(.air));
    world.setWater(2, 1, 2, 3);
    _ = try step(&world, .{ 2, 1, 2 });
    try std.testing.expectEqual(@as(u4, 2), world.getWaterLevel(3, 1, 2));
    try std.testing.expectEqual(@as(u4, 2), world.getWaterLevel(1, 1, 2));
}

test "level zero films evaporate instead of spreading" {
    var world = TestWorld{};
    world.blocks[1] = @splat(@splat(.air));
    world.setWater(2, 1, 2, 0);
    try std.testing.expectEqual(@as(usize, 1), try step(&world, .{ 2, 1, 2 }));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(2, 1, 2));
    try std.testing.expectEqual(BlockId.air, world.getBlockWorld(3, 1, 2));
}

test "downward flow preserves source level" {
    var world = TestWorld{};
    world.blocks[2] = @splat(@splat(.air));
    world.blocks[1] = @splat(@splat(.air));
    world.blocks[0] = @splat(@splat(.air));
    world.setWater(2, 2, 2, 4);
    _ = try step(&world, .{ 2, 2, 2 });
    try std.testing.expectEqual(@as(u4, 4), world.getWaterLevel(2, 1, 2));
}

pub const WashDebris = struct {
    r: f32,
    g: f32,
    b: f32,
};

pub fn componentWashDebris(block: BlockId) ?WashDebris {
    return switch (block) {
        .redstone_wire_off, .redstone_wire_on => .{ .r = 0.6, .g = 0.1, .b = 0.1 },
        .redstone_torch_off, .redstone_torch_on => .{ .r = 0.7, .g = 0.2, .b = 0.1 },
        .repeater_off, .repeater_on => .{ .r = 0.5, .g = 0.5, .b = 0.5 },
        .pressure_plate_up, .pressure_plate_down => .{ .r = 0.6, .g = 0.4, .b = 0.2 },
        else => null,
    };
}

test "componentWashDebris mapping" {
    try std.testing.expect(componentWashDebris(.redstone_wire_on) != null);
    try std.testing.expectEqual(@as(f32, 0.6), componentWashDebris(.redstone_wire_on).?.r);
    try std.testing.expectEqual(@as(f32, 0.7), componentWashDebris(.redstone_torch_on).?.r);
    try std.testing.expectEqual(@as(f32, 0.5), componentWashDebris(.repeater_off).?.r);
    try std.testing.expectEqual(@as(f32, 0.6), componentWashDebris(.pressure_plate_up).?.r);
    try std.testing.expect(componentWashDebris(.stone) == null);
}

pub const WashAction = enum {
    wash,
    keep,
};

pub fn evaluateComponentWash(cell: BlockId, above: BlockId) WashAction {
    return if (isWashable(cell, above)) .wash else .keep;
}

test "evaluateComponentWash action" {
    try std.testing.expectEqual(WashAction.wash, evaluateComponentWash(.water, .air));
    try std.testing.expectEqual(WashAction.wash, evaluateComponentWash(.redstone_wire_on, .water));
    try std.testing.expectEqual(WashAction.keep, evaluateComponentWash(.redstone_wire_on, .air));
}
