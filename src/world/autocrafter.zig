const std = @import("std");

// =========================================================================
// SINGLE-INPUT AUTOCRAFT & VAULT LOOT CONSTANTS / RULES
// =========================================================================

pub const WoodLogTag: u16 = 5;
pub const WoodPlanksTag: u16 = 7;
pub const StickTag: u16 = 8;
pub const CraftingBenchTag: u16 = 10;
pub const CoalTag: u16 = 12;
pub const IronOreTag: u16 = 13;
pub const IronIngotTag: u16 = 26;
pub const TorchTag: u16 = 34;
pub const RedstoneDustTag: u16 = 38;
pub const ArrowTag: u16 = 97;
pub const GoldBlockTag: u16 = 216;
pub const DiamondTag: u16 = 217;
pub const FlintTag: u16 = 226;
pub const EmeraldTag: u16 = 273;
pub const CopperIngotTag: u16 = 284;
pub const CopperBlockTag: u16 = 286;
pub const IronBlockTag: u16 = 313;
pub const BreezeRodTag: u16 = 371;
pub const WindChargeTag: u16 = 372;
pub const HeavyCoreTag: u16 = 373;
pub const EnchantedGoldenAppleTag: u16 = 379;
pub const WoodenSlabTag: u16 = 563;
pub const GoldIngotTag: u16 = 606;

pub const AutoCraftResult = struct {
    output_tag: u16,
    output_count: u8,
};

/// Map a single input item tag to an instant autocraft output when supported.
pub fn autoCraftSingleInput(input_tag: u16) ?AutoCraftResult {
    return switch (input_tag) {
        WoodLogTag => .{ .output_tag = WoodPlanksTag, .output_count = 4 },
        WoodPlanksTag => .{ .output_tag = StickTag, .output_count = 2 },
        BreezeRodTag => .{ .output_tag = WindChargeTag, .output_count = 4 },
        else => null,
    };
}

/// Deterministic standard Trial Vault loot roll table.
pub fn vaultLootForRoll(roll: u8) AutoCraftResult {
    return switch (roll % 5) {
        0 => .{ .output_tag = HeavyCoreTag, .output_count = 1 },
        1 => .{ .output_tag = BreezeRodTag, .output_count = 3 },
        2 => .{ .output_tag = DiamondTag, .output_count = 2 },
        3 => .{ .output_tag = EmeraldTag, .output_count = 4 },
        else => .{ .output_tag = EnchantedGoldenAppleTag, .output_count = 1 },
    };
}

// =========================================================================
// UNIFIED CRAFTER GRID, PULSED 3x3 CRAFTING, AND FACTORY CLOCKING CONSTANTS
// =========================================================================

pub const slot_count: usize = 9;
pub const cooldown_game_ticks: u8 = 8;
pub const craft_delay_ticks: u64 = 4;
pub const craft_delay_game_ticks: u8 = 4;
pub const default_max_stack: u8 = 64;
pub const default_slot_capacity: u8 = 64;
pub const hopper_transfer_game_ticks: u8 = 8;
pub const blast_furnace_smelt_game_ticks: u16 = 100;
pub const game_ticks_per_minute: f32 = 1200.0;
pub const nozzle_speed: f32 = 0.4;

pub const Item = enum {
    iron_ore,
    iron_ingot,
    iron_block,
    gold_ingot,
    gold_block,
    copper_ingot,
    copper_block,
    redstone,
    stick,
    torch,
    wood_planks,
    crafting_table,
    coal,
    flint,
    feather,
    arrow,
    wooden_slab,
    other,
};

pub const ItemType = Item;

pub const Stack = struct {
    item: Item,
    count: u8,
};

pub const ItemStack = Stack;

pub const Direction = enum {
    north,
    south,
    east,
    west,
    up,
    down,
};

pub const CraftResult = enum {
    none,
    crafted,
    cooldown,
    missing_ingredients,
};

pub const GridCraftResult = enum {
    none,
    cooldown,
    failed,
    crafted,
};

pub const ClockMode = enum(u8) {
    one_redstone_tick = 2,
    four_redstone_ticks = 8,

    pub fn periodGameTicks(self: ClockMode) u8 {
        return @intFromEnum(self);
    }
};

pub const NozzleOutput = struct {
    item: Item,
    count: u8,
    direction: Direction,
};

pub const EjectedItem = struct {
    stack: ItemStack,
    velocity: [3]f32,
    particles_emitted: bool,
};

/// Convert an inventory item tag into the corresponding crafter grid item, if supported.
pub fn gridItemFromTag(tag: u16) ?Item {
    return switch (tag) {
        IronOreTag => .iron_ore,
        IronIngotTag => .iron_ingot,
        IronBlockTag => .iron_block,
        GoldIngotTag => .gold_ingot,
        GoldBlockTag => .gold_block,
        CopperIngotTag => .copper_ingot,
        CopperBlockTag => .copper_block,
        RedstoneDustTag => .redstone,
        StickTag => .stick,
        TorchTag => .torch,
        WoodPlanksTag => .wood_planks,
        CraftingBenchTag => .crafting_table,
        CoalTag => .coal,
        FlintTag => .flint,
        ArrowTag => .arrow,
        WoodenSlabTag => .wooden_slab,
        else => null,
    };
}

/// Convert a crafter grid item back into its inventory item tag, if mapped.
pub fn tagFromGridItem(item: Item) ?u16 {
    return switch (item) {
        .iron_ore => IronOreTag,
        .iron_ingot => IronIngotTag,
        .iron_block => IronBlockTag,
        .gold_ingot => GoldIngotTag,
        .gold_block => GoldBlockTag,
        .copper_ingot => CopperIngotTag,
        .copper_block => CopperBlockTag,
        .redstone => RedstoneDustTag,
        .stick => StickTag,
        .torch => TorchTag,
        .wood_planks => WoodPlanksTag,
        .crafting_table => CraftingBenchTag,
        .coal => CoalTag,
        .flint => FlintTag,
        .arrow => ArrowTag,
        .wooden_slab => WoodenSlabTag,
        .feather, .other => null,
    };
}

/// Normalized unit vector pointing out of a Crafter nozzle face.
pub fn directionVector(dir: Direction) [3]f32 {
    return switch (dir) {
        .north => .{ 0.0, 0.0, -1.0 },
        .south => .{ 0.0, 0.0, 1.0 },
        .east => .{ 1.0, 0.0, 0.0 },
        .west => .{ -1.0, 0.0, 0.0 },
        .up => .{ 0.0, 1.0, 0.0 },
        .down => .{ 0.0, -1.0, 0.0 },
    };
}

/// Initial ejection velocity vector along the Crafter nozzle direction.
pub fn velocityFor(direction: Direction) [3]f32 {
    return switch (direction) {
        .north => .{ 0, 0, -nozzle_speed },
        .south => .{ 0, 0, nozzle_speed },
        .east => .{ nozzle_speed, 0, 0 },
        .west => .{ -nozzle_speed, 0, 0 },
        .up => .{ 0, nozzle_speed, 0 },
        .down => .{ 0, -nozzle_speed, 0 },
    };
}

// =========================================================================
// PULSED 3x3 CRAFTER & ROUND-ROBIN HOPPER RULES (from crafter_pulsed_grid)
// =========================================================================

pub const Recipe = struct {
    pattern: [slot_count]?Item,
    output: Stack,

    pub fn matches(self: Recipe, slots: [slot_count]?Stack, disabled_mask: u9) bool {
        for (0..slot_count) |i| {
            const bit: u9 = @as(u9, 1) << @intCast(i);
            const is_disabled = (disabled_mask & bit) != 0;
            if (is_disabled) {
                if (self.pattern[i] != null) return false;
            } else {
                const expected = self.pattern[i];
                if (expected) |item| {
                    const slot = slots[i] orelse return false;
                    if (slot.item != item or slot.count == 0) return false;
                } else {
                    if (slots[i] != null) return false;
                }
            }
        }
        return true;
    }
};

