//! Mangrove prop-root structure, mud hydration, and mud-brick masonry rules.
//! World and inventory owners apply the returned edits and item transfers.

pub const MUD_HARDNESS: f32 = 0.5;
pub const PACKED_MUD_HARDNESS: f32 = 1.0;
pub const MUD_BRICKS_HARDNESS: f32 = 1.5;
pub const MUD_BRICKS_BLAST_RESISTANCE: f32 = 3.0;
pub const MANGROVE_ROOTS_HARDNESS: f32 = 0.7;
pub const MUDDY_MANGROVE_ROOTS_HARDNESS: f32 = 0.7;
pub const MUD_BRICK_WALL_COLLISION_HEIGHT: f32 = 1.5;
pub const MUD_BRICK_SLAB_COLLISION_HEIGHT: f32 = 0.5;
pub const MUD_BRICK_STAIR_COLLISION_HEIGHT: f32 = 1.0;

pub const BlockId = enum {
    air,
    dirt,
    coarse_dirt,
    rooted_dirt,
    mud,
    packed_mud,
    mud_bricks,
    mangrove_roots,
    muddy_mangrove_roots,
};

pub const ItemType = enum {
    none,
    water_bottle,
    glass_bottle,
    dirt,
    coarse_dirt,
    rooted_dirt,
    mud,
    wheat,
    packed_mud,
    mud_bricks,
    mud_brick_slab,
    mud_brick_stairs,
    mud_brick_wall,
    mangrove_roots,
    muddy_mangrove_roots,
    axe,
    other_tool,
};

pub const ItemStack = struct {
    item: ItemType = .none,
    count: u8 = 0,
};

pub const HydrationResult = struct {
    changed: bool = false,
    block: BlockId = .air,
    held_item: ItemStack = .{},
    returned_container: ItemStack = .{},
};

/// Simulates a right-click with a water bottle on a dirt-family block.
pub fn hydrateDirt(target: BlockId, held: ItemStack) HydrationResult {
    if (held.item != .water_bottle or held.count == 0) return .{ .block = target, .held_item = held };
    if (target != .dirt and target != .coarse_dirt and target != .rooted_dirt) {
        return .{ .block = target, .held_item = held };
    }
    const remainder = held.count - 1;
    return .{
        .changed = true,
        .block = .mud,
        .held_item = if (remainder == 0)
            .{ .item = .glass_bottle, .count = 1 }
        else
            .{ .item = .water_bottle, .count = remainder },
        .returned_container = if (remainder == 0) .{} else .{ .item = .glass_bottle, .count = 1 },
    };
}

pub const Recipe = enum { packed_mud, mud_bricks, mud_brick_slabs, mud_brick_stairs, mud_brick_walls };
pub const RecipeResult = struct { item: ItemType, count: u8 };

/// Matches a shapeless 2x2 inventory recipe by ingredient counts.
pub fn craft2x2(slots: [4]ItemStack) ?RecipeResult {
    var non_empty: u8 = 0;
    var mud: u8 = 0;
    var wheat: u8 = 0;
    var packed_mud: u8 = 0;
    for (slots) |slot| {
        if (slot.count == 0 or slot.item == .none) continue;
        non_empty += 1;
        switch (slot.item) {
            .mud => mud += slot.count,
            .wheat => wheat += slot.count,
            .packed_mud => packed_mud += slot.count,
            .mud_bricks => {},
            else => {},
        }
    }
    if (non_empty == 2 and mud == 1 and wheat == 1) return .{ .item = .packed_mud, .count = 1 };
    if (non_empty == 4 and packed_mud == 4) return .{ .item = .mud_bricks, .count = 4 };
    return null;
}

