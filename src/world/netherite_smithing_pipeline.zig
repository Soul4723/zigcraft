//! ============================================================================
//! Milestone 473: Netherite Armor & Weapon Smithing Template Customization
//! ============================================================================
//!
//! Overview:
//!   Provides comprehensive mechanics for Netherite equipment upgrading via the
//!   Smithing Table introduced in Minecraft 1.20+, including:
//!
//!   1. Netherite Upgrade Smithing Template:
//!      - `ItemType.netherite_upgrade_smithing_template`: generated in Bastion Remnants
//!        (100% guaranteed in Treasure Room chests, 10% in other Bastion chests).
//!      - Template Duplication Recipe: 1 Netherite Upgrade Template + 7 Diamonds +
//!        1 Netherrack in a 3x3 crafting grid produces 2 Netherite Upgrade Templates.
//!
//!   2. 3-Slot Smithing Table Pipeline:
//!      - Slot 0: `template_slot` (Netherite Upgrade Smithing Template).
//!      - Slot 1: `base_gear_slot` (Diamond equipment piece).
//!      - Slot 2: `addition_slot` (Netherite Ingot).
//!      - Upgrades all 9 Diamond items:
//!        Helmet, Chestplate, Leggings, Boots, Sword, Pickaxe, Axe, Shovel, Hoe.
//!      - Strict rejection of non-diamond equipment (iron, golden, leather, stone, wood).
//!      - Strict rejection of missing/invalid templates or additions.
//!
//!   3. Stat Enhancements & Attribute Scaling:
//!      - Durability: Diamond Pickaxe (1561) -> Netherite Pickaxe (2031);
//!        Helmet (363 -> 407), Chestplate (528 -> 592), Leggings (495 -> 555), Boots (429 -> 481).
//!        Preserves exact damage taken on the base gear.
//!      - Armor Toughness: +3 per armor piece (+12 for a full 4-piece suit).
//!      - Knockback Resistance: +10% (0.10) per armor piece up to +40% (0.40) full set.
//!      - Attack Damage: +1 bonus damage over diamond for weapons and tools.
//!      - Metadata Preservation: existing enchantments, prior work penalty / repair cost,
//!        and custom names are strictly preserved across the smithing transformation.
//!
//!   4. Netherite Lava / Fire Buoyancy & Blast Immunity:
//!      - All Netherite items (armor, tools, ingots, scraps, blocks, templates) are
//!        completely immune to fire and lava destruction (`isImmuneToLava = true`).
//!      - In lava fluids, Netherite items float on the lava surface with positive
//!        vertical buoyancy rather than sinking.
//!      - Blast resistance: 1200.0 blast resistance for Netherite Block, rendering it
//!        completely immune to TNT and Nether bed explosions.

const std = @import("std");

// ============================================================================
// Constants & Configuration
// ============================================================================

/// Number of slots in the 1.20+ Smithing Table (template, base gear, addition).
pub const SMITHING_TABLE_SLOTS: usize = 3;

/// Diamonds consumed per template duplication craft.
pub const DIAMONDS_PER_TEMPLATE_DUPLICATION: u8 = 7;

/// Host blocks (Netherrack) consumed per template duplication craft.
pub const NETHERRACK_PER_TEMPLATE_DUPLICATION: u8 = 1;

/// Templates produced per duplication craft.
pub const TEMPLATES_PER_DUPLICATION_OUTPUT: u8 = 2;

/// Maximum number of enchantments stored on an equipment piece.
pub const MAX_ENCHANTMENTS: usize = 8;

/// Maximum character length for custom item names.
pub const MAX_CUSTOM_NAME_LEN: usize = 32;

/// Blast resistance of Netherite Block and Ancient Debris (1200.0).
pub const NETHERITE_BLOCK_BLAST_RESISTANCE: f32 = 1200.0;

/// Standard TNT explosion power for blast mining.
pub const TNT_EXPLOSION_POWER: f32 = 4.0;

/// Nether Bed explosion power (power 5.0).
pub const BED_EXPLOSION_POWER: f32 = 5.0;

/// Upward acceleration applied to buoyant items in lava per tick.
pub const LAVA_BUOYANCY_ACCEL: f32 = 0.05;

/// Drag factor applied to vertical velocity in lava.
pub const LAVA_DRAG: f32 = 0.90;

/// Terminal floating vertical velocity at the lava surface.
pub const LAVA_TERMINAL_FLOAT_VY: f32 = 0.10;

// ============================================================================
// Item Types & Classification
// ============================================================================

/// Item IDs mirrored from inventory.zig for self-contained world mechanics.
pub const ItemType = enum(u16) {
    none = 0,

    // Environmental blocks & materials
    cobblestone = 11,
    dirt = 12,
    iron_ingot = 26,
    iron_pickaxe = 27,
    iron_sword = 31,
    netherrack = 49,
    ancient_debris = 70,
    netherite_scrap = 71,
    netherite_ingot = 72,
    netherite_pickaxe = 73,
    netherite_sword = 74,
    gold_nugget = 81,
    netherite_chestplate = 90,
    netherite_helmet = 92,
    netherite_leggings = 93,
    netherite_boots = 95,

    // Diamond materials & equipment
    diamond = 217,
    diamond_sword = 220,
    diamond_pickaxe = 221,
    diamond_helmet = 222,
    diamond_chestplate = 223,
    diamond_leggings = 224,
    diamond_boots = 225,
    iron_axe = 229,
    diamond_axe = 230,
    netherite_axe = 231,
    iron_shovel = 233,
    diamond_shovel = 234,
    netherite_shovel = 235,
    wooden_hoe = 236,
    iron_hoe = 237,
    diamond_hoe = 238,
    netherite_hoe = 239,
    netherite_block = 240,

    // Non-diamond armor
    iron_helmet = 241,
    iron_chestplate = 242,
    iron_leggings = 243,
    iron_boots = 244,
    golden_helmet = 245,
    golden_chestplate = 246,
    golden_leggings = 247,
    golden_boots = 248,
    stone_sword = 249,
    stone_pickaxe = 250,
    stone_axe = 251,
    stone_shovel = 252,
    stone_hoe = 253,
    golden_sword = 254,
    golden_pickaxe = 255,
    golden_axe = 256,
    golden_shovel = 257,
    golden_hoe = 258,
    wooden_sword = 259,
    wooden_pickaxe = 260,
    leather_helmet = 261,
    leather_chestplate = 262,
    leather_leggings = 263,
    leather_boots = 264,
    wooden_axe = 275,
    wooden_shovel = 276,
    stick = 280,
    gold_ingot = 285,

    // Smithing Upgrade Template & trims
    netherite_upgrade_smithing_template = 491,
    coast_armor_trim_template = 492,

    /// Alias matching inventory.zig
    pub const netherite_upgrade_template = ItemType.netherite_upgrade_smithing_template;

    pub fn maxStackSize(self: ItemType) u8 {
        return switch (self) {
            .diamond_sword, .diamond_pickaxe, .diamond_axe, .diamond_shovel, .diamond_hoe,
            .diamond_helmet, .diamond_chestplate, .diamond_leggings, .diamond_boots,
            .netherite_sword, .netherite_pickaxe, .netherite_axe, .netherite_shovel, .netherite_hoe,
            .netherite_helmet, .netherite_chestplate, .netherite_leggings, .netherite_boots,
            .iron_sword, .iron_pickaxe, .iron_axe, .iron_shovel, .iron_hoe,
            .iron_helmet, .iron_chestplate, .iron_leggings, .iron_boots,
            .golden_sword, .golden_pickaxe, .golden_axe, .golden_shovel, .golden_hoe,
            .golden_helmet, .golden_chestplate, .golden_leggings, .golden_boots,
            .leather_helmet, .leather_chestplate, .leather_leggings, .leather_boots,
            .stone_sword, .stone_pickaxe, .stone_axe, .stone_shovel, .stone_hoe,
            .wooden_sword, .wooden_pickaxe, .wooden_axe, .wooden_shovel, .wooden_hoe,
            => 1,
            else => 64,
        };
    }

    pub fn name(self: ItemType) []const u8 {
        return switch (self) {
            .none => "Air",
            .cobblestone => "Cobblestone",
            .dirt => "Dirt",
            .netherrack => "Netherrack",
            .diamond => "Diamond",
            .iron_ingot => "Iron Ingot",
            .gold_ingot => "Gold Ingot",
            .gold_nugget => "Gold Nugget",
            .stick => "Stick",
            .netherite_scrap => "Netherite Scrap",
            .netherite_ingot => "Netherite Ingot",
            .ancient_debris => "Ancient Debris",
            .netherite_block => "Netherite Block",
            .diamond_sword => "Diamond Sword",
            .diamond_pickaxe => "Diamond Pickaxe",
            .diamond_helmet => "Diamond Helmet",
            .diamond_chestplate => "Diamond Chestplate",
            .diamond_leggings => "Diamond Leggings",
            .diamond_boots => "Diamond Boots",
            .diamond_axe => "Diamond Axe",
            .diamond_shovel => "Diamond Shovel",
            .diamond_hoe => "Diamond Hoe",
            .netherite_sword => "Netherite Sword",
            .netherite_pickaxe => "Netherite Pickaxe",
            .netherite_axe => "Netherite Axe",
            .netherite_shovel => "Netherite Shovel",
            .netherite_hoe => "Netherite Hoe",
            .netherite_chestplate => "Netherite Chestplate",
            .netherite_helmet => "Netherite Helmet",
            .netherite_leggings => "Netherite Leggings",
            .netherite_boots => "Netherite Boots",
            .netherite_upgrade_smithing_template => "Netherite Upgrade Smithing Template",
            .iron_helmet => "Iron Helmet",
            .iron_chestplate => "Iron Chestplate",
            .iron_leggings => "Iron Leggings",
            .iron_boots => "Iron Boots",
            .iron_sword => "Iron Sword",
            .iron_pickaxe => "Iron Pickaxe",
            .iron_axe => "Iron Axe",
            .iron_shovel => "Iron Shovel",
            .iron_hoe => "Iron Hoe",
            .golden_helmet => "Golden Helmet",
            .golden_chestplate => "Golden Chestplate",
            .golden_leggings => "Golden Leggings",
            .golden_boots => "Golden Boots",
            .golden_sword => "Golden Sword",
            .golden_pickaxe => "Golden Pickaxe",
            .golden_axe => "Golden Axe",
            .golden_shovel => "Golden Shovel",
            .golden_hoe => "Golden Hoe",
            .leather_helmet => "Leather Helmet",
            .leather_chestplate => "Leather Chestplate",
            .leather_leggings => "Leather Leggings",
            .leather_boots => "Leather Boots",
            .stone_sword => "Stone Sword",
            .stone_pickaxe => "Stone Pickaxe",
            .stone_axe => "Stone Axe",
            .stone_shovel => "Stone Shovel",
            .stone_hoe => "Stone Hoe",
            .wooden_sword => "Wooden Sword",
            .wooden_pickaxe => "Wooden Pickaxe",
            .wooden_axe => "Wooden Axe",
            .wooden_shovel => "Wooden Shovel",
            .wooden_hoe => "Wooden Hoe",
            .coast_armor_trim_template => "Coast Armor Trim Template",
        };
    }
};

