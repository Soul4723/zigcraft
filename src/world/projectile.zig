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

pub fn projectileBlockCoords(px: f32, py: f32, pz: f32) [3]i32 {
    return .{
        @intFromFloat(@floor(px)),
        @intFromFloat(@floor(py)),
        @intFromFloat(@floor(pz)),
    };
}

test "projectileBlockCoords floor conversion" {
    const coords = projectileBlockCoords(2.8, -1.2, 5.0);
    try std.testing.expectEqual(@as(i32, 2), coords[0]);
    try std.testing.expectEqual(@as(i32, -2), coords[1]);
    try std.testing.expectEqual(@as(i32, 5), coords[2]);
}

pub fn initialVelocity(dir_x: f32, dir_y: f32, dir_z: f32) [3]f32 {
    return .{
        dir_x * throw_speed,
        dir_y * throw_speed + throw_up,
        dir_z * throw_speed,
    };
}

test "initialVelocity calculation" {
    const v = initialVelocity(1.0, 0.0, 0.0);
    try std.testing.expectEqual(@as(f32, throw_speed), v[0]);
    try std.testing.expectEqual(@as(f32, throw_up), v[1]);
    try std.testing.expectEqual(@as(f32, 0.0), v[2]);
}

pub const fireball_speed: f32 = 10.0;
pub const fireball_life: f32 = 4.0;
pub const fireball_damage: f32 = 3.0;
pub const fireball_range_sq: f32 = 30.0 * 30.0;
pub const fireball_cooldown: f32 = 2.5;

pub fn inFireballRange(dx: f32, dz: f32) bool {
    return dx * dx + dz * dz < fireball_range_sq;
}

pub fn fireballVelocity(dx: f32, dy: f32, dz: f32) [3]f32 {
    const len = @max(0.001, @sqrt(dx * dx + dy * dy + dz * dz));
    return .{ dx / len * fireball_speed, dy / len * fireball_speed, dz / len * fireball_speed };
}

test "fireball range and velocity" {
    try std.testing.expect(inFireballRange(10.0, 10.0));
    try std.testing.expect(!inFireballRange(25.0, 20.0));
    const v = fireballVelocity(3.0, 0.0, 4.0);
    try std.testing.expectApproxEqAbs(v[0], 6.0, 0.001);
    try std.testing.expectApproxEqAbs(v[1], 0.0, 0.001);
    try std.testing.expectApproxEqAbs(v[2], 8.0, 0.001);
}

pub const spectral_arrow_damage: u8 = 2;
pub const spectral_arrow_glow_duration: f32 = 10.0;

test "spectral arrow constants" {
    try std.testing.expectEqual(@as(u8, 2), spectral_arrow_damage);
    try std.testing.expectEqual(@as(f32, 10.0), spectral_arrow_glow_duration);
}

pub const bow_draw_time: f32 = 1.0;
pub const bow_min_speed: f32 = 12.0;
pub const bow_max_speed: f32 = 32.0;
pub const bow_durability: u16 = 384;

pub fn bowArrowSpeed(charge: f32) f32 {
    return bow_min_speed + (bow_max_speed - bow_min_speed) * std.math.clamp(charge, 0.0, 1.0);
}

pub fn bowArrowDamage(charge: f32) u8 {
    return 1 + @as(u8, @intFromFloat(std.math.clamp(charge, 0.0, 1.0) * 5.0));
}

pub fn bowInitialVelocity(dir_x: f32, dir_y: f32, dir_z: f32, speed: f32) [3]f32 {
    return .{
        dir_x * speed,
        dir_y * speed + 1.2,
        dir_z * speed,
    };
}

test "bow speed and damage scaling" {
    try std.testing.expectApproxEqAbs(bowArrowSpeed(0.0), 12.0, 0.01);
    try std.testing.expectApproxEqAbs(bowArrowSpeed(1.0), 32.0, 0.01);
    try std.testing.expectApproxEqAbs(bowArrowSpeed(0.5), 22.0, 0.01);

    try std.testing.expectEqual(@as(u8, 1), bowArrowDamage(0.0));
    try std.testing.expectEqual(@as(u8, 3), bowArrowDamage(0.5));
    try std.testing.expectEqual(@as(u8, 6), bowArrowDamage(1.0));

    const vel = bowInitialVelocity(1.0, 0.0, 0.0, 20.0);
    try std.testing.expectApproxEqAbs(vel[0], 20.0, 0.01);
    try std.testing.expectApproxEqAbs(vel[1], 1.2, 0.01);
    try std.testing.expectApproxEqAbs(vel[2], 0.0, 0.01);
}

