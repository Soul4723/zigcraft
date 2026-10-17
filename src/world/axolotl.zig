const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Health & combat constants
pub const max_health: f32 = 14.0; // 7 hearts
pub const low_health_threshold: f32 = 7.0; // Feigns death below 50% max HP
pub const play_dead_damage_threshold: f32 = 2.0; // Incoming damage >= 2.0 can trigger play dead
pub const play_dead_duration: f32 = 10.0; // 10.0 seconds feigning death (200 ticks at 20 ticks/sec)
pub const play_dead_ticks: u32 = 200;
pub const play_dead_regen_rate: f32 = 0.4; // 0.4 HP/second (+4.0 HP total over 10.0s)
pub const play_dead_total_regen: f32 = 4.0; // +4.0 HP
pub const axolotl_attack_damage: f32 = 2.0; // 1 heart melee attack
pub const attack_cooldown_duration: f32 = 1.0; // 1.0 second between attacks

/// Combat ally buff constants
pub const regen_duration_per_axolotl: f32 = 5.0; // +5.0s Regeneration I granted to player per assist
pub const max_regen_cap: f32 = 120.0; // 120.0s maximum duration cap (2 minutes / 2400 ticks)

/// Dry-out constants
pub const max_dry_land_seconds: f32 = 300.0; // 5 minutes / 300.0s out of water or rain before taking suffocation damage
pub const dry_out_ticks: u32 = 6000; // 300 seconds * 20 ticks/sec
pub const suffocation_damage_interval: f32 = 1.0; // Takes damage once per second when dry
pub const suffocation_damage_per_sec: f32 = 1.0; // 1.0 HP / second suffocation damage

/// Genetics constants
pub const blue_mutation_denominator: u16 = 1200; // 1/1200 chance for blue mutation
pub const blue_mutation_chance: u16 = 1200;

/// Item & tag constants
pub const WaterBucketItemId: u16 = 326;
pub const AxolotlBucketItemId: u16 = 333;
pub const TropicalFishBucketItemId: u16 = 334;
pub const TropicalFishItemId: u16 = 349;

/// Breeding & growth constants
pub const breeding_cooldown_duration: f32 = 300.0; // 5 minutes
pub const baby_growth_duration: f32 = 1200.0; // 20 minutes
pub const baby_growth_feed_bonus: f32 = 120.0; // 10% reduction per tropical fish fed

// ============================================================================
// Enums
// ============================================================================

/// 5 color variants of axolotls.
pub const AxolotlColor = enum(u8) {
    leucistic = 0, // Pink ("Lucy")
    wild = 1,      // Brown
    gold = 2,      // Yellow
    cyan = 3,      // Cyan / light blue
    blue = 4,      // Rare 1/1200 mutation

    pub fn name(self: AxolotlColor) []const u8 {
        return switch (self) {
            .leucistic => "Leucistic",
            .wild => "Wild",
            .gold => "Gold",
            .cyan => "Cyan",
            .blue => "Blue",
        };
    }

    pub fn isRare(self: AxolotlColor) bool {
        return self == .blue;
    }

    pub fn hexRgb(self: AxolotlColor) u24 {
        return switch (self) {
            .leucistic => 0xF4B3C2, // Pink body
            .wild => 0x5C4033,      // Brown body
            .gold => 0xF4C430,      // Golden yellow body
            .cyan => 0x8BE5F0,      // Cyan body
            .blue => 0x2A3D8F,      // Deep blue body
        };
    }
};

/// Aquatic mobs targeted by axolotls or involved in combat assistance.
pub const AquaticMobType = enum(u8) {
    drowned = 0,
    guardian = 1,
    elder_guardian = 2,
    squid = 3,
    glow_squid = 4,
    fish = 5,
    dolphin = 6,
    turtle = 7,

    pub fn isHostile(self: AquaticMobType) bool {
        return switch (self) {
            .drowned, .guardian, .elder_guardian => true,
            else => false,
        };
    }

    pub fn isAxolotlTarget(self: AquaticMobType) bool {
        return switch (self) {
            .drowned, .guardian, .elder_guardian, .squid, .glow_squid, .fish => true,
            .dolphin, .turtle => false,
        };
    }

    pub fn grantsCombatBuffOnKill(self: AquaticMobType) bool {
        return self.isHostile();
    }
};

