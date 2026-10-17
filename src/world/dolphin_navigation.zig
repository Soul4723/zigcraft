const std = @import("std");

pub const max_air_supply_seconds: f32 = 240.0;
pub const max_moisture_seconds: f32 = 120.0;
pub const drowning_damage_per_second: f32 = 2.0;
pub const dry_out_damage_per_second: f32 = 2.0;
pub const dolphins_grace_multiplier: f32 = 2.45;
pub const dolphins_grace_duration_seconds: f32 = 5.0;
pub const dolphins_grace_radius: f32 = 9.0;

pub const DolphinState = struct {
    air_supply_seconds: f32 = max_air_supply_seconds,
    moisture_seconds: f32 = max_moisture_seconds,
    fed_raw_fish: bool = false,
    target_structure_pos: ?[3]i32 = null,
    health: f32 = 10.0,
};

/// Feeding raw cod or salmon makes the dolphin seek nearby shipwreck/ocean ruin treasure.
/// The caller supplies the chosen structure waypoint and emits happy particles on success.
pub fn feedDolphinRawFish(state: *DolphinState, held_is_raw_cod_or_salmon: bool, nearest_shipwreck_or_ruin_pos: [3]i32) bool {
    if (!held_is_raw_cod_or_salmon) return false;
    state.fed_raw_fish = true;
    state.target_structure_pos = nearest_shipwreck_or_ruin_pos;
    return true;
}

/// Depth Strider improves water movement by roughly one third per level; Dolphin's Grace
/// multiplies the resulting velocity by 2.45 (e.g. 4 m/s becomes 9.8 m/s).
pub fn computeDolphinsGraceSwimSpeed(base_swim_speed: f32, depth_strider_level: u2, has_dolphins_grace: bool) f32 {
    const stride_efficiency = 1.0 + @as(f32, @floatFromInt(depth_strider_level)) / 3.0;
    const grace_multiplier: f32 = if (has_dolphins_grace) dolphins_grace_multiplier else 1.0;
    return base_swim_speed * stride_efficiency * grace_multiplier;
}

/// Updates independent air and moisture reserves and returns damage dealt this tick.
pub fn tickDolphinBreathAndMoisture(state: *DolphinState, submerged_in_water: bool, breathing_air_at_surface: bool, in_rain: bool, dt: f32) f32 {
    const delta = @max(dt, 0.0);
    var damage: f32 = 0.0;

    if (!submerged_in_water or breathing_air_at_surface) {
        state.air_supply_seconds = max_air_supply_seconds;
    } else {
        const before = state.air_supply_seconds;
        state.air_supply_seconds = @max(0.0, before - delta);
        const exhausted_seconds = @max(0.0, delta - before);
        damage += exhausted_seconds * drowning_damage_per_second;
    }

    if (submerged_in_water or in_rain) {
        state.moisture_seconds = max_moisture_seconds;
    } else {
        const before = state.moisture_seconds;
        state.moisture_seconds = @max(0.0, before - delta);
        const exhausted_seconds = @max(0.0, delta - before);
        damage += exhausted_seconds * dry_out_damage_per_second;
    }

    state.health = @max(0.0, state.health - damage);
    return damage;
}

test "raw cod is accepted and establishes shipwreck waypoint" {
    var dolphin = DolphinState{};
    const waypoint = [3]i32{ 10, 20, 30 };
    try std.testing.expect(feedDolphinRawFish(&dolphin, true, waypoint));
    try std.testing.expect(dolphin.fed_raw_fish);
    try std.testing.expectEqual(waypoint, dolphin.target_structure_pos.?);
}

test "raw salmon is accepted and establishes ruin waypoint" {
    var dolphin = DolphinState{};
    const waypoint = [3]i32{ -4, 5, 9 };
    try std.testing.expect(feedDolphinRawFish(&dolphin, true, waypoint));
    try std.testing.expectEqual(waypoint, dolphin.target_structure_pos.?);
}

test "cooked fish is rejected without changing dolphin navigation" {
    var dolphin = DolphinState{};
    try std.testing.expect(!feedDolphinRawFish(&dolphin, false, .{ 1, 2, 3 }));
    try std.testing.expect(!dolphin.fed_raw_fish);
    try std.testing.expectEqual(@as(?[3]i32, null), dolphin.target_structure_pos);
}

test "feeding updates prior waypoint to nearest structure" {
    var dolphin = DolphinState{ .fed_raw_fish = true, .target_structure_pos = .{ 1, 1, 1 } };
    try std.testing.expect(feedDolphinRawFish(&dolphin, true, .{ 8, 0, -2 }));
    try std.testing.expectEqual([3]i32{ 8, 0, -2 }, dolphin.target_structure_pos.?);
}

