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

const block_mod = @import("block.zig");

pub fn toggleDoor(door: block_mod.BlockId, open: bool) ?block_mod.BlockId {
    return switch (door) {
        .wooden_door_closed => if (open) .wooden_door_open else null,
        .wooden_door_open => if (!open) .wooden_door_closed else null,
        .iron_door_closed => if (open) .iron_door_open else null,
        .iron_door_open => if (!open) .iron_door_closed else null,
        else => null,
    };
}

test "toggleDoor transitions" {
    try std.testing.expectEqual(block_mod.BlockId.wooden_door_open, toggleDoor(.wooden_door_closed, true).?);
    try std.testing.expectEqual(block_mod.BlockId.wooden_door_closed, toggleDoor(.wooden_door_open, false).?);
    try std.testing.expectEqual(block_mod.BlockId.iron_door_open, toggleDoor(.iron_door_closed, true).?);
    try std.testing.expectEqual(block_mod.BlockId.iron_door_closed, toggleDoor(.iron_door_open, false).?);
    try std.testing.expectEqual(@as(?block_mod.BlockId, null), toggleDoor(.wooden_door_closed, false));
    try std.testing.expectEqual(@as(?block_mod.BlockId, null), toggleDoor(.dirt, true));
}

pub fn toggleLever(lever: block_mod.BlockId) ?block_mod.BlockId {
    return switch (lever) {
        .lever_off => .lever_on,
        .lever_on => .lever_off,
        else => null,
    };
}

test "toggleLever transitions" {
    try std.testing.expectEqual(block_mod.BlockId.lever_on, toggleLever(.lever_off).?);
    try std.testing.expectEqual(block_mod.BlockId.lever_off, toggleLever(.lever_on).?);
    try std.testing.expectEqual(@as(?block_mod.BlockId, null), toggleLever(.stone));
}