/// Crafting-grid shaped recipes for slabs (3 in a row), stairs (6), and walls (6).
/// Since a 2x2 grid cannot hold the 3x2 masonry layouts, this accepts a 3x3 grid.
pub fn craftMasonry3x3(slots: [9]ItemStack, recipe: Recipe) ?RecipeResult {
    var bricks: u8 = 0;
    var non_empty: u8 = 0;
    for (slots) |slot| {
        if (slot.count == 0 or slot.item == .none) continue;
        non_empty += 1;
        if (slot.item == .mud_bricks) bricks += slot.count else return null;
    }
    return switch (recipe) {
        .mud_brick_slabs => if (non_empty == 3 and bricks == 3 and rowOfThree(slots)) .{ .item = .mud_brick_slab, .count = 6 } else null,
        .mud_brick_stairs => if (non_empty == 6 and bricks == 6 and stairsShape(slots)) .{ .item = .mud_brick_stairs, .count = 4 } else null,
        .mud_brick_walls => if (non_empty == 6 and bricks == 6 and twoRowsOfThree(slots)) .{ .item = .mud_brick_wall, .count = 6 } else null,
        else => null,
    };
}

fn rowOfThree(slots: [9]ItemStack) bool {
    for (0..3) |row| {
        var count: u8 = 0;
        for (0..3) |col| if (slots[row * 3 + col].item == .mud_bricks and slots[row * 3 + col].count > 0) {
            count += 1;
        };
        if (count == 3) return true;
    }
    return false;
}

fn twoRowsOfThree(slots: [9]ItemStack) bool {
    for (0..2) |row| {
        var count: u8 = 0;
        for (0..3) |col| {
            const a = slots[row * 3 + col];
            const b = slots[(row + 1) * 3 + col];
            if (a.item == .mud_bricks and a.count > 0 and b.item == .mud_bricks and b.count > 0) count += 2;
        }
        if (count == 6) return true;
    }
    return false;
}

fn stairsShape(slots: [9]ItemStack) bool {
    const patterns = [_][6]usize{
        .{ 0, 3, 4, 6, 7, 8 }, .{ 2, 4, 5, 6, 7, 8 },
    };
    for (patterns) |pattern| {
        var matches = true;
        for (pattern) |index| matches = matches and slots[index].item == .mud_bricks and slots[index].count > 0;
        if (matches) return true;
    }
    return false;
}

pub const StonecutterResult = struct { item: ItemType, count: u8 };
pub const StonecutterCut = enum { slab, stairs, wall };

pub fn stonecutMudBricks(input: ItemStack, cut: StonecutterCut) ?StonecutterResult {
    if (input.item != .mud_bricks or input.count == 0) return null;
    return switch (cut) {
        .slab => .{ .item = .mud_brick_slab, .count = 2 },
        .stairs => .{ .item = .mud_brick_stairs, .count = 1 },
        .wall => .{ .item = .mud_brick_wall, .count = 1 },
    };
}

pub fn collisionHeight(item: ItemType) ?f32 {
    return switch (item) {
        .mud_brick_slab => MUD_BRICK_SLAB_COLLISION_HEIGHT,
        .mud_brick_stairs => MUD_BRICK_STAIR_COLLISION_HEIGHT,
        .mud_brick_wall => MUD_BRICK_WALL_COLLISION_HEIGHT,
        else => null,
    };
}

pub fn isMinableWithAxe(block: BlockId) bool {
    return block == .mangrove_roots or block == .muddy_mangrove_roots;
}

pub fn hardness(block: BlockId) ?f32 {
    return switch (block) {
        .mud => MUD_HARDNESS,
        .packed_mud => PACKED_MUD_HARDNESS,
        .mud_bricks => MUD_BRICKS_HARDNESS,
        .mangrove_roots => MANGROVE_ROOTS_HARDNESS,
        .muddy_mangrove_roots => MUDDY_MANGROVE_ROOTS_HARDNESS,
        else => null,
    };
}

pub const RootSegment = struct { x: i8, y: i8, z: i8, waterlogged: bool };
pub const RootCage = struct { segments: [8]RootSegment, radius: u2, count: u4 };

