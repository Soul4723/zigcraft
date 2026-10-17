/// Damage reduction from the vanilla armor/toughness formula. Armor is normally
/// in [0, 20] and toughness in [0, 12]; callers provide raw incoming damage.
pub fn computeArmorAndToughnessReduction(raw_damage: f32, armor_points_0_to_20: f32, toughness_0_to_12: f32) f32 {
    const armor = armor_points_0_to_20;
    const toughness = toughness_0_to_12;
    const effective_armor = @min(20.0, @max(armor / 5.0, armor - (4.0 * raw_damage) / (toughness + 8.0)));
    const reduction_pct = effective_armor / 25.0;
    return raw_damage * (1.0 - reduction_pct);
}

pub const ProtectionEnchantType = enum {
    all_protection,
    fire_protection,
    blast_protection,
    projectile_protection,
    feather_falling,
};

pub fn computeSinglePieceEpf(
    enchant: ProtectionEnchantType,
    level_1_to_4: u3,
    damage_is_fire: bool,
    damage_is_explosion: bool,
    damage_is_projectile: bool,
    damage_is_fall: bool,
) u8 {
    const level: u8 = level_1_to_4;
    return switch (enchant) {
        .all_protection => level,
        .fire_protection => if (damage_is_fire) 2 * level else 0,
        .blast_protection => if (damage_is_explosion) 2 * level else 0,
        .projectile_protection => if (damage_is_projectile) 2 * level else 0,
        // Callers classify Ender Pearl teleport impact as fall damage too.
        .feather_falling => if (damage_is_fall) 3 * level else 0,
    };
}

pub fn applyTotalEpfReduction(damage_after_armor: f32, total_epf_sum: u8) f32 {
    const capped_epf = @min(20, total_epf_sum);
    return damage_after_armor * (1.0 - @as(f32, @floatFromInt(capped_epf)) * 0.04);
}

pub fn blastProtectionKnockbackMultiplier(level_1_to_4: u3) f32 {
    return 1.0 - @as(f32, @floatFromInt(level_1_to_4)) * 0.15;
}

pub fn fireProtectionBurnTimeMultiplier(level_1_to_4: u3) f32 {
    return 1.0 - @as(f32, @floatFromInt(level_1_to_4)) * 0.15;
}

test "armor and toughness reduce heavy hits better at higher toughness" {
    const leather = computeArmorAndToughnessReduction(15.0, 7.0, 0.0);
    const iron = computeArmorAndToughnessReduction(15.0, 15.0, 0.0);
    const diamond = computeArmorAndToughnessReduction(15.0, 20.0, 8.0);
    const netherite = computeArmorAndToughnessReduction(15.0, 20.0, 12.0);
    try std.testing.expect(leather > iron);
    try std.testing.expect(iron > diamond);
    try std.testing.expect(diamond > netherite);
    try std.testing.expectApproxEqAbs(@as(f32, 14.16), leather, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), iron, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 5.25), diamond, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 4.8), netherite, 0.01);
}

test "toughness limits high damage armor penetration" {
    const zero_toughness = computeArmorAndToughnessReduction(20.0, 20.0, 0.0);
    const diamond = computeArmorAndToughnessReduction(20.0, 20.0, 8.0);
    const netherite = computeArmorAndToughnessReduction(20.0, 20.0, 12.0);
    try std.testing.expect(diamond < zero_toughness);
    try std.testing.expect(netherite < diamond);
}

test "armor bounds effective armor to twenty" {
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), computeArmorAndToughnessReduction(10.0, 30.0, 12.0), 0.001);
}

test "protection four grants four EPF against every category" {
    try std.testing.expectEqual(@as(u8, 4), computeSinglePieceEpf(.all_protection, 4, false, false, false, false));
    try std.testing.expectEqual(@as(u8, 4), computeSinglePieceEpf(.all_protection, 4, true, true, true, true));
}

test "specialized protection four grants eight EPF for matching damage" {
    try std.testing.expectEqual(@as(u8, 8), computeSinglePieceEpf(.fire_protection, 4, true, false, false, false));
    try std.testing.expectEqual(@as(u8, 8), computeSinglePieceEpf(.blast_protection, 4, false, true, false, false));
    try std.testing.expectEqual(@as(u8, 8), computeSinglePieceEpf(.projectile_protection, 4, false, false, true, false));
}

test "specialized protections do not protect against unrelated categories" {
    try std.testing.expectEqual(@as(u8, 0), computeSinglePieceEpf(.fire_protection, 4, false, true, true, true));
    try std.testing.expectEqual(@as(u8, 0), computeSinglePieceEpf(.blast_protection, 4, true, false, true, true));
    try std.testing.expectEqual(@as(u8, 0), computeSinglePieceEpf(.projectile_protection, 4, true, true, false, true));
}

test "feather falling four grants twelve EPF against fall damage" {
    try std.testing.expectEqual(@as(u8, 12), computeSinglePieceEpf(.feather_falling, 4, false, false, false, true));
    try std.testing.expectEqual(@as(u8, 0), computeSinglePieceEpf(.feather_falling, 4, false, false, false, false));
}

test "feather falling levels scale at three EPF per level" {
    try std.testing.expectEqual(@as(u8, 3), computeSinglePieceEpf(.feather_falling, 1, false, false, false, true));
    try std.testing.expectEqual(@as(u8, 9), computeSinglePieceEpf(.feather_falling, 3, false, false, false, true));
}

test "EPF reduction is four percent per point" {
    try std.testing.expectApproxEqAbs(@as(f32, 8.4), applyTotalEpfReduction(10.0, 4), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.8), applyTotalEpfReduction(10.0, 8), 0.001);
}

test "EPF hard cap limits reduction to eighty percent" {
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), applyTotalEpfReduction(10.0, 20), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), applyTotalEpfReduction(10.0, 24), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), applyTotalEpfReduction(10.0, 255), 0.001);
}

test "EPF stacks multiplicatively after armor reduction" {
    const after_armor = computeArmorAndToughnessReduction(10.0, 10.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 6.72), applyTotalEpfReduction(after_armor, 4), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.72), after_armor * 0.84, 0.001);
}

test "blast protection four reduces explosion knockback by sixty percent" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), blastProtectionKnockbackMultiplier(4), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), blastProtectionKnockbackMultiplier(1), 0.001);
}

test "fire protection four reduces burn time by sixty percent" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), fireProtectionBurnTimeMultiplier(4), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), fireProtectionBurnTimeMultiplier(1), 0.001);
}

test "zero armor and zero EPF leave damage unchanged" {
    try std.testing.expectEqual(@as(f32, 15.0), computeArmorAndToughnessReduction(15.0, 0.0, 0.0));
    try std.testing.expectEqual(@as(f32, 15.0), applyTotalEpfReduction(15.0, 0));
}

const std = @import("std");
