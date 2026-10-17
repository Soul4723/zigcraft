const std = @import("std");

/// Recipe family selector for the one-input Stonecutter recipes.
pub const StonecutterCutRatio = enum {
    stairs,
    slabs,
    wall,
    chiseled,
    cut_copper,
    copper_grate,
};

/// Crafting-table recipe: six blocks produce four stairs (1.5 blocks/stair).
pub const crafting_table_stair_input: u8 = 6;
pub const crafting_table_stair_output: u8 = 4;

/// Output count for one supported input block in a Stonecutter.
pub fn stonecutterYield(cut: StonecutterCutRatio) u8 {
    return switch (cut) {
        .stairs, .wall, .chiseled => 1,
        .slabs => 2,
        .cut_copper, .copper_grate => 4,
    };
}

pub const SpecializedFurnaceKind = enum {
    standard_furnace,
    blast_furnace_ores_and_metal_gear,
    smoker_food_and_kelp,
};

pub const FurnaceSmeltCycle = struct {
    can_smelt: bool,
    smelt_duration_seconds: f32,
};

pub fn resolveFurnaceSmeltCycle(
    kind: SpecializedFurnaceKind,
    item_is_ore_or_metal: bool,
    item_is_food_or_kelp: bool,
) FurnaceSmeltCycle {
    return switch (kind) {
        .standard_furnace => .{
            .can_smelt = item_is_ore_or_metal or item_is_food_or_kelp,
            .smelt_duration_seconds = 10.0,
        },
        .blast_furnace_ores_and_metal_gear => .{
            .can_smelt = item_is_ore_or_metal,
            .smelt_duration_seconds = 5.0,
        },
        .smoker_food_and_kelp => .{
            .can_smelt = item_is_food_or_kelp,
            .smelt_duration_seconds = 5.0,
        },
    };
}

pub const FurnaceFuelSource = enum {
    lava_bucket_1000s,
    coal_block_800s,
    dried_kelp_block_200s,
    blaze_rod_120s,
    coal_or_charcoal_80s,
    boat_or_bamboo_mosaic_20s,
    planks_15s,
    sticks_or_saplings_5s,
    bamboo_or_scaffolding_2_5s,

    pub fn burnDurationSeconds(self: FurnaceFuelSource) f32 {
        return switch (self) {
            .lava_bucket_1000s => 1000.0,
            .coal_block_800s => 800.0,
            .dried_kelp_block_200s => 200.0,
            .blaze_rod_120s => 120.0,
            .coal_or_charcoal_80s => 80.0,
            .boat_or_bamboo_mosaic_20s => 20.0,
            .planks_15s => 15.0,
            .sticks_or_saplings_5s => 5.0,
            .bamboo_or_scaffolding_2_5s => 2.5,
        };
    }

    /// At the standard 10-second smelt rate, reports total item capacity.
    pub fn itemsSmeltedCount(self: FurnaceFuelSource) f32 {
        return self.burnDurationSeconds() / 10.0;
    }

    /// Lava buckets are consumed as fuel but leave their empty container behind.
    pub fn containerAfterBurn(self: FurnaceFuelSource) FurnaceFuelContainer {
        return switch (self) {
            .lava_bucket_1000s => .empty_bucket,
            else => .none,
        };
    }
};

pub const FurnaceFuelContainer = enum { none, empty_bucket };

/// Hopper extraction adds item XP to a retained bank; player extraction collects
/// both the stored amount and the newly extracted item's XP.
pub fn accumulateSmeltXp(stored_xp: *f32, item_xp: f32, extracted_by_hopper: bool) f32 {
    if (extracted_by_hopper) {
        stored_xp.* += item_xp;
        return 0.0;
    }

    const collected = stored_xp.* + item_xp;
    stored_xp.* = 0.0;
    return collected;
}

/// Called when the furnace is broken: stored XP is released and the bank resets.
pub fn collectFurnaceXpOnBreak(stored_xp: *f32) f32 {
    const collected = stored_xp.*;
    stored_xp.* = 0.0;
    return collected;
}

test "crafting table stair ratio and Stonecutter stair yield" {
    try std.testing.expectEqual(@as(u8, 6), crafting_table_stair_input);
    try std.testing.expectEqual(@as(u8, 4), crafting_table_stair_output);
    try std.testing.expectEqual(@as(u8, 1), stonecutterYield(.stairs));
}

test "Stonecutter slab, wall, chiseled, and copper yields" {
    try std.testing.expectEqual(@as(u8, 2), stonecutterYield(.slabs));
    try std.testing.expectEqual(@as(u8, 1), stonecutterYield(.wall));
    try std.testing.expectEqual(@as(u8, 1), stonecutterYield(.chiseled));
    try std.testing.expectEqual(@as(u8, 4), stonecutterYield(.cut_copper));
    try std.testing.expectEqual(@as(u8, 4), stonecutterYield(.copper_grate));
}

