const std = @import("std");

/// Items used by lighting-fixture recipes and drops.
pub const FixtureItem = enum {
    lantern,
    soul_lantern,
    torch,
    soul_torch,
    redstone_torch,
    carved_pumpkin,
    jack_o_lantern,
    sea_lantern,
    prismarine_shard,
    prismarine_crystal,
    end_rod,
    blaze_rod,
    popped_chorus_fruit,
    iron_ingot,
    iron_nugget,
    chain,
};

pub const RecipeIngredient = struct {
    item: FixtureItem,
    count: u8,
};

pub const CraftingRecipe = struct {
    output: FixtureItem,
    output_count: u8,
    ingredients: [3]RecipeIngredient,
    ingredient_count: u8,

    pub fn ingredient(self: CraftingRecipe, item: FixtureItem) u8 {
        var total: u8 = 0;
        for (self.ingredients[0..self.ingredient_count]) |part| {
            if (part.item == item) total += part.count;
        }
        return total;
    }
};

/// Light-emitting blocks and fixtures introduced by Milestone 413.
pub const LightFixtureKind = enum {
    lantern,
    soul_lantern,
    torch,
    soul_torch,
    redstone_torch_lit,
    jack_o_lantern,
    sea_lantern,
    end_rod,

    pub fn lightLevel(self: LightFixtureKind) u8 {
        return switch (self) {
            .lantern, .jack_o_lantern, .sea_lantern => 15,
            .torch, .end_rod => 14,
            .soul_lantern, .soul_torch => 10,
            .redstone_torch_lit => 7,
        };
    }

    pub fn meltsSnowAndIce(self: LightFixtureKind) bool {
        return switch (self) {
            .lantern, .torch, .jack_o_lantern, .sea_lantern, .end_rod => true,
            .soul_lantern, .soul_torch, .redstone_torch_lit => false,
        };
    }

    pub fn repelsPiglins(self: LightFixtureKind) bool {
        return self == .soul_lantern or self == .soul_torch;
    }

    pub fn piglinRepelRadius(self: LightFixtureKind) u8 {
        return if (self.repelsPiglins()) 8 else 0;
    }

    pub fn washedAwayByWater(self: LightFixtureKind) bool {
        return self == .torch or self == .soul_torch or self == .redstone_torch_lit;
    }

    pub fn canPlaceUnderwater(self: LightFixtureKind) bool {
        return self == .jack_o_lantern or self == .sea_lantern or self == .end_rod;
    }

    pub fn hasSolidCollision(self: LightFixtureKind) bool {
        return self == .end_rod;
    }

    pub fn supportsAllFaces(self: LightFixtureKind) bool {
        return self == .end_rod;
    }

    /// Whether this fixture blocks spawning at a supplied minimum light level.
    /// The normal hostile-mob rule uses a threshold of 1, so all fixtures do.
    pub fn preventsMobSpawning(self: LightFixtureKind, required_light_level: u8) bool {
        return self.lightLevel() >= required_light_level;
    }

    pub fn recipe(self: LightFixtureKind) CraftingRecipe {
        const empty = RecipeIngredient{ .item = .iron_nugget, .count = 0 };
        return switch (self) {
            .lantern => .{ .output = .lantern, .output_count = 1, .ingredients = .{
                .{ .item = .torch, .count = 1 }, .{ .item = .iron_nugget, .count = 8 }, empty,
            }, .ingredient_count = 2 },
            .soul_lantern => .{ .output = .soul_lantern, .output_count = 1, .ingredients = .{
                .{ .item = .soul_torch, .count = 1 }, .{ .item = .iron_nugget, .count = 8 }, empty,
            }, .ingredient_count = 2 },
            .jack_o_lantern => .{ .output = .jack_o_lantern, .output_count = 1, .ingredients = .{
                .{ .item = .carved_pumpkin, .count = 1 }, .{ .item = .torch, .count = 1 }, empty,
            }, .ingredient_count = 2 },
            .sea_lantern => .{ .output = .sea_lantern, .output_count = 1, .ingredients = .{
                .{ .item = .prismarine_shard, .count = 4 }, .{ .item = .prismarine_crystal, .count = 5 }, empty,
            }, .ingredient_count = 2 },
            .end_rod => .{ .output = .end_rod, .output_count = 4, .ingredients = .{
                .{ .item = .blaze_rod, .count = 1 }, .{ .item = .popped_chorus_fruit, .count = 1 }, empty,
            }, .ingredient_count = 2 },
            .torch, .soul_torch, .redstone_torch_lit => .{ .output = .torch, .output_count = 0, .ingredients = .{ empty, empty, empty }, .ingredient_count = 0 },
        };
    }

    /// Sea lantern drops: Silk Touch preserves the block; otherwise Fortune III
    /// increases the crystal drop cap from 3 to 5.
    pub fn seaLanternDrops(self: LightFixtureKind, silk_touch: bool, fortune_level: u8) u8 {
        if (self != .sea_lantern) return 0;
        if (silk_touch) return 1;
        return if (fortune_level >= 3) 5 else if (fortune_level > 0) 3 else 2;
    }

    pub fn item(self: LightFixtureKind) FixtureItem {
        return switch (self) {
            .lantern => .lantern, .soul_lantern => .soul_lantern, .torch => .torch,
            .soul_torch => .soul_torch, .redstone_torch_lit => .redstone_torch,
            .jack_o_lantern => .jack_o_lantern, .sea_lantern => .sea_lantern, .end_rod => .end_rod,
        };
    }
};

