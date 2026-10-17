const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

// ============================================================================
// Registry Tags & Biome Constants
// ============================================================================

/// Registry tag IDs for Dark Forest and Giant Mushroom block and item types.
pub const DarkOakLogTag: u16 = 440;
pub const DarkOakLeavesTag: u16 = 441;
pub const DarkOakSaplingTag: u16 = 442;
pub const DarkOakWoodTag: u16 = 443;
pub const DarkOakPlanksTag: u16 = 444;
pub const RedMushroomBlockTag: u16 = 445;
pub const BrownMushroomBlockTag: u16 = 446;
pub const MushroomStemTag: u16 = 447;
pub const RedMushroomTag: u16 = 448;
pub const BrownMushroomTag: u16 = 449;

/// Dark Forest biome environmental parameters.
pub const dark_forest_temperature: f32 = 0.7;
pub const dark_forest_downfall: f32 = 0.8;

// ============================================================================
// 1. DarkOakGrowth: 2x2 Sapling Cluster, Clearance & Tree Structure
// ============================================================================

pub const DarkOakBlockType = enum(u8) {
    trunk_log = 0,
    branch_log = 1,
    leaves = 2,
};

pub const DarkOakBlock = struct {
    dx: i32,
    dy: i32,
    dz: i32,
    block_type: DarkOakBlockType,
};

pub const DarkOakGrowth = struct {
    pub const min_clearance: u8 = 6;
    pub const max_clearance: u8 = 11;
    pub const trunk_width: u8 = 2; // 2x2 trunk
    pub const sapling_cluster_count: usize = 4;

    /// Checks whether a 2x2 cluster of saplings can grow into a dark oak tree.
    /// Requirements:
    /// - All 4 saplings in the 2x2 cluster must be present ([4]bool all true).
    /// - A single sapling or incomplete cluster cannot grow.
    /// - Overhead clearance must be within 6..11 blocks (inclusive).
    pub fn canGrowDarkOak(saplings: [4]bool, clearance_height: u8) bool {
        // All 4 saplings must be present in the 2x2 arrangement
        for (saplings) |present| {
            if (!present) return false;
        }

        // Clearance requirement: 6..11 blocks
        if (clearance_height < min_clearance or clearance_height > max_clearance) {
            return false;
        }

        return true;
    }

    /// Evaluates if a 2x2 boolean grid represents a complete 4-sapling cluster.
    pub fn isClusterComplete(cluster: [2][2]bool) bool {
        return cluster[0][0] and cluster[0][1] and cluster[1][0] and cluster[1][1];
    }

    /// Generates a procedural 2x2 dark oak tree with a 2x2 trunk and dense leaf roof.
    /// Returns the number of blocks written to buffer.
    pub fn generateTree(trunk_height: u8, buffer: []DarkOakBlock) usize {
        const clamped_height = std.math.clamp(trunk_height, min_clearance, max_clearance);
        var count: usize = 0;

        // 1. Thick 2x2 trunk from dy = 1 up to clamped_height
        var y: i32 = 1;
        while (y <= clamped_height) : (y += 1) {
            const trunk_coords = [_][2]i32{
                .{ 0, 0 },
                .{ 1, 0 },
                .{ 0, 1 },
                .{ 1, 1 },
            };
            for (trunk_coords) |coord| {
                if (count < buffer.len) {
                    buffer[count] = .{
                        .dx = coord[0],
                        .dy = y,
                        .dz = coord[1],
                        .block_type = .trunk_log,
                    };
                    count += 1;
                }
            }
        }

        // 2. Dense leaf roof (canopy layers)
        // Multi-tier dense roof spanning over the 2x2 trunk:
        // - Layer -1 (clamped_height - 1): wide 8x8 flat disk with rounded corners
        // - Layer 0  (clamped_height): dense solid 8x8 roof
        // - Layer 1  (clamped_height + 1): 6x6 upper canopy
        // - Layer 2  (clamped_height + 2): 4x4 canopy crown
        const leaf_layers = [_]struct {
            dy_offset: i32,
            radius: i32,
            skip_corners: bool,
        }{
            .{ .dy_offset = -1, .radius = 3, .skip_corners = true },
            .{ .dy_offset = 0, .radius = 3, .skip_corners = false },
            .{ .dy_offset = 1, .radius = 2, .skip_corners = false },
            .{ .dy_offset = 2, .radius = 1, .skip_corners = false },
        };

        for (leaf_layers) |layer| {
            const leaf_y = @as(i32, clamped_height) + layer.dy_offset;
            const r = layer.radius;
            var dx: i32 = -r;
            while (dx <= r + 1) : (dx += 1) {
                var dz: i32 = -r;
                while (dz <= r + 1) : (dz += 1) {
                    // Skip positions occupied by trunk logs
                    const is_trunk_col = (dx == 0 or dx == 1) and (dz == 0 or dz == 1);
                    if (is_trunk_col and leaf_y <= clamped_height) continue;

                    if (layer.skip_corners) {
                        const is_corner = (dx == -r or dx == r + 1) and (dz == -r or dz == r + 1);
                        if (is_corner) continue;
                    }

                    if (count < buffer.len) {
                        buffer[count] = .{
                            .dx = dx,
                            .dy = leaf_y,
                            .dz = dz,
                            .block_type = .leaves,
                        };
                        count += 1;
                    }
                }
            }
        }

        return count;
    }
};

