const std = @import("std");

/// Content kinds stored within a cauldron basin.
pub const CauldronContent = enum {
    empty,
    water,
    lava,
    powder_snow,

    pub fn isFluid(self: CauldronContent) bool {
        return self == .water or self == .lava;
    }
};

/// Maximum fluid or snow level in a cauldron (3 levels).
pub const max_cauldron_level: u2 = 3;

/// Light level emitted by a lava cauldron.
pub const lava_light_level: u4 = 15;

/// Lava contact damage dealt to an entity stepping inside.
pub const lava_burn_damage: f32 = 4.0;

/// Default fire duration ticks applied to an entity stepping into lava (15 seconds at 20 tps).
pub const lava_fire_ticks: u32 = 300;

/// Maximum vertical distance (in blocks) from stalactite tip to cauldron basin for drip filling.
pub const max_dripstone_distance: i32 = 10;

/// State of a cauldron basin block in the world.
pub const CauldronState = struct {
    content: CauldronContent = .empty,
    /// Fluid or snow level:
    /// - 0 when empty
    /// - 1..3 for water or powder_snow
    /// - always 3 for lava
    level: u2 = 0,

    pub fn initEmpty() CauldronState {
        return .{ .content = .empty, .level = 0 };
    }

    pub fn initWater(lvl: u2) CauldronState {
        std.debug.assert(lvl >= 1 and lvl <= max_cauldron_level);
        return .{ .content = .water, .level = lvl };
    }

    pub fn initLava() CauldronState {
        return .{ .content = .lava, .level = 3 };
    }

    pub fn initPowderSnow(lvl: u2) CauldronState {
        std.debug.assert(lvl >= 1 and lvl <= max_cauldron_level);
        return .{ .content = .powder_snow, .level = lvl };
    }

    pub fn isEmpty(self: CauldronState) bool {
        return self.content == .empty or self.level == 0;
    }

    pub fn isFull(self: CauldronState) bool {
        return self.level == max_cauldron_level;
    }

    pub fn isWater(self: CauldronState) bool {
        return self.content == .water and self.level > 0;
    }

    pub fn isLava(self: CauldronState) bool {
        return self.content == .lava and self.level == 3;
    }

    pub fn isPowderSnow(self: CauldronState) bool {
        return self.content == .powder_snow and self.level > 0;
    }

    /// Evaluates redstone comparator signal strength (0..3).
    pub fn comparatorSignal(self: CauldronState) u4 {
        return switch (self.content) {
            .empty => 0,
            .water, .powder_snow => self.level,
            .lava => 3,
        };
    }

    /// Emissive light level: 15 for lava, 0 for others.
    pub fn lightLevel(self: CauldronState) u4 {
        return if (self.content == .lava) lava_light_level else 0;
    }

    /// Resets cauldron to empty level 0.
    pub fn reset(self: *CauldronState) void {
        self.content = .empty;
        self.level = 0;
    }

    /// Decrements fluid level by 1; clears to empty if level reaches 0.
    pub fn drainOneLevel(self: *CauldronState) bool {
        if (self.isEmpty()) return false;
        self.level -= 1;
        if (self.level == 0) {
            self.content = .empty;
        }
        return true;
    }
};

/// Free function for comparator signal strength (0..3).
pub fn comparatorSignal(state: CauldronState) u4 {
    return state.comparatorSignal();
}

/// Free function for cauldron light level (0 or 15).
pub fn lightLevel(state: CauldronState) u4 {
    return state.lightLevel();
}

// ============================================================================
// Bucket & Bottle Interactions
// ============================================================================

pub const BucketType = enum {
    empty,
    water,
    lava,
    powder_snow,
};

pub const BottleType = enum {
    empty, // Glass bottle
    water, // Water bottle
};

/// Handles bucket usage on a cauldron.
/// - Water / Lava / Powder Snow bucket on empty fills to level 3 (yielding empty bucket).
/// - Empty bucket on level 3 extracts the full bucket and resets to empty level 0.
/// - Returns resulting bucket in player's hand, or null if interaction is invalid.
pub fn interactBucket(state: *CauldronState, bucket: BucketType) ?BucketType {
    switch (bucket) {
        .empty => {
            if (state.level == max_cauldron_level) {
                const prev_content = state.content;
                state.reset();
                return switch (prev_content) {
                    .water => .water,
                    .lava => .lava,
                    .powder_snow => .powder_snow,
                    .empty => null,
                };
            }
            return null;
        },
        .water => {
            if (state.content == .empty) {
                state.content = .water;
                state.level = max_cauldron_level;
                return .empty;
            }
            return null;
        },
        .lava => {
            if (state.content == .empty) {
                state.content = .lava;
                state.level = max_cauldron_level;
                return .empty;
            }
            return null;
        },
        .powder_snow => {
            if (state.content == .empty) {
                state.content = .powder_snow;
                state.level = max_cauldron_level;
                return .empty;
            }
            return null;
        },
    }
}

