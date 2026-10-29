//! ============================================================================
//! Milestone 530: Ominous Bottle Consumption & Bad Omen / Trial Omen
//! Transformation Matrix in Zigcraft
//! ============================================================================
//!
//! This module implements the mechanics of Ominous Bottle drinking consumption,
//! Bad Omen status effect duration and amplifier stacking, Village Raid Omen
//! transmutation with countdown timer and scaled raid waves, Trial Spawner
//! Trial Omen transmutation with duration scaling and spawner upgrading,
//! and Milk Bucket cleansing across all omen states.


const std = @import("std");

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
pub fn calculateTrialOmenDuration(amplifier: u8) u32 {
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
        self.ticks_remaining = calculateTrialOmenDuration(self.amplifier);
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
    try std.testing.expectEqual(@as(u32, 18_000), calculateTrialOmenDuration(0));
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_1);
    const outcome = matrix.tick(.{ .trial_spawner_distance = 8.0 });
    try std.testing.expectEqual(@as(u32, 18_000), outcome.ticks_remaining);
}

test "41: Trial Omen duration formula for Tier II is 36,000 ticks" {
    try std.testing.expectEqual(@as(u32, 36_000), calculateTrialOmenDuration(1));
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_2);
    const outcome = matrix.tick(.{ .trial_spawner_distance = 8.0 });
    try std.testing.expectEqual(@as(u32, 36_000), outcome.ticks_remaining);
}

test "42: Trial Omen duration formula for Tier III is 54,000 ticks" {
    try std.testing.expectEqual(@as(u32, 54_000), calculateTrialOmenDuration(2));
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_3);
    const outcome = matrix.tick(.{ .trial_spawner_distance = 8.0 });
    try std.testing.expectEqual(@as(u32, 54_000), outcome.ticks_remaining);
}

test "43: Trial Omen duration formula for Tier IV is 72,000 ticks" {
    try std.testing.expectEqual(@as(u32, 72_000), calculateTrialOmenDuration(3));
    var matrix = OminousBottleMatrix.init();
    matrix.status.applyBadOmen(.tier_4);
    const outcome = matrix.tick(.{ .trial_spawner_distance = 8.0 });
    try std.testing.expectEqual(@as(u32, 72_000), outcome.ticks_remaining);
}

test "44: Trial Omen duration formula for Tier V is 90,000 ticks" {
    try std.testing.expectEqual(@as(u32, 90_000), calculateTrialOmenDuration(4));
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
