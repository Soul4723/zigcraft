const std = @import("std");

pub const glow_berry_hunger: f32 = 2.0;
pub const carrot_hunger: f32 = 3.0;
pub const golden_carrot_hunger: f32 = 6.0;
pub const night_vision_duration: f32 = 180.0;
pub const moss_spread_radius: i32 = 2;

pub fn canConvertToMoss(is_stone_or_dirt: bool, has_air_above: bool) bool {
    return is_stone_or_dirt and has_air_above;
}

pub fn shouldRipenVine(roll: u8) bool {
    return (roll % 4) == 0;
}

pub fn effectiveAmbientLight(base_ambient: f32, night_vision_timer: f32) f32 {
    if (night_vision_timer > 0.0) {
        return @max(base_ambient, 0.85);
    }
    return base_ambient;
}

pub fn tickNightVision(timer: f32, dt: f32) f32 {
    return @max(0.0, timer - dt);
}

test "constants" {
    try std.testing.expectEqual(@as(f32, 2.0), glow_berry_hunger);
    try std.testing.expectEqual(@as(f32, 3.0), carrot_hunger);
    try std.testing.expectEqual(@as(f32, 6.0), golden_carrot_hunger);
    try std.testing.expectEqual(@as(f32, 180.0), night_vision_duration);
    try std.testing.expectEqual(@as(i32, 2), moss_spread_radius);
}

test "canConvertToMoss truth table" {
    try std.testing.expect(canConvertToMoss(true, true));
    try std.testing.expect(!canConvertToMoss(true, false));
    try std.testing.expect(!canConvertToMoss(false, true));
    try std.testing.expect(!canConvertToMoss(false, false));
}

test "shouldRipenVine every fourth roll" {
    try std.testing.expect(shouldRipenVine(0));
    try std.testing.expect(!shouldRipenVine(1));
    try std.testing.expect(!shouldRipenVine(2));
    try std.testing.expect(!shouldRipenVine(3));
    try std.testing.expect(shouldRipenVine(4));
}

test "shouldRipenVine full byte range" {
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const roll: u8 = @intCast(i);
        try std.testing.expectEqual((i % 4) == 0, shouldRipenVine(roll));
    }
}

test "effectiveAmbientLight without night vision" {
    try std.testing.expectEqual(@as(f32, 0.0), effectiveAmbientLight(0.0, 0.0));
    try std.testing.expectEqual(@as(f32, 0.3), effectiveAmbientLight(0.3, 0.0));
    try std.testing.expectEqual(@as(f32, 1.0), effectiveAmbientLight(1.0, 0.0));
}

test "effectiveAmbientLight floors at 0.85 with night vision" {
    try std.testing.expectEqual(@as(f32, 0.85), effectiveAmbientLight(0.0, 1.0));
    try std.testing.expectEqual(@as(f32, 0.85), effectiveAmbientLight(0.5, 180.0));
}

test "effectiveAmbientLight keeps brighter ambient" {
    try std.testing.expectEqual(@as(f32, 1.0), effectiveAmbientLight(1.0, 10.0));
    try std.testing.expectEqual(@as(f32, 0.9), effectiveAmbientLight(0.9, 10.0));
}

test "effectiveAmbientLight zero timer ignores flooring" {
    try std.testing.expectEqual(@as(f32, 0.2), effectiveAmbientLight(0.2, 0.0));
}

test "tickNightVision decrements" {
    try std.testing.expectEqual(@as(f32, 9.5), tickNightVision(10.0, 0.5));
    try std.testing.expectEqual(@as(f32, 0.0), tickNightVision(1.0, 1.0));
}

test "tickNightVision clamps at zero" {
    try std.testing.expectEqual(@as(f32, 0.0), tickNightVision(5.0, 10.0));
    try std.testing.expectEqual(@as(f32, 0.0), tickNightVision(0.0, 1.0));
}

test "tickNightVision zero dt leaves timer unchanged" {
    try std.testing.expectEqual(@as(f32, 180.0), tickNightVision(night_vision_duration, 0.0));
}