/// Equipment slot category.
pub const EquipmentKind = enum {
    helmet,
    chestplate,
    leggings,
    boots,
    sword,
    pickaxe,
    axe,
    shovel,
    hoe,

    pub fn isArmor(self: EquipmentKind) bool {
        return switch (self) {
            .helmet, .chestplate, .leggings, .boots => true,
            else => false,
        };
    }

    pub fn isToolOrWeapon(self: EquipmentKind) bool {
        return !self.isArmor();
    }
};

/// All 9 Diamond equipment pieces eligible for Netherite transformation.
pub const DIAMOND_EQUIPMENT = [9]ItemType{
    .diamond_helmet,
    .diamond_chestplate,
    .diamond_leggings,
    .diamond_boots,
    .diamond_sword,
    .diamond_pickaxe,
    .diamond_axe,
    .diamond_shovel,
    .diamond_hoe,
};

/// All 9 Netherite equipment pieces produced by the Smithing Table.
pub const NETHERITE_EQUIPMENT = [9]ItemType{
    .netherite_helmet,
    .netherite_chestplate,
    .netherite_leggings,
    .netherite_boots,
    .netherite_sword,
    .netherite_pickaxe,
    .netherite_axe,
    .netherite_shovel,
    .netherite_hoe,
};

/// Checks if an item is an upgradeable diamond equipment piece.
pub fn isDiamondEquipment(item: ItemType) bool {
    return switch (item) {
        .diamond_helmet,
        .diamond_chestplate,
        .diamond_leggings,
        .diamond_boots,
        .diamond_sword,
        .diamond_pickaxe,
        .diamond_axe,
        .diamond_shovel,
        .diamond_hoe,
        => true,
        else => false,
    };
}

/// Checks if an item is a Netherite equipment piece.
pub fn isNetheriteEquipment(item: ItemType) bool {
    return switch (item) {
        .netherite_helmet,
        .netherite_chestplate,
        .netherite_leggings,
        .netherite_boots,
        .netherite_sword,
        .netherite_pickaxe,
        .netherite_axe,
        .netherite_shovel,
        .netherite_hoe,
        => true,
        else => false,
    };
}

/// Maps a diamond gear item to its corresponding netherite variant.
pub fn toNetheriteVariant(item: ItemType) ?ItemType {
    return switch (item) {
        .diamond_helmet => .netherite_helmet,
        .diamond_chestplate => .netherite_chestplate,
        .diamond_leggings => .netherite_leggings,
        .diamond_boots => .netherite_boots,
        .diamond_sword => .netherite_sword,
        .diamond_pickaxe => .netherite_pickaxe,
        .diamond_axe => .netherite_axe,
        .diamond_shovel => .netherite_shovel,
        .diamond_hoe => .netherite_hoe,
        else => null,
    };
}

/// Returns the EquipmentKind category for an item, or null if not valid equipment.
pub fn getEquipmentKind(item: ItemType) ?EquipmentKind {
    return switch (item) {
        .diamond_helmet, .netherite_helmet, .iron_helmet, .golden_helmet, .leather_helmet => .helmet,
        .diamond_chestplate, .netherite_chestplate, .iron_chestplate, .golden_chestplate, .leather_chestplate => .chestplate,
        .diamond_leggings, .netherite_leggings, .iron_leggings, .golden_leggings, .leather_leggings => .leggings,
        .diamond_boots, .netherite_boots, .iron_boots, .golden_boots, .leather_boots => .boots,
        .diamond_sword, .netherite_sword, .iron_sword, .golden_sword, .stone_sword, .wooden_sword => .sword,
        .diamond_pickaxe, .netherite_pickaxe, .iron_pickaxe, .golden_pickaxe, .stone_pickaxe, .wooden_pickaxe => .pickaxe,
        .diamond_axe, .netherite_axe, .iron_axe, .golden_axe, .stone_axe, .wooden_axe => .axe,
        .diamond_shovel, .netherite_shovel, .iron_shovel, .golden_shovel, .stone_shovel, .wooden_shovel => .shovel,
        .diamond_hoe, .netherite_hoe, .iron_hoe, .golden_hoe, .stone_hoe, .wooden_hoe => .hoe,
        else => null,
    };
}

/// Canonical maximum durability values according to Minecraft Java specifications.
pub fn maxDurability(item: ItemType) u16 {
    return switch (item) {
        // Diamond tier
        .diamond_helmet => 363,
        .diamond_chestplate => 528,
        .diamond_leggings => 495,
        .diamond_boots => 429,
        .diamond_sword, .diamond_pickaxe, .diamond_axe, .diamond_shovel, .diamond_hoe => 1561,

        // Netherite tier
        .netherite_helmet => 407,
        .netherite_chestplate => 592,
        .netherite_leggings => 555,
        .netherite_boots => 481,
        .netherite_sword, .netherite_pickaxe, .netherite_axe, .netherite_shovel, .netherite_hoe => 2031,

        // Iron tier
        .iron_helmet => 165,
        .iron_chestplate => 240,
        .iron_leggings => 225,
        .iron_boots => 195,
        .iron_sword, .iron_pickaxe, .iron_axe, .iron_shovel, .iron_hoe => 250,

        // Golden tier
        .golden_helmet => 77,
        .golden_chestplate => 112,
        .golden_leggings => 105,
        .golden_boots => 91,
        .golden_sword, .golden_pickaxe, .golden_axe, .golden_shovel, .golden_hoe => 32,

        // Leather tier
        .leather_helmet => 55,
        .leather_chestplate => 80,
        .leather_leggings => 75,
        .leather_boots => 65,

        // Stone tier
        .stone_sword, .stone_pickaxe, .stone_axe, .stone_shovel, .stone_hoe => 131,

        // Wooden tier
        .wooden_sword, .wooden_pickaxe, .wooden_axe, .wooden_shovel, .wooden_hoe => 59,

        else => 0,
    };
}

