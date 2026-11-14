const std = @import("std");

/// Piglins evaluate nearby guarded blocks across this radius.
pub const guarded_block_anger_radius: f32 = 16.0;
pub const guarded_block_anger_duration: f32 = 30.0;
pub const guarded_block_anger_ticks: u32 = 600;

/// Gold-ingot admiration lasts six seconds at the standard 20 TPS tick rate.
pub const barter_admiration_duration: f32 = 6.0;
pub const barter_admiration_ticks: u32 = 120;

/// Piglins and brutes shiver for fifteen seconds before zombifying in the
/// Overworld or End. Nether piglins do not use this timer.
pub const overworld_zombification_duration: f32 = 15.0;
pub const overworld_zombification_ticks: u32 = 300;

pub const soul_fire_repulsion_radius: f32 = 8.0;
pub const piglin_brute_max_health: f32 = 50.0;
pub const piglin_brute_axe_damage: f32 = 13.0;

/// Standard piglins accept any one piece of golden armor, unless the player
/// has provoked the bastion by opening/mining a guarded block. Brutes ignore
/// armor and are consequently never pacified by this rule.
pub fn isPiglinPacifiedByPlayer(
    wearing_any_gold_armor: bool,
    opened_or_mined_guarded_block: bool,
    is_piglin_brute: bool,
) bool {
    return !is_piglin_brute and wearing_any_gold_armor and !opened_or_mined_guarded_block;
}

/// Returns whether a guarded block interaction at `distance` provokes nearby
/// piglins. The caller can use the result to apply the 30-second anger timer.
pub fn guardedBlockProvokesPiglins(distance: f32) bool {
    return distance >= 0.0 and distance <= guarded_block_anger_radius;
}

pub const PiglinBarterState = struct {
    ticks_remaining: u16 = 0,
    is_baby: bool = false,
    holding_gold: bool = false,
    distracted: bool = false,

    pub fn init(is_baby: bool) PiglinBarterState {
        return .{ .is_baby = is_baby };
    }

    /// Starts (or restarts) the six-second admiration animation.
    pub fn startAdmiring(self: *PiglinBarterState) void {
        self.ticks_remaining = barter_admiration_ticks;
        self.holding_gold = true;
        self.distracted = false;
    }

    /// Advances admiration by game ticks. Returns true on the completion tick.
    pub fn tick(self: *PiglinBarterState, ticks: u32) bool {
        if (!self.holding_gold or self.ticks_remaining == 0) return false;
        const amount: u16 = @intCast(@min(ticks, @as(u32, self.ticks_remaining)));
        self.ticks_remaining -= amount;
        return self.ticks_remaining == 0;
    }

    pub fn isAdmiring(self: PiglinBarterState) bool {
        return self.holding_gold and self.ticks_remaining > 0;
    }

    /// Adult piglins return loot after admiration. Babies keep the ingot; a
    /// distracted baby also keeps it, matching the confiscation behavior.
    pub fn returnsLoot(self: PiglinBarterState) bool {
        return !self.is_baby and self.holding_gold and !self.distracted;
    }

    pub fn babyKeepsGold(self: PiglinBarterState) bool {
        return self.is_baby and self.holding_gold and !self.returnsLoot();
    }
};

pub const BarterLoot = struct {
    item_name: []const u8,
    min_count: u8,
    max_count: u8,
};

// Weighted 8-bit table. The final entry owns the remainder, so every u8 roll
// deterministically yields one of the documented barter rewards.
const barter_loot_table = [_]struct { weight: u16, loot: BarterLoot }{
    .{ .weight = 6, .loot = .{ .item_name = "Ender Pearls", .min_count = 2, .max_count = 4 } },
    .{ .weight = 22, .loot = .{ .item_name = "Crying Obsidian", .min_count = 1, .max_count = 3 } },
    .{ .weight = 22, .loot = .{ .item_name = "Obsidian", .min_count = 1, .max_count = 1 } },
    .{ .weight = 22, .loot = .{ .item_name = "Fire Resistance Potion", .min_count = 1, .max_count = 1 } },
    .{ .weight = 4, .loot = .{ .item_name = "Soul Speed Book", .min_count = 1, .max_count = 1 } },
    .{ .weight = 4, .loot = .{ .item_name = "Soul Speed Boots", .min_count = 1, .max_count = 1 } },
    .{ .weight = 22, .loot = .{ .item_name = "Spectral Arrows", .min_count = 6, .max_count = 12 } },
    .{ .weight = 22, .loot = .{ .item_name = "Nether Quartz", .min_count = 5, .max_count = 12 } },
    .{ .weight = 22, .loot = .{ .item_name = "String", .min_count = 3, .max_count = 9 } },
    .{ .weight = 22, .loot = .{ .item_name = "Gravel", .min_count = 8, .max_count = 16 } },
    .{ .weight = 88, .loot = .{ .item_name = "Iron Nuggets", .min_count = 9, .max_count = 36 } },
};

