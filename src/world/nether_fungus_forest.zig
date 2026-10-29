const std = @import("std");

/// Block vocabulary used by the Nether fungus ecology simulation. The game
/// world adapter can map these values to its persisted block palette.
pub const BlockId = enum(u8) {
    air,
    netherrack,
    crimson_nylium,
    warped_nylium,
    crimson_fungus,
    warped_fungus,
    crimson_roots,
    warped_roots,
    nether_sprouts,
    weeping_vines,
    twisting_vines,
    crimson_stem,
    warped_stem,
    nether_wart_block,
    warped_wart_block,
    shroomlight,
    crimson_planks,
    warped_planks,
    crimson_slab,
    warped_slab,
    crimson_stairs,
    warped_stairs,
    crimson_fence,
    warped_fence,
    crimson_door,
    warped_door,
    crimson_trapdoor,
    warped_trapdoor,
    other,
};

pub const ItemType = enum {
    crimson_fungus,
    warped_fungus,
    crimson_roots,
    warped_roots,
    nether_sprouts,
    weeping_vines,
    twisting_vines,
    shroomlight,
};

pub const NyliumType = enum { crimson_nylium, warped_nylium };
pub const FungusType = enum { crimson, warped };

pub const GRID_X: usize = 31;
pub const GRID_Y: usize = 40;
pub const GRID_Z: usize = 31;
const GRID_VOLUME = GRID_X * GRID_Y * GRID_Z;

pub const ForestWorld = struct {
    blocks: [GRID_VOLUME]BlockId = [_]BlockId{.air} ** GRID_VOLUME,

    pub fn get(self: *const ForestWorld, x: i32, y: i32, z: i32) BlockId {
        const index = worldIndex(x, y, z) orelse return .other;
        return self.blocks[index];
    }

    pub fn set(self: *ForestWorld, x: i32, y: i32, z: i32, block: BlockId) bool {
        const index = worldIndex(x, y, z) orelse return false;
        self.blocks[index] = block;
        return true;
    }
};

fn worldIndex(x: i32, y: i32, z: i32) ?usize {
    if (x < 0 or y < 0 or z < 0 or x >= GRID_X or y >= GRID_Y or z >= GRID_Z) return null;
    return (@as(usize, @intCast(y)) * GRID_Z + @as(usize, @intCast(z))) * GRID_X + @as(usize, @intCast(x));
}

pub fn nyliumBlock(kind: NyliumType) BlockId {
    return switch (kind) {
        .crimson_nylium => .crimson_nylium,
        .warped_nylium => .warped_nylium,
    };
}

pub fn fungusKind(block: BlockId) ?FungusType {
    return switch (block) {
        .crimson_fungus => .crimson,
        .warped_fungus => .warped,
        else => null,
    };
}

pub fn isNylium(block: BlockId) bool {
    return block == .crimson_nylium or block == .warped_nylium;
}

/// Bone meal creates a 3x3 or 5x5 search area. Vegetation is planted only on
/// matching nylium, with an empty block above it; the center is included.
pub fn applyBoneMealToNylium(world: *ForestWorld, x: i32, y: i32, z: i32, kind: NyliumType, roll: f32) u8 {
    if (world.get(x, y, z) != nyliumBlock(kind)) return 0;
    const radius: i32 = if (roll < 0.5) 1 else 2;
    var placed: u8 = 0;
    var dz = -radius;
    while (dz <= radius) : (dz += 1) {
        var dx = -radius;
        while (dx <= radius) : (dx += 1) {
            const px = x + dx;
            const pz = z + dz;
            if (world.get(px, y, pz) != nyliumBlock(kind) or world.get(px, y + 1, pz) != .air) continue;
            // A stable coordinate hash keeps the mechanic deterministic while
            // leaving a varied carpet instead of filling every cell.
            if (@mod(@abs(px * 31 + pz * 17 + x * 13 + z * 7), 3) != 0) continue;
            if (world.set(px, y + 1, pz, sproutFor(kind, px, pz))) placed += 1;
        }
    }
    return placed;
}