test "standard furnace accepts ores and food at ten seconds" {
    const ore = resolveFurnaceSmeltCycle(.standard_furnace, true, false);
    const food = resolveFurnaceSmeltCycle(.standard_furnace, false, true);
    try std.testing.expect(ore.can_smelt);
    try std.testing.expect(food.can_smelt);
    try std.testing.expectEqual(@as(f32, 10.0), ore.smelt_duration_seconds);
}

test "blast furnace smelts ores at five seconds" {
    const cycle = resolveFurnaceSmeltCycle(.blast_furnace_ores_and_metal_gear, true, false);
    try std.testing.expect(cycle.can_smelt);
    try std.testing.expectEqual(@as(f32, 5.0), cycle.smelt_duration_seconds);
}

test "blast furnace rejects food" {
    try std.testing.expect(!resolveFurnaceSmeltCycle(.blast_furnace_ores_and_metal_gear, false, true).can_smelt);
}

test "smoker cooks food at five seconds" {
    const cycle = resolveFurnaceSmeltCycle(.smoker_food_and_kelp, false, true);
    try std.testing.expect(cycle.can_smelt);
    try std.testing.expectEqual(@as(f32, 5.0), cycle.smelt_duration_seconds);
}

test "smoker rejects ores" {
    try std.testing.expect(!resolveFurnaceSmeltCycle(.smoker_food_and_kelp, true, false).can_smelt);
}

test "no workstation smelts unclassified items" {
    try std.testing.expect(!resolveFurnaceSmeltCycle(.standard_furnace, false, false).can_smelt);
    try std.testing.expect(!resolveFurnaceSmeltCycle(.blast_furnace_ores_and_metal_gear, false, false).can_smelt);
    try std.testing.expect(!resolveFurnaceSmeltCycle(.smoker_food_and_kelp, false, false).can_smelt);
}

test "fuel burn durations cover all listed sources" {
    try std.testing.expectEqual(@as(f32, 1000.0), FurnaceFuelSource.lava_bucket_1000s.burnDurationSeconds());
    try std.testing.expectEqual(@as(f32, 800.0), FurnaceFuelSource.coal_block_800s.burnDurationSeconds());
    try std.testing.expectEqual(@as(f32, 200.0), FurnaceFuelSource.dried_kelp_block_200s.burnDurationSeconds());
    try std.testing.expectEqual(@as(f32, 120.0), FurnaceFuelSource.blaze_rod_120s.burnDurationSeconds());
    try std.testing.expectEqual(@as(f32, 80.0), FurnaceFuelSource.coal_or_charcoal_80s.burnDurationSeconds());
    try std.testing.expectEqual(@as(f32, 20.0), FurnaceFuelSource.boat_or_bamboo_mosaic_20s.burnDurationSeconds());
    try std.testing.expectEqual(@as(f32, 15.0), FurnaceFuelSource.planks_15s.burnDurationSeconds());
    try std.testing.expectEqual(@as(f32, 5.0), FurnaceFuelSource.sticks_or_saplings_5s.burnDurationSeconds());
    try std.testing.expectEqual(@as(f32, 2.5), FurnaceFuelSource.bamboo_or_scaffolding_2_5s.burnDurationSeconds());
}

test "fuel item capacity uses standard smelt duration" {
    try std.testing.expectEqual(@as(f32, 100.0), FurnaceFuelSource.lava_bucket_1000s.itemsSmeltedCount());
    try std.testing.expectEqual(@as(f32, 8.0), FurnaceFuelSource.coal_or_charcoal_80s.itemsSmeltedCount());
    try std.testing.expectEqual(@as(f32, 0.25), FurnaceFuelSource.bamboo_or_scaffolding_2_5s.itemsSmeltedCount());
}

test "lava bucket leaves empty bucket in fuel slot" {
    try std.testing.expectEqual(FurnaceFuelContainer.empty_bucket, FurnaceFuelSource.lava_bucket_1000s.containerAfterBurn());
    try std.testing.expectEqual(FurnaceFuelContainer.none, FurnaceFuelSource.coal_block_800s.containerAfterBurn());
}

test "hopper extraction accumulates fractional furnace XP" {
    var bank: f32 = 0.0;
    try std.testing.expectEqual(@as(f32, 0.0), accumulateSmeltXp(&bank, 0.35, true));
    try std.testing.expectEqual(@as(f32, 0.35), bank);
    _ = accumulateSmeltXp(&bank, 0.2, true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), bank, 0.00001);
}

test "manual extraction collects stored XP and clears bank" {
    var bank: f32 = 0.55;
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), accumulateSmeltXp(&bank, 0.2, false), 0.00001);
    try std.testing.expectEqual(@as(f32, 0.0), bank);
}

test "breaking furnace collects banked fractional XP" {
    var bank: f32 = 0.375;
    try std.testing.expectEqual(@as(f32, 0.375), collectFurnaceXpOnBreak(&bank));
    try std.testing.expectEqual(@as(f32, 0.0), bank);
}
