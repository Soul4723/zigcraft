const std = @import("std");
const chunk_mod = @import("chunk.zig");
const block_jobs_mod = @import("block_jobs.zig");
const Chunk = chunk_mod.Chunk;
const container_cap = @import("component_cache.zig").chest_cap;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("sys/stat.h");
    @cInclude("sys/types.h");
    @cInclude("unistd.h");
    @cInclude("errno.h");
});

pub const MAGIC = [4]u8{ 'Z', 'C', 'H', 'K' };
pub const VERSION: u32 = 2;
pub const VERSION_LEVELS: u32 = 2;
pub const PLAYER_MAGIC = [4]u8{ 'Z', 'P', 'L', 'Y' };
pub const PLAYER_VERSION: u32 = 1;
pub const PLAYER_SAVE_SIZE: usize = 4 + 4 + 3 * 4 + 4 + 3 * 4 + 2 * 4 + 1 + 4 * 4 + 1 + 6 * 2 + 24 * 3 + 4 * 3 + 3;

pub const SavedSlot = struct { item_id: u16 = 0, count: u8 = 0 };
pub const PlayerSaveData = struct {
    pos: [3]f32, vel_y: f32 = 0.0, spawn_point: [3]f32, yaw: f32, pitch: f32,
    dimension: Dimension = .overworld, health: f32 = 20.0, hunger: f32 = 20.0,
    saturation: f32 = 5.0, oxygen: f32 = 15.0, selected_slot: u8 = 0,
    tool_wear: [6]u16 = [_]u16{0} ** 6,
    slots: [24]SavedSlot = [_]SavedSlot{.{}} ** 24,
    craft_grid: [4]SavedSlot = [_]SavedSlot{.{}} ** 4,
    cursor_stack: SavedSlot = .{},
};

/// Dimensions supported by the game engine, mapping to separate save namespaces.
pub const Dimension = enum(u8) {
    overworld = 0,
    nether = 1,
    the_end = 2,
};

pub const BlockJobsData = block_jobs_mod.BlockJobsData;
pub const LoadJobsResult = block_jobs_mod.LoadJobsResult;
pub const BLOCK_JOBS_MAGIC = block_jobs_mod.BLOCK_JOBS_MAGIC;
pub const BLOCK_JOBS_VERSION = block_jobs_mod.BLOCK_JOBS_VERSION;
pub const MAX_BLOCK_JOBS_SAVE_SIZE = block_jobs_mod.MAX_SAVE_SIZE;

pub const ChunkHeader = extern struct {
    magic: [4]u8,
    version: u32,
    cx: i32,
    cz: i32,
};

