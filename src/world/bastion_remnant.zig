const std = @import("std");

/// The four canonical structure variants of Bastion Remnants.
/// Bastion remnants are large castle-like ruins found in the Nether.
pub const BastionVariant = enum {
    bridge,
    hoglin_stables,
    housing_units,
    treasure_room,

    pub fn name(self: BastionVariant) []const u8 {
        return switch (self) {
            .bridge => "Bridge",
            .hoglin_stables => "Hoglin Stables",
            .housing_units => "Housing Units",
            .treasure_room => "Treasure Room",
        };
    }

    /// Whether this variant naturally spawns hoglins in specialized stable pens.
    pub fn hasHoglinPens(self: BastionVariant) bool {
        return self == .hoglin_stables;
    }

    /// Whether this variant contains a central magma cube spawner in a suspended cage.
    pub fn hasMagmaCubeSpawner(self: BastionVariant) bool {
        return self == .treasure_room;
    }

    /// Whether this variant has a guaranteed Netherite Upgrade smithing template in its primary chest.
    pub fn guaranteesNetheriteUpgradeTemplate(self: BastionVariant) bool {
        return self == .treasure_room;
    }
};

/// Bastion remnants generate in Nether Wastes, Crimson Forest, Warped Forest,
/// and Soul Sand Valley biomes, but NEVER in Basalt Deltas.
pub fn canGenerateBastionInBiome(is_basalt_deltas: bool) bool {
    return !is_basalt_deltas;
}

/// Combat and behavioral statistics for the Piglin Brute.
/// Piglin Brutes are hostile, axe-wielding guards that inhabit Bastion Remnants.
pub const PiglinBruteStats = struct {
    max_health: f32 = 50.0,
    golden_axe_damage: f32 = 13.0,
    ignores_gold_armor: bool = true,
    spawns_only_on_generation: bool = true,
    alert_piglins_radius: f32 = 16.0,

    /// Piglin Brutes are completely immune to gold pacification and will attack
    /// players regardless of what armor they are wearing.
    pub fn isPacifiedByGoldArmor(self: PiglinBruteStats) bool {
        return !self.ignores_gold_armor;
    }

    /// Piglin Brutes only spawn naturally during world/structure generation.
    /// Unlike standard piglins, they do not respawn over time after being killed.
    pub fn canRespawnAfterDeath(self: PiglinBruteStats) bool {
        return !self.spawns_only_on_generation;
    }

    /// When a Piglin Brute targets an enemy or takes damage, it alerts all standard
    /// piglins within a 16-block radius to also become aggressive.
    pub fn alertsNearbyPiglins(self: PiglinBruteStats, distance_m: f32) bool {
        return distance_m >= 0.0 and distance_m <= self.alert_piglins_radius;
    }
};

/// Global helper for checking whether Piglin Brutes are pacified by gold armor.
pub fn isPacifiedByGoldArmor() bool {
    const stats: PiglinBruteStats = .{};
    return stats.isPacifiedByGoldArmor();
}

/// Global helper for checking whether Piglin Brutes can respawn after death.
pub fn canRespawnAfterDeath() bool {
    const stats: PiglinBruteStats = .{};
    return stats.canRespawnAfterDeath();
}

/// Global helper for piglin brute alert range.
pub fn shouldAlertNearbyPiglin(distance_m: f32) bool {
    const stats: PiglinBruteStats = .{};
    return stats.alertsNearbyPiglins(distance_m);
}

/// Key architectural and loot features of the Bastion Treasure Room.
pub const TreasureRoomFeatures = struct {
    /// A magma cube spawner suspended in an iron bar cage over a lava court.
    has_magma_cube_spawner: bool = true,
    /// Central lava court surrounded by multiple tiers and ramparts.
    has_lava_court: bool = true,
    /// A central cache of gold blocks at the bottom of the treasure room (typically 16 blocks).
    gold_blocks_count: u8 = 16,
    /// The central chest in the treasure room has a 100% guaranteed chance to contain a Netherite Upgrade Smithing Template.
    has_netherite_upgrade_template: bool = true,

    pub fn isGuaranteedNetheriteUpgrade(self: TreasureRoomFeatures) bool {
        return self.has_netherite_upgrade_template;
    }

    pub fn getGoldBlockCount(self: TreasureRoomFeatures) u8 {
        return self.gold_blocks_count;
    }

    pub fn hasMagmaCubeSpawnerCage(self: TreasureRoomFeatures) bool {
        return self.has_magma_cube_spawner and self.has_lava_court;
    }
};

