const std = @import("std");

pub const FishingCategoryProbabilities = struct {
    fish_chance: f32,
    treasure_chance: f32,
    junk_chance: f32,
};

/// Applies Lure's five-second-per-level reduction, then sky and direct-rain modifiers.
/// The resulting wait is clamped to one second before environmental multipliers.
pub fn computeFishingBiteWaitTime(
    base_wait_seconds: f32,
    lure_level: u2,
    exposed_to_sky: bool,
    raining_on_bobber: bool,
) f32 {
    const reduced = @max(1.0, base_wait_seconds - 5.0 * @as(f32, @floatFromInt(lure_level)));
    const sky_multiplier: f32 = if (exposed_to_sky) 1.0 else 2.0;
    const rain_multiplier: f32 = if (raining_on_bobber) 0.80 else 1.0;
    return reduced * sky_multiplier * rain_multiplier;
}

/// The caller supplies the two complete 5x5x2 volume checks (water, then clear air).
pub fn isOpenWaterForTreasure(water_source_5x2x5_clear: bool, air_5x2x5_above_clear: bool) bool {
    return water_source_5x2x5_clear and air_5x2x5_above_clear;
}

/// Category weights are percentages. Non-open water excludes treasure; its remaining
/// category weights are normalized to 100% while preserving the Fish/Junk ratio.
pub fn computeFishingCategoryProbabilities(
    luck_of_the_sea_level: u2,
    in_open_water: bool,
) FishingCategoryProbabilities {
    const level: f32 = @floatFromInt(@min(luck_of_the_sea_level, 3));
    const treasure: f32 = if (in_open_water) 5.0 + 2.1 * level else 0.0;
    const junk: f32 = 10.0 - 1.95 * level;
    if (!in_open_water) {
        const remaining = 100.0 - treasure;
        const no_treasure_total = 85.0 + junk;
        return .{
            .fish_chance = remaining * 85.0 / no_treasure_total,
            .treasure_chance = 0.0,
            .junk_chance = remaining * junk / no_treasure_total,
        };
    }
    return .{ .fish_chance = 100.0 - treasure - junk, .treasure_chance = treasure, .junk_chance = junk };
}

/// Pull velocity from the bobber toward the angler. Item catches receive the
/// additional upward component used to make dropped loot arc toward the player.
pub fn computeFishingHookPullImpulse(bobber_pos: [3]f32, angler_pos: [3]f32, hooked_is_item: bool) [3]f32 {
    const dx = angler_pos[0] - bobber_pos[0];
    const dy = angler_pos[1] - bobber_pos[1];
    const dz = angler_pos[2] - bobber_pos[2];
    const distance = @sqrt(dx * dx + dy * dy + dz * dz);
    return .{ dx * 0.1, dy * 0.1 + (if (hooked_is_item) @sqrt(distance) * 0.08 else 0.0), dz * 0.1 };
}

test "Lure I reduces wait by five seconds" {
    try std.testing.expectApproxEqAbs(@as(f32, 15), computeFishingBiteWaitTime(20, 1, true, false), 0.001);
}

test "Lure II reduces wait by ten seconds" {
    try std.testing.expectApproxEqAbs(@as(f32, 10), computeFishingBiteWaitTime(20, 2, true, false), 0.001);
}

test "Lure III reduces wait by fifteen seconds" {
    try std.testing.expectApproxEqAbs(@as(f32, 5), computeFishingBiteWaitTime(20, 3, true, false), 0.001);
}

test "Lure reduction clamps to one second" {
    try std.testing.expectApproxEqAbs(@as(f32, 1), computeFishingBiteWaitTime(5, 3, true, false), 0.001);
}

test "occluded sky doubles wait" {
    try std.testing.expectApproxEqAbs(@as(f32, 20), computeFishingBiteWaitTime(10, 0, false, false), 0.001);
}

test "direct rain reduces wait by twenty percent" {
    try std.testing.expectApproxEqAbs(@as(f32, 8), computeFishingBiteWaitTime(10, 0, true, true), 0.001);
}

test "sky and rain multipliers combine" {
    try std.testing.expectApproxEqAbs(@as(f32, 16), computeFishingBiteWaitTime(10, 0, false, true), 0.001);
}

test "base wait remains unchanged without modifiers" {
    try std.testing.expectApproxEqAbs(@as(f32, 17), computeFishingBiteWaitTime(17, 0, true, false), 0.001);
}

test "clear 5x5x2 water and air qualify as open water" {
    try std.testing.expect(isOpenWaterForTreasure(true, true));
}

test "water volume obstruction prevents open water" {
    try std.testing.expect(!isOpenWaterForTreasure(false, true));
}

test "air obstruction such as lily pad prevents open water" {
    try std.testing.expect(!isOpenWaterForTreasure(true, false));
}

test "both obstructed volumes prevent open water" {
    try std.testing.expect(!isOpenWaterForTreasure(false, false));
}

test "Luck of the Sea I shifts open-water category weights" {
    const p = computeFishingCategoryProbabilities(1, true);
    try std.testing.expectApproxEqAbs(@as(f32, 7.1), p.treasure_chance, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.05), p.junk_chance, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 84.85), p.fish_chance, 0.001);
}

test "Luck of the Sea II shifts open-water category weights" {
    const p = computeFishingCategoryProbabilities(2, true);
    try std.testing.expectApproxEqAbs(@as(f32, 9.2), p.treasure_chance, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.1), p.junk_chance, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 84.7), p.fish_chance, 0.001);
}

test "Luck of the Sea III shifts open-water category weights" {
    const p = computeFishingCategoryProbabilities(3, true);
    try std.testing.expectApproxEqAbs(@as(f32, 11.3), p.treasure_chance, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.15), p.junk_chance, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 84.55), p.fish_chance, 0.001);
}

test "no enchantment uses vanilla open-water category weights" {
    const p = computeFishingCategoryProbabilities(0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 85), p.fish_chance, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5), p.treasure_chance, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10), p.junk_chance, 0.001);
}

test "non-open water has no treasure category" {
    const p = computeFishingCategoryProbabilities(0, false);
    try std.testing.expectEqual(@as(f32, 0), p.treasure_chance);
    try std.testing.expectApproxEqAbs(@as(f32, 100), p.fish_chance + p.junk_chance, 0.001);
}

test "non-open water still excludes treasure at Luck III" {
    const p = computeFishingCategoryProbabilities(3, false);
    try std.testing.expectEqual(@as(f32, 0), p.treasure_chance);
    try std.testing.expectApproxEqAbs(@as(f32, 100), p.fish_chance + p.junk_chance, 0.001);
}

test "entity hook impulse points from bobber to angler" {
    const impulse = computeFishingHookPullImpulse(.{ 0, 0, 0 }, .{ 10, 5, -2 }, false);
    try std.testing.expectEqual([3]f32{ 1, 0.5, -0.2 }, impulse);
}

test "item hook impulse includes upward arc" {
    const entity = computeFishingHookPullImpulse(.{ 0, 0, 0 }, .{ 3, 4, 0 }, false);
    const item = computeFishingHookPullImpulse(.{ 0, 0, 0 }, .{ 3, 4, 0 }, true);
    try std.testing.expect(item[1] > entity[1]);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), item[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), item[2], 0.001);
}
