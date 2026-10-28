const std = @import("std");

// ============================================================================
// Milestone 435: Swift Sneak Crouch Kinematics & Sonic Dampening
// ============================================================================
// Swift Sneak is an enchantment exclusive to leggings found in Ancient Cities.
// 1. Movement Speed:
//    - Base sneaking speed is 30% of normal walking speed (0.30).
//    - Swift Sneak on leggings increases crouching speed:
//      crouch_speed = @min(1.0, 0.30 + 0.15 * @as(f32, @floatFromInt(level)))
//      Level 1: 0.45, Level 2: 0.60, Level 3: 0.75.
//    - Clamped at 1.0 (100% of normal walking speed).
//    - Walking without sneaking is unaffected (1.0).
// 2. Sculk Acoustic Vibration Suppression:
//    - Sneaking with Swift Sneak completely dampens footstep acoustic vibration
//      (vibration frequency = 0, no sound emitted to Sculk Sensors / Warden).
// 3. Ledge Safety & Mechanics:
//    - Crouch prevents walking off solid block edges even when moving at 75%
//      speed under Level 3 (or higher).
//    - Slot validation: Swift Sneak is strictly exclusive to leggings.
// ============================================================================

// ============================================================================
// Constants
// ============================================================================

/// Base sneaking / crouching movement speed as a fraction of normal walking speed (30%).
pub const BASE_CROUCH_SPEED: f32 = 0.30;

/// Swift Sneak speed bonus per enchantment level (15%).
pub const SPEED_BONUS_PER_LEVEL: f32 = 0.15;

/// Maximum crouching speed cap (100% of normal walking speed).
pub const MAX_CROUCH_SPEED: f32 = 1.00;

/// Normal walking speed factor (100%).
pub const NORMAL_WALK_SPEED: f32 = 1.00;

/// Maximum natural survival tier for Swift Sneak (Level III).
pub const MAX_NATURAL_LEVEL: u8 = 3;

/// Minimum enchantment tier.
pub const MIN_LEVEL: u8 = 0;

/// Canonical Minecraft acoustic vibration frequency for footstep events (Frequency 3).
pub const FOOTSTEP_VIBRATION_FREQ: u8 = 3;

/// Completely dampened acoustic vibration frequency produced while crouching (Frequency 0).
pub const DAMPENED_VIBRATION_FREQ: u8 = 0;

/// Default player collision bounding box horizontal radius in blocks (0.3m).
pub const DEFAULT_PLAYER_RADIUS: f32 = 0.3;

/// Player height while crouching / sneaking in blocks (1.5m).
pub const SNEAK_PLAYER_HEIGHT: f32 = 1.5;

/// Player standing height in blocks (1.8m).
pub const STANDING_PLAYER_HEIGHT: f32 = 1.8;

// ============================================================================
// Armor & Equipment Slots
// ============================================================================

/// Canonical Minecraft 4-piece armor slot classification.
pub const ArmorSlot = enum {
    helmet,
    chestplate,
    leggings,
    boots,

    pub fn isLeggings(self: ArmorSlot) bool {
        return self == .leggings;
    }

    pub fn allowsSwiftSneak(self: ArmorSlot) bool {
        return self == .leggings;
    }
};

/// General entity equipment slots including hands.
pub const EquipmentSlot = enum {
    head,
    chest,
    legs,
    feet,
    mainhand,
    offhand,

    pub fn isLeggings(self: EquipmentSlot) bool {
        return self == .legs;
    }

    pub fn allowsSwiftSneak(self: EquipmentSlot) bool {
        return self == .legs;
    }
};

/// Errors encountered when validating Swift Sneak application.
pub const SwiftSneakError = error{
    InvalidArmorSlot,
    InvalidEquipmentSlot,
    InvalidEnchantmentLevel,
};

/// Checks if an armor slot is valid for Swift Sneak.
/// Swift Sneak is strictly exclusive to leggings.
pub fn isValidArmorSlot(slot: ArmorSlot) bool {
    return slot == .leggings;
}

/// Checks if an equipment slot is valid for Swift Sneak.
pub fn isValidEquipmentSlot(slot: EquipmentSlot) bool {
    return slot == .legs;
}

/// Validates that the provided armor slot is eligible for Swift Sneak.
pub fn validateSwiftSneakSlot(slot: ArmorSlot) SwiftSneakError!void {
    if (!isValidArmorSlot(slot)) return error.InvalidArmorSlot;
}

/// Validates that the provided equipment slot is eligible for Swift Sneak.
pub fn validateSwiftSneakEquipmentSlot(slot: EquipmentSlot) SwiftSneakError!void {
    if (!isValidEquipmentSlot(slot)) return error.InvalidEquipmentSlot;
}

