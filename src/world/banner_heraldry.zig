const std = @import("std");

/// The 16 canonical Minecraft dye colors (0..15).
pub const DyeColor = enum(u4) {
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

    pub fn name(self: DyeColor) []const u8 {
        return switch (self) {
            .white => "White",
            .orange => "Orange",
            .magenta => "Magenta",
            .light_blue => "Light Blue",
            .yellow => "Yellow",
            .lime => "Lime",
            .pink => "Pink",
            .gray => "Gray",
            .light_gray => "Light Gray",
            .cyan => "Cyan",
            .purple => "Purple",
            .blue => "Blue",
            .brown => "Brown",
            .green => "Green",
            .red => "Red",
            .black => "Black",
        };
    }
};

/// All 28 Banner Pattern designs:
/// - 1 solid background base
/// - 19 standard Loom patterns selectable directly without stencil items
/// - 8 special stencil patterns requiring dedicated Banner Pattern items
pub const BannerPattern = enum(u8) {
    base_solid = 0,
    border = 1,
    bricks = 2,
    circle = 3,
    cross = 4,
    curly_border = 5,
    diagonal_left = 6,
    diagonal_right = 7,
    gradient = 8,
    half_horizontal = 9,
    half_vertical = 10,
    rhombus = 11,
    stripe_bottom = 12,
    stripe_center = 13,
    stripe_downleft = 14,
    stripe_downright = 15,
    stripe_middle = 16,
    stripe_top = 17,
    triangle_bottom = 18,
    triangle_top = 19,
    creeper = 20,
    skull = 21,
    flower = 22,
    thing = 23,
    globe = 24,
    snout = 25,
    flow = 26,
    guster = 27,

    /// Helper returning true if this pattern requires a dedicated Banner Pattern stencil item.
    pub fn requiresStencilItem(self: BannerPattern) bool {
        return switch (self) {
            .creeper, .skull, .flower, .thing, .globe, .snout, .flow, .guster => true,
            else => false,
        };
    }

    /// Minecraft canonical 2-3 letter pattern abbreviation code (used in NBT / packet data).
    pub fn code(self: BannerPattern) []const u8 {
        return switch (self) {
            .base_solid => "b",
            .border => "bo",
            .bricks => "bri",
            .circle => "mc",
            .cross => "cr",
            .curly_border => "cbo",
            .diagonal_left => "ld",
            .diagonal_right => "rud",
            .gradient => "gra",
            .half_horizontal => "hh",
            .half_vertical => "vh",
            .rhombus => "mr",
            .stripe_bottom => "bs",
            .stripe_center => "cs",
            .stripe_downleft => "dls",
            .stripe_downright => "drs",
            .stripe_middle => "ms",
            .stripe_top => "ts",
            .triangle_bottom => "bt",
            .triangle_top => "tt",
            .creeper => "cre",
            .skull => "sku",
            .flower => "flo",
            .thing => "moj",
            .globe => "glb",
            .snout => "pig",
            .flow => "flw",
            .guster => "gus",
        };
    }

    /// Human-readable pattern name.
    pub fn name(self: BannerPattern) []const u8 {
        return switch (self) {
            .base_solid => "Base",
            .border => "Bordure",
            .bricks => "Field Masoned",
            .circle => "Roundel",
            .cross => "Saltire",
            .curly_border => "Bordure Indented",
            .diagonal_left => "Per Bend Sinister",
            .diagonal_right => "Per Bend",
            .gradient => "Gradient",
            .half_horizontal => "Per Fess",
            .half_vertical => "Per Pale",
            .rhombus => "Lozenge",
            .stripe_bottom => "Base Fess",
            .stripe_center => "Pale",
            .stripe_downleft => "Bend Sinister",
            .stripe_downright => "Bend",
            .stripe_middle => "Fess",
            .stripe_top => "Chief",
            .triangle_bottom => "Chevron",
            .triangle_top => "Inverted Chevron",
            .creeper => "Creeper Charge",
            .skull => "Skull Charge",
            .flower => "Flower Charge",
            .thing => "Thing",
            .globe => "Globe",
            .snout => "Snout",
            .flow => "Flow",
            .guster => "Guster",
        };
    }

    /// Returns the name of the required stencil item if applicable, or null for standard patterns.
    pub fn stencilItemName(self: BannerPattern) ?[]const u8 {
        return switch (self) {
            .creeper => "Creeper Charge Banner Pattern",
            .skull => "Skull Charge Banner Pattern",
            .flower => "Flower Charge Banner Pattern",
            .thing => "Thing Banner Pattern",
            .globe => "Globe Banner Pattern",
            .snout => "Snout Banner Pattern",
            .flow => "Flow Banner Pattern",
            .guster => "Guster Banner Pattern",
            else => null,
        };
    }
};

