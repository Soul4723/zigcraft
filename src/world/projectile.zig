const std = @import("std");

pub const gravity: f32 = 12.0;
pub const throw_speed: f32 = 18.0;
pub const throw_up: f32 = 2.0;
pub const throw_life: f32 = 3.0;
pub const throw_cooldown: f32 = 0.4;
pub const hit_radius_sq: f32 = 0.64;
pub const thrown_cap: usize = 8;

pub fn stepVy(vy: f32, dt: f32) f32 {
    return vy - gravity * dt;
}

pub fn isExpired(life: f32) bool {
    return life <= 0.0;
}

pub fn hitsMob(dx: f32, dy: f32, dz: f32) bool {
    return dx * dx + dy * dy + dz * dz < hit_radius_sq;
}

test "projectile gravity step" {
    try std.testing.expectEqual(stepVy(0.0, 1.0), -12.0);
    try std.testing.expectEqual(stepVy(5.0, 0.5), -1.0);
}

test "projectile expiry" {
    try std.testing.expect(isExpired(0.0));
    try std.testing.expect(isExpired(-1.0));
    try std.testing.expect(!isExpired(0.1));
}

test "mob hit radius" {
    try std.testing.expect(hitsMob(0, 0, 0));
    try std.testing.expect(hitsMob(0.5, 0.5, 0.3));
    try std.testing.expect(!hitsMob(1.0, 0, 0));
}
