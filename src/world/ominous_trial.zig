const std = @import("std");

// ============================================================================
// Item Tags & Identifiers for Milestone 300 Integration
// ============================================================================

pub const DiamondBlockTag: u16 = 219;
pub const BreezeRodTag: u16 = 371;
pub const WindChargeTag: u16 = 372;
pub const HeavyCoreTag: u16 = 373;
pub const TrialKeyTag: u16 = 376;
pub const TrialSpawnerTag: u16 = 377;
pub const VaultTag: u16 = 378;
pub const EnchantedGoldenAppleTag: u16 = 379;

// New item tags introduced for Ominous Trials & Bogged
pub const RedMushroomTag: u16 = 401;
pub const BrownMushroomTag: u16 = 402;
pub const OminousBottleTag: u16 = 403;
pub const OminousTrialKeyTag: u16 = 404;
pub const WindBurstBookTag: u16 = 405; // Wind Burst III Enchanted Book
pub const FlowBannerPatternTag: u16 = 406;
pub const BoltBannerPatternTag: u16 = 407;

// ============================================================================
// 1. Bogged Poison Skeleton Mob
// ============================================================================

pub const bogged_max_health: f32 = 16.0;
pub const standard_skeleton_max_health: f32 = 20.0;

pub const bogged_fire_interval: f32 = 3.5;
pub const standard_skeleton_fire_interval: f32 = 2.0;

pub const bogged_poison_duration: f32 = 4.0;
pub const bogged_arrow_damage: f32 = 2.0;

pub const MushroomType = enum(u8) {
    red = 0,
    brown = 1,

    pub fn tag(self: MushroomType) u16 {
        return switch (self) {
            .red => RedMushroomTag,
            .brown => BrownMushroomTag,
        };
    }

    pub fn name(self: MushroomType) []const u8 {
        return switch (self) {
            .red => "Red Mushroom",
            .brown => "Brown Mushroom",
        };
    }
};

pub const BoggedArrow = struct {
    damage: f32 = bogged_arrow_damage,
    poison_duration: f32 = bogged_poison_duration,
};

pub const BoggedMob = struct {
    health: f32 = bogged_max_health,
    max_health: f32 = bogged_max_health,
    fire_interval: f32 = bogged_fire_interval,
    poison_duration: f32 = bogged_poison_duration,
    shot_cooldown: f32 = 0.0,
    sheared: bool = false,
    pos: [3]f32 = .{ 0.0, 0.0, 0.0 },

    pub fn init(x: f32, y: f32, z: f32) BoggedMob {
        return .{
            .health = bogged_max_health,
            .max_health = bogged_max_health,
            .fire_interval = bogged_fire_interval,
            .poison_duration = bogged_poison_duration,
            .shot_cooldown = 0.0,
            .sheared = false,
            .pos = .{ x, y, z },
        };
    }

    pub fn tick(self: *BoggedMob, dt: f32) void {
        if (self.shot_cooldown > dt) {
            self.shot_cooldown -= dt;
        } else {
            self.shot_cooldown = 0.0;
        }
    }

    pub fn canFire(self: BoggedMob) bool {
        return self.health > 0.0 and self.shot_cooldown <= 0.0;
    }

    pub fn fireArrow(self: *BoggedMob) ?BoggedArrow {
        if (!self.canFire()) return null;
        self.shot_cooldown = self.fire_interval;
        return BoggedArrow{
            .damage = bogged_arrow_damage,
            .poison_duration = self.poison_duration,
        };
    }

    pub fn takeDamage(self: *BoggedMob, amount: f32) void {
        self.health = @max(0.0, self.health - amount);
    }

    pub fn isAlive(self: BoggedMob) bool {
        return self.health > 0.0;
    }

    pub fn shear(self: *BoggedMob) u8 {
        return shearBogged(self);
    }
};

/// Shearing a Bogged drops 2 Mushrooms (red/brown) once per Bogged.
/// Returns the number of mushrooms dropped (2 on success, 0 if already sheared).
pub fn shearBogged(bogged: *BoggedMob) u8 {
    if (bogged.sheared) return 0;
    bogged.sheared = true;
    return 2;
}

pub const BoggedShearDrop = struct {
    count: u8,
    mushrooms: [2]MushroomType,
};