/// Armor toughness attribute points:
/// Diamond armor: 2.0 toughness per piece (+8.0 full set)
/// Netherite armor: 3.0 toughness per piece (+12.0 full set, +3 per piece)
pub fn getArmorToughness(item: ItemType) f32 {
    return switch (item) {
        .diamond_helmet, .diamond_chestplate, .diamond_leggings, .diamond_boots => 2.0,
        .netherite_helmet, .netherite_chestplate, .netherite_leggings, .netherite_boots => 3.0,
        else => 0.0,
    };
}

/// Armor toughness bonus provided by a Netherite armor piece (+3.0 per piece).
pub fn getArmorToughnessBonus(item: ItemType) f32 {
    return switch (item) {
        .netherite_helmet, .netherite_chestplate, .netherite_leggings, .netherite_boots => 3.0,
        else => 0.0,
    };
}

/// Knockback resistance attribute:
/// Netherite armor pieces grant +10% (0.10) knockback resistance per piece.
/// Full suit (4 pieces) grants +40% (0.40) knockback resistance.
pub fn getKnockbackResistance(item: ItemType) f32 {
    return switch (item) {
        .netherite_helmet, .netherite_chestplate, .netherite_leggings, .netherite_boots => 0.10,
        else => 0.0,
    };
}

/// Calculates total knockback resistance for equipped armor pieces.
pub fn calculateSetKnockbackResistance(helmet: bool, chestplate: bool, leggings: bool, boots: bool) f32 {
    var pieces: u3 = 0;
    if (helmet) pieces += 1;
    if (chestplate) pieces += 1;
    if (leggings) pieces += 1;
    if (boots) pieces += 1;
    return @as(f32, @floatFromInt(pieces)) * 0.10;
}

/// Applies knockback reduction to an incoming impulse.
pub fn applyKnockbackReduction(raw_knockback: f32, netherite_pieces: u3) f32 {
    const pieces = @min(netherite_pieces, 4);
    const resistance = @as(f32, @floatFromInt(pieces)) * 0.10;
    return raw_knockback * (1.0 - resistance);
}

/// Base attack damage according to Minecraft Java Edition:
/// Netherite weapons and tools gain a flat +1 damage bonus over diamond tier.
pub fn getAttackDamage(item: ItemType) f32 {
    return switch (item) {
        .diamond_sword => 7.0,
        .netherite_sword => 8.0,

        .diamond_pickaxe => 5.0,
        .netherite_pickaxe => 6.0,

        .diamond_axe => 9.0,
        .netherite_axe => 10.0,

        .diamond_shovel => 5.5,
        .netherite_shovel => 6.5,

        .diamond_hoe => 1.0,
        .netherite_hoe => 2.0,

        .iron_sword => 6.0,
        .golden_sword => 4.0,
        .stone_sword => 5.0,
        .wooden_sword => 4.0,

        else => 0.0,
    };
}

/// Bonus attack damage granted by Netherite tier over Diamond tier (+1 for tools/weapons).
pub fn getAttackDamageBonusOverDiamond(item: ItemType) f32 {
    return switch (item) {
        .netherite_sword, .netherite_pickaxe, .netherite_axe, .netherite_shovel, .netherite_hoe => 1.0,
        else => 0.0,
    };
}

// ============================================================================
// Bastion Remnant Loot Exclusivity
// ============================================================================

pub const BastionVariant = enum {
    treasure_room,
    hoglin_stables,
    housing_units,
    bridge,

    /// In Minecraft 1.20+, the central chest of a Treasure Room Bastion Remnant
    /// is 100% guaranteed to contain a Netherite Upgrade Smithing Template.
    pub fn guaranteesNetheriteUpgradeTemplate(self: BastionVariant) bool {
        return self == .treasure_room;
    }

    /// Chest drop chance for a Netherite Upgrade Template:
    /// - Treasure Room: 1.0 (100% guaranteed)
    /// - Other Bastions: 0.10 (10% chance)
    pub fn templateChestDropRate(self: BastionVariant) f32 {
        return switch (self) {
            .treasure_room => 1.0,
            .hoglin_stables, .housing_units, .bridge => 0.10,
        };
    }
};

/// Evaluates whether a Bastion chest roll successfully generates a Netherite Upgrade Template.
pub fn generatesBastionTemplateLoot(variant: BastionVariant, roll: f32) bool {
    return roll < variant.templateChestDropRate();
}

// ============================================================================
// Template Duplication Crafting (3x3 Grid)
// ============================================================================

/// Validates whether a 3x3 crafting grid matches the exact shaped recipe:
///   [0] Diamond,  [1] Template,   [2] Diamond
///   [3] Diamond,  [4] Netherrack, [5] Diamond
///   [6] Diamond,  [7] Diamond,    [8] Diamond
pub fn isExactShapedDuplicationRecipe(grid: [9]?ItemType) bool {
    const d = ItemType.diamond;
    const t = ItemType.netherite_upgrade_smithing_template;
    const n = ItemType.netherrack;

    const expected = [9]?ItemType{
        d, t, d,
        d, n, d,
        d, d, d,
    };

    for (0..9) |i| {
        if (grid[i] != expected[i]) return false;
    }
    return true;
}

/// Validates whether 9 slots contain exactly 1 Template, 7 Diamonds, and 1 Netherrack.
pub fn isDuplicationRecipeShapeless(grid: [9]?ItemType) bool {
    var template_count: u8 = 0;
    var diamond_count: u8 = 0;
    var netherrack_count: u8 = 0;

    for (grid) |slot_opt| {
        if (slot_opt) |item| {
            switch (item) {
                .netherite_upgrade_smithing_template => template_count += 1,
                .diamond => diamond_count += 1,
                .netherrack => netherrack_count += 1,
                else => return false,
            }
        }
    }
    return template_count == 1 and diamond_count == 7 and netherrack_count == 1;
}

/// Unified check for template duplication crafting in 3x3 grid.
pub fn canDuplicateTemplate(grid: [9]?ItemType) bool {
    return isExactShapedDuplicationRecipe(grid) or isDuplicationRecipeShapeless(grid);
}

pub const TemplateDuplicationResult = struct {
    templates_out: u8,
    diamonds_used: u8,
    netherrack_used: u8,
    success: bool,
};

/// Performs template duplication from raw counts: 1 Template + 7 Diamonds + 1 Netherrack -> 2 Templates.
pub fn duplicateTemplateDirect(templates: u8, diamonds: u8, netherracks: u8) TemplateDuplicationResult {
    if (templates == 0 or diamonds < DIAMONDS_PER_TEMPLATE_DUPLICATION or netherracks < NETHERRACK_PER_TEMPLATE_DUPLICATION) {
        return .{
            .templates_out = 0,
            .diamonds_used = 0,
            .netherrack_used = 0,
            .success = false,
        };
    }
    return .{
        .templates_out = TEMPLATES_PER_DUPLICATION_OUTPUT,
        .diamonds_used = DIAMONDS_PER_TEMPLATE_DUPLICATION,
        .netherrack_used = NETHERRACK_PER_TEMPLATE_DUPLICATION,
        .success = true,
    };
}

/// Batch duplicates templates when multiple sets of ingredients are available.
pub fn batchDuplicateTemplates(templates: u8, diamonds: u8, netherracks: u8) TemplateDuplicationResult {
    if (templates == 0 or diamonds < DIAMONDS_PER_TEMPLATE_DUPLICATION or netherracks == 0) {
        return .{ .templates_out = 0, .diamonds_used = 0, .netherrack_used = 0, .success = false };
    }
    const crafts_from_diamonds = diamonds / DIAMONDS_PER_TEMPLATE_DUPLICATION;
    const crafts = @min(templates, @min(crafts_from_diamonds, netherracks));
    return .{
        .templates_out = crafts * TEMPLATES_PER_DUPLICATION_OUTPUT,
        .diamonds_used = crafts * DIAMONDS_PER_TEMPLATE_DUPLICATION,
        .netherrack_used = crafts * NETHERRACK_PER_TEMPLATE_DUPLICATION,
        .success = crafts > 0,
    };
}

// ============================================================================
// Equipment Item with Metadata (Enchantments, Custom Name, Prior Work Penalty)
// ============================================================================

