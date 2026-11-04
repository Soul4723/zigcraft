const std = @import("std");

// =========================================================================
// WEAPON CONSTANTS & ATTRIBUTES
// =========================================================================

pub const BASE_DAMAGE: f32 = 6.0;
pub const base_damage: f32 = BASE_DAMAGE;
pub const mace_base_damage: u8 = 6;

pub const SMASH_MIN_FALL_DISTANCE: f32 = 1.5;
pub const smash_min_fall_distance: f32 = SMASH_MIN_FALL_DISTANCE;
pub const smash_threshold_m: f32 = smash_min_fall_distance;
pub const smash_max_damage: u8 = 50;

pub const FIRST_TIER_HEIGHT_LIMIT: f32 = 3.0;
pub const FIRST_TIER_DAMAGE_RATE: f32 = 4.0;
pub const SECOND_TIER_DAMAGE_RATE: f32 = 2.0;

pub const MAX_COMBO_MULTIPLIER: f32 = 2.0;
pub const max_combo_multiplier: f32 = MAX_COMBO_MULTIPLIER;
pub const max_damage_multiplier: f32 = MAX_COMBO_MULTIPLIER;
pub const COMBO_MULTIPLIER_STEP: f32 = 0.25;

pub const DENSITY_FACTOR_PER_LEVEL: f32 = 0.5;
pub const MAX_DENSITY_LEVEL: u3 = 5;

pub const BREACH_REDUCTION_PER_LEVEL: f32 = 0.15;
pub const MAX_BREACH_LEVEL: u3 = 4;

pub const WIND_BURST_I_VELOCITY: f32 = 7.0;
pub const WIND_BURST_II_VELOCITY: f32 = 10.0;
pub const WIND_BURST_III_VELOCITY: f32 = 13.0;
pub const wind_burst_iii_launch_speed: f32 = WIND_BURST_III_VELOCITY;
pub const secondary_vertical_pop_speed: f32 = 3.5;

pub const DURABILITY: u16 = 500;
pub const durability: u16 = DURABILITY;
pub const mace_durability: u16 = DURABILITY;

pub const attack_speed: f32 = 0.6;
pub const attack_cooldown_seconds: f32 = 1.0 / attack_speed;
pub const attack_cooldown_ticks: u8 = 33;
pub const shockwave_radius: f32 = 2.5;
pub const shockwave_radius_m: f32 = 3.5;
pub const resetFallOnSmash: bool = true;

// =========================================================================
// ENUMS & STRUCTURES
// =========================================================================

pub const ExclusiveEnchantment = enum { none, density, breach };

pub const WindBurstLevel = enum(u2) {
    none = 0,
    one = 1,
    two = 2,
    three = 3,

    pub fn impulse(self: WindBurstLevel) f32 {
        return switch (self) {
            .none => 0.0,
            .one => WIND_BURST_I_VELOCITY,
            .two => WIND_BURST_II_VELOCITY,
            .three => WIND_BURST_III_VELOCITY,
        };
    }
};

pub const HitKind = enum { miss, normal_hit, smash_hit };

pub const FallState = struct {
    accumulated_fall_distance: f32,
    downward_velocity: f32,
};

pub const KnockbackTarget = struct {
    distance: f32,
    is_smash_target: bool = false,
    is_mob: bool = true,
};

pub const PlayerState = struct {
    combo_count: u32 = 0,
    accumulated_fall_damage: f32 = 0.0,
    vertical_velocity: f32 = 0.0,
};

pub const SmashOutcome = struct {
    landed_smash: bool,
    combo_count: u32,
    damage_multiplier: f32,
    primary_damage: f32,
    wind_burst_impulse: f32,
    fall_damage_negated: bool,
};

pub const ShockwaveEffect = struct {
    knockback_force: f32,
    vertical_velocity: f32,
};

/// State tracking for aerial mace combat combos, fall kinematics, and accumulated damage.
pub const MaceComboTracker = struct {
    combo_count: u32 = 0,
    accumulated_fall_distance: f32 = 0.0,
    accumulated_fall_damage: f32 = 0.0,
    vertical_velocity: f32 = 0.0,
    is_grounded: bool = true,

    /// Reset combo on ground contact.
    pub fn onGroundContact(self: *MaceComboTracker) void {
        self.combo_count = 0;
        self.is_grounded = true;
        self.vertical_velocity = 0.0;
    }

    /// Mark player as airborne.
    pub fn onTakeoff(self: *MaceComboTracker) void {
        self.is_grounded = false;
    }

    /// Update accumulated fall distance during fall.
    pub fn addFallDistance(self: *MaceComboTracker, delta: f32) void {
        if (delta > 0.0) {
            self.accumulated_fall_distance += delta;
            self.accumulated_fall_damage = calculateUnmitigatedFallDamage(self.accumulated_fall_distance);
        }
    }

    /// Reset fall damage and fall distance completely (e.g. upon landing smash attack).
    pub fn resetFallDamage(self: *MaceComboTracker) void {
        self.accumulated_fall_distance = 0.0;
        self.accumulated_fall_damage = 0.0;
    }

    /// Current combo multiplier based on active chain.
    pub fn currentMultiplier(self: *const MaceComboTracker) f32 {
        return calculateComboMultiplier(self.combo_count);
    }
};

/// Configuration options for a mace attack.
pub const MaceAttackConfig = struct {
    density_level: u3 = 0,
    breach_level: u3 = 0,
    wind_burst_level: WindBurstLevel = .none,
    target_armor: f32 = 0.0,
};

/// Detailed outcome of executing a mace smash attack.
pub const SmashExecutionResult = struct {
    is_smash: bool,
    hit_successful: bool,
    fall_distance: f32,
    combo_count: u32,
    combo_multiplier: f32,
    base_kinetic_damage: f32,
    density_bonus: f32,
    pre_combo_damage: f32,
    final_damage: f32,
    target_armor_original: f32,
    target_armor_effective: f32,
    breach_reduction: f32,
    wind_burst_launch_speed: f32,
    fall_damage_canceled: bool,
    prior_fall_damage: f32,
};

// =========================================================================
// HELPER FUNCTIONS & FORMULAS
// =========================================================================

pub fn isSmashAttack(fall_distance: f32) bool {
    return fall_distance >= SMASH_MIN_FALL_DISTANCE;
}

pub fn calculateRawHeightScaling(h: f32) f32 {
    const height = @max(0.0, h);
    return BASE_DAMAGE + FIRST_TIER_DAMAGE_RATE * @min(height, FIRST_TIER_HEIGHT_LIMIT) +
        SECOND_TIER_DAMAGE_RATE * @max(0.0, height - FIRST_TIER_HEIGHT_LIMIT);
}

pub fn calculateKineticDamage(fall_distance: f32) f32 {
    if (!isSmashAttack(fall_distance)) {
        return BASE_DAMAGE;
    }
    return calculateRawHeightScaling(fall_distance);
}