/// Standalone 3x3 crafter rules. The caller applies the nozzle output to the world.
pub const Crafter = struct {
    slots: [slot_count]?Stack = [_]?Stack{null} ** slot_count,
    disabled_mask: u9 = 0,
    previous_powered: bool = false,
    game_tick: u64 = 0,
    last_craft_tick: ?u64 = null,
    front_nozzle: Direction = .north,
    output: ?NozzleOutput = null,
    craft_count: u32 = 0,
    recipe: ?Recipe = null,

    pub fn setDisabled(self: *Crafter, index: usize, disabled: bool) bool {
        if (index >= slot_count) return false;
        const bit: u9 = @as(u9, 1) << @intCast(index);
        if (disabled) {
            self.disabled_mask |= bit;
            self.slots[index] = null;
        } else {
            self.disabled_mask &= ~bit;
        }
        return true;
    }

    pub fn toggleSlot(self: *Crafter, index: usize) bool {
        if (index >= slot_count) return false;
        const currently_disabled = self.isDisabled(index);
        return self.setDisabled(index, !currently_disabled);
    }

    pub fn isDisabled(self: *const Crafter, index: usize) bool {
        return index >= slot_count or (self.disabled_mask & (@as(u9, 1) << @intCast(index))) != 0;
    }

    pub fn disabledCount(self: *const Crafter) usize {
        return @as(usize, @popCount(self.disabled_mask));
    }

    pub fn enabledCount(self: *const Crafter) usize {
        return slot_count - self.disabledCount();
    }

    pub fn insert(self: *Crafter, index: usize, item: Item, count: u8, capacity: u8) u8 {
        if (index >= slot_count or self.isDisabled(index) or count == 0 or capacity == 0) return count;
        const current = self.slots[index];
        if (current) |stack| {
            if (stack.item != item or stack.count >= capacity) return count;
            const accepted = @min(count, capacity - stack.count);
            self.slots[index].?.count += accepted;
            return count - accepted;
        }
        const accepted = @min(count, capacity);
        self.slots[index] = .{ .item = item, .count = accepted };
        return count - accepted;
    }

    /// A rising edge evaluates all active slots against recipes, consuming one item each.
    pub fn tick(self: *Crafter, powered: bool) CraftResult {
        self.game_tick += 1;
        self.output = null;
        const rising_edge = powered and !self.previous_powered;
        self.previous_powered = powered;
        if (!rising_edge) return .none;
        if (self.last_craft_tick) |last| {
            if (self.game_tick - last < craft_delay_ticks) return .cooldown;
        }

        if (self.recipe) |rec| {
            if (!rec.matches(self.slots, self.disabled_mask)) {
                return .missing_ingredients;
            }
            for (0..slot_count) |i| {
                if (rec.pattern[i] != null) {
                    self.slots[i].?.count -= 1;
                    if (self.slots[i].?.count == 0) self.slots[i] = null;
                }
            }
            self.last_craft_tick = self.game_tick;
            self.craft_count += 1;
            self.output = .{
                .item = rec.output.item,
                .count = rec.output.count,
                .direction = self.front_nozzle,
            };
            return .crafted;
        } else {
            var enabled: usize = 0;
            for (self.slots, 0..) |stack, index| {
                if (self.isDisabled(index)) continue;
                enabled += 1;
                if (stack == null or stack.?.item != .iron_ingot or stack.?.count == 0) return .missing_ingredients;
            }
            if (enabled == 0) return .missing_ingredients;

            for (&self.slots, 0..) |*stack, index| {
                if (self.isDisabled(index)) continue;
                stack.*.?.count -= 1;
                if (stack.*.?.count == 0) stack.* = null;
            }
            self.last_craft_tick = self.game_tick;
            self.craft_count += 1;
            self.output = .{
                .item = .iron_block,
                .count = 1,
                .direction = self.front_nozzle,
            };
            return .crafted;
        }
    }

    /// Signal is the number of disabled plus occupied slots, clamped to 0..9.
    pub fn comparatorSignal(self: *const Crafter) u4 {
        const total = self.disabledCount() + self.occupiedCount();
        return @intCast(@min(slot_count, total));
    }

    pub fn occupiedCount(self: *const Crafter) usize {
        var count: usize = 0;
        for (self.slots) |slot| {
            if (slot != null) count += 1;
        }
        return count;
    }
};

pub const HopperResult = struct {
    accepted: u8,
    remaining: u8,
    slot: ?u4,
};

/// Advances one slot per accepted transfer; disabled or full slots are skipped.
pub const HopperRoundRobin = struct {
    next_slot: u4 = 0,
    capacity: u8 = default_slot_capacity,
    backpressured: bool = false,

    pub fn insert(self: *HopperRoundRobin, crafter: *Crafter, item: Item, count: u8) HopperResult {
        if (count == 0 or self.capacity == 0) {
            self.refreshBackpressure(crafter);
            return .{ .accepted = 0, .remaining = count, .slot = null };
        }
        var checked: usize = 0;
        var index: usize = self.next_slot;
        while (checked < slot_count) : (checked += 1) {
            const current = crafter.slots[index];
            if (!crafter.isDisabled(index) and (current == null or (current.?.item == item and current.?.count < self.capacity))) break;
            index = (index + 1) % slot_count;
        }
        if (checked == slot_count) {
            self.refreshBackpressure(crafter);
            return .{ .accepted = 0, .remaining = count, .slot = null };
        }
        const remaining = crafter.insert(index, item, count, self.capacity);
        const accepted = count - remaining;
        if (accepted > 0) self.next_slot = @intCast((index + 1) % slot_count);
        self.refreshBackpressure(crafter);
        return .{ .accepted = accepted, .remaining = remaining, .slot = @intCast(index) };
    }

    pub fn refreshBackpressure(self: *HopperRoundRobin, crafter: *const Crafter) void {
        var has_capacity = false;
        for (crafter.slots, 0..) |slot, index| {
            if (crafter.isDisabled(index)) continue;
            if (slot == null or slot.?.count < self.capacity) {
                has_capacity = true;
                break;
            }
        }
        self.backpressured = !has_capacity;
    }
};

// =========================================================================
// AUTOMATION GRID & SHAPED OFFSET RECIPES (from crafter_automation)
// =========================================================================

const GridRecipe = struct {
    width: u8,
    height: u8,
    pattern: [slot_count]?ItemType,
    output: ItemStack,
};

const grid_recipes = [_]GridRecipe{
    .{ .width = 3, .height = 3, .pattern = .{.iron_ingot} ** 9, .output = .{ .item = .iron_block, .count = 1 } },
    .{ .width = 2, .height = 2, .pattern = .{ .wood_planks, .wood_planks, .wood_planks, .wood_planks, null, null, null, null, null }, .output = .{ .item = .crafting_table, .count = 1 } },
    .{ .width = 1, .height = 2, .pattern = .{ .coal, .stick, null, null, null, null, null, null, null }, .output = .{ .item = .torch, .count = 4 } },
    .{ .width = 1, .height = 3, .pattern = .{ .flint, .stick, .feather, null, null, null, null, null, null }, .output = .{ .item = .arrow, .count = 4 } },
    .{ .width = 3, .height = 1, .pattern = .{ .wood_planks, .wood_planks, .wood_planks, null, null, null, null, null, null }, .output = .{ .item = .wooden_slab, .count = 6 } },
};

pub const CrafterGrid = struct {
    slots: [slot_count]Slot = [_]Slot{.{}} ** slot_count,
    disabled_slots_mask: u9 = 0,
    occupied_slots_mask: u9 = 0,
    is_crafting: bool = false,
    indicator_lamp_on: bool = false,
    is_powered: bool = false,
    cooldown_ticks_remaining: u8 = 0,
    ejected: ?EjectedItem = null,
    mechanical_failure_clicks: u32 = 0,

    pub const Slot = struct {
        is_disabled: bool = false,
        stack: ?ItemStack = null,
    };

    pub fn toggleSlot(self: *CrafterGrid, index: usize) bool {
        if (index >= slot_count) return false;
        self.slots[index].is_disabled = !self.slots[index].is_disabled;
        if (self.slots[index].is_disabled) {
            self.disabled_slots_mask |= @as(u9, 1) << @intCast(index);
            self.slots[index].stack = null;
        } else {
            self.disabled_slots_mask &= ~(@as(u9, 1) << @intCast(index));
        }
        self.refreshOccupiedMask();
        return true;
    }

    pub fn setDisabled(self: *CrafterGrid, index: usize, disabled: bool) bool {
        if (index >= slot_count) return false;
        if (self.slots[index].is_disabled != disabled) return self.toggleSlot(index);
        return true;
    }

    pub fn insertFromHopper(self: *CrafterGrid, item: ItemType, count: u8, max_stack: u8) u8 {
        if (count == 0 or max_stack == 0) return count;
        var remaining = count;
        for (&self.slots, 0..) |*slot, index| {
            if (slot.is_disabled or self.slots[index].stack == null) continue;
            const existing = &slot.stack.?;
            if (existing.item != item or existing.count >= max_stack) continue;
            const moved = @min(remaining, max_stack - existing.count);
            existing.count += moved;
            remaining -= moved;
            if (remaining == 0) break;
        }
        if (remaining > 0) {
            for (&self.slots, 0..) |*slot, index| {
                if (slot.is_disabled or slot.stack != null) continue;
                const moved = @min(remaining, max_stack);
                slot.stack = .{ .item = item, .count = moved };
                remaining -= moved;
                if (remaining == 0) break;
                _ = index;
            }
        }
        self.refreshOccupiedMask();
        return remaining;
    }

    /// Advance one game tick and process only unpowered-to-powered transitions.
    pub fn tick(self: *CrafterGrid, powered: bool, front: Direction) GridCraftResult {
        self.is_crafting = false;
        self.indicator_lamp_on = false;
        self.ejected = null;
        const rising_edge = powered and !self.is_powered;
        self.is_powered = powered;
        if (!rising_edge) {
            if (self.cooldown_ticks_remaining > 0) self.cooldown_ticks_remaining -= 1;
            return .none;
        }
        if (self.cooldown_ticks_remaining > 0) {
            self.cooldown_ticks_remaining -= 1;
            return .cooldown;
        }

        const recipe = self.findRecipe() orelse {
            self.mechanical_failure_clicks += 1;
            self.cooldown_ticks_remaining = cooldown_game_ticks;
            return .failed;
        };
        for (0..slot_count) |i| {
            if (recipe.consumed[i]) {
                const stack = &self.slots[i].stack.?;
                stack.count -= 1;
                if (stack.count == 0) self.slots[i].stack = null;
            }
        }
        self.refreshOccupiedMask();
        self.is_crafting = true;
        self.indicator_lamp_on = true;
        self.ejected = .{ .stack = recipe.output, .velocity = velocityFor(front), .particles_emitted = true };
        self.cooldown_ticks_remaining = cooldown_game_ticks;
        return .crafted;
    }

    pub fn comparatorSignal(self: *const CrafterGrid) u4 {
        const signal: u8 = @intCast(@popCount(self.disabled_slots_mask) + @popCount(self.occupied_slots_mask));
        return @intCast(@min(signal, 9));
    }

    fn refreshOccupiedMask(self: *CrafterGrid) void {
        self.occupied_slots_mask = 0;
        for (self.slots, 0..) |slot, index| {
            if (slot.stack != null) self.occupied_slots_mask |= @as(u9, 1) << @intCast(index);
        }
    }

    const Match = struct { consumed: [slot_count]bool, output: ItemStack };

    fn findRecipe(self: *const CrafterGrid) ?Match {
        for (grid_recipes) |recipe| {
            var y: usize = 0;
            while (y + recipe.height <= 3) : (y += 1) {
                var x: usize = 0;
                while (x + recipe.width <= 3) : (x += 1) {
                    if (self.matchesAt(recipe, x, y)) {
                        var consumed = [_]bool{false} ** slot_count;
                        for (0..slot_count) |i| {
                            if (recipe.pattern[i] != null) {
                                const rx = i % recipe.width;
                                const ry = i / recipe.width;
                                consumed[(y + ry) * 3 + x + rx] = true;
                            }
                        }
                        return .{ .consumed = consumed, .output = recipe.output };
                    }
                }
            }
        }
        return null;
    }

    fn matchesAt(self: *const CrafterGrid, recipe: GridRecipe, x: usize, y: usize) bool {
        for (0..slot_count) |index| {
            const gx = index % 3;
            const gy = index / 3;
            const inside = gx >= x and gx < x + recipe.width and gy >= y and gy < y + recipe.height;
            const expected: ?ItemType = if (inside) recipe.pattern[(gy - y) * recipe.width + (gx - x)] else null;
            const actual = if (self.slots[index].is_disabled) null else if (self.slots[index].stack) |stack| stack.item else null;
            if (actual != expected) return false;
        }
        return true;
    }
};

