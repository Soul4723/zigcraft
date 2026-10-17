const std = @import("std");

// ============================================================================
// Constants & Tags
// ============================================================================

pub const OchreFroglightTag: u16 = 386;
pub const VerdantFroglightTag: u16 = 387;
pub const PearlescentFroglightTag: u16 = 388;
pub const SlimeballTag: u16 = 206;
pub const MagmaCreamTag: u16 = 62;

pub const slime_chunk_max_y: i32 = 39; // Below Y = 40 (i.e. Y <= 39)
pub const swamp_min_y: i32 = 51;
pub const swamp_max_y: i32 = 69;
pub const swamp_max_light_level: u4 = 7;

pub const slime_base_jump_velocity: f32 = 5.5;
pub const magma_cube_jump_multiplier: f32 = 1.5;

// ============================================================================
// Enums & Types
// ============================================================================

/// Three canonical sizes for Slimes and Magma Cubes.
pub const SlimeSize = enum(u8) {
    small = 1,
    medium = 2,
    large = 4,

    /// Health is size * size: 1.0 (small), 4.0 (medium), 16.0 (large).
    pub fn health(self: SlimeSize) f32 {
        const size: f32 = @floatFromInt(@intFromEnum(self));
        return size * size;
    }

    pub fn slimeHealth(self: SlimeSize) f32 {
        return self.health();
    }

    pub fn magmaCubeHealth(self: SlimeSize) f32 {
        return self.health();
    }

    /// Slime melee attack damage: Small slimes deal 0 damage (only pushing players).
    pub fn slimeMeleeDamage(self: SlimeSize) f32 {
        return switch (self) {
            .small => 0.0,
            .medium => 2.0,
            .large => 4.0,
        };
    }

    /// Magma Cube melee attack damage: Small cubes deal 3.0 damage!
    pub fn magmaCubeMeleeDamage(self: SlimeSize) f32 {
        return switch (self) {
            .small => 3.0,
            .medium => 4.0,
            .large => 6.0,
        };
    }

    /// Slimes have no innate armor.
    pub fn slimeArmor(self: SlimeSize) u8 {
        _ = self;
        return 0;
    }

    /// Magma Cubes have innate armor points equal to 3 * size:
    /// small = 3, medium = 6, large = 12.
    pub fn magmaCubeArmor(self: SlimeSize) u8 {
        return 3 * @intFromEnum(self);
    }

    /// Magma Cubes have 1.5x higher jump velocity than Slimes.
    pub fn magmaCubeJumpVelocity(slime_jump_velocity: f32) f32 {
        return slime_jump_velocity * magma_cube_jump_multiplier;
    }

    /// Scale factor for model dimensions and bounding boxes.
    pub fn dimensions(self: SlimeSize) struct { width: f32, height: f32 } {
        const factor: f32 = @floatFromInt(@intFromEnum(self));
        return .{
            .width = 0.51 * factor,
            .height = 0.51 * factor,
        };
    }
};

/// Result of a Slime or Magma Cube death split.
pub const MitosisResult = struct {
    child_size: ?SlimeSize,
    child_count: u8,
    drops_slimeball_or_cream: bool,
};

/// When a Large (4) or Medium (2) Slime or Magma Cube dies, it splits into
/// 2..4 children of the next smaller size (large -> medium, medium -> small).
/// Only Small (1) Slimes drop Slimeballs (and Small Magma Cubes drop Magma Cream
/// or froglights when consumed by a Frog).
pub fn resolveMitosisSplitOnDeath(size: SlimeSize, split_roll_2_to_4: u8) MitosisResult {
    const clamped_roll = std.math.clamp(split_roll_2_to_4, 2, 4);
    return switch (size) {
        .large => .{
            .child_size = .medium,
            .child_count = clamped_roll,
            .drops_slimeball_or_cream = false,
        },
        .medium => .{
            .child_size = .small,
            .child_count = clamped_roll,
            .drops_slimeball_or_cream = false,
        },
        .small => .{
            .child_size = null,
            .child_count = 0,
            .drops_slimeball_or_cream = true,
        },
    };
}

/// Magma Cube loot resolution including Frog predation.
pub const MagmaCubeLoot = struct {
    drops_magma_cream: bool,
    froglight_tag: ?u16,
};

