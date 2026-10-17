//! Wandering Trader Spawn Timer, Nocturnal Invisibility Potion AI,
//! Two Leashed Trader Llamas, and Exotic Botanical Trades.
//!
//! Minecraft Mechanics Implemented:
//! - WanderingTraderSpawnCycle: Attempts spawn every 24000 ticks (1 in-game day)
//!   with escalating chances: 2.5% -> 5.0% -> 7.5% (capped at 7.5%).
//!   Only 1 Wandering Trader can exist in a world at a time.
//!   Despawns automatically after 48000 ticks (40.0 minutes / 2 game days).
//!   Name tags and boats do NOT prevent despawning.
//! - NocturnalInvisibilityAI: At dusk/night (time_of_day_ticks >= 12500 and < 23500),
//!   drinks Potion of Invisibility to evade Zombies, Pillagers, Vindicators, Evokers, and Vexes.
//!   At dawn (time_of_day_ticks < 12500 or >= 23500), drinks Milk Bucket to clear invisibility.
//! - TraderLlamaGuard: Spawns with 2 leashed Trader Llamas (leashed_llamas: u2 = 2).
//!   If attacked by a zombie or player, both llamas retaliate with spit (llama_spit_damage = 1.0).
//!   Separating or killing the llamas drops 2 Leads total.
//! - ExoticBotanicalCatalog: Offers 6 trades (5 regular + 1 special) for Emeralds.
//!   Includes coral_block, sea_pickle, pufferfish_bucket, tropical_fish_bucket,
//!   slimeball, glowstone, nautilus_shell, podzol, packed_ice, blue_ice, gunpowder,
//!   mangrove_propagule, cherry_sapling, pointed_dripstone, rooted_dirt, and moss_block.
//!   canRestockTrades() == false (once sold out, never restocks).

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Day length in Minecraft game ticks (20 ticks/sec * 60 sec * 20 min = 24000 ticks).
pub const day_length_ticks: u32 = 24000;
pub const spawn_attempt_interval_ticks: u32 = 24000;

/// Wandering Trader despawn lifespan: 48000 ticks = 40.0 minutes = 2 in-game days.
pub const despawn_ticks: u32 = 48000;
pub const despawn_minutes: f32 = 40.0;

/// Escalating spawn probabilities.
pub const base_spawn_chance: f32 = 0.025; // 2.5%
pub const spawn_chance_step: f32 = 0.025; // +2.5% per failed attempt
pub const max_spawn_chance: f32 = 0.075;  // 7.5% maximum cap

/// Day/night cycle time-of-day thresholds.
pub const dusk_ticks: u32 = 12500;
pub const dawn_ticks: u32 = 23500;

/// Llama combat parameters.
pub const llama_spit_damage: f32 = 1.0;
pub const max_leashed_llamas: u2 = 2;
pub const leads_dropped_per_llama: u8 = 1;
pub const total_leads_dropped: u8 = 2;

// ============================================================================
// Global Helper Functions
// ============================================================================

/// Returns true if the in-game time of day is nocturnal (dusk or night: 12500..23499).
pub fn isNocturnalTime(time_of_day_ticks: u32) bool {
    const t = time_of_day_ticks % day_length_ticks;
    return t >= dusk_ticks and t < dawn_ticks;
}

/// Returns true if the in-game time of day is day or dawn (0..12499 or 23500..23999).
pub fn isDawnOrDay(time_of_day_ticks: u32) bool {
    return !isNocturnalTime(time_of_day_ticks);
}

/// Evaluates if the trader should drink a Potion of Invisibility.
pub fn shouldDrinkInvisibilityPotion(is_night: bool, already_invisible: bool) bool {
    return is_night and !already_invisible;
}

/// Evaluates if the trader should drink a Milk Bucket at dawn.
pub fn shouldDrinkMilkAtDawn(is_day: bool, is_invisible: bool) bool {
    return is_day and is_invisible;
}

/// Name tags explicitly do NOT prevent the Wandering Trader from despawning.
pub fn doesNameTagPreventDespawn() bool {
    return false;
}

/// Boats explicitly do NOT prevent the Wandering Trader from despawning.
pub fn doesBoatPreventDespawn() bool {
    return false;
}

/// Wandering Trader trades never restock once sold out.
pub fn canRestockTrades() bool {
    return false;
}

/// Calculates spawn probability given consecutive failed attempts:
/// Attempt 0: 2.5%
/// Attempt 1: 5.0%
/// Attempt 2+: 7.5%
pub fn calculateSpawnChance(failed_attempts: u32) f32 {
    const chance = base_spawn_chance + @as(f32, @floatFromInt(failed_attempts)) * spawn_chance_step;
    return @min(chance, max_spawn_chance);
}

// ============================================================================
// Attacker and Threat Mob Definitions
// ============================================================================

pub const AttackerType = enum {
    player,
    zombie,
    pillager,
    vindicator,
    evoker,
    vex,
    skeleton,
    creeper,
    spider,
    enderman,
    wolf,
};