// =========================================================================
// FACTORY CLOCKING & SMELTING PIPELINE (from crafter_factory_clocking)
// =========================================================================

/// Nine-slot iron-block crafter driven by sampled redstone clock levels.
pub const ClockedCrafter = struct {
    slots: [slot_count]?Stack = [_]?Stack{null} ** slot_count,
    disabled_mask: u9 = 0,
    previous_powered: bool = false,
    game_tick: u64 = 0,
    last_craft_tick: ?u64 = null,
    output_blocks: u32 = 0,
    craft_count: u32 = 0,

    pub fn setDisabled(self: *ClockedCrafter, index: usize, disabled: bool) bool {
        if (index >= slot_count) return false;
        const bit: u9 = @as(u9, 1) << @intCast(index);
        if (disabled) {
            self.disabled_mask |= bit;
            self.slots[index] = null;
        } else {
            self.disabled_mask &= ~bit;
        }
        return true;
    }

    pub fn isDisabled(self: *const ClockedCrafter, index: usize) bool {
        return index >= slot_count or (self.disabled_mask & (@as(u9, 1) << @intCast(index))) != 0;
    }

    pub fn enabledCount(self: *const ClockedCrafter) u8 {
        return @intCast(slot_count - @popCount(self.disabled_mask));
    }

    /// Attempts one recipe on a redstone rising edge; crafting consumes one ingot per slot.
    pub fn tick(self: *ClockedCrafter, powered: bool) CraftResult {
        self.game_tick += 1;
        const rising_edge = powered and !self.previous_powered;
        self.previous_powered = powered;
        if (!rising_edge) return .none;
        if (self.last_craft_tick) |last| {
            if (self.game_tick - last < craft_delay_game_ticks) return .cooldown;
        }
        for (self.slots, 0..) |stack, i| {
            if (self.isDisabled(i)) continue;
            const ingot_count: u8 = if (stack) |s| if (s.item == .iron_ingot) s.count else 0 else 0;
            if (ingot_count == 0) return .missing_ingredients;
        }
        if (self.enabledCount() != slot_count) return .missing_ingredients;
        for (&self.slots) |*stack| {
            const value = &stack.*.?;
            value.count -= 1;
            if (value.count == 0) stack.* = null;
        }
        self.last_craft_tick = self.game_tick;
        self.craft_count += 1;
        self.output_blocks += 1;
        return .crafted;
    }

    /// Comparator fullness follows container fullness scaled to redstone strength 0..15.
    pub fn comparatorSignal(self: *const ClockedCrafter, max_stack: u8) u4 {
        if (max_stack == 0) return 0;
        var occupied: u32 = 0;
        var enabled: u32 = 0;
        for (self.slots, 0..) |stack, i| {
            if (self.isDisabled(i)) continue;
            enabled += 1;
            if (stack) |s| occupied += @min(s.count, max_stack);
        }
        if (occupied == 0 or enabled == 0) return 0;
        const denominator = enabled * max_stack;
        return @intCast(@min(15, 1 + @divTrunc(occupied * 14, denominator)));
    }
};

/// One-tick-wide pulse train. The first high sample occurs after one full period.
pub const FactoryClock = struct {
    mode: ClockMode,
    elapsed_game_ticks: u64 = 0,

    pub fn tick(self: *FactoryClock) bool {
        self.elapsed_game_ticks += 1;
        return self.elapsed_game_ticks % self.mode.periodGameTicks() == 0;
    }
};

pub const HopperInsert = struct { accepted: u8, remaining: u8, slot: ?u4 };

/// Hopper feed cursor distributes successive stacks round-robin over enabled slots.
pub const HopperFeed = struct {
    next_slot: u4 = 0,
    max_stack: u8 = default_max_stack,
    is_backpressured: bool = false,

    pub fn insert(self: *HopperFeed, crafter: *ClockedCrafter, item: Item, count: u8) HopperInsert {
        if (count == 0 or self.max_stack == 0) {
            self.refreshBackpressure(crafter);
            return .{ .accepted = 0, .remaining = count, .slot = null };
        }
        self.refreshBackpressure(crafter);
        if (self.is_backpressured) return .{ .accepted = 0, .remaining = count, .slot = null };
        var index: usize = self.next_slot;
        var checked: usize = 0;
        while (checked < slot_count) : (checked += 1) {
            if (!crafter.isDisabled(index)) {
                const existing = crafter.slots[index];
                if (existing == null or (existing.?.item == item and existing.?.count < self.max_stack)) break;
            }
            index = (index + 1) % slot_count;
        }
        if (checked == slot_count) {
            self.refreshBackpressure(crafter);
            return .{ .accepted = 0, .remaining = count, .slot = null };
        }
        const current = crafter.slots[index];
        const capacity: u8 = if (current) |stack| self.max_stack - stack.count else self.max_stack;
        const accepted = @min(count, capacity);
        if (accepted > 0) {
            crafter.slots[index] = .{ .item = item, .count = if (current) |stack| stack.count + accepted else accepted };
            self.next_slot = @intCast((index + 1) % slot_count);
        }
        self.refreshBackpressure(crafter);
        return .{ .accepted = accepted, .remaining = count - accepted, .slot = @intCast(index) };
    }

    pub fn refreshBackpressure(self: *HopperFeed, crafter: *const ClockedCrafter) void {
        var found_capacity = false;
        for (crafter.slots, 0..) |stack, i| {
            if (crafter.isDisabled(i)) continue;
            if (stack == null or stack.?.count < self.max_stack) {
                found_capacity = true;
                break;
            }
        }
        self.is_backpressured = !found_capacity;
    }
};

pub const PipelineReport = struct {
    game_ticks: u64,
    ore_smelted: u32,
    ingots_crafted: u32,
    blocks_output: u32,
    items_per_minute: f32,
    redstone_edges: u32,
    crafts_per_edge: f32,
};

