//! ============================================================================
//! Milestone 482: Piglin Brute & Bastion Defense Tactics in Zigcraft
//! ============================================================================
//!
//! Overview:
//!   The Piglin Brute is an elite, heavily armored hostile humanoid mob that guards
//!   Bastion Remnants in the Nether. Unlike standard piglins, Piglin Brutes are
//!   single-minded defenders who wield golden axes with devastating force, cannot be
//!   distracted or pacified, and serve as bastion sentinels coordinating garrison defenses.
//!
//! Specifications:
//! 1. Target File: `src/world/piglin_brute_bastion.zig`
//! 2. Piglin Brute Entity Attributes:
//!    - Max Health: 50.0 HP (25 hearts, >3x standard Piglin 16.0 HP).
//!    - Base attack damage: 13.0 HP (Golden Axe heavy blow).
//!    - Visual identifier: Golden arm band, scarred blind eye, two-handed Golden Axe stance.
//!    - Non-respawning: Spawns only upon world generation in Bastion Remnants; never
//!      respawns when killed.
//! 3. Gold Distraction & Pacification Immunity:
//!    - Completely immune to gold armor pacification: Attacks players on sight
//!      regardless of whether they wear full golden armor (is_gold_armor_ignored = true).
//!    - Completely immune to gold bartering distraction: Never picks up gold ingots,
//!      never barters, never pauses to inspect gold (is_barter_ignored = true).
//!    - Attacks players unconditionally (is_always_hostile = true).
//! 4. Bastion Defense Alarm Coordination:
//!    - When a Piglin Brute spots or attacks a player:
//!      * Emits a piercing war snort audio alarm (SoundEffect.brute_war_horn).
//!      * Coordinates alarm broadcast: Alerts all nearby standard Piglins within a
//!        16.0m Euclidean radius (ALARM_RADIUS = 16.0).
//!      * Any nearby Piglin that was currently pacified (by gold armor or inspecting
//!        an ingot) immediately breaks pacification, drops what it is doing, and
//!        joins the coordinated attack against the player!
//! 5. Zombification in Overworld:
//!    - If a Piglin Brute enters the Overworld or The End:
//!      * Begins shaking after 15.0 seconds (300 ticks).
//!      * After 300 ticks: transforms into a Zombified Piglin with 50.0 HP and
//!        golden axe.
//! 6. Drops on Defeat:
//!    - Drops: Golden Axe (8.5% base chance, scaled by Looting enchantment),
//!      20 Experience Points (high XP drop).
//! ============================================================================

const std = @import("std");

// ============================================================================
// Core Constants
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;

/// Piglin Brute health attributes (50.0 HP = 25 hearts)
pub const PIGLIN_BRUTE_MAX_HEALTH: f32 = 50.0;
pub const PIGLIN_BRUTE_HEARTS: f32 = 25.0;

/// Standard Piglin health attributes for comparison (16.0 HP = 8 hearts)
pub const STANDARD_PIGLIN_MAX_HEALTH: f32 = 16.0;
pub const STANDARD_PIGLIN_HEARTS: f32 = 8.0;

/// Health ratio: 50.0 / 16.0 = 3.125x (over 3x standard piglin health)
pub const BRUTE_TO_STANDARD_HEALTH_RATIO: f32 = PIGLIN_BRUTE_MAX_HEALTH / STANDARD_PIGLIN_MAX_HEALTH;

/// Piglin Brute melee attack damage (Golden Axe heavy blow = 13.0 HP)
pub const PIGLIN_BRUTE_BASE_DAMAGE: f32 = 13.0;

/// Standard Piglin sword attack damage (5.0 HP)
pub const STANDARD_PIGLIN_MELEE_DAMAGE: f32 = 5.0;

/// Bastion alarm coordination radius (16.0 meters Euclidean)
pub const ALARM_RADIUS: f32 = 16.0;
pub const ALARM_RADIUS_SQ: f32 = ALARM_RADIUS * ALARM_RADIUS; // 256.0

/// Overworld and The End zombification duration (15.0s = 300 ticks)
pub const ZOMBIFICATION_TICKS: u32 = 300;
pub const ZOMBIFICATION_DURATION_SECONDS: f32 = 15.0;

/// Drops on defeat
pub const GOLDEN_AXE_BASE_DROP_CHANCE: f32 = 0.085; // 8.5% base chance
pub const LOOTING_DROP_BONUS_PER_LEVEL: f32 = 0.01; // +1.0% per Looting level
pub const EXPERIENCE_POINTS_DROP: u32 = 20; // 20 XP points
pub const STANDARD_PIGLIN_XP_DROP: u32 = 5;

/// Standard piglin barter admiration ticks (6.0s = 120 ticks)
pub const BARTER_ADMIRATION_TICKS: u16 = 120;

// ============================================================================
// Spatial Mathematics
// ============================================================================

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub const zero: Vec3 = .{ .x = 0.0, .y = 0.0, .z = 0.0 };

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn distSq(self: Vec3, other: Vec3) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn dist(self: Vec3, other: Vec3) f32 {
        return @sqrt(self.distSq(other));
    }
};

