const std = @import("std");

pub const polar_bear_health: f32 = 30.0;
pub const polar_bear_hind_leg_maul_damage: f32 = 6.0;
pub const polar_bear_cub_defense_radius: f32 = 16.0;
pub const polar_bear_swims_faster_than_player = true;

/// Adult bears are normally neutral, but an adult within cub-defense range
/// attacks immediately. Any bear that has already been attacked retaliates.
pub fn isPolarBearHostileToPlayer(bear_is_adult: bool, has_cub_within_16m: bool, was_attacked: bool) bool {
    if (was_attacked) return true;
    return bear_is_adult and has_cub_within_16m;
}

pub const IglooItem = enum {
    splash_potion_of_weakness,
    golden_apple,
};

pub const IglooContainer = enum { brewing_stand, loot_chest };
pub const IglooCellOccupant = enum { cleric_villager, zombie_villager };

pub const IglooLaboratory = struct {
    brewing_stands: u1 = 1,
    brewing_stand_potion: IglooItem = .splash_potion_of_weakness,
    loot_chests: u1 = 1,
    chest_golden_apples: u1 = 1,
    iron_bar_prison_cells: u2 = 2,
    cell_occupants: [2]IglooCellOccupant = .{ .cleric_villager, .zombie_villager },
    is_underground_stone_brick_room: bool = true,
};

pub const IglooStructure = struct {
    basement_generation_chance_percent: u7 = 50,
    has_basement_laboratory: bool = false,
    secret_shaft_under_floor_carpet: bool = false,
    ladder_shaft_to_laboratory: bool = false,
    laboratory: ?IglooLaboratory = null,

    /// `roll` is an integer in [0, 99], supplied by world generation's RNG.
    pub fn generate(roll: u7) IglooStructure {
        const has_basement = roll < 50;
        return .{
            .has_basement_laboratory = has_basement,
            .secret_shaft_under_floor_carpet = has_basement,
            .ladder_shaft_to_laboratory = has_basement,
            .laboratory = if (has_basement) IglooLaboratory{} else null,
        };
    }
};

pub const snow_layer_collision_height_per_layer: f32 = 0.125;
pub const SnowLayerStack = struct {
    layers: u4 = 1,

    pub fn addLayer(self: *SnowLayerStack) void {
        if (self.layers < 8) self.layers += 1;
    }

    pub fn collisionHeight(self: SnowLayerStack) f32 {
        return snow_layer_collision_height_per_layer * @as(f32, @floatFromInt(self.layers));
    }

    pub fn isFullSnowBlock(self: SnowLayerStack) bool {
        return self.layers == 8;
    }
};

pub fn isFullSnowBlock(layers: u4) bool {
    return layers == 8;
}

test "polar bear base health is thirty" {
    try std.testing.expectEqual(@as(f32, 30.0), polar_bear_health);
}

test "standing hind-leg maul deals six damage" {
    try std.testing.expectEqual(@as(f32, 6.0), polar_bear_hind_leg_maul_damage);
}

test "polar bears swim faster than the player" {
    try std.testing.expect(polar_bear_swims_faster_than_player);
}

test "adult polar bear alone is neutral" {
    try std.testing.expect(!isPolarBearHostileToPlayer(true, false, false));
}

test "adult bear becomes hostile to protect cub within sixteen blocks" {
    try std.testing.expect(isPolarBearHostileToPlayer(true, true, false));
}

test "adult bear is neutral when cub is outside defense radius" {
    try std.testing.expect(!isPolarBearHostileToPlayer(true, false, false));
    try std.testing.expectEqual(@as(f32, 16.0), polar_bear_cub_defense_radius);
}

test "attacked adult bear retaliates even without cub" {
    try std.testing.expect(isPolarBearHostileToPlayer(true, false, true));
}

test "attacked bear retaliates regardless of age" {
    try std.testing.expect(isPolarBearHostileToPlayer(false, false, true));
}

test "cub by itself is not made hostile by adult cub defense rule" {
    try std.testing.expect(!isPolarBearHostileToPlayer(false, true, false));
}

test "igloo basement generation chance is fifty percent" {
    try std.testing.expectEqual(@as(u7, 50), (IglooStructure{}).basement_generation_chance_percent);
}

test "igloo rolls below fifty generate carpet-hidden ladder laboratory" {
    const igloo = IglooStructure.generate(49);
    try std.testing.expect(igloo.has_basement_laboratory);
    try std.testing.expect(igloo.secret_shaft_under_floor_carpet);
    try std.testing.expect(igloo.ladder_shaft_to_laboratory);
    try std.testing.expect(igloo.laboratory != null);
}

test "igloo rolls at and above fifty omit basement" {
    try std.testing.expect(!IglooStructure.generate(50).has_basement_laboratory);
    try std.testing.expect(!IglooStructure.generate(99).has_basement_laboratory);
}

test "basement laboratory contains weakness potion and golden apple kit" {
    const lab = IglooStructure.generate(0).laboratory.?;
    try std.testing.expectEqual(@as(u1, 1), lab.brewing_stands);
    try std.testing.expectEqual(IglooItem.splash_potion_of_weakness, lab.brewing_stand_potion);
    try std.testing.expectEqual(@as(u1, 1), lab.loot_chests);
    try std.testing.expectEqual(@as(u1, 1), lab.chest_golden_apples);
}

test "basement laboratory has two tutorial prison cells" {
    const lab = IglooStructure.generate(25).laboratory.?;
    try std.testing.expectEqual(@as(u2, 2), lab.iron_bar_prison_cells);
    try std.testing.expectEqual(IglooCellOccupant.cleric_villager, lab.cell_occupants[0]);
    try std.testing.expectEqual(IglooCellOccupant.zombie_villager, lab.cell_occupants[1]);
    try std.testing.expect(lab.is_underground_stone_brick_room);
}

test "snow layer starts at one eighth block height" {
    const snow = SnowLayerStack{};
    try std.testing.expectEqual(@as(u4, 1), snow.layers);
    try std.testing.expectApproxEqAbs(@as(f32, 0.125), snow.collisionHeight(), 0.0001);
}

test "snow layers stack from one through eight with proportional height" {
    var snow = SnowLayerStack{};
    var expected: u4 = 1;
    while (expected < 8) {
        snow.addLayer();
        expected += 1;
        try std.testing.expectEqual(expected, snow.layers);
        try std.testing.expectApproxEqAbs(0.125 * @as(f32, @floatFromInt(expected)), snow.collisionHeight(), 0.0001);
    }
}

test "eight snow layers are a full block and further layers do not overflow" {
    var snow = SnowLayerStack{};
    var i: usize = 1;
    while (i < 8) : (i += 1) snow.addLayer();
    try std.testing.expect(isFullSnowBlock(snow.layers));
    try std.testing.expect(snow.isFullSnowBlock());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), snow.collisionHeight(), 0.0001);
    snow.addLayer();
    try std.testing.expectEqual(@as(u4, 8), snow.layers);
}

test "partial snow stacks are not full blocks" {
    try std.testing.expect(!isFullSnowBlock(1));
    try std.testing.expect(!isFullSnowBlock(7));
}
