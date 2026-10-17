const std = @import("std");
const note_block_instruments = @import("note_block_instruments.zig");
pub const NoteBlockInstrument = note_block_instruments.NoteBlockInstrument;

const subterranean_fossils = @This();

// ============================================================================
// 1. Overworld Fossil Biomes
// ============================================================================

/// Biome registry kinds evaluated for subterranean fossil generation.
/// In Minecraft Overworld worldgen, fossils generate exclusively underground
/// in Desert, Swamp, and Mangrove Swamp biomes.
pub const OverworldFossilBiome = enum {
    desert,
    swamp,
    mangrove_swamp,
    plains,
    snowy_plains,
    forest,
    birch_forest,
    dark_forest,
    taiga,
    snowy_taiga,
    savanna,
    savanna_plateau,
    jungle,
    sparse_jungle,
    bamboo_jungle,
    badlands,
    eroded_badlands,
    wooded_badlands,
    meadow,
    cherry_grove,
    grove,
    snowy_slopes,
    frozen_peaks,
    jagged_peaks,
    stony_peaks,
    river,
    frozen_river,
    beach,
    snowy_beach,
    stony_shore,
    warm_ocean,
    lukewarm_ocean,
    deep_lukewarm_ocean,
    ocean,
    deep_ocean,
    cold_ocean,
    deep_cold_ocean,
    frozen_ocean,
    deep_frozen_ocean,
    mushroom_fields,
    dripstone_caves,
    lush_caves,
    deep_dark,
    nether_wastes,
    soul_sand_valley,
    crimson_forest,
    warped_forest,
    basalt_deltas,
    the_end,

    pub fn canGenerateOverworldFossil(self: OverworldFossilBiome) bool {
        return subterranean_fossils.canGenerateOverworldFossil(self);
    }

    pub fn canGenerate(self: OverworldFossilBiome) bool {
        return subterranean_fossils.canGenerateOverworldFossil(self);
    }
};

/// Returns true if and only if the given biome can generate subterranean fossils.
/// Generates exclusively underground in .desert, .swamp, and .mangrove_swamp biomes.
pub fn canGenerateOverworldFossil(biome: OverworldFossilBiome) bool {
    return switch (biome) {
        .desert, .swamp, .mangrove_swamp => true,
        else => false,
    };
}

// ============================================================================
// 2. Fossil Anatomy Variants & Structure Integrity
// ============================================================================

/// Broad anatomical category of the fossil structure.
pub const FossilCategory = enum {
    skull,
    spine,
};

/// 8 official Overworld fossil structure variants:
/// 4 skull variants (.skull_1 .. .skull_4) and 4 spine ribcage variants (.spine_1 .. .spine_4).
pub const FossilAnatomyVariant = enum {
    skull_1,
    skull_2,
    skull_3,
    skull_4,
    spine_1,
    spine_2,
    spine_3,
    spine_4,

    /// 90% structure integrity: 90% of bone blocks generate intact.
    pub const STRUCTURE_INTEGRITY: f32 = 0.90;
    /// 10% decay rate: 10% of bone blocks decay into air or ore.
    pub const DECAY_RATE: f32 = 0.10;

    pub fn isSkull(self: FossilAnatomyVariant) bool {
        return switch (self) {
            .skull_1, .skull_2, .skull_3, .skull_4 => true,
            .spine_1, .spine_2, .spine_3, .spine_4 => false,
        };
    }

    pub fn isSpine(self: FossilAnatomyVariant) bool {
        return !self.isSkull();
    }

    pub fn isSpineRibcage(self: FossilAnatomyVariant) bool {
        return self.isSpine();
    }

    pub fn category(self: FossilAnatomyVariant) FossilCategory {
        return if (self.isSkull()) .skull else .spine;
    }

    pub fn structureIntegrity(self: FossilAnatomyVariant) f32 {
        _ = self;
        return STRUCTURE_INTEGRITY;
    }

    pub fn decayRate(self: FossilAnatomyVariant) f32 {
        _ = self;
        return DECAY_RATE;
    }

    pub fn variantIndex(self: FossilAnatomyVariant) u3 {
        return @intFromEnum(self);
    }

    pub fn dimensions(self: FossilAnatomyVariant) FossilDimensions {
        return switch (self) {
            .skull_1 => .{ .width = 8, .height = 7, .length = 8, .approx_bone_count = 54 },
            .skull_2 => .{ .width = 7, .height = 6, .length = 9, .approx_bone_count = 46 },
            .skull_3 => .{ .width = 7, .height = 7, .length = 7, .approx_bone_count = 50 },
            .skull_4 => .{ .width = 6, .height = 6, .length = 8, .approx_bone_count = 40 },
            .spine_1 => .{ .width = 7, .height = 5, .length = 13, .approx_bone_count = 58 },
            .spine_2 => .{ .width = 9, .height = 6, .length = 13, .approx_bone_count = 72 },
            .spine_3 => .{ .width = 7, .height = 6, .length = 11, .approx_bone_count = 56 },
            .spine_4 => .{ .width = 9, .height = 5, .length = 15, .approx_bone_count = 68 },
        };
    }

    pub fn template(self: FossilAnatomyVariant) []const FossilBone {
        return switch (self) {
            .skull_1 => skull_1_bones[0..],
            .skull_2 => skull_2_bones[0..],
            .skull_3 => skull_3_bones[0..],
            .skull_4 => skull_4_bones[0..],
            .spine_1 => spine_1_bones[0..],
            .spine_2 => spine_2_bones[0..],
            .spine_3 => spine_3_bones[0..],
            .spine_4 => spine_4_bones[0..],
        };
    }
};