/// Handles bottle usage on a cauldron.
/// - Glass bottle (.empty) on .water decrements level by 1 (yielding Water Bottle).
/// - Water bottle (.water) on .empty or .water (level < 3) increments level by 1 (yielding Glass Bottle).
/// - Returns resulting bottle in player's hand, or null if interaction is invalid.
pub fn interactBottle(state: *CauldronState, bottle: BottleType) ?BottleType {
    switch (bottle) {
        .empty => {
            if (state.content == .water and state.level > 0) {
                state.level -= 1;
                if (state.level == 0) {
                    state.content = .empty;
                }
                return .water;
            }
            return null;
        },
        .water => {
            if (state.content == .empty) {
                state.content = .water;
                state.level = 1;
                return .empty;
            } else if (state.content == .water and state.level < max_cauldron_level) {
                state.level += 1;
                return .empty;
            }
            return null;
        },
    }
}

// ============================================================================
// Entity Interactions (Extinguish, Lava Burn, Powder Snow)
// ============================================================================

pub const Entity = struct {
    is_burning: bool = false,
    fire_ticks: u32 = 0,
    health: f32 = 20.0,
    freeze_ticks: u32 = 0,

    pub fn extinguish(self: *Entity) void {
        self.is_burning = false;
        self.fire_ticks = 0;
    }

    pub fn ignite(self: *Entity, ticks: u32) void {
        self.is_burning = true;
        self.fire_ticks = ticks;
    }

    pub fn takeDamage(self: *Entity, damage: f32) void {
        self.health = @max(0.0, self.health - damage);
    }
};

pub const EntityInsideResult = struct {
    extinguished: bool = false,
    damage_dealt: f32 = 0.0,
    ignited: bool = false,
    cauldron_level_consumed: bool = false,
    converted_to_water: bool = false,
};

/// Handles an entity stepping inside a cauldron:
/// - Burning entity in .water (level >= 1): fire extinguished, level decrements by 1 (empty at 0).
/// - Burning entity in .powder_snow (level >= 1): fire extinguished, level decrements by 1,
///   and remaining powder snow melts into .water! (or empty if level reaches 0).
/// - Entity in .lava: takes lava burn damage and ignited.
pub fn handleEntityInside(state: *CauldronState, entity: *Entity) EntityInsideResult {
    var result = EntityInsideResult{};

    switch (state.content) {
        .empty => {},
        .water => {
            if (state.level >= 1 and (entity.is_burning or entity.fire_ticks > 0)) {
                entity.extinguish();
                result.extinguished = true;
                state.level -= 1;
                result.cauldron_level_consumed = true;
                if (state.level == 0) {
                    state.content = .empty;
                }
            }
        },
        .powder_snow => {
            if (state.level >= 1) {
                if (entity.is_burning or entity.fire_ticks > 0) {
                    entity.extinguish();
                    result.extinguished = true;
                    state.level -= 1;
                    result.cauldron_level_consumed = true;
                    if (state.level == 0) {
                        state.content = .empty;
                    } else {
                        // Powder snow melted into water
                        state.content = .water;
                        result.converted_to_water = true;
                    }
                } else {
                    entity.freeze_ticks += 1;
                }
            }
        },
        .lava => {
            entity.takeDamage(lava_burn_damage);
            entity.ignite(lava_fire_ticks);
            result.damage_dealt = lava_burn_damage;
            result.ignited = true;
        },
    }

    return result;
}

/// Standalone helper to extinguish a burning entity stepping into a cauldron.
pub fn extinguishBurningEntity(state: *CauldronState, is_burning: *bool, fire_ticks: *u32) bool {
    if (!is_burning.* and fire_ticks.* == 0) return false;
    if (state.level < 1) return false;

    if (state.content == .water) {
        is_burning.* = false;
        fire_ticks.* = 0;
        state.level -= 1;
        if (state.level == 0) state.content = .empty;
        return true;
    } else if (state.content == .powder_snow) {
        is_burning.* = false;
        fire_ticks.* = 0;
        state.level -= 1;
        if (state.level == 0) {
            state.content = .empty;
        } else {
            state.content = .water;
        }
        return true;
    }
    return false;
}

// ============================================================================
// Dripstone Stalactite & Weather Filling Mechanics
// ============================================================================

pub const DripFluid = enum {
    water,
    lava,
};

/// Checks if distance between stalactite tip and cauldron is within 10 blocks below.
pub fn isWithinDripDistance(stalactite_y: i32, cauldron_y: i32) bool {
    const diff = stalactite_y - cauldron_y;
    return diff > 0 and diff <= max_dripstone_distance;
}

/// Checks if a cauldron can accept dripstone filling of the specified fluid.
pub fn canDripstoneFill(state: CauldronState, fluid: DripFluid) bool {
    return switch (fluid) {
        .water => (state.content == .empty) or (state.content == .water and state.level < max_cauldron_level),
        .lava => state.content == .empty,
    };
}