/// Dedicated Banner Pattern stencil items used in the Loom.
pub const StencilItem = enum(u8) {
    creeper_charge = 0,
    skull_charge = 1,
    flower_charge = 2,
    thing = 3,
    globe = 4,
    snout = 5,
    flow = 6,
    guster = 7,

    pub fn toPattern(self: StencilItem) BannerPattern {
        return switch (self) {
            .creeper_charge => .creeper,
            .skull_charge => .skull,
            .flower_charge => .flower,
            .thing => .thing,
            .globe => .globe,
            .snout => .snout,
            .flow => .flow,
            .guster => .guster,
        };
    }

    pub fn fromPattern(pattern: BannerPattern) ?StencilItem {
        return switch (pattern) {
            .creeper => .creeper_charge,
            .skull => .skull_charge,
            .flower => .flower_charge,
            .thing => .thing,
            .globe => .globe,
            .snout => .snout,
            .flow => .flow,
            .guster => .guster,
            else => null,
        };
    }

    pub fn name(self: StencilItem) []const u8 {
        return switch (self) {
            .creeper_charge => "Creeper Charge Banner Pattern",
            .skull_charge => "Skull Charge Banner Pattern",
            .flower_charge => "Flower Charge Banner Pattern",
            .thing => "Thing Banner Pattern",
            .globe => "Globe Banner Pattern",
            .snout => "Snout Banner Pattern",
            .flow => "Flow Banner Pattern",
            .guster => "Guster Banner Pattern",
        };
    }
};

/// A single dyed pattern layer on a banner.
pub const BannerLayer = struct {
    pattern: BannerPattern = .base_solid,
    color: u4 = 0,
};

/// Maximum number of pattern layers that can be stacked in a Loom in survival mode.
pub const max_survival_loom_layers: u3 = 6;

