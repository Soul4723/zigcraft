const std = @import("std");
const mace = @import("mace_smash_kinematics.zig");

pub const smash_threshold_m: f32 = mace.smash_min_fall_distance;
pub const shockwave_radius_m: f32 = 3.5;
pub const wind_burst_iii_launch_speed: f32 = 13.0;
pub const secondary_vertical_pop_speed: f32 = 3.5;
pub const max_damage_multiplier: f32 = 2.0;

pub const PlayerState = struct {
    combo_count: u32 = 0,
    accumulated_fall_damage: f32 = 0.0,
    vertical_velocity: f32 = 0.0,
};

pub const SmashOutcome = struct {
    landed_smash: bool,
    combo_count: u32,
    damage_multiplier: f32,
    primary_damage: f32,
    wind_burst_impulse: f32,
    fall_damage_negated: bool,
};

pub const ShockwaveEffect = struct {
    knockback_force: f32,
    vertical_velocity: f32,
};

/// Combo count is one-based after the first landed smash and stays zero otherwise.
pub fn damageMultiplier(combo_count: u32) f32 {
    if (combo_count == 0) return 1.0;
    const multiplier = 1.0 + 0.25 * @as(f32, @floatFromInt(combo_count - 1));
    return @min(multiplier, max_damage_multiplier);
}

/// A successful smash landing resets fall damage and advances the aerial combo.
/// Wind Burst III applies its upward launch only when that smash is successfully landed.
pub fn landSmash(
    player: *PlayerState,
    fall_height: f32,
    successful_hit: bool,
    wind_burst: mace.WindBurstLevel,
) SmashOutcome {
    const landed_smash = successful_hit and mace.isSmashAttack(fall_height);
    if (!landed_smash) {
        return .{
            .landed_smash = false,
            .combo_count = player.combo_count,
            .damage_multiplier = damageMultiplier(player.combo_count),
            .primary_damage = 0.0,
            .wind_burst_impulse = 0.0,
            .fall_damage_negated = false,
        };
    }

    player.combo_count +|= 1;
    player.accumulated_fall_damage = 0.0;
    const impulse = if (wind_burst == .three) wind_burst_iii_launch_speed else 0.0;
    if (impulse > 0.0) player.vertical_velocity = impulse;
    const multiplier = damageMultiplier(player.combo_count);

    return .{
        .landed_smash = true,
        .combo_count = player.combo_count,
        .damage_multiplier = multiplier,
        .primary_damage = mace.calculateSmashDamage(fall_height, 0) * multiplier,
        .wind_burst_impulse = impulse,
        .fall_damage_negated = true,
    };
}

/// Solid ground contact ends the current chain, including after a Wind Burst launch.
pub fn onGroundContact(player: *PlayerState) void {
    player.combo_count = 0;
}

/// Returns no effect for the primary target or for entities outside the shockwave.
pub fn shockwaveEffect(distance: f32, combo_count: u32, is_primary_target: bool) ?ShockwaveEffect {
    if (is_primary_target or !std.math.isFinite(distance) or distance < 0.0 or distance > shockwave_radius_m) {
        return null;
    }
    const combo = @as(f32, @floatFromInt(combo_count));
    const falloff = (shockwave_radius_m - distance) / shockwave_radius_m;
    return .{
        .knockback_force = falloff * (1.5 + 0.5 * combo),
        .vertical_velocity = secondary_vertical_pop_speed,
    };
}

test "smash threshold is below one and a half meters" {
    try std.testing.expect(!mace.isSmashAttack(1.49));
}

test "smash threshold includes exactly one and a half meters" {
    try std.testing.expect(mace.isSmashAttack(1.5));
}

test "smash threshold accepts greater fall heights" {
    try std.testing.expect(mace.isSmashAttack(2.0));
}

