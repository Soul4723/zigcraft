const std = @import("std");

// ============================================================================
// Constants & Mathematical Definitions
// ============================================================================

pub const PI: f32 = std.math.pi;
pub const TWO_PI: f32 = std.math.pi * 2.0;
pub const HALF_PI: f32 = std.math.pi / 2.0;
pub const EPSILON: f32 = 1e-5;

// ============================================================================
// Canonical Dimensions
// ============================================================================

/// Canonical Minecraft dimensions.
pub const Dimension = enum(u8) {
    overworld = 0,
    nether = 1,
    the_end = 2,

    pub fn name(self: Dimension) []const u8 {
        return switch (self) {
            .overworld => "Overworld",
            .nether => "Nether",
            .the_end => "The End",
        };
    }

    pub fn id(self: Dimension) u8 {
        return @intFromEnum(self);
    }
};

// ============================================================================
// Lodestone Binding
// ============================================================================

/// Stores the bound dimension and block coordinates for a Lodestone Compass.
pub const LodestoneBinding = struct {
    dimension: Dimension,
    target_pos: [3]i32,

    pub fn init(dimension: Dimension, target_pos: [3]i32) LodestoneBinding {
        return .{
            .dimension = dimension,
            .target_pos = target_pos,
        };
    }

    /// World-space target center coordinates (X+0.5, Y+0.5, Z+0.5).
    pub fn targetCenterX(self: LodestoneBinding) f32 {
        return @as(f32, @floatFromInt(self.target_pos[0])) + 0.5;
    }

    pub fn targetCenterY(self: LodestoneBinding) f32 {
        return @as(f32, @floatFromInt(self.target_pos[1])) + 0.5;
    }

    pub fn targetCenterZ(self: LodestoneBinding) f32 {
        return @as(f32, @floatFromInt(self.target_pos[2])) + 0.5;
    }

    /// Checks if a position matches this binding's coordinates.
    pub fn matchesPos(self: LodestoneBinding, pos: [3]i32) bool {
        return self.target_pos[0] == pos[0] and
            self.target_pos[1] == pos[1] and
            self.target_pos[2] == pos[2];
    }

    /// Checks if both dimension and coordinates match.
    pub fn matches(self: LodestoneBinding, dim: Dimension, pos: [3]i32) bool {
        return self.dimension == dim and self.matchesPos(pos);
    }
};

// ============================================================================
// Needle Reading & Visual Representation
// ============================================================================

/// Represents the instantaneous output state of a compass needle dial.
pub const NeedleReading = struct {
    /// Screen or player-relative needle angle in radians in range [-pi, pi].
    angle: f32,
    /// Whether the needle is wildly/erratically spinning.
    is_spinning: bool,
    /// Whether the compass has a confirmed lock on an intact lodestone in the same dimension.
    is_locked: bool,
    /// Enchanted visual glint (always true for Lodestone Compasses in Minecraft).
    has_glint: bool = true,
};

// ============================================================================
// Kinematics, Azimuth Math & Interpolation
// ============================================================================

/// Normalizes an angle into the canonical range [-pi, pi].
pub fn normalizeAngle(angle: f32) f32 {
    return std.math.atan2(@sin(angle), @cos(angle));
}

/// Computes the shortest angular difference from 'from' to 'to', in range [-pi, pi].
/// A positive value means rotating clockwise/positive; negative means counter-clockwise.
pub fn shortestAngleDiff(from: f32, to: f32) f32 {
    return normalizeAngle(to - from);
}

/// Calculates absolute target azimuth in radians from player (x, z) to target (x, z).
/// Coordinate convention (Minecraft world space):
/// North is -Z (azimuth = 0)
/// East is +X (azimuth = +pi/2)
/// South is +Z (azimuth = pi)
/// West is -X (azimuth = -pi/2)
pub fn calculateTargetAzimuth(player_x: f32, player_z: f32, target_x: f32, target_z: f32) f32 {
    const dx = target_x - player_x;
    const dz = target_z - player_z;
    if (@abs(dx) < EPSILON and @abs(dz) < EPSILON) {
        return 0.0;
    }
    // atan2(dx, -dz):
    // dx = 0, -dz > 0 (North): atan2(0, positive) = 0
    // dx > 0, -dz = 0 (East):  atan2(positive, 0) = pi/2
    // dx = 0, -dz < 0 (South): atan2(0, negative) = pi
    // dx < 0, -dz = 0 (West):  atan2(negative, 0) = -pi/2
    return std.math.atan2(dx, -dz);
}

