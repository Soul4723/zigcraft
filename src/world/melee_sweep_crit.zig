const std = @import("std");

pub const critical_or_sweep_charge_threshold: f32 = 0.848;

/// Canonical Java-style attack speeds, expressed as attacks per second.
pub const WeaponAttackSpeed = enum {
    sword_1_6_hz,
    trident_1_1_hz,
    pickaxe_1_2_hz,
    shovel_1_0_hz,
    wood_stone_axe_0_8_hz,
    diamond_netherite_axe_1_0_hz,
    mace_0_6_hz,
    bare_hand_4_0_hz,

    pub fn attacksPerSecond(self: WeaponAttackSpeed) f32 {
        return switch (self) {
            .sword_1_6_hz => 1.6,
            .trident_1_1_hz => 1.1,
            .pickaxe_1_2_hz => 1.2,
            .shovel_1_0_hz => 1.0,
            .wood_stone_axe_0_8_hz => 0.8,
            .diamond_netherite_axe_1_0_hz => 1.0,
            .mace_0_6_hz => 0.6,
            .bare_hand_4_0_hz => 4.0,
        };
    }

    pub fn rechargeDurationSeconds(self: WeaponAttackSpeed) f32 {
        return 1.0 / self.attacksPerSecond();
    }
};

pub const CooldownDamageScale = struct {
    charge_ratio_0_to_1: f32,
    damage_multiplier: f32,
    can_trigger_crit_or_sweep: bool,
};

pub fn computeCooldownDamageScale(elapsed_since_last_swing: f32, recharge_duration: f32) CooldownDamageScale {
    const charge_ratio = if (recharge_duration > 0.0)
        std.math.clamp(elapsed_since_last_swing / recharge_duration, 0.0, 1.0)
    else
        1.0;
    return .{
        .charge_ratio_0_to_1 = charge_ratio,
        .damage_multiplier = 0.2 + charge_ratio * charge_ratio * 0.8,
        .can_trigger_crit_or_sweep = charge_ratio >= critical_or_sweep_charge_threshold,
    };
}

pub fn canLandCriticalHit(
    charge_ratio: f32,
    falling_downward_vy_neg: bool,
    on_ground: bool,
    on_ladder_or_vine: bool,
    in_water: bool,
    is_blind: bool,
    is_sprinting: bool,
) bool {
    return charge_ratio >= critical_or_sweep_charge_threshold and
        falling_downward_vy_neg and
        !on_ground and
        !on_ladder_or_vine and
        !in_water and
        !is_blind and
        !is_sprinting;
}

/// Applies the 1.5x critical-hit bonus to the weapon damage value.
pub fn applyCriticalHitMultiplier(weapon_damage: f32, is_critical_hit: bool) f32 {
    return if (is_critical_hit) weapon_damage * 1.5 else weapon_damage;
}

/// Returns bonus damage to each secondary target in a valid sword sweep.
pub fn computeSwordSweepCleaveDamage(
    primary_hit_damage: f32,
    sweeping_edge_level: u2,
    weapon_is_sword: bool,
    charge_ratio: f32,
    player_moving_slowly_on_ground: bool,
) f32 {
    if (!weapon_is_sword or charge_ratio < critical_or_sweep_charge_threshold or !player_moving_slowly_on_ground) {
        return 0.0;
    }
    const level = @as(f32, @floatFromInt(sweeping_edge_level));
    return 1.0 + primary_hit_damage * (level / (level + 1.0));
}

test "weapon attack speed recharge durations" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.625), WeaponAttackSpeed.sword_1_6_hz.rechargeDurationSeconds(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), WeaponAttackSpeed.diamond_netherite_axe_1_0_hz.rechargeDurationSeconds(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 0.6), WeaponAttackSpeed.mace_0_6_hz.rechargeDurationSeconds(), 0.001);
}

test "all canonical weapon speeds have reciprocal recharge durations" {
    const weapons = [_]WeaponAttackSpeed{
        .sword_1_6_hz,          .trident_1_1_hz,               .pickaxe_1_2_hz, .shovel_1_0_hz,
        .wood_stone_axe_0_8_hz, .diamond_netherite_axe_1_0_hz, .mace_0_6_hz,    .bare_hand_4_0_hz,
    };
    for (weapons) |weapon| {
        try std.testing.expectApproxEqAbs(1.0, weapon.attacksPerSecond() * weapon.rechargeDurationSeconds(), 0.0001);
    }
}