/// Simulates ore smelting, hopper-fed nine-ingot crafting, and chest collection.
pub const FactoryPipeline = struct {
    clock: FactoryClock,
    crafter: ClockedCrafter = .{},
    hopper: HopperFeed = .{},
    ore_remaining: u32,
    ore_smelted: u32 = 0,
    ingots_crafted: u32 = 0,
    redstone_edges: u32 = 0,
    smelt_progress: u16 = 0,
    hopper_wait: u8 = 0,
    furnace_output_ingots: u32 = 0,
    game_ticks: u64 = 0,

    pub fn init(mode: ClockMode, ore_count: u32) FactoryPipeline {
        return .{ .clock = .{ .mode = mode }, .ore_remaining = ore_count };
    }

    pub fn tick(self: *FactoryPipeline) void {
        self.game_ticks += 1;
        if (self.ore_remaining > 0) {
            self.smelt_progress += 1;
            if (self.smelt_progress >= blast_furnace_smelt_game_ticks) {
                self.smelt_progress = 0;
                self.ore_remaining -= 1;
                self.ore_smelted += 1;
                self.furnace_output_ingots += 1;
            }
        }
        if (self.hopper_wait > 0) self.hopper_wait -= 1;
        if (self.furnace_output_ingots > 0 and self.hopper_wait == 0) {
            const inserted = self.hopper.insert(&self.crafter, .iron_ingot, 1);
            if (inserted.accepted == 1) {
                self.furnace_output_ingots -= 1;
                self.hopper_wait = hopper_transfer_game_ticks;
            }
        }
        const powered = self.clock.tick();
        if (powered) self.redstone_edges += 1;
        if (self.crafter.tick(powered) == .crafted) self.ingots_crafted += @intCast(slot_count);
    }

    pub fn run(self: *FactoryPipeline, game_ticks: u64) PipelineReport {
        for (0..game_ticks) |_| self.tick();
        const rate = if (game_ticks == 0) 0 else @as(f32, @floatFromInt(self.crafter.output_blocks)) * game_ticks_per_minute / @as(f32, @floatFromInt(game_ticks));
        return .{
            .game_ticks = self.game_ticks,
            .ore_smelted = self.ore_smelted,
            .ingots_crafted = self.ingots_crafted,
            .blocks_output = self.crafter.output_blocks,
            .items_per_minute = rate,
            .redstone_edges = self.redstone_edges,
            .crafts_per_edge = if (self.redstone_edges == 0) 0 else @as(f32, @floatFromInt(self.crafter.craft_count)) / @as(f32, @floatFromInt(self.redstone_edges)),
        };
    }
};

fn put(grid: *CrafterGrid, index: usize, item: ItemType, count: u8) void {
    grid.slots[index].stack = .{ .item = item, .count = count };
    grid.refreshOccupiedMask();
}

fn fillCrafter(crafter: *ClockedCrafter, count: u8) void {
    for (&crafter.slots) |*slot| slot.* = .{ .item = .iron_ingot, .count = count };
}

// =========================================================================
// UNIT TESTS
// =========================================================================

// --- Original autocrafter tests ---

test "tag constants" {
    try std.testing.expectEqual(@as(u16, 5), WoodLogTag);
    try std.testing.expectEqual(@as(u16, 7), WoodPlanksTag);
    try std.testing.expectEqual(@as(u16, 8), StickTag);
    try std.testing.expectEqual(@as(u16, 371), BreezeRodTag);
    try std.testing.expectEqual(@as(u16, 372), WindChargeTag);
    try std.testing.expectEqual(@as(u16, 373), HeavyCoreTag);
    try std.testing.expectEqual(@as(u16, 217), DiamondTag);
    try std.testing.expectEqual(@as(u16, 273), EmeraldTag);
    try std.testing.expectEqual(@as(u16, 379), EnchantedGoldenAppleTag);
}

test "autoCraftSingleInput maps log to planks" {
    const r = autoCraftSingleInput(WoodLogTag).?;
    try std.testing.expectEqual(WoodPlanksTag, r.output_tag);
    try std.testing.expectEqual(@as(u8, 4), r.output_count);
}

test "autoCraftSingleInput maps planks to sticks" {
    const r = autoCraftSingleInput(WoodPlanksTag).?;
    try std.testing.expectEqual(StickTag, r.output_tag);
    try std.testing.expectEqual(@as(u8, 2), r.output_count);
}

test "autoCraftSingleInput maps breeze rod to wind charge" {
    const r = autoCraftSingleInput(BreezeRodTag).?;
    try std.testing.expectEqual(WindChargeTag, r.output_tag);
    try std.testing.expectEqual(@as(u8, 4), r.output_count);
}

test "autoCraftSingleInput unknown returns null" {
    try std.testing.expectEqual(@as(?AutoCraftResult, null), autoCraftSingleInput(0));
    try std.testing.expectEqual(@as(?AutoCraftResult, null), autoCraftSingleInput(DiamondTag));
    try std.testing.expectEqual(@as(?AutoCraftResult, null), autoCraftSingleInput(WindChargeTag));
    try std.testing.expectEqual(@as(?AutoCraftResult, null), autoCraftSingleInput(65535));
}

test "vaultLootForRoll covers all residues" {
    const r0 = vaultLootForRoll(0);
    try std.testing.expectEqual(HeavyCoreTag, r0.output_tag);
    try std.testing.expectEqual(@as(u8, 1), r0.output_count);

    const r1 = vaultLootForRoll(1);
    try std.testing.expectEqual(BreezeRodTag, r1.output_tag);
    try std.testing.expectEqual(@as(u8, 3), r1.output_count);

    const r2 = vaultLootForRoll(2);
    try std.testing.expectEqual(DiamondTag, r2.output_tag);
    try std.testing.expectEqual(@as(u8, 2), r2.output_count);

    const r3 = vaultLootForRoll(3);
    try std.testing.expectEqual(EmeraldTag, r3.output_tag);
    try std.testing.expectEqual(@as(u8, 4), r3.output_count);

    const r4 = vaultLootForRoll(4);
    try std.testing.expectEqual(EnchantedGoldenAppleTag, r4.output_tag);
    try std.testing.expectEqual(@as(u8, 1), r4.output_count);
}

test "vaultLootForRoll wraps by modulo 5" {
    const r5 = vaultLootForRoll(5);
    try std.testing.expectEqual(HeavyCoreTag, r5.output_tag);
    try std.testing.expectEqual(@as(u8, 1), r5.output_count);

    const r9 = vaultLootForRoll(9);
    try std.testing.expectEqual(EnchantedGoldenAppleTag, r9.output_tag);

    const r10 = vaultLootForRoll(10);
    try std.testing.expectEqual(HeavyCoreTag, r10.output_tag);

    const r255 = vaultLootForRoll(255);
    try std.testing.expectEqual(HeavyCoreTag, r255.output_tag);
    try std.testing.expectEqual(@as(u8, 1), r255.output_count);
}

// --- Gameplay tag mapping bridge tests ---

test "gridItemFromTag and tagFromGridItem round-trip supported gameplay items" {
    const pairs = [_]struct { tag: u16, item: Item }{
        .{ .tag = IronIngotTag, .item = .iron_ingot },
        .{ .tag = IronBlockTag, .item = .iron_block },
        .{ .tag = WoodPlanksTag, .item = .wood_planks },
        .{ .tag = CraftingBenchTag, .item = .crafting_table },
        .{ .tag = CoalTag, .item = .coal },
        .{ .tag = StickTag, .item = .stick },
        .{ .tag = TorchTag, .item = .torch },
        .{ .tag = FlintTag, .item = .flint },
        .{ .tag = ArrowTag, .item = .arrow },
        .{ .tag = WoodenSlabTag, .item = .wooden_slab },
        .{ .tag = RedstoneDustTag, .item = .redstone },
    };
    for (pairs) |pair| {
        try std.testing.expectEqual(@as(?Item, pair.item), gridItemFromTag(pair.tag));
        try std.testing.expectEqual(@as(?u16, pair.tag), tagFromGridItem(pair.item));
    }
    try std.testing.expectEqual(@as(?Item, null), gridItemFromTag(0));
    try std.testing.expectEqual(@as(?u16, null), tagFromGridItem(.other));
}

// --- Pulsed grid tests (from crafter_pulsed_grid) ---

test "slot count describes the 3x3 grid" {
    try std.testing.expectEqual(@as(usize, 9), slot_count);
}

test "disabled mask starts empty" {
    const c = Crafter{};
    try std.testing.expectEqual(@as(u9, 0), c.disabled_mask);
}

test "disabling a slot sets its bit" {
    var c = Crafter{};
    try std.testing.expect(c.setDisabled(0, true));
    try std.testing.expectEqual(@as(u9, 1), c.disabled_mask);
}

test "enabling a slot clears its bit" {
    var c = Crafter{ .disabled_mask = 4 };
    try std.testing.expect(c.setDisabled(2, false));
    try std.testing.expectEqual(@as(u9, 0), c.disabled_mask);
}

test "toggling multiple mask bits preserves neighbors" {
    var c = Crafter{};
    _ = c.setDisabled(1, true);
    _ = c.setDisabled(7, true);
    _ = c.setDisabled(1, false);
    try std.testing.expectEqual(@as(u9, 128), c.disabled_mask);
}

test "invalid slot toggle is rejected" {
    var c = Crafter{};
    try std.testing.expect(!c.setDisabled(9, true));
}

test "disabled state query rejects out of range indices" {
    const c = Crafter{};
    try std.testing.expect(c.isDisabled(9));
}