/// Checks if an item name corresponds to leggings (e.g. "diamond_leggings", "leather_pants").
pub fn isLeggingsItemName(name: []const u8) bool {
    return std.mem.indexOf(u8, name, "leggings") != null or
        std.mem.indexOf(u8, name, "pants") != null;
}

// ============================================================================
// Speed Calculations
// ============================================================================

/// Calculates crouch speed multiplier from Swift Sneak level.
/// Formula: crouch_speed = @min(1.0, 0.30 + 0.15 * @as(f32, @floatFromInt(level)))
pub fn calculateCrouchSpeed(level: u8) f32 {
    const level_f = @as(f32, @floatFromInt(level));
    return @min(MAX_CROUCH_SPEED, BASE_CROUCH_SPEED + SPEED_BONUS_PER_LEVEL * level_f);
}

/// Computes the effective horizontal movement speed multiplier.
/// When crouching: returns calculateCrouchSpeed(swift_sneak_level).
/// When not crouching: returns NORMAL_WALK_SPEED (1.0).
pub fn computeSpeedMultiplier(is_crouching: bool, swift_sneak_level: u8) f32 {
    if (!is_crouching) return NORMAL_WALK_SPEED;
    return calculateCrouchSpeed(swift_sneak_level);
}

/// Computes movement speed multiplier with armor slot exclusivity validation.
/// If Swift Sneak is equipped on any slot other than leggings, the bonus does
/// not apply and crouching defaults to BASE_CROUCH_SPEED (0.30).
pub fn computeSpeedMultiplierWithSlot(is_crouching: bool, slot: ArmorSlot, swift_sneak_level: u8) f32 {
    if (!is_crouching) return NORMAL_WALK_SPEED;
    if (!isValidArmorSlot(slot)) return BASE_CROUCH_SPEED;
    return calculateCrouchSpeed(swift_sneak_level);
}

/// Computes movement speed multiplier with equipment slot exclusivity validation.
pub fn computeSpeedMultiplierWithEquipmentSlot(is_crouching: bool, slot: EquipmentSlot, swift_sneak_level: u8) f32 {
    if (!is_crouching) return NORMAL_WALK_SPEED;
    if (!isValidEquipmentSlot(slot)) return BASE_CROUCH_SPEED;
    return calculateCrouchSpeed(swift_sneak_level);
}

// ============================================================================
// Sculk Acoustic Vibration Suppression
// ============================================================================

/// Detailed acoustic report for footstep emissions.
pub const AcousticEmissionReport = struct {
    frequency: u8,
    is_silent: bool,
    triggers_sculk_sensor: bool,
    alerts_warden: bool,
};

/// Evaluates the footstep acoustic vibration frequency.
/// Crouching (with or without Swift Sneak) completely dampens footstep vibration
/// to frequency 0. Non-crouching footsteps emit frequency 3.
pub fn evaluateFootstepVibrationFrequency(is_crouching: bool, swift_sneak_level: u8) u8 {
    _ = swift_sneak_level; // Swift Sneak preserves 0 frequency dampening even at high speeds
    if (is_crouching) return DAMPENED_VIBRATION_FREQ;
    return FOOTSTEP_VIBRATION_FREQ;
}

/// Returns whether footstep acoustic vibrations trigger a Sculk Sensor.
pub fn canSculkSensorDetectFootstep(is_crouching: bool, swift_sneak_level: u8) bool {
    return evaluateFootstepVibrationFrequency(is_crouching, swift_sneak_level) != 0;
}

/// Returns whether footstep acoustic vibrations alert the Warden.
pub fn canWardenDetectFootstep(is_crouching: bool, swift_sneak_level: u8) bool {
    return evaluateFootstepVibrationFrequency(is_crouching, swift_sneak_level) != 0;
}

/// Produces a complete acoustic emission diagnostics report.
pub fn evaluateSonicEmission(is_crouching: bool, swift_sneak_level: u8) AcousticEmissionReport {
    const freq = evaluateFootstepVibrationFrequency(is_crouching, swift_sneak_level);
    const silent = (freq == 0);
    return .{
        .frequency = freq,
        .is_silent = silent,
        .triggers_sculk_sensor = !silent,
        .alerts_warden = !silent,
    };
}

// ============================================================================
// Kinematics & Ledge Safety
// ============================================================================

/// Self-contained 3D vector for world positioning and velocities.
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn zero() Vec3 {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn scale(self: Vec3, s: f32) Vec3 {
        return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
    }

    pub fn length(self: Vec3) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }
};

