const std = @import("std");

/// The 16 canonical Minecraft dye colors (0..15).
pub const DyeColor = enum(u4) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,

    pub const count: usize = 16;

    pub fn name(self: DyeColor) []const u8 {
        return switch (self) {
            .white => "White",
            .orange => "Orange",
            .magenta => "Magenta",
            .light_blue => "Light Blue",
            .yellow => "Yellow",
            .lime => "Lime",
            .pink => "Pink",
            .gray => "Gray",
            .light_gray => "Light Gray",
            .cyan => "Cyan",
            .purple => "Purple",
            .blue => "Blue",
            .brown => "Brown",
            .green => "Green",
            .red => "Red",
            .black => "Black",
        };
    }
};

pub const TerracottaColor = DyeColor;

/// Mosaic pattern motifs and special visual features for the 16 Glazed Terracotta variants.
pub const MosaicPatternType = enum {
    sunburst_star, // White: 4-pointed sunburst star
    pinwheel_spiral, // Orange: pinwheel curved spiral
    directional_arrow, // Magenta: bold directional arrow
    four_petal_flower, // Light Blue: 4-petal floral bloom
    geometric_cogwheel, // Yellow: concentric cogwheel frame
    quatrefoil_flourish, // Lime: ornate quatrefoil flourish
    curved_heart_swirl, // Pink: ornate curved heart swirl
    fortress_medallion, // Gray: fortified square medallion
    knotwork_ring, // Light Gray: interlaced circular knotwork
    creeper_face_mosaic, // Cyan: 2x2 centerpiece forms a Creeper face
    broad_floral_bloom, // Purple: broad floral bloom
    ornate_sun_crest, // Blue: ornate solar crest
    geometric_concentric, // Brown: concentric geometric square tiles
    ribbon_loop_diamond, // Green: ribbon loops with diamond accents
    ornate_cross_flower, // Red: ornate heraldic cross and flower
    labyrinth_wheel, // Black: intricate red and black labyrinth wheel
};

pub const GlazedTerracottaInfo = struct {
    color: DyeColor,
    pattern: MosaicPatternType,
    has_directional_arrow: bool,
    motif_name: []const u8,
};

pub fn getGlazedTerracottaInfo(color: DyeColor) GlazedTerracottaInfo {
    return switch (color) {
        .white => .{
            .color = .white,
            .pattern = .sunburst_star,
            .has_directional_arrow = false,
            .motif_name = "Sunburst Star",
        },
        .orange => .{
            .color = .orange,
            .pattern = .pinwheel_spiral,
            .has_directional_arrow = false,
            .motif_name = "Pinwheel Spiral",
        },
        .magenta => .{
            .color = .magenta,
            .pattern = .directional_arrow,
            .has_directional_arrow = true,
            .motif_name = "Directional Arrow",
        },
        .light_blue => .{
            .color = .light_blue,
            .pattern = .four_petal_flower,
            .has_directional_arrow = false,
            .motif_name = "Four-Petal Flower",
        },
        .yellow => .{
            .color = .yellow,
            .pattern = .geometric_cogwheel,
            .has_directional_arrow = false,
            .motif_name = "Geometric Cogwheel",
        },
        .lime => .{
            .color = .lime,
            .pattern = .quatrefoil_flourish,
            .has_directional_arrow = false,
            .motif_name = "Quatrefoil Flourish",
        },
        .pink => .{
            .color = .pink,
            .pattern = .curved_heart_swirl,
            .has_directional_arrow = false,
            .motif_name = "Curved Heart Swirl",
        },
        .gray => .{
            .color = .gray,
            .pattern = .fortress_medallion,
            .has_directional_arrow = false,
            .motif_name = "Fortress Medallion",
        },
        .light_gray => .{
            .color = .light_gray,
            .pattern = .knotwork_ring,
            .has_directional_arrow = false,
            .motif_name = "Knotwork Ring",
        },
        .cyan => .{
            .color = .cyan,
            .pattern = .creeper_face_mosaic,
            .has_directional_arrow = false,
            .motif_name = "Creeper Face Mosaic",
        },
        .purple => .{
            .color = .purple,
            .pattern = .broad_floral_bloom,
            .has_directional_arrow = false,
            .motif_name = "Broad Floral Bloom",
        },
        .blue => .{
            .color = .blue,
            .pattern = .ornate_sun_crest,
            .has_directional_arrow = false,
            .motif_name = "Ornate Sun Crest",
        },
        .brown => .{
            .color = .brown,
            .pattern = .geometric_concentric,
            .has_directional_arrow = false,
            .motif_name = "Geometric Concentric",
        },
        .green => .{
            .color = .green,
            .pattern = .ribbon_loop_diamond,
            .has_directional_arrow = false,
            .motif_name = "Ribbon Loop Diamond",
        },
        .red => .{
            .color = .red,
            .pattern = .ornate_cross_flower,
            .has_directional_arrow = false,
            .motif_name = "Ornate Cross Flower",
        },
        .black => .{
            .color = .black,
            .pattern = .labyrinth_wheel,
            .has_directional_arrow = false,
            .motif_name = "Labyrinth Wheel",
        },
    };
}

