const std = @import("std");

pub const Plate = struct { x: i32, y: i32, z: i32, down: bool };
pub const Wire = struct { x: i32, y: i32, z: i32, powered: bool };
pub const Repeater = struct { x: i32, y: i32, z: i32, powered: bool, timer: f32, stage: u2 };
pub const Lamp = struct { x: i32, y: i32, z: i32, lit: bool };
pub const Torch = struct { x: i32, y: i32, z: i32 };
pub const RedTorch = struct { x: i32, y: i32, z: i32, lit: bool, flips: [8]f32, flip_count: u8, burnout: f32 };

pub const plate_cap: usize = 64;
pub const torch_cap: usize = 32;
pub const chest_cap: usize = 16;
pub const wire_cap: usize = 256;
pub const repeater_cap: usize = 64;
pub const lamp_cap: usize = 64;
pub const red_torch_cap: usize = 64;

fn find2D(items: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (items[i].x == x and items[i].y == y and items[i].z == z) return i;
    }
    return null;
}

pub fn findPlate(plates: []Plate, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(plates, n, x, y, z);
}

pub fn findWire(wires: []Wire, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(wires, n, x, y, z);
}

pub fn findRepeater(repeaters: []Repeater, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(repeaters, n, x, y, z);
}

pub fn findTorch(torches: []Torch, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(torches, n, x, y, z);
}

pub fn findRedTorch(torches: []RedTorch, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(torches, n, x, y, z);
}

pub fn findLamp(lamps: []Lamp, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(lamps, n, x, y, z);
}


pub fn swapRemoveLast(n: *usize) void {
    n.* -= 1;
}

test "component find helpers" {
    var plates = [_]Plate{.{ .x = 1, .y = 2, .z = 3, .down = false }} ** 2;
    try std.testing.expectEqual(findPlate(&plates, 1, 1, 2, 3), @as(?usize, 0));
    try std.testing.expectEqual(findPlate(&plates, 1, 9, 9, 9), @as(?usize, null));
    var wires = [_]Wire{.{ .x = 4, .y = 5, .z = 6, .powered = true }} ** 2;
    try std.testing.expectEqual(findWire(&wires, 1, 4, 5, 6), @as(?usize, 0));
    var reps = [_]Repeater{.{ .x = 7, .y = 8, .z = 9, .powered = false, .timer = 0, .stage = 1 }} ** 2;
    try std.testing.expectEqual(findRepeater(&reps, 1, 7, 8, 9), @as(?usize, 0));
    var rts = [_]RedTorch{.{ .x = 1, .y = 1, .z = 1, .lit = true, .flips = [_]f32{-100} ** 8, .flip_count = 0, .burnout = 0 }} ** 2;
    try std.testing.expectEqual(findRedTorch(&rts, 1, 1, 1, 1), @as(?usize, 0));
    var torch = [_]Torch{.{ .x = 2, .y = 3, .z = 4 }} ** 2;
    try std.testing.expectEqual(findTorch(&torch, 1, 2, 3, 4), @as(?usize, 0));
    try std.testing.expectEqual(findTorch(&torch, 1, 9, 9, 9), @as(?usize, null));
    var lamps = [_]Lamp{.{ .x = 3, .y = 4, .z = 5, .lit = false }} ** 2;
    try std.testing.expectEqual(findLamp(&lamps, 1, 3, 4, 5), @as(?usize, 0));
    try std.testing.expectEqual(findLamp(&lamps, 1, 9, 9, 9), @as(?usize, null));
}

pub const plate_door_offsets = [_][3]i32{
    .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
    .{ 1, 1, 0 }, .{ -1, 1, 0 }, .{ 0, 1, 1 }, .{ 0, 1, -1 },
    .{ 0, 1, 0 },
};

pub fn isPosOnPlate(fx: f32, fy: f32, fz: f32, px: i32, py: i32, pz: i32, margin: f32) bool {
    const x0 = @as(f32, @floatFromInt(px)) - margin;
    const x1 = @as(f32, @floatFromInt(px)) + 1.0 + margin;
    const z0 = @as(f32, @floatFromInt(pz)) - margin;
    const z1 = @as(f32, @floatFromInt(pz)) + 1.0 + margin;
    const y0 = @as(f32, @floatFromInt(py)) - 0.1;
    const y1 = @as(f32, @floatFromInt(py)) + 0.6;
    return fx >= x0 and fx <= x1 and fz >= z0 and fz <= z1 and fy >= y0 and fy <= y1;
}

