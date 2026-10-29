const std = @import("std");

pub const TICKS_PER_SECOND: u16 = 20;
pub const WITHER_SKELETON_HEIGHT_METERS: f32 = 2.4;
pub const WITHER_SKELETON_MAX_HEALTH: f32 = 20.0;
pub const WITHER_SKELETON_SPRINT_SPEED_MPS: f32 = 3.6;
pub const WITHER_DURATION_TICKS: u16 = 200;
pub const WITHER_DAMAGE_INTERVAL_TICKS: u16 = 40;
pub const WITHER_DAMAGE_HP: f32 = 1.0;
pub const WITHER_SKULL_BASE_CHANCE: f32 = 0.025;
pub const WITHER_SKULL_LOOTING_BONUS: f32 = 0.01;
pub const WITHER_SKELETON_EXPERIENCE: u8 = 5;

/// Numeric identifiers match the project's existing inventory and block enums.
/// These local declarations keep this rules module independently testable.
pub const ItemType = enum(u16) {
    wither_skeleton_skull = 67,
    stone_sword = 249,
};
pub const BlockId = enum(u8) { wither_skeleton_skull = 58 };

pub const Difficulty = enum { easy, normal, hard };
pub const HeartColor = enum { red, black };
pub const MeleeHit = struct { damage: f32, wither_ticks: u16 };

pub const WitherSkeleton = struct {
    health: f32 = WITHER_SKELETON_MAX_HEALTH,

    pub const height_meters = WITHER_SKELETON_HEIGHT_METERS;
    pub const max_health = WITHER_SKELETON_MAX_HEALTH;
    pub const sprint_speed_mps = WITHER_SKELETON_SPRINT_SPEED_MPS;
    pub const weapon = ItemType.stone_sword;
    pub const isImmuneToFire = true;
    pub const isImmuneToLava = true;

    pub fn canFitInClearance(clearance_meters: f32) bool {
        return clearance_meters >= height_meters;
    }

    pub fn applyFireOrLavaDamage(_: *WitherSkeleton, _: f32, _: bool) f32 {
        return 0.0;
    }

    pub fn meleeHit(_: WitherSkeleton, difficulty: Difficulty) MeleeHit {
        return .{
            .damage = switch (difficulty) {
                .easy => 5.0,
                .normal => 8.0,
                .hard => 12.0,
            },
            .wither_ticks = WITHER_DURATION_TICKS,
        };
    }
};

pub const WitherEffect = struct {
    ticks_remaining: u16 = WITHER_DURATION_TICKS,
    ticks_until_damage: u16 = WITHER_DAMAGE_INTERVAL_TICKS,

    pub const heart_color = HeartColor.black;
    pub const damage_per_tick: f32 = WITHER_DAMAGE_HP;
    pub const damage_interval_ticks = WITHER_DAMAGE_INTERVAL_TICKS;
    pub const damage_interval_seconds: f32 = @as(f32, WITHER_DAMAGE_INTERVAL_TICKS) / TICKS_PER_SECOND;

    pub fn isActive(self: WitherEffect) bool {
        return self.ticks_remaining > 0;
    }

    /// Ticks the effect and applies periodic damage. Unlike poison, health can reach zero.
    pub fn tick(self: *WitherEffect, health: *f32) f32 {
        if (!self.isActive()) return 0.0;
        self.ticks_remaining -= 1;
        self.ticks_until_damage -= 1;
        var damage: f32 = 0.0;
        if (self.ticks_until_damage == 0) {
            damage = @min(@max(0.0, health.*), damage_per_tick);
            health.* = @max(0.0, health.* - damage_per_tick);
            self.ticks_until_damage = damage_interval_ticks;
        }
        return damage;
    }

    pub fn cleanseWithMilk(self: *WitherEffect) void {
        self.ticks_remaining = 0;
        self.ticks_until_damage = damage_interval_ticks;
    }
};

pub fn poisonTickDamage(health: *f32, amount: f32) f32 {
    if (health.* <= 1.0) return 0.0;
    const damage = @min(health.* - 1.0, @max(0.0, amount));
    health.* -= damage;
    return damage;
}

pub const SkullDrop = struct {
    skull_count: u8 = 0,
    bones: u8 = 0,
    coal: u8 = 0,
    experience: u8 = WITHER_SKELETON_EXPERIENCE,
    item: ItemType = .wither_skeleton_skull,
    block: BlockId = .wither_skeleton_skull,
};

pub fn witherSkullDropChance(looting_level: u8) f32 {
    return WITHER_SKULL_BASE_CHANCE + WITHER_SKULL_LOOTING_BONUS * @as(f32, @floatFromInt(looting_level));
}

