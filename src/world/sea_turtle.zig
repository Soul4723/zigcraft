const std = @import("std");

/// Number of eggs represented by one turtle-egg block.
pub const TurtleEggClutch = struct {
    egg_count: u3 = 1,
    crack_stage: u2 = 0,

    pub fn init(egg_count: u3) TurtleEggClutch {
        return .{ .egg_count = @max(1, @min(egg_count, 4)) };
    }

    /// Turtle eggs hatch on sand and red sand, but not on other blocks.
    pub fn canHatchOnBlock(is_sand: bool) bool {
        return is_sand;
    }
};

/// Module-level form for world/block registries that do not retain a clutch.
pub fn canHatchOnBlock(is_sand: bool) bool {
    return TurtleEggClutch.canHatchOnBlock(is_sand);
}

pub const TrampleResult = struct { trampled: bool, remaining_eggs: u3 };

/// A non-sneaking entity landing or walking on a clutch damages one egg.
/// Feather Falling mitigates ordinary impact damage, but does not protect eggs.
pub fn tryTrampleTurtleEgg(
    clutch: *TurtleEggClutch,
    entity_fell_or_walked: bool,
    is_sneaking: bool,
    has_feather_falling: bool,
) TrampleResult {
    _ = has_feather_falling;
    if (!entity_fell_or_walked or is_sneaking or clutch.egg_count == 0)
        return .{ .trampled = false, .remaining_eggs = clutch.egg_count };

    if (clutch.crack_stage < 2) {
        clutch.crack_stage += 1;
    } else {
        clutch.egg_count -= 1;
        clutch.crack_stage = 0;
    }
    return .{ .trampled = true, .remaining_eggs = clutch.egg_count };
}

pub const HatchResult = struct { cracked_further: bool, hatched_babies: u3 };

/// Each call represents a random tick: probability is 1/5 at late night and
/// 1/250 otherwise. The u16 roll uses modulo to retain those exact odds.
pub fn tickEggClutchHatch(
    clutch: *TurtleEggClutch,
    is_late_night_21600_to_22550: bool,
    on_sand: bool,
    roll: u16,
) HatchResult {
    if (!on_sand or clutch.egg_count == 0) return .{ .cracked_further = false, .hatched_babies = 0 };
    const divisor: u16 = if (is_late_night_21600_to_22550) 5 else 250;
    if (roll % divisor != 0) return .{ .cracked_further = false, .hatched_babies = 0 };

    if (clutch.crack_stage < 2) {
        clutch.crack_stage += 1;
        return .{ .cracked_further = true, .hatched_babies = 0 };
    }
    const babies = clutch.egg_count;
    clutch.egg_count = 0;
    clutch.crack_stage = 0;
    return .{ .cracked_further = false, .hatched_babies = babies };
}

pub const SeaTurtleState = struct {
    home_beach_pos: [3]i32,
    is_carrying_eggs: bool = false,
    is_baby: bool = false,
    growth_timer: f32 = 0,

    pub fn init(birth_beach_pos: [3]i32, is_baby: bool) SeaTurtleState {
        return .{ .home_beach_pos = birth_beach_pos, .is_baby = is_baby };
    }

    /// Egg-carrying turtles navigate to the exact beach position imprinted at birth.
    pub fn homeBeachTarget(self: SeaTurtleState) ?[3]i32 {
        if (!self.is_carrying_eggs) return null;
        return self.home_beach_pos;
    }
};

pub const BABY_GROWTH_SECONDS: f32 = 1200.0;
/// Feeding seagrass removes ten percent of the normal maturation time.
pub const SEAGRASS_GROWTH_BONUS_SECONDS: f32 = BABY_GROWTH_SECONDS * 0.1;

pub const GrowthResult = struct {
    matured_to_adult: bool = false,
    dropped_turtle_scute: u8 = 0,
    matured: bool = false,
    scutes_dropped: u8 = 0,
};

pub fn tickBabyTurtleGrowth(state: *SeaTurtleState, dt: f32, fed_seagrass: bool) GrowthResult {
    if (!state.is_baby or dt <= 0) return .{};
    state.growth_timer += dt;
    if (fed_seagrass) state.growth_timer += SEAGRASS_GROWTH_BONUS_SECONDS;
    if (state.growth_timer < BABY_GROWTH_SECONDS)
        return .{};
    state.is_baby = false;
    return .{
        .matured_to_adult = true,
        .dropped_turtle_scute = 1,
        .matured = true,
        .scutes_dropped = 1,
    };
}

