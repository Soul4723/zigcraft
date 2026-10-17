const std = @import("std");

// ============================================================================
// 1. Igneous Rock Variants & Enums
// ============================================================================

/// Igneous stone kinds representing naturally generating Overworld intrusive rocks
/// and their refined, polished architectural counterparts.
pub const IgneousStoneKind = enum(u8) {
    granite = 0,
    diorite = 1,
    andesite = 2,
    polished_granite = 3,
    polished_diorite = 4,
    polished_andesite = 5,

    /// Whether this block kind is a polished variant.
    pub fn isPolished(self: IgneousStoneKind) bool {
        return switch (self) {
            .polished_granite, .polished_diorite, .polished_andesite => true,
            .granite, .diorite, .andesite => false,
        };
    }

    /// Resolves the base unpolished igneous rock type.
    pub fn baseKind(self: IgneousStoneKind) IgneousStoneKind {
        return switch (self) {
            .granite, .polished_granite => .granite,
            .diorite, .polished_diorite => .diorite,
            .andesite, .polished_andesite => .andesite,
        };
    }

    /// Converts raw igneous rock to its polished variant (or identity if already polished).
    pub fn toPolished(self: IgneousStoneKind) IgneousStoneKind {
        return switch (self) {
            .granite => .polished_granite,
            .diorite => .polished_diorite,
            .andesite => .polished_andesite,
            .polished_granite, .polished_diorite, .polished_andesite => self,
        };
    }

    /// Converts polished igneous rock to its raw variant (or identity if already raw).
    pub fn toRaw(self: IgneousStoneKind) IgneousStoneKind {
        return switch (self) {
            .granite, .polished_granite => .granite,
            .diorite, .polished_diorite => .diorite,
            .andesite, .polished_andesite => .andesite,
        };
    }

    /// Primary visual color and texture description.
    pub fn visualDescription(self: IgneousStoneKind) []const u8 {
        return switch (self) {
            .granite => "pinkish-red",
            .diorite => "speckled white",
            .andesite => "speckled gray",
            .polished_granite => "smooth pinkish-red",
            .polished_diorite => "smooth speckled white",
            .polished_andesite => "smooth speckled gray",
        };
    }

    /// Approximate normalized RGB palette representation for rendering and HUD.
    pub fn colorRgb(self: IgneousStoneKind) [3]f32 {
        return switch (self) {
            .granite => .{ 0.59, 0.39, 0.32 }, // pinkish-red
            .diorite => .{ 0.78, 0.78, 0.78 }, // speckled white
            .andesite => .{ 0.53, 0.53, 0.53 }, // speckled gray
            .polished_granite => .{ 0.61, 0.42, 0.35 },
            .polished_diorite => .{ 0.82, 0.82, 0.82 },
            .polished_andesite => .{ 0.56, 0.56, 0.56 },
        };
    }

    /// Standard block hardness in Minecraft (1.5 for all igneous stone variants).
    pub fn hardness(self: IgneousStoneKind) f32 {
        _ = self;
        return 1.5;
    }

    /// Standard blast resistance (6.0 for all igneous stone variants).
    pub fn blastResistance(self: IgneousStoneKind) f32 {
        _ = self;
        return 6.0;
    }

    /// Igneous stone drops itself when mined with any tier pickaxe (wooden or better),
    /// and drops nothing if broken without a pickaxe.
    pub fn dropsWhenMined(self: IgneousStoneKind, used_pickaxe: bool) bool {
        _ = self;
        return used_pickaxe;
    }

    /// Whether this block has an architectural cobblestone-style wall variant.
    /// Only raw blocks have wall variants; polished blocks do not.
    pub fn hasWall(self: IgneousStoneKind) bool {
        return hasWallVariant(self.isPolished());
    }

    /// Whether this rock type acts as the host matrix for giant copper ore veins.
    pub fn isCopperVeinHost(self: IgneousStoneKind) bool {
        return isCopperVeinHostRock(self);
    }
};

// ============================================================================
// 2. Nether Quartz Mineral Synthesis Recipes
// ============================================================================