pub const EnchantmentId = enum(u8) {
    protection = 0,
    fire_protection = 1,
    feather_falling = 2,
    blast_protection = 3,
    projectile_protection = 4,
    respiration = 5,
    aqua_affinity = 6,
    thorns = 7,
    depth_strider = 8,
    frost_walker = 9,
    soul_speed = 10,
    swift_sneak = 11,
    unbreaking = 12,
    mending = 13,
    sharpness = 14,
    smite = 15,
    bane_of_arthropods = 16,
    knockback = 17,
    fire_aspect = 18,
    looting = 19,
    sweeping_edge = 20,
    efficiency = 21,
    silk_touch = 22,
    fortune = 23,
    power = 24,
    punch = 25,
    flame = 26,
    infinity = 27,
    curse_of_binding = 28,
    curse_of_vanishing = 29,

    pub fn name(self: EnchantmentId) []const u8 {
        return switch (self) {
            .protection => "Protection",
            .fire_protection => "Fire Protection",
            .feather_falling => "Feather Falling",
            .blast_protection => "Blast Protection",
            .projectile_protection => "Projectile Protection",
            .respiration => "Respiration",
            .aqua_affinity => "Aqua Affinity",
            .thorns => "Thorns",
            .depth_strider => "Depth Strider",
            .frost_walker => "Frost Walker",
            .soul_speed => "Soul Speed",
            .swift_sneak => "Swift Sneak",
            .unbreaking => "Unbreaking",
            .mending => "Mending",
            .sharpness => "Sharpness",
            .smite => "Smite",
            .bane_of_arthropods => "Bane of Arthropods",
            .knockback => "Knockback",
            .fire_aspect => "Fire Aspect",
            .looting => "Looting",
            .sweeping_edge => "Sweeping Edge",
            .efficiency => "Efficiency",
            .silk_touch => "Silk Touch",
            .fortune => "Fortune",
            .power => "Power",
            .punch => "Punch",
            .flame => "Flame",
            .infinity => "Infinity",
            .curse_of_binding => "Curse of Binding",
            .curse_of_vanishing => "Curse of Vanishing",
        };
    }
};

pub const Enchantment = struct {
    id: EnchantmentId,
    level: u8,
};

/// Represents an item stack with full Minecraft RPG metadata.
pub const EquipmentItem = struct {
    item: ItemType = .none,
    count: u8 = 0,
    durability: u16 = 0,
    repair_cost: u32 = 0, // Anvil prior-work penalty (0, 1, 3, 7, 15, 31, ...)
    custom_name: ?[MAX_CUSTOM_NAME_LEN]u8 = null,
    custom_name_len: u8 = 0,
    enchantments: [MAX_ENCHANTMENTS]Enchantment = [_]Enchantment{.{ .id = .protection, .level = 0 }} ** MAX_ENCHANTMENTS,
    enchantment_count: u8 = 0,

    pub fn init(item: ItemType, durability: u16) EquipmentItem {
        return .{
            .item = item,
            .count = if (item != .none) 1 else 0,
            .durability = durability,
        };
    }

    pub fn initFull(item: ItemType) EquipmentItem {
        return init(item, maxDurability(item));
    }

    pub fn initStack(item: ItemType, count: u8) EquipmentItem {
        return .{
            .item = item,
            .count = count,
            .durability = maxDurability(item),
        };
    }

    pub fn isEmpty(self: EquipmentItem) bool {
        return self.item == .none or self.count == 0;
    }

    pub fn clear(self: *EquipmentItem) void {
        self.* = .{};
    }

    pub fn setName(self: *EquipmentItem, custom_str: []const u8) void {
        const len = @min(custom_str.len, MAX_CUSTOM_NAME_LEN);
        var buf = [_]u8{0} ** MAX_CUSTOM_NAME_LEN;
        @memcpy(buf[0..len], custom_str[0..len]);
        self.custom_name = buf;
        self.custom_name_len = @intCast(len);
    }

    pub fn getName(self: *const EquipmentItem) ?[]const u8 {
        if (self.custom_name_len == 0 or self.custom_name == null) return null;
        return self.custom_name.?[0..self.custom_name_len];
    }

    pub fn addEnchantment(self: *EquipmentItem, id: EnchantmentId, level: u8) bool {
        if (self.enchantment_count >= MAX_ENCHANTMENTS) return false;
        self.enchantments[self.enchantment_count] = .{ .id = id, .level = level };
        self.enchantment_count += 1;
        return true;
    }

    pub fn getEnchantmentLevel(self: EquipmentItem, id: EnchantmentId) u8 {
        for (self.enchantments[0..self.enchantment_count]) |ench| {
            if (ench.id == id) return ench.level;
        }
        return 0;
    }

    pub fn isImmuneToLava(self: EquipmentItem) bool {
        return isItemImmuneToLava(self.item);
    }
};

// ============================================================================
// Durability Upgrade Scaling
// ============================================================================

/// Computes the upgraded Netherite durability, preserving any damage sustained:
///   damage_taken = diamond_max - current_durability
///   new_durability = netherite_max - damage_taken
pub fn computeUpgradedDurability(base_item: ItemType, current_durability: u16) u16 {
    const old_max = maxDurability(base_item);
    const new_item = toNetheriteVariant(base_item) orelse return current_durability;
    const new_max = maxDurability(new_item);
    if (old_max == 0 or new_max == 0) return current_durability;

    const damage_taken = if (current_durability <= old_max) old_max - current_durability else 0;
    if (damage_taken >= new_max) return 1;
    return new_max - damage_taken;
}

// ============================================================================
// 3-Slot Smithing Table Pipeline
// ============================================================================

/// Represents a 3-slot Smithing Table:
///   Slot 0: template_slot (Netherite Upgrade Template)
///   Slot 1: base_gear_slot (Diamond Equipment)
///   Slot 2: addition_slot (Netherite Ingot)
pub const SmithingTable = struct {
    template_slot: EquipmentItem = .{},
    base_gear_slot: EquipmentItem = .{},
    addition_slot: EquipmentItem = .{},

    pub fn init() SmithingTable {
        return .{};
    }

    pub fn setSlot(self: *SmithingTable, slot_idx: usize, item: EquipmentItem) void {
        switch (slot_idx) {
            0 => self.template_slot = item,
            1 => self.base_gear_slot = item,
            2 => self.addition_slot = item,
            else => {},
        }
    }

    pub fn getSlot(self: SmithingTable, slot_idx: usize) ?EquipmentItem {
        return switch (slot_idx) {
            0 => self.template_slot,
            1 => self.base_gear_slot,
            2 => self.addition_slot,
            else => null,
        };
    }

    /// Validates whether the 3 slots satisfy the Netherite Upgrade transformation criteria:
    ///   - Slot 0: Netherite Upgrade Smithing Template
    ///   - Slot 1: Diamond equipment piece
    ///   - Slot 2: Netherite Ingot
    pub fn isValidUpgrade(self: SmithingTable) bool {
        // Slot 0: must be Netherite Upgrade Smithing Template
        if (self.template_slot.isEmpty() or self.template_slot.item != .netherite_upgrade_smithing_template) {
            return false;
        }

        // Slot 1: must be a valid diamond equipment piece
        if (self.base_gear_slot.isEmpty() or !isDiamondEquipment(self.base_gear_slot.item)) {
            return false;
        }

        // Slot 2: must be a Netherite Ingot
        if (self.addition_slot.isEmpty() or self.addition_slot.item != .netherite_ingot) {
            return false;
        }

        return true;
    }

    /// Computes the upgraded Netherite equipment output, preserving all metadata.
    pub fn getUpgradeOutput(self: SmithingTable) ?EquipmentItem {
        if (!self.isValidUpgrade()) return null;

        const base = self.base_gear_slot;
        const netherite_type = toNetheriteVariant(base.item) orelse return null;
        const new_durability = computeUpgradedDurability(base.item, base.durability);

        var result = EquipmentItem{
            .item = netherite_type,
            .count = 1,
            .durability = new_durability,
            .repair_cost = base.repair_cost, // Preserves prior work penalty
            .custom_name = base.custom_name, // Preserves custom name
            .custom_name_len = base.custom_name_len,
            .enchantment_count = base.enchantment_count,
        };

        // Preserves all existing enchantments
        for (0..base.enchantment_count) |i| {
            result.enchantments[i] = base.enchantments[i];
        }

        return result;
    }

    /// Performs the upgrade transformation, consuming ingredients and returning the upgraded gear.
    pub fn executeUpgrade(self: *SmithingTable) ?EquipmentItem {
        const output = self.getUpgradeOutput() orelse return null;

        // Consume 1 template from slot 0
        if (self.template_slot.count > 1) {
            self.template_slot.count -= 1;
        } else {
            self.template_slot.clear();
        }

        // Consume base gear from slot 1
        self.base_gear_slot.clear();

        // Consume 1 netherite ingot from slot 2
        if (self.addition_slot.count > 1) {
            self.addition_slot.count -= 1;
        } else {
            self.addition_slot.clear();
        }

        return output;
    }
};

/// Standalone helper to validate smithing table upgrade inputs.
pub fn canNetheriteUpgrade(template: ItemType, base_gear: ItemType, addition: ItemType) bool {
    return template == .netherite_upgrade_smithing_template and
        isDiamondEquipment(base_gear) and
        addition == .netherite_ingot;
}

