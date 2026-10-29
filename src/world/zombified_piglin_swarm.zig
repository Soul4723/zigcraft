//! ============================================================================
//! Milestone 483: Zombified Piglin Neutrality & Group Alarm Swarm in Zigcraft
//! ============================================================================
//!
//! Overview:
//!   Zombified Piglins (formerly Zombie Pigmen) are undead humanoid mobs that roam
//!   the Nether in nomadic packs. Naturally neutral and docile, they passively ignore
//!   players, wandering peacefully through Nether wastes, crimson forests, and basalt deltas.
//!   However, if any Zombified Piglin is struck or damaged by a player:
//!     - It emits a piercing zombie pigman screech audio cue (`SoundEffect.zombified_piglin_screech`).
//!     - It broadcasts an alarm swarm call to all nearby Zombified Piglins within a
//!       40.0m Euclidean radius (`SWARM_ALARM_RADIUS = 40.0`).
//!     - Line-of-sight is NOT required for swarm alerts: the piercing screech penetrates
//!       walls, ceilings, caves, and basalt pillars.
//!     - All alerted Zombified Piglins enter the `.angered` state, targeting the attacking player,
//!       and sprint at 4.35 m/s (+45% speed boost over neutral 3.0 m/s walk).
//!     - Anger lasts 400 to 799 game ticks (20.0 to 39.95s).
//!     - Continuous pursuit: while a player remains in line-of-sight within 16.0m,
//!       the anger timer resets, maintaining an relentless pursuit!
//!     - When the anger timer expires without seeing the player, the mob transitions
//!       to `.calming` and then returns to `.neutral` (anger forgiven).
//!     - Complete undead fire immunity: immune to fire, lava, and burning damage (`isImmuneToLava = true`, `isImmuneToFire = true`).
//!     - Reinforcement calling: taking damage has a 10% chance to summon another Zombified
//!       Piglin within 16 blocks.
//!     - Drops on defeat: Rotten Flesh (0–1), Gold Nuggets (0–1, scaled by Looting),
//!       Golden Sword (8.5% chance, scaled by Looting), and 5 Experience Points.
//! ============================================================================

const std = @import("std");

// ============================================================================
// Core Constants
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;

/// Health attributes: 20.0 HP = 10 hearts
pub const MAX_HEALTH: f32 = 20.0;
pub const HEARTS: f32 = 10.0;
pub const ZOMBIFIED_PIGLIN_MAX_HEALTH: f32 = 20.0;
pub const ZOMBIFIED_PIGLIN_HEARTS: f32 = 10.0;

/// Base melee attack damage with golden sword (5.0 HP = 2.5 hearts)
pub const BASE_ATTACK_DAMAGE: f32 = 5.0;

/// Movement speeds: neutral walk is 3.0 m/s; angered sprint is +45% (4.35 m/s)
pub const NEUTRAL_WALK_SPEED: f32 = 3.0;
pub const SPRINT_SPEED_BOOST: f32 = 0.45;
pub const ANGERED_SPRINT_SPEED: f32 = 4.35; // 3.0 * (1.0 + 0.45) = 4.35

/// 40-Block Group Alarm Swarm Propagation radius (40.0 meters Euclidean)
pub const SWARM_ALARM_RADIUS: f32 = 40.0;
pub const SWARM_ALARM_RADIUS_SQ: f32 = SWARM_ALARM_RADIUS * SWARM_ALARM_RADIUS; // 1600.0
pub const swarm_alarm_radius: f32 = 40.0;

/// Re-aggro pursuit maintenance radius (16.0 meters with line-of-sight)
pub const RE_AGGRO_RADIUS: f32 = 16.0;
pub const RE_AGGRO_RADIUS_SQ: f32 = RE_AGGRO_RADIUS * RE_AGGRO_RADIUS; // 256.0

/// Anger duration cycle: 400 to 799 game ticks (20.0 to 39.95 seconds)
pub const MIN_ANGER_TICKS: u32 = 400;
pub const MAX_ANGER_TICKS: u32 = 799;
pub const MIN_ANGER_SECONDS: f32 = 20.0;
pub const MAX_ANGER_SECONDS: f32 = 39.95;

/// Calming transition duration before returning to neutral (20 ticks = 1.0s)
pub const CALMING_DURATION_TICKS: u32 = 20;

/// Undead fire and lava immunity flags (module-level constants)
pub const isImmuneToLava: bool = true;
pub const isImmuneToFire: bool = true;
pub const IS_IMMUNE_TO_LAVA: bool = true;
pub const IS_IMMUNE_TO_FIRE: bool = true;

/// Reinforcement calling: 10% chance to summon another piglin within 16 blocks
pub const REINFORCEMENT_CHANCE: f32 = 0.10;
pub const REINFORCEMENT_RADIUS: f32 = 16.0;

/// Drops on defeat
pub const GOLDEN_SWORD_BASE_DROP_CHANCE: f32 = 0.085; // 8.5% base chance
pub const LOOTING_SWORD_BONUS_PER_LEVEL: f32 = 0.01; // +1.0% per Looting level
pub const EXPERIENCE_POINTS_DROP: u32 = 5; // 5 XP

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
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
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

/// Zombified Piglin state machine
pub const ZombifiedPiglinState = enum(u8) {
    neutral,
    angered,
    calming,
};

pub const SoundEffect = enum(u8) {
    zombified_piglin_screech, // Piercing screech audio cue when provoked or broadcasting alarm
    zombified_piglin_angry,   // Angry growl/snarl when entering swarm pursuit
    zombified_piglin_hurt,    // Hurt grunt on taking damage
    zombified_piglin_death,   // Death groan
    zombified_piglin_ambient, // Idle snort/groan
    zombified_piglin_reinforcement, // Audio flare when reinforcement arrives
};

pub const DamageSource = enum(u8) {
    generic,
    player_attack,
    mob_attack,
    fire,
    lava,
    burning,
    fall,
    drowning,
    explosion,

    pub fn isFireOrLava(self: DamageSource) bool {
        return self == .fire or self == .lava or self == .burning;
    }
};

pub const ItemType = enum(u16) {
    none = 0,
    rotten_flesh = 367,
    gold_nugget = 371,
    golden_sword = 283,
    gold_ingot = 266,

    pub fn isGold(self: ItemType) bool {
        return switch (self) {
            .gold_nugget, .golden_sword, .gold_ingot => true,
            else => false,
        };
    }
};

// ============================================================================
// Sampling & Drops Helpers
// ============================================================================

/// Samples an anger duration in ticks between 400 and 799 game ticks (20.0 to 39.95s)
/// from a uniform distribution [0.0, 1.0].
pub fn sampleAngerTicks(roll_0_to_1: f32) u32 {
    const clamped = @max(0.0, @min(1.0, roll_0_to_1));
    const range: f32 = @floatFromInt(MAX_ANGER_TICKS - MIN_ANGER_TICKS + 1); // 400
    const offset = @as(u32, @intFromFloat(clamped * range));
    const result = MIN_ANGER_TICKS + offset;
    return @min(result, MAX_ANGER_TICKS);
}

