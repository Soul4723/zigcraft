//! Milestone 438: Composter Biofuel & Bone Meal Pipeline
//!
//! Implements the complete Minecraft-compliant Composter workstation mechanics:
//! 1. 8-level fill states (0..8):
//!    - Level 0 = empty.
//!    - Levels 1..7 = accumulating organic compost layers.
//!    - Level 8 = fully composted (ready for bone meal harvest, visible white top layer).
//! 2. Organic compost fill probabilities across 5 tiers:
//!    - Tier 1 (30% success): seeds (wheat, pumpkin, melon, beetroot), leaves, saplings, sweet berries, glow berries, kelp.
//!    - Tier 2 (50% success): cactus, dried kelp, sugar cane, tall grass.
//!    - Tier 3 (65% success): apples, carrots, potatoes, beetroot, wheat, mushrooms, sea pickle.
//!    - Tier 4 (85% success): bread, baked potato, cookie, hay bale.
//!    - Tier 5 (100% success): cake, pumpkin pie.
//! 3. Harvest and reset:
//!    - Right-clicking (or hopper pulling) from Level 8 yields exactly 1 Bone Meal and resets fill level to 0.
//! 4. Redstone comparator signal:
//!    - Emits signal strength equal to the current fill level (0..8).
//! 5. Hopper automation rules:
//!    - Hopper above inserts valid compostable items.
//!    - Hopper below extracts bone meal only when fill level reaches 8.
//! 6. Biofuel and biomass energy calculations for circular crop/kelp fuel farming.

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Minimum composter fill level (empty).
pub const EMPTY_LEVEL: u4 = 0;

/// Maximum composter fill level (fully composted / ripe for bone meal harvest).
pub const MAX_LEVEL: u4 = 8;

/// Fill level at which composter is ready for harvesting (level 8).
pub const READY_HARVEST_LEVEL: u4 = 8;

/// Bone Meal yield per successful composter harvest.
pub const BONE_MEAL_YIELD: u8 = 1;

/// Item identifier for Bone Meal (mirrors ItemType.bone_meal = 128).
pub const BONE_MEAL_ITEM_ID: u16 = 128;

/// Composting success percentage tiers according to Minecraft mechanics.
pub const TIER_1_CHANCE_PERCENT: u8 = 30;
pub const TIER_2_CHANCE_PERCENT: u8 = 50;
pub const TIER_3_CHANCE_PERCENT: u8 = 65;
pub const TIER_4_CHANCE_PERCENT: u8 = 85;
pub const TIER_5_CHANCE_PERCENT: u8 = 100;

// ============================================================================
// Enums & Types
// ============================================================================

/// Visual and functional fill level state of a composter (0..8).
pub const ComposterLevel = enum(u4) {
    empty = 0,
    accumulating_1 = 1,
    accumulating_2 = 2,
    accumulating_3 = 3,
    accumulating_4 = 4,
    accumulating_5 = 5,
    accumulating_6 = 6,
    accumulating_7 = 7,
    ready_harvest = 8,

    pub fn toLevel(self: ComposterLevel) u4 {
        return @intFromEnum(self);
    }

    pub fn fromLevel(lvl: anytype) ComposterLevel {
        const clamped: u4 = @intCast(@min(lvl, MAX_LEVEL));
        return @enumFromInt(clamped);
    }

    pub fn isEmpty(self: ComposterLevel) bool {
        return self == .empty;
    }

    pub fn isAccumulating(self: ComposterLevel) bool {
        const v = @intFromEnum(self);
        return v >= 1 and v <= 7;
    }

    pub fn isReadyForHarvest(self: ComposterLevel) bool {
        return self == .ready_harvest;
    }

    pub fn hasVisibleWhiteTopLayer(self: ComposterLevel) bool {
        return self == .ready_harvest;
    }

    pub fn comparatorSignal(self: ComposterLevel) u4 {
        return self.toLevel();
    }
};

/// 5-tier organic composting probability classification.
pub const CompostTier = enum(u8) {
    tier_1 = 1, // 30% success
    tier_2 = 2, // 50% success
    tier_3 = 3, // 65% success
    tier_4 = 4, // 85% success
    tier_5 = 5, // 100% success

    pub fn successPercentage(self: CompostTier) u8 {
        return switch (self) {
            .tier_1 => TIER_1_CHANCE_PERCENT,
            .tier_2 => TIER_2_CHANCE_PERCENT,
            .tier_3 => TIER_3_CHANCE_PERCENT,
            .tier_4 => TIER_4_CHANCE_PERCENT,
            .tier_5 => TIER_5_CHANCE_PERCENT,
        };
    }

    pub fn successProbability(self: CompostTier) f32 {
        return switch (self) {
            .tier_1 => 0.30,
            .tier_2 => 0.50,
            .tier_3 => 0.65,
            .tier_4 => 0.85,
            .tier_5 => 1.00,
        };
    }

    /// Evaluates if a given roll (0..99 or arbitrary integer modulo 100) succeeds.
    /// Tier 5 always succeeds.
    pub fn rollsSuccess(self: CompostTier, roll: anytype) bool {
        if (self == .tier_5) return true;
        const r: u64 = @intCast(roll);
        return (r % 100) < self.successPercentage();
    }

    /// Expected number of items needed to advance 1 level on average.
    pub fn expectedItemsPerLevel(self: CompostTier) f32 {
        return 1.0 / self.successProbability();
    }

    /// Expected number of items needed to fill a composter from empty (0) to ready (8).
    pub fn expectedItemsForFullCompost(self: CompostTier) f32 {
        return 8.0 * self.expectedItemsPerLevel();
    }
};

/// Common compostable items categorized across all 5 tiers.
pub const CompostableItem = enum(u16) {
    // Tier 1 (30%): seeds, leaves, saplings, sweet berries, glow berries, kelp
    wheat_seeds = 266,
    pumpkin_seeds = 300,
    melon_seeds = 318,
    beetroot_seeds = 346,
    seeds = 1001,
    leaves = 18,
    sapling = 24,
    sweet_berries = 355,
    glow_berries = 324,
    kelp = 187,

    // Tier 2 (50%): cactus, dried kelp, sugar cane, tall grass
    cactus = 265,
    dried_kelp = 188,
    sugar_cane = 299,
    tall_grass = 31,

    // Tier 3 (65%): apples, carrots, potatoes, beetroot, wheat, mushrooms, sea pickle
    apple = 23,
    carrot = 331,
    potato = 342,
    beetroot = 345,
    wheat = 267,
    mushroom = 39,
    sea_pickle = 190,

    // Tier 4 (85%): bread, baked potato, cookie, hay bale
    bread = 268,
    baked_potato = 343,
    cookie = 354,
    hay_bale = 71,

    // Tier 5 (100%): cake, pumpkin pie
    cake = 314,
    pumpkin_pie = 304,

    pub fn tier(self: CompostableItem) CompostTier {
        return switch (self) {
            .wheat_seeds, .pumpkin_seeds, .melon_seeds, .beetroot_seeds, .seeds, .leaves, .sapling, .sweet_berries, .glow_berries, .kelp => .tier_1,
            .cactus, .dried_kelp, .sugar_cane, .tall_grass => .tier_2,
            .apple, .carrot, .potato, .beetroot, .wheat, .mushroom, .sea_pickle => .tier_3,
            .bread, .baked_potato, .cookie, .hay_bale => .tier_4,
            .cake, .pumpkin_pie => .tier_5,
        };
    }
};