/// Shears a Bogged and returns the specific mushroom variants dropped based on seed.
pub fn shearBoggedWithTypes(bogged: *BoggedMob, seed: u32) ?BoggedShearDrop {
    const count = shearBogged(bogged);
    if (count == 0) return null;
    const first: MushroomType = if ((seed & 1) == 0) .red else .brown;
    const second: MushroomType = if ((seed & 2) == 0) .brown else .red;
    return BoggedShearDrop{
        .count = count,
        .mushrooms = .{ first, second },
    };
}

// ============================================================================
// 2. Ominous Bottle, Bad Omen & Trial Omen
// ============================================================================

pub const min_amplifier: u8 = 1;
pub const max_amplifier: u8 = 5;

pub const bad_omen_duration: f32 = 6000.0; // 6000.0s (100 minutes)
pub const trial_omen_base_duration: f32 = 900.0; // 900.0s (15 minutes) per amplifier tier
pub const trial_spawner_detection_radius: f32 = 14.0;
pub const trial_spawner_detection_radius_sq: f32 = trial_spawner_detection_radius * trial_spawner_detection_radius; // 196.0

pub const BottleTier = enum(u8) {
    I = 1,
    II = 2,
    III = 3,
    IV = 4,
    V = 5,
};

pub const BadOmenEffect = struct {
    amplifier: u8,
    duration: f32 = bad_omen_duration,
    active: bool = true,

    pub fn init(amplifier: u8) BadOmenEffect {
        const clamped_amp = @min(max_amplifier, @max(min_amplifier, amplifier));
        return .{
            .amplifier = clamped_amp,
            .duration = bad_omen_duration,
            .active = true,
        };
    }

    pub fn tick(self: *BadOmenEffect, dt: f32) void {
        if (!self.active) return;
        if (self.duration > dt) {
            self.duration -= dt;
        } else {
            self.duration = 0.0;
            self.active = false;
        }
    }
};

pub const OminousBottle = struct {
    amplifier: u8 = 1,

    pub fn init(tier: u8) OminousBottle {
        return .{ .amplifier = @min(max_amplifier, @max(min_amplifier, tier)) };
    }

    pub fn consume(self: OminousBottle) BadOmenEffect {
        return BadOmenEffect.init(self.amplifier);
    }
};

pub fn calculateTrialOmenDuration(amplifier: u8) f32 {
    const clamped_amp = @min(max_amplifier, @max(min_amplifier, amplifier));
    return trial_omen_base_duration * @as(f32, @floatFromInt(clamped_amp));
}

pub const TrialOmenEffect = struct {
    amplifier: u8,
    duration: f32,
    max_duration: f32,
    active: bool = true,

    pub fn init(amplifier: u8) TrialOmenEffect {
        const clamped_amp = @min(max_amplifier, @max(min_amplifier, amplifier));
        const dur = calculateTrialOmenDuration(clamped_amp);
        return .{
            .amplifier = clamped_amp,
            .duration = dur,
            .max_duration = dur,
            .active = true,
        };
    }

    pub fn tick(self: *TrialOmenEffect, dt: f32) void {
        if (!self.active) return;
        if (self.duration > dt) {
            self.duration -= dt;
        } else {
            self.duration = 0.0;
            self.active = false;
        }
    }
};

pub fn isWithinTrialSpawnerRadius(px: f32, py: f32, pz: f32, sx: f32, sy: f32, sz: f32) bool {
    const dx = px - sx;
    const dy = py - sy;
    const dz = pz - sz;
    return (dx * dx + dy * dy + dz * dz) <= trial_spawner_detection_radius_sq;
}

pub fn convertBadOmenToTrialOmen(bad_omen: BadOmenEffect) TrialOmenEffect {
    return TrialOmenEffect.init(bad_omen.amplifier);
}

/// Checks if a player with Bad Omen is within a Trial Spawner's 14.0 block detection radius.
/// If so, converts the Bad Omen into Trial Omen (900.0s * amplifier) and deactivates Bad Omen.
pub fn tryTriggerTrialOmen(
    bad_omen: *BadOmenEffect,
    px: f32,
    py: f32,
    pz: f32,
    sx: f32,
    sy: f32,
    sz: f32,
) ?TrialOmenEffect {
    if (!bad_omen.active) return null;
    if (!isWithinTrialSpawnerRadius(px, py, pz, sx, sy, sz)) return null;

    const omen = convertBadOmenToTrialOmen(bad_omen.*);
    bad_omen.active = false;
    bad_omen.duration = 0.0;
    return omen;
}