pub const ZombifiedPiglinDrops = struct {
    rotten_flesh_count: u32,
    gold_nugget_count: u32,
    dropped_golden_sword: bool,
    experience_points: u32 = EXPERIENCE_POINTS_DROP,
    golden_sword_drop_chance: f32,
    looting_level: u8,
};

/// Calculates item drops on defeat:
/// - Rotten Flesh (0–1 base, scaled with Looting)
/// - Gold Nuggets (0–1 base, scaled with Looting)
/// - Golden Sword (8.5% base chance, +1.0% per Looting level)
/// - 5 Experience Points
pub fn calculateDefeatDrops(
    looting_level: u8,
    flesh_roll: f32,
    nugget_roll: f32,
    sword_roll: f32,
) ZombifiedPiglinDrops {
    const clamped_flesh = @max(0.0, @min(1.0, flesh_roll));
    const clamped_nugget = @max(0.0, @min(1.0, nugget_roll));
    const clamped_sword = @max(0.0, @min(1.0, sword_roll));

    // Base flesh: 0-1, with Looting increasing maximum by 1 per level
    const max_flesh: u32 = 1 + @as(u32, looting_level);
    const flesh_count: u32 = if (clamped_flesh < 0.5)
        0
    else
        @min(max_flesh, 1 + @as(u32, @intFromFloat(clamped_flesh * @as(f32, @floatFromInt(looting_level)))));

    // Base gold nuggets: 0-1, with Looting increasing maximum by 1 per level
    const max_nuggets: u32 = 1 + @as(u32, looting_level);
    const nugget_count: u32 = if (clamped_nugget < 0.5)
        0
    else
        @min(max_nuggets, 1 + @as(u32, @intFromFloat(clamped_nugget * @as(f32, @floatFromInt(looting_level)))));

    // Golden sword: 8.5% base + 1.0% per Looting level
    const sword_chance = GOLDEN_SWORD_BASE_DROP_CHANCE + @as(f32, @floatFromInt(looting_level)) * LOOTING_SWORD_BONUS_PER_LEVEL;
    const dropped_sword = clamped_sword < sword_chance;

    return .{
        .rotten_flesh_count = flesh_count,
        .gold_nugget_count = nugget_count,
        .dropped_golden_sword = dropped_sword,
        .experience_points = EXPERIENCE_POINTS_DROP,
        .golden_sword_drop_chance = sword_chance,
        .looting_level = looting_level,
    };
}

// ============================================================================
// Alarm Broadcast & Reinforcement Types
// ============================================================================

pub const SwarmAlarmResult = struct {
    sound_effect: SoundEffect = .zombified_piglin_screech,
    provoker_player_id: u32,
    origin_pos: Vec3,
    alerted_count: usize = 0,
    already_angry_count: usize = 0,
    out_of_range_count: usize = 0,
    total_in_swarm: usize = 0,
};

pub const ReinforcementResult = struct {
    summoned: bool,
    spawn_pos: Vec3,
    reinforcement: ?ZombifiedPiglin = null,
};

pub const DamageResult = struct {
    damage_dealt: f32,
    was_immune: bool = false,
    was_fatal: bool = false,
    sound_emitted: ?SoundEffect = null,
    reinforcement: ReinforcementResult,
};

// ============================================================================
// Zombified Piglin Entity
// ============================================================================