pub fn densityDamageBonus(fall_distance: f32, level: u3) f32 {
    const clamped_level = @min(level, MAX_DENSITY_LEVEL);
    return DENSITY_FACTOR_PER_LEVEL * @as(f32, @floatFromInt(clamped_level)) * @max(0.0, fall_distance);
}
pub const calculateDensityBonus = densityDamageBonus;

pub fn calculateSmashDamage(fall_distance: f32, density_level: u3) f32 {
    if (!isSmashAttack(fall_distance)) return BASE_DAMAGE;
    return calculateKineticDamage(fall_distance) + densityDamageBonus(fall_distance, density_level);
}

pub fn calculateMaceDamage(fall_distance: f32) u8 {
    if (!isSmashAttack(fall_distance)) {
        return mace_base_damage;
    }
    const first_tier = @min(fall_distance, 3.0) * 4.0;
    const extra_tier = @max(0.0, fall_distance - 3.0) * 2.0;
    const total = @as(f32, @floatFromInt(mace_base_damage)) + first_tier + extra_tier;
    return @intFromFloat(@min(@as(f32, @floatFromInt(smash_max_damage)), @floor(total)));
}

pub fn shouldNegateFallOnSmash(is_mace: bool, fall_distance: f32) bool {
    return is_mace and isSmashAttack(fall_distance);
}

pub fn breachArmorReduction(breach_level: u3) f32 {
    const clamped_level = @min(breach_level, MAX_BREACH_LEVEL);
    return BREACH_REDUCTION_PER_LEVEL * @as(f32, @floatFromInt(clamped_level));
}
pub const breachReductionRatio = breachArmorReduction;

pub fn effectiveArmorDefense(armor_points: f32, breach_level: u3) f32 {
    const reduction = breachArmorReduction(breach_level);
    return @max(0.0, armor_points * (1.0 - reduction));
}
pub const calculateEffectiveArmor = effectiveArmorDefense;

pub fn hasExclusiveEnchantmentConflict(first: ExclusiveEnchantment, second: ExclusiveEnchantment) bool {
    return first != .none and second != .none and first != second;
}

pub fn resetFallStateOnSmash(state: FallState, successful_smash: bool) FallState {
    if (!successful_smash) return state;
    return .{ .accumulated_fall_distance = 0.0, .downward_velocity = 0.0 };
}

pub fn shouldKnockbackTarget(target: KnockbackTarget) bool {
    return target.is_mob and !target.is_smash_target and target.distance >= 0.0 and target.distance <= shockwave_radius;
}

pub fn windBurstVerticalImpulse(level: WindBurstLevel) f32 {
    return level.impulse();
}
pub const getWindBurstImpulse = windBurstVerticalImpulse;

pub fn getWindBurstImpulseFromInt(level: u3) f32 {
    return switch (level) {
        0 => 0.0,
        1 => WIND_BURST_I_VELOCITY,
        2 => WIND_BURST_II_VELOCITY,
        else => WIND_BURST_III_VELOCITY,
    };
}

/// Combo count is one-based after the first landed smash and stays zero otherwise.
pub fn damageMultiplier(combo_count: u32) f32 {
    if (combo_count == 0) return 1.0;
    const multiplier = 1.0 + COMBO_MULTIPLIER_STEP * @as(f32, @floatFromInt(combo_count - 1));
    return @min(multiplier, MAX_COMBO_MULTIPLIER);
}
pub const calculateComboMultiplier = damageMultiplier;

pub fn calculateSmashDamageWithEnchantments(fall_distance: f32, density_level: u3, combo_count: u32) f32 {
    return calculateSmashDamage(fall_distance, density_level) * damageMultiplier(combo_count);
}

/// A successful smash landing resets fall damage and advances the aerial combo.
/// Wind Burst III applies its upward launch only when that smash is successfully landed.
pub fn landSmash(
    player: *PlayerState,
    fall_height: f32,
    successful_hit: bool,
    wind_burst: WindBurstLevel,
) SmashOutcome {
    const landed_smash = successful_hit and isSmashAttack(fall_height);
    if (!landed_smash) {
        return .{
            .landed_smash = false,
            .combo_count = player.combo_count,
            .damage_multiplier = damageMultiplier(player.combo_count),
            .primary_damage = 0.0,
            .wind_burst_impulse = 0.0,
            .fall_damage_negated = false,
        };
    }

    player.combo_count +|= 1;
    player.accumulated_fall_damage = 0.0;
    const impulse = if (wind_burst == .three) wind_burst_iii_launch_speed else 0.0;
    if (impulse > 0.0) player.vertical_velocity = impulse;
    const multiplier = damageMultiplier(player.combo_count);

    return .{
        .landed_smash = true,
        .combo_count = player.combo_count,
        .damage_multiplier = multiplier,
        .primary_damage = calculateSmashDamage(fall_height, 0) * multiplier,
        .wind_burst_impulse = impulse,
        .fall_damage_negated = true,
    };
}

/// Solid ground contact ends the current chain, including after a Wind Burst launch.
pub fn onGroundContact(player: *PlayerState) void {
    player.combo_count = 0;
}

/// Returns no effect for the primary target or for entities outside the shockwave.
pub fn shockwaveEffect(distance: f32, combo_count: u32, is_primary_target: bool) ?ShockwaveEffect {
    if (is_primary_target or !std.math.isFinite(distance) or distance < 0.0 or distance > shockwave_radius_m) {
        return null;
    }
    const combo = @as(f32, @floatFromInt(combo_count));
    const falloff = (shockwave_radius_m - distance) / shockwave_radius_m;
    return .{
        .knockback_force = falloff * (1.5 + 0.5 * combo),
        .vertical_velocity = secondary_vertical_pop_speed,
    };
}

/// Calculates vanilla Minecraft-style fall damage: max(0.0, height - 3.0).
pub fn calculateUnmitigatedFallDamage(fall_distance: f32) f32 {
    return @max(0.0, fall_distance - 3.0);
}

/// Unbreaking avoids a wear point on `unbreaking_level` of every `unbreaking_level + 1` rolls.
/// `wear_roll` is expected in [0, 1); passing it makes the result deterministic and testable.
pub fn durabilityWear(kind: HitKind, unbreaking_level: u3, wear_roll: f32) u16 {
    if (kind == .miss) return 0;
    const level = @min(unbreaking_level, 3);
    if (level == 0) return 1;
    const wear_chance = 1.0 / (@as(f32, @floatFromInt(level)) + 1.0);
    return if (wear_roll < wear_chance) 1 else 0;
}

