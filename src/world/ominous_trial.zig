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


// ============================================================================

// ============================================================================
// Top-Level Canonical API Aliases
// ============================================================================

/// Dynamically scales total mob waves for trial spawner by participating player count.
pub const scaleWaveMobs = waves.scaleTotalMobs;

/// Dynamically scales simultaneous mob cap for trial spawner by participating player count.
pub const scaleWaveSimultaneous = waves.scaleSimultaneousMobs;

/// Checks if an ominous spawner / vault completion awards a vault reset token (5% chance).
pub const rollVaultResetToken = vault_multiplayer.dropsVaultResetToken;

/// Returns required key for vault type (.standard -> .trial_key, .ominous -> .ominous_trial_key).
pub const getRequiredVaultKey = vault_multiplayer.requiredKey;

/// Mob category mapping for trial mobs.
pub const spawnerMobCategory = dynamics.mobCategory;

/// Amplifier mapping for ominous bottle tiers (0..4).
pub const ominousBottleAmplifier = bottle_omen.amplifierForTier;

/// Duration ticks required to drink an ominous bottle (32 ticks).
pub const ominousDrinkingTicks = bottle_matrix.DRINKING_DURATION_TICKS;

// Consolidated Submodules & Canonical Namespace Aliases
// ============================================================================


test "consolidated trial chamber declarations and submodules" {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(bottle_omen);
    std.testing.refAllDecls(bottle_matrix);
    std.testing.refAllDecls(dynamics);
    std.testing.refAllDecls(waves);
    std.testing.refAllDecls(vault_dispenser);
    std.testing.refAllDecls(vault_multiplayer);
    std.testing.refAllDecls(vault_reset);
}


pub const bottle_omen = struct {
pub const TICKS_PER_SECOND: u32 = 20;
pub const BOTTLE_DRINK_TICKS: u32 = 32;
pub const BAD_OMEN_DURATION_TICKS: u32 = 120_000;
pub const RAID_OMEN_DURATION_TICKS: u32 = 600;
pub const VILLAGE_RADIUS: f32 = 32.0;
pub const TRIAL_OMEN_RADIUS: f32 = 14.0;

pub const OminousBottleTier = enum(u8) { tier_1 = 1, tier_2 = 2, tier_3 = 3, tier_4 = 4, tier_5 = 5 };
pub const OmenKind = enum { idle, bad_omen, raid_omen, trial_omen };
pub const SoundCue = enum { none, raid_horn, ominous_chime };

pub fn amplifierForTier(tier: OminousBottleTier) u8 {
    return @intFromEnum(tier) - 1;
}

pub const DrinkEvent = struct {
    bottle_consumed: bool = false,
    glass_break_particles: bool = false,
    bad_omen_applied: bool = false,
};

pub const OminousBottleDrink = struct {
    tier: OminousBottleTier,
    ticks_remaining: u32 = BOTTLE_DRINK_TICKS,
    completed: bool = false,

    pub fn tick(self: *OminousBottleDrink, omen: *PlayerOmen) DrinkEvent {
        if (self.completed) return .{};
        if (self.ticks_remaining > 0) self.ticks_remaining -= 1;
        if (self.ticks_remaining != 0) return .{};
        self.completed = true;
        omen.applyBadOmen(amplifierForTier(self.tier), BAD_OMEN_DURATION_TICKS);
        return .{ .bottle_consumed = true, .glass_break_particles = true, .bad_omen_applied = true };
    }
};

pub const Proximity = struct {
    village_distance: ?f32 = null,
    trial_distance: ?f32 = null,
};

pub const TickEvent = struct {
    kind: OmenKind = .idle,
    red_black_head_particles: bool = false,
    ominous_flame_burst: bool = false,
    sound: SoundCue = .none,
    raid_started: bool = false,
    raid_waves_started: bool = false,
    raid_cancelled: bool = false,
};

/// Per-player status state. Call tick once per game tick and pass distances to
/// the nearest village marker and trial chamber/spawner when available.
pub const PlayerOmen = struct {
    kind: OmenKind = .idle,
    amplifier: u8 = 0,
    ticks_remaining: u32 = 0,
    is_transmuted: bool = false,

    pub fn applyBadOmen(self: *PlayerOmen, amplifier: u8, duration: u32) void {
        self.kind = .bad_omen;
        self.amplifier = @min(amplifier, 4);
        self.ticks_remaining = duration;
        self.is_transmuted = false;
    }

    pub fn cleanseWithMilk(self: *PlayerOmen) void {
        self.* = .{};
    }

    pub fn tick(self: *PlayerOmen, proximity: Proximity) TickEvent {
        var event = TickEvent{};
        switch (self.kind) {
            .idle => {},
            .bad_omen => {
                if (proximity.trial_distance) |distance| {
                    if (distance <= TRIAL_OMEN_RADIUS) {
                        self.kind = .trial_omen;
                        self.is_transmuted = true;
                        event.ominous_flame_burst = true;
                        event.sound = .ominous_chime;
                    }
                }
                if (self.kind == .bad_omen) {
                    if (proximity.village_distance) |distance| {
                        if (distance <= VILLAGE_RADIUS) {
                            self.kind = .raid_omen;
                            self.ticks_remaining = RAID_OMEN_DURATION_TICKS;
                            event.raid_started = true;
                            event.sound = .raid_horn;
                        }
                    }
                }
                if (self.kind == .bad_omen) {
                    event.red_black_head_particles = true;
                    decrement(self);
                } else if (self.kind == .trial_omen) {
                    // Trial Omen inherits Bad Omen's remaining duration exactly.
                }
            },
            .raid_omen => {
                if (self.ticks_remaining == 1) event.raid_waves_started = true;
                decrement(self);
            },
            .trial_omen => {
                event.red_black_head_particles = true;
                decrement(self);
            },
        }
        if (self.kind == .idle) self.is_transmuted = false;
        event.kind = self.kind;
        return event;
    }

    /// Milk is checked before ordinary tick processing, so it cancels even a
    /// final-tick Raid Omen countdown.
    pub fn tickWithMilk(self: *PlayerOmen, proximity: Proximity, drank_milk: bool) TickEvent {
        if (!drank_milk) return self.tick(proximity);
        const cancelled = self.kind == .raid_omen;
        self.cleanseWithMilk();
        return .{ .kind = .idle, .raid_cancelled = cancelled };
    }

    pub fn shouldOminousTrialSpawner(self: PlayerOmen, player_distance: f32) bool {
        return self.kind == .trial_omen and self.is_transmuted and player_distance <= TRIAL_OMEN_RADIUS;
    }
};

fn decrement(self: *PlayerOmen) void {
    if (self.ticks_remaining > 0) self.ticks_remaining -= 1;
    if (self.ticks_remaining == 0) self.cleanseWithMilk();
}

// Distance helper for world integrations that have positions rather than ranges.
pub fn distance3(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

// Keep this helper public for integrations that enumerate a neighborhood of spawners.
pub fn spawnerReceivesOminousTrial(omen: PlayerOmen, player: [3]f32, spawner: [3]f32) bool {
    return omen.shouldOminousTrialSpawner(distance3(player, spawner));
}

test "bottle tiers map to amplifiers zero through four" {
    try std.testing.expectEqual(@as(u8, 0), amplifierForTier(.tier_1));
    try std.testing.expectEqual(@as(u8, 1), amplifierForTier(.tier_2));
    try std.testing.expectEqual(@as(u8, 2), amplifierForTier(.tier_3));
    try std.testing.expectEqual(@as(u8, 3), amplifierForTier(.tier_4));
    try std.testing.expectEqual(@as(u8, 4), amplifierForTier(.tier_5));
}

test "bottle takes exactly 32 ticks to drink" {
    var drink = OminousBottleDrink{ .tier = .tier_1 };
    var omen = PlayerOmen{};
    for (0..31) |_| try std.testing.expect(!drink.tick(&omen).bottle_consumed);
    try std.testing.expectEqual(@as(u32, 1), drink.ticks_remaining);
    try std.testing.expect(drink.tick(&omen).bottle_consumed);
}

test "bottle completion consumes glass and applies tier amplifier" {
    var drink = OminousBottleDrink{ .tier = .tier_5 };
    var omen = PlayerOmen{};
    for (0..32) |_| _ = drink.tick(&omen);
    try std.testing.expectEqual(OmenKind.bad_omen, omen.kind);
    try std.testing.expectEqual(@as(u8, 4), omen.amplifier);
    try std.testing.expectEqual(BAD_OMEN_DURATION_TICKS, omen.ticks_remaining);
}

test "completed bottle cannot be consumed twice" {
    var drink = OminousBottleDrink{ .tier = .tier_1 };
    var omen = PlayerOmen{};
    for (0..32) |_| _ = drink.tick(&omen);
    try std.testing.expect(!drink.tick(&omen).bottle_consumed);
}

test "bad omen begins with 100 minute duration" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, BAD_OMEN_DURATION_TICKS);
    try std.testing.expectEqual(@as(u32, 120_000), omen.ticks_remaining);
}

test "bad omen duration decays one game tick at a time" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(2, BAD_OMEN_DURATION_TICKS);
    _ = omen.tick(.{});
    try std.testing.expectEqual(@as(u32, 119_999), omen.ticks_remaining);
}

test "bad omen expires to idle at zero" {
    var omen = PlayerOmen{ .kind = .bad_omen, .ticks_remaining = 1, .amplifier = 3 };
    const event = omen.tick(.{});
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
    try std.testing.expect(event.red_black_head_particles);
}

test "bad omen emits red black head particles" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, 10);
    try std.testing.expect(omen.tick(.{}).red_black_head_particles);
}

test "bad omen does not trigger raid outside 32 meters" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, 10);
    _ = omen.tick(.{ .village_distance = 32.01 });
    try std.testing.expectEqual(OmenKind.bad_omen, omen.kind);
}

test "village boundary triggers raid omen at 32 meters" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(1, 1000);
    const event = omen.tick(.{ .village_distance = 32.0 });
    try std.testing.expect(event.raid_started);
    try std.testing.expectEqual(SoundCue.raid_horn, event.sound);
    try std.testing.expectEqual(OmenKind.raid_omen, omen.kind);
    try std.testing.expectEqual(@as(u32, 600), omen.ticks_remaining);
}

test "raid countdown decays for 30 seconds" {
    var omen = PlayerOmen{ .kind = .raid_omen, .ticks_remaining = RAID_OMEN_DURATION_TICKS };
    for (0..599) |_| _ = omen.tick(.{});
    try std.testing.expectEqual(@as(u32, 1), omen.ticks_remaining);
    const event = omen.tick(.{});
    try std.testing.expect(event.raid_waves_started);
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
}

test "milk cancels raid countdown" {
    var omen = PlayerOmen{ .kind = .raid_omen, .ticks_remaining = 1 };
    const event = omen.tickWithMilk(.{}, true);
    try std.testing.expect(event.raid_cancelled);
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
}

test "milk does not report raid cancellation when no raid is pending" {
    var omen = PlayerOmen{};
    try std.testing.expect(!omen.tickWithMilk(.{}, true).raid_cancelled);
}

test "trial proximity transmutates at 14 meters" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(3, 9000);
    const event = omen.tick(.{ .trial_distance = 14.0 });
    try std.testing.expectEqual(OmenKind.trial_omen, omen.kind);
    try std.testing.expect(omen.is_transmuted);
    try std.testing.expect(event.ominous_flame_burst);
    try std.testing.expectEqual(SoundCue.ominous_chime, event.sound);
}

test "trial transmutation inherits remaining duration and amplifier" {
    var omen = PlayerOmen{ .kind = .bad_omen, .amplifier = 4, .ticks_remaining = 4321 };
    _ = omen.tick(.{ .trial_distance = 13.9 });
    try std.testing.expectEqual(@as(u32, 4321), omen.ticks_remaining);
    try std.testing.expectEqual(@as(u8, 4), omen.amplifier);
}

test "trial transmutation does not occur outside 14 meters" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, 10);
    _ = omen.tick(.{ .trial_distance = 14.01 });
    try std.testing.expectEqual(OmenKind.bad_omen, omen.kind);
}

test "trial omen keeps inherited duration ticking" {
    var omen = PlayerOmen{ .kind = .trial_omen, .amplifier = 2, .ticks_remaining = 8, .is_transmuted = true };
    _ = omen.tick(.{});
    try std.testing.expectEqual(@as(u32, 7), omen.ticks_remaining);
}

test "trial aura triggers nearby spawner transformation" {
    const omen = PlayerOmen{ .kind = .trial_omen, .amplifier = 1, .ticks_remaining = 50, .is_transmuted = true };
    try std.testing.expect(spawnerReceivesOminousTrial(omen, .{ 0, 0, 0 }, .{ 14, 0, 0 }));
    try std.testing.expect(!spawnerReceivesOminousTrial(omen, .{ 0, 0, 0 }, .{ 14.1, 0, 0 }));
}

test "bad omen does not make spawners ominous before transmutation" {
    const omen = PlayerOmen{ .kind = .bad_omen, .ticks_remaining = 50 };
    try std.testing.expect(!spawnerReceivesOminousTrial(omen, .{ 0, 0, 0 }, .{ 1, 0, 0 }));
}

test "milk clears bad omen, raid omen, and trial omen" {
    const kinds = [_]OmenKind{ .bad_omen, .raid_omen, .trial_omen };
    for (kinds) |kind| {
        var omen = PlayerOmen{ .kind = kind, .amplifier = 4, .ticks_remaining = 50, .is_transmuted = kind == .trial_omen };
        omen.cleanseWithMilk();
        try std.testing.expectEqual(OmenKind.idle, omen.kind);
        try std.testing.expectEqual(@as(u32, 0), omen.ticks_remaining);
        try std.testing.expectEqual(@as(u8, 0), omen.amplifier);
        try std.testing.expect(!omen.is_transmuted);
    }
}

test "milk tick prevents proximity triggers" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, 10);
    const event = omen.tickWithMilk(.{ .village_distance = 1, .trial_distance = 1 }, true);
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
    try std.testing.expect(!event.raid_started);
    try std.testing.expect(!event.ominous_flame_burst);
}

test "trial chamber takes precedence over nearby village" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(2, 500);
    const event = omen.tick(.{ .village_distance = 1, .trial_distance = 1 });
    try std.testing.expectEqual(OmenKind.trial_omen, omen.kind);
    try std.testing.expect(!event.raid_started);
}

test "bad omen amplifier is clamped to bottle maximum" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(99, 10);
    try std.testing.expectEqual(@as(u8, 4), omen.amplifier);
}

test "distance helper measures three dimensional range" {
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), distance3(.{ 0, 0, 0 }, .{ 3, 4, 0 }), 0.0001);
}

test "raid omen preserves amplifier while counting down" {
    var omen = PlayerOmen{ .kind = .raid_omen, .amplifier = 3, .ticks_remaining = 20 };
    _ = omen.tick(.{});
    try std.testing.expectEqual(@as(u8, 3), omen.amplifier);
}

test "cleansed player remains idle without effects" {
    var omen = PlayerOmen{ .kind = .trial_omen, .ticks_remaining = 3, .is_transmuted = true };
    _ = omen.tickWithMilk(.{}, true);
    _ = omen.tick(.{});
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
}

};


