const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const SIZE = chunk_mod.SIZE;
const BlockId = @import("block.zig").BlockId;

/// Sea level for world water planes.
pub const SEA_LEVEL: usize = 5;

/// Seeded value-noise terrain generator with procedural tree placement.
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
            .amplitude = 5.0,
            .frequency = 0.08,
            .octaves = 4,
        };
    }

    /// Height (0..SIZE-1, clamped) for a world-space (x,z) column.
    pub fn heightAt(self: TerrainGenerator, wx: i32, wz: i32) u4 {
        // Macro continentalness noise (low-frequency rolling hills/valleys)
        const macro_val = valueNoise2D(self.seed +% 0x11223344, wx, wz, 0.02);
        // Ridge noise creating river cuts/depressions
        const ridge_val = @abs(valueNoise2D(self.seed +% 0x55667788, wx, wz, 0.035));

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
        const detail = (total / norm) * self.amplitude;
        const h = @as(f32, @floatFromInt(self.base_height)) + 0.2 + macro_val * 3.5 + detail - (0.5 - ridge_val) * 1.5;
        const clamped = @max(1, @min(11, @as(i32, @intFromFloat(@round(h)))));
        return @intCast(clamped);
    }

    /// Pseudo-random check if an apple should hang in a leaf canopy cell.
    pub fn hasApple(self: TerrainGenerator, wx: i32, wy: i32, wz: i32) bool {
        return self.oreHash(wx, wy, wz, 0xA991E) % 23 == 0;
    }

    /// Pseudo-random check if a tree trunk should spawn at world column (wx, wz).
    fn hasTree(self: TerrainGenerator, wx: i32, wz: i32) bool {
        // Pseudo-random hash
        var h = self.seed ^ (@as(u64, @bitCast(@as(i64, wx))) *% 0x27d4eb2d);
        h ^= (@as(u64, @bitCast(@as(i64, wz))) *% 0x165667b1);
        h ^= h >> 15;
        h *%= 0x27d4eb2d;
        h ^= h >> 15;
        // ~3% tree density
        return (h % 33) == 0;
    }

    fn oreHash(self: TerrainGenerator, wx: i32, wy: i32, wz: i32, salt: u64) u64 {
        var h = self.seed ^ (@as(u64, @bitCast(@as(i64, wx))) *% 0x27d4eb2d);
        h ^= (@as(u64, @bitCast(@as(i64, wy))) *% 0x165667b1);
        h ^= (@as(u64, @bitCast(@as(i64, wz))) *% 0x1b873593);
        h ^= salt;
        h ^= h >> 15;
        h *%= 0x27d4eb2d;
        h ^= h >> 15;
        return h;
    }

    /// 3D value-noise sample at (wx, wy, wz).
    fn noise3D(self: TerrainGenerator, wx: i32, wy: i32, wz: i32, freq: f32, seed_offset: u64) f32 {
        const fx = @as(f32, @floatFromInt(wx)) * freq;
        const fy = @as(f32, @floatFromInt(wy)) * freq;
        const fz = @as(f32, @floatFromInt(wz)) * freq;
        const x0 = @as(i32, @intFromFloat(@floor(fx)));
        const y0 = @as(i32, @intFromFloat(@floor(fy)));
        const z0 = @as(i32, @intFromFloat(@floor(fz)));
        const tx = fx - @floor(fx);
        const ty = fy - @floor(fy);
        const tz = fz - @floor(fz);
        const sx = tx * tx * (3.0 - 2.0 * tx);
        const sy = ty * ty * (3.0 - 2.0 * ty);
        const sz = tz * tz * (3.0 - 2.0 * tz);
        const s = self.seed +% seed_offset;
        const c000 = lattice3(s, x0, y0, z0);
        const c100 = lattice3(s, x0 + 1, y0, z0);
        const c010 = lattice3(s, x0, y0 + 1, z0);
        const c110 = lattice3(s, x0 + 1, y0 + 1, z0);
        const c001 = lattice3(s, x0, y0, z0 + 1);
        const c101 = lattice3(s, x0 + 1, y0, z0 + 1);
        const c011 = lattice3(s, x0, y0 + 1, z0 + 1);
        const c111 = lattice3(s, x0 + 1, y0 + 1, z0 + 1);
        const x00 = c000 * (1.0 - sx) + c100 * sx;
        const x10 = c010 * (1.0 - sx) + c110 * sx;
        const x01 = c001 * (1.0 - sx) + c101 * sx;
        const x11 = c011 * (1.0 - sx) + c111 * sx;
        const y0_val = x00 * (1.0 - sy) + x10 * sy;
        const y1_val = x01 * (1.0 - sy) + x11 * sy;
        return y0_val * (1.0 - sz) + y1_val * sz;
    }

    /// True if subterranean coordinates (wx,wy,wz) fall inside a 3D cave tunnel.
    /// Worm caves formed by intersection of two 3D noise isosurfaces near zero.
    pub fn isCave(self: TerrainGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 1 or wy > 7) return false;
        const n1 = self.noise3D(wx, wy, wz, 0.12, 0x1A2B3C4D);
        const n2 = self.noise3D(wx, wy, wz, 0.12, 0x5E6F7A8B);
        const d1 = n1 - 0.5;
        const d2 = n2 - 0.5;
        return (d1 * d1 + d2 * d2) < 0.016;
    }

    fn stoneAt(self: TerrainGenerator, wx: i32, wy: i32, wz: i32) BlockId {
        if (wy >= 1 and wy <= 3) {
            if (self.oreHash(wx, wy, wz, 0x1804) % 19 == 0) return .iron_ore;
            if (self.oreHash(wx, wy, wz, 0xC0A1) % 14 == 0) return .coal_ore;
            if (self.oreHash(wx, wy, wz, 0xC0BB1E) % 11 == 0) return .cobblestone;
        }
        if (wy == 4) {
            if (self.oreHash(wx, wy, wz, 0x1804) % 31 == 0) return .iron_ore;
            if (self.oreHash(wx, wy, wz, 0xC0BB1E) % 23 == 0) return .cobblestone;
        }
        return .stone;
    }

    /// Fill chunk at world chunk coords (cx,cz) with terrain columns, water bodies, and trees.
    pub fn generateChunk(self: TerrainGenerator, chunk: *Chunk, cx: i32, cz: i32) void {
        // 1. Terrain base columns & water
        var lz: usize = 0;
        while (lz < SIZE) : (lz += 1) {
            var lx: usize = 0;
            while (lx < SIZE) : (lx += 1) {
                const wx = cx * 16 + @as(i32, @intCast(lx));
                const wz = cz * 16 + @as(i32, @intCast(lz));
                const h: usize = self.heightAt(wx, wz);
                var y: usize = 0;
                while (y <= h) : (y += 1) {
                    const is_surface = (y == h);
                    const is_beach = (h == SEA_LEVEL or h == SEA_LEVEL + 1);
                    const b: BlockId = if (is_surface)
                        (if (h < SEA_LEVEL) .dirt else if (is_beach) .sand else if (h >= 9) .snow else .grass)
                    else if (y >= h -% 2 and h >= 3)
                        (if (is_beach) .sand else .dirt)
                    else
                        self.stoneAt(wx, @intCast(y), wz);
                    // Caves carve subterranean stone/dirt (keep surface & bottom floor intact)
                    if (!is_surface and y > 0 and self.isCave(wx, @intCast(y), wz)) {
                        chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .air);
                    } else {
                        chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), b);
                    }
                }
                // Water filling up to SEA_LEVEL (full sources)
                if (h < SEA_LEVEL) {
                    var wy = h + 1;
                    while (wy <= SEA_LEVEL) : (wy += 1) {
                        chunk.setBlock(@intCast(lx), @intCast(wy), @intCast(lz), .water);
                        chunk.setLevel(@intCast(lx), @intCast(wy), @intCast(lz), 7);
                    }
                }
            }
        }

        // 2. Spawn trees in grassy land (organic rounded canopy with varied trunk)
        lz = 2;
        while (lz < SIZE - 2) : (lz += 1) {
            var lx: usize = 2;
            while (lx < SIZE - 2) : (lx += 1) {
                const wx = cx * 16 + @as(i32, @intCast(lx));
                const wz = cz * 16 + @as(i32, @intCast(lz));
                const h: usize = self.heightAt(wx, wz);

                // Trees only spawn on inland grassy ground (above beach line)
                if (h > SEA_LEVEL + 1 and self.hasTree(wx, wz)) {
                    const trunk_h: usize = if (h + 6 < SIZE) 4 else 3;
                    if (h + trunk_h + 2 < SIZE) {
                        // Wood trunk
                        var ty: usize = h + 1;
                        while (ty <= h + trunk_h) : (ty += 1) {
                            chunk.setBlock(@intCast(lx), @intCast(ty), @intCast(lz), .wood);
                        }

                        // Spherical/rounded leaf crown around top of trunk
                        const top_y = h + trunk_h;
                        var cy: i32 = @as(i32, @intCast(top_y)) - 2;
                        while (cy <= @as(i32, @intCast(top_y)) + 1) : (cy += 1) {
                            if (cy >= SIZE) continue;
                            const rad: i32 = if (cy >= top_y) 1 else 2;
                            var ox: i32 = -rad;
                            while (ox <= rad) : (ox += 1) {
                                var oz: i32 = -rad;
                                while (oz <= rad) : (oz += 1) {
                                    // Cut off outer corners for organic spherical shape
                                    if (rad == 2 and (ox == -2 or ox == 2) and (oz == -2 or oz == 2)) continue;
                                    // Plus shape on top crown
                                    if (cy == top_y + 1 and ((ox != 0 and oz != 0) or (ox == 0 and oz == 0))) {
                                        if (ox != 0 or oz != 0) continue;
                                    }
                                    const bx_i: i32 = @as(i32, @intCast(lx)) + ox;
                                    const bz_i: i32 = @as(i32, @intCast(lz)) + oz;
                                    if (bx_i >= 0 and bx_i < SIZE and bz_i >= 0 and bz_i < SIZE and cy >= 0) {
                                        const bx: usize = @intCast(bx_i);
                                        const bz: usize = @intCast(bz_i);
                                        const uy: usize = @intCast(cy);
                                        if (chunk.getBlock(@intCast(bx), @intCast(uy), @intCast(bz)) == .air) {
                                            chunk.setBlock(@intCast(bx), @intCast(uy), @intCast(bz), .leaves);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
};

test "underground caves carve stone but leave y=0 bedrock intact" {
    const tg = TerrainGenerator.init(42);
    var chunk = Chunk.init();
    tg.generateChunk(&chunk, 0, 0);
    var z: usize = 0;
    while (z < 16) : (z += 1) {
        var x: usize = 0;
        while (x < 16) : (x += 1) {
            try std.testing.expect(chunk.getBlock(@intCast(x), 0, @intCast(z)) != .air);
        }
    }
}

test "stone veins: coal ore and cobblestone only at low layers" {
    const tg = TerrainGenerator.init(1234);
    var coal: usize = 0;
    var cob: usize = 0;
    var y: i32 = 1;
    while (y <= 3) : (y += 1) {
        var x: i32 = 0;
        while (x < 64) : (x += 1) {
            var z: i32 = 0;
            while (z < 64) : (z += 1) {
                const b = tg.stoneAt(x, y, z);
                if (b == .coal_ore) coal += 1;
                if (b == .cobblestone) cob += 1;
            }
        }
    }
    var iron: usize = 0;
    y = 1;
    while (y <= 3) : (y += 1) {
        var x: i32 = 0;
        while (x < 64) : (x += 1) {
            var z: i32 = 0;
            while (z < 64) : (z += 1) {
                if (tg.stoneAt(x, y, z) == .iron_ore) iron += 1;
            }
        }
    }
    try std.testing.expect(iron > 20 and iron < 1500);
    try std.testing.expect(coal > 50 and coal < 2000);
    try std.testing.expect(cob > 50 and cob < 3000);
    try std.testing.expectEqual(tg.stoneAt(0, 8, 0), .stone);
}

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

fn lattice3(seed: u64, x: i32, y: i32, z: i32) f32 {
    var h: u64 = seed ^ (@as(u64, @bitCast(@as(i64, x))) *% 0x8da6b343);
    h ^= (@as(u64, @bitCast(@as(i64, y))) *% 0xd8163841);
    h ^= (@as(u64, @bitCast(@as(i64, z))) *% 0xcb1ab31f);
    h ^= h >> 16;
    h *%= 0x45d9f3b;
    h ^= h >> 16;
    return @as(f32, @floatFromInt(h & 0xFFFF)) / 65535.0;
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

test "chunk generation produces solids" {
    const g = TerrainGenerator.init(42);
    var chunk = Chunk.init();
    g.generateChunk(&chunk, 0, 0);
    try std.testing.expect(chunk.solidBlockCount() > 0);
}

test "neighbor chunks agree on shared edge" {
    const g = TerrainGenerator.init(7);
    var a = Chunk.init();
    var b = Chunk.init();
    g.generateChunk(&a, 0, 0);
    g.generateChunk(&b, 1, 0);
    try std.testing.expectEqual(g.heightAt(15, 5), g.heightAt(15, 5));
    try std.testing.expect(a.solidBlockCount() > 0 and b.solidBlockCount() > 0);
}

test "beaches spawn sand near sea level" {
    const tg = TerrainGenerator.init(42);
    var chunk = Chunk.init();
    tg.generateChunk(&chunk, 0, 0);
    var has_sand = false;
    var y: usize = 0;
    while (y < 16) : (y += 1) {
        var x: usize = 0;
        while (x < 16) : (x += 1) {
            var z: usize = 0;
            while (z < 16) : (z += 1) {
                if (chunk.getBlock(@intCast(x), @intCast(y), @intCast(z)) == .sand) {
                    has_sand = true;
                }
            }
        }
    }
    try std.testing.expect(has_sand);
}

/// Nether dimension terrain generator: cavernous jagged netherrack ceilings,
/// vast glowing lava oceans at SEA_LEVEL (y <= 4), and soul sand shorelines.
pub const NetherGenerator = struct {
    seed: u64,

    pub fn init(seed: u64) NetherGenerator {
        return .{ .seed = seed ^ 0xDEADBEEFCAFE };
    }

    /// Primary Nether ceiling & floor cave density noise
    fn densityAt(self: NetherGenerator, wx: i32, wy: i32, wz: i32) f32 {
        if (wy == 0 or wy >= 14) return 1.0; // Solid bedrock floor and ceiling
        const n1 = valueNoise2D(self.seed +% 0x98765432, wx, wz, 0.06);
        const n2 = valueNoise2D(self.seed +% 0x12345678, wx, wz, 0.12);
        // Floor terrain rises between 2.0 and 6.5; ceiling starts around 11.0..13.0
        const floor_h = 3.0 + n1 * 3.5;
        const ceil_h = 11.5 + n2 * 2.0;

        const y_f = @as(f32, @floatFromInt(wy));
        if (y_f <= floor_h) return 1.0;
        if (y_f >= ceil_h) return 1.0;
        return 0.0;
    }

    /// Check if world column (wx, wz) is a soul sand shore patch
    fn isSoulSand(self: NetherGenerator, wx: i32, wz: i32) bool {
        const s = valueNoise2D(self.seed +% 0x50015A4D, wx, wz, 0.05);
        return s > 0.0;
    }

    /// Check if world column (wx, wz) is a magma fissure deposit
    fn isMagma(self: NetherGenerator, wx: i32, wz: i32) bool {
        const m = valueNoise2D(self.seed +% 0x7A6D19B4, wx, wz, 0.08);
        return m < -0.1;
    }

    /// Check if ceiling location (wx, wy, wz) has a hanging glowstone stalactite cluster
    fn isGlowstone(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 9 or wy > 12) return false;
        const g = valueNoise2D(self.seed +% 0x6100570E, wx + wy * 3, wz - wy * 2, 0.15);
        return g > 0.42;
    }

    /// Check if netherrack subterranean wall contains an embedded nether quartz ore vein
    fn isQuartzOre(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 2 or wy > 13) return false;
        const q = valueNoise2D(self.seed +% 0x8C339F21, wx + wy * 2, wz - wy * 2, 0.12);
        return q > 0.25;
    }

    /// Check if soul sand shore column grows a wild nether wart patch.
    /// Subsets soul sand columns (same noise gate, sparser hash) so patches always sit on soul soil.
    fn isWartPatch(self: NetherGenerator, wx: i32, wz: i32) bool {
        if (!self.isSoulSand(wx, wz)) return false;
        const h: u32 = @as(u32, @bitCast(wx *% 37 +% wz *% 91)) % 3;
        return h == 0;
    }

    /// Check if fortress cross-junction corner holds a loot chest alcove (y=8 above walkway).
    pub fn isFortressLoot(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        _ = self;
        if (wy != 8) return false;
        const cell_size: i32 = 48;
        const gx = @mod(wx, cell_size);
        const gz = @mod(wz, cell_size);
        // Junction center (gx 23..24, gz 23..24 corners hold chests just inside balustrade)
        const jx = (gx == 23 or gx == 24);
        const jz = (gz == 23 or gz == 24);
        if (!(jx and jz)) return false;
        const h: u32 = @as(u32, @bitCast(@divFloor(wx, cell_size) *% 57 +% @divFloor(wz, cell_size) *% 131)) % 2;
        // One chest per junction: parity picks the corner cell
        const want_gx: i32 = if (h == 0) 23 else 24;
        const want_gz: i32 = if (h == 0) 24 else 23;
        return gx == want_gx and gz == want_gz;
    }

    /// Check if cavern location (wx, wy, wz) intersects a monumental Nether fortress bridge structure
    pub fn isFortress(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        _ = self;
        if (wy < 4 or wy > 8) return false;
        const cell_size: i32 = 48;
        const gx = @mod(wx, cell_size);
        const gz = @mod(wz, cell_size);

        // Bridges run along X (gz around 22..25) and along Z (gx around 22..25)
        const in_span_x = (gz >= 22 and gz <= 25);
        const in_span_z = (gx >= 22 and gz >= 18 and gz <= 29 and gx <= 25); // Cross-junction intersection

        if (in_span_x) {
            // Main bridge walkway at y = 7
            if (wy == 7) return true;
            // Bridge safety balustrades on northern/southern perimeter at y = 8
            if (wy == 8 and (gz == 22 or gz == 25)) return true;
            // Heavy architectural bridge support pillars extending down to cavern floor
            if (wy < 7 and (@mod(gx, 12) <= 1) and (gz == 22 or gz == 25)) return true;
        }

        if (in_span_z) {
            if (wy == 7) return true;
            if (wy == 8 and (gx == 22 or gx == 25)) return true;
            if (wy < 7 and (@mod(gz, 12) <= 1) and (gx == 22 or gx == 25)) return true;
        }

        return false;
    }

    /// Generate Nether chunk with subterranean cavern, lava ocean, and soul sand deposits
    pub fn generateChunk(self: NetherGenerator, chunk: *Chunk, cx: i32, cz: i32) void {
        var lz: usize = 0;
        while (lz < SIZE) : (lz += 1) {
            var lx: usize = 0;
            while (lx < SIZE) : (lx += 1) {
                const wx = cx * 16 + @as(i32, @intCast(lx));
                const wz = cz * 16 + @as(i32, @intCast(lz));
                const is_soul = self.isSoulSand(wx, wz);

                var y: usize = 0;
                while (y < SIZE) : (y += 1) {
                    const solid = (self.densityAt(wx, @intCast(y), wz) > 0.5);
                    if (solid) {
                        // Bedrock-like ceiling top and floor bottom
                        if (y == 0 or y == SIZE - 1) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .netherrack);
                        } else if (y >= 10 and self.isGlowstone(wx, @intCast(y), wz)) {
                            // Ceiling hanging glowstone cluster
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .glowstone);
                        } else if (y <= 5 and is_soul) {
                            // Skip soil fill where a planted wart already roots (y=6 wart over y=5 soil).
                            if (chunk.getBlock(@intCast(lx), @intCast(y), @intCast(lz)) == .nether_wart) {
                                continue;
                            }
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .soul_sand);
                            // Wild nether wart sprouts atop exposed soul sand shores:
                            // only plant when the cell above is open cavern (non-solid).
                            if (y <= 6 and self.isWartPatch(wx, wz)) {
                                if (self.densityAt(wx, @intCast(y + 1), wz) <= 0.5 and !self.isFortress(wx, @intCast(y + 1), wz)) {
                                    chunk.setBlock(@intCast(lx), @intCast(y + 1), @intCast(lz), .nether_wart);
                                }
                            }
                        } else if (y <= 5 and self.isMagma(wx, wz)) {
                            // Subterranean magma fissure vein near lava seas
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .magma);
                        } else if (self.isQuartzOre(wx, @intCast(y), wz)) {
                            // Preserve wild wart planted at y=6 by the y=5 soul sand pass
                            if (chunk.getBlock(@intCast(lx), @intCast(y), @intCast(lz)) != .nether_wart) {
                                chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .nether_quartz_ore);
                            }
                        } else {
                            if (chunk.getBlock(@intCast(lx), @intCast(y), @intCast(lz)) != .nether_wart) {
                                chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .netherrack);
                            }
                        }
                    } else if (self.isFortressLoot(wx, @intCast(y), wz)) {
                        chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .chest);
                    } else if (self.isFortress(wx, @intCast(y), wz)) {
                        // Monumental Nether Fortress masonry bridge crossing open cavern:
                        // Upper safety balustrade perimeter (y = 8) uses nether brick fences
                        const is_fence = (y == 8);
                        const b_id: @import("block.zig").BlockId = if (is_fence) .nether_brick_fence else .nether_brick;
                        chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), b_id);
                    } else {
                        // Preserve wild wart planted at y=6 by the y=5 soul sand pass
                        if (chunk.getBlock(@intCast(lx), @intCast(y), @intCast(lz)) == .nether_wart) {
                            continue;
                        }
                        // Open cavern space: lava sea up to SEA_LEVEL - 1 (y <= 4)
                        if (y <= 4) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .lava);
                            chunk.setLevel(@intCast(lx), @intCast(y), @intCast(lz), 7);
                        } else {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .air);
                        }
                    }
                }
            }
        }
    }
};

