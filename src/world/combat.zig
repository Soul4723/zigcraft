const std = @import("std");

pub const wolf_bite_damage: f32 = 2.0;
pub const wolf_bite_cooldown: f32 = 1.0;
pub const wolf_bite_range_sq: f32 = 1.44;
pub const wolf_bite_height: f32 = 2.0;
pub const melee_cooldown: f32 = 0.35;
pub const melee_range: f32 = 4.0;
pub const sword_damage: u8 = 2;
pub const stone_sword_damage: u8 = 2;
pub const golden_sword_damage: u8 = 2;
pub const diamond_sword_damage: u8 = 3;
pub const netherite_sword_damage: u8 = 4;
pub const hand_damage: u8 = 1;

pub const golden_armor_absorption: f32 = 0.15; // 15% golden chestplate reduction
pub const golden_full_set_absorption: f32 = 0.35; // 35% golden 4-piece set reduction
pub const iron_armor_absorption: f32 = 0.25; // 25% iron chestplate reduction
pub const iron_full_set_absorption: f32 = 0.50; // 50% iron 4-piece set reduction
pub const diamond_armor_absorption: f32 = 0.40; // 40% diamond chestplate reduction
pub const diamond_full_set_absorption: f32 = 0.65; // 65% diamond 4-piece set reduction
pub const netherite_armor_absorption: f32 = 0.50; // 50% chestplate reduction
pub const netherite_full_set_absorption: f32 = 0.75; // 75% complete 4-piece set reduction

pub fn applyArmorReduction(raw_damage: f32, has_netherite_armor: bool) f32 {
    return applyArmorReductionFullSet(raw_damage, has_netherite_armor, false);
}

pub fn applyArmorReductionFullSet(raw_damage: f32, has_netherite_armor: bool, has_full_set: bool) f32 {
    return applyArmorReductionTier(raw_damage, has_netherite_armor, has_full_set, false, false);
}

pub fn applyArmorReductionTier(raw_damage: f32, has_netherite_armor: bool, has_full_netherite: bool, has_diamond_armor: bool, has_full_diamond: bool) f32 {
    return applyArmorReductionFullTiers(raw_damage, has_netherite_armor, has_full_netherite, has_diamond_armor, has_full_diamond, false, false);
}

pub fn applyArmorReductionFullTiers(raw_damage: f32, has_netherite_armor: bool, has_full_netherite: bool, has_diamond_armor: bool, has_full_diamond: bool, has_iron_armor: bool, has_full_iron: bool) f32 {
    return applyArmorReductionAllTiers(raw_damage, has_netherite_armor, has_full_netherite, has_diamond_armor, has_full_diamond, has_iron_armor, has_full_iron, false, false);
}

pub fn applyArmorReductionAllTiers(raw_damage: f32, has_netherite_armor: bool, has_full_netherite: bool, has_diamond_armor: bool, has_full_diamond: bool, has_iron_armor: bool, has_full_iron: bool, has_golden_armor: bool, has_full_golden: bool) f32 {
    if (has_full_netherite) {
        return raw_damage * (1.0 - netherite_full_set_absorption);
    } else if (has_netherite_armor) {
        return raw_damage * (1.0 - netherite_armor_absorption);
    } else if (has_full_diamond) {
        return raw_damage * (1.0 - diamond_full_set_absorption);
    } else if (has_diamond_armor) {
        return raw_damage * (1.0 - diamond_armor_absorption);
    } else if (has_full_iron) {
        return raw_damage * (1.0 - iron_full_set_absorption);
    } else if (has_iron_armor) {
        return raw_damage * (1.0 - iron_armor_absorption);
    } else if (has_full_golden) {
        return raw_damage * (1.0 - golden_full_set_absorption);
    } else if (has_golden_armor) {
        return raw_damage * (1.0 - golden_armor_absorption);
    }
    return raw_damage;
}

pub const netherite_knockback_resistance: f32 = 0.60; // 60% knockback reduction

pub fn applyKnockbackResistance(raw_knockback: f32, has_netherite_leggings: bool) f32 {
    if (has_netherite_leggings) {
        return raw_knockback * (1.0 - netherite_knockback_resistance);
    }
    return raw_knockback;
}

pub fn inBiteRange(dx: f32, dz: f32, dy: f32) bool {
    return dx * dx + dz * dz < wolf_bite_range_sq and @abs(dy) < wolf_bite_height;
}

pub fn tickCooldown(cd: f32, dt: f32) f32 {
    return @max(0.0, cd - dt);
}

pub fn weaponDamage(is_netherite: bool, is_iron: bool) u8 {
    return weaponDamageTier(is_netherite, false, is_iron);
}

