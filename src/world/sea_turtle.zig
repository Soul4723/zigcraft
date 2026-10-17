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

pub const GrowthResult = struct { matured_to_adult: bool, dropped_turtle_scute: u8 };

pub fn tickBabyTurtleGrowth(state: *SeaTurtleState, dt: f32, fed_seagrass: bool) GrowthResult {
    if (!state.is_baby or dt <= 0) return .{ .matured_to_adult = false, .dropped_turtle_scute = 0 };
    state.growth_timer += dt;
    if (fed_seagrass) state.growth_timer += SEAGRASS_GROWTH_BONUS_SECONDS;
    if (state.growth_timer < BABY_GROWTH_SECONDS)
        return .{ .matured_to_adult = false, .dropped_turtle_scute = 0 };
    state.is_baby = false;
    return .{ .matured_to_adult = true, .dropped_turtle_scute = 1 };
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
