const std = @import("std");

pub const WeatherState = enum {
    clear_sky,
    raining,
    thunderstorming,
};

pub const SleepResult = struct {
    can_sleep: bool,
    blocked_by_monsters: bool,
};

pub const Precipitation = enum {
    none,
    rain,
    snow,
};

pub const LightningResult = struct {
    final_strike_pos: [3]i32,
    diverted_to_rod: bool,
    redstone_signal_emitted: u4,
    deoxidized_copper_radius: u3,
};

pub const lightning_rod_range: f64 = 128.0;
pub const lightning_rod_redstone_ticks: u8 = 8;
pub const lightning_rod_copper_radius: u3 = 4;
pub const snow_accumulation_max_block_light: u4 = 9;

pub fn canPlayerSleepInBed(
    weather: WeatherState,
    time_of_day_ticks_0_to_24000: u16,
    monsters_within_8m_xz_5m_y: bool,
) SleepResult {
    const night = time_of_day_ticks_0_to_24000 >= 12_542 and
        time_of_day_ticks_0_to_24000 <= 23_459;
    const eligible_time = night or weather == .thunderstorming;
    const can_sleep = eligible_time and !monsters_within_8m_xz_5m_y;
    return .{
        .can_sleep = can_sleep,
        .blocked_by_monsters = eligible_time and monsters_within_8m_xz_5m_y,
    };
}

/// Chooses the nearest rod in the strike's horizontal (XZ) 128-block radius.
/// A rod strike emits signal strength 15 for 8 game ticks; copper deoxidizing
/// within radius 4 is exposed to the caller as an effect radius.
pub fn divertLightningToNearestRod(
    natural_strike_pos: [3]i32,
    lightning_rods: []const [3]i32,
) LightningResult {
    var result = LightningResult{
        .final_strike_pos = natural_strike_pos,
        .diverted_to_rod = false,
        .redstone_signal_emitted = 0,
        .deoxidized_copper_radius = 0,
    };
    var nearest_distance_squared: i64 = 128 * 128 + 1;
    for (lightning_rods) |rod| {
        const dx: i64 = @as(i64, rod[0]) - natural_strike_pos[0];
        const dz: i64 = @as(i64, rod[2]) - natural_strike_pos[2];
        const distance_squared = dx * dx + dz * dz;
        if (distance_squared <= 128 * 128 and distance_squared < nearest_distance_squared) {
            nearest_distance_squared = distance_squared;
            result.final_strike_pos = rod;
            result.diverted_to_rod = true;
        }
    }
    if (result.diverted_to_rod) {
        result.redstone_signal_emitted = 15;
        result.deoxidized_copper_radius = lightning_rod_copper_radius;
    }
    return result;
}

pub fn resolveBiomePrecipitation(
    biome_temperature: f32,
    y_altitude: i32,
    weather: WeatherState,
) Precipitation {
    if (weather == .clear_sky or biome_temperature > 0.95) return .none;
    const altitude_above_64 = @max(0, y_altitude - 64);
    const effective_temperature = biome_temperature - @as(f32, @floatFromInt(altitude_above_64)) * 0.0016;
    if (effective_temperature < 0.15) return .snow;
    return .rain;
}

/// Snow layers accumulate only in low-light conditions during snowfall.
pub fn canAccumulateSnowLayer(block_light: u4, precipitation: Precipitation) bool {
    return precipitation == .snow and block_light <= snow_accumulation_max_block_light;
}

/// Rain or snow extinguishes fire; clear weather does not.
pub fn doesPrecipitationExtinguishFire(precipitation: Precipitation) bool {
    return precipitation != .none;
}

test "night sleep is allowed at both bounds and inside the interval" {
    try std.testing.expect(canPlayerSleepInBed(.clear_sky, 12_542, false).can_sleep);
    try std.testing.expect(canPlayerSleepInBed(.raining, 18_000, false).can_sleep);
    try std.testing.expect(canPlayerSleepInBed(.clear_sky, 23_459, false).can_sleep);
}

test "sleep is denied just outside the night interval" {
    try std.testing.expect(!canPlayerSleepInBed(.clear_sky, 12_541, false).can_sleep);
    try std.testing.expect(!canPlayerSleepInBed(.clear_sky, 23_460, false).can_sleep);
}

test "thunderstorm allows daytime sleep" {
    try std.testing.expect(canPlayerSleepInBed(.thunderstorming, 6_000, false).can_sleep);
    try std.testing.expect(canPlayerSleepInBed(.thunderstorming, 24_000, false).can_sleep);
}

