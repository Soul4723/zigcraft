const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Duration in seconds for a full composter (level 7) to ripen into level 8 (1.0s = 20 game ticks).
pub const composter_ripen_time: f32 = 1.0;

/// Number of game ticks required for ripening (20 ticks at 20 ticks/sec = 1.0s).
pub const composter_ripen_ticks: u32 = 20;

/// Game tick duration in seconds (1/20 second = 0.05s).
pub const tick_duration: f32 = 0.05;

/// Maximum composter stage / level (level 8: ripe with Bone Meal ready).
pub const composter_max_level: u4 = 8;

/// Composter level when completely full and entering the ripening phase (level 7).
pub const composter_ripen_level: u4 = 7;

/// Composter empty level (level 0).
pub const composter_empty_level: u4 = 0;

/// Number of Bone Meal yielded when extracting from a ripe composter.
pub const bone_meal_yield: u8 = 1;

/// Maximum honey level of a beehive / bee nest (level 5: ready for harvest).
pub const max_honey_level: u8 = 5;

/// Number of honeycombs yielded when shears are used on a full hive.
pub const honeycomb_yield: u8 = 3;

/// Number of honey bottles yielded when an empty glass bottle is used on a full hive.
pub const honey_bottle_yield: u8 = 1;

/// Maximum redstone signal strength emitted by a lectern with comparator.
pub const max_lectern_signal: u4 = 15;

/// Minimum redstone signal strength emitted by a non-empty lectern.
pub const min_lectern_signal: u4 = 1;

// ============================================================================
// Composter Enums & Types
// ============================================================================

/// Composter 8-stage visual and functional state:
/// - 0: empty
/// - 1..6: filling
/// - 7: full pre-ripen (ripening timer active)
/// - 8: ripe with Bone Meal ready to harvest
pub const ComposterStage = enum(u4) {
    empty = 0,
    filling_1 = 1,
    filling_2 = 2,
    filling_3 = 3,
    filling_4 = 4,
    filling_5 = 5,
    filling_6 = 6,
    full_pre_ripen = 7,
    ripe = 8,

    pub const stage_0 = ComposterStage.empty;
    pub const stage_1 = ComposterStage.filling_1;
    pub const stage_2 = ComposterStage.filling_2;
    pub const stage_3 = ComposterStage.filling_3;
    pub const stage_4 = ComposterStage.filling_4;
    pub const stage_5 = ComposterStage.filling_5;
    pub const stage_6 = ComposterStage.filling_6;
    pub const stage_7 = ComposterStage.full_pre_ripen;
    pub const stage_8 = ComposterStage.ripe;

    pub fn toLevel(self: ComposterStage) u4 {
        return @intFromEnum(self);
    }

    pub fn fromLevel(lvl: anytype) ComposterStage {
        const clamped: u4 = @intCast(@min(lvl, 8));
        return @enumFromInt(clamped);
    }

    pub fn isEmpty(self: ComposterStage) bool {
        return self == .empty;
    }

    pub fn isFilling(self: ComposterStage) bool {
        const val = @intFromEnum(self);
        return val >= 1 and val <= 6;
    }

    pub fn isFullPreRipen(self: ComposterStage) bool {
        return self == .full_pre_ripen;
    }

    pub fn isRipe(self: ComposterStage) bool {
        return self == .ripe;
    }

    pub fn comparatorSignal(self: ComposterStage) u4 {
        return self.toLevel();
    }
};

/// Composting chance tiers according to Minecraft mechanics:
/// - tier_30 (30%): seeds, leaves, saplings
/// - tier_50 (50%): vines, cactus, sugar cane, kelp
/// - tier_65 (65%): wheat, apple, melon, pumpkin, carrot, potato, mushrooms, flowers
/// - tier_85 (85%): bread, baked potato, cookie, hay bale, mushroom block
/// - tier_100 (100%): cake, pumpkin pie
pub const CompostChanceTier = enum(u8) {
    tier_30 = 30,
    tier_50 = 50,
    tier_65 = 65,
    tier_85 = 85,
    tier_100 = 100,

    pub fn chancePercent(self: CompostChanceTier) u8 {
        return @intFromEnum(self);
    }

    pub fn rollsSuccess(self: CompostChanceTier, roll: u8) bool {
        if (self == .tier_100) return true;
        return (roll % 100) < @intFromEnum(self);
    }
};