test "dolphin defaults model four minute air and two minute moisture" {
    const dolphin = DolphinState{};
    try std.testing.expectApproxEqAbs(@as(f32, 240), dolphin.air_supply_seconds, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 120), dolphin.moisture_seconds, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10), dolphin.health, 0.001);
}

test "Depth Strider III doubles swim speed without grace" {
    try std.testing.expectApproxEqAbs(@as(f32, 8), computeDolphinsGraceSwimSpeed(4, 3, false), 0.001);
}

test "Dolphin's Grace multiplies swim velocity by 2.45" {
    try std.testing.expectApproxEqAbs(@as(f32, 9.8), computeDolphinsGraceSwimSpeed(4, 0, true), 0.001);
}

test "Depth Strider III and grace combine multiplicatively" {
    try std.testing.expectApproxEqAbs(@as(f32, 19.6), computeDolphinsGraceSwimSpeed(4, 3, true), 0.001);
}

test "Depth Strider levels provide one third stride efficiency each" {
    try std.testing.expectApproxEqAbs(@as(f32, 4.0 * 4.0 / 3.0), computeDolphinsGraceSwimSpeed(4, 1, false), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0 * 5.0 / 3.0), computeDolphinsGraceSwimSpeed(4, 2, false), 0.001);
}

test "surface air access refills a partially depleted supply" {
    var dolphin = DolphinState{ .air_supply_seconds = 25 };
    _ = tickDolphinBreathAndMoisture(&dolphin, true, true, false, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 240), dolphin.air_supply_seconds, 0.001);
}

test "land refills air even though dry land drains moisture" {
    var dolphin = DolphinState{ .air_supply_seconds = 2, .moisture_seconds = 120 };
    _ = tickDolphinBreathAndMoisture(&dolphin, false, false, false, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 240), dolphin.air_supply_seconds, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 117), dolphin.moisture_seconds, 0.001);
}

test "four minutes submerged consumes all air without damage before exhaustion" {
    var dolphin = DolphinState{};
    const damage = tickDolphinBreathAndMoisture(&dolphin, true, false, false, 240);
    try std.testing.expectApproxEqAbs(@as(f32, 0), damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), dolphin.air_supply_seconds, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10), dolphin.health, 0.001);
}

test "ice trapped dolphin takes two damage per second after air expires" {
    var dolphin = DolphinState{};
    _ = tickDolphinBreathAndMoisture(&dolphin, true, false, false, 240);
    const damage = tickDolphinBreathAndMoisture(&dolphin, true, false, false, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 6), damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4), dolphin.health, 0.001);
}

test "water surface air access prevents drowning" {
    var dolphin = DolphinState{ .air_supply_seconds = 0 };
    const damage = tickDolphinBreathAndMoisture(&dolphin, true, true, false, 10);
    try std.testing.expectApproxEqAbs(@as(f32, 0), damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 240), dolphin.air_supply_seconds, 0.001);
}

test "dry land moisture lasts 120 seconds before damage" {
    var dolphin = DolphinState{};
    const damage = tickDolphinBreathAndMoisture(&dolphin, false, false, false, 120);
    try std.testing.expectApproxEqAbs(@as(f32, 0), damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), dolphin.moisture_seconds, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10), dolphin.health, 0.001);
}

test "dry-out damage begins after moisture reserve is exhausted" {
    var dolphin = DolphinState{};
    _ = tickDolphinBreathAndMoisture(&dolphin, false, false, false, 120);
    const damage = tickDolphinBreathAndMoisture(&dolphin, false, false, false, 2.5);
    try std.testing.expectApproxEqAbs(@as(f32, 5), damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5), dolphin.health, 0.001);
}

test "rain refills moisture while dry-land air remains replenished" {
    var dolphin = DolphinState{ .moisture_seconds = 5, .air_supply_seconds = 1 };
    _ = tickDolphinBreathAndMoisture(&dolphin, false, false, true, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 120), dolphin.moisture_seconds, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 240), dolphin.air_supply_seconds, 0.001);
}

test "damage cannot reduce health below zero" {
    var dolphin = DolphinState{ .health = 1, .air_supply_seconds = 0 };
    _ = tickDolphinBreathAndMoisture(&dolphin, true, false, false, 4);
    try std.testing.expectApproxEqAbs(@as(f32, 0), dolphin.health, 0.001);
}
