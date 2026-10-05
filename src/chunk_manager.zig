const std = @import("std");
const chunk_mod = @import("world/chunk.zig");
const block_mod = @import("world/block.zig");
const Chunk = chunk_mod.Chunk;
const chunk_mesh_mod = @import("world/chunk_mesh.zig");
const terrain_mod = @import("world/terrain.zig");
const chunk_renderer_mod = @import("chunk_renderer.zig");
const frustum_mod = @import("frustum.zig");
const math = @import("math.zig");
const persistence_mod = @import("world/persistence.zig");

pub const ChunkCoord = struct {
    x: i32,
    z: i32,

    pub fn hash(self: ChunkCoord) u64 {
        const ux: u64 = @bitCast(@as(i64, self.x));
        const uz: u64 = @bitCast(@as(i64, self.z));
        return (ux *% 0x9E3779B97F4A7C15) ^ (uz *% 0xBF58476D1CE4E5B9);
    }

    pub fn eql(a: ChunkCoord, b: ChunkCoord) bool {
        return a.x == b.x and a.z == b.z;
    }
};

const ChunkCoordContext = struct {
    pub fn hash(_: ChunkCoordContext, key: ChunkCoord) u64 {
        return key.hash();
    }
    pub fn eql(_: ChunkCoordContext, a: ChunkCoord, b: ChunkCoord) bool {
        return a.eql(b);
    }
};

pub const LoadedChunk = struct {
    chunk: Chunk,
    renderer: ?chunk_renderer_mod.ChunkRenderer,
    dirty: bool,
    modified: bool,
};