pub const ThreatMob = enum {
    zombie,
    pillager,
    vindicator,
    evoker,
    vex,

    pub fn isNocturnalThreat(self: ThreatMob) bool {
        _ = self;
        return true;
    }
};

/// Hostile attackers (zombies, players, and illagers) trigger llama spit retaliation.
pub fn triggersLlamaSpitRetaliation(attacker: AttackerType) bool {
    return switch (attacker) {
        .player, .zombie, .pillager, .vindicator, .evoker, .vex => true,
        .skeleton, .creeper, .spider, .enderman, .wolf => false,
    };
}

// ============================================================================
// 1. Wandering Trader Spawn Cycle
// ============================================================================

pub const WanderingTraderSpawnCycle = struct {
    ticks_since_last_attempt: u32 = 0,
    failed_attempts: u32 = 0,
    current_spawn_chance: f32 = base_spawn_chance,
    world_has_trader: bool = false,

    pub const spawn_interval_ticks: u32 = spawn_attempt_interval_ticks;
    pub const despawn_lifespan_ticks: u32 = despawn_ticks;

    pub fn init() WanderingTraderSpawnCycle {
        return .{};
    }

    pub fn doesNameTagPreventDespawn() bool {
        return false;
    }

    pub fn doesBoatPreventDespawn() bool {
        return false;
    }

    pub fn canSpawn(self: WanderingTraderSpawnCycle) bool {
        return !self.world_has_trader;
    }

    pub fn getSpawnChance(self: WanderingTraderSpawnCycle) f32 {
        return self.current_spawn_chance;
    }

    /// Advances the spawn timer by `delta_ticks`.
    /// When the 24000-tick interval is reached, executes a spawn attempt with `roll` (0.0..1.0).
    /// Returns true if a trader spawned.
    pub fn tick(self: *WanderingTraderSpawnCycle, delta_ticks: u32, roll: f32) bool {
        if (self.world_has_trader) {
            return false;
        }

        self.ticks_since_last_attempt += delta_ticks;
        if (self.ticks_since_last_attempt >= spawn_interval_ticks) {
            self.ticks_since_last_attempt %= spawn_interval_ticks;
            return self.attemptSpawn(roll);
        }
        return false;
    }

    /// Executes a single spawn attempt with random roll in [0.0, 1.0).
    /// Escalates 2.5% -> 5.0% -> 7.5% on failure; resets to 2.5% on success.
    pub fn attemptSpawn(self: *WanderingTraderSpawnCycle, roll: f32) bool {
        if (self.world_has_trader) {
            return false;
        }

        const chance = self.current_spawn_chance;
        if (roll < chance) {
            self.world_has_trader = true;
            self.failed_attempts = 0;
            self.current_spawn_chance = base_spawn_chance;
            return true;
        } else {
            self.failed_attempts += 1;
            self.current_spawn_chance = calculateSpawnChance(self.failed_attempts);
            return false;
        }
    }

    /// Called when the active Wandering Trader despawns.
    pub fn onTraderDespawn(self: *WanderingTraderSpawnCycle) void {
        self.world_has_trader = false;
    }
};

// ============================================================================
// 2. Nocturnal Invisibility AI
// ============================================================================

pub const NocturnalInvisibilityAI = struct {
    is_invisible: bool = false,
    is_drinking_potion: bool = false,
    is_drinking_milk: bool = false,
    potion_drink_timer: u32 = 0,

    pub fn init() NocturnalInvisibilityAI {
        return .{};
    }

    pub fn shouldDrinkInvisibilityPotion(is_night: bool, already_invisible: bool) bool {
        return is_night and !already_invisible;
    }

    pub fn shouldDrinkMilkAtDawn(is_day: bool, is_invisible: bool) bool {
        return is_day and is_invisible;
    }

    /// Hostile threat mobs (Zombies, Pillagers, Vindicators, Evokers, Vexes)
    /// cannot detect or target the trader when invisible.
    pub fn canThreatDetect(self: NocturnalInvisibilityAI, mob: ThreatMob) bool {
        _ = mob;
        return !self.is_invisible;
    }

    /// Updates AI status based on the in-game time of day.
    pub fn updateTimeOfDay(self: *NocturnalInvisibilityAI, time_of_day_ticks: u32) void {
        const night = isNocturnalTime(time_of_day_ticks);
        const day = isDawnOrDay(time_of_day_ticks);

        if (NocturnalInvisibilityAI.shouldDrinkInvisibilityPotion(night, self.is_invisible)) {
            self.drinkPotion();
        } else if (NocturnalInvisibilityAI.shouldDrinkMilkAtDawn(day, self.is_invisible)) {
            self.drinkMilk();
        }
    }

    pub fn drinkPotion(self: *NocturnalInvisibilityAI) void {
        self.is_drinking_potion = true;
        self.is_drinking_milk = false;
        self.is_invisible = true;
    }

    pub fn drinkMilk(self: *NocturnalInvisibilityAI) void {
        self.is_drinking_milk = true;
        self.is_drinking_potion = false;
        self.is_invisible = false;
    }
};

