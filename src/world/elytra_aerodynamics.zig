const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Maximum durability of Elytra wings (432 points in Minecraft Java Edition).
pub const max_durability: u16 = 432;

/// Durability threshold where Elytra wings become "tattered" / "broken" and unusable (1 point).
/// Elytra does NOT break completely at 0 durability; it stops functioning at 1.
pub const tattered_durability: u16 = 1;
pub const broken_durability: u16 = tattered_durability;

/// Durability restored per Phantom Membrane during anvil / crafting repair (108 points = 25% of 432).
pub const membrane_repair_amount: u16 = 108;
pub const membrane_repair_percent: u8 = 25;

/// Terminal horizontal airspeed achievable during steep dives (67.0 m/s = 3.35 blocks/tick).
pub const max_horizontal_speed: f32 = 67.0;

/// Propulsion velocity granted by an active Firework Rocket flight boost (33.5 m/s = 1.675 blocks/tick).
pub const rocket_boost_speed: f32 = 33.5;

/// Forward acceleration added along camera look vector during rocket boost (1.5 m/s^2).
pub const rocket_acceleration: f32 = 1.5;

/// Default duration of a Firework Rocket flight boost in seconds (1.5 seconds).
pub const default_rocket_duration: f32 = 1.5;

/// Minimum horizontal collision velocity required to inflict kinetic energy damage (12.0 m/s for wall impact).
pub const kinetic_damage_threshold: f32 = 12.0;

/// Kinetic damage scaling multiplier per m/s exceeding 12.0 m/s (1.2 damage per m/s excess).
pub const kinetic_damage_multiplier: f32 = 1.2;

/// Minimum collision speed required to inflict kinetic crash damage (10.0 m/s).
pub const kinetic_crash_threshold: f32 = 10.0;
pub const kinetic_crash_multiplier: f32 = 2.0;

/// Blast damage dealt to player if boosting with an explosive Firework Star rocket (5.0 HP).
pub const firework_star_blast_damage: f32 = 5.0;

/// Aerodynamic horizontal thrust conversion coefficient from diving pitch: -0.08 * sin(theta_rad).
pub const dive_thrust_coefficient: f32 = 0.08;

/// Aerodynamic vertical lift conversion coefficient from climbing pitch: 0.06 * sin(theta_rad).
pub const pitch_lift_coefficient: f32 = 0.06;

/// Atmospheric drag decay multiplier applied per tick (0.99).
pub const drag_coefficient: f32 = 0.99;

/// Default gravitational acceleration applied to gliding entities per tick (0.05 blocks/tick^2).
pub const default_gravity: f32 = 0.05;

/// Simulation ticks per second in the voxel game loop.
pub const ticks_per_second: u32 = 20;

/// Rocket boost flight duration tiers:
pub const tier1_duration_ticks: u32 = 20; // 1.0 second
pub const tier2_duration_ticks: u32 = 40; // 2.0 seconds
pub const tier3_duration_ticks: u32 = 60; // 3.0 seconds

/// Aerodynamic sink speed during level horizontal glide (descent of 1.2 m/s).
pub const level_sink_speed: f32 = -1.2;

/// Natural gravitational acceleration applied to gliding entities (9.81 m/s²).
pub const glide_gravity: f32 = 9.81;

/// Parasitic drag factor applied per second during horizontal glide.
pub const horizontal_drag_coeff: f32 = 0.05;

/// Wear and stall parameters from flight matrix.
pub const base_wear_probability: f32 = 1.0;
pub const stall_angle_degrees: f32 = 35.0;
pub const stall_speed_mps: f32 = 6.0;
pub const stall_recovery_speed_mps: f32 = 8.0;
pub const stalled_lift_multiplier: f32 = 0.1;
pub const terminal_dive_speed_mps: f32 = 67.5;
pub const dive_acceleration_mps2: f32 = 9.81;
pub const mending_durability_per_xp: u16 = 2;

// ============================================================================
// Probability & Calculation Functions
// ============================================================================

/// A roll is supplied by the caller once per 20-tick wear interval, keeping
/// this rules module deterministic and leaving random number ownership outside.
pub fn wearProbability(unbreaking_level: u8) f32 {
    return 1.0 / (@as(f32, @floatFromInt(unbreaking_level)) + 1.0);
}

pub fn shouldConsumeWear(unbreaking_level: u8, random_roll: f32) bool {
    if (random_roll < 0.0 or random_roll >= 1.0) return false;
    return random_roll < wearProbability(unbreaking_level);
}

/// Nominal expected full-durability flight duration. The broken-at-one rule
/// means an individual new Elytra stops after 431 successful wear events.
pub fn expectedFlightSeconds(unbreaking_level: u8) f32 {
    return @as(f32, @floatFromInt(max_durability)) / wearProbability(unbreaking_level);
}

/// Calculates kinetic crash damage inflicted when colliding with a solid block face at speed >= 10.0 m/s.
/// - Below 10.0 m/s: zero damage (safe impact).
/// - At or above 10.0 m/s: damage = @max(0.0, (speed - 10.0) * 2.0).
pub fn calculateKineticDamage(speed: f32) f32 {
    const v = @abs(speed);
    if (v < kinetic_crash_threshold) {
        return 0.0;
    }
    return (v - kinetic_crash_threshold) * kinetic_crash_multiplier;
}

pub fn evaluateKineticCrash(speed: f32) KineticCrashResult {
    const dmg = calculateKineticDamage(speed);
    return .{
        .damage = dmg,
        .is_crash = dmg > 0.0,
    };
}

pub fn computeKineticCrashDamage(impact_velocity: f32) f32 {
    return calculateKineticDamage(impact_velocity);
}

/// Computes kinetic energy damage inflicted when colliding horizontally into a solid wall while gliding.
/// Flying at horizontal_speed > 12.0 m/s deals `(horizontal_speed - 12.0) * 1.2` damage; 0 otherwise.
pub fn computeKineticWallImpactDamage(horizontal_speed: f32) f32 {
    const speed = @abs(horizontal_speed);
    if (speed <= kinetic_damage_threshold) {
        return 0.0;
    }
    return (speed - kinetic_damage_threshold) * kinetic_damage_multiplier;
}

/// Helper to compute kinetic wall impact damage directly from a 3D velocity vector.
pub fn computeKineticWallImpactDamageFromVel(vel: [3]f32) f32 {
    const h_speed = @sqrt(vel[0] * vel[0] + vel[2] * vel[2]);
    return computeKineticWallImpactDamage(h_speed);
}

// ============================================================================
// State Management & Flight Models
// ============================================================================

pub const RocketBoostTier = enum(u8) {
    tier1 = 1,
    tier2 = 2,
    tier3 = 3,

    pub fn durationSeconds(self: RocketBoostTier) f32 {
        return switch (self) {
            .tier1 => 1.0,
            .tier2 => 2.0,
            .tier3 => 3.0,
        };
    }

    pub fn durationTicks(self: RocketBoostTier) u32 {
        return switch (self) {
            .tier1 => tier1_duration_ticks,
            .tier2 => tier2_duration_ticks,
            .tier3 => tier3_duration_ticks,
        };
    }
};

pub const FireworkRocketProps = struct {
    duration_tier: u8 = 1,
    has_firework_star: bool = false,
    star_count: u8 = 0,

    pub fn init(tier: u8, has_star: bool) FireworkRocketProps {
        return .{
            .duration_tier = std.math.clamp(tier, 1, 3),
            .has_firework_star = has_star,
            .star_count = if (has_star) 1 else 0,
        };
    }

    pub fn durationTicks(self: FireworkRocketProps) u32 {
        return computeRocketBoostDurationTicks(self.duration_tier);
    }

    pub fn durationSeconds(self: FireworkRocketProps) f32 {
        return @as(f32, @floatFromInt(self.durationTicks())) / 20.0;
    }

    pub fn blastDamage(self: FireworkRocketProps) f32 {
        return computeRocketBlastDamage(self.has_firework_star);
    }
};
pub const FireworkRocket = FireworkRocketProps;

pub const KineticCrashResult = struct {
    damage: f32,
    is_crash: bool,
};

pub const DurabilityState = struct {
    durability: u16 = max_durability,
    equipped: bool = true,
    has_mending: bool = false,
    is_flying: bool = false,

    pub fn isBroken(self: DurabilityState) bool {
        return self.durability <= broken_durability;
    }

    pub fn canFly(self: DurabilityState) bool {
        return self.equipped and !self.isBroken();
    }

    pub fn startFlight(self: *DurabilityState) bool {
        if (!self.canFly()) return false;
        self.is_flying = true;
        return true;
    }

    /// Call once for each 20 ticks of active flight.
    pub fn tickFlightWear(self: *DurabilityState, unbreaking_level: u8, random_roll: f32) bool {
        if (!self.is_flying or !self.canFly()) {
            self.is_flying = false;
            return false;
        }
        if (!shouldConsumeWear(unbreaking_level, random_roll)) return false;
        self.durability -= 1;
        if (self.isBroken()) self.is_flying = false;
        return true;
    }

    /// Directly absorbed XP points restore two durability apiece with Mending.
    /// The caller must only invoke this for an orb absorbed while equipped.
    pub fn absorbExperience(self: *DurabilityState, xp_points: u16) u16 {
        if (!self.equipped or !self.has_mending or xp_points == 0) return 0;
        const missing = max_durability -| self.durability;
        const restored: u32 = @min(@as(u32, missing), @as(u32, xp_points) * mending_durability_per_xp);
        self.durability += @intCast(restored);
        return @intCast(restored);
    }
};

pub const AerodynamicState = struct {
    airspeed_mps: f32 = 0.0,
    is_stalled: bool = false,

    pub fn setAirspeed(self: *AerodynamicState, speed_mps: f32) void {
        self.airspeed_mps = @max(0.0, speed_mps);
    }
};

pub const FlightFrame = struct {
    airspeed_mps: f32,
    requested_pitch_degrees: f32,
    effective_pitch_degrees: f32,
    lift_coefficient: f32,
    is_stalled: bool,
    nose_down_tumble: bool,
};

/// Steps stall hysteresis and dive acceleration. Pitch uses the existing
/// convention: -90 degrees is a vertical dive, while positive pitch is climb.
pub fn stepAerodynamics(state: *AerodynamicState, pitch_degrees: f32, dt_seconds: f32) FlightFrame {
    if (dt_seconds > 0.0) {
        if (state.is_stalled) {
            if (state.airspeed_mps >= stall_recovery_speed_mps) state.is_stalled = false;
        } else if (pitch_degrees > stall_angle_degrees and state.airspeed_mps < stall_speed_mps) {
            state.is_stalled = true;
        }

        const tumbling = state.is_stalled;
        const effective_pitch = if (tumbling) -90.0 else pitch_degrees;
        if (effective_pitch <= -90.0) {
            state.airspeed_mps = @min(terminal_dive_speed_mps, state.airspeed_mps + dive_acceleration_mps2 * dt_seconds);
        }
        if (state.is_stalled and state.airspeed_mps >= stall_recovery_speed_mps) {
            state.is_stalled = false;
        }
    }
    const tumbling = state.is_stalled;
    return .{
        .airspeed_mps = state.airspeed_mps,
        .requested_pitch_degrees = pitch_degrees,
        .effective_pitch_degrees = if (tumbling) -90.0 else pitch_degrees,
        .lift_coefficient = if (tumbling) stalled_lift_multiplier else 1.0,
        .is_stalled = tumbling,
        .nose_down_tumble = tumbling,
    };
}