pub const QuartzMineralSynthesis = struct {
    /// Item ingredient identifiers used in mineral synthesis recipes.
    pub const SynthesisIngredient = enum {
        cobblestone,
        nether_quartz,
        diorite,
        granite,
        andesite,
    };

    /// 2 cobblestone + 2 nether_quartz in a checkerboard 2x2 pattern -> 2 diorite.
    /// Each full batch consumes 2 cobblestone and 2 quartz to produce 2 diorite.
    pub fn craftDioriteFromQuartz(cobblestone: u16, nether_quartz: u16) u16 {
        const batches = @min(cobblestone / 2, nether_quartz / 2);
        return batches * 2;
    }

    /// 1 diorite + 1 nether_quartz -> 1 granite.
    /// Each full batch consumes 1 diorite and 1 nether quartz to produce 1 granite.
    pub fn craftGraniteFromDiorite(diorite: u16, nether_quartz: u16) u16 {
        const batches = @min(diorite, nether_quartz);
        return batches;
    }

    /// 1 diorite + 1 cobblestone -> 2 andesite.
    /// Each full batch consumes 1 diorite and 1 cobblestone to produce 2 andesite.
    pub fn craftAndesiteFromDiorite(diorite: u16, cobblestone: u16) u16 {
        const batches = @min(diorite, cobblestone);
        return batches * 2;
    }

    pub const CraftingResult = struct {
        crafted: u16,
        remaining_first: u16,
        remaining_second: u16,
    };

    /// Diorite crafting with ingredient residue tracking.
    pub fn craftDioriteWithRemainder(cobblestone: u16, nether_quartz: u16) CraftingResult {
        const batches = @min(cobblestone / 2, nether_quartz / 2);
        return .{
            .crafted = batches * 2,
            .remaining_first = cobblestone - (batches * 2),
            .remaining_second = nether_quartz - (batches * 2),
        };
    }

    /// Granite crafting with ingredient residue tracking.
    pub fn craftGraniteWithRemainder(diorite: u16, nether_quartz: u16) CraftingResult {
        const batches = @min(diorite, nether_quartz);
        return .{
            .crafted = batches,
            .remaining_first = diorite - batches,
            .remaining_second = nether_quartz - batches,
        };
    }

    /// Andesite crafting with ingredient residue tracking.
    pub fn craftAndesiteWithRemainder(diorite: u16, cobblestone: u16) CraftingResult {
        const batches = @min(diorite, cobblestone);
        return .{
            .crafted = batches * 2,
            .remaining_first = diorite - batches,
            .remaining_second = cobblestone - batches,
        };
    }

    /// Validates a 2x2 crafting grid for diorite checkerboard synthesis.
    /// In Minecraft, the checkerboard layout requires:
    /// [Cobblestone, Nether Quartz]
    /// [Nether Quartz, Cobblestone]
    /// OR
    /// [Nether Quartz, Cobblestone]
    /// [Cobblestone, Nether Quartz]
    pub fn isValidDioriteCheckerboard(grid: [2][2]?SynthesisIngredient) bool {
        const c = SynthesisIngredient.cobblestone;
        const q = SynthesisIngredient.nether_quartz;

        const pattern_a = (grid[0][0] == c and grid[0][1] == q and
            grid[1][0] == q and grid[1][1] == c);
        const pattern_b = (grid[0][0] == q and grid[0][1] == c and
            grid[1][0] == c and grid[1][1] == q);

        return pattern_a or pattern_b;
    }

    /// Validates shapeless 2-ingredient recipe for granite (1 diorite + 1 nether quartz).
    pub fn isValidGraniteRecipe(slot_a: SynthesisIngredient, slot_b: SynthesisIngredient) bool {
        return (slot_a == .diorite and slot_b == .nether_quartz) or
            (slot_a == .nether_quartz and slot_b == .diorite);
    }

    /// Validates shapeless 2-ingredient recipe for andesite (1 diorite + 1 cobblestone).
    pub fn isValidAndesiteRecipe(slot_a: SynthesisIngredient, slot_b: SynthesisIngredient) bool {
        return (slot_a == .diorite and slot_b == .cobblestone) or
            (slot_a == .cobblestone and slot_b == .diorite);
    }
};

/// Exported module-level synthesis helper functions.
pub const craftDioriteFromQuartz = QuartzMineralSynthesis.craftDioriteFromQuartz;
pub const craftGraniteFromDiorite = QuartzMineralSynthesis.craftGraniteFromDiorite;
pub const craftAndesiteFromDiorite = QuartzMineralSynthesis.craftAndesiteFromDiorite;

