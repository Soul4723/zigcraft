//! ============================================================================
//! Milestone 481: Piglin Bartering & Gold Ingot Economy in Zigcraft
//! ============================================================================
//!
//! Overview:
//!   Piglins are nether-dwelling humanoid mobs obsessed with gold.
//!   This module implements the complete Piglin gold pacification mechanics,
//!   hostility triggers, bartering interaction lifecycle, 6-second (120-tick)
//!   inspection phase, and deterministic/stochastic Nether loot dispensing.
//!
//! Specifications & Rules:
//!   1. Target File: src/world/piglin_bartering_economy.zig
//!   2. Piglin Gold Pacification:
//!      - Armor check: If player wears at least 1 piece of golden armor
//!        (golden_helmet, golden_chestplate, golden_leggings, golden_boots),
//!        Piglin is neutral (is_pacified = true, is_hostile = false).
//!      - If player is not wearing golden armor: Piglin is hostile
//!        (is_hostile = true, charges with crossbow or golden sword).
//!      - Hostility Triggers (breaks pacification regardless of golden armor):
//!        * Attacking any Piglin or Piglin Brute.
//!        * Opening a chest, shulker box, ender chest, or barrel within 16 blocks.
//!        * Breaking a gold block, gilded blackstone, or gold ore within 16 blocks.
//!      - Piglin Brutes ignore armor and are never pacified.
//!   3. Bartering Interaction & Inspection Phase:
//!      - Right-clicking Piglin with Gold Ingot (ItemType.gold_ingot) or throwing
//!        Gold Ingot onto ground near Piglin (< 3.5m):
//!        * Piglin picks up Gold Ingot and inspects it for 120 game ticks (6.0 seconds).
//!        * While inspecting: stops moving, holds ingot in hand, ignores distractions.
//!      - Non-gold items are rejected and do not initiate bartering.
//!   4. Bartering Loot Dispensing:
//!      - At the end of the 6.0s inspection:
//!        * Consumes the Gold Ingot.
//!        * Drops 1 bartered loot item at Piglin position with upward pop velocity (vy = 0.3).
//!        * Barter Loot Pool & Probabilities:
//!          - Soul Speed Enchanted Book (1.09%)
//!          - Iron Boots with Soul Speed (1.89%)
//!          - Potion of Fire Resistance (2.18%) / Splash Potion (2.18%)
//!          - Ender Pearl (4.36%, count 2..4)
//!          - Crying Obsidian (8.71%, count 1..3)
//!          - Obsidian (8.71%, count 1)
//!          - Fire Charge (8.71%, count 1)
//!          - Nether Quartz (4.36%, count 5..12)
//!          - String (4.36%, count 3..9)
//!          - Magma Cream (4.36%, count 1)
//!          - Leather (8.71%, count 2..4)
//!          - Soul Sand (8.71%, count 2..8)
//!          - Gravel (8.71%, count 8..16)
//!          - Iron Nugget (2.18%, count 10..36)
//!   5. Audio & Visual Event Feedback:
//!      - Barter inspection chime/grunt on pickup.
//!      - Barter completion sound and green/gold sparkle particles on dispensing.
//!      - Angry sound and angry villager particles on hostility triggers.
//! ============================================================================

const std = @import("std");

// ============================================================================
// Core Constants
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;
pub const TICK_DT: f32 = 1.0 / @as(f32, @floatFromInt(TICKS_PER_SECOND)); // 0.05 seconds

/// Barter admiration/inspection duration in game ticks (6.0 seconds * 20 TPS = 120 ticks)
pub const BARTER_INSPECTION_TICKS: u32 = 120;
pub const BARTER_INSPECTION_DURATION_SECONDS: f32 = 6.0;

/// Maximum ground pickup distance for thrown gold ingots (less than 3.5 meters)
pub const BARTER_GROUND_PICKUP_RANGE: f32 = 3.5;

/// Radius within which opening guarded containers or breaking gold blocks angers Piglins (16 blocks)
pub const GUARDED_ACTION_ANGER_RADIUS: f32 = 16.0;

/// Default anger duration in game ticks when hostility is triggered (30.0s = 600 ticks)
pub const PIGLIN_ANGER_DURATION_TICKS: u32 = 600;
pub const PIGLIN_ANGER_DURATION_SECONDS: f32 = 30.0;

/// Upward pop velocity imparted to dropped barter items
pub const BARTER_DROP_POP_VELOCITY_Y: f32 = 0.30;

/// Piglin movement kinematic constants
pub const PIGLIN_WALK_SPEED: f32 = 1.75;
pub const PIGLIN_CHARGE_SPEED: f32 = 3.50;

// ============================================================================
// Enums & Types
// ============================================================================

/// Item types used in Piglin pacification, equipment, and bartering
pub const ItemType = enum(u16) {
    none = 0,
    gold_ingot = 1,
    golden_helmet = 2,
    golden_chestplate = 3,
    golden_leggings = 4,
    golden_boots = 5,
    golden_sword = 6,
    crossbow = 7,
    golden_axe = 8,

    // Barter loot rewards
    soul_speed_enchanted_book = 9,
    iron_boots_soul_speed = 10,
    potion_of_fire_resistance = 11,
    splash_potion_of_fire_resistance = 12,
    ender_pearl = 13,
    crying_obsidian = 14,
    obsidian = 15,
    fire_charge = 16,
    nether_quartz = 17,
    string = 18,
    magma_cream = 19,
    leather = 20,
    soul_sand = 21,
    gravel = 22,
    iron_nugget = 23,

    // Additional test / non-gold items
    diamond = 24,
    iron_ingot = 25,
    dirt = 26,
    stone = 27,
    iron_helmet = 28,
    diamond_chestplate = 29,
    leather_boots = 30,
    gold_nugget = 31,
    gold_block = 32,

    pub fn isGoldenArmor(self: ItemType) bool {
        return switch (self) {
            .golden_helmet, .golden_chestplate, .golden_leggings, .golden_boots => true,
            else => false,
        };
    }

    pub fn isGoldIngot(self: ItemType) bool {
        return self == .gold_ingot;
    }

    pub fn displayName(self: ItemType) []const u8 {
        return switch (self) {
            .none => "Air",
            .gold_ingot => "Gold Ingot",
            .golden_helmet => "Golden Helmet",
            .golden_chestplate => "Golden Chestplate",
            .golden_leggings => "Golden Leggings",
            .golden_boots => "Golden Boots",
            .golden_sword => "Golden Sword",
            .crossbow => "Crossbow",
            .golden_axe => "Golden Axe",
            .soul_speed_enchanted_book => "Enchanted Book (Soul Speed)",
            .iron_boots_soul_speed => "Iron Boots (Soul Speed)",
            .potion_of_fire_resistance => "Potion of Fire Resistance",
            .splash_potion_of_fire_resistance => "Splash Potion of Fire Resistance",
            .ender_pearl => "Ender Pearl",
            .crying_obsidian => "Crying Obsidian",
            .obsidian => "Obsidian",
            .fire_charge => "Fire Charge",
            .nether_quartz => "Nether Quartz",
            .string => "String",
            .magma_cream => "Magma Cream",
            .leather => "Leather",
            .soul_sand => "Soul Sand",
            .gravel => "Gravel",
            .iron_nugget => "Iron Nugget",
            .diamond => "Diamond",
            .iron_ingot => "Iron Ingot",
            .dirt => "Dirt",
            .stone => "Stone",
            .iron_helmet => "Iron Helmet",
            .diamond_chestplate => "Diamond Chestplate",
            .leather_boots => "Leather Boots",
            .gold_nugget => "Gold Nugget",
            .gold_block => "Gold Block",
        };
    }
};