/// Relative hopper position to the composter.
pub const HopperPosition = enum {
    above, // top input hopper
    below, // bottom output/extraction hopper
    side,  // side hopper (no interaction in vanilla mechanics)
};

// ============================================================================
// State & Structs
// ============================================================================

/// In-world Composter block state tracking fill levels and coordinates.
pub const ComposterState = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    level: u4 = 0, // 0..8

    pub fn init() ComposterState {
        return .{ .level = 0 };
    }

    pub fn initAt(x: i32, y: i32, z: i32) ComposterState {
        return .{ .x = x, .y = y, .z = z, .level = 0 };
    }

    pub fn initWithLevel(lvl: anytype) ComposterState {
        return .{ .level = @intCast(@min(lvl, MAX_LEVEL)) };
    }

    pub fn isEmpty(self: ComposterState) bool {
        return self.level == EMPTY_LEVEL;
    }

    pub fn isAccumulating(self: ComposterState) bool {
        return self.level >= 1 and self.level <= 7;
    }

    pub fn isFullyComposted(self: ComposterState) bool {
        return self.level == READY_HARVEST_LEVEL;
    }

    pub fn isReadyForHarvest(self: ComposterState) bool {
        return self.level == READY_HARVEST_LEVEL;
    }

    pub fn hasWhiteTopLayer(self: ComposterState) bool {
        return self.level == READY_HARVEST_LEVEL;
    }

    pub fn fillState(self: ComposterState) ComposterLevel {
        return ComposterLevel.fromLevel(self.level);
    }

    pub fn fillProgress(self: ComposterState) f32 {
        return @as(f32, @floatFromInt(self.level)) / 8.0;
    }

    pub fn comparatorSignal(self: ComposterState) u4 {
        return @min(self.level, MAX_LEVEL);
    }

    /// Surface height of compost inside the open basin (in block units 0.0..1.0).
    pub fn surfaceHeight(self: ComposterState) f32 {
        if (self.level == 0) return 0.125; // bottom basin floor
        return 0.125 + (@as(f32, @floatFromInt(self.level)) * 0.095625);
    }

    /// Visual appearance texture tag of the top layer.
    pub fn topLayerTexture(self: ComposterState) []const u8 {
        if (self.level == 0) return "empty_basin";
        if (self.level == 8) return "white_humus_ready";
        return "green_brown_compost_mulch";
    }

    /// Direct attempt to insert an item into this composter.
    pub fn insert(self: *ComposterState, item: anytype, roll: anytype) InsertResult {
        return insertItem(self, item, roll);
    }

    /// Direct attempt to harvest bone meal from this composter.
    pub fn harvest(self: *ComposterState) HarvestResult {
        return harvestComposter(self);
    }

    /// Simulates player right-click interaction.
    pub fn interact(self: *ComposterState, held_item: anytype, roll: anytype) InteractionResult {
        return rightClick(self, held_item, roll);
    }
};

/// Result of attempting to insert a compostable item into a composter.
pub const InsertResult = struct {
    accepted: bool,        // true if item was compostable and composter had space (< 8)
    level_increased: bool, // true if probability roll succeeded and level increased
    previous_level: u4,
    new_level: u4,
    tier: ?CompostTier,
};

/// Result of attempting to harvest bone meal from a composter.
pub const HarvestResult = struct {
    success: bool,
    bone_meal_count: u8, // exactly 1 on success, 0 on failure
    previous_level: u4,
    new_level: u4,       // 0 on success
};

/// Outcome of player right-click interaction.
pub const InteractionResult = union(enum) {
    harvested: HarvestResult,
    inserted: InsertResult,
    rejected,
};

/// Outcome of hopper attempting to push an item into the composter.
pub const HopperInsertOutcome = struct {
    item_pulled_from_hopper: bool,
    level_incremented: bool,
    new_composter_level: u4,
};

/// Outcome of hopper attempting to pull an item out of the composter.
pub const HopperExtractOutcome = struct {
    bone_meal_extracted: bool,
    item_count: u8,
    new_composter_level: u4,
};

/// Basic item stack representation for hopper automation simulation.
pub const ItemStack = struct {
    item_id: u16 = 0,
    name: []const u8 = "",
    count: u8 = 0,

    pub fn isEmpty(self: ItemStack) bool {
        return self.count == 0;
    }
};

/// Simulated 5-slot Hopper container.
pub const Hopper = struct {
    position: HopperPosition,
    slots: [5]?ItemStack = [_]?ItemStack{null} ** 5,

    pub fn init(pos: HopperPosition) Hopper {
        return .{ .position = pos };
    }

    pub fn totalCount(self: Hopper) u32 {
        var sum: u32 = 0;
        for (self.slots) |slot_opt| {
            if (slot_opt) |s| sum += s.count;
        }
        return sum;
    }

    pub fn findFirstNonEmpty(self: *Hopper) ?usize {
        for (self.slots, 0..) |slot_opt, i| {
            if (slot_opt) |s| {
                if (s.count > 0) return i;
            }
        }
        return null;
    }

    pub fn addItem(self: *Hopper, name: []const u8, item_id: u16, count: u8) bool {
        if (count == 0) return true;
        // Try to stack onto existing matching slot
        for (&self.slots) |*slot_opt| {
            if (slot_opt.*) |*s| {
                if (s.item_id == item_id or std.mem.eql(u8, s.name, name)) {
                    s.count += count;
                    return true;
                }
            }
        }
        // Place in first empty slot
        for (&self.slots) |*slot_opt| {
            if (slot_opt.* == null) {
                slot_opt.* = .{ .item_id = item_id, .name = name, .count = count };
                return true;
            }
        }
        return false;
    }
};

// ============================================================================
// Item Classification & Tier Lookup
// ============================================================================

