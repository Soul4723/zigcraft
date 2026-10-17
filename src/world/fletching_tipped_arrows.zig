//! Milestone 396: Tipped Arrows Lingering-Potion 8x Crafting, 1/8th Effect Duration Scaling,
//! Spectral Arrow Glowing Outline & Fletching Villager Trades.
//!
//! Provides deterministic mechanics for:
//! 1. Tipped Arrow Crafting (8 regular arrows + 1 lingering potion = 8 tipped arrows)
//! 2. Tipped Arrow Duration Scaling (1/8th or 0.125 of drinkable potion duration)
//! 3. Undead mob damage / healing inversion rules for Arrow of Healing & Arrow of Harming
//! 4. Spectral Arrow Crafting (1 arrow + 4 glowstone dust = 2 spectral arrows) & Glowing outline
//! 5. Master-level Fletcher villager trading (2 emeralds + 5 arrows = 5 tipped arrows)

const std = @import("std");

// ============================================================================
// Item Tags & Identifiers
// ============================================================================

pub const ItemTag = struct {
    pub const SpectralArrow: u16 = 96;
    pub const Arrow: u16 = 97;
    pub const GlowstoneDust: u16 = 348;
    pub const Emerald: u16 = 388;
    pub const LingeringPotion: u16 = 441;
    pub const TippedArrow: u16 = 475;
};

pub const ItemKind = enum(u16) {
    none = 0,
    spectral_arrow = ItemTag.SpectralArrow,
    arrow = ItemTag.Arrow,
    glowstone_dust = ItemTag.GlowstoneDust,
    emerald = ItemTag.Emerald,
    lingering_potion = ItemTag.LingeringPotion,
    tipped_arrow = ItemTag.TippedArrow,
    _,
};

// ============================================================================
// Potion Effects & Tipped Arrows
// ============================================================================

pub const PotionEffect = enum(u8) {
    none = 0,
    night_vision = 1,
    invisibility = 2,
    leaping = 3,
    fire_resistance = 4,
    swiftness = 5,
    slowness = 6,
    water_breathing = 7,
    healing = 8,
    harming = 9,
    poison = 10,
    regeneration = 11,
    strength = 12,
    weakness = 13,
    slow_falling = 14,
    turtle_master = 15,
    wind_charged = 16,
    weaving = 17,
    oozing = 18,
    infested = 19,

    pub fn displayName(self: PotionEffect) []const u8 {
        return switch (self) {
            .none => "None",
            .night_vision => "Night Vision",
            .invisibility => "Invisibility",
            .leaping => "Leaping",
            .fire_resistance => "Fire Resistance",
            .swiftness => "Swiftness",
            .slowness => "Slowness",
            .water_breathing => "Water Breathing",
            .healing => "Healing",
            .harming => "Harming",
            .poison => "Poison",
            .regeneration => "Regeneration",
            .strength => "Strength",
            .weakness => "Weakness",
            .slow_falling => "Slow Falling",
            .turtle_master => "Turtle Master",
            .wind_charged => "Wind Charged",
            .weaving => "Weaving",
            .oozing => "Oozing",
            .infested => "Infested",
        };
    }

    pub fn isInstant(self: PotionEffect) bool {
        return self == .healing or self == .harming;
    }

    pub fn defaultDrinkableDuration(self: PotionEffect) f32 {
        return switch (self) {
            .healing, .harming => 0.0,
            .turtle_master => 20.0,
            .poison, .regeneration => 45.0,
            .slowness, .weakness, .slow_falling => 90.0,
            .night_vision,
            .invisibility,
            .leaping,
            .fire_resistance,
            .swiftness,
            .water_breathing,
            .strength,
            .wind_charged,
            .weaving,
            .oozing,
            .infested,
            => 180.0,
            .none => 0.0,
        };
    }
};

pub const HarmingOrHealing = enum {
    healing,
    harming,
};

pub const TippedArrow = struct {
    effect: PotionEffect = .none,
    count: u8 = 8,
    duration_seconds: f32 = 0.0,
    level: u8 = 1,
};

// ============================================================================
// 1. Tipped Arrow Crafting (8 Arrows + 1 Lingering Potion = 8 Tipped Arrows)
// ============================================================================

pub const TippedArrowCraftResult = struct {
    crafted_count: u8,
    arrows_consumed: u8,
    potions_consumed: u8,
    remaining_arrows: u8,
    remaining_potions: u8,
    arrow: ?TippedArrow = null,
};

