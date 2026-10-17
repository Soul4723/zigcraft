/// The sixteen concrete dyes, indexed in the conventional white-to-black order.
pub const ConcreteColor = enum(u4) {
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

/// Uniform, high-saturation concrete palette in normalized RGB.
pub fn concreteRgb(color: ConcreteColor) [3]f32 {
    return switch (color) {
        .white => .{ 0.95, 0.95, 0.95 },
        .orange => .{ 0.98, 0.38, 0.08 },
        .magenta => .{ 0.78, 0.18, 0.62 },
        .light_blue => .{ 0.20, 0.62, 0.92 },
        .yellow => .{ 0.98, 0.82, 0.08 },
        .lime => .{ 0.42, 0.82, 0.08 },
        .pink => .{ 0.94, 0.48, 0.62 },
        .gray => .{ 0.28, 0.30, 0.32 },
        .light_gray => .{ 0.62, 0.64, 0.65 },
        .cyan => .{ 0.08, 0.66, 0.68 },
        .purple => .{ 0.48, 0.16, 0.72 },
        .blue => .{ 0.12, 0.24, 0.78 },
        .brown => .{ 0.48, 0.25, 0.12 },
        .green => .{ 0.24, 0.48, 0.12 },
        .red => .{ 0.78, 0.12, 0.12 },
        .black => .{ 0.08, 0.08, 0.09 },
    };
}

pub const ConcreteCraftResult = struct {
    powder_crafted: u8,
    color: ConcreteColor,
};

/// Craft 8 colored powder from exactly four sand, four gravel, and one dye.
pub fn craftConcretePowder(sand_count: u8, gravel_count: u8, dye_count: u8, color: ConcreteColor) ConcreteCraftResult {
    if (sand_count < 4 or gravel_count < 4 or dye_count < 1) {
        return .{ .powder_crafted = 0, .color = color };
    }
    return .{ .powder_crafted = 8, .color = color };
}

/// Concrete powder hydrates only by direct water contact, including entity fall-in.
pub fn evaluateConcretePowderHydration(adjacent_or_falling_into_water: bool, in_rain_only: bool, hit_by_water_splash_bottle: bool) bool {
    _ = in_rain_only;
    _ = hit_by_water_splash_bottle;
    return adjacent_or_falling_into_water;
}

pub const ConcreteMiningTool = enum {
    shovel,
    pickaxe,
};

pub const ConcreteToolRequirement = struct {
    pub const powder_hardness: f32 = 0.5;
    pub const concrete_hardness: f32 = 1.8;

    pub const powder_is_falling: bool = true;
    pub const powder_fastest_tool: ConcreteMiningTool = .shovel;
    pub const concrete_is_falling: bool = false;

    /// Powder is hand-harvestable (and fastest with a shovel); concrete requires a pickaxe.
    pub fn dropsWhenMined(is_solid_concrete: bool, used_pickaxe: bool) bool {
        return !is_solid_concrete or used_pickaxe;
    }
};

test "4 sand 4 gravel and 1 dye craft eight powder" {
    const result = craftConcretePowder(4, 4, 1, .cyan);
    try std.testing.expectEqual(@as(u8, 8), result.powder_crafted);
    try std.testing.expectEqual(ConcreteColor.cyan, result.color);
}

test "crafting requires four sand" {
    try std.testing.expectEqual(@as(u8, 0), craftConcretePowder(3, 4, 1, .red).powder_crafted);
}

test "crafting requires four gravel" {
    try std.testing.expectEqual(@as(u8, 0), craftConcretePowder(4, 3, 1, .red).powder_crafted);
}

test "crafting requires dye" {
    try std.testing.expectEqual(@as(u8, 0), craftConcretePowder(4, 4, 0, .red).powder_crafted);
}

test "crafting accepts surplus ingredients" {
    try std.testing.expectEqual(@as(u8, 8), craftConcretePowder(7, 9, 2, .orange).powder_crafted);
}

test "all sixteen colors have normalized saturated RGB entries" {
    const colors = [_]ConcreteColor{ .white, .orange, .magenta, .light_blue, .yellow, .lime, .pink, .gray, .light_gray, .cyan, .purple, .blue, .brown, .green, .red, .black };
    for (colors) |color| {
        const rgb = concreteRgb(color);
        for (rgb) |channel| {
            try std.testing.expect(channel >= 0.0 and channel <= 1.0);
        }
    }
}

test "RGB table keeps the expected vibrant primary colors" {
    try std.testing.expectEqual([3]f32{ 0.98, 0.82, 0.08 }, concreteRgb(.yellow));
    try std.testing.expectEqual([3]f32{ 0.78, 0.12, 0.12 }, concreteRgb(.red));
    try std.testing.expectEqual([3]f32{ 0.12, 0.24, 0.78 }, concreteRgb(.blue));
}

test "color enum follows white to black indices" {
    try std.testing.expectEqual(@as(u4, 0), @intFromEnum(ConcreteColor.white));
    try std.testing.expectEqual(@as(u4, 15), @intFromEnum(ConcreteColor.black));
}

test "adjacent water instantly hydrates powder" {
    try std.testing.expect(evaluateConcretePowderHydration(true, false, false));
}

test "falling powder into water instantly hydrates" {
    try std.testing.expect(evaluateConcretePowderHydration(true, true, false));
}

test "rain alone does not hydrate powder" {
    try std.testing.expect(!evaluateConcretePowderHydration(false, true, false));
}

test "splash water bottle does not hydrate powder" {
    try std.testing.expect(!evaluateConcretePowderHydration(false, false, true));
}

test "cauldron or no water contact does not hydrate powder" {
    try std.testing.expect(!evaluateConcretePowderHydration(false, false, false));
}

test "powder is gravity affected and concrete is not" {
    try std.testing.expect(ConcreteToolRequirement.powder_is_falling);
    try std.testing.expect(!ConcreteToolRequirement.concrete_is_falling);
}

test "powder is fastest with a shovel" {
    try std.testing.expectEqual(ConcreteMiningTool.shovel, ConcreteToolRequirement.powder_fastest_tool);
}

test "powder and concrete hardness values" {
    try std.testing.expectEqual(@as(f32, 0.5), ConcreteToolRequirement.powder_hardness);
    try std.testing.expectEqual(@as(f32, 1.8), ConcreteToolRequirement.concrete_hardness);
}

test "powder drops when mined by shovel or bare hand" {
    try std.testing.expect(ConcreteToolRequirement.dropsWhenMined(false, false));
    try std.testing.expect(ConcreteToolRequirement.dropsWhenMined(false, true));
}

test "solid concrete drops only when mined by pickaxe" {
    try std.testing.expect(ConcreteToolRequirement.dropsWhenMined(true, true));
    try std.testing.expect(!ConcreteToolRequirement.dropsWhenMined(true, false));
}

const std = @import("std");
