const std = @import("std");

/// Nether biomes introduced in the Nether Update (1.16).
pub const NetherBiome = enum {
    nether_wastes,
    crimson_forest,
    warped_forest,
    soul_sand_valley,
    basalt_deltas,

    pub fn name(self: NetherBiome) []const u8 {
        return switch (self) {
            .nether_wastes => "Nether Wastes",
            .crimson_forest => "Crimson Forest",
            .warped_forest => "Warped Forest",
            .soul_sand_valley => "Soul Sand Valley",
            .basalt_deltas => "Basalt Deltas",
        };
    }

    pub fn isForest(self: NetherBiome) bool {
        return self == .crimson_forest or self == .warped_forest;
    }

    pub fn hasSoulFire(self: NetherBiome) bool {
        return self == .soul_sand_valley;
    }

    /// Environmental ambient fog color in RGB [0.0, 1.0].
    pub fn fogColor(self: NetherBiome) [3]f32 {
        return switch (self) {
            .nether_wastes => .{ 0.20, 0.03, 0.03 }, // Classic crimson dark fog
            .crimson_forest => .{ 0.20, 0.01, 0.01 }, // Deep ruby red fog
            .warped_forest => .{ 0.10, 0.03, 0.16 }, // Deep indigo/violet fog
            .soul_sand_valley => .{ 0.11, 0.15, 0.20 }, // Eerie cyan-tinted gloomy fog
            .basalt_deltas => .{ 0.41, 0.37, 0.44 }, // Heavy grey ash fog
        };
    }

    /// Primary particle type floating through the air.
    pub fn ambientParticle(self: NetherBiome) AmbientParticleKind {
        return switch (self) {
            .nether_wastes => .none,
            .crimson_forest => .crimson_spore,
            .warped_forest => .warped_spore,
            .soul_sand_valley => .ash,
            .basalt_deltas => .white_ash,
        };
    }
};

pub const AmbientParticleKind = enum {
    none,
    crimson_spore,
    warped_spore,
    ash,
    white_ash,
};

/// Nether block identifiers.
pub const NetherBlock = enum(u16) {
    air = 0,
    netherrack = 4,
    soul_sand = 62,
    basalt = 64,
    crimson_fungus = 71,
    warped_fungus = 72,
    shroomlight = 73,
    weeping_vines = 74,
    twisting_vines = 75,
    soul_soil = 76,
    crimson_nylium = 77,
    warped_nylium = 78,
    crimson_stem = 79,
    warped_stem = 80,
    crimson_hyphae = 81,
    warped_hyphae = 82,
    nether_wart_block = 83,
    warped_wart_block = 84,
    smooth_basalt = 85,
    polished_basalt = 86,
    bone_block = 87,
    blue_ice = 88,
    flowing_lava = 89,
    still_lava = 90,
    soul_fire = 91,
    fire = 92,
    blackstone = 93,
    magma_block = 94,
    crimson_roots = 95,
    warped_roots = 96,
    nether_sprouts = 97,

    pub fn isSolidOpaque(self: NetherBlock) bool {
        return switch (self) {
            .air,
            .crimson_fungus,
            .warped_fungus,
            .weeping_vines,
            .twisting_vines,
            .flowing_lava,
            .still_lava,
            .soul_fire,
            .fire,
            .crimson_roots,
            .warped_roots,
            .nether_sprouts,
            => false,
            else => true,
        };
    }
};

/// Wood from Huge Fungi (Crimson and Warped Stems/Hyphae) is completely fireproof.
pub fn isFireproofWood(block: NetherBlock) bool {
    return switch (block) {
        .crimson_stem,
        .warped_stem,
        .crimson_hyphae,
        .warped_hyphae,
        => true,
        else => false,
    };
}