// ============================================================================
// State & Structs
// ============================================================================

/// Axolotl entity state.
pub const AxolotlState = struct {
    color: AxolotlColor = .leucistic,
    health: f32 = max_health,
    play_dead_timer: f32 = 0.0,
    out_of_water_timer: f32 = 0.0,
    attack_cooldown: f32 = 0.0,
    in_bucket_of_axolotl: bool = false,

    // Auxiliary mechanics
    is_baby: bool = false,
    age: f32 = 0.0,
    breed_cooldown: f32 = 0.0,
    love_timer: f32 = 0.0,

    pub fn init(color: AxolotlColor) AxolotlState {
        return .{
            .color = color,
            .health = max_health,
            .play_dead_timer = 0.0,
            .out_of_water_timer = 0.0,
            .attack_cooldown = 0.0,
            .in_bucket_of_axolotl = false,
            .is_baby = false,
            .age = 0.0,
            .breed_cooldown = 0.0,
            .love_timer = 0.0,
        };
    }

    pub fn isPlayingDead(self: *const AxolotlState) bool {
        return self.play_dead_timer > 0.0;
    }

    pub fn isDryingOut(self: *const AxolotlState) bool {
        return !self.in_bucket_of_axolotl and self.out_of_water_timer >= max_dry_land_seconds;
    }

    pub fn isIgnoredByHostiles(self: *const AxolotlState) bool {
        return self.play_dead_timer > 0.0;
    }

    pub fn captureInBucket(self: *AxolotlState) bool {
        if (self.in_bucket_of_axolotl or self.health <= 0.0) return false;
        self.in_bucket_of_axolotl = true;
        self.play_dead_timer = 0.0;
        self.out_of_water_timer = 0.0;
        return true;
    }

    pub fn releaseFromBucket(self: *AxolotlState) bool {
        if (!self.in_bucket_of_axolotl) return false;
        self.in_bucket_of_axolotl = false;
        self.out_of_water_timer = 0.0;
        return true;
    }

    pub fn feedTropicalFish(self: *AxolotlState) bool {
        if (self.in_bucket_of_axolotl or self.health <= 0.0) return false;
        if (self.is_baby) {
            self.age += baby_growth_feed_bonus;
            if (self.age >= baby_growth_duration) {
                self.is_baby = false;
                self.age = 0.0;
            }
            return true;
        }
        if (self.breed_cooldown <= 0.0 and self.love_timer <= 0.0) {
            self.love_timer = 30.0;
            return true;
        }
        return false;
    }

    pub fn update(self: *AxolotlState, dt: f32, in_water_or_rain: bool) void {
        if (self.in_bucket_of_axolotl or self.health <= 0.0) return;

        // Moisture & dry land tracking
        if (in_water_or_rain) {
            self.out_of_water_timer = 0.0;
        } else {
            const prev_timer = self.out_of_water_timer;
            self.out_of_water_timer += dt;
            if (self.out_of_water_timer > max_dry_land_seconds) {
                const suffocation_time = if (prev_timer >= max_dry_land_seconds)
                    dt
                else
                    self.out_of_water_timer - max_dry_land_seconds;
                const dmg = suffocation_damage_per_sec * suffocation_time;
                self.health = @max(0.0, self.health - dmg);
            }
        }

        // Play Dead active state & health regeneration (+4.0 HP over 10.0s = 0.4 HP/s)
        if (self.play_dead_timer > 0.0) {
            const active_dt = @min(self.play_dead_timer, dt);
            self.play_dead_timer -= active_dt;
            self.health = @min(max_health, self.health + active_dt * play_dead_regen_rate);
        }

        // Attack cooldown
        if (self.attack_cooldown > 0.0) {
            self.attack_cooldown = @max(0.0, self.attack_cooldown - dt);
        }

        // Growth & breeding timers
        if (self.is_baby) {
            self.age += dt;
            if (self.age >= baby_growth_duration) {
                self.is_baby = false;
                self.age = 0.0;
            }
        }
        if (self.breed_cooldown > 0.0) {
            self.breed_cooldown = @max(0.0, self.breed_cooldown - dt);
        }
        if (self.love_timer > 0.0) {
            self.love_timer = @max(0.0, self.love_timer - dt);
        }
    }
};