test "clutch placement clamps to one through four eggs" {
    try std.testing.expectEqual(@as(u3, 1), TurtleEggClutch.init(0).egg_count);
    try std.testing.expectEqual(@as(u3, 1), TurtleEggClutch.init(1).egg_count);
    try std.testing.expectEqual(@as(u3, 2), TurtleEggClutch.init(2).egg_count);
    try std.testing.expectEqual(@as(u3, 3), TurtleEggClutch.init(3).egg_count);
    try std.testing.expectEqual(@as(u3, 4), TurtleEggClutch.init(4).egg_count);
    try std.testing.expectEqual(@as(u3, 4), TurtleEggClutch.init(7).egg_count);
}

test "clutch crack stage begins undamaged" {
    const clutch = TurtleEggClutch.init(4);
    try std.testing.expectEqual(@as(u2, 0), clutch.crack_stage);
}

test "eggs hatch on sand including red sand" {
    try std.testing.expect(TurtleEggClutch.canHatchOnBlock(true));
}

test "eggs do not hatch on non-sand" {
    try std.testing.expect(!TurtleEggClutch.canHatchOnBlock(false));
}

test "trampling advances cracks before breaking an egg" {
    var clutch = TurtleEggClutch.init(2);
    try std.testing.expect((tryTrampleTurtleEgg(&clutch, true, false, false)).trampled);
    try std.testing.expectEqual(@as(u2, 1), clutch.crack_stage);
    _ = tryTrampleTurtleEgg(&clutch, true, false, false);
    try std.testing.expectEqual(@as(u2, 2), clutch.crack_stage);
    const result = tryTrampleTurtleEgg(&clutch, true, false, false);
    try std.testing.expectEqual(@as(u3, 1), result.remaining_eggs);
    try std.testing.expectEqual(@as(u2, 0), clutch.crack_stage);
}

test "sneaking grants trample immunity" {
    var clutch = TurtleEggClutch.init(2);
    const result = tryTrampleTurtleEgg(&clutch, true, true, false);
    try std.testing.expect(!result.trampled);
    try std.testing.expectEqual(@as(u3, 2), clutch.egg_count);
}

test "walking or falling is required to trample" {
    var clutch = TurtleEggClutch.init(1);
    const result = tryTrampleTurtleEgg(&clutch, false, false, false);
    try std.testing.expect(!result.trampled);
}

test "feather falling does not grant egg trampling immunity" {
    var clutch = TurtleEggClutch.init(1);
    const result = tryTrampleTurtleEgg(&clutch, true, false, true);
    try std.testing.expect(result.trampled);
}

test "each trample breaks only one egg" {
    var clutch = TurtleEggClutch.init(4);
    var i: usize = 0;
    while (i < 3) : (i += 1) _ = tryTrampleTurtleEgg(&clutch, true, false, false);
    try std.testing.expectEqual(@as(u3, 3), clutch.egg_count);
}

test "late-night hatch success is fifty times as likely by roll threshold" {
    try std.testing.expectEqual(@as(u16, 50), 250 / 5);
    var late = TurtleEggClutch.init(1);
    var normal = TurtleEggClutch.init(1);
    try std.testing.expect(tickEggClutchHatch(&late, true, true, 5).cracked_further);
    try std.testing.expect(!tickEggClutchHatch(&normal, false, true, 5).cracked_further);
    try std.testing.expect(tickEggClutchHatch(&normal, false, true, 250).cracked_further);
}

test "hatching does not progress off sand" {
    var clutch = TurtleEggClutch.init(2);
    const result = tickEggClutchHatch(&clutch, true, false, 0);
    try std.testing.expectEqual(@as(u2, 0), clutch.crack_stage);
    try std.testing.expectEqual(@as(u3, 0), result.hatched_babies);
}

test "fully cracked clutch hatches all babies" {
    var clutch = TurtleEggClutch{ .egg_count = 3, .crack_stage = 2 };
    const result = tickEggClutchHatch(&clutch, true, true, 0);
    try std.testing.expectEqual(@as(u3, 3), result.hatched_babies);
    try std.testing.expectEqual(@as(u3, 0), clutch.egg_count);
}

