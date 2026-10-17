const std = @import("std");

pub const SculkBlock = enum { sculk, sculk_vein, sculk_catalyst, sculk_sensor, sculk_shrieker };
pub const Tool = enum { hand, pickaxe, shovel, axe, hoe };

pub fn fastestToolForSculk(block: SculkBlock) Tool { _ = block; return .hoe; }
pub const SculkFastestTool = struct { pub fn fastestTool(block: SculkBlock) Tool { return fastestToolForSculk(block); } };

pub fn xpDroppedWithoutSilkTouch(block: SculkBlock) u32 {
    return switch (block) { .sculk => 1, .sculk_catalyst, .sculk_sensor, .sculk_shrieker => 5, .sculk_vein => 0 };
}
pub fn itemsDroppedWithoutSilkTouch(block: SculkBlock) u32 { _ = block; return 0; }
pub fn xpDroppedWithSilkTouch() u32 { return 0; }
pub fn silkTouchDropsBlock(block: SculkBlock) bool { return block != .sculk_vein; }
pub fn itemsDroppedWithSilkTouch(block: SculkBlock) u32 { return if (silkTouchDropsBlock(block)) 1 else 0; }
pub const SculkXpVsSilkTouch = struct {
    pub fn xpWithoutSilkTouch(block: SculkBlock) u32 { return xpDroppedWithoutSilkTouch(block); }
    pub fn xpWithSilkTouch() u32 { return xpDroppedWithSilkTouch(); }
    pub fn blockDropWithSilkTouch(block: SculkBlock) bool { return silkTouchDropsBlock(block); }
};

pub const ReplaceableBlock = enum { stone, deepslate, dirt, grass, netherrack, end_stone, other,
    pub fn canBeConverted(self: ReplaceableBlock) bool { return self != .other; }
};
pub const CatalystRadius: f32 = 8.0;
pub fn isWithinCatalystRange(distance: f32) bool { return distance >= 0.0 and distance <= CatalystRadius; }
pub fn suppressesNaturalXpOrbs() bool { return true; }
pub fn catalystAbsorbsMobXp(distance: f32, mob_xp_value: u32) bool { return mob_xp_value > 0 and isWithinCatalystRange(distance); }

pub const SculkCharge = struct {
    charge: u32,
    pub fn init(charge: u32) SculkCharge { return .{ .charge = charge }; }
    pub fn canConvert(self: SculkCharge) bool { return self.charge > 0; }
    pub fn consumeForBlock(self: *SculkCharge) bool { if (self.charge == 0) return false; self.charge -= 1; return true; }
};
pub const SculkChargeCursor = SculkCharge;
pub const SoulChargeCursor = SculkCharge;

/// Catalyst charge is represented by a wandering cursor rather than an XP orb.
pub fn spawnSculkCharge(mob_xp_value: u32) SculkCharge { return SculkCharge.init(mob_xp_value); }
pub fn propagateSoulCharge(mob_xp_value: u32, distance: f32) ?SculkCharge {
    if (!catalystAbsorbsMobXp(distance, mob_xp_value)) return null;
    return spawnSculkCharge(mob_xp_value);
}
pub const BloomResult = struct { block_converted: bool, sculk_vein_faces: u8 };
pub fn bloomBlock(charge: *SculkCharge, block: ReplaceableBlock, open_face_count: u8) BloomResult {
    if (!block.canBeConverted() or !charge.consumeForBlock()) return .{ .block_converted = false, .sculk_vein_faces = 0 };
    return .{ .block_converted = true, .sculk_vein_faces = @min(open_face_count, 6) };
}
pub fn canHarvestWithHoe(block: SculkBlock) bool { return fastestToolForSculk(block) == .hoe; }
pub fn silkTouchMiningDrops(block: SculkBlock) struct { items: u32, xp: u32 } {
    return .{ .items = itemsDroppedWithSilkTouch(block), .xp = xpDroppedWithSilkTouch() };
}

pub const DeepDarkGrowth = enum { overworld, deep_dark, on_sculk };
pub fn canCatalystGrowActivator(context: DeepDarkGrowth, distance_from_catalyst: f32, charge: u32) bool {
    return charge >= 10 and distance_from_catalyst >= 2.0 and (context == .deep_dark or context == .on_sculk);
}
pub fn catalystActivatorGrowth(roll: f32) ?SculkBlock {
    if (roll < 0.0 or roll >= 1.0) return null;
    if (roll < 0.09) return .sculk_sensor;
    if (roll < 0.10) return .sculk_shrieker;
    return null;
}
pub fn canPlayerGrownShriekerSummonWarden() bool { return false; }
pub const CatalystActivatorGrowth = struct {
    pub fn canGrow(context: DeepDarkGrowth, distance: f32, charge: u32) bool { return canCatalystGrowActivator(context, distance, charge); }
    pub fn growthForRoll(roll: f32) ?SculkBlock { return catalystActivatorGrowth(roll); }
    pub fn canSummonWarden() bool { return canPlayerGrownShriekerSummonWarden(); }
};

