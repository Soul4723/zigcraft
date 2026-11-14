const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Distance in blocks within which threats (sprinting player, undead mob, recent damage)
/// cause an armadillo to roll up into its protective ball (7 blocks).
pub const threat_detection_radius: f32 = 7.0;
pub const threat_radius: f32 = threat_detection_radius;
pub const threat_detection_radius_sq: f32 = 49.0;

/// Distance in blocks within which spiders and cave spiders flee from unrolled armadillos (6 blocks).
pub const spider_flee_radius: f32 = 6.0;
pub const spider_flee_radius_sq: f32 = 36.0;

/// Ticks without a threat before a curled armadillo starts unrolling (200 ticks = 10s).
pub const unthreatened_ticks_to_unroll: u16 = 200;
/// Ticks between natural armadillo scute drops (24,000 ticks = 20 minutes).
pub const natural_scute_interval_ticks: u32 = 24_000;

/// Brush durability consumed when harvesting an armadillo scute.
pub const brush_durability_cost: u16 = 16;
/// Number of armadillo scutes yielded per brush action.
pub const scutes_per_brush: u8 = 1;

/// Maximum durability points for Wolf Armor.
pub const wolf_armor_max_durability: u16 = 64;
pub const wolf_armor_durability: u16 = wolf_armor_max_durability;
/// Number of armadillo scutes required to craft Wolf Armor.
pub const wolf_armor_craft_scutes: u8 = 6;
/// Durability restored per armadillo scute when repairing Wolf Armor in place.
pub const scute_repair_amount: u16 = 8;

/// Durability thresholds for Wolf Armor crack stages.
pub const crack_threshold_low: u16 = 60;
pub const crack_threshold_medium: u16 = 44;
pub const crack_threshold_high: u16 = 20;

/// Animation / state transition timings in seconds.
pub const rolling_up_duration: f32 = 0.75;
pub const rolled_up_duration: f32 = 3.0;
pub const peeking_duration: f32 = 2.0;
pub const unrolling_duration: f32 = 0.75;
pub const threat_cooldown_duration: f32 = 3.0;

/// Breeding timers in seconds.
pub const armadillo_breed_cooldown: f32 = 300.0; // 5 minutes
pub const armadillo_baby_growth_target: f32 = 1200.0; // 20 minutes
pub const armadillo_baby_growth_feed_bonus: f32 = 120.0; // 10% acceleration
pub const armadillo_love_duration: f32 = 30.0;

// ============================================================================
// Enums
// ============================================================================

/// Behavioral state of an Armadillo (continuous-time state machine).
pub const ArmadilloState = enum {
    unrolled,
    rolling_up,
    rolled_up,
    peeking,
    unrolling,
};

/// Tick-discrete defensive posture state of an Armadillo.
pub const DefenseArmadilloState = enum {
    standing,
    rolling_up,
    curled_ball,
    unrolling,
};

/// Type of threat capable of startling an Armadillo.
pub const ThreatType = enum {
    none,
    sprinting_player,
    undead_mob,
    recent_damage,
};

/// Detailed entity/event threat classification for tick-based evaluation.
pub const ThreatKind = enum {
    sprinting_player,
    zombie,
    husk,
    drowned,
    skeleton,
    spider,
    cave_spider,
    environmental_damage,
    other,
};

/// Crack stages for Wolf Armor visual degradation.
pub const CrackStage = enum {
    none,
    low_cracks,
    medium_cracks,
    high_cracks,
};

/// Five-stage crack progression including pristine and broken states.
pub const DefenseCrackStage = enum {
    pristine,
    slightly_cracked,
    moderately_cracked,
    heavily_cracked,
    broken,
};

/// Standard 16 Minecraft dye colors supported for dying Wolf Armor.
pub const DyeColor = enum(u8) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,

    pub fn rgb(self: DyeColor) u32 {
        return switch (self) {
            .white => 0xF9FFFE,
            .orange => 0xF9801D,
            .magenta => 0xC74EBD,
            .light_blue => 0x3AB3DA,
            .yellow => 0xFED83D,
            .lime => 0x80C71F,
            .pink => 0xF38BAA,
            .gray => 0x474F52,
            .light_gray => 0x9D9D97,
            .cyan => 0x169C9C,
            .purple => 0x8932B8,
            .blue => 0x3C44AA,
            .brown => 0x835432,
            .green => 0x5E7C16,
            .red => 0xB02E26,
            .black => 0x1D1D21,
        };
    }
};

/// Outcome when attempting to feed an Armadillo with Spider Eyes.
pub const FeedResult = enum {
    entered_love_mode,
    baby_growth_accelerated,
    refused_on_cooldown,
    refused_rolled_up,
    refused_wrong_item,
};

/// Classification of damage sources for wolf armor penetration.
pub const DamageKind = enum {
    melee,
    projectile,
    explosion,
    fall,
    fire,
    environmental, // drowning, freezing, suffocation, magic/wither, void
};

/// Damage classes for curled armadillo mitigation.
pub const DefenseDamageKind = enum { weak, blast, melee, other };

/// Acoustic cues emitted by armadillo shell roll-up and wolf armor shatter.
pub const Sound = enum { shell_clack, armor_shatter };

/// Interaction item categories for tick-based wolf and armadillo interactions.
pub const InteractionItem = enum { brush, armadillo_scute, wolf_armor, shears, other };

// ============================================================================
// Core Functions: Armadillo Defense & Brushing
// ============================================================================

