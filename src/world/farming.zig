const std = @import("std");

pub const max_crops: usize = 64;
pub const CropStage = u3;

pub const WheatCrop = struct {
    x: i32,
    y: i32,
    z: i32,
    timer: f32 = 0.0,
    stage: u8 = 0,
    hydrated: bool = false,
};

pub const dry_stage_time: f32 = 12.0;
pub const hydrated_stage_time: f32 = 6.0;
pub const bone_meal_stage_boost: u8 = 3;

pub const Harvest = struct { wheat: u8, seeds: u8 };

pub fn isMature(stage: u8) bool {
    return stage >= 7;
}

pub fn stageTime(hydrated: bool) f32 {
    return if (hydrated) hydrated_stage_time else dry_stage_time;
}

pub fn tickCrop(crop: *WheatCrop, dt: f32) bool {
    if (crop.stage >= 7) return false;
    crop.timer += dt;
    while (crop.stage < 7 and crop.timer >= stageTime(crop.hydrated)) {
        crop.timer -= stageTime(crop.hydrated);
        crop.stage += 1;
    }
    return crop.stage >= 7;
}

pub fn applyBoneMeal(crop: *WheatCrop) bool {
    if (crop.stage >= 7) return false;
    const boosted: u16 = @as(u16, crop.stage) + bone_meal_stage_boost;
    crop.stage = @intCast(@min(boosted, 7));
    crop.timer = 0.0;
    return true;
}

pub fn findCrop(crops: []const WheatCrop, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, crops.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const c = crops[i];
        if (c.x == x and c.y == y and c.z == z) return i;
    }
    return null;
}

pub fn harvestYield(stage: u8, seed_roll: u8) Harvest {
    if (stage >= 7) {
        return .{ .wheat = 1, .seeds = 1 + (seed_roll % 3) };
    }
    return .{ .wheat = 0, .seeds = 1 };
}

pub fn isWithinHydrationRange(fx: i32, fy: i32, fz: i32, wx: i32, wy: i32, wz: i32) bool {
    const vertical = wy == fy or wy == fy + 1;
    return vertical and @abs(fx - wx) <= 4 and @abs(fz - wz) <= 4;
}

test "isMature threshold" {
    try std.testing.expect(!isMature(0));
    try std.testing.expect(!isMature(6));
    try std.testing.expect(isMature(7));
    try std.testing.expect(isMature(8));
}

test "stageTime hydrated is faster" {
    try std.testing.expectEqual(dry_stage_time, stageTime(false));
    try std.testing.expectEqual(hydrated_stage_time, stageTime(true));
    try std.testing.expect(stageTime(true) < stageTime(false));
}

test "tickCrop advances dry stage after 12s" {
    var crop = WheatCrop{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!tickCrop(&crop, 11.9));
    try std.testing.expectEqual(@as(u8, 0), crop.stage);
    try std.testing.expect(!tickCrop(&crop, 0.2));
    try std.testing.expectEqual(@as(u8, 1), crop.stage);
}

test "tickCrop hydrated advances in 6s" {
    var crop = WheatCrop{ .x = 0, .y = 0, .z = 0, .hydrated = true };
    try std.testing.expect(!tickCrop(&crop, 5.9));
    try std.testing.expectEqual(@as(u8, 0), crop.stage);
    try std.testing.expect(!tickCrop(&crop, 0.2));
    try std.testing.expectEqual(@as(u8, 1), crop.stage);
}

test "tickCrop reaches maturity and reports it" {
    var crop = WheatCrop{ .x = 0, .y = 0, .z = 0 };
    var reached = false;
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        reached = tickCrop(&crop, dry_stage_time);
    }
    try std.testing.expect(reached);
    try std.testing.expect(isMature(crop.stage));
    try std.testing.expectEqual(@as(u8, 7), crop.stage);
}

test "tickCrop large dt advances multiple stages" {
    var crop = WheatCrop{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!tickCrop(&crop, dry_stage_time * 3.0));
    try std.testing.expectEqual(@as(u8, 3), crop.stage);
}

test "tickCrop on mature crop is inert" {
    var crop = WheatCrop{ .x = 0, .y = 0, .z = 0, .stage = 7, .timer = 5.0 };
    try std.testing.expect(!tickCrop(&crop, 100.0));
    try std.testing.expectEqual(@as(u8, 7), crop.stage);
    try std.testing.expectEqual(@as(f32, 5.0), crop.timer);
}