/// Normalizes an item string name into lowercase with underscores for robust matching.
fn normalizeInto(name: []const u8, buf: []u8) []const u8 {
    var out_idx: usize = 0;
    for (name) |c| {
        if (out_idx >= buf.len) break;
        if (c >= 'A' and c <= 'Z') {
            buf[out_idx] = c + ('a' - 'A');
            out_idx += 1;
        } else if (c == ' ' or c == '-') {
            buf[out_idx] = '_';
            out_idx += 1;
        } else {
            buf[out_idx] = c;
            out_idx += 1;
        }
    }
    return buf[0..out_idx];
}

/// Classifies an item name string into one of the 5 organic composting tiers.
/// Returns null if the item is not compostable.
pub fn classifyItem(name: []const u8) ?CompostTier {
    var buf: [64]u8 = undefined;
    const clean = normalizeInto(name, &buf);

    // ------------------------------------------------------------------------
    // Tier 5 (100% success): cake, pumpkin pie
    // ------------------------------------------------------------------------
    if (std.mem.eql(u8, clean, "cake") or
        std.mem.eql(u8, clean, "pumpkin_pie") or
        std.mem.eql(u8, clean, "pumpkinpie"))
    {
        return .tier_5;
    }

    // ------------------------------------------------------------------------
    // Tier 4 (85% success): bread, baked potato, cookie, hay bale
    // ------------------------------------------------------------------------
    if (std.mem.eql(u8, clean, "bread") or
        std.mem.eql(u8, clean, "baked_potato") or
        std.mem.eql(u8, clean, "cookie") or
        std.mem.eql(u8, clean, "cookies") or
        std.mem.eql(u8, clean, "hay_bale") or
        std.mem.eql(u8, clean, "haybale") or
        std.mem.eql(u8, clean, "mushroom_block") or
        std.mem.eql(u8, clean, "red_mushroom_block") or
        std.mem.eql(u8, clean, "brown_mushroom_block") or
        std.mem.eql(u8, clean, "nether_wart_block") or
        std.mem.eql(u8, clean, "warped_wart_block"))
    {
        return .tier_4;
    }

    // ------------------------------------------------------------------------
    // Tier 3 (65% success): apples, carrots, potatoes, beetroot, wheat,
    // mushrooms, sea pickle (plus flowers, melon, pumpkin, moss)
    // ------------------------------------------------------------------------
    if (std.mem.eql(u8, clean, "apple") or
        std.mem.eql(u8, clean, "apples") or
        std.mem.eql(u8, clean, "carrot") or
        std.mem.eql(u8, clean, "carrots") or
        std.mem.eql(u8, clean, "potato") or
        std.mem.eql(u8, clean, "potatoes") or
        std.mem.eql(u8, clean, "beetroot") or
        std.mem.eql(u8, clean, "beetroots") or
        std.mem.eql(u8, clean, "wheat") or
        std.mem.eql(u8, clean, "mushroom") or
        std.mem.eql(u8, clean, "mushrooms") or
        std.mem.eql(u8, clean, "red_mushroom") or
        std.mem.eql(u8, clean, "brown_mushroom") or
        std.mem.eql(u8, clean, "crimson_fungus") or
        std.mem.eql(u8, clean, "warped_fungus") or
        std.mem.eql(u8, clean, "shroomlight") or
        std.mem.eql(u8, clean, "sea_pickle") or
        std.mem.eql(u8, clean, "seapickle") or
        std.mem.eql(u8, clean, "melon") or
        std.mem.eql(u8, clean, "pumpkin") or
        std.mem.eql(u8, clean, "carved_pumpkin") or
        std.mem.eql(u8, clean, "flower") or
        std.mem.eql(u8, clean, "flowers") or
        std.mem.eql(u8, clean, "dandelion") or
        std.mem.eql(u8, clean, "poppy") or
        std.mem.eql(u8, clean, "blue_orchid") or
        std.mem.eql(u8, clean, "allium") or
        std.mem.eql(u8, clean, "tulip") or
        std.mem.eql(u8, clean, "daisy") or
        std.mem.eql(u8, clean, "sunflower") or
        std.mem.eql(u8, clean, "lilac") or
        std.mem.eql(u8, clean, "rose") or
        std.mem.eql(u8, clean, "peony") or
        std.mem.eql(u8, clean, "cocoa_beans") or
        std.mem.eql(u8, clean, "moss_block") or
        std.mem.eql(u8, clean, "moss_carpet") or
        std.mem.eql(u8, clean, "open_eyeblossom") or
        std.mem.eql(u8, clean, "closed_eyeblossom") or
        std.mem.eql(u8, clean, "pink_petals") or
        std.mem.eql(u8, clean, "torchflower") or
        std.mem.eql(u8, clean, "pitcher_plant"))
    {
        return .tier_3;
    }

    // ------------------------------------------------------------------------
    // Tier 2 (50% success): cactus, dried kelp, sugar cane, tall grass
    // ------------------------------------------------------------------------
    if (std.mem.eql(u8, clean, "cactus") or
        std.mem.eql(u8, clean, "dried_kelp") or
        std.mem.eql(u8, clean, "driedkelp") or
        std.mem.eql(u8, clean, "sugar_cane") or
        std.mem.eql(u8, clean, "sugarcane") or
        std.mem.eql(u8, clean, "tall_grass") or
        std.mem.eql(u8, clean, "tallgrass") or
        std.mem.eql(u8, clean, "double_tallgrass") or
        std.mem.eql(u8, clean, "vines") or
        std.mem.eql(u8, clean, "vine") or
        std.mem.eql(u8, clean, "weeping_vines") or
        std.mem.eql(u8, clean, "twisting_vines") or
        std.mem.eql(u8, clean, "glow_lichen") or
        std.mem.eql(u8, clean, "melon_slice"))
    {
        return .tier_2;
    }

    // ------------------------------------------------------------------------
    // Tier 1 (30% success): seeds (wheat, pumpkin, melon, beetroot),
    // leaves, saplings, sweet berries, glow berries, kelp
    // ------------------------------------------------------------------------
    if (std.mem.eql(u8, clean, "seeds") or
        std.mem.eql(u8, clean, "wheat_seeds") or
        std.mem.eql(u8, clean, "pumpkin_seeds") or
        std.mem.eql(u8, clean, "melon_seeds") or
        std.mem.eql(u8, clean, "beetroot_seeds") or
        std.mem.eql(u8, clean, "torchflower_seeds") or
        std.mem.eql(u8, clean, "pitcher_pod") or
        std.mem.eql(u8, clean, "leaves") or
        std.mem.eql(u8, clean, "oak_leaves") or
        std.mem.eql(u8, clean, "birch_leaves") or
        std.mem.eql(u8, clean, "spruce_leaves") or
        std.mem.eql(u8, clean, "jungle_leaves") or
        std.mem.eql(u8, clean, "acacia_leaves") or
        std.mem.eql(u8, clean, "dark_oak_leaves") or
        std.mem.eql(u8, clean, "mangrove_leaves") or
        std.mem.eql(u8, clean, "cherry_leaves") or
        std.mem.eql(u8, clean, "pale_oak_leaves") or
        std.mem.eql(u8, clean, "azalea_leaves") or
        std.mem.eql(u8, clean, "flowering_azalea_leaves") or
        std.mem.eql(u8, clean, "sapling") or
        std.mem.eql(u8, clean, "saplings") or
        std.mem.eql(u8, clean, "oak_sapling") or
        std.mem.eql(u8, clean, "birch_sapling") or
        std.mem.eql(u8, clean, "spruce_sapling") or
        std.mem.eql(u8, clean, "jungle_sapling") or
        std.mem.eql(u8, clean, "acacia_sapling") or
        std.mem.eql(u8, clean, "dark_oak_sapling") or
        std.mem.eql(u8, clean, "cherry_sapling") or
        std.mem.eql(u8, clean, "mangrove_propagule") or
        std.mem.eql(u8, clean, "sweet_berries") or
        std.mem.eql(u8, clean, "sweetberries") or
        std.mem.eql(u8, clean, "glow_berries") or
        std.mem.eql(u8, clean, "glowberries") or
        std.mem.eql(u8, clean, "kelp") or
        std.mem.eql(u8, clean, "hanging_roots") or
        std.mem.eql(u8, clean, "small_dripleaf") or
        std.mem.eql(u8, clean, "seagrass") or
        std.mem.eql(u8, clean, "grass") or
        std.mem.eql(u8, clean, "short_grass"))
    {
        return .tier_1;
    }

    return null;
}

