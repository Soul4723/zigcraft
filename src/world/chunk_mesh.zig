const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const SIZE = chunk_mod.SIZE;
const BlockId = @import("block.zig").BlockId;

/// A single vertex in the mesh with per-vertex Ambient Occlusion factor.
pub const Vertex = extern struct {
    position: [3]f32,
    normal: [3]f32,
    tex_coord: [2]f32,
    ao: f32, // 0.0 (fully occluded) to 1.0 (open)
    emissive: f32, // 0.0 = sun-lit, 1.0 = full glow (lamp, torch, live wire)
};

/// A generated mesh ready for rendering.
pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,

    pub fn deinit(self: *Mesh, allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.indices);
    }
};

const face_dirs: [6][3]i32 = .{
    .{ 0, 1, 0 }, // 0: Up (+Y)
    .{ 0, -1, 0 }, // 1: Down (-Y)
    .{ 0, 0, -1 }, // 2: North (-Z)
    .{ 0, 0, 1 }, // 3: South (+Z)
    .{ 1, 0, 0 }, // 4: East (+X)
    .{ -1, 0, 0 }, // 5: West (-X)
};

const face_normals: [6][3]f32 = .{
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
};

fn faceTexCoords(tile_x: u32, tile_y: u32, w: f32, h: f32) [4][2]f32 {
    _ = w;
    _ = h;
    const tile_size: f32 = 0.125; // 8x8 atlas
    const u_min = @as(f32, @floatFromInt(tile_x)) * tile_size;
    const v_min = @as(f32, @floatFromInt(tile_y)) * tile_size;
    const u_max = u_min + tile_size;
    const v_max = v_min + tile_size;
    return .{
        .{ u_min, v_min },
        .{ u_max, v_min },
        .{ u_max, v_max },
        .{ u_min, v_max },
    };
}

fn getBlockSafe(
    chunk: *const Chunk,
    neighbors: ?*const [6]?*const Chunk,
    x: i32,
    y: i32,
    z: i32,
) BlockId {
    const size: i32 = @intCast(SIZE);
    if (x >= 0 and x < size and y >= 0 and y < size and z >= 0 and z < size) {
        return chunk.getBlock(@intCast(x), @intCast(y), @intCast(z));
    }
    // Vertical chunk out-of-bounds (chunks are 16 blocks tall)
    if (y < 0 or y >= size) return .air;

    if (neighbors) |nbs| {
        // Can only lookup direct cardinal neighbor chunk if only one axis is out of bounds
        if ((x < 0 or x >= size) and (z >= 0 and z < size)) {
            const n_idx: usize = if (x < 0) 5 else 4;
            const lx: usize = if (x < 0) @as(usize, @intCast(size - 1)) else 0;
            if (nbs[n_idx]) |neighbor| {
                return neighbor.getBlock(@intCast(lx), @intCast(y), @intCast(z));
            }
        } else if ((z < 0 or z >= size) and (x >= 0 and x < size)) {
            const n_idx: usize = if (z < 0) 2 else 3;
            const lz: usize = if (z < 0) @as(usize, @intCast(size - 1)) else 0;
            if (nbs[n_idx]) |neighbor| {
                return neighbor.getBlock(@intCast(x), @intCast(y), @intCast(lz));
            }
        }
    }
    return .air;
}