// ============================================================================
// Enums & Classifications
// ============================================================================

pub const SoundEffect = enum(u8) {
    brute_war_horn, // Piercing war snort audio alarm
    brute_angry,
    brute_hurt,
    brute_death,
    brute_step,
    piglin_alarmed,
    piglin_angry,
    piglin_admiring_gold,
    zombified_growl,
};

pub const Dimension = enum(u8) {
    nether,
    overworld,
    the_end,

    pub fn isOverworldOrEnd(self: Dimension) bool {
        return self == .overworld or self == .the_end;
    }

    pub fn isNether(self: Dimension) bool {
        return self == .nether;
    }
};

pub const VisualStance = enum(u8) {
    two_handed_golden_axe,
    one_handed_sword,
    crossbow_aim,
    idle_arms,
};

pub const ItemType = enum(u16) {
    none = 0,
    gold_ingot = 266,
    golden_axe = 286,
    golden_sword = 283,
    crossbow = 471,
    gold_nugget = 371,
    gold_block = 41,
    porkchop = 319,
    cooked_porkchop = 320,

    pub fn isGold(self: ItemType) bool {
        return switch (self) {
            .gold_ingot, .golden_axe, .golden_sword, .gold_nugget, .gold_block => true,
            else => false,
        };
    }
};

pub const PiglinActivity = enum(u8) {
    idle,
    patrolling,
    inspecting_ingot,
    bartering,
    pacified_wandering,
    alarmed,
    attacking_player,
    shaking,
    zombified,
};

// ============================================================================
// Player Armor Configuration
// ============================================================================

pub const PlayerGoldArmor = struct {
    helmet: bool = false,
    chestplate: bool = false,
    leggings: bool = false,
    boots: bool = false,

    pub fn none() PlayerGoldArmor {
        return .{};
    }

    pub fn full() PlayerGoldArmor {
        return .{
            .helmet = true,
            .chestplate = true,
            .leggings = true,
            .boots = true,
        };
    }

    pub fn hasAnyGold(self: PlayerGoldArmor) bool {
        return self.helmet or self.chestplate or self.leggings or self.boots;
    }

    pub fn isFullGold(self: PlayerGoldArmor) bool {
        return self.helmet and self.chestplate and self.leggings and self.boots;
    }

    pub fn pieceCount(self: PlayerGoldArmor) u8 {
        var count: u8 = 0;
        if (self.helmet) count += 1;
        if (self.chestplate) count += 1;
        if (self.leggings) count += 1;
        if (self.boots) count += 1;
        return count;
    }
};

// ============================================================================
// Piglin Brute Visual Identifiers
// ============================================================================

pub const PiglinBruteVisuals = struct {
    golden_arm_band: bool = true,
    scarred_blind_eye: bool = true,
    two_handed_golden_axe_stance: bool = true,
    stance: VisualStance = .two_handed_golden_axe,
    scar_side: enum { left, right } = .left,
    arm_band_color: [4]f32 = .{ 1.0, 0.84, 0.0, 1.0 }, // Gold RGBA
    scar_color: [4]f32 = .{ 0.55, 0.23, 0.23, 1.0 },

    pub fn init() PiglinBruteVisuals {
        return .{};
    }
};

// ============================================================================
// Standard Piglin Entity
// ============================================================================

pub const StandardPiglin = struct {
    id: u32,
    pos: Vec3,
    health: f32 = STANDARD_PIGLIN_MAX_HEALTH,
    is_baby: bool = false,
    is_pacified: bool = true,
    inspecting_ingot: bool = false,
    barter_ticks: u16 = 0,
    dropped_ingot_count: u32 = 0,
    is_angry: bool = false,
    target_player_id: ?u32 = null,
    activity: PiglinActivity = .pacified_wandering,
    last_sound: ?SoundEffect = null,

    pub fn init(id: u32, pos: Vec3) StandardPiglin {
        return .{
            .id = id,
            .pos = pos,
            .is_pacified = true,
            .activity = .pacified_wandering,
        };
    }

    pub fn initInspectingGold(id: u32, pos: Vec3) StandardPiglin {
        return .{
            .id = id,
            .pos = pos,
            .is_pacified = true,
            .inspecting_ingot = true,
            .barter_ticks = BARTER_ADMIRATION_TICKS,
            .activity = .inspecting_ingot,
            .last_sound = .piglin_admiring_gold,
        };
    }

    /// Alert the standard piglin to immediately break pacification, drop what
    /// it is doing (including gold ingots), and attack the player!
    pub fn alertToAttack(self: *StandardPiglin, player_id: u32) bool {
        const was_pacified = self.is_pacified or self.inspecting_ingot;
        self.is_pacified = false;
        if (self.inspecting_ingot) {
            self.inspecting_ingot = false;
            self.barter_ticks = 0;
            self.dropped_ingot_count += 1;
        }
        self.is_angry = true;
        self.target_player_id = player_id;
        self.activity = .attacking_player;
        self.last_sound = .piglin_angry;
        return was_pacified;
    }
};