/// Returns four outward/downward root arches around a trunk, leaving its center open.
/// Radius is clamped to the specified 1..3 block span; each arm has two segments.
pub fn generateRootCage(requested_radius: u8, water_at: [4]bool) RootCage {
    const radius: u8 = @min(3, @max(1, requested_radius));
    const radial: i8 = @intCast(radius);
    const inner: i8 = @intCast(@max(1, radius - 1));
    const directions = [_][2]i8{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };
    var result = RootCage{ .segments = undefined, .radius = @intCast(radius), .count = 8 };
    for (directions, 0..) |dir, index| {
        result.segments[index * 2] = .{ .x = dir[0] * inner, .y = 0, .z = dir[1] * inner, .waterlogged = water_at[index] };
        result.segments[index * 2 + 1] = .{ .x = dir[0] * radial, .y = -1, .z = dir[1] * radial, .waterlogged = water_at[index] };
    }
    return result;
}

pub const WaterloggedState = struct { is_waterlogged: bool = false };

/// Placing mangrove roots in a water cell preserves water as block metadata.
pub fn placeMangroveRoots(in_water: bool) WaterloggedState {
    return .{ .is_waterlogged = in_water };
}

pub fn craftMuddyMangroveRoots(mud_count: u8, roots_count: u8) ?RecipeResult {
    if (mud_count != 1 or roots_count != 1) return null;
    return .{ .item = .muddy_mangrove_roots, .count = 1 };
}

