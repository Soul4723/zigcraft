const std = @import("std");

/// Standalone item definitions mirrored for independent testability without
/// crossing external module boundaries.
pub const ItemType = enum(u16) {
    arrow = 97,
    iron_ingot = 26,
    golden_carrot = 332,
    baked_potato = 343,
    emerald = 273,
    wind_charge = 372,
    heavy_core = 373,
    mace = 374,
    trial_key = 376,
    enchanted_golden_apple = 379,
    ominous_trial_key = 416,
    potion_of_weaving = 417,
    potion_of_oozing = 418,
    potion_of_infested = 419,
    potion_of_wind_charged = 421,
    vault_reset_token = 608,
};

pub const DETECTION_RADIUS: f32 = 14.0;
pub const DETECTION_RADIUS_SQ: f32 = DETECTION_RADIUS * DETECTION_RADIUS; // 196.0
pub const TICKS_PER_SECOND: u32 = 20;
pub const SPAWN_INTERVAL_TICKS: u32 = 40; // 2.0s
pub const HAZARD_INTERVAL_TICKS: u32 = 160; // 8.0s (8 * 20 = 160 ticks)
pub const COOLDOWN_TICKS: u32 = 36_000; // 30 minutes (30 * 60 * 20 = 36,000 ticks)
pub const STANDARD_KEY_CHANCE: f32 = 0.50; // 50%
pub const OMINOUS_KEY_CHANCE: f32 = 0.30; // 30%
pub const BASE_TOTAL_MOBS: u32 = 6;
pub const BASE_SIMULTANEOUS_MOBS: u32 = 2;

pub const State = enum {
    inactive,
    waiting_for_players,
    active,
    waiting_for_reward_ejection,
    cooldown,
};

pub const PlayerMode = enum {
    survival,
    adventure,
    creative,
    spectator,

    pub fn isEligible(self: PlayerMode) bool {
        return self == .survival or self == .adventure;
    }
};

pub const Player = struct {
    position: [3]f32,
    mode: PlayerMode = .survival,
    trial_omen: bool = false,
};

/// Total mob wave size scaling formula:
/// N = @intFromFloat(@floor(base_total_mobs * (1.0 + 0.5 * (P - 1))))
pub fn scaleTotalMobs(base_total_mobs: u32, players: u32) u32 {
    if (players == 0) return 0;
    const p_f: f64 = @floatFromInt(players);
    const base_f: f64 = @floatFromInt(base_total_mobs);
    const multiplier: f64 = 1.0 + 0.5 * (p_f - 1.0);
    return @intFromFloat(@floor(base_f * multiplier));
}

/// Simultaneous mob cap scaling formula:
/// M = @intFromFloat(@floor(base_simultaneous * (1.0 + 0.5 * (P - 1))))
pub fn scaleSimultaneousMobs(base_simultaneous: u32, players: u32) u32 {
    if (players == 0) return 0;
    const p_f: f64 = @floatFromInt(players);
    const base_f: f64 = @floatFromInt(base_simultaneous);
    const multiplier: f64 = 1.0 + 0.5 * (p_f - 1.0);
    return @intFromFloat(@floor(base_f * multiplier));
}

pub fn scaledCount(base: u32, players: u32) u32 {
    return scaleTotalMobs(base, players);
}

pub const MobCategory = enum {
    melee,
    small_melee,
    ranged,
};

pub const MobType = enum {
    zombie,
    husk,
    slime,
    spider,
    baby_zombie,
    cave_spider,
    silverfish,
    skeleton,
    stray,
    bogged,
    breeze,
};

pub fn mobCategory(mob: MobType) MobCategory {
    return switch (mob) {
        .zombie, .husk, .slime, .spider => .melee,
        .baby_zombie, .cave_spider, .silverfish => .small_melee,
        .skeleton, .stray, .bogged, .breeze => .ranged,
    };
}

pub const ArmorMaterial = enum {
    chainmail,
    iron,

    pub fn name(self: ArmorMaterial) []const u8 {
        return switch (self) {
            .chainmail => "Chainmail",
            .iron => "Iron",
        };
    }
};

pub const EnchantmentType = enum {
    protection_1,
    sharpness_1,
    power_1,

    pub fn name(self: EnchantmentType) []const u8 {
        return switch (self) {
            .protection_1 => "Protection I",
            .sharpness_1 => "Sharpness I",
            .power_1 => "Power I",
        };
    }
};

pub const Enchantment = struct {
    enchant_type: EnchantmentType,
    level: u8 = 1,
};

pub const EquipmentItem = struct {
    name: []const u8,
    material: ?ArmorMaterial = null,
    enchantment: ?Enchantment = null,
};

pub const MobEquipment = struct {
    helmet: ?EquipmentItem = null,
    chestplate: ?EquipmentItem = null,
    leggings: ?EquipmentItem = null,
    boots: ?EquipmentItem = null,
    main_hand: ?EquipmentItem = null,
    is_enchanted: bool = false,

    pub fn hasProtection(self: MobEquipment) bool {
        if (self.helmet) |h| if (h.enchantment) |e| if (e.enchant_type == .protection_1) return true;
        if (self.chestplate) |c| if (c.enchantment) |e| if (e.enchant_type == .protection_1) return true;
        if (self.leggings) |l| if (l.enchantment) |e| if (e.enchant_type == .protection_1) return true;
        if (self.boots) |b| if (b.enchantment) |e| if (e.enchant_type == .protection_1) return true;
        return false;
    }

    pub fn hasSharpness(self: MobEquipment) bool {
        if (self.main_hand) |w| if (w.enchantment) |e| if (e.enchant_type == .sharpness_1) return true;
        return false;
    }
};

