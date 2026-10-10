const std = @import("std");
const block_mod = @import("block.zig");
pub const BlockId = block_mod.BlockId;

/// Wither summon pattern: T of soul sand with 3 wither skulls on top.
/// Base row: 3 soul sand at y0. Stem: 1 soul sand centered under middle.
/// Skulls: 3 wither_skull_block at y0+1 above each base cell.
/// Triggered from any of the 3 skull placements; returns base center (middle soul sand).
pub const SummonSite = struct {
    base_x: i32,
    base_y: i32,
    base_z: i32,
    axis: enum { x_axis, z_axis },
};

pub fn detectWitherPattern(lookup: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, y: i32, z: i32) ?SummonSite {
    // Skull just placed at (x,y,z); base row runs at y-1.
    // Trigger may be any of the 3 skulls, so probe middle candidates at offsets -1..1.
    if (lookup(x, y, z) != .wither_skull_block) return null;
    const by = y - 1;
    var d: i32 = -1;
    while (d <= 1) : (d += 1) {
        if (isSkullRow(lookup, x + d, y, z, true) and isSoulBase(lookup, x + d, by, z, true)) {
            return .{ .base_x = x + d, .base_y = by, .base_z = z, .axis = .x_axis };
        }
        if (isSkullRow(lookup, x, y, z + d, false) and isSoulBase(lookup, x, by, z + d, false)) {
            return .{ .base_x = x, .base_y = by, .base_z = z + d, .axis = .z_axis };
        }
    }
    return null;
}

fn isSkullRow(lookup: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, y: i32, z: i32, along_x: bool) bool {
    var d: i32 = -1;
    while (d <= 1) : (d += 1) {
        const b = if (along_x) lookup(x + d, y, z) else lookup(x, y, z + d);
        if (b != .wither_skull_block) return false;
    }
    return true;
}

fn isSoulBase(lookup: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, by: i32, z: i32, along_x: bool) bool {
    var d: i32 = -1;
    while (d <= 1) : (d += 1) {
        const b = if (along_x) lookup(x + d, by, z) else lookup(x, by, z + d);
        if (b != .soul_sand) return false;
    }
    // Stem: soul sand directly below middle base cell.
    if (lookup(x, by - 1, z) != .soul_sand) return false;
    return true;
}

test "detectWitherPattern finds X-axis T" {
    const Mock = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            // Base row y=7: soul sand x=9..11, z=5. Stem y=6 x=10. Skulls y=8.
            if (y == 8 and z == 5 and (x == 9 or x == 10 or x == 11)) return .wither_skull_block;
            if (y == 7 and z == 5 and (x == 9 or x == 10 or x == 11)) return .soul_sand;
            if (y == 6 and x == 10 and z == 5) return .soul_sand;
            return .air;
        }
    };
    const site = detectWitherPattern(Mock.get, 11, 8, 5);
    try std.testing.expect(site != null);
    try std.testing.expectEqual(@as(i32, 10), site.?.base_x);
}

test "detectWitherPattern finds Z-axis T" {
    const Mock = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (y == 8 and x == 5 and (z == 9 or z == 10 or z == 11)) return .wither_skull_block;
            if (y == 7 and x == 5 and (z == 9 or z == 10 or z == 11)) return .soul_sand;
            if (y == 6 and x == 5 and z == 10) return .soul_sand;
            return .air;
        }
    };
    const site = detectWitherPattern(Mock.get, 5, 8, 9);
    try std.testing.expect(site != null);
    try std.testing.expectEqual(@as(i32, 10), site.?.base_z);
}

test "detectWitherPattern rejects missing stem" {
    const Mock = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (y == 8 and z == 5 and (x == 9 or x == 10 or x == 11)) return .wither_skull_block;
            if (y == 7 and z == 5 and (x == 9 or x == 10 or x == 11)) return .soul_sand;
            return .stone;
        }
    };
    try std.testing.expect(detectWitherPattern(Mock.get, 10, 8, 5) == null);
}
