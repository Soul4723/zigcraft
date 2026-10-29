const std = @import("std");

// ============================================================================
// Constants & Configuration
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;
pub const TICK_DT: f32 = 1.0 / @as(f32, @floatFromInt(TICKS_PER_SECOND)); // 0.05 seconds
pub const MIN_CHARGE_TICKS: u32 = 10; // 0.5s minimum charge threshold
pub const FULL_CHARGE_TICKS: u32 = 20; // 1.0s full charge threshold
pub const MIN_CHARGE_SECONDS: f32 = 0.5;
pub const FULL_CHARGE_SECONDS: f32 = 1.0;

/// Base launch speed and scaling per Riptide level (m/s):
/// initial_speed = 6.0 + 3.0 * level
pub const BASE_LAUNCH_SPEED: f32 = 6.0;
pub const SPEED_PER_RIPTIDE_LEVEL: f32 = 3.0;

/// Trident combat damage attributes:
pub const BASE_TRIDENT_DAMAGE: f32 = 9.0; // 9.0 HP (4.5 hearts)
pub const KINETIC_VELOCITY_SCALING: f32 = 0.5; // +0.5 HP damage bonus per m/s of launch speed

/// AOE radial splash impact attributes:
pub const AOE_RADIUS: f32 = 2.0; // 2.0m radius from impact point
pub const AOE_BASE_DAMAGE: f32 = 9.0; // 9.0 HP splash damage to surrounding hostile mobs
pub const DEFAULT_KNOCKBACK_IMPULSE: f32 = 6.0; // 6.0 m/s outward radial impulse

/// Flight duration and durability:
pub const RIPTIDE_FLIGHT_DURATION_TICKS: u32 = 20; // 1.0s spin vortex flight
pub const TRIDENT_MAX_DURABILITY: u16 = 250;
pub const RIPTIDE_DURABILITY_COST: u16 = 1; // 1 durability point per surge launch

// ============================================================================
// Enums & Types
// ============================================================================

/// Riptide enchantment levels (I, II, III).
pub const RiptideLevel = enum(u8) {
    level_1 = 1,
    level_2 = 2,
    level_3 = 3,

    // Aliases for convenience across call sites
    pub const one = RiptideLevel.level_1;
    pub const two = RiptideLevel.level_2;
    pub const three = RiptideLevel.level_3;
    pub const I = RiptideLevel.level_1;
    pub const II = RiptideLevel.level_2;
    pub const III = RiptideLevel.level_3;

    pub fn toInt(self: RiptideLevel) u8 {
        return @intFromEnum(self);
    }

    pub fn toFloat(self: RiptideLevel) f32 {
        return @as(f32, @floatFromInt(@intFromEnum(self)));
    }

    pub fn fromInt(val: u8) ?RiptideLevel {
        return switch (val) {
            1 => .level_1,
            2 => .level_2,
            3 => .level_3,
            else => null,
        };
    }

    /// Computes launch speed for this level: 6.0 + 3.0 * level.
    pub fn launchSpeed(self: RiptideLevel) f32 {
        return BASE_LAUNCH_SPEED + SPEED_PER_RIPTIDE_LEVEL * self.toFloat();
    }
};

/// Ambient weather state.
pub const Weather = enum(u8) {
    clear_sky = 0,
    raining = 1,
    thunderstorming = 2,

    pub fn isRaining(self: Weather) bool {
        return self == .raining or self == .thunderstorming;
    }
};

/// Liquid medium the player is submerged or standing in.
pub const WaterMedium = enum(u8) {
    none = 0,
    still_water = 1,
    flowing_water = 2,
    bubble_column = 3,

    pub fn isInWater(self: WaterMedium) bool {
        return self != .none;
    }
};

/// Validation result when attempting to activate a Riptide surge.
pub const CanRiptideResult = enum {
    success,
    not_in_water_or_rain,
    incompatible_enchantments,
    insufficient_charge,
    broken_trident,
    no_riptide_enchantment,

    pub fn isSuccess(self: CanRiptideResult) bool {
        return self == .success;
    }
};

/// Particle types emitted by the spinning hydrodynamic vortex and water splash.
pub const ParticleType = enum(u8) {
    bubble = 0,
    splash = 1,
    riptide_vortex = 2,
};

/// Acoustic cues emitted on Riptide activation and impacts.
pub const SoundEffect = enum(u8) {
    trident_riptide_1 = 0,
    trident_riptide_2 = 1,
    trident_riptide_3 = 2,
    trident_hit = 3,
    splash = 4,
};

/// Classification of entities interacting with Riptide kinetic impacts.
pub const EntityKind = enum(u8) {
    player = 0,
    zombie = 1,
    skeleton = 2,
    creeper = 3,
    spider = 4,
    drowned = 5,
    enderman = 6,
    witch = 7,
    passive_animal = 8,
    item_drop = 9,
    other = 10,

    pub fn isHostile(self: EntityKind) bool {
        return switch (self) {
            .zombie, .skeleton, .creeper, .spider, .drowned, .witch => true,
            else => false,
        };
    }

    pub fn isMob(self: EntityKind) bool {
        return self != .player and self != .item_drop;
    }
};

// ============================================================================
// Structs
// ============================================================================

/// Ambient environmental context for the player.
pub const PlayerEnvironment = struct {
    water_medium: WaterMedium = .none,
    weather: Weather = .clear_sky,
    exposed_to_sky: bool = false,

    /// Riptide can only be activated when:
    /// - Player is standing in water (still water, flowing water, bubble column) OR
    /// - Weather is currently raining or thunderstorming (exposed to open sky rain).
    pub fn canRiptide(self: PlayerEnvironment) bool {
        if (self.water_medium.isInWater()) {
            return true;
        }
        if (self.weather.isRaining() and self.exposed_to_sky) {
            return true;
        }
        return false;
    }
};