/// Computes 3D Euclidean distance between two coordinates.
pub fn distance3d(ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32) f32 {
    const dx = ax - bx;
    const dy = ay - by;
    const dz = az - bz;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

/// Calculates whether a squared distance is within the 7-block threat detection radius.
pub fn isThreatWithinRadius(distance_sq: f32) bool {
    return distance_sq <= threat_detection_radius_sq;
}

/// Calculates whether a linear Euclidean distance is within the 7-block threat radius.
pub fn isThreatDistanceWithinRadius(distance: f32) bool {
    return distance >= 0 and distance <= threat_radius;
}

/// Threat descriptor with distance for tick-based armadillo detection.
pub const Threat = struct {
    kind: ThreatKind,
    distance: f32 = 0,

    pub fn isRelevant(self: Threat) bool {
        if (self.kind == .environmental_damage) return true;
        return self.distance >= 0 and self.distance <= threat_radius and self.kind != .other;
    }
};

/// Evaluates whether a nearby entity or event constitutes an armadillo threat within 7 blocks.
pub fn shouldTriggerRollUp(distance_sq: f32, is_sprinting_player: bool, is_undead_mob: bool, has_recent_damage: bool) bool {
    if (!is_sprinting_player and !is_undead_mob and !has_recent_damage) return false;
    return distance_sq <= threat_detection_radius_sq;
}

/// Incoming damage reduction formula when an armadillo is rolled up:
/// `(raw_damage - 1.0) / 2.0`, fully resisting weak attacks (<= 1.0 raw damage).
pub fn rolledDamageReduction(raw_damage: f32) f32 {
    if (raw_damage <= 1.0) return 0.0;
    return (raw_damage - 1.0) / 2.0;
}

/// Brushing an armadillo drops 1 Armadillo Scute and consumes 16 durability from the brush.
/// If the brush has 0 durability, no scutes drop and no brush damage is applied.
pub const BrushResult = struct {
    scutes_dropped: u8,
    brush_damage: u16,
};

/// Result of brushing an armadillo with explicit tool classification.
pub const DefenseBrushResult = struct {
    scutes_dropped: u8 = 0,
    brush_durability_used: u16 = 0,
};

pub fn brushArmadillo(brush_durability_remaining: u16) BrushResult {
    if (brush_durability_remaining == 0) {
        return .{ .scutes_dropped = 0, .brush_damage = 0 };
    }
    const damage = @min(brush_durability_remaining, brush_durability_cost);
    return .{
        .scutes_dropped = scutes_per_brush,
        .brush_damage = damage,
    };
}

/// Whether spiders/cave spiders should flee from an armadillo.
/// Spiders only flee from unrolled armadillos within 6 blocks.
pub fn shouldSpiderFlee(armadillo_state: ArmadilloState, distance_sq: f32) bool {
    if (armadillo_state != .unrolled) return false;
    return distance_sq <= spider_flee_radius_sq;
}

// ============================================================================
// Armadillo Entity
// ============================================================================

pub const Armadillo = struct {
    state: ArmadilloState = .unrolled,
    state_timer: f32 = 0.0,
    threat_cooldown: f32 = 0.0,
    ticks_since_scute_drop: u32 = 0,
    is_baby: bool = false,
    baby_age: f32 = 0.0,
    breed_cooldown: f32 = 0.0,
    is_in_love: bool = false,
    love_timer: f32 = 0.0,

    pub fn init() Armadillo {
        return .{};
    }

    pub fn initBaby() Armadillo {
        return .{
            .is_baby = true,
            .baby_age = 0.0,
        };
    }

    /// Triggers startle roll-up response when threatened.
    pub fn triggerThreat(self: *Armadillo) void {
        self.threat_cooldown = threat_cooldown_duration;
        switch (self.state) {
            .unrolled => {
                self.state = .rolling_up;
                self.state_timer = 0.0;
            },
            .peeking, .unrolling => {
                self.state = .rolled_up;
                self.state_timer = 0.0;
            },
            .rolling_up, .rolled_up => {},
        }
    }

    /// Advances armadillo defense state machine and timers.
    pub fn tick(self: *Armadillo, dt: f32, threat_nearby: bool) void {
        if (threat_nearby) {
            self.triggerThreat();
        } else if (self.threat_cooldown > 0.0) {
            self.threat_cooldown = @max(0.0, self.threat_cooldown - dt);
        }

        self.state_timer += dt;
        switch (self.state) {
            .unrolled => {},
            .rolling_up => {
                if (self.state_timer >= rolling_up_duration) {
                    self.state = .rolled_up;
                    self.state_timer = 0.0;
                }
            },
            .rolled_up => {
                if (self.threat_cooldown <= 0.0 and self.state_timer >= rolled_up_duration) {
                    self.state = .peeking;
                    self.state_timer = 0.0;
                }
            },
            .peeking => {
                if (self.threat_cooldown <= 0.0 and self.state_timer >= peeking_duration) {
                    self.state = .unrolling;
                    self.state_timer = 0.0;
                }
            },
            .unrolling => {
                if (self.state_timer >= unrolling_duration) {
                    self.state = .unrolled;
                    self.state_timer = 0.0;
                }
            },
        }

        // Breeding timers
        if (self.breed_cooldown > 0.0) {
            self.breed_cooldown = @max(0.0, self.breed_cooldown - dt);
        }
        if (self.is_in_love) {
            self.love_timer = @max(0.0, self.love_timer - dt);
            if (self.love_timer <= 0.0) {
                self.is_in_love = false;
            }
        }
        if (self.is_baby) {
            self.baby_age += dt;
            if (self.baby_age >= armadillo_baby_growth_target) {
                self.is_baby = false;
                self.baby_age = 0.0;
            }
        }
    }

    /// Advances natural scute drop counter by 1 game tick; returns true every 24,000 ticks.
    pub fn tickNaturalScute(self: *Armadillo) bool {
        if (self.is_baby) return false;
        self.ticks_since_scute_drop += 1;
        if (self.ticks_since_scute_drop < natural_scute_interval_ticks) return false;
        self.ticks_since_scute_drop = 0;
        return true;
    }

    /// Handles incoming damage to the armadillo, taking defense roll-up state into account.
    pub fn applyDamage(self: *Armadillo, raw_damage: f32) f32 {
        const was_rolled = (self.state == .rolled_up or self.state == .rolling_up);
        self.triggerThreat();
        if (was_rolled) {
            return rolledDamageReduction(raw_damage);
        }
        return raw_damage;
    }
};

/// Result of a tick-based armadillo defense step.
pub const TickResult = struct { sound: ?Sound = null };

/// Tick-based armadillo defense state machine supporting threat lists, curled mitigation,
/// and natural scute shedding intervals.
pub const DefenseArmadillo = struct {
    state: DefenseArmadilloState = .standing,
    state_ticks: u8 = 0,
    threat_clear_ticks: u16 = 0,
    ticks_since_scute_drop: u32 = 0,

    pub fn tick(self: *DefenseArmadillo, threats: []const Threat) TickResult {
        var threatened = false;
        for (threats) |threat| {
            if (threat.isRelevant()) {
                threatened = true;
                break;
            }
        }

        var began_rolling = false;
        if (threatened) {
            self.threat_clear_ticks = 0;
            if (self.state == .standing or self.state == .unrolling) {
                self.state = .rolling_up;
                self.state_ticks = 0;
                began_rolling = true;
            }
        } else if (self.state == .curled_ball) {
            self.threat_clear_ticks +|= 1;
        }

        self.state_ticks +|= 1;
        switch (self.state) {
            .standing => {},
            .rolling_up => {
                if (began_rolling) return .{};
                if (self.state_ticks >= 1) {
                    self.state = .curled_ball;
                    self.state_ticks = 0;
                    return .{ .sound = .shell_clack };
                }
            },
            .curled_ball => {
                if (self.threat_clear_ticks >= unthreatened_ticks_to_unroll) {
                    self.state = .unrolling;
                    self.state_ticks = 0;
                }
            },
            .unrolling => {
                if (self.state_ticks >= 1) {
                    self.state = .standing;
                    self.state_ticks = 0;
                }
            },
        }
        return .{};
    }

    pub fn applyDamage(self: *DefenseArmadillo, amount: f32, kind: DefenseDamageKind) f32 {
        if (self.state != .curled_ball) return amount;
        return switch (kind) {
            .weak => 0,
            .blast, .melee => amount * 0.15,
            .other => amount,
        };
    }

    pub fn brush(_: DefenseArmadillo, tool: InteractionItem, brush_durability: u16) DefenseBrushResult {
        if (tool != .brush or brush_durability == 0) return .{};
        return .{ .scutes_dropped = 1, .brush_durability_used = @min(brush_durability, brush_durability_cost) };
    }

    pub fn tickNaturalScute(self: *DefenseArmadillo) bool {
        self.ticks_since_scute_drop += 1;
        if (self.ticks_since_scute_drop < natural_scute_interval_ticks) return false;
        self.ticks_since_scute_drop = 0;
        return true;
    }
};

// ============================================================================
// Armadillo Breeding Interaction
// ============================================================================

/// Feeds an Armadillo using Spider Eyes.
pub fn feedSpiderEye(armadillo: *Armadillo, is_spider_eye: bool) FeedResult {
    if (!is_spider_eye) return .refused_wrong_item;
    if (armadillo.state != .unrolled) return .refused_rolled_up;

    if (armadillo.is_baby) {
        armadillo.baby_age += armadillo_baby_growth_feed_bonus;
        if (armadillo.baby_age >= armadillo_baby_growth_target) {
            armadillo.is_baby = false;
            armadillo.baby_age = 0.0;
        }
        return .baby_growth_accelerated;
    }

    if (armadillo.breed_cooldown > 0.0) return .refused_on_cooldown;
    if (armadillo.is_in_love) return .refused_on_cooldown;

    armadillo.is_in_love = true;
    armadillo.love_timer = armadillo_love_duration;
    return .entered_love_mode;
}

/// Breeds two compatible armadillos in love mode.
pub fn tryBreedArmadillos(parent1: *Armadillo, parent2: *Armadillo) ?Armadillo {
    if (!parent1.is_in_love or !parent2.is_in_love) return null;
    if (parent1.is_baby or parent2.is_baby) return null;
    if (parent1.state != .unrolled or parent2.state != .unrolled) return null;

    parent1.is_in_love = false;
    parent1.love_timer = 0.0;
    parent1.breed_cooldown = armadillo_breed_cooldown;

    parent2.is_in_love = false;
    parent2.love_timer = 0.0;
    parent2.breed_cooldown = armadillo_breed_cooldown;

    return Armadillo.initBaby();
}

// ============================================================================
// Wolf Armor & Tamed Wolf Interaction
// ============================================================================

pub const WolfArmor = struct {
    durability: u16 = wolf_armor_max_durability,
    color: ?DyeColor = null,

    pub fn init() WolfArmor {
        return .{
            .durability = wolf_armor_max_durability,
            .color = null,
        };
    }

    pub fn currentCrackStage(self: WolfArmor) CrackStage {
        return getCrackStage(self.durability);
    }

    /// Returns the 5-stage visual crack progression (pristine, slightly/moderately/heavily cracked, broken).
    pub fn crackStage(self: WolfArmor) DefenseCrackStage {
        if (self.durability == 0) return .broken;
        if (self.durability == wolf_armor_durability) return .pristine;
        if (self.durability >= 48) return .slightly_cracked;
        if (self.durability >= 32) return .moderately_cracked;
        return .heavily_cracked;
    }

    /// Applies one of the 16 dye colors to this Wolf Armor.
    pub fn dye(self: *WolfArmor, color: DyeColor) void {
        self.color = color;
    }

    /// Removes dye from this Wolf Armor; returns true if dye was present.
    pub fn undye(self: *WolfArmor) bool {
        if (self.color == null) return false;
        self.color = null;
        return true;
    }

    pub fn isBroken(self: WolfArmor) bool {
        return self.durability == 0;
    }
};

/// Crafts Wolf Armor from 6 Armadillo Scutes.
pub fn craftWolfArmor(scutes_available: u8) ?WolfArmor {
    if (scutes_available < wolf_armor_craft_scutes) return null;
    return WolfArmor.init();
}

/// Crafting outcome descriptor preserving consumed scute count.
pub const CraftResult = struct {
    item: InteractionItem = .other,
    count: u8 = 0,
    scutes_consumed: u8 = 0,
};

/// Evaluates Wolf Armor crafting from 6 scutes and reports consumed scutes.
pub fn craftWolfArmorResult(scutes: u8) CraftResult {
    if (scutes < 6) return .{};
    return .{ .item = .wolf_armor, .count = 1, .scutes_consumed = 6 };
}

/// Returns the crack stage for Wolf Armor based on remaining durability:
/// - > 60: none
/// - 45..60: low_cracks
/// - 21..44: medium_cracks
/// - <= 20: high_cracks
pub fn getCrackStage(durability: u16) CrackStage {
    if (durability > crack_threshold_low) return .none;
    if (durability > crack_threshold_medium) return .low_cracks;
    if (durability > crack_threshold_high) return .medium_cracks;
    return .high_cracks;
}

/// Absorbs 100% of non-environmental damage directed at a tamed Wolf until the armor shatters.
/// When the armor shatters from a blow, the entire blow is absorbed, durability reaches 0,
/// and armor_broken is set to true. Subsequent blows with 0 durability penetrate to the wolf.
pub const AbsorbDamageResult = struct {
    damage_to_wolf: u16,
    armor_broken: bool,
};

pub fn absorbWolfDamage(armor: *WolfArmor, incoming_damage: u16) AbsorbDamageResult {
    if (incoming_damage == 0) {
        return .{
            .damage_to_wolf = 0,
            .armor_broken = (armor.durability == 0),
        };
    }

    if (armor.durability == 0) {
        return .{
            .damage_to_wolf = incoming_damage,
            .armor_broken = true,
        };
    }

    if (incoming_damage >= armor.durability) {
        armor.durability = 0;
        return .{
            .damage_to_wolf = 0,
            .armor_broken = true,
        };
    } else {
        armor.durability -= incoming_damage;
        return .{
            .damage_to_wolf = 0,
            .armor_broken = false,
        };
    }
}

/// Absorbs damage with explicit damage source check. Non-environmental damage is absorbed
/// 100% by wolf armor; environmental damage (drowning, freezing, suffocation, magic, wither, void)
/// bypasses wolf armor completely.
pub fn absorbWolfDamageWithKind(armor: *WolfArmor, incoming_damage: u16, kind: DamageKind) AbsorbDamageResult {
    if (kind == .environmental) {
        return .{
            .damage_to_wolf = incoming_damage,
            .armor_broken = (armor.durability == 0),
        };
    }
    return absorbWolfDamage(armor, incoming_damage);
}

/// Repairs Wolf Armor in place on a wolf using 1 Armadillo Scute (+8 durability, capped at 64).
/// Returns true if repair succeeded, or false if already at maximum durability.
pub fn repairWolfArmor(armor: *WolfArmor) bool {
    if (armor.durability >= wolf_armor_max_durability) return false;
    armor.durability = @min(wolf_armor_max_durability, armor.durability + scute_repair_amount);
    return true;
}

/// Repairs Wolf Armor using available Armadillo Scutes. Returns the number of scutes consumed.
pub fn repairWolfArmorWithScutes(armor: *WolfArmor, scutes_available: u8) u8 {
    var used: u8 = 0;
    while (used < scutes_available and armor.durability < wolf_armor_max_durability) {
        _ = repairWolfArmor(armor);
        used += 1;
    }
    return used;
}

/// Dyes Wolf Armor in place using one of 16 dye colors.
pub fn dyeWolfArmor(armor: *WolfArmor, color: DyeColor) void {
    armor.color = color;
}

/// Clears dye from Wolf Armor (e.g. by washing in a cauldron).
pub fn removeWolfArmorDye(armor: *WolfArmor) bool {
    return armor.undye();
}

/// Washes dyed Wolf Armor in a cauldron, clearing applied dye.
pub fn washArmorInCauldron(armor: *WolfArmor) bool {
    return armor.undye();
}

pub const WolfInteractionAction = enum {
    armor_equipped,
    armor_removed,
    repaired,
    nothing_to_repair,
    no_interaction,
    not_owner,
};

pub const WolfInteractionResult = struct {
    action: WolfInteractionAction,
    consumed_item: ?InteractionItem = null,
    returned_armor: ?WolfArmor = null,
};

pub const WolfDamageResult = struct {
    damage_to_wolf: u16 = 0,
    armor_broke: bool = false,
    sound: ?Sound = null,
};

/// Tamed Wolf entity supporting owner-gated armor equipping, scute repair, shears removal,
/// damage absorption with shatter sound, and dyeing.
pub const Wolf = struct {
    owner_id: u64,
    armor: ?WolfArmor = null,

    pub fn interact(self: *Wolf, player_id: u64, item: InteractionItem) WolfInteractionResult {
        if (player_id != self.owner_id) return .{ .action = .not_owner };
        if (self.armor) |*armor| {
            switch (item) {
                .armadillo_scute => {
                    if (armor.durability == wolf_armor_durability) return .{ .action = .nothing_to_repair };
                    armor.durability = @min(wolf_armor_durability, armor.durability + scute_repair_amount);
                    return .{ .action = .repaired, .consumed_item = .armadillo_scute };
                },
                .shears => {
                    const returned_armor = armor.*;
                    self.armor = null;
                    return .{ .action = .armor_removed, .returned_armor = returned_armor };
                },
                else => return .{ .action = .no_interaction },
            }
        }
        if (item == .wolf_armor) {
            self.armor = WolfArmor{};
            return .{ .action = .armor_equipped, .consumed_item = .wolf_armor };
        }
        return .{ .action = .no_interaction };
    }

    pub fn applyDamage(self: *Wolf, damage: u16) WolfDamageResult {
        if (self.armor) |*armor| {
            if (damage == 0) return .{};
            armor.durability -|= damage;
            if (armor.durability == 0) {
                self.armor = null;
                return .{ .damage_to_wolf = 0, .armor_broke = true, .sound = .armor_shatter };
            }
            return .{ .damage_to_wolf = 0 };
        }
        return .{ .damage_to_wolf = damage };
    }

    pub fn dyeArmor(self: *Wolf, player_id: u64, color: DyeColor) bool {
        if (player_id != self.owner_id) return false;
        const armor = if (self.armor) |*value| value else return false;
        armor.color = color;
        return true;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "constants have expected values" {
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), threat_detection_radius, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 49.0), threat_detection_radius_sq, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), spider_flee_radius, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 36.0), spider_flee_radius_sq, 0.0001);
    try std.testing.expectEqual(@as(u16, 16), brush_durability_cost);
    try std.testing.expectEqual(@as(u8, 1), scutes_per_brush);
    try std.testing.expectEqual(@as(u16, 64), wolf_armor_max_durability);
    try std.testing.expectEqual(@as(u8, 6), wolf_armor_craft_scutes);
    try std.testing.expectEqual(@as(u16, 8), scute_repair_amount);
    try std.testing.expectEqual(@as(u16, 60), crack_threshold_low);
    try std.testing.expectEqual(@as(u16, 44), crack_threshold_medium);
    try std.testing.expectEqual(@as(u16, 20), crack_threshold_high);
}

