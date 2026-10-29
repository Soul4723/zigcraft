const std = @import("std");

/// Field of View dot product threshold for Creaking gaze freeze.
/// cos(45 degrees) ≈ 0.70710678; dot >= 0.707 represents within 45 degrees horizontal/vertical FOV.
pub const fov_dot_threshold: f32 = 0.707;
pub const fov_half_angle_degrees: f32 = 45.0;

/// Physical and kinematic constants for Creaking stalking pursuit.
pub const stalking_speed: f32 = 2.4; // 2.4 m/s (blocks per second)
pub const creaking_height: f32 = 2.7; // standard Creaking mob height
pub const creaking_center_y_offset: f32 = 1.35; // center block height for LOS evaluation
pub const creaking_attack_range: f32 = 2.0; // melee attack distance
pub const creaking_attack_damage: f32 = 3.0; // virtual attack power

/// Acoustic emission constants.
/// Creaking moves with completely silent footstep kinematics.
pub const silent_footstep_frequency: f32 = 0.0; // 0.0 Hz acoustic frequency
pub const silent_vibration_frequency: u8 = 0; // 0 vibration frequency

/// Day/night and light level thresholds for Eyeblossom state machine.
pub const night_time_start: u32 = 13000;
pub const night_time_end: u32 = 23000;
pub const night_light_threshold: u8 = 7;
pub const eyeblossom_resonance_radius: f32 = 16.0;

/// Callback type for querying whether a block at integer coordinates (x, y, z) is solid and opaque.
pub const IsOpaqueFn = *const fn (x: i32, y: i32, z: i32) bool;

/// Represents a player's observation parameters (eye position, gaze vector, and gear).
pub const PlayerView = struct {
    id: u32 = 1,
    eye_pos: [3]f32,
    look_dir: [3]f32,
    wearing_carved_pumpkin: bool = false,

    pub fn init(id: u32, eye_pos: [3]f32, look_dir: [3]f32) PlayerView {
        return .{
            .id = id,
            .eye_pos = eye_pos,
            .look_dir = look_dir,
            .wearing_carved_pumpkin = false,
        };
    }
};

/// Computes the normalized dot product between the player's look direction
/// and the vector from the player's eye to the target position.
pub fn computeGazeDotProduct(player_eye: [3]f32, player_look: [3]f32, target: [3]f32) f32 {
    const dx = target[0] - player_eye[0];
    const dy = target[1] - player_eye[1];
    const dz = target[2] - player_eye[2];
    const dist_sq = dx * dx + dy * dy + dz * dz;

    // Player eye is inside or identical to target position
    if (dist_sq < 1e-7) return 1.0;

    const look_sq = player_look[0] * player_look[0] +
        player_look[1] * player_look[1] +
        player_look[2] * player_look[2];

    // Invalid zero-length look vector
    if (look_sq < 1e-7) return -1.0;

    const inv_dist = 1.0 / @sqrt(dist_sq);
    const to_target_x = dx * inv_dist;
    const to_target_y = dy * inv_dist;
    const to_target_z = dz * inv_dist;

    const inv_look = 1.0 / @sqrt(look_sq);
    const look_x = player_look[0] * inv_look;
    const look_y = player_look[1] * inv_look;
    const look_z = player_look[2] * inv_look;

    return to_target_x * look_x + to_target_y * look_y + to_target_z * look_z;
}

/// Checks if a target is within the player's 45-degree FOV cone (dot >= 0.707).
pub fn isWithinFOV(player_eye: [3]f32, player_look: [3]f32, target: [3]f32) bool {
    return isWithinFOVThreshold(player_eye, player_look, target, fov_dot_threshold);
}

/// Checks if a target is within an arbitrary FOV dot threshold.
pub fn isWithinFOVThreshold(player_eye: [3]f32, player_look: [3]f32, target: [3]f32, threshold: f32) bool {
    const dot = computeGazeDotProduct(player_eye, player_look, target);
    return dot >= threshold;
}

