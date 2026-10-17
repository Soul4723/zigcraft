const std = @import("std");

/// Ocean Ruin Biome Variant:
/// - cold_stone_brick_ruin: generated in cold, frozen, deep, or normal oceans. Built from stone bricks,
///   mossy/cracked stone bricks, sea lanterns, and suspicious gravel.
/// - warm_sandstone_ruin: generated in warm or lukewarm oceans. Built from sandstone,
///   chiseled sandstone, polished granite, magma blocks, and suspicious sand.
pub const OceanRuinBiomeVariant = enum {
    cold_stone_brick_ruin,
    warm_sandstone_ruin,

    pub fn isCold(self: OceanRuinBiomeVariant) bool {
        return self == .cold_stone_brick_ruin;
    }

    pub fn isWarm(self: OceanRuinBiomeVariant) bool {
        return self == .warm_sandstone_ruin;
    }

    pub fn suspiciousBlock(self: OceanRuinBiomeVariant) SuspiciousBlockType {
        return switch (self) {
            .cold_stone_brick_ruin => .suspicious_gravel,
            .warm_sandstone_ruin => .suspicious_sand,
        };
    }

    pub fn canExcavateSnifferEgg(self: OceanRuinBiomeVariant) bool {
        return self == .warm_sandstone_ruin;
    }

    pub fn hasMagmaBlocks(self: OceanRuinBiomeVariant) bool {
        return self == .warm_sandstone_ruin;
    }

    pub fn hasSeaLanterns(self: OceanRuinBiomeVariant) bool {
        return self == .cold_stone_brick_ruin;
    }

    pub fn primaryBuildingBlock(self: OceanRuinBiomeVariant) OceanRuinBlock {
        return switch (self) {
            .cold_stone_brick_ruin => .stone_bricks,
            .warm_sandstone_ruin => .sandstone,
        };
    }

    pub fn isValidStructureBlock(self: OceanRuinBiomeVariant, block: OceanRuinBlock) bool {
        return switch (self) {
            .cold_stone_brick_ruin => switch (block) {
                .stone_bricks,
                .mossy_stone_bricks,
                .cracked_stone_bricks,
                .sea_lantern,
                .suspicious_gravel,
                .gravel,
                .cobblestone,
                .mossy_cobblestone,
                .chest,
                .water,
                => true,
                else => false,
            },
            .warm_sandstone_ruin => switch (block) {
                .sandstone,
                .chiseled_sandstone,
                .cut_sandstone,
                .polished_granite,
                .magma_block,
                .suspicious_sand,
                .sand,
                .chest,
                .water,
                => true,
                else => false,
            },
        };
    }
};

/// Blocks appearing in Ocean Ruin structures.
pub const OceanRuinBlock = enum {
    // Cold ruin materials
    stone_bricks,
    mossy_stone_bricks,
    cracked_stone_bricks,
    sea_lantern,
    suspicious_gravel,
    gravel,
    cobblestone,
    mossy_cobblestone,

    // Warm ruin materials
    sandstone,
    chiseled_sandstone,
    cut_sandstone,
    polished_granite,
    magma_block,
    suspicious_sand,
    sand,

    // Shared structure blocks
    chest,
    water,
    iron_bars,
    wooden_planks,
};

/// Archaeology suspicious block types in ocean ruins.
pub const SuspiciousBlockType = enum {
    suspicious_gravel,
    suspicious_sand,

    pub fn normalBlockAfterBrushing(self: SuspiciousBlockType) OceanRuinBlock {
        return switch (self) {
            .suspicious_gravel => .gravel,
            .suspicious_sand => .sand,
        };
    }
};

/// Pottery sherd designs specific to ocean ruins archaeology.
pub const OceanRuinPotterySherd = enum {
    // Warm ocean ruins
    angler,
    shelter,
    snort,

    // Cold ocean ruins
    blade,
    explorer,
    mourner,
    plenty,

    pub fn isWarmExclusive(self: OceanRuinPotterySherd) bool {
        return switch (self) {
            .angler, .shelter, .snort => true,
            .blade, .explorer, .mourner, .plenty => false,
        };
    }

    pub fn isColdExclusive(self: OceanRuinPotterySherd) bool {
        return !self.isWarmExclusive();
    }
};

/// Archaeology excavation loot items.
pub const ArchaeologyLootItem = enum {
    sniffer_egg,
    angler_pottery_sherd,
    shelter_pottery_sherd,
    snort_pottery_sherd,
    blade_pottery_sherd,
    explorer_pottery_sherd,
    mourner_pottery_sherd,
    plenty_pottery_sherd,
    iron_axe,
    emerald,
    coal,
    wheat,
    wooden_hoe,
    gold_nugget,

    pub fn isSherd(self: ArchaeologyLootItem) bool {
        return switch (self) {
            .angler_pottery_sherd,
            .shelter_pottery_sherd,
            .snort_pottery_sherd,
            .blade_pottery_sherd,
            .explorer_pottery_sherd,
            .mourner_pottery_sherd,
            .plenty_pottery_sherd,
            => true,
            else => false,
        };
    }
};