test "threat detection radius within 7 blocks" {
    try std.testing.expect(isThreatWithinRadius(0.0));
    try std.testing.expect(isThreatWithinRadius(25.0));
    try std.testing.expect(isThreatWithinRadius(49.0));
    try std.testing.expect(!isThreatWithinRadius(50.0));
    try std.testing.expect(!isThreatWithinRadius(100.0));
}

test "shouldTriggerRollUp triggers on threats within radius" {
    try std.testing.expect(shouldTriggerRollUp(30.0, true, false, false));
    try std.testing.expect(shouldTriggerRollUp(40.0, false, true, false));
    try std.testing.expect(shouldTriggerRollUp(10.0, false, false, true));
    try std.testing.expect(!shouldTriggerRollUp(50.0, true, false, false));
    try std.testing.expect(!shouldTriggerRollUp(50.0, false, true, false));
    try std.testing.expect(!shouldTriggerRollUp(50.0, false, false, true));
}

test "shouldTriggerRollUp ignores non-threats" {
    try std.testing.expect(!shouldTriggerRollUp(1.0, false, false, false));
    try std.testing.expect(!shouldTriggerRollUp(25.0, false, false, false));
}

test "armadillo state transition lifecycle" {
    var armadillo = Armadillo.init();
    try std.testing.expectEqual(ArmadilloState.unrolled, armadillo.state);

    armadillo.tick(0.1, true);
    try std.testing.expectEqual(ArmadilloState.rolling_up, armadillo.state);

    armadillo.tick(0.65, false); // total 0.75s in rolling_up
    try std.testing.expectEqual(ArmadilloState.rolled_up, armadillo.state);

    armadillo.tick(2.5, false);
    try std.testing.expectEqual(ArmadilloState.rolled_up, armadillo.state);

    armadillo.tick(1.0, false);
    try std.testing.expectEqual(ArmadilloState.peeking, armadillo.state);

    armadillo.tick(2.0, false);
    try std.testing.expectEqual(ArmadilloState.unrolling, armadillo.state);

    armadillo.tick(0.75, false);
    try std.testing.expectEqual(ArmadilloState.unrolled, armadillo.state);
}