/// Rectangular horizontal bounds of a solid ledge or platform.
pub const LedgeBoundary = struct {
    min_x: f32,
    max_x: f32,
    min_z: f32,
    max_z: f32,
    y: f32,

    pub fn init(min_x: f32, max_x: f32, min_z: f32, max_z: f32, y: f32) LedgeBoundary {
        return .{
            .min_x = min_x,
            .max_x = max_x,
            .min_z = min_z,
            .max_z = max_z,
            .y = y,
        };
    }

    /// Constructs the top surface boundary for a single block at (bx, by, bz).
    pub fn fromBlock(bx: i32, by: i32, bz: i32) LedgeBoundary {
        const x_f = @as(f32, @floatFromInt(bx));
        const y_f = @as(f32, @floatFromInt(by));
        const z_f = @as(f32, @floatFromInt(bz));
        return .{
            .min_x = x_f,
            .max_x = x_f + 1.0,
            .min_z = z_f,
            .max_z = z_f + 1.0,
            .y = y_f + 1.0,
        };
    }

    /// Clamps prospective position within the ledge bounds taking into account
    /// player radius and crouching overhang limit.
    pub fn clampPosition(self: LedgeBoundary, pos: Vec3, radius: f32, is_crouching: bool) Vec3 {
        if (!is_crouching) return pos;
        const clamped_x = std.math.clamp(pos.x, self.min_x - radius, self.max_x + radius);
        const clamped_z = std.math.clamp(pos.z, self.min_z - radius, self.max_z + radius);
        return Vec3.init(clamped_x, pos.y, clamped_z);
    }

    /// Strict clamp to the block's physical top surface.
    pub fn clampStrict(self: LedgeBoundary, pos: Vec3, is_crouching: bool) Vec3 {
        if (!is_crouching) return pos;
        return Vec3.init(
            std.math.clamp(pos.x, self.min_x, self.max_x),
            pos.y,
            std.math.clamp(pos.z, self.min_z, self.max_z),
        );
    }
};

/// Checks if the footprint at `pos` has ground support on solid blocks below.
/// In Minecraft, an entity has ground support if any of the footprint sample
/// points (center or bounding box corners) rest on a solid block below feet elevation.
pub fn hasGroundSupport(pos: Vec3, radius: f32, is_solid: *const fn (x: i32, y: i32, z: i32) bool) bool {
    const floor_y: i32 = @intFromFloat(@floor(pos.y - 0.05));

    // Center sample
    const cx: i32 = @intFromFloat(@floor(pos.x));
    const cz: i32 = @intFromFloat(@floor(pos.z));
    if (is_solid(cx, floor_y, cz)) return true;

    // Corner footprint samples
    const offsets = [_]f32{ -radius, radius };
    for (offsets) |ox| {
        for (offsets) |oz| {
            const bx: i32 = @intFromFloat(@floor(pos.x + ox));
            const bz: i32 = @intFromFloat(@floor(pos.z + oz));
            if (is_solid(bx, floor_y, bz)) return true;
        }
    }
    return false;
}

/// Evaluates whether applying `delta` would cause the entity to lose all ground
/// support and walk off a ledge.
pub fn wouldFallOffLedge(pos: Vec3, delta: Vec3, radius: f32, is_solid: *const fn (x: i32, y: i32, z: i32) bool) bool {
    const next_pos = pos.add(delta);
    return !hasGroundSupport(next_pos, radius, is_solid);
}