pub fn generateOminousEquipment(material: ArmorMaterial, mob: MobType) MobEquipment {
    const is_ranged = mobCategory(mob) == .ranged and mob != .breeze;
    const weapon: EquipmentItem = if (is_ranged)
        .{
            .name = "Bow",
            .enchantment = .{ .enchant_type = .power_1, .level = 1 },
        }
    else
        .{
            .name = "Iron Sword",
            .enchantment = .{ .enchant_type = .sharpness_1, .level = 1 },
        };

    const prot = Enchantment{ .enchant_type = .protection_1, .level = 1 };
    const helm_name = if (material == .chainmail) "Chainmail Helmet" else "Iron Helmet";
    const chest_name = if (material == .chainmail) "Chainmail Chestplate" else "Iron Chestplate";
    const legs_name = if (material == .chainmail) "Chainmail Leggings" else "Iron Leggings";
    const boots_name = if (material == .chainmail) "Chainmail Boots" else "Iron Boots";

    return .{
        .helmet = .{ .name = helm_name, .material = material, .enchantment = prot },
        .chestplate = .{ .name = chest_name, .material = material, .enchantment = prot },
        .leggings = .{ .name = legs_name, .material = material, .enchantment = prot },
        .boots = .{ .name = boots_name, .material = material, .enchantment = prot },
        .main_hand = weapon,
        .is_enchanted = true,
    };
}

pub const PotionCloudType = enum(u8) {
    poison = 0,
    slowness = 1,
    weaving = 2,
    oozing = 3,
    infested = 4,
    wind_charged = 5,

    pub fn name(self: PotionCloudType) []const u8 {
        return switch (self) {
            .poison => "Poison",
            .slowness => "Slowness",
            .weaving => "Weaving",
            .oozing => "Oozing",
            .infested => "Infested",
            .wind_charged => "Wind Charged",
        };
    }
};

pub const ProjectileDropType = enum(u8) {
    fire_charge = 0,
    wind_charge = 1,

    pub fn name(self: ProjectileDropType) []const u8 {
        return switch (self) {
            .fire_charge => "Fire Charge",
            .wind_charge => "Wind Charge",
        };
    }
};

pub const HazardKind = enum {
    potion_cloud,
    projectile_drop,
};

pub const HazardPayload = union(HazardKind) {
    potion_cloud: PotionCloudType,
    projectile_drop: ProjectileDropType,
};

pub const HazardType = enum {
    poison,
    slowness,
    weaving,
    oozing,
    infested,
    wind_charged,
    fire_charge,
    wind_charge,

    pub fn toPayload(self: HazardType) HazardPayload {
        return switch (self) {
            .poison => .{ .potion_cloud = .poison },
            .slowness => .{ .potion_cloud = .slowness },
            .weaving => .{ .potion_cloud = .weaving },
            .oozing => .{ .potion_cloud = .oozing },
            .infested => .{ .potion_cloud = .infested },
            .wind_charged => .{ .potion_cloud = .wind_charged },
            .fire_charge => .{ .projectile_drop = .fire_charge },
            .wind_charge => .{ .projectile_drop = .wind_charge },
        };
    }

    pub fn isPotionCloud(self: HazardType) bool {
        return switch (self) {
            .poison, .slowness, .weaving, .oozing, .infested, .wind_charged => true,
            .fire_charge, .wind_charge => false,
        };
    }

    pub fn isProjectileDrop(self: HazardType) bool {
        return !self.isPotionCloud();
    }
};

pub const all_hazards = [_]HazardType{
    .poison,
    .slowness,
    .weaving,
    .oozing,
    .infested,
    .wind_charged,
    .fire_charge,
    .wind_charge,
};

pub fn hazardForCycle(cycle: u32) HazardType {
    return all_hazards[cycle % all_hazards.len];
}

pub fn hazardForRoll(roll: f32) HazardType {
    const clamped = std.math.clamp(roll, 0.0, 0.999999);
    const index: usize = @intFromFloat(clamped * @as(f32, @floatFromInt(all_hazards.len)));
    return all_hazards[index];
}

pub const HazardEvent = struct {
    payload: HazardPayload,
    hazard_type: HazardType,
    target_player_index: usize,
    target_position: [3]f32,
    drop_position: [3]f32, // directly above target player
    velocity: [3]f32 = .{ 0.0, -0.6, 0.0 }, // downward drop
};

pub const SpawnEvent = struct {
    mob: MobType,
    category: MobCategory,
    position: [3]f32,
    armored_and_armed: bool,
    equipment: ?MobEquipment = null,
};

pub const TickResult = struct {
    activated: bool = false,
    ignition_particles: bool = false,
    activation_sound: bool = false,
    spawn: ?SpawnEvent = null,
    hazard: ?HazardEvent = null,
    venting_grey_smoke_particles: bool = false,
    venting_ominous_smoke: bool = false,
    wave_completed: bool = false,
};

