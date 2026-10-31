const std = @import("std");
const items_mod = @import("items.zig");
const recipes_mod = @import("recipes.zig");

// Re-export all public symbols from items.zig
pub const BlockId = items_mod.BlockId;
pub const ItemType = items_mod.ItemType;
pub const ItemStack = items_mod.ItemStack;

pub const canHarvestBlock = items_mod.canHarvestBlock;
pub const MobType = items_mod.MobType;
pub const getMobMeatDrop = items_mod.getMobMeatDrop;
pub const BarterReward = items_mod.BarterReward;
pub const getPiglinBarter = items_mod.getPiglinBarter;
pub const getEmberBonus = items_mod.getEmberBonus;
pub const dropsWitherSkull = items_mod.dropsWitherSkull;
pub const dropsSpiderEye = items_mod.dropsSpiderEye;
pub const dropsSkeletonArrow = items_mod.dropsSkeletonArrow;
pub const dropsDrownedNautilus = items_mod.dropsDrownedNautilus;
pub const dropsDrownedTrident = items_mod.dropsDrownedTrident;
pub const dropsEyeShatter = items_mod.dropsEyeShatter;
pub const dropsZombieIron = items_mod.dropsZombieIron;
pub const BlockDrop = items_mod.BlockDrop;
pub const getBlockDrops = items_mod.getBlockDrops;
pub const fortressLoot = items_mod.fortressLoot;

// Re-export recipe resolution
pub const resolveCraftOutput = recipes_mod.resolveCraftOutput;

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
        inv.slots[3] = .{ .item = .wooden_pickaxe, .count = 1 };
        inv.slots[4] = .{ .item = .wood, .count = 32 };
        inv.slots[5] = .{ .item = .leaves, .count = 32 };

        inv.updateCrafting();
        return inv;
    }

    pub fn getHotbar(self: *Inventory, index: usize) ?*ItemStack {
        if (index >= HOTBAR_SIZE) return null;
        return &self.slots[index];
    }

    pub fn hasFullChainmailSet(self: *const Inventory) bool {
        return self.hasItem(.chainmail_helmet) and
            self.hasItem(.chainmail_chestplate) and
            self.hasItem(.chainmail_leggings) and
            self.hasItem(.chainmail_boots);
    }

    pub fn hasFullLeatherSet(self: *const Inventory) bool {
        return self.hasItem(.leather_helmet) and
            self.hasItem(.leather_chestplate) and
            self.hasItem(.leather_leggings) and
            self.hasItem(.leather_boots);
    }

    pub fn hasFullGoldenSet(self: *const Inventory) bool {
        return self.hasItem(.golden_helmet) and
            self.hasItem(.golden_chestplate) and
            self.hasItem(.golden_leggings) and
            self.hasItem(.golden_boots);
    }

    pub fn hasAnyGoldenArmor(self: *const Inventory) bool {
        return self.hasItem(.golden_helmet) or
            self.hasItem(.golden_chestplate) or
            self.hasItem(.golden_leggings) or
            self.hasItem(.golden_boots);
    }

    pub fn hasAnyGoldenItem(self: *const Inventory) bool {
        return self.hasAnyGoldenArmor() or
            self.hasItem(.gold_nugget) or
            self.hasItem(.golden_apple) or
            self.hasItem(.gold_block) or
            self.hasItem(.golden_sword) or
            self.hasItem(.golden_pickaxe) or
            self.hasItem(.golden_axe) or
            self.hasItem(.golden_shovel) or
            self.hasItem(.golden_hoe) or self.hasItem(.golden_carrot) or self.hasItem(.enchanted_golden_apple);
    }

    pub fn hasFullIronSet(self: *const Inventory) bool {
        return self.hasItem(.iron_helmet) and
            self.hasItem(.iron_chestplate) and
            self.hasItem(.iron_leggings) and
            self.hasItem(.iron_boots);
    }

    pub fn hasFullDiamondSet(self: *const Inventory) bool {
        return self.hasItem(.diamond_helmet) and
            self.hasItem(.diamond_chestplate) and
            self.hasItem(.diamond_leggings) and
            self.hasItem(.diamond_boots);
    }

    pub fn hasFullNetheriteSet(self: *const Inventory) bool {
        return self.hasItem(.netherite_helmet) and
            self.hasItem(.netherite_chestplate) and
            self.hasItem(.netherite_leggings) and
            (self.hasItem(.netherite_boots) or self.hasItem(.soul_speed_boots));
    }

    pub fn hasItem(self: *const Inventory, item: ItemType) bool {
        for (self.slots) |slot| {
            if (slot.item == item and slot.count > 0) return true;
        }
        return false;
    }

    pub fn consumeItem(self: *Inventory, item: ItemType) bool {
        for (&self.slots) |*slot| {
            if (slot.item == item and slot.count > 0) {
                slot.decrement(1);
                return true;
            }
        }
        return false;
    }

    pub fn consumeCrossbowAmmo(self: *Inventory) ?ItemType {
        if (self.consumeItem(.fireworks_rocket)) return .fireworks_rocket;
        if (self.consumeItem(.spectral_arrow)) return .spectral_arrow;
        if (self.consumeItem(.arrow)) return .arrow;
        return null;
    }

    pub fn consumeArrow(self: *Inventory) ?ItemType {
        if (self.consumeItem(.spectral_arrow)) return .spectral_arrow;
        if (self.consumeItem(.arrow)) return .arrow;
        return null;
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
        self.craft_output = recipes_mod.resolveCraftOutput(self.craft_grid);
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

        // Lead recipe consumes four strings and one slimeball per batch.
        if (out.item == .lead) {
            var strings_to_consume: u16 = 4;
            var slimeballs_to_consume: u16 = 1;
            for (&self.craft_grid) |*slot| {
                if (slot.item == .string and strings_to_consume > 0) {
                    const consumed: u8 = @intCast(@min(strings_to_consume, slot.count));
                    slot.decrement(consumed);
                    strings_to_consume -= consumed;
                } else if (slot.item == .slimeball and slimeballs_to_consume > 0) {
                    const consumed: u8 = @intCast(@min(slimeballs_to_consume, slot.count));
                    slot.decrement(consumed);
                    slimeballs_to_consume -= consumed;
                }
            }
        } else {
            // Other recipes consume one item from each non-empty ingredient slot.
            for (&self.craft_grid) |*slot| {
                if (!slot.isEmpty()) slot.decrement(1);
            }
        }

        self.updateCrafting();
        return true;
    }
};

test "inventory init and hotbar defaults" {
    var inv = Inventory.init();
    try std.testing.expectEqual(inv.slots[0].item, .stone);
    try std.testing.expectEqual(inv.slots[0].count, 64);
    try std.testing.expectEqual(inv.slots[3].item, .wooden_pickaxe);
    try std.testing.expectEqual(inv.slots[4].item, .wood);
    try std.testing.expectEqual(inv.slots[5].item, .leaves);

    try std.testing.expect(inv.hasItem(.stone));
    try std.testing.expect(inv.consumeItem(.stone));
    try std.testing.expectEqual(@as(u8, 63), inv.slots[0].count);

    inv.craft_grid[0] = .{ .item = .wood, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.wood_planks, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 4), inv.craft_output.count);

    var cursor: ItemStack = .{};
    try std.testing.expect(inv.takeCraftResult(&cursor));
    try std.testing.expectEqual(cursor.item, .wood_planks);
    try std.testing.expectEqual(@as(u8, 4), cursor.count);
}