test "peeking armadillo re-rolls immediately when threatened" {
    var armadillo = Armadillo.init();
    armadillo.state = .peeking;
    armadillo.state_timer = 1.0;

    armadillo.tick(0.1, true);
    try std.testing.expectEqual(ArmadilloState.rolled_up, armadillo.state);
}

test "rolledDamageReduction fully resists weak attacks" {
    try std.testing.expectEqual(@as(f32, 0.0), rolledDamageReduction(0.0));
    try std.testing.expectEqual(@as(f32, 0.0), rolledDamageReduction(0.5));
    try std.testing.expectEqual(@as(f32, 0.0), rolledDamageReduction(1.0));
}

test "rolledDamageReduction scales according to Minecraft formula" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), rolledDamageReduction(2.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), rolledDamageReduction(3.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), rolledDamageReduction(5.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), rolledDamageReduction(9.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), rolledDamageReduction(11.0), 0.0001);
}

test "armadillo applyDamage applies reduction only when rolled up" {
    var armadillo = Armadillo.init();

    const dmg1 = armadillo.applyDamage(5.0);
    try std.testing.expectEqual(@as(f32, 5.0), dmg1);
    try std.testing.expectEqual(ArmadilloState.rolling_up, armadillo.state);

    const dmg2 = armadillo.applyDamage(5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), dmg2, 0.0001);

    armadillo.state = .rolled_up;
    const dmg3 = armadillo.applyDamage(9.0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), dmg3, 0.0001);
}