/// DyedTerracottaRecipe:
/// Surrounding 1 dye of any of the 16 colors with 8 uncolored terracotta blocks
/// in a crafting grid crafts 8 DyedTerracotta of that color.
pub const DyedTerracottaRecipe = struct {
    pub const terracotta_input_per_batch: u8 = 8;
    pub const dye_input_per_batch: u8 = 1;
    pub const output_per_batch: u8 = 8;

    /// Crafts 8 Dyed Terracotta for every batch of 8 uncolored terracotta and 1 dye.
    pub fn craftDyedTerracotta(terracotta_count: u8, dye_count: u8) u8 {
        const batches = @min(terracotta_count / terracotta_input_per_batch, dye_count);
        return batches * output_per_batch;
    }

    pub fn craft(terracotta_count: u8, dye_count: u8) u8 {
        return DyedTerracottaRecipe.craftDyedTerracotta(terracotta_count, dye_count);
    }

    pub const CraftResult = struct {
        dyed_terracotta_crafted: u8,
        color: DyeColor,
        remaining_terracotta: u8,
        remaining_dye: u8,
    };

    pub fn craftDetailed(terracotta_count: u8, dye_count: u8, color: DyeColor) CraftResult {
        const batches = @min(terracotta_count / terracotta_input_per_batch, dye_count);
        const crafted = batches * output_per_batch;
        return .{
            .dyed_terracotta_crafted = crafted,
            .color = color,
            .remaining_terracotta = terracotta_count - (batches * terracotta_input_per_batch),
            .remaining_dye = dye_count - batches,
        };
    }

    pub fn canCraft(terracotta_count: u8, dye_count: u8) bool {
        return terracotta_count >= terracotta_input_per_batch and dye_count >= dye_input_per_batch;
    }
};

/// Free function for crafting dyed terracotta.
pub fn craftDyedTerracotta(terracotta_count: u8, dye_count: u8) u8 {
    return DyedTerracottaRecipe.craftDyedTerracotta(terracotta_count, dye_count);
}

/// Workstation categories for furnace smelting.
pub const SmeltingWorkstation = enum {
    furnace,
    blast_furnace,
    smoker,
};