/// Tracks the state of an in-world Composter workstation.
pub const ComposterState = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    level: u4 = 0, // 0..8
    ripen_timer: f32 = 0.0, // Countdown timer in seconds when level == 7

    pub fn stage(self: ComposterState) ComposterStage {
        return @enumFromInt(@min(self.level, 8));
    }

    pub fn isEmpty(self: ComposterState) bool {
        return self.level == 0;
    }

    pub fn isFilling(self: ComposterState) bool {
        return self.level >= 1 and self.level <= 6;
    }

    pub fn isFullPreRipen(self: ComposterState) bool {
        return self.level == 7;
    }

    pub fn isRipe(self: ComposterState) bool {
        return self.level >= 8;
    }

    pub fn canExtract(self: ComposterState) bool {
        return self.level >= 8;
    }

    pub fn comparatorSignal(self: ComposterState) u4 {
        return @min(self.level, 8);
    }

    pub fn tick(self: *ComposterState, dt: f32) bool {
        return tickComposter(self, dt);
    }

    pub fn extract(self: *ComposterState) u8 {
        return extractBoneMeal(self);
    }

    pub fn insert(self: *ComposterState, tier: CompostChanceTier, roll: u8) bool {
        return insertCompostable(self, tier, roll);
    }
};

// ============================================================================
// Composter Functions
// ============================================================================

/// Helper checking if a percentage roll succeeds for a chance tier.
pub fn rollSuccess(tier: CompostChanceTier, roll: u8) bool {
    return tier.rollsSuccess(roll);
}

/// Inserts a compostable item into the composter.
/// Increments level based on percentage roll.
/// When reaching level 7 (full pre-ripen), starts a 1.0s (20-tick) ripening timer.
/// Returns true if the composter level was incremented; false if roll failed or composter is already full/ripe.
pub fn insertCompostable(state: *ComposterState, tier: CompostChanceTier, roll: u8) bool {
    if (state.level >= 7) return false;

    if (rollSuccess(tier, roll)) {
        state.level += 1;
        if (state.level == 7) {
            state.ripen_timer = composter_ripen_time;
        }
        return true;
    }
    return false;
}

/// Ticks the composter ripening timer by dt seconds.
/// When at level 7 and the 1.0s timer elapses, transitions to level 8 (ripe).
/// Returns true if the composter transitioned from ripening (7) to ripe (8).
pub fn tickComposter(state: *ComposterState, dt: f32) bool {
    if (state.level != 7) return false;

    state.ripen_timer -= dt;
    if (state.ripen_timer <= 0.0) {
        state.level = 8;
        state.ripen_timer = 0.0;
        return true;
    }
    return false;
}

/// Ticks the composter ripening timer by a given number of game ticks (20 ticks/sec = 0.05s/tick).
pub fn tickComposterTicks(state: *ComposterState, ticks: u32) bool {
    return tickComposter(state, @as(f32, @floatFromInt(ticks)) * tick_duration);
}

/// Extracts Bone Meal from a ripe composter (level 8).
/// Yields 1 Bone Meal and resets level to 0.
/// Returns 1 on successful extraction, 0 if not ripe.
pub fn extractBoneMeal(state: *ComposterState) u8 {
    if (state.level != 8) return 0;
    state.level = 0;
    state.ripen_timer = 0.0;
    return bone_meal_yield;
}

/// Harvest alias for extractBoneMeal.
pub const harvestBoneMeal = extractBoneMeal;

/// Computes the comparator signal (0..8) for a composter.
/// Accepts ComposterState, pointer to ComposterState, ComposterStage, or integer level.
pub fn comparatorSignal(target: anytype) u4 {
    const T = @TypeOf(target);
    if (T == ComposterState or T == *const ComposterState or T == *ComposterState) {
        return @intCast(@min(target.level, 8));
    } else if (T == ComposterStage) {
        return target.toLevel();
    } else {
        return @intCast(@min(target, 8));
    }
}

/// Alias for comparatorSignal.
pub const composterComparatorSignal = comparatorSignal;

// ============================================================================
// Hopper Auto-Composting Automation
// ============================================================================

pub const HopperCompostResult = struct {
    item_consumed: bool,
    level_increased: bool,
    new_level: u4,
};

/// Simulates a hopper pushing a compostable item into the top of a composter.
/// The item is accepted and consumed if level < 7.
/// The composter level increments only if the chance roll succeeds.
pub fn hopperCompostInput(state: *ComposterState, tier: CompostChanceTier, roll: u8) HopperCompostResult {
    if (state.level >= 7) {
        return .{
            .item_consumed = false,
            .level_increased = false,
            .new_level = state.level,
        };
    }
    const increased = insertCompostable(state, tier, roll);
    return .{
        .item_consumed = true,
        .level_increased = increased,
        .new_level = state.level,
    };
}

/// Simulates a hopper pulling items out of the bottom of a composter.
/// Only extracts when composter is at level 8 (ripe), yielding 1 Bone Meal and resetting level to 0.
pub fn hopperCompostExtract(state: *ComposterState) ?u8 {
    if (state.level == 8) {
        return extractBoneMeal(state);
    }
    return null;
}

// ============================================================================
// Item to Compost Chance Tier Mapping
// ============================================================================