/// Tracks the active flight state and durability of an Elytra wing pair in live gameplay.
pub const ElytraFlightState = struct {
    /// Whether the player is currently deployed and gliding.
    is_gliding: bool = false,

    /// Remaining durability points. Defaults to full 432 points.
    /// Becomes tattered and unusable at durability == 1 rather than breaking at 0.
    durability: u16 = max_durability,

    /// Remaining duration in seconds of active Firework Rocket propulsion.
    rocket_boost_timer: f32 = 0.0,

    /// Accumulated flight time in seconds towards the next 1-second durability drain.
    glide_time_accum: f32 = 0.0,

    /// Initializes a brand new Elytra flight state at full durability.
    pub fn init() ElytraFlightState {
        return .{};
    }

    /// Initializes an Elytra flight state with a specific initial durability.
    pub fn initWithDurability(d: u16) ElytraFlightState {
        return .{
            .durability = @min(d, max_durability),
        };
    }

    /// Returns true if the Elytra wings are tattered (durability <= 1) and cannot fly.
    pub fn isTattered(self: ElytraFlightState) bool {
        return self.durability <= tattered_durability;
    }

    /// Returns true if the Elytra wings have sufficient durability (> 1) to fly.
    pub fn canFly(self: ElytraFlightState) bool {
        return self.durability > tattered_durability;
    }

    /// Returns true if an active Firework Rocket boost is currently propelling the flight.
    pub fn isRocketBoosting(self: ElytraFlightState) bool {
        return self.is_gliding and self.rocket_boost_timer > 0.0;
    }

    /// Attempts to deploy Elytra flight based on environmental conditions.
    pub fn deploy(self: *ElytraFlightState, on_ground: bool, in_water: bool, levitating: bool) bool {
        if (canDeployElytra(on_ground, in_water, levitating, self.durability)) {
            self.is_gliding = true;
            return true;
        }
        return false;
    }

    /// Stops gliding and cancels any active rocket propulsion.
    pub fn stopGliding(self: *ElytraFlightState) void {
        self.is_gliding = false;
        self.rocket_boost_timer = 0.0;
        self.glide_time_accum = 0.0;
    }

    /// Ignites a Firework Rocket boost for the specified duration if gliding and wings are intact.
    pub fn boostWithRocket(self: *ElytraFlightState, duration: f32) bool {
        if (self.is_gliding and self.canFly()) {
            self.rocket_boost_timer = duration;
            return true;
        }
        return false;
    }

    /// Repairs durability using Phantom Membranes (+108 per membrane, capped at 432).
    pub fn repairPhantomMembrane(self: *ElytraFlightState, membrane_count: u16) u16 {
        self.durability = @import("elytra_aerodynamics.zig").repairWithPhantomMembrane(self.durability, membrane_count);
        return self.durability;
    }

    /// Consumes durability, clamping at minimum 1 (tattered).
    /// If durability drops to 1, gliding immediately ceases!
    pub fn consumeDurability(self: *ElytraFlightState, amount: u16) void {
        if (self.durability <= tattered_durability) {
            self.durability = tattered_durability;
            self.is_gliding = false;
            self.rocket_boost_timer = 0.0;
            return;
        }

        if (self.durability - tattered_durability <= amount) {
            self.durability = tattered_durability;
            self.is_gliding = false;
            self.rocket_boost_timer = 0.0;
        } else {
            self.durability -= amount;
        }
    }

    /// Advances flight timers and consumes 1 durability point every 1.0 second of gliding.
    pub fn tick(self: *ElytraFlightState, dt: f32) void {
        if (self.rocket_boost_timer > 0.0) {
            self.rocket_boost_timer = @max(0.0, self.rocket_boost_timer - dt);
        }

        if (self.is_gliding) {
            if (self.isTattered()) {
                self.is_gliding = false;
                self.rocket_boost_timer = 0.0;
                return;
            }

            self.glide_time_accum += dt;
            while (self.glide_time_accum >= 1.0) {
                self.glide_time_accum -= 1.0;
                self.consumeDurability(1);
                if (self.isTattered()) {
                    break;
                }
            }
        } else {
            self.glide_time_accum = 0.0;
        }
    }
};

// ============================================================================
// Core Flight Validation & Repair
// ============================================================================

/// Determines if Elytra can be deployed.
/// Deploys only in mid-air when durability > 1, not on ground, not in water, and not levitating.
pub fn canDeployElytra(on_ground: bool, in_water: bool, levitating: bool, durability: u16) bool {
    if (on_ground) return false;
    if (in_water) return false;
    if (levitating) return false;
    if (durability <= tattered_durability) return false;
    return true;
}

/// Evaluates if gliding flight can be initiated (extended kinematics version).
pub fn canInitiateGlide(
    is_equipped: bool,
    is_broken: bool,
    durability: u16,
    fall_distance: f32,
    is_on_ground: bool,
    jump_pressed: bool,
) bool {
    if (is_on_ground) return false;
    if (!is_equipped) return false;
    if (is_broken) return false;
    if (durability <= broken_durability) return false;
    if (fall_distance <= 0.0) return false;
    if (!jump_pressed) return false;
    return true;
}

/// Computes repaired durability using Phantom Membranes (+108 per membrane, 25% of 432 max).
/// Clamps at max_durability (432).
pub fn repairWithPhantomMembrane(current_durability: u16, membrane_count: u16) u16 {
    const total_repair = @as(u32, membrane_count) * @as(u32, membrane_repair_amount);
    const new_durability = @as(u32, current_durability) + total_repair;
    return @intCast(@min(@as(u32, max_durability), new_durability));
}

/// Detailed outcome of an Anvil repair operation using Phantom Membranes.
pub const AnvilRepairResult = struct {
    initial_durability: u16,
    repaired_durability: u16,
    durability_restored: u16,
    membranes_used: u16,
    is_broken: bool,
    xp_level_cost: u32,
};

/// Computes Anvil repair outcome when repairing an Elytra with Phantom Membranes.
pub fn calculateAnvilRepair(current_durability: u16, membranes_offered: u16) AnvilRepairResult {
    if (membranes_offered == 0 or current_durability >= max_durability) {
        return .{
            .initial_durability = current_durability,
            .repaired_durability = current_durability,
            .durability_restored = 0,
            .membranes_used = 0,
            .is_broken = current_durability <= broken_durability,
            .xp_level_cost = 0,
        };
    }

    const missing = max_durability - current_durability;
    const needed = (missing + membrane_repair_amount - 1) / membrane_repair_amount;
    const used = @min(membranes_offered, needed);
    const restored = @min(missing, used * membrane_repair_amount);
    const new_dur = current_durability + restored;

    return .{
        .initial_durability = current_durability,
        .repaired_durability = new_dur,
        .durability_restored = restored,
        .membranes_used = used,
        .is_broken = new_dur <= broken_durability,
        .xp_level_cost = @as(u32, used),
    };
}

/// Returns the boost duration in game ticks for a specified flight duration tier (1..3).
pub fn computeRocketBoostDurationTicks(tier: u8) u32 {
    return switch (tier) {
        0 => 0,
        1 => tier1_duration_ticks,
        2 => tier2_duration_ticks,
        else => tier3_duration_ticks,
    };
}

/// Computes blast damage dealt by a firework rocket at the end of its flight boost.
pub fn computeRocketBlastDamage(has_firework_star: bool) f32 {
    if (has_firework_star) {
        return firework_star_blast_damage;
    }
    return 0.0;
}

// ============================================================================
// 3D Vector Math & Aerodynamics Controller
// ============================================================================

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub const zero: Vec3 = .{ .x = 0.0, .y = 0.0, .z = 0.0 };

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn lengthSq(v: Vec3) f32 {
        return v.x * v.x + v.y * v.y + v.z * v.z;
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(v.lengthSq());
    }

    pub fn horizontalLength(v: Vec3) f32 {
        return @sqrt(v.x * v.x + v.z * v.z);
    }

    pub fn normalize(v: Vec3) Vec3 {
        const len = v.length();
        if (len <= 0.00001) return zero;
        return v.scale(1.0 / len);
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn toArray(v: Vec3) [3]f32 {
        return [3]f32{ v.x, v.y, v.z };
    }

    pub fn fromArray(arr: [3]f32) Vec3 {
        return .{ .x = arr[0], .y = arr[1], .z = arr[2] };
    }
};

/// Computes the unit 3D look vector from pitch (degrees) and yaw (radians) as [3]f32.
pub fn computeLookVector(pitch_deg: f32, yaw_rad: f32) [3]f32 {
    const pitch_rad = std.math.degreesToRadians(pitch_deg);
    const cos_p = @cos(pitch_rad);
    const sin_p = @sin(pitch_rad);
    const cos_y = @cos(yaw_rad);
    const sin_y = @sin(yaw_rad);
    return [3]f32{
        cos_y * cos_p,
        sin_p,
        sin_y * cos_p,
    };
}

/// Computes the unit 3D look vector as Vec3.
pub fn computeLookVec3(pitch_deg: f32, yaw_rad: f32) Vec3 {
    const clamped_pitch = std.math.clamp(pitch_deg, -90.0, 90.0);
    const pitch_rad = clamped_pitch * (std.math.pi / 180.0);
    const cos_p = @cos(pitch_rad);
    const sin_p = @sin(pitch_rad);
    const cos_y = @cos(yaw_rad);
    const sin_y = @sin(yaw_rad);

    return Vec3.init(
        cos_y * cos_p,
        sin_p,
        sin_y * cos_p,
    );
}

/// Computes raw per-tick aerodynamic force deltas from pitch angle theta:
/// - Dive (theta < 0): v_horiz += -0.08 * @sin(theta_rad) (accelerates horizontal velocity)
/// - Climb (theta > 0): vy += 0.06 * @sin(theta_rad) - gravity (converts into vertical lift)
pub fn computeRawPitchForces(theta_deg: f32, gravity: f32) struct { delta_v_horiz: f32, delta_vy: f32 } {
    const clamped_pitch = std.math.clamp(theta_deg, -90.0, 90.0);
    const theta_rad = clamped_pitch * (std.math.pi / 180.0);
    const sin_theta = @sin(theta_rad);

    return .{
        .delta_v_horiz = -dive_thrust_coefficient * sin_theta,
        .delta_vy = pitch_lift_coefficient * sin_theta - gravity,
    };
}

