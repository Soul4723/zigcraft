const std = @import("std");

/// The module has a standalone `zig test src/world/...` target, so item IDs are
/// mirrored here instead of importing inventory across Zig's module boundary.
pub const ItemType = enum(u16) {
    arrow = 97,
    iron_ingot = 26,
    golden_carrot = 332,
    baked_potato = 343,
    emerald = 273,
    wind_charge = 372,
    heavy_core = 373,
    mace = 374,
    enchanted_golden_apple = 379,
    trial_key = 376,
    ominous_trial_key = 416,
};

pub const DETECTION_RADIUS: f32 = 14.0;
pub const DETECTION_RADIUS_SQ: f32 = 196.0;
pub const TICKS_PER_SECOND: u32 = 20;
pub const SPAWN_INTERVAL_TICKS: u32 = 40;
pub const COOLDOWN_TICKS: u32 = 36_000;
pub const HAZARD_INTERVAL_TICKS: u32 = 160;
pub const STANDARD_KEY_CHANCE: f32 = 0.50;
pub const OMINOUS_KEY_CHANCE: f32 = 0.30;

pub const State = enum { inactive, waiting_for_players, active, waiting_for_reward_ejection, cooldown };
pub const PlayerMode = enum { survival, adventure, creative, spectator };

pub const Player = struct {
    position: [3]f32,
    mode: PlayerMode = .survival,
    trial_omen: bool = false,
};

pub const MobCategory = enum { melee, small_melee, ranged };
pub const MobType = enum { zombie, husk, slime, spider, baby_zombie, cave_spider, silverfish, skeleton, stray, bogged };

pub fn mobCategory(mob: MobType) MobCategory {
    return switch (mob) {
        .zombie, .husk, .slime, .spider => .melee,
        .baby_zombie, .cave_spider, .silverfish => .small_melee,
        .skeleton, .stray, .bogged => .ranged,
    };
}

pub fn scaledCount(base: u32, players: u32) u32 {
    if (players == 0) return 0;
    const multiplier = 1.0 + 0.5 * @as(f64, @floatFromInt(players - 1));
    return @intFromFloat(@floor(@as(f64, @floatFromInt(base)) * multiplier));
}

pub const SpawnEvent = struct {
    mob: MobType,
    category: MobCategory,
    position: [3]f32,
    armored_and_armed: bool,
};

pub const HazardType = enum { fire_charge, wind_charge, lingering_potion_cloud };
pub const HazardEvent = struct { kind: HazardType, target_player_index: usize };
pub const TickResult = struct {
    activated: bool = false,
    ignition_particles: bool = false,
    activation_sound: bool = false,
    spawn: ?SpawnEvent = null,
    hazard: ?HazardEvent = null,
    venting_ominous_smoke: bool = false,
};

pub const Reward = struct {
    item: ItemType,
    count: u8 = 1,
    key_dropped: bool = false,
};

pub const RewardEjection = struct {
    bundles: u32,
    item: ItemType,
    key_item: ?ItemType,
    position: [3]f32,
    velocity: [3]f32,
};

pub fn rewardForRoll(ominous: bool, reward_roll: f32, key_roll: f32) Reward {
    const normal = [_]ItemType{ .baked_potato, .golden_carrot, .arrow, .iron_ingot, .emerald };
    const high_tier = [_]ItemType{ .enchanted_golden_apple, .heavy_core, .mace, .wind_charge };
    const items = if (ominous) high_tier[0..] else normal[0..];
    const normalized = std.math.clamp(reward_roll, 0.0, 0.999999);
    const index: usize = @intFromFloat(normalized * @as(f32, @floatFromInt(items.len)));
    const key_dropped = key_roll < (if (ominous) OMINOUS_KEY_CHANCE else STANDARD_KEY_CHANCE);
    return .{
        .item = items[index],
        .key_dropped = key_dropped,
        .count = 1,
    };
}