pub const SculkVeinFace = enum(u3) { down = 0, up = 1, north = 2, south = 3, west = 4, east = 5 };
pub const all_vein_faces: [6]SculkVeinFace = .{ .down, .up, .north, .south, .west, .east };
pub const SculkVein = struct {
    face_mask: u8 = 0,
    pub fn init() SculkVein { return .{}; }
    pub fn hasFace(self: SculkVein, face: SculkVeinFace) bool { return (self.face_mask & (@as(u8, 1) << @intFromEnum(face))) != 0; }
    pub fn addFace(self: *SculkVein, face: SculkVeinFace) void { self.face_mask |= @as(u8, 1) << @intFromEnum(face); }
    pub fn spreadToOpenFaces(self: *SculkVein, open_faces: u8) u8 { const added = open_faces & ~self.face_mask; self.face_mask |= open_faces; return @popCount(added); }
    pub fn faceCount(self: SculkVein) u8 { return @popCount(self.face_mask); }
    pub fn silkTouchDropsSelf() bool { return true; }
};

test "all five sculk blocks use hoe" { inline for (@typeInfo(SculkBlock).@"enum".fields) |field| try std.testing.expectEqual(Tool.hoe, fastestToolForSculk(@enumFromInt(field.value))); }
test "sculk stores one xp as a silk touched block" { try std.testing.expectEqual(@as(u32, 1), xpDroppedWithoutSilkTouch(.sculk)); try std.testing.expectEqual(@as(u32, 0), itemsDroppedWithoutSilkTouch(.sculk)); try std.testing.expectEqual(@as(u32, 0), xpDroppedWithSilkTouch()); try std.testing.expectEqual(@as(u32, 1), itemsDroppedWithSilkTouch(.sculk)); }
test "catalyst sensor and shrieker yield five xp without silk" { try std.testing.expectEqual(@as(u32, 5), xpDroppedWithoutSilkTouch(.sculk_catalyst)); try std.testing.expectEqual(@as(u32, 5), xpDroppedWithoutSilkTouch(.sculk_sensor)); try std.testing.expectEqual(@as(u32, 5), xpDroppedWithoutSilkTouch(.sculk_shrieker)); }
test "silk touch preserves catalyst family blocks" { try std.testing.expect(silkTouchDropsBlock(.sculk_catalyst)); try std.testing.expect(silkTouchDropsBlock(.sculk_sensor)); try std.testing.expect(silkTouchDropsBlock(.sculk_shrieker)); try std.testing.expect(!silkTouchDropsBlock(.sculk_vein)); }
test "catalyst range includes eight blocks" { try std.testing.expect(isWithinCatalystRange(0.0)); try std.testing.expect(isWithinCatalystRange(8.0)); try std.testing.expect(!isWithinCatalystRange(8.01)); }
test "only positive xp mobs activate a nearby catalyst" { try std.testing.expect(catalystAbsorbsMobXp(4.0, 7)); try std.testing.expect(!catalystAbsorbsMobXp(4.0, 0)); try std.testing.expect(!catalystAbsorbsMobXp(9.0, 7)); }
test "catalyst suppresses natural xp orbs" { try std.testing.expect(suppressesNaturalXpOrbs()); }
test "charge converts replaceable blocks and borders veins" { var charge = SculkCharge.init(2); const result = bloomBlock(&charge, .stone, 6); try std.testing.expect(result.block_converted); try std.testing.expectEqual(@as(u8, 6), result.sculk_vein_faces); try std.testing.expectEqual(@as(u32, 1), charge.charge); }
test "charge does not convert nonreplaceable blocks" { var charge = SculkCharge.init(2); const result = bloomBlock(&charge, .other, 6); try std.testing.expect(!result.block_converted); try std.testing.expectEqual(@as(u32, 2), charge.charge); }
test "activator growth requires deep dark or sculk and ten charge" { try std.testing.expect(canCatalystGrowActivator(.deep_dark, 2.0, 10)); try std.testing.expect(canCatalystGrowActivator(.on_sculk, 4.0, 20)); try std.testing.expect(!canCatalystGrowActivator(.overworld, 2.0, 10)); try std.testing.expect(!canCatalystGrowActivator(.deep_dark, 1.9, 10)); try std.testing.expect(!canCatalystGrowActivator(.deep_dark, 2.0, 9)); }
test "activator growth probabilities are nine and one percent" { try std.testing.expectEqual(SculkBlock.sculk_sensor, catalystActivatorGrowth(0.0).?); try std.testing.expectEqual(SculkBlock.sculk_sensor, catalystActivatorGrowth(0.0899).?); try std.testing.expectEqual(SculkBlock.sculk_shrieker, catalystActivatorGrowth(0.09).?); try std.testing.expect(catalystActivatorGrowth(0.10) == null); }
test "catalyst grown shriekers cannot summon wardens" { try std.testing.expect(!canPlayerGrownShriekerSummonWarden()); }
test "sculk vein spreads across multiple faces" { var vein = SculkVein.init(); try std.testing.expectEqual(@as(u8, 3), vein.spreadToOpenFaces(0b001011)); try std.testing.expectEqual(@as(u8, 3), vein.faceCount()); try std.testing.expect(vein.hasFace(.down)); try std.testing.expect(vein.hasFace(.up)); try std.testing.expect(vein.hasFace(.south)); try std.testing.expectEqual(@as(u8, 0), vein.spreadToOpenFaces(0b001011)); }
test "sculk vein supports all six orthogonal faces" { var vein = SculkVein.init(); for (all_vein_faces) |face| vein.addFace(face); try std.testing.expectEqual(@as(u8, 6), vein.faceCount()); try std.testing.expect(SculkVein.silkTouchDropsSelf()); }
test "charge consumption stops at zero" { var charge = SculkCharge.init(1); try std.testing.expect(charge.consumeForBlock()); try std.testing.expect(!charge.consumeForBlock()); try std.testing.expectEqual(@as(u32, 0), charge.charge); }