pub const FossilDimensions = struct {
    width: u8,
    height: u8,
    length: u8,
    approx_bone_count: u16,
};

/// A single bone element within a fossil template layout.
pub const FossilBone = struct {
    rel_x: i8,
    rel_y: i8,
    rel_z: i8,
    axis: PillarAxis = .y,
};

// Canonical representations of the 8 fossil structure templates.
const skull_1_bones = [_]FossilBone{
    .{ .rel_x = 0, .rel_y = 0, .rel_z = 0, .axis = .y },
    .{ .rel_x = 1, .rel_y = 0, .rel_z = 0, .axis = .x },
    .{ .rel_x = 2, .rel_y = 0, .rel_z = 0, .axis = .x },
    .{ .rel_x = 0, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 2, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 0, .axis = .y },
    .{ .rel_x = 1, .rel_y = 2, .rel_z = 0, .axis = .x },
    .{ .rel_x = 2, .rel_y = 2, .rel_z = 0, .axis = .x },
    .{ .rel_x = 0, .rel_y = 0, .rel_z = 1, .axis = .z },
    .{ .rel_x = 2, .rel_y = 0, .rel_z = 1, .axis = .z },
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 1, .axis = .z },
    .{ .rel_x = 2, .rel_y = 2, .rel_z = 1, .axis = .z },
};

const skull_2_bones = [_]FossilBone{
    .{ .rel_x = 0, .rel_y = 0, .rel_z = 0, .axis = .x },
    .{ .rel_x = 1, .rel_y = 0, .rel_z = 0, .axis = .x },
    .{ .rel_x = 0, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 1, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 1, .axis = .z },
    .{ .rel_x = 1, .rel_y = 2, .rel_z = 1, .axis = .z },
    .{ .rel_x = 0, .rel_y = 1, .rel_z = 2, .axis = .y },
    .{ .rel_x = 1, .rel_y = 1, .rel_z = 2, .axis = .y },
};

const skull_3_bones = [_]FossilBone{
    .{ .rel_x = -1, .rel_y = 0, .rel_z = 0, .axis = .x },
    .{ .rel_x = 0, .rel_y = 0, .rel_z = 0, .axis = .y },
    .{ .rel_x = 1, .rel_y = 0, .rel_z = 0, .axis = .x },
    .{ .rel_x = -1, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 1, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 0, .axis = .x },
    .{ .rel_x = 0, .rel_y = 1, .rel_z = 1, .axis = .z },
};

const skull_4_bones = [_]FossilBone{
    .{ .rel_x = 0, .rel_y = 0, .rel_z = 0, .axis = .y },
    .{ .rel_x = 0, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 1, .rel_y = 1, .rel_z = 0, .axis = .x },
    .{ .rel_x = 0, .rel_y = 1, .rel_z = 1, .axis = .z },
    .{ .rel_x = 1, .rel_y = 1, .rel_z = 1, .axis = .y },
    .{ .rel_x = 0, .rel_y = 0, .rel_z = 1, .axis = .z },
};

