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

/// Face directions as (dx, dy, dz) offsets.
/// Order: up, down, north, south, east, west
const face_dirs: [6][3]i32 = .{
    .{ 0,  1,  0},
    .{ 0, -1,  0},
    .{ 0,  0, -1},
    .{ 0,  0,  1},
    .{ 1,  0,  0},
    .{-1,  0,  0},
};

/// Face normals, matching face_dirs order.
const face_normals: [6][3]f32 = .{
    .{ 0.0,  1.0,  0.0},
    .{ 0.0, -1.0,  0.0},
    .{ 0.0,  0.0, -1.0},
    .{ 0.0,  0.0,  1.0},
    .{ 1.0,  0.0,  0.0},
    .{-1.0,  0.0,  0.0},
};

/// Vertices for the 4 corners of a single face of a unit cube centered at origin.
fn faceVertices(face_index: usize) [4][3]f32 {
    return switch (face_index) {
        0 => .{  // up (+Y)
            .{ -0.5, 0.5,  0.5 },
            .{  0.5, 0.5,  0.5 },
            .{  0.5, 0.5, -0.5 },
            .{ -0.5, 0.5, -0.5 },
        },
        1 => .{  // down (-Y)
            .{ -0.5, -0.5, -0.5 },
            .{  0.5, -0.5, -0.5 },
            .{  0.5, -0.5,  0.5 },
            .{ -0.5, -0.5,  0.5 },
        },
        2 => .{  // north (-Z)
            .{ -0.5, -0.5, -0.5 },
            .{  0.5, -0.5, -0.5 },
            .{  0.5,  0.5, -0.5 },
            .{ -0.5,  0.5, -0.5 },
        },
        3 => .{  // south (+Z)
            .{  0.5, -0.5,  0.5 },
            .{ -0.5, -0.5,  0.5 },
            .{ -0.5,  0.5,  0.5 },
            .{  0.5,  0.5,  0.5 },
        },
        4 => .{  // east (+X)
            .{  0.5, -0.5,  0.5 },
            .{  0.5, -0.5, -0.5 },
            .{  0.5,  0.5, -0.5 },
            .{  0.5,  0.5,  0.5 },
        },
        5 => .{  // west (-X)
            .{ -0.5, -0.5, -0.5 },
            .{ -0.5, -0.5,  0.5 },
            .{ -0.5,  0.5,  0.5 },
            .{ -0.5,  0.5, -0.5 },
        },
        else => unreachable,
    };
}