/// Item representation when an Axolotl is captured in a Water Bucket.
pub const BucketOfAxolotl = struct {
    color: AxolotlColor,
    health: f32,
    is_baby: bool = false,

    pub fn fromAxolotl(axolotl: *AxolotlState) ?BucketOfAxolotl {
        if (!axolotl.captureInBucket()) return null;
        return .{
            .color = axolotl.color,
            .health = axolotl.health,
            .is_baby = axolotl.is_baby,
        };
    }

    pub fn spawnAxolotl(self: BucketOfAxolotl) AxolotlState {
        var axolotl = AxolotlState.init(self.color);
        axolotl.health = self.health;
        axolotl.is_baby = self.is_baby;
        axolotl.in_bucket_of_axolotl = false;
        return axolotl;
    }
};

/// Result of combat assistance granted to a player upon an assisted kill.
pub const AssistedKillResult = struct {
    new_regen_timer: f32,
    cleared_mining_fatigue: bool,
};

// ============================================================================
// Core Functions
// ============================================================================

/// Determine offspring color from two parents.
/// Rare Blue mutation occurs when `mutation_roll == 0` (1 / 1200 chance).
/// Otherwise, 50/50 inheritance selects parent_a (roll 0) or parent_b (roll 1).
pub fn breedAxolotlColor(
    parent_a: AxolotlColor,
    parent_b: AxolotlColor,
    mutation_roll: u16,
    parent_pick_roll: u1,
) AxolotlColor {
    if (mutation_roll == 0) {
        return .blue;
    }
    return if (parent_pick_roll == 0) parent_a else parent_b;
}

/// Evaluates if an axolotl feigns death when damaged underwater.
/// When damaged underwater (`health < 7.0` or `incoming_damage >= 2.0`, `roll % 3 == 0`),
/// feigns death for 10.0s (200 ticks), dropping hostile mob aggro and regenerating +4.0 HP (0.4 HP/s).
pub fn tryTriggerPlayDead(
    self: *AxolotlState,
    incoming_damage: f32,
    in_water: bool,
    roll: u8,
) bool {
    if (!in_water) return false;
    if (self.in_bucket_of_axolotl) return false;
    if (self.health <= 0.0) return false;

    if ((self.health < low_health_threshold or incoming_damage >= play_dead_damage_threshold) and (roll % 3 == 0)) {
        self.play_dead_timer = play_dead_duration;
        return true;
    }
    return false;
}

/// Checks whether hostile mobs ignore this axolotl.
/// Returns true when play_dead_timer > 0.0.
pub fn isIgnoredByHostiles(axolotl: anytype) bool {
    const T = @TypeOf(axolotl);
    if (T == *AxolotlState or T == *const AxolotlState) {
        return axolotl.play_dead_timer > 0.0;
    } else if (T == AxolotlState) {
        return axolotl.play_dead_timer > 0.0;
    } else {
        @compileError("isIgnoredByHostiles expects AxolotlState or *const AxolotlState");
    }
}

