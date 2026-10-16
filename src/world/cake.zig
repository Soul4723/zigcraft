const std = @import("std");

pub const max_cakes: usize = 32;
pub const initial_slices: u8 = 7;
pub const hunger_per_slice: f32 = 2.0;
pub const melon_slice_hunger: f32 = 2.0;
pub const healing_potion_hp: f32 = 8.0;

pub const CakeState = struct {
    x: i32,
    y: i32,
    z: i32,
    slices_remaining: u8 = initial_slices,
};

pub fn eatSlice(cake: *CakeState) struct { ate: bool, finished: bool, comparator_signal: u8 } {
    if (cake.slices_remaining == 0) {
        return .{ .ate = false, .finished = true, .comparator_signal = 0 };
    }
    cake.slices_remaining -= 1;
    return .{
        .ate = true,
        .finished = cake.slices_remaining == 0,
        .comparator_signal = cake.slices_remaining * 2,
    };
}

pub fn comparatorSignal(slices_remaining: u8) u8 {
    return @min(@as(u8, 14), slices_remaining *| 2);
}

pub fn findCake(cakes: []const CakeState, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, cakes.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const cake = cakes[i];
        if (cake.x == x and cake.y == y and cake.z == z) return i;
    }
    return null;
}

test "constants" {
    try std.testing.expectEqual(@as(usize, 32), max_cakes);
    try std.testing.expectEqual(@as(u8, 7), initial_slices);
    try std.testing.expectEqual(@as(f32, 2.0), hunger_per_slice);
    try std.testing.expectEqual(@as(f32, 2.0), melon_slice_hunger);
    try std.testing.expectEqual(@as(f32, 8.0), healing_potion_hp);
}

test "CakeState defaults" {
    const cake = CakeState{ .x = 1, .y = 2, .z = 3 };
    try std.testing.expectEqual(@as(i32, 1), cake.x);
    try std.testing.expectEqual(@as(i32, 2), cake.y);
    try std.testing.expectEqual(@as(i32, 3), cake.z);
    try std.testing.expectEqual(initial_slices, cake.slices_remaining);
}

test "eatSlice once from full" {
    var cake = CakeState{ .x = 0, .y = 0, .z = 0 };
    const result = eatSlice(&cake);
    try std.testing.expect(result.ate);
    try std.testing.expect(!result.finished);
    try std.testing.expectEqual(@as(u8, 6), cake.slices_remaining);
    try std.testing.expectEqual(@as(u8, 12), result.comparator_signal);
}

test "eatSlice finishes cake" {
    var cake = CakeState{ .x = 0, .y = 0, .z = 0, .slices_remaining = 1 };
    const result = eatSlice(&cake);
    try std.testing.expect(result.ate);
    try std.testing.expect(result.finished);
    try std.testing.expectEqual(@as(u8, 0), cake.slices_remaining);
    try std.testing.expectEqual(@as(u8, 0), result.comparator_signal);
}

test "eatSlice on empty cake" {
    var cake = CakeState{ .x = 0, .y = 0, .z = 0, .slices_remaining = 0 };
    const result = eatSlice(&cake);
    try std.testing.expect(!result.ate);
    try std.testing.expect(result.finished);
    try std.testing.expectEqual(@as(u8, 0), result.comparator_signal);
    try std.testing.expectEqual(@as(u8, 0), cake.slices_remaining);
}

test "eatSlice consumes all slices down to empty" {
    var cake = CakeState{ .x = 0, .y = 0, .z = 0 };
    var eaten: u32 = 0;
    while (cake.slices_remaining > 0) {
        const result = eatSlice(&cake);
        try std.testing.expect(result.ate);
        eaten += 1;
    }
    try std.testing.expectEqual(@as(u32, initial_slices), eaten);
    const last = eatSlice(&cake);
    try std.testing.expect(!last.ate);
    try std.testing.expect(last.finished);
    try std.testing.expectEqual(@as(u8, 0), last.comparator_signal);
}

test "comparatorSignal values" {
    try std.testing.expectEqual(@as(u8, 0), comparatorSignal(0));
    try std.testing.expectEqual(@as(u8, 2), comparatorSignal(1));
    try std.testing.expectEqual(@as(u8, 4), comparatorSignal(2));
    try std.testing.expectEqual(@as(u8, 6), comparatorSignal(3));
    try std.testing.expectEqual(@as(u8, 8), comparatorSignal(4));
    try std.testing.expectEqual(@as(u8, 10), comparatorSignal(5));
    try std.testing.expectEqual(@as(u8, 12), comparatorSignal(6));
    try std.testing.expectEqual(@as(u8, 14), comparatorSignal(7));
}

test "comparatorSignal clamps above threshold" {
    try std.testing.expectEqual(@as(u8, 14), comparatorSignal(8));
    try std.testing.expectEqual(@as(u8, 14), comparatorSignal(100));
    try std.testing.expectEqual(@as(u8, 14), comparatorSignal(255));
}

test "comparatorSignal saturates without overflow" {
    try std.testing.expectEqual(@as(u8, 14), comparatorSignal(200));
    try std.testing.expectEqual(@as(u8, 14), comparatorSignal(255));
}

test "findCake" {
    var cakes: [max_cakes]CakeState = undefined;
    cakes[0] = .{ .x = 1, .y = 2, .z = 3 };
    cakes[1] = .{ .x = 4, .y = 5, .z = 6 };
    cakes[2] = .{ .x = 1, .y = 2, .z = 3 };

    try std.testing.expectEqual(@as(?usize, 0), findCake(&cakes, 3, 1, 2, 3));
    try std.testing.expectEqual(@as(?usize, 1), findCake(&cakes, 3, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, null), findCake(&cakes, 3, 9, 9, 9));
    try std.testing.expectEqual(@as(?usize, null), findCake(&cakes, 1, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, null), findCake(&cakes, 0, 1, 2, 3));
    try std.testing.expectEqual(@as(?usize, null), findCake(&cakes, 100, 100, 100, 100));
}

test "findCake ignores slices_remaining in matching" {
    var cakes: [max_cakes]CakeState = undefined;
    cakes[0] = .{ .x = 0, .y = 0, .z = 0, .slices_remaining = 0 };
    cakes[1] = .{ .x = 0, .y = 0, .z = 0, .slices_remaining = 3 };
    try std.testing.expectEqual(@as(?usize, 0), findCake(&cakes, 2, 0, 0, 0));
}

test "findCake negative coordinates" {
    var cakes: [max_cakes]CakeState = undefined;
    cakes[0] = .{ .x = -5, .y = -6, .z = -7 };
    try std.testing.expectEqual(@as(?usize, 0), findCake(&cakes, 1, -5, -6, -7));
    try std.testing.expectEqual(@as(?usize, null), findCake(&cakes, 1, 5, 6, 7));
}