pub const TippedArrowCrafting = struct {
    pub const arrows_per_batch: u8 = 8;
    pub const lingering_potions_per_batch: u8 = 1;
    pub const output_arrows_per_batch: u8 = 8;

    pub fn craft(arrows: u8, lingering_potions: u8) u8 {
        return craftTippedArrows(arrows, lingering_potions);
    }

    pub fn canCraft(arrows: u8, lingering_potions: u8) bool {
        return arrows >= arrows_per_batch and lingering_potions >= lingering_potions_per_batch;
    }

    pub fn craftDetailed(arrows: u8, lingering_potions: u8, effect: PotionEffect) TippedArrowCraftResult {
        const count = craftTippedArrows(arrows, lingering_potions);
        const batches = count / output_arrows_per_batch;
        const arrows_used = batches * arrows_per_batch;
        const potions_used = batches * lingering_potions_per_batch;
        return .{
            .crafted_count = count,
            .arrows_consumed = arrows_used,
            .potions_consumed = potions_used,
            .remaining_arrows = arrows - arrows_used,
            .remaining_potions = lingering_potions - potions_used,
            .arrow = if (count > 0) .{
                .effect = effect,
                .count = count,
                .duration_seconds = tippedArrowDurationSeconds(effect.defaultDrinkableDuration()),
                .level = 1,
            } else null,
        };
    }

    /// Checks if a 3x3 crafting grid matches the Tipped Arrow recipe:
    /// Center slot 4 is 1 lingering potion, surrounded by 8 arrows (slots 0,1,2,3,5,6,7,8).
    pub fn matchesGrid(grid: [9]?ItemKind) bool {
        const center = grid[4] orelse return false;
        if (center != .lingering_potion) return false;

        const surrounding = [_]usize{ 0, 1, 2, 3, 5, 6, 7, 8 };
        for (surrounding) |idx| {
            const item = grid[idx] orelse return false;
            if (item != .arrow) return false;
        }
        return true;
    }
};

/// Surrounding 1 lingering_potion with 8 regular arrows crafts 8 matching TippedArrows.
pub fn craftTippedArrows(arrows: u8, lingering_potions: u8) u8 {
    const batches = @min(arrows / 8, lingering_potions);
    return batches * 8;
}

// ============================================================================
// 2. Tipped Arrow Duration Scaling (1/8th or 0.125 Scaling)
// ============================================================================

pub const tipped_arrow_duration_multiplier: f32 = 0.125;

pub const TippedArrowDurationScale = struct {
    pub const scale: f32 = 0.125;
    pub const divisor: f32 = 8.0;

    pub fn scaleDuration(drinkable_duration_seconds: f32) f32 {
        return tippedArrowDurationSeconds(drinkable_duration_seconds);
    }

    pub fn scaleTicks(drinkable_ticks: u32) u32 {
        return drinkable_ticks / 8;
    }
};

/// Scales the drinkable potion duration to 1/8th (0.125) for a Tipped Arrow.
/// Examples:
///   180.0s -> 22.5s
///   480.0s -> 60.0s
///    90.0s -> 11.25s
pub fn tippedArrowDurationSeconds(drinkable_duration_seconds: f32) f32 {
    if (drinkable_duration_seconds <= 0.0) return 0.0;
    return drinkable_duration_seconds * 0.125;
}

/// Helper for tick-based duration scaling (20 ticks = 1 second).
pub fn tippedArrowDurationTicks(drinkable_ticks: u32) u32 {
    return drinkable_ticks / 8;
}

// ============================================================================
// 3. Undead Mobs & Arrow of Healing / Harming Inversion Rules
// ============================================================================

pub const MobType = enum {
    player,
    zombie,
    skeleton,
    wither_skeleton,
    stray,
    drowned,
    husk,
    phantom,
    wither,
    zombified_piglin,
    zombie_villager,
    zoglin,
    skeleton_horse,
    zombie_horse,
    villager,
    cow,
    sheep,
    pig,
    chicken,
    iron_golem,
    snow_golem,
    creeper,
    spider,
    cave_spider,
    enderman,
    witch,
    slime,
    magma_cube,
    blaze,
    ghast,
    allay,
    armadillo,
    wolf,
    cat,
    other,
};

/// Returns true if the entity is an undead mob:
/// Canonical undead: zombie, skeleton, wither_skeleton, stray, drowned, husk, phantom, wither.
pub fn isUndead(target: anytype) bool {
    const T = @TypeOf(target);
    if (T == bool) return target;
    return switch (target) {
        .zombie,
        .skeleton,
        .wither_skeleton,
        .stray,
        .drowned,
        .husk,
        .phantom,
        .wither,
        .zombified_piglin,
        .zombie_villager,
        .zoglin,
        .skeleton_horse,
        .zombie_horse,
        => true,
        else => false,
    };
}

pub fn isHarmingEffect(effect: anytype) bool {
    const T = @TypeOf(effect);
    if (T == bool) return effect;
    const tag = @tagName(effect);
    if (std.mem.eql(u8, tag, "harming") or std.mem.eql(u8, tag, "instant_damage")) {
        return true;
    }
    return false;
}

pub const HarmingHealingResult = struct {
    damage: f32 = 0.0,
    healing: f32 = 0.0,
    is_magic_damage: bool = false,
    ignores_armor: bool = false,
    target_is_undead: bool = false,

    pub fn netHpDelta(self: HarmingHealingResult) f32 {
        return self.healing - self.damage;
    }

    pub fn netDamage(self: HarmingHealingResult) f32 {
        return self.damage;
    }
};

pub const TippedArrowUndeadRule = struct {
    pub const harming_tier_1_damage: f32 = 6.0;
    pub const harming_tier_2_damage: f32 = 12.0;
    pub const healing_tier_1_undead_damage: f32 = 6.0;
    pub const healing_tier_2_undead_damage: f32 = 12.0;
    pub const healing_tier_1_living_heal: f32 = 6.0;
    pub const healing_tier_2_living_heal: f32 = 12.0;
    pub const harming_tier_1_undead_heal: f32 = 6.0;
    pub const harming_tier_2_undead_heal: f32 = 12.0;

    pub const isUndeadMob = isUndead;
    pub const resolve = resolveArrowOfHarmingOrHealing;
};

