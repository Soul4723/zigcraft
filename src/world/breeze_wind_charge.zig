const std = @import("std");
const BlockId = @import("block.zig").BlockId;

pub const max_health: f32 = 30.0;
pub const ground_friction: f32 = 0.6;
pub const eye_height: f32 = 1.8;
pub const wind_particle_swirl_base: f32 = 0.35;
pub const gravity: f32 = 9.8;
pub const max_leap_distance: f32 = 15.0;
pub const max_leap_height: f32 = 5.0;
pub const deflection_damping: f32 = 0.8;
pub const wind_charge_speed: f32 = 20.0;
pub const wind_charge_gravity: f32 = 0.0;
pub const wind_charge_cooldown_ticks: u16 = 40;
pub const wind_charge_cooldown_seconds: f32 = 2.0;
pub const wind_burst_radius: f32 = 3.5;
pub const wind_burst_knockback_scale: f32 = 1.2;
pub const wind_charge_direct_damage: f32 = 1.0;
pub const breeze_rod_tag: u16 = 371;

pub const Vec3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }
};

pub const Leap = struct {
    velocity: Vec3,
    duration: f32,
    landing: Vec3,
    peak_y: f32,
};

/// Computes a ballistic arc with a chosen apex. Horizontal range and apex are
/// clamped to the Breeze's movement envelope; vertical target offset is retained.
pub fn calculateLeap(start: Vec3, target: Vec3, requested_apex: f32) Leap {
    const dx = target.x - start.x;
    const dz = target.z - start.z;
    const distance = @sqrt(dx * dx + dz * dz);
    const horizontal_scale = if (distance > max_leap_distance) max_leap_distance / distance else 1.0;
    const vertical_delta = std.math.clamp(target.y - start.y, -max_leap_height, max_leap_height - 0.01);
    const landing = Vec3{
        .x = start.x + dx * horizontal_scale,
        .y = start.y + vertical_delta,
        .z = start.z + dz * horizontal_scale,
    };
    const apex = @min(max_leap_height, @max(0.25, requested_apex));
    const rise = @max(apex, vertical_delta + 0.01);
    const fall = @max(0.01, rise - vertical_delta);
    const up_time = @sqrt(2.0 * rise / gravity);
    const down_time = @sqrt(2.0 * fall / gravity);
    const duration = up_time + down_time;
    const vy = gravity * up_time;
    const vx = if (duration > 0.0) (landing.x - start.x) / duration else 0.0;
    const vz = if (duration > 0.0) (landing.z - start.z) / duration else 0.0;
    return .{
        .velocity = .{ .x = vx, .y = vy, .z = vz },
        .duration = duration,
        .landing = landing,
        .peak_y = start.y + rise,
    };
}

pub fn leapPosition(start: Vec3, leap: Leap, elapsed: f32) Vec3 {
    const t = @min(@max(elapsed, 0.0), leap.duration);
    return .{
        .x = start.x + leap.velocity.x * t,
        .y = start.y + leap.velocity.y * t - 0.5 * gravity * t * t,
        .z = start.z + leap.velocity.z * t,
    };
}

pub fn takesWaterDamage(in_water: bool) bool {
    return in_water;
}

pub const ProjectileKind = enum {
    arrow,
    spectral_arrow,
    tipped_arrow,
    trident,
    egg,
    snowball,
    splash_potion,
    other,
};

pub fn isPhysicalProjectile(kind: ProjectileKind) bool {
    return kind != .other;
}

pub const Deflection = struct {
    velocity: Vec3,
    is_deflected: bool,
    damage_to_breeze: f32,
};

/// A supplied spread vector makes the reflection deterministic and testable.
pub fn deflectProjectile(kind: ProjectileKind, incoming: Vec3, random_spread: Vec3) Deflection {
    if (!isPhysicalProjectile(kind)) return .{ .velocity = incoming, .is_deflected = false, .damage_to_breeze = 0.0 };
    return .{
        .velocity = .{
            .x = -incoming.x * deflection_damping + random_spread.x,
            .y = -incoming.y * deflection_damping + random_spread.y,
            .z = -incoming.z * deflection_damping + random_spread.z,
        },
        .is_deflected = true,
        .damage_to_breeze = 0.0,
    };
}

