const std = @import("std");

/// XP orb pickup cooldown: two game ticks (0.10 seconds).
pub const XP_ORB_PICKUP_COOLDOWN_TICKS: u8 = 2;
pub const XP_ORB_PICKUP_COOLDOWN_SECONDS: f32 = 0.10;
pub const XP_ORB_CLUMP_DISTANCE_SQ: f32 = 0.25;
pub const MAX_PLAYER_DEATH_DROPPED_XP: u16 = 100;

/// Canonical XP values represented by the eleven visual orb sizes.
pub const XpOrbTier = enum(u16) {
    xp_1 = 1, xp_3 = 3, xp_7 = 7, xp_17 = 17, xp_37 = 37, xp_73 = 73,
    xp_149 = 149, xp_307 = 307, xp_617 = 617, xp_1237 = 1237, xp_2477 = 2477,
};

const ORB_TIER_VALUES = [_]u16{ 1, 3, 7, 17, 37, 73, 149, 307, 617, 1237, 2477 };

/// XP needed to advance from current_level to the next level.
pub fn xpRequiredForNextLevel(current_level: u16) u32 {
    const level: u32 = current_level;
    return if (current_level <= 15) 2 * level + 7 else if (current_level <= 30) 5 * level - 38 else 9 * level - 158;
}

/// Total XP required to reach `level` from level zero.
pub fn totalXpForLevel(level: u16) u32 {
    var total: u32 = 0;
    var current: u32 = 0;
    while (current < level) : (current += 1) total += xpRequiredForNextLevel(@intCast(current));
    return total;
}

/// Largest canonical orb value no greater than xp_remaining; zero means none fits.
pub fn largestOrbTierLeq(xp_remaining: u32) u16 {
    var selected: u16 = 0;
    for (ORB_TIER_VALUES) |value| {
        if (value > xp_remaining) break;
        selected = value;
    }
    return selected;
}

/// Merge matching-value nearby orbs into an existing stack.
pub fn clumpNearbyXpOrbs(orb_a_value: u32, orb_a_count: u8, orb_b_value: u32, dist_sq: f32) struct { merged: bool, new_count: u8 } {
    const can_merge = orb_a_value == orb_b_value and dist_sq <= XP_ORB_CLUMP_DISTANCE_SQ and orb_a_count < std.math.maxInt(u8);
    return .{ .merged = can_merge, .new_count = if (can_merge) orb_a_count + 1 else orb_a_count };
}

/// XP dropped on player death, capped at 100 XP.
pub fn computePlayerDeathDroppedXp(player_level: u16) u16 {
    return @intCast(@min(MAX_PLAYER_DEATH_DROPPED_XP, @as(u32, player_level) * 7));
}

test "next-level XP follows 0..15 curve" {
    for (0..16) |level| try std.testing.expectEqual(@as(u32, 2 * @as(u32, @intCast(level)) + 7), xpRequiredForNextLevel(@intCast(level)));
    try std.testing.expectEqual(@as(u32, 37), xpRequiredForNextLevel(15));
}

test "next-level XP follows 16..30 curve" {
    for (16..31) |level| try std.testing.expectEqual(@as(u32, 5 * @as(u32, @intCast(level)) - 38), xpRequiredForNextLevel(@intCast(level)));
    try std.testing.expectEqual(@as(u32, 42), xpRequiredForNextLevel(16));
    try std.testing.expectEqual(@as(u32, 112), xpRequiredForNextLevel(30));
}

test "next-level XP follows 31+ curve" {
    try std.testing.expectEqual(@as(u32, 121), xpRequiredForNextLevel(31));
    try std.testing.expectEqual(@as(u32, 238), xpRequiredForNextLevel(44));
    try std.testing.expectEqual(@as(u32, 8842), xpRequiredForNextLevel(1000));
}

test "cumulative XP reaches level 15 and 30 totals" {
    try std.testing.expectEqual(@as(u32, 315), totalXpForLevel(15));
    try std.testing.expectEqual(@as(u32, 1395), totalXpForLevel(30));
}

test "cumulative XP reflects individual level costs" {
    try std.testing.expectEqual(@as(u32, 27), totalXpForLevel(3));
    try std.testing.expectEqual(@as(u32, 306), totalXpForLevel(30) - totalXpForLevel(27));
}

test "cumulative XP handles zero and level 31" {
    try std.testing.expectEqual(@as(u32, 0), totalXpForLevel(0));
    try std.testing.expectEqual(@as(u32, 1507), totalXpForLevel(31));
}

test "largest orb tier recognizes all eleven thresholds" {
    const values = [_]u16{ 1, 3, 7, 17, 37, 73, 149, 307, 617, 1237, 2477 };
    for (values) |value| try std.testing.expectEqual(value, largestOrbTierLeq(value));
    try std.testing.expectEqual(@as(usize, 11), @typeInfo(XpOrbTier).@"enum".fields.len);
}

test "largest orb tier picks lower threshold or zero" {
    try std.testing.expectEqual(@as(u16, 0), largestOrbTierLeq(0));
    try std.testing.expectEqual(@as(u16, 1), largestOrbTierLeq(2));
    try std.testing.expectEqual(@as(u16, 3), largestOrbTierLeq(6));
    try std.testing.expectEqual(@as(u16, 1237), largestOrbTierLeq(2476));
    try std.testing.expectEqual(@as(u16, 2477), largestOrbTierLeq(10000));
}

test "largest orb tier returns its canonical enum value" {
    try std.testing.expectEqual(@as(u16, 2477), @intFromEnum(XpOrbTier.xp_2477));
}

test "matching orbs at half-block distance merge into a stack" {
    const result = clumpNearbyXpOrbs(7, 1, 7, 0.25);
    try std.testing.expect(result.merged);
    try std.testing.expectEqual(@as(u8, 2), result.new_count);
}

test "clumping rejects different values and distances past half block" {
    try std.testing.expect(!clumpNearbyXpOrbs(7, 2, 3, 0.1).merged);
    try std.testing.expect(!clumpNearbyXpOrbs(7, 2, 7, 0.25001).merged);
}

test "clumping does not overflow a full stack count" {
    const result = clumpNearbyXpOrbs(1, std.math.maxInt(u8), 1, 0);
    try std.testing.expect(!result.merged);
    try std.testing.expectEqual(std.math.maxInt(u8), result.new_count);
}

test "death XP is seven times player level below cap" {
    try std.testing.expectEqual(@as(u16, 0), computePlayerDeathDroppedXp(0));
    try std.testing.expectEqual(@as(u16, 7), computePlayerDeathDroppedXp(1));
    try std.testing.expectEqual(@as(u16, 98), computePlayerDeathDroppedXp(14));
}

test "death XP caps at 100 from level 15 onward" {
    try std.testing.expectEqual(@as(u16, 100), computePlayerDeathDroppedXp(15));
    try std.testing.expectEqual(@as(u16, 100), computePlayerDeathDroppedXp(100));
    try std.testing.expectEqual(@as(u16, 100), computePlayerDeathDroppedXp(std.math.maxInt(u16)));
}

test "orb pickup cooldown is two ticks or one tenth second" {
    try std.testing.expectEqual(@as(u8, 2), XP_ORB_PICKUP_COOLDOWN_TICKS);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), XP_ORB_PICKUP_COOLDOWN_SECONDS, 0.00001);
}
