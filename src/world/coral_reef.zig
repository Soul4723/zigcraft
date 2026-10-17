const std = @import("std");

/// Normalized floating-point RGB color in the [0.0, 1.0] range.
pub const ColorRgb = struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn toArray(self: ColorRgb) [3]f32 {
        return .{ self.r, self.g, self.b };
    }

    pub fn isGrayscale(self: ColorRgb) bool {
        const diff_rg = @abs(self.r - self.g);
        const diff_gb = @abs(self.g - self.b);
        return diff_rg < 0.001 and diff_gb < 0.001;
    }
};

/// Universal dead/bleached coral gray color.
pub const dead_coral_color_rgb: ColorRgb = .{ .r = 0.52, .g = 0.52, .b = 0.52 };

/// Five canonical Minecraft coral species with distinct vibrant normalized RGB color signatures.
pub const CoralSpecies = enum(u3) {
    tube_blue = 0,
    brain_pink = 1,
    bubble_purple = 2,
    fire_red = 3,
    horn_yellow = 4,

    pub const count: usize = 5;
    pub const all: [count]CoralSpecies = .{
        .tube_blue,
        .brain_pink,
        .bubble_purple,
        .fire_red,
        .horn_yellow,
    };

    /// Normalized RGB color for living specimens of this species.
    pub fn getRgb(self: CoralSpecies) ColorRgb {
        return switch (self) {
            .tube_blue => .{ .r = 0.19, .g = 0.38, .b = 0.89 },
            .brain_pink => .{ .r = 0.88, .g = 0.32, .b = 0.65 },
            .bubble_purple => .{ .r = 0.65, .g = 0.18, .b = 0.78 },
            .fire_red => .{ .r = 0.89, .g = 0.18, .b = 0.18 },
            .horn_yellow => .{ .r = 0.93, .g = 0.82, .b = 0.17 },
        };
    }

    pub fn name(self: CoralSpecies) []const u8 {
        return switch (self) {
            .tube_blue => "tube",
            .brain_pink => "brain",
            .bubble_purple => "bubble",
            .fire_red => "fire",
            .horn_yellow => "horn",
        };
    }

    pub fn fromInt(val: u3) ?CoralSpecies {
        if (val < count) return @enumFromInt(val);
        return null;
    }
};

/// Forms in which coral can exist in the world.
pub const CoralForm = enum(u2) {
    coral_block = 0,
    coral_polyp = 1,
    coral_fan = 2,
    wall_coral_fan = 3,

    pub const count: usize = 4;
    pub const all: [count]CoralForm = .{
        .coral_block,
        .coral_polyp,
        .coral_fan,
        .wall_coral_fan,
    };

    pub fn isBlock(self: CoralForm) bool {
        return self == .coral_block;
    }

    pub fn isPolyp(self: CoralForm) bool {
        return self == .coral_polyp;
    }

    pub fn isFan(self: CoralForm) bool {
        return self == .coral_fan or self == .wall_coral_fan;
    }

    pub fn isWallAttached(self: CoralForm) bool {
        return self == .wall_coral_fan;
    }

    pub fn isPlantLike(self: CoralForm) bool {
        return self != .coral_block;
    }
};

/// Bleaching time parameters. Living coral out of water bleaches within 3.0 to 5.0 seconds.
pub const bleaching_threshold_seconds: f32 = 4.0;
pub const min_bleaching_threshold_seconds: f32 = 3.0;
pub const max_bleaching_threshold_seconds: f32 = 5.0;

/// Rain alone does NOT keep coral alive; it must be in or adjacent to water blocks.
pub fn rainCountsAsWaterForCoral() bool {
    return false;
}

