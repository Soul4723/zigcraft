const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Chance (out of 100) for an anvil to advance one damage stage on operation (12%).
pub const ANVIL_OPERATION_BREAK_CHANCE_PERCENT: u8 = 12;

/// Threshold in XP levels where anvil operations are deemed "Too Expensive!" in Survival (40 levels).
pub const TOO_EXPENSIVE_THRESHOLD: u32 = 40;

/// Base XP level cost for combining two items of the same type in an anvil (2 levels in Minecraft Java Edition).
pub const BASE_COMBINE_COST: u32 = 2;

/// Additional XP level cost for renaming an item in an anvil (1 level).
pub const RENAME_COST: u32 = 1;

/// Bonus durability percentage granted when combining two damaged items (12% of max durability).
pub const COMBINE_BONUS_PERCENT: u32 = 12;

/// Maximum damage in HP dealt by a falling anvil (40.0 HP = 20 hearts).
pub const MAX_FALLING_CRUSH_DAMAGE: f32 = 40.0;

/// Damage reduction percentage granted by wearing a helmet against falling anvil crush (25%).
pub const HELMET_DAMAGE_REDUCTION: f32 = 0.25;

/// Multiplier applied to crush damage when target wears a helmet (0.75 = 1.0 - 0.25).
pub const HELMET_DAMAGE_MULTIPLIER: f32 = 0.75;

/// Diamonds consumed per smithing template duplication craft (7 diamonds).
pub const DIAMONDS_PER_TEMPLATE_DUPLICATION: u8 = 7;

/// Output templates produced per smithing template duplication craft (2 templates).
pub const TEMPLATES_PER_DUPLICATION_OUTPUT: u8 = 2;

// ============================================================================
// Enums
// ============================================================================

/// 3-stage fracture progression of an anvil before destruction.
pub const AnvilDamageStage = enum(u2) {
    intact = 0,
    chipped = 1,
    damaged = 2,
    destroyed = 3,

    /// Returns the next degradation stage, clamping at destroyed.
    pub fn next(self: AnvilDamageStage) AnvilDamageStage {
        return switch (self) {
            .intact => .chipped,
            .chipped => .damaged,
            .damaged, .destroyed => .destroyed,
        };
    }

    /// Whether this anvil is destroyed / broken.
    pub fn isDestroyed(self: AnvilDamageStage) bool {
        return self == .destroyed;
    }

    /// Advance anvil fracture stage on an operation with 12% probability (roll < 12).
    pub fn advanceOnOperation(self: AnvilDamageStage, roll: u8) AnvilDamageStage {
        if (roll < ANVIL_OPERATION_BREAK_CHANCE_PERCENT) {
            return self.next();
        }
        return self;
    }

    /// Advance anvil fracture stage when landing from a fall.
    /// In Minecraft, fall_distance > 1.0 causes wear with chance = 5% + (fall_distance * 5%).
    pub fn advanceOnFall(self: AnvilDamageStage, fall_distance: f32, roll: u8) AnvilDamageStage {
        if (fall_distance <= 1.0) return self;
        const chance = fallBreakChancePercent(fall_distance);
        if (roll < chance) {
            return self.next();
        }
        return self;
    }

    pub fn name(self: AnvilDamageStage) []const u8 {
        return switch (self) {
            .intact => "Anvil",
            .chipped => "Chipped Anvil",
            .damaged => "Damaged Anvil",
            .destroyed => "Destroyed Anvil",
        };
    }
};

/// 11 armor trim materials supported by the Smithing Table.
pub const SmithingTrimMaterial = enum {
    amethyst,
    copper,
    diamond,
    emerald,
    gold,
    iron,
    lapis,
    netherite,
    quartz,
    redstone,
    resin,

    pub fn name(self: SmithingTrimMaterial) []const u8 {
        return switch (self) {
            .amethyst => "Amethyst",
            .copper => "Copper",
            .diamond => "Diamond",
            .emerald => "Emerald",
            .gold => "Gold",
            .iron => "Iron",
            .lapis => "Lapis Lazuli",
            .netherite => "Netherite",
            .quartz => "Quartz",
            .redstone => "Redstone",
            .resin => "Resin",
        };
    }

    pub fn ingredientItemName(self: SmithingTrimMaterial) []const u8 {
        return switch (self) {
            .amethyst => "Amethyst Shard",
            .copper => "Copper Ingot",
            .diamond => "Diamond",
            .emerald => "Emerald",
            .gold => "Gold Ingot",
            .iron => "Iron Ingot",
            .lapis => "Lapis Lazuli",
            .netherite => "Netherite Ingot",
            .quartz => "Nether Quartz",
            .redstone => "Redstone Dust",
            .resin => "Resin Brick",
        };
    }

    pub fn colorHex(self: SmithingTrimMaterial) u24 {
        return switch (self) {
            .amethyst => 0x9a5cc6,
            .copper => 0xb4684d,
            .diamond => 0x64c8d8,
            .emerald => 0x11a036,
            .gold => 0xe6b539,
            .iron => 0xdedede,
            .lapis => 0x2b56a3,
            .netherite => 0x3b3839,
            .quartz => 0xe3ded5,
            .redstone => 0x9e1010,
            .resin => 0xe05e26,
        };
    }
};