test "brushArmadillo drops 1 scute and consumes 16 durability" {
    const res = brushArmadillo(64);
    try std.testing.expectEqual(@as(u8, 1), res.scutes_dropped);
    try std.testing.expectEqual(@as(u16, 16), res.brush_damage);
}

test "brushArmadillo with 0 durability fails" {
    const res = brushArmadillo(0);
    try std.testing.expectEqual(@as(u8, 0), res.scutes_dropped);
    try std.testing.expectEqual(@as(u16, 0), res.brush_damage);
}

test "brushArmadillo with less than 16 durability consumes remainder and breaks" {
    const res = brushArmadillo(10);
    try std.testing.expectEqual(@as(u8, 1), res.scutes_dropped);
    try std.testing.expectEqual(@as(u16, 10), res.brush_damage);
}

test "craftWolfArmor crafts armor with 6 scutes and 64 durability" {
    const armor = craftWolfArmor(6);
    try std.testing.expect(armor != null);
    try std.testing.expectEqual(@as(u16, 64), armor.?.durability);
    try std.testing.expect(armor.?.color == null);
}

test "craftWolfArmor fails with fewer than 6 scutes" {
    try std.testing.expect(craftWolfArmor(0) == null);
    try std.testing.expect(craftWolfArmor(5) == null);
}

test "wolf armor absorbs 100% of non-environmental damage" {
    var armor = WolfArmor.init();

    const res1 = absorbWolfDamage(&armor, 10);
    try std.testing.expectEqual(@as(u16, 0), res1.damage_to_wolf);
    try std.testing.expectEqual(false, res1.armor_broken);
    try std.testing.expectEqual(@as(u16, 54), armor.durability);

    const res2 = absorbWolfDamage(&armor, 20);
    try std.testing.expectEqual(@as(u16, 0), res2.damage_to_wolf);
    try std.testing.expectEqual(false, res2.armor_broken);
    try std.testing.expectEqual(@as(u16, 34), armor.durability);
}

test "wolf armor absorbs lethal shattering blow completely" {
    var armor = WolfArmor.init();
    armor.durability = 10;

    const res = absorbWolfDamage(&armor, 25);
    try std.testing.expectEqual(@as(u16, 0), res.damage_to_wolf);
    try std.testing.expectEqual(true, res.armor_broken);
    try std.testing.expectEqual(@as(u16, 0), armor.durability);
    try std.testing.expect(armor.isBroken());
}

