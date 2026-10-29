const std = @import("std");

pub const base_damage: f32 = 6.0;
pub const attack_speed: f32 = 0.6;
pub const attack_cooldown_seconds: f32 = 1.0 / attack_speed;
pub const attack_cooldown_ticks: u8 = 33;
pub const durability: u16 = 500;
pub const smash_min_fall_distance: f32 = 1.5;
pub const shockwave_radius: f32 = 2.5;
pub const resetFallOnSmash = true;

pub const ExclusiveEnchantment = enum { none, density, breach };
pub const WindBurstLevel = enum(u2) { none = 0, one = 1, two = 2, three = 3 };
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

pub fn isSmashAttack(fall_distance: f32) bool {
    return fall_distance >= smash_min_fall_distance;
}

pub fn calculateSmashDamage(fall_distance: f32, density_level: u3) f32 {
    if (!isSmashAttack(fall_distance)) return base_damage;
    const h = @max(0.0, fall_distance);
    const base_fall = 4.0 * @min(h, 3.0) + 2.0 * @max(h - 3.0, 0.0);
    const density_bonus = 0.5 * @as(f32, @floatFromInt(@min(density_level, 5))) * h;
    return base_damage + base_fall + density_bonus;
}

pub fn densityDamageBonus(fall_distance: f32, level: u3) f32 {
    return 0.5 * @as(f32, @floatFromInt(@min(level, 5))) * @max(0.0, fall_distance);
}

pub fn effectiveArmorDefense(armor_points: f32, breach_level: u3) f32 {
    const reduction = 0.15 * @as(f32, @floatFromInt(@min(breach_level, 4)));
    return @max(0.0, armor_points * (1.0 - reduction));
}

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
    return switch (level) {
        .none => 0.0,
        .one => 7.0,
        .two => 10.0,
        .three => 13.0,
    };
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