pub const LanternMountMode = enum {
    standing_on_floor,
    hanging_from_ceiling,
};

pub const LanternSupport = enum {
    solid_bottom_face,
    fence_post,
    iron_bars,
    vertical_chain,
    none,

    pub fn isValid(self: LanternSupport) bool {
        return self != .none;
    }
};

pub const LanternState = struct {
    kind: LightFixtureKind,
    mount_mode: LanternMountMode,
    support: LanternSupport,
    support_intact: bool = true,

    pub fn init(kind: LightFixtureKind, mode: LanternMountMode, support: LanternSupport) ?LanternState {
        if (!support.isValid()) return null;
        if (mode == .hanging_from_ceiling and support == .solid_bottom_face) {
            return .{ .kind = kind, .mount_mode = mode, .support = support };
        }
        if (mode == .standing_on_floor and support == .solid_bottom_face) {
            return .{ .kind = kind, .mount_mode = mode, .support = support };
        }
        if (mode == .hanging_from_ceiling and (support == .fence_post or support == .iron_bars or support == .vertical_chain)) {
            return .{ .kind = kind, .mount_mode = mode, .support = support };
        }
        return null;
    }

    pub fn onSupportBroken(self: *LanternState) bool {
        if (!self.support_intact) return false;
        self.support_intact = false;
        return true;
    }

    pub fn dropsAsItem(self: LanternState) bool {
        return !self.support_intact;
    }
};

pub const ChainAxis = enum { x, y, z };

pub const ChainBlock = struct {
    axis: ChainAxis = .y,
    waterlogged: bool = false,

    pub const recipe = CraftingRecipe{
        .output = .chain,
        .output_count = 1,
        .ingredients = .{
            .{ .item = .iron_ingot, .count = 1 },
            .{ .item = .iron_nugget, .count = 2 },
            .{ .item = .iron_nugget, .count = 0 },
        },
        .ingredient_count = 2,
    };

    pub fn init(axis: ChainAxis, waterlogged: bool) ChainBlock {
        return .{ .axis = axis, .waterlogged = waterlogged };
    }

    pub fn canPistonMove(self: ChainBlock, lantern: ?LanternState) bool {
        _ = self;
        return lantern == null or lantern.?.support == .vertical_chain;
    }

    pub fn pistonMovePreservesLantern(self: ChainBlock, lantern: LanternState) bool {
        return self.canPistonMove(lantern);
    }
};

test "lantern recipe and light spectrum" {
    const recipe = LightFixtureKind.lantern.recipe();
    try std.testing.expectEqual(@as(u8, 1), recipe.ingredient(.torch));
    try std.testing.expectEqual(@as(u8, 8), recipe.ingredient(.iron_nugget));
    try std.testing.expectEqual(@as(u8, 15), LightFixtureKind.lantern.lightLevel());
    try std.testing.expect(LightFixtureKind.lantern.meltsSnowAndIce());
}

test "soul lantern is dim, repels piglins, and does not melt" {
    try std.testing.expectEqual(@as(u8, 10), LightFixtureKind.soul_lantern.lightLevel());
    try std.testing.expect(LightFixtureKind.soul_lantern.repelsPiglins());
    try std.testing.expectEqual(@as(u8, 8), LightFixtureKind.soul_lantern.piglinRepelRadius());
    try std.testing.expect(!LightFixtureKind.soul_lantern.meltsSnowAndIce());
}

test "torch spectrum and water behavior" {
    try std.testing.expectEqual(@as(u8, 14), LightFixtureKind.torch.lightLevel());
    try std.testing.expect(LightFixtureKind.torch.washedAwayByWater());
    try std.testing.expect(!LightFixtureKind.torch.canPlaceUnderwater());
}

test "soul torch has soul behavior" {
    try std.testing.expect(LightFixtureKind.soul_torch.repelsPiglins());
    try std.testing.expect(!LightFixtureKind.soul_torch.meltsSnowAndIce());
    try std.testing.expectEqual(@as(u8, 10), LightFixtureKind.soul_torch.lightLevel());
}