// ============================================================================
// 3. Ominous Trial Spawner
// ============================================================================

pub const standard_armored_chance: f32 = 0.25;
pub const ominous_armored_chance: f32 = standard_armored_chance * 2.0; // 0.50 (doubled!)

pub const ominous_hazard_interval: f32 = 8.0; // Periodic projectile/potion hazards every 8.0s
pub const ominous_key_drop_probability: f32 = 0.30; // 30% probability
pub const standard_key_drop_probability: f32 = 0.50; // standard 50% trial key

pub const SpawnerHazard = enum(u8) {
    lingering_poison_potion = 0,
    lingering_slowness_potion = 1,
    lingering_weakness_potion = 2,
    wind_charge_projectile = 3,
    fire_charge_projectile = 4,

    pub fn name(self: SpawnerHazard) []const u8 {
        return switch (self) {
            .lingering_poison_potion => "Lingering Potion of Poison",
            .lingering_slowness_potion => "Lingering Potion of Slowness",
            .lingering_weakness_potion => "Lingering Potion of Weakness",
            .wind_charge_projectile => "Wind Charge",
            .fire_charge_projectile => "Fire Charge",
        };
    }
};

pub const KeyType = enum(u8) {
    standard_trial_key = 0,
    ominous_trial_key = 1,

    pub fn tag(self: KeyType) u16 {
        return switch (self) {
            .standard_trial_key => TrialKeyTag,
            .ominous_trial_key => OminousTrialKeyTag,
        };
    }

    pub fn name(self: KeyType) []const u8 {
        return switch (self) {
            .standard_trial_key => "Trial Key",
            .ominous_trial_key => "Ominous Trial Key",
        };
    }
};

pub const SpawnerState = enum(u8) {
    inactive = 0,
    active = 1,
    waiting_for_reward = 2,
    cooldown = 3,
};

pub fn getArmoredEquipmentOdds(is_ominous: bool) f32 {
    return if (is_ominous) ominous_armored_chance else standard_armored_chance;
}

pub fn rollArmoredEquipment(is_ominous: bool, roll: f32) bool {
    return roll < getArmoredEquipmentOdds(is_ominous);
}

pub fn rollKeyDrop(is_ominous: bool, roll: f32) ?KeyType {
    if (is_ominous) {
        if (roll < ominous_key_drop_probability) {
            return .ominous_trial_key;
        }
        return null;
    } else {
        if (roll < standard_key_drop_probability) {
            return .standard_trial_key;
        }
        return null;
    }
}

pub const OminousTrialSpawner = struct {
    pos: [3]f32 = .{ 0.0, 0.0, 0.0 },
    is_ominous: bool = false,
    state: SpawnerState = .inactive,
    hazard_timer: f32 = ominous_hazard_interval,
    hazard_cycle: u32 = 0,
    active_mobs_remaining: u8 = 0,
    total_mobs_spawned: u8 = 0,
    cooldown_timer: f32 = 0.0,

    pub fn init(x: f32, y: f32, z: f32, ominous: bool) OminousTrialSpawner {
        return .{
            .pos = .{ x, y, z },
            .is_ominous = ominous,
            .state = .inactive,
            .hazard_timer = ominous_hazard_interval,
            .hazard_cycle = 0,
            .active_mobs_remaining = 0,
            .total_mobs_spawned = 0,
            .cooldown_timer = 0.0,
        };
    }

    /// Upgrades a normal Trial Spawner into Ominous mode.
    /// Returns true if newly upgraded, false if already ominous.
    pub fn upgradeToOminous(self: *OminousTrialSpawner) bool {
        if (self.is_ominous) return false;
        self.is_ominous = true;
        self.hazard_timer = ominous_hazard_interval;
        return true;
    }

    pub fn activate(self: *OminousTrialSpawner, mob_count: u8) void {
        self.state = .active;
        self.active_mobs_remaining = mob_count;
        self.total_mobs_spawned = mob_count;
        self.hazard_timer = ominous_hazard_interval;
    }

    /// Ticks the hazard timer. If active in Ominous mode, emits a projectile/potion hazard
    /// every 8.0s and resets the hazard interval.
    pub fn tickHazardTimer(self: *OminousTrialSpawner, dt: f32) ?SpawnerHazard {
        if (!self.is_ominous or self.state != .active) return null;
        self.hazard_timer -= dt;
        if (self.hazard_timer <= 0.0) {
            self.hazard_timer = ominous_hazard_interval;
            const hazard: SpawnerHazard = @enumFromInt(self.hazard_cycle % 5);
            self.hazard_cycle +%= 1;
            return hazard;
        }
        return null;
    }

    pub fn onMobDefeated(self: *OminousTrialSpawner) void {
        if (self.active_mobs_remaining > 0) {
            self.active_mobs_remaining -= 1;
            if (self.active_mobs_remaining == 0) {
                self.state = .waiting_for_reward;
            }
        }
    }

    /// Complete trial and roll for key ejection (30% probability of Ominous Trial Key).
    pub fn completeAndEjectKey(self: *OminousTrialSpawner, roll: f32) ?KeyType {
        if (self.state != .waiting_for_reward) return null;
        self.state = .cooldown;
        self.cooldown_timer = 1800.0; // 30 minutes cooldown
        return rollKeyDrop(self.is_ominous, roll);
    }
};

