//! Dragon's Breath collection, lingering potion brewing, and tipped arrow crafting.
const std = @import("std");
const brewing = @import("brewing_stand_alchemy.zig");

pub const ItemType = enum { glass_bottle, dragons_breath, splash_potion, lingering_potion, arrow, tipped_arrow, other };

pub const BreathCloud = struct {
    radius: f32 = 4.0,

    pub fn collect(self: *BreathCloud, item: ItemType, bottle_count: *u8, breath_count: *u8, inside_cloud: bool) bool {
        if (!inside_cloud or item != .glass_bottle or bottle_count.* == 0 or self.radius <= 0) return false;
        bottle_count.* -= 1;
        breath_count.* += 1;
        self.radius = @max(0.0, self.radius - 0.5);
        return true;
    }
};

pub const PotionEffect = enum {
    poison, slowness, healing, harming, invisibility, strength, night_vision,
    regeneration, turtle_master, slow_falling,

    pub fn potionType(self: PotionEffect) brewing.PotionType {
        return switch (self) {
            .poison => .poison, .slowness => .slowness, .healing => .healing,
            .harming => .harming, .invisibility => .invisibility, .strength => .strength,
            .night_vision => .night_vision, .regeneration => .regeneration,
            .turtle_master => .turtle_master, .slow_falling => .slow_falling,
        };
    }

    pub fn durationSeconds(self: PotionEffect) f32 {
        return switch (self) {
            .poison, .regeneration => 45.0,
            .slowness, .turtle_master => 20.0,
            .healing, .harming => 0.0,
            else => 180.0,
        };
    }

    pub fn tippedArrowDurationSeconds(self: PotionEffect) f32 {
        return self.durationSeconds() / 8.0;
    }
};

pub const BrewingResult = struct {
    item: ItemType,
    effect: PotionEffect,
    cloud_duration_seconds: f32 = 30.0,
    cloud_duration_ticks: u32 = 600,
};

pub fn brewLingering(input: ItemType, potion: PotionEffect, ingredient: ItemType, count: u8) ?BrewingResult {
    if (input != .splash_potion or ingredient != .dragons_breath or count == 0) return null;
    return .{ .item = .lingering_potion, .effect = potion };
}

pub const GridItem = struct { item: ItemType = .other, effect: ?PotionEffect = null };
pub const CraftResult = struct { item: ItemType, effect: PotionEffect, count: u8 = 8 };

/// The potion occupies the center slot; all eight surrounding cells must be arrows.
pub fn craftTippedArrows(grid: [9]GridItem) ?CraftResult {
    if (grid[4].item != .lingering_potion) return null;
    const effect = grid[4].effect orelse return null;
    for (grid, 0..) |slot, index| {
        if (index != 4 and slot.item != .arrow) return null;
    }
    return .{ .item = .tipped_arrow, .effect = effect };
}

test "cloud collection consumes one bottle, grants breath, and shrinks radius" {
    var cloud = BreathCloud{ .radius = 3.0 };
    var bottles: u8 = 2;
    var breath: u8 = 0;
    try std.testing.expect(cloud.collect(.glass_bottle, &bottles, &breath, true));
    try std.testing.expectEqual(@as(u8, 1), bottles);
    try std.testing.expectEqual(@as(u8, 1), breath);
    try std.testing.expectEqual(@as(f32, 2.5), cloud.radius);
}

test "no cloud, wrong item, or empty bottle rejects collection" {
    var cloud = BreathCloud{};
    var bottles: u8 = 1;
    var breath: u8 = 0;
    try std.testing.expect(!cloud.collect(.glass_bottle, &bottles, &breath, false));
    try std.testing.expect(!cloud.collect(.arrow, &bottles, &breath, true));
    bottles = 0;
    try std.testing.expect(!cloud.collect(.glass_bottle, &bottles, &breath, true));
    try std.testing.expectEqual(@as(u8, 0), breath);
    try std.testing.expectEqual(@as(f32, 4.0), cloud.radius);
}

test "cloud radius stops at zero" {
    var cloud = BreathCloud{ .radius = 0.25 };
    var bottles: u8 = 1;
    var breath: u8 = 0;
    try std.testing.expect(cloud.collect(.glass_bottle, &bottles, &breath, true));
    try std.testing.expectEqual(@as(f32, 0), cloud.radius);
    try std.testing.expect(!cloud.collect(.glass_bottle, &bottles, &breath, true));
}

test "splash potion and breath brew a 30 second lingering potion" {
    const brewed = brewLingering(.splash_potion, .poison, .dragons_breath, 1).?;
    try std.testing.expectEqual(ItemType.lingering_potion, brewed.item);
    try std.testing.expectEqual(PotionEffect.poison, brewed.effect);
    try std.testing.expectEqual(@as(f32, 30), brewed.cloud_duration_seconds);
    try std.testing.expectEqual(@as(u32, 600), brewed.cloud_duration_ticks);
}