/// Calculates relative angle to target given player's heading yaw (where 0 = North, pi/2 = East).
/// Returns angle in [-pi, pi], where 0 is straight ahead, +pi/2 is 90° right, -pi/2 is 90° left.
pub fn calculateRelativeAzimuth(target_azimuth: f32, player_yaw: f32) f32 {
    return normalizeAngle(target_azimuth - player_yaw);
}

/// Helper that converts camera yaw (where default is -pi/2 facing -Z North) into heading yaw (where 0 is North).
pub fn cameraYawToHeading(cam_yaw: f32) f32 {
    return normalizeAngle(cam_yaw + HALF_PI);
}

/// Calculates needle azimuth angle from player position to target relative to player heading yaw.
pub fn calculateNeedleAzimuth(
    player_x: f32,
    player_z: f32,
    target_x: f32,
    target_z: f32,
    player_yaw: f32,
) f32 {
    const azimuth = calculateTargetAzimuth(player_x, player_z, target_x, target_z);
    return calculateRelativeAzimuth(azimuth, player_yaw);
}

/// Calculates screen-relative compass needle angle from camera yaw.
pub fn calculateNeedleAngleCamera(
    target_x: f32,
    target_z: f32,
    player_x: f32,
    player_z: f32,
    cam_yaw: f32,
) f32 {
    const heading = cameraYawToHeading(cam_yaw);
    return calculateNeedleAzimuth(player_x, player_z, target_x, target_z, heading);
}

/// Smoothly interpolates an angle from `current` toward `target` taking the shortest path around the circle.
/// `step_fraction` is in [0.0, 1.0].
pub fn interpolateAngle(current: f32, target: f32, step_fraction: f32) f32 {
    const diff = shortestAngleDiff(current, target);
    const clamped_frac = std.math.clamp(step_fraction, 0.0, 1.0);
    return normalizeAngle(current + diff * clamped_frac);
}

/// Smoothly advances rotation with exponential decay over delta time.
pub fn smoothTurnNeedle(current: f32, target: f32, dt: f32, turn_speed: f32) f32 {
    const diff = shortestAngleDiff(current, target);
    const factor = 1.0 - @exp(-turn_speed * dt);
    return normalizeAngle(current + diff * std.math.clamp(factor, 0.0, 1.0));
}

/// Computes erratic rapid spin angle when compass is in a different dimension or unbound.
pub fn calculateErraticSpinAngle(world_time: f32, player_yaw: f32) f32 {
    // Multi-harmonic high-frequency wobble and rapid rotation
    const base_spin = world_time * 16.0;
    const wobble1 = @sin(world_time * 6.28) * 2.4;
    const wobble2 = @cos(world_time * 14.1) * 1.5;
    const wobble3 = @sin(world_time * 29.3) * 0.8;
    return normalizeAngle(base_spin + wobble1 + wobble2 + wobble3 - player_yaw);
}

// ============================================================================
// Physical Needle Kinematics (Spring-Damper Simulation)
// ============================================================================

/// Models the physical rotational kinematics of a jeweled compass needle with inertia and damping.
pub const NeedleKinematics = struct {
    angle: f32 = 0.0,
    velocity: f32 = 0.0,
    spring_k: f32 = 36.0,
    damping: f32 = 6.5,

    pub fn update(self: *NeedleKinematics, target_angle: f32, dt: f32) void {
        const diff = shortestAngleDiff(self.angle, target_angle);
        const accel = diff * self.spring_k - self.velocity * self.damping;
        self.velocity += accel * dt;
        self.velocity = std.math.clamp(self.velocity, -60.0, 60.0);
        self.angle = normalizeAngle(self.angle + self.velocity * dt);
    }

    pub fn setAngleImmediate(self: *NeedleKinematics, target_angle: f32) void {
        self.angle = normalizeAngle(target_angle);
        self.velocity = 0.0;
    }
};

// ============================================================================
// Lodestone Compass
// ============================================================================

