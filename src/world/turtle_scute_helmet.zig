const std = @import("std");

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
pub const GrowthResult = struct { matured: bool = false, scutes_dropped: u8 = 0 };

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
    return .{ .matured = true, .scutes_dropped = 1 };
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