// ============================================================================
// 3. Polished Masonry & Stonecutter Yields
// ============================================================================

pub const PolishedMasonry = struct {
    pub const crafting_table_input_batch: u16 = 4;
    pub const crafting_table_output_batch: u16 = 4;

    /// 4 raw igneous blocks arranged in a 2x2 grid produce 4 polished blocks (1:1 yield).
    pub fn craftPolishedFromRaw(raw_count: u16) u16 {
        const batches = raw_count / crafting_table_input_batch;
        return batches * crafting_table_output_batch;
    }

    pub const CraftPolishedResult = struct {
        polished_crafted: u16,
        raw_remaining: u16,
    };

    pub fn craftPolishedWithRemainder(raw_count: u16) CraftPolishedResult {
        const batches = raw_count / crafting_table_input_batch;
        const crafted = batches * crafting_table_output_batch;
        return .{
            .polished_crafted = crafted,
            .raw_remaining = raw_count - (batches * crafting_table_input_batch),
        };
    }

    /// Architectural wall availability rule:
    /// Only raw blocks cut into walls; polished blocks do not have walls (`!is_polished`).
    pub fn hasWallVariant(is_polished: bool) bool {
        return !is_polished;
    }

    /// Distinct cut profiles supported by the Stonecutter workstation.
    pub const StonecutterCut = enum {
        polished_block,
        slab,
        stairs,
        wall,
    };

    /// Checks if a stonecutter cut operation is valid for the given rock polish state.
    pub fn canCut(cut: PolishedMasonry.StonecutterCut, is_polished: bool) bool {
        return switch (cut) {
            // Raw blocks can be cut into polished blocks; already polished blocks cannot be re-polished.
            .polished_block => !is_polished,
            // Slabs and stairs exist for both raw and polished variants.
            .slab, .stairs => true,
            // Walls exist exclusively for raw variants.
            .wall => PolishedMasonry.hasWallVariant(is_polished),
        };
    }

    /// Output count for 1 input block in a Stonecutter workstation:
    /// - 1 polished block (raw input only)
    /// - 2 slabs (raw or polished input)
    /// - 1 stair (raw or polished input)
    /// - 1 wall (raw input only; returns 0 for polished input)
    pub fn stonecutterYield(cut: PolishedMasonry.StonecutterCut, is_polished: bool) u8 {
        if (!PolishedMasonry.canCut(cut, is_polished)) return 0;
        return switch (cut) {
            .polished_block => 1,
            .slab => 2,
            .stairs => 1,
            .wall => 1,
        };
    }

    /// Theoretical base cut yield per block if supported.
    pub fn cutYield(cut: PolishedMasonry.StonecutterCut) u8 {
        return switch (cut) {
            .polished_block => 1,
            .slab => 2,
            .stairs => 1,
            .wall => 1,
        };
    }

    /// Crafting-table stair recipe constants for comparison.
    pub const crafting_table_stair_input: u8 = 6;
    pub const crafting_table_stair_output: u8 = 4;

    /// Stonecutter stair material savings percentage vs Crafting Table.
    /// Crafting table: 6 input / 4 stairs = 1.5 blocks/stair.
    /// Stonecutter: 1 input / 1 stair = 1.0 block/stair.
    /// Material savings = (1.5 - 1.0) / 1.5 = 1/3 ≈ 33.333% savings.
    pub fn stairStonecutterMaterialSavings() f32 {
        const ct_ratio = @as(f32, @floatFromInt(crafting_table_stair_input)) /
            @as(f32, @floatFromInt(crafting_table_stair_output));
        const sc_ratio: f32 = 1.0;
        return (ct_ratio - sc_ratio) / ct_ratio;
    }
};

/// Exported module-level masonry helper functions.
pub const hasWallVariant = PolishedMasonry.hasWallVariant;
pub const craftPolishedFromRaw = PolishedMasonry.craftPolishedFromRaw;
pub const StonecutterCut = PolishedMasonry.StonecutterCut;
pub const stonecutterYield = PolishedMasonry.stonecutterYield;

// ============================================================================
// 4. Subterranean Blob Generation & Ore Vein Rules
// ============================================================================

