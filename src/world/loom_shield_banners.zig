const std = @import("std");

pub const DyeColor = enum(u4) { white, orange, magenta, light_blue, yellow, lime, pink, gray, light_gray, cyan, purple, blue, brown, green, red, black };

pub const Recipe = struct {
    string_count: u8 = 0,
    wood_planks_count: u8 = 0,
    wool_count: u8 = 0,
    stick_count: u8 = 0,
    output_count: u8 = 1,
    output_name: []const u8,
    stack_limit: u8,
};

pub const LoomAndBannerRecipes = struct {
    pub const loom = Recipe{ .string_count = 2, .wood_planks_count = 2, .output_name = "loom", .stack_limit = 64 };
    pub const banner = Recipe{ .wool_count = 6, .stick_count = 1, .output_name = "banner", .stack_limit = 16 };
    pub fn loomRecipe() Recipe {
        return loom;
    }
    pub fn bannerRecipe() Recipe {
        return banner;
    }
    pub fn hasMatchingWoolColor(_: DyeColor, wool_count: u8, stick_count: u8) bool {
        return wool_count == banner.wool_count and stick_count == banner.stick_count;
    }
};

pub const BannerPattern = enum(u8) {
    border,
    bricks,
    circle,
    cross,
    curly_border,
    diagonal_left,
    diagonal_right,
    gradient,
    half_horizontal,
    half_vertical,
    rhombus,
    stripe_bottom,
    stripe_center,
    stripe_downleft,
    stripe_downright,
    stripe_middle,
    stripe_top,
    triangle_bottom,
    triangle_top,
    flower_charge,
    creeper_charge,
    skull_charge,
    thing_mojang,
    globe,
    snout,
    flow,
    guster,
};

pub const BannerPatternItem = enum(u8) {
    oxeye_daisy,
    creeper_head,
    wither_skeleton_skull,
    enchanted_golden_apple,
    cartographer_globe,
    bastion_snout,
    trial_flow,
    trial_guster,
    pub fn pattern(self: BannerPatternItem) BannerPattern {
        return switch (self) {
            .oxeye_daisy => .flower_charge,
            .creeper_head => .creeper_charge,
            .wither_skeleton_skull => .skull_charge,
            .enchanted_golden_apple => .thing_mojang,
            .cartographer_globe => .globe,
            .bastion_snout => .snout,
            .trial_flow => .flow,
            .trial_guster => .guster,
        };
    }
};

pub const LoomPatternStencil = struct {
    pub fn requiresReusableStencil(pattern: BannerPattern) bool {
        return switch (pattern) {
            .flower_charge, .creeper_charge, .skull_charge, .thing_mojang, .globe, .snout, .flow, .guster => true,
            else => false,
        };
    }
    pub fn isBannerPatternItemConsumedInLoom(_: BannerPatternItem) bool {
        return false;
    }
    pub fn stencilFor(pattern: BannerPattern) ?BannerPatternItem {
        return switch (pattern) {
            .flower_charge => .oxeye_daisy,
            .creeper_charge => .creeper_head,
            .skull_charge => .wither_skeleton_skull,
            .thing_mojang => .enchanted_golden_apple,
            .globe => .cartographer_globe,
            .snout => .bastion_snout,
            .flow => .trial_flow,
            .guster => .trial_guster,
            else => null,
        };
    }
    pub fn canApply(pattern: BannerPattern, stencil: ?BannerPatternItem) bool {
        if (stencil) |item| return item.pattern() == pattern;
        return !requiresReusableStencil(pattern);
    }
};

pub const BannerLayer = struct { pattern: BannerPattern, color: DyeColor };

pub const Banner = struct {
    base_color: DyeColor,
    layers: [6]BannerLayer = undefined,
    layer_count: u4 = 0,
    present: bool = true,
    pub fn init(base_color: DyeColor) Banner {
        return .{ .base_color = base_color };
    }
    pub fn addLayer(self: *Banner, layer: BannerLayer) bool {
        if (!SixLayerSurvivalLimit.canAddLayerInLoom(self.layer_count)) return false;
        self.layers[self.layer_count] = layer;
        self.layer_count += 1;
        return true;
    }
};

pub const SixLayerSurvivalLimit = struct {
    pub const max_loom_layers: u4 = 6;
    pub fn canAddLayerInLoom(current_layers: u4) bool {
        return current_layers < max_loom_layers;
    }
    pub fn washTopBannerLayer(banner: *Banner) bool {
        if (banner.layer_count == 0) return false;
        banner.layer_count -= 1;
        return true;
    }
};

pub const BannerCloningRule = struct {
    pub fn canCloneBanner(source_base_color: DyeColor, blank_base_color: DyeColor, blank_layers: u4, source_layers: u4) bool {
        return source_base_color == blank_base_color and blank_layers == 0 and source_layers >= 1 and source_layers <= SixLayerSurvivalLimit.max_loom_layers;
    }
    pub fn clone(source: *const Banner, blank: *Banner) bool {
        if (!canCloneBanner(source.base_color, blank.base_color, blank.layer_count, source.layer_count)) return false;
        blank.layers = source.layers;
        blank.layer_count = source.layer_count;
        return true;
    }
};

pub const Shield = struct {
    patterned: bool = false,
    base_color: ?DyeColor = null,
    layers: [6]BannerLayer = undefined,
    layer_count: u4 = 0,
    heraldry_resolution_divisor: u8 = 2,
};

pub const ShieldHeraldryTransfer = struct {
    pub fn applyBannerToShield(shield: *Shield, banner: *Banner) bool {
        if (shield.patterned or !banner.present or banner.layer_count > SixLayerSurvivalLimit.max_loom_layers) return false;
        shield.patterned = true;
        shield.base_color = banner.base_color;
        shield.layers = banner.layers;
        shield.layer_count = banner.layer_count;
        banner.present = false;
        return true;
    }
};