test "hatch cracks first and second stages before hatching" {
    var clutch = TurtleEggClutch.init(1);
    try std.testing.expect(tickEggClutchHatch(&clutch, true, true, 0).cracked_further);
    try std.testing.expect(tickEggClutchHatch(&clutch, true, true, 0).cracked_further);
    try std.testing.expectEqual(@as(u3, 1), tickEggClutchHatch(&clutch, true, true, 0).hatched_babies);
}

test "egg-carrying turtle targets its imprinted birth beach" {
    var turtle = SeaTurtleState.init(.{ 128, 64, -35 }, false);
    turtle.is_carrying_eggs = true;
    try std.testing.expectEqual([3]i32{ 128, 64, -35 }, turtle.homeBeachTarget().?);
}

test "non-pregnant turtle has no return target" {
    const turtle = SeaTurtleState.init(.{ 4, 70, 9 }, false);
    try std.testing.expect(turtle.homeBeachTarget() == null);
}

test "baby turtle grows over time and seagrass boosts growth" {
    var turtle = SeaTurtleState.init(.{ 0, 60, 0 }, true);
    _ = tickBabyTurtleGrowth(&turtle, 1000, false);
    const fed = tickBabyTurtleGrowth(&turtle, 80, true);
    try std.testing.expect(fed.matured_to_adult);
}

test "baby turtle drops one scute on maturation" {
    var turtle = SeaTurtleState.init(.{ 0, 60, 0 }, true);
    const result = tickBabyTurtleGrowth(&turtle, BABY_GROWTH_SECONDS, false);
    try std.testing.expect(result.matured_to_adult);
    try std.testing.expectEqual(@as(u8, 1), result.dropped_turtle_scute);
    try std.testing.expect(!turtle.is_baby);
}

test "adult turtles do not grow or molt again" {
    var turtle = SeaTurtleState.init(.{ 0, 60, 0 }, false);
    const result = tickBabyTurtleGrowth(&turtle, 5000, true);
    try std.testing.expect(!result.matured_to_adult);
    try std.testing.expectEqual(@as(u8, 0), result.dropped_turtle_scute);
}

// ============================================================================
// Merged Turtle Scute, Helmet Craft, and Water Breathing Rules (from turtle_scute_helmet.zig)
// ============================================================================

/// Stable domain IDs used by the turtle lifecycle and recipe helpers.
/// The repository's inventory enum already assigns numeric ID 333 to
/// night_vision_potion, so the legacy scute ID is represented separately here.
pub const ItemType = enum(u16) {
    seagrass = 445,
    turtle_scute = 333,
    turtle_helmet = 169,
    turtle_egg = 444,
    none = 0,
};

pub const StatusEffect = enum { water_breathing };

pub const TURTLE_MAX_HEALTH: f32 = 30.0;
pub const BABY_SCALE: f32 = 0.25;
pub const EGG_DIG_TICKS: u32 = 200;
pub const BABY_GROWTH_TICKS: u32 = 24_000;
pub const EGG_MIN_HATCH_TICKS: u32 = 48_000;
pub const EGG_MAX_HATCH_TICKS: u32 = 60_000;
pub const WATER_BREATHING_TICKS: u16 = 200;
pub const TURTLE_HELMET_DURABILITY: u16 = 275;
pub const TURTLE_HELMET_DEFENSE: u8 = 2;

pub const TurtleEntity = struct {
    position: [3]f32 = .{ 0, 0, 0 },
    health: f32 = TURTLE_MAX_HEALTH,
    home_beach: [2]i32 = .{ 0, 0 },
    is_baby: bool = false,
    in_love: bool = false,
    pregnant: bool = false,
    digging_ticks: u32 = 0,
    growth_ticks: u32 = 0,

    pub fn scale(self: TurtleEntity) f32 {
        return if (self.is_baby) BABY_SCALE else 1.0;
    }

    pub fn feedSeagrass(self: *TurtleEntity) bool {
        if (self.is_baby or self.pregnant) return false;
        self.in_love = true;
        return true;
    }

    pub fn breedWith(self: *TurtleEntity, other: *TurtleEntity) bool {
        if (self.is_baby or other.is_baby or !self.in_love or !other.in_love or self.pregnant or other.pregnant) return false;
        self.pregnant = true;
        self.in_love = false;
        other.in_love = false;
        return true;
    }

    pub fn homeBeachTarget(self: TurtleEntity) ?[2]i32 {
        return if (self.pregnant) self.home_beach else null;
    }

    /// Returns the clutch size once the turtle has completed 200 digging ticks.
    pub fn tickEggLaying(self: *TurtleEntity, on_sand: bool, clutch_size: u3) u3 {
        if (!self.pregnant or !on_sand) {
            self.digging_ticks = 0;
            return 0;
        }
        if (self.digging_ticks < EGG_DIG_TICKS) self.digging_ticks += 1;
        if (self.digging_ticks < EGG_DIG_TICKS) return 0;
        self.pregnant = false;
        self.digging_ticks = 0;
        return @max(1, @min(clutch_size, 4));
    }
};