pub fn resolveMagmaCubeLoot(size: SlimeSize, killed_by_frog: bool, frog_variant_u8: ?u8) MagmaCubeLoot {
    if (killed_by_frog and size == .small) {
        const variant = frog_variant_u8 orelse 0;
        const froglight: u16 = switch (variant) {
            0 => OchreFroglightTag,
            1 => PearlescentFroglightTag,
            2 => VerdantFroglightTag,
            else => OchreFroglightTag,
        };
        return .{ .drops_magma_cream = false, .froglight_tag = froglight };
    }
    return .{
        .drops_magma_cream = (size == .medium or size == .large),
        .froglight_tag = null,
    };
}

/// Vanilla Minecraft deterministic 1-in-10 (~10%) Slime Chunk algorithm.
/// Coordinates are evaluated with 64-bit signed wrapping arithmetic and
/// seeded into java.util.Random LCG.
pub fn isSlimeChunk(chunk_x: i32, chunk_z: i32, world_seed: u64) bool {
    const x: i64 = chunk_x;
    const z: i64 = chunk_z;
    const seed: i64 = @bitCast(world_seed);

    var rnd_seed: i64 = seed;
    rnd_seed +%= x *% x *% 4_987_142;
    rnd_seed +%= x *% 5_947_611;
    rnd_seed +%= (z *% z) *% 4_392_871;
    rnd_seed +%= z *% 389_711;
    rnd_seed ^= 987_234_911;

    return javaRandomNextInt(rnd_seed, 10) == 0;
}

/// Emulates java.util.Random.nextInt(bound) with exact 48-bit linear congruential
/// generator and uniform modulo rejection loop.
fn javaRandomNextInt(rng_seed: i64, bound: u32) u32 {
    const multiplier: u64 = 0x5DEECE66D;
    const addend: u64 = 0xB;
    const mask: u64 = (1 << 48) - 1;

    // Initial scramble: (seed ^ multiplier) & mask
    var state: u64 = (@as(u64, @bitCast(rng_seed)) ^ multiplier) & mask;

    while (true) {
        state = (state *% multiplier +% addend) & mask;
        const bits: u32 = @intCast(state >> 17);
        const value = bits % bound;
        if (bits - value + (bound - 1) < 0x8000_0000) {
            return value;
        }
    }
}

/// Slimes spawn in slime chunks below Y = 40 regardless of light level.
pub fn canSlimeSpawnInChunk(chunk_x: i32, chunk_z: i32, world_seed: u64, y_coord: i32) bool {
    return y_coord < 40 and isSlimeChunk(chunk_x, chunk_z, world_seed);
}

/// Swamp biome Slime spawn probability based on the 8-day lunar cycle.
/// Only occurs between Y = 51..69 and light_level <= 7.
/// Moon phases:
///   0 (Full Moon)        -> 1.00 (100%)
///   1 (Waning Gibbous)   -> 0.75 (75%)
///   2 (Third Quarter)    -> 0.50 (50%)
///   3 (Waning Crescent)  -> 0.25 (25%)
///   4 (New Moon)         -> 0.00 (0% - no spawns!)
///   5 (Waxing Crescent)  -> 0.25 (25%)
///   6 (First Quarter)    -> 0.50 (50%)
///   7 (Waxing Gibbous)   -> 0.75 (75%)
pub fn swampMoonPhaseSpawnChance(moon_phase_0_to_7: u3, light_level: u4, y_coord: i32) f32 {
    if (y_coord < swamp_min_y or y_coord > swamp_max_y or light_level > swamp_max_light_level) {
        return 0.0;
    }
    return switch (moon_phase_0_to_7) {
        0 => 1.0,
        1, 7 => 0.75,
        2, 6 => 0.50,
        3, 5 => 0.25,
        4 => 0.0,
    };
}

// ============================================================================
// Damage Immunities
// ============================================================================

/// Magma cubes have 100% immunity to fire damage.
pub fn magmaCubeImmuneToFire() bool {
    return true;
}

/// Magma cubes have 100% immunity to lava damage.
pub fn magmaCubeImmuneToLava() bool {
    return true;
}

/// Magma cubes have 100% immunity to fall damage.
pub fn magmaCubeImmuneToFallDamage() bool {
    return true;
}

/// Generic mob fire immunity check.
pub fn isFireImmune(is_magma_cube: bool) bool {
    return is_magma_cube;
}

/// Generic mob lava immunity check.
pub fn isLavaImmune(is_magma_cube: bool) bool {
    return is_magma_cube;
}

/// Generic mob fall damage immunity check.
pub fn isFallDamageImmune(is_magma_cube: bool) bool {
    return is_magma_cube;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "size discriminants and health scale by square" {
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(SlimeSize.small));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(SlimeSize.medium));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(SlimeSize.large));
    try std.testing.expectEqual(@as(f32, 1.0), SlimeSize.small.health());
    try std.testing.expectEqual(@as(f32, 4.0), SlimeSize.medium.health());
    try std.testing.expectEqual(@as(f32, 16.0), SlimeSize.large.health());
    try std.testing.expectEqual(@as(f32, 1.0), SlimeSize.small.slimeHealth());
    try std.testing.expectEqual(@as(f32, 16.0), SlimeSize.large.magmaCubeHealth());
}