const spine_1_bones = [_]FossilBone{
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 0, .axis = .z },
    .{ .rel_x = -1, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 1, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = -1, .rel_y = 0, .rel_z = 0, .axis = .x },
    .{ .rel_x = 1, .rel_y = 0, .rel_z = 0, .axis = .x },
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 2, .axis = .z },
    .{ .rel_x = -1, .rel_y = 1, .rel_z = 2, .axis = .y },
    .{ .rel_x = 1, .rel_y = 1, .rel_z = 2, .axis = .y },
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 4, .axis = .z },
};

const spine_2_bones = [_]FossilBone{
    .{ .rel_x = 0, .rel_y = 3, .rel_z = 0, .axis = .z },
    .{ .rel_x = -2, .rel_y = 2, .rel_z = 0, .axis = .x },
    .{ .rel_x = -1, .rel_y = 3, .rel_z = 0, .axis = .x },
    .{ .rel_x = 1, .rel_y = 3, .rel_z = 0, .axis = .x },
    .{ .rel_x = 2, .rel_y = 2, .rel_z = 0, .axis = .x },
    .{ .rel_x = -2, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 2, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 0, .rel_y = 3, .rel_z = 2, .axis = .z },
};

const spine_3_bones = [_]FossilBone{
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 0, .axis = .z },
    .{ .rel_x = -2, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 2, .rel_y = 1, .rel_z = 0, .axis = .y },
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 2, .axis = .z },
    .{ .rel_x = -2, .rel_y = 1, .rel_z = 2, .axis = .y },
    .{ .rel_x = 2, .rel_y = 1, .rel_z = 2, .axis = .y },
    .{ .rel_x = 0, .rel_y = 2, .rel_z = 4, .axis = .z },
};

const spine_4_bones = [_]FossilBone{
    .{ .rel_x = 0, .rel_y = 3, .rel_z = 0, .axis = .z },
    .{ .rel_x = -3, .rel_y = 2, .rel_z = 0, .axis = .y },
    .{ .rel_x = 3, .rel_y = 2, .rel_z = 0, .axis = .y },
    .{ .rel_x = -2, .rel_y = 3, .rel_z = 0, .axis = .x },
    .{ .rel_x = 2, .rel_y = 3, .rel_z = 0, .axis = .x },
    .{ .rel_x = 0, .rel_y = 3, .rel_z = 3, .axis = .z },
    .{ .rel_x = -3, .rel_y = 2, .rel_z = 3, .axis = .y },
    .{ .rel_x = 3, .rel_y = 2, .rel_z = 3, .axis = .y },
};

// ============================================================================
// 3. Fossil Ore Substitution: Shallow Coal vs Deep Deepslate Diamond
// ============================================================================

/// Kinds of ore that substitute decayed bone blocks in subterranean fossils.
pub const FossilOreKind = enum {
    coal_ore,
    deepslate_diamond_ore,

    pub fn isCoal(self: FossilOreKind) bool {
        return self == .coal_ore;
    }

    pub fn isDiamond(self: FossilOreKind) bool {
        return self == .deepslate_diamond_ore;
    }

    pub fn isDeepslate(self: FossilOreKind) bool {
        return self == .deepslate_diamond_ore;
    }
};

/// Resolves the ore substitution block type for a given altitude Y:
/// - Shallow fossils (y >= 0, specifically y = 40..49 or 0..320): replaced bone blocks become coal_ore.
/// - Deep deepslate fossils (y < 0, specifically y = -63..-8): replaced bone blocks become deepslate_diamond_ore.
pub fn resolveFossilOreBlock(y: i32) FossilOreKind {
    if (y < 0) {
        return .deepslate_diamond_ore;
    } else {
        return .coal_ore;
    }
}