test "disabling occupied slot clears its contents" {
    var c = Crafter{};
    _ = c.insert(4, .iron_ingot, 3, 64);
    _ = c.setDisabled(4, true);
    try std.testing.expectEqual(@as(?Stack, null), c.slots[4]);
}

test "toggleSlot toggles enabled slot to disabled and back" {
    var c = Crafter{};
    try std.testing.expect(!c.isDisabled(3));
    try std.testing.expect(c.toggleSlot(3));
    try std.testing.expect(c.isDisabled(3));
    try std.testing.expectEqual(@as(u9, 1 << 3), c.disabled_mask);

    try std.testing.expect(c.toggleSlot(3));
    try std.testing.expect(!c.isDisabled(3));
    try std.testing.expectEqual(@as(u9, 0), c.disabled_mask);
}

test "toggleSlot clears occupied items when disabling" {
    var c = Crafter{};
    _ = c.insert(2, .gold_ingot, 5, 64);
    try std.testing.expect(c.slots[2] != null);
    _ = c.toggleSlot(2);
    try std.testing.expect(c.isDisabled(2));
    try std.testing.expectEqual(@as(?Stack, null), c.slots[2]);
}

test "toggleSlot out of range returns false" {
    var c = Crafter{};
    try std.testing.expect(!c.toggleSlot(9));
    try std.testing.expect(!c.toggleSlot(100));
}

test "disabledCount and enabledCount reflect disabled mask" {
    var c = Crafter{};
    try std.testing.expectEqual(@as(usize, 0), c.disabledCount());
    try std.testing.expectEqual(@as(usize, 9), c.enabledCount());

    _ = c.setDisabled(0, true);
    _ = c.setDisabled(4, true);
    _ = c.setDisabled(8, true);

    try std.testing.expectEqual(@as(usize, 3), c.disabledCount());
    try std.testing.expectEqual(@as(usize, 6), c.enabledCount());
}

test "disabled slot refuses direct hopper insertion" {
    var c = Crafter{};
    _ = c.setDisabled(3, true);
    try std.testing.expectEqual(@as(u8, 2), c.insert(3, .iron_ingot, 2, 64));
}

test "direct insertion rejects invalid slot" {
    var c = Crafter{};
    try std.testing.expectEqual(@as(u8, 1), c.insert(9, .iron_ingot, 1, 64));
}

test "insertion respects slot capacity" {
    var c = Crafter{};
    try std.testing.expectEqual(@as(u8, 1), c.insert(0, .iron_ingot, 5, 4));
    try std.testing.expectEqual(@as(u8, 4), c.slots[0].?.count);
}

test "insertion does not mix item types" {
    var c = Crafter{};
    _ = c.insert(0, .other, 2, 64);
    try std.testing.expectEqual(@as(u8, 1), c.insert(0, .iron_ingot, 1, 64));
}

test "no craft without a rising redstone edge" {
    var c = Crafter{};
    try std.testing.expectEqual(CraftResult.none, c.tick(false));
}

test "craft requires all enabled slots filled" {
    var c = Crafter{};
    try std.testing.expectEqual(CraftResult.missing_ingredients, c.tick(true));
}

test "craft consumes one item from each enabled slot" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 2 };
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    for (c.slots) |s| try std.testing.expectEqual(@as(u8, 1), s.?.count);
}

test "craft rejects wrong ingredient" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 1 };
    c.slots[5] = .{ .item = .other, .count = 1 };
    try std.testing.expectEqual(CraftResult.missing_ingredients, c.tick(true));
}

test "held redstone does not craft repeatedly" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 2 };
    _ = c.tick(true);
    try std.testing.expectEqual(CraftResult.none, c.tick(true));
}

test "craft output ejects through front nozzle" {
    var c = Crafter{ .front_nozzle = .east };
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 1 };
    _ = c.tick(true);
    try std.testing.expectEqual(NozzleOutput{ .item = .iron_block, .count = 1, .direction = .east }, c.output.?);
}

test "nozzle output resets on later tick" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 1 };
    _ = c.tick(true);
    _ = c.tick(false);
    try std.testing.expectEqual(@as(?NozzleOutput, null), c.output);
}

test "minimum craft delay blocks edges less than four ticks apart" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 2 };
    _ = c.tick(true);
    _ = c.tick(false);
    try std.testing.expectEqual(CraftResult.cooldown, c.tick(true));
}

test "craft is allowed exactly four ticks after previous craft" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 2 };
    _ = c.tick(true);
    _ = c.tick(false);
    _ = c.tick(false);
    _ = c.tick(false);
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
}

test "craft multiple operations spaced by 4 ticks" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 3 };

    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(@as(u32, 1), c.craft_count);

    _ = c.tick(false);
    _ = c.tick(false);
    _ = c.tick(false);

    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(@as(u32, 2), c.craft_count);
}

test "custom recipe matching with disabled slots" {
    var c = Crafter{ .front_nozzle = .down };
    var pattern: [slot_count]?Item = [_]?Item{null} ** slot_count;
    pattern[0] = .wood_planks;
    pattern[1] = .wood_planks;
    pattern[3] = .wood_planks;
    pattern[4] = .wood_planks;

    c.recipe = .{
        .pattern = pattern,
        .output = .{ .item = .crafting_table, .count = 1 },
    };

    _ = c.setDisabled(2, true);
    _ = c.setDisabled(5, true);
    _ = c.setDisabled(6, true);
    _ = c.setDisabled(7, true);
    _ = c.setDisabled(8, true);

    c.slots[0] = .{ .item = .wood_planks, .count = 2 };
    c.slots[1] = .{ .item = .wood_planks, .count = 1 };
    c.slots[3] = .{ .item = .wood_planks, .count = 3 };
    c.slots[4] = .{ .item = .wood_planks, .count = 4 };

    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(NozzleOutput{ .item = .crafting_table, .count = 1, .direction = .down }, c.output.?);

    try std.testing.expectEqual(@as(u8, 1), c.slots[0].?.count);
    try std.testing.expectEqual(@as(?Stack, null), c.slots[1]);
    try std.testing.expectEqual(@as(u8, 2), c.slots[3].?.count);
    try std.testing.expectEqual(@as(u8, 3), c.slots[4].?.count);
}

test "custom recipe fails when ingredient missing in active slot" {
    var c = Crafter{};
    var pattern: [slot_count]?Item = [_]?Item{null} ** slot_count;
    pattern[0] = .gold_ingot;
    pattern[1] = .gold_ingot;

    c.recipe = .{
        .pattern = pattern,
        .output = .{ .item = .gold_block, .count = 1 },
    };

    c.slots[0] = .{ .item = .gold_ingot, .count = 1 };

    try std.testing.expectEqual(CraftResult.missing_ingredients, c.tick(true));
}

test "direction vector produces normalized unit vectors" {
    try std.testing.expectEqual([3]f32{ 0.0, 0.0, -1.0 }, directionVector(.north));
    try std.testing.expectEqual([3]f32{ 0.0, 0.0, 1.0 }, directionVector(.south));
    try std.testing.expectEqual([3]f32{ 1.0, 0.0, 0.0 }, directionVector(.east));
    try std.testing.expectEqual([3]f32{ -1.0, 0.0, 0.0 }, directionVector(.west));
    try std.testing.expectEqual([3]f32{ 0.0, 1.0, 0.0 }, directionVector(.up));
    try std.testing.expectEqual([3]f32{ 0.0, -1.0, 0.0 }, directionVector(.down));
}

test "hopper begins at lowest enabled slot" {
    var c = Crafter{};
    var h = HopperRoundRobin{};
    try std.testing.expectEqual(@as(?u4, 0), h.insert(&c, .iron_ingot, 1).slot);
}

test "hopper places successive inserts in sequential slots" {
    var c = Crafter{};
    var h = HopperRoundRobin{};
    for (0..3) |expected| try std.testing.expectEqual(@as(?u4, @intCast(expected)), h.insert(&c, .iron_ingot, 1).slot);
}

test "hopper wraps after final slot" {
    var c = Crafter{};
    var h = HopperRoundRobin{ .next_slot = 8 };
    _ = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?u4, 0), h.insert(&c, .iron_ingot, 1).slot);
}

test "hopper skips disabled slots" {
    var c = Crafter{};
    _ = c.setDisabled(0, true);
    var h = HopperRoundRobin{};
    try std.testing.expectEqual(@as(?u4, 1), h.insert(&c, .iron_ingot, 1).slot);
}

test "hopper skips consecutive disabled slots" {
    var c = Crafter{};
    _ = c.setDisabled(0, true);
    _ = c.setDisabled(1, true);
    _ = c.setDisabled(2, true);
    var h = HopperRoundRobin{};
    try std.testing.expectEqual(@as(?u4, 3), h.insert(&c, .iron_ingot, 1).slot);
}