/// 18 armor trim pattern templates in Minecraft 1.20-1.21.
pub const SmithingTrimPattern = enum {
    silence,
    ward,
    spire,
    vex,
    rib,
    snout,
    eye,
    tide,
    flow,
    bolt,
    wayfinder,
    raiser,
    shaper,
    host,
    coast,
    dune,
    sentry,
    wild,

    pub fn name(self: SmithingTrimPattern) []const u8 {
        return switch (self) {
            .silence => "Silence Armor Trim",
            .ward => "Ward Armor Trim",
            .spire => "Spire Armor Trim",
            .vex => "Vex Armor Trim",
            .rib => "Rib Armor Trim",
            .snout => "Snout Armor Trim",
            .eye => "Eye Armor Trim",
            .tide => "Tide Armor Trim",
            .flow => "Flow Armor Trim",
            .bolt => "Bolt Armor Trim",
            .wayfinder => "Wayfinder Armor Trim",
            .raiser => "Raiser Armor Trim",
            .shaper => "Shaper Armor Trim",
            .host => "Host Armor Trim",
            .coast => "Coast Armor Trim",
            .dune => "Dune Armor Trim",
            .sentry => "Sentry Armor Trim",
            .wild => "Wild Armor Trim",
        };
    }

    pub fn hostBlockName(self: SmithingTrimPattern) []const u8 {
        return switch (self) {
            .silence, .ward => "Cobbled Deepslate",
            .spire => "Purpur Block",
            .vex, .coast, .sentry => "Cobblestone",
            .rib => "Netherrack",
            .snout => "Blackstone",
            .eye => "End Stone",
            .tide => "Prismarine",
            .flow => "Breeze Rod",
            .bolt => "Copper Block",
            .wayfinder, .raiser, .shaper, .host => "Terracotta",
            .dune => "Sandstone",
            .wild => "Mossy Cobblestone",
        };
    }

    pub fn structureOrigin(self: SmithingTrimPattern) []const u8 {
        return switch (self) {
            .silence, .ward => "Ancient City",
            .spire => "End City",
            .vex => "Woodland Mansion",
            .rib => "Nether Fortress",
            .snout => "Bastion Remnant",
            .eye => "Stronghold",
            .tide => "Ocean Monument",
            .flow, .bolt => "Trial Chamber",
            .wayfinder, .raiser, .shaper, .host => "Trail Ruins",
            .coast => "Shipwreck",
            .dune => "Desert Pyramid",
            .sentry => "Pillager Outpost",
            .wild => "Jungle Temple",
        };
    }
};

// ============================================================================
// Structs & Return Types
// ============================================================================

/// Result of an anvil tool combination operation.
pub const AnvilCombineResult = struct {
    new_durability: u16,
    new_uses: u5,
    xp_level_cost: u32,
    too_expensive: bool,
};

/// Result of a falling anvil crush impact on an entity.
pub const FallingCrushResult = struct {
    damage: f32,
    helmet_durability_loss: u16,
};

/// Result of a smithing template duplication craft.
pub const TemplateDuplicationResult = struct {
    templates_out: u8,
    diamonds_used: u8,
};

/// Stateful representation of an in-world anvil block.
pub const AnvilBlockState = struct {
    stage: AnvilDamageStage = .intact,
    uses_completed: u32 = 0,

    pub fn onUse(self: *AnvilBlockState, roll: u8) AnvilDamageStage {
        self.uses_completed += 1;
        self.stage = self.stage.advanceOnOperation(roll);
        return self.stage;
    }

    pub fn onFall(self: *AnvilBlockState, fall_distance: f32, roll: u8) AnvilDamageStage {
        self.stage = self.stage.advanceOnFall(fall_distance, roll);
        return self.stage;
    }

    pub fn isBroken(self: AnvilBlockState) bool {
        return self.stage.isDestroyed();
    }
};

// ============================================================================
// Core Functions
// ============================================================================

/// Computes the exponential prior-work penalty cost: (1 << anvil_uses) - 1.
/// Produces: 0, 1, 3, 7, 15, 31, 63, ... XP levels.
pub fn priorWorkPenaltyCost(anvil_uses: u5) u32 {
    return (@as(u32, 1) << anvil_uses) - 1;
}

/// Checks if an anvil operation exceeds the Survival cap of 40 XP levels ("Too Expensive!").
pub fn isTooExpensive(total_xp_cost: u32) bool {
    return total_xp_cost >= TOO_EXPENSIVE_THRESHOLD;
}

/// Advance an anvil damage stage on operation with a 12% probability roll (roll < 12).
pub fn advanceAnvilStage(current: AnvilDamageStage, roll: u8) AnvilDamageStage {
    return current.advanceOnOperation(roll);
}

/// Calculate the break chance percentage for an anvil falling from height.
/// When fall_distance > 1.0, chance is 5% base + 5% per meter fallen, clamped at 100%.
pub fn fallBreakChancePercent(fall_distance: f32) u8 {
    if (fall_distance <= 1.0) return 0;
    const chance = 5.0 + (fall_distance * 5.0);
    if (chance >= 100.0) return 100;
    return @intFromFloat(chance);
}

