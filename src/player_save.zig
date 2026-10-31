const std = @import("std");
const player_mod = @import("player.zig");
const camera_mod = @import("camera.zig");
const inventory_mod = @import("inventory.zig");
const wear_mod = @import("world/tool_wear.zig");
const persistence_mod = @import("world/persistence.zig");
const math = @import("math.zig");

comptime {
    std.debug.assert(inventory_mod.Inventory.TOTAL_SIZE == 24);
}

/// Convert live gameplay state to the stable persistence representation.
/// Folds any held cursor stack into main inventory slots first, preserving any overflow
/// directly in `cursor_stack` without polluting the 2x2 crafting grid or dropping items.
pub fn captureState(
    player: *const player_mod.Player,
    cam: *const camera_mod.Camera,
    inventory: *const inventory_mod.Inventory,
    cursor_stack: inventory_mod.ItemStack,
    selected_slot: usize,
    tool_wear: *const wear_mod.Wear,
    dimension: persistence_mod.Dimension,
) persistence_mod.PlayerSaveData {
    var inv = inventory.*;
    var saved_cursor = persistence_mod.SavedSlot{};
    if (!cursor_stack.isEmpty()) {
        const remaining = inv.addItem(cursor_stack.item, cursor_stack.count);
        if (remaining > 0) {
            saved_cursor = .{ .item_id = @intFromEnum(cursor_stack.item), .count = remaining };
        }
    }
    var data = persistence_mod.PlayerSaveData{
        .pos = .{ player.pos.x, player.pos.y, player.pos.z },
        .vel_y = player.vel_y,
        .spawn_point = .{ player.spawn_point.x, player.spawn_point.y, player.spawn_point.z },
        .yaw = cam.yaw,
        .pitch = cam.pitch,
        .dimension = dimension,
        .health = player.health,
        .hunger = player.hunger,
        .saturation = player.saturation,
        .oxygen = player.oxygen,
        .selected_slot = @intCast(@min(selected_slot, 255)),
        .tool_wear = tool_wear.uses,
        .cursor_stack = saved_cursor,
    };
    for (inv.slots, 0..) |stack, n| {
        data.slots[n] = .{ .item_id = @intFromEnum(stack.item), .count = stack.count };
    }
    for (inv.craft_grid, 0..) |stack, n| {
        data.craft_grid[n] = .{ .item_id = @intFromEnum(stack.item), .count = stack.count };
    }
    return data;
}

/// Restore persisted gameplay state, validate and clamp fields safely, and return its world dimension.
pub fn applyState(
    data: *const persistence_mod.PlayerSaveData,
    player: *player_mod.Player,
    cam: *camera_mod.Camera,
    inventory: *inventory_mod.Inventory,
    cursor_stack: *inventory_mod.ItemStack,
    selected_slot: *usize,
    tool_wear: *wear_mod.Wear,
) persistence_mod.Dimension {
    player.spawn_point = math.Vec3.init(data.spawn_point[0], data.spawn_point[1], data.spawn_point[2]);
    var target_dim = data.dimension;
    if (data.health <= 0.0) {
        player.respawn(player.spawn_point.x, player.spawn_point.y, player.spawn_point.z);
        target_dim = .overworld;
    } else {
        player.pos = math.Vec3.init(data.pos[0], data.pos[1], data.pos[2]);
        player.vel_y = data.vel_y;
        player.health = std.math.clamp(data.health, 0.0, 20.0);
        player.hunger = std.math.clamp(data.hunger, 0.0, 20.0);
        player.saturation = std.math.clamp(data.saturation, 0.0, player.hunger);
        player.oxygen = std.math.clamp(data.oxygen, 0.0, 15.0);
    }
    selected_slot.* = @min(@as(usize, data.selected_slot), inventory_mod.Inventory.HOTBAR_SIZE - 1);
    tool_wear.uses = data.tool_wear;
    for (data.slots, 0..) |s, n| inventory.slots[n] = decode(s);
    for (data.craft_grid, 0..) |s, n| inventory.craft_grid[n] = decode(s);
    inventory.updateCrafting();
    const decoded_cursor = decode(data.cursor_stack);
    if (!decoded_cursor.isEmpty()) {
        const leftover = inventory.addItem(decoded_cursor.item, decoded_cursor.count);
        cursor_stack.* = if (leftover > 0) .{ .item = decoded_cursor.item, .count = leftover } else .{};
    } else {
        cursor_stack.* = .{};
    }
    cam.yaw = data.yaw;
    cam.pitch = std.math.clamp(data.pitch, -1.55, 1.55);
    cam.position = player.eyePos();
    return target_dim;
}