// ============================================================================
// Netherite Lava & Fire Buoyancy, Hazard Immunity & Blast Resistance
// ============================================================================

/// Checks if an ItemType is completely immune to lava and fire destruction.
/// In Minecraft, all Netherite items (armor, tools, ingots, scraps, blocks, templates) are fireproof.
pub fn isItemImmuneToLava(item: ItemType) bool {
    return switch (item) {
        .netherite_helmet,
        .netherite_chestplate,
        .netherite_leggings,
        .netherite_boots,
        .netherite_sword,
        .netherite_pickaxe,
        .netherite_axe,
        .netherite_shovel,
        .netherite_hoe,
        .netherite_ingot,
        .netherite_scrap,
        .ancient_debris,
        .netherite_block,
        .netherite_upgrade_smithing_template,
        => true,
        else => false,
    };
}

/// Checks if an ItemType is immune to fire damage.
pub fn isItemImmuneToFire(item: ItemType) bool {
    return isItemImmuneToLava(item);
}

/// Generic immunity check supporting ItemType, EquipmentItem, or any struct with an .item field.
pub fn isImmuneToLava(target: anytype) bool {
    const T = @TypeOf(target);
    if (T == ItemType) {
        return isItemImmuneToLava(target);
    }
    if (@hasField(T, "item")) {
        return isItemImmuneToLava(target.item);
    }
    if (@hasDecl(T, "isImmuneToLava")) {
        return target.isImmuneToLava();
    }
    return false;
}

/// Generic fire immunity check.
pub fn isImmuneToFire(target: anytype) bool {
    return isImmuneToLava(target);
}

/// Computes the buoyant vertical velocity of dropped items in lava fluids:
///   - If sinking (vy < 0), downward velocity is damped and reversed into upward lift.
///   - Once floating upward (vy >= 0), velocity accelerates toward LAVA_TERMINAL_FLOAT_VY (+0.10).
pub fn computeLavaBuoyancyVy(current_vy: f32) f32 {
    if (current_vy < 0.0) {
        const damped = current_vy * 0.5 + LAVA_BUOYANCY_ACCEL;
        return if (damped > 0.0) @min(damped, LAVA_TERMINAL_FLOAT_VY) else damped;
    }
    return @min(current_vy * LAVA_DRAG + LAVA_BUOYANCY_ACCEL, LAVA_TERMINAL_FLOAT_VY);
}

/// Represents an in-world dropped item entity subjected to lava buoyancy physics.
pub const LavaBuoyantItem = struct {
    item: ItemType,
    count: u8 = 1,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    vy: f32 = 0.0,
    in_lava: bool = false,
    isImmuneToLava: bool = true,

    pub fn init(item: ItemType) LavaBuoyantItem {
        return .{
            .item = item,
            .isImmuneToLava = isItemImmuneToLava(item),
        };
    }

    /// Ticks item entity physics in lava fluids.
    /// Returns true if the item survives and floats, false if incinerated.
    pub fn tickInLava(self: *LavaBuoyantItem) bool {
        if (!isItemImmuneToLava(self.item)) {
            self.isImmuneToLava = false;
            return false; // Non-netherite item burns up!
        }
        self.in_lava = true;
        self.vy = computeLavaBuoyancyVy(self.vy);
        self.y += self.vy;
        return true;
    }
};

/// Blast resistance ratings for world blocks.
pub fn getBlastResistance(item: ItemType) f32 {
    return switch (item) {
        .netherite_block, .ancient_debris => NETHERITE_BLOCK_BLAST_RESISTANCE,
        .netherrack => 0.4,
        .cobblestone => 6.0,
        .diamond => 6.0,
        else => 0.0,
    };
}

/// Checks whether an item survives TNT and Nether Bed explosions.
pub fn isImmuneToExplosion(item: ItemType) bool {
    return getBlastResistance(item) >= NETHERITE_BLOCK_BLAST_RESISTANCE or isItemImmuneToLava(item);
}

// ============================================================================
// Comprehensive Unit Tests (45+ tests)
// ============================================================================

test "1. ItemType properties: canonical naming and stack size constraints" {
    try std.testing.expectEqualStrings("Netherite Upgrade Smithing Template", ItemType.netherite_upgrade_smithing_template.name());
    try std.testing.expectEqualStrings("Netherite Pickaxe", ItemType.netherite_pickaxe.name());
    try std.testing.expectEqualStrings("Netherite Chestplate", ItemType.netherite_chestplate.name());
    try std.testing.expectEqualStrings("Diamond Pickaxe", ItemType.diamond_pickaxe.name());

    // Tools and armor stack to 1
    try std.testing.expectEqual(@as(u8, 1), ItemType.netherite_sword.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.netherite_pickaxe.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.netherite_chestplate.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.diamond_pickaxe.maxStackSize());

    // Materials and templates stack to 64
    try std.testing.expectEqual(@as(u8, 64), ItemType.netherite_upgrade_smithing_template.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.netherite_ingot.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.diamond.maxStackSize());
}

test "2. Bastion Remnant loot exclusivity: Treasure Room guarantees template drop" {
    const tr = BastionVariant.treasure_room;
    try std.testing.expect(tr.guaranteesNetheriteUpgradeTemplate());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tr.templateChestDropRate(), 0.001);
    try std.testing.expect(generatesBastionTemplateLoot(tr, 0.0));
    try std.testing.expect(generatesBastionTemplateLoot(tr, 0.99));
}

test "3. Bastion Remnant loot exclusivity: non-treasure variants have 10% drop chance" {
    const stables = BastionVariant.hoglin_stables;
    const housing = BastionVariant.housing_units;
    const bridge = BastionVariant.bridge;

    try std.testing.expect(!stables.guaranteesNetheriteUpgradeTemplate());
    try std.testing.expect(!housing.guaranteesNetheriteUpgradeTemplate());
    try std.testing.expect(!bridge.guaranteesNetheriteUpgradeTemplate());

    try std.testing.expectApproxEqAbs(@as(f32, 0.10), stables.templateChestDropRate(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), housing.templateChestDropRate(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), bridge.templateChestDropRate(), 0.001);

    // Roll < 0.10 succeeds, roll >= 0.10 fails
    try std.testing.expect(generatesBastionTemplateLoot(stables, 0.05));
    try std.testing.expect(!generatesBastionTemplateLoot(stables, 0.15));
}

test "4. Template duplication crafting: exact shaped 3x3 crafting grid produces 2 templates" {
    const d = ItemType.diamond;
    const t = ItemType.netherite_upgrade_smithing_template;
    const n = ItemType.netherrack;

    const grid = [9]?ItemType{
        d, t, d,
        d, n, d,
        d, d, d,
    };

    try std.testing.expect(isExactShapedDuplicationRecipe(grid));
    try std.testing.expect(canDuplicateTemplate(grid));
}

test "5. Template duplication crafting: shapeless 3x3 crafting grid produces 2 templates" {
    const d = ItemType.diamond;
    const t = ItemType.netherite_upgrade_smithing_template;
    const n = ItemType.netherrack;

    // Different layout with same ingredients (1 T + 7 D + 1 N)
    const grid = [9]?ItemType{
        t, d, d,
        d, d, d,
        d, d, n,
    };

    try std.testing.expect(!isExactShapedDuplicationRecipe(grid)); // Not standard shaped
    try std.testing.expect(isDuplicationRecipeShapeless(grid));     // Valid shapeless
    try std.testing.expect(canDuplicateTemplate(grid));
}

test "6. Template duplication recipe rejection: insufficient diamonds (< 7)" {
    const d = ItemType.diamond;
    const t = ItemType.netherite_upgrade_smithing_template;
    const n = ItemType.netherrack;

    // Only 6 diamonds (one slot null/empty)
    const grid = [9]?ItemType{
        d,    t, d,
        d,    n, d,
        d, null, d,
    };

    try std.testing.expect(!isExactShapedDuplicationRecipe(grid));
    try std.testing.expect(!isDuplicationRecipeShapeless(grid));
    try std.testing.expect(!canDuplicateTemplate(grid));
}

test "7. Template duplication recipe rejection: missing netherrack" {
    const d = ItemType.diamond;
    const t = ItemType.netherite_upgrade_smithing_template;

    // 8 diamonds + 1 template, but no netherrack host block
    const grid = [9]?ItemType{
        d, t, d,
        d, d, d,
        d, d, d,
    };

    try std.testing.expect(!canDuplicateTemplate(grid));
}

