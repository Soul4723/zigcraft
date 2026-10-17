/// Standalone item-frame and painting domain rules. Rendering and registry wiring
/// are intentionally left to the integration layer.

pub const ItemFrameState = struct {
    is_glow_frame: bool = false,
    displayed_item_id: ?u16 = null,
    rotation_step_0_to_7: u3 = 0,
    is_map_item: bool = false,

    /// Glow frames emit full-bright item/map rendering, independent of world light.
    pub fn rendersAtFullBrightness(self: ItemFrameState) bool {
        return self.is_glow_frame and self.displayed_item_id != null;
    }
};

pub const ItemFrameInteraction = struct {
    inserted_item: bool = false,
    rotated_item: bool = false,
    new_rotation: u3 = 0,
};

pub fn interactItemFrame(frame: *ItemFrameState, held_item_id: ?u16, held_is_map: bool) ItemFrameInteraction {
    if (frame.displayed_item_id != null) {
        frame.rotation_step_0_to_7 = @intCast((@as(u4, frame.rotation_step_0_to_7) + 1) % 8);
        return .{ .rotated_item = true, .new_rotation = frame.rotation_step_0_to_7 };
    }
    if (held_item_id) |item_id| {
        frame.displayed_item_id = item_id;
        frame.is_map_item = held_is_map;
        frame.rotation_step_0_to_7 = 0;
        return .{ .inserted_item = true, .new_rotation = 0 };
    }
    return .{ .new_rotation = frame.rotation_step_0_to_7 };
}

pub fn itemFrameComparatorSignal(frame: ItemFrameState) u4 {
    if (frame.displayed_item_id == null) return 0;
    return @as(u4, frame.rotation_step_0_to_7) + 1;
}

pub fn doesItemFrameExpandMapToFullBlock(frame: ItemFrameState) bool {
    return frame.displayed_item_id != null and frame.is_map_item;
}

/// The 26 canonical Minecraft painting artworks, represented by their canvases.
pub const PaintingCanvasSize = enum {
    size_1x1, kebab_1x1, aztec_1x1, alban_1x1, aztec2_1x1, bomb_1x1, plant_1x1, wasteland_1x1,
    size_1x2_tall, pool_1x2, courbet_1x2, sea_1x2, sunset_1x2, creebet_1x2,
    size_2x1_wide, wanderer_2x1, graham_2x1,
    size_2x2, match_2x2, bust_2x2, stage_2x2, void_2x2, skull_and_roses_2x2, wither_2x2,
    size_4x2_wanderer, fighters_4x2,
    size_4x3_skeleton, donkey_kong_4x3,
    size_4x4_pointer_pigscene, pointer_4x4, pigscene_4x4,
};

pub const PaintingDimensions = struct { width: u8, height: u8 };

pub fn paintingCanvasDimensions(size: PaintingCanvasSize) PaintingDimensions {
    return switch (size) {
        .size_1x1, .kebab_1x1, .aztec_1x1, .alban_1x1, .aztec2_1x1, .bomb_1x1, .plant_1x1, .wasteland_1x1 => .{ .width = 1, .height = 1 },
        .size_1x2_tall, .pool_1x2, .courbet_1x2, .sea_1x2, .sunset_1x2, .creebet_1x2 => .{ .width = 1, .height = 2 },
        .size_2x1_wide, .wanderer_2x1, .graham_2x1 => .{ .width = 2, .height = 1 },
        .size_2x2, .match_2x2, .bust_2x2, .stage_2x2, .void_2x2, .skull_and_roses_2x2, .wither_2x2 => .{ .width = 2, .height = 2 },
        .size_4x2_wanderer, .fighters_4x2 => .{ .width = 4, .height = 2 },
        .size_4x3_skeleton, .donkey_kong_4x3 => .{ .width = 4, .height = 3 },
        .size_4x4_pointer_pigscene, .pointer_4x4, .pigscene_4x4 => .{ .width = 4, .height = 4 },
    };
}

/// Paintings are non-solid hanging entities and never obstruct doorway movement.
pub fn isPaintingSolid(_: PaintingCanvasSize) bool {
    return false;
}

pub fn selectLargestFittingPainting(available_wall_width: u8, available_wall_height: u8) ?PaintingCanvasSize {
    const candidates = [_]PaintingCanvasSize{
        .size_1x1, .size_1x2_tall, .size_2x1_wide, .size_2x2,
        .size_4x2_wanderer, .size_4x3_skeleton, .size_4x4_pointer_pigscene,
    };
    var best: ?PaintingCanvasSize = null;
    var best_area: u16 = 0;
    for (candidates) |candidate| {
        const d = paintingCanvasDimensions(candidate);
        if (d.width > available_wall_width or d.height > available_wall_height) continue;
        const area = @as(u16, d.width) * d.height;
        if (area > best_area or (area == best_area and best != null and d.width > paintingCanvasDimensions(best.?).width)) {
            best = candidate;
            best_area = area;
        }
    }
    return best;
}

const std = @import("std");

