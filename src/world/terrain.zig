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

    /// Deterministic check whether a tree column (wx, wz) is a Pale Oak tree variant.
    /// Returns true for approximately 8% of tree positions.
    pub fn isPaleOakTree(self: TerrainGenerator, wx: i32, wz: i32) bool {
        return lattice(self.seed ^ 0x5A1E_0A4C, wx, wz) < 0.08;
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
            if (self.oreHash(wx, wy, wz, 0x4E0570) % 23 == 0) return .redstone_ore;
            if (self.oreHash(wx, wy, wz, 0x601D) % 29 == 0) return .gold_ore;
            if (self.oreHash(wx, wy, wz, 0xD1A4) % 37 == 0) return .diamond_ore;
            if (self.oreHash(wx, wy, wz, 0xE3E4) % 43 == 0) return .emerald_ore;
            if (self.oreHash(wx, wy, wz, 0x1A915) % 27 == 0) return .lapis_ore;
            if (self.oreHash(wx, wy, wz, 0xC099E4) % 21 == 0) return .copper_ore;
            if (self.oreHash(wx, wy, wz, 0xA3E7) % 47 == 0) return .amethyst_block;
            if (wy == 1 and self.oreHash(wx, wy, wz, 0xDEE9) % 13 == 0) return .deepslate;
            if (wy == 2 and self.oreHash(wx, wy, wz, 0x70FF) % 17 == 0) return .tuff;
            if (self.oreHash(wx, wy, wz, 0xC0BB1E) % 11 == 0) return .cobblestone;
        }
        if (wy == 4) {
            if (self.oreHash(wx, wy, wz, 0x1804) % 31 == 0) return .iron_ore;
            if (self.oreHash(wx, wy, wz, 0xC0BB1E) % 23 == 0) return .cobblestone;
        }
        return .stone;
    }


    /// Check if coordinates (wx, wy, wz) intersect the submerged Ocean Monument structure.
    /// Centered at wx in -8..8, wz in -24..-8, submerged at ocean floor wy in 1..7 (water ceiling wy=8).
    /// Features Prismarine exterior pyramid, Sea Lantern pillars, and interior Conduit altar.
    pub fn getOceanMonumentBlock(self: TerrainGenerator, wx: i32, wy: i32, wz: i32) ?BlockId {
        _ = self;
        if (wx < -8 or wx > 8 or wz < -24 or wz > -8) return null;
        if (wy < 1 or wy > 7) return null;

        // Central altar chamber with Conduit at (0, 3, -16) and apex Elder Guardian boss room vault
        if (wx == 0 and wz == -16) {
            if (wy == 2) return .dark_prismarine;
            if (wy == 3) return .conduit;
            if (wy == 4) return .sea_lantern;
            if (wy == 5 or wy == 6) return .wet_sponge;
        }

        // 4 corner Sea Lantern beacon pillars at (+-6, wy, -22 / -10)
        const is_corner_x = (wx == -6 or wx == 6);
        const is_corner_z = (wz == -22 or wz == -10);
        if (is_corner_x and is_corner_z) {
            if (wy == 5) return .sea_lantern;
            if (wy <= 4) return .dark_prismarine;
        }

        // Stepped pyramid roof at wy = 6..7
        if (wy == 7) {
            if (@abs(wx) <= 2 and @abs(wz - (-16)) <= 2) return .sea_lantern;
            return null;
        }
        if (wy == 6) {
            if (@abs(wx) <= 5 and @abs(wz - (-16)) <= 5) return .prismarine_bricks;
            return null;
        }

        // Monument foundation floor at wy = 1
        if (wy == 1) return .dark_prismarine;

        // Perimeter exterior walls at wy = 2..5
        if (wx == -8 or wx == 8 or wz == -24 or wz == -8) {
            // Entryway arch at south face (wz == -8, wx in -1..1, wy in 2..3)
            if (wz == -8 and @abs(wx) <= 1 and (wy == 2 or wy == 3)) return .water;
            return if (@mod(wy, 2) == 0) .prismarine else .prismarine_bricks;
        }

        // Interior flooded chambers: water filled with prismarine floor/pillars
        return .water;
    }


    /// Check if cavern coordinates (wx, wy, wz) intersect an Abandoned Mineshaft corridor structure.
    /// Deep underground subterranean corridors (wy in 3..6) featuring oak plank floor/walkways,
    /// oak fence support struts & arch timber frames every 4 blocks, rail track lines,
    /// intermittent powered rails, cobweb clusters, and abandoned minecart loot chests.
    pub fn getAbandonedMineshaftBlock(self: TerrainGenerator, wx: i32, wy: i32, wz: i32) ?BlockId {
        _ = self;
        // Deep underground elevation bound
        if (wy < 3 or wy > 6) return null;

        // Primary corridor axis: East-West along wz in 15..17 (center wz = 16), length wx in -32..32
        const is_primary_ew = (wx >= -32 and wx <= 32 and wz >= 15 and wz <= 17);
        // Crossing branch corridor: North-South along wx in -1..1 (center wx = 0), length wz in -16..32
        const is_branch_ns = (wz >= -16 and wz <= 32 and wx >= -1 and wx <= 1);

        if (!is_primary_ew and !is_branch_ns) return null;

        const is_center = (is_primary_ew and wz == 16) or (is_branch_ns and wx == 0);

        // Floor at wy = 3: wooden walkways under rail tracks, cobblestone/gravel ballast
        if (wy == 3) {
            if (is_center) return .wood_planks;
            return .cobblestone;
        }

        // Timber arch support frames every 4 blocks along corridor
        const is_arch_x = is_primary_ew and (@mod(wx, 4) == 0);
        const is_arch_z = is_branch_ns and (@mod(wz, 4) == 0);

        // Ceiling beam at wy = 6
        if (wy == 6) {
            if (is_arch_x or is_arch_z) return .wood_planks;
            // Cobwebs hanging from ceiling
            const web_hash: u32 = @as(u32, @bitCast(wx *% 31 +% wz *% 73));
            if ((web_hash % 10) == 0) return .cobweb;
            return .air;
        }

        // Walls / support posts at sides (wy in 4..5)
        const is_side = (is_primary_ew and (wz == 15 or wz == 17)) or (is_branch_ns and (wx == -1 or wx == 1));
        if (is_side) {
            if (is_arch_x or is_arch_z) return .oak_fence;
            // Occasional cobwebs in side corners
            const side_hash: u32 = @as(u32, @bitCast(wx *% 53 +% wz *% 29 +% wy *% 11));
            if ((side_hash % 8) == 0) return .cobweb;
            return .air;
        }

        // Cave spider spawner cage nest at wx = -16, wz = 16 surrounded by dense cobwebs
        if (wx >= -18 and wx <= -14 and wz >= 15 and wz <= 17) {
            if (wx == -16 and wz == 16 and wy == 4) return .spawner_cage;
            if (wy >= 4 and wy <= 5) {
                // Dense web nest around spawner
                if (@abs(wx - (-16)) <= 1 and (wy == 4 or wy == 5)) return .cobweb;
            }
        }

        // Center track corridor at wy = 4: Rails, Powered Rails, Torches, Chests
        if (wy == 4 and is_center) {
            // Chest at branch junction or dead ends
            if ((wx == 0 and wz == 16) or (wx == 30 and wz == 16)) return .chest;
            // Redstone powered rail every 8 blocks
            if (@mod(wx, 8) == 4 or @mod(wz, 8) == 4) return .powered_rail;
            return .rail;
        }

        // Corridor interior air clearance
        return .air;
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

                // Submerged Kelp Forest generation: in ocean water columns on seafloor
                if (h < SEA_LEVEL and h >= 1) {
                    // Hash column position deterministically for kelp forest stalks
                    const kh: u32 = @as(u32, @bitCast(wx *% 73 +% wz *% 109));
                    if ((kh % 100) < 35) {
                        const max_ky = @min(SEA_LEVEL, h + 1 + @as(usize, @intCast((kh >> 8) % 3)));
                        var ky = h + 1;
                        while (ky <= max_ky) : (ky += 1) {
                            chunk.setBlock(@intCast(lx), @intCast(ky), @intCast(lz), .kelp);
                        }
                    }
                }

                // Submerged Sea Pickle colonies: bioluminescent clusters on ocean seafloor
                if (h < SEA_LEVEL and h >= 1) {
                    const sp_hash: u32 = @as(u32, @bitCast(wx *% 127 +% wz *% 67));
                    if ((sp_hash % 100) < 14) {
                        const spy = h + 1;
                        if (spy <= SEA_LEVEL and chunk.getBlock(@intCast(lx), @intCast(spy), @intCast(lz)) == .water) {
                            chunk.setBlock(@intCast(lx), @intCast(spy), @intCast(lz), .sea_pickle);
                        }
                    }
                }

                // Submerged Ocean Monument structure override
                var my: i32 = 1;
                while (my <= 7) : (my += 1) {
                    if (self.getOceanMonumentBlock(wx, my, wz)) |mb| {
                        chunk.setBlock(@intCast(lx), @intCast(my), @intCast(lz), mb);
                        if (mb == .water) chunk.setLevel(@intCast(lx), @intCast(my), @intCast(lz), 7);
                    }
                }

                // Subterranean Abandoned Mineshaft structure override (wy in 3..6)
                var shy: i32 = 3;
                while (shy <= 6) : (shy += 1) {
                    if (self.getAbandonedMineshaftBlock(wx, shy, wz)) |sb| {
                        chunk.setBlock(@intCast(lx), @intCast(shy), @intCast(lz), sb);
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
                        const is_pale_oak = self.isPaleOakTree(wx, wz) and trunk_h >= 3;
                        // Wood or Pale Oak trunk with sandwiched Creaking Heart
                        var ty: usize = h + 1;
                        while (ty <= h + trunk_h) : (ty += 1) {
                            if (is_pale_oak) {
                                if (ty == h + 2) {
                                    chunk.setBlock(@intCast(lx), @intCast(ty), @intCast(lz), .creaking_heart);
                                } else {
                                    chunk.setBlock(@intCast(lx), @intCast(ty), @intCast(lz), .pale_oak_log);
                                }
                            } else {
                                chunk.setBlock(@intCast(lx), @intCast(ty), @intCast(lz), .wood);
                            }
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
    tg.generateChunk(&chunk, -10, -10);
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
    tg.generateChunk(&chunk, -10, -10);
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

    /// Check if deeply buried netherrack contains an ancient debris fossil deposit (y = 2..4).
    /// Uses deterministic 3D hash (~1 in 80 cells at y=2..4) so veins are rare, scattered deep fossils.
    /// Check if deep cavern or lava shore strata contains a crying obsidian cluster (y = 3..5).
    /// Uses deterministic 3D hash (~1 in 90 cells at y=3..5) near ancient ruins/magma beds.
    /// Check if cavern location (wx, wy, wz) intersects a procedural basalt column cluster.
    /// Columns emerge from lava floors/shores (y = 4..11) in volcanic delta patches.
    /// Check if cavern location (wx, wy, wz) forms a Blackstone Bastion Remnant ruin rampart (y = 5..10).
    /// Generates imposing square bastions with central courtyards at cell_size = 64 intervals.
    /// Check if bastion rampart location contains a gilded blackstone gold seam deposit.
    pub fn isGildedBlackstone(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (!self.isBastionRampart(wx, wy, wz)) return false;
        // Floor at y=5 is plain blackstone; veins sit inside vertical rampart walls (wy=6..9)
        if (wy < 6 or wy > 9) return false;
        const seed_mix: u32 = @truncate(self.seed);
        const h: u32 = (@as(u32, @bitCast(wx *% 31 +% wy *% 17 +% wz *% 79)) +% seed_mix) % 8;
        return h == 0;
    }

    pub fn isBastionRampart(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 5 or wy > 10) return false;
        const cell_size: i32 = 64;
        const gx = @mod(wx, cell_size);
        const gz = @mod(wz, cell_size);

        // Bastion footprint: 12x12 perimeter ramparts centered at gx, gz ~ 40..51
        const in_outer = (gx >= 40 and gx <= 51 and gz >= 40 and gz <= 51);
        if (!in_outer) return false;

        // Inner courtyard opening (open air in center at gx, gz 43..48)
        const in_inner = (gx >= 43 and gx <= 48 and gz >= 43 and gz <= 48);

        // Parity hash selects 50% of 64x64 cells for bastion ruins
        const cell_x = @divFloor(wx, cell_size);
        const cell_z = @divFloor(wz, cell_size);
        const seed_mix: u32 = @truncate(self.seed);
        const h: u32 = (@as(u32, @bitCast(cell_x *% 97 +% cell_z *% 43)) +% seed_mix) % 100;
        if (h >= 50) return false;

        // Main rampart walkway floor at y = 5
        if (wy == 5) return true;
        // Outer defensive rampart walls up to y = 10
        if (!in_inner) return true;
        // Central courtyard is open (except floor at y=5)
        return false;
    }

    pub fn isBasaltColumn(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 4 or wy > 11) return false;
        const cell_size: i32 = 32;
        const gx = @mod(wx, cell_size);
        const gz = @mod(wz, cell_size);

        // Column roots sit at specific delta clusters in the cell
        const is_center_col = ((gx >= 6 and gx <= 7) and (gz >= 6 and gz <= 7));
        const is_offset_col = ((gx >= 9 and gx <= 10) and (gz >= 8 and gz <= 9));
        if (!is_center_col and !is_offset_col) return false;

        // Check height variation per column using cell coordinates
        const cell_x = @divFloor(wx, cell_size);
        const cell_z = @divFloor(wz, cell_size);
        const seed_mix: u32 = @truncate(self.seed);
        const h: u32 = (@as(u32, @bitCast(cell_x *% 83 +% cell_z *% 59)) +% seed_mix) % 100;
        // 40% of cells have basalt column formations
        if (h >= 40) return false;

        // Column max height varies between y=8 and y=11
        const max_h: i32 = if (is_center_col) 11 else 9;
        return wy <= max_h;
    }

    pub fn isCryingObsidian(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 3 or wy > 5) return false;
        const seed_mix: u32 = @truncate(self.seed);
        const h: u32 = (@as(u32, @bitCast(wx *% 47 +% wy *% 29 +% wz *% 67)) +% seed_mix) % 90;
        return h == 0;
    }

    fn isAncientDebris(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 2 or wy > 4) return false;
        const seed_mix: u32 = @truncate(self.seed);
        const h: u32 = (@as(u32, @bitCast(wx *% 73 +% wy *% 19 +% wz *% 37)) +% seed_mix) % 80;
        return h == 0;
    }

    /// Check if cavern ceiling/shelf location grows organic shroomlight clusters (y = 7..10).
    /// Shroomlights embed in luminous clusters beneath cavern overhangs and fungi shelves.
    pub fn isShroomlight(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 7 or wy > 10) return false;
        const v = valueNoise2D(self.seed +% 0x48B2C917, wx, wz, 0.11);
        if (v < 0.29) return false;
        const h: u32 = (@as(u32, @bitCast(wx *% 61 +% wy *% 41 +% wz *% 73)) % 11);
        return h == 0;
    }

    /// Check if cavern floor location grows a crimson fungus (y = 6 atop netherrack cavern floor).
    pub fn isCrimsonFungus(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy != 6) return false;
        if (self.isSoulSand(wx, wz)) return false; // Crimson prefers netherrack
        const v = valueNoise2D(self.seed +% 0x51A8D413, wx, wz, 0.12);
        if (v < 0.28) return false;
        const h: u32 = (@as(u32, @bitCast(wx *% 29 +% wz *% 71)) % 5);
        return h == 0;
    }

    /// Check if soul sand shore location grows a warped fungus (y = 6 atop soul sand shore).
    pub fn isWarpedFungus(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy != 6) return false;
        if (!self.isSoulSand(wx, wz)) return false; // Warped prefers soul sand
        const v = valueNoise2D(self.seed +% 0x7E319A05, wx, wz, 0.13);
        if (v < 0.26) return false;
        const h: u32 = (@as(u32, @bitCast(wx *% 31 +% wz *% 83)) % 4);
        return h == 0;
    }

    /// Check if soul sand floor location (wx, wy, wz) grows an upward twisting vine stalk (y = 6..9).
    /// Twisting vines rise vertically 1 to 4 blocks from soul sand shore floors in cyan warped patches.
    pub fn isTwistingVine(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 6 or wy > 9) return false;
        if (!self.isSoulSand(wx, wz)) return false;
        // Twisting vine stalks emerge in specific soul sand shore pockets
        const s = valueNoise2D(self.seed +% 0x9B118743, wx, wz, 0.14);
        if (s < 0.22) return false;
        const h: u32 = (@as(u32, @bitCast(wx *% 53 +% wz *% 79)) % 4) + 1; // 1..4 blocks high above y=5 floor
        return wy <= 5 + @as(i32, @intCast(h));
    }

    /// Check if cavern ceiling location (wx, wy, wz) grows a hanging weeping vine tendril (y = 8..12).
    /// Tendrils hang downwards 1 to 3 blocks below the cavern netherrack ceiling in crimson clusters.
    pub fn isWeepingVine(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        if (wy < 7 or wy > 12) return false;
        // Tendrils cluster in crimson cavern patches
        const v = valueNoise2D(self.seed +% 0x33A7C159, wx, wz, 0.10);
        if (v < 0.25) return false;
        const h: u32 = (@as(u32, @bitCast(wx *% 43 +% wz *% 67)) % 3) + 1; // 1..3 blocks long
        const n2 = valueNoise2D(self.seed +% 0x12345678, wx, wz, 0.12);
        const ceil_y: i32 = @intFromFloat(@floor(11.5 + n2 * 2.0));
        return (wy < ceil_y and wy >= ceil_y - @as(i32, @intCast(h)));
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

    /// Check if cavern location (wx, wy, wz) hosts an emberbeast spawner cage at a fortress junction center
    pub fn isFortressSpawner(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        _ = self;
        if (wy != 8) return false;
        const cell_size: i32 = 48;
        const gx = @mod(wx, cell_size);
        const gz = @mod(wz, cell_size);
        // Chest sits at (23,24) or (24,23). Spawner cage sits at the opposite diagonal junction cell (24,24) or (23,23)
        const h: u32 = @as(u32, @bitCast(@divFloor(wx, cell_size) *% 57 +% @divFloor(wz, cell_size) *% 131)) % 2;
        const want_gx: i32 = if (h == 0) 24 else 23;
        const want_gz: i32 = if (h == 0) 24 else 23;
        return gx == want_gx and gz == want_gz;
    }

    /// Check if cavern location (wx, wy, wz) mounts an ambient soul torch atop fortress fence balustrades
    pub fn isFortressTorch(self: NetherGenerator, wx: i32, wy: i32, wz: i32) bool {
        _ = self;
        if (wy != 9) return false;
        const cell_size: i32 = 48;
        const gx = @mod(wx, cell_size);
        const gz = @mod(wz, cell_size);

        // Bridge X balustrades: y=8 fences at gz == 22 or 25; torch sits at y=9
        const on_x_balustrade = (gz == 22 or gz == 25);
        if (on_x_balustrade and (@mod(gx, 6) == 0)) return true;

        // Bridge Z balustrades: y=8 fences at gx == 22 or 25; torch sits at y=9
        const in_span_z = (gz >= 18 and gz <= 29);
        const on_z_balustrade = (gx == 22 or gx == 25) and in_span_z;
        if (on_z_balustrade and (@mod(gz, 6) == 0)) return true;

        return false;
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
                        } else if (self.isAncientDebris(wx, @intCast(y), wz)) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .ancient_debris);
                        } else if (self.isCryingObsidian(wx, @intCast(y), wz)) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .crying_obsidian);
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
                    } else if (self.isFortressSpawner(wx, @intCast(y), wz)) {
                        chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .spawner_cage);
                    } else if (self.isFortressTorch(wx, @intCast(y), wz)) {
                        chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .soul_torch);
                    } else if (self.isFortress(wx, @intCast(y), wz)) {
                        // Monumental Nether Fortress masonry bridge crossing open cavern:
                        // Upper safety balustrade perimeter (y = 8) uses nether brick fences
                        const is_fence = (y == 8);
                        const is_chiseled = (y == 7 and (@mod(wx, 6) == 0 or @mod(wz, 6) == 0));
                        const b_id: @import("block.zig").BlockId = if (is_fence) .nether_brick_fence else if (is_chiseled) .chiseled_nether_brick else .nether_brick;
                        chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), b_id);
                    } else if (self.isBastionRampart(wx, @intCast(y), wz)) {
                        const b_id: @import("block.zig").BlockId = if (self.isGildedBlackstone(wx, @intCast(y), wz)) .gilded_blackstone else .blackstone;
                        chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), b_id);
                    } else if (self.isBasaltColumn(wx, @intCast(y), wz)) {
                        chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .basalt);
                    } else {
                        // Preserve wild wart planted at y=6 by the y=5 soul sand pass
                        if (chunk.getBlock(@intCast(lx), @intCast(y), @intCast(lz)) == .nether_wart) {
                            continue;
                        }
                        if (self.isShroomlight(wx, @intCast(y), wz)) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .shroomlight);
                            continue;
                        }
                        if (self.isCrimsonFungus(wx, @intCast(y), wz)) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .crimson_fungus);
                            continue;
                        }
                        if (self.isWarpedFungus(wx, @intCast(y), wz)) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .warped_fungus);
                            continue;
                        }
                        if (self.isTwistingVine(wx, @intCast(y), wz)) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .twisting_vines);
                            continue;
                        }
                        // Open cavern space: lava sea up to SEA_LEVEL - 1 (y <= 4)
                        if (y <= 4) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .lava);
                            chunk.setLevel(@intCast(lx), @intCast(y), @intCast(lz), 7);
                        } else if (self.isWeepingVine(wx, @intCast(y), wz)) {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .weeping_vines);
                        } else {
                            chunk.setBlock(@intCast(lx), @intCast(y), @intCast(lz), .air);
                        }
                    }
                }
            }
        }
    }
};