fn sproutFor(kind: NyliumType, x: i32, z: i32) BlockId {
    const modulus: u32 = if (kind == .warped_nylium) 4 else 3;
    const selector = @mod(@abs(x * 11 + z * 19), modulus);
    return switch (kind) {
        .crimson_nylium => switch (selector) {
            0 => .crimson_fungus,
            1 => .crimson_roots,
            else => .weeping_vines,
        },
        .warped_nylium => switch (selector) {
            0 => .warped_fungus,
            1 => .warped_roots,
            2 => .nether_sprouts,
            else => .twisting_vines,
        },
    };
}

pub fn sproutItem(block: BlockId) ?ItemType {
    return switch (block) {
        .crimson_fungus => .crimson_fungus,
        .warped_fungus => .warped_fungus,
        .crimson_roots => .crimson_roots,
        .warped_roots => .warped_roots,
        .nether_sprouts => .nether_sprouts,
        .weeping_vines => .weeping_vines,
        .twisting_vines => .twisting_vines,
        else => null,
    };
}

pub const FungusPlant = struct {
    kind: FungusType,
    growth_attempts: u3 = 0,
};

pub const GrowthResult = struct {
    width: u8,
    height: u8,
    trunk_width: u8,
    shroomlights: u8,
    vegetation_count: u16,
};

/// Returns true when a roll grows the plant. The first three attempts each
/// have a 40% chance; the fourth guarantees growth to bound repeated feeding.
pub fn rollFungusGrowth(plant: *FungusPlant, roll: f32) bool {
    if (plant.growth_attempts >= 4) return false;
    plant.growth_attempts += 1;
    return roll < 0.4 or plant.growth_attempts == 4;
}

/// Grows a complete giant fungus only when the supporting nylium matches.
/// width_roll/height_roll/light_roll select deterministic geometry for tests
/// and callers; rolls are clamped into the supported architecture ranges.
pub fn growHugeFungus(
    world: *ForestWorld,
    x: i32,
    y: i32,
    z: i32,
    plant: *FungusPlant,
    growth_roll: f32,
    width_roll: f32,
    height_roll: f32,
    light_roll: f32,
) ?GrowthResult {
    const required_nylium: BlockId = if (plant.kind == .crimson) .crimson_nylium else .warped_nylium;
    const planted_fungus: BlockId = if (plant.kind == .crimson) .crimson_fungus else .warped_fungus;
    if (world.get(x, y, z) != planted_fungus or world.get(x, y - 1, z) != required_nylium) return null;
    if (!rollFungusGrowth(plant, growth_roll)) return null;

    const width: u8 = 7 + @as(u8, @intFromFloat(clampRoll(width_roll) * 2.999));
    const height: u8 = 4 + @as(u8, @intFromFloat(clampRoll(height_roll) * 23.999));
    const trunk_width: u8 = if (width_roll < 0.5) 1 else 3;
    const lights: u8 = 1 + @as(u8, @intFromFloat(clampRoll(light_roll) * 4.999));
    if (y + height >= GRID_Y) return null;

    const stem: BlockId = if (plant.kind == .crimson) .crimson_stem else .warped_stem;
    const cap: BlockId = if (plant.kind == .crimson) .nether_wart_block else .warped_wart_block;
    const trunk_offset: i32 = @divTrunc(trunk_width, 2);
    var dy: i32 = 0;
    while (dy < height) : (dy += 1) {
        var tx: i32 = -trunk_offset;
        while (tx < trunk_width - trunk_offset) : (tx += 1) {
            var tz: i32 = -trunk_offset;
            while (tz < trunk_width - trunk_offset) : (tz += 1) {
                _ = world.set(x + tx, y + dy, z + tz, stem);
            }
        }
    }

    const canopy_start = y + height - 3;
    const left: i32 = -@divTrunc(@as(i32, width), 2);
    const right: i32 = left + width - 1;
    var canopy_blocks: [9 * 9 * 4]usize = undefined;
    var canopy_count: usize = 0;
    dy = canopy_start;
    while (dy <= y + height) : (dy += 1) {
        const taper: i32 = if (dy == canopy_start or dy == y + height) 1 else 0;
        var cz = left + taper;
        while (cz <= right - taper) : (cz += 1) {
            var cx = left + taper;
            while (cx <= right - taper) : (cx += 1) {
                if (world.set(x + cx, dy, z + cz, cap)) {
                    canopy_blocks[canopy_count] = worldIndex(x + cx, dy, z + cz).?;
                    canopy_count += 1;
                }
            }
        }
    }

    var inserted: u8 = 0;
    var scan: usize = 0;
    while (inserted < lights and scan < canopy_count) : (scan += 1) {
        const index = canopy_blocks[scan];
        if (world.blocks[index] != cap) continue;
        world.blocks[index] = .shroomlight;
        inserted += 1;
    }

    var vegetation: u16 = 0;
    if (plant.kind == .crimson) {
        // Crimson vines hang down from canopy edges.
        var vine_x = x + left;
        while (vine_x <= x + right) : (vine_x += 2) {
            var vine_z = z + left;
            while (vine_z <= z + right) : (vine_z += 2) {
                var vine_y = canopy_start - 1;
                const vine_len: i32 = 1 + @as(i32, @intCast(@mod(@abs(vine_x * 3 + vine_z * 5), 4)));
                while (vine_y >= canopy_start - vine_len and vine_y >= y and world.get(vine_x, vine_y, vine_z) == .air) : (vine_y -= 1) {
                    _ = world.set(vine_x, vine_y, vine_z, .weeping_vines);
                    vegetation += 1;
                }
            }
        }
    } else {
        // Warped twisting vines grow upward on the surrounding nylium.
        var vx = x + left - 1;
        while (vx <= x + right + 1) : (vx += 2) {
            var vz = z + left - 1;
            while (vz <= z + right + 1) : (vz += 2) {
                if (vx >= x + left and vx <= x + right and vz >= z + left and vz <= z + right) continue;
                if (!isNylium(world.get(vx, y - 1, vz))) continue;
                var vine_y = y;
                const vine_len: i32 = 1 + @as(i32, @intCast(@mod(@abs(vx * 7 + vz * 11), 4)));
                while (vine_y < y + vine_len and world.get(vx, vine_y, vz) == .air) : (vine_y += 1) {
                    _ = world.set(vx, vine_y, vz, .twisting_vines);
                    vegetation += 1;
                }
            }
        }
    }

    return .{ .width = width, .height = height, .trunk_width = trunk_width, .shroomlights = inserted, .vegetation_count = vegetation };
}