/// Evaluates line-of-sight between `start` and `end` using 3D voxel DDA (Amanatides & Woo).
/// Returns true if the ray reaches `end` without encountering any solid opaque blocks.
pub fn hasLineOfSight(
    start: [3]f32,
    end: [3]f32,
    is_opaque: ?IsOpaqueFn,
) bool {
    const is_opaque_fn = is_opaque orelse return true;

    const dx = end[0] - start[0];
    const dy = end[1] - start[1];
    const dz = end[2] - start[2];
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);
    if (dist < 1e-5) return true;

    const dir_x = dx / dist;
    const dir_y = dy / dist;
    const dir_z = dz / dist;

    var curr_x: i32 = @intFromFloat(@floor(start[0]));
    var curr_y: i32 = @intFromFloat(@floor(start[1]));
    var curr_z: i32 = @intFromFloat(@floor(start[2]));

    const target_x: i32 = @intFromFloat(@floor(end[0]));
    const target_y: i32 = @intFromFloat(@floor(end[1]));
    const target_z: i32 = @intFromFloat(@floor(end[2]));

    // Start and end are in the same voxel
    if (curr_x == target_x and curr_y == target_y and curr_z == target_z) {
        return true;
    }

    // If starting cell is solid opaque, line of sight is obstructed
    if (is_opaque_fn(curr_x, curr_y, curr_z)) {
        return false;
    }

    const step_x: i32 = if (dir_x > 0) 1 else if (dir_x < 0) -1 else 0;
    const step_y: i32 = if (dir_y > 0) 1 else if (dir_y < 0) -1 else 0;
    const step_z: i32 = if (dir_z > 0) 1 else if (dir_z < 0) -1 else 0;

    const t_delta_x: f32 = if (dir_x != 0) @abs(1.0 / dir_x) else std.math.inf(f32);
    const t_delta_y: f32 = if (dir_y != 0) @abs(1.0 / dir_y) else std.math.inf(f32);
    const t_delta_z: f32 = if (dir_z != 0) @abs(1.0 / dir_z) else std.math.inf(f32);

    var t_max_x: f32 = if (dir_x != 0)
        (if (step_x > 0) (@as(f32, @floatFromInt(curr_x + 1)) - start[0]) else (start[0] - @as(f32, @floatFromInt(curr_x)))) * t_delta_x
    else
        std.math.inf(f32);
    var t_max_y: f32 = if (dir_y != 0)
        (if (step_y > 0) (@as(f32, @floatFromInt(curr_y + 1)) - start[1]) else (start[1] - @as(f32, @floatFromInt(curr_y)))) * t_delta_y
    else
        std.math.inf(f32);
    var t_max_z: f32 = if (dir_z != 0)
        (if (step_z > 0) (@as(f32, @floatFromInt(curr_z + 1)) - start[2]) else (start[2] - @as(f32, @floatFromInt(curr_z)))) * t_delta_z
    else
        std.math.inf(f32);

    var t: f32 = 0.0;
    var max_steps: usize = 256;

    while (t < dist and max_steps > 0) : (max_steps -= 1) {
        if (t_max_x < t_max_y and t_max_x < t_max_z) {
            curr_x += step_x;
            t = t_max_x;
            t_max_x += t_delta_x;
        } else if (t_max_y < t_max_z) {
            curr_y += step_y;
            t = t_max_y;
            t_max_y += t_delta_y;
        } else {
            curr_z += step_z;
            t = t_max_z;
            t_max_z += t_delta_z;
        }

        // Reached destination cell without obstruction
        if (curr_x == target_x and curr_y == target_y and curr_z == target_z) {
            return true;
        }

        if (t >= dist - 1e-4) break;

        // Hit a solid opaque block between origin and target
        if (is_opaque_fn(curr_x, curr_y, curr_z)) {
            return false;
        }
    }

    return true;
}

/// Helper evaluating line-of-sight against a slice of blocked integer coordinates.
pub fn checkLineOfSightWithObstacles(start: [3]f32, end: [3]f32, obstacles: []const [3]i32) bool {
    const Context = struct {
        var obstacle_slice: []const [3]i32 = &.{};
        fn isOpaque(x: i32, y: i32, z: i32) bool {
            for (obstacle_slice) |b| {
                if (b[0] == x and b[1] == y and b[2] == z) return true;
            }
            return false;
        }
    };
    Context.obstacle_slice = obstacles;
    return hasLineOfSight(start, end, Context.isOpaque);
}

/// Determines whether a single player has active gaze on the Creaking center block.
/// Requires:
/// 1. Not wearing carved pumpkin (pumpkin grants immunity/bypasses gaze freeze).
/// 2. Creaking center is within 45-degree FOV cone (dot >= 0.707).
/// 3. Clear unobstructed line-of-sight without solid opaque blocks in between.
pub fn isPlayerGazingAtCreaking(
    player: PlayerView,
    creaking_center: [3]f32,
    is_opaque: ?IsOpaqueFn,
) bool {
    if (player.wearing_carved_pumpkin) return false;

    const dot = computeGazeDotProduct(player.eye_pos, player.look_dir, creaking_center);
    if (dot < fov_dot_threshold) return false;

    return hasLineOfSight(player.eye_pos, creaking_center, is_opaque);
}

/// Evaluates Creaking gaze freeze across all players in the world.
/// When ANY player has clear LOS within their view cone, the Creaking is frozen.
pub fn evaluateCreakingGazeFreeze(
    creaking_center: [3]f32,
    players: []const PlayerView,
    is_opaque: ?IsOpaqueFn,
) bool {
    for (players) |player| {
        if (isPlayerGazingAtCreaking(player, creaking_center, is_opaque)) {
            return true;
        }
    }
    return false;
}