test "cooldown damage is quadratic from twenty to one hundred percent" {
    const spam = computeCooldownDamageScale(0.0, 1.0);
    try std.testing.expectEqual(@as(f32, 0.0), spam.charge_ratio_0_to_1);
    try std.testing.expectEqual(@as(f32, 0.2), spam.damage_multiplier);
    try std.testing.expect(!spam.can_trigger_crit_or_sweep);

    const half = computeCooldownDamageScale(0.5, 1.0);
    try std.testing.expectEqual(@as(f32, 0.5), half.charge_ratio_0_to_1);
    try std.testing.expectEqual(@as(f32, 0.4), half.damage_multiplier);

    const full = computeCooldownDamageScale(1.0, 1.0);
    try std.testing.expectEqual(@as(f32, 1.0), full.charge_ratio_0_to_1);
    try std.testing.expectEqual(@as(f32, 1.0), full.damage_multiplier);
    try std.testing.expect(full.can_trigger_crit_or_sweep);
}

test "cooldown clamps elapsed charge below zero and above full" {
    try std.testing.expectEqual(@as(f32, 0.0), computeCooldownDamageScale(-1.0, 1.0).charge_ratio_0_to_1);
    try std.testing.expectEqual(@as(f32, 1.0), computeCooldownDamageScale(2.0, 1.0).charge_ratio_0_to_1);
}

test "zero recharge duration is treated as fully charged" {
    const scale = computeCooldownDamageScale(0.0, 0.0);
    try std.testing.expectEqual(@as(f32, 1.0), scale.charge_ratio_0_to_1);
    try std.testing.expectEqual(@as(f32, 1.0), scale.damage_multiplier);
    try std.testing.expect(scale.can_trigger_crit_or_sweep);
}

test "critical and sweep threshold is inclusive at 0.848" {
    try std.testing.expect(computeCooldownDamageScale(0.848, 1.0).can_trigger_crit_or_sweep);
    try std.testing.expect(!computeCooldownDamageScale(0.847, 1.0).can_trigger_crit_or_sweep);
}

test "critical hit requires a full charge and downward airborne fall" {
    try std.testing.expect(canLandCriticalHit(0.848, true, false, false, false, false, false));
    try std.testing.expect(!canLandCriticalHit(0.847, true, false, false, false, false, false));
    try std.testing.expect(!canLandCriticalHit(1.0, false, false, false, false, false, false));
    try std.testing.expect(!canLandCriticalHit(1.0, true, true, false, false, false, false));
}

test "critical hit suppressed on ladders and in water" {
    try std.testing.expect(!canLandCriticalHit(1.0, true, false, true, false, false, false));
    try std.testing.expect(!canLandCriticalHit(1.0, true, false, false, true, false, false));
}

test "critical hit suppressed by blindness and sprint knockback" {
    try std.testing.expect(!canLandCriticalHit(1.0, true, false, false, false, true, false));
    try std.testing.expect(!canLandCriticalHit(1.0, true, false, false, false, false, true));
}

test "critical hit multiplier is one and a half" {
    try std.testing.expectEqual(@as(f32, 15.0), applyCriticalHitMultiplier(10.0, true));
    try std.testing.expectEqual(@as(f32, 10.0), applyCriticalHitMultiplier(10.0, false));
}

test "sword sweep requires sword charge and slow grounded movement" {
    try std.testing.expectEqual(@as(f32, 0.0), computeSwordSweepCleaveDamage(8.0, 1, false, 1.0, true));
    try std.testing.expectEqual(@as(f32, 0.0), computeSwordSweepCleaveDamage(8.0, 1, true, 0.847, true));
    try std.testing.expectEqual(@as(f32, 0.0), computeSwordSweepCleaveDamage(8.0, 1, true, 1.0, false));
}

test "sweeping edge I cleaves one half primary damage plus one" {
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), computeSwordSweepCleaveDamage(8.0, 1, true, 0.848, true), 0.0001);
}

test "sweeping edge II cleaves two thirds primary damage plus one" {
    try std.testing.expectApproxEqAbs(@as(f32, 19.0 / 3.0), computeSwordSweepCleaveDamage(8.0, 2, true, 1.0, true), 0.0001);
}

test "sweeping edge III cleaves three quarters primary damage plus one" {
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), computeSwordSweepCleaveDamage(8.0, 3, true, 1.0, true), 0.0001);
}