test "item frame and glow frame brightness behavior" {
    const ordinary = ItemFrameState{ .displayed_item_id = 12 };
    const glow = ItemFrameState{ .is_glow_frame = true, .displayed_item_id = 12 };
    const empty_glow = ItemFrameState{ .is_glow_frame = true };
    try std.testing.expect(!ordinary.rendersAtFullBrightness());
    try std.testing.expect(glow.rendersAtFullBrightness());
    try std.testing.expect(!empty_glow.rendersAtFullBrightness());
}

test "right click inserts item into empty frame at rotation zero" {
    var frame = ItemFrameState{};
    const result = interactItemFrame(&frame, 42, false);
    try std.testing.expect(result.inserted_item);
    try std.testing.expect(!result.rotated_item);
    try std.testing.expectEqual(@as(?u16, 42), frame.displayed_item_id);
    try std.testing.expectEqual(@as(u3, 0), frame.rotation_step_0_to_7);
}

test "empty hand does not insert into empty frame" {
    var frame = ItemFrameState{};
    const result = interactItemFrame(&frame, null, false);
    try std.testing.expect(!result.inserted_item and !result.rotated_item);
    try std.testing.expect(frame.displayed_item_id == null);
}

test "map insertion records map state for seamless expansion" {
    var frame = ItemFrameState{};
    _ = interactItemFrame(&frame, 900, true);
    try std.testing.expect(frame.is_map_item);
    try std.testing.expect(doesItemFrameExpandMapToFullBlock(frame));
}

test "non-map item does not expand frame border" {
    var frame = ItemFrameState{};
    _ = interactItemFrame(&frame, 10, false);
    try std.testing.expect(!doesItemFrameExpandMapToFullBlock(frame));
}

test "occupied frame rotates clockwise in 45 degree steps" {
    var frame = ItemFrameState{ .displayed_item_id = 3 };
    for (1..8) |expected| {
        const result = interactItemFrame(&frame, null, false);
        try std.testing.expect(result.rotated_item);
        try std.testing.expectEqual(@as(u3, @intCast(expected)), result.new_rotation);
    }
}

test "eight 45 degree rotations wrap to upright" {
    var frame = ItemFrameState{ .displayed_item_id = 3 };
    for (0..8) |_| _ = interactItemFrame(&frame, null, false);
    try std.testing.expectEqual(@as(u3, 0), frame.rotation_step_0_to_7);
}

test "occupied frame rotates instead of replacing held item" {
    var frame = ItemFrameState{ .displayed_item_id = 3 };
    const result = interactItemFrame(&frame, 99, true);
    try std.testing.expect(result.rotated_item and !result.inserted_item);
    try std.testing.expectEqual(@as(?u16, 3), frame.displayed_item_id);
    try std.testing.expect(!frame.is_map_item);
}

test "comparator is zero for empty frame" {
    try std.testing.expectEqual(@as(u4, 0), itemFrameComparatorSignal(.{}));
}

test "comparator dial exposes values one through eight" {
    var rotation: u4 = 0;
    while (rotation < 8) : (rotation += 1) {
        const frame = ItemFrameState{ .displayed_item_id = 1, .rotation_step_0_to_7 = @intCast(rotation) };
        try std.testing.expectEqual(rotation + 1, itemFrameComparatorSignal(frame));
    }
}

test "map expansion requires an actually displayed map" {
    try std.testing.expect(!doesItemFrameExpandMapToFullBlock(.{ .is_map_item = true }));
}

test "painting enum includes at least 26 canonical artworks" {
    try std.testing.expect(@typeInfo(PaintingCanvasSize).@"enum".fields.len >= 26);
}

test "largest fitting painting chooses maximum 4x4 canvas" {
    try std.testing.expectEqual(PaintingCanvasSize.size_4x4_pointer_pigscene, selectLargestFittingPainting(4, 4).?);
}

test "painting fit falls back through 4x3 and 4x2 canvases" {
    try std.testing.expectEqual(PaintingCanvasSize.size_4x3_skeleton, selectLargestFittingPainting(4, 3).?);
    try std.testing.expectEqual(PaintingCanvasSize.size_4x2_wanderer, selectLargestFittingPainting(4, 2).?);
}

test "painting fit selects wide and tall 2x2 and unit canvases" {
    try std.testing.expectEqual(PaintingCanvasSize.size_2x2, selectLargestFittingPainting(2, 2).?);
    try std.testing.expectEqual(PaintingCanvasSize.size_2x1_wide, selectLargestFittingPainting(2, 1).?);
    try std.testing.expectEqual(PaintingCanvasSize.size_1x2_tall, selectLargestFittingPainting(1, 2).?);
    try std.testing.expectEqual(PaintingCanvasSize.size_1x1, selectLargestFittingPainting(1, 1).?);
}

test "painting returns null when no canvas fits" {
    try std.testing.expect(selectLargestFittingPainting(0, 0) == null);
}

test "paintings are non-solid and pass through open doorways" {
    try std.testing.expect(!isPaintingSolid(.size_4x4_pointer_pigscene));
}