pub fn weaponDamageTier(is_netherite: bool, is_diamond: bool, is_iron: bool) u8 {
    return weaponDamageAllTiers(is_netherite, is_diamond, is_iron, false);
}

pub fn weaponDamageAllTiers(is_netherite: bool, is_diamond: bool, is_iron: bool, is_stone: bool) u8 {
    return weaponDamageEveryTier(is_netherite, is_diamond, is_iron, is_stone, false);
}

pub fn weaponDamageEveryTier(is_netherite: bool, is_diamond: bool, is_iron: bool, is_stone: bool, is_golden: bool) u8 {
    if (is_netherite) return netherite_sword_damage;
    if (is_diamond) return diamond_sword_damage;
    if (is_iron) return sword_damage;
    if (is_stone) return stone_sword_damage;
    if (is_golden) return golden_sword_damage;
    return hand_damage;
}

pub fn calculatePlayerAttackDamage(is_netherite: bool, is_iron: bool, is_weakened: bool) u8 {
    return calculatePlayerAttackDamageTier(is_netherite, false, is_iron, is_weakened);
}

pub fn calculatePlayerAttackDamageTier(is_netherite: bool, is_diamond: bool, is_iron: bool, is_weakened: bool) u8 {
    return calculatePlayerAttackDamageAllTiers(is_netherite, is_diamond, is_iron, false, is_weakened);
}

pub fn calculatePlayerAttackDamageAllTiers(is_netherite: bool, is_diamond: bool, is_iron: bool, is_stone: bool, is_weakened: bool) u8 {
    return calculatePlayerAttackDamageEveryTier(is_netherite, is_diamond, is_iron, is_stone, false, is_weakened);
}

pub fn calculatePlayerAttackDamageEveryTier(is_netherite: bool, is_diamond: bool, is_iron: bool, is_stone: bool, is_golden: bool, is_weakened: bool) u8 {
    const raw = weaponDamageEveryTier(is_netherite, is_diamond, is_iron, is_stone, is_golden);
    if (is_weakened) {
        // Weakness reduces attack potency by 2 damage, floor of 1
        return if (raw > 2) raw - 2 else 1;
    }
    return raw;
}

pub fn meleeDamage(is_sword: bool) u8 {
    return weaponDamage(false, is_sword);
}

pub fn wolfDamage(base: f32, pack_bonus: f32) f32 {
    return base + pack_bonus;
}


test "bite range box" {
    try std.testing.expect(inBiteRange(0, 0, 0));
    try std.testing.expect(inBiteRange(1.0, 0.5, 1.0));
    try std.testing.expect(!inBiteRange(2.0, 0, 0));
    try std.testing.expect(!inBiteRange(0, 0, 2.5));
}

test "cooldown ticks down and clamps" {
    try std.testing.expectEqual(tickCooldown(1.0, 0.4), @as(f32, 0.6));
    try std.testing.expectEqual(tickCooldown(0.2, 0.5), @as(f32, 0.0));
}

test "melee damage tiers" {
    try std.testing.expectEqual(meleeDamage(true), @as(u8, 2));
    try std.testing.expectEqual(meleeDamage(false), @as(u8, 1));
    try std.testing.expectEqual(weaponDamage(true, false), @as(u8, 4));
    try std.testing.expectEqual(weaponDamage(false, true), @as(u8, 2));
    try std.testing.expectEqual(weaponDamage(false, false), @as(u8, 1));
}

test "wolf damage calculation with pack bonus" {
    try std.testing.expectEqual(wolfDamage(wolf_bite_damage, 0.0), 2.0);
    try std.testing.expectEqual(wolfDamage(wolf_bite_damage, 1.5), 3.5);
}

pub const WolfAttackHit = struct {
    damage: f32,
    knockback_x: f32,
    knockback_z: f32,
};

pub fn calculateWolfBite(bdx: f32, bdz: f32, pack_bonus: f32) WolfAttackHit {
    const bl = @max(0.5, @sqrt(bdx * bdx + bdz * bdz));
    return .{
        .damage = wolfDamage(wolf_bite_damage, pack_bonus),
        .knockback_x = (bdx / bl) * 0.6,
        .knockback_z = (bdz / bl) * 0.6,
    };
}

test "calculateWolfBite knockback and damage" {
    const hit = calculateWolfBite(3.0, 4.0, 1.0);
    try std.testing.expectEqual(wolf_bite_damage + 1.0, hit.damage);
    try std.testing.expectApproxEqAbs(@as(f32, 0.36), hit.knockback_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.48), hit.knockback_z, 0.001);

    // Test zero-distance clamping to 0.5 to avoid division by zero
    const hit_zero = calculateWolfBite(0.0, 0.0, 0.0);
    try std.testing.expectEqual(wolf_bite_damage, hit_zero.damage);
    try std.testing.expectEqual(@as(f32, 0.0), hit_zero.knockback_x);
    try std.testing.expectEqual(@as(f32, 0.0), hit_zero.knockback_z);
}