pub fn rollPiglinBarterLoot(roll: u8) BarterLoot {
    var cursor: u16 = @as(u16, roll);
    for (barter_loot_table) |entry| {
        if (cursor < entry.weight) return entry.loot;
        cursor -= entry.weight;
    }
    return barter_loot_table[barter_loot_table.len - 1].loot;
}

/// `is_overworld_or_end` excludes the Nether, where piglins remain native.
pub fn shouldTransformToZombifiedPiglin(ticks_elapsed: u32, is_overworld_or_end: bool) bool {
    return is_overworld_or_end and ticks_elapsed >= overworld_zombification_ticks;
}

pub fn fleeFromSoulFire(is_brute: bool, dist_to_soul_fire: f32) bool {
    return !is_brute and dist_to_soul_fire >= 0.0 and dist_to_soul_fire <= soul_fire_repulsion_radius;
}

pub const TICKS_PER_SECOND: u32 = 20;

/// Unified 3D vector for Piglin Bastion & Zombified Piglin Swarm mechanics.
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

    pub fn distanceSq(self: Vec3, other: Vec3) f32 {
        return self.distSq(other);
    }

    pub fn distance(self: Vec3, other: Vec3) f32 {
        return self.dist(other);
    }
};

pub const SoundEffect = enum(u8) {
    brute_war_horn,
    brute_angry,
    brute_hurt,
    brute_death,
    brute_step,
    piglin_alarmed,
    piglin_angry,
    piglin_admiring_gold,
    zombified_growl,
    zombified_piglin_screech,
    zombified_piglin_angry,
    zombified_piglin_hurt,
    zombified_piglin_death,
    zombified_piglin_ambient,
    zombified_piglin_reinforcement,
};

pub const ItemType = enum(u16) {
    none = 0,
    gold_ingot = 266,
    golden_helmet = 2,
    golden_chestplate = 3,
    golden_leggings = 4,
    golden_boots = 5,
    golden_sword = 283,
    crossbow = 471,
    golden_axe = 286,

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

    // Additional items
    diamond = 24,
    iron_ingot = 25,
    dirt = 26,
    stone = 27,
    iron_helmet = 28,
    diamond_chestplate = 29,
    leather_boots = 30,
    gold_nugget = 371,
    gold_block = 41,
    porkchop = 319,
    cooked_porkchop = 320,
    rotten_flesh = 367,

    pub fn isGoldenArmor(self: ItemType) bool {
        return switch (self) {
            .golden_helmet, .golden_chestplate, .golden_leggings, .golden_boots => true,
            else => false,
        };
    }

    pub fn isGoldIngot(self: ItemType) bool {
        return self == .gold_ingot;
    }

    pub fn isGold(self: ItemType) bool {
        return switch (self) {
            .gold_ingot, .golden_axe, .golden_sword, .gold_nugget, .gold_block => true,
            else => false,
        };
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
            .porkchop => "Raw Porkchop",
            .cooked_porkchop => "Cooked Porkchop",
            .rotten_flesh => "Rotten Flesh",
        };
    }
};


// ============================================================================
// Core Constants
// ============================================================================

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
        .position = Vec3.zero,
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
    position: Vec3 = Vec3.zero,
    velocity: Vec3 = Vec3.zero,
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
            .velocity = Vec3.zero,
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
        self.velocity = Vec3.zero;
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
                self.velocity = Vec3.zero;
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