test "isPosOnPlate detection" {
    // Inside plate at (5, 10, 5) with 0.2 margin
    try std.testing.expect(isPosOnPlate(5.5, 10.2, 5.5, 5, 10, 5, 0.2));
    // At margin edge
    try std.testing.expect(isPosOnPlate(4.85, 10.0, 5.0, 5, 10, 5, 0.2));
    // Outside horizontally
    try std.testing.expect(!isPosOnPlate(3.0, 10.0, 5.0, 5, 10, 5, 0.2));
    // Outside vertically
    try std.testing.expect(!isPosOnPlate(5.5, 11.0, 5.5, 5, 10, 5, 0.2));
}

pub const torch_flame_dist_sq: f32 = 400.0; // 20 blocks squared

pub fn isWithinFlameDist(tx: i32, tz: i32, px: f32, pz: f32) bool {
    const tdx = @as(f32, @floatFromInt(tx)) - px;
    const tdz = @as(f32, @floatFromInt(tz)) - pz;
    return tdx * tdx + tdz * tdz < torch_flame_dist_sq;
}

test "isWithinFlameDist check" {
    try std.testing.expect(isWithinFlameDist(0, 0, 0.0, 0.0));
    try std.testing.expect(isWithinFlameDist(10, 10, 0.0, 0.0));
    try std.testing.expect(!isWithinFlameDist(25, 0, 0.0, 0.0));
}

pub const Chest = struct { x: i32, y: i32, z: i32 };

pub fn findChest(chests: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(chests, n, x, y, z);
}

test "findChest helper" {
    const FakeChest = struct { x: i32, y: i32, z: i32 };
    var cs = [_]FakeChest{.{ .x = 1, .y = 2, .z = 3 }} ** 2;
    try std.testing.expectEqual(findChest(&cs, 1, 1, 2, 3), @as(?usize, 0));
    try std.testing.expectEqual(findChest(&cs, 1, 9, 9, 9), @as(?usize, null));
}

pub const Furnace = struct { x: i32, y: i32, z: i32 };

pub fn findFurnace(furnaces: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(furnaces, n, x, y, z);
}

test "findFurnace helper" {
    const FakeFurnace = struct { x: i32, y: i32, z: i32 };
    var fs = [_]FakeFurnace{.{ .x = 1, .y = 2, .z = 3 }} ** 2;
    try std.testing.expectEqual(findFurnace(&fs, 1, 1, 2, 3), @as(?usize, 0));
    try std.testing.expectEqual(findFurnace(&fs, 1, 9, 9, 9), @as(?usize, null));
}

pub fn swapRemove(items: anytype, n: *usize, index: usize) void {
    if (index < n.*) {
        items[index] = items[n.* - 1];
        n.* -= 1;
    }
}

test "swapRemove helper" {
    var arr = [_]i32{ 10, 20, 30, 40 };
    var n: usize = 4;
    swapRemove(&arr, &n, 1);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqual(@as(i32, 40), arr[1]);
    try std.testing.expectEqual(@as(i32, 10), arr[0]);
}

pub fn isTrackedRedstoneComponent(block: @import("block.zig").BlockId) bool {
    return switch (block) {
        .pressure_plate_up, .pressure_plate_down,
        .redstone_wire_off, .redstone_wire_on,
        .repeater_off, .repeater_on,
        .redstone_lamp_off, .redstone_lamp_on,
        .redstone_torch_off, .redstone_torch_on,
        => true,
        else => false,
    };
}

test "isTrackedRedstoneComponent filter" {
    try std.testing.expect(isTrackedRedstoneComponent(.pressure_plate_up));
    try std.testing.expect(isTrackedRedstoneComponent(.redstone_wire_on));
    try std.testing.expect(isTrackedRedstoneComponent(.repeater_off));
    try std.testing.expect(isTrackedRedstoneComponent(.redstone_lamp_on));
    try std.testing.expect(isTrackedRedstoneComponent(.redstone_torch_off));
    try std.testing.expect(!isTrackedRedstoneComponent(.stone));
    try std.testing.expect(!isTrackedRedstoneComponent(.air));
}

pub const PlateAction = enum {
    none,
    trigger,
    release,
};

pub fn evaluatePlateStep(is_down: bool, stepped: bool) PlateAction {
    if (stepped and !is_down) return .trigger;
    if (!stepped and is_down) return .release;
    return .none;
}

