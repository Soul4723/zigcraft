const std = @import("std");

// ============================================================================
// Constants & Configuration
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;
pub const TICK_DT: f32 = 1.0 / @as(f32, @floatFromInt(TICKS_PER_SECOND)); // 0.05 seconds
pub const CRUISE_SPEED: f32 = 0.50; // 0.50 m/s (slow, deliberate tracking)
pub const CRUISE_SPEED_PER_TICK: f32 = CRUISE_SPEED * TICK_DT; // 0.025 m/tick
pub const NAVIGATION_EVALUATION_INTERVAL_TICKS: u32 = 4;
pub const BULLET_DAMAGE: f32 = 4.0; // 4.0 HP (2 hearts)
pub const LEVITATION_DURATION_TICKS: u32 = 200; // 200 game ticks = 10.0 seconds
pub const LEVITATION_DURATION_SECONDS: f32 = 10.0;
pub const LEVITATION_LIFT_PER_TICK_PER_LEVEL: f32 = 0.05; // +0.05 * level blocks/tick
pub const LEVITATION_LIFT_SPEED_PER_LEVEL: f32 = 1.0; // +1.0 m/s per level
pub const BULLET_MAX_LIFETIME_TICKS: u32 = 1200; // 60 seconds = 1200 ticks
pub const BULLET_HITBOX_RADIUS: f32 = 0.3125; // 5/16 block
pub const DEFAULT_GRAVITY: f32 = 25.0; // m/s^2 downward gravity
pub const SHIELD_MAX_DURABILITY: u16 = 336;
pub const SHIELD_DEFAULT_DURABILITY_DAMAGE: u16 = 1;

// ============================================================================
// Enums & Types
// ============================================================================

/// Cardinal axes along which the Shulker Bullet navigates orthogonally.
pub const CardinalAxis = enum(u2) {
    x = 0,
    y = 1,
    z = 2,
};

/// Particle types emitted by missiles and impacts.
pub const ParticleType = enum(u8) {
    end_rod = 0,
    crit = 1,
    spark = 2,
};

/// Acoustic sound cues produced by bullet events and defense actions.
pub const SoundEffect = enum(u8) {
    shield_block_metallic_clang = 0,
    bullet_hit = 1,
    bullet_deflected = 2,
    bullet_destroyed = 3,
    milk_drink = 4,
    levitation_float = 5,
};

/// Alias for SoundEffect.
pub const Sound = SoundEffect;

/// Attack classifications capable of interacting with or deflecting missiles.
pub const AttackKind = enum(u8) {
    fist = 0,
    sword = 1,
    axe = 2,
    arrow = 3,
    projectile_other = 4,

    pub fn isMelee(self: AttackKind) bool {
        return self == .fist or self == .sword or self == .axe;
    }

    pub fn isProjectile(self: AttackKind) bool {
        return self == .arrow or self == .projectile_other;
    }
};

/// Particle data generated along the bullet trajectory.
pub const Particle = struct {
    particle_type: ParticleType = .end_rod,
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    color_rgba: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 }, // pure white
    lifetime_ticks: u16 = 20,
    scale: f32 = 1.0,
};

/// Shield state tracking block posture, orientation, and durability.
pub const ShieldState = struct {
    is_blocking: bool = false,
    durability: u16 = SHIELD_MAX_DURABILITY,
    facing_direction: [3]f32 = .{ 0.0, 0.0, 1.0 },

    pub fn damageShield(self: *ShieldState, amount: u16) void {
        if (self.durability > amount) {
            self.durability -= amount;
        } else {
            self.durability = 0;
            self.is_blocking = false;
        }
    }
};

/// Levitation status effect: applies constant upward vertical velocity and overrides gravity.
pub const LevitationEffect = struct {
    level: u8 = 1,
    duration_ticks: u32 = LEVITATION_DURATION_TICKS,
    active: bool = true,

    pub fn init(level: u8, duration_ticks: u32) LevitationEffect {
        return .{
            .level = level,
            .duration_ticks = duration_ticks,
            .active = duration_ticks > 0 and level > 0,
        };
    }

    /// Upward velocity in blocks per game tick: vy = +0.05 * level blocks/tick.
    pub fn upwardVelocityBlocksPerTick(self: LevitationEffect) f32 {
        if (!self.active) return 0.0;
        return LEVITATION_LIFT_PER_TICK_PER_LEVEL * @as(f32, @floatFromInt(self.level));
    }

    /// Upward velocity in meters per second: vy = +1.0 * level m/s.
    pub fn upwardVelocityMetersPerSecond(self: LevitationEffect) f32 {
        if (!self.active) return 0.0;
        return LEVITATION_LIFT_SPEED_PER_LEVEL * @as(f32, @floatFromInt(self.level));
    }

    /// Decrement duration by 1 tick and deactivate when expired.
    pub fn tick(self: *LevitationEffect) void {
        if (!self.active) return;
        if (self.duration_ticks > 0) {
            self.duration_ticks -= 1;
            if (self.duration_ticks == 0) {
                self.active = false;
            }
        } else {
            self.active = false;
        }
    }

    /// Drinking milk immediately cancels the effect.
    pub fn cureWithMilk(self: *LevitationEffect) void {
        self.active = false;
        self.duration_ticks = 0;
    }
};