/// Resolves the effect of Arrow of Harming or Arrow of Healing on a target.
/// - Arrow of Healing deals extra armor-ignoring magic damage (6.0 / 12.0 HP) to undead mobs while healing living mobs.
/// - Arrow of Harming heals undead mobs while dealing armor-ignoring magic damage (6.0 / 12.0 HP) to living players/mobs.
/// Supports both boolean and enum types for effect and target.
pub fn resolveArrowOfHarmingOrHealing(arg1: anytype, arg2: anytype, level: u8) HarmingHealingResult {
    const T1 = @TypeOf(arg1);
    const T2 = @TypeOf(arg2);

    var harming: bool = false;
    var undead: bool = false;

    if (T1 == MobType) {
        undead = isUndead(arg1);
        harming = isHarmingEffect(arg2);
    } else if (T2 == MobType) {
        undead = isUndead(arg2);
        harming = isHarmingEffect(arg1);
    } else if (T1 == PotionEffect or T1 == HarmingOrHealing) {
        harming = isHarmingEffect(arg1);
        undead = isUndead(arg2);
    } else if (T2 == PotionEffect or T2 == HarmingOrHealing) {
        harming = isHarmingEffect(arg2);
        undead = isUndead(arg1);
    } else if (T1 == bool and T2 == bool) {
        harming = arg1;
        undead = arg2;
    } else {
        harming = isHarmingEffect(arg1);
        undead = isUndead(arg2);
    }

    const effective_level: u8 = if (level <= 1) 1 else level;
    const power: f32 = @as(f32, @floatFromInt(effective_level)) * 6.0;

    if (harming) {
        if (undead) {
            // Arrow of Harming heals undead mobs
            return .{
                .damage = 0.0,
                .healing = power,
                .is_magic_damage = false,
                .ignores_armor = false,
                .target_is_undead = true,
            };
        } else {
            // Arrow of Harming deals armor-ignoring magic damage (6.0 / 12.0 HP) to living
            return .{
                .damage = power,
                .healing = 0.0,
                .is_magic_damage = true,
                .ignores_armor = true,
                .target_is_undead = false,
            };
        }
    } else {
        if (undead) {
            // Arrow of Healing deals extra magic damage to undead mobs (armor-ignoring)
            return .{
                .damage = power,
                .healing = 0.0,
                .is_magic_damage = true,
                .ignores_armor = true,
                .target_is_undead = true,
            };
        } else {
            // Arrow of Healing heals living mobs/players
            return .{
                .damage = 0.0,
                .healing = power,
                .is_magic_damage = false,
                .ignores_armor = false,
                .target_is_undead = false,
            };
        }
    }
}

// ============================================================================
// 4. Spectral Arrow Crafting & Glowing Outline
// ============================================================================

pub const glowing_duration_seconds: f32 = 10.0;
pub const glowing_duration_ticks: u32 = 200;
pub const spectral_arrow_glows_through_walls: bool = true;

pub const GlowingStatusEffect = struct {
    duration_seconds: f32 = glowing_duration_seconds,
    duration_ticks: u32 = glowing_duration_ticks,
    visible_through_walls: bool = true,
    visible_through_solid_walls: bool = true,

    pub fn init() GlowingStatusEffect {
        return .{};
    }

    pub fn tick(self: *GlowingStatusEffect, dt: f32) void {
        if (dt <= 0.0) return;
        self.duration_seconds = @max(0.0, self.duration_seconds - dt);
        const ticks_f = self.duration_seconds * 20.0;
        self.duration_ticks = @intFromFloat(@max(0.0, @ceil(ticks_f)));
    }

    pub fn tickTicks(self: *GlowingStatusEffect, ticks: u32) void {
        if (ticks >= self.duration_ticks) {
            self.duration_ticks = 0;
            self.duration_seconds = 0.0;
        } else {
            self.duration_ticks -= ticks;
            self.duration_seconds = @as(f32, @floatFromInt(self.duration_ticks)) / 20.0;
        }
    }

    pub fn isActive(self: GlowingStatusEffect) bool {
        return self.duration_seconds > 0.0;
    }
};

pub const SpectralArrowCraftResult = struct {
    spectral_arrows_crafted: u8,
    arrows_consumed: u8,
    glowstone_dust_consumed: u8,
    remaining_arrows: u8,
    remaining_glowstone_dust: u8,
};