test "fireball burn application" {
    // Fireball deals flat damage; fire resistance handled at player effect layer.
    try std.testing.expectEqual(@as(f32, 3.0), @import("projectile.zig").fireball_damage);
}

test "applyArmorReduction absorbs 50% damage with netherite chestplate" {
    try std.testing.expectApproxEqAbs(applyArmorReduction(10.0, true), 5.0, 0.01);
    try std.testing.expectApproxEqAbs(applyArmorReduction(4.0, true), 2.0, 0.01);
    try std.testing.expectApproxEqAbs(applyArmorReduction(10.0, false), 10.0, 0.01);
}

test "applyKnockbackResistance dampens knockback by 60% with netherite leggings" {
    try std.testing.expectApproxEqAbs(applyKnockbackResistance(1.0, true), 0.40, 0.01);
    try std.testing.expectApproxEqAbs(applyKnockbackResistance(2.5, true), 1.00, 0.01);
    try std.testing.expectApproxEqAbs(applyKnockbackResistance(1.0, false), 1.00, 0.01);
}

test "applyArmorReductionFullSet absorbs 75% damage with full netherite set" {
    try std.testing.expectApproxEqAbs(applyArmorReductionFullSet(10.0, true, true), 2.5, 0.01);
    try std.testing.expectApproxEqAbs(applyArmorReductionFullSet(10.0, true, false), 5.0, 0.01);
    try std.testing.expectApproxEqAbs(applyArmorReductionFullSet(10.0, false, false), 10.0, 0.01);
}

pub const shield_durability: u16 = 336;
pub const shield_blocking_speed_mult: f32 = 0.58; // 3.5 m/s vs 6.0 m/s
pub const shield_knockback_absorption: f32 = 0.80; // 80% knockback reduction while blocking

/// Checks if an incoming attack vector (attacker_pos - player_pos) is blocked by player facing front.
/// Returns true if the attacker is in the front 180-degree hemisphere (dot product > 0).
pub fn canBlockAttack(look_x: f32, look_z: f32, attack_dx: f32, attack_dz: f32) bool {
    const dot = look_x * attack_dx + look_z * attack_dz;
    return dot > 0.0;
}

test "shield combat blocking hemisphere check" {
    // Looking forward (+Z), attacker in front (+Z)
    try std.testing.expect(canBlockAttack(0.0, 1.0, 0.0, 2.0));
    // Looking forward (+Z), attacker behind (-Z)
    try std.testing.expect(!canBlockAttack(0.0, 1.0, 0.0, -2.0));
    // Looking East (+X), attacker to East (+X)
    try std.testing.expect(canBlockAttack(1.0, 0.0, 3.0, 1.0));
    // Looking East (+X), attacker to West (-X)
    try std.testing.expect(!canBlockAttack(1.0, 0.0, -3.0, 0.0));
}

test "shield blocking speed multiplier and durability constants" {
    try std.testing.expectEqual(@as(u16, 336), shield_durability);
    try std.testing.expectApproxEqAbs(@as(f32, 0.58), shield_blocking_speed_mult, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.80), shield_knockback_absorption, 0.01);
}

test "weakness reduces player attack damage to floor 1" {
    // Netherite sword: 4 -> 2 under weakness
    try std.testing.expectEqual(calculatePlayerAttackDamage(true, false, false), 4);
    try std.testing.expectEqual(calculatePlayerAttackDamage(true, false, true), 2);

    // Iron sword: 2 -> 1 under weakness
    try std.testing.expectEqual(calculatePlayerAttackDamage(false, true, false), 2);
    try std.testing.expectEqual(calculatePlayerAttackDamage(false, true, true), 1);

    // Hand: 1 -> 1 under weakness
    try std.testing.expectEqual(calculatePlayerAttackDamage(false, false, false), 1);
    try std.testing.expectEqual(calculatePlayerAttackDamage(false, false, true), 1);
}

test "diamond sword attack damage tier and weakness interaction" {
    try std.testing.expectEqual(diamond_sword_damage, 3);
    try std.testing.expectEqual(weaponDamageTier(false, true, false), 3);

    // Full hierarchy unweakened: Netherite (4) > Diamond (3) > Iron (2) > Hand (1)
    try std.testing.expectEqual(calculatePlayerAttackDamageTier(true, false, false, false), 4);
    try std.testing.expectEqual(calculatePlayerAttackDamageTier(false, true, false, false), 3);
    try std.testing.expectEqual(calculatePlayerAttackDamageTier(false, false, true, false), 2);
    try std.testing.expectEqual(calculatePlayerAttackDamageTier(false, false, false, false), 1);

    // Weakened: weakness reduces raw damage by 2 (floor 1)
    // Diamond (3 - 2 = 1)
    try std.testing.expectEqual(calculatePlayerAttackDamageTier(false, true, false, true), 1);
    // Netherite (4 - 2 = 2)
    try std.testing.expectEqual(calculatePlayerAttackDamageTier(true, false, false, true), 2);
}