pub const SubterraneanBlobGeneration = struct {
    /// Upper stone band altitude boundaries where Granite, Diorite, and Andesite
    /// generate abundantly in the Overworld stone crust.
    pub const upper_band_min_y: i32 = 0;
    pub const upper_band_max_y: i32 = 60;

    /// Evaluates if an altitude coordinate falls within the upper stone band y = 0..60.
    pub fn isInUpperBand(y: i32) bool {
        return y >= SubterraneanBlobGeneration.upper_band_min_y and y <= SubterraneanBlobGeneration.upper_band_max_y;
    }

    /// Host rock validation for giant ore veins:
    /// Giant copper ore veins generate exclusively inside Granite host rock.
    pub fn isCopperVeinHostRock(rock: IgneousStoneKind) bool {
        return rock == .granite;
    }

    /// Giant iron ore veins generate inside Tuff host rock (not granite/diorite/andesite).
    pub fn isIronVeinHostRock(rock: IgneousStoneKind) bool {
        _ = rock;
        return false;
    }

    /// Rare giant ore vein classification.
    pub const OreVeinKind = enum {
        copper_granite,
        iron_tuff,

        pub fn minAltitude(self: OreVeinKind) i32 {
            return switch (self) {
                .copper_granite => 0,
                .iron_tuff => -60,
            };
        }

        pub fn maxAltitude(self: OreVeinKind) i32 {
            return switch (self) {
                .copper_granite => 50,
                .iron_tuff => -8,
            };
        }

        pub fn hostRockName(self: OreVeinKind) []const u8 {
            return switch (self) {
                .copper_granite => "granite",
                .iron_tuff => "tuff",
            };
        }

        pub fn rawOreBlockName(self: OreVeinKind) []const u8 {
            return switch (self) {
                .copper_granite => "raw_copper_block",
                .iron_tuff => "raw_iron_block",
            };
        }
    };

    /// 64-bit coordinate hash for deterministic procedural distribution.
    pub fn hashCoords(seed: u64, x: i32, y: i32, z: i32) u64 {
        var h: u64 = seed ^ 0x517cc1b727220a95;
        h = (h ^ @as(u64, @bitCast(@as(i64, x)))) *% 0x9e3779b97f4a7c15;
        h = (h ^ @as(u64, @bitCast(@as(i64, y)))) *% 0xbf58476d1ce4e5b9;
        h = (h ^ @as(u64, @bitCast(@as(i64, z)))) *% 0x94d049bb133111eb;
        h ^= (h >> 32);
        return h;
    }

    /// Samples subterranean igneous rock blobs within the upper band y = 0..60.
    /// Returns the raw igneous rock variant if a blob center intersects the block,
    /// or null if regular stone should be retained.
    pub fn sampleIgneousBlob(seed: u64, x: i32, y: i32, z: i32) ?IgneousStoneKind {
        if (!SubterraneanBlobGeneration.isInUpperBand(y)) return null;

        const cell_x = @divFloor(x, 16);
        const cell_y = @divFloor(y, 16);
        const cell_z = @divFloor(z, 16);
        const h = hashCoords(seed, cell_x, cell_y, cell_z);

        // Approximately 25% of 16x16x16 sub-volumes contain an igneous blob
        if ((h & 0xFF) >= 64) return null;

        // Choose between granite, diorite, and andesite
        const kind_val = (h >> 8) % 3;
        return switch (kind_val) {
            0 => .granite,
            1 => .diorite,
            else => .andesite,
        };
    }
};

/// Exported module-level world generation helper functions.
pub const upper_band_min_y = SubterraneanBlobGeneration.upper_band_min_y;
pub const upper_band_max_y = SubterraneanBlobGeneration.upper_band_max_y;
pub const isInUpperBand = SubterraneanBlobGeneration.isInUpperBand;
pub const isCopperVeinHostRock = SubterraneanBlobGeneration.isCopperVeinHostRock;

// ============================================================================
// 5. Comprehensive Test Suite (16 Test Blocks)
// ============================================================================