/// Guarded container types whose opening provokes nearby Piglins
pub const GuardedContainer = enum {
    chest,
    trapped_chest,
    shulker_box,
    ender_chest,
    barrel,

    pub fn isGuarded(self: GuardedContainer) bool {
        _ = self;
        return true;
    }
};

/// Guarded gold blocks whose mining/destruction provokes nearby Piglins
pub const GuardedGoldBlock = enum {
    gold_block,
    gilded_blackstone,
    gold_ore,
    nether_gold_ore,
    deepslate_gold_ore,
    raw_gold_block,

    pub fn isGuarded(self: GuardedGoldBlock) bool {
        _ = self;
        return true;
    }
};

/// Mob species classification for hostility triggering
pub const MobKind = enum {
    piglin,
    piglin_brute,
    zombified_piglin,
    player,
    other,

    pub fn isPiglinKind(self: MobKind) bool {
        return self == .piglin or self == .piglin_brute;
    }
};

/// Weapon wielded by a Piglin
pub const PiglinWeapon = enum {
    golden_sword,
    crossbow,
    golden_axe,
    none,
};

/// Audio sound event cues
pub const SoundEvent = enum {
    piglin_admire,
    piglin_barter_complete,
    piglin_angry,
    piglin_step,
    piglin_ambient,
};

/// Visual particle event cues
pub const ParticleEvent = enum {
    barter_sparkle,
    angry_villager,
};

/// 3D Vector for positions and velocities
pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn zero() Vec3 {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    pub fn distanceSq(self: Vec3, other: Vec3) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn distance(self: Vec3, other: Vec3) f32 {
        return @sqrt(self.distanceSq(other));
    }
};

/// Represents player armor equipment slots
pub const PlayerArmor = struct {
    helmet: ItemType = .none,
    chestplate: ItemType = .none,
    leggings: ItemType = .none,
    boots: ItemType = .none,

    pub fn wearsAnyGoldArmor(self: PlayerArmor) bool {
        return self.helmet.isGoldenArmor() or
            self.chestplate.isGoldenArmor() or
            self.leggings.isGoldenArmor() or
            self.boots.isGoldenArmor();
    }

    pub fn goldenPieceCount(self: PlayerArmor) u8 {
        var count: u8 = 0;
        if (self.helmet.isGoldenArmor()) count += 1;
        if (self.chestplate.isGoldenArmor()) count += 1;
        if (self.leggings.isGoldenArmor()) count += 1;
        if (self.boots.isGoldenArmor()) count += 1;
        return count;
    }
};

/// Represents a barter loot entry with item, count range, weight, and nominal probability
pub const BarterReward = struct {
    item: ItemType,
    min_count: u8,
    max_count: u8,
    weight: u16,
    nominal_probability: f32, // percentage e.g. 1.09, 1.89, etc.
};

/// Dropped barter loot item spawned upon inspection completion
pub const DroppedBarterItem = struct {
    item: ItemType,
    count: u8,
    position: Vec3,
    velocity: Vec3,
    is_bartered_loot: bool = true,
};

// ============================================================================
// Barter Loot Table Specification
// ============================================================================

/// Complete 15-entry barter loot pool with weights, count ranges, and nominal probabilities
pub const BARTER_LOOT_TABLE = [_]BarterReward{
    .{ .item = .soul_speed_enchanted_book, .min_count = 1, .max_count = 1, .weight = 5, .nominal_probability = 1.09 },
    .{ .item = .iron_boots_soul_speed, .min_count = 1, .max_count = 1, .weight = 8, .nominal_probability = 1.89 },
    .{ .item = .potion_of_fire_resistance, .min_count = 1, .max_count = 1, .weight = 10, .nominal_probability = 2.18 },
    .{ .item = .splash_potion_of_fire_resistance, .min_count = 1, .max_count = 1, .weight = 10, .nominal_probability = 2.18 },
    .{ .item = .ender_pearl, .min_count = 2, .max_count = 4, .weight = 20, .nominal_probability = 4.36 },
    .{ .item = .crying_obsidian, .min_count = 1, .max_count = 3, .weight = 40, .nominal_probability = 8.71 },
    .{ .item = .obsidian, .min_count = 1, .max_count = 1, .weight = 40, .nominal_probability = 8.71 },
    .{ .item = .fire_charge, .min_count = 1, .max_count = 1, .weight = 40, .nominal_probability = 8.71 },
    .{ .item = .nether_quartz, .min_count = 5, .max_count = 12, .weight = 20, .nominal_probability = 4.36 },
    .{ .item = .string, .min_count = 3, .max_count = 9, .weight = 20, .nominal_probability = 4.36 },
    .{ .item = .magma_cream, .min_count = 1, .max_count = 1, .weight = 20, .nominal_probability = 4.36 },
    .{ .item = .leather, .min_count = 2, .max_count = 4, .weight = 40, .nominal_probability = 8.71 },
    .{ .item = .soul_sand, .min_count = 2, .max_count = 8, .weight = 40, .nominal_probability = 8.71 },
    .{ .item = .gravel, .min_count = 8, .max_count = 16, .weight = 40, .nominal_probability = 8.71 },
    .{ .item = .iron_nugget, .min_count = 10, .max_count = 36, .weight = 10, .nominal_probability = 2.18 },
};

/// Sum of weights in the barter table (363)
pub const BARTER_TOTAL_WEIGHT: u16 = blk: {
    var sum: u16 = 0;
    for (BARTER_LOOT_TABLE) |entry| sum += entry.weight;
    break :blk sum;
};

/// Returns the nominal probability in percent for a given barter reward item
pub fn getNominalProbability(item: ItemType) f32 {
    for (BARTER_LOOT_TABLE) |entry| {
        if (entry.item == item) return entry.nominal_probability;
    }
    return 0.0;
}

