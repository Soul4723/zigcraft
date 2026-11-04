const std = @import("std");

// --- Beacon Aura, Supercharge & Mineral Base Tags ---


pub const supercharge_duration: f32 = 300.0;
pub const haste_tier1_multiplier: f32 = 1.25;
pub const haste_tier2_multiplier: f32 = 1.40;
pub const regen_rate_per_sec: f32 = 0.5;

pub const IronBlockTag: u8 = 185;
pub const GoldBlockTag: u8 = 149;
pub const DiamondBlockTag: u8 = 151;
pub const EmeraldBlockTag: u8 = 157;

/// Checks whether a block tag represents an eligible beacon base mineral block.
pub fn isBeaconBaseBlock(block_tag: u8) bool {
    return block_tag == IronBlockTag or
        block_tag == GoldBlockTag or
        block_tag == DiamondBlockTag or
        block_tag == EmeraldBlockTag;
}

/// Returns the aura radius in blocks for a given pyramid level (0=0, 1=20, 2=30, 3=40, >=4=50).
pub fn auraRadiusForLevel(pyramid_level: u8) f32 {
    return switch (pyramid_level) {
        0 => 0.0,
        1 => 20.0,
        2 => 30.0,
        3 => 40.0,
        else => 50.0,
    };
}

/// Returns the Haste mining speed multiplier for a pyramid level and supercharged state.
pub fn hasteMultiplier(pyramid_level: u8, supercharged: bool) f32 {
    if (pyramid_level == 0) return 1.0;
    if (supercharged or pyramid_level >= 2) return haste_tier2_multiplier;
    return haste_tier1_multiplier;
}

/// Regenerates health for a player within beacon aura range.
pub fn tickBeaconRegen(current_hp: f32, max_hp: f32, pyramid_level: u8, dt: f32) f32 {
    if (pyramid_level == 0 or current_hp <= 0.0) return current_hp;
    return @min(max_hp, current_hp + regen_rate_per_sec * dt);
}


// --- Pyramid Geometry & Layer Tier Validation ---


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

/// Validates primary and secondary power selection against pyramid tier.
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

/// Checks if a beacon beam can pass through a block (transparent glass, water, bedrock pass; tinted glass obstructs).
pub fn canBeaconBeamPassThroughBlock(
    block_is_transparent_glass_or_water: bool,
    block_is_bedrock: bool,
    block_is_tinted_glass: bool,
) bool {
    if (block_is_tinted_glass) return false;
    return block_is_transparent_glass_or_water or block_is_bedrock;
}

/// Blends beam RGB color through multiple layers of stained glass from bottom to top.
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


// --- Status Pyramids, Powers & Payment Activation ---


pub const TICKS_PER_SECOND: u32 = 20;
pub const PULSE_INTERVAL_TICKS: u32 = 80;
pub const PRIMARY_POWER_COUNT: usize = 5;

pub const MineralBlock = enum {
    iron,
    gold,
    diamond,
    netherite,
    emerald,
    other,
};

pub const PaymentItem = enum {
    iron_ingot,
    gold_ingot,
    diamond,
    emerald,
    netherite_ingot,
    other,
};

pub const PrimaryPower = enum {
    speed,
    haste,
    resistance,
    jump_boost,
    strength,
};

pub const SecondaryPower = enum {
    regeneration,
    level_2_amplifier,
};

pub const Tier = enum(u8) { one = 1, two = 2, three = 3, four = 4 };

pub const TierProperties = struct {
    layer_sides: []const u8,
    block_count: u16,
    range_meters: f32,
    primary_power_count: u8,
};

const tier_one_sides = [_]u8{3};
const tier_two_sides = [_]u8{ 5, 3 };
const tier_three_sides = [_]u8{ 7, 5, 3 };
const tier_four_sides = [_]u8{ 9, 7, 5, 3 };

