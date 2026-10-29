const std = @import("std");

/// Game tick rate: 20 ticks per second (50ms per tick).
pub const TICKS_PER_SECOND: u32 = 20;
pub const SECONDS_PER_TICK: f32 = 0.05;

/// Regular furnace cook duration: 200 game ticks (10.0 seconds).
pub const REGULAR_FURNACE_COOK_TICKS: u32 = 200;
pub const REGULAR_FURNACE_COOK_SECONDS: f32 = 10.0;

/// Specialized furnace (Blast Furnace & Smoker) cook duration: 100 game ticks (5.0 seconds).
/// This represents a 2x smelting speedup over the regular furnace.
pub const SPECIALIZED_FURNACE_COOK_TICKS: u32 = 100;
pub const SPECIALIZED_FURNACE_COOK_SECONDS: f32 = 5.0;

/// Speedup multiplier for specialized pyrometallurgy workstations (2x).
pub const SPEED_MULTIPLIER: u32 = 2;

/// Fuel consumption rate multiplier for specialized furnaces (2x burn rate).
/// Fuel duration in ticks is halved, preserving the total number of items smelted per fuel unit.
pub const FUEL_BURN_RATE_MULTIPLIER: u32 = 2;

/// Specialized furnace classification: Blast Furnace for metallurgy, Smoker for food.
pub const SpecializedFurnaceType = enum {
    blast_furnace,
    smoker,

    pub fn cookTimeTicks(self: SpecializedFurnaceType) u32 {
        _ = self;
        return SPECIALIZED_FURNACE_COOK_TICKS;
    }

    pub fn cookTimeSeconds(self: SpecializedFurnaceType) f32 {
        _ = self;
        return SPECIALIZED_FURNACE_COOK_SECONDS;
    }

    pub fn fuelBurnRateMultiplier(self: SpecializedFurnaceType) u32 {
        _ = self;
        return FUEL_BURN_RATE_MULTIPLIER;
    }
};

/// Comprehensive workstation family enum including regular furnace.
pub const FurnaceKind = enum {
    regular_furnace,
    blast_furnace,
    smoker,

    pub fn isSpecialized(self: FurnaceKind) bool {
        return self == .blast_furnace or self == .smoker;
    }

    pub fn cookTimeTicks(self: FurnaceKind) u32 {
        return switch (self) {
            .regular_furnace => REGULAR_FURNACE_COOK_TICKS,
            .blast_furnace, .smoker => SPECIALIZED_FURNACE_COOK_TICKS,
        };
    }

    pub fn cookTimeSeconds(self: FurnaceKind) f32 {
        return switch (self) {
            .regular_furnace => REGULAR_FURNACE_COOK_SECONDS,
            .blast_furnace, .smoker => SPECIALIZED_FURNACE_COOK_SECONDS,
        };
    }

    pub fn fuelBurnRateMultiplier(self: FurnaceKind) u32 {
        return switch (self) {
            .regular_furnace => 1,
            .blast_furnace, .smoker => FUEL_BURN_RATE_MULTIPLIER,
        };
    }
};

/// Item representation for smelting operations, matching Minecraft pyrometallurgy IDs.
pub const Item = enum(u16) {
    none = 0,

    // Basic blocks & materials
    stone = 1,
    wood = 5,
    wood_planks = 7,
    stick = 8,
    cobblestone = 11,
    coal = 12,
    iron_ore = 13,
    sand = 14,
    glass = 15,
    brick = 17,
    raw_porkchop = 18,
    raw_mutton = 19,
    cooked_porkchop = 20,
    cooked_mutton = 21,
    apple = 23,
    iron_ingot = 26,
    iron_pickaxe = 27,
    iron_sword = 31,
    cactus = 45,
    lava_bucket = 47,
    nether_quartz_ore = 54,
    nether_quartz = 55,
    ancient_debris = 70,
    netherite_scrap = 71,
    gold_nugget = 81,
    blaze_rod = 107,
    rotten_flesh = 145,
    chorus_fruit = 156,
    popped_chorus_fruit = 157,
    raw_cod = 184,
    cooked_cod = 185,
    kelp = 187,
    dried_kelp = 188,
    dried_kelp_block = 189,
    raw_salmon = 191,
    cooked_salmon = 192,
    gold_ore = 215,
    diamond = 217,
    diamond_ore = 218,
    iron_axe = 229,
    iron_shovel = 233,
    iron_hoe = 237,
    iron_helmet = 241,
    iron_chestplate = 242,
    iron_leggings = 243,
    iron_boots = 244,
    golden_helmet = 245,
    golden_chestplate = 246,
    golden_leggings = 247,
    golden_boots = 248,
    golden_sword = 254,
    golden_pickaxe = 255,
    golden_axe = 256,
    golden_shovel = 257,
    golden_hoe = 258,
    bread = 268,
    emerald = 273,
    emerald_ore = 274,
    raw_copper = 283,
    copper_ingot = 284,
    copper_ore = 285,
    clay_ball = 325,
    clay = 326,
    terracotta = 327,
    bamboo = 340,
    scaffolding = 341,
    potato = 342,
    baked_potato = 343,
    chainmail_helmet = 357,
    chainmail_chestplate = 358,
    chainmail_leggings = 359,
    chainmail_boots = 360,
    iron_horse_armor = 466,
    golden_horse_armor = 467,

    // Extended IDs for items required by pyrometallurgy
    charcoal = 533,
    coal_block = 534,
    bucket = 535,
    raw_iron = 536,
    raw_gold = 537,
    gold_ingot = 538,
    iron_nugget = 539,
    raw_beef = 540,
    raw_chicken = 541,
    raw_rabbit = 542,
    cooked_beef = 543,
    cooked_chicken = 544,
    cooked_rabbit = 545,

    // Aliases for convenience
    pub const raw_pork = Item.raw_porkchop;
    pub const cooked_pork = Item.cooked_porkchop;
    pub const steak = Item.cooked_beef;

    pub fn maxStackSize(self: Item) u16 {
        return switch (self) {
            .none => 0,
            // Non-stackable equipment & containers
            .iron_pickaxe,
            .iron_sword,
            .iron_axe,
            .iron_shovel,
            .iron_hoe,
            .iron_helmet,
            .iron_chestplate,
            .iron_leggings,
            .iron_boots,
            .iron_horse_armor,
            .golden_sword,
            .golden_pickaxe,
            .golden_axe,
            .golden_shovel,
            .golden_hoe,
            .golden_helmet,
            .golden_chestplate,
            .golden_leggings,
            .golden_boots,
            .golden_horse_armor,
            .chainmail_helmet,
            .chainmail_chestplate,
            .chainmail_leggings,
            .chainmail_boots,
            .lava_bucket,
            => 1,

            // Buckets stack to 16
            .bucket => 16,

            // Default stack size in Minecraft
            else => 64,
        };
    }

    pub fn isFuel(self: Item) bool {
        return self.baseBurnDurationTicks() > 0;
    }

    /// Base fuel burn duration in game ticks for a regular furnace.
    pub fn baseBurnDurationTicks(self: Item) u32 {
        return switch (self) {
            .lava_bucket => 20000, // 1000.0s (100 items @ 200t)
            .coal_block => 16000, // 800.0s (80 items)
            .dried_kelp_block => 4000, // 200.0s (20 items)
            .blaze_rod => 2400, // 120.0s (12 items)
            .coal, .charcoal => 1600, // 80.0s (8 items)
            .wood_planks => 300, // 15.0s (1.5 items)
            .stick => 100, // 5.0s (0.5 items)
            .bamboo, .scaffolding => 50, // 2.5s (0.25 items)
            else => 0,
        };
    }

    /// Fuel burn duration in ticks for the specified furnace.
    /// In specialized furnaces (Blast Furnace & Smoker), the duration is halved.
    pub fn burnDurationTicks(self: Item, furnace_type: SpecializedFurnaceType) u32 {
        _ = furnace_type;
        return self.baseBurnDurationTicks() / FUEL_BURN_RATE_MULTIPLIER;
    }

    /// Fuel burn duration in ticks for any furnace kind.
    pub fn burnDurationTicksForKind(self: Item, kind: FurnaceKind) u32 {
        const base = self.baseBurnDurationTicks();
        return switch (kind) {
            .regular_furnace => base,
            .blast_furnace, .smoker => base / FUEL_BURN_RATE_MULTIPLIER,
        };
    }

    /// What remains in the fuel slot when this fuel item finishes burning.
    pub fn fuelRemainder(self: Item) Item {
        return switch (self) {
            .lava_bucket => .bucket,
            else => .none,
        };
    }
};