// ============================================================================
// 4. Ominous Vault & High-Tier Loot Table
// ============================================================================

pub const OminousLootResult = struct {
    output_tag: u16,
    output_count: u8,
    name: []const u8,
};

/// High-tier Ominous Vault loot table:
/// - Heavy Core
/// - Enchanted Golden Apple
/// - Wind Burst III Book
/// - Flow Banner Pattern
/// - Bolt Banner Pattern
/// - Diamond Block
pub fn ominousVaultLootForRoll(roll: u8) OminousLootResult {
    return switch (roll % 6) {
        0 => .{ .output_tag = HeavyCoreTag, .output_count = 1, .name = "Heavy Core" },
        1 => .{ .output_tag = EnchantedGoldenAppleTag, .output_count = 1, .name = "Enchanted Golden Apple" },
        2 => .{ .output_tag = WindBurstBookTag, .output_count = 1, .name = "Wind Burst III Enchanted Book" },
        3 => .{ .output_tag = FlowBannerPatternTag, .output_count = 1, .name = "Flow Banner Pattern" },
        4 => .{ .output_tag = BoltBannerPatternTag, .output_count = 1, .name = "Bolt Banner Pattern" },
        else => .{ .output_tag = DiamondBlockTag, .output_count = 1, .name = "Block of Diamond" },
    };
}

/// Compatibility result struct for autocrafter / main loop dispensing.
pub const AutoCraftResult = struct {
    output_tag: u16,
    output_count: u8,
};

pub fn ominousVaultAutoCraftResult(roll: u8) AutoCraftResult {
    const l = ominousVaultLootForRoll(roll);
    return .{ .output_tag = l.output_tag, .output_count = l.output_count };
}

pub fn canUnlockOminousVault(key_tag: u16) bool {
    return key_tag == OminousTrialKeyTag;
}

pub fn canUnlockStandardVault(key_tag: u16) bool {
    return key_tag == TrialKeyTag;
}

pub const VaultUnlockError = error{
    InvalidKey,
    AlreadyUnlocked,
};

pub const OminousVault = struct {
    pos: [3]i32 = .{ 0, 0, 0 },
    is_ominous: bool = true,
    unlocked: bool = false,

    pub fn init(x: i32, y: i32, z: i32) OminousVault {
        return .{
            .pos = .{ x, y, z },
            .is_ominous = true,
            .unlocked = false,
        };
    }

    /// Unlocks the vault exclusively with an Ominous Trial Key.
    /// Dispenses high-tier loot and marks the vault as permanently unlocked.
    pub fn tryUnlock(self: *OminousVault, key_tag: u16, roll: u8) VaultUnlockError!OminousLootResult {
        if (self.unlocked) return error.AlreadyUnlocked;
        if (!canUnlockOminousVault(key_tag)) return error.InvalidKey;
        self.unlocked = true;
        return ominousVaultLootForRoll(roll);
    }
};

// ============================================================================
// Unit Tests (22 Tests)
// ============================================================================