/// Tracks hydration and bleaching timer of an individual placed coral block or plant.
pub const CoralBleachingState = struct {
    species: CoralSpecies,
    form: CoralForm,
    is_alive: bool = true,
    dry_time_seconds: f32 = 0.0,
    bleaching_threshold_seconds: f32 = 4.0,

    pub fn init(species: CoralSpecies, form: CoralForm) CoralBleachingState {
        return .{
            .species = species,
            .form = form,
            .is_alive = true,
            .dry_time_seconds = 0.0,
            .bleaching_threshold_seconds = 4.0,
        };
    }

    pub fn initDead(species: CoralSpecies, form: CoralForm) CoralBleachingState {
        return .{
            .species = species,
            .form = form,
            .is_alive = false,
            .dry_time_seconds = 4.0,
            .bleaching_threshold_seconds = 4.0,
        };
    }

    pub fn initWithThreshold(species: CoralSpecies, form: CoralForm, threshold_seconds: f32) CoralBleachingState {
        const clamped_threshold = std.math.clamp(
            threshold_seconds,
            min_bleaching_threshold_seconds,
            max_bleaching_threshold_seconds,
        );
        return .{
            .species = species,
            .form = form,
            .is_alive = true,
            .dry_time_seconds = 0.0,
            .bleaching_threshold_seconds = clamped_threshold,
        };
    }

    /// Ticks coral hydration. Returns true if the coral newly bleached during this tick.
    pub fn tickCoralHydration(self: *CoralBleachingState, has_adjacent_water: bool, dt: f32) bool {
        if (!self.is_alive) return false;

        if (has_adjacent_water) {
            self.dry_time_seconds = 0.0;
            return false;
        }

        const delta = @max(0.0, dt);
        self.dry_time_seconds += delta;

        if (self.dry_time_seconds >= self.bleaching_threshold_seconds) {
            self.is_alive = false;
            return true;
        }
        return false;
    }

    pub fn getColorRgb(self: CoralBleachingState) ColorRgb {
        if (!self.is_alive) return dead_coral_color_rgb;
        return self.species.getRgb();
    }

    pub fn rainCountsAsWaterForCoral() bool {
        return false;
    }
};

/// Module-level hydration tick wrapper.
pub fn tickCoralHydration(state: *CoralBleachingState, has_adjacent_water: bool, dt: f32) bool {
    return state.tickCoralHydration(has_adjacent_water, dt);
}

/// Six-way adjacent water presence checker for 3D block neighborhoods.
pub const AdjacentWaterNeighbors = struct {
    neg_x: bool = false,
    pos_x: bool = false,
    neg_y: bool = false,
    pos_y: bool = false,
    neg_z: bool = false,
    pos_z: bool = false,

    pub fn hasAnyWater(self: AdjacentWaterNeighbors) bool {
        return self.neg_x or self.pos_x or self.neg_y or self.pos_y or self.neg_z or self.pos_z;
    }

    pub fn waterCount(self: AdjacentWaterNeighbors) u3 {
        var count: u3 = 0;
        if (self.neg_x) count += 1;
        if (self.pos_x) count += 1;
        if (self.neg_y) count += 1;
        if (self.pos_y) count += 1;
        if (self.neg_z) count += 1;
        if (self.pos_z) count += 1;
        return count;
    }
};

/// Checks if a coral block is hydrated based on surrounding 6 adjacent blocks or waterlogged state.
pub fn isCoralBlockHydrated(neighbors: AdjacentWaterNeighbors, is_submerged: bool) bool {
    return is_submerged or neighbors.hasAnyWater();
}

/// For coral polyps and fans, they must be waterlogged to stay hydrated.
pub fn isCoralPlantHydrated(is_waterlogged: bool) bool {
    return is_waterlogged;
}

/// Universal hydration check taking form, waterlogged state, and adjacent water into account.
pub fn isCoralHydrated(form: CoralForm, is_waterlogged: bool, adjacent_water: AdjacentWaterNeighbors) bool {
    if (form == .coral_block) {
        return is_waterlogged or adjacent_water.hasAnyWater();
    } else {
        return is_waterlogged;
    }
}

/// Item dropped upon harvesting a coral block or plant.
pub const CoralDrop = struct {
    species: CoralSpecies,
    form: CoralForm,
    is_alive: bool,
    count: u8,
};

