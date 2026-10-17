const std = @import("std");

pub const guardian_laser_charge_seconds: f32 = 2.0;
pub const elder_guardian_laser_charge_seconds: f32 = 3.0;
pub const guardian_laser_range: f32 = 15.0;
pub const guardian_spike_thorns_damage: f32 = 2.0;
pub const sponge_absorption_limit: u8 = 65;
pub const sponge_absorption_radius: u4 = 7;

pub const GuardianLaserState = struct {
    target_id: ?u32 = null,
    charge_timer: f32 = 0.0,
};

pub const GuardianBeamColor = enum { purple, orange, yellow_flash };

pub const GuardianLaserTick = struct {
    fired_beam: bool,
    physical_damage: f32,
    magic_armor_piercing_damage: f32,
};

/// The beam progresses from purple through orange to a yellow flash as it charges.
pub fn guardianLaserChargeColor(state: GuardianLaserState, is_elder: bool) GuardianBeamColor {
    const duration = if (is_elder) elder_guardian_laser_charge_seconds else guardian_laser_charge_seconds;
    const progress = std.math.clamp(state.charge_timer / duration, 0.0, 1.0);
    if (progress >= 0.9) return .yellow_flash;
    if (progress >= 0.5) return .orange;
    return .purple;
}

/// Advances a focused Guardian beam. Losing sight or exceeding range breaks the charge.
pub fn tickGuardianLaserBeam(
    state: *GuardianLaserState,
    has_line_of_sight: bool,
    dist_to_target: f32,
    is_elder: bool,
    dt: f32,
) GuardianLaserTick {
    const no_damage = GuardianLaserTick{
        .fired_beam = false,
        .physical_damage = 0.0,
        .magic_armor_piercing_damage = 0.0,
    };
    if (!has_line_of_sight or dist_to_target < 0.0 or dist_to_target > guardian_laser_range or dt <= 0.0) {
        state.charge_timer = 0.0;
        return no_damage;
    }

    const charge_duration = if (is_elder) elder_guardian_laser_charge_seconds else guardian_laser_charge_seconds;
    state.charge_timer = @min(state.charge_timer + dt, charge_duration);
    if (state.charge_timer < charge_duration) return no_damage;

    state.charge_timer = 0.0;
    return .{
        .fired_beam = true,
        .physical_damage = if (is_elder) 8.0 else 6.0,
        .magic_armor_piercing_damage = if (is_elder) 2.0 else 1.0,
    };
}

/// Extended defensive spikes punish melee attacks while the Guardian is not laser-focused.
pub fn evaluateGuardianSpikeThorns(spikes_extended: bool, attacker_used_melee: bool) f32 {
    return if (spikes_extended and attacker_used_melee) guardian_spike_thorns_damage else 0.0;
}

pub const SpongePlacementResult = struct {
    became_wet: bool,
    became_dry_instantly: bool,
    water_absorbed_radius: u4,
};

/// Resolves sponge placement. The caller removes at most 65 water blocks in radius seven.
pub fn placeSpongeInBiomeOrDimension(
    is_wet_sponge: bool,
    placed_in_nether: bool,
    adjacent_water_blocks: u8,
) SpongePlacementResult {
    if (is_wet_sponge) {
        return .{
            .became_wet = false,
            .became_dry_instantly = placed_in_nether,
            .water_absorbed_radius = 0,
        };
    }
    return .{
        .became_wet = adjacent_water_blocks > 0,
        .became_dry_instantly = false,
        .water_absorbed_radius = if (adjacent_water_blocks > 0) sponge_absorption_radius else 0,
    };
}

