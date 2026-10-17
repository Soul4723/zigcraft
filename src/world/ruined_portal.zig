//! Ruined Portals, Crying Obsidian Frame Incompatibility, Gold Block Monuments & Enchanted Gold Loot
//! Milestone 382: Implements ruined portal generation geometry, frame validation rules,
//! chest loot generation with guaranteed igniters, and portal repair requirements.

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Minimum netherrack spread apron radius surrounding a ruined portal.
pub const MIN_NETHERRACK_APRON_RADIUS: u4 = 4;

/// Maximum netherrack spread apron radius surrounding a ruined portal.
pub const MAX_NETHERRACK_APRON_RADIUS: u4 = 7;

/// Minimum number of gold blocks crowning a ruined portal monument.
pub const MIN_GOLD_BLOCK_CROWN: u8 = 1;

/// Maximum number of gold blocks crowning a ruined portal monument.
pub const MAX_GOLD_BLOCK_CROWN: u8 = 2;

/// Standard 4x5 Nether Portal non-corner perimeter edge blocks required to complete a functional frame.
/// 2 sill (bottom) + 2 lintel (top) + 3 left jamb + 3 right jamb = 10 blocks.
pub const REQUIRED_PORTAL_EDGE_BLOCKS: u8 = 10;

/// Total 4x5 frame perimeter blocks when including optional corners (10 edges + 4 corners).
pub const TOTAL_PORTAL_FRAME_BLOCKS_WITH_CORNERS: u8 = 14;

/// Crying Obsidian block hardness (mining resistance).
pub const CRYING_OBSIDIAN_HARDNESS: f32 = 50.0;
pub const crying_obsidian_hardness: f32 = 50.0;

/// Emissive light level produced by crying obsidian veins (light level 10).
pub const CRYING_OBSIDIAN_LIGHT_LEVEL: u8 = 10;
pub const crying_obsidian_light_level: u8 = 10;

/// Identifier for purple crying tear drip particles emitted by crying obsidian.
pub const CRYING_OBSIDIAN_PARTICLES: []const u8 = "purple_dripping_tear";
pub const crying_obsidian_particles: []const u8 = "purple_dripping_tear";

/// Gold equipment high enchantability factor (Level 22), granting superior enchantment rolls.
pub const gold_enchantability: u8 = 22;
pub const GOLD_ENCHANTABILITY: u8 = 22;

/// Maximum number of items in a ruined portal chest inventory.
pub const MAX_CHEST_SLOTS: usize = 8;

// ============================================================================
// RuinedPortalPlacement & Monument Geometry
// ============================================================================

/// Placement environments where ruined portals generate across the Overworld and Nether.
pub const RuinedPortalPlacement = enum {
    surface,
    underground,
    underwater,
    nether,

    pub const min_apron_radius: u4 = MIN_NETHERRACK_APRON_RADIUS;
    pub const max_apron_radius: u4 = MAX_NETHERRACK_APRON_RADIUS;
    pub const min_gold_blocks: u8 = MIN_GOLD_BLOCK_CROWN;
    pub const max_gold_blocks: u8 = MAX_GOLD_BLOCK_CROWN;

    /// Checks if this placement is in the Overworld.
    pub fn isOverworld(self: RuinedPortalPlacement) bool {
        return self != .nether;
    }

    /// Underwater ruined portals generate waterlogged chests and water-submerged frames.
    pub fn isWaterlogged(self: RuinedPortalPlacement) bool {
        return self == .underwater;
    }

    /// Surface and nether portals typically feature an adjacent lava pocket.
    pub fn hasLavaPocket(self: RuinedPortalPlacement) bool {
        return self == .surface or self == .nether;
    }

    /// Whether this placement is subterranean.
    pub fn isUnderground(self: RuinedPortalPlacement) bool {
        return self == .underground;
    }
};

/// Validates whether a netherrack apron radius is within the canonical 4..7 range.
pub fn isValidApronRadius(radius: u4) bool {
    return radius >= MIN_NETHERRACK_APRON_RADIUS and radius <= MAX_NETHERRACK_APRON_RADIUS;
}

/// Validates whether a gold block crown count is within the canonical 1..2 range.
pub fn isValidGoldBlockCrown(count: u8) bool {
    return count >= MIN_GOLD_BLOCK_CROWN and count <= MAX_GOLD_BLOCK_CROWN;
}

/// Checks whether relative coordinates (dx, dz) fall within the netherrack spread apron.
pub fn isCoordinateInNetherrackApron(dx: i32, dz: i32, radius: u4) bool {
    if (!isValidApronRadius(radius)) return false;
    const r: i32 = @as(i32, radius);
    return (dx * dx + dz * dz) <= (r * r);
}

/// Computes the total number of horizontal surface blocks covered by a circular apron of radius r.
pub fn computeApronBlockCoverage(radius: u4) u32 {
    if (!isValidApronRadius(radius)) return 0;
    const r: i32 = @as(i32, radius);
    var count: u32 = 0;
    var x: i32 = -r;
    while (x <= r) : (x += 1) {
        var z: i32 = -r;
        while (z <= r) : (z += 1) {
            if (x * x + z * z <= r * r) {
                count += 1;
            }
        }
    }
    return count;
}