// ============================================================================
// Zombified Piglin Entity
// ============================================================================

pub const ZombifiedPiglin = struct {
    id: u32,
    pos: Vec3,
    health: f32 = 50.0,
    max_health: f32 = 50.0,
    attack_damage: f32 = 13.0,
    weapon: ItemType = .golden_axe,
    is_undead: bool = true,
    is_immune_to_fire: bool = true,
    xp_reward: u32 = 20,
};

// ============================================================================
// Alarm Coordination Results & Helpers
// ============================================================================

pub const AlarmBroadcastResult = struct {
    sound_effect: SoundEffect = .brute_war_horn,
    brute_pos: Vec3,
    player_id: u32,
    alerted_piglin_count: usize = 0,
    pacification_broken_count: usize = 0,
    dropped_ingots_count: usize = 0,
    out_of_range_count: usize = 0,
};

/// Coordinates Bastion defense alarm broadcast:
/// Alerts all nearby standard Piglins within 16.0m Euclidean radius.
/// Any nearby Piglin pacified by gold armor or inspecting an ingot
/// breaks pacification, drops what it is doing, and joins the attack!
pub fn broadcastBastionAlarm(
    brute_pos: Vec3,
    player_id: u32,
    player_pos: Vec3,
    nearby_piglins: []StandardPiglin,
) AlarmBroadcastResult {
    _ = player_pos;
    var result = AlarmBroadcastResult{
        .sound_effect = .brute_war_horn,
        .brute_pos = brute_pos,
        .player_id = player_id,
    };

    for (nearby_piglins) |*piglin| {
        const distance = brute_pos.dist(piglin.pos);
        if (distance <= ALARM_RADIUS) {
            const was_pacified = piglin.is_pacified or piglin.inspecting_ingot;
            const had_ingot = piglin.inspecting_ingot;

            _ = piglin.alertToAttack(player_id);

            result.alerted_piglin_count += 1;
            if (was_pacified) {
                result.pacification_broken_count += 1;
            }
            if (had_ingot) {
                result.dropped_ingots_count += 1;
            }
        } else {
            result.out_of_range_count += 1;
        }
    }

    return result;
}

// ============================================================================
// Drops Calculation
// ============================================================================

pub const PiglinBruteDrops = struct {
    dropped_golden_axe: bool,
    golden_axe_damage: f32 = PIGLIN_BRUTE_BASE_DAMAGE,
    experience_points: u32 = EXPERIENCE_POINTS_DROP,
    drop_chance: f32,
    looting_level: u8,
};

pub fn calculateDefeatDrops(looting_level: u8, roll_0_to_1: f32) PiglinBruteDrops {
    const chance = GOLDEN_AXE_BASE_DROP_CHANCE + @as(f32, @floatFromInt(looting_level)) * LOOTING_DROP_BONUS_PER_LEVEL;
    const dropped = roll_0_to_1 < chance;
    return .{
        .dropped_golden_axe = dropped,
        .golden_axe_damage = PIGLIN_BRUTE_BASE_DAMAGE,
        .experience_points = EXPERIENCE_POINTS_DROP,
        .drop_chance = chance,
        .looting_level = looting_level,
    };
}

// ============================================================================
// Attack & Zombification Results
// ============================================================================

pub const BruteAttackResult = struct {
    damage_dealt: f32,
    sound_effect: SoundEffect,
    alarm_result: AlarmBroadcastResult,
};

pub const ZombificationTickResult = struct {
    ticks_in_dimension: u32,
    is_shaking: bool,
    transformed: bool,
    zombified_piglin: ?ZombifiedPiglin = null,
};

// ============================================================================
// Piglin Brute Entity Struct
// ============================================================================