/// Structure processor constants and rules for ore substitution.
pub const FossilOreSubstitution = struct {
    pub const SHALLOW_MIN_Y: i32 = 0;
    pub const SHALLOW_MAX_Y: i32 = 320;
    pub const SHALLOW_CONCENTRATION_MIN_Y: i32 = 40;
    pub const SHALLOW_CONCENTRATION_MAX_Y: i32 = 49;

    pub const DEEP_MIN_Y: i32 = -63;
    pub const DEEP_MAX_Y: i32 = -8;

    pub const STRUCTURE_INTEGRITY: f32 = 0.90;
    pub const DECAY_RATE: f32 = 0.10;
    pub const ORE_SUBSTITUTION_RATE: f32 = 0.10; // 10% of replaced bone blocks become ore

    pub fn resolveFossilOreBlock(y: i32) FossilOreKind {
        return subterranean_fossils.resolveFossilOreBlock(y);
    }

    pub fn isDeepslateLayer(y: i32) bool {
        return y < 0;
    }

    pub fn isShallowLayer(y: i32) bool {
        return y >= 0;
    }

    pub fn isDeepFossilAltitude(y: i32) bool {
        return y >= DEEP_MIN_Y and y <= DEEP_MAX_Y;
    }

    pub fn isShallowFossilAltitude(y: i32) bool {
        return y >= SHALLOW_MIN_Y and y <= SHALLOW_MAX_Y;
    }

    pub fn isConcentratedShallowAltitude(y: i32) bool {
        return y >= SHALLOW_CONCENTRATION_MIN_Y and y <= SHALLOW_CONCENTRATION_MAX_Y;
    }

    /// Evaluates what a decayed bone block becomes:
    /// - 10% of replaced bone blocks become ore (coal_ore if y >= 0, deepslate_diamond_ore if y < 0).
    /// - The other 90% decay into air (represented by null).
    pub fn substituteDecayedBlock(y: i32, ore_roll: f32) ?FossilOreKind {
        if (ore_roll >= 0.0 and ore_roll < ORE_SUBSTITUTION_RATE) {
            return subterranean_fossils.resolveFossilOreBlock(y);
        }
        return null;
    }
};

/// Block states produced when sampling a subterranean fossil position.
pub const PlacedFossilBlock = enum {
    bone_block,
    coal_ore,
    deepslate_diamond_ore,
    air,

    pub fn isOre(self: PlacedFossilBlock) bool {
        return self == .coal_ore or self == .deepslate_diamond_ore;
    }

    pub fn isBone(self: PlacedFossilBlock) bool {
        return self == .bone_block;
    }

    pub fn isAir(self: PlacedFossilBlock) bool {
        return self == .air;
    }
};

/// Samples the resulting block given altitude Y, an integrity roll in [0.0, 1.0),
/// and an ore substitution roll in [0.0, 1.0).
pub fn sampleFossilBlock(y: i32, integrity_roll: f32, ore_roll: f32) PlacedFossilBlock {
    // 90% structure integrity -> bone block
    if (integrity_roll >= 0.0 and integrity_roll < FossilAnatomyVariant.STRUCTURE_INTEGRITY) {
        return .bone_block;
    }
    // 10% of bone blocks decay into air or ore:
    // 10% of replaced bone blocks become ore
    if (ore_roll >= 0.0 and ore_roll < FossilOreSubstitution.ORE_SUBSTITUTION_RATE) {
        return switch (resolveFossilOreBlock(y)) {
            .coal_ore => .coal_ore,
            .deepslate_diamond_ore => .deepslate_diamond_ore,
        };
    }
    return .air;
}

/// Deterministic block placement sampler using 64-bit integer hashing of world coordinates and seed.
pub fn sampleFossilBlockAtCoord(world_seed: u64, x: i32, y: i32, z: i32) PlacedFossilBlock {
    var h = world_seed ^ (@as(u64, @bitCast(@as(i64, x))) *% 0x517cc1b727220a95);
    h ^= (@as(u64, @bitCast(@as(i64, y))) *% 0x6c62272e07bb0142);
    h ^= (@as(u64, @bitCast(@as(i64, z))) *% 0x62b821756295c58d);
    h ^= h >> 30;
    h *%= 0xbf58476d1ce4e5b9;
    h ^= h >> 27;
    h *%= 0x94d049bb133111eb;
    h ^= h >> 31;

    const integrity_int = @as(u16, @truncate(h));
    const ore_int = @as(u16, @truncate(h >> 16));

    const integrity_roll = @as(f32, @floatFromInt(integrity_int)) / 65536.0;
    const ore_roll = @as(f32, @floatFromInt(ore_int)) / 65536.0;

    return sampleFossilBlock(y, integrity_roll, ore_roll);
}

// ============================================================================
// 4. Bone Block Crafting (Bidirectional 1 Bone Block <-> 9 Bone Meal)
// ============================================================================

pub const BoneBlockCrafting = struct {
    pub const BONE_MEAL_PER_BLOCK: u16 = 9;

    pub fn craftBoneBlockFromMeal(meal: u16) u16 {
        return meal / BONE_MEAL_PER_BLOCK;
    }

    pub fn uncraftBoneBlockToMeal(blocks: u16) u16 {
        return blocks *| BONE_MEAL_PER_BLOCK;
    }

    pub const CraftingSummary = struct {
        blocks_crafted: u16,
        leftover_meal: u16,
    };

    pub fn craftWithRemainder(meal: u16) CraftingSummary {
        return .{
            .blocks_crafted = meal / BONE_MEAL_PER_BLOCK,
            .leftover_meal = meal % BONE_MEAL_PER_BLOCK,
        };
    }
};