pub const Persistence = struct {
    dir_path: [:0]const u8,
    dimension: Dimension = .overworld,

    /// Initialize persistence for the Overworld dimension by default.
    pub fn init(dir_path: [:0]const u8) Persistence {
        return .{ .dir_path = dir_path, .dimension = .overworld };
    }

    /// Initialize persistence for a specific dimension.
    pub fn initForDimension(dir_path: [:0]const u8, dimension: Dimension) Persistence {
        return .{ .dir_path = dir_path, .dimension = dimension };
    }

    /// Return a copy of persistence configured for the specified dimension.
    pub fn withDimension(self: Persistence, dimension: Dimension) Persistence {
        return .{ .dir_path = self.dir_path, .dimension = dimension };
    }

    /// Atomically save player state in the shared root save directory.
    pub fn savePlayer(self: Persistence, data: *const PlayerSaveData) bool {
        _ = c.mkdir(self.dir_path.ptr, 0o755);
        var path_buf: [256:0]u8 = undefined;
        const path = std.fmt.bufPrintZ(&path_buf, "{s}/player.bin", .{self.dir_path}) catch return false;
        var bytes: [PLAYER_SAVE_SIZE]u8 = undefined;
        var i: usize = 0;
        inline for (PLAYER_MAGIC) |b| { bytes[i] = b; i += 1; }
        putInt(&bytes, &i, PLAYER_VERSION);
        inline for (data.pos) |v| putFloat(&bytes, &i, v);
        putFloat(&bytes, &i, data.vel_y);
        inline for (data.spawn_point) |v| putFloat(&bytes, &i, v);
        putFloat(&bytes, &i, data.yaw); putFloat(&bytes, &i, data.pitch);
        bytes[i] = @intFromEnum(data.dimension); i += 1;
        putFloat(&bytes, &i, data.health); putFloat(&bytes, &i, data.hunger);
        putFloat(&bytes, &i, data.saturation); putFloat(&bytes, &i, data.oxygen);
        bytes[i] = data.selected_slot; i += 1;
        for (data.tool_wear) |v| putInt(&bytes, &i, v);
        for (data.slots) |slot| { putInt(&bytes, &i, slot.item_id); bytes[i] = slot.count; i += 1; }
        for (data.craft_grid) |slot| { putInt(&bytes, &i, slot.item_id); bytes[i] = slot.count; i += 1; }
        putInt(&bytes, &i, data.cursor_stack.item_id); bytes[i] = data.cursor_stack.count; i += 1;
        std.debug.assert(i == PLAYER_SAVE_SIZE);
        return writeAtomic(path, &.{bytes[0..i]});
    }

    /// Load and validate player state without changing `out` on failure.
    pub fn loadPlayer(self: Persistence, out: *PlayerSaveData) bool {
        var path_buf: [256:0]u8 = undefined;
        const path = std.fmt.bufPrintZ(&path_buf, "{s}/player.bin", .{self.dir_path}) catch return false;
        const f = c.fopen(path.ptr, "rb") orelse return false;
        defer _ = c.fclose(f);
        var bytes: [PLAYER_SAVE_SIZE]u8 = undefined;
        if (c.fread(&bytes, 1, bytes.len, f) != bytes.len or c.fgetc(f) != -1 or !decodePlayerBytes(&bytes, out)) {
            std.debug.print("invalid player save ignored; starting with defaults\n", .{});
            return false;
        }
        return true;
    }

    fn decodePlayerBytes(bytes: *const [PLAYER_SAVE_SIZE]u8, out: *PlayerSaveData) bool {
        if (!std.mem.eql(u8, bytes[0..4], &PLAYER_MAGIC)) return false;
        var i: usize = 4;
        if (getInt(u32, bytes, &i) != PLAYER_VERSION) return false;
        var value: PlayerSaveData = undefined;
        inline for (0..3) |n| value.pos[n] = getFloat(bytes, &i);
        value.vel_y = getFloat(bytes, &i);
        inline for (0..3) |n| value.spawn_point[n] = getFloat(bytes, &i);
        value.yaw = getFloat(bytes, &i); value.pitch = getFloat(bytes, &i);
        const dim = bytes[i]; i += 1;
        value.dimension = std.enums.fromInt(Dimension, dim) orelse return false;
        value.health = getFloat(bytes, &i); value.hunger = getFloat(bytes, &i);
        value.saturation = getFloat(bytes, &i); value.oxygen = getFloat(bytes, &i);
        value.selected_slot = bytes[i]; i += 1;
        for (&value.tool_wear) |*v| v.* = getInt(u16, bytes, &i);
        for (&value.slots) |*slot| { slot.item_id = getInt(u16, bytes, &i); slot.count = bytes[i]; i += 1; }
        for (&value.craft_grid) |*slot| { slot.item_id = getInt(u16, bytes, &i); slot.count = bytes[i]; i += 1; }
        value.cursor_stack = .{ .item_id = getInt(u16, bytes, &i), .count = bytes[i] }; i += 1;
        std.debug.assert(i == PLAYER_SAVE_SIZE);
        inline for (value.pos) |v| { if (!std.math.isFinite(v)) return false; }
        inline for (value.spawn_point) |v| { if (!std.math.isFinite(v)) return false; }
        inline for (.{ value.vel_y, value.yaw, value.pitch, value.health, value.hunger, value.saturation, value.oxygen }) |v| { if (!std.math.isFinite(v)) return false; }
        out.* = value;
        return true;
    }

    fn ensureDir(self: Persistence) void {
        _ = c.mkdir(self.dir_path.ptr, 0o755);
        switch (self.dimension) {
            .overworld => {},
            .nether => {
                var dir_buf: [256:0]u8 = undefined;
                if (std.fmt.bufPrintZ(&dir_buf, "{s}/nether", .{self.dir_path})) |sub| {
                    _ = c.mkdir(sub.ptr, 0o755);
                } else |_| {}
            },
            .the_end => {
                var dir_buf: [256:0]u8 = undefined;
                if (std.fmt.bufPrintZ(&dir_buf, "{s}/the_end", .{self.dir_path})) |sub| {
                    _ = c.mkdir(sub.ptr, 0o755);
                } else |_| {}
            },
        }
    }

    fn makePathWithExt(self: Persistence, buf: *[256:0]u8, cx: i32, cz: i32, ext: []const u8) ![:0]const u8 {
        return switch (self.dimension) {
            .overworld => std.fmt.bufPrintZ(buf, "{s}/c_{d}_{d}.{s}", .{ self.dir_path, cx, cz, ext }),
            .nether => std.fmt.bufPrintZ(buf, "{s}/nether/c_{d}_{d}.{s}", .{ self.dir_path, cx, cz, ext }),
            .the_end => std.fmt.bufPrintZ(buf, "{s}/the_end/c_{d}_{d}.{s}", .{ self.dir_path, cx, cz, ext }),
        };
    }

    fn makePath(self: Persistence, buf: *[256:0]u8, cx: i32, cz: i32) ![:0]const u8 {
        return self.makePathWithExt(buf, cx, cz, "bin");
    }

    /// Try loading a saved chunk from disk. Returns true if file exists and was loaded.
    pub fn loadChunk(self: Persistence, cx: i32, cz: i32, out_chunk: *Chunk) bool {
        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makePath(&path_buf, cx, cz) catch return false;

        const f = c.fopen(file_path.ptr, "rb") orelse return false;
        defer _ = c.fclose(f);

        var header: ChunkHeader = undefined;
        if (c.fread(&header, 1, @sizeOf(ChunkHeader), f) != @sizeOf(ChunkHeader)) return false;

        if (!std.mem.eql(u8, &header.magic, &MAGIC)) return false;
        if (header.version != 1 and header.version != VERSION) return false;
        if (header.cx != cx or header.cz != cz) return false;

        const payload_size = @sizeOf(@TypeOf(out_chunk.blocks));
        if (c.fread(&out_chunk.blocks, 1, payload_size, f) != payload_size) return false;

        // v1 files have no level payload: treat all water as full sources.
        if (header.version == 1) {
            var y: usize = 0;
            while (y < 16) : (y += 1) {
                var z: usize = 0;
                while (z < 16) : (z += 1) {
                    var x: usize = 0;
                    while (x < 16) : (x += 1) {
                        out_chunk.levels[y][z][x] = if (out_chunk.blocks[y][z][x] == .water) 7 else 0;
                    }
                }
            }
            return true;
        }
        const level_size = @sizeOf(@TypeOf(out_chunk.levels));
        if (c.fread(&out_chunk.levels, 1, level_size, f) != level_size) return false;

        return true;
    }

    /// Repeater delay stages sidecar: `c_{x}_{z}.rsp` holds up to 64 (lx,y,lz,stage) quads.
    pub fn saveRepeaterStages(self: Persistence, cx: i32, cz: i32, stages: []const [4]u8) bool {
        self.ensureDir();
        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makePathWithExt(&path_buf, cx, cz, "rsp") catch return false;
        const count: u8 = @intCast(@min(stages.len, 64));
        return writeAtomic(file_path, &.{ std.mem.asBytes(&count), std.mem.sliceAsBytes(stages[0..count]) });
    }

    /// Load repeater stages sidecar into `out` (each [lx,y,lz,stage]); returns count.
    pub fn loadRepeaterStages(self: Persistence, cx: i32, cz: i32, out: *[][4]u8) usize {
        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makePathWithExt(&path_buf, cx, cz, "rsp") catch return 0;
        const f = c.fopen(file_path.ptr, "rb") orelse return 0;
        defer _ = c.fclose(f);
        var count: u8 = 0;
        if (c.fread(&count, 1, 1, f) != 1) return 0;
        const n: usize = @min(count, out.len);
        if (n == 0) return 0;
        const got = c.fread(out.ptr, 4, n, f);
        return got;
    }

    /// Burned-out torch sidecar: `c_{x}_{z}.rtb` holds up to 64 (lx,y,lz,secs) quads.
    pub fn saveTorchBurnout(self: Persistence, cx: i32, cz: i32, items: []const [4]u8) bool {
        self.ensureDir();
        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makePathWithExt(&path_buf, cx, cz, "rtb") catch return false;
        const count: u8 = @intCast(@min(items.len, 64));
        return writeAtomic(file_path, &.{ std.mem.asBytes(&count), std.mem.sliceAsBytes(items[0..count]) });
    }

    /// Load torch burnout sidecar into `out`; returns count.
    pub fn loadTorchBurnout(self: Persistence, cx: i32, cz: i32, out: *[][4]u8) usize {
        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makePathWithExt(&path_buf, cx, cz, "rtb") catch return 0;
        const f = c.fopen(file_path.ptr, "rb") orelse return 0;
        defer _ = c.fclose(f);
        var count: u8 = 0;
        if (c.fread(&count, 1, 1, f) != 1) return 0;
        const n: usize = @min(count, out.len);
        if (n == 0) return 0;
        return c.fread(out.ptr, 4, n, f);
    }

    /// Save a chunk to disk. Ensures storage directory exists.
    pub fn saveChunk(self: Persistence, cx: i32, cz: i32, chunk: *const Chunk) bool {
        self.ensureDir();

        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makePath(&path_buf, cx, cz) catch return false;

        const header = ChunkHeader{
            .magic = MAGIC,
            .version = VERSION,
            .cx = cx,
            .cz = cz,
        };

        return writeAtomic(file_path, &.{ std.mem.asBytes(&header), std.mem.asBytes(&chunk.blocks), std.mem.asBytes(&chunk.levels) });
    }

    fn makeContainersPath(self: Persistence, buf: *[256:0]u8) ![:0]const u8 {
        return switch (self.dimension) {
            .overworld => std.fmt.bufPrintZ(buf, "{s}/containers.bin", .{self.dir_path}),
            .nether => std.fmt.bufPrintZ(buf, "{s}/nether/containers.bin", .{self.dir_path}),
            .the_end => std.fmt.bufPrintZ(buf, "{s}/the_end/containers.bin", .{self.dir_path}),
        };
    }

    /// Atomically save the active dimension's container cache, including empty containers.
    pub fn saveContainers(self: Persistence, containers: anytype) bool {
        if (containers.len > container_cap) return false;
        self.ensureDir();
        var path_buf: [256:0]u8 = undefined;
        const path = self.makeContainersPath(&path_buf) catch return false;
        var bytes: [11 + 24 * container_cap]u8 = undefined;
        @memcpy(bytes[0..4], "ZCON");
        var i: usize = 4;
        putInt(&bytes, &i, @as(u32, 1));
        bytes[i] = @intFromEnum(self.dimension); i += 1;
        putInt(&bytes, &i, @as(u16, @intCast(containers.len)));
        for (containers, 0..) |ch, idx| {
            if (ch.y < 0 or ch.y >= 16) return false;
            for (containers[0..idx]) |prev| {
                if (prev.x == ch.x and prev.y == ch.y and prev.z == ch.z) return false;
            }
            for (ch.items) |slot| {
                if ((slot.item == .none) != (slot.count == 0) or slot.count > slot.item.maxStackSize()) return false;
            }
            putInt(&bytes, &i, ch.x); putInt(&bytes, &i, ch.y); putInt(&bytes, &i, ch.z);
            for (ch.items) |slot| {
                putInt(&bytes, &i, @as(u16, @intCast(@intFromEnum(slot.item))));
                bytes[i] = slot.count; i += 1;
            }
        }
        return writeAtomic(path, &.{bytes[0..i]});
    }

    /// Load a complete cache; corrupt or unreadable files leave the caller's state untouched.
    pub fn loadContainers(self: Persistence, containers: anytype, count: *usize) LoadJobsResult {
        var path_buf: [256:0]u8 = undefined;
        const path = self.makeContainersPath(&path_buf) catch return .corrupt;
        const f = c.fopen(path.ptr, "rb") orelse {
            if (c.__errno_location().* == c.ENOENT) { count.* = 0; return .absent; }
            return .corrupt;
        };
        defer _ = c.fclose(f);
        var bytes: [11 + 24 * container_cap + 1]u8 = undefined;
        const len = c.fread(&bytes, 1, bytes.len, f);
        if (len < 11 or len > bytes.len - 1 or c.fgetc(f) != -1 or c.ferror(f) != 0) return .corrupt;
        if (!std.mem.eql(u8, bytes[0..4], "ZCON")) return .corrupt;
        var i: usize = 4;
        if (getInt(u32, &bytes, &i) != 1 or bytes[i] != @intFromEnum(self.dimension)) return .corrupt;
        i += 1;
        const n = getInt(u16, &bytes, &i);
        if (n > container_cap or n > containers.len or len != 11 + @as(usize, n) * 24) return .corrupt;
        var staged: @TypeOf(containers.*) = undefined;
        for (0..n) |idx| {
            const x = getInt(i32, &bytes, &i); const y = getInt(i32, &bytes, &i); const z = getInt(i32, &bytes, &i);
            if (y < 0 or y >= 16) return .corrupt;
            for (staged[0..idx]) |prev| if (prev.x == x and prev.y == y and prev.z == z) { return .corrupt; };
            staged[idx].x = x; staged[idx].y = y; staged[idx].z = z;
            for (&staged[idx].items) |*slot| {
                const id = getInt(u16, &bytes, &i);
                const item = std.enums.fromInt(@TypeOf(slot.item), id) orelse return .corrupt;
                const amount = bytes[i]; i += 1;
                if ((item == .none) != (amount == 0) or amount > item.maxStackSize()) return .corrupt;
                slot.* = .{ .item = item, .count = amount };
            }
        }
        @memcpy(containers[0..n], staged[0..n]); count.* = n;
        return .ok;
    }

    fn makeAutomationPath(self: Persistence, buf: *[256:0]u8) ![:0]const u8 {
        return switch (self.dimension) {
            .overworld => std.fmt.bufPrintZ(buf, "{s}/automation.bin", .{self.dir_path}),
            .nether => std.fmt.bufPrintZ(buf, "{s}/nether/automation.bin", .{self.dir_path}),
            .the_end => std.fmt.bufPrintZ(buf, "{s}/the_end/automation.bin", .{self.dir_path}),
        };
    }

    /// Save both automation caches atomically in their dimension namespace.
    pub fn saveAutomation(self: Persistence, hoppers: anytype, droppers: anytype) bool {
        if (hoppers.len > 32 or droppers.len > 32) return false;
        for (hoppers) |hop| for (droppers) |drop| {
            if (hop.x == drop.x and hop.y == drop.y and hop.z == drop.z) return false;
        };
        var bytes: [13 + 28 * 32 + 25 * 32]u8 = undefined;
        @memcpy(bytes[0..4], "ZAUT");
        var i: usize = 4;
        putInt(&bytes, &i, @as(u32, 1));
        bytes[i] = @intFromEnum(self.dimension); i += 1;
        putInt(&bytes, &i, @as(u16, @intCast(hoppers.len)));
        putInt(&bytes, &i, @as(u16, @intCast(droppers.len)));
        inline for (.{hoppers, droppers}, 0..) |entries, kind| {
            for (entries, 0..) |entry, idx| {
                if (entry.y < 0 or entry.y >= 16) return false;
                for (entries[0..idx]) |prev| if (prev.x == entry.x and prev.y == entry.y and prev.z == entry.z) { return false; };
                for (entry.items) |slot| if ((slot.item == .none) != (slot.count == 0) or slot.count > slot.item.maxStackSize()) { return false; };
                putInt(&bytes, &i, entry.x); putInt(&bytes, &i, entry.y); putInt(&bytes, &i, entry.z);
                for (entry.items) |slot| {
                    putInt(&bytes, &i, @as(u16, @intCast(@intFromEnum(slot.item))));
                    bytes[i] = slot.count; i += 1;
                }
                if (kind == 0) {
                    if (!std.math.isFinite(entry.cooldown) or entry.cooldown < 0 or entry.cooldown > 0.4) return false;
                    putFloat(&bytes, &i, entry.cooldown);
                } else {
                    bytes[i] = @intFromBool(entry.powered); i += 1;
                }
            }
        }
        self.ensureDir();
        var path_buf: [256:0]u8 = undefined;
        const path = self.makeAutomationPath(&path_buf) catch return false;
        return writeAtomic(path, &.{bytes[0..i]});
    }

    /// Validate and stage the entire automation file before replacing live caches.
    pub fn loadAutomation(self: Persistence, hoppers: anytype, hopper_count: *usize, droppers: anytype, dropper_count: *usize) LoadJobsResult {
        var path_buf: [256:0]u8 = undefined;
        const path = self.makeAutomationPath(&path_buf) catch return .corrupt;
        const f = c.fopen(path.ptr, "rb") orelse {
            if (c.__errno_location().* == c.ENOENT) { hopper_count.* = 0; dropper_count.* = 0; return .absent; }
            return .corrupt;
        };
        defer _ = c.fclose(f);
        var bytes: [13 + 28 * 32 + 25 * 32 + 1]u8 = undefined;
        const len = c.fread(&bytes, 1, bytes.len, f);
        if (len < 13 or len >= bytes.len or c.fgetc(f) != -1 or c.ferror(f) != 0 or !std.mem.eql(u8, bytes[0..4], "ZAUT")) return .corrupt;
        var i: usize = 4;
        if (getInt(u32, &bytes, &i) != 1 or bytes[i] != @intFromEnum(self.dimension)) return .corrupt;
        i += 1;
        const hn = getInt(u16, &bytes, &i); const dn = getInt(u16, &bytes, &i);
        if (hn > 32 or dn > 32 or hn > hoppers.len or dn > droppers.len or len != 13 + @as(usize, hn) * 28 + @as(usize, dn) * 25) return .corrupt;
        var hs: @TypeOf(hoppers.*) = undefined;
        var ds: @TypeOf(droppers.*) = undefined;
        inline for (.{ .{ &hs, hn }, .{ &ds, dn } }, 0..) |pair, kind| {
            const entries = pair[0]; const n = pair[1];
            for (0..n) |idx| {
                const x = getInt(i32, &bytes, &i); const y = getInt(i32, &bytes, &i); const z = getInt(i32, &bytes, &i);
                if (y < 0 or y >= 16) return .corrupt;
                for (entries[0..idx]) |prev| if (prev.x == x and prev.y == y and prev.z == z) { return .corrupt; };
                entries[idx] = .{ .x = x, .y = y, .z = z };
                for (&entries[idx].items) |*slot| {
                    const id = getInt(u16, &bytes, &i);
                    const item = std.enums.fromInt(@TypeOf(slot.item), id) orelse return .corrupt;
                    const amount = bytes[i]; i += 1;
                    if ((item == .none) != (amount == 0) or amount > item.maxStackSize()) return .corrupt;
                    slot.* = .{ .item = item, .count = amount };
                }
                if (kind == 0) {
                    const cooldown = getFloat(&bytes, &i);
                    if (!std.math.isFinite(cooldown) or cooldown < 0 or cooldown > 0.4) return .corrupt;
                    entries[idx].cooldown = cooldown;
                } else {
                    if (bytes[i] > 1) return .corrupt;
                    entries[idx].powered = bytes[i] == 1; i += 1;
                }
            }
        }
        for (hs[0..hn]) |hop| for (ds[0..dn]) |drop| {
            if (hop.x == drop.x and hop.y == drop.y and hop.z == drop.z) return .corrupt;
        };
        @memcpy(hoppers[0..hn], hs[0..hn]); hopper_count.* = hn;
        @memcpy(droppers[0..dn], ds[0..dn]); dropper_count.* = dn;
        return .ok;
    }

    /// Stage the target and save the source before a dimension switch.
    pub fn prepareAutomationTransit(self: Persistence, target: Persistence, hoppers: anytype, droppers: anytype, target_hoppers: anytype, target_hopper_count: *usize, target_droppers: anytype, target_dropper_count: *usize) bool {
        if (target.loadAutomation(target_hoppers, target_hopper_count, target_droppers, target_dropper_count) == .corrupt) return false;
        return self.saveAutomation(hoppers, droppers);
    }

    fn makeJobsPath(self: Persistence, buf: *[256:0]u8) ![:0]const u8 {
        return switch (self.dimension) {
            .overworld => std.fmt.bufPrintZ(buf, "{s}/block_jobs.bin", .{self.dir_path}),
            .nether => std.fmt.bufPrintZ(buf, "{s}/nether/block_jobs.bin", .{self.dir_path}),
            .the_end => std.fmt.bufPrintZ(buf, "{s}/the_end/block_jobs.bin", .{self.dir_path}),
        };
    }

    /// Atomically save dimension block entity jobs. Ensures storage directory exists.
    pub fn saveBlockJobs(self: Persistence, data: *const BlockJobsData) bool {
        self.ensureDir();
        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makeJobsPath(&path_buf) catch return false;
        var bytes: [block_jobs_mod.MAX_SAVE_SIZE]u8 = undefined;
        const len = block_jobs_mod.encodeBlockJobs(data, self.dimension, &bytes) catch return false;
        return writeAtomic(file_path, &.{bytes[0..len]});
    }

    /// Load and validate dimension block entity jobs without changing `out` on corruption.
    pub fn loadBlockJobs(self: Persistence, out: *BlockJobsData) LoadJobsResult {
        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makeJobsPath(&path_buf) catch return .corrupt;
        const f = c.fopen(file_path.ptr, "rb") orelse {
            const err = c.__errno_location().*;
            if (err == c.ENOENT) {
                out.* = BlockJobsData{};
                return .absent;
            }
            std.debug.print("unreadable block jobs save file at {s} (errno {d}); preserving durable file\n", .{ file_path, err });
            return .corrupt;
        };
        defer _ = c.fclose(f);

        var bytes: [block_jobs_mod.MAX_SAVE_SIZE + 1]u8 = undefined;
        const read_count = c.fread(&bytes, 1, bytes.len, f);
        if (read_count == 0 or read_count > block_jobs_mod.MAX_SAVE_SIZE or c.fgetc(f) != -1) {
            std.debug.print("invalid block jobs save ignored; preserving durable file\n", .{});
            return .corrupt;
        }

        if (!block_jobs_mod.decodeBlockJobs(bytes[0..read_count], self.dimension, out)) {
            std.debug.print("invalid block jobs save ignored; preserving durable file\n", .{});
            return .corrupt;
        }

        return .ok;
    }
};