/// Free function matching the exact signature requested in requirements:
/// `canGrowDarkOak([4]bool, clearance_height: u8) bool`
pub fn canGrowDarkOak(saplings: [4]bool, clearance_height: u8) bool {
    return DarkOakGrowth.canGrowDarkOak(saplings, clearance_height);
}

// ============================================================================
// 2. GiantMushroomVariant: Red Bell Cap, Brown Flat Cap & Bone Meal Growth
// ============================================================================

pub const SubstrateType = enum(u8) {
    dirt,
    grass,
    podzol,
    mycelium,
    stone,
    other,

    pub fn isFungusFriendly(self: SubstrateType) bool {
        return self == .podzol or self == .mycelium;
    }
};

pub const MushroomCapShape = enum(u8) {
    dome_bell_with_spots,
    wide_flat_5x5,
};

pub const MushroomBlockRole = enum(u8) {
    stem,
    red_cap,
    brown_cap,
};

pub const MushroomStructureBlock = struct {
    dx: i32,
    dy: i32,
    dz: i32,
    role: MushroomBlockRole,
    has_white_spots: bool,
};

pub const GiantMushroomVariant = enum(u8) {
    red_bell_cap,
    brown_flat_cap,

    pub const min_red_stem: u8 = 5;
    pub const max_red_stem: u8 = 7;
    pub const min_brown_stem: u8 = 6;
    pub const max_brown_stem: u8 = 9;

    pub fn minStemHeight(self: GiantMushroomVariant) u8 {
        return switch (self) {
            .red_bell_cap => min_red_stem,
            .brown_flat_cap => min_brown_stem,
        };
    }

    pub fn maxStemHeight(self: GiantMushroomVariant) u8 {
        return switch (self) {
            .red_bell_cap => max_red_stem,
            .brown_flat_cap => max_brown_stem,
        };
    }

    pub fn isValidStemHeight(self: GiantMushroomVariant, height: u8) bool {
        return height >= self.minStemHeight() and height <= self.maxStemHeight();
    }

    pub fn capShape(self: GiantMushroomVariant) MushroomCapShape {
        return switch (self) {
            .red_bell_cap => .dome_bell_with_spots,
            .brown_flat_cap => .wide_flat_5x5,
        };
    }

    /// Bone meal growth check on mushroom:
    /// - On mycelium or podzol substrate: grows regardless of light level (even at 15).
    /// - On other substrates: requires light level <= 12.
    pub fn canGrowWithBoneMeal(light_level: u8, substrate: SubstrateType) bool {
        if (substrate.isFungusFriendly()) return true;
        return light_level <= 12;
    }

    pub fn canGrowWithBoneMealBool(light_level: u8, is_mycelium_or_podzol: bool) bool {
        if (is_mycelium_or_podzol) return true;
        return light_level <= 12;
    }

    /// Procedural giant mushroom structure generation.
    pub fn generateStructure(
        self: GiantMushroomVariant,
        stem_height: u8,
        buffer: []MushroomStructureBlock,
    ) usize {
        const clamped_stem = std.math.clamp(stem_height, self.minStemHeight(), self.maxStemHeight());
        var count: usize = 0;

        // 1. Central vertical stem
        var y: i32 = 1;
        while (y <= clamped_stem) : (y += 1) {
            if (count < buffer.len) {
                buffer[count] = .{
                    .dx = 0,
                    .dy = y,
                    .dz = 0,
                    .role = .stem,
                    .has_white_spots = false,
                };
                count += 1;
            }
        }

        const top_y = @as(i32, clamped_stem);

        // 2. Cap generation
        switch (self) {
            .red_bell_cap => {
                // Red mushroom: dome cap with white spots
                // Layer top: 3x3 filled cap
                var dx: i32 = -1;
                while (dx <= 1) : (dx += 1) {
                    var dz: i32 = -1;
                    while (dz <= 1) : (dz += 1) {
                        if (count < buffer.len) {
                            buffer[count] = .{
                                .dx = dx,
                                .dy = top_y,
                                .dz = dz,
                                .role = .red_cap,
                                .has_white_spots = (dx == 0 or dz == 0),
                            };
                            count += 1;
                        }
                    }
                }

                // Layer top - 1: 5x5 ring with rounded corners
                const mid_y = top_y - 1;
                var mx: i32 = -2;
                while (mx <= 2) : (mx += 1) {
                    var mz: i32 = -2;
                    while (mz <= 2) : (mz += 1) {
                        const is_edge = (mx == -2 or mx == 2 or mz == -2 or mz == 2);
                        const is_corner = (mx == -2 or mx == 2) and (mz == -2 or mz == 2);
                        if (is_edge and !is_corner) {
                            if (count < buffer.len) {
                                buffer[count] = .{
                                    .dx = mx,
                                    .dy = mid_y,
                                    .dz = mz,
                                    .role = .red_cap,
                                    .has_white_spots = (@mod(mx + mz, 2) == 0),
                                };
                                count += 1;
                            }
                        }
                    }
                }

                // Layer top - 2: bottom skirt along cardinal edges
                const skirt_y = top_y - 2;
                const skirt_coords = [_][2]i32{
                    .{ 0, -2 },
                    .{ 0, 2 },
                    .{ -2, 0 },
                    .{ 2, 0 },
                };
                for (skirt_coords) |coord| {
                    if (count < buffer.len) {
                        buffer[count] = .{
                            .dx = coord[0],
                            .dy = skirt_y,
                            .dz = coord[1],
                            .role = .red_cap,
                            .has_white_spots = true,
                        };
                        count += 1;
                    }
                }
            },
            .brown_flat_cap => {
                // Brown mushroom: wide 5x5 flat cap at top of stem
                var fx: i32 = -2;
                while (fx <= 2) : (fx += 1) {
                    var fz: i32 = -2;
                    while (fz <= 2) : (fz += 1) {
                        if (count < buffer.len) {
                            buffer[count] = .{
                                .dx = fx,
                                .dy = top_y,
                                .dz = fz,
                                .role = .brown_cap,
                                .has_white_spots = false,
                            };
                            count += 1;
                        }
                    }
                }
            },
        }

        return count;
    }
};