pub const TrialSpawner = struct {
    position: [3]f32,
    base_total_mobs: u32 = 6,
    base_simultaneous: u32 = 2,
    state: State = .inactive,
    is_ominous: bool = false,
    total_mobs: u32 = 0,
    mobs_spawned: u32 = 0,
    mobs_alive: u32 = 0,
    participating_players: u32 = 0,
    cooldown_remaining: u32 = 0,
    spawn_ticks_remaining: u32 = SPAWN_INTERVAL_TICKS,
    hazard_ticks_remaining: u32 = HAZARD_INTERVAL_TICKS,
    hazard_cycle: u32 = 0,
    rewards_ejected: u32 = 0,

    pub fn init(x: f32, y: f32, z: f32) TrialSpawner {
        return .{ .position = .{ x, y, z } };
    }

    pub fn nearbyPlayerCount(self: TrialSpawner, players: []const Player) u32 {
        var count: u32 = 0;
        for (players) |player| {
            if (!countsForTrial(player.mode)) continue;
            if (isWithinDetectionRadius(player.position, self.position)) count += 1;
        }
        return count;
    }

    pub fn tick(self: *TrialSpawner, players: []const Player) TickResult {
        var result = TickResult{};
        switch (self.state) {
            .inactive => {
                const count = self.nearbyPlayerCount(players);
                if (count == 0) return result;
                self.participating_players = count;
                self.is_ominous = false;
                for (players) |player| {
                    if (countsForTrial(player.mode) and isWithinDetectionRadius(player.position, self.position) and player.trial_omen) {
                        self.is_ominous = true;
                        break;
                    }
                }
                self.state = .waiting_for_players;
                result.activated = true;
                result.ignition_particles = true;
                result.activation_sound = true;
            },
            .waiting_for_players => {
                const count = self.nearbyPlayerCount(players);
                if (count == 0) {
                    self.state = .inactive;
                    self.participating_players = 0;
                    return result;
                }
                self.participating_players = count;
                for (players) |player| {
                    if (countsForTrial(player.mode) and isWithinDetectionRadius(player.position, self.position) and player.trial_omen) {
                        self.is_ominous = true;
                        break;
                    }
                }
                self.total_mobs = scaledCount(self.base_total_mobs, count);
                self.mobs_spawned = 0;
                self.mobs_alive = 0;
                self.rewards_ejected = 0;
                self.spawn_ticks_remaining = SPAWN_INTERVAL_TICKS;
                self.hazard_ticks_remaining = HAZARD_INTERVAL_TICKS;
                self.state = .active;
            },
            .active => self.tickActive(players, &result),
            .waiting_for_reward_ejection => {},
            .cooldown => {
                result.venting_ominous_smoke = self.is_ominous;
                if (self.cooldown_remaining > 0) self.cooldown_remaining -= 1;
                if (self.cooldown_remaining == 0) self.state = .inactive;
            },
        }
        return result;
    }

    fn tickActive(self: *TrialSpawner, players: []const Player, result: *TickResult) void {
        if (self.is_ominous) {
            if (self.hazard_ticks_remaining > 0) self.hazard_ticks_remaining -= 1;
            if (self.hazard_ticks_remaining == 0) {
                if (self.nextNearbyPlayerIndex(players)) |target| {
                    const kind: HazardType = switch (self.hazard_cycle % 3) {
                        0 => .fire_charge,
                        1 => .wind_charge,
                        else => .lingering_potion_cloud,
                    };
                    result.hazard = .{ .kind = kind, .target_player_index = target };
                }
                self.hazard_cycle +%= 1;
                self.hazard_ticks_remaining = HAZARD_INTERVAL_TICKS;
            }
        }
        if (self.mobs_spawned >= self.total_mobs) return;
        if (self.spawn_ticks_remaining > 0) {
            self.spawn_ticks_remaining -= 1;
            if (self.spawn_ticks_remaining > 0) return;
        }
        const mob_cap = scaledCount(self.base_simultaneous, self.participating_players);
        if (self.mobs_alive >= mob_cap) return;
        const mob = mobAt(self.mobs_spawned);
        result.spawn = .{
            .mob = mob,
            .category = mobCategory(mob),
            .position = .{ self.position[0], self.position[1] + 1.0, self.position[2] },
            .armored_and_armed = self.is_ominous,
        };
        self.mobs_spawned += 1;
        self.mobs_alive += 1;
        self.spawn_ticks_remaining = SPAWN_INTERVAL_TICKS;
    }

    fn nextNearbyPlayerIndex(self: TrialSpawner, players: []const Player) ?usize {
        const count = self.nearbyPlayerCount(players);
        if (count == 0) return null;
        const target_slot = self.hazard_cycle % count;
        var seen: u32 = 0;
        for (players, 0..) |player, index| {
            if (!countsForTrial(player.mode) or !isWithinDetectionRadius(player.position, self.position)) continue;
            if (seen == target_slot) return index;
            seen += 1;
        }
        return null;
    }

    pub fn mobDefeated(self: *TrialSpawner) void {
        if (self.state != .active or self.mobs_alive == 0) return;
        self.mobs_alive -= 1;
        if (self.mobs_spawned == self.total_mobs and self.mobs_alive == 0) self.state = .waiting_for_reward_ejection;
    }

    pub fn ejectRewards(self: *TrialSpawner, reward_roll: f32, key_roll: f32) ?RewardEjection {
        if (self.state != .waiting_for_reward_ejection) return null;
        const reward = rewardForRoll(self.is_ominous, reward_roll, key_roll);
        const key: ?ItemType = if (reward.key_dropped)
            (if (self.is_ominous) .ominous_trial_key else .trial_key)
        else
            null;
        self.rewards_ejected += 1;
        if (self.rewards_ejected >= self.participating_players) {
            self.state = .cooldown;
            self.cooldown_remaining = COOLDOWN_TICKS;
        }
        return .{
            .bundles = 1,
            .item = reward.item,
            .key_item = key,
            .position = .{ self.position[0], self.position[1] + 1.0, self.position[2] },
            .velocity = .{ 0.0, 0.4, 0.0 },
        };
    }

    pub fn lightLevel(self: TrialSpawner) u8 {
        return switch (self.state) { .inactive, .cooldown => 0, .waiting_for_players, .active, .waiting_for_reward_ejection => 15 };
    }

    pub fn simultaneousMobCap(self: TrialSpawner) u32 {
        return scaledCount(self.base_simultaneous, self.participating_players);
    }
};