// ponytail: each file replaces atomically; cross-file transactions and directory fsync remain deferred.
fn writeAtomic(path: [:0]const u8, parts: []const []const u8) bool {
    var temp_buf: [272:0]u8 = undefined;
    const temp = std.fmt.bufPrintZ(&temp_buf, "{s}.XXXXXX", .{path}) catch return false;
    const fd = c.mkstemp(temp.ptr);
    if (fd < 0) return false;
    defer _ = c.unlink(temp.ptr);
    const file = c.fdopen(fd, "wb") orelse {
        _ = c.close(fd);
        return false;
    };
    var closed = false;
    defer if (!closed) {
        _ = c.fclose(file);
    };
    for (parts) |part| {
        if (c.fwrite(part.ptr, 1, part.len, file) != part.len) return false;
    }
    if (c.fflush(file) != 0 or c.fsync(fd) != 0) return false;
    const close_result = c.fclose(file);
    closed = true;
    if (close_result != 0) return false;
    return c.rename(temp.ptr, path.ptr) == 0;
}

fn putInt(bytes: []u8, index: *usize, value: anytype) void {
    const T = @TypeOf(value);
    std.mem.writeInt(T, bytes[index.*..][0..@sizeOf(T)], value, .little);
    index.* += @sizeOf(T);
}

fn putFloat(bytes: []u8, index: *usize, value: f32) void {
    std.mem.writeInt(u32, bytes[index.*..][0..4], @as(u32, @bitCast(value)), .little);
    index.* += 4;
}

fn getInt(comptime T: type, bytes: []const u8, index: *usize) T {
    const val = std.mem.readInt(T, bytes[index.*..][0..@sizeOf(T)], .little);
    index.* += @sizeOf(T);
    return val;
}

fn getFloat(bytes: []const u8, index: *usize) f32 {
    const bits = std.mem.readInt(u32, bytes[index.*..][0..4], .little);
    index.* += 4;
    return @bitCast(bits);
}
