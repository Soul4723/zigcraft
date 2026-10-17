const std = @import("std");

/// Wood types with a boat recipe, plus the bamboo raft variant.
pub const WatercraftVariant = enum {
    oak_boat,
    spruce_boat,
    birch_boat,
    jungle_boat,
    acacia_boat,
    dark_oak_boat,
    mangrove_boat,
    cherry_boat,
    pale_oak_boat,
    bamboo_raft,

    pub fn isRaft(self: WatercraftVariant) bool {
        return self == .bamboo_raft;
    }

    pub fn recipeMaterialName(self: WatercraftVariant) []const u8 {
        return if (self.isRaft()) "bamboo" else "planks";
    }
};

pub const boat_recipe_materials: u8 = 5;
pub const boat_recipe_yield: u8 = 1;

/// Returns the number of boats/rafts made by the shaped recipe.
pub fn craftWatercraft(variant: WatercraftVariant, materials: u16) u16 {
    _ = variant; // all variants use the same five-material recipe
    return (materials / boat_recipe_materials) * boat_recipe_yield;
}

/// A chest boat retains its wood/raft variant and has a 27-slot container.
pub const ChestBoat = struct {
    pub const inventory_slots: u8 = 27;
    variant: WatercraftVariant,

    pub fn init(variant: WatercraftVariant) ChestBoat {
        return .{ .variant = variant };
    }

    pub fn maxPassengers(self: ChestBoat) u2 {
        _ = self;
        return PassengerSeating.maxPassengers(true);
    }
};

/// One boat plus one chest makes one chest boat.
pub fn craftChestBoat(boats: u16, chests: u16) u16 {
    return @min(boats, chests);
}

pub const PassengerSeating = struct {
    /// Regular boats and rafts have a driver and rear passenger. A chest takes
    /// the rear seat, leaving only the driver position available.
    pub fn maxPassengers(has_chest: bool) u2 {
        return if (has_chest) 1 else 2;
    }
};

pub fn maxPassengers(has_chest: bool) u2 {
    return PassengerSeating.maxPassengers(has_chest);
}

pub const mob_boarding_hitbox_limit: f32 = 1.375;

/// Narrow mobs board an empty seat on collision. Bosses and the Warden are
/// excluded even if a custom hitbox happens to be narrow enough.
pub fn canMobBoardBoat(hitbox_width: f32, is_boss_or_warden: bool) bool {
    return hitbox_width >= 0.0 and hitbox_width < mob_boarding_hitbox_limit and !is_boss_or_warden;
}

/// Boat passengers take no fall damage when their boat lands on solid ground.
pub fn computeRiderFallDamageInBoat(fall_distance: f32) f32 {
    _ = fall_distance;
    return 0.0;
}

pub const bubble_column_rocking_ticks: u16 = 60;
pub const bubble_column_rocking_seconds: f32 = 3.0;

pub const BubbleColumnType = enum {
    none,
    magma,
    soul_sand,
};

pub const BubbleColumnBoatState = struct {
    rocking_ticks: u16 = 0,
    submerged: bool = false,
    riders_ejected: bool = false,

    pub fn init() BubbleColumnBoatState {
        return .{};
    }
};

pub const BubbleColumnBoatTick = struct {
    rocking: bool,
    sinking: bool,
    eject_riders: bool,
};

/// Advances a boat by one game tick in a bubble column. Magma and soul-sand
/// columns rock it for exactly 60 ticks, then submerge and eject passengers.
pub fn resolveBubbleColumnBoatTick(state: *BubbleColumnBoatState, column: BubbleColumnType) BubbleColumnBoatTick {
    if (column == .none or state.submerged) {
        return .{ .rocking = false, .sinking = state.submerged, .eject_riders = state.riders_ejected };
    }

    state.rocking_ticks += 1;
    if (state.rocking_ticks >= bubble_column_rocking_ticks) {
        state.rocking_ticks = bubble_column_rocking_ticks;
        state.submerged = true;
        state.riders_ejected = true;
        return .{ .rocking = false, .sinking = true, .eject_riders = true };
    }
    return .{ .rocking = true, .sinking = false, .eject_riders = false };
}

pub fn canRowSubmergedBoat() bool {
    return false;
}

test "all watercraft variants are represented" {
    const variants = [_]WatercraftVariant{ .oak_boat, .spruce_boat, .birch_boat, .jungle_boat, .acacia_boat, .dark_oak_boat, .mangrove_boat, .cherry_boat, .pale_oak_boat, .bamboo_raft };
    try std.testing.expectEqual(@as(usize, 10), variants.len);
    try std.testing.expect(variants[9].isRaft());
    try std.testing.expectEqualStrings("planks", variants[0].recipeMaterialName());
    try std.testing.expectEqualStrings("bamboo", variants[9].recipeMaterialName());
}

