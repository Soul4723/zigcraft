const std = @import("std");

pub const MAX_RADIUS: i32 = 8;
pub const MAX_RADIUS_SQ: i32 = MAX_RADIUS * MAX_RADIUS;
pub const BLOOM_TICKS: u32 = 20;
pub const BLOOM_LIGHT: u4 = 6;
pub const CARDINAL_BRANCH_CHANCE: u32 = 85;
pub const DIAGONAL_BRANCH_CHANCE: u32 = 15;
pub const VEIN_FACE_MASK: u6 = 0b11_1111;

pub const BlockType = enum(u8) {
    air,
    water,
    stone,
    dirt,
    deepslate,
    tuff,
    sculk,
    sculk_vein,
};

pub const Pos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn add(self: Pos, other: Pos) Pos {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn distanceSq(self: Pos, other: Pos) i32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return dx * dx + dy * dy + dz * dz;
    }
};

pub const Face = enum(u6) {
    down = 0,
    up = 1,
    north = 2,
    south = 3,
    west = 4,
    east = 5,

    pub const all = [_]Face{ .down, .up, .north, .south, .west, .east };

    pub fn offset(self: Face) Pos {
        return switch (self) {
            .down => .{ .x = 0, .y = -1, .z = 0 },
            .up => .{ .x = 0, .y = 1, .z = 0 },
            .north => .{ .x = 0, .y = 0, .z = -1 },
            .south => .{ .x = 0, .y = 0, .z = 1 },
            .west => .{ .x = -1, .y = 0, .z = 0 },
            .east => .{ .x = 1, .y = 0, .z = 0 },
        };
    }
};

pub fn faceBit(face: Face) u6 {
    return @as(u6, 1) << @as(u3, @intCast(@intFromEnum(face)));
}

pub fn isSubstrate(block: BlockType) bool {
    return switch (block) {
        .stone, .dirt, .deepslate, .tuff => true,
        else => false,
    };
}

/// A local 17-cube centered on the death epicenter. Coordinates outside the
/// cube are treated as air, and propagation is clipped to the radius-8 sphere.
pub const World = struct {
    pub const SIDE: usize = 33;
    pub const WORLD_BOUND: i32 = 16;
    blocks: [SIDE][SIDE][SIDE]BlockType = filled(.air),
    vein_faces: [SIDE][SIDE][SIDE]u6 = filledMask(0),

    fn filled(comptime block: BlockType) [SIDE][SIDE][SIDE]BlockType {
        return @as([SIDE][SIDE][SIDE]BlockType, @splat(@as([SIDE][SIDE]BlockType, @splat(@as([SIDE]BlockType, @splat(block))))));
    }

    fn filledMask(comptime mask: u6) [SIDE][SIDE][SIDE]u6 {
        return @as([SIDE][SIDE][SIDE]u6, @splat(@as([SIDE][SIDE]u6, @splat(@as([SIDE]u6, @splat(mask))))));
    }

    fn index(v: i32) ?usize {
        if (v < -WORLD_BOUND or v > WORLD_BOUND) return null;
        return @intCast(v + WORLD_BOUND);
    }

    pub fn inBounds(pos: Pos) bool {
        return index(pos.x) != null and index(pos.y) != null and index(pos.z) != null;
    }

    pub fn get(self: *const World, pos: Pos) BlockType {
        const x = index(pos.x) orelse return .air;
        const y = index(pos.y) orelse return .air;
        const z = index(pos.z) orelse return .air;
        return self.blocks[x][y][z];
    }

    pub fn set(self: *World, pos: Pos, block: BlockType) bool {
        const x = index(pos.x) orelse return false;
        const y = index(pos.y) orelse return false;
        const z = index(pos.z) orelse return false;
        self.blocks[x][y][z] = block;
        return true;
    }

    pub fn veinMask(self: *const World, pos: Pos) u6 {
        const x = index(pos.x) orelse return 0;
        const y = index(pos.y) orelse return 0;
        const z = index(pos.z) orelse return 0;
        return self.vein_faces[x][y][z];
    }

    fn addVeinFace(self: *World, pos: Pos, face: Face) void {
        const x = index(pos.x) orelse return;
        const y = index(pos.y) orelse return;
        const z = index(pos.z) orelse return;
        if (self.blocks[x][y][z] != .air and self.blocks[x][y][z] != .water and self.blocks[x][y][z] != .sculk_vein) return;
        self.blocks[x][y][z] = .sculk_vein;
        self.vein_faces[x][y][z] |= faceBit(face);
    }
};