/// Harvesting mechanics for coral:
/// - Mining living coral_block without Silk Touch drops dead_coral_block (count = 1).
/// - Mining living coral_block with Silk Touch preserves living coral_block (count = 1).
/// - Mining coral_polyp or coral_fan without Silk Touch drops nothing (count = 0).
/// - Mining coral_polyp or coral_fan with Silk Touch drops the living polyp/fan (count = 1).
pub const CoralHarvesting = struct {
    pub fn getDrop(species: CoralSpecies, form: CoralForm, is_alive: bool, has_silk_touch: bool) CoralDrop {
        // Wall coral fans drop ordinary coral fan items when collected
        const drop_form: CoralForm = if (form == .wall_coral_fan) .coral_fan else form;

        if (form == .coral_block) {
            if (has_silk_touch) {
                return .{
                    .species = species,
                    .form = .coral_block,
                    .is_alive = is_alive,
                    .count = 1,
                };
            } else {
                return .{
                    .species = species,
                    .form = .coral_block,
                    .is_alive = false, // Bleaches upon harvest without Silk Touch
                    .count = 1,
                };
            }
        } else {
            // Coral polyps and fans
            if (has_silk_touch) {
                return .{
                    .species = species,
                    .form = drop_form,
                    .is_alive = is_alive,
                    .count = 1,
                };
            } else {
                return .{
                    .species = species,
                    .form = drop_form,
                    .is_alive = false,
                    .count = 0, // Drops nothing without Silk Touch
                };
            }
        }
    }

    pub fn dropsItem(form: CoralForm, has_silk_touch: bool) bool {
        if (form == .coral_block) return true;
        return has_silk_touch;
    }
};

/// Module-level harvest function.
pub fn harvestCoral(species: CoralSpecies, form: CoralForm, is_alive: bool, has_silk_touch: bool) CoralDrop {
    return CoralHarvesting.getDrop(species, form, is_alive, has_silk_touch);
}

/// Valid substrates on which bone meal can grow coral.
pub const SubstrateType = enum {
    dirt,
    coarse_dirt,
    sand,
    red_sand,
    gravel,
    clay,
    stone,
    cobblestone,
    deepslate,
    bedrock,
    other,

    pub fn isValidForBoneMealCoral(self: SubstrateType) bool {
        return switch (self) {
            .dirt, .coarse_dirt, .sand, .red_sand, .gravel => true,
            else => false,
        };
    }
};

/// Bone meal mechanics in Warm Ocean biomes.
pub const WarmOceanBoneMeal = struct {
    /// Bone meal applied underwater in a Warm Ocean biome grows coral polyps, fans, and sea pickles.
    pub fn canGrowCoralWithBoneMeal(in_warm_ocean: bool, is_submerged_water: bool, substrate_valid: bool) bool {
        return in_warm_ocean and is_submerged_water and substrate_valid;
    }

    pub const GrowthKind = enum {
        coral_polyp,
        coral_fan,
        sea_pickle,
    };

    pub const GrowthOutcome = struct {
        kind: GrowthKind,
        species: ?CoralSpecies, // null for sea_pickle
        count: u3, // 1 for coral polyp/fan, 1-4 for sea pickles

        pub fn isCoral(self: GrowthOutcome) bool {
            return self.kind != .sea_pickle;
        }
    };

    /// Generates bone meal growth outcome from a PRNG instance.
    pub fn rollGrowth(prng: *std.Random) GrowthOutcome {
        const roll = prng.intRangeLessThan(u8, 0, 100);
        if (roll < 45) {
            // Coral polyp (45% chance)
            const species_idx = prng.intRangeLessThan(u3, 0, CoralSpecies.count);
            return .{
                .kind = .coral_polyp,
                .species = @enumFromInt(species_idx),
                .count = 1,
            };
        } else if (roll < 80) {
            // Coral fan (35% chance)
            const species_idx = prng.intRangeLessThan(u3, 0, CoralSpecies.count);
            return .{
                .kind = .coral_fan,
                .species = @enumFromInt(species_idx),
                .count = 1,
            };
        } else {
            // Sea pickle (20% chance)
            const pickle_count: u3 = @intCast(prng.intRangeLessThan(u8, 1, 5));
            return .{
                .kind = .sea_pickle,
                .species = null,
                .count = pickle_count,
            };
        }
    }

    /// Generates bone meal growth outcome from a 64-bit seed deterministically.
    pub fn rollGrowthFromSeed(seed: u64) GrowthOutcome {
        var prng = std.Random.DefaultPrng.init(seed);
        var rand = prng.random();
        return rollGrowth(&rand);
    }
};

/// Module-level bone meal check function matching requirement specification.
pub fn canGrowCoralWithBoneMeal(in_warm_ocean: bool, is_submerged_water: bool, substrate_valid: bool) bool {
    return WarmOceanBoneMeal.canGrowCoralWithBoneMeal(in_warm_ocean, is_submerged_water, substrate_valid);
}