// ============================================================================
// 3. Trader Llama Guard
// ============================================================================

pub const TraderLlama = struct {
    id: u32,
    is_leashed: bool = true,
    is_alive: bool = true,
    health: f32 = 20.0,
};

pub const SpitRetaliation = struct {
    spits_fired: u2,
    damage_per_spit: f32,
    total_damage: f32,
    hit_target: bool,
};

pub const TraderLlamaGuard = struct {
    pub const llama_spit_damage: f32 = 1.0;
    pub const max_leashed_llamas: u2 = 2;

    leashed_llamas: u2 = 2,
    llamas: [2]TraderLlama,
    total_leads_dropped_count: u8 = 0,

    pub fn init() TraderLlamaGuard {
        return .{
            .leashed_llamas = 2,
            .llamas = .{
                .{ .id = 1, .is_leashed = true, .is_alive = true, .health = 20.0 },
                .{ .id = 2, .is_leashed = true, .is_alive = true, .health = 20.0 },
            },
            .total_leads_dropped_count = 0,
        };
    }

    pub fn triggersLlamaSpitRetaliation(attacker: AttackerType) bool {
        return switch (attacker) {
            .player, .zombie, .pillager, .vindicator, .evoker, .vex => true,
            .skeleton, .creeper, .spider, .enderman, .wolf => false,
        };
    }

    /// When the Wandering Trader is attacked, leashed llamas immediately spit.
    pub fn onTraderAttacked(self: *TraderLlamaGuard, attacker: AttackerType) ?SpitRetaliation {
        if (!TraderLlamaGuard.triggersLlamaSpitRetaliation(attacker)) {
            return null;
        }

        const count = self.leashed_llamas;
        if (count == 0) {
            return null;
        }

        const spit_damage = TraderLlamaGuard.llama_spit_damage;
        const total = @as(f32, @floatFromInt(count)) * spit_damage;

        return .{
            .spits_fired = count,
            .damage_per_spit = spit_damage,
            .total_damage = total,
            .hit_target = true,
        };
    }

    /// Separates a llama from the trader, breaking its leash and dropping 1 Lead.
    pub fn separateLlama(self: *TraderLlamaGuard, index: usize) u8 {
        if (index >= 2) return 0;
        if (self.llamas[index].is_leashed) {
            self.llamas[index].is_leashed = false;
            if (self.leashed_llamas > 0) self.leashed_llamas -= 1;
            self.total_leads_dropped_count += 1;
            return 1;
        }
        return 0;
    }

    /// Kills a llama, dropping 1 Lead if it was still leashed.
    pub fn killLlama(self: *TraderLlamaGuard, index: usize) u8 {
        if (index >= 2) return 0;
        if (!self.llamas[index].is_alive) return 0;
        self.llamas[index].is_alive = false;
        if (self.llamas[index].is_leashed) {
            self.llamas[index].is_leashed = false;
            if (self.leashed_llamas > 0) self.leashed_llamas -= 1;
            self.total_leads_dropped_count += 1;
            return 1;
        }
        return 0;
    }

    /// Unleashes or kills both llamas, yielding 2 Leads total.
    pub fn releaseAllLeads(self: *TraderLlamaGuard) u8 {
        var dropped: u8 = 0;
        for (0..2) |i| {
            dropped += self.separateLlama(i);
        }
        return dropped;
    }
};

// ============================================================================
// 4. Exotic Botanical & Aquatic Trades Catalog
// ============================================================================

pub const ExoticItem = enum(u16) {
    coral_block = 1,
    sea_pickle = 2,
    pufferfish_bucket = 3,
    tropical_fish_bucket = 4,
    slimeball = 5,
    glowstone = 6,
    nautilus_shell = 7,
    podzol = 8,
    packed_ice = 9,
    blue_ice = 10,
    gunpowder = 11,
    mangrove_propagule = 12,
    cherry_sapling = 13,
    pointed_dripstone = 14,
    rooted_dirt = 15,
    moss_block = 16,

    pub fn isSpecial(self: ExoticItem) bool {
        return switch (self) {
            .nautilus_shell, .pufferfish_bucket, .tropical_fish_bucket, .blue_ice => true,
            else => false,
        };
    }

    pub fn defaultEmeraldCost(self: ExoticItem) u8 {
        return switch (self) {
            .gunpowder, .pointed_dripstone, .rooted_dirt => 1,
            .sea_pickle, .glowstone, .moss_block => 2,
            .coral_block, .podzol, .packed_ice => 3,
            .slimeball => 4,
            .nautilus_shell, .pufferfish_bucket, .tropical_fish_bucket, .mangrove_propagule, .cherry_sapling => 5,
            .blue_ice => 6,
        };
    }

    pub fn defaultMaxUses(self: ExoticItem) u8 {
        return switch (self) {
            .pufferfish_bucket, .tropical_fish_bucket => 4,
            .nautilus_shell => 5,
            .blue_ice => 6,
            else => 8,
        };
    }
};