pub const crossbow_load_time: f32 = 1.25;
pub const crossbow_arrow_speed: f32 = 42.0;
pub const crossbow_arrow_damage: u8 = 8;
pub const crossbow_durability: u16 = 465;

pub fn crossbowInitialVelocity(dir_x: f32, dir_y: f32, dir_z: f32) [3]f32 {
    return .{
        dir_x * crossbow_arrow_speed,
        dir_y * crossbow_arrow_speed + 0.6,
        dir_z * crossbow_arrow_speed,
    };
}

test "crossbow velocity and damage constants" {
    try std.testing.expectEqual(@as(u8, 8), crossbow_arrow_damage);
    try std.testing.expectEqual(@as(u16, 465), crossbow_durability);
    try std.testing.expectApproxEqAbs(crossbow_arrow_speed, 42.0, 0.01);
    const vel = crossbowInitialVelocity(0.0, 0.0, 1.0);
    try std.testing.expectApproxEqAbs(vel[0], 0.0, 0.01);
    try std.testing.expectApproxEqAbs(vel[1], 0.6, 0.01);
    try std.testing.expectApproxEqAbs(vel[2], 42.0, 0.01);
}

pub const firework_rocket_speed: f32 = 24.0;
pub const firework_rocket_life: f32 = 1.1; // Explodes after ~1.1s flight
pub const firework_explosion_damage: u8 = 6;
pub const firework_explosion_radius: f32 = 3.5;

pub fn fireworkInitialVelocity(dir_x: f32, dir_y: f32, dir_z: f32) [3]f32 {
    return .{
        dir_x * firework_rocket_speed,
        dir_y * firework_rocket_speed + 2.5, // slight upward boost
        dir_z * firework_rocket_speed,
    };
}

test "firework rocket trajectory constants and velocity" {
    try std.testing.expectEqual(@as(u8, 6), firework_explosion_damage);
    try std.testing.expectApproxEqAbs(firework_rocket_speed, 24.0, 0.01);
    try std.testing.expectApproxEqAbs(firework_explosion_radius, 3.5, 0.01);
    const vel = fireworkInitialVelocity(0.0, 1.0, 0.0);
    try std.testing.expectApproxEqAbs(vel[0], 0.0, 0.01);
    try std.testing.expectApproxEqAbs(vel[1], 26.5, 0.01);
    try std.testing.expectApproxEqAbs(vel[2], 0.0, 0.01);
}

pub const crossbow_rocket_speed: f32 = 38.0;

pub fn crossbowRocketVelocity(dir_x: f32, dir_y: f32, dir_z: f32) [3]f32 {
    return .{
        dir_x * crossbow_rocket_speed,
        dir_y * crossbow_rocket_speed + 0.4,
        dir_z * crossbow_rocket_speed,
    };
}

test "crossbow rocket velocity calculation" {
    try std.testing.expectApproxEqAbs(crossbow_rocket_speed, 38.0, 0.01);
    const vel = crossbowRocketVelocity(1.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(vel[0], 38.0, 0.01);
    try std.testing.expectApproxEqAbs(vel[1], 0.4, 0.01);
    try std.testing.expectApproxEqAbs(vel[2], 0.0, 0.01);
}

pub const crossbow_pierce_count: u8 = 2; // Penetrates through up to 2 entities, terminates on 3rd

pub fn decrementPierce(remaining_pierce: u8) struct { dead: bool, next_pierce: u8 } {
    if (remaining_pierce > 0) {
        return .{ .dead = false, .next_pierce = remaining_pierce - 1 };
    }
    return .{ .dead = true, .next_pierce = 0 };
}

test "decrementPierce multi-entity penetration sequence" {
    const p: u8 = 2;
    const r1 = decrementPierce(p);
    try std.testing.expectEqual(false, r1.dead);
    try std.testing.expectEqual(@as(u8, 1), r1.next_pierce);

    const r2 = decrementPierce(r1.next_pierce);
    try std.testing.expectEqual(false, r2.dead);
    try std.testing.expectEqual(@as(u8, 0), r2.next_pierce);

    const r3 = decrementPierce(r2.next_pierce);
    try std.testing.expectEqual(true, r3.dead);
    try std.testing.expectEqual(@as(u8, 0), r3.next_pierce);
}