pub const PiglinBrute = struct {
    id: u32 = 1,
    pos: Vec3 = Vec3.zero,
    dimension: Dimension = .nether,
    health: f32 = PIGLIN_BRUTE_MAX_HEALTH,
    max_health: f32 = PIGLIN_BRUTE_MAX_HEALTH,
    attack_damage: f32 = PIGLIN_BRUTE_BASE_DAMAGE,

    // Visual identifier
    visuals: PiglinBruteVisuals = .{},

    // Non-respawning persistence: spawns only on world generation in Bastions; never respawns
    spawns_only_on_generation: bool = true,
    can_respawn: bool = false,
    is_structure_persistent: bool = true,

    // Gold Distraction & Pacification Immunity
    is_gold_armor_ignored: bool = true,
    is_barter_ignored: bool = true,
    is_always_hostile: bool = true,

    // Overworld / The End Zombification
    overworld_ticks: u32 = 0,
    is_shaking: bool = false,
    is_zombified: bool = false,

    // Combat & Alarm state
    target_player_id: ?u32 = null,
    has_sounded_alarm: bool = false,
    last_sound: ?SoundEffect = null,

    pub fn init(id: u32, pos: Vec3) PiglinBrute {
        return .{
            .id = id,
            .pos = pos,
            .dimension = .nether,
            .health = PIGLIN_BRUTE_MAX_HEALTH,
            .max_health = PIGLIN_BRUTE_MAX_HEALTH,
            .attack_damage = PIGLIN_BRUTE_BASE_DAMAGE,
            .visuals = .{},
            .spawns_only_on_generation = true,
            .can_respawn = false,
            .is_structure_persistent = true,
            .is_gold_armor_ignored = true,
            .is_barter_ignored = true,
            .is_always_hostile = true,
        };
    }

    pub fn initInBastion(id: u32, pos: Vec3) PiglinBrute {
        return init(id, pos);
    }

    /// Non-respawning flag: Piglin Brutes never respawn after defeat.
    pub fn canRespawnWhenKilled(self: PiglinBrute) bool {
        _ = self;
        return false;
    }

    /// Completely immune to gold armor pacification: Piglin Brute attacks players on sight
    /// regardless of whether they wear full golden armor.
    pub fn shouldAttackPlayer(self: PiglinBrute, armor: PlayerGoldArmor) bool {
        _ = armor;
        return self.is_always_hostile and self.is_gold_armor_ignored;
    }

    /// Check if pacified by player wearing gold armor. Always false!
    pub fn isPacifiedByGoldArmor(self: PiglinBrute, armor: PlayerGoldArmor) bool {
        _ = armor;
        _ = self;
        return false;
    }

    /// Completely immune to gold bartering distraction: Never picks up gold ingots,
    /// never barters, never pauses to inspect gold.
    pub fn canPickUpItem(self: PiglinBrute, item: ItemType) bool {
        _ = self;
        _ = item;
        return false;
    }

    pub fn attemptBarter(self: *PiglinBrute, item: ItemType) bool {
        _ = self;
        _ = item;
        return false;
    }

    /// When a Piglin Brute spots a player:
    /// - Emits a piercing war snort audio alarm (SoundEffect.brute_war_horn)
    /// - Coordinates alarm broadcast to nearby standard piglins within 16.0m Euclidean radius
    /// - Pacified piglins break pacification, drop ingots, and attack!
    pub fn spotPlayer(
        self: *PiglinBrute,
        player_id: u32,
        player_pos: Vec3,
        nearby_piglins: []StandardPiglin,
    ) AlarmBroadcastResult {
        self.target_player_id = player_id;
        self.has_sounded_alarm = true;
        self.last_sound = .brute_war_horn;

        return broadcastBastionAlarm(self.pos, player_id, player_pos, nearby_piglins);
    }

    /// Attack player: deals 13.0 HP attack damage, emits war snort alarm, alerts bastion garrison.
    pub fn attackPlayer(
        self: *PiglinBrute,
        player_id: u32,
        player_pos: Vec3,
        nearby_piglins: []StandardPiglin,
    ) BruteAttackResult {
        self.target_player_id = player_id;
        const emitted_sound: SoundEffect = .brute_war_horn;
        self.last_sound = emitted_sound;
        self.has_sounded_alarm = true;

        const alarm_result = broadcastBastionAlarm(self.pos, player_id, player_pos, nearby_piglins);

        return .{
            .damage_dealt = self.attack_damage,
            .sound_effect = emitted_sound,
            .alarm_result = alarm_result,
        };
    }

    /// Overworld and The End zombification tick:
    /// In Overworld or The End:
    /// - Begins shaking after entering and during the 15.0 seconds (300 ticks) duration.
    /// - After 300 ticks: transforms into a Zombified Piglin with 50.0 HP and golden axe.
    pub fn tickDimension(self: *PiglinBrute, current_dim: Dimension, delta_ticks: u32) ZombificationTickResult {
        self.dimension = current_dim;
        if (!current_dim.isOverworldOrEnd()) {
            self.overworld_ticks = 0;
            self.is_shaking = false;
            return .{
                .ticks_in_dimension = 0,
                .is_shaking = false,
                .transformed = false,
                .zombified_piglin = null,
            };
        }

        self.overworld_ticks += delta_ticks;
        self.is_shaking = true;

        if (self.overworld_ticks >= ZOMBIFICATION_TICKS and !self.is_zombified) {
            self.is_zombified = true;
            self.is_shaking = false;
            self.last_sound = .zombified_growl;
            const zombified = self.transformToZombifiedPiglin();
            return .{
                .ticks_in_dimension = self.overworld_ticks,
                .is_shaking = false,
                .transformed = true,
                .zombified_piglin = zombified,
            };
        }

        return .{
            .ticks_in_dimension = self.overworld_ticks,
            .is_shaking = true,
            .transformed = false,
            .zombified_piglin = null,
        };
    }

    /// Transform into Zombified Piglin with 50.0 HP and Golden Axe.
    pub fn transformToZombifiedPiglin(self: PiglinBrute) ZombifiedPiglin {
        return .{
            .id = self.id,
            .pos = self.pos,
            .health = PIGLIN_BRUTE_MAX_HEALTH,
            .max_health = PIGLIN_BRUTE_MAX_HEALTH,
            .attack_damage = self.attack_damage,
            .weapon = .golden_axe,
            .is_undead = true,
            .is_immune_to_fire = true,
            .xp_reward = EXPERIENCE_POINTS_DROP,
        };
    }

    /// Roll drops on defeat: Golden Axe (8.5% chance, scaled by Looting), 20 Experience Points.
    pub fn calculateDrops(self: PiglinBrute, looting_level: u8, roll_0_to_1: f32) PiglinBruteDrops {
        _ = self;
        return calculateDefeatDrops(looting_level, roll_0_to_1);
    }

    pub fn takeDamage(self: *PiglinBrute, damage: f32) void {
        if (damage <= 0.0) return;
        self.health = @max(0.0, self.health - damage);
        self.last_sound = if (self.health <= 0.0) .brute_death else .brute_hurt;
    }

    pub fn isDead(self: PiglinBrute) bool {
        return self.health <= 0.0;
    }
};