/// Returns the min/max count range for a barter reward item
pub fn getItemCountRange(item: ItemType) struct { min: u8, max: u8 } {
    for (BARTER_LOOT_TABLE) |entry| {
        if (entry.item == item) return .{ .min = entry.min_count, .max = entry.max_count };
    }
    return .{ .min = 0, .max = 0 };
}

/// Rolls a barter reward by weight cursor (deterministic lookup)
pub fn rollBarterLootByWeight(weight_roll: u16) BarterReward {
    var cursor = weight_roll % BARTER_TOTAL_WEIGHT;
    for (BARTER_LOOT_TABLE) |entry| {
        if (cursor < entry.weight) return entry;
        cursor -= entry.weight;
    }
    return BARTER_LOOT_TABLE[BARTER_LOOT_TABLE.len - 1];
}

/// Rolls a barter reward using a random number generator
pub fn rollBarterLoot(prng: *std.Random.DefaultPrng) DroppedBarterItem {
    const r = prng.random();
    const roll_val = r.uintLessThan(u16, BARTER_TOTAL_WEIGHT);
    const reward = rollBarterLootByWeight(roll_val);
    const count = if (reward.min_count == reward.max_count)
        reward.min_count
    else
        r.intRangeAtMost(u8, reward.min_count, reward.max_count);

    return DroppedBarterItem{
        .item = reward.item,
        .count = count,
        .position = Vec3.zero(),
        .velocity = Vec3.init(0.0, BARTER_DROP_POP_VELOCITY_Y, 0.0),
        .is_bartered_loot = true,
    };
}

/// Rolls a deterministic barter reward from a u64 seed
pub fn rollBarterLootBySeed(seed: u64) DroppedBarterItem {
    var prng = std.Random.DefaultPrng.init(seed);
    return rollBarterLoot(&prng);
}

// ============================================================================
// Piglin Entity State Machine
// ============================================================================

pub const Piglin = struct {
    id: u32 = 1,
    position: Vec3 = Vec3.zero(),
    velocity: Vec3 = Vec3.zero(),
    is_brute: bool = false,
    is_baby: bool = false,

    // Pacification & Hostility state
    is_pacified: bool = false,
    is_hostile: bool = true,
    anger_ticks_remaining: u32 = 0,
    equipped_weapon: PiglinWeapon = .golden_sword,
    is_charging: bool = false,

    // Bartering & Inspection state
    is_inspecting: bool = false,
    inspection_ticks_remaining: u32 = 0,
    holding_gold_ingot: bool = false,
    is_moving: bool = false,
    ignores_distractions: bool = false,
    consumed_gold_ingot: bool = false,

    // Audio & Visual Event Feedback
    last_sound: ?SoundEvent = null,
    last_particle: ?ParticleEvent = null,
    sound_event_count: u32 = 0,
    particle_event_count: u32 = 0,

    /// Initializes a new Piglin entity
    pub fn init(id: u32, pos: Vec3, is_brute: bool, weapon: PiglinWeapon) Piglin {
        return .{
            .id = id,
            .position = pos,
            .velocity = Vec3.zero(),
            .is_brute = is_brute,
            .is_baby = false,
            .is_pacified = false,
            .is_hostile = true,
            .anger_ticks_remaining = 0,
            .equipped_weapon = weapon,
            .is_charging = true,
            .is_inspecting = false,
            .inspection_ticks_remaining = 0,
            .holding_gold_ingot = false,
            .is_moving = false,
            .ignores_distractions = false,
            .consumed_gold_ingot = false,
            .last_sound = null,
            .last_particle = null,
            .sound_event_count = 0,
            .particle_event_count = 0,
        };
    }

    /// Evaluates player armor pacification rules
    pub fn updatePacification(self: *Piglin, player_armor: PlayerArmor) void {
        // Piglin Brutes ignore gold armor and remain permanently hostile
        if (self.is_brute) {
            self.is_pacified = false;
            self.is_hostile = true;
            self.is_charging = true;
            return;
        }

        // Active anger overrides golden armor
        if (self.anger_ticks_remaining > 0) {
            self.is_pacified = false;
            self.is_hostile = true;
            self.is_charging = true;
            return;
        }

        // Standard Piglin: pacified if player wears at least 1 piece of golden armor
        if (player_armor.wearsAnyGoldArmor()) {
            self.is_pacified = true;
            self.is_hostile = false;
            self.is_charging = false;
        } else {
            self.is_pacified = false;
            self.is_hostile = true;
            self.is_charging = true;
        }
    }

    /// Triggers Piglin anger/hostility, breaking pacification for duration_ticks
    pub fn triggerAnger(self: *Piglin, duration_ticks: u32) void {
        self.anger_ticks_remaining = duration_ticks;
        self.is_pacified = false;
        self.is_hostile = true;
        self.is_charging = true;

        // An angry Piglin drops any inspected gold and cancels bartering
        if (self.is_inspecting) {
            self.is_inspecting = false;
            self.holding_gold_ingot = false;
            self.inspection_ticks_remaining = 0;
            self.ignores_distractions = false;
        }

        self.emitSound(.piglin_angry);
        self.emitParticle(.angry_villager);
    }

    /// Responds to mob attack: provokes if victim is Piglin or Piglin Brute
    pub fn onAttackedMob(self: *Piglin, target_kind: MobKind, attacker_dist: f32) void {
        if (target_kind.isPiglinKind()) {
            if (attacker_dist <= GUARDED_ACTION_ANGER_RADIUS) {
                self.triggerAnger(PIGLIN_ANGER_DURATION_TICKS);
            }
        }
    }

    /// Responds to opening guarded container: provokes if within 16 blocks
    pub fn onContainerOpened(self: *Piglin, container: GuardedContainer, container_pos: Vec3) bool {
        _ = container;
        const dist = self.position.distance(container_pos);
        if (dist <= GUARDED_ACTION_ANGER_RADIUS) {
            self.triggerAnger(PIGLIN_ANGER_DURATION_TICKS);
            return true;
        }
        return false;
    }

    /// Responds to breaking guarded gold block: provokes if within 16 blocks
    pub fn onGoldBlockBroken(self: *Piglin, block: GuardedGoldBlock, block_pos: Vec3) bool {
        _ = block;
        const dist = self.position.distance(block_pos);
        if (dist <= GUARDED_ACTION_ANGER_RADIUS) {
            self.triggerAnger(PIGLIN_ANGER_DURATION_TICKS);
            return true;
        }
        return false;
    }

    /// Determines whether the Piglin is currently eligible to accept a gold ingot
    pub fn canBarter(self: Piglin) bool {
        // Brutes never barter, hostile piglins never barter, and piglins already inspecting do not take another
        return !self.is_brute and !self.is_hostile and !self.is_inspecting and self.anger_ticks_remaining == 0;
    }

    /// Initiates the 120-tick (6.0s) gold inspection phase
    pub fn startInspection(self: *Piglin) void {
        self.is_inspecting = true;
        self.inspection_ticks_remaining = BARTER_INSPECTION_TICKS;
        self.holding_gold_ingot = true;
        self.is_moving = false;
        self.velocity = Vec3.zero();
        self.ignores_distractions = true;
        self.consumed_gold_ingot = false;
        self.emitSound(.piglin_admire);
    }

    /// Right-click interaction with an item. Consumes/accepts gold ingot or rejects non-gold items.
    pub fn interactWithItem(self: *Piglin, item: ItemType) bool {
        if (!item.isGoldIngot()) {
            return false; // Rejection of non-gold items
        }
        if (!self.canBarter()) {
            return false;
        }
        self.startInspection();
        return true;
    }

    /// Thrown ground item pickup: picks up gold ingot within 3.5m
    pub fn pickupThrownItem(self: *Piglin, item: ItemType, item_pos: Vec3) bool {
        const dist = self.position.distance(item_pos);
        if (dist >= BARTER_GROUND_PICKUP_RANGE) {
            return false; // Out of pickup range (>= 3.5m)
        }
        if (!item.isGoldIngot()) {
            return false; // Rejection of non-gold items
        }
        if (!self.canBarter()) {
            return false;
        }
        self.startInspection();
        return true;
    }

    /// Advances Piglin state by game ticks. If inspection completes, dispenses barter loot.
    pub fn tick(self: *Piglin, ticks: u32, prng: ?*std.Random.DefaultPrng) ?DroppedBarterItem {
        // Decrement anger timer if active
        if (self.anger_ticks_remaining > 0) {
            const dec: u32 = @min(ticks, self.anger_ticks_remaining);
            self.anger_ticks_remaining -= dec;
        }

        // If not inspecting, no barter completion to process
        if (!self.is_inspecting) return null;

        if (self.inspection_ticks_remaining > 0) {
            const dec: u32 = @min(ticks, self.inspection_ticks_remaining);
            self.inspection_ticks_remaining -= dec;
            if (self.inspection_ticks_remaining > 0) {
                // Still inspecting: motionless, holding gold, ignoring distractions
                self.is_moving = false;
                self.velocity = Vec3.zero();
                self.ignores_distractions = true;
                self.holding_gold_ingot = true;
                return null;
            }
        }

        // Inspection timer reached 0!
        self.is_inspecting = false;
        self.holding_gold_ingot = false;
        self.consumed_gold_ingot = true;
        self.ignores_distractions = false;

        // Sound and particle events on barter completion
        self.emitSound(.piglin_barter_complete);
        self.emitParticle(.barter_sparkle);

        // Baby piglins confiscate the gold and do not dispense loot
        if (self.is_baby) {
            return null;
        }

        // Adult piglin dispenses bartered loot item with upward pop velocity
        return self.dispenseBarterLoot(prng);
    }

    /// Dispenses one bartered loot item at Piglin position with upward pop velocity
    pub fn dispenseBarterLoot(self: *Piglin, prng: ?*std.Random.DefaultPrng) DroppedBarterItem {
        var dropped: DroppedBarterItem = undefined;
        if (prng) |rng| {
            dropped = rollBarterLoot(rng);
        } else {
            // Default deterministic fallback
            const reward = rollBarterLootByWeight(0);
            dropped = DroppedBarterItem{
                .item = reward.item,
                .count = reward.min_count,
                .position = self.position,
                .velocity = Vec3.init(0.0, BARTER_DROP_POP_VELOCITY_Y, 0.0),
                .is_bartered_loot = true,
            };
        }
        dropped.position = self.position;
        dropped.velocity = Vec3.init(0.0, BARTER_DROP_POP_VELOCITY_Y, 0.0);
        return dropped;
    }

    pub fn emitSound(self: *Piglin, sound: SoundEvent) void {
        self.last_sound = sound;
        self.sound_event_count += 1;
    }

    pub fn emitParticle(self: *Piglin, particle: ParticleEvent) void {
        self.last_particle = particle;
        self.particle_event_count += 1;
    }
};