pub const ZombifiedPiglin = struct {
    id: u32,
    pos: Vec3,
    health: f32 = MAX_HEALTH,
    max_health: f32 = MAX_HEALTH,
    state: ZombifiedPiglinState = .neutral,
    target_player_id: ?u32 = null,
    anger_ticks: u32 = 0,
    calming_ticks: u32 = 0,
    movement_speed: f32 = NEUTRAL_WALK_SPEED,
    last_sound: ?SoundEffect = null,
    is_alive: bool = true,
    is_undead: bool = true,

    /// Undead fire and lava immunity fields
    isImmuneToLava: bool = true,
    isImmuneToFire: bool = true,
    is_immune_to_lava: bool = true,
    is_immune_to_fire: bool = true,

    weapon: ItemType = .golden_sword,
    attack_damage: f32 = BASE_ATTACK_DAMAGE,
    reinforcements_summoned_count: u32 = 0,
    ticks_lived: u64 = 0,
    rng_state: u64 = 0,

    pub fn init(id: u32, pos: Vec3) ZombifiedPiglin {
        var piglin = ZombifiedPiglin{
            .id = id,
            .pos = pos,
            .health = MAX_HEALTH,
            .max_health = MAX_HEALTH,
            .state = .neutral,
            .target_player_id = null,
            .anger_ticks = 0,
            .calming_ticks = 0,
            .movement_speed = NEUTRAL_WALK_SPEED,
            .last_sound = null,
            .is_alive = true,
            .is_undead = true,
            .isImmuneToLava = true,
            .isImmuneToFire = true,
            .is_immune_to_lava = true,
            .is_immune_to_fire = true,
            .weapon = .golden_sword,
            .attack_damage = BASE_ATTACK_DAMAGE,
            .reinforcements_summoned_count = 0,
            .ticks_lived = 0,
            .rng_state = @as(u64, id) *% 6364136223846793005 +% 1442695040888963407,
        };
        // Warm up PRNG state
        _ = piglin.pseudoRandomRoll();
        return piglin;
    }

    /// Internal PRNG roll in [0.0, 1.0)
    pub fn pseudoRandomRoll(self: *ZombifiedPiglin) f32 {
        self.rng_state = self.rng_state *% 6364136223846793005 +% 1442695040888963407;
        const val = @as(u32, @truncate(self.rng_state >> 32));
        return @as(f32, @floatFromInt(val % 100000)) / 100000.0;
    }

    pub fn isNeutral(self: ZombifiedPiglin) bool {
        return self.state == .neutral;
    }

    pub fn isAngered(self: ZombifiedPiglin) bool {
        return self.state == .angered;
    }

    pub fn isCalming(self: ZombifiedPiglin) bool {
        return self.state == .calming;
    }

    pub fn isDead(self: ZombifiedPiglin) bool {
        return !self.is_alive or self.health <= 0.0;
    }

    pub fn getMovementSpeed(self: ZombifiedPiglin) f32 {
        return switch (self.state) {
            .angered => ANGERED_SPRINT_SPEED,
            .neutral, .calming => NEUTRAL_WALK_SPEED,
        };
    }

    /// Trigger anger towards a player.
    /// Sets state to `.angered`, records `target_player_id`,
    /// samples anger timer in uniform range [400, 799] ticks,
    /// increases movement speed to 4.35 m/s (+45%), and emits screech.
    pub fn angerAt(self: *ZombifiedPiglin, player_id: u32) void {
        const roll = self.pseudoRandomRoll();
        const ticks = sampleAngerTicks(roll);
        self.angerAtWithTicks(player_id, ticks);
    }

    /// Anger at player with explicit tick duration (for deterministic tests)
    pub fn angerAtWithTicks(self: *ZombifiedPiglin, player_id: u32, ticks: u32) void {
        self.state = .angered;
        self.target_player_id = player_id;
        self.anger_ticks = ticks;
        self.calming_ticks = 0;
        self.movement_speed = ANGERED_SPRINT_SPEED;
        self.last_sound = .zombified_piglin_screech;
    }

    /// Anger at player with explicit uniform roll in [0.0, 1.0]
    pub fn angerAtWithRoll(self: *ZombifiedPiglin, player_id: u32, roll_0_to_1: f32) void {
        const ticks = sampleAngerTicks(roll_0_to_1);
        self.angerAtWithTicks(player_id, ticks);
    }

    /// Resets the anger timer during continuous pursuit.
    pub fn resetAngerTimer(self: *ZombifiedPiglin, custom_ticks: ?u32) void {
        if (custom_ticks) |t| {
            self.anger_ticks = t;
        } else {
            const roll = self.pseudoRandomRoll();
            self.anger_ticks = sampleAngerTicks(roll);
        }
    }

    /// Checks if line-of-sight and proximity within 16m refresh anger pursuit.
    pub fn checkReAggro(self: *ZombifiedPiglin, player_pos: Vec3, has_line_of_sight: bool) bool {
        if (self.state != .angered or self.target_player_id == null) return false;

        const distance_sq = self.pos.distSq(player_pos);
        if (has_line_of_sight and distance_sq <= RE_AGGRO_RADIUS_SQ) {
            self.resetAngerTimer(null);
            return true;
        }
        return false;
    }

    /// Advances the zombified piglin's state by `delta_ticks`.
    /// Handles:
    /// - Continuous pursuit re-aggro if player is in line-of-sight within 16m
    /// - Anger timer countdown when player is not seen
    /// - Transition from `.angered` -> `.calming` when timer reaches 0
    /// - Transition from `.calming` -> `.neutral` when calming concludes (anger forgiven)
    pub fn tick(
        self: *ZombifiedPiglin,
        delta_ticks: u32,
        player_pos: ?Vec3,
        has_line_of_sight: bool,
    ) void {
        if (!self.is_alive) return;
        self.ticks_lived += delta_ticks;

        switch (self.state) {
            .neutral => {
                // Natural neutrality: passively wander, ignoring player
                self.target_player_id = null;
                self.movement_speed = NEUTRAL_WALK_SPEED;
            },
            .angered => {
                self.movement_speed = ANGERED_SPRINT_SPEED;

                // Re-aggro check: while player remains within LOS and 16m, reset timer!
                var maintained_pursuit = false;
                if (player_pos) |target_pos| {
                    if (has_line_of_sight and self.pos.distSq(target_pos) <= RE_AGGRO_RADIUS_SQ) {
                        self.resetAngerTimer(null);
                        maintained_pursuit = true;
                    }
                }

                // If pursuit was not refreshed by visible player proximity, decrement anger timer
                if (!maintained_pursuit) {
                    if (self.anger_ticks > delta_ticks) {
                        self.anger_ticks -= delta_ticks;
                    } else {
                        // Timer expired without seeing the player: transition to calming
                        const excess_ticks = delta_ticks - self.anger_ticks;
                        self.anger_ticks = 0;
                        self.state = .calming;
                        self.calming_ticks = CALMING_DURATION_TICKS;

                        if (excess_ticks > 0) {
                            if (self.calming_ticks > excess_ticks) {
                                self.calming_ticks -= excess_ticks;
                            } else {
                                self.calming_ticks = 0;
                                self.state = .neutral;
                                self.target_player_id = null;
                                self.movement_speed = NEUTRAL_WALK_SPEED;
                            }
                        }
                    }
                }
            },
            .calming => {
                // In calming phase: slowing down to neutral
                if (self.calming_ticks > delta_ticks) {
                    self.calming_ticks -= delta_ticks;
                } else {
                    // Anger completely forgiven: return to neutral state
                    self.calming_ticks = 0;
                    self.state = .neutral;
                    self.target_player_id = null;
                    self.movement_speed = NEUTRAL_WALK_SPEED;
                }
            },
        }
    }

    /// Applies damage to the zombified piglin with full fire/lava immunity check,
    /// provokes anger towards attacking players, and rolls for reinforcement summoning.
    pub fn takeDamage(
        self: *ZombifiedPiglin,
        damage: f32,
        source: DamageSource,
        attacker_player_id: ?u32,
        reinforcement_roll: ?f32,
        next_reinforcement_id: ?u32,
    ) DamageResult {
        // Complete fire, lava, and burning immunity
        if (source.isFireOrLava()) {
            return .{
                .damage_dealt = 0.0,
                .was_immune = true,
                .was_fatal = false,
                .sound_emitted = null,
                .reinforcement = .{ .summoned = false, .spawn_pos = self.pos, .reinforcement = null },
            };
        }

        if (damage <= 0.0 or !self.is_alive) {
            return .{
                .damage_dealt = 0.0,
                .was_immune = false,
                .was_fatal = !self.is_alive,
                .sound_emitted = null,
                .reinforcement = .{ .summoned = false, .spawn_pos = self.pos, .reinforcement = null },
            };
        }

        self.health = @max(0.0, self.health - damage);
        const was_fatal = (self.health <= 0.0);
        if (was_fatal) {
            self.is_alive = false;
            self.last_sound = .zombified_piglin_death;
        } else {
            self.last_sound = .zombified_piglin_hurt;
        }

        // If damaged by a player, trigger anger
        if (attacker_player_id) |p_id| {
            if (self.is_alive) {
                self.angerAt(p_id);
                self.last_sound = .zombified_piglin_screech;
            }
        }

        // Reinforcement calling: 10% chance to summon another piglin within 16 blocks
        var reinf_result = ReinforcementResult{
            .summoned = false,
            .spawn_pos = self.pos,
            .reinforcement = null,
        };

        const roll = reinforcement_roll orelse self.pseudoRandomRoll();
        if (roll < REINFORCEMENT_CHANCE) {
            const reinf_id = next_reinforcement_id orelse (self.id + 1000 + self.reinforcements_summoned_count + 1);
            reinf_result = self.rollReinforcement(roll, attacker_player_id, reinf_id);
        }

        return .{
            .damage_dealt = damage,
            .was_immune = false,
            .was_fatal = was_fatal,
            .sound_emitted = self.last_sound,
            .reinforcement = reinf_result,
        };
    }

    /// Spawns a reinforcement Zombified Piglin within 16 blocks
    pub fn rollReinforcement(
        self: *ZombifiedPiglin,
        roll: f32,
        attacker_player_id: ?u32,
        new_id: u32,
    ) ReinforcementResult {
        if (roll >= REINFORCEMENT_CHANCE) {
            return .{
                .summoned = false,
                .spawn_pos = self.pos,
                .reinforcement = null,
            };
        }

        self.reinforcements_summoned_count += 1;

        // Position reinforcement within 16 blocks (deterministic offset based on count and id)
        const angle = @as(f32, @floatFromInt((self.reinforcements_summoned_count * 57) % 360)) * (std.math.pi / 180.0);
        const dist_offset: f32 = 4.0 + @as(f32, @floatFromInt((new_id % 12))); // 4.0m to 15.0m <= 16.0m
        const spawn_pos = Vec3.init(
            self.pos.x + @cos(angle) * dist_offset,
            self.pos.y,
            self.pos.z + @sin(angle) * dist_offset,
        );

        var reinforcement = ZombifiedPiglin.init(new_id, spawn_pos);
        if (attacker_player_id) |p_id| {
            reinforcement.angerAt(p_id);
            reinforcement.last_sound = .zombified_piglin_screech;
        }

        return .{
            .summoned = true,
            .spawn_pos = spawn_pos,
            .reinforcement = reinforcement,
        };
    }

    /// Calculate drops on defeat
    pub fn calculateDrops(
        self: ZombifiedPiglin,
        looting_level: u8,
        flesh_roll: f32,
        nugget_roll: f32,
        sword_roll: f32,
    ) ZombifiedPiglinDrops {
        _ = self;
        return calculateDefeatDrops(looting_level, flesh_roll, nugget_roll, sword_roll);
    }

    /// Calculate drops on defeat using internal PRNG
    pub fn calculateDropsWithRng(self: *ZombifiedPiglin, looting_level: u8) ZombifiedPiglinDrops {
        const f_roll = self.pseudoRandomRoll();
        const n_roll = self.pseudoRandomRoll();
        const s_roll = self.pseudoRandomRoll();
        return calculateDefeatDrops(looting_level, f_roll, n_roll, s_roll);
    }
};

