const std = @import("std");

pub const slot_count: usize = 9;
pub const craft_delay_ticks: u64 = 4;
pub const default_slot_capacity: u8 = 64;

pub const Item = enum {
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
    other,
};

pub const Stack = struct {
    item: Item,
    count: u8,
};

pub const CraftResult = enum {
    none,
    crafted,
    cooldown,
    missing_ingredients,
};

pub const Direction = enum {
    north,
    south,
    east,
    west,
    up,
    down,
};

pub const NozzleOutput = struct {
    item: Item,
    count: u8,
    direction: Direction,
};

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

// ============================================================================
// Unit Tests (25+ tests covering all specification categories)
// ============================================================================

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

    // Craft 1: tick 1
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(@as(u32, 1), c.craft_count);

    // Ticks 2, 3, 4: cooldown
    _ = c.tick(false);
    _ = c.tick(false);
    _ = c.tick(false);

    // Craft 2: tick 5
    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(@as(u32, 2), c.craft_count);
}

test "custom recipe matching with disabled slots" {
    var c = Crafter{ .front_nozzle = .down };
    // 2x2 crafting table recipe in slots 0, 1, 3, 4; slots 2, 5, 6, 7, 8 disabled
    var pattern: [slot_count]?Item = [_]?Item{null} ** slot_count;
    pattern[0] = .wood_planks;
    pattern[1] = .wood_planks;
    pattern[3] = .wood_planks;
    pattern[4] = .wood_planks;

    c.recipe = .{
        .pattern = pattern,
        .output = .{ .item = .crafting_table, .count = 1 },
    };

    // Disable slots 2, 5, 6, 7, 8
    _ = c.setDisabled(2, true);
    _ = c.setDisabled(5, true);
    _ = c.setDisabled(6, true);
    _ = c.setDisabled(7, true);
    _ = c.setDisabled(8, true);

    // Populate active slots
    c.slots[0] = .{ .item = .wood_planks, .count = 2 };
    c.slots[1] = .{ .item = .wood_planks, .count = 1 };
    c.slots[3] = .{ .item = .wood_planks, .count = 3 };
    c.slots[4] = .{ .item = .wood_planks, .count = 4 };

    try std.testing.expectEqual(CraftResult.crafted, c.tick(true));
    try std.testing.expectEqual(NozzleOutput{ .item = .crafting_table, .count = 1, .direction = .down }, c.output.?);

    // Verify 1 plank consumed per active slot
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

    // Only slot 0 filled, slot 1 empty
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
    // Disable slots 0, 2, 4, 6, 8 (alternating)
    _ = c.setDisabled(0, true);
    _ = c.setDisabled(2, true);
    _ = c.setDisabled(4, true);
    _ = c.setDisabled(6, true);
    _ = c.setDisabled(8, true);

    var h = HopperRoundRobin{};
    // Inserts should sequentially go to 1, 3, 5, 7, then wrap back to 1
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
    // Every slot now has 1 copper_ingot
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