/// Maps an item name string to its Minecraft composting chance tier.
/// Returns null if the item is not compostable.
pub fn itemCompostTier(name: []const u8) ?CompostChanceTier {
    // Tier 100 (100%): Cake, Pumpkin Pie
    if (std.mem.eql(u8, name, "cake") or
        std.mem.eql(u8, name, "pumpkin_pie"))
    {
        return .tier_100;
    }

    // Tier 85 (85%): Bread, Baked Potato, Cookie, Hay Bale, Mushroom Blocks
    if (std.mem.eql(u8, name, "bread") or
        std.mem.eql(u8, name, "baked_potato") or
        std.mem.eql(u8, name, "cookie") or
        std.mem.eql(u8, name, "hay_bale") or
        std.mem.eql(u8, name, "mushroom_block") or
        std.mem.eql(u8, name, "red_mushroom_block") or
        std.mem.eql(u8, name, "brown_mushroom_block") or
        std.mem.eql(u8, name, "nether_wart_block") or
        std.mem.eql(u8, name, "warped_wart_block"))
    {
        return .tier_85;
    }

    // Tier 65 (65%): Wheat, Apple, Melon, Pumpkin, Carrot, Potato, Mushrooms, Flowers
    if (std.mem.eql(u8, name, "wheat") or
        std.mem.eql(u8, name, "apple") or
        std.mem.eql(u8, name, "melon") or
        std.mem.eql(u8, name, "pumpkin") or
        std.mem.eql(u8, name, "carved_pumpkin") or
        std.mem.eql(u8, name, "carrot") or
        std.mem.eql(u8, name, "potato") or
        std.mem.eql(u8, name, "mushroom") or
        std.mem.eql(u8, name, "red_mushroom") or
        std.mem.eql(u8, name, "brown_mushroom") or
        std.mem.eql(u8, name, "crimson_fungus") or
        std.mem.eql(u8, name, "warped_fungus") or
        std.mem.eql(u8, name, "flower") or
        std.mem.eql(u8, name, "dandelion") or
        std.mem.eql(u8, name, "poppy") or
        std.mem.eql(u8, name, "blue_orchid") or
        std.mem.eql(u8, name, "allium") or
        std.mem.eql(u8, name, "tulip") or
        std.mem.eql(u8, name, "daisy") or
        std.mem.eql(u8, name, "sunflower") or
        std.mem.eql(u8, name, "lilac") or
        std.mem.eql(u8, name, "rose") or
        std.mem.eql(u8, name, "peony") or
        std.mem.eql(u8, name, "open_eyeblossom") or
        std.mem.eql(u8, name, "closed_eyeblossom") or
        std.mem.eql(u8, name, "pink_petals") or
        std.mem.eql(u8, name, "torchflower") or
        std.mem.eql(u8, name, "pitcher_plant") or
        std.mem.eql(u8, name, "sweet_berries") or
        std.mem.eql(u8, name, "glow_berries") or
        std.mem.eql(u8, name, "cocoa_beans") or
        std.mem.eql(u8, name, "sea_pickle") or
        std.mem.eql(u8, name, "moss_block") or
        std.mem.eql(u8, name, "moss_carpet"))
    {
        return .tier_65;
    }

    // Tier 50 (50%): Vines, Cactus, Sugar Cane, Kelp, Melon Slice
    if (std.mem.eql(u8, name, "vines") or
        std.mem.eql(u8, name, "vine") or
        std.mem.eql(u8, name, "weeping_vines") or
        std.mem.eql(u8, name, "twisting_vines") or
        std.mem.eql(u8, name, "cactus") or
        std.mem.eql(u8, name, "sugar_cane") or
        std.mem.eql(u8, name, "kelp") or
        std.mem.eql(u8, name, "dried_kelp") or
        std.mem.eql(u8, name, "glow_lichen") or
        std.mem.eql(u8, name, "melon_slice"))
    {
        return .tier_50;
    }

    // Tier 30 (30%): Seeds, Leaves, Saplings
    if (std.mem.eql(u8, name, "seeds") or
        std.mem.eql(u8, name, "wheat_seeds") or
        std.mem.eql(u8, name, "beetroot_seeds") or
        std.mem.eql(u8, name, "melon_seeds") or
        std.mem.eql(u8, name, "pumpkin_seeds") or
        std.mem.eql(u8, name, "torchflower_seeds") or
        std.mem.eql(u8, name, "pitcher_pod") or
        std.mem.eql(u8, name, "leaves") or
        std.mem.eql(u8, name, "oak_leaves") or
        std.mem.eql(u8, name, "birch_leaves") or
        std.mem.eql(u8, name, "spruce_leaves") or
        std.mem.eql(u8, name, "jungle_leaves") or
        std.mem.eql(u8, name, "acacia_leaves") or
        std.mem.eql(u8, name, "dark_oak_leaves") or
        std.mem.eql(u8, name, "mangrove_leaves") or
        std.mem.eql(u8, name, "cherry_leaves") or
        std.mem.eql(u8, name, "sapling") or
        std.mem.eql(u8, name, "oak_sapling") or
        std.mem.eql(u8, name, "birch_sapling") or
        std.mem.eql(u8, name, "spruce_sapling") or
        std.mem.eql(u8, name, "jungle_sapling") or
        std.mem.eql(u8, name, "acacia_sapling") or
        std.mem.eql(u8, name, "dark_oak_sapling") or
        std.mem.eql(u8, name, "cherry_sapling") or
        std.mem.eql(u8, name, "grass") or
        std.mem.eql(u8, name, "short_grass") or
        std.mem.eql(u8, name, "seagrass") or
        std.mem.eql(u8, name, "hanging_roots") or
        std.mem.eql(u8, name, "small_dripleaf"))
    {
        return .tier_30;
    }

    return null;
}