// ============================================================================
// Core Constants
// ============================================================================


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
pub const BRUTE_EXPERIENCE_POINTS_DROP: u32 = 20; // 20 XP points
pub const STANDARD_PIGLIN_XP_DROP: u32 = 5;

/// Standard piglin barter admiration ticks (6.0s = 120 ticks)
pub const BARTER_ADMIRATION_TICKS: u16 = 120;

// ============================================================================
// Spatial Mathematics
// ============================================================================


// ============================================================================
// Enums & Classifications
// ============================================================================


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

pub const BruteZombifiedPiglin = struct {
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
    experience_points: u32 = BRUTE_EXPERIENCE_POINTS_DROP,
    drop_chance: f32,
    looting_level: u8,
};

pub fn calculateBruteDefeatDrops(looting_level: u8, roll_0_to_1: f32) PiglinBruteDrops {
    const chance = GOLDEN_AXE_BASE_DROP_CHANCE + @as(f32, @floatFromInt(looting_level)) * LOOTING_DROP_BONUS_PER_LEVEL;
    const dropped = roll_0_to_1 < chance;
    return .{
        .dropped_golden_axe = dropped,
        .golden_axe_damage = PIGLIN_BRUTE_BASE_DAMAGE,
        .experience_points = BRUTE_EXPERIENCE_POINTS_DROP,
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
    zombified_piglin: ?BruteZombifiedPiglin = null,
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
            const zombified = self.transformToBruteZombifiedPiglin();
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
    pub fn transformToBruteZombifiedPiglin(self: PiglinBrute) BruteZombifiedPiglin {
        return .{
            .id = self.id,
            .pos = self.pos,
            .health = PIGLIN_BRUTE_MAX_HEALTH,
            .max_health = PIGLIN_BRUTE_MAX_HEALTH,
            .attack_damage = self.attack_damage,
            .weapon = .golden_axe,
            .is_undead = true,
            .is_immune_to_fire = true,
            .xp_reward = BRUTE_EXPERIENCE_POINTS_DROP,
        };
    }

    /// Roll drops on defeat: Golden Axe (8.5% chance, scaled by Looting), 20 Experience Points.
    pub fn calculateDrops(self: PiglinBrute, looting_level: u8, roll_0_to_1: f32) PiglinBruteDrops {
        _ = self;
        return calculateBruteDefeatDrops(looting_level, roll_0_to_1);
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


// ============================================================================
// Core Constants
// ============================================================================


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


// ============================================================================
// Enums & Classifications
// ============================================================================

/// Zombified Piglin state machine
pub const ZombifiedPiglinState = enum(u8) {
    neutral,
    angered,
    calming,
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

test "gold armor pacifies standard piglins" {
    try std.testing.expect(isPiglinPacifiedByPlayer(true, false, false));
    try std.testing.expect(!isPiglinPacifiedByPlayer(false, false, false));
}

test "all golden armor pieces are represented by one boolean" {
    try std.testing.expect(isPiglinPacifiedByPlayer(true, false, false));
}

test "guarded chest or gold mining provocation overrides armor" {
    try std.testing.expect(!isPiglinPacifiedByPlayer(true, true, false));
    try std.testing.expect(guardedBlockProvokesPiglins(16.0));
    try std.testing.expect(!guardedBlockProvokesPiglins(16.01));
}

test "piglin brute always attacks despite armor" {
    try std.testing.expect(!isPiglinPacifiedByPlayer(true, false, true));
    try std.testing.expectEqual(@as(f32, 50.0), piglin_brute_max_health);
    try std.testing.expectEqual(@as(f32, 13.0), piglin_brute_axe_damage);
}

test "barter admiration lasts exactly 120 ticks" {
    var state = PiglinBarterState.init(false);
    state.startAdmiring();
    try std.testing.expectEqual(@as(u32, 120), barter_admiration_ticks);
    try std.testing.expect(state.isAdmiring());
    try std.testing.expect(!state.tick(119));
    try std.testing.expect(state.tick(1));
    try std.testing.expect(!state.isAdmiring());
}

test "barter tick clamps large advances" {
    var state = PiglinBarterState.init(false);
    state.startAdmiring();
    try std.testing.expect(state.tick(1000));
    try std.testing.expectEqual(@as(u16, 0), state.ticks_remaining);
}

test "adult piglin returns loot after admiration" {
    var state = PiglinBarterState.init(false);
    state.startAdmiring();
    _ = state.tick(barter_admiration_ticks);
    try std.testing.expect(state.returnsLoot());
    try std.testing.expect(!state.babyKeepsGold());
}

test "baby piglin keeps gold without returning loot" {
    var state = PiglinBarterState.init(true);
    state.startAdmiring();
    _ = state.tick(barter_admiration_ticks);
    try std.testing.expect(!state.returnsLoot());
    try std.testing.expect(state.babyKeepsGold());
}

test "distracted adult does not return loot" {
    var state = PiglinBarterState.init(false);
    state.startAdmiring();
    state.distracted = true;
    try std.testing.expect(!state.returnsLoot());
}

test "barter table includes pearls and crying obsidian" {
    try std.testing.expectEqualStrings("Ender Pearls", rollPiglinBarterLoot(0).item_name);
    try std.testing.expectEqualStrings("Crying Obsidian", rollPiglinBarterLoot(6).item_name);
}

test "barter table covers every reward category" {
    const expected = [_][]const u8{ "Ender Pearls", "Crying Obsidian", "Obsidian", "Fire Resistance Potion", "Soul Speed Book", "Soul Speed Boots", "Spectral Arrows", "Nether Quartz", "String", "Gravel", "Iron Nuggets" };
    for (expected) |name| {
        var found = false;
        var roll: u16 = 0;
        while (roll <= 255) : (roll += 1) {
            if (std.mem.eql(u8, rollPiglinBarterLoot(@intCast(roll)).item_name, name)) found = true;
        }
        try std.testing.expect(found);
    }
}

test "loot counts are ordered" {
    var roll: u16 = 0;
    while (roll <= 255) : (roll += 1) {
        const loot = rollPiglinBarterLoot(@intCast(roll));
        try std.testing.expect(loot.min_count <= loot.max_count);
    }
}

test "overworld zombification begins after 300 ticks" {
    try std.testing.expect(!shouldTransformToZombifiedPiglin(299, true));
    try std.testing.expect(shouldTransformToZombifiedPiglin(300, true));
    try std.testing.expect(!shouldTransformToZombifiedPiglin(300, false));
}

test "zombification timer is fifteen seconds" {
    try std.testing.expectEqual(@as(f32, 15.0), overworld_zombification_duration);
    try std.testing.expectEqual(@as(u32, 300), overworld_zombification_ticks);
}

test "normal piglins flee soul fire within eight blocks" {
    try std.testing.expect(fleeFromSoulFire(false, 0.0));
    try std.testing.expect(fleeFromSoulFire(false, 8.0));
    try std.testing.expect(!fleeFromSoulFire(false, 8.01));
}

test "piglin brutes do not flee soul fire" {
    try std.testing.expect(!fleeFromSoulFire(true, 1.0));
    try std.testing.expect(!fleeFromSoulFire(true, 8.0));
}

test "1. Gold armor pacification: golden helmet pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);

    const armor = PlayerArmor{ .helmet = .golden_helmet };
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
    try std.testing.expect(!piglin.is_charging);
}

test "2. Gold armor pacification: golden chestplate pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero, false, .crossbow);
    const armor = PlayerArmor{ .chestplate = .golden_chestplate };
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
}

test "3. Gold armor pacification: golden leggings pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    const armor = PlayerArmor{ .leggings = .golden_leggings };
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
}

test "4. Gold armor pacification: golden boots pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero, false, .crossbow);
    const armor = PlayerArmor{ .boots = .golden_boots };
    piglin.updatePacification(armor);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
}

