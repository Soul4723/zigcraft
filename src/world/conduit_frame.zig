const std = @import("std");

/// Blocks that can contribute to a Conduit's orthogonal frame rings.
pub const ConduitFrameBlock = enum {
    prismarine,
    dark_prismarine,
    prismarine_bricks,
    sea_lantern,
};

pub const minimum_frame_blocks: u8 = 16;
pub const full_frame_blocks: u8 = 42;
pub const conduit_power_mining_multiplier: f32 = 1.167;
pub const hostile_zap_radius: f32 = 8.0;
pub const hostile_zap_interval: f32 = 2.0;
pub const hostile_zap_damage: f32 = 4.0;

pub const ConduitActivation = struct {
    is_active: bool,
    eye_hunting_open: bool,
    aura_radius: f32,
};

/// Evaluates the conduit using the water volume and valid blocks found in its rings.
/// Each additional group of seven frame blocks increases range by 16 blocks.
pub fn evaluateConduitActivation(
    surrounded_by_3x3x3_water: bool,
    valid_ring_block_count: u8,
) ConduitActivation {
    const active = surrounded_by_3x3x3_water and valid_ring_block_count >= minimum_frame_blocks;
    if (!active) return .{ .is_active = false, .eye_hunting_open = false, .aura_radius = 0.0 };

    const clamped_count = @min(valid_ring_block_count, full_frame_blocks);
    const tier: u8 = if (clamped_count >= 42) 4 else if (clamped_count >= 35) 3 else if (clamped_count >= 28) 2 else if (clamped_count >= 21) 1 else 0;
    const radius = 32.0 + @as(f32, @floatFromInt(tier)) * 16.0;
    return .{
        .is_active = true,
        .eye_hunting_open = clamped_count >= full_frame_blocks,
        .aura_radius = radius,
    };
}

pub const ConduitPowerBuff = struct {
    restores_oxygen: bool,
    grants_underwater_night_vision: bool,
    mining_speed_multiplier: f32,
};

/// Computes the conduit power effects for a player in its water/rain aura.
pub fn computeConduitPowerBuff(
    is_active: bool,
    player_in_water_or_rain: bool,
    distance_sq: f32,
    aura_radius: f32,
) ConduitPowerBuff {
    const in_aura = is_active and player_in_water_or_rain and aura_radius > 0.0 and
        distance_sq >= 0.0 and distance_sq <= aura_radius * aura_radius;
    return .{
        .restores_oxygen = in_aura,
        .grants_underwater_night_vision = in_aura,
        .mining_speed_multiplier = if (in_aura) conduit_power_mining_multiplier else 1.0,
    };
}

/// Advances the zap timer and returns damage dealt this tick (zero or 4 damage).
/// The caller supplies hostile-mob eligibility; this function handles only range,
/// water/rain, activation of the hunting eye, and the two-second cadence.
pub fn tickConduitHostileZap(
    eye_hunting_open: bool,
    distance_to_conduit: f32,
    target_in_water_or_rain: bool,
    zap_timer: *f32,
    dt: f32,
) f32 {
    if (!eye_hunting_open or !target_in_water_or_rain or distance_to_conduit < 0.0 or
        distance_to_conduit > hostile_zap_radius or dt <= 0.0)
    {
        return 0.0;
    }

    zap_timer.* += dt;
    if (zap_timer.* < hostile_zap_interval) return 0.0;

    zap_timer.* -= hostile_zap_interval;
    return hostile_zap_damage;
}

test "ConduitFrameBlock includes the four valid frame materials" {
    const blocks = [_]ConduitFrameBlock{
        .prismarine,
        .dark_prismarine,
        .prismarine_bricks,
        .sea_lantern,
    };
    try std.testing.expectEqual(@as(usize, 4), blocks.len);
}

test "water volume is required for conduit activation" {
    const result = evaluateConduitActivation(false, 42);
    try std.testing.expect(!result.is_active);
    try std.testing.expect(!result.eye_hunting_open);
    try std.testing.expectEqual(@as(f32, 0.0), result.aura_radius);
}

