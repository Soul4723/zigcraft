const std = @import("std");

/// Strength is mapped linearly from the center (15) to a face corner (1).
/// Distances are Euclidean and hit coordinates are clamped to the block face.
pub fn computeTargetBlockBullseyeSignal(hit_u: f32, hit_v: f32, projectile_is_trident_or_arrow: bool) u4 {
    _ = projectile_is_trident_or_arrow; // Projectile kind affects pulse duration, not strength.
    const u = std.math.clamp(hit_u, 0.0, 1.0) - 0.5;
    const v = std.math.clamp(hit_v, 0.0, 1.0) - 0.5;
    const distance = @sqrt(u * u + v * v);
    // The outer edge is the midpoint of any face side (radius 0.5); corners
    // saturate at the same minimum strength.
    const edge_distance: f32 = 0.5;
    const strength = 15.0 - (distance / edge_distance) * 14.0;
    return @intCast(std.math.clamp(@as(i32, @intFromFloat(@round(strength))), 1, 15));
}

/// Target blocks remain active for 20 ticks on arrow/trident hits and 8 ticks otherwise.
pub fn targetPulseDurationSeconds(is_arrow_or_trident: bool) f32 {
    return if (is_arrow_or_trident) 1.0 else 0.4;
}

/// Solar signal uses the sine of elevation (cosine of solar zenith), then applies weather.
pub fn computeDaylightDetectorSignal(sun_elevation_deg: f32, is_raining: bool, is_thunderstorming: bool, inverted_lunar_mode: bool) u4 {
    const elevation = std.math.clamp(sun_elevation_deg, 0.0, 90.0);
    const radians = elevation * (std.math.pi / 180.0);
    var standard: i32 = @intFromFloat(@round(15.0 * @sin(radians)));
    if (is_thunderstorming) {
        standard -= 6;
    } else if (is_raining) {
        standard -= 3;
    }
    standard = std.math.clamp(standard, 0, 15);
    const signal = if (inverted_lunar_mode) 15 - standard else standard;
    return @intCast(signal);
}

/// Gold plates count one entity per signal level; iron plates count ten.
pub fn computeWeightedPressurePlateSignal(entity_count: u16, is_light_gold_plate: bool) u4 {
    if (entity_count == 0) return 0;
    const divisor: u16 = if (is_light_gold_plate) 1 else 10;
    return @intCast(@min(15, (entity_count + divisor - 1) / divisor));
}

/// Observer emits full strength after a one-tick detection delay, then for one tick.
pub const ObserverPulseGenerator = struct {
    pub const delay_seconds: f32 = 0.1;
    pub const pulse_seconds: f32 = 0.1;

    observed_state: u64 = 0,
    timer: f32 = 0,
    phase: Phase = .idle,

    pub const Phase = enum { idle, delay, pulse };

    /// Starts a delayed pulse if the observed face's state changed. Returns current output.
    pub fn tick(self: *ObserverPulseGenerator, current_state: u64, dt: f32) u4 {
        if (self.phase == .idle and current_state != self.observed_state) {
            self.observed_state = current_state;
            self.phase = .delay;
            self.timer = delay_seconds;
        }
        var remaining = dt;
        while (remaining > 0 and self.phase != .idle) {
            if (remaining < self.timer) {
                self.timer -= remaining;
                remaining = 0;
            } else {
                remaining -= self.timer;
                if (self.phase == .delay) {
                    self.phase = .pulse;
                    self.timer = pulse_seconds;
                } else {
                    self.phase = .idle;
                    self.timer = 0;
                }
            }
        }
        return if (self.phase == .pulse) 15 else 0;
    }
};

