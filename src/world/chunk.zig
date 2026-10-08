const std = @import("std");
const BlockId = @import("block.zig").BlockId;

/// Chunk dimensions: 16×16×16 = 4096 blocks
pub const SIZE: u5 = 16;

/// Fill a 3D block array with a given block type.
fn fillBlocks(comptime block: BlockId) [SIZE][SIZE][SIZE]BlockId {
    var result: [SIZE][SIZE][SIZE]BlockId = undefined;
    var y: usize = 0;
    while (y < SIZE) : (y += 1) {
        var z: usize = 0;
        while (z < SIZE) : (z += 1) {
            var x: usize = 0;
            while (x < SIZE) : (x += 1) {
                result[y][z][x] = block;
            }
        }
    }
    return result;
}

/// 16×16×16 chunk of block data.
///
/// Storage is indexed [y][z][x] — vertical column access is cache-friendly
/// (terrain generation, raycasting, etc).
pub const Chunk = struct {
    blocks: [SIZE][SIZE][SIZE]BlockId,
    /// Per-cell water level 0..7. Meaningful only where blocks == .water;
    /// 7 = full source, 0 = thinnest film. Zeroed for non-water.
    levels: [SIZE][SIZE][SIZE]u4,

    pub fn init() Chunk {
        var levels: [SIZE][SIZE][SIZE]u4 = undefined;
        var y: usize = 0;
        while (y < SIZE) : (y += 1) {
            var z: usize = 0;
            while (z < SIZE) : (z += 1) {
                var x: usize = 0;
                while (x < SIZE) : (x += 1) {
                    levels[y][z][x] = 0;
                }
            }
        }
        return .{ .blocks = fillBlocks(.air), .levels = levels };
    }

    pub fn getBlock(self: *const Chunk, x: u4, y: u4, z: u4) BlockId {
        return self.blocks[y][z][x];
    }

    pub fn setBlock(self: *Chunk, x: u4, y: u4, z: u4, block: BlockId) void {
        self.blocks[y][z][x] = block;
        // ponytail: level preserved across setBlock so flow edits keep depth;
        // callers clearing water to air should reset level explicitly.
        if (block != .water) self.levels[y][z][x] = 0;
    }

    /// Water depth 0..7 at cell; 0 for non-water.
    pub fn getLevel(self: *const Chunk, x: u4, y: u4, z: u4) u4 {
        if (self.blocks[y][z][x] != .water) return 0;
        return self.levels[y][z][x];
    }

    /// Set water level; no-op unless cell is water.
    pub fn setLevel(self: *Chunk, x: u4, y: u4, z: u4, level: u4) void {
        if (self.blocks[y][z][x] != .water) return;
        self.levels[y][z][x] = level;
    }

    /// Fill an entire horizontal layer (all x,z at a given y) with one block type.
    pub fn fillLayer(self: *Chunk, y: u4, block: BlockId) void {
        var x: usize = 0;
        while (x < SIZE) : (x += 1) {
            var z: usize = 0;
            while (z < SIZE) : (z += 1) {
                self.blocks[y][z][x] = block;
            }
        }
    }

    /// Count solid blocks in this chunk.
    pub fn solidBlockCount(self: *const Chunk) usize {
        var count: usize = 0;
        var y: usize = 0;
        while (y < SIZE) : (y += 1) {
            var z: usize = 0;
            while (z < SIZE) : (z += 1) {
                var x: usize = 0;
                while (x < SIZE) : (x += 1) {
                    if (self.blocks[y][z][x].is_solid()) {
                        count += 1;
                    }
                }
            }
        }
        return count;
    }
};

test "chunk defaults to all air" {
    const chunk = Chunk.init();
    try std.testing.expectEqual(chunk.getBlock(0, 0, 0), .air);
    try std.testing.expectEqual(chunk.getBlock(15, 15, 15), .air);
    try std.testing.expectEqual(chunk.solidBlockCount(), 0);
}

test "chunk set and get round-trip" {
    var chunk = Chunk.init();
    chunk.setBlock(5, 10, 3, .stone);
    try std.testing.expectEqual(chunk.getBlock(5, 10, 3), .stone);
    try std.testing.expectEqual(chunk.getBlock(5, 10, 4), .air);
    try std.testing.expectEqual(chunk.solidBlockCount(), 1);
}

test "chunk fillLayer" {
    var chunk = Chunk.init();
    chunk.fillLayer(0, .stone);
    try std.testing.expectEqual(chunk.getBlock(0, 0, 0), .stone);
    try std.testing.expectEqual(chunk.getBlock(15, 0, 15), .stone);
    try std.testing.expectEqual(chunk.getBlock(0, 1, 0), .air);
    try std.testing.expectEqual(chunk.solidBlockCount(), 256); // 16*16
}

test "water levels default zero and clear with block" {
    var chunk = Chunk.init();
    try std.testing.expectEqual(@as(u4, 0), chunk.getLevel(1, 1, 1));
    chunk.setBlock(1, 1, 1, .water);
    chunk.setLevel(1, 1, 1, 7);
    try std.testing.expectEqual(@as(u4, 7), chunk.getLevel(1, 1, 1));
    chunk.setBlock(1, 1, 1, .air);
    try std.testing.expectEqual(@as(u4, 0), chunk.getLevel(1, 1, 1));
}

test "setLevel ignores non-water cells" {
    var chunk = Chunk.init();
    chunk.setBlock(2, 2, 2, .stone);
    chunk.setLevel(2, 2, 2, 7);
    try std.testing.expectEqual(@as(u4, 0), chunk.getLevel(2, 2, 2));
}

test "chunk boundary addresses" {
    var chunk = Chunk.init();
    chunk.setBlock(0, 0, 0, .grass);
    try std.testing.expectEqual(chunk.getBlock(0, 0, 0), .grass);

    chunk.setBlock(15, 15, 15, .dirt);
    try std.testing.expectEqual(chunk.getBlock(15, 15, 15), .dirt);
}