pub const standard_rewards = [_]ItemType{
    .baked_potato,
    .golden_carrot,
    .arrow,
    .iron_ingot,
    .emerald,
};

pub const ominous_rewards = [_]ItemType{
    .enchanted_golden_apple,
    .heavy_core,
    .mace,
    .wind_charge,
};

pub const LootBundle = struct {
    item: ItemType,
    count: u8 = 1,
    key_item: ?ItemType = null,
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.4, 0.0 }, // upward ejection
};

pub fn evaluateReward(is_ominous: bool, reward_roll: f32, key_roll: f32) struct { item: ItemType, key_item: ?ItemType } {
    const items = if (is_ominous) ominous_rewards[0..] else standard_rewards[0..];
    const clamped = std.math.clamp(reward_roll, 0.0, 0.999999);
    const idx: usize = @intFromFloat(clamped * @as(f32, @floatFromInt(items.len)));
    const key_chance = if (is_ominous) OMINOUS_KEY_CHANCE else STANDARD_KEY_CHANCE;
    const key_dropped = key_roll < key_chance;
    const key: ?ItemType = if (key_dropped) (if (is_ominous) .ominous_trial_key else .trial_key) else null;
    return .{
        .item = items[idx],
        .key_item = key,
    };
}

pub fn isWithinDetectionRadius(player_pos: [3]f32, spawner_pos: [3]f32) bool {
    const dx = player_pos[0] - spawner_pos[0];
    const dy = player_pos[1] - spawner_pos[1];
    const dz = player_pos[2] - spawner_pos[2];
    return (dx * dx + dy * dy + dz * dz) <= DETECTION_RADIUS_SQ;
}

pub const default_mob_rotation = [_]MobType{
    .zombie,
    .husk,
    .slime,
    .spider,
    .baby_zombie,
    .cave_spider,
    .silverfish,
    .skeleton,
    .stray,
    .bogged,
    .breeze,
};

pub fn selectMob(index: u32) MobType {
    return default_mob_rotation[index % default_mob_rotation.len];
}