// ============================================================================
// Bastion Defense Tactics Encounter Coordinator
// ============================================================================

pub const BastionDefenseTactics = struct {
    brute: PiglinBrute,
    garrison: [32]StandardPiglin = undefined,
    garrison_count: usize = 0,

    pub fn init(brute_pos: Vec3) BastionDefenseTactics {
        return .{
            .brute = PiglinBrute.init(1, brute_pos),
            .garrison_count = 0,
        };
    }

    pub fn addStandardPiglin(self: *BastionDefenseTactics, piglin: StandardPiglin) bool {
        if (self.garrison_count >= self.garrison.len) return false;
        self.garrison[self.garrison_count] = piglin;
        self.garrison_count += 1;
        return true;
    }

    pub fn onPlayerDetected(self: *BastionDefenseTactics, player_id: u32, player_pos: Vec3) AlarmBroadcastResult {
        return self.brute.spotPlayer(player_id, player_pos, self.garrison[0..self.garrison_count]);
    }
};

// ============================================================================
// Unit Tests (25+ tests covering all specification requirements)
// ============================================================================

test "01: Piglin Brute has 50.0 HP max health pool (25 hearts)" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expectEqual(@as(f32, 50.0), brute.max_health);
    try std.testing.expectEqual(@as(f32, 50.0), brute.health);
    try std.testing.expectEqual(@as(f32, 25.0), PIGLIN_BRUTE_HEARTS);
    try std.testing.expectEqual(@as(f32, 50.0), PIGLIN_BRUTE_MAX_HEALTH);
}

test "02: Piglin Brute health is over 3x standard piglin 16.0 HP" {
    try std.testing.expectEqual(@as(f32, 16.0), STANDARD_PIGLIN_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 8.0), STANDARD_PIGLIN_HEARTS);
    try std.testing.expect(BRUTE_TO_STANDARD_HEALTH_RATIO >= 3.0);
    try std.testing.expectApproxEqAbs(@as(f32, 3.125), BRUTE_TO_STANDARD_HEALTH_RATIO, 0.001);
}

test "03: Piglin Brute deals 13.0 HP base melee damage with Golden Axe heavy blow" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expectEqual(@as(f32, 13.0), brute.attack_damage);
    try std.testing.expectEqual(@as(f32, 13.0), PIGLIN_BRUTE_BASE_DAMAGE);
}

test "04: Visual identifier: Golden arm band is present and styled" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expect(brute.visuals.golden_arm_band);
    try std.testing.expectEqual(@as(f32, 1.0), brute.visuals.arm_band_color[0]);
    try std.testing.expectEqual(@as(f32, 0.84), brute.visuals.arm_band_color[1]);
}

test "05: Visual identifier: Scarred blind eye is present" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expect(brute.visuals.scarred_blind_eye);
    try std.testing.expectEqual(brute.visuals.scar_side, .left);
}

test "06: Visual identifier: Two-handed Golden Axe stance" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expect(brute.visuals.two_handed_golden_axe_stance);
    try std.testing.expectEqual(VisualStance.two_handed_golden_axe, brute.visuals.stance);
}

test "07: Non-respawning: Spawns only upon world generation in Bastion Remnants" {
    const brute = PiglinBrute.initInBastion(1, Vec3.init(100, 60, 200));
    try std.testing.expect(brute.spawns_only_on_generation);
    try std.testing.expect(brute.is_structure_persistent);
}

test "08: Non-respawning: Never respawns after death (canRespawnWhenKilled is false)" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expect(!brute.can_respawn);
    try std.testing.expect(!brute.canRespawnWhenKilled());

    // Slay the brute
    brute.takeDamage(50.0);
    try std.testing.expect(brute.isDead());
    try std.testing.expect(!brute.canRespawnWhenKilled());
}

test "09: Gold armor immunity: is_gold_armor_ignored is true and is_always_hostile is true" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expect(brute.is_gold_armor_ignored);
    try std.testing.expect(brute.is_always_hostile);
}