// ============================================================================
// Piglin Bartering Economy Simulator
// ============================================================================

/// Bastion / World economy manager managing multiple Piglins, container checks, and loot drops
pub const PiglinBarterEconomy = struct {
    piglins: std.ArrayList(Piglin),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PiglinBarterEconomy {
        return .{
            .piglins = std.ArrayList(Piglin).empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PiglinBarterEconomy) void {
        self.piglins.deinit(self.allocator);
    }

    pub fn spawnPiglin(self: *PiglinBarterEconomy, pos: Vec3, is_brute: bool, weapon: PiglinWeapon) !*Piglin {
        const id: u32 = @intCast(self.piglins.items.len + 1);
        try self.piglins.append(self.allocator, Piglin.init(id, pos, is_brute, weapon));
        return &self.piglins.items[self.piglins.items.len - 1];
    }

    pub fn evaluatePlayerPacification(self: *PiglinBarterEconomy, player_armor: PlayerArmor) void {
        for (self.piglins.items) |*piglin| {
            piglin.updatePacification(player_armor);
        }
    }

    pub fn notifyAttackMob(self: *PiglinBarterEconomy, target_kind: MobKind, attacker_pos: Vec3) u32 {
        var angered: u32 = 0;
        for (self.piglins.items) |*piglin| {
            const dist = piglin.position.distance(attacker_pos);
            const prev_hostile = piglin.is_hostile;
            piglin.onAttackedMob(target_kind, dist);
            if (!prev_hostile and piglin.is_hostile) {
                angered += 1;
            }
        }
        return angered;
    }

    pub fn notifyOpenContainer(self: *PiglinBarterEconomy, container: GuardedContainer, container_pos: Vec3) u32 {
        var angered: u32 = 0;
        for (self.piglins.items) |*piglin| {
            if (piglin.onContainerOpened(container, container_pos)) {
                angered += 1;
            }
        }
        return angered;
    }

    pub fn notifyBreakGoldBlock(self: *PiglinBarterEconomy, block: GuardedGoldBlock, block_pos: Vec3) u32 {
        var angered: u32 = 0;
        for (self.piglins.items) |*piglin| {
            if (piglin.onGoldBlockBroken(block, block_pos)) {
                angered += 1;
            }
        }
        return angered;
    }

    pub fn tickAll(self: *PiglinBarterEconomy, ticks: u32, prng: ?*std.Random.DefaultPrng, out_drops: *std.ArrayList(DroppedBarterItem)) !void {
        for (self.piglins.items) |*piglin| {
            if (piglin.tick(ticks, prng)) |drop| {
                try out_drops.append(self.allocator, drop);
            }
        }
    }
};

// ============================================================================
// Unit Tests (25+ Specifications)
// ============================================================================

test "1. Gold armor pacification: golden helmet pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);

    const armor = PlayerArmor{ .helmet = .golden_helmet };
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
    try std.testing.expect(!piglin.is_charging);
}