// ============================================================================
// Lectern Comparator Mechanics
// ============================================================================

/// Computes the exact Minecraft Lectern redstone output signal (1..15) based on current page and total pages.
/// - 0 if total_pages == 0 or current_page == 0 (no book on lectern)
/// - 15 if total_pages == 1 (single-page book)
/// - Exact linear scaling: 1 on page 1, 15 on final page
/// - Formula: floor(((current_page - 1) * 14) / (total_pages - 1)) + 1
pub fn lecternComparatorSignal(current_page: u8, total_pages: u8) u4 {
    if (total_pages == 0 or current_page == 0) return 0;
    if (total_pages == 1) return max_lectern_signal; // Page 1 of 1 is the final page

    const clamped_page = @min(current_page, total_pages);
    const p: u32 = clamped_page - 1;
    const n: u32 = total_pages - 1;
    const signal: u32 = ((p * 14) / n) + 1;
    return @intCast(@min(signal, max_lectern_signal));
}

// ============================================================================
// Dispenser Beehive Automation
// ============================================================================

pub const BeehiveDispenserResult = struct {
    harvested: bool = false,
    honeycomb_out: u8 = 0,
    honey_bottle_out: u8 = 0,
    bees_angered: bool = false,
};

/// Automates beehive harvesting via a Dispenser.
/// A Dispenser firing Shears or Glass Bottles into a honey_level == 5 Beehive harvests:
/// - 3 Honeycombs (if shears are used)
/// - 1 Honey Bottle (if empty bottle is used)
/// CRITICALLY: Dispensers harvest WITHOUT angering the bees, even without a campfire underneath!
pub fn dispenserAutomateBeehive(
    hive_honey_level: u8,
    dispenser_holds_shears: bool,
    dispenser_holds_empty_bottle: bool,
) BeehiveDispenserResult {
    // Only harvest when honey level reaches maximum (level 5)
    if (hive_honey_level < max_honey_level) {
        return .{
            .harvested = false,
            .honeycomb_out = 0,
            .honey_bottle_out = 0,
            .bees_angered = false,
        };
    }

    if (dispenser_holds_shears) {
        return .{
            .harvested = true,
            .honeycomb_out = honeycomb_yield,
            .honey_bottle_out = 0,
            .bees_angered = false, // Dispenser NEVER angers bees
        };
    } else if (dispenser_holds_empty_bottle) {
        return .{
            .harvested = true,
            .honeycomb_out = 0,
            .honey_bottle_out = honey_bottle_yield,
            .bees_angered = false, // Dispenser NEVER angers bees
        };
    }

    return .{
        .harvested = false,
        .honeycomb_out = 0,
        .honey_bottle_out = 0,
        .bees_angered = false,
    };
}

/// Helper modeling player manual beehive harvesting to contrast with dispenser automation.
/// When a player harvests manually without a campfire underneath, the bees ARE angered!
pub fn playerHarvestBeehive(
    hive_honey_level: u8,
    has_campfire_underneath: bool,
    use_shears: bool,
    use_empty_bottle: bool,
) BeehiveDispenserResult {
    if (hive_honey_level < max_honey_level) {
        return .{
            .harvested = false,
            .honeycomb_out = 0,
            .honey_bottle_out = 0,
            .bees_angered = false,
        };
    }

    const angered = !has_campfire_underneath;

    if (use_shears) {
        return .{
            .harvested = true,
            .honeycomb_out = honeycomb_yield,
            .honey_bottle_out = 0,
            .bees_angered = angered,
        };
    } else if (use_empty_bottle) {
        return .{
            .harvested = true,
            .honeycomb_out = 0,
            .honey_bottle_out = honey_bottle_yield,
            .bees_angered = angered,
        };
    }

    return .{
        .harvested = false,
        .honeycomb_out = 0,
        .honey_bottle_out = 0,
        .bees_angered = false,
    };
}

// ============================================================================
// Unit Tests (22 Comprehensive Tests)
// ============================================================================