// ============================================================================
// 3. MushroomBlockDrop: Mining Drops, Silk Touch & Pores on Inside Faces
// ============================================================================

pub const MushroomBlockType = enum(u8) {
    red_mushroom_block,
    brown_mushroom_block,
    mushroom_stem,
};

pub const Direction = enum(u8) {
    north,
    south,
    east,
    west,
    up,
    down,
};

pub const FaceTexture = enum(u8) {
    skin,
    pores,
    stem,
};

pub const MushroomDrop = struct {
    item_id: []const u8,
    count: u8,
    is_silk_touch_block: bool,
};

pub const MushroomBlockDrop = struct {
    pub const min_drops_without_silk_touch: u8 = 0;
    pub const max_drops_without_silk_touch: u8 = 2;

    /// Calculate drops when mining giant mushroom blocks:
    /// - With Silk Touch: drops the mushroom block itself (count = 1).
    /// - Without Silk Touch: drops 0..2 small mushrooms based on rng roll.
    pub fn getDrop(block_type: MushroomBlockType, has_silk_touch: bool, roll: f32) MushroomDrop {
        if (has_silk_touch) {
            const block_name = switch (block_type) {
                .red_mushroom_block => "red_mushroom_block",
                .brown_mushroom_block => "brown_mushroom_block",
                .mushroom_stem => "mushroom_stem",
            };
            return .{
                .item_id = block_name,
                .count = 1,
                .is_silk_touch_block = true,
            };
        }

        // Without Silk Touch: 0..2 small mushrooms
        const count: u8 = if (roll < (1.0 / 3.0))
            0
        else if (roll < (2.0 / 3.0))
            1
        else
            2;

        const small_mushroom_name = switch (block_type) {
            .red_mushroom_block => "red_mushroom",
            .brown_mushroom_block => "brown_mushroom",
            .mushroom_stem => "mushroom",
        };

        return .{
            .item_id = small_mushroom_name,
            .count = count,
            .is_silk_touch_block = false,
        };
    }

    /// Evaluates the texture of a face on a giant mushroom block.
    /// - Faces adjoining an existing adjacent mushroom block are interior and show pores.
    /// - Outside faces show exterior skin (or stem bark).
    /// - When an adjacent block is broken, the previously shared interior face reveals pores.
    pub fn getFaceTexture(
        block_type: MushroomBlockType,
        face: Direction,
        is_external_cap_face: bool,
        has_adjacent_block: bool,
    ) FaceTexture {
        _ = face;
        if (has_adjacent_block) {
            return .pores;
        }

        if (is_external_cap_face) {
            return if (block_type == .mushroom_stem) .stem else .skin;
        } else {
            return .pores;
        }
    }

    /// Pores on inside faces when adjacent mushroom block is broken:
    /// Returns the face texture exposed when an adjacent neighbor block is broken.
    pub fn onAdjacentBlockBroken(
        block_type: MushroomBlockType,
        face: Direction,
        was_shared_interior: bool,
    ) FaceTexture {
        _ = face;
        if (was_shared_interior) {
            return .pores;
        }
        return if (block_type == .mushroom_stem) .stem else .skin;
    }
};