test "1. Bogged mob base stats vs standard skeleton" {
    const bogged = BoggedMob.init(0.0, 0.0, 0.0);
    try std.testing.expectEqual(@as(f32, 16.0), bogged.health);
    try std.testing.expectEqual(@as(f32, 16.0), bogged_max_health);
    try std.testing.expectEqual(@as(f32, 20.0), standard_skeleton_max_health);
    try std.testing.expect(bogged.health < standard_skeleton_max_health);
}

test "2. Bogged slower fire interval (3.5s vs 2.0s)" {
    try std.testing.expectEqual(@as(f32, 3.5), bogged_fire_interval);
    try std.testing.expectEqual(@as(f32, 2.0), standard_skeleton_fire_interval);
    const bogged = BoggedMob.init(1.0, 2.0, 3.0);
    try std.testing.expectEqual(@as(f32, 3.5), bogged.fire_interval);
}

test "3. Bogged fires Poison-tipped arrows (4.0s duration)" {
    var bogged = BoggedMob.init(0.0, 0.0, 0.0);
    try std.testing.expect(bogged.canFire());
    const arrow = bogged.fireArrow().?;
    try std.testing.expectEqual(@as(f32, 2.0), arrow.damage);
    try std.testing.expectEqual(@as(f32, 4.0), arrow.poison_duration);
    try std.testing.expectEqual(@as(f32, 3.5), bogged.shot_cooldown);
    try std.testing.expect(!bogged.canFire());
}

test "4. Bogged cooldown ticking and ready state" {
    var bogged = BoggedMob.init(0.0, 0.0, 0.0);
    _ = bogged.fireArrow();
    try std.testing.expect(!bogged.canFire());

    bogged.tick(2.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), bogged.shot_cooldown, 0.001);
    try std.testing.expect(!bogged.canFire());

    bogged.tick(2.0);
    try std.testing.expectEqual(@as(f32, 0.0), bogged.shot_cooldown);
    try std.testing.expect(bogged.canFire());
}

test "5. Shearing a Bogged drops 2 Mushrooms once per Bogged" {
    var bogged = BoggedMob.init(5.0, 10.0, 5.0);
    try std.testing.expect(!bogged.sheared);

    const drop1 = shearBogged(&bogged);
    try std.testing.expectEqual(@as(u8, 2), drop1);
    try std.testing.expect(bogged.sheared);

    // Second shear attempt returns 0
    const drop2 = shearBogged(&bogged);
    try std.testing.expectEqual(@as(u8, 0), drop2);

    // Method syntax test
    var bogged2 = BoggedMob.init(0.0, 0.0, 0.0);
    try std.testing.expectEqual(@as(u8, 2), bogged2.shear());
    try std.testing.expectEqual(@as(u8, 0), bogged2.shear());
}

test "6. Shearing Bogged drops red or brown mushroom varieties" {
    var b1 = BoggedMob.init(0.0, 0.0, 0.0);
    const drop_even = shearBoggedWithTypes(&b1, 0).?;
    try std.testing.expectEqual(@as(u8, 2), drop_even.count);
    try std.testing.expectEqual(MushroomType.red, drop_even.mushrooms[0]);
    try std.testing.expectEqual(MushroomType.brown, drop_even.mushrooms[1]);

    var b2 = BoggedMob.init(0.0, 0.0, 0.0);
    const drop_odd = shearBoggedWithTypes(&b2, 3).?;
    try std.testing.expectEqual(@as(u8, 2), drop_odd.count);
    try std.testing.expectEqual(MushroomType.brown, drop_odd.mushrooms[0]);
    try std.testing.expectEqual(MushroomType.red, drop_odd.mushrooms[1]);

    // Shearing already sheared returns null
    try std.testing.expect(shearBoggedWithTypes(&b1, 0) == null);
}

test "7. Bogged damage and death tracking" {
    var bogged = BoggedMob.init(0.0, 0.0, 0.0);
    try std.testing.expect(bogged.isAlive());

    bogged.takeDamage(10.0);
    try std.testing.expectEqual(@as(f32, 6.0), bogged.health);
    try std.testing.expect(bogged.isAlive());

    bogged.takeDamage(10.0);
    try std.testing.expectEqual(@as(f32, 0.0), bogged.health);
    try std.testing.expect(!bogged.isAlive());
    try std.testing.expect(!bogged.canFire());
    try std.testing.expect(bogged.fireArrow() == null);
}