test "5. Gold armor pacification: full gold armor suit pacifies Piglin" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    const armor = PlayerArmor{};
    piglin.updatePacification(armor);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
    try std.testing.expect(piglin.is_charging);
}

test "7. Gold armor pacification: non-gold armor leaves Piglin hostile" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var brute = Piglin.init(2, Vec3.zero, true, .golden_axe);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
        var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
        piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
        const pos = Vec3.init(3.0, 1.0, 2.0);
        const provoked = piglin.onContainerOpened(container, pos);
        try std.testing.expect(provoked);
        try std.testing.expect(!piglin.is_pacified);
        try std.testing.expect(piglin.is_hostile);
    }
}

test "15. Hostility Trigger: Opening container at 16.0m boundary provokes; 16.01m does not" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .leggings = .golden_leggings });
    try std.testing.expect(piglin.is_pacified);

    const block_pos = Vec3.init(5.0, 0.0, 5.0);
    const provoked = piglin.onGoldBlockBroken(.gold_block, block_pos);
    try std.testing.expect(provoked);
    try std.testing.expect(!piglin.is_pacified);
    try std.testing.expect(piglin.is_hostile);
}

test "17. Hostility Trigger: Breaking gilded blackstone within 16 blocks provokes Piglin" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
        var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
        piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
        const provoked = piglin.onGoldBlockBroken(ore, Vec3.init(4.0, 0.0, 4.0));
        try std.testing.expect(provoked);
        try std.testing.expect(!piglin.is_pacified);
        try std.testing.expect(piglin.is_hostile);
    }
}

