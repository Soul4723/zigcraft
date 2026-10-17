const std = @import("std");

pub const BeaconPyramid = struct {
    tier_0_to_4: u3,
    total_mineral_blocks: u8,
    aura_radius_blocks: f32,
    buff_duration_seconds: f32,
};

/// Reports the highest uninterrupted, complete beacon pyramid tier.
pub fn validateBeaconPyramidTier(
    layer_3x3_complete: bool,
    layer_5x5_complete: bool,
    layer_7x7_complete: bool,
    layer_9x9_complete: bool,
) BeaconPyramid {
    var tier: u3 = 0;
    if (layer_3x3_complete) {
        tier = 1;
        if (layer_5x5_complete) {
            tier = 2;
            if (layer_7x7_complete) {
                tier = 3;
                if (layer_9x9_complete) tier = 4;
            }
        }
    }

    const blocks: u8 = switch (tier) {
        0 => 0,
        1 => 9,
        2 => 34,
        3 => 83,
        4 => 164,
        else => unreachable,
    };
    return .{
        .tier_0_to_4 = tier,
        .total_mineral_blocks = blocks,
        .aura_radius_blocks = switch (tier) {
            0 => 0.0,
            1 => 20.0,
            2 => 30.0,
            3 => 40.0,
            else => 50.0,
        },
        .buff_duration_seconds = if (tier == 0) 0.0 else 9.0 + 2.0 * @as(f32, @floatFromInt(tier)),
    };
}

pub const BeaconEffect = enum {
    speed,
    haste,
    resistance,
    jump_boost,
    strength,
    regeneration,
};

pub const BeaconPowerSelection = struct {
    valid: bool,
    primary_level: u2,
    has_regeneration_secondary: bool,
};

fn effectUnlocked(tier: u3, effect: BeaconEffect) bool {
    return switch (effect) {
        .speed, .haste => tier >= 1,
        .resistance, .jump_boost => tier >= 2,
        .strength => tier >= 3,
        .regeneration => false,
    };
}

pub fn validateBeaconPowerSelection(
    pyramid_tier_0_to_4: u3,
    primary_power: BeaconEffect,
    wants_level_2_primary: bool,
    wants_secondary_regeneration: bool,
) BeaconPowerSelection {
    if (pyramid_tier_0_to_4 == 0 or pyramid_tier_0_to_4 > 4 or !effectUnlocked(pyramid_tier_0_to_4, primary_power)) {
        return .{ .valid = false, .primary_level = 0, .has_regeneration_secondary = false };
    }

    if (wants_level_2_primary) {
        // The Level II primary option is the speed/haste choice; it excludes regeneration.
        const eligible = primary_power == .speed or primary_power == .haste;
        if (pyramid_tier_0_to_4 != 4 or !eligible or wants_secondary_regeneration) {
            return .{ .valid = false, .primary_level = 0, .has_regeneration_secondary = false };
        }
        return .{ .valid = true, .primary_level = 2, .has_regeneration_secondary = false };
    }

    if (wants_secondary_regeneration and pyramid_tier_0_to_4 != 4) {
        return .{ .valid = false, .primary_level = 0, .has_regeneration_secondary = false };
    }
    return .{
        .valid = true,
        .primary_level = 1,
        .has_regeneration_secondary = wants_secondary_regeneration,
    };
}

pub fn canBeaconBeamPassThroughBlock(
    block_is_transparent_glass_or_water: bool,
    block_is_bedrock: bool,
    block_is_tinted_glass: bool,
) bool {
    if (block_is_tinted_glass) return false;
    return block_is_transparent_glass_or_water or block_is_bedrock;
}

pub fn blendBeaconBeamStainedGlassColors(glass_colors_bottom_to_top: []const [3]f32) [3]f32 {
    if (glass_colors_bottom_to_top.len == 0) return .{ 1.0, 1.0, 1.0 };
    var color = glass_colors_bottom_to_top[0];
    for (glass_colors_bottom_to_top[1..]) |next| {
        color = .{
            (color[0] + next[0]) * 0.5,
            (color[1] + next[1]) * 0.5,
            (color[2] + next[2]) * 0.5,
        };
    }
    return color;
}