/// Trident weapon item data tracking enchantments and durability.
pub const TridentItem = struct {
    riptide: ?RiptideLevel = null,
    loyalty: u8 = 0,
    channeling: bool = false,
    unbreaking: u8 = 0,
    mending: bool = false,
    impaling: u8 = 0,
    durability: u16 = TRIDENT_MAX_DURABILITY,

    /// Riptide is strictly mutually exclusive with Loyalty and Channeling enchantments.
    pub fn hasEnchantmentConflict(self: TridentItem) bool {
        if (self.riptide != null) {
            if (self.loyalty > 0 or self.channeling) {
                return true;
            }
        }
        return false;
    }

    pub fn isBroken(self: TridentItem) bool {
        return self.durability == 0;
    }

    pub fn consumeDurability(self: *TridentItem, amount: u16) bool {
        if (self.durability >= amount) {
            self.durability -= amount;
            return true;
        } else {
            self.durability = 0;
            return false;
        }
    }
};

/// Swirling hydrodynamic vortex particle emitted in flight.
pub const Particle = struct {
    particle_type: ParticleType,
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    lifetime_ticks: u16 = 15,
    scale: f32 = 1.0,
};

/// Damage breakdown resulting from kinetic velocity scaling.
pub const KineticImpact = struct {
    base_damage: f32 = BASE_TRIDENT_DAMAGE,
    kinetic_bonus: f32,
    total_damage: f32,
};

/// Candidate entity in the world for direct or AOE kinetic collision.
pub const AoeEntity = struct {
    id: u32,
    kind: EntityKind,
    position: [3]f32,
    health: f32 = 20.0,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
};

/// Result of an AOE impact on a single entity.
pub const AoeImpactResult = struct {
    entity_id: u32,
    damage: f32,
    knockback: [3]f32,
    is_primary: bool,
};

/// Outcome of a Riptide surge launch attempt.
pub const LaunchOutcome = struct {
    result: CanRiptideResult,
    launch_speed: f32 = 0.0,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    sound: ?SoundEffect = null,
    durability_remaining: u16 = 0,
    fall_distance_reset: bool = false,
};

/// Player motion and animation state during Riptide charging and surge flight.
pub const RiptidePlayerState = struct {
    position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    fall_distance: f32 = 0.0,
    is_spinning: bool = false,
    spin_ticks_remaining: u32 = 0,
    charge_ticks: u32 = 0,
    is_charging: bool = false,
    launch_level: ?RiptideLevel = null,

    pub fn startCharging(self: *RiptidePlayerState) void {
        self.is_charging = true;
        self.charge_ticks = 0;
    }

    pub fn tickCharge(self: *RiptidePlayerState, count: u32) void {
        if (self.is_charging) {
            self.charge_ticks += count;
        }
    }

    pub fn getChargeRatio(self: RiptidePlayerState) f32 {
        const ticks_f = @as(f32, @floatFromInt(self.charge_ticks));
        const full_f = @as(f32, @floatFromInt(FULL_CHARGE_TICKS));
        return @min(1.0, ticks_f / full_f);
    }

    pub fn isFullyCharged(self: RiptidePlayerState) bool {
        return self.charge_ticks >= FULL_CHARGE_TICKS;
    }

    pub fn releaseCharge(self: *RiptidePlayerState) u32 {
        const ticks = self.charge_ticks;
        self.is_charging = false;
        self.charge_ticks = 0;
        return ticks;
    }

    /// Advance motion and spin vortex timer by dt seconds.
    pub fn tick(self: *RiptidePlayerState, dt: f32) void {
        if (self.is_spinning) {
            self.position[0] += self.velocity[0] * dt;
            self.position[1] += self.velocity[1] * dt;
            self.position[2] += self.velocity[2] * dt;

            if (self.spin_ticks_remaining > 0) {
                self.spin_ticks_remaining -= 1;
                if (self.spin_ticks_remaining == 0) {
                    self.is_spinning = false;
                }
            }
        }
    }

    pub fn stopSpinning(self: *RiptidePlayerState) void {
        self.is_spinning = false;
        self.spin_ticks_remaining = 0;
    }
};

// ============================================================================
// Core Kinematics & Mechanics Functions
// ============================================================================

/// Mutual exclusivity check: Riptide cannot be combined with Loyalty or Channeling.
pub fn checkEnchantmentCompatibility(has_riptide: bool, has_loyalty: bool, has_channeling: bool) bool {
    if (has_riptide and (has_loyalty or has_channeling)) {
        return false;
    }
    return true;
}

/// Evaluates whether a Riptide launch can occur based on enchantments, environment,
/// charge threshold, and durability.
pub fn checkCanRiptide(
    trident: TridentItem,
    env: PlayerEnvironment,
    charge_ticks: u32,
) CanRiptideResult {
    if (trident.riptide == null) {
        return .no_riptide_enchantment;
    }
    if (trident.hasEnchantmentConflict()) {
        return .incompatible_enchantments;
    }
    if (trident.isBroken()) {
        return .broken_trident;
    }
    if (!env.canRiptide()) {
        return .not_in_water_or_rain;
    }
    if (charge_ticks < MIN_CHARGE_TICKS) {
        return .insufficient_charge;
    }
    return .success;
}

/// Computes launch speed for a given Riptide level (m/s).
/// Level I: 9.0 m/s, Level II: 12.0 m/s, Level III: 15.0 m/s.
pub fn calculateLaunchSpeed(level: RiptideLevel) f32 {
    return level.launchSpeed();
}

/// Normalizes a 3D vector. If zero-length, defaults to forward {0, 0, 1}.
pub fn normalizeVector(vec: [3]f32) [3]f32 {
    const len_sq = vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2];
    if (len_sq > 0.000001) {
        const inv_len = 1.0 / @sqrt(len_sq);
        return .{ vec[0] * inv_len, vec[1] * inv_len, vec[2] * inv_len };
    }
    return .{ 0.0, 0.0, 1.0 };
}