pub const SpectralArrowCrafting = struct {
    pub const required_arrows: u8 = 1;
    pub const required_glowstone_dust: u8 = 4;
    pub const output_spectral_arrows: u8 = 2;

    pub fn craft(arrows: u8, glowstone_dust: u8) u8 {
        return craftSpectralArrows(arrows, glowstone_dust);
    }

    pub fn canCraft(arrows: u8, glowstone_dust: u8) bool {
        return arrows >= required_arrows and glowstone_dust >= required_glowstone_dust;
    }

    pub fn craftDetailed(arrows: u8, glowstone_dust: u8) SpectralArrowCraftResult {
        const count = craftSpectralArrows(arrows, glowstone_dust);
        const batches = count / output_spectral_arrows;
        const arrows_used = batches * required_arrows;
        const dust_used = batches * required_glowstone_dust;
        return .{
            .spectral_arrows_crafted = count,
            .arrows_consumed = arrows_used,
            .glowstone_dust_consumed = dust_used,
            .remaining_arrows = arrows - arrows_used,
            .remaining_glowstone_dust = glowstone_dust - dust_used,
        };
    }

    /// 3x3 crafting grid: center (slot 4) arrow, cardinal slots (1, 3, 5, 7) glowstone dust,
    /// corners (0, 2, 6, 8) empty.
    pub fn matchesGrid(grid: [9]?ItemKind) bool {
        const center = grid[4] orelse return false;
        if (center != .arrow) return false;

        const cardinals = [_]usize{ 1, 3, 5, 7 };
        for (cardinals) |idx| {
            const item = grid[idx] orelse return false;
            if (item != .glowstone_dust) return false;
        }

        const corners = [_]usize{ 0, 2, 6, 8 };
        for (corners) |idx| {
            if (grid[idx] != null and grid[idx] != .none) return false;
        }
        return true;
    }
};

/// 1 arrow + 4 glowstone_dust crafts 2 spectral_arrows.
pub fn craftSpectralArrows(arrows: u8, glowstone_dust: u8) u8 {
    const batches = @min(arrows, glowstone_dust / 4);
    return batches * 2;
}

/// Applies the Glowing status effect for 10.0 seconds (200 ticks) upon arrow impact.
pub fn applySpectralArrowHit() GlowingStatusEffect {
    return GlowingStatusEffect.init();
}

// ============================================================================
// 5. Master-Level Fletcher Villager Trades
// ============================================================================

pub const FletcherTradeResult = struct {
    count: u8,
    effect: PotionEffect,
    emeralds_spent: u8,
    arrows_spent: u8,
    remaining_emeralds: u8,
    remaining_arrows: u8,
};

pub const FletcherMasterTrade = struct {
    pub const emerald_cost: u8 = 2;
    pub const arrow_cost: u8 = 5;
    pub const output_arrows: u8 = 5;

    pub const available_effects = [_]PotionEffect{
        .night_vision,
        .invisibility,
        .leaping,
        .fire_resistance,
        .swiftness,
        .slowness,
        .water_breathing,
        .healing,
        .harming,
        .poison,
        .regeneration,
        .strength,
        .weakness,
        .slow_falling,
        .turtle_master,
    };

    pub fn canTrade(emeralds: u8, arrows: u8) bool {
        return emeralds >= emerald_cost and arrows >= arrow_cost;
    }

    pub fn trade(emeralds: u8, arrows: u8) u8 {
        return tradeMasterFletcherTippedArrows(emeralds, arrows);
    }

    pub fn tradeDetailed(emeralds: u8, arrows: u8, effect: PotionEffect) ?FletcherTradeResult {
        return tradeMasterFletcherTippedArrowsWithEffect(emeralds, arrows, effect);
    }

    pub fn randomEffect(roll: u8) PotionEffect {
        return available_effects[roll % available_effects.len];
    }
};

/// Master-level Fletcher villager trades 2 Emeralds + 5 Arrows -> 5 Tipped Arrows of any effect.
pub fn tradeMasterFletcherTippedArrows(emeralds: u8, arrows: u8) u8 {
    const trades = @min(emeralds / FletcherMasterTrade.emerald_cost, arrows / FletcherMasterTrade.arrow_cost);
    return trades * FletcherMasterTrade.output_arrows;
}

/// Detailed trade function that tracks remaining resources and specifies the potion effect.
pub fn tradeMasterFletcherTippedArrowsWithEffect(emeralds: u8, arrows: u8, effect: PotionEffect) ?FletcherTradeResult {
    if (!FletcherMasterTrade.canTrade(emeralds, arrows)) return null;
    const trades = @min(emeralds / FletcherMasterTrade.emerald_cost, arrows / FletcherMasterTrade.arrow_cost);
    const emeralds_spent = trades * FletcherMasterTrade.emerald_cost;
    const arrows_spent = trades * FletcherMasterTrade.arrow_cost;
    return .{
        .count = trades * FletcherMasterTrade.output_arrows,
        .effect = effect,
        .emeralds_spent = emeralds_spent,
        .arrows_spent = arrows_spent,
        .remaining_emeralds = emeralds - emeralds_spent,
        .remaining_arrows = arrows - arrows_spent,
    };
}

// ============================================================================
// Infinity Enchantment Exclusion Helper
// ============================================================================

/// In Minecraft, bows enchanted with Infinity do NOT duplicate tipped or spectral arrows.
/// Regular untipped arrows are not consumed (returns false), while tipped or spectral arrows
/// are always consumed (returns true).
pub fn resolveBowInfinityArrowConsumption(has_infinity: bool, is_tipped: bool, is_spectral: bool) bool {
    if (is_tipped or is_spectral) return true;
    if (has_infinity) return false;
    return true;
}