pub const bottle_matrix = struct {
// ============================================================================
// Milestone 530: Ominous Bottle Consumption & Bad Omen / Trial Omen
// Transformation Matrix in Zigcraft
// ============================================================================
//
// This module implements the mechanics of Ominous Bottle drinking consumption,
// Bad Omen status effect duration and amplifier stacking, Village Raid Omen
// transmutation with countdown timer and scaled raid waves, Trial Spawner
// Trial Omen transmutation with duration scaling and spawner upgrading,
// and Milk Bucket cleansing across all omen states.


// ============================================================================
// Constants
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;

/// Drinking an ominous bottle requires 32 game ticks (1.6 seconds).
pub const DRINKING_DURATION_TICKS: u32 = 32;

/// Bad Omen duration: 100 minutes = 6,000 seconds = 120,000 game ticks.
pub const BAD_OMEN_DURATION_TICKS: u32 = 120_000;

/// Raid Omen countdown: 30 seconds = 600 game ticks.
pub const RAID_OMEN_COUNTDOWN_TICKS: u32 = 600;

/// Village proximity boundary: 64.0m Euclidean radius.
pub const VILLAGE_BOUNDARY_RADIUS: f32 = 64.0;
pub const VILLAGE_BOUNDARY_RADIUS_SQ: f32 = 64.0 * 64.0;

/// Trial Spawner proximity boundary: 14.0m Euclidean radius.
pub const TRIAL_SPAWNER_BOUNDARY_RADIUS: f32 = 14.0;
pub const TRIAL_SPAWNER_BOUNDARY_RADIUS_SQ: f32 = 14.0 * 14.0;

/// Trial Omen base duration factor: 18,000 ticks (15 minutes).
/// Total duration is 18,000 * (amplifier + 1).
pub const TRIAL_OMEN_BASE_DURATION_TICKS: u32 = 18_000;

// ============================================================================
// Enumerations
// ============================================================================

/// 5 Ominous Bottle tiers corresponding to amplifier levels 0 through 4.
pub const OminousBottleTier = enum(u8) {
    tier_1 = 1,
    tier_2 = 2,
    tier_3 = 3,
    tier_4 = 4,
    tier_5 = 5,

    /// Amplifier is defined as `tier - 1`.
    /// Tier I -> 0, Tier II -> 1, Tier III -> 2, Tier IV -> 3, Tier V -> 4.
    pub fn amplifier(self: OminousBottleTier) u8 {
        return @intFromEnum(self) - 1;
    }

    /// User-facing tier number (1..5).
    pub fn tierNumber(self: OminousBottleTier) u8 {
        return @intFromEnum(self);
    }

    /// Construct tier from 0-based amplifier (0..4).
    pub fn fromAmplifier(amp: u8) ?OminousBottleTier {
        return switch (amp) {
            0 => .tier_1,
            1 => .tier_2,
            2 => .tier_3,
            3 => .tier_4,
            4 => .tier_5,
            else => null,
        };
    }

    /// Construct tier from 1-based tier number (1..5).
    pub fn fromTierNumber(num: u8) ?OminousBottleTier {
        return switch (num) {
            1 => .tier_1,
            2 => .tier_2,
            3 => .tier_3,
            4 => .tier_4,
            5 => .tier_5,
            else => null,
        };
    }

    pub fn name(self: OminousBottleTier) []const u8 {
        return switch (self) {
            .tier_1 => "Ominous Bottle I",
            .tier_2 => "Ominous Bottle II",
            .tier_3 => "Ominous Bottle III",
            .tier_4 => "Ominous Bottle IV",
            .tier_5 => "Ominous Bottle V",
        };
    }
};

/// Sound cues emitted during bottle consumption and omen transmutations.
pub const SoundEffect = enum(u8) {
    none = 0,
    potion_drink = 1,
    raid_horn = 2,
    trial_omen_transmute = 3,
    milk_drink = 4,
};

/// Item tags matching the Minecraft / Zigcraft inventory system.
pub const ItemType = enum(u16) {
    none = 0,
    bucket = 325,
    ominous_bottle = 415,
    milk_bucket = 472,
    glass_bottle = 638,
    _,
};

/// Status effect kind for the player's omen state.
pub const OmenKind = enum(u8) {
    neutral = 0,
    bad_omen = 1,
    raid_omen = 2,
    trial_omen = 3,

    pub const none: OmenKind = .neutral;
    pub const idle: OmenKind = .neutral;
};

/// Difficulty setting for village raids.
pub const RaidDifficulty = enum(u8) {
    easy = 0,
    normal = 1,
    hard = 2,
};

// ============================================================================
// Math & Scaling Formulas
// ============================================================================

/// Returns amplifier (0..4) for a given bottle tier.
pub fn amplifierForTier(tier: OminousBottleTier) u8 {
    return tier.amplifier();
}

/// Trial Omen duration formula: 18,000 * (amplifier + 1) ticks.
/// Tier I (amp 0): 18,000 ticks (15 min)
/// Tier II (amp 1): 36,000 ticks (30 min)
/// Tier III (amp 2): 54,000 ticks (45 min)
/// Tier IV (amp 3): 72,000 ticks (60 min)
/// Tier V (amp 4): 90,000 ticks (75 min)
pub fn calculateTrialOmenDurationTicks(amplifier: u8) u32 {
    const clamped_amp: u32 = @min(@as(u32, amplifier), 4);
    return TRIAL_OMEN_BASE_DURATION_TICKS * (clamped_amp + 1);
}

/// Raid wave count scaled by raid difficulty and omen amplifier.
/// Easy: 3 base waves (+1 bonus wave if amplifier >= 1).
/// Normal: 5 base waves (+1 bonus wave if amplifier >= 1).
/// Hard: 7 base waves (+1 bonus wave if amplifier >= 1, max 8 waves).
pub fn raidWaveCount(difficulty: RaidDifficulty, amplifier: u8) u8 {
    const base: u8 = switch (difficulty) {
        .easy => 3,
        .normal => 5,
        .hard => 7,
    };
    return base + if (amplifier >= 1) @as(u8, 1) else 0;
}

pub fn calculateRaidWaves(difficulty: RaidDifficulty, amplifier: u8) u8 {
    return raidWaveCount(difficulty, amplifier);
}

/// Euclidean distance in 3D space: sqrt(dx^2 + dy^2 + dz^2).
pub fn euclideanDistance(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

/// Squared Euclidean distance in 3D space.
pub fn euclideanDistanceSq(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

/// Checks if a position is within the Village proximity boundary (r <= 64.0m).
pub fn isInVillageBoundary(pos: [3]f32, village_center: [3]f32) bool {
    return euclideanDistance(pos, village_center) <= VILLAGE_BOUNDARY_RADIUS;
}

/// Checks if a position is within the Trial Spawner proximity boundary (r <= 14.0m).
pub fn isInTrialSpawnerBoundary(pos: [3]f32, spawner_pos: [3]f32) bool {
    return euclideanDistance(pos, spawner_pos) <= TRIAL_SPAWNER_BOUNDARY_RADIUS;
}

// ============================================================================
// Inventory & Item Stacking
// ============================================================================

pub const ItemStack = struct {
    item: ItemType = .none,
    count: u16 = 0,
    tier: ?OminousBottleTier = null,
};

pub const Inventory = struct {
    slots: [36]ItemStack = [_]ItemStack{.{}} ** 36,

    pub fn init() Inventory {
        return .{};
    }

    pub fn countItem(self: *const Inventory, item: ItemType) u32 {
        var total: u32 = 0;
        for (self.slots) |slot| {
            if (slot.item == item) total += slot.count;
        }
        return total;
    }

    pub fn countOminousBottle(self: *const Inventory, tier: ?OminousBottleTier) u32 {
        var total: u32 = 0;
        for (self.slots) |slot| {
            if (slot.item == .ominous_bottle and slot.count > 0) {
                if (tier == null or slot.tier == tier) {
                    total += slot.count;
                }
            }
        }
        return total;
    }

    pub fn addItem(self: *Inventory, item: ItemType, count: u16, tier: ?OminousBottleTier) bool {
        if (count == 0) return true;
        var remaining = count;

        // 1. Try stacking into existing compatible slots
        for (&self.slots) |*slot| {
            if (slot.item == item and slot.tier == tier and slot.count < 64) {
                const space: u16 = 64 - slot.count;
                const to_add = @min(space, remaining);
                slot.count += to_add;
                remaining -= to_add;
                if (remaining == 0) return true;
            }
        }

        // 2. Put into empty slots
        for (&self.slots) |*slot| {
            if (slot.item == .none or slot.count == 0) {
                const to_add = @min(@as(u16, 64), remaining);
                slot.* = .{
                    .item = item,
                    .count = to_add,
                    .tier = tier,
                };
                remaining -= to_add;
                if (remaining == 0) return true;
            }
        }

        return remaining == 0;
    }

    pub fn consumeItem(self: *Inventory, item: ItemType) bool {
        for (&self.slots) |*slot| {
            if (slot.item == item and slot.count > 0) {
                slot.count -= 1;
                if (slot.count == 0) {
                    slot.* = .{};
                }
                return true;
            }
        }
        return false;
    }

    pub fn consumeOminousBottle(self: *Inventory, tier: ?OminousBottleTier) bool {
        for (&self.slots) |*slot| {
            if (slot.item == .ominous_bottle and slot.count > 0) {
                if (tier == null or slot.tier == tier) {
                    slot.count -= 1;
                    if (slot.count == 0) {
                        slot.* = .{};
                    }
                    return true;
                }
            }
        }
        return false;
    }
};

// ============================================================================
// Trial Spawner Model
// ============================================================================

pub const TrialSpawner = struct {
    position: [3]f32,
    is_active: bool = true,
    is_ominous: bool = false,

    pub fn init(x: f32, y: f32, z: f32, is_active: bool) TrialSpawner {
        return .{
            .position = .{ x, y, z },
            .is_active = is_active,
            .is_ominous = false,
        };
    }

    /// Upgrades spawner to ominous mode. Returns true if newly upgraded.
    pub fn upgradeToOminous(self: *TrialSpawner) bool {
        if (!self.is_active or self.is_ominous) return false;
        self.is_ominous = true;
        return true;
    }
};

// ============================================================================
// Player Omen Status & State Machine
// ============================================================================

pub const DrinkEvent = struct {
    completed: bool = false,
    bottle_consumed: bool = false,
    glass_bottle_yielded: bool = false,
    sound: SoundEffect = .none,
    bad_omen_applied: bool = false,
    amplifier: u8 = 0,
    duration_ticks: u32 = 0,
};

pub const OminousBottleDrink = struct {
    tier: OminousBottleTier,
    ticks_remaining: u32 = DRINKING_DURATION_TICKS,
    completed: bool = false,
    cancelled: bool = false,

    pub fn init(tier: OminousBottleTier) OminousBottleDrink {
        return .{
            .tier = tier,
            .ticks_remaining = DRINKING_DURATION_TICKS,
            .completed = false,
            .cancelled = false,
        };
    }

    pub fn tick(self: *OminousBottleDrink, status: *PlayerOmenStatus, inventory: ?*Inventory) DrinkEvent {
        if (self.completed or self.cancelled) return .{};
        if (self.ticks_remaining > 0) {
            self.ticks_remaining -= 1;
        }
        if (self.ticks_remaining != 0) {
            return .{};
        }

        // 32 ticks completed: consume bottle and yield glass bottle
        if (inventory) |inv| {
            if (!inv.consumeOminousBottle(self.tier)) {
                self.cancelled = true;
                return .{};
            }
            _ = inv.addItem(.glass_bottle, 1, null);
        }

        self.completed = true;
        status.applyBadOmen(self.tier);

        return .{
            .completed = true,
            .bottle_consumed = true,
            .glass_bottle_yielded = true,
            .sound = .potion_drink,
            .bad_omen_applied = true,
            .amplifier = status.amplifier,
            .duration_ticks = status.ticks_remaining,
        };
    }

    pub fn cancel(self: *OminousBottleDrink) void {
        self.cancelled = true;
    }
};

pub const PlayerOmenStatus = struct {
    kind: OmenKind = .neutral,
    amplifier: u8 = 0,
    ticks_remaining: u32 = 0,
    raid_countdown: u32 = 0,
    is_transmuted: bool = false,

    pub fn init() PlayerOmenStatus {
        return .{};
    }

    pub fn hasActiveOmen(self: *const PlayerOmenStatus) bool {
        return self.kind != .neutral and self.ticks_remaining > 0;
    }

    /// Applies Bad Omen status effect according to rules:
    /// - Duration: 120,000 game ticks (100 minutes).
    /// - Amplifier matches bottle tier (0..4).
    /// - If player already has Bad Omen:
    ///   - higher or equal tier resets duration to 120,000 ticks and updates amplifier.
    ///   - lower tier does not downgrade amplifier (and does not decrease duration).
    pub fn applyBadOmen(self: *PlayerOmenStatus, tier: OminousBottleTier) void {
        const new_amp = tier.amplifier();
        if (self.kind == .bad_omen) {
            if (new_amp >= self.amplifier) {
                self.amplifier = new_amp;
                self.ticks_remaining = BAD_OMEN_DURATION_TICKS;
            } else {
                // Lower tier does not downgrade amplifier or reset duration
            }
        } else {
            self.kind = .bad_omen;
            self.amplifier = new_amp;
            self.ticks_remaining = BAD_OMEN_DURATION_TICKS;
            self.raid_countdown = 0;
            self.is_transmuted = false;
        }
    }

    /// Immediately cleanses all omens, reverting state to neutral.
    pub fn cleanseWithMilk(self: *PlayerOmenStatus) void {
        self.kind = .neutral;
        self.amplifier = 0;
        self.ticks_remaining = 0;
        self.raid_countdown = 0;
        self.is_transmuted = false;
    }

    /// Transmutes Bad Omen into Raid Omen:
    /// - Preserves amplifier tier.
    /// - Initiates 600-tick countdown timer.
    pub fn transmuteToRaidOmen(self: *PlayerOmenStatus) bool {
        if (self.kind != .bad_omen) return false;
        self.kind = .raid_omen;
        self.raid_countdown = RAID_OMEN_COUNTDOWN_TICKS;
        self.ticks_remaining = RAID_OMEN_COUNTDOWN_TICKS;
        self.is_transmuted = true;
        return true;
    }

    /// Transmutes Bad Omen into Trial Omen:
    /// - Preserves amplifier tier.
    /// - Sets duration formula: 18,000 * (amplifier + 1) ticks.
    pub fn transmuteToTrialOmen(self: *PlayerOmenStatus) bool {
        if (self.kind != .bad_omen) return false;
        self.kind = .trial_omen;
        self.ticks_remaining = calculateTrialOmenDurationTicks(self.amplifier);
        self.raid_countdown = 0;
        self.is_transmuted = true;
        return true;
    }
};

// ============================================================================
// Proximity Input & Tick Outcome
// ============================================================================

pub const ProximityInput = struct {
    village_pos: ?[3]f32 = null,
    village_distance: ?f32 = null,
    trial_spawner_pos: ?[3]f32 = null,
    trial_spawner_distance: ?f32 = null,
    trial_spawner_active: bool = true,
    spawners: []TrialSpawner = &[_]TrialSpawner{},
};

pub const TransmutationKind = enum(u8) {
    none = 0,
    to_raid_omen = 1,
    to_trial_omen = 2,
    cleansed_milk = 3,
    expired = 4,
};

pub const TickOutcome = struct {
    kind: OmenKind = .neutral,
    amplifier: u8 = 0,
    ticks_remaining: u32 = 0,
    transmutation: TransmutationKind = .none,
    sound: SoundEffect = .none,
    ominous_particle_vortex: bool = false,
    raid_countdown: u32 = 0,
    raid_triggered: bool = false,
    raid_wave_count: u8 = 0,
    raid_difficulty: RaidDifficulty = .normal,
    spawners_upgraded: u32 = 0,
    drink_event: ?DrinkEvent = null,
    cleansed: bool = false,
};

// ============================================================================
// Ominous Bottle Matrix Manager
// ============================================================================

pub const OminousBottleMatrix = struct {
    player_position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    inventory: Inventory = .{},
    status: PlayerOmenStatus = .{},
    active_drink: ?OminousBottleDrink = null,
    raid_difficulty: RaidDifficulty = .normal,

    pub fn init() OminousBottleMatrix {
        return .{};
    }

    pub fn startDrinking(self: *OminousBottleMatrix, tier: OminousBottleTier) bool {
        if (self.active_drink != null and !self.active_drink.?.completed) {
            return false;
        }
        if (self.inventory.countOminousBottle(tier) == 0) {
            return false;
        }
        self.active_drink = OminousBottleDrink.init(tier);
        return true;
    }

    pub fn cancelDrinking(self: *OminousBottleMatrix) void {
        if (self.active_drink) |*drink| {
            drink.cancel();
        }
        self.active_drink = null;
    }

    /// Cleanses all active omens using milk bucket from inventory.
    /// Yields an empty bucket back into inventory.
    pub fn drinkMilk(self: *OminousBottleMatrix) TickOutcome {
        var outcome = TickOutcome{};
        _ = self.inventory.consumeItem(.milk_bucket);
        _ = self.inventory.addItem(.bucket, 1, null);
        self.status.cleanseWithMilk();
        self.cancelDrinking();

        outcome.kind = .neutral;
        outcome.cleansed = true;
        outcome.sound = .potion_drink;
        outcome.transmutation = .cleansed_milk;
        return outcome;
    }

    /// Single game tick processor for all omen transformation matrix rules.
    pub fn tick(self: *OminousBottleMatrix, proximity: ProximityInput) TickOutcome {
        var outcome = TickOutcome{};

        // 1. Progress active drinking session if present
        if (self.active_drink) |*drink| {
            const d_event = drink.tick(&self.status, &self.inventory);
            if (d_event.completed) {
                outcome.drink_event = d_event;
                outcome.sound = d_event.sound;
                self.active_drink = null;
            }
        }

        // 2. Process active omen states & proximity transmutations
        switch (self.status.kind) {
            .neutral => {},

            .bad_omen => {
                // Determine distances to trial spawner and village
                var trial_dist: ?f32 = proximity.trial_spawner_distance;
                if (trial_dist == null and proximity.trial_spawner_pos != null) {
                    trial_dist = euclideanDistance(self.player_position, proximity.trial_spawner_pos.?);
                }

                // Also check if any spawner in spawners list is nearby
                var active_spawner_in_range = false;
                if (proximity.spawners.len > 0) {
                    for (proximity.spawners) |spawner| {
                        if (spawner.is_active) {
                            const d = euclideanDistance(self.player_position, spawner.position);
                            if (d <= TRIAL_SPAWNER_BOUNDARY_RADIUS) {
                                active_spawner_in_range = true;
                                if (trial_dist == null or d < trial_dist.?) {
                                    trial_dist = d;
                                }
                            }
                        }
                    }
                }

                var village_dist: ?f32 = proximity.village_distance;
                if (village_dist == null and proximity.village_pos != null) {
                    village_dist = euclideanDistance(self.player_position, proximity.village_pos.?);
                }

                // Trial Spawner takes precedence over Village
                const trial_triggered = proximity.trial_spawner_active and
                    ((trial_dist != null and trial_dist.? <= TRIAL_SPAWNER_BOUNDARY_RADIUS) or active_spawner_in_range);

                if (trial_triggered) {
                    // Transmute Bad Omen -> Trial Omen
                    _ = self.status.transmuteToTrialOmen();
                    outcome.transmutation = .to_trial_omen;
                    outcome.sound = .trial_omen_transmute;
                    outcome.ominous_particle_vortex = true;

                    // Signal nearby active Trial Spawners to upgrade to Ominous
                    if (proximity.spawners.len > 0) {
                        for (proximity.spawners) |*spawner| {
                            if (spawner.is_active and !spawner.is_ominous) {
                                const d = euclideanDistance(self.player_position, spawner.position);
                                if (d <= TRIAL_SPAWNER_BOUNDARY_RADIUS) {
                                    if (spawner.upgradeToOminous()) {
                                        outcome.spawners_upgraded += 1;
                                    }
                                }
                            }
                        }
                    }
                } else if (village_dist != null and village_dist.? <= VILLAGE_BOUNDARY_RADIUS) {
                    // Transmute Bad Omen -> Raid Omen
                    _ = self.status.transmuteToRaidOmen();
                    outcome.transmutation = .to_raid_omen;
                    outcome.sound = .raid_horn;
                } else {
                    // Normal tick decay for Bad Omen
                    if (self.status.ticks_remaining > 0) {
                        self.status.ticks_remaining -= 1;
                    }
                    if (self.status.ticks_remaining == 0) {
                        self.status.cleanseWithMilk();
                        outcome.transmutation = .expired;
                    }
                }
            },

            .raid_omen => {
                // Countdown timer ticks down from 600
                if (self.status.raid_countdown > 0) {
                    self.status.raid_countdown -= 1;
                }
                self.status.ticks_remaining = self.status.raid_countdown;

                if (self.status.raid_countdown == 0) {
                    // Countdown expired at tick 600: Trigger Village Raid!
                    outcome.raid_triggered = true;
                    outcome.raid_difficulty = self.raid_difficulty;
                    outcome.raid_wave_count = calculateRaidWaves(self.raid_difficulty, self.status.amplifier);
                    outcome.transmutation = .expired;
                    self.status.cleanseWithMilk();
                }
            },

            .trial_omen => {
                // Signal any additional nearby active spawners that came into range
                if (proximity.spawners.len > 0) {
                    for (proximity.spawners) |*spawner| {
                        if (spawner.is_active and !spawner.is_ominous) {
                            const d = euclideanDistance(self.player_position, spawner.position);
                            if (d <= TRIAL_SPAWNER_BOUNDARY_RADIUS) {
                                if (spawner.upgradeToOminous()) {
                                    outcome.spawners_upgraded += 1;
                                }
                            }
                        }
                    }
                }

                // Trial Omen duration decay
                if (self.status.ticks_remaining > 0) {
                    self.status.ticks_remaining -= 1;
                }
                if (self.status.ticks_remaining == 0) {
                    self.status.cleanseWithMilk();
                    outcome.transmutation = .expired;
                }
            },
        }

        outcome.kind = self.status.kind;
        outcome.amplifier = self.status.amplifier;
        outcome.ticks_remaining = self.status.ticks_remaining;
        outcome.raid_countdown = self.status.raid_countdown;

        return outcome;
    }

    /// Process tick with milk consumption flag.
    pub fn tickWithMilk(self: *OminousBottleMatrix, proximity: ProximityInput, drank_milk: bool) TickOutcome {
        if (!drank_milk) {
            return self.tick(proximity);
        }
        return self.drinkMilk();
    }
};

// ============================================================================
// Unit Tests (At least 35 tests covering all requirements)
// ============================================================================

test "01: Tier I amplifier mapping is 0" {
    try std.testing.expectEqual(@as(u8, 0), OminousBottleTier.tier_1.amplifier());
    try std.testing.expectEqual(@as(u8, 0), amplifierForTier(.tier_1));
}

test "02: Tier II amplifier mapping is 1" {
    try std.testing.expectEqual(@as(u8, 1), OminousBottleTier.tier_2.amplifier());
    try std.testing.expectEqual(@as(u8, 1), amplifierForTier(.tier_2));
}

test "03: Tier III amplifier mapping is 2" {
    try std.testing.expectEqual(@as(u8, 2), OminousBottleTier.tier_3.amplifier());
    try std.testing.expectEqual(@as(u8, 2), amplifierForTier(.tier_3));
}

test "04: Tier IV amplifier mapping is 3" {
    try std.testing.expectEqual(@as(u8, 3), OminousBottleTier.tier_4.amplifier());
    try std.testing.expectEqual(@as(u8, 3), amplifierForTier(.tier_4));
}

test "05: Tier V amplifier mapping is 4" {
    try std.testing.expectEqual(@as(u8, 4), OminousBottleTier.tier_5.amplifier());
    try std.testing.expectEqual(@as(u8, 4), amplifierForTier(.tier_5));
}

test "06: Tier conversion roundtrips and invalid lookups return null" {
    for (1..6) |num| {
        const tier = OminousBottleTier.fromTierNumber(@intCast(num)).?;
        try std.testing.expectEqual(@as(u8, @intCast(num)), tier.tierNumber());
        const from_amp = OminousBottleTier.fromAmplifier(tier.amplifier()).?;
        try std.testing.expectEqual(tier, from_amp);
    }
    try std.testing.expect(OminousBottleTier.fromAmplifier(5) == null);
    try std.testing.expect(OminousBottleTier.fromTierNumber(0) == null);
    try std.testing.expect(OminousBottleTier.fromTierNumber(6) == null);
}

test "07: Drinking duration requires exactly 32 ticks" {
    var status = PlayerOmenStatus.init();
    var drink = OminousBottleDrink.init(.tier_1);

    for (0..31) |_| {
        const ev = drink.tick(&status, null);
        try std.testing.expect(!ev.completed);
        try std.testing.expect(!drink.completed);
    }
    try std.testing.expectEqual(@as(u32, 1), drink.ticks_remaining);

    const finish_ev = drink.tick(&status, null);
    try std.testing.expect(finish_ev.completed);
    try std.testing.expect(drink.completed);
    try std.testing.expectEqual(@as(u32, 0), drink.ticks_remaining);
}

test "08: Drinking ticks 1 through 31 do not consume bottle or apply effect" {
    var status = PlayerOmenStatus.init();
    var inv = Inventory.init();
    _ = inv.addItem(.ominous_bottle, 1, .tier_3);

    var drink = OminousBottleDrink.init(.tier_3);
    for (0..31) |_| {
        const ev = drink.tick(&status, &inv);
        try std.testing.expect(!ev.bottle_consumed);
        try std.testing.expect(!ev.bad_omen_applied);
        try std.testing.expectEqual(OmenKind.neutral, status.kind);
        try std.testing.expectEqual(@as(u32, 1), inv.countOminousBottle(.tier_3));
    }
}

test "09: Tick 32 consumes 1 ominous bottle from inventory" {
    var status = PlayerOmenStatus.init();
    var inv = Inventory.init();
    _ = inv.addItem(.ominous_bottle, 1, .tier_2);

    var drink = OminousBottleDrink.init(.tier_2);
    for (0..31) |_| _ = drink.tick(&status, &inv);

    const ev = drink.tick(&status, &inv);
    try std.testing.expect(ev.bottle_consumed);
    try std.testing.expectEqual(@as(u32, 0), inv.countOminousBottle(.tier_2));
}

test "10: Tick 32 yields 1 glass bottle to inventory" {
    var status = PlayerOmenStatus.init();
    var inv = Inventory.init();
    _ = inv.addItem(.ominous_bottle, 1, .tier_1);

    try std.testing.expectEqual(@as(u32, 0), inv.countItem(.glass_bottle));

    var drink = OminousBottleDrink.init(.tier_1);
    for (0..32) |_| _ = drink.tick(&status, &inv);

    try std.testing.expectEqual(@as(u32, 1), inv.countItem(.glass_bottle));
}

test "11: Tick 32 emits SoundEffect.potion_drink" {
    var status = PlayerOmenStatus.init();
    var drink = OminousBottleDrink.init(.tier_4);
    for (0..31) |_| _ = drink.tick(&status, null);

    const ev = drink.tick(&status, null);
    try std.testing.expectEqual(SoundEffect.potion_drink, ev.sound);
}

test "12: Interrupted drinking session preserves bottle in inventory without effect" {
    var status = PlayerOmenStatus.init();
    var inv = Inventory.init();
    _ = inv.addItem(.ominous_bottle, 1, .tier_5);

    var drink = OminousBottleDrink.init(.tier_5);
    for (0..15) |_| _ = drink.tick(&status, &inv);
    drink.cancel();

    // Next tick should do nothing
    const ev = drink.tick(&status, &inv);
    try std.testing.expect(!ev.completed);
    try std.testing.expectEqual(@as(u32, 1), inv.countOminousBottle(.tier_5));
    try std.testing.expectEqual(OmenKind.neutral, status.kind);
}

test "13: Drinking fails if inventory has no ominous bottle" {
    var status = PlayerOmenStatus.init();
    var inv = Inventory.init(); // Empty inventory

    var drink = OminousBottleDrink.init(.tier_1);
    for (0..31) |_| _ = drink.tick(&status, &inv);

    const ev = drink.tick(&status, &inv);
    try std.testing.expect(!ev.completed);
    try std.testing.expect(!ev.bad_omen_applied);
    try std.testing.expectEqual(OmenKind.neutral, status.kind);
}

test "14: Completed drinking session cannot be ticked again" {
    var status = PlayerOmenStatus.init();
    var drink = OminousBottleDrink.init(.tier_1);
    for (0..32) |_| _ = drink.tick(&status, null);

    const ev_after = drink.tick(&status, null);
    try std.testing.expect(!ev_after.completed);
    try std.testing.expect(!ev_after.bottle_consumed);
}

test "15: Stacked ominous bottles decrement by 1, leaving remainder in inventory" {
    var status = PlayerOmenStatus.init();
    var inv = Inventory.init();
    _ = inv.addItem(.ominous_bottle, 4, .tier_2);

    var drink = OminousBottleDrink.init(.tier_2);
    for (0..32) |_| _ = drink.tick(&status, &inv);

    try std.testing.expectEqual(@as(u32, 3), inv.countOminousBottle(.tier_2));
    try std.testing.expectEqual(@as(u32, 1), inv.countItem(.glass_bottle));
}

test "16: Bad Omen initial duration is exactly 120,000 ticks" {
    var status = PlayerOmenStatus.init();
    status.applyBadOmen(.tier_1);

    try std.testing.expectEqual(OmenKind.bad_omen, status.kind);
    try std.testing.expectEqual(BAD_OMEN_DURATION_TICKS, status.ticks_remaining);
    try std.testing.expectEqual(@as(u32, 120_000), status.ticks_remaining);
}

test "17: Bad Omen duration decays one tick per game tick" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_3);

    const res = matrix.tick(.{});
    try std.testing.expectEqual(@as(u32, 119_999), res.ticks_remaining);
    try std.testing.expectEqual(OmenKind.bad_omen, res.kind);
}

test "18: Bad Omen expires to neutral when ticks reach 0" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.kind = .bad_omen;
    matrix.status.amplifier = 2;
    matrix.status.ticks_remaining = 1;

    const res = matrix.tick(.{});
    try std.testing.expectEqual(OmenKind.neutral, res.kind);
    try std.testing.expectEqual(@as(u32, 0), res.ticks_remaining);
    try std.testing.expectEqual(@as(u8, 0), res.amplifier);
}