/// `roll` is in [0, 1). A charged Creeper kill always produces exactly one skull.
pub fn rollWitherSkeletonDrops(
    skull_roll: f32,
    bones_roll: f32,
    coal_roll: f32,
    looting_level: u8,
    killed_by_charged_creeper: bool,
) SkullDrop {
    const skull_count: u8 = if (killed_by_charged_creeper)
        1
    else if (skull_roll >= 0.0 and skull_roll < witherSkullDropChance(looting_level))
        1
    else
        0;
    const bones: u8 = if (bones_roll >= 0.0 and bones_roll < 1.0) @intFromFloat(@floor(bones_roll * 3.0)) else 0;
    const coal: u8 = if (coal_roll >= 0.0 and coal_roll < 0.5) 1 else 0;
    return .{ .skull_count = skull_count, .bones = bones, .coal = coal };
}

test "wither skeleton is 2.4 meters tall" {
    try std.testing.expectEqual(@as(f32, 2.4), WitherSkeleton.height_meters);
}

test "2.4 meter skeleton fits in a three meter space" {
    try std.testing.expect(WitherSkeleton.canFitInClearance(3.0));
}

test "2.4 meter skeleton is blocked by a two block ceiling" {
    try std.testing.expect(!WitherSkeleton.canFitInClearance(2.0));
}

test "height threshold is inclusive" {
    try std.testing.expect(WitherSkeleton.canFitInClearance(2.4));
    try std.testing.expect(!WitherSkeleton.canFitInClearance(2.399));
}

test "wither skeleton has twenty hp" {
    try std.testing.expectEqual(@as(f32, 20.0), (WitherSkeleton{}).health);
    try std.testing.expectEqual(@as(f32, 20.0), WitherSkeleton.max_health);
}

test "wither skeleton sprint speed is 3.6 meters per second" {
    try std.testing.expectEqual(@as(f32, 3.6), WitherSkeleton.sprint_speed_mps);
}

test "wither skeleton wields a stone sword" {
    try std.testing.expectEqual(ItemType.stone_sword, WitherSkeleton.weapon);
}

test "undead skeleton is fire immune" {
    try std.testing.expect(WitherSkeleton.isImmuneToFire);
}

test "undead skeleton is lava immune" {
    try std.testing.expect(WitherSkeleton.isImmuneToLava);
}

test "fire damage is ignored" {
    var mob = WitherSkeleton{};
    try std.testing.expectEqual(@as(f32, 0.0), mob.applyFireOrLavaDamage(12.0, false));
    try std.testing.expectEqual(WITHER_SKELETON_MAX_HEALTH, mob.health);
}

test "lava damage is ignored" {
    var mob = WitherSkeleton{};
    try std.testing.expectEqual(@as(f32, 0.0), mob.applyFireOrLavaDamage(20.0, true));
    try std.testing.expectEqual(WITHER_SKELETON_MAX_HEALTH, mob.health);
}

test "easy melee hit deals five hp and applies Wither I" {
    const hit = (WitherSkeleton{}).meleeHit(.easy);
    try std.testing.expectEqual(@as(f32, 5.0), hit.damage);
    try std.testing.expectEqual(@as(u16, 200), hit.wither_ticks);
}

test "normal melee hit deals eight hp and applies Wither I" {
    const hit = (WitherSkeleton{}).meleeHit(.normal);
    try std.testing.expectEqual(@as(f32, 8.0), hit.damage);
    try std.testing.expectEqual(WITHER_DURATION_TICKS, hit.wither_ticks);
}

test "hard melee hit deals twelve hp and applies Wither I" {
    const hit = (WitherSkeleton{}).meleeHit(.hard);
    try std.testing.expectEqual(@as(f32, 12.0), hit.damage);
    try std.testing.expectEqual(WITHER_DURATION_TICKS, hit.wither_ticks);
}

test "Wither I lasts ten seconds at twenty ticks per second" {
    try std.testing.expectEqual(@as(u16, 200), WITHER_DURATION_TICKS);
    try std.testing.expectEqual(@as(f32, 10.0), @as(f32, WITHER_DURATION_TICKS) / TICKS_PER_SECOND);
}

test "Wither effect sets hearts to black" {
    try std.testing.expectEqual(HeartColor.black, WitherEffect.heart_color);
}

test "Wither drains one hp every forty ticks" {
    try std.testing.expectEqual(@as(f32, 1.0), WitherEffect.damage_per_tick);
    try std.testing.expectEqual(@as(u16, 40), WitherEffect.damage_interval_ticks);
    try std.testing.expectEqual(@as(f32, 2.0), WitherEffect.damage_interval_seconds);
}

test "Wither has no damage during the first thirty nine ticks" {
    var effect = WitherEffect{};
    var health: f32 = 20.0;
    for (0..39) |_| try std.testing.expectEqual(@as(f32, 0.0), effect.tick(&health));
    try std.testing.expectEqual(@as(f32, 20.0), health);
}