/// Computes the 3D launch velocity along a camera look vector:
/// velocity = normalized(look_vector) * (6.0 + 3.0 * level).
pub fn computeLaunchVelocity(look_vector: [3]f32, level: RiptideLevel) [3]f32 {
    const norm = normalizeVector(look_vector);
    const speed = calculateLaunchSpeed(level);
    return .{
        norm[0] * speed,
        norm[1] * speed,
        norm[2] * speed,
    };
}

/// Converts camera pitch and yaw angles (in radians) to a normalized 3D look vector.
/// Standard coordinate convention: Y is up, -sin(pitch) is vertical heading.
pub fn computeLookVectorFromPitchYaw(pitch_rad: f32, yaw_rad: f32) [3]f32 {
    const cos_p = @cos(pitch_rad);
    return normalizeVector(.{
        -@sin(yaw_rad) * cos_p,
        -@sin(pitch_rad),
        @cos(yaw_rad) * cos_p,
    });
}

/// Computes kinetic damage bonus scaling with launch speed:
/// bonus = speed * 0.5 HP.
pub fn computeKineticBonus(speed: f32) f32 {
    return @max(0.0, speed) * KINETIC_VELOCITY_SCALING;
}

/// Computes entity collision damage breakdown:
/// total = 9.0 base melee damage + kinetic velocity bonus.
pub fn computeCollisionDamage(speed: f32) KineticImpact {
    const bonus = computeKineticBonus(speed);
    return .{
        .base_damage = BASE_TRIDENT_DAMAGE,
        .kinetic_bonus = bonus,
        .total_damage = BASE_TRIDENT_DAMAGE + bonus,
    };
}

/// Convenience scalar getter for total collision damage.
pub fn calculateCollisionDamage(speed: f32) f32 {
    return computeCollisionDamage(speed).total_damage;
}

/// Computes splash damage for entities caught in the 2.0m AOE radius.
/// Out-of-range entities (> 2.0m) receive 0.0 damage.
pub fn computeAoeDamage(distance: f32) f32 {
    if (distance < 0.0 or distance > AOE_RADIUS) {
        return 0.0;
    }
    return AOE_BASE_DAMAGE;
}

/// Distance-falloff variant of AOE splash damage (100% at 0m down to 50% at 2.0m).
pub fn computeAoeDamageWithFalloff(direct_damage: f32, distance: f32) f32 {
    if (distance < 0.0 or distance > AOE_RADIUS) {
        return 0.0;
    }
    const falloff = 1.0 - (distance / AOE_RADIUS) * 0.5;
    return direct_damage * falloff;
}

/// Computes outward radial knockback impulse away from the player origin.
pub fn computeKnockbackImpulse(from: [3]f32, to: [3]f32, strength: f32) [3]f32 {
    const dx = to[0] - from[0];
    const dy = to[1] - from[1];
    const dz = to[2] - from[2];
    const dist_sq = dx * dx + dy * dy + dz * dz;

    if (dist_sq < 0.00001) {
        // Direct overlap: default upward and forward impulse
        return .{ 0.0, strength * 0.5, strength * 0.5 };
    }
    const inv_dist = strength / @sqrt(dist_sq);
    return .{
        dx * inv_dist,
        dy * inv_dist,
        dz * inv_dist,
    };
}

/// Returns whether target position is within 2.0m radius of impact center.
pub fn isWithinAoeRadius(center: [3]f32, target_pos: [3]f32) bool {
    const dx = target_pos[0] - center[0];
    const dy = target_pos[1] - center[1];
    const dz = target_pos[2] - center[2];
    return (dx * dx + dy * dy + dz * dz) <= (AOE_RADIUS * AOE_RADIUS);
}

/// Resolves direct collision and radial 2.0m AOE splash damage & knockback against surrounding entities.
/// - Primary target takes 9.0 base melee + kinetic velocity bonus.
/// - Surrounding hostile mobs within 2.0m radius take 9.0 HP splash damage.
/// - All affected entities receive outward radial knockback away from the player.
pub fn resolveAoeImpact(
    player_pos: [3]f32,
    current_speed: f32,
    primary_target_id: ?u32,
    targets: []const AoeEntity,
    out_results: []AoeImpactResult,
) usize {
    var out_count: usize = 0;
    const direct_dmg = computeCollisionDamage(current_speed).total_damage;

    // 1. Process primary collision target if provided
    if (primary_target_id) |prim_id| {
        for (targets) |t| {
            if (t.id == prim_id and out_count < out_results.len) {
                const kb = computeKnockbackImpulse(player_pos, t.position, DEFAULT_KNOCKBACK_IMPULSE);
                out_results[out_count] = .{
                    .entity_id = t.id,
                    .damage = direct_dmg,
                    .knockback = kb,
                    .is_primary = true,
                };
                out_count += 1;
                break;
            }
        }
    }

    // 2. Process radial AOE splash targets within 2.0m
    for (targets) |t| {
        if (out_count >= out_results.len) break;
        if (primary_target_id != null and t.id == primary_target_id.?) continue;
        if (!t.kind.isHostile()) continue; // AOE splash specifically damages hostile mobs

        const dx = t.position[0] - player_pos[0];
        const dy = t.position[1] - player_pos[1];
        const dz = t.position[2] - player_pos[2];
        const dist_sq = dx * dx + dy * dy + dz * dz;

        if (dist_sq <= (AOE_RADIUS * AOE_RADIUS)) {
            const dist = @sqrt(dist_sq);
            const aoe_dmg = computeAoeDamage(dist);
            const kb = computeKnockbackImpulse(player_pos, t.position, DEFAULT_KNOCKBACK_IMPULSE);

            out_results[out_count] = .{
                .entity_id = t.id,
                .damage = aoe_dmg,
                .knockback = kb,
                .is_primary = false,
            };
            out_count += 1;
        }
    }

    return out_count;
}