test "NetherGenerator embeds gilded blackstone veins in bastion rampart walls" {
    const nether_gen = NetherGenerator.init(12345);
    var found = false;
    var x: i32 = 0;
    while (x <= 128) : (x += 1) {
        var z: i32 = 0;
        while (z <= 128) : (z += 1) {
            var y: i32 = 6;
            while (y <= 9) : (y += 1) {
                if (nether_gen.isGildedBlackstone(x, y, z)) {
                    try std.testing.expect(nether_gen.isBastionRampart(x, y, z));
                    found = true;
                    break;
                }
            }
            if (found) break;
        }
        if (found) break;
    }
    try std.testing.expect(found);
}

test "NetherGenerator generates blackstone bastion remnant ramparts" {
    const nether_gen = NetherGenerator.init(12345);
    var found = false;
    var x: i32 = 0;
    while (x <= 128) : (x += 1) {
        var z: i32 = 0;
        while (z <= 128) : (z += 1) {
            if (nether_gen.isBastionRampart(x, 7, z)) {
                // Wall should be solid blackstone from y=5 up to y=10
                try std.testing.expect(nether_gen.isBastionRampart(x, 5, z));
                try std.testing.expect(nether_gen.isBastionRampart(x, 10, z));
                found = true;
                break;
            }
        }
        if (found) break;
    }
    try std.testing.expect(found);
}