/// Execute a mace strike, evaluating smash criteria, kinetic scaling, enchantments,
/// combo multipliers, Wind Burst launch impulse, and complete fall damage cancellation.
pub fn executeAttack(
    tracker: *MaceComboTracker,
    fall_distance: f32,
    hit_successful: bool,
    config: MaceAttackConfig,
) SmashExecutionResult {
    const smash_qualified = isSmashAttack(fall_distance);
    const prior_damage = tracker.accumulated_fall_damage;

    if (!hit_successful or !smash_qualified) {
        const kinetic = if (smash_qualified) calculateKineticDamage(fall_distance) else BASE_DAMAGE;
        const eff_armor = calculateEffectiveArmor(config.target_armor, config.breach_level);
        return .{
            .is_smash = false,
            .hit_successful = hit_successful,
            .fall_distance = fall_distance,
            .combo_count = tracker.combo_count,
            .combo_multiplier = tracker.currentMultiplier(),
            .base_kinetic_damage = kinetic,
            .density_bonus = 0.0,
            .pre_combo_damage = kinetic,
            .final_damage = kinetic,
            .target_armor_original = config.target_armor,
            .target_armor_effective = eff_armor,
            .breach_reduction = breachReductionRatio(config.breach_level),
            .wind_burst_launch_speed = 0.0,
            .fall_damage_canceled = false,
            .prior_fall_damage = prior_damage,
        };
    }

    tracker.combo_count +|= 1;
    tracker.resetFallDamage();

    const impulse = config.wind_burst_level.impulse();
    if (impulse > 0.0) {
        tracker.vertical_velocity = impulse;
        tracker.is_grounded = false;
    }

    const kinetic = calculateKineticDamage(fall_distance);
    const density_bonus = calculateDensityBonus(fall_distance, config.density_level);
    const pre_combo = kinetic + density_bonus;
    const mult = tracker.currentMultiplier();
    const final_dmg = pre_combo * mult;
    const eff_armor = calculateEffectiveArmor(config.target_armor, config.breach_level);

    return .{
        .is_smash = true,
        .hit_successful = true,
        .fall_distance = fall_distance,
        .combo_count = tracker.combo_count,
        .combo_multiplier = mult,
        .base_kinetic_damage = kinetic,
        .density_bonus = density_bonus,
        .pre_combo_damage = pre_combo,
        .final_damage = final_dmg,
        .target_armor_original = config.target_armor,
        .target_armor_effective = eff_armor,
        .breach_reduction = breachReductionRatio(config.breach_level),
        .wind_burst_launch_speed = impulse,
        .fall_damage_canceled = true,
        .prior_fall_damage = prior_damage,
    };
}

// =========================================================================
// UNIT TESTS
// =========================================================================

test "calculateSmashDamageWithEnchantments combines density and aerial combo scaling" {
    // at 3.0m fall: kinetic = 6 + 4*3 = 18.0.
    // density 2: +0.5 * 2 * 3.0 = 3.0. pre-combo = 21.0.
    // combo 3: 1.0 + 0.25 * 2 = 1.5x -> 21.0 * 1.5 = 31.5.
    try std.testing.expectApproxEqAbs(@as(f32, 31.5), calculateSmashDamageWithEnchantments(3.0, 2, 3), 0.0001);
    // sub-threshold fall: base = 6.0, combo 1 = 1.0x -> 6.0
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), calculateSmashDamageWithEnchantments(1.0, 2, 1), 0.0001);
}

test "breachArmorReduction clamps to max breach level" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), breachArmorReduction(0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.15), breachArmorReduction(1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), breachArmorReduction(2), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.45), breachArmorReduction(3), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), breachArmorReduction(4), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), breachArmorReduction(5), 0.0001);
}

test "weapon core attributes" {
    try std.testing.expectEqual(@as(f32, 6.0), base_damage);
    try std.testing.expectEqual(@as(f32, 0.6), attack_speed);
    try std.testing.expectApproxEqAbs(@as(f32, 1.67), attack_cooldown_seconds, 0.01);
    try std.testing.expectEqual(@as(u8, 33), attack_cooldown_ticks);
    try std.testing.expectEqual(@as(u16, 500), durability);
    try std.testing.expect(resetFallOnSmash);
}

test "smash threshold is inclusive at one and a half meters" {
    try std.testing.expect(!isSmashAttack(1.49));
    try std.testing.expect(isSmashAttack(1.50));
}

test "smash damage follows two fall tiers at requested heights" {
    const cases = [_]struct { h: f32, expected: f32 }{
        .{ .h = 1.5, .expected = 12.0 },  .{ .h = 3.0, .expected = 18.0 },
        .{ .h = 5.0, .expected = 22.0 },  .{ .h = 10.0, .expected = 32.0 },
        .{ .h = 20.0, .expected = 52.0 },
    };
    for (cases) |case| try std.testing.expectApproxEqAbs(case.expected, calculateSmashDamage(case.h, 0), 0.0001);
}

test "density levels one through five add half a point per level per block" {
    for (1..6) |level| {
        const level_u3: u3 = @intCast(level);
        try std.testing.expectApproxEqAbs(0.5 * @as(f32, @floatFromInt(level)) * 4.0, densityDamageBonus(4.0, level_u3), 0.0001);
        try std.testing.expectApproxEqAbs(20.0 + 2.0 * @as(f32, @floatFromInt(level)), calculateSmashDamage(4.0, level_u3), 0.0001);
    }
}

test "density is bounded to level five and negative fall grants no bonus" {
    try std.testing.expectEqual(densityDamageBonus(3.0, 5), densityDamageBonus(3.0, 7));
    try std.testing.expectEqual(@as(f32, 0.0), densityDamageBonus(-2.0, 5));
}

test "breach reduces effective armor by fifteen percent per level" {
    for (1..5) |level| {
        const lvl: u3 = @intCast(level);
        const remaining = 1.0 - 0.15 * @as(f32, @floatFromInt(level));
        try std.testing.expectApproxEqAbs(20.0 * remaining, effectiveArmorDefense(20.0, lvl), 0.0001);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), effectiveArmorDefense(20.0, 4), 0.0001);
}

test "breach armor never becomes negative and caps at level four" {
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), effectiveArmorDefense(20.0, 7), 0.0001);
    try std.testing.expectEqual(effectiveArmorDefense(20.0, 4), effectiveArmorDefense(20.0, 7));
}

test "density and breach conflict while matching or absent enchantments do not" {
    try std.testing.expect(hasExclusiveEnchantmentConflict(.density, .breach));
    try std.testing.expect(!hasExclusiveEnchantmentConflict(.density, .density));
    try std.testing.expect(!hasExclusiveEnchantmentConflict(.none, .breach));
}

test "successful smash resets accumulated fall and downward velocity" {
    const initial = FallState{ .accumulated_fall_distance = 9.5, .downward_velocity = -14.0 };
    const reset = resetFallStateOnSmash(initial, true);
    try std.testing.expectEqual(@as(f32, 0.0), reset.accumulated_fall_distance);
    try std.testing.expectEqual(@as(f32, 0.0), reset.downward_velocity);
}