test "19. Hostility Trigger: Breaking gold block beyond 16 blocks does not provoke Piglin" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });

    const far_block = Vec3.init(25.0, 0.0, 0.0);
    const provoked = piglin.onGoldBlockBroken(.gold_block, far_block);
    try std.testing.expect(!provoked);
    try std.testing.expect(piglin.is_pacified);
    try std.testing.expect(!piglin.is_hostile);
}

test "20. Hostility Anger Timer: Piglin pacifies again after 600 ticks if player wears gold armor" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    try std.testing.expectEqual(@as(?SoundEvent, null), piglin.last_sound);
    try std.testing.expectEqual(@as(?ParticleEvent, null), piglin.last_particle);

    piglin.triggerAnger(600);
    try std.testing.expectEqual(SoundEvent.piglin_angry, piglin.last_sound.?);
    try std.testing.expectEqual(ParticleEvent.angry_villager, piglin.last_particle.?);
    try std.testing.expect(piglin.sound_event_count >= 1);
    try std.testing.expect(piglin.particle_event_count >= 1);
}

test "22. Bartering Rejection: Right-clicking with non-gold items is rejected" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });

    const near_pos = Vec3.init(1.0, 0.0, 1.0); // ~1.41m
    const accepted = piglin.pickupThrownItem(.iron_ingot, near_pos);
    try std.testing.expect(!accepted);
    try std.testing.expect(!piglin.is_inspecting);
}

test "24. Bartering Interaction: Right-clicking with Gold Ingot starts 120-tick inspection" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    try std.testing.expect(piglin.holding_gold_ingot);
    _ = piglin.tick(50, null);
    try std.testing.expect(piglin.holding_gold_ingot);
    _ = piglin.tick(69, null);
    try std.testing.expect(piglin.holding_gold_ingot);
}

test "29. Bartering Inspection: Piglin ignores distractions while inspecting" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    try std.testing.expect(piglin.ignores_distractions);
    _ = piglin.tick(100, null);
    try std.testing.expect(piglin.ignores_distractions);
}

test "30. Bartering Inspection: Advancing inspection tick by tick decrements remaining timer" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    // Advance 500 ticks at once
    const drop = piglin.tick(500, null);
    try std.testing.expect(drop != null);
    try std.testing.expectEqual(@as(u32, 0), piglin.inspection_ticks_remaining);
    try std.testing.expect(!piglin.is_inspecting);
}

test "32. Bartering Completion: Ingot consumed and exactly 1 barter loot item dispensed at 120 ticks" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .helmet = .golden_helmet });
    _ = piglin.interactWithItem(.gold_ingot);

    _ = piglin.tick(120, null);
    try std.testing.expectEqual(SoundEvent.piglin_barter_complete, piglin.last_sound.?);
    try std.testing.expectEqual(ParticleEvent.barter_sparkle, piglin.last_particle.?);
}