fn levelAtSafe(
    chunk: *const Chunk,
    neighbors: ?*const [6]?*const Chunk,
    x: i32,
    y: i32,
    z: i32,
) u4 {
    const size: i32 = @intCast(SIZE);
    if (x >= 0 and x < size and y >= 0 and y < size and z >= 0 and z < size) {
        return chunk.getLevel(@intCast(x), @intCast(y), @intCast(z));
    }
    if (y < 0 or y >= size) return 0;
    if (neighbors) |nbs| {
        if ((x < 0 or x >= size) and (z >= 0 and z < size)) {
            const n_idx: usize = if (x < 0) 5 else 4;
            const lx: usize = if (x < 0) @as(usize, @intCast(size - 1)) else 0;
            if (nbs[n_idx]) |neighbor| {
                return neighbor.getLevel(@intCast(lx), @intCast(y), @intCast(z));
            }
        } else if ((z < 0 or z >= size) and (x >= 0 and x < size)) {
            const n_idx: usize = if (z < 0) 2 else 3;
            const lz: usize = if (z < 0) @as(usize, @intCast(size - 1)) else 0;
            if (nbs[n_idx]) |neighbor| {
                return neighbor.getLevel(@intCast(x), @intCast(y), @intCast(lz));
            }
        }
    }
    return 0;
}

/// Rendered surface height of water level 0..7 as fraction of block.
/// Full sources sit just below the top face to avoid z-fighting; films sink lower.
pub fn waterSurfaceHeight(level: u4) f32 {
    return switch (level) {
        7 => 0.9,
        6 => 0.8,
        5 => 0.7,
        4 => 0.6,
        3 => 0.5,
        2 => 0.4,
        else => 0.3,
    };
}

fn shouldRenderFace(my_block: BlockId, adj: BlockId) bool {
    if (my_block == .air) return false;
    if (my_block == .water) return adj != .water;
    return adj.is_transparent();
}

/// Water-vs-water faces render only when surfaces sit at different heights.
fn shouldRenderWaterFace(my_level: u4, adj: BlockId, adj_level: u4) bool {
    if (adj != .water) return true;
    return waterSurfaceHeight(my_level) != waterSurfaceHeight(adj_level);
}

/// Calculate vertex Ambient Occlusion factor (0.0 to 1.0) by sampling 2 side neighbors and 1 corner neighbor.
fn vertexAO(side1: bool, side2: bool, corner: bool) f32 {
    if (side1 and side2) return 0.2; // Both adjacent sides occlude
    var count: f32 = 0;
    if (side1) count += 1;
    if (side2) count += 1;
    if (corner) count += 1;
    return 1.0 - (count * 0.25);
}