test "slime damage distinguishes harmless small slimes" {
    try std.testing.expectEqual(@as(f32, 0.0), SlimeSize.small.slimeMeleeDamage());
    try std.testing.expectEqual(@as(f32, 2.0), SlimeSize.medium.slimeMeleeDamage());
    try std.testing.expectEqual(@as(f32, 4.0), SlimeSize.large.slimeMeleeDamage());
}

test "magma cube damage includes small cube damage" {
    try std.testing.expectEqual(@as(f32, 3.0), SlimeSize.small.magmaCubeMeleeDamage());
    try std.testing.expectEqual(@as(f32, 4.0), SlimeSize.medium.magmaCubeMeleeDamage());
    try std.testing.expectEqual(@as(f32, 6.0), SlimeSize.large.magmaCubeMeleeDamage());
}

test "magma cube armor scales with size (3 * size)" {
    try std.testing.expectEqual(@as(u8, 0), SlimeSize.small.slimeArmor());
    try std.testing.expectEqual(@as(u8, 0), SlimeSize.large.slimeArmor());
    try std.testing.expectEqual(@as(u8, 3), SlimeSize.small.magmaCubeArmor());
    try std.testing.expectEqual(@as(u8, 6), SlimeSize.medium.magmaCubeArmor());
    try std.testing.expectEqual(@as(u8, 12), SlimeSize.large.magmaCubeArmor());
}

test "magma cube jump velocity is 1.5x slime jump velocity" {
    try std.testing.expectEqual(@as(f32, 8.25), SlimeSize.magmaCubeJumpVelocity(5.5));
    try std.testing.expectEqual(@as(f32, 12.0), SlimeSize.magmaCubeJumpVelocity(8.0));
}

test "magma cubes ignore fire lava and fall damage" {
    try std.testing.expect(magmaCubeImmuneToFire());
    try std.testing.expect(magmaCubeImmuneToLava());
    try std.testing.expect(magmaCubeImmuneToFallDamage());
}

test "generic immunity queries for magma cube vs slime" {
    try std.testing.expect(isFireImmune(true));
    try std.testing.expect(!isFireImmune(false));
    try std.testing.expect(isLavaImmune(true));
    try std.testing.expect(!isLavaImmune(false));
    try std.testing.expect(isFallDamageImmune(true));
    try std.testing.expect(!isFallDamageImmune(false));
}

test "large death splits into two to four medium children with no item drops" {
    inline for (.{ 2, 3, 4 }) |count| {
        const split = resolveMitosisSplitOnDeath(.large, count);
        try std.testing.expectEqual(SlimeSize.medium, split.child_size.?);
        try std.testing.expectEqual(@as(u8, count), split.child_count);
        try std.testing.expect(!split.drops_slimeball_or_cream);
    }
}

test "medium death splits into two to four small children with no item drops" {
    inline for (.{ 2, 3, 4 }) |count| {
        const split = resolveMitosisSplitOnDeath(.medium, count);
        try std.testing.expectEqual(SlimeSize.small, split.child_size.?);
        try std.testing.expectEqual(@as(u8, count), split.child_count);
        try std.testing.expect(!split.drops_slimeball_or_cream);
    }
}

test "small death does not split and drops slimeball or cream" {
    const split = resolveMitosisSplitOnDeath(.small, 3);
    try std.testing.expectEqual(@as(?SlimeSize, null), split.child_size);
    try std.testing.expectEqual(@as(u8, 0), split.child_count);
    try std.testing.expect(split.drops_slimeball_or_cream);
}

test "resolveMitosisSplitOnDeath clamps out-of-range rolls" {
    const clamped_low = resolveMitosisSplitOnDeath(.large, 0);
    try std.testing.expectEqual(@as(u8, 2), clamped_low.child_count);
    const clamped_high = resolveMitosisSplitOnDeath(.large, 10);
    try std.testing.expectEqual(@as(u8, 4), clamped_high.child_count);
}

test "magma cube loot drops cream for medium and large" {
    const loot_small = resolveMagmaCubeLoot(.small, false, null);
    try std.testing.expect(!loot_small.drops_magma_cream);
    try std.testing.expectEqual(@as(?u16, null), loot_small.froglight_tag);

    const loot_med = resolveMagmaCubeLoot(.medium, false, null);
    try std.testing.expect(loot_med.drops_magma_cream);

    const loot_large = resolveMagmaCubeLoot(.large, false, null);
    try std.testing.expect(loot_large.drops_magma_cream);
}

