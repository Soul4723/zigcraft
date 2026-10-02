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
    const tile_size: f32 = 0.25; // 4x4 atlas
    const u_min = @as(f32, @floatFromInt(tile_x)) * tile_size;
    const v_min = @as(f32, @floatFromInt(tile_y)) * tile_size;
    const u_max = u_min + tile_size * w;
    const v_max = v_min + tile_size * h;
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

fn shouldRenderFace(my_block: BlockId, adj: BlockId) bool {
    if (my_block == .air) return false;
    if (my_block == .water) return adj != .water;
    return adj.is_transparent();
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

                    if (shouldRenderFace(block, adj)) {
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

                    var w: usize = 1;
                    while (u + w < size and mask[v][u + w] == block) : (w += 1) {}

                    var h: usize = 1;
                    outer_h: while (v + h < size) : (h += 1) {
                        var k: usize = 0;
                        while (k < w) : (k += 1) {
                            if (mask[v + h][u + k] != block) break :outer_h;
                        }
                    }

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
                        try vertices.append(allocator, .{ .position = c0, .normal = normal, .tex_coord = tex[0], .ao = ao0 });
                        try vertices.append(allocator, .{ .position = c1, .normal = normal, .tex_coord = tex[1], .ao = ao1 });
                        try vertices.append(allocator, .{ .position = c2, .normal = normal, .tex_coord = tex[2], .ao = ao2 });
                        try vertices.append(allocator, .{ .position = c3, .normal = normal, .tex_coord = tex[3], .ao = ao3 });
                    } else {
                        try vertices.append(allocator, .{ .position = c0, .normal = normal, .tex_coord = tex[0], .ao = ao0 });
                        try vertices.append(allocator, .{ .position = c3, .normal = normal, .tex_coord = tex[3], .ao = ao3 });
                        try vertices.append(allocator, .{ .position = c2, .normal = normal, .tex_coord = tex[2], .ao = ao2 });
                        try vertices.append(allocator, .{ .position = c1, .normal = normal, .tex_coord = tex[1], .ao = ao1 });
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
    try std.testing.expectEqual(@sizeOf(Vertex), (3 + 3 + 2 + 1) * @sizeOf(f32));
}