/// Banner Heraldry representing the base color and up to 6 stacked pattern layers.
pub const BannerHeraldry = struct {
    base_color: u4,
    layers: [6]BannerLayer = [_]BannerLayer{.{ .pattern = .base_solid, .color = 0 }} ** 6,
    layer_count: u3 = 0,

    pub fn init(base_color: u4) BannerHeraldry {
        return .{
            .base_color = base_color,
            .layers = [_]BannerLayer{.{ .pattern = .base_solid, .color = 0 }} ** 6,
            .layer_count = 0,
        };
    }

    pub fn getLayers(self: *const BannerHeraldry) []const BannerLayer {
        return self.layers[0..self.layer_count];
    }

    pub fn isFull(self: BannerHeraldry) bool {
        return self.layer_count >= max_survival_loom_layers;
    }

    pub fn isEmpty(self: BannerHeraldry) bool {
        return self.layer_count == 0;
    }

    pub fn clearLayers(self: *BannerHeraldry) void {
        self.layers = [_]BannerLayer{.{ .pattern = .base_solid, .color = 0 }} ** 6;
        self.layer_count = 0;
    }

    pub fn eql(self: BannerHeraldry, other: BannerHeraldry) bool {
        if (self.base_color != other.base_color) return false;
        if (self.layer_count != other.layer_count) return false;
        var i: usize = 0;
        while (i < self.layer_count) : (i += 1) {
            if (self.layers[i].pattern != other.layers[i].pattern or
                self.layers[i].color != other.layers[i].color)
            {
                return false;
            }
        }
        return true;
    }

    pub fn applyLoomLayer(self: *BannerHeraldry, pattern: BannerPattern, dye_color: u4, has_required_stencil: bool) bool {
        if (self.layer_count >= max_survival_loom_layers) {
            return false;
        }
        if (pattern.requiresStencilItem() and !has_required_stencil) {
            return false;
        }
        self.layers[self.layer_count] = .{
            .pattern = pattern,
            .color = dye_color,
        };
        self.layer_count += 1;
        return true;
    }

    pub fn washTopBannerLayer(self: *BannerHeraldry, cauldron_water_level: *u2) bool {
        if (self.layer_count == 0) {
            return false;
        }
        if (cauldron_water_level.* == 0) {
            return false;
        }
        self.layer_count -= 1;
        self.layers[self.layer_count] = .{
            .pattern = .base_solid,
            .color = 0,
        };
        cauldron_water_level.* -= 1;
        return true;
    }

    pub fn duplicate(self: BannerHeraldry, blank_target_color: u4) ?BannerHeraldry {
        return duplicateBanner(self, blank_target_color);
    }

    pub fn applyToShield(self: BannerHeraldry, shield_has_coat_of_arms: bool) ?BannerHeraldry {
        return applyBannerToShield(self, shield_has_coat_of_arms);
    }
};

/// Adds a layer in the Loom if layer_count < 6 and stencil requirements are satisfied.
pub fn applyLoomLayer(
    banner: *BannerHeraldry,
    pattern: BannerPattern,
    dye_color: u4,
    has_required_stencil: bool,
) bool {
    return banner.applyLoomLayer(pattern, dye_color, has_required_stencil);
}

/// Using a Banner on a water-filled Cauldron washes off the topmost dyed pattern layer
/// and consumes 1 water level (1..3). Returns false if cauldron is empty or banner has no layers.
pub fn washTopBannerLayer(
    banner: *BannerHeraldry,
    cauldron_water_level: *u2,
) bool {
    return banner.washTopBannerLayer(cauldron_water_level);
}

/// Crafting a patterned banner with a blank banner of the exact same base_color
/// duplicates all layers onto the second banner. Returns null if colors mismatch or source has no layers.
pub fn duplicateBanner(
    source: BannerHeraldry,
    blank_target_color: u4,
) ?BannerHeraldry {
    if (source.base_color != blank_target_color) {
        return null;
    }
    if (source.layer_count == 0) {
        return null;
    }
    return BannerHeraldry{
        .base_color = source.base_color,
        .layers = source.layers,
        .layer_count = source.layer_count,
    };
}

/// Transfers the 6-layer coat-of-arms onto a Shield.
/// Returns null if the shield already has a coat-of-arms.
pub fn applyBannerToShield(
    banner: BannerHeraldry,
    shield_has_coat_of_arms: bool,
) ?BannerHeraldry {
    if (shield_has_coat_of_arms) {
        return null;
    }
    return BannerHeraldry{
        .base_color = banner.base_color,
        .layers = banner.layers,
        .layer_count = banner.layer_count,
    };
}

/// Helper representation for a Shield item with an optional heraldic coat-of-arms.
pub const Shield = struct {
    coat_of_arms: ?BannerHeraldry = null,

    pub fn hasCoatOfArms(self: Shield) bool {
        return self.coat_of_arms != null;
    }

    pub fn applyBanner(self: *Shield, banner: BannerHeraldry) bool {
        if (applyBannerToShield(banner, self.hasCoatOfArms())) |heraldry| {
            self.coat_of_arms = heraldry;
            return true;
        }
        return false;
    }
};