/// Applies a single dripstone filling event to the cauldron.
pub fn applyDripstoneFill(state: *CauldronState, fluid: DripFluid) bool {
    switch (fluid) {
        .water => {
            if (state.content == .empty) {
                state.content = .water;
                state.level = 1;
                return true;
            } else if (state.content == .water and state.level < max_cauldron_level) {
                state.level += 1;
                return true;
            }
            return false;
        },
        .lava => {
            if (state.content == .empty) {
                state.content = .lava;
                state.level = max_cauldron_level;
                return true;
            }
            return false;
        },
    }
}

/// Ticks dripstone accumulation for a cauldron located below a stalactite tip.
pub fn tickDripstoneFilling(
    state: *CauldronState,
    stalactite_y: i32,
    cauldron_y: i32,
    fluid: DripFluid,
    accumulated_ticks: *u32,
    required_ticks: u32,
) bool {
    if (!isWithinDripDistance(stalactite_y, cauldron_y)) {
        accumulated_ticks.* = 0;
        return false;
    }
    if (!canDripstoneFill(state.*, fluid)) {
        accumulated_ticks.* = 0;
        return false;
    }

    accumulated_ticks.* += 1;
    if (accumulated_ticks.* >= required_ticks) {
        accumulated_ticks.* = 0;
        return applyDripstoneFill(state, fluid);
    }
    return false;
}

pub const Weather = enum {
    clear,
    rain,
    snow,
};

/// Checks if weather can fill an open-sky cauldron.
pub fn canWeatherFill(state: CauldronState, weather: Weather, open_sky: bool) bool {
    if (!open_sky) return false;
    return switch (weather) {
        .clear => false,
        .rain => (state.content == .empty) or (state.content == .water and state.level < max_cauldron_level),
        .snow => (state.content == .empty) or (state.content == .powder_snow and state.level < max_cauldron_level),
    };
}

/// Applies rain (water) or snowfall (powder snow) increment to an open-sky cauldron.
pub fn applyWeatherFill(state: *CauldronState, weather: Weather, open_sky: bool) bool {
    if (!canWeatherFill(state.*, weather, open_sky)) return false;
    switch (weather) {
        .clear => return false,
        .rain => {
            if (state.content == .empty) {
                state.content = .water;
                state.level = 1;
                return true;
            } else if (state.content == .water and state.level < max_cauldron_level) {
                state.level += 1;
                return true;
            }
            return false;
        },
        .snow => {
            if (state.content == .empty) {
                state.content = .powder_snow;
                state.level = 1;
                return true;
            } else if (state.content == .powder_snow and state.level < max_cauldron_level) {
                state.level += 1;
                return true;
            }
            return false;
        },
    }
}

/// Ticks weather accumulation for open-sky rain/snowfall filling.
pub fn tickWeatherFilling(
    state: *CauldronState,
    weather: Weather,
    open_sky: bool,
    accumulated_ticks: *u32,
    required_ticks: u32,
) bool {
    if (!canWeatherFill(state.*, weather, open_sky)) {
        accumulated_ticks.* = 0;
        return false;
    }
    accumulated_ticks.* += 1;
    if (accumulated_ticks.* >= required_ticks) {
        accumulated_ticks.* = 0;
        return applyWeatherFill(state, weather, open_sky);
    }
    return false;
}

// ============================================================================
// Washing Dyed Items Mechanics (Leather, Wolf Armor, Banner, Shulker Box)
// ============================================================================

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
};

pub const LeatherArmorSlot = enum {
    helmet,
    chestplate,
    leggings,
    boots,
};

pub const LeatherArmor = struct {
    slot: LeatherArmorSlot = .chestplate,
    color: ?u24 = null, // null = undyed natural leather

    pub fn isDyed(self: LeatherArmor) bool {
        return self.color != null;
    }

    pub fn dye(self: *LeatherArmor, rgb: u24) void {
        self.color = rgb;
    }

    pub fn undye(self: *LeatherArmor) bool {
        if (self.color == null) return false;
        self.color = null;
        return true;
    }
};

pub const WolfArmor = struct {
    color: ?DyeColor = null, // null = undyed default wolf armor

    pub fn isDyed(self: WolfArmor) bool {
        return self.color != null;
    }

    pub fn dye(self: *WolfArmor, c: DyeColor) void {
        self.color = c;
    }

    pub fn undye(self: *WolfArmor) bool {
        if (self.color == null) return false;
        self.color = null;
        return true;
    }
};

pub const max_banner_layers: usize = 6;

pub const Banner = struct {
    base_color: DyeColor = .white,
    layers: [max_banner_layers]DyeColor = [_]DyeColor{.white} ** max_banner_layers,
    layer_count: u3 = 0,

    pub fn addLayer(self: *Banner, c: DyeColor) bool {
        if (self.layer_count >= max_banner_layers) return false;
        self.layers[self.layer_count] = c;
        self.layer_count += 1;
        return true;
    }

    pub fn stripTopLayer(self: *Banner) ?DyeColor {
        if (self.layer_count == 0) return null;
        self.layer_count -= 1;
        return self.layers[self.layer_count];
    }
};

