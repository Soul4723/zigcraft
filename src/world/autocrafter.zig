const std = @import("std");

pub const WoodLogTag: u16 = 5;
pub const WoodPlanksTag: u16 = 7;
pub const StickTag: u16 = 8;
pub const BreezeRodTag: u16 = 371;
pub const WindChargeTag: u16 = 372;
pub const HeavyCoreTag: u16 = 373;
pub const DiamondTag: u16 = 217;
pub const EmeraldTag: u16 = 273;
pub const EnchantedGoldenAppleTag: u16 = 379;

pub const AutoCraftResult = struct {
    output_tag: u16,
    output_count: u8,
};

pub fn autoCraftSingleInput(input_tag: u16) ?AutoCraftResult {
    return switch (input_tag) {
        WoodLogTag => .{ .output_tag = WoodPlanksTag, .output_count = 4 },
        WoodPlanksTag => .{ .output_tag = StickTag, .output_count = 2 },
        BreezeRodTag => .{ .output_tag = WindChargeTag, .output_count = 4 },
        else => null,
    };
}

pub fn vaultLootForRoll(roll: u8) AutoCraftResult {
    return switch (roll % 5) {
        0 => .{ .output_tag = HeavyCoreTag, .output_count = 1 },
        1 => .{ .output_tag = BreezeRodTag, .output_count = 3 },
        2 => .{ .output_tag = DiamondTag, .output_count = 2 },
        3 => .{ .output_tag = EmeraldTag, .output_count = 4 },
        else => .{ .output_tag = EnchantedGoldenAppleTag, .output_count = 1 },
    };
}

test "tag constants" {
    try std.testing.expectEqual(@as(u16, 5), WoodLogTag);
    try std.testing.expectEqual(@as(u16, 7), WoodPlanksTag);
    try std.testing.expectEqual(@as(u16, 8), StickTag);
    try std.testing.expectEqual(@as(u16, 371), BreezeRodTag);
    try std.testing.expectEqual(@as(u16, 372), WindChargeTag);
    try std.testing.expectEqual(@as(u16, 373), HeavyCoreTag);
    try std.testing.expectEqual(@as(u16, 217), DiamondTag);
    try std.testing.expectEqual(@as(u16, 273), EmeraldTag);
    try std.testing.expectEqual(@as(u16, 379), EnchantedGoldenAppleTag);
}

test "autoCraftSingleInput maps log to planks" {
    const r = autoCraftSingleInput(WoodLogTag).?;
    try std.testing.expectEqual(WoodPlanksTag, r.output_tag);
    try std.testing.expectEqual(@as(u8, 4), r.output_count);
}

test "autoCraftSingleInput maps planks to sticks" {
    const r = autoCraftSingleInput(WoodPlanksTag).?;
    try std.testing.expectEqual(StickTag, r.output_tag);
    try std.testing.expectEqual(@as(u8, 2), r.output_count);
}

test "autoCraftSingleInput maps breeze rod to wind charge" {
    const r = autoCraftSingleInput(BreezeRodTag).?;
    try std.testing.expectEqual(WindChargeTag, r.output_tag);
    try std.testing.expectEqual(@as(u8, 4), r.output_count);
}

test "autoCraftSingleInput unknown returns null" {
    try std.testing.expectEqual(@as(?AutoCraftResult, null), autoCraftSingleInput(0));
    try std.testing.expectEqual(@as(?AutoCraftResult, null), autoCraftSingleInput(DiamondTag));
    try std.testing.expectEqual(@as(?AutoCraftResult, null), autoCraftSingleInput(WindChargeTag));
    try std.testing.expectEqual(@as(?AutoCraftResult, null), autoCraftSingleInput(65535));
}

test "vaultLootForRoll covers all residues" {
    const r0 = vaultLootForRoll(0);
    try std.testing.expectEqual(HeavyCoreTag, r0.output_tag);
    try std.testing.expectEqual(@as(u8, 1), r0.output_count);

    const r1 = vaultLootForRoll(1);
    try std.testing.expectEqual(BreezeRodTag, r1.output_tag);
    try std.testing.expectEqual(@as(u8, 3), r1.output_count);

    const r2 = vaultLootForRoll(2);
    try std.testing.expectEqual(DiamondTag, r2.output_tag);
    try std.testing.expectEqual(@as(u8, 2), r2.output_count);

    const r3 = vaultLootForRoll(3);
    try std.testing.expectEqual(EmeraldTag, r3.output_tag);
    try std.testing.expectEqual(@as(u8, 4), r3.output_count);

    const r4 = vaultLootForRoll(4);
    try std.testing.expectEqual(EnchantedGoldenAppleTag, r4.output_tag);
    try std.testing.expectEqual(@as(u8, 1), r4.output_count);
}

test "vaultLootForRoll wraps by modulo 5" {
    const r5 = vaultLootForRoll(5);
    try std.testing.expectEqual(HeavyCoreTag, r5.output_tag);
    try std.testing.expectEqual(@as(u8, 1), r5.output_count);

    const r9 = vaultLootForRoll(9);
    try std.testing.expectEqual(EnchantedGoldenAppleTag, r9.output_tag);

    const r10 = vaultLootForRoll(10);
    try std.testing.expectEqual(HeavyCoreTag, r10.output_tag);

    const r255 = vaultLootForRoll(255);
    try std.testing.expectEqual(HeavyCoreTag, r255.output_tag);
    try std.testing.expectEqual(@as(u8, 1), r255.output_count);
}