test "10: Gold armor immunity: Hostile when player wears golden helmet" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    const armor = PlayerGoldArmor{ .helmet = true };
    try std.testing.expect(armor.hasAnyGold());
    try std.testing.expect(!armor.isFullGold());
    try std.testing.expect(brute.shouldAttackPlayer(armor));
    try std.testing.expect(!brute.isPacifiedByGoldArmor(armor));
}

test "11: Gold armor immunity: Hostile when player wears golden chestplate" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    const armor = PlayerGoldArmor{ .chestplate = true };
    try std.testing.expect(armor.hasAnyGold());
    try std.testing.expect(brute.shouldAttackPlayer(armor));
    try std.testing.expect(!brute.isPacifiedByGoldArmor(armor));
}

test "12: Gold armor immunity: Hostile when player wears golden leggings" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    const armor = PlayerGoldArmor{ .leggings = true };
    try std.testing.expect(armor.hasAnyGold());
    try std.testing.expect(brute.shouldAttackPlayer(armor));
    try std.testing.expect(!brute.isPacifiedByGoldArmor(armor));
}

test "13: Gold armor immunity: Hostile when player wears golden boots" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    const armor = PlayerGoldArmor{ .boots = true };
    try std.testing.expect(armor.hasAnyGold());
    try std.testing.expect(brute.shouldAttackPlayer(armor));
    try std.testing.expect(!brute.isPacifiedByGoldArmor(armor));
}

test "14: Gold armor immunity: Hostile when player wears full golden armor (all 4 pieces)" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    const armor = PlayerGoldArmor.full();
    try std.testing.expect(armor.hasAnyGold());
    try std.testing.expect(armor.isFullGold());
    try std.testing.expectEqual(@as(u8, 4), armor.pieceCount());
    try std.testing.expect(brute.shouldAttackPlayer(armor));
    try std.testing.expect(!brute.isPacifiedByGoldArmor(armor));
}

test "15: Barter distraction immunity: is_barter_ignored is true" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expect(brute.is_barter_ignored);
}

test "16: Barter distraction immunity: Never picks up gold ingots" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expect(!brute.canPickUpItem(.gold_ingot));
    try std.testing.expect(!brute.canPickUpItem(.gold_block));
    try std.testing.expect(!brute.canPickUpItem(.gold_nugget));
}

test "17: Barter distraction immunity: Never barters or pauses to inspect gold" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    try std.testing.expect(!brute.attemptBarter(.gold_ingot));
    try std.testing.expect(!brute.attemptBarter(.gold_block));
}

test "18: Bastion defense: Spotting player emits SoundEffect.brute_war_horn" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    var piglins = [_]StandardPiglin{};
    const broadcast = brute.spotPlayer(42, Vec3.init(5, 0, 5), &piglins);

    try std.testing.expectEqual(SoundEffect.brute_war_horn, broadcast.sound_effect);
    try std.testing.expectEqual(SoundEffect.brute_war_horn, brute.last_sound.?);
    try std.testing.expect(brute.has_sounded_alarm);
    try std.testing.expectEqual(@as(?u32, 42), brute.target_player_id);
}

test "19: Bastion defense: Attacking player emits SoundEffect.brute_war_horn and deals 13.0 damage" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    var piglins = [_]StandardPiglin{};
    const attack_res = brute.attackPlayer(42, Vec3.init(1, 0, 1), &piglins);

    try std.testing.expectEqual(@as(f32, 13.0), attack_res.damage_dealt);
    try std.testing.expectEqual(SoundEffect.brute_war_horn, attack_res.sound_effect);
    try std.testing.expectEqual(SoundEffect.brute_war_horn, attack_res.alarm_result.sound_effect);
}

test "20: Bastion defense alarm radius constant is exactly 16.0 meters Euclidean" {
    try std.testing.expectEqual(@as(f32, 16.0), ALARM_RADIUS);
    try std.testing.expectEqual(@as(f32, 256.0), ALARM_RADIUS_SQ);
}

test "21: Alarm broadcast: Alerts standard piglins within 16.0m Euclidean radius" {
    const brute_pos = Vec3.init(0, 0, 0);
    var piglins = [_]StandardPiglin{
        StandardPiglin.init(1, Vec3.init(5.0, 0.0, 0.0)), // dist = 5.0m
        StandardPiglin.init(2, Vec3.init(0.0, 10.0, 0.0)), // dist = 10.0m
        StandardPiglin.init(3, Vec3.init(9.0, 9.0, 0.0)), // dist = sqrt(162) = ~12.7m
    };

    const res = broadcastBastionAlarm(brute_pos, 99, Vec3.zero, &piglins);
    try std.testing.expectEqual(@as(usize, 3), res.alerted_piglin_count);
    try std.testing.expectEqual(@as(usize, 0), res.out_of_range_count);

    for (piglins) |p| {
        try std.testing.expect(p.is_angry);
        try std.testing.expectEqual(@as(?u32, 99), p.target_player_id);
    }
}