test "ComposterStage enum mapping, level conversions, and states" {
    try std.testing.expectEqual(@as(u4, 0), ComposterStage.empty.toLevel());
    try std.testing.expectEqual(@as(u4, 1), ComposterStage.filling_1.toLevel());
    try std.testing.expectEqual(@as(u4, 6), ComposterStage.filling_6.toLevel());
    try std.testing.expectEqual(@as(u4, 7), ComposterStage.full_pre_ripen.toLevel());
    try std.testing.expectEqual(@as(u4, 8), ComposterStage.ripe.toLevel());

    try std.testing.expectEqual(ComposterStage.empty, ComposterStage.fromLevel(0));
    try std.testing.expectEqual(ComposterStage.filling_1, ComposterStage.fromLevel(1));
    try std.testing.expectEqual(ComposterStage.full_pre_ripen, ComposterStage.fromLevel(7));
    try std.testing.expectEqual(ComposterStage.ripe, ComposterStage.fromLevel(8));
    try std.testing.expectEqual(ComposterStage.ripe, ComposterStage.fromLevel(15)); // Clamped

    try std.testing.expect(ComposterStage.empty.isEmpty());
    try std.testing.expect(!ComposterStage.filling_1.isEmpty());
    try std.testing.expect(ComposterStage.filling_1.isFilling());
    try std.testing.expect(ComposterStage.filling_6.isFilling());
    try std.testing.expect(!ComposterStage.full_pre_ripen.isFilling());
    try std.testing.expect(ComposterStage.full_pre_ripen.isFullPreRipen());
    try std.testing.expect(ComposterStage.ripe.isRipe());
}

test "CompostChanceTier 30% seeds, leaves, and saplings" {
    var state = ComposterState{};
    try std.testing.expectEqual(@as(u8, 30), CompostChanceTier.tier_30.chancePercent());

    // Roll 0..29 succeeds (< 30)
    try std.testing.expect(insertCompostable(&state, .tier_30, 0));
    try std.testing.expectEqual(@as(u4, 1), state.level);

    try std.testing.expect(insertCompostable(&state, .tier_30, 29));
    try std.testing.expectEqual(@as(u4, 2), state.level);

    // Roll 30..99 fails (>= 30)
    try std.testing.expect(!insertCompostable(&state, .tier_30, 30));
    try std.testing.expectEqual(@as(u4, 2), state.level);

    try std.testing.expect(!insertCompostable(&state, .tier_30, 99));
    try std.testing.expectEqual(@as(u4, 2), state.level);
}

test "CompostChanceTier 50% vines, cactus, sugar cane, kelp" {
    var state = ComposterState{};
    try std.testing.expectEqual(@as(u8, 50), CompostChanceTier.tier_50.chancePercent());

    // Roll 0..49 succeeds
    try std.testing.expect(insertCompostable(&state, .tier_50, 0));
    try std.testing.expectEqual(@as(u4, 1), state.level);

    try std.testing.expect(insertCompostable(&state, .tier_50, 49));
    try std.testing.expectEqual(@as(u4, 2), state.level);

    // Roll 50..99 fails
    try std.testing.expect(!insertCompostable(&state, .tier_50, 50));
    try std.testing.expectEqual(@as(u4, 2), state.level);

    try std.testing.expect(!insertCompostable(&state, .tier_50, 75));
    try std.testing.expectEqual(@as(u4, 2), state.level);
}

test "CompostChanceTier 65% wheat, apple, melon, vegetables, mushrooms" {
    var state = ComposterState{};
    try std.testing.expectEqual(@as(u8, 65), CompostChanceTier.tier_65.chancePercent());

    // Roll 0..64 succeeds
    try std.testing.expect(insertCompostable(&state, .tier_65, 0));
    try std.testing.expectEqual(@as(u4, 1), state.level);

    try std.testing.expect(insertCompostable(&state, .tier_65, 64));
    try std.testing.expectEqual(@as(u4, 2), state.level);

    // Roll 65..99 fails
    try std.testing.expect(!insertCompostable(&state, .tier_65, 65));
    try std.testing.expectEqual(@as(u4, 2), state.level);

    try std.testing.expect(!insertCompostable(&state, .tier_65, 90));
    try std.testing.expectEqual(@as(u4, 2), state.level);
}

test "CompostChanceTier 85% bread, baked potato, cookie, hay bale" {
    var state = ComposterState{};
    try std.testing.expectEqual(@as(u8, 85), CompostChanceTier.tier_85.chancePercent());

    // Roll 0..84 succeeds
    try std.testing.expect(insertCompostable(&state, .tier_85, 0));
    try std.testing.expectEqual(@as(u4, 1), state.level);

    try std.testing.expect(insertCompostable(&state, .tier_85, 84));
    try std.testing.expectEqual(@as(u4, 2), state.level);

    // Roll 85..99 fails
    try std.testing.expect(!insertCompostable(&state, .tier_85, 85));
    try std.testing.expectEqual(@as(u4, 2), state.level);

    try std.testing.expect(!insertCompostable(&state, .tier_85, 98));
    try std.testing.expectEqual(@as(u4, 2), state.level);
}