/// Fungus varieties that grow into giant tree-like fungi in the Nether.
pub const FungusType = enum {
    crimson,
    warped,

    pub fn requiredSubstrate(self: FungusType) NetherBlock {
        return switch (self) {
            .crimson => .crimson_nylium,
            .warped => .warped_nylium,
        };
    }

    pub fn stemBlock(self: FungusType) NetherBlock {
        return switch (self) {
            .crimson => .crimson_stem,
            .warped => .warped_stem,
        };
    }

    pub fn capBlock(self: FungusType) NetherBlock {
        return switch (self) {
            .crimson => .nether_wart_block,
            .warped => .warped_wart_block,
        };
    }

    pub fn vineBlock(self: FungusType) NetherBlock {
        return switch (self) {
            .crimson => .weeping_vines,
            .warped => .twisting_vines,
        };
    }

    pub fn vineDirection(self: FungusType) VineDirection {
        return switch (self) {
            .crimson => .downward,
            .warped => .upward,
        };
    }

    pub fn isFireproofWood(self: FungusType) bool {
        _ = self;
        return true;
    }
};

pub const VineDirection = enum {
    downward,
    upward,
};

/// Huge fungus growth simulation and verification.
pub const HugeFungusGrowth = struct {
    fungus_type: FungusType,
    stem_height: u8,
    shroomlight_count: u8,
    shroomlight_light_level: u8 = 15,
    vines_count: u8,
    vines_direction: VineDirection,

    pub const min_height: u8 = 4;
    pub const max_height: u8 = 13;
    pub const shroomlight_emission_level: u8 = 15;

    /// Fireproof wood property helper: Huge fungus wood stems cannot burn.
    pub fn isFireproofWood() bool {
        return true;
    }

    /// Crimson fungus grows only on crimson_nylium when bone-mealed;
    /// Warped fungus grows only on warped_nylium when bone-mealed.
    pub fn canGrow(fungus: FungusType, substrate: NetherBlock, has_bone_meal: bool) bool {
        if (!has_bone_meal) return false;
        return switch (fungus) {
            .crimson => substrate == .crimson_nylium,
            .warped => substrate == .warped_nylium,
        };
    }

    /// Block-based canGrow helper.
    pub fn canGrowFromBlock(fungus_block: NetherBlock, substrate: NetherBlock, has_bone_meal: bool) bool {
        if (!has_bone_meal) return false;
        return switch (fungus_block) {
            .crimson_fungus => substrate == .crimson_nylium,
            .warped_fungus => substrate == .warped_nylium,
            else => false,
        };
    }

    /// Simulates deterministic growth from bone meal.
    pub fn attemptGrowth(
        fungus: FungusType,
        substrate: NetherBlock,
        has_bone_meal: bool,
        seed: u32,
    ) ?HugeFungusGrowth {
        if (!canGrow(fungus, substrate, has_bone_meal)) return null;

        const height_offset: u8 = @intCast(seed % (max_height - min_height + 1));
        const height: u8 = min_height + height_offset;
        const shroomlights: u8 = @intCast(1 + ((seed >> 8) % 4)); // 1 to 4 shroomlight blocks
        const vines: u8 = @intCast(2 + ((seed >> 16) % 5)); // 2 to 6 vines

        return HugeFungusGrowth{
            .fungus_type = fungus,
            .stem_height = height,
            .shroomlight_count = shroomlights,
            .shroomlight_light_level = shroomlight_emission_level,
            .vines_count = vines,
            .vines_direction = fungus.vineDirection(),
        };
    }
};