/// Represents a generated Ruined Portal monument structure and its decorative components.
pub const RuinedPortalMonument = struct {
    placement: RuinedPortalPlacement,
    netherrack_apron_radius: u4,
    gold_block_crown: u8,
    magma_blocks: u8,
    iron_bars: u8,
    stone_bricks: u8,
    crying_obsidian_blocks: u8,
    obsidian_blocks: u8,
    is_waterlogged: bool,
    has_loot_chest: bool = true,

    pub fn init(
        placement: RuinedPortalPlacement,
        apron_radius: u4,
        gold_blocks: u8,
        magma_blocks: u8,
        iron_bars: u8,
        stone_bricks: u8,
        crying_obsidian: u8,
        obsidian: u8,
    ) !RuinedPortalMonument {
        if (!isValidApronRadius(apron_radius)) return error.InvalidApronRadius;
        if (!isValidGoldBlockCrown(gold_blocks)) return error.InvalidGoldBlockCount;
        return .{
            .placement = placement,
            .netherrack_apron_radius = apron_radius,
            .gold_block_crown = gold_blocks,
            .magma_blocks = magma_blocks,
            .iron_bars = iron_bars,
            .stone_bricks = stone_bricks,
            .crying_obsidian_blocks = crying_obsidian,
            .obsidian_blocks = obsidian,
            .is_waterlogged = placement == .underwater,
            .has_loot_chest = true,
        };
    }
};

/// Deterministically generates a Ruined Portal monument with randomized apron, gold crown,
/// magma blocks, iron bars, and stone bricks.
pub fn generateRuinedPortalMonument(
    placement: RuinedPortalPlacement,
    seed: u64,
) RuinedPortalMonument {
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    // netherrack_apron_radius between 4 and 7 inclusive
    const radius_offset = random.uintLessThan(u4, 4); // 0..3
    const apron_radius: u4 = MIN_NETHERRACK_APRON_RADIUS + radius_offset; // 4..7

    // gold_block_crown: 1 or 2 gold blocks
    const gold_count: u8 = if (random.boolean()) 1 else 2;

    // other decorative materials
    const magma_count: u8 = 2 + @as(u8, @intCast(random.uintLessThan(u32, 5))); // 2..6
    const bars_count: u8 = 1 + @as(u8, @intCast(random.uintLessThan(u32, 4))); // 1..4
    const stone_bricks_count: u8 = 4 + @as(u8, @intCast(random.uintLessThan(u32, 7))); // 4..10

    // frame composition: 1..4 crying obsidian, 6..10 normal obsidian
    const crying_count: u8 = 1 + @as(u8, @intCast(random.uintLessThan(u32, 4)));
    const obsidian_count: u8 = 6 + @as(u8, @intCast(random.uintLessThan(u32, 5)));

    return RuinedPortalMonument.init(
        placement,
        apron_radius,
        gold_count,
        magma_count,
        bars_count,
        stone_bricks_count,
        crying_count,
        obsidian_count,
    ) catch unreachable;
}

// ============================================================================
// Portal Frame Validation & Crying Obsidian Incompatibility
// ============================================================================

/// Tool harvest tiers for mining checks.
pub const PickaxeTier = enum {
    none,
    wooden,
    stone,
    iron,
    golden,
    diamond,
    netherite,

    /// Only diamond and netherite pickaxes meet the tier requirement to harvest crying obsidian.
    pub fn canHarvestCryingObsidian(self: PickaxeTier) bool {
        return self == .diamond or self == .netherite;
    }

    /// Speed multiplier for each pickaxe tier.
    pub fn speedMultiplier(self: PickaxeTier) f32 {
        return switch (self) {
            .none => 1.0,
            .wooden => 2.0,
            .stone => 4.0,
            .iron => 6.0,
            .diamond => 8.0,
            .netherite => 9.0,
            .golden => 12.0,
        };
    }
};

/// Returns whether a tool of the given pickaxe tier can successfully mine and harvest crying obsidian.
pub fn canHarvestCryingObsidian(tier: PickaxeTier) bool {
    return tier.canHarvestCryingObsidian();
}

/// Returns whether a tool by canonical name can harvest crying obsidian.
pub fn canHarvestCryingObsidianWithToolName(tool_name: []const u8) bool {
    return std.mem.eql(u8, tool_name, "diamond_pickaxe") or
        std.mem.eql(u8, tool_name, "netherite_pickaxe");
}