test "shattered wolf armor lets damage penetrate to wolf" {
    var armor = WolfArmor.init();
    armor.durability = 0;

    const res = absorbWolfDamage(&armor, 15);
    try std.testing.expectEqual(@as(u16, 15), res.damage_to_wolf);
    try std.testing.expectEqual(true, res.armor_broken);
}

test "environmental damage bypasses wolf armor" {
    var armor = WolfArmor.init();

    const res = absorbWolfDamageWithKind(&armor, 8, .environmental);
    try std.testing.expectEqual(@as(u16, 8), res.damage_to_wolf);
    try std.testing.expectEqual(false, res.armor_broken);
    try std.testing.expectEqual(@as(u16, 64), armor.durability);
}

test "crack stage thresholds at 60, 44, 20" {
    try std.testing.expectEqual(CrackStage.none, getCrackStage(64));
    try std.testing.expectEqual(CrackStage.none, getCrackStage(61));

    try std.testing.expectEqual(CrackStage.low_cracks, getCrackStage(60));
    try std.testing.expectEqual(CrackStage.low_cracks, getCrackStage(45));

    try std.testing.expectEqual(CrackStage.medium_cracks, getCrackStage(44));
    try std.testing.expectEqual(CrackStage.medium_cracks, getCrackStage(21));

    try std.testing.expectEqual(CrackStage.high_cracks, getCrackStage(20));
    try std.testing.expectEqual(CrackStage.high_cracks, getCrackStage(1));
    try std.testing.expectEqual(CrackStage.high_cracks, getCrackStage(0));
}

test "repairWolfArmor restores 8 durability per scute up to 64" {
    var armor = WolfArmor.init();
    armor.durability = 50;

    try std.testing.expect(repairWolfArmor(&armor));
    try std.testing.expectEqual(@as(u16, 58), armor.durability);

    try std.testing.expect(repairWolfArmor(&armor));
    try std.testing.expectEqual(@as(u16, 64), armor.durability);

    try std.testing.expect(!repairWolfArmor(&armor));
    try std.testing.expectEqual(@as(u16, 64), armor.durability);
}

test "repairWolfArmorWithScutes consumes exact scutes needed" {
    var armor = WolfArmor.init();
    armor.durability = 40;

    const consumed = repairWolfArmorWithScutes(&armor, 5);
    try std.testing.expectEqual(@as(u8, 3), consumed);
    try std.testing.expectEqual(@as(u16, 64), armor.durability);
}

test "wolf armor dye colors: 16 colors supported" {
    var armor = WolfArmor.init();
    try std.testing.expect(armor.color == null);

    const colors = [_]DyeColor{
        .white, .orange,     .magenta, .light_blue,
        .yellow, .lime,      .pink,    .gray,
        .light_gray, .cyan,  .purple,  .blue,
        .brown, .green,      .red,     .black,
    };
    try std.testing.expectEqual(@as(usize, 16), colors.len);

    for (colors, 0..) |c, idx| {
        try std.testing.expectEqual(@as(u8, @intCast(idx)), @intFromEnum(c));
        dyeWolfArmor(&armor, c);
        try std.testing.expectEqual(c, armor.color.?);
        try std.testing.expect(c.rgb() > 0);
    }
}

test "removeWolfArmorDye clears applied dye" {
    var armor = WolfArmor.init();
    dyeWolfArmor(&armor, .red);
    try std.testing.expectEqual(DyeColor.red, armor.color.?);

    try std.testing.expect(removeWolfArmorDye(&armor));
    try std.testing.expect(armor.color == null);

    try std.testing.expect(!removeWolfArmorDye(&armor));
}

test "spider eye feeding enters love mode for adult unrolled armadillo" {
    var armadillo = Armadillo.init();
    const result = feedSpiderEye(&armadillo, true);
    try std.testing.expectEqual(FeedResult.entered_love_mode, result);
    try std.testing.expect(armadillo.is_in_love);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), armadillo.love_timer, 0.0001);
}

test "spider eye feeding refused when armadillo is rolled up" {
    var armadillo = Armadillo.init();
    armadillo.state = .rolled_up;

    const result = feedSpiderEye(&armadillo, true);
    try std.testing.expectEqual(FeedResult.refused_rolled_up, result);
    try std.testing.expect(!armadillo.is_in_love);
}

test "spider eye feeding accelerates baby growth" {
    var baby = Armadillo.initBaby();
    try std.testing.expect(baby.is_baby);
    try std.testing.expectEqual(@as(f32, 0.0), baby.baby_age);

    const result = feedSpiderEye(&baby, true);
    try std.testing.expectEqual(FeedResult.baby_growth_accelerated, result);
    try std.testing.expectApproxEqAbs(armadillo_baby_growth_feed_bonus, baby.baby_age, 0.0001);
}

test "tryBreedArmadillos produces baby and sets cooldown" {
    var parent1 = Armadillo.init();
    var parent2 = Armadillo.init();

    _ = feedSpiderEye(&parent1, true);
    _ = feedSpiderEye(&parent2, true);

    const maybe_baby = tryBreedArmadillos(&parent1, &parent2);
    try std.testing.expect(maybe_baby != null);
    try std.testing.expect(maybe_baby.?.is_baby);

    try std.testing.expect(!parent1.is_in_love);
    try std.testing.expect(!parent2.is_in_love);
    try std.testing.expectApproxEqAbs(armadillo_breed_cooldown, parent1.breed_cooldown, 0.0001);
    try std.testing.expectApproxEqAbs(armadillo_breed_cooldown, parent2.breed_cooldown, 0.0001);

    try std.testing.expectEqual(FeedResult.refused_on_cooldown, feedSpiderEye(&parent1, true));
}

test "spiders flee from unrolled armadillos within 6 blocks" {
    try std.testing.expect(shouldSpiderFlee(.unrolled, 20.0));
    try std.testing.expect(shouldSpiderFlee(.unrolled, 36.0));
    try std.testing.expect(!shouldSpiderFlee(.unrolled, 37.0));

    try std.testing.expect(!shouldSpiderFlee(.rolled_up, 10.0));
    try std.testing.expect(!shouldSpiderFlee(.rolling_up, 10.0));
    try std.testing.expect(!shouldSpiderFlee(.peeking, 10.0));
    try std.testing.expect(!shouldSpiderFlee(.unrolling, 10.0));
}

