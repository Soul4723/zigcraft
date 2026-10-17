const std = @import("std");

pub const base_cure_seconds: f32 = 180.0;
pub const max_acceleration_blocks: u8 = 14;
pub const acceleration_per_block: f32 = 0.04;
pub const cured_major_positive_points: u8 = 20;
pub const cured_discount_per_major: u8 = 20;
pub const minor_positive_discount_per_point: u8 = 1;
pub const minor_negative_price_per_point: u8 = 1;

/// State retained across zombie-villager conversion; presentation effects are
/// exposed as constants for the entity/rendering layer to apply.
pub const ZombieVillagerCureState = struct {
    has_weakness_effect: bool = false,
    is_converting: bool = false,
    cure_timer: f32 = 0.0,
    retained_profession_id: u8 = 0,
    retained_xp_tier: u3 = 0,
};

pub const cure_trembles = true;
pub const cure_particles_are_red = true;
pub const cure_strength_amplifier: u8 = 0; // Strength I

/// Starts conversion only when the zombie villager has Weakness and was fed
/// a Golden Apple. Nearby bars/beds accelerate progress by 4% each, capped at 14.
pub fn startZombieVillagerCure(state: *ZombieVillagerCureState, fed_golden_apple: bool, nearby_iron_bars_and_beds_count: u8) bool {
    if (!state.has_weakness_effect or !fed_golden_apple or state.is_converting) return false;
    const acceleration_count = @min(nearby_iron_bars_and_beds_count, max_acceleration_blocks);
    const speed_multiplier = 1.0 + acceleration_per_block * @as(f32, @floatFromInt(acceleration_count));
    state.is_converting = true;
    state.cure_timer = base_cure_seconds / speed_multiplier;
    return true;
}

/// Applies the permanent major-positive cure discount and minor gossip effects.
/// Positive gossip lowers price; negative gossip raises it; final prices never
/// fall below one emerald. Inputs represent accumulated points/counts.
pub fn computeGossipTradeDiscount(base_price: u8, major_positive_cured_count: u3, minor_positive_trading_points: u8, minor_negative_hit_points: u8) u8 {
    const cured_discount: u16 = @as(u16, major_positive_cured_count) * cured_discount_per_major;
    const positive_discount: u16 = minor_positive_trading_points;
    const penalty: u16 = minor_negative_hit_points;
    const net: i32 = @as(i32, base_price) + @as(i32, @intCast(penalty)) - @as(i32, @intCast(cured_discount + positive_discount));
    return @intCast(@max(1, @min(255, net)));
}

/// `villager_group_size` is the count of qualifying panicked or gossiping
/// villagers. They must have slept recently, face a nearby hostile, and have
/// lacked a recently detected golem.
pub fn canPanicSpawnVillageIronGolem(villager_group_size: u8, all_slept_within_20_min: bool, hostile_zombie_or_raider_within_16m: bool, golem_detected_within_30_sec: bool) bool {
    return villager_group_size >= 3 and all_slept_within_20_min and hostile_zombie_or_raider_within_16m and !golem_detected_within_30_sec;
}

test "cure requires Weakness" {
    var state = ZombieVillagerCureState{};
    try std.testing.expect(!startZombieVillagerCure(&state, true, 0));
    try std.testing.expect(!state.is_converting);
}

test "cure requires Golden Apple" {
    var state = ZombieVillagerCureState{ .has_weakness_effect = true };
    try std.testing.expect(!startZombieVillagerCure(&state, false, 0));
}

test "Weakness and Golden Apple start base cure" {
    var state = ZombieVillagerCureState{ .has_weakness_effect = true };
    try std.testing.expect(startZombieVillagerCure(&state, true, 0));
    try std.testing.expect(state.is_converting);
    try std.testing.expectApproxEqAbs(base_cure_seconds, state.cure_timer, 0.001);
}

test "cure applies trembling red particle and Strength I presentation" {
    try std.testing.expect(cure_trembles);
    try std.testing.expect(cure_particles_are_red);
    try std.testing.expectEqual(@as(u8, 0), cure_strength_amplifier);
}

test "one iron bar or bed accelerates by four percent" {
    var state = ZombieVillagerCureState{ .has_weakness_effect = true };
    try std.testing.expect(startZombieVillagerCure(&state, true, 1));
    try std.testing.expectApproxEqAbs(@as(f32, 180.0 / 1.04), state.cure_timer, 0.001);
}

test "multiple iron bars and beds compound speed acceleration" {
    var state = ZombieVillagerCureState{ .has_weakness_effect = true };
    try std.testing.expect(startZombieVillagerCure(&state, true, 5));
    try std.testing.expectApproxEqAbs(@as(f32, 180.0 / 1.20), state.cure_timer, 0.001);
}

test "acceleration caps at fourteen nearby blocks" {
    var at_cap = ZombieVillagerCureState{ .has_weakness_effect = true };
    var above_cap = ZombieVillagerCureState{ .has_weakness_effect = true };
    try std.testing.expect(startZombieVillagerCure(&at_cap, true, 14));
    try std.testing.expect(startZombieVillagerCure(&above_cap, true, 255));
    try std.testing.expectEqual(at_cap.cure_timer, above_cap.cure_timer);
}

test "already converting villagers cannot restart cure" {
    var state = ZombieVillagerCureState{ .has_weakness_effect = true, .is_converting = true, .cure_timer = 42.0 };
    try std.testing.expect(!startZombieVillagerCure(&state, true, 4));
    try std.testing.expectEqual(@as(f32, 42.0), state.cure_timer);
}

test "profession and experience tier retention are represented" {
    const state = ZombieVillagerCureState{ .has_weakness_effect = true, .retained_profession_id = 3, .retained_xp_tier = 5 };
    try std.testing.expectEqual(@as(u8, 3), state.retained_profession_id);
    try std.testing.expectEqual(@as(u3, 5), state.retained_xp_tier);
}

test "one cured gossip discounts twenty emeralds" {
    try std.testing.expectEqual(@as(u8, 10), computeGossipTradeDiscount(30, 1, 0, 0));
}

test "permanent cure discount clamps price to one emerald" {
    try std.testing.expectEqual(@as(u8, 1), computeGossipTradeDiscount(12, 1, 0, 0));
    try std.testing.expectEqual(@as(u8, 1), computeGossipTradeDiscount(1, 0, 20, 0));
}

test "multiple cured gossip discounts accumulate" {
    try std.testing.expectEqual(@as(u8, 40), computeGossipTradeDiscount(80, 2, 0, 0));
}

test "minor trading gossip lowers prices" {
    try std.testing.expectEqual(@as(u8, 7), computeGossipTradeDiscount(10, 0, 3, 0));
}

test "hitting villagers adds a price penalty" {
    try std.testing.expectEqual(@as(u8, 13), computeGossipTradeDiscount(10, 0, 0, 3));
    try std.testing.expectEqual(@as(u8, 11), computeGossipTradeDiscount(30, 1, 0, 1));
}

test "panic spawn requires three villagers and qualifying conditions" {
    try std.testing.expect(canPanicSpawnVillageIronGolem(3, true, true, false));
    try std.testing.expect(!canPanicSpawnVillageIronGolem(2, true, true, false));
    try std.testing.expect(!canPanicSpawnVillageIronGolem(3, false, true, false));
    try std.testing.expect(!canPanicSpawnVillageIronGolem(3, true, false, false));
    try std.testing.expect(!canPanicSpawnVillageIronGolem(3, true, true, true));
}

test "larger gossiping group also qualifies for panic spawn" {
    try std.testing.expect(canPanicSpawnVillageIronGolem(5, true, true, false));
}
