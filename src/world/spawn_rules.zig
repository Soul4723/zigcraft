const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

pub const spawn_radius: f32 = 18.0;
pub const deep_water_depth: i32 = 3;

pub const SpawnCategory = enum {
    sheep,
    pig,
    wolf,
};

pub fn selectMobType(roll: f32, is_night: bool) SpawnCategory {
    if (is_night) {
        if (roll < 0.60) return .wolf;
        if (roll < 0.80) return .pig;
        return .sheep;
    } else {
        if (roll < 0.42) return .sheep;
        if (roll < 0.84) return .pig;
        return .wolf;
    }
}

pub fn isSpawnGround(block: BlockId) bool {
    return block == .grass or block == .dirt or block == .sand;
}

pub fn hasHeadroom(head1: BlockId, head2: BlockId) bool {
    return head1 == .air and head2 == .air;
}

pub fn waterDepthAt(get: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, y: i32, z: i32) i32 {
    var depth: i32 = 0;
    var dy: i32 = 0;
    while (dy > -8) : (dy -= 1) {
        if (get(x, y + dy, z) == .water) {
            depth += 1;
        } else break;
    }
    return depth;
}

pub fn isSafeSpawn(get: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, y: i32, z: i32) bool {
    const ground = get(x, y, z);
    if (!isSpawnGround(ground)) return false;
    if (!hasHeadroom(get(x, y + 1, z), get(x, y + 2, z))) return false;
    if (waterDepthAt(get, x, y, z) >= deep_water_depth) return false;
    var dx: i32 = -1;
    while (dx <= 1) : (dx += 1) {
        var dz: i32 = -1;
        while (dz <= 1) : (dz += 1) {
            if (dx == 0 and dz == 0) continue;
            if (waterDepthAt(get, x + dx, y, z + dz) >= deep_water_depth) return false;
        }
    }
    return true;
}

fn flatWorld(x: i32, y: i32, z: i32) BlockId {
    _ = x;
    _ = z;
    if (y == 5) return .grass;
    if (y > 5) return .air;
    return .dirt;
}

fn lakeWorld(x: i32, y: i32, z: i32) BlockId {
    _ = x;
    _ = z;
    if (y == 5) return .water;
    if (y > 5) return .air;
    return .dirt;
}

test "spawn ground classification" {
    try std.testing.expect(isSpawnGround(.grass));
    try std.testing.expect(isSpawnGround(.sand));
    try std.testing.expect(!isSpawnGround(.water));
    try std.testing.expect(!isSpawnGround(.stone));
}

test "safe spawn on flat grass" {
    try std.testing.expect(isSafeSpawn(&flatWorld, 0, 5, 0));
}

test "no spawn over deep water" {
    try std.testing.expect(!isSafeSpawn(&lakeWorld, 0, 5, 0));
}

test "day vs night mob type selection" {
    // Day distribution: 0.1 -> sheep, 0.5 -> pig, 0.9 -> wolf
    try std.testing.expectEqual(selectMobType(0.1, false), .sheep);
    try std.testing.expectEqual(selectMobType(0.5, false), .pig);
    try std.testing.expectEqual(selectMobType(0.9, false), .wolf);

    // Night distribution: 0.5 -> wolf, 0.7 -> pig, 0.9 -> sheep
    try std.testing.expectEqual(selectMobType(0.5, true), .wolf);
    try std.testing.expectEqual(selectMobType(0.7, true), .pig);
    try std.testing.expectEqual(selectMobType(0.9, true), .sheep);
}