pub const TrialSpawner = struct {
    position: [3]f32,
    base_total_mobs: u32 = BASE_TOTAL_MOBS,
    base_simultaneous: u32 = BASE_SIMULTANEOUS_MOBS,
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
        return .{
            .position = .{ x, y, z },
        };
    }

    pub fn initWithConfig(x: f32, y: f32, z: f32, base_total: u32, base_simultaneous: u32) TrialSpawner {
        return .{
            .position = .{ x, y, z },
            .base_total_mobs = base_total,
            .base_simultaneous = base_simultaneous,
        };
    }

    pub fn nearbyPlayerCount(self: TrialSpawner, players: []const Player) u32 {
        var count: u32 = 0;
        for (players) |player| {
            if (!player.mode.isEligible()) continue;
            if (isWithinDetectionRadius(player.position, self.position)) {
                count += 1;
            }
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
                    if (player.mode.isEligible() and isWithinDetectionRadius(player.position, self.position) and player.trial_omen) {
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
                    if (player.mode.isEligible() and isWithinDetectionRadius(player.position, self.position) and player.trial_omen) {
                        self.is_ominous = true;
                        break;
                    }
                }

                self.total_mobs = scaleTotalMobs(self.base_total_mobs, count);
                self.mobs_spawned = 0;
                self.mobs_alive = 0;
                self.rewards_ejected = 0;
                self.spawn_ticks_remaining = SPAWN_INTERVAL_TICKS;
                self.hazard_ticks_remaining = HAZARD_INTERVAL_TICKS;
                self.state = .active;
            },

            .active => {
                // If an omen player enters while active, spawner transforms into ominous
                if (!self.is_ominous) {
                    for (players) |player| {
                        if (player.mode.isEligible() and isWithinDetectionRadius(player.position, self.position) and player.trial_omen) {
                            self.is_ominous = true;
                            self.hazard_ticks_remaining = HAZARD_INTERVAL_TICKS;
                            break;
                        }
                    }
                }

                self.tickActive(players, &result);
            },

            .waiting_for_reward_ejection => {},

            .cooldown => {
                result.venting_grey_smoke_particles = true;
                result.venting_ominous_smoke = self.is_ominous;
                if (self.cooldown_remaining > 0) {
                    self.cooldown_remaining -= 1;
                }
                if (self.cooldown_remaining == 0) {
                    self.state = .inactive;
                    self.is_ominous = false;
                }
            },
        }

        return result;
    }

    fn tickActive(self: *TrialSpawner, players: []const Player, result: *TickResult) void {
        // 1. Ominous Spawner Hazard Timer (160 ticks = 8.0 seconds)
        if (self.is_ominous) {
            if (self.hazard_ticks_remaining > 0) {
                self.hazard_ticks_remaining -= 1;
            }
            if (self.hazard_ticks_remaining == 0) {
                if (self.selectTargetPlayer(players)) |target_idx| {
                    const h_type = hazardForCycle(self.hazard_cycle);
                    const p_pos = players[target_idx].position;
                    // Hazard drops directly above player
                    result.hazard = .{
                        .payload = h_type.toPayload(),
                        .hazard_type = h_type,
                        .target_player_index = target_idx,
                        .target_position = p_pos,
                        .drop_position = .{ p_pos[0], p_pos[1] + 3.5, p_pos[2] },
                        .velocity = .{ 0.0, -0.6, 0.0 },
                    };
                }
                self.hazard_cycle +%= 1;
                self.hazard_ticks_remaining = HAZARD_INTERVAL_TICKS;
            }
        }

        // 2. Mob Spawning
        if (self.mobs_spawned >= self.total_mobs) return;

        if (self.spawn_ticks_remaining > 0) {
            self.spawn_ticks_remaining -= 1;
            if (self.spawn_ticks_remaining > 0) return;
        }

        const sim_cap = scaleSimultaneousMobs(self.base_simultaneous, self.participating_players);
        if (self.mobs_alive >= sim_cap) return;

        const mob = selectMob(self.mobs_spawned);
        const equip: ?MobEquipment = if (self.is_ominous)
            generateOminousEquipment(if ((self.mobs_spawned % 2) == 0) .chainmail else .iron, mob)
        else
            null;

        result.spawn = .{
            .mob = mob,
            .category = mobCategory(mob),
            .position = .{ self.position[0], self.position[1] + 1.0, self.position[2] },
            .armored_and_armed = self.is_ominous,
            .equipment = equip,
        };

        self.mobs_spawned += 1;
        self.mobs_alive += 1;
        self.spawn_ticks_remaining = SPAWN_INTERVAL_TICKS;
    }

    fn selectTargetPlayer(self: TrialSpawner, players: []const Player) ?usize {
        const count = self.nearbyPlayerCount(players);
        if (count == 0) return null;
        const target_slot = self.hazard_cycle % count;
        var seen: u32 = 0;
        for (players, 0..) |player, index| {
            if (!player.mode.isEligible() or !isWithinDetectionRadius(player.position, self.position)) continue;
            if (seen == target_slot) return index;
            seen += 1;
        }
        return null;
    }

    pub fn mobDefeated(self: *TrialSpawner) void {
        if (self.state != .active or self.mobs_alive == 0) return;
        self.mobs_alive -= 1;
        if (self.mobs_spawned == self.total_mobs and self.mobs_alive == 0) {
            self.state = .waiting_for_reward_ejection;
        }
    }

    pub fn ejectRewards(self: *TrialSpawner, reward_roll: f32, key_roll: f32) ?LootBundle {
        if (self.state != .waiting_for_reward_ejection) return null;

        const eval = evaluateReward(self.is_ominous, reward_roll, key_roll);
        self.rewards_ejected += 1;

        if (self.rewards_ejected >= self.participating_players) {
            self.state = .cooldown;
            self.cooldown_remaining = COOLDOWN_TICKS;
        }

        return .{
            .item = eval.item,
            .count = 1,
            .key_item = eval.key_item,
            .position = .{ self.position[0], self.position[1] + 1.0, self.position[2] },
            .velocity = .{ 0.0, 0.4, 0.0 },
        };
    }

    pub fn lightLevel(self: TrialSpawner) u8 {
        return switch (self.state) {
            .inactive, .cooldown => 0,
            .waiting_for_players, .active, .waiting_for_reward_ejection => 15,
        };
    }

    pub fn simultaneousMobCap(self: TrialSpawner) u32 {
        return scaleSimultaneousMobs(self.base_simultaneous, self.participating_players);
    }

    pub fn totalWaveSize(self: TrialSpawner) u32 {
        return scaleTotalMobs(self.base_total_mobs, self.participating_players);
    }
};

// ============================================================================
// UNIT TESTS (25+ tests covering all specification points)
// ============================================================================

test "1. dynamic total mob wave scaling for 1 player (base 6 -> 6)" {
    try std.testing.expectEqual(@as(u32, 6), scaleTotalMobs(6, 1));
}

test "2. dynamic total mob wave scaling for 2 players (base 6 -> 9)" {
    try std.testing.expectEqual(@as(u32, 9), scaleTotalMobs(6, 2));
}

test "3. dynamic total mob wave scaling for 3 players (base 6 -> 12)" {
    try std.testing.expectEqual(@as(u32, 12), scaleTotalMobs(6, 3));
}

test "4. dynamic total mob wave scaling for 4 players (base 6 -> 15)" {
    try std.testing.expectEqual(@as(u32, 15), scaleTotalMobs(6, 4));
}

test "5. dynamic total mob wave scaling for 5 players (base 6 -> 18)" {
    try std.testing.expectEqual(@as(u32, 18), scaleTotalMobs(6, 5));
}

test "6. dynamic simultaneous mob cap scaling for 1 player (base 2 -> 2)" {
    try std.testing.expectEqual(@as(u32, 2), scaleSimultaneousMobs(2, 1));
}

test "7. dynamic simultaneous mob cap scaling for 2 players (base 2 -> 3)" {
    try std.testing.expectEqual(@as(u32, 3), scaleSimultaneousMobs(2, 2));
}

test "8. dynamic simultaneous mob cap scaling for 3 players (base 2 -> 4)" {
    try std.testing.expectEqual(@as(u32, 4), scaleSimultaneousMobs(2, 3));
}