fn clampRoll(roll: f32) f32 {
    return @min(@max(roll, 0.0), 0.9999);
}

pub fn shroomlightEmission(block: BlockId) u4 {
    return if (block == .shroomlight) 15 else 0;
}

/// Nether wood is immune to both direct fire spread and burning damage.
pub fn isFlammable(block: BlockId) bool {
    return switch (block) {
        .crimson_stem, .warped_stem, .crimson_planks, .warped_planks, .crimson_slab, .warped_slab, .crimson_stairs, .warped_stairs, .crimson_fence, .warped_fence, .crimson_door, .warped_door, .crimson_trapdoor, .warped_trapdoor => false,
        else => false,
    };
}

test "crimson nylium bone meal grows only crimson vegetation" {
    var world = ForestWorld{};
    var dz: i32 = 9;
    while (dz < 14) : (dz += 1) {
        var dx: i32 = 9;
        while (dx < 14) : (dx += 1) _ = world.set(dx, 10, dz, .crimson_nylium);
    }
    const count = applyBoneMealToNylium(&world, 11, 10, 11, .crimson_nylium, 0.8);
    try std.testing.expect(count > 0);
    var crimson_seen = false;
    for (world.blocks) |block| {
        if (block == .crimson_fungus or block == .crimson_roots or block == .weeping_vines) crimson_seen = true;
        try std.testing.expect(block != .warped_fungus and block != .warped_roots and block != .nether_sprouts and block != .twisting_vines);
    }
    try std.testing.expect(crimson_seen);
}

test "warped nylium bone meal grows warped vegetation" {
    var world = ForestWorld{};
    var dz: i32 = 8;
    while (dz < 13) : (dz += 1) {
        var dx: i32 = 8;
        while (dx < 13) : (dx += 1) _ = world.set(dx, 7, dz, .warped_nylium);
    }
    try std.testing.expect(applyBoneMealToNylium(&world, 10, 7, 10, .warped_nylium, 0.9) > 0);
    var warped_seen = false;
    for (world.blocks) |block| if (block == .warped_fungus or block == .warped_roots or block == .nether_sprouts) {
        warped_seen = true;
    };
    try std.testing.expect(warped_seen);
}