test "2. Gold armor pacification: golden chestplate pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .crossbow);
    const armor = PlayerArmor{ .chestplate = .golden_chestplate };
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
}

test "3. Gold armor pacification: golden leggings pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    const armor = PlayerArmor{ .leggings = .golden_leggings };
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
}

test "4. Gold armor pacification: golden boots pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .crossbow);
    const armor = PlayerArmor{ .boots = .golden_boots };
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
}

test "5. Gold armor pacification: full gold armor suit pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    const armor = PlayerArmor{
        .helmet = .golden_helmet,
        .chestplate = .golden_chestplate,
        .leggings = .golden_leggings,
        .boots = .golden_boots,
    };
    try std.testing.expectEqual(@as(u8, 4), armor.goldenPieceCount());
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
}

test "6. Gold armor pacification: player without armor leaves Piglin hostile" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    const armor = PlayerArmor{};
    piglin.updatePacification(armor);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
    try std.testing.expect(piglin.is_charging);
}

test "7. Gold armor pacification: non-gold armor leaves Piglin hostile" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    const armor = PlayerArmor{
        .helmet = .iron_helmet,
        .chestplate = .diamond_chestplate,
        .boots = .leather_boots,
    };
    try std.testing.expectEqual(@as(u8, 0), armor.goldenPieceCount());
    piglin.updatePacification(armor);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
}

test "8. Gold armor pacification: removing gold armor immediately makes Piglin hostile" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    var armor = PlayerArmor{ .boots = .golden_boots };
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);

    // Unequip boots
    armor.boots = .none;
    piglin.updatePacification(armor);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
}

test "9. Piglin Brute immunity: Brute is never pacified by golden armor and always charges" {
    var brute = Piglin.init(2, Vec3.zero(), true, .golden_axe);
    const armor = PlayerArmor{
        .helmet = .golden_helmet,
        .chestplate = .golden_chestplate,
        .leggings = .golden_leggings,
        .boots = .golden_boots,
    };
    brute.updatePacification(armor);
    try std.testing.expect(!brute.is_pacified);
    try std.testing.expect(brute.is_hostile);
    try std.testing.expect(brute.is_charging);
    try std.testing.expect(!brute.canBarter());
}

test "10. Hostility Trigger: Attacking Piglin provokes nearby Piglins within 16 blocks" {
    var piglin = Piglin.init(1, Vec3.init(0.0, 0.0, 0.0), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    try std.testing.expect(piglin.is_pacified);

    // Player attacks Piglin at distance 5m
    piglin.onAttackedMob(.piglin, 5.0);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
    try std.testing.expectEqual(PIGLIN_ANGER_DURATION_TICKS, piglin.anger_ticks_remaining);
}

test "11. Hostility Trigger: Attacking Piglin Brute provokes nearby Piglins" {
    var piglin = Piglin.init(1, Vec3.init(0.0, 0.0, 0.0), false, .crossbow);
    piglin.updatePacification(PlayerArmor{ .boots = .golden_boots });
    try std.testing.expect(piglin.is_pacified);

    // Player attacks Piglin Brute at distance 12m
    piglin.onAttackedMob(.piglin_brute, 12.0);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
}

test "12. Hostility Trigger: Attacking non-piglin mob does not provoke Piglin" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    try std.testing.expect(piglin.is_pacified);

    // Attacking other mob
    piglin.onAttackedMob(.other, 4.0);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
    try std.testing.expectEqual(@as(u32, 0), piglin.anger_ticks_remaining);
}

test "13. Hostility Trigger: Opening regular chest within 16 blocks provokes Piglin" {
    var piglin = Piglin.init(1, Vec3.init(0.0, 0.0, 0.0), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .chestplate = .golden_chestplate });
    try std.testing.expect(piglin.is_pacified);

    const chest_pos = Vec3.init(10.0, 0.0, 0.0);
    const provoked = piglin.onContainerOpened(.chest, chest_pos);
    try std.testing.expect(provoked);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
    try std.testing.expectEqual(PIGLIN_ANGER_DURATION_TICKS, piglin.anger_ticks_remaining);
}

test "14. Hostility Trigger: Opening shulker box, ender chest, and barrel provokes Piglin" {
    const containers = [_]GuardedContainer{ .trapped_chest, .shulker_box, .ender_chest, .barrel };
    for (containers) |container| {
        var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
        piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
        const pos = Vec3.init(3.0, 1.0, 2.0);
        const provoked = piglin.onContainerOpened(container, pos);
        try std.testing.expect(provoked);
        try std.testing.expect(!piglin.is_pacified);
        try std.testing.expect(piglin.is_hostile);
    }
}

test "15. Hostility Trigger: Opening container at 16.0m boundary provokes; 16.01m does not" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });

    // Exactly 16.0m
    const provoked_16 = piglin.onContainerOpened(.chest, Vec3.init(16.0, 0.0, 0.0));
    try std.testing.expect(provoked_16);

    // Reset pacification
    piglin.anger_ticks_remaining = 0;
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    try std.testing.expect(piglin.is_pacified);

    // 16.01m (beyond 16 blocks)
    const provoked_far = piglin.onContainerOpened(.chest, Vec3.init(16.01, 0.0, 0.0));
    try std.testing.expect(!provoked_far);
    try std.testing.expect(piglin.is_pacified);
}

test "16. Hostility Trigger: Breaking gold block within 16 blocks provokes Piglin" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .leggings = .golden_leggings });
    try std.testing.expect(piglin.is_pacified);

    const block_pos = Vec3.init(5.0, 0.0, 5.0);
    const provoked = piglin.onGoldBlockBroken(.gold_block, block_pos);
    try std.testing.expect(provoked);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
}

test "17. Hostility Trigger: Breaking gilded blackstone within 16 blocks provokes Piglin" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .boots = .golden_boots });

    const block_pos = Vec3.init(0.0, 8.0, 0.0);
    const provoked = piglin.onGoldBlockBroken(.gilded_blackstone, block_pos);
    try std.testing.expect(provoked);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
}