/// Returns the layer side dimensions, total block count, effect range, and primary power count for a pyramid tier.
pub fn tierProperties(tier: Tier) TierProperties {
    return switch (tier) {
        .one => .{ .layer_sides = &tier_one_sides, .block_count = 9, .range_meters = 20.0, .primary_power_count = 1 },
        .two => .{ .layer_sides = &tier_two_sides, .block_count = 34, .range_meters = 30.0, .primary_power_count = 2 },
        .three => .{ .layer_sides = &tier_three_sides, .block_count = 83, .range_meters = 40.0, .primary_power_count = 3 },
        .four => .{ .layer_sides = &tier_four_sides, .block_count = 164, .range_meters = 50.0, .primary_power_count = PRIMARY_POWER_COUNT },
    };
}

/// Checks if a mineral block is eligible for beacon pyramid construction.
pub fn isMineralBlock(block: MineralBlock) bool {
    return block != .other;
}

pub const PyramidLayer = struct {
    side: u8,
    blocks: []const MineralBlock,
};

pub const Pyramid = struct {
    tier: Tier,
    block_count: u16,
    range_meters: f32,
    is_sky_clear: bool,
};

/// Layers are ordered from the widest bottom layer to the 3x3 layer beneath
/// the beacon. Every layer must be a complete centered square of mineral blocks.
pub fn validatePyramid(layers: []const PyramidLayer, is_sky_clear: bool) ?Pyramid {
    if (!is_sky_clear) return null;
    const tier: Tier = switch (layers.len) {
        1 => .one,
        2 => .two,
        3 => .three,
        4 => .four,
        else => return null,
    };
    const properties = tierProperties(tier);
    var total_blocks: u16 = 0;
    for (layers, 0..) |layer, index| {
        const expected_side = properties.layer_sides[index];
        if (layer.side != expected_side) return null;
        const expected_block_count: usize = @as(usize, layer.side) * layer.side;
        if (layer.blocks.len != expected_block_count) return null;
        for (layer.blocks) |block| {
            if (!isMineralBlock(block)) return null;
        }
        total_blocks += @intCast(expected_block_count);
    }
    if (total_blocks != properties.block_count) return null;
    return .{
        .tier = tier,
        .block_count = total_blocks,
        .range_meters = properties.range_meters,
        .is_sky_clear = true,
    };
}

pub const PowerSelection = struct {
    primary: [PRIMARY_POWER_COUNT]PrimaryPower = undefined,
    primary_count: u8 = 0,
    secondary: ?SecondaryPower = null,
    amplified_primary: ?PrimaryPower = null,

    pub fn hasPrimary(self: PowerSelection, power: PrimaryPower) bool {
        for (self.primary[0..self.primary_count]) |selected| {
            if (selected == power) return true;
        }
        return false;
    }
};

/// Produces a stable selection only when the choices fit the tier. Tier IV
/// requires all five primaries and one secondary. The amplifier must name one
/// of the selected primaries; regeneration must not name an amplified primary.
pub fn selectPowers(
    tier: Tier,
    primary: []const PrimaryPower,
    secondary: ?SecondaryPower,
    amplified_primary: ?PrimaryPower,
) ?PowerSelection {
    const required = tierProperties(tier).primary_power_count;
    if (primary.len != required) return null;
    if ((tier == .four) != (secondary != null)) return null;
    if (secondary == .level_2_amplifier) {
        if (amplified_primary == null) return null;
    } else if (amplified_primary != null) {
        return null;
    }
    if (secondary != .level_2_amplifier and amplified_primary != null) return null;

    var selection = PowerSelection{ .primary_count = @intCast(primary.len), .secondary = secondary, .amplified_primary = amplified_primary };
    for (primary, 0..) |power, index| {
        for (primary[0..index]) |prior| {
            if (power == prior) return null;
        }
        selection.primary[index] = power;
    }
    if (amplified_primary) |power| {
        if (!selection.hasPrimary(power)) return null;
    }
    return selection;
}

pub const PaymentStack = struct {
    item: PaymentItem,
    count: u16,
};

pub const Activation = struct {
    pyramid: Pyramid,
    powers: PowerSelection,
};

fn isValidPyramid(pyramid: Pyramid) bool {
    const properties = tierProperties(pyramid.tier);
    return pyramid.is_sky_clear and
        pyramid.block_count == properties.block_count and
        pyramid.range_meters == properties.range_meters;
}

