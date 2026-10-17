const std = @import("std");

pub const flower_nectar_time: f32 = 20.0;
pub const max_crops_per_trip: u4 = 10;
pub const sting_damage: f32 = 2.0;
pub const sting_poison_seconds: f32 = 10.0;
pub const post_sting_death_time: f32 = 50.0;

pub const BeePollinatorState = struct {
    has_nectar: bool = false,
    pollinating_flower_timer: f32 = 0.0,
    crops_fertilized_this_trip: u4 = 0,
    has_stung: bool = false,
    post_sting_death_timer: f32 = 0.0,
    is_angry: bool = false,
    health: f32 = 10.0,
};

/// Advances flower-homing time and collects nectar after 20 uninterrupted seconds.
pub fn tickFlowerPollination(state: *BeePollinatorState, over_flower: bool, dt: f32) bool {
    if (state.has_nectar or !over_flower) {
        if (!over_flower and !state.has_nectar) state.pollinating_flower_timer = 0.0;
        return false;
    }
    state.pollinating_flower_timer += dt;
    if (state.pollinating_flower_timer < flower_nectar_time) return false;
    state.pollinating_flower_timer = 0.0;
    state.has_nectar = true;
    state.crops_fertilized_this_trip = 0;
    return true;
}

/// Dripping pollen advances a crop with a 10% chance per eligible flight-over.
/// Crop growth is limited to ten successful fertilizations for the nectar trip.
pub fn tryPollinateCropBelowBee(
    state: *BeePollinatorState,
    flying_over_crop: bool,
    current_crop_stage: u3,
    max_crop_stage: u3,
    roll_0_to_99: u8,
) u3 {
    if (!state.has_nectar or !flying_over_crop or current_crop_stage >= max_crop_stage or
        state.crops_fertilized_this_trip >= max_crops_per_trip or roll_0_to_99 >= 10)
    {
        return current_crop_stage;
    }

    state.crops_fertilized_this_trip += 1;
    if (state.crops_fertilized_this_trip == max_crops_per_trip) state.has_nectar = false;
    return current_crop_stage + 1;
}

pub const StingResult = struct { damage: f32, poison_seconds: f32, lost_stinger: bool };

pub fn resolveBeeStingAttack(state: *BeePollinatorState) StingResult {
    if (!state.is_angry or state.has_stung) {
        return .{ .damage = 0.0, .poison_seconds = 0.0, .lost_stinger = false };
    }
    state.has_stung = true;
    state.is_angry = false;
    state.post_sting_death_timer = 0.0;
    return .{ .damage = sting_damage, .poison_seconds = sting_poison_seconds, .lost_stinger = true };
}

/// Returns true once the sting-loss death countdown has elapsed.
pub fn tickPostStingCountdown(state: *BeePollinatorState, dt: f32) bool {
    if (!state.has_stung) return false;
    state.post_sting_death_timer = @min(state.post_sting_death_timer + dt, post_sting_death_time);
    if (state.post_sting_death_timer >= post_sting_death_time) {
        state.health = 0.0;
        return true;
    }
    return false;
}

pub fn doesManualHiveHarvestAngerBees(
    campfire_within_5_blocks_below_unobstructed: bool,
    carpet_on_campfire: bool,
) bool {
    _ = carpet_on_campfire; // Carpet preserves smoke while preventing fire contact.
    return !campfire_within_5_blocks_below_unobstructed;
}

pub fn shouldBeeReturnToHive(is_night: bool, is_raining: bool, has_nectar: bool) bool {
    return is_night or is_raining or !has_nectar;
}

test "state defaults" {
    const state = BeePollinatorState{};
    try std.testing.expect(!state.has_nectar);
    try std.testing.expectEqual(@as(f32, 0.0), state.pollinating_flower_timer);
    try std.testing.expectEqual(@as(u4, 0), state.crops_fertilized_this_trip);
    try std.testing.expect(!state.has_stung);
    try std.testing.expectEqual(@as(f32, 0.0), state.post_sting_death_timer);
    try std.testing.expect(!state.is_angry);
    try std.testing.expectEqual(@as(f32, 10.0), state.health);
}

test "flower nectar collection takes twenty seconds" {
    var bee = BeePollinatorState{};
    try std.testing.expect(!tickFlowerPollination(&bee, true, 19.9));
    try std.testing.expect(!bee.has_nectar);
    try std.testing.expect(tickFlowerPollination(&bee, true, 0.1));
    try std.testing.expect(bee.has_nectar);
}

test "flower timer resets when bee leaves flower" {
    var bee = BeePollinatorState{ .pollinating_flower_timer = 12.0 };
    try std.testing.expect(!tickFlowerPollination(&bee, false, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), bee.pollinating_flower_timer);
}