test "brewing rejects drinkable potion, wrong ingredient, and missing ingredient" {
    try std.testing.expect(brewLingering(.other, .poison, .dragons_breath, 1) == null);
    try std.testing.expect(brewLingering(.splash_potion, .poison, .arrow, 1) == null);
    try std.testing.expect(brewLingering(.splash_potion, .poison, .dragons_breath, 0) == null);
}

test "brewing stand recipe agrees with base alchemy rules" {
    const base = brewing.PotionState{ .potion_type = .healing, .vessel = .splash, .duration_seconds = 0 };
    const converted = brewing.brewPotion(base, .dragons_breath).?;
    try std.testing.expectEqual(brewing.DeliveryVessel.lingering, converted.vessel);
    try std.testing.expectEqual(brewing.PotionType.healing, converted.potion_type);
}

test "eight arrows around a lingering potion craft eight matching tipped arrows" {
    var grid = [_]GridItem{.{ .item = .arrow }} ** 9;
    grid[4] = .{ .item = .lingering_potion, .effect = .slowness };
    const result = craftTippedArrows(grid).?;
    try std.testing.expectEqual(ItemType.tipped_arrow, result.item);
    try std.testing.expectEqual(PotionEffect.slowness, result.effect);
    try std.testing.expectEqual(@as(u8, 8), result.count);
}

test "tipped arrow recipe rejects missing or misplaced ingredients" {
    var grid = [_]GridItem{.{ .item = .arrow }} ** 9;
    grid[4] = .{ .item = .lingering_potion, .effect = .healing };
    grid[0] = .{};
    try std.testing.expect(craftTippedArrows(grid) == null);
    grid[0] = .{ .item = .arrow };
    grid[4] = .{ .item = .arrow };
    try std.testing.expect(craftTippedArrows(grid) == null);
    grid[4] = .{ .item = .lingering_potion };
    try std.testing.expect(craftTippedArrows(grid) == null);
}

test "effect and tipped-arrow duration mappings cover all requested potions" {
    const effects = [_]PotionEffect{ .poison, .slowness, .healing, .harming, .invisibility, .strength, .night_vision, .regeneration, .turtle_master, .slow_falling };
    for (effects) |effect| {
        try std.testing.expectEqual(effect, @as(PotionEffect, @enumFromInt(@intFromEnum(effect))));
        try std.testing.expectEqual(effect.durationSeconds() / 8.0, effect.tippedArrowDurationSeconds());
        try std.testing.expect(effect.potionType().name().len > 0);
    }
}

test "all requested effects preserve identity through crafting" {
    const effects = [_]PotionEffect{ .poison, .slowness, .healing, .harming, .invisibility, .strength, .night_vision, .regeneration, .turtle_master, .slow_falling };
    for (effects) |effect| {
        var grid = [_]GridItem{.{ .item = .arrow }} ** 9;
        grid[4] = .{ .item = .lingering_potion, .effect = effect };
        try std.testing.expectEqual(effect, craftTippedArrows(grid).?.effect);
    }
}

test "lingering potion effect mappings match brewable potion identifiers" {
    try std.testing.expectEqual(brewing.PotionType.poison, PotionEffect.poison.potionType());
    try std.testing.expectEqual(brewing.PotionType.slowness, PotionEffect.slowness.potionType());
    try std.testing.expectEqual(brewing.PotionType.healing, PotionEffect.healing.potionType());
    try std.testing.expectEqual(brewing.PotionType.harming, PotionEffect.harming.potionType());
    try std.testing.expectEqual(brewing.PotionType.invisibility, PotionEffect.invisibility.potionType());
    try std.testing.expectEqual(brewing.PotionType.strength, PotionEffect.strength.potionType());
    try std.testing.expectEqual(brewing.PotionType.night_vision, PotionEffect.night_vision.potionType());
    try std.testing.expectEqual(brewing.PotionType.regeneration, PotionEffect.regeneration.potionType());
    try std.testing.expectEqual(brewing.PotionType.turtle_master, PotionEffect.turtle_master.potionType());
    try std.testing.expectEqual(brewing.PotionType.slow_falling, PotionEffect.slow_falling.potionType());
}

test "effect duration mappings use standard potion durations" {
    try std.testing.expectEqual(@as(f32, 45), PotionEffect.poison.durationSeconds());
    try std.testing.expectEqual(@as(f32, 20), PotionEffect.slowness.durationSeconds());
    try std.testing.expectEqual(@as(f32, 0), PotionEffect.healing.durationSeconds());
    try std.testing.expectEqual(@as(f32, 0), PotionEffect.harming.durationSeconds());
    try std.testing.expectEqual(@as(f32, 180), PotionEffect.invisibility.durationSeconds());
    try std.testing.expectEqual(@as(f32, 180), PotionEffect.strength.durationSeconds());
    try std.testing.expectEqual(@as(f32, 180), PotionEffect.night_vision.durationSeconds());
    try std.testing.expectEqual(@as(f32, 45), PotionEffect.regeneration.durationSeconds());
    try std.testing.expectEqual(@as(f32, 20), PotionEffect.turtle_master.durationSeconds());
    try std.testing.expectEqual(@as(f32, 180), PotionEffect.slow_falling.durationSeconds());
}