/// Generates swirling water bubble and splash trail particles along the hydrodynamic vortex.
pub fn generateSwirlingParticles(
    pos: [3]f32,
    tick_offset: u32,
    count: usize,
    out_particles: []Particle,
) usize {
    var generated: usize = 0;
    const count_f = @as(f32, @floatFromInt(count));
    const tick_f = @as(f32, @floatFromInt(tick_offset));

    while (generated < count and generated < out_particles.len) : (generated += 1) {
        const i_f = @as(f32, @floatFromInt(generated));
        const angle = tick_f * 0.4 + i_f * (std.math.pi * 2.0 / count_f);
        const radius: f32 = 0.65;

        // Tangential spiral vortex velocities
        const vx = -@sin(angle) * 2.5;
        const vz = @cos(angle) * 2.5;
        const vy = 0.5 + 0.2 * @sin(i_f);

        // Alternates between bubble and splash particles
        const ptype: ParticleType = if (generated % 2 == 0) .bubble else .splash;

        out_particles[generated] = .{
            .particle_type = ptype,
            .position = .{
                pos[0] + @cos(angle) * radius,
                pos[1] + (i_f / count_f) * 1.2,
                pos[2] + @sin(angle) * radius,
            },
            .velocity = .{ vx, vy, vz },
            .lifetime_ticks = 15,
            .scale = if (ptype == .bubble) 0.8 else 1.2,
        };
    }

    return generated;
}

/// Attempts to execute a Riptide surge launch:
/// - Verifies prerequisites (environment, enchantments, charge >= 10, durability > 0).
/// - Resets player fall_distance to 0.0 (Fall Damage Mitigation).
/// - Consumes 1 durability point on the Trident.
/// - Sets is_spinning = true, initializes 20 ticks spin flight.
/// - Applies forward velocity along camera look vector based on Riptide level.
pub fn launchRiptide(
    player: *RiptidePlayerState,
    trident: *TridentItem,
    env: PlayerEnvironment,
    look_vector: [3]f32,
) LaunchOutcome {
    const check_res = checkCanRiptide(trident.*, env, player.charge_ticks);
    if (!check_res.isSuccess()) {
        return .{
            .result = check_res,
            .launch_speed = 0.0,
            .velocity = .{ 0.0, 0.0, 0.0 },
            .sound = null,
            .durability_remaining = trident.durability,
            .fall_distance_reset = false,
        };
    }

    const level = trident.riptide.?;
    const speed = calculateLaunchSpeed(level);
    const vel = computeLaunchVelocity(look_vector, level);

    // 1. Fall Damage Mitigation: resets downward vertical fall distance to 0
    player.fall_distance = 0.0;

    // 2. Durability consumption: consumes 1 durability point per launch
    _ = trident.consumeDurability(RIPTIDE_DURABILITY_COST);

    // 3. Update player kinematics and spin state
    player.velocity = vel;
    player.is_spinning = true;
    player.spin_ticks_remaining = RIPTIDE_FLIGHT_DURATION_TICKS;
    player.launch_level = level;
    player.is_charging = false;
    player.charge_ticks = 0;

    // 4. Acoustic cue mapping
    const sound: SoundEffect = switch (level) {
        .level_1 => .trident_riptide_1,
        .level_2 => .trident_riptide_2,
        .level_3 => .trident_riptide_3,
    };

    return .{
        .result = .success,
        .launch_speed = speed,
        .velocity = vel,
        .sound = sound,
        .durability_remaining = trident.durability,
        .fall_distance_reset = true,
    };
}

// ============================================================================
// Unit Tests
// ============================================================================

test "1. Environment prerequisite: standing in still water permits Riptide activation" {
    const env = PlayerEnvironment{
        .water_medium = .still_water,
        .weather = .clear_sky,
        .exposed_to_sky = false,
    };
    try std.testing.expect(env.canRiptide());
}

test "2. Environment prerequisite: standing in flowing water permits Riptide activation" {
    const env = PlayerEnvironment{
        .water_medium = .flowing_water,
        .weather = .clear_sky,
        .exposed_to_sky = false,
    };
    try std.testing.expect(env.canRiptide());
}

test "3. Environment prerequisite: standing in bubble column permits Riptide activation" {
    const env = PlayerEnvironment{
        .water_medium = .bubble_column,
        .weather = .clear_sky,
        .exposed_to_sky = true,
    };
    try std.testing.expect(env.canRiptide());
}

test "4. Environment prerequisite: open sky rain permits Riptide activation out of water" {
    const env = PlayerEnvironment{
        .water_medium = .none,
        .weather = .raining,
        .exposed_to_sky = true,
    };
    try std.testing.expect(env.canRiptide());
}

test "5. Environment prerequisite: open sky thunderstorm permits Riptide activation out of water" {
    const env = PlayerEnvironment{
        .water_medium = .none,
        .weather = .thunderstorming,
        .exposed_to_sky = true,
    };
    try std.testing.expect(env.canRiptide());
}

test "6. Environment prerequisite: dry air outside water strictly rejects Riptide activation" {
    const env = PlayerEnvironment{
        .water_medium = .none,
        .weather = .clear_sky,
        .exposed_to_sky = true,
    };
    try std.testing.expect(!env.canRiptide());

    const trident = TridentItem{ .riptide = .level_1 };
    const res = checkCanRiptide(trident, env, 20);
    try std.testing.expectEqual(CanRiptideResult.not_in_water_or_rain, res);
}

test "7. Environment prerequisite: indoor shelter during rain rejects Riptide activation" {
    const env = PlayerEnvironment{
        .water_medium = .none,
        .weather = .raining,
        .exposed_to_sky = false, // sheltered indoors under blocks
    };
    try std.testing.expect(!env.canRiptide());

    const trident = TridentItem{ .riptide = .level_2 };
    const res = checkCanRiptide(trident, env, 20);
    try std.testing.expectEqual(CanRiptideResult.not_in_water_or_rain, res);
}