/// Applied when a player kills an aquatic hostile mob that an Axolotl was fighting.
/// Grants Regeneration I (+5.0s per axolotl up to 120.0s cap) and clears Elder Guardian Mining Fatigue.
pub fn onPlayerAssistedKill(
    axolotl_assisted: bool,
    current_regen_timer: f32,
    has_mining_fatigue: bool,
) AssistedKillResult {
    if (!axolotl_assisted) {
        return .{
            .new_regen_timer = current_regen_timer,
            .cleared_mining_fatigue = false,
        };
    }
    const current = @max(0.0, current_regen_timer);
    const new_timer = @min(max_regen_cap, current + regen_duration_per_axolotl);
    return .{
        .new_regen_timer = new_timer,
        .cleared_mining_fatigue = has_mining_fatigue,
    };
}

/// Helper for aquatic mob death checking combat assistance.
pub fn onAquaticMobKilled(
    mob: AquaticMobType,
    axolotl_assisted: bool,
    current_regen_timer: f32,
    has_mining_fatigue: bool,
) AssistedKillResult {
    if (!mob.grantsCombatBuffOnKill()) {
        return .{
            .new_regen_timer = current_regen_timer,
            .cleared_mining_fatigue = false,
        };
    }
    return onPlayerAssistedKill(axolotl_assisted, current_regen_timer, has_mining_fatigue);
}

// ============================================================================
// Unit Tests
// ============================================================================

test "1. AxolotlColor enum discriminants and names" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AxolotlColor.leucistic));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(AxolotlColor.wild));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(AxolotlColor.gold));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(AxolotlColor.cyan));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(AxolotlColor.blue));

    try std.testing.expectEqualStrings("Leucistic", AxolotlColor.leucistic.name());
    try std.testing.expectEqualStrings("Wild", AxolotlColor.wild.name());
    try std.testing.expectEqualStrings("Gold", AxolotlColor.gold.name());
    try std.testing.expectEqualStrings("Cyan", AxolotlColor.cyan.name());
    try std.testing.expectEqualStrings("Blue", AxolotlColor.blue.name());

    try std.testing.expect(!AxolotlColor.leucistic.isRare());
    try std.testing.expect(!AxolotlColor.wild.isRare());
    try std.testing.expect(!AxolotlColor.gold.isRare());
    try std.testing.expect(!AxolotlColor.cyan.isRare());
    try std.testing.expect(AxolotlColor.blue.isRare());
}

test "2. breedAxolotlColor rare 1/1200 Blue mutation on mutation_roll == 0" {
    // Both wild parents mutate into rare Blue on mutation_roll == 0
    const baby1 = breedAxolotlColor(.wild, .wild, 0, 0);
    try std.testing.expectEqual(AxolotlColor.blue, baby1);

    // Leucistic and Gold parents mutate into rare Blue on mutation_roll == 0
    const baby2 = breedAxolotlColor(.leucistic, .gold, 0, 1);
    try std.testing.expectEqual(AxolotlColor.blue, baby2);

    // Cyan and Wild parents mutate into rare Blue on mutation_roll == 0
    const baby3 = breedAxolotlColor(.cyan, .wild, 0, 0);
    try std.testing.expectEqual(AxolotlColor.blue, baby3);
}

test "3. breedAxolotlColor inherits parent A on parent_pick_roll 0 when not mutated" {
    // Non-zero mutation roll inherits parent A
    const baby1 = breedAxolotlColor(.leucistic, .wild, 1, 0);
    try std.testing.expectEqual(AxolotlColor.leucistic, baby1);

    const baby2 = breedAxolotlColor(.gold, .cyan, 1199, 0);
    try std.testing.expectEqual(AxolotlColor.gold, baby2);
}

test "4. breedAxolotlColor inherits parent B on parent_pick_roll 1 when not mutated" {
    // Non-zero mutation roll inherits parent B
    const baby1 = breedAxolotlColor(.leucistic, .wild, 1, 1);
    try std.testing.expectEqual(AxolotlColor.wild, baby1);

    const baby2 = breedAxolotlColor(.gold, .cyan, 42, 1);
    try std.testing.expectEqual(AxolotlColor.cyan, baby2);
}