/// Impact outcome from a Shulker Bullet collision with an entity.
pub const ImpactResult = struct {
    damage_dealt: f32,
    levitation_applied: bool,
    levitation_duration_ticks: u32,
    levitation_level: u8,
    shield_blocked: bool,
    sound_effect: ?SoundEffect,
    shield_durability_damage: u16,
    bullet_destroyed: bool,
};

/// Result of striking or deflecting an incoming Shulker Bullet.
pub const DeflectionResult = struct {
    is_deflected: bool,
    bullet_destroyed: bool,
    new_velocity: [3]f32,
    sound_effect: ?SoundEffect,
};

/// Entity kinematics representing a target (e.g. player or mob) experiencing gravity,
/// drag, levitation, and shield interactions.
pub const EntityKinematics = struct {
    position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    health: f32 = 20.0,
    on_ground: bool = false,
    levitation: ?LevitationEffect = null,
    shield: ShieldState = .{},
    gravity: f32 = DEFAULT_GRAVITY,
    horizontal_drag: f32 = 0.91,

    pub fn isLevitating(self: EntityKinematics) bool {
        if (self.levitation) |lev| {
            return lev.active and lev.duration_ticks > 0;
        }
        return false;
    }

    pub fn applyLevitation(self: *EntityKinematics, level: u8, duration_ticks: u32) void {
        self.levitation = LevitationEffect.init(level, duration_ticks);
        self.on_ground = false;
    }

    pub fn cureWithMilk(self: *EntityKinematics) void {
        if (self.levitation) |*lev| {
            lev.cureWithMilk();
        }
        self.levitation = null;
    }

    /// Advance entity physics for 1 game tick.
    pub fn tickPhysics(self: *EntityKinematics, input_move_xz: [2]f32) void {
        // Horizontal movement remains player-controllable and subject to drag
        self.velocity[0] = (self.velocity[0] + input_move_xz[0]) * self.horizontal_drag;
        self.velocity[2] = (self.velocity[2] + input_move_xz[1]) * self.horizontal_drag;

        if (self.isLevitating()) {
            const lev = &self.levitation.?;
            // Overrides normal gravity: applies constant vertical upward velocity
            self.velocity[1] = lev.upwardVelocityMetersPerSecond();
            self.on_ground = false;
            lev.tick();
            if (!lev.active) {
                self.levitation = null;
            }
        } else {
            // Normal downward gravity restores immediately
            self.velocity[1] -= self.gravity * TICK_DT;
            if (self.velocity[1] < -30.0) self.velocity[1] = -30.0;
        }

        self.position[0] += self.velocity[0] * TICK_DT;
        self.position[1] += self.velocity[1] * TICK_DT;
        self.position[2] += self.velocity[2] * TICK_DT;
    }
};