/// Dynamic chunk manager: streams chunks in a view radius (square diameter = 2*radius+1)
/// centered on player position. Loads new chunks, unloads distant ones, remeshes dirty,
/// persists modified chunks to disk.
pub const ChunkManager = struct {
    allocator: std.mem.Allocator,
    chunks: std.HashMap(ChunkCoord, LoadedChunk, ChunkCoordContext, 80),
    radius: i32,
    terrain: terrain_mod.TerrainGenerator,
    persistence: persistence_mod.Persistence,

    pub fn init(allocator: std.mem.Allocator, radius: i32, center_cx: i32, center_cz: i32, seed: u64, save_dir: [:0]const u8) !ChunkManager {
        var self = ChunkManager{
            .allocator = allocator,
            .chunks = std.HashMap(ChunkCoord, LoadedChunk, ChunkCoordContext, 80).init(allocator),
            .radius = radius,
            .terrain = terrain_mod.TerrainGenerator.init(seed),
            .persistence = persistence_mod.Persistence.init(save_dir),
        };
        errdefer self.deinit();

        try self.syncToCenter(center_cx, center_cz, true);
        return self;
    }

    pub fn deinit(self: *ChunkManager) void {
        var iter = self.chunks.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.modified) {
                _ = self.persistence.saveChunk(entry.key_ptr.x, entry.key_ptr.z, &entry.value_ptr.chunk);
            }
            if (entry.value_ptr.renderer) |*r| r.deinit();
        }
        self.chunks.deinit();
    }

    /// Load missing chunks and purge distant ones around (center_cx, center_cz).
    pub fn update(self: *ChunkManager, player_x: f32, player_z: f32) !void {
        const center_cx = @as(i32, @intFromFloat(@floor(player_x / 16.0)));
        const center_cz = @as(i32, @intFromFloat(@floor(player_z / 16.0)));
        try self.syncToCenter(center_cx, center_cz, false);
    }

    /// Ensure chunks within radius exist, purge outside, mesh dirty ones up to budget per tick.
    pub fn syncToCenter(self: *ChunkManager, center_cx: i32, center_cz: i32, mesh_all: bool) !void {
        // 1. Purge out-of-range chunks (save if modified)
        var iter = self.chunks.iterator();
        while (iter.next()) |entry| {
            const coord = entry.key_ptr.*;
            if (@abs(coord.x - center_cx) > self.radius or @abs(coord.z - center_cz) > self.radius) {
                if (entry.value_ptr.modified) {
                    _ = self.persistence.saveChunk(coord.x, coord.z, &entry.value_ptr.chunk);
                }
                if (entry.value_ptr.renderer) |*r| r.deinit();
                _ = self.chunks.remove(coord);
            }
        }

        // 2. Load from disk or generate new chunks within radius
        var cz = center_cz - self.radius;
        while (cz <= center_cz + self.radius) : (cz += 1) {
            var cx = center_cx - self.radius;
            while (cx <= center_cx + self.radius) : (cx += 1) {
                const coord = ChunkCoord{ .x = cx, .z = cz };
                if (!self.chunks.contains(coord)) {
                    var ch = Chunk.init();
                    const from_disk = self.persistence.loadChunk(cx, cz, &ch);
                    if (!from_disk) {
                        self.terrain.generateChunk(&ch, cx, cz);
                    }
                    try self.chunks.put(coord, .{
                        .chunk = ch,
                        .renderer = null,
                        .dirty = true,
                        .modified = false,
                    });
                    self.markDirty(cx + 1, cz);
                    self.markDirty(cx - 1, cz);
                    self.markDirty(cx, cz + 1);
                    self.markDirty(cx, cz - 1);
                }
            }
        }

        // 3. Mesh dirty chunks (budgeted per frame unless mesh_all)
        const budget: usize = if (mesh_all) std.math.maxInt(usize) else 4;
        var meshed: usize = 0;
        var r_iter = self.chunks.iterator();
        while (r_iter.next()) |entry| {
            if (meshed >= budget) break;
            if (!entry.value_ptr.dirty) continue;

            const coord = entry.key_ptr.*;
            var nbs = self.neighborsFor(coord.x, coord.z);
            var cpu_mesh = try chunk_mesh_mod.generateMesh(self.allocator, &entry.value_ptr.chunk, &nbs);
            defer cpu_mesh.deinit(self.allocator);

            if (entry.value_ptr.renderer) |*r| {
                r.remesh(&cpu_mesh);
            } else {
                entry.value_ptr.renderer = try chunk_renderer_mod.ChunkRenderer.init(self.allocator, &cpu_mesh);
            }
            entry.value_ptr.dirty = false;
            meshed += 1;
        }
    }

    fn markDirty(self: *ChunkManager, cx: i32, cz: i32) void {
        if (self.chunks.getPtr(.{ .x = cx, .z = cz })) |entry| {
            entry.dirty = true;
        }
    }

    pub const DrawStats = struct { drawn: usize, culled: usize };

    /// Draw all visible loaded chunks. MVP offset uses actual world chunk position (cx*16, 0, cz*16).
    pub fn draw(self: *ChunkManager, view_proj: math.Mat4, sun_dir: math.Vec3) DrawStats {
        const frustum = frustum_mod.Frustum.fromMatrix(view_proj);
        var stats = DrawStats{ .drawn = 0, .culled = 0 };

        var iter = self.chunks.iterator();
        while (iter.next()) |entry| {
            const renderer = &(entry.value_ptr.renderer orelse continue);
            const cx = entry.key_ptr.x;
            const cz = entry.key_ptr.z;
            const ox: f32 = @floatFromInt(cx * 16);
            const oz: f32 = @floatFromInt(cz * 16);
            const min = math.Vec3.init(ox, 0, oz);
            const max = math.Vec3.init(ox + 16, 16, oz + 16);
            if (!frustum.containsBox(min, max)) {
                stats.culled += 1;
                continue;
            }
            const model = math.Mat4.translate(math.Vec3.init(ox, 0, oz));
            var mvp = math.Mat4.mul(view_proj, model);
            renderer.draw(mvp.ptr(), sun_dir);
            stats.drawn += 1;
        }
        return stats;
    }

    /// World-space solid test. Checks loaded chunk at world coords.
    pub fn isSolidWorld(self: *const ChunkManager, x: i32, y: i32, z: i32) bool {
        return self.getBlockWorld(x, y, z).is_solid();
    }

    /// World-space block lookup. Returns .air if outside loaded chunks or y out of range.
    pub fn getBlockWorld(self: *const ChunkManager, x: i32, y: i32, z: i32) block_mod.BlockId {
        if (y < 0 or y >= 16) return .air;
        const cx = @divFloor(x, 16);
        const cz = @divFloor(z, 16);
        const entry = self.chunks.get(.{ .x = cx, .z = cz }) orelse return .air;
        const lx: u4 = @intCast(@mod(x, 16));
        const lz: u4 = @intCast(@mod(z, 16));
        return entry.chunk.getBlock(lx, @intCast(y), lz);
    }

    /// Set block in loaded chunk. Returns false if chunk not loaded or y out of range.
    pub fn setBlockWorld(self: *ChunkManager, x: i32, y: i32, z: i32, block: block_mod.BlockId) bool {
        if (y < 0 or y >= 16) return false;
        const cx = @divFloor(x, 16);
        const cz = @divFloor(z, 16);
        const entry = self.chunks.getPtr(.{ .x = cx, .z = cz }) orelse return false;
        const lx: u4 = @intCast(@mod(x, 16));
        const lz: u4 = @intCast(@mod(z, 16));
        entry.chunk.setBlock(lx, @intCast(y), lz, block);
        entry.dirty = true;
        entry.modified = true;
        return true;
    }

    /// Remesh a single chunk by coordinate.
    pub fn remeshChunk(self: *ChunkManager, cx: i32, cz: i32) !void {
        const entry = self.chunks.getPtr(.{ .x = cx, .z = cz }) orelse return;
        var nbs = self.neighborsFor(cx, cz);
        var cpu_mesh = try chunk_mesh_mod.generateMesh(self.allocator, &entry.chunk, &nbs);
        defer cpu_mesh.deinit(self.allocator);
        if (entry.renderer) |*r| {
            r.remesh(&cpu_mesh);
        } else {
            entry.renderer = try chunk_renderer_mod.ChunkRenderer.init(self.allocator, &cpu_mesh);
        }
        entry.dirty = false;
    }

    /// Set block and immediately remesh its chunk + borders if near edge.
    pub fn editAndRemesh(self: *ChunkManager, x: i32, y: i32, z: i32, block: block_mod.BlockId) !bool {
        if (!self.setBlockWorld(x, y, z, block)) return false;
        const cx = @divFloor(x, 16);
        const cz = @divFloor(z, 16);
        try self.remeshChunk(cx, cz);
        const lx = @mod(x, 16);
        const lz = @mod(z, 16);
        if (lx == 0) try self.remeshChunk(cx - 1, cz);
        if (lx == 15) try self.remeshChunk(cx + 1, cz);
        if (lz == 0) try self.remeshChunk(cx, cz - 1);
        if (lz == 15) try self.remeshChunk(cx, cz + 1);
        return true;
    }

    fn neighborsFor(self: *const ChunkManager, cx: i32, cz: i32) [6]?*const Chunk {
        var nbs: [6]?*const Chunk = .{ null, null, null, null, null, null };
        if (self.chunks.getPtr(.{ .x = cx, .z = cz - 1 })) |n| nbs[2] = &n.chunk;
        if (self.chunks.getPtr(.{ .x = cx, .z = cz + 1 })) |n| nbs[3] = &n.chunk;
        if (self.chunks.getPtr(.{ .x = cx + 1, .z = cz })) |n| nbs[4] = &n.chunk;
        if (self.chunks.getPtr(.{ .x = cx - 1, .z = cz })) |n| nbs[5] = &n.chunk;
        return nbs;
    }

    pub fn loadedChunkCount(self: *const ChunkManager) usize {
        return self.chunks.count();
    }
};