test "miss or failed smash preserves fall state" {
    const initial = FallState{ .accumulated_fall_distance = 9.5, .downward_velocity = -14.0 };
    try std.testing.expectEqual(initial, resetFallStateOnSmash(initial, false));
}

test "sub-threshold fall only deals base weapon damage" {
    try std.testing.expectEqual(base_damage, calculateSmashDamage(1.49, 0));
    try std.testing.expectEqual(base_damage, calculateSmashDamage(0.0, 5));
}

test "density I bonus scales linearly with fall height" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), densityDamageBonus(1.5, 1), 0.0001);
}

test "density II bonus scales linearly with fall height" {
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), densityDamageBonus(3.0, 2), 0.0001);
}

test "density III bonus scales linearly with fall height" {
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), densityDamageBonus(3.0, 3), 0.0001);
}

test "density IV bonus scales linearly with fall height" {
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), densityDamageBonus(3.0, 4), 0.0001);
}

test "density V bonus scales linearly with fall height" {
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), densityDamageBonus(3.0, 5), 0.0001);
}

test "breach I leaves eighty five percent armor" {
    try std.testing.expectApproxEqAbs(@as(f32, 17.0), effectiveArmorDefense(20.0, 1), 0.0001);
}

test "breach II leaves seventy percent armor" {
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), effectiveArmorDefense(20.0, 2), 0.0001);
}

test "breach III leaves fifty five percent armor" {
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), effectiveArmorDefense(20.0, 3), 0.0001);
}

test "breach IV leaves forty percent armor" {
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), effectiveArmorDefense(20.0, 4), 0.0001);
}

test "wind burst I launches with seven meters per second" {
    try std.testing.expectEqual(@as(f32, 7.0), windBurstVerticalImpulse(.one));
}

test "wind burst II launches with ten meters per second" {
    try std.testing.expectEqual(@as(f32, 10.0), windBurstVerticalImpulse(.two));
}

test "wind burst III launches with thirteen meters per second" {
    try std.testing.expectEqual(@as(f32, 13.0), windBurstVerticalImpulse(.three));
}

test "normal hit and smash hit consume the same durability" {
    try std.testing.expectEqual(durabilityWear(.normal_hit, 2, 0.1), durabilityWear(.smash_hit, 2, 0.1));
}

test "shockwave affects surrounding mobs through two point five meters" {
    try std.testing.expect(shouldKnockbackTarget(.{ .distance = 0.0 }));
    try std.testing.expect(shouldKnockbackTarget(.{ .distance = 2.5 }));
    try std.testing.expect(!shouldKnockbackTarget(.{ .distance = 2.51 }));
}

test "shockwave excludes primary target non-mobs and invalid distances" {
    try std.testing.expect(!shouldKnockbackTarget(.{ .distance = 1.0, .is_smash_target = true }));
    try std.testing.expect(!shouldKnockbackTarget(.{ .distance = 1.0, .is_mob = false }));
    try std.testing.expect(!shouldKnockbackTarget(.{ .distance = -0.1 }));
}

test "wind burst impulses map to levels one through three" {
    try std.testing.expectEqual(@as(f32, 7.0), windBurstVerticalImpulse(.one));
    try std.testing.expectEqual(@as(f32, 10.0), windBurstVerticalImpulse(.two));
    try std.testing.expectEqual(@as(f32, 13.0), windBurstVerticalImpulse(.three));
}

test "no wind burst enchantment has no impulse" {
    try std.testing.expectEqual(@as(f32, 0.0), windBurstVerticalImpulse(.none));
}

test "miss costs no durability and normal or smash hit costs one without unbreaking" {
    try std.testing.expectEqual(@as(u16, 0), durabilityWear(.miss, 0, 0.0));
    try std.testing.expectEqual(@as(u16, 1), durabilityWear(.normal_hit, 0, 0.9));
    try std.testing.expectEqual(@as(u16, 1), durabilityWear(.smash_hit, 0, 0.9));
}

test "unbreaking probabilistically prevents hit wear" {
    try std.testing.expectEqual(@as(u16, 1), durabilityWear(.smash_hit, 1, 0.49));
    try std.testing.expectEqual(@as(u16, 0), durabilityWear(.smash_hit, 1, 0.5));
    try std.testing.expectEqual(@as(u16, 1), durabilityWear(.normal_hit, 3, 0.24));
    try std.testing.expectEqual(@as(u16, 0), durabilityWear(.normal_hit, 3, 0.25));
}

test "constants have expected values" {
    try std.testing.expectEqual(@as(u8, 6), mace_base_damage);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), smash_min_fall_distance, 0.0001);
    try std.testing.expectEqual(@as(u8, 50), smash_max_damage);
    try std.testing.expectEqual(@as(u16, 500), mace_durability);
}

test "isSmashAttack threshold at 1.5 blocks" {
    try std.testing.expect(!isSmashAttack(0.0));
    try std.testing.expect(!isSmashAttack(1.49));
    try std.testing.expect(isSmashAttack(1.5));
    try std.testing.expect(isSmashAttack(3.0));
    try std.testing.expect(isSmashAttack(100.0));
}

test "calculateMaceDamage returns base below threshold" {
    try std.testing.expectEqual(@as(u8, 6), calculateMaceDamage(0.0));
    try std.testing.expectEqual(@as(u8, 6), calculateMaceDamage(1.0));
    try std.testing.expectEqual(@as(u8, 6), calculateMaceDamage(1.49));
}

test "calculateMaceDamage first tier scaling" {
    // at fall 1.5: 6 + 1.5*4 = 12
    try std.testing.expectEqual(@as(u8, 12), calculateMaceDamage(1.5));
    // at fall 2.0: 6 + 2*4 = 14
    try std.testing.expectEqual(@as(u8, 14), calculateMaceDamage(2.0));
    // at fall 3.0: 6 + 3*4 = 18
    try std.testing.expectEqual(@as(u8, 18), calculateMaceDamage(3.0));
}

test "calculateMaceDamage extra tier scaling" {
    // at fall 4.0: 6 + 12 + 1*2 = 20
    try std.testing.expectEqual(@as(u8, 20), calculateMaceDamage(4.0));
    // at fall 5.0: 6 + 12 + 2*2 = 22
    try std.testing.expectEqual(@as(u8, 22), calculateMaceDamage(5.0));
    // at fall 10.0: 6 + 12 + 7*2 = 32
    try std.testing.expectEqual(@as(u8, 32), calculateMaceDamage(10.0));
}

test "calculateMaceDamage clamps to smash max" {
    try std.testing.expectEqual(smash_max_damage, calculateMaceDamage(25.0));
    try std.testing.expectEqual(smash_max_damage, calculateMaceDamage(1000.0));
}