pub fn isWithinDetectionRadius(player: [3]f32, spawner: [3]f32) bool {
    const dx = player[0] - spawner[0];
    const dy = player[1] - spawner[1];
    const dz = player[2] - spawner[2];
    return dx * dx + dy * dy + dz * dz <= DETECTION_RADIUS_SQ;
}

fn countsForTrial(mode: PlayerMode) bool {
    return mode == .survival or mode == .adventure;
}

fn mobAt(index: u32) MobType {
    const mobs = [_]MobType{ .zombie, .husk, .slime, .spider, .baby_zombie, .cave_spider, .silverfish, .skeleton, .stray, .bogged };
    return mobs[index % mobs.len];
}

test "detection includes the 14 block Euclidean boundary" {
    try std.testing.expect(isWithinDetectionRadius(.{ 14, 0, 0 }, .{ 0, 0, 0 }));
    try std.testing.expect(isWithinDetectionRadius(.{ 8, 8, 8 }, .{ 0, 0, 0 }));
    try std.testing.expect(!isWithinDetectionRadius(.{ 14.01, 0, 0 }, .{ 0, 0, 0 }));
}

test "inactive spawner activates only for nearby survival or adventure players" {
    var spawner = TrialSpawner.init(0, 64, 0);
    const far = [_]Player{.{ .position = .{ 15, 64, 0 } }};
    try std.testing.expect(!spawner.tick(&far).activated);
    try std.testing.expectEqual(State.inactive, spawner.state);
    const nearby = [_]Player{.{ .position = .{ 1, 64, 0 } }};
    const activation = spawner.tick(&nearby);
    try std.testing.expect(activation.activated);
    try std.testing.expect(activation.ignition_particles);
    try std.testing.expect(activation.activation_sound);
    try std.testing.expectEqual(State.waiting_for_players, spawner.state);
}