/// Archaeology system for Ocean Ruins.
pub const OceanRuinArchaeology = struct {
    pub const brushes_to_excavate: u8 = 4;

    /// Warm ocean ruin loot table:
    /// - Sniffer Egg (6.7% / 1 in 15 in vanilla)
    /// - Angler, Shelter, Snort pottery sherds
    /// - Iron axe, Emerald, Coal, Wheat, Wooden hoe, Gold nugget
    pub const warm_archaeology_loot = [_]ArchaeologyLootItem{
        .sniffer_egg,
        .angler_pottery_sherd,
        .shelter_pottery_sherd,
        .snort_pottery_sherd,
        .iron_axe,
        .emerald,
        .coal,
        .wheat,
        .wooden_hoe,
        .gold_nugget,
    };

    /// Cold ocean ruin loot table:
    /// - Blade, Explorer, Mourner, Plenty pottery sherds
    /// - Iron axe, Emerald, Coal, Wheat, Wooden hoe, Gold nugget
    pub const cold_archaeology_loot = [_]ArchaeologyLootItem{
        .blade_pottery_sherd,
        .explorer_pottery_sherd,
        .mourner_pottery_sherd,
        .plenty_pottery_sherd,
        .iron_axe,
        .emerald,
        .coal,
        .wheat,
        .wooden_hoe,
        .gold_nugget,
    };

    /// Whether sniffer eggs can be excavated from this biome variant's suspicious blocks.
    /// Only warm sandstone ocean ruins yield sniffer eggs.
    pub fn canExcavateSnifferEgg(variant: OceanRuinBiomeVariant) bool {
        return variant == .warm_sandstone_ruin;
    }

    /// Returns the pool of possible excavation loot for the given ruin variant.
    pub fn getLootTable(variant: OceanRuinBiomeVariant) []const ArchaeologyLootItem {
        return switch (variant) {
            .warm_sandstone_ruin => &warm_archaeology_loot,
            .cold_stone_brick_ruin => &cold_archaeology_loot,
        };
    }

    /// Selects loot using a normalized roll in [0.0, 1.0).
    pub fn rollLoot(variant: OceanRuinBiomeVariant, roll_normalized: f32) ArchaeologyLootItem {
        const table = getLootTable(variant);
        const clamped = std.math.clamp(roll_normalized, 0.0, 0.999999);
        const index = @as(usize, @intFromFloat(clamped * @as(f32, @floatFromInt(table.len))));
        return table[index];
    }

    /// Deterministically samples loot from a pseudo-random seed.
    pub fn rollLootFromSeed(variant: OceanRuinBiomeVariant, seed: u64) ArchaeologyLootItem {
        var prng = std.Random.DefaultPrng.init(seed);
        const roll = prng.random().float(f32);
        return rollLoot(variant, roll);
    }
};

/// Global function alias matching requirement:
/// `canExcavateSnifferEgg(variant: OceanRuinBiomeVariant) bool`
pub fn canExcavateSnifferEgg(variant: OceanRuinBiomeVariant) bool {
    return OceanRuinArchaeology.canExcavateSnifferEgg(variant);
}

/// State tracking for a suspicious block undergoing brush excavation.
pub const SuspiciousBlockState = struct {
    variant: OceanRuinBiomeVariant,
    block_type: SuspiciousBlockType,
    brush_stage: u8 = 0,
    loot: ArchaeologyLootItem,
    is_extracted: bool = false,

    pub fn init(variant: OceanRuinBiomeVariant, loot: ArchaeologyLootItem) SuspiciousBlockState {
        return .{
            .variant = variant,
            .block_type = variant.suspiciousBlock(),
            .brush_stage = 0,
            .loot = loot,
            .is_extracted = false,
        };
    }

    pub fn initFromSeed(variant: OceanRuinBiomeVariant, seed: u64) SuspiciousBlockState {
        const loot = OceanRuinArchaeology.rollLootFromSeed(variant, seed);
        return init(variant, loot);
    }

    /// Applies a brush action. Advances stage 0 -> 1 -> 2 -> 3 -> 4.
    /// When reaching the required brushes, returns the extracted loot item.
    pub fn brush(self: *SuspiciousBlockState) ?ArchaeologyLootItem {
        if (self.is_extracted) return null;
        self.brush_stage += 1;
        if (self.brush_stage >= OceanRuinArchaeology.brushes_to_excavate) {
            self.is_extracted = true;
            return self.loot;
        }
        return null;
    }

    /// When excavation completes, suspicious sand turns into sand, and suspicious gravel turns into gravel.
    pub fn resultingBlock(self: SuspiciousBlockState) OceanRuinBlock {
        if (!self.is_extracted) {
            return switch (self.block_type) {
                .suspicious_sand => .suspicious_sand,
                .suspicious_gravel => .suspicious_gravel,
            };
        }
        return self.block_type.normalBlockAfterBrushing();
    }
};

/// Sniffer Egg cracking phases.
pub const EggCrackStage = enum(u8) {
    intact = 0,
    cracked = 1,
    near_hatching = 2,
    hatched = 3,

    pub fn crackIndex(self: EggCrackStage) u8 {
        return @intFromEnum(self);
    }
};

/// Baby sniffer produced when an egg completes incubation.
pub const Snifflet = struct {
    is_baby: bool = true,
    age_seconds: f32 = 0.0,
    growth_duration_seconds: f32 = 1200.0, // 20 minutes to reach adulthood

    pub fn isAdult(self: Snifflet) bool {
        return self.age_seconds >= self.growth_duration_seconds;
    }

    pub fn tick(self: *Snifflet, dt: f32) void {
        if (dt > 0.0) {
            self.age_seconds = @min(self.age_seconds + dt, self.growth_duration_seconds);
            if (self.isAdult()) {
                self.is_baby = false;
            }
        }
    }
};