pub const regular_trade_pool = [_]ExoticItem{
    .coral_block,
    .sea_pickle,
    .slimeball,
    .glowstone,
    .podzol,
    .packed_ice,
    .gunpowder,
    .mangrove_propagule,
    .cherry_sapling,
    .pointed_dripstone,
    .rooted_dirt,
    .moss_block,
};

pub const special_trade_pool = [_]ExoticItem{
    .nautilus_shell,
    .pufferfish_bucket,
    .tropical_fish_bucket,
    .blue_ice,
};

pub const TradeTier = enum {
    regular,
    special,
};

pub const TradeOffer = struct {
    item: ExoticItem,
    emerald_cost: u8,
    count: u8 = 1,
    max_uses: u8 = 8,
    uses: u8 = 0,
    tier: TradeTier = .regular,

    pub fn isSoldOut(self: TradeOffer) bool {
        return self.uses >= self.max_uses;
    }

    pub fn canRestockTrades() bool {
        return false;
    }
};

pub const TradeReceipt = struct {
    item: ExoticItem,
    count: u8,
    emeralds_consumed: u8,
};

pub const ExoticBotanicalCatalog = struct {
    pub const total_trade_slots: usize = 6;
    pub const regular_trade_slots: usize = 5;
    pub const special_trade_slots: usize = 1;

    offers: [6]TradeOffer,

    pub fn canRestockTrades() bool {
        return false;
    }

    pub fn init() ExoticBotanicalCatalog {
        return initFromSeed(42);
    }

    /// Generates 6 random trades: 5 distinct regular items + 1 special item.
    pub fn initFromSeed(seed: u64) ExoticBotanicalCatalog {
        var prng = std.Random.DefaultPrng.init(seed);
        const rng = prng.random();

        var offers: [6]TradeOffer = undefined;

        // Pick 5 distinct regular items
        var chosen_reg = [_]bool{false} ** regular_trade_pool.len;
        var reg_idx: usize = 0;
        while (reg_idx < regular_trade_slots) {
            const pick = rng.uintLessThan(usize, regular_trade_pool.len);
            if (!chosen_reg[pick]) {
                chosen_reg[pick] = true;
                const it = regular_trade_pool[pick];
                offers[reg_idx] = .{
                    .item = it,
                    .emerald_cost = it.defaultEmeraldCost(),
                    .count = 1,
                    .max_uses = it.defaultMaxUses(),
                    .uses = 0,
                    .tier = .regular,
                };
                reg_idx += 1;
            }
        }

        // Pick 1 special item
        const spec_pick = rng.uintLessThan(usize, special_trade_pool.len);
        const spec_item = special_trade_pool[spec_pick];
        offers[5] = .{
            .item = spec_item,
            .emerald_cost = spec_item.defaultEmeraldCost(),
            .count = 1,
            .max_uses = spec_item.defaultMaxUses(),
            .uses = 0,
            .tier = .special,
        };

        return .{ .offers = offers };
    }

    /// Executes trade at slot (0..5) if affordable and not sold out.
    pub fn trade(self: *ExoticBotanicalCatalog, slot: usize, emeralds: u8) ?TradeReceipt {
        if (slot >= total_trade_slots) return null;
        var offer = &self.offers[slot];
        if (offer.isSoldOut()) return null;
        if (emeralds < offer.emerald_cost) return null;

        offer.uses += 1;
        return .{
            .item = offer.item,
            .count = offer.count,
            .emeralds_consumed = offer.emerald_cost,
        };
    }

    /// Wandering Traders never restock trades; always returns false.
    pub fn attemptRestock(self: *ExoticBotanicalCatalog) bool {
        _ = self;
        return false;
    }

    pub fn areAllSoldOut(self: ExoticBotanicalCatalog) bool {
        for (self.offers) |offer| {
            if (!offer.isSoldOut()) return false;
        }
        return true;
    }
};

// ============================================================================
// 5. Complete Wandering Trader Entity
// ============================================================================