/// Generic function to resolve CompostTier from string literals, slices, CompostableItem, CompostTier, or enums.
pub fn getTier(item: anytype) ?CompostTier {
    const T = @TypeOf(item);
    if (T == CompostTier) {
        return item;
    } else if (T == CompostableItem) {
        return item.tier();
    } else if (@typeInfo(T) == .enum_literal or @typeInfo(T) == .@"enum") {
        return classifyItem(@tagName(item));
    } else {
        const slice: []const u8 = item;
        return classifyItem(slice);
    }
}

/// Returns true if an item is compostable in a composter.
pub fn isCompostable(item: anytype) bool {
    return getTier(item) != null;
}

// ============================================================================
// Core Composter Operations
// ============================================================================

/// Inserts a compostable item into the composter.
/// - If composter is already full/ripe (level == 8), the item is rejected.
/// - If item is not compostable, it is rejected.
/// - If accepted, a chance roll is evaluated against the item's tier:
///   - On roll success: level increments by 1 (up to 8).
///   - On roll failure: level is unchanged.
/// Always returns an InsertResult capturing the transition details.
pub fn insertItem(state: *ComposterState, item: anytype, roll: anytype) InsertResult {
    const previous = state.level;
    if (state.level >= READY_HARVEST_LEVEL) {
        return .{
            .accepted = false,
            .level_increased = false,
            .previous_level = previous,
            .new_level = previous,
            .tier = getTier(item),
        };
    }

    const tier_opt = getTier(item);
    const tier = tier_opt orelse {
        return .{
            .accepted = false,
            .level_increased = false,
            .previous_level = previous,
            .new_level = previous,
            .tier = null,
        };
    };

    const succeeded = tier.rollsSuccess(roll);
    if (succeeded) {
        state.level += 1;
        return .{
            .accepted = true,
            .level_increased = true,
            .previous_level = previous,
            .new_level = state.level,
            .tier = tier,
        };
    } else {
        return .{
            .accepted = true,
            .level_increased = false,
            .previous_level = previous,
            .new_level = previous,
            .tier = tier,
        };
    }
}

/// Extracts Bone Meal from a ripe composter (level 8).
/// Yields exactly 1 Bone Meal and resets fill level to 0.
/// If not at level 8, fails and leaves fill level unchanged.
pub fn harvestComposter(state: *ComposterState) HarvestResult {
    const previous = state.level;
    if (state.level == READY_HARVEST_LEVEL) {
        state.level = EMPTY_LEVEL;
        return .{
            .success = true,
            .bone_meal_count = BONE_MEAL_YIELD,
            .previous_level = previous,
            .new_level = EMPTY_LEVEL,
        };
    }
    return .{
        .success = false,
        .bone_meal_count = 0,
        .previous_level = previous,
        .new_level = previous,
    };
}

/// Convenience alias for harvestComposter returning ?u8 count.
pub fn harvestBoneMeal(state: *ComposterState) ?u8 {
    const res = harvestComposter(state);
    if (res.success) return res.bone_meal_count;
    return null;
}

/// Simulates right-click interaction:
/// 1. If at level 8 (ready), right-clicking always harvests 1 Bone Meal and resets level to 0.
/// 2. If below level 8, right-clicking with a compostable item attempts organic insertion.
/// 3. Otherwise rejects the interaction.
pub fn rightClick(state: *ComposterState, held_item: anytype, roll: anytype) InteractionResult {
    if (state.level == READY_HARVEST_LEVEL) {
        const h_res = harvestComposter(state);
        return .{ .harvested = h_res };
    }

    if (isCompostable(held_item)) {
        const i_res = insertItem(state, held_item, roll);
        return .{ .inserted = i_res };
    }

    return .rejected;
}

// ============================================================================
// Redstone Comparator Signal
// ============================================================================

/// Computes redstone comparator signal strength (0..8) directly equal to the fill level.
/// Accepts ComposterState, *ComposterState, *const ComposterState, ComposterLevel, or integer.
pub fn comparatorSignal(source: anytype) u4 {
    const T = @TypeOf(source);
    if (T == ComposterState or T == *const ComposterState or T == *ComposterState) {
        return @min(source.level, MAX_LEVEL);
    } else if (T == ComposterLevel) {
        return source.toLevel();
    } else {
        const val: u4 = @intCast(@min(source, MAX_LEVEL));
        return val;
    }
}

// ============================================================================
// Hopper Automation Rules
// ============================================================================

/// Checks whether a hopper can push an item into the composter.
/// Hoppers can only insert from above, only when level < 8, and only compostable items.
pub fn hopperCanInsert(state: *const ComposterState, pos: HopperPosition, item: anytype) bool {
    if (pos != .above) return false;
    if (state.level >= READY_HARVEST_LEVEL) return false;
    return isCompostable(item);
}