/// Drop rules and probabilities for mining Gilded Blackstone.
pub const GildedBlackstoneDrop = struct {
    pub const ItemType = enum {
        gilded_blackstone,
        gold_nugget,

        pub fn name(self: ItemType) []const u8 {
            return switch (self) {
                .gilded_blackstone => "Gilded Blackstone",
                .gold_nugget => "Gold Nugget",
            };
        }
    };

    pub const DropResult = struct {
        item: ItemType,
        count: u8,
    };

    pub const min_gold_nuggets: u8 = 2;
    pub const max_gold_nuggets: u8 = 5;

    /// Fortune-scaled chance to drop 2..5 gold nuggets when mined without Silk Touch.
    /// Fortune 0 => 10% (0.10)
    /// Fortune 1 => 14.29% (~1/7, 0.1429)
    /// Fortune 2 => 25% (0.25)
    /// Fortune 3 => 100% (1.00)
    pub fn getGoldNuggetChance(fortune_level: u8) f32 {
        return switch (fortune_level) {
            0 => 0.10,
            1 => 0.1429,
            2 => 0.25,
            else => 1.0,
        };
    }

    /// Evaluates if gold nuggets are dropped given silk touch, fortune, and a random float in [0.0, 1.0).
    pub fn dropsGoldNuggets(has_silk_touch: bool, fortune_level: u8, roll_0_to_1: f32) bool {
        if (has_silk_touch) return false;
        const chance = getGoldNuggetChance(fortune_level);
        return roll_0_to_1 < chance;
    }

    /// Calculates the drop result cleanly and deterministically.
    /// `chance_roll_0_to_1` is a float in [0.0, 1.0) for deciding nugget vs block.
    /// `nugget_count_roll_0_to_3` is an integer in 0..3 selecting between 2 and 5 nuggets (2 + roll).
    pub fn calculateDrop(
        has_silk_touch: bool,
        fortune_level: u8,
        chance_roll_0_to_1: f32,
        nugget_count_roll_0_to_3: u8,
    ) DropResult {
        if (has_silk_touch) {
            return .{ .item = .gilded_blackstone, .count = 1 };
        }

        if (dropsGoldNuggets(false, fortune_level, chance_roll_0_to_1)) {
            const extra = @min(nugget_count_roll_0_to_3, max_gold_nuggets - min_gold_nuggets);
            return .{
                .item = .gold_nugget,
                .count = min_gold_nuggets + extra,
            };
        }

        return .{ .item = .gilded_blackstone, .count = 1 };
    }
};

/// Signature rare and unique loot items found exclusively or prominently in Bastion Remnants.
pub const BastionRareLoot = enum {
    pigstep_music_disc,
    snout_banner_pattern,
    snout_armor_trim,
    ancient_debris,
    crying_obsidian,

    pub fn name(self: BastionRareLoot) []const u8 {
        return switch (self) {
            .pigstep_music_disc => "Music Disc (Lena Raine - Pigstep)",
            .snout_banner_pattern => "Banner Pattern (Snout)",
            .snout_armor_trim => "Snout Armor Trim Smithing Template",
            .ancient_debris => "Ancient Debris",
            .crying_obsidian => "Crying Obsidian",
        };
    }

    /// Whether this item can only be obtained natively from Bastion Remnants in survival mode.
    pub fn isExclusiveToBastion(self: BastionRareLoot) bool {
        return switch (self) {
            .pigstep_music_disc, .snout_banner_pattern, .snout_armor_trim => true,
            .ancient_debris, .crying_obsidian => false,
        };
    }
};

// ============================================================================
// Unit Tests (At least 12 comprehensive test blocks)
// ============================================================================

test "1: BastionVariant enum contains all four canonical variants" {
    const variants = [_]BastionVariant{
        .bridge,
        .hoglin_stables,
        .housing_units,
        .treasure_room,
    };
    try std.testing.expectEqual(@as(usize, 4), variants.len);
    try std.testing.expectEqualStrings("Bridge", BastionVariant.bridge.name());
    try std.testing.expectEqualStrings("Hoglin Stables", BastionVariant.hoglin_stables.name());
    try std.testing.expectEqualStrings("Housing Units", BastionVariant.housing_units.name());
    try std.testing.expectEqualStrings("Treasure Room", BastionVariant.treasure_room.name());
}

test "2: Bastion Remnants never generate in basalt deltas biome" {
    // Biome check must return false for basalt deltas
    try std.testing.expect(!canGenerateBastionInBiome(true));
    // Biome check returns true for non-basalt-deltas Nether biomes
    try std.testing.expect(canGenerateBastionInBiome(false));
}