/// Structural properties and harvest mechanics for Crying Obsidian.
pub const CryingObsidianProps = struct {
    pub const hardness: f32 = CRYING_OBSIDIAN_HARDNESS;
    pub const light_level: u8 = CRYING_OBSIDIAN_LIGHT_LEVEL;
    pub const particles: []const u8 = CRYING_OBSIDIAN_PARTICLES;
    pub const requires_diamond_or_netherite: bool = true;

    pub fn canHarvest(tier: PickaxeTier) bool {
        return tier.canHarvestCryingObsidian();
    }

    /// Calculates seconds required to mine crying obsidian with the specified pickaxe tier.
    /// If an inadequate tool is used, the time is hardness * 5.0 = 250.0 seconds and drops nothing.
    pub fn calculateMiningTimeSeconds(tier: PickaxeTier) f32 {
        if (!tier.canHarvestCryingObsidian()) {
            return hardness * 5.0;
        }
        return (hardness * 1.5) / tier.speedMultiplier();
    }
};

/// Checks if a 4x5 Nether Portal frame can ignite.
/// Any Crying Obsidian in a required edge position strictly blocks ignition.
/// All 10 required edge blocks must be regular Obsidian.
pub fn canActivateFrameWithCryingObsidian(crying_obsidian_in_edge: u8, obsidian_in_edge: u8) bool {
    if (crying_obsidian_in_edge > 0) return false;
    return obsidian_in_edge >= REQUIRED_PORTAL_EDGE_BLOCKS;
}

/// Block classification for examining individual portal frame slots.
pub const PortalBlockKind = enum {
    air,
    obsidian,
    crying_obsidian,
    other,
};

/// Detailed diagnostic of a portal frame edge configuration.
pub const PortalFrameValidation = struct {
    obsidian_in_edge: u8,
    crying_obsidian_in_edge: u8,
    missing_in_edge: u8,
    can_ignite: bool,
    rejection_reason: ?[]const u8,

    pub fn init(crying_obsidian: u8, obsidian: u8) PortalFrameValidation {
        const can_ignite = canActivateFrameWithCryingObsidian(crying_obsidian, obsidian);
        var reason: ?[]const u8 = null;
        if (crying_obsidian > 0) {
            reason = "Crying obsidian in edge blocks portal ignition";
        } else if (obsidian < REQUIRED_PORTAL_EDGE_BLOCKS) {
            reason = "Incomplete frame: missing required obsidian blocks";
        }

        const missing = if (obsidian + crying_obsidian < REQUIRED_PORTAL_EDGE_BLOCKS)
            REQUIRED_PORTAL_EDGE_BLOCKS - (obsidian + crying_obsidian)
        else
            0;

        return .{
            .obsidian_in_edge = obsidian,
            .crying_obsidian_in_edge = crying_obsidian,
            .missing_in_edge = missing,
            .can_ignite = can_ignite,
            .rejection_reason = reason,
        };
    }
};

/// Analyzes an array of 10 required frame edge blocks and returns validation details.
pub fn analyzeFrameEdges(edge_blocks: [10]PortalBlockKind) PortalFrameValidation {
    var obs: u8 = 0;
    var crying: u8 = 0;

    for (edge_blocks) |b| {
        switch (b) {
            .obsidian => obs += 1,
            .crying_obsidian => crying += 1,
            .air, .other => {},
        }
    }

    return PortalFrameValidation.init(crying, obs);
}

// ============================================================================
// Ruined Portal Chest Loot & Enchanted Gold Items
// ============================================================================

/// Possible items found inside a Ruined Portal chest.
pub const RuinedPortalLootItem = enum {
    flint_and_steel,
    fire_charge,
    obsidian,
    crying_obsidian,
    golden_apple,
    enchanted_golden_apple,
    glistering_melon,
    lodestone,
    gold_nugget,
    gold_ingot,
    gold_block,
    golden_sword,
    golden_pickaxe,
    golden_axe,
    golden_shovel,
    golden_hoe,
    golden_helmet,
    golden_chestplate,
    golden_leggings,
    golden_boots,
    golden_horse_armor,
    iron_nugget,

    /// Whether this item functions as an ignition source to light the Nether Portal.
    pub fn isIgniter(self: RuinedPortalLootItem) bool {
        return self == .flint_and_steel or self == .fire_charge;
    }

    /// Whether this item is golden armor or tool equipment.
    pub fn isGoldenEquipment(self: RuinedPortalLootItem) bool {
        return switch (self) {
            .golden_sword,
            .golden_pickaxe,
            .golden_axe,
            .golden_shovel,
            .golden_hoe,
            .golden_helmet,
            .golden_chestplate,
            .golden_leggings,
            .golden_boots,
            .golden_horse_armor,
            => true,
            else => false,
        };
    }

    /// Enchantability modifier for items. Gold equipment has high enchantability (22).
    pub fn enchantability(self: RuinedPortalLootItem) u8 {
        if (self.isGoldenEquipment()) return gold_enchantability;
        return 0;
    }
};