pub const TurtleEgg = struct {
    count: u3 = 1,
    crack_stage: u2 = 0,
    elapsed_ticks: u32 = 0,
    hatch_after_ticks: u32 = EGG_MAX_HATCH_TICKS,

    pub fn init(count: u3, hatch_after_ticks: u32) TurtleEgg {
        return .{
            .count = @max(1, @min(count, 4)),
            .hatch_after_ticks = @max(EGG_MIN_HATCH_TICKS, @min(hatch_after_ticks, EGG_MAX_HATCH_TICKS)),
        };
    }

    /// Only warm sand accelerates incubation. Successful night checks advance
    /// the visible crack stage; hatching waits until the full incubation time.
    pub fn tick(self: *TurtleEgg, ticks: u32, is_night: bool, on_sand: bool, warm_sand: bool) EggTickResult {
        if (!on_sand or self.count == 0) return .{};
        const before = self.elapsed_ticks;
        const multiplier: u32 = if (warm_sand) 2 else 1;
        self.elapsed_ticks = @min(self.hatch_after_ticks, self.elapsed_ticks +| ticks *| multiplier);
        var cracked = false;
        if (is_night and self.crack_stage < 2 and self.elapsed_ticks > before) {
            self.crack_stage += 1;
            cracked = true;
        }
        if (self.elapsed_ticks < self.hatch_after_ticks or self.crack_stage < 2) return .{ .cracked = cracked };
        const babies = self.count;
        self.count = 0;
        return .{ .cracked = cracked, .hatched_babies = babies };
    }
};

pub const EggTickResult = struct { cracked: bool = false, hatched_babies: u3 = 0 };

pub fn feedBabySeagrass(turtle: *TurtleEntity) bool {
    if (!turtle.is_baby) return false;
    const remaining = BABY_GROWTH_TICKS -| turtle.growth_ticks;
    turtle.growth_ticks += @min(remaining, BABY_GROWTH_TICKS / 10);
    return true;
}

pub fn tickBabyGrowth(turtle: *TurtleEntity, ticks: u32) GrowthResult {
    if (!turtle.is_baby) return .{};
    turtle.growth_ticks = @min(BABY_GROWTH_TICKS, turtle.growth_ticks +| ticks);
    if (turtle.growth_ticks < BABY_GROWTH_TICKS) return .{};
    turtle.is_baby = false;
    return .{ .matured = true, .scutes_dropped = 1, .matured_to_adult = true, .dropped_turtle_scute = 1 };
}

pub const CraftSlot = ItemType;
/// 3x3 crafting grid. Scutes occupy the full top row and the two outer slots
/// of the middle row, leaving the bottom row empty.
pub fn craftTurtleHelmet(grid: [9]CraftSlot) ?ItemType {
    const pattern = [_]usize{ 0, 1, 2, 3, 5 };
    for (grid, 0..) |item, i| {
        var expected = false;
        for (pattern) |slot| expected = expected or slot == i;
        if ((item == .turtle_scute) != expected) return null;
    }
    return .turtle_helmet;
}

pub const HelmetBreathing = struct {
    effect: ?StatusEffect = null,
    remaining_ticks: u16 = 0,
    was_in_water: bool = false,

    pub fn tick(self: *HelmetBreathing, helmet_equipped: bool, in_water: bool, surfaced: bool) void {
        const entered_water = in_water and !self.was_in_water;
        self.was_in_water = in_water;
        if (helmet_equipped and (entered_water or surfaced)) {
            self.effect = .water_breathing;
            self.remaining_ticks = WATER_BREATHING_TICKS;
            return;
        }
        if (self.remaining_ticks > 0) self.remaining_ticks -= 1;
        if (self.remaining_ticks == 0) self.effect = null;
    }
};