pub const ShulkerBox = struct {
    color: ?DyeColor = null, // null = undyed default purple shulker box

    pub fn isDyed(self: ShulkerBox) bool {
        return self.color != null;
    }

    pub fn dye(self: *ShulkerBox, c: DyeColor) void {
        self.color = c;
    }

    pub fn undye(self: *ShulkerBox) bool {
        if (self.color == null) return false;
        self.color = null;
        return true;
    }
};

/// Consumes 1 water level from a water-containing cauldron.
fn consumeWaterLevel(state: *CauldronState) bool {
    if (state.content != .water or state.level == 0) return false;
    state.level -= 1;
    if (state.level == 0) {
        state.content = .empty;
    }
    return true;
}

/// Washes dyed leather armor in a water cauldron, removing dye and consuming 1 water level.
pub fn washLeatherArmor(state: *CauldronState, armor: *LeatherArmor) bool {
    if (state.content != .water or state.level == 0) return false;
    if (!armor.isDyed()) return false;
    _ = armor.undye();
    return consumeWaterLevel(state);
}

/// Washes dyed wolf armor in a water cauldron, removing dye and consuming 1 water level.
pub fn washWolfArmor(state: *CauldronState, armor: *WolfArmor) bool {
    if (state.content != .water or state.level == 0) return false;
    if (!armor.isDyed()) return false;
    _ = armor.undye();
    return consumeWaterLevel(state);
}

/// Washes a patterned banner in a water cauldron, stripping the top layer and consuming 1 water level.
pub fn washBanner(state: *CauldronState, banner: *Banner) bool {
    if (state.content != .water or state.level == 0) return false;
    if (banner.layer_count == 0) return false;
    _ = banner.stripTopLayer();
    return consumeWaterLevel(state);
}

/// Washes a dyed shulker box in a water cauldron, reverting to undyed and consuming 1 water level.
pub fn washShulkerBox(state: *CauldronState, box: *ShulkerBox) bool {
    if (state.content != .water or state.level == 0) return false;
    if (!box.isDyed()) return false;
    _ = box.undye();
    return consumeWaterLevel(state);
}

pub const WashableItem = union(enum) {
    leather_armor: *LeatherArmor,
    wolf_armor: *WolfArmor,
    banner: *Banner,
    shulker_box: *ShulkerBox,
};

/// Unified wash function for any washable item in a water cauldron.
pub fn washItem(state: *CauldronState, item: WashableItem) bool {
    return switch (item) {
        .leather_armor => |a| washLeatherArmor(state, a),
        .wolf_armor => |w| washWolfArmor(state, w),
        .banner => |b| washBanner(state, b),
        .shulker_box => |s| washShulkerBox(state, s),
    };
}

// ============================================================================
// Tests
// ============================================================================

test "1: CauldronState default initialization and state invariants" {
    var state = CauldronState{};
    try std.testing.expectEqual(CauldronContent.empty, state.content);
    try std.testing.expectEqual(@as(u2, 0), state.level);
    try std.testing.expect(state.isEmpty());
    try std.testing.expect(!state.isFull());
    try std.testing.expect(!state.isWater());
    try std.testing.expect(!state.isLava());
    try std.testing.expect(!state.isPowderSnow());

    const water_cauldron = CauldronState.initWater(2);
    try std.testing.expectEqual(CauldronContent.water, water_cauldron.content);
    try std.testing.expectEqual(@as(u2, 2), water_cauldron.level);
    try std.testing.expect(water_cauldron.isWater());

    const lava_cauldron = CauldronState.initLava();
    try std.testing.expectEqual(CauldronContent.lava, lava_cauldron.content);
    try std.testing.expectEqual(@as(u2, 3), lava_cauldron.level);
    try std.testing.expect(lava_cauldron.isLava());
    try std.testing.expect(lava_cauldron.isFull());

    const snow_cauldron = CauldronState.initPowderSnow(1);
    try std.testing.expectEqual(CauldronContent.powder_snow, snow_cauldron.content);
    try std.testing.expectEqual(@as(u2, 1), snow_cauldron.level);
    try std.testing.expect(snow_cauldron.isPowderSnow());
}

test "2: Water bucket fills empty cauldron to level 3" {
    var state = CauldronState.initEmpty();
    const result = interactBucket(&state, .water);
    try std.testing.expectEqual(@as(?BucketType, .empty), result);
    try std.testing.expectEqual(CauldronContent.water, state.content);
    try std.testing.expectEqual(@as(u2, 3), state.level);
    try std.testing.expect(state.isFull());

    // Trying to use another water bucket on a full water cauldron fails
    const fail_result = interactBucket(&state, .water);
    try std.testing.expectEqual(@as(?BucketType, null), fail_result);
    try std.testing.expectEqual(@as(u2, 3), state.level);
}

