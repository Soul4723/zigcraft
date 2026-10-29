const std = @import("std");

/// Item tags used by this standalone mineralogy rule set. Existing tags match
/// inventory.ItemType; the later values are reserved for the additional cuts.
pub const ItemType = enum(u16) {
    none = 0,
    stone = 1,
    deepslate = 309,
    cobbled_deepslate = 310,
    polished_deepslate = 311,
    deepslate_bricks = 312,
    reinforced_deepslate = 471,
    deepslate_tiles = 502,
    chiseled_deepslate = 503,
    cobbled_deepslate_slab = 504,
    polished_deepslate_slab = 505,
    deepslate_brick_slab = 506,
    deepslate_tile_slab = 507,
    cobbled_deepslate_stairs = 508,
    polished_deepslate_stairs = 509,
    deepslate_brick_stairs = 510,
    deepslate_tile_stairs = 511,
    cobbled_deepslate_wall = 512,
    polished_deepslate_wall = 513,
    deepslate_brick_wall = 514,
    deepslate_tile_wall = 515,
};

pub const stone_hardness: f32 = 1.5;
pub const deepslate_hardness: f32 = 3.0;
pub const reinforced_deepslate_hardness: f32 = 55.0;
pub const reinforced_deepslate_blast_resistance: f32 = 1200.0;
pub const deepslate_smelting_ticks: u16 = 200;

/// Deepslate is fully present below Y=-8 and absent above Y=0. Between them,
/// its generation probability rises linearly from 0 to 1.
pub fn deepslateProbability(y: f32) f32 {
    if (y >= 0.0) return 0.0;
    if (y <= -8.0) return 1.0;
    return -y / 8.0;
}

pub fn isDeepslateLayer(y: f32, sample: f32) bool {
    return sample >= 0.0 and sample < 1.0 and sample < deepslateProbability(y);
}

pub fn hardnessFor(item: ItemType) f32 {
    return switch (item) {
        .stone => stone_hardness,
        .deepslate => deepslate_hardness,
        .reinforced_deepslate => reinforced_deepslate_hardness,
        else => 3.5,
    };
}

pub fn miningDrop(item: ItemType, silk_touch: bool) ItemType {
    if (item == .deepslate and !silk_touch) return .cobbled_deepslate;
    return item;
}

pub fn smelt(input: ItemType) ?ItemType {
    return if (input == .cobbled_deepslate) .deepslate else null;
}

pub const CraftingResult = struct { item: ItemType, count: u8 };

/// Four identical masonry blocks in a 2x2 grid produce four of the next form.
pub fn craft2x2(input: ItemType) ?CraftingResult {
    return switch (input) {
        .cobbled_deepslate => .{ .item = .polished_deepslate, .count = 4 },
        .polished_deepslate => .{ .item = .deepslate_bricks, .count = 4 },
        .deepslate_bricks => .{ .item = .deepslate_tiles, .count = 4 },
        else => null,
    };
}

/// Two cobbled-deepslate slabs make one chiseled block.
pub fn craftChiseledDeepslate(input: ItemType, count: u8) ?CraftingResult {
    if (input != .cobbled_deepslate_slab or count < 2) return null;
    return .{ .item = .chiseled_deepslate, .count = 1 };
}

/// Stonecutter one-to-one cuts from cobbled deepslate.
pub fn stonecut(input: ItemType, output: ItemType) ?CraftingResult {
    if (input != .cobbled_deepslate) return null;
    return switch (output) {
        .polished_deepslate, .deepslate_bricks, .deepslate_tiles,
        .cobbled_deepslate_slab, .polished_deepslate_slab, .deepslate_brick_slab, .deepslate_tile_slab,
        .cobbled_deepslate_stairs, .polished_deepslate_stairs, .deepslate_brick_stairs, .deepslate_tile_stairs,
        .cobbled_deepslate_wall, .polished_deepslate_wall, .deepslate_brick_wall, .deepslate_tile_wall,
        => .{ .item = output, .count = 1 },
        else => null,
    };
}

pub fn reinforcedDeepslateSurvivesBlast(power: f32) bool {
    return power <= reinforced_deepslate_blast_resistance;
}

pub const reinforced_deepslate_piston_movable = false;
pub const reinforced_deepslate_wither_shatterable = false;
pub const reinforced_deepslate_dragon_collision_destroyable = false;