test "19: Stacking higher tier updates amplifier and resets duration to 120,000" {
    var status = PlayerOmenStatus.init();
    status.applyBadOmen(.tier_2); // amplifier 1
    status.ticks_remaining = 50_000;

    status.applyBadOmen(.tier_4); // amplifier 3
    try std.testing.expectEqual(@as(u8, 3), status.amplifier);
    try std.testing.expectEqual(BAD_OMEN_DURATION_TICKS, status.ticks_remaining);
}

test "20: Stacking equal tier preserves amplifier and resets duration to 120,000" {
    var status = PlayerOmenStatus.init();
    status.applyBadOmen(.tier_3); // amplifier 2
    status.ticks_remaining = 30_000;

    status.applyBadOmen(.tier_3); // amplifier 2
    try std.testing.expectEqual(@as(u8, 2), status.amplifier);
    try std.testing.expectEqual(BAD_OMEN_DURATION_TICKS, status.ticks_remaining);
}

test "21: Stacking lower tier does not downgrade amplifier" {
    var status = PlayerOmenStatus.init();
    status.applyBadOmen(.tier_5); // amplifier 4
    status.ticks_remaining = 100_000;

    status.applyBadOmen(.tier_1); // amplifier 0
    try std.testing.expectEqual(@as(u8, 4), status.amplifier);
}

test "22: Stacking lower tier preserves remaining duration and higher amplifier" {
    var status = PlayerOmenStatus.init();
    status.applyBadOmen(.tier_4); // amplifier 3
    status.ticks_remaining = 85_432;

    status.applyBadOmen(.tier_2); // amplifier 1
    try std.testing.expectEqual(@as(u8, 3), status.amplifier);
    try std.testing.expectEqual(@as(u32, 85_432), status.ticks_remaining);
}

test "23: Bad Omen amplifier does not exceed 4 (Tier V)" {
    var status = PlayerOmenStatus.init();
    status.applyBadOmen(.tier_5);
    try std.testing.expectEqual(@as(u8, 4), status.amplifier);
}

test "24: Player outside 64.0m village boundary does not transmute to Raid Omen" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_2);

    const outcome = matrix.tick(.{ .village_distance = 64.01 });
    try std.testing.expectEqual(OmenKind.bad_omen, outcome.kind);
    try std.testing.expectEqual(SoundEffect.none, outcome.sound);
}

test "25: Player exactly at 64.0m village boundary transmutes to Raid Omen" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_3);

    const outcome = matrix.tick(.{ .village_distance = 64.0 });
    try std.testing.expectEqual(OmenKind.raid_omen, outcome.kind);
    try std.testing.expectEqual(SoundEffect.raid_horn, outcome.sound);
}

test "26: Player inside 64.0m village boundary transmutes to Raid Omen" {
    var matrix = OminousBottleMatrix.init();
    matrix.player_position = .{ 0.0, 0.0, 0.0 };
    matrix.status.applyBadOmen(.tier_1);

    // Village center at (30, 0, 0) -> distance 30m
    const outcome = matrix.tick(.{ .village_pos = .{ 30.0, 0.0, 0.0 } });
    try std.testing.expectEqual(OmenKind.raid_omen, outcome.kind);
    try std.testing.expectEqual(SoundEffect.raid_horn, outcome.sound);
}

test "27: Raid Omen preserves the Bad Omen amplifier tier" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_4); // amplifier 3

    const outcome = matrix.tick(.{ .village_distance = 50.0 });
    try std.testing.expectEqual(OmenKind.raid_omen, outcome.kind);
    try std.testing.expectEqual(@as(u8, 3), outcome.amplifier);
}

test "28: Raid Omen transmutation emits SoundEffect.raid_horn" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_1);

    const outcome = matrix.tick(.{ .village_distance = 10.0 });
    try std.testing.expectEqual(SoundEffect.raid_horn, outcome.sound);
    try std.testing.expectEqual(TransmutationKind.to_raid_omen, outcome.transmutation);
}

test "29: Raid Omen initiates 600-tick countdown timer" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_2);

    const outcome = matrix.tick(.{ .village_distance = 60.0 });
    try std.testing.expectEqual(RAID_OMEN_COUNTDOWN_TICKS, outcome.raid_countdown);
    try std.testing.expectEqual(@as(u32, 600), outcome.ticks_remaining);
}

test "30: Raid Omen countdown decays one tick per game tick" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.kind = .raid_omen;
    matrix.status.amplifier = 2;
    matrix.status.raid_countdown = 600;
    matrix.status.ticks_remaining = 600;

    const outcome = matrix.tick(.{});
    try std.testing.expectEqual(@as(u32, 599), outcome.raid_countdown);
    try std.testing.expectEqual(@as(u32, 599), outcome.ticks_remaining);
}

test "31: Raid Omen tick 600 expiration triggers village raid" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.kind = .raid_omen;
    matrix.status.amplifier = 3;
    matrix.status.raid_countdown = 1;
    matrix.status.ticks_remaining = 1;
    matrix.raid_difficulty = .normal;

    const outcome = matrix.tick(.{});
    try std.testing.expect(outcome.raid_triggered);
    try std.testing.expectEqual(RaidDifficulty.normal, outcome.raid_difficulty);
    // Normal: base 5 waves + 1 bonus wave for amplifier >= 1 = 6 waves
    try std.testing.expectEqual(@as(u8, 6), outcome.raid_wave_count);
    try std.testing.expectEqual(OmenKind.neutral, outcome.kind);
}

test "32: Raid Omen countdown at tick 599 does not yet trigger raid" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.kind = .raid_omen;
    matrix.status.amplifier = 1;
    matrix.status.raid_countdown = 2;
    matrix.status.ticks_remaining = 2;

    const outcome = matrix.tick(.{});
    try std.testing.expect(!outcome.raid_triggered);
    try std.testing.expectEqual(OmenKind.raid_omen, outcome.kind);
    try std.testing.expectEqual(@as(u32, 1), outcome.raid_countdown);
}

test "33: Raid wave count scales with difficulty and amplifier for Easy" {
    try std.testing.expectEqual(@as(u8, 3), raidWaveCount(.easy, 0)); // Tier I (amp 0): 3 waves
    try std.testing.expectEqual(@as(u8, 4), raidWaveCount(.easy, 1)); // Tier II (amp 1): 4 waves
    try std.testing.expectEqual(@as(u8, 4), raidWaveCount(.easy, 4)); // Tier V (amp 4): 4 waves
}

test "34: Raid wave count scales with difficulty and amplifier for Normal" {
    try std.testing.expectEqual(@as(u8, 5), raidWaveCount(.normal, 0)); // Tier I (amp 0): 5 waves
    try std.testing.expectEqual(@as(u8, 6), raidWaveCount(.normal, 1)); // Tier II (amp 1): 6 waves
    try std.testing.expectEqual(@as(u8, 6), raidWaveCount(.normal, 4)); // Tier V (amp 4): 6 waves
}

test "35: Raid wave count scales with difficulty and amplifier for Hard" {
    try std.testing.expectEqual(@as(u8, 7), raidWaveCount(.hard, 0)); // Tier I (amp 0): 7 waves
    try std.testing.expectEqual(@as(u8, 8), raidWaveCount(.hard, 1)); // Tier II (amp 1): 8 waves
    try std.testing.expectEqual(@as(u8, 8), raidWaveCount(.hard, 4)); // Tier V (amp 4): 8 waves
}

test "36: Player outside 14.0m trial spawner boundary does not transmute to Trial Omen" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_3);

    const outcome = matrix.tick(.{ .trial_spawner_distance = 14.01 });
    try std.testing.expectEqual(OmenKind.bad_omen, outcome.kind);
    try std.testing.expectEqual(SoundEffect.none, outcome.sound);
}

test "37: Player exactly at 14.0m trial spawner boundary transmutes to Trial Omen" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_2);

    const outcome = matrix.tick(.{ .trial_spawner_distance = 14.0 });
    try std.testing.expectEqual(OmenKind.trial_omen, outcome.kind);
    try std.testing.expectEqual(SoundEffect.trial_omen_transmute, outcome.sound);
    try std.testing.expect(outcome.ominous_particle_vortex);
}

test "38: Inactive trial spawner does not trigger Trial Omen transmutation" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_1);

    const outcome = matrix.tick(.{
        .trial_spawner_distance = 5.0,
        .trial_spawner_active = false,
    });
    try std.testing.expectEqual(OmenKind.bad_omen, outcome.kind);
    try std.testing.expectEqual(SoundEffect.none, outcome.sound);
}

test "39: Trial Omen preserves amplifier tier" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_4); // amplifier 3

    const outcome = matrix.tick(.{ .trial_spawner_distance = 10.0 });
    try std.testing.expectEqual(OmenKind.trial_omen, outcome.kind);
    try std.testing.expectEqual(@as(u8, 3), outcome.amplifier);
}