/// Shulker Bullet missile entity with cardinal axis guided navigation.
pub const ShulkerBullet = struct {
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    target_entity_id: u32,
    target_position: [3]f32,

    cruise_speed: f32 = CRUISE_SPEED,
    alive: bool = true,
    is_deflected: bool = false,
    age_ticks: u32 = 0,
    max_lifetime_ticks: u32 = BULLET_MAX_LIFETIME_TICKS,

    current_axis: CardinalAxis = .x,
    current_direction: f32 = 1.0,
    ticks_since_evaluation: u32 = 0,

    pub fn init(position: [3]f32, target_entity_id: u32, target_position: [3]f32) ShulkerBullet {
        var bullet = ShulkerBullet{
            .position = position,
            .target_entity_id = target_entity_id,
            .target_position = target_position,
        };
        bullet.evaluateNavigation(target_position);
        return bullet;
    }

    /// Cardinal axis guided navigation: selects the primary axis (X, Y, or Z) with
    /// the greatest remaining distance toward the target and sets orthogonal velocity.
    pub fn evaluateNavigation(self: *ShulkerBullet, target: [3]f32) void {
        self.target_position = target;
        const dx = target[0] - self.position[0];
        const dy = target[1] - self.position[1];
        const dz = target[2] - self.position[2];

        const abs_x = @abs(dx);
        const abs_y = @abs(dy);
        const abs_z = @abs(dz);

        if (abs_x == 0.0 and abs_y == 0.0 and abs_z == 0.0) {
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.ticks_since_evaluation = 0;
            return;
        }

        if (abs_x >= abs_y and abs_x >= abs_z) {
            self.current_axis = .x;
            self.current_direction = if (dx >= 0.0) 1.0 else -1.0;
        } else if (abs_y >= abs_z) {
            self.current_axis = .y;
            self.current_direction = if (dy >= 0.0) 1.0 else -1.0;
        } else {
            self.current_axis = .z;
            self.current_direction = if (dz >= 0.0) 1.0 else -1.0;
        }

        self.velocity = .{ 0.0, 0.0, 0.0 };
        switch (self.current_axis) {
            .x => self.velocity[0] = self.current_direction * self.cruise_speed,
            .y => self.velocity[1] = self.current_direction * self.cruise_speed,
            .z => self.velocity[2] = self.current_direction * self.cruise_speed,
        }
        self.ticks_since_evaluation = 0;
    }

    /// Advance bullet by 1 game tick, re-evaluating target offset direction every 4 game ticks.
    pub fn tick(self: *ShulkerBullet, updated_target_pos: ?[3]f32) void {
        if (!self.alive) return;

        if (self.age_ticks >= self.max_lifetime_ticks) {
            self.alive = false;
            return;
        }

        if (updated_target_pos) |tgt| {
            self.target_position = tgt;
        }

        self.age_ticks += 1;
        self.ticks_since_evaluation += 1;

        // Re-evaluate target offset direction every 4 game ticks
        if (self.ticks_since_evaluation >= NAVIGATION_EVALUATION_INTERVAL_TICKS) {
            self.evaluateNavigation(self.target_position);
        }

        self.position[0] += self.velocity[0] * TICK_DT;
        self.position[1] += self.velocity[1] * TICK_DT;
        self.position[2] += self.velocity[2] * TICK_DT;

        if (self.age_ticks >= self.max_lifetime_ticks) {
            self.alive = false;
        }
    }

    /// Emits spinning white spiral swirling particles (`ParticleType.end_rod`).
    pub fn emitSpiralParticle(self: ShulkerBullet) Particle {
        const angle = @as(f32, @floatFromInt(self.age_ticks)) * (std.math.pi * 0.5);
        const radius: f32 = 0.25;

        var offset = [3]f32{ 0.0, 0.0, 0.0 };
        switch (self.current_axis) {
            .x => {
                offset[1] = radius * @sin(angle);
                offset[2] = radius * @cos(angle);
            },
            .y => {
                offset[0] = radius * @cos(angle);
                offset[2] = radius * @sin(angle);
            },
            .z => {
                offset[0] = radius * @cos(angle);
                offset[1] = radius * @sin(angle);
            },
        }

        return .{
            .particle_type = .end_rod,
            .position = .{
                self.position[0] + offset[0],
                self.position[1] + offset[1],
                self.position[2] + offset[2],
            },
            .velocity = .{
                offset[0] * 0.1,
                offset[1] * 0.1,
                offset[2] * 0.1,
            },
            .color_rgba = .{ 1.0, 1.0, 1.0, 1.0 },
            .lifetime_ticks = 20,
        };
    }

    /// Striking the incoming bullet with melee (fist, sword, axe) or projectile (arrow)
    /// destroys the bullet or deflects it away, setting is_deflected = true.
    pub fn deflectWithAttack(self: *ShulkerBullet, attack: AttackKind, deflection_aim_dir: ?[3]f32) DeflectionResult {
        _ = attack;
        if (!self.alive) {
            return .{
                .is_deflected = false,
                .bullet_destroyed = false,
                .new_velocity = self.velocity,
                .sound_effect = null,
            };
        }

        self.is_deflected = true;

        if (deflection_aim_dir) |aim| {
            const len_sq = aim[0] * aim[0] + aim[1] * aim[1] + aim[2] * aim[2];
            if (len_sq > 0.0001) {
                const inv_len = 1.0 / @sqrt(len_sq);
                const speed = self.cruise_speed * 1.5;
                self.velocity = .{
                    aim[0] * inv_len * speed,
                    aim[1] * inv_len * speed,
                    aim[2] * inv_len * speed,
                };
                return .{
                    .is_deflected = true,
                    .bullet_destroyed = false,
                    .new_velocity = self.velocity,
                    .sound_effect = .bullet_deflected,
                };
            }
        }

        self.alive = false;
        return .{
            .is_deflected = true,
            .bullet_destroyed = true,
            .new_velocity = .{ 0.0, 0.0, 0.0 },
            .sound_effect = .bullet_destroyed,
        };
    }

    /// A direct melee swat destroys the projectile and marks it deflected.
    pub fn swatWithMelee(self: *ShulkerBullet) bool {
        if (!self.alive) return false;
        self.alive = false;
        self.is_deflected = true;
        return true;
    }

    pub fn destroy(self: *ShulkerBullet) void {
        self.alive = false;
        self.is_deflected = true;
    }
};