test "1. igneous stone kind variants, properties and color representations" {
    const raw_variants = [_]IgneousStoneKind{ .granite, .diorite, .andesite };
    for (raw_variants) |rock| {
        try std.testing.expect(!rock.isPolished());
        try std.testing.expectEqual(@as(f32, 1.5), rock.hardness());
        try std.testing.expectEqual(@as(f32, 6.0), rock.blastResistance());
        try std.testing.expect(rock.dropsWhenMined(true));
        try std.testing.expect(!rock.dropsWhenMined(false));
    }

    try std.testing.expectEqualStrings("pinkish-red", IgneousStoneKind.granite.visualDescription());
    try std.testing.expectEqualStrings("speckled white", IgneousStoneKind.diorite.visualDescription());
    try std.testing.expectEqualStrings("speckled gray", IgneousStoneKind.andesite.visualDescription());

    // Check RGB color channels are normalized in [0, 1]
    const all_kinds = [_]IgneousStoneKind{
        .granite,          .diorite,          .andesite,
        .polished_granite, .polished_diorite, .polished_andesite,
    };
    for (all_kinds) |k| {
        const rgb = k.colorRgb();
        for (rgb) |ch| {
            try std.testing.expect(ch >= 0.0 and ch <= 1.0);
        }
    }
}

test "2. igneous stone kind conversions between raw and polished" {
    try std.testing.expectEqual(IgneousStoneKind.polished_granite, IgneousStoneKind.granite.toPolished());
    try std.testing.expectEqual(IgneousStoneKind.polished_diorite, IgneousStoneKind.diorite.toPolished());
    try std.testing.expectEqual(IgneousStoneKind.polished_andesite, IgneousStoneKind.andesite.toPolished());

    try std.testing.expectEqual(IgneousStoneKind.granite, IgneousStoneKind.polished_granite.toRaw());
    try std.testing.expectEqual(IgneousStoneKind.diorite, IgneousStoneKind.polished_diorite.toRaw());
    try std.testing.expectEqual(IgneousStoneKind.andesite, IgneousStoneKind.polished_andesite.toRaw());

    try std.testing.expect(IgneousStoneKind.polished_granite.isPolished());
    try std.testing.expect(IgneousStoneKind.polished_diorite.isPolished());
    try std.testing.expect(IgneousStoneKind.polished_andesite.isPolished());

    try std.testing.expectEqual(IgneousStoneKind.granite, IgneousStoneKind.polished_granite.baseKind());
    try std.testing.expectEqual(IgneousStoneKind.diorite, IgneousStoneKind.polished_diorite.baseKind());
    try std.testing.expectEqual(IgneousStoneKind.andesite, IgneousStoneKind.polished_andesite.baseKind());
}

test "3. quartz mineral synthesis - diorite checkerboard crafting yields" {
    // 2 cobblestone + 2 quartz -> 2 diorite
    try std.testing.expectEqual(@as(u16, 2), craftDioriteFromQuartz(2, 2));

    // Even scaling: 6 cobblestone + 6 quartz -> 6 diorite
    try std.testing.expectEqual(@as(u16, 6), craftDioriteFromQuartz(6, 6));

    // Uneven inputs: 4 cobblestone + 5 quartz -> 4 diorite (2 batches)
    try std.testing.expectEqual(@as(u16, 4), craftDioriteFromQuartz(4, 5));
    try std.testing.expectEqual(@as(u16, 4), craftDioriteFromQuartz(7, 4));

    // Insufficient ingredients
    try std.testing.expectEqual(@as(u16, 0), craftDioriteFromQuartz(1, 10));
    try std.testing.expectEqual(@as(u16, 0), craftDioriteFromQuartz(10, 1));
    try std.testing.expectEqual(@as(u16, 0), craftDioriteFromQuartz(0, 0));

    // Stack batching (64 cobble + 64 quartz -> 64 diorite)
    try std.testing.expectEqual(@as(u16, 64), craftDioriteFromQuartz(64, 64));
}