/// Simulates a hopper inserting an item into the composter.
/// Follows strict hopper automation rules:
/// - Only a hopper above can insert.
/// - Item must be compostable.
/// - Item is consumed from the hopper.
/// - Composter fill level increments if the chance roll succeeds.
pub fn hopperInsert(state: *ComposterState, pos: HopperPosition, item: anytype, roll: anytype) HopperInsertOutcome {
    if (!hopperCanInsert(state, pos, item)) {
        return .{
            .item_pulled_from_hopper = false,
            .level_incremented = false,
            .new_composter_level = state.level,
        };
    }

    const ins = insertItem(state, item, roll);
    return .{
        .item_pulled_from_hopper = ins.accepted,
        .level_incremented = ins.level_increased,
        .new_composter_level = state.level,
    };
}

/// Checks whether a hopper can extract an item from the composter.
/// Hoppers can only extract from below, and only when the composter reaches level 8.
pub fn hopperCanExtract(state: *const ComposterState, pos: HopperPosition) bool {
    if (pos != .below) return false;
    return state.level == READY_HARVEST_LEVEL;
}

/// Simulates a hopper below pulling bone meal out of the composter.
/// Only extracts when composter is at level 8, yielding 1 Bone Meal and resetting level to 0.
pub fn hopperExtract(state: *ComposterState, pos: HopperPosition) HopperExtractOutcome {
    if (!hopperCanExtract(state, pos)) {
        return .{
            .bone_meal_extracted = false,
            .item_count = 0,
            .new_composter_level = state.level,
        };
    }

    const h = harvestComposter(state);
    return .{
        .bone_meal_extracted = h.success,
        .item_count = h.bone_meal_count,
        .new_composter_level = state.level,
    };
}

/// Simulates a game tick step between a top hopper, the composter, and a bottom hopper.
/// Follows standard Minecraft tick ordering: states are evaluated at tick onset.
/// If the composter is at level 8 at tick start, bottom hopper extracts bone meal.
/// Top hopper only pushes if the composter had capacity at tick start.
pub fn tickHopperComposterPipeline(
    top_hopper: ?*Hopper,
    composter: *ComposterState,
    bottom_hopper: ?*Hopper,
    roll: anytype,
) struct { pushed: bool, pulled: bool } {
    var pushed = false;
    var pulled = false;

    const had_capacity_at_start = composter.level < READY_HARVEST_LEVEL;

    // 1. Bottom hopper extraction
    if (bottom_hopper) |bh| {
        if (bh.position == .below and hopperCanExtract(composter, .below)) {
            const ext = hopperExtract(composter, .below);
            if (ext.bone_meal_extracted) {
                _ = bh.addItem("bone_meal", BONE_MEAL_ITEM_ID, ext.item_count);
                pulled = true;
            }
        }
    }

    // 2. Top hopper insertion (only if composter had capacity at start of this tick)
    if (top_hopper) |th| {
        if (th.position == .above and had_capacity_at_start) {
            if (th.findFirstNonEmpty()) |slot_idx| {
                const slot = &th.slots[slot_idx].?;
                if (hopperCanInsert(composter, .above, slot.name)) {
                    const outcome = hopperInsert(composter, .above, slot.name, roll);
                    if (outcome.item_pulled_from_hopper) {
                        slot.count -= 1;
                        if (slot.count == 0) th.slots[slot_idx] = null;
                        pushed = true;
                    }
                }
            }
        }
    }

    return .{ .pushed = pushed, .pulled = pulled };
}

// ============================================================================
// Biofuel & Biomass Pipeline Calculations
// ============================================================================

pub const BiofuelPipeline = struct {
    /// Expected number of raw compostable items required to yield 1 Bone Meal from an empty composter.
    pub fn expectedItemsPerBoneMeal(tier: CompostTier) f32 {
        return tier.expectedItemsForFullCompost();
    }

    /// Biofuel thermal burn duration in furnace seconds when bone meal accelerates biomass generation:
    /// E.g. Bone meal fertilizes kelp plant -> harvested -> smelted into dried kelp -> crafted into dried kelp block.
    /// In Minecraft: 1 dried kelp block burns for 200 seconds (smelting 20 items).
    pub fn driedKelpBiofuelBurnSeconds(dried_kelp_blocks: u32) f32 {
        return @as(f32, @floatFromInt(dried_kelp_blocks)) * 200.0;
    }

    /// Charcoal biofuel burn duration in furnace seconds when bone meal accelerates tree saplings:
    /// In Minecraft: 1 charcoal burns for 80 seconds (smelting 8 items).
    pub fn treeSaplingCharcoalBurnSeconds(charcoal_count: u32) f32 {
        return @as(f32, @floatFromInt(charcoal_count)) * 80.0;
    }

    /// Computes the net biomass energy return multiplier of composting organic waste into bone meal
    /// to cultivate high-density biofuel (e.g. saplings or kelp).
    pub fn biofuelEnergyMultiplier(raw_burn_seconds: f32, output_biofuel_burn_seconds: f32) f32 {
        if (raw_burn_seconds <= 0.0) return 0.0;
        return output_biofuel_burn_seconds / raw_burn_seconds;
    }
};

// ============================================================================
// Comprehensive Unit Tests (15+ Tests)
// ============================================================================

test "1. CompostTier probability percentages and roll evaluations across all 5 tiers" {
    try std.testing.expectEqual(@as(u8, 30), CompostTier.tier_1.successPercentage());
    try std.testing.expectEqual(@as(u8, 50), CompostTier.tier_2.successPercentage());
    try std.testing.expectEqual(@as(u8, 65), CompostTier.tier_3.successPercentage());
    try std.testing.expectEqual(@as(u8, 85), CompostTier.tier_4.successPercentage());
    try std.testing.expectEqual(@as(u8, 100), CompostTier.tier_5.successPercentage());

    // Tier 1 (30%): rolls 0..29 succeed, 30..99 fail
    try std.testing.expect(CompostTier.tier_1.rollsSuccess(@as(u8, 0)));
    try std.testing.expect(CompostTier.tier_1.rollsSuccess(@as(u8, 29)));
    try std.testing.expect(!CompostTier.tier_1.rollsSuccess(@as(u8, 30)));
    try std.testing.expect(!CompostTier.tier_1.rollsSuccess(@as(u8, 99)));

    // Tier 2 (50%): rolls 0..49 succeed, 50..99 fail
    try std.testing.expect(CompostTier.tier_2.rollsSuccess(@as(u8, 0)));
    try std.testing.expect(CompostTier.tier_2.rollsSuccess(@as(u8, 49)));
    try std.testing.expect(!CompostTier.tier_2.rollsSuccess(@as(u8, 50)));

    // Tier 3 (65%): rolls 0..64 succeed, 65..99 fail
    try std.testing.expect(CompostTier.tier_3.rollsSuccess(@as(u8, 0)));
    try std.testing.expect(CompostTier.tier_3.rollsSuccess(@as(u8, 64)));
    try std.testing.expect(!CompostTier.tier_3.rollsSuccess(@as(u8, 65)));

    // Tier 4 (85%): rolls 0..84 succeed, 85..99 fail
    try std.testing.expect(CompostTier.tier_4.rollsSuccess(@as(u8, 0)));
    try std.testing.expect(CompostTier.tier_4.rollsSuccess(@as(u8, 84)));
    try std.testing.expect(!CompostTier.tier_4.rollsSuccess(@as(u8, 85)));

    // Tier 5 (100%): any roll succeeds
    try std.testing.expect(CompostTier.tier_5.rollsSuccess(@as(u8, 0)));
    try std.testing.expect(CompostTier.tier_5.rollsSuccess(@as(u8, 99)));
    try std.testing.expect(CompostTier.tier_5.rollsSuccess(@as(u8, 255)));
}