/// Clamps horizontal movement delta to keep a crouching player safely on the ledge.
/// Even at 75% speed under Swift Sneak Level 3 (or 100% speed), movement that
/// would walk off solid block edges is stopped at the ledge boundary.
/// If not crouching, the full uninhibited delta is returned.
pub fn clampMovementToLedge(
    pos: Vec3,
    delta: Vec3,
    radius: f32,
    is_crouching: bool,
    is_solid: *const fn (x: i32, y: i32, z: i32) bool,
) Vec3 {
    if (!is_crouching) return delta;

    var result_dx = delta.x;
    var result_dz = delta.z;

    // 1. Check X-axis movement
    if (result_dx != 0.0) {
        var test_pos = Vec3.init(pos.x + result_dx, pos.y, pos.z);
        if (!hasGroundSupport(test_pos, radius, is_solid)) {
            // Step backwards towards 0 in fine increments to find the safe edge boundary
            const step_size: f32 = 0.01;
            const sign: f32 = if (result_dx > 0.0) 1.0 else -1.0;
            var safe_dx: f32 = 0.0;
            var cur_dx = result_dx;
            while (@abs(cur_dx) >= step_size) {
                cur_dx -= sign * step_size;
                test_pos.x = pos.x + cur_dx;
                if (hasGroundSupport(test_pos, radius, is_solid)) {
                    safe_dx = cur_dx;
                    break;
                }
            }
            result_dx = safe_dx;
        }
    }

    // 2. Check Z-axis movement
    if (result_dz != 0.0) {
        var test_pos = Vec3.init(pos.x + result_dx, pos.y, pos.z + result_dz);
        if (!hasGroundSupport(test_pos, radius, is_solid)) {
            const step_size: f32 = 0.01;
            const sign: f32 = if (result_dz > 0.0) 1.0 else -1.0;
            var safe_dz: f32 = 0.0;
            var cur_dz = result_dz;
            while (@abs(cur_dz) >= step_size) {
                cur_dz -= sign * step_size;
                test_pos.z = pos.z + cur_dz;
                if (hasGroundSupport(test_pos, radius, is_solid)) {
                    safe_dz = cur_dz;
                    break;
                }
            }
            result_dz = safe_dz;
        }
    }

    // 3. Final diagonal verification
    if (result_dx != 0.0 and result_dz != 0.0) {
        const diag_pos = Vec3.init(pos.x + result_dx, pos.y, pos.z + result_dz);
        if (!hasGroundSupport(diag_pos, radius, is_solid)) {
            const total_len = @sqrt(result_dx * result_dx + result_dz * result_dz);
            if (total_len > 0.001) {
                const dir_x = result_dx / total_len;
                const dir_z = result_dz / total_len;
                var safe_len: f32 = 0.0;
                var cur_len = total_len;
                const step_size: f32 = 0.01;
                while (cur_len >= step_size) {
                    cur_len -= step_size;
                    const test_diag = Vec3.init(pos.x + dir_x * cur_len, pos.y, pos.z + dir_z * cur_len);
                    if (hasGroundSupport(test_diag, radius, is_solid)) {
                        safe_len = cur_len;
                        break;
                    }
                }
                result_dx = dir_x * safe_len;
                result_dz = dir_z * safe_len;
            }
        }
    }

    return Vec3.init(result_dx, delta.y, result_dz);
}

/// Comprehensive stateful kinematics controller for a player using Swift Sneak.
pub const SwiftSneakKinematics = struct {
    pos: Vec3,
    velocity: Vec3 = Vec3.zero(),
    is_crouching: bool = false,
    swift_sneak_level: u8 = 0,
    equipped_armor_slot: ArmorSlot = .leggings,
    radius: f32 = DEFAULT_PLAYER_RADIUS,

    pub fn init(pos: Vec3) SwiftSneakKinematics {
        return .{ .pos = pos };
    }

    pub fn setCrouching(self: *SwiftSneakKinematics, crouching: bool) void {
        self.is_crouching = crouching;
    }

    pub fn equipEnchantedLeggings(self: *SwiftSneakKinematics, level: u8) void {
        self.equipped_armor_slot = .leggings;
        self.swift_sneak_level = level;
    }

    pub fn equipOtherArmor(self: *SwiftSneakKinematics, slot: ArmorSlot, level: u8) void {
        self.equipped_armor_slot = slot;
        self.swift_sneak_level = level;
    }

    pub fn getEffectiveSpeedMultiplier(self: SwiftSneakKinematics) f32 {
        return computeSpeedMultiplierWithSlot(self.is_crouching, self.equipped_armor_slot, self.swift_sneak_level);
    }

    pub fn getFootstepVibrationFrequency(self: SwiftSneakKinematics) u8 {
        return evaluateFootstepVibrationFrequency(self.is_crouching, self.swift_sneak_level);
    }

    pub fn canEmitVibrationToSculk(self: SwiftSneakKinematics) bool {
        return canSculkSensorDetectFootstep(self.is_crouching, self.swift_sneak_level);
    }

    pub fn canEmitVibrationToWarden(self: SwiftSneakKinematics) bool {
        return canWardenDetectFootstep(self.is_crouching, self.swift_sneak_level);
    }

    /// Advances horizontal position by input movement, scaling by crouch speed multiplier
    /// and clamping to ledge safety when crouching.
    pub fn move(self: *SwiftSneakKinematics, input_dx: f32, input_dz: f32, is_solid: *const fn (x: i32, y: i32, z: i32) bool) void {
        const mult = self.getEffectiveSpeedMultiplier();
        const raw_delta = Vec3.init(input_dx * mult, 0.0, input_dz * mult);
        const clamped_delta = clampMovementToLedge(self.pos, raw_delta, self.radius, self.is_crouching, is_solid);
        self.pos = self.pos.add(clamped_delta);
    }
};

