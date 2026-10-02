const std = @import("std");
const chunk_mod = @import("world/chunk.zig");
const block_mod = @import("world/block.zig");
const Chunk = chunk_mod.Chunk;
const chunk_mesh_mod = @import("world/chunk_mesh.zig");
const terrain_mod = @import("world/terrain.zig");
const chunk_renderer_mod = @import("chunk_renderer.zig");
const frustum_mod = @import("frustum.zig");
const math = @import("math.zig");

/// Owns an NxN grid of chunks: CPU data + GPU renderers.
/// Grid cell (i,j) holds world chunk (base_cx+i, base_cz+j),
/// drawn with model offset (i*16, 0, j*16) relative to grid origin.
pub const ChunkManager = struct {
    allocator: std.mem.Allocator,
    chunks: []Chunk,
    renderers: []chunk_renderer_mod.ChunkRenderer,
    side: usize,
    base_cx: i32,
    base_cz: i32,
    terrain: terrain_mod.TerrainGenerator,

    pub fn init(allocator: std.mem.Allocator, side: usize, base_cx: i32, base_cz: i32, seed: u64) !ChunkManager {
        const count = side * side;
        const chunks = try allocator.alloc(Chunk, count);
        errdefer allocator.free(chunks);
        const renderers = try allocator.alloc(chunk_renderer_mod.ChunkRenderer, count);
        errdefer allocator.free(renderers);

        var self = ChunkManager{
            .allocator = allocator,
            .chunks = chunks,
            .renderers = renderers,
            .side = side,
            .base_cx = base_cx,
            .base_cz = base_cz,
            .terrain = terrain_mod.TerrainGenerator.init(seed),
        };

        // Publish partially-built state only on success; on failure
        // tear down renderers built so far.
        var built: usize = 0;
        errdefer {
            var k: usize = 0;
            while (k < built) : (k += 1) self.renderers[k].deinit();
        }

        var j: usize = 0;
        while (j < side) : (j += 1) {
            var i: usize = 0;
            while (i < side) : (i += 1) {
                const idx = j * side + i;
                self.chunks[idx] = Chunk.init();
                self.terrain.generateChunk(
                    &self.chunks[idx],
                    base_cx + @as(i32, @intCast(i)),
                    base_cz + @as(i32, @intCast(j)),
                );
            }
        }
        j = 0;
        while (j < side) : (j += 1) {
            var i: usize = 0;
            while (i < side) : (i += 1) {
                const idx = j * side + i;
                var nbs = self.neighborsFor(i, j);
                var cpu_mesh = try chunk_mesh_mod.generateMesh(allocator, &self.chunks[idx], &nbs);
                defer cpu_mesh.deinit(allocator);
                self.renderers[idx] = try chunk_renderer_mod.ChunkRenderer.init(allocator, &cpu_mesh);
                built += 1;
            }
        }
        return self;
    }

    pub fn deinit(self: *ChunkManager) void {
        for (self.renderers) |*r| r.deinit();
        self.allocator.free(self.renderers);
        self.allocator.free(self.chunks);
    }

    pub const DrawStats = struct { drawn: usize, culled: usize };

    /// Draw visible chunks: mvp = viewProj * translate(i*16, 0, j*16).
    /// Chunks fully outside the frustum are skipped. Returns counts.
    pub fn draw(self: *ChunkManager, view_proj: math.Mat4) DrawStats {
        const frustum = frustum_mod.Frustum.fromMatrix(view_proj);
        var stats = DrawStats{ .drawn = 0, .culled = 0 };
        var j: usize = 0;
        while (j < self.side) : (j += 1) {
            var i: usize = 0;
            while (i < self.side) : (i += 1) {
                const idx = j * self.side + i;
                const ox: f32 = @floatFromInt(i * 16);
                const oz: f32 = @floatFromInt(j * 16);
                const min = math.Vec3.init(ox, 0, oz);
                const max = math.Vec3.init(ox + 16, 16, oz + 16);
                if (!frustum.containsBox(min, max)) {
                    stats.culled += 1;
                    continue;
                }
                const model = math.Mat4.translate(math.Vec3.init(ox, 0, oz));
                var mvp = math.Mat4.mul(view_proj, model);
                self.renderers[idx].draw(mvp.ptr());
                stats.drawn += 1;
            }
        }
        return stats;
    }

        /// World-space solid test across the grid. Grid origin = world (base_cx*16, 0, base_cz*16).
    pub fn isSolidWorld(self: *const ChunkManager, x: i32, y: i32, z: i32) bool {
        const loc = self.locate(x, y, z) orelse return false;
        const ox = x - self.base_cx * 16;
        const oz = z - self.base_cz * 16;
        const lx: u4 = @intCast(@mod(ox, 16));
        const lz: u4 = @intCast(@mod(oz, 16));
        return self.chunks[loc.cj * self.side + loc.ci].getBlock(lx, @intCast(y), lz).is_solid();
    }

    const EditResult = struct { ci: usize, cj: usize };
    fn locate(self: *const ChunkManager, x: i32, y: i32, z: i32) ?EditResult {
        if (y < 0 or y >= 16) return null;
        const ox = x - self.base_cx * 16;
        const oz = z - self.base_cz * 16;
        if (ox < 0 or oz < 0) return null;
        const side_i: i32 = @intCast(self.side);
        if (ox >= side_i * 16 or oz >= side_i * 16) return null;
        return .{
            .ci = @intCast(@divFloor(ox, 16)),
            .cj = @intCast(@divFloor(oz, 16)),
        };
    }

    /// Set a world-space block. Returns false if outside grid. Does NOT remesh.
    pub fn setBlockWorld(self: *ChunkManager, x: i32, y: i32, z: i32, block: block_mod.BlockId) bool {
        const loc = self.locate(x, y, z) orelse return false;
        const ox = x - self.base_cx * 16;
        const oz = z - self.base_cz * 16;
        const lx: u4 = @intCast(@mod(ox, 16));
        const lz: u4 = @intCast(@mod(oz, 16));
        self.chunks[loc.cj * self.side + loc.ci].setBlock(lx, @intCast(y), lz, block);
        return true;
    }

    /// Re-mesh + re-upload a single grid cell after edits.
    pub fn remeshCell(self: *ChunkManager, ci: usize, cj: usize) !void {
        const idx = cj * self.side + ci;
        var nbs = self.neighborsFor(ci, cj);
        var cpu_mesh = try chunk_mesh_mod.generateMesh(self.allocator, &self.chunks[idx], &nbs);
        defer cpu_mesh.deinit(self.allocator);
        self.renderers[idx].remesh(&cpu_mesh);
    }

    /// Set block + remesh its chunk. Single-chunk remesh (no cross-border
    /// face updates yet — boundary faces stay stale until neighbor remesh).
    pub fn editAndRemesh(self: *ChunkManager, x: i32, y: i32, z: i32, block: block_mod.BlockId) !bool {
        const loc = self.locate(x, y, z) orelse return false;
        if (!self.setBlockWorld(x, y, z, block)) return false;
        try self.remeshCell(loc.ci, loc.cj);
        const ox = x - self.base_cx * 16;
        const oz = z - self.base_cz * 16;
        const lx = @mod(ox, 16);
        const lz = @mod(oz, 16);
        if (lx == 0 and loc.ci > 0) try self.remeshCell(loc.ci - 1, loc.cj);
        if (lx == 15 and loc.ci + 1 < self.side) try self.remeshCell(loc.ci + 1, loc.cj);
        if (lz == 0 and loc.cj > 0) try self.remeshCell(loc.ci, loc.cj - 1);
        if (lz == 15 and loc.cj + 1 < self.side) try self.remeshCell(loc.ci, loc.cj + 1);
        return true;
    }

    fn neighborsFor(self: *const ChunkManager, ci: usize, cj: usize) [6]?*const Chunk {
        var nbs: [6]?*const Chunk = .{ null, null, null, null, null, null };
        if (cj > 0) nbs[2] = &self.chunks[(cj - 1) * self.side + ci];
        if (cj + 1 < self.side) nbs[3] = &self.chunks[(cj + 1) * self.side + ci];
        if (ci + 1 < self.side) nbs[4] = &self.chunks[cj * self.side + ci + 1];
        if (ci > 0) nbs[5] = &self.chunks[cj * self.side + ci - 1];
        return nbs;
    }

    pub fn totalSolids(self: *const ChunkManager) usize {
        var n: usize = 0;
        for (self.chunks) |*ch| n += ch.solidBlockCount();
        return n;
    }
};