test "3: BastionVariant specific traits and features" {
    try std.testing.expect(BastionVariant.hoglin_stables.hasHoglinPens());
    try std.testing.expect(!BastionVariant.bridge.hasHoglinPens());
    try std.testing.expect(!BastionVariant.housing_units.hasHoglinPens());
    try std.testing.expect(!BastionVariant.treasure_room.hasHoglinPens());

    try std.testing.expect(BastionVariant.treasure_room.hasMagmaCubeSpawner());
    try std.testing.expect(!BastionVariant.bridge.hasMagmaCubeSpawner());

    try std.testing.expect(BastionVariant.treasure_room.guaranteesNetheriteUpgradeTemplate());
    try std.testing.expect(!BastionVariant.housing_units.guaranteesNetheriteUpgradeTemplate());
}

test "4: PiglinBruteStats default values match specifications" {
    const brute = PiglinBruteStats{};
    try std.testing.expectEqual(@as(f32, 50.0), brute.max_health);
    try std.testing.expectEqual(@as(f32, 13.0), brute.golden_axe_damage);
    try std.testing.expect(brute.ignores_gold_armor);
    try std.testing.expect(brute.spawns_only_on_generation);
    try std.testing.expectEqual(@as(f32, 16.0), brute.alert_piglins_radius);
}

test "5: Piglin Brute ignores gold armor and is never pacified" {
    const brute = PiglinBruteStats{};
    try std.testing.expect(!brute.isPacifiedByGoldArmor());
    try std.testing.expect(!isPacifiedByGoldArmor());

    // If a custom instance had ignores_gold_armor = false, it would pacify
    const custom = PiglinBruteStats{ .ignores_gold_armor = false };
    try std.testing.expect(custom.isPacifiedByGoldArmor());
}

test "6: Piglin Brute spawns only on generation and cannot respawn after death" {
    const brute = PiglinBruteStats{};
    try std.testing.expect(!brute.canRespawnAfterDeath());
    try std.testing.expect(!canRespawnAfterDeath());

    const custom = PiglinBruteStats{ .spawns_only_on_generation = false };
    try std.testing.expect(custom.canRespawnAfterDeath());
}

test "7: Piglin Brute alerts nearby regular piglins within 16 meters" {
    const brute = PiglinBruteStats{};
    try std.testing.expect(brute.alertsNearbyPiglins(0.0));
    try std.testing.expect(brute.alertsNearbyPiglins(8.0));
    try std.testing.expect(brute.alertsNearbyPiglins(16.0));
    try std.testing.expect(!brute.alertsNearbyPiglins(16.05));
    try std.testing.expect(!brute.alertsNearbyPiglins(20.0));
    try std.testing.expect(!brute.alertsNearbyPiglins(-1.0));

    try std.testing.expect(shouldAlertNearbyPiglin(15.9));
    try std.testing.expect(!shouldAlertNearbyPiglin(16.1));
}

test "8: TreasureRoomFeatures includes magma cube spawner cage hanging over lava court" {
    const features = TreasureRoomFeatures{};
    try std.testing.expect(features.has_magma_cube_spawner);
    try std.testing.expect(features.has_lava_court);
    try std.testing.expect(features.hasMagmaCubeSpawnerCage());
}

test "9: TreasureRoomFeatures has bottom gold block cache with 16 blocks" {
    const features = TreasureRoomFeatures{};
    try std.testing.expectEqual(@as(u8, 16), features.gold_blocks_count);
    try std.testing.expectEqual(@as(u8, 16), features.getGoldBlockCount());
}

test "10: TreasureRoomFeatures guarantees Netherite Upgrade Smithing Template in chest" {
    const features = TreasureRoomFeatures{};
    try std.testing.expect(features.has_netherite_upgrade_template);
    try std.testing.expect(features.isGuaranteedNetheriteUpgrade());
}

test "11: Gilded Blackstone mining with Silk Touch always drops Gilded Blackstone" {
    // Silk Touch with any fortune and any rolls must always drop exactly 1 Gilded Blackstone
    const result1 = GildedBlackstoneDrop.calculateDrop(true, 0, 0.0, 0);
    try std.testing.expectEqual(GildedBlackstoneDrop.ItemType.gilded_blackstone, result1.item);
    try std.testing.expectEqual(@as(u8, 1), result1.count);

    const result2 = GildedBlackstoneDrop.calculateDrop(true, 3, 0.05, 3);
    try std.testing.expectEqual(GildedBlackstoneDrop.ItemType.gilded_blackstone, result2.item);
    try std.testing.expectEqual(@as(u8, 1), result2.count);

    try std.testing.expect(!GildedBlackstoneDrop.dropsGoldNuggets(true, 3, 0.0));
}