/// Greedy mesher: sweeps 6 face directions across all slices, merges adjacent coplanar faces of identical block types, calculates vertex AO.
pub fn generateMesh(
    allocator: std.mem.Allocator,
    chunk: *const Chunk,
    neighbors: ?*const [6]?*const Chunk,
) !Mesh {
    var vertices = std.ArrayList(Vertex).empty;
    defer vertices.deinit(allocator);

    var indices = std.ArrayList(u32).empty;
    defer indices.deinit(allocator);

    const size: usize = SIZE;

    var face_idx: usize = 0;
    while (face_idx < 6) : (face_idx += 1) {
        const dir = face_dirs[face_idx];
        const normal = face_normals[face_idx];

        const d: usize = if (dir[0] != 0) 0 else if (dir[1] != 0) 1 else 2;
        const u_axis: usize = (d + 1) % 3;
        const v_axis: usize = (d + 2) % 3;

        var slice: usize = 0;
        while (slice < size) : (slice += 1) {
            var mask: [SIZE][SIZE]BlockId = undefined;
            for (&mask) |*row| @memset(row, .air);
            var mask_level: [SIZE][SIZE]u4 = undefined;
            for (&mask_level) |*row| @memset(row, 0);

            var v: usize = 0;
            while (v < size) : (v += 1) {
                var u: usize = 0;
                while (u < size) : (u += 1) {
                    var pos: [3]i32 = undefined;
                    pos[d] = @intCast(slice);
                    pos[u_axis] = @intCast(u);
                    pos[v_axis] = @intCast(v);

                    const block = chunk.getBlock(@intCast(pos[0]), @intCast(pos[1]), @intCast(pos[2]));
                    if (block == .air) continue;

                    const n_pos = [3]i32{ pos[0] + dir[0], pos[1] + dir[1], pos[2] + dir[2] };
                    const adj = getBlockSafe(chunk, neighbors, n_pos[0], n_pos[1], n_pos[2]);

                    if (block == .water) {
                        const my_level: u4 = chunk.getLevel(@intCast(pos[0]), @intCast(pos[1]), @intCast(pos[2]));
                        const adj_level: u4 = levelAtSafe(chunk, neighbors, n_pos[0], n_pos[1], n_pos[2]);
                        if (shouldRenderWaterFace(my_level, adj, adj_level)) {
                            mask[v][u] = block;
                            mask_level[v][u] = my_level;
                        }
                    } else if (shouldRenderFace(block, adj)) {
                        mask[v][u] = block;
                    }
                }
            }

            v = 0;
            while (v < size) : (v += 1) {
                var u: usize = 0;
                while (u < size) {
                    const block = mask[v][u];
                    if (block == .air) {
                        u += 1;
                        continue;
                    }

                    // Render individual 1x1 block faces so texture atlas coordinates
                    // never stretch or sample neighbor tiles in the 4x4 atlas.
                    const w: usize = 1;
                    const h: usize = 1;

                    var dy: usize = 0;
                    while (dy < h) : (dy += 1) {
                        var dx: usize = 0;
                        while (dx < w) : (dx += 1) {
                            mask[v + dy][u + dx] = .air;
                        }
                    }

                    const fw: f32 = @floatFromInt(w);
                    const fh: f32 = @floatFromInt(h);
                    const tile = block.getFaceTexture(face_idx);
                    const face_emissive = block.emissive();
                    const tex = faceTexCoords(tile.x, tile.y, fw, fh);
                    const base_idx: u32 = @intCast(vertices.items.len);

                    var c0: [3]f32 = undefined;
                    var c1: [3]f32 = undefined;
                    var c2: [3]f32 = undefined;
                    var c3: [3]f32 = undefined;

                    const slice_f: f32 = @floatFromInt(slice);
                    const u_f: f32 = @floatFromInt(u);
                    const v_f: f32 = @floatFromInt(v);

                    const d_coord: f32 = if (dir[d] > 0) slice_f + 1.0 else slice_f;

                    c0[d] = d_coord;
                    c0[u_axis] = u_f;
                    c0[v_axis] = v_f;

                    c1[d] = d_coord;
                    c1[u_axis] = u_f + fw;
                    c1[v_axis] = v_f;

                    c2[d] = d_coord;
                    c2[u_axis] = u_f + fw;
                    c2[v_axis] = v_f + fh;

                    c3[d] = d_coord;
                    c3[u_axis] = u_f;
                    c3[v_axis] = v_f + fh;

                    // Shallow water surfaces sit below the block top.
                    if (block == .water) {
                        // Cell Y along whichever axis is vertical here.
                        const cell_y: f32 = if (d == 1) slice_f else if (u_axis == 1) u_f else v_f;
                        const surface = cell_y + waterSurfaceHeight(mask_level[v][u]);
                        if (d == 1 and dir[d] > 0) {
                            c0[d] = surface;
                            c1[d] = surface;
                            c2[d] = surface;
                            c3[d] = surface;
                        } else if (d != 1) {
                            // Side faces: lower verts on the top edge to the surface.
                            const top_y = cell_y + 1.0;
                            if (c0[1] == top_y) c0[1] = surface;
                            if (c1[1] == top_y) c1[1] = surface;
                            if (c2[1] == top_y) c2[1] = surface;
                            if (c3[1] == top_y) c3[1] = surface;
                        }
                    }

                    // Calculate Ambient Occlusion for each 4 corners
                    const n_d: i32 = @as(i32, @intCast(slice)) + dir[d];
                    const u_start_i: i32 = @intCast(u);
                    const u_end_i: i32 = @intCast(u + w);
                    const v_start_i: i32 = @intCast(v);
                    const v_end_i: i32 = @intCast(v + h);

                    var p_test: [3]i32 = undefined;
                    p_test[d] = n_d;

                    // Helper to test if block at relative offset from corner is solid
                    const isSolidAt = struct {
                        fn check(ch: *const Chunk, nbs: ?*const [6]?*const Chunk, pt: *[3]i32, da: usize, ua: usize, va: usize, du: i32, dv: i32) bool {
                            pt.*[ua] += du;
                            pt.*[va] += dv;
                            const b = getBlockSafe(ch, nbs, pt.*[0], pt.*[1], pt.*[2]);
                            pt.*[ua] -= du;
                            pt.*[va] -= dv;
                            _ = da;
                            return b.is_solid();
                        }
                    }.check;

                    // c0 (u0, v0)
                    p_test[u_axis] = u_start_i;
                    p_test[v_axis] = v_start_i;
                    const s1_0 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, -1, 0);
                    const s2_0 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, 0, -1);
                    const cr_0 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, -1, -1);
                    const ao0 = vertexAO(s1_0, s2_0, cr_0);

                    // c1 (u1, v0)
                    p_test[u_axis] = u_end_i;
                    p_test[v_axis] = v_start_i;
                    const s1_1 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, 0, 0);
                    const s2_1 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, -1, -1);
                    const cr_1 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, 0, -1);
                    const ao1 = vertexAO(s1_1, s2_1, cr_1);

                    // c2 (u1, v1)
                    p_test[u_axis] = u_end_i;
                    p_test[v_axis] = v_end_i;
                    const s1_2 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, 0, 0);
                    const s2_2 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, -1, 0);
                    const cr_2 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, 0, 0);
                    const ao2 = vertexAO(s1_2, s2_2, cr_2);

                    // c3 (u0, v1)
                    p_test[u_axis] = u_start_i;
                    p_test[v_axis] = v_end_i;
                    const s1_3 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, -1, 0);
                    const s2_3 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, 0, 0);
                    const cr_3 = isSolidAt(chunk, neighbors, &p_test, d, u_axis, v_axis, -1, 0);
                    const ao3 = vertexAO(s1_3, s2_3, cr_3);

                    const winding_normal = (dir[0] + dir[1] + dir[2]) > 0;
                    if (winding_normal) {
                        try vertices.append(allocator, .{ .position = c0, .normal = normal, .tex_coord = tex[0], .ao = ao0, .emissive = face_emissive });
                        try vertices.append(allocator, .{ .position = c1, .normal = normal, .tex_coord = tex[1], .ao = ao1, .emissive = face_emissive });
                        try vertices.append(allocator, .{ .position = c2, .normal = normal, .tex_coord = tex[2], .ao = ao2, .emissive = face_emissive });
                        try vertices.append(allocator, .{ .position = c3, .normal = normal, .tex_coord = tex[3], .ao = ao3, .emissive = face_emissive });
                    } else {
                        try vertices.append(allocator, .{ .position = c0, .normal = normal, .tex_coord = tex[0], .ao = ao0, .emissive = face_emissive });
                        try vertices.append(allocator, .{ .position = c3, .normal = normal, .tex_coord = tex[3], .ao = ao3, .emissive = face_emissive });
                        try vertices.append(allocator, .{ .position = c2, .normal = normal, .tex_coord = tex[2], .ao = ao2, .emissive = face_emissive });
                        try vertices.append(allocator, .{ .position = c1, .normal = normal, .tex_coord = tex[1], .ao = ao1, .emissive = face_emissive });
                    }

                    try indices.appendSlice(allocator, &[_]u32{
                        base_idx, base_idx + 1, base_idx + 2,
                        base_idx, base_idx + 2, base_idx + 3,
                    });

                    u += w;
                }
            }
        }
    }

    return Mesh{
        .vertices = try vertices.toOwnedSlice(allocator),
        .indices = try indices.toOwnedSlice(allocator),
    };
}

