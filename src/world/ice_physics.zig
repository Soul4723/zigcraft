const std = @import("std");

/// Speed multiplier applied while walking on regular ice.
pub const ice_speed_multiplier: f32 = 1.35;
/// Speed multiplier applied while walking on packed ice.
pub const packed_ice_speed_multiplier: f32 = 1.65;
/// Speed multiplier applied while walking on blue ice.
pub const blue_ice_speed_multiplier: f32 = 2.20;
/// Seconds of unprotected exposure in powder snow before freezing damage starts.
pub const freeze_buildup_time: f32 = 7.0;
/// Damage per second once the freeze timer is full.
pub const freeze_damage_rate: f32 = 1.0;

/// The kind of slippery ice surface the player is standing on.
pub const IceKind = enum { none, ice, packed_ice, blue_ice };

/// Returns the movement speed multiplier for the given ice surface.
/// Returns `1.0` for `.none` (ordinary ground).
pub fn speedMultiplier(kind: IceKind) f32 {
    return switch (kind) {
        .none => 1.0,
        .ice => ice_speed_multiplier,
        .packed_ice => packed_ice_speed_multiplier,
        .blue_ice => blue_ice_speed_multiplier,
    };
}

/// Advances (or decays) the powder snow freeze timer by `dt` seconds.
/// Unprotected exposure builds toward `freeze_buildup_time`; otherwise it
/// thaws at double rate and never drops below zero.
pub fn tickFreezeTimer(current_timer: f32, in_powder_snow: bool, has_leather_protection: bool, dt: f32) f32 {
    if (in_powder_snow and !has_leather_protection) {
        return @min(freeze_buildup_time, current_timer + dt);
    }
    return @max(0.0, current_timer - dt * 2.0);
}

/// Damage dealt this tick from freezing. Zero while protected or before the
/// buildup time is reached; otherwise `freeze_damage_rate * dt`.
pub fn calculateFreezeDamage(freeze_timer: f32, has_leather_protection: bool, dt: f32) f32 {
    if (has_leather_protection or freeze_timer < freeze_buildup_time) return 0.0;
    return freeze_damage_rate * dt;
}

/// Whether the player can walk on top of powder snow (requires leather boots).
pub fn canWalkOnPowderSnow(has_leather_boots: bool) bool {
    return has_leather_boots;
}

test "constants have expected values" {
    try std.testing.expectEqual(@as(f32, 1.35), ice_speed_multiplier);
    try std.testing.expectEqual(@as(f32, 1.65), packed_ice_speed_multiplier);
    try std.testing.expectEqual(@as(f32, 2.20), blue_ice_speed_multiplier);
    try std.testing.expectEqual(@as(f32, 7.0), freeze_buildup_time);
    try std.testing.expectEqual(@as(f32, 1.0), freeze_damage_rate);
}

test "speedMultiplier returns per-surface multipliers" {
    try std.testing.expectEqual(@as(f32, 1.0), speedMultiplier(.none));
    try std.testing.expectEqual(ice_speed_multiplier, speedMultiplier(.ice));
    try std.testing.expectEqual(packed_ice_speed_multiplier, speedMultiplier(.packed_ice));
    try std.testing.expectEqual(blue_ice_speed_multiplier, speedMultiplier(.blue_ice));
}

test "speedMultiplier increases with slickness" {
    try std.testing.expect(speedMultiplier(.blue_ice) > speedMultiplier(.packed_ice));
    try std.testing.expect(speedMultiplier(.packed_ice) > speedMultiplier(.ice));
    try std.testing.expect(speedMultiplier(.ice) > speedMultiplier(.none));
}

test "tickFreezeTimer builds up while unprotected in powder snow" {
    const t = tickFreezeTimer(0.0, true, false, 1.0);
    try std.testing.expectEqual(@as(f32, 1.0), t);
}

test "tickFreezeTimer clamps to freeze_buildup_time" {
    const t = tickFreezeTimer(freeze_buildup_time - 0.5, true, false, 3.0);
    try std.testing.expectEqual(freeze_buildup_time, t);
}

test "tickFreezeTimer does not build with leather protection" {
    const t = tickFreezeTimer(2.0, true, true, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), t, 0.001);
}

test "tickFreezeTimer thaws at double rate" {
    const t = tickFreezeTimer(4.0, false, false, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), t, 0.001);
}

test "tickFreezeTimer never goes negative while thawing" {
    const t = tickFreezeTimer(1.0, false, false, 10.0);
    try std.testing.expectEqual(@as(f32, 0.0), t);
}

test "calculateFreezeDamage zero before buildup" {
    try std.testing.expectEqual(@as(f32, 0.0), calculateFreezeDamage(1.0, false, 1.0));
}

test "calculateFreezeDamage zero when protected" {
    try std.testing.expectEqual(@as(f32, 0.0), calculateFreezeDamage(freeze_buildup_time, true, 1.0));
}

test "calculateFreezeDamage deals rate while frozen" {
    const dmg = calculateFreezeDamage(freeze_buildup_time, false, 0.5);
    try std.testing.expectApproxEqAbs(freeze_damage_rate * 0.5, dmg, 0.0001);
}

test "calculateFreezeDamage zero exactly at buildup threshold" {
    try std.testing.expectEqual(@as(f32, 0.0), calculateFreezeDamage(freeze_buildup_time - 0.01, false, 1.0));
}

test "canWalkOnPowderSnow follows leather boots" {
    try std.testing.expect(canWalkOnPowderSnow(true));
    try std.testing.expect(!canWalkOnPowderSnow(false));
}