fn isValidSelection(selection: PowerSelection, tier: Tier) bool {
    if (selection.primary_count > PRIMARY_POWER_COUNT) return false;
    return selectPowers(
        tier,
        selection.primary[0..selection.primary_count],
        selection.secondary,
        selection.amplified_primary,
    ) != null;
}

/// Payment is consumed only after structure and power choices validate.
pub fn activate(
    pyramid: Pyramid,
    powers: PowerSelection,
    payment: *PaymentStack,
) ?Activation {
    if (!isValidPyramid(pyramid) or payment.count == 0 or payment.item == .other) return null;
    if (!isValidSelection(powers, pyramid.tier)) return null;
    payment.count -= 1;
    return .{ .pyramid = pyramid, .powers = powers };
}

pub const Position = struct { x: f32, y: f32, z: f32 };

/// The aura uses a spherical radius in world meters, including vertical distance.
pub fn isWithinEffectRadius(center: Position, player: Position, tier: Tier) bool {
    const radius = tierProperties(tier).range_meters;
    const dx = player.x - center.x;
    const dy = player.y - center.y;
    const dz = player.z - center.z;
    return dx * dx + dy * dy + dz * dz <= radius * radius;
}

/// Duration in seconds of beacon status effects based on pyramid tier.
pub fn effectDurationSeconds(tier: Tier) u32 {
    return 9 + @as(u32, @intFromEnum(tier)) * 2;
}

pub const PulseClock = struct {
    ticks_until_pulse: u32 = PULSE_INTERVAL_TICKS,

    /// Returns how many pulses elapsed, retaining partial ticks between calls.
    pub fn advance(self: *PulseClock, game_ticks: u32) u32 {
        const accumulated = game_ticks + (PULSE_INTERVAL_TICKS - self.ticks_until_pulse);
        const pulses = accumulated / PULSE_INTERVAL_TICKS;
        const remainder = accumulated % PULSE_INTERVAL_TICKS;
        self.ticks_until_pulse = if (remainder == 0) PULSE_INTERVAL_TICKS else PULSE_INTERVAL_TICKS - remainder;
        return pulses;
    }
};

fn fillBlocks(comptime count: usize, block: MineralBlock) [count]MineralBlock {
    return [_]MineralBlock{block} ** count;
}


// --- Beacon Aura Tests ---

test "constants have expected values" {
    try std.testing.expectEqual(@as(f32, 300.0), supercharge_duration);
    try std.testing.expectEqual(@as(f32, 1.25), haste_tier1_multiplier);
    try std.testing.expectEqual(@as(f32, 1.40), haste_tier2_multiplier);
    try std.testing.expectEqual(@as(f32, 0.5), regen_rate_per_sec);
    try std.testing.expectEqual(@as(u8, 185), IronBlockTag);
    try std.testing.expectEqual(@as(u8, 149), GoldBlockTag);
    try std.testing.expectEqual(@as(u8, 151), DiamondBlockTag);
    try std.testing.expectEqual(@as(u8, 157), EmeraldBlockTag);
}

test "isBeaconBaseBlock accepts all four base blocks" {
    try std.testing.expect(isBeaconBaseBlock(IronBlockTag));
    try std.testing.expect(isBeaconBaseBlock(GoldBlockTag));
    try std.testing.expect(isBeaconBaseBlock(DiamondBlockTag));
    try std.testing.expect(isBeaconBaseBlock(EmeraldBlockTag));
}

test "isBeaconBaseBlock rejects other blocks" {
    try std.testing.expect(!isBeaconBaseBlock(0));
    try std.testing.expect(!isBeaconBaseBlock(1));
    try std.testing.expect(!isBeaconBaseBlock(182));
    try std.testing.expect(!isBeaconBaseBlock(255));
}

test "auraRadiusForLevel maps each level" {
    try std.testing.expectEqual(@as(f32, 0.0), auraRadiusForLevel(0));
    try std.testing.expectEqual(@as(f32, 20.0), auraRadiusForLevel(1));
    try std.testing.expectEqual(@as(f32, 30.0), auraRadiusForLevel(2));
    try std.testing.expectEqual(@as(f32, 40.0), auraRadiusForLevel(3));
    try std.testing.expectEqual(@as(f32, 50.0), auraRadiusForLevel(4));
    try std.testing.expectEqual(@as(f32, 50.0), auraRadiusForLevel(5));
    try std.testing.expectEqual(@as(f32, 50.0), auraRadiusForLevel(255));
}