// ============================================================================
// Comprehensive Unit Test Suite (24 Tests)
// ============================================================================

test "1. crouch speed multiplier for unenchanted crouch (Level 0) is 0.30" {
    const mult = calculateCrouchSpeed(0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), mult, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), computeSpeedMultiplier(true, 0), 0.0001);
}

test "2. crouch speed multiplier for Swift Sneak Level 1 is 0.45" {
    // 0.30 + 0.15 * 1 = 0.45
    const mult = calculateCrouchSpeed(1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.45), mult, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.45), computeSpeedMultiplier(true, 1), 0.0001);
}

test "3. crouch speed multiplier for Swift Sneak Level 2 is 0.60" {
    // 0.30 + 0.15 * 2 = 0.60
    const mult = calculateCrouchSpeed(2);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), mult, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), computeSpeedMultiplier(true, 2), 0.0001);
}

test "4. crouch speed multiplier for Swift Sneak Level 3 is 0.75" {
    // 0.30 + 0.15 * 3 = 0.75
    const mult = calculateCrouchSpeed(3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), mult, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), computeSpeedMultiplier(true, 3), 0.0001);
}

test "5. crouch speed multiplier clamps at 1.0 for Level 5 and higher" {
    // Level 4: 0.30 + 0.60 = 0.90
    try std.testing.expectApproxEqAbs(@as(f32, 0.90), calculateCrouchSpeed(4), 0.0001);

    // Level 5: 0.30 + 0.75 = 1.05 -> clamped to 1.00
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), calculateCrouchSpeed(5), 0.0001);

    // Level 10: clamped to 1.00
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), calculateCrouchSpeed(10), 0.0001);

    // Level 255: clamped to 1.00
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), calculateCrouchSpeed(255), 0.0001);
}

test "6. walking speed is unaffected by Swift Sneak when not crouching (1.00x)" {
    // Not crouching returns 1.00 regardless of Swift Sneak level
    try std.testing.expectEqual(@as(f32, 1.00), computeSpeedMultiplier(false, 0));
    try std.testing.expectEqual(@as(f32, 1.00), computeSpeedMultiplier(false, 1));
    try std.testing.expectEqual(@as(f32, 1.00), computeSpeedMultiplier(false, 2));
    try std.testing.expectEqual(@as(f32, 1.00), computeSpeedMultiplier(false, 3));
    try std.testing.expectEqual(@as(f32, 1.00), computeSpeedMultiplier(false, 10));
}

test "7. armor slot exclusivity: leggings is strictly the only valid slot for Swift Sneak" {
    try std.testing.expect(isValidArmorSlot(.leggings));
    try std.testing.expect(!isValidArmorSlot(.helmet));
    try std.testing.expect(!isValidArmorSlot(.chestplate));
    try std.testing.expect(!isValidArmorSlot(.boots));

    try std.testing.expect(ArmorSlot.leggings.allowsSwiftSneak());
    try std.testing.expect(!ArmorSlot.helmet.allowsSwiftSneak());
    try std.testing.expect(!ArmorSlot.chestplate.allowsSwiftSneak());
    try std.testing.expect(!ArmorSlot.boots.allowsSwiftSneak());
}

test "8. armor slot exclusivity: validateSwiftSneakSlot rejects helmet, chestplate, and boots" {
    try validateSwiftSneakSlot(.leggings);
    try std.testing.expectError(error.InvalidArmorSlot, validateSwiftSneakSlot(.helmet));
    try std.testing.expectError(error.InvalidArmorSlot, validateSwiftSneakSlot(.chestplate));
    try std.testing.expectError(error.InvalidArmorSlot, validateSwiftSneakSlot(.boots));
}

test "9. equipment slot exclusivity: legs is strictly the only valid equipment slot" {
    try std.testing.expect(isValidEquipmentSlot(.legs));
    try std.testing.expect(!isValidEquipmentSlot(.head));
    try std.testing.expect(!isValidEquipmentSlot(.chest));
    try std.testing.expect(!isValidEquipmentSlot(.feet));
    try std.testing.expect(!isValidEquipmentSlot(.mainhand));
    try std.testing.expect(!isValidEquipmentSlot(.offhand));

    try std.testing.expect(EquipmentSlot.legs.allowsSwiftSneak());
    try std.testing.expect(!EquipmentSlot.head.allowsSwiftSneak());
}

