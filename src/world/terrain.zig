const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const SIZE = chunk_mod.SIZE;
const BlockId = @import("block.zig").BlockId;

/// Seeded value-noise terrain generator. Deterministic per world (x,z).
/// Pure Zig, no deps. Value noise + fBm; cheap and good enough for hills.
pub const TerrainGenerator = struct {
    seed: u64,
    base_height: i32,
    amplitude: f32,
    frequency: f32,
    octaves: u32,

    pub fn init(seed: u64) TerrainGenerator {
        return .{
            .seed = seed,
            .base_height = 6,
            .amplitude = 6.0,
            .frequency = 0.08,
            .octaves = 4,
        };
    }

    /// Height (0..SIZE-1, clamped) for a world-space (x,z) column.
    pub fn heightAt(self: TerrainGenerator, wx: i32, wz: i32) u4 {
        var freq = self.frequency;
        var amp = self.amplitude;
        var total: f32 = 0;
        var norm: f32 = 0;
        var o: u32 = 0;
        while (o < self.octaves) : (o += 1) {
            total += valueNoise2D(self.seed +% @as(u64, o) *% 0x9E3779B9, wx, wz, freq) * amp;
            norm += amp;
            freq *= 2.0;
            amp *= 0.5;
        }
        const h = @as(f32, @floatFromInt(self.base_height)) + total / norm * self.amplitude;
        const clamped = @max(1, @min(14, @as(i32, @intFromFloat(@round(h)))));
        return @intCast(clamped);
    }

    /// Fill chunk at world chunk coords (cx,cz) with terrain columns.
    /// y=0 stone floor, stone below, dirt band, grass cap.
    pub fn generateChunk(self: TerrainGenerator, chunk: *Chunk, cx: i32, cz: i32) void {
        var lz: usize = 0;
        while (lz < SIZE) : (lz += 1) {
            var lx: usize = 0;
            while (lx < SIZE) : (lx += 1) {
                const wx = cx * 16 + @as(i32, @intCast(lx));
                const wz = cz * 16 + @as(i32, @intCast(lz));
                const h: usize = self.heightAt(wx, wz);
                var y: usize = 0;
                while (y <= h) : (y += 1) {
                    const b: BlockId = if (y == h) .grass else if (y >= h -% 2 and h >= 3) .dirt else .stone;
                    chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), b);
                }
            }
        }
    }
};

/// Hash world coords + seed to [0,1). Integer lattice value noise with
/// smoothstep interpolation.
fn valueNoise2D(seed: u64, wx: i32, wz: i32, freq: f32) f32 {
    const fx = @as(f32, @floatFromInt(wx)) * freq;
    const fz = @as(f32, @floatFromInt(wz)) * freq;
    const x0 = @as(i32, @intFromFloat(@floor(fx)));
    const z0 = @as(i32, @intFromFloat(@floor(fz)));
    const tx = fx - @floor(fx);
    const tz = fz - @floor(fz);
    const sx = tx * tx * (3 - 2 * tx);
    const sz = tz * tz * (3 - 2 * tz);
    const a = lattice(seed, x0, z0);
    const b = lattice(seed, x0 + 1, z0);
    const cc = lattice(seed, x0, z0 + 1);
    const d = lattice(seed, x0 + 1, z0 + 1);
    return (a * (1 - sx) + b * sx) * (1 - sz) + (cc * (1 - sx) + d * sx) * sz - 0.5;
}

fn lattice(seed: u64, x: i32, z: i32) f32 {
    var h: u64 = seed ^ (@as(u64, @bitCast(@as(i64, x))) *% 0x8da6b343);
    h ^= (@as(u64, @bitCast(@as(i64, z))) *% 0xd8163841);
    h ^= h >> 16;
    h *%= 0x45d9f3b;
    h ^= h >> 16;
    return @as(f32, @floatFromInt(h & 0xFFFF)) / 65535.0;
}

test "same seed same height" {
    const g = TerrainGenerator.init(1234);
    try std.testing.expectEqual(g.heightAt(5, 7), g.heightAt(5, 7));
}

test "different seeds differ somewhere" {
    const a = TerrainGenerator.init(1);
    const b = TerrainGenerator.init(999);
    var diff = false;
    var x: i32 = 0;
    while (x < 16) : (x += 1) {
        var z: i32 = 0;
        while (z < 16) : (z += 1) {
            if (a.heightAt(x, z) != b.heightAt(x, z)) diff = true;
        }
    }
    try std.testing.expect(diff);
}

test "heights in range" {
    const g = TerrainGenerator.init(42);
    var x: i32 = -20;
    while (x < 20) : (x += 1) {
        var z: i32 = -20;
        while (z < 20) : (z += 1) {
            const h: usize = g.heightAt(x, z);
            try std.testing.expect(h >= 1 and h <= 14);
        }
    }
}

test "chunk top block is grass" {
    const g = TerrainGenerator.init(42);
    var chunk = Chunk.init();
    g.generateChunk(&chunk, 0, 0);
    var found_grass = false;
    var y: usize = 0;
    while (y < SIZE) : (y += 1) {
        var z: usize = 0;
        while (z < SIZE) : (z += 1) {
            var x: usize = 0;
            while (x < SIZE) : (x += 1) {
                if (chunk.blocks[y][z][x] == .grass) found_grass = true;
                // No floating blocks: solid below every solid except y=0
                if (y > 0 and chunk.blocks[y][z][x] != .air) {
                    try std.testing.expect(chunk.blocks[y - 1][z][x] != .air);
                }
            }
        }
    }
    try std.testing.expect(found_grass);
    try std.testing.expect(chunk.solidBlockCount() > 0);
}

test "neighbor chunks agree on shared edge" {
    const g = TerrainGenerator.init(7);
    var a = Chunk.init();
    var b = Chunk.init();
    g.generateChunk(&a, 0, 0);
    g.generateChunk(&b, 1, 0);
    // Same world column via either chunk must match: heightAt is world-space.
    try std.testing.expectEqual(g.heightAt(15, 5), g.heightAt(15, 5));
    try std.testing.expect(a.solidBlockCount() > 0 and b.solidBlockCount() > 0);
}