/// A compass bound to a Lodestone block.
pub const LodestoneCompass = struct {
    /// The dimension and coordinate binding.
    binding: LodestoneBinding,
    /// Whether the lodestone target block is currently intact and valid.
    is_locked: bool = true,
    /// Current smoothed needle angle in radians.
    current_needle_angle: f32 = 0.0,
    /// Rotational turn rate speed.
    smoothing_speed: f32 = 12.0,
    /// Physical damped-spring kinematics.
    kinematics: NeedleKinematics = .{},

    /// Creates a newly bound LodestoneCompass with confirmed lock.
    pub fn init(dimension: Dimension, target_pos: [3]i32) LodestoneCompass {
        return .{
            .binding = LodestoneBinding.init(dimension, target_pos),
            .is_locked = true,
            .current_needle_angle = 0.0,
            .smoothing_speed = 12.0,
            .kinematics = .{},
        };
    }

    pub fn targetCenterX(self: LodestoneCompass) f32 {
        return self.binding.targetCenterX();
    }

    pub fn targetCenterY(self: LodestoneCompass) f32 {
        return self.binding.targetCenterY();
    }

    pub fn targetCenterZ(self: LodestoneCompass) f32 {
        return self.binding.targetCenterZ();
    }

    /// Lodestone compasses always emit an enchanted purple-cyan glint in Minecraft.
    pub fn hasGlint(self: LodestoneCompass) bool {
        _ = self;
        return true;
    }

    /// Returns true if the player is in a different dimension than the lodestone.
    pub fn isInterdimensional(self: LodestoneCompass, current_dimension: Dimension) bool {
        return self.binding.dimension != current_dimension;
    }

    /// Returns true if the compass maintains a valid tracking lock.
    pub fn hasTargetLock(self: LodestoneCompass, current_dimension: Dimension) bool {
        return self.is_locked and !self.isInterdimensional(current_dimension);
    }

    /// Returns true if the needle should spin rapidly and erratically.
    pub fn shouldSpin(self: LodestoneCompass, current_dimension: Dimension) bool {
        return !self.hasTargetLock(current_dimension);
    }

    /// Invalidates the lodestone lock (e.g. block broken or replaced).
    pub fn invalidateLock(self: *LodestoneCompass) void {
        self.is_locked = false;
    }

    /// Re-binds this compass to a new lodestone block.
    pub fn rebind(self: *LodestoneCompass, dimension: Dimension, target_pos: [3]i32) void {
        self.binding = LodestoneBinding.init(dimension, target_pos);
        self.is_locked = true;
    }

    /// Callback when a block in the world is broken. If it matches target pos and dimension, lock is lost.
    pub fn onBlockBroken(self: *LodestoneCompass, dimension: Dimension, pos: [3]i32) bool {
        if (self.binding.matches(dimension, pos)) {
            self.invalidateLock();
            return true;
        }
        return false;
    }

    /// Callback when a block is replaced. If target is no longer a lodestone, lock is lost.
    pub fn onBlockReplaced(self: *LodestoneCompass, dimension: Dimension, pos: [3]i32, is_still_lodestone: bool) void {
        if (self.binding.matches(dimension, pos) and !is_still_lodestone) {
            self.invalidateLock();
        }
    }

    /// Directly checks whether the target block is still a lodestone.
    pub fn checkBlockState(self: *LodestoneCompass, is_lodestone: bool) void {
        if (!is_lodestone) {
            self.invalidateLock();
        }
    }

    /// Computes absolute target azimuth from player position to lodestone target.
    pub fn getTargetAzimuth(self: LodestoneCompass, player_x: f32, player_z: f32) f32 {
        return calculateTargetAzimuth(player_x, player_z, self.targetCenterX(), self.targetCenterZ());
    }

    /// Computes relative needle angle to target given player's heading yaw.
    pub fn getRelativeAzimuth(self: LodestoneCompass, player_x: f32, player_z: f32, player_yaw: f32) f32 {
        const azimuth = self.getTargetAzimuth(player_x, player_z);
        return calculateRelativeAzimuth(azimuth, player_yaw);
    }

    /// Evaluates current needle reading.
    pub fn calculateReading(
        self: LodestoneCompass,
        player_x: f32,
        player_z: f32,
        player_yaw: f32,
        current_dimension: Dimension,
        world_time: f32,
    ) NeedleReading {
        if (self.shouldSpin(current_dimension)) {
            return .{
                .angle = calculateErraticSpinAngle(world_time, player_yaw),
                .is_spinning = true,
                .is_locked = false,
                .has_glint = true,
            };
        }

        const angle = self.getRelativeAzimuth(player_x, player_z, player_yaw);
        return .{
            .angle = angle,
            .is_spinning = false,
            .is_locked = true,
            .has_glint = true,
        };
    }

    /// Updates smoothed kinematics needle angle over delta time `dt`.
    pub fn update(
        self: *LodestoneCompass,
        dt: f32,
        player_x: f32,
        player_z: f32,
        player_yaw: f32,
        current_dimension: Dimension,
        world_time: f32,
    ) void {
        if (self.shouldSpin(current_dimension)) {
            const target_spin = calculateErraticSpinAngle(world_time, player_yaw);
            self.current_needle_angle = target_spin;
            self.kinematics.setAngleImmediate(target_spin);
            return;
        }

        const target_angle = self.getRelativeAzimuth(player_x, player_z, player_yaw);
        self.current_needle_angle = smoothTurnNeedle(self.current_needle_angle, target_angle, dt, self.smoothing_speed);
        self.kinematics.update(target_angle, dt);
    }
};