/// GlazedTerracottaSmelting:
/// Smelting any DyedTerracotta in a standard furnace yields 1 GlazedTerracotta
/// of that color and 0.1 XP.
/// Blast furnaces and smokers CANNOT smelt terracotta.
/// Uncolored terracotta CANNOT be smelted into glazed terracotta.
pub const GlazedTerracottaSmelting = struct {
    pub const xp_yield: f32 = 0.1;
    pub const output_count: u8 = 1;
    pub const smelt_duration_seconds: f32 = 10.0;

    /// Only standard furnaces can smelt dyed terracotta into glazed terracotta.
    pub fn canSmeltInFurnaceOnly(workstation: anytype) bool {
        const T = @TypeOf(workstation);
        if (T == SmeltingWorkstation) {
            return workstation == .furnace;
        }
        const name = @tagName(workstation);
        return std.mem.eql(u8, name, "furnace") or std.mem.eql(u8, name, "standard_furnace");
    }

    /// Uncolored terracotta CANNOT be smelted into glazed terracotta.
    pub fn canSmeltUncoloredTerracotta() bool {
        return false;
    }

    pub const SmeltResult = struct {
        glazed_terracotta_count: u8,
        color: DyeColor,
        xp: f32,
    };

    pub fn smeltDyedTerracotta(color: DyeColor, workstation: anytype) ?SmeltResult {
        if (!GlazedTerracottaSmelting.canSmeltInFurnaceOnly(workstation)) {
            return null;
        }
        return .{
            .glazed_terracotta_count = output_count,
            .color = color,
            .xp = xp_yield,
        };
    }
};

pub fn canSmeltInFurnaceOnly(workstation: anytype) bool {
    return GlazedTerracottaSmelting.canSmeltInFurnaceOnly(workstation);
}

pub fn canSmeltUncoloredTerracotta() bool {
    return GlazedTerracottaSmelting.canSmeltUncoloredTerracotta();
}

/// 4 cardinal horizontal facings.
pub const HorizontalFacing = enum(u2) {
    north = 0,
    east = 1,
    south = 2,
    west = 3,

    pub const North = HorizontalFacing.north;
    pub const East = HorizontalFacing.east;
    pub const South = HorizontalFacing.south;
    pub const West = HorizontalFacing.west;

    pub fn opposite(self: HorizontalFacing) HorizontalFacing {
        return switch (self) {
            .north => .south,
            .east => .west,
            .south => .north,
            .west => .east,
        };
    }

    pub fn rotateClockwise(self: HorizontalFacing) HorizontalFacing {
        return switch (self) {
            .north => .east,
            .east => .south,
            .south => .west,
            .west => .north,
        };
    }

    pub fn rotateCounterClockwise(self: HorizontalFacing) HorizontalFacing {
        return switch (self) {
            .north => .west,
            .west => .south,
            .south => .east,
            .east => .north,
        };
    }
};