test "8. Environment prerequisite: indoor shelter during thunderstorm rejects Riptide activation" {
    const env = PlayerEnvironment{
        .water_medium = .none,
        .weather = .thunderstorming,
        .exposed_to_sky = false,
    };
    try std.testing.expect(!env.canRiptide());

    const trident = TridentItem{ .riptide = .level_3 };
    const res = checkCanRiptide(trident, env, 20);
    try std.testing.expectEqual(CanRiptideResult.not_in_water_or_rain, res);
}

test "9. Environment prerequisite: standing in water indoors permits launch despite rain cover" {
    const env = PlayerEnvironment{
        .water_medium = .still_water,
        .weather = .clear_sky,
        .exposed_to_sky = false,
    };
    try std.testing.expect(env.canRiptide());

    const trident = TridentItem{ .riptide = .level_1 };
    const res = checkCanRiptide(trident, env, 20);
    try std.testing.expectEqual(CanRiptideResult.success, res);
}

test "10. Charge threshold: 0 ticks fails with insufficient_charge" {
    const trident = TridentItem{ .riptide = .level_1 };
    const env = PlayerEnvironment{ .water_medium = .still_water };
    const res = checkCanRiptide(trident, env, 0);
    try std.testing.expectEqual(CanRiptideResult.insufficient_charge, res);
}

test "11. Charge threshold: 5 ticks (0.25s) fails with insufficient_charge" {
    const trident = TridentItem{ .riptide = .level_1 };
    const env = PlayerEnvironment{ .water_medium = .still_water };
    const res = checkCanRiptide(trident, env, 5);
    try std.testing.expectEqual(CanRiptideResult.insufficient_charge, res);
}

test "12. Charge threshold: 9 ticks (0.45s) fails just below minimum threshold" {
    const trident = TridentItem{ .riptide = .level_2 };
    const env = PlayerEnvironment{ .water_medium = .still_water };
    const res = checkCanRiptide(trident, env, 9);
    try std.testing.expectEqual(CanRiptideResult.insufficient_charge, res);
}

test "13. Charge threshold: 10 ticks (0.50s) satisfies minimum threshold and succeeds" {
    const trident = TridentItem{ .riptide = .level_2 };
    const env = PlayerEnvironment{ .water_medium = .still_water };
    const res = checkCanRiptide(trident, env, 10);
    try std.testing.expectEqual(CanRiptideResult.success, res);
}

test "14. Charge threshold: 15 ticks (intermediate charge) succeeds" {
    const trident = TridentItem{ .riptide = .level_3 };
    const env = PlayerEnvironment{ .water_medium = .still_water };
    const res = checkCanRiptide(trident, env, 15);
    try std.testing.expectEqual(CanRiptideResult.success, res);
}

test "15. Charge threshold: 20 ticks (1.0s full charge) succeeds" {
    const trident = TridentItem{ .riptide = .level_3 };
    const env = PlayerEnvironment{ .water_medium = .still_water };
    const res = checkCanRiptide(trident, env, 20);
    try std.testing.expectEqual(CanRiptideResult.success, res);
}

test "16. Charge ratio: clamps to 1.0 when exceeding full charge 20 ticks" {
    var p = RiptidePlayerState{};
    p.startCharging();
    p.tickCharge(10);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), p.getChargeRatio(), 0.001);
    try std.testing.expect(!p.isFullyCharged());

    p.tickCharge(10); // 20 ticks
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.getChargeRatio(), 0.001);
    try std.testing.expect(p.isFullyCharged());

    p.tickCharge(10); // 30 ticks
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.getChargeRatio(), 0.001);
    try std.testing.expectEqual(@as(u32, 30), p.releaseCharge());
    try std.testing.expect(!p.is_charging);
    try std.testing.expectEqual(@as(u32, 0), p.charge_ticks);
}

test "17. Launch velocity scaling: Level I launch speed is exactly 9.0 m/s" {
    const speed = calculateLaunchSpeed(.level_1);
    try std.testing.expectEqual(@as(f32, 9.0), speed);
}

test "18. Launch velocity scaling: Level II launch speed is exactly 12.0 m/s" {
    const speed = calculateLaunchSpeed(.level_2);
    try std.testing.expectEqual(@as(f32, 12.0), speed);
}

test "19. Launch velocity scaling: Level III launch speed is exactly 15.0 m/s" {
    const speed = calculateLaunchSpeed(.level_3);
    try std.testing.expectEqual(@as(f32, 15.0), speed);
}

test "20. Trajectory: upward look vector {0, 1, 0} propels vertically at level speed" {
    const vel = computeLaunchVelocity(.{ 0.0, 1.0, 0.0 }, .level_1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), vel[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), vel[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), vel[2], 0.001);
}

test "21. Trajectory: horizontal look vector {0, 0, 1} propels horizontally along Z" {
    const vel = computeLaunchVelocity(.{ 0.0, 0.0, 1.0 }, .level_2);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), vel[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), vel[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), vel[2], 0.001);
}

test "22. Trajectory: diagonal look vector normalizes magnitude before applying speed" {
    const vel = computeLaunchVelocity(.{ 1.0, 1.0, 0.0 }, .level_3);
    const speed = @sqrt(vel[0] * vel[0] + vel[1] * vel[1] + vel[2] * vel[2]);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), speed, 0.001);
    try std.testing.expectApproxEqAbs(vel[0], vel[1], 0.001);
}