/// Creaking mob AI state machine and stalking kinematics tracker.
pub const CreakingAI = struct {
    id: u32 = 1,
    pos: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    is_frozen: bool = false,
    is_alerted: bool = false,
    hostility_suppressed: bool = false,
    can_attack: bool = false,
    stalking_speed: f32 = stalking_speed, // 2.4 m/s
    acoustic_emission_freq: f32 = silent_footstep_frequency, // 0.0 Hz
    vibration_frequency: u8 = silent_vibration_frequency, // 0
    tether_heart_pos: ?[3]i32 = null,
    target_player_id: ?u32 = null,

    pub fn init(pos: [3]f32) CreakingAI {
        return .{
            .pos = pos,
            .velocity = .{ 0.0, 0.0, 0.0 },
            .is_frozen = false,
            .is_alerted = false,
            .hostility_suppressed = false,
            .can_attack = false,
            .stalking_speed = stalking_speed,
            .acoustic_emission_freq = silent_footstep_frequency,
            .vibration_frequency = silent_vibration_frequency,
            .tether_heart_pos = null,
            .target_player_id = null,
        };
    }

    /// Center block coordinate of the Creaking for line-of-sight checks.
    pub fn getCenterPos(self: *const CreakingAI) [3]f32 {
        return .{
            self.pos[0],
            self.pos[1] + creaking_center_y_offset,
            self.pos[2],
        };
    }

    /// Evaluates gaze freeze status from a list of players.
    pub fn updateGaze(
        self: *CreakingAI,
        players: []const PlayerView,
        is_opaque: ?IsOpaqueFn,
    ) bool {
        const center = self.getCenterPos();
        self.is_frozen = evaluateCreakingGazeFreeze(center, players, is_opaque);
        if (self.is_frozen) {
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.can_attack = false;
        }
        return self.is_frozen;
    }

    /// Performs stalking pursuit kinematics towards a target position when unobserved.
    pub fn updatePursuit(self: *CreakingAI, target_pos: [3]f32, dt: f32) void {
        if (self.is_frozen or self.hostility_suppressed) {
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.can_attack = false;
            self.acoustic_emission_freq = silent_footstep_frequency;
            self.vibration_frequency = silent_vibration_frequency;
            return;
        }

        const dx = target_pos[0] - self.pos[0];
        const dz = target_pos[2] - self.pos[2];
        const dist_horiz_sq = dx * dx + dz * dz;

        if (dist_horiz_sq < 0.0001) {
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.can_attack = true;
            self.acoustic_emission_freq = silent_footstep_frequency;
            self.vibration_frequency = silent_vibration_frequency;
            return;
        }

        const dist_horiz = @sqrt(dist_horiz_sq);
        const dir_x = dx / dist_horiz;
        const dir_z = dz / dist_horiz;

        self.velocity[0] = dir_x * self.stalking_speed;
        self.velocity[1] = 0.0;
        self.velocity[2] = dir_z * self.stalking_speed;

        self.pos[0] += self.velocity[0] * dt;
        self.pos[2] += self.velocity[2] * dt;

        // Kinematics are completely silent (zero acoustic / vibration emission)
        self.acoustic_emission_freq = silent_footstep_frequency;
        self.vibration_frequency = silent_vibration_frequency;

        // Evaluates melee attack readiness
        const dy = target_pos[1] - self.pos[1];
        const total_dist_sq = dist_horiz_sq + dy * dy;
        self.can_attack = total_dist_sq <= (creaking_attack_range * creaking_attack_range);
    }

    /// Full update cycle: checks player gaze, updates stalking kinematics towards nearest player.
    pub fn update(
        self: *CreakingAI,
        players: []const PlayerView,
        dt: f32,
        is_opaque: ?IsOpaqueFn,
    ) void {
        _ = self.updateGaze(players, is_opaque);

        if (self.is_frozen or self.hostility_suppressed) {
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.can_attack = false;
            self.acoustic_emission_freq = silent_footstep_frequency;
            self.vibration_frequency = silent_vibration_frequency;
            return;
        }

        if (players.len == 0) {
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.can_attack = false;
            self.target_player_id = null;
            return;
        }

        // Find nearest player
        var nearest_idx: ?usize = null;
        var min_dist_sq: f32 = std.math.inf(f32);
        for (players, 0..) |p, i| {
            const dx = p.eye_pos[0] - self.pos[0];
            const dy = p.eye_pos[1] - self.pos[1];
            const dz = p.eye_pos[2] - self.pos[2];
            const dsq = dx * dx + dy * dy + dz * dz;
            if (dsq < min_dist_sq) {
                min_dist_sq = dsq;
                nearest_idx = i;
            }
        }

        if (nearest_idx) |idx| {
            const nearest_p = players[idx];
            self.target_player_id = nearest_p.id;
            self.updatePursuit(nearest_p.eye_pos, dt);
        }
    }
};

/// Eyeblossom flower open/closed state.
pub const EyeblossomState = enum {
    closed,
    open,
};

