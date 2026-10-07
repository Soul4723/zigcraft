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

pub const mob_hit_height_offset: f32 = 0.4;

pub fn mobDelta(mx: f32, my: f32, mz: f32, px: f32, py: f32, pz: f32) [3]f32 {
    return .{ mx - px, (my + mob_hit_height_offset) - py, mz - pz };
}

test "mobDelta calculation" {
    const d = mobDelta(10.0, 5.0, 2.0, 10.0, 5.4, 2.0);
    try std.testing.expectApproxEqAbs(d[0], 0.0, 0.001);
    try std.testing.expectApproxEqAbs(d[1], 0.0, 0.001);
    try std.testing.expectApproxEqAbs(d[2], 0.0, 0.001);
}

pub const ProjectileStep = struct {
    pos: [3]f32,
    vel: [3]f32,
    life: f32,
};

pub fn stepMotion(px: f32, py: f32, pz: f32, vx: f32, vy: f32, vz: f32, life: f32, dt: f32) ProjectileStep {
    const nvy = stepVy(vy, dt);
    return .{
        .pos = .{ px + vx * dt, py + nvy * dt, pz + vz * dt },
        .vel = .{ vx, nvy, vz },
        .life = life - dt,
    };
}

test "stepMotion updates velocity and position" {
    const s = stepMotion(0, 10, 0, 1, 0, 2, 2.0, 0.5);
    try std.testing.expectEqual(@as(f32, 1.5), s.life);
    try std.testing.expectEqual(@as(f32, -6.0), s.vel[1]);
    try std.testing.expectEqual(@as(f32, 0.5), s.pos[0]);
    try std.testing.expectEqual(@as(f32, 7.0), s.pos[1]);
    try std.testing.expectEqual(@as(f32, 1.0), s.pos[2]);
}