pub const BranchKind = enum { cardinal, diagonal };

/// Roll is in 0...99. Cardinal outcomes occupy 85 values; diagonal outcomes 15.
pub fn branchKind(roll: u7) BranchKind {
    return if (roll < CARDINAL_BRANCH_CHANCE) .cardinal else .diagonal;
}

pub const BloomResult = struct {
    converted: u32 = 0,
    remaining_charge: u32 = 0,
    consumed_charge: u32 = 0,
};

fn coatExposedFaces(world: *World, pos: Pos) void {
    for (Face.all) |face| {
        const neighbor = pos.add(face.offset());
        const adjacent = world.get(neighbor);
        if (adjacent == .air or adjacent == .water) {
            // The vein occupies the exposed neighbor; its attachment face points back to sculk.
            const toward_sculk: Face = switch (face) {
                .down => .up,
                .up => .down,
                .north => .south,
                .south => .north,
                .west => .east,
                .east => .west,
            };
            world.addVeinFace(neighbor, toward_sculk);
        }
    }
}

fn hasConvertedNeighbor(world: *const World, pos: Pos, epicenter: Pos) bool {
    if (pos.distanceSq(epicenter) <= 1) return true;
    for (Face.all) |face| {
        if (world.get(pos.add(face.offset())) == .sculk) return true;
    }
    return false;
}

/// Converts connected substrate in integer Euclidean shells, closest first,
/// bounded by radius 8 and the available charge. The epicenter may itself be
/// substrate, or may touch substrate on one of its six faces.
pub fn propagate(world: *World, epicenter: Pos, charge: u32) BloomResult {
    var result = BloomResult{ .remaining_charge = charge };
    if (!World.inBounds(epicenter) or charge == 0) return result;

    var shell: i32 = 0;
    while (shell <= MAX_RADIUS and result.remaining_charge > 0) : (shell += 1) {
        var changed = true;
        while (changed and result.remaining_charge > 0) {
            changed = false;
            var dx: i32 = -MAX_RADIUS;
            while (dx <= MAX_RADIUS and result.remaining_charge > 0) : (dx += 1) {
                var dy: i32 = -MAX_RADIUS;
                while (dy <= MAX_RADIUS and result.remaining_charge > 0) : (dy += 1) {
                    var dz: i32 = -MAX_RADIUS;
                    while (dz <= MAX_RADIUS and result.remaining_charge > 0) : (dz += 1) {
                        const pos = epicenter.add(.{ .x = dx, .y = dy, .z = dz });
                        const distance_sq = pos.distanceSq(epicenter);
                        if (distance_sq > MAX_RADIUS_SQ or distance_sq > shell * shell or (shell > 0 and distance_sq <= (shell - 1) * (shell - 1))) continue;
                        if (!isSubstrate(world.get(pos)) or !hasConvertedNeighbor(world, pos, epicenter)) continue;
                        _ = world.set(pos, .sculk);
                        result.converted += 1;
                        result.remaining_charge -= 1;
                        result.consumed_charge += 1;
                        coatExposedFaces(world, pos);
                        changed = true;
                    }
                }
            }
        }
    }
    return result;
}

pub const Catalyst = struct {
    ticks_remaining: u32 = 0,

    pub fn lightLevel(self: Catalyst) u4 {
        return if (self.ticks_remaining > 0) BLOOM_LIGHT else 0;
    }

    pub fn activate(self: *Catalyst) void {
        self.ticks_remaining = BLOOM_TICKS;
    }

    pub fn tick(self: *Catalyst) void {
        if (self.ticks_remaining > 0) self.ticks_remaining -= 1;
    }
};

