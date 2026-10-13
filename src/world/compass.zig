const std = @import("std");

pub const compass_hidden: f32 = -999.0;

/// Calculates screen-relative compass needle angle in radians.
pub fn calculateNeedleAngle(target_x: f32, target_z: f32, player_x: f32, player_z: f32, cam_yaw: f32) f32 {
    const bearing = std.math.atan2(target_x - player_x, target_z - player_z);
    return bearing - (std.math.pi / 2.0 - cam_yaw);
}

/// Calculates chaotic fluctuating spin angle of an uncalibrated compass in the Nether.
pub fn netherSpinAngle(world_time: f32, cam_yaw: f32) f32 {
    const spin = world_time * 8.0 + @sin(world_time * 4.7) * 1.5;
    return spin - (std.math.pi / 2.0 - cam_yaw);
}

test "calculateNeedleAngle directly north" {
    const angle = calculateNeedleAngle(0.0, 10.0, 0.0, 0.0, -std.math.pi / 2.0);
    try std.testing.expectApproxEqAbs(angle, -std.math.pi, 0.001);
}

test "calculateNeedleAngle target south" {
    const angle = calculateNeedleAngle(0.0, -10.0, 0.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(angle, std.math.pi / 2.0, 0.001);
}

test "netherSpinAngle changes with world time" {
    const s0 = netherSpinAngle(0.0, 0.0);
    const s1 = netherSpinAngle(1.5, 0.0);
    try std.testing.expect(s0 != s1);
}