test "hasteMultiplier level zero is neutral" {
    try std.testing.expectEqual(@as(f32, 1.0), hasteMultiplier(0, false));
    try std.testing.expectEqual(@as(f32, 1.0), hasteMultiplier(0, true));
}

test "hasteMultiplier tier1 for level1 not supercharged" {
    try std.testing.expectEqual(haste_tier1_multiplier, hasteMultiplier(1, false));
}

test "hasteMultiplier tier2 for level2 and above" {
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(2, false));
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(3, false));
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(4, false));
}

test "hasteMultiplier supercharged upgrades level1 to tier2" {
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(1, true));
    try std.testing.expectEqual(haste_tier2_multiplier, hasteMultiplier(2, true));
}

test "tickBeaconRegen is inactive without pyramid" {
    try std.testing.expectEqual(@as(f32, 10.0), tickBeaconRegen(10.0, 20.0, 0, 1.0));
}

test "tickBeaconRegen is inactive at or below zero hp" {
    try std.testing.expectEqual(@as(f32, 0.0), tickBeaconRegen(0.0, 20.0, 2, 1.0));
    try std.testing.expectEqual(@as(f32, -1.0), tickBeaconRegen(-1.0, 20.0, 2, 1.0));
}

test "tickBeaconRegen regenerates at fixed rate" {
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), tickBeaconRegen(10.0, 20.0, 1, 1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), tickBeaconRegen(10.0, 20.0, 1, 4.0), 0.0001);
}

test "tickBeaconRegen clamps to max hp" {
    try std.testing.expectEqual(@as(f32, 20.0), tickBeaconRegen(19.9, 20.0, 1, 1.0));
    try std.testing.expectEqual(@as(f32, 20.0), tickBeaconRegen(20.0, 20.0, 3, 1.0));
}

test "tickBeaconRegen with zero dt is a no-op" {
    try std.testing.expectEqual(@as(f32, 15.0), tickBeaconRegen(15.0, 20.0, 4, 0.0));
}

// --- Beacon Pyramid Geometry Tests ---

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

// --- Beacon Status Pyramids & Activation Tests ---

test "tier one has 9 blocks, 20 meter range, and one primary" {
    const properties = tierProperties(.one);
    try std.testing.expectEqual(@as(u16, 9), properties.block_count);
    try std.testing.expectEqual(@as(f32, 20.0), properties.range_meters);
    try std.testing.expectEqual(@as(u8, 1), properties.primary_power_count);
}

test "tier two has 34 blocks, 30 meter range, and two primaries" {
    const properties = tierProperties(.two);
    try std.testing.expectEqual(@as(u16, 34), properties.block_count);
    try std.testing.expectEqual(@as(f32, 30.0), properties.range_meters);
    try std.testing.expectEqual(@as(u8, 2), properties.primary_power_count);
}

test "tier three has 83 blocks, 40 meter range, and three primaries" {
    const properties = tierProperties(.three);
    try std.testing.expectEqual(@as(u16, 83), properties.block_count);
    try std.testing.expectEqual(@as(f32, 40.0), properties.range_meters);
    try std.testing.expectEqual(@as(u8, 3), properties.primary_power_count);
}

test "tier four has 164 blocks, 50 meter range, and all five primaries" {
    const properties = tierProperties(.four);
    try std.testing.expectEqual(@as(u16, 164), properties.block_count);
    try std.testing.expectEqual(@as(f32, 50.0), properties.range_meters);
    try std.testing.expectEqual(@as(u8, 5), properties.primary_power_count);
}

test "iron blocks are eligible pyramid minerals" {
    try std.testing.expect(isMineralBlock(.iron));
}

test "gold blocks are eligible pyramid minerals" {
    try std.testing.expect(isMineralBlock(.gold));
}