// ============================================================================
// UNIT TESTS
// ============================================================================

test "1: BannerPattern enum all 28 variants, names, and pattern codes" {
    const patterns = [_]BannerPattern{
        .base_solid,
        .border,
        .bricks,
        .circle,
        .cross,
        .curly_border,
        .diagonal_left,
        .diagonal_right,
        .gradient,
        .half_horizontal,
        .half_vertical,
        .rhombus,
        .stripe_bottom,
        .stripe_center,
        .stripe_downleft,
        .stripe_downright,
        .stripe_middle,
        .stripe_top,
        .triangle_bottom,
        .triangle_top,
        .creeper,
        .skull,
        .flower,
        .thing,
        .globe,
        .snout,
        .flow,
        .guster,
    };
    try std.testing.expectEqual(@as(usize, 28), patterns.len);

    for (patterns) |pat| {
        try std.testing.expect(pat.name().len > 0);
        try std.testing.expect(pat.code().len > 0);
    }
}

test "2: Special stencil patterns require stencil item (Globe, Snout, Flow, Guster, Thing, Skull, Creeper, Flower)" {
    const stencil_patterns = [_]BannerPattern{
        .globe,
        .snout,
        .flow,
        .guster,
        .thing,
        .skull,
        .creeper,
        .flower,
    };

    for (stencil_patterns) |pat| {
        try std.testing.expect(pat.requiresStencilItem());
        try std.testing.expect(pat.stencilItemName() != null);
    }
}

test "3: Standard Loom patterns do not require stencil item" {
    const standard_patterns = [_]BannerPattern{
        .base_solid,
        .border,
        .bricks,
        .circle,
        .cross,
        .curly_border,
        .diagonal_left,
        .diagonal_right,
        .gradient,
        .half_horizontal,
        .half_vertical,
        .rhombus,
        .stripe_bottom,
        .stripe_center,
        .stripe_downleft,
        .stripe_downright,
        .stripe_middle,
        .stripe_top,
        .triangle_bottom,
        .triangle_top,
    };

    for (standard_patterns) |pat| {
        try std.testing.expect(!pat.requiresStencilItem());
        try std.testing.expect(pat.stencilItemName() == null);
    }
}

test "4: StencilItem enum mapping and bidirectional conversion" {
    const stencils = [_]StencilItem{
        .creeper_charge,
        .skull_charge,
        .flower_charge,
        .thing,
        .globe,
        .snout,
        .flow,
        .guster,
    };

    for (stencils) |item| {
        const pat = item.toPattern();
        try std.testing.expect(pat.requiresStencilItem());
        try std.testing.expectEqual(item, StencilItem.fromPattern(pat).?);
        try std.testing.expect(item.name().len > 0);
    }

    // Standard pattern returns null for StencilItem
    try std.testing.expect(StencilItem.fromPattern(.border) == null);
    try std.testing.expect(StencilItem.fromPattern(.cross) == null);
}

test "5: BannerHeraldry initialization and empty state" {
    const banner = BannerHeraldry.init(14); // Red base
    try std.testing.expectEqual(@as(u4, 14), banner.base_color);
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);
    try std.testing.expect(banner.isEmpty());
    try std.testing.expect(!banner.isFull());
    try std.testing.expectEqual(@as(usize, 0), banner.getLayers().len);
}

test "6: Loom layer application for standard pattern without stencil item succeeds" {
    var banner = BannerHeraldry.init(0); // White base

    // Applying stripe_center with yellow dye (4), no stencil required
    const ok = banner.applyLoomLayer(.stripe_center, 4, false);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u3, 1), banner.layer_count);
    try std.testing.expect(!banner.isEmpty());

    const layers = banner.getLayers();
    try std.testing.expectEqual(@as(usize, 1), layers.len);
    try std.testing.expectEqual(BannerPattern.stripe_center, layers[0].pattern);
    try std.testing.expectEqual(@as(u4, 4), layers[0].color);
}