/// Returns standard material enchantability across item tiers for comparison.
pub fn getMaterialEnchantability(material_name: []const u8) u8 {
    if (std.mem.eql(u8, material_name, "gold")) return gold_enchantability;
    if (std.mem.eql(u8, material_name, "netherite")) return 15;
    if (std.mem.eql(u8, material_name, "iron")) return 14;
    if (std.mem.eql(u8, material_name, "diamond")) return 10;
    if (std.mem.eql(u8, material_name, "stone")) return 5;
    if (std.mem.eql(u8, material_name, "wood")) return 15;
    if (std.mem.eql(u8, material_name, "leather")) return 15;
    return 0;
}

/// An individual item slot in a chest inventory.
pub const LootSlot = struct {
    item: RuinedPortalLootItem,
    count: u8,
    is_enchanted: bool = false,
    enchantment_level: u8 = 0,
};

/// Represents generated Ruined Portal chest loot.
pub const RuinedPortalChestLoot = struct {
    slots: [MAX_CHEST_SLOTS]LootSlot,
    slot_count: usize,
    obsidian_repair_count: u8,
    igniter_item: RuinedPortalLootItem,
    has_golden_apple: bool,
    has_enchanted_golden_apple: bool,
    has_glistering_melon: bool,
    has_lodestone: bool,
    has_enchanted_gold_gear: bool,

    /// Verifies that at least one guaranteed portal igniter (flint & steel or fire charges) is present.
    pub fn hasGuaranteedIgniter(self: RuinedPortalChestLoot) bool {
        for (self.slots[0..self.slot_count]) |slot| {
            if (slot.item.isIgniter() and slot.count >= 1) return true;
        }
        return false;
    }

    /// Computes total normal obsidian blocks present in the chest loot.
    pub fn getObsidianCount(self: RuinedPortalChestLoot) u8 {
        var total: u8 = 0;
        for (self.slots[0..self.slot_count]) |slot| {
            if (slot.item == .obsidian) total += slot.count;
        }
        return total;
    }

    /// Verifies whether the chest contains enchanted golden equipment.
    pub fn hasEnchantedGoldGear(self: RuinedPortalChestLoot) bool {
        for (self.slots[0..self.slot_count]) |slot| {
            if (slot.item.isGoldenEquipment() and slot.is_enchanted) return true;
        }
        return false;
    }

    /// Verifies whether a specific loot item is contained in the chest.
    pub fn hasItem(self: RuinedPortalChestLoot, item: RuinedPortalLootItem) bool {
        for (self.slots[0..self.slot_count]) |slot| {
            if (slot.item == item) return true;
        }
        return false;
    }
};

/// Deterministically generates Ruined Portal chest loot adhering to all guaranteed and weighted items.
pub fn generateRuinedPortalChestLoot(seed: u64) RuinedPortalChestLoot {
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    var slots: [MAX_CHEST_SLOTS]LootSlot = undefined;
    var count: usize = 0;

    // 1. Guaranteed portal igniter: flint and steel (count 1) or fire charges (count 1..3)
    const is_flint_steel = random.boolean();
    const igniter: RuinedPortalLootItem = if (is_flint_steel) .flint_and_steel else .fire_charge;
    const igniter_count: u8 = if (is_flint_steel) 1 else (1 + @as(u8, @intCast(random.uintLessThan(u32, 3))));
    slots[count] = .{
        .item = igniter,
        .count = igniter_count,
    };
    count += 1;

    // 2. Obsidian: 1..4 blocks to repair frame
    const obsidian_amount: u8 = 1 + @as(u8, @intCast(random.uintLessThan(u32, 4))); // 1..4
    slots[count] = .{
        .item = .obsidian,
        .count = obsidian_amount,
    };
    count += 1;

    // 3. Golden tools/armor with high enchantability (22)
    const gold_items = [_]RuinedPortalLootItem{
        .golden_sword,
        .golden_pickaxe,
        .golden_axe,
        .golden_shovel,
        .golden_hoe,
        .golden_helmet,
        .golden_chestplate,
        .golden_leggings,
        .golden_boots,
    };
    const gold_idx = random.uintLessThan(usize, gold_items.len);
    // Enchantment level scaled by gold enchantability (22)
    const enchant_level: u8 = 15 + @as(u8, @intCast(random.uintLessThan(u32, 16))); // 15..30
    slots[count] = .{
        .item = gold_items[gold_idx],
        .count = 1,
        .is_enchanted = true,
        .enchantment_level = enchant_level,
    };
    count += 1;

    // 4. Gold nuggets (4..24)
    const nuggets = 4 + @as(u8, @intCast(random.uintLessThan(u32, 21)));
    slots[count] = .{
        .item = .gold_nugget,
        .count = nuggets,
    };
    count += 1;

    // 5. Crying obsidian (1..2) or Glistering Melon slice (1..3)
    var has_glistering = false;
    if (random.boolean()) {
        slots[count] = .{ .item = .glistering_melon, .count = 1 + @as(u8, @intCast(random.uintLessThan(u32, 3))) };
        has_glistering = true;
    } else {
        slots[count] = .{ .item = .crying_obsidian, .count = 1 + @as(u8, @intCast(random.uintLessThan(u32, 2))) };
    }
    count += 1;

    // 6. Rare high-tier rolls: Enchanted Golden Apple (3%), Golden Apple (22%), Lodestone (15%)
    var has_gapple = false;
    var has_egapple = false;
    var has_lodestone = false;
    const rare_roll = random.uintLessThan(u32, 100);
    if (rare_roll < 3) {
        slots[count] = .{ .item = .enchanted_golden_apple, .count = 1 };
        has_egapple = true;
        count += 1;
    } else if (rare_roll < 25) {
        slots[count] = .{ .item = .golden_apple, .count = 1 };
        has_gapple = true;
        count += 1;
    } else if (rare_roll < 40) {
        slots[count] = .{ .item = .lodestone, .count = 1 };
        has_lodestone = true;
        count += 1;
    }

    return .{
        .slots = slots,
        .slot_count = count,
        .obsidian_repair_count = obsidian_amount,
        .igniter_item = igniter,
        .has_golden_apple = has_gapple,
        .has_enchanted_golden_apple = has_egapple,
        .has_glistering_melon = has_glistering,
        .has_lodestone = has_lodestone,
        .has_enchanted_gold_gear = true,
    };
}

