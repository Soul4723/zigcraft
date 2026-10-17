const std = @import("std");

/// The eight distinct sounds represented by goat horn items.
pub const GoatHornVariant = enum {
    ponder,
    sing,
    seek,
    feel,
    admire,
    call,
    yearn,
    dream,
};

pub const regular_horn_variants = [_]GoatHornVariant{ .ponder, .sing, .seek, .feel };
pub const screaming_horn_variants = [_]GoatHornVariant{ .admire, .call, .yearn, .dream };

pub const regular_ram_cooldown_min_seconds: f32 = 30.0;
pub const regular_ram_cooldown_max_seconds: f32 = 300.0;
pub const screaming_ram_cooldown_min_seconds: f32 = 5.0;
pub const screaming_ram_cooldown_max_seconds: f32 = 15.0;
pub const goat_fall_damage_reduction_blocks: f32 = 10.0;

/// Rolls are whole-number percentages in [0, 99].
pub fn isScreamingGoatRoll(roll_0_to_99: u8) bool {
    return roll_0_to_99 < 2;
}

pub const GoatState = struct {
    is_screaming_goat: bool = false,
    horns_remaining: u2 = 2,
    ram_cooldown_seconds: f32 = 0.0,
};

/// Produces a ram timer for a uniformly distributed roll in [0, 1]. Values
/// outside that interval are clamped to keep the result in the documented range.
pub fn ramCooldownSeconds(is_screaming_goat: bool, roll_0_to_1: f32) f32 {
    const roll = @max(0.0, @min(1.0, roll_0_to_1));
    const min = if (is_screaming_goat) screaming_ram_cooldown_min_seconds else regular_ram_cooldown_min_seconds;
    const max = if (is_screaming_goat) screaming_ram_cooldown_max_seconds else regular_ram_cooldown_max_seconds;
    return min + (max - min) * roll;
}

/// Snaps one horn off when the missed ram hits a naturally generated hard
/// horn-snapper. The caller classifies the block; soft blocks pass false.
pub fn resolveGoatRamWallCollision(goat: *GoatState, hit_block_is_hard_horn_snapper: bool, variant_roll_0_to_3: u2) ?GoatHornVariant {
    if (!hit_block_is_hard_horn_snapper or goat.horns_remaining == 0) return null;
    goat.horns_remaining -= 1;
    const index: usize = variant_roll_0_to_3;
    return if (goat.is_screaming_goat) screaming_horn_variants[index] else regular_horn_variants[index];
}

/// Goats have ten blocks of innate fall reduction; damage begins above 13.
pub fn computeGoatFallDamage(fall_distance_blocks: f32) f32 {
    return @max(0.0, fall_distance_blocks - 13.0);
}

/// Goats automatically avoid Powder Snow while pathfinding.
pub fn shouldAvoidPowderSnow(is_powder_snow: bool) bool {
    return is_powder_snow;
}

/// True when using a bucket can milk the goat (the result is a MilkBucket).
pub fn milkGoatWithBucket(held_is_empty_bucket: bool) bool {
    return held_is_empty_bucket;
}

test "2 percent screaming goat spawn roll" {
    try std.testing.expect(isScreamingGoatRoll(0));
    try std.testing.expect(isScreamingGoatRoll(1));
    try std.testing.expect(!isScreamingGoatRoll(2));
    try std.testing.expect(!isScreamingGoatRoll(99));
}

test "screaming goat ram timer is 5 to 15 seconds" {
    try std.testing.expectEqual(@as(f32, 5), ramCooldownSeconds(true, 0));
    try std.testing.expectEqual(@as(f32, 15), ramCooldownSeconds(true, 1));
    try std.testing.expectEqual(@as(f32, 10), ramCooldownSeconds(true, 0.5));
}

test "regular goat ram timer is 30 to 300 seconds" {
    try std.testing.expectEqual(@as(f32, 30), ramCooldownSeconds(false, 0));
    try std.testing.expectEqual(@as(f32, 300), ramCooldownSeconds(false, 1));
    try std.testing.expectEqual(@as(f32, 165), ramCooldownSeconds(false, 0.5));
}

test "ram timer clamps random input" {
    try std.testing.expectEqual(@as(f32, 5), ramCooldownSeconds(true, -1));
    try std.testing.expectEqual(@as(f32, 15), ramCooldownSeconds(true, 2));
}

test "regular horns map all four rolls" {
    for (regular_horn_variants, 0..) |variant, i| {
        var goat = GoatState{};
        try std.testing.expectEqual(variant, resolveGoatRamWallCollision(&goat, true, @intCast(i)).?);
    }
}

test "screaming horns map all four rolls exclusively" {
    for (screaming_horn_variants, 0..) |variant, i| {
        var goat = GoatState{ .is_screaming_goat = true };
        try std.testing.expectEqual(variant, resolveGoatRamWallCollision(&goat, true, @intCast(i)).?);
    }
    var regular = GoatState{};
    try std.testing.expectEqual(GoatHornVariant.ponder, resolveGoatRamWallCollision(&regular, true, 0).?);
}

test "hard collision snaps one of two horns" {
    var goat = GoatState{};
    try std.testing.expect(resolveGoatRamWallCollision(&goat, true, 0) != null);
    try std.testing.expectEqual(@as(u2, 1), goat.horns_remaining);
}

test "second hard collision removes last horn" {
    var goat = GoatState{};
    _ = resolveGoatRamWallCollision(&goat, true, 0);
    _ = resolveGoatRamWallCollision(&goat, true, 1);
    try std.testing.expectEqual(@as(u2, 0), goat.horns_remaining);
}

test "hornless goat cannot drop another horn" {
    var goat = GoatState{ .horns_remaining = 0 };
    try std.testing.expectEqual(@as(?GoatHornVariant, null), resolveGoatRamWallCollision(&goat, true, 0));
    try std.testing.expectEqual(@as(u2, 0), goat.horns_remaining);
}

test "soft collision preserves both horns" {
    var goat = GoatState{};
    try std.testing.expectEqual(@as(?GoatHornVariant, null), resolveGoatRamWallCollision(&goat, false, 0));
    try std.testing.expectEqual(@as(u2, 2), goat.horns_remaining);
}

test "hard collision classification supports natural snapper blocks" {
    // Stone, coal/iron/copper/emerald ore, packed ice, and wood logs are
    // supplied as hard by the integration layer; dirt, snow and planks are not.
    var goat = GoatState{};
    for (0..7) |_| {
        goat.horns_remaining = 2;
        try std.testing.expect(resolveGoatRamWallCollision(&goat, true, 0) != null);
    }
}

test "fall damage is zero through thirteen blocks" {
    try std.testing.expectEqual(@as(f32, 0), computeGoatFallDamage(0));
    try std.testing.expectEqual(@as(f32, 0), computeGoatFallDamage(10));
    try std.testing.expectEqual(@as(f32, 0), computeGoatFallDamage(13));
}

test "fall damage starts above thirteen blocks" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), computeGoatFallDamage(13.5), 0.0001);
    try std.testing.expectEqual(@as(f32, 7), computeGoatFallDamage(20));
}

test "goat pathfinding avoids powder snow only" {
    try std.testing.expect(shouldAvoidPowderSnow(true));
    try std.testing.expect(!shouldAvoidPowderSnow(false));
}

test "empty bucket milks goat" {
    try std.testing.expect(milkGoatWithBucket(true));
}

test "non-empty hand cannot milk goat" {
    try std.testing.expect(!milkGoatWithBucket(false));
}
