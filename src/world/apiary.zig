const std = @import("std");

pub const max_hives: usize = 32;
pub const max_honey_level: u8 = 5;
pub const honey_stage_time: f32 = 15.0;
pub const pollinated_stage_time: f32 = 7.5;
pub const honey_slide_max_fall_speed: f32 = -2.2;
pub const honey_fall_damage_multiplier: f32 = 0.20;
pub const honey_bottle_hunger: f32 = 6.0;

pub const Beehive = struct {
    x: i32,
    y: i32,
    z: i32,
    timer: f32 = 0.0,
    honey_level: u8 = 0,
    has_flowers_nearby: bool = false,
};

pub fn isReadyForHarvest(honey_level: u8) bool {
    return honey_level >= max_honey_level;
}

pub fn stageDuration(has_flowers_nearby: bool) f32 {
    return if (has_flowers_nearby) pollinated_stage_time else honey_stage_time;
}

pub fn tickHive(hive: *Beehive, dt: f32) bool {
    if (hive.honey_level >= max_honey_level) return false;
    hive.timer += dt;
    const duration = stageDuration(hive.has_flowers_nearby);
    while (hive.honey_level < max_honey_level and hive.timer >= duration) {
        hive.timer -= duration;
        hive.honey_level += 1;
    }
    return hive.honey_level >= max_honey_level;
}

pub fn harvestHoneycomb(hive: *Beehive) u8 {
    if (!isReadyForHarvest(hive.honey_level)) return 0;
    hive.honey_level = 0;
    hive.timer = 0.0;
    return 3;
}

pub fn harvestHoneyBottle(hive: *Beehive) bool {
    if (!isReadyForHarvest(hive.honey_level)) return false;
    hive.honey_level = 0;
    hive.timer = 0.0;
    return true;
}

pub fn findHive(hives: []const Beehive, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, hives.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const h = hives[i];
        if (h.x == x and h.y == y and h.z == z) return i;
    }
    return null;
}

pub fn clampHoneySlideVelocity(vy: f32) f32 {
    return @max(vy, honey_slide_max_fall_speed);
}

pub fn calculateHoneyFallDamage(raw_damage: f32) f32 {
    return raw_damage * honey_fall_damage_multiplier;
}

test "constants" {
    try std.testing.expectEqual(@as(usize, 32), max_hives);
    try std.testing.expectEqual(@as(u8, 5), max_honey_level);
    try std.testing.expectEqual(@as(f32, 15.0), honey_stage_time);
    try std.testing.expectEqual(@as(f32, 7.5), pollinated_stage_time);
    try std.testing.expectEqual(@as(f32, -2.2), honey_slide_max_fall_speed);
    try std.testing.expectEqual(@as(f32, 0.20), honey_fall_damage_multiplier);
    try std.testing.expectEqual(@as(f32, 6.0), honey_bottle_hunger);
}

test "isReadyForHarvest" {
    try std.testing.expect(!isReadyForHarvest(0));
    try std.testing.expect(!isReadyForHarvest(4));
    try std.testing.expect(isReadyForHarvest(5));
    try std.testing.expect(isReadyForHarvest(6));
}

test "stageDuration" {
    try std.testing.expectEqual(honey_stage_time, stageDuration(false));
    try std.testing.expectEqual(pollinated_stage_time, stageDuration(true));
}

test "tickHive fills over time" {
    var hive = Beehive{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!tickHive(&hive, 14.9));
    try std.testing.expectEqual(@as(u8, 0), hive.honey_level);
    try std.testing.expect(!tickHive(&hive, 0.1));
    try std.testing.expectEqual(@as(u8, 1), hive.honey_level);
}

test "tickHive reaches max and reports ready" {
    var hive = Beehive{ .x = 1, .y = 2, .z = 3 };
    var ready = false;
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        ready = tickHive(&hive, honey_stage_time);
    }
    try std.testing.expect(ready);
    try std.testing.expectEqual(max_honey_level, hive.honey_level);
    try std.testing.expect(!tickHive(&hive, 100.0));
    try std.testing.expectEqual(max_honey_level, hive.honey_level);
}

test "tickHive with flowers is faster" {
    var hive = Beehive{ .x = 0, .y = 0, .z = 0, .has_flowers_nearby = true };
    try std.testing.expect(!tickHive(&hive, pollinated_stage_time));
    try std.testing.expectEqual(@as(u8, 1), hive.honey_level);
}

test "harvestHoneycomb" {
    var hive = Beehive{ .x = 0, .y = 0, .z = 0, .honey_level = 4, .timer = 3.0 };
    try std.testing.expectEqual(@as(u8, 0), harvestHoneycomb(&hive));
    try std.testing.expectEqual(@as(u8, 4), hive.honey_level);

    hive.honey_level = max_honey_level;
    try std.testing.expectEqual(@as(u8, 3), harvestHoneycomb(&hive));
    try std.testing.expectEqual(@as(u8, 0), hive.honey_level);
    try std.testing.expectEqual(@as(f32, 0.0), hive.timer);
}

test "harvestHoneyBottle" {
    var hive = Beehive{ .x = 0, .y = 0, .z = 0, .honey_level = 4, .timer = 3.0 };
    try std.testing.expect(!harvestHoneyBottle(&hive));
    try std.testing.expectEqual(@as(u8, 4), hive.honey_level);

    hive.honey_level = max_honey_level;
    try std.testing.expect(harvestHoneyBottle(&hive));
    try std.testing.expectEqual(@as(u8, 0), hive.honey_level);
    try std.testing.expectEqual(@as(f32, 0.0), hive.timer);
}

test "findHive" {
    var hives: [max_hives]Beehive = undefined;
    hives[0] = .{ .x = 1, .y = 2, .z = 3 };
    hives[1] = .{ .x = 4, .y = 5, .z = 6 };
    hives[2] = .{ .x = 1, .y = 2, .z = 3 };

    try std.testing.expectEqual(@as(?usize, 0), findHive(&hives, 3, 1, 2, 3));
    try std.testing.expectEqual(@as(?usize, 1), findHive(&hives, 3, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, null), findHive(&hives, 3, 9, 9, 9));
    try std.testing.expectEqual(@as(?usize, null), findHive(&hives, 1, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, null), findHive(&hives, 0, 1, 2, 3));
}

test "clampHoneySlideVelocity" {
    try std.testing.expectEqual(@as(f32, -2.2), clampHoneySlideVelocity(-10.0));
    try std.testing.expectEqual(@as(f32, -2.2), clampHoneySlideVelocity(-2.2));
    try std.testing.expectEqual(@as(f32, 0.0), clampHoneySlideVelocity(0.0));
    try std.testing.expectEqual(@as(f32, 1.5), clampHoneySlideVelocity(1.5));
}

test "calculateHoneyFallDamage" {
    try std.testing.expectEqual(@as(f32, 0.0), calculateHoneyFallDamage(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), calculateHoneyFallDamage(5.0));
    try std.testing.expectEqual(@as(f32, 2.0), calculateHoneyFallDamage(10.0));
}