test "7: Loom layer application rejects special stencil pattern when has_required_stencil is false" {
    var banner = BannerHeraldry.init(15); // Black base

    // Snout requires stencil
    try std.testing.expect(!banner.applyLoomLayer(.snout, 1, false));
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);

    // Flow requires stencil
    try std.testing.expect(!banner.applyLoomLayer(.flow, 9, false));
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);

    // Guster requires stencil
    try std.testing.expect(!banner.applyLoomLayer(.guster, 3, false));
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);

    // Thing requires stencil
    try std.testing.expect(!banner.applyLoomLayer(.thing, 14, false));
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);

    // Globe requires stencil
    try std.testing.expect(!banner.applyLoomLayer(.globe, 11, false));
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);

    // Skull requires stencil
    try std.testing.expect(!banner.applyLoomLayer(.skull, 0, false));
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);
}

test "8: Loom layer application succeeds for special stencil patterns when has_required_stencil is true" {
    var banner = BannerHeraldry.init(11); // Blue base

    // Add Globe pattern with white dye and stencil
    try std.testing.expect(banner.applyLoomLayer(.globe, 0, true));
    try std.testing.expectEqual(@as(u3, 1), banner.layer_count);
    try std.testing.expectEqual(BannerPattern.globe, banner.layers[0].pattern);
    try std.testing.expectEqual(@as(u4, 0), banner.layers[0].color);

    // Add Snout pattern with orange dye and stencil
    try std.testing.expect(banner.applyLoomLayer(.snout, 1, true));
    try std.testing.expectEqual(@as(u3, 2), banner.layer_count);
    try std.testing.expectEqual(BannerPattern.snout, banner.layers[1].pattern);
    try std.testing.expectEqual(@as(u4, 1), banner.layers[1].color);
}

test "9: Loom 6-layer maximum stacking limit strictly enforced" {
    var banner = BannerHeraldry.init(1); // Orange base

    // Apply 6 layers
    try std.testing.expect(banner.applyLoomLayer(.circle, 0, false)); // 1
    try std.testing.expect(banner.applyLoomLayer(.cross, 14, false));  // 2
    try std.testing.expect(banner.applyLoomLayer(.border, 15, false)); // 3
    try std.testing.expect(banner.applyLoomLayer(.gradient, 4, false)); // 4
    try std.testing.expect(banner.applyLoomLayer(.rhombus, 11, false)); // 5
    try std.testing.expect(banner.applyLoomLayer(.flow, 9, true));      // 6

    try std.testing.expectEqual(@as(u3, 6), banner.layer_count);
    try std.testing.expect(banner.isFull());

    // 7th layer must be rejected!
    const rejected_regular = banner.applyLoomLayer(.stripe_top, 2, false);
    try std.testing.expect(!rejected_regular);

    const rejected_stencil = banner.applyLoomLayer(.guster, 3, true);
    try std.testing.expect(!rejected_stencil);

    try std.testing.expectEqual(@as(u3, 6), banner.layer_count);
}

test "10: Cauldron wash single layer decreases layer count and consumes 1 water level" {
    var banner = BannerHeraldry.init(4); // Yellow base
    _ = banner.applyLoomLayer(.circle, 14, false); // Red circle

    var water_level: u2 = 3; // Full cauldron
    const washed = banner.washTopBannerLayer(&water_level);

    try std.testing.expect(washed);
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);
    try std.testing.expect(banner.isEmpty());
    try std.testing.expectEqual(@as(u2, 2), water_level); // Consumed 1 level
}