/// MosaicSymmetryPlacement:
/// Glazed Terracotta faces the opposite of the player's horizontal look direction on placement.
/// Arranging 4 matching Glazed Terracotta blocks in a 2x2 square with clockwise
/// or counter-clockwise rotation (North, East, South, West) forms a complete
/// circular/sunburst/floral centerpiece mosaic.
pub const MosaicSymmetryPlacement = struct {
    /// Placed block faces the opposite of the player's horizontal look direction.
    pub fn getPlacedFacing(player_look_direction: HorizontalFacing) HorizontalFacing {
        return player_look_direction.opposite();
    }

    pub fn placementFacing(player_look_direction: HorizontalFacing) HorizontalFacing {
        return player_look_direction.opposite();
    }

    fn checkCycle(seq: [4]HorizontalFacing, clockwise: bool) bool {
        var i: usize = 0;
        while (i < 3) : (i += 1) {
            const expected = if (clockwise)
                seq[i].rotateClockwise()
            else
                seq[i].rotateCounterClockwise();
            if (seq[i + 1] != expected) return false;
        }
        const closed = if (clockwise)
            seq[3].rotateClockwise()
        else
            seq[3].rotateCounterClockwise();
        return closed == seq[0];
    }

    /// Evaluates if 4 facings in a 2x2 square form a complete rotated mosaic.
    /// Supports perimeter sequence order [0, 1, 2, 3], standard row-major 2x2
    /// perimeter order [0=NW, 1=NE, 3=SE, 2=SW], and column-major [0=NW, 2=SW, 3=SE, 1=NE].
    pub fn isComplete2x2RotatedMosaic(facings: [4]HorizontalFacing) bool {
        // Direct sequential perimeter order
        if (checkCycle(facings, true) or checkCycle(facings, false)) {
            return true;
        }

        // Row-major order [0=NW, 1=NE, 2=SW, 3=SE] -> perimeter cycle: 0 -> 1 -> 3 -> 2
        const row_major_perimeter = [4]HorizontalFacing{ facings[0], facings[1], facings[3], facings[2] };
        if (checkCycle(row_major_perimeter, true) or checkCycle(row_major_perimeter, false)) {
            return true;
        }

        // Column-major order [0=NW, 1=SW, 2=NE, 3=SE] -> perimeter cycle: 0 -> 2 -> 3 -> 1
        const col_major_perimeter = [4]HorizontalFacing{ facings[0], facings[2], facings[3], facings[1] };
        if (checkCycle(col_major_perimeter, true) or checkCycle(col_major_perimeter, false)) {
            return true;
        }

        return false;
    }

    pub fn isClockwise2x2Mosaic(facings: [4]HorizontalFacing) bool {
        if (checkCycle(facings, true)) return true;
        const row_major_perimeter = [4]HorizontalFacing{ facings[0], facings[1], facings[3], facings[2] };
        if (checkCycle(row_major_perimeter, true)) return true;
        const col_major_perimeter = [4]HorizontalFacing{ facings[0], facings[2], facings[3], facings[1] };
        return checkCycle(col_major_perimeter, true);
    }

    pub fn isCounterClockwise2x2Mosaic(facings: [4]HorizontalFacing) bool {
        if (checkCycle(facings, false)) return true;
        const row_major_perimeter = [4]HorizontalFacing{ facings[0], facings[1], facings[3], facings[2] };
        if (checkCycle(row_major_perimeter, false)) return true;
        const col_major_perimeter = [4]HorizontalFacing{ facings[0], facings[2], facings[3], facings[1] };
        return checkCycle(col_major_perimeter, false);
    }

    /// Generates a valid 4-facing mosaic starting with start_facing.
    pub fn generateMosaic(start_facing: HorizontalFacing, clockwise: bool) [4]HorizontalFacing {
        var res: [4]HorizontalFacing = undefined;
        res[0] = start_facing;
        var i: usize = 1;
        while (i < 4) : (i += 1) {
            res[i] = if (clockwise) res[i - 1].rotateClockwise() else res[i - 1].rotateCounterClockwise();
        }
        return res;
    }
};

pub fn isComplete2x2RotatedMosaic(facings: [4]HorizontalFacing) bool {
    return MosaicSymmetryPlacement.isComplete2x2RotatedMosaic(facings);
}

pub fn getPlacedFacing(player_look_direction: HorizontalFacing) HorizontalFacing {
    return MosaicSymmetryPlacement.getPlacedFacing(player_look_direction);
}

/// MagentaArrowSignage:
/// Magenta Glazed Terracotta features a bold directional arrow sprite
/// that points in the block's facing direction.
pub const MagentaArrowSignage = struct {
    pub const arrow_color: DyeColor = .magenta;

    pub fn isDirectionalArrowTile(color: anytype) bool {
        const T = @TypeOf(color);
        if (T == DyeColor) {
            return color == .magenta;
        }
        const name = @tagName(color);
        return std.mem.eql(u8, name, "magenta");
    }

    pub fn getArrowPointingDirection(facing: HorizontalFacing) HorizontalFacing {
        return facing;
    }
};

pub fn isDirectionalArrowTile(color: anytype) bool {
    return MagentaArrowSignage.isDirectionalArrowTile(color);
}

/// Adhesion block categories for piston physics.
pub const AdhesionBlockType = enum {
    air,
    movable_normal,
    slime_block,
    honey_block,
    glazed_terracotta,
    immovable_obsidian_or_tile,
};