test "flower collection does not restart while carrying nectar" {
    var bee = BeePollinatorState{ .has_nectar = true };
    try std.testing.expect(!tickFlowerPollination(&bee, true, 30.0));
    try std.testing.expectEqual(@as(f32, 0.0), bee.pollinating_flower_timer);
}

test "pollen roll advances eligible crop" {
    var bee = BeePollinatorState{ .has_nectar = true };
    try std.testing.expectEqual(@as(u3, 4), tryPollinateCropBelowBee(&bee, true, 3, 7, 9));
    try std.testing.expectEqual(@as(u4, 1), bee.crops_fertilized_this_trip);
}

test "pollen chance fails outside successful ten percent roll" {
    var bee = BeePollinatorState{ .has_nectar = true };
    try std.testing.expectEqual(@as(u3, 3), tryPollinateCropBelowBee(&bee, true, 3, 7, 10));
    try std.testing.expectEqual(@as(u4, 0), bee.crops_fertilized_this_trip);
}

test "pollen requires nectar and direct flight over crop" {
    var bee = BeePollinatorState{};
    try std.testing.expectEqual(@as(u3, 2), tryPollinateCropBelowBee(&bee, true, 2, 7, 0));
    bee.has_nectar = true;
    try std.testing.expectEqual(@as(u3, 2), tryPollinateCropBelowBee(&bee, false, 2, 7, 0));
}

test "pollen does not grow mature crops" {
    var bee = BeePollinatorState{ .has_nectar = true };
    try std.testing.expectEqual(@as(u3, 7), tryPollinateCropBelowBee(&bee, true, 7, 7, 0));
    try std.testing.expectEqual(@as(u4, 0), bee.crops_fertilized_this_trip);
}

test "ten successful crops exhaust nectar trip" {
    var bee = BeePollinatorState{ .has_nectar = true };
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        _ = tryPollinateCropBelowBee(&bee, true, 0, 7, 0);
    }
    try std.testing.expectEqual(max_crops_per_trip, bee.crops_fertilized_this_trip);
    try std.testing.expect(!bee.has_nectar);
    try std.testing.expectEqual(@as(u3, 0), tryPollinateCropBelowBee(&bee, true, 0, 7, 0));
}

test "angry bee sting deals damage poison and loses stinger" {
    var bee = BeePollinatorState{ .is_angry = true };
    const result = resolveBeeStingAttack(&bee);
    try std.testing.expectEqual(@as(f32, 2.0), result.damage);
    try std.testing.expectEqual(@as(f32, 10.0), result.poison_seconds);
    try std.testing.expect(result.lost_stinger);
    try std.testing.expect(bee.has_stung);
    try std.testing.expect(!bee.is_angry);
}

test "calm or already-stung bee cannot attack" {
    var bee = BeePollinatorState{};
    try std.testing.expectEqual(@as(f32, 0.0), resolveBeeStingAttack(&bee).damage);
    bee.is_angry = true;
    bee.has_stung = true;
    try std.testing.expect(!resolveBeeStingAttack(&bee).lost_stinger);
}

test "stinger-loss death countdown takes fifty seconds" {
    var bee = BeePollinatorState{ .has_stung = true };
    try std.testing.expect(!tickPostStingCountdown(&bee, 49.9));
    try std.testing.expectEqual(@as(f32, 49.9), bee.post_sting_death_timer);
    try std.testing.expect(tickPostStingCountdown(&bee, 0.1));
    try std.testing.expectEqual(@as(f32, 0.0), bee.health);
}

test "un-stung bee has no post-sting countdown" {
    var bee = BeePollinatorState{};
    try std.testing.expect(!tickPostStingCountdown(&bee, 100.0));
    try std.testing.expectEqual(@as(f32, 0.0), bee.post_sting_death_timer);
}

test "campfire smoke pacifies manual harvest within five blocks" {
    try std.testing.expect(!doesManualHiveHarvestAngerBees(true, false));
    try std.testing.expect(!doesManualHiveHarvestAngerBees(true, true));
    try std.testing.expect(doesManualHiveHarvestAngerBees(false, true));
}

test "campfire protection requires unobstructed campfire below" {
    try std.testing.expect(doesManualHiveHarvestAngerBees(false, false));
    try std.testing.expect(!doesManualHiveHarvestAngerBees(true, true));
}

test "bee returns to hive at night or in rain" {
    try std.testing.expect(shouldBeeReturnToHive(true, false, true));
    try std.testing.expect(shouldBeeReturnToHive(false, true, true));
    try std.testing.expect(!shouldBeeReturnToHive(false, false, true));
}

test "bee without nectar returns to hive" {
    try std.testing.expect(shouldBeeReturnToHive(false, false, false));
}