// ============================================================================
// 4. CanopyShadeLight: Attenuation & Daytime Hostile Mob Spawning
// ============================================================================

pub const CanopyShadeLight = struct {
    pub const min_canopy_attenuation: u4 = 8;
    pub const max_canopy_attenuation: u4 = 12;
    pub const daytime_full_sky_light: u4 = 15;
    pub const max_spawning_sky_light: u4 = 7;
    pub const max_spawning_block_light: u4 = 0;

    /// Validates whether canopy attenuation falls within the dense dark forest range (8..12).
    pub fn isValidCanopyAttenuation(attenuation: u4) bool {
        return attenuation >= min_canopy_attenuation and attenuation <= max_canopy_attenuation;
    }

    /// Attenuates incoming sky light by the canopy density factor.
    pub fn attenuateSkyLight(sky_light: u4, canopy_attenuation: u4) u4 {
        if (canopy_attenuation >= sky_light) return 0;
        return sky_light - canopy_attenuation;
    }

    /// Checks if hostile mobs can spawn during the daytime under the dark forest canopy.
    /// Spawning conditions:
    /// - Local block light == 0 (no torches/light sources).
    /// - Attenuated sky light at ground <= 7.
    pub fn canHostileMobSpawnDaytime(
        block_light: u4,
        sky_light_at_ground: u4,
    ) bool {
        return (block_light == max_spawning_block_light) and (sky_light_at_ground <= max_spawning_sky_light);
    }

    /// End-to-end check from incident sky light, canopy attenuation, and block light.
    pub fn canHostileSpawnUnderCanopy(
        incident_sky_light: u4,
        canopy_attenuation: u4,
        block_light: u4,
    ) bool {
        const ground_sky_light = attenuateSkyLight(incident_sky_light, canopy_attenuation);
        return canHostileMobSpawnDaytime(block_light, ground_sky_light);
    }
};

// ============================================================================
// 5. DarkOakSaplingDrop: Decay Chance & Sustainable Harvest Recovery
// ============================================================================

pub const DarkOakSaplingDrop = struct {
    pub const sapling_decay_chance: f32 = 0.05; // 5% (1 in 20)
    pub const apple_decay_chance: f32 = 0.005; // 0.5% (1 in 200)
    pub const sapling_one_in_n: u32 = 20;
    pub const apple_one_in_n: u32 = 200;
    pub const required_saplings_for_tree: u8 = 4;
    pub const min_canopy_leaves_for_sustainability: usize = 80;

    pub const LeafDrop = struct {
        has_sapling: bool,
        has_apple: bool,
    };

    /// Evaluates if a decayed leaf block drops a sapling and/or an apple from uniform random rolls in [0.0, 1.0).
    pub fn rollLeafDrop(sapling_roll: f32, apple_roll: f32) LeafDrop {
        return .{
            .has_sapling = sapling_roll < sapling_decay_chance,
            .has_apple = apple_roll < apple_decay_chance,
        };
    }

    /// Expected number of saplings dropped from a canopy of `leaf_count` leaves.
    pub fn expectedSaplings(leaf_count: usize) f32 {
        return @as(f32, @floatFromInt(leaf_count)) * sapling_decay_chance;
    }

    /// Expected number of apples dropped from a canopy of `leaf_count` leaves.
    pub fn expectedApples(leaf_count: usize) f32 {
        return @as(f32, @floatFromInt(leaf_count)) * apple_decay_chance;
    }

    /// Returns whether the canopy leaf count provides a sustainable harvest
    /// (expected saplings >= 4, allowing complete recovery of the 2x2 planting investment).
    pub fn isSustainableHarvest(leaf_count: usize) bool {
        return expectedSaplings(leaf_count) >= @as(f32, @floatFromInt(required_saplings_for_tree));
    }
};