/// GlazedPistonRule:
/// Glazed Terracotta CAN be pushed by a piston (canPistonPush() == true),
/// CANNOT be pulled back by a sticky piston (canStickyPistonPull() == false),
/// and DOES NOT stick to adjacent Slime Blocks or Honey Blocks (sticksToSlimeOrHoney() == false).
pub const GlazedPistonRule = struct {
    pub const can_push: bool = true;
    pub const can_pull: bool = false;
    pub const sticks_to_slime_or_honey: bool = false;

    pub fn canPistonPush() bool {
        return true;
    }

    pub fn canStickyPistonPull() bool {
        return false;
    }

    pub fn sticksToSlimeOrHoney() bool {
        return false;
    }

    /// Glazed terracotta never adheres to any adjacent block.
    pub fn sticksTo(adjacent: AdhesionBlockType) bool {
        _ = adjacent;
        return false;
    }

    /// Evaluates if two adjacent blocks adhere together under piston motion.
    /// Glazed terracotta never adheres to anything, including slime and honey.
    pub fn doBlocksStickTogether(block_a: AdhesionBlockType, block_b: AdhesionBlockType) bool {
        if (block_a == .glazed_terracotta or block_b == .glazed_terracotta) {
            return false;
        }
        return switch (block_a) {
            .slime_block => block_b == .slime_block or block_b == .movable_normal,
            .honey_block => block_b == .honey_block or block_b == .movable_normal,
            else => switch (block_b) {
                .slime_block => block_a == .movable_normal,
                .honey_block => block_a == .movable_normal,
                else => false,
            },
        };
    }
};

pub fn canPistonPush() bool {
    return GlazedPistonRule.canPistonPush();
}

pub fn canStickyPistonPull() bool {
    return GlazedPistonRule.canStickyPistonPull();
}

pub fn sticksToSlimeOrHoney() bool {
    return GlazedPistonRule.sticksToSlimeOrHoney();
}

// ============================================================================
// TESTS
// ============================================================================

test "1. all 16 canonical dye colors exist with correct names and indices" {
    try std.testing.expectEqual(@as(usize, 16), DyeColor.count);
    try std.testing.expectEqual(@as(u4, 0), @intFromEnum(DyeColor.white));
    try std.testing.expectEqual(@as(u4, 2), @intFromEnum(DyeColor.magenta));
    try std.testing.expectEqual(@as(u4, 9), @intFromEnum(DyeColor.cyan));
    try std.testing.expectEqual(@as(u4, 15), @intFromEnum(DyeColor.black));

    try std.testing.expectEqualStrings("White", DyeColor.white.name());
    try std.testing.expectEqualStrings("Magenta", DyeColor.magenta.name());
    try std.testing.expectEqualStrings("Cyan", DyeColor.cyan.name());
    try std.testing.expectEqualStrings("Black", DyeColor.black.name());
}

test "2. DyedTerracottaRecipe crafts 8 dyed terracotta from 8 uncolored terracotta and 1 dye" {
    const crafted = craftDyedTerracotta(8, 1);
    try std.testing.expectEqual(@as(u8, 8), crafted);
    try std.testing.expect(DyedTerracottaRecipe.canCraft(8, 1));
}

test "3. DyedTerracottaRecipe handles multi-batch crafting and surplus materials" {
    try std.testing.expectEqual(@as(u8, 16), craftDyedTerracotta(16, 2));
    try std.testing.expectEqual(@as(u8, 64), craftDyedTerracotta(64, 8));
    try std.testing.expectEqual(@as(u8, 8), craftDyedTerracotta(64, 1)); // bottlenecked by dye
    try std.testing.expectEqual(@as(u8, 8), craftDyedTerracotta(9, 3)); // surplus terracotta and dye

    const detailed = DyedTerracottaRecipe.craftDetailed(20, 3, .light_blue);
    try std.testing.expectEqual(@as(u8, 16), detailed.dyed_terracotta_crafted);
    try std.testing.expectEqual(DyeColor.light_blue, detailed.color);
    try std.testing.expectEqual(@as(u8, 4), detailed.remaining_terracotta); // 20 - 16 = 4
    try std.testing.expectEqual(@as(u8, 1), detailed.remaining_dye); // 3 - 2 = 1
}