/// Structural coral reef formations commonly generated in warm ocean biomes.
pub const ReefFormationType = enum {
    tree,
    claw,
    spire,
    shelf,
};

// ============================================================================
// TESTS (At least 12 comprehensive test blocks)
// ============================================================================

test "CoralSpecies: variants, names, counts, and enum conversions" {
    try std.testing.expectEqual(@as(usize, 5), CoralSpecies.count);
    try std.testing.expectEqualStrings("tube", CoralSpecies.tube_blue.name());
    try std.testing.expectEqualStrings("brain", CoralSpecies.brain_pink.name());
    try std.testing.expectEqualStrings("bubble", CoralSpecies.bubble_purple.name());
    try std.testing.expectEqualStrings("fire", CoralSpecies.fire_red.name());
    try std.testing.expectEqualStrings("horn", CoralSpecies.horn_yellow.name());

    for (0..5) |i| {
        const sp = CoralSpecies.fromInt(@intCast(i));
        try std.testing.expect(sp != null);
    }
    try std.testing.expect(CoralSpecies.fromInt(5) == null);
}

test "CoralSpecies: normalized RGB values in [0.0, 1.0] and unique per species" {
    for (CoralSpecies.all) |species| {
        const rgb = species.getRgb();
        try std.testing.expect(rgb.r >= 0.0 and rgb.r <= 1.0);
        try std.testing.expect(rgb.g >= 0.0 and rgb.g <= 1.0);
        try std.testing.expect(rgb.b >= 0.0 and rgb.b <= 1.0);
        // Living coral is vibrant, not grayscale
        try std.testing.expect(!rgb.isGrayscale());
    }

    // Verify species colors are distinct
    for (0..CoralSpecies.count) |i| {
        for ((i + 1)..CoralSpecies.count) |j| {
            const rgb_a = CoralSpecies.all[i].getRgb();
            const rgb_b = CoralSpecies.all[j].getRgb();
            const same = (rgb_a.r == rgb_b.r and rgb_a.g == rgb_b.g and rgb_a.b == rgb_b.b);
            try std.testing.expect(!same);
        }
    }
}

test "CoralForm: classification of block, polyp, fan, wall fan" {
    try std.testing.expect(CoralForm.coral_block.isBlock());
    try std.testing.expect(!CoralForm.coral_block.isPolyp());
    try std.testing.expect(!CoralForm.coral_block.isFan());
    try std.testing.expect(!CoralForm.coral_block.isWallAttached());
    try std.testing.expect(!CoralForm.coral_block.isPlantLike());

    try std.testing.expect(!CoralForm.coral_polyp.isBlock());
    try std.testing.expect(CoralForm.coral_polyp.isPolyp());
    try std.testing.expect(!CoralForm.coral_polyp.isFan());
    try std.testing.expect(CoralForm.coral_polyp.isPlantLike());

    try std.testing.expect(CoralForm.coral_fan.isFan());
    try std.testing.expect(!CoralForm.coral_fan.isWallAttached());

    try std.testing.expect(CoralForm.wall_coral_fan.isFan());
    try std.testing.expect(CoralForm.wall_coral_fan.isWallAttached());
    try std.testing.expect(CoralForm.wall_coral_fan.isPlantLike());
}

test "CoralBleachingState: initialization defaults and 4.0s bleaching threshold" {
    const state = CoralBleachingState.init(.tube_blue, .coral_block);
    try std.testing.expect(state.is_alive);
    try std.testing.expectEqual(@as(f32, 0.0), state.dry_time_seconds);
    try std.testing.expectEqual(@as(f32, 4.0), state.bleaching_threshold_seconds);

    const dead = CoralBleachingState.initDead(.brain_pink, .coral_fan);
    try std.testing.expect(!dead.is_alive);
    try std.testing.expectEqual(@as(f32, 4.0), dead.dry_time_seconds);
}

test "CoralBleachingState: continuous water hydration prevents bleaching" {
    var state = CoralBleachingState.init(.bubble_purple, .coral_block);

    // Run for 10 seconds with water present
    var t: f32 = 0.0;
    while (t < 10.0) : (t += 0.5) {
        const bleached = state.tickCoralHydration(true, 0.5);
        try std.testing.expect(!bleached);
        try std.testing.expect(state.is_alive);
        try std.testing.expectEqual(@as(f32, 0.0), state.dry_time_seconds);
    }
}