// ============================================================================
// Tests
// ============================================================================

test "DarkOakGrowth: canGrowDarkOak requires all 4 saplings in 2x2 cluster" {
    const all_present = [4]bool{ true, true, true, true };
    try std.testing.expect(canGrowDarkOak(all_present, 6));
    try std.testing.expect(canGrowDarkOak(all_present, 8));
    try std.testing.expect(canGrowDarkOak(all_present, 11));

    const grid = [2][2]bool{
        .{ true, true },
        .{ true, true },
    };
    try std.testing.expect(DarkOakGrowth.isClusterComplete(grid));
}

test "DarkOakGrowth: single sapling cannot grow and incomplete clusters fail" {
    // Single sapling configurations
    const single_sapling_0 = [4]bool{ true, false, false, false };
    const single_sapling_1 = [4]bool{ false, true, false, false };
    const single_sapling_2 = [4]bool{ false, false, true, false };
    const single_sapling_3 = [4]bool{ false, false, false, true };

    try std.testing.expect(!canGrowDarkOak(single_sapling_0, 8));
    try std.testing.expect(!canGrowDarkOak(single_sapling_1, 8));
    try std.testing.expect(!canGrowDarkOak(single_sapling_2, 8));
    try std.testing.expect(!canGrowDarkOak(single_sapling_3, 8));

    // Three saplings (missing one)
    const three_saplings = [4]bool{ true, true, true, false };
    try std.testing.expect(!canGrowDarkOak(three_saplings, 8));

    const incomplete_grid = [2][2]bool{
        .{ true, false },
        .{ true, true },
    };
    try std.testing.expect(!DarkOakGrowth.isClusterComplete(incomplete_grid));
}

test "DarkOakGrowth: clearance height must be in range 6..11 blocks" {
    const all_present = [4]bool{ true, true, true, true };

    // Below minimum clearance (0..5) fails
    try std.testing.expect(!canGrowDarkOak(all_present, 0));
    try std.testing.expect(!canGrowDarkOak(all_present, 4));
    try std.testing.expect(!canGrowDarkOak(all_present, 5));

    // Valid range 6..11 passes
    var h: u8 = 6;
    while (h <= 11) : (h += 1) {
        try std.testing.expect(canGrowDarkOak(all_present, h));
    }

    // Above maximum clearance (12+) fails
    try std.testing.expect(!canGrowDarkOak(all_present, 12));
    try std.testing.expect(!canGrowDarkOak(all_present, 15));
}

test "DarkOakGrowth: procedural generation produces 2x2 trunk and dense leaf roof" {
    var buffer: [512]DarkOakBlock = undefined;
    const count = DarkOakGrowth.generateTree(7, &buffer);
    try std.testing.expect(count > 0);

    var trunk_count: usize = 0;
    var leaf_count: usize = 0;

    for (buffer[0..count]) |b| {
        switch (b.block_type) {
            .trunk_log => trunk_count += 1,
            .branch_log => {},
            .leaves => leaf_count += 1,
        }
    }

    // 2x2 trunk of height 7 has exactly 4 * 7 = 28 trunk logs
    try std.testing.expectEqual(@as(usize, 28), trunk_count);
    // Dense leaf roof should contain >= 80 leaves
    try std.testing.expect(leaf_count >= 80);
}