// ============================================================================
// Portal Repair Calculation
// ============================================================================

/// Computes the total number of regular obsidian blocks required to restore a ruined portal:
/// missing_edge_blocks + crying_obsidian_edge_blocks.
pub fn computeObsidianNeededToComplete(missing_edge_blocks: u8, crying_obsidian_edge_blocks: u8) u8 {
    return missing_edge_blocks + crying_obsidian_edge_blocks;
}

/// Alias for computeObsidianNeededToComplete.
pub fn calculatePortalRepair(missing_edge_blocks: u8, crying_obsidian_edge_blocks: u8) u8 {
    return missing_edge_blocks + crying_obsidian_edge_blocks;
}

/// Structure encapsulating ruined portal repair requirements and feasibility checks.
pub const PortalRepairCalculation = struct {
    missing_edge_blocks: u8,
    crying_obsidian_edge_blocks: u8,
    obsidian_needed_to_complete: u8,

    pub fn compute(missing_edge_blocks: u8, crying_obsidian_edge_blocks: u8) PortalRepairCalculation {
        return .{
            .missing_edge_blocks = missing_edge_blocks,
            .crying_obsidian_edge_blocks = crying_obsidian_edge_blocks,
            .obsidian_needed_to_complete = missing_edge_blocks + crying_obsidian_edge_blocks,
        };
    }

    /// Checks if a player with `available_obsidian` has enough blocks to repair the frame.
    pub fn canCompleteWithObsidian(self: PortalRepairCalculation, available_obsidian: u8) bool {
        return available_obsidian >= self.obsidian_needed_to_complete;
    }

    /// Checks if the obsidian found in the ruined portal chest is sufficient to complete the frame.
    pub fn canCompleteWithChest(self: PortalRepairCalculation, chest: RuinedPortalChestLoot) bool {
        return self.canCompleteWithObsidian(chest.getObsidianCount());
    }
};

// ============================================================================
// Tests
// ============================================================================

test "1. RuinedPortalPlacement variants and environmental classifications" {
    const surface: RuinedPortalPlacement = .surface;
    const underground: RuinedPortalPlacement = .underground;
    const underwater: RuinedPortalPlacement = .underwater;
    const nether: RuinedPortalPlacement = .nether;

    try std.testing.expect(surface.isOverworld());
    try std.testing.expect(underground.isOverworld());
    try std.testing.expect(underwater.isOverworld());
    try std.testing.expect(!nether.isOverworld());

    try std.testing.expect(underwater.isWaterlogged());
    try std.testing.expect(!surface.isWaterlogged());
    try std.testing.expect(!underground.isWaterlogged());
    try std.testing.expect(!nether.isWaterlogged());

    try std.testing.expect(surface.hasLavaPocket());
    try std.testing.expect(nether.hasLavaPocket());
    try std.testing.expect(!underwater.hasLavaPocket());
    try std.testing.expect(underground.isUnderground());
}

test "2. Netherrack apron radius bounds validation (4..7)" {
    // Valid canonical radius range: 4 to 7
    try std.testing.expect(isValidApronRadius(4));
    try std.testing.expect(isValidApronRadius(5));
    try std.testing.expect(isValidApronRadius(6));
    try std.testing.expect(isValidApronRadius(7));

    // Invalid radii outside 4..7
    try std.testing.expect(!isValidApronRadius(0));
    try std.testing.expect(!isValidApronRadius(1));
    try std.testing.expect(!isValidApronRadius(2));
    try std.testing.expect(!isValidApronRadius(3));
    try std.testing.expect(!isValidApronRadius(8));
    try std.testing.expect(!isValidApronRadius(12));
    try std.testing.expect(!isValidApronRadius(15));
}