test "3: Empty bucket extracts full level 3 water, lava, and powder_snow" {
    // Water
    var water_state = CauldronState.initWater(3);
    const water_res = interactBucket(&water_state, .empty);
    try std.testing.expectEqual(@as(?BucketType, .water), water_res);
    try std.testing.expect(water_state.isEmpty());
    try std.testing.expectEqual(@as(u2, 0), water_state.level);

    // Lava
    var lava_state = CauldronState.initLava();
    const lava_res = interactBucket(&lava_state, .empty);
    try std.testing.expectEqual(@as(?BucketType, .lava), lava_res);
    try std.testing.expect(lava_state.isEmpty());
    try std.testing.expectEqual(@as(u2, 0), lava_state.level);

    // Powder Snow
    var snow_state = CauldronState.initPowderSnow(3);
    const snow_res = interactBucket(&snow_state, .powder_snow);
    try std.testing.expectEqual(@as(?BucketType, null), snow_res); // Cannot add to full
    const scoop_res = interactBucket(&snow_state, .empty);
    try std.testing.expectEqual(@as(?BucketType, .powder_snow), scoop_res);
    try std.testing.expect(snow_state.isEmpty());
    try std.testing.expectEqual(@as(u2, 0), snow_state.level);
}

test "4: Empty bucket fails on partial cauldron and empty cauldron" {
    var partial_state = CauldronState.initWater(1);
    try std.testing.expectEqual(@as(?BucketType, null), interactBucket(&partial_state, .empty));
    try std.testing.expectEqual(@as(u2, 1), partial_state.level);

    partial_state.level = 2;
    try std.testing.expectEqual(@as(?BucketType, null), interactBucket(&partial_state, .empty));
    try std.testing.expectEqual(@as(u2, 2), partial_state.level);

    var empty_state = CauldronState.initEmpty();
    try std.testing.expectEqual(@as(?BucketType, null), interactBucket(&empty_state, .empty));
}

test "5: Lava bucket and powder snow bucket deposit into empty cauldron" {
    var state1 = CauldronState.initEmpty();
    const res_lava = interactBucket(&state1, .lava);
    try std.testing.expectEqual(@as(?BucketType, .empty), res_lava);
    try std.testing.expectEqual(CauldronContent.lava, state1.content);
    try std.testing.expectEqual(@as(u2, 3), state1.level);

    var state2 = CauldronState.initEmpty();
    const res_snow = interactBucket(&state2, .powder_snow);
    try std.testing.expectEqual(@as(?BucketType, .empty), res_snow);
    try std.testing.expectEqual(CauldronContent.powder_snow, state2.content);
    try std.testing.expectEqual(@as(u2, 3), state2.level);

    // Cannot deposit lava into already filled cauldron
    try std.testing.expectEqual(@as(?BucketType, null), interactBucket(&state1, .lava));
    // Cannot deposit water into lava cauldron
    try std.testing.expectEqual(@as(?BucketType, null), interactBucket(&state1, .water));
}

test "6: Glass bottle scooping decrements water level and empties at level 0" {
    var state = CauldronState.initWater(3);

    // 1st scoop
    const b1 = interactBottle(&state, .empty);
    try std.testing.expectEqual(@as(?BottleType, .water), b1);
    try std.testing.expectEqual(CauldronContent.water, state.content);
    try std.testing.expectEqual(@as(u2, 2), state.level);

    // 2nd scoop
    const b2 = interactBottle(&state, .empty);
    try std.testing.expectEqual(@as(?BottleType, .water), b2);
    try std.testing.expectEqual(CauldronContent.water, state.content);
    try std.testing.expectEqual(@as(u2, 1), state.level);

    // 3rd scoop: level becomes 0, content becomes .empty
    const b3 = interactBottle(&state, .empty);
    try std.testing.expectEqual(@as(?BottleType, .water), b3);
    try std.testing.expectEqual(CauldronContent.empty, state.content);
    try std.testing.expectEqual(@as(u2, 0), state.level);
    try std.testing.expect(state.isEmpty());

    // 4th scoop on empty fails
    const b4 = interactBottle(&state, .empty);
    try std.testing.expectEqual(@as(?BottleType, null), b4);
}

test "7: Water bottle increments water level on empty or water cauldron < 3" {
    var state = CauldronState.initEmpty();

    // Fill empty cauldron with water bottle -> level 1
    const res1 = interactBottle(&state, .water);
    try std.testing.expectEqual(@as(?BottleType, .empty), res1);
    try std.testing.expectEqual(CauldronContent.water, state.content);
    try std.testing.expectEqual(@as(u2, 1), state.level);

    // Increment to level 2
    const res2 = interactBottle(&state, .water);
    try std.testing.expectEqual(@as(?BottleType, .empty), res2);
    try std.testing.expectEqual(@as(u2, 2), state.level);

    // Increment to level 3
    const res3 = interactBottle(&state, .water);
    try std.testing.expectEqual(@as(?BottleType, .empty), res3);
    try std.testing.expectEqual(@as(u2, 3), state.level);
    try std.testing.expect(state.isFull());

    // Fails on full cauldron
    const res4 = interactBottle(&state, .water);
    try std.testing.expectEqual(@as(?BottleType, null), res4);
    try std.testing.expectEqual(@as(u2, 3), state.level);
}