// ============================================================================
// Impact & Shield Detection Helpers
// ============================================================================

/// Determines if the defender's shield is facing the incoming bullet vector.
pub fn isShieldFacingIncoming(defender_look: [3]f32, incoming_vector: [3]f32) bool {
    // Horizontal dot product (standard Minecraft 180-degree blocking arc)
    const dot_xz = defender_look[0] * incoming_vector[0] + defender_look[2] * incoming_vector[2];
    return dot_xz > 0.0;
}

/// Computes Euclidean 3D distance between two points.
pub fn distance3D(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

/// Resolves bullet impact on a targeted entity.
/// - Deflected bullets deal 0 damage.
/// - Blocked by shield: absorbs 100% of damage, negates Levitation, emits clang, wears shield.
/// - Unshielded: deals 4.0 HP damage, inflicts Levitation I for 200 ticks (10.0 seconds).
pub fn resolveImpact(bullet: *ShulkerBullet, target: *EntityKinematics) ImpactResult {
    if (!bullet.alive) {
        return .{
            .damage_dealt = 0.0,
            .levitation_applied = false,
            .levitation_duration_ticks = 0,
            .levitation_level = 0,
            .shield_blocked = false,
            .sound_effect = null,
            .shield_durability_damage = 0,
            .bullet_destroyed = false,
        };
    }

    // A deflected bullet deals 0 damage to the player
    if (bullet.is_deflected) {
        bullet.alive = false;
        return .{
            .damage_dealt = 0.0,
            .levitation_applied = false,
            .levitation_duration_ticks = 0,
            .levitation_level = 0,
            .shield_blocked = false,
            .sound_effect = null,
            .shield_durability_damage = 0,
            .bullet_destroyed = true,
        };
    }

    const incoming_vector = [3]f32{
        bullet.position[0] - target.position[0],
        bullet.position[1] - target.position[1],
        bullet.position[2] - target.position[2],
    };

    const is_facing = isShieldFacingIncoming(target.shield.facing_direction, incoming_vector);
    const blocked_by_shield = target.shield.is_blocking and is_facing;

    if (blocked_by_shield) {
        bullet.alive = false;
        target.shield.damageShield(SHIELD_DEFAULT_DURABILITY_DAMAGE);
        return .{
            .damage_dealt = 0.0,
            .levitation_applied = false,
            .levitation_duration_ticks = 0,
            .levitation_level = 0,
            .shield_blocked = true,
            .sound_effect = .shield_block_metallic_clang,
            .shield_durability_damage = SHIELD_DEFAULT_DURABILITY_DAMAGE,
            .bullet_destroyed = true,
        };
    } else {
        bullet.alive = false;
        target.health = @max(0.0, target.health - BULLET_DAMAGE);
        target.applyLevitation(1, LEVITATION_DURATION_TICKS);
        return .{
            .damage_dealt = BULLET_DAMAGE,
            .levitation_applied = true,
            .levitation_duration_ticks = LEVITATION_DURATION_TICKS,
            .levitation_level = 1,
            .shield_blocked = false,
            .sound_effect = .bullet_hit,
            .shield_durability_damage = 0,
            .bullet_destroyed = true,
        };
    }
}

/// Helper to simulate drinking milk and curing levitation.
pub fn drinkMilkBucket(target: *EntityKinematics) SoundEffect {
    target.cureWithMilk();
    return .milk_drink;
}

/// Multi-tick flight simulation result.
pub const FlightSimulationResult = struct {
    ticks_elapsed: u32,
    hit: bool,
    timed_out: bool,
    final_position: [3]f32,
};

/// Simulates bullet flight for up to max_ticks toward a target entity.
pub fn simulateFlight(
    bullet: *ShulkerBullet,
    target: *EntityKinematics,
    max_ticks: u32,
    hit_distance: f32,
) FlightSimulationResult {
    var t: u32 = 0;
    while (t < max_ticks and bullet.alive) : (t += 1) {
        if (distance3D(bullet.position, target.position) <= hit_distance) {
            _ = resolveImpact(bullet, target);
            return .{
                .ticks_elapsed = t,
                .hit = true,
                .timed_out = false,
                .final_position = bullet.position,
            };
        }
        bullet.tick(target.position);
    }
    return .{
        .ticks_elapsed = t,
        .hit = false,
        .timed_out = !bullet.alive or t >= max_ticks,
        .final_position = bullet.position,
    };
}

// ============================================================================
// Unit Tests (40+ comprehensive tests)
// ============================================================================

test "1. ShulkerBullet initialization sets position, target entity id, and cruise speed" {
    const bullet = ShulkerBullet.init(.{ 0.0, 10.0, 0.0 }, 42, .{ 10.0, 10.0, 0.0 });
    try std.testing.expectEqual([3]f32{ 0.0, 10.0, 0.0 }, bullet.position);
    try std.testing.expectEqual(@as(u32, 42), bullet.target_entity_id);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.cruise_speed, 0.0001);
    try std.testing.expect(bullet.alive);
    try std.testing.expect(!bullet.is_deflected);
}