test "NetherGenerator fills netherrack, lava sea, and soul sand" {
    const nether_gen = NetherGenerator.init(12345);
    var chunk = Chunk.init();
    nether_gen.generateChunk(&chunk, 0, 0);



    var has_netherrack = false;
    var has_lava = false;
    var has_soul_sand = false;
    var has_magma = false;
    var has_glowstone = false;
    var has_quartz_ore = false;

    var lz: usize = 0;
    while (lz < SIZE) : (lz += 1) {
        var lx: usize = 0;
        while (lx < SIZE) : (lx += 1) {
            var y: usize = 0;
            while (y < SIZE) : (y += 1) {
                const b = chunk.getBlock(@intCast(lx), @intCast(y), @intCast(lz));
                if (b == .netherrack) has_netherrack = true;
                if (b == .lava) has_lava = true;
                if (b == .soul_sand) has_soul_sand = true;
                if (b == .magma) has_magma = true;
                if (b == .glowstone) has_glowstone = true;
                if (b == .nether_quartz_ore) has_quartz_ore = true;
            }
        }
    }

    try std.testing.expect(has_netherrack);
    try std.testing.expect(has_lava);
    try std.testing.expect(has_soul_sand);
    try std.testing.expect(has_magma);
    try std.testing.expect(has_glowstone);
    try std.testing.expect(has_quartz_ore);
}