/// Advance an anvil damage stage on landing from height.
pub fn advanceAnvilStageOnFall(current: AnvilDamageStage, fall_distance: f32, roll: u8) AnvilDamageStage {
    return current.advanceOnFall(fall_distance, roll);
}

/// Combines two damaged tools with +12% bonus durability, increments prior uses to
/// @max(target_uses, sacrifice_uses) + 1, and adds +1 level for custom item renaming.
pub fn computeAnvilCombine(
    target_durability: u16,
    sacrifice_durability: u16,
    max_durability: u16,
    target_uses: u5,
    sacrifice_uses: u5,
    rename_changed: bool,
) AnvilCombineResult {
    const bonus: u32 = (@as(u32, max_durability) * COMBINE_BONUS_PERCENT) / 100;
    const combined: u32 = @as(u32, target_durability) + @as(u32, sacrifice_durability) + bonus;
    const new_durability: u16 = @intCast(@min(combined, @as(u32, max_durability)));

    const max_prior = @max(target_uses, sacrifice_uses);
    const new_uses: u5 = if (max_prior < 31) max_prior + 1 else 31;

    const target_penalty = priorWorkPenaltyCost(target_uses);
    const sacrifice_penalty = priorWorkPenaltyCost(sacrifice_uses);
    const rename_cost: u32 = if (rename_changed) RENAME_COST else 0;

    const total_cost = BASE_COMBINE_COST + target_penalty + sacrifice_penalty + rename_cost;
    const too_expensive = isTooExpensive(total_cost);

    return .{
        .new_durability = new_durability,
        .new_uses = new_uses,
        .xp_level_cost = total_cost,
        .too_expensive = too_expensive,
    };
}

/// Calculates falling anvil crush damage: 2.0 * (fall_blocks - 1.0) capped at 40.0 HP.
/// Wearing a helmet reduces crush damage by 25% (* 0.75) at the cost of helmet durability.
pub fn fallingAnvilCrushDamage(fall_blocks: f32, target_has_helmet: bool) FallingCrushResult {
    if (fall_blocks <= 1.0) {
        return .{
            .damage = 0.0,
            .helmet_durability_loss = 0,
        };
    }
    const raw_damage = 2.0 * (fall_blocks - 1.0);
    const base_damage = @min(raw_damage, MAX_FALLING_CRUSH_DAMAGE);
    if (target_has_helmet) {
        const damage = base_damage * HELMET_DAMAGE_MULTIPLIER;
        const helmet_loss: u16 = @intFromFloat(base_damage);
        return .{
            .damage = damage,
            .helmet_durability_loss = helmet_loss,
        };
    } else {
        return .{
            .damage = base_damage,
            .helmet_durability_loss = 0,
        };
    }
}

/// Duplicate a smithing template: 1 Template + 7 Diamonds + 1 Host Block -> 2 Templates.
pub fn duplicateSmithingTemplate(has_template: bool, diamonds: u8, has_matching_host_block: bool) TemplateDuplicationResult {
    if (!has_template or diamonds < DIAMONDS_PER_TEMPLATE_DUPLICATION or !has_matching_host_block) {
        return .{
            .templates_out = 0,
            .diamonds_used = 0,
        };
    }
    return .{
        .templates_out = TEMPLATES_PER_DUPLICATION_OUTPUT,
        .diamonds_used = DIAMONDS_PER_TEMPLATE_DUPLICATION,
    };
}

/// Batch duplicate smithing templates when multiple sets of ingredients are available.
pub fn duplicateSmithingTemplateBatch(templates_in: u8, diamonds: u8, host_blocks: u8) TemplateDuplicationResult {
    if (templates_in == 0 or diamonds < DIAMONDS_PER_TEMPLATE_DUPLICATION or host_blocks == 0) {
        return .{ .templates_out = 0, .diamonds_used = 0 };
    }
    const crafts_from_diamonds = diamonds / DIAMONDS_PER_TEMPLATE_DUPLICATION;
    const crafts = @min(templates_in, @min(crafts_from_diamonds, host_blocks));
    return .{
        .templates_out = crafts * TEMPLATES_PER_DUPLICATION_OUTPUT,
        .diamonds_used = crafts * DIAMONDS_PER_TEMPLATE_DUPLICATION,
    };
}

// ============================================================================
// Smithing Table Netherite Upgrade & Armor Trim Matrix
// ============================================================================

/// Diamond equipment pieces that can be upgraded to Netherite.
pub const NetheriteEquipment = enum {
    helmet,
    chestplate,
    leggings,
    boots,
    sword,
    pickaxe,
    axe,
    shovel,
    hoe,

    pub fn diamondMaxDurability(self: NetheriteEquipment) u16 {
        return switch (self) {
            .helmet => 363,
            .chestplate => 528,
            .leggings => 495,
            .boots => 429,
            .sword, .pickaxe, .axe, .shovel, .hoe => 1561,
        };
    }

    pub fn netheriteMaxDurability(self: NetheriteEquipment) u16 {
        return switch (self) {
            .helmet => 407,
            .chestplate => 592,
            .leggings => 555,
            .boots => 481,
            .sword, .pickaxe, .axe, .shovel, .hoe => 2031,
        };
    }
};

