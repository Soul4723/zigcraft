const std = @import("std");

/// Maximum number of sculk sensors tracked in a single collection.
pub const max_sensors: usize = 32;

/// Detection radius of a sculk sensor, in blocks.
pub const sensor_range: f32 = 8.0;

/// Squared detection radius; compared against squared distances to avoid sqrt.
pub const sensor_range_sq: f32 = 64.0;

/// How long a sensor stays "active" (signal emitted) after a vibration, in seconds.
pub const sensor_active_duration: f32 = 1.5;

/// How long a sensor is unable to retrigger after deactivating, in seconds.
pub const sensor_cooldown_duration: f32 = 0.5;

/// A single sculk sensor placed at block coordinates (x, y, z).
/// `signal_strength` is 0 when idle, otherwise 1..15 scaled by distance.
pub const SculkSensor = struct {
    x: i32,
    y: i32,
    z: i32,
    active_timer: f32 = 0.0,
    cooldown_timer: f32 = 0.0,
    signal_strength: u8 = 0,
};

/// Maps a squared distance to a redstone signal strength of 1..15.
/// Returns 0 when out of range. Closer vibrations produce stronger signals:
/// distance 0.0 -> 15, distance `sensor_range` (8.0) -> 1.
pub fn vibrationSignalStrength(dist_sq: f32) u8 {
    if (dist_sq > sensor_range_sq) return 0;
    const dist = @sqrt(@max(0.0, dist_sq));
    const frac = dist / sensor_range;
    const raw = 15.0 - frac * 14.0;
    const clamped = @max(1.0, @min(15.0, raw));
    return @intFromFloat(@round(clamped));
}

/// Attempts to trigger `sensor` from a vibration at world position (vx, vy, vz).
/// Wool occlusion or a currently active/cooling sensor blocks the trigger.
/// Returns true and starts the active window when the vibration landed in range.
pub fn triggerVibration(sensor: *SculkSensor, vx: f32, vy: f32, vz: f32, wool_occluded: bool) bool {
    if (wool_occluded) return false;
    if (sensor.active_timer > 0.0) return false;
    if (sensor.cooldown_timer > 0.0) return false;

    const cx = @as(f32, @floatFromInt(sensor.x)) + 0.5;
    const cy = @as(f32, @floatFromInt(sensor.y)) + 0.5;
    const cz = @as(f32, @floatFromInt(sensor.z)) + 0.5;
    const dx = cx - vx;
    const dy = cy - vy;
    const dz = cz - vz;
    const dist_sq = dx * dx + dy * dy + dz * dz;
    if (dist_sq > sensor_range_sq) return false;

    sensor.active_timer = sensor_active_duration;
    sensor.signal_strength = vibrationSignalStrength(dist_sq);
    return true;
}

/// Advances a sensor by `dt` seconds.
/// While active the timer ticks down; on reaching zero it deactivates, clears the
/// signal, starts the cooldown, and returns true. Otherwise it ticks the cooldown
/// (clamped at zero) and returns false.
pub fn tickSensor(sensor: *SculkSensor, dt: f32) bool {
    if (sensor.active_timer > 0.0) {
        sensor.active_timer -= dt;
        if (sensor.active_timer <= 0.0) {
            sensor.active_timer = 0.0;
            sensor.cooldown_timer = sensor_cooldown_duration;
            sensor.signal_strength = 0;
            return true;
        }
        return false;
    }

    if (sensor.cooldown_timer > 0.0) {
        sensor.cooldown_timer = @max(0.0, sensor.cooldown_timer - dt);
    }
    return false;
}

/// Finds the index of the sensor at block (x, y, z) among the first `count`
/// entries of `sensors`, or null when none matches.
pub fn findSensor(sensors: []const SculkSensor, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, sensors.len);
    for (sensors[0..n], 0..) |s, i| {
        if (s.x == x and s.y == y and s.z == z) return i;
    }
    return null;
}

test "constants match expected values" {
    try std.testing.expectEqual(@as(usize, 32), max_sensors);
    try std.testing.expectEqual(@as(f32, 8.0), sensor_range);
    try std.testing.expectEqual(@as(f32, 64.0), sensor_range_sq);
    try std.testing.expectEqual(@as(f32, 1.5), sensor_active_duration);
    try std.testing.expectEqual(@as(f32, 0.5), sensor_cooldown_duration);
}