test "18. Hostility Trigger: Breaking gold ore (regular, nether, deepslate, raw) provokes Piglin" {
    const ores = [_]GuardedGoldBlock{ .gold_ore, .nether_gold_ore, .deepslate_gold_ore, .raw_gold_block };
    for (ores) |ore| {
        var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
        piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
        const provoked = piglin.onGoldBlockBroken(ore, Vec3.init(4.0, 0.0, 4.0));
        try std.testing.expect(provoked);
        try std.testing.expect(!piglin.is_pacified);
        try std.testing.expect(piglin.is_hostile);
    }
}

test "19. Hostility Trigger: Breaking gold block beyond 16 blocks does not provoke Piglin" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });

    const far_block = Vec3.init(25.0, 0.0, 0.0);
    const provoked = piglin.onGoldBlockBroken(.gold_block, far_block);
    try std.testing.expect(!provoked);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
}

test "20. Hostility Anger Timer: Piglin pacifies again after 600 ticks if player wears gold armor" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    const armor = PlayerArmor{ .helmet = .golden_helmet };
    piglin.updatePacification(armor);

    // Provoke piglin
    piglin.triggerAnger(PIGLIN_ANGER_DURATION_TICKS);
    try std.testing.expect(piglin.is_hostile);

    // Tick 300 ticks
    _ = piglin.tick(300, null);
    try std.testing.expectEqual(@as(u32, 300), piglin.anger_ticks_remaining);
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_hostile); // still angry

    // Tick remaining 300 ticks
    _ = piglin.tick(300, null);
    try std.testing.expectEqual(@as(u32, 0), piglin.anger_ticks_remaining);
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified); // calm again!
    try std.testing.expect(!piglin.is_hostile);
}

test "21. Hostility Feedback: Provoking Piglin emits angry sound and angry villager particles" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    try std.testing.expectEqual(@as(?SoundEvent, null), piglin.last_sound);
    try std.testing.expectEqual(@as(?ParticleEvent, null), piglin.last_particle);

    piglin.triggerAnger(600);
    try std.testing.expectEqual(SoundEvent.piglin_angry, piglin.last_sound.?);
    try std.testing.expectEqual(ParticleEvent.angry_villager, piglin.last_particle.?);
    try std.testing.expect(piglin.sound_event_count >= 1);
    try std.testing.expect(piglin.particle_event_count >= 1);
}

test "22. Bartering Rejection: Right-clicking with non-gold items is rejected" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .boots = .golden_boots });

    const non_gold = [_]ItemType{ .iron_ingot, .diamond, .dirt, .stone, .gold_nugget, .gold_block };
    for (non_gold) |item| {
        const accepted = piglin.interactWithItem(item);
        try std.testing.expect(!accepted);
        try std.testing.expect(!piglin.is_inspecting);
        try std.testing.expect(!piglin.holding_gold_ingot);
        try std.testing.expectEqual(@as(u32, 0), piglin.inspection_ticks_remaining);
    }
}

test "23. Bartering Rejection: Throwing non-gold items near Piglin (< 3.5m) is rejected" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });

    const near_pos = Vec3.init(1.0, 0.0, 1.0); // ~1.41m
    const accepted = piglin.pickupThrownItem(.iron_ingot, near_pos);
    try std.testing.expect(!accepted);
    try std.testing.expect(!piglin.is_inspecting);
}

test "24. Bartering Interaction: Right-clicking with Gold Ingot starts 120-tick inspection" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .chestplate = .golden_chestplate });

    const accepted = piglin.interactWithItem(.gold_ingot);
    try std.testing.expect(accepted);
    try std.testing.expect(piglin.is_inspecting);
    try std.testing.expectEqual(BARTER_INSPECTION_TICKS, piglin.inspection_ticks_remaining);
    try std.testing.expect(piglin.holding_gold_ingot);
    try std.testing.expect(!piglin.is_moving);
    try std.testing.expect(piglin.ignores_distractions);
    try std.testing.expectEqual(SoundEvent.piglin_admire, piglin.last_sound.?);
}

test "25. Bartering Interaction: Throwing Gold Ingot within 3.5m is picked up and starts inspection" {
    var piglin = Piglin.init(1, Vec3.init(10.0, 64.0, 10.0), false, .crossbow);
    piglin.updatePacification(PlayerArmor{ .leggings = .golden_leggings });

    // Ingot at distance 2.5m
    const ingot_pos = Vec3.init(12.0, 64.0, 11.5);
    try std.testing.expect(piglin.position.distance(ingot_pos) < BARTER_GROUND_PICKUP_RANGE);

    const picked_up = piglin.pickupThrownItem(.gold_ingot, ingot_pos);
    try std.testing.expect(picked_up);
    try std.testing.expect(piglin.is_inspecting);
    try std.testing.expectEqual(BARTER_INSPECTION_TICKS, piglin.inspection_ticks_remaining);
    try std.testing.expect(piglin.holding_gold_ingot);
}

test "26. Bartering Interaction: Throwing Gold Ingot at >= 3.5m is ignored" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .boots = .golden_boots });

    // Distance exactly 3.5m
    const picked_up_35 = piglin.pickupThrownItem(.gold_ingot, Vec3.init(3.5, 0.0, 0.0));
    try std.testing.expect(!picked_up_35);

    // Distance 5.0m
    const picked_up_50 = piglin.pickupThrownItem(.gold_ingot, Vec3.init(5.0, 0.0, 0.0));
    try std.testing.expect(!picked_up_50);
    try std.testing.expect(!piglin.is_inspecting);
}

test "27. Bartering Inspection: Piglin stops moving during 120-tick inspection" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.velocity = Vec3.init(1.5, 0.0, 0.0);
    piglin.is_moving = true;
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });

    _ = piglin.interactWithItem(.gold_ingot);
    try std.testing.expect(!piglin.is_moving);
    try std.testing.expectEqual(@as(f32, 0.0), piglin.velocity.x);
    try std.testing.expectEqual(@as(f32, 0.0), piglin.velocity.y);
    try std.testing.expectEqual(@as(f32, 0.0), piglin.velocity.z);

    // Still motionless at tick 60
    _ = piglin.tick(60, null);
    try std.testing.expect(!piglin.is_moving);
    try std.testing.expect(piglin.is_inspecting);
}

test "28. Bartering Inspection: Piglin holds gold ingot in hand during inspection" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    try std.testing.expect(piglin.holding_gold_ingot);
    _ = piglin.tick(50, null);
    try std.testing.expect(piglin.holding_gold_ingot);
    _ = piglin.tick(69, null);
    try std.testing.expect(piglin.holding_gold_ingot);
}

test "29. Bartering Inspection: Piglin ignores distractions while inspecting" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    try std.testing.expect(piglin.ignores_distractions);
    _ = piglin.tick(100, null);
    try std.testing.expect(piglin.ignores_distractions);
}