test "hopper round-robin distribution with checkerboard disabled mask" {
    var c = Crafter{};
    _ = c.setDisabled(0, true);
    _ = c.setDisabled(2, true);
    _ = c.setDisabled(4, true);
    _ = c.setDisabled(6, true);
    _ = c.setDisabled(8, true);

    var h = HopperRoundRobin{};
    try std.testing.expectEqual(@as(?u4, 1), h.insert(&c, .redstone, 1).slot);
    try std.testing.expectEqual(@as(?u4, 3), h.insert(&c, .redstone, 1).slot);
    try std.testing.expectEqual(@as(?u4, 5), h.insert(&c, .redstone, 1).slot);
    try std.testing.expectEqual(@as(?u4, 7), h.insert(&c, .redstone, 1).slot);
    try std.testing.expectEqual(@as(?u4, 1), h.insert(&c, .redstone, 1).slot);
}

test "hopper adds to an existing same item stack" {
    var c = Crafter{};
    _ = c.insert(0, .iron_ingot, 2, 64);
    var h = HopperRoundRobin{};
    try std.testing.expectEqual(@as(?u4, 0), h.insert(&c, .iron_ingot, 3).slot);
    try std.testing.expectEqual(@as(u8, 5), c.slots[0].?.count);
}

test "hopper does not overwrite incompatible slot" {
    var c = Crafter{};
    _ = c.insert(0, .other, 64, 64);
    var h = HopperRoundRobin{};
    try std.testing.expectEqual(@as(?u4, 1), h.insert(&c, .iron_ingot, 1).slot);
    try std.testing.expectEqual(Item.other, c.slots[0].?.item);
}

test "full enabled grid returns item as backpressure" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 64 };
    var h = HopperRoundRobin{};
    const result = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(u8, 0), result.accepted);
    try std.testing.expectEqual(@as(u8, 1), result.remaining);
    try std.testing.expect(h.backpressured);
}

test "all disabled slots apply hopper backpressure" {
    var c = Crafter{};
    c.disabled_mask = std.math.maxInt(u9);
    var h = HopperRoundRobin{};
    _ = h.insert(&c, .iron_ingot, 1);
    try std.testing.expect(h.backpressured);
}

test "hopper backpressure clears when enabled slot has room" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 64 };
    c.slots[4].?.count = 63;
    var h = HopperRoundRobin{};
    h.refreshBackpressure(&c);
    try std.testing.expect(!h.backpressured);
}

test "hopper round robin distributes evenly across all 9 slots" {
    var c = Crafter{};
    var h = HopperRoundRobin{};
    for (0..9) |expected_slot| {
        const res = h.insert(&c, .copper_ingot, 1);
        try std.testing.expectEqual(@as(?u4, @intCast(expected_slot)), res.slot);
        try std.testing.expectEqual(@as(u8, 1), res.accepted);
        try std.testing.expectEqual(@as(u8, 0), res.remaining);
    }
    for (c.slots) |slot| {
        try std.testing.expectEqual(@as(u8, 1), slot.?.count);
        try std.testing.expectEqual(Item.copper_ingot, slot.?.item);
    }
}

test "comparator empty grid is zero" {
    const c = Crafter{};
    try std.testing.expectEqual(@as(u4, 0), c.comparatorSignal());
}

test "comparator counts each occupied slot once" {
    var c = Crafter{};
    _ = c.insert(0, .iron_ingot, 64, 64);
    _ = c.insert(4, .iron_ingot, 1, 64);
    try std.testing.expectEqual(@as(u4, 2), c.comparatorSignal());
}

test "comparator adds disabled and occupied slot counts" {
    var c = Crafter{};
    _ = c.setDisabled(1, true);
    _ = c.setDisabled(3, true);
    _ = c.insert(0, .iron_ingot, 1, 64);
    _ = c.insert(8, .iron_ingot, 1, 64);
    try std.testing.expectEqual(@as(u4, 4), c.comparatorSignal());
}

test "comparator disabled slots count even though their contents clear" {
    var c = Crafter{};
    _ = c.insert(5, .iron_ingot, 2, 64);
    _ = c.setDisabled(5, true);
    try std.testing.expectEqual(@as(u4, 1), c.comparatorSignal());
}

test "comparator maximum output is nine" {
    var c = Crafter{ .disabled_mask = std.math.maxInt(u9) };
    try std.testing.expectEqual(@as(u4, 9), c.comparatorSignal());
}

test "comparator is capped when all slots are occupied and some disabled" {
    var c = Crafter{ .disabled_mask = 1 };
    for (&c.slots) |*s| s.* = .{ .item = .other, .count = 1 };
    try std.testing.expectEqual(@as(u4, 9), c.comparatorSignal());
}

test "comparator output scales 0 through 9 incrementally" {
    var c = Crafter{};
    for (0..9) |i| {
        try std.testing.expectEqual(@as(u4, @intCast(i)), c.comparatorSignal());
        _ = c.insert(i, .stick, 1, 64);
    }
    try std.testing.expectEqual(@as(u4, 9), c.comparatorSignal());
}

test "comparator output scales with disabled slots incrementing" {
    var c = Crafter{};
    for (0..9) |i| {
        try std.testing.expectEqual(@as(u4, @intCast(i)), c.comparatorSignal());
        _ = c.setDisabled(i, true);
    }
    try std.testing.expectEqual(@as(u4, 9), c.comparatorSignal());
}

// --- Automation grid tests (from crafter_automation) ---

test "default grid contains nine enabled empty slots" {
    const grid = CrafterGrid{};
    try std.testing.expectEqual(@as(u9, 0), grid.disabled_slots_mask);
    try std.testing.expectEqual(@as(u9, 0), grid.occupied_slots_mask);
    try std.testing.expectEqual(@as(usize, 9), grid.slots.len);
}

test "toggle disables slot and updates mask" {
    var grid = CrafterGrid{};
    try std.testing.expect(grid.toggleSlot(4));
    try std.testing.expect(grid.slots[4].is_disabled);
    try std.testing.expectEqual(@as(u9, 1 << 4), grid.disabled_slots_mask);
}

test "toggle re-enables slot and clears mask" {
    var grid = CrafterGrid{};
    _ = grid.toggleSlot(4);
    _ = grid.toggleSlot(4);
    try std.testing.expect(!grid.slots[4].is_disabled);
    try std.testing.expectEqual(@as(u9, 0), grid.disabled_slots_mask);
}

test "disabling occupied slot clears its item" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 3);
    _ = grid.toggleSlot(0);
    try std.testing.expectEqual(@as(?ItemStack, null), grid.slots[0].stack);
    try std.testing.expectEqual(@as(u9, 0), grid.occupied_slots_mask);
}

test "out of range slot toggle fails safely" {
    var grid = CrafterGrid{};
    try std.testing.expect(!grid.toggleSlot(9));
    try std.testing.expectEqual(@as(u9, 0), grid.disabled_slots_mask);
}

test "set disabled is idempotent" {
    var grid = CrafterGrid{};
    try std.testing.expect(grid.setDisabled(2, true));
    try std.testing.expect(grid.setDisabled(2, true));
    try std.testing.expectEqual(@as(u9, 4), grid.disabled_slots_mask);
}

test "hopper skips disabled first slot" {
    var grid = CrafterGrid{};
    _ = grid.toggleSlot(0);
    try std.testing.expectEqual(@as(u8, 0), grid.insertFromHopper(.coal, 2, 64));
    try std.testing.expectEqual(@as(?ItemType, .coal), if (grid.slots[1].stack) |s| s.item else null);
}

test "hopper fills lowest enabled empty slot" {
    var grid = CrafterGrid{};
    _ = grid.toggleSlot(0);
    _ = grid.toggleSlot(1);
    _ = grid.insertFromHopper(.stick, 1, 64);
    try std.testing.expectEqual(@as(?ItemStack, null), grid.slots[0].stack);
    try std.testing.expectEqual(@as(?ItemType, .stick), if (grid.slots[2].stack) |s| s.item else null);
}

test "hopper stacks into lowest matching slot first" {
    var grid = CrafterGrid{};
    put(&grid, 2, .coal, 4);
    put(&grid, 5, .coal, 8);
    _ = grid.insertFromHopper(.coal, 3, 64);
    try std.testing.expectEqual(@as(u8, 7), grid.slots[2].stack.?.count);
    try std.testing.expectEqual(@as(u8, 8), grid.slots[5].stack.?.count);
}

test "hopper respects stack max and fills next empty slot" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 63);
    try std.testing.expectEqual(@as(u8, 0), grid.insertFromHopper(.coal, 2, 64));
    try std.testing.expectEqual(@as(u8, 64), grid.slots[0].stack.?.count);
    try std.testing.expectEqual(@as(u8, 1), grid.slots[1].stack.?.count);
}

test "hopper returns overflow when grid is full" {
    var grid = CrafterGrid{};
    for (0..9) |i| put(&grid, i, .coal, 64);
    try std.testing.expectEqual(@as(u8, 2), grid.insertFromHopper(.stick, 2, 64));
}

test "hopper ignores zero count" {
    var grid = CrafterGrid{};
    try std.testing.expectEqual(@as(u8, 0), grid.insertFromHopper(.coal, 0, 64));
    try std.testing.expectEqual(@as(u9, 0), grid.occupied_slots_mask);
}

