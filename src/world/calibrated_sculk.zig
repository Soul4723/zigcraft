const std = @import("std");

/// Maximum number of calibrated sculk sensors tracked in a single collection.
pub const max_calibrated_sensors: usize = 32;

/// Detection radius of a calibrated sculk sensor, in blocks.
pub const calibrated_range: f32 = 16.0;

/// Squared detection radius; compared against squared distances to avoid sqrt.
pub const calibrated_range_sq: f32 = 256.0;

/// How long a calibrated sensor stays active after a vibration, in seconds.
pub const calibrated_active_time: f32 = 1.0;

/// Vibration frequency categories, mirroring game vibration event IDs.
pub const VibrationFrequency = enum(u8) {
    movement = 1,
    flap = 2,
    step = 3,
    swim = 4,
    mob_action = 6,
    projectile_hit = 8,
    block_break = 12,
    block_place = 13,
    bell_ring = 15,
};

/// A calibrated sculk sensor placed at block coordinates (x, y, z).
/// `filter_frequency` is 0 to accept all vibrations, otherwise an event ID.
/// `signal_strength` is 0 when idle, otherwise the triggering frequency.
pub const CalibratedSensor = struct {
    x: i32,
    y: i32,
    z: i32,
    active_timer: f32 = 0.0,
    filter_frequency: u8 = 0,
    signal_strength: u8 = 0,
};

/// Returns whether a vibration of `incoming_freq` passes the sensor filter.
/// A `filter_freq` of 0 accepts every frequency; otherwise they must match.
pub fn matchesFilter(filter_freq: u8, incoming_freq: u8) bool {
    if (filter_freq == 0) return true;
    return filter_freq == incoming_freq;
}

/// Attempts to trigger `sensor` from a vibration at world position (vx, vy, vz).
/// A currently active sensor or one whose filter rejects `freq` blocks the trigger.
/// Returns true and starts the active window when the vibration landed in range.
pub fn triggerVibration(sensor: *CalibratedSensor, vx: f32, vy: f32, vz: f32, freq: u8) bool {
    if (sensor.active_timer > 0.0) return false;
    if (!matchesFilter(sensor.filter_frequency, freq)) return false;

    const cx = @as(f32, @floatFromInt(sensor.x)) + 0.5;
    const cy = @as(f32, @floatFromInt(sensor.y)) + 0.5;
    const cz = @as(f32, @floatFromInt(sensor.z)) + 0.5;
    const dx = cx - vx;
    const dy = cy - vy;
    const dz = cz - vz;
    const dist_sq = dx * dx + dy * dy + dz * dz;
    if (dist_sq > calibrated_range_sq) return false;

    sensor.active_timer = calibrated_active_time;
    sensor.signal_strength = freq;
    return true;
}

/// Advances a sensor by `dt` seconds.
/// While active the timer ticks down; on reaching zero it deactivates, clears the
/// signal, and returns true. Otherwise it returns false.
pub fn tickSensor(sensor: *CalibratedSensor, dt: f32) bool {
    if (sensor.active_timer > 0.0) {
        sensor.active_timer -= dt;
        if (sensor.active_timer <= 0.0) {
            sensor.active_timer = 0.0;
            sensor.signal_strength = 0;
            return true;
        }
    }
    return false;
}

/// Finds the index of the sensor at block (x, y, z) among the first `count`
/// entries of `sensors`, or null when none matches.
pub fn findSensor(sensors: []const CalibratedSensor, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, sensors.len);
    for (sensors[0..n], 0..) |s, i| {
        if (s.x == x and s.y == y and s.z == z) return i;
    }
    return null;
}

test "constants match expected values" {
    try std.testing.expectEqual(@as(usize, 32), max_calibrated_sensors);
    try std.testing.expectEqual(@as(f32, 16.0), calibrated_range);
    try std.testing.expectEqual(@as(f32, 256.0), calibrated_range_sq);
    try std.testing.expectEqual(@as(f32, 1.0), calibrated_active_time);
}

test "VibrationFrequency values are stable" {
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(VibrationFrequency.movement));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(VibrationFrequency.flap));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(VibrationFrequency.step));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(VibrationFrequency.swim));
    try std.testing.expectEqual(@as(u8, 6), @intFromEnum(VibrationFrequency.mob_action));
    try std.testing.expectEqual(@as(u8, 8), @intFromEnum(VibrationFrequency.projectile_hit));
    try std.testing.expectEqual(@as(u8, 12), @intFromEnum(VibrationFrequency.block_break));
    try std.testing.expectEqual(@as(u8, 13), @intFromEnum(VibrationFrequency.block_place));
    try std.testing.expectEqual(@as(u8, 15), @intFromEnum(VibrationFrequency.bell_ring));
}