// ============================================================================
// Unified Defense & Tamed Wolf Interaction Tests (from armadillo_wolf_defense)
// ============================================================================

test "threat radius includes exactly seven meters and rejects farther entities" {
    try std.testing.expect(isThreatDistanceWithinRadius(7));
    try std.testing.expect(!isThreatDistanceWithinRadius(7.001));
    try std.testing.expect(!(Threat{ .kind = .zombie, .distance = 7.01 }).isRelevant());
}

test "threat range uses three dimensional Euclidean distance" {
    try std.testing.expectApproxEqAbs(@as(f32, 7), distance3d(0, 0, 0, 3, 4, @sqrt(@as(f32, 24))), 0.0001);
    try std.testing.expect(!isThreatDistanceWithinRadius(distance3d(0, 0, 0, 3, 4, 5)));
}

test "sprinting player triggers roll-up" {
    var armadillo = DefenseArmadillo{};
    _ = armadillo.tick(&.{.{ .kind = .sprinting_player, .distance = 2 }});
    try std.testing.expectEqual(DefenseArmadilloState.rolling_up, armadillo.state);
}

test "zombies trigger roll-up" {
    try threatStartsRoll(.zombie);
}
test "husks trigger roll-up" {
    try threatStartsRoll(.husk);
}
test "drowned trigger roll-up" {
    try threatStartsRoll(.drowned);
}
test "skeletons trigger roll-up" {
    try threatStartsRoll(.skeleton);
}
test "spiders trigger roll-up" {
    try threatStartsRoll(.spider);
}
test "cave spiders trigger roll-up" {
    try threatStartsRoll(.cave_spider);
}

fn threatStartsRoll(kind: ThreatKind) !void {
    var armadillo = DefenseArmadillo{};
    _ = armadillo.tick(&.{.{ .kind = kind, .distance = 6.9 }});
    try std.testing.expectEqual(DefenseArmadilloState.rolling_up, armadillo.state);
}

test "environmental damage triggers roll-up" {
    var armadillo = DefenseArmadillo{};
    _ = armadillo.tick(&.{.{ .kind = .environmental_damage, .distance = 100 }});
    try std.testing.expectEqual(DefenseArmadilloState.rolling_up, armadillo.state);
}

test "ordinary nearby entity is ignored" {
    var armadillo = DefenseArmadillo{};
    _ = armadillo.tick(&.{.{ .kind = .other, .distance = 1 }});
    try std.testing.expectEqual(DefenseArmadilloState.standing, armadillo.state);
}

test "rolling closes into curled ball and emits clack" {
    var armadillo = DefenseArmadillo{};
    _ = armadillo.tick(&.{.{ .kind = .sprinting_player, .distance = 1 }});
    const result = armadillo.tick(&.{});
    try std.testing.expectEqual(DefenseArmadilloState.curled_ball, armadillo.state);
    try std.testing.expectEqual(Sound.shell_clack, result.sound.?);
}

test "weak attack is fully negated while curled" {
    var armadillo = DefenseArmadillo{ .state = .curled_ball };
    try std.testing.expectEqual(@as(f32, 0), armadillo.applyDamage(10, .weak));
}

test "blast attack is reduced by eighty five percent" {
    var armadillo = DefenseArmadillo{ .state = .curled_ball };
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), armadillo.applyDamage(10, .blast), 0.0001);
}

test "melee attack is reduced by eighty five percent" {
    var armadillo = DefenseArmadillo{ .state = .curled_ball };
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), armadillo.applyDamage(5, .melee), 0.0001);
}

test "uncurled armadillo takes full damage" {
    var armadillo = DefenseArmadillo{};
    try std.testing.expectEqual(@as(f32, 5), armadillo.applyDamage(5, .weak));
}

test "threat resets the 200 tick clear counter" {
    var armadillo = DefenseArmadillo{ .state = .curled_ball, .threat_clear_ticks = 199 };
    _ = armadillo.tick(&.{.{ .kind = .spider, .distance = 7 }});
    try std.testing.expectEqual(@as(u16, 0), armadillo.threat_clear_ticks);
    try std.testing.expectEqual(DefenseArmadilloState.curled_ball, armadillo.state);
}

test "starts unrolling on the two hundredth clear tick" {
    var armadillo = DefenseArmadillo{ .state = .curled_ball };
    for (0..199) |_| _ = armadillo.tick(&.{});
    try std.testing.expectEqual(DefenseArmadilloState.curled_ball, armadillo.state);
    _ = armadillo.tick(&.{});
    try std.testing.expectEqual(DefenseArmadilloState.unrolling, armadillo.state);
}

test "unrolling returns to standing after transition tick" {
    var armadillo = DefenseArmadillo{ .state = .unrolling };
    _ = armadillo.tick(&.{});
    try std.testing.expectEqual(DefenseArmadilloState.standing, armadillo.state);
}

test "brush drops one scute and consumes sixteen durability" {
    const result = (DefenseArmadillo{}).brush(.brush, 64);
    try std.testing.expectEqual(@as(u8, 1), result.scutes_dropped);
    try std.testing.expectEqual(@as(u16, 16), result.brush_durability_used);
}

test "wrong tool does not brush armadillo" {
    const result = (DefenseArmadillo{}).brush(.other, 64);
    try std.testing.expectEqual(@as(u8, 0), result.scutes_dropped);
}

test "broken brush yields no scute" {
    const result = (DefenseArmadillo{}).brush(.brush, 0);
    try std.testing.expectEqual(@as(u8, 0), result.scutes_dropped);
}

test "brush use never spends more remaining durability" {
    const result = (DefenseArmadillo{}).brush(.brush, 5);
    try std.testing.expectEqual(@as(u16, 5), result.brush_durability_used);
}

test "natural scute drop occurs every 24000 ticks" {
    var armadillo = DefenseArmadillo{ .ticks_since_scute_drop = 23_998 };
    try std.testing.expect(!armadillo.tickNaturalScute());
    try std.testing.expect(armadillo.tickNaturalScute());
    try std.testing.expectEqual(@as(u32, 0), armadillo.ticks_since_scute_drop);
}