// ============================================================================
// Unit Tests (At least 12 comprehensive tests required)
// ============================================================================

test "1. TippedArrowCrafting 8 arrows and 1 lingering potion produces 8 tipped arrows" {
    const count = craftTippedArrows(8, 1);
    try std.testing.expectEqual(@as(u8, 8), count);

    const detailed = TippedArrowCrafting.craftDetailed(8, 1, .slowness);
    try std.testing.expectEqual(@as(u8, 8), detailed.crafted_count);
    try std.testing.expectEqual(@as(u8, 8), detailed.arrows_consumed);
    try std.testing.expectEqual(@as(u8, 1), detailed.potions_consumed);
    try std.testing.expectEqual(@as(u8, 0), detailed.remaining_arrows);
    try std.testing.expectEqual(@as(u8, 0), detailed.remaining_potions);
    try std.testing.expect(detailed.arrow != null);
    try std.testing.expectEqual(PotionEffect.slowness, detailed.arrow.?.effect);
    try std.testing.expectEqual(@as(u8, 8), detailed.arrow.?.count);
}

test "2. TippedArrowCrafting insufficient arrows or lingering potions yields zero" {
    try std.testing.expectEqual(@as(u8, 0), craftTippedArrows(7, 1));
    try std.testing.expectEqual(@as(u8, 0), craftTippedArrows(8, 0));
    try std.testing.expectEqual(@as(u8, 0), craftTippedArrows(0, 0));
    try std.testing.expectEqual(@as(u8, 0), craftTippedArrows(1, 5));
    try std.testing.expect(!TippedArrowCrafting.canCraft(7, 1));
    try std.testing.expect(!TippedArrowCrafting.canCraft(8, 0));
    try std.testing.expect(TippedArrowCrafting.canCraft(8, 1));
}

test "3. TippedArrowCrafting batch scaling and remainder calculation" {
    // 16 arrows + 2 potions = 16 tipped arrows
    try std.testing.expectEqual(@as(u8, 16), craftTippedArrows(16, 2));

    // 24 arrows + 3 potions = 24 tipped arrows
    try std.testing.expectEqual(@as(u8, 24), craftTippedArrows(24, 3));

    // 20 arrows + 2 potions = 16 tipped arrows (4 leftover arrows)
    const d = TippedArrowCrafting.craftDetailed(20, 2, .poison);
    try std.testing.expectEqual(@as(u8, 16), d.crafted_count);
    try std.testing.expectEqual(@as(u8, 16), d.arrows_consumed);
    try std.testing.expectEqual(@as(u8, 2), d.potions_consumed);
    try std.testing.expectEqual(@as(u8, 4), d.remaining_arrows);
    try std.testing.expectEqual(@as(u8, 0), d.remaining_potions);

    // 64 arrows + 1 potion = 8 tipped arrows (56 leftover arrows)
    const d2 = TippedArrowCrafting.craftDetailed(64, 1, .regeneration);
    try std.testing.expectEqual(@as(u8, 8), d2.crafted_count);
    try std.testing.expectEqual(@as(u8, 56), d2.remaining_arrows);
}

test "4. TippedArrowCrafting 3x3 crafting grid layout verification" {
    var valid_grid: [9]?ItemKind = [_]?ItemKind{.arrow} ** 9;
    valid_grid[4] = .lingering_potion; // center is lingering potion
    try std.testing.expect(TippedArrowCrafting.matchesGrid(valid_grid));

    // Invalid: center is regular arrow
    const invalid_grid: [9]?ItemKind = [_]?ItemKind{.arrow} ** 9;
    try std.testing.expect(!TippedArrowCrafting.matchesGrid(invalid_grid));

    // Invalid: one surrounding arrow missing
    var missing_arrow = valid_grid;
    missing_arrow[0] = null;
    try std.testing.expect(!TippedArrowCrafting.matchesGrid(missing_arrow));

    // Invalid: surrounding item is something else
    var wrong_item = valid_grid;
    wrong_item[7] = .glowstone_dust;
    try std.testing.expect(!TippedArrowCrafting.matchesGrid(wrong_item));
}

test "5. TippedArrowDurationScale 1/8th scaling for standard drinkable durations" {
    // 180.0s drinkable (3:00 min) -> 22.5s tipped arrow
    const scaled_180 = tippedArrowDurationSeconds(180.0);
    try std.testing.expectApproxEqAbs(@as(f32, 22.5), scaled_180, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 22.5), TippedArrowDurationScale.scaleDuration(180.0), 0.0001);

    // 480.0s drinkable (8:00 min extended) -> 60.0s tipped arrow
    const scaled_480 = tippedArrowDurationSeconds(480.0);
    try std.testing.expectApproxEqAbs(@as(f32, 60.0), scaled_480, 0.0001);

    // 90.0s drinkable (1:30 min tier II / base) -> 11.25s tipped arrow
    const scaled_90 = tippedArrowDurationSeconds(90.0);
    try std.testing.expectApproxEqAbs(@as(f32, 11.25), scaled_90, 0.0001);
}