test "4. DyedTerracottaRecipe rejects insufficient materials" {
    try std.testing.expectEqual(@as(u8, 0), craftDyedTerracotta(7, 1));
    try std.testing.expectEqual(@as(u8, 0), craftDyedTerracotta(8, 0));
    try std.testing.expectEqual(@as(u8, 0), craftDyedTerracotta(0, 0));
    try std.testing.expect(!DyedTerracottaRecipe.canCraft(7, 1));
    try std.testing.expect(!DyedTerracottaRecipe.canCraft(8, 0));
}

test "5. canSmeltInFurnaceOnly accepts standard furnace and rejects blast furnace and smoker" {
    try std.testing.expect(canSmeltInFurnaceOnly(SmeltingWorkstation.furnace));
    try std.testing.expect(!canSmeltInFurnaceOnly(SmeltingWorkstation.blast_furnace));
    try std.testing.expect(!canSmeltInFurnaceOnly(SmeltingWorkstation.smoker));
}

test "6. GlazedTerracottaSmelting yields 1 glazed terracotta and 0.1 XP per dyed terracotta" {
    try std.testing.expectEqual(@as(u8, 1), GlazedTerracottaSmelting.output_count);
    try std.testing.expectEqual(@as(f32, 0.1), GlazedTerracottaSmelting.xp_yield);
    try std.testing.expectEqual(@as(f32, 10.0), GlazedTerracottaSmelting.smelt_duration_seconds);

    const result = GlazedTerracottaSmelting.smeltDyedTerracotta(.cyan, SmeltingWorkstation.furnace);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u8, 1), result.?.glazed_terracotta_count);
    try std.testing.expectEqual(DyeColor.cyan, result.?.color);
    try std.testing.expectEqual(@as(f32, 0.1), result.?.xp);

    const invalid_smelt = GlazedTerracottaSmelting.smeltDyedTerracotta(.cyan, SmeltingWorkstation.blast_furnace);
    try std.testing.expect(invalid_smelt == null);
}

test "7. uncolored terracotta cannot be smelted into glazed terracotta" {
    try std.testing.expect(!canSmeltUncoloredTerracotta());
    try std.testing.expect(!GlazedTerracottaSmelting.canSmeltUncoloredTerracotta());
}

test "8. MosaicSymmetryPlacement places block facing opposite of player look direction" {
    try std.testing.expectEqual(HorizontalFacing.south, getPlacedFacing(.north));
    try std.testing.expectEqual(HorizontalFacing.north, getPlacedFacing(.south));
    try std.testing.expectEqual(HorizontalFacing.west, getPlacedFacing(.east));
    try std.testing.expectEqual(HorizontalFacing.east, getPlacedFacing(.west));
}

test "9. HorizontalFacing clockwise and counter-clockwise rotations" {
    try std.testing.expectEqual(HorizontalFacing.east, HorizontalFacing.north.rotateClockwise());
    try std.testing.expectEqual(HorizontalFacing.south, HorizontalFacing.east.rotateClockwise());
    try std.testing.expectEqual(HorizontalFacing.west, HorizontalFacing.south.rotateClockwise());
    try std.testing.expectEqual(HorizontalFacing.north, HorizontalFacing.west.rotateClockwise());

    try std.testing.expectEqual(HorizontalFacing.west, HorizontalFacing.north.rotateCounterClockwise());
    try std.testing.expectEqual(HorizontalFacing.south, HorizontalFacing.west.rotateCounterClockwise());
    try std.testing.expectEqual(HorizontalFacing.east, HorizontalFacing.south.rotateCounterClockwise());
    try std.testing.expectEqual(HorizontalFacing.north, HorizontalFacing.east.rotateCounterClockwise());
}