// ============================================================================
// Block Interaction & Compass Conversion
// ============================================================================

/// Manages interaction logic when right-clicking blocks with a compass.
pub const LodestoneInteraction = struct {
    /// Right-clicking a Lodestone block with a regular Compass converts it into a Lodestone Compass.
    pub fn rightClickBlock(
        held_is_compass: bool,
        target_is_lodestone: bool,
        dimension: Dimension,
        pos: [3]i32,
    ) ?LodestoneCompass {
        if (!held_is_compass or !target_is_lodestone) return null;
        return LodestoneCompass.init(dimension, pos);
    }
};

/// Binds a regular Compass to a Lodestone at the given coordinates and dimension.
pub fn bindCompass(dimension: Dimension, target_pos: [3]i32) LodestoneCompass {
    return LodestoneCompass.init(dimension, target_pos);
}

/// Right-clicking a Lodestone block with a Compass converts it into a Lodestone Compass.
pub fn rightClickToBind(
    held_is_compass: bool,
    target_is_lodestone: bool,
    dimension: Dimension,
    target_pos: [3]i32,
) ?LodestoneCompass {
    return LodestoneInteraction.rightClickBlock(held_is_compass, target_is_lodestone, dimension, target_pos);
}

// ============================================================================
// Multi-Compass Tracker
// ============================================================================

/// Tracks multiple lodestone compasses and routes block break / world events to invalidate locks.
pub const LodestoneCompassTracker = struct {
    pub const MAX_COMPASSES: usize = 36;
    compasses: [MAX_COMPASSES]?LodestoneCompass = [_]?LodestoneCompass{null} ** MAX_COMPASSES,

    pub fn init() LodestoneCompassTracker {
        return .{};
    }

    /// Registers a compass to be tracked.
    pub fn registerCompass(self: *LodestoneCompassTracker, compass: LodestoneCompass) ?usize {
        for (&self.compasses, 0..) |*slot, idx| {
            if (slot.* == null) {
                slot.* = compass;
                return idx;
            }
        }
        return null;
    }

    /// Removes a tracked compass.
    pub fn removeCompass(self: *LodestoneCompassTracker, idx: usize) bool {
        if (idx < MAX_COMPASSES and self.compasses[idx] != null) {
            self.compasses[idx] = null;
            return true;
        }
        return false;
    }

    /// Broadcasts a block broken event across all tracked compasses.
    /// Returns the number of compasses whose lock was invalidated.
    pub fn notifyBlockBroken(self: *LodestoneCompassTracker, dimension: Dimension, pos: [3]i32) usize {
        var invalidated_count: usize = 0;
        for (&self.compasses) |*slot| {
            if (slot.*) |*c| {
                if (c.onBlockBroken(dimension, pos)) {
                    invalidated_count += 1;
                }
            }
        }
        return invalidated_count;
    }

    /// Updates all tracked compasses.
    pub fn updateAll(
        self: *LodestoneCompassTracker,
        dt: f32,
        player_x: f32,
        player_z: f32,
        player_yaw: f32,
        current_dimension: Dimension,
        world_time: f32,
    ) void {
        for (&self.compasses) |*slot| {
            if (slot.*) |*c| {
                c.update(dt, player_x, player_z, player_yaw, current_dimension, world_time);
            }
        }
    }
};

// ============================================================================
// Unit Tests (Requirements 1-5)
// ============================================================================

test "1. LodestoneBinding initialization and center coordinates" {
    const binding = LodestoneBinding.init(.overworld, .{ 10, 64, -20 });
    try std.testing.expectEqual(Dimension.overworld, binding.dimension);
    try std.testing.expectEqual([3]i32{ 10, 64, -20 }, binding.target_pos);
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), binding.targetCenterX(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.5), binding.targetCenterY(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -19.5), binding.targetCenterZ(), 0.001);
}