test "3. Netherrack apron coordinate geometry and block coverage" {
    // Center is always within apron
    try std.testing.expect(isCoordinateInNetherrackApron(0, 0, 5));
    // Points along cardinal axes
    try std.testing.expect(isCoordinateInNetherrackApron(5, 0, 5));
    try std.testing.expect(isCoordinateInNetherrackApron(0, -5, 5));
    // Point beyond radius is outside apron
    try std.testing.expect(!isCoordinateInNetherrackApron(6, 0, 5));
    try std.testing.expect(!isCoordinateInNetherrackApron(4, 4, 5)); // 4^2 + 4^2 = 32 > 25

    // Block coverage checks
    const cov4 = computeApronBlockCoverage(4);
    const cov5 = computeApronBlockCoverage(5);
    const cov7 = computeApronBlockCoverage(7);
    try std.testing.expect(cov4 > 40 and cov4 < 60);
    try std.testing.expect(cov5 > cov4);
    try std.testing.expect(cov7 > cov5);
    try std.testing.expectEqual(@as(u32, 0), computeApronBlockCoverage(3)); // invalid radius returns 0
}

test "4. Gold block crown monument count bounds (1..2) and construction" {
    try std.testing.expect(isValidGoldBlockCrown(1));
    try std.testing.expect(isValidGoldBlockCrown(2));
    try std.testing.expect(!isValidGoldBlockCrown(0));
    try std.testing.expect(!isValidGoldBlockCrown(3));

    // Successful monument construction with valid apron and gold count
    const monument = try RuinedPortalMonument.init(
        .surface,
        5, // apron radius
        2, // gold crown
        4, // magma
        2, // iron bars
        8, // stone bricks
        2, // crying obsidian
        8, // obsidian
    );
    try std.testing.expectEqual(RuinedPortalPlacement.surface, monument.placement);
    try std.testing.expectEqual(@as(u4, 5), monument.netherrack_apron_radius);
    try std.testing.expectEqual(@as(u8, 2), monument.gold_block_crown);
    try std.testing.expect(!monument.is_waterlogged);

    // Rejection on invalid apron radius
    try std.testing.expectError(error.InvalidApronRadius, RuinedPortalMonument.init(
        .surface,
        2, // invalid
        1,
        0, 0, 0, 0, 0,
    ));

    // Rejection on invalid gold block crown count
    try std.testing.expectError(error.InvalidGoldBlockCount, RuinedPortalMonument.init(
        .surface,
        6,
        0, // invalid: 0 gold blocks
        0, 0, 0, 0, 0,
    ));
}

test "5. canActivateFrameWithCryingObsidian allows intact 10-block obsidian frame" {
    // Zero crying obsidian, exactly 10 obsidian edge blocks -> valid ignition!
    try std.testing.expect(canActivateFrameWithCryingObsidian(0, 10));

    // Zero crying obsidian, complete 14-block frame with corners -> valid ignition!
    try std.testing.expect(canActivateFrameWithCryingObsidian(0, 14));
}

test "6. canActivateFrameWithCryingObsidian rejects frame containing crying obsidian in edge" {
    // 1 crying obsidian block in edge blocks ignition, even if obsidian is 9
    try std.testing.expect(!canActivateFrameWithCryingObsidian(1, 9));

    // Crying obsidian in edge blocks ignition even if 10 or more obsidian blocks exist
    try std.testing.expect(!canActivateFrameWithCryingObsidian(1, 10));
    try std.testing.expect(!canActivateFrameWithCryingObsidian(2, 10));
    try std.testing.expect(!canActivateFrameWithCryingObsidian(3, 7));
}

test "7. canActivateFrameWithCryingObsidian rejects incomplete frame without crying obsidian" {
    // Missing obsidian blocks (fewer than 10 required)
    try std.testing.expect(!canActivateFrameWithCryingObsidian(0, 0));
    try std.testing.expect(!canActivateFrameWithCryingObsidian(0, 5));
    try std.testing.expect(!canActivateFrameWithCryingObsidian(0, 8));
    try std.testing.expect(!canActivateFrameWithCryingObsidian(0, 9));
}

test "8. Crying Obsidian block properties: hardness, light level, particles" {
    try std.testing.expectEqual(@as(f32, 50.0), CRYING_OBSIDIAN_HARDNESS);
    try std.testing.expectEqual(@as(f32, 50.0), crying_obsidian_hardness);
    try std.testing.expectEqual(@as(u8, 10), CRYING_OBSIDIAN_LIGHT_LEVEL);
    try std.testing.expectEqual(@as(u8, 10), crying_obsidian_light_level);
    try std.testing.expectEqualStrings("purple_dripping_tear", CRYING_OBSIDIAN_PARTICLES);
    try std.testing.expectEqualStrings("purple_dripping_tear", crying_obsidian_particles);

    try std.testing.expectEqual(@as(f32, 50.0), CryingObsidianProps.hardness);
    try std.testing.expectEqual(@as(u8, 10), CryingObsidianProps.light_level);
    try std.testing.expect(CryingObsidianProps.requires_diamond_or_netherite);
}