/// Sniffer Egg Hatching mechanics:
/// - Hatches in 20.0 minutes (1200.0 seconds) on regular blocks.
/// - Hatches in 10.0 minutes (600.0 seconds, 2x speed) when placed on a moss_block.
pub const SnifferEggHatching = struct {
    pub const regular_hatch_duration_seconds: f32 = 1200.0;
    pub const moss_hatch_duration_seconds: f32 = 600.0;
    pub const moss_speed_multiplier: f32 = 2.0;

    /// Returns required incubation duration in seconds.
    pub fn hatchDurationSeconds(on_moss_block: bool) f32 {
        if (on_moss_block) {
            return moss_hatch_duration_seconds;
        } else {
            return regular_hatch_duration_seconds;
        }
    }
};

/// Global function alias matching requirement:
/// `hatchDurationSeconds(on_moss_block: bool) f32`
pub fn hatchDurationSeconds(on_moss_block: bool) f32 {
    return SnifferEggHatching.hatchDurationSeconds(on_moss_block);
}

/// State of an incubating Sniffer Egg placed in the world.
pub const SnifferEggState = struct {
    on_moss_block: bool = false,
    elapsed_seconds: f32 = 0.0,
    stage: EggCrackStage = .intact,

    pub fn init(on_moss_block: bool) SnifferEggState {
        return .{
            .on_moss_block = on_moss_block,
            .elapsed_seconds = 0.0,
            .stage = .intact,
        };
    }

    pub fn targetDurationSeconds(self: SnifferEggState) f32 {
        return hatchDurationSeconds(self.on_moss_block);
    }

    pub fn progressRatio(self: SnifferEggState) f32 {
        const total = self.targetDurationSeconds();
        if (total <= 0.0) return 1.0;
        return std.math.clamp(self.elapsed_seconds / total, 0.0, 1.0);
    }

    pub fn remainingSeconds(self: SnifferEggState) f32 {
        const total = self.targetDurationSeconds();
        if (self.elapsed_seconds >= total) return 0.0;
        return total - self.elapsed_seconds;
    }

    pub fn updateCrackStage(self: *SnifferEggState) void {
        const total = self.targetDurationSeconds();
        if (total <= 0.0 or self.elapsed_seconds >= total) {
            self.stage = .hatched;
        } else if (self.elapsed_seconds + 0.001 >= total * (2.0 / 3.0)) {
            self.stage = .near_hatching;
        } else if (self.elapsed_seconds + 0.001 >= total * (1.0 / 3.0)) {
            self.stage = .cracked;
        } else {
            self.stage = .intact;
        }
    }

    /// Advance incubation timer. If hatching threshold reached, spawns a Snifflet.
    pub fn tick(self: *SnifferEggState, dt: f32) ?Snifflet {
        if (self.stage == .hatched) return null;
        if (dt <= 0.0) return null;

        self.elapsed_seconds += dt;
        self.updateCrackStage();

        if (self.stage == .hatched) {
            return Snifflet{
                .is_baby = true,
                .age_seconds = 0.0,
                .growth_duration_seconds = 1200.0,
            };
        }
        return null;
    }
};

/// Trident projectile attack result emitted by a Drowned guard.
pub const TridentAttackResult = struct {
    origin: [3]f32,
    target: [3]f32,
    distance: f32,
    damage: f32 = 8.0,
    speed: f32 = 1.6,
};

/// Ocean Ruin Drowned Guard:
/// - Persistent structure guard: doesNotDespawn = true
/// - 6.25% chance (1 in 16) to spawn holding a Trident
/// - 3% chance to spawn holding a Nautilus Shell in offhand
/// - Firing tridents every 1.5 seconds at targets within 20.0m
pub const OceanRuinDrownedGuard = struct {
    pub const doesNotDespawn_default: bool = true;
    pub const trident_spawn_chance: f32 = 0.0625; // 1 in 16 = 6.25%
    pub const nautilus_shell_spawn_chance: f32 = 0.03; // 3%
    pub const trident_attack_cooldown_seconds: f32 = 1.5;
    pub const trident_attack_range: f32 = 20.0; // 20.0m
    pub const base_health: f32 = 20.0;

    doesNotDespawn: bool = true,
    has_trident: bool = false,
    has_nautilus_shell: bool = false,
    attack_cooldown: f32 = 0.0,
    pos: [3]f32 = .{ 0.0, 0.0, 0.0 },
    health: f32 = base_health,

    pub fn init(pos: [3]f32, roll_mainhand: f32, roll_offhand: f32) OceanRuinDrownedGuard {
        return .{
            .doesNotDespawn = true,
            .has_trident = roll_mainhand < trident_spawn_chance and roll_mainhand >= 0.0,
            .has_nautilus_shell = roll_offhand < nautilus_shell_spawn_chance and roll_offhand >= 0.0,
            .attack_cooldown = 0.0,
            .pos = pos,
            .health = base_health,
        };
    }

    pub fn spawnFromSeed(pos: [3]f32, seed: u64) OceanRuinDrownedGuard {
        var prng = std.Random.DefaultPrng.init(seed);
        const main_roll = prng.random().float(f32);
        const off_roll = prng.random().float(f32);
        return init(pos, main_roll, off_roll);
    }

    pub fn canAttackTarget(self: OceanRuinDrownedGuard, target_dist: f32) bool {
        if (!self.has_trident) return false;
        if (target_dist < 0.0 or target_dist > trident_attack_range) return false;
        return self.attack_cooldown <= 0.0;
    }

    /// Advances guard attack cooldown and fires trident if a valid target is within 20.0m.
    pub fn tick(self: *OceanRuinDrownedGuard, dt: f32, target_pos: ?[3]f32) ?TridentAttackResult {
        if (dt > 0.0 and self.attack_cooldown > 0.0) {
            self.attack_cooldown = @max(0.0, self.attack_cooldown - dt);
        }

        if (target_pos) |t| {
            const dx = t[0] - self.pos[0];
            const dy = t[1] - self.pos[1];
            const dz = t[2] - self.pos[2];
            const dist = @sqrt(dx * dx + dy * dy + dz * dz);

            if (self.canAttackTarget(dist)) {
                self.attack_cooldown = trident_attack_cooldown_seconds;
                return TridentAttackResult{
                    .origin = self.pos,
                    .target = t,
                    .distance = dist,
                    .damage = 8.0,
                    .speed = 1.6,
                };
            }
        }
        return null;
    }
};