test "calculateMaceDamage floors fractional result" {
    // at fall 1.75: 6 + 7.0 = 13.0
    try std.testing.expectEqual(@as(u8, 13), calculateMaceDamage(1.75));
    // at fall 2.1: 6 + 8.4 = 14.4 -> 14
    try std.testing.expectEqual(@as(u8, 14), calculateMaceDamage(2.1));
    // at fall 3.25: 6 + 12 + 0.5 = 18.5 -> 18
    try std.testing.expectEqual(@as(u8, 18), calculateMaceDamage(3.25));
}

test "shouldNegateFallOnSmash requires mace and smash" {
    try std.testing.expect(shouldNegateFallOnSmash(true, 1.5));
    try std.testing.expect(shouldNegateFallOnSmash(true, 10.0));
    try std.testing.expect(!shouldNegateFallOnSmash(false, 10.0));
    try std.testing.expect(!shouldNegateFallOnSmash(true, 1.0));
    try std.testing.expect(!shouldNegateFallOnSmash(false, 0.0));
}

test "smash threshold is below one and a half meters" {
    try std.testing.expect(!isSmashAttack(1.49));
}

test "smash threshold includes exactly one and a half meters" {
    try std.testing.expect(isSmashAttack(1.5));
}

test "smash threshold accepts greater fall heights" {
    try std.testing.expect(isSmashAttack(2.0));
}

test "a failed hit does not count as a landed smash" {
    var player = PlayerState{ .combo_count = 2 };
    const outcome = landSmash(&player, 8.0, false, .three);
    try std.testing.expect(!outcome.landed_smash);
    try std.testing.expectEqual(@as(u32, 2), player.combo_count);
}

test "subthreshold hit does not count as a smash" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.49, true, .three);
    try std.testing.expect(!outcome.landed_smash);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.wind_burst_impulse);
}

test "first successful smash starts combo one at one times damage" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.5, true, .none);
    try std.testing.expectEqual(@as(u32, 1), outcome.combo_count);
    try std.testing.expectEqual(@as(f32, 1.0), outcome.damage_multiplier);
}

test "second consecutive smash increases combo multiplier to one point two five" {
    var player = PlayerState{};
    _ = landSmash(&player, 2.0, true, .none);
    const outcome = landSmash(&player, 2.0, true, .none);
    try std.testing.expectEqual(@as(u32, 2), outcome.combo_count);
    try std.testing.expectEqual(@as(f32, 1.25), outcome.damage_multiplier);
}

test "third consecutive smash increases combo multiplier to one point five" {
    var player = PlayerState{};
    _ = landSmash(&player, 2.0, true, .none);
    _ = landSmash(&player, 2.0, true, .none);
    const outcome = landSmash(&player, 2.0, true, .none);
    try std.testing.expectEqual(@as(u32, 3), outcome.combo_count);
    try std.testing.expectEqual(@as(f32, 1.5), outcome.damage_multiplier);
}

test "fourth combo increases multiplier to one point seven five" {
    try std.testing.expectEqual(@as(f32, 1.75), damageMultiplier(4));
}

test "fifth combo reaches two times damage" {
    try std.testing.expectEqual(@as(f32, 2.0), damageMultiplier(5));
}

test "combo multiplier remains capped after the fifth combo" {
    try std.testing.expectEqual(@as(f32, 2.0), damageMultiplier(20));
}

test "zero combo multiplier is the normal one times baseline" {
    try std.testing.expectEqual(@as(f32, 1.0), damageMultiplier(0));
}

test "successful smash scales full primary smash damage by combo" {
    var player = PlayerState{ .combo_count = 1 };
    const outcome = landSmash(&player, 3.0, true, .none);
    try std.testing.expectEqual(@as(f32, 18.0 * 1.25), outcome.primary_damage);
}

test "Wind Burst III applies plus thirteen meters per second" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.5, true, .three);
    try std.testing.expectEqual(@as(f32, 13.0), outcome.wind_burst_impulse);
    try std.testing.expectEqual(@as(f32, 13.0), player.vertical_velocity);
}

test "Wind Burst III launch applies at the smash threshold" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.5, true, .three);
    try std.testing.expectEqual(wind_burst_iii_launch_speed, outcome.wind_burst_impulse);
}

test "Wind Burst III launch does not apply below the smash threshold" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.49, true, .three);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.wind_burst_impulse);
}

test "Wind Burst III launch does not apply on a miss" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 3.0, false, .three);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.wind_burst_impulse);
}

test "Wind Burst levels one and two do not use the level three launch" {
    var one = PlayerState{};
    var two = PlayerState{};
    try std.testing.expectEqual(@as(f32, 0.0), landSmash(&one, 3.0, true, .one).wind_burst_impulse);
    try std.testing.expectEqual(@as(f32, 0.0), landSmash(&two, 3.0, true, .two).wind_burst_impulse);
}

test "landing smash sets launch velocity to thirteen" {
    var player = PlayerState{ .vertical_velocity = -20.0 };
    _ = landSmash(&player, 10.0, true, .three);
    try std.testing.expectEqual(@as(f32, 13.0), player.vertical_velocity);
}

test "landing without Wind Burst preserves vertical velocity" {
    var player = PlayerState{ .vertical_velocity = -8.0 };
    _ = landSmash(&player, 10.0, true, .none);
    try std.testing.expectEqual(@as(f32, -8.0), player.vertical_velocity);
}

test "solid ground contact resets combo count" {
    var player = PlayerState{ .combo_count = 3 };
    onGroundContact(&player);
    try std.testing.expectEqual(@as(u32, 0), player.combo_count);
}

test "combo after ground contact starts at one again" {
    var player = PlayerState{ .combo_count = 3 };
    onGroundContact(&player);
    const outcome = landSmash(&player, 1.5, true, .none);
    try std.testing.expectEqual(@as(u32, 1), outcome.combo_count);
    try std.testing.expectEqual(@as(f32, 1.0), outcome.damage_multiplier);
}

test "successful smash negates accumulated fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 9.0 };
    const outcome = landSmash(&player, 10.0, true, .none);
    try std.testing.expect(outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 0.0), player.accumulated_fall_damage);
}

test "one hundred meter successful smash negates all fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 1000.0 };
    const outcome = landSmash(&player, 100.0, true, .three);
    try std.testing.expect(outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 0.0), player.accumulated_fall_damage);
}

test "very large successful smash negates all fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 5000.0 };
    const outcome = landSmash(&player, 1000.0, true, .none);
    try std.testing.expect(outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 0.0), player.accumulated_fall_damage);
}

test "failed smash preserves accumulated fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 42.0 };
    const outcome = landSmash(&player, 100.0, false, .three);
    try std.testing.expect(!outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 42.0), player.accumulated_fall_damage);
}