test "6. TippedArrowDurationScale other durations (20s Turtle Master, 45s Poison)" {
    // Turtle master 20.0s -> 2.5s
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), tippedArrowDurationSeconds(20.0), 0.0001);

    // Poison / Regen 45.0s -> 5.625s
    try std.testing.expectApproxEqAbs(@as(f32, 5.625), tippedArrowDurationSeconds(45.0), 0.0001);

    // Multiplier constant is exactly 0.125
    try std.testing.expectEqual(@as(f32, 0.125), tipped_arrow_duration_multiplier);
    try std.testing.expectEqual(@as(f32, 0.125), TippedArrowDurationScale.scale);
}

test "7. TippedArrowDurationScale instant and zero or negative duration edge cases" {
    // Instant potions (healing/harming) have duration 0.0s
    try std.testing.expectEqual(@as(f32, 0.0), tippedArrowDurationSeconds(0.0));
    try std.testing.expectEqual(@as(f32, 0.0), tippedArrowDurationSeconds(-10.0));
    try std.testing.expect(PotionEffect.healing.isInstant());
    try std.testing.expect(PotionEffect.harming.isInstant());
    try std.testing.expect(!PotionEffect.slowness.isInstant());
}

test "8. TippedArrowDurationScale tick division and precision" {
    // 3600 ticks (180s) / 8 = 450 ticks (22.5s)
    try std.testing.expectEqual(@as(u32, 450), tippedArrowDurationTicks(3600));
    try std.testing.expectEqual(@as(u32, 450), TippedArrowDurationScale.scaleTicks(3600));

    // 9600 ticks (480s) / 8 = 1200 ticks (60.0s)
    try std.testing.expectEqual(@as(u32, 1200), tippedArrowDurationTicks(9600));

    // 1800 ticks (90s) / 8 = 225 ticks (11.25s)
    try std.testing.expectEqual(@as(u32, 225), tippedArrowDurationTicks(1800));
}

test "9. TippedArrowUndeadRule classifies all eight canonical undead mobs and non-undead mobs" {
    // All 8 undead mobs from requirement:
    // zombie, skeleton, wither_skeleton, stray, drowned, husk, phantom, wither
    try std.testing.expect(isUndead(MobType.zombie));
    try std.testing.expect(isUndead(MobType.skeleton));
    try std.testing.expect(isUndead(MobType.wither_skeleton));
    try std.testing.expect(isUndead(MobType.stray));
    try std.testing.expect(isUndead(MobType.drowned));
    try std.testing.expect(isUndead(MobType.husk));
    try std.testing.expect(isUndead(MobType.phantom));
    try std.testing.expect(isUndead(MobType.wither));

    // Undead variants
    try std.testing.expect(isUndead(MobType.zombified_piglin));
    try std.testing.expect(isUndead(MobType.zombie_villager));
    try std.testing.expect(isUndead(MobType.skeleton_horse));

    // Living entities must return false
    try std.testing.expect(!isUndead(MobType.player));
    try std.testing.expect(!isUndead(MobType.villager));
    try std.testing.expect(!isUndead(MobType.cow));
    try std.testing.expect(!isUndead(MobType.iron_golem));
    try std.testing.expect(!isUndead(MobType.creeper));
    try std.testing.expect(!isUndead(MobType.spider));
    try std.testing.expect(!isUndead(MobType.enderman));
    try std.testing.expect(!isUndead(MobType.blaze));
}

test "10. TippedArrowUndeadRule Arrow of Healing deals 6.0 and 12.0 magic damage ignoring armor to undead" {
    // Healing Level 1 vs Zombie (undead) -> 6.0 magic damage
    const res1 = resolveArrowOfHarmingOrHealing(PotionEffect.healing, MobType.zombie, 1);
    try std.testing.expectEqual(@as(f32, 6.0), res1.damage);
    try std.testing.expectEqual(@as(f32, 0.0), res1.healing);
    try std.testing.expect(res1.is_magic_damage);
    try std.testing.expect(res1.ignores_armor);
    try std.testing.expect(res1.target_is_undead);

    // Healing Level 2 vs Wither (undead) -> 12.0 magic damage
    const res2 = resolveArrowOfHarmingOrHealing(PotionEffect.healing, MobType.wither, 2);
    try std.testing.expectEqual(@as(f32, 12.0), res2.damage);
    try std.testing.expectEqual(@as(f32, 0.0), res2.healing);
    try std.testing.expect(res2.is_magic_damage);
    try std.testing.expect(res2.ignores_armor);

    // Using boolean args: is_harming = false, is_undead = true
    const res_bool = resolveArrowOfHarmingOrHealing(false, true, 1);
    try std.testing.expectEqual(@as(f32, 6.0), res_bool.damage);
    try std.testing.expect(res_bool.is_magic_damage);
}