test "pyramid geometry has expected counts, radii, and refresh durations" {
    const cases = [_]struct { tier: u3, blocks: u8, radius: f32, duration: f32 }{
        .{ .tier = 0, .blocks = 0, .radius = 0.0, .duration = 0.0 },
        .{ .tier = 1, .blocks = 9, .radius = 20.0, .duration = 11.0 },
        .{ .tier = 2, .blocks = 34, .radius = 30.0, .duration = 13.0 },
        .{ .tier = 3, .blocks = 83, .radius = 40.0, .duration = 15.0 },
        .{ .tier = 4, .blocks = 164, .radius = 50.0, .duration = 17.0 },
    };
    for (cases) |case| {
        const result = validateBeaconPyramidTier(case.tier >= 1, case.tier >= 2, case.tier >= 3, case.tier >= 4);
        try std.testing.expectEqual(case.tier, result.tier_0_to_4);
        try std.testing.expectEqual(case.blocks, result.total_mineral_blocks);
        try std.testing.expectEqual(case.radius, result.aura_radius_blocks);
        try std.testing.expectEqual(case.duration, result.buff_duration_seconds);
    }
}

test "incomplete layers do not count without the layer below" {
    const tier = validateBeaconPyramidTier(false, true, true, true);
    try std.testing.expectEqual(@as(u3, 0), tier.tier_0_to_4);
    try std.testing.expectEqual(@as(u8, 0), tier.total_mineral_blocks);
}

test "layer gaps stop pyramid at the last consecutive complete layer" {
    const tier = validateBeaconPyramidTier(true, false, true, true);
    try std.testing.expectEqual(@as(u3, 1), tier.tier_0_to_4);
    try std.testing.expectEqual(@as(u8, 9), tier.total_mineral_blocks);
}

test "tier one unlocks speed and haste at level one" {
    for ([_]BeaconEffect{ .speed, .haste }) |effect| {
        const result = validateBeaconPowerSelection(1, effect, false, false);
        try std.testing.expect(result.valid);
        try std.testing.expectEqual(@as(u2, 1), result.primary_level);
    }
}

test "tier one rejects higher-tier effects" {
    try std.testing.expect(!validateBeaconPowerSelection(1, .resistance, false, false).valid);
    try std.testing.expect(!validateBeaconPowerSelection(1, .jump_boost, false, false).valid);
    try std.testing.expect(!validateBeaconPowerSelection(1, .strength, false, false).valid);
}

test "tier two unlocks resistance and jump boost" {
    try std.testing.expect(validateBeaconPowerSelection(2, .resistance, false, false).valid);
    try std.testing.expect(validateBeaconPowerSelection(2, .jump_boost, false, false).valid);
}

test "tier two rejects strength" {
    try std.testing.expect(!validateBeaconPowerSelection(2, .strength, false, false).valid);
}

test "tier three unlocks strength" {
    try std.testing.expect(validateBeaconPowerSelection(3, .strength, false, false).valid);
}

test "tier four selects level two haste without regeneration" {
    const result = validateBeaconPowerSelection(4, .haste, true, false);
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u2, 2), result.primary_level);
    try std.testing.expect(!result.has_regeneration_secondary);
}

test "tier four selects level two speed without regeneration" {
    const result = validateBeaconPowerSelection(4, .speed, true, false);
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u2, 2), result.primary_level);
}

test "tier four selects level one primary plus regeneration" {
    const result = validateBeaconPowerSelection(4, .strength, false, true);
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u2, 1), result.primary_level);
    try std.testing.expect(result.has_regeneration_secondary);
}

test "tier four rejects simultaneous level two and regeneration" {
    try std.testing.expect(!validateBeaconPowerSelection(4, .haste, true, true).valid);
}

test "lower tiers reject level two and regeneration secondary" {
    try std.testing.expect(!validateBeaconPowerSelection(3, .haste, true, false).valid);
    try std.testing.expect(!validateBeaconPowerSelection(3, .haste, false, true).valid);
}

test "beam passes transparent glass water and bedrock but not opaque or tinted glass" {
    try std.testing.expect(canBeaconBeamPassThroughBlock(true, false, false));
    try std.testing.expect(canBeaconBeamPassThroughBlock(false, true, false));
    try std.testing.expect(!canBeaconBeamPassThroughBlock(false, false, false));
    try std.testing.expect(!canBeaconBeamPassThroughBlock(true, false, true));
    try std.testing.expect(!canBeaconBeamPassThroughBlock(false, true, true));
}

test "stained glass colors are averaged from bottom to top" {
    const colors = [_][3]f32{ .{ 1.0, 0.0, 0.0 }, .{ 0.0, 0.0, 1.0 }, .{ 0.0, 1.0, 0.0 } };
    const result = blendBeaconBeamStainedGlassColors(&colors);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), result[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), result[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), result[2], 0.0001);
}

test "no stained glass leaves beam white and one glass sets its color" {
    try std.testing.expectEqual([3]f32{ 1.0, 1.0, 1.0 }, blendBeaconBeamStainedGlassColors(&.{}));
    const one = [_][3]f32{.{ 0.2, 0.4, 0.8 }};
    try std.testing.expectEqual(one[0], blendBeaconBeamStainedGlassColors(&one));
}