test "occupied mask follows hopper insertion" {
    var grid = CrafterGrid{};
    _ = grid.insertFromHopper(.coal, 1, 64);
    try std.testing.expectEqual(@as(u9, 1), grid.occupied_slots_mask);
}

test "valid iron block recipe consumes one item per slot and ejects" {
    var grid = CrafterGrid{};
    for (0..9) |i| put(&grid, i, .iron_ingot, 2);
    try std.testing.expectEqual(GridCraftResult.crafted, grid.tick(true, .north));
    try std.testing.expectEqual(@as(?ItemStack, .{ .item = .iron_block, .count = 1 }), grid.ejected.?.stack);
    try std.testing.expectEqual(@as(u8, 1), grid.slots[0].stack.?.count);
    try std.testing.expect(grid.is_crafting and grid.indicator_lamp_on);
    try std.testing.expect(grid.ejected.?.particles_emitted);
}

test "iron block recipe clears one-count inputs" {
    var grid = CrafterGrid{};
    for (0..9) |i| put(&grid, i, .iron_ingot, 1);
    _ = grid.tick(true, .east);
    try std.testing.expectEqual(@as(u9, 0), grid.occupied_slots_mask);
}

test "crafting table recipe matches 2x2 at top left" {
    var grid = CrafterGrid{};
    for ([_]usize{ 0, 1, 3, 4 }) |i| put(&grid, i, .wood_planks, 1);
    try std.testing.expectEqual(GridCraftResult.crafted, grid.tick(true, .south));
    try std.testing.expectEqual(ItemType.crafting_table, grid.ejected.?.stack.item);
}

test "2x2 recipe can be offset in 3x3 grid" {
    var grid = CrafterGrid{};
    for ([_]usize{ 4, 5, 7, 8 }) |i| put(&grid, i, .wood_planks, 1);
    try std.testing.expectEqual(GridCraftResult.crafted, grid.tick(true, .west));
}

test "torch recipe crafts four torches" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 1);
    put(&grid, 3, .stick, 1);
    try std.testing.expectEqual(GridCraftResult.crafted, grid.tick(true, .up));
    try std.testing.expectEqual(@as(u8, 4), grid.ejected.?.stack.count);
}

test "arrow recipe crafts four arrows" {
    var grid = CrafterGrid{};
    put(&grid, 0, .flint, 1);
    put(&grid, 3, .stick, 1);
    put(&grid, 6, .feather, 1);
    try std.testing.expectEqual(GridCraftResult.crafted, grid.tick(true, .down));
    try std.testing.expectEqual(ItemType.arrow, grid.ejected.?.stack.item);
}

test "slab recipe crafts six slabs" {
    var grid = CrafterGrid{};
    for (0..3) |i| put(&grid, i, .wood_planks, 1);
    try std.testing.expectEqual(GridCraftResult.crafted, grid.tick(true, .north));
    try std.testing.expectEqual(@as(u8, 6), grid.ejected.?.stack.count);
}

test "mismatched ingredients fail without consumption or ejection" {
    var grid = CrafterGrid{};
    for (0..9) |i| put(&grid, i, if (i == 0) .iron_ingot else .coal, 2);
    const before = grid.slots;
    try std.testing.expectEqual(GridCraftResult.failed, grid.tick(true, .north));
    try std.testing.expectEqualDeep(before, grid.slots);
    try std.testing.expectEqual(@as(?EjectedItem, null), grid.ejected);
    try std.testing.expectEqual(@as(u32, 1), grid.mechanical_failure_clicks);
}

test "extra enabled ingredient prevents shaped match" {
    var grid = CrafterGrid{};
    for ([_]usize{ 0, 1, 3, 4 }) |i| put(&grid, i, .wood_planks, 1);
    put(&grid, 8, .coal, 1);
    try std.testing.expectEqual(GridCraftResult.failed, grid.tick(true, .north));
}

test "disabled empty slots are excluded from recipe matching" {
    var grid = CrafterGrid{};
    for (0..9) |i| put(&grid, i, .iron_ingot, 1);
    _ = grid.toggleSlot(8);
    try std.testing.expectEqual(GridCraftResult.failed, grid.tick(true, .north));
}

test "same powered level does not retrigger craft" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 2);
    put(&grid, 3, .stick, 2);
    _ = grid.tick(true, .north);
    try std.testing.expectEqual(GridCraftResult.none, grid.tick(true, .north));
}

test "falling edge only rearms redstone rising edge" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 2);
    put(&grid, 3, .stick, 2);
    _ = grid.tick(true, .north);
    _ = grid.tick(false, .north);
    try std.testing.expectEqual(GridCraftResult.cooldown, grid.tick(true, .north));
}

test "four redstone ticks eight game ticks block rapid retrigger" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 3);
    put(&grid, 3, .stick, 3);
    _ = grid.tick(true, .north);
    _ = grid.tick(false, .north);
    for (0..6) |_| _ = grid.tick(false, .north);
    try std.testing.expectEqual(GridCraftResult.cooldown, grid.tick(true, .north));
    _ = grid.tick(false, .north);
    try std.testing.expectEqual(GridCraftResult.crafted, grid.tick(true, .north));
}

test "failed pulse also observes cooldown" {
    var grid = CrafterGrid{};
    try std.testing.expectEqual(GridCraftResult.failed, grid.tick(true, .north));
    _ = grid.tick(false, .north);
    try std.testing.expectEqual(GridCraftResult.cooldown, grid.tick(true, .north));
}

test "cooldown counts down one game tick at a time" {
    var grid = CrafterGrid{};
    _ = grid.tick(true, .north);
    try std.testing.expectEqual(cooldown_game_ticks, grid.cooldown_ticks_remaining);
    _ = grid.tick(false, .north);
    try std.testing.expectEqual(cooldown_game_ticks - 1, grid.cooldown_ticks_remaining);
}

test "north nozzle velocity points north at four tenths" {
    const velocity = velocityFor(.north);
    try std.testing.expectEqual(-nozzle_speed, velocity[2]);
}

test "east nozzle velocity points east at four tenths" {
    const velocity = velocityFor(.east);
    try std.testing.expectEqual(nozzle_speed, velocity[0]);
}

test "south nozzle velocity points south at four tenths" {
    try std.testing.expectEqual(nozzle_speed, velocityFor(.south)[2]);
}

test "west nozzle velocity points west at four tenths" {
    try std.testing.expectEqual(-nozzle_speed, velocityFor(.west)[0]);
}

test "up nozzle velocity points upward at four tenths" {
    try std.testing.expectEqual(nozzle_speed, velocityFor(.up)[1]);
}

test "down nozzle velocity points downward at four tenths" {
    try std.testing.expectEqual(-nozzle_speed, velocityFor(.down)[1]);
}

test "comparator empty grid outputs zero" {
    const grid = CrafterGrid{};
    try std.testing.expectEqual(@as(u4, 0), grid.comparatorSignal());
}

test "comparator counts disabled slots" {
    var grid = CrafterGrid{};
    _ = grid.toggleSlot(0);
    _ = grid.toggleSlot(4);
    try std.testing.expectEqual(@as(u4, 2), grid.comparatorSignal());
}

test "comparator counts occupied slots" {
    var grid = CrafterGrid{};
    put(&grid, 2, .coal, 64);
    put(&grid, 5, .stick, 1);
    try std.testing.expectEqual(@as(u4, 2), grid.comparatorSignal());
}

test "grid comparator adds disabled and occupied slot counts" {
    var grid = CrafterGrid{};
    _ = grid.toggleSlot(0);
    _ = grid.toggleSlot(1);
    put(&grid, 4, .coal, 1);
    put(&grid, 8, .stick, 1);
    try std.testing.expectEqual(@as(u4, 4), grid.comparatorSignal());
}

test "comparator clamps fullness signal to nine" {
    var grid = CrafterGrid{};
    for (0..9) |i| _ = grid.toggleSlot(i);
    try std.testing.expectEqual(@as(u4, 9), grid.comparatorSignal());
}

test "comparator full formula clamps mixed count to nine" {
    var grid = CrafterGrid{};
    for (0..6) |i| _ = grid.toggleSlot(i);
    for (6..9) |i| put(&grid, i, .coal, 1);
    try std.testing.expectEqual(@as(u4, 9), grid.comparatorSignal());
}

// --- Factory clocking & smelting pipeline tests (from crafter_factory_clocking) ---

test "one-clock period is two game ticks" {
    var clock = FactoryClock{ .mode = .one_redstone_tick };
    try std.testing.expect(!clock.tick());
    try std.testing.expect(clock.tick());
}

test "four-clock period is eight game ticks" {
    var clock = FactoryClock{ .mode = .four_redstone_ticks };
    for (0..7) |_| try std.testing.expect(!clock.tick());
    try std.testing.expect(clock.tick());
}

test "one-clock has one tick high pulse per cycle" {
    var c = FactoryClock{ .mode = .one_redstone_tick };
    try std.testing.expect(!c.tick());
    try std.testing.expect(c.tick());
    try std.testing.expect(!c.tick());
}

test "four-clock pulses repeat every eight ticks" {
    var c = FactoryClock{ .mode = .four_redstone_ticks };
    for (0..16) |i| try std.testing.expectEqual(i == 7 or i == 15, c.tick());
}

