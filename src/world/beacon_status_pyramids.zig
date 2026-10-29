const std = @import("std");

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

pub fn tierProperties(tier: Tier) TierProperties {
    return switch (tier) {
        .one => .{ .layer_sides = &tier_one_sides, .block_count = 9, .range_meters = 20.0, .primary_power_count = 1 },
        .two => .{ .layer_sides = &tier_two_sides, .block_count = 34, .range_meters = 30.0, .primary_power_count = 2 },
        .three => .{ .layer_sides = &tier_three_sides, .block_count = 83, .range_meters = 40.0, .primary_power_count = 3 },
        .four => .{ .layer_sides = &tier_four_sides, .block_count = 164, .range_meters = 50.0, .primary_power_count = PRIMARY_POWER_COUNT },
    };
}

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
