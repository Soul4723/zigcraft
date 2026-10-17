const std = @import("std");

pub const mega_spruce_min_height: u8 = 15;
pub const mega_spruce_max_height: u8 = 30;
pub const podzol_conversion_radius: f32 = 6.0;

pub const TreeKind = enum { spruce, pine };

/// Result of successfully growing a four-sapling mega tree.
pub const MegaSpruceTreeGrowth = struct {
    height: u8,
    kind: TreeKind,
    soil_radius: f32 = podzol_conversion_radius,

    pub fn isGiant(self: MegaSpruceTreeGrowth) bool {
        return self.height >= mega_spruce_min_height and self.height <= mega_spruce_max_height;
    }
};

/// A mega tree needs all four corners of a 2x2 sapling square and room for its
/// minimum trunk. Clearance is measured in blocks above the saplings.
pub fn canGrowMega2x2Spruce(saplings: [4]bool, clearance_height: u8) bool {
    return saplings[0] and saplings[1] and saplings[2] and saplings[3] and
        clearance_height >= mega_spruce_min_height;
}

/// Returns a deterministic tree result. More clearance gives a taller tree,
/// capped at the natural 30-block maximum.
pub fn growMegaSpruceTree(saplings: [4]bool, clearance_height: u8, kind: TreeKind) ?MegaSpruceTreeGrowth {
    if (!canGrowMega2x2Spruce(saplings, clearance_height)) return null;
    const height = @min(clearance_height, mega_spruce_max_height);
    return .{ .height = height, .kind = kind };
}

/// Surface grass and dirt within (and including) the six-block radius become
/// podzol when the mega tree grows. Negative distances are invalid positions.
pub fn shouldConvertSoilToPodzol(dist_m: f32, is_grass_or_dirt: bool) bool {
    return is_grass_or_dirt and dist_m >= 0.0 and dist_m <= podzol_conversion_radius;
}

pub const PodzolDrop = enum { podzol, dirt };

pub const PodzolProperties = struct {
    /// Podzol and mycelium bypass the normal mushroom light restriction.
    pub fn canPlantMushroomOnBlock(is_podzol_or_mycelium: bool, light_level: u4) bool {
        _ = light_level;
        return is_podzol_or_mycelium;
    }

    pub fn harvest(has_silk_touch: bool) PodzolDrop {
        return if (has_silk_touch) .podzol else .dirt;
    }
};

pub fn canPlantMushroomOnBlock(is_podzol_or_mycelium: bool, light_level: u4) bool {
    return PodzolProperties.canPlantMushroomOnBlock(is_podzol_or_mycelium, light_level);
}

pub fn harvestPodzol(has_silk_touch: bool) PodzolDrop {
    return PodzolProperties.harvest(has_silk_touch);
}

pub const MossyBoulderSize = enum(u8) { two_by_two = 2, three_by_three = 3 };

pub const MossyCobblestoneBoulder = struct {
    size: MossyBoulderSize,

    pub fn init(requested_size: u8) MossyCobblestoneBoulder {
        return .{ .size = if (requested_size >= 3) .three_by_three else .two_by_two };
    }

    pub fn blockCount(self: MossyCobblestoneBoulder) u8 {
        const side: u8 = @intFromEnum(self.size);
        return side * side;
    }
};

/// One cobblestone plus one vine or moss block crafts one mossy cobblestone.
/// The return value is the number of output blocks, making partial recipes
/// unambiguous for callers holding item counts.
pub fn craftMossyCobblestone(cobblestone_count: u8, vines_count: u8, moss_block_count: u8) u8 {
    if (cobblestone_count == 0) return 0;
    const available_secondary: u16 = @as(u16, vines_count) + @as(u16, moss_block_count);
    return @min(cobblestone_count, @as(u8, @intCast(@min(available_secondary, 255))));
}

pub const TaigaFernDuplication = struct {
    pub fn boneMealFern(is_fern: bool) bool {
        return is_fern;
    }

    pub fn shearLargeFern(is_large_fern: bool) u8 {
        return if (is_large_fern) 2 else 0;
    }
};