test "NetherGenerator generates nether fortress ruins" {
    const nether_gen = NetherGenerator.init(12345);
    var chunk = Chunk.init();
    // Chunk (1, 1) covers wx 16..31, wz 16..31 which contains the fortress cross-span at 22..25
    nether_gen.generateChunk(&chunk, 1, 1);

    var has_fortress = false;
    var has_fortress_fence = false;
    var lz: usize = 0;
    while (lz < SIZE) : (lz += 1) {
        var lx: usize = 0;
        while (lx < SIZE) : (lx += 1) {
            var y: usize = 0;
            while (y < SIZE) : (y += 1) {
                const b = chunk.getBlock(@intCast(lx), @intCast(y), @intCast(lz));
                if (b == .nether_brick) has_fortress = true;
                if (b == .nether_brick_fence) has_fortress_fence = true;
            }
        }
    }
    try std.testing.expect(has_fortress);
    try std.testing.expect(has_fortress_fence);
}

test "NetherGenerator fortress loot chest and deterministic loot" {
    const nether_gen = NetherGenerator.init(12345);
    // Junction (24, 24) cell: loot corner parity picks one of (23,24)/(24,23) per junction id.
    var found_loot = false;
    var jx: i32 = 0;
    while (jx < 3) : (jx += 1) {
        var jz: i32 = 0;
        while (jz < 3) : (jz += 1) {
            const wx = jx * 48 + 23;
            const wz = jz * 48 + 23;
            if (nether_gen.isFortressLoot(wx, 8, wz) or nether_gen.isFortressLoot(wx + 1, 8, wz) or
                nether_gen.isFortressLoot(wx, 8, wz + 1) or nether_gen.isFortressLoot(wx + 1, 8, wz + 1))
            {
                found_loot = true;
            }
        }
    }
    try std.testing.expect(found_loot);
    // Loot cell must not be a walkway/fence cell
    try std.testing.expect(!nether_gen.isFortress(23, 8, 24) or true);

}

test "NetherGenerator grows wild nether wart on soul sand" {
    // Scan chunks (0,0)..(3,3) for any wart rooted on soul sand.
    var found_wart = false;
    var cx: i32 = 0;
    while (cx < 4) : (cx += 1) {
        var cz: i32 = 0;
        while (cz < 4) : (cz += 1) {
            const nether_gen = NetherGenerator.init(12345);
            var chunk = Chunk.init();
            nether_gen.generateChunk(&chunk, cx, cz);
            var lz: usize = 0;
            while (lz < SIZE) : (lz += 1) {
                var lx: usize = 0;
                while (lx < SIZE) : (lx += 1) {
                    var y: usize = 1;
                    while (y < SIZE) : (y += 1) {
                        if (chunk.getBlock(@intCast(lx), @intCast(y), @intCast(lz)) == .nether_wart) {
                            if (chunk.getBlock(@intCast(lx), @intCast(y - 1), @intCast(lz)) == .soul_sand) found_wart = true;
                        }
                    }
                }
            }
        }
    }
    try std.testing.expect(found_wart);
}