test "magma cube eaten by frog drops variant froglight" {
    // Temperate frog (0) -> Ochre (386)
    const loot_ochre = resolveMagmaCubeLoot(.small, true, 0);
    try std.testing.expectEqual(OchreFroglightTag, loot_ochre.froglight_tag.?);

    // Warm frog (1) -> Pearlescent (388)
    const loot_pearl = resolveMagmaCubeLoot(.small, true, 1);
    try std.testing.expectEqual(PearlescentFroglightTag, loot_pearl.froglight_tag.?);

    // Cold frog (2) -> Verdant (387)
    const loot_verd = resolveMagmaCubeLoot(.small, true, 2);
    try std.testing.expectEqual(VerdantFroglightTag, loot_verd.froglight_tag.?);
}

test "slime chunk hash is deterministic across calls" {
    for (0..100) |i| {
        const x: i32 = @intCast(i);
        try std.testing.expectEqual(isSlimeChunk(x, -x, 123456789), isSlimeChunk(x, -x, 123456789));
    }
}

test "slime chunk distribution is close to 10% across 10,000 chunks" {
    var matches: u32 = 0;
    for (0..10_000) |i| {
        const x: i32 = @intCast(i % 100);
        const z: i32 = @intCast(i / 100);
        if (isSlimeChunk(x, z, 987654321)) matches += 1;
    }
    // 1,000 expected (10%). Expected within [850, 1150] (approx 5 std dev)
    try std.testing.expect(matches >= 850 and matches <= 1150);
}

test "slime chunk hash handles negative coordinates and large seeds" {
    _ = isSlimeChunk(-123, -456, 0xFFFF_FFFF_FFFF_FFFF);
    _ = isSlimeChunk(123, 456, 0);
}

test "slime chunk known vanilla coordinates for seed 0" {
    try std.testing.expect(isSlimeChunk(-2, 0, 0));
    try std.testing.expect(isSlimeChunk(2, 2, 0));
    try std.testing.expect(isSlimeChunk(4, 2, 0));
    try std.testing.expect(!isSlimeChunk(0, 0, 0));
}

test "slime chunk max spawn height is below Y = 40" {
    // (-2, 0) is a slime chunk for seed 0
    try std.testing.expect(canSlimeSpawnInChunk(-2, 0, 0, 39));
    try std.testing.expect(canSlimeSpawnInChunk(-2, 0, 0, 10));
    try std.testing.expect(!canSlimeSpawnInChunk(-2, 0, 0, 40));
    try std.testing.expect(!canSlimeSpawnInChunk(-2, 0, 0, 50));
    // (0, 0) is not a slime chunk
    try std.testing.expect(!canSlimeSpawnInChunk(0, 0, 0, 30));
}

test "swamp lunar chances cover all eight phases symmetrically" {
    const expected = [_]f32{ 1.0, 0.75, 0.50, 0.25, 0.0, 0.25, 0.50, 0.75 };
    for (expected, 0..) |chance, phase| {
        try std.testing.expectEqual(chance, swampMoonPhaseSpawnChance(@intCast(phase), 7, 60));
    }
}

test "swamp new moon has zero spawn chance" {
    try std.testing.expectEqual(@as(f32, 0.0), swampMoonPhaseSpawnChance(4, 0, 60));
}

test "swamp spawn requires specified height (51..69) and low light (<= 7)" {
    try std.testing.expectEqual(@as(f32, 1.0), swampMoonPhaseSpawnChance(0, 7, 51));
    try std.testing.expectEqual(@as(f32, 1.0), swampMoonPhaseSpawnChance(0, 0, 69));
    try std.testing.expectEqual(@as(f32, 0.0), swampMoonPhaseSpawnChance(0, 8, 60));
    try std.testing.expectEqual(@as(f32, 0.0), swampMoonPhaseSpawnChance(0, 7, 50));
    try std.testing.expectEqual(@as(f32, 0.0), swampMoonPhaseSpawnChance(0, 7, 70));
}

test "slime and magma cube dimensions scale with size" {
    const small_dim = SlimeSize.small.dimensions();
    const med_dim = SlimeSize.medium.dimensions();
    const large_dim = SlimeSize.large.dimensions();
    try std.testing.expectApproxEqAbs(@as(f32, 0.51), small_dim.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.02), med_dim.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.04), large_dim.width, 0.001);
}