test "11: Cauldron wash sequential layers until banner is blank" {
    var banner = BannerHeraldry.init(0); // White base
    _ = banner.applyLoomLayer(.stripe_top, 1, false);
    _ = banner.applyLoomLayer(.stripe_middle, 2, false);
    _ = banner.applyLoomLayer(.stripe_bottom, 3, false);
    try std.testing.expectEqual(@as(u3, 3), banner.layer_count);

    var water_level: u2 = 3;

    // Wash layer 3 (stripe_bottom)
    try std.testing.expect(banner.washTopBannerLayer(&water_level));
    try std.testing.expectEqual(@as(u3, 2), banner.layer_count);
    try std.testing.expectEqual(@as(u2, 2), water_level);
    try std.testing.expectEqual(BannerPattern.stripe_middle, banner.layers[1].pattern);

    // Wash layer 2 (stripe_middle)
    try std.testing.expect(banner.washTopBannerLayer(&water_level));
    try std.testing.expectEqual(@as(u3, 1), banner.layer_count);
    try std.testing.expectEqual(@as(u2, 1), water_level);
    try std.testing.expectEqual(BannerPattern.stripe_top, banner.layers[0].pattern);

    // Wash layer 1 (stripe_top)
    try std.testing.expect(banner.washTopBannerLayer(&water_level));
    try std.testing.expectEqual(@as(u3, 0), banner.layer_count);
    try std.testing.expectEqual(@as(u2, 0), water_level);
    try std.testing.expect(banner.isEmpty());

    // 4th wash fails because cauldron is empty (water_level == 0) and banner is empty
    try std.testing.expect(!banner.washTopBannerLayer(&water_level));
}

test "12: Cauldron wash fails on empty cauldron (water level 0)" {
    var banner = BannerHeraldry.init(10); // Purple base
    _ = banner.applyLoomLayer(.triangle_top, 5, false);

    var empty_water: u2 = 0;
    try std.testing.expect(!banner.washTopBannerLayer(&empty_water));
    try std.testing.expectEqual(@as(u3, 1), banner.layer_count);
    try std.testing.expectEqual(@as(u2, 0), empty_water);
}

test "13: Cauldron wash fails on blank banner (layer count 0)" {
    var blank_banner = BannerHeraldry.init(2); // Magenta base

    var water_level: u2 = 3;
    try std.testing.expect(!blank_banner.washTopBannerLayer(&water_level));
    try std.testing.expectEqual(@as(u2, 3), water_level); // Water level unchanged!
}

test "14: Same-color banner duplication successfully copies all layers" {
    var source = BannerHeraldry.init(14); // Red base
    _ = source.applyLoomLayer(.rhombus, 0, false);
    _ = source.applyLoomLayer(.border, 15, false);
    _ = source.applyLoomLayer(.thing, 4, true);

    const target_color: u4 = 14; // Same red base
    const duplicate = duplicateBanner(source, target_color);

    try std.testing.expect(duplicate != null);
    const copy = duplicate.?;
    try std.testing.expectEqual(source.base_color, copy.base_color);
    try std.testing.expectEqual(source.layer_count, copy.layer_count);
    try std.testing.expect(source.eql(copy));
}

test "15: Banner duplication rejected for mismatched base colors" {
    var source = BannerHeraldry.init(14); // Red base
    _ = source.applyLoomLayer(.circle, 0, false);

    const mismatched_color: u4 = 11; // Blue base
    const duplicate = duplicateBanner(source, mismatched_color);
    try std.testing.expect(duplicate == null);
}

test "16: Banner duplication rejected for blank source banner (no patterns)" {
    const blank_source = BannerHeraldry.init(5); // Lime base, 0 layers
    const duplicate = duplicateBanner(blank_source, 5);
    try std.testing.expect(duplicate == null);
}

test "17: Shield coat-of-arms transfer succeeds on unpatterned shield" {
    var banner = BannerHeraldry.init(9); // Cyan base
    _ = banner.applyLoomLayer(.cross, 0, false);
    _ = banner.applyLoomLayer(.guster, 3, true);

    const shield_has_coat_of_arms = false;
    const result = applyBannerToShield(banner, shield_has_coat_of_arms);

    try std.testing.expect(result != null);
    const shield_heraldry = result.?;
    try std.testing.expectEqual(banner.base_color, shield_heraldry.base_color);
    try std.testing.expectEqual(banner.layer_count, shield_heraldry.layer_count);
    try std.testing.expect(banner.eql(shield_heraldry));
}

