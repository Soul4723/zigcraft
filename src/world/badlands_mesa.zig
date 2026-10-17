/// Terracotta palette used by the mesa strata selector.
pub const MesaTerracottaBandColor = enum {
    terracotta_uncolored,
    orange,
    yellow,
    brown,
    red,
    white,
    light_gray,
};

// Sixteen four-block strata layers form a 64-block sediment cycle. The seven
// exposed palette colors repeat in a deliberate sedimentary sequence.
const strata_palette = [_]MesaTerracottaBandColor{
    .terracotta_uncolored, .terracotta_uncolored, .orange, .orange,
    .yellow, .brown, .brown, .red,
    .red, .white, .light_gray, .light_gray,
    .terracotta_uncolored, .orange, .red, .brown,
};

/// Selects a horizontal sediment layer. Seed offsets shift the repeating bands.
pub fn mesaStrataColorForAltitude(y_coord: i32, world_seed_offset: i32) MesaTerracottaBandColor {
    const layer = @mod(@divFloor(y_coord +% world_seed_offset, 4), @as(i32, strata_palette.len));
    return strata_palette[@intCast(layer)];
}

pub const BadlandsGoldOreGeneration = struct { eligible: bool, veins_per_chunk: u8 };

pub fn canGenerateBadlandsBonusGoldOre(in_badlands_biome: bool, y_coord: i32) BadlandsGoldOreGeneration {
    if (in_badlands_biome) {
        const eligible = y_coord >= 32 and y_coord <= 256;
        return .{ .eligible = eligible, .veins_per_chunk = if (eligible) 20 else 0 };
    }
    const eligible = y_coord < 32;
    return .{ .eligible = eligible, .veins_per_chunk = if (eligible) 4 else 0 };
}

pub const BadlandsMineshaftKind = enum { abandoned_surface_mineshaft };
pub const MesaMineshaftBlock = enum { dark_oak_planks, dark_oak_fence, rail, tnt_minecart, chest_minecart };

pub const MesaMineshaftProps = struct {
    kind: BadlandsMineshaftKind = .abandoned_surface_mineshaft,
    min_y: i32 = 60,
    max_y: i32 = 75,
    support_block: MesaMineshaftBlock = .dark_oak_planks,
    fence_block: MesaMineshaftBlock = .dark_oak_fence,
    exposed_to_sunlight: bool = true,
    has_tnt_minecarts: bool = true,
    has_chest_minecarts: bool = true,
};
pub const BADLANDS_MINESHAFT = MesaMineshaftProps{};

pub fn canGenerateSurfaceBadlandsMineshaft(y_coord: i32) bool {
    return y_coord >= BADLANDS_MINESHAFT.min_y and y_coord <= BADLANDS_MINESHAFT.max_y;
}

/// Sun exposure suppresses the cave-spider jockey encounter in mesa shafts.
pub fn canSpawnCaveSpiderJockeyInMesaMineshaft(y_coord: i32, exposed_to_sunlight: bool) bool {
    return canGenerateSurfaceBadlandsMineshaft(y_coord) and !exposed_to_sunlight;
}

pub const RedSandProduct = enum { glass, red_sandstone, smooth_red_sandstone, chiseled_red_sandstone, wither_relief };
pub const RedSandProps = struct {
    is_falling: bool = true,
    smelts_into: RedSandProduct = .glass,
    supports_dead_bush: bool = true,
    supports_cactus: bool = true,
    crafting_input_count: u8 = 4,
    crafting_output: RedSandProduct = .red_sandstone,
    smooth_variant: RedSandProduct = .smooth_red_sandstone,
    chiseled_variant: RedSandProduct = .chiseled_red_sandstone,
    chiseled_relief: RedSandProduct = .wither_relief,
};
pub const RED_SAND = RedSandProps{};

pub fn redSandCraftOutput(input_count: u32) u32 {
    return input_count / RED_SAND.crafting_input_count;
}

pub fn redSandstoneMasonry() [3]RedSandProduct {
    return .{ .red_sandstone, .smooth_red_sandstone, .chiseled_red_sandstone };
}

test "strata repeat deterministically across horizontal layers" {
    const std = @import("std");
    try std.testing.expectEqual(mesaStrataColorForAltitude(40, 3), mesaStrataColorForAltitude(40, 3));
    try std.testing.expectEqual(mesaStrataColorForAltitude(40, 3), mesaStrataColorForAltitude(41, 3));
    try std.testing.expect(mesaStrataColorForAltitude(40, 0) != mesaStrataColorForAltitude(48, 0));
}

test "sixteen strata layers cover the declared color palette" {
    const std = @import("std");
    var seen = [_]bool{false} ** 7;
    for (0..16) |layer| seen[@intFromEnum(mesaStrataColorForAltitude(@intCast(layer * 4), 0))] = true;
    for (seen) |color_seen| try std.testing.expect(color_seen);
}