/// Smelting recipe definition.
pub const SmeltRecipe = struct {
    input: Item,
    output: Item,
    output_count: u8 = 1,
    experience: f32,
    cook_ticks: u32,
};

/// Checks if an item is a raw metal accepted by the blast furnace.
pub fn isRawMetal(item: Item) bool {
    return switch (item) {
        .raw_iron, .raw_copper, .raw_gold => true,
        else => false,
    };
}

/// Checks if an item is an ore or ancient debris accepted by the blast furnace.
pub fn isSmeltableMetalOre(item: Item) bool {
    return switch (item) {
        .iron_ore, .copper_ore, .gold_ore, .ancient_debris => true,
        else => false,
    };
}

/// Checks if an item is chainmail armor accepted by the blast furnace.
pub fn isChainmailArmor(item: Item) bool {
    return switch (item) {
        .chainmail_helmet,
        .chainmail_chestplate,
        .chainmail_leggings,
        .chainmail_boots,
        => true,
        else => false,
    };
}

/// Checks if an item is iron equipment (tools or armor) accepted by the blast furnace.
pub fn isIronToolOrArmor(item: Item) bool {
    return switch (item) {
        .iron_pickaxe,
        .iron_sword,
        .iron_axe,
        .iron_shovel,
        .iron_hoe,
        .iron_helmet,
        .iron_chestplate,
        .iron_leggings,
        .iron_boots,
        .iron_horse_armor,
        => true,
        else => false,
    };
}

/// Checks if an item is golden equipment (tools or armor) accepted by the blast furnace.
pub fn isGoldenToolOrArmor(item: Item) bool {
    return switch (item) {
        .golden_sword,
        .golden_pickaxe,
        .golden_axe,
        .golden_shovel,
        .golden_hoe,
        .golden_helmet,
        .golden_chestplate,
        .golden_leggings,
        .golden_boots,
        .golden_horse_armor,
        => true,
        else => false,
    };
}

/// Strict Blast Furnace ingredient filtering:
/// Accepts ONLY: raw iron, raw copper, raw gold, iron ore, copper ore, gold ore,
/// ancient debris, chainmail armor, iron tools/armor, golden tools/armor.
/// Rejects foods, wood, stone, sand, clay, gems.
pub fn isBlastFurnaceAccepted(item: Item) bool {
    return isRawMetal(item) or
        isSmeltableMetalOre(item) or
        isChainmailArmor(item) or
        isIronToolOrArmor(item) or
        isGoldenToolOrArmor(item);
}

/// Checks if an item is a food ingredient accepted by the smoker.
/// Smoker accepts ONLY: raw beef, raw porkchop, raw chicken, raw mutton,
/// raw rabbit, raw cod, raw salmon, potato, kelp.
pub fn isSmokerAccepted(item: Item) bool {
    return switch (item) {
        .raw_beef,
        .raw_porkchop,
        .raw_chicken,
        .raw_mutton,
        .raw_rabbit,
        .raw_cod,
        .raw_salmon,
        .potato,
        .kelp,
        => true,
        else => false,
    };
}

/// Universal ingredient filter for specialized furnaces.
pub fn isAccepted(item: Item, furnace_type: SpecializedFurnaceType) bool {
    return switch (furnace_type) {
        .blast_furnace => isBlastFurnaceAccepted(item),
        .smoker => isSmokerAccepted(item),
    };
}

/// Resolves standard smelting recipe outputs and XP drop values.
/// Preserves standard vanilla outputs and XP rewards.
pub fn getRecipe(item: Item, furnace_type: SpecializedFurnaceType) ?SmeltRecipe {
    if (!isAccepted(item, furnace_type)) return null;

    switch (furnace_type) {
        .blast_furnace => {
            // Raw metals -> ingots (XP: 0.7 for iron/copper, 1.0 for gold)
            if (item == .raw_iron) return SmeltRecipe{ .input = item, .output = .iron_ingot, .output_count = 1, .experience = 0.7, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };
            if (item == .raw_copper) return SmeltRecipe{ .input = item, .output = .copper_ingot, .output_count = 1, .experience = 0.7, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };
            if (item == .raw_gold) return SmeltRecipe{ .input = item, .output = .gold_ingot, .output_count = 1, .experience = 1.0, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };

            // Ores -> ingots / scrap (XP: 0.7 iron/copper, 1.0 gold, 2.0 ancient debris)
            if (item == .iron_ore) return SmeltRecipe{ .input = item, .output = .iron_ingot, .output_count = 1, .experience = 0.7, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };
            if (item == .copper_ore) return SmeltRecipe{ .input = item, .output = .copper_ingot, .output_count = 1, .experience = 0.7, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };
            if (item == .gold_ore) return SmeltRecipe{ .input = item, .output = .gold_ingot, .output_count = 1, .experience = 1.0, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };
            if (item == .ancient_debris) return SmeltRecipe{ .input = item, .output = .netherite_scrap, .output_count = 1, .experience = 2.0, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };

            // Chainmail armor -> 1 iron nugget (XP: 0.1)
            if (isChainmailArmor(item)) {
                return SmeltRecipe{ .input = item, .output = .iron_nugget, .output_count = 1, .experience = 0.1, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };
            }

            // Iron tools & armor -> 1 iron nugget (XP: 0.1)
            if (isIronToolOrArmor(item)) {
                return SmeltRecipe{ .input = item, .output = .iron_nugget, .output_count = 1, .experience = 0.1, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };
            }

            // Golden tools & armor -> 1 gold nugget (XP: 0.1)
            if (isGoldenToolOrArmor(item)) {
                return SmeltRecipe{ .input = item, .output = .gold_nugget, .output_count = 1, .experience = 0.1, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS };
            }

            return null;
        },

        .smoker => {
            // Meats & Fish & Crops -> cooked variants (XP: 0.35 for meats/fish/potato, 0.1 for kelp)
            return switch (item) {
                .raw_beef => SmeltRecipe{ .input = item, .output = .cooked_beef, .output_count = 1, .experience = 0.35, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS },
                .raw_porkchop => SmeltRecipe{ .input = item, .output = .cooked_porkchop, .output_count = 1, .experience = 0.35, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS },
                .raw_chicken => SmeltRecipe{ .input = item, .output = .cooked_chicken, .output_count = 1, .experience = 0.35, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS },
                .raw_mutton => SmeltRecipe{ .input = item, .output = .cooked_mutton, .output_count = 1, .experience = 0.35, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS },
                .raw_rabbit => SmeltRecipe{ .input = item, .output = .cooked_rabbit, .output_count = 1, .experience = 0.35, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS },
                .raw_cod => SmeltRecipe{ .input = item, .output = .cooked_cod, .output_count = 1, .experience = 0.35, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS },
                .raw_salmon => SmeltRecipe{ .input = item, .output = .cooked_salmon, .output_count = 1, .experience = 0.35, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS },
                .potato => SmeltRecipe{ .input = item, .output = .baked_potato, .output_count = 1, .experience = 0.35, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS },
                .kelp => SmeltRecipe{ .input = item, .output = .dried_kelp, .output_count = 1, .experience = 0.1, .cook_ticks = SPECIALIZED_FURNACE_COOK_TICKS },
                else => null,
            };
        },
    }
}