/// Check if a valid Netherite Upgrade recipe is present on the Smithing Table.
pub fn canNetheriteUpgrade(has_template: bool, is_diamond_gear: bool, has_netherite_ingot: bool) bool {
    return has_template and is_diamond_gear and has_netherite_ingot;
}

pub const NetheriteUpgradeResult = struct {
    success: bool,
    new_durability: u16,
    new_max_durability: u16,
};

/// Compute Netherite upgrade in the Smithing Table, preserving damage taken.
pub fn computeNetheriteUpgrade(
    equipment: NetheriteEquipment,
    current_durability: u16,
    has_template: bool,
    has_ingot: bool,
) NetheriteUpgradeResult {
    if (!has_template or !has_ingot) {
        return .{
            .success = false,
            .new_durability = current_durability,
            .new_max_durability = equipment.diamondMaxDurability(),
        };
    }
    const old_max = equipment.diamondMaxDurability();
    const new_max = equipment.netheriteMaxDurability();
    const damage_taken = if (current_durability <= old_max) old_max - current_durability else 0;
    const new_dur = if (new_max > damage_taken) new_max - damage_taken else 1;
    return .{
        .success = true,
        .new_durability = new_dur,
        .new_max_durability = new_max,
    };
}

/// Armor slot types for trimming.
pub const ArmorSlot = enum {
    helmet,
    chestplate,
    leggings,
    boots,
};

/// Specification of trimmed armor.
pub const TrimmedArmorSpec = struct {
    slot: ArmorSlot,
    pattern: SmithingTrimPattern,
    material: SmithingTrimMaterial,
};

/// Apply armor trim in the Smithing Table.
pub fn applyArmorTrim(
    has_template: bool,
    pattern: SmithingTrimPattern,
    slot: ArmorSlot,
    material: SmithingTrimMaterial,
    has_material: bool,
) ?TrimmedArmorSpec {
    if (!has_template or !has_material) return null;
    return .{
        .slot = slot,
        .pattern = pattern,
        .material = material,
    };
}

// ============================================================================
// Unit Tests (At least 14 required; 28 tests provided)
// ============================================================================

test "AnvilDamageStage enum mapping and values" {
    try std.testing.expectEqual(@as(u2, 0), @intFromEnum(AnvilDamageStage.intact));
    try std.testing.expectEqual(@as(u2, 1), @intFromEnum(AnvilDamageStage.chipped));
    try std.testing.expectEqual(@as(u2, 2), @intFromEnum(AnvilDamageStage.damaged));
    try std.testing.expectEqual(@as(u2, 3), @intFromEnum(AnvilDamageStage.destroyed));
    try std.testing.expectEqualStrings("Anvil", AnvilDamageStage.intact.name());
    try std.testing.expectEqualStrings("Chipped Anvil", AnvilDamageStage.chipped.name());
    try std.testing.expectEqualStrings("Damaged Anvil", AnvilDamageStage.damaged.name());
    try std.testing.expectEqualStrings("Destroyed Anvil", AnvilDamageStage.destroyed.name());
}

test "AnvilDamageStage next progression and isDestroyed" {
    const s0 = AnvilDamageStage.intact;
    try std.testing.expect(!s0.isDestroyed());

    const s1 = s0.next();
    try std.testing.expectEqual(AnvilDamageStage.chipped, s1);
    try std.testing.expect(!s1.isDestroyed());

    const s2 = s1.next();
    try std.testing.expectEqual(AnvilDamageStage.damaged, s2);
    try std.testing.expect(!s2.isDestroyed());

    const s3 = s2.next();
    try std.testing.expectEqual(AnvilDamageStage.destroyed, s3);
    try std.testing.expect(s3.isDestroyed());

    const s4 = s3.next();
    try std.testing.expectEqual(AnvilDamageStage.destroyed, s4);
    try std.testing.expect(s4.isDestroyed());
}

test "anvil operation 12% fracture chance progression" {
    // roll < 12 advances stage
    try std.testing.expectEqual(AnvilDamageStage.chipped, advanceAnvilStage(.intact, 0));
    try std.testing.expectEqual(AnvilDamageStage.chipped, advanceAnvilStage(.intact, 5));
    try std.testing.expectEqual(AnvilDamageStage.chipped, advanceAnvilStage(.intact, 11));

    // roll >= 12 does not advance
    try std.testing.expectEqual(AnvilDamageStage.intact, advanceAnvilStage(.intact, 12));
    try std.testing.expectEqual(AnvilDamageStage.intact, advanceAnvilStage(.intact, 50));
    try std.testing.expectEqual(AnvilDamageStage.intact, advanceAnvilStage(.intact, 99));

    // chipped -> damaged with roll < 12
    try std.testing.expectEqual(AnvilDamageStage.damaged, advanceAnvilStage(.chipped, 7));
    try std.testing.expectEqual(AnvilDamageStage.chipped, advanceAnvilStage(.chipped, 12));

    // damaged -> destroyed with roll < 12
    try std.testing.expectEqual(AnvilDamageStage.destroyed, advanceAnvilStage(.damaged, 3));
    try std.testing.expectEqual(AnvilDamageStage.damaged, advanceAnvilStage(.damaged, 20));
}