/// Enchantments on fishing rods found in ocean ruin chests.
pub const FishingRodEnchantment = enum {
    luck_of_the_sea,
    lure,
    luck_and_lure,

    pub fn name(self: FishingRodEnchantment) []const u8 {
        return switch (self) {
            .luck_of_the_sea => "Luck of the Sea II",
            .lure => "Lure II",
            .luck_and_lure => "Luck of the Sea II + Lure II",
        };
    }
};

/// Items found in ocean ruin chests.
pub const OceanRuinChestItemType = enum {
    buried_treasure_map,
    fishing_rod_enchanted,
    water_breathing_potion,
    emerald,
    wheat,
    golden_apple,
    coal,
    iron_axe,
    iron_ingot,
    leather_tunic,
    rotten_flesh,
};

/// A loot stack generated inside an ocean ruin chest.
pub const OceanRuinChestSlot = struct {
    item: OceanRuinChestItemType,
    count: u8 = 1,
    fishing_rod_enchant: ?FishingRodEnchantment = null,
    potion_duration_seconds: u16 = 180, // 3:00 min water breathing
    treasure_map_target: ?[2]i32 = null,
};

/// Ocean Ruin Chest Loot Generator:
/// Generates chest contents containing:
/// - Buried treasure map
/// - Fishing rod with Luck of the Sea / Lure
/// - Water breathing potion
/// - Emeralds
/// - Wheat
/// - Golden apple
pub const OceanRuinChestLoot = struct {
    pub const max_chest_slots: usize = 8;

    pub fn generateChestLoot(seed: u64, variant: OceanRuinBiomeVariant) [max_chest_slots]OceanRuinChestSlot {
        var prng = std.Random.DefaultPrng.init(seed);
        const rand = prng.random();

        var slots: [max_chest_slots]OceanRuinChestSlot = undefined;

        // Slot 0: Guaranteed or high-probability Buried Treasure Map
        const map_x = @as(i32, @intCast(rand.intRangeAtMost(i16, -1000, 1000)));
        const map_z = @as(i32, @intCast(rand.intRangeAtMost(i16, -1000, 1000)));
        slots[0] = .{
            .item = .buried_treasure_map,
            .count = 1,
            .treasure_map_target = .{ map_x, map_z },
        };

        // Slot 1: Enchanted Fishing Rod with Luck of the Sea / Lure
        const enchant_roll = rand.uintLessThan(u8, 3);
        const rod_enchant: FishingRodEnchantment = switch (enchant_roll) {
            0 => .luck_of_the_sea,
            1 => .lure,
            else => .luck_and_lure,
        };
        slots[1] = .{
            .item = .fishing_rod_enchanted,
            .count = 1,
            .fishing_rod_enchant = rod_enchant,
        };

        // Slot 2: Potion of Water Breathing (3 minutes or 8 minutes)
        const extended_potion = rand.boolean();
        slots[2] = .{
            .item = .water_breathing_potion,
            .count = 1,
            .potion_duration_seconds = if (extended_potion) 480 else 180,
        };

        // Slot 3: Emeralds (1-5)
        const emerald_count = rand.intRangeAtMost(u8, 1, 5);
        slots[3] = .{
            .item = .emerald,
            .count = emerald_count,
        };

        // Slot 4: Wheat (2-6)
        const wheat_count = rand.intRangeAtMost(u8, 2, 6);
        slots[4] = .{
            .item = .wheat,
            .count = wheat_count,
        };

        // Slot 5: Golden Apple
        slots[5] = .{
            .item = .golden_apple,
            .count = 1,
        };

        // Slot 6: Coal (1-4)
        slots[6] = .{
            .item = .coal,
            .count = rand.intRangeAtMost(u8, 1, 4),
        };

        // Slot 7: Variant specific gear (Iron Axe in cold ruins, Iron Ingot in warm ruins)
        slots[7] = switch (variant) {
            .cold_stone_brick_ruin => .{
                .item = .iron_axe,
                .count = 1,
            },
            .warm_sandstone_ruin => .{
                .item = .iron_ingot,
                .count = rand.intRangeAtMost(u8, 1, 3),
            },
        };

        return slots;
    }

    pub fn hasItem(slots: []const OceanRuinChestSlot, item: OceanRuinChestItemType) bool {
        for (slots) |s| {
            if (s.item == item) return true;
        }
        return false;
    }
};