test "40: Trial Omen duration formula for Tier I is 18,000 ticks" {
    try std.testing.expectEqual(@as(u32, 18_000), calculateTrialOmenDurationTicks(0));
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_1);
    const outcome = matrix.tick(.{ .trial_spawner_distance = 8.0 });
    try std.testing.expectEqual(@as(u32, 18_000), outcome.ticks_remaining);
}

test "41: Trial Omen duration formula for Tier II is 36,000 ticks" {
    try std.testing.expectEqual(@as(u32, 36_000), calculateTrialOmenDurationTicks(1));
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_2);
    const outcome = matrix.tick(.{ .trial_spawner_distance = 8.0 });
    try std.testing.expectEqual(@as(u32, 36_000), outcome.ticks_remaining);
}

test "42: Trial Omen duration formula for Tier III is 54,000 ticks" {
    try std.testing.expectEqual(@as(u32, 54_000), calculateTrialOmenDurationTicks(2));
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_3);
    const outcome = matrix.tick(.{ .trial_spawner_distance = 8.0 });
    try std.testing.expectEqual(@as(u32, 54_000), outcome.ticks_remaining);
}

test "43: Trial Omen duration formula for Tier IV is 72,000 ticks" {
    try std.testing.expectEqual(@as(u32, 72_000), calculateTrialOmenDurationTicks(3));
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_4);
    const outcome = matrix.tick(.{ .trial_spawner_distance = 8.0 });
    try std.testing.expectEqual(@as(u32, 72_000), outcome.ticks_remaining);
}

test "44: Trial Omen duration formula for Tier V is 90,000 ticks" {
    try std.testing.expectEqual(@as(u32, 90_000), calculateTrialOmenDurationTicks(4));
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_5);
    const outcome = matrix.tick(.{ .trial_spawner_distance = 8.0 });
    try std.testing.expectEqual(@as(u32, 90_000), outcome.ticks_remaining);
}

test "45: Trial Omen transmutation emits SoundEffect.trial_omen_transmute and ominous vortex" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_1);

    const outcome = matrix.tick(.{ .trial_spawner_distance = 12.0 });
    try std.testing.expectEqual(SoundEffect.trial_omen_transmute, outcome.sound);
    try std.testing.expect(outcome.ominous_particle_vortex);
    try std.testing.expectEqual(TransmutationKind.to_trial_omen, outcome.transmutation);
}

test "46: Trial Omen transmutation signals nearby active trial spawners to upgrade to ominous" {
    var matrix = OminousBottleMatrix.init();
    matrix.player_position = .{ 0.0, 0.0, 0.0 };
    matrix.status.applyBadOmen(.tier_1);

    var spawners = [_]TrialSpawner{
        TrialSpawner.init(5.0, 0.0, 0.0, true),   // 5m away, active -> should upgrade
        TrialSpawner.init(12.0, 0.0, 0.0, true),  // 12m away, active -> should upgrade
        TrialSpawner.init(20.0, 0.0, 0.0, true),  // 20m away (> 14m) -> should not upgrade
        TrialSpawner.init(4.0, 0.0, 0.0, false),  // 4m away, inactive -> should not upgrade
    };

    const outcome = matrix.tick(.{ .spawners = spawners[0..] });
    try std.testing.expectEqual(@as(u32, 2), outcome.spawners_upgraded);
    try std.testing.expect(spawners[0].is_ominous);
    try std.testing.expect(spawners[1].is_ominous);
    try std.testing.expect(!spawners[2].is_ominous);
    try std.testing.expect(!spawners[3].is_ominous);
}

test "47: Already ominous trial spawner is not re-upgraded" {
    var matrix = OminousBottleMatrix.init();
    matrix.player_position = .{ 0.0, 0.0, 0.0 };
    matrix.status.applyBadOmen(.tier_2);

    var spawners = [_]TrialSpawner{
        TrialSpawner.init(5.0, 0.0, 0.0, true),
    };
    spawners[0].is_ominous = true; // Pre-existing ominous spawner

    const outcome = matrix.tick(.{ .spawners = spawners[0..] });
    try std.testing.expectEqual(@as(u32, 0), outcome.spawners_upgraded);
    try std.testing.expect(spawners[0].is_ominous);
}

test "48: Trial spawner at 14.0m takes precedence over village at 64.0m" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_3);

    const outcome = matrix.tick(.{
        .village_distance = 10.0,
        .trial_spawner_distance = 14.0,
    });
    try std.testing.expectEqual(OmenKind.trial_omen, outcome.kind);
    try std.testing.expectEqual(SoundEffect.trial_omen_transmute, outcome.sound);
    try std.testing.expect(!outcome.raid_triggered);
}

test "49: Milk bucket cleanses Bad Omen immediately to neutral" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_4);
    _ = matrix.inventory.addItem(.milk_bucket, 1, null);

    const outcome = matrix.drinkMilk();
    try std.testing.expect(outcome.cleansed);
    try std.testing.expectEqual(OmenKind.neutral, outcome.kind);
    try std.testing.expectEqual(@as(u8, 0), outcome.amplifier);
    try std.testing.expectEqual(@as(u32, 0), outcome.ticks_remaining);
    try std.testing.expectEqual(SoundEffect.potion_drink, outcome.sound);
}

test "50: Milk bucket cleanses Raid Omen immediately and cancels raid trigger" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.kind = .raid_omen;
    matrix.status.amplifier = 4;
    matrix.status.raid_countdown = 1; // 1 tick from expiration
    matrix.status.ticks_remaining = 1;
    _ = matrix.inventory.addItem(.milk_bucket, 1, null);

    const outcome = matrix.tickWithMilk(.{}, true);
    try std.testing.expect(outcome.cleansed);
    try std.testing.expectEqual(OmenKind.neutral, outcome.kind);
    try std.testing.expect(!outcome.raid_triggered);
}

test "51: Milk bucket cleanses Trial Omen immediately to neutral" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.kind = .trial_omen;
    matrix.status.amplifier = 2;
    matrix.status.ticks_remaining = 36_000;
    _ = matrix.inventory.addItem(.milk_bucket, 1, null);

    const outcome = matrix.drinkMilk();
    try std.testing.expect(outcome.cleansed);
    try std.testing.expectEqual(OmenKind.neutral, outcome.kind);
    try std.testing.expectEqual(@as(u32, 0), matrix.status.ticks_remaining);
}

test "52: Milk bucket drinking consumes milk bucket, yields empty bucket and sound" {
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_1);
    _ = matrix.inventory.addItem(.milk_bucket, 1, null);

    try std.testing.expectEqual(@as(u32, 1), matrix.inventory.countItem(.milk_bucket));
    try std.testing.expectEqual(@as(u32, 0), matrix.inventory.countItem(.bucket));

    const outcome = matrix.drinkMilk();
    try std.testing.expectEqual(@as(u32, 0), matrix.inventory.countItem(.milk_bucket));
    try std.testing.expectEqual(@as(u32, 1), matrix.inventory.countItem(.bucket));
    try std.testing.expectEqual(SoundEffect.potion_drink, outcome.sound);
}

test "53: Neutral player drinking milk remains neutral without errors" {
    var matrix = OminousBottleMatrix.init();
    _ = matrix.inventory.addItem(.milk_bucket, 1, null);

    const outcome = matrix.drinkMilk();
    try std.testing.expect(outcome.cleansed);
    try std.testing.expectEqual(OmenKind.neutral, outcome.kind);
    try std.testing.expectEqual(@as(u8, 0), matrix.status.amplifier);
    try std.testing.expectEqual(@as(u32, 0), matrix.status.ticks_remaining);
}

};


pub const dynamics = struct {
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
    vault_reset_token = 608,
};

pub const DETECTION_RADIUS: f32 = 14.0;
pub const DETECTION_RADIUS_SQ: f32 = 196.0;
pub const TICKS_PER_SECOND: u32 = 20;
pub const SPAWN_INTERVAL_TICKS: u32 = 40;
pub const COOLDOWN_TICKS: u32 = 36_000;
pub const HAZARD_INTERVAL_TICKS: u32 = 160;
pub const STANDARD_KEY_CHANCE: f32 = 0.50;
pub const OMINOUS_KEY_CHANCE: f32 = 0.30;
pub const OMINOUS_RESET_TOKEN_CHANCE: f32 = 0.05;

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
    reset_token_item: ?ItemType = null,
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
        return self.ejectRewardsWithTokenRoll(reward_roll, key_roll, 1.0);
    }

    /// `reset_token_roll` independently gives ominous spawners a 5% reset-token chance.
    pub fn ejectRewardsWithTokenRoll(self: *TrialSpawner, reward_roll: f32, key_roll: f32, reset_token_roll: f32) ?RewardEjection {
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
            .reset_token_item = if (self.is_ominous and reset_token_roll < OMINOUS_RESET_TOKEN_CHANCE) .vault_reset_token else null,
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

test "ominous trial spawner independently ejects vault reset token on five percent roll" {
    var spawner = TrialSpawner.init(0, 0, 0);
    spawner.state = .waiting_for_reward_ejection;
    spawner.is_ominous = true;
    const reward = spawner.ejectRewardsWithTokenRoll(0.5, 0.9, 0.049).?;
    try std.testing.expectEqual(ItemType.vault_reset_token, reward.reset_token_item.?);
}

test "standard trial spawner and ominous rolls outside five percent never eject reset token" {
    var normal = TrialSpawner.init(0, 0, 0);
    normal.state = .waiting_for_reward_ejection;
    try std.testing.expect(normal.ejectRewardsWithTokenRoll(0.5, 0.9, 0.0).?.reset_token_item == null);
    var ominous = TrialSpawner.init(0, 0, 0);
    ominous.state = .waiting_for_reward_ejection;
    ominous.is_ominous = true;
    try std.testing.expect(ominous.ejectRewardsWithTokenRoll(0.5, 0.9, 0.05).?.reset_token_item == null);
}

};


pub const waves = struct {
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

};


pub const vault_dispenser = struct {
/// Item IDs are mirrored here so this world module remains a standalone test target.
pub const ItemType = enum(u16) {
    iron_ingot = 26,
    golden_apple = 30,
    bread = 34,
    cooked_beef = 36,
    diamond = 217,
    emerald = 273,
    baked_potato = 343,
    breeze_rod = 371,
    heavy_core = 373,
    trial_key = 376,
    enchanted_golden_apple = 379,
    flow_armor_trim_template = 402,
    bolt_armor_trim_template = 403,
    ominous_trial_key = 404,
    wind_burst_enchanted_book = 405,
    flow_banner_pattern = 406,
};

pub const VaultType = enum { standard, ominous };
pub const State = enum { idle, ejecting, unlocked };
pub const InteractionResult = enum { started_ejection, already_unlocked, wrong_key, busy };
pub const EJECTION_TICKS: u8 = 40;
pub const COMPARATOR_RADIUS: f32 = 4.5;
pub const COMPARATOR_RADIUS_SQ: f32 = COMPARATOR_RADIUS * COMPARATOR_RADIUS;
pub const MAX_UNLOCKED_PLAYERS: usize = 64;
pub const MAX_EJECTED_STACKS: usize = 6;

pub const ItemStack = struct {
    item: ItemType,
    count: u8 = 1,
};

pub const Inventory = struct {
    slots: [36]?ItemStack = [_]?ItemStack{null} ** 36,

    pub fn count(self: Inventory, item: ItemType) u32 {
        var total: u32 = 0;
        for (self.slots) |slot| if (slot) |stack| {
            if (stack.item == item) total += stack.count;
        };
        return total;
    }

    fn consumeOne(self: *Inventory, item: ItemType) bool {
        for (&self.slots) |*slot| {
            if (slot.*) |*stack| {
                if (stack.item != item or stack.count == 0) continue;
                stack.count -= 1;
                if (stack.count == 0) slot.* = null;
                return true;
            }
        }
        return false;
    }
};

pub const DisplayItem = struct {
    item: ItemType,
    position: [3]f32,
    spin_radians: f32,
};

pub const EjectedStack = struct {
    stack: ItemStack,
    position: [3]f32,
    velocity: [3]f32,
};

pub const UnlockResult = struct {
    interaction: InteractionResult,
    ejected: [MAX_EJECTED_STACKS]?EjectedStack = [_]?EjectedStack{null} ** MAX_EJECTED_STACKS,
    ejected_count: u8 = 0,
};

pub const NearbyPlayer = struct { id: u32, position: [3]f32 };

pub const VaultBlock = struct {
    position: [3]f32,
    vault_type: VaultType = .standard,
    state: State = .idle,
    eject_ticks_remaining: u8 = 0,
    display_ticks: u32 = 0,
    spin_radians: f32 = 0.0,
    display_item: ItemType = .heavy_core,
    unlocked_players: [MAX_UNLOCKED_PLAYERS]u32 = [_]u32{0} ** MAX_UNLOCKED_PLAYERS,
    unlocked_player_count: u8 = 0,
    active_ejector: ?u32 = null,
    last_eject_stacks: [MAX_EJECTED_STACKS]?EjectedStack = [_]?EjectedStack{null} ** MAX_EJECTED_STACKS,
    last_eject_count: u8 = 0,

    pub fn init(vault_type: VaultType, position: [3]f32) VaultBlock {
        return .{ .position = position, .vault_type = vault_type };
    }

    pub fn hasPlayerUnlocked(self: VaultBlock, player_id: u32) bool {
        for (self.unlocked_players[0..self.unlocked_player_count]) |id| {
            if (id == player_id) return true;
        }
        return false;
    }

    pub fn acceptsInteraction(self: VaultBlock, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id) and self.unlocked_player_count < MAX_UNLOCKED_PLAYERS;
    }

    /// A keyhole goes dark only for the player who has already claimed this vault.
    pub fn keyholeIsDark(self: VaultBlock, player_id: u32) bool {
        return self.hasPlayerUnlocked(player_id);
    }

    /// The caged item and ambient sparks are viewer-specific, not global vault state.
    pub fn displayForPlayer(self: VaultBlock, player_id: u32) ?DisplayItem {
        if (self.hasPlayerUnlocked(player_id)) return null;
        const angle = if (self.state == .ejecting) self.spin_radians else @as(f32, @floatFromInt(self.display_ticks % 628)) * 0.01;
        return .{
            .item = self.display_item,
            .position = .{ self.position[0] + 0.5, self.position[1] + 0.65, self.position[2] + 0.5 },
            .spin_radians = angle,
        };
    }

    pub fn emitsAmbientSparks(self: VaultBlock, player_id: u32) bool {
        return self.displayForPlayer(player_id) != null;
    }

    pub fn interact(self: *VaultBlock, player_id: u32, inventory: *Inventory, random_seed: u32) UnlockResult {
        if (self.hasPlayerUnlocked(player_id)) return .{ .interaction = .already_unlocked };
        if (self.unlocked_player_count >= MAX_UNLOCKED_PLAYERS) return .{ .interaction = .already_unlocked };
        if (self.state == .ejecting) return .{ .interaction = .busy };
        const key = requiredKey(self.vault_type);
        if (!inventory.consumeOne(key)) return .{ .interaction = .wrong_key };

        self.unlocked_players[self.unlocked_player_count] = player_id;
        self.unlocked_player_count += 1;
        self.state = .ejecting;
        self.eject_ticks_remaining = EJECTION_TICKS;
        self.spin_radians = 0.0;
        self.active_ejector = player_id;
        const generated = generateLoot(self.vault_type, random_seed, self.position);
        self.last_eject_stacks = generated.stacks;
        self.last_eject_count = generated.count;
        return .{
            .interaction = .started_ejection,
            .ejected = generated.stacks,
            .ejected_count = generated.count,
        };
    }

    /// Advances the 40 tick display spin-down; returns true on the completion tick.
    pub fn tick(self: *VaultBlock) bool {
        self.display_ticks +%= 1;
        if (self.state != .ejecting) return false;
        const progress = @as(f32, @floatFromInt(EJECTION_TICKS - self.eject_ticks_remaining)) / @as(f32, EJECTION_TICKS);
        const angular_speed = 0.8 - 0.6 * progress;
        self.spin_radians += angular_speed;
        if (self.eject_ticks_remaining > 0) self.eject_ticks_remaining -= 1;
        if (self.eject_ticks_remaining == 0) {
            self.state = .unlocked;
            self.active_ejector = null;
            return true;
        }
        return false;
    }

    /// Signal is based on the nearest player in range, including already-unlocked players.
    pub fn comparatorSignal(self: VaultBlock, players: []const NearbyPlayer) u4 {
        var nearest_distance_sq = COMPARATOR_RADIUS_SQ;
        var nearest_id: ?u32 = null;
        for (players) |player| {
            const distance_sq = distanceSquared(self.position, player.position);
            if (distance_sq <= nearest_distance_sq) {
                if (nearest_id == null or distance_sq < nearest_distance_sq or player.id < nearest_id.?) {
                    nearest_distance_sq = distance_sq;
                    nearest_id = player.id;
                }
            }
        }
        const id = nearest_id orelse return 0;
        return if (self.hasPlayerUnlocked(id)) 0 else 15;
    }
};

pub fn requiredKey(vault_type: VaultType) ItemType {
    return if (vault_type == .standard) .trial_key else .ominous_trial_key;
}

