const std = @import("std");

pub const wind_charge_speed: f32 = 28.0;
pub const wind_burst_radius: f32 = 3.5;
pub const wind_burst_radius_sq: f32 = 12.25;
pub const self_boost_vy: f32 = 9.5;
pub const mob_knockback_vy: f32 = 6.5;
pub const wind_direct_damage: u8 = 1;

pub fn calculateSelfBoostVy(current_vy: f32, pitch_deg: f32) f32 {
    if (pitch_deg <= -35.0) {
        return @max(current_vy, self_boost_vy);
    }
    return @max(current_vy, self_boost_vy * 0.55);
}

pub fn isWithinBurstRadius(bx: f32, by: f32, bz: f32, tx: f32, ty: f32, tz: f32) bool {
    const dx = tx - bx;
    const dy = ty - by;
    const dz = tz - bz;
    const dist_sq = dx * dx + dy * dy + dz * dz;
    return dist_sq <= wind_burst_radius_sq;
}

pub fn calculateKnockbackImpulse(bx: f32, bz: f32, tx: f32, tz: f32) struct { vx: f32, vy: f32, vz: f32 } {
    const dx = tx - bx;
    const dz = tz - bz;
    const len = @max(0.25, @sqrt(dx * dx + dz * dz));
    return .{ .vx = (dx / len) * 6.0, .vy = mob_knockback_vy, .vz = (dz / len) * 6.0 };
}

test "wind charge constants" {
    try std.testing.expectApproxEqAbs(wind_charge_speed, 28.0, 0.001);
    try std.testing.expectApproxEqAbs(wind_burst_radius, 3.5, 0.001);
    try std.testing.expectApproxEqAbs(wind_burst_radius_sq, 12.25, 0.001);
    try std.testing.expectApproxEqAbs(self_boost_vy, 9.5, 0.001);
    try std.testing.expectApproxEqAbs(mob_knockback_vy, 6.5, 0.001);
    try std.testing.expectEqual(@as(u8, 1), wind_direct_damage);
}

test "burst radius squared matches radius" {
    try std.testing.expectApproxEqAbs(wind_burst_radius * wind_burst_radius, wind_burst_radius_sq, 0.001);
}

test "self boost when looking steeply down" {
    try std.testing.expectApproxEqAbs(calculateSelfBoostVy(0.0, -35.0), self_boost_vy, 0.001);
    try std.testing.expectApproxEqAbs(calculateSelfBoostVy(0.0, -90.0), self_boost_vy, 0.001);
}

test "self boost partial when not looking steeply down" {
    try std.testing.expectApproxEqAbs(calculateSelfBoostVy(0.0, -34.9), self_boost_vy * 0.55, 0.001);
    try std.testing.expectApproxEqAbs(calculateSelfBoostVy(0.0, 0.0), self_boost_vy * 0.55, 0.001);
    try std.testing.expectApproxEqAbs(calculateSelfBoostVy(0.0, 45.0), self_boost_vy * 0.55, 0.001);
}

test "self boost preserves larger current velocity" {
    try std.testing.expectApproxEqAbs(calculateSelfBoostVy(20.0, -90.0), 20.0, 0.001);
    try std.testing.expectApproxEqAbs(calculateSelfBoostVy(8.0, 0.0), 8.0, 0.001);
    try std.testing.expectApproxEqAbs(calculateSelfBoostVy(3.0, 0.0), self_boost_vy * 0.55, 0.001);
}

test "within burst radius inside and on boundary" {
    try std.testing.expect(isWithinBurstRadius(0.0, 0.0, 0.0, 0.0, 0.0, 0.0));
    try std.testing.expect(isWithinBurstRadius(0.0, 0.0, 0.0, 1.0, 1.0, 1.0));
    try std.testing.expect(isWithinBurstRadius(0.0, 0.0, 0.0, 3.5, 0.0, 0.0));
}

test "within burst radius outside" {
    try std.testing.expect(!isWithinBurstRadius(0.0, 0.0, 0.0, 3.5, 0.01, 0.0));
    try std.testing.expect(!isWithinBurstRadius(0.0, 0.0, 0.0, 5.0, 0.0, 0.0));
    try std.testing.expect(!isWithinBurstRadius(10.0, 10.0, 10.0, 20.0, 20.0, 20.0));
}

test "knockback impulse pushes along delta" {
    const k = calculateKnockbackImpulse(0.0, 0.0, 3.0, 4.0);
    try std.testing.expectApproxEqAbs(k.vx, 3.6, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, 4.8, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, mob_knockback_vy, 0.001);
}

test "knockback impulse negative direction" {
    const k = calculateKnockbackImpulse(0.0, 0.0, -3.0, -4.0);
    try std.testing.expectApproxEqAbs(k.vx, -3.6, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, -4.8, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, mob_knockback_vy, 0.001);
}

test "knockback impulse uses minimum length near center" {
    const k = calculateKnockbackImpulse(0.0, 0.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(k.vx, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, mob_knockback_vy, 0.001);
}