/// Underwater Ocean Ruin structure representation.
pub const OceanRuinStructure = struct {
    pub const RuinClusterType = enum { single_ruin, sunken_village_cluster };

    variant: OceanRuinBiomeVariant,
    cluster_type: RuinClusterType,
    center_pos: [3]i32,
    drowned_guard_count: u8,
    suspicious_block_count: u8,
    has_loot_chest: bool = true,

    pub fn init(variant: OceanRuinBiomeVariant, cluster_type: RuinClusterType, pos: [3]i32) OceanRuinStructure {
        const drowned_count: u8 = if (cluster_type == .sunken_village_cluster) 5 else 2;
        const susp_count: u8 = if (cluster_type == .sunken_village_cluster) 8 else 3;
        return .{
            .variant = variant,
            .cluster_type = cluster_type,
            .center_pos = pos,
            .drowned_guard_count = drowned_count,
            .suspicious_block_count = susp_count,
            .has_loot_chest = true,
        };
    }

    /// Warm ruins feature magma blocks that generate underwater bubble columns
    /// pulling players and entities downwards towards the ocean floor.
    pub fn createsDownwardWhirlpool(self: OceanRuinStructure) bool {
        return self.variant.hasMagmaBlocks();
    }

    /// Cold ruins feature sea lanterns providing underwater illumination.
    pub fn emitsUnderwaterLight(self: OceanRuinStructure) bool {
        return self.variant.hasSeaLanterns();
    }
};

// =============================================================================
// Comprehensive Test Suite (16 test blocks)
// =============================================================================

test "1. OceanRuinBiomeVariant properties: cold vs warm ruin palettes" {
    const cold = OceanRuinBiomeVariant.cold_stone_brick_ruin;
    const warm = OceanRuinBiomeVariant.warm_sandstone_ruin;

    try std.testing.expect(cold.isCold());
    try std.testing.expect(!cold.isWarm());
    try std.testing.expect(!warm.isCold());
    try std.testing.expect(warm.isWarm());

    // Suspicious block association
    try std.testing.expectEqual(SuspiciousBlockType.suspicious_gravel, cold.suspiciousBlock());
    try std.testing.expectEqual(SuspiciousBlockType.suspicious_sand, warm.suspiciousBlock());

    // Primary building block
    try std.testing.expectEqual(OceanRuinBlock.stone_bricks, cold.primaryBuildingBlock());
    try std.testing.expectEqual(OceanRuinBlock.sandstone, warm.primaryBuildingBlock());

    // Light and magma properties
    try std.testing.expect(cold.hasSeaLanterns());
    try std.testing.expect(!cold.hasMagmaBlocks());
    try std.testing.expect(!warm.hasSeaLanterns());
    try std.testing.expect(warm.hasMagmaBlocks());

    // Structure block membership
    try std.testing.expect(cold.isValidStructureBlock(.stone_bricks));
    try std.testing.expect(cold.isValidStructureBlock(.mossy_stone_bricks));
    try std.testing.expect(cold.isValidStructureBlock(.cracked_stone_bricks));
    try std.testing.expect(cold.isValidStructureBlock(.sea_lantern));
    try std.testing.expect(cold.isValidStructureBlock(.suspicious_gravel));
    try std.testing.expect(!cold.isValidStructureBlock(.sandstone));
    try std.testing.expect(!cold.isValidStructureBlock(.magma_block));

    try std.testing.expect(warm.isValidStructureBlock(.sandstone));
    try std.testing.expect(warm.isValidStructureBlock(.chiseled_sandstone));
    try std.testing.expect(warm.isValidStructureBlock(.polished_granite));
    try std.testing.expect(warm.isValidStructureBlock(.magma_block));
    try std.testing.expect(warm.isValidStructureBlock(.suspicious_sand));
    try std.testing.expect(!warm.isValidStructureBlock(.stone_bricks));
    try std.testing.expect(!warm.isValidStructureBlock(.sea_lantern));
}

test "2. canExcavateSnifferEgg returns true exclusively for warm sandstone ruins" {
    const cold = OceanRuinBiomeVariant.cold_stone_brick_ruin;
    const warm = OceanRuinBiomeVariant.warm_sandstone_ruin;

    // Both method call and free function call
    try std.testing.expect(!cold.canExcavateSnifferEgg());
    try std.testing.expect(warm.canExcavateSnifferEgg());

    try std.testing.expect(!OceanRuinArchaeology.canExcavateSnifferEgg(cold));
    try std.testing.expect(OceanRuinArchaeology.canExcavateSnifferEgg(warm));

    try std.testing.expect(!canExcavateSnifferEgg(cold));
    try std.testing.expect(canExcavateSnifferEgg(warm));
}

test "3. OceanRuinArchaeology warm loot table contains sniffer egg and warm sherds" {
    const warm_table = OceanRuinArchaeology.getLootTable(.warm_sandstone_ruin);

    var has_sniffer_egg = false;
    var has_angler = false;
    var has_shelter = false;
    var has_snort = false;
    var has_blade = false;

    for (warm_table) |item| {
        if (item == .sniffer_egg) has_sniffer_egg = true;
        if (item == .angler_pottery_sherd) has_angler = true;
        if (item == .shelter_pottery_sherd) has_shelter = true;
        if (item == .snort_pottery_sherd) has_snort = true;
        if (item == .blade_pottery_sherd) has_blade = true;
    }

    try std.testing.expect(has_sniffer_egg);
    try std.testing.expect(has_angler);
    try std.testing.expect(has_shelter);
    try std.testing.expect(has_snort);
    // Cold-exclusive sherd must NOT be present in warm ruin table
    try std.testing.expect(!has_blade);
}