test "loom recipe uses two string and two planks" {
    const recipe = LoomAndBannerRecipes.loomRecipe();
    try std.testing.expectEqual(@as(u8, 2), recipe.string_count);
    try std.testing.expectEqual(@as(u8, 2), recipe.wood_planks_count);
    try std.testing.expectEqualStrings("loom", recipe.output_name);
}

test "banner recipe is six wool and one stick with sixteen stack" {
    const recipe = LoomAndBannerRecipes.bannerRecipe();
    try std.testing.expectEqual(@as(u8, 6), recipe.wool_count);
    try std.testing.expectEqual(@as(u8, 1), recipe.stick_count);
    try std.testing.expectEqual(@as(u8, 16), recipe.stack_limit);
}

test "matching wool recipe accepts six wool" {
    try std.testing.expect(LoomAndBannerRecipes.hasMatchingWoolColor(.blue, 6, 1));
    try std.testing.expect(!LoomAndBannerRecipes.hasMatchingWoolColor(.blue, 5, 1));
}

test "standard loom patterns need no stencil" {
    try std.testing.expect(!LoomPatternStencil.requiresReusableStencil(.border));
    try std.testing.expect(LoomPatternStencil.canApply(.border, null));
}

test "all eight special patterns map to reusable items" {
    const patterns = [_]BannerPattern{ .flower_charge, .creeper_charge, .skull_charge, .thing_mojang, .globe, .snout, .flow, .guster };
    for (patterns) |pattern| {
        try std.testing.expect(LoomPatternStencil.requiresReusableStencil(pattern));
        try std.testing.expect(LoomPatternStencil.stencilFor(pattern) != null);
    }
}

test "special stencil must match requested pattern" {
    try std.testing.expect(LoomPatternStencil.canApply(.flower_charge, .oxeye_daisy));
    try std.testing.expect(!LoomPatternStencil.canApply(.flower_charge, .creeper_head));
}

test "loom stencil is never consumed" {
    inline for (@typeInfo(BannerPatternItem).@"enum".fields) |field| {
        const item: BannerPatternItem = @enumFromInt(field.value);
        try std.testing.expect(!LoomPatternStencil.isBannerPatternItemConsumedInLoom(item));
    }
}

test "survival loom allows exactly six layers" {
    var banner = Banner.init(.white);
    for (0..6) |_| try std.testing.expect(banner.addLayer(.{ .pattern = .border, .color = .red }));
    try std.testing.expectEqual(@as(u4, 6), banner.layer_count);
    try std.testing.expect(!banner.addLayer(.{ .pattern = .cross, .color = .blue }));
}

test "water cauldron washes only the top layer" {
    var banner = Banner.init(.white);
    _ = banner.addLayer(.{ .pattern = .border, .color = .red });
    _ = banner.addLayer(.{ .pattern = .circle, .color = .blue });
    try std.testing.expect(SixLayerSurvivalLimit.washTopBannerLayer(&banner));
    try std.testing.expectEqual(@as(u4, 1), banner.layer_count);
    try std.testing.expectEqual(BannerPattern.border, banner.layers[0].pattern);
}

test "washing blank banner is a no-op" {
    var banner = Banner.init(.black);
    try std.testing.expect(!SixLayerSurvivalLimit.washTopBannerLayer(&banner));
}

test "cloning requires same color and blank target" {
    try std.testing.expect(BannerCloningRule.canCloneBanner(.red, .red, 0, 1));
    try std.testing.expect(!BannerCloningRule.canCloneBanner(.red, .blue, 0, 1));
    try std.testing.expect(!BannerCloningRule.canCloneBanner(.red, .red, 1, 1));
}

test "cloning copies complete pattern stack" {
    var source = Banner.init(.green);
    _ = source.addLayer(.{ .pattern = .gradient, .color = .yellow });
    _ = source.addLayer(.{ .pattern = .snout, .color = .black });
    var blank = Banner.init(.green);
    try std.testing.expect(BannerCloningRule.clone(&source, &blank));
    try std.testing.expectEqual(@as(u4, 2), blank.layer_count);
    try std.testing.expectEqual(BannerPattern.snout, blank.layers[1].pattern);
}

test "shield transfer applies heraldry at half resolution and consumes banner" {
    var banner = Banner.init(.blue);
    _ = banner.addLayer(.{ .pattern = .cross, .color = .white });
    var shield = Shield{};
    try std.testing.expect(ShieldHeraldryTransfer.applyBannerToShield(&shield, &banner));
    try std.testing.expect(shield.patterned);
    try std.testing.expectEqual(DyeColor.blue, shield.base_color.?);
    try std.testing.expectEqual(@as(u4, 1), shield.layer_count);
    try std.testing.expectEqual(@as(u8, 2), shield.heraldry_resolution_divisor);
    try std.testing.expect(!banner.present);
}

test "shield cannot receive a second banner" {
    var banner = Banner.init(.white);
    var shield = Shield{};
    try std.testing.expect(ShieldHeraldryTransfer.applyBannerToShield(&shield, &banner));
    var second = Banner.init(.red);
    try std.testing.expect(!ShieldHeraldryTransfer.applyBannerToShield(&shield, &second));
    try std.testing.expect(second.present);
}

test "shield transfer rejects already consumed banner" {
    var banner = Banner.init(.white);
    banner.present = false;
    var shield = Shield{};
    try std.testing.expect(!ShieldHeraldryTransfer.applyBannerToShield(&shield, &banner));
}