test "2. ShulkerBullet cruise speed per tick is 0.025 blocks (0.50 m/s at 20 ticks/sec)" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.025), CRUISE_SPEED_PER_TICK, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), CRUISE_SPEED, 0.0001);
}

test "3. Cardinal axis navigation: selects +X axis when positive X offset is largest" {
    const bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 10.0, 2.0, 1.0 });
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.velocity[0], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[2]);
}

test "4. Cardinal axis navigation: selects -X axis when negative X offset is largest" {
    const bullet = ShulkerBullet.init(.{ 5.0, 0.0, 0.0 }, 1, .{ -5.0, 1.0, 0.0 });
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);
    try std.testing.expectApproxEqAbs(@as(f32, -0.50), bullet.velocity[0], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[2]);
}

test "5. Cardinal axis navigation: selects +Y axis when vertical Y offset is largest" {
    const bullet = ShulkerBullet.init(.{ 0.0, 2.0, 0.0 }, 1, .{ 1.0, 15.0, 2.0 });
    try std.testing.expectEqual(CardinalAxis.y, bullet.current_axis);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.velocity[1], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[2]);
}

test "6. Cardinal axis navigation: selects -Y axis when negative Y offset is largest" {
    const bullet = ShulkerBullet.init(.{ 0.0, 20.0, 0.0 }, 1, .{ 1.0, 5.0, 2.0 });
    try std.testing.expectEqual(CardinalAxis.y, bullet.current_axis);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
    try std.testing.expectApproxEqAbs(@as(f32, -0.50), bullet.velocity[1], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[2]);
}

test "7. Cardinal axis navigation: selects +Z axis when Z offset is largest" {
    const bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 1.0, 2.0, 8.0 });
    try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[1]);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.velocity[2], 0.0001);
}

test "8. Cardinal axis navigation: selects -Z axis when negative Z offset is largest" {
    const bullet = ShulkerBullet.init(.{ 0.0, 0.0, 10.0 }, 1, .{ 1.0, 2.0, 0.0 });
    try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[1]);
    try std.testing.expectApproxEqAbs(@as(f32, -0.50), bullet.velocity[2], 0.0001);
}

test "9. Cardinal axis navigation: orthogonal stepping has exactly one non-zero velocity component" {
    const bullet = ShulkerBullet.init(.{ 1.0, 2.0, 3.0 }, 1, .{ 10.0, 8.0, 5.0 });
    var non_zero_count: usize = 0;
    for (bullet.velocity) |v| {
        if (@abs(v) > 0.0001) non_zero_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), non_zero_count);
}

test "10. Cardinal axis navigation: re-evaluates target offset direction every 4 game ticks" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 10.0, 0.0, 0.0 });
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);

    // Change target position to vertical offset (Y dominant)
    const new_target = [3]f32{ 0.0, 20.0, 0.0 };

    // Ticks 1, 2, 3: does not re-evaluate, stays on X axis
    bullet.tick(new_target); // tick 1
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);
    bullet.tick(new_target); // tick 2
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);
    bullet.tick(new_target); // tick 3
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);

    // Tick 4: 4th tick boundary re-evaluates and switches to Y axis!
    bullet.tick(new_target); // tick 4
    try std.testing.expectEqual(CardinalAxis.y, bullet.current_axis);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.velocity[1], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
}

