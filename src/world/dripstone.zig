const std = @import("std");

pub const stalagmite_fall_damage_multiplier: f32 = 2.0;
pub const stalactite_impact_per_block: u8 = 6;
pub const stalactite_max_damage: u8 = 40;
pub const cauldron_drip_interval: f32 = 20.0;

pub const DripFluid = enum { none, water, lava };

pub fn calculateStalagmiteFallDamage(base_fall_damage: f32) f32 {
    return base_fall_damage * stalagmite_fall_damage_multiplier;
}

pub fn calculateStalactiteImpactDamage(fall_distance: u8) u8 {
    if (fall_distance == 0) return 0;
    const scaled: u16 = @as(u16, fall_distance) * @as(u16, stalactite_impact_per_block);
    return @as(u8, @intCast(@min(@as(u16, stalactite_max_damage), scaled)));
}

pub fn tickCauldronDrip(timer: *f32, dt: f32, fluid: DripFluid, current_level: u8) ?u8 {
    if (fluid == .none or current_level >= 3) {
        timer.* = 0.0;
        return null;
    }
    timer.* += dt;
    if (timer.* >= cauldron_drip_interval) {
        timer.* -= cauldron_drip_interval;
        return current_level + 1;
    }
    return null;
}

test "constants" {
    try std.testing.expectEqual(@as(f32, 2.0), stalagmite_fall_damage_multiplier);
    try std.testing.expectEqual(@as(u8, 6), stalactite_impact_per_block);
    try std.testing.expectEqual(@as(u8, 40), stalactite_max_damage);
    try std.testing.expectEqual(@as(f32, 20.0), cauldron_drip_interval);
}

test "DripFluid values" {
    try std.testing.expectEqual(DripFluid.none, DripFluid.none);
    try std.testing.expectEqual(DripFluid.water, DripFluid.water);
    try std.testing.expectEqual(DripFluid.lava, DripFluid.lava);
    try std.testing.expect(DripFluid.none != DripFluid.water);
}

test "calculateStalagmiteFallDamage doubles base damage" {
    try std.testing.expectEqual(@as(f32, 0.0), calculateStalagmiteFallDamage(0.0));
    try std.testing.expectEqual(@as(f32, 2.0), calculateStalagmiteFallDamage(1.0));
    try std.testing.expectEqual(@as(f32, 7.5), calculateStalagmiteFallDamage(3.75));
    try std.testing.expectEqual(@as(f32, 24.0), calculateStalagmiteFallDamage(12.0));
}

test "calculateStalagmiteFallDamage negative base" {
    try std.testing.expectEqual(@as(f32, -4.0), calculateStalagmiteFallDamage(-2.0));
}

test "calculateStalactiteImpactDamage zero distance" {
    try std.testing.expectEqual(@as(u8, 0), calculateStalactiteImpactDamage(0));
}

test "calculateStalactiteImpactDamage scales per block" {
    try std.testing.expectEqual(@as(u8, 6), calculateStalactiteImpactDamage(1));
    try std.testing.expectEqual(@as(u8, 12), calculateStalactiteImpactDamage(2));
    try std.testing.expectEqual(@as(u8, 30), calculateStalactiteImpactDamage(5));
}

test "calculateStalactiteImpactDamage clamps at maximum" {
    try std.testing.expectEqual(@as(u8, 40), calculateStalactiteImpactDamage(7));
    try std.testing.expectEqual(@as(u8, 40), calculateStalactiteImpactDamage(10));
    try std.testing.expectEqual(@as(u8, 40), calculateStalactiteImpactDamage(255));
}

test "calculateStalactiteImpactDamage exact boundary" {
    try std.testing.expectEqual(@as(u8, 36), calculateStalactiteImpactDamage(6));
    try std.testing.expectEqual(@as(u8, 40), calculateStalactiteImpactDamage(7));
}

test "tickCauldronDrip none fluid resets timer" {
    var timer: f32 = 15.0;
    try std.testing.expectEqual(@as(?u8, null), tickCauldronDrip(&timer, 1.0, .none, 0));
    try std.testing.expectEqual(@as(f32, 0.0), timer);
}

test "tickCauldronDrip full cauldron resets timer" {
    var timer: f32 = 15.0;
    try std.testing.expectEqual(@as(?u8, null), tickCauldronDrip(&timer, 1.0, .water, 3));
    try std.testing.expectEqual(@as(f32, 0.0), timer);

    var lava_timer: f32 = 15.0;
    try std.testing.expectEqual(@as(?u8, null), tickCauldronDrip(&lava_timer, 1.0, .lava, 4));
    try std.testing.expectEqual(@as(f32, 0.0), lava_timer);
}

test "tickCauldronDrip advances below interval" {
    var timer: f32 = 0.0;
    try std.testing.expectEqual(@as(?u8, null), tickCauldronDrip(&timer, 10.0, .water, 0));
    try std.testing.expectEqual(@as(f32, 10.0), timer);
    try std.testing.expectEqual(@as(?u8, null), tickCauldronDrip(&timer, 9.9, .water, 0));
    try std.testing.expectEqual(@as(f32, 19.9), timer);
}

test "tickCauldronDrip fills at interval" {
    var timer: f32 = 19.0;
    try std.testing.expectEqual(@as(?u8, 1), tickCauldronDrip(&timer, 1.0, .water, 0));
    try std.testing.expectEqual(@as(f32, 0.0), timer);
}

test "tickCauldronDrip keeps remainder after fill" {
    var timer: f32 = 0.0;
    try std.testing.expectEqual(@as(?u8, 1), tickCauldronDrip(&timer, 25.0, .lava, 0));
    try std.testing.expectEqual(@as(f32, 5.0), timer);
}

test "tickCauldronDrip increments level" {
    var timer: f32 = 19.5;
    try std.testing.expectEqual(@as(?u8, 2), tickCauldronDrip(&timer, 0.5, .water, 1));
    try std.testing.expectEqual(@as(f32, 0.0), timer);
}

test "tickCauldronDrip level two fills to three" {
    var timer: f32 = 19.5;
    try std.testing.expectEqual(@as(?u8, 3), tickCauldronDrip(&timer, 0.5, .water, 2));
}