test "a failed hit does not count as a landed smash" {
    var player = PlayerState{ .combo_count = 2 };
    const outcome = landSmash(&player, 8.0, false, .three);
    try std.testing.expect(!outcome.landed_smash);
    try std.testing.expectEqual(@as(u32, 2), player.combo_count);
}

test "subthreshold hit does not count as a smash" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.49, true, .three);
    try std.testing.expect(!outcome.landed_smash);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.wind_burst_impulse);
}

test "first successful smash starts combo one at one times damage" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.5, true, .none);
    try std.testing.expectEqual(@as(u32, 1), outcome.combo_count);
    try std.testing.expectEqual(@as(f32, 1.0), outcome.damage_multiplier);
}

test "second consecutive smash increases combo multiplier to one point two five" {
    var player = PlayerState{};
    _ = landSmash(&player, 2.0, true, .none);
    const outcome = landSmash(&player, 2.0, true, .none);
    try std.testing.expectEqual(@as(u32, 2), outcome.combo_count);
    try std.testing.expectEqual(@as(f32, 1.25), outcome.damage_multiplier);
}

test "third consecutive smash increases combo multiplier to one point five" {
    var player = PlayerState{};
    _ = landSmash(&player, 2.0, true, .none);
    _ = landSmash(&player, 2.0, true, .none);
    const outcome = landSmash(&player, 2.0, true, .none);
    try std.testing.expectEqual(@as(u32, 3), outcome.combo_count);
    try std.testing.expectEqual(@as(f32, 1.5), outcome.damage_multiplier);
}

test "fourth combo increases multiplier to one point seven five" {
    try std.testing.expectEqual(@as(f32, 1.75), damageMultiplier(4));
}

test "fifth combo reaches two times damage" {
    try std.testing.expectEqual(@as(f32, 2.0), damageMultiplier(5));
}

test "combo multiplier remains capped after the fifth combo" {
    try std.testing.expectEqual(@as(f32, 2.0), damageMultiplier(20));
}

test "zero combo multiplier is the normal one times baseline" {
    try std.testing.expectEqual(@as(f32, 1.0), damageMultiplier(0));
}

test "successful smash scales full primary smash damage by combo" {
    var player = PlayerState{ .combo_count = 1 };
    const outcome = landSmash(&player, 3.0, true, .none);
    try std.testing.expectEqual(@as(f32, 18.0 * 1.25), outcome.primary_damage);
}

test "Wind Burst III applies plus thirteen meters per second" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.5, true, .three);
    try std.testing.expectEqual(@as(f32, 13.0), outcome.wind_burst_impulse);
    try std.testing.expectEqual(@as(f32, 13.0), player.vertical_velocity);
}

test "Wind Burst III launch applies at the smash threshold" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.5, true, .three);
    try std.testing.expectEqual(wind_burst_iii_launch_speed, outcome.wind_burst_impulse);
}

test "Wind Burst III launch does not apply below the smash threshold" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 1.49, true, .three);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.wind_burst_impulse);
}

test "Wind Burst III launch does not apply on a miss" {
    var player = PlayerState{};
    const outcome = landSmash(&player, 3.0, false, .three);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.wind_burst_impulse);
}

test "Wind Burst levels one and two do not use the level three launch" {
    var one = PlayerState{};
    var two = PlayerState{};
    try std.testing.expectEqual(@as(f32, 0.0), landSmash(&one, 3.0, true, .one).wind_burst_impulse);
    try std.testing.expectEqual(@as(f32, 0.0), landSmash(&two, 3.0, true, .two).wind_burst_impulse);
}

test "landing smash sets launch velocity to thirteen" {
    var player = PlayerState{ .vertical_velocity = -20.0 };
    _ = landSmash(&player, 10.0, true, .three);
    try std.testing.expectEqual(@as(f32, 13.0), player.vertical_velocity);
}

test "landing without Wind Burst preserves vertical velocity" {
    var player = PlayerState{ .vertical_velocity = -8.0 };
    _ = landSmash(&player, 10.0, true, .none);
    try std.testing.expectEqual(@as(f32, -8.0), player.vertical_velocity);
}