pub const WindCharge = struct {
    position: Vec3,
    velocity: Vec3,
    owner_id: u32,

    pub fn aim(position: Vec3, target: Vec3, owner_id: u32) WindCharge {
        const dx = target.x - position.x;
        const dy = target.y - position.y;
        const dz = target.z - position.z;
        const length = @sqrt(dx * dx + dy * dy + dz * dz);
        if (length == 0.0) return .{ .position = position, .velocity = .{}, .owner_id = owner_id };
        const scale = wind_charge_speed / length;
        return .{
            .position = position,
            .velocity = .{ .x = dx * scale, .y = dy * scale, .z = dz * scale },
            .owner_id = owner_id,
        };
    }

    pub fn advance(self: *WindCharge, dt: f32) void {
        self.position.x += self.velocity.x * dt;
        self.position.y += self.velocity.y * dt;
        self.position.z += self.velocity.z * dt;
    }
};

pub const BreezeAttack = struct {
    cooldown_ticks: u16 = 0,

    pub fn tick(self: *BreezeAttack) void {
        if (self.cooldown_ticks > 0) self.cooldown_ticks -= 1;
    }

    pub fn fire(self: *BreezeAttack, origin: Vec3, target: Vec3, owner_id: u32) ?WindCharge {
        if (self.cooldown_ticks > 0) return null;
        self.cooldown_ticks = wind_charge_cooldown_ticks;
        return WindCharge.aim(origin, target, owner_id);
    }
};

pub const BurstHit = struct {
    within_radius: bool,
    knockback: Vec3,
    direct_damage: f32,
};

pub fn resolveWindBurst(center: Vec3, target: Vec3, direct_hit: bool) BurstHit {
    const dx = target.x - center.x;
    const dy = target.y - center.y;
    const dz = target.z - center.z;
    const distance = @sqrt(dx * dx + dy * dy + dz * dz);
    if (distance > wind_burst_radius or distance == 0.0) return .{
        .within_radius = distance <= wind_burst_radius,
        .knockback = .{},
        .direct_damage = if (direct_hit and distance == 0.0) wind_charge_direct_damage else 0.0,
    };
    const magnitude = ((wind_burst_radius - distance) / wind_burst_radius) * wind_burst_knockback_scale;
    return .{
        .within_radius = true,
        .knockback = .{ .x = dx / distance * magnitude, .y = dy / distance * magnitude, .z = dz / distance * magnitude },
        .direct_damage = if (direct_hit) wind_charge_direct_damage else 0.0,
    };
}

/// The world currently has no button BlockIds, so buttons are modeled here
/// alongside real block states to keep their wind activation rules explicit.
pub const InteractiveBlock = union(enum) {
    block: BlockId,
    wooden_button_pressed: bool,
    stone_button_pressed: bool,
};

pub fn actuateByWind(block: InteractiveBlock) ?InteractiveBlock {
    return switch (block) {
        .wooden_button_pressed => |pressed| .{ .wooden_button_pressed = !pressed },
        .stone_button_pressed => |pressed| .{ .stone_button_pressed = !pressed },
        .block => |id| switch (id) {
            .lever_off => .{ .block = .lever_on },
            .lever_on => .{ .block = .lever_off },
            .wooden_trapdoor_closed => .{ .block = .wooden_trapdoor_open },
            .wooden_trapdoor_open => .{ .block = .wooden_trapdoor_closed },
            .iron_trapdoor_closed => .{ .block = .iron_trapdoor_open },
            .iron_trapdoor_open => .{ .block = .iron_trapdoor_closed },
            .copper_trapdoor_closed => .{ .block = .copper_trapdoor_open },
            .copper_trapdoor_open => .{ .block = .copper_trapdoor_closed },
            .wooden_door_closed => .{ .block = .wooden_door_open },
            .wooden_door_open => .{ .block = .wooden_door_closed },
            .copper_door_closed => .{ .block = .copper_door_open },
            .copper_door_open => .{ .block = .copper_door_closed },
            // Iron doors and their powered states are intentionally immune.
            else => null,
        },
    };
}