test "subthreshold hit preserves accumulated fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 2.0 };
    const outcome = landSmash(&player, 1.0, true, .three);
    try std.testing.expect(!outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 2.0), player.accumulated_fall_damage);
}

test "shockwave has maximum base force at zero distance" {
    const effect = shockwaveEffect(0.0, 0, false).?;
    try std.testing.expectEqual(@as(f32, 1.5), effect.knockback_force);
}

test "shockwave force falls off linearly at half radius" {
    const effect = shockwaveEffect(1.75, 0, false).?;
    try std.testing.expectEqual(@as(f32, 0.75), effect.knockback_force);
}

test "shockwave has no horizontal force at the radius edge" {
    const effect = shockwaveEffect(3.5, 0, false).?;
    try std.testing.expectEqual(@as(f32, 0.0), effect.knockback_force);
}

test "shockwave excludes entities beyond three point five meters" {
    try std.testing.expect(shockwaveEffect(3.5001, 0, false) == null);
}

test "shockwave excludes primary target" {
    try std.testing.expect(shockwaveEffect(1.0, 1, true) == null);
}

test "shockwave excludes negative distance" {
    try std.testing.expect(shockwaveEffect(-0.1, 0, false) == null);
}

test "shockwave excludes nonfinite distance" {
    try std.testing.expect(shockwaveEffect(std.math.nan(f32), 0, false) == null);
}

test "shockwave combo one force is two at zero distance" {
    const effect = shockwaveEffect(0.0, 1, false).?;
    try std.testing.expectEqual(@as(f32, 2.0), effect.knockback_force);
}

test "shockwave force grows with combo count" {
    const first = shockwaveEffect(1.0, 1, false).?;
    const third = shockwaveEffect(1.0, 3, false).?;
    try std.testing.expect(third.knockback_force > first.knockback_force);
}

test "shockwave applies vertical pop of three point five meters per second" {
    const effect = shockwaveEffect(2.0, 2, false).?;
    try std.testing.expectEqual(@as(f32, 3.5), effect.vertical_velocity);
}

test "shockwave vertical pop is independent of distance" {
    const near = shockwaveEffect(0.0, 0, false).?;
    const edge = shockwaveEffect(3.5, 0, false).?;
    try std.testing.expectEqual(near.vertical_velocity, edge.vertical_velocity);
}

test "1: smash minimum fall distance constant is 1.5" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), SMASH_MIN_FALL_DISTANCE, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), smash_min_fall_distance, 0.0001);
}

test "2: base weapon damage is 6.0" {
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), BASE_DAMAGE, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), base_damage, 0.0001);
}

test "3: isSmashAttack returns false for sub-1.5m falls" {
    try std.testing.expect(!isSmashAttack(0.0));
    try std.testing.expect(!isSmashAttack(0.5));
    try std.testing.expect(!isSmashAttack(1.0));
    try std.testing.expect(!isSmashAttack(1.49));
    try std.testing.expect(!isSmashAttack(1.4999));
}

test "4: isSmashAttack returns true at exactly 1.5m threshold" {
    try std.testing.expect(isSmashAttack(1.5));
}

test "5: isSmashAttack returns true for falls above 1.5m" {
    try std.testing.expect(isSmashAttack(1.51));
    try std.testing.expect(isSmashAttack(2.0));
    try std.testing.expect(isSmashAttack(3.0));
    try std.testing.expect(isSmashAttack(5.0));
    try std.testing.expect(isSmashAttack(10.0));
    try std.testing.expect(isSmashAttack(100.0));
}

test "6: calculateKineticDamage returns base damage 6.0 for sub-threshold fall" {
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), calculateKineticDamage(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), calculateKineticDamage(0.75), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), calculateKineticDamage(1.49), 0.0001);
}

test "7: raw height scaling formula direct verification" {
    // formula: 6.0 + 4.0 * min(h, 3.0) + 2.0 * max(0.0, h - 3.0)
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), calculateRawHeightScaling(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), calculateRawHeightScaling(1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), calculateRawHeightScaling(1.5), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 18.0), calculateRawHeightScaling(3.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 22.0), calculateRawHeightScaling(5.0), 0.0001);
}

test "8: two-tier kinetic scaling first tier at 1.5m is 12.0" {
    // 6.0 + 4.0 * 1.5 + 2.0 * 0.0 = 12.0
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), calculateKineticDamage(1.5), 0.0001);
}

test "9: two-tier kinetic scaling first tier at 2.0m is 14.0" {
    // 6.0 + 4.0 * 2.0 + 2.0 * 0.0 = 14.0
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), calculateKineticDamage(2.0), 0.0001);
}

test "10: two-tier kinetic scaling boundary at 3.0m is 18.0" {
    // 6.0 + 4.0 * 3.0 + 2.0 * 0.0 = 18.0
    try std.testing.expectApproxEqAbs(@as(f32, 18.0), calculateKineticDamage(3.0), 0.0001);
}

test "11: two-tier kinetic scaling second tier at 4.0m is 20.0" {
    // 6.0 + 4.0 * 3.0 + 2.0 * 1.0 = 20.0
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), calculateKineticDamage(4.0), 0.0001);
}

test "12: two-tier kinetic scaling second tier at 5.0m is 22.0" {
    // 6.0 + 4.0 * 3.0 + 2.0 * 2.0 = 22.0
    try std.testing.expectApproxEqAbs(@as(f32, 22.0), calculateKineticDamage(5.0), 0.0001);
}

test "13: two-tier kinetic scaling second tier at 10.0m is 32.0" {
    // 6.0 + 12.0 + 2.0 * 7.0 = 32.0
    try std.testing.expectApproxEqAbs(@as(f32, 32.0), calculateKineticDamage(10.0), 0.0001);
}

test "14: two-tier kinetic scaling second tier at 20.0m is 52.0" {
    // 6.0 + 12.0 + 2.0 * 17.0 = 52.0
    try std.testing.expectApproxEqAbs(@as(f32, 52.0), calculateKineticDamage(20.0), 0.0001);
}

test "15: two-tier kinetic scaling fractional fall heights" {
    // h = 1.75: 6.0 + 4.0 * 1.75 = 13.0
    try std.testing.expectApproxEqAbs(@as(f32, 13.0), calculateKineticDamage(1.75), 0.0001);
    // h = 3.5: 6.0 + 12.0 + 2.0 * 0.5 = 19.0
    try std.testing.expectApproxEqAbs(@as(f32, 19.0), calculateKineticDamage(3.5), 0.0001);
}

test "16: density 0 adds no bonus damage" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), calculateDensityBonus(5.0, 0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), calculateDensityBonus(100.0, 0), 0.0001);
}