/// Evaluates one tick of 2D pitch aerodynamics and drag decay.
pub fn computePitchAerodynamics(v_horiz: f32, vy: f32, theta_deg: f32, gravity: f32) struct { v_horiz: f32, vy: f32 } {
    const forces = computeRawPitchForces(theta_deg, gravity);

    var new_vh = v_horiz + forces.delta_v_horiz;
    if (new_vh < 0.0) new_vh = 0.0;

    var new_vy = vy + forces.delta_vy;

    // Drag decay: drag coefficient 0.99 per tick
    new_vh *= drag_coefficient;
    new_vy *= drag_coefficient;

    return .{
        .v_horiz = new_vh,
        .vy = new_vy,
    };
}

/// Steps Elytra aerodynamics over delta time `dt`:
/// - Diving (`pitch_deg < 0`) converts gravitational potential energy into high horizontal airspeed (`up to 67.0 m/s`).
/// - Pulling up (`pitch_deg > 0`) converts horizontal airspeed into vertical lift (`vel[1] > 0`).
/// - Active Firework Rocket boost overrides velocity toward look vector at `33.5` m/s!
pub fn stepElytraAerodynamics(vel: [3]f32, pitch_deg: f32, yaw_rad: f32, rocket_boosting: bool, dt: f32) [3]f32 {
    if (dt <= 0.0) return vel;

    const look = computeLookVector(pitch_deg, yaw_rad);

    // Active Firework Rocket boost overrides velocity toward look vector at 33.5 m/s!
    if (rocket_boosting) {
        return [3]f32{
            look[0] * rocket_boost_speed,
            look[1] * rocket_boost_speed,
            look[2] * rocket_boost_speed,
        };
    }

    const current_h_speed = @sqrt(vel[0] * vel[0] + vel[2] * vel[2]);
    const current_vy = vel[1];

    const pitch_rad = std.math.degreesToRadians(pitch_deg);
    const cos_p = @cos(pitch_rad);
    const sin_p = @sin(pitch_rad);

    var new_h_speed = current_h_speed;
    var new_vy = current_vy;

    if (pitch_deg < 0.0) {
        // Diving: converts gravitational potential energy into high horizontal airspeed (up to 67.0 m/s)
        const dive_ratio = -sin_p; // positive ratio: 0.0 at level to 1.0 at -90 deg
        const dive_accel = 30.0 * dive_ratio * @max(0.1, cos_p);

        // Potential energy conversion from downward vertical velocity
        const vy_conversion = @max(0.0, -current_vy) * dive_ratio * dt * 2.0;
        new_h_speed = @min(max_horizontal_speed, current_h_speed + (dive_accel * dt) + vy_conversion);

        // Downward vertical trajectory during dive
        const target_vy = -new_h_speed * (dive_ratio / @max(0.3, cos_p));
        const clamped_target_vy = @max(-max_horizontal_speed, target_vy);
        new_vy = current_vy + (clamped_target_vy - current_vy) * @min(1.0, 6.0 * dt);
        new_vy -= glide_gravity * dt * dive_ratio;
    } else if (pitch_deg > 0.0) {
        // Pulling up: converts horizontal airspeed into vertical lift (vel[1] > 0)
        if (current_h_speed > 0.5) {
            const climb_ratio = sin_p; // positive ratio: 0.0 to 1.0
            const lift_target_vy = current_h_speed * climb_ratio;

            // Generate upward vertical lift from horizontal airspeed
            const lift_impulse = @max(1.0, lift_target_vy * 0.7);
            new_vy = @max(lift_impulse, current_vy + (lift_target_vy - current_vy) * @min(1.0, 8.0 * dt));
            new_vy -= glide_gravity * dt * (1.0 - climb_ratio);

            // Kinetic energy trade: horizontal speed is consumed to generate vertical lift
            const speed_consumed = (lift_target_vy * climb_ratio * 1.8 + 2.0) * dt;
            new_h_speed = @max(0.0, current_h_speed - speed_consumed);
        } else {
            // Insufficient airspeed: player stalls and falls under gravity
            new_vy = current_vy - glide_gravity * dt;
            new_h_speed = @max(0.0, current_h_speed - 2.0 * dt);
        }
    } else {
        // Level flight (pitch_deg == 0.0)
        new_vy = current_vy + (level_sink_speed - current_vy) * @min(1.0, 3.0 * dt);
        new_h_speed = current_h_speed * (1.0 - horizontal_drag_coeff * dt);
    }

    // Look heading unit vector in horizontal plane
    const look_h_x = @cos(yaw_rad);
    const look_h_z = @sin(yaw_rad);

    // Steer horizontal velocity smoothly toward look heading
    const steer_rate = @min(1.0, 8.0 * dt);
    const dir_x = if (current_h_speed > 0.001) (vel[0] / current_h_speed) else look_h_x;
    const dir_z = if (current_h_speed > 0.001) (vel[2] / current_h_speed) else look_h_z;
    const final_dir_x = dir_x + (look_h_x - dir_x) * steer_rate;
    const final_dir_z = dir_z + (look_h_z - dir_z) * steer_rate;
    const final_dir_len = @sqrt(final_dir_x * final_dir_x + final_dir_z * final_dir_z);
    const norm_x = if (final_dir_len > 0.001) final_dir_x / final_dir_len else look_h_x;
    const norm_z = if (final_dir_len > 0.001) final_dir_z / final_dir_len else look_h_z;

    return [3]f32{
        norm_x * new_h_speed,
        new_vy,
        norm_z * new_h_speed,
    };
}

/// Kinematic flight states for extended controller simulation.
pub const KinematicFlightState = enum {
    grounded,
    falling,
    gliding,
    kinetic_impact,

    pub fn isGliding(self: KinematicFlightState) bool {
        return self == .gliding;
    }

    pub fn isAirborne(self: KinematicFlightState) bool {
        return self == .falling or self == .gliding;
    }

    pub fn name(self: KinematicFlightState) []const u8 {
        return switch (self) {
            .grounded => "grounded",
            .falling => "falling",
            .gliding => "gliding",
            .kinetic_impact => "kinetic_impact",
        };
    }
};

/// Player input per tick driving the flight state machine and aerodynamics.
pub const FlightInput = struct {
    pitch_deg: f32 = 0.0,
    yaw_rad: f32 = 0.0,
    jump_pressed: bool = false,
    is_on_ground: bool = false,
};

/// Full kinematic controller simulating Elytra flight, rocket propulsion,
/// kinetic wall collisions, durability wear, and anvil repair.
pub const ElytraGlider = struct {
    state: KinematicFlightState = .grounded,
    durability: u16 = max_durability,
    is_broken: bool = false,
    is_equipped: bool = true,
    fall_distance: f32 = 0.0,
    v_horiz: f32 = 0.0,
    vy: f32 = 0.0,
    velocity: Vec3 = Vec3.zero,
    gravity: f32 = default_gravity,
    firework_rockets: u32 = 16,
    boost_ticks_remaining: u32 = 0,
    active_boost_tier: u8 = 0,
    has_active_firework_star: bool = false,
    durability_tick_counter: u32 = 0,
    player_health: f32 = 20.0,
    last_blast_damage: f32 = 0.0,
    last_kinetic_damage: f32 = 0.0,

    pub fn init() ElytraGlider {
        return .{};
    }

    pub fn initWithDurability(dur: u16) ElytraGlider {
        const d = @min(dur, max_durability);
        return .{
            .durability = d,
            .is_broken = (d <= broken_durability),
        };
    }

    pub fn canFly(self: ElytraGlider) bool {
        return self.is_equipped and !self.is_broken and self.durability > broken_durability;
    }

    pub fn isGliding(self: ElytraGlider) bool {
        return self.state == .gliding;
    }

    pub fn isRocketBoosting(self: ElytraGlider) bool {
        return self.state == .gliding and self.boost_ticks_remaining > 0;
    }

    pub fn tryActivateGliding(self: *ElytraGlider, jump_pressed: bool, is_on_ground: bool) bool {
        if (!canInitiateGlide(self.is_equipped, self.is_broken, self.durability, self.fall_distance, is_on_ground, jump_pressed)) {
            return false;
        }

        self.state = .gliding;
        self.fall_distance = 0.0;
        return true;
    }

    pub fn boostWithRocket(self: *ElytraGlider, duration_tier: u8) bool {
        return self.boostWithRocketConfig(duration_tier, false);
    }

    pub fn boostWithExplosiveRocket(self: *ElytraGlider, duration_tier: u8) bool {
        return self.boostWithRocketConfig(duration_tier, true);
    }

    pub fn boostWithRocketItem(self: *ElytraGlider, rocket: FireworkRocketProps) bool {
        return self.boostWithRocketConfig(rocket.duration_tier, rocket.has_firework_star);
    }

    pub fn boostWithRocketConfig(self: *ElytraGlider, duration_tier: u8, has_firework_star: bool) bool {
        if (!self.isGliding() or !self.canFly()) {
            return false;
        }

        if (self.firework_rockets == 0) {
            return false;
        }

        self.firework_rockets -= 1;
        const tier = std.math.clamp(duration_tier, 1, 3);
        self.active_boost_tier = tier;
        self.boost_ticks_remaining = computeRocketBoostDurationTicks(tier);
        self.has_active_firework_star = has_firework_star;
        return true;
    }

    pub fn onCollideSolidBlock(self: *ElytraGlider, impact_speed: f32) f32 {
        const damage = computeKineticCrashDamage(impact_speed);
        if (damage > 0.0) {
            self.player_health = @max(0.0, self.player_health - damage);
            self.last_kinetic_damage = damage;
            self.v_horiz = 0.0;
            self.vy = 0.0;
            self.velocity = Vec3.zero;
            self.state = .kinetic_impact;
            self.boost_ticks_remaining = 0;
            self.has_active_firework_star = false;
            return damage;
        }

        self.last_kinetic_damage = 0.0;
        return 0.0;
    }

    pub fn repairWithPhantomMembrane(self: *ElytraGlider, membrane_count: u16) u16 {
        self.durability = @import("elytra_aerodynamics.zig").repairWithPhantomMembrane(self.durability, membrane_count);
        if (self.durability > broken_durability) {
            self.is_broken = false;
        }
        return self.durability;
    }

    pub fn repairInAnvil(self: *ElytraGlider, membranes_offered: u16) AnvilRepairResult {
        const result = calculateAnvilRepair(self.durability, membranes_offered);
        self.durability = result.repaired_durability;
        self.is_broken = result.is_broken;
        return result;
    }

    pub fn consumeDurability(self: *ElytraGlider, amount: u16) void {
        if (self.durability <= broken_durability) {
            self.durability = broken_durability;
            self.is_broken = true;
            self.state = .falling;
            self.boost_ticks_remaining = 0;
            self.has_active_firework_star = false;
            return;
        }

        if (self.durability - broken_durability <= amount) {
            self.durability = broken_durability;
            self.is_broken = true;
            self.state = .falling;
            self.boost_ticks_remaining = 0;
            self.has_active_firework_star = false;
        } else {
            self.durability -= amount;
        }
    }

    pub fn tick(self: *ElytraGlider, input: FlightInput) void {
        if (input.is_on_ground) {
            self.state = .grounded;
            self.fall_distance = 0.0;
            self.boost_ticks_remaining = 0;
            self.has_active_firework_star = false;
            self.durability_tick_counter = 0;
            self.v_horiz = 0.0;
            self.vy = 0.0;
            self.velocity = Vec3.zero;
            return;
        }

        if (self.state == .kinetic_impact) {
            self.v_horiz = 0.0;
            self.vy = 0.0;
            self.velocity = Vec3.zero;
            self.state = .falling;
            return;
        }

        if (self.state == .falling) {
            self.fall_distance += @max(0.1, -self.vy * 0.05 + 0.1);
            if (input.jump_pressed and self.canFly()) {
                _ = self.tryActivateGliding(input.jump_pressed, input.is_on_ground);
            } else {
                self.vy -= self.gravity;
                self.vy *= 0.98;
                self.velocity = Vec3.init(0.0, self.vy, 0.0);
            }
            return;
        }

        if (self.state == .gliding) {
            if (self.is_broken or self.durability <= broken_durability) {
                self.is_broken = true;
                self.state = .falling;
                self.boost_ticks_remaining = 0;
                self.has_active_firework_star = false;
                return;
            }

            self.durability_tick_counter += 1;
            if (self.durability_tick_counter >= ticks_per_second) {
                self.durability_tick_counter = 0;
                self.consumeDurability(1);
                if (self.is_broken) {
                    return;
                }
            }

            if (self.boost_ticks_remaining > 0) {
                const look = computeLookVec3(input.pitch_deg, input.yaw_rad);
                self.velocity.x += look.x * rocket_acceleration;
                self.velocity.y += look.y * rocket_acceleration;
                self.velocity.z += look.z * rocket_acceleration;

                const clamped_pitch = std.math.clamp(input.pitch_deg, -90.0, 90.0);
                const pitch_rad = clamped_pitch * (std.math.pi / 180.0);
                self.v_horiz += @cos(pitch_rad) * rocket_acceleration;
                self.vy += @sin(pitch_rad) * rocket_acceleration;

                self.boost_ticks_remaining -= 1;
                if (self.boost_ticks_remaining == 0) {
                    if (self.has_active_firework_star) {
                        self.has_active_firework_star = false;
                        self.player_health = @max(0.0, self.player_health - firework_star_blast_damage);
                        self.last_blast_damage = firework_star_blast_damage;
                    }
                }
            }

            const clamped_pitch = std.math.clamp(input.pitch_deg, -90.0, 90.0);
            const theta_rad = clamped_pitch * (std.math.pi / 180.0);
            const sin_theta = @sin(theta_rad);

            self.v_horiz += -dive_thrust_coefficient * sin_theta;
            if (self.v_horiz < 0.0) self.v_horiz = 0.0;

            self.vy += pitch_lift_coefficient * sin_theta - self.gravity;

            self.v_horiz *= drag_coefficient;
            self.vy *= drag_coefficient;

            const cos_y = @cos(input.yaw_rad);
            const sin_y = @sin(input.yaw_rad);
            self.velocity.x = self.v_horiz * cos_y;
            self.velocity.y = self.vy;
            self.velocity.z = self.v_horiz * sin_y;
        }
    }
};

