const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Distance in blocks within which threats (sprinting player, undead mob, recent damage)
/// cause an armadillo to roll up into its protective ball (7 blocks).
pub const threat_detection_radius: f32 = 7.0;
pub const threat_detection_radius_sq: f32 = 49.0;

/// Distance in blocks within which spiders and cave spiders flee from unrolled armadillos (6 blocks).
pub const spider_flee_radius: f32 = 6.0;
pub const spider_flee_radius_sq: f32 = 36.0;

/// Brush durability consumed when harvesting an armadillo scute.
pub const brush_durability_cost: u16 = 16;
/// Number of armadillo scutes yielded per brush action.
pub const scutes_per_brush: u8 = 1;

/// Maximum durability points for Wolf Armor.
pub const wolf_armor_max_durability: u16 = 64;
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

/// Behavioral state of an Armadillo.
pub const ArmadilloState = enum {
    unrolled,
    rolling_up,
    rolled_up,
    peeking,
    unrolling,
};

/// Type of threat capable of startling an Armadillo.
pub const ThreatType = enum {
    none,
    sprinting_player,
    undead_mob,
    recent_damage,
};

/// Crack stages for Wolf Armor visual degradation.
pub const CrackStage = enum {
    none,
    low_cracks,
    medium_cracks,
    high_cracks,
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

// ============================================================================
// Core Functions: Armadillo Defense & Brushing
// ============================================================================

/// Calculates whether a squared distance is within the 7-block threat detection radius.
pub fn isThreatWithinRadius(distance_sq: f32) bool {
    return distance_sq <= threat_detection_radius_sq;
}

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
// Wolf Armor
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

    pub fn isBroken(self: WolfArmor) bool {
        return self.durability == 0;
    }
};

/// Crafts Wolf Armor from 6 Armadillo Scutes.
pub fn craftWolfArmor(scutes_available: u8) ?WolfArmor {
    if (scutes_available < wolf_armor_craft_scutes) return null;
    return WolfArmor.init();
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
    if (armor.color == null) return false;
    armor.color = null;
    return true;
}

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
    // 0 blocks
    try std.testing.expect(isThreatWithinRadius(0.0));
    // 5 blocks (25 sq)
    try std.testing.expect(isThreatWithinRadius(25.0));
    // Exactly 7 blocks (49 sq)
    try std.testing.expect(isThreatWithinRadius(49.0));
    // Outside 7 blocks (50 sq)
    try std.testing.expect(!isThreatWithinRadius(50.0));
    // Far away
    try std.testing.expect(!isThreatWithinRadius(100.0));
}

test "shouldTriggerRollUp triggers on threats within radius" {
    // Sprinting player within 7 blocks
    try std.testing.expect(shouldTriggerRollUp(30.0, true, false, false));
    // Undead mob within 7 blocks
    try std.testing.expect(shouldTriggerRollUp(40.0, false, true, false));
    // Recent damage within 7 blocks
    try std.testing.expect(shouldTriggerRollUp(10.0, false, false, true));
    // Threat beyond 7 blocks does not trigger
    try std.testing.expect(!shouldTriggerRollUp(50.0, true, false, false));
    try std.testing.expect(!shouldTriggerRollUp(50.0, false, true, false));
    try std.testing.expect(!shouldTriggerRollUp(50.0, false, false, true));
}

test "shouldTriggerRollUp ignores non-threats" {
    // Walking player (not sprinting), no undead, no damage
    try std.testing.expect(!shouldTriggerRollUp(1.0, false, false, false));
    try std.testing.expect(!shouldTriggerRollUp(25.0, false, false, false));
}

test "armadillo state transition lifecycle" {
    var armadillo = Armadillo.init();
    try std.testing.expectEqual(ArmadilloState.unrolled, armadillo.state);

    // Threat triggers rolling_up
    armadillo.tick(0.1, true);
    try std.testing.expectEqual(ArmadilloState.rolling_up, armadillo.state);

    // Advances to rolled_up after rolling_up_duration (0.75s)
    armadillo.tick(0.65, false); // total 0.75s in rolling_up
    try std.testing.expectEqual(ArmadilloState.rolled_up, armadillo.state);

    // Stays rolled up while threat cooldown is active
    armadillo.tick(2.5, false);
    try std.testing.expectEqual(ArmadilloState.rolled_up, armadillo.state);

    // After threat cooldown clears and rolled_up_duration elapses, enters peeking
    armadillo.tick(1.0, false);
    try std.testing.expectEqual(ArmadilloState.peeking, armadillo.state);

    // After peeking_duration (2.0s), transitions to unrolling
    armadillo.tick(2.0, false);
    try std.testing.expectEqual(ArmadilloState.unrolling, armadillo.state);

    // After unrolling_duration (0.75s), returns to unrolled
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
    // formula: (raw_damage - 1.0) / 2.0
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), rolledDamageReduction(2.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), rolledDamageReduction(3.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), rolledDamageReduction(5.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), rolledDamageReduction(9.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), rolledDamageReduction(11.0), 0.0001);
}