// ============================================================================
// 40-Block Group Alarm Swarm Broadcast
// ============================================================================

/// Broadcasts group alarm swarm call when a Zombified Piglin is provoked or attacked:
/// - Emits piercing zombie pigman screech audio cue (`SoundEffect.zombified_piglin_screech`).
/// - Alerts all nearby Zombified Piglins within a 40.0m Euclidean radius (`SWARM_ALARM_RADIUS = 40.0`).
/// - Line-of-sight check NOT required: propagates through solid walls and caves within 40m.
/// - Every alerted Zombified Piglin enters `.angered` state targeting the provoker player.
pub fn broadcastSwarmAlarm(
    provoked_piglin: *ZombifiedPiglin,
    player_id: u32,
    swarm: []ZombifiedPiglin,
) SwarmAlarmResult {
    // Provoked piglin itself angers and screeches
    provoked_piglin.angerAt(player_id);
    provoked_piglin.last_sound = .zombified_piglin_screech;

    var result = SwarmAlarmResult{
        .sound_effect = .zombified_piglin_screech,
        .provoker_player_id = player_id,
        .origin_pos = provoked_piglin.pos,
        .total_in_swarm = swarm.len,
    };

    for (swarm) |*other| {
        if (other.id == provoked_piglin.id) continue;
        if (!other.is_alive) continue;

        const distance = provoked_piglin.pos.dist(other.pos);
        if (distance <= SWARM_ALARM_RADIUS) {
            const was_already_angry = (other.state == .angered and other.target_player_id == player_id);
            other.angerAt(player_id);
            other.last_sound = .zombified_piglin_angry;

            if (was_already_angry) {
                result.already_angry_count += 1;
            } else {
                result.alerted_count += 1;
            }
        } else {
            result.out_of_range_count += 1;
        }
    }

    return result;
}

/// Swarm alarm broadcast from arbitrary origin coordinate
pub fn broadcastSwarmAlarmFromPos(
    origin_pos: Vec3,
    player_id: u32,
    swarm: []ZombifiedPiglin,
) SwarmAlarmResult {
    var result = SwarmAlarmResult{
        .sound_effect = .zombified_piglin_screech,
        .provoker_player_id = player_id,
        .origin_pos = origin_pos,
        .total_in_swarm = swarm.len,
    };

    for (swarm) |*piglin| {
        if (!piglin.is_alive) continue;

        const distance = origin_pos.dist(piglin.pos);
        if (distance <= SWARM_ALARM_RADIUS) {
            const was_already_angry = (piglin.state == .angered and piglin.target_player_id == player_id);
            piglin.angerAt(player_id);
            piglin.last_sound = .zombified_piglin_angry;

            if (was_already_angry) {
                result.already_angry_count += 1;
            } else {
                result.alerted_count += 1;
            }
        } else {
            result.out_of_range_count += 1;
        }
    }

    return result;
}

// ============================================================================
// Swarm Coordinator / Pack Manager
// ============================================================================

pub const ZombifiedPiglinSwarm = struct {
    piglins: [64]ZombifiedPiglin = undefined,
    count: usize = 0,
    next_id: u32 = 100,

    pub fn init() ZombifiedPiglinSwarm {
        return .{};
    }

    pub fn addPiglin(self: *ZombifiedPiglinSwarm, piglin: ZombifiedPiglin) bool {
        if (self.count >= self.piglins.len) return false;
        self.piglins[self.count] = piglin;
        self.count += 1;
        return true;
    }

    pub fn spawnPiglin(self: *ZombifiedPiglinSwarm, pos: Vec3) ?*ZombifiedPiglin {
        if (self.count >= self.piglins.len) return null;
        const id = self.next_id;
        self.next_id += 1;
        self.piglins[self.count] = ZombifiedPiglin.init(id, pos);
        const ptr = &self.piglins[self.count];
        self.count += 1;
        return ptr;
    }

    pub fn onPiglinProvoked(
        self: *ZombifiedPiglinSwarm,
        provoked_index: usize,
        player_id: u32,
    ) SwarmAlarmResult {
        if (provoked_index >= self.count) return .{
            .sound_effect = .zombified_piglin_screech,
            .provoker_player_id = player_id,
            .origin_pos = Vec3.zero,
        };
        return broadcastSwarmAlarm(&self.piglins[provoked_index], player_id, self.piglins[0..self.count]);
    }

    pub fn tickAll(
        self: *ZombifiedPiglinSwarm,
        delta_ticks: u32,
        player_pos: ?Vec3,
        has_line_of_sight: bool,
    ) void {
        for (self.piglins[0..self.count]) |*piglin| {
            if (piglin.is_alive) {
                piglin.tick(delta_ticks, player_pos, has_line_of_sight);
            }
        }
    }

    pub fn countAngeredAt(self: ZombifiedPiglinSwarm, player_id: u32) usize {
        var count: usize = 0;
        for (self.piglins[0..self.count]) |piglin| {
            if (piglin.is_alive and piglin.state == .angered and piglin.target_player_id == player_id) {
                count += 1;
            }
        }
        return count;
    }

    pub fn countNeutral(self: ZombifiedPiglinSwarm) usize {
        var count: usize = 0;
        for (self.piglins[0..self.count]) |piglin| {
            if (piglin.is_alive and piglin.state == .neutral) {
                count += 1;
            }
        }
        return count;
    }
};