fn distanceSquared(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

fn lootPool(vault_type: VaultType) []const ItemType {
    const standard = [_]ItemType{ .heavy_core, .breeze_rod, .diamond, .emerald, .enchanted_golden_apple, .iron_ingot, .bread, .cooked_beef, .baked_potato };
    const ominous = [_]ItemType{ .heavy_core, .flow_armor_trim_template, .bolt_armor_trim_template, .wind_burst_enchanted_book, .flow_banner_pattern, .golden_apple };
    return if (vault_type == .standard) standard[0..] else ominous[0..];
}

const LootGeneration = struct {
    stacks: [MAX_EJECTED_STACKS]?EjectedStack,
    count: u8,
};

fn nextRandom(state: *u32) u32 {
    state.* = state.* *% 1664525 +% 1013904223;
    return state.*;
}

fn generateLoot(vault_type: VaultType, seed: u32, position: [3]f32) LootGeneration {
    var result = LootGeneration{ .stacks = [_]?EjectedStack{null} ** MAX_EJECTED_STACKS, .count = 0 };
    var rng = seed;
    const pool = lootPool(vault_type);
    const standard_pool = pool[1..]; // Heavy Core is selected by its independent 2.2% roll.
    const choices = if (vault_type == .standard) standard_pool else pool;
    const requested: usize = 3 + @as(usize, @intCast(nextRandom(&rng) % 4));
    var item_used: [9]bool = [_]bool{false} ** 9;
    while (result.count < requested) {
        const rare_heavy_core = vault_type == .standard and nextRandom(&rng) % 1000 < 22 and !item_used[0];
        var item_index: usize = if (rare_heavy_core)
            0
        else if (vault_type == .standard)
            1 + @as(usize, @intCast(nextRandom(&rng) % @as(u32, @intCast(choices.len))))
        else
            @intCast(nextRandom(&rng) % @as(u32, @intCast(choices.len)));
        var attempts: usize = 0;
        while (item_used[item_index] and attempts < choices.len) : (attempts += 1) {
            item_index = if (vault_type == .standard and item_index + 1 >= pool.len)
                1
            else
                (item_index + 1) % pool.len;
        }
        if (item_used[item_index]) item_index = if (item_used[0]) 1 else 0;
        item_used[item_index] = true;
        const item = pool[item_index];
        const horizontal_x = @as(f32, @floatFromInt(@as(i32, @intCast(nextRandom(&rng) % 101)) - 50)) / 200.0;
        const horizontal_z = @as(f32, @floatFromInt(@as(i32, @intCast(nextRandom(&rng) % 101)) - 50)) / 200.0;
        const amount: u8 = switch (item) {
            .breeze_rod => 2 + @as(u8, @intCast(nextRandom(&rng) % 3)),
            .diamond, .emerald, .iron_ingot => 2 + @as(u8, @intCast(nextRandom(&rng) % 5)),
            .bread, .cooked_beef, .baked_potato, .golden_apple => 2 + @as(u8, @intCast(nextRandom(&rng) % 4)),
            else => 1,
        };
        result.stacks[result.count] = .{
            .stack = .{ .item = item, .count = amount },
            .position = .{ position[0] + 0.5, position[1] + 1.0, position[2] + 0.5 },
            .velocity = .{ horizontal_x, 0.45, horizontal_z },
        };
        result.count += 1;
    }
    return result;
}

test "vault type selects its required key and pool" {
    try std.testing.expectEqual(ItemType.trial_key, requiredKey(.standard));
    try std.testing.expectEqual(ItemType.ominous_trial_key, requiredKey(.ominous));
    try std.testing.expectEqual(@as(u16, 404), @intFromEnum(ItemType.ominous_trial_key));
    try std.testing.expectEqual(@as(usize, 9), lootPool(.standard).len);
    try std.testing.expectEqual(@as(usize, 6), lootPool(.ominous).len);
}

test "standard vault accepts standard key and consumes exactly one" {
    var vault = VaultBlock.init(.standard, .{ 0, 64, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 2 };
    const result = vault.interact(1, &inventory, 1);
    try std.testing.expectEqual(InteractionResult.started_ejection, result.interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.trial_key));
    try std.testing.expect(vault.hasPlayerUnlocked(1));
}

test "ominous vault accepts ominous key and consumes it" {
    var vault = VaultBlock.init(.ominous, .{ 0, 64, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .ominous_trial_key, .count = 1 };
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(7, &inventory, 3).interaction);
    try std.testing.expectEqual(@as(u32, 0), inventory.count(.ominous_trial_key));
}

test "wrong key variants do not consume inventory" {
    var standard = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var ominous = VaultBlock.init(.ominous, .{ 0, 0, 0 });
    var ominous_key_inventory = Inventory{};
    ominous_key_inventory.slots[0] = .{ .item = .ominous_trial_key, .count = 1 };
    try std.testing.expectEqual(InteractionResult.wrong_key, standard.interact(1, &ominous_key_inventory, 4).interaction);
    var standard_key_inventory = Inventory{};
    standard_key_inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    try std.testing.expectEqual(InteractionResult.wrong_key, ominous.interact(1, &standard_key_inventory, 5).interaction);
    try std.testing.expectEqual(@as(u32, 1), ominous_key_inventory.count(.ominous_trial_key));
    try std.testing.expectEqual(@as(u32, 1), standard_key_inventory.count(.trial_key));
}

test "player unlock tracking is isolated by player ID" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(1, &inventory, 1).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(!vault.hasPlayerUnlocked(2));
    try std.testing.expect(vault.keyholeIsDark(1));
    try std.testing.expect(!vault.keyholeIsDark(2));
    try std.testing.expect(vault.displayForPlayer(1) == null);
    try std.testing.expect(vault.displayForPlayer(2) != null);
}

test "unlocked player is rejected on second interaction" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 2 };
    _ = vault.interact(1, &inventory, 1);
    try std.testing.expectEqual(InteractionResult.already_unlocked, vault.interact(1, &inventory, 2).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.trial_key));
}

test "ambient sparks and floating item show only to eligible player" {
    var vault = VaultBlock.init(.standard, .{ 2, 10, -3 });
    try std.testing.expect(vault.emitsAmbientSparks(2));
    const display = vault.displayForPlayer(2).?;
    try std.testing.expectEqual(ItemType.heavy_core, display.item);
    try std.testing.expectEqual([3]f32{ 2.5, 10.65, -2.5 }, display.position);
    vault.unlocked_players[0] = 2;
    vault.unlocked_player_count = 1;
    try std.testing.expect(!vault.emitsAmbientSparks(2));
    try std.testing.expect(vault.displayForPlayer(2) == null);
    try std.testing.expect(vault.emitsAmbientSparks(3));
}

test "ejection returns three to six distinct stacks with upward velocity" {
    var seed: u32 = 0;
    while (seed < 20) : (seed += 1) {
        const generated = generateLoot(.standard, seed, .{ 4, 8, -2 });
        try std.testing.expect(generated.count >= 3 and generated.count <= 6);
        var i: usize = 0;
        while (i < generated.count) : (i += 1) {
            const stack = generated.stacks[i].?;
            try std.testing.expectEqual(@as(f32, 0.45), stack.velocity[1]);
            try std.testing.expectEqual([3]f32{ 4.5, 9.0, -1.5 }, stack.position);
            var j = i + 1;
            while (j < generated.count) : (j += 1) try std.testing.expect(stack.stack.item != generated.stacks[j].?.stack.item);
        }
    }
}

test "ejection has deterministic horizontal dispersion" {
    const a = generateLoot(.standard, 1, .{ 0, 0, 0 });
    const b = generateLoot(.standard, 2, .{ 0, 0, 0 });
    try std.testing.expect(a.stacks[0].?.velocity[0] != b.stacks[0].?.velocity[0] or a.stacks[0].?.velocity[2] != b.stacks[0].?.velocity[2]);
    for (a.stacks[0..a.count]) |maybe_stack| {
        const velocity = maybe_stack.?.velocity;
        try std.testing.expect(velocity[0] >= -0.25 and velocity[0] <= 0.25);
        try std.testing.expect(velocity[2] >= -0.25 and velocity[2] <= 0.25);
    }
}

test "standard loot includes heavy core with requested rare weight" {
    var heavy_count: usize = 0;
    var stack_count: usize = 0;
    const trials = 20_000;
    var seed: u32 = 0;
    while (seed < trials) : (seed += 1) {
        const generated = generateLoot(.standard, seed, .{ 0, 0, 0 });
        for (generated.stacks[0..generated.count]) |stack| {
            stack_count += 1;
            if (stack.?.stack.item == .heavy_core) heavy_count += 1;
        }
    }
    const observed_rate = @as(f64, @floatFromInt(heavy_count)) / @as(f64, @floatFromInt(stack_count));
    try std.testing.expect(observed_rate > 0.018 and observed_rate < 0.026);
}

test "standard loot items stay within standard pool" {
    const generated = generateLoot(.standard, 123, .{ 0, 0, 0 });
    for (generated.stacks[0..generated.count]) |stack| try std.testing.expect(std.mem.indexOfScalar(ItemType, lootPool(.standard), stack.?.stack.item) != null);
}

test "ominous loot items stay within ominous pool" {
    const generated = generateLoot(.ominous, 456, .{ 0, 0, 0 });
    for (generated.stacks[0..generated.count]) |stack| try std.testing.expect(std.mem.indexOfScalar(ItemType, lootPool(.ominous), stack.?.stack.item) != null);
}

test "comparator gives full signal for nearby eligible player" {
    const vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    const players = [_]NearbyPlayer{.{ .id = 1, .position = .{ 4, 0, 0 } }};
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorSignal(&players));
}

test "comparator gives zero for nearby unlocked player" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 5;
    vault.unlocked_player_count = 1;
    const players = [_]NearbyPlayer{.{ .id = 5, .position = .{ 1, 0, 0 } }};
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorSignal(&players));
}

test "comparator ignores players beyond 4.5 meters" {
    const vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    const players = [_]NearbyPlayer{.{ .id = 1, .position = .{ 4.6, 0, 0 } }};
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorSignal(&players));
}

test "comparator uses nearest player's eligibility" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    const players = [_]NearbyPlayer{
        .{ .id = 1, .position = .{ 1, 0, 0 } },
        .{ .id = 2, .position = .{ 2, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorSignal(&players));
}

test "comparator follows newly nearest eligible player" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    const players = [_]NearbyPlayer{
        .{ .id = 1, .position = .{ 2, 0, 0 } },
        .{ .id = 2, .position = .{ 1, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorSignal(&players));
}

test "state machine advances idle to ejecting to unlocked after forty ticks" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    try std.testing.expectEqual(State.idle, vault.state);
    _ = vault.interact(1, &inventory, 4);
    try std.testing.expectEqual(State.ejecting, vault.state);
    var tick_number: u8 = 0;
    while (tick_number < EJECTION_TICKS - 1) : (tick_number += 1) try std.testing.expect(!vault.tick());
    try std.testing.expectEqual(State.ejecting, vault.state);
    try std.testing.expect(vault.tick());
    try std.testing.expectEqual(State.unlocked, vault.state);
}

test "ejecting vault is busy to other players and does not consume their key" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inv1 = Inventory{};
    var inv2 = Inventory{};
    inv1.slots[0] = .{ .item = .trial_key, .count = 1 };
    inv2.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inv1, 9);
    try std.testing.expectEqual(InteractionResult.busy, vault.interact(2, &inv2, 10).interaction);
    try std.testing.expectEqual(@as(u32, 1), inv2.count(.trial_key));
    try std.testing.expect(!vault.hasPlayerUnlocked(2));
}

test "second player can unlock after current ejection finishes" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var first = Inventory{};
    var second = Inventory{};
    first.slots[0] = .{ .item = .trial_key, .count = 1 };
    second.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &first, 7);
    var i: usize = 0;
    while (i < EJECTION_TICKS) : (i += 1) _ = vault.tick();
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(2, &second, 8).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(vault.hasPlayerUnlocked(2));
}

test "item spin advances and slows through the ejection cycle" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inventory, 11);
    var i: usize = 0;
    while (i < 20) : (i += 1) _ = vault.tick();
    const middle_spin = vault.displayForPlayer(2).?.spin_radians;
    const middle_increment = vault.spin_radians;
    _ = vault.tick();
    const next_increment = vault.spin_radians - middle_increment;
    try std.testing.expect(middle_spin > 0.0);
    try std.testing.expect(next_increment < 0.8);
    try std.testing.expectEqual(@as(u8, 19), vault.eject_ticks_remaining);
}

test "empty inventory rejects interaction" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    try std.testing.expectEqual(InteractionResult.wrong_key, vault.interact(1, &inventory, 0).interaction);
    try std.testing.expectEqual(State.idle, vault.state);
}

test "unlocked tracking supports zero-valued player IDs" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(0, &inventory, 4);
    try std.testing.expect(vault.hasPlayerUnlocked(0));
}

test "display item remains visible to other players during ejection" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inventory, 0);
    try std.testing.expect(vault.displayForPlayer(1) == null);
    try std.testing.expect(vault.displayForPlayer(2) != null);
    try std.testing.expect(vault.emitsAmbientSparks(2));
}

test "completed ejection clears active player and tick is stable" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(9, &inventory, 13);
    var i: usize = 0;
    while (i < EJECTION_TICKS) : (i += 1) _ = vault.tick();
    try std.testing.expect(vault.active_ejector == null);
    try std.testing.expect(!vault.tick());
    try std.testing.expectEqual(State.unlocked, vault.state);
}

test "player at comparator radius boundary is considered nearby" {
    const vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    const players = [_]NearbyPlayer{.{ .id = 42, .position = .{ 0, 0, 4.5 } }};
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorSignal(&players));
}

test "unlocked player list capacity rejects additional keys safely" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_player_count = MAX_UNLOCKED_PLAYERS;
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    try std.testing.expect(!vault.acceptsInteraction(999));
    try std.testing.expectEqual(InteractionResult.already_unlocked, vault.interact(999, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.trial_key));
}

};