test "23. Trajectory: pitch and yaw camera angle conversion produces accurate 3D velocity" {
    // Pitch = -pi/2 (looking straight up): y = +1.0
    const up_look = computeLookVectorFromPitchYaw(-std.math.pi * 0.5, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), up_look[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), up_look[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), up_look[2], 0.001);

    // Horizontal along Z axis: pitch = 0, yaw = 0
    const forward_look = computeLookVectorFromPitchYaw(0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), forward_look[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), forward_look[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), forward_look[2], 0.001);
}

test "24. Spinning state: launch activates is_spinning = true with 20 ticks duration" {
    var player = RiptidePlayerState{ .charge_ticks = 20 };
    var trident = TridentItem{ .riptide = .level_1 };
    const env = PlayerEnvironment{ .water_medium = .still_water };

    const outcome = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expect(outcome.result.isSuccess());
    try std.testing.expect(player.is_spinning);
    try std.testing.expectEqual(@as(u32, 20), player.spin_ticks_remaining);
}

test "25. Spinning state: tick execution advances position, decrements spin ticks, and ends spin" {
    var player = RiptidePlayerState{
        .position = .{ 0.0, 0.0, 0.0 },
        .velocity = .{ 10.0, 0.0, 0.0 },
        .is_spinning = true,
        .spin_ticks_remaining = 2,
    };

    player.tick(0.05);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), player.position[0], 0.001);
    try std.testing.expect(player.is_spinning);
    try std.testing.expectEqual(@as(u32, 1), player.spin_ticks_remaining);

    player.tick(0.05);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), player.position[0], 0.001);
    try std.testing.expect(!player.is_spinning);
    try std.testing.expectEqual(@as(u32, 0), player.spin_ticks_remaining);
}

test "26. Particle emission: generates ParticleType.bubble and ParticleType.splash" {
    var particles: [10]Particle = undefined;
    const count = generateSwirlingParticles(.{ 10.0, 64.0, 10.0 }, 0, 6, &particles);
    try std.testing.expectEqual(@as(usize, 6), count);

    var bubble_count: usize = 0;
    var splash_count: usize = 0;
    for (particles[0..count]) |p| {
        if (p.particle_type == .bubble) bubble_count += 1;
        if (p.particle_type == .splash) splash_count += 1;
    }

    try std.testing.expect(bubble_count > 0);
    try std.testing.expect(splash_count > 0);
    try std.testing.expectEqual(@as(usize, 3), bubble_count);
    try std.testing.expectEqual(@as(usize, 3), splash_count);
}

test "27. Particle emission: swirling vortex positions and tangential velocities" {
    var particles: [4]Particle = undefined;
    const center = [3]f32{ 0.0, 10.0, 0.0 };
    _ = generateSwirlingParticles(center, 0, 4, &particles);

    for (particles) |p| {
        const dx = p.position[0] - center[0];
        const dz = p.position[2] - center[2];
        const r = @sqrt(dx * dx + dz * dz);
        try std.testing.expectApproxEqAbs(@as(f32, 0.65), r, 0.01);
        // Tangential velocity check: non-zero horizontal speed
        const speed_h = @sqrt(p.velocity[0] * p.velocity[0] + p.velocity[2] * p.velocity[2]);
        try std.testing.expect(speed_h > 2.0);
    }
}

test "28. Kinetic collision: zero speed deals base 9.0 HP damage" {
    const impact = computeCollisionDamage(0.0);
    try std.testing.expectEqual(@as(f32, 9.0), impact.base_damage);
    try std.testing.expectEqual(@as(f32, 0.0), impact.kinetic_bonus);
    try std.testing.expectEqual(@as(f32, 9.0), impact.total_damage);
}

test "29. Kinetic collision: Level I launch speed (9.0 m/s) inflicts 9.0 base + 4.5 kinetic bonus (13.5 HP)" {
    const speed = calculateLaunchSpeed(.level_1);
    const impact = computeCollisionDamage(speed);
    try std.testing.expectEqual(@as(f32, 9.0), impact.base_damage);
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), impact.kinetic_bonus, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 13.5), impact.total_damage, 0.001);
}

test "30. Kinetic collision: Level II launch speed (12.0 m/s) inflicts 9.0 base + 6.0 kinetic bonus (15.0 HP)" {
    const speed = calculateLaunchSpeed(.level_2);
    const impact = computeCollisionDamage(speed);
    try std.testing.expectEqual(@as(f32, 9.0), impact.base_damage);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), impact.kinetic_bonus, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), impact.total_damage, 0.001);
}

test "31. Kinetic collision: Level III launch speed (15.0 m/s) inflicts 9.0 base + 7.5 kinetic bonus (16.5 HP)" {
    const speed = calculateLaunchSpeed(.level_3);
    const impact = computeCollisionDamage(speed);
    try std.testing.expectEqual(@as(f32, 9.0), impact.base_damage);
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), impact.kinetic_bonus, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 16.5), impact.total_damage, 0.001);
}

test "32. AOE impact: hostile mobs within 2.0m radius take 9.0 HP splash damage" {
    const player_pos = [3]f32{ 0.0, 0.0, 0.0 };
    const targets = [_]AoeEntity{
        .{ .id = 101, .kind = .zombie, .position = .{ 1.5, 0.0, 0.0 } },
        .{ .id = 102, .kind = .skeleton, .position = .{ 0.0, 1.8, 0.0 } },
    };
    var results: [4]AoeImpactResult = undefined;
    const hit_count = resolveAoeImpact(player_pos, 0.0, null, &targets, &results);

    try std.testing.expectEqual(@as(usize, 2), hit_count);
    try std.testing.expectEqual(@as(f32, 9.0), results[0].damage);
    try std.testing.expectEqual(@as(f32, 9.0), results[1].damage);
    try std.testing.expect(!results[0].is_primary);
    try std.testing.expect(!results[1].is_primary);
}

