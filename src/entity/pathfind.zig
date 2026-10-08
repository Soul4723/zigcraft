const std = @import("std");

pub const search_radius: i32 = 6;
pub const grid_dim: usize = @intCast(search_radius * 2 + 1); // 13x13 = 169 cells
pub const max_nodes: usize = grid_dim * grid_dim;

pub const Step = struct {
    dx: i32,
    dz: i32,

    pub fn toYaw(self: Step) f32 {
        return std.math.atan2(@as(f32, @floatFromInt(self.dx)), @as(f32, @floatFromInt(self.dz)));
    }
};

const Node = struct {
    gx: i32,
    gz: i32,
    g_cost: u16,
    f_cost: u16,
    parent_idx: u16, // index in nodes array; max_nodes = none
    open: bool,
    closed: bool,
};

const cardinal_dirs = [_][2]i32{
    .{ 1, 0 },
    .{ -1, 0 },
    .{ 0, 1 },
    .{ 0, -1 },
};

fn manhattan(x1: i32, z1: i32, x2: i32, z2: i32) u16 {
    const dx: u32 = @abs(x1 - x2);
    const dz: u32 = @abs(z1 - z2);
    return @intCast(@min(dx + dz, std.math.maxInt(u16)));
}

fn cellIndex(start_x: i32, start_z: i32, x: i32, z: i32) ?usize {
    const lx = x - (start_x - search_radius);
    const lz = z - (start_z - search_radius);
    if (lx < 0 or lx >= @as(i32, @intCast(grid_dim))) return null;
    if (lz < 0 or lz >= @as(i32, @intCast(grid_dim))) return null;
    return @intCast(lz * @as(i32, @intCast(grid_dim)) + lx);
}

/// Find next single step along the shortest path from (start_x, start_z) to (target_x, target_z).
/// `is_walkable` is a query function returning true if the integer (x, z) cell can be stepped into.
/// Returns null if start == target, target unreachable, or blocked immediately.
pub fn findNextStep(
    start_x: i32,
    start_z: i32,
    target_x: i32,
    target_z: i32,
    walkable_ctx: anytype,
    is_walkable: *const fn (ctx: @TypeOf(walkable_ctx), x: i32, z: i32) bool,
) ?Step {
    if (start_x == target_x and start_z == target_z) return null;

    var nodes: [max_nodes]Node = undefined;
    for (&nodes) |*n| {
        n.g_cost = std.math.maxInt(u16);
        n.f_cost = std.math.maxInt(u16);
        n.parent_idx = @intCast(max_nodes);
        n.open = false;
        n.closed = false;
    }

    const start_idx = cellIndex(start_x, start_z, start_x, start_z) orelse return null;
    nodes[start_idx].gx = start_x;
    nodes[start_idx].gz = start_z;
    nodes[start_idx].g_cost = 0;
    nodes[start_idx].f_cost = manhattan(start_x, start_z, target_x, target_z);
    nodes[start_idx].open = true;

    var closest_idx = start_idx;
    var closest_h = nodes[start_idx].f_cost;

    var iter: usize = 0;
    while (iter < max_nodes) : (iter += 1) {
        // Pick open node with lowest f_cost
        var best_idx: ?usize = null;
        var best_f: u16 = std.math.maxInt(u16);
        for (nodes, 0..) |n, i| {
            if (n.open and n.f_cost < best_f) {
                best_f = n.f_cost;
                best_idx = i;
            }
        }
        const cur_idx = best_idx orelse break;
        const cur = &nodes[cur_idx];
        cur.open = false;
        cur.closed = true;

        if (cur.gx == target_x and cur.gz == target_z) {
            closest_idx = cur_idx;
            break;
        }

        const h = manhattan(cur.gx, cur.gz, target_x, target_z);
        if (h < closest_h) {
            closest_h = h;
            closest_idx = cur_idx;
        }

        // Expand cardinal neighbors
        for (cardinal_dirs) |d| {
            const nx = cur.gx + d[0];
            const nz = cur.gz + d[1];
            const n_idx = cellIndex(start_x, start_z, nx, nz) orelse continue;
            if (nodes[n_idx].closed) continue;
            if (!is_walkable(walkable_ctx, nx, nz)) continue;

            const tentative_g = cur.g_cost + 1;
            if (!nodes[n_idx].open or tentative_g < nodes[n_idx].g_cost) {
                nodes[n_idx].gx = nx;
                nodes[n_idx].gz = nz;
                nodes[n_idx].g_cost = tentative_g;
                nodes[n_idx].f_cost = tentative_g + manhattan(nx, nz, target_x, target_z);
                nodes[n_idx].parent_idx = @intCast(cur_idx);
                nodes[n_idx].open = true;
            }
        }
    }

    if (closest_idx == start_idx) return null;

    // Backtrack from closest_idx to the node immediately following start
    var trace = closest_idx;
    while (nodes[trace].parent_idx != start_idx and nodes[trace].parent_idx < max_nodes) {
        trace = nodes[trace].parent_idx;
    }

    return Step{
        .dx = nodes[trace].gx - start_x,
        .dz = nodes[trace].gz - start_z,
    };
}