test "applyBoneMeal boosts stage and resets timer" {
    var crop = WheatCrop{ .x = 0, .y = 0, .z = 0, .timer = 4.0, .stage = 1 };
    try std.testing.expect(applyBoneMeal(&crop));
    try std.testing.expectEqual(@as(u8, 4), crop.stage);
    try std.testing.expectEqual(@as(f32, 0.0), crop.timer);
}

test "applyBoneMeal clamps to maturity" {
    var crop = WheatCrop{ .x = 0, .y = 0, .z = 0, .stage = 6 };
    try std.testing.expect(applyBoneMeal(&crop));
    try std.testing.expectEqual(@as(u8, 7), crop.stage);
}

test "applyBoneMeal rejects mature crop" {
    var crop = WheatCrop{ .x = 0, .y = 0, .z = 0, .stage = 7, .timer = 2.0 };
    try std.testing.expect(!applyBoneMeal(&crop));
    try std.testing.expectEqual(@as(u8, 7), crop.stage);
    try std.testing.expectEqual(@as(f32, 2.0), crop.timer);
}

test "findCrop locates within count and ignores beyond" {
    var crops: [4]WheatCrop = undefined;
    crops[0] = .{ .x = 1, .y = 2, .z = 3 };
    crops[1] = .{ .x = 4, .y = 5, .z = 6 };
    crops[2] = .{ .x = 7, .y = 8, .z = 9 };
    crops[3] = .{ .x = 10, .y = 11, .z = 12 };
    try std.testing.expectEqual(@as(?usize, 1), findCrop(&crops, 3, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, 0), findCrop(&crops, 3, 1, 2, 3));
    try std.testing.expectEqual(@as(?usize, null), findCrop(&crops, 3, 1, 2, 9));
    try std.testing.expectEqual(@as(?usize, 2), findCrop(&crops, 3, 7, 8, 9));
    try std.testing.expectEqual(@as(?usize, null), findCrop(&crops, 3, 10, 11, 12));
    try std.testing.expectEqual(@as(?usize, 3), findCrop(&crops, 4, 10, 11, 12));
}

test "harvestYield immature gives a seed only" {
    try std.testing.expectEqualDeep(Harvest{ .wheat = 0, .seeds = 1 }, harvestYield(0, 0));
    try std.testing.expectEqualDeep(Harvest{ .wheat = 0, .seeds = 1 }, harvestYield(6, 200));
}

test "harvestYield mature gives wheat and rolled seeds" {
    try std.testing.expectEqualDeep(Harvest{ .wheat = 1, .seeds = 1 }, harvestYield(7, 0));
    try std.testing.expectEqualDeep(Harvest{ .wheat = 1, .seeds = 2 }, harvestYield(7, 1));
    try std.testing.expectEqualDeep(Harvest{ .wheat = 1, .seeds = 3 }, harvestYield(7, 2));
    try std.testing.expectEqualDeep(Harvest{ .wheat = 1, .seeds = 1 }, harvestYield(7, 3));
    try std.testing.expectEqualDeep(Harvest{ .wheat = 1, .seeds = 1 }, harvestYield(8, 9));
}

test "isWithinHydrationRange respects level and radius" {
    try std.testing.expect(isWithinHydrationRange(0, 4, 0, 0, 4, 0));
    try std.testing.expect(isWithinHydrationRange(0, 4, 0, 0, 5, 0));
    try std.testing.expect(isWithinHydrationRange(0, 4, 0, 4, 4, 4));
    try std.testing.expect(isWithinHydrationRange(0, 4, 0, -4, 4, -4));
    try std.testing.expect(!isWithinHydrationRange(0, 4, 0, 0, 3, 0));
    try std.testing.expect(!isWithinHydrationRange(0, 4, 0, 0, 6, 0));
    try std.testing.expect(!isWithinHydrationRange(0, 4, 0, 5, 4, 0));
    try std.testing.expect(!isWithinHydrationRange(0, 4, 0, 0, 4, 5));
}

test "constants" {
    try std.testing.expectEqual(@as(usize, 64), max_crops);
    try std.testing.expectEqual(@as(f32, 12.0), dry_stage_time);
    try std.testing.expectEqual(@as(f32, 6.0), hydrated_stage_time);
    try std.testing.expectEqual(@as(u8, 3), bone_meal_stage_boost);
    try std.testing.expectEqual(@as(u8, 7), @as(u8, std.math.maxInt(CropStage)));
}