test "applyArmorReductionTier absorbs diamond tier 40% and full set 65%" {
    // Bare damage: 10.0
    try std.testing.expectApproxEqAbs(applyArmorReductionTier(10.0, false, false, false, false), 10.0, 0.01);

    // Diamond chestplate only: 40% reduction -> 6.0
    try std.testing.expectApproxEqAbs(applyArmorReductionTier(10.0, false, false, true, false), 6.0, 0.01);

    // Full diamond set: 65% reduction -> 3.5
    try std.testing.expectApproxEqAbs(applyArmorReductionTier(10.0, false, false, true, true), 3.5, 0.01);

    // Netherite chestplate takes priority over diamond: 50% reduction -> 5.0
    try std.testing.expectApproxEqAbs(applyArmorReductionTier(10.0, true, false, true, true), 5.0, 0.01);

    // Full netherite set takes top priority: 75% reduction -> 2.5
    try std.testing.expectApproxEqAbs(applyArmorReductionTier(10.0, true, true, true, true), 2.5, 0.01);
}

test "applyArmorReductionFullTiers absorbs iron tier 25% and full set 50%" {
    try std.testing.expectApproxEqAbs(applyArmorReductionFullTiers(10.0, false, false, false, false, false, false), 10.0, 0.01);
    // Iron chestplate: 25% reduction -> 7.5
    try std.testing.expectApproxEqAbs(applyArmorReductionFullTiers(10.0, false, false, false, false, true, false), 7.5, 0.01);
    // Iron full set: 50% reduction -> 5.0
    try std.testing.expectApproxEqAbs(applyArmorReductionFullTiers(10.0, false, false, false, false, true, true), 5.0, 0.01);
    // Diamond overrides iron
    try std.testing.expectApproxEqAbs(applyArmorReductionFullTiers(10.0, false, false, true, false, true, true), 6.0, 0.01);
    try std.testing.expectApproxEqAbs(applyArmorReductionFullTiers(10.0, false, false, true, true, true, true), 3.5, 0.01);
    // Netherite overrides diamond and iron
    try std.testing.expectApproxEqAbs(applyArmorReductionFullTiers(10.0, true, false, true, true, true, true), 5.0, 0.01);
    try std.testing.expectApproxEqAbs(applyArmorReductionFullTiers(10.0, true, true, true, true, true, true), 2.5, 0.01);
}

test "applyArmorReductionAllTiers absorbs golden tier 15% and full set 35%" {
    try std.testing.expectApproxEqAbs(applyArmorReductionAllTiers(10.0, false, false, false, false, false, false, false, false), 10.0, 0.01);
    // Golden chestplate: 15% reduction -> 8.5
    try std.testing.expectApproxEqAbs(applyArmorReductionAllTiers(10.0, false, false, false, false, false, false, true, false), 8.5, 0.01);
    // Golden full set: 35% reduction -> 6.5
    try std.testing.expectApproxEqAbs(applyArmorReductionAllTiers(10.0, false, false, false, false, false, false, true, true), 6.5, 0.01);
    // Iron overrides golden
    try std.testing.expectApproxEqAbs(applyArmorReductionAllTiers(10.0, false, false, false, false, true, false, true, true), 7.5, 0.01);
    try std.testing.expectApproxEqAbs(applyArmorReductionAllTiers(10.0, false, false, false, false, true, true, true, true), 5.0, 0.01);
}

test "calculatePlayerAttackDamageAllTiers stone sword damage check" {
    // Stone sword deals 2 damage (same tier as iron sword, more than bare hand)
    try std.testing.expectEqual(calculatePlayerAttackDamageAllTiers(false, false, false, true, false), 2);
    // Stone sword with weakness deals floor 1 damage
    try std.testing.expectEqual(calculatePlayerAttackDamageAllTiers(false, false, false, true, true), 1);
}

test "calculatePlayerAttackDamageEveryTier golden sword damage check" {
    // Golden sword deals 2 damage
    try std.testing.expectEqual(calculatePlayerAttackDamageEveryTier(false, false, false, false, true, false), 2);
    // Golden sword with weakness deals floor 1 damage
    try std.testing.expectEqual(calculatePlayerAttackDamageEveryTier(false, false, false, false, true, true), 1);
}