test "turtles start with thirty health and beach coordinates" {
    const turtle = TurtleEntity{ .home_beach = .{ 12, -8 } };
    try std.testing.expectEqual(@as(f32, 30), turtle.health);
    try std.testing.expectEqual([2]i32{ 12, -8 }, turtle.home_beach);
}

test "baby scale is one quarter adult scale" {
    const baby = TurtleEntity{ .is_baby = true };
    const adult = TurtleEntity{};
    try std.testing.expectEqual(@as(f32, 0.25), baby.scale());
    try std.testing.expectEqual(@as(f32, 1), adult.scale());
}

test "feeding seagrass starts love mode" {
    var turtle = TurtleEntity{};
    try std.testing.expect(turtle.feedSeagrass());
    try std.testing.expect(turtle.in_love);
}

test "baby turtle cannot enter love mode" {
    var baby = TurtleEntity{ .is_baby = true };
    try std.testing.expect(!baby.feedSeagrass());
}

test "two adults in love trigger pregnancy" {
    var a = TurtleEntity{};
    var b = TurtleEntity{};
    _ = a.feedSeagrass();
    _ = b.feedSeagrass();
    try std.testing.expect(a.breedWith(&b));
    try std.testing.expect(a.pregnant);
    try std.testing.expect(!a.in_love and !b.in_love);
}

test "pregnant turtle navigates to its home beach" {
    const turtle = TurtleEntity{ .home_beach = .{ 41, 93 }, .pregnant = true };
    try std.testing.expectEqual([2]i32{ 41, 93 }, turtle.homeBeachTarget().?);
}

test "non pregnant turtle has no beach target" {
    try std.testing.expect((TurtleEntity{}).homeBeachTarget() == null);
}

test "egg laying requires sand" {
    var turtle = TurtleEntity{ .pregnant = true };
    try std.testing.expectEqual(@as(u3, 0), turtle.tickEggLaying(false, 2));
    try std.testing.expectEqual(@as(u32, 0), turtle.digging_ticks);
}

test "egg laying takes exactly two hundred ticks" {
    var turtle = TurtleEntity{ .pregnant = true };
    for (0..199) |_| try std.testing.expectEqual(@as(u3, 0), turtle.tickEggLaying(true, 2));
    try std.testing.expectEqual(@as(u3, 2), turtle.tickEggLaying(true, 2));
}

test "egg clutch size is clamped to one through four" {
    var turtle = TurtleEntity{ .pregnant = true };
    for (0..199) |_| _ = turtle.tickEggLaying(true, 0);
    try std.testing.expectEqual(@as(u3, 1), turtle.tickEggLaying(true, 0));
    turtle.pregnant = true;
    for (0..199) |_| _ = turtle.tickEggLaying(true, 7);
    try std.testing.expectEqual(@as(u3, 4), turtle.tickEggLaying(true, 7));
}

test "egg incubation duration is forty to fifty minutes" {
    try std.testing.expectEqual(@as(u32, 48_000), EGG_MIN_HATCH_TICKS);
    try std.testing.expectEqual(@as(u32, 60_000), EGG_MAX_HATCH_TICKS);
}

test "egg incubation does not advance away from sand" {
    var egg = TurtleEgg.init(2, EGG_MIN_HATCH_TICKS);
    _ = egg.tick(100, true, false, false);
    try std.testing.expectEqual(@as(u32, 0), egg.elapsed_ticks);
}

test "eggs crack at night in two visible stages" {
    var egg = TurtleEgg.init(1, EGG_MIN_HATCH_TICKS);
    try std.testing.expect(egg.tick(1, true, true, false).cracked);
    try std.testing.expectEqual(@as(u2, 1), egg.crack_stage);
    try std.testing.expect(egg.tick(1, true, true, false).cracked);
    try std.testing.expectEqual(@as(u2, 2), egg.crack_stage);
}

test "daytime incubation does not crack eggs" {
    var egg = TurtleEgg.init(1, EGG_MIN_HATCH_TICKS);
    try std.testing.expect(!egg.tick(1, false, true, false).cracked);
    try std.testing.expectEqual(@as(u2, 0), egg.crack_stage);
}

test "warm sand doubles egg incubation progress" {
    var warm = TurtleEgg.init(1, EGG_MIN_HATCH_TICKS);
    var cool = TurtleEgg.init(1, EGG_MIN_HATCH_TICKS);
    _ = warm.tick(100, false, true, true);
    _ = cool.tick(100, false, true, false);
    try std.testing.expectEqual(@as(u32, 200), warm.elapsed_ticks);
    try std.testing.expectEqual(@as(u32, 100), cool.elapsed_ticks);
}