test "creative and spectator players do not trigger or scale a trial" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const players = [_]Player{ .{ .position = .{ 0, 0, 0 }, .mode = .creative }, .{ .position = .{ 0, 0, 0 }, .mode = .spectator } };
    try std.testing.expectEqual(@as(u32, 0), spawner.nearbyPlayerCount(&players));
    _ = spawner.tick(&players);
    try std.testing.expectEqual(State.inactive, spawner.state);
}

test "scales total mob counts for one through five players" {
    const expected = [_]u32{ 6, 9, 12, 15, 18 };
    for (expected, 1..) |value, players| try std.testing.expectEqual(value, scaledCount(6, @intCast(players)));
}

test "scales simultaneous mob cap for one through five players" {
    const expected = [_]u32{ 2, 3, 4, 5, 6 };
    for (expected, 1..) |value, players| try std.testing.expectEqual(value, scaledCount(2, @intCast(players)));
}

test "zero players have no scaled spawn budget" {
    try std.testing.expectEqual(@as(u32, 0), scaledCount(6, 0));
}

test "state lifecycle reaches reward ejection and cooldown" {
    var spawner = TrialSpawner.init(0, 64, 0);
    spawner.base_total_mobs = 1;
    const players = [_]Player{.{ .position = .{ 0, 64, 0 } }};
    _ = spawner.tick(&players);
    _ = spawner.tick(&players);
    try std.testing.expectEqual(State.active, spawner.state);
    for (0..SPAWN_INTERVAL_TICKS) |_| {
        if (spawner.tick(&players).spawn != null) break;
    }
    spawner.mobDefeated();
    try std.testing.expectEqual(State.waiting_for_reward_ejection, spawner.state);
    _ = spawner.ejectRewards(0.1, 0.9).?;
    try std.testing.expectEqual(State.cooldown, spawner.state);
    try std.testing.expectEqual(@as(u32, COOLDOWN_TICKS), spawner.cooldown_remaining);
}

test "waiting activation cancels if players leave before the active state" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const nearby = [_]Player{.{ .position = .{ 0, 0, 0 } }};
    const none = [_]Player{};
    _ = spawner.tick(&nearby);
    _ = spawner.tick(&none);
    try std.testing.expectEqual(State.inactive, spawner.state);
}

test "cooldown holds activation lock for exactly 36000 ticks" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .cooldown;
    spawner.cooldown_remaining = COOLDOWN_TICKS;
    const nearby = [_]Player{.{ .position = .{ 0, 0, 0 } }};
    for (0..COOLDOWN_TICKS - 1) |_| {
        _ = spawner.tick(&nearby);
        try std.testing.expectEqual(State.cooldown, spawner.state);
    }
    _ = spawner.tick(&nearby);
    try std.testing.expectEqual(State.inactive, spawner.state);
    try std.testing.expect(spawner.tick(&nearby).activated);
    try std.testing.expectEqual(State.waiting_for_players, spawner.state);
}

test "spawn cadence is 40 ticks and mob emerges above the top face" {
    var spawner = TrialSpawner.init(2, 30, 4);
    spawner.state = .active;
    spawner.total_mobs = 1;
    spawner.participating_players = 1;
    var spawned: ?SpawnEvent = null;
    for (0..SPAWN_INTERVAL_TICKS - 1) |_| spawned = spawner.tick(&.{}).spawn;
    try std.testing.expect(spawned == null);
    spawned = spawner.tick(&.{}).spawn;
    try std.testing.expectEqual(@as(f32, 31), spawned.?.position[1]);
}

test "simultaneous cap blocks additional spawns until a mob is defeated" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.participating_players = 1;
    spawner.total_mobs = 3;
    for (0..SPAWN_INTERVAL_TICKS) |_| _ = spawner.tick(&.{});
    try std.testing.expectEqual(@as(u32, 1), spawner.mobs_alive);
    spawner.spawn_ticks_remaining = 0;
    try std.testing.expect(spawner.tick(&.{}).spawn != null);
    try std.testing.expectEqual(@as(u32, 2), spawner.mobs_alive);
    spawner.spawn_ticks_remaining = 0;
    _ = spawner.tick(&.{});
    try std.testing.expectEqual(@as(u32, 2), spawner.mobs_alive);
    spawner.mobDefeated();
    const event = spawner.tick(&.{}).spawn;
    try std.testing.expect(event != null);
}