pub const WanderingTrader = struct {
    ticks_alive: u32 = 0,
    despawn_timer: u32 = despawn_ticks,
    has_name_tag: bool = false,
    in_boat: bool = false,
    is_despawned: bool = false,

    invisibility_ai: NocturnalInvisibilityAI = .{},
    llama_guard: TraderLlamaGuard = TraderLlamaGuard.init(),
    catalog: ExoticBotanicalCatalog,

    pub fn init(seed: u64) WanderingTrader {
        return .{
            .catalog = ExoticBotanicalCatalog.initFromSeed(seed),
        };
    }

    pub fn doesNameTagPreventDespawn() bool {
        return false;
    }

    pub fn doesBoatPreventDespawn() bool {
        return false;
    }

    pub fn canRestockTrades() bool {
        return false;
    }

    pub fn applyNameTag(self: *WanderingTrader) void {
        self.has_name_tag = true;
    }

    pub fn enterBoat(self: *WanderingTrader) void {
        self.in_boat = true;
    }

    pub fn tick(self: *WanderingTrader, delta_ticks: u32, time_of_day_ticks: u32) void {
        if (self.is_despawned) return;

        self.ticks_alive += delta_ticks;
        if (self.despawn_timer <= delta_ticks) {
            self.despawn_timer = 0;
            self.is_despawned = true;
            return;
        } else {
            self.despawn_timer -= delta_ticks;
        }

        self.invisibility_ai.updateTimeOfDay(time_of_day_ticks);
    }

    pub fn onAttacked(self: *WanderingTrader, attacker: AttackerType) ?SpitRetaliation {
        return self.llama_guard.onTraderAttacked(attacker);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "WanderingTraderSpawnCycle - attempts spawn every 24000 ticks with escalating 2.5% -> 5.0% -> 7.5% chance" {
    var cycle = WanderingTraderSpawnCycle.init();

    try std.testing.expectEqual(@as(u32, 24000), WanderingTraderSpawnCycle.spawn_interval_ticks);
    try std.testing.expectEqual(@as(f32, 0.025), cycle.getSpawnChance());

    // Advance 12000 ticks - half day, no spawn attempt yet
    const spawned_half = cycle.tick(12000, 0.01);
    try std.testing.expect(!spawned_half);
    try std.testing.expectEqual(@as(f32, 0.025), cycle.getSpawnChance());

    // Advance another 12000 ticks - reaches 24000 ticks, roll 0.03 fails (0.03 >= 0.025)
    const spawned_day1 = cycle.tick(12000, 0.03);
    try std.testing.expect(!spawned_day1);
    // Escalates to 5.0%
    try std.testing.expectApproxEqAbs(@as(f32, 0.050), cycle.getSpawnChance(), 0.0001);

    // Another day (24000 ticks), roll 0.06 fails (0.06 >= 0.050)
    const spawned_day2 = cycle.tick(24000, 0.06);
    try std.testing.expect(!spawned_day2);
    // Escalates to 7.5%
    try std.testing.expectApproxEqAbs(@as(f32, 0.075), cycle.getSpawnChance(), 0.0001);

    // Another day (24000 ticks), roll 0.08 fails (0.08 >= 0.075)
    const spawned_day3 = cycle.tick(24000, 0.08);
    try std.testing.expect(!spawned_day3);
    // Capped at 7.5%
    try std.testing.expectApproxEqAbs(@as(f32, 0.075), cycle.getSpawnChance(), 0.0001);
}

test "WanderingTraderSpawnCycle - chance resets to 2.5% after successful spawn and only 1 trader can exist" {
    var cycle = WanderingTraderSpawnCycle.init();

    // Fail two attempts to reach 7.5%
    _ = cycle.attemptSpawn(0.9);
    _ = cycle.attemptSpawn(0.9);
    try std.testing.expectApproxEqAbs(@as(f32, 0.075), cycle.getSpawnChance(), 0.0001);

    // Third attempt succeeds with roll 0.04 (< 0.075)
    const success = cycle.attemptSpawn(0.04);
    try std.testing.expect(success);
    try std.testing.expect(cycle.world_has_trader);
    // Resets to base 2.5%
    try std.testing.expectApproxEqAbs(@as(f32, 0.025), cycle.getSpawnChance(), 0.0001);

    // Only 1 Wandering Trader can exist per world at a time
    try std.testing.expect(!cycle.canSpawn());
    const blocked_spawn = cycle.attemptSpawn(0.001);
    try std.testing.expect(!blocked_spawn);

    // When trader despawns, spawning becomes possible again
    cycle.onTraderDespawn();
    try std.testing.expect(cycle.canSpawn());
}

test "WanderingTraderSpawnCycle - despawns automatically after 48000 ticks (40.0 minutes / 2 game days)" {
    try std.testing.expectEqual(@as(u32, 48000), despawn_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), despawn_minutes, 0.001);

    var trader = WanderingTrader.init(99);
    try std.testing.expect(!trader.is_despawned);
    try std.testing.expectEqual(@as(u32, 48000), trader.despawn_timer);

    // Tick 47999 ticks - still alive
    trader.tick(47999, 6000);
    try std.testing.expect(!trader.is_despawned);
    try std.testing.expectEqual(@as(u32, 1), trader.despawn_timer);

    // Tick 1 more tick - despawns at exactly 48000 ticks
    trader.tick(1, 6000);
    try std.testing.expect(trader.is_despawned);
    try std.testing.expectEqual(@as(u32, 0), trader.despawn_timer);
}

test "WanderingTraderSpawnCycle - doesNameTagPreventDespawn and doesBoatPreventDespawn return false" {
    try std.testing.expectEqual(false, doesNameTagPreventDespawn());
    try std.testing.expectEqual(false, doesBoatPreventDespawn());
    try std.testing.expectEqual(false, WanderingTraderSpawnCycle.doesNameTagPreventDespawn());
    try std.testing.expectEqual(false, WanderingTraderSpawnCycle.doesBoatPreventDespawn());
    try std.testing.expectEqual(false, WanderingTrader.doesNameTagPreventDespawn());
    try std.testing.expectEqual(false, WanderingTrader.doesBoatPreventDespawn());

    // Test on active trader entity
    var trader = WanderingTrader.init(101);
    trader.applyNameTag();
    trader.enterBoat();
    try std.testing.expect(trader.has_name_tag);
    try std.testing.expect(trader.in_boat);

    // Name tag and boat do NOT prevent despawn
    trader.tick(48000, 6000);
    try std.testing.expect(trader.is_despawned);
}

test "NocturnalInvisibilityAI - shouldDrinkInvisibilityPotion triggers at dusk/night when not invisible" {
    // Top-level function
    try std.testing.expect(shouldDrinkInvisibilityPotion(true, false));
    try std.testing.expect(!shouldDrinkInvisibilityPotion(true, true));
    try std.testing.expect(!shouldDrinkInvisibilityPotion(false, false));
    try std.testing.expect(!shouldDrinkInvisibilityPotion(false, true));

    // Struct-level method
    try std.testing.expect(NocturnalInvisibilityAI.shouldDrinkInvisibilityPotion(true, false));
    try std.testing.expect(!NocturnalInvisibilityAI.shouldDrinkInvisibilityPotion(true, true));
}

test "NocturnalInvisibilityAI - shouldDrinkMilkAtDawn triggers at dawn when invisible" {
    // Top-level function
    try std.testing.expect(shouldDrinkMilkAtDawn(true, true));
    try std.testing.expect(!shouldDrinkMilkAtDawn(true, false));
    try std.testing.expect(!shouldDrinkMilkAtDawn(false, true));
    try std.testing.expect(!shouldDrinkMilkAtDawn(false, false));

    // Struct-level method
    try std.testing.expect(NocturnalInvisibilityAI.shouldDrinkMilkAtDawn(true, true));
    try std.testing.expect(!NocturnalInvisibilityAI.shouldDrinkMilkAtDawn(true, false));
}

test "NocturnalInvisibilityAI - time of day thresholds correctly classify dusk, night, and dawn" {
    try std.testing.expectEqual(@as(u32, 12500), dusk_ticks);
    try std.testing.expectEqual(@as(u32, 23500), dawn_ticks);

    // Noon (6000) is day
    try std.testing.expect(!isNocturnalTime(6000));
    try std.testing.expect(isDawnOrDay(6000));

    // Exactly at dusk (12500) starts nocturnal period
    try std.testing.expect(isNocturnalTime(12500));
    try std.testing.expect(!isDawnOrDay(12500));

    // Midnight (18000) is night
    try std.testing.expect(isNocturnalTime(18000));
    try std.testing.expect(!isDawnOrDay(18000));

    // Just before dawn (23499) is still nocturnal
    try std.testing.expect(isNocturnalTime(23499));

    // At dawn (23500) returns to day/dawn
    try std.testing.expect(!isNocturnalTime(23500));
    try std.testing.expect(isDawnOrDay(23500));

    // Early morning (1000) is day/dawn
    try std.testing.expect(!isNocturnalTime(1000));
    try std.testing.expect(isDawnOrDay(1000));
}

test "NocturnalInvisibilityAI - hostile threat mobs lose tracking when trader is invisible" {
    var ai = NocturnalInvisibilityAI.init();

    // Initially visible during day
    try std.testing.expect(!ai.is_invisible);
    try std.testing.expect(ai.canThreatDetect(.zombie));
    try std.testing.expect(ai.canThreatDetect(.pillager));
    try std.testing.expect(ai.canThreatDetect(.vindicator));
    try std.testing.expect(ai.canThreatDetect(.evoker));
    try std.testing.expect(ai.canThreatDetect(.vex));

    // Night arrives -> drinks potion of invisibility
    ai.updateTimeOfDay(13000);
    try std.testing.expect(ai.is_invisible);
    try std.testing.expect(ai.is_drinking_potion);

    // When invisible, hostile threat mobs CANNOT detect or target the trader
    try std.testing.expect(!ai.canThreatDetect(.zombie));
    try std.testing.expect(!ai.canThreatDetect(.pillager));
    try std.testing.expect(!ai.canThreatDetect(.vindicator));
    try std.testing.expect(!ai.canThreatDetect(.evoker));
    try std.testing.expect(!ai.canThreatDetect(.vex));

    // Dawn arrives -> drinks milk bucket to clear invisibility
    ai.updateTimeOfDay(0);
    try std.testing.expect(!ai.is_invisible);
    try std.testing.expect(ai.is_drinking_milk);
    try std.testing.expect(ai.canThreatDetect(.zombie));
}

test "TraderLlamaGuard - spawns with 2 leashed trader llamas" {
    const guard = TraderLlamaGuard.init();

    try std.testing.expectEqual(@as(u2, 2), guard.leashed_llamas);
    try std.testing.expectEqual(@as(u2, 2), TraderLlamaGuard.max_leashed_llamas);
    try std.testing.expect(guard.llamas[0].is_leashed);
    try std.testing.expect(guard.llamas[1].is_leashed);
    try std.testing.expect(guard.llamas[0].is_alive);
    try std.testing.expect(guard.llamas[1].is_alive);
}

test "TraderLlamaGuard - triggersLlamaSpitRetaliation returns true for zombie, player, and illagers" {
    try std.testing.expect(triggersLlamaSpitRetaliation(.zombie));
    try std.testing.expect(triggersLlamaSpitRetaliation(.player));
    try std.testing.expect(triggersLlamaSpitRetaliation(.pillager));
    try std.testing.expect(triggersLlamaSpitRetaliation(.vindicator));
    try std.testing.expect(triggersLlamaSpitRetaliation(.evoker));
    try std.testing.expect(triggersLlamaSpitRetaliation(.vex));

    // Non-threat mobs do not trigger spit
    try std.testing.expect(!triggersLlamaSpitRetaliation(.skeleton));
    try std.testing.expect(!triggersLlamaSpitRetaliation(.creeper));
    try std.testing.expect(!triggersLlamaSpitRetaliation(.spider));
    try std.testing.expect(!triggersLlamaSpitRetaliation(.enderman));
    try std.testing.expect(!triggersLlamaSpitRetaliation(.wolf));
}

test "TraderLlamaGuard - spits at zombie and player attackers with 1.0 damage per llama" {
    var guard = TraderLlamaGuard.init();

    try std.testing.expectEqual(@as(f32, 1.0), TraderLlamaGuard.llama_spit_damage);
    try std.testing.expectEqual(@as(f32, 1.0), llama_spit_damage);

    // Zombie attack triggers both llamas to spit (2 * 1.0 = 2.0 total damage)
    const zombie_retaliation = guard.onTraderAttacked(.zombie).?;
    try std.testing.expectEqual(@as(u2, 2), zombie_retaliation.spits_fired);
    try std.testing.expectEqual(@as(f32, 1.0), zombie_retaliation.damage_per_spit);
    try std.testing.expectEqual(@as(f32, 2.0), zombie_retaliation.total_damage);

    // Player attack also triggers both llamas to spit
    const player_retaliation = guard.onTraderAttacked(.player).?;
    try std.testing.expectEqual(@as(u2, 2), player_retaliation.spits_fired);
    try std.testing.expectEqual(@as(f32, 2.0), player_retaliation.total_damage);

    // Skeleton attack does not trigger retaliation
    const skeleton_retaliation = guard.onTraderAttacked(.skeleton);
    try std.testing.expect(skeleton_retaliation == null);
}

test "TraderLlamaGuard - separating or killing llamas drops exactly 2 leads total" {
    var guard1 = TraderLlamaGuard.init();
    try std.testing.expectEqual(@as(u8, 2), total_leads_dropped);

    // Separate llama 0 -> drops 1 lead
    const drop1 = guard1.separateLlama(0);
    try std.testing.expectEqual(@as(u8, 1), drop1);
    try std.testing.expectEqual(@as(u2, 1), guard1.leashed_llamas);

    // Separate llama 1 -> drops 1 lead
    const drop2 = guard1.separateLlama(1);
    try std.testing.expectEqual(@as(u8, 1), drop2);
    try std.testing.expectEqual(@as(u2, 0), guard1.leashed_llamas);
    try std.testing.expectEqual(@as(u8, 2), guard1.total_leads_dropped_count);

    // Killing remaining separated llama drops 0 additional leads
    const drop3 = guard1.killLlama(0);
    try std.testing.expectEqual(@as(u8, 0), drop3);

    // Test fresh guard: killing llamas directly drops 2 leads
    var guard2 = TraderLlamaGuard.init();
    const kill_drop1 = guard2.killLlama(0);
    const kill_drop2 = guard2.killLlama(1);
    try std.testing.expectEqual(@as(u8, 1), kill_drop1);
    try std.testing.expectEqual(@as(u8, 1), kill_drop2);
    try std.testing.expectEqual(@as(u8, 2), guard2.total_leads_dropped_count);

    // Test releaseAllLeads
    var guard3 = TraderLlamaGuard.init();
    const all_leads = guard3.releaseAllLeads();
    try std.testing.expectEqual(@as(u8, 2), all_leads);
}

test "ExoticBotanicalCatalog - offers 6 random trades (5 regular + 1 special) for Emeralds" {
    const catalog = ExoticBotanicalCatalog.initFromSeed(777);

    try std.testing.expectEqual(@as(usize, 6), catalog.offers.len);

    var regular_count: usize = 0;
    var special_count: usize = 0;

    for (catalog.offers) |offer| {
        try std.testing.expect(offer.emerald_cost > 0);
        try std.testing.expect(offer.count >= 1);
        try std.testing.expect(offer.max_uses > 0);

        if (offer.tier == .regular) {
            regular_count += 1;
            try std.testing.expect(!offer.item.isSpecial());
        } else if (offer.tier == .special) {
            special_count += 1;
            try std.testing.expect(offer.item.isSpecial());
        }
    }

    try std.testing.expectEqual(@as(usize, 5), regular_count);
    try std.testing.expectEqual(@as(usize, 1), special_count);
}

test "ExoticBotanicalCatalog - contains all 16 exotic botanical and aquatic items" {
    // Verify every single requested item exists in ExoticItem enum
    const items = [_]ExoticItem{
        .coral_block,
        .sea_pickle,
        .pufferfish_bucket,
        .tropical_fish_bucket,
        .slimeball,
        .glowstone,
        .nautilus_shell,
        .podzol,
        .packed_ice,
        .blue_ice,
        .gunpowder,
        .mangrove_propagule,
        .cherry_sapling,
        .pointed_dripstone,
        .rooted_dirt,
        .moss_block,
    };

    try std.testing.expectEqual(@as(usize, 16), items.len);

    for (items) |it| {
        try std.testing.expect(it.defaultEmeraldCost() >= 1);
        try std.testing.expect(it.defaultMaxUses() >= 4);
    }

    // Special items cost significant emeralds
    try std.testing.expect(ExoticItem.nautilus_shell.isSpecial());
    try std.testing.expect(ExoticItem.blue_ice.isSpecial());
    try std.testing.expect(ExoticItem.pufferfish_bucket.isSpecial());
    try std.testing.expect(ExoticItem.tropical_fish_bucket.isSpecial());

    // Regular items are not special
    try std.testing.expect(!ExoticItem.coral_block.isSpecial());
    try std.testing.expect(!ExoticItem.cherry_sapling.isSpecial());
}

test "ExoticBotanicalCatalog - canRestockTrades is false and sold-out trades never restock" {
    try std.testing.expectEqual(false, canRestockTrades());
    try std.testing.expectEqual(false, ExoticBotanicalCatalog.canRestockTrades());
    try std.testing.expectEqual(false, TradeOffer.canRestockTrades());

    var catalog = ExoticBotanicalCatalog.initFromSeed(1234);

    // Trade slot 0 until sold out
    const cost = catalog.offers[0].emerald_cost;
    const max_uses = catalog.offers[0].max_uses;

    var trades_completed: u8 = 0;
    while (trades_completed < max_uses) : (trades_completed += 1) {
        const receipt = catalog.trade(0, cost);
        try std.testing.expect(receipt != null);
    }

    // Now slot 0 is sold out
    try std.testing.expect(catalog.offers[0].isSoldOut());
    const failed_trade = catalog.trade(0, cost);
    try std.testing.expect(failed_trade == null);

    // Attempting restock fails completely
    const restock_success = catalog.attemptRestock();
    try std.testing.expectEqual(false, restock_success);
    // Still sold out
    try std.testing.expect(catalog.offers[0].isSoldOut());
}

test "WanderingTrader - integrated lifecycle with name tag, boat, attack retaliation, and trading" {
    var trader = WanderingTrader.init(2026);

    try std.testing.expect(!trader.is_despawned);
    try std.testing.expectEqual(@as(u2, 2), trader.llama_guard.leashed_llamas);

    // Morning -> visible
    trader.tick(1000, 1000);
    try std.testing.expect(!trader.invisibility_ai.is_invisible);

    // Dusk -> drinks potion of invisibility
    trader.tick(12000, 13000);
    try std.testing.expect(trader.invisibility_ai.is_invisible);

    // Player attacks trader -> both leashed llamas spit back for 2.0 damage
    const spit = trader.onAttacked(.player).?;
    try std.testing.expectEqual(@as(u2, 2), spit.spits_fired);
    try std.testing.expectEqual(@as(f32, 2.0), spit.total_damage);

    // Unleashing both llamas drops 2 leads
    const dropped_leads = trader.llama_guard.releaseAllLeads();
    try std.testing.expectEqual(@as(u8, 2), dropped_leads);

    // After llamas are unleashed, they no longer spit
    const no_spit = trader.onAttacked(.player);
    try std.testing.expect(no_spit == null);

    // Name tag and boat applied
    trader.applyNameTag();
    trader.enterBoat();

    // Trader still despawns when lifespan expires
    trader.tick(48000, 1000);
    try std.testing.expect(trader.is_despawned);
}