// Unit coverage intentionally keeps the world and inventory owners decoupled.
test "water bottle hydrates ordinary dirt" {
    const result = hydrateDirt(.dirt, .{ .item = .water_bottle, .count = 1 });
    try @import("std").testing.expect(result.changed);
    try @import("std").testing.expectEqual(BlockId.mud, result.block);
}
test "coarse dirt hydrates to mud" {
    try @import("std").testing.expect(hydrateDirt(.coarse_dirt, .{ .item = .water_bottle, .count = 1 }).changed);
}
test "rooted dirt hydrates to mud" {
    try @import("std").testing.expect(hydrateDirt(.rooted_dirt, .{ .item = .water_bottle, .count = 1 }).changed);
}
test "water bottle becomes glass bottle when emptied" {
    const result = hydrateDirt(.dirt, .{ .item = .water_bottle, .count = 1 });
    try @import("std").testing.expectEqual(ItemType.glass_bottle, result.held_item.item);
}
test "stacked water bottles leave remaining bottles" {
    const result = hydrateDirt(.dirt, .{ .item = .water_bottle, .count = 3 });
    try @import("std").testing.expectEqual(@as(u8, 2), result.held_item.count);
    try @import("std").testing.expectEqual(ItemType.water_bottle, result.held_item.item);
    try @import("std").testing.expectEqual(ItemType.glass_bottle, result.returned_container.item);
}
test "empty bottle stack does not hydrate" {
    try @import("std").testing.expect(!hydrateDirt(.dirt, .{ .item = .water_bottle }).changed);
}
test "water bottle does not hydrate stone-like mud target" {
    try @import("std").testing.expect(!hydrateDirt(.mud, .{ .item = .water_bottle, .count = 1 }).changed);
}
test "wrong held item does not hydrate dirt" {
    try @import("std").testing.expect(!hydrateDirt(.dirt, .{ .item = .wheat, .count = 1 }).changed);
}
test "mud plus wheat crafts packed mud" {
    const output = craft2x2(.{ .{ .item = .mud, .count = 1 }, .{ .item = .wheat, .count = 1 }, .{}, .{} }).?;
    try @import("std").testing.expectEqual(ItemType.packed_mud, output.item);
}
test "packed mud recipe yields one" {
    const output = craft2x2(.{ .{ .item = .mud, .count = 1 }, .{ .item = .wheat, .count = 1 }, .{}, .{} }).?;
    try @import("std").testing.expectEqual(@as(u8, 1), output.count);
}
test "four packed mud craft four mud bricks" {
    const output = craft2x2(.{ .{ .item = .packed_mud, .count = 1 }, .{ .item = .packed_mud, .count = 1 }, .{ .item = .packed_mud, .count = 1 }, .{ .item = .packed_mud, .count = 1 } }).?;
    try @import("std").testing.expectEqual(ItemType.mud_bricks, output.item);
    try @import("std").testing.expectEqual(@as(u8, 4), output.count);
}
test "three mud bricks in a row craft six slabs" {
    var slots = [_]ItemStack{.{}} ** 9;
    slots[0] = .{ .item = .mud_bricks, .count = 1 };
    slots[1] = slots[0];
    slots[2] = slots[0];
    const output = craftMasonry3x3(slots, .mud_brick_slabs).?;
    try @import("std").testing.expectEqual(@as(u8, 6), output.count);
}
test "six mud bricks craft four stairs" {
    var slots = [_]ItemStack{.{}} ** 9;
    for ([_]usize{ 0, 3, 4, 6, 7, 8 }) |i| slots[i] = .{ .item = .mud_bricks, .count = 1 };
    try @import("std").testing.expectEqual(@as(u8, 4), craftMasonry3x3(slots, .mud_brick_stairs).?.count);
}
test "mirrored stair recipe crafts four stairs" {
    var slots = [_]ItemStack{.{}} ** 9;
    for ([_]usize{ 2, 4, 5, 6, 7, 8 }) |i| slots[i] = .{ .item = .mud_bricks, .count = 1 };
    try @import("std").testing.expectEqual(@as(u8, 4), craftMasonry3x3(slots, .mud_brick_stairs).?.count);
}
test "six mud bricks craft six walls" {
    var slots = [_]ItemStack{.{}} ** 9;
    for (0..6) |i| slots[i] = .{ .item = .mud_bricks, .count = 1 };
    try @import("std").testing.expectEqual(@as(u8, 6), craftMasonry3x3(slots, .mud_brick_walls).?.count);
}
test "slab crafting rejects non-row arrangement" {
    var slots = [_]ItemStack{.{}} ** 9;
    for ([_]usize{ 0, 4, 8 }) |i| slots[i] = .{ .item = .mud_bricks, .count = 1 };
    try @import("std").testing.expect(craftMasonry3x3(slots, .mud_brick_slabs) == null);
}
test "stair crafting rejects wrong material" {
    var slots = [_]ItemStack{.{}} ** 9;
    for (0..6) |i| slots[i] = .{ .item = .mud, .count = 1 };
    try @import("std").testing.expect(craftMasonry3x3(slots, .mud_brick_stairs) == null);
}
test "stair crafting rejects an unshaped brick cluster" {
    var slots = [_]ItemStack{.{}} ** 9;
    for ([_]usize{ 0, 1, 2, 3, 4, 5 }) |i| slots[i] = .{ .item = .mud_bricks, .count = 1 };
    try @import("std").testing.expect(craftMasonry3x3(slots, .mud_brick_stairs) == null);
}
test "stonecutter makes two slabs" {
    try @import("std").testing.expectEqual(@as(u8, 2), stonecutMudBricks(.{ .item = .mud_bricks, .count = 1 }, .slab).?.count);
}
test "stonecutter makes one stair" {
    try @import("std").testing.expectEqual(@as(u8, 1), stonecutMudBricks(.{ .item = .mud_bricks, .count = 1 }, .stairs).?.count);
}
test "stonecutter makes one wall" {
    try @import("std").testing.expectEqual(ItemType.mud_brick_wall, stonecutMudBricks(.{ .item = .mud_bricks, .count = 1 }, .wall).?.item);
}
test "stonecutter rejects other items" {
    try @import("std").testing.expect(stonecutMudBricks(.{ .item = .mud, .count = 1 }, .wall) == null);
}
test "slab collision height is half a block" {
    try @import("std").testing.expectEqual(@as(f32, 0.5), collisionHeight(.mud_brick_slab).?);
}
test "stair collision height is one block" {
    try @import("std").testing.expectEqual(@as(f32, 1.0), collisionHeight(.mud_brick_stairs).?);
}
test "wall collision height is one and a half blocks" {
    try @import("std").testing.expectEqual(@as(f32, 1.5), collisionHeight(.mud_brick_wall).?);
}
test "masonry collision height is absent for full brick" {
    try @import("std").testing.expect(collisionHeight(.mud_bricks) == null);
}
test "root placement in water is waterlogged" {
    try @import("std").testing.expect(placeMangroveRoots(true).is_waterlogged);
}
test "root placement on dry land is not waterlogged" {
    try @import("std").testing.expect(!placeMangroveRoots(false).is_waterlogged);
}
test "root cage emits eight segments and leaves center open" {
    const cage = generateRootCage(2, .{ false, false, false, false });
    try @import("std").testing.expectEqual(@as(u4, 8), cage.count);
    for (cage.segments) |segment| try @import("std").testing.expect(segment.x != 0 or segment.z != 0);
}
test "root cage clamps radius to three" {
    try @import("std").testing.expectEqual(@as(u2, 3), generateRootCage(9, .{ false, false, false, false }).radius);
}
test "root cage clamps radius to one" {
    try @import("std").testing.expectEqual(@as(u2, 1), generateRootCage(0, .{ false, false, false, false }).radius);
}
test "root cage descends on outer segments" {
    const cage = generateRootCage(2, .{ false, false, false, false });
    for (0..4) |i| try @import("std").testing.expectEqual(@as(i8, -1), cage.segments[i * 2 + 1].y);
}
test "root cage retains waterlogging by cardinal arm" {
    const cage = generateRootCage(2, .{ true, false, true, false });
    try @import("std").testing.expect(cage.segments[0].waterlogged);
    try @import("std").testing.expect(!cage.segments[2].waterlogged);
    try @import("std").testing.expect(cage.segments[4].waterlogged);
}
test "mud plus roots craft muddy mangrove roots" {
    const output = craftMuddyMangroveRoots(1, 1).?;
    try @import("std").testing.expectEqual(ItemType.muddy_mangrove_roots, output.item);
}
test "muddy root recipe yields one" {
    try @import("std").testing.expectEqual(@as(u8, 1), craftMuddyMangroveRoots(1, 1).?.count);
}
test "muddy root recipe requires exactly one of each" {
    try @import("std").testing.expect(craftMuddyMangroveRoots(2, 1) == null);
}
test "mangrove roots are axe minable" {
    try @import("std").testing.expect(isMinableWithAxe(.mangrove_roots));
}
test "muddy mangrove roots are axe minable" {
    try @import("std").testing.expect(isMinableWithAxe(.muddy_mangrove_roots));
}
test "mud hardness matches specification" {
    try @import("std").testing.expectEqual(@as(f32, 0.5), hardness(.mud).?);
}
test "packed mud hardness matches specification" {
    try @import("std").testing.expectEqual(@as(f32, 1.0), hardness(.packed_mud).?);
}
test "mud brick hardness matches specification" {
    try @import("std").testing.expectEqual(@as(f32, 1.5), hardness(.mud_bricks).?);
}
test "mud brick blast resistance matches specification" {
    try @import("std").testing.expectEqual(@as(f32, 3.0), MUD_BRICKS_BLAST_RESISTANCE);
}
test "mangrove root hardness matches specification" {
    try @import("std").testing.expectEqual(@as(f32, 0.7), hardness(.mangrove_roots).?);
}
test "muddy mangrove root hardness matches root hardness" {
    try @import("std").testing.expectEqual(MANGROVE_ROOTS_HARDNESS, hardness(.muddy_mangrove_roots).?);
}