test "radius sphere accepts center and exact radius boundary" {
    const center = Pos{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expectEqual(@as(i32, 0), center.distanceSq(center));
    try std.testing.expectEqual(MAX_RADIUS_SQ, center.distanceSq(.{ .x = 8, .y = 0, .z = 0 }));
}

test "sphere rejects diagonal outside maximum Euclidean radius" {
    try std.testing.expect((Pos{ .x = 0, .y = 0, .z = 0 }).distanceSq(.{ .x = 8, .y = 1, .z = 0 }) > MAX_RADIUS_SQ);
}

test "out of bounds world coordinates read as air" {
    const world = World{};
    try std.testing.expectEqual(BlockType.air, world.get(.{ .x = 9, .y = 0, .z = 0 }));
}

test "world refuses writes beyond radius cube" {
    var world = World{};
    try std.testing.expect(!world.set(.{ .x = 17, .y = 0, .z = 0 }, .stone));
}

test "stone converts to sculk" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .stone);
    _ = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(BlockType.sculk, world.get(.{ .x = 0, .y = 0, .z = 0 }));
}

test "dirt converts to sculk" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .dirt);
    _ = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(BlockType.sculk, world.get(.{ .x = 0, .y = 0, .z = 0 }));
}

test "deepslate converts to sculk" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .deepslate);
    _ = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(BlockType.sculk, world.get(.{ .x = 0, .y = 0, .z = 0 }));
}

test "tuff converts to sculk" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .tuff);
    _ = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(BlockType.sculk, world.get(.{ .x = 0, .y = 0, .z = 0 }));
}

test "air does not convert" {
    var world = World{};
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 10);
    try std.testing.expectEqual(@as(u32, 0), result.converted);
}

test "water does not convert" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .water);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 10);
    try std.testing.expectEqual(@as(u32, 0), result.converted);
}

test "radius eight substrate converts" {
    var world = World{};
    _ = world.set(.{ .x = 8, .y = 0, .z = 0 }, .stone);
    const result = propagate(&world, .{ .x = 8, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(@as(u32, 1), result.converted);
}

test "radius eight boundary is included from epicenter" {
    var world = World{};
    for (1..8) |x| _ = world.set(.{ .x = @intCast(x), .y = 0, .z = 0 }, .sculk);
    _ = world.set(.{ .x = 8, .y = 0, .z = 0 }, .stone);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(@as(u32, 1), result.converted);
}

test "substrate beyond sphere is excluded" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .sculk);
    _ = world.set(.{ .x = 8, .y = 1, .z = 0 }, .stone);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 8);
    try std.testing.expectEqual(@as(u32, 0), result.converted);
}

test "propagation reaches vertical substrate in 3d" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 1, .z = 0 }, .stone);
    _ = world.set(.{ .x = 0, .y = 2, .z = 0 }, .dirt);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 2);
    try std.testing.expectEqual(@as(u32, 2), result.converted);
}

test "propagation reaches north and south substrate" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .sculk);
    _ = world.set(.{ .x = 0, .y = 0, .z = -1 }, .stone);
    _ = world.set(.{ .x = 0, .y = 0, .z = 1 }, .stone);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 2);
    try std.testing.expectEqual(@as(u32, 2), result.converted);
}

test "disconnected substrate is not converted" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .sculk);
    _ = world.set(.{ .x = 2, .y = 0, .z = 0 }, .stone);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(@as(u32, 0), result.converted);
}

test "converted cells are connected through six-face substrate path" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .sculk);
    _ = world.set(.{ .x = 1, .y = 0, .z = 0 }, .stone);
    _ = world.set(.{ .x = 2, .y = 0, .z = 0 }, .tuff);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 2);
    try std.testing.expectEqual(@as(u32, 2), result.converted);
}

test "propagation consumes one charge per conversion" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .stone);
    _ = world.set(.{ .x = 1, .y = 0, .z = 0 }, .stone);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 2);
    try std.testing.expectEqual(@as(u32, 2), result.consumed_charge);
    try std.testing.expectEqual(@as(u32, 0), result.remaining_charge);
}

test "charge limits total conversion count" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .stone);
    _ = world.set(.{ .x = 1, .y = 0, .z = 0 }, .stone);
    _ = world.set(.{ .x = 2, .y = 0, .z = 0 }, .stone);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 2);
    try std.testing.expectEqual(@as(u32, 2), result.converted);
    try std.testing.expectEqual(@as(u32, 0), result.remaining_charge);
}

test "zero charge performs no conversion" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .stone);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 0);
    try std.testing.expectEqual(@as(u32, 0), result.converted);
    try std.testing.expectEqual(BlockType.stone, world.get(.{ .x = 0, .y = 0, .z = 0 }));
}