/// Nylium spreading and decay rules.
pub const NyliumSpread = struct {
    /// Bone meal applied on netherrack converts it to nylium if adjacent to matching nylium.
    pub fn convertNetherrack(
        target_block: NetherBlock,
        has_bone_meal: bool,
        adjacent_is_crimson_nylium: bool,
        adjacent_is_warped_nylium: bool,
    ) ?NetherBlock {
        if (!has_bone_meal) return null;
        if (target_block != .netherrack) return null;

        if (adjacent_is_crimson_nylium and !adjacent_is_warped_nylium) {
            return .crimson_nylium;
        } else if (adjacent_is_warped_nylium and !adjacent_is_crimson_nylium) {
            return .warped_nylium;
        } else if (adjacent_is_crimson_nylium and adjacent_is_warped_nylium) {
            // When touching both, crimson takes priority deterministically
            return .crimson_nylium;
        }
        return null;
    }

    /// Bone meal applied on netherrack with explicit preferred variant.
    pub fn convertNetherrackPreferred(
        target_block: NetherBlock,
        has_bone_meal: bool,
        adjacent_is_crimson: bool,
        adjacent_is_warped: bool,
        preferred_is_warped: bool,
    ) ?NetherBlock {
        if (!has_bone_meal) return null;
        if (target_block != .netherrack) return null;

        if (adjacent_is_crimson and adjacent_is_warped) {
            return if (preferred_is_warped) .warped_nylium else .crimson_nylium;
        }
        if (adjacent_is_crimson) return .crimson_nylium;
        if (adjacent_is_warped) return .warped_nylium;
        return null;
    }

    /// A solid opaque block directly above nylium decays it back to netherrack.
    pub fn shouldDecay(block_above: NetherBlock) bool {
        return block_above.isSolidOpaque();
    }

    /// Evaluates nylium decay under block_above.
    pub fn tickNylium(current: NetherBlock, block_above: NetherBlock) NetherBlock {
        if (current != .crimson_nylium and current != .warped_nylium) {
            return current;
        }
        if (shouldDecay(block_above)) {
            return .netherrack;
        }
        return current;
    }

    /// Evaluates nylium decay with an explicit boolean flag for solid opaque above.
    pub fn tickNyliumWithOpaqueFlag(current: NetherBlock, above_is_solid_opaque: bool) NetherBlock {
        if (current != .crimson_nylium and current != .warped_nylium) {
            return current;
        }
        if (above_is_solid_opaque) {
            return .netherrack;
        }
        return current;
    }
};

/// Basalt Generator physics and basalt crafting/smelting recipes.
pub const BasaltGenerator = struct {
    /// Flowing lava contacting soul soil below and blue ice adjacent crystallizes into basalt.
    pub fn canFormBasalt(
        has_flowing_lava: bool,
        below_is_soul_soil: bool,
        adjacent_is_blue_ice: bool,
    ) bool {
        return has_flowing_lava and below_is_soul_soil and adjacent_is_blue_ice;
    }

    /// Block-type based overload for canFormBasalt.
    pub fn canFormBasaltFromBlocks(
        lava_block: NetherBlock,
        below_block: NetherBlock,
        adjacent_block: NetherBlock,
    ) bool {
        const has_flowing = (lava_block == .flowing_lava);
        const below_soil = (below_block == .soul_soil);
        const adj_ice = (adjacent_block == .blue_ice);
        return BasaltGenerator.canFormBasalt(has_flowing, below_soil, adj_ice);
    }

    /// Smelting basalt in a furnace yields smooth_basalt.
    pub fn smeltBasalt(input: NetherBlock) ?NetherBlock {
        if (input == .basalt) {
            return .smooth_basalt;
        }
        return null;
    }

    pub const CraftingResult = struct {
        output_block: NetherBlock,
        output_count: u32,
        consumed_count: u32,
    };

    /// Crafting 4 basalt blocks in a 2x2 grid yields 4 polished_basalt blocks.
    pub fn craftPolishedBasalt(input: NetherBlock, input_count: u32) ?CraftingResult {
        if (input != .basalt or input_count < 4) return null;
        const batches = input_count / 4;
        return CraftingResult{
            .output_block = .polished_basalt,
            .output_count = batches * 4,
            .consumed_count = batches * 4,
        };
    }
};

/// Top-level canFormBasalt as requested in prompt.
pub fn canFormBasalt(
    has_flowing_lava: bool,
    below_is_soul_soil: bool,
    adjacent_is_blue_ice: bool,
) bool {
    return BasaltGenerator.canFormBasalt(
        has_flowing_lava,
        below_is_soul_soil,
        adjacent_is_blue_ice,
    );
}

/// Smelting helper at top-level.
pub fn smeltBasalt(input: NetherBlock) ?NetherBlock {
    return BasaltGenerator.smeltBasalt(input);
}

/// Crafting helper at top-level.
pub fn craftPolishedBasalt(input: NetherBlock, count: u32) ?BasaltGenerator.CraftingResult {
    return BasaltGenerator.craftPolishedBasalt(input, count);
}