test "fewer than sixteen frame blocks does not activate" {
    try std.testing.expect(!evaluateConduitActivation(true, 15).is_active);
    try std.testing.expectEqual(@as(f32, 0.0), evaluateConduitActivation(true, 15).aura_radius);
}

test "sixteen frame blocks activate at 32 metres" {
    const result = evaluateConduitActivation(true, 16);
    try std.testing.expect(result.is_active);
    try std.testing.expectEqual(@as(f32, 32.0), result.aura_radius);
    try std.testing.expect(!result.eye_hunting_open);
}

test "twenty frame blocks remain at the first radius tier" {
    try std.testing.expectEqual(@as(f32, 32.0), evaluateConduitActivation(true, 20).aura_radius);
}

test "twenty-one frame blocks scale radius to 48 metres" {
    try std.testing.expectEqual(@as(f32, 48.0), evaluateConduitActivation(true, 21).aura_radius);
}

test "twenty-eight frame blocks scale radius to 64 metres" {
    try std.testing.expectEqual(@as(f32, 64.0), evaluateConduitActivation(true, 28).aura_radius);
}

test "thirty-five frame blocks scale radius to 80 metres" {
    try std.testing.expectEqual(@as(f32, 80.0), evaluateConduitActivation(true, 35).aura_radius);
}

test "forty-two frame blocks scale radius to 96 metres and open eye" {
    const result = evaluateConduitActivation(true, 42);
    try std.testing.expectEqual(@as(f32, 96.0), result.aura_radius);
    try std.testing.expect(result.eye_hunting_open);
}

test "frame count above full frame is capped" {
    const result = evaluateConduitActivation(true, 255);
    try std.testing.expectEqual(@as(f32, 96.0), result.aura_radius);
    try std.testing.expect(result.eye_hunting_open);
}

test "conduit power restores oxygen grants vision and speeds mining in water" {
    const buff = computeConduitPowerBuff(true, true, 100.0, 32.0);
    try std.testing.expect(buff.restores_oxygen);
    try std.testing.expect(buff.grants_underwater_night_vision);
    try std.testing.expectEqual(conduit_power_mining_multiplier, buff.mining_speed_multiplier);
}

test "conduit power applies in rain within aura" {
    const buff = computeConduitPowerBuff(true, true, 96.0, 32.0);
    try std.testing.expect(buff.restores_oxygen);
    try std.testing.expect(buff.grants_underwater_night_vision);
    try std.testing.expectEqual(@as(f32, 1.167), buff.mining_speed_multiplier);
}

test "conduit power does not apply outside aura or without water or rain" {
    const outside = computeConduitPowerBuff(true, true, 1024.1, 32.0);
    try std.testing.expect(!outside.restores_oxygen);
    try std.testing.expect(!outside.grants_underwater_night_vision);
    try std.testing.expectEqual(@as(f32, 1.0), outside.mining_speed_multiplier);

    const dry = computeConduitPowerBuff(true, false, 0.0, 32.0);
    try std.testing.expect(!dry.restores_oxygen);
}

test "conduit power does not apply when inactive" {
    const buff = computeConduitPowerBuff(false, true, 0.0, 96.0);
    try std.testing.expect(!buff.restores_oxygen);
    try std.testing.expectEqual(@as(f32, 1.0), buff.mining_speed_multiplier);
}

test "hunting eye zaps eligible hostile targets every two seconds within eight metres" {
    var timer: f32 = 0.0;
    try std.testing.expectEqual(@as(f32, 0.0), tickConduitHostileZap(true, 8.0, true, &timer, 1.0));
    try std.testing.expectEqual(@as(f32, 4.0), tickConduitHostileZap(true, 7.0, true, &timer, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), timer);
}

test "hostile zap requires full frame, range and target in water or rain" {
    var timer: f32 = 0.0;
    try std.testing.expectEqual(@as(f32, 0.0), tickConduitHostileZap(false, 4.0, true, &timer, 2.0));
    try std.testing.expectEqual(@as(f32, 0.0), tickConduitHostileZap(true, 8.01, true, &timer, 2.0));
    try std.testing.expectEqual(@as(f32, 0.0), tickConduitHostileZap(true, 4.0, false, &timer, 2.0));
    try std.testing.expectEqual(@as(f32, 0.0), timer);
}
