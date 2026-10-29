//! Milestone 514: portable 27-slot shulker box storage, dyeing and comparator output.
const std = @import("std");
pub const SLOT_COUNT: usize = 27;
pub const DyeColor = enum(u4) { white, orange, magenta, light_blue, yellow, lime, pink, gray, light_gray, cyan, purple, blue, brown, green, red, black };
pub const ItemType = enum(u16) { air = 0, shulker_shell = 160, shulker_box = 161, chest = 16, dye = 0xFFFE, stone = 1 };
pub const ItemStack = struct {
    item: ItemType = .air,
    count: u8 = 0,
    pub fn empty(self: ItemStack) bool {
        return self.count == 0 or self.item == .air;
    }
};
pub const CraftOutput = struct { item: ItemType, color: ?DyeColor = null, count: u8 = 1 };
pub const BreakCause = enum { tool, explosion };
pub const ShulkerBoxItem = struct { item: ItemType = .shulker_box, contents: [SLOT_COUNT]ItemStack, color: ?DyeColor = null };
pub const MiningResult = struct { drop: ShulkerBoxItem, spilled_items: usize };

pub const ShulkerBox = struct {
    slots: [SLOT_COUNT]ItemStack = [_]ItemStack{.{}} ** SLOT_COUNT,
    color: ?DyeColor = null,
    pub fn canInsertItem(_: *const ShulkerBox, item: ItemType) bool {
        return item != .shulker_box;
    }
    pub fn insert(self: *ShulkerBox, index: usize, stack: ItemStack) bool {
        if (index >= SLOT_COUNT or stack.empty() or !self.canInsertItem(stack.item) or !self.slots[index].empty()) return false;
        self.slots[index] = stack;
        return true;
    }
    pub fn mine(self: ShulkerBox, _: BreakCause) MiningResult {
        return .{ .drop = .{ .contents = self.slots, .color = self.color }, .spilled_items = 0 };
    }
    pub fn comparatorSignal(self: *const ShulkerBox) u8 {
        var fullness: f64 = 0;
        for (self.slots) |slot| if (!slot.empty()) {
            fullness += @as(f64, @floatFromInt(slot.count)) / 64.0;
        };
        if (fullness == 0) return 0;
        return @intFromFloat(@min(15.0, @floor((fullness / @as(f64, @floatFromInt(SLOT_COUNT))) * 14.0) + 1.0));
    }
};

pub fn place(item: ShulkerBoxItem) ShulkerBox {
    return .{ .slots = item.contents, .color = item.color };
}
pub fn craftShulkerBox(shells: u8, chests: u8) ?CraftOutput {
    if (shells == 2 and chests == 1) return .{ .item = .shulker_box };
    return null;
}
pub fn craftDye(box: ShulkerBoxItem, color: DyeColor) ShulkerBoxItem {
    var result = box;
    result.color = color;
    return result;
}
pub fn washInWaterCauldron(item: ShulkerBoxItem, is_water_cauldron: bool) ?ShulkerBoxItem {
    if (!is_water_cauldron or item.color == null) return null;
    var washed = item;
    washed.color = null;
    return washed;
}

