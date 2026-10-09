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

pub fn waterDepthAt(world: anytype, x: i32, y: i32, z: i32) i32 {
    var depth: i32 = 0;
    var dy: i32 = 0;
    while (dy > -8) : (dy -= 1) {
        if (world.getBlockWorld(x, y + dy, z) == .water) {
            depth += 1;
        } else break;
    }
    return depth;
}

/// Cave spawn: stone floor, headroom, and no sky access above (darkness proxy).
/// World provides getBlockWorld; max_y bounds the upward scan.
pub fn isCaveSpawn(world: anytype, x: i32, y: i32, z: i32, max_y: i32) bool {
    const ground = world.getBlockWorld(x, y, z);
    if (ground != .stone and ground != .cobblestone and ground != .dirt) return false;
    if (!hasHeadroom(world.getBlockWorld(x, y + 1, z), world.getBlockWorld(x, y + 2, z))) return false;
    var up = y + 3;
    while (up <= max_y) : (up += 1) {
        if (world.getBlockWorld(x, up, z) == .air) return false;
    }
    return true;
}

pub fn isSafeSpawn(world: anytype, x: i32, y: i32, z: i32) bool {
    const ground = world.getBlockWorld(x, y, z);
    if (!isSpawnGround(ground)) return false;
    if (!hasHeadroom(world.getBlockWorld(x, y + 1, z), world.getBlockWorld(x, y + 2, z))) return false;
    if (waterDepthAt(world, x, y, z) >= deep_water_depth) return false;
    var dx: i32 = -1;
    while (dx <= 1) : (dx += 1) {
        var dz: i32 = -1;
        while (dz <= 1) : (dz += 1) {
            if (dx == 0 and dz == 0) continue;
            if (waterDepthAt(world, x + dx, y, z + dz) >= deep_water_depth) return false;
        }
    }
    return true;
}

const FlatWorld = struct {
    pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
        _ = x;
        _ = z;
        if (y == 5) return .grass;
        if (y > 5) return .air;
        return .dirt;
    }
};

const LakeWorld = struct {
    pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
        _ = x;
        _ = z;
        if (y == 5) return .water;
        if (y > 5) return .air;
        return .dirt;
    }
};

const CaveWorld = struct {
    pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
        _ = x;
        _ = z;
        // Stone floor at y=3, air pocket y=4-5, solid rock above.
        if (y == 3) return .stone;
        if (y == 4 or y == 5) return .air;
        return .stone;
    }
};

const OpenPitWorld = struct {
    pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
        _ = x;
        _ = z;
        if (y == 3) return .stone;
        if (y == 4 or y == 5) return .air;
        if (y > 5) return .air;
        return .stone;
    }
};

test "cave spawn needs stone floor, headroom, and cover" {
    try std.testing.expect(isCaveSpawn(CaveWorld{}, 0, 3, 0, 15));
    // Sky visible above -> not a cave.
    try std.testing.expect(!isCaveSpawn(OpenPitWorld{}, 0, 3, 0, 15));
    // Wrong floor.
    try std.testing.expect(!isCaveSpawn(CaveWorld{}, 0, 4, 0, 15));
}

test "spawn ground classification" {
    try std.testing.expect(isSpawnGround(.grass));
    try std.testing.expect(isSpawnGround(.sand));
    try std.testing.expect(!isSpawnGround(.water));
    try std.testing.expect(!isSpawnGround(.stone));
}

test "safe spawn on flat grass" {
    try std.testing.expect(isSafeSpawn(FlatWorld{}, 0, 5, 0));
}

test "no spawn over deep water" {
    try std.testing.expect(!isSafeSpawn(LakeWorld{}, 0, 5, 0));
}

test "deep water scan reaches below mob manager old four-cell window" {
    const DeepLake = struct {
        pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
            _ = x;
            _ = z;
            if (y >= 1 and y <= 5) return .water;
            if (y == 0) return .grass;
            if (y > 5) return .air;
            return .dirt;
        }
    };
    // Five-deep water at spawn column: old inline 4-deep scan missed it, unified scan rejects it.
    try std.testing.expectEqual(@as(i32, 5), waterDepthAt(DeepLake{}, 0, 5, 0));
    try std.testing.expect(!isSafeSpawn(DeepLake{}, 0, 0, 0));
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

/// Nether spawn: netherrack or fortress masonry floor with two simplest headroom cells.
pub fn isNetherSpawn(world: anytype, x: i32, y: i32, z: i32) bool {
    const ground = world.getBlockWorld(x, y, z);
    if (ground != .netherrack and ground != .nether_brick and ground != .soul_sand) return false;
    return hasHeadroom(world.getBlockWorld(x, y + 1, z), world.getBlockWorld(x, y + 2, z));
}

test "nether spawn needs nether ground and headroom" {
    const NetherFlat = struct {
        pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
            _ = x;
            _ = z;
            if (y == 5) return .netherrack;
            if (y > 5) return .air;
            return .netherrack;
        }
    };
    try std.testing.expect(isNetherSpawn(NetherFlat{}, 0, 5, 0));
    try std.testing.expect(!isNetherSpawn(NetherFlat{}, 0, 6, 0));
    try std.testing.expect(!isNetherSpawn(FlatWorld{}, 0, 5, 0));
}

/// Fortress spawner pulse: emberbeast reinforcements trickle near loot junctions.
/// max_near caps local guards; interval gates pulse frequency; elapsed tracks time since last wave.
pub const spawner_interval: f32 = 20.0;
pub const spawner_max_near: usize = 2;

pub fn spawnerDue(elapsed: f32) bool {
    return elapsed >= spawner_interval;
}

test "fortress spawner pulse timing and cap" {
    try std.testing.expect(!spawnerDue(0.0));
    try std.testing.expect(!spawnerDue(19.9));
    try std.testing.expect(spawnerDue(20.0));
    try std.testing.expect(spawnerDue(60.0));
    try std.testing.expectEqual(@as(usize, 2), spawner_max_near);
}