test "crafting requires six scutes and consumes six" {
    try std.testing.expectEqual(@as(u8, 0), craftWolfArmorResult(5).count);
    const result = craftWolfArmorResult(6);
    try std.testing.expectEqual(InteractionItem.wolf_armor, result.item);
    try std.testing.expectEqual(@as(u8, 1), result.count);
    try std.testing.expectEqual(@as(u8, 6), result.scutes_consumed);
}

test "only owner may equip wolf armor" {
    var wolf = Wolf{ .owner_id = 12 };
    try std.testing.expectEqual(WolfInteractionAction.not_owner, wolf.interact(13, .wolf_armor).action);
    try std.testing.expectEqual(@as(?WolfArmor, null), wolf.armor);
    const equipped = wolf.interact(12, .wolf_armor);
    try std.testing.expectEqual(WolfInteractionAction.armor_equipped, equipped.action);
    try std.testing.expectEqual(InteractionItem.wolf_armor, equipped.consumed_item.?);
}

test "only owner may remove armor with shears" {
    var wolf = Wolf{ .owner_id = 12, .armor = .{ .durability = 23, .color = .cyan } };
    try std.testing.expectEqual(WolfInteractionAction.not_owner, wolf.interact(13, .shears).action);
    try std.testing.expect(wolf.armor != null);
    const removed = wolf.interact(12, .shears);
    try std.testing.expectEqual(WolfInteractionAction.armor_removed, removed.action);
    try std.testing.expectEqual(@as(u16, 23), removed.returned_armor.?.durability);
    try std.testing.expectEqual(DyeColor.cyan, removed.returned_armor.?.color.?);
    try std.testing.expect(wolf.armor == null);
}

test "wolf armor absorbs damage and loses matching durability" {
    var wolf = Wolf{ .owner_id = 1, .armor = .{} };
    const result = wolf.applyDamage(10);
    try std.testing.expectEqual(@as(u16, 0), result.damage_to_wolf);
    try std.testing.expectEqual(@as(u16, 54), wolf.armor.?.durability);
}

test "wolf armor break absorbs final hit and emits shatter sound" {
    var wolf = Wolf{ .owner_id = 1, .armor = .{ .durability = 3 } };
    const result = wolf.applyDamage(10);
    try std.testing.expectEqual(@as(u16, 0), result.damage_to_wolf);
    try std.testing.expect(result.armor_broke);
    try std.testing.expectEqual(Sound.armor_shatter, result.sound.?);
    try std.testing.expect(wolf.armor == null);
}

test "unarmored wolf takes full damage" {
    var wolf = Wolf{ .owner_id = 1 };
    try std.testing.expectEqual(@as(u16, 9), wolf.applyDamage(9).damage_to_wolf);
}

test "armor crack stages match requested durability ranges" {
    try std.testing.expectEqual(DefenseCrackStage.pristine, (WolfArmor{ .durability = 64 }).crackStage());
    try std.testing.expectEqual(DefenseCrackStage.slightly_cracked, (WolfArmor{ .durability = 63 }).crackStage());
    try std.testing.expectEqual(DefenseCrackStage.slightly_cracked, (WolfArmor{ .durability = 48 }).crackStage());
    try std.testing.expectEqual(DefenseCrackStage.moderately_cracked, (WolfArmor{ .durability = 47 }).crackStage());
    try std.testing.expectEqual(DefenseCrackStage.moderately_cracked, (WolfArmor{ .durability = 32 }).crackStage());
    try std.testing.expectEqual(DefenseCrackStage.heavily_cracked, (WolfArmor{ .durability = 31 }).crackStage());
    try std.testing.expectEqual(DefenseCrackStage.heavily_cracked, (WolfArmor{ .durability = 1 }).crackStage());
    try std.testing.expectEqual(DefenseCrackStage.broken, (WolfArmor{ .durability = 0 }).crackStage());
}

test "owner repairs armor by eight durability with scute" {
    var wolf = Wolf{ .owner_id = 1, .armor = .{ .durability = 40 } };
    const repair = wolf.interact(1, .armadillo_scute);
    try std.testing.expectEqual(WolfInteractionAction.repaired, repair.action);
    try std.testing.expectEqual(InteractionItem.armadillo_scute, repair.consumed_item.?);
    try std.testing.expectEqual(@as(u16, 48), wolf.armor.?.durability);
    try std.testing.expectEqual(DefenseCrackStage.slightly_cracked, wolf.armor.?.crackStage());
}

test "scute repair caps armor durability at sixty four" {
    var wolf = Wolf{ .owner_id = 1, .armor = .{ .durability = 60 } };
    _ = wolf.interact(1, .armadillo_scute);
    try std.testing.expectEqual(@as(u16, 64), wolf.armor.?.durability);
}

test "dye enum exposes all sixteen named colors and RGB values" {
    const colors = [_]DyeColor{ .white, .orange, .magenta, .light_blue, .yellow, .lime, .pink, .gray, .light_gray, .cyan, .purple, .blue, .brown, .green, .red, .black };
    try std.testing.expectEqual(@as(usize, 16), colors.len);
    for (colors) |color| try std.testing.expect(color.rgb() != 0);
    try std.testing.expectEqual(@as(u32, 0xF9FFFE), DyeColor.white.rgb());
    try std.testing.expectEqual(@as(u32, 0x1D1D21), DyeColor.black.rgb());
}

test "owner can dye armor and cauldron washes it" {
    var wolf = Wolf{ .owner_id = 4, .armor = .{} };
    try std.testing.expect(!wolf.dyeArmor(5, .cyan));
    try std.testing.expect(wolf.dyeArmor(4, .cyan));
    try std.testing.expectEqual(DyeColor.cyan, wolf.armor.?.color.?);
    if (wolf.armor) |*armor| {
        try std.testing.expect(washArmorInCauldron(armor));
    } else {
        return error.TestUnexpectedResult;
    }
    try std.testing.expect(wolf.armor.?.color == null);
}

test "washing undyed armor is a no-op" {
    var armor = WolfArmor{};
    try std.testing.expect(!washArmorInCauldron(&armor));
}