/// Soul Sand Valley fossil structure representation and mob spawn parameters.
pub const SoulSandValleyFossil = struct {
    bone_blocks_count: u8,
    bone_meal_per_block: u8 = 3,
    variant: FossilVariant = .ribcage,

    pub const FossilVariant = enum {
        ribcage,
        spine,
        skull,
    };

    /// Calculates total bone meal yielded by breaking down all bone blocks in the fossil.
    pub fn totalBoneMealYield(self: SoulSandValleyFossil) u32 {
        return @as(u32, self.bone_blocks_count) * @as(u32, self.bone_meal_per_block);
    }

    /// Generates a ribcage fossil with a given number of rib pairs.
    pub fn generateRibcage(rib_pairs: u8) SoulSandValleyFossil {
        // Spine has 2 blocks per rib pair plus 1 terminal block;
        // Each rib arch has 3 blocks per side (6 per pair).
        const spine_count: u8 = rib_pairs * 2 + 1;
        const ribs_count: u8 = rib_pairs * 6;
        return SoulSandValleyFossil{
            .bone_blocks_count = spine_count + ribs_count,
            .bone_meal_per_block = 3,
            .variant = .ribcage,
        };
    }
};

/// Mob spawn weight configuration in Nether biomes.
pub const MobSpawnWeight = struct {
    mob_name: []const u8,
    weight: u32,
};

pub const SoulSandValleySpawns = struct {
    /// In Soul Sand Valley, Ghasts and Skeletons have unusually high spawn weights.
    pub const skeleton_weight: u32 = 300;
    pub const ghast_weight: u32 = 50;
    pub const enderman_weight: u32 = 1;

    pub fn isHighSpawnWeightSkeleton() bool {
        return skeleton_weight >= 100;
    }

    pub fn isHighSpawnWeightGhast() bool {
        return ghast_weight >= 50;
    }
};

/// Fire characteristics in the Nether.
pub const FireType = enum {
    none,
    normal_fire,
    soul_fire,

    pub fn lightLevel(self: FireType) u8 {
        return switch (self) {
            .none => 0,
            .soul_fire => 10,
            .normal_fire => 15,
        };
    }

    pub fn damagePerSecond(self: FireType) f32 {
        return switch (self) {
            .none => 0.0,
            .normal_fire => 1.0,
            .soul_fire => 2.0, // Soul fire deals double damage compared to normal fire
        };
    }

    pub fn isBlue(self: FireType) bool {
        return self == .soul_fire;
    }
};

/// Fire ignited on soul soil or soul sand produces blue soul fire.
pub fn igniteFireOnBlock(substrate: NetherBlock) FireType {
    return switch (substrate) {
        .soul_soil, .soul_sand => .soul_fire,
        .netherrack, .basalt, .blackstone, .magma_block => .normal_fire,
        else => .normal_fire,
    };
}

pub fn isSoulSoilFire(substrate: NetherBlock) bool {
    return substrate == .soul_soil or substrate == .soul_sand;
}

// ============================================================================
// TESTS (At least 12 comprehensive test blocks)
// ============================================================================

test "1. NetherBiome enum includes all five official nether biomes with properties" {
    const biomes = [_]NetherBiome{
        .nether_wastes,
        .crimson_forest,
        .warped_forest,
        .soul_sand_valley,
        .basalt_deltas,
    };
    try std.testing.expectEqual(@as(usize, 5), biomes.len);

    try std.testing.expect(NetherBiome.crimson_forest.isForest());
    try std.testing.expect(NetherBiome.warped_forest.isForest());
    try std.testing.expect(!NetherBiome.nether_wastes.isForest());
    try std.testing.expect(!NetherBiome.soul_sand_valley.isForest());
    try std.testing.expect(!NetherBiome.basalt_deltas.isForest());

    try std.testing.expect(NetherBiome.soul_sand_valley.hasSoulFire());
    try std.testing.expect(!NetherBiome.nether_wastes.hasSoulFire());
    try std.testing.expect(!NetherBiome.crimson_forest.hasSoulFire());
}

test "2. HugeFungusGrowth: Crimson fungus grows only on crimson_nylium when bone-mealed" {
    // Valid growth on crimson nylium with bone meal
    try std.testing.expect(HugeFungusGrowth.canGrow(.crimson, .crimson_nylium, true));
    try std.testing.expect(HugeFungusGrowth.canGrowFromBlock(.crimson_fungus, .crimson_nylium, true));

    // Rejection on other substrates
    try std.testing.expect(!HugeFungusGrowth.canGrow(.crimson, .warped_nylium, true));
    try std.testing.expect(!HugeFungusGrowth.canGrow(.crimson, .netherrack, true));
    try std.testing.expect(!HugeFungusGrowth.canGrow(.crimson, .soul_soil, true));
    try std.testing.expect(!HugeFungusGrowth.canGrow(.crimson, .basalt, true));
}