test "ChunkCoord hash and equality" {
    const a = ChunkCoord{ .x = -3, .z = 4 };
    const b = ChunkCoord{ .x = -3, .z = 4 };
    const c = ChunkCoord{ .x = 3, .z = 4 };
    try std.testing.expect(a.eql(b));
    try std.testing.expect(!a.eql(c));
    try std.testing.expectEqual(a.hash(), b.hash());
}

test "streaming loads radius and unloads outside" {
    var mgr = ChunkManager{
        .allocator = std.testing.allocator,
        .chunks = std.HashMap(ChunkCoord, LoadedChunk, ChunkCoordContext, 80).init(std.testing.allocator),
        .radius = 1,
        .terrain = terrain_mod.TerrainGenerator.init(123),
        .persistence = persistence_mod.Persistence.init(".zig-cache/test_mgr_stream"),
    };
    defer mgr.deinit();

    // Radius 1 around (0,0) -> 3x3 = 9 chunks (CPU only, no meshing)
    var cz: i32 = -1;
    while (cz <= 1) : (cz += 1) {
        var cx: i32 = -1;
        while (cx <= 1) : (cx += 1) {
            var ch = Chunk.init();
            mgr.terrain.generateChunk(&ch, cx, cz);
            try mgr.chunks.put(.{ .x = cx, .z = cz }, .{ .chunk = ch, .renderer = null, .dirty = false, .modified = false });
        }
    }
    try std.testing.expectEqual(mgr.loadedChunkCount(), 9);

    // Shift center to (10, 10) without GL rendering: manually test coordinate filter
    var iter = mgr.chunks.iterator();
    while (iter.next()) |entry| {
        const coord = entry.key_ptr.*;
        if (@abs(coord.x - 10) > mgr.radius or @abs(coord.z - 10) > mgr.radius) {
            _ = mgr.chunks.remove(coord);
        }
    }
    try std.testing.expectEqual(mgr.loadedChunkCount(), 0);
}