test "crafter executes only on rising edge" {
    var c = ClockedCrafter{};
    fillCrafter(&c, 1);
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(CraftResult.none, c.tick(true));
}

test "crafter requires low transition before next rising edge" {
    var c = ClockedCrafter{};
    fillCrafter(&c, 2);
    _ = c.tick(true);
    try std.testing.expectEqual(CraftResult.none, c.tick(false));
    try std.testing.expectEqual(CraftResult.cooldown, c.tick(true));
}

test "minimum craft delay is four game ticks" {
    var c = ClockedCrafter{};
    fillCrafter(&c, 3);
    _ = c.tick(true);
    _ = c.tick(false);
    try std.testing.expectEqual(CraftResult.cooldown, c.tick(true));
    _ = c.tick(false);
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
}

test "clocked craft consumes one ingot from each enabled slot" {
    var c = ClockedCrafter{};
    fillCrafter(&c, 2);
    _ = c.tick(true);
    for (c.slots) |s| try std.testing.expectEqual(@as(u8, 1), s.?.count);
}

test "successful craft ejects one iron block to output chest" {
    var c = ClockedCrafter{};
    fillCrafter(&c, 1);
    _ = c.tick(true);
    try std.testing.expectEqual(@as(u32, 1), c.output_blocks);
}

test "empty recipe returns missing ingredients" {
    var c = ClockedCrafter{};
    try std.testing.expectEqual(CraftResult.missing_ingredients, c.tick(true));
}

test "disabled slot cannot satisfy recipe" {
    var c = ClockedCrafter{};
    fillCrafter(&c, 1);
    _ = c.setDisabled(4, true);
    try std.testing.expectEqual(CraftResult.missing_ingredients, c.tick(true));
}

test "disabling a slot clears its stored contents" {
    var c = ClockedCrafter{};
    fillCrafter(&c, 2);
    _ = c.setDisabled(4, true);
    try std.testing.expectEqual(@as(?Stack, null), c.slots[4]);
}

test "slot configuration rejects out of range" {
    var c = ClockedCrafter{};
    try std.testing.expect(!c.setDisabled(9, true));
}

test "enabled count tracks disabled slots" {
    var c = ClockedCrafter{};
    _ = c.setDisabled(0, true);
    _ = c.setDisabled(8, true);
    try std.testing.expectEqual(@as(u8, 7), c.enabledCount());
}

test "hopper fills sequential enabled slots in round robin" {
    var c = ClockedCrafter{};
    var h = HopperFeed{};
    for (0..3) |_| {
        const r = h.insert(&c, .iron_ingot, 1);
        try std.testing.expectEqual(@as(u8, 1), r.accepted);
    }
    try std.testing.expectEqual(@as(?u8, 1), if (c.slots[0]) |s| s.count else null);
    try std.testing.expectEqual(@as(?u8, 1), if (c.slots[1]) |s| s.count else null);
    try std.testing.expectEqual(@as(?u8, 1), if (c.slots[2]) |s| s.count else null);
}

test "hopper wraps round robin cursor after slot eight" {
    var c = ClockedCrafter{};
    var h = HopperFeed{ .next_slot = 8 };
    _ = h.insert(&c, .iron_ingot, 1);
    const r = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?u4, 0), r.slot);
}

test "hopper skips disabled slots in round robin" {
    var c = ClockedCrafter{};
    _ = c.setDisabled(0, true);
    var h = HopperFeed{};
    const r = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?u4, 1), r.slot);
}

test "disabled slots remain isolated from hopper input" {
    var c = ClockedCrafter{};
    _ = c.setDisabled(2, true);
    var h = HopperFeed{ .next_slot = 2 };
    _ = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?Stack, null), c.slots[2]);
}

test "hopper places items in the next slot rather than stacking prior slot" {
    var c = ClockedCrafter{};
    var h = HopperFeed{};
    _ = h.insert(&c, .iron_ingot, 4);
    _ = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(u8, 4), c.slots[0].?.count);
    try std.testing.expectEqual(@as(u8, 1), c.slots[1].?.count);
}

test "full enabled slots trigger backpressure" {
    var c = ClockedCrafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 64 };
    var h = HopperFeed{};
    h.refreshBackpressure(&c);
    try std.testing.expect(h.is_backpressured);
}

test "backpressured hopper does not accept items" {
    var c = ClockedCrafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 64 };
    var h = HopperFeed{};
    const r = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(u8, 0), r.accepted);
    try std.testing.expectEqual(@as(u8, 1), r.remaining);
}

test "disabled slots are excluded when checking backpressure" {
    var c = ClockedCrafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 64 };
    _ = c.setDisabled(0, true);
    c.slots[1] = null;
    var h = HopperFeed{ .next_slot = 0 };
    h.refreshBackpressure(&c);
    try std.testing.expect(!h.is_backpressured);
    const r = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?u4, 1), r.slot);
}

test "one nonfull slot clears backpressure" {
    var c = ClockedCrafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 64 };
    c.slots[7].?.count = 63;
    var h = HopperFeed{};
    h.refreshBackpressure(&c);
    try std.testing.expect(!h.is_backpressured);
}

test "incompatible occupied slot blocks insertion without overwriting" {
    var c = ClockedCrafter{};
    c.slots[0] = .{ .item = .iron_ore, .count = 2 };
    for (1..slot_count) |i| c.slots[i] = .{ .item = .iron_ingot, .count = 64 };
    var h = HopperFeed{};
    const r = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?Item, .iron_ore), if (c.slots[0]) |s| s.item else null);
    try std.testing.expectEqual(@as(u8, 1), r.remaining);
}

test "comparator reads empty crafter as zero" {
    try std.testing.expectEqual(@as(u4, 0), (ClockedCrafter{}).comparatorSignal(64));
}

test "comparator reports one item in nine slot capacity" {
    var c = ClockedCrafter{};
    c.slots[0] = .{ .item = .iron_ingot, .count = 1 };
    try std.testing.expectEqual(@as(u4, 1), c.comparatorSignal(64));
}

test "comparator reports half full as eight" {
    var c = ClockedCrafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 32 };
    try std.testing.expectEqual(@as(u4, 8), c.comparatorSignal(64));
}

test "comparator reflects fullness during active clocking" {
    var c = ClockedCrafter{};
    fillCrafter(&c, 64);
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(@as(u4, 14), c.comparatorSignal(64));
}

test "comparator ignores disabled slots in denominator" {
    var c = ClockedCrafter{};
    _ = c.setDisabled(8, true);
    fillCrafter(&c, 64);
    c.slots[8] = null;
    try std.testing.expectEqual(@as(u4, 15), c.comparatorSignal(64));
}

test "comparator handles zero stack limit" {
    var c = ClockedCrafter{};
    fillCrafter(&c, 1);
    try std.testing.expectEqual(@as(u4, 0), c.comparatorSignal(0));
}

test "factory smelts iron ore into ingots at blast furnace rate" {
    var p = FactoryPipeline.init(.four_redstone_ticks, 1);
    const r = p.run(100);
    try std.testing.expectEqual(@as(u32, 1), r.ore_smelted);
}

test "factory pipeline crafts iron blocks after nine ingots" {
    var p = FactoryPipeline.init(.four_redstone_ticks, 9);
    const r = p.run(1000);
    try std.testing.expectEqual(@as(u32, 9), r.ore_smelted);
    try std.testing.expectEqual(@as(u32, 9), r.ingots_crafted);
    try std.testing.expectEqual(@as(u32, 1), r.blocks_output);
}

test "factory pipeline reports item throughput per minute" {
    var p = FactoryPipeline.init(.four_redstone_ticks, 9);
    const r = p.run(1200);
    try std.testing.expectEqual(@as(f32, 1), r.items_per_minute);
}

test "factory pipeline reports redstone efficiency" {
    var p = FactoryPipeline.init(.four_redstone_ticks, 9);
    const r = p.run(1000);
    try std.testing.expect(r.redstone_edges > 0);
    try std.testing.expect(r.crafts_per_edge > 0);
    try std.testing.expect(r.crafts_per_edge <= 1);
}

test "factory pipeline reports zero throughput for zero ticks" {
    var p = FactoryPipeline.init(.one_redstone_tick, 9);
    const r = p.run(0);
    try std.testing.expectEqual(@as(f32, 0), r.items_per_minute);
}

test "factory output chest accumulates blocks across multiple batches" {
    var p = FactoryPipeline.init(.four_redstone_ticks, 18);
    const r = p.run(1900);
    try std.testing.expectEqual(@as(u32, 2), r.blocks_output);
}

test "one clock and four clock produce distinct edge counts" {
    var fast = FactoryPipeline.init(.one_redstone_tick, 0);
    var slow = FactoryPipeline.init(.four_redstone_ticks, 0);
    const a = fast.run(80);
    const b = slow.run(80);
    try std.testing.expectEqual(@as(u32, 40), a.redstone_edges);
    try std.testing.expectEqual(@as(u32, 10), b.redstone_edges);
}
