const std = @import("std");

pub const brushes_to_excavate: u8 = 3;

pub const PotterySherdTag: u16 = 369;
pub const EmeraldTag: u16 = 273;
pub const GoldNuggetTag: u16 = 81;
pub const DiamondTag: u16 = 217;
pub const CoalTag: u16 = 12;

pub fn relicForRoll(roll: u8) u16 {
    return switch (roll % 5) {
        0, 1 => PotterySherdTag,
        2 => EmeraldTag,
        3 => GoldNuggetTag,
        else => DiamondTag,
    };
}

pub fn toggleCopperBulb(is_lit: bool) bool {
    return !is_lit;
}

pub fn copperBulbComparatorSignal(is_lit: bool) u8 {
    if (is_lit) return 15;
    return 0;
}

test "constants" {
    try std.testing.expectEqual(@as(u8, 3), brushes_to_excavate);
    try std.testing.expectEqual(@as(u16, 369), PotterySherdTag);
    try std.testing.expectEqual(@as(u16, 273), EmeraldTag);
    try std.testing.expectEqual(@as(u16, 81), GoldNuggetTag);
    try std.testing.expectEqual(@as(u16, 217), DiamondTag);
    try std.testing.expectEqual(@as(u16, 12), CoalTag);
}

test "relicForRoll maps each residue class" {
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(0));
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(1));
    try std.testing.expectEqual(EmeraldTag, relicForRoll(2));
    try std.testing.expectEqual(GoldNuggetTag, relicForRoll(3));
    try std.testing.expectEqual(DiamondTag, relicForRoll(4));
}

test "relicForRoll wraps with modulo five" {
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(5));
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(6));
    try std.testing.expectEqual(EmeraldTag, relicForRoll(7));
    try std.testing.expectEqual(GoldNuggetTag, relicForRoll(8));
    try std.testing.expectEqual(DiamondTag, relicForRoll(9));
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(255));
}

test "toggleCopperBulb" {
    try std.testing.expect(toggleCopperBulb(false));
    try std.testing.expect(!toggleCopperBulb(true));
}

test "copperBulbComparatorSignal" {
    try std.testing.expectEqual(@as(u8, 15), copperBulbComparatorSignal(true));
    try std.testing.expectEqual(@as(u8, 0), copperBulbComparatorSignal(false));
}
