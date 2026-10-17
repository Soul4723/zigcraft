const std = @import("std");

/// Rules shared by regular Birch trees and the taller Old Growth Birch Forest.
pub const BirchTreeGrowth = struct {
    pub const regular_min_height: u8 = 5;
    pub const regular_max_height: u8 = 7;
    pub const old_growth_max_height: u8 = 14;

    pub fn supports2x2MegaTree() bool {
        return false;
    }

    pub fn neverGeneratesBranches() bool {
        return true;
    }

    pub fn isValidRegularHeight(height: u8) bool {
        return height >= regular_min_height and height <= regular_max_height;
    }

    pub fn isValidOldGrowthHeight(height: u8) bool {
        return height >= regular_min_height and height <= old_growth_max_height;
    }

    /// Deterministically maps a supplied growth sample to a valid height.
    /// Values in [0, 1] cover the complete regular/old-growth range.
    pub fn heightFromSample(sample: f32, old_growth: bool) u8 {
        const upper = if (old_growth) old_growth_max_height else regular_max_height;
        const clamped = std.math.clamp(sample, 0.0, 0.99999994);
        const span: u8 = upper - regular_min_height + 1;
        return regular_min_height + @as(u8, @intFromFloat(clamped * @as(f32, @floatFromInt(span))));
    }

    pub fn trunkBlockCount(height: u8) u8 {
        return std.math.clamp(height, regular_min_height, old_growth_max_height);
    }
};

pub const BirchTrunkBlock = struct {
    dx: i8 = 0,
    dy: u8,
    dz: i8 = 0,
};

/// Generates only a single vertical column: birch never grows side branches.
pub fn generateBirchTrunk(height: u8, buffer: []BirchTrunkBlock) usize {
    const actual_height = BirchTreeGrowth.trunkBlockCount(height);
    const count = @min(@as(usize, actual_height), buffer.len);
    var index: usize = 0;
    while (index < count) : (index += 1) {
        buffer[index] = .{ .dy = @intCast(index + 1) };
    }
    return count;
}

pub const BirchCanopyRule = struct {
    pub const min_vertical_clearance: u8 = 6;
    pub const max_vertical_clearance: u8 = 8;
    pub const birch_sapling_drop_chance: f32 = 0.05;
    pub const stick_drop_chance: f32 = 0.02;

    pub fn ignoresAdjacentHorizontalObstructions() bool {
        return true;
    }

    pub fn hasValidVerticalClearance(clearance: u8) bool {
        return clearance >= min_vertical_clearance and clearance <= max_vertical_clearance;
    }

    pub fn dropsApplesFromBirchLeaves() bool {
        return false;
    }

    /// Returns the item for a normalized deterministic roll, if any.
    /// Saplings occupy [0, .05), sticks [.05, .07), and the rest is empty.
    pub fn dropForRoll(roll: f32) ?BirchLeafDrop {
        const normalized = std.math.clamp(roll, 0.0, 0.99999994);
        if (normalized < birch_sapling_drop_chance) return .birch_sapling;
        if (normalized < birch_sapling_drop_chance + stick_drop_chance) return .stick;
        return null;
    }
};

pub const BirchLeafDrop = enum {
    birch_sapling,
    stick,
};

pub const FallenLogOrientation = enum {
    x_axis,
    z_axis,
};

pub const FallenLogTopping = enum {
    moss_carpet,
    brown_mushroom,
    red_mushroom,
};

/// A horizontal, detached birch trunk found on a forest floor.
pub const FallenBirchLog = struct {
    length: u4 = 3,
    orientation: FallenLogOrientation = .x_axis,
    gap_from_stump: u8 = 1,
    topping: FallenLogTopping = .moss_carpet,
    has_bee_nest: bool = false,

    pub const min_length: u4 = 3;
    pub const max_length: u4 = 5;

    pub fn init(length: u8, orientation: FallenLogOrientation, topping: FallenLogTopping, has_bee_nest: bool) FallenBirchLog {
        return .{
            .length = @intCast(std.math.clamp(length, @as(u8, min_length), @as(u8, max_length))),
            .orientation = orientation,
            .topping = topping,
            .has_bee_nest = has_bee_nest,
        };
    }

    pub fn isValid(self: FallenBirchLog) bool {
        return self.length >= min_length and self.length <= max_length and self.gap_from_stump == 1;
    }

    pub fn isHorizontal(self: FallenBirchLog) bool {
        _ = self;
        return true;
    }

    pub fn logBlockCount(self: FallenBirchLog) u4 {
        return self.length;
    }

    pub fn toppingBlock(self: FallenBirchLog) FallenLogTopping {
        return self.topping;
    }
};

pub const BirchWoodBlock = enum {
    birch_log,
    stripped_birch_log,
    birch_wood,
    birch_planks,
};