pub const BreezeRodDrop = struct { item_tag: u16 = breeze_rod_tag, count: u8 };

pub fn breezeRodDrops(base_roll: u8, looting_level: u8) BreezeRodDrop {
    const base = @min(@as(u8, 2), @max(@as(u8, 1), base_roll));
    return .{ .count = base + looting_level };
}

pub const EntityState = struct {
    health: f32 = max_health,
    position: Vec3 = .{},

    pub fn damage(self: *EntityState, amount: f32) void {
        self.health = @max(0.0, self.health - @max(0.0, amount));
    }

    pub fn isDefeated(self: EntityState) bool {
        return self.health <= 0.0;
    }
};

test "Breeze health and movement constants match the entity profile" {
    try std.testing.expectEqual(@as(f32, 30.0), max_health);
    try std.testing.expectEqual(@as(f32, 0.6), ground_friction);
    try std.testing.expectEqual(@as(f32, 1.8), eye_height);
    try std.testing.expectEqual(@as(f32, 0.35), wind_particle_swirl_base);
}

test "leap horizontal distance is capped at fifteen blocks" {
    const leap = calculateLeap(.{}, .{ .x = 30.0 }, 3.0);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), leap.landing.x, 0.001);
}

test "leap preserves requested horizontal target within range" {
    const leap = calculateLeap(.{}, .{ .x = 8.0, .z = 6.0 }, 3.0);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), leap.landing.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), leap.landing.z, 0.001);
}

test "leap velocity is positive and gravity defines a parabolic arc" {
    const leap = calculateLeap(.{}, .{ .x = 10.0 }, 4.0);
    try std.testing.expect(leap.velocity.y > 0.0);
    try std.testing.expect(leap.duration > 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), leapPosition(.{}, leap, leap.duration).y, 0.01);
}

test "leap peak elevation does not exceed five blocks" {
    const leap = calculateLeap(.{}, .{ .y = 1.0 }, 9.0);
    try std.testing.expect(leap.peak_y <= max_leap_height + 0.001);
}

test "leap arc reaches its computed peak at ascent duration" {
    const leap = calculateLeap(.{}, .{ .x = 5.0 }, 3.0);
    const midpoint = leapPosition(.{}, leap, leap.duration / 2.0);
    try std.testing.expect(midpoint.y > 2.9);
}

test "leap landing coordinates match the clamped trajectory" {
    const start = Vec3{ .x = 2.0, .y = 4.0, .z = -3.0 };
    const leap = calculateLeap(start, .{ .x = 22.0, .y = 4.0, .z = -3.0 }, 2.0);
    const landed = leapPosition(start, leap, leap.duration);
    try std.testing.expectApproxEqAbs(leap.landing.x, landed.x, 0.001);
    try std.testing.expectApproxEqAbs(leap.landing.y, landed.y, 0.01);
    try std.testing.expectApproxEqAbs(leap.landing.z, landed.z, 0.001);
}

test "water is an environmental damage hazard" {
    try std.testing.expect(takesWaterDamage(true));
    try std.testing.expect(!takesWaterDamage(false));
}

test "arrow projectile automatically deflects without damaging Breeze" {
    const result = deflectProjectile(.arrow, .{ .x = 4.0 }, .{});
    try std.testing.expect(result.is_deflected);
    try std.testing.expectEqual(@as(f32, 0.0), result.damage_to_breeze);
}

test "spectral arrow deflects with damped inverted velocity" {
    const result = deflectProjectile(.spectral_arrow, .{ .x = 5.0 }, .{});
    try std.testing.expectApproxEqAbs(@as(f32, -4.0), result.velocity.x, 0.001);
}