test "five materials craft one watercraft" {
    try std.testing.expectEqual(@as(u16, 1), craftWatercraft(.oak_boat, 5));
    try std.testing.expectEqual(@as(u16, 2), craftWatercraft(.bamboo_raft, 10));
    try std.testing.expectEqual(@as(u16, 0), craftWatercraft(.spruce_boat, 4));
}

test "crafting preserves remainder as incomplete batches" {
    try std.testing.expectEqual(@as(u16, 2), craftWatercraft(.cherry_boat, 14));
    try std.testing.expectEqual(@as(u16, 0), craftWatercraft(.pale_oak_boat, 0));
}

test "chest boat recipe consumes one boat and chest per result" {
    try std.testing.expectEqual(@as(u16, 1), craftChestBoat(1, 1));
    try std.testing.expectEqual(@as(u16, 3), craftChestBoat(5, 3));
    try std.testing.expectEqual(@as(u16, 0), craftChestBoat(0, 4));
}

test "chest boat has twenty seven slots" {
    const boat = ChestBoat.init(.bamboo_raft);
    try std.testing.expectEqual(@as(u8, 27), ChestBoat.inventory_slots);
    try std.testing.expectEqual(WatercraftVariant.bamboo_raft, boat.variant);
    try std.testing.expectEqual(@as(u2, 1), boat.maxPassengers());
}

test "regular boat seats two passengers" {
    try std.testing.expectEqual(@as(u2, 2), PassengerSeating.maxPassengers(false));
    try std.testing.expectEqual(@as(u2, 2), maxPassengers(false));
}

test "chest boat leaves only driver seat" {
    try std.testing.expectEqual(@as(u2, 1), PassengerSeating.maxPassengers(true));
    try std.testing.expectEqual(@as(u2, 1), maxPassengers(true));
}

test "mob boarding uses strict hitbox threshold" {
    try std.testing.expect(canMobBoardBoat(1.0, false));
    try std.testing.expect(canMobBoardBoat(1.3749, false));
    try std.testing.expect(!canMobBoardBoat(1.375, false));
    try std.testing.expect(!canMobBoardBoat(1.4, false));
}

test "bosses and wardens cannot board" {
    try std.testing.expect(!canMobBoardBoat(1.0, true));
    try std.testing.expect(!canMobBoardBoat(1.374, true));
}

test "negative hitboxes cannot board" {
    try std.testing.expect(!canMobBoardBoat(-0.1, false));
}

test "boat fall clutch negates damage at every height" {
    try std.testing.expectEqual(@as(f32, 0.0), computeRiderFallDamageInBoat(0.0));
    try std.testing.expectEqual(@as(f32, 0.0), computeRiderFallDamageInBoat(1000.0));
    try std.testing.expectEqual(@as(f32, 0.0), computeRiderFallDamageInBoat(-4.0));
}

test "magma column rocks for the first fifty nine ticks" {
    var state = BubbleColumnBoatState.init();
    var tick: BubbleColumnBoatTick = undefined;
    var i: u16 = 0;
    while (i < 59) : (i += 1) {
        tick = resolveBubbleColumnBoatTick(&state, .magma);
        try std.testing.expect(tick.rocking);
        try std.testing.expect(!tick.sinking);
    }
    try std.testing.expectEqual(@as(u16, 59), state.rocking_ticks);
    try std.testing.expect(!state.submerged);
}

test "soul sand column sinks and ejects on sixtieth tick" {
    var state = BubbleColumnBoatState.init();
    var i: u16 = 0;
    while (i < 59) : (i += 1) {
        _ = resolveBubbleColumnBoatTick(&state, .soul_sand);
    }
    const result = resolveBubbleColumnBoatTick(&state, .soul_sand);
    try std.testing.expect(!result.rocking);
    try std.testing.expect(result.sinking);
    try std.testing.expect(result.eject_riders);
    try std.testing.expect(state.submerged);
    try std.testing.expectEqual(@as(u16, 60), state.rocking_ticks);
}

test "boats do not row while submerged" {
    try std.testing.expect(!canRowSubmergedBoat());
}

test "outside a bubble column state does not advance" {
    var state = BubbleColumnBoatState.init();
    const result = resolveBubbleColumnBoatTick(&state, .none);
    try std.testing.expect(!result.rocking);
    try std.testing.expect(!result.sinking);
    try std.testing.expectEqual(@as(u16, 0), state.rocking_ticks);
}

test "submerged boats remain sunk and keep riders ejected" {
    var state = BubbleColumnBoatState.init();
    state.submerged = true;
    state.riders_ejected = true;
    state.rocking_ticks = bubble_column_rocking_ticks;
    const result = resolveBubbleColumnBoatTick(&state, .magma);
    try std.testing.expect(!result.rocking);
    try std.testing.expect(result.sinking);
    try std.testing.expect(result.eject_riders);
}