pub const ElytraRocketPropulsion = ElytraGlider;
pub const ElytraKinematics = ElytraGlider;
pub const ElytraFlightController = ElytraGlider;

// ============================================================================

// Unit Tests (elytra_aerodynamics)
// ============================================================================
test "constants match Minecraft Java specification" {
    try std.testing.expectEqual(@as(u16, 432), max_durability);
    try std.testing.expectEqual(@as(u16, 1), tattered_durability);
    try std.testing.expectEqual(@as(u16, 108), membrane_repair_amount);
    try std.testing.expectEqual(@as(u8, 25), membrane_repair_percent);
    try std.testing.expectApproxEqAbs(max_horizontal_speed, 67.0, 0.001);
    try std.testing.expectApproxEqAbs(rocket_boost_speed, 33.5, 0.001);
    try std.testing.expectApproxEqAbs(kinetic_damage_threshold, 12.0, 0.001);
    try std.testing.expectApproxEqAbs(kinetic_damage_multiplier, 1.2, 0.001);
}

test "canDeployElytra allows deployment in mid-air with intact durability" {
    try std.testing.expect(canDeployElytra(false, false, false, 432));
    try std.testing.expect(canDeployElytra(false, false, false, 100));
    try std.testing.expect(canDeployElytra(false, false, false, 2));
}

test "canDeployElytra fails when player is on ground" {
    try std.testing.expect(!canDeployElytra(true, false, false, 432));
    try std.testing.expect(!canDeployElytra(true, false, false, 200));
}

test "canDeployElytra fails when player is submerged in water" {
    try std.testing.expect(!canDeployElytra(false, true, false, 432));
    try std.testing.expect(!canDeployElytra(false, true, false, 50));
}

test "canDeployElytra fails when player has levitation effect" {
    try std.testing.expect(!canDeployElytra(false, false, true, 432));
    try std.testing.expect(!canDeployElytra(false, false, true, 300));
}

test "canDeployElytra fails when durability is 1 (tattered wing condition)" {
    try std.testing.expect(!canDeployElytra(false, false, false, 1));
}

test "canDeployElytra fails when durability is 0" {
    try std.testing.expect(!canDeployElytra(false, false, false, 0));
}

