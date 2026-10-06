const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const SIZE = chunk_mod.SIZE;
const BlockId = @import("block.zig").BlockId;

const c = @cImport({
    @cInclude("stdio.h");
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

    /// Repeater delay stages sidecar: `c_{x}_{z}.rsp` holds up to 32 (lx,y,lz,stage) quads.
    pub fn saveRepeaterStages(self: Persistence, cx: i32, cz: i32, stages: []const [4]u8) bool {
        self.ensureDir();
        var path_buf: [256:0]u8 = undefined;
        const file_path = std.fmt.bufPrintZ(&path_buf, "{s}/c_{d}_{d}.rsp", .{ self.dir_path, cx, cz }) catch return false;
        const f = c.fopen(file_path.ptr, "wb") orelse return false;
        defer _ = c.fclose(f);
        var count: u8 = @intCast(@min(stages.len, 32));
        if (c.fwrite(&count, 1, 1, f) != 1) return false;
        if (count == 0) return true;
        if (c.fwrite(stages.ptr, 4, count, f) != count) return false;
        return true;
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

    /// Save a chunk to disk. Ensures storage directory exists.
    pub fn saveChunk(self: Persistence, cx: i32, cz: i32, chunk: *const Chunk) bool {
        self.ensureDir();

        var path_buf: [256:0]u8 = undefined;
        const file_path = self.makePath(&path_buf, cx, cz) catch return false;

        const f = c.fopen(file_path.ptr, "wb") orelse return false;
        defer _ = c.fclose(f);

        const header = ChunkHeader{
            .magic = MAGIC,
            .version = VERSION,
            .cx = cx,
            .cz = cz,
        };

        if (c.fwrite(&header, 1, @sizeOf(ChunkHeader), f) != @sizeOf(ChunkHeader)) return false;
        const payload_size = @sizeOf(@TypeOf(chunk.blocks));
        if (c.fwrite(&chunk.blocks, 1, payload_size, f) != payload_size) return false;

        return true;
    }
};

test "save and load roundtrip" {
    const test_dir = ".zig-cache/test_persistence";
    _ = c.mkdir(test_dir, 0o755);
    defer {
        _ = c.unlink(".zig-cache/test_persistence/c_-5_12.bin");
        _ = c.rmdir(test_dir);
    }

    const p = Persistence.init(test_dir);

    var src = Chunk.init();
    src.setBlock(2, 3, 4, .stone);
    src.setBlock(15, 10, 0, .grass);

    try std.testing.expect(p.saveChunk(-5, 12, &src));

    var dst = Chunk.init();
    const loaded = p.loadChunk(-5, 12, &dst);
    try std.testing.expect(loaded);

    try std.testing.expectEqual(dst.getBlock(2, 3, 4), .stone);
    try std.testing.expectEqual(dst.getBlock(15, 10, 0), .grass);
    try std.testing.expectEqual(dst.getBlock(0, 0, 0), .air);

    // Non-existent chunk returns false
    var missing = Chunk.init();
    const found = p.loadChunk(99, 99, &missing);
    try std.testing.expect(!found);
}

test "repeater stages sidecar roundtrip" {
    const test_dir = ".zig-cache/test_persistence";
    _ = c.mkdir(test_dir, 0o755);
    defer {
        _ = c.unlink(".zig-cache/test_persistence/c_3_7.rsp");
    }
    const pp = Persistence.init(test_dir);
    const stages = [_][4]u8{ .{ 1, 5, 2, 3 }, .{ 15, 0, 0, 1 } };
    try std.testing.expect(pp.saveRepeaterStages(3, 7, &stages));
    var out = [_][4]u8{.{ 0, 0, 0, 0 }} ** 32;
    var slice: [][4]u8 = &out;
    const n = pp.loadRepeaterStages(3, 7, &slice);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(stages[0], out[0]);
    try std.testing.expectEqual(stages[1], out[1]);
    // missing sidecar -> 0
    var out2 = [_][4]u8{.{ 0, 0, 0, 0 }} ** 32;
    var slice2: [][4]u8 = &out2;
    try std.testing.expectEqual(@as(usize, 0), pp.loadRepeaterStages(77, 78, &slice2));
}

test "redstone block states persist roundtrip" {
    const test_dir = ".zig-cache/test_persistence";
    _ = c.mkdir(test_dir, 0o755);
    defer {
        _ = c.unlink(".zig-cache/test_persistence/c_8_9.bin");
    }
    const pp = Persistence.init(test_dir);
    var src = Chunk.init();
    src.setBlock(1, 2, 3, .redstone_wire_on);
    src.setBlock(4, 5, 6, .repeater_on);
    src.setBlock(7, 8, 9, .redstone_lamp_on);
    src.setBlock(10, 11, 12, .redstone_torch_off);
    src.setBlock(13, 14, 15, .pressure_plate_down);
    src.setBlock(0, 0, 1, .lever_on);
    try std.testing.expect(pp.saveChunk(8, 9, &src));
    var dst = Chunk.init();
    try std.testing.expect(pp.loadChunk(8, 9, &dst));
    try std.testing.expectEqual(BlockId.redstone_wire_on, dst.getBlock(1, 2, 3));
    try std.testing.expectEqual(BlockId.repeater_on, dst.getBlock(4, 5, 6));
    try std.testing.expectEqual(BlockId.redstone_lamp_on, dst.getBlock(7, 8, 9));
    try std.testing.expectEqual(BlockId.redstone_torch_off, dst.getBlock(10, 11, 12));
    try std.testing.expectEqual(BlockId.pressure_plate_down, dst.getBlock(13, 14, 15));
    try std.testing.expectEqual(BlockId.lever_on, dst.getBlock(0, 0, 1));
}
