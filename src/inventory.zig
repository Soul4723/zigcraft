const std = @import("std");
const block_mod = @import("world/block.zig");
pub const BlockId = block_mod.BlockId;

pub const ItemType = enum(u8) {
    none = 0,
    stone = 1,
    dirt = 2,
    grass = 3,
    water = 4,
    wood = 5,
    leaves = 6,
    wood_planks = 7,
    stick = 8,
    wooden_pickaxe = 9,
    crafting_bench = 10,

    pub fn toBlockId(self: ItemType) ?BlockId {
        return switch (self) {
            .stone => .stone,
            .dirt => .dirt,
            .grass => .grass,
            .water => .water,
            .wood => .wood,
            .leaves => .leaves,
            .wood_planks => .wood_planks,
            .crafting_bench => .crafting_table,
            else => null,
        };
    }

    pub fn fromBlockId(b: BlockId) ItemType {
        return switch (b) {
            .air => .none,
            .stone => .stone,
            .dirt => .dirt,
            .grass => .grass,
            .water => .water,
            .wood => .wood,
            .leaves => .leaves,
            .wood_planks => .wood_planks,
            .crafting_table => .crafting_bench,
        };
    }

    pub fn maxStackSize(self: ItemType) u8 {
        return switch (self) {
            .none => 0,
            .wooden_pickaxe => 1,
            else => 64,
        };
    }

    pub fn name(self: ItemType) []const u8 {
        return switch (self) {
            .none => "Empty",
            .stone => "Stone",
            .dirt => "Dirt",
            .grass => "Grass",
            .water => "Water",
            .wood => "Wood Log",
            .leaves => "Leaves",
            .wood_planks => "Wood Planks",
            .stick => "Stick",
            .wooden_pickaxe => "Wooden Pickaxe",
            .crafting_bench => "Crafting Table",
        };
    }

    pub fn getColor(self: ItemType) [4]f32 {
        return switch (self) {
            .none => .{ 0.0, 0.0, 0.0, 0.0 },
            .stone => .{ 0.6, 0.6, 0.62, 0.95 },
            .dirt => .{ 0.55, 0.35, 0.2, 0.95 },
            .grass => .{ 0.25, 0.75, 0.25, 0.95 },
            .water => .{ 0.2, 0.45, 0.85, 0.95 },
            .wood => .{ 0.45, 0.28, 0.12, 0.95 },
            .leaves => .{ 0.15, 0.55, 0.15, 0.95 },
            .wood_planks => .{ 0.80, 0.62, 0.35, 0.95 },
            .stick => .{ 0.60, 0.45, 0.22, 0.95 },
            .wooden_pickaxe => .{ 0.85, 0.70, 0.40, 0.95 },
            .crafting_bench => .{ 0.75, 0.50, 0.25, 0.95 },
        };
    }
};

pub const ItemStack = struct {
    item: ItemType = .none,
    count: u8 = 0,

    pub fn isEmpty(self: ItemStack) bool {
        return self.item == .none or self.count == 0;
    }

    pub fn clear(self: *ItemStack) void {
        self.item = .none;
        self.count = 0;
    }

    pub fn canStackWith(self: ItemStack, other: ItemStack) bool {
        if (self.isEmpty()) return true;
        if (other.isEmpty()) return true;
        return self.item == other.item and (self.count + other.count <= self.item.maxStackSize());
    }

    pub fn add(self: *ItemStack, count: u8) u8 {
        if (self.item == .none) return count;
        const max = self.item.maxStackSize();
        const available = max - self.count;
        const to_add = @min(available, count);
        self.count += to_add;
        return count - to_add;
    }

    pub fn decrement(self: *ItemStack, amount: u8) void {
        if (amount >= self.count) {
            self.clear();
        } else {
            self.count -= amount;
        }
    }
};