test "3. HugeFungusGrowth: Warped fungus grows only on warped_nylium when bone-mealed" {
    // Valid growth on warped nylium with bone meal
    try std.testing.expect(HugeFungusGrowth.canGrow(.warped, .warped_nylium, true));
    try std.testing.expect(HugeFungusGrowth.canGrowFromBlock(.warped_fungus, .warped_nylium, true));

    // Rejection on other substrates
    try std.testing.expect(!HugeFungusGrowth.canGrow(.warped, .crimson_nylium, true));
    try std.testing.expect(!HugeFungusGrowth.canGrow(.warped, .netherrack, true));
    try std.testing.expect(!HugeFungusGrowth.canGrow(.warped, .soul_soil, true));
    try std.testing.expect(!HugeFungusGrowth.canGrow(.warped, .soul_sand, true));
}

test "4. HugeFungusGrowth: Fails growth if bone meal is not provided" {
    try std.testing.expect(!HugeFungusGrowth.canGrow(.crimson, .crimson_nylium, false));
    try std.testing.expect(!HugeFungusGrowth.canGrow(.warped, .warped_nylium, false));
    try std.testing.expect(HugeFungusGrowth.attemptGrowth(.crimson, .crimson_nylium, false, 42) == null);
    try std.testing.expect(HugeFungusGrowth.attemptGrowth(.warped, .warped_nylium, false, 42) == null);
}

test "5. HugeFungusGrowth: Produces shroomlight clusters with light level 15" {
    const growth = HugeFungusGrowth.attemptGrowth(.crimson, .crimson_nylium, true, 100).?;
    try std.testing.expect(growth.shroomlight_count >= 1);
    try std.testing.expectEqual(@as(u8, 15), growth.shroomlight_light_level);
    try std.testing.expectEqual(@as(u8, 15), HugeFungusGrowth.shroomlight_emission_level);
}

test "6. HugeFungusGrowth: Crimson produces weeping vines downward and Warped produces twisting vines upward" {
    const crimson_growth = HugeFungusGrowth.attemptGrowth(.crimson, .crimson_nylium, true, 1234).?;
    try std.testing.expectEqual(VineDirection.downward, crimson_growth.vines_direction);
    try std.testing.expectEqual(NetherBlock.weeping_vines, FungusType.crimson.vineBlock());

    const warped_growth = HugeFungusGrowth.attemptGrowth(.warped, .warped_nylium, true, 5678).?;
    try std.testing.expectEqual(VineDirection.upward, warped_growth.vines_direction);
    try std.testing.expectEqual(NetherBlock.twisting_vines, FungusType.warped.vineBlock());
}

test "7. HugeFungusGrowth: Stems are fireproof wood (isFireproofWood() == true)" {
    // Struct method check
    try std.testing.expect(HugeFungusGrowth.isFireproofWood());

    // Enum method check
    try std.testing.expect(FungusType.crimson.isFireproofWood());
    try std.testing.expect(FungusType.warped.isFireproofWood());

    // Block-level check
    try std.testing.expect(isFireproofWood(.crimson_stem));
    try std.testing.expect(isFireproofWood(.warped_stem));
    try std.testing.expect(isFireproofWood(.crimson_hyphae));
    try std.testing.expect(isFireproofWood(.warped_hyphae));

    // Other blocks are not fireproof wood
    try std.testing.expect(!isFireproofWood(.netherrack));
    try std.testing.expect(!isFireproofWood(.basalt));
    try std.testing.expect(!isFireproofWood(.shroomlight));
}

