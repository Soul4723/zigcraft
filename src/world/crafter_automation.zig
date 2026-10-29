const std = @import("std");

pub const slot_count = 9;
pub const cooldown_game_ticks: u8 = 8;
pub const nozzle_speed: f32 = 0.4;

pub const ItemType = enum {
    iron_ingot,
    iron_block,
    wood_planks,
    crafting_table,
    coal,
    stick,
    torch,
    flint,
    feather,
    arrow,
    wooden_slab,
};

pub const ItemStack = struct {
    item: ItemType,
    count: u8,
};

pub const Direction = enum { north, south, east, west, up, down };
pub const CraftResult = enum { none, cooldown, failed, crafted };

pub const EjectedItem = struct {
    stack: ItemStack,
    velocity: [3]f32,
    particles_emitted: bool,
};

const Recipe = struct {
    width: u8,
    height: u8,
    pattern: [9]?ItemType,
    output: ItemStack,
};

const recipes = [_]Recipe{
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
    pub fn tick(self: *CrafterGrid, powered: bool, front: Direction) CraftResult {
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
        for (recipes) |recipe| {
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

    fn matchesAt(self: *const CrafterGrid, recipe: Recipe, x: usize, y: usize) bool {
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

fn velocityFor(direction: Direction) [3]f32 {
    return switch (direction) {
        .north => .{ 0, 0, -nozzle_speed },
        .south => .{ 0, 0, nozzle_speed },
        .east => .{ nozzle_speed, 0, 0 },
        .west => .{ -nozzle_speed, 0, 0 },
        .up => .{ 0, nozzle_speed, 0 },
        .down => .{ 0, -nozzle_speed, 0 },
    };
}

fn put(grid: *CrafterGrid, index: usize, item: ItemType, count: u8) void {
    grid.slots[index].stack = .{ .item = item, .count = count };
    grid.refreshOccupiedMask();
}

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
    try std.testing.expectEqual(CraftResult.crafted, grid.tick(true, .north));
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
    try std.testing.expectEqual(CraftResult.crafted, grid.tick(true, .south));
    try std.testing.expectEqual(ItemType.crafting_table, grid.ejected.?.stack.item);
}

test "2x2 recipe can be offset in 3x3 grid" {
    var grid = CrafterGrid{};
    for ([_]usize{ 4, 5, 7, 8 }) |i| put(&grid, i, .wood_planks, 1);
    try std.testing.expectEqual(CraftResult.crafted, grid.tick(true, .west));
}

test "torch recipe crafts four torches" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 1);
    put(&grid, 3, .stick, 1);
    try std.testing.expectEqual(CraftResult.crafted, grid.tick(true, .up));
    try std.testing.expectEqual(@as(u8, 4), grid.ejected.?.stack.count);
}

test "arrow recipe crafts four arrows" {
    var grid = CrafterGrid{};
    put(&grid, 0, .flint, 1);
    put(&grid, 3, .stick, 1);
    put(&grid, 6, .feather, 1);
    try std.testing.expectEqual(CraftResult.crafted, grid.tick(true, .down));
    try std.testing.expectEqual(ItemType.arrow, grid.ejected.?.stack.item);
}

test "slab recipe crafts six slabs" {
    var grid = CrafterGrid{};
    for (0..3) |i| put(&grid, i, .wood_planks, 1);
    try std.testing.expectEqual(CraftResult.crafted, grid.tick(true, .north));
    try std.testing.expectEqual(@as(u8, 6), grid.ejected.?.stack.count);
}

test "mismatched ingredients fail without consumption or ejection" {
    var grid = CrafterGrid{};
    for (0..9) |i| put(&grid, i, if (i == 0) .iron_ingot else .coal, 2);
    const before = grid.slots;
    try std.testing.expectEqual(CraftResult.failed, grid.tick(true, .north));
    try std.testing.expectEqualDeep(before, grid.slots);
    try std.testing.expectEqual(@as(?EjectedItem, null), grid.ejected);
    try std.testing.expectEqual(@as(u32, 1), grid.mechanical_failure_clicks);
}

test "extra enabled ingredient prevents shaped match" {
    var grid = CrafterGrid{};
    for ([_]usize{ 0, 1, 3, 4 }) |i| put(&grid, i, .wood_planks, 1);
    put(&grid, 8, .coal, 1);
    try std.testing.expectEqual(CraftResult.failed, grid.tick(true, .north));
}

test "disabled empty slots are excluded from recipe matching" {
    var grid = CrafterGrid{};
    for (0..9) |i| put(&grid, i, .iron_ingot, 1);
    _ = grid.toggleSlot(8);
    try std.testing.expectEqual(CraftResult.failed, grid.tick(true, .north));
}

test "same powered level does not retrigger craft" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 2);
    put(&grid, 3, .stick, 2);
    _ = grid.tick(true, .north);
    try std.testing.expectEqual(CraftResult.none, grid.tick(true, .north));
}

test "falling edge only rearms redstone rising edge" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 2);
    put(&grid, 3, .stick, 2);
    _ = grid.tick(true, .north);
    _ = grid.tick(false, .north);
    try std.testing.expectEqual(CraftResult.cooldown, grid.tick(true, .north));
}

test "four redstone ticks eight game ticks block rapid retrigger" {
    var grid = CrafterGrid{};
    put(&grid, 0, .coal, 3);
    put(&grid, 3, .stick, 3);
    _ = grid.tick(true, .north);
    _ = grid.tick(false, .north);
    for (0..6) |_| _ = grid.tick(false, .north);
    try std.testing.expectEqual(CraftResult.cooldown, grid.tick(true, .north));
    _ = grid.tick(false, .north);
    try std.testing.expectEqual(CraftResult.crafted, grid.tick(true, .north));
}

test "failed pulse also observes cooldown" {
    var grid = CrafterGrid{};
    try std.testing.expectEqual(CraftResult.failed, grid.tick(true, .north));
    _ = grid.tick(false, .north);
    try std.testing.expectEqual(CraftResult.cooldown, grid.tick(true, .north));
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

test "comparator adds disabled and occupied slot counts" {
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