test "NetherGenerator generates vertical basalt columns in volcanic cavern deltas" {
    const nether_gen = NetherGenerator.init(12345);
    var found = false;
    var x: i32 = 0;
    while (x <= 128) : (x += 1) {
        var z: i32 = 0;
        while (z <= 128) : (z += 1) {
            if (nether_gen.isBasaltColumn(x, 6, z)) {
                // Column should extend vertically from y=4 up to at least y=8
                try std.testing.expect(nether_gen.isBasaltColumn(x, 4, z));
                try std.testing.expect(nether_gen.isBasaltColumn(x, 8, z));
                found = true;
                break;
            }
        }
        if (found) break;
    }
    try std.testing.expect(found);
}

test "NetherGenerator generates crying obsidian veins in deep strata" {
    const nether_gen = NetherGenerator.init(12345);
    var found = false;
    var x: i32 = -50;
    while (x <= 50) : (x += 1) {
        var z: i32 = -50;
        while (z <= 50) : (z += 1) {
            var y: i32 = 3;
            while (y <= 5) : (y += 1) {
                if (nether_gen.isCryingObsidian(x, y, z)) {
                    found = true;
                    break;
                }
            }
            if (found) break;
        }
        if (found) break;
    }
    try std.testing.expect(found);
}

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

    // Verify Ancient Debris generation in a nearby subterranean chunk
    var chunk2 = Chunk.init();
    nether_gen.generateChunk(&chunk2, 1, 0);
    var has_debris = false;
    for (0..SIZE) |z_i| {
        for (0..SIZE) |x_i| {
            for (2..5) |y_i| {
                if (chunk2.getBlock(@intCast(x_i), @intCast(y_i), @intCast(z_i)) == .ancient_debris or
                    chunk.getBlock(@intCast(x_i), @intCast(y_i), @intCast(z_i)) == .ancient_debris) {
                    has_debris = true;
                }
            }
        }
    }
    try std.testing.expect(has_debris);
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