test "target bullseye center is fifteen" {
    try std.testing.expectEqual(@as(u4, 15), computeTargetBlockBullseyeSignal(0.5, 0.5, true));
}
test "target face edge is one" {
    try std.testing.expectEqual(@as(u4, 1), computeTargetBlockBullseyeSignal(0.0, 0.5, false));
    try std.testing.expectEqual(@as(u4, 1), computeTargetBlockBullseyeSignal(1.0, 1.0, true));
}
test "target radial signal decreases toward corner" {
    try std.testing.expect(computeTargetBlockBullseyeSignal(0.75, 0.5, false) < 15);
    try std.testing.expect(computeTargetBlockBullseyeSignal(0.75, 0.75, false) < computeTargetBlockBullseyeSignal(0.75, 0.5, false));
}
test "target coordinates outside face are clamped" {
    try std.testing.expectEqual(@as(u4, 1), computeTargetBlockBullseyeSignal(-1, 0.5, false));
}
test "arrow and trident pulse lasts one second" {
    try std.testing.expectEqual(@as(f32, 1.0), targetPulseDurationSeconds(true));
}
test "snowball egg and wind charge pulse lasts point four seconds" {
    try std.testing.expectEqual(@as(f32, 0.4), targetPulseDurationSeconds(false));
}
test "daylight detector peaks at solar noon" {
    try std.testing.expectEqual(@as(u4, 15), computeDaylightDetectorSignal(90, false, false, false));
}
test "daylight detector is dark at midnight" {
    try std.testing.expectEqual(@as(u4, 0), computeDaylightDetectorSignal(-90, false, false, false));
}
test "daylight detector scales by solar elevation" {
    try std.testing.expectEqual(@as(u4, 8), computeDaylightDetectorSignal(30, false, false, false));
}
test "rain reduces daylight by three" {
    try std.testing.expectEqual(@as(u4, 12), computeDaylightDetectorSignal(90, true, false, false));
}
test "thunderstorm reduces daylight by six" {
    try std.testing.expectEqual(@as(u4, 9), computeDaylightDetectorSignal(90, true, true, false));
}
test "inverted lunar mode complements standard signal" {
    try std.testing.expectEqual(@as(u4, 15), computeDaylightDetectorSignal(0, false, false, true));
    try std.testing.expectEqual(@as(u4, 0), computeDaylightDetectorSignal(90, false, false, true));
}
test "gold weighted plate counts entities individually and caps" {
    try std.testing.expectEqual(@as(u4, 0), computeWeightedPressurePlateSignal(0, true));
    try std.testing.expectEqual(@as(u4, 1), computeWeightedPressurePlateSignal(1, true));
    try std.testing.expectEqual(@as(u4, 15), computeWeightedPressurePlateSignal(15, true));
    try std.testing.expectEqual(@as(u4, 15), computeWeightedPressurePlateSignal(99, true));
}
test "iron weighted plate counts groups of ten" {
    try std.testing.expectEqual(@as(u4, 1), computeWeightedPressurePlateSignal(1, false));
    try std.testing.expectEqual(@as(u4, 1), computeWeightedPressurePlateSignal(10, false));
    try std.testing.expectEqual(@as(u4, 2), computeWeightedPressurePlateSignal(11, false));
    try std.testing.expectEqual(@as(u4, 2), computeWeightedPressurePlateSignal(20, false));
    try std.testing.expectEqual(@as(u4, 15), computeWeightedPressurePlateSignal(141, false));
}
test "observer waits one tick then emits a one tick pulse" {
    var observer = ObserverPulseGenerator{};
    try std.testing.expectEqual(@as(u4, 0), observer.tick(1, 0.05));
    try std.testing.expectEqual(@as(u4, 15), observer.tick(1, 0.05));
    try std.testing.expectEqual(@as(u4, 15), observer.tick(1, 0.05));
    try std.testing.expectEqual(@as(u4, 0), observer.tick(1, 0.05));
}
test "observer ignores unchanged state" {
    var observer = ObserverPulseGenerator{};
    try std.testing.expectEqual(@as(u4, 0), observer.tick(0, 1.0));
    try std.testing.expectEqual(@as(u4, 0), observer.tick(0, 1.0));
}