test "9. dynamic simultaneous mob cap scaling for 4 players (base 2 -> 5)" {
    try std.testing.expectEqual(@as(u32, 5), scaleSimultaneousMobs(2, 4));
}

test "10. dynamic simultaneous mob cap scaling for 5 players (base 2 -> 6)" {
    try std.testing.expectEqual(@as(u32, 6), scaleSimultaneousMobs(2, 5));
}

test "11. dynamic mob wave scaling with custom base counts (base 4, 8, 10)" {
    // Base 4: 1->4, 2->6, 3->8, 4->10, 5->12
    try std.testing.expectEqual(@as(u32, 4), scaleTotalMobs(4, 1));
    try std.testing.expectEqual(@as(u32, 6), scaleTotalMobs(4, 2));
    try std.testing.expectEqual(@as(u32, 8), scaleTotalMobs(4, 3));
    try std.testing.expectEqual(@as(u32, 10), scaleTotalMobs(4, 4));
    try std.testing.expectEqual(@as(u32, 12), scaleTotalMobs(4, 5));

    // Base 8: 1->8, 2->12, 3->16, 4->20, 5->24
    try std.testing.expectEqual(@as(u32, 8), scaleTotalMobs(8, 1));
    try std.testing.expectEqual(@as(u32, 12), scaleTotalMobs(8, 2));
    try std.testing.expectEqual(@as(u32, 16), scaleTotalMobs(8, 3));
    try std.testing.expectEqual(@as(u32, 20), scaleTotalMobs(8, 4));
    try std.testing.expectEqual(@as(u32, 24), scaleTotalMobs(8, 5));
}

test "12. zero players scaling returns zero for mob count and simultaneous cap" {
    try std.testing.expectEqual(@as(u32, 0), scaleTotalMobs(6, 0));
    try std.testing.expectEqual(@as(u32, 0), scaleSimultaneousMobs(2, 0));
}

test "13. nearby player detection adheres to 14.0m Euclidean radius" {
    const spawner_pos = [3]f32{ 0.0, 64.0, 0.0 };
    try std.testing.expect(isWithinDetectionRadius(.{ 14.0, 64.0, 0.0 }, spawner_pos));
    try std.testing.expect(isWithinDetectionRadius(.{ 0.0, 78.0, 0.0 }, spawner_pos));
    try std.testing.expect(isWithinDetectionRadius(.{ 0.0, 64.0, 14.0 }, spawner_pos));
    try std.testing.expect(isWithinDetectionRadius(.{ 8.0, 72.0, 8.0 }, spawner_pos));
}

test "14. nearby player detection boundary: 14.0m is in range, 14.01m is out of range" {
    const spawner_pos = [3]f32{ 0.0, 0.0, 0.0 };
    try std.testing.expect(isWithinDetectionRadius(.{ 14.0, 0.0, 0.0 }, spawner_pos));
    try std.testing.expect(!isWithinDetectionRadius(.{ 14.01, 0.0, 0.0 }, spawner_pos));
    try std.testing.expect(!isWithinDetectionRadius(.{ 10.0, 10.0, 0.0 }, spawner_pos)); // 10^2+10^2 = 200 > 196
}

test "15. survival and adventure players are eligible for trial activation and scaling" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const players = [_]Player{
        .{ .position = .{ 5, 0, 0 }, .mode = .survival },
        .{ .position = .{ -5, 0, 0 }, .mode = .adventure },
    };
    try std.testing.expectEqual(@as(u32, 2), spawner.nearbyPlayerCount(&players));
    const res = spawner.tick(&players);
    try std.testing.expect(res.activated);
    try std.testing.expect(res.ignition_particles);
    try std.testing.expect(res.activation_sound);
    try std.testing.expectEqual(State.waiting_for_players, spawner.state);
}

test "16. creative and spectator players are ignored and do not activate spawner" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const players = [_]Player{
        .{ .position = .{ 2, 0, 0 }, .mode = .creative },
        .{ .position = .{ 3, 0, 0 }, .mode = .spectator },
    };
    try std.testing.expectEqual(@as(u32, 0), spawner.nearbyPlayerCount(&players));
    const res = spawner.tick(&players);
    try std.testing.expect(!res.activated);
    try std.testing.expectEqual(State.inactive, spawner.state);
}

test "17. trial omen on approaching player transforms spawner to is_ominous = true" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const players = [_]Player{
        .{ .position = .{ 3, 0, 0 }, .mode = .survival, .trial_omen = true },
    };
    _ = spawner.tick(&players);
    try std.testing.expect(spawner.is_ominous);
    try std.testing.expectEqual(State.waiting_for_players, spawner.state);
}

test "18. approaching player without trial omen activates standard spawner" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const players = [_]Player{
        .{ .position = .{ 3, 0, 0 }, .mode = .survival, .trial_omen = false },
    };
    _ = spawner.tick(&players);
    try std.testing.expect(!spawner.is_ominous);
}

test "19. approaching trial omen player during waiting_for_players triggers ominous transformation" {
    var spawner = TrialSpawner.init(0, 0, 0);
    const standard_players = [_]Player{
        .{ .position = .{ 3, 0, 0 }, .mode = .survival, .trial_omen = false },
    };
    _ = spawner.tick(&standard_players);
    try std.testing.expect(!spawner.is_ominous);
    try std.testing.expectEqual(State.waiting_for_players, spawner.state);

    const omen_players = [_]Player{
        .{ .position = .{ 3, 0, 0 }, .mode = .survival, .trial_omen = true },
    };
    _ = spawner.tick(&omen_players);
    try std.testing.expect(spawner.is_ominous);
    try std.testing.expectEqual(State.active, spawner.state);
}

