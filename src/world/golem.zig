const std = @import("std");

pub const snow_golem_hp: u8 = 10;
pub const iron_golem_hp: u8 = 100;
pub const iron_golem_fling_damage: u8 = 12;
pub const iron_golem_fling_vy: f32 = 8.5;
pub const iron_ingot_repair_hp: u8 = 25;

pub const GolemKind = enum { snow_golem, iron_golem };

pub const SnowBlockTag: u8 = 18;
pub const IronBlockTag: u8 = 185;
pub const CarvedPumpkinTag: u8 = 176;
pub const JackOLanternTag: u8 = 177;

pub fn isPumpkinHead(block_tag: u8) bool {
    return block_tag == CarvedPumpkinTag or block_tag == JackOLanternTag;
}

pub fn detectTotem(head_tag: u8, middle_tag: u8, base_tag: u8) ?GolemKind {
    if (!isPumpkinHead(head_tag)) return null;
    if (middle_tag == SnowBlockTag and base_tag == SnowBlockTag) return .snow_golem;
    if (middle_tag == IronBlockTag and base_tag == IronBlockTag) return .iron_golem;
    return null;
}

pub fn repairIronGolem(current_hp: u8) ?u8 {
    if (current_hp >= iron_golem_hp) return null;
    return @min(iron_golem_hp, current_hp +| iron_ingot_repair_hp);
}

pub fn golemDropCount(kind: GolemKind, roll: u8) u8 {
    return switch (kind) {
        .iron_golem => 3 + (roll % 3),
        .snow_golem => 2 + (roll % 3),
    };
}

test "hp constants" {
    try std.testing.expectEqual(@as(u8, 10), snow_golem_hp);
    try std.testing.expectEqual(@as(u8, 100), iron_golem_hp);
}

test "fling and repair constants" {
    try std.testing.expectEqual(@as(u8, 12), iron_golem_fling_damage);
    try std.testing.expectApproxEqAbs(@as(f32, 8.5), iron_golem_fling_vy, 0.0001);
    try std.testing.expectEqual(@as(u8, 25), iron_ingot_repair_hp);
}

test "block tag constants" {
    try std.testing.expectEqual(@as(u8, 18), SnowBlockTag);
    try std.testing.expectEqual(@as(u8, 185), IronBlockTag);
    try std.testing.expectEqual(@as(u8, 176), CarvedPumpkinTag);
    try std.testing.expectEqual(@as(u8, 177), JackOLanternTag);
}

test "isPumpkinHead accepts both pumpkin tags" {
    try std.testing.expect(isPumpkinHead(CarvedPumpkinTag));
    try std.testing.expect(isPumpkinHead(JackOLanternTag));
    try std.testing.expect(!isPumpkinHead(SnowBlockTag));
    try std.testing.expect(!isPumpkinHead(IronBlockTag));
    try std.testing.expect(!isPumpkinHead(0));
}

test "detectTotem builds snow golem" {
    try std.testing.expectEqual(GolemKind.snow_golem, detectTotem(CarvedPumpkinTag, SnowBlockTag, SnowBlockTag).?);
    try std.testing.expectEqual(GolemKind.snow_golem, detectTotem(JackOLanternTag, SnowBlockTag, SnowBlockTag).?);
}

test "detectTotem builds iron golem" {
    try std.testing.expectEqual(GolemKind.iron_golem, detectTotem(CarvedPumpkinTag, IronBlockTag, IronBlockTag).?);
    try std.testing.expectEqual(GolemKind.iron_golem, detectTotem(JackOLanternTag, IronBlockTag, IronBlockTag).?);
}

test "detectTotem rejects invalid builds" {
    try std.testing.expect(detectTotem(SnowBlockTag, SnowBlockTag, SnowBlockTag) == null);
    try std.testing.expect(detectTotem(CarvedPumpkinTag, IronBlockTag, SnowBlockTag) == null);
    try std.testing.expect(detectTotem(CarvedPumpkinTag, SnowBlockTag, IronBlockTag) == null);
    try std.testing.expect(detectTotem(CarvedPumpkinTag, 0, 0) == null);
}

test "repairIronGolem heals and clamps" {
    try std.testing.expectEqual(@as(u8, 30), repairIronGolem(5).?);
    try std.testing.expectEqual(@as(u8, 100), repairIronGolem(90).?);
    try std.testing.expectEqual(@as(u8, 100), repairIronGolem(76).?);
}

test "repairIronGolem returns null at full hp" {
    try std.testing.expect(repairIronGolem(iron_golem_hp) == null);
    try std.testing.expect(repairIronGolem(255) == null);
}

test "repairIronGolem handles lone hp" {
    try std.testing.expectEqual(@as(u8, 26), repairIronGolem(1).?);
}

test "golemDropCount ranges" {
    var roll: u8 = 0;
    while (roll < 6) : (roll += 1) {
        const iron = golemDropCount(.iron_golem, roll);
        const snow = golemDropCount(.snow_golem, roll);
        try std.testing.expect(iron >= 3 and iron <= 5);
        try std.testing.expect(snow >= 2 and snow <= 4);
    }
}

test "golemDropCount cycles by roll mod 3" {
    try std.testing.expectEqual(@as(u8, 3), golemDropCount(.iron_golem, 0));
    try std.testing.expectEqual(@as(u8, 5), golemDropCount(.iron_golem, 2));
    try std.testing.expectEqual(@as(u8, 3), golemDropCount(.iron_golem, 3));
    try std.testing.expectEqual(@as(u8, 2), golemDropCount(.snow_golem, 0));
    try std.testing.expectEqual(@as(u8, 4), golemDropCount(.snow_golem, 2));
    try std.testing.expectEqual(@as(u8, 2), golemDropCount(.snow_golem, 6));
}