test "diamond blocks are eligible pyramid minerals" {
    try std.testing.expect(isMineralBlock(.diamond));
}

test "netherite blocks are eligible pyramid minerals" {
    try std.testing.expect(isMineralBlock(.netherite));
}

test "emerald blocks are eligible pyramid minerals" {
    try std.testing.expect(isMineralBlock(.emerald));
}

test "other blocks are rejected as pyramid minerals" {
    try std.testing.expect(!isMineralBlock(.other));
}

test "valid tier one pyramid counts all base blocks" {
    const blocks = fillBlocks(9, .iron);
    const layers = [_]PyramidLayer{.{ .side = 3, .blocks = &blocks }};
    const pyramid = validatePyramid(&layers, true).?;
    try std.testing.expectEqual(Tier.one, pyramid.tier);
    try std.testing.expectEqual(@as(u16, 9), pyramid.block_count);
}

test "valid tier two pyramid counts 5x5 and 3x3 layers" {
    const base = fillBlocks(25, .gold);
    const top = fillBlocks(9, .emerald);
    const layers = [_]PyramidLayer{ .{ .side = 5, .blocks = &base }, .{ .side = 3, .blocks = &top } };
    const pyramid = validatePyramid(&layers, true).?;
    try std.testing.expectEqual(Tier.two, pyramid.tier);
    try std.testing.expectEqual(@as(u16, 34), pyramid.block_count);
}

test "valid tier three pyramid counts 7x7, 5x5, and 3x3 layers" {
    const base = fillBlocks(49, .diamond);
    const middle = fillBlocks(25, .netherite);
    const top = fillBlocks(9, .iron);
    const layers = [_]PyramidLayer{ .{ .side = 7, .blocks = &base }, .{ .side = 5, .blocks = &middle }, .{ .side = 3, .blocks = &top } };
    const pyramid = validatePyramid(&layers, true).?;
    try std.testing.expectEqual(Tier.three, pyramid.tier);
    try std.testing.expectEqual(@as(u16, 83), pyramid.block_count);
}

test "valid tier four pyramid counts all 164 mineral blocks" {
    const base = fillBlocks(81, .iron);
    const layer2 = fillBlocks(49, .gold);
    const layer3 = fillBlocks(25, .diamond);
    const top = fillBlocks(9, .emerald);
    const layers = [_]PyramidLayer{ .{ .side = 9, .blocks = &base }, .{ .side = 7, .blocks = &layer2 }, .{ .side = 5, .blocks = &layer3 }, .{ .side = 3, .blocks = &top } };
    const pyramid = validatePyramid(&layers, true).?;
    try std.testing.expectEqual(Tier.four, pyramid.tier);
    try std.testing.expectEqual(@as(u16, 164), pyramid.block_count);
}

test "obstructed sky blocks pyramid activation and beam" {
    const blocks = fillBlocks(9, .iron);
    const layers = [_]PyramidLayer{.{ .side = 3, .blocks = &blocks }};
    try std.testing.expect(validatePyramid(&layers, false) == null);
}

test "incorrect pyramid layer width is rejected" {
    const blocks = fillBlocks(9, .iron);
    const layers = [_]PyramidLayer{.{ .side = 5, .blocks = &blocks }};
    try std.testing.expect(validatePyramid(&layers, true) == null);
}

test "incomplete pyramid layer is rejected" {
    const blocks = fillBlocks(8, .iron);
    const layers = [_]PyramidLayer{.{ .side = 3, .blocks = &blocks }};
    try std.testing.expect(validatePyramid(&layers, true) == null);
}

test "non-mineral block in a pyramid layer is rejected" {
    var blocks = fillBlocks(9, .iron);
    blocks[4] = .other;
    const layers = [_]PyramidLayer{.{ .side = 3, .blocks = &blocks }};
    try std.testing.expect(validatePyramid(&layers, true) == null);
}

test "missing lower pyramid layer is rejected" {
    const base = fillBlocks(25, .iron);
    const top = fillBlocks(9, .gold);
    const layers = [_]PyramidLayer{ .{ .side = 5, .blocks = &base }, .{ .side = 3, .blocks = &top } };
    try std.testing.expect(validatePyramid(&layers, true) != null);
    const reversed = [_]PyramidLayer{ .{ .side = 3, .blocks = &top }, .{ .side = 5, .blocks = &base } };
    try std.testing.expect(validatePyramid(&reversed, true) == null);
}