test "ElytraFlightState default initialization" {
    const state = ElytraFlightState.init();
    try std.testing.expect(!state.is_gliding);
    try std.testing.expectEqual(@as(u16, 432), state.durability);
    try std.testing.expectApproxEqAbs(state.rocket_boost_timer, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(state.glide_time_accum, 0.0, 0.001);
    try std.testing.expect(state.canFly());
    try std.testing.expect(!state.isTattered());
}

test "ElytraFlightState deploy and stopGliding lifecycle" {
    var state = ElytraFlightState.init();
    try std.testing.expect(state.deploy(false, false, false));
    try std.testing.expect(state.is_gliding);

    state.stopGliding();
    try std.testing.expect(!state.is_gliding);
    try std.testing.expectApproxEqAbs(state.rocket_boost_timer, 0.0, 0.001);
}

test "tattered wing: durability consumption clamps at 1 and stops flight" {
    var state = ElytraFlightState.initWithDurability(5);
    try std.testing.expect(state.deploy(false, false, false));
    try std.testing.expect(state.is_gliding);

    // Consume 3: durability becomes 2, still gliding
    state.consumeDurability(3);
    try std.testing.expectEqual(@as(u16, 2), state.durability);
    try std.testing.expect(state.is_gliding);

    // Consume 10: clamps at 1 (tattered!), flight stops immediately, never 0
    state.consumeDurability(10);
    try std.testing.expectEqual(@as(u16, 1), state.durability);
    try std.testing.expect(!state.is_gliding);
    try std.testing.expect(state.isTattered());
    try std.testing.expect(!state.canFly());

    // Further consumption remains clamped at 1
    state.consumeDurability(5);
    try std.testing.expectEqual(@as(u16, 1), state.durability);
}

test "tattered wing: flight tick accumulation stops at durability 1" {
    var state = ElytraFlightState.initWithDurability(3);
    try std.testing.expect(state.deploy(false, false, false));

    // Tick 1.0s: drops from 3 to 2
    state.tick(1.0);
    try std.testing.expectEqual(@as(u16, 2), state.durability);
    try std.testing.expect(state.is_gliding);

    // Tick 1.0s: drops from 2 to 1 (tattered!), flight canceled
    state.tick(1.0);
    try std.testing.expectEqual(@as(u16, 1), state.durability);
    try std.testing.expect(!state.is_gliding);

    // Tick 2.0s further: durability does NOT drop to 0, stays at 1
    state.tick(2.0);
    try std.testing.expectEqual(@as(u16, 1), state.durability);
    try std.testing.expect(!state.is_gliding);
}

test "tattered wing: cannot deploy or boost with rocket when tattered" {
    var state = ElytraFlightState.initWithDurability(1);
    try std.testing.expect(!state.deploy(false, false, false));
    try std.testing.expect(!state.is_gliding);
    try std.testing.expect(!state.boostWithRocket(1.5));
    try std.testing.expectApproxEqAbs(state.rocket_boost_timer, 0.0, 0.001);
}

test "phantom membrane repair: single membrane adds +108 durability" {
    var state = ElytraFlightState.initWithDurability(1); // tattered wing
    const repaired = state.repairPhantomMembrane(1);
    try std.testing.expectEqual(@as(u16, 109), repaired);
    try std.testing.expectEqual(@as(u16, 109), state.durability);
    try std.testing.expect(state.canFly());
    try std.testing.expect(!state.isTattered());

    // Now it can deploy again!
    try std.testing.expect(state.deploy(false, false, false));
    try std.testing.expect(state.is_gliding);
}

test "phantom membrane repair: standalone function caps at 432 max" {
    try std.testing.expectEqual(@as(u16, 109), repairWithPhantomMembrane(1, 1));
    try std.testing.expectEqual(@as(u16, 217), repairWithPhantomMembrane(1, 2));
    try std.testing.expectEqual(@as(u16, 325), repairWithPhantomMembrane(1, 3));
    try std.testing.expectEqual(@as(u16, 432), repairWithPhantomMembrane(1, 4));
    try std.testing.expectEqual(@as(u16, 432), repairWithPhantomMembrane(400, 1));
    try std.testing.expectEqual(@as(u16, 432), repairWithPhantomMembrane(432, 2));
}

test "computeLookVector calculations" {
    // Level flight facing +X (yaw = 0, pitch = 0)
    const forward_x = computeLookVector(0.0, 0.0);
    try std.testing.expectApproxEqAbs(forward_x[0], 1.0, 0.001);
    try std.testing.expectApproxEqAbs(forward_x[1], 0.0, 0.001);
    try std.testing.expectApproxEqAbs(forward_x[2], 0.0, 0.001);

    // Looking straight up (pitch = +90)
    const up = computeLookVector(90.0, 0.0);
    try std.testing.expectApproxEqAbs(up[0], 0.0, 0.001);
    try std.testing.expectApproxEqAbs(up[1], 1.0, 0.001);
    try std.testing.expectApproxEqAbs(up[2], 0.0, 0.001);

    // Looking straight down (pitch = -90)
    const down = computeLookVector(-90.0, 0.0);
    try std.testing.expectApproxEqAbs(down[0], 0.0, 0.001);
    try std.testing.expectApproxEqAbs(down[1], -1.0, 0.001);
    try std.testing.expectApproxEqAbs(down[2], 0.0, 0.001);
}

test "stepElytraAerodynamics: diving (pitch_deg < 0) accelerates horizontal airspeed" {
    const initial_vel = [3]f32{ 15.0, 0.0, 0.0 };
    const dive_vel = stepElytraAerodynamics(initial_vel, -35.0, 0.0, false, 0.1);

    const initial_h_speed = @sqrt(initial_vel[0] * initial_vel[0] + initial_vel[2] * initial_vel[2]);
    const dive_h_speed = @sqrt(dive_vel[0] * dive_vel[0] + dive_vel[2] * dive_vel[2]);

    try std.testing.expect(dive_h_speed > initial_h_speed);
    try std.testing.expect(dive_vel[1] < 0.0); // descending in dive
}

test "stepElytraAerodynamics: sustained diving caps horizontal airspeed at 67.0 m/s" {
    var vel = [3]f32{ 10.0, -1.0, 0.0 };
    const dt: f32 = 0.05;

    // Simulate 10 seconds of steep diving (-50 degrees)
    var step: usize = 0;
    while (step < 200) : (step += 1) {
        vel = stepElytraAerodynamics(vel, -50.0, 0.0, false, dt);
    }

    const final_h_speed = @sqrt(vel[0] * vel[0] + vel[2] * vel[2]);
    try std.testing.expectApproxEqAbs(final_h_speed, 67.0, 0.01);
    try std.testing.expect(final_h_speed <= 67.0);
}

test "stepElytraAerodynamics: pulling up (pitch_deg > 0) converts horizontal airspeed into vertical lift (vel[1] > 0)" {
    // Coming out of a high speed dive into a pull up
    const fast_glide = [3]f32{ 40.0, -2.0, 0.0 };
    const climb_vel = stepElytraAerodynamics(fast_glide, 35.0, 0.0, false, 0.05);

    // Must generate vertical lift (vel[1] > 0)
    try std.testing.expect(climb_vel[1] > 0.0);

    // Horizontal speed must decrease as kinetic energy is converted into vertical lift
    const initial_h_speed = @sqrt(fast_glide[0] * fast_glide[0] + fast_glide[2] * fast_glide[2]);
    const climb_h_speed = @sqrt(climb_vel[0] * climb_vel[0] + climb_vel[2] * climb_vel[2]);
    try std.testing.expect(climb_h_speed < initial_h_speed);
}

test "stepElytraAerodynamics: pulling up with zero airspeed cannot generate vertical lift" {
    const stationary = [3]f32{ 0.0, 0.0, 0.0 };
    const result = stepElytraAerodynamics(stationary, 45.0, 0.0, false, 0.05);

    // No airspeed to generate lift -> stalls and falls under gravity
    try std.testing.expect(result[1] < 0.0);
    const result_h_speed = @sqrt(result[0] * result[0] + result[2] * result[2]);
    try std.testing.expectApproxEqAbs(result_h_speed, 0.0, 0.001);
}

test "stepElytraAerodynamics: active firework rocket boost overrides velocity toward look vector at 33.5 m/s" {
    // Initially falling downwards slowly
    const falling_vel = [3]f32{ 5.0, -10.0, 2.0 };

    // Firework rocket boost looking slightly up and forward along +X
    const boost_vel = stepElytraAerodynamics(falling_vel, 20.0, 0.0, true, 0.05);

    const total_speed = @sqrt(boost_vel[0] * boost_vel[0] + boost_vel[1] * boost_vel[1] + boost_vel[2] * boost_vel[2]);
    try std.testing.expectApproxEqAbs(total_speed, 33.5, 0.001);

    // Look vector check: pitch = 20 deg, yaw = 0 rad
    const look = computeLookVector(20.0, 0.0);
    try std.testing.expectApproxEqAbs(boost_vel[0], look[0] * 33.5, 0.001);
    try std.testing.expectApproxEqAbs(boost_vel[1], look[1] * 33.5, 0.001);
    try std.testing.expectApproxEqAbs(boost_vel[2], look[2] * 33.5, 0.001);
}

test "stepElytraAerodynamics: rocket boost pointing in arbitrary directions" {
    // Looking straight up
    const up_boost = stepElytraAerodynamics([3]f32{ 0, 0, 0 }, 90.0, 0.0, true, 0.05);
    try std.testing.expectApproxEqAbs(up_boost[0], 0.0, 0.001);
    try std.testing.expectApproxEqAbs(up_boost[1], 33.5, 0.001);
    try std.testing.expectApproxEqAbs(up_boost[2], 0.0, 0.001);

    // Looking along +Z (yaw = pi/2, pitch = 0)
    const z_boost = stepElytraAerodynamics([3]f32{ 0, 0, 0 }, 0.0, std.math.pi * 0.5, true, 0.05);
    try std.testing.expectApproxEqAbs(z_boost[0], 0.0, 0.001);
    try std.testing.expectApproxEqAbs(z_boost[1], 0.0, 0.001);
    try std.testing.expectApproxEqAbs(z_boost[2], 33.5, 0.001);
}

test "computeKineticWallImpactDamage: no damage at or below 12.0 m/s threshold" {
    try std.testing.expectApproxEqAbs(computeKineticWallImpactDamage(0.0), 0.0, 0.001);
    try std.testing.expectApproxEqAbs(computeKineticWallImpactDamage(5.0), 0.0, 0.001);
    try std.testing.expectApproxEqAbs(computeKineticWallImpactDamage(11.99), 0.0, 0.001);
    try std.testing.expectApproxEqAbs(computeKineticWallImpactDamage(12.0), 0.0, 0.001);
}

test "computeKineticWallImpactDamage: inflicts damage scaled by (horizontal_speed - 12.0) * 1.2" {
    // At 14.0 m/s: (14 - 12) * 1.2 = 2.4
    try std.testing.expectApproxEqAbs(computeKineticWallImpactDamage(14.0), 2.4, 0.001);

    // At 22.0 m/s: (22 - 12) * 1.2 = 12.0
    try std.testing.expectApproxEqAbs(computeKineticWallImpactDamage(22.0), 12.0, 0.001);

    // At Firework Rocket boost speed 33.5 m/s: (33.5 - 12) * 1.2 = 25.8
    try std.testing.expectApproxEqAbs(computeKineticWallImpactDamage(33.5), 25.8, 0.001);

    // At max dive airspeed 67.0 m/s: (67.0 - 12) * 1.2 = 66.0
    try std.testing.expectApproxEqAbs(computeKineticWallImpactDamage(67.0), 66.0, 0.001);
}

test "computeKineticWallImpactDamageFromVel helper with 3D velocity" {
    // Collision while traveling along X and Z at resultant horizontal speed 20.0 m/s
    // (12.0, 0.0, 16.0) -> sqrt(144 + 256) = sqrt(400) = 20.0 m/s
    const vel = [3]f32{ 12.0, -5.0, 16.0 };
    const damage = computeKineticWallImpactDamageFromVel(vel);
    // (20.0 - 12.0) * 1.2 = 9.6
    try std.testing.expectApproxEqAbs(damage, 9.6, 0.001);
}

test "canDeployElytra boundary check at durability 2" {
    // 1 is tattered, 2 is the lowest usable durability
    try std.testing.expect(!canDeployElytra(false, false, false, 1));
    try std.testing.expect(canDeployElytra(false, false, false, 2));
}

test "ElytraFlightState tick decrements rocket_boost_timer to zero" {
    var state = ElytraFlightState.init();
    try std.testing.expect(state.deploy(false, false, false));
    try std.testing.expect(state.boostWithRocket(1.5));
    try std.testing.expect(state.isRocketBoosting());

    state.tick(0.5);
    try std.testing.expectApproxEqAbs(state.rocket_boost_timer, 1.0, 0.001);
    try std.testing.expect(state.isRocketBoosting());

    state.tick(1.0);
    try std.testing.expectApproxEqAbs(state.rocket_boost_timer, 0.0, 0.001);
    try std.testing.expect(!state.isRocketBoosting());
}

test "stepElytraAerodynamics: diving converts downward vertical velocity into forward thrust" {
    // Player has initial downward velocity (-15 m/s) and moderate forward speed (10 m/s)
    const falling_vel = [3]f32{ 10.0, -15.0, 0.0 };
    const stepped_vel = stepElytraAerodynamics(falling_vel, -45.0, 0.0, false, 0.1);

    const h_speed_after = @sqrt(stepped_vel[0] * stepped_vel[0] + stepped_vel[2] * stepped_vel[2]);
    // Forward airspeed should gain significantly from falling energy conversion
    try std.testing.expect(h_speed_after > 10.0);
}

test "stepElytraAerodynamics: level flight preserves airspeed with gentle descent sink rate" {
    const cruise_vel = [3]f32{ 25.0, 0.0, 0.0 };
    const stepped = stepElytraAerodynamics(cruise_vel, 0.0, 0.0, false, 0.05);

    // Vertical descent approaches level_sink_speed (-1.2 m/s)
    try std.testing.expect(stepped[1] < 0.0);
    try std.testing.expect(stepped[1] >= level_sink_speed - 0.5);

    // Slight horizontal drag
    const h_after = @sqrt(stepped[0] * stepped[0] + stepped[2] * stepped[2]);
    try std.testing.expect(h_after <= 25.0);
    try std.testing.expect(h_after > 24.5);
}

// Unit Tests (elytra_flight_matrix)
// ============================================================================
fn expectNear(actual: f32, expected: f32) !void {
try std.testing.expect(@abs(actual - expected) < 0.001);
}

test "base durability is 432" {
    try std.testing.expectEqual(@as(u16, 432), max_durability);
}

test "wear interval is twenty ticks" {
    try std.testing.expectEqual(@as(u32, 20), ticks_per_second);
}

test "base wear chance is 100 percent" {
    try expectNear(wearProbability(0), 1.0);
}

test "Unbreaking I wear chance is 50 percent" {
    try expectNear(wearProbability(1), 0.5);
}

test "Unbreaking II wear chance is one third" {
    try expectNear(wearProbability(2), 1.0 / 3.0);
}

test "Unbreaking III wear chance is 25 percent" {
    try expectNear(wearProbability(3), 0.25);
}

test "Unbreaking I doubles nominal flight duration" {
    try expectNear(expectedFlightSeconds(1), 864.0);
}

test "Unbreaking II triples nominal flight duration" {
    try expectNear(expectedFlightSeconds(2), 1296.0);
}

test "Unbreaking III quadruples nominal flight duration" {
    try expectNear(expectedFlightSeconds(3), 1728.0);
}

test "base nominal flight is 7.2 minutes" {
    try expectNear(expectedFlightSeconds(0) / 60.0, 7.2);
}

test "Unbreaking III nominal flight is 28.8 minutes" {
    try expectNear(expectedFlightSeconds(3) / 60.0, 28.8);
}

test "wear occurs below probability threshold" {
    try std.testing.expect(shouldConsumeWear(1, 0.49));
}

test "wear does not occur at probability threshold" {
    try std.testing.expect(!shouldConsumeWear(1, 0.5));
}

test "Unbreaking II accepts a low wear roll" {
    try std.testing.expect(shouldConsumeWear(2, 0.1));
}

test "Unbreaking II rejects a high wear roll" {
    try std.testing.expect(!shouldConsumeWear(2, 0.34));
}

test "wear rejects negative random rolls" {
    try std.testing.expect(!shouldConsumeWear(0, -0.01));
}

test "wear rejects random rolls equal to one" {
    try std.testing.expect(!shouldConsumeWear(0, 1.0));
}

test "flight starts with usable Elytra" {
    var state = DurabilityState{};
    try std.testing.expect(state.startFlight());
    try std.testing.expect(state.is_flying);
}

test "one wear roll consumes one durability" {
    var state = DurabilityState{};
    try std.testing.expect(state.startFlight());
    try std.testing.expect(state.tickFlightWear(0, 0.5));
    try std.testing.expectEqual(@as(u16, 431), state.durability);
}

test "Unbreaking can skip the wear event" {
    var state = DurabilityState{};
    try std.testing.expect(state.startFlight());
    try std.testing.expect(!state.tickFlightWear(3, 0.5));
    try std.testing.expectEqual(max_durability, state.durability);
}

test "durability one is broken" {
    const state = DurabilityState{ .durability = 1 };
    try std.testing.expect(state.isBroken());
}

test "durability one prevents starting flight" {
    var state = DurabilityState{ .durability = 1 };
    try std.testing.expect(!state.startFlight());
}

test "wear reaching one stops flight" {
    var state = DurabilityState{ .durability = 2 };
    try std.testing.expect(state.startFlight());
    try std.testing.expect(state.tickFlightWear(0, 0.0));
    try std.testing.expectEqual(@as(u16, 1), state.durability);
    try std.testing.expect(!state.is_flying);
}

test "unequipped Elytra cannot fly" {
    var state = DurabilityState{ .equipped = false };
    try std.testing.expect(!state.startFlight());
}

test "five XP points repair ten durability with Mending" {
    var state = DurabilityState{ .durability = 100, .has_mending = true };
    try std.testing.expectEqual(@as(u16, 10), state.absorbExperience(5));
    try std.testing.expectEqual(@as(u16, 110), state.durability);
}

test "Mending repair requires equipped Elytra" {
    var state = DurabilityState{ .durability = 100, .equipped = false, .has_mending = true };
    try std.testing.expectEqual(@as(u16, 0), state.absorbExperience(5));
    try std.testing.expectEqual(@as(u16, 100), state.durability);
}

test "Mending repair requires the enchantment" {
    var state = DurabilityState{ .durability = 100, .equipped = true, .has_mending = false };
    try std.testing.expectEqual(@as(u16, 0), state.absorbExperience(5));
}

test "Mending repair caps at maximum durability" {
    var state = DurabilityState{ .durability = 430, .has_mending = true };
    try std.testing.expectEqual(@as(u16, 2), state.absorbExperience(5));
    try std.testing.expectEqual(max_durability, state.durability);
}

test "zero XP does not repair durability" {
    var state = DurabilityState{ .durability = 100, .has_mending = true };
    try std.testing.expectEqual(@as(u16, 0), state.absorbExperience(0));
}

test "stall angle threshold itself does not trigger stall" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    const frame = stepAerodynamics(&state, 35.0, 0.01);
    try std.testing.expect(!frame.is_stalled);
}

