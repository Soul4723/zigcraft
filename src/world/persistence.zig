const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("sys/stat.h");
    @cInclude("sys/types.h");
    @cInclude("unistd.h");
});

pub const MAGIC = [4]u8{ 'Z', 'C', 'H', 'K' };
pub const VERSION: u32 = 1;

pub const ChunkHeader = extern struct {
    magic: [4]u8,
    version: u32,
    cx: i32,
    cz: i32,
};

pub const Persistence = struct {
    dir_path: [:0]const u8,

    pub fn init(dir_path: [:0]const u8) Persistence {
        return .{ .dir_path = dir_path };
    }

    fn ensureDir(self: Persistence) void {
        _ = c.mkdir(self.dir_path.ptr, 0o755);
    }

    fn makePath(self: Persistence, buf: *[256:0]u8, cx: i32, cz: i32) ![:0]const u8 {
        return try std.fmt.bufPrintZ(buf, "{s}/c_{d}_{d}.bin", .{ self.dir_path, cx, cz });
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
        if (header.version != VERSION) return false;
        if (header.cx != cx or header.cz != cz) return false;

        const payload_size = @sizeOf(@TypeOf(out_chunk.blocks));
        if (c.fread(&out_chunk.blocks, 1, payload_size, f) != payload_size) return false;

        return true;
    }

    /// Repeater delay stages sidecar: `c_{x}_{z}.rsp` holds up to 64 (lx,y,lz,stage) quads.
    pub fn saveRepeaterStages(self: Persistence, cx: i32, cz: i32, stages: []const [4]u8) bool {
        self.ensureDir();
        var path_buf: [256:0]u8 = undefined;
        const file_path = std.fmt.bufPrintZ(&path_buf, "{s}/c_{d}_{d}.rsp", .{ self.dir_path, cx, cz }) catch return false;
        const count: u8 = @intCast(@min(stages.len, 64));
        return writeAtomic(file_path, &.{ std.mem.asBytes(&count), std.mem.sliceAsBytes(stages[0..count]) });
    }

    /// Load repeater stages sidecar into `out` (each [lx,y,lz,stage]); returns count.
    pub fn loadRepeaterStages(self: Persistence, cx: i32, cz: i32, out: *[][4]u8) usize {
        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makePath(&path_buf, cx, cz) catch return 0;
        _ = file_path;
        var rpath: [256:0]u8 = undefined;
        const rp = std.fmt.bufPrintZ(&rpath, "{s}/c_{d}_{d}.rsp", .{ self.dir_path, cx, cz }) catch return 0;
        const f = c.fopen(rp.ptr, "rb") orelse return 0;
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
        const file_path = std.fmt.bufPrintZ(&path_buf, "{s}/c_{d}_{d}.rtb", .{ self.dir_path, cx, cz }) catch return false;
        const count: u8 = @intCast(@min(items.len, 64));
        return writeAtomic(file_path, &.{ std.mem.asBytes(&count), std.mem.sliceAsBytes(items[0..count]) });
    }

    /// Load torch burnout sidecar into `out`; returns count.
    pub fn loadTorchBurnout(self: Persistence, cx: i32, cz: i32, out: *[][4]u8) usize {
        var rpath: [256:0]u8 = undefined;
        const rp = std.fmt.bufPrintZ(&rpath, "{s}/c_{d}_{d}.rtb", .{ self.dir_path, cx, cz }) catch return 0;
        const f = c.fopen(rp.ptr, "rb") orelse return 0;
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

        return writeAtomic(file_path, &.{ std.mem.asBytes(&header), std.mem.asBytes(&chunk.blocks) });
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