test "5. breedAxolotlColor with both blue parents always yields blue" {
    // Mutation roll 0 yields blue
    const baby_mut = breedAxolotlColor(.blue, .blue, 0, 0);
    try std.testing.expectEqual(AxolotlColor.blue, baby_mut);

    // Non-mutation inherits parent A (blue)
    const baby_a = breedAxolotlColor(.blue, .blue, 500, 0);
    try std.testing.expectEqual(AxolotlColor.blue, baby_a);

    // Non-mutation inherits parent B (blue)
    const baby_b = breedAxolotlColor(.blue, .blue, 500, 1);
    try std.testing.expectEqual(AxolotlColor.blue, baby_b);
}

test "6. AxolotlState initialization and default values" {
    const axolotl = AxolotlState.init(.cyan);
    try std.testing.expectEqual(AxolotlColor.cyan, axolotl.color);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), axolotl.health, @as(f32, 0.001));
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.play_dead_timer, @as(f32, 0.001));
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.out_of_water_timer, @as(f32, 0.001));
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.attack_cooldown, @as(f32, 0.001));
    try std.testing.expect(!axolotl.in_bucket_of_axolotl);
    try std.testing.expect(!axolotl.isPlayingDead());
    try std.testing.expect(!axolotl.isDryingOut());
}

test "7. tryTriggerPlayDead triggers on low health underwater when roll % 3 == 0" {
    var axolotl = AxolotlState.init(.leucistic);
    axolotl.health = 6.0; // < 7.0 (low health threshold)

    // roll % 3 == 0 triggers
    const triggered = tryTriggerPlayDead(&axolotl, 0.5, true, 0);
    try std.testing.expect(triggered);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), axolotl.play_dead_timer, @as(f32, 0.001));
    try std.testing.expect(axolotl.isPlayingDead());
}

test "8. tryTriggerPlayDead triggers on incoming damage >= 2.0 underwater even at full health" {
    var axolotl = AxolotlState.init(.gold);
    axolotl.health = 14.0; // Full health

    // incoming damage 2.0 >= 2.0, roll 3 (% 3 == 0)
    const triggered = tryTriggerPlayDead(&axolotl, 2.0, true, 3);
    try std.testing.expect(triggered);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), axolotl.play_dead_timer, @as(f32, 0.001));
    try std.testing.expect(axolotl.isPlayingDead());
}

test "9. tryTriggerPlayDead fails when not in water" {
    var axolotl = AxolotlState.init(.wild);
    axolotl.health = 4.0; // Low health

    // in_water = false -> must fail to trigger
    const triggered = tryTriggerPlayDead(&axolotl, 4.0, false, 0);
    try std.testing.expect(!triggered);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.play_dead_timer, @as(f32, 0.001));
    try std.testing.expect(!axolotl.isPlayingDead());
}

test "10. tryTriggerPlayDead fails when roll % 3 != 0" {
    var axolotl = AxolotlState.init(.cyan);
    axolotl.health = 5.0; // Low health

    // roll 1 % 3 != 0
    const triggered1 = tryTriggerPlayDead(&axolotl, 1.0, true, 1);
    try std.testing.expect(!triggered1);

    // roll 2 % 3 != 0
    const triggered2 = tryTriggerPlayDead(&axolotl, 1.0, true, 2);
    try std.testing.expect(!triggered2);

    // roll 4 % 3 != 0
    const triggered3 = tryTriggerPlayDead(&axolotl, 3.0, true, 4);
    try std.testing.expect(!triggered3);

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.play_dead_timer, @as(f32, 0.001));
}

test "11. tryTriggerPlayDead fails when health >= 7.0 and incoming_damage < 2.0" {
    var axolotl = AxolotlState.init(.blue);
    axolotl.health = 10.0; // >= 7.0

    // incoming_damage 1.0 < 2.0, even with roll % 3 == 0
    const triggered = tryTriggerPlayDead(&axolotl, 1.0, true, 0);
    try std.testing.expect(!triggered);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.play_dead_timer, @as(f32, 0.001));
}