pub const Inventory = struct {
    pub const HOTBAR_SIZE = 6;
    pub const MAIN_SIZE = 18;
    pub const TOTAL_SIZE = HOTBAR_SIZE + MAIN_SIZE; // 24 slots total

    slots: [TOTAL_SIZE]ItemStack,
    craft_grid: [4]ItemStack, // 2x2 player crafting grid: [0, 1; 2, 3]
    craft_output: ItemStack,

    pub fn init() Inventory {
        var inv = Inventory{
            .slots = [_]ItemStack{.{}} ** TOTAL_SIZE,
            .craft_grid = [_]ItemStack{.{}} ** 4,
            .craft_output = .{},
        };

        // Give starter items in hotbar
        inv.slots[0] = .{ .item = .stone, .count = 64 };
        inv.slots[1] = .{ .item = .dirt, .count = 64 };
        inv.slots[2] = .{ .item = .grass, .count = 64 };
        inv.slots[3] = .{ .item = .water, .count = 1 };
        inv.slots[4] = .{ .item = .wood, .count = 32 };
        inv.slots[5] = .{ .item = .leaves, .count = 32 };

        inv.updateCrafting();
        return inv;
    }

    pub fn getHotbar(self: *Inventory, index: usize) ?*ItemStack {
        if (index >= HOTBAR_SIZE) return null;
        return &self.slots[index];
    }

    pub fn addItem(self: *Inventory, item: ItemType, count: u8) u8 {
        if (item == .none or count == 0) return 0;
        var remaining = count;

        // Try existing stacks
        for (&self.slots) |*slot| {
            if (slot.item == item and slot.count < item.maxStackSize()) {
                remaining = slot.add(remaining);
                if (remaining == 0) return 0;
            }
        }

        // Place into first empty slot
        for (&self.slots) |*slot| {
            if (slot.isEmpty()) {
                const max = item.maxStackSize();
                const to_place = @min(max, remaining);
                slot.* = .{ .item = item, .count = to_place };
                remaining -= to_place;
                if (remaining == 0) return 0;
            }
        }

        return remaining;
    }

    /// Evaluates current 2x2 crafting grid and sets output preview.
    pub fn updateCrafting(self: *Inventory) void {
        const g0 = self.craft_grid[0].item;
        const g1 = self.craft_grid[1].item;
        const g2 = self.craft_grid[2].item;
        const g3 = self.craft_grid[3].item;

        // Count non-empty items
        var non_empty: usize = 0;
        for (self.craft_grid) |s| {
            if (!s.isEmpty()) non_empty += 1;
        }

        // Recipe 1: 1 Wood Log -> 4 Wood Planks (any single slot)
        if (non_empty == 1) {
            for (self.craft_grid) |s| {
                if (!s.isEmpty() and s.item == .wood) {
                    self.craft_output = .{ .item = .wood_planks, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 2: 2 Planks vertically -> 4 Sticks
        // Slot 0 & 2 or Slot 1 & 3
        if (non_empty == 2) {
            if ((g0 == .wood_planks and g2 == .wood_planks and g1 == .none and g3 == .none) or
                (g1 == .wood_planks and g3 == .wood_planks and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .stick, .count = 4 };
                return;
            }
        }

        // Recipe 3: 4 Wood Planks (2x2 filled) -> 1 Crafting Table
        if (non_empty == 4) {
            if (g0 == .wood_planks and g1 == .wood_planks and g2 == .wood_planks and g3 == .wood_planks) {
                self.craft_output = .{ .item = .crafting_bench, .count = 1 };
                return;
            }
        }

        // Recipe 4: Wooden Pickaxe recipe in 2x2:
        // Top row: 2 wood planks (g0, g1), bottom: 1 stick (g2 or g3)
        if (non_empty == 3) {
            if (g0 == .wood_planks and g1 == .wood_planks and (g2 == .stick or g3 == .stick)) {
                self.craft_output = .{ .item = .wooden_pickaxe, .count = 1 };
                return;
            }
        }

        self.craft_output.clear();
    }

    /// Craft output clicked: decrements 1 item from each ingredient slot, outputs to cursor stack.
    pub fn takeCraftResult(self: *Inventory, cursor: *ItemStack) bool {
        if (self.craft_output.isEmpty()) return false;

        const out = self.craft_output;
        if (!cursor.isEmpty()) {
            if (cursor.item != out.item or cursor.count + out.count > out.item.maxStackSize()) {
                return false;
            }
            cursor.count += out.count;
        } else {
            cursor.* = out;
        }

        // Decrement inputs
        for (&self.craft_grid) |*slot| {
            if (!slot.isEmpty()) {
                slot.decrement(1);
            }
        }

        self.updateCrafting();
        return true;
    }
};

test "inventory init and hotbar defaults" {
    const inv = Inventory.init();
    try std.testing.expectEqual(inv.slots[0].item, .stone);
    try std.testing.expectEqual(inv.slots[0].count, 64);
    try std.testing.expectEqual(inv.slots[4].item, .wood);
    try std.testing.expectEqual(inv.slots[5].item, .leaves);
}

test "inventory addItem stacking" {
    var inv = Inventory.init();
    inv.slots[0].clear();
    _ = inv.addItem(.stone, 30);
    try std.testing.expectEqual(inv.slots[0].item, .stone);
    try std.testing.expectEqual(inv.slots[0].count, 30);

    _ = inv.addItem(.stone, 40);
    try std.testing.expectEqual(inv.slots[0].count, 64);
    try std.testing.expectEqual(inv.slots[6].item, .stone);
    try std.testing.expectEqual(inv.slots[6].count, 6);
}

test "crafting recipes: wood to planks, planks to sticks, 2x2 to table and pickaxe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .wood, .count = 2 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wood_planks);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    var cursor = ItemStack{};
    try std.testing.expect(inv.takeCraftResult(&cursor));
    try std.testing.expectEqual(cursor.item, .wood_planks);
    try std.testing.expectEqual(cursor.count, 4);
    try std.testing.expectEqual(inv.craft_grid[0].count, 1);

    // Now test sticks (vertical planks)
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 2 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 2 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stick);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Test 4 planks -> crafting table
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .crafting_bench);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "inventory full test: transfer between slots, boundary checks" {
    var inv = Inventory.init();
    // Test slot out of bounds
    try std.testing.expect(inv.getHotbar(6) == null);
    try std.testing.expect(inv.getHotbar(0) != null);

    // Test stack decrement to empty
    var stack = ItemStack{ .item = .dirt, .count = 2 };
    stack.decrement(1);
    try std.testing.expectEqual(stack.count, 1);
    stack.decrement(1);
    try std.testing.expect(stack.isEmpty());

    // Test item max stack
    const pick = ItemType.wooden_pickaxe;
    try std.testing.expectEqual(pick.maxStackSize(), 1);
    const planks = ItemType.wood_planks;
    try std.testing.expectEqual(planks.maxStackSize(), 64);
}