test "CompostChanceTier 100% cake and pumpkin pie always succeeds" {
    var state = ComposterState{};
    try std.testing.expectEqual(@as(u8, 100), CompostChanceTier.tier_100.chancePercent());

    // Any roll succeeds for tier 100
    try std.testing.expect(insertCompostable(&state, .tier_100, 0));
    try std.testing.expectEqual(@as(u4, 1), state.level);

    try std.testing.expect(insertCompostable(&state, .tier_100, 50));
    try std.testing.expectEqual(@as(u4, 2), state.level);

    try std.testing.expect(insertCompostable(&state, .tier_100, 99));
    try std.testing.expectEqual(@as(u4, 3), state.level);

    try std.testing.expect(insertCompostable(&state, .tier_100, 100));
    try std.testing.expectEqual(@as(u4, 4), state.level);

    try std.testing.expect(insertCompostable(&state, .tier_100, 255));
    try std.testing.expectEqual(@as(u4, 5), state.level);
}

test "insertCompostable reaching level 7 triggers 1.0s ripening timer" {
    var state = ComposterState{ .level = 6 };
    try std.testing.expectEqual(@as(f32, 0.0), state.ripen_timer);

    // Insert to reach level 7
    const success = insertCompostable(&state, .tier_100, 0);
    try std.testing.expect(success);
    try std.testing.expectEqual(@as(u4, 7), state.level);
    try std.testing.expectEqual(composter_ripen_time, state.ripen_timer); // 1.0s
    try std.testing.expect(state.isFullPreRipen());
    try std.testing.expect(!state.isRipe());
}

test "insertCompostable rejected when already at level 7 or 8" {
    var state7 = ComposterState{ .level = 7, .ripen_timer = 1.0 };
    try std.testing.expect(!insertCompostable(&state7, .tier_100, 0));
    try std.testing.expectEqual(@as(u4, 7), state7.level);

    var state8 = ComposterState{ .level = 8 };
    try std.testing.expect(!insertCompostable(&state8, .tier_100, 0));
    try std.testing.expectEqual(@as(u4, 8), state8.level);
}

test "tickComposter ripening transition from level 7 to level 8" {
    var state = ComposterState{ .level = 7, .ripen_timer = composter_ripen_time };

    // Advance 0.4s -> timer 0.6s remaining, still level 7
    try std.testing.expect(!tickComposter(&state, 0.4));
    try std.testing.expectEqual(@as(u4, 7), state.level);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), state.ripen_timer, 0.001);

    // Advance 0.5s -> timer 0.1s remaining, still level 7
    try std.testing.expect(!tickComposter(&state, 0.5));
    try std.testing.expectEqual(@as(u4, 7), state.level);

    // Advance 0.15s -> timer <= 0, transitions to level 8 (ripe)
    try std.testing.expect(tickComposter(&state, 0.15));
    try std.testing.expectEqual(@as(u4, 8), state.level);
    try std.testing.expectEqual(@as(f32, 0.0), state.ripen_timer);
    try std.testing.expect(state.isRipe());

    // Once ripe, ticking returns false
    try std.testing.expect(!tickComposter(&state, 1.0));
    try std.testing.expectEqual(@as(u4, 8), state.level);
}

test "tickComposterTicks 20-tick ripening" {
    var state = ComposterState{ .level = 7, .ripen_timer = composter_ripen_time };

    // 10 ticks (0.5s) -> still level 7
    try std.testing.expect(!tickComposterTicks(&state, 10));
    try std.testing.expectEqual(@as(u4, 7), state.level);

    // Another 10 ticks (0.5s, total 20 ticks = 1.0s) -> transitions to level 8
    try std.testing.expect(tickComposterTicks(&state, 10));
    try std.testing.expectEqual(@as(u4, 8), state.level);
    try std.testing.expect(state.isRipe());
}

test "extractBoneMeal at level 8 yields 1 Bone Meal and resets to level 0" {
    var state = ComposterState{ .level = 8 };

    const yield_count = extractBoneMeal(&state);
    try std.testing.expectEqual(@as(u8, 1), yield_count);
    try std.testing.expectEqual(@as(u4, 0), state.level);
    try std.testing.expectEqual(@as(f32, 0.0), state.ripen_timer);
    try std.testing.expect(state.isEmpty());

    // Second extract attempt yields nothing (already empty)
    try std.testing.expectEqual(@as(u8, 0), extractBoneMeal(&state));
}

test "extractBoneMeal rejected when level is below 8" {
    var lvl: u4 = 0;
    while (lvl < 8) : (lvl += 1) {
        var state = ComposterState{ .level = lvl };
        try std.testing.expectEqual(@as(u8, 0), extractBoneMeal(&state));
        try std.testing.expectEqual(lvl, state.level);
    }
}