fn decode(s: persistence_mod.SavedSlot) inventory_mod.ItemStack {
    const item = std.enums.fromInt(inventory_mod.ItemType, s.item_id) orelse .none;
    if (item == .none or s.count == 0) return .{};
    return .{ .item = item, .count = @min(s.count, item.maxStackSize()) };
}

test "player state capture and apply full roundtrip" {
    var player = player_mod.Player.init(12.5, 34.0, -56.75);
    player.vel_y = -1.2;
    player.spawn_point = math.Vec3.init(100.0, 64.0, 200.0);
    player.health = 17.5;
    player.hunger = 14.0;
    player.saturation = 3.5;
    player.oxygen = 11.0;

    var cam = camera_mod.Camera.init();
    cam.yaw = 1.23;
    cam.pitch = -0.45;
    cam.position = player.eyePos();

    var inv = inventory_mod.Inventory.init();
    inv.slots[0] = .{ .item = .diamond, .count = 3 };
    inv.slots[5] = .{ .item = .iron_sword, .count = 1 };
    inv.slots[10] = .{ .item = .bread, .count = 16 };
    inv.slots[23] = .{ .item = .torch, .count = 64 };
    inv.craft_grid[0] = .{ .item = .wood, .count = 1 };
    inv.updateCrafting();

    var tool_wear = wear_mod.Wear{};
    tool_wear.uses[0] = 42;
    tool_wear.uses[3] = 100;

    const saved = captureState(&player, &cam, &inv, .{}, 4, &tool_wear, .nether);

    var restored_player = player_mod.Player.init(0, 0, 0);
    var restored_cam = camera_mod.Camera.init();
    var restored_inv = inventory_mod.Inventory.init();
    var restored_cursor = inventory_mod.ItemStack{};
    var restored_slot: usize = 0;
    var restored_wear = wear_mod.Wear{};

    const dim = applyState(&saved, &restored_player, &restored_cam, &restored_inv, &restored_cursor, &restored_slot, &restored_wear);

    try std.testing.expectEqual(persistence_mod.Dimension.nether, dim);
    try std.testing.expectEqual(@as(f32, 12.5), restored_player.pos.x);
    try std.testing.expectEqual(@as(f32, 34.0), restored_player.pos.y);
    try std.testing.expectEqual(@as(f32, -56.75), restored_player.pos.z);
    try std.testing.expectEqual(@as(f32, -1.2), restored_player.vel_y);
    try std.testing.expectEqual(@as(f32, 100.0), restored_player.spawn_point.x);
    try std.testing.expectEqual(@as(f32, 17.5), restored_player.health);
    try std.testing.expectEqual(@as(f32, 14.0), restored_player.hunger);
    try std.testing.expectEqual(@as(f32, 3.5), restored_player.saturation);
    try std.testing.expectEqual(@as(f32, 11.0), restored_player.oxygen);
    try std.testing.expectEqual(@as(usize, 4), restored_slot);
    try std.testing.expectEqual(@as(u16, 42), restored_wear.uses[0]);
    try std.testing.expectEqual(@as(u16, 100), restored_wear.uses[3]);
    try std.testing.expectEqual(inventory_mod.ItemType.diamond, restored_inv.slots[0].item);
    try std.testing.expectEqual(@as(u8, 3), restored_inv.slots[0].count);
    try std.testing.expectEqual(inventory_mod.ItemType.wood_planks, restored_inv.craft_output.item);
    try std.testing.expect(restored_cursor.isEmpty());
}

