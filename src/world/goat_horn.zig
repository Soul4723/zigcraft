const std = @import("std");

/// Seconds the goat horn is on cooldown after being blown.
pub const horn_cooldown_duration: f32 = 7.0;
/// Radius in blocks within which the horn can be heard.
pub const horn_audible_radius: f32 = 64.0;
/// Squared audible radius, for cheap distance comparisons.
pub const horn_audible_radius_sq: f32 = 4096.0;
/// Damage dealt to a target hit by a goat ram.
pub const ram_impact_damage: u8 = 8;
/// Upward knockback velocity applied by a goat ram.
pub const ram_knockback_vy: f32 = 7.0;

/// Whether the horn may be blown yet. It is ready once the cooldown reaches
/// zero (or below).
pub fn canBlowHorn(cooldown_timer: f32) bool {
    return cooldown_timer <= 0.0;
}

/// Advances the horn cooldown by `dt` seconds, never returning below zero.
pub fn tickHornCooldown(timer: f32, dt: f32) f32 {
    return @max(0.0, timer - dt);
}

/// Whether a point at `(px, pz)` lies within the horn's audible radius of the
/// horn at `(hx, hz)`, using squared horizontal distance.
pub fn isWithinHornAudibleRange(hx: f32, hz: f32, px: f32, pz: f32) bool {
    const dx = px - hx;
    const dz = pz - hz;
    return dx * dx + dz * dz <= horn_audible_radius_sq;
}

/// Computes the horizontal and vertical impulse applied to a target at
/// horizontal offset `(dx, dz)` from a ramming goat. The horizontal direction
/// is normalized (with a minimum length of 0.2) and scaled by 9.0.
pub fn calculateRamImpulse(dx: f32, dz: f32) struct { vx: f32, vy: f32, vz: f32 } {
    const len = @max(0.2, @sqrt(dx * dx + dz * dz));
    return .{ .vx = (dx / len) * 9.0, .vy = ram_knockback_vy, .vz = (dz / len) * 9.0 };
}

test "constants have expected values" {
    try std.testing.expectApproxEqAbs(horn_cooldown_duration, 7.0, 0.0001);
    try std.testing.expectApproxEqAbs(horn_audible_radius, 64.0, 0.0001);
    try std.testing.expectApproxEqAbs(horn_audible_radius_sq, 4096.0, 0.0001);
    try std.testing.expectEqual(@as(u8, 8), ram_impact_damage);
    try std.testing.expectApproxEqAbs(ram_knockback_vy, 7.0, 0.0001);
}

test "audible radius squared matches radius" {
    try std.testing.expectApproxEqAbs(horn_audible_radius * horn_audible_radius, horn_audible_radius_sq, 0.01);
}

test "canBlowHorn ready at or below zero cooldown" {
    try std.testing.expect(canBlowHorn(0.0));
    try std.testing.expect(canBlowHorn(-1.0));
}

test "canBlowHorn blocked while cooling down" {
    try std.testing.expect(!canBlowHorn(horn_cooldown_duration));
    try std.testing.expect(!canBlowHorn(0.01));
}

test "tickHornCooldown decays the timer" {
    try std.testing.expectApproxEqAbs(tickHornCooldown(horn_cooldown_duration, 1.0), 6.0, 0.0001);
    try std.testing.expectApproxEqAbs(tickHornCooldown(2.0, 0.5), 1.5, 0.0001);
}

test "tickHornCooldown never goes negative" {
    try std.testing.expectEqual(@as(f32, 0.0), tickHornCooldown(0.0, 5.0));
    try std.testing.expectEqual(@as(f32, 0.0), tickHornCooldown(1.0, 10.0));
}

test "tickHornCooldown completes a full cooldown" {
    var timer: f32 = horn_cooldown_duration;
    timer = tickHornCooldown(timer, horn_cooldown_duration);
    try std.testing.expectEqual(@as(f32, 0.0), timer);
    try std.testing.expect(canBlowHorn(timer));
}

test "isWithinHornAudibleRange inside and on boundary" {
    try std.testing.expect(isWithinHornAudibleRange(0.0, 0.0, 0.0, 0.0));
    try std.testing.expect(isWithinHornAudibleRange(0.0, 0.0, 64.0, 0.0));
    try std.testing.expect(isWithinHornAudibleRange(0.0, 0.0, 0.0, -64.0));
    try std.testing.expect(isWithinHornAudibleRange(10.0, 10.0, 13.0, 14.0));
}

test "isWithinHornAudibleRange outside" {
    try std.testing.expect(!isWithinHornAudibleRange(0.0, 0.0, 64.01, 0.0));
    try std.testing.expect(!isWithinHornAudibleRange(0.0, 0.0, 100.0, 100.0));
    try std.testing.expect(!isWithinHornAudibleRange(0.0, 0.0, 45.0, 46.0));
}

test "calculateRamImpulse pushes along delta" {
    const k = calculateRamImpulse(3.0, 4.0);
    try std.testing.expectApproxEqAbs(k.vx, 5.4, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, 7.2, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, ram_knockback_vy, 0.001);
}

test "calculateRamImpulse negative direction" {
    const k = calculateRamImpulse(-3.0, -4.0);
    try std.testing.expectApproxEqAbs(k.vx, -5.4, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, -7.2, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, ram_knockback_vy, 0.001);
}

test "calculateRamImpulse clamps tiny offset to minimum length" {
    const k = calculateRamImpulse(0.1, 0.0);
    try std.testing.expectApproxEqAbs(k.vx, 4.5, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, ram_knockback_vy, 0.001);
}

test "calculateRamImpulse handles zero offset without panic" {
    const k = calculateRamImpulse(0.0, 0.0);
    try std.testing.expectApproxEqAbs(k.vx, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, ram_knockback_vy, 0.001);
}