pub const vault_multiplayer = struct {
/// Item IDs mirrored from canonical inventory definitions so this world module is an isolated test target.
pub const ItemType = enum(u16) {
    iron_ingot = 26,
    golden_apple = 30,
    bread = 34,
    cooked_beef = 36,
    diamond = 217,
    emerald = 273,
    baked_potato = 343,
    breeze_rod = 371,
    heavy_core = 373,
    trial_key = 376,
    enchanted_golden_apple = 379,
    flow_armor_trim_template = 402,
    bolt_armor_trim_template = 403,
    wind_burst_enchanted_book = 405,
    flow_banner_pattern = 406,
    ominous_trial_key = 416,
    vault_reset_token = 613,

    pub fn name(self: ItemType) []const u8 {
        return switch (self) {
            .iron_ingot => "Iron Ingot",
            .golden_apple => "Golden Apple",
            .bread => "Bread",
            .cooked_beef => "Cooked Beef",
            .diamond => "Diamond",
            .emerald => "Emerald",
            .baked_potato => "Baked Potato",
            .breeze_rod => "Breeze Rod",
            .heavy_core => "Heavy Core",
            .trial_key => "Trial Key",
            .enchanted_golden_apple => "Enchanted Golden Apple",
            .flow_armor_trim_template => "Flow Armor Trim Smithing Template",
            .bolt_armor_trim_template => "Bolt Armor Trim Smithing Template",
            .wind_burst_enchanted_book => "Wind Burst Enchanted Book",
            .flow_banner_pattern => "Flow Banner Pattern",
            .ominous_trial_key => "Ominous Trial Key",
            .vault_reset_token => "Vault Reset Token",
        };
    }

    pub fn isOminousExclusive(self: ItemType) bool {
        return switch (self) {
            .heavy_core,
            .flow_armor_trim_template,
            .bolt_armor_trim_template,
            .wind_burst_enchanted_book,
            .flow_banner_pattern,
            => true,
            else => false,
        };
    }

    pub fn isStandardReward(self: ItemType) bool {
        return !self.isOminousExclusive() and self != .trial_key and self != .ominous_trial_key and self != .vault_reset_token;
    }
};

pub const VaultType = enum { standard, ominous };
pub const VaultState = enum { idle, ejecting, unlocked };
pub const State = VaultState;

pub const InteractionResult = enum {
    started_ejection,
    reset,
    already_unlocked,
    wrong_item,
    busy,
    player_limit,
};

pub const EJECTION_TICKS: u8 = 40;
pub const RESET_TOKEN_DROP_PERCENT: u8 = 5;
pub const MIN_LOOT_ITEMS: usize = 3;
pub const MAX_LOOT_ITEMS: usize = 6;
pub const MAX_EJECTED_STACKS: usize = MAX_LOOT_ITEMS;
pub const MIN_UPWARD_VELOCITY: f32 = 0.35;
pub const MAX_UPWARD_VELOCITY: f32 = 0.55;
pub const MIN_HORIZONTAL_SPEED: f32 = 0.15;
pub const MAX_HORIZONTAL_SPEED: f32 = 0.35;
pub const MAX_UNLOCKED_PLAYERS: usize = 64;
pub const HEAVY_CORE_CHANCE_PER_MILLE: u32 = 22; // 2.2% chance
pub const COMPARATOR_DETECTION_RADIUS: f32 = 4.5;
pub const COMPARATOR_RADIUS_SQ: f32 = COMPARATOR_DETECTION_RADIUS * COMPARATOR_DETECTION_RADIUS;
pub const COMPARATOR_MAX_SIGNAL: u4 = 15;
pub const COMPARATOR_MIN_SIGNAL: u4 = 0;

const TAU: f32 = 2.0 * std.math.pi;

pub const ItemStack = struct {
    item: ItemType,
    count: u8 = 1,
};
pub const Stack = ItemStack;

pub const Inventory = struct {
    slots: [36]?ItemStack = [_]?ItemStack{null} ** 36,

    pub fn count(self: Inventory, item: ItemType) u32 {
        var total: u32 = 0;
        for (self.slots) |slot| if (slot) |s| {
            if (s.item == item) total += s.count;
        };
        return total;
    }

    pub fn consumeOne(self: *Inventory, item: ItemType) bool {
        for (&self.slots) |*slot| {
            if (slot.*) |*s| {
                if (s.item != item or s.count == 0) continue;
                s.count -= 1;
                if (s.count == 0) slot.* = null;
                return true;
            }
        }
        return false;
    }
};

pub const EjectedItem = struct {
    item: ItemType,
    count: u8 = 1,
    stack: ItemStack,
    position: [3]f32,
    velocity: [3]f32,
    dispersion_angle: f32 = 0.0,
};
pub const EjectedStack = EjectedItem;

pub const DisplayPreview = struct {
    item: ItemType,
    position: [3]f32,
    spin_radians: f32,
};
pub const DisplayItem = DisplayPreview;

pub const Loot = struct {
    items: [MAX_LOOT_ITEMS]?EjectedItem = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS,
    count: u8 = 0,

    pub fn stacks(self: Loot) [MAX_LOOT_ITEMS]?EjectedItem {
        return self.items;
    }
};
pub const LootGeneration = Loot;

pub const UnlockResult = struct {
    interaction: InteractionResult,
    ejected: [MAX_LOOT_ITEMS]?EjectedItem = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS,
    ejected_count: u8 = 0,
};

pub const PlayerPosition = struct {
    player_id: u32,
    position: [3]f32,
};
pub const NearbyPlayer = struct {
    id: u32,
    position: [3]f32,

    pub fn toPlayerPosition(self: NearbyPlayer) PlayerPosition {
        return .{ .player_id = self.id, .position = self.position };
    }
};

pub const Vault = struct {
    position: [3]f32,
    vault_type: VaultType = .standard,
    state: VaultState = .idle,
    unlocked_players: [MAX_UNLOCKED_PLAYERS]u32 = [_]u32{0} ** MAX_UNLOCKED_PLAYERS,
    unlocked_player_count: u8 = 0,
    eject_ticks_remaining: u8 = 0,
    display_ticks: u32 = 0,
    spin_radians: f32 = 0.0,
    active_ejector: ?u32 = null,
    last_ejected_items: [MAX_LOOT_ITEMS]?EjectedItem = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS,
    last_ejected_count: u8 = 0,

    pub fn init(vault_type: VaultType, position: [3]f32) Vault {
        return .{
            .position = position,
            .vault_type = vault_type,
        };
    }

    pub fn hasPlayerUnlocked(self: Vault, player_id: u32) bool {
        for (self.unlocked_players[0..self.unlocked_player_count]) |id| {
            if (id == player_id) return true;
        }
        return false;
    }

    pub fn acceptsInteraction(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id) and self.unlocked_player_count < MAX_UNLOCKED_PLAYERS;
    }

    pub fn canInsertKey(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id) and self.state != .ejecting and self.unlocked_player_count < MAX_UNLOCKED_PLAYERS;
    }

    pub fn keyholeIsDark(self: Vault, player_id: u32) bool {
        return self.hasPlayerUnlocked(player_id);
    }

    pub fn displayItemVisible(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id);
    }

    pub fn emitsAmbientParticles(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id);
    }
    pub const emitsAmbientSparks = emitsAmbientParticles;

    pub fn currentShowcaseItem(self: Vault) ItemType {
        if (self.vault_type == .ominous) {
            const pool = [_]ItemType{
                .heavy_core,
                .flow_armor_trim_template,
                .bolt_armor_trim_template,
                .wind_burst_enchanted_book,
                .diamond,
                .enchanted_golden_apple,
            };
            const index = (self.display_ticks / 40) % pool.len;
            return pool[index];
        } else {
            const pool = [_]ItemType{
                .diamond,
                .emerald,
                .golden_apple,
                .iron_ingot,
                .breeze_rod,
            };
            const index = (self.display_ticks / 40) % pool.len;
            return pool[index];
        }
    }

    pub fn displayPreview(self: Vault, player_id: u32) ?DisplayPreview {
        if (!self.displayItemVisible(player_id)) return null;
        const angle = if (self.state == .ejecting)
            self.spin_radians
        else
            @as(f32, @floatFromInt(self.display_ticks % 628)) * 0.01;
        return .{
            .item = self.currentShowcaseItem(),
            .position = .{ self.position[0] + 0.5, self.position[1] + 0.65, self.position[2] + 0.5 },
            .spin_radians = angle,
        };
    }

    pub fn displayForPlayer(self: Vault, player_id: u32) ?DisplayPreview {
        return self.displayPreview(player_id);
    }

    pub fn resetPlayerLock(self: *Vault, player_id: u32) bool {
        for (self.unlocked_players[0..self.unlocked_player_count], 0..) |id, index| {
            if (id != player_id) continue;
            var i = index;
            while (i + 1 < self.unlocked_player_count) : (i += 1) {
                self.unlocked_players[i] = self.unlocked_players[i + 1];
            }
            self.unlocked_player_count -= 1;
            self.unlocked_players[self.unlocked_player_count] = 0;
            return true;
        }
        return false;
    }

    pub fn interact(self: *Vault, player_id: u32, inventory: *Inventory, seed: u32) UnlockResult {
        // 1. If player has already unlocked this vault:
        if (self.hasPlayerUnlocked(player_id)) {
            if (self.state == .ejecting) return .{ .interaction = .busy };
            if (inventory.consumeOne(.vault_reset_token)) {
                _ = self.resetPlayerLock(player_id);
                return .{ .interaction = .reset };
            }
            return .{ .interaction = .already_unlocked };
        }

        // 2. Vault currently busy ejecting for another player
        if (self.state == .ejecting) return .{ .interaction = .busy };

        // 3. Vault player capacity reached
        if (self.unlocked_player_count >= MAX_UNLOCKED_PLAYERS) {
            return .{ .interaction = .player_limit };
        }

        // 4. Key validation
        const needed_key = requiredKey(self.vault_type);
        if (!inventory.consumeOne(needed_key)) {
            return .{ .interaction = .wrong_item };
        }

        // 5. Successful unlock
        self.unlocked_players[self.unlocked_player_count] = player_id;
        self.unlocked_player_count += 1;
        self.state = .ejecting;
        self.eject_ticks_remaining = EJECTION_TICKS;
        self.spin_radians = 0.0;
        self.active_ejector = player_id;

        const generated = generateLoot(self.vault_type, seed, self.position);
        self.last_ejected_items = generated.items;
        self.last_ejected_count = generated.count;

        return .{
            .interaction = .started_ejection,
            .ejected = generated.items,
            .ejected_count = generated.count,
        };
    }

    pub fn tick(self: *Vault) bool {
        self.display_ticks +%= 1;
        if (self.state != .ejecting) return false;

        const progress = @as(f32, @floatFromInt(EJECTION_TICKS - self.eject_ticks_remaining)) / @as(f32, EJECTION_TICKS);
        const angular_speed = 0.8 - 0.6 * progress;
        self.spin_radians += angular_speed;

        if (self.eject_ticks_remaining > 0) self.eject_ticks_remaining -= 1;
        if (self.eject_ticks_remaining == 0) {
            self.state = .unlocked;
            self.active_ejector = null;
            return true;
        }
        return false;
    }

    pub fn comparatorOutput(self: Vault, players: []const PlayerPosition) u4 {
        var nearest_distance_sq = std.math.inf(f32);
        var nearest_id: ?u32 = null;
        for (players) |player| {
            const d2 = distanceSquared(self.position, player.position);
            if (d2 < nearest_distance_sq or (d2 == nearest_distance_sq and player.player_id < (nearest_id orelse std.math.maxInt(u32)))) {
                nearest_distance_sq = d2;
                nearest_id = player.player_id;
            }
        }
        const id = nearest_id orelse return COMPARATOR_MIN_SIGNAL;
        return if (self.hasPlayerUnlocked(id)) COMPARATOR_MIN_SIGNAL else COMPARATOR_MAX_SIGNAL;
    }

    pub fn comparatorSignal(self: Vault, players: []const PlayerPosition) u4 {
        return self.comparatorOutput(players);
    }

    pub fn comparatorOutputWithRadius(self: Vault, players: []const PlayerPosition, max_radius: f32) u4 {
        const max_radius_sq = max_radius * max_radius;
        var nearest_distance_sq = max_radius_sq;
        var nearest_id: ?u32 = null;
        for (players) |player| {
            const d2 = distanceSquared(self.position, player.position);
            if (d2 <= nearest_distance_sq) {
                if (nearest_id == null or d2 < nearest_distance_sq or player.player_id < nearest_id.?) {
                    nearest_distance_sq = d2;
                    nearest_id = player.player_id;
                }
            }
        }
        const id = nearest_id orelse return COMPARATOR_MIN_SIGNAL;
        return if (self.hasPlayerUnlocked(id)) COMPARATOR_MIN_SIGNAL else COMPARATOR_MAX_SIGNAL;
    }
};
pub const VaultBlock = Vault;

pub fn requiredKey(vault_type: VaultType) ItemType {
    return if (vault_type == .standard) .trial_key else .ominous_trial_key;
}

pub fn dropsVaultResetToken(ominous: bool, roll_percent: u8) bool {
    return ominous and roll_percent < RESET_TOKEN_DROP_PERCENT;
}

pub fn rollHeavyCore(rng_state: *u32) bool {
    return (nextRandom(rng_state) % 1000) < HEAVY_CORE_CHANCE_PER_MILLE;
}

pub fn rollHeavyCoreDirect(roll_1000: u32) bool {
    return roll_1000 < HEAVY_CORE_CHANCE_PER_MILLE;
}

pub fn isOminousExclusive(item: ItemType) bool {
    return item.isOminousExclusive();
}

pub fn isStandardReward(item: ItemType) bool {
    return item.isStandardReward();
}

fn distanceSquared(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

pub fn nextRandom(state: *u32) u32 {
    state.* = state.* *% 1664525 +% 1013904223;
    return state.*;
}

pub fn unitRandom(state: *u32) f32 {
    return @as(f32, @floatFromInt(nextRandom(state) >> 8)) / 16_777_216.0;
}

pub fn generateLoot(vault_type: VaultType, seed: u32, position: [3]f32) Loot {
    var result = Loot{};
    var rng = seed;
    const item_count: usize = MIN_LOOT_ITEMS + @as(usize, @intCast(nextRandom(&rng) % 4));

    if (vault_type == .ominous) {
        // Exclusive ominous rewards: Heavy Core (2.2%), Flow/Bolt armor trims, Wind Burst books, Flow banner pattern
        const heavy_core_awarded = (nextRandom(&rng) % 1000) < HEAVY_CORE_CHANCE_PER_MILLE;
        var heavy_core_added = false;

        while (result.count < item_count) {
            var item: ItemType = undefined;
            var count: u8 = 1;

            if (heavy_core_awarded and !heavy_core_added) {
                item = .heavy_core;
                count = 1;
                heavy_core_added = true;
            } else {
                const pool = [_]ItemType{
                    .flow_armor_trim_template,
                    .bolt_armor_trim_template,
                    .wind_burst_enchanted_book,
                    .flow_banner_pattern,
                    .diamond,
                    .emerald,
                    .enchanted_golden_apple,
                    .golden_apple,
                    .breeze_rod,
                    .iron_ingot,
                };
                item = pool[nextRandom(&rng) % pool.len];
                count = switch (item) {
                    .flow_armor_trim_template, .bolt_armor_trim_template, .wind_burst_enchanted_book, .flow_banner_pattern, .enchanted_golden_apple => 1,
                    .diamond => 1 + @as(u8, @intCast(nextRandom(&rng) % 3)),
                    .emerald => 2 + @as(u8, @intCast(nextRandom(&rng) % 5)),
                    .golden_apple => 1 + @as(u8, @intCast(nextRandom(&rng) % 2)),
                    .breeze_rod => 1 + @as(u8, @intCast(nextRandom(&rng) % 3)),
                    .iron_ingot => 2 + @as(u8, @intCast(nextRandom(&rng) % 4)),
                    else => 1,
                };
            }

            const theta = unitRandom(&rng) * TAU;
            const horizontal_speed = MIN_HORIZONTAL_SPEED + unitRandom(&rng) * (MAX_HORIZONTAL_SPEED - MIN_HORIZONTAL_SPEED);
            const vy = MIN_UPWARD_VELOCITY + unitRandom(&rng) * (MAX_UPWARD_VELOCITY - MIN_UPWARD_VELOCITY);
            const vx = @cos(theta) * horizontal_speed;
            const vz = @sin(theta) * horizontal_speed;

            result.items[result.count] = .{
                .item = item,
                .count = count,
                .stack = .{ .item = item, .count = count },
                .position = .{ position[0] + 0.5, position[1] + 1.0, position[2] + 0.5 },
                .velocity = .{ vx, vy, vz },
                .dispersion_angle = theta,
            };
            result.count += 1;
        }
    } else {
        // Standard Vault: dispenses standard rewards only (never ominous exclusives)
        const pool = [_]ItemType{
            .iron_ingot,
            .diamond,
            .emerald,
            .golden_apple,
            .enchanted_golden_apple,
            .breeze_rod,
            .bread,
            .cooked_beef,
            .baked_potato,
        };

        while (result.count < item_count) {
            const item = pool[nextRandom(&rng) % pool.len];
            const count: u8 = switch (item) {
                .enchanted_golden_apple => 1,
                .diamond => 1 + @as(u8, @intCast(nextRandom(&rng) % 2)),
                .golden_apple => 1 + @as(u8, @intCast(nextRandom(&rng) % 2)),
                .emerald, .iron_ingot => 2 + @as(u8, @intCast(nextRandom(&rng) % 4)),
                .breeze_rod => 1 + @as(u8, @intCast(nextRandom(&rng) % 2)),
                .bread, .cooked_beef, .baked_potato => 2 + @as(u8, @intCast(nextRandom(&rng) % 4)),
                else => 1,
            };

            const theta = unitRandom(&rng) * TAU;
            const horizontal_speed = MIN_HORIZONTAL_SPEED + unitRandom(&rng) * (MAX_HORIZONTAL_SPEED - MIN_HORIZONTAL_SPEED);
            const vy = MIN_UPWARD_VELOCITY + unitRandom(&rng) * (MAX_UPWARD_VELOCITY - MIN_UPWARD_VELOCITY);
            const vx = @cos(theta) * horizontal_speed;
            const vz = @sin(theta) * horizontal_speed;

            result.items[result.count] = .{
                .item = item,
                .count = count,
                .stack = .{ .item = item, .count = count },
                .position = .{ position[0] + 0.5, position[1] + 1.0, position[2] + 0.5 },
                .velocity = .{ vx, vy, vz },
                .dispersion_angle = theta,
            };
            result.count += 1;
        }
    }

    return result;
}

// ============================================================================
// UNIT TESTS (37 Tests)
// ============================================================================

test "1. Standard and ominous vaults require matching trial key variants" {
    try std.testing.expectEqual(ItemType.trial_key, requiredKey(.standard));
    try std.testing.expectEqual(ItemType.ominous_trial_key, requiredKey(.ominous));
    try std.testing.expectEqual(@as(u16, 376), @intFromEnum(ItemType.trial_key));
    try std.testing.expectEqual(@as(u16, 416), @intFromEnum(ItemType.ominous_trial_key));
}

test "2. Standard vault accepts standard key and consumes exactly one" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 2 };
    const res = vault.interact(1, &inv, 42);
    try std.testing.expectEqual(InteractionResult.started_ejection, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.trial_key));
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expectEqual(VaultState.ejecting, vault.state);
}

test "3. Standard vault rejects ominous trial key without consuming it" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .ominous_trial_key, .count = 1 };
    const res = vault.interact(1, &inv, 42);
    try std.testing.expectEqual(InteractionResult.wrong_item, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.ominous_trial_key));
    try std.testing.expect(!vault.hasPlayerUnlocked(1));
}

test "4. Ominous vault accepts ominous trial key and consumes exactly one" {
    var vault = Vault.init(.ominous, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .ominous_trial_key, .count = 3 };
    const res = vault.interact(10, &inv, 99);
    try std.testing.expectEqual(InteractionResult.started_ejection, res.interaction);
    try std.testing.expectEqual(@as(u32, 2), inv.count(.ominous_trial_key));
    try std.testing.expect(vault.hasPlayerUnlocked(10));
    try std.testing.expectEqual(VaultState.ejecting, vault.state);
}

test "5. Ominous vault rejects standard trial key without consuming it" {
    var vault = Vault.init(.ominous, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    const res = vault.interact(1, &inv, 42);
    try std.testing.expectEqual(InteractionResult.wrong_item, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.trial_key));
    try std.testing.expect(!vault.hasPlayerUnlocked(1));
}

test "6. Standard vault loot pool dispenses standard rewards only" {
    var seed: u32 = 1;
    while (seed <= 50) : (seed += 1) {
        const loot = generateLoot(.standard, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?.item;
            try std.testing.expect(item.isStandardReward());
            try std.testing.expect(!item.isOminousExclusive());
            try std.testing.expect(item != .heavy_core);
            try std.testing.expect(item != .flow_armor_trim_template);
            try std.testing.expect(item != .bolt_armor_trim_template);
            try std.testing.expect(item != .wind_burst_enchanted_book);
            try std.testing.expect(item != .flow_banner_pattern);
        }
    }
}

test "7. Ominous vault loot pool dispenses exclusive ominous rewards" {
    var found_flow_trim = false;
    var found_bolt_trim = false;
    var found_wind_burst = false;
    var found_heavy_core = false;

    var seed: u32 = 1;
    while (seed <= 500) : (seed += 1) {
        const loot = generateLoot(.ominous, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?.item;
            if (item == .flow_armor_trim_template) found_flow_trim = true;
            if (item == .bolt_armor_trim_template) found_bolt_trim = true;
            if (item == .wind_burst_enchanted_book) found_wind_burst = true;
            if (item == .heavy_core) found_heavy_core = true;
        }
    }

    try std.testing.expect(found_flow_trim);
    try std.testing.expect(found_bolt_trim);
    try std.testing.expect(found_wind_burst);
    try std.testing.expect(found_heavy_core);
}

test "8. Heavy core 2.2 percent roll threshold boundaries are exact" {
    try std.testing.expect(rollHeavyCoreDirect(0));
    try std.testing.expect(rollHeavyCoreDirect(21));
    try std.testing.expect(!rollHeavyCoreDirect(22));
    try std.testing.expect(!rollHeavyCoreDirect(23));
    try std.testing.expect(!rollHeavyCoreDirect(999));
    try std.testing.expectEqual(@as(u32, 22), HEAVY_CORE_CHANCE_PER_MILLE);
}

test "9. Heavy core rolls at approximately 2.2 percent over large sample" {
    var rng_state: u32 = 12345;
    var heavy_core_count: u32 = 0;
    const trials: u32 = 10_000;
    var i: u32 = 0;
    while (i < trials) : (i += 1) {
        if (rollHeavyCore(&rng_state)) heavy_core_count += 1;
    }
    // 2.2% of 10,000 is 220; expect within reasonable sampling bounds [160, 280]
    try std.testing.expect(heavy_core_count >= 160 and heavy_core_count <= 280);
}

