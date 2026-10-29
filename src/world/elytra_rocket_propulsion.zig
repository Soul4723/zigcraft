const std = @import("std");

// ============================================================================
// Milestone 475: Elytra Kinetic Glide & Firework Rocket Propulsion
// ============================================================================
// Core mechanics:
// 1. Elytra Gliding Flight Kinematics:
//    - Flight state machine: .grounded, .falling, .gliding, .kinetic_impact.
//    - Activation condition: Player falls in air and presses jump spacebar
//      while equipped with Elytra (is_equipped = true, fall_distance > 0.0).
//    - Pitch angle aerodynamics (theta in [-90, +90] deg):
//      * Dive (theta < 0): converts potential energy into horizontal velocity:
//        v_horiz += -0.08 * @sin(theta_rad)
//      * Climb (theta > 0): converts horizontal velocity into vertical altitude:
//        vy += 0.06 * @sin(theta_rad) - gravity
//      * Drag decay: drag coefficient 0.99 per tick.
// 2. Firework Rocket Propulsion Boost:
//    - Right-clicking Firework Rocket while gliding (boostWithRocket(duration_tier)):
//      * Consumes 1 Firework Rocket.
//      * Adds forward acceleration vector along camera look direction: look_vector * 1.5 m/s^2.
//      * Duration scaling: Tier 1 (20 ticks / 1.0s), Tier 2 (40 ticks / 2.0s), Tier 3 (60 ticks / 3.0s).
//      * Firework Star explosion hazard: If crafted with an explosive Firework Star,
//        exploding at the end of the boost deals 5.0 HP direct blast damage to the player!
// 3. Kinetic Wall Crash Collision Damage:
//    - Colliding with solid block face at high speed (v >= 10.0 m/s):
//      damage = @max(0.0, (v - 10.0) * 2.0)
//    - Resets forward velocity to 0 and cancels gliding flight.
// 4. Durability Consumption & Broken State:
//    - Consumes 1 durability point per second of gliding flight (once per 20 ticks).
//    - At 1 durability point, Elytra breaks into Broken Elytra (is_broken = true),
//      halts flight, and cannot be flown until repaired with Phantom Membranes in an Anvil.
// ============================================================================

// ============================================================================
// Constants
// ============================================================================

/// Maximum durability of Elytra wings in Minecraft Java Edition.
pub const max_durability: u16 = 432;

/// Threshold durability where Elytra breaks into Broken Elytra (stops functioning at 1 point).
pub const broken_durability: u16 = 1;

/// Durability restored per Phantom Membrane during Anvil repair (108 points = 25% of 432).
pub const membrane_repair_amount: u16 = 108;
pub const membrane_repair_percent: u8 = 25;

/// Minimum collision speed required to inflict kinetic crash damage (10.0 m/s).
pub const kinetic_damage_threshold: f32 = 10.0;

/// Damage multiplier per m/s exceeding the 10.0 m/s threshold (2.0 HP per excess m/s).
pub const kinetic_damage_multiplier: f32 = 2.0;

/// Blast damage dealt to player if boosting with an explosive Firework Star rocket (5.0 HP).
pub const firework_star_blast_damage: f32 = 5.0;

/// Forward acceleration added along camera look vector per tick during rocket boost (1.5 m/s^2).
pub const rocket_acceleration: f32 = 1.5;

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

// ============================================================================
// 3D Vector Math
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

// ============================================================================
// Enums & Types
// ============================================================================

/// Four primary kinematic flight states of an Elytra-equipped player.
pub const ElytraFlightState = enum {
    grounded,
    falling,
    gliding,
    kinetic_impact,

    pub fn isGliding(self: ElytraFlightState) bool {
        return self == .gliding;
    }

    pub fn isAirborne(self: ElytraFlightState) bool {
        return self == .falling or self == .gliding;
    }

    pub fn name(self: ElytraFlightState) []const u8 {
        return switch (self) {
            .grounded => "grounded",
            .falling => "falling",
            .gliding => "gliding",
            .kinetic_impact => "kinetic_impact",
        };
    }
};

/// Item representation of a Firework Rocket used for flight propulsion.
pub const FireworkRocket = struct {
    duration_tier: u8 = 1, // Tier 1 (1.0s / 20t), Tier 2 (2.0s / 40t), Tier 3 (3.0s / 60t)
    has_firework_star: bool = false, // If true, explodes with direct blast hazard
    star_count: u8 = 0, // Number of firework stars crafted into rocket

    pub fn init(tier: u8, has_star: bool) FireworkRocket {
        return .{
            .duration_tier = std.math.clamp(tier, 1, 3),
            .has_firework_star = has_star,
            .star_count = if (has_star) 1 else 0,
        };
    }
};

