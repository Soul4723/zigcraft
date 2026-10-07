const std = @import("std");

pub const bed_cooldown: f32 = 1.0;
pub const flint_edge_cooldown: f32 = 0.5;
pub const flint_action_cooldown: f32 = 0.25;
pub const flint_feed_cooldown: f32 = 0.3;
pub const aim_range: f32 = 5.0;

pub fn tickCooldown(cd: f32, dt: f32) f32 {
    return @max(0.0, cd - dt);
}

pub fn ready(cd: f32) bool {
    return cd <= 0.0;
}

test "cooldown ticks and readiness" {
    try std.testing.expect(ready(0.0));
    try std.testing.expect(!ready(0.5));
    try std.testing.expectEqual(tickCooldown(1.0, 0.4), @as(f32, 0.6));
    try std.testing.expectEqual(tickCooldown(0.2, 0.5), @as(f32, 0.0));
}