test "10. isComplete2x2RotatedMosaic validates clockwise and counter-clockwise circular mosaics" {
    const cw_mosaic = [4]HorizontalFacing{ .north, .east, .south, .west };
    try std.testing.expect(isComplete2x2RotatedMosaic(cw_mosaic));
    try std.testing.expect(MosaicSymmetryPlacement.isClockwise2x2Mosaic(cw_mosaic));
    try std.testing.expect(!MosaicSymmetryPlacement.isCounterClockwise2x2Mosaic(cw_mosaic));

    const ccw_mosaic = [4]HorizontalFacing{ .north, .west, .south, .east };
    try std.testing.expect(isComplete2x2RotatedMosaic(ccw_mosaic));
    try std.testing.expect(MosaicSymmetryPlacement.isCounterClockwise2x2Mosaic(ccw_mosaic));
    try std.testing.expect(!MosaicSymmetryPlacement.isClockwise2x2Mosaic(ccw_mosaic));

    const rotated_start = [4]HorizontalFacing{ .east, .south, .west, .north };
    try std.testing.expect(isComplete2x2RotatedMosaic(rotated_start));
}

test "11. isComplete2x2RotatedMosaic validates standard row-major 2x2 grid layout" {
    // In row-major [0=NW, 1=NE, 2=SW, 3=SE], moving clockwise around perimeter:
    // NW (.north) -> NE (.east) -> SE (.south) -> SW (.west)
    // Thus array is [NW=.north, NE=.east, SW=.west, SE=.south]
    const row_major_cw = [4]HorizontalFacing{ .north, .east, .west, .south };
    try std.testing.expect(isComplete2x2RotatedMosaic(row_major_cw));
    try std.testing.expect(MosaicSymmetryPlacement.isClockwise2x2Mosaic(row_major_cw));

    // Counter-clockwise in row-major:
    // NW (.north) -> NE (.west) -> SE (.south) -> SW (.east)
    // Thus array is [NW=.north, NE=.west, SW=.east, SE=.south]
    const row_major_ccw = [4]HorizontalFacing{ .north, .west, .east, .south };
    try std.testing.expect(isComplete2x2RotatedMosaic(row_major_ccw));
    try std.testing.expect(MosaicSymmetryPlacement.isCounterClockwise2x2Mosaic(row_major_ccw));
}

test "12. isComplete2x2RotatedMosaic rejects invalid non-rotational patterns and duplicates" {
    const all_same = [4]HorizontalFacing{ .north, .north, .north, .north };
    try std.testing.expect(!isComplete2x2RotatedMosaic(all_same));

    const two_pairs = [4]HorizontalFacing{ .north, .east, .north, .east };
    try std.testing.expect(!isComplete2x2RotatedMosaic(two_pairs));

    const opposite_adjacent = [4]HorizontalFacing{ .north, .south, .east, .west };
    try std.testing.expect(!isComplete2x2RotatedMosaic(opposite_adjacent));

    const three_same = [4]HorizontalFacing{ .north, .east, .north, .north };
    try std.testing.expect(!isComplete2x2RotatedMosaic(three_same));
}

test "13. MagentaArrowSignage identifies magenta as unique directional arrow tile" {
    try std.testing.expect(isDirectionalArrowTile(DyeColor.magenta));
    try std.testing.expect(MagentaArrowSignage.isDirectionalArrowTile(DyeColor.magenta));

    // All other 15 colors are NOT directional arrow tiles
    const non_arrow_colors = [_]DyeColor{
        .white,      .orange, .light_blue, .yellow,
        .lime,       .pink,   .gray,       .light_gray,
        .cyan,       .purple, .blue,       .brown,
        .green,      .red,    .black,
    };
    for (non_arrow_colors) |c| {
        try std.testing.expect(!isDirectionalArrowTile(c));
    }
}

