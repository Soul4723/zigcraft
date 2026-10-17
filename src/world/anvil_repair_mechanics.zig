const std = @import("std");

/// The anvil recipe consumes three iron blocks (27 ingots) and four loose
/// ingots, for 31 ingots of iron per anvil.
pub const AnvilRecipe = struct {
    pub const iron_blocks_required: u8 = 3;
    pub const iron_ingots_required: u8 = 4;
    pub const iron_ingots_total: u8 = 31;
    pub const anvils_output: u8 = 1;

    pub fn craftAnvil(iron_blocks: u8, iron_ingots: u8) u8 {
        const batches = @min(iron_blocks / iron_blocks_required, iron_ingots / iron_ingots_required);
        return batches * anvils_output;
    }
};

/// Returns how many anvils can be made from the supplied ingredients.
pub fn craftAnvil(iron_blocks: u8, iron_ingots: u8) u8 {
    return AnvilRecipe.craftAnvil(iron_blocks, iron_ingots);
}

pub const AnvilDamageStages = enum {
    intact,
    chipped,
    damaged,
    broken_destroyed,
};

pub const anvil_use_degradation_chance: f32 = 0.12;
pub const fall_degradation_chance_per_block: f32 = 0.05;
pub const crush_damage_per_extra_block: f32 = 2.0;
pub const max_crush_damage: f32 = 40.0;

/// Computes the total probability that a use degrades the anvil. A one-block
/// fall has the ordinary 12% use chance; only falls above one block add risk.
pub fn computeFallDegradationChance(fall_blocks: u8) f32 {
    const extra = if (fall_blocks > 1)
        @as(f32, @floatFromInt(fall_blocks)) * fall_degradation_chance_per_block
    else
        0.0;
    return @min(1.0, anvil_use_degradation_chance + extra);
}

/// Advances one damage stage, leaving an already destroyed anvil destroyed.
pub fn degradeAnvil(stage: AnvilDamageStages) AnvilDamageStages {
    return switch (stage) {
        .intact => .chipped,
        .chipped => .damaged,
        .damaged => .broken_destroyed,
        .broken_destroyed => .broken_destroyed,
    };
}

/// Falling onto a block deals two points for every block beyond the first.
pub fn computeFallCrushDamage(fall_blocks: u8) f32 {
    if (fall_blocks <= 1) return 0.0;
    const damage = crush_damage_per_extra_block * @as(f32, @floatFromInt(fall_blocks - 1));
    return @min(max_crush_damage, damage);
}

/// Applies crush damage to a helmet durability value, clamped at zero.
pub fn computeHelmetDurabilityAfterFall(current_durability: u16, fall_blocks: u8) u16 {
    const damage: u16 = @intFromFloat(computeFallCrushDamage(fall_blocks));
    return if (damage >= current_durability) 0 else current_durability - damage;
}

/// Prior-work cost is 2^uses - 1. The u5 input bounds the shift to 0..31.
pub fn priorWorkPenaltyLevels(anvil_uses: u5) u32 {
    return (@as(u32, 1) << anvil_uses) - 1;
}

/// Anvil results inherit the larger prior-work count, plus this operation.
/// Saturating at u5's maximum prevents a wraparound at 31 prior uses.
pub fn resultingAnvilUses(target_uses: u5, sacrifice_uses: u5) u5 {
    const greatest: u8 = @max(@as(u8, target_uses), @as(u8, sacrifice_uses));
    return @intCast(@min(@as(u8, 31), greatest + 1));
}

pub const max_survival_xp_cost: u8 = 39;

/// Survival rejects non-rename operations at 40 levels or more. Renaming is
/// allowed and its displayed cost is capped by max_survival_xp_cost.
pub fn isAnvilOperationTooExpensive(total_level_cost: u32, rename_only: bool) bool {
    return !rename_only and total_level_cost > max_survival_xp_cost;
}

pub fn cappedAnvilXpCost(total_level_cost: u32, rename_only: bool) u8 {
    _ = rename_only;
    return @intCast(@min(total_level_cost, @as(u32, max_survival_xp_cost)));
}

/// Raw material repairs restore 25% of maximum durability per unit. The
/// multiplication is performed before division so fractional quarters are
/// rounded down once for the complete repair amount.
pub fn computeUnitRepairDurability(current_dur: u16, max_dur: u16, units: u8) u16 {
    if (current_dur >= max_dur or max_dur == 0) return @min(current_dur, max_dur);
    const restored: u32 = (@as(u32, max_dur) * @min(units, 4)) / 4;
    return @intCast(@min(@as(u32, max_dur), @as(u32, current_dur) + restored));
}

/// Combining identical items adds their remaining durability and a 12% bonus.
pub fn computeSacrificeRepairDurability(target_dur: u16, sacrifice_dur: u16, max_dur: u16) u16 {
    const bonus: u32 = (@as(u32, max_dur) * 12) / 100;
    const combined = @as(u32, target_dur) + sacrifice_dur + bonus;
    return @intCast(@min(@as(u32, max_dur), combined));
}