test "17: density I adds 0.5 damage per meter fallen" {
    // +0.5 * 1 * h
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), calculateDensityBonus(2.0, 1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), calculateDensityBonus(5.0, 1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), calculateDensityBonus(10.0, 1), 0.0001);
}

test "18: density II adds 1.0 damage per meter fallen" {
    // +0.5 * 2 * h = 1.0 * h
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), calculateDensityBonus(2.0, 2), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), calculateDensityBonus(5.0, 2), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), calculateDensityBonus(10.0, 2), 0.0001);
}

test "19: density III adds 1.5 damage per meter fallen" {
    // +0.5 * 3 * h = 1.5 * h
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), calculateDensityBonus(2.0, 3), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), calculateDensityBonus(5.0, 3), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), calculateDensityBonus(10.0, 3), 0.0001);
}

test "20: density IV adds 2.0 damage per meter fallen" {
    // +0.5 * 4 * h = 2.0 * h
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), calculateDensityBonus(2.0, 4), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), calculateDensityBonus(5.0, 4), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), calculateDensityBonus(10.0, 4), 0.0001);
}

test "21: density V adds 2.5 damage per meter fallen" {
    // +0.5 * 5 * h = 2.5 * h
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), calculateDensityBonus(2.0, 5), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.5), calculateDensityBonus(5.0, 5), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), calculateDensityBonus(10.0, 5), 0.0001);
}

test "22: density level is clamped to level V" {
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), calculateDensityBonus(10.0, 6), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), calculateDensityBonus(10.0, 7), 0.0001);
}

test "23: density bonus with zero or negative fall distance is 0.0" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), calculateDensityBonus(0.0, 5), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), calculateDensityBonus(-5.0, 5), 0.0001);
}

test "24: calculateSmashDamage combines kinetic scaling and density" {
    // at h = 5.0, density V: kinetic = 22.0, density = 12.5 -> total = 34.5
    try std.testing.expectApproxEqAbs(@as(f32, 34.5), calculateSmashDamage(5.0, 5), 0.0001);
    // at h = 1.0 (sub-threshold), returns base damage 6.0
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), calculateSmashDamage(1.0, 5), 0.0001);
}

test "25: breach 0 applies no armor reduction" {
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), calculateEffectiveArmor(20.0, 0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), breachReductionRatio(0), 0.0001);
}

test "26: breach I reduces effective armor by 15%" {
    // 20.0 * (1.0 - 0.15) = 17.0
    try std.testing.expectApproxEqAbs(@as(f32, 17.0), calculateEffectiveArmor(20.0, 1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.15), breachReductionRatio(1), 0.0001);
}

test "27: breach II reduces effective armor by 30%" {
    // 20.0 * (1.0 - 0.30) = 14.0
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), calculateEffectiveArmor(20.0, 2), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), breachReductionRatio(2), 0.0001);
}

test "28: breach III reduces effective armor by 45%" {
    // 20.0 * (1.0 - 0.45) = 11.0
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), calculateEffectiveArmor(20.0, 3), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.45), breachReductionRatio(3), 0.0001);
}

test "29: breach IV reduces effective armor by 60%" {
    // 20.0 * (1.0 - 0.60) = 8.0
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), calculateEffectiveArmor(20.0, 4), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), breachReductionRatio(4), 0.0001);
}

test "30: breach level is clamped to level IV" {
    // level 5 clamped to level 4: 60%
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), calculateEffectiveArmor(20.0, 5), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), breachReductionRatio(5), 0.0001);
}

test "31: breach armor points never drop below zero" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), calculateEffectiveArmor(0.0, 4), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), calculateEffectiveArmor(-5.0, 4), 0.0001);
}

test "32: wind burst level none impulse is 0.0 m/s" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), WindBurstLevel.none.impulse(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getWindBurstImpulse(.none), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getWindBurstImpulseFromInt(0), 0.0001);
}

test "33: wind burst I impulse is +7.0 m/s" {
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), WIND_BURST_I_VELOCITY, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), WindBurstLevel.one.impulse(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), getWindBurstImpulse(.one), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), getWindBurstImpulseFromInt(1), 0.0001);
}

test "34: wind burst II impulse is +10.0 m/s" {
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), WIND_BURST_II_VELOCITY, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), WindBurstLevel.two.impulse(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), getWindBurstImpulse(.two), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), getWindBurstImpulseFromInt(2), 0.0001);
}

test "35: wind burst III impulse is +13.0 m/s" {
    try std.testing.expectApproxEqAbs(@as(f32, 13.0), WIND_BURST_III_VELOCITY, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 13.0), WindBurstLevel.three.impulse(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 13.0), getWindBurstImpulse(.three), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 13.0), getWindBurstImpulseFromInt(3), 0.0001);
}

test "36: combo multiplier for combo 0 is 1.0x baseline" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), calculateComboMultiplier(0), 0.0001);
}

test "37: combo multiplier for combo 1 is 1.0x" {
    // 1.0 + 0.25 * 0 = 1.0
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), calculateComboMultiplier(1), 0.0001);
}

test "38: combo multiplier for combo 2 is 1.25x" {
    // 1.0 + 0.25 * 1 = 1.25
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), calculateComboMultiplier(2), 0.0001);
}

test "39: combo multiplier for combo 3 is 1.50x" {
    // 1.0 + 0.25 * 2 = 1.50
    try std.testing.expectApproxEqAbs(@as(f32, 1.50), calculateComboMultiplier(3), 0.0001);
}

test "40: combo multiplier for combo 4 is 1.75x" {
    // 1.0 + 0.25 * 3 = 1.75
    try std.testing.expectApproxEqAbs(@as(f32, 1.75), calculateComboMultiplier(4), 0.0001);
}

test "41: combo multiplier for combo 5 is 2.00x" {
    // 1.0 + 0.25 * 4 = 2.00
    try std.testing.expectApproxEqAbs(@as(f32, 2.00), calculateComboMultiplier(5), 0.0001);
}

test "42: combo multiplier caps at 2.0x for combo 6 and above" {
    try std.testing.expectApproxEqAbs(@as(f32, 2.00), calculateComboMultiplier(6), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.00), calculateComboMultiplier(10), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.00), calculateComboMultiplier(100), 0.0001);
}

test "43: ground contact resets combo count to 0" {
    var tracker = MaceComboTracker{
        .combo_count = 4,
        .is_grounded = false,
        .vertical_velocity = 8.5,
    };
    try std.testing.expectEqual(@as(u32, 4), tracker.combo_count);

    tracker.onGroundContact();
    try std.testing.expectEqual(@as(u32, 0), tracker.combo_count);
    try std.testing.expect(tracker.is_grounded);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tracker.vertical_velocity, 0.0001);
}

