const std = @import("std");
const chunk_mod = @import("world/chunk.zig");
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
                var cpu_mesh = try chunk_mesh_mod.generateMesh(allocator, &self.chunks[idx], null);
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
        if (y < 0 or y >= 16) return false;
        const ox = x - self.base_cx * 16;
        const oz = z - self.base_cz * 16;
        if (ox < 0 or oz < 0) return false;
        const side_i: i32 = @intCast(self.side);
        if (ox >= side_i * 16 or oz >= side_i * 16) return false;
        const ci: usize = @intCast(@divFloor(ox, 16));
        const cj: usize = @intCast(@divFloor(oz, 16));
        const lx: u4 = @intCast(@mod(ox, 16));
        const lz: usize = @intCast(@mod(oz, 16));
        const ly: u4 = @intCast(y);
        return self.chunks[cj * self.side + ci].getBlock(lx, ly, @intCast(lz)).is_solid();
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

test "model offsets tile without gaps" {
    // Adjacent chunk origins differ by exactly 16 on x/z.
    const a = math.Mat4.translate(math.Vec3.init(0, 0, 0));
    const b = math.Mat4.translate(math.Vec3.init(16, 0, 0));
    try std.testing.expectEqual(a.data[3][0] + 16, b.data[3][0]);
}