test "8: Comparator signal outputs exact levels for all cauldron types" {
    try std.testing.expectEqual(@as(u4, 0), comparatorSignal(CauldronState.initEmpty()));

    try std.testing.expectEqual(@as(u4, 1), comparatorSignal(CauldronState.initWater(1)));
    try std.testing.expectEqual(@as(u4, 2), comparatorSignal(CauldronState.initWater(2)));
    try std.testing.expectEqual(@as(u4, 3), comparatorSignal(CauldronState.initWater(3)));

    try std.testing.expectEqual(@as(u4, 1), comparatorSignal(CauldronState.initPowderSnow(1)));
    try std.testing.expectEqual(@as(u4, 2), comparatorSignal(CauldronState.initPowderSnow(2)));
    try std.testing.expectEqual(@as(u4, 3), comparatorSignal(CauldronState.initPowderSnow(3)));

    try std.testing.expectEqual(@as(u4, 3), comparatorSignal(CauldronState.initLava()));
}

test "9: Light level emission: lava emits 15, others emit 0" {
    try std.testing.expectEqual(@as(u4, 0), lightLevel(CauldronState.initEmpty()));
    try std.testing.expectEqual(@as(u4, 0), lightLevel(CauldronState.initWater(3)));
    try std.testing.expectEqual(@as(u4, 0), lightLevel(CauldronState.initPowderSnow(3)));
    try std.testing.expectEqual(@as(u4, 15), lightLevel(CauldronState.initLava()));
    try std.testing.expectEqual(@as(u4, 15), CauldronState.initLava().lightLevel());
}

test "10: Burning entity stepping into water cauldron extinguishes fire and consumes 1 level" {
    var state = CauldronState.initWater(3);
    var entity = Entity{ .is_burning = true, .fire_ticks = 100, .health = 20.0 };

    const result = handleEntityInside(&state, &entity);
    try std.testing.expect(result.extinguished);
    try std.testing.expect(result.cauldron_level_consumed);
    try std.testing.expect(!entity.is_burning);
    try std.testing.expectEqual(@as(u32, 0), entity.fire_ticks);
    try std.testing.expectEqual(@as(u2, 2), state.level);

    // Non-burning entity stepping into water cauldron does not consume water
    const non_burning_res = handleEntityInside(&state, &entity);
    try std.testing.expect(!non_burning_res.extinguished);
    try std.testing.expect(!non_burning_res.cauldron_level_consumed);
    try std.testing.expectEqual(@as(u2, 2), state.level);
}

test "11: Burning entity stepping into powder snow cauldron extinguishes fire and converts to water" {
    var state = CauldronState.initPowderSnow(3);
    var entity = Entity{ .is_burning = true, .fire_ticks = 160 };

    const result = handleEntityInside(&state, &entity);
    try std.testing.expect(result.extinguished);
    try std.testing.expect(result.cauldron_level_consumed);
    try std.testing.expect(result.converted_to_water);
    try std.testing.expectEqual(CauldronContent.water, state.content);
    try std.testing.expectEqual(@as(u2, 2), state.level);
    try std.testing.expect(!entity.is_burning);

    // Extinguishing at powder snow level 1 resets to empty
    var state_lvl1 = CauldronState.initPowderSnow(1);
    entity.ignite(80);
    const res1 = handleEntityInside(&state_lvl1, &entity);
    try std.testing.expect(res1.extinguished);
    try std.testing.expect(!res1.converted_to_water);
    try std.testing.expect(state_lvl1.isEmpty());
    try std.testing.expectEqual(CauldronContent.empty, state_lvl1.content);
    try std.testing.expectEqual(@as(u2, 0), state_lvl1.level);
}

test "12: Entity stepping into lava cauldron takes burn damage and is ignited" {
    var state = CauldronState.initLava();
    var entity = Entity{ .health = 20.0, .is_burning = false };

    const result = handleEntityInside(&state, &entity);
    try std.testing.expectEqual(lava_burn_damage, result.damage_dealt);
    try std.testing.expect(result.ignited);
    try std.testing.expectEqual(@as(f32, 16.0), entity.health);
    try std.testing.expect(entity.is_burning);
    try std.testing.expectEqual(lava_fire_ticks, entity.fire_ticks);
    // Lava cauldron remains full
    try std.testing.expectEqual(CauldronContent.lava, state.content);
    try std.testing.expectEqual(@as(u2, 3), state.level);
}