test "12. isIgnoredByHostiles drops aggro while playing dead and restores after timer expires" {
    var axolotl = AxolotlState.init(.leucistic);
    try std.testing.expect(!isIgnoredByHostiles(&axolotl));
    try std.testing.expect(!isIgnoredByHostiles(axolotl));

    // Feign death
    _ = tryTriggerPlayDead(&axolotl, 3.0, true, 0);
    try std.testing.expect(isIgnoredByHostiles(&axolotl));
    try std.testing.expect(isIgnoredByHostiles(axolotl));
    try std.testing.expect(axolotl.isIgnoredByHostiles());

    // Update 5 seconds: still feigning death
    axolotl.update(5.0, true);
    try std.testing.expect(isIgnoredByHostiles(&axolotl));
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), axolotl.play_dead_timer, @as(f32, 0.001));

    // Update remaining 5 seconds: timer expires, aggro restored
    axolotl.update(5.0, true);
    try std.testing.expect(!isIgnoredByHostiles(&axolotl));
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.play_dead_timer, @as(f32, 0.001));
}

test "13. Play Dead regenerates +4.0 HP over 10.0 seconds (0.4 HP/s)" {
    var axolotl = AxolotlState.init(.wild);
    axolotl.health = 5.0;

    _ = tryTriggerPlayDead(&axolotl, 2.5, true, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), axolotl.play_dead_timer, @as(f32, 0.001));

    // 5 seconds at 0.4 HP/s -> +2.0 HP
    axolotl.update(5.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), axolotl.health, @as(f32, 0.001));

    // Another 5 seconds -> +2.0 HP (total +4.0 HP -> 9.0 HP)
    axolotl.update(5.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), axolotl.health, @as(f32, 0.001));
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.play_dead_timer, @as(f32, 0.001));
}

test "14. Play Dead regeneration caps at max health 14.0 HP" {
    var axolotl = AxolotlState.init(.gold);
    axolotl.health = 12.0;

    _ = tryTriggerPlayDead(&axolotl, 2.0, true, 0);
    // Regenerating +4.0 from 12.0 caps at 14.0 max health
    axolotl.update(10.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), axolotl.health, @as(f32, 0.001));
}

test "15. onPlayerAssistedKill grants +5.0s Regeneration I when axolotl assists" {
    const res1 = onPlayerAssistedKill(true, 0.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), res1.new_regen_timer, @as(f32, 0.001));
    try std.testing.expect(!res1.cleared_mining_fatigue);

    const res2 = onPlayerAssistedKill(true, 15.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), res2.new_regen_timer, @as(f32, 0.001));
}

test "16. onPlayerAssistedKill caps Regeneration I duration at 120.0s" {
    const res1 = onPlayerAssistedKill(true, 118.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 120.0), res1.new_regen_timer, @as(f32, 0.001));

    const res2 = onPlayerAssistedKill(true, 120.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 120.0), res2.new_regen_timer, @as(f32, 0.001));
}

test "17. onPlayerAssistedKill completely clears Elder Guardian Mining Fatigue" {
    const res = onPlayerAssistedKill(true, 10.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), res.new_regen_timer, @as(f32, 0.001));
    try std.testing.expect(res.cleared_mining_fatigue);
}

test "18. onPlayerAssistedKill does nothing when axolotl did not assist" {
    const res = onPlayerAssistedKill(false, 25.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), res.new_regen_timer, @as(f32, 0.001));
    try std.testing.expect(!res.cleared_mining_fatigue);
}