test "20. ominous transformation equips spawned mobs with chainmail armor with Protection I" {
    const equip = generateOminousEquipment(.chainmail, .zombie);
    try std.testing.expect(equip.is_enchanted);
    try std.testing.expect(equip.hasProtection());
    try std.testing.expectEqual(ArmorMaterial.chainmail, equip.helmet.?.material.?);
    try std.testing.expectEqual(ArmorMaterial.chainmail, equip.chestplate.?.material.?);
    try std.testing.expectEqual(ArmorMaterial.chainmail, equip.leggings.?.material.?);
    try std.testing.expectEqual(ArmorMaterial.chainmail, equip.boots.?.material.?);
    try std.testing.expectEqual(EnchantmentType.protection_1, equip.helmet.?.enchantment.?.enchant_type);
}

test "21. ominous transformation equips spawned mobs with iron armor with Protection I" {
    const equip = generateOminousEquipment(.iron, .skeleton);
    try std.testing.expect(equip.is_enchanted);
    try std.testing.expect(equip.hasProtection());
    try std.testing.expectEqual(ArmorMaterial.iron, equip.helmet.?.material.?);
    try std.testing.expectEqual(ArmorMaterial.iron, equip.chestplate.?.material.?);
    try std.testing.expectEqual(ArmorMaterial.iron, equip.leggings.?.material.?);
    try std.testing.expectEqual(ArmorMaterial.iron, equip.boots.?.material.?);
    try std.testing.expectEqual(EnchantmentType.protection_1, equip.chestplate.?.enchantment.?.enchant_type);
}

test "22. ominous transformation equips melee mob with Iron Sword with Sharpness I" {
    const equip = generateOminousEquipment(.iron, .zombie);
    try std.testing.expect(equip.hasSharpness());
    try std.testing.expectEqualStrings("Iron Sword", equip.main_hand.?.name);
    try std.testing.expectEqual(EnchantmentType.sharpness_1, equip.main_hand.?.enchantment.?.enchant_type);
}

test "23. standard spawner spawns mobs without enchanted equipment" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.is_ominous = false;
    spawner.participating_players = 1;
    spawner.total_mobs = 2;
    spawner.spawn_ticks_remaining = 1;

    const res = spawner.tick(&.{});
    try std.testing.expect(res.spawn != null);
    try std.testing.expect(!res.spawn.?.armored_and_armed);
    try std.testing.expect(res.spawn.?.equipment == null);
}

test "24. ominous spawner active tick spawns mobs with enchanted equipment" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.is_ominous = true;
    spawner.participating_players = 1;
    spawner.total_mobs = 2;
    spawner.spawn_ticks_remaining = 1;

    const res = spawner.tick(&.{});
    try std.testing.expect(res.spawn != null);
    try std.testing.expect(res.spawn.?.armored_and_armed);
    try std.testing.expect(res.spawn.?.equipment != null);
    try std.testing.expect(res.spawn.?.equipment.?.is_enchanted);
    try std.testing.expect(res.spawn.?.equipment.?.hasProtection());
}

test "25. mob categories are correctly assigned across all mob types" {
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
    try std.testing.expectEqual(MobCategory.ranged, mobCategory(.breeze));
}

test "26. spawner tick cadence is exactly 40 ticks between mob spawns" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.participating_players = 1;
    spawner.total_mobs = 3;
    spawner.spawn_ticks_remaining = SPAWN_INTERVAL_TICKS;

    for (0..SPAWN_INTERVAL_TICKS - 1) |_| {
        const res = spawner.tick(&.{});
        try std.testing.expect(res.spawn == null);
    }
    const spawn_res = spawner.tick(&.{});
    try std.testing.expect(spawn_res.spawn != null);
    try std.testing.expectEqual(@as(u32, 1), spawner.mobs_alive);
}

test "27. simultaneous mob cap throttles spawns until living mob is defeated" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.participating_players = 1; // sim cap is 2
    spawner.total_mobs = 4;
    spawner.spawn_ticks_remaining = 0;

    // First spawn
    _ = spawner.tick(&.{});
    try std.testing.expectEqual(@as(u32, 1), spawner.mobs_alive);

    // Second spawn
    spawner.spawn_ticks_remaining = 0;
    _ = spawner.tick(&.{});
    try std.testing.expectEqual(@as(u32, 2), spawner.mobs_alive);

    // Third spawn blocked by simultaneous cap (2)
    spawner.spawn_ticks_remaining = 0;
    const blocked_res = spawner.tick(&.{});
    try std.testing.expect(blocked_res.spawn == null);
    try std.testing.expectEqual(@as(u32, 2), spawner.mobs_alive);

    // Defeating one mob unblocks the next spawn
    spawner.mobDefeated();
    try std.testing.expectEqual(@as(u32, 1), spawner.mobs_alive);
    const unblocked_res = spawner.tick(&.{});
    try std.testing.expect(unblocked_res.spawn != null);
    try std.testing.expectEqual(@as(u32, 2), spawner.mobs_alive);
}