test "2. Item probability classification: Tier 1 (30% success)" {
    // Seeds (wheat, pumpkin, melon, beetroot)
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("wheat_seeds").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("pumpkin_seeds").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("melon_seeds").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("beetroot_seeds").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("seeds").?);

    // Leaves
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("leaves").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("oak_leaves").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("birch_leaves").?);

    // Saplings
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("sapling").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("oak_sapling").?);

    // Sweet berries, glow berries, kelp
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("sweet_berries").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("Sweet Berries").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("glow_berries").?);
    try std.testing.expectEqual(CompostTier.tier_1, classifyItem("kelp").?);
}

test "3. Item probability classification: Tier 2 (50% success)" {
    try std.testing.expectEqual(CompostTier.tier_2, classifyItem("cactus").?);
    try std.testing.expectEqual(CompostTier.tier_2, classifyItem("dried_kelp").?);
    try std.testing.expectEqual(CompostTier.tier_2, classifyItem("Dried Kelp").?);
    try std.testing.expectEqual(CompostTier.tier_2, classifyItem("sugar_cane").?);
    try std.testing.expectEqual(CompostTier.tier_2, classifyItem("tall_grass").?);
    try std.testing.expectEqual(CompostTier.tier_2, classifyItem("Tall Grass").?);
}

test "4. Item probability classification: Tier 3 (65% success)" {
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("apple").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("apples").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("carrot").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("carrots").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("potato").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("potatoes").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("beetroot").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("wheat").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("mushroom").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("mushrooms").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("red_mushroom").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("brown_mushroom").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("sea_pickle").?);
    try std.testing.expectEqual(CompostTier.tier_3, classifyItem("Sea Pickle").?);
}

test "5. Item probability classification: Tier 4 (85% success)" {
    try std.testing.expectEqual(CompostTier.tier_4, classifyItem("bread").?);
    try std.testing.expectEqual(CompostTier.tier_4, classifyItem("baked_potato").?);
    try std.testing.expectEqual(CompostTier.tier_4, classifyItem("Baked Potato").?);
    try std.testing.expectEqual(CompostTier.tier_4, classifyItem("cookie").?);
    try std.testing.expectEqual(CompostTier.tier_4, classifyItem("hay_bale").?);
    try std.testing.expectEqual(CompostTier.tier_4, classifyItem("Hay Bale").?);
}

test "6. Item probability classification: Tier 5 (100% success)" {
    try std.testing.expectEqual(CompostTier.tier_5, classifyItem("cake").?);
    try std.testing.expectEqual(CompostTier.tier_5, classifyItem("Cake").?);
    try std.testing.expectEqual(CompostTier.tier_5, classifyItem("pumpkin_pie").?);
    try std.testing.expectEqual(CompostTier.tier_5, classifyItem("Pumpkin Pie").?);
}

test "7. Non-compostable item rejection" {
    try std.testing.expectEqual(@as(?CompostTier, null), classifyItem("diamond"));
    try std.testing.expectEqual(@as(?CompostTier, null), classifyItem("stone"));
    try std.testing.expectEqual(@as(?CompostTier, null), classifyItem("iron_ingot"));
    try std.testing.expectEqual(@as(?CompostTier, null), classifyItem("bone"));
    try std.testing.expectEqual(@as(?CompostTier, null), classifyItem("bone_meal"));
    try std.testing.expectEqual(@as(?CompostTier, null), classifyItem("stick"));
    try std.testing.expect(!isCompostable("diamond"));
    try std.testing.expect(!isCompostable("dirt"));
    try std.testing.expect(!isCompostable("bedrock"));
}

test "8. Composter fill states and visual layer progression from 0 to 8" {
    var composter = ComposterState.init();
    try std.testing.expect(composter.isEmpty());
    try std.testing.expect(!composter.isAccumulating());
    try std.testing.expect(!composter.isReadyForHarvest());
    try std.testing.expect(!composter.hasWhiteTopLayer());
    try std.testing.expectEqual(ComposterLevel.empty, composter.fillState());
    try std.testing.expectEqualStrings("empty_basin", composter.topLayerTexture());

    // Levels 1..7: accumulating compost
    var lvl: u4 = 1;
    while (lvl <= 7) : (lvl += 1) {
        composter.level = lvl;
        try std.testing.expect(!composter.isEmpty());
        try std.testing.expect(composter.isAccumulating());
        try std.testing.expect(!composter.isReadyForHarvest());
        try std.testing.expect(!composter.hasWhiteTopLayer());
        try std.testing.expectEqualStrings("green_brown_compost_mulch", composter.topLayerTexture());
    }

    // Level 8: fully composted, ready for bone meal harvest, visible white top layer
    composter.level = 8;
    try std.testing.expect(!composter.isEmpty());
    try std.testing.expect(!composter.isAccumulating());
    try std.testing.expect(composter.isReadyForHarvest());
    try std.testing.expect(composter.isFullyComposted());
    try std.testing.expect(composter.hasWhiteTopLayer());
    try std.testing.expectEqual(ComposterLevel.ready_harvest, composter.fillState());
    try std.testing.expectEqualStrings("white_humus_ready", composter.topLayerTexture());
}

test "9. Step-by-step fill level increments from 0 to 8 via successful insertions" {
    var composter = ComposterState.init();
    try std.testing.expectEqual(@as(u4, 0), composter.level);

    // Insert 8 Tier 5 items (100% success rate)
    var step: u4 = 1;
    while (step <= 8) : (step += 1) {
        const res = insertItem(&composter, "cake", 0);
        try std.testing.expect(res.accepted);
        try std.testing.expect(res.level_increased);
        try std.testing.expectEqual(step - 1, res.previous_level);
        try std.testing.expectEqual(step, res.new_level);
        try std.testing.expectEqual(step, composter.level);
    }

    try std.testing.expectEqual(@as(u4, 8), composter.level);
    try std.testing.expect(composter.isReadyForHarvest());
}