/// Crafts Bone Blocks from Bone Meal. 9 Bone Meal yields 1 Bone Block (integer division).
pub fn craftBoneBlockFromMeal(meal: u16) u16 {
    return BoneBlockCrafting.craftBoneBlockFromMeal(meal);
}

/// Uncrafts Bone Blocks into Bone Meal. 1 Bone Block yields 9 Bone Meal.
pub fn uncraftBoneBlockToMeal(blocks: u16) u16 {
    return BoneBlockCrafting.uncraftBoneBlockToMeal(blocks);
}

// ============================================================================
// 5. Bone Block Properties, Pillar Axis & Note Block Acoustics
// ============================================================================

/// Directional pillar axis along which a Bone Block is aligned when placed (.x, .y, .z).
pub const PillarAxis = enum {
    x,
    y,
    z,

    pub fn isVertical(self: PillarAxis) bool {
        return self == .y;
    }

    pub fn isHorizontal(self: PillarAxis) bool {
        return self == .x or self == .z;
    }

    pub fn directionVector(self: PillarAxis) [3]i8 {
        return switch (self) {
            .x => [3]i8{ 1, 0, 0 },
            .y => [3]i8{ 0, 1, 0 },
            .z => [3]i8{ 0, 0, 1 },
        };
    }
};

pub const Axis = PillarAxis;

/// Physical and acoustic properties of the Bone Block.
pub const BoneBlockProperties = struct {
    axis: PillarAxis = .y,
    hardness: f32 = 2.0,
    blast_resistance: f32 = 2.0,

    pub const Axis = PillarAxis;

    pub fn dropsWithoutPickaxe() bool {
        return false;
    }

    pub fn noteBlockInstrument() NoteBlockInstrument {
        return .xylophone;
    }

    pub fn requiresPickaxe() bool {
        return true;
    }

    pub fn dropsWhenMined(with_pickaxe: bool) bool {
        return with_pickaxe;
    }

    pub fn getInstrument(self: BoneBlockProperties) NoteBlockInstrument {
        _ = self;
        return subterranean_fossils.noteBlockInstrument();
    }
};

/// Bone Blocks require a pickaxe to harvest; breaking them by hand or any non-pickaxe tool drops nothing.
pub fn dropsWithoutPickaxe() bool {
    return false;
}

/// A Bone Block placed beneath a Note Block configures the Note Block to play the xylophone sound.
pub fn noteBlockInstrument() NoteBlockInstrument {
    return .xylophone;
}

// ============================================================================
// Tests
// ============================================================================

test "1. OverworldFossilBiome generates exclusively in desert, swamp, and mangrove_swamp" {
    try std.testing.expect(canGenerateOverworldFossil(.desert));
    try std.testing.expect(canGenerateOverworldFossil(.swamp));
    try std.testing.expect(canGenerateOverworldFossil(.mangrove_swamp));
}

test "2. OverworldFossilBiome rejects non-fossil biomes" {
    const non_fossil_biomes = [_]OverworldFossilBiome{
        .plains,
        .snowy_plains,
        .forest,
        .birch_forest,
        .dark_forest,
        .taiga,
        .snowy_taiga,
        .savanna,
        .jungle,
        .badlands,
        .ocean,
        .deep_ocean,
        .deep_dark,
        .dripstone_caves,
        .lush_caves,
        .nether_wastes,
        .the_end,
    };
    for (non_fossil_biomes) |biome| {
        try std.testing.expect(!canGenerateOverworldFossil(biome));
        try std.testing.expect(!biome.canGenerate());
    }
}

test "3. OverworldFossilBiome method matches free function" {
    try std.testing.expectEqual(canGenerateOverworldFossil(.desert), OverworldFossilBiome.desert.canGenerateOverworldFossil());
    try std.testing.expectEqual(canGenerateOverworldFossil(.swamp), OverworldFossilBiome.swamp.canGenerateOverworldFossil());
    try std.testing.expectEqual(canGenerateOverworldFossil(.mangrove_swamp), OverworldFossilBiome.mangrove_swamp.canGenerateOverworldFossil());
    try std.testing.expectEqual(canGenerateOverworldFossil(.plains), OverworldFossilBiome.plains.canGenerateOverworldFossil());
}