test "pitch above 35 degrees at low speed stalls" {
    var state = AerodynamicState{ .airspeed_mps = 5.9 };
    const frame = stepAerodynamics(&state, 35.1, 0.01);
    try std.testing.expect(frame.is_stalled);
}

test "pitch above stall angle at six m/s does not stall" {
    var state = AerodynamicState{ .airspeed_mps = 6.0 };
    const frame = stepAerodynamics(&state, 40.0, 0.01);
    try std.testing.expect(!frame.is_stalled);
}

test "pitch below stall angle does not stall at low speed" {
    var state = AerodynamicState{ .airspeed_mps = 2.0 };
    const frame = stepAerodynamics(&state, 35.0, 0.01);
    try std.testing.expect(!frame.is_stalled);
}

test "stall reduces lift coefficient by 90 percent" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    const frame = stepAerodynamics(&state, 40.0, 0.01);
    try expectNear(frame.lift_coefficient, 0.1);
}

test "stall enters nose-down vertical tumble" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    const frame = stepAerodynamics(&state, 45.0, 0.01);
    try std.testing.expect(frame.nose_down_tumble);
    try expectNear(frame.effective_pitch_degrees, -90.0);
}

test "stall stays active below eight m/s recovery speed" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    _ = stepAerodynamics(&state, 40.0, 0.01);
    state.setAirspeed(7.99);
    const frame = stepAerodynamics(&state, 0.0, 0.0);
    try std.testing.expect(frame.is_stalled);
}

test "stall recovers at eight m/s" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    _ = stepAerodynamics(&state, 40.0, 0.01);
    state.setAirspeed(8.0);
    const frame = stepAerodynamics(&state, 0.0, 0.01);
    try std.testing.expect(!frame.is_stalled);
    try std.testing.expect(!frame.nose_down_tumble);
}

test "nose-down tumble can recover during a dive step" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    _ = stepAerodynamics(&state, 40.0, 0.01);
    const frame = stepAerodynamics(&state, 0.0, 1.0);
    try std.testing.expect(!frame.is_stalled);
    try std.testing.expect(frame.airspeed_mps >= stall_recovery_speed_mps);
}

test "a dive accelerates by gravity over one second" {
    var state = AerodynamicState{ .airspeed_mps = 0.0 };
    const frame = stepAerodynamics(&state, -90.0, 1.0);
    try expectNear(frame.airspeed_mps, 9.81);
}

test "dive speed clamps at 67.5 meters per second" {
    var state = AerodynamicState{ .airspeed_mps = 67.0 };
    const frame = stepAerodynamics(&state, -90.0, 1.0);
    try expectNear(frame.airspeed_mps, 67.5);
}

test "dive at terminal velocity remains capped" {
    var state = AerodynamicState{ .airspeed_mps = terminal_dive_speed_mps };
    const frame = stepAerodynamics(&state, -90.0, 5.0);
    try expectNear(frame.airspeed_mps, terminal_dive_speed_mps);
}

test "zero duration does not change flight speed" {
    var state = AerodynamicState{ .airspeed_mps = 12.0 };
    _ = stepAerodynamics(&state, -90.0, 0.0);
    try expectNear(state.airspeed_mps, 12.0);
}

test "negative airspeed is clamped to zero" {
    var state = AerodynamicState{};
    state.setAirspeed(-4.0);
    try expectNear(state.airspeed_mps, 0.0);
}

// Unit Tests (elytra_rocket_propulsion)
// ============================================================================
test "01: constants match Minecraft Java and milestone specification" {
    try std.testing.expectEqual(@as(u16, 432), max_durability);
    try std.testing.expectEqual(@as(u16, 1), broken_durability);
    try std.testing.expectEqual(@as(u16, 108), membrane_repair_amount);
    try std.testing.expectEqual(@as(u8, 25), membrane_repair_percent);
    try std.testing.expectEqual(@as(f32, 10.0), kinetic_crash_threshold);
    try std.testing.expectEqual(@as(f32, 2.0), kinetic_crash_multiplier);
    try std.testing.expectEqual(@as(f32, 5.0), firework_star_blast_damage);
    try std.testing.expectEqual(@as(f32, 1.5), rocket_acceleration);
    try std.testing.expectEqual(@as(f32, 0.08), dive_thrust_coefficient);
    try std.testing.expectEqual(@as(f32, 0.06), pitch_lift_coefficient);
    try std.testing.expectEqual(@as(f32, 0.99), drag_coefficient);
    try std.testing.expectEqual(@as(u32, 20), tier1_duration_ticks);
    try std.testing.expectEqual(@as(u32, 40), tier2_duration_ticks);
    try std.testing.expectEqual(@as(u32, 60), tier3_duration_ticks);
}

test "02: KinematicFlightState enum variants and helper methods" {
    const s1 = KinematicFlightState.grounded;
    const s2 = KinematicFlightState.falling;
    const s3 = KinematicFlightState.gliding;
    const s4 = KinematicFlightState.kinetic_impact;

    try std.testing.expect(!s1.isGliding());
    try std.testing.expect(!s2.isGliding());
    try std.testing.expect(s3.isGliding());
    try std.testing.expect(!s4.isGliding());

    try std.testing.expect(!s1.isAirborne());
    try std.testing.expect(s2.isAirborne());
    try std.testing.expect(s3.isAirborne());
    try std.testing.expect(!s4.isAirborne());

    try std.testing.expectEqualStrings("grounded", s1.name());
    try std.testing.expectEqualStrings("falling", s2.name());
    try std.testing.expectEqualStrings("gliding", s3.name());
    try std.testing.expectEqualStrings("kinetic_impact", s4.name());
}

test "03: gliding initiation succeeds when falling, equipped, and jump pressed" {
    const can_glide = canInitiateGlide(
        true, // is_equipped
        false, // is_broken
        432, // durability
        1.5, // fall_distance > 0.0
        false, // is_on_ground
        true, // jump_pressed
    );
    try std.testing.expect(can_glide);

    var glider = ElytraGlider.init();
    glider.state = .falling;
    glider.fall_distance = 2.0;
    const deployed = glider.tryActivateGliding(true, false);
    try std.testing.expect(deployed);
    try std.testing.expectEqual(KinematicFlightState.gliding, glider.state);
    try std.testing.expectEqual(@as(f32, 0.0), glider.fall_distance);
}

test "04: gliding initiation fails when not equipped" {
    const can_glide = canInitiateGlide(
        false, // is_equipped
        false,
        432,
        2.0,
        false,
        true,
    );
    try std.testing.expect(!can_glide);

    var glider = ElytraGlider.init();
    glider.is_equipped = false;
    glider.state = .falling;
    glider.fall_distance = 2.0;
    try std.testing.expect(!glider.tryActivateGliding(true, false));
    try std.testing.expectEqual(KinematicFlightState.falling, glider.state);
}

test "05: gliding initiation fails when on ground" {
    const can_glide = canInitiateGlide(
        true,
        false,
        432,
        2.0,
        true, // is_on_ground
        true,
    );
    try std.testing.expect(!can_glide);

    var glider = ElytraGlider.init();
    glider.state = .grounded;
    try std.testing.expect(!glider.tryActivateGliding(true, true));
    try std.testing.expectEqual(KinematicFlightState.grounded, glider.state);
}