test "2. Compass binding to lodestone in Overworld sets target and lock" {
    const compass = bindCompass(.overworld, .{ 150, 70, -300 });
    try std.testing.expectEqual(Dimension.overworld, compass.binding.dimension);
    try std.testing.expectEqual([3]i32{ 150, 70, -300 }, compass.binding.target_pos);
    try std.testing.expect(compass.is_locked);
    try std.testing.expect(compass.hasGlint());
    try std.testing.expect(!compass.isInterdimensional(.overworld));
    try std.testing.expect(compass.hasTargetLock(.overworld));
    try std.testing.expect(!compass.shouldSpin(.overworld));
}

test "3. Compass binding to lodestone in Nether and The End" {
    const nether_compass = bindCompass(.nether, .{ 25, 48, 80 });
    try std.testing.expectEqual(Dimension.nether, nether_compass.binding.dimension);
    try std.testing.expect(nether_compass.hasTargetLock(.nether));
    try std.testing.expect(nether_compass.shouldSpin(.overworld));

    const end_compass = bindCompass(.the_end, .{ 0, 60, 0 });
    try std.testing.expectEqual(Dimension.the_end, end_compass.binding.dimension);
    try std.testing.expect(end_compass.hasTargetLock(.the_end));
    try std.testing.expect(end_compass.shouldSpin(.nether));
}

test "4. Right-click block interaction converts compass to lodestone compass" {
    const bound = rightClickToBind(true, true, .overworld, .{ 40, 65, 80 });
    try std.testing.expect(bound != null);
    try std.testing.expectEqual(Dimension.overworld, bound.?.binding.dimension);
    try std.testing.expectEqual([3]i32{ 40, 65, 80 }, bound.?.binding.target_pos);
    try std.testing.expect(bound.?.is_locked);
}

test "5. Right-click fails if held item is not compass or block is not lodestone" {
    // Held item is not compass
    const fail_held = rightClickToBind(false, true, .overworld, .{ 10, 64, 10 });
    try std.testing.expect(fail_held == null);

    // Block is not lodestone
    const fail_block = rightClickToBind(true, false, .overworld, .{ 10, 64, 10 });
    try std.testing.expect(fail_block == null);

    // Neither is valid
    const fail_both = rightClickToBind(false, false, .overworld, .{ 10, 64, 10 });
    try std.testing.expect(fail_both == null);
}

test "6. Cardinal direction target azimuth: North, East, South, West" {
    const player_x: f32 = 0.0;
    const player_z: f32 = 0.0;

    // North (-Z): azimuth should be 0.0
    const north_azimuth = calculateTargetAzimuth(player_x, player_z, 0.0, -10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), north_azimuth, 0.001);

    // East (+X): azimuth should be +pi/2
    const east_azimuth = calculateTargetAzimuth(player_x, player_z, 10.0, 0.0);
    try std.testing.expectApproxEqAbs(HALF_PI, east_azimuth, 0.001);

    // South (+Z): azimuth should be +/- pi
    const south_azimuth = calculateTargetAzimuth(player_x, player_z, 0.0, 10.0);
    try std.testing.expectApproxEqAbs(PI, @abs(south_azimuth), 0.001);

    // West (-X): azimuth should be -pi/2
    const west_azimuth = calculateTargetAzimuth(player_x, player_z, -10.0, 0.0);
    try std.testing.expectApproxEqAbs(-HALF_PI, west_azimuth, 0.001);
}

test "7. Ordinal direction target azimuth: NE, SE, SW, NW" {
    const px: f32 = 0.0;
    const pz: f32 = 0.0;

    // Northeast (+X, -Z): +pi/4 (45°)
    const ne_azimuth = calculateTargetAzimuth(px, pz, 10.0, -10.0);
    try std.testing.expectApproxEqAbs(PI / 4.0, ne_azimuth, 0.001);

    // Southeast (+X, +Z): +3*pi/4 (135°)
    const se_azimuth = calculateTargetAzimuth(px, pz, 10.0, 10.0);
    try std.testing.expectApproxEqAbs(3.0 * PI / 4.0, se_azimuth, 0.001);

    // Southwest (-X, +Z): -3*pi/4 (-135°)
    const sw_azimuth = calculateTargetAzimuth(px, pz, -10.0, 10.0);
    try std.testing.expectApproxEqAbs(-3.0 * PI / 4.0, sw_azimuth, 0.001);

    // Northwest (-X, -Z): -pi/4 (-45°)
    const nw_azimuth = calculateTargetAzimuth(px, pz, -10.0, -10.0);
    try std.testing.expectApproxEqAbs(-PI / 4.0, nw_azimuth, 0.001);
}