/// Player input per tick driving the flight state machine and aerodynamics.
pub const FlightInput = struct {
    pitch_deg: f32 = 0.0, // Camera pitch angle in [-90, +90] deg (negative is dive, positive is climb)
    yaw_rad: f32 = 0.0, // Camera horizontal azimuth in radians
    jump_pressed: bool = false, // Spacebar key status
    is_on_ground: bool = false, // Solid block collision beneath feet
};

/// Detailed outcome of an Anvil repair operation using Phantom Membranes.
pub const AnvilRepairResult = struct {
    initial_durability: u16,
    repaired_durability: u16,
    durability_restored: u16,
    membranes_used: u16,
    is_broken: bool,
    xp_level_cost: u32,
};

// ============================================================================
// Core Calculation Functions
// ============================================================================

/// Evaluates if gliding flight can be initiated.
/// Player must:
/// - Be airborne (!is_on_ground)
/// - Be equipped with Elytra (is_equipped = true)
/// - Elytra not broken (!is_broken and durability > 1)
/// - Have accumulated positive fall distance (fall_distance > 0.0)
/// - Press the jump spacebar (jump_pressed = true)
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

/// Computes the unit 3D look vector from camera pitch (deg) and yaw (rad).
/// - pitch_deg in [-90, +90]: negative is looking down, positive is looking up.
/// - yaw_rad: horizontal rotation around vertical Y axis.
pub fn computeLookVector(pitch_deg: f32, yaw_rad: f32) Vec3 {
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

/// Computes kinetic crash damage inflicted when colliding with a solid block face while flying.
/// - Below 10.0 m/s: zero damage (safe impact).
/// - At or above 10.0 m/s: damage = @max(0.0, (v - 10.0) * 2.0).
pub fn computeKineticCrashDamage(impact_velocity: f32) f32 {
    const v = @abs(impact_velocity);
    if (v < kinetic_damage_threshold) {
        return 0.0;
    }
    return (v - kinetic_damage_threshold) * kinetic_damage_multiplier;
}

/// Returns the boost duration in game ticks for a specified flight duration tier (1..3).
pub fn computeRocketBoostDurationTicks(tier: u8) u32 {
    return switch (tier) {
        0 => 0,
        1 => tier1_duration_ticks, // 20 ticks = 1.0s
        2 => tier2_duration_ticks, // 40 ticks = 2.0s
        else => tier3_duration_ticks, // 60 ticks = 3.0s
    };
}

/// Computes blast damage dealt by a firework rocket at the end of its flight boost.
/// A rocket with an explosive Firework Star inflicts 5.0 HP direct blast damage to the player!
pub fn computeRocketBlastDamage(has_firework_star: bool) f32 {
    if (has_firework_star) {
        return firework_star_blast_damage;
    }
    return 0.0;
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

/// Evaluates one tick of 2D pitch aerodynamics and drag decay:
/// 1. v_horiz += -0.08 * @sin(theta_rad)
/// 2. vy += 0.06 * @sin(theta_rad) - gravity
/// 3. v_horiz *= 0.99
/// 4. vy *= 0.99
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

/// Standalone helper to calculate durability after repairing with Phantom Membranes.
/// Each membrane restores 108 durability (25% of 432 max), capped at 432.
pub fn repairWithPhantomMembrane(current_durability: u16, membrane_count: u16) u16 {
    const total_added = @as(u32, membrane_count) * @as(u32, membrane_repair_amount);
    const new_dur = @as(u32, current_durability) + total_added;
    return @intCast(@min(@as(u32, max_durability), new_dur));
}

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

// ============================================================================
// Elytra Glider Kinematics Controller
// ============================================================================

/// Full kinematic controller simulating Elytra flight, rocket propulsion,
/// kinetic wall collisions, durability wear, and anvil repair.
pub const ElytraGlider = struct {
    /// Active flight state in the state machine.
    state: ElytraFlightState = .grounded,

    /// Remaining durability points (1..432).
    durability: u16 = max_durability,

    /// True if durability drops to 1, disabling flight until anvil repaired.
    is_broken: bool = false,

    /// Whether the player has Elytra equipped in the chestplate armor slot.
    is_equipped: bool = true,

    /// Accumulated distance fallen in air while not gliding.
    fall_distance: f32 = 0.0,

    /// Horizontal airspeed component in m/s (blocks/tick * 20 or m/s).
    v_horiz: f32 = 0.0,

    /// Vertical velocity component in m/s.
    vy: f32 = 0.0,

    /// Full 3D velocity vector.
    velocity: Vec3 = Vec3.zero,

    /// Gravitational downward acceleration applied per tick.
    gravity: f32 = default_gravity,

    /// Consumable Firework Rocket inventory count.
    firework_rockets: u32 = 16,

    /// Remaining ticks of active rocket propulsion boost.
    boost_ticks_remaining: u32 = 0,

    /// Active flight duration tier of current boost (1, 2, or 3).
    active_boost_tier: u8 = 0,

    /// Whether currently active rocket boost contains an explosive Firework Star.
    has_active_firework_star: bool = false,

    /// Tick counter tracking seconds of flight for 1 durability drain per 20 ticks.
    durability_tick_counter: u32 = 0,

    /// Player hit points (default 20.0 HP = 10 hearts).
    player_health: f32 = 20.0,

    /// Blast damage received from the most recent firework star detonation.
    last_blast_damage: f32 = 0.0,

    /// Kinetic damage received from the most recent solid block wall collision.
    last_kinetic_damage: f32 = 0.0,

    /// Initializes a brand new Elytra glider at full durability.
    pub fn init() ElytraGlider {
        return .{};
    }

    /// Initializes an Elytra glider with specified durability.
    pub fn initWithDurability(dur: u16) ElytraGlider {
        const d = @min(dur, max_durability);
        return .{
            .durability = d,
            .is_broken = (d <= broken_durability),
        };
    }

    /// Returns true if the Elytra is equipped, unbroken, and has durability > 1.
    pub fn canFly(self: ElytraGlider) bool {
        return self.is_equipped and !self.is_broken and self.durability > broken_durability;
    }

    /// Returns true if currently in gliding flight state.
    pub fn isGliding(self: ElytraGlider) bool {
        return self.state == .gliding;
    }

    /// Returns true if rocket propulsion boost is actively propelling the glider.
    pub fn isRocketBoosting(self: ElytraGlider) bool {
        return self.state == .gliding and self.boost_ticks_remaining > 0;
    }

    /// Attempts to deploy Elytra flight based on player inputs and fall conditions.
    pub fn tryActivateGliding(self: *ElytraGlider, jump_pressed: bool, is_on_ground: bool) bool {
        if (!canInitiateGlide(self.is_equipped, self.is_broken, self.durability, self.fall_distance, is_on_ground, jump_pressed)) {
            return false;
        }

        self.state = .gliding;
        self.fall_distance = 0.0;
        return true;
    }

    /// Right-click Firework Rocket flight boost with specified duration tier (1..3).
    /// Safe rocket (0 firework stars). Consumes 1 Firework Rocket.
    pub fn boostWithRocket(self: *ElytraGlider, duration_tier: u8) bool {
        return self.boostWithRocketConfig(duration_tier, false);
    }

    /// Right-click Firework Rocket flight boost with an explosive Firework Star.
    /// Explodes at the end of boost dealing 5.0 HP direct blast damage to the player!
    pub fn boostWithExplosiveRocket(self: *ElytraGlider, duration_tier: u8) bool {
        return self.boostWithRocketConfig(duration_tier, true);
    }

    /// Right-click Firework Rocket using a FireworkRocket item struct.
    pub fn boostWithRocketItem(self: *ElytraGlider, rocket: FireworkRocket) bool {
        return self.boostWithRocketConfig(rocket.duration_tier, rocket.has_firework_star);
    }

    /// Internal rocket boost ignition logic.
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

    /// Handles solid block wall collision at given impact velocity.
    /// If speed >= 10.0 m/s:
    /// - Inflicts kinetic damage = @max(0.0, (v - 10.0) * 2.0).
    /// - Resets forward velocity to 0.
    /// - Cancels gliding flight (transitions to .kinetic_impact).
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

    /// Repairs durability with Phantom Membranes (+108 per membrane, capped at 432).
    /// Restores broken wings back to usable status if durability > 1.
    pub fn repairWithPhantomMembrane(self: *ElytraGlider, membrane_count: u16) u16 {
        self.durability = @import("elytra_rocket_propulsion.zig").repairWithPhantomMembrane(self.durability, membrane_count);
        if (self.durability > broken_durability) {
            self.is_broken = false;
        }
        return self.durability;
    }

    /// Performs an Anvil repair using offered Phantom Membranes.
    pub fn repairInAnvil(self: *ElytraGlider, membranes_offered: u16) AnvilRepairResult {
        const result = calculateAnvilRepair(self.durability, membranes_offered);
        self.durability = result.repaired_durability;
        self.is_broken = result.is_broken;
        return result;
    }

    /// Consumes durability, clamping at 1 (broken). Halts flight if broken.
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

    /// Advances 1 simulation tick of flight kinematics, inputs, and aerodynamics.
    pub fn tick(self: *ElytraGlider, input: FlightInput) void {
        // Touchdown on ground terminates flight
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

        // Kinetic impact state recovery
        if (self.state == .kinetic_impact) {
            self.v_horiz = 0.0;
            self.vy = 0.0;
            self.velocity = Vec3.zero;
            self.state = .falling;
            return;
        }

        // Falling state: accumulate fall distance and check for glide deployment
        if (self.state == .falling) {
            self.fall_distance += @max(0.1, -self.vy * 0.05 + 0.1);
            if (input.jump_pressed and self.canFly()) {
                _ = self.tryActivateGliding(input.jump_pressed, input.is_on_ground);
            } else {
                self.vy -= self.gravity;
                self.vy *= 0.98; // Standard airborne fall drag
                self.velocity = Vec3.init(0.0, self.vy, 0.0);
            }
            return;
        }

        // Gliding state aerodynamics & propulsion
        if (self.state == .gliding) {
            // Verify broken status
            if (self.is_broken or self.durability <= broken_durability) {
                self.is_broken = true;
                self.state = .falling;
                self.boost_ticks_remaining = 0;
                self.has_active_firework_star = false;
                return;
            }

            // Durability wear: 1 durability per second (every 20 ticks)
            self.durability_tick_counter += 1;
            if (self.durability_tick_counter >= ticks_per_second) {
                self.durability_tick_counter = 0;
                self.consumeDurability(1);
                if (self.is_broken) {
                    return;
                }
            }

            // Rocket propulsion boost
            if (self.boost_ticks_remaining > 0) {
                const look = computeLookVector(input.pitch_deg, input.yaw_rad);
                // Forward acceleration along camera look direction: look_vector * 1.5 m/s^2
                self.velocity.x += look.x * rocket_acceleration;
                self.velocity.y += look.y * rocket_acceleration;
                self.velocity.z += look.z * rocket_acceleration;

                const clamped_pitch = std.math.clamp(input.pitch_deg, -90.0, 90.0);
                const pitch_rad = clamped_pitch * (std.math.pi / 180.0);
                self.v_horiz += @cos(pitch_rad) * rocket_acceleration;
                self.vy += @sin(pitch_rad) * rocket_acceleration;

                self.boost_ticks_remaining -= 1;
                if (self.boost_ticks_remaining == 0) {
                    // Boost finished! Check for Firework Star blast hazard
                    if (self.has_active_firework_star) {
                        self.has_active_firework_star = false;
                        self.player_health = @max(0.0, self.player_health - firework_star_blast_damage);
                        self.last_blast_damage = firework_star_blast_damage;
                    }
                }
            }

            // Pitch angle aerodynamics:
            const clamped_pitch = std.math.clamp(input.pitch_deg, -90.0, 90.0);
            const theta_rad = clamped_pitch * (std.math.pi / 180.0);
            const sin_theta = @sin(theta_rad);

            // Horizontal thrust conversion from dive (theta < 0) or climb deceleration (theta > 0):
            // v_horiz += -0.08 * @sin(theta_rad)
            self.v_horiz += -dive_thrust_coefficient * sin_theta;
            if (self.v_horiz < 0.0) self.v_horiz = 0.0;

            // Pitching upwards (theta > 0) converts horizontal velocity back into vertical altitude:
            // vy += 0.06 * @sin(theta_rad) - gravity
            self.vy += pitch_lift_coefficient * sin_theta - self.gravity;

            // Drag decay: drag coefficient 0.99 per tick
            self.v_horiz *= drag_coefficient;
            self.vy *= drag_coefficient;

            // Align 3D velocity with horizontal and vertical kinematics
            const cos_y = @cos(input.yaw_rad);
            const sin_y = @sin(input.yaw_rad);
            self.velocity.x = self.v_horiz * cos_y;
            self.velocity.y = self.vy;
            self.velocity.z = self.v_horiz * sin_y;
        }
    }
};

// Aliases for compatibility
pub const ElytraRocketPropulsion = ElytraGlider;
pub const ElytraKinematics = ElytraGlider;
pub const ElytraFlightController = ElytraGlider;

// ============================================================================
// Unit Tests (25+ tests)
// ============================================================================

test "01: constants match Minecraft Java and milestone specification" {
    try std.testing.expectEqual(@as(u16, 432), max_durability);
    try std.testing.expectEqual(@as(u16, 1), broken_durability);
    try std.testing.expectEqual(@as(u16, 108), membrane_repair_amount);
    try std.testing.expectEqual(@as(u8, 25), membrane_repair_percent);
    try std.testing.expectEqual(@as(f32, 10.0), kinetic_damage_threshold);
    try std.testing.expectEqual(@as(f32, 2.0), kinetic_damage_multiplier);
    try std.testing.expectEqual(@as(f32, 5.0), firework_star_blast_damage);
    try std.testing.expectEqual(@as(f32, 1.5), rocket_acceleration);
    try std.testing.expectEqual(@as(f32, 0.08), dive_thrust_coefficient);
    try std.testing.expectEqual(@as(f32, 0.06), pitch_lift_coefficient);
    try std.testing.expectEqual(@as(f32, 0.99), drag_coefficient);
    try std.testing.expectEqual(@as(u32, 20), tier1_duration_ticks);
    try std.testing.expectEqual(@as(u32, 40), tier2_duration_ticks);
    try std.testing.expectEqual(@as(u32, 60), tier3_duration_ticks);
}

test "02: ElytraFlightState enum variants and helper methods" {
    const s1 = ElytraFlightState.grounded;
    const s2 = ElytraFlightState.falling;
    const s3 = ElytraFlightState.gliding;
    const s4 = ElytraFlightState.kinetic_impact;

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
    try std.testing.expectEqual(ElytraFlightState.gliding, glider.state);
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
    try std.testing.expectEqual(ElytraFlightState.falling, glider.state);
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
    try std.testing.expectEqual(ElytraFlightState.grounded, glider.state);
}

test "06: gliding initiation fails when fall distance is zero or negative" {
    try std.testing.expect(!canInitiateGlide(true, false, 432, 0.0, false, true));
    try std.testing.expect(!canInitiateGlide(true, false, 432, -0.5, false, true));

    var glider = ElytraGlider.init();
    glider.state = .falling;
    glider.fall_distance = 0.0;
    try std.testing.expect(!glider.tryActivateGliding(true, false));
    try std.testing.expectEqual(ElytraFlightState.falling, glider.state);
}

test "07: gliding initiation fails when jump spacebar is not pressed" {
    try std.testing.expect(!canInitiateGlide(true, false, 432, 1.0, false, false));

    var glider = ElytraGlider.init();
    glider.state = .falling;
    glider.fall_distance = 1.0;
    try std.testing.expect(!glider.tryActivateGliding(false, false));
    try std.testing.expectEqual(ElytraFlightState.falling, glider.state);
}

test "08: gliding initiation fails when Elytra is broken (is_broken = true)" {
    try std.testing.expect(!canInitiateGlide(true, true, 432, 1.0, false, true));

    var glider = ElytraGlider.init();
    glider.is_broken = true;
    glider.state = .falling;
    glider.fall_distance = 1.0;
    try std.testing.expect(!glider.tryActivateGliding(true, false));
    try std.testing.expectEqual(ElytraFlightState.falling, glider.state);
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
    try std.testing.expectEqual(ElytraFlightState.gliding, glider.state);
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
    try std.testing.expectEqual(ElytraFlightState.kinetic_impact, glider.state);
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
    try std.testing.expectEqual(ElytraFlightState.falling, glider.state);
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
    const forward = computeLookVector(0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), forward.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), forward.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), forward.z, 0.001);

    // Looking straight up (pitch = +90): look = (0.0, 1.0, 0.0)
    const up = computeLookVector(90.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), up.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), up.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), up.z, 0.001);

    // Looking straight down (pitch = -90): look = (0.0, -1.0, 0.0)
    const down = computeLookVector(-90.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), down.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), down.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), down.z, 0.001);
}

test "34: FireworkRocket item helper initialization" {
    const safe_rocket = FireworkRocket.init(1, false);
    try std.testing.expectEqual(@as(u8, 1), safe_rocket.duration_tier);
    try std.testing.expect(!safe_rocket.has_firework_star);
    try std.testing.expectEqual(@as(u8, 0), safe_rocket.star_count);

    const explosive_rocket = FireworkRocket.init(3, true);
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

    try std.testing.expectEqual(ElytraFlightState.grounded, glider.state);
    try std.testing.expectEqual(@as(f32, 0.0), glider.v_horiz);
    try std.testing.expectEqual(@as(f32, 0.0), glider.vy);
    try std.testing.expectEqual(@as(u32, 0), glider.boost_ticks_remaining);
}