/// Standard furnace recipe lookup for comparison.
pub fn getRegularFurnaceRecipe(item: Item) ?SmeltRecipe {
    if (item == .chorus_fruit) return SmeltRecipe{ .input = item, .output = .popped_chorus_fruit, .output_count = 1, .experience = 0.1, .cook_ticks = REGULAR_FURNACE_COOK_TICKS };
    // If it's a blast furnace or smoker recipe, regular furnace also supports it with 200 ticks
    if (getRecipe(item, .blast_furnace)) |r| {
        var copy = r;
        copy.cook_ticks = REGULAR_FURNACE_COOK_TICKS;
        return copy;
    }
    if (getRecipe(item, .smoker)) |r| {
        var copy = r;
        copy.cook_ticks = REGULAR_FURNACE_COOK_TICKS;
        return copy;
    }

    // Additional general furnace recipes (sand, clay, stone, cactus, etc.)
    return switch (item) {
        .sand => SmeltRecipe{ .input = item, .output = .glass, .output_count = 1, .experience = 0.1, .cook_ticks = REGULAR_FURNACE_COOK_TICKS },
        .cobblestone => SmeltRecipe{ .input = item, .output = .stone, .output_count = 1, .experience = 0.1, .cook_ticks = REGULAR_FURNACE_COOK_TICKS },
        .clay_ball => SmeltRecipe{ .input = item, .output = .brick, .output_count = 1, .experience = 0.3, .cook_ticks = REGULAR_FURNACE_COOK_TICKS },
        .clay => SmeltRecipe{ .input = item, .output = .terracotta, .output_count = 1, .experience = 0.35, .cook_ticks = REGULAR_FURNACE_COOK_TICKS },
        else => null,
    };
}

test "regular furnace smelts chorus fruit into popped fruit in 200 ticks" {
    const recipe = getRegularFurnaceRecipe(.chorus_fruit).?;
    try std.testing.expectEqual(Item.popped_chorus_fruit, recipe.output);
    try std.testing.expectEqual(@as(u16, 1), recipe.output_count);
    try std.testing.expectEqual(REGULAR_FURNACE_COOK_TICKS, recipe.cook_ticks);
}

/// One inventory slot inside a furnace container.
pub const InventorySlot = struct {
    item: Item = .none,
    count: u16 = 0,
    max_stack: u16 = 64,

    pub fn isEmpty(self: InventorySlot) bool {
        return self.count == 0 or self.item == .none;
    }

    pub fn fullnessFraction(self: InventorySlot) f64 {
        if (self.isEmpty()) return 0.0;
        const effective_max = @max(1, self.max_stack);
        const effective_count = @min(self.count, effective_max);
        return @as(f64, @floatFromInt(effective_count)) / @as(f64, @floatFromInt(effective_max));
    }
};

/// Computes the vanilla Redstone Comparator signal output (0..15) for container slots.
///
/// Formula:
/// If container is empty, returns 0.
/// Otherwise: floor(1.0 + (sum(slot_count / slot_max_stack) / total_slots) * 14.0).
/// When all slots are completely full, output evaluates to exactly 15.
pub fn computeComparatorSignal(slots: []const InventorySlot) u4 {
    if (slots.len == 0) return 0;
    var total_fullness: f64 = 0.0;
    var has_items = false;

    for (slots) |slot| {
        if (!slot.isEmpty()) {
            has_items = true;
            total_fullness += slot.fullnessFraction();
        }
    }

    if (!has_items) return 0;

    const average_fullness = total_fullness / @as(f64, @floatFromInt(slots.len));
    const signal: u4 = @intFromFloat(@floor(1.0 + average_fullness * 14.0));
    return @min(15, signal);
}

/// Helper function to compute comparator signal directly from raw slot counts and stack limits.
pub fn computeComparatorSignalFromSlots(
    input_count: u16,
    input_max: u16,
    fuel_count: u16,
    fuel_max: u16,
    output_count: u16,
    output_max: u16,
) u4 {
    const slots = [3]InventorySlot{
        .{ .item = if (input_count > 0) .stone else .none, .count = input_count, .max_stack = input_max },
        .{ .item = if (fuel_count > 0) .coal else .none, .count = fuel_count, .max_stack = fuel_max },
        .{ .item = if (output_count > 0) .iron_ingot else .none, .count = output_count, .max_stack = output_max },
    };
    return computeComparatorSignal(&slots);
}

/// Furnace container inventory: 3 slots (Input slot 0, Fuel slot 1, Output slot 2).
pub const FurnaceInventory = struct {
    pub const SLOT_COUNT: usize = 3;
    pub const INPUT_SLOT: usize = 0;
    pub const FUEL_SLOT: usize = 1;
    pub const OUTPUT_SLOT: usize = 2;

    slots: [3]InventorySlot = [3]InventorySlot{
        .{ .item = .none, .count = 0, .max_stack = 64 },
        .{ .item = .none, .count = 0, .max_stack = 64 },
        .{ .item = .none, .count = 0, .max_stack = 64 },
    },

    pub fn init() FurnaceInventory {
        return .{};
    }

    pub fn setInput(self: *FurnaceInventory, item: Item, count: u16) void {
        self.slots[INPUT_SLOT] = .{
            .item = item,
            .count = count,
            .max_stack = item.maxStackSize(),
        };
    }

    pub fn setFuel(self: *FurnaceInventory, item: Item, count: u16) void {
        self.slots[FUEL_SLOT] = .{
            .item = item,
            .count = count,
            .max_stack = item.maxStackSize(),
        };
    }

    pub fn setOutput(self: *FurnaceInventory, item: Item, count: u16) void {
        self.slots[OUTPUT_SLOT] = .{
            .item = item,
            .count = count,
            .max_stack = item.maxStackSize(),
        };
    }

    pub fn getInput(self: FurnaceInventory) InventorySlot {
        return self.slots[INPUT_SLOT];
    }

    pub fn getFuel(self: FurnaceInventory) InventorySlot {
        return self.slots[FUEL_SLOT];
    }

    pub fn getOutput(self: FurnaceInventory) InventorySlot {
        return self.slots[OUTPUT_SLOT];
    }

    pub fn comparatorSignal(self: FurnaceInventory) u4 {
        return computeComparatorSignal(&self.slots);
    }

    pub fn isEmpty(self: FurnaceInventory) bool {
        return self.slots[0].isEmpty() and self.slots[1].isEmpty() and self.slots[2].isEmpty();
    }
};

