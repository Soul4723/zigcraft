const std = @import("std");

pub const ArmorStandPose = enum(u4) {
    default_attention = 0,
    none = 1,
    solemn = 2,
    athena = 3,
    brandish = 4,
    honor = 5,
    entertain = 6,
    salute = 7,
    hero = 8,
    riposte = 9,
    zombie = 10,
    cancan_a = 11,
    cancan_b = 12,
    dab_star = 13,
};

/// Redstone power selects a pose directly; values above the final pose clamp.
pub fn poseForRedstoneSignal(redstone_power_0_to_15: u4) ArmorStandPose {
    return @enumFromInt(@min(13, redstone_power_0_to_15));
}

/// Advances a manually selected pose, wrapping from the last pose to the first.
pub fn nextArmorStandPose(pose: ArmorStandPose) ArmorStandPose {
    const value: u4 = @intFromEnum(pose);
    return @enumFromInt(if (value == 13) 0 else value + 1);
}

/// Exchanges the selected stand slot and held stack atomically when compatible.
/// A null optional represents an empty hand or equipment slot.
pub fn swapArmorStandSlot(stand_slot_item: *?u16, player_held_item: *?u16, item_matches_slot: bool) bool {
    if (!item_matches_slot) return false;
    const held = player_held_item.*;
    player_held_item.* = stand_slot_item.*;
    stand_slot_item.* = held;
    return true;
}

/// Frost Walker reaches two blocks plus its level from the player's position.
pub fn frostWalkerRadius(level: u2) u3 {
    return 2 + @as(u3, level);
}

/// Whether still water at the same elevation is within the freezing radius.
pub fn canFreezeWaterAtDistance(level: u2, same_y_level: bool, still_water: bool, distance: u4) bool {
    return same_y_level and still_water and distance > 0 and distance <= frostWalkerRadius(level);
}

/// Frost Walker I and II completely protect against hot floor contact damage.
pub fn frostWalkerNegatesHotFloorDamage(level: u2) bool {
    return level > 0;
}

pub const FrostedIceMeltResult = struct {
    next_age: u2,
    melted_to_water: bool,
};

/// Neighbor loss melts immediately; otherwise daylight advances the crack age.
pub fn tickFrostedIceMelt(current_age_0_to_3: u2, day_or_light_above_11: bool, adjacent_frosted_ice_count: u3) FrostedIceMeltResult {
    if (adjacent_frosted_ice_count < 2) return .{ .next_age = 0, .melted_to_water = true };
    if (!day_or_light_above_11) return .{ .next_age = current_age_0_to_3, .melted_to_water = false };
    if (current_age_0_to_3 == 3) return .{ .next_age = 0, .melted_to_water = true };
    return .{ .next_age = current_age_0_to_3 + 1, .melted_to_water = false };
}

pub const SoulSpeedResult = struct {
    speed_multiplier: f32,
    consumes_boot_durability: bool,
};

/// Applies Soul Speed's level-dependent acceleration and per-step wear roll.
pub fn computeSoulSpeedMultiplier(on_soul_sand_or_soil: bool, soul_speed_level: u2, roll_durability_0_to_99: u8) SoulSpeedResult {
    if (!on_soul_sand_or_soil or soul_speed_level == 0) {
        return .{ .speed_multiplier = 0.4, .consumes_boot_durability = false };
    }
    const level: f32 = @floatFromInt(@min(soul_speed_level, 3));
    return .{
        .speed_multiplier = 1.21 + level * 0.105,
        .consumes_boot_durability = roll_durability_0_to_99 < 4,
    };
}

test "redstone power maps to all thirteen poses and clamps high power" {
    const expected = [_]ArmorStandPose{
        .default_attention, .none, .solemn, .athena, .brandish, .honor, .entertain,
        .salute, .hero, .riposte, .zombie, .cancan_a, .cancan_b, .dab_star,
    };
    for (expected, 0..) |pose, power| try std.testing.expectEqual(pose, poseForRedstoneSignal(@intCast(power)));
    try std.testing.expectEqual(ArmorStandPose.dab_star, poseForRedstoneSignal(15));
}

test "redstone zero selects default attention" {
    try std.testing.expectEqual(ArmorStandPose.default_attention, poseForRedstoneSignal(0));
}

test "manual pose cycle advances and wraps" {
    try std.testing.expectEqual(ArmorStandPose.none, nextArmorStandPose(.default_attention));
    try std.testing.expectEqual(ArmorStandPose.dab_star, nextArmorStandPose(.cancan_b));
    try std.testing.expectEqual(ArmorStandPose.default_attention, nextArmorStandPose(.dab_star));
}

