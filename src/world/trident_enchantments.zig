const std = @import("std");

pub const LoyaltyTridentState = struct {
    pos: [3]f32,
    owner_pos: [3]f32,
    loyalty_level: u2,
    is_returning: bool,
    fell_into_void_below_y_minus_64: bool,
    /// Set by collision handling when the thrown trident hits a block or entity.
    hit_target: bool = false,
};

pub const LoyaltyReturnStep = struct {
    returned_to_owner: bool,
    return_speed: f32,
};

pub fn stepLoyaltyReturnFlight(state: *LoyaltyTridentState, dt: f32) LoyaltyReturnStep {
    if (state.loyalty_level == 0) return .{ .returned_to_owner = false, .return_speed = 0.0 };
    if (state.pos[1] < -64.0) state.fell_into_void_below_y_minus_64 = true;
    if (!state.is_returning and (state.hit_target or state.fell_into_void_below_y_minus_64)) {
        state.is_returning = true;
    }
    if (!state.is_returning) return .{ .returned_to_owner = false, .return_speed = 0.0 };

    const speed = 10.0 + 7.5 * @as(f32, @floatFromInt(state.loyalty_level));
    const dx = state.owner_pos[0] - state.pos[0];
    const dy = state.owner_pos[1] - state.pos[1];
    const dz = state.owner_pos[2] - state.pos[2];
    const distance = @sqrt(dx * dx + dy * dy + dz * dz);
    const travel = @max(0.0, dt) * speed;
    if (distance <= travel or distance <= 0.0001) {
        state.pos = state.owner_pos;
        return .{ .returned_to_owner = true, .return_speed = speed };
    }

    const scale = travel / distance;
    state.pos[0] += dx * scale;
    state.pos[1] += dy * scale;
    state.pos[2] += dz * scale;
    return .{ .returned_to_owner = false, .return_speed = speed };
}

pub const ChannelingStrikeTarget = enum {
    creeper,
    villager,
    pig,
    red_mooshroom,
    brown_mooshroom,
    copper_golem_statue,
    turtle,
    other_mob,
};

pub const ChannelingStrikeResult = struct {
    lightning_summoned: bool,
    lightning_damage: f32,
    transformed_into: ?[]const u8,
};

pub fn resolveChannelingStrike(
    has_channeling: bool,
    is_thunderstorming: bool,
    target_exposed_to_sky: bool,
    target_kind: ChannelingStrikeTarget,
) ChannelingStrikeResult {
    if (!(has_channeling and is_thunderstorming and target_exposed_to_sky)) {
        return .{ .lightning_summoned = false, .lightning_damage = 0.0, .transformed_into = null };
    }

    const transformed: ?[]const u8 = switch (target_kind) {
        .creeper => "charged_creeper",
        .villager => "witch",
        .pig => "zombified_piglin",
        .red_mooshroom => "brown_mooshroom",
        .brown_mooshroom => "red_mooshroom",
        .copper_golem_statue => "active_unoxidized_copper_golem",
        .turtle, .other_mob => null,
    };
    return .{
        .lightning_summoned = true,
        .lightning_damage = if (target_kind == .turtle) 100.0 else 0.0,
        .transformed_into = transformed,
    };
}

pub fn computeImpalingDamageBonus(impaling_level: u3, target_is_aquatic: bool, target_in_water_or_rain: bool) f32 {
    if (!target_is_aquatic and !target_in_water_or_rain) return 0.0;
    return 2.5 * @as(f32, @floatFromInt(impaling_level));
}

pub fn canCombineTridentEnchantments(has_riptide: bool, wants_loyalty_or_channeling: bool) bool {
    return !(has_riptide and wants_loyalty_or_channeling);
}

test "loyalty return speeds scale from I through III" {
    var state = LoyaltyTridentState{ .pos = .{ 0, 0, 0 }, .owner_pos = .{ 100, 0, 0 }, .loyalty_level = 1, .is_returning = false, .fell_into_void_below_y_minus_64 = false, .hit_target = true };
    const one = stepLoyaltyReturnFlight(&state, 0.1);
    try @import("std").testing.expectEqual(@as(f32, 17.5), one.return_speed);
    try @import("std").testing.expectApproxEqAbs(@as(f32, 1.75), state.pos[0], 0.001);
    state.loyalty_level = 2;
    try @import("std").testing.expectEqual(@as(f32, 25.0), stepLoyaltyReturnFlight(&state, 0).return_speed);
    state.loyalty_level = 3;
    try @import("std").testing.expectEqual(@as(f32, 32.5), stepLoyaltyReturnFlight(&state, 0).return_speed);
}

test "loyalty triggers on target impact and reaches owner" {
    var state = LoyaltyTridentState{ .pos = .{ 1, 0, 0 }, .owner_pos = .{ 0, 0, 0 }, .loyalty_level = 1, .is_returning = false, .fell_into_void_below_y_minus_64 = false, .hit_target = true };
    const step = stepLoyaltyReturnFlight(&state, 1.0);
    try std.testing.expect(step.returned_to_owner);
    try std.testing.expectEqual([_]f32{ 0, 0, 0 }, state.pos);
    try std.testing.expect(state.is_returning);
}

test "loyalty void recovery starts return flight" {
    var state = LoyaltyTridentState{ .pos = .{ 0, -65, 0 }, .owner_pos = .{ 0, 0, 0 }, .loyalty_level = 1, .is_returning = false, .fell_into_void_below_y_minus_64 = true };
    _ = stepLoyaltyReturnFlight(&state, 0.1);
    try std.testing.expect(state.is_returning);
    try std.testing.expect(state.pos[1] > -65.0);
}