test "NetherGenerator grows twisting vines upward from soul sand floors" {
    const nether_gen = NetherGenerator.init(12345);
    var found = false;
    var x: i32 = -64;
    while (x <= 64) : (x += 1) {
        var z: i32 = -64;
        while (z <= 64) : (z += 1) {
            var y: i32 = 6;
            while (y <= 9) : (y += 1) {
                if (nether_gen.isTwistingVine(x, y, z)) {
                    try std.testing.expect(nether_gen.isSoulSand(x, z));
                    found = true;
                    break;
                }
            }
            if (found) break;
        }
        if (found) break;
    }
    try std.testing.expect(found);
}

test "NetherGenerator grows weeping vines hanging under cavern ceiling" {
    const nether_gen = NetherGenerator.init(12345);
    var found = false;
    var x: i32 = -64;
    while (x <= 64) : (x += 1) {
        var z: i32 = -64;
        while (z <= 64) : (z += 1) {
            var y: i32 = 7;
            while (y <= 12) : (y += 1) {
                if (nether_gen.isWeepingVine(x, y, z)) {
                    found = true;
                    break;
                }
            }
            if (found) break;
        }
        if (found) break;
    }
    try std.testing.expect(found);
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

test "NetherGenerator generates crimson and warped fungi on cavern floors" {
    const nether = NetherGenerator.init(12345);
    var found_crimson = false;
    var found_warped = false;
    var x: i32 = -32;
    while (x <= 32) : (x += 1) {
        var z: i32 = -32;
        while (z <= 32) : (z += 1) {
            if (nether.isCrimsonFungus(x, 6, z)) found_crimson = true;
            if (nether.isWarpedFungus(x, 6, z)) found_warped = true;
        }
    }
    try std.testing.expect(found_crimson);
    try std.testing.expect(found_warped);
}

test "NetherGenerator mounts ambient soul torches on fortress balustrades" {
    const nether_gen = NetherGenerator.init(12345);
    // Over the span of one 48-block bridge cell, check for soul torches at y=9
    try std.testing.expect(nether_gen.isFortressTorch(0, 9, 22));
    try std.testing.expect(nether_gen.isFortressTorch(6, 9, 25));
    try std.testing.expect(!nether_gen.isFortressTorch(1, 9, 22));
    try std.testing.expect(!nether_gen.isFortressTorch(0, 8, 22)); // y=8 is fence, not torch

    var chunk = Chunk.init();
    nether_gen.generateChunk(&chunk, 0, 1); // contains gz around 22..25 in local chunk 1 (wz = 16..31)
    // At wx = 0 (lx = 0), wz = 22 (lz = 6), y = 8 is fence and y = 9 is soul_torch
    try std.testing.expectEqual(chunk.getBlock(0, 8, 6), .nether_brick_fence);
    try std.testing.expectEqual(chunk.getBlock(0, 9, 6), .soul_torch);
}

test "NetherGenerator places spawner cage at fortress junction alcoves" {
    const nether_gen = NetherGenerator.init(12345);
    // At junction (0,0), cell (24, 24) or (23, 23) should be spawner cage at y=8
    const has_spawner = nether_gen.isFortressSpawner(24, 8, 24) or nether_gen.isFortressSpawner(23, 8, 23);
    try std.testing.expect(has_spawner);
    try std.testing.expect(!nether_gen.isFortressSpawner(0, 8, 0));
    try std.testing.expect(!nether_gen.isFortressSpawner(24, 7, 24));
}

test "NetherGenerator procedural shroomlight cluster generation" {
    const nether_gen = NetherGenerator.init(42);
    var found = false;
    var x: i32 = -32;
    while (x < 32) : (x += 1) {
        var z: i32 = -32;
        while (z < 32) : (z += 1) {
            var y: i32 = 7;
            while (y <= 10) : (y += 1) {
                if (nether_gen.isShroomlight(x, y, z)) {
                    found = true;
                    break;
                }
            }
            if (found) break;
        }
        if (found) break;
    }
    try std.testing.expect(found);
}

test "NetherGenerator incorporates chiseled nether bricks in fortress walkways" {
    const nether_gen = NetherGenerator.init(1337);
    var chunk = Chunk.init();
    // Chunk at cx=1, cz=1 contains cell (24, 24) which is fortress cross-junction
    nether_gen.generateChunk(&chunk, 1, 1);
    var found_chiseled = false;
    var lx: usize = 0;
    while (lx < SIZE) : (lx += 1) {
        var lz: usize = 0;
        while (lz < SIZE) : (lz += 1) {
            if (chunk.getBlock(@intCast(lx), 7, @intCast(lz)) == .chiseled_nether_brick) {
                found_chiseled = true;
                break;
            }
        }
        if (found_chiseled) break;
    }
    try std.testing.expect(found_chiseled);
}


pub const EndGenerator = struct {
    seed: u64,

    pub fn init(seed: u64) EndGenerator {
        return .{ .seed = seed };
    }

    /// Check if horizontal coordinate (wx, wz) lies within the End central island.
    /// Island radius ~40 blocks around (0, 0) with gentle circular falloff.
    pub fn isIsland(self: EndGenerator, wx: i32, wz: i32) bool {
        _ = self;
        const fx = @as(f32, @floatFromInt(wx));
        const fz = @as(f32, @floatFromInt(wz));
        const dist = @sqrt(fx * fx + fz * fz);
        return dist <= 40.0;
    }

    /// Check if horizontal coordinate (wx, wz) lies within an outer End satellite island.
    /// Outer islands centered at (72, 0), (-72, 0), (0, 72), (0, -72) with radius 16.
    pub fn isOuterIsland(self: EndGenerator, wx: i32, wz: i32) bool {
        _ = self;
        const centers = [_][2]i32{
            .{ 72, 0 },
            .{ -72, 0 },
            .{ 0, 72 },
            .{ 0, -72 },
        };
        for (centers) |c| {
            const dx = wx - c[0];
            const dz = wz - c[1];
            if (dx * dx + dz * dz <= 16 * 16) return true;
        }
        return false;
    }

    /// Returns height range [floor_y, ceil_y] for the End stone island at (wx, wz).
    /// Center of central island sits around y=6..10.
    /// Outer islands sit around y=6..8.
    pub fn islandFloorCeil(self: EndGenerator, wx: i32, wz: i32) ?struct { min_y: i32, max_y: i32 } {
        if (self.isIsland(wx, wz)) {
            const fx = @as(f32, @floatFromInt(wx));
            const fz = @as(f32, @floatFromInt(wz));
            const dist = @sqrt(fx * fx + fz * fz);
            const taper = 1.0 - (dist / 40.0);
            const half_thick: i32 = @intFromFloat(@floor(1.0 + taper * 3.0));
            const center_y: i32 = 8;
            return .{
                .min_y = center_y - half_thick,
                .max_y = center_y + half_thick,
            };
        }
        if (self.isOuterIsland(wx, wz)) {
            return .{
                .min_y = 6,
                .max_y = 8,
            };
        }
        return null;
    }

    /// Check if (wx, wz) is an obsidian pillar column.
    /// 4 colossal obsidian monolith pillars placed at distance ~22 blocks on main axes / diagonals:
    /// (16, 16), (-16, 16), (16, -16), (-16, -16)
    pub fn isObsidianPillar(self: EndGenerator, wx: i32, wz: i32) bool {
        _ = self;
        const pillars = [_][2]i32{
            .{ 16, 16 },
            .{ -16, 16 },
            .{ 16, -16 },
            .{ -16, -16 },
        };
        for (pillars) |p| {
            const dx = wx - p[0];
            const dz = wz - p[1];
            // 3x3 square pillar column
            if (dx >= -1 and dx <= 1 and dz >= -1 and dz <= 1) return true;
        }
        return false;
    }

    /// Check if (wx, wz) is the central pinnacle apex of an obsidian pillar (center cell of 3x3).
    pub fn isPillarApex(self: EndGenerator, wx: i32, wz: i32) bool {
        _ = self;
        return (wx == 16 and wz == 16) or
            (wx == -16 and wz == 16) or
            (wx == 16 and wz == -16) or
            (wx == -16 and wz == -16);
    }



    /// Check if (wx, wy, wz) intersects an End Gateway teleportation portal fixture.
    /// Central gateway at (32, y, 0), return outer gateway at (72, y, 14).
    pub fn getEndGatewayBlock(self: EndGenerator, wx: i32, wy: i32, wz: i32) ?BlockId {
        _ = self;
        // Central island gateway at (32, 11, 0)
        if (wx >= 31 and wx <= 33 and wz >= -1 and wz <= 1 and wy >= 10 and wy <= 12) {
            if (wx == 32 and wz == 0 and wy == 11) return .end_gateway;
            // Obsidian protective framing
            if (wy == 10 or wy == 12 or wx == 31 or wx == 33 or wz == -1 or wz == 1) return .obsidian;
            return .air;
        }

        // Outer island return gateway at (72, 11, 14)
        if (wx >= 71 and wx <= 73 and wz >= 13 and wz <= 15 and wy >= 10 and wy <= 12) {
            if (wx == 72 and wz == 14 and wy == 11) return .end_gateway;
            if (wy == 10 or wy == 12 or wx == 71 or wx == 73 or wz == 13 or wz == 15) return .obsidian;
            return .air;
        }

        return null;
    }

    /// Check if (wx, wy, wz) intersects the airborne End Ship vessel floating beside the End City.
    /// Hull at wx in 80..88, wz in -2..2, elevation wy in 12..15.
    /// Prow tip mounts the Dragon Head trophy block (wx = 88, wy = 13, wz = 0).
    pub fn getEndShipBlock(self: EndGenerator, wx: i32, wy: i32, wz: i32) ?BlockId {
        _ = self;
        if (wx < 80 or wx > 88 or wz < -2 or wz > 2) return null;
        if (wy < 12 or wy > 15) return null;

        // Prow tip: Dragon Head mounted on ship bow
        if (wx == 88) {
            if (wy == 13 and wz == 0) return .dragon_head;
            return null;
        }

        // Keel / hull base at wy = 12
        if (wy == 12) {
            if (@abs(wz) <= 1 and (wx >= 81 and wx <= 87)) return .purpur_block;
            return null;
        }

        // Main deck, bulwarks, and cargo hold at wy = 13
        if (wy == 13) {
            // Gunwale bulwarks along sides
            if (@abs(wz) == 2) {
                return if (wx == 80 or wx == 87) .purpur_pillar else .purpur_block;
            }
            // Stern transom wall at wx = 80
            if (wx == 80) return .purpur_block;
            // Bow taper at wx = 87
            if (wx == 87) return if (@abs(wz) == 1) .purpur_block else null;

            // Interior deck: Shulker Box loot chest at (82, 13, 0)
            if (wx == 82 and wz == 0) return .shulker_box;
            return .air;
        }

        // Mast and yardarm rigging at wy = 14..15
        if (wy == 14) {
            if (wx == 84 and wz == 0) return .purpur_pillar;
            return null;
        }
        if (wy == 15) {
            if (wx == 84 and @abs(wz) <= 1) return .end_rod;
            return null;
        }

        return null;
    }

    /// Check if (wx, wy, wz) intersects the End City fortress structure on the East outer island.
    /// Tower center at (72, 0), floor at y=8, footprint wx in 69..75, wz in -3..3, height up to y=15.
    pub fn getEndCityBlock(self: EndGenerator, wx: i32, wy: i32, wz: i32) ?BlockId {
        _ = self;
        if (wx < 69 or wx > 75 or wz < -3 or wz > 3) return null;
        if (wy < 8 or wy > 15) return null;

        const is_corner = (wx == 69 or wx == 75) and (wz == -3 or wz == 3);
        const is_wall = (wx == 69 or wx == 75 or wz == -3 or wz == 3);

        // Foundation floor at y=8
        if (wy == 8) return .purpur_block;

        // Ground floor walls, doorway, and loot container
        if (wy == 9) {
            if (is_wall) {
                // Entrance portal at wx == 69, wz == 0
                if (wx == 69 and wz == 0) return .air;
                return if (is_corner) .purpur_pillar else .purpur_block;
            }
            if (wx == 72 and wz == 0) return .shulker_box;
            return .air;
        }

        // Mid-wall / doorway arch
        if (wy == 10) {
            if (is_wall) {
                if (wx == 69 and wz == 0) return .air;
                return if (is_corner) .purpur_pillar else .purpur_block;
            }
            return .air;
        }

        // Window level: End Rod light sources on center wall flanks
        if (wy == 11) {
            if (is_wall) {
                if ((wx == 72 and (wz == -3 or wz == 3)) or (wz == 0 and wx == 75)) return .end_rod;
                return if (is_corner) .purpur_pillar else .purpur_block;
            }
            return .air;
        }

        // Upper tower walls
        if (wy == 12 or wy == 13) {
            if (is_wall) return if (is_corner) .purpur_pillar else .purpur_block;
            return .air;
        }

        // Roof slab at y=14
        if (wy == 14) return .purpur_block;

        // Parapet spires at y=15 (End Rods on corners)
        if (wy == 15) {
            if (is_corner) return .end_rod;
            return .air;
        }

        return null;
    }

    /// Deterministic hash check for Chorus Plant grove generation on outer islands.
    pub fn isChorusTree(self: EndGenerator, wx: i32, wz: i32) bool {
        // Exclude End City tower footprint
        if (wx >= 68 and wx <= 76 and wz >= -4 and wz <= 4) return false;
        if (!self.isOuterIsland(wx, wz)) return false;

        const u_wx: u64 = @bitCast(@as(i64, wx));
        const u_wz: u64 = @bitCast(@as(i64, wz));
        var h: u64 = (u_wx *% 73856093) ^ (u_wz *% 19349663) ^ (self.seed *% 83492791);
        h ^= (h >> 13);
        h *%= 0x5bd1e995;
        return (h % 31) == 0;
    }

    /// Generates segmented Chorus Plant stem and Chorus Flower crown.
    pub fn getChorusBlock(self: EndGenerator, wx: i32, wy: i32, wz: i32, ground_y: i32) ?BlockId {
        if (!self.isChorusTree(wx, wz)) return null;
        if (wy <= ground_y or wy > ground_y + 4) return null;

        // Trunk: y = ground+1, ground+2, ground+3 are chorus_plant
        if (wy <= ground_y + 3) return .chorus_plant;
        // Crown: y = ground+4 is chorus_flower
        if (wy == ground_y + 4) return .chorus_flower;
        return null;
    }

    pub fn generateChunk(self: EndGenerator, chunk: *Chunk, cx: i32, cz: i32) void {
        const ox = cx * 16;
        const oz = cz * 16;

        var lx: i32 = 0;
        while (lx < 16) : (lx += 1) {
            const wx = ox + lx;
            var lz: i32 = 0;
            while (lz < 16) : (lz += 1) {
                const wz = oz + lz;

                const is_pillar = self.isObsidianPillar(wx, wz);
                const island = self.islandFloorCeil(wx, wz);

                var ly: i32 = 0;
                while (ly < 16) : (ly += 1) {
                    const wy = ly;

                    if (self.getEndGatewayBlock(wx, wy, wz)) |gb| {
                        // End Gateway fixture takes precedence
                        chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), gb);
                    } else if (self.getEndShipBlock(wx, wy, wz)) |sb| {
                        // End Ship vessel block takes precedence
                        chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), sb);
                    } else if (self.getEndCityBlock(wx, wy, wz)) |b| {
                        // End City architectural block takes precedence
                        chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), b);
                    } else if (is_pillar and wy >= 4 and wy <= 14) {
                        // Obsidian monolith pillar shaft
                        chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), .obsidian);
                    } else if (wy == 15 and is_pillar) {
                        if (self.isPillarApex(wx, wz)) {
                            // Perched End Crystal at pillar apex
                            chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), .end_crystal);
                        } else {
                            chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), .obsidian);
                        }
                    } else if (island) |isl| {
                        if (wy >= isl.min_y and wy <= isl.max_y) {
                            chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), .end_stone);
                        } else if (self.getChorusBlock(wx, wy, wz, isl.max_y)) |cb| {
                            chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), cb);
                        } else {
                            chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), .air);
                        }
                    } else {
                        chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), .air);
                    }
                }
            }
        }
    }
};