test "SculkSensor defaults are idle" {
    const s = SculkSensor{ .x = 1, .y = 2, .z = 3 };
    try std.testing.expectEqual(@as(f32, 0.0), s.active_timer);
    try std.testing.expectEqual(@as(f32, 0.0), s.cooldown_timer);
    try std.testing.expectEqual(@as(u8, 0), s.signal_strength);
}

test "vibrationSignalStrength out of range is zero" {
    try std.testing.expectEqual(@as(u8, 0), vibrationSignalStrength(64.01));
    try std.testing.expectEqual(@as(u8, 0), vibrationSignalStrength(1000.0));
}

test "vibrationSignalStrength maps 0..8 to 15..1" {
    try std.testing.expectEqual(@as(u8, 15), vibrationSignalStrength(0.0));
    try std.testing.expectEqual(@as(u8, 1), vibrationSignalStrength(64.0));
    // dist = 4 -> 15 - (4/8)*14 = 8
    try std.testing.expectEqual(@as(u8, 8), vibrationSignalStrength(16.0));
    // dist = 2 -> 15 - (2/8)*14 = 11.5 -> 12
    try std.testing.expectEqual(@as(u8, 12), vibrationSignalStrength(4.0));
}

test "vibrationSignalStrength clamps negative inputs" {
    try std.testing.expectEqual(@as(u8, 15), vibrationSignalStrength(-4.0));
}

test "triggerVibration within range activates and sets signal" {
    var s = SculkSensor{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(triggerVibration(&s, 0.5, 0.5, 0.5, false));
    try std.testing.expectEqual(@as(f32, sensor_active_duration), s.active_timer);
    try std.testing.expectEqual(@as(u8, 15), s.signal_strength);
}

test "triggerVibration out of range does nothing" {
    var s = SculkSensor{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!triggerVibration(&s, 100.0, 0.5, 0.5, false));
    try std.testing.expectEqual(@as(f32, 0.0), s.active_timer);
    try std.testing.expectEqual(@as(u8, 0), s.signal_strength);
}

test "triggerVibration blocked by wool or active or cooldown" {
    var s = SculkSensor{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!triggerVibration(&s, 0.5, 0.5, 0.5, true));

    s.active_timer = 0.5;
    try std.testing.expect(!triggerVibration(&s, 0.5, 0.5, 0.5, false));

    s.active_timer = 0.0;
    s.cooldown_timer = 0.25;
    try std.testing.expect(!triggerVibration(&s, 0.5, 0.5, 0.5, false));
}

test "tickSensor counts down active then deactivates" {
    var s = SculkSensor{ .x = 0, .y = 0, .z = 0 };
    _ = triggerVibration(&s, 0.5, 0.5, 0.5, false);
    try std.testing.expect(!tickSensor(&s, 1.0));
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), s.active_timer, 1e-5);
    try std.testing.expect(tickSensor(&s, 0.5));
    try std.testing.expectEqual(@as(f32, 0.0), s.active_timer);
    try std.testing.expectEqual(@as(f32, sensor_cooldown_duration), s.cooldown_timer);
    try std.testing.expectEqual(@as(u8, 0), s.signal_strength);
}

test "tickSensor cools down but cannot go negative" {
    var s = SculkSensor{ .x = 0, .y = 0, .z = 0, .cooldown_timer = 0.3 };
    try std.testing.expect(!tickSensor(&s, 0.1));
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), s.cooldown_timer, 1e-5);
    try std.testing.expect(!tickSensor(&s, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), s.cooldown_timer);
}

test "findSensor locates matching coordinate within count" {
    const sensors = [_]SculkSensor{
        .{ .x = 1, .y = 0, .z = 0 },
        .{ .x = 2, .y = 3, .z = 4 },
        .{ .x = 5, .y = 5, .z = 5 },
    };
    try std.testing.expectEqual(@as(?usize, 1), findSensor(&sensors, 3, 2, 3, 4));
    try std.testing.expectEqual(@as(?usize, null), findSensor(&sensors, 3, 9, 9, 9));
    // count limits the search window
    try std.testing.expectEqual(@as(?usize, null), findSensor(&sensors, 1, 2, 3, 4));
    // count larger than slice length is clamped
    try std.testing.expectEqual(@as(?usize, 0), findSensor(&sensors, 99, 1, 0, 0));
}