test "8. Ominous Bottle amplifier tiers I to V clamping" {
    const b1 = OminousBottle.init(1);
    try std.testing.expectEqual(@as(u8, 1), b1.amplifier);

    const b5 = OminousBottle.init(5);
    try std.testing.expectEqual(@as(u8, 5), b5.amplifier);

    // Clamping lower bound
    const b0 = OminousBottle.init(0);
    try std.testing.expectEqual(@as(u8, 1), b0.amplifier);

    // Clamping upper bound
    const b99 = OminousBottle.init(99);
    try std.testing.expectEqual(@as(u8, 5), b99.amplifier);
}

test "9. Ominous Bottle consumption grants Bad Omen (6000.0s)" {
    const bottle = OminousBottle.init(3);
    const bad_omen = bottle.consume();
    try std.testing.expectEqual(@as(u8, 3), bad_omen.amplifier);
    try std.testing.expectEqual(@as(f32, 6000.0), bad_omen.duration);
    try std.testing.expect(bad_omen.active);
}

test "10. Bad Omen timer ticks down and expires" {
    var bad_omen = BadOmenEffect.init(1);
    bad_omen.tick(1000.0);
    try std.testing.expectApproxEqAbs(@as(f32, 5000.0), bad_omen.duration, 0.01);
    try std.testing.expect(bad_omen.active);

    bad_omen.tick(5000.0);
    try std.testing.expectEqual(@as(f32, 0.0), bad_omen.duration);
    try std.testing.expect(!bad_omen.active);
}

test "11. Trial Spawner 14.0 block detection radius" {
    // Exactly at origin
    try std.testing.expect(isWithinTrialSpawnerRadius(0.0, 0.0, 0.0, 0.0, 0.0, 0.0));
    // Inside 10 blocks
    try std.testing.expect(isWithinTrialSpawnerRadius(10.0, 0.0, 0.0, 0.0, 0.0, 0.0));
    // Exactly at boundary 14 blocks
    try std.testing.expect(isWithinTrialSpawnerRadius(14.0, 0.0, 0.0, 0.0, 0.0, 0.0));
    // 3D vector (8, 8, 8) -> 64*3 = 192 <= 196 (inside)
    try std.testing.expect(isWithinTrialSpawnerRadius(8.0, 8.0, 8.0, 0.0, 0.0, 0.0));
    // Just outside 14.1 blocks
    try std.testing.expect(!isWithinTrialSpawnerRadius(14.1, 0.0, 0.0, 0.0, 0.0, 0.0));
    // Far outside
    try std.testing.expect(!isWithinTrialSpawnerRadius(25.0, 10.0, 25.0, 0.0, 0.0, 0.0));
}

test "12. Bad Omen converts to Trial Omen on entering Trial Spawner radius" {
    var bad_omen = BadOmenEffect.init(2);
    // Spawner at (100, 64, 100), player at (120, 64, 100) -> 20 blocks away (outside)
    const result_outside = tryTriggerTrialOmen(&bad_omen, 120.0, 64.0, 100.0, 100.0, 64.0, 100.0);
    try std.testing.expect(result_outside == null);
    try std.testing.expect(bad_omen.active);

    // Player enters radius at (110, 64, 100) -> 10 blocks away (inside)
    const result_inside = tryTriggerTrialOmen(&bad_omen, 110.0, 64.0, 100.0, 100.0, 64.0, 100.0).?;
    try std.testing.expect(!bad_omen.active);
    try std.testing.expectEqual(@as(f32, 0.0), bad_omen.duration);

    try std.testing.expect(result_inside.active);
    try std.testing.expectEqual(@as(u8, 2), result_inside.amplifier);
    // 900.0s * 2 = 1800.0s
    try std.testing.expectEqual(@as(f32, 1800.0), result_inside.duration);
    try std.testing.expectEqual(@as(f32, 1800.0), result_inside.max_duration);
}