// Tests
const TestGrid = struct {
    blocked: [13][13]bool = @splat(@splat(false)),

    pub fn isWalkable(self: *const TestGrid, x: i32, z: i32) bool {
        // Grid centered at (0, 0), spans -6..+6
        const lx = x + 6;
        const lz = z + 6;
        if (lx < 0 or lx >= 13 or lz < 0 or lz >= 13) return false;
        return !self.blocked[@intCast(lz)][@intCast(lx)];
    }
};

test "direct straight-line path" {
    var grid = TestGrid{};
    const step = findNextStep(0, 0, 3, 0, &grid, TestGrid.isWalkable);
    try std.testing.expect(step != null);
    try std.testing.expectEqual(@as(i32, 1), step.?.dx);
    try std.testing.expectEqual(@as(i32, 0), step.?.dz);
}

test "already at goal returns null" {
    var grid = TestGrid{};
    const step = findNextStep(2, 2, 2, 2, &grid, TestGrid.isWalkable);
    try std.testing.expect(step == null);
}

test "navigate around wall obstacle" {
    var grid = TestGrid{};
    // Place wall across path from (0, 0) to (3, 0): blocks (1, -1), (1, 0), (1, 1)
    grid.blocked[6 + 0][6 + 1] = true;
    grid.blocked[6 - 1][6 + 1] = true;
    grid.blocked[6 + 1][6 + 1] = true;

    // Path must divert around wall along Z axis first (either +Z or -Z)
    const step = findNextStep(0, 0, 3, 0, &grid, TestGrid.isWalkable);
    try std.testing.expect(step != null);
    try std.testing.expectEqual(@as(i32, 0), step.?.dx);
    try std.testing.expect(step.?.dz == 1 or step.?.dz == -1);
}

test "fully blocked returns null" {
    var grid = TestGrid{};
    // Surround start with walls
    grid.blocked[6 + 1][6 + 0] = true;
    grid.blocked[6 - 1][6 + 0] = true;
    grid.blocked[6 + 0][6 + 1] = true;
    grid.blocked[6 + 0][6 - 1] = true;

    const step = findNextStep(0, 0, 4, 0, &grid, TestGrid.isWalkable);
    try std.testing.expect(step == null);
}

test "step toYaw angle mapping" {
    const east = Step{ .dx = 1, .dz = 0 };
    try std.testing.expectApproxEqAbs(east.toYaw(), std.math.pi * 0.5, 0.001);

    const south = Step{ .dx = 0, .dz = 1 };
    try std.testing.expectApproxEqAbs(south.toYaw(), 0.0, 0.001);
}