test "solid ground contact resets combo count" {
    var player = PlayerState{ .combo_count = 3 };
    onGroundContact(&player);
    try std.testing.expectEqual(@as(u32, 0), player.combo_count);
}

test "combo after ground contact starts at one again" {
    var player = PlayerState{ .combo_count = 3 };
    onGroundContact(&player);
    const outcome = landSmash(&player, 1.5, true, .none);
    try std.testing.expectEqual(@as(u32, 1), outcome.combo_count);
    try std.testing.expectEqual(@as(f32, 1.0), outcome.damage_multiplier);
}

test "successful smash negates accumulated fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 9.0 };
    const outcome = landSmash(&player, 10.0, true, .none);
    try std.testing.expect(outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 0.0), player.accumulated_fall_damage);
}

test "one hundred meter successful smash negates all fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 1000.0 };
    const outcome = landSmash(&player, 100.0, true, .three);
    try std.testing.expect(outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 0.0), player.accumulated_fall_damage);
}

test "very large successful smash negates all fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 5000.0 };
    const outcome = landSmash(&player, 1000.0, true, .none);
    try std.testing.expect(outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 0.0), player.accumulated_fall_damage);
}

test "failed smash preserves accumulated fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 42.0 };
    const outcome = landSmash(&player, 100.0, false, .three);
    try std.testing.expect(!outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 42.0), player.accumulated_fall_damage);
}

test "subthreshold hit preserves accumulated fall damage" {
    var player = PlayerState{ .accumulated_fall_damage = 2.0 };
    const outcome = landSmash(&player, 1.0, true, .three);
    try std.testing.expect(!outcome.fall_damage_negated);
    try std.testing.expectEqual(@as(f32, 2.0), player.accumulated_fall_damage);
}

test "shockwave has maximum base force at zero distance" {
    const effect = shockwaveEffect(0.0, 0, false).?;
    try std.testing.expectEqual(@as(f32, 1.5), effect.knockback_force);
}

test "shockwave force falls off linearly at half radius" {
    const effect = shockwaveEffect(1.75, 0, false).?;
    try std.testing.expectEqual(@as(f32, 0.75), effect.knockback_force);
}

test "shockwave has no horizontal force at the radius edge" {
    const effect = shockwaveEffect(3.5, 0, false).?;
    try std.testing.expectEqual(@as(f32, 0.0), effect.knockback_force);
}

test "shockwave excludes entities beyond three point five meters" {
    try std.testing.expect(shockwaveEffect(3.5001, 0, false) == null);
}

test "shockwave excludes primary target" {
    try std.testing.expect(shockwaveEffect(1.0, 1, true) == null);
}

test "shockwave excludes negative distance" {
    try std.testing.expect(shockwaveEffect(-0.1, 0, false) == null);
}

test "shockwave excludes nonfinite distance" {
    try std.testing.expect(shockwaveEffect(std.math.nan(f32), 0, false) == null);
}

test "shockwave combo one force is two at zero distance" {
    const effect = shockwaveEffect(0.0, 1, false).?;
    try std.testing.expectEqual(@as(f32, 2.0), effect.knockback_force);
}

test "shockwave force grows with combo count" {
    const first = shockwaveEffect(1.0, 1, false).?;
    const third = shockwaveEffect(1.0, 3, false).?;
    try std.testing.expect(third.knockback_force > first.knockback_force);
}

test "shockwave applies vertical pop of three point five meters per second" {
    const effect = shockwaveEffect(2.0, 2, false).?;
    try std.testing.expectEqual(@as(f32, 3.5), effect.vertical_velocity);
}

test "shockwave vertical pop is independent of distance" {
    const near = shockwaveEffect(0.0, 0, false).?;
    const edge = shockwaveEffect(3.5, 0, false).?;
    try std.testing.expectEqual(near.vertical_velocity, edge.vertical_velocity);
}