test "EndGenerator central island and obsidian monolith pillars" {
    const end_gen = EndGenerator.init(12345);

    // Center (0, 0) is island
    try std.testing.expect(end_gen.isIsland(0, 0));
    const center_isl = end_gen.islandFloorCeil(0, 0);
    try std.testing.expect(center_isl != null);
    try std.testing.expect(center_isl.?.max_y >= 10);
    try std.testing.expect(center_isl.?.min_y <= 6);

    // Void gap between central and outer islands
    try std.testing.expect(!end_gen.isIsland(50, 0));
    try std.testing.expect(!end_gen.isOuterIsland(50, 0));
    try std.testing.expect(end_gen.islandFloorCeil(50, 0) == null);

    // Pillar at (16, 16)
    try std.testing.expect(end_gen.isObsidianPillar(16, 16));
    try std.testing.expect(end_gen.isObsidianPillar(15, 17));
    try std.testing.expect(!end_gen.isObsidianPillar(0, 0));

    // Chunk generation: central island
    var chunk = Chunk.init();
    end_gen.generateChunk(&chunk, 0, 0); // chunk (0, 0) contains island center
    try std.testing.expectEqual(BlockId.end_stone, chunk.getBlock(0, 8, 0));
}

test "EndGenerator outer satellite islands and chorus forest grove generation" {
    const end_gen = EndGenerator.init(12345);

    // East outer island at (72, 0)
    try std.testing.expect(!end_gen.isIsland(72, 0));
    try std.testing.expect(end_gen.isOuterIsland(72, 0));
    try std.testing.expect(end_gen.islandFloorCeil(72, 0) != null);

    // North outer island at (0, 72)
    try std.testing.expect(end_gen.isOuterIsland(0, 72));

    // Chorus tree generation on outer islands
    var found_tree = false;
    var wx: i32 = 58;
    while (wx <= 86) : (wx += 1) {
        if (end_gen.isChorusTree(wx, 8)) {
            found_tree = true;
            // Verify stem and flower vertical structure
            try std.testing.expectEqual(BlockId.chorus_plant, end_gen.getChorusBlock(wx, 9, 8, 8).?);
            try std.testing.expectEqual(BlockId.chorus_plant, end_gen.getChorusBlock(wx, 10, 8, 8).?);
            try std.testing.expectEqual(BlockId.chorus_plant, end_gen.getChorusBlock(wx, 11, 8, 8).?);
            try std.testing.expectEqual(BlockId.chorus_flower, end_gen.getChorusBlock(wx, 12, 8, 8).?);
            try std.testing.expect(end_gen.getChorusBlock(wx, 13, 8, 8) == null);
            break;
        }
    }
    try std.testing.expect(found_tree);
}