test "4. FossilAnatomyVariant defines 4 skull variants and 4 spine ribcage variants" {
    const skulls = [_]FossilAnatomyVariant{ .skull_1, .skull_2, .skull_3, .skull_4 };
    const spines = [_]FossilAnatomyVariant{ .spine_1, .spine_2, .spine_3, .spine_4 };

    for (skulls) |variant| {
        try std.testing.expect(variant.isSkull());
        try std.testing.expect(!variant.isSpine());
        try std.testing.expectEqual(FossilCategory.skull, variant.category());
    }

    for (spines) |variant| {
        try std.testing.expect(variant.isSpine());
        try std.testing.expect(variant.isSpineRibcage());
        try std.testing.expect(!variant.isSkull());
        try std.testing.expectEqual(FossilCategory.spine, variant.category());
    }
}

test "5. FossilAnatomyVariant structure integrity is 90% and decay rate is 10%" {
    const all_variants = [_]FossilAnatomyVariant{
        .skull_1, .skull_2, .skull_3, .skull_4,
        .spine_1, .spine_2, .spine_3, .spine_4,
    };

    for (all_variants) |v| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.90), v.structureIntegrity(), 0.0001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.10), v.decayRate(), 0.0001);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 0.90), FossilAnatomyVariant.STRUCTURE_INTEGRITY, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), FossilAnatomyVariant.DECAY_RATE, 0.0001);
}

test "6. FossilAnatomyVariant dimensions and structural templates are non-empty" {
    const all_variants = [_]FossilAnatomyVariant{
        .skull_1, .skull_2, .skull_3, .skull_4,
        .spine_1, .spine_2, .spine_3, .spine_4,
    };

    for (all_variants) |v| {
        const dim = v.dimensions();
        try std.testing.expect(dim.width > 0);
        try std.testing.expect(dim.height > 0);
        try std.testing.expect(dim.length > 0);
        try std.testing.expect(dim.approx_bone_count > 0);

        const tmpl = v.template();
        try std.testing.expect(tmpl.len > 0);
    }
}

test "7. resolveFossilOreBlock returns coal_ore for shallow fossils (y >= 0)" {
    // Specifically y = 40..49 (peak concentration) or general shallow 0..320
    try std.testing.expectEqual(FossilOreKind.coal_ore, resolveFossilOreBlock(0));
    try std.testing.expectEqual(FossilOreKind.coal_ore, resolveFossilOreBlock(40));
    try std.testing.expectEqual(FossilOreKind.coal_ore, resolveFossilOreBlock(45));
    try std.testing.expectEqual(FossilOreKind.coal_ore, resolveFossilOreBlock(49));
    try std.testing.expectEqual(FossilOreKind.coal_ore, resolveFossilOreBlock(100));
    try std.testing.expectEqual(FossilOreKind.coal_ore, resolveFossilOreBlock(320));

    const ore = resolveFossilOreBlock(45);
    try std.testing.expect(ore.isCoal());
    try std.testing.expect(!ore.isDiamond());
}

test "8. resolveFossilOreBlock returns deepslate_diamond_ore for deep deepslate fossils (y < 0)" {
    // Specifically deep deepslate y = -63..-8
    try std.testing.expectEqual(FossilOreKind.deepslate_diamond_ore, resolveFossilOreBlock(-1));
    try std.testing.expectEqual(FossilOreKind.deepslate_diamond_ore, resolveFossilOreBlock(-8));
    try std.testing.expectEqual(FossilOreKind.deepslate_diamond_ore, resolveFossilOreBlock(-20));
    try std.testing.expectEqual(FossilOreKind.deepslate_diamond_ore, resolveFossilOreBlock(-50));
    try std.testing.expectEqual(FossilOreKind.deepslate_diamond_ore, resolveFossilOreBlock(-63));

    const ore = resolveFossilOreBlock(-40);
    try std.testing.expect(ore.isDiamond());
    try std.testing.expect(ore.isDeepslate());
    try std.testing.expect(!ore.isCoal());
}