pub const BirchWoodFamily = struct {
    pub const planks_per_log: u8 = 4;
    pub const bark_color = "pale cream";
    pub const bark_markings = "dark horizontal lenticel markings";

    pub fn isLog(block: BirchWoodBlock) bool {
        return block == .birch_log or block == .stripped_birch_log;
    }

    pub fn stripLog(block: BirchWoodBlock) ?BirchWoodBlock {
        return if (block == .birch_log) .stripped_birch_log else null;
    }

    pub fn craftPlanks(logs: u32) u32 {
        return logs * planks_per_log;
    }

    pub fn description() []const u8 {
        return "pale cream bark with dark horizontal lenticel markings";
    }
};

test "birch saplings are never mega trees" {
    try std.testing.expect(!BirchTreeGrowth.supports2x2MegaTree());
}

test "birch trunks never generate side branches" {
    try std.testing.expect(BirchTreeGrowth.neverGeneratesBranches());
    var blocks: [14]BirchTrunkBlock = undefined;
    const count = generateBirchTrunk(14, &blocks);
    try std.testing.expectEqual(@as(usize, 14), count);
    for (blocks) |block| {
        try std.testing.expectEqual(@as(i8, 0), block.dx);
        try std.testing.expectEqual(@as(i8, 0), block.dz);
    }
}

test "regular birch height is five through seven" {
    try std.testing.expect(BirchTreeGrowth.isValidRegularHeight(5));
    try std.testing.expect(BirchTreeGrowth.isValidRegularHeight(7));
    try std.testing.expect(!BirchTreeGrowth.isValidRegularHeight(4));
    try std.testing.expect(!BirchTreeGrowth.isValidRegularHeight(8));
}

test "old growth birch reaches fourteen blocks" {
    try std.testing.expect(BirchTreeGrowth.isValidOldGrowthHeight(14));
    try std.testing.expect(!BirchTreeGrowth.isValidOldGrowthHeight(15));
}

test "height samples are deterministic and bounded" {
    try std.testing.expectEqual(@as(u8, 5), BirchTreeGrowth.heightFromSample(0.0, false));
    try std.testing.expectEqual(@as(u8, 7), BirchTreeGrowth.heightFromSample(0.99, false));
    try std.testing.expectEqual(@as(u8, 14), BirchTreeGrowth.heightFromSample(0.99, true));
}

test "trunk generation clamps invalid heights" {
    var blocks: [8]BirchTrunkBlock = undefined;
    try std.testing.expectEqual(@as(usize, 5), generateBirchTrunk(2, &blocks));
    try std.testing.expectEqual(@as(usize, 8), generateBirchTrunk(20, &blocks));
}

test "canopy ignores horizontal logs" {
    try std.testing.expect(BirchCanopyRule.ignoresAdjacentHorizontalObstructions());
}

test "canopy clearance is six through eight" {
    try std.testing.expect(!BirchCanopyRule.hasValidVerticalClearance(5));
    try std.testing.expect(BirchCanopyRule.hasValidVerticalClearance(6));
    try std.testing.expect(BirchCanopyRule.hasValidVerticalClearance(8));
    try std.testing.expect(!BirchCanopyRule.hasValidVerticalClearance(9));
}

test "birch leaves do not drop apples" {
    try std.testing.expect(!BirchCanopyRule.dropsApplesFromBirchLeaves());
}

test "birch leaf drop table has sapling and stick bands" {
    try std.testing.expectEqual(BirchLeafDrop.birch_sapling, BirchCanopyRule.dropForRoll(0.0).?);
    try std.testing.expectEqual(BirchLeafDrop.stick, BirchCanopyRule.dropForRoll(0.06).?);
    try std.testing.expect(BirchCanopyRule.dropForRoll(0.07) == null);
}

test "fallen logs have constrained lengths and a one block stump gap" {
    const log = FallenBirchLog.init(9, .z_axis, .red_mushroom, true);
    try std.testing.expectEqual(@as(u4, 5), log.length);
    try std.testing.expectEqual(@as(u8, 1), log.gap_from_stump);
    try std.testing.expect(log.isValid());
    try std.testing.expect(log.isHorizontal());
}

test "fallen log toppings and bee nest are retained" {
    const log = FallenBirchLog.init(3, .x_axis, .moss_carpet, true);
    try std.testing.expectEqual(FallenLogTopping.moss_carpet, log.toppingBlock());
    try std.testing.expect(log.has_bee_nest);
}

test "birch wood family strips logs and crafts four planks" {
    try std.testing.expect(BirchWoodFamily.isLog(.birch_log));
    try std.testing.expect(!BirchWoodFamily.isLog(.birch_wood));
    try std.testing.expectEqual(BirchWoodBlock.stripped_birch_log, BirchWoodFamily.stripLog(.birch_log).?);
    try std.testing.expectEqual(@as(u32, 12), BirchWoodFamily.craftPlanks(3));
}

test "birch wood family records pale bark markings" {
    try std.testing.expectEqualStrings("pale cream", BirchWoodFamily.bark_color);
    try std.testing.expect(std.mem.indexOf(u8, BirchWoodFamily.description(), "lenticel") != null);
}