pub fn boneMealFern(is_fern: bool) bool {
    return TaigaFernDuplication.boneMealFern(is_fern);
}

pub fn shearLargeFern(is_large_fern: bool) u8 {
    return TaigaFernDuplication.shearLargeFern(is_large_fern);
}

test "four saplings and minimum clearance permit mega spruce" {
    try std.testing.expect(canGrowMega2x2Spruce(.{ true, true, true, true }, 15));
}

test "missing sapling corner prevents mega growth" {
    try std.testing.expect(!canGrowMega2x2Spruce(.{ true, true, true, false }, 30));
}

test "insufficient clearance prevents mega growth" {
    try std.testing.expect(!canGrowMega2x2Spruce(.{ true, true, true, true }, 14));
}

test "mega tree height is deterministic and capped" {
    const short = growMegaSpruceTree(.{ true, true, true, true }, 15, .spruce).?;
    const tall = growMegaSpruceTree(.{ true, true, true, true }, 80, .pine).?;
    try std.testing.expectEqual(@as(u8, 15), short.height);
    try std.testing.expectEqual(@as(u8, 30), tall.height);
    try std.testing.expectEqual(TreeKind.pine, tall.kind);
    try std.testing.expect(short.isGiant() and tall.isGiant());
}

test "soil conversion includes radius edge and excludes beyond it" {
    try std.testing.expect(shouldConvertSoilToPodzol(0, true));
    try std.testing.expect(shouldConvertSoilToPodzol(6, true));
    try std.testing.expect(!shouldConvertSoilToPodzol(6.01, true));
}

test "soil conversion ignores non grass and dirt" {
    try std.testing.expect(!shouldConvertSoilToPodzol(2, false));
    try std.testing.expect(!shouldConvertSoilToPodzol(-1, true));
}

test "podzol permits mushrooms at every light level" {
    try std.testing.expect(canPlantMushroomOnBlock(true, 0));
    try std.testing.expect(canPlantMushroomOnBlock(true, 15));
}

test "regular dirt still rejects mushroom planting" {
    try std.testing.expect(!canPlantMushroomOnBlock(false, 0));
    try std.testing.expect(!PodzolProperties.canPlantMushroomOnBlock(false, 15));
}

test "silk touch preserves podzol and ordinary harvest drops dirt" {
    try std.testing.expectEqual(PodzolDrop.podzol, harvestPodzol(true));
    try std.testing.expectEqual(PodzolDrop.dirt, harvestPodzol(false));
}

test "boulder sizes are rounded two or three block squares" {
    try std.testing.expectEqual(MossyBoulderSize.two_by_two, MossyCobblestoneBoulder.init(2).size);
    try std.testing.expectEqual(MossyBoulderSize.three_by_three, MossyCobblestoneBoulder.init(3).size);
    try std.testing.expectEqual(@as(u8, 9), MossyCobblestoneBoulder.init(3).blockCount());
}

test "boulder size clamps arbitrary values to supported range" {
    try std.testing.expectEqual(MossyBoulderSize.two_by_two, MossyCobblestoneBoulder.init(0).size);
    try std.testing.expectEqual(MossyBoulderSize.three_by_three, MossyCobblestoneBoulder.init(99).size);
}

test "vines or moss block each complete mossy recipe" {
    try std.testing.expectEqual(@as(u8, 1), craftMossyCobblestone(1, 1, 0));
    try std.testing.expectEqual(@as(u8, 1), craftMossyCobblestone(1, 0, 1));
}

test "mossy recipe consumes matching ingredient counts" {
    try std.testing.expectEqual(@as(u8, 2), craftMossyCobblestone(3, 1, 1));
    try std.testing.expectEqual(@as(u8, 0), craftMossyCobblestone(2, 0, 0));
}

test "bone meal turns a fern into a large fern" {
    try std.testing.expect(boneMealFern(true));
    try std.testing.expect(!boneMealFern(false));
}

test "shearing a large fern drops two ferns" {
    try std.testing.expectEqual(@as(u8, 2), shearLargeFern(true));
    try std.testing.expectEqual(@as(u8, 0), shearLargeFern(false));
}