test "Wither applies the first damage on tick forty" {
    var effect = WitherEffect{};
    var health: f32 = 20.0;
    for (0..40) |_| _ = effect.tick(&health);
    try std.testing.expectEqual(@as(f32, 19.0), health);
}

test "Wither applies five periodic damage ticks over its duration" {
    var effect = WitherEffect{};
    var health: f32 = 20.0;
    for (0..200) |_| _ = effect.tick(&health);
    try std.testing.expectEqual(@as(f32, 15.0), health);
    try std.testing.expect(!effect.isActive());
}

test "Wither is lethal where poison stops at one hp" {
    var wither = WitherEffect{};
    var wither_health: f32 = 0.5;
    for (0..40) |_| _ = wither.tick(&wither_health);
    try std.testing.expectEqual(@as(f32, 0.0), wither_health);
    var poison_health: f32 = 0.5;
    try std.testing.expectEqual(@as(f32, 0.0), poisonTickDamage(&poison_health, 1.0));
    try std.testing.expectEqual(@as(f32, 0.5), poison_health);
}

test "Wither damage clamps health at zero" {
    var effect = WitherEffect{};
    var health: f32 = 0.25;
    for (0..40) |_| _ = effect.tick(&health);
    try std.testing.expectEqual(@as(f32, 0.0), health);
}

test "milk instantly cleanses Wither" {
    var effect = WitherEffect{};
    effect.cleanseWithMilk();
    try std.testing.expect(!effect.isActive());
    var health: f32 = 20.0;
    for (0..40) |_| try std.testing.expectEqual(@as(f32, 0.0), effect.tick(&health));
    try std.testing.expectEqual(@as(f32, 20.0), health);
}

test "Wither does not damage health after expiration" {
    var effect = WitherEffect{ .ticks_remaining = 0 };
    var health: f32 = 4.0;
    try std.testing.expectEqual(@as(f32, 0.0), effect.tick(&health));
    try std.testing.expectEqual(@as(f32, 4.0), health);
}

test "base Wither Skeleton skull probability is 2.5 percent" {
    try std.testing.expectEqual(@as(f32, 0.025), witherSkullDropChance(0));
}

test "Looting I raises skull chance to 3.5 percent" {
    try std.testing.expectEqual(@as(f32, 0.035), witherSkullDropChance(1));
}

test "Looting II raises skull chance to 4.5 percent" {
    try std.testing.expectEqual(@as(f32, 0.045), witherSkullDropChance(2));
}

test "Looting III raises skull chance to 5.5 percent" {
    try std.testing.expectEqual(@as(f32, 0.055), witherSkullDropChance(3));
}

test "skull roll immediately below base chance succeeds" {
    try std.testing.expectEqual(@as(u8, 1), rollWitherSkeletonDrops(0.02499, 1.0, 1.0, 0, false).skull_count);
}

test "skull roll at base chance fails" {
    try std.testing.expectEqual(@as(u8, 0), rollWitherSkeletonDrops(0.025, 1.0, 1.0, 0, false).skull_count);
}

test "Looting III skull roll succeeds through 5.49 percent" {
    try std.testing.expectEqual(@as(u8, 1), rollWitherSkeletonDrops(0.0549, 1.0, 1.0, 3, false).skull_count);
}

test "charged Creeper kill guarantees exactly one skull regardless of roll" {
    const drop = rollWitherSkeletonDrops(0.99, 0.0, 0.99, 3, true);
    try std.testing.expectEqual(@as(u8, 1), drop.skull_count);
    try std.testing.expectEqual(ItemType.wither_skeleton_skull, drop.item);
    try std.testing.expectEqual(BlockId.wither_skeleton_skull, drop.block);
}

test "regular drop table awards zero to two bones" {
    try std.testing.expectEqual(@as(u8, 0), rollWitherSkeletonDrops(1.0, 0.0, 1.0, 0, false).bones);
    try std.testing.expectEqual(@as(u8, 1), rollWitherSkeletonDrops(1.0, 0.5, 1.0, 0, false).bones);
    try std.testing.expectEqual(@as(u8, 2), rollWitherSkeletonDrops(1.0, 0.99, 1.0, 0, false).bones);
}

test "regular drop table awards zero or one coal" {
    try std.testing.expectEqual(@as(u8, 0), rollWitherSkeletonDrops(1.0, 1.0, 0.5, 0, false).coal);
    try std.testing.expectEqual(@as(u8, 1), rollWitherSkeletonDrops(1.0, 1.0, 0.49, 0, false).coal);
}

test "regular drop table awards five experience" {
    try std.testing.expectEqual(@as(u8, 5), rollWitherSkeletonDrops(1.0, 1.0, 1.0, 0, false).experience);
}