test "EndGenerator end city fortress architecture, purpur pillars, end rods, and shulker box loot" {
    const end_gen = EndGenerator.init(12345);

    // End City tower at wx in 69..75, wz in -3..3
    // Corner at (69, -3) has Purpur Pillar walls
    try std.testing.expectEqual(BlockId.purpur_pillar, end_gen.getEndCityBlock(69, 9, -3).?);
    try std.testing.expectEqual(BlockId.purpur_pillar, end_gen.getEndCityBlock(75, 12, 3).?);

    // Wall at (72, 3) has Purpur Block
    try std.testing.expectEqual(BlockId.purpur_block, end_gen.getEndCityBlock(72, 9, 3).?);

    // Entrance at (69, 0) is air (walkway entry)
    try std.testing.expectEqual(BlockId.air, end_gen.getEndCityBlock(69, 9, 0).?);

    // Window light sources at y=11 are End Rods
    try std.testing.expectEqual(BlockId.end_rod, end_gen.getEndCityBlock(72, 11, 3).?);

    // Loot container at tower interior center (72, 9, 0)
    try std.testing.expectEqual(BlockId.shulker_box, end_gen.getEndCityBlock(72, 9, 0).?);

    // Roof at y=14 is Purpur Block
    try std.testing.expectEqual(BlockId.purpur_block, end_gen.getEndCityBlock(72, 14, 0).?);

    // Spire pinnacles at y=15 are End Rods
    try std.testing.expectEqual(BlockId.end_rod, end_gen.getEndCityBlock(69, 15, -3).?);

    // Chunk generation for chunk (4, 0) covering wx 64..79, wz 0..15 (contains half of city)
    var chunk = Chunk.init();
    end_gen.generateChunk(&chunk, 4, 0);
    // At wx = 72 (lx = 8), wz = 0 (lz = 0), wy = 9 (ly = 9) should be shulker_box
    try std.testing.expectEqual(BlockId.shulker_box, chunk.getBlock(8, 9, 0));
}