test "bone meal nylium rejects mismatched soil" {
    var world = ForestWorld{};
    _ = world.set(10, 5, 10, .crimson_nylium);
    try std.testing.expectEqual(@as(u8, 0), applyBoneMealToNylium(&world, 10, 5, 10, .warped_nylium, 0.2));
}

test "bone meal sprouts stay within 5 by 5 search area" {
    var world = ForestWorld{};
    var z: i32 = 5;
    while (z <= 15) : (z += 1) {
        var x: i32 = 5;
        while (x <= 15) : (x += 1) _ = world.set(x, 5, z, .crimson_nylium);
    }
    _ = applyBoneMealToNylium(&world, 10, 5, 10, .crimson_nylium, 0.99);
    for (world.blocks, 0..) |block, index| if (block == .crimson_fungus or block == .crimson_roots or block == .weeping_vines) {
        const px: i32 = @intCast(index % GRID_X);
        const pz: i32 = @intCast((index / GRID_X) % GRID_Z);
        try std.testing.expect(@abs(px - 10) <= 2 and @abs(pz - 10) <= 2);
    };
}

test "crimson vegetation selector includes all supported sprouts" {
    var seen = [_]bool{false} ** 3;
    for (0..100) |i| {
        const block = sproutFor(.crimson_nylium, @intCast(i), @intCast(i * 5));
        if (block == .crimson_fungus) seen[0] = true else if (block == .crimson_roots) seen[1] = true else if (block == .weeping_vines) seen[2] = true;
    }
    try std.testing.expect(seen[0] and seen[1] and seen[2]);
}

test "warped vegetation selector includes sprouts roots and fungus" {
    var seen = [_]bool{false} ** 4;
    for (0..100) |i| {
        const block = sproutFor(.warped_nylium, @intCast(i), @intCast(i * 2));
        if (block == .warped_fungus) seen[0] = true else if (block == .warped_roots) seen[1] = true else if (block == .nether_sprouts) seen[2] = true;
        if (block == .twisting_vines) seen[3] = true;
    }
    try std.testing.expect(seen[0] and seen[1] and seen[2] and seen[3]);
}

test "growth requires a fungus on matching crimson nylium" {
    var world = ForestWorld{};
    _ = world.set(15, 10, 15, .crimson_nylium);
    _ = world.set(15, 11, 15, .crimson_fungus);
    var plant = FungusPlant{ .kind = .crimson };
    try std.testing.expect(growHugeFungus(&world, 15, 11, 15, &plant, 0.1, 0.5, 0.5, 0.2) != null);
}

test "growth requires a fungus on matching warped nylium" {
    var world = ForestWorld{};
    _ = world.set(15, 10, 15, .warped_nylium);
    _ = world.set(15, 11, 15, .warped_fungus);
    var plant = FungusPlant{ .kind = .warped };
    try std.testing.expect(growHugeFungus(&world, 15, 11, 15, &plant, 0.1, 0.5, 0.5, 0.2) != null);
}

test "mismatched nylium rejects crimson growth" {
    var world = ForestWorld{};
    _ = world.set(15, 10, 15, .warped_nylium);
    _ = world.set(15, 11, 15, .crimson_fungus);
    var plant = FungusPlant{ .kind = .crimson };
    try std.testing.expect(growHugeFungus(&world, 15, 11, 15, &plant, 0.1, 0.5, 0.5, 0.2) == null);
}

test "mismatched nylium rejects warped growth" {
    var world = ForestWorld{};
    _ = world.set(15, 10, 15, .crimson_nylium);
    _ = world.set(15, 11, 15, .warped_fungus);
    var plant = FungusPlant{ .kind = .warped };
    try std.testing.expect(growHugeFungus(&world, 15, 11, 15, &plant, 0.1, 0.5, 0.5, 0.2) == null);
}