test "tipped arrows are among the automatically reflected projectiles" {
    try std.testing.expect(deflectProjectile(.tipped_arrow, .{ .z = 3.0 }, .{}).is_deflected);
}

test "tridents are deflected" {
    try std.testing.expect(deflectProjectile(.trident, .{ .y = -2.0 }, .{}).is_deflected);
}

test "eggs are deflected" {
    try std.testing.expect(deflectProjectile(.egg, .{ .x = 1.0 }, .{}).is_deflected);
}

test "snowballs are deflected" {
    try std.testing.expect(deflectProjectile(.snowball, .{ .x = 1.0 }, .{}).is_deflected);
}

test "splash potions are deflected" {
    try std.testing.expect(deflectProjectile(.splash_potion, .{ .x = 1.0 }, .{}).is_deflected);
}

test "deflection applies random spread after reflection" {
    const result = deflectProjectile(.arrow, .{ .x = 5.0, .y = -2.0 }, .{ .x = 0.5, .y = 0.25 });
    try std.testing.expectApproxEqAbs(@as(f32, -3.5), result.velocity.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.85), result.velocity.y, 0.001);
}

test "non physical projectiles are not deflected" {
    const result = deflectProjectile(.other, .{ .x = 3.0 }, .{});
    try std.testing.expect(!result.is_deflected);
    try std.testing.expectEqual(@as(f32, 3.0), result.velocity.x);
}

test "wind charge aims at twenty meters per second" {
    const charge = WindCharge.aim(.{}, .{ .x = 3.0, .z = 4.0 }, 9);
    try std.testing.expectApproxEqAbs(wind_charge_speed, @sqrt(charge.velocity.x * charge.velocity.x + charge.velocity.y * charge.velocity.y + charge.velocity.z * charge.velocity.z), 0.001);
}

test "wind charge has zero gravity and advances linearly" {
    var charge = WindCharge.aim(.{}, .{ .x = 1.0 }, 1);
    charge.advance(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), charge.position.x, 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), wind_charge_gravity);
}

test "Breeze fires once and observes a forty tick cooldown" {
    var attack = BreezeAttack{};
    try std.testing.expect(attack.fire(.{}, .{ .x = 5.0 }, 1) != null);
    try std.testing.expectEqual(@as(u16, 40), attack.cooldown_ticks);
    try std.testing.expect(attack.fire(.{}, .{ .x = 5.0 }, 1) == null);
}

test "Breeze attack becomes ready after forty ticks" {
    var attack = BreezeAttack{};
    _ = attack.fire(.{}, .{ .x = 5.0 }, 1);
    for (0..40) |_| attack.tick();
    try std.testing.expect(attack.fire(.{}, .{ .x = 5.0 }, 1) != null);
}

test "direct wind charge hit deals exactly one health" {
    const hit = resolveWindBurst(.{}, .{}, true);
    try std.testing.expectEqual(@as(f32, 1.0), hit.direct_damage);
}

test "wind burst includes its three point five meter boundary" {
    const hit = resolveWindBurst(.{}, .{ .x = 3.5 }, false);
    try std.testing.expect(hit.within_radius);
}

test "wind burst excludes entities beyond its spherical radius" {
    const hit = resolveWindBurst(.{}, .{ .x = 3.5, .y = 0.1 }, false);
    try std.testing.expect(!hit.within_radius);
}

test "wind burst knockback scales down with distance" {
    const near = resolveWindBurst(.{}, .{ .x = 1.0 }, false);
    const far = resolveWindBurst(.{}, .{ .x = 2.0 }, false);
    try std.testing.expect(near.knockback.x > far.knockback.x);
    try std.testing.expectApproxEqAbs(@as(f32, (3.5 - 1.0) / 3.5 * 1.2), near.knockback.x, 0.001);
}