test "11. Cardinal axis navigation: maintains current axis during intermediate ticks 1, 2, 3" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 10.0 });
    try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);

    for (0..3) |_| {
        bullet.tick(.{ 50.0, 0.0, 0.0 });
        try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);
    }
}

test "12. Cardinal axis navigation: switches to Z axis when Z becomes dominant on tick 4" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 10.0, 0.0, 0.0 });
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);

    for (0..3) |_| {
        bullet.tick(.{ 0.0, 0.0, 50.0 });
    }
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);

    bullet.tick(.{ 0.0, 0.0, 50.0 });
    try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);
}

test "13. Cardinal axis navigation: sets velocity to zero when coincident with target" {
    const bullet = ShulkerBullet.init(.{ 5.0, 5.0, 5.0 }, 1, .{ 5.0, 5.0, 5.0 });
    try std.testing.expectEqual([3]f32{ 0.0, 0.0, 0.0 }, bullet.velocity);
}

test "14. Particle emission: emits spinning ParticleType.end_rod particles" {
    const bullet = ShulkerBullet.init(.{ 0.0, 10.0, 0.0 }, 1, .{ 10.0, 10.0, 0.0 });
    const p = bullet.emitSpiralParticle();
    try std.testing.expectEqual(ParticleType.end_rod, p.particle_type);
}

test "15. Particle emission: spiral particles swirl with tick-based angular advance" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 10.0, 0.0, 0.0 });
    const p0 = bullet.emitSpiralParticle();
    bullet.tick(null);
    const p1 = bullet.emitSpiralParticle();

    // Position offset must have changed due to angular rotation around X axis
    try std.testing.expect(p0.position[1] != p1.position[1] or p0.position[2] != p1.position[2]);
}

test "16. Particle emission: particle color is pure white rgba(1, 1, 1, 1)" {
    const bullet = ShulkerBullet.init(.{ 2.0, 3.0, 4.0 }, 1, .{ 5.0, 3.0, 4.0 });
    const p = bullet.emitSpiralParticle();
    try std.testing.expectEqual([4]f32{ 1.0, 1.0, 1.0, 1.0 }, p.color_rgba);
}

test "17. Impact physics: unshielded entity hit deals 4.0 HP damage (2 hearts)" {
    var bullet = ShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{ .health = 20.0 };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), result.damage_dealt, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), target.health, 0.0001);
}

test "18. Impact physics: unshielded entity hit inflicts Levitation I for 200 ticks (10.0 seconds)" {
    var bullet = ShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{};

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(result.levitation_applied);
    try std.testing.expectEqual(@as(u32, 200), result.levitation_duration_ticks);
    try std.testing.expectEqual(@as(u8, 1), result.levitation_level);
    try std.testing.expect(target.isLevitating());
    try std.testing.expectEqual(@as(u32, 200), target.levitation.?.duration_ticks);
}

test "19. Impact physics: unshielded entity hit consumes bullet (alive = false)" {
    var bullet = ShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{};

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(result.bullet_destroyed);
    try std.testing.expect(!bullet.alive);
}

test "20. Impact physics: subsequent hit on dead bullet deals 0 damage" {
    var bullet = ShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{};

    _ = resolveImpact(&bullet, &target);
    const second = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(f32, 0.0), second.damage_dealt);
    try std.testing.expect(!second.levitation_applied);
}

test "21. Shield deflection: blocking shield facing bullet incoming vector absorbs 100% damage (0 HP dealt)" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 5.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .health = 20.0,
        .shield = .{
            .is_blocking = true,
            .facing_direction = .{ 0.0, 0.0, 1.0 }, // facing +Z toward incoming bullet
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(result.shield_blocked);
    try std.testing.expectEqual(@as(f32, 0.0), result.damage_dealt);
    try std.testing.expectEqual(@as(f32, 20.0), target.health);
}

test "22. Shield deflection: blocking shield completely negates Levitation effect (0 ticks applied)" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 5.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .shield = .{
            .is_blocking = true,
            .facing_direction = .{ 0.0, 0.0, 1.0 },
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(!result.levitation_applied);
    try std.testing.expectEqual(@as(u32, 0), result.levitation_duration_ticks);
    try std.testing.expect(!target.isLevitating());
}

