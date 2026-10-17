const std = @import("std");

/// Spiders are neutral in bright light unless they have been directly provoked.
/// Evaluated at the current light level, so entering a dark area re-aggros them.
pub fn isSpiderHostileAtLightLevel(light_level_0_to_15: u4, provoked_by_attacker: bool) bool {
    return provoked_by_attacker or light_level_0_to_15 < daylight_neutrality_threshold;
}

pub const daylight_neutrality_threshold: u4 = 12;
pub const spider_wall_climb_speed_meters_per_second: f32 = 4.0;

/// Climbs at 0.2 blocks/tick (4 m/s) on a wall unless an overhead lip blocks it.
pub fn computeSpiderWallClimbVelocity(colliding_horizontally_with_wall: bool, blocked_by_overhead_lip_or_slab: bool) f32 {
    if (colliding_horizontally_with_wall and !blocked_by_overhead_lip_or_slab)
        return spider_wall_climb_speed_meters_per_second;
    return 0.0;
}

pub const ArachnidKind = enum { spider, cave_spider };

pub const ArachnidDimensions = struct {
    width: f32,
    height: f32,
    health: f32,

    pub fn forKind(kind: ArachnidKind) ArachnidDimensions {
        return switch (kind) {
            .spider => .{ .width = 1.4, .height = 0.9, .health = 16.0 },
            .cave_spider => .{ .width = 0.7, .height = 0.5, .health = 12.0 },
        };
    }

    /// A gap admits the entity when its width and height are both sufficient.
    pub fn fitsGap(self: ArachnidDimensions, gap_width: f32, gap_height: f32) bool {
        return self.width <= gap_width and self.height <= gap_height;
    }
};

pub const cave_spider_poison_easy_seconds: f32 = 0.0;
pub const cave_spider_poison_normal_seconds: f32 = 7.0;
pub const cave_spider_poison_hard_seconds: f32 = 15.0;

pub const Difficulty = enum { easy, normal, hard };

pub fn caveSpiderPoisonDuration(difficulty: Difficulty) f32 {
    return switch (difficulty) {
        .easy => cave_spider_poison_easy_seconds,
        .normal => cave_spider_poison_normal_seconds,
        .hard => cave_spider_poison_hard_seconds,
    };
}

pub const cave_spider_poison_immune: bool = true;
pub const cave_spider_cobweb_slowdown_immune: bool = true;

pub const JockeyRider = enum { skeleton, stray, wither_skeleton };
pub const SpiderJockeyBiome = enum { ordinary, icy, nether };
pub const spider_jockey_chance_percent: u8 = 1;

/// Rider selection for the 1% natural spider-jockey spawn roll. The spider
/// owns locomotion and climbing; its rider aims/fires independently.
pub const SpiderJockeyState = struct {
    has_rider: bool,
    rider: ?JockeyRider,
    spider_controls_movement: bool,
    spider_controls_wall_climbing: bool,
    rider_fires_arrows_independently: bool,

    pub fn fromSpawnRoll(roll_0_to_99: u8, biome: SpiderJockeyBiome) SpiderJockeyState {
        const spawned = roll_0_to_99 < spider_jockey_chance_percent;
        const rider: ?JockeyRider = if (!spawned) null else switch (biome) {
            .ordinary => .skeleton,
            .icy => .stray,
            .nether => .wither_skeleton,
        };
        return .{
            .has_rider = spawned,
            .rider = rider,
            .spider_controls_movement = true,
            .spider_controls_wall_climbing = true,
            .rider_fires_arrows_independently = true,
        };
    }
};

pub const HardModeSpiderBuff = enum { none, speed, strength, regeneration, invisibility };
pub const hard_mode_spider_buff_chance_percent: u8 = 10;

/// One in ten rolls receives a permanent buff; remaining rolls (and non-Hard
/// difficulty) have no buff. Input rolls outside 0..99 are treated as invalid.
pub fn rollHardModeSpiderBuff(is_hard: bool, roll: u8) HardModeSpiderBuff {
    if (!is_hard or roll >= 100 or roll >= hard_mode_spider_buff_chance_percent) return .none;
    return switch (roll % 4) {
        0 => .speed,
        1 => .strength,
        2 => .regeneration,
        3 => .invisibility,
        else => unreachable,
    };
}

/// Invisibility hides the body but leaves the spider's eyes visible/glowing.
pub fn spiderBuffHasVisibleRedEyes(buff: HardModeSpiderBuff) bool {
    return buff == .invisibility;
}

test "light threshold makes unprovoked spiders neutral at 12 and hostile in shadow" {
    try std.testing.expect(isSpiderHostileAtLightLevel(11, false));
    try std.testing.expect(!isSpiderHostileAtLightLevel(12, false));
    try std.testing.expect(!isSpiderHostileAtLightLevel(15, false));
    try std.testing.expect(isSpiderHostileAtLightLevel(0, false));
}

test "provoked spider remains hostile in bright light" {
    try std.testing.expect(isSpiderHostileAtLightLevel(12, true));
    try std.testing.expect(isSpiderHostileAtLightLevel(15, true));
}