test "anvil operation on destroyed stays destroyed" {
    try std.testing.expectEqual(AnvilDamageStage.destroyed, advanceAnvilStage(.destroyed, 0));
    try std.testing.expectEqual(AnvilDamageStage.destroyed, advanceAnvilStage(.destroyed, 99));
}

test "anvil falling damage stage progression threshold <= 1.0 block" {
    // fall_distance <= 1.0 never damages anvil (0% chance)
    try std.testing.expectEqual(@as(u8, 0), fallBreakChancePercent(0.0));
    try std.testing.expectEqual(@as(u8, 0), fallBreakChancePercent(0.5));
    try std.testing.expectEqual(@as(u8, 0), fallBreakChancePercent(1.0));

    try std.testing.expectEqual(AnvilDamageStage.intact, advanceAnvilStageOnFall(.intact, 1.0, 0));
    try std.testing.expectEqual(AnvilDamageStage.intact, advanceAnvilStageOnFall(.intact, 0.5, 0));
}

test "anvil falling damage stage progression from height > 1.0 block" {
    // 2.0 blocks -> 5% + (2.0 * 5%) = 15%
    try std.testing.expectEqual(@as(u8, 15), fallBreakChancePercent(2.0));
    try std.testing.expectEqual(AnvilDamageStage.chipped, advanceAnvilStageOnFall(.intact, 2.0, 10)); // 10 < 15 -> advance
    try std.testing.expectEqual(AnvilDamageStage.intact, advanceAnvilStageOnFall(.intact, 2.0, 15)); // 15 >= 15 -> unchanged

    // 10.0 blocks -> 5% + (10.0 * 5%) = 55%
    try std.testing.expectEqual(@as(u8, 55), fallBreakChancePercent(10.0));
    try std.testing.expectEqual(AnvilDamageStage.chipped, advanceAnvilStageOnFall(.intact, 10.0, 50));

    // 20.0 blocks -> 100% chance
    try std.testing.expectEqual(@as(u8, 100), fallBreakChancePercent(20.0));
    try std.testing.expectEqual(AnvilDamageStage.chipped, advanceAnvilStageOnFall(.intact, 20.0, 99));
}

test "AnvilBlockState tracking uses and stage transitions" {
    var anvil = AnvilBlockState{};
    try std.testing.expectEqual(AnvilDamageStage.intact, anvil.stage);
    try std.testing.expectEqual(@as(u32, 0), anvil.uses_completed);
    try std.testing.expect(!anvil.isBroken());

    // 1st use, roll 50 (no break)
    _ = anvil.onUse(50);
    try std.testing.expectEqual(AnvilDamageStage.intact, anvil.stage);
    try std.testing.expectEqual(@as(u32, 1), anvil.uses_completed);

    // 2nd use, roll 5 (breaks to chipped)
    _ = anvil.onUse(5);
    try std.testing.expectEqual(AnvilDamageStage.chipped, anvil.stage);
    try std.testing.expectEqual(@as(u32, 2), anvil.uses_completed);

    // fall from 5 blocks, roll 10 (breaks to damaged)
    _ = anvil.onFall(5.0, 10);
    try std.testing.expectEqual(AnvilDamageStage.damaged, anvil.stage);

    // 3rd use, roll 2 (breaks to destroyed)
    _ = anvil.onUse(2);
    try std.testing.expectEqual(AnvilDamageStage.destroyed, anvil.stage);
    try std.testing.expect(anvil.isBroken());
}

test "priorWorkPenaltyCost exponential sequence (2^n - 1)" {
    // 0 -> 0, 1 -> 1, 2 -> 3, 3 -> 7, 4 -> 15, 5 -> 31, 6 -> 63
    try std.testing.expectEqual(@as(u32, 0), priorWorkPenaltyCost(0));
    try std.testing.expectEqual(@as(u32, 1), priorWorkPenaltyCost(1));
    try std.testing.expectEqual(@as(u32, 3), priorWorkPenaltyCost(2));
    try std.testing.expectEqual(@as(u32, 7), priorWorkPenaltyCost(3));
    try std.testing.expectEqual(@as(u32, 15), priorWorkPenaltyCost(4));
    try std.testing.expectEqual(@as(u32, 31), priorWorkPenaltyCost(5));
    try std.testing.expectEqual(@as(u32, 63), priorWorkPenaltyCost(6));
}

test "priorWorkPenaltyCost maximum u5 shift boundary" {
    // u5 max is 31: (1 << 31) - 1 = 2147483647
    const max_penalty = priorWorkPenaltyCost(31);
    try std.testing.expectEqual(@as(u32, 2147483647), max_penalty);
}

test "isTooExpensive threshold at 40 levels" {
    try std.testing.expect(!isTooExpensive(0));
    try std.testing.expect(!isTooExpensive(1));
    try std.testing.expect(!isTooExpensive(20));
    try std.testing.expect(!isTooExpensive(38));
    try std.testing.expect(!isTooExpensive(39));
    try std.testing.expect(isTooExpensive(40));
    try std.testing.expect(isTooExpensive(41));
    try std.testing.expect(isTooExpensive(100));
}