test "22: Alarm broadcast boundary: Alerts at exactly 16.0m but ignores at 16.01m" {
    const brute_pos = Vec3.zero;
    var piglins = [_]StandardPiglin{
        StandardPiglin.init(1, Vec3.init(16.0, 0.0, 0.0)), // dist = 16.0m (in range)
        StandardPiglin.init(2, Vec3.init(16.01, 0.0, 0.0)), // dist = 16.01m (out of range)
        StandardPiglin.init(3, Vec3.init(0.0, 0.0, 25.0)), // dist = 25.0m (out of range)
    };

    const res = broadcastBastionAlarm(brute_pos, 77, Vec3.zero, &piglins);
    try std.testing.expectEqual(@as(usize, 1), res.alerted_piglin_count);
    try std.testing.expectEqual(@as(usize, 2), res.out_of_range_count);

    try std.testing.expect(piglins[0].is_angry);
    try std.testing.expect(!piglins[1].is_angry);
    try std.testing.expect(!piglins[2].is_angry);
}

test "23: Pacification break: Pacified piglin wearing gold armor breaks pacification" {
    var piglin = StandardPiglin.init(1, Vec3.init(4.0, 0.0, 0.0));
    piglin.is_pacified = true;

    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_angry);

    const broke = piglin.alertToAttack(55);
    try std.testing.expect(broke);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_angry);
    try std.testing.expectEqual(PiglinActivity.attacking_player, piglin.activity);
    try std.testing.expectEqual(SoundEffect.piglin_angry, piglin.last_sound.?);
}

test "24: Pacification break: Piglin inspecting gold ingot drops ingot immediately and attacks" {
    var piglin = StandardPiglin.initInspectingGold(1, Vec3.init(3.0, 0.0, 0.0));

    try std.testing.expect(piglin.inspecting_ingot);
    try std.testing.expectEqual(@as(u16, 120), piglin.barter_ticks);
    try std.testing.expectEqual(@as(u32, 0), piglin.dropped_ingot_count);

    const broke = piglin.alertToAttack(88);
    try std.testing.expect(broke);
    try std.testing.expect(!piglin.inspecting_ingot);
    try std.testing.expectEqual(@as(u16, 0), piglin.barter_ticks);
    try std.testing.expectEqual(@as(u32, 1), piglin.dropped_ingot_count);
    try std.testing.expect(piglin.is_angry);
    try std.testing.expectEqual(@as(?u32, 88), piglin.target_player_id);
}

test "25: Coordinated Bastion defense: Multiple piglins (pacified & inspecting) alerted at once" {
    const brute_pos = Vec3.init(0, 0, 0);
    var piglins = [_]StandardPiglin{
        StandardPiglin.init(1, Vec3.init(5, 0, 0)),
        StandardPiglin.initInspectingGold(2, Vec3.init(8, 0, 0)),
        StandardPiglin.initInspectingGold(3, Vec3.init(12, 0, 0)),
        StandardPiglin.init(4, Vec3.init(20, 0, 0)), // out of range
    };

    const res = broadcastBastionAlarm(brute_pos, 101, Vec3.zero, &piglins);

    try std.testing.expectEqual(@as(usize, 3), res.alerted_piglin_count);
    try std.testing.expectEqual(@as(usize, 3), res.pacification_broken_count);
    try std.testing.expectEqual(@as(usize, 2), res.dropped_ingots_count);
    try std.testing.expectEqual(@as(usize, 1), res.out_of_range_count);

    try std.testing.expect(piglins[0].is_angry);
    try std.testing.expect(piglins[1].is_angry);
    try std.testing.expect(piglins[2].is_angry);
    try std.testing.expect(!piglins[3].is_angry);
}

test "26: Overworld zombification: Nether native does not shake or zombify" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    const tick_res = brute.tickDimension(.nether, 500);

    try std.testing.expect(!tick_res.is_shaking);
    try std.testing.expect(!tick_res.transformed);
    try std.testing.expect(tick_res.zombified_piglin == null);
    try std.testing.expectEqual(@as(u32, 0), brute.overworld_ticks);
    try std.testing.expect(!brute.is_shaking);
    try std.testing.expect(!brute.is_zombified);
}

test "27: Overworld zombification: Begins shaking in Overworld" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    const tick_res = brute.tickDimension(.overworld, 100);

    try std.testing.expect(tick_res.is_shaking);
    try std.testing.expect(!tick_res.transformed);
    try std.testing.expectEqual(@as(u32, 100), tick_res.ticks_in_dimension);
    try std.testing.expect(brute.is_shaking);
    try std.testing.expect(!brute.is_zombified);
}

test "28: Overworld zombification: 299 ticks is not yet transformed" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    const tick_res = brute.tickDimension(.overworld, 299);

    try std.testing.expect(tick_res.is_shaking);
    try std.testing.expect(!tick_res.transformed);
    try std.testing.expect(tick_res.zombified_piglin == null);
}

test "29: Overworld zombification: Transforms into Zombified Piglin after exactly 300 ticks (15.0s)" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    _ = brute.tickDimension(.overworld, 299);
    const final_tick = brute.tickDimension(.overworld, 1);

    try std.testing.expect(final_tick.transformed);
    try std.testing.expect(final_tick.zombified_piglin != null);
    try std.testing.expect(brute.is_zombified);
    try std.testing.expect(!brute.is_shaking);
    try std.testing.expectEqual(SoundEffect.zombified_growl, brute.last_sound.?);
}