test "8. Template duplication recipe rejection: wrong host block (cobblestone instead of netherrack)" {
    const d = ItemType.diamond;
    const t = ItemType.netherite_upgrade_smithing_template;
    const c = ItemType.cobblestone;

    const grid = [9]?ItemType{
        d, t, d,
        d, c, d,
        d, d, d,
    };

    try std.testing.expect(!canDuplicateTemplate(grid));
}

test "9. Template duplication recipe rejection: missing template" {
    const d = ItemType.diamond;
    const n = ItemType.netherrack;

    // 8 diamonds + 1 netherrack, no template
    const grid = [9]?ItemType{
        d, d, d,
        d, n, d,
        d, d, d,
    };

    try std.testing.expect(!canDuplicateTemplate(grid));
}

test "10. Template duplication direct calculation: 1 template + 7 diamonds + 1 netherrack -> 2 templates" {
    const res = duplicateTemplateDirect(1, 7, 1);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u8, 2), res.templates_out);
    try std.testing.expectEqual(@as(u8, 7), res.diamonds_used);
    try std.testing.expectEqual(@as(u8, 1), res.netherrack_used);

    // Insufficient materials fails
    const fail_d = duplicateTemplateDirect(1, 6, 1);
    try std.testing.expect(!fail_d.success);
    try std.testing.expectEqual(@as(u8, 0), fail_d.templates_out);

    const fail_t = duplicateTemplateDirect(0, 7, 1);
    try std.testing.expect(!fail_t.success);

    const fail_n = duplicateTemplateDirect(1, 7, 0);
    try std.testing.expect(!fail_n.success);
}

test "11. Template duplication batch crafting calculation" {
    // 3 templates, 21 diamonds, 3 netherrack -> 6 templates
    const batch = batchDuplicateTemplates(3, 21, 3);
    try std.testing.expect(batch.success);
    try std.testing.expectEqual(@as(u8, 6), batch.templates_out);
    try std.testing.expectEqual(@as(u8, 21), batch.diamonds_used);
    try std.testing.expectEqual(@as(u8, 3), batch.netherrack_used);

    // Limited by diamonds (14 diamonds = 2 crafts)
    const limited = batchDuplicateTemplates(5, 14, 5);
    try std.testing.expectEqual(@as(u8, 4), limited.templates_out);
    try std.testing.expectEqual(@as(u8, 14), limited.diamonds_used);
    try std.testing.expectEqual(@as(u8, 2), limited.netherrack_used);
}

test "12. Smithing Table 3-slot layout structure, slot access, and clearing" {
    var table = SmithingTable.init();
    try std.testing.expect(table.template_slot.isEmpty());
    try std.testing.expect(table.base_gear_slot.isEmpty());
    try std.testing.expect(table.addition_slot.isEmpty());

    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_pickaxe));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expectEqual(ItemType.netherite_upgrade_smithing_template, table.getSlot(0).?.item);
    try std.testing.expectEqual(ItemType.diamond_pickaxe, table.getSlot(1).?.item);
    try std.testing.expectEqual(ItemType.netherite_ingot, table.getSlot(2).?.item);
    try std.testing.expect(table.isValidUpgrade());
}

test "13. Smithing Table upgrade: Diamond Helmet -> Netherite Helmet" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_helmet));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(table.isValidUpgrade());
    const out = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_helmet, out.item);
    try std.testing.expectEqual(@as(u16, 407), out.durability);
}

test "14. Smithing Table upgrade: Diamond Chestplate -> Netherite Chestplate" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_chestplate));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(table.isValidUpgrade());
    const out = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_chestplate, out.item);
    try std.testing.expectEqual(@as(u16, 592), out.durability);
}

test "15. Smithing Table upgrade: Diamond Leggings -> Netherite Leggings" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_leggings));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(table.isValidUpgrade());
    const out = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_leggings, out.item);
    try std.testing.expectEqual(@as(u16, 555), out.durability);
}

test "16. Smithing Table upgrade: Diamond Boots -> Netherite Boots" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_boots));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(table.isValidUpgrade());
    const out = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_boots, out.item);
    try std.testing.expectEqual(@as(u16, 481), out.durability);
}

test "17. Smithing Table upgrade: Diamond Sword -> Netherite Sword" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_sword));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(table.isValidUpgrade());
    const out = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_sword, out.item);
    try std.testing.expectEqual(@as(u16, 2031), out.durability);
}

test "18. Smithing Table upgrade: Diamond Pickaxe -> Netherite Pickaxe" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_pickaxe));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(table.isValidUpgrade());
    const out = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_pickaxe, out.item);
    try std.testing.expectEqual(@as(u16, 2031), out.durability);
}

test "19. Smithing Table upgrade: Diamond Axe -> Netherite Axe" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_axe));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(table.isValidUpgrade());
    const out = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_axe, out.item);
    try std.testing.expectEqual(@as(u16, 2031), out.durability);
}

test "20. Smithing Table upgrade: Diamond Shovel -> Netherite Shovel" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_shovel));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(table.isValidUpgrade());
    const out = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_shovel, out.item);
    try std.testing.expectEqual(@as(u16, 2031), out.durability);
}

test "21. Smithing Table upgrade: Diamond Hoe -> Netherite Hoe" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_hoe));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(table.isValidUpgrade());
    const out = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_hoe, out.item);
    try std.testing.expectEqual(@as(u16, 2031), out.durability);
}

test "22. Smithing Table rejection: non-diamond iron equipment in base gear slot" {
    const iron_items = [_]ItemType{
        .iron_helmet, .iron_chestplate, .iron_leggings, .iron_boots,
        .iron_sword, .iron_pickaxe, .iron_axe, .iron_shovel, .iron_hoe,
    };

    for (iron_items) |item| {
        var table = SmithingTable.init();
        table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
        table.setSlot(1, EquipmentItem.initFull(item));
        table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

        try std.testing.expect(!table.isValidUpgrade());
        try std.testing.expect(table.getUpgradeOutput() == null);
        try std.testing.expect(!canNetheriteUpgrade(.netherite_upgrade_smithing_template, item, .netherite_ingot));
    }
}

test "23. Smithing Table rejection: non-diamond golden equipment in base gear slot" {
    const golden_items = [_]ItemType{
        .golden_helmet, .golden_chestplate, .golden_leggings, .golden_boots,
        .golden_sword, .golden_pickaxe, .golden_axe, .golden_shovel, .golden_hoe,
    };

    for (golden_items) |item| {
        var table = SmithingTable.init();
        table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
        table.setSlot(1, EquipmentItem.initFull(item));
        table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

        try std.testing.expect(!table.isValidUpgrade());
        try std.testing.expect(table.getUpgradeOutput() == null);
    }
}

test "24. Smithing Table rejection: non-diamond leather equipment in base gear slot" {
    const leather_items = [_]ItemType{
        .leather_helmet, .leather_chestplate, .leather_leggings, .leather_boots,
    };

    for (leather_items) |item| {
        var table = SmithingTable.init();
        table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
        table.setSlot(1, EquipmentItem.initFull(item));
        table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

        try std.testing.expect(!table.isValidUpgrade());
        try std.testing.expect(table.getUpgradeOutput() == null);
    }
}

test "25. Smithing Table rejection: stone and wooden tools in base gear slot" {
    const low_tier = [_]ItemType{
        .stone_sword, .stone_pickaxe, .wooden_sword, .wooden_pickaxe,
    };

    for (low_tier) |item| {
        var table = SmithingTable.init();
        table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
        table.setSlot(1, EquipmentItem.initFull(item));
        table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

        try std.testing.expect(!table.isValidUpgrade());
        try std.testing.expect(table.getUpgradeOutput() == null);
    }
}

test "26. Smithing Table rejection: invalid or non-template item in slot 0" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.stick, 1)); // Stick instead of template
    table.setSlot(1, EquipmentItem.initFull(.diamond_sword));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    try std.testing.expect(!table.isValidUpgrade());

    // Armor trim template cannot upgrade to netherite
    table.setSlot(0, EquipmentItem.initStack(.coast_armor_trim_template, 1));
    try std.testing.expect(!table.isValidUpgrade());

    // Diamond in template slot
    table.setSlot(0, EquipmentItem.initStack(.diamond, 1));
    try std.testing.expect(!table.isValidUpgrade());
}

test "27. Smithing Table rejection: invalid addition item in slot 2" {
    const invalid_additions = [_]ItemType{
        .gold_ingot, .iron_ingot, .diamond, .netherite_scrap, .cobblestone, .netherrack,
    };

    for (invalid_additions) |add| {
        var table = SmithingTable.init();
        table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
        table.setSlot(1, EquipmentItem.initFull(.diamond_pickaxe));
        table.setSlot(2, EquipmentItem.initStack(add, 1));

        try std.testing.expect(!table.isValidUpgrade());
        try std.testing.expect(table.getUpgradeOutput() == null);
    }
}