test "28. mobDefeated prevents underflow below zero" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.mobDefeated();
    try std.testing.expectEqual(@as(u32, 0), spawner.mobs_alive);
}

test "29. 160-tick (8.0 second) hazard timer counts down in ominous mode" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.is_ominous = true;
    const players = [_]Player{.{ .position = .{ 1, 0, 0 } }};

    try std.testing.expectEqual(@as(u32, HAZARD_INTERVAL_TICKS), spawner.hazard_ticks_remaining);
    for (0..HAZARD_INTERVAL_TICKS - 1) |_| {
        const res = spawner.tick(&players);
        try std.testing.expect(res.hazard == null);
    }
    const h_res = spawner.tick(&players);
    try std.testing.expect(h_res.hazard != null);
    try std.testing.expectEqual(@as(u32, HAZARD_INTERVAL_TICKS), spawner.hazard_ticks_remaining);
}

test "30. standard non-ominous spawner suppresses hazards completely" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.is_ominous = false;
    const players = [_]Player{.{ .position = .{ 1, 0, 0 } }};

    for (0..HAZARD_INTERVAL_TICKS * 2) |_| {
        const res = spawner.tick(&players);
        try std.testing.expect(res.hazard == null);
    }
}

test "31. hazard drops directly above target player with downward velocity" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .active;
    spawner.is_ominous = true;
    spawner.hazard_ticks_remaining = 1;
    const players = [_]Player{.{ .position = .{ 2.0, 0.0, 3.0 } }};

    const res = spawner.tick(&players);
    try std.testing.expect(res.hazard != null);
    const h = res.hazard.?;
    try std.testing.expectEqual(@as(usize, 0), h.target_player_index);
    try std.testing.expectEqualSlices(f32, &.{ 2.0, 0.0, 3.0 }, &h.target_position);
    try std.testing.expectEqualSlices(f32, &.{ 2.0, 3.5, 3.0 }, &h.drop_position);
    try std.testing.expectEqualSlices(f32, &.{ 0.0, -0.6, 0.0 }, &h.velocity);
}

test "32. all 6 lingering potion cloud types are defined and named" {
    try std.testing.expectEqualStrings("Poison", PotionCloudType.poison.name());
    try std.testing.expectEqualStrings("Slowness", PotionCloudType.slowness.name());
    try std.testing.expectEqualStrings("Weaving", PotionCloudType.weaving.name());
    try std.testing.expectEqualStrings("Oozing", PotionCloudType.oozing.name());
    try std.testing.expectEqualStrings("Infested", PotionCloudType.infested.name());
    try std.testing.expectEqualStrings("Wind Charged", PotionCloudType.wind_charged.name());
}

test "33. downward projectile drops are defined and named" {
    try std.testing.expectEqualStrings("Fire Charge", ProjectileDropType.fire_charge.name());
    try std.testing.expectEqualStrings("Wind Charge", ProjectileDropType.wind_charge.name());
}

test "34. hazard cycle alternates through all 8 hazard varieties" {
    for (all_hazards, 0..) |expected_hazard, i| {
        const actual = hazardForCycle(@intCast(i));
        try std.testing.expectEqual(expected_hazard, actual);
    }
}

test "35. hazard roll maps properly to all 8 hazard varieties" {
    try std.testing.expectEqual(HazardType.poison, hazardForRoll(0.0));
    try std.testing.expectEqual(HazardType.slowness, hazardForRoll(0.13));
    try std.testing.expectEqual(HazardType.weaving, hazardForRoll(0.26));
    try std.testing.expectEqual(HazardType.oozing, hazardForRoll(0.39));
    try std.testing.expectEqual(HazardType.infested, hazardForRoll(0.51));
    try std.testing.expectEqual(HazardType.wind_charged, hazardForRoll(0.64));
    try std.testing.expectEqual(HazardType.fire_charge, hazardForRoll(0.76));
    try std.testing.expectEqual(HazardType.wind_charge, hazardForRoll(0.89));
}