test "06: gliding initiation fails when fall distance is zero or negative" {
    try std.testing.expect(!canInitiateGlide(true, false, 432, 0.0, false, true));
    try std.testing.expect(!canInitiateGlide(true, false, 432, -0.5, false, true));

    var glider = ElytraGlider.init();
    glider.state = .falling;
    glider.fall_distance = 0.0;
    try std.testing.expect(!glider.tryActivateGliding(true, false));
    try std.testing.expectEqual(KinematicFlightState.falling, glider.state);
}

test "07: gliding initiation fails when jump spacebar is not pressed" {
    try std.testing.expect(!canInitiateGlide(true, false, 432, 1.0, false, false));

    var glider = ElytraGlider.init();
    glider.state = .falling;
    glider.fall_distance = 1.0;
    try std.testing.expect(!glider.tryActivateGliding(false, false));
    try std.testing.expectEqual(KinematicFlightState.falling, glider.state);
}

test "08: gliding initiation fails when Elytra is broken (is_broken = true)" {
    try std.testing.expect(!canInitiateGlide(true, true, 432, 1.0, false, true));

    var glider = ElytraGlider.init();
    glider.is_broken = true;
    glider.state = .falling;
    glider.fall_distance = 1.0;
    try std.testing.expect(!glider.tryActivateGliding(true, false));
    try std.testing.expectEqual(KinematicFlightState.falling, glider.state);
}

test "09: gliding initiation fails when durability is 1 (broken elytra threshold)" {
    try std.testing.expect(!canInitiateGlide(true, false, 1, 1.0, false, true));

    var glider = ElytraGlider.initWithDurability(1);
    try std.testing.expect(glider.is_broken);
    try std.testing.expect(!glider.canFly());

    glider.state = .falling;
    glider.fall_distance = 1.0;
    try std.testing.expect(!glider.tryActivateGliding(true, false));
}

test "10: gliding initiation succeeds at minimum functional durability (durability = 2)" {
    try std.testing.expect(canInitiateGlide(true, false, 2, 1.0, false, true));

    var glider = ElytraGlider.initWithDurability(2);
    try std.testing.expect(!glider.is_broken);
    try std.testing.expect(glider.canFly());

    glider.state = .falling;
    glider.fall_distance = 1.0;
    try std.testing.expect(glider.tryActivateGliding(true, false));
    try std.testing.expectEqual(KinematicFlightState.gliding, glider.state);
}

test "11: pitch dive speed acceleration: theta < 0 converts potential energy into horizontal velocity" {
    // Formula: v_horiz += -0.08 * @sin(theta_rad)
    // At theta = -30 deg, sin(-30 deg) = -0.5 => -0.08 * (-0.5) = +0.04 m/s acceleration
    const forces = computeRawPitchForces(-30.0, 0.05);
    try std.testing.expect(forces.delta_v_horiz > 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.04), forces.delta_v_horiz, 0.001);

    // Test with controller tick
    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.v_horiz = 5.0;
    glider.vy = 0.0;

    glider.tick(.{ .pitch_deg = -30.0, .yaw_rad = 0.0, .jump_pressed = false, .is_on_ground = false });
    // Expected before drag: 5.0 + 0.04 = 5.04. After drag (0.99): 5.04 * 0.99 = 4.9896.
    // In comparison to level flight (theta = 0): 5.0 * 0.99 = 4.95.
    try std.testing.expect(glider.v_horiz > 4.95);
    try std.testing.expectApproxEqAbs(@as(f32, 4.9896), glider.v_horiz, 0.001);
}

test "12: steeper pitch dive (-60 deg vs -30 deg) produces greater horizontal thrust" {
    const dive30 = computeRawPitchForces(-30.0, 0.05);
    const dive60 = computeRawPitchForces(-60.0, 0.05);

    try std.testing.expect(dive60.delta_v_horiz > dive30.delta_v_horiz);
    // At -60 deg, sin(-60 deg) = -sqrt(3)/2 ~= -0.8660 => -0.08 * (-0.8660) = 0.06928
    try std.testing.expectApproxEqAbs(@as(f32, 0.06928), dive60.delta_v_horiz, 0.001);
}

test "13: pitch climb deceleration: theta > 0 converts horizontal velocity into vertical altitude" {
    // Formula: vy += 0.06 * @sin(theta_rad) - gravity
    // At theta = +30 deg, sin(+30 deg) = +0.5 => 0.06 * 0.5 - 0.05 = +0.03 - 0.05 = -0.02
    // Compared to level flight (-0.05), vy is increased by +0.03!
    const forces = computeRawPitchForces(30.0, 0.05);
    try std.testing.expect(forces.delta_v_horiz < 0.0); // Climb decelerates horizontal velocity
    try std.testing.expectApproxEqAbs(@as(f32, -0.04), forces.delta_v_horiz, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.02), forces.delta_vy, 0.001);

    // Steep climb at +60 deg: sin(+60 deg) = 0.8660 => 0.06 * 0.8660 - 0.05 = +0.00196 (lift overcomes gravity!)
    const climb60 = computeRawPitchForces(60.0, 0.05);
    try std.testing.expect(climb60.delta_vy > 0.0);
}

test "14: drag decay reduces airspeed over time with 0.99 coefficient" {
    const vh: f32 = 10.0;
    const vy: f32 = 0.0;

    // In level flight (theta = 0) with zero gravity
    const step1 = computePitchAerodynamics(vh, vy, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 9.9), step1.v_horiz, 0.001);

    const step2 = computePitchAerodynamics(step1.v_horiz, step1.vy, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 9.801), step2.v_horiz, 0.001);
}

test "15: firework rocket boost: tier 1 scales to 20 ticks (1.0s)" {
    try std.testing.expectEqual(@as(u32, 20), computeRocketBoostDurationTicks(1));

    var glider = ElytraGlider.init();
    glider.state = .gliding;
    try std.testing.expect(glider.boostWithRocket(1));
    try std.testing.expectEqual(@as(u32, 20), glider.boost_ticks_remaining);
    try std.testing.expectEqual(@as(u8, 1), glider.active_boost_tier);
    try std.testing.expect(glider.isRocketBoosting());
}

test "16: firework rocket boost: tier 2 scales to 40 ticks (2.0s)" {
    try std.testing.expectEqual(@as(u32, 40), computeRocketBoostDurationTicks(2));

    var glider = ElytraGlider.init();
    glider.state = .gliding;
    try std.testing.expect(glider.boostWithRocket(2));
    try std.testing.expectEqual(@as(u32, 40), glider.boost_ticks_remaining);
    try std.testing.expectEqual(@as(u8, 2), glider.active_boost_tier);
    try std.testing.expect(glider.isRocketBoosting());
}

test "17: firework rocket boost: tier 3 scales to 60 ticks (3.0s)" {
    try std.testing.expectEqual(@as(u32, 60), computeRocketBoostDurationTicks(3));

    var glider = ElytraGlider.init();
    glider.state = .gliding;
    try std.testing.expect(glider.boostWithRocket(3));
    try std.testing.expectEqual(@as(u32, 60), glider.boost_ticks_remaining);
    try std.testing.expectEqual(@as(u8, 3), glider.active_boost_tier);
    try std.testing.expect(glider.isRocketBoosting());
}

test "18: firework rocket boost consumes 1 rocket from inventory" {
    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.firework_rockets = 5;

    try std.testing.expect(glider.boostWithRocket(1));
    try std.testing.expectEqual(@as(u32, 4), glider.firework_rockets);

    try std.testing.expect(glider.boostWithRocket(2));
    try std.testing.expectEqual(@as(u32, 3), glider.firework_rockets);
}

test "19: firework rocket boost fails when rocket inventory is depleted (0 rockets)" {
    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.firework_rockets = 0;

    try std.testing.expect(!glider.boostWithRocket(1));
    try std.testing.expectEqual(@as(u32, 0), glider.boost_ticks_remaining);
    try std.testing.expect(!glider.isRocketBoosting());
}

test "20: firework rocket boost fails when not in gliding flight" {
    var glider = ElytraGlider.init();
    glider.state = .grounded;
    try std.testing.expect(!glider.boostWithRocket(1));

    glider.state = .falling;
    try std.testing.expect(!glider.boostWithRocket(1));

    glider.state = .kinetic_impact;
    try std.testing.expect(!glider.boostWithRocket(1));
}

test "21: firework rocket boost adds forward acceleration vector along look direction (1.5 m/s^2)" {
    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.v_horiz = 0.0;
    glider.vy = 0.0;
    glider.velocity = Vec3.zero;

    try std.testing.expect(glider.boostWithRocket(1));

    // Level flight forward along yaw = 0: look_vector = (1.0, 0.0, 0.0)
    glider.tick(.{ .pitch_deg = 0.0, .yaw_rad = 0.0, .jump_pressed = false, .is_on_ground = false });

    // Rocket adds 1.5 forward acceleration along look vector
    try std.testing.expect(glider.velocity.x > 1.0);
    try std.testing.expect(glider.v_horiz > 1.0);
    try std.testing.expectEqual(@as(u32, 19), glider.boost_ticks_remaining);
}

test "22: firework star explosion hazard: starless rocket deals 0.0 blast damage" {
    try std.testing.expectEqual(@as(f32, 0.0), computeRocketBlastDamage(false));

    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.player_health = 20.0;

    try std.testing.expect(glider.boostWithRocket(1)); // Tier 1 (20 ticks), starless
    try std.testing.expect(!glider.has_active_firework_star);

    // Simulate 20 ticks until rocket boost expires
    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        glider.tick(.{ .pitch_deg = 0.0, .yaw_rad = 0.0, .jump_pressed = false, .is_on_ground = false });
    }

    try std.testing.expectEqual(@as(u32, 0), glider.boost_ticks_remaining);
    try std.testing.expectEqual(@as(f32, 20.0), glider.player_health);
    try std.testing.expectEqual(@as(f32, 0.0), glider.last_blast_damage);
}

test "23: firework star explosion hazard: explosive rocket deals 5.0 HP direct blast damage" {
    try std.testing.expectEqual(@as(f32, 5.0), computeRocketBlastDamage(true));

    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.player_health = 20.0;

    try std.testing.expect(glider.boostWithExplosiveRocket(1)); // Tier 1 (20 ticks), has star!
    try std.testing.expect(glider.has_active_firework_star);

    // Simulate 20 ticks until rocket boost expires and explodes
    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        glider.tick(.{ .pitch_deg = 0.0, .yaw_rad = 0.0, .jump_pressed = false, .is_on_ground = false });
    }

    try std.testing.expectEqual(@as(u32, 0), glider.boost_ticks_remaining);
    // At expiration, player took 5.0 HP blast damage
    try std.testing.expectEqual(@as(f32, 15.0), glider.player_health);
    try std.testing.expectEqual(@as(f32, 5.0), glider.last_blast_damage);
}