test "poison maps to a 45 second effect and 5.625 second arrow" {
    try std.testing.expectEqual(@as(f32, 5.625), PotionEffect.poison.tippedArrowDurationSeconds());
}

test "slowness maps to a 20 second effect and 2.5 second arrow" {
    try std.testing.expectEqual(@as(f32, 2.5), PotionEffect.slowness.tippedArrowDurationSeconds());
}

test "healing remains instantaneous on a tipped arrow" {
    try std.testing.expectEqual(@as(f32, 0), PotionEffect.healing.tippedArrowDurationSeconds());
    try std.testing.expect(PotionEffect.healing.potionType().isInstantaneous());
}

test "harming remains instantaneous on a tipped arrow" {
    try std.testing.expectEqual(@as(f32, 0), PotionEffect.harming.tippedArrowDurationSeconds());
    try std.testing.expect(PotionEffect.harming.potionType().isInstantaneous());
}

test "invisibility maps to the brewable invisibility potion" {
    try std.testing.expectEqualStrings("Invisibility", PotionEffect.invisibility.potionType().name());
}

test "strength maps to the brewable strength potion" {
    try std.testing.expectEqualStrings("Strength", PotionEffect.strength.potionType().name());
}

test "night vision maps to the brewable night vision potion" {
    try std.testing.expectEqualStrings("Night Vision", PotionEffect.night_vision.potionType().name());
}

test "regeneration maps to a 45 second effect" {
    try std.testing.expectEqual(@as(f32, 45), PotionEffect.regeneration.durationSeconds());
}

test "turtle master maps to a 20 second effect" {
    try std.testing.expectEqual(@as(f32, 20), PotionEffect.turtle_master.durationSeconds());
}

test "slow falling maps to the brewable slow falling potion" {
    try std.testing.expectEqualStrings("Slow Falling", PotionEffect.slow_falling.potionType().name());
}

test "one bottle can collect only one breath item per interaction" {
    var cloud = BreathCloud{};
    var bottles: u8 = 3;
    var breath: u8 = 0;
    try std.testing.expect(cloud.collect(.glass_bottle, &bottles, &breath, true));
    try std.testing.expectEqual(@as(u8, 1), breath);
    try std.testing.expectEqual(@as(u8, 2), bottles);
}

test "collection does not consume bottles outside a cloud" {
    var cloud = BreathCloud{};
    var bottles: u8 = 4;
    var breath: u8 = 2;
    try std.testing.expect(!cloud.collect(.glass_bottle, &bottles, &breath, false));
    try std.testing.expectEqual(@as(u8, 4), bottles);
    try std.testing.expectEqual(@as(u8, 2), breath);
}

test "collection does not accept an empty-radius cloud" {
    var cloud = BreathCloud{ .radius = 0 };
    var bottles: u8 = 1;
    var breath: u8 = 0;
    try std.testing.expect(!cloud.collect(.glass_bottle, &bottles, &breath, true));
}

test "a full arrow ring may carry poison" {
    var grid = [_]GridItem{.{ .item = .arrow }} ** 9;
    grid[4] = .{ .item = .lingering_potion, .effect = .poison };
    try std.testing.expectEqual(PotionEffect.poison, craftTippedArrows(grid).?.effect);
}

test "a full arrow ring may carry healing" {
    var grid = [_]GridItem{.{ .item = .arrow }} ** 9;
    grid[4] = .{ .item = .lingering_potion, .effect = .healing };
    try std.testing.expectEqual(PotionEffect.healing, craftTippedArrows(grid).?.effect);
}

test "a full arrow ring may carry turtle master" {
    var grid = [_]GridItem{.{ .item = .arrow }} ** 9;
    grid[4] = .{ .item = .lingering_potion, .effect = .turtle_master };
    try std.testing.expectEqual(PotionEffect.turtle_master, craftTippedArrows(grid).?.effect);
}

test "arrow crafting consumes the center slot for potion payload" {
    var grid = [_]GridItem{.{ .item = .arrow }} ** 9;
    grid[4] = .{ .item = .lingering_potion, .effect = .strength };
    try std.testing.expectEqual(@as(u8, 8), craftTippedArrows(grid).?.count);
}

test "lingering cloud timing is in 20 tick seconds" {
    const result = brewLingering(.splash_potion, .slow_falling, .dragons_breath, 1).?;
    try std.testing.expectEqual(result.cloud_duration_ticks, @as(u32, @intFromFloat(result.cloud_duration_seconds * 20.0)));
}