test "28. Smithing Table rejection: empty slots" {
    // Missing template (slot 0 empty)
    var table = SmithingTable.init();
    table.setSlot(1, EquipmentItem.initFull(.diamond_pickaxe));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));
    try std.testing.expect(!table.isValidUpgrade());

    // Missing base gear (slot 1 empty)
    table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));
    try std.testing.expect(!table.isValidUpgrade());

    // Missing addition (slot 2 empty)
    table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, EquipmentItem.initFull(.diamond_pickaxe));
    try std.testing.expect(!table.isValidUpgrade());
}

test "29. Durability scaling: undamaged tool durability increases (Diamond Pickaxe 1561 -> Netherite Pickaxe 2031)" {
    const old_max = maxDurability(.diamond_pickaxe);
    const new_max = maxDurability(.netherite_pickaxe);
    try std.testing.expectEqual(@as(u16, 1561), old_max);
    try std.testing.expectEqual(@as(u16, 2031), new_max);

    const upgraded_dur = computeUpgradedDurability(.diamond_pickaxe, 1561);
    try std.testing.expectEqual(@as(u16, 2031), upgraded_dur);
}

test "30. Durability scaling: damaged equipment preserves exact damage taken across upgrade" {
    // Diamond Pickaxe (1561 max) damaged by 500 points (durability = 1061)
    const current_dur: u16 = 1061;
    const damage_taken = 1561 - current_dur;
    try std.testing.expectEqual(@as(u16, 500), damage_taken);

    // Netherite Pickaxe has 2031 max; after upgrade, should have 2031 - 500 = 1531 durability
    const new_dur = computeUpgradedDurability(.diamond_pickaxe, current_dur);
    try std.testing.expectEqual(@as(u16, 1531), new_dur);

    // Heavily damaged gear (durability = 1, damage = 1560)
    const heavy_dur = computeUpgradedDurability(.diamond_pickaxe, 1);
    try std.testing.expectEqual(@as(u16, 2031 - 1560), heavy_dur);
}

test "31. Durability scaling: armor pieces max durability increases" {
    // Helmet: 363 -> 407 (+44)
    try std.testing.expectEqual(@as(u16, 407), computeUpgradedDurability(.diamond_helmet, 363));

    // Chestplate: 528 -> 592 (+64)
    try std.testing.expectEqual(@as(u16, 592), computeUpgradedDurability(.diamond_chestplate, 528));

    // Leggings: 495 -> 555 (+60)
    try std.testing.expectEqual(@as(u16, 555), computeUpgradedDurability(.diamond_leggings, 495));

    // Boots: 429 -> 481 (+52)
    try std.testing.expectEqual(@as(u16, 481), computeUpgradedDurability(.diamond_boots, 429));

    // Damaged Chestplate with 28 damage taken: 592 - 28 = 564
    try std.testing.expectEqual(@as(u16, 564), computeUpgradedDurability(.diamond_chestplate, 500));
}

test "32. Armor toughness attribute: +3 toughness per netherite armor piece (+12 full set vs +8 diamond)" {
    // Diamond armor pieces have 2.0 toughness each
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), getArmorToughness(.diamond_helmet), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), getArmorToughness(.diamond_chestplate), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), getArmorToughness(.diamond_leggings), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), getArmorToughness(.diamond_boots), 0.001);

    // Netherite armor pieces have 3.0 toughness each (+3 per piece)
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), getArmorToughness(.netherite_helmet), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), getArmorToughness(.netherite_chestplate), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), getArmorToughness(.netherite_leggings), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), getArmorToughness(.netherite_boots), 0.001);

    // Full 4-piece suits: diamond = 8.0, netherite = 12.0 (+4.0 total upgrade)
    const diamond_set_toughness: f32 = 4.0 * 2.0;
    const netherite_set_toughness: f32 = 4.0 * 3.0;
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), diamond_set_toughness, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), netherite_set_toughness, 0.001);

    // Tools have 0.0 toughness
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getArmorToughness(.netherite_sword), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getArmorToughness(.diamond_pickaxe), 0.001);
}

test "33. Knockback resistance attribute: +10% per armor piece up to +40% for full suit" {
    // Individual pieces: +10% (0.10)
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), getKnockbackResistance(.netherite_helmet), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), getKnockbackResistance(.netherite_chestplate), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), getKnockbackResistance(.netherite_leggings), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), getKnockbackResistance(.netherite_boots), 0.001);

    // Diamond pieces have 0% knockback resistance
    try std.testing.expectApproxEqAbs(@as(f32, 0.00), getKnockbackResistance(.diamond_chestplate), 0.001);

    // Set calculation: 1 piece = 10%, 2 pieces = 20%, 3 pieces = 30%, 4 pieces = 40%
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), calculateSetKnockbackResistance(true, false, false, false), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.20), calculateSetKnockbackResistance(true, true, false, false), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), calculateSetKnockbackResistance(true, true, true, false), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.40), calculateSetKnockbackResistance(true, true, true, true), 0.001);
}

test "34. Knockback resistance: knockback impulse reduction on player" {
    const raw_impulse: f32 = 1.0;

    // 0 pieces: full knockback (1.0)
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), applyKnockbackReduction(raw_impulse, 0), 0.001);

    // 2 pieces (20% resistance): 1.0 * 0.8 = 0.8
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), applyKnockbackReduction(raw_impulse, 2), 0.001);

    // 4 pieces (full suit, 40% resistance): 1.0 * 0.6 = 0.6
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), applyKnockbackReduction(raw_impulse, 4), 0.001);
}

test "35. Attack damage attribute: +1 bonus damage for netherite weapons and tools over diamond" {
    // Sword: 7.0 -> 8.0 (+1)
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), getAttackDamage(.diamond_sword), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), getAttackDamage(.netherite_sword), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getAttackDamageBonusOverDiamond(.netherite_sword), 0.001);

    // Pickaxe: 5.0 -> 6.0 (+1)
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), getAttackDamage(.diamond_pickaxe), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), getAttackDamage(.netherite_pickaxe), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getAttackDamageBonusOverDiamond(.netherite_pickaxe), 0.001);

    // Axe: 9.0 -> 10.0 (+1)
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), getAttackDamage(.diamond_axe), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), getAttackDamage(.netherite_axe), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getAttackDamageBonusOverDiamond(.netherite_axe), 0.001);

    // Shovel: 5.5 -> 6.5 (+1)
    try std.testing.expectApproxEqAbs(@as(f32, 5.5), getAttackDamage(.diamond_shovel), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), getAttackDamage(.netherite_shovel), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getAttackDamageBonusOverDiamond(.netherite_shovel), 0.001);

    // Hoe: 1.0 -> 2.0 (+1)
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getAttackDamage(.diamond_hoe), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), getAttackDamage(.netherite_hoe), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getAttackDamageBonusOverDiamond(.netherite_hoe), 0.001);
}

test "36. Metadata preservation: existing enchantments preserved intact across upgrade" {
    var sword = EquipmentItem.initFull(.diamond_sword);
    _ = sword.addEnchantment(.sharpness, 5);
    _ = sword.addEnchantment(.unbreaking, 3);
    _ = sword.addEnchantment(.looting, 3);
    _ = sword.addEnchantment(.mending, 1);

    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, sword);
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    const upgraded = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_sword, upgraded.item);
    try std.testing.expectEqual(@as(u8, 4), upgraded.enchantment_count);
    try std.testing.expectEqual(@as(u8, 5), upgraded.getEnchantmentLevel(.sharpness));
    try std.testing.expectEqual(@as(u8, 3), upgraded.getEnchantmentLevel(.unbreaking));
    try std.testing.expectEqual(@as(u8, 3), upgraded.getEnchantmentLevel(.looting));
    try std.testing.expectEqual(@as(u8, 1), upgraded.getEnchantmentLevel(.mending));
}

test "37. Metadata preservation: anvil prior-work penalty / repair cost preserved intact across upgrade" {
    var pickaxe = EquipmentItem.initFull(.diamond_pickaxe);
    pickaxe.repair_cost = 15; // 4 prior anvil uses penalty: (1 << 4) - 1 = 15

    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, pickaxe);
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    const upgraded = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_pickaxe, upgraded.item);
    try std.testing.expectEqual(@as(u32, 15), upgraded.repair_cost);
}