test "10. equipment slot exclusivity: validateEquipmentSlot rejects head, chest, feet, and hands" {
    try validateSwiftSneakEquipmentSlot(.legs);
    try std.testing.expectError(error.InvalidEquipmentSlot, validateSwiftSneakEquipmentSlot(.head));
    try std.testing.expectError(error.InvalidEquipmentSlot, validateSwiftSneakEquipmentSlot(.chest));
    try std.testing.expectError(error.InvalidEquipmentSlot, validateSwiftSneakEquipmentSlot(.feet));
    try std.testing.expectError(error.InvalidEquipmentSlot, validateSwiftSneakEquipmentSlot(.mainhand));
    try std.testing.expectError(error.InvalidEquipmentSlot, validateSwiftSneakEquipmentSlot(.offhand));
}

test "11. Swift Sneak on non-leggings slot does not boost crouch speed (remains 0.30)" {
    // When equipped on leggings:
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), computeSpeedMultiplierWithSlot(true, .leggings, 3), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), computeSpeedMultiplierWithEquipmentSlot(true, .legs, 3), 0.0001);

    // When erroneously attached to boots or chestplate: speed defaults to base 0.30
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), computeSpeedMultiplierWithSlot(true, .boots, 3), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), computeSpeedMultiplierWithSlot(true, .chestplate, 3), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), computeSpeedMultiplierWithSlot(true, .helmet, 3), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), computeSpeedMultiplierWithEquipmentSlot(true, .feet, 3), 0.0001);
}

test "12. item name validation accepts leggings items and rejects non-leggings" {
    try std.testing.expect(isLeggingsItemName("diamond_leggings"));
    try std.testing.expect(isLeggingsItemName("netherite_leggings"));
    try std.testing.expect(isLeggingsItemName("iron_leggings"));
    try std.testing.expect(isLeggingsItemName("golden_leggings"));
    try std.testing.expect(isLeggingsItemName("leather_leggings"));
    try std.testing.expect(isLeggingsItemName("leather_pants"));
    try std.testing.expect(isLeggingsItemName("chainmail_leggings"));

    try std.testing.expect(!isLeggingsItemName("diamond_helmet"));
    try std.testing.expect(!isLeggingsItemName("diamond_chestplate"));
    try std.testing.expect(!isLeggingsItemName("diamond_boots"));
    try std.testing.expect(!isLeggingsItemName("elytra"));
    try std.testing.expect(!isLeggingsItemName("diamond_sword"));
}

test "13. sculk acoustic vibration suppression: crouching yields frequency 0" {
    try std.testing.expectEqual(@as(u8, 0), evaluateFootstepVibrationFrequency(true, 0));
    try std.testing.expectEqual(@as(u8, 0), evaluateFootstepVibrationFrequency(true, 1));
    try std.testing.expectEqual(@as(u8, 0), evaluateFootstepVibrationFrequency(true, 2));
    try std.testing.expectEqual(@as(u8, 0), evaluateFootstepVibrationFrequency(true, 3));
}

test "14. sculk acoustic vibration suppression: Swift Sneak Levels 1, 2, 3 are completely silent" {
    const report0 = evaluateSonicEmission(true, 0);
    try std.testing.expectEqual(@as(u8, 0), report0.frequency);
    try std.testing.expect(report0.is_silent);
    try std.testing.expect(!report0.triggers_sculk_sensor);
    try std.testing.expect(!report0.alerts_warden);

    const report3 = evaluateSonicEmission(true, 3);
    try std.testing.expectEqual(@as(u8, 0), report3.frequency);
    try std.testing.expect(report3.is_silent);
    try std.testing.expect(!report3.triggers_sculk_sensor);
    try std.testing.expect(!report3.alerts_warden);
}

test "15. sculk sensor cannot detect footstep vibrations while player is crouching with Swift Sneak" {
    try std.testing.expect(!canSculkSensorDetectFootstep(true, 0));
    try std.testing.expect(!canSculkSensorDetectFootstep(true, 1));
    try std.testing.expect(!canSculkSensorDetectFootstep(true, 2));
    try std.testing.expect(!canSculkSensorDetectFootstep(true, 3));
}

test "16. Warden is not alerted by footstep vibrations while player is crouching with Swift Sneak" {
    try std.testing.expect(!canWardenDetectFootstep(true, 0));
    try std.testing.expect(!canWardenDetectFootstep(true, 1));
    try std.testing.expect(!canWardenDetectFootstep(true, 2));
    try std.testing.expect(!canWardenDetectFootstep(true, 3));
}