test "14. Magenta directional arrow points in the block's facing direction" {
    const directions = [_]HorizontalFacing{ .north, .east, .south, .west };
    for (directions) |dir| {
        try std.testing.expectEqual(dir, MagentaArrowSignage.getArrowPointingDirection(dir));
    }
}

test "15. GlazedPistonRule allows push, prevents sticky pull, and prevents slime/honey adhesion" {
    try std.testing.expect(canPistonPush());
    try std.testing.expect(GlazedPistonRule.canPistonPush());

    try std.testing.expect(!canStickyPistonPull());
    try std.testing.expect(!GlazedPistonRule.canStickyPistonPull());

    try std.testing.expect(!sticksToSlimeOrHoney());
    try std.testing.expect(!GlazedPistonRule.sticksToSlimeOrHoney());
}

test "16. Glazed terracotta adhesion rules against adjacent blocks" {
    try std.testing.expect(!GlazedPistonRule.sticksTo(.slime_block));
    try std.testing.expect(!GlazedPistonRule.sticksTo(.honey_block));
    try std.testing.expect(!GlazedPistonRule.sticksTo(.movable_normal));
    try std.testing.expect(!GlazedPistonRule.sticksTo(.glazed_terracotta));

    // doBlocksStickTogether: glazed terracotta never sticks to slime, honey, or anything
    try std.testing.expect(!GlazedPistonRule.doBlocksStickTogether(.glazed_terracotta, .slime_block));
    try std.testing.expect(!GlazedPistonRule.doBlocksStickTogether(.slime_block, .glazed_terracotta));
    try std.testing.expect(!GlazedPistonRule.doBlocksStickTogether(.glazed_terracotta, .honey_block));
    try std.testing.expect(!GlazedPistonRule.doBlocksStickTogether(.honey_block, .glazed_terracotta));
    try std.testing.expect(!GlazedPistonRule.doBlocksStickTogether(.glazed_terracotta, .movable_normal));

    // Whereas ordinary slime and honey stick to movable normal blocks
    try std.testing.expect(GlazedPistonRule.doBlocksStickTogether(.slime_block, .movable_normal));
    try std.testing.expect(GlazedPistonRule.doBlocksStickTogether(.honey_block, .movable_normal));
}

test "17. Pattern motifs for all 16 glazed terracotta variants include cyan creeper face" {
    const cyan_info = getGlazedTerracottaInfo(.cyan);
    try std.testing.expectEqual(MosaicPatternType.creeper_face_mosaic, cyan_info.pattern);
    try std.testing.expectEqualStrings("Creeper Face Mosaic", cyan_info.motif_name);

    const magenta_info = getGlazedTerracottaInfo(.magenta);
    try std.testing.expectEqual(MosaicPatternType.directional_arrow, magenta_info.pattern);
    try std.testing.expect(magenta_info.has_directional_arrow);

    const white_info = getGlazedTerracottaInfo(.white);
    try std.testing.expectEqual(MosaicPatternType.sunburst_star, white_info.pattern);
    try std.testing.expect(!white_info.has_directional_arrow);
}

test "18. generateMosaic produces valid circular mosaics for all starting orientations" {
    const facings = [_]HorizontalFacing{ .north, .east, .south, .west };
    for (facings) |f| {
        const cw = MosaicSymmetryPlacement.generateMosaic(f, true);
        try std.testing.expect(isComplete2x2RotatedMosaic(cw));
        try std.testing.expect(MosaicSymmetryPlacement.isClockwise2x2Mosaic(cw));

        const ccw = MosaicSymmetryPlacement.generateMosaic(f, false);
        try std.testing.expect(isComplete2x2RotatedMosaic(ccw));
        try std.testing.expect(MosaicSymmetryPlacement.isCounterClockwise2x2Mosaic(ccw));
    }
}