// ============================================================================
// Unit Tests (44 Tests)
// ============================================================================

test "01: Zombified Piglin max health is 20.0 HP (10 hearts)" {
    const piglin = ZombifiedPiglin.init(1, Vec3.zero);
    try std.testing.expectEqual(@as(f32, 20.0), piglin.health);
    try std.testing.expectEqual(@as(f32, 20.0), piglin.max_health);
    try std.testing.expectEqual(@as(f32, 20.0), MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 10.0), HEARTS);
    try std.testing.expectEqual(@as(f32, 20.0), ZOMBIFIED_PIGLIN_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 10.0), ZOMBIFIED_PIGLIN_HEARTS);
}

test "02: Natural neutrality: Zombified Piglin initializes in .neutral state" {
    const piglin = ZombifiedPiglin.init(1, Vec3.zero);
    try std.testing.expectEqual(ZombifiedPiglinState.neutral, piglin.state);
    try std.testing.expect(piglin.isNeutral());
    try std.testing.expect(!piglin.isAngered());
    try std.testing.expect(!piglin.isCalming());
}

test "03: Natural neutrality: ignores nearby player without taking damage" {
    var piglin = ZombifiedPiglin.init(1, Vec3.init(10.0, 64.0, 10.0));
    const player_pos = Vec3.init(11.0, 64.0, 10.0); // 1 block away!

    // Tick for 100 ticks with player nearby in line of sight
    piglin.tick(100, player_pos, true);

    try std.testing.expect(piglin.isNeutral());
    try std.testing.expect(piglin.target_player_id == null);
    try std.testing.expectEqual(@as(u32, 0), piglin.anger_ticks);
}

test "04: Natural neutrality: base movement speed is 3.0 m/s neutral walk" {
    const piglin = ZombifiedPiglin.init(1, Vec3.zero);
    try std.testing.expectEqual(@as(f32, 3.0), NEUTRAL_WALK_SPEED);
    try std.testing.expectEqual(@as(f32, 3.0), piglin.movement_speed);
    try std.testing.expectEqual(@as(f32, 3.0), piglin.getMovementSpeed());
}

test "05: Attack trigger: angerAt(player_id) transitions state from .neutral to .angered" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    try std.testing.expect(piglin.isNeutral());

    piglin.angerAt(42);
    try std.testing.expectEqual(ZombifiedPiglinState.angered, piglin.state);
    try std.testing.expect(piglin.isAngered());
    try std.testing.expect(!piglin.isNeutral());
}

test "06: Attack trigger: sets target_player_id to player_id" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAt(77);
    try std.testing.expect(piglin.target_player_id != null);
    try std.testing.expectEqual(@as(u32, 77), piglin.target_player_id.?);
}

test "07: Attack trigger: movement speed increases by 45% (sprinting at 4.35 m/s)" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    try std.testing.expectEqual(@as(f32, 3.0), piglin.getMovementSpeed());

    piglin.angerAt(99);
    try std.testing.expectApproxEqAbs(@as(f32, 4.35), piglin.movement_speed, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.35), piglin.getMovementSpeed(), 0.001);
    try std.testing.expectEqual(@as(f32, 0.45), SPRINT_SPEED_BOOST);
    try std.testing.expectEqual(@as(f32, 4.35), ANGERED_SPRINT_SPEED);
}

test "08: Attack trigger: emits piercing SoundEffect.zombified_piglin_screech audio cue" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAt(101);
    try std.testing.expectEqual(SoundEffect.zombified_piglin_screech, piglin.last_sound.?);
}

test "09: Anger duration: MIN_ANGER_TICKS is 400 (20.0s) and MAX_ANGER_TICKS is 799 (39.95s)" {
    try std.testing.expectEqual(@as(u32, 400), MIN_ANGER_TICKS);
    try std.testing.expectEqual(@as(u32, 799), MAX_ANGER_TICKS);
    try std.testing.expectEqual(@as(f32, 20.0), MIN_ANGER_SECONDS);
    try std.testing.expectEqual(@as(f32, 39.95), MAX_ANGER_SECONDS);

    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAt(1);
    try std.testing.expect(piglin.anger_ticks >= MIN_ANGER_TICKS);
    try std.testing.expect(piglin.anger_ticks <= MAX_ANGER_TICKS);
}

test "10: Anger duration: sampleAngerTicks maps uniform roll [0, 1] into [400, 799] inclusive" {
    try std.testing.expectEqual(@as(u32, 400), sampleAngerTicks(0.0));
    try std.testing.expectEqual(@as(u32, 600), sampleAngerTicks(0.5));
    try std.testing.expectEqual(@as(u32, 799), sampleAngerTicks(1.0));
    try std.testing.expectEqual(@as(u32, 799), sampleAngerTicks(0.9999));
}

test "11: Swarm alarm radius constant is exactly 40.0 meters Euclidean (SWARM_ALARM_RADIUS = 40.0)" {
    try std.testing.expectEqual(@as(f32, 40.0), SWARM_ALARM_RADIUS);
    try std.testing.expectEqual(@as(f32, 40.0), swarm_alarm_radius);
    try std.testing.expectEqual(@as(f32, 1600.0), SWARM_ALARM_RADIUS_SQ);
}

test "12: Swarm alarm propagation: alerts all nearby Zombified Piglins within 40.0m radius" {
    var provoked = ZombifiedPiglin.init(1, Vec3.zero);
    var pack = [_]ZombifiedPiglin{
        ZombifiedPiglin.init(2, Vec3.init(10.0, 0.0, 0.0)),
        ZombifiedPiglin.init(3, Vec3.init(0.0, 25.0, 0.0)),
        ZombifiedPiglin.init(4, Vec3.init(0.0, 0.0, 39.0)),
    };

    const broadcast = broadcastSwarmAlarm(&provoked, 50, &pack);

    try std.testing.expectEqual(SoundEffect.zombified_piglin_screech, broadcast.sound_effect);
    try std.testing.expectEqual(@as(usize, 3), broadcast.alerted_count);
    try std.testing.expectEqual(@as(usize, 0), broadcast.out_of_range_count);

    for (pack) |piglin| {
        try std.testing.expect(piglin.isAngered());
        try std.testing.expectEqual(@as(u32, 50), piglin.target_player_id.?);
    }
}

test "13: Swarm alarm boundary: piglin at exactly 40.0m Euclidean distance is alerted" {
    var provoked = ZombifiedPiglin.init(1, Vec3.zero);
    var pack = [_]ZombifiedPiglin{
        ZombifiedPiglin.init(2, Vec3.init(40.0, 0.0, 0.0)),
    };

    const broadcast = broadcastSwarmAlarm(&provoked, 55, &pack);
    try std.testing.expectEqual(@as(usize, 1), broadcast.alerted_count);
    try std.testing.expectEqual(@as(usize, 0), broadcast.out_of_range_count);
    try std.testing.expect(pack[0].isAngered());
}