test "01 surface has zero deepslate chance" {
    try std.testing.expectEqual(@as(f32, 0.0), deepslateProbability(0));
}
test "02 above surface has zero deepslate chance" {
    try std.testing.expectEqual(@as(f32, 0.0), deepslateProbability(20));
}
test "03 transition midpoint has half deepslate chance" {
    try std.testing.expectEqual(@as(f32, 0.5), deepslateProbability(-4));
}
test "04 transition quarter has quarter chance" {
    try std.testing.expectEqual(@as(f32, 0.25), deepslateProbability(-2));
}
test "05 transition three-quarter has three-quarter chance" {
    try std.testing.expectEqual(@as(f32, 0.75), deepslateProbability(-6));
}
test "06 transition endpoint at minus eight is full chance" {
    try std.testing.expectEqual(@as(f32, 1.0), deepslateProbability(-8));
}
test "07 deep layer remains deepslate through minus sixty four" {
    try std.testing.expectEqual(@as(f32, 1.0), deepslateProbability(-64));
    try std.testing.expectEqual(@as(f32, 1.0), deepslateProbability(-200));
}
test "08 transition roll below threshold selects deepslate" {
    try std.testing.expect(isDeepslateLayer(-4, 0.49));
}
test "09 transition roll above threshold selects stone" {
    try std.testing.expect(!isDeepslateLayer(-4, 0.5));
}
test "10 stone endpoint never selects deepslate" {
    try std.testing.expect(!isDeepslateLayer(0, 0));
}
test "11 deep endpoint always selects deepslate for valid rolls" {
    try std.testing.expect(isDeepslateLayer(-8, 0.999));
}
test "12 stone hardness is one point five" {
    try std.testing.expectEqual(@as(f32, 1.5), hardnessFor(.stone));
}
test "13 deepslate hardness is double stone" {
    try std.testing.expectEqual(@as(f32, 3.0), hardnessFor(.deepslate));
    try std.testing.expectEqual(stone_hardness * 2.0, hardnessFor(.deepslate));
}
test "14 ordinary deepslate mining drops cobbled deepslate" {
    try std.testing.expectEqual(ItemType.cobbled_deepslate, miningDrop(.deepslate, false));
}
test "15 silk touch preserves deepslate" {
    try std.testing.expectEqual(ItemType.deepslate, miningDrop(.deepslate, true));
}
test "16 cobbled deepslate smelts back to deepslate" {
    try std.testing.expectEqual(ItemType.deepslate, smelt(.cobbled_deepslate).?);
}
test "17 deepslate smelting takes two hundred ticks" {
    try std.testing.expectEqual(@as(u16, 200), deepslate_smelting_ticks);
}
test "18 cobbled deepslate crafts into four polished blocks" {
    const result = craft2x2(.cobbled_deepslate).?;
    try std.testing.expectEqual(ItemType.polished_deepslate, result.item);
    try std.testing.expectEqual(@as(u8, 4), result.count);
}
test "19 polished deepslate crafts into four brick blocks" {
    const result = craft2x2(.polished_deepslate).?;
    try std.testing.expectEqual(ItemType.deepslate_bricks, result.item);
    try std.testing.expectEqual(@as(u8, 4), result.count);
}
test "20 deepslate bricks craft into four tile blocks" {
    const result = craft2x2(.deepslate_bricks).?;
    try std.testing.expectEqual(ItemType.deepslate_tiles, result.item);
    try std.testing.expectEqual(@as(u8, 4), result.count);
}
test "21 two cobbled slabs craft one chiseled block" {
    const result = craftChiseledDeepslate(.cobbled_deepslate_slab, 2).?;
    try std.testing.expectEqual(ItemType.chiseled_deepslate, result.item);
    try std.testing.expectEqual(@as(u8, 1), result.count);
}
test "22 one slab is insufficient for chiseled masonry" {
    try std.testing.expect(craftChiseledDeepslate(.cobbled_deepslate_slab, 1) == null);
}
test "23 stonecutter makes polished deepslate one to one" {
    const result = stonecut(.cobbled_deepslate, .polished_deepslate).?;
    try std.testing.expectEqual(@as(u8, 1), result.count);
}
test "24 stonecutter makes bricks and tiles directly one to one" {
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .deepslate_bricks).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .deepslate_tiles).?.count);
}
test "25 stonecutter makes slabs directly one to one" {
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .cobbled_deepslate_slab).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .polished_deepslate_slab).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .deepslate_brick_slab).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .deepslate_tile_slab).?.count);
}
test "26 stonecutter makes stairs directly one to one" {
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .cobbled_deepslate_stairs).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .polished_deepslate_stairs).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .deepslate_brick_stairs).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .deepslate_tile_stairs).?.count);
}
test "27 stonecutter makes walls directly one to one" {
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .cobbled_deepslate_wall).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .polished_deepslate_wall).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .deepslate_brick_wall).?.count);
    try std.testing.expectEqual(@as(u8, 1), stonecut(.cobbled_deepslate, .deepslate_tile_wall).?.count);
}
test "28 stonecutter rejects unrelated input" {
    try std.testing.expect(stonecut(.stone, .deepslate_bricks) == null);
}
test "29 reinforced deepslate hardness and blast resistance are extreme" {
    try std.testing.expectEqual(@as(f32, 55.0), hardnessFor(.reinforced_deepslate));
    try std.testing.expectEqual(@as(f32, 1200.0), reinforced_deepslate_blast_resistance);
}
test "30 reinforced deepslate survives blast power one hundred" {
    try std.testing.expect(reinforcedDeepslateSurvivesBlast(100.0));
}
test "31 reinforced deepslate survives blast at resistance limit" {
    try std.testing.expect(reinforcedDeepslateSurvivesBlast(1200.0));
}
test "32 reinforced deepslate breaks above resistance limit" {
    try std.testing.expect(!reinforcedDeepslateSurvivesBlast(1200.1));
}
test "33 reinforced deepslate cannot move with pistons" {
    try std.testing.expect(!reinforced_deepslate_piston_movable);
}
test "34 reinforced deepslate resists wither skull block shattering" {
    try std.testing.expect(!reinforced_deepslate_wither_shatterable);
}
test "35 reinforced deepslate retains integrity during dragon collision" {
    try std.testing.expect(!reinforced_deepslate_dragon_collision_destroyable);
}