test "equipment swap exchanges both items in one operation" {
    var stand: ?u16 = 12;
    var held: ?u16 = 34;
    try std.testing.expect(swapArmorStandSlot(&stand, &held, true));
    try std.testing.expectEqual(@as(?u16, 34), stand);
    try std.testing.expectEqual(@as(?u16, 12), held);
}

test "equipment swap supports empty slots" {
    var stand: ?u16 = null;
    var held: ?u16 = 34;
    try std.testing.expect(swapArmorStandSlot(&stand, &held, true));
    try std.testing.expectEqual(@as(?u16, 34), stand);
    try std.testing.expectEqual(@as(?u16, null), held);
}

test "equipment swap rejects wrong slot without mutation" {
    var stand: ?u16 = 12;
    var held: ?u16 = 34;
    try std.testing.expect(!swapArmorStandSlot(&stand, &held, false));
    try std.testing.expectEqual(@as(?u16, 12), stand);
    try std.testing.expectEqual(@as(?u16, 34), held);
}

test "Frost Walker I has radius three" {
    try std.testing.expectEqual(@as(u3, 3), frostWalkerRadius(1));
    try std.testing.expect(canFreezeWaterAtDistance(1, true, true, 3));
    try std.testing.expect(!canFreezeWaterAtDistance(1, true, true, 4));
}

test "Frost Walker II has radius four" {
    try std.testing.expectEqual(@as(u3, 4), frostWalkerRadius(2));
    try std.testing.expect(canFreezeWaterAtDistance(2, true, true, 4));
}

test "Frost Walker only freezes same-height still water" {
    try std.testing.expect(!canFreezeWaterAtDistance(2, false, true, 2));
    try std.testing.expect(!canFreezeWaterAtDistance(2, true, false, 2));
    try std.testing.expect(!canFreezeWaterAtDistance(2, true, true, 0));
}

test "Frost Walker grants hot floor immunity at levels one and two" {
    try std.testing.expect(!frostWalkerNegatesHotFloorDamage(0));
    try std.testing.expect(frostWalkerNegatesHotFloorDamage(1));
    try std.testing.expect(frostWalkerNegatesHotFloorDamage(2));
}

test "Frosted Ice cracks through four daylight stages then melts" {
    var result = tickFrostedIceMelt(0, true, 2);
    try std.testing.expectEqual(@as(u2, 1), result.next_age);
    try std.testing.expect(!result.melted_to_water);
    result = tickFrostedIceMelt(1, true, 2);
    try std.testing.expectEqual(@as(u2, 2), result.next_age);
    result = tickFrostedIceMelt(2, true, 2);
    try std.testing.expectEqual(@as(u2, 3), result.next_age);
    result = tickFrostedIceMelt(3, true, 2);
    try std.testing.expectEqual(@as(u2, 0), result.next_age);
    try std.testing.expect(result.melted_to_water);
}

test "Frosted Ice does not crack without daylight" {
    const result = tickFrostedIceMelt(2, false, 3);
    try std.testing.expectEqual(@as(u2, 2), result.next_age);
    try std.testing.expect(!result.melted_to_water);
}

test "Frosted Ice neighbor cascade melts below two neighbors" {
    const result = tickFrostedIceMelt(1, false, 1);
    try std.testing.expect(result.melted_to_water);
    try std.testing.expectEqual(@as(u2, 0), result.next_age);
}

test "Frosted Ice survives with two adjacent neighbors" {
    const result = tickFrostedIceMelt(1, false, 2);
    try std.testing.expect(!result.melted_to_water);
    try std.testing.expectEqual(@as(u2, 1), result.next_age);
}

test "Soul Speed I through III multipliers" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.315), computeSoulSpeedMultiplier(true, 1, 50).speed_multiplier, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.420), computeSoulSpeedMultiplier(true, 2, 50).speed_multiplier, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.525), computeSoulSpeedMultiplier(true, 3, 50).speed_multiplier, 0.0001);
}

test "Soul Speed uses four percent durability wear chance" {
    try std.testing.expect(computeSoulSpeedMultiplier(true, 1, 0).consumes_boot_durability);
    try std.testing.expect(computeSoulSpeedMultiplier(true, 1, 3).consumes_boot_durability);
    try std.testing.expect(!computeSoulSpeedMultiplier(true, 1, 4).consumes_boot_durability);
    try std.testing.expect(!computeSoulSpeedMultiplier(true, 1, 99).consumes_boot_durability);
}

test "Soul Speed does not apply away from soul blocks or without enchantment" {
    try std.testing.expectEqual(@as(f32, 0.4), computeSoulSpeedMultiplier(false, 3, 0).speed_multiplier);
    try std.testing.expectEqual(@as(f32, 0.4), computeSoulSpeedMultiplier(true, 0, 0).speed_multiplier);
    try std.testing.expect(!computeSoulSpeedMultiplier(false, 3, 0).consumes_boot_durability);
}