test "spider re-aggros immediately on stepping into a dark shadow" {
    try std.testing.expect(!isSpiderHostileAtLightLevel(13, false));
    try std.testing.expect(isSpiderHostileAtLightLevel(11, false));
}

test "wall contact climbs at four meters per second" {
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), computeSpiderWallClimbVelocity(true, false), 0.001);
}

test "without wall contact spider does not climb" {
    try std.testing.expectEqual(@as(f32, 0.0), computeSpiderWallClimbVelocity(false, false));
}

test "overhanging lip or slab blocks wall climbing" {
    try std.testing.expectEqual(@as(f32, 0.0), computeSpiderWallClimbVelocity(true, true));
}

test "standard spider is 1.4 by 0.9 and fits a two-wide one-high gap" {
    const spider = ArachnidDimensions.forKind(.spider);
    try std.testing.expectEqual(@as(f32, 1.4), spider.width);
    try std.testing.expectEqual(@as(f32, 0.9), spider.height);
    try std.testing.expect(spider.fitsGap(2.0, 1.0));
}

test "standard spider is blocked by a one-by-one gap" {
    try std.testing.expect(!ArachnidDimensions.forKind(.spider).fitsGap(1.0, 1.0));
}

test "cave spider is 0.7 by 0.5 with twelve health and fits slab gap" {
    const cave_spider = ArachnidDimensions.forKind(.cave_spider);
    try std.testing.expectEqual(@as(f32, 0.7), cave_spider.width);
    try std.testing.expectEqual(@as(f32, 0.5), cave_spider.height);
    try std.testing.expectEqual(@as(f32, 12.0), cave_spider.health);
    try std.testing.expect(cave_spider.fitsGap(1.0, 0.5));
}

test "cave spider fails a gap shorter than a half block" {
    try std.testing.expect(!ArachnidDimensions.forKind(.cave_spider).fitsGap(1.0, 0.49));
}

test "cave spider is immune to poison and cobweb slowdown" {
    try std.testing.expect(cave_spider_poison_immune);
    try std.testing.expect(cave_spider_cobweb_slowdown_immune);
}

test "cave spider poison duration is zero on Easy" {
    try std.testing.expectEqual(@as(f32, 0.0), caveSpiderPoisonDuration(.easy));
}

test "cave spider poison duration is seven seconds on Normal" {
    try std.testing.expectEqual(@as(f32, 7.0), caveSpiderPoisonDuration(.normal));
}

test "cave spider poison duration is fifteen seconds on Hard" {
    try std.testing.expectEqual(@as(f32, 15.0), caveSpiderPoisonDuration(.hard));
}

test "one percent jockey roll selects skeleton rider in ordinary biome" {
    const jockey = SpiderJockeyState.fromSpawnRoll(0, .ordinary);
    try std.testing.expect(jockey.has_rider);
    try std.testing.expectEqual(JockeyRider.skeleton, jockey.rider.?);
}

test "jockey variant is stray in icy biomes" {
    try std.testing.expectEqual(JockeyRider.stray, SpiderJockeyState.fromSpawnRoll(0, .icy).rider.?);
}

test "jockey variant is wither skeleton in the Nether" {
    try std.testing.expectEqual(JockeyRider.wither_skeleton, SpiderJockeyState.fromSpawnRoll(0, .nether).rider.?);
}

test "jockey chance boundary and independent rider behavior" {
    const ordinary_spider = SpiderJockeyState.fromSpawnRoll(1, .ordinary);
    try std.testing.expect(!ordinary_spider.has_rider);
    try std.testing.expect(ordinary_spider.spider_controls_movement);
    try std.testing.expect(ordinary_spider.spider_controls_wall_climbing);
    try std.testing.expect(ordinary_spider.rider_fires_arrows_independently);
}

test "hard-mode spider buff rolls give speed and are absent outside Hard" {
    try std.testing.expectEqual(HardModeSpiderBuff.speed, rollHardModeSpiderBuff(true, 0));
    try std.testing.expectEqual(HardModeSpiderBuff.none, rollHardModeSpiderBuff(false, 0));
}

test "hard-mode spider buff rolls include strength and regeneration" {
    try std.testing.expectEqual(HardModeSpiderBuff.strength, rollHardModeSpiderBuff(true, 1));
    try std.testing.expectEqual(HardModeSpiderBuff.regeneration, rollHardModeSpiderBuff(true, 2));
}

test "hard-mode invisible spider retains visible red eyes" {
    const buff = rollHardModeSpiderBuff(true, 3);
    try std.testing.expectEqual(HardModeSpiderBuff.invisibility, buff);
    try std.testing.expect(spiderBuffHasVisibleRedEyes(buff));
}

test "hard-mode spider buff occurs on exactly the first ten percentage rolls" {
    var roll: u8 = 0;
    while (roll < 100) : (roll += 1) {
        try std.testing.expectEqual(roll < 10, rollHardModeSpiderBuff(true, roll) != .none);
    }
    try std.testing.expectEqual(HardModeSpiderBuff.none, rollHardModeSpiderBuff(true, 100));
}
