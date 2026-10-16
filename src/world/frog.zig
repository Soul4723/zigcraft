const std = @import("std");

pub const FrogVariant = enum(u8) { temperate = 0, warm = 1, cold = 2 };

pub const OchreFroglightTag: u16 = 386;
pub const VerdantFroglightTag: u16 = 387;
pub const PearlescentFroglightTag: u16 = 388;
pub const SlimeballTag: u16 = 206;

pub fn froglightForVariant(variant: FrogVariant) u16 {
    return switch (variant) {
        .temperate => OchreFroglightTag,
        .warm => PearlescentFroglightTag,
        .cold => VerdantFroglightTag,
    };
}

pub fn predationDrop(is_magma_cube: bool, variant: FrogVariant) u16 {
    if (is_magma_cube) return froglightForVariant(variant);
    return SlimeballTag;
}

pub fn jumpVelocity(on_lily_pad: bool) f32 {
    if (on_lily_pad) return 8.0;
    return 5.5;
}

pub fn variantForBiomeHeight(height: usize) FrogVariant {
    if (height >= 9) return .cold;
    if (height <= 4) return .warm;
    return .temperate;
}

test "constants have expected values" {
    try std.testing.expectEqual(@as(u16, 386), OchreFroglightTag);
    try std.testing.expectEqual(@as(u16, 387), VerdantFroglightTag);
    try std.testing.expectEqual(@as(u16, 388), PearlescentFroglightTag);
    try std.testing.expectEqual(@as(u16, 206), SlimeballTag);
}

test "variant enum discriminants" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(FrogVariant.temperate));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(FrogVariant.warm));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(FrogVariant.cold));
}

test "froglightForVariant maps each variant" {
    try std.testing.expectEqual(OchreFroglightTag, froglightForVariant(.temperate));
    try std.testing.expectEqual(PearlescentFroglightTag, froglightForVariant(.warm));
    try std.testing.expectEqual(VerdantFroglightTag, froglightForVariant(.cold));
}

test "predationDrop from magma cube yields froglight" {
    try std.testing.expectEqual(OchreFroglightTag, predationDrop(true, .temperate));
    try std.testing.expectEqual(PearlescentFroglightTag, predationDrop(true, .warm));
    try std.testing.expectEqual(VerdantFroglightTag, predationDrop(true, .cold));
}

test "predationDrop from non-magma yields slimeball" {
    try std.testing.expectEqual(SlimeballTag, predationDrop(false, .temperate));
    try std.testing.expectEqual(SlimeballTag, predationDrop(false, .warm));
    try std.testing.expectEqual(SlimeballTag, predationDrop(false, .cold));
}

test "jumpVelocity on lily pad" {
    try std.testing.expectEqual(@as(f32, 8.0), jumpVelocity(true));
}

test "jumpVelocity off lily pad" {
    try std.testing.expectEqual(@as(f32, 5.5), jumpVelocity(false));
}

test "variantForBiomeHeight cold for tall biomes" {
    try std.testing.expectEqual(FrogVariant.cold, variantForBiomeHeight(9));
    try std.testing.expectEqual(FrogVariant.cold, variantForBiomeHeight(20));
}

test "variantForBiomeHeight warm for short biomes" {
    try std.testing.expectEqual(FrogVariant.warm, variantForBiomeHeight(0));
    try std.testing.expectEqual(FrogVariant.warm, variantForBiomeHeight(4));
}

test "variantForBiomeHeight temperate in between" {
    try std.testing.expectEqual(FrogVariant.temperate, variantForBiomeHeight(5));
    try std.testing.expectEqual(FrogVariant.temperate, variantForBiomeHeight(8));
}
