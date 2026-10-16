const std = @import("std");

pub const supercharge_duration: f32 = 300.0;
pub const haste_tier1_multiplier: f32 = 1.25;
pub const haste_tier2_multiplier: f32 = 1.40;
pub const regen_rate_per_sec: f32 = 0.5;

pub const IronBlockTag: u8 = 185;
pub const GoldBlockTag: u8 = 149;
pub const DiamondBlockTag: u8 = 151;
pub const EmeraldBlockTag: u8 = 157;

pub fn isBeaconBaseBlock(block_tag: u8) bool {
    return block_tag == IronBlockTag or
        block_tag == GoldBlockTag or
        block_tag == DiamondBlockTag or
        block_tag == EmeraldBlockTag;
}

pub fn auraRadiusForLevel(pyramid_level: u8) f32 {
    return switch (pyramid_level) {
        0 => 0.0,
        1 => 20.0,
        2 => 30.0,
        3 => 40.0,
        else => 50.0,
    };
}

pub fn hasteMultiplier(pyramid_level: u8, supercharged: bool) f32 {
    if (pyramid_level == 0) return 1.0;
    if (supercharged or pyramid_level >= 2) return haste_tier2_multiplier;
    return haste_tier1_multiplier;
}

pub fn tickBeaconRegen(current_hp: f32, max_hp: f32, pyramid_level: u8, dt: f32) f32 {
    if (pyramid_level == 0 or current_hp <= 0.0) return current_hp;
    return @min(max_hp, current_hp + regen_rate_per_sec * dt);
}

test "constants have expected values" {
    try std.testing.expectEqual(@as(f32, 300.0), supercharge_duration);
    try std.testing.expectEqual(@as(f32, 1.25), haste_tier1_multiplier);
    try std.testing.expectEqual(@as(f32, 1.40), haste_tier2_multiplier);
    try std.testing.expectEqual(@as(f32, 0.5), regen_rate_per_sec);
    try std.testing.expectEqual(@as(u8, 185), IronBlockTag);
    try std.testing.expectEqual(@as(u8, 149), GoldBlockTag);
    try std.testing.expectEqual(@as(u8, 151), DiamondBlockTag);
    try std.testing.expectEqual(@as(u8, 157), EmeraldBlockTag);
}

test "isBeaconBaseBlock accepts all four base blocks" {
    try std.testing.expect(isBeaconBaseBlock(IronBlockTag));
    try std.testing.expect(isBeaconBaseBlock(GoldBlockTag));
    try std.testing.expect(isBeaconBaseBlock(DiamondBlockTag));
    try std.testing.expect(isBeaconBaseBlock(EmeraldBlockTag));
}

test "isBeaconBaseBlock rejects other blocks" {
    try std.testing.expect(!isBeaconBaseBlock(0));
    try std.testing.expect(!isBeaconBaseBlock(1));
    try std.testing.expect(!isBeaconBaseBlock(182));
    try std.testing.expect(!isBeaconBaseBlock(255));
}

test "auraRadiusForLevel maps each level" {
    try std.testing.expectEqual(@as(f32, 0.0), auraRadiusForLevel(0));
    try std.testing.expectEqual(@as(f32, 20.0), auraRadiusForLevel(1));
    try std.testing.expectEqual(@as(f32, 30.0), auraRadiusForLevel(2));
    try std.testing.expectEqual(@as(f32, 40.0), auraRadiusForLevel(3));
    try std.testing.expectEqual(@as(f32, 50.0), auraRadiusForLevel(4));
    try std.testing.expectEqual(@as(f32, 50.0), auraRadiusForLevel(5));
    try std.testing.expectEqual(@as(f32, 50.0), auraRadiusForLevel(255));
}

test "hasteMultiplier level zero is neutral" {
    try std.testing.expectEqual(@as(f32, 1.0), hasteMultiplier(0, false));
    try std.testing.expectEqual(@as(f32, 1.0), hasteMultiplier(0, true));
}

test "hasteMultiplier tier1 for level1 not supercharged" {
    try std.testing.expectEqual(haste_tier1_multiplier, hasteMultiplier(1, false));
}

test "hasteMultiplier tier2 for level2 and above" {
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(2, false));
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(3, false));
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(4, false));
}

test "hasteMultiplier supercharged upgrades level1 to tier2" {
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(1, true));
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(2, true));
}

test "tickBeaconRegen is inactive without pyramid" {
    try std.testing.expectEqual(@as(f32, 10.0), tickBeaconRegen(10.0, 20.0, 0, 1.0));
}

test "tickBeaconRegen is inactive at or below zero hp" {
    try std.testing.expectEqual(@as(f32, 0.0), tickBeaconRegen(0.0, 20.0, 2, 1.0));
    try std.testing.expectEqual(@as(f32, -1.0), tickBeaconRegen(-1.0, 20.0, 2, 1.0));
}

test "tickBeaconRegen regenerates at fixed rate" {
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), tickBeaconRegen(10.0, 20.0, 1, 1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), tickBeaconRegen(10.0, 20.0, 1, 4.0), 0.0001);
}

test "tickBeaconRegen clamps to max hp" {
    try std.testing.expectEqual(@as(f32, 20.0), tickBeaconRegen(19.9, 20.0, 1, 1.0));
    try std.testing.expectEqual(@as(f32, 20.0), tickBeaconRegen(20.0, 20.0, 3, 1.0));
}

test "tickBeaconRegen with zero dt is a no-op" {
    try std.testing.expectEqual(@as(f32, 15.0), tickBeaconRegen(15.0, 20.0, 4, 0.0));
}