test "8. Target azimuth with player at identical coordinates as target" {
    // When player is directly on the lodestone center, azimuth returns 0.0 without NaN
    const azimuth = calculateTargetAzimuth(5.0, 5.0, 5.0, 5.0);
    try std.testing.expect(!std.math.isNan(azimuth));
    try std.testing.expectEqual(@as(f32, 0.0), azimuth);
}

test "9. Relative needle azimuth with player facing North (yaw = 0)" {
    const px: f32 = 0.0;
    const pz: f32 = 0.0;
    const player_yaw: f32 = 0.0; // Facing North

    // Target North -> straight ahead (0 rad)
    const rel_north = calculateNeedleAzimuth(px, pz, 0.0, -20.0, player_yaw);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), rel_north, 0.001);

    // Target East -> 90° right (+pi/2 rad)
    const rel_east = calculateNeedleAzimuth(px, pz, 20.0, 0.0, player_yaw);
    try std.testing.expectApproxEqAbs(HALF_PI, rel_east, 0.001);

    // Target South -> 180° behind (+/- pi rad)
    const rel_south = calculateNeedleAzimuth(px, pz, 0.0, 20.0, player_yaw);
    try std.testing.expectApproxEqAbs(PI, @abs(rel_south), 0.001);

    // Target West -> 90° left (-pi/2 rad)
    const rel_west = calculateNeedleAzimuth(px, pz, -20.0, 0.0, player_yaw);
    try std.testing.expectApproxEqAbs(-HALF_PI, rel_west, 0.001);
}

test "10. Relative needle azimuth with player facing East (yaw = pi/2)" {
    const px: f32 = 0.0;
    const pz: f32 = 0.0;
    const player_yaw: f32 = HALF_PI; // Facing East

    // Target East -> straight ahead (0 rad)
    const rel_east = calculateNeedleAzimuth(px, pz, 20.0, 0.0, player_yaw);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), rel_east, 0.001);

    // Target North -> 90° left (-pi/2 rad)
    const rel_north = calculateNeedleAzimuth(px, pz, 0.0, -20.0, player_yaw);
    try std.testing.expectApproxEqAbs(-HALF_PI, rel_north, 0.001);

    // Target South -> 90° right (+pi/2 rad)
    const rel_south = calculateNeedleAzimuth(px, pz, 0.0, 20.0, player_yaw);
    try std.testing.expectApproxEqAbs(HALF_PI, rel_south, 0.001);

    // Target West -> behind (+/- pi rad)
    const rel_west = calculateNeedleAzimuth(px, pz, -20.0, 0.0, player_yaw);
    try std.testing.expectApproxEqAbs(PI, @abs(rel_west), 0.001);
}

test "11. Relative needle azimuth with player facing West (yaw = -pi/2)" {
    const px: f32 = 0.0;
    const pz: f32 = 0.0;
    const player_yaw: f32 = -HALF_PI; // Facing West

    // Target West -> straight ahead (0 rad)
    const rel_west = calculateNeedleAzimuth(px, pz, -20.0, 0.0, player_yaw);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), rel_west, 0.001);

    // Target North -> 90° right (+pi/2 rad)
    const rel_north = calculateNeedleAzimuth(px, pz, 0.0, -20.0, player_yaw);
    try std.testing.expectApproxEqAbs(HALF_PI, rel_north, 0.001);
}

test "12. Relative needle azimuth wraps cleanly across +/- pi boundary" {
    // When player yaw is near -pi and target is near +pi
    const target_azimuth: f32 = 3.10;
    const player_yaw: f32 = -3.10;
    // Difference is 6.20, which is shortest around the circle at -(2*pi - 6.20) = -0.08318...
    const rel = calculateRelativeAzimuth(target_azimuth, player_yaw);
    try std.testing.expect(rel < 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, -0.0831853), rel, 0.002);
}

test "13. Camera yaw to heading conversion matches 3D camera front vector" {
    // Default Camera: cam_yaw = -pi/2 faces -Z (North) -> heading should be 0.0
    const heading_north = cameraYawToHeading(-HALF_PI);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), heading_north, 0.001);

    // cam_yaw = 0 faces +X (East) -> heading should be +pi/2
    const heading_east = cameraYawToHeading(0.0);
    try std.testing.expectApproxEqAbs(HALF_PI, heading_east, 0.001);

    // cam_yaw = pi/2 faces +Z (South) -> heading should be +/- pi
    const heading_south = cameraYawToHeading(HALF_PI);
    try std.testing.expectApproxEqAbs(PI, @abs(heading_south), 0.001);
}