test "fully incubated cracked eggs hatch all babies" {
    var egg = TurtleEgg{ .count = 3, .crack_stage = 2, .hatch_after_ticks = 10 };
    const result = egg.tick(10, false, true, false);
    try std.testing.expectEqual(@as(u3, 3), result.hatched_babies);
    try std.testing.expectEqual(@as(u3, 0), egg.count);
}

test "baby natural growth takes twenty four thousand ticks" {
    try std.testing.expectEqual(@as(u32, 24_000), BABY_GROWTH_TICKS);
    var baby = TurtleEntity{ .is_baby = true };
    try std.testing.expect(!tickBabyGrowth(&baby, 23_999).matured);
    try std.testing.expect(tickBabyGrowth(&baby, 1).matured);
}

test "seagrass accelerates baby growth by ten percent" {
    var baby = TurtleEntity{ .is_baby = true };
    try std.testing.expect(feedBabySeagrass(&baby));
    try std.testing.expectEqual(@as(u32, 2_400), baby.growth_ticks);
}

test "seagrass feeding can finish the remaining growth" {
    var baby = TurtleEntity{ .is_baby = true, .growth_ticks = 22_000 };
    _ = feedBabySeagrass(&baby);
    try std.testing.expect(tickBabyGrowth(&baby, 0).matured);
}

test "maturation instantly drops one turtle scute" {
    var baby = TurtleEntity{ .is_baby = true, .growth_ticks = 23_999 };
    const result = tickBabyGrowth(&baby, 1);
    try std.testing.expect(result.matured);
    try std.testing.expectEqual(@as(u8, 1), result.scutes_dropped);
    try std.testing.expect(!baby.is_baby);
}

test "adults cannot mature or drop scutes again" {
    var adult = TurtleEntity{};
    const result = tickBabyGrowth(&adult, BABY_GROWTH_TICKS);
    try std.testing.expect(!result.matured);
    try std.testing.expectEqual(@as(u8, 0), result.scutes_dropped);
}

test "five turtle scutes in horseshoe craft a helmet" {
    const grid = [_]CraftSlot{ .turtle_scute, .turtle_scute, .turtle_scute, .turtle_scute, .none, .turtle_scute, .none, .none, .none };
    try std.testing.expectEqual(ItemType.turtle_helmet, craftTurtleHelmet(grid).?);
}

test "incorrect helmet recipe is rejected" {
    const grid = [_]CraftSlot{ .turtle_scute, .turtle_scute, .turtle_scute, .none, .turtle_scute, .turtle_scute, .none, .none, .none };
    try std.testing.expect(craftTurtleHelmet(grid) == null);
}

test "helmet has specified durability and defense" {
    try std.testing.expectEqual(@as(u16, 275), TURTLE_HELMET_DURABILITY);
    try std.testing.expectEqual(@as(u8, 2), TURTLE_HELMET_DEFENSE);
}

test "helmet entering water grants ten seconds water breathing" {
    var effect = HelmetBreathing{};
    effect.tick(true, true, false);
    try std.testing.expectEqual(StatusEffect.water_breathing, effect.effect.?);
    try std.testing.expectEqual(@as(u16, 200), effect.remaining_ticks);
}

test "helmet surfaces refresh water breathing timer" {
    var effect = HelmetBreathing{};
    effect.tick(true, true, false);
    for (0..80) |_| effect.tick(false, false, false);
    effect.tick(true, false, true);
    try std.testing.expectEqual(@as(u16, 200), effect.remaining_ticks);
}

test "staying underwater does not refresh breathing timer" {
    var effect = HelmetBreathing{};
    effect.tick(true, true, false);
    for (0..80) |_| effect.tick(true, true, false);
    try std.testing.expectEqual(@as(u16, 120), effect.remaining_ticks);
}

test "breathing timer expires without helmet or water contact" {
    var effect = HelmetBreathing{};
    effect.tick(true, true, false);
    for (0..200) |_| effect.tick(false, false, false);
    try std.testing.expect(effect.effect == null);
    try std.testing.expectEqual(@as(u16, 0), effect.remaining_ticks);
}

test "turtle scute tag identity remains explicit" {
    try std.testing.expectEqual(@as(u16, 333), @intFromEnum(ItemType.turtle_scute));
}