test "evaluatePlateStep transitions" {
    try std.testing.expectEqual(PlateAction.trigger, evaluatePlateStep(false, true));
    try std.testing.expectEqual(PlateAction.release, evaluatePlateStep(true, false));
    try std.testing.expectEqual(PlateAction.none, evaluatePlateStep(false, false));
    try std.testing.expectEqual(PlateAction.none, evaluatePlateStep(true, true));
}

pub fn canCreateChest(chest_count: usize, max_chests: usize) bool {
    return chest_count < max_chests;
}

pub fn canCreateFurnace(furnace_count: usize, max_furnaces: usize) bool {
    return furnace_count < max_furnaces;
}

test "component creation limits" {
    try std.testing.expect(canCreateChest(0, 16));
    try std.testing.expect(!canCreateChest(16, 16));
    try std.testing.expect(canCreateFurnace(5, 16));
    try std.testing.expect(!canCreateFurnace(16, 16));
}

pub fn canCreateTorch(torch_count: usize, max_torches: usize) bool {
    return torch_count < max_torches;
}

test "canCreateTorch limit" {
    try std.testing.expect(canCreateTorch(0, 32));
    try std.testing.expect(!canCreateTorch(32, 32));
}

pub fn findDepositSlot(slots: anytype, item: anytype) ?usize {
    for (slots, 0..) |s, i| {
        if (s.item == item and s.count < 64) return i;
    }
    for (slots, 0..) |s, i| {
        if (s.isEmpty()) return i;
    }
    return null;
}

test "findDepositSlot searches matching then empty" {
    const Slot = struct {
        item: u8,
        count: u8,
        pub fn isEmpty(self: @This()) bool {
            return self.count == 0;
        }
    };
    var slots = [_]Slot{
        .{ .item = 1, .count = 64 },
        .{ .item = 2, .count = 10 },
        .{ .item = 0, .count = 0 },
    };
    try std.testing.expectEqual(@as(?usize, 1), findDepositSlot(&slots, @as(u8, 2)));
    try std.testing.expectEqual(@as(?usize, 2), findDepositSlot(&slots, @as(u8, 1)));
    try std.testing.expectEqual(@as(?usize, 2), findDepositSlot(&slots, @as(u8, 3)));
}

pub const brewing_stand_cap: usize = 32;

pub fn findBrewingStand(stands: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(stands, n, x, y, z);
}

test "findBrewingStand helper" {
    const FakeBrewingStand = struct { x: i32, y: i32, z: i32 };
    var bs = [_]FakeBrewingStand{.{ .x = 5, .y = 6, .z = 7 }} ** 2;
    try std.testing.expectEqual(findBrewingStand(&bs, 1, 5, 6, 7), @as(?usize, 0));
    try std.testing.expectEqual(findBrewingStand(&bs, 1, 0, 0, 0), @as(?usize, null));
}

pub const cauldron_cap: usize = 32;

pub fn findCauldron(cauldrons: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(cauldrons, n, x, y, z);
}

test "findCauldron helper" {
    const FakeCauldron = struct { x: i32, y: i32, z: i32 };
    var cs = [_]FakeCauldron{.{ .x = 10, .y = 20, .z = 30 }} ** 2;
    try std.testing.expectEqual(findCauldron(&cs, 1, 10, 20, 30), @as(?usize, 0));
    try std.testing.expectEqual(findCauldron(&cs, 1, 0, 0, 0), @as(?usize, null));
}

pub const note_block_cap: usize = 32;

pub fn findNoteBlock(notes: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(notes, n, x, y, z);
}

test "findNoteBlock helper" {
    const FakeNoteBlock = struct { x: i32, y: i32, z: i32 };
    var nb = [_]FakeNoteBlock{.{ .x = 11, .y = 22, .z = 33 }} ** 2;
    try std.testing.expectEqual(findNoteBlock(&nb, 1, 11, 22, 33), @as(?usize, 0));
    try std.testing.expectEqual(findNoteBlock(&nb, 1, 0, 0, 0), @as(?usize, null));
}

pub const jukebox_cap: usize = 32;

pub fn findJukebox(boxes: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(boxes, n, x, y, z);
}

test "findJukebox helper" {
    const FakeJukebox = struct { x: i32, y: i32, z: i32 };
    var jb = [_]FakeJukebox{.{ .x = 12, .y = 34, .z = 56 }} ** 2;
    try std.testing.expectEqual(findJukebox(&jb, 1, 12, 34, 56), @as(?usize, 0));
    try std.testing.expectEqual(findJukebox(&jb, 1, 0, 0, 0), @as(?usize, null));
}