test "4. quartz mineral synthesis - diorite checkerboard grid validation" {
    const c = QuartzMineralSynthesis.SynthesisIngredient.cobblestone;
    const q = QuartzMineralSynthesis.SynthesisIngredient.nether_quartz;
    const d = QuartzMineralSynthesis.SynthesisIngredient.diorite;

    // Pattern A: [c, q] / [q, c]
    const grid_a: [2][2]?QuartzMineralSynthesis.SynthesisIngredient = .{
        .{ c, q },
        .{ q, c },
    };
    try std.testing.expect(QuartzMineralSynthesis.isValidDioriteCheckerboard(grid_a));

    // Pattern B: [q, c] / [c, q]
    const grid_b: [2][2]?QuartzMineralSynthesis.SynthesisIngredient = .{
        .{ q, c },
        .{ c, q },
    };
    try std.testing.expect(QuartzMineralSynthesis.isValidDioriteCheckerboard(grid_b));

    // Invalid non-checkerboard patterns
    const grid_all_c: [2][2]?QuartzMineralSynthesis.SynthesisIngredient = .{
        .{ c, c },
        .{ c, c },
    };
    try std.testing.expect(!QuartzMineralSynthesis.isValidDioriteCheckerboard(grid_all_c));

    const grid_wrong_item: [2][2]?QuartzMineralSynthesis.SynthesisIngredient = .{
        .{ c, q },
        .{ d, c },
    };
    try std.testing.expect(!QuartzMineralSynthesis.isValidDioriteCheckerboard(grid_wrong_item));

    const grid_incomplete: [2][2]?QuartzMineralSynthesis.SynthesisIngredient = .{
        .{ c, q },
        .{ q, null },
    };
    try std.testing.expect(!QuartzMineralSynthesis.isValidDioriteCheckerboard(grid_incomplete));
}

test "5. quartz mineral synthesis - granite crafting yields and shapeless recipe" {
    // 1 diorite + 1 quartz -> 1 granite
    try std.testing.expectEqual(@as(u16, 1), craftGraniteFromDiorite(1, 1));
    try std.testing.expectEqual(@as(u16, 10), craftGraniteFromDiorite(10, 15));
    try std.testing.expectEqual(@as(u16, 8), craftGraniteFromDiorite(12, 8));
    try std.testing.expectEqual(@as(u16, 0), craftGraniteFromDiorite(0, 10));
    try std.testing.expectEqual(@as(u16, 0), craftGraniteFromDiorite(10, 0));

    // Shapeless verification
    try std.testing.expect(QuartzMineralSynthesis.isValidGraniteRecipe(.diorite, .nether_quartz));
    try std.testing.expect(QuartzMineralSynthesis.isValidGraniteRecipe(.nether_quartz, .diorite));
    try std.testing.expect(!QuartzMineralSynthesis.isValidGraniteRecipe(.diorite, .cobblestone));
}

test "6. quartz mineral synthesis - andesite crafting yields and shapeless recipe" {
    // 1 diorite + 1 cobblestone -> 2 andesite
    try std.testing.expectEqual(@as(u16, 2), craftAndesiteFromDiorite(1, 1));
    try std.testing.expectEqual(@as(u16, 6), craftAndesiteFromDiorite(3, 4));
    try std.testing.expectEqual(@as(u16, 8), craftAndesiteFromDiorite(5, 4));
    try std.testing.expectEqual(@as(u16, 0), craftAndesiteFromDiorite(0, 5));
    try std.testing.expectEqual(@as(u16, 0), craftAndesiteFromDiorite(5, 0));

    // Shapeless verification
    try std.testing.expect(QuartzMineralSynthesis.isValidAndesiteRecipe(.diorite, .cobblestone));
    try std.testing.expect(QuartzMineralSynthesis.isValidAndesiteRecipe(.cobblestone, .diorite));
    try std.testing.expect(!QuartzMineralSynthesis.isValidAndesiteRecipe(.diorite, .nether_quartz));
}

test "7. quartz mineral synthesis - remainder tracking and conservation" {
    const res_d = QuartzMineralSynthesis.craftDioriteWithRemainder(7, 5);
    try std.testing.expectEqual(@as(u16, 4), res_d.crafted); // 2 batches
    try std.testing.expectEqual(@as(u16, 3), res_d.remaining_first); // 7 - 4 = 3
    try std.testing.expectEqual(@as(u16, 1), res_d.remaining_second); // 5 - 4 = 1

    const res_g = QuartzMineralSynthesis.craftGraniteWithRemainder(10, 6);
    try std.testing.expectEqual(@as(u16, 6), res_g.crafted);
    try std.testing.expectEqual(@as(u16, 4), res_g.remaining_first);
    try std.testing.expectEqual(@as(u16, 0), res_g.remaining_second);

    const res_a = QuartzMineralSynthesis.craftAndesiteWithRemainder(4, 7);
    try std.testing.expectEqual(@as(u16, 8), res_a.crafted); // 4 * 2 = 8
    try std.testing.expectEqual(@as(u16, 0), res_a.remaining_first);
    try std.testing.expectEqual(@as(u16, 3), res_a.remaining_second);
}

