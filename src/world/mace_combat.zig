const std = @import("std");

pub const mace_base_damage: u8 = 6;
pub const smash_min_fall_distance: f32 = 1.5;
pub const smash_max_damage: u8 = 50;
pub const mace_durability: u16 = 500;

pub fn isSmashAttack(fall_distance: f32) bool {
    return fall_distance >= smash_min_fall_distance;
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
