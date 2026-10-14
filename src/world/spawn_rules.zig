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

pub fn isWaterSpawn(world: anytype, x: i32, y: i32, z: i32) bool {
    const ground = world.getBlockWorld(x, y, z);
    if (ground != .water and ground != .sand and ground != .dirt) return false;
    const water_layer = world.getBlockWorld(x, y + 1, z);
    if (water_layer != .water) return false;
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

/// Bastion spawn: blackstone or gilded blackstone floor with headroom (piglin guard posts).
pub fn isBastionSpawn(world: anytype, x: i32, y: i32, z: i32) bool {
    const ground = world.getBlockWorld(x, y, z);
    if (ground != .blackstone and ground != .gilded_blackstone) return false;
    return hasHeadroom(world.getBlockWorld(x, y + 1, z), world.getBlockWorld(x, y + 2, z));
}

/// Fortress spawn: nether brick floor with headroom (wither skeleton guard posts).
pub fn isFortressSpawn(world: anytype, x: i32, y: i32, z: i32) bool {
    const ground = world.getBlockWorld(x, y, z);
    if (ground != .nether_brick) return false;
    return hasHeadroom(world.getBlockWorld(x, y + 1, z), world.getBlockWorld(x, y + 2, z));
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

test "bastion spawn needs blackstone or gilded blackstone and headroom" {
    const BastionFlat = struct {
        pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
            _ = x;
            _ = z;
            if (y == 7) return .blackstone;
            if (y == 8 or y == 9) return .air;
            return .netherrack;
        }
    };
    try std.testing.expect(isBastionSpawn(BastionFlat{}, 0, 7, 0));
    try std.testing.expect(!isBastionSpawn(BastionFlat{}, 0, 8, 0));

    const GildedFlat = struct {
        pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
            _ = x;
            _ = z;
            if (y == 7) return .gilded_blackstone;
            if (y == 8 or y == 9) return .air;
            return .netherrack;
        }
    };
    try std.testing.expect(isBastionSpawn(GildedFlat{}, 0, 7, 0));
}

test "fortress spawn needs nether brick and headroom" {
    const FortressFlat = struct {
        pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
            _ = x;
            _ = z;
            if (y == 7) return .nether_brick;
            if (y > 7) return .air;
            return .netherrack;
        }
    };
    try std.testing.expect(isFortressSpawn(FortressFlat{}, 0, 7, 0));
    try std.testing.expect(!isFortressSpawn(FortressFlat{}, 0, 5, 0));
    try std.testing.expect(isNetherSpawn(FortressFlat{}, 0, 7, 0)); // fortress brick also valid nether ground
}

/// Fortress spawner pulse: emberbeast reinforcements trickle near loot junctions.
/// max_near caps local guards; interval gates pulse frequency; elapsed tracks time since last wave.
pub const spawner_interval: f32 = 20.0;
pub const spawner_max_near: usize = 2;

pub fn spawnerDue(elapsed: f32) bool {
    return elapsed >= spawner_interval;
}

/// Spawner cage activation check: active within 16 blocks horizontal distance.
pub fn isSpawnerActive(spawner_x: i32, spawner_z: i32, player_x: f32, player_z: f32) bool {
    const dx = @as(f32, @floatFromInt(spawner_x)) + 0.5 - player_x;
    const dz = @as(f32, @floatFromInt(spawner_z)) + 0.5 - player_z;
    return (dx * dx + dz * dz) <= (16.0 * 16.0);
}

test "fortress spawner pulse timing and cap" {
    try std.testing.expect(!spawnerDue(0.0));
    try std.testing.expect(!spawnerDue(19.9));
    try std.testing.expect(spawnerDue(20.0));
    try std.testing.expect(spawnerDue(60.0));
    try std.testing.expectEqual(@as(usize, 2), spawner_max_near);

    try std.testing.expect(isSpawnerActive(10, 10, 10.0, 10.0));
    try std.testing.expect(isSpawnerActive(10, 10, 25.0, 10.0));
    try std.testing.expect(!isSpawnerActive(10, 10, 30.0, 10.0));
}

/// Nearest fortress junction center (48-cell grid, span 22..25) to world (x, z).
/// Returns junction origin + distance for compass readout.
pub const JunctionPoint = struct { jx: i32, jz: i32, dist: f32 };

pub fn nearestJunction(x: f32, z: f32) JunctionPoint {
    const cell: f32 = 48.0;
    const cx = @floor((x - 23.5) / cell);
    const cz = @floor((z - 23.5) / cell);
    var best: JunctionPoint = .{ .jx = 0, .jz = 0, .dist = 1e30 };
    var ox: i32 = -1;
    while (ox <= 1) : (ox += 1) {
        var oz: i32 = -1;
        while (oz <= 1) : (oz += 1) {
            const jx: i32 = @as(i32, @intFromFloat(cx)) * 48 + 23 + ox * 48;
            const jz: i32 = @as(i32, @intFromFloat(cz)) * 48 + 23 + oz * 48;
            const dx = @as(f32, @floatFromInt(jx)) - x;
            const dz = @as(f32, @floatFromInt(jz)) - z;
            const d = @sqrt(dx * dx + dz * dz);
            if (d < best.dist) best = .{ .jx = jx, .jz = jz, .dist = d };
        }
    }
    return best;
}

test "nearest junction centers on 48-cell fortress grid" {
    const j = nearestJunction(24.0, 24.0);
    try std.testing.expectEqual(@as(i32, 23), j.jx);
    try std.testing.expect(j.dist < 2.0);
    const k = nearestJunction(70.0, 70.0);
    try std.testing.expectEqual(@as(i32, 71), k.jx);
    try std.testing.expectEqual(@as(i32, 71), k.jz);
}

test "water spawn checks water presence at y+1" {
    const WWorld = struct {
        pub fn getBlockWorld(_: @This(), x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = z;
            if (y == 2) return .sand;
            if (y == 3) return .water;
            return .air;
        }
    };
    try std.testing.expect(isWaterSpawn(WWorld{}, 0, 2, 0));
    try std.testing.expect(!isWaterSpawn(WWorld{}, 0, 3, 0));
}