test "11. TippedArrowUndeadRule Arrow of Healing heals living players and mobs" {
    // Healing Level 1 vs Player (living) -> 6.0 healing, 0 damage
    const res_player = resolveArrowOfHarmingOrHealing(PotionEffect.healing, MobType.player, 1);
    try std.testing.expectEqual(@as(f32, 0.0), res_player.damage);
    try std.testing.expectEqual(@as(f32, 6.0), res_player.healing);
    try std.testing.expect(!res_player.is_magic_damage);
    try std.testing.expect(!res_player.ignores_armor);
    try std.testing.expect(!res_player.target_is_undead);
    try std.testing.expectEqual(@as(f32, 6.0), res_player.netHpDelta());

    // Healing Level 2 vs Villager (living) -> 12.0 healing
    const res_villager = resolveArrowOfHarmingOrHealing(PotionEffect.healing, MobType.villager, 2);
    try std.testing.expectEqual(@as(f32, 0.0), res_villager.damage);
    try std.testing.expectEqual(@as(f32, 12.0), res_villager.healing);
}

test "12. TippedArrowUndeadRule Arrow of Harming heals undead mobs 6.0 and 12.0 HP" {
    // Harming Level 1 vs Skeleton (undead) -> 6.0 healing, 0 damage
    const res1 = resolveArrowOfHarmingOrHealing(PotionEffect.harming, MobType.skeleton, 1);
    try std.testing.expectEqual(@as(f32, 0.0), res1.damage);
    try std.testing.expectEqual(@as(f32, 6.0), res1.healing);
    try std.testing.expect(!res1.is_magic_damage);
    try std.testing.expect(!res1.ignores_armor);
    try std.testing.expect(res1.target_is_undead);
    try std.testing.expectEqual(@as(f32, 6.0), res1.netHpDelta());

    // Harming Level 2 vs Drowned (undead) -> 12.0 healing
    const res2 = resolveArrowOfHarmingOrHealing(PotionEffect.harming, MobType.drowned, 2);
    try std.testing.expectEqual(@as(f32, 0.0), res2.damage);
    try std.testing.expectEqual(@as(f32, 12.0), res2.healing);
}

test "13. TippedArrowUndeadRule Arrow of Harming deals 6.0 and 12.0 armor-ignoring magic damage to living players and mobs" {
    // Harming Level 1 vs Player (living) -> 6.0 armor-ignoring magic damage
    const res1 = resolveArrowOfHarmingOrHealing(PotionEffect.harming, MobType.player, 1);
    try std.testing.expectEqual(@as(f32, 6.0), res1.damage);
    try std.testing.expectEqual(@as(f32, 0.0), res1.healing);
    try std.testing.expect(res1.is_magic_damage);
    try std.testing.expect(res1.ignores_armor);
    try std.testing.expect(!res1.target_is_undead);
    try std.testing.expectEqual(@as(f32, -6.0), res1.netHpDelta());

    // Harming Level 2 vs Cow (living) -> 12.0 armor-ignoring magic damage
    const res2 = resolveArrowOfHarmingOrHealing(PotionEffect.harming, MobType.cow, 2);
    try std.testing.expectEqual(@as(f32, 12.0), res2.damage);
    try std.testing.expectEqual(@as(f32, 0.0), res2.healing);
    try std.testing.expect(res2.is_magic_damage);
    try std.testing.expect(res2.ignores_armor);

    // Using boolean args: is_harming = true, is_undead = false
    const res_bool = resolveArrowOfHarmingOrHealing(true, false, 2);
    try std.testing.expectEqual(@as(f32, 12.0), res_bool.damage);
    try std.testing.expect(res_bool.ignores_armor);
}

test "14. SpectralArrowCrafting 1 arrow and 4 glowstone dust yields 2 spectral arrows" {
    const output = craftSpectralArrows(1, 4);
    try std.testing.expectEqual(@as(u8, 2), output);

    const detailed = SpectralArrowCrafting.craftDetailed(1, 4);
    try std.testing.expectEqual(@as(u8, 2), detailed.spectral_arrows_crafted);
    try std.testing.expectEqual(@as(u8, 1), detailed.arrows_consumed);
    try std.testing.expectEqual(@as(u8, 4), detailed.glowstone_dust_consumed);
    try std.testing.expectEqual(@as(u8, 0), detailed.remaining_arrows);
    try std.testing.expectEqual(@as(u8, 0), detailed.remaining_glowstone_dust);
}

test "15. SpectralArrowCrafting batch scaling, insufficient materials, and 3x3 grid" {
    // 2 arrows + 8 glowstone dust = 4 spectral arrows
    try std.testing.expectEqual(@as(u8, 4), craftSpectralArrows(2, 8));

    // 5 arrows + 20 dust = 10 spectral arrows
    try std.testing.expectEqual(@as(u8, 10), craftSpectralArrows(5, 20));

    // Insufficient
    try std.testing.expectEqual(@as(u8, 0), craftSpectralArrows(0, 4));
    try std.testing.expectEqual(@as(u8, 0), craftSpectralArrows(1, 3));
    try std.testing.expect(!SpectralArrowCrafting.canCraft(1, 3));
    try std.testing.expect(SpectralArrowCrafting.canCraft(1, 4));

    // Remainder calculation: 3 arrows + 9 dust -> 2 batches (4 spectral arrows, 1 arrow and 1 dust left)
    const d = SpectralArrowCrafting.craftDetailed(3, 9);
    try std.testing.expectEqual(@as(u8, 4), d.spectral_arrows_crafted);
    try std.testing.expectEqual(@as(u8, 1), d.remaining_arrows);
    try std.testing.expectEqual(@as(u8, 1), d.remaining_glowstone_dust);

    // Grid match: center arrow, cardinals dust
    var grid: [9]?ItemKind = [_]?ItemKind{null} ** 9;
    grid[4] = .arrow;
    grid[1] = .glowstone_dust;
    grid[3] = .glowstone_dust;
    grid[5] = .glowstone_dust;
    grid[7] = .glowstone_dust;
    try std.testing.expect(SpectralArrowCrafting.matchesGrid(grid));

    grid[0] = .arrow; // extra corner invalidates
    try std.testing.expect(!SpectralArrowCrafting.matchesGrid(grid));
}