test "18: Shield coat-of-arms transfer rejected on shield with existing coat of arms" {
    var banner = BannerHeraldry.init(1); // Orange base
    _ = banner.applyLoomLayer(.bricks, 12, false);

    const shield_has_coat_of_arms = true;
    const result = applyBannerToShield(banner, shield_has_coat_of_arms);
    try std.testing.expect(result == null);
}

test "19: Shield coat-of-arms with full 6 layers preserved exactly" {
    var banner = BannerHeraldry.init(8); // Light gray base
    _ = banner.applyLoomLayer(.stripe_top, 0, false);
    _ = banner.applyLoomLayer(.stripe_center, 1, false);
    _ = banner.applyLoomLayer(.stripe_bottom, 2, false);
    _ = banner.applyLoomLayer(.border, 3, false);
    _ = banner.applyLoomLayer(.curly_border, 4, false);
    _ = banner.applyLoomLayer(.snout, 5, true);

    try std.testing.expectEqual(@as(u3, 6), banner.layer_count);

    const shield_heraldry = applyBannerToShield(banner, false).?;
    try std.testing.expectEqual(@as(u3, 6), shield_heraldry.layer_count);
    try std.testing.expect(banner.eql(shield_heraldry));
}

test "20: Shield struct helper wraps application lifecycle" {
    var shield = Shield{};
    try std.testing.expect(!shield.hasCoatOfArms());

    var banner = BannerHeraldry.init(14);
    _ = banner.applyLoomLayer(.flower, 4, true);

    // Apply banner to empty shield
    const ok1 = shield.applyBanner(banner);
    try std.testing.expect(ok1);
    try std.testing.expect(shield.hasCoatOfArms());
    try std.testing.expectEqual(banner.base_color, shield.coat_of_arms.?.base_color);

    // Apply banner to shield that already has coat of arms fails
    const second_banner = BannerHeraldry.init(0);
    const ok2 = shield.applyBanner(second_banner);
    try std.testing.expect(!ok2);
    // Heraldry remains the first banner's
    try std.testing.expectEqual(@as(u4, 14), shield.coat_of_arms.?.base_color);
}

test "21: All 16 dye colors properly represented in BannerLayer and DyeColor enum" {
    var c: u5 = 0;
    while (c < 16) : (c += 1) {
        const dye: DyeColor = @enumFromInt(@as(u4, @intCast(c)));
        try std.testing.expect(dye.name().len > 0);

        const layer = BannerLayer{
            .pattern = .circle,
            .color = @as(u4, @intCast(c)),
        };
        try std.testing.expectEqual(@as(u4, @intCast(c)), layer.color);
    }
}

test "22: BannerHeraldry equality helper behaves correctly" {
    var b1 = BannerHeraldry.init(0);
    _ = b1.applyLoomLayer(.border, 1, false);
    _ = b1.applyLoomLayer(.circle, 2, false);

    var b2 = BannerHeraldry.init(0);
    _ = b2.applyLoomLayer(.border, 1, false);
    _ = b2.applyLoomLayer(.circle, 2, false);

    try std.testing.expect(b1.eql(b2));

    // Change layer color
    var b3 = BannerHeraldry.init(0);
    _ = b3.applyLoomLayer(.border, 1, false);
    _ = b3.applyLoomLayer(.circle, 3, false); // different color
    try std.testing.expect(!b1.eql(b3));

    // Change base color
    var b4 = BannerHeraldry.init(1);
    _ = b4.applyLoomLayer(.border, 1, false);
    _ = b4.applyLoomLayer(.circle, 2, false);
    try std.testing.expect(!b1.eql(b4));

    // Clear layers
    b1.clearLayers();
    try std.testing.expect(b1.isEmpty());
    try std.testing.expect(!b1.eql(b2));
}