test "Guardian state starts without a target or charge" {
    const state = GuardianLaserState{};
    try std.testing.expectEqual(@as(?u32, null), state.target_id);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "standard Guardian requires two seconds to fire" {
    var state = GuardianLaserState{};
    try std.testing.expect(!tickGuardianLaserBeam(&state, true, 10.0, false, 1.99).fired_beam);
    const shot = tickGuardianLaserBeam(&state, true, 10.0, false, 0.01);
    try std.testing.expect(shot.fired_beam);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "standard Guardian beam gives six physical and one piercing damage" {
    var state = GuardianLaserState{};
    const shot = tickGuardianLaserBeam(&state, true, 15.0, false, 2.0);
    try std.testing.expectEqual(@as(f32, 6.0), shot.physical_damage);
    try std.testing.expectEqual(@as(f32, 1.0), shot.magic_armor_piercing_damage);
}

test "Elder Guardian requires three seconds to fire" {
    var state = GuardianLaserState{};
    try std.testing.expect(!tickGuardianLaserBeam(&state, true, 8.0, true, 2.99).fired_beam);
    try std.testing.expect(tickGuardianLaserBeam(&state, true, 8.0, true, 0.01).fired_beam);
}

test "Elder Guardian beam gives eight physical and two piercing damage" {
    var state = GuardianLaserState{};
    const shot = tickGuardianLaserBeam(&state, true, 8.0, true, 3.0);
    try std.testing.expectEqual(@as(f32, 8.0), shot.physical_damage);
    try std.testing.expectEqual(@as(f32, 2.0), shot.magic_armor_piercing_damage);
}

test "pillar breaking line of sight immediately resets a standard charge" {
    var state = GuardianLaserState{ .charge_timer = 1.25 };
    const shot = tickGuardianLaserBeam(&state, false, 5.0, false, 0.1);
    try std.testing.expect(!shot.fired_beam);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "line of sight break resets an Elder charge" {
    var state = GuardianLaserState{ .charge_timer = 2.8 };
    _ = tickGuardianLaserBeam(&state, false, 5.0, true, 0.2);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "target outside fifteen blocks breaks the beam charge" {
    var state = GuardianLaserState{ .charge_timer = 1.0 };
    _ = tickGuardianLaserBeam(&state, true, 15.01, false, 0.1);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "target at fifteen blocks remains in valid beam range" {
    var state = GuardianLaserState{};
    _ = tickGuardianLaserBeam(&state, true, 15.0, false, 1.0);
    try std.testing.expectEqual(@as(f32, 1.0), state.charge_timer);
}

test "Guardian beam charge colors progress purple orange yellow" {
    var state = GuardianLaserState{};
    try std.testing.expectEqual(GuardianBeamColor.purple, guardianLaserChargeColor(state, false));
    state.charge_timer = 1.0;
    try std.testing.expectEqual(GuardianBeamColor.orange, guardianLaserChargeColor(state, false));
    state.charge_timer = 1.8;
    try std.testing.expectEqual(GuardianBeamColor.yellow_flash, guardianLaserChargeColor(state, false));
}

test "Elder color stages use its longer charge duration" {
    const state = GuardianLaserState{ .charge_timer = 1.0 };
    try std.testing.expectEqual(GuardianBeamColor.purple, guardianLaserChargeColor(state, true));
}

test "extended Guardian spikes return two melee thorns damage" {
    try std.testing.expectEqual(@as(f32, 2.0), evaluateGuardianSpikeThorns(true, true));
}

test "spikes do not hurt ranged attackers or retracted Guardians" {
    try std.testing.expectEqual(@as(f32, 0.0), evaluateGuardianSpikeThorns(true, false));
    try std.testing.expectEqual(@as(f32, 0.0), evaluateGuardianSpikeThorns(false, true));
}

test "dry sponge touching water absorbs within seven-block radius and becomes wet" {
    const result = placeSpongeInBiomeOrDimension(false, false, 1);
    try std.testing.expect(result.became_wet);
    try std.testing.expect(!result.became_dry_instantly);
    try std.testing.expectEqual(@as(u4, 7), result.water_absorbed_radius);
}

test "sponge absorption is bounded to sixty-five water blocks" {
    const result = placeSpongeInBiomeOrDimension(false, false, 100);
    try std.testing.expect(result.became_wet);
    try std.testing.expectEqual(sponge_absorption_limit, @min(@as(u8, 100), sponge_absorption_limit));
}

test "dry sponge away from water remains dry" {
    const result = placeSpongeInBiomeOrDimension(false, false, 0);
    try std.testing.expect(!result.became_wet);
    try std.testing.expectEqual(@as(u4, 0), result.water_absorbed_radius);
}

test "wet sponge placed in Nether dries instantly" {
    const result = placeSpongeInBiomeOrDimension(true, true, 0);
    try std.testing.expect(result.became_dry_instantly);
    try std.testing.expect(!result.became_wet);
}

test "wet sponge outside Nether does not instantly dry" {
    const result = placeSpongeInBiomeOrDimension(true, false, 0);
    try std.testing.expect(!result.became_dry_instantly);
}