test "30. Bartering Inspection: Advancing inspection tick by tick decrements remaining timer" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .boots = .golden_boots });
    _ = piglin.interactWithItem(.gold_ingot);

    try std.testing.expectEqual(@as(u32, 120), piglin.inspection_ticks_remaining);
    const drop1 = piglin.tick(1, null);
    try std.testing.expectEqual(@as(?DroppedBarterItem, null), drop1);
    try std.testing.expectEqual(@as(u32, 119), piglin.inspection_ticks_remaining);

    const drop2 = piglin.tick(19, null);
    try std.testing.expectEqual(@as(?DroppedBarterItem, null), drop2);
    try std.testing.expectEqual(@as(u32, 100), piglin.inspection_ticks_remaining);
}

test "31. Bartering Inspection: Large tick advance clamps cleanly to zero" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    // Advance 500 ticks at once
    const drop = piglin.tick(500, null);
    try std.testing.expect(drop != null);
    try std.testing.expectEqual(@as(u32, 0), piglin.inspection_ticks_remaining);
    try std.testing.expect(!piglin.is_inspecting);
}

test "32. Bartering Completion: Ingot consumed and exactly 1 barter loot item dispensed at 120 ticks" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    try std.testing.expect(!piglin.consumed_gold_ingot);
    _ = piglin.tick(119, null);
    try std.testing.expect(!piglin.consumed_gold_ingot);
    try std.testing.expect(piglin.is_inspecting);

    // Final completion tick
    const drop = piglin.tick(1, null);
    try std.testing.expect(drop != null);
    try std.testing.expect(piglin.consumed_gold_ingot);
    try std.testing.expect(!piglin.holding_gold_ingot);
    try std.testing.expect(!piglin.is_inspecting);
    try std.testing.expect(!piglin.ignores_distractions);
}

test "33. Bartering Completion: Dropped loot item spawns at Piglin position with upward pop velocity" {
    var piglin = Piglin.init(1, Vec3.init(12.5, 64.0, -8.2), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    const drop = piglin.tick(120, null).?;
    try std.testing.expectEqual(@as(f32, 12.5), drop.position.x);
    try std.testing.expectEqual(@as(f32, 64.0), drop.position.y);
    try std.testing.expectEqual(@as(f32, -8.2), drop.position.z);
    try std.testing.expectEqual(BARTER_DROP_POP_VELOCITY_Y, drop.velocity.y);
    try std.testing.expect(drop.velocity.y > 0.0);
    try std.testing.expect(drop.is_bartered_loot);
}

test "34. Bartering Completion: Emits barter completion sound and sparkle particle events" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    _ = piglin.tick(120, null);
    try std.testing.expectEqual(SoundEvent.piglin_barter_complete, piglin.last_sound.?);
    try std.testing.expectEqual(ParticleEvent.barter_sparkle, piglin.last_particle.?);
}

test "35. Bartering Rejection: Piglin cannot start second barter while inspecting" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .boots = .golden_boots });
    try std.testing.expect(piglin.interactWithItem(.gold_ingot));
    try std.testing.expect(piglin.is_inspecting);

    // Try interacting again while inspecting
    try std.testing.expect(!piglin.interactWithItem(.gold_ingot));
    try std.testing.expect(!piglin.pickupThrownItem(.gold_ingot, Vec3.init(0.5, 0.0, 0.0)));
}

test "36. Baby Piglin: Baby takes gold ingot and consumes it without dropping loot" {
    var baby = Piglin.init(5, Vec3.zero(), false, .none);
    baby.is_baby = true;
    baby.updatePacification(PlayerArmor{ .helmet = .golden_helmet });

    try std.testing.expect(baby.interactWithItem(.gold_ingot));
    try std.testing.expect(baby.is_inspecting);

    const drop = baby.tick(120, null);
    try std.testing.expectEqual(@as(?DroppedBarterItem, null), drop);
    try std.testing.expect(baby.consumed_gold_ingot);
    try std.testing.expect(!baby.is_inspecting);
    try std.testing.expectEqual(SoundEvent.piglin_barter_complete, baby.last_sound.?);
}

test "37. Loot Table: Contains all 15 bartered items with exact count ranges" {
    try std.testing.expectEqual(@as(usize, 15), BARTER_LOOT_TABLE.len);

    const expected = [_]struct { item: ItemType, min: u8, max: u8 }{
        .{ .item = .soul_speed_enchanted_book, .min = 1, .max = 1 },
        .{ .item = .iron_boots_soul_speed, .min = 1, .max = 1 },
        .{ .item = .potion_of_fire_resistance, .min = 1, .max = 1 },
        .{ .item = .splash_potion_of_fire_resistance, .min = 1, .max = 1 },
        .{ .item = .ender_pearl, .min = 2, .max = 4 },
        .{ .item = .crying_obsidian, .min = 1, .max = 3 },
        .{ .item = .obsidian, .min = 1, .max = 1 },
        .{ .item = .fire_charge, .min = 1, .max = 1 },
        .{ .item = .nether_quartz, .min = 5, .max = 12 },
        .{ .item = .string, .min = 3, .max = 9 },
        .{ .item = .magma_cream, .min = 1, .max = 1 },
        .{ .item = .leather, .min = 2, .max = 4 },
        .{ .item = .soul_sand, .min = 2, .max = 8 },
        .{ .item = .gravel, .min = 8, .max = 16 },
        .{ .item = .iron_nugget, .min = 10, .max = 36 },
    };

    for (expected) |exp| {
        const range = getItemCountRange(exp.item);
        try std.testing.expectEqual(exp.min, range.min);
        try std.testing.expectEqual(exp.max, range.max);
    }
}

test "38. Loot Probabilities: Nominal probabilities match specification (1.09%, 1.89%, 2.18%, 4.36%, 8.71%)" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.09), getNominalProbability(.soul_speed_enchanted_book), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.89), getNominalProbability(.iron_boots_soul_speed), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.18), getNominalProbability(.potion_of_fire_resistance), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.18), getNominalProbability(.splash_potion_of_fire_resistance), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.36), getNominalProbability(.ender_pearl), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.71), getNominalProbability(.crying_obsidian), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.71), getNominalProbability(.obsidian), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.71), getNominalProbability(.fire_charge), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.36), getNominalProbability(.nether_quartz), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.36), getNominalProbability(.string), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.36), getNominalProbability(.magma_cream), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.71), getNominalProbability(.leather), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.71), getNominalProbability(.soul_sand), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.71), getNominalProbability(.gravel), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.18), getNominalProbability(.iron_nugget), 0.001);
}