test "14. Shortest angle difference picks minimal rotational arc" {
    // Standard difference within [-pi, pi]
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), shortestAngleDiff(0.0, 0.5), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), shortestAngleDiff(0.5, 0.0), 0.001);

    // Across the +/- pi boundary: from 3.1 to -3.1
    // Shortest path is +0.083 rad, NOT -6.20 rad!
    const wrap_diff = shortestAngleDiff(3.1, -3.1);
    try std.testing.expect(wrap_diff > 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0831853), wrap_diff, 0.002);
}

test "15. Smooth rotation interpolation moves needle towards target" {
    const current: f32 = 0.0;
    const target: f32 = HALF_PI;

    // Halfway interpolation
    const mid = interpolateAngle(current, target, 0.5);
    try std.testing.expectApproxEqAbs(PI / 4.0, mid, 0.001);

    // Small fraction step
    const step = interpolateAngle(current, target, 0.2);
    try std.testing.expectApproxEqAbs(HALF_PI * 0.2, step, 0.001);
}

test "16. Smooth rotation interpolation handles boundary wrap-around correctly" {
    // Current at 3.10 rad, target at -3.10 rad
    const current: f32 = 3.10;
    const target: f32 = -3.10;

    // Moving halfway along the shortest path advances through +/- pi seam
    const halfway = interpolateAngle(current, target, 0.5);
    try std.testing.expectApproxEqAbs(PI, @abs(halfway), 0.01);
}

test "17. Smooth turn needle convergence over multiple ticks" {
    var angle: f32 = 0.0;
    const target: f32 = 1.5;
    const dt: f32 = 0.05;
    const speed: f32 = 10.0;

    // Step 20 times (1 second total)
    var step: usize = 0;
    while (step < 20) : (step += 1) {
        angle = smoothTurnNeedle(angle, target, dt, speed);
    }

    // Should be converged within 0.01 of target
    try std.testing.expectApproxEqAbs(target, angle, 0.01);
}

test "18. Physical NeedleKinematics spring-damper converges to target azimuth" {
    var k = NeedleKinematics{ .angle = 0.0, .velocity = 0.0 };
    const target: f32 = 1.2;
    const dt: f32 = 0.016; // 60 FPS tick

    // Simulate 1.5 seconds (90 ticks)
    var i: usize = 0;
    while (i < 90) : (i += 1) {
        k.update(target, dt);
    }

    // Needle settles near target angle
    try std.testing.expectApproxEqAbs(target, k.angle, 0.05);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), k.velocity, 0.5);
}

test "19. Interdimensional spin: Overworld compass in Nether spins rapidly without lock" {
    const compass = bindCompass(.overworld, .{ 100, 64, -200 });

    try std.testing.expect(compass.isInterdimensional(.nether));
    try std.testing.expect(!compass.hasTargetLock(.nether));
    try std.testing.expect(compass.shouldSpin(.nether));

    const reading = compass.calculateReading(100.0, -200.0, 0.0, .nether, 1.5);
    try std.testing.expect(reading.is_spinning);
    try std.testing.expect(!reading.is_locked);
    try std.testing.expect(reading.has_glint);
}

test "20. Interdimensional spin: Overworld compass in The End spins rapidly without lock" {
    const compass = bindCompass(.overworld, .{ 0, 70, 0 });

    try std.testing.expect(compass.isInterdimensional(.the_end));
    try std.testing.expect(!compass.hasTargetLock(.the_end));
    try std.testing.expect(compass.shouldSpin(.the_end));

    const reading = compass.calculateReading(0.0, 0.0, 0.0, .the_end, 2.0);
    try std.testing.expect(reading.is_spinning);
    try std.testing.expect(!reading.is_locked);
}

test "21. Interdimensional spin: Nether compass in Overworld or End spins erratically" {
    const nether_compass = bindCompass(.nether, .{ 50, 40, 50 });

    try std.testing.expect(nether_compass.shouldSpin(.overworld));
    try std.testing.expect(nether_compass.shouldSpin(.the_end));
    try std.testing.expect(!nether_compass.shouldSpin(.nether));
}

test "22. Erratic spin angle varies continuously with time and does not freeze" {
    const spin_t0 = calculateErraticSpinAngle(0.0, 0.0);
    const spin_t1 = calculateErraticSpinAngle(0.2, 0.0);
    const spin_t2 = calculateErraticSpinAngle(0.5, 0.0);

    // Different times must produce different spin angles
    try std.testing.expect(spin_t0 != spin_t1);
    try std.testing.expect(spin_t1 != spin_t2);
}