test "GiantMushroomVariant: stem height constraints for red bell and brown flat caps" {
    const red = GiantMushroomVariant.red_bell_cap;
    const brown = GiantMushroomVariant.brown_flat_cap;

    // Red stem: 5..7
    try std.testing.expectEqual(@as(u8, 5), red.minStemHeight());
    try std.testing.expectEqual(@as(u8, 7), red.maxStemHeight());
    try std.testing.expect(!red.isValidStemHeight(4));
    try std.testing.expect(red.isValidStemHeight(5));
    try std.testing.expect(red.isValidStemHeight(6));
    try std.testing.expect(red.isValidStemHeight(7));
    try std.testing.expect(!red.isValidStemHeight(8));

    // Brown stem: 6..9
    try std.testing.expectEqual(@as(u8, 6), brown.minStemHeight());
    try std.testing.expectEqual(@as(u8, 9), brown.maxStemHeight());
    try std.testing.expect(!brown.isValidStemHeight(5));
    try std.testing.expect(brown.isValidStemHeight(6));
    try std.testing.expect(brown.isValidStemHeight(7));
    try std.testing.expect(brown.isValidStemHeight(8));
    try std.testing.expect(brown.isValidStemHeight(9));
    try std.testing.expect(!brown.isValidStemHeight(10));
}

test "GiantMushroomVariant: cap geometry profiles (bell dome vs flat 5x5)" {
    try std.testing.expectEqual(MushroomCapShape.dome_bell_with_spots, GiantMushroomVariant.red_bell_cap.capShape());
    try std.testing.expectEqual(MushroomCapShape.wide_flat_5x5, GiantMushroomVariant.brown_flat_cap.capShape());
}

test "GiantMushroomVariant: bone meal growth succeeds at any light level on mycelium or podzol" {
    const light_levels = [_]u8{ 0, 4, 8, 12, 13, 14, 15 };

    // Mycelium substrate allows bone meal growth at every light level
    for (light_levels) |light| {
        try std.testing.expect(GiantMushroomVariant.canGrowWithBoneMeal(light, .mycelium));
        try std.testing.expect(GiantMushroomVariant.canGrowWithBoneMealBool(light, true));
    }

    // Podzol substrate allows bone meal growth at every light level
    for (light_levels) |light| {
        try std.testing.expect(GiantMushroomVariant.canGrowWithBoneMeal(light, .podzol));
        try std.testing.expect(GiantMushroomVariant.canGrowWithBoneMealBool(light, true));
    }
}

test "GiantMushroomVariant: bone meal growth on non-fungal soil requires light level <= 12" {
    const non_fungal_soils = [_]SubstrateType{ .dirt, .grass, .stone, .other };

    for (non_fungal_soils) |soil| {
        // Light levels 0..12 permit growth
        var l: u8 = 0;
        while (l <= 12) : (l += 1) {
            try std.testing.expect(GiantMushroomVariant.canGrowWithBoneMeal(l, soil));
            try std.testing.expect(GiantMushroomVariant.canGrowWithBoneMealBool(l, false));
        }

        // Light levels 13..15 block growth
        try std.testing.expect(!GiantMushroomVariant.canGrowWithBoneMeal(13, soil));
        try std.testing.expect(!GiantMushroomVariant.canGrowWithBoneMeal(14, soil));
        try std.testing.expect(!GiantMushroomVariant.canGrowWithBoneMeal(15, soil));
        try std.testing.expect(!GiantMushroomVariant.canGrowWithBoneMealBool(13, false));
        try std.testing.expect(!GiantMushroomVariant.canGrowWithBoneMealBool(15, false));
    }
}

test "GiantMushroomVariant: procedural generation of giant red and brown mushrooms" {
    var buffer: [128]MushroomStructureBlock = undefined;

    // Red bell cap mushroom with stem height 6
    const red_count = GiantMushroomVariant.red_bell_cap.generateStructure(6, &buffer);
    try std.testing.expect(red_count > 0);

    var red_stems: usize = 0;
    var red_caps: usize = 0;
    var spot_count: usize = 0;

    for (buffer[0..red_count]) |b| {
        if (b.role == .stem) red_stems += 1;
        if (b.role == .red_cap) {
            red_caps += 1;
            if (b.has_white_spots) spot_count += 1;
        }
    }

    try std.testing.expectEqual(@as(usize, 6), red_stems);
    try std.testing.expect(red_caps > 0);
    try std.testing.expect(spot_count > 0); // Red mushroom dome has white spots

    // Brown flat cap mushroom with stem height 7
    const brown_count = GiantMushroomVariant.brown_flat_cap.generateStructure(7, &buffer);
    try std.testing.expect(brown_count > 0);

    var brown_stems: usize = 0;
    var brown_caps: usize = 0;

    for (buffer[0..brown_count]) |b| {
        if (b.role == .stem) brown_stems += 1;
        if (b.role == .brown_cap) brown_caps += 1;
    }

    try std.testing.expectEqual(@as(usize, 7), brown_stems);
    // Wide 5x5 flat cap has 5 * 5 = 25 cap blocks
    try std.testing.expectEqual(@as(usize, 25), brown_caps);
}