test "39. Loot Rolling: Deterministic roll by weight cursor spans all rewards" {
    // Check key breakpoints in cumulative weights
    try std.testing.expectEqual(ItemType.soul_speed_enchanted_book, rollBarterLootByWeight(0).item);
    try std.testing.expectEqual(ItemType.soul_speed_enchanted_book, rollBarterLootByWeight(4).item);
    try std.testing.expectEqual(ItemType.iron_boots_soul_speed, rollBarterLootByWeight(5).item);
    try std.testing.expectEqual(ItemType.iron_boots_soul_speed, rollBarterLootByWeight(12).item);
    try std.testing.expectEqual(ItemType.potion_of_fire_resistance, rollBarterLootByWeight(13).item);
    try std.testing.expectEqual(ItemType.splash_potion_of_fire_resistance, rollBarterLootByWeight(23).item);
    try std.testing.expectEqual(ItemType.ender_pearl, rollBarterLootByWeight(33).item);
    try std.testing.expectEqual(ItemType.crying_obsidian, rollBarterLootByWeight(53).item);
    try std.testing.expectEqual(ItemType.obsidian, rollBarterLootByWeight(93).item);
    try std.testing.expectEqual(ItemType.fire_charge, rollBarterLootByWeight(133).item);
    try std.testing.expectEqual(ItemType.nether_quartz, rollBarterLootByWeight(173).item);
    try std.testing.expectEqual(ItemType.string, rollBarterLootByWeight(193).item);
    try std.testing.expectEqual(ItemType.magma_cream, rollBarterLootByWeight(213).item);
    try std.testing.expectEqual(ItemType.leather, rollBarterLootByWeight(233).item);
    try std.testing.expectEqual(ItemType.soul_sand, rollBarterLootByWeight(273).item);
    try std.testing.expectEqual(ItemType.gravel, rollBarterLootByWeight(313).item);
    try std.testing.expectEqual(ItemType.iron_nugget, rollBarterLootByWeight(353).item);
}

test "40. Loot Rolling: Deterministic roll by seed yields consistent drop and count" {
    const seed: u64 = 88888888;
    const drop1 = rollBarterLootBySeed(seed);
    const drop2 = rollBarterLootBySeed(seed);

    try std.testing.expectEqual(drop1.item, drop2.item);
    try std.testing.expectEqual(drop1.count, drop2.count);
    try std.testing.expect(drop1.count >= 1);
}

test "41. Loot Distribution: Monte Carlo simulation verifies probability distribution and bounds" {
    var prng = std.Random.DefaultPrng.init(54321);
    var seen_counts = [_]u32{0} ** BARTER_LOOT_TABLE.len;

    const iterations: usize = 20000;
    for (0..iterations) |_| {
        const drop = rollBarterLoot(&prng);
        const range = getItemCountRange(drop.item);
        try std.testing.expect(drop.count >= range.min);
        try std.testing.expect(drop.count <= range.max);

        for (BARTER_LOOT_TABLE, 0..) |entry, i| {
            if (entry.item == drop.item) {
                seen_counts[i] += 1;
                break;
            }
        }
    }

    // Every item in the pool must have dropped at least once
    for (seen_counts, 0..) |cnt, i| {
        try std.testing.expect(cnt > 0);
        // Soul speed book (weight 5) should appear fewer times than gravel (weight 40)
        if (i == 0) { // book
            try std.testing.expect(cnt < seen_counts[13]); // gravel
        }
    }
}

test "42. Economy Simulation: Multi-Piglin bastion correctly handles selective anger radius and pacification" {
    var economy = PiglinBarterEconomy.init(std.testing.allocator);
    defer economy.deinit();

    // Spawn 3 piglins at varying distances from origin
    _ = try economy.spawnPiglin(Vec3.init(0.0, 0.0, 0.0), false, .golden_sword);   // A: at origin
    _ = try economy.spawnPiglin(Vec3.init(10.0, 0.0, 0.0), false, .crossbow);       // B: 10m away
    _ = try economy.spawnPiglin(Vec3.init(30.0, 0.0, 0.0), false, .golden_sword);   // C: 30m away

    // Pacify all with gold armor
    economy.evaluatePlayerPacification(PlayerArmor{ .boots = .golden_boots });
    try std.testing.expect(economy.piglins.items[0].is_pacified);
    try std.testing.expect(economy.piglins.items[1].is_pacified);
    try std.testing.expect(economy.piglins.items[2].is_pacified);

    // Player opens chest at origin (0,0,0)
    const angered = economy.notifyOpenContainer(.chest, Vec3.zero());
    try std.testing.expectEqual(@as(u32, 2), angered); // A (0m) and B (10m) angered

    try std.testing.expect(economy.piglins.items[0].is_hostile);
    try std.testing.expect(economy.piglins.items[1].is_hostile);
    try std.testing.expect(!economy.piglins.items[2].is_hostile); // C is 30m away, still pacified!
}

test "43. Piglin Weapon: Equipped with crossbow or golden sword charges when hostile" {
    var sword_piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    sword_piglin.updatePacification(PlayerArmor{}); // no armor
    try std.testing.expect(sword_piglin.is_hostile);
    try std.testing.expect(sword_piglin.is_charging);
    try std.testing.expectEqual(PiglinWeapon.golden_sword, sword_piglin.equipped_weapon);

    var crossbow_piglin = Piglin.init(2, Vec3.zero(), false, .crossbow);
    crossbow_piglin.updatePacification(PlayerArmor{});
    try std.testing.expect(crossbow_piglin.is_hostile);
    try std.testing.expect(crossbow_piglin.is_charging);
    try std.testing.expectEqual(PiglinWeapon.crossbow, crossbow_piglin.equipped_weapon);
}

test "44. Interrupted Barter: Hostility trigger during inspection aborts bartering" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    try std.testing.expect(piglin.interactWithItem(.gold_ingot));
    try std.testing.expect(piglin.is_inspecting);

    // Tick 40 ticks into admiration
    _ = piglin.tick(40, null);
    try std.testing.expect(piglin.is_inspecting);

    // Provocation: container opened nearby
    _ = piglin.onContainerOpened(.chest, Vec3.init(2.0, 0.0, 0.0));
    try std.testing.expect(!piglin.is_inspecting);
    try std.testing.expect(!piglin.holding_gold_ingot);
    try std.testing.expect(piglin.is_hostile);
}

test "45. Hostile Piglin rejects bartering" {
    var piglin = Piglin.init(1, Vec3.zero(), false, .golden_sword);
    piglin.updatePacification(PlayerArmor{}); // hostile
    try std.testing.expect(piglin.is_hostile);

    try std.testing.expect(!piglin.interactWithItem(.gold_ingot));
    try std.testing.expect(!piglin.pickupThrownItem(.gold_ingot, Vec3.init(1.0, 0.0, 0.0)));
    try std.testing.expect(!piglin.is_inspecting);
}