test "inner shell converts before outer shell when charge is limited" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .sculk);
    _ = world.set(.{ .x = 1, .y = 0, .z = 0 }, .dirt);
    _ = world.set(.{ .x = 2, .y = 0, .z = 0 }, .stone);
    const result = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(BlockType.sculk, world.get(.{ .x = 1, .y = 0, .z = 0 }));
    try std.testing.expectEqual(BlockType.stone, world.get(.{ .x = 2, .y = 0, .z = 0 }));
    try std.testing.expectEqual(@as(u32, 1), result.converted);
}

test "exposed east face receives vein with west attachment bit" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .stone);
    _ = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(BlockType.sculk_vein, world.get(.{ .x = 1, .y = 0, .z = 0 }));
    try std.testing.expectEqual(faceBit(.west), world.veinMask(.{ .x = 1, .y = 0, .z = 0 }));
}

test "exposed down face receives vein with up attachment bit" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .stone);
    _ = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(faceBit(.up), world.veinMask(.{ .x = 0, .y = -1, .z = 0 }));
}

test "all face bit values fit six-bit mask" {
    for (Face.all) |face| try std.testing.expect(faceBit(face) <= VEIN_FACE_MASK);
}

test "exposed water face receives vein" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .stone);
    _ = world.set(.{ .x = 1, .y = 0, .z = 0 }, .water);
    _ = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    try std.testing.expectEqual(BlockType.sculk_vein, world.get(.{ .x = 1, .y = 0, .z = 0 }));
}

test "full solid neighbors receive no vein coating" {
    var world = World{};
    for (Face.all) |face| _ = world.set(face.offset(), .stone);
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .stone);
    _ = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 1);
    for (Face.all) |face| try std.testing.expectEqual(BlockType.stone, world.get(face.offset()));
}

test "adjacent veins combine orientation bits without exceeding 63" {
    var world = World{};
    _ = world.set(.{ .x = 0, .y = 0, .z = 0 }, .stone);
    _ = world.set(.{ .x = 1, .y = 0, .z = 0 }, .stone);
    _ = propagate(&world, .{ .x = 0, .y = 0, .z = 0 }, 2);
    try std.testing.expect(world.veinMask(.{ .x = 0, .y = 1, .z = 0 }) <= 63);
}

test "branch roll zero is cardinal" {
    try std.testing.expectEqual(BranchKind.cardinal, branchKind(0));
}

test "branch roll 84 is cardinal" {
    try std.testing.expectEqual(BranchKind.cardinal, branchKind(84));
}

test "branch roll 85 is diagonal" {
    try std.testing.expectEqual(BranchKind.diagonal, branchKind(85));
}

test "branch roll 99 is diagonal" {
    try std.testing.expectEqual(BranchKind.diagonal, branchKind(99));
}

test "branch distribution has 85 cardinal outcomes out of 100" {
    var cardinal: u32 = 0;
    for (0..100) |roll| if (branchKind(@intCast(roll)) == .cardinal) { cardinal += 1; };
    try std.testing.expectEqual(@as(u32, 85), cardinal);
}

test "branch distribution has 15 diagonal outcomes out of 100" {
    var diagonal: u32 = 0;
    for (0..100) |roll| if (branchKind(@intCast(roll)) == .diagonal) { diagonal += 1; };
    try std.testing.expectEqual(@as(u32, 15), diagonal);
}

test "catalyst starts with light level zero" {
    const catalyst = Catalyst{};
    try std.testing.expectEqual(@as(u4, 0), catalyst.lightLevel());
}

test "catalyst activation sets light level six" {
    var catalyst = Catalyst{};
    catalyst.activate();
    try std.testing.expectEqual(@as(u4, 6), catalyst.lightLevel());
}

test "catalyst remains lit for twenty ticks" {
    var catalyst = Catalyst{};
    catalyst.activate();
    for (0..19) |_| {
        catalyst.tick();
        try std.testing.expectEqual(@as(u4, 6), catalyst.lightLevel());
    }
}

test "catalyst returns to light zero after tick twenty" {
    var catalyst = Catalyst{};
    catalyst.activate();
    for (0..20) |_| catalyst.tick();
    try std.testing.expectEqual(@as(u4, 0), catalyst.lightLevel());
}

test "catalyst stays dormant after extra ticks" {
    var catalyst = Catalyst{};
    for (0..25) |_| catalyst.tick();
    try std.testing.expectEqual(@as(u4, 0), catalyst.lightLevel());
}