/// Particle resonance visual types emitted by Eyeblossom flowers.
pub const ResonanceParticle = enum {
    muted_grey,
    orange_resonance,
};

/// Resonance signal emitted by an Eyeblossom flower during day or night cycles.
pub const ResonanceSignal = struct {
    state: EyeblossomState,
    particle: ResonanceParticle,
    particle_color_rgb: [3]f32,
    alerts_creaking: bool,
    suppresses_hostility: bool,
    resonance_radius: f32 = eyeblossom_resonance_radius,
};

/// Evaluates if world time corresponds to nighttime (13000..23000 ticks in 24000 tick cycle).
pub fn isNightTime(world_time: u32) bool {
    const time_of_day = world_time % 24000;
    return time_of_day >= night_time_start and time_of_day <= night_time_end;
}

/// Evaluates Eyeblossom state machine:
/// .open at night (13000..23000) or when light level <= 7.
/// .closed during daytime when light level > 7.
pub fn evaluateEyeblossomState(world_time: u32, light_level: u8) EyeblossomState {
    if (isNightTime(world_time) or light_level <= night_light_threshold) {
        return .open;
    } else {
        return .closed;
    }
}

/// Generates the resonance signal for an Eyeblossom state.
/// Open (night resonance): emits orange particles and alerts Creakings.
/// Closed (day resonance): emits muted grey particles and suppresses Creaking hostility.
pub fn emitResonanceSignal(state: EyeblossomState) ResonanceSignal {
    return switch (state) {
        .open => .{
            .state = .open,
            .particle = .orange_resonance,
            .particle_color_rgb = .{ 1.0, 0.45, 0.0 }, // Vivid orange
            .alerts_creaking = true,
            .suppresses_hostility = false,
            .resonance_radius = eyeblossom_resonance_radius,
        },
        .closed => .{
            .state = .closed,
            .particle = .muted_grey,
            .particle_color_rgb = .{ 0.55, 0.55, 0.55 }, // Muted grey
            .alerts_creaking = false,
            .suppresses_hostility = true,
            .resonance_radius = eyeblossom_resonance_radius,
        },
    };
}

/// State tracking for an Eyeblossom flower in the world.
pub const Eyeblossom = struct {
    pos: [3]i32 = .{ 0, 0, 0 },
    state: EyeblossomState = .closed,

    pub fn init(pos: [3]i32, initial_state: EyeblossomState) Eyeblossom {
        return .{
            .pos = pos,
            .state = initial_state,
        };
    }

    /// Updates flower state based on world time and local block light level.
    /// Returns true if state transitioned.
    pub fn update(self: *Eyeblossom, world_time: u32, light_level: u8) bool {
        const next_state = evaluateEyeblossomState(world_time, light_level);
        const changed = (self.state != next_state);
        self.state = next_state;
        return changed;
    }

    /// Emits resonance signal for current state.
    pub fn getResonanceSignal(self: *const Eyeblossom) ResonanceSignal {
        return emitResonanceSignal(self.state);
    }

    /// Pulses day/night resonance to nearby Creaking entities within 16-block radius.
    /// Returns the number of Creaking puppets affected.
    pub fn pulseResonance(self: *const Eyeblossom, creakings: []CreakingAI) usize {
        const signal = self.getResonanceSignal();
        var affected: usize = 0;
        const ex = @as(f32, @floatFromInt(self.pos[0])) + 0.5;
        const ey = @as(f32, @floatFromInt(self.pos[1])) + 0.5;
        const ez = @as(f32, @floatFromInt(self.pos[2])) + 0.5;

        for (creakings) |*c| {
            const dx = c.pos[0] - ex;
            const dy = c.pos[1] - ey;
            const dz = c.pos[2] - ez;
            const dist_sq = dx * dx + dy * dy + dz * dz;

            if (dist_sq <= signal.resonance_radius * signal.resonance_radius) {
                if (signal.alerts_creaking) {
                    c.is_alerted = true;
                    c.hostility_suppressed = false;
                } else if (signal.suppresses_hostility) {
                    c.hostility_suppressed = true;
                    c.is_alerted = false;
                    c.can_attack = false;
                    c.velocity = .{ 0.0, 0.0, 0.0 };
                }
                affected += 1;
            }
        }
        return affected;
    }
};

// ============================================================================
// Comprehensive Unit Test Suite
// ============================================================================

test "computeGazeDotProduct direct look yields dot 1.0" {
    const player_eye = [3]f32{ 0.0, 1.6, 0.0 };
    const player_look = [3]f32{ 0.0, 0.0, 1.0 }; // Looking straight along +Z
    const creaking_center = [3]f32{ 0.0, 1.6, 10.0 }; // Creaking located along +Z

    const dot = computeGazeDotProduct(player_eye, player_look, creaking_center);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dot, 0.0001);
    try std.testing.expect(isWithinFOV(player_eye, player_look, creaking_center));
}

