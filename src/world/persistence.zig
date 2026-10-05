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