test "isSolidWorld checks negative chunk coords" {
    var mgr = ChunkManager{
        .allocator = std.testing.allocator,
        .chunks = std.HashMap(ChunkCoord, LoadedChunk, ChunkCoordContext, 80).init(std.testing.allocator),
        .radius = 1,
        .terrain = terrain_mod.TerrainGenerator.init(0),
        .persistence = persistence_mod.Persistence.init(".zig-cache/test_mgr_solid"),
    };
    defer mgr.deinit();

    var ch = Chunk.init();
    ch.setBlock(15, 4, 15, .stone);
    try mgr.chunks.put(.{ .x = -1, .z = -1 }, .{ .chunk = ch, .renderer = null, .dirty = false, .modified = false });

    // World (-1, 4, -1) lies in chunk (-1, -1) at local (15, 4, 15)
    try std.testing.expect(mgr.isSolidWorld(-1, 4, -1));
    try std.testing.expect(!mgr.isSolidWorld(-1, 5, -1));
    try std.testing.expect(!mgr.isSolidWorld(0, 4, 0));
}

test "getBlockWorld returns block id or air" {
    var mgr = ChunkManager{
        .allocator = std.testing.allocator,
        .chunks = std.HashMap(ChunkCoord, LoadedChunk, ChunkCoordContext, 80).init(std.testing.allocator),
        .radius = 1,
        .terrain = terrain_mod.TerrainGenerator.init(0),
        .persistence = persistence_mod.Persistence.init(".zig-cache/test_mgr_block"),
    };
    defer mgr.deinit();

    var ch = Chunk.init();
    ch.setBlock(2, 5, 2, .wood);
    try mgr.chunks.put(.{ .x = 0, .z = 0 }, .{ .chunk = ch, .renderer = null, .dirty = false, .modified = false });

    try std.testing.expectEqual(block_mod.BlockId.wood, mgr.getBlockWorld(2, 5, 2));
    try std.testing.expectEqual(block_mod.BlockId.air, mgr.getBlockWorld(2, 6, 2));
    try std.testing.expectEqual(block_mod.BlockId.air, mgr.getBlockWorld(2, -1, 2));
    try std.testing.expectEqual(block_mod.BlockId.air, mgr.getBlockWorld(100, 5, 100));
}