test "44: airborne chain preserves combo count until ground contact" {
    var tracker = MaceComboTracker{};
    tracker.onTakeoff();

    // Smash 1
    const res1 = executeAttack(&tracker, 2.0, true, .{});
    try std.testing.expect(res1.is_smash);
    try std.testing.expectEqual(@as(u32, 1), tracker.combo_count);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tracker.currentMultiplier(), 0.0001);

    // Smash 2 without touching ground
    const res2 = executeAttack(&tracker, 3.0, true, .{});
    try std.testing.expect(res2.is_smash);
    try std.testing.expectEqual(@as(u32, 2), tracker.combo_count);
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), tracker.currentMultiplier(), 0.0001);

    // Smash 3 without touching ground
    const res3 = executeAttack(&tracker, 4.0, true, .{});
    try std.testing.expect(res3.is_smash);
    try std.testing.expectEqual(@as(u32, 3), tracker.combo_count);
    try std.testing.expectApproxEqAbs(@as(f32, 1.50), tracker.currentMultiplier(), 0.0001);

    // Touch ground -> reset
    tracker.onGroundContact();
    try std.testing.expectEqual(@as(u32, 0), tracker.combo_count);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), tracker.currentMultiplier(), 0.0001);
}

test "45: 100m fall damage completely canceled on successful smash" {
    var tracker = MaceComboTracker{};
    tracker.onTakeoff();
    tracker.addFallDistance(100.0);

    // 100m unmitigated fall damage would be 97.0
    try std.testing.expectApproxEqAbs(@as(f32, 97.0), tracker.accumulated_fall_damage, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), tracker.accumulated_fall_distance, 0.0001);

    const outcome = executeAttack(&tracker, 100.0, true, .{});
    try std.testing.expect(outcome.is_smash);
    try std.testing.expect(outcome.fall_damage_canceled);
    try std.testing.expectApproxEqAbs(@as(f32, 97.0), outcome.prior_fall_damage, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tracker.accumulated_fall_damage, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tracker.accumulated_fall_distance, 0.0001);
}

test "46: extreme 1000m fall damage canceled on successful smash" {
    var tracker = MaceComboTracker{};
    tracker.onTakeoff();
    tracker.addFallDistance(1000.0);

    try std.testing.expectApproxEqAbs(@as(f32, 997.0), tracker.accumulated_fall_damage, 0.0001);

    const outcome = executeAttack(&tracker, 1000.0, true, .{});
    try std.testing.expect(outcome.is_smash);
    try std.testing.expect(outcome.fall_damage_canceled);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tracker.accumulated_fall_damage, 0.0001);
}

test "47: sub-threshold fall does not cancel fall damage or increment combo" {
    var tracker = MaceComboTracker{};
    tracker.onTakeoff();
    tracker.addFallDistance(1.4);

    const outcome = executeAttack(&tracker, 1.4, true, .{});
    try std.testing.expect(!outcome.is_smash);
    try std.testing.expect(!outcome.fall_damage_canceled);
    try std.testing.expectEqual(@as(u32, 0), tracker.combo_count);
}

test "48: missed smash does not cancel fall damage or increment combo" {
    var tracker = MaceComboTracker{};
    tracker.onTakeoff();
    tracker.addFallDistance(10.0);

    const outcome = executeAttack(&tracker, 10.0, false, .{});
    try std.testing.expect(!outcome.is_smash);
    try std.testing.expect(!outcome.fall_damage_canceled);
    try std.testing.expectEqual(@as(u32, 0), tracker.combo_count);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), tracker.accumulated_fall_damage, 0.0001);
}

test "49: chained aerial smash execution with Wind Burst III and combo compounding" {
    var tracker = MaceComboTracker{};
    tracker.onTakeoff();

    // Hit 1: fall 2m, Wind Burst III
    // base damage: 6.0 + 4*2.0 = 14.0. Combo 1 mult = 1.0x -> 14.0
    const hit1 = executeAttack(&tracker, 2.0, true, .{
        .wind_burst_level = .three,
    });
    try std.testing.expect(hit1.is_smash);
    try std.testing.expectEqual(@as(u32, 1), hit1.combo_count);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), hit1.combo_multiplier, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), hit1.final_damage, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 13.0), tracker.vertical_velocity, 0.0001);
    try std.testing.expect(!tracker.is_grounded);

    // Hit 2: fall 3m from the bounce, Wind Burst III
    // base damage: 6.0 + 4*3.0 = 18.0. Combo 2 mult = 1.25x -> 18.0 * 1.25 = 22.5
    const hit2 = executeAttack(&tracker, 3.0, true, .{
        .wind_burst_level = .three,
    });
    try std.testing.expect(hit2.is_smash);
    try std.testing.expectEqual(@as(u32, 2), hit2.combo_count);
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), hit2.combo_multiplier, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 22.5), hit2.final_damage, 0.0001);

    // Hit 3: fall 5m from another bounce, Wind Burst III
    // base damage: 6.0 + 12 + 2*2 = 22.0. Combo 3 mult = 1.50x -> 22.0 * 1.50 = 33.0
    const hit3 = executeAttack(&tracker, 5.0, true, .{
        .wind_burst_level = .three,
    });
    try std.testing.expect(hit3.is_smash);
    try std.testing.expectEqual(@as(u32, 3), hit3.combo_count);
    try std.testing.expectApproxEqAbs(@as(f32, 1.50), hit3.combo_multiplier, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 33.0), hit3.final_damage, 0.0001);
}

test "50: combined smash attack calculation with Density V, Breach IV, and Combo 5" {
    var tracker = MaceComboTracker{ .combo_count = 4 }; // next hit is combo 5
    tracker.onTakeoff();
    tracker.addFallDistance(10.0);

    // fall = 10m:
    // kinetic: 6 + 4*3 + 2*7 = 32.0
    // density V (5): 0.5 * 5 * 10 = 25.0
    // pre_combo: 32.0 + 25.0 = 57.0
    // combo 5: multiplier = 2.0x
    // final damage: 57.0 * 2.0 = 114.0
    // target armor: 20.0
    // breach IV: 60% reduction -> effective armor = 8.0 (reduction = 0.60)
    // wind burst II: impulse = 10.0 m/s
    const result = executeAttack(&tracker, 10.0, true, .{
        .density_level = 5,
        .breach_level = 4,
        .wind_burst_level = .two,
        .target_armor = 20.0,
    });

    try std.testing.expect(result.is_smash);
    try std.testing.expectEqual(@as(u32, 5), result.combo_count);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), result.combo_multiplier, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 32.0), result.base_kinetic_damage, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), result.density_bonus, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 57.0), result.pre_combo_damage, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 114.0), result.final_damage, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), result.target_armor_original, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), result.target_armor_effective, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), result.breach_reduction, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), result.wind_burst_launch_speed, 0.0001);
    try std.testing.expect(result.fall_damage_canceled);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), result.prior_fall_damage, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tracker.accumulated_fall_damage, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), tracker.vertical_velocity, 0.0001);
}