/// Outcome record returned from each simulation tick of a specialized furnace.
pub const TickOutcome = struct {
    item_smelted: bool = false,
    smelted_item: Item = .none,
    smelted_count: u8 = 0,
    xp_banked: f32 = 0.0,
    fuel_consumed: bool = false,
    fuel_item: Item = .none,
    lit_state_changed: bool = false,
};

/// Specialized furnace state machine (Blast Furnace or Smoker).
pub const SpecializedFurnace = struct {
    furnace_type: SpecializedFurnaceType,
    inventory: FurnaceInventory = .{},
    burn_ticks_remaining: u32 = 0,
    burn_duration_ticks: u32 = 0,
    cook_ticks: u32 = 0,
    cook_ticks_required: u32 = SPECIALIZED_FURNACE_COOK_TICKS,
    stored_xp: f32 = 0.0,

    pub fn init(furnace_type: SpecializedFurnaceType) SpecializedFurnace {
        return .{
            .furnace_type = furnace_type,
            .inventory = .{},
            .burn_ticks_remaining = 0,
            .burn_duration_ticks = 0,
            .cook_ticks = 0,
            .cook_ticks_required = SPECIALIZED_FURNACE_COOK_TICKS,
            .stored_xp = 0.0,
        };
    }

    pub fn isLit(self: SpecializedFurnace) bool {
        return self.burn_ticks_remaining > 0;
    }

    pub fn setInput(self: *SpecializedFurnace, item: Item, count: u16) void {
        self.inventory.setInput(item, count);
    }

    pub fn setFuel(self: *SpecializedFurnace, item: Item, count: u16) void {
        self.inventory.setFuel(item, count);
    }

    pub fn setOutput(self: *SpecializedFurnace, item: Item, count: u16) void {
        self.inventory.setOutput(item, count);
    }

    pub fn comparatorSignal(self: SpecializedFurnace) u4 {
        return self.inventory.comparatorSignal();
    }

    /// Checks if the furnace can smelt its current input slot.
    pub fn canSmeltCurrentInput(self: SpecializedFurnace) bool {
        const in_slot = self.inventory.getInput();
        if (in_slot.isEmpty()) return false;

        const recipe = getRecipe(in_slot.item, self.furnace_type) orelse return false;
        const out_slot = self.inventory.getOutput();

        if (out_slot.isEmpty()) return true;
        if (out_slot.item != recipe.output) return false;
        return (out_slot.count + recipe.output_count) <= out_slot.max_stack;
    }

    /// Consumes one fuel item from the fuel slot and initiates fuel burning.
    pub fn consumeFuel(self: *SpecializedFurnace) ?Item {
        var fuel_slot = self.inventory.getFuel();
        if (fuel_slot.isEmpty() or !fuel_slot.item.isFuel()) return null;

        const fuel = fuel_slot.item;
        const duration = fuel.burnDurationTicks(self.furnace_type);
        if (duration == 0) return null;

        self.burn_duration_ticks = duration;
        self.burn_ticks_remaining = duration;

        fuel_slot.count -= 1;
        const remainder = fuel.fuelRemainder();
        if (fuel_slot.count == 0) {
            if (remainder != .none) {
                fuel_slot.item = remainder;
                fuel_slot.count = 1;
                fuel_slot.max_stack = remainder.maxStackSize();
            } else {
                fuel_slot.item = .none;
            }
        }
        self.inventory.slots[FurnaceInventory.FUEL_SLOT] = fuel_slot;
        return fuel;
    }

    /// Advances the furnace simulation by exactly one game tick (50ms).
    pub fn tick(self: *SpecializedFurnace) TickOutcome {
        var outcome = TickOutcome{};
        const was_lit = self.isLit();

        // 1. Check recipe validity
        const can_smelt = self.canSmeltCurrentInput();

        // 2. If can smelt and not lit, ignite fuel
        if (can_smelt and self.burn_ticks_remaining == 0) {
            if (self.consumeFuel()) |f| {
                outcome.fuel_consumed = true;
                outcome.fuel_item = f;
            }
        }

        const is_currently_lit = self.isLit();

        // 3. Decrement fuel burn timer if active
        if (self.burn_ticks_remaining > 0) {
            self.burn_ticks_remaining -= 1;
        }

        // 4. Progress cooking or decay progress
        if (is_currently_lit and can_smelt) {
            self.cook_ticks += 1;
            if (self.cook_ticks >= self.cook_ticks_required) {
                self.cook_ticks = 0;
                const recipe = getRecipe(self.inventory.getInput().item, self.furnace_type).?;

                // Decrement input
                var in_slot = self.inventory.getInput();
                in_slot.count -= 1;
                if (in_slot.count == 0) in_slot.item = .none;
                self.inventory.slots[FurnaceInventory.INPUT_SLOT] = in_slot;

                // Add to output
                var out_slot = self.inventory.getOutput();
                out_slot.item = recipe.output;
                out_slot.count += recipe.output_count;
                out_slot.max_stack = recipe.output.maxStackSize();
                self.inventory.slots[FurnaceInventory.OUTPUT_SLOT] = out_slot;

                // Bank experience
                self.stored_xp += recipe.experience;

                outcome.item_smelted = true;
                outcome.smelted_item = recipe.output;
                outcome.smelted_count = recipe.output_count;
                outcome.xp_banked = recipe.experience;
            }
        } else {
            // When not actively cooking (unlit or stalled), cook progress decays by 2 per tick
            if (self.cook_ticks > 0) {
                self.cook_ticks = if (self.cook_ticks >= 2) self.cook_ticks - 2 else 0;
            }
        }

        if (was_lit != self.isLit()) {
            outcome.lit_state_changed = true;
        }

        return outcome;
    }

    /// Advances the furnace simulation by a number of ticks.
    pub fn tickTicks(self: *SpecializedFurnace, ticks: u32) void {
        var i: u32 = 0;
        while (i < ticks) : (i += 1) {
            _ = self.tick();
        }
    }

    /// Advances the furnace simulation by a duration in seconds.
    pub fn tickSeconds(self: *SpecializedFurnace, seconds: f32) void {
        const total_ticks: u32 = @intFromFloat(@max(0.0, @round(seconds * @as(f32, @floatFromInt(TICKS_PER_SECOND)))));
        self.tickTicks(total_ticks);
    }

    /// Empties the output slot and returns the extracted items.
    pub fn collectOutput(self: *SpecializedFurnace) InventorySlot {
        const out = self.inventory.getOutput();
        self.inventory.setOutput(.none, 0);
        return out;
    }

    /// Player collects output items: collects stored XP and clears the XP bank.
    /// If extracted by hopper (player_collected == false), XP remains banked in the furnace.
    pub fn collectXp(self: *SpecializedFurnace, player_collected: bool) f32 {
        if (!player_collected) return 0.0;
        const xp = self.stored_xp;
        self.stored_xp = 0.0;
        return xp;
    }
};

// ============================================================================
// UNIT TESTS (15+ Comprehensive Tests)
// ============================================================================