test "valid primary power is selected for tier one" {
    const powers = [_]PrimaryPower{.speed};
    const selection = selectPowers(.one, &powers, null, null).?;
    try std.testing.expect(selection.hasPrimary(.speed));
}

test "tier two accepts two distinct primary powers" {
    const powers = [_]PrimaryPower{ .haste, .strength };
    try std.testing.expect(selectPowers(.two, &powers, null, null) != null);
}

test "tier three accepts three distinct primary powers" {
    const powers = [_]PrimaryPower{ .speed, .resistance, .jump_boost };
    try std.testing.expect(selectPowers(.three, &powers, null, null) != null);
}

test "tier four requires all primary powers and regeneration secondary" {
    const powers = [_]PrimaryPower{ .speed, .haste, .resistance, .jump_boost, .strength };
    const selection = selectPowers(.four, &powers, .regeneration, null).?;
    try std.testing.expectEqual(@as(u8, 5), selection.primary_count);
}

test "tier four amplifier must select an existing primary" {
    const powers = [_]PrimaryPower{ .speed, .haste, .resistance, .jump_boost, .strength };
    const selection = selectPowers(.four, &powers, .level_2_amplifier, .strength).?;
    try std.testing.expectEqual(PrimaryPower.strength, selection.amplified_primary.?);
}

test "too few primary powers for a tier are rejected" {
    const powers = [_]PrimaryPower{.speed};
    try std.testing.expect(selectPowers(.two, &powers, null, null) == null);
}

test "duplicate primary powers are rejected" {
    const powers = [_]PrimaryPower{ .speed, .speed };
    try std.testing.expect(selectPowers(.two, &powers, null, null) == null);
}

test "tier four requires a secondary selection" {
    const powers = [_]PrimaryPower{ .speed, .haste, .resistance, .jump_boost, .strength };
    try std.testing.expect(selectPowers(.four, &powers, null, null) == null);
}

test "lower tiers cannot select secondary power" {
    const powers = [_]PrimaryPower{.speed};
    try std.testing.expect(selectPowers(.one, &powers, .regeneration, null) == null);
}

test "amplifier requires a selected primary power" {
    const powers = [_]PrimaryPower{ .speed, .haste, .resistance, .jump_boost, .strength };
    try std.testing.expect(selectPowers(.four, &powers, .level_2_amplifier, .strength) != null);
    const lower = [_]PrimaryPower{.speed};
    try std.testing.expect(selectPowers(.one, &lower, null, .speed) == null);
}

test "tier one payment consumes exactly one eligible item" {
    const pyramid = Pyramid{ .tier = .one, .block_count = 9, .range_meters = 20, .is_sky_clear = true };
    const powers = [_]PrimaryPower{.speed};
    const selected = selectPowers(.one, &powers, null, null).?;
    var payment = PaymentStack{ .item = .iron_ingot, .count = 2 };
    try std.testing.expect(activate(pyramid, selected, &payment) != null);
    try std.testing.expectEqual(@as(u16, 1), payment.count);
}

test "gold diamond emerald and netherite payments are eligible" {
    const pyramid = Pyramid{ .tier = .one, .block_count = 9, .range_meters = 20, .is_sky_clear = true };
    const powers = [_]PrimaryPower{.speed};
    const selected = selectPowers(.one, &powers, null, null).?;
    const items = [_]PaymentItem{ .gold_ingot, .diamond, .emerald, .netherite_ingot };
    for (items) |item| {
        var payment = PaymentStack{ .item = item, .count = 1 };
        try std.testing.expect(activate(pyramid, selected, &payment) != null);
        try std.testing.expectEqual(@as(u16, 0), payment.count);
    }
}