test "fungus planted on non nylium cannot grow" {
    var world = ForestWorld{};
    _ = world.set(15, 10, 15, .netherrack);
    _ = world.set(15, 11, 15, .warped_fungus);
    var plant = FungusPlant{ .kind = .warped };
    try std.testing.expect(growHugeFungus(&world, 15, 11, 15, &plant, 0.1, 0.5, 0.5, 0.2) == null);
}

test "growth rejects when fungus is absent" {
    var world = ForestWorld{};
    _ = world.set(15, 10, 15, .warped_nylium);
    var plant = FungusPlant{ .kind = .warped };
    try std.testing.expect(growHugeFungus(&world, 15, 11, 15, &plant, 0.1, 0.5, 0.5, 0.2) == null);
}

test "growth chance succeeds below forty percent threshold" {
    var plant = FungusPlant{ .kind = .crimson };
    try std.testing.expect(rollFungusGrowth(&plant, 0.39));
}

test "growth chance fails above forty percent threshold before fourth attempt" {
    var plant = FungusPlant{ .kind = .crimson };
    try std.testing.expect(!rollFungusGrowth(&plant, 0.4));
    try std.testing.expect(!rollFungusGrowth(&plant, 0.99));
}

test "fungus growth is guaranteed on fourth bone meal attempt" {
    var plant = FungusPlant{ .kind = .warped };
    try std.testing.expect(!rollFungusGrowth(&plant, 0.99));
    try std.testing.expect(!rollFungusGrowth(&plant, 0.99));
    try std.testing.expect(!rollFungusGrowth(&plant, 0.99));
    try std.testing.expect(rollFungusGrowth(&plant, 0.99));
    try std.testing.expect(!rollFungusGrowth(&plant, 0.0));
}

test "growth width is between seven and nine blocks" {
    for ([_]f32{ 0.0, 0.5, 0.999 }) |roll| {
        var world = ForestWorld{};
        _ = world.set(15, 5, 15, .crimson_nylium);
        _ = world.set(15, 6, 15, .crimson_fungus);
        var plant = FungusPlant{ .kind = .crimson };
        const result = growHugeFungus(&world, 15, 6, 15, &plant, 0.0, roll, 0.5, 0.2).?;
        try std.testing.expect(result.width >= 7 and result.width <= 9);
    }
}

test "growth height is between four and twenty seven blocks" {
    for ([_]f32{ 0.0, 0.5, 0.999 }) |roll| {
        var world = ForestWorld{};
        _ = world.set(15, 5, 15, .warped_nylium);
        _ = world.set(15, 6, 15, .warped_fungus);
        var plant = FungusPlant{ .kind = .warped };
        const result = growHugeFungus(&world, 15, 6, 15, &plant, 0.0, 0.5, roll, 0.2).?;
        try std.testing.expect(result.height >= 4 and result.height <= 27);
    }
}

test "crimson tree trunk is stem and has one or three block thickness" {
    var world = ForestWorld{};
    _ = world.set(15, 5, 15, .crimson_nylium);
    _ = world.set(15, 6, 15, .crimson_fungus);
    var plant = FungusPlant{ .kind = .crimson };
    const result = growHugeFungus(&world, 15, 6, 15, &plant, 0.0, 0.2, 0.2, 0.2).?;
    try std.testing.expectEqual(@as(u8, 1), result.trunk_width);
    try std.testing.expectEqual(BlockId.crimson_stem, world.get(15, 6, 15));
}

test "warped tree supports three by three stem base" {
    var world = ForestWorld{};
    _ = world.set(15, 5, 15, .warped_nylium);
    _ = world.set(15, 6, 15, .warped_fungus);
    var plant = FungusPlant{ .kind = .warped };
    const result = growHugeFungus(&world, 15, 6, 15, &plant, 0.0, 0.9, 0.2, 0.2).?;
    try std.testing.expectEqual(@as(u8, 3), result.trunk_width);
    try std.testing.expectEqual(BlockId.warped_stem, world.get(14, 6, 14));
    try std.testing.expectEqual(BlockId.warped_stem, world.get(16, 6, 16));
}