test "14: Swarm alarm boundary: piglin at 40.01m Euclidean distance is out of range and remains neutral" {
    var provoked = ZombifiedPiglin.init(1, Vec3.zero);
    var pack = [_]ZombifiedPiglin{
        ZombifiedPiglin.init(2, Vec3.init(40.01, 0.0, 0.0)),
    };

    const broadcast = broadcastSwarmAlarm(&provoked, 55, &pack);
    try std.testing.expectEqual(@as(usize, 0), broadcast.alerted_count);
    try std.testing.expectEqual(@as(usize, 1), broadcast.out_of_range_count);
    try std.testing.expect(pack[0].isNeutral());
    try std.testing.expect(pack[0].target_player_id == null);
}

test "15: Swarm alarm out-of-range: piglins at 50m and 100m remain neutral" {
    var provoked = ZombifiedPiglin.init(1, Vec3.zero);
    var pack = [_]ZombifiedPiglin{
        ZombifiedPiglin.init(2, Vec3.init(50.0, 0.0, 0.0)),
        ZombifiedPiglin.init(3, Vec3.init(0.0, 100.0, 0.0)),
    };

    const broadcast = broadcastSwarmAlarm(&provoked, 60, &pack);
    try std.testing.expectEqual(@as(usize, 0), broadcast.alerted_count);
    try std.testing.expectEqual(@as(usize, 2), broadcast.out_of_range_count);
    try std.testing.expect(pack[0].isNeutral());
    try std.testing.expect(pack[1].isNeutral());
}

test "16: Swarm alarm line-of-sight: alerts piglins through walls and caves (no LOS required)" {
    var provoked = ZombifiedPiglin.init(1, Vec3.init(100.0, 50.0, 100.0));
    var pack = [_]ZombifiedPiglin{
        // Behind thick obsidian wall / netherrack cavern at 20m Euclidean
        ZombifiedPiglin.init(2, Vec3.init(112.0, 50.0, 116.0)), // distance = sqrt(144 + 256) = 20.0m
    };

    const broadcast = broadcastSwarmAlarm(&provoked, 70, &pack);
    try std.testing.expectEqual(@as(usize, 1), broadcast.alerted_count);
    try std.testing.expect(pack[0].isAngered());
    try std.testing.expectEqual(@as(u32, 70), pack[0].target_player_id.?);
}

test "17: Swarm alarm 3D Euclidean propagation: Y-axis vertical elevation within 40m is alerted" {
    var provoked = ZombifiedPiglin.init(1, Vec3.init(0.0, 30.0, 0.0));
    var pack = [_]ZombifiedPiglin{
        // 30m straight up in Y: distance is 30.0m <= 40.0m
        ZombifiedPiglin.init(2, Vec3.init(0.0, 60.0, 0.0)),
        // 30m X and 30m Y: distance = sqrt(900 + 900) = 42.42m > 40.0m
        ZombifiedPiglin.init(3, Vec3.init(30.0, 60.0, 0.0)),
    };

    const broadcast = broadcastSwarmAlarm(&provoked, 80, &pack);
    try std.testing.expectEqual(@as(usize, 1), broadcast.alerted_count);
    try std.testing.expectEqual(@as(usize, 1), broadcast.out_of_range_count);
    try std.testing.expect(pack[0].isAngered());
    try std.testing.expect(pack[1].isNeutral());
}

test "18: Swarm alarm multi-pack coordination: all alerted piglins sprint at 4.35 m/s and target provoker" {
    var provoked = ZombifiedPiglin.init(1, Vec3.zero);
    var pack = [_]ZombifiedPiglin{
        ZombifiedPiglin.init(2, Vec3.init(5.0, 0.0, 5.0)),
        ZombifiedPiglin.init(3, Vec3.init(15.0, 0.0, 15.0)),
        ZombifiedPiglin.init(4, Vec3.init(25.0, 0.0, 20.0)),
    };

    _ = broadcastSwarmAlarm(&provoked, 999, &pack);

    for (pack) |piglin| {
        try std.testing.expect(piglin.isAngered());
        try std.testing.expectEqual(@as(u32, 999), piglin.target_player_id.?);
        try std.testing.expectApproxEqAbs(@as(f32, 4.35), piglin.movement_speed, 0.001);
    }
}

test "19: Swarm alarm audio: returns SoundEffect.zombified_piglin_screech" {
    var provoked = ZombifiedPiglin.init(1, Vec3.zero);
    var pack = [_]ZombifiedPiglin{
        ZombifiedPiglin.init(2, Vec3.init(10.0, 0.0, 0.0)),
    };

    const broadcast = broadcastSwarmAlarm(&provoked, 42, &pack);
    try std.testing.expectEqual(SoundEffect.zombified_piglin_screech, broadcast.sound_effect);
    try std.testing.expectEqual(SoundEffect.zombified_piglin_screech, provoked.last_sound.?);
    try std.testing.expectEqual(SoundEffect.zombified_piglin_angry, pack[0].last_sound.?);
}

test "20: Swarm alarm already-angry piglins: increments already_angry_count and maintains pursuit" {
    var provoked = ZombifiedPiglin.init(1, Vec3.zero);
    var pack = [_]ZombifiedPiglin{
        ZombifiedPiglin.init(2, Vec3.init(10.0, 0.0, 0.0)),
    };
    pack[0].angerAt(88); // already angry at player 88

    const broadcast = broadcastSwarmAlarm(&provoked, 88, &pack);
    try std.testing.expectEqual(@as(usize, 0), broadcast.alerted_count);
    try std.testing.expectEqual(@as(usize, 1), broadcast.already_angry_count);
    try std.testing.expect(pack[0].isAngered());
}

test "21: Anger countdown: ticking decreases anger timer when player is not in LOS / out of range" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAtWithTicks(42, 600);
    try std.testing.expectEqual(@as(u32, 600), piglin.anger_ticks);

    // Tick for 200 ticks without player in LOS
    piglin.tick(200, null, false);
    try std.testing.expectEqual(@as(u32, 400), piglin.anger_ticks);
    try std.testing.expect(piglin.isAngered());
}

test "22: Calming cycle: anger timer reaching 0 transitions to .calming state" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAtWithTicks(42, 100);

    // Tick for 100 ticks (exhausts anger timer)
    piglin.tick(100, null, false);

    try std.testing.expectEqual(ZombifiedPiglinState.calming, piglin.state);
    try std.testing.expect(piglin.isCalming());
    try std.testing.expectEqual(@as(u32, 0), piglin.anger_ticks);
    try std.testing.expectEqual(CALMING_DURATION_TICKS, piglin.calming_ticks);
}

test "23: Calming cycle: completing calming phase transitions to .neutral (anger forgiven)" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAtWithTicks(42, 50);

    // Reach calming
    piglin.tick(50, null, false);
    try std.testing.expect(piglin.isCalming());

    // Advance through the 20 calming ticks
    piglin.tick(CALMING_DURATION_TICKS, null, false);

    try std.testing.expectEqual(ZombifiedPiglinState.neutral, piglin.state);
    try std.testing.expect(piglin.isNeutral());
}