test "wind burst knockback points away from its center in three dimensions" {
    const hit = resolveWindBurst(.{}, .{ .x = 1.0, .y = 1.0, .z = 1.0 }, false);
    try std.testing.expect(hit.knockback.x > 0 and hit.knockback.y > 0 and hit.knockback.z > 0);
}

test "wind burst direct damage is limited to a direct entity impact" {
    try std.testing.expectEqual(@as(f32, 0.0), resolveWindBurst(.{}, .{ .x = 1.0 }, false).direct_damage);
}

test "wind burst outside radius applies no impulse" {
    const hit = resolveWindBurst(.{}, .{ .x = 4.0 }, true);
    try std.testing.expectEqual(@as(f32, 0.0), hit.knockback.x);
    try std.testing.expectEqual(@as(f32, 0.0), hit.direct_damage);
}

test "wooden button toggles on a wind burst" {
    const result = actuateByWind(.{ .wooden_button_pressed = false }).?;
    try std.testing.expect(result.wooden_button_pressed);
}

test "stone button toggles off on a wind burst" {
    const result = actuateByWind(.{ .stone_button_pressed = true }).?;
    try std.testing.expect(!result.stone_button_pressed);
}

test "lever changes to the opposite state" {
    try std.testing.expectEqual(BlockId.lever_on, actuateByWind(.{ .block = .lever_off }).?.block);
    try std.testing.expectEqual(BlockId.lever_off, actuateByWind(.{ .block = .lever_on }).?.block);
}

test "wooden trapdoor toggles open and closed" {
    try std.testing.expectEqual(BlockId.wooden_trapdoor_open, actuateByWind(.{ .block = .wooden_trapdoor_closed }).?.block);
    try std.testing.expectEqual(BlockId.wooden_trapdoor_closed, actuateByWind(.{ .block = .wooden_trapdoor_open }).?.block);
}

test "iron trapdoor toggles open and closed" {
    try std.testing.expectEqual(BlockId.iron_trapdoor_open, actuateByWind(.{ .block = .iron_trapdoor_closed }).?.block);
    try std.testing.expectEqual(BlockId.iron_trapdoor_closed, actuateByWind(.{ .block = .iron_trapdoor_open }).?.block);
}

test "copper trapdoor toggles open and closed" {
    try std.testing.expectEqual(BlockId.copper_trapdoor_open, actuateByWind(.{ .block = .copper_trapdoor_closed }).?.block);
    try std.testing.expectEqual(BlockId.copper_trapdoor_closed, actuateByWind(.{ .block = .copper_trapdoor_open }).?.block);
}

test "wooden and copper doors toggle on a wind burst" {
    try std.testing.expectEqual(BlockId.wooden_door_open, actuateByWind(.{ .block = .wooden_door_closed }).?.block);
    try std.testing.expectEqual(BlockId.copper_door_open, actuateByWind(.{ .block = .copper_door_closed }).?.block);
}

test "iron door is rejected without redstone" {
    try std.testing.expect(actuateByWind(.{ .block = .iron_door_closed }) == null);
    try std.testing.expect(actuateByWind(.{ .block = .iron_door_open }) == null);
}

test "ordinary stone is not actuated by a wind burst" {
    try std.testing.expect(actuateByWind(.{ .block = .stone }) == null);
}

test "Breeze defeat drops one or two tagged rods" {
    try std.testing.expectEqual(breeze_rod_tag, breezeRodDrops(1, 0).item_tag);
    try std.testing.expectEqual(@as(u8, 1), breezeRodDrops(1, 0).count);
    try std.testing.expectEqual(@as(u8, 2), breezeRodDrops(2, 0).count);
}

test "Looting scales Breeze rod drops" {
    try std.testing.expectEqual(@as(u8, 4), breezeRodDrops(2, 2).count);
}

test "defeated entity state clamps health and recognizes defeat" {
    var breeze = EntityState{};
    breeze.damage(31.0);
    try std.testing.expectEqual(@as(f32, 0.0), breeze.health);
    try std.testing.expect(breeze.isDefeated());
}