test "loyalty zero does not return" {
    var state = LoyaltyTridentState{ .pos = .{ 0, 0, 0 }, .owner_pos = .{ 1, 0, 0 }, .loyalty_level = 0, .is_returning = false, .fell_into_void_below_y_minus_64 = true };
    const step = stepLoyaltyReturnFlight(&state, 1.0);
    try std.testing.expect(!step.returned_to_owner);
    try std.testing.expectEqual(@as(f32, 0), step.return_speed);
    try std.testing.expectEqual(@as(f32, 0), state.pos[0]);
}

test "channeling requires enchantment thunderstorm and open sky" {
    const no_enchantment = resolveChannelingStrike(false, true, true, .creeper);
    const no_storm = resolveChannelingStrike(true, false, true, .creeper);
    const no_sky = resolveChannelingStrike(true, true, false, .creeper);
    try std.testing.expect(!no_enchantment.lightning_summoned);
    try std.testing.expect(!no_storm.lightning_summoned);
    try std.testing.expect(!no_sky.lightning_summoned);
    try std.testing.expectEqual(@as(?[]const u8, null), no_sky.transformed_into);
}

test "channeling transforms creeper villager and pig" {
    try std.testing.expectEqualStrings("charged_creeper", (resolveChannelingStrike(true, true, true, .creeper).transformed_into.?));
    try std.testing.expectEqualStrings("witch", (resolveChannelingStrike(true, true, true, .villager).transformed_into.?));
    try std.testing.expectEqualStrings("zombified_piglin", (resolveChannelingStrike(true, true, true, .pig).transformed_into.?));
}

test "channeling toggles mooshroom colors" {
    try std.testing.expectEqualStrings("brown_mooshroom", (resolveChannelingStrike(true, true, true, .red_mooshroom).transformed_into.?));
    try std.testing.expectEqualStrings("red_mooshroom", (resolveChannelingStrike(true, true, true, .brown_mooshroom).transformed_into.?));
}

test "channeling activates copper golem statue" {
    try std.testing.expectEqualStrings("active_unoxidized_copper_golem", (resolveChannelingStrike(true, true, true, .copper_golem_statue).transformed_into.?));
}

test "channeling turtle strike drops bowl as damage event" {
    const result = resolveChannelingStrike(true, true, true, .turtle);
    try std.testing.expect(result.lightning_summoned);
    try std.testing.expectEqual(@as(f32, 100.0), result.lightning_damage);
    try std.testing.expectEqual(@as(?[]const u8, null), result.transformed_into);
}

test "channeling other mob summons lightning without transformation" {
    const result = resolveChannelingStrike(true, true, true, .other_mob);
    try std.testing.expect(result.lightning_summoned);
    try std.testing.expectEqual(@as(?[]const u8, null), result.transformed_into);
}

test "impaling I through V add bonus to aquatic targets" {
    var level: u3 = 1;
    while (level <= 5) : (level += 1) {
        try std.testing.expectApproxEqAbs(2.5 * @as(f32, @floatFromInt(level)), computeImpalingDamageBonus(level, true, false), 0.001);
    }
    try std.testing.expectEqual(@as(f32, 12.5), computeImpalingDamageBonus(5, true, false));
}

test "impaling bonus also applies to targets in water or rain" {
    try std.testing.expectEqual(@as(f32, 7.5), computeImpalingDamageBonus(3, false, true));
}

test "impaling has no bonus for dry non-aquatic targets" {
    try std.testing.expectEqual(@as(f32, 0), computeImpalingDamageBonus(5, false, false));
}

test "riptide is incompatible with loyalty or channeling" {
    try std.testing.expect(!canCombineTridentEnchantments(true, true));
    try std.testing.expect(canCombineTridentEnchantments(true, false));
    try std.testing.expect(canCombineTridentEnchantments(false, true));
    try std.testing.expect(canCombineTridentEnchantments(false, false));
}

test "loyalty return flies straight toward owner in three dimensions" {
    var state = LoyaltyTridentState{
        .pos = .{ 3, 4, 0 },
        .owner_pos = .{ 0, 0, 0 },
        .loyalty_level = 1,
        .is_returning = true,
        .fell_into_void_below_y_minus_64 = false,
    };
    const result = stepLoyaltyReturnFlight(&state, 0.1);
    try std.testing.expect(!result.returned_to_owner);
    try std.testing.expectApproxEqAbs(@as(f32, 1.95), state.pos[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.6), state.pos[1], 0.001);
}

test "loyalty void threshold is detected from position" {
    var state = LoyaltyTridentState{
        .pos = .{ 0, -64.1, 0 },
        .owner_pos = .{ 0, 0, 0 },
        .loyalty_level = 2,
        .is_returning = false,
        .fell_into_void_below_y_minus_64 = false,
    };
    _ = stepLoyaltyReturnFlight(&state, 0.01);
    try std.testing.expect(state.fell_into_void_below_y_minus_64);
    try std.testing.expect(state.is_returning);
}

test "loyalty return completes without overshooting owner" {
    var state = LoyaltyTridentState{
        .pos = .{ 1, 0, 0 },
        .owner_pos = .{ 0, 0, 0 },
        .loyalty_level = 3,
        .is_returning = true,
        .fell_into_void_below_y_minus_64 = false,
    };
    const result = stepLoyaltyReturnFlight(&state, 0.1);
    try std.testing.expect(result.returned_to_owner);
    try std.testing.expectEqual([_]f32{ 0, 0, 0 }, state.pos);
}

test "channeling damage is zero for ordinary strike targets" {
    const result = resolveChannelingStrike(true, true, true, .creeper);
    try std.testing.expectEqual(@as(f32, 0), result.lightning_damage);
}

test "riptide exclusivity permits loyalty without riptide" {
    try std.testing.expect(canCombineTridentEnchantments(false, true));
}