test "9. FossilOreSubstitution altitude helpers classify shallow vs deep layers correctly" {
    try std.testing.expect(FossilOreSubstitution.isShallowLayer(0));
    try std.testing.expect(FossilOreSubstitution.isShallowLayer(45));
    try std.testing.expect(!FossilOreSubstitution.isShallowLayer(-1));

    try std.testing.expect(FossilOreSubstitution.isDeepslateLayer(-10));
    try std.testing.expect(!FossilOreSubstitution.isDeepslateLayer(10));

    try std.testing.expect(FossilOreSubstitution.isDeepFossilAltitude(-63));
    try std.testing.expect(FossilOreSubstitution.isDeepFossilAltitude(-8));
    try std.testing.expect(!FossilOreSubstitution.isDeepFossilAltitude(-64));
    try std.testing.expect(!FossilOreSubstitution.isDeepFossilAltitude(-7));

    try std.testing.expect(FossilOreSubstitution.isConcentratedShallowAltitude(40));
    try std.testing.expect(FossilOreSubstitution.isConcentratedShallowAltitude(49));
    try std.testing.expect(!FossilOreSubstitution.isConcentratedShallowAltitude(39));
    try std.testing.expect(!FossilOreSubstitution.isConcentratedShallowAltitude(50));
}

test "10. FossilOreSubstitution substituteDecayedBlock replaces 10% with ore and 90% with air" {
    // In shallow layer (y = 45): ore substitution yields coal_ore
    const shallow_ore = FossilOreSubstitution.substituteDecayedBlock(45, 0.05);
    try std.testing.expect(shallow_ore != null);
    try std.testing.expectEqual(FossilOreKind.coal_ore, shallow_ore.?);

    // In deep deepslate layer (y = -40): ore substitution yields deepslate_diamond_ore
    const deep_ore = FossilOreSubstitution.substituteDecayedBlock(-40, 0.05);
    try std.testing.expect(deep_ore != null);
    try std.testing.expectEqual(FossilOreKind.deepslate_diamond_ore, deep_ore.?);

    // When ore roll >= 0.10 (the other 90% of decay), decays to air (null)
    const decay_air_shallow = FossilOreSubstitution.substituteDecayedBlock(45, 0.15);
    try std.testing.expect(decay_air_shallow == null);

    const decay_air_deep = FossilOreSubstitution.substituteDecayedBlock(-40, 0.85);
    try std.testing.expect(decay_air_deep == null);
}

test "11. craftBoneBlockFromMeal crafts 1 Bone Block per 9 Bone Meal" {
    try std.testing.expectEqual(@as(u16, 0), craftBoneBlockFromMeal(0));
    try std.testing.expectEqual(@as(u16, 0), craftBoneBlockFromMeal(8));
    try std.testing.expectEqual(@as(u16, 1), craftBoneBlockFromMeal(9));
    try std.testing.expectEqual(@as(u16, 1), craftBoneBlockFromMeal(17));
    try std.testing.expectEqual(@as(u16, 2), craftBoneBlockFromMeal(18));
    try std.testing.expectEqual(@as(u16, 7), craftBoneBlockFromMeal(64));
    try std.testing.expectEqual(@as(u16, 64), craftBoneBlockFromMeal(576));

    const summary = BoneBlockCrafting.craftWithRemainder(25);
    try std.testing.expectEqual(@as(u16, 2), summary.blocks_crafted);
    try std.testing.expectEqual(@as(u16, 7), summary.leftover_meal);
}

test "12. uncraftBoneBlockToMeal converts 1 Bone Block to 9 Bone Meal" {
    try std.testing.expectEqual(@as(u16, 0), uncraftBoneBlockToMeal(0));
    try std.testing.expectEqual(@as(u16, 9), uncraftBoneBlockToMeal(1));
    try std.testing.expectEqual(@as(u16, 18), uncraftBoneBlockToMeal(2));
    try std.testing.expectEqual(@as(u16, 576), uncraftBoneBlockToMeal(64));
    try std.testing.expectEqual(@as(u16, 900), uncraftBoneBlockToMeal(100));
}

test "13. BoneBlockCrafting bidirectional round-trip conversion" {
    var blocks: u16 = 1;
    while (blocks <= 64) : (blocks += 1) {
        const meal = uncraftBoneBlockToMeal(blocks);
        try std.testing.expectEqual(blocks * 9, meal);
        const crafted_back = craftBoneBlockFromMeal(meal);
        try std.testing.expectEqual(blocks, crafted_back);
    }
}