test "17. walking or sprinting without crouching emits footstep vibration frequency 3 and alerts sculk" {
    try std.testing.expectEqual(@as(u8, 3), evaluateFootstepVibrationFrequency(false, 0));
    try std.testing.expectEqual(@as(u8, 3), evaluateFootstepVibrationFrequency(false, 3));
    try std.testing.expect(canSculkSensorDetectFootstep(false, 3));
    try std.testing.expect(canWardenDetectFootstep(false, 3));

    const report = evaluateSonicEmission(false, 3);
    try std.testing.expectEqual(@as(u8, 3), report.frequency);
    try std.testing.expect(!report.is_silent);
    try std.testing.expect(report.triggers_sculk_sensor);
    try std.testing.expect(report.alerts_warden);
}

// Mock world: single solid block at (0, 0, 0), air everywhere else.
fn singleBlockWorld(x: i32, y: i32, z: i32) bool {
    return x == 0 and y == 0 and z == 0;
}

test "18. ledge safety prevents player from walking off single block edge while crouching at Level 3 speed (0.75)" {
    // Player is on block (0, 0, 0) at x=0.8, y=1.0, z=0.5
    const start_pos = Vec3.init(0.8, 1.0, 0.5);

    // Large prospective step towards +X at 75% speed: delta = (0.75, 0, 0)
    const raw_delta = Vec3.init(0.75, 0.0, 0.0);

    // With crouching enabled: movement MUST be clamped at the ledge
    const clamped = clampMovementToLedge(start_pos, raw_delta, DEFAULT_PLAYER_RADIUS, true, singleBlockWorld);
    const end_pos = start_pos.add(clamped);

    // The player must still have solid ground support under their feet
    try std.testing.expect(hasGroundSupport(end_pos, DEFAULT_PLAYER_RADIUS, singleBlockWorld));

    // The player's end position must be clamped (cannot overshoot to 1.25 where ground support is lost)
    try std.testing.expect(clamped.x < 0.75);
    try std.testing.expect(clamped.x > 0.0);
    try std.testing.expect(end_pos.x <= 1.0 + DEFAULT_PLAYER_RADIUS);
}

test "19. ledge safety allows normal movement when solid ground exists beneath player" {
    // Platform of 5x5 blocks around (0, 0, 0)
    const Platform = struct {
        fn solid(x: i32, y: i32, z: i32) bool {
            return y == 0 and x >= -2 and x <= 2 and z >= -2 and z <= 2;
        }
    };

    const start_pos = Vec3.init(0.0, 1.0, 0.0);
    const delta = Vec3.init(0.75, 0.0, 0.50);

    // Moving safely on top of platform is completely unhindered
    const clamped = clampMovementToLedge(start_pos, delta, DEFAULT_PLAYER_RADIUS, true, Platform.solid);
    try std.testing.expectApproxEqAbs(delta.x, clamped.x, 0.001);
    try std.testing.expectApproxEqAbs(delta.z, clamped.z, 0.001);
}

test "20. ledge safety permits sliding along edge while blocking movement perpendicular to edge" {
    // Ledge running along Z from 0 to 5 at x = 0 (column of blocks)
    const ZWall = struct {
        fn solid(x: i32, y: i32, z: i32) bool {
            return x == 0 and y == 0 and z >= 0 and z <= 5;
        }
    };

    // Position player near +X edge of the strip at z = 2.0
    const edge_pos = Vec3.init(1.28, 1.0, 2.0);

    // Try to move diagonally: +0.50 into empty air (+X), and +0.50 along the solid strip (+Z)
    const delta = Vec3.init(0.50, 0.0, 0.50);
    const clamped = clampMovementToLedge(edge_pos, delta, DEFAULT_PLAYER_RADIUS, true, ZWall.solid);

    // Movement off the ledge (+X) must be blocked (clamped to ~0)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), clamped.x, 0.02);

    // Movement along the solid ledge (+Z) must be preserved
    try std.testing.expect(clamped.z > 0.40);

    const final_pos = edge_pos.add(clamped);
    try std.testing.expect(hasGroundSupport(final_pos, DEFAULT_PLAYER_RADIUS, ZWall.solid));
}