test "waterSurfaceHeight sinks with level" {
    try std.testing.expectApproxEqAbs(waterSurfaceHeight(7), 0.9, 0.001);
    try std.testing.expectApproxEqAbs(waterSurfaceHeight(0), 0.3, 0.001);
    try std.testing.expect(waterSurfaceHeight(2) < waterSurfaceHeight(5));
}

test "shallow water top face sits below full source" {
    var chunk = Chunk.init();
    chunk.setBlock(7, 7, 7, .water);
    chunk.setLevel(7, 7, 7, 7);
    var full_mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer full_mesh.deinit(std.testing.allocator);

    var shallow = Chunk.init();
    shallow.setBlock(7, 7, 7, .water);
    shallow.setLevel(7, 7, 7, 2);
    var shallow_mesh = try generateMesh(std.testing.allocator, &shallow, null);
    defer shallow_mesh.deinit(std.testing.allocator);

    const topY = struct {
        fn maxTopY(mesh: Mesh) f32 {
            var top: f32 = 0;
            for (mesh.vertices) |v| {
                // Top faces have +Y normals.
                if (v.normal[1] > 0.5 and v.position[1] > top) top = v.position[1];
            }
            return top;
        }
    }.maxTopY;
    try std.testing.expectApproxEqAbs(topY(full_mesh), 7.9, 0.001);
    try std.testing.expectApproxEqAbs(topY(shallow_mesh), 7.4, 0.001);
}