test "computeGazeDotProduct 45 degree angle boundary yields dot ~0.707" {
    const player_eye = [3]f32{ 0.0, 0.0, 0.0 };
    const creaking_center = [3]f32{ 0.0, 0.0, 10.0 }; // Target along +Z

    // Look at exactly 45 degrees horizontal: (sin(45°), 0, cos(45°)) = (0.70710678, 0, 0.70710678)
    const look_45 = [3]f32{ 0.70710678, 0.0, 0.70710678 };
    const dot_45 = computeGazeDotProduct(player_eye, look_45, creaking_center);

    try std.testing.expectApproxEqAbs(@as(f32, 0.7071), dot_45, 0.001);
    try std.testing.expect(dot_45 >= fov_dot_threshold);
    try std.testing.expect(isWithinFOV(player_eye, look_45, creaking_center));
}

test "computeGazeDotProduct peripheral view at 60 degrees is below threshold" {
    const player_eye = [3]f32{ 0.0, 0.0, 0.0 };
    const creaking_center = [3]f32{ 0.0, 0.0, 10.0 }; // Target along +Z

    // Look at 60 degrees: (sin(60°), 0, cos(60°)) = (0.866025, 0, 0.5) -> dot = 0.5
    const look_60 = [3]f32{ 0.866025, 0.0, 0.5 };
    const dot_60 = computeGazeDotProduct(player_eye, look_60, creaking_center);

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), dot_60, 0.001);
    try std.testing.expect(dot_60 < fov_dot_threshold);
    try std.testing.expect(!isWithinFOV(player_eye, look_60, creaking_center));
}

test "computeGazeDotProduct looking perpendicular (90 deg) and away (180 deg)" {
    const player_eye = [3]f32{ 0.0, 0.0, 0.0 };
    const creaking_center = [3]f32{ 0.0, 0.0, 10.0 };

    // Perpendicular (90 degrees along +X): dot = 0.0
    const look_90 = [3]f32{ 1.0, 0.0, 0.0 };
    const dot_90 = computeGazeDotProduct(player_eye, look_90, creaking_center);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dot_90, 0.0001);
    try std.testing.expect(!isWithinFOV(player_eye, look_90, creaking_center));

    // Opposite (180 degrees along -Z): dot = -1.0
    const look_180 = [3]f32{ 0.0, 0.0, -1.0 };
    const dot_180 = computeGazeDotProduct(player_eye, look_180, creaking_center);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), dot_180, 0.0001);
    try std.testing.expect(!isWithinFOV(player_eye, look_180, creaking_center));
}

test "computeGazeDotProduct 3D vertical elevation look within 45 deg FOV" {
    const player_eye = [3]f32{ 0.0, 0.0, 0.0 };
    const creaking_center = [3]f32{ 0.0, 0.0, 10.0 }; // Target along +Z

    // Look tilted upward at 30 degrees: (0, sin(30°), cos(30°)) = (0, 0.5, 0.866025)
    const look_pitch_30 = [3]f32{ 0.0, 0.5, 0.866025 };
    const dot_30 = computeGazeDotProduct(player_eye, look_pitch_30, creaking_center);

    try std.testing.expectApproxEqAbs(@as(f32, 0.8660), dot_30, 0.001);
    try std.testing.expect(dot_30 >= fov_dot_threshold);
    try std.testing.expect(isWithinFOV(player_eye, look_pitch_30, creaking_center));
}

test "computeGazeDotProduct 3D vertical elevation look outside 45 deg FOV" {
    const player_eye = [3]f32{ 0.0, 0.0, 0.0 };
    const creaking_center = [3]f32{ 0.0, 0.0, 10.0 }; // Target along +Z

    // Look tilted upward at 60 degrees: (0, sin(60°), cos(60°)) = (0, 0.866025, 0.5)
    const look_pitch_60 = [3]f32{ 0.0, 0.866025, 0.5 };
    const dot_60 = computeGazeDotProduct(player_eye, look_pitch_60, creaking_center);

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), dot_60, 0.001);
    try std.testing.expect(dot_60 < fov_dot_threshold);
    try std.testing.expect(!isWithinFOV(player_eye, look_pitch_60, creaking_center));
}

test "hasLineOfSight clear path with no obstacles returns true" {
    const start = [3]f32{ 0.5, 1.5, 0.5 };
    const end = [3]f32{ 8.5, 1.5, 0.5 };

    // With null callback
    try std.testing.expect(hasLineOfSight(start, end, null));

    // With empty obstacles list
    try std.testing.expect(checkLineOfSightWithObstacles(start, end, &.{}));
}

test "hasLineOfSight solid opaque block directly between player and creaking obstructs" {
    const start = [3]f32{ 0.5, 1.5, 0.5 };
    const end = [3]f32{ 8.5, 1.5, 0.5 };

    // Block placed at x=4, y=1, z=0 (directly intersecting ray)
    const obstacles = [_][3]i32{.{ 4, 1, 0 }};
    const clear = checkLineOfSightWithObstacles(start, end, &obstacles);

    try std.testing.expect(!clear);
}