test "MushroomBlockDrop: silk touch mining drops the mushroom block itself" {
    const red_drop = MushroomBlockDrop.getDrop(.red_mushroom_block, true, 0.5);
    try std.testing.expect(red_drop.is_silk_touch_block);
    try std.testing.expectEqual(@as(u8, 1), red_drop.count);
    try std.testing.expectEqualStrings("red_mushroom_block", red_drop.item_id);

    const brown_drop = MushroomBlockDrop.getDrop(.brown_mushroom_block, true, 0.1);
    try std.testing.expect(brown_drop.is_silk_touch_block);
    try std.testing.expectEqual(@as(u8, 1), brown_drop.count);
    try std.testing.expectEqualStrings("brown_mushroom_block", brown_drop.item_id);

    const stem_drop = MushroomBlockDrop.getDrop(.mushroom_stem, true, 0.9);
    try std.testing.expect(stem_drop.is_silk_touch_block);
    try std.testing.expectEqual(@as(u8, 1), stem_drop.count);
    try std.testing.expectEqualStrings("mushroom_stem", stem_drop.item_id);
}

test "MushroomBlockDrop: non-silk touch mining drops 0..2 small mushrooms" {
    // Roll < 1/3 (0.3333) -> 0 drops
    const zero_drop = MushroomBlockDrop.getDrop(.red_mushroom_block, false, 0.1);
    try std.testing.expect(!zero_drop.is_silk_touch_block);
    try std.testing.expectEqual(@as(u8, 0), zero_drop.count);
    try std.testing.expectEqualStrings("red_mushroom", zero_drop.item_id);

    // Roll in 1/3..2/3 (0.5) -> 1 drop
    const one_drop = MushroomBlockDrop.getDrop(.brown_mushroom_block, false, 0.5);
    try std.testing.expect(!one_drop.is_silk_touch_block);
    try std.testing.expectEqual(@as(u8, 1), one_drop.count);
    try std.testing.expectEqualStrings("brown_mushroom", one_drop.item_id);

    // Roll >= 2/3 (0.8) -> 2 drops
    const two_drop = MushroomBlockDrop.getDrop(.red_mushroom_block, false, 0.85);
    try std.testing.expect(!two_drop.is_silk_touch_block);
    try std.testing.expectEqual(@as(u8, 2), two_drop.count);
    try std.testing.expectEqualStrings("red_mushroom", two_drop.item_id);
}

test "MushroomBlockDrop: pores appear on inside faces when adjacent mushroom block is broken" {
    // When adjacent block was present (interior junction), the face shows pores
    const connected_face = MushroomBlockDrop.getFaceTexture(.red_mushroom_block, .north, false, true);
    try std.testing.expectEqual(FaceTexture.pores, connected_face);

    // When that adjacent interior block is broken, the exposed face reveals pores
    const broken_interior = MushroomBlockDrop.onAdjacentBlockBroken(.red_mushroom_block, .north, true);
    try std.testing.expectEqual(FaceTexture.pores, broken_interior);

    // A natural exterior boundary face shows skin (not pores)
    const broken_exterior = MushroomBlockDrop.onAdjacentBlockBroken(.red_mushroom_block, .up, false);
    try std.testing.expectEqual(FaceTexture.skin, broken_exterior);

    // Stem block exterior face shows stem bark
    const stem_exterior = MushroomBlockDrop.onAdjacentBlockBroken(.mushroom_stem, .north, false);
    try std.testing.expectEqual(FaceTexture.stem, stem_exterior);
}

test "CanopyShadeLight: canopy attenuation validates within 8..12 range" {
    try std.testing.expect(!CanopyShadeLight.isValidCanopyAttenuation(7));
    try std.testing.expect(CanopyShadeLight.isValidCanopyAttenuation(8));
    try std.testing.expect(CanopyShadeLight.isValidCanopyAttenuation(9));
    try std.testing.expect(CanopyShadeLight.isValidCanopyAttenuation(10));
    try std.testing.expect(CanopyShadeLight.isValidCanopyAttenuation(11));
    try std.testing.expect(CanopyShadeLight.isValidCanopyAttenuation(12));
    try std.testing.expect(!CanopyShadeLight.isValidCanopyAttenuation(13));
}