test "4. OceanRuinArchaeology cold loot table contains cold sherds and materials" {
    const cold_table = OceanRuinArchaeology.getLootTable(.cold_stone_brick_ruin);

    var has_blade = false;
    var has_explorer = false;
    var has_mourner = false;
    var has_plenty = false;
    var has_iron_axe = false;
    var has_emerald = false;
    var has_coal = false;
    var has_wheat = false;
    var has_sniffer_egg = false;

    for (cold_table) |item| {
        if (item == .blade_pottery_sherd) has_blade = true;
        if (item == .explorer_pottery_sherd) has_explorer = true;
        if (item == .mourner_pottery_sherd) has_mourner = true;
        if (item == .plenty_pottery_sherd) has_plenty = true;
        if (item == .iron_axe) has_iron_axe = true;
        if (item == .emerald) has_emerald = true;
        if (item == .coal) has_coal = true;
        if (item == .wheat) has_wheat = true;
        if (item == .sniffer_egg) has_sniffer_egg = true;
    }

    try std.testing.expect(has_blade);
    try std.testing.expect(has_explorer);
    try std.testing.expect(has_mourner);
    try std.testing.expect(has_plenty);
    try std.testing.expect(has_iron_axe);
    try std.testing.expect(has_emerald);
    try std.testing.expect(has_coal);
    try std.testing.expect(has_wheat);
    // Sniffer egg must NOT be present in cold ruin archaeology
    try std.testing.expect(!has_sniffer_egg);
}

test "5. OceanRuinArchaeology deterministic loot roll mapping" {
    // First element of warm table is sniffer_egg (roll = 0.0)
    const loot_zero = OceanRuinArchaeology.rollLoot(.warm_sandstone_ruin, 0.0);
    try std.testing.expectEqual(ArchaeologyLootItem.sniffer_egg, loot_zero);

    // Roll for cold ruin at 0.0 should be blade_pottery_sherd
    const cold_loot_zero = OceanRuinArchaeology.rollLoot(.cold_stone_brick_ruin, 0.0);
    try std.testing.expectEqual(ArchaeologyLootItem.blade_pottery_sherd, cold_loot_zero);

    // Roll near 0.999 should be gold_nugget
    const loot_high = OceanRuinArchaeology.rollLoot(.warm_sandstone_ruin, 0.99);
    try std.testing.expectEqual(ArchaeologyLootItem.gold_nugget, loot_high);

    // Test sherd classification helper
    try std.testing.expect(ArchaeologyLootItem.angler_pottery_sherd.isSherd());
    try std.testing.expect(ArchaeologyLootItem.blade_pottery_sherd.isSherd());
    try std.testing.expect(!ArchaeologyLootItem.sniffer_egg.isSherd());
    try std.testing.expect(!ArchaeologyLootItem.emerald.isSherd());
}

test "6. SuspiciousBlockState brushing stage progression to completion" {
    var state = SuspiciousBlockState.init(.warm_sandstone_ruin, .sniffer_egg);
    try std.testing.expectEqual(SuspiciousBlockType.suspicious_sand, state.block_type);
    try std.testing.expectEqual(@as(u8, 0), state.brush_stage);
    try std.testing.expect(!state.is_extracted);
    try std.testing.expectEqual(OceanRuinBlock.suspicious_sand, state.resultingBlock());

    // Stage 1
    try std.testing.expectEqual(@as(?ArchaeologyLootItem, null), state.brush());
    try std.testing.expectEqual(@as(u8, 1), state.brush_stage);
    try std.testing.expect(!state.is_extracted);

    // Stage 2
    try std.testing.expectEqual(@as(?ArchaeologyLootItem, null), state.brush());
    try std.testing.expectEqual(@as(u8, 2), state.brush_stage);

    // Stage 3
    try std.testing.expectEqual(@as(?ArchaeologyLootItem, null), state.brush());
    try std.testing.expectEqual(@as(u8, 3), state.brush_stage);

    // Stage 4: Extracted!
    const extracted = state.brush();
    try std.testing.expectEqual(@as(?ArchaeologyLootItem, .sniffer_egg), extracted);
    try std.testing.expectEqual(@as(u8, 4), state.brush_stage);
    try std.testing.expect(state.is_extracted);

    // Suspicious sand transforms into regular sand after brushing
    try std.testing.expectEqual(OceanRuinBlock.sand, state.resultingBlock());

    // Subsequent brushes do nothing
    try std.testing.expectEqual(@as(?ArchaeologyLootItem, null), state.brush());
}

test "7. SuspiciousBlockState suspicious gravel transforms to regular gravel" {
    var cold_block = SuspiciousBlockState.init(.cold_stone_brick_ruin, .blade_pottery_sherd);
    try std.testing.expectEqual(SuspiciousBlockType.suspicious_gravel, cold_block.block_type);
    try std.testing.expectEqual(OceanRuinBlock.suspicious_gravel, cold_block.resultingBlock());

    _ = cold_block.brush();
    _ = cold_block.brush();
    _ = cold_block.brush();
    const result = cold_block.brush();

    try std.testing.expectEqual(@as(?ArchaeologyLootItem, .blade_pottery_sherd), result);
    try std.testing.expectEqual(OceanRuinBlock.gravel, cold_block.resultingBlock());
}

test "8. SnifferEggHatching hatchDurationSeconds on regular block vs moss block" {
    // Regular block: 20.0 minutes = 1200.0 seconds
    const reg_seconds = hatchDurationSeconds(false);
    try std.testing.expectApproxEqAbs(@as(f32, 1200.0), reg_seconds, 0.001);

    // Moss block: 10.0 minutes = 600.0 seconds (2x speed)
    const moss_seconds = hatchDurationSeconds(true);
    try std.testing.expectApproxEqAbs(@as(f32, 600.0), moss_seconds, 0.001);

    // Confirm 2x speed ratio
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), reg_seconds / moss_seconds, 0.001);

    // SnifferEggHatching struct constants check
    try std.testing.expectEqual(@as(f32, 1200.0), SnifferEggHatching.regular_hatch_duration_seconds);
    try std.testing.expectEqual(@as(f32, 600.0), SnifferEggHatching.moss_hatch_duration_seconds);
    try std.testing.expectEqual(@as(f32, 2.0), SnifferEggHatching.moss_speed_multiplier);
}