test "hasLineOfSight solid block offset to the side does not obstruct" {
    const start = [3]f32{ 0.5, 1.5, 0.5 };
    const end = [3]f32{ 8.5, 1.5, 0.5 };

    // Block placed off to the side at x=4, y=3, z=0 (above the ray) or z=2 (lateral)
    const obstacles = [_][3]i32{ .{ 4, 3, 0 }, .{ 4, 1, 2 } };
    const clear = checkLineOfSightWithObstacles(start, end, &obstacles);

    try std.testing.expect(clear);
}

test "hasLineOfSight multiple blocks along ray path obstruct" {
    const start = [3]f32{ 0.5, 1.5, 0.5 };
    const end = [3]f32{ 6.5, 1.5, 6.5 }; // Diagonal path

    // Solid block placed on diagonal at (3, 1, 3)
    const obstacles = [_][3]i32{.{ 3, 1, 3 }};
    try std.testing.expect(!checkLineOfSightWithObstacles(start, end, &obstacles));

    // Clear without that block
    const non_intersecting = [_][3]i32{.{ 0, 1, 5 }};
    try std.testing.expect(checkLineOfSightWithObstacles(start, end, &non_intersecting));
}

test "isPlayerGazingAtCreaking unobstructed direct look causes gaze freeze" {
    const player = PlayerView.init(1, .{ 0.5, 1.62, 0.5 }, .{ 0.0, 0.0, 1.0 });
    const creaking = CreakingAI.init(.{ 0.5, 0.0, 10.5 });
    const center = creaking.getCenterPos();

    const is_frozen = isPlayerGazingAtCreaking(player, center, null);
    try std.testing.expect(is_frozen);
}

test "isPlayerGazingAtCreaking solid opaque block releases gaze freeze" {
    const player = PlayerView.init(1, .{ 0.5, 1.62, 0.5 }, .{ 0.0, 0.0, 1.0 });
    const creaking = CreakingAI.init(.{ 0.5, 0.0, 10.5 });
    const center = creaking.getCenterPos();

    // With a wall at (0, 1, 5) blocking direct line of sight
    const wall = [_][3]i32{.{ 0, 1, 5 }};
    const Context = struct {
        fn isOpaque(x: i32, y: i32, z: i32) bool {
            return x == wall[0][0] and y == wall[0][1] and z == wall[0][2];
        }
    };

    const is_frozen = isPlayerGazingAtCreaking(player, center, Context.isOpaque);
    try std.testing.expect(!is_frozen); // Wall releases gaze freeze!
}

test "isPlayerGazingAtCreaking carved pumpkin bypasses gaze freeze" {
    var player = PlayerView.init(1, .{ 0.5, 1.62, 0.5 }, .{ 0.0, 0.0, 1.0 });
    player.wearing_carved_pumpkin = true;

    const creaking = CreakingAI.init(.{ 0.5, 0.0, 10.5 });
    const center = creaking.getCenterPos();

    // Wearing carved pumpkin bypasses gaze freeze completely!
    const is_frozen = isPlayerGazingAtCreaking(player, center, null);
    try std.testing.expect(!is_frozen);
}

test "evaluateCreakingGazeFreeze multiple players: any watching freezes creaking" {
    const creaking = CreakingAI.init(.{ 0.0, 0.0, 0.0 });
    const center = creaking.getCenterPos();

    // Player 1 looks away (-Z)
    const p1 = PlayerView.init(1, .{ 0.0, 1.6, 10.0 }, .{ 0.0, 0.0, 1.0 });
    // Player 2 looks directly at Creaking (+X towards origin)
    const p2 = PlayerView.init(2, .{ 10.0, 1.6, 0.0 }, .{ -1.0, 0.0, 0.0 });

    const players = [_]PlayerView{ p1, p2 };
    const frozen = evaluateCreakingGazeFreeze(center, &players, null);

    try std.testing.expect(frozen);
}

test "evaluateCreakingGazeFreeze multiple players: all looking away leaves unobserved" {
    const creaking = CreakingAI.init(.{ 0.0, 0.0, 0.0 });
    const center = creaking.getCenterPos();

    // Both players looking away from Creaking
    const p1 = PlayerView.init(1, .{ 0.0, 1.6, 10.0 }, .{ 0.0, 0.0, 1.0 });
    const p2 = PlayerView.init(2, .{ 10.0, 1.6, 0.0 }, .{ 1.0, 0.0, 0.0 });

    const players = [_]PlayerView{ p1, p2 };
    const frozen = evaluateCreakingGazeFreeze(center, &players, null);

    try std.testing.expect(!frozen);
}