test "10. Insert rejection when composter is fully composted at level 8" {
    var composter = ComposterState.initWithLevel(8);
    try std.testing.expect(composter.isReadyForHarvest());

    // Even 100% cake is rejected at level 8
    const res = insertItem(&composter, "cake", 0);
    try std.testing.expect(!res.accepted);
    try std.testing.expect(!res.level_increased);
    try std.testing.expectEqual(@as(u4, 8), res.new_level);
    try std.testing.expectEqual(@as(u4, 8), composter.level);
}

test "11. Failed roll does not increment level but item is consumed" {
    var composter = ComposterState.init();

    // Tier 1 (30% success): roll 50 fails
    const res = insertItem(&composter, "wheat_seeds", 50);
    try std.testing.expect(res.accepted);
    try std.testing.expect(!res.level_increased);
    try std.testing.expectEqual(@as(u4, 0), res.previous_level);
    try std.testing.expectEqual(@as(u4, 0), res.new_level);
    try std.testing.expectEqual(@as(u4, 0), composter.level);

    // Now roll 10 succeeds
    const res2 = insertItem(&composter, "wheat_seeds", 10);
    try std.testing.expect(res2.accepted);
    try std.testing.expect(res2.level_increased);
    try std.testing.expectEqual(@as(u4, 0), res2.previous_level);
    try std.testing.expectEqual(@as(u4, 1), res2.new_level);
    try std.testing.expectEqual(@as(u4, 1), composter.level);
}

test "12. Redstone comparator signal emits exact fill level 0..8" {
    var lvl: u4 = 0;
    while (true) : (lvl += 1) {
        const composter = ComposterState.initWithLevel(lvl);
        try std.testing.expectEqual(lvl, comparatorSignal(composter));
        try std.testing.expectEqual(lvl, comparatorSignal(&composter));
        try std.testing.expectEqual(lvl, composter.comparatorSignal());
        try std.testing.expectEqual(lvl, comparatorSignal(lvl));
        try std.testing.expectEqual(lvl, ComposterLevel.fromLevel(lvl).comparatorSignal());
        if (lvl == 8) break;
    }

    // Clamping beyond 8
    try std.testing.expectEqual(@as(u4, 8), comparatorSignal(@as(u8, 15)));
}

test "13. Bone meal harvest at level 8 yields 1 Bone Meal and resets level to 0" {
    var composter = ComposterState.initWithLevel(8);
    try std.testing.expect(composter.isReadyForHarvest());

    const result = harvestComposter(&composter);
    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(u8, 1), result.bone_meal_count);
    try std.testing.expectEqual(@as(u4, 8), result.previous_level);
    try std.testing.expectEqual(@as(u4, 0), result.new_level);
    try std.testing.expectEqual(@as(u4, 0), composter.level);
    try std.testing.expect(composter.isEmpty());
}

test "14. Harvest attempt on non-ready composter (levels 0..7) fails without resetting" {
    var lvl: u4 = 0;
    while (lvl <= 7) : (lvl += 1) {
        var composter = ComposterState.initWithLevel(lvl);
        const result = harvestComposter(&composter);
        try std.testing.expect(!result.success);
        try std.testing.expectEqual(@as(u8, 0), result.bone_meal_count);
        try std.testing.expectEqual(lvl, result.previous_level);
        try std.testing.expectEqual(lvl, result.new_level);
        try std.testing.expectEqual(lvl, composter.level);

        // harvestBoneMeal helper returns null
        try std.testing.expectEqual(@as(?u8, null), harvestBoneMeal(&composter));
    }
}