test "crimson canopy is nether wart block" {
    var world = ForestWorld{};
    _ = world.set(15, 5, 15, .crimson_nylium);
    _ = world.set(15, 6, 15, .crimson_fungus);
    var plant = FungusPlant{ .kind = .crimson };
    _ = growHugeFungus(&world, 15, 6, 15, &plant, 0.0, 0.5, 0.2, 0.0).?;
    try std.testing.expectEqual(BlockId.nether_wart_block, world.get(15, 12, 15));
}

test "warped canopy is warped wart block" {
    var world = ForestWorld{};
    _ = world.set(15, 5, 15, .warped_nylium);
    _ = world.set(15, 6, 15, .warped_fungus);
    var plant = FungusPlant{ .kind = .warped };
    _ = growHugeFungus(&world, 15, 6, 15, &plant, 0.0, 0.5, 0.2, 0.0).?;
    try std.testing.expectEqual(BlockId.warped_wart_block, world.get(15, 12, 15));
}

test "giant fungus inserts one to five shroomlights" {
    for ([_]f32{ 0.0, 0.25, 0.5, 0.75, 0.999 }) |roll| {
        var world = ForestWorld{};
        _ = world.set(15, 5, 15, .crimson_nylium);
        _ = world.set(15, 6, 15, .crimson_fungus);
        var plant = FungusPlant{ .kind = .crimson };
        const result = growHugeFungus(&world, 15, 6, 15, &plant, 0.0, 0.5, 0.3, roll).?;
        try std.testing.expect(result.shroomlights >= 1 and result.shroomlights <= 5);
    }
}

test "shroomlight emits light level fifteen" {
    try std.testing.expectEqual(@as(u4, 15), shroomlightEmission(.shroomlight));
    try std.testing.expectEqual(@as(u4, 0), shroomlightEmission(.crimson_stem));
}

test "crimson canopy generates hanging weeping vines" {
    var world = ForestWorld{};
    _ = world.set(15, 5, 15, .crimson_nylium);
    _ = world.set(15, 6, 15, .crimson_fungus);
    var plant = FungusPlant{ .kind = .crimson };
    const result = growHugeFungus(&world, 15, 6, 15, &plant, 0.0, 0.5, 0.3, 0.0).?;
    try std.testing.expect(result.vegetation_count > 0);
    var vines: usize = 0;
    for (world.blocks) |block| if (block == .weeping_vines) {
        vines += 1;
    };
    try std.testing.expect(vines > 0);
}

test "warped tree generates upward twisting vines around base" {
    var world = ForestWorld{};
    var z: i32 = 9;
    while (z <= 21) : (z += 1) {
        var x: i32 = 9;
        while (x <= 21) : (x += 1) _ = world.set(x, 5, z, .warped_nylium);
    }
    _ = world.set(15, 6, 15, .warped_fungus);
    var plant = FungusPlant{ .kind = .warped };
    const result = growHugeFungus(&world, 15, 6, 15, &plant, 0.0, 0.5, 0.3, 0.0).?;
    try std.testing.expect(result.vegetation_count > 0);
    var vines: usize = 0;
    for (world.blocks) |block| if (block == .twisting_vines) {
        vines += 1;
    };
    try std.testing.expect(vines > 0);
}

test "nether wood families are nonflammable" {
    const wood = [_]BlockId{
        .crimson_stem,     .warped_stem,     .crimson_planks, .warped_planks,
        .crimson_slab,     .warped_slab,     .crimson_stairs, .warped_stairs,
        .crimson_fence,    .warped_fence,    .crimson_door,   .warped_door,
        .crimson_trapdoor, .warped_trapdoor,
    };
    for (wood) |block| try std.testing.expect(!isFlammable(block));
}

test "crimson and warped fungi map to their tree species" {
    try std.testing.expectEqual(FungusType.crimson, fungusKind(.crimson_fungus).?);
    try std.testing.expectEqual(FungusType.warped, fungusKind(.warped_fungus).?);
    try std.testing.expect(fungusKind(.netherrack) == null);
}

test "world bounds safely reject out of range edits" {
    var world = ForestWorld{};
    try std.testing.expect(!world.set(-1, 0, 0, .crimson_nylium));
    try std.testing.expectEqual(BlockId.other, world.get(-1, 0, 0));
}