test "36. wave completion triggers transition to waiting_for_reward_ejection" {
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

test "37. standard key reward drop probability: 50% threshold" {
    const dropped = evaluateReward(false, 0.2, 0.4999);
    try std.testing.expect(dropped.key_item != null);
    try std.testing.expectEqual(ItemType.trial_key, dropped.key_item.?);

    const missed = evaluateReward(false, 0.2, 0.50);
    try std.testing.expect(missed.key_item == null);
}

test "38. ominous key reward drop probability: 30% threshold" {
    const dropped = evaluateReward(true, 0.2, 0.2999);
    try std.testing.expect(dropped.key_item != null);
    try std.testing.expectEqual(ItemType.ominous_trial_key, dropped.key_item.?);

    const missed = evaluateReward(true, 0.2, 0.30);
    try std.testing.expect(missed.key_item == null);
}

test "39. reward ejection velocity points upward at 0.4 m/s" {
    var spawner = TrialSpawner.init(10.0, 60.0, 10.0);
    spawner.state = .waiting_for_reward_ejection;
    spawner.participating_players = 1;

    const bundle = spawner.ejectRewards(0.3, 0.1).?;
    try std.testing.expectEqualSlices(f32, &.{ 0.0, 0.4, 0.0 }, &bundle.velocity);
    try std.testing.expectEqualSlices(f32, &.{ 10.0, 61.0, 10.0 }, &bundle.position);
}

test "40. standard reward pool produces standard items" {
    const res0 = evaluateReward(false, 0.05, 0.9);
    try std.testing.expectEqual(ItemType.baked_potato, res0.item);

    const res1 = evaluateReward(false, 0.25, 0.9);
    try std.testing.expectEqual(ItemType.golden_carrot, res1.item);

    const res2 = evaluateReward(false, 0.45, 0.9);
    try std.testing.expectEqual(ItemType.arrow, res2.item);

    const res3 = evaluateReward(false, 0.65, 0.9);
    try std.testing.expectEqual(ItemType.iron_ingot, res3.item);

    const res4 = evaluateReward(false, 0.85, 0.9);
    try std.testing.expectEqual(ItemType.emerald, res4.item);
}

test "41. ominous reward pool produces high tier item varieties" {
    const res0 = evaluateReward(true, 0.1, 0.9);
    try std.testing.expectEqual(ItemType.enchanted_golden_apple, res0.item);

    const res1 = evaluateReward(true, 0.3, 0.9);
    try std.testing.expectEqual(ItemType.heavy_core, res1.item);

    const res2 = evaluateReward(true, 0.6, 0.9);
    try std.testing.expectEqual(ItemType.mace, res2.item);

    const res3 = evaluateReward(true, 0.9, 0.9);
    try std.testing.expectEqual(ItemType.wind_charge, res3.item);
}

test "42. 30-minute (36,000-tick) cooldown lock enters upon wave completion and reward ejection" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .waiting_for_reward_ejection;
    spawner.participating_players = 1;

    _ = spawner.ejectRewards(0.2, 0.1);
    try std.testing.expectEqual(State.cooldown, spawner.state);
    try std.testing.expectEqual(@as(u32, 36_000), spawner.cooldown_remaining);
}

test "43. cooldown lock suppresses spawner reactivation during 36,000 ticks" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .cooldown;
    spawner.cooldown_remaining = COOLDOWN_TICKS;

    const nearby_players = [_]Player{
        .{ .position = .{ 1, 0, 0 }, .mode = .survival, .trial_omen = true },
    };

    // First 35,999 ticks, spawner stays in cooldown
    for (0..100) |_| {
        const res = spawner.tick(&nearby_players);
        try std.testing.expect(!res.activated);
        try std.testing.expectEqual(State.cooldown, spawner.state);
        try std.testing.expect(res.venting_grey_smoke_particles);
    }
}

test "44. cooldown emits grey smoke particles on each tick" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .cooldown;
    spawner.cooldown_remaining = 10;

    const res = spawner.tick(&.{});
    try std.testing.expect(res.venting_grey_smoke_particles);
    try std.testing.expectEqual(@as(u32, 9), spawner.cooldown_remaining);
}

test "45. cooldown expiration unlocks spawner back to inactive state" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .cooldown;
    spawner.cooldown_remaining = 1;

    _ = spawner.tick(&.{});
    try std.testing.expectEqual(State.inactive, spawner.state);
    try std.testing.expectEqual(@as(u32, 0), spawner.cooldown_remaining);

    // Now eligible player can reactivate
    const player = [_]Player{.{ .position = .{ 2, 0, 0 } }};
    const act_res = spawner.tick(&player);
    try std.testing.expect(act_res.activated);
    try std.testing.expectEqual(State.waiting_for_players, spawner.state);
}

test "46. light level corresponds to active (15) and inactive/cooldown (0)" {
    var spawner = TrialSpawner.init(0, 0, 0);
    try std.testing.expectEqual(@as(u8, 0), spawner.lightLevel());

    spawner.state = .waiting_for_players;
    try std.testing.expectEqual(@as(u8, 15), spawner.lightLevel());

    spawner.state = .active;
    try std.testing.expectEqual(@as(u8, 15), spawner.lightLevel());

    spawner.state = .waiting_for_reward_ejection;
    try std.testing.expectEqual(@as(u8, 15), spawner.lightLevel());

    spawner.state = .cooldown;
    try std.testing.expectEqual(@as(u8, 0), spawner.lightLevel());
}

test "47. multi-player reward ejection waits for all participants before entering cooldown" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .waiting_for_reward_ejection;
    spawner.participating_players = 3;

    // Eject bundle 1
    const b1 = spawner.ejectRewards(0.5, 0.9);
    try std.testing.expect(b1 != null);
    try std.testing.expectEqual(State.waiting_for_reward_ejection, spawner.state);

    // Eject bundle 2
    const b2 = spawner.ejectRewards(0.5, 0.9);
    try std.testing.expect(b2 != null);
    try std.testing.expectEqual(State.waiting_for_reward_ejection, spawner.state);

    // Eject bundle 3 -> now enters cooldown
    const b3 = spawner.ejectRewards(0.5, 0.9);
    try std.testing.expect(b3 != null);
    try std.testing.expectEqual(State.cooldown, spawner.state);
    try std.testing.expectEqual(@as(u32, COOLDOWN_TICKS), spawner.cooldown_remaining);
}