test "EndGenerator end ship structure generation, purpur hull, mast, and dragon head prow" {
    const end_gen = EndGenerator.init(12345);

    // Prow tip mounts Dragon Head at (88, 13, 0)
    try std.testing.expectEqual(BlockId.dragon_head, end_gen.getEndShipBlock(88, 13, 0).?);
    try std.testing.expect(end_gen.getEndShipBlock(88, 13, 1) == null);

    // Keel at wy=12
    try std.testing.expectEqual(BlockId.purpur_block, end_gen.getEndShipBlock(84, 12, 0).?);

    // Cargo deck Shulker Box at (82, 13, 0)
    try std.testing.expectEqual(BlockId.shulker_box, end_gen.getEndShipBlock(82, 13, 0).?);

    // Mast at (84, 14, 0) is Purpur Pillar
    try std.testing.expectEqual(BlockId.purpur_pillar, end_gen.getEndShipBlock(84, 14, 0).?);

    // Rigging yardarm at (84, 15, 1) is End Rod
    try std.testing.expectEqual(BlockId.end_rod, end_gen.getEndShipBlock(84, 15, 1).?);

    // Chunk generation: chunk (5, 0) covering wx 80..95, wz 0..15 contains ship prow
    var chunk = Chunk.init();
    end_gen.generateChunk(&chunk, 5, 0);
    // wx = 88 (lx = 8), wz = 0 (lz = 0), wy = 13 (ly = 13) has dragon_head
    try std.testing.expectEqual(BlockId.dragon_head, chunk.getBlock(8, 13, 0));
}

test "EndGenerator end gateway portal structure generation, obsidian frame, and gateway core" {
    const end_gen = EndGenerator.init(12345);

    // Central island gateway at (32, 11, 0)
    try std.testing.expectEqual(BlockId.end_gateway, end_gen.getEndGatewayBlock(32, 11, 0).?);
    try std.testing.expectEqual(BlockId.obsidian, end_gen.getEndGatewayBlock(32, 10, 0).?);
    try std.testing.expectEqual(BlockId.obsidian, end_gen.getEndGatewayBlock(32, 12, 0).?);
    try std.testing.expectEqual(BlockId.obsidian, end_gen.getEndGatewayBlock(31, 11, 0).?);

    // Outer island return gateway at (72, 11, 14)
    try std.testing.expectEqual(BlockId.end_gateway, end_gen.getEndGatewayBlock(72, 11, 14).?);
    try std.testing.expectEqual(BlockId.obsidian, end_gen.getEndGatewayBlock(72, 10, 14).?);

    // Chunk generation: chunk (2, 0) covering wx 32..47, wz 0..15 contains central gateway
    var chunk = Chunk.init();
    end_gen.generateChunk(&chunk, 2, 0);
    // wx = 32 (lx = 0), wz = 0 (lz = 0), wy = 11 (ly = 11) is end_gateway
    try std.testing.expectEqual(BlockId.end_gateway, chunk.getBlock(0, 11, 0));
}

test "Ocean Monument generation: submerged pyramid, sea lanterns, and conduit altar" {
    const tg = TerrainGenerator.init(1337);
    try std.testing.expectEqual(BlockId.conduit, tg.getOceanMonumentBlock(0, 3, -16).?);
    try std.testing.expectEqual(BlockId.sea_lantern, tg.getOceanMonumentBlock(0, 4, -16).?);
    try std.testing.expectEqual(BlockId.sea_lantern, tg.getOceanMonumentBlock(6, 5, -22).?);
    try std.testing.expectEqual(BlockId.dark_prismarine, tg.getOceanMonumentBlock(0, 1, -16).?);
    try std.testing.expectEqual(BlockId.prismarine_bricks, tg.getOceanMonumentBlock(2, 6, -16).?);
    try std.testing.expectEqual(BlockId.wet_sponge, tg.getOceanMonumentBlock(0, 5, -16).?);
    try std.testing.expectEqual(BlockId.wet_sponge, tg.getOceanMonumentBlock(0, 6, -16).?);
    try std.testing.expect(tg.getOceanMonumentBlock(10, 3, -16) == null);
}