test "12: Gilded Blackstone drop chances scale with Fortune (0=>10%, 1=>14.29%, 2=>25%, 3=>100%)" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), GildedBlackstoneDrop.getGoldNuggetChance(0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1429), GildedBlackstoneDrop.getGoldNuggetChance(1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), GildedBlackstoneDrop.getGoldNuggetChance(2), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), GildedBlackstoneDrop.getGoldNuggetChance(3), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), GildedBlackstoneDrop.getGoldNuggetChance(4), 0.0001);

    // Fortune 0: roll 0.09 drops nuggets, roll 0.11 drops block
    try std.testing.expect(GildedBlackstoneDrop.dropsGoldNuggets(false, 0, 0.09));
    try std.testing.expect(!GildedBlackstoneDrop.dropsGoldNuggets(false, 0, 0.11));

    // Fortune 1: roll 0.14 drops nuggets, roll 0.15 drops block
    try std.testing.expect(GildedBlackstoneDrop.dropsGoldNuggets(false, 1, 0.14));
    try std.testing.expect(!GildedBlackstoneDrop.dropsGoldNuggets(false, 1, 0.15));

    // Fortune 2: roll 0.24 drops nuggets, roll 0.26 drops block
    try std.testing.expect(GildedBlackstoneDrop.dropsGoldNuggets(false, 2, 0.24));
    try std.testing.expect(!GildedBlackstoneDrop.dropsGoldNuggets(false, 2, 0.26));

    // Fortune 3: roll 0.99 still drops nuggets (100% chance)
    try std.testing.expect(GildedBlackstoneDrop.dropsGoldNuggets(false, 3, 0.99));
}

test "13: Gilded Blackstone drops 2..5 gold nuggets when nugget roll succeeds" {
    // Roll 0 -> 2 nuggets
    const drop0 = GildedBlackstoneDrop.calculateDrop(false, 3, 0.5, 0);
    try std.testing.expectEqual(GildedBlackstoneDrop.ItemType.gold_nugget, drop0.item);
    try std.testing.expectEqual(@as(u8, 2), drop0.count);

    // Roll 1 -> 3 nuggets
    const drop1 = GildedBlackstoneDrop.calculateDrop(false, 3, 0.5, 1);
    try std.testing.expectEqual(GildedBlackstoneDrop.ItemType.gold_nugget, drop1.item);
    try std.testing.expectEqual(@as(u8, 3), drop1.count);

    // Roll 2 -> 4 nuggets
    const drop2 = GildedBlackstoneDrop.calculateDrop(false, 3, 0.5, 2);
    try std.testing.expectEqual(GildedBlackstoneDrop.ItemType.gold_nugget, drop2.item);
    try std.testing.expectEqual(@as(u8, 4), drop2.count);

    // Roll 3 -> 5 nuggets
    const drop3 = GildedBlackstoneDrop.calculateDrop(false, 3, 0.5, 3);
    try std.testing.expectEqual(GildedBlackstoneDrop.ItemType.gold_nugget, drop3.item);
    try std.testing.expectEqual(@as(u8, 5), drop3.count);

    // Clamping large roll values
    const drop_large = GildedBlackstoneDrop.calculateDrop(false, 3, 0.5, 10);
    try std.testing.expectEqual(GildedBlackstoneDrop.ItemType.gold_nugget, drop_large.item);
    try std.testing.expectEqual(@as(u8, 5), drop_large.count);
}

test "14: Gilded Blackstone drops the block itself if nugget chance roll fails" {
    // At Fortune 0, roll = 0.50 fails the 10% chance
    const drop_fail = GildedBlackstoneDrop.calculateDrop(false, 0, 0.50, 0);
    try std.testing.expectEqual(GildedBlackstoneDrop.ItemType.gilded_blackstone, drop_fail.item);
    try std.testing.expectEqual(@as(u8, 1), drop_fail.count);
}

test "15: BastionRareLoot enum and bastion exclusivity" {
    const disc = BastionRareLoot.pigstep_music_disc;
    const banner = BastionRareLoot.snout_banner_pattern;
    const trim = BastionRareLoot.snout_armor_trim;
    const debris = BastionRareLoot.ancient_debris;
    const crying = BastionRareLoot.crying_obsidian;

    try std.testing.expect(disc.isExclusiveToBastion());
    try std.testing.expect(banner.isExclusiveToBastion());
    try std.testing.expect(trim.isExclusiveToBastion());
    try std.testing.expect(!debris.isExclusiveToBastion());
    try std.testing.expect(!crying.isExclusiveToBastion());

    try std.testing.expectEqualStrings("Music Disc (Lena Raine - Pigstep)", disc.name());
    try std.testing.expectEqualStrings("Banner Pattern (Snout)", banner.name());
    try std.testing.expectEqualStrings("Snout Armor Trim Smithing Template", trim.name());
    try std.testing.expectEqualStrings("Ancient Debris", debris.name());
    try std.testing.expectEqualStrings("Crying Obsidian", crying.name());
}