test "16. SpectralArrow glowing outline effect duration 10s 200 ticks visible through walls and ticks down" {
    var glow = applySpectralArrowHit();
    try std.testing.expectEqual(@as(f32, 10.0), glowing_duration_seconds);
    try std.testing.expectEqual(@as(u32, 200), glowing_duration_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), glow.duration_seconds, 0.0001);
    try std.testing.expectEqual(@as(u32, 200), glow.duration_ticks);
    try std.testing.expect(glow.visible_through_walls);
    try std.testing.expect(glow.visible_through_solid_walls);
    try std.testing.expect(glow.isActive());

    // Tick by 3.5 seconds -> 6.5s remaining, 130 ticks
    glow.tick(3.5);
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), glow.duration_seconds, 0.0001);
    try std.testing.expectEqual(@as(u32, 130), glow.duration_ticks);
    try std.testing.expect(glow.isActive());

    // Tick past expiration
    glow.tick(10.0);
    try std.testing.expectEqual(@as(f32, 0.0), glow.duration_seconds);
    try std.testing.expectEqual(@as(u32, 0), glow.duration_ticks);
    try std.testing.expect(!glow.isActive());

    // Ticking via tickTicks
    var glow2 = GlowingStatusEffect.init();
    glow2.tickTicks(50);
    try std.testing.expectEqual(@as(u32, 150), glow2.duration_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), glow2.duration_seconds, 0.0001);
}

test "17. FletcherMasterTrade trades 2 emeralds and 5 arrows for 5 tipped arrows" {
    // 2 Emeralds + 5 Arrows -> 5 Tipped Arrows
    const traded = tradeMasterFletcherTippedArrows(2, 5);
    try std.testing.expectEqual(@as(u8, 5), traded);

    // Constants check
    try std.testing.expectEqual(@as(u8, 2), FletcherMasterTrade.emerald_cost);
    try std.testing.expectEqual(@as(u8, 5), FletcherMasterTrade.arrow_cost);
    try std.testing.expectEqual(@as(u8, 5), FletcherMasterTrade.output_arrows);
}

test "18. FletcherMasterTrade rejects insufficient emeralds or arrows and handles multi-batch trades with effects" {
    // Insufficient emeralds (1 < 2)
    try std.testing.expectEqual(@as(u8, 0), tradeMasterFletcherTippedArrows(1, 5));
    try std.testing.expect(!FletcherMasterTrade.canTrade(1, 5));

    // Insufficient arrows (4 < 5)
    try std.testing.expectEqual(@as(u8, 0), tradeMasterFletcherTippedArrows(2, 4));
    try std.testing.expect(!FletcherMasterTrade.canTrade(2, 4));

    // Multi-batch: 4 emeralds + 10 arrows -> 10 tipped arrows
    try std.testing.expectEqual(@as(u8, 10), tradeMasterFletcherTippedArrows(4, 10));

    // Trade with specific effect (e.g. Slowness)
    const detail = tradeMasterFletcherTippedArrowsWithEffect(6, 17, .slowness);
    try std.testing.expect(detail != null);
    try std.testing.expectEqual(@as(u8, 15), detail.?.count);
    try std.testing.expectEqual(PotionEffect.slowness, detail.?.effect);
    try std.testing.expectEqual(@as(u8, 6), detail.?.emeralds_spent);
    try std.testing.expectEqual(@as(u8, 15), detail.?.arrows_spent);
    try std.testing.expectEqual(@as(u8, 0), detail.?.remaining_emeralds);
    try std.testing.expectEqual(@as(u8, 2), detail.?.remaining_arrows);

    // Random trade effect selection
    const effect0 = FletcherMasterTrade.randomEffect(0);
    try std.testing.expectEqual(PotionEffect.night_vision, effect0);
}

test "19. Infinity enchantment consumes tipped and spectral arrows but preserves regular arrows" {
    // Regular arrow with Infinity -> NOT consumed (returns false)
    try std.testing.expect(!resolveBowInfinityArrowConsumption(true, false, false));

    // Regular arrow without Infinity -> consumed (returns true)
    try std.testing.expect(resolveBowInfinityArrowConsumption(false, false, false));

    // Tipped arrow with Infinity -> consumed (returns true)
    try std.testing.expect(resolveBowInfinityArrowConsumption(true, true, false));

    // Spectral arrow with Infinity -> consumed (returns true)
    try std.testing.expect(resolveBowInfinityArrowConsumption(true, false, true));

    // Tipped arrow without Infinity -> consumed (returns true)
    try std.testing.expect(resolveBowInfinityArrowConsumption(false, true, false));
}
