const std = @import("std");

pub const Plate = struct { x: i32, y: i32, z: i32, down: bool };
pub const Wire = struct { x: i32, y: i32, z: i32, powered: bool };
pub const Repeater = struct { x: i32, y: i32, z: i32, powered: bool, timer: f32, stage: u2 };
pub const Lamp = struct { x: i32, y: i32, z: i32, lit: bool };
pub const RedTorch = struct { x: i32, y: i32, z: i32, lit: bool, flips: [8]f32, flip_count: u8, burnout: f32 };

pub const plate_cap: usize = 64;
pub const wire_cap: usize = 256;
pub const repeater_cap: usize = 64;
pub const lamp_cap: usize = 64;
pub const red_torch_cap: usize = 64;

fn find2D(items: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (items[i].x == x and items[i].y == y and items[i].z == z) return i;
    }
    return null;
}

pub fn findPlate(plates: []Plate, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(plates, n, x, y, z);
}

pub fn findWire(wires: []Wire, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(wires, n, x, y, z);
}

pub fn findRepeater(repeaters: []Repeater, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(repeaters, n, x, y, z);
}

pub fn findRedTorch(torches: []RedTorch, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(torches, n, x, y, z);
}

pub fn swapRemoveLast(n: *usize) void {
    n.* -= 1;
}

test "component find helpers" {
    var plates = [_]Plate{.{ .x = 1, .y = 2, .z = 3, .down = false }} ** 2;
    try std.testing.expectEqual(findPlate(&plates, 1, 1, 2, 3), @as(?usize, 0));
    try std.testing.expectEqual(findPlate(&plates, 1, 9, 9, 9), @as(?usize, null));
    var wires = [_]Wire{.{ .x = 4, .y = 5, .z = 6, .powered = true }} ** 2;
    try std.testing.expectEqual(findWire(&wires, 1, 4, 5, 6), @as(?usize, 0));
    var reps = [_]Repeater{.{ .x = 7, .y = 8, .z = 9, .powered = false, .timer = 0, .stage = 1 }} ** 2;
    try std.testing.expectEqual(findRepeater(&reps, 1, 7, 8, 9), @as(?usize, 0));
    var rts = [_]RedTorch{.{ .x = 1, .y = 1, .z = 1, .lit = true, .flips = [_]f32{-100} ** 8, .flip_count = 0, .burnout = 0 }} ** 2;
    try std.testing.expectEqual(findRedTorch(&rts, 1, 1, 1, 1), @as(?usize, 0));
}
