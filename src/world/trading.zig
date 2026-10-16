const std = @import("std");

pub const Profession = enum(u8) {
    farmer = 0,
    librarian = 1,
    blacksmith = 2,
    cleric = 3,
    fletcher = 4,
};

pub const TradeOffer = struct {
    emerald_cost: u8,
    output_tag: u16,
    output_count: u8,
};

pub const BreadTag: u16 = 268;
pub const GoldenAppleTag: u16 = 30;
pub const BookTag: u16 = 270;
pub const LanternTag: u16 = 133;
pub const IronPickaxeTag: u16 = 27;
pub const DiamondSwordTag: u16 = 220;
pub const EnderPearlTag: u16 = 147;
pub const GlowstoneTag: u16 = 53;
pub const ArrowTag: u16 = 97;
pub const SpectralArrowTag: u16 = 96;

pub fn professionForTier(roll: u8) Profession {
    return switch (roll % 5) {
        0 => .farmer,
        1 => .librarian,
        2 => .blacksmith,
        3 => .cleric,
        else => .fletcher,
    };
}

pub fn getOffer(profession: Profession, tier: u8) TradeOffer {
    const master = tier >= 1;
    return switch (profession) {
        .farmer => if (master)
            .{ .emerald_cost = 3, .output_tag = GoldenAppleTag, .output_count = 1 }
        else
            .{ .emerald_cost = 1, .output_tag = BreadTag, .output_count = 4 },
        .librarian => if (master)
            .{ .emerald_cost = 2, .output_tag = LanternTag, .output_count = 2 }
        else
            .{ .emerald_cost = 1, .output_tag = BookTag, .output_count = 2 },
        .blacksmith => if (master)
            .{ .emerald_cost = 4, .output_tag = DiamondSwordTag, .output_count = 1 }
        else
            .{ .emerald_cost = 2, .output_tag = IronPickaxeTag, .output_count = 1 },
        .cleric => if (master)
            .{ .emerald_cost = 3, .output_tag = EnderPearlTag, .output_count = 1 }
        else
            .{ .emerald_cost = 1, .output_tag = GlowstoneTag, .output_count = 2 },
        .fletcher => if (master)
            .{ .emerald_cost = 2, .output_tag = SpectralArrowTag, .output_count = 4 }
        else
            .{ .emerald_cost = 1, .output_tag = ArrowTag, .output_count = 8 },
    };
}

pub fn canAfford(emerald_count: u16, offer: TradeOffer) bool {
    return emerald_count >= offer.emerald_cost;
}

pub fn emeraldDropCount(looting_roll: u8) u8 {
    return 1 + (looting_roll % 2);
}

pub fn xpToTier(trades_completed: u16) u8 {
    return if (trades_completed < 3) 0 else 1;
}

test "professionForTier maps roll modulo five" {
    try std.testing.expectEqual(Profession.farmer, professionForTier(0));
    try std.testing.expectEqual(Profession.librarian, professionForTier(1));
    try std.testing.expectEqual(Profession.blacksmith, professionForTier(2));
    try std.testing.expectEqual(Profession.cleric, professionForTier(3));
    try std.testing.expectEqual(Profession.fletcher, professionForTier(4));
    try std.testing.expectEqual(Profession.farmer, professionForTier(5));
    try std.testing.expectEqual(Profession.librarian, professionForTier(6));
    try std.testing.expectEqual(Profession.farmer, professionForTier(10));
    try std.testing.expectEqual(Profession.blacksmith, professionForTier(12));
    try std.testing.expectEqual(Profession.cleric, professionForTier(13));
    try std.testing.expectEqual(Profession.farmer, professionForTier(255));
}

test "getOffer farmer" {
    const novice = getOffer(.farmer, 0);
    try std.testing.expectEqual(@as(u8, 1), novice.emerald_cost);
    try std.testing.expectEqual(BreadTag, novice.output_tag);
    try std.testing.expectEqual(@as(u8, 4), novice.output_count);

    const master = getOffer(.farmer, 1);
    try std.testing.expectEqual(@as(u8, 3), master.emerald_cost);
    try std.testing.expectEqual(GoldenAppleTag, master.output_tag);
    try std.testing.expectEqual(@as(u8, 1), master.output_count);

    try std.testing.expectEqual(master, getOffer(.farmer, 7));
}