pub const armor_stand_cap: usize = 32;

pub fn findArmorStand(stands: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(stands, n, x, y, z);
}

test "findArmorStand helper" {
    const FakeArmorStand = struct { x: i32, y: i32, z: i32 };
    var as_arr = [_]FakeArmorStand{.{ .x = 15, .y = 30, .z = 45 }} ** 2;
    try std.testing.expectEqual(findArmorStand(&as_arr, 1, 15, 30, 45), @as(?usize, 0));
    try std.testing.expectEqual(findArmorStand(&as_arr, 1, 0, 0, 0), @as(?usize, null));
}

pub const enchantment_table_cap: usize = 32;

pub fn findEnchantmentTable(tables: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(tables, n, x, y, z);
}

test "findEnchantmentTable helper" {
    const FakeTable = struct { x: i32, y: i32, z: i32 };
    var et = [_]FakeTable{.{ .x = 10, .y = 20, .z = 30 }} ** 2;
    try std.testing.expectEqual(findEnchantmentTable(&et, 1, 10, 20, 30), @as(?usize, 0));
    try std.testing.expectEqual(findEnchantmentTable(&et, 1, 0, 0, 0), @as(?usize, null));
}

pub const anvil_cap: usize = 32;

pub fn findAnvil(anvils: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(anvils, n, x, y, z);
}

test "findAnvil helper" {
    const FakeAnvil = struct { x: i32, y: i32, z: i32 };
    var an = [_]FakeAnvil{.{ .x = 5, .y = 12, .z = 15 }} ** 2;
    try std.testing.expectEqual(findAnvil(&an, 1, 5, 12, 15), @as(?usize, 0));
    try std.testing.expectEqual(findAnvil(&an, 1, 0, 0, 0), @as(?usize, null));
}

pub const grindstone_cap: usize = 32;

pub fn findGrindstone(grindstones: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(grindstones, n, x, y, z);
}

test "findGrindstone helper" {
    const FakeGrindstone = struct { x: i32, y: i32, z: i32 };
    var gs = [_]FakeGrindstone{.{ .x = 7, .y = 9, .z = 11 }} ** 2;
    try std.testing.expectEqual(findGrindstone(&gs, 1, 7, 9, 11), @as(?usize, 0));
    try std.testing.expectEqual(findGrindstone(&gs, 1, 0, 0, 0), @as(?usize, null));
}

pub const smithing_table_cap: usize = 32;

pub fn findSmithingTable(tables: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(tables, n, x, y, z);
}

test "findSmithingTable helper" {
    const FakeTable = struct { x: i32, y: i32, z: i32 };
    var st = [_]FakeTable{.{ .x = 14, .y = 18, .z = 22 }} ** 2;
    try std.testing.expectEqual(findSmithingTable(&st, 1, 14, 18, 22), @as(?usize, 0));
    try std.testing.expectEqual(findSmithingTable(&st, 1, 0, 0, 0), @as(?usize, null));
}

pub const cartography_table_cap: usize = 32;

pub fn findCartographyTable(tables: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(tables, n, x, y, z);
}

test "findCartographyTable helper" {
    const FakeTable = struct { x: i32, y: i32, z: i32 };
    var ct = [_]FakeTable{.{ .x = 16, .y = 20, .z = 24 }} ** 2;
    try std.testing.expectEqual(findCartographyTable(&ct, 1, 16, 20, 24), @as(?usize, 0));
    try std.testing.expectEqual(findCartographyTable(&ct, 1, 0, 0, 0), @as(?usize, null));
}

pub const fletching_table_cap: usize = 32;

pub fn findFletchingTable(tables: anytype, n: usize, x: i32, y: i32, z: i32) ?usize {
    return find2D(tables, n, x, y, z);
}

test "findFletchingTable helper" {
    const FakeTable = struct { x: i32, y: i32, z: i32 };
    var ft = [_]FakeTable{.{ .x = 18, .y = 22, .z = 26 }} ** 2;
    try std.testing.expectEqual(findFletchingTable(&ft, 1, 18, 22, 26), @as(?usize, 0));
    try std.testing.expectEqual(findFletchingTable(&ft, 1, 0, 0, 0), @as(?usize, null));
}
