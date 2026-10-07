const std = @import("std");

pub const hunt_range: f32 = 12.0;
pub const bite_range: f32 = 0.5;
pub const pack_rally_radius: f32 = 8.0;
pub const walk_pulse: f32 = 0.5;

pub fn shouldHunt(dist: f32) bool {
    return dist < hunt_range and dist > bite_range;
}

pub fn packBonus(nearby_wolves: usize) f32 {
    if (nearby_wolves <= 1) return 0.0;
    return @min(2.0, @as(f32, @floatFromInt(nearby_wolves - 1)) * 0.5);
}

test "hunt engagement window" {
    try std.testing.expect(shouldHunt(6.0));
    try std.testing.expect(!shouldHunt(0.3));
    try std.testing.expect(!shouldHunt(12.0));
    try std.testing.expect(!shouldHunt(20.0));
}

test "pack bonus scales then caps" {
    try std.testing.expectEqual(packBonus(0), 0.0);
    try std.testing.expectEqual(packBonus(1), 0.0);
    try std.testing.expectEqual(packBonus(2), 0.5);
    try std.testing.expectEqual(packBonus(6), 2.0);
    try std.testing.expectEqual(packBonus(10), 2.0);
}