test "13: Dripstone stalactite fills water cauldron within 10 blocks over drip ticks" {
    var state = CauldronState.initEmpty();
    const stalactite_y: i32 = 70;
    const cauldron_y: i32 = 64; // Distance = 6 blocks (<= 10)

    try std.testing.expect(isWithinDripDistance(stalactite_y, cauldron_y));
    try std.testing.expect(canDripstoneFill(state, .water));

    var ticks: u32 = 0;
    const required_ticks: u32 = 5;

    // Tick 1 to 4 should not complete
    for (0..4) |_| {
        try std.testing.expect(!tickDripstoneFilling(&state, stalactite_y, cauldron_y, .water, &ticks, required_ticks));
    }
    try std.testing.expectEqual(@as(u32, 4), ticks);

    // 5th tick completes and fills to level 1
    try std.testing.expect(tickDripstoneFilling(&state, stalactite_y, cauldron_y, .water, &ticks, required_ticks));
    try std.testing.expectEqual(CauldronContent.water, state.content);
    try std.testing.expectEqual(@as(u2, 1), state.level);
    try std.testing.expectEqual(@as(u32, 0), ticks);

    // Repeat to level 2 and 3
    for (0..5) |_| {
        _ = tickDripstoneFilling(&state, stalactite_y, cauldron_y, .water, &ticks, required_ticks);
    }
    try std.testing.expectEqual(@as(u2, 2), state.level);

    for (0..5) |_| {
        _ = tickDripstoneFilling(&state, stalactite_y, cauldron_y, .water, &ticks, required_ticks);
    }
    try std.testing.expectEqual(@as(u2, 3), state.level);

    // Once full, cannot fill further
    try std.testing.expect(!canDripstoneFill(state, .water));
    try std.testing.expect(!tickDripstoneFilling(&state, stalactite_y, cauldron_y, .water, &ticks, required_ticks));
}

test "14: Dripstone stalactite lava filling fills empty cauldron to level 3" {
    var state = CauldronState.initEmpty();
    const stalactite_y: i32 = 80;
    const cauldron_y: i32 = 75; // Distance = 5 blocks

    try std.testing.expect(canDripstoneFill(state, .lava));

    var ticks: u32 = 0;
    const required_ticks: u32 = 3;

    try std.testing.expect(!tickDripstoneFilling(&state, stalactite_y, cauldron_y, .lava, &ticks, required_ticks));
    try std.testing.expect(!tickDripstoneFilling(&state, stalactite_y, cauldron_y, .lava, &ticks, required_ticks));
    try std.testing.expect(tickDripstoneFilling(&state, stalactite_y, cauldron_y, .lava, &ticks, required_ticks));

    try std.testing.expectEqual(CauldronContent.lava, state.content);
    try std.testing.expectEqual(@as(u2, 3), state.level);

    // Cannot drip lava into an already full lava cauldron or water cauldron
    try std.testing.expect(!canDripstoneFill(state, .lava));
    const water_state = CauldronState.initWater(1);
    try std.testing.expect(!canDripstoneFill(water_state, .lava));
}

test "15: Dripstone filling distance limits and rejection outside 10 blocks" {
    try std.testing.expect(isWithinDripDistance(70, 60)); // Exactly 10 blocks -> valid
    try std.testing.expect(!isWithinDripDistance(70, 59)); // 11 blocks -> too far
    try std.testing.expect(!isWithinDripDistance(60, 70)); // Stalactite below cauldron -> invalid
    try std.testing.expect(!isWithinDripDistance(60, 60)); // Same level -> invalid

    var state = CauldronState.initEmpty();
    var ticks: u32 = 0;
    try std.testing.expect(!tickDripstoneFilling(&state, 70, 59, .water, &ticks, 5));
    try std.testing.expectEqual(@as(u32, 0), ticks);
}

test "16: Weather rain slowly fills open-sky water cauldron" {
    var state = CauldronState.initEmpty();

    // Covered cauldron does not fill
    try std.testing.expect(!canWeatherFill(state, .rain, false));
    try std.testing.expect(!applyWeatherFill(&state, .rain, false));

    // Open sky cauldron fills
    try std.testing.expect(canWeatherFill(state, .rain, true));
    try std.testing.expect(applyWeatherFill(&state, .rain, true));
    try std.testing.expectEqual(CauldronContent.water, state.content);
    try std.testing.expectEqual(@as(u2, 1), state.level);

    // Weather ticking
    var ticks: u32 = 0;
    const req: u32 = 4;
    for (0..3) |_| {
        try std.testing.expect(!tickWeatherFilling(&state, .rain, true, &ticks, req));
    }
    try std.testing.expect(tickWeatherFilling(&state, .rain, true, &ticks, req));
    try std.testing.expectEqual(@as(u2, 2), state.level);
}

