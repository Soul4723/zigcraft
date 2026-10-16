const std = @import("std");

pub const max_scaffolding_height: i32 = 15;
pub const max_overhang: u8 = 6;
pub const berry_bush_damage_rate: f32 = 0.5;

pub fn findTopPlacementY(base_y: i32, world_ceiling: i32, column_heights_occupied: u8) ?i32 {
    const target_y = base_y + @as(i32, column_heights_occupied);
    if (target_y <= world_ceiling) return target_y;
    return null;
}

pub fn isSupportedOverhang(lateral_distance: u8) bool {
    return lateral_distance <= max_overhang;
}

pub fn calculateBerryBushDamage(is_moving: bool, has_leggings: bool, dt: f32) f32 {
    if (!is_moving) return 0.0;
    const mult: f32 = if (has_leggings) 0.5 else 1.0;
    return berry_bush_damage_rate * mult * dt;
}

test "scaffolding constants" {
    try std.testing.expectEqual(@as(i32, 15), max_scaffolding_height);
    try std.testing.expectEqual(@as(u8, 6), max_overhang);
    try std.testing.expectEqual(@as(f32, 0.5), berry_bush_damage_rate);
}

test "findTopPlacementY within ceiling" {
    try std.testing.expectEqual(@as(?i32, 70), findTopPlacementY(64, 100, 6));
    try std.testing.expectEqual(@as(?i32, 64), findTopPlacementY(64, 100, 0));
}

test "findTopPlacementY at exact ceiling" {
    try std.testing.expectEqual(@as(?i32, 100), findTopPlacementY(94, 100, 6));
}

test "findTopPlacementY above ceiling" {
    try std.testing.expectEqual(@as(?i32, null), findTopPlacementY(94, 100, 7));
    try std.testing.expectEqual(@as(?i32, null), findTopPlacementY(0, -1, 0));
}

test "findTopPlacementY full column" {
    try std.testing.expectEqual(@as(?i32, 79), findTopPlacementY(64, 100, 15));
    try std.testing.expectEqual(@as(?i32, null), findTopPlacementY(64, 70, 15));
}

test "isSupportedOverhang" {
    try std.testing.expect(isSupportedOverhang(0));
    try std.testing.expect(isSupportedOverhang(6));
    try std.testing.expect(!isSupportedOverhang(7));
    try std.testing.expect(!isSupportedOverhang(255));
}

test "calculateBerryBushDamage stationary" {
    try std.testing.expectEqual(@as(f32, 0.0), calculateBerryBushDamage(false, false, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), calculateBerryBushDamage(false, true, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), calculateBerryBushDamage(false, false, 0.0));
}

test "calculateBerryBushDamage moving without leggings" {
    try std.testing.expectEqual(@as(f32, 0.5), calculateBerryBushDamage(true, false, 1.0));
    try std.testing.expectEqual(@as(f32, 1.0), calculateBerryBushDamage(true, false, 2.0));
    try std.testing.expectEqual(@as(f32, 0.05), calculateBerryBushDamage(true, false, 0.1));
}

test "calculateBerryBushDamage moving with leggings" {
    try std.testing.expectEqual(@as(f32, 0.25), calculateBerryBushDamage(true, true, 1.0));
    try std.testing.expectEqual(@as(f32, 0.5), calculateBerryBushDamage(true, true, 2.0));
}

test "calculateBerryBushDamage zero dt" {
    try std.testing.expectEqual(@as(f32, 0.0), calculateBerryBushDamage(true, false, 0.0));
    try std.testing.expectEqual(@as(f32, 0.0), calculateBerryBushDamage(true, true, 0.0));
}