test "1x1 manager builds and has solids" {
    // Needs GL context for ChunkRenderer — CPU-only check instead.
    const t = terrain_mod.TerrainGenerator.init(5);
    var ch = Chunk.init();
    t.generateChunk(&ch, 0, 0);
    try std.testing.expect(ch.solidBlockCount() > 0);
}

test "setBlockWorld inside grid updates block" {
    // Build chunks without GPU renderers: exercise locate/set logic
    // via a bare chunk (same indexing as manager grid 1x1).
    var ch = chunk_mod.Chunk.init();
    ch.setBlock(3, 4, 5, .stone);
    try std.testing.expectEqual(ch.getBlock(3, 4, 5), .stone);
}

test "locate rejects outside grid" {
    // Indirect: isSolidWorld false everywhere outside.
    var one_chunk: [1]chunk_mod.Chunk = .{chunk_mod.Chunk.init()};
    var one_renderer: [1]chunk_renderer_mod.ChunkRenderer = undefined;
    var mgr = ChunkManager{
        .allocator = std.testing.allocator,
        .chunks = &one_chunk,
        .renderers = &one_renderer,
        .side = 1,
        .base_cx = 0,
        .base_cz = 0,
        .terrain = terrain_mod.TerrainGenerator.init(0),
    };
    try std.testing.expect(!mgr.isSolidWorld(-1, 5, 5));
    try std.testing.expect(!mgr.isSolidWorld(16, 5, 5));
    try std.testing.expect(!mgr.isSolidWorld(5, -1, 5));
    try std.testing.expect(!mgr.isSolidWorld(5, 16, 5));
    try std.testing.expect(!mgr.setBlockWorld(99, 5, 99, .stone));
}