test "CoralBleachingState: out of water bleaching triggers exactly at threshold" {
    var state = CoralBleachingState.init(.fire_red, .coral_polyp);

    // Tick without water up to 3.5 seconds
    var bleached = state.tickCoralHydration(false, 3.5);
    try std.testing.expect(!bleached);
    try std.testing.expect(state.is_alive);
    try std.testing.expectEqual(@as(f32, 3.5), state.dry_time_seconds);

    // Another 0.5 seconds brings total dry time to 4.0 seconds (threshold)
    bleached = state.tickCoralHydration(false, 0.5);
    try std.testing.expect(bleached);
    try std.testing.expect(!state.is_alive);
    try std.testing.expectEqual(@as(f32, 4.0), state.dry_time_seconds);

    // Subsequent ticks on dead coral return false (no further state transition)
    bleached = state.tickCoralHydration(false, 1.0);
    try std.testing.expect(!bleached);
    try std.testing.expect(!state.is_alive);
}

test "CoralBleachingState: threshold clamped between 3.0 and 5.0 seconds" {
    const low = CoralBleachingState.initWithThreshold(.horn_yellow, .coral_block, 1.5);
    try std.testing.expectEqual(min_bleaching_threshold_seconds, low.bleaching_threshold_seconds);

    const high = CoralBleachingState.initWithThreshold(.horn_yellow, .coral_block, 9.0);
    try std.testing.expectEqual(max_bleaching_threshold_seconds, high.bleaching_threshold_seconds);

    var valid = CoralBleachingState.initWithThreshold(.horn_yellow, .coral_block, 3.2);
    try std.testing.expectEqual(@as(f32, 3.2), valid.bleaching_threshold_seconds);

    // Verify it bleaches at 3.2s
    _ = valid.tickCoralHydration(false, 3.1);
    try std.testing.expect(valid.is_alive);
    const bleached = valid.tickCoralHydration(false, 0.2);
    try std.testing.expect(bleached);
    try std.testing.expect(!valid.is_alive);
}

test "CoralBleachingState: re-hydration resets dry timer before threshold" {
    var state = CoralBleachingState.init(.tube_blue, .coral_fan);

    // Dry for 3.0 seconds (close to threshold)
    _ = state.tickCoralHydration(false, 3.0);
    try std.testing.expectEqual(@as(f32, 3.0), state.dry_time_seconds);
    try std.testing.expect(state.is_alive);

    // Water touches the coral -> dry timer resets to 0
    _ = state.tickCoralHydration(true, 0.1);
    try std.testing.expectEqual(@as(f32, 0.0), state.dry_time_seconds);
    try std.testing.expect(state.is_alive);

    // Dry for another 3.0 seconds -> still alive
    _ = state.tickCoralHydration(false, 3.0);
    try std.testing.expect(state.is_alive);
    try std.testing.expectEqual(@as(f32, 3.0), state.dry_time_seconds);
}

test "CoralBleachingState: rain does NOT count as water for coral" {
    try std.testing.expect(!rainCountsAsWaterForCoral());
    try std.testing.expect(!CoralBleachingState.rainCountsAsWaterForCoral());

    var state = CoralBleachingState.init(.brain_pink, .coral_block);

    // Simulate rainy day where rain is present but no adjacent water blocks
    const in_rain = true;
    const has_water_blocks = false;
    const effective_water = has_water_blocks or (in_rain and rainCountsAsWaterForCoral());

    // Because effective_water is false, coral should dry and bleach
    _ = tickCoralHydration(&state, effective_water, 4.0);
    try std.testing.expect(!state.is_alive);
}

test "CoralHarvesting: living coral block with Silk Touch preserves living block" {
    const drop = harvestCoral(.tube_blue, .coral_block, true, true);
    try std.testing.expectEqual(CoralSpecies.tube_blue, drop.species);
    try std.testing.expectEqual(CoralForm.coral_block, drop.form);
    try std.testing.expect(drop.is_alive);
    try std.testing.expectEqual(@as(u8, 1), drop.count);
    try std.testing.expect(CoralHarvesting.dropsItem(.coral_block, true));
}