test "armadillo applyDamage applies reduction only when rolled up" {
    var armadillo = Armadillo.init();

    // When unrolled, first hit does unreduced damage but triggers roll-up
    const dmg1 = armadillo.applyDamage(5.0);
    try std.testing.expectEqual(@as(f32, 5.0), dmg1);
    try std.testing.expectEqual(ArmadilloState.rolling_up, armadillo.state);

    // Next hit while rolling_up or rolled_up gets reduced
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

    // Incoming 25 damage exceeds 10 durability, armor absorbs fully and breaks
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

    // Drowning / Freezing / Environmental damage penetrates directly
    const res = absorbWolfDamageWithKind(&armor, 8, .environmental);
    try std.testing.expectEqual(@as(u16, 8), res.damage_to_wolf);
    try std.testing.expectEqual(false, res.armor_broken);
    try std.testing.expectEqual(@as(u16, 64), armor.durability); // Armor undamaged
}

test "crack stage thresholds at 60, 44, 20" {
    try std.testing.expectEqual(CrackStage.none, getCrackStage(64));
    try std.testing.expectEqual(CrackStage.none, getCrackStage(61));

    // Threshold 60 -> low_cracks
    try std.testing.expectEqual(CrackStage.low_cracks, getCrackStage(60));
    try std.testing.expectEqual(CrackStage.low_cracks, getCrackStage(45));

    // Threshold 44 -> medium_cracks
    try std.testing.expectEqual(CrackStage.medium_cracks, getCrackStage(44));
    try std.testing.expectEqual(CrackStage.medium_cracks, getCrackStage(21));

    // Threshold 20 -> high_cracks
    try std.testing.expectEqual(CrackStage.high_cracks, getCrackStage(20));
    try std.testing.expectEqual(CrackStage.high_cracks, getCrackStage(1));
    try std.testing.expectEqual(CrackStage.high_cracks, getCrackStage(0));
}

test "repairWolfArmor restores 8 durability per scute up to 64" {
    var armor = WolfArmor.init();
    armor.durability = 50;

    // First repair: 50 + 8 = 58
    try std.testing.expect(repairWolfArmor(&armor));
    try std.testing.expectEqual(@as(u16, 58), armor.durability);

    // Second repair: 58 + 8 = 64 (clamped)
    try std.testing.expect(repairWolfArmor(&armor));
    try std.testing.expectEqual(@as(u16, 64), armor.durability);

    // Cannot repair when full
    try std.testing.expect(!repairWolfArmor(&armor));
    try std.testing.expectEqual(@as(u16, 64), armor.durability);
}

test "repairWolfArmorWithScutes consumes exact scutes needed" {
    var armor = WolfArmor.init();
    armor.durability = 40; // Needs 24 durability -> 3 scutes

    const consumed = repairWolfArmorWithScutes(&armor, 5);
    try std.testing.expectEqual(@as(u8, 3), consumed);
    try std.testing.expectEqual(@as(u16, 64), armor.durability);
}

test "wolf armor dye colors: 16 colors supported" {
    var armor = WolfArmor.init();
    try std.testing.expect(armor.color == null);

    const colors = [_]DyeColor{
        .white, .orange,   .magenta, .light_blue,
        .yellow, .lime,    .pink,    .gray,
        .light_gray, .cyan, .purple,  .blue,
        .brown, .green,    .red,     .black,
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

    // Removing when already null returns false
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

    // Both parents exit love mode and enter 300s breed cooldown
    try std.testing.expect(!parent1.is_in_love);
    try std.testing.expect(!parent2.is_in_love);
    try std.testing.expectApproxEqAbs(armadillo_breed_cooldown, parent1.breed_cooldown, 0.0001);
    try std.testing.expectApproxEqAbs(armadillo_breed_cooldown, parent2.breed_cooldown, 0.0001);

    // Feeding during cooldown is refused
    try std.testing.expectEqual(FeedResult.refused_on_cooldown, feedSpiderEye(&parent1, true));
}

test "spiders flee from unrolled armadillos within 6 blocks" {
    // Unrolled within 6 blocks -> flee
    try std.testing.expect(shouldSpiderFlee(.unrolled, 20.0));
    try std.testing.expect(shouldSpiderFlee(.unrolled, 36.0));

    // Beyond 6 blocks -> do not flee
    try std.testing.expect(!shouldSpiderFlee(.unrolled, 37.0));

    // Rolled up armadillo -> spiders do not flee
    try std.testing.expect(!shouldSpiderFlee(.rolled_up, 10.0));
    try std.testing.expect(!shouldSpiderFlee(.rolling_up, 10.0));
    try std.testing.expect(!shouldSpiderFlee(.peeking, 10.0));
    try std.testing.expect(!shouldSpiderFlee(.unrolling, 10.0));
}