fn faceTexCoords(tile_x: u32, tile_y: u32) [4][2]f32 {
    const tile_size: f32 = 0.25; // 4x4 atlas
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

/// Check if block face should be rendered against adjacent block.
/// Opaque solid against air/water renders.
/// Water against air or non-water renders (water against water culls).
fn shouldRenderFace(
    my_block: BlockId,
    chunk: *const Chunk,
    neighbors: ?*const [6]?*const Chunk,
    nx: i32,
    ny: i32,
    nz: i32,
) bool {
    const size: i32 = @intCast(SIZE);

    var adj: BlockId = .air;
    if (nx >= 0 and nx < size and ny >= 0 and ny < size and nz >= 0 and nz < size) {
        adj = chunk.getBlock(@intCast(nx), @intCast(ny), @intCast(nz));
    } else if (neighbors) |neighbors_arr| {
        var neighbor_idx: usize = 0;
        var lx: usize = 0;
        var ly: usize = 0;
        var lz: usize = 0;

        if (nx < 0 or nx >= size) {
            neighbor_idx = if (nx < 0) 5 else 4;
            lx = if (nx < 0) size - 1 else 0;
            ly = @intCast(ny);
            lz = @intCast(nz);
        } else if (ny < 0 or ny >= size) {
            neighbor_idx = if (ny < 0) 1 else 0;
            lx = @intCast(nx);
            ly = if (ny < 0) size - 1 else 0;
            lz = @intCast(nz);
        } else {
            neighbor_idx = if (nz < 0) 2 else 3;
            lx = @intCast(nx);
            ly = @intCast(ny);
            lz = if (nz < 0) size - 1 else 0;
        }

        if (neighbors_arr[neighbor_idx]) |neighbor| {
            adj = neighbor.getBlock(@intCast(lx), @intCast(ly), @intCast(lz));
        }
    }

    if (my_block == .water) {
        // Water face rendered if adjacent is air or solid
        return adj != .water;
    } else {
        // Solid block face rendered if adjacent is transparent (air or water)
        return adj.is_transparent();
    }
}

/// Generate a mesh from chunk data using per-face meshing.
pub fn generateMesh(
    allocator: std.mem.Allocator,
    chunk: *const Chunk,
    neighbors: ?*const [6]?*const Chunk,
) !Mesh {
    var vertices = std.ArrayList(Vertex).empty;
    defer vertices.deinit(allocator);

    var indices = std.ArrayList(u32).empty;
    defer indices.deinit(allocator);

    var y: usize = 0;
    while (y < SIZE) : (y += 1) {
        var z: usize = 0;
        while (z < SIZE) : (z += 1) {
            var x: usize = 0;
            while (x < SIZE) : (x += 1) {
                const block = chunk.getBlock(@intCast(x), @intCast(y), @intCast(z));
                if (block == .air) continue;

                var face_idx: usize = 0;
                while (face_idx < 6) : (face_idx += 1) {
                    const dir = face_dirs[face_idx];
                    const nx = @as(i32, @intCast(x)) + dir[0];
                    const ny = @as(i32, @intCast(y)) + dir[1];
                    const nz = @as(i32, @intCast(z)) + dir[2];

                    if (shouldRenderFace(block, chunk, neighbors, nx, ny, nz)) {
                        const corners = faceVertices(face_idx);
                        const normal = face_normals[face_idx];
                        const base_index: u32 = @intCast(vertices.items.len);

                        const tile = block.getFaceTexture(face_idx);
                        const tex_coords = faceTexCoords(tile.x, tile.y);
                        var i: usize = 0;
                        while (i < 4) : (i += 1) {
                            const v = corners[i];
                            try vertices.append(allocator, .{
                                .position = .{
                                    @as(f32, @floatFromInt(x)) + v[0],
                                    @as(f32, @floatFromInt(y)) + v[1],
                                    @as(f32, @floatFromInt(z)) + v[2],
                                },
                                .normal = normal,
                                .tex_coord = tex_coords[i],
                            });
                        }

                        try indices.appendSlice(allocator, &[_]u32{
                            base_index, base_index + 1, base_index + 2,
                            base_index, base_index + 2, base_index + 3,
                        });
                    }
                }
            }
        }
    }

    return Mesh{
        .vertices = try vertices.toOwnedSlice(allocator),
        .indices = try indices.toOwnedSlice(allocator),
    };
}

test "face vertices for up face" {
    const corners = faceVertices(0);
    for (corners) |v| {
        try std.testing.expectEqual(v[1], 0.5);
    }
}

test "face normals are unit vectors" {
    for (face_normals) |n| {
        const len = @sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
        try std.testing.expectApproxEqAbs(len, 1.0, 0.001);
    }
}

test "empty chunk produces no mesh" {
    const chunk = Chunk.init();
    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    try std.testing.expectEqual(mesh.vertices.len, 0);
    try std.testing.expectEqual(mesh.indices.len, 0);
}

test "single block at corner produces 6 faces" {
    var chunk = Chunk.init();
    chunk.setBlock(0, 0, 0, .stone);

    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    try std.testing.expectEqual(mesh.vertices.len, 24);
    try std.testing.expectEqual(mesh.indices.len, 36);
}

test "single block at center produces 6 faces" {
    var chunk = Chunk.init();
    chunk.setBlock(7, 7, 7, .stone);

    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    try std.testing.expectEqual(mesh.vertices.len, 24);
    try std.testing.expectEqual(mesh.indices.len, 36);
}

test "two adjacent blocks share a face" {
    var chunk = Chunk.init();
    chunk.setBlock(5, 5, 5, .stone);
    chunk.setBlock(6, 5, 5, .stone);

    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    try std.testing.expectEqual(mesh.vertices.len, 40);
    try std.testing.expectEqual(mesh.indices.len, 60);
}

test "fillLayer produces correct face count" {
    var chunk = Chunk.init();
    chunk.fillLayer(0, .stone);

    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    try std.testing.expectEqual(mesh.vertices.len, 2304);
    try std.testing.expectEqual(mesh.indices.len, 3456);
}

test "water culls against adjacent water" {
    var chunk = Chunk.init();
    chunk.setBlock(2, 2, 2, .water);
    chunk.setBlock(2, 2, 3, .water);

    var mesh = try generateMesh(std.testing.allocator, &chunk, null);
    defer mesh.deinit(std.testing.allocator);

    // 2 cubes = 12 faces, but shared internal face culled -> 10 faces = 40 verts
    try std.testing.expectEqual(mesh.vertices.len, 40);
}