test "24: kinetic crash collision: low speed (< 10.0 m/s) safe impact deals zero damage" {
    try std.testing.expectEqual(@as(f32, 0.0), computeKineticCrashDamage(0.0));
    try std.testing.expectEqual(@as(f32, 0.0), computeKineticCrashDamage(5.0));
    try std.testing.expectEqual(@as(f32, 0.0), computeKineticCrashDamage(9.9));

    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.player_health = 20.0;
    const damage = glider.onCollideSolidBlock(8.5);
    try std.testing.expectEqual(@as(f32, 0.0), damage);
    try std.testing.expectEqual(@as(f32, 20.0), glider.player_health);
}

test "25: kinetic crash collision: exact 10.0 m/s threshold deals zero damage" {
    try std.testing.expectEqual(@as(f32, 0.0), computeKineticCrashDamage(10.0));

    var glider = ElytraGlider.init();
    glider.state = .gliding;
    const damage = glider.onCollideSolidBlock(10.0);
    try std.testing.expectEqual(@as(f32, 0.0), damage);
}

test "26: kinetic crash collision: high speed impact formula damage = (v - 10.0) * 2.0" {
    // 12.0 m/s => (12 - 10) * 2.0 = 4.0 HP
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), computeKineticCrashDamage(12.0), 0.001);

    // 15.0 m/s => (15 - 10) * 2.0 = 10.0 HP
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), computeKineticCrashDamage(15.0), 0.001);

    // 20.0 m/s => (20 - 10) * 2.0 = 20.0 HP (lethal damage!)
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), computeKineticCrashDamage(20.0), 0.001);
}

test "27: kinetic crash collision resets velocity, cancels flight, and transitions to kinetic_impact" {
    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.v_horiz = 16.0;
    glider.vy = -2.0;
    glider.velocity = Vec3.init(16.0, -2.0, 0.0);
    glider.player_health = 20.0;

    const damage = glider.onCollideSolidBlock(16.0);
    // (16 - 10) * 2 = 12.0 HP damage
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), glider.player_health, 0.001);
    try std.testing.expectEqual(KinematicFlightState.kinetic_impact, glider.state);
    try std.testing.expectEqual(@as(f32, 0.0), glider.v_horiz);
    try std.testing.expectEqual(@as(f32, 0.0), glider.vy);
    try std.testing.expectEqual(@as(f32, 0.0), glider.velocity.length());
}

test "28: durability wear consumes 1 point per second (every 20 ticks) of flight" {
    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.durability = 432;

    // Simulate 19 ticks: durability unchanged
    var i: u32 = 0;
    while (i < 19) : (i += 1) {
        glider.tick(.{ .pitch_deg = 0.0, .yaw_rad = 0.0, .jump_pressed = false, .is_on_ground = false });
    }
    try std.testing.expectEqual(@as(u16, 432), glider.durability);

    // 20th tick: 1 second reached, durability decreases by 1
    glider.tick(.{ .pitch_deg = 0.0, .yaw_rad = 0.0, .jump_pressed = false, .is_on_ground = false });
    try std.testing.expectEqual(@as(u16, 431), glider.durability);

    // Another 20 ticks: decreases to 430
    i = 0;
    while (i < 20) : (i += 1) {
        glider.tick(.{ .pitch_deg = 0.0, .yaw_rad = 0.0, .jump_pressed = false, .is_on_ground = false });
    }
    try std.testing.expectEqual(@as(u16, 430), glider.durability);
}

test "29: durability wear halts flight and sets is_broken = true when durability reaches 1" {
    var glider = ElytraGlider.initWithDurability(2);
    glider.state = .gliding;
    try std.testing.expect(!glider.is_broken);

    // Simulate 20 ticks: durability drops from 2 to 1 (broken!)
    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        glider.tick(.{ .pitch_deg = 0.0, .yaw_rad = 0.0, .jump_pressed = false, .is_on_ground = false });
    }

    try std.testing.expectEqual(@as(u16, 1), glider.durability);
    try std.testing.expect(glider.is_broken);
    try std.testing.expect(!glider.isGliding());
    try std.testing.expectEqual(KinematicFlightState.falling, glider.state);
}

test "30: anvil repair: 1 phantom membrane restores +108 durability" {
    try std.testing.expectEqual(@as(u16, 109), repairWithPhantomMembrane(1, 1));
    try std.testing.expectEqual(@as(u16, 208), repairWithPhantomMembrane(100, 1));

    var glider = ElytraGlider.initWithDurability(1);
    try std.testing.expect(glider.is_broken);

    const new_dur = glider.repairWithPhantomMembrane(1);
    try std.testing.expectEqual(@as(u16, 109), new_dur);
    try std.testing.expectEqual(@as(u16, 109), glider.durability);
    try std.testing.expect(!glider.is_broken); // Restored from broken!
    try std.testing.expect(glider.canFly());
}

test "31: anvil repair: multiple phantom membranes cap at max durability 432" {
    // 4 membranes from 1 durability: 1 + 4 * 108 = 433 => capped at 432
    try std.testing.expectEqual(@as(u16, 432), repairWithPhantomMembrane(1, 4));
    try std.testing.expectEqual(@as(u16, 432), repairWithPhantomMembrane(350, 2));

    var glider = ElytraGlider.initWithDurability(400);
    _ = glider.repairWithPhantomMembrane(1);
    try std.testing.expectEqual(@as(u16, 432), glider.durability);
}

test "32: anvil repair calculation returns proper membrane consumption and xp cost" {
    // Broken elytra (1 durability): needs 4 membranes to fully restore (431 missing)
    const repair_calc = calculateAnvilRepair(1, 4);
    try std.testing.expectEqual(@as(u16, 1), repair_calc.initial_durability);
    try std.testing.expectEqual(@as(u16, 432), repair_calc.repaired_durability);
    try std.testing.expectEqual(@as(u16, 431), repair_calc.durability_restored);
    try std.testing.expectEqual(@as(u16, 4), repair_calc.membranes_used);
    try std.testing.expectEqual(@as(u32, 4), repair_calc.xp_level_cost);
    try std.testing.expect(!repair_calc.is_broken);

    // Elytra missing only 50 points: 1 membrane is sufficient
    const partial_calc = calculateAnvilRepair(382, 3);
    try std.testing.expectEqual(@as(u16, 432), partial_calc.repaired_durability);
    try std.testing.expectEqual(@as(u16, 50), partial_calc.durability_restored);
    try std.testing.expectEqual(@as(u16, 1), partial_calc.membranes_used);
    try std.testing.expectEqual(@as(u32, 1), partial_calc.xp_level_cost);
}

test "33: 3D look vector math for pitch and yaw directions" {
    // Looking straight ahead (pitch = 0, yaw = 0): look = (1.0, 0.0, 0.0)
    const forward = computeLookVec3(0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), forward.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), forward.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), forward.z, 0.001);

    // Looking straight up (pitch = +90): look = (0.0, 1.0, 0.0)
    const up = computeLookVec3(90.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), up.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), up.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), up.z, 0.001);

    // Looking straight down (pitch = -90): look = (0.0, -1.0, 0.0)
    const down = computeLookVec3(-90.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), down.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), down.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), down.z, 0.001);
}

test "34: FireworkRocket item helper initialization" {
    const safe_rocket = FireworkRocketProps.init(1, false);
    try std.testing.expectEqual(@as(u8, 1), safe_rocket.duration_tier);
    try std.testing.expect(!safe_rocket.has_firework_star);
    try std.testing.expectEqual(@as(u8, 0), safe_rocket.star_count);

    const explosive_rocket = FireworkRocketProps.init(3, true);
    try std.testing.expectEqual(@as(u8, 3), explosive_rocket.duration_tier);
    try std.testing.expect(explosive_rocket.has_firework_star);
    try std.testing.expectEqual(@as(u8, 1), explosive_rocket.star_count);
}

test "35: landing on ground terminates gliding flight and resets kinematics" {
    var glider = ElytraGlider.init();
    glider.state = .gliding;
    glider.v_horiz = 12.0;
    glider.vy = -1.0;
    glider.boost_ticks_remaining = 15;

    glider.tick(.{ .pitch_deg = 0.0, .yaw_rad = 0.0, .jump_pressed = false, .is_on_ground = true });

    try std.testing.expectEqual(KinematicFlightState.grounded, glider.state);
    try std.testing.expectEqual(@as(f32, 0.0), glider.v_horiz);
    try std.testing.expectEqual(@as(f32, 0.0), glider.vy);
    try std.testing.expectEqual(@as(u32, 0), glider.boost_ticks_remaining);
}

// ============================================================================
// Unit Tests (unification additions)
// ============================================================================

test "RocketBoostTier duration values and ticks" {
    try std.testing.expectEqual(@as(u32, 20), RocketBoostTier.tier1.durationTicks());
    try std.testing.expectEqual(@as(u32, 40), RocketBoostTier.tier2.durationTicks());
    try std.testing.expectEqual(@as(u32, 60), RocketBoostTier.tier3.durationTicks());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), RocketBoostTier.tier1.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), RocketBoostTier.tier2.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), RocketBoostTier.tier3.durationSeconds(), 0.001);
}

test "FireworkRocketProps initialization and helpers" {
    const r1 = FireworkRocketProps.init(1, false);
    try std.testing.expectEqual(@as(u8, 1), r1.duration_tier);
    try std.testing.expect(!r1.has_firework_star);
    try std.testing.expectEqual(@as(f32, 0.0), r1.blastDamage());
    try std.testing.expectEqual(@as(u32, 20), r1.durationTicks());

    const r3 = FireworkRocketProps.init(3, true);
    try std.testing.expectEqual(@as(u8, 3), r3.duration_tier);
    try std.testing.expect(r3.has_firework_star);
    try std.testing.expectEqual(@as(f32, 5.0), r3.blastDamage());
    try std.testing.expectEqual(@as(u32, 60), r3.durationTicks());
}

test "evaluateKineticCrash returns correct crash state and damage" {
    const safe = evaluateKineticCrash(9.5);
    try std.testing.expect(!safe.is_crash);
    try std.testing.expectEqual(@as(f32, 0.0), safe.damage);

    const threshold = evaluateKineticCrash(10.0);
    try std.testing.expect(!threshold.is_crash);
    try std.testing.expectEqual(@as(f32, 0.0), threshold.damage);

    const crash12 = evaluateKineticCrash(12.0);
    try std.testing.expect(crash12.is_crash);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), crash12.damage, 0.001);

    const crash15 = evaluateKineticCrash(15.0);
    try std.testing.expect(crash15.is_crash);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), crash15.damage, 0.001);
}
