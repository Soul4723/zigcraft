const std = @import("std");

pub const slot_count = 9;
pub const default_max_stack: u8 = 64;
pub const craft_delay_game_ticks: u8 = 4;
pub const hopper_transfer_game_ticks: u8 = 8;
pub const blast_furnace_smelt_game_ticks: u16 = 100;
pub const game_ticks_per_minute: f32 = 1200.0;

pub const ClockMode = enum(u8) {
    one_redstone_tick = 2,
    four_redstone_ticks = 8,

    pub fn periodGameTicks(self: ClockMode) u8 {
        return @intFromEnum(self);
    }
};

pub const Item = enum { iron_ore, iron_ingot, iron_block };

pub const Stack = struct {
    item: Item,
    count: u8,
};

pub const CraftResult = enum { none, crafted, cooldown, missing_ingredients };

/// Nine-slot iron-block crafter driven by sampled redstone clock levels.
pub const Crafter = struct {
    slots: [slot_count]?Stack = [_]?Stack{null} ** slot_count,
    disabled_mask: u9 = 0,
    previous_powered: bool = false,
    game_tick: u64 = 0,
    last_craft_tick: ?u64 = null,
    output_blocks: u32 = 0,
    craft_count: u32 = 0,

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

    pub fn isDisabled(self: *const Crafter, index: usize) bool {
        return index >= slot_count or (self.disabled_mask & (@as(u9, 1) << @intCast(index))) != 0;
    }

    pub fn enabledCount(self: *const Crafter) u8 {
        return @intCast(slot_count - @popCount(self.disabled_mask));
    }

    /// Attempts one recipe on a redstone rising edge; crafting consumes one ingot per slot.
    pub fn tick(self: *Crafter, powered: bool) CraftResult {
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
    pub fn comparatorSignal(self: *const Crafter, max_stack: u8) u4 {
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

    pub fn insert(self: *HopperFeed, crafter: *Crafter, item: Item, count: u8) HopperInsert {
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

    pub fn refreshBackpressure(self: *HopperFeed, crafter: *const Crafter) void {
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
    crafter: Crafter = .{},
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
        if (self.crafter.tick(powered) == .crafted) self.ingots_crafted += slot_count;
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

fn fillCrafter(crafter: *Crafter, count: u8) void {
    for (&crafter.slots) |*slot| slot.* = .{ .item = .iron_ingot, .count = count };
}

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
    var c = Crafter{};
    fillCrafter(&c, 1);
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(CraftResult.none, c.tick(true));
}
test "crafter requires low transition before next rising edge" {
    var c = Crafter{};
    fillCrafter(&c, 2);
    _ = c.tick(true);
    try std.testing.expectEqual(CraftResult.none, c.tick(false));
    try std.testing.expectEqual(CraftResult.cooldown, c.tick(true));
}
test "minimum craft delay is four game ticks" {
    var c = Crafter{};
    fillCrafter(&c, 3);
    _ = c.tick(true);
    _ = c.tick(false);
    try std.testing.expectEqual(CraftResult.cooldown, c.tick(true));
    _ = c.tick(false);
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
}
test "craft consumes one ingot from each enabled slot" {
    var c = Crafter{};
    fillCrafter(&c, 2);
    _ = c.tick(true);
    for (c.slots) |s| try std.testing.expectEqual(@as(u8, 1), s.?.count);
}
test "successful craft ejects one iron block to output chest" {
    var c = Crafter{};
    fillCrafter(&c, 1);
    _ = c.tick(true);
    try std.testing.expectEqual(@as(u32, 1), c.output_blocks);
}
test "empty recipe returns missing ingredients" {
    var c = Crafter{};
    try std.testing.expectEqual(CraftResult.missing_ingredients, c.tick(true));
}
test "disabled slot cannot satisfy recipe" {
    var c = Crafter{};
    fillCrafter(&c, 1);
    _ = c.setDisabled(4, true);
    try std.testing.expectEqual(CraftResult.missing_ingredients, c.tick(true));
}
test "disabling a slot clears its stored contents" {
    var c = Crafter{};
    fillCrafter(&c, 2);
    _ = c.setDisabled(4, true);
    try std.testing.expectEqual(@as(?Stack, null), c.slots[4]);
}
test "slot configuration rejects out of range" {
    var c = Crafter{};
    try std.testing.expect(!c.setDisabled(9, true));
}
test "enabled count tracks disabled slots" {
    var c = Crafter{};
    _ = c.setDisabled(0, true);
    _ = c.setDisabled(8, true);
    try std.testing.expectEqual(@as(u8, 7), c.enabledCount());
}
test "hopper fills sequential enabled slots in round robin" {
    var c = Crafter{};
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
    var c = Crafter{};
    var h = HopperFeed{ .next_slot = 8 };
    _ = h.insert(&c, .iron_ingot, 1);
    const r = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?u4, 0), r.slot);
}
test "hopper skips disabled slots in round robin" {
    var c = Crafter{};
    _ = c.setDisabled(0, true);
    var h = HopperFeed{};
    const r = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?u4, 1), r.slot);
}
test "disabled slots remain isolated from hopper input" {
    var c = Crafter{};
    _ = c.setDisabled(2, true);
    var h = HopperFeed{ .next_slot = 2 };
    _ = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?Stack, null), c.slots[2]);
}
test "hopper places items in the next slot rather than stacking prior slot" {
    var c = Crafter{};
    var h = HopperFeed{};
    _ = h.insert(&c, .iron_ingot, 4);
    _ = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(u8, 4), c.slots[0].?.count);
    try std.testing.expectEqual(@as(u8, 1), c.slots[1].?.count);
}
test "full enabled slots trigger backpressure" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 64 };
    var h = HopperFeed{};
    h.refreshBackpressure(&c);
    try std.testing.expect(h.is_backpressured);
}
test "backpressured hopper does not accept items" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 64 };
    var h = HopperFeed{};
    const r = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(u8, 0), r.accepted);
    try std.testing.expectEqual(@as(u8, 1), r.remaining);
}
test "disabled slots are excluded when checking backpressure" {
    var c = Crafter{};
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
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 64 };
    c.slots[7].?.count = 63;
    var h = HopperFeed{};
    h.refreshBackpressure(&c);
    try std.testing.expect(!h.is_backpressured);
}
test "incompatible occupied slot blocks insertion without overwriting" {
    var c = Crafter{};
    c.slots[0] = .{ .item = .iron_ore, .count = 2 };
    for (1..slot_count) |i| c.slots[i] = .{ .item = .iron_ingot, .count = 64 };
    var h = HopperFeed{};
    const r = h.insert(&c, .iron_ingot, 1);
    try std.testing.expectEqual(@as(?Item, .iron_ore), if (c.slots[0]) |s| s.item else null);
    try std.testing.expectEqual(@as(u8, 1), r.remaining);
}
test "comparator reads empty crafter as zero" {
    try std.testing.expectEqual(@as(u4, 0), (Crafter{}).comparatorSignal(64));
}
test "comparator reports one item in nine slot capacity" {
    var c = Crafter{};
    c.slots[0] = .{ .item = .iron_ingot, .count = 1 };
    try std.testing.expectEqual(@as(u4, 1), c.comparatorSignal(64));
}
test "comparator reports half full as eight" {
    var c = Crafter{};
    for (&c.slots) |*s| s.* = .{ .item = .iron_ingot, .count = 32 };
    try std.testing.expectEqual(@as(u4, 8), c.comparatorSignal(64));
}
test "comparator reflects fullness during active clocking" {
    var c = Crafter{};
    fillCrafter(&c, 64);
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(@as(u4, 14), c.comparatorSignal(64));
}
test "comparator ignores disabled slots in denominator" {
    var c = Crafter{};
    _ = c.setDisabled(8, true);
    fillCrafter(&c, 64);
    c.slots[8] = null;
    try std.testing.expectEqual(@as(u4, 15), c.comparatorSignal(64));
}
test "comparator handles zero stack limit" {
    var c = Crafter{};
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