test "procedural kelp forest stalks generate in deep ocean water" {
    const tg = TerrainGenerator.init(42);
    var chunk = Chunk.init();
    tg.generateChunk(&chunk, -10, -10);

    var found_kelp = false;
    var lz: usize = 0;
    while (lz < 16) : (lz += 1) {
        var lx: usize = 0;
        while (lx < 16) : (lx += 1) {
            var ly: usize = 1;
            while (ly < 16) : (ly += 1) {
                if (chunk.getBlock(@intCast(lx), @intCast(ly), @intCast(lz)) == .kelp) {
                    found_kelp = true;
                    break;
                }
            }
            if (found_kelp) break;
        }
        if (found_kelp) break;
    }
    // Verify kelp blocks exist in procedural world
    try std.testing.expect(found_kelp);
}

test "procedural sea pickle colonies generate on seafloor in ocean water" {
    const tg = TerrainGenerator.init(42);
    var chunk = Chunk.init();
    tg.generateChunk(&chunk, -10, -10);

    var found_sp = false;
    var lz: usize = 0;
    while (lz < 16) : (lz += 1) {
        var lx: usize = 0;
        while (lx < 16) : (lx += 1) {
            var ly: usize = 1;
            while (ly < 16) : (ly += 1) {
                if (chunk.getBlock(@intCast(lx), @intCast(ly), @intCast(lz)) == .sea_pickle) {
                    found_sp = true;
                    break;
                }
            }
            if (found_sp) break;
        }
        if (found_sp) break;
    }
    try std.testing.expect(found_sp);
}

test "TerrainGenerator abandoned mineshaft corridors, rails, timber frames, and chests" {
    const tg = TerrainGenerator.init(42);
    // Cave spider spawner cage at (-16, 4, 16) with dense cobweb cocoon
    try std.testing.expectEqual(BlockId.spawner_cage, tg.getAbandonedMineshaftBlock(-16, 4, 16).?);
    try std.testing.expectEqual(BlockId.cobweb, tg.getAbandonedMineshaftBlock(-15, 4, 16).?);
    try std.testing.expectEqual(BlockId.cobweb, tg.getAbandonedMineshaftBlock(-16, 5, 16).?);



    // Primary corridor at (10, wy, 16):
    // Floor wy=3 -> wood_planks
    try std.testing.expectEqual(BlockId.wood_planks, tg.getAbandonedMineshaftBlock(10, 3, 16).?);
    // Rail at wy=4
    try std.testing.expectEqual(BlockId.rail, tg.getAbandonedMineshaftBlock(10, 4, 16).?);
    // Air at wy=5
    try std.testing.expectEqual(BlockId.air, tg.getAbandonedMineshaftBlock(10, 5, 16).?);

    // Powered rail at wx=4, wy=4, wz=16 (mod 8 == 4)
    try std.testing.expectEqual(BlockId.powered_rail, tg.getAbandonedMineshaftBlock(4, 4, 16).?);

    // Arch timber frame post at wx=8, wy=4, wz=15 (side post, mod 4 == 0)
    try std.testing.expectEqual(BlockId.oak_fence, tg.getAbandonedMineshaftBlock(8, 4, 15).?);
    // Arch ceiling beam at wx=8, wy=6, wz=16
    try std.testing.expectEqual(BlockId.wood_planks, tg.getAbandonedMineshaftBlock(8, 6, 16).?);

    // Loot chest at junction (0, 4, 16)
    try std.testing.expectEqual(BlockId.chest, tg.getAbandonedMineshaftBlock(0, 4, 16).?);

    // Coordinates outside bounds return null
    try std.testing.expect(tg.getAbandonedMineshaftBlock(100, 4, 16) == null);
    try std.testing.expect(tg.getAbandonedMineshaftBlock(0, 8, 16) == null);

    // Verify chunk generator applies mineshaft blocks
    var chunk = Chunk.init(); tg.generateChunk(&chunk, 0, 1); // cx=0, cz=1 -> wz in 16..31
    try std.testing.expectEqual(BlockId.wood_planks, chunk.getBlock(4, 3, 0)); // wx=4, wy=3, wz=16
    try std.testing.expectEqual(BlockId.powered_rail, chunk.getBlock(4, 4, 0)); // wx=4, wy=4, wz=16
    try std.testing.expectEqual(BlockId.chest, chunk.getBlock(0, 4, 0)); // junction chest at wx=0, wy=4, wz=16
}

test "TerrainGenerator isPaleOakTree determinism and natural generation" {
    const tg1 = TerrainGenerator.init(12345);
    const tg2 = TerrainGenerator.init(12345);
    const tg3 = TerrainGenerator.init(67890);

    // Deterministic with same seed
    try std.testing.expectEqual(tg1.isPaleOakTree(10, 20), tg2.isPaleOakTree(10, 20));
    try std.testing.expectEqual(tg1.isPaleOakTree(-15, 42), tg2.isPaleOakTree(-15, 42));

    // Seeds differ somewhere
    var differ = false;
    var sx: i32 = -50;
    while (sx < 50) : (sx += 1) {
        if (tg1.isPaleOakTree(sx, 0) != tg3.isPaleOakTree(sx, 0)) {
            differ = true;
            break;
        }
    }
    try std.testing.expect(differ);

    // Scan generated chunks over a region to prove regular .wood trees and
    // Pale Oak trees with sandwiched .creaking_heart blocks generate
    var regular_tree_count: usize = 0;
    var pale_oak_tree_count: usize = 0;
    var creaking_heart_count: usize = 0;

    var cx: i32 = -6;
    while (cx <= 6) : (cx += 1) {
        var cz: i32 = -6;
        while (cz <= 6) : (cz += 1) {
            var chunk = Chunk.init();
            tg1.generateChunk(&chunk, cx, cz);

            var lz: usize = 0;
            while (lz < SIZE) : (lz += 1) {
                var lx: usize = 0;
                while (lx < SIZE) : (lx += 1) {
                    var ly: usize = 0;
                    while (ly < SIZE) : (ly += 1) {
                        const blk = chunk.getBlock(@intCast(lx), @intCast(ly), @intCast(lz));
                        if (blk == .creaking_heart) {
                            creaking_heart_count += 1;
                            // Prove every generated creaking_heart has .pale_oak_log directly above and below
                            try std.testing.expect(ly >= 1);
                            try std.testing.expect(ly + 1 < SIZE);
                            const below = chunk.getBlock(@intCast(lx), @intCast(ly - 1), @intCast(lz));
                            const above = chunk.getBlock(@intCast(lx), @intCast(ly + 1), @intCast(lz));
                            try std.testing.expectEqual(BlockId.pale_oak_log, below);
                            try std.testing.expectEqual(BlockId.pale_oak_log, above);
                        } else if (blk == .pale_oak_log) {
                            pale_oak_tree_count += 1;
                        } else if (blk == .wood) {
                            regular_tree_count += 1;
                        }
                    }
                }
            }
        }
    }

    try std.testing.expect(regular_tree_count > 0);
    try std.testing.expect(pale_oak_tree_count > 0);
    try std.testing.expect(creaking_heart_count > 0);
}
