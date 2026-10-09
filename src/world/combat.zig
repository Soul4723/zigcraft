const std = @import("std");

pub const wolf_bite_damage: f32 = 2.0;
pub const wolf_bite_cooldown: f32 = 1.0;
pub const wolf_bite_range_sq: f32 = 1.44;
pub const wolf_bite_height: f32 = 2.0;
pub const melee_cooldown: f32 = 0.35;
pub const melee_range: f32 = 4.0;
pub const sword_damage: u8 = 2;
pub const hand_damage: u8 = 1;

pub fn inBiteRange(dx: f32, dz: f32, dy: f32) bool {
    return dx * dx + dz * dz < wolf_bite_range_sq and @abs(dy) < wolf_bite_height;
}

pub fn tickCooldown(cd: f32, dt: f32) f32 {
    return @max(0.0, cd - dt);
}

pub fn meleeDamage(is_sword: bool) u8 {
    return if (is_sword) sword_damage else hand_damage;
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
