const std = @import("std");

pub const buff_duration: f32 = 180.0;
pub const swiftness_speed_multiplier: f32 = 1.20;
pub const strength_bonus_damage: u8 = 3;
pub const leaping_jump_multiplier: f32 = 1.25;

pub const BuffTimers = struct {
    swiftness: f32 = 0.0,
    strength: f32 = 0.0,
    leaping: f32 = 0.0,
};

pub fn tickBuffs(timers: *BuffTimers, dt: f32) void {
    timers.swiftness = clampZero(timers.swiftness - dt);
    timers.strength = clampZero(timers.strength - dt);
    timers.leaping = clampZero(timers.leaping - dt);
}

fn clampZero(value: f32) f32 {
    return if (value < 0.0) 0.0 else value;
}

pub fn effectiveSpeedMultiplier(timers: BuffTimers) f32 {
    return if (timers.swiftness > 0.0) swiftness_speed_multiplier else 1.0;
}

pub fn applyStrengthBonus(base_damage: u8, timers: BuffTimers) u8 {
    return if (timers.strength > 0.0) base_damage +| strength_bonus_damage else base_damage;
}

pub fn effectiveJumpMultiplier(timers: BuffTimers) f32 {
    return if (timers.leaping > 0.0) leaping_jump_multiplier else 1.0;
}

test "constants have expected values" {
    try std.testing.expectEqual(@as(f32, 180.0), buff_duration);
    try std.testing.expectEqual(@as(f32, 1.20), swiftness_speed_multiplier);
    try std.testing.expectEqual(@as(u8, 3), strength_bonus_damage);
    try std.testing.expectEqual(@as(f32, 1.25), leaping_jump_multiplier);
}

test "BuffTimers defaults to zero" {
    const timers = BuffTimers{};
    try std.testing.expectEqual(@as(f32, 0.0), timers.swiftness);
    try std.testing.expectEqual(@as(f32, 0.0), timers.strength);
    try std.testing.expectEqual(@as(f32, 0.0), timers.leaping);
}

test "tickBuffs decrements all timers" {
    var timers = BuffTimers{ .swiftness = 10.0, .strength = 5.0, .leaping = 2.0 };
    tickBuffs(&timers, 1.5);
    try std.testing.expectApproxEqAbs(@as(f32, 8.5), timers.swiftness, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), timers.strength, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), timers.leaping, 0.0001);
}

test "tickBuffs clamps to zero and never goes negative" {
    var timers = BuffTimers{ .swiftness = 1.0, .strength = 0.5, .leaping = 0.25 };
    tickBuffs(&timers, 10.0);
    try std.testing.expectEqual(@as(f32, 0.0), timers.swiftness);
    try std.testing.expectEqual(@as(f32, 0.0), timers.strength);
    try std.testing.expectEqual(@as(f32, 0.0), timers.leaping);
}

test "tickBuffs leaves zero timers at zero" {
    var timers = BuffTimers{};
    tickBuffs(&timers, 5.0);
    try std.testing.expectEqual(@as(f32, 0.0), timers.swiftness);
    try std.testing.expectEqual(@as(f32, 0.0), timers.strength);
    try std.testing.expectEqual(@as(f32, 0.0), timers.leaping);
}

test "tickBuffs can expire a buff from buff_duration" {
    var timers = BuffTimers{ .swiftness = buff_duration };
    tickBuffs(&timers, buff_duration);
    try std.testing.expectEqual(@as(f32, 0.0), timers.swiftness);
}

test "effectiveSpeedMultiplier active and inactive" {
    try std.testing.expectEqual(swiftness_speed_multiplier, effectiveSpeedMultiplier(.{ .swiftness = 2.0 }));
    try std.testing.expectEqual(@as(f32, 1.0), effectiveSpeedMultiplier(.{}));
}

test "effectiveSpeedMultiplier treats negative timers as inactive" {
    try std.testing.expectEqual(@as(f32, 1.0), effectiveSpeedMultiplier(.{ .swiftness = -1.0 }));
}

test "applyStrengthBonus active and inactive" {
    try std.testing.expectEqual(@as(u8, 13), applyStrengthBonus(10, .{ .strength = 1.0 }));
    try std.testing.expectEqual(@as(u8, 10), applyStrengthBonus(10, .{}));
}

test "applyStrengthBonus saturates at u8 max" {
    try std.testing.expectEqual(@as(u8, 255), applyStrengthBonus(255, .{ .strength = 1.0 }));
    try std.testing.expectEqual(@as(u8, 255), applyStrengthBonus(254, .{ .strength = 1.0 }));
}

test "applyStrengthBonus treats negative timers as inactive" {
    try std.testing.expectEqual(@as(u8, 7), applyStrengthBonus(7, .{ .strength = -0.5 }));
}

test "effectiveJumpMultiplier active and inactive" {
    try std.testing.expectEqual(leaping_jump_multiplier, effectiveJumpMultiplier(.{ .leaping = 0.1 }));
    try std.testing.expectEqual(@as(f32, 1.0), effectiveJumpMultiplier(.{}));
}

test "effectiveJumpMultiplier treats negative timers as inactive" {
    try std.testing.expectEqual(@as(f32, 1.0), effectiveJumpMultiplier(.{ .leaping = -0.1 }));
}

test "buffs are independent of one another" {
    var timers = BuffTimers{ .swiftness = 5.0 };
    tickBuffs(&timers, 5.0);
    try std.testing.expectEqual(swiftness_speed_multiplier, effectiveSpeedMultiplier(.{ .swiftness = 5.0 }));
    try std.testing.expectEqual(@as(f32, 1.0), effectiveSpeedMultiplier(timers));
    try std.testing.expectEqual(@as(f32, 1.0), effectiveJumpMultiplier(timers));
}