test "8. complete mineral synthesis loop from quartz and cobblestone" {
    // Start with 10 cobblestone and 10 nether quartz
    const diorite_crafted = craftDioriteFromQuartz(10, 10);
    try std.testing.expectEqual(@as(u16, 10), diorite_crafted);

    // Split 10 diorite: 4 for granite, 6 for andesite
    // 4 diorite + 4 nether quartz -> 4 granite
    const granite_crafted = craftGraniteFromDiorite(4, 4);
    try std.testing.expectEqual(@as(u16, 4), granite_crafted);

    // 6 diorite + 6 cobblestone -> 12 andesite
    const andesite_crafted = craftAndesiteFromDiorite(6, 6);
    try std.testing.expectEqual(@as(u16, 12), andesite_crafted);
}

test "9. polished masonry - 2x2 crafting table 1:1 yield" {
    // 4 raw blocks -> 4 polished blocks
    try std.testing.expectEqual(@as(u16, 4), craftPolishedFromRaw(4));
    try std.testing.expectEqual(@as(u16, 8), craftPolishedFromRaw(8));
    try std.testing.expectEqual(@as(u16, 4), craftPolishedFromRaw(7)); // remainder 3
    try std.testing.expectEqual(@as(u16, 0), craftPolishedFromRaw(3));
    try std.testing.expectEqual(@as(u16, 0), craftPolishedFromRaw(0));

    const rem = PolishedMasonry.craftPolishedWithRemainder(15);
    try std.testing.expectEqual(@as(u16, 12), rem.polished_crafted);
    try std.testing.expectEqual(@as(u16, 3), rem.raw_remaining);
}

test "10. stonecutter cut yields for raw igneous blocks" {
    const is_polished = false;

    // 1 raw block into 1 polished block
    try std.testing.expect(PolishedMasonry.canCut(.polished_block, is_polished));
    try std.testing.expectEqual(@as(u8, 1), stonecutterYield(.polished_block, is_polished));

    // 1 raw block into 2 slabs
    try std.testing.expect(PolishedMasonry.canCut(.slab, is_polished));
    try std.testing.expectEqual(@as(u8, 2), stonecutterYield(.slab, is_polished));

    // 1 raw block into 1 stair
    try std.testing.expect(PolishedMasonry.canCut(.stairs, is_polished));
    try std.testing.expectEqual(@as(u8, 1), stonecutterYield(.stairs, is_polished));

    // 1 raw block into 1 wall
    try std.testing.expect(PolishedMasonry.canCut(.wall, is_polished));
    try std.testing.expectEqual(@as(u8, 1), stonecutterYield(.wall, is_polished));
}

test "11. stonecutter cut yields for polished igneous blocks" {
    const is_polished = true;

    // Polished blocks cannot be cut into polished blocks (no circular operation)
    try std.testing.expect(!PolishedMasonry.canCut(.polished_block, is_polished));
    try std.testing.expectEqual(@as(u8, 0), stonecutterYield(.polished_block, is_polished));

    // 1 polished block into 2 polished slabs
    try std.testing.expect(PolishedMasonry.canCut(.slab, is_polished));
    try std.testing.expectEqual(@as(u8, 2), stonecutterYield(.slab, is_polished));

    // 1 polished block into 1 polished stair
    try std.testing.expect(PolishedMasonry.canCut(.stairs, is_polished));
    try std.testing.expectEqual(@as(u8, 1), stonecutterYield(.stairs, is_polished));

    // Polished blocks DO NOT have wall variants
    try std.testing.expect(!PolishedMasonry.canCut(.wall, is_polished));
    try std.testing.expectEqual(@as(u8, 0), stonecutterYield(.wall, is_polished));
}

