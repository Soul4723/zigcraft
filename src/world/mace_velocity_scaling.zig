const std = @import("std");

/// Base weapon damage of the mace without any fall velocity kinetic scaling.
pub const BASE_DAMAGE: f32 = 6.0;
pub const base_damage: f32 = BASE_DAMAGE;

/// Minimum fall distance in meters required to activate a smash attack.
pub const SMASH_MIN_FALL_DISTANCE: f32 = 1.5;
pub const smash_min_fall_distance: f32 = SMASH_MIN_FALL_DISTANCE;

/// Threshold height for the first tier of kinetic damage scaling (meters).
pub const FIRST_TIER_HEIGHT_LIMIT: f32 = 3.0;

/// Damage added per meter fallen in the first tier (0 <= h <= 3.0).
pub const FIRST_TIER_DAMAGE_RATE: f32 = 4.0;

/// Damage added per meter fallen in the second tier (h > 3.0).
pub const SECOND_TIER_DAMAGE_RATE: f32 = 2.0;

/// Maximum combo damage multiplier cap.
pub const MAX_COMBO_MULTIPLIER: f32 = 2.0;
pub const max_combo_multiplier: f32 = MAX_COMBO_MULTIPLIER;

/// Multiplier step added per consecutive aerial smash hit.
pub const COMBO_MULTIPLIER_STEP: f32 = 0.25;

/// Density enchantment damage multiplier per level per meter fallen.
pub const DENSITY_FACTOR_PER_LEVEL: f32 = 0.5;

/// Maximum Density enchantment level supported (I-V).
pub const MAX_DENSITY_LEVEL: u3 = 5;

/// Breach enchantment armor reduction fraction per level.
pub const BREACH_REDUCTION_PER_LEVEL: f32 = 0.15;

/// Maximum Breach enchantment level supported (I-IV).
pub const MAX_BREACH_LEVEL: u3 = 4;

/// Wind Burst vertical launch speeds (meters per second).
pub const WIND_BURST_I_VELOCITY: f32 = 7.0;
pub const WIND_BURST_II_VELOCITY: f32 = 10.0;
pub const WIND_BURST_III_VELOCITY: f32 = 13.0;

/// Mace durability standard.
pub const DURABILITY: u16 = 500;

/// Wind Burst enchantment levels.
pub const WindBurstLevel = enum(u3) {
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

/// Determines if a given falling height qualifies as a smash attack.
pub fn isSmashAttack(fall_distance: f32) bool {
    return fall_distance >= SMASH_MIN_FALL_DISTANCE;
}

/// Evaluates raw height scaling formula directly:
/// `damage = base_damage (6.0) + 4.0 * @min(h, 3.0) + 2.0 * @max(0.0, h - 3.0)`
pub fn calculateRawHeightScaling(h: f32) f32 {
    const height = @max(0.0, h);
    return BASE_DAMAGE + FIRST_TIER_DAMAGE_RATE * @min(height, FIRST_TIER_HEIGHT_LIMIT) +
        SECOND_TIER_DAMAGE_RATE * @max(0.0, height - FIRST_TIER_HEIGHT_LIMIT);
}

/// Computes the un-enchanted kinetic smash damage based on fall height `h`.
/// Formula: `damage = base_damage (6.0) + 4.0 * @min(h, 3.0) + 2.0 * @max(0.0, h - 3.0)`
/// If `h < SMASH_MIN_FALL_DISTANCE`, standard base damage (6.0) is returned.
pub fn calculateKineticDamage(fall_distance: f32) f32 {
    if (!isSmashAttack(fall_distance)) {
        return BASE_DAMAGE;
    }
    return calculateRawHeightScaling(fall_distance);
}

/// Density Enchantment (I–V): adds `+0.5 * level * h` extra damage per meter fallen.
/// Level is clamped between 0 and 5.
pub fn calculateDensityBonus(fall_distance: f32, level: u3) f32 {
    const clamped_level = @min(level, MAX_DENSITY_LEVEL);
    const h = @max(0.0, fall_distance);
    return DENSITY_FACTOR_PER_LEVEL * @as(f32, @floatFromInt(clamped_level)) * h;
}

/// Total smash damage combining kinetic scaling and Density bonus before combo multipliers.
pub fn calculateSmashDamage(fall_distance: f32, density_level: u3) f32 {
    if (!isSmashAttack(fall_distance)) {
        return BASE_DAMAGE;
    }
    const kinetic = calculateKineticDamage(fall_distance);
    const density_bonus = calculateDensityBonus(fall_distance, density_level);
    return kinetic + density_bonus;
}

/// Breach Enchantment (I–IV): reduces target's effective armor points by `0.15 * level`
/// (up to 60% armor reduction at Breach IV). Effective armor points cannot fall below 0.
pub fn calculateEffectiveArmor(armor_points: f32, breach_level: u3) f32 {
    const clamped_level = @min(breach_level, MAX_BREACH_LEVEL);
    const reduction_ratio = BREACH_REDUCTION_PER_LEVEL * @as(f32, @floatFromInt(clamped_level));
    const effective = armor_points * (1.0 - reduction_ratio);
    return @max(0.0, effective);
}

/// Armor reduction fraction for a given Breach level (0.0 to 0.60).
pub fn breachReductionRatio(breach_level: u3) f32 {
    const clamped_level = @min(breach_level, MAX_BREACH_LEVEL);
    return BREACH_REDUCTION_PER_LEVEL * @as(f32, @floatFromInt(clamped_level));
}

/// Upward velocity impulse provided by Wind Burst enchantment upon successful smash.
pub fn getWindBurstImpulse(level: WindBurstLevel) f32 {
    return level.impulse();
}

/// Upward velocity impulse helper by integer level (0..3).
pub fn getWindBurstImpulseFromInt(level: u3) f32 {
    return switch (level) {
        0 => 0.0,
        1 => WIND_BURST_I_VELOCITY,
        2 => WIND_BURST_II_VELOCITY,
        else => WIND_BURST_III_VELOCITY,
    };
}

/// Aerial combo multiplier:
/// Consecutive smashes without touching ground increment combo (`combo_count` = 1, 2, 3, ...):
/// `damage_multiplier = 1.0 + 0.25 * @as(f32, @floatFromInt(combo_count - 1))`
/// Capped at 2.0x multiplier.
/// When `combo_count == 0`, baseline 1.0x is returned.
pub fn calculateComboMultiplier(combo_count: u32) f32 {
    if (combo_count == 0) return 1.0;
    const mult = 1.0 + COMBO_MULTIPLIER_STEP * @as(f32, @floatFromInt(combo_count - 1));
    return @min(mult, MAX_COMBO_MULTIPLIER);
}

/// Calculates vanilla Minecraft-style fall damage: max(0.0, height - 3.0).
pub fn calculateUnmitigatedFallDamage(fall_distance: f32) f32 {
    return @max(0.0, fall_distance - 3.0);
}

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
        // Attack failed or did not meet smash height threshold.
        // Combo is NOT incremented; fall damage is NOT canceled.
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

    // Successful smash attack!
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
// UNIT TESTS (50 tests covering all specifications & edge cases)
// =========================================================================

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