test "23. Target block destruction invalidates compass lock (is_locked = false)" {
    var compass = bindCompass(.overworld, .{ 45, 64, 90 });
    try std.testing.expect(compass.is_locked);

    // Break the bound block
    const invalidated = compass.onBlockBroken(.overworld, .{ 45, 64, 90 });
    try std.testing.expect(invalidated);
    try std.testing.expect(!compass.is_locked);
}

test "24. Destroyed lodestone enters random spin state even when player in same dimension" {
    var compass = bindCompass(.overworld, .{ 10, 64, 10 });
    compass.invalidateLock();

    try std.testing.expect(!compass.is_locked);
    // Even though player is in Overworld right next to the former block, compass spins
    try std.testing.expect(compass.shouldSpin(.overworld));

    const reading = compass.calculateReading(10.0, 10.0, 0.0, .overworld, 1.0);
    try std.testing.expect(reading.is_spinning);
    try std.testing.expect(!reading.is_locked);
    try std.testing.expect(reading.has_glint);
}

test "25. Breaking unrelated block coordinate does not invalidate lock" {
    var compass = bindCompass(.overworld, .{ 100, 64, 200 });

    // Break adjacent or unrelated block
    const invalidated = compass.onBlockBroken(.overworld, .{ 101, 64, 200 });
    try std.testing.expect(!invalidated);
    try std.testing.expect(compass.is_locked);
    try std.testing.expect(compass.hasTargetLock(.overworld));
}

test "26. Breaking block in different dimension with same coordinate does not invalidate lock" {
    var compass = bindCompass(.overworld, .{ 100, 64, 200 });

    // Break block at same (x, y, z) but in the Nether
    const invalidated = compass.onBlockBroken(.nether, .{ 100, 64, 200 });
    try std.testing.expect(!invalidated);
    try std.testing.expect(compass.is_locked);
}

test "27. Replacing lodestone block with air or non-lodestone block invalidates lock" {
    var compass = bindCompass(.nether, .{ 30, 50, -40 });

    // Replaced with air / non-lodestone
    compass.onBlockReplaced(.nether, .{ 30, 50, -40 }, false);
    try std.testing.expect(!compass.is_locked);
    try std.testing.expect(compass.shouldSpin(.nether));
}

test "28. Lodestone compass retains enchanted glint in all states" {
    var compass = bindCompass(.overworld, .{ 0, 64, 0 });
    try std.testing.expect(compass.hasGlint());

    // Glint remains true when interdimensional
    const reading_nether = compass.calculateReading(0.0, 0.0, 0.0, .nether, 1.0);
    try std.testing.expect(reading_nether.has_glint);

    // Glint remains true when broken/unlocked
    compass.invalidateLock();
    const reading_broken = compass.calculateReading(0.0, 0.0, 0.0, .overworld, 2.0);
    try std.testing.expect(reading_broken.has_glint);
}

test "29. Compass update method smoothly interpolates towards target azimuth when locked" {
    var compass = bindCompass(.overworld, .{ 0, 64, -50 }); // Target North
    compass.current_needle_angle = HALF_PI; // Initially pointing East (90° off)

    // Player at (0, 0), facing North (yaw = 0). Target azimuth is 0.0.
    const dt: f32 = 0.05;
    var step: usize = 0;
    while (step < 20) : (step += 1) {
        compass.update(dt, 0.0, 0.0, 0.0, .overworld, 1.0);
    }

    // Needle smoothly turns from +pi/2 toward 0.0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), compass.current_needle_angle, 0.05);
}

test "30. LodestoneCompassTracker broadcasts block destruction to multiple compasses" {
    var tracker = LodestoneCompassTracker.init();

    const c1 = bindCompass(.overworld, .{ 10, 64, 10 });
    const c2 = bindCompass(.overworld, .{ 20, 64, 20 });
    const c3 = bindCompass(.nether, .{ 10, 64, 10 });

    _ = tracker.registerCompass(c1);
    _ = tracker.registerCompass(c2);
    _ = tracker.registerCompass(c3);

    // Break block at (10, 64, 10) in Overworld
    const invalidated = tracker.notifyBlockBroken(.overworld, .{ 10, 64, 10 });
    // Only c1 should be invalidated (c2 has different pos, c3 has different dimension)
    try std.testing.expectEqual(@as(usize, 1), invalidated);

    try std.testing.expect(!tracker.compasses[0].?.is_locked);
    try std.testing.expect(tracker.compasses[1].?.is_locked);
    try std.testing.expect(tracker.compasses[2].?.is_locked);
}