test "comparatorSignal returns exact level 0..8 for composter" {
    // Check signals 0 through 8
    var lvl: u4 = 0;
    while (lvl <= 8) : (lvl += 1) {
        const state = ComposterState{ .level = lvl };
        try std.testing.expectEqual(lvl, comparatorSignal(state));
        try std.testing.expectEqual(lvl, comparatorSignal(&state));
        try std.testing.expectEqual(lvl, state.comparatorSignal());
        try std.testing.expectEqual(lvl, comparatorSignal(lvl));

        const stg = ComposterStage.fromLevel(lvl);
        try std.testing.expectEqual(lvl, comparatorSignal(stg));
        try std.testing.expectEqual(lvl, stg.comparatorSignal());
    }

    // Values beyond 8 are clamped to 8
    try std.testing.expectEqual(@as(u4, 8), comparatorSignal(@as(u8, 12)));
}

test "Hopper auto-composting push into top and pull from bottom" {
    var state = ComposterState{};

    // 1. Hopper pushes tier_100 item -> consumed, level increases
    const res1 = hopperCompostInput(&state, .tier_100, 0);
    try std.testing.expect(res1.item_consumed);
    try std.testing.expect(res1.level_increased);
    try std.testing.expectEqual(@as(u4, 1), res1.new_level);

    // 2. Hopper pushes tier_30 with failing roll -> item consumed, level not increased
    const res2 = hopperCompostInput(&state, .tier_30, 99);
    try std.testing.expect(res2.item_consumed);
    try std.testing.expect(!res2.level_increased);
    try std.testing.expectEqual(@as(u4, 1), res2.new_level);

    // 3. Fast-forward composter to level 6 and push one more to level 7
    state.level = 6;
    const res3 = hopperCompostInput(&state, .tier_100, 0);
    try std.testing.expect(res3.item_consumed);
    try std.testing.expect(res3.level_increased);
    try std.testing.expectEqual(@as(u4, 7), res3.new_level);

    // 4. Hopper attempts to push into level 7 (ripening) -> rejected!
    const res4 = hopperCompostInput(&state, .tier_100, 0);
    try std.testing.expect(!res4.item_consumed);
    try std.testing.expect(!res4.level_increased);
    try std.testing.expectEqual(@as(u4, 7), res4.new_level);

    // 5. Hopper attempts to extract at level 7 -> returns null (not ripe)
    try std.testing.expectEqual(@as(?u8, null), hopperCompostExtract(&state));

    // 6. Composter ripens to level 8
    _ = tickComposter(&state, 1.0);
    try std.testing.expectEqual(@as(u4, 8), state.level);

    // 7. Hopper attempts to push into level 8 -> rejected!
    const res5 = hopperCompostInput(&state, .tier_100, 0);
    try std.testing.expect(!res5.item_consumed);

    // 8. Hopper extracts from bottom at level 8 -> yields 1 Bone Meal, resets to 0
    const extracted = hopperCompostExtract(&state);
    try std.testing.expectEqual(@as(?u8, 1), extracted);
    try std.testing.expectEqual(@as(u4, 0), state.level);
}

test "lecternComparatorSignal exact linear scaling for 1..15 pages" {
    // 15-page book produces outputs 1..15 exactly on each page
    var page: u8 = 1;
    while (page <= 15) : (page += 1) {
        const expected: u4 = @intCast(page);
        try std.testing.expectEqual(expected, lecternComparatorSignal(page, 15));
    }
}

test "lecternComparatorSignal single page book outputs max 15" {
    // A single page book is already on its final page -> outputs 15
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(1, 1));
}

test "lecternComparatorSignal boundary conditions and edge cases" {
    // 2-page book: page 1 -> 1, page 2 -> 15
    try std.testing.expectEqual(@as(u4, 1), lecternComparatorSignal(1, 2));
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(2, 2));

    // 3-page book: page 1 -> 1, page 2 -> 8, page 3 -> 15
    try std.testing.expectEqual(@as(u4, 1), lecternComparatorSignal(1, 3));
    try std.testing.expectEqual(@as(u4, 8), lecternComparatorSignal(2, 3));
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(3, 3));

    // 5-page book: pages 1..5 -> 1, 4, 8, 11, 15
    try std.testing.expectEqual(@as(u4, 1), lecternComparatorSignal(1, 5));
    try std.testing.expectEqual(@as(u4, 4), lecternComparatorSignal(2, 5));
    try std.testing.expectEqual(@as(u4, 8), lecternComparatorSignal(3, 5));
    try std.testing.expectEqual(@as(u4, 11), lecternComparatorSignal(4, 5));
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(5, 5));

    // Over-page clamping (reading page past end)
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(20, 5));

    // Empty lectern / 0 pages
    try std.testing.expectEqual(@as(u4, 0), lecternComparatorSignal(0, 0));
    try std.testing.expectEqual(@as(u4, 0), lecternComparatorSignal(1, 0));
    try std.testing.expectEqual(@as(u4, 0), lecternComparatorSignal(0, 5));
}