test "21. uncrouched player walks off ledge into air without ledge safety" {
    const start_pos = Vec3.init(0.5, 1.0, 0.5);
    const delta = Vec3.init(0.75, 0.0, 0.0);

    // When is_crouching is false, delta is not clamped
    const unclamped = clampMovementToLedge(start_pos, delta, DEFAULT_PLAYER_RADIUS, false, singleBlockWorld);
    try std.testing.expectEqual(delta.x, unclamped.x);

    const fall_pos = start_pos.add(unclamped);
    try std.testing.expectEqual(@as(f32, 1.25), fall_pos.x);
    // At x=1.25 with radius 0.3: center is at 1.25, corner at 0.95 still touches, but at 1.50 all ground is lost
    const big_delta = Vec3.init(1.5, 0.0, 0.0);
    const big_unclamped = clampMovementToLedge(start_pos, big_delta, DEFAULT_PLAYER_RADIUS, false, singleBlockWorld);
    const off_edge_pos = start_pos.add(big_unclamped);
    try std.testing.expect(!hasGroundSupport(off_edge_pos, DEFAULT_PLAYER_RADIUS, singleBlockWorld));
}

test "22. LedgeBoundary clamps prospective player position to safe supported region" {
    const bounds = LedgeBoundary.fromBlock(0, 0, 0);
    try std.testing.expectEqual(@as(f32, 0.0), bounds.min_x);
    try std.testing.expectEqual(@as(f32, 1.0), bounds.max_x);
    try std.testing.expectEqual(@as(f32, 1.0), bounds.y);

    // Position outside bounds (e.g. x = 2.0)
    const outside = Vec3.init(2.0, 1.0, 0.5);
    const clamped = bounds.clampPosition(outside, DEFAULT_PLAYER_RADIUS, true);
    // Overhang clamp: max_x + radius = 1.30
    try std.testing.expectApproxEqAbs(@as(f32, 1.30), clamped.x, 0.0001);

    // Strict clamp: max_x = 1.00
    const strict_clamped = bounds.clampStrict(outside, true);
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), strict_clamped.x, 0.0001);

    // Not crouching: position remains unclamped
    const uninhibited = bounds.clampPosition(outside, DEFAULT_PLAYER_RADIUS, false);
    try std.testing.expectEqual(@as(f32, 2.0), uninhibited.x);
}

test "23. diagonal movement ledge safety clamps corner overhang correctly" {
    // Player near corner of block (0.7, 1.0, 0.7)
    const start_pos = Vec3.init(0.7, 1.0, 0.7);
    // Diagonal step (+0.75, +0.75) off the corner of a single block
    const delta = Vec3.init(0.75, 0.0, 0.75);

    const clamped = clampMovementToLedge(start_pos, delta, DEFAULT_PLAYER_RADIUS, true, singleBlockWorld);
    const end_pos = start_pos.add(clamped);

    try std.testing.expect(hasGroundSupport(end_pos, DEFAULT_PLAYER_RADIUS, singleBlockWorld));
    try std.testing.expect(clamped.x < 0.75);
    try std.testing.expect(clamped.z < 0.75);
}

test "24. SwiftSneakKinematics stateful simulation: speed, vibration, and ledge safety integration" {
    var player = SwiftSneakKinematics.init(Vec3.init(0.5, 1.0, 0.5));

    // Initially standing, unenchanted
    try std.testing.expectEqual(@as(f32, 1.0), player.getEffectiveSpeedMultiplier());
    try std.testing.expectEqual(@as(u8, 3), player.getFootstepVibrationFrequency());
    try std.testing.expect(player.canEmitVibrationToSculk());

    // Equip Swift Sneak III on Leggings and crouch
    player.equipEnchantedLeggings(3);
    player.setCrouching(true);

    // Speed multiplier is 0.75 (0.30 + 0.15*3)
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), player.getEffectiveSpeedMultiplier(), 0.0001);

    // Complete acoustic dampening (0 frequency)
    try std.testing.expectEqual(@as(u8, 0), player.getFootstepVibrationFrequency());
    try std.testing.expect(!player.canEmitVibrationToSculk());
    try std.testing.expect(!player.canEmitVibrationToWarden());

    // Repeated movement towards edge over 50 steps: player never falls off
    var step: usize = 0;
    while (step < 50) : (step += 1) {
        player.move(1.0, 0.0, singleBlockWorld);
        try std.testing.expect(hasGroundSupport(player.pos, player.radius, singleBlockWorld));
    }

    // Player position remains safely on ledge
    try std.testing.expect(player.pos.x <= 1.0 + player.radius);

    // Uncrouch: speed becomes 1.0, vibration becomes 3, and player walks off edge
    player.setCrouching(false);
    try std.testing.expectEqual(@as(f32, 1.0), player.getEffectiveSpeedMultiplier());
    try std.testing.expectEqual(@as(u8, 3), player.getFootstepVibrationFrequency());
    player.move(1.0, 0.0, singleBlockWorld);
    try std.testing.expect(!hasGroundSupport(player.pos, player.radius, singleBlockWorld));
}