test "CreakingAI freeze state enforcement zeroes velocity and disables attacks" {
    var creaking = CreakingAI.init(.{ 0.0, 0.0, 5.0 });
    // Set initial non-zero stalking velocity and attack readiness
    creaking.velocity = .{ 1.5, 0.0, 1.8 };
    creaking.can_attack = true;

    // Player stares directly at Creaking
    const player = PlayerView.init(1, .{ 0.0, 1.62, 0.0 }, .{ 0.0, 0.0, 1.0 });
    const players = [_]PlayerView{player};

    creaking.update(&players, 0.5, null);

    try std.testing.expect(creaking.is_frozen);
    try std.testing.expectEqual(@as(f32, 0.0), creaking.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), creaking.velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), creaking.velocity[2]);
    try std.testing.expect(!creaking.can_attack);
}

test "CreakingAI unobserved stalking pursuit moves towards player at 2.4 m/s" {
    var creaking = CreakingAI.init(.{ 0.0, 0.0, 0.0 });
    // Player is at (10, 0, 0) looking away (+X)
    const player = PlayerView.init(1, .{ 10.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    const players = [_]PlayerView{player};

    // 1.0 second timestep
    creaking.update(&players, 1.0, null);

    try std.testing.expect(!creaking.is_frozen);
    // Stalks along +X at 2.4 m/s
    try std.testing.expectApproxEqAbs(@as(f32, 2.4), creaking.velocity[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), creaking.velocity[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), creaking.velocity[2], 0.001);
    // Position advanced by 2.4m
    try std.testing.expectApproxEqAbs(@as(f32, 2.4), creaking.pos[0], 0.001);
}

test "CreakingAI stalking kinematics have 0 frequency acoustic emission and 0 vibration" {
    var creaking = CreakingAI.init(.{ 0.0, 0.0, 0.0 });
    const player = PlayerView.init(1, .{ 5.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    const players = [_]PlayerView{player};

    creaking.update(&players, 0.1, null);

    // Stalking movement is occurring
    try std.testing.expect(!creaking.is_frozen);
    try std.testing.expect(creaking.velocity[0] > 0.0);

    // Acoustic emission and vibration frequencies must be strictly 0!
    try std.testing.expectEqual(@as(f32, 0.0), creaking.acoustic_emission_freq);
    try std.testing.expectEqual(@as(u8, 0), creaking.vibration_frequency);
}

test "CreakingAI targets nearest player among multiple players" {
    var creaking = CreakingAI.init(.{ 0.0, 0.0, 0.0 });
    // Far player at (20, 0, 0) looking away
    const far_player = PlayerView.init(101, .{ 20.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    // Near player at (0, 0, 5) looking away
    const near_player = PlayerView.init(102, .{ 0.0, 0.0, 5.0 }, .{ 0.0, 0.0, 1.0 });

    const players = [_]PlayerView{ far_player, near_player };
    creaking.update(&players, 0.5, null);

    try std.testing.expect(!creaking.is_frozen);
    try std.testing.expectEqual(@as(?u32, 102), creaking.target_player_id);
    // Moving towards near player along +Z
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), creaking.velocity[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.4), creaking.velocity[2], 0.001);
}

test "evaluateEyeblossomState day/night cycle transitions (13000..23000)" {
    // Daytime noon (world_time = 6000, bright light = 15) -> closed
    try std.testing.expectEqual(EyeblossomState.closed, evaluateEyeblossomState(6000, 15));

    // Sunset / Dusk boundary (world_time = 12999, light = 10) -> closed
    try std.testing.expectEqual(EyeblossomState.closed, evaluateEyeblossomState(12999, 10));

    // Night start (world_time = 13000, light = 10) -> open
    try std.testing.expectEqual(EyeblossomState.open, evaluateEyeblossomState(13000, 10));

    // Midnight (world_time = 18000, light = 4) -> open
    try std.testing.expectEqual(EyeblossomState.open, evaluateEyeblossomState(18000, 4));

    // Night end boundary (world_time = 23000, light = 4) -> open
    try std.testing.expectEqual(EyeblossomState.open, evaluateEyeblossomState(23000, 4));

    // Dawn / Sunrise (world_time = 23001, light = 12) -> closed
    try std.testing.expectEqual(EyeblossomState.closed, evaluateEyeblossomState(23001, 12));

    // Subsequent day cycle (world_time = 37000: 37000 % 24000 = 13000) -> open
    try std.testing.expectEqual(EyeblossomState.open, evaluateEyeblossomState(37000, 10));
}

test "evaluateEyeblossomState low light level (<= 7) opens eyeblossom during daytime" {
    // Daytime noon (world_time = 6000), but placed in deep cave or dense canopy (light = 7)
    try std.testing.expectEqual(EyeblossomState.open, evaluateEyeblossomState(6000, 7));

    // Pitch black cave (light = 0)
    try std.testing.expectEqual(EyeblossomState.open, evaluateEyeblossomState(6000, 0));

    // Slightly higher light (light = 8) during daytime -> closed
    try std.testing.expectEqual(EyeblossomState.closed, evaluateEyeblossomState(6000, 8));
}

test "Eyeblossom night resonance emits orange particles and alerts nearby Creaking puppets" {
    const blossom = Eyeblossom.init(.{ 0, 64, 0 }, .open);
    const signal = blossom.getResonanceSignal();

    try std.testing.expectEqual(ResonanceParticle.orange_resonance, signal.particle);
    try std.testing.expect(signal.alerts_creaking);
    try std.testing.expect(!signal.suppresses_hostility);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), signal.particle_color_rgb[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.45), signal.particle_color_rgb[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), signal.particle_color_rgb[2], 0.01);

    var creakings = [_]CreakingAI{ CreakingAI.init(.{ 5.0, 64.0, 5.0 }) };

    const count = blossom.pulseResonance(&creakings);
    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expect(creakings[0].is_alerted);
    try std.testing.expect(!creakings[0].hostility_suppressed);
}

test "Eyeblossom day resonance emits muted grey particles and suppresses Creaking hostility" {
    const blossom = Eyeblossom.init(.{ 0, 64, 0 }, .closed);
    const signal = blossom.getResonanceSignal();

    try std.testing.expectEqual(ResonanceParticle.muted_grey, signal.particle);
    try std.testing.expect(!signal.alerts_creaking);
    try std.testing.expect(signal.suppresses_hostility);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), signal.particle_color_rgb[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), signal.particle_color_rgb[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), signal.particle_color_rgb[2], 0.01);

    var creakings = [_]CreakingAI{ CreakingAI.init(.{ 5.0, 64.0, 5.0 }) };
    creakings[0].is_alerted = true;
    creakings[0].velocity = .{ 2.0, 0.0, 2.0 };

    const count = blossom.pulseResonance(&creakings);
    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expect(!creakings[0].is_alerted);
    try std.testing.expect(creakings[0].hostility_suppressed);
    try std.testing.expectEqual(@as(f32, 0.0), creakings[0].velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), creakings[0].velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), creakings[0].velocity[2]);
    try std.testing.expect(!creakings[0].can_attack);
}