test "19. dry-out suffocation timer takes no damage until 300.0s (5 minutes) out of water" {
    var axolotl = AxolotlState.init(.blue);

    // 299 seconds on dry land
    axolotl.update(299.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), axolotl.health, @as(f32, 0.001));
    try std.testing.expectApproxEqAbs(@as(f32, 299.0), axolotl.out_of_water_timer, @as(f32, 0.001));
    try std.testing.expect(!axolotl.isDryingOut());

    // Another 1 second reaches exactly 300.0s (no damage yet because time > 300.0s is 0)
    axolotl.update(1.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), axolotl.health, @as(f32, 0.001));
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), axolotl.out_of_water_timer, @as(f32, 0.001));
    try std.testing.expect(axolotl.isDryingOut());

    // Once past 300.0s, takes 1 HP/s suffocation damage
    axolotl.update(2.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), axolotl.health, @as(f32, 0.001));
}

test "20. dry-out timer resets immediately when entering water or rain" {
    var axolotl = AxolotlState.init(.leucistic);

    // 250 seconds on land
    axolotl.update(250.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 250.0), axolotl.out_of_water_timer, @as(f32, 0.001));

    // Enters water or rain
    axolotl.update(1.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.out_of_water_timer, @as(f32, 0.001));
    try std.testing.expect(!axolotl.isDryingOut());
}

test "21. Bucket of Axolotl capture, storage, and release" {
    var axolotl = AxolotlState.init(.gold);
    axolotl.health = 10.0;
    axolotl.out_of_water_timer = 150.0;

    // Capture into bucket
    const bucket = BucketOfAxolotl.fromAxolotl(&axolotl);
    try std.testing.expect(bucket != null);
    try std.testing.expectEqual(AxolotlColor.gold, bucket.?.color);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), bucket.?.health, @as(f32, 0.001));
    try std.testing.expect(axolotl.in_bucket_of_axolotl);

    // While in bucket, updating does not advance dry land timer or hurt axolotl
    axolotl.update(500.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), axolotl.health, @as(f32, 0.001));

    // Release from bucket
    const released = axolotl.releaseFromBucket();
    try std.testing.expect(released);
    try std.testing.expect(!axolotl.in_bucket_of_axolotl);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), axolotl.out_of_water_timer, @as(f32, 0.001));

    // Releasing again fails because not in bucket
    try std.testing.expect(!axolotl.releaseFromBucket());

    // Spawn new axolotl instance from bucket
    const spawned = bucket.?.spawnAxolotl();
    try std.testing.expectEqual(AxolotlColor.gold, spawned.color);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), spawned.health, @as(f32, 0.001));
    try std.testing.expect(!spawned.in_bucket_of_axolotl);
}

test "22. AquaticMobType targets and combat buff dispatch" {
    // Drowned, Guardian, Elder Guardian are hostiles and grant combat buff
    try std.testing.expect(AquaticMobType.drowned.isHostile());
    try std.testing.expect(AquaticMobType.guardian.isHostile());
    try std.testing.expect(AquaticMobType.elder_guardian.isHostile());
    try std.testing.expect(AquaticMobType.drowned.grantsCombatBuffOnKill());
    try std.testing.expect(AquaticMobType.guardian.grantsCombatBuffOnKill());
    try std.testing.expect(AquaticMobType.elder_guardian.grantsCombatBuffOnKill());

    // Non-hostiles don't grant combat buff
    try std.testing.expect(!AquaticMobType.squid.isHostile());
    try std.testing.expect(!AquaticMobType.squid.grantsCombatBuffOnKill());
    try std.testing.expect(!AquaticMobType.fish.grantsCombatBuffOnKill());
    try std.testing.expect(!AquaticMobType.dolphin.grantsCombatBuffOnKill());
    try std.testing.expect(!AquaticMobType.turtle.grantsCombatBuffOnKill());

    // Killing Elder Guardian with assist grants regen and clears fatigue
    const eg_res = onAquaticMobKilled(.elder_guardian, true, 0.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), eg_res.new_regen_timer, @as(f32, 0.001));
    try std.testing.expect(eg_res.cleared_mining_fatigue);

    // Killing Squid with assist does not grant buff
    const squid_res = onAquaticMobKilled(.squid, true, 0.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), squid_res.new_regen_timer, @as(f32, 0.001));
    try std.testing.expect(!squid_res.cleared_mining_fatigue);
}