test "12. wall variant exclusivity rule - raw vs polished" {
    // hasWallVariant(is_polished: bool) bool == !is_polished
    try std.testing.expectEqual(true, hasWallVariant(false));
    try std.testing.expectEqual(false, hasWallVariant(true));

    // Direct check on enum variants
    try std.testing.expect(IgneousStoneKind.granite.hasWall());
    try std.testing.expect(IgneousStoneKind.diorite.hasWall());
    try std.testing.expect(IgneousStoneKind.andesite.hasWall());

    try std.testing.expect(!IgneousStoneKind.polished_granite.hasWall());
    try std.testing.expect(!IgneousStoneKind.polished_diorite.hasWall());
    try std.testing.expect(!IgneousStoneKind.polished_andesite.hasWall());
}

test "13. stonecutter efficiency advantage over crafting table stairs" {
    try std.testing.expectEqual(@as(u8, 6), PolishedMasonry.crafting_table_stair_input);
    try std.testing.expectEqual(@as(u8, 4), PolishedMasonry.crafting_table_stair_output);

    // 33.333% material savings
    const savings = PolishedMasonry.stairStonecutterMaterialSavings();
    try std.testing.expectApproxEqAbs(@as(f32, 0.333333), savings, 0.001);
}

test "14. subterranean blob generation - upper band y boundaries" {
    try std.testing.expectEqual(@as(i32, 0), upper_band_min_y);
    try std.testing.expectEqual(@as(i32, 60), upper_band_max_y);

    // Boundaries and inside band
    try std.testing.expect(isInUpperBand(0));
    try std.testing.expect(isInUpperBand(30));
    try std.testing.expect(isInUpperBand(60));

    // Outside band
    try std.testing.expect(!isInUpperBand(-1));
    try std.testing.expect(!isInUpperBand(-64));
    try std.testing.expect(!isInUpperBand(61));
    try std.testing.expect(!isInUpperBand(256));
}

test "15. subterranean giant ore veins - copper-granite host rock matching" {
    // isCopperVeinHostRock(rock: IgneousStoneKind) bool -> rock == .granite
    try std.testing.expect(isCopperVeinHostRock(.granite));
    try std.testing.expect(!isCopperVeinHostRock(.diorite));
    try std.testing.expect(!isCopperVeinHostRock(.andesite));
    try std.testing.expect(!isCopperVeinHostRock(.polished_granite));
    try std.testing.expect(!isCopperVeinHostRock(.polished_diorite));
    try std.testing.expect(!isCopperVeinHostRock(.polished_andesite));

    // Enum method helper
    try std.testing.expect(IgneousStoneKind.granite.isCopperVeinHost());
    try std.testing.expect(!IgneousStoneKind.diorite.isCopperVeinHost());

    // Iron vein host rock (tuff) rejection for all igneous kinds
    try std.testing.expect(!SubterraneanBlobGeneration.isIronVeinHostRock(.granite));
    try std.testing.expect(!SubterraneanBlobGeneration.isIronVeinHostRock(.diorite));
    try std.testing.expect(!SubterraneanBlobGeneration.isIronVeinHostRock(.andesite));
}

test "16. subterranean blob sampling and ore vein properties" {
    const seed: u64 = 1337420;

    // Sampling outside upper band returns null
    try std.testing.expectEqual(@as(?IgneousStoneKind, null), SubterraneanBlobGeneration.sampleIgneousBlob(seed, 100, -10, 200));
    try std.testing.expectEqual(@as(?IgneousStoneKind, null), SubterraneanBlobGeneration.sampleIgneousBlob(seed, 100, 70, 200));

    // Ore vein altitude profiles
    const copper_vein = SubterraneanBlobGeneration.OreVeinKind.copper_granite;
    try std.testing.expectEqual(@as(i32, 0), copper_vein.minAltitude());
    try std.testing.expectEqual(@as(i32, 50), copper_vein.maxAltitude());
    try std.testing.expectEqualStrings("granite", copper_vein.hostRockName());
    try std.testing.expectEqualStrings("raw_copper_block", copper_vein.rawOreBlockName());

    const iron_vein = SubterraneanBlobGeneration.OreVeinKind.iron_tuff;
    try std.testing.expectEqual(@as(i32, -60), iron_vein.minAltitude());
    try std.testing.expectEqual(@as(i32, -8), iron_vein.maxAltitude());
    try std.testing.expectEqualStrings("tuff", iron_vein.hostRockName());
    try std.testing.expectEqualStrings("raw_iron_block", iron_vein.rawOreBlockName());
}