test "23. Shield deflection: blocking shield emits metallic clang sound effect" {
    var bullet = ShulkerBullet.init(.{ 3.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .shield = .{
            .is_blocking = true,
            .facing_direction = .{ 1.0, 0.0, 0.0 },
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(SoundEffect.shield_block_metallic_clang, result.sound_effect.?);
}

test "24. Shield deflection: blocking shield suffers durability wear" {
    var bullet = ShulkerBullet.init(.{ 3.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .shield = .{
            .is_blocking = true,
            .durability = SHIELD_MAX_DURABILITY,
            .facing_direction = .{ 1.0, 0.0, 0.0 },
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(u16, 1), result.shield_durability_damage);
    try std.testing.expectEqual(@as(u16, SHIELD_MAX_DURABILITY - 1), target.shield.durability);
}

test "25. Shield deflection: shield facing away (dot <= 0) fails to block, taking full 4.0 damage and Levitation" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 5.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .health = 20.0,
        .shield = .{
            .is_blocking = true,
            .facing_direction = .{ 0.0, 0.0, -1.0 }, // facing opposite direction
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(!result.shield_blocked);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), result.damage_dealt, 0.0001);
    try std.testing.expect(result.levitation_applied);
}

test "26. Shield deflection: unraised shield fails to block, taking full 4.0 damage and Levitation" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 5.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .health = 20.0,
        .shield = .{
            .is_blocking = false, // shield lowered
            .facing_direction = .{ 0.0, 0.0, 1.0 },
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(!result.shield_blocked);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), result.damage_dealt, 0.0001);
    try std.testing.expect(result.levitation_applied);
}

test "27. Attack deflection: striking bullet with fist deflects and destroys bullet (is_deflected = true, 0 player damage)" {
    var bullet = ShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    const res = bullet.deflectWithAttack(.fist, null);
    try std.testing.expect(res.is_deflected);
    try std.testing.expect(res.bullet_destroyed);
    try std.testing.expect(bullet.is_deflected);
    try std.testing.expect(!bullet.alive);

    var target = EntityKinematics{};
    const impact = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(f32, 0.0), impact.damage_dealt);
}

test "28. Attack deflection: striking bullet with sword deflects bullet (is_deflected = true, 0 player damage)" {
    var bullet = ShulkerBullet.init(.{ 2.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    const res = bullet.deflectWithAttack(.sword, null);
    try std.testing.expect(res.is_deflected);
    try std.testing.expect(bullet.is_deflected);
}

test "29. Attack deflection: striking bullet with axe deflects bullet (is_deflected = true, 0 player damage)" {
    var bullet = ShulkerBullet.init(.{ 2.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    const res = bullet.deflectWithAttack(.axe, null);
    try std.testing.expect(res.is_deflected);
    try std.testing.expect(bullet.is_deflected);
}

test "30. Attack deflection: striking bullet with projectile arrow deflects bullet away with redirected velocity" {
    var bullet = ShulkerBullet.init(.{ 2.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    const aim = [3]f32{ 0.0, 1.0, 0.0 }; // deflected upward
    const res = bullet.deflectWithAttack(.arrow, aim);
    try std.testing.expect(res.is_deflected);
    try std.testing.expect(!res.bullet_destroyed);
    try std.testing.expect(bullet.velocity[1] > 0.0);
}

test "31. Attack deflection: deflected bullet deals 0 damage to player on subsequent collision" {
    var bullet = ShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    _ = bullet.deflectWithAttack(.arrow, .{ 1.0, 0.0, 0.0 });
    try std.testing.expect(bullet.is_deflected);

    var target = EntityKinematics{ .health = 20.0 };
    const res = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
    try std.testing.expect(!res.levitation_applied);
    try std.testing.expectEqual(@as(f32, 20.0), target.health);
}

test "32. Attack deflection: swatWithMelee immediately destroys bullet and marks is_deflected" {
    var bullet = ShulkerBullet.init(.{ 3.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    try std.testing.expect(bullet.swatWithMelee());
    try std.testing.expect(bullet.is_deflected);
    try std.testing.expect(!bullet.alive);
    try std.testing.expect(!bullet.swatWithMelee());
}

test "33. Levitation kinematics: Levitation I applies constant vertical upward velocity of +0.05 blocks/tick (+1.0 m/s)" {
    const lev = LevitationEffect.init(1, 200);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), lev.upwardVelocityBlocksPerTick(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), lev.upwardVelocityMetersPerSecond(), 0.0001);
}

test "34. Levitation kinematics: Levitation II applies +0.10 blocks/tick (+2.0 m/s)" {
    const lev = LevitationEffect.init(2, 200);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), lev.upwardVelocityBlocksPerTick(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), lev.upwardVelocityMetersPerSecond(), 0.0001);
}

test "35. Levitation kinematics: overrides downward gravity and floats entity smoothly upward" {
    var entity = EntityKinematics{
        .position = .{ 0.0, 10.0, 0.0 },
        .velocity = .{ 0.0, 0.0, 0.0 },
    };
    entity.applyLevitation(1, 200);

    // Run 20 ticks (1 second) of physics with zero movement inputs
    for (0..20) |_| {
        entity.tickPhysics(.{ 0.0, 0.0 });
    }

    // In 1 second at +1.0 m/s, position should rise by ~1.0 meter
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), entity.position[1], 0.01);
    // Vertical velocity should remain held at +1.0 m/s
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), entity.velocity[1], 0.001);
}