test "getOffer librarian" {
    const novice = getOffer(.librarian, 0);
    try std.testing.expectEqual(@as(u8, 1), novice.emerald_cost);
    try std.testing.expectEqual(BookTag, novice.output_tag);
    try std.testing.expectEqual(@as(u8, 2), novice.output_count);

    const master = getOffer(.librarian, 1);
    try std.testing.expectEqual(@as(u8, 2), master.emerald_cost);
    try std.testing.expectEqual(LanternTag, master.output_tag);
    try std.testing.expectEqual(@as(u8, 2), master.output_count);

    try std.testing.expectEqual(master, getOffer(.librarian, 200));
}

test "getOffer blacksmith" {
    const novice = getOffer(.blacksmith, 0);
    try std.testing.expectEqual(@as(u8, 2), novice.emerald_cost);
    try std.testing.expectEqual(IronPickaxeTag, novice.output_tag);
    try std.testing.expectEqual(@as(u8, 1), novice.output_count);

    const master = getOffer(.blacksmith, 1);
    try std.testing.expectEqual(@as(u8, 4), master.emerald_cost);
    try std.testing.expectEqual(DiamondSwordTag, master.output_tag);
    try std.testing.expectEqual(@as(u8, 1), master.output_count);

    try std.testing.expectEqual(master, getOffer(.blacksmith, 5));
}

test "getOffer cleric" {
    const novice = getOffer(.cleric, 0);
    try std.testing.expectEqual(@as(u8, 1), novice.emerald_cost);
    try std.testing.expectEqual(GlowstoneTag, novice.output_tag);
    try std.testing.expectEqual(@as(u8, 2), novice.output_count);

    const master = getOffer(.cleric, 1);
    try std.testing.expectEqual(@as(u8, 3), master.emerald_cost);
    try std.testing.expectEqual(EnderPearlTag, master.output_tag);
    try std.testing.expectEqual(@as(u8, 1), master.output_count);

    try std.testing.expectEqual(master, getOffer(.cleric, 9));
}

test "getOffer fletcher" {
    const novice = getOffer(.fletcher, 0);
    try std.testing.expectEqual(@as(u8, 1), novice.emerald_cost);
    try std.testing.expectEqual(ArrowTag, novice.output_tag);
    try std.testing.expectEqual(@as(u8, 8), novice.output_count);

    const master = getOffer(.fletcher, 1);
    try std.testing.expectEqual(@as(u8, 2), master.emerald_cost);
    try std.testing.expectEqual(SpectralArrowTag, master.output_tag);
    try std.testing.expectEqual(@as(u8, 4), master.output_count);

    try std.testing.expectEqual(master, getOffer(.fletcher, 6));
}

test "canAfford compares emeralds to cost" {
    const cheap = TradeOffer{ .emerald_cost = 1, .output_tag = BreadTag, .output_count = 4 };
    const pricey = TradeOffer{ .emerald_cost = 4, .output_tag = DiamondSwordTag, .output_count = 1 };

    try std.testing.expect(canAfford(1, cheap));
    try std.testing.expect(canAfford(100, cheap));
    try std.testing.expect(!canAfford(0, cheap));
    try std.testing.expect(!canAfford(3, pricey));
    try std.testing.expect(canAfford(4, pricey));
    try std.testing.expect(canAfford(65535, pricey));
}

test "emeraldDropCount alternates one and two" {
    try std.testing.expectEqual(@as(u8, 1), emeraldDropCount(0));
    try std.testing.expectEqual(@as(u8, 2), emeraldDropCount(1));
    try std.testing.expectEqual(@as(u8, 1), emeraldDropCount(2));
    try std.testing.expectEqual(@as(u8, 2), emeraldDropCount(3));
    try std.testing.expectEqual(@as(u8, 1), emeraldDropCount(254));
    try std.testing.expectEqual(@as(u8, 2), emeraldDropCount(255));
}

test "xpToTier promotes after three trades" {
    try std.testing.expectEqual(@as(u8, 0), xpToTier(0));
    try std.testing.expectEqual(@as(u8, 0), xpToTier(1));
    try std.testing.expectEqual(@as(u8, 0), xpToTier(2));
    try std.testing.expectEqual(@as(u8, 1), xpToTier(3));
    try std.testing.expectEqual(@as(u8, 1), xpToTier(4));
    try std.testing.expectEqual(@as(u8, 1), xpToTier(1000));
}