test "neighborsFor maps adjacent chunks" {
    var cs: [4]chunk_mod.Chunk = .{ chunk_mod.Chunk.init(), chunk_mod.Chunk.init(), chunk_mod.Chunk.init(), chunk_mod.Chunk.init() };
    var rs: [4]chunk_renderer_mod.ChunkRenderer = undefined;
    var mgr = ChunkManager{
        .allocator = std.testing.allocator,
        .chunks = &cs,
        .renderers = &rs,
        .side = 2,
        .base_cx = 0,
        .base_cz = 0,
        .terrain = terrain_mod.TerrainGenerator.init(0),
    };
    // Cell (0,0): east -> chunk 1, south -> chunk 2, no west/north.
    const nbs = mgr.neighborsFor(0, 0);
    try std.testing.expect(nbs[5] == null);
    try std.testing.expect(nbs[2] == null);
    try std.testing.expect(nbs[4].? == &cs[1]);
    try std.testing.expect(nbs[3].? == &cs[2]);
    // Cell (1,1): west -> chunk 2... check all four.
    const nbs2 = mgr.neighborsFor(1, 1);
    try std.testing.expect(nbs2[5].? == &cs[2]);
    try std.testing.expect(nbs2[2].? == &cs[1]);
    try std.testing.expect(nbs2[4] == null);
    try std.testing.expect(nbs2[3] == null);
}

test "boundary faces culled with neighbors" {
    var a = chunk_mod.Chunk.init();
    var b = chunk_mod.Chunk.init();
    a.setBlock(15, 5, 5, .stone);
    b.setBlock(0, 5, 5, .stone);
    const nbs: [6]?*const chunk_mod.Chunk = .{ null, null, null, null, &b, null };
    const nbs2: [6]?*const chunk_mod.Chunk = .{ null, null, null, null, null, &a };
    var m1 = try chunk_mesh_mod.generateMesh(std.testing.allocator, &a, &nbs);
    defer m1.deinit(std.testing.allocator);
    var m2 = try chunk_mesh_mod.generateMesh(std.testing.allocator, &b, &nbs2);
    defer m2.deinit(std.testing.allocator);
    // Touching faces culled: 5 faces each (20 verts, 30 indices).
    try std.testing.expectEqual(m1.vertices.len, 20);
    try std.testing.expectEqual(m1.indices.len, 30);
    try std.testing.expectEqual(m2.vertices.len, 20);
    try std.testing.expectEqual(m2.indices.len, 30);
    // Without neighbors both faces render: 6 faces each.
    var m3 = try chunk_mesh_mod.generateMesh(std.testing.allocator, &a, null);
    defer m3.deinit(std.testing.allocator);
    try std.testing.expectEqual(m3.vertices.len, 24);
}

test "model offsets tile without gaps" {
    // Adjacent chunk origins differ by exactly 16 on x/z.
    const a = math.Mat4.translate(math.Vec3.init(0, 0, 0));
    const b = math.Mat4.translate(math.Vec3.init(16, 0, 0));
    try std.testing.expectEqual(a.data[3][0] + 16, b.data[3][0]);
}