test "cursor stack folds into inventory when space exists and persists losslessly when all 28 slots are full" {
    var player = player_mod.Player.init(0, 0, 0);
    var cam = camera_mod.Camera.init();
    var inv = inventory_mod.Inventory{
        .slots = [_]inventory_mod.ItemStack{.{}} ** inventory_mod.Inventory.TOTAL_SIZE,
        .craft_grid = [_]inventory_mod.ItemStack{.{}} ** 4,
        .craft_output = .{},
    };
    var wear = wear_mod.Wear{};

    // Space exists in main slots: folded directly into slots[0]
    const saved = captureState(&player, &cam, &inv, .{ .item = .golden_apple, .count = 5 }, 0, &wear, .overworld);
    try std.testing.expectEqual(@as(u16, @intFromEnum(inventory_mod.ItemType.golden_apple)), saved.slots[0].item_id);
    try std.testing.expectEqual(@as(u8, 5), saved.slots[0].count);
    try std.testing.expectEqual(@as(u8, 0), saved.cursor_stack.count);

    // Fill ALL 24 inventory slots AND ALL 4 craft_grid slots: cursor stack still survives in saved.cursor_stack without polluting craft_grid!
    for (&inv.slots) |*slot| slot.* = .{ .item = .dirt, .count = 64 };
    for (&inv.craft_grid) |*slot| slot.* = .{ .item = .slimeball, .count = 1 };
    const saved_full = captureState(&player, &cam, &inv, .{ .item = .nether_star, .count = 1 }, 0, &wear, .the_end);
    try std.testing.expectEqual(@as(u16, @intFromEnum(inventory_mod.ItemType.nether_star)), saved_full.cursor_stack.item_id);
    try std.testing.expectEqual(@as(u8, 1), saved_full.cursor_stack.count);
    try std.testing.expectEqual(@as(u16, @intFromEnum(inventory_mod.ItemType.slimeball)), saved_full.craft_grid[0].item_id);

    var restored_inv = inventory_mod.Inventory.init();
    var restored_cursor = inventory_mod.ItemStack{};
    var restored_slot: usize = 0;
    _ = applyState(&saved_full, &player, &cam, &restored_inv, &restored_cursor, &restored_slot, &wear);
    try std.testing.expectEqual(inventory_mod.ItemType.nether_star, restored_cursor.item);
    try std.testing.expectEqual(@as(u8, 1), restored_cursor.count);
}

test "dead player save respawns safely in overworld at spawn_point on reload" {
    var player = player_mod.Player.init(5.0, 10.0, 5.0);
    player.spawn_point = math.Vec3.init(24.0, 20.0, 24.0);
    player.health = 0.0;
    var cam = camera_mod.Camera.init();
    var inv = inventory_mod.Inventory.init();
    var wear = wear_mod.Wear{};

    const saved = captureState(&player, &cam, &inv, .{}, 0, &wear, .nether);
    var restored_player = player_mod.Player.init(0, 0, 0);
    var restored_cursor = inventory_mod.ItemStack{};
    var restored_slot: usize = 0;
    const dim = applyState(&saved, &restored_player, &cam, &inv, &restored_cursor, &restored_slot, &wear);
    try std.testing.expectEqual(persistence_mod.Dimension.overworld, dim);
    try std.testing.expectEqual(@as(f32, 20.0), restored_player.health);
    try std.testing.expectEqual(@as(f32, 24.0), restored_player.pos.x);
}

test "out-of-range ItemType ID and vitals clamp safely" {
    var player = player_mod.Player.init(0, 0, 0);
    var cam = camera_mod.Camera.init();
    var inv = inventory_mod.Inventory.init();
    var cursor = inventory_mod.ItemStack{};
    var slot: usize = 0;
    var wear = wear_mod.Wear{};

    var data = persistence_mod.PlayerSaveData{
        .pos = .{ 0, 0, 0 },
        .spawn_point = .{ 0, 0, 0 },
        .yaw = 0,
        .pitch = 5.0,
        .health = 50.0,
        .hunger = -10.0,
        .saturation = 25.0,
        .oxygen = 99.0,
        .selected_slot = 99,
    };
    data.slots[0] = .{ .item_id = 9999, .count = 10 };
    data.craft_grid[0] = .{ .item_id = 65535, .count = 1 };

    _ = applyState(&data, &player, &cam, &inv, &cursor, &slot, &wear);
    try std.testing.expect(inv.slots[0].isEmpty());
    try std.testing.expect(inv.craft_grid[0].isEmpty());
    try std.testing.expectEqual(@as(f32, 20.0), player.health);
    try std.testing.expectEqual(@as(f32, 0.0), player.hunger);
    try std.testing.expectEqual(@as(f32, 0.0), player.saturation);
    try std.testing.expectEqual(@as(f32, 15.0), player.oxygen);
    try std.testing.expectEqual(@as(usize, inventory_mod.Inventory.HOTBAR_SIZE - 1), slot);
    try std.testing.expectEqual(@as(f32, 1.55), cam.pitch);
}