test "CoralHarvesting: living coral block without Silk Touch drops dead coral block" {
    const drop = harvestCoral(.fire_red, .coral_block, true, false);
    try std.testing.expectEqual(CoralSpecies.fire_red, drop.species);
    try std.testing.expectEqual(CoralForm.coral_block, drop.form);
    try std.testing.expect(!drop.is_alive); // Bleached to dead coral block
    try std.testing.expectEqual(@as(u8, 1), drop.count);
    try std.testing.expect(CoralHarvesting.dropsItem(.coral_block, false));
}

test "CoralHarvesting: living polyp and fan without Silk Touch drop nothing (0)" {
    const polyp_drop = harvestCoral(.bubble_purple, .coral_polyp, true, false);
    try std.testing.expectEqual(@as(u8, 0), polyp_drop.count);
    try std.testing.expect(!CoralHarvesting.dropsItem(.coral_polyp, false));

    const fan_drop = harvestCoral(.horn_yellow, .coral_fan, true, false);
    try std.testing.expectEqual(@as(u8, 0), fan_drop.count);
    try std.testing.expect(!CoralHarvesting.dropsItem(.coral_fan, false));

    const wall_fan_drop = harvestCoral(.brain_pink, .wall_coral_fan, true, false);
    try std.testing.expectEqual(@as(u8, 0), wall_fan_drop.count);
    try std.testing.expect(!CoralHarvesting.dropsItem(.wall_coral_fan, false));
}

test "CoralHarvesting: living polyp and fan with Silk Touch drop living items" {
    const polyp_drop = harvestCoral(.bubble_purple, .coral_polyp, true, true);
    try std.testing.expectEqual(CoralSpecies.bubble_purple, polyp_drop.species);
    try std.testing.expectEqual(CoralForm.coral_polyp, polyp_drop.form);
    try std.testing.expect(polyp_drop.is_alive);
    try std.testing.expectEqual(@as(u8, 1), polyp_drop.count);
    try std.testing.expect(CoralHarvesting.dropsItem(.coral_polyp, true));

    const fan_drop = harvestCoral(.horn_yellow, .coral_fan, true, true);
    try std.testing.expectEqual(CoralSpecies.horn_yellow, fan_drop.species);
    try std.testing.expectEqual(CoralForm.coral_fan, fan_drop.form);
    try std.testing.expect(fan_drop.is_alive);
    try std.testing.expectEqual(@as(u8, 1), fan_drop.count);

    // Wall coral fan drops ordinary coral fan item
    const wall_drop = harvestCoral(.tube_blue, .wall_coral_fan, true, true);
    try std.testing.expectEqual(CoralForm.coral_fan, wall_drop.form);
    try std.testing.expect(wall_drop.is_alive);
    try std.testing.expectEqual(@as(u8, 1), wall_drop.count);
}

test "CoralHarvesting: dead coral harvesting rules" {
    // Dead coral block always drops dead coral block with or without Silk Touch
    const dead_block_no_st = harvestCoral(.brain_pink, .coral_block, false, false);
    try std.testing.expect(!dead_block_no_st.is_alive);
    try std.testing.expectEqual(@as(u8, 1), dead_block_no_st.count);

    const dead_block_st = harvestCoral(.brain_pink, .coral_block, false, true);
    try std.testing.expect(!dead_block_st.is_alive);
    try std.testing.expectEqual(@as(u8, 1), dead_block_st.count);

    // Dead fan without Silk Touch drops 0
    const dead_fan_no_st = harvestCoral(.brain_pink, .coral_fan, false, false);
    try std.testing.expectEqual(@as(u8, 0), dead_fan_no_st.count);

    // Dead fan with Silk Touch drops 1 dead fan
    const dead_fan_st = harvestCoral(.brain_pink, .coral_fan, false, true);
    try std.testing.expect(!dead_fan_st.is_alive);
    try std.testing.expectEqual(@as(u8, 1), dead_fan_st.count);
}

test "WarmOceanBoneMeal: canGrowCoralWithBoneMeal requires all conditions" {
    // True only when warm ocean + submerged + valid substrate
    try std.testing.expect(canGrowCoralWithBoneMeal(true, true, true));

    // Any false condition denies growth
    try std.testing.expect(!canGrowCoralWithBoneMeal(false, true, true));
    try std.testing.expect(!canGrowCoralWithBoneMeal(true, false, true));
    try std.testing.expect(!canGrowCoralWithBoneMeal(true, true, false));
    try std.testing.expect(!canGrowCoralWithBoneMeal(false, false, false));
}

