const std = @import("std");

pub const snow_golem_max_health: f32 = 4.0;
pub const snowball_attack_cooldown: f32 = 1.0;
pub const snowball_attack_range: f32 = 10.0;
pub const carved_pumpkin_drop_count: u8 = 1;

/// Runtime state for the snow golem's combat and pumpkin helmet.
pub const SnowGolemState = struct {
    health: f32 = snow_golem_max_health,
    wearing_carved_pumpkin: bool = true,
    attack_cooldown: f32 = 0.0,
    pos: [3]f32 = .{ 0.0, 0.0, 0.0 },
};

/// Removes the original carved pumpkin helmet once. The caller can use the
/// successful return to emit `carved_pumpkin_drop_count` CarvedPumpkin items.
pub fn shearSnowGolemPumpkin(state: *SnowGolemState, used_shears: bool) bool {
    if (!used_shears or !state.wearing_carved_pumpkin) return false;
    state.wearing_carved_pumpkin = false;
    return true;
}

/// Snow layers form under a golem only over a solid opaque block and only in
/// cold or temperate biomes.
pub fn canFormSnowTrailUnderGolem(
    biome_temperature: f32,
    block_below_is_full_opaque: bool,
    current_block_is_air: bool,
) bool {
    return biome_temperature <= 0.80 and block_below_is_full_opaque and current_block_is_air;
}

/// Returns environmental HP loss for this timestep (not a new health value).
pub fn evaluateSnowGolemEnvironmentalDamage(
    biome_temperature: f32,
    in_water_or_rain: bool,
    has_fire_resistance: bool,
    dt: f32,
) f32 {
    const elapsed = @max(dt, 0.0);
    const heat_damage: f32 = if (biome_temperature > 1.0 and !has_fire_resistance) 2.0 * elapsed else 0.0;
    const water_damage: f32 = if (in_water_or_rain) 2.0 * elapsed else 0.0;
    return heat_damage + water_damage;
}

pub const SnowballDamage = struct {
    damage: f32,
    applies_knockback: bool,
    provokes_aggro: bool,
};

/// Snowballs are especially effective against blazes; Endermen dodge them.
pub fn computeSnowGolemBallDamage(
    target_is_blaze: bool,
    target_is_ender_dragon: bool,
    target_is_enderman: bool,
) SnowballDamage {
    if (target_is_enderman) return .{ .damage = 0.0, .applies_knockback = false, .provokes_aggro = false };
    if (target_is_blaze) return .{ .damage = 3.0, .applies_knockback = true, .provokes_aggro = true };
    if (target_is_ender_dragon) return .{ .damage = 1.0, .applies_knockback = true, .provokes_aggro = true };
    return .{ .damage = 0.0, .applies_knockback = true, .provokes_aggro = true };
}

/// Advances the attack timer, clamped at zero. Returns the remaining cooldown.
pub fn advanceSnowGolemAttackCooldown(state: *SnowGolemState, dt: f32) f32 {
    state.attack_cooldown = @max(0.0, state.attack_cooldown - @max(dt, 0.0));
    return state.attack_cooldown;
}

/// A snowball may be launched at a target within 10 blocks when the timer is ready.
pub fn canThrowSnowball(state: SnowGolemState, target_pos: [3]f32) bool {
    if (state.attack_cooldown > 0.0) return false;
    const dx = target_pos[0] - state.pos[0];
    const dy = target_pos[1] - state.pos[1];
    const dz = target_pos[2] - state.pos[2];
    return dx * dx + dy * dy + dz * dz <= snowball_attack_range * snowball_attack_range;
}

test "snow golem defaults to four hp, pumpkin, and ready attack" {
    const state = SnowGolemState{};
    try std.testing.expectEqual(@as(f32, 4.0), state.health);
    try std.testing.expect(state.wearing_carved_pumpkin);
    try std.testing.expectEqual(@as(f32, 0.0), state.attack_cooldown);
}

test "turret can throw immediately at a target in range" {
    try std.testing.expect(canThrowSnowball(SnowGolemState{}, .{ 10.0, 0.0, 0.0 }));
}

test "turret rejects target beyond ten blocks" {
    try std.testing.expect(!canThrowSnowball(SnowGolemState{}, .{ 10.01, 0.0, 0.0 }));
}