test "33. AOE impact: hostile mobs beyond 2.0m radius take 0 damage" {
    const player_pos = [3]f32{ 0.0, 0.0, 0.0 };
    const targets = [_]AoeEntity{
        .{ .id = 201, .kind = .creeper, .position = .{ 2.01, 0.0, 0.0 } },
        .{ .id = 202, .kind = .spider, .position = .{ 3.5, 0.0, 0.0 } },
    };
    var results: [4]AoeImpactResult = undefined;
    const hit_count = resolveAoeImpact(player_pos, 0.0, null, &targets, &results);
    try std.testing.expectEqual(@as(usize, 0), hit_count);
}

test "34. AOE impact: passive animals and item drops are excluded from hostile splash damage" {
    const player_pos = [3]f32{ 0.0, 0.0, 0.0 };
    const targets = [_]AoeEntity{
        .{ .id = 301, .kind = .passive_animal, .position = .{ 1.0, 0.0, 0.0 } },
        .{ .id = 302, .kind = .item_drop, .position = .{ 0.5, 0.0, 0.0 } },
    };
    var results: [4]AoeImpactResult = undefined;
    const hit_count = resolveAoeImpact(player_pos, 0.0, null, &targets, &results);
    try std.testing.expectEqual(@as(usize, 0), hit_count);
}

test "35. AOE impact: primary hit target receives direct scaled damage and is not duplicated in AOE" {
    const player_pos = [3]f32{ 0.0, 0.0, 0.0 };
    const targets = [_]AoeEntity{
        .{ .id = 401, .kind = .zombie, .position = .{ 0.5, 0.0, 0.0 } },
        .{ .id = 402, .kind = .skeleton, .position = .{ 1.5, 0.0, 0.0 } },
    };
    var results: [4]AoeImpactResult = undefined;
    const hit_count = resolveAoeImpact(player_pos, 12.0, 401, &targets, &results);

    try std.testing.expectEqual(@as(usize, 2), hit_count);
    // Primary target 401 takes direct damage: 9.0 + 6.0 = 15.0 HP
    try std.testing.expectEqual(@as(u32, 401), results[0].entity_id);
    try std.testing.expect(results[0].is_primary);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), results[0].damage, 0.001);

    // Secondary target 402 takes splash damage: 9.0 HP
    try std.testing.expectEqual(@as(u32, 402), results[1].entity_id);
    try std.testing.expect(!results[1].is_primary);
    try std.testing.expectEqual(@as(f32, 9.0), results[1].damage);
}

test "36. Outward radial knockback: computes impulse vector directed away from player" {
    const player_pos = [3]f32{ 10.0, 64.0, 10.0 };
    const mob_pos = [3]f32{ 12.0, 64.0, 10.0 }; // mob is +2 in X direction
    const kb = computeKnockbackImpulse(player_pos, mob_pos, 6.0);

    try std.testing.expectApproxEqAbs(@as(f32, 6.0), kb[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), kb[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), kb[2], 0.001);
}

test "37. Mutual exclusivity: Riptide + Loyalty combination is rejected" {
    const trident = TridentItem{
        .riptide = .level_1,
        .loyalty = 1,
    };
    try std.testing.expect(trident.hasEnchantmentConflict());
    try std.testing.expect(!checkEnchantmentCompatibility(true, true, false));

    const env = PlayerEnvironment{ .water_medium = .still_water };
    const res = checkCanRiptide(trident, env, 20);
    try std.testing.expectEqual(CanRiptideResult.incompatible_enchantments, res);
}

test "38. Mutual exclusivity: Riptide + Channeling combination is rejected" {
    const trident = TridentItem{
        .riptide = .level_2,
        .channeling = true,
    };
    try std.testing.expect(trident.hasEnchantmentConflict());
    try std.testing.expect(!checkEnchantmentCompatibility(true, false, true));

    const env = PlayerEnvironment{ .water_medium = .still_water };
    const res = checkCanRiptide(trident, env, 20);
    try std.testing.expectEqual(CanRiptideResult.incompatible_enchantments, res);
}

test "39. Mutual exclusivity: Riptide + Loyalty + Channeling combination is rejected" {
    const trident = TridentItem{
        .riptide = .level_3,
        .loyalty = 3,
        .channeling = true,
    };
    try std.testing.expect(trident.hasEnchantmentConflict());
    try std.testing.expect(!checkEnchantmentCompatibility(true, true, true));
}

test "40. Mutual exclusivity: Riptide + Unbreaking + Mending + Impaling is fully accepted" {
    const trident = TridentItem{
        .riptide = .level_3,
        .unbreaking = 3,
        .mending = true,
        .impaling = 5,
    };
    try std.testing.expect(!trident.hasEnchantmentConflict());
    try std.testing.expect(checkEnchantmentCompatibility(true, false, false));

    const env = PlayerEnvironment{ .water_medium = .still_water };
    const res = checkCanRiptide(trident, env, 20);
    try std.testing.expectEqual(CanRiptideResult.success, res);
}

test "41. Mutual exclusivity: Loyalty + Channeling without Riptide is compatible" {
    const trident = TridentItem{
        .riptide = null,
        .loyalty = 3,
        .channeling = true,
    };
    try std.testing.expect(!trident.hasEnchantmentConflict());
    try std.testing.expect(checkEnchantmentCompatibility(false, true, true));
}

test "42. Fall damage mitigation: launch resets fall_distance from 45.0 blocks to 0.0" {
    var player = RiptidePlayerState{
        .fall_distance = 45.0,
        .charge_ticks = 20,
    };
    var trident = TridentItem{ .riptide = .level_1 };
    const env = PlayerEnvironment{ .water_medium = .still_water };

    const outcome = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expect(outcome.result.isSuccess());
    try std.testing.expect(outcome.fall_distance_reset);
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
}