test "empty payment stack does not activate or consume" {
    const pyramid = Pyramid{ .tier = .one, .block_count = 9, .range_meters = 20, .is_sky_clear = true };
    const powers = [_]PrimaryPower{.speed};
    const selected = selectPowers(.one, &powers, null, null).?;
    var payment = PaymentStack{ .item = .iron_ingot, .count = 0 };
    try std.testing.expect(activate(pyramid, selected, &payment) == null);
    try std.testing.expectEqual(@as(u16, 0), payment.count);
}

test "ineligible payment item does not activate or consume" {
    const pyramid = Pyramid{ .tier = .one, .block_count = 9, .range_meters = 20, .is_sky_clear = true };
    const powers = [_]PrimaryPower{.speed};
    const selected = selectPowers(.one, &powers, null, null).?;
    var payment = PaymentStack{ .item = .other, .count = 1 };
    try std.testing.expect(activate(pyramid, selected, &payment) == null);
    try std.testing.expectEqual(@as(u16, 1), payment.count);
}

test "activation rejects inconsistent pyramid data without consuming payment" {
    const pyramid = Pyramid{ .tier = .four, .block_count = 9, .range_meters = 20, .is_sky_clear = true };
    const powers = [_]PrimaryPower{ .speed, .haste, .resistance, .jump_boost, .strength };
    const selected = selectPowers(.four, &powers, .regeneration, null).?;
    var payment = PaymentStack{ .item = .diamond, .count = 1 };
    try std.testing.expect(activate(pyramid, selected, &payment) == null);
    try std.testing.expectEqual(@as(u16, 1), payment.count);
}

test "duration scales from eleven to seventeen seconds" {
    try std.testing.expectEqual(@as(u32, 11), effectDurationSeconds(.one));
    try std.testing.expectEqual(@as(u32, 13), effectDurationSeconds(.two));
    try std.testing.expectEqual(@as(u32, 15), effectDurationSeconds(.three));
    try std.testing.expectEqual(@as(u32, 17), effectDurationSeconds(.four));
}

test "pulse clock waits for the full 80 tick interval" {
    var clock = PulseClock{};
    try std.testing.expectEqual(@as(u32, 0), clock.advance(79));
    try std.testing.expectEqual(@as(u32, 1), clock.advance(1));
    try std.testing.expectEqual(@as(u32, 80), clock.ticks_until_pulse);
}

test "pulse clock returns to 80 ticks between pulses" {
    var clock = PulseClock{};
    try std.testing.expectEqual(@as(u32, 1), clock.advance(80));
    try std.testing.expectEqual(@as(u32, 80), clock.ticks_until_pulse);
}

test "pulse clock retains partial ticks across updates" {
    var clock = PulseClock{};
    try std.testing.expectEqual(@as(u32, 0), clock.advance(30));
    try std.testing.expectEqual(@as(u32, 0), clock.advance(49));
    try std.testing.expectEqual(@as(u32, 1), clock.advance(1));
}

test "pulse clock reports multiple intervals in a large update" {
    var clock = PulseClock{};
    try std.testing.expectEqual(@as(u32, 3), clock.advance(250));
    try std.testing.expectEqual(@as(u32, 70), clock.ticks_until_pulse);
}

test "player at beacon center is in range" {
    try std.testing.expect(isWithinEffectRadius(.{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 0 }, .one));
}

test "player at tier radius boundary is in range" {
    try std.testing.expect(isWithinEffectRadius(.{ .x = 0, .y = 0, .z = 0 }, .{ .x = 20, .y = 0, .z = 0 }, .one));
}

test "player beyond tier radius is out of range" {
    try std.testing.expect(!isWithinEffectRadius(.{ .x = 0, .y = 0, .z = 0 }, .{ .x = 20.01, .y = 0, .z = 0 }, .one));
}

test "effect radius is spherical across all three axes" {
    try std.testing.expect(isWithinEffectRadius(.{ .x = 0, .y = 0, .z = 0 }, .{ .x = 12, .y = 12, .z = 0 }, .one));
    try std.testing.expect(!isWithinEffectRadius(.{ .x = 0, .y = 0, .z = 0 }, .{ .x = 15, .y = 15, .z = 0 }, .one));
}

test "tier four radius reaches fifty meters" {
    try std.testing.expect(isWithinEffectRadius(.{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 50 }, .four));
}