test "15. Right-click interaction: priority harvesting at level 8 vs feeding below level 8" {
    var composter = ComposterState.initWithLevel(8);

    // Player right-clicks holding wheat_seeds on level 8: should HARVEST bone meal!
    const res8 = rightClick(&composter, "wheat_seeds", 0);
    switch (res8) {
        .harvested => |h| {
            try std.testing.expect(h.success);
            try std.testing.expectEqual(@as(u8, 1), h.bone_meal_count);
            try std.testing.expectEqual(@as(u4, 0), composter.level);
        },
        else => return error.TestUnexpectedResult,
    }

    // Now composter is at level 0: right-clicking with wheat_seeds deposits and rolls
    const res0 = rightClick(&composter, "wheat_seeds", 10);
    switch (res0) {
        .inserted => |i| {
            try std.testing.expect(i.accepted);
            try std.testing.expect(i.level_increased);
            try std.testing.expectEqual(@as(u4, 1), composter.level);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "16. Right-click rejection with invalid or non-compostable item" {
    var composter = ComposterState.init();
    const res = rightClick(&composter, "diamond", 0);
    try std.testing.expectEqual(InteractionResult.rejected, res);
    try std.testing.expectEqual(@as(u4, 0), composter.level);
}

test "17. Hopper above automation: accepts compostables, rejects non-compostables" {
    var composter = ComposterState.init();

    // Compostable item from above: accepted and pulled
    try std.testing.expect(hopperCanInsert(&composter, .above, "apple"));
    const out_valid = hopperInsert(&composter, .above, "apple", 0);
    try std.testing.expect(out_valid.item_pulled_from_hopper);
    try std.testing.expect(out_valid.level_incremented);
    try std.testing.expectEqual(@as(u4, 1), composter.level);

    // Non-compostable item from above: rejected, not pulled
    try std.testing.expect(!hopperCanInsert(&composter, .above, "stone"));
    const out_invalid = hopperInsert(&composter, .above, "stone", 0);
    try std.testing.expect(!out_invalid.item_pulled_from_hopper);
    try std.testing.expect(!out_invalid.level_incremented);
    try std.testing.expectEqual(@as(u4, 1), composter.level);
}

test "18. Hopper above stops inserting when composter reaches level 8" {
    var composter = ComposterState.initWithLevel(8);

    try std.testing.expect(!hopperCanInsert(&composter, .above, "cake"));
    const out = hopperInsert(&composter, .above, "cake", 0);
    try std.testing.expect(!out.item_pulled_from_hopper);
    try std.testing.expect(!out.level_incremented);
    try std.testing.expectEqual(@as(u4, 8), composter.level);
}

test "19. Hopper below automation: extracts bone meal ONLY when fill level reaches 8" {
    // Levels 0..7: hopper below cannot extract
    var lvl: u4 = 0;
    while (lvl <= 7) : (lvl += 1) {
        var composter = ComposterState.initWithLevel(lvl);
        try std.testing.expect(!hopperCanExtract(&composter, .below));
        const out = hopperExtract(&composter, .below);
        try std.testing.expect(!out.bone_meal_extracted);
        try std.testing.expectEqual(@as(u8, 0), out.item_count);
        try std.testing.expectEqual(lvl, composter.level);
    }

    // Level 8: hopper below extracts 1 bone meal and resets level to 0
    var ready_composter = ComposterState.initWithLevel(8);
    try std.testing.expect(hopperCanExtract(&ready_composter, .below));
    const out_ready = hopperExtract(&ready_composter, .below);
    try std.testing.expect(out_ready.bone_meal_extracted);
    try std.testing.expectEqual(@as(u8, 1), out_ready.item_count);
    try std.testing.expectEqual(@as(u4, 0), out_ready.new_composter_level);
    try std.testing.expectEqual(@as(u4, 0), ready_composter.level);
}

test "20. Side hopper rejection (vanilla standard)" {
    var composter_mid = ComposterState.initWithLevel(4);
    try std.testing.expect(!hopperCanInsert(&composter_mid, .side, "wheat"));
    try std.testing.expect(!hopperCanExtract(&composter_mid, .side));

    var composter_full = ComposterState.initWithLevel(8);
    try std.testing.expect(!hopperCanInsert(&composter_full, .side, "cake"));
    try std.testing.expect(!hopperCanExtract(&composter_full, .side));
}

test "21. End-to-end automated pipeline: hopper feeding, filling to 8, and hopper extraction" {
    var top_hopper = Hopper.init(.above);
    var bottom_hopper = Hopper.init(.below);
    var composter = ComposterState.init();

    // Load top hopper with 16 cakes (Tier 5, 100% success)
    _ = top_hopper.addItem("cake", 314, 16);
    try std.testing.expectEqual(@as(u32, 16), top_hopper.totalCount());
    try std.testing.expectEqual(@as(u32, 0), bottom_hopper.totalCount());

    // Cycle 1: 8 pushes fill the composter from 0 to 8
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const step = tickHopperComposterPipeline(&top_hopper, &composter, &bottom_hopper, 0);
        try std.testing.expect(step.pushed);
        try std.testing.expect(!step.pulled);
    }

    try std.testing.expectEqual(@as(u4, 8), composter.level);
    try std.testing.expectEqual(@as(u4, 8), composter.comparatorSignal());
    try std.testing.expectEqual(@as(u32, 8), top_hopper.totalCount());

    // Next tick: bottom hopper extracts bone meal, resetting composter to 0
    const extract_step = tickHopperComposterPipeline(&top_hopper, &composter, &bottom_hopper, 0);
    try std.testing.expect(extract_step.pulled);
    try std.testing.expect(!extract_step.pushed); // Top hopper doesn't push in same tick it was full at start
    try std.testing.expectEqual(@as(u4, 0), composter.level);
    try std.testing.expectEqual(@as(u32, 1), bottom_hopper.totalCount());

    // Bottom hopper now holds 1 bone meal
    const slot0 = bottom_hopper.slots[0].?;
    try std.testing.expectEqual(BONE_MEAL_ITEM_ID, slot0.item_id);
    try std.testing.expectEqualStrings("bone_meal", slot0.name);
    try std.testing.expectEqual(@as(u8, 1), slot0.count);
}

test "22. Biofuel pipeline: expected items per bone meal and biomass energy calculations" {
    // Check expected item counts
    const tier1_exp = BiofuelPipeline.expectedItemsPerBoneMeal(.tier_1);
    const tier2_exp = BiofuelPipeline.expectedItemsPerBoneMeal(.tier_2);
    const tier3_exp = BiofuelPipeline.expectedItemsPerBoneMeal(.tier_3);
    const tier4_exp = BiofuelPipeline.expectedItemsPerBoneMeal(.tier_4);
    const tier5_exp = BiofuelPipeline.expectedItemsPerBoneMeal(.tier_5);

    try std.testing.expect(tier1_exp > 26.6 and tier1_exp < 26.7); // 8 / 0.3 = 26.666...
    try std.testing.expectEqual(@as(f32, 16.0), tier2_exp);        // 8 / 0.5 = 16.0
    try std.testing.expect(tier3_exp > 12.3 and tier3_exp < 12.4); // 8 / 0.65 = 12.307...
    try std.testing.expect(tier4_exp > 9.4 and tier4_exp < 9.5);   // 8 / 0.85 = 9.411...
    try std.testing.expectEqual(@as(f32, 8.0), tier5_exp);         // 8 / 1.0 = 8.0

    // Biofuel thermal burn calculations
    // 2 dried kelp blocks burn for 400 seconds (40 items smelted)
    try std.testing.expectEqual(@as(f32, 400.0), BiofuelPipeline.driedKelpBiofuelBurnSeconds(2));

    // 5 charcoal burn for 400 seconds (40 items smelted)
    try std.testing.expectEqual(@as(f32, 400.0), BiofuelPipeline.treeSaplingCharcoalBurnSeconds(5));

    // Biofuel multiplier: converting 27 saplings (5s burn each = 135s) into 1 bone meal
    // which grows an oak tree yielding 5 logs -> 5 charcoal (400s) = 400 / 135 ~ 2.96x energy gain!
    const mult = BiofuelPipeline.biofuelEnergyMultiplier(135.0, 400.0);
    try std.testing.expect(mult > 2.95 and mult < 2.97);
}

test "23. CompostableItem enum and generic getTier dispatch" {
    try std.testing.expectEqual(CompostTier.tier_1, getTier(CompostableItem.wheat_seeds).?);
    try std.testing.expectEqual(CompostTier.tier_2, getTier(CompostableItem.cactus).?);
    try std.testing.expectEqual(CompostTier.tier_3, getTier(CompostableItem.apple).?);
    try std.testing.expectEqual(CompostTier.tier_4, getTier(CompostableItem.bread).?);
    try std.testing.expectEqual(CompostTier.tier_5, getTier(CompostableItem.cake).?);

    // String dispatch
    try std.testing.expectEqual(CompostTier.tier_1, getTier("leaves").?);
    try std.testing.expectEqual(CompostTier.tier_5, getTier("pumpkin_pie").?);

    // Direct tier pass-through
    try std.testing.expectEqual(CompostTier.tier_3, getTier(CompostTier.tier_3).?);
}

test "24. ComposterState fill progress and surface height consistency" {
    var composter = ComposterState.init();
    try std.testing.expectEqual(@as(f32, 0.0), composter.fillProgress());
    try std.testing.expect(composter.surfaceHeight() > 0.12 and composter.surfaceHeight() < 0.13);

    composter.level = 4;
    try std.testing.expectEqual(@as(f32, 0.5), composter.fillProgress());

    composter.level = 8;
    try std.testing.expectEqual(@as(f32, 1.0), composter.fillProgress());
    try std.testing.expect(composter.surfaceHeight() > 0.88 and composter.surfaceHeight() < 0.90);
}