test "computeAnvilCombine durability +12% bonus calculation" {
    // max = 1000, 12% bonus = 120
    // target = 200, sacrifice = 300 -> 200 + 300 + 120 = 620
    const res = computeAnvilCombine(200, 300, 1000, 0, 0, false);
    try std.testing.expectEqual(@as(u16, 620), res.new_durability);
    try std.testing.expectEqual(@as(u5, 1), res.new_uses);
    try std.testing.expectEqual(@as(u32, 2), res.xp_level_cost); // base 2 levels
    try std.testing.expect(!res.too_expensive);
}

test "computeAnvilCombine durability clamping at max" {
    // max = 250, 12% bonus = 30
    // target = 200, sacrifice = 100 -> 200 + 100 + 30 = 330 -> clamped to 250
    const res = computeAnvilCombine(200, 100, 250, 0, 0, false);
    try std.testing.expectEqual(@as(u16, 250), res.new_durability);
}

test "computeAnvilCombine prior uses progression max + 1" {
    // target_uses = 1, sacrifice_uses = 3 -> new_uses = @max(1, 3) + 1 = 4
    const res = computeAnvilCombine(50, 50, 100, 1, 3, false);
    try std.testing.expectEqual(@as(u5, 4), res.new_uses);

    // target_uses = 4, sacrifice_uses = 2 -> new_uses = @max(4, 2) + 1 = 5
    const res2 = computeAnvilCombine(50, 50, 100, 4, 2, false);
    try std.testing.expectEqual(@as(u5, 5), res2.new_uses);
}

test "computeAnvilCombine rename cost adds +1 level" {
    // target_uses = 0, sacrifice_uses = 0, rename = true -> base 2 + 1 = 3
    const res = computeAnvilCombine(100, 100, 500, 0, 0, true);
    try std.testing.expectEqual(@as(u32, 3), res.xp_level_cost);
    try std.testing.expect(!res.too_expensive);
}

test "computeAnvilCombine total cost with prior work penalties" {
    // target_uses = 2 (penalty 3), sacrifice_uses = 3 (penalty 7), rename = true (1)
    // base 2 + 3 + 7 + 1 = 13 levels
    const res = computeAnvilCombine(100, 100, 500, 2, 3, true);
    try std.testing.expectEqual(@as(u32, 13), res.xp_level_cost);
    try std.testing.expect(!res.too_expensive);
}

test "computeAnvilCombine triggers too_expensive at >= 40 levels" {
    // target_uses = 5 (penalty 31), sacrifice_uses = 3 (penalty 7)
    // base 2 + 31 + 7 = 40 levels -> Too Expensive!
    const res = computeAnvilCombine(100, 100, 500, 5, 3, false);
    try std.testing.expectEqual(@as(u32, 40), res.xp_level_cost);
    try std.testing.expect(res.too_expensive);

    // target_uses = 5 (31), sacrifice_uses = 4 (15) -> base 2 + 31 + 15 = 48 -> Too Expensive!
    const res2 = computeAnvilCombine(100, 100, 500, 5, 4, false);
    try std.testing.expectEqual(@as(u32, 48), res2.xp_level_cost);
    try std.testing.expect(res2.too_expensive);
}

test "fallingAnvilCrushDamage linear scaling below cap" {
    // fall 2.0 blocks: 2.0 * (2.0 - 1.0) = 2.0 HP
    const c1 = fallingAnvilCrushDamage(2.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), c1.damage, 0.0001);
    try std.testing.expectEqual(@as(u16, 0), c1.helmet_durability_loss);

    // fall 5.0 blocks: 2.0 * (5.0 - 1.0) = 8.0 HP
    const c2 = fallingAnvilCrushDamage(5.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), c2.damage, 0.0001);

    // fall 6.0 blocks: 2.0 * (6.0 - 1.0) = 10.0 HP
    const c3 = fallingAnvilCrushDamage(6.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), c3.damage, 0.0001);
}

test "fallingAnvilCrushDamage minimum height threshold <= 1.0 block" {
    // fall 0.0 and 1.0 deal 0 damage
    const c0 = fallingAnvilCrushDamage(0.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c0.damage, 0.0001);
    try std.testing.expectEqual(@as(u16, 0), c0.helmet_durability_loss);

    const c1 = fallingAnvilCrushDamage(1.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c1.damage, 0.0001);
    try std.testing.expectEqual(@as(u16, 0), c1.helmet_durability_loss);

    const c_sub = fallingAnvilCrushDamage(0.75, true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c_sub.damage, 0.0001);
    try std.testing.expectEqual(@as(u16, 0), c_sub.helmet_durability_loss);
}

test "fallingAnvilCrushDamage cap at 40.0 HP" {
    // 21.0 blocks: 2.0 * 20.0 = 40.0 HP
    const c21 = fallingAnvilCrushDamage(21.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), c21.damage, 0.0001);

    // 30.0 blocks: 2.0 * 29.0 = 58.0 -> capped at 40.0 HP
    const c30 = fallingAnvilCrushDamage(30.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), c30.damage, 0.0001);

    // 100.0 blocks: capped at 40.0 HP
    const c100 = fallingAnvilCrushDamage(100.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), c100.damage, 0.0001);
}