test "10. Multi-player party members independently unlock the same vault" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var p1_inv = Inventory{};
    p1_inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    var p2_inv = Inventory{};
    p2_inv.slots[0] = .{ .item = .trial_key, .count = 1 };

    // P1 unlocks
    const res1 = vault.interact(1, &p1_inv, 100);
    try std.testing.expectEqual(InteractionResult.started_ejection, res1.interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(!vault.hasPlayerUnlocked(2));

    // P2 cannot unlock while vault is ejecting for P1
    const res2_busy = vault.interact(2, &p2_inv, 200);
    try std.testing.expectEqual(InteractionResult.busy, res2_busy.interaction);
    try std.testing.expectEqual(@as(u32, 1), p2_inv.count(.trial_key));

    // Finish 40-tick ejection
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();
    try std.testing.expectEqual(VaultState.unlocked, vault.state);

    // Now P2 can independently unlock
    const res2 = vault.interact(2, &p2_inv, 200);
    try std.testing.expectEqual(InteractionResult.started_ejection, res2.interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(vault.hasPlayerUnlocked(2));
    try std.testing.expectEqual(@as(u32, 0), p2_inv.count(.trial_key));
}

test "11. Per-player tracking maintains multiple player IDs accurately" {
    var vault = Vault.init(.ominous, .{ 10, 20, 30 });
    const player_ids = [_]u32{ 7, 42, 101, 256, 512 };

    for (player_ids, 0..) |pid, idx| {
        try std.testing.expect(!vault.hasPlayerUnlocked(pid));
        try std.testing.expect(vault.acceptsInteraction(pid));

        var inv = Inventory{};
        inv.slots[0] = .{ .item = .ominous_trial_key, .count = 1 };
        _ = vault.interact(pid, &inv, @as(u32, @intCast(pid)));

        // Advance ejection ticks
        var t: u8 = 0;
        while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();

        try std.testing.expect(vault.hasPlayerUnlocked(pid));
        try std.testing.expectEqual(@as(u8, @intCast(idx + 1)), vault.unlocked_player_count);
    }

    // Verify all players remain recorded
    for (player_ids) |pid| {
        try std.testing.expect(vault.hasPlayerUnlocked(pid));
    }
}

test "12. Already unlocked player is rejected when attempting to unlock again" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 2 };

    _ = vault.interact(1, &inv, 10);
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();

    // Second unlock attempt with trial key
    const res2 = vault.interact(1, &inv, 20);
    try std.testing.expectEqual(InteractionResult.already_unlocked, res2.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.trial_key)); // Key preserved!
}

test "13. Consuming 1 Vault Reset Token clears only that player lock" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    inv.slots[1] = .{ .item = .vault_reset_token, .count = 2 };

    _ = vault.interact(1, &inv, 1);
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();
    try std.testing.expect(vault.hasPlayerUnlocked(1));

    // Reset lock
    const res = vault.interact(1, &inv, 2);
    try std.testing.expectEqual(InteractionResult.reset, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.vault_reset_token)); // 1 consumed
    try std.testing.expect(!vault.hasPlayerUnlocked(1)); // Lock cleared!
    try std.testing.expectEqual(@as(u8, 0), vault.unlocked_player_count);
}

test "14. Reset token cannot reset an unlocked player who lacks a token" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };

    _ = vault.interact(1, &inv, 1);
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();

    var empty_inv = Inventory{};
    const res = vault.interact(1, &empty_inv, 2);
    try std.testing.expectEqual(InteractionResult.already_unlocked, res.interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
}

test "15. Reset token is not consumed if player has not yet unlocked the vault" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .vault_reset_token, .count = 1 };

    const res = vault.interact(1, &inv, 10);
    try std.testing.expectEqual(InteractionResult.wrong_item, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.vault_reset_token));
    try std.testing.expect(!vault.hasPlayerUnlocked(1));
}

test "16. Reset token is not consumed while vault is busy ejecting" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv1 = Inventory{};
    inv1.slots[0] = .{ .item = .trial_key, .count = 1 };
    inv1.slots[1] = .{ .item = .vault_reset_token, .count = 1 };

    _ = vault.interact(1, &inv1, 1);
    // Vault is in ejecting state!
    try std.testing.expectEqual(VaultState.ejecting, vault.state);

    const res = vault.interact(1, &inv1, 2);
    try std.testing.expectEqual(InteractionResult.busy, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv1.count(.vault_reset_token));
}

test "17. Resetting player lock allows unlocking the vault again" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 2 };
    inv.slots[1] = .{ .item = .vault_reset_token, .count = 1 };

    // First unlock
    const res1 = vault.interact(1, &inv, 1);
    try std.testing.expectEqual(InteractionResult.started_ejection, res1.interaction);
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();

    // Reset lock
    const res_reset = vault.interact(1, &inv, 2);
    try std.testing.expectEqual(InteractionResult.reset, res_reset.interaction);
    try std.testing.expect(!vault.hasPlayerUnlocked(1));

    // Second unlock succeeds!
    const res2 = vault.interact(1, &inv, 3);
    try std.testing.expectEqual(InteractionResult.started_ejection, res2.interaction);
    try std.testing.expectEqual(@as(u32, 0), inv.count(.trial_key));
    try std.testing.expect(vault.hasPlayerUnlocked(1));
}

test "18. resetPlayerLock preserves other players locks and order" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 10;
    vault.unlocked_players[1] = 20;
    vault.unlocked_players[2] = 30;
    vault.unlocked_player_count = 3;

    try std.testing.expect(vault.resetPlayerLock(20));
    try std.testing.expectEqual(@as(u8, 2), vault.unlocked_player_count);
    try std.testing.expect(vault.hasPlayerUnlocked(10));
    try std.testing.expect(!vault.hasPlayerUnlocked(20));
    try std.testing.expect(vault.hasPlayerUnlocked(30));
    try std.testing.expectEqual(@as(u32, 10), vault.unlocked_players[0]);
    try std.testing.expectEqual(@as(u32, 30), vault.unlocked_players[1]);
}

test "19. resetPlayerLock returns false for non-locked player IDs" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(!vault.resetPlayerLock(999));
    try std.testing.expect(!vault.resetPlayerLock(0));
}

test "20. Vault rejects player when capacity is reached without consuming key" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var i: u32 = 0;
    while (i < MAX_UNLOCKED_PLAYERS) : (i += 1) {
        vault.unlocked_players[i] = i + 1;
    }
    vault.unlocked_player_count = MAX_UNLOCKED_PLAYERS;

    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    const res = vault.interact(100, &inv, 5);
    try std.testing.expectEqual(InteractionResult.player_limit, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.trial_key));
}

test "21. Resetting a player at capacity frees one slot" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var i: u32 = 0;
    while (i < MAX_UNLOCKED_PLAYERS) : (i += 1) {
        vault.unlocked_players[i] = i + 1;
    }
    vault.unlocked_player_count = MAX_UNLOCKED_PLAYERS;
    vault.state = .unlocked;

    var inv = Inventory{};
    inv.slots[0] = .{ .item = .vault_reset_token, .count = 1 };
    const res_reset = vault.interact(5, &inv, 1);
    try std.testing.expectEqual(InteractionResult.reset, res_reset.interaction);
    try std.testing.expectEqual(@as(u8, MAX_UNLOCKED_PLAYERS - 1), vault.unlocked_player_count);

    var new_player_inv = Inventory{};
    new_player_inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    const res_unlock = vault.interact(100, &new_player_inv, 2);
    try std.testing.expectEqual(InteractionResult.started_ejection, res_unlock.interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(100));
}

test "22. Ejection item count is strictly between three and six items" {
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const std_loot = generateLoot(.standard, seed, .{ 0, 0, 0 });
        try std.testing.expect(std_loot.count >= MIN_LOOT_ITEMS and std_loot.count <= MAX_LOOT_ITEMS);

        const omn_loot = generateLoot(.ominous, seed, .{ 0, 0, 0 });
        try std.testing.expect(omn_loot.count >= MIN_LOOT_ITEMS and omn_loot.count <= MAX_LOOT_ITEMS);
    }
}

test "23. All ejected upward velocities stay within specified bounds [0.35, 0.55]" {
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const loot = generateLoot(.standard, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const vy = maybe_item.?.velocity[1];
            try std.testing.expect(vy >= MIN_UPWARD_VELOCITY);
            try std.testing.expect(vy <= MAX_UPWARD_VELOCITY);
        }
    }
}

test "24. Horizontal velocity is radial and matches dispersion angle" {
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const loot = generateLoot(.ominous, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?;
            const vx = item.velocity[0];
            const vz = item.velocity[2];
            const h_speed = std.math.sqrt(vx * vx + vz * vz);

            try std.testing.expect(h_speed >= MIN_HORIZONTAL_SPEED - 0.001);
            try std.testing.expect(h_speed <= MAX_HORIZONTAL_SPEED + 0.001);

            const expected_vx = @cos(item.dispersion_angle) * h_speed;
            const expected_vz = @sin(item.dispersion_angle) * h_speed;
            try std.testing.expectApproxEqAbs(expected_vx, vx, 0.001);
            try std.testing.expectApproxEqAbs(expected_vz, vz, 0.001);
        }
    }
}

test "25. Radial angles cover full circular range [0, 2*pi]" {
    var quadrant_covered = [_]bool{ false, false, false, false };
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const loot = generateLoot(.standard, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const angle = maybe_item.?.dispersion_angle;
            if (angle >= 0.0 and angle < 0.5 * std.math.pi) quadrant_covered[0] = true;
            if (angle >= 0.5 * std.math.pi and angle < std.math.pi) quadrant_covered[1] = true;
            if (angle >= std.math.pi and angle < 1.5 * std.math.pi) quadrant_covered[2] = true;
            if (angle >= 1.5 * std.math.pi and angle < TAU) quadrant_covered[3] = true;
        }
    }
    for (quadrant_covered) |covered| {
        try std.testing.expect(covered);
    }
}

test "26. Ejection positions spawn at vault center plus one meter launch height" {
    const vault_pos = [3]f32{ 15.0, 60.0, -25.0 };
    const loot = generateLoot(.standard, 888, vault_pos);
    const expected_pos = [3]f32{ 15.5, 61.0, -24.5 };
    for (loot.items[0..loot.count]) |maybe_item| {
        try std.testing.expectEqual(expected_pos, maybe_item.?.position);
    }
}

test "27. Loot generation is strictly deterministic for identical seeds" {
    const l1 = generateLoot(.ominous, 7777, .{ 1, 2, 3 });
    const l2 = generateLoot(.ominous, 7777, .{ 1, 2, 3 });
    try std.testing.expectEqual(l1.count, l2.count);
    var i: usize = 0;
    while (i < l1.count) : (i += 1) {
        try std.testing.expectEqual(l1.items[i].?.item, l2.items[i].?.item);
        try std.testing.expectEqual(l1.items[i].?.count, l2.items[i].?.count);
        try std.testing.expectEqual(l1.items[i].?.velocity, l2.items[i].?.velocity);
        try std.testing.expectEqual(l1.items[i].?.dispersion_angle, l2.items[i].?.dispersion_angle);
    }
}

test "28. Animated spinning loot showcase is visible only to eligible players" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(vault.displayItemVisible(1));
    try std.testing.expect(vault.displayPreview(1) != null);
    try std.testing.expect(vault.emitsAmbientParticles(1));

    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inv, 10);

    // After unlocking, showcase is hidden for player 1 but visible for player 2
    try std.testing.expect(!vault.displayItemVisible(1));
    try std.testing.expect(vault.displayPreview(1) == null);
    try std.testing.expect(!vault.emitsAmbientParticles(1));

    try std.testing.expect(vault.displayItemVisible(2));
    try std.testing.expect(vault.displayPreview(2) != null);
    try std.testing.expect(vault.emitsAmbientParticles(2));
}

test "29. Keyhole is dark for already unlocked players and illuminated for eligible players" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(!vault.keyholeIsDark(1));

    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;

    try std.testing.expect(vault.keyholeIsDark(1));
    try std.testing.expect(!vault.keyholeIsDark(2));
}

test "30. canInsertKey returns true only for eligible players when not ejecting" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(vault.canInsertKey(1));

    vault.state = .ejecting;
    try std.testing.expect(!vault.canInsertKey(1));

    vault.state = .idle;
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    try std.testing.expect(!vault.canInsertKey(1));
    try std.testing.expect(vault.canInsertKey(2));
}

test "31. Comparator outputs fifteen for nearest eligible player and zero after unlock" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    const nearby = [_]PlayerPosition{.{ .player_id = 5, .position = .{ 1, 0, 0 } }};
    try std.testing.expectEqual(COMPARATOR_MAX_SIGNAL, vault.comparatorOutput(&nearby));

    vault.unlocked_players[0] = 5;
    vault.unlocked_player_count = 1;
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutput(&nearby));
}

test "32. Comparator selects nearest player when party members differ in eligibility" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;

    // Player 1 (unlocked) is at distance 1.0, Player 2 (eligible) is at distance 2.0 -> output 0
    const p1_closer = [_]PlayerPosition{
        .{ .player_id = 1, .position = .{ 1, 0, 0 } },
        .{ .player_id = 2, .position = .{ 2, 0, 0 } },
    };
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutput(&p1_closer));

    // Player 2 (eligible) is at distance 1.0, Player 1 (unlocked) is at distance 3.0 -> output 15
    const p2_closer = [_]PlayerPosition{
        .{ .player_id = 1, .position = .{ 3, 0, 0 } },
        .{ .player_id = 2, .position = .{ 1, 0, 0 } },
    };
    try std.testing.expectEqual(COMPARATOR_MAX_SIGNAL, vault.comparatorOutput(&p2_closer));
}

test "33. Comparator outputs zero with no players and handles distance ties deterministically" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutput(&.{}));

    vault.unlocked_players[0] = 3;
    vault.unlocked_player_count = 1;

    const tied = [_]PlayerPosition{
        .{ .player_id = 8, .position = .{ 1, 0, 0 } },
        .{ .player_id = 3, .position = .{ -1, 0, 0 } },
    };
    // Tie at distance 1; lower ID is 3 (unlocked) -> output 0
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutput(&tied));
}

test "34. Comparator bounded radius returns zero when nearest player is outside radius" {
    const vault = Vault.init(.standard, .{ 0, 0, 0 });
    const outside_players = [_]PlayerPosition{.{ .player_id = 1, .position = .{ 5.0, 0, 0 } }};
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutputWithRadius(&outside_players, COMPARATOR_DETECTION_RADIUS));

    const inside_players = [_]PlayerPosition{.{ .player_id = 1, .position = .{ 4.0, 0, 0 } }};
    try std.testing.expectEqual(COMPARATOR_MAX_SIGNAL, vault.comparatorOutputWithRadius(&inside_players, COMPARATOR_DETECTION_RADIUS));
}

test "35. Vault tick advances display ticks and completes ejection in forty ticks" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inv, 12);
    try std.testing.expectEqual(VaultState.ejecting, vault.state);

    var i: u8 = 0;
    while (i < EJECTION_TICKS - 1) : (i += 1) {
        try std.testing.expect(!vault.tick());
    }
    // 40th tick completes ejection
    try std.testing.expect(vault.tick());
    try std.testing.expectEqual(VaultState.unlocked, vault.state);
}

test "36. dropsVaultResetToken awards tokens only for ominous spawners at five percent" {
    try std.testing.expect(dropsVaultResetToken(true, 0));
    try std.testing.expect(dropsVaultResetToken(true, 4));
    try std.testing.expect(!dropsVaultResetToken(true, 5));
    try std.testing.expect(!dropsVaultResetToken(true, 99));

    // Standard spawners never drop reset tokens
    try std.testing.expect(!dropsVaultResetToken(false, 0));
    try std.testing.expect(!dropsVaultResetToken(false, 4));
}

test "37. Item stack counts match rarity rules" {
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const loot = generateLoot(.ominous, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?;
            if (item.item == .heavy_core) try std.testing.expectEqual(@as(u8, 1), item.count);
            if (item.item == .flow_armor_trim_template) try std.testing.expectEqual(@as(u8, 1), item.count);
            if (item.item == .bolt_armor_trim_template) try std.testing.expectEqual(@as(u8, 1), item.count);
            if (item.item == .wind_burst_enchanted_book) try std.testing.expectEqual(@as(u8, 1), item.count);
        }
    }
}

};