test "reward waits until every scaled mob has spawned and died" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.participating_players = 1;
    spawner.total_mobs = 2;
    spawner.mobs_spawned = 2;
    spawner.mobs_alive = 2;
    spawner.mobDefeated();
    try std.testing.expectEqual(State.active, spawner.state);
    spawner.mobDefeated();
    try std.testing.expectEqual(State.waiting_for_reward_ejection, spawner.state);
}

test "defeated mobs do not underflow living count" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.mobDefeated();
    try std.testing.expectEqual(@as(u32, 0), spawner.mobs_alive);
}

test "reward ejection velocity points upward at 0.4 meters per second" {
    var spawner = TrialSpawner.init(1, 20, 3);
    spawner.state = .waiting_for_reward_ejection;
    spawner.participating_players = 3;
    const reward = spawner.ejectRewards(0.4, 0.9).?;
    try std.testing.expectEqualSlices(f32, &.{ 0, 0.4, 0 }, &reward.velocity);
    try std.testing.expectEqual(@as(f32, 21), reward.position[1]);
    try std.testing.expectEqual(@as(u32, 1), reward.bundles);
    try std.testing.expectEqual(State.waiting_for_reward_ejection, spawner.state);
    _ = spawner.ejectRewards(0.4, 0.9).?;
    _ = spawner.ejectRewards(0.4, 0.9).?;
    try std.testing.expectEqual(State.cooldown, spawner.state);
}

test "reward ejection is unavailable before the trial completes" {
    var spawner = TrialSpawner.init(0, 0, 0);
    try std.testing.expect(spawner.ejectRewards(0, 0) == null);
}

test "standard key chance boundary is fifty percent" {
    try std.testing.expect(rewardForRoll(false, 0.2, 0.4999).key_dropped);
    try std.testing.expect(!rewardForRoll(false, 0.2, 0.5).key_dropped);
}

test "standard reward pool contains baked potato carrot arrows iron and emerald" {
    const expected = [_]ItemType{ .baked_potato, .golden_carrot, .arrow, .iron_ingot, .emerald };
    for (expected, 0..) |item, i| {
        const result = rewardForRoll(false, (@as(f32, @floatFromInt(i)) + 0.1) / 5.0, 0.9);
        try std.testing.expectEqual(item, result.item);
    }
}

test "trial omen transforms an approaching player to ominous mode" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const players = [_]Player{.{ .position = .{ 0, 0, 0 }, .trial_omen = true }};
    _ = spawner.tick(&players);
    try std.testing.expect(spawner.is_ominous);
    _ = spawner.tick(&players);
    for (0..SPAWN_INTERVAL_TICKS) |_| {
        const event = spawner.tick(&players).spawn;
        if (event) |spawn| {
            try std.testing.expect(spawn.armored_and_armed);
            break;
        }
    }
}

test "standard nearby players do not transform spawner to ominous" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const players = [_]Player{.{ .position = .{ 0, 0, 0 } }};
    _ = spawner.tick(&players);
    try std.testing.expect(!spawner.is_ominous);
}

test "ominous key chance boundary is thirty percent" {
    try std.testing.expect(rewardForRoll(true, 0.2, 0.2999).key_dropped);
    try std.testing.expect(!rewardForRoll(true, 0.2, 0.30).key_dropped);
}

test "ominous reward table can eject enchanted golden apples" {
    try std.testing.expectEqual(ItemType.enchanted_golden_apple, rewardForRoll(true, 0.1, 0.9).item);
    try std.testing.expectEqual(ItemType.heavy_core, rewardForRoll(true, 0.3, 0.9).item);
    try std.testing.expectEqual(ItemType.mace, rewardForRoll(true, 0.6, 0.9).item);
    try std.testing.expectEqual(ItemType.wind_charge, rewardForRoll(true, 0.9, 0.9).item);
}