test "30: Zombified Piglin properties: Retains 50.0 HP and golden axe weapon" {
    var brute = PiglinBrute.init(42, Vec3.init(10, 20, 30));
    const zombified = brute.transformToZombifiedPiglin();

    try std.testing.expectEqual(@as(u32, 42), zombified.id);
    try std.testing.expectEqual(@as(f32, 50.0), zombified.max_health);
    try std.testing.expectEqual(@as(f32, 50.0), zombified.health);
    try std.testing.expectEqual(@as(f32, 13.0), zombified.attack_damage);
    try std.testing.expectEqual(ItemType.golden_axe, zombified.weapon);
    try std.testing.expect(zombified.is_undead);
    try std.testing.expect(zombified.is_immune_to_fire);
    try std.testing.expectEqual(@as(u32, 20), zombified.xp_reward);
}

test "31: Overworld zombification: The End dimension triggers identical 300-tick zombification" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    const tick_res = brute.tickDimension(.the_end, 300);

    try std.testing.expect(tick_res.transformed);
    try std.testing.expect(tick_res.zombified_piglin != null);
    try std.testing.expectEqual(@as(f32, 50.0), tick_res.zombified_piglin.?.max_health);
}

test "32: Drops on defeat: Drops 20 Experience Points (high XP drop)" {
    const brute = PiglinBrute.init(1, Vec3.zero);
    const drops = brute.calculateDrops(0, 0.5);

    try std.testing.expectEqual(@as(u32, 20), drops.experience_points);
    try std.testing.expectEqual(@as(u32, 20), EXPERIENCE_POINTS_DROP);
}

test "33: Drops on defeat: Golden Axe drops at base 8.5% chance without Looting" {
    try std.testing.expectEqual(@as(f32, 0.085), GOLDEN_AXE_BASE_DROP_CHANCE);

    // Roll 0.08 is < 0.085 -> drops axe
    const drop_success = calculateDefeatDrops(0, 0.08);
    try std.testing.expect(drop_success.dropped_golden_axe);
    try std.testing.expectApproxEqAbs(@as(f32, 0.085), drop_success.drop_chance, 0.0001);

    // Roll 0.086 is >= 0.085 -> does not drop axe
    const drop_fail = calculateDefeatDrops(0, 0.086);
    try std.testing.expect(!drop_fail.dropped_golden_axe);
}

test "34: Drops on defeat: Looting I increases drop chance to 9.5%" {
    const drops = calculateDefeatDrops(1, 0.09);
    try std.testing.expectApproxEqAbs(@as(f32, 0.095), drops.drop_chance, 0.0001);
    try std.testing.expect(drops.dropped_golden_axe);

    const fail = calculateDefeatDrops(1, 0.096);
    try std.testing.expect(!fail.dropped_golden_axe);
}

test "35: Drops on defeat: Looting III increases drop chance to 11.5%" {
    const drops = calculateDefeatDrops(3, 0.11);
    try std.testing.expectApproxEqAbs(@as(f32, 0.115), drops.drop_chance, 0.0001);
    try std.testing.expect(drops.dropped_golden_axe);

    const fail = calculateDefeatDrops(3, 0.12);
    try std.testing.expect(!fail.dropped_golden_axe);
}

test "36: Combat damage: Taking damage reduces health and triggers hurt/death sounds" {
    var brute = PiglinBrute.init(1, Vec3.zero);
    brute.takeDamage(20.0);
    try std.testing.expectEqual(@as(f32, 30.0), brute.health);
    try std.testing.expectEqual(SoundEffect.brute_hurt, brute.last_sound.?);

    brute.takeDamage(35.0);
    try std.testing.expectEqual(@as(f32, 0.0), brute.health);
    try std.testing.expect(brute.isDead());
    try std.testing.expectEqual(SoundEffect.brute_death, brute.last_sound.?);
}

test "37: Bastion encounter simulation: BastionDefenseTactics coordinates full defense" {
    var bastion = BastionDefenseTactics.init(Vec3.init(0, 0, 0));
    _ = bastion.addStandardPiglin(StandardPiglin.init(10, Vec3.init(4, 0, 0)));
    _ = bastion.addStandardPiglin(StandardPiglin.initInspectingGold(11, Vec3.init(8, 0, 0)));
    _ = bastion.addStandardPiglin(StandardPiglin.init(12, Vec3.init(25, 0, 0))); // far

    try std.testing.expectEqual(@as(usize, 3), bastion.garrison_count);

    const alarm = bastion.onPlayerDetected(999, Vec3.init(2, 0, 2));
    try std.testing.expectEqual(@as(usize, 2), alarm.alerted_piglin_count);
    try std.testing.expectEqual(@as(usize, 1), alarm.dropped_ingots_count);
    try std.testing.expectEqual(SoundEffect.brute_war_horn, alarm.sound_effect);
}