test "turret observes one second attack cadence" {
    var state = SnowGolemState{ .attack_cooldown = snowball_attack_cooldown };
    try std.testing.expect(!canThrowSnowball(state, .{ 1.0, 0.0, 0.0 }));
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), advanceSnowGolemAttackCooldown(&state, 0.5), 0.0001);
    try std.testing.expect(!canThrowSnowball(state, .{ 1.0, 0.0, 0.0 }));
    try std.testing.expectEqual(@as(f32, 0.0), advanceSnowGolemAttackCooldown(&state, 0.5));
    try std.testing.expect(canThrowSnowball(state, .{ 1.0, 0.0, 0.0 }));
}

test "attack cooldown accepts tick-sized updates and never goes negative" {
    var state = SnowGolemState{ .attack_cooldown = 1.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.95), advanceSnowGolemAttackCooldown(&state, 1.0 / 20.0), 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), advanceSnowGolemAttackCooldown(&state, 2.0));
}

test "shearing removes pumpkin and signals one drop" {
    var state = SnowGolemState{};
    try std.testing.expect(shearSnowGolemPumpkin(&state, true));
    try std.testing.expect(!state.wearing_carved_pumpkin);
    try std.testing.expectEqual(@as(u8, 1), carved_pumpkin_drop_count);
}

test "pumpkin cannot be sheared twice or without shears" {
    var state = SnowGolemState{};
    try std.testing.expect(!shearSnowGolemPumpkin(&state, false));
    try std.testing.expect(state.wearing_carved_pumpkin);
    try std.testing.expect(shearSnowGolemPumpkin(&state, true));
    try std.testing.expect(!shearSnowGolemPumpkin(&state, true));
}

test "snow trail forms at cold threshold and temperate temperatures" {
    try std.testing.expect(canFormSnowTrailUnderGolem(0.80, true, true));
    try std.testing.expect(canFormSnowTrailUnderGolem(0.0, true, true));
}

test "snow trail does not form in warmer biome" {
    try std.testing.expect(!canFormSnowTrailUnderGolem(0.81, true, true));
}

test "snow trail requires full opaque support" {
    try std.testing.expect(!canFormSnowTrailUnderGolem(0.5, false, true));
}

test "snow trail requires air at destination" {
    try std.testing.expect(!canFormSnowTrailUnderGolem(0.5, true, false));
}

test "hot biome melts for two hp per second" {
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), evaluateSnowGolemEnvironmentalDamage(1.01, false, false, 1.0), 0.0001);
}

test "fire resistance protects from desert and nether heat" {
    try std.testing.expectEqual(@as(f32, 0.0), evaluateSnowGolemEnvironmentalDamage(2.0, false, true, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), evaluateSnowGolemEnvironmentalDamage(8.0, false, true, 1.0));
}

test "heat threshold is strictly above one" {
    try std.testing.expectEqual(@as(f32, 0.0), evaluateSnowGolemEnvironmentalDamage(1.0, false, false, 1.0));
}

test "water and rain damage at two hp per second even with fire resistance" {
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), evaluateSnowGolemEnvironmentalDamage(0.0, true, true, 1.0), 0.0001);
}

test "heat and water damage accumulate" {
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), evaluateSnowGolemEnvironmentalDamage(2.0, true, true, 1.0), 0.0001);
}

test "negative elapsed time causes no environmental damage" {
    try std.testing.expectEqual(@as(f32, 0.0), evaluateSnowGolemEnvironmentalDamage(2.0, true, false, -1.0));
}

test "snowballs deal three damage to blazes" {
    const result = computeSnowGolemBallDamage(true, false, false);
    try std.testing.expectEqual(@as(f32, 3.0), result.damage);
    try std.testing.expect(result.applies_knockback and result.provokes_aggro);
}

test "snowballs deal one damage to dragon crystals" {
    try std.testing.expectEqual(@as(f32, 1.0), computeSnowGolemBallDamage(false, true, false).damage);
}

test "snowballs knock back and provoke other hostile mobs without damage" {
    const result = computeSnowGolemBallDamage(false, false, false);
    try std.testing.expectEqual(@as(f32, 0.0), result.damage);
    try std.testing.expect(result.applies_knockback and result.provokes_aggro);
}

test "endermen dodge snowballs" {
    const result = computeSnowGolemBallDamage(false, false, true);
    try std.testing.expectEqual(@as(f32, 0.0), result.damage);
    try std.testing.expect(!result.applies_knockback and !result.provokes_aggro);
}