test "36. Levitation kinematics: horizontal movement remains controllable with input and air drag" {
    var entity = EntityKinematics{};
    entity.applyLevitation(1, 200);

    // Player inputs forward X acceleration
    entity.tickPhysics(.{ 2.0, 0.0 });
    try std.testing.expect(entity.velocity[0] > 0.0);
    try std.testing.expect(entity.position[0] > 0.0);

    // Levitation remains intact vertically
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), entity.velocity[1], 0.001);
}

test "37. Levitation kinematics: milk bucket drinking immediately clears Levitation effect" {
    var entity = EntityKinematics{};
    entity.applyLevitation(1, 200);
    try std.testing.expect(entity.isLevitating());

    const sound = drinkMilkBucket(&entity);
    try std.testing.expectEqual(SoundEffect.milk_drink, sound);
    try std.testing.expect(!entity.isLevitating());
}

test "38. Levitation kinematics: milk drinking immediately restores normal downward gravity acceleration" {
    var entity = EntityKinematics{
        .position = .{ 0.0, 20.0, 0.0 },
        .velocity = .{ 0.0, 1.0, 0.0 },
    };
    entity.applyLevitation(1, 200);

    // Drink milk bucket to cure levitation
    _ = drinkMilkBucket(&entity);

    // Advance 1 tick: normal downward gravity must accelerate entity downward
    entity.tickPhysics(.{ 0.0, 0.0 });
    // vy = 1.0 - 25.0 * 0.05 = -0.25 m/s
    try std.testing.expect(entity.velocity[1] < 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, -0.25), entity.velocity[1], 0.001);
}

test "39. Levitation kinematics: effect expiration after 200 ticks immediately restores normal downward gravity" {
    var entity = EntityKinematics{
        .position = .{ 0.0, 20.0, 0.0 },
    };
    entity.applyLevitation(1, 200);

    // Tick for 200 game ticks
    for (0..200) |_| {
        entity.tickPhysics(.{ 0.0, 0.0 });
    }

    try std.testing.expect(!entity.isLevitating());

    // Tick 201: downward gravity is applied
    const vy_before = entity.velocity[1];
    entity.tickPhysics(.{ 0.0, 0.0 });
    try std.testing.expect(entity.velocity[1] < vy_before);
}

test "40. Flight simulation: multi-tick trajectory simulation successfully homes and hits target" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 1.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 1.0, 0.0, 0.0 },
        .health = 20.0,
    };

    const sim = simulateFlight(&bullet, &target, 100, 0.5);
    try std.testing.expect(sim.hit);
    try std.testing.expect(!sim.timed_out);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), target.health, 0.0001);
    try std.testing.expect(target.isLevitating());
}

test "41. Timeout despawn: bullet despawns after 60 seconds (1200 ticks) of flight" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 1000.0, 0.0, 0.0 });
    try std.testing.expect(bullet.alive);

    for (0..1200) |_| {
        bullet.tick(null);
    }

    try std.testing.expect(!bullet.alive);
    try std.testing.expectEqual(@as(u32, 1200), bullet.age_ticks);
}

test "42. Despawned bullet stops advancing and cannot deal damage" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 100.0, 0.0, 0.0 });
    bullet.alive = false;

    const pos_before = bullet.position;
    bullet.tick(null);
    try std.testing.expectEqual(pos_before, bullet.position);

    var target = EntityKinematics{ .health = 20.0 };
    const res = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 20.0), target.health);
}