test "thunderstorm allows sleep across valid day ticks" {
    try std.testing.expect(canPlayerSleepInBed(.thunderstorming, 0, false).can_sleep);
    try std.testing.expect(canPlayerSleepInBed(.thunderstorming, 12_541, false).can_sleep);
}

test "nearby monsters block otherwise eligible sleep" {
    const night = canPlayerSleepInBed(.clear_sky, 18_000, true);
    try std.testing.expect(!night.can_sleep);
    try std.testing.expect(night.blocked_by_monsters);
}

test "nearby monsters also block thunderstorm daytime sleep" {
    const day = canPlayerSleepInBed(.thunderstorming, 6_000, true);
    try std.testing.expect(!day.can_sleep);
    try std.testing.expect(day.blocked_by_monsters);
}

test "monsters outside eligible sleep time do not report sleep blocking" {
    const result = canPlayerSleepInBed(.raining, 6_000, true);
    try std.testing.expect(!result.can_sleep);
    try std.testing.expect(!result.blocked_by_monsters);
}

test "nearest rod within horizontal 128 blocks diverts lightning" {
    const rods = [_][3]i32{ .{ 200, 0, 0 }, .{ 100, 300, 0 }, .{ 20, 0, 0 } };
    const result = divertLightningToNearestRod(.{ 0, 40, 0 }, &rods);
    try std.testing.expect(result.diverted_to_rod);
    try std.testing.expectEqual([3]i32{ 20, 0, 0 }, result.final_strike_pos);
}

test "rod exactly 128 horizontal blocks away qualifies" {
    const rods = [_][3]i32{.{ 128, 90, 0 }};
    const result = divertLightningToNearestRod(.{ 0, 0, 0 }, &rods);
    try std.testing.expect(result.diverted_to_rod);
}

test "rod beyond 128 horizontal blocks does not divert" {
    const rods = [_][3]i32{.{ 129, 0, 0 }};
    const result = divertLightningToNearestRod(.{ 0, 0, 0 }, &rods);
    try std.testing.expect(!result.diverted_to_rod);
    try std.testing.expectEqual([3]i32{ 0, 0, 0 }, result.final_strike_pos);
}

test "diverted strike emits full redstone pulse and copper radius" {
    const rods = [_][3]i32{.{ 0, 0, 0 }};
    const result = divertLightningToNearestRod(.{ 1, 0, 1 }, &rods);
    try std.testing.expectEqual(@as(u4, 15), result.redstone_signal_emitted);
    try std.testing.expectEqual(@as(u8, 8), lightning_rod_redstone_ticks);
    try std.testing.expectEqual(@as(u3, 4), result.deoxidized_copper_radius);
}

test "un diverted lightning has no rod effects" {
    const result = divertLightningToNearestRod(.{ 0, 0, 0 }, &.{});
    try std.testing.expectEqual(@as(u4, 0), result.redstone_signal_emitted);
    try std.testing.expectEqual(@as(u3, 0), result.deoxidized_copper_radius);
}

test "hot desert biome remains dry even during rain" {
    try std.testing.expectEqual(Precipitation.none, resolveBiomePrecipitation(0.96, 64, .raining));
    try std.testing.expectEqual(Precipitation.none, resolveBiomePrecipitation(1.0, 200, .thunderstorming));
}

test "cold biome precipitation is snow" {
    try std.testing.expectEqual(Precipitation.snow, resolveBiomePrecipitation(0.0, 64, .raining));
}

test "altitude temperature calculation crosses mountain snow line" {
    try std.testing.expectEqual(Precipitation.rain, resolveBiomePrecipitation(0.20, 64, .raining));
    try std.testing.expectEqual(Precipitation.snow, resolveBiomePrecipitation(0.20, 96, .raining));
}

test "clear sky never precipitates" {
    try std.testing.expectEqual(Precipitation.none, resolveBiomePrecipitation(0.0, 200, .clear_sky));
}

test "snow layers accumulate only below block light ten" {
    try std.testing.expect(canAccumulateSnowLayer(9, .snow));
    try std.testing.expect(!canAccumulateSnowLayer(10, .snow));
    try std.testing.expect(!canAccumulateSnowLayer(0, .rain));
}

test "rain extinguishes fire and dry weather does not" {
    try std.testing.expect(doesPrecipitationExtinguishFire(.rain));
    try std.testing.expect(doesPrecipitationExtinguishFire(.snow));
    try std.testing.expect(!doesPrecipitationExtinguishFire(.none));
}