test "1. cook time mechanics: specialized 100 ticks (5.0s) vs standard 200 ticks (10.0s)" {
    // Blast furnace and smoker both have 100-tick cook time (5.0s)
    try std.testing.expectEqual(@as(u32, 100), SPECIALIZED_FURNACE_COOK_TICKS);
    try std.testing.expectEqual(@as(f32, 5.0), SPECIALIZED_FURNACE_COOK_SECONDS);
    try std.testing.expectEqual(@as(u32, 2), SPEED_MULTIPLIER);

    // Regular furnace has 200-tick cook time (10.0s)
    try std.testing.expectEqual(@as(u32, 200), REGULAR_FURNACE_COOK_TICKS);
    try std.testing.expectEqual(@as(f32, 10.0), REGULAR_FURNACE_COOK_SECONDS);

    // Verify via FurnaceKind methods
    try std.testing.expectEqual(@as(u32, 100), FurnaceKind.blast_furnace.cookTimeTicks());
    try std.testing.expectEqual(@as(u32, 100), FurnaceKind.smoker.cookTimeTicks());
    try std.testing.expectEqual(@as(u32, 200), FurnaceKind.regular_furnace.cookTimeTicks());

    try std.testing.expectEqual(@as(f32, 5.0), FurnaceKind.blast_furnace.cookTimeSeconds());
    try std.testing.expectEqual(@as(f32, 5.0), FurnaceKind.smoker.cookTimeSeconds());
    try std.testing.expectEqual(@as(f32, 10.0), FurnaceKind.regular_furnace.cookTimeSeconds());
}

test "2. 2x fuel burn rate and duration halving across fuel sources" {
    // In specialized furnaces, fuel duration in ticks is halved (2x burn rate)
    try std.testing.expectEqual(@as(u32, 2), FUEL_BURN_RATE_MULTIPLIER);

    // Coal: 1600 base -> 800 specialized
    try std.testing.expectEqual(@as(u32, 1600), Item.coal.baseBurnDurationTicks());
    try std.testing.expectEqual(@as(u32, 800), Item.coal.burnDurationTicks(.blast_furnace));
    try std.testing.expectEqual(@as(u32, 800), Item.coal.burnDurationTicks(.smoker));

    // Lava bucket: 20000 base -> 10000 specialized
    try std.testing.expectEqual(@as(u32, 20000), Item.lava_bucket.baseBurnDurationTicks());
    try std.testing.expectEqual(@as(u32, 10000), Item.lava_bucket.burnDurationTicks(.blast_furnace));

    // Blaze rod: 2400 base -> 1200 specialized
    try std.testing.expectEqual(@as(u32, 2400), Item.blaze_rod.baseBurnDurationTicks());
    try std.testing.expectEqual(@as(u32, 1200), Item.blaze_rod.burnDurationTicks(.blast_furnace));

    // Dried kelp block: 4000 base -> 2000 specialized
    try std.testing.expectEqual(@as(u32, 4000), Item.dried_kelp_block.baseBurnDurationTicks());
    try std.testing.expectEqual(@as(u32, 2000), Item.dried_kelp_block.burnDurationTicks(.smoker));

    // Coal block: 16000 base -> 8000 specialized
    try std.testing.expectEqual(@as(u32, 16000), Item.coal_block.baseBurnDurationTicks());
    try std.testing.expectEqual(@as(u32, 8000), Item.coal_block.burnDurationTicks(.blast_furnace));

    // Wood planks: 300 base -> 150 specialized
    try std.testing.expectEqual(@as(u32, 300), Item.wood_planks.baseBurnDurationTicks());
    try std.testing.expectEqual(@as(u32, 150), Item.wood_planks.burnDurationTicks(.smoker));

    // Sticks: 100 base -> 50 specialized
    try std.testing.expectEqual(@as(u32, 100), Item.stick.baseBurnDurationTicks());
    try std.testing.expectEqual(@as(u32, 50), Item.stick.burnDurationTicks(.blast_furnace));
}

test "3. total fuel energy conservation per smelted item" {
    // Each fuel item smelts the EXACT same number of items in specialized vs regular furnaces:
    // (fuel_duration_ticks / cook_time_ticks) is invariant!
    const fuels = [_]Item{ .coal, .lava_bucket, .blaze_rod, .dried_kelp_block, .coal_block };
    for (fuels) |fuel| {
        const regular_yield = fuel.baseBurnDurationTicks() / REGULAR_FURNACE_COOK_TICKS;
        const blast_yield = fuel.burnDurationTicks(.blast_furnace) / SPECIALIZED_FURNACE_COOK_TICKS;
        const smoker_yield = fuel.burnDurationTicks(.smoker) / SPECIALIZED_FURNACE_COOK_TICKS;

        try std.testing.expectEqual(regular_yield, blast_yield);
        try std.testing.expectEqual(regular_yield, smoker_yield);
    }

    // Specifically:
    // Coal smelts 8 items in both
    try std.testing.expectEqual(@as(u32, 8), Item.coal.burnDurationTicks(.blast_furnace) / SPECIALIZED_FURNACE_COOK_TICKS);
    // Lava bucket smelts 100 items in both
    try std.testing.expectEqual(@as(u32, 100), Item.lava_bucket.burnDurationTicks(.blast_furnace) / SPECIALIZED_FURNACE_COOK_TICKS);
    // Blaze rod smelts 12 items in both
    try std.testing.expectEqual(@as(u32, 12), Item.blaze_rod.burnDurationTicks(.blast_furnace) / SPECIALIZED_FURNACE_COOK_TICKS);
    // Dried kelp block smelts 20 items in both
    try std.testing.expectEqual(@as(u32, 20), Item.dried_kelp_block.burnDurationTicks(.smoker) / SPECIALIZED_FURNACE_COOK_TICKS);
}

test "4. blast furnace accepted raw metals (raw iron, raw copper, raw gold) outputs and XP" {
    try std.testing.expect(isBlastFurnaceAccepted(.raw_iron));
    try std.testing.expect(isBlastFurnaceAccepted(.raw_copper));
    try std.testing.expect(isBlastFurnaceAccepted(.raw_gold));

    // Raw iron -> Iron Ingot (0.7 XP, 100 ticks)
    const r_iron = getRecipe(.raw_iron, .blast_furnace).?;
    try std.testing.expectEqual(Item.iron_ingot, r_iron.output);
    try std.testing.expectEqual(@as(u8, 1), r_iron.output_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), r_iron.experience, 0.0001);
    try std.testing.expectEqual(SPECIALIZED_FURNACE_COOK_TICKS, r_iron.cook_ticks);

    // Raw copper -> Copper Ingot (0.7 XP, 100 ticks)
    const r_copper = getRecipe(.raw_copper, .blast_furnace).?;
    try std.testing.expectEqual(Item.copper_ingot, r_copper.output);
    try std.testing.expectEqual(@as(u8, 1), r_copper.output_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), r_copper.experience, 0.0001);
    try std.testing.expectEqual(SPECIALIZED_FURNACE_COOK_TICKS, r_copper.cook_ticks);

    // Raw gold -> Gold Ingot (1.0 XP, 100 ticks)
    const r_gold = getRecipe(.raw_gold, .blast_furnace).?;
    try std.testing.expectEqual(Item.gold_ingot, r_gold.output);
    try std.testing.expectEqual(@as(u8, 1), r_gold.output_count);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), r_gold.experience, 0.0001);
    try std.testing.expectEqual(SPECIALIZED_FURNACE_COOK_TICKS, r_gold.cook_ticks);
}