test "WarmOceanBoneMeal: valid substrates include dirt, sand, gravel" {
    try std.testing.expect(SubstrateType.dirt.isValidForBoneMealCoral());
    try std.testing.expect(SubstrateType.coarse_dirt.isValidForBoneMealCoral());
    try std.testing.expect(SubstrateType.sand.isValidForBoneMealCoral());
    try std.testing.expect(SubstrateType.red_sand.isValidForBoneMealCoral());
    try std.testing.expect(SubstrateType.gravel.isValidForBoneMealCoral());

    try std.testing.expect(!SubstrateType.stone.isValidForBoneMealCoral());
    try std.testing.expect(!SubstrateType.cobblestone.isValidForBoneMealCoral());
    try std.testing.expect(!SubstrateType.deepslate.isValidForBoneMealCoral());
    try std.testing.expect(!SubstrateType.bedrock.isValidForBoneMealCoral());
    try std.testing.expect(!SubstrateType.other.isValidForBoneMealCoral());
}

test "WarmOceanBoneMeal: deterministic roll generates polyps, fans, pickles" {
    var found_polyp = false;
    var found_fan = false;
    var found_pickle = false;

    // Test deterministic outcomes over 50 varied seeds
    for (0..50) |seed| {
        const outcome = WarmOceanBoneMeal.rollGrowthFromSeed(seed * 1337 + 42);
        switch (outcome.kind) {
            .coral_polyp => {
                found_polyp = true;
                try std.testing.expect(outcome.species != null);
                try std.testing.expectEqual(@as(u3, 1), outcome.count);
                try std.testing.expect(outcome.isCoral());
            },
            .coral_fan => {
                found_fan = true;
                try std.testing.expect(outcome.species != null);
                try std.testing.expectEqual(@as(u3, 1), outcome.count);
                try std.testing.expect(outcome.isCoral());
            },
            .sea_pickle => {
                found_pickle = true;
                try std.testing.expect(outcome.species == null);
                try std.testing.expect(outcome.count >= 1 and outcome.count <= 4);
                try std.testing.expect(!outcome.isCoral());
            },
        }
    }

    try std.testing.expect(found_polyp);
    try std.testing.expect(found_fan);
    try std.testing.expect(found_pickle);
}

test "Hydration helpers: 6-way adjacent water and waterlogged logic" {
    var water_neighbors = AdjacentWaterNeighbors{};
    try std.testing.expect(!water_neighbors.hasAnyWater());
    try std.testing.expectEqual(@as(u3, 0), water_neighbors.waterCount());

    // Not hydrated without water
    try std.testing.expect(!isCoralBlockHydrated(water_neighbors, false));
    try std.testing.expect(!isCoralHydrated(.coral_block, false, water_neighbors));

    // Water on one face hydrates the block
    water_neighbors.neg_y = true;
    try std.testing.expect(water_neighbors.hasAnyWater());
    try std.testing.expectEqual(@as(u3, 1), water_neighbors.waterCount());
    try std.testing.expect(isCoralBlockHydrated(water_neighbors, false));
    try std.testing.expect(isCoralHydrated(.coral_block, false, water_neighbors));

    // Submerged block is hydrated regardless of neighbors
    try std.testing.expect(isCoralBlockHydrated(AdjacentWaterNeighbors{}, true));

    // Coral plants require waterlogged state
    try std.testing.expect(!isCoralPlantHydrated(false));
    try std.testing.expect(isCoralPlantHydrated(true));
    try std.testing.expect(!isCoralHydrated(.coral_polyp, false, water_neighbors));
    try std.testing.expect(isCoralHydrated(.coral_polyp, true, AdjacentWaterNeighbors{}));
}

test "Color: bleached coral has grayscale color signature" {
    var state = CoralBleachingState.init(.tube_blue, .coral_block);
    const alive_color = state.getColorRgb();
    try std.testing.expect(!alive_color.isGrayscale());

    _ = state.tickCoralHydration(false, 4.0);
    try std.testing.expect(!state.is_alive);

    const dead_color = state.getColorRgb();
    try std.testing.expect(dead_color.isGrayscale());
    try std.testing.expectEqual(dead_coral_color_rgb.r, dead_color.r);
    try std.testing.expectEqual(dead_coral_color_rgb.g, dead_color.g);
    try std.testing.expectEqual(dead_coral_color_rgb.b, dead_color.b);
}