test "fallingAnvilCrushDamage 25% helmet reduction and durability loss" {
    // fall 6.0 blocks: raw 10.0 HP
    // with helmet: 10.0 * 0.75 = 7.5 HP, helmet loses 10 durability
    const c = fallingAnvilCrushDamage(6.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), c.damage, 0.0001);
    try std.testing.expectEqual(@as(u16, 10), c.helmet_durability_loss);
}

test "fallingAnvilCrushDamage helmet reduction with 40.0 HP cap" {
    // fall 30.0 blocks: raw 40.0 HP (capped)
    // with helmet: 40.0 * 0.75 = 30.0 HP, helmet loses 40 durability
    const c = fallingAnvilCrushDamage(30.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), c.damage, 0.0001);
    try std.testing.expectEqual(@as(u16, 40), c.helmet_durability_loss);
}

test "SmithingTrimMaterial enum completeness and properties" {
    const materials = [_]SmithingTrimMaterial{
        .amethyst, .copper, .diamond, .emerald, .gold,
        .iron,     .lapis,  .netherite, .quartz,  .redstone,
        .resin,
    };
    try std.testing.expectEqual(@as(usize, 11), materials.len);

    try std.testing.expectEqualStrings("Amethyst", SmithingTrimMaterial.amethyst.name());
    try std.testing.expectEqualStrings("Copper", SmithingTrimMaterial.copper.name());
    try std.testing.expectEqualStrings("Diamond", SmithingTrimMaterial.diamond.name());
    try std.testing.expectEqualStrings("Emerald", SmithingTrimMaterial.emerald.name());
    try std.testing.expectEqualStrings("Gold", SmithingTrimMaterial.gold.name());
    try std.testing.expectEqualStrings("Iron", SmithingTrimMaterial.iron.name());
    try std.testing.expectEqualStrings("Lapis Lazuli", SmithingTrimMaterial.lapis.name());
    try std.testing.expectEqualStrings("Netherite", SmithingTrimMaterial.netherite.name());
    try std.testing.expectEqualStrings("Quartz", SmithingTrimMaterial.quartz.name());
    try std.testing.expectEqualStrings("Redstone", SmithingTrimMaterial.redstone.name());
    try std.testing.expectEqualStrings("Resin", SmithingTrimMaterial.resin.name());

    try std.testing.expectEqualStrings("Amethyst Shard", SmithingTrimMaterial.amethyst.ingredientItemName());
    try std.testing.expectEqualStrings("Resin Brick", SmithingTrimMaterial.resin.ingredientItemName());

    try std.testing.expectEqual(@as(u24, 0x64c8d8), SmithingTrimMaterial.diamond.colorHex());
    try std.testing.expectEqual(@as(u24, 0xe05e26), SmithingTrimMaterial.resin.colorHex());
}

test "SmithingTrimPattern enum completeness and host blocks" {
    const patterns = [_]SmithingTrimPattern{
        .silence,   .ward,      .spire,     .vex,
        .rib,       .snout,     .eye,       .tide,
        .flow,      .bolt,      .wayfinder, .raiser,
        .shaper,    .host,      .coast,     .dune,
        .sentry,    .wild,
    };
    try std.testing.expectEqual(@as(usize, 18), patterns.len);

    // Prompt highlighted patterns
    try std.testing.expectEqualStrings("Silence Armor Trim", SmithingTrimPattern.silence.name());
    try std.testing.expectEqualStrings("Cobbled Deepslate", SmithingTrimPattern.silence.hostBlockName());
    try std.testing.expectEqualStrings("Ancient City", SmithingTrimPattern.silence.structureOrigin());

    try std.testing.expectEqualStrings("Ward Armor Trim", SmithingTrimPattern.ward.name());
    try std.testing.expectEqualStrings("Spire Armor Trim", SmithingTrimPattern.spire.name());
    try std.testing.expectEqualStrings("Purpur Block", SmithingTrimPattern.spire.hostBlockName());

    try std.testing.expectEqualStrings("Vex Armor Trim", SmithingTrimPattern.vex.name());
    try std.testing.expectEqualStrings("Rib Armor Trim", SmithingTrimPattern.rib.name());
    try std.testing.expectEqualStrings("Netherrack", SmithingTrimPattern.rib.hostBlockName());

    try std.testing.expectEqualStrings("Snout Armor Trim", SmithingTrimPattern.snout.name());
    try std.testing.expectEqualStrings("Eye Armor Trim", SmithingTrimPattern.eye.name());
    try std.testing.expectEqualStrings("Tide Armor Trim", SmithingTrimPattern.tide.name());
    try std.testing.expectEqualStrings("Prismarine", SmithingTrimPattern.tide.hostBlockName());

    try std.testing.expectEqualStrings("Flow Armor Trim", SmithingTrimPattern.flow.name());
    try std.testing.expectEqualStrings("Breeze Rod", SmithingTrimPattern.flow.hostBlockName());
    try std.testing.expectEqualStrings("Bolt Armor Trim", SmithingTrimPattern.bolt.name());
    try std.testing.expectEqualStrings("Copper Block", SmithingTrimPattern.bolt.hostBlockName());

    try std.testing.expectEqualStrings("Wayfinder Armor Trim", SmithingTrimPattern.wayfinder.name());
    try std.testing.expectEqualStrings("Raiser Armor Trim", SmithingTrimPattern.raiser.name());
    try std.testing.expectEqualStrings("Shaper Armor Trim", SmithingTrimPattern.shaper.name());
    try std.testing.expectEqualStrings("Host Armor Trim", SmithingTrimPattern.host.name());
    try std.testing.expectEqualStrings("Terracotta", SmithingTrimPattern.host.hostBlockName());
}