test "5. blast furnace accepted ores (iron ore, copper ore, gold ore, ancient debris) outputs and XP" {
    try std.testing.expect(isBlastFurnaceAccepted(.iron_ore));
    try std.testing.expect(isBlastFurnaceAccepted(.copper_ore));
    try std.testing.expect(isBlastFurnaceAccepted(.gold_ore));
    try std.testing.expect(isBlastFurnaceAccepted(.ancient_debris));

    // Iron ore -> Iron Ingot (0.7 XP)
    const r_io = getRecipe(.iron_ore, .blast_furnace).?;
    try std.testing.expectEqual(Item.iron_ingot, r_io.output);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), r_io.experience, 0.0001);

    // Copper ore -> Copper Ingot (0.7 XP)
    const r_co = getRecipe(.copper_ore, .blast_furnace).?;
    try std.testing.expectEqual(Item.copper_ingot, r_co.output);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), r_co.experience, 0.0001);

    // Gold ore -> Gold Ingot (1.0 XP)
    const r_go = getRecipe(.gold_ore, .blast_furnace).?;
    try std.testing.expectEqual(Item.gold_ingot, r_go.output);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), r_go.experience, 0.0001);

    // Ancient debris -> Netherite scrap (2.0 XP)
    const r_ad = getRecipe(.ancient_debris, .blast_furnace).?;
    try std.testing.expectEqual(Item.netherite_scrap, r_ad.output);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), r_ad.experience, 0.0001);
}

test "6. blast furnace accepted chainmail armor recyclability into iron nuggets" {
    const chain_pieces = [_]Item{
        .chainmail_helmet,
        .chainmail_chestplate,
        .chainmail_leggings,
        .chainmail_boots,
    };

    for (chain_pieces) |piece| {
        try std.testing.expect(isBlastFurnaceAccepted(piece));
        const r = getRecipe(piece, .blast_furnace).?;
        try std.testing.expectEqual(Item.iron_nugget, r.output);
        try std.testing.expectEqual(@as(u8, 1), r.output_count);
        try std.testing.expectApproxEqAbs(@as(f32, 0.1), r.experience, 0.0001);
        try std.testing.expectEqual(SPECIALIZED_FURNACE_COOK_TICKS, r.cook_ticks);
    }
}

test "7. blast furnace accepted iron tools and armor into iron nuggets" {
    const iron_gear = [_]Item{
        .iron_pickaxe,
        .iron_sword,
        .iron_axe,
        .iron_shovel,
        .iron_hoe,
        .iron_helmet,
        .iron_chestplate,
        .iron_leggings,
        .iron_boots,
        .iron_horse_armor,
    };

    for (iron_gear) |gear| {
        try std.testing.expect(isBlastFurnaceAccepted(gear));
        const r = getRecipe(gear, .blast_furnace).?;
        try std.testing.expectEqual(Item.iron_nugget, r.output);
        try std.testing.expectEqual(@as(u8, 1), r.output_count);
        try std.testing.expectApproxEqAbs(@as(f32, 0.1), r.experience, 0.0001);
    }
}

test "8. blast furnace accepted golden tools and armor into gold nuggets" {
    const golden_gear = [_]Item{
        .golden_sword,
        .golden_pickaxe,
        .golden_axe,
        .golden_shovel,
        .golden_hoe,
        .golden_helmet,
        .golden_chestplate,
        .golden_leggings,
        .golden_boots,
        .golden_horse_armor,
    };

    for (golden_gear) |gear| {
        try std.testing.expect(isBlastFurnaceAccepted(gear));
        const r = getRecipe(gear, .blast_furnace).?;
        try std.testing.expectEqual(Item.gold_nugget, r.output);
        try std.testing.expectEqual(@as(u8, 1), r.output_count);
        try std.testing.expectApproxEqAbs(@as(f32, 0.1), r.experience, 0.0001);
    }
}

test "9. blast furnace strict rejection of foods, wood, stone, sand, clay, and gems" {
    // Foods rejected
    try std.testing.expect(!isBlastFurnaceAccepted(.raw_beef));
    try std.testing.expect(!isBlastFurnaceAccepted(.raw_porkchop));
    try std.testing.expect(!isBlastFurnaceAccepted(.raw_chicken));
    try std.testing.expect(!isBlastFurnaceAccepted(.potato));
    try std.testing.expect(!isBlastFurnaceAccepted(.kelp));
    try std.testing.expect(!isBlastFurnaceAccepted(.apple));
    try std.testing.expect(!isBlastFurnaceAccepted(.bread));

    // Wood & organic rejected
    try std.testing.expect(!isBlastFurnaceAccepted(.wood));
    try std.testing.expect(!isBlastFurnaceAccepted(.wood_planks));
    try std.testing.expect(!isBlastFurnaceAccepted(.stick));

    // Stone & masonry rejected
    try std.testing.expect(!isBlastFurnaceAccepted(.stone));
    try std.testing.expect(!isBlastFurnaceAccepted(.cobblestone));

    // Sand & clay rejected
    try std.testing.expect(!isBlastFurnaceAccepted(.sand));
    try std.testing.expect(!isBlastFurnaceAccepted(.clay_ball));
    try std.testing.expect(!isBlastFurnaceAccepted(.clay));
    try std.testing.expect(!isBlastFurnaceAccepted(.terracotta));

    // Non-metal ores (gems) rejected
    try std.testing.expect(!isBlastFurnaceAccepted(.diamond_ore));
    try std.testing.expect(!isBlastFurnaceAccepted(.emerald_ore));
    try std.testing.expect(!isBlastFurnaceAccepted(.nether_quartz_ore));

    // Null recipes for rejected items
    try std.testing.expect(getRecipe(.raw_beef, .blast_furnace) == null);
    try std.testing.expect(getRecipe(.sand, .blast_furnace) == null);
    try std.testing.expect(getRecipe(.cobblestone, .blast_furnace) == null);
    try std.testing.expect(getRecipe(.diamond_ore, .blast_furnace) == null);
}

test "10. smoker accepted raw meats (beef, porkchop, chicken, mutton, rabbit) outputs and XP" {
    const raw_meats = [_]struct { in: Item, out: Item }{
        .{ .in = .raw_beef, .out = .cooked_beef },
        .{ .in = .raw_porkchop, .out = .cooked_porkchop },
        .{ .in = .raw_chicken, .out = .cooked_chicken },
        .{ .in = .raw_mutton, .out = .cooked_mutton },
        .{ .in = .raw_rabbit, .out = .cooked_rabbit },
    };

    for (raw_meats) |meat| {
        try std.testing.expect(isSmokerAccepted(meat.in));
        const r = getRecipe(meat.in, .smoker).?;
        try std.testing.expectEqual(meat.out, r.output);
        try std.testing.expectEqual(@as(u8, 1), r.output_count);
        try std.testing.expectApproxEqAbs(@as(f32, 0.35), r.experience, 0.0001);
        try std.testing.expectEqual(SPECIALIZED_FURNACE_COOK_TICKS, r.cook_ticks);
    }
}

test "11. smoker accepted seafood and crops (cod, salmon, potato, kelp) outputs and XP" {
    // Raw cod -> cooked cod (0.35 XP)
    try std.testing.expect(isSmokerAccepted(.raw_cod));
    const r_cod = getRecipe(.raw_cod, .smoker).?;
    try std.testing.expectEqual(Item.cooked_cod, r_cod.output);
    try std.testing.expectApproxEqAbs(@as(f32, 0.35), r_cod.experience, 0.0001);

    // Raw salmon -> cooked salmon (0.35 XP)
    try std.testing.expect(isSmokerAccepted(.raw_salmon));
    const r_sal = getRecipe(.raw_salmon, .smoker).?;
    try std.testing.expectEqual(Item.cooked_salmon, r_sal.output);
    try std.testing.expectApproxEqAbs(@as(f32, 0.35), r_sal.experience, 0.0001);

    // Potato -> baked potato (0.35 XP)
    try std.testing.expect(isSmokerAccepted(.potato));
    const r_pot = getRecipe(.potato, .smoker).?;
    try std.testing.expectEqual(Item.baked_potato, r_pot.output);
    try std.testing.expectApproxEqAbs(@as(f32, 0.35), r_pot.experience, 0.0001);

    // Kelp -> dried kelp (0.1 XP)
    try std.testing.expect(isSmokerAccepted(.kelp));
    const r_kelp = getRecipe(.kelp, .smoker).?;
    try std.testing.expectEqual(Item.dried_kelp, r_kelp.output);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), r_kelp.experience, 0.0001);
}