test "redstone torch emits seven and is not a heat source" {
    try std.testing.expectEqual(@as(u8, 7), LightFixtureKind.redstone_torch_lit.lightLevel());
    try std.testing.expect(!LightFixtureKind.redstone_torch_lit.meltsSnowAndIce());
    try std.testing.expect(LightFixtureKind.redstone_torch_lit.preventsMobSpawning(1));
}

test "jack o lantern recipe and underwater placement" {
    const recipe = LightFixtureKind.jack_o_lantern.recipe();
    try std.testing.expectEqual(@as(u8, 1), recipe.ingredient(.carved_pumpkin));
    try std.testing.expectEqual(@as(u8, 1), recipe.ingredient(.torch));
    try std.testing.expect(LightFixtureKind.jack_o_lantern.canPlaceUnderwater());
}

test "sea lantern recipe and drops" {
    const recipe = LightFixtureKind.sea_lantern.recipe();
    try std.testing.expectEqual(@as(u8, 4), recipe.ingredient(.prismarine_shard));
    try std.testing.expectEqual(@as(u8, 5), recipe.ingredient(.prismarine_crystal));
    try std.testing.expectEqual(@as(u8, 2), LightFixtureKind.sea_lantern.seaLanternDrops(false, 0));
    try std.testing.expectEqual(@as(u8, 3), LightFixtureKind.sea_lantern.seaLanternDrops(false, 2));
    try std.testing.expectEqual(@as(u8, 5), LightFixtureKind.sea_lantern.seaLanternDrops(false, 3));
}

test "silk touch preserves sea lantern" {
    try std.testing.expectEqual(@as(u8, 1), LightFixtureKind.sea_lantern.seaLanternDrops(true, 0));
}

test "end rod recipe, collision, and six-face placement" {
    const recipe = LightFixtureKind.end_rod.recipe();
    try std.testing.expectEqual(@as(u8, 4), recipe.output_count);
    try std.testing.expectEqual(@as(u8, 1), recipe.ingredient(.blaze_rod));
    try std.testing.expect(LightFixtureKind.end_rod.hasSolidCollision());
    try std.testing.expect(LightFixtureKind.end_rod.supportsAllFaces());
}

test "standing lantern accepts floor support" {
    const lantern = LanternState.init(.lantern, .standing_on_floor, .solid_bottom_face);
    try std.testing.expect(lantern != null);
    try std.testing.expectEqual(LanternMountMode.standing_on_floor, lantern.?.mount_mode);
}

test "hanging lantern accepts chain and narrow supports" {
    try std.testing.expect(LanternState.init(.lantern, .hanging_from_ceiling, .vertical_chain) != null);
    try std.testing.expect(LanternState.init(.lantern, .hanging_from_ceiling, .fence_post) != null);
    try std.testing.expect(LanternState.init(.lantern, .hanging_from_ceiling, .iron_bars) != null);
}

test "invalid support cannot place lantern" {
    try std.testing.expect(LanternState.init(.lantern, .hanging_from_ceiling, .none) == null);
}

test "broken support makes lantern drop" {
    var lantern = LanternState.init(.lantern, .hanging_from_ceiling, .vertical_chain).?;
    try std.testing.expect(!lantern.dropsAsItem());
    try std.testing.expect(lantern.onSupportBroken());
    try std.testing.expect(lantern.dropsAsItem());
    try std.testing.expect(!lantern.onSupportBroken());
}

test "chain recipe and all axis orientations" {
    try std.testing.expectEqual(@as(u8, 1), ChainBlock.recipe.ingredient(.iron_ingot));
    try std.testing.expectEqual(@as(u8, 2), ChainBlock.recipe.ingredient(.iron_nugget));
    try std.testing.expectEqual(ChainAxis.x, ChainBlock.init(.x, false).axis);
    try std.testing.expectEqual(ChainAxis.y, ChainBlock.init(.y, true).axis);
    try std.testing.expectEqual(ChainAxis.z, ChainBlock.init(.z, false).axis);
}

test "waterlogged chain conducts piston movement with hanging lantern" {
    const chain = ChainBlock.init(.y, true);
    const lantern = LanternState.init(.lantern, .hanging_from_ceiling, .vertical_chain).?;
    try std.testing.expect(chain.canPistonMove(lantern));
    try std.testing.expect(chain.pistonMovePreservesLantern(lantern));
}

test "light levels provide deterministic mob threshold checks" {
    try std.testing.expect(LightFixtureKind.redstone_torch_lit.preventsMobSpawning(7));
    try std.testing.expect(!LightFixtureKind.redstone_torch_lit.preventsMobSpawning(8));
    try std.testing.expect(LightFixtureKind.sea_lantern.preventsMobSpawning(15));
}