test "9. Crying Obsidian mining tool requirements: diamond and netherite only" {
    // Harvestable only by diamond and netherite pickaxes
    try std.testing.expect(canHarvestCryingObsidian(.diamond));
    try std.testing.expect(canHarvestCryingObsidian(.netherite));

    // Other tools/tiers fail harvest requirement
    try std.testing.expect(!canHarvestCryingObsidian(.none));
    try std.testing.expect(!canHarvestCryingObsidian(.wooden));
    try std.testing.expect(!canHarvestCryingObsidian(.stone));
    try std.testing.expect(!canHarvestCryingObsidian(.iron));
    try std.testing.expect(!canHarvestCryingObsidian(.golden));

    // Tool name string check
    try std.testing.expect(canHarvestCryingObsidianWithToolName("diamond_pickaxe"));
    try std.testing.expect(canHarvestCryingObsidianWithToolName("netherite_pickaxe"));
    try std.testing.expect(!canHarvestCryingObsidianWithToolName("iron_pickaxe"));
    try std.testing.expect(!canHarvestCryingObsidianWithToolName("wooden_pickaxe"));

    // Mining time: inadequate tool takes 250s, diamond takes (50.0 * 1.5) / 8.0 = 9.375s
    try std.testing.expectEqual(@as(f32, 250.0), CryingObsidianProps.calculateMiningTimeSeconds(.none));
    try std.testing.expectEqual(@as(f32, 250.0), CryingObsidianProps.calculateMiningTimeSeconds(.iron));
    try std.testing.expectApproxEqAbs(@as(f32, 9.375), CryingObsidianProps.calculateMiningTimeSeconds(.diamond), 0.001);
}

test "10. RuinedPortalChestLoot guarantees portal igniter in every generated chest" {
    var seed: u64 = 100;
    while (seed < 125) : (seed += 1) {
        const loot = generateRuinedPortalChestLoot(seed);
        // Every chest must have a guaranteed igniter (flint & steel or fire charges)
        try std.testing.expect(loot.hasGuaranteedIgniter());
        try std.testing.expect(loot.igniter_item == .flint_and_steel or loot.igniter_item == .fire_charge);
    }
}

test "11. RuinedPortalChestLoot obsidian count is strictly between 1 and 4 blocks" {
    var seed: u64 = 200;
    while (seed < 225) : (seed += 1) {
        const loot = generateRuinedPortalChestLoot(seed);
        const obs = loot.obsidian_repair_count;
        try std.testing.expect(obs >= 1 and obs <= 4);
        try std.testing.expectEqual(obs, loot.getObsidianCount());
    }
}

test "12. Golden equipment high enchantability constant is 22" {
    try std.testing.expectEqual(@as(u8, 22), gold_enchantability);
    try std.testing.expectEqual(@as(u8, 22), GOLD_ENCHANTABILITY);

    // Golden equipment reports gold_enchantability
    try std.testing.expectEqual(@as(u8, 22), RuinedPortalLootItem.golden_sword.enchantability());
    try std.testing.expectEqual(@as(u8, 22), RuinedPortalLootItem.golden_pickaxe.enchantability());
    try std.testing.expectEqual(@as(u8, 22), RuinedPortalLootItem.golden_helmet.enchantability());
    try std.testing.expectEqual(@as(u8, 22), RuinedPortalLootItem.golden_chestplate.enchantability());

    // Non-equipment items return 0
    try std.testing.expectEqual(@as(u8, 0), RuinedPortalLootItem.obsidian.enchantability());
    try std.testing.expectEqual(@as(u8, 0), RuinedPortalLootItem.gold_nugget.enchantability());

    // Material enchantability comparison
    try std.testing.expectEqual(@as(u8, 22), getMaterialEnchantability("gold"));
    try std.testing.expectEqual(@as(u8, 15), getMaterialEnchantability("netherite"));
    try std.testing.expectEqual(@as(u8, 14), getMaterialEnchantability("iron"));
    try std.testing.expectEqual(@as(u8, 10), getMaterialEnchantability("diamond"));
}

test "13. RuinedPortalChestLoot generates enchanted gold armor or tools" {
    const loot = generateRuinedPortalChestLoot(555);
    try std.testing.expect(loot.hasEnchantedGoldGear());

    // Find the enchanted gold slot
    var found_enchanted_gold = false;
    for (loot.slots[0..loot.slot_count]) |slot| {
        if (slot.item.isGoldenEquipment() and slot.is_enchanted) {
            found_enchanted_gold = true;
            try std.testing.expect(slot.enchantment_level >= 15);
        }
    }
    try std.testing.expect(found_enchanted_gold);
}