test "14. BoneBlockProperties directional pillar axis (.x, .y, .z) and defaults" {
    const default_props = BoneBlockProperties{};
    try std.testing.expectEqual(PillarAxis.y, default_props.axis);
    try std.testing.expect(default_props.axis.isVertical());
    try std.testing.expect(!default_props.axis.isHorizontal());

    const x_props = BoneBlockProperties{ .axis = .x };
    try std.testing.expectEqual(PillarAxis.x, x_props.axis);
    try std.testing.expect(!x_props.axis.isVertical());
    try std.testing.expect(x_props.axis.isHorizontal());

    const z_props = BoneBlockProperties{ .axis = .z };
    try std.testing.expectEqual(PillarAxis.z, z_props.axis);
    try std.testing.expect(!z_props.axis.isVertical());
    try std.testing.expect(z_props.axis.isHorizontal());

    try std.testing.expectEqual([3]i8{ 1, 0, 0 }, PillarAxis.x.directionVector());
    try std.testing.expectEqual([3]i8{ 0, 1, 0 }, PillarAxis.y.directionVector());
    try std.testing.expectEqual([3]i8{ 0, 0, 1 }, PillarAxis.z.directionVector());
}

test "15. dropsWithoutPickaxe returns false: pickaxe is required to harvest bone blocks" {
    try std.testing.expectEqual(false, dropsWithoutPickaxe());
    try std.testing.expectEqual(false, BoneBlockProperties.dropsWithoutPickaxe());

    try std.testing.expect(BoneBlockProperties.requiresPickaxe());
    try std.testing.expect(BoneBlockProperties.dropsWhenMined(true));
    try std.testing.expect(!BoneBlockProperties.dropsWhenMined(false));
}

test "16. noteBlockInstrument produces xylophone sound when placed beneath Note Block" {
    try std.testing.expectEqual(NoteBlockInstrument.xylophone, noteBlockInstrument());
    try std.testing.expectEqual(NoteBlockInstrument.xylophone, BoneBlockProperties.noteBlockInstrument());

    const props = BoneBlockProperties{ .axis = .y };
    try std.testing.expectEqual(NoteBlockInstrument.xylophone, props.getInstrument());
}

test "17. sampleFossilBlock produces bone_block, coal_ore, deepslate_diamond_ore, and air" {
    // Roll < 0.90 -> bone_block intact
    const intact_shallow = sampleFossilBlock(45, 0.50, 0.05);
    try std.testing.expectEqual(PlacedFossilBlock.bone_block, intact_shallow);

    const intact_deep = sampleFossilBlock(-40, 0.89, 0.05);
    try std.testing.expectEqual(PlacedFossilBlock.bone_block, intact_deep);

    // Roll >= 0.90 (decay): ore_roll < 0.10 -> ore substitution
    // Shallow: coal_ore
    const decayed_shallow_ore = sampleFossilBlock(45, 0.95, 0.05);
    try std.testing.expectEqual(PlacedFossilBlock.coal_ore, decayed_shallow_ore);

    // Deep: deepslate_diamond_ore
    const decayed_deep_ore = sampleFossilBlock(-40, 0.95, 0.05);
    try std.testing.expectEqual(PlacedFossilBlock.deepslate_diamond_ore, decayed_deep_ore);

    // Roll >= 0.90 (decay): ore_roll >= 0.10 -> air
    const decayed_air = sampleFossilBlock(45, 0.95, 0.50);
    try std.testing.expectEqual(PlacedFossilBlock.air, decayed_air);
}

test "18. sampleFossilBlockAtCoord deterministically generates blocks from world coords and seed" {
    const seed: u64 = 123456789;
    const block1 = sampleFossilBlockAtCoord(seed, 10, 45, 20);
    const block2 = sampleFossilBlockAtCoord(seed, 10, 45, 20);
    try std.testing.expectEqual(block1, block2);

    // Sampling across a range of coordinates in deep layer verifies deepslate_diamond_ore can generate
    var found_diamond = false;
    var found_bone = false;
    var found_air = false;

    var x: i32 = -50;
    while (x <= 50) : (x += 1) {
        var z: i32 = -50;
        while (z <= 50) : (z += 1) {
            const blk = sampleFossilBlockAtCoord(seed, x, -30, z);
            switch (blk) {
                .bone_block => found_bone = true,
                .deepslate_diamond_ore => found_diamond = true,
                .air => found_air = true,
                .coal_ore => unreachable, // Coal ore should never generate in negative Y deepslate!
            }
            if (found_diamond and found_bone and found_air) break;
        }
        if (found_diamond and found_bone and found_air) break;
    }

    try std.testing.expect(found_bone);
    try std.testing.expect(found_diamond);
    try std.testing.expect(found_air);
}