test "CalibratedSensor defaults are idle and unfiltered" {
    const s = CalibratedSensor{ .x = 1, .y = 2, .z = 3 };
    try std.testing.expectEqual(@as(f32, 0.0), s.active_timer);
    try std.testing.expectEqual(@as(u8, 0), s.filter_frequency);
    try std.testing.expectEqual(@as(u8, 0), s.signal_strength);
}

test "matchesFilter accepts all when filter is zero" {
    try std.testing.expect(matchesFilter(0, 1));
    try std.testing.expect(matchesFilter(0, 15));
    try std.testing.expect(matchesFilter(0, 0));
}

test "matchesFilter requires equality otherwise" {
    try std.testing.expect(matchesFilter(3, 3));
    try std.testing.expect(!matchesFilter(3, 4));
    try std.testing.expect(!matchesFilter(15, 0));
}

test "triggerVibration within range activates and stores frequency" {
    var s = CalibratedSensor{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(triggerVibration(&s, 0.5, 0.5, 0.5, @intFromEnum(VibrationFrequency.step)));
    try std.testing.expectEqual(@as(f32, calibrated_active_time), s.active_timer);
    try std.testing.expectEqual(@as(u8, 3), s.signal_strength);
}

test "triggerVibration at range boundary is accepted" {
    var s = CalibratedSensor{ .x = 0, .y = 0, .z = 0 };
    // distance exactly 16.0 along +x -> dist_sq == 256.0, allowed
    try std.testing.expect(triggerVibration(&s, 16.5, 0.5, 0.5, 1));
}

test "triggerVibration out of range does nothing" {
    var s = CalibratedSensor{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!triggerVibration(&s, 100.0, 0.5, 0.5, 1));
    try std.testing.expectEqual(@as(f32, 0.0), s.active_timer);
    try std.testing.expectEqual(@as(u8, 0), s.signal_strength);
}

test "triggerVibration blocked while active" {
    var s = CalibratedSensor{ .x = 0, .y = 0, .z = 0, .active_timer = 0.5 };
    try std.testing.expect(!triggerVibration(&s, 0.5, 0.5, 0.5, 1));
}

test "triggerVibration rejects filtered frequency" {
    var s = CalibratedSensor{ .x = 0, .y = 0, .z = 0, .filter_frequency = 3 };
    try std.testing.expect(!triggerVibration(&s, 0.5, 0.5, 0.5, 4));
    try std.testing.expectEqual(@as(f32, 0.0), s.active_timer);
    try std.testing.expect(triggerVibration(&s, 0.5, 0.5, 0.5, 3));
}

test "tickSensor counts down active then deactivates" {
    var s = CalibratedSensor{ .x = 0, .y = 0, .z = 0 };
    _ = triggerVibration(&s, 0.5, 0.5, 0.5, 1);
    try std.testing.expect(!tickSensor(&s, 0.4));
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), s.active_timer, 1e-5);
    try std.testing.expect(tickSensor(&s, 0.6));
    try std.testing.expectEqual(@as(f32, 0.0), s.active_timer);
    try std.testing.expectEqual(@as(u8, 0), s.signal_strength);
}

test "tickSensor idle returns false and stays zero" {
    var s = CalibratedSensor{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!tickSensor(&s, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), s.active_timer);
}

test "tickSensor clamps overshoot to zero" {
    var s = CalibratedSensor{ .x = 0, .y = 0, .z = 0, .active_timer = 0.2 };
    try std.testing.expect(tickSensor(&s, 5.0));
    try std.testing.expectEqual(@as(f32, 0.0), s.active_timer);
    try std.testing.expectEqual(@as(u8, 0), s.signal_strength);
}

test "findSensor locates matching coordinate within count" {
    const sensors = [_]CalibratedSensor{
        .{ .x = 1, .y = 0, .z = 0 },
        .{ .x = 2, .y = 3, .z = 4 },
        .{ .x = 5, .y = 5, .z = 5 },
    };
    try std.testing.expectEqual(@as(?usize, 1), findSensor(&sensors, 3, 2, 3, 4));
    try std.testing.expectEqual(@as(?usize, null), findSensor(&sensors, 3, 9, 9, 9));
    try std.testing.expectEqual(@as(?usize, null), findSensor(&sensors, 1, 2, 3, 4));
    try std.testing.expectEqual(@as(?usize, 0), findSensor(&sensors, 99, 1, 0, 0));
}