test "12. smoker strict rejection of ores, raw metals, gear, and masonry" {
    // Ores & metals rejected
    try std.testing.expect(!isSmokerAccepted(.iron_ore));
    try std.testing.expect(!isSmokerAccepted(.gold_ore));
    try std.testing.expect(!isSmokerAccepted(.copper_ore));
    try std.testing.expect(!isSmokerAccepted(.ancient_debris));
    try std.testing.expect(!isSmokerAccepted(.raw_iron));
    try std.testing.expect(!isSmokerAccepted(.raw_copper));
    try std.testing.expect(!isSmokerAccepted(.raw_gold));

    // Armor & tools rejected
    try std.testing.expect(!isSmokerAccepted(.iron_sword));
    try std.testing.expect(!isSmokerAccepted(.golden_helmet));
    try std.testing.expect(!isSmokerAccepted(.chainmail_chestplate));

    // Stone & sand rejected
    try std.testing.expect(!isSmokerAccepted(.stone));
    try std.testing.expect(!isSmokerAccepted(.cobblestone));
    try std.testing.expect(!isSmokerAccepted(.sand));
    try std.testing.expect(!isSmokerAccepted(.clay_ball));

    // Null recipes
    try std.testing.expect(getRecipe(.iron_ore, .smoker) == null);
    try std.testing.expect(getRecipe(.raw_iron, .smoker) == null);
    try std.testing.expect(getRecipe(.stone, .smoker) == null);
}

test "13. container inventory 3-slot layout (input, fuel, output) and stack bounds" {
    var inv = FurnaceInventory.init();
    try std.testing.expect(inv.isEmpty());

    // Slot layout indices: Input=0, Fuel=1, Output=2
    try std.testing.expectEqual(@as(usize, 0), FurnaceInventory.INPUT_SLOT);
    try std.testing.expectEqual(@as(usize, 1), FurnaceInventory.FUEL_SLOT);
    try std.testing.expectEqual(@as(usize, 2), FurnaceInventory.OUTPUT_SLOT);
    try std.testing.expectEqual(@as(usize, 3), FurnaceInventory.SLOT_COUNT);

    // Set input slot
    inv.setInput(.raw_iron, 32);
    try std.testing.expectEqual(Item.raw_iron, inv.getInput().item);
    try std.testing.expectEqual(@as(u16, 32), inv.getInput().count);
    try std.testing.expectEqual(@as(u16, 64), inv.getInput().max_stack);

    // Set fuel slot
    inv.setFuel(.coal, 8);
    try std.testing.expectEqual(Item.coal, inv.getFuel().item);
    try std.testing.expectEqual(@as(u16, 8), inv.getFuel().count);

    // Set output slot
    inv.setOutput(.iron_ingot, 16);
    try std.testing.expectEqual(Item.iron_ingot, inv.getOutput().item);
    try std.testing.expectEqual(@as(u16, 16), inv.getOutput().count);

    // Equipment stack bound is 1
    inv.setInput(.iron_sword, 1);
    try std.testing.expectEqual(@as(u16, 1), inv.getInput().max_stack);

    // Bucket stack bound is 16
    inv.setFuel(.bucket, 5);
    try std.testing.expectEqual(@as(u16, 16), inv.getFuel().max_stack);
}

test "14. comparator signal is zero for completely empty container" {
    const inv = FurnaceInventory.init();
    try std.testing.expectEqual(@as(u4, 0), inv.comparatorSignal());
    try std.testing.expectEqual(@as(u4, 0), computeComparatorSignalFromSlots(0, 64, 0, 64, 0, 64));
}

test "15. comparator signal is fifteen for completely full container (stackable & unstackable)" {
    // 3 slots full of 64-stack items
    var inv64 = FurnaceInventory.init();
    inv64.setInput(.raw_iron, 64);
    inv64.setFuel(.coal, 64);
    inv64.setOutput(.iron_ingot, 64);
    try std.testing.expectEqual(@as(u4, 15), inv64.comparatorSignal());

    // 3 slots full of unstackable (stack limit 1) items
    var inv1 = FurnaceInventory.init();
    inv1.setInput(.iron_sword, 1);
    inv1.setFuel(.lava_bucket, 1);
    inv1.setOutput(.iron_helmet, 1);
    try std.testing.expectEqual(@as(u4, 15), inv1.comparatorSignal());

    // Mixed full slots: 1 sword (1/1), 64 coal (64/64), 64 iron ingots (64/64)
    var inv_mix = FurnaceInventory.init();
    inv_mix.setInput(.iron_sword, 1);
    inv_mix.setFuel(.coal, 64);
    inv_mix.setOutput(.iron_ingot, 64);
    try std.testing.expectEqual(@as(u4, 15), inv_mix.comparatorSignal());
}

test "16. comparator signal calculates exact fullness for single and double full slots" {
    // In a 3-slot container:
    // 1 full slot = 1.0 / 3 fullness: floor(1.0 + (1/3)*14) = floor(1.0 + 4.6667) = 5
    var one_slot = FurnaceInventory.init();
    one_slot.setInput(.raw_iron, 64);
    try std.testing.expectEqual(@as(u4, 5), one_slot.comparatorSignal());

    // 1 full unstackable item (1/1) in input also gives 5
    var one_unstackable = FurnaceInventory.init();
    one_unstackable.setInput(.iron_sword, 1);
    try std.testing.expectEqual(@as(u4, 5), one_unstackable.comparatorSignal());

    // 2 full slots = 2.0 / 3 fullness: floor(1.0 + (2/3)*14) = floor(1.0 + 9.3333) = 10
    var two_slots = FurnaceInventory.init();
    two_slots.setInput(.raw_iron, 64);
    two_slots.setFuel(.coal, 64);
    try std.testing.expectEqual(@as(u4, 10), two_slots.comparatorSignal());
}

test "17. comparator signal fractional stepping across all intermediate values 1..14" {
    // 1 item in slot 0 out of 64 gives signal 1
    try std.testing.expectEqual(@as(u4, 1), computeComparatorSignalFromSlots(1, 64, 0, 64, 0, 64));

    // Verify monotonic signal increase as items accumulate
    var prev_signal: u4 = 0;
    var count: u16 = 0;
    while (count <= 64) : (count += 1) {
        const sig = computeComparatorSignalFromSlots(count, 64, 0, 64, 0, 64);
        try std.testing.expect(sig >= prev_signal);
        prev_signal = sig;
    }

    // Verify signals 1 through 15 are all attainable
    var signal_seen = [_]bool{false} ** 16;
    var in_c: u16 = 0;
    while (in_c <= 64) : (in_c += 8) {
        var fl_c: u16 = 0;
        while (fl_c <= 64) : (fl_c += 8) {
            var out_c: u16 = 0;
            while (out_c <= 64) : (out_c += 8) {
                const s = computeComparatorSignalFromSlots(in_c, 64, fl_c, 64, out_c, 64);
                signal_seen[s] = true;
            }
        }
    }

    // Signals 0 through 15 must all be observed
    for (signal_seen, 0..) |seen, s| {
        try std.testing.expect(seen or s == 13); // 13 is hit with finer increments
    }

    // Fine check for 13: 64 in input, 64 in fuel, 45 in output -> average = 2.703 / 3 = 0.901 -> floor(1 + 0.901*14) = 13
    try std.testing.expectEqual(@as(u4, 13), computeComparatorSignalFromSlots(64, 64, 64, 64, 45, 64));
    // Fine check for 14: 64 in input, 64 in fuel, 55 in output
    try std.testing.expectEqual(@as(u4, 14), computeComparatorSignalFromSlots(64, 64, 64, 64, 55, 64));
}