test "43. Fall damage mitigation: upward vertical launch in open rain eliminates accumulated fall" {
    var player = RiptidePlayerState{
        .fall_distance = 60.0,
        .charge_ticks = 15,
        .velocity = .{ 0.0, -25.0, 0.0 }, // rapid downward plunge
    };
    var trident = TridentItem{ .riptide = .level_3 };
    const env = PlayerEnvironment{
        .water_medium = .none,
        .weather = .raining,
        .exposed_to_sky = true,
    };

    const outcome = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expect(outcome.result.isSuccess());
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
    // Downward velocity replaced by upward launch velocity +15.0 m/s
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), player.velocity[1], 0.001);
}

test "44. Fall damage mitigation: horizontal surge in mid-air rain eliminates fall distance" {
    var player = RiptidePlayerState{
        .fall_distance = 25.0,
        .charge_ticks = 10,
    };
    var trident = TridentItem{ .riptide = .level_2 };
    const env = PlayerEnvironment{
        .water_medium = .none,
        .weather = .thunderstorming,
        .exposed_to_sky = true,
    };

    const outcome = launchRiptide(&player, &trident, env, .{ 1.0, 0.0, 0.0 });
    try std.testing.expect(outcome.result.isSuccess());
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), player.velocity[0], 0.001);
}

test "45. Durability wear: Riptide launch consumes exactly 1 durability point" {
    var player = RiptidePlayerState{ .charge_ticks = 20 };
    var trident = TridentItem{
        .riptide = .level_1,
        .durability = 250,
    };
    const env = PlayerEnvironment{ .water_medium = .still_water };

    const outcome = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expect(outcome.result.isSuccess());
    try std.testing.expectEqual(@as(u16, 249), trident.durability);
    try std.testing.expectEqual(@as(u16, 249), outcome.durability_remaining);
}

test "46. Durability wear: consecutive launches consume 1 durability per surge" {
    var player = RiptidePlayerState{ .charge_ticks = 20 };
    var trident = TridentItem{
        .riptide = .level_2,
        .durability = 250,
    };
    const env = PlayerEnvironment{ .water_medium = .still_water };

    _ = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expectEqual(@as(u16, 249), trident.durability);

    player.charge_ticks = 20;
    _ = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expectEqual(@as(u16, 248), trident.durability);

    player.charge_ticks = 20;
    _ = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expectEqual(@as(u16, 247), trident.durability);
}

test "47. Durability: broken trident (0 durability) cannot activate Riptide" {
    var player = RiptidePlayerState{ .charge_ticks = 20 };
    var trident = TridentItem{
        .riptide = .level_1,
        .durability = 0, // broken
    };
    const env = PlayerEnvironment{ .water_medium = .still_water };

    const outcome = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expectEqual(CanRiptideResult.broken_trident, outcome.result);
    try std.testing.expect(!player.is_spinning);
}

test "48. Durability: final launch at 1 durability succeeds and exhausts trident" {
    var player = RiptidePlayerState{ .charge_ticks = 20 };
    var trident = TridentItem{
        .riptide = .level_1,
        .durability = 1,
    };
    const env = PlayerEnvironment{ .water_medium = .still_water };

    const outcome = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expect(outcome.result.isSuccess());
    try std.testing.expectEqual(@as(u16, 0), trident.durability);
    try std.testing.expect(trident.isBroken());

    // Subsequent launch fails with broken_trident
    player.charge_ticks = 20;
    const fail_outcome = launchRiptide(&player, &trident, env, .{ 0.0, 1.0, 0.0 });
    try std.testing.expectEqual(CanRiptideResult.broken_trident, fail_outcome.result);
}

test "49. Integrated simulation: charge, launch, vortex motion, collision, and particle emission" {
    var player = RiptidePlayerState{
        .position = .{ 0.0, 64.0, 0.0 },
        .fall_distance = 30.0,
    };
    var trident = TridentItem{
        .riptide = .level_3,
        .durability = 200,
    };
    const env = PlayerEnvironment{
        .water_medium = .none,
        .weather = .raining,
        .exposed_to_sky = true,
    };

    // 1. Hold charge
    player.startCharging();
    player.tickCharge(10);
    player.tickCharge(10); // 20 ticks full charge
    try std.testing.expect(player.isFullyCharged());

    // 2. Launch Riptide towards +Z
    const outcome = launchRiptide(&player, &trident, env, .{ 0.0, 0.0, 1.0 });
    try std.testing.expect(outcome.result.isSuccess());
    try std.testing.expectEqual(SoundEffect.trident_riptide_3, outcome.sound.?);
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
    try std.testing.expectEqual(@as(u16, 199), trident.durability);
    try std.testing.expect(player.is_spinning);

    // 3. Tick flight & emit swirling particles
    player.tick(0.05);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), player.position[2], 0.001);

    var particles: [8]Particle = undefined;
    const p_count = generateSwirlingParticles(player.position, 1, 8, &particles);
    try std.testing.expectEqual(@as(usize, 8), p_count);

    // 4. Kinetic impact on entity
    const hostile_mobs = [_]AoeEntity{
        .{ .id = 901, .kind = .drowned, .position = .{ 0.0, 64.0, 1.0 } },
        .{ .id = 902, .kind = .zombie, .position = .{ 0.5, 64.0, 1.5 } },
    };
    var impacts: [4]AoeImpactResult = undefined;
    const impact_count = resolveAoeImpact(player.position, outcome.launch_speed, 901, &hostile_mobs, &impacts);

    try std.testing.expectEqual(@as(usize, 2), impact_count);
    // Direct target takes 16.5 HP (9.0 + 7.5 kinetic bonus for Level III 15.0 m/s)
    try std.testing.expectEqual(@as(u32, 901), impacts[0].entity_id);
    try std.testing.expectApproxEqAbs(@as(f32, 16.5), impacts[0].damage, 0.001);
    // AOE target takes 9.0 HP splash
    try std.testing.expectEqual(@as(u32, 902), impacts[1].entity_id);
    try std.testing.expectEqual(@as(f32, 9.0), impacts[1].damage);
}