test "recipe crafts exactly two shells and one chest" {
    try std.testing.expect(craftShulkerBox(2, 1) != null);
}
test "recipe rejects one shell" {
    try std.testing.expect(craftShulkerBox(1, 1) == null);
}
test "recipe rejects three shells" {
    try std.testing.expect(craftShulkerBox(3, 1) == null);
}
test "recipe rejects two chests" {
    try std.testing.expect(craftShulkerBox(2, 2) == null);
}
test "recipe output is shulker box" {
    try std.testing.expectEqual(ItemType.shulker_box, craftShulkerBox(2, 1).?.item);
}
test "storage contains 27 empty slots" {
    const b = ShulkerBox{};
    try std.testing.expectEqual(@as(usize, 27), b.slots.len);
    for (b.slots) |s| try std.testing.expect(s.empty());
}
test "insert and read slot zero" {
    var b = ShulkerBox{};
    try std.testing.expect(b.insert(0, .{ .item = .stone, .count = 64 }));
    try std.testing.expectEqual(@as(u8, 64), b.slots[0].count);
}
test "insert works in last slot" {
    var b = ShulkerBox{};
    try std.testing.expect(b.insert(26, .{ .item = .stone, .count = 1 }));
}
test "rejects insertion outside slot range" {
    var b = ShulkerBox{};
    try std.testing.expect(!b.insert(27, .{ .item = .stone, .count = 1 }));
}
test "rejects empty stack insertion" {
    var b = ShulkerBox{};
    try std.testing.expect(!b.insert(0, .{}));
}
test "rejects occupied slot insertion" {
    var b = ShulkerBox{};
    _ = b.insert(0, .{ .item = .stone, .count = 1 });
    try std.testing.expect(!b.insert(0, .{ .item = .stone, .count = 2 }));
}
test "anti nesting canInsertItem rejects shulker box" {
    const b = ShulkerBox{};
    try std.testing.expect(!b.canInsertItem(.shulker_box));
}
test "anti nesting rejects shulker box in each of 27 slots" {
    var b = ShulkerBox{};
    for (0..SLOT_COUNT) |i| try std.testing.expect(!b.insert(i, .{ .item = .shulker_box, .count = 1 }));
}
test "other items remain insertable" {
    const b = ShulkerBox{};
    try std.testing.expect(b.canInsertItem(.stone));
}
test "tool mining preserves content with zero spill" {
    var b = ShulkerBox{};
    b.slots[0] = .{ .item = .stone, .count = 12 };
    const r = b.mine(.tool);
    try std.testing.expectEqual(@as(usize, 0), r.spilled_items);
    try std.testing.expectEqual(b.slots, r.drop.contents);
}
test "explosion mining preserves content with zero spill" {
    var b = ShulkerBox{};
    b.slots[26] = .{ .item = .stone, .count = 4 };
    const r = b.mine(.explosion);
    try std.testing.expectEqual(@as(usize, 0), r.spilled_items);
    try std.testing.expectEqual(b.slots, r.drop.contents);
}
test "mining drop is a shulker box item" {
    const r = (ShulkerBox{}).mine(.tool);
    try std.testing.expectEqual(ItemType.shulker_box, r.drop.item);
}
test "placement restores all saved stacks" {
    var b = ShulkerBox{};
    b.slots[0] = .{ .item = .stone, .count = 4 };
    b.slots[13] = .{ .item = .chest, .count = 2 };
    try std.testing.expectEqual(b.slots, place(b.mine(.tool).drop).slots);
}
test "placement retains box color" {
    const b = ShulkerBox{ .color = .cyan };
    try std.testing.expectEqual(b.color, place(b.mine(.tool).drop).color);
}
test "dye enum contains sixteen colors" {
    try std.testing.expectEqual(@as(usize, 16), @typeInfo(DyeColor).@"enum".fields.len);
}
test "all sixteen dye variants preserve contents" {
    var b = ShulkerBox{};
    b.slots[4] = .{ .item = .stone, .count = 37 };
    const payload = b.mine(.tool).drop;
    inline for (@typeInfo(DyeColor).@"enum".fields) |f| {
        const color: DyeColor = @enumFromInt(f.value);
        const dyed = craftDye(payload, color);
        try std.testing.expectEqual(payload.contents, dyed.contents);
        try std.testing.expectEqual(color, dyed.color.?);
    }
}
test "dye crafting preserves item identity" {
    const dyed = craftDye((ShulkerBox{}).mine(.tool).drop, .red);
    try std.testing.expectEqual(ItemType.shulker_box, dyed.item);
}
test "water cauldron washes dye" {
    const dyed = craftDye((ShulkerBox{}).mine(.tool).drop, .red);
    try std.testing.expect(washInWaterCauldron(dyed, true).?.color == null);
}
test "washing preserves contents" {
    var b = ShulkerBox{};
    b.slots[8] = .{ .item = .stone, .count = 9 };
    const washed = washInWaterCauldron(craftDye(b.mine(.tool).drop, .blue), true).?;
    try std.testing.expectEqual(b.slots, washed.contents);
}
test "nonwater cauldron does not wash" {
    const d = craftDye((ShulkerBox{}).mine(.tool).drop, .blue);
    try std.testing.expect(washInWaterCauldron(d, false) == null);
}
test "washing undyed box is a no-op" {
    const d = (ShulkerBox{}).mine(.tool).drop;
    try std.testing.expect(washInWaterCauldron(d, true) == null);
}
test "empty comparator signal is zero" {
    const b = ShulkerBox{};
    try std.testing.expectEqual(@as(u8, 0), b.comparatorSignal());
}
test "one item comparator signal is one" {
    var b = ShulkerBox{};
    b.slots[0] = .{ .item = .stone, .count = 1 };
    try std.testing.expectEqual(@as(u8, 1), b.comparatorSignal());
}
test "full comparator signal is fifteen" {
    var b = ShulkerBox{};
    for (&b.slots) |*s| s.* = .{ .item = .stone, .count = 64 };
    try std.testing.expectEqual(@as(u8, 15), b.comparatorSignal());
}
test "comparator output is bounded" {
    var b = ShulkerBox{};
    for (&b.slots, 0..) |*s, i| s.* = .{ .item = .stone, .count = @intCast(i + 1) };
    try std.testing.expect(b.comparatorSignal() <= 15);
}
test "last slot contributes to comparator signal" {
    var b = ShulkerBox{};
    b.slots[26] = .{ .item = .stone, .count = 64 };
    try std.testing.expectEqual(@as(u8, 1), b.comparatorSignal());
}