test "anvil recipe requires three blocks and four ingots" {
    try std.testing.expectEqual(@as(u8, 1), craftAnvil(3, 4));
    try std.testing.expectEqual(@as(u8, 31), AnvilRecipe.iron_ingots_total);
}

test "anvil recipe supports multiple complete batches" {
    try std.testing.expectEqual(@as(u8, 2), craftAnvil(6, 8));
    try std.testing.expectEqual(@as(u8, 0), craftAnvil(2, 99));
}

test "anvil degradation chance includes base use chance" {
    try std.testing.expectEqual(@as(f32, 0.12), computeFallDegradationChance(0));
    try std.testing.expectEqual(@as(f32, 0.12), computeFallDegradationChance(1));
    try std.testing.expectEqual(@as(f32, 0.22), computeFallDegradationChance(2));
}

test "degradation chance caps for very high falls" {
    try std.testing.expectEqual(@as(f32, 1.0), computeFallDegradationChance(255));
}

test "anvil stages progress and destroyed stage is stable" {
    try std.testing.expectEqual(AnvilDamageStages.chipped, degradeAnvil(.intact));
    try std.testing.expectEqual(AnvilDamageStages.damaged, degradeAnvil(.chipped));
    try std.testing.expectEqual(AnvilDamageStages.broken_destroyed, degradeAnvil(.damaged));
    try std.testing.expectEqual(AnvilDamageStages.broken_destroyed, degradeAnvil(.broken_destroyed));
}

test "fall crush damage starts after one block and caps at forty" {
    try std.testing.expectEqual(@as(f32, 0.0), computeFallCrushDamage(1));
    try std.testing.expectEqual(@as(f32, 4.0), computeFallCrushDamage(3));
    try std.testing.expectEqual(@as(f32, 40.0), computeFallCrushDamage(255));
}

test "helmet durability is reduced by crush damage" {
    try std.testing.expectEqual(@as(u16, 96), computeHelmetDurabilityAfterFall(100, 3));
    try std.testing.expectEqual(@as(u16, 0), computeHelmetDurabilityAfterFall(3, 10));
}

test "prior work penalty follows powers of two minus one" {
    try std.testing.expectEqual(@as(u32, 0), priorWorkPenaltyLevels(0));
    try std.testing.expectEqual(@as(u32, 1), priorWorkPenaltyLevels(1));
    try std.testing.expectEqual(@as(u32, 3), priorWorkPenaltyLevels(2));
    try std.testing.expectEqual(@as(u32, 7), priorWorkPenaltyLevels(3));
    try std.testing.expectEqual(@as(u32, 15), priorWorkPenaltyLevels(4));
    try std.testing.expectEqual(@as(u32, 31), priorWorkPenaltyLevels(5));
}

test "resulting item uses larger prior work count plus one" {
    try std.testing.expectEqual(@as(u5, 4), resultingAnvilUses(3, 1));
    try std.testing.expectEqual(@as(u5, 4), resultingAnvilUses(2, 3));
    try std.testing.expectEqual(@as(u5, 31), resultingAnvilUses(31, 31));
}

test "survival cap rejects forty or more except rename-only" {
    try std.testing.expect(!isAnvilOperationTooExpensive(39, false));
    try std.testing.expect(isAnvilOperationTooExpensive(40, false));
    try std.testing.expect(isAnvilOperationTooExpensive(100, false));
    try std.testing.expect(!isAnvilOperationTooExpensive(100, true));
}

test "anvil xp display cost is capped at thirty-nine" {
    try std.testing.expectEqual(@as(u8, 12), cappedAnvilXpCost(12, false));
    try std.testing.expectEqual(@as(u8, 39), cappedAnvilXpCost(40, true));
    try std.testing.expectEqual(@as(u8, 39), cappedAnvilXpCost(100, false));
}

test "unit repair restores quarters and clamps at max" {
    try std.testing.expectEqual(@as(u16, 50), computeUnitRepairDurability(0, 100, 2));
    try std.testing.expectEqual(@as(u16, 100), computeUnitRepairDurability(0, 100, 4));
    try std.testing.expectEqual(@as(u16, 100), computeUnitRepairDurability(90, 100, 1));
}

test "unit repair handles zero and over-limit units" {
    try std.testing.expectEqual(@as(u16, 20), computeUnitRepairDurability(20, 100, 0));
    try std.testing.expectEqual(@as(u16, 100), computeUnitRepairDurability(0, 100, 9));
    try std.testing.expectEqual(@as(u16, 0), computeUnitRepairDurability(0, 0, 1));
}

test "sacrifice repair adds item durabilities and twelve percent bonus" {
    try std.testing.expectEqual(@as(u16, 92), computeSacrificeRepairDurability(40, 40, 100));
    try std.testing.expectEqual(@as(u16, 98), computeSacrificeRepairDurability(30, 56, 100));
}

test "sacrifice repair clamps to maximum durability" {
    try std.testing.expectEqual(@as(u16, 432), computeSacrificeRepairDurability(400, 400, 432));
}