test "35. Bartering Rejection: Piglin cannot start second barter while inspecting" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    piglin.updatePacification(PlayerArmor{ .boots = .golden_boots });
    try std.testing.expect(piglin.interactWithItem(.gold_ingot));
    try std.testing.expect(piglin.is_inspecting);

    // Try interacting again while inspecting
    try std.testing.expect(!piglin.interactWithItem(.gold_ingot));
    try std.testing.expect(!piglin.pickupThrownItem(.gold_ingot, Vec3.init(0.5, 0.0, 0.0)));
}

test "36. Baby Piglin: Baby takes gold ingot and consumes it without dropping loot" {
    var baby = Piglin.init(5, Vec3.zero, false, .none);
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
    const angered = economy.notifyOpenContainer(.chest, Vec3.zero);
    try std.testing.expectEqual(@as(u32, 2), angered); // A (0m) and B (10m) angered

    try std.testing.expect(economy.piglins.items[0].is_hostile);
    try std.testing.expect(economy.piglins.items[1].is_hostile);
    try std.testing.expect(!economy.piglins.items[2].is_hostile); // C is 30m away, still pacified!
}

test "43. Piglin Weapon: Equipped with crossbow or golden sword charges when hostile" {
    var sword_piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    sword_piglin.updatePacification(PlayerArmor{}); // no armor
    try std.testing.expect(sword_piglin.is_hostile);
    try std.testing.expect(sword_piglin.is_charging);
    try std.testing.expectEqual(PiglinWeapon.golden_sword, sword_piglin.equipped_weapon);

    var crossbow_piglin = Piglin.init(2, Vec3.zero, false, .crossbow);
    crossbow_piglin.updatePacification(PlayerArmor{});
    try std.testing.expect(crossbow_piglin.is_hostile);
    try std.testing.expect(crossbow_piglin.is_charging);
    try std.testing.expectEqual(PiglinWeapon.crossbow, crossbow_piglin.equipped_weapon);
}

test "44. Interrupted Barter: Hostility trigger during inspection aborts bartering" {
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
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
    var piglin = Piglin.init(1, Vec3.zero, false, .golden_sword);
    piglin.updatePacification(PlayerArmor{}); // hostile
    try std.testing.expect(piglin.is_hostile);

    try std.testing.expect(!piglin.interactWithItem(.gold_ingot));
    try std.testing.expect(!piglin.pickupThrownItem(.gold_ingot, Vec3.init(1.0, 0.0, 0.0)));
    try std.testing.expect(!piglin.is_inspecting);
}

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
    const zombified = brute.transformToBruteZombifiedPiglin();

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
    try std.testing.expectEqual(@as(u32, 20), BRUTE_EXPERIENCE_POINTS_DROP);
}

test "33: Drops on defeat: Golden Axe drops at base 8.5% chance without Looting" {
    try std.testing.expectEqual(@as(f32, 0.085), GOLDEN_AXE_BASE_DROP_CHANCE);

    // Roll 0.08 is < 0.085 -> drops axe
    const drop_success = calculateBruteDefeatDrops(0, 0.08);
    try std.testing.expect(drop_success.dropped_golden_axe);
    try std.testing.expectApproxEqAbs(@as(f32, 0.085), drop_success.drop_chance, 0.0001);

    // Roll 0.086 is >= 0.085 -> does not drop axe
    const drop_fail = calculateBruteDefeatDrops(0, 0.086);
    try std.testing.expect(!drop_fail.dropped_golden_axe);
}

test "34: Drops on defeat: Looting I increases drop chance to 9.5%" {
    const drops = calculateBruteDefeatDrops(1, 0.09);
    try std.testing.expectApproxEqAbs(@as(f32, 0.095), drops.drop_chance, 0.0001);
    try std.testing.expect(drops.dropped_golden_axe);

    const fail = calculateBruteDefeatDrops(1, 0.096);
    try std.testing.expect(!fail.dropped_golden_axe);
}

test "35: Drops on defeat: Looting III increases drop chance to 11.5%" {
    const drops = calculateBruteDefeatDrops(3, 0.11);
    try std.testing.expectApproxEqAbs(@as(f32, 0.115), drops.drop_chance, 0.0001);
    try std.testing.expect(drops.dropped_golden_axe);

    const fail = calculateBruteDefeatDrops(3, 0.12);
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