test "Eyeblossom resonance radius distance falloff leaves distant Creakings unaffected" {
    const blossom = Eyeblossom.init(.{ 0, 64, 0 }, .open);

    var creakings = [_]CreakingAI{
        CreakingAI.init(.{ 10.0, 64.0, 0.0 }), // 10m away (<= 16m)
        CreakingAI.init(.{ 25.0, 64.0, 0.0 }), // 25m away (> 16m)
    };

    const count = blossom.pulseResonance(&creakings);
    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expect(creakings[0].is_alerted); // near creaking alerted
    try std.testing.expect(!creakings[1].is_alerted); // far creaking unaffected
}

/// Creaking Heart tethering constants.
pub const creaking_max_tether_radius: f32 = 32.0;
pub const creaking_max_tether_radius_sq: f32 = creaking_max_tether_radius * creaking_max_tether_radius; // 1024.0

/// Checks if a position is within the Creaking's 32-block tether radius from its heart.
pub fn isWithinTetherRadius(creaking_pos: [3]f32, heart_pos: [3]i32) bool {
    const dx = creaking_pos[0] - @as(f32, @floatFromInt(heart_pos[0]));
    const dy = creaking_pos[1] - @as(f32, @floatFromInt(heart_pos[1]));
    const dz = creaking_pos[2] - @as(f32, @floatFromInt(heart_pos[2]));
    return (dx * dx + dy * dy + dz * dz) <= creaking_max_tether_radius_sq;
}

test "hasLineOfSight negative direction raycasting through voxels" {
    const start = [3]f32{ 8.5, 1.5, 0.5 };
    const end = [3]f32{ 0.5, 1.5, 0.5 };

    // Clear path along -X
    try std.testing.expect(checkLineOfSightWithObstacles(start, end, &.{}));

    // Obstacle at x=4 along -X path
    const obstacles = [_][3]i32{.{ 4, 1, 0 }};
    try std.testing.expect(!checkLineOfSightWithObstacles(start, end, &obstacles));
}

test "Creaking tether radius evaluation from heart position" {
    const heart_pos = [3]i32{ 100, 64, 100 };

    // Creaking 20 blocks away (within 32 blocks)
    const near_creaking = [3]f32{ 120.0, 64.0, 100.0 };
    try std.testing.expect(isWithinTetherRadius(near_creaking, heart_pos));

    // Creaking exactly 32 blocks away
    const max_creaking = [3]f32{ 132.0, 64.0, 100.0 };
    try std.testing.expect(isWithinTetherRadius(max_creaking, heart_pos));

    // Creaking 35 blocks away (exceeds 32 blocks tether)
    const far_creaking = [3]f32{ 135.0, 64.0, 100.0 };
    try std.testing.expect(!isWithinTetherRadius(far_creaking, heart_pos));
}