test "strata seed offset shifts bands predictably" {
    const std = @import("std");
    try std.testing.expectEqual(mesaStrataColorForAltitude(40, 0), mesaStrataColorForAltitude(36, 4));
    try std.testing.expect(mesaStrataColorForAltitude(40, 0) != mesaStrataColorForAltitude(40, 8));
}

test "negative altitude bands use floor division" {
    const std = @import("std");
    try std.testing.expectEqual(mesaStrataColorForAltitude(-4, 0), mesaStrataColorForAltitude(-1, 0));
}

test "badlands gold begins at Y 32 and yields twenty veins" {
    const std = @import("std");
    const result = canGenerateBadlandsBonusGoldOre(true, 32);
    try std.testing.expect(result.eligible);
    try std.testing.expectEqual(@as(u8, 20), result.veins_per_chunk);
}

test "badlands gold includes every altitude from Y 32 through 256" {
    const std = @import("std");
    for (32..257) |y| {
        const result = canGenerateBadlandsBonusGoldOre(true, @intCast(y));
        try std.testing.expect(result.eligible);
        try std.testing.expectEqual(@as(u8, 20), result.veins_per_chunk);
    }
}

test "badlands gold excludes levels outside Y 32 through 256" {
    const std = @import("std");
    try std.testing.expect(!canGenerateBadlandsBonusGoldOre(true, 31).eligible);
    try std.testing.expect(!canGenerateBadlandsBonusGoldOre(true, 257).eligible);
}

test "normal gold below Y 32 has four veins per chunk" {
    const std = @import("std");
    for ([_]i32{ -64, -1, 0, 31 }) |y| {
        const result = canGenerateBadlandsBonusGoldOre(false, y);
        try std.testing.expect(result.eligible);
        try std.testing.expectEqual(@as(u8, 4), result.veins_per_chunk);
    }
}

test "normal gold is excluded at and above Y 32" {
    const std = @import("std");
    for ([_]i32{ 32, 64, 256 }) |y| try std.testing.expect(!canGenerateBadlandsBonusGoldOre(false, y).eligible);
}

test "surface mineshaft bounds are inclusive Y 60 through 75" {
    const std = @import("std");
    try std.testing.expect(!canGenerateSurfaceBadlandsMineshaft(59));
    try std.testing.expect(canGenerateSurfaceBadlandsMineshaft(60));
    try std.testing.expect(canGenerateSurfaceBadlandsMineshaft(75));
    try std.testing.expect(!canGenerateSurfaceBadlandsMineshaft(76));
}

test "surface mineshafts use exposed dark oak with TNT and chest minecarts" {
    const std = @import("std");
    try std.testing.expectEqual(BadlandsMineshaftKind.abandoned_surface_mineshaft, BADLANDS_MINESHAFT.kind);
    try std.testing.expectEqual(MesaMineshaftBlock.dark_oak_planks, BADLANDS_MINESHAFT.support_block);
    try std.testing.expectEqual(MesaMineshaftBlock.dark_oak_fence, BADLANDS_MINESHAFT.fence_block);
    try std.testing.expect(BADLANDS_MINESHAFT.exposed_to_sunlight);
    try std.testing.expect(BADLANDS_MINESHAFT.has_tnt_minecarts and BADLANDS_MINESHAFT.has_chest_minecarts);
}

test "sunlit shafts suppress cave spider jockeys" {
    const std = @import("std");
    try std.testing.expect(!canSpawnCaveSpiderJockeyInMesaMineshaft(65, true));
    try std.testing.expect(canSpawnCaveSpiderJockeyInMesaMineshaft(65, false));
    try std.testing.expect(!canSpawnCaveSpiderJockeyInMesaMineshaft(80, false));
}

test "red sand falls, smelts to glass, and supports desert plants" {
    const std = @import("std");
    try std.testing.expect(RED_SAND.is_falling);
    try std.testing.expectEqual(RedSandProduct.glass, RED_SAND.smelts_into);
    try std.testing.expect(RED_SAND.supports_dead_bush and RED_SAND.supports_cactus);
}

test "four red sand craft one red sandstone with remainder handling" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 0), redSandCraftOutput(3));
    try std.testing.expectEqual(@as(u32, 1), redSandCraftOutput(4));
    try std.testing.expectEqual(@as(u32, 2), redSandCraftOutput(8));
    try std.testing.expectEqual(@as(u32, 2), redSandCraftOutput(11));
}

test "red sandstone exposes smooth chiseled and Wither relief masonry" {
    const std = @import("std");
    try std.testing.expectEqual(RedSandProduct.red_sandstone, RED_SAND.crafting_output);
    try std.testing.expectEqual(RedSandProduct.smooth_red_sandstone, RED_SAND.smooth_variant);
    try std.testing.expectEqual(RedSandProduct.chiseled_red_sandstone, RED_SAND.chiseled_variant);
    try std.testing.expectEqual(RedSandProduct.wither_relief, RED_SAND.chiseled_relief);
    try std.testing.expectEqual(RedSandProduct.chiseled_red_sandstone, redSandstoneMasonry()[2]);
}