test "ominous hazards target nearby players periodically" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.is_ominous = true;
    const players = [_]Player{ .{ .position = .{ 0, 0, 0 } }, .{ .position = .{ 1, 0, 0 } } };
    var hazard: ?HazardEvent = null;
    for (0..HAZARD_INTERVAL_TICKS) |_| hazard = spawner.tick(&players).hazard;
    try std.testing.expect(hazard != null);
    try std.testing.expect(hazard.?.target_player_index < players.len);
}

test "ominous hazards do not target an absent or ineligible player" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.is_ominous = true;
    const players = [_]Player{.{ .position = .{ 0, 0, 0 }, .mode = .spectator }};
    var hazard: ?HazardEvent = null;
    for (0..HAZARD_INTERVAL_TICKS) |_| hazard = spawner.tick(&players).hazard;
    try std.testing.expect(hazard == null);
}

test "cooldown emits ominous smoke and suppresses hazards" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .cooldown;
    spawner.is_ominous = true;
    spawner.cooldown_remaining = 3;
    const result = spawner.tick(&.{});
    try std.testing.expect(result.venting_ominous_smoke);
    try std.testing.expect(result.hazard == null);
}

test "all supported mob categories are assigned" {
    try std.testing.expectEqual(MobCategory.melee, mobCategory(.zombie));
    try std.testing.expectEqual(MobCategory.melee, mobCategory(.husk));
    try std.testing.expectEqual(MobCategory.melee, mobCategory(.slime));
    try std.testing.expectEqual(MobCategory.melee, mobCategory(.spider));
    try std.testing.expectEqual(MobCategory.small_melee, mobCategory(.baby_zombie));
    try std.testing.expectEqual(MobCategory.small_melee, mobCategory(.cave_spider));
    try std.testing.expectEqual(MobCategory.small_melee, mobCategory(.silverfish));
    try std.testing.expectEqual(MobCategory.ranged, mobCategory(.skeleton));
    try std.testing.expectEqual(MobCategory.ranged, mobCategory(.stray));
    try std.testing.expectEqual(MobCategory.ranged, mobCategory(.bogged));
}

test "light is dark while inactive and during cooldown" {
    var spawner = TrialSpawner.init(0, 0, 0);
    try std.testing.expectEqual(@as(u8, 0), spawner.lightLevel());
    spawner.state = .active;
    try std.testing.expectEqual(@as(u8, 15), spawner.lightLevel());
    spawner.state = .cooldown;
    try std.testing.expectEqual(@as(u8, 0), spawner.lightLevel());
}

test "reward ejection selects correct standard and ominous key item types" {
    var normal = TrialSpawner.init(0, 0, 0);
    normal.state = .waiting_for_reward_ejection;
    try std.testing.expectEqual(ItemType.trial_key, normal.ejectRewards(0.2, 0.1).?.key_item.?);
    var ominous = TrialSpawner.init(0, 0, 0);
    ominous.state = .waiting_for_reward_ejection;
    ominous.is_ominous = true;
    try std.testing.expectEqual(ItemType.ominous_trial_key, ominous.ejectRewards(0.2, 0.1).?.key_item.?);
}

test "reward roll endpoints clamp into valid item pool" {
    try std.testing.expectEqual(ItemType.baked_potato, rewardForRoll(false, -1, 0.9).item);
    try std.testing.expectEqual(ItemType.emerald, rewardForRoll(false, 1, 0.9).item);
}

test "participating player count uses only eligible players in radius" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const players = [_]Player{
        .{ .position = .{ 0, 0, 0 } },
        .{ .position = .{ 14, 0, 0 }, .mode = .adventure },
        .{ .position = .{ 0, 0, 0 }, .mode = .creative },
        .{ .position = .{ 15, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u32, 2), spawner.nearbyPlayerCount(&players));
}

test "an ominous reward key roll above threshold drops no key" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .waiting_for_reward_ejection;
    spawner.is_ominous = true;
    try std.testing.expect(spawner.ejectRewards(0.5, 0.31).?.key_item == null);
}