test "8. NyliumSpread: Bone meal on netherrack adjacent to nylium converts to matching nylium" {
    // Netherrack adjacent to crimson nylium becomes crimson nylium
    const crimson_res = NyliumSpread.convertNetherrack(.netherrack, true, true, false);
    try std.testing.expectEqual(@as(?NetherBlock, .crimson_nylium), crimson_res);

    // Netherrack adjacent to warped nylium becomes warped nylium
    const warped_res = NyliumSpread.convertNetherrack(.netherrack, true, false, true);
    try std.testing.expectEqual(@as(?NetherBlock, .warped_nylium), warped_res);

    // Without bone meal, no conversion occurs
    try std.testing.expectEqual(@as(?NetherBlock, null), NyliumSpread.convertNetherrack(.netherrack, false, true, false));

    // Non-netherrack blocks do not convert
    try std.testing.expectEqual(@as(?NetherBlock, null), NyliumSpread.convertNetherrack(.basalt, true, true, false));

    // When touching both, preference or default deterministic priority works
    const preferred_warped = NyliumSpread.convertNetherrackPreferred(.netherrack, true, true, true, true);
    try std.testing.expectEqual(@as(?NetherBlock, .warped_nylium), preferred_warped);
    const preferred_crimson = NyliumSpread.convertNetherrackPreferred(.netherrack, true, true, true, false);
    try std.testing.expectEqual(@as(?NetherBlock, .crimson_nylium), preferred_crimson);
}

test "9. NyliumSpread: Solid opaque block above nylium decays it back to netherrack" {
    // Opaque blocks cause decay
    try std.testing.expect(NyliumSpread.shouldDecay(.netherrack));
    try std.testing.expect(NyliumSpread.shouldDecay(.basalt));
    try std.testing.expect(NyliumSpread.shouldDecay(.blackstone));

    try std.testing.expectEqual(NetherBlock.netherrack, NyliumSpread.tickNylium(.crimson_nylium, .netherrack));
    try std.testing.expectEqual(NetherBlock.netherrack, NyliumSpread.tickNylium(.warped_nylium, .basalt));
    try std.testing.expectEqual(NetherBlock.netherrack, NyliumSpread.tickNyliumWithOpaqueFlag(.crimson_nylium, true));

    // Transparent blocks (air, vines, fungi, fire) preserve nylium
    try std.testing.expect(!NyliumSpread.shouldDecay(.air));
    try std.testing.expect(!NyliumSpread.shouldDecay(.crimson_fungus));
    try std.testing.expect(!NyliumSpread.shouldDecay(.warped_fungus));
    try std.testing.expect(!NyliumSpread.shouldDecay(.weeping_vines));
    try std.testing.expect(!NyliumSpread.shouldDecay(.twisting_vines));
    try std.testing.expect(!NyliumSpread.shouldDecay(.fire));

    try std.testing.expectEqual(NetherBlock.crimson_nylium, NyliumSpread.tickNylium(.crimson_nylium, .air));
    try std.testing.expectEqual(NetherBlock.warped_nylium, NyliumSpread.tickNylium(.warped_nylium, .air));
    try std.testing.expectEqual(NetherBlock.crimson_nylium, NyliumSpread.tickNyliumWithOpaqueFlag(.crimson_nylium, false));
}

test "10. BasaltGenerator: Flowing lava contacting soul soil below and blue ice adjacent forms basalt" {
    // Exact signature verification: canFormBasalt(has_flowing_lava, below_is_soul_soil, adjacent_is_blue_ice)
    try std.testing.expect(canFormBasalt(true, true, true));
    try std.testing.expect(BasaltGenerator.canFormBasalt(true, true, true));

    // Block-based overload
    try std.testing.expect(BasaltGenerator.canFormBasaltFromBlocks(.flowing_lava, .soul_soil, .blue_ice));

    // Missing any condition fails
    try std.testing.expect(!canFormBasalt(false, true, true)); // Still lava or no lava
    try std.testing.expect(!canFormBasalt(true, false, true)); // Soul sand or stone instead of soul soil
    try std.testing.expect(!canFormBasalt(true, true, false)); // Packed ice or regular ice instead of blue ice

    try std.testing.expect(!BasaltGenerator.canFormBasaltFromBlocks(.still_lava, .soul_soil, .blue_ice));
    try std.testing.expect(!BasaltGenerator.canFormBasaltFromBlocks(.flowing_lava, .soul_sand, .blue_ice));
}