test "13. Trial Omen duration scales by 900.0s * amplifier" {
    try std.testing.expectEqual(@as(f32, 900.0), calculateTrialOmenDuration(1));
    try std.testing.expectEqual(@as(f32, 1800.0), calculateTrialOmenDuration(2));
    try std.testing.expectEqual(@as(f32, 2700.0), calculateTrialOmenDuration(3));
    try std.testing.expectEqual(@as(f32, 3600.0), calculateTrialOmenDuration(4));
    try std.testing.expectEqual(@as(f32, 4500.0), calculateTrialOmenDuration(5));
}

test "14. Ominous Trial Spawner upgrade from normal mode" {
    var spawner = OminousTrialSpawner.init(0.0, 60.0, 0.0, false);
    try std.testing.expect(!spawner.is_ominous);

    const upgraded = spawner.upgradeToOminous();
    try std.testing.expect(upgraded);
    try std.testing.expect(spawner.is_ominous);
    try std.testing.expectEqual(@as(f32, 8.0), spawner.hazard_timer);

    // Second upgrade attempt is a no-op
    try std.testing.expect(!spawner.upgradeToOminous());
}

test "15. Armored mob equipment odds doubled in Ominous mode" {
    try std.testing.expectEqual(@as(f32, 0.25), standard_armored_chance);
    try std.testing.expectEqual(@as(f32, 0.50), ominous_armored_chance);
    try std.testing.expectEqual(@as(f32, 0.25), getArmoredEquipmentOdds(false));
    try std.testing.expectEqual(@as(f32, 0.50), getArmoredEquipmentOdds(true));

    // Roll checks
    try std.testing.expect(rollArmoredEquipment(false, 0.20));
    try std.testing.expect(!rollArmoredEquipment(false, 0.30));

    try std.testing.expect(rollArmoredEquipment(true, 0.45));
    try std.testing.expect(!rollArmoredEquipment(true, 0.55));
}

test "16. Ominous Spawner periodic hazard timer (8.0s)" {
    var spawner = OminousTrialSpawner.init(0.0, 60.0, 0.0, true);
    spawner.activate(4);
    try std.testing.expectEqual(SpawnerState.active, spawner.state);

    // Tick 5.0s: no hazard yet
    const h1 = spawner.tickHazardTimer(5.0);
    try std.testing.expect(h1 == null);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), spawner.hazard_timer, 0.001);

    // Tick 3.0s: hazard triggered, timer resets to 8.0s
    const h2 = spawner.tickHazardTimer(3.0);
    try std.testing.expect(h2 != null);
    try std.testing.expectEqual(SpawnerHazard.lingering_poison_potion, h2.?);
    try std.testing.expectEqual(@as(f32, 8.0), spawner.hazard_timer);

    // Inactive spawner does not emit hazards
    var inactive_spawner = OminousTrialSpawner.init(0.0, 60.0, 0.0, true);
    try std.testing.expect(inactive_spawner.tickHazardTimer(10.0) == null);

    // Normal (non-ominous) spawner does not emit hazards
    var normal_spawner = OminousTrialSpawner.init(0.0, 60.0, 0.0, false);
    normal_spawner.activate(4);
    try std.testing.expect(normal_spawner.tickHazardTimer(10.0) == null);
}

test "17. Spawner hazard variety sequence" {
    var spawner = OminousTrialSpawner.init(0.0, 60.0, 0.0, true);
    spawner.activate(10);

    const hazards = [_]SpawnerHazard{
        .lingering_poison_potion,
        .lingering_slowness_potion,
        .lingering_weakness_potion,
        .wind_charge_projectile,
        .fire_charge_projectile,
    };

    for (hazards) |expected| {
        const h = spawner.tickHazardTimer(8.0).?;
        try std.testing.expectEqual(expected, h);
    }
}

test "18. Ominous Trial Key completion drop probability (30%)" {
    try std.testing.expectEqual(@as(f32, 0.30), ominous_key_drop_probability);

    // Inside 30% -> drops ominous key
    try std.testing.expectEqual(KeyType.ominous_trial_key, rollKeyDrop(true, 0.10).?);
    try std.testing.expectEqual(KeyType.ominous_trial_key, rollKeyDrop(true, 0.29).?);

    // Outside 30% -> drops null
    try std.testing.expect(rollKeyDrop(true, 0.30) == null);
    try std.testing.expect(rollKeyDrop(true, 0.75) == null);

    // Standard spawner drops standard key at 50%
    try std.testing.expectEqual(KeyType.standard_trial_key, rollKeyDrop(false, 0.49).?);
    try std.testing.expect(rollKeyDrop(false, 0.51) == null);
}

