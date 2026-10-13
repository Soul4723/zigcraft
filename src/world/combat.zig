const std = @import("std");

pub const wolf_bite_damage: f32 = 2.0;
pub const wolf_bite_cooldown: f32 = 1.0;
pub const wolf_bite_range_sq: f32 = 1.44;
pub const wolf_bite_height: f32 = 2.0;
pub const melee_cooldown: f32 = 0.35;
pub const melee_range: f32 = 4.0;
pub const sword_damage: u8 = 2;
pub const netherite_sword_damage: u8 = 4;
pub const hand_damage: u8 = 1;

pub const netherite_armor_absorption: f32 = 0.50; // 50% damage reduction

pub fn applyArmorReduction(raw_damage: f32, has_netherite_armor: bool) f32 {
    if (has_netherite_armor) {
        return raw_damage * (1.0 - netherite_armor_absorption);
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
    if (is_netherite) return netherite_sword_damage;
    if (is_iron) return sword_damage;
    return hand_damage;
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