test "9. SnifferEggState progression through cracking stages on regular blocks" {
    var egg = SnifferEggState.init(false); // regular block (1200s)
    try std.testing.expectEqual(EggCrackStage.intact, egg.stage);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), egg.progressRatio(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1200.0), egg.remainingSeconds(), 0.001);

    // Advance 300s (25% progress) -> intact
    try std.testing.expectEqual(@as(?Snifflet, null), egg.tick(300.0));
    try std.testing.expectEqual(EggCrackStage.intact, egg.stage);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), egg.progressRatio(), 0.001);

    // Advance to 400s total (33.33% progress) -> cracked
    try std.testing.expectEqual(@as(?Snifflet, null), egg.tick(100.0));
    try std.testing.expectEqual(EggCrackStage.cracked, egg.stage);

    // Advance to 800s total (66.67% progress) -> near_hatching
    try std.testing.expectEqual(@as(?Snifflet, null), egg.tick(400.0));
    try std.testing.expectEqual(EggCrackStage.near_hatching, egg.stage);

    // Advance remaining 400s (1200s total) -> hatched with Snifflet
    const hatched_snifflet = egg.tick(400.0);
    try std.testing.expect(hatched_snifflet != null);
    try std.testing.expectEqual(EggCrackStage.hatched, egg.stage);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), egg.progressRatio(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), egg.remainingSeconds(), 0.001);
}

test "10. SnifferEggState accelerated hatching on moss block (2x speed, 600s)" {
    var egg = SnifferEggState.init(true); // on moss block
    try std.testing.expectApproxEqAbs(@as(f32, 600.0), egg.targetDurationSeconds(), 0.001);

    // Tick 300s -> 50% progress (already cracked!)
    try std.testing.expectEqual(@as(?Snifflet, null), egg.tick(300.0));
    try std.testing.expectEqual(EggCrackStage.cracked, egg.stage);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), egg.progressRatio(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), egg.remainingSeconds(), 0.001);

    // Tick another 300s -> completes at 600s and hatches
    const snifflet_opt = egg.tick(300.0);
    try std.testing.expect(snifflet_opt != null);
    const snifflet = snifflet_opt.?;
    try std.testing.expect(snifflet.is_baby);
    try std.testing.expectEqual(@as(f32, 0.0), snifflet.age_seconds);
    try std.testing.expectEqual(EggCrackStage.hatched, egg.stage);
}

test "11. Snifflet growth into adult Sniffer" {
    var snifflet = Snifflet{
        .is_baby = true,
        .age_seconds = 0.0,
        .growth_duration_seconds = 1200.0,
    };
    try std.testing.expect(!snifflet.isAdult());

    snifflet.tick(600.0);
    try std.testing.expect(snifflet.is_baby);
    try std.testing.expect(!snifflet.isAdult());

    snifflet.tick(600.0);
    try std.testing.expect(snifflet.isAdult());
    try std.testing.expect(!snifflet.is_baby);
}

test "12. OceanRuinDrownedGuard persistence flag doesNotDespawn is true" {
    const guard_default = OceanRuinDrownedGuard.init(.{ 10.0, 30.0, -100.0 }, 0.5, 0.5);
    try std.testing.expect(guard_default.doesNotDespawn);

    const guard_seed = OceanRuinDrownedGuard.spawnFromSeed(.{ 0.0, 20.0, 0.0 }, 12345);
    try std.testing.expect(guard_seed.doesNotDespawn);
    try std.testing.expect(OceanRuinDrownedGuard.doesNotDespawn_default);
}

test "13. OceanRuinDrownedGuard equipment spawn chances (6.25% trident, 3% nautilus shell)" {
    // Roll < 0.0625 spawns trident
    const trident_guard = OceanRuinDrownedGuard.init(.{ 0, 0, 0 }, 0.0624, 0.5);
    try std.testing.expect(trident_guard.has_trident);
    try std.testing.expect(!trident_guard.has_nautilus_shell);

    // Roll >= 0.0625 does not spawn trident
    const no_trident_guard = OceanRuinDrownedGuard.init(.{ 0, 0, 0 }, 0.0625, 0.5);
    try std.testing.expect(!no_trident_guard.has_trident);

    // Roll < 0.03 spawns nautilus shell
    const shell_guard = OceanRuinDrownedGuard.init(.{ 0, 0, 0 }, 0.5, 0.0299);
    try std.testing.expect(shell_guard.has_nautilus_shell);
    try std.testing.expect(!shell_guard.has_trident);

    // Roll >= 0.03 does not spawn nautilus shell
    const no_shell_guard = OceanRuinDrownedGuard.init(.{ 0, 0, 0 }, 0.5, 0.03);
    try std.testing.expect(!no_shell_guard.has_nautilus_shell);

    // Dual wielder (both trident and nautilus shell)
    const dual_wielder = OceanRuinDrownedGuard.init(.{ 0, 0, 0 }, 0.01, 0.01);
    try std.testing.expect(dual_wielder.has_trident);
    try std.testing.expect(dual_wielder.has_nautilus_shell);

    // Verify constant values
    try std.testing.expectEqual(@as(f32, 0.0625), OceanRuinDrownedGuard.trident_spawn_chance);
    try std.testing.expectEqual(@as(f32, 0.03), OceanRuinDrownedGuard.nautilus_shell_spawn_chance);
}