test "19. Spawner mob wave completion and reward dispensing flow" {
    var spawner = OminousTrialSpawner.init(10.0, 20.0, 30.0, true);
    spawner.activate(2);
    try std.testing.expectEqual(@as(u8, 2), spawner.active_mobs_remaining);

    // Defeating 1 mob
    spawner.onMobDefeated();
    try std.testing.expectEqual(@as(u8, 1), spawner.active_mobs_remaining);
    try std.testing.expectEqual(SpawnerState.active, spawner.state);

    // Defeating final mob moves to waiting_for_reward
    spawner.onMobDefeated();
    try std.testing.expectEqual(@as(u8, 0), spawner.active_mobs_remaining);
    try std.testing.expectEqual(SpawnerState.waiting_for_reward, spawner.state);

    // Eject key with successful roll
    const key = spawner.completeAndEjectKey(0.15);
    try std.testing.expectEqual(KeyType.ominous_trial_key, key.?);
    try std.testing.expectEqual(SpawnerState.cooldown, spawner.state);
}

test "20. Ominous Vault requires exclusively Ominous Trial Key" {
    try std.testing.expect(canUnlockOminousVault(OminousTrialKeyTag));
    try std.testing.expect(!canUnlockOminousVault(TrialKeyTag));
    try std.testing.expect(!canUnlockOminousVault(HeavyCoreTag));
    try std.testing.expect(!canUnlockOminousVault(0));

    // Standard Vault accepts standard key and rejects Ominous key
    try std.testing.expect(canUnlockStandardVault(TrialKeyTag));
    try std.testing.expect(!canUnlockStandardVault(OminousTrialKeyTag));
}

test "21. Ominous Vault high-tier loot table distribution" {
    const l0 = ominousVaultLootForRoll(0);
    try std.testing.expectEqual(HeavyCoreTag, l0.output_tag);
    try std.testing.expectEqual(@as(u8, 1), l0.output_count);

    const l1 = ominousVaultLootForRoll(1);
    try std.testing.expectEqual(EnchantedGoldenAppleTag, l1.output_tag);
    try std.testing.expectEqual(@as(u8, 1), l1.output_count);

    const l2 = ominousVaultLootForRoll(2);
    try std.testing.expectEqual(WindBurstBookTag, l2.output_tag);
    try std.testing.expectEqual(@as(u8, 1), l2.output_count);

    const l3 = ominousVaultLootForRoll(3);
    try std.testing.expectEqual(FlowBannerPatternTag, l3.output_tag);
    try std.testing.expectEqual(@as(u8, 1), l3.output_count);

    const l4 = ominousVaultLootForRoll(4);
    try std.testing.expectEqual(BoltBannerPatternTag, l4.output_tag);
    try std.testing.expectEqual(@as(u8, 1), l4.output_count);

    const l5 = ominousVaultLootForRoll(5);
    try std.testing.expectEqual(DiamondBlockTag, l5.output_tag);
    try std.testing.expectEqual(@as(u8, 1), l5.output_count);

    // Modulo 6 wrapping
    const l6 = ominousVaultLootForRoll(6);
    try std.testing.expectEqual(HeavyCoreTag, l6.output_tag);

    const l11 = ominousVaultLootForRoll(11);
    try std.testing.expectEqual(DiamondBlockTag, l11.output_tag);
}

test "22. Ominous Vault unlock flow and single-use state" {
    var vault = OminousVault.init(10, 20, 30);
    try std.testing.expect(!vault.unlocked);

    // Attempting unlock with standard Trial Key fails with InvalidKey
    try std.testing.expectError(error.InvalidKey, vault.tryUnlock(TrialKeyTag, 0));
    try std.testing.expect(!vault.unlocked);

    // Unlocking with Ominous Trial Key succeeds
    const reward = try vault.tryUnlock(OminousTrialKeyTag, 2);
    try std.testing.expect(vault.unlocked);
    try std.testing.expectEqual(WindBurstBookTag, reward.output_tag);

    // Second unlock attempt returns AlreadyUnlocked
    try std.testing.expectError(error.AlreadyUnlocked, vault.tryUnlock(OminousTrialKeyTag, 0));
}