test "24: Calming cycle: forgiven piglin clears target_player_id to null and restores speed to 3.0 m/s" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAtWithTicks(42, 10);
    piglin.tick(10 + CALMING_DURATION_TICKS, null, false);

    try std.testing.expect(piglin.isNeutral());
    try std.testing.expect(piglin.target_player_id == null);
    try std.testing.expectEqual(@as(f32, 3.0), piglin.movement_speed);
    try std.testing.expectEqual(@as(f32, 3.0), piglin.getMovementSpeed());
}

test "25: Continuous pursuit: player within 16m and in LOS resets anger timer (re-aggro)" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAtWithTicks(42, 450);

    // Let anger timer run down to 50 ticks
    piglin.tick(400, null, false);
    try std.testing.expectEqual(@as(u32, 50), piglin.anger_ticks);

    // Now player appears at 10m with line-of-sight: re-aggro!
    const player_pos = Vec3.init(10.0, 0.0, 0.0);
    piglin.tick(1, player_pos, true);

    try std.testing.expect(piglin.isAngered());
    // Timer was reset back into [400, 799] range
    try std.testing.expect(piglin.anger_ticks >= MIN_ANGER_TICKS);
    try std.testing.expect(piglin.anger_ticks <= MAX_ANGER_TICKS);
}

test "26: Continuous pursuit boundary: player at exactly 16.0m with LOS resets anger timer" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAtWithTicks(42, 100);

    const player_pos = Vec3.init(16.0, 0.0, 0.0);
    const reaggro = piglin.checkReAggro(player_pos, true);

    try std.testing.expect(reaggro);
    try std.testing.expect(piglin.anger_ticks >= MIN_ANGER_TICKS);
}

test "27: Continuous pursuit boundary: player at 16.01m with LOS does NOT reset timer" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAtWithTicks(42, 100);

    const player_pos = Vec3.init(16.01, 0.0, 0.0);
    const reaggro = piglin.checkReAggro(player_pos, true);

    try std.testing.expect(!reaggro);
    try std.testing.expectEqual(@as(u32, 100), piglin.anger_ticks);
}

test "28: Continuous pursuit obstruction: player within 16m without LOS (blocked by wall) does NOT reset timer" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAtWithTicks(42, 100);

    const player_pos = Vec3.init(5.0, 0.0, 0.0);
    const reaggro = piglin.checkReAggro(player_pos, false); // blocked by wall!

    try std.testing.expect(!reaggro);
    try std.testing.expectEqual(@as(u32, 100), piglin.anger_ticks);
}

test "29: Continuous pursuit indefinite: maintaining LOS within 16m keeps piglin angered across multiple cycles" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    piglin.angerAtWithTicks(42, 500);

    const player_pos = Vec3.init(8.0, 0.0, 0.0);

    // Tick for 2000 ticks (100 seconds) with continuous LOS
    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        piglin.tick(100, player_pos, true);
        try std.testing.expect(piglin.isAngered());
        try std.testing.expect(piglin.anger_ticks >= MIN_ANGER_TICKS);
    }
}

test "30: Fire immunity: taking fire damage deals 0 HP, isImmuneToFire = true" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    try std.testing.expect(piglin.isImmuneToFire);
    try std.testing.expect(piglin.is_immune_to_fire);
    try std.testing.expect(isImmuneToFire);

    const res = piglin.takeDamage(10.0, .fire, null, null, null);
    try std.testing.expect(res.was_immune);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 20.0), piglin.health);
}

test "31: Lava immunity: taking lava damage deals 0 HP, isImmuneToLava = true" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    try std.testing.expect(piglin.isImmuneToLava);
    try std.testing.expect(piglin.is_immune_to_lava);
    try std.testing.expect(isImmuneToLava);

    const res = piglin.takeDamage(15.0, .lava, null, null, null);
    try std.testing.expect(res.was_immune);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 20.0), piglin.health);
}

test "32: Burning immunity: taking burning status damage deals 0 HP" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    const res = piglin.takeDamage(4.0, .burning, null, null, null);
    try std.testing.expect(res.was_immune);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 20.0), piglin.health);
}

test "33: Environmental fire immunity: fire and lava damage do not provoke anger towards players" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    _ = piglin.takeDamage(8.0, .fire, null, null, null);
    try std.testing.expect(piglin.isNeutral());
    try std.testing.expect(piglin.target_player_id == null);

    _ = piglin.takeDamage(12.0, .lava, null, null, null);
    try std.testing.expect(piglin.isNeutral());
    try std.testing.expect(piglin.target_player_id == null);
}

test "34: Reinforcement calling: taking damage has a 10% chance to summon another piglin" {
    try std.testing.expectEqual(@as(f32, 0.10), REINFORCEMENT_CHANCE);
    try std.testing.expectEqual(@as(f32, 16.0), REINFORCEMENT_RADIUS);
}

test "35: Reinforcement summoning: roll < 0.10 summons reinforcement within 16 blocks" {
    var piglin = ZombifiedPiglin.init(1, Vec3.init(100.0, 64.0, 100.0));

    // Roll 0.05 is < 0.10 -> summons reinforcement
    const res = piglin.takeDamage(4.0, .player_attack, 42, 0.05, 555);

    try std.testing.expect(res.reinforcement.summoned);
    try std.testing.expect(res.reinforcement.reinforcement != null);

    const reinf = res.reinforcement.reinforcement.?;
    try std.testing.expectEqual(@as(u32, 555), reinf.id);

    // Distance must be <= 16.0 blocks
    const dist = piglin.pos.dist(reinf.pos);
    try std.testing.expect(dist <= 16.0);
    try std.testing.expect(dist > 0.0);
}

test "36: Reinforcement summoning: roll >= 0.10 does not summon reinforcement" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);

    // Roll 0.15 is >= 0.10 -> no reinforcement
    const res = piglin.takeDamage(4.0, .player_attack, 42, 0.15, 777);

    try std.testing.expect(!res.reinforcement.summoned);
    try std.testing.expect(res.reinforcement.reinforcement == null);
}

test "37: Reinforcement attributes: summoned piglin has 20.0 max health, golden sword, fire immunity, and angers at player" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);
    const res = piglin.takeDamage(5.0, .player_attack, 99, 0.01, 888);

    const reinf = res.reinforcement.reinforcement.?;
    try std.testing.expectEqual(@as(f32, 20.0), reinf.health);
    try std.testing.expectEqual(@as(f32, 20.0), reinf.max_health);
    try std.testing.expectEqual(ItemType.golden_sword, reinf.weapon);
    try std.testing.expect(reinf.isImmuneToFire);
    try std.testing.expect(reinf.isImmuneToLava);
    try std.testing.expect(reinf.is_undead);

    // Inherits anger targeting the attacking player
    try std.testing.expect(reinf.isAngered());
    try std.testing.expectEqual(@as(u32, 99), reinf.target_player_id.?);
}