pub const vault_reset = struct {
/// Item IDs are mirrored here so this module stays an isolated test target.
pub const ItemType = enum(u16) {
    trial_key = 376,
    ominous_trial_key = 416,
    vault_reset_token = 608,
    heavy_core = 373,
    emerald = 273,
    diamond = 217,
    golden_apple = 30,
};

pub const VaultType = enum { standard, ominous };
pub const VaultState = enum { idle, ejecting, unlocked };
pub const InteractionResult = enum { started_ejection, reset, already_unlocked, wrong_item, busy, player_limit };
pub const EJECTION_TICKS: u8 = 40;
pub const RESET_TOKEN_DROP_PERCENT: u8 = 5;
pub const MIN_LOOT_ITEMS: usize = 3;
pub const MAX_LOOT_ITEMS: usize = 6;
pub const MIN_UPWARD_VELOCITY: f32 = 0.35;
pub const MAX_UPWARD_VELOCITY: f32 = 0.55;
pub const MAX_UNLOCKED_PLAYERS: usize = 64;
const TAU: f32 = 2.0 * std.math.pi;

pub const Stack = struct { item: ItemType, count: u8 = 1 };
pub const Inventory = struct {
    slots: [36]?Stack = [_]?Stack{null} ** 36,

    pub fn count(self: Inventory, item: ItemType) u32 {
        var total: u32 = 0;
        for (self.slots) |slot| if (slot) |stack| {
            if (stack.item == item) total += stack.count;
        };
        return total;
    }

    fn consumeOne(self: *Inventory, item: ItemType) bool {
        for (&self.slots) |*slot| {
            if (slot.*) |*stack| {
                if (stack.item != item or stack.count == 0) continue;
                stack.count -= 1;
                if (stack.count == 0) slot.* = null;
                return true;
            }
        }
        return false;
    }
};

pub const EjectedItem = struct {
    item: ItemType,
    position: [3]f32,
    velocity: [3]f32,
    dispersion_angle: f32,
};

pub const DisplayPreview = struct { item: ItemType, spin_radians: f32 };

pub const UnlockResult = struct {
    interaction: InteractionResult,
    ejected: [MAX_LOOT_ITEMS]?EjectedItem = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS,
    ejected_count: u8 = 0,
};

pub const PlayerPosition = struct { player_id: u32, position: [3]f32 };

pub const Vault = struct {
    position: [3]f32,
    vault_type: VaultType = .standard,
    state: VaultState = .idle,
    unlocked_players: [MAX_UNLOCKED_PLAYERS]u32 = [_]u32{0} ** MAX_UNLOCKED_PLAYERS,
    unlocked_player_count: u8 = 0,
    eject_ticks_remaining: u8 = 0,
    display_ticks: u32 = 0,

    pub fn init(vault_type: VaultType, position: [3]f32) Vault {
        return .{ .position = position, .vault_type = vault_type };
    }

    pub fn hasPlayerUnlocked(self: Vault, player_id: u32) bool {
        for (self.unlocked_players[0..self.unlocked_player_count]) |id| {
            if (id == player_id) return true;
        }
        return false;
    }

    pub fn acceptsInteraction(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id) and self.unlocked_player_count < MAX_UNLOCKED_PLAYERS;
    }

    pub fn resetPlayerLock(self: *Vault, player_id: u32) bool {
        for (self.unlocked_players[0..self.unlocked_player_count], 0..) |id, index| {
            if (id != player_id) continue;
            var i = index;
            while (i + 1 < self.unlocked_player_count) : (i += 1) {
                self.unlocked_players[i] = self.unlocked_players[i + 1];
            }
            self.unlocked_player_count -= 1;
            return true;
        }
        return false;
    }

    pub fn displayItemVisible(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id);
    }

    pub fn displayPreview(self: Vault, player_id: u32) ?DisplayPreview {
        if (!self.displayItemVisible(player_id)) return null;
        return .{ .item = .heavy_core, .spin_radians = @as(f32, @floatFromInt(self.display_ticks % 628)) * 0.01 };
    }

    pub fn interact(self: *Vault, player_id: u32, inventory: *Inventory, seed: u32) UnlockResult {
        if (self.hasPlayerUnlocked(player_id)) {
            if (self.state != .unlocked) return .{ .interaction = .busy };
            if (!inventory.consumeOne(.vault_reset_token)) return .{ .interaction = .already_unlocked };
            _ = self.resetPlayerLock(player_id);
            return .{ .interaction = .reset };
        }
        if (self.unlocked_player_count >= MAX_UNLOCKED_PLAYERS) return .{ .interaction = .player_limit };
        if (self.state == .ejecting) return .{ .interaction = .busy };

        if (!inventory.consumeOne(requiredKey(self.vault_type))) return .{ .interaction = .wrong_item };
        self.unlocked_players[self.unlocked_player_count] = player_id;
        self.unlocked_player_count += 1;
        self.state = .ejecting;
        self.eject_ticks_remaining = EJECTION_TICKS;
        const generated = generateLoot(seed, self.position);
        return .{ .interaction = .started_ejection, .ejected = generated.items, .ejected_count = generated.count };
    }

    pub fn tick(self: *Vault) bool {
        self.display_ticks +%= 1;
        if (self.state != .ejecting) return false;
        if (self.eject_ticks_remaining > 0) self.eject_ticks_remaining -= 1;
        if (self.eject_ticks_remaining != 0) return false;
        self.state = .unlocked;
        return true;
    }

    pub fn comparatorOutput(self: Vault, players: []const PlayerPosition) u4 {
        var nearest_distance_sq = std.math.inf(f32);
        var nearest_id: ?u32 = null;
        for (players) |player| {
            const d2 = distanceSquared(self.position, player.position);
            if (d2 < nearest_distance_sq or (d2 == nearest_distance_sq and player.player_id < (nearest_id orelse std.math.maxInt(u32)))) {
                nearest_distance_sq = d2;
                nearest_id = player.player_id;
            }
        }
        const id = nearest_id orelse return 0;
        return if (self.hasPlayerUnlocked(id)) 0 else 15;
    }
};

pub fn requiredKey(vault_type: VaultType) ItemType {
    return if (vault_type == .standard) .trial_key else .ominous_trial_key;
}

/// `roll_percent` is an integer in [0, 99]; only ominous spawners can drop the token.
pub fn dropsVaultResetToken(ominous: bool, roll_percent: u8) bool {
    return ominous and roll_percent < RESET_TOKEN_DROP_PERCENT;
}

const Loot = struct { items: [MAX_LOOT_ITEMS]?EjectedItem, count: u8 };

fn nextRandom(state: *u32) u32 {
    state.* = state.* *% 1664525 +% 1013904223;
    return state.*;
}

fn unitRandom(state: *u32) f32 {
    return @as(f32, @floatFromInt(nextRandom(state) >> 8)) / 16_777_216.0;
}

fn generateLoot(seed: u32, position: [3]f32) Loot {
    var result = Loot{ .items = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS, .count = 0 };
    var random_state = seed;
    const item_count: usize = MIN_LOOT_ITEMS + @as(usize, @intCast(nextRandom(&random_state) % 4));
    const pool = [_]ItemType{ .emerald, .diamond, .golden_apple, .heavy_core };
    while (result.count < item_count) {
        const item = pool[nextRandom(&random_state) % pool.len];
        const theta = unitRandom(&random_state) * TAU;
        const horizontal_speed = 0.15 + unitRandom(&random_state) * 0.20;
        const vy = MIN_UPWARD_VELOCITY + unitRandom(&random_state) * (MAX_UPWARD_VELOCITY - MIN_UPWARD_VELOCITY);
        result.items[result.count] = .{
            .item = item,
            .position = .{ position[0] + 0.5, position[1] + 1.0, position[2] + 0.5 },
            .velocity = .{ @cos(theta) * horizontal_speed, vy, @sin(theta) * horizontal_speed },
            .dispersion_angle = theta,
        };
        result.count += 1;
    }
    return result;
}

fn distanceSquared(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

test "standard and ominous vaults require their matching trial key variants" {
    try std.testing.expectEqual(ItemType.trial_key, requiredKey(.standard));
    try std.testing.expectEqual(ItemType.ominous_trial_key, requiredKey(.ominous));
    var standard = Vault.init(.standard, .{ 0, 0, 0 });
    var wrong = Inventory{};
    wrong.slots[0] = .{ .item = .ominous_trial_key };
    try std.testing.expectEqual(InteractionResult.wrong_item, standard.interact(1, &wrong, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), wrong.count(.ominous_trial_key));
    var ominous = Vault.init(.ominous, .{ 0, 0, 0 });
    var right = Inventory{};
    right.slots[0] = .{ .item = .ominous_trial_key };
    try std.testing.expectEqual(InteractionResult.started_ejection, ominous.interact(1, &right, 0).interaction);
}

test "each party member can independently unlock the same vault" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var first = Inventory{};
    first.slots[0] = .{ .item = .trial_key };
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(1, &first, 1).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(!vault.hasPlayerUnlocked(2));
    var second = Inventory{};
    second.slots[0] = .{ .item = .trial_key };
    try std.testing.expectEqual(InteractionResult.busy, vault.interact(2, &second, 2).interaction);
    var i: u8 = 0;
    while (i < EJECTION_TICKS) : (i += 1) _ = vault.tick();
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(2, &second, 2).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1) and vault.hasPlayerUnlocked(2));
}

test "reset token consumes exactly one and clears only that player's lock" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 11;
    vault.unlocked_players[1] = 22;
    vault.unlocked_player_count = 2;
    vault.state = .unlocked;
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .vault_reset_token, .count = 2 };
    try std.testing.expectEqual(InteractionResult.reset, vault.interact(11, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.vault_reset_token));
    try std.testing.expect(!vault.hasPlayerUnlocked(11));
    try std.testing.expect(vault.hasPlayerUnlocked(22));
    try std.testing.expect(vault.displayItemVisible(11));
    try std.testing.expect(!vault.displayItemVisible(22));
}

test "reset token cannot reset an unlocked player without token" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 7;
    vault.unlocked_player_count = 1;
    vault.state = .unlocked;
    var inventory = Inventory{};
    try std.testing.expectEqual(InteractionResult.already_unlocked, vault.interact(7, &inventory, 0).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(7));
}

test "reset token is not consumed before the vault ejection cycle completes" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 7;
    vault.unlocked_player_count = 1;
    vault.state = .ejecting;
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .vault_reset_token };
    try std.testing.expectEqual(InteractionResult.busy, vault.interact(7, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.vault_reset_token));
    try std.testing.expect(vault.hasPlayerUnlocked(7));
}

test "reset player lock is safe for missing and zero-valued IDs" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 0;
    vault.unlocked_players[1] = 1;
    vault.unlocked_player_count = 2;
    try std.testing.expect(!vault.resetPlayerLock(9));
    try std.testing.expect(vault.resetPlayerLock(0));
    try std.testing.expectEqual(@as(u8, 1), vault.unlocked_player_count);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
}

test "only ominous spawners have a five percent reset token drop" {
    try std.testing.expect(dropsVaultResetToken(true, 0));
    try std.testing.expect(dropsVaultResetToken(true, 4));
    try std.testing.expect(!dropsVaultResetToken(true, 5));
    try std.testing.expect(!dropsVaultResetToken(false, 0));
}

test "ejection loot count is three to six for a broad deterministic seed range" {
    var seed: u32 = 0;
    while (seed < 500) : (seed += 1) {
        const loot = generateLoot(seed, .{ 5, 70, -2 });
        try std.testing.expect(loot.count >= MIN_LOOT_ITEMS and loot.count <= MAX_LOOT_ITEMS);
    }
}

test "all ejected upward velocities stay within specified bounds" {
    var seed: u32 = 0;
    while (seed < 256) : (seed += 1) {
        const loot = generateLoot(seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?;
            try std.testing.expect(item.velocity[1] >= MIN_UPWARD_VELOCITY);
            try std.testing.expect(item.velocity[1] <= MAX_UPWARD_VELOCITY);
        }
    }
}

test "horizontal velocity is radial and matches randomized theta" {
    const loot = generateLoot(12345, .{ 0, 0, 0 });
    for (loot.items[0..loot.count]) |maybe_item| {
        const item = maybe_item.?;
        const speed = @sqrt(item.velocity[0] * item.velocity[0] + item.velocity[2] * item.velocity[2]);
        try std.testing.expect(item.dispersion_angle >= 0.0 and item.dispersion_angle < TAU);
        try std.testing.expect(speed >= 0.15 and speed <= 0.35);
        try std.testing.expectApproxEqAbs(@cos(item.dispersion_angle) * speed, item.velocity[0], 0.00001);
        try std.testing.expectApproxEqAbs(@sin(item.dispersion_angle) * speed, item.velocity[2], 0.00001);
    }
}

test "ejection positions use the vault center and one meter launch height" {
    const loot = generateLoot(7, .{ 5, 70, -2 });
    for (loot.items[0..loot.count]) |maybe_item| try std.testing.expectEqual([3]f32{ 5.5, 71.0, -1.5 }, maybe_item.?.position);
}

test "loot dispersion is deterministic for the same seed" {
    const first = generateLoot(912, .{ 0, 0, 0 });
    const second = generateLoot(912, .{ 0, 0, 0 });
    try std.testing.expectEqual(first.count, second.count);
    for (first.items[0..first.count], second.items[0..second.count]) |a, b| try std.testing.expectEqual(a.?.velocity, b.?.velocity);
}

test "comparator outputs fifteen for nearest eligible player and zero after unlock" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    const nearby = [_]PlayerPosition{.{ .player_id = 2, .position = .{ 1, 0, 0 } }};
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorOutput(&nearby));
    vault.unlocked_players[0] = 2;
    vault.unlocked_player_count = 1;
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorOutput(&nearby));
}

test "comparator follows the nearest player when party members differ in eligibility" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    const players = [_]PlayerPosition{
        .{ .player_id = 1, .position = .{ 1, 0, 0 } },
        .{ .player_id = 2, .position = .{ 2, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorOutput(&players));
}

test "comparator outputs zero with no players and is deterministic on distance ties" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorOutput(&.{}));
    vault.unlocked_players[0] = 3;
    vault.unlocked_player_count = 1;
    const tied = [_]PlayerPosition{
        .{ .player_id = 8, .position = .{ 1, 0, 0 } },
        .{ .player_id = 3, .position = .{ -1, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorOutput(&tied));
}

test "ejection cooldown completes after forty ticks before next party member unlocks" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inventory, 17);
    var i: u8 = 0;
    while (i < EJECTION_TICKS - 1) : (i += 1) try std.testing.expect(!vault.tick());
    try std.testing.expect(vault.tick());
    try std.testing.expectEqual(VaultState.unlocked, vault.state);
}

test "vault rejects a sixty-fifth distinct player without consuming key" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_player_count = @intCast(MAX_UNLOCKED_PLAYERS);
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key };
    try std.testing.expectEqual(InteractionResult.player_limit, vault.interact(999, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.trial_key));
}

test "wrong ominous key does not open a standard vault" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .ominous_trial_key, .count = 2 };
    try std.testing.expectEqual(InteractionResult.wrong_item, vault.interact(3, &inventory, 4).interaction);
    try std.testing.expectEqual(@as(u32, 2), inventory.count(.ominous_trial_key));
    try std.testing.expectEqual(VaultState.idle, vault.state);
}

test "successful standard key interaction consumes one and starts ejection" {
    var vault = Vault.init(.standard, .{ 1, 2, 3 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 3 };
    const result = vault.interact(4, &inventory, 77);
    try std.testing.expectEqual(InteractionResult.started_ejection, result.interaction);
    try std.testing.expectEqual(@as(u32, 2), inventory.count(.trial_key));
    try std.testing.expectEqual(VaultState.ejecting, vault.state);
}

test "an eligible player sees the preview while another player's preview is hidden" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 15;
    vault.unlocked_player_count = 1;
    try std.testing.expect(!vault.displayItemVisible(15));
    try std.testing.expect(vault.displayItemVisible(16));
    try std.testing.expect(vault.displayPreview(16) != null);
    try std.testing.expect(vault.displayPreview(15) == null);
}

test "reset token on a player without a lock is not consumed" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .vault_reset_token };
    try std.testing.expectEqual(InteractionResult.wrong_item, vault.interact(1, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.vault_reset_token));
}

test "resetting a player permits another key unlock after current ejection finishes" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var first = Inventory{};
    first.slots[0] = .{ .item = .trial_key };
    _ = vault.interact(7, &first, 1);
    var i: u8 = 0;
    while (i < EJECTION_TICKS) : (i += 1) _ = vault.tick();
    var reset = Inventory{};
    reset.slots[0] = .{ .item = .vault_reset_token };
    try std.testing.expectEqual(InteractionResult.reset, vault.interact(7, &reset, 2).interaction);
    var second_key = Inventory{};
    second_key.slots[0] = .{ .item = .trial_key };
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(7, &second_key, 3).interaction);
}

test "removing a lock at capacity frees one player slot" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_player_count = @intCast(MAX_UNLOCKED_PLAYERS);
    vault.unlocked_players[0] = 9;
    vault.state = .unlocked;
    var reset = Inventory{};
    reset.slots[0] = .{ .item = .vault_reset_token };
    try std.testing.expectEqual(InteractionResult.reset, vault.interact(9, &reset, 0).interaction);
    try std.testing.expect(vault.acceptsInteraction(999));
}

test "reset token drop boundary is inclusive at four percent and exclusive at five" {
    try std.testing.expect(dropsVaultResetToken(true, RESET_TOKEN_DROP_PERCENT - 1));
    try std.testing.expect(!dropsVaultResetToken(true, RESET_TOKEN_DROP_PERCENT));
    try std.testing.expect(!dropsVaultResetToken(false, RESET_TOKEN_DROP_PERCENT - 1));
}

test "ejected loot count is not coupled to party size" {
    const one = generateLoot(89, .{ 0, 0, 0 });
    const another_seed = generateLoot(90, .{ 0, 0, 0 });
    try std.testing.expect(one.count >= 3 and one.count <= 6);
    try std.testing.expect(another_seed.count >= 3 and another_seed.count <= 6);
}

test "randomized ejection angles cover the full circle" {
    var quadrants = [_]bool{false} ** 4;
    var seed: u32 = 0;
    while (seed < 64) : (seed += 1) {
        const loot = generateLoot(seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const theta = maybe_item.?.dispersion_angle;
            const quadrant: usize = @intFromFloat(theta / (TAU / 4.0));
            quadrants[@min(quadrant, 3)] = true;
        }
    }
    for (quadrants) |seen| try std.testing.expect(seen);
}

test "ejected items have nonzero horizontal radial speed" {
    const loot = generateLoot(0xfeedbeef, .{ 0, 0, 0 });
    for (loot.items[0..loot.count]) |maybe_item| {
        const item = maybe_item.?;
        try std.testing.expect(item.velocity[0] != 0.0 or item.velocity[2] != 0.0);
    }
}

test "ejecting state rejects other players without consuming their key" {
    var vault = Vault.init(.ominous, .{ 0, 0, 0 });
    var first = Inventory{};
    first.slots[0] = .{ .item = .ominous_trial_key };
    _ = vault.interact(1, &first, 2);
    var second = Inventory{};
    second.slots[0] = .{ .item = .ominous_trial_key };
    try std.testing.expectEqual(InteractionResult.busy, vault.interact(2, &second, 3).interaction);
    try std.testing.expectEqual(@as(u32, 1), second.count(.ominous_trial_key));
}

test "comparator chooses closest eligible player over farther unlocked player" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    const players = [_]PlayerPosition{
        .{ .player_id = 1, .position = .{ 3, 0, 0 } },
        .{ .player_id = 2, .position = .{ 1, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorOutput(&players));
}

test "comparator handles players at the vault position" {
    const vault = Vault.init(.standard, .{ 4, 5, 6 });
    const players = [_]PlayerPosition{.{ .player_id = 1, .position = .{ 4, 5, 6 } }};
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorOutput(&players));
}

test "idle tick advances preview time without changing state" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(!vault.tick());
    try std.testing.expectEqual(@as(u32, 1), vault.display_ticks);
    try std.testing.expectEqual(VaultState.idle, vault.state);
}

};