test "duplicateSmithingTemplate valid recipe (1 template + 7 diamonds + host block -> 2 templates)" {
    const res = duplicateSmithingTemplate(true, 7, true);
    try std.testing.expectEqual(@as(u8, 2), res.templates_out);
    try std.testing.expectEqual(@as(u8, 7), res.diamonds_used);

    // Excess diamonds still uses 7 for 1 craft
    const res_excess = duplicateSmithingTemplate(true, 15, true);
    try std.testing.expectEqual(@as(u8, 2), res_excess.templates_out);
    try std.testing.expectEqual(@as(u8, 7), res_excess.diamonds_used);
}

test "duplicateSmithingTemplate insufficient diamonds (< 7)" {
    const res = duplicateSmithingTemplate(true, 6, true);
    try std.testing.expectEqual(@as(u8, 0), res.templates_out);
    try std.testing.expectEqual(@as(u8, 0), res.diamonds_used);

    const res0 = duplicateSmithingTemplate(true, 0, true);
    try std.testing.expectEqual(@as(u8, 0), res0.templates_out);
    try std.testing.expectEqual(@as(u8, 0), res0.diamonds_used);
}

test "duplicateSmithingTemplate missing host block or missing template" {
    // Missing host block
    const res_no_host = duplicateSmithingTemplate(true, 7, false);
    try std.testing.expectEqual(@as(u8, 0), res_no_host.templates_out);
    try std.testing.expectEqual(@as(u8, 0), res_no_host.diamonds_used);

    // Missing template
    const res_no_tpl = duplicateSmithingTemplate(false, 7, true);
    try std.testing.expectEqual(@as(u8, 0), res_no_tpl.templates_out);
    try std.testing.expectEqual(@as(u8, 0), res_no_tpl.diamonds_used);
}

test "batch template duplication multiple sets" {
    // 2 templates + 14 diamonds + 2 host blocks -> 4 templates, 14 diamonds
    const b2 = duplicateSmithingTemplateBatch(2, 14, 2);
    try std.testing.expectEqual(@as(u8, 4), b2.templates_out);
    try std.testing.expectEqual(@as(u8, 14), b2.diamonds_used);

    // Limited by host blocks
    const b_lim = duplicateSmithingTemplateBatch(5, 21, 1);
    try std.testing.expectEqual(@as(u8, 2), b_lim.templates_out);
    try std.testing.expectEqual(@as(u8, 7), b_lim.diamonds_used);
}

test "Netherite upgrade matrix verification" {
    try std.testing.expect(canNetheriteUpgrade(true, true, true));
    try std.testing.expect(!canNetheriteUpgrade(false, true, true));
    try std.testing.expect(!canNetheriteUpgrade(true, false, true));
    try std.testing.expect(!canNetheriteUpgrade(true, true, false));

    // Diamond pickaxe (max 1561) -> Netherite pickaxe (max 2031)
    // Fully intact: 1561 -> 2031
    const up_full = computeNetheriteUpgrade(.pickaxe, 1561, true, true);
    try std.testing.expect(up_full.success);
    try std.testing.expectEqual(@as(u16, 2031), up_full.new_durability);
    try std.testing.expectEqual(@as(u16, 2031), up_full.new_max_durability);

    // Worn pickaxe: 1561 - 500 damage taken = 1061 durability
    // Upgraded: 2031 - 500 = 1531 durability
    const up_worn = computeNetheriteUpgrade(.pickaxe, 1061, true, true);
    try std.testing.expect(up_worn.success);
    try std.testing.expectEqual(@as(u16, 1531), up_worn.new_durability);
    try std.testing.expectEqual(@as(u16, 2031), up_worn.new_max_durability);

    // Failed upgrade when missing ingot
    const up_fail = computeNetheriteUpgrade(.sword, 1000, true, false);
    try std.testing.expect(!up_fail.success);
    try std.testing.expectEqual(@as(u16, 1000), up_fail.new_durability);
}

test "Armor trim matrix application" {
    const trim_opt = applyArmorTrim(true, .silence, .chestplate, .amethyst, true);
    try std.testing.expect(trim_opt != null);
    const trim = trim_opt.?;
    try std.testing.expectEqual(ArmorSlot.chestplate, trim.slot);
    try std.testing.expectEqual(SmithingTrimPattern.silence, trim.pattern);
    try std.testing.expectEqual(SmithingTrimMaterial.amethyst, trim.material);

    // Missing template or material returns null
    try std.testing.expect(applyArmorTrim(false, .ward, .helmet, .diamond, true) == null);
    try std.testing.expect(applyArmorTrim(true, .ward, .helmet, .diamond, false) == null);
}
