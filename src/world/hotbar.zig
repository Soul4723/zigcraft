const std = @import("std");

pub const slot_count: usize = 6;

pub fn slotForKey(key_index: u8) ?usize {
    if (key_index < slot_count) return key_index;
    return null;
}

pub fn clampSlot(slot: usize) usize {
    return @min(slot, slot_count - 1);
}

test "hotbar slots map 0-5" {
    try std.testing.expectEqual(slotForKey(0), @as(?usize, 0));
    try std.testing.expectEqual(slotForKey(5), @as(?usize, 5));
    try std.testing.expectEqual(slotForKey(6), @as(?usize, null));
}

test "slot clamp" {
    try std.testing.expectEqual(clampSlot(0), 0);
    try std.testing.expectEqual(clampSlot(99), 5);
}