test "14. OceanRuinDrownedGuard trident attack range (20.0m) and cooldown (1.5s)" {
    var guard = OceanRuinDrownedGuard.init(.{ 0.0, 10.0, 0.0 }, 0.01, 0.5); // Has trident
    try std.testing.expect(guard.has_trident);

    // Target at 15.0m (within 20.0m range)
    const target_close: [3]f32 = .{ 15.0, 10.0, 0.0 };
    try std.testing.expect(guard.canAttackTarget(15.0));

    // Attack!
    const attack_result = guard.tick(0.0, target_close);
    try std.testing.expect(attack_result != null);
    const attack = attack_result.?;
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), attack.distance, 0.01);
    try std.testing.expectEqual(@as(f32, 8.0), attack.damage);

    // Attack cooldown is now set to 1.5 seconds
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), guard.attack_cooldown, 0.001);
    try std.testing.expect(!guard.canAttackTarget(15.0));

    // Tick 1.0 second -> cooldown remains 0.5s, cannot attack yet
    const mid_attack = guard.tick(1.0, target_close);
    try std.testing.expect(mid_attack == null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), guard.attack_cooldown, 0.001);

    // Tick remaining 0.5s -> cooldown reset, fires again!
    const ready_attack = guard.tick(0.5, target_close);
    try std.testing.expect(ready_attack != null);

    // Target at 25.0m (exceeds 20.0m range) -> cannot attack
    guard.attack_cooldown = 0.0;
    const target_far: [3]f32 = .{ 25.0, 10.0, 0.0 };
    try std.testing.expect(!guard.canAttackTarget(25.0));
    try std.testing.expectEqual(@as(?TridentAttackResult, null), guard.tick(0.0, target_far));
}

test "15. OceanRuinChestLoot contains all required ocean ruin items" {
    const cold_loot = OceanRuinChestLoot.generateChestLoot(42, .cold_stone_brick_ruin);
    const warm_loot = OceanRuinChestLoot.generateChestLoot(99, .warm_sandstone_ruin);

    // Verify all 6 mandatory item types:
    // 1. Buried treasure map
    try std.testing.expect(OceanRuinChestLoot.hasItem(&cold_loot, .buried_treasure_map));
    try std.testing.expect(OceanRuinChestLoot.hasItem(&warm_loot, .buried_treasure_map));

    // 2. Fishing rod with Luck of the Sea / Lure
    try std.testing.expect(OceanRuinChestLoot.hasItem(&cold_loot, .fishing_rod_enchanted));
    try std.testing.expect(OceanRuinChestLoot.hasItem(&warm_loot, .fishing_rod_enchanted));

    // 3. Water breathing potion
    try std.testing.expect(OceanRuinChestLoot.hasItem(&cold_loot, .water_breathing_potion));
    try std.testing.expect(OceanRuinChestLoot.hasItem(&warm_loot, .water_breathing_potion));

    // 4. Emeralds
    try std.testing.expect(OceanRuinChestLoot.hasItem(&cold_loot, .emerald));
    try std.testing.expect(OceanRuinChestLoot.hasItem(&warm_loot, .emerald));

    // 5. Wheat
    try std.testing.expect(OceanRuinChestLoot.hasItem(&cold_loot, .wheat));
    try std.testing.expect(OceanRuinChestLoot.hasItem(&warm_loot, .wheat));

    // 6. Golden Apple
    try std.testing.expect(OceanRuinChestLoot.hasItem(&cold_loot, .golden_apple));
    try std.testing.expect(OceanRuinChestLoot.hasItem(&warm_loot, .golden_apple));

    // Check fishing rod enchantments are valid Luck of the Sea or Lure
    for (cold_loot) |slot| {
        if (slot.item == .fishing_rod_enchanted) {
            try std.testing.expect(slot.fishing_rod_enchant != null);
        }
        if (slot.item == .water_breathing_potion) {
            try std.testing.expect(slot.potion_duration_seconds >= 180);
        }
        if (slot.item == .buried_treasure_map) {
            try std.testing.expect(slot.treasure_map_target != null);
        }
    }
}

test "16. OceanRuinStructure whirlpool bubble columns vs light emission" {
    const cold_ruin = OceanRuinStructure.init(.cold_stone_brick_ruin, .sunken_village_cluster, .{ 100, 25, 200 });
    const warm_ruin = OceanRuinStructure.init(.warm_sandstone_ruin, .single_ruin, .{ -50, 28, -80 });

    // Cold ruin emits light via sea lanterns, does not create magma whirlpool
    try std.testing.expect(cold_ruin.emitsUnderwaterLight());
    try std.testing.expect(!cold_ruin.createsDownwardWhirlpool());
    try std.testing.expectEqual(@as(u8, 5), cold_ruin.drowned_guard_count);
    try std.testing.expectEqual(@as(u8, 8), cold_ruin.suspicious_block_count);

    // Warm ruin creates magma whirlpool (downward bubble column), no sea lantern illumination
    try std.testing.expect(!warm_ruin.emitsUnderwaterLight());
    try std.testing.expect(warm_ruin.createsDownwardWhirlpool());
    try std.testing.expectEqual(@as(u8, 2), warm_ruin.drowned_guard_count);
    try std.testing.expectEqual(@as(u8, 3), warm_ruin.suspicious_block_count);
}