test "18. complete smelting lifecycle: input, fuel burn, progress, item production, and XP banking" {
    var bf = SpecializedFurnace.init(.blast_furnace);
    bf.setInput(.raw_iron, 1);
    bf.setFuel(.coal, 1);

    try std.testing.expect(!bf.isLit());
    try std.testing.expectEqual(@as(u32, 0), bf.cook_ticks);
    try std.testing.expectEqual(@as(f32, 0.0), bf.stored_xp);

    // Tick 1: fuel ignited (coal = 800 ticks for blast furnace), cook timer progresses
    const out1 = bf.tick();
    try std.testing.expect(bf.isLit());
    try std.testing.expect(out1.fuel_consumed);
    try std.testing.expectEqual(Item.coal, out1.fuel_item);
    try std.testing.expectEqual(@as(u32, 799), bf.burn_ticks_remaining);
    try std.testing.expectEqual(@as(u32, 1), bf.cook_ticks);
    try std.testing.expect(!out1.item_smelted);

    // Tick remaining 98 ticks (total 99 ticks elapsed)
    bf.tickTicks(98);
    try std.testing.expectEqual(@as(u32, 99), bf.cook_ticks);
    try std.testing.expect(bf.inventory.getOutput().isEmpty());

    // 100th tick: completes smelting!
    const out100 = bf.tick();
    try std.testing.expect(out100.item_smelted);
    try std.testing.expectEqual(Item.iron_ingot, out100.smelted_item);
    try std.testing.expectEqual(@as(u8, 1), out100.smelted_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), out100.xp_banked, 0.0001);

    // Input consumed, output now has 1 iron ingot, cook timer reset to 0
    try std.testing.expect(bf.inventory.getInput().isEmpty());
    try std.testing.expectEqual(Item.iron_ingot, bf.inventory.getOutput().item);
    try std.testing.expectEqual(@as(u16, 1), bf.inventory.getOutput().count);
    try std.testing.expectEqual(@as(u32, 0), bf.cook_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), bf.stored_xp, 0.0001);

    // Fuel is still burning (700 ticks remaining of the 800)
    try std.testing.expect(bf.isLit());
    try std.testing.expectEqual(@as(u32, 700), bf.burn_ticks_remaining);
}

test "19. smelting lifecycle: fuel exhaustion stops cooking and progress decays" {
    var smoker = SpecializedFurnace.init(.smoker);
    smoker.setInput(.raw_beef, 2);

    // Planks: 300 base ticks -> 150 specialized ticks (burns 150 ticks)
    // 1 item cooks in 100 ticks, leaving 50 ticks of fuel for item 2
    smoker.setFuel(.wood_planks, 1);

    // Tick 100 ticks: item 1 finishes, 50 ticks of fuel remaining
    smoker.tickTicks(100);
    try std.testing.expectEqual(Item.cooked_beef, smoker.inventory.getOutput().item);
    try std.testing.expectEqual(@as(u16, 1), smoker.inventory.getOutput().count);
    try std.testing.expectEqual(@as(u16, 1), smoker.inventory.getInput().count);
    try std.testing.expectEqual(@as(u32, 50), smoker.burn_ticks_remaining);

    // Next 50 ticks: item 2 cooks to 50% (50 ticks) while fuel expires
    smoker.tickTicks(50);
    try std.testing.expectEqual(@as(u32, 0), smoker.burn_ticks_remaining);
    try std.testing.expect(!smoker.isLit());
    try std.testing.expectEqual(@as(u32, 50), smoker.cook_ticks);

    // Now out of fuel: subsequent ticks without fuel cause cook progress to decay
    smoker.tickTicks(10);
    try std.testing.expect(smoker.cook_ticks < 50); // decayed
}

test "20. smelting lifecycle: blocked output slot halts progress without consuming fuel" {
    var bf = SpecializedFurnace.init(.blast_furnace);
    bf.setInput(.raw_iron, 5);
    bf.setFuel(.coal, 2);
    // Output slot already contains 64 iron ingots (full stack!)
    bf.setOutput(.iron_ingot, 64);

    try std.testing.expect(!bf.canSmeltCurrentInput());

    // Ticking must NOT ignite fuel or cook
    _ = bf.tick();
    try std.testing.expect(!bf.isLit());
    try std.testing.expectEqual(@as(u32, 0), bf.cook_ticks);
    try std.testing.expectEqual(@as(u16, 2), bf.inventory.getFuel().count);

    // Output slot contains incompatible item (gold ingot instead of iron ingot)
    bf.setOutput(.gold_ingot, 1);
    try std.testing.expect(!bf.canSmeltCurrentInput());
    _ = bf.tick();
    try std.testing.expect(!bf.isLit());
    try std.testing.expectEqual(@as(u32, 0), bf.cook_ticks);
}

test "21. smelting lifecycle: player extraction collects banked XP whereas hopper retains it" {
    var bf = SpecializedFurnace.init(.blast_furnace);
    bf.setInput(.ancient_debris, 2);
    bf.setFuel(.coal, 1);

    // Smelt both ancient debris (2 items * 100 ticks = 200 ticks)
    bf.tickTicks(200);

    // Output has 2 netherite scrap, stored XP is 2 * 2.0 = 4.0 XP
    try std.testing.expectEqual(@as(u16, 2), bf.inventory.getOutput().count);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), bf.stored_xp, 0.0001);

    // Hopper extraction (player_collected = false): 0 XP returned, bank untouched
    const hopper_xp = bf.collectXp(false);
    try std.testing.expectEqual(@as(f32, 0.0), hopper_xp);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), bf.stored_xp, 0.0001);

    // Player extraction (player_collected = true): returns full 4.0 XP, clears bank
    const player_xp = bf.collectXp(true);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), player_xp, 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bf.stored_xp);
}

test "22. lava bucket fuel leaves empty bucket container and burns for 10000 ticks" {
    var bf = SpecializedFurnace.init(.blast_furnace);
    bf.setInput(.raw_copper, 10);
    bf.setFuel(.lava_bucket, 1);

    // Igniting consumes lava bucket and places an empty bucket in fuel slot
    const out = bf.tick();
    try std.testing.expect(out.fuel_consumed);
    try std.testing.expectEqual(Item.lava_bucket, out.fuel_item);

    // Lava bucket burns for 10000 ticks in specialized furnace (20000 / 2)
    try std.testing.expectEqual(@as(u32, 10000), bf.burn_duration_ticks);
    try std.testing.expectEqual(@as(u32, 9999), bf.burn_ticks_remaining);

    // Fuel slot now contains empty bucket
    try std.testing.expectEqual(Item.bucket, bf.inventory.getFuel().item);
    try std.testing.expectEqual(@as(u16, 1), bf.inventory.getFuel().count);
    try std.testing.expectEqual(@as(u16, 16), bf.inventory.getFuel().max_stack);
}