test "17: Weather snowfall slowly fills open-sky powder snow cauldron" {
    var state = CauldronState.initEmpty();

    try std.testing.expect(canWeatherFill(state, .snow, true));
    try std.testing.expect(applyWeatherFill(&state, .snow, true));
    try std.testing.expectEqual(CauldronContent.powder_snow, state.content);
    try std.testing.expectEqual(@as(u2, 1), state.level);

    try std.testing.expect(applyWeatherFill(&state, .snow, true));
    try std.testing.expectEqual(@as(u2, 2), state.level);

    try std.testing.expect(applyWeatherFill(&state, .snow, true));
    try std.testing.expectEqual(@as(u2, 3), state.level);

    // Full powder snow cauldron will not overfill
    try std.testing.expect(!canWeatherFill(state, .snow, true));
    try std.testing.expect(!applyWeatherFill(&state, .snow, true));
}

test "18: Washing dyed leather armor strips color and consumes 1 water level" {
    var state = CauldronState.initWater(2);
    var armor = LeatherArmor{ .slot = .chestplate };
    armor.dye(0xFF0000); // Red
    try std.testing.expect(armor.isDyed());

    try std.testing.expect(washLeatherArmor(&state, &armor));
    try std.testing.expect(!armor.isDyed());
    try std.testing.expectEqual(@as(?u24, null), armor.color);
    try std.testing.expectEqual(@as(u2, 1), state.level);

    // Washing already undyed armor fails and preserves water
    try std.testing.expect(!washLeatherArmor(&state, &armor));
    try std.testing.expectEqual(@as(u2, 1), state.level);
}

test "19: Washing dyed wolf armor removes dye and consumes 1 water level" {
    var state = CauldronState.initWater(1);
    var wolf_armor = WolfArmor{};
    wolf_armor.dye(.cyan);
    try std.testing.expect(wolf_armor.isDyed());

    try std.testing.expect(washWolfArmor(&state, &wolf_armor));
    try std.testing.expect(!wolf_armor.isDyed());
    try std.testing.expectEqual(@as(?DyeColor, null), wolf_armor.color);
    // Cauldron emptied from level 1 -> 0
    try std.testing.expect(state.isEmpty());
    try std.testing.expectEqual(CauldronContent.empty, state.content);
    try std.testing.expectEqual(@as(u2, 0), state.level);

    // Washing with empty cauldron fails
    wolf_armor.dye(.orange);
    try std.testing.expect(!washWolfArmor(&state, &wolf_armor));
    try std.testing.expect(wolf_armor.isDyed());
}

test "20: Washing banner strips top layer and consumes 1 water level" {
    var state = CauldronState.initWater(3);
    var banner = Banner{ .base_color = .white };
    try std.testing.expect(banner.addLayer(.red));
    try std.testing.expect(banner.addLayer(.blue));
    try std.testing.expect(banner.addLayer(.yellow));
    try std.testing.expectEqual(@as(u3, 3), banner.layer_count);

    // 1st wash removes top layer (yellow)
    try std.testing.expect(washBanner(&state, &banner));
    try std.testing.expectEqual(@as(u3, 2), banner.layer_count);
    try std.testing.expectEqual(@as(u2, 2), state.level);

    // 2nd wash removes blue
    try std.testing.expect(washBanner(&state, &banner));
    try std.testing.expectEqual(@as(u3, 1), banner.layer_count);
    try std.testing.expectEqual(@as(u2, 1), state.level);

    // 3rd wash removes red
    try std.testing.expect(washBanner(&state, &banner));
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);
    try std.testing.expect(state.isEmpty());

    // 4th wash on blank banner fails
    try std.testing.expect(!washBanner(&state, &banner));
}

test "21: Washing dyed shulker box reverts to undyed and consumes 1 water level" {
    var state = CauldronState.initWater(3);
    var box = ShulkerBox{};
    box.dye(.purple);
    try std.testing.expect(box.isDyed());

    try std.testing.expect(washShulkerBox(&state, &box));
    try std.testing.expect(!box.isDyed());
    try std.testing.expectEqual(@as(?DyeColor, null), box.color);
    try std.testing.expectEqual(@as(u2, 2), state.level);

    // Undyed shulker box cannot be washed
    try std.testing.expect(!washShulkerBox(&state, &box));
    try std.testing.expectEqual(@as(u2, 2), state.level);
}

test "22: Unified washItem interface and non-water cauldron rejection" {
    var lava_state = CauldronState.initLava();
    var box = ShulkerBox{};
    box.dye(.green);

    // Cannot wash items in lava or powder snow cauldron
    try std.testing.expect(!washItem(&lava_state, .{ .shulker_box = &box }));
    try std.testing.expect(box.isDyed());

    var snow_state = CauldronState.initPowderSnow(3);
    try std.testing.expect(!washItem(&snow_state, .{ .shulker_box = &box }));
    try std.testing.expect(box.isDyed());

    // In water cauldron, washItem succeeds
    var water_state = CauldronState.initWater(1);
    try std.testing.expect(washItem(&water_state, .{ .shulker_box = &box }));
    try std.testing.expect(!box.isDyed());
    try std.testing.expect(water_state.isEmpty());
}