test "14. RuinedPortalChestLoot rare treasure items: golden apples, glistering melon, lodestone" {
    // Test across a seed range to encounter glistering melon, golden apples, lodestone
    var seen_glistering = false;
    var seen_lodestone_or_apple = false;

    var seed: u64 = 1000;
    while (seed < 1100) : (seed += 1) {
        const loot = generateRuinedPortalChestLoot(seed);
        if (loot.has_glistering_melon) seen_glistering = true;
        if (loot.has_golden_apple or loot.has_enchanted_golden_apple or loot.has_lodestone) {
            seen_lodestone_or_apple = true;
        }
    }

    try std.testing.expect(seen_glistering);
    try std.testing.expect(seen_lodestone_or_apple);
}

test "15. PortalRepairCalculation computes missing_edge_blocks + crying_obsidian_edge_blocks" {
    // 3 missing + 1 crying obsidian = 4 obsidian needed
    try std.testing.expectEqual(@as(u8, 4), computeObsidianNeededToComplete(3, 1));
    try std.testing.expectEqual(@as(u8, 4), calculatePortalRepair(3, 1));

    // 0 missing + 2 crying obsidian = 2 obsidian needed
    try std.testing.expectEqual(@as(u8, 2), computeObsidianNeededToComplete(0, 2));

    // 10 missing + 0 crying obsidian = 10 obsidian needed
    try std.testing.expectEqual(@as(u8, 10), computeObsidianNeededToComplete(10, 0));

    // 0 missing + 0 crying obsidian = 0 obsidian needed
    try std.testing.expectEqual(@as(u8, 0), computeObsidianNeededToComplete(0, 0));

    // Struct compute test
    const calc = PortalRepairCalculation.compute(2, 2);
    try std.testing.expectEqual(@as(u8, 2), calc.missing_edge_blocks);
    try std.testing.expectEqual(@as(u8, 2), calc.crying_obsidian_edge_blocks);
    try std.testing.expectEqual(@as(u8, 4), calc.obsidian_needed_to_complete);
}

test "16. PortalRepairCalculation feasibility check against chest loot obsidian" {
    const calc = PortalRepairCalculation.compute(2, 1); // needs 3 obsidian
    try std.testing.expectEqual(@as(u8, 3), calc.obsidian_needed_to_complete);

    // Having 3 obsidian completes the repair
    try std.testing.expect(calc.canCompleteWithObsidian(3));
    try std.testing.expect(calc.canCompleteWithObsidian(4));
    // Having only 2 obsidian is insufficient
    try std.testing.expect(!calc.canCompleteWithObsidian(2));

    // Mock a chest loot with 3 obsidian
    var chest = generateRuinedPortalChestLoot(42);
    chest.slots[1] = .{ .item = .obsidian, .count = 3 };
    try std.testing.expect(calc.canCompleteWithChest(chest));

    // Mock chest loot with 1 obsidian
    chest.slots[1] = .{ .item = .obsidian, .count = 1 };
    try std.testing.expect(!calc.canCompleteWithChest(chest));
}

test "17. RuinedPortalMonument deterministic generation across biomes" {
    const surface_monument = generateRuinedPortalMonument(.surface, 42);
    try std.testing.expectEqual(RuinedPortalPlacement.surface, surface_monument.placement);
    try std.testing.expect(surface_monument.netherrack_apron_radius >= 4 and surface_monument.netherrack_apron_radius <= 7);
    try std.testing.expect(surface_monument.gold_block_crown >= 1 and surface_monument.gold_block_crown <= 2);
    try std.testing.expect(!surface_monument.is_waterlogged);

    const underwater_monument = generateRuinedPortalMonument(.underwater, 77);
    try std.testing.expectEqual(RuinedPortalPlacement.underwater, underwater_monument.placement);
    try std.testing.expect(underwater_monument.is_waterlogged);

    const nether_monument = generateRuinedPortalMonument(.nether, 99);
    try std.testing.expectEqual(RuinedPortalPlacement.nether, nether_monument.placement);
    try std.testing.expect(!nether_monument.placement.isOverworld());
}

test "18. Full 4x5 portal frame edge analysis with crying obsidian replacement" {
    // Frame with 7 obsidian, 2 crying obsidian, and 1 air block
    const edges = [10]PortalBlockKind{
        .obsidian,        .obsidian, // sill
        .obsidian,        .air,      // lintel (1 missing)
        .obsidian,        .crying_obsidian, .obsidian, // left jamb (1 crying)
        .crying_obsidian, .obsidian,        .obsidian, // right jamb (1 crying)
    };

    const analysis = analyzeFrameEdges(edges);
    try std.testing.expectEqual(@as(u8, 7), analysis.obsidian_in_edge);
    try std.testing.expectEqual(@as(u8, 2), analysis.crying_obsidian_in_edge);
    try std.testing.expectEqual(@as(u8, 1), analysis.missing_in_edge);
    try std.testing.expect(!analysis.can_ignite);
    try std.testing.expect(analysis.rejection_reason != null);

    // Compute repair for this frame
    const repair = PortalRepairCalculation.compute(analysis.missing_in_edge, analysis.crying_obsidian_in_edge);
    try std.testing.expectEqual(@as(u8, 3), repair.obsidian_needed_to_complete);
}
