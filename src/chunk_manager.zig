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
pub const Dimension = persistence_mod.Dimension;

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
    nether: terrain_mod.NetherGenerator,
    end: terrain_mod.EndGenerator,
    is_nether: bool = false,
    is_end: bool = false,
    persistence: persistence_mod.Persistence,
    enable_gpu_mesh: bool = true,

    /// Initialize ChunkManager with explicit GPU mesh rendering options.
    /// When `enable_gpu_mesh` is false, meshing and renderer allocation are bypassed,
    /// enabling headless unit tests without an active OpenGL context.
    pub fn initWithOptions(allocator: std.mem.Allocator, radius: i32, center_cx: i32, center_cz: i32, seed: u64, save_dir: [:0]const u8, enable_gpu_mesh: bool) !ChunkManager {
        return initForDimension(allocator, radius, center_cx, center_cz, seed, save_dir, .overworld, enable_gpu_mesh);
    }

    /// Initialize directly in a dimension before loading its chunks.
    pub fn initForDimension(allocator: std.mem.Allocator, radius: i32, center_cx: i32, center_cz: i32, seed: u64, save_dir: [:0]const u8, dim: Dimension, enable_gpu_mesh: bool) !ChunkManager {
        var self = ChunkManager{
            .allocator = allocator,
            .chunks = std.HashMap(ChunkCoord, LoadedChunk, ChunkCoordContext, 80).init(allocator),
            .radius = radius,
            .terrain = terrain_mod.TerrainGenerator.init(seed),
            .nether = terrain_mod.NetherGenerator.init(seed),
            .end = terrain_mod.EndGenerator.init(seed),
            .is_nether = dim == .nether,
            .is_end = dim == .the_end,
            .persistence = persistence_mod.Persistence.initForDimension(save_dir, dim),
            .enable_gpu_mesh = enable_gpu_mesh,
        };
        errdefer self.deinit();

        try self.syncToCenter(center_cx, center_cz, true);
        return self;
    }

    /// Initialize ChunkManager with GPU meshing enabled.
    pub fn init(allocator: std.mem.Allocator, radius: i32, center_cx: i32, center_cz: i32, seed: u64, save_dir: [:0]const u8) !ChunkManager {
        return initWithOptions(allocator, radius, center_cx, center_cz, seed, save_dir, true);
    }

    /// Return the currently active dimension.
    pub fn currentDimension(self: *const ChunkManager) persistence_mod.Dimension {
        if (self.is_end) return .the_end;
        if (self.is_nether) return .nether;
        return .overworld;
    }

    /// Switch active dimension, saving modified chunks from the current dimension,
    /// releasing chunk renderers, clearing chunk cache, updating persistence namespace,
    /// and reloading/generating chunks around (player_x, player_z).
    pub fn switchDimension(self: *ChunkManager, dim: persistence_mod.Dimension, player_x: f32, player_z: f32, mesh_all: bool) !void {
        const center_cx = @as(i32, @intFromFloat(@floor(player_x / 16.0)));
        const center_cz = @as(i32, @intFromFloat(@floor(player_z / 16.0)));
        if (self.currentDimension() != dim) {
            var save_iter = self.chunks.iterator();
            while (save_iter.next()) |entry| {
                if (entry.value_ptr.modified) {
                    try self.saveModified(entry.key_ptr.*, &entry.value_ptr.chunk);
                    entry.value_ptr.modified = false;
                }
            }
            var clean_iter = self.chunks.iterator();
            while (clean_iter.next()) |entry| {
                if (entry.value_ptr.renderer) |*r| {
                    r.deinit();
                    entry.value_ptr.renderer = null;
                }
            }
            self.chunks.clearRetainingCapacity();
            stageSnapshotLen = 0;
            burnoutSnapshotLen = 0;
            self.is_nether = (dim == .nether);
            self.is_end = (dim == .the_end);
            self.persistence = self.persistence.withDimension(dim);
        }
        try self.syncToCenter(center_cx, center_cz, mesh_all);
    }

    pub fn deinit(self: *ChunkManager) void {
        var iter = self.chunks.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.modified) {
                self.saveModified(entry.key_ptr.*, &entry.value_ptr.chunk) catch |err| {
                    std.debug.print("failed to save chunk ({d},{d}) during shutdown: {s}\n", .{ entry.key_ptr.x, entry.key_ptr.z, @errorName(err) });
                };
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
                    try self.saveModified(coord, &entry.value_ptr.chunk);
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
                        if (self.is_end) {
                            self.end.generateChunk(&ch, cx, cz);
                        } else if (self.is_nether) {
                            self.nether.generateChunk(&ch, cx, cz);
                        } else {
                            self.terrain.generateChunk(&ch, cx, cz);
                        }
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
        if (self.enable_gpu_mesh) {
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
    }

    fn markDirty(self: *ChunkManager, cx: i32, cz: i32) void {
        if (self.chunks.getPtr(.{ .x = cx, .z = cz })) |entry| {
            entry.dirty = true;
        }
    }

    pub const DrawStats = struct { drawn: usize, culled: usize };

    /// Draw all visible loaded chunks. MVP offset uses actual world chunk position (cx*16, 0, cz*16).
    /// `lamp_spots` holds up to 8 lit lamp centers for night spill; `night` is 0..1 darkness.
    pub fn draw(self: *ChunkManager, view_proj: math.Mat4, sun_dir: math.Vec3, lamp_spots: []const [3]f32, night: f32, cam_pos: math.Vec3, is_underwater: bool) DrawStats {
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
            var lamp_light = chunk_renderer_mod.ChunkRenderer.LampLight{ .night = night };
            lamp_light.count = @min(lamp_spots.len, lamp_light.positions.len);
            var li: usize = 0;
            while (li < lamp_light.count) : (li += 1) {
                lamp_light.positions[li] = lamp_spots[li];
            }
            renderer.draw(mvp.ptr(), sun_dir, .{ ox, 0, oz }, lamp_light, cam_pos, is_underwater, self.is_nether);
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

    /// Water level 0..7 at world coords; 0 outside loaded chunks or for non-water.
    pub fn getWaterLevel(self: *const ChunkManager, x: i32, y: i32, z: i32) u4 {
        if (y < 0 or y >= 16) return 0;
        const cx = @divFloor(x, 16);
        const cz = @divFloor(z, 16);
        const entry = self.chunks.get(.{ .x = cx, .z = cz }) orelse return 0;
        const lx: u4 = @intCast(@mod(x, 16));
        const lz: u4 = @intCast(@mod(z, 16));
        return entry.chunk.getLevel(lx, @intCast(y), lz);
    }

    /// Set water level; false if chunk not loaded or cell is not water.
    pub fn setWaterLevel(self: *ChunkManager, x: i32, y: i32, z: i32, level: u4) bool {
        if (y < 0 or y >= 16) return false;
        const cx = @divFloor(x, 16);
        const cz = @divFloor(z, 16);
        const entry = self.chunks.getPtr(.{ .x = cx, .z = cz }) orelse return false;
        const lx: u4 = @intCast(@mod(x, 16));
        const lz: u4 = @intCast(@mod(z, 16));
        if (entry.chunk.getBlock(lx, @intCast(y), lz) != .water) return false;
        entry.chunk.setLevel(lx, @intCast(y), lz, level);
        entry.modified = true;
        return true;
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
        if (!self.enable_gpu_mesh) return;
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

    fn saveModified(self: *const ChunkManager, coord: ChunkCoord, chunk: *const Chunk) !void {
        if (!self.persistence.saveChunk(coord.x, coord.z, chunk)) return error.ChunkSaveFailed;
        if (!self.saveStages(coord.x, coord.z, chunk)) return error.SidecarSaveFailed;
    }

    /// Persist repeater stages and torch burnout sidecars; report any write failure.
    pub fn saveStages(self: *const ChunkManager, cx: i32, cz: i32, chunk: *const Chunk) bool {
        _ = chunk;
        return self.stageCache(cx, cz) and self.burnoutCache(cx, cz);
    }

    fn burnoutCache(self: *const ChunkManager, cx: i32, cz: i32) bool {
        var buf = [_][4]u8{.{ 0, 0, 0, 0 }} ** 64;
        var n: usize = 0;
        for (burnoutSnapshot[0..burnoutSnapshotLen]) |st| {
            if (@divFloor(st[0], 16) != cx or @divFloor(st[2], 16) != cz) continue;
            if (n >= buf.len) break;
            buf[n] = .{ @intCast(@mod(st[0], 16)), @intCast(st[1]), @intCast(@mod(st[2], 16)), @intCast(@min(st[3], 255)) };
            n += 1;
        }
        return self.persistence.saveTorchBurnout(cx, cz, buf[0..n]);
    }

    /// Load persisted burnout entries for chunk (cx,cz) as world coords [x,y,z,secs].
    pub fn loadBurnout(self: *const ChunkManager, cx: i32, cz: i32, out: [][4]i32) usize {
        var raw = [_][4]u8{.{ 0, 0, 0, 0 }} ** 64;
        var slice: [][4]u8 = &raw;
        const n = self.persistence.loadTorchBurnout(cx, cz, &slice);
        var count: usize = 0;
        while (count < n and count < out.len) : (count += 1) {
            out[count] = .{ cx * 16 + @as(i32, raw[count][0]), @as(i32, raw[count][1]), cz * 16 + @as(i32, raw[count][2]), @as(i32, raw[count][3]) };
        }
        return count;
    }

    /// Session hook main.zig sets: serialized stages snapshot for save (copied in).
    pub var stageSnapshot: [64][4]i32 = undefined;
    pub var stageSnapshotLen: usize = 0;

    /// Session hook: burned-out torches snapshot [x,y,z,secs] for save (copied in).
    pub var burnoutSnapshot: [64][4]i32 = undefined;
    pub var burnoutSnapshotLen: usize = 0;

    pub fn setBurnoutSnapshot(items: []const [4]i32) void {
        burnoutSnapshotLen = @min(items.len, burnoutSnapshot.len);
        var i: usize = 0;
        while (i < burnoutSnapshotLen) : (i += 1) {
            burnoutSnapshot[i] = items[i];
        }
    }

    pub fn setStageSnapshot(stages: []const [4]i32) void {
        stageSnapshotLen = @min(stages.len, stageSnapshot.len);
        var i: usize = 0;
        while (i < stageSnapshotLen) : (i += 1) {
            stageSnapshot[i] = stages[i];
        }
    }

    fn stageCache(self: *const ChunkManager, cx: i32, cz: i32) bool {
        var buf = [_][4]u8{.{ 0, 0, 0, 0 }} ** 64;
        var n: usize = 0;
        for (stageSnapshot[0..stageSnapshotLen]) |st| {
            if (@divFloor(st[0], 16) != cx or @divFloor(st[2], 16) != cz) continue;
            if (n >= buf.len) break;
            buf[n] = .{ @intCast(@mod(st[0], 16)), @intCast(st[1]), @intCast(@mod(st[2], 16)), @intCast(st[3] & 3) };
            n += 1;
        }
        return self.persistence.saveRepeaterStages(cx, cz, buf[0..n]);
    }

    /// Load persisted repeater stages for chunk (cx,cz) as world coords [x,y,z,stage].
    pub fn loadStages(self: *const ChunkManager, cx: i32, cz: i32, out: [][4]i32) usize {
        var raw = [_][4]u8{.{ 0, 0, 0, 0 }} ** 64;
        var slice: [][4]u8 = &raw;
        const n = self.persistence.loadRepeaterStages(cx, cz, &slice);
        var count: usize = 0;
        while (count < n and count < out.len) : (count += 1) {
            out[count] = .{ cx * 16 + @as(i32, raw[count][0]), @as(i32, raw[count][1]), cz * 16 + @as(i32, raw[count][2]), @as(i32, raw[count][3]) };
        }
        return count;
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
        .nether = terrain_mod.NetherGenerator.init(123),
        .end = terrain_mod.EndGenerator.init(123),
        .is_nether = false,
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
        .nether = terrain_mod.NetherGenerator.init(0),
        .end = terrain_mod.EndGenerator.init(0),
        .is_nether = false,
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
        .nether = terrain_mod.NetherGenerator.init(0),
        .end = terrain_mod.EndGenerator.init(0),
        .is_nether = false,
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


test "streaming retains modified chunk when chunk or sidecar save fails" {
    const cases = [_]struct { path: []const u8, err: anyerror }{
        .{ .path = "c_0_0.bin", .err = error.ChunkSaveFailed },
        .{ .path = "c_0_0.rsp", .err = error.SidecarSaveFailed },
        .{ .path = "c_0_0.rtb", .err = error.SidecarSaveFailed },
    };
    for (cases) |case| {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        try tmp.dir.createDir(std.testing.io, case.path, .default_dir);
        var path_buf: [256:0]u8 = undefined;
        const dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
        var mgr = ChunkManager{
            .allocator = std.testing.allocator,
            .chunks = std.HashMap(ChunkCoord, LoadedChunk, ChunkCoordContext, 80).init(std.testing.allocator),
            .radius = 0,
            .terrain = terrain_mod.TerrainGenerator.init(0),
        .nether = terrain_mod.NetherGenerator.init(0),
        .end = terrain_mod.EndGenerator.init(0),
        .is_nether = false,
            .persistence = persistence_mod.Persistence.init(dir),
        };
        defer mgr.deinit();
        var ch = Chunk.init();
        ch.setBlock(1, 2, 3, .wood);
        try mgr.chunks.put(.{ .x = 0, .z = 0 }, .{ .chunk = ch, .renderer = null, .dirty = false, .modified = true });
        try std.testing.expectError(case.err, mgr.syncToCenter(10, 10, false));
        try std.testing.expectEqual(@as(usize, 1), mgr.loadedChunkCount());
        const retained = mgr.chunks.getPtr(.{ .x = 0, .z = 0 }).?;
        try std.testing.expect(retained.modified);
        try std.testing.expectEqual(block_mod.BlockId.wood, retained.chunk.getBlock(1, 2, 3));
        // Clear only test data so teardown does not deliberately retry a failed save.
        retained.modified = false;
    }
}

test "switchDimension isolates per-dimension chunk and sidecar edits across portals" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});

    defer {
        ChunkManager.stageSnapshotLen = 0;
        ChunkManager.burnoutSnapshotLen = 0;
    }

    var mgr = try ChunkManager.initWithOptions(std.testing.allocator, 1, 0, 0, 42, test_dir, false);
    defer mgr.deinit();

    try std.testing.expectEqual(persistence_mod.Dimension.overworld, mgr.currentDimension());

    _ = mgr.setBlockWorld(0, 5, 0, .diamond_block);
    ChunkManager.setStageSnapshot(&.{.{ 2, 5, 2, 3 }});
    ChunkManager.setBurnoutSnapshot(&.{.{ 3, 5, 3, 12 }});
    try std.testing.expectEqual(block_mod.BlockId.diamond_block, mgr.getBlockWorld(0, 5, 0));

    try mgr.switchDimension(.nether, 0.5, 0.5, false);
    try std.testing.expectEqual(persistence_mod.Dimension.nether, mgr.currentDimension());
    try std.testing.expect(mgr.getBlockWorld(0, 5, 0) != .diamond_block);
    try std.testing.expectEqual(@as(usize, 0), ChunkManager.stageSnapshotLen);

    _ = mgr.setBlockWorld(0, 5, 0, .gold_block);
    ChunkManager.setStageSnapshot(&.{.{ 2, 5, 2, 1 }});
    ChunkManager.setBurnoutSnapshot(&.{.{ 3, 5, 3, 25 }});
    try std.testing.expectEqual(block_mod.BlockId.gold_block, mgr.getBlockWorld(0, 5, 0));

    try mgr.switchDimension(.the_end, 0.5, 0.5, false);
    try std.testing.expectEqual(persistence_mod.Dimension.the_end, mgr.currentDimension());
    try std.testing.expect(mgr.getBlockWorld(0, 5, 0) != .gold_block);
    try std.testing.expect(mgr.getBlockWorld(0, 5, 0) != .diamond_block);

    _ = mgr.setBlockWorld(0, 5, 0, .emerald_block);
    try std.testing.expectEqual(block_mod.BlockId.emerald_block, mgr.getBlockWorld(0, 5, 0));

    try mgr.switchDimension(.overworld, 0.5, 0.5, false);
    try std.testing.expectEqual(persistence_mod.Dimension.overworld, mgr.currentDimension());
    try std.testing.expectEqual(block_mod.BlockId.diamond_block, mgr.getBlockWorld(0, 5, 0));
    var stages: [8][4]i32 = undefined;
    try std.testing.expectEqual(@as(usize, 1), mgr.loadStages(0, 0, &stages));
    try std.testing.expectEqual([4]i32{ 2, 5, 2, 3 }, stages[0]);
    var burnouts: [8][4]i32 = undefined;
    try std.testing.expectEqual(@as(usize, 1), mgr.loadBurnout(0, 0, &burnouts));
    try std.testing.expectEqual([4]i32{ 3, 5, 3, 12 }, burnouts[0]);

    try mgr.switchDimension(.nether, 0.5, 0.5, false);
    try std.testing.expectEqual(persistence_mod.Dimension.nether, mgr.currentDimension());
    try std.testing.expectEqual(block_mod.BlockId.gold_block, mgr.getBlockWorld(0, 5, 0));
    try std.testing.expectEqual(@as(usize, 1), mgr.loadStages(0, 0, &stages));
    try std.testing.expectEqual([4]i32{ 2, 5, 2, 1 }, stages[0]);
    try std.testing.expectEqual(@as(usize, 1), mgr.loadBurnout(0, 0, &burnouts));
    try std.testing.expectEqual([4]i32{ 3, 5, 3, 25 }, burnouts[0]);

    try mgr.switchDimension(.the_end, 0.5, 0.5, false);
    try std.testing.expectEqual(persistence_mod.Dimension.the_end, mgr.currentDimension());
    try std.testing.expectEqual(block_mod.BlockId.emerald_block, mgr.getBlockWorld(0, 5, 0));
    try std.testing.expectEqual(@as(usize, 0), mgr.loadStages(0, 0, &stages));
}

test "switchDimension retains current dimension and modified chunks when save fails" {
    const cases = [_]struct { path: []const u8, err: anyerror }{
        .{ .path = "c_0_0.bin", .err = error.ChunkSaveFailed },
        .{ .path = "c_0_0.rsp", .err = error.SidecarSaveFailed },
        .{ .path = "c_0_0.rtb", .err = error.SidecarSaveFailed },
    };
    for (cases) |case| {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        try tmp.dir.createDir(std.testing.io, case.path, .default_dir);
        var path_buf: [256:0]u8 = undefined;
        const dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
        var mgr = ChunkManager{
            .allocator = std.testing.allocator,
            .chunks = std.HashMap(ChunkCoord, LoadedChunk, ChunkCoordContext, 80).init(std.testing.allocator),
            .radius = 0,
            .terrain = terrain_mod.TerrainGenerator.init(0),
            .nether = terrain_mod.NetherGenerator.init(0),
            .end = terrain_mod.EndGenerator.init(0),
            .is_nether = false,
            .is_end = false,
            .persistence = persistence_mod.Persistence.init(dir),
            .enable_gpu_mesh = false,
        };
        defer mgr.deinit();
        var ch = Chunk.init();
        ch.setBlock(1, 2, 3, .wood);
        try mgr.chunks.put(.{ .x = 0, .z = 0 }, .{ .chunk = ch, .renderer = null, .dirty = false, .modified = true });
        try std.testing.expectError(case.err, mgr.switchDimension(.nether, 0.5, 0.5, false));
        try std.testing.expectEqual(persistence_mod.Dimension.overworld, mgr.currentDimension());
        try std.testing.expectEqual(@as(usize, 1), mgr.loadedChunkCount());
        const retained = mgr.chunks.getPtr(.{ .x = 0, .z = 0 }).?;
        try std.testing.expect(retained.modified);
        try std.testing.expectEqual(block_mod.BlockId.wood, retained.chunk.getBlock(1, 2, 3));
        retained.modified = false;
    }
}

test "initForDimension starts directly in nether or the_end and loads saved dimension chunks" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});

    // Pre-save chunks in nether and the_end subdirectories
    const p_nether = persistence_mod.Persistence.initForDimension(test_dir, .nether);
    var nether_chunk = chunk_mod.Chunk.init();
    nether_chunk.setBlock(2, 3, 4, .gold_block);
    try std.testing.expect(p_nether.saveChunk(0, 0, &nether_chunk));

    const p_end = persistence_mod.Persistence.initForDimension(test_dir, .the_end);
    var end_chunk = chunk_mod.Chunk.init();
    end_chunk.setBlock(2, 3, 4, .obsidian);
    try std.testing.expect(p_end.saveChunk(0, 0, &end_chunk));

    // Initialize ChunkManager directly in .nether with radius 0 around (0, 0)
    var mgr_nether = try ChunkManager.initForDimension(std.testing.allocator, 0, 0, 0, 42, test_dir, .nether, false);
    defer mgr_nether.deinit();

    try std.testing.expectEqual(persistence_mod.Dimension.nether, mgr_nether.currentDimension());
    try std.testing.expect(mgr_nether.is_nether);
    try std.testing.expect(!mgr_nether.is_end);
    try std.testing.expectEqual(block_mod.BlockId.gold_block, mgr_nether.getBlockWorld(2, 3, 4));

    // Initialize ChunkManager directly in .the_end with radius 0 around (0, 0)
    var mgr_end = try ChunkManager.initForDimension(std.testing.allocator, 0, 0, 0, 42, test_dir, .the_end, false);
    defer mgr_end.deinit();

    try std.testing.expectEqual(persistence_mod.Dimension.the_end, mgr_end.currentDimension());
    try std.testing.expect(!mgr_end.is_nether);
    try std.testing.expect(mgr_end.is_end);
    try std.testing.expectEqual(block_mod.BlockId.obsidian, mgr_end.getBlockWorld(2, 3, 4));
}
