const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const SIZE = chunk_mod.SIZE;
const BlockId = @import("block.zig").BlockId;

/// A single vertex in the mesh.
pub const Vertex = extern struct {
    position: [3]f32,
    normal: [3]f32,
    tex_coord: [2]f32,
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
    // Repeat UV texture across merged quad
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
    if (neighbors) |nbs| {
        var n_idx: usize = 0;
        var lx: usize = 0;
        var ly: usize = 0;
        var lz: usize = 0;
        if (x < 0 or x >= size) {
            n_idx = if (x < 0) 5 else 4;
            lx = if (x < 0) size - 1 else 0;
            ly = @intCast(y);
            lz = @intCast(z);
        } else if (y < 0 or y >= size) {
            n_idx = if (y < 0) 1 else 0;
            lx = @intCast(x);
            ly = if (y < 0) size - 1 else 0;
            lz = @intCast(z);
        } else {
            n_idx = if (z < 0) 2 else 3;
            lx = @intCast(x);
            ly = @intCast(y);
            lz = if (z < 0) size - 1 else 0;
        }
        if (nbs[n_idx]) |neighbor| {
            return neighbor.getBlock(@intCast(lx), @intCast(ly), @intCast(lz));
        }
    }
    return .air;
}

fn shouldRenderFace(my_block: BlockId, adj: BlockId) bool {
    if (my_block == .air) return false;
    if (my_block == .water) return adj != .water;
    return adj.is_transparent();
}

/// Greedy mesher: sweeps 6 face directions across all slices, merges adjacent coplanar faces of identical block types into single quads.
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

    // For each of 6 face directions
    var face_idx: usize = 0;
    while (face_idx < 6) : (face_idx += 1) {
        const dir = face_dirs[face_idx];
        const normal = face_normals[face_idx];

        // Slice axis d (0=x, 1=y, 2=z), u and v are planar axes
        const d: usize = if (dir[0] != 0) 0 else if (dir[1] != 0) 1 else 2;
        const u_axis: usize = (d + 1) % 3;
        const v_axis: usize = (d + 2) % 3;

        var slice: usize = 0;
        while (slice < size) : (slice += 1) {
            // Mask of visible block types on this slice for this face direction
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

            // Greedy merge rectangles from mask
            v = 0;
            while (v < size) : (v += 1) {
                var u: usize = 0;
                while (u < size) {
                    const block = mask[v][u];
                    if (block == .air) {
                        u += 1;
                        continue;
                    }

                    // 1. Determine width of rectangle along u
                    var w: usize = 1;
                    while (u + w < size and mask[v][u + w] == block) : (w += 1) {}

                    // 2. Determine height of rectangle along v
                    var h: usize = 1;
                    outer_h: while (v + h < size) : (h += 1) {
                        var k: usize = 0;
                        while (k < w) : (k += 1) {
                            if (mask[v + h][u + k] != block) break :outer_h;
                        }
                    }

                    // 3. Clear merged rectangle in mask
                    var dy: usize = 0;
                    while (dy < h) : (dy += 1) {
                        var dx: usize = 0;
                        while (dx < w) : (dx += 1) {
                            mask[v + dy][u + dx] = .air;
                        }
                    }

                    // 4. Emit merged quad
                    const fw: f32 = @floatFromInt(w);
                    const fh: f32 = @floatFromInt(h);
                    const tile = block.getFaceTexture(face_idx);
                    const tex = faceTexCoords(tile.x, tile.y, fw, fh);
                    const base_idx: u32 = @intCast(vertices.items.len);

                    // Quad corners in 3D
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

                    // Ensure front-facing winding relative to face normal
                    const winding_normal = (dir[0] + dir[1] + dir[2]) > 0;
                    if (winding_normal) {
                        try vertices.append(allocator, .{ .position = c0, .normal = normal, .tex_coord = tex[0] });
                        try vertices.append(allocator, .{ .position = c1, .normal = normal, .tex_coord = tex[1] });
                        try vertices.append(allocator, .{ .position = c2, .normal = normal, .tex_coord = tex[2] });
                        try vertices.append(allocator, .{ .position = c3, .normal = normal, .tex_coord = tex[3] });
                    } else {
                        try vertices.append(allocator, .{ .position = c0, .normal = normal, .tex_coord = tex[0] });
                        try vertices.append(allocator, .{ .position = c3, .normal = normal, .tex_coord = tex[3] });
                        try vertices.append(allocator, .{ .position = c2, .normal = normal, .tex_coord = tex[2] });
                        try vertices.append(allocator, .{ .position = c1, .normal = normal, .tex_coord = tex[1] });
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

test "single block produces 6 quads" {
    var chunk = Chunk.init();
    chunk.setBlock(7, 7, 7, .stone);

    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    try std.testing.expectEqual(mesh.vertices.len, 24);
    try std.testing.expectEqual(mesh.indices.len, 36);
}

test "fillLayer merges into single 16x16 quad on top and bottom" {
    var chunk = Chunk.init();
    chunk.fillLayer(0, .stone);

    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    // Top: 1 merged quad (4 verts)
    // Bottom: 1 merged quad (4 verts)
    // 4 sides: 16x1 quads each (16 verts)
    // Total = 6 quads = 24 vertices! Down from 2304 vertices in naive meshing.
    try std.testing.expectEqual(mesh.vertices.len, 24);
    try std.testing.expectEqual(mesh.indices.len, 36);
}

test "adjacent blocks merge horizontally" {
    var chunk = Chunk.init();
    chunk.setBlock(2, 2, 2, .stone);
    chunk.setBlock(3, 2, 2, .stone);

    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    // 2 blocks side-by-side: Top, bottom, front, back merge into 1 quad each (4 quads).
    // Left and right are 1 quad each (2 quads). Total 6 quads = 24 verts.
    try std.testing.expectEqual(mesh.vertices.len, 24);
}
