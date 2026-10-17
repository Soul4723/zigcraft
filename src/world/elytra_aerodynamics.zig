const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Maximum durability of Elytra wings (432 points in Minecraft Java Edition).
pub const max_durability: u16 = 432;

/// Durability threshold where Elytra wings become "tattered" and unusable (1 point).
/// Elytra does NOT break completely at 0 durability; it stops functioning at 1.
pub const tattered_durability: u16 = 1;

/// Durability restored per Phantom Membrane during anvil / crafting repair (108 points = 25% of 432).
pub const membrane_repair_amount: u16 = 108;
pub const membrane_repair_percent: u8 = 25;

/// Terminal horizontal airspeed achievable during steep dives (67.0 m/s = 3.35 blocks/tick).
pub const max_horizontal_speed: f32 = 67.0;

/// Propulsion velocity granted by an active Firework Rocket flight boost (33.5 m/s = 1.675 blocks/tick).
pub const rocket_boost_speed: f32 = 33.5;

/// Default duration of a Firework Rocket flight boost in seconds (1.5 seconds).
pub const default_rocket_duration: f32 = 1.5;

/// Minimum horizontal collision velocity required to inflict kinetic energy damage (12.0 m/s).
pub const kinetic_damage_threshold: f32 = 12.0;

/// Kinetic damage scaling multiplier per m/s exceeding 12.0 m/s (1.2 damage per m/s excess).
pub const kinetic_damage_multiplier: f32 = 1.2;

/// Aerodynamic sink speed during level horizontal glide (descent of 1.2 m/s).
pub const level_sink_speed: f32 = -1.2;

/// Natural gravitational acceleration applied to gliding entities (9.81 m/s²).
pub const glide_gravity: f32 = 9.81;

/// Parasitic drag factor applied per second during horizontal glide.
pub const horizontal_drag_coeff: f32 = 0.05;

// ============================================================================
// State Management
// ============================================================================

/// Tracks the active flight state and durability of an Elytra wing pair.
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
        self.durability = repairWithPhantomMembrane(self.durability, membrane_count);
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

/// Computes repaired durability using Phantom Membranes (+108 per membrane, 25% of 432 max).
/// Clamps at max_durability (432).
pub fn repairWithPhantomMembrane(current_durability: u16, membrane_count: u16) u16 {
    const total_repair = @as(u32, membrane_count) * @as(u32, membrane_repair_amount);
    const new_durability = @as(u32, current_durability) + total_repair;
    return @intCast(@min(@as(u32, max_durability), new_durability));
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
// Aerodynamics & Propulsion
// ============================================================================

/// Computes the unit 3D look vector from pitch (degrees) and yaw (radians).
/// - pitch_deg: negative is looking down (dive), positive is looking up (climb).
/// - yaw_rad: azimuth angle around the vertical Y axis.
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

// ============================================================================
// Unit Tests
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