test "11. BasaltGenerator: Smelting basalt yields smooth_basalt" {
    try std.testing.expectEqual(@as(?NetherBlock, .smooth_basalt), BasaltGenerator.smeltBasalt(.basalt));
    try std.testing.expectEqual(@as(?NetherBlock, .smooth_basalt), smeltBasalt(.basalt));

    // Non-basalt does not smelt to smooth basalt
    try std.testing.expectEqual(@as(?NetherBlock, null), BasaltGenerator.smeltBasalt(.netherrack));
    try std.testing.expectEqual(@as(?NetherBlock, null), BasaltGenerator.smeltBasalt(.blackstone));
}

test "12. BasaltGenerator: Crafting 4 basalt yields 4 polished_basalt" {
    const result = BasaltGenerator.craftPolishedBasalt(.basalt, 4).?;
    try std.testing.expectEqual(NetherBlock.polished_basalt, result.output_block);
    try std.testing.expectEqual(@as(u32, 4), result.output_count);
    try std.testing.expectEqual(@as(u32, 4), result.consumed_count);

    // Multi-batch: 8 basalt yields 8 polished_basalt
    const multi = craftPolishedBasalt(.basalt, 8).?;
    try std.testing.expectEqual(@as(u32, 8), multi.output_count);
    try std.testing.expectEqual(@as(u32, 8), multi.consumed_count);

    // Insufficient input (< 4) fails crafting
    try std.testing.expect(BasaltGenerator.craftPolishedBasalt(.basalt, 3) == null);
    try std.testing.expect(craftPolishedBasalt(.netherrack, 4) == null);
}

test "13. SoulSandValleyFossil: Ribcage fossils and bone meal yield calculation" {
    const fossil = SoulSandValleyFossil{
        .bone_blocks_count = 15,
        .bone_meal_per_block = 3,
        .variant = .ribcage,
    };
    try std.testing.expectEqual(@as(u8, 15), fossil.bone_blocks_count);
    try std.testing.expectEqual(@as(u8, 3), fossil.bone_meal_per_block);
    try std.testing.expectEqual(@as(u32, 45), fossil.totalBoneMealYield());

    // Generated ribcage with 3 pairs of ribs:
    // spine = 3*2 + 1 = 7 blocks; ribs = 3*6 = 18 blocks; total = 25 blocks.
    const ribcage = SoulSandValleyFossil.generateRibcage(3);
    try std.testing.expectEqual(@as(u8, 25), ribcage.bone_blocks_count);
    try std.testing.expectEqual(@as(u8, 3), ribcage.bone_meal_per_block);
    try std.testing.expectEqual(@as(u32, 75), ribcage.totalBoneMealYield());
}

test "14. SoulSandValley: High spawn weights for Ghasts and Skeletons" {
    try std.testing.expect(SoulSandValleySpawns.isHighSpawnWeightSkeleton());
    try std.testing.expect(SoulSandValleySpawns.isHighSpawnWeightGhast());
    try std.testing.expectEqual(@as(u32, 300), SoulSandValleySpawns.skeleton_weight);
    try std.testing.expectEqual(@as(u32, 50), SoulSandValleySpawns.ghast_weight);
    try std.testing.expect(SoulSandValleySpawns.skeleton_weight > SoulSandValleySpawns.ghast_weight);
}

test "15. Soul Fire: Blue fire on soul soil and soul sand with double damage and lower light level" {
    try std.testing.expect(isSoulSoilFire(.soul_soil));
    try std.testing.expect(isSoulSoilFire(.soul_sand));
    try std.testing.expect(!isSoulSoilFire(.netherrack));

    const soil_fire = igniteFireOnBlock(.soul_soil);
    try std.testing.expectEqual(FireType.soul_fire, soil_fire);
    try std.testing.expect(soil_fire.isBlue());
    try std.testing.expectEqual(@as(u8, 10), soil_fire.lightLevel());
    try std.testing.expectEqual(@as(f32, 2.0), soil_fire.damagePerSecond());

    const netherrack_fire = igniteFireOnBlock(.netherrack);
    try std.testing.expectEqual(FireType.normal_fire, netherrack_fire);
    try std.testing.expect(!netherrack_fire.isBlue());
    try std.testing.expectEqual(@as(u8, 15), netherrack_fire.lightLevel());
    try std.testing.expectEqual(@as(f32, 1.0), netherrack_fire.damagePerSecond());
}