test "38: Drops on defeat: drops 5 Experience Points (EXPERIENCE_POINTS_DROP = 5)" {
    const drops = calculateDefeatDrops(0, 0.2, 0.2, 0.2);
    try std.testing.expectEqual(@as(u32, 5), drops.experience_points);
    try std.testing.expectEqual(@as(u32, 5), EXPERIENCE_POINTS_DROP);
}

test "39: Drops on defeat: Rotten Flesh drops 0–1 base and scales with Looting" {
    // Roll < 0.5 yields 0
    const drops_zero = calculateDefeatDrops(0, 0.4, 0.0, 0.5);
    try std.testing.expectEqual(@as(u32, 0), drops_zero.rotten_flesh_count);

    // Roll >= 0.5 yields 1 at Looting 0
    const drops_one = calculateDefeatDrops(0, 0.6, 0.0, 0.5);
    try std.testing.expectEqual(@as(u32, 1), drops_one.rotten_flesh_count);

    // Looting III scales up to 4 flesh
    const drops_looting3 = calculateDefeatDrops(3, 0.99, 0.0, 0.5);
    try std.testing.expect(drops_looting3.rotten_flesh_count >= 1);
    try std.testing.expect(drops_looting3.rotten_flesh_count <= 4);
}

test "40: Drops on defeat: Gold Nuggets drop 0–1 base and scale with Looting" {
    // Roll < 0.5 yields 0
    const drops_zero = calculateDefeatDrops(0, 0.0, 0.3, 0.5);
    try std.testing.expectEqual(@as(u32, 0), drops_zero.gold_nugget_count);

    // Roll >= 0.5 yields 1 at Looting 0
    const drops_one = calculateDefeatDrops(0, 0.0, 0.7, 0.5);
    try std.testing.expectEqual(@as(u32, 1), drops_one.gold_nugget_count);

    // Looting III scales up to 4 nuggets
    const drops_looting3 = calculateDefeatDrops(3, 0.0, 0.99, 0.5);
    try std.testing.expect(drops_looting3.gold_nugget_count >= 1);
    try std.testing.expect(drops_looting3.gold_nugget_count <= 4);
}

test "41: Drops on defeat: Golden Sword has 8.5% base drop chance" {
    try std.testing.expectEqual(@as(f32, 0.085), GOLDEN_SWORD_BASE_DROP_CHANCE);

    // Roll 0.08 is < 0.085 -> drops golden sword
    const drop_success = calculateDefeatDrops(0, 0.0, 0.0, 0.08);
    try std.testing.expect(drop_success.dropped_golden_sword);
    try std.testing.expectApproxEqAbs(@as(f32, 0.085), drop_success.golden_sword_drop_chance, 0.0001);

    // Roll 0.086 is >= 0.085 -> does not drop golden sword
    const drop_fail = calculateDefeatDrops(0, 0.0, 0.0, 0.086);
    try std.testing.expect(!drop_fail.dropped_golden_sword);
}

test "42: Drops on defeat: Looting enchantment increases Golden Sword drop chance by +1.0% per level" {
    try std.testing.expectEqual(@as(f32, 0.01), LOOTING_SWORD_BONUS_PER_LEVEL);

    // Looting I: 8.5% + 1.0% = 9.5%
    const l1 = calculateDefeatDrops(1, 0.0, 0.0, 0.09);
    try std.testing.expectApproxEqAbs(@as(f32, 0.095), l1.golden_sword_drop_chance, 0.0001);
    try std.testing.expect(l1.dropped_golden_sword);

    // Looting III: 8.5% + 3.0% = 11.5%
    const l3 = calculateDefeatDrops(3, 0.0, 0.0, 0.11);
    try std.testing.expectApproxEqAbs(@as(f32, 0.115), l3.golden_sword_drop_chance, 0.0001);
    try std.testing.expect(l3.dropped_golden_sword);

    // Roll 0.12 exceeds 11.5%
    const l3_fail = calculateDefeatDrops(3, 0.0, 0.0, 0.12);
    try std.testing.expect(!l3_fail.dropped_golden_sword);
}

test "43: Combat damage: taking damage reduces health, emits hurt sound, and kills at 0 HP with death sound" {
    var piglin = ZombifiedPiglin.init(1, Vec3.zero);

    // Take 8.0 damage
    const res1 = piglin.takeDamage(8.0, .player_attack, 10, 0.5, null);
    try std.testing.expectEqual(@as(f32, 12.0), piglin.health);
    try std.testing.expect(!res1.was_fatal);
    try std.testing.expectEqual(SoundEffect.zombified_piglin_screech, piglin.last_sound.?);

    // Take 15.0 damage (fatal, exceeding remaining 12.0 health)
    const res2 = piglin.takeDamage(15.0, .generic, null, 0.5, null);
    try std.testing.expectEqual(@as(f32, 0.0), piglin.health);
    try std.testing.expect(res2.was_fatal);
    try std.testing.expect(piglin.isDead());
    try std.testing.expectEqual(SoundEffect.zombified_piglin_death, piglin.last_sound.?);
}

test "44: Swarm coordinator: multi-piglin Nether bastion/wastes encounter simulation" {
    var swarm = ZombifiedPiglinSwarm.init();

    // Spawn 6 piglins within 40m, and 2 piglins far away (> 40m)
    _ = swarm.spawnPiglin(Vec3.init(0.0, 64.0, 0.0));
    _ = swarm.spawnPiglin(Vec3.init(5.0, 64.0, 10.0));
    _ = swarm.spawnPiglin(Vec3.init(-15.0, 64.0, 8.0));
    _ = swarm.spawnPiglin(Vec3.init(20.0, 64.0, -10.0));
    _ = swarm.spawnPiglin(Vec3.init(0.0, 80.0, 0.0)); // 16m vertical
    _ = swarm.spawnPiglin(Vec3.init(25.0, 64.0, 25.0)); // sqrt(625 + 625) = 35.35m <= 40m

    // Far away piglins
    _ = swarm.spawnPiglin(Vec3.init(60.0, 64.0, 0.0)); // 60m away
    _ = swarm.spawnPiglin(Vec3.init(0.0, 64.0, 100.0)); // 100m away

    try std.testing.expectEqual(@as(usize, 8), swarm.count);
    try std.testing.expectEqual(@as(usize, 8), swarm.countNeutral());
    try std.testing.expectEqual(@as(usize, 0), swarm.countAngeredAt(1234));

    // Player strikes piglin 0!
    const alarm = swarm.onPiglinProvoked(0, 1234);

    try std.testing.expectEqual(SoundEffect.zombified_piglin_screech, alarm.sound_effect);
    try std.testing.expectEqual(@as(usize, 5), alarm.alerted_count); // 5 other piglins within 40m
    try std.testing.expectEqual(@as(usize, 2), alarm.out_of_range_count); // 2 piglins > 40m

    // Total angered at player is 1 (provoked) + 5 (alerted) = 6
    try std.testing.expectEqual(@as(usize, 6), swarm.countAngeredAt(1234));
    try std.testing.expectEqual(@as(usize, 2), swarm.countNeutral());
}