test "38. Metadata preservation: custom item name preserved intact across upgrade" {
    var chestplate = EquipmentItem.initFull(.diamond_chestplate);
    chestplate.setName("Dragon Slayer");

    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 1));
    table.setSlot(1, chestplate);
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    const upgraded = table.getUpgradeOutput().?;
    try std.testing.expectEqual(ItemType.netherite_chestplate, upgraded.item);
    try std.testing.expectEqualStrings("Dragon Slayer", upgraded.getName().?);
}

test "39. Smithing Table execution: consumes 1 template, 1 base gear, and 1 netherite ingot" {
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(.netherite_upgrade_smithing_template, 2)); // 2 templates stacked
    table.setSlot(1, EquipmentItem.initFull(.diamond_axe));
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 3));                     // 3 ingots stacked

    const out = table.executeUpgrade().?;
    try std.testing.expectEqual(ItemType.netherite_axe, out.item);

    // Template slot should have 1 remaining
    try std.testing.expectEqual(@as(u8, 1), table.template_slot.count);
    try std.testing.expectEqual(ItemType.netherite_upgrade_smithing_template, table.template_slot.item);

    // Base gear slot should be cleared
    try std.testing.expect(table.base_gear_slot.isEmpty());

    // Addition slot should have 2 ingots remaining
    try std.testing.expectEqual(@as(u8, 2), table.addition_slot.count);
    try std.testing.expectEqual(ItemType.netherite_ingot, table.addition_slot.item);
}

test "40. Lava and fire immunity: all Netherite items are completely immune (isImmuneToLava = true)" {
    const netherite_family = [_]ItemType{
        .netherite_helmet, .netherite_chestplate, .netherite_leggings, .netherite_boots,
        .netherite_sword, .netherite_pickaxe, .netherite_axe, .netherite_shovel, .netherite_hoe,
        .netherite_ingot, .netherite_scrap, .ancient_debris, .netherite_block,
        .netherite_upgrade_smithing_template,
    };

    for (netherite_family) |item| {
        try std.testing.expect(isItemImmuneToLava(item));
        try std.testing.expect(isItemImmuneToFire(item));
        try std.testing.expect(isImmuneToLava(item));
        try std.testing.expect(isImmuneToFire(item));

        const dropped = LavaBuoyantItem.init(item);
        try std.testing.expect(dropped.isImmuneToLava);
        try std.testing.expect(isImmuneToLava(dropped));
    }
}

test "41. Lava and fire vulnerability: non-netherite items burn and are destroyed in lava" {
    const vulnerable_items = [_]ItemType{
        .diamond, .iron_ingot, .gold_ingot, .netherrack, .cobblestone,
        .diamond_pickaxe, .diamond_sword, .iron_sword, .leather_boots,
    };

    for (vulnerable_items) |item| {
        try std.testing.expect(!isItemImmuneToLava(item));
        try std.testing.expect(!isItemImmuneToFire(item));

        var dropped = LavaBuoyantItem.init(item);
        try std.testing.expect(!dropped.isImmuneToLava);
        const survived = dropped.tickInLava();
        try std.testing.expect(!survived); // Destroyed by lava!
    }
}

test "42. Lava buoyancy physics: submerged sinking item reverses downward momentum and floats upward" {
    var dropped_pick = LavaBuoyantItem.init(.netherite_pickaxe);
    dropped_pick.y = 20.0;
    dropped_pick.vy = -0.40; // Falling fast into lava lake

    // First tick slows the sinking momentum
    const s1 = dropped_pick.tickInLava();
    try std.testing.expect(s1);
    try std.testing.expect(dropped_pick.vy > -0.40);

    // After 10 ticks, vertical velocity has fully reversed into positive upward float
    for (0..10) |_| {
        _ = dropped_pick.tickInLava();
    }
    try std.testing.expect(dropped_pick.vy > 0.0);

    // Entity position is now ascending towards surface
    const pre_y = dropped_pick.y;
    _ = dropped_pick.tickInLava();
    try std.testing.expect(dropped_pick.y > pre_y);
}

test "43. Lava buoyancy physics: terminal upward float velocity capped at +0.10" {
    var high_vy: f32 = 0.50;
    high_vy = computeLavaBuoyancyVy(high_vy);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), high_vy, 0.001);

    var dropped_ingot = LavaBuoyantItem.init(.netherite_ingot);
    dropped_ingot.vy = 0.09;
    _ = dropped_ingot.tickInLava();
    try std.testing.expect(dropped_ingot.vy <= 0.10);
}

test "44. Blast resistance: Netherite Block blast resistance 1200 is immune to TNT and Bed explosions" {
    try std.testing.expectEqual(@as(f32, 1200.0), NETHERITE_BLOCK_BLAST_RESISTANCE);
    try std.testing.expectEqual(@as(f32, 1200.0), getBlastResistance(.netherite_block));
    try std.testing.expectEqual(@as(f32, 1200.0), getBlastResistance(.ancient_debris));

    // Survives TNT (4.0 power) and Bed (5.0 power) blasts
    try std.testing.expect(isImmuneToExplosion(.netherite_block));
    try std.testing.expect(isImmuneToExplosion(.ancient_debris));

    // Netherrack (0.4 blast resistance) is destroyed
    try std.testing.expectEqual(@as(f32, 0.4), getBlastResistance(.netherrack));
    try std.testing.expect(!isImmuneToExplosion(.netherrack));
}

test "45. Full end-to-end lifecycle: Bastion loot to template duplication to smithing upgrade to lava buoyancy recovery" {
    // 1. Player explores a Bastion Remnant Treasure Room: guaranteed template drop
    const treasure_bastion = BastionVariant.treasure_room;
    try std.testing.expect(treasure_bastion.guaranteesNetheriteUpgradeTemplate());
    try std.testing.expect(generatesBastionTemplateLoot(treasure_bastion, 0.5));
    const looted_template = ItemType.netherite_upgrade_smithing_template;

    // 2. Duplicate template using 1 template + 7 diamonds + 1 netherrack
    const dup = duplicateTemplateDirect(1, 7, 1);
    try std.testing.expect(dup.success);
    try std.testing.expectEqual(@as(u8, 2), dup.templates_out);

    // 3. Prepare high-tier Diamond Pickaxe with Efficiency V, Unbreaking III, Fortune III, Mending,
    //    custom name "Vein Miner", and sustained 300 damage
    var base_pick = EquipmentItem.init(.diamond_pickaxe, 1561 - 300); // 1261 durability
    _ = base_pick.addEnchantment(.efficiency, 5);
    _ = base_pick.addEnchantment(.unbreaking, 3);
    _ = base_pick.addEnchantment(.fortune, 3);
    _ = base_pick.addEnchantment(.mending, 1);
    base_pick.repair_cost = 7;
    base_pick.setName("Vein Miner");

    // 4. Place ingredients into 3-slot Smithing Table
    var table = SmithingTable.init();
    table.setSlot(0, EquipmentItem.initStack(looted_template, 1));
    table.setSlot(1, base_pick);
    table.setSlot(2, EquipmentItem.initStack(.netherite_ingot, 1));

    // 5. Upgrade transformation executes cleanly
    const upgraded = table.executeUpgrade().?;
    try std.testing.expectEqual(ItemType.netherite_pickaxe, upgraded.item);
    try std.testing.expectEqual(@as(u16, 2031 - 300), upgraded.durability); // Preserved 300 damage taken!
    try std.testing.expectEqual(@as(u32, 7), upgraded.repair_cost);         // Preserved prior-work penalty!
    try std.testing.expectEqualStrings("Vein Miner", upgraded.getName().?);  // Preserved custom name!
    try std.testing.expectEqual(@as(u8, 5), upgraded.getEnchantmentLevel(.efficiency));
    try std.testing.expectEqual(@as(u8, 3), upgraded.getEnchantmentLevel(.unbreaking));
    try std.testing.expectEqual(@as(u8, 3), upgraded.getEnchantmentLevel(.fortune));
    try std.testing.expectEqual(@as(u8, 1), upgraded.getEnchantmentLevel(.mending));

    // Smithing table consumed all single inputs
    try std.testing.expect(table.template_slot.isEmpty());
    try std.testing.expect(table.base_gear_slot.isEmpty());
    try std.testing.expect(table.addition_slot.isEmpty());

    // 6. Upgraded tool accidentally dropped into Nether lava lake
    var dropped = LavaBuoyantItem.init(upgraded.item);
    dropped.y = 31.0;
    dropped.vy = -0.30;
    try std.testing.expect(dropped.isImmuneToLava);

    // Ticking lava buoyancy recovers tool to lava surface safely
    for (0..20) |_| {
        try std.testing.expect(dropped.tickInLava());
    }
    try std.testing.expect(dropped.y > 31.0);
    try std.testing.expect(dropped.vy > 0.0);
}