test "CanopyShadeLight: daytime sky light 15 attenuated to <= 7 allows hostile spawning with zero block light" {
    const daytime_sky: u4 = 15;

    // Minimum attenuation of 8: 15 - 8 = 7 (exactly <= 7 threshold)
    const sky_at_8 = CanopyShadeLight.attenuateSkyLight(daytime_sky, 8);
    try std.testing.expectEqual(@as(u4, 7), sky_at_8);
    try std.testing.expect(CanopyShadeLight.canHostileMobSpawnDaytime(0, sky_at_8));
    try std.testing.expect(CanopyShadeLight.canHostileSpawnUnderCanopy(daytime_sky, 8, 0));

    // Mid attenuation of 10: 15 - 10 = 5 (well below 7)
    const sky_at_10 = CanopyShadeLight.attenuateSkyLight(daytime_sky, 10);
    try std.testing.expectEqual(@as(u4, 5), sky_at_10);
    try std.testing.expect(CanopyShadeLight.canHostileMobSpawnDaytime(0, sky_at_10));
    try std.testing.expect(CanopyShadeLight.canHostileSpawnUnderCanopy(daytime_sky, 10, 0));

    // Maximum attenuation of 12: 15 - 12 = 3
    const sky_at_12 = CanopyShadeLight.attenuateSkyLight(daytime_sky, 12);
    try std.testing.expectEqual(@as(u4, 3), sky_at_12);
    try std.testing.expect(CanopyShadeLight.canHostileMobSpawnDaytime(0, sky_at_12));
    try std.testing.expect(CanopyShadeLight.canHostileSpawnUnderCanopy(daytime_sky, 12, 0));
}

test "CanopyShadeLight: non-zero block light suppresses hostile mob spawning under daytime canopy" {
    const daytime_sky: u4 = 15;
    const attenuation: u4 = 10; // Resulting sky light = 5

    // Block light > 0 (torches, lanterns) prevents hostile spawning
    try std.testing.expect(!CanopyShadeLight.canHostileSpawnUnderCanopy(daytime_sky, attenuation, 1));
    try std.testing.expect(!CanopyShadeLight.canHostileSpawnUnderCanopy(daytime_sky, attenuation, 7));
    try std.testing.expect(!CanopyShadeLight.canHostileSpawnUnderCanopy(daytime_sky, attenuation, 14));

    // Insufficient attenuation (e.g. normal tree canopy attenuation = 2): 15 - 2 = 13 > 7
    try std.testing.expect(!CanopyShadeLight.canHostileSpawnUnderCanopy(daytime_sky, 2, 0));
}

test "DarkOakSaplingDrop: decay drop rates are 5% for saplings and 0.5% for apples" {
    try std.testing.expectEqual(@as(f32, 0.05), DarkOakSaplingDrop.sapling_decay_chance);
    try std.testing.expectEqual(@as(f32, 0.005), DarkOakSaplingDrop.apple_decay_chance);

    // Roll below chance yields item
    const lucky_drop = DarkOakSaplingDrop.rollLeafDrop(0.04, 0.003);
    try std.testing.expect(lucky_drop.has_sapling);
    try std.testing.expect(lucky_drop.has_apple);

    // Roll above chance yields nothing
    const unlucky_drop = DarkOakSaplingDrop.rollLeafDrop(0.06, 0.006);
    try std.testing.expect(!unlucky_drop.has_sapling);
    try std.testing.expect(!unlucky_drop.has_apple);
}

test "DarkOakSaplingDrop: canopy size of 80+ leaves yields >= 4 saplings on average ensuring sustainability" {
    // 80 leaves * 0.05 = 4.0 saplings
    try std.testing.expectEqual(@as(f32, 4.0), DarkOakSaplingDrop.expectedSaplings(80));
    try std.testing.expect(DarkOakSaplingDrop.isSustainableHarvest(80));

    // 100 leaves * 0.05 = 5.0 saplings
    try std.testing.expectEqual(@as(f32, 5.0), DarkOakSaplingDrop.expectedSaplings(100));
    try std.testing.expect(DarkOakSaplingDrop.isSustainableHarvest(100));

    // 60 leaves * 0.05 = 3.0 saplings (< 4.0, unsustainable)
    try std.testing.expectEqual(@as(f32, 3.0), DarkOakSaplingDrop.expectedSaplings(60));
    try std.testing.expect(!DarkOakSaplingDrop.isSustainableHarvest(60));

    // Apple expectation: 200 leaves * 0.005 = 1.0 apple
    try std.testing.expectEqual(@as(f32, 1.0), DarkOakSaplingDrop.expectedApples(200));
}