test "side step drops to shallower surface" {
    var chunk = Chunk.init();
    chunk.setBlock(7, 7, 7, .water);
    chunk.setLevel(7, 7, 7, 7);
    chunk.setBlock(8, 7, 7, .water);
    chunk.setLevel(8, 7, 7, 1);
    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);
    // Side verts at the shared edge must sit at or below the full surface (7.9).
    for (mesh.vertices) |vert| {
        if (vert.normal[1] == 0.0) {
            try std.testing.expect(vert.position[1] <= 7.901);
        }
    }
}

test "adjacent water levels render a step face" {
    var chunk = Chunk.init();
    chunk.setBlock(7, 7, 7, .water);
    chunk.setLevel(7, 7, 7, 7);
    chunk.setBlock(8, 7, 7, .water);
    chunk.setLevel(8, 7, 7, 1);
    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);
    // Two top quads (8 verts) + shared step side quad (4 verts) = 12+ verts.
    try std.testing.expect(mesh.vertices.len >= 12);
}

test "empty chunk produces no mesh" {
    const chunk = Chunk.init();
    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    try std.testing.expectEqual(mesh.vertices.len, 0);
    try std.testing.expectEqual(mesh.indices.len, 0);
}

test "single block produces 6 quads with AO" {
    var chunk = Chunk.init();
    chunk.setBlock(7, 7, 7, .stone);

    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    try std.testing.expectEqual(mesh.vertices.len, 24);
    try std.testing.expectEqual(mesh.indices.len, 36);
    // Standalone block should have zero occlusions -> AO=1.0 for all vertices
    for (mesh.vertices) |v| {
        try std.testing.expect(v.ao >= 0.99);
    }
}

test "vertex layout contains ao field" {
    try std.testing.expectEqual(@sizeOf(Vertex), (3 + 3 + 2 + 1 + 1) * @sizeOf(f32));
}

test "torch face carries emissive, stone does not" {
    var chunk = Chunk.init();
    chunk.setBlock(7, 7, 7, .torch);
    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);
    try std.testing.expect(mesh.vertices.len > 0);
    for (mesh.vertices) |v| {
        try std.testing.expectApproxEqAbs(v.emissive, 0.9, 0.001);
    }
    var rock = Chunk.init();
    rock.setBlock(7, 7, 7, .stone);
    var rock_mesh = try generateMesh(std.testing.allocator, &rock, null);
    defer rock_mesh.deinit(std.testing.allocator);
    for (rock_mesh.vertices) |v| {
        try std.testing.expectEqual(v.emissive, 0.0);
    }
}