test "dispenserAutomateBeehive shears harvest 3 honeycomb without angering bees" {
    const res = dispenserAutomateBeehive(5, true, false);
    try std.testing.expect(res.harvested);
    try std.testing.expectEqual(@as(u8, 3), res.honeycomb_out);
    try std.testing.expectEqual(@as(u8, 0), res.honey_bottle_out);
    try std.testing.expect(!res.bees_angered); // Dispenser safe harvesting!
}

test "dispenserAutomateBeehive bottle harvest 1 honey bottle without angering bees" {
    const res = dispenserAutomateBeehive(5, false, true);
    try std.testing.expect(res.harvested);
    try std.testing.expectEqual(@as(u8, 0), res.honeycomb_out);
    try std.testing.expectEqual(@as(u8, 1), res.honey_bottle_out);
    try std.testing.expect(!res.bees_angered); // Dispenser safe harvesting!
}

test "dispenserAutomateBeehive requires honey_level == 5 and suitable tool" {
    // Honey levels 0..4 cannot be harvested
    var lvl: u8 = 0;
    while (lvl < 5) : (lvl += 1) {
        const res_shears = dispenserAutomateBeehive(lvl, true, false);
        try std.testing.expect(!res_shears.harvested);
        try std.testing.expectEqual(@as(u8, 0), res_shears.honeycomb_out);

        const res_bottle = dispenserAutomateBeehive(lvl, false, true);
        try std.testing.expect(!res_bottle.harvested);
        try std.testing.expectEqual(@as(u8, 0), res_bottle.honey_bottle_out);
    }

    // Honey level 5 with no tools -> nothing harvested
    const res_empty = dispenserAutomateBeehive(5, false, false);
    try std.testing.expect(!res_empty.harvested);
    try std.testing.expectEqual(@as(u8, 0), res_empty.honeycomb_out);
    try std.testing.expectEqual(@as(u8, 0), res_empty.honey_bottle_out);
}

test "playerHarvestBeehive angers bees without campfire but safe with campfire" {
    // Player shears hive without campfire -> bees angered!
    const res_no_fire = playerHarvestBeehive(5, false, true, false);
    try std.testing.expect(res_no_fire.harvested);
    try std.testing.expectEqual(@as(u8, 3), res_no_fire.honeycomb_out);
    try std.testing.expect(res_no_fire.bees_angered);

    // Player shears hive with campfire -> calm bees
    const res_fire = playerHarvestBeehive(5, true, true, false);
    try std.testing.expect(res_fire.harvested);
    try std.testing.expectEqual(@as(u8, 3), res_fire.honeycomb_out);
    try std.testing.expect(!res_fire.bees_angered);
}

test "itemCompostTier maps items to correct CompostChanceTier" {
    // Tier 100
    try std.testing.expectEqual(CompostChanceTier.tier_100, itemCompostTier("cake").?);
    try std.testing.expectEqual(CompostChanceTier.tier_100, itemCompostTier("pumpkin_pie").?);

    // Tier 85
    try std.testing.expectEqual(CompostChanceTier.tier_85, itemCompostTier("bread").?);
    try std.testing.expectEqual(CompostChanceTier.tier_85, itemCompostTier("cookie").?);
    try std.testing.expectEqual(CompostChanceTier.tier_85, itemCompostTier("hay_bale").?);
    try std.testing.expectEqual(CompostChanceTier.tier_85, itemCompostTier("baked_potato").?);

    // Tier 65
    try std.testing.expectEqual(CompostChanceTier.tier_65, itemCompostTier("wheat").?);
    try std.testing.expectEqual(CompostChanceTier.tier_65, itemCompostTier("apple").?);
    try std.testing.expectEqual(CompostChanceTier.tier_65, itemCompostTier("carrot").?);
    try std.testing.expectEqual(CompostChanceTier.tier_65, itemCompostTier("potato").?);
    try std.testing.expectEqual(CompostChanceTier.tier_65, itemCompostTier("pumpkin").?);
    try std.testing.expectEqual(CompostChanceTier.tier_65, itemCompostTier("melon").?);

    // Tier 50
    try std.testing.expectEqual(CompostChanceTier.tier_50, itemCompostTier("vines").?);
    try std.testing.expectEqual(CompostChanceTier.tier_50, itemCompostTier("cactus").?);
    try std.testing.expectEqual(CompostChanceTier.tier_50, itemCompostTier("sugar_cane").?);
    try std.testing.expectEqual(CompostChanceTier.tier_50, itemCompostTier("kelp").?);

    // Tier 30
    try std.testing.expectEqual(CompostChanceTier.tier_30, itemCompostTier("wheat_seeds").?);
    try std.testing.expectEqual(CompostChanceTier.tier_30, itemCompostTier("leaves").?);
    try std.testing.expectEqual(CompostChanceTier.tier_30, itemCompostTier("sapling").?);

    // Uncompostable
    try std.testing.expectEqual(@as(?CompostChanceTier, null), itemCompostTier("diamond"));
    try std.testing.expectEqual(@as(?CompostChanceTier, null), itemCompostTier("stone"));
}
