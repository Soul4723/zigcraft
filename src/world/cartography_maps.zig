/// Cartography-table map operations and map-canvas coordinates.

pub const MapZoomLevel = enum(u3) {
    level_0_128m = 0,
    level_1_256m = 1,
    level_2_512m = 2,
    level_3_1024m = 3,
    level_4_2048m = 4,

    pub fn blocksPerSide(self: MapZoomLevel) u16 {
        return @as(u16, 128) << @intFromEnum(self);
    }

    pub fn blocksPerPixel(self: MapZoomLevel) u8 {
        return @as(u8, 1) << @intFromEnum(self);
    }
};

pub const MapBannerWaypoint = struct {
    x: i32 = 0,
    z: i32 = 0,
    color: u4 = 0,
};

pub const CartographyMapState = struct {
    center_x: i32,
    center_z: i32,
    zoom: MapZoomLevel = .level_0_128m,
    is_locked: bool = false,
    has_tracking_compass: bool = true,
    waypoints: [8]MapBannerWaypoint = [_]MapBannerWaypoint{.{}} ** 8,
    waypoint_count: u4 = 0,
};

pub const CartographyIngredient = enum { paper, glass_pane, empty_map, compass };

/// Returns whether the table operation is applicable. For `.empty_map`, the
/// unchanged state is the source to copy into the output map by the caller.
pub fn applyCartographyTableOperation(state: *CartographyMapState, ingredient: CartographyIngredient) bool {
    switch (ingredient) {
        .paper => {
            if (state.is_locked or state.zoom == .level_4_2048m) return false;
            state.zoom = @enumFromInt(@intFromEnum(state.zoom) + 1);
            return true;
        },
        .glass_pane => {
            if (state.is_locked) return false;
            state.is_locked = true;
            return true;
        },
        .empty_map => return true,
        .compass => {
            if (state.has_tracking_compass) return false;
            state.has_tracking_compass = true;
            return true;
        },
    }
}

/// Toggles a banner marker if it lies inside the map's square world bounds.
pub fn toggleBannerMapWaypoint(state: *CartographyMapState, banner_x: i32, banner_z: i32, banner_color: u4) bool {
    const half: i64 = state.zoom.blocksPerSide() / 2;
    const dx: i64 = @as(i64, banner_x) - state.center_x;
    const dz: i64 = @as(i64, banner_z) - state.center_z;
    if (dx < -half or dx >= half or dz < -half or dz >= half) return false;

    const count: usize = state.waypoint_count;
    for (0..count) |i| {
        const wp = state.waypoints[i];
        if (wp.x == banner_x and wp.z == banner_z) {
            for (i..count - 1) |j| state.waypoints[j] = state.waypoints[j + 1];
            state.waypoint_count -= 1;
            return true;
        }
    }
    if (count == state.waypoints.len) return false;
    state.waypoints[count] = .{ .x = banner_x, .z = banner_z, .color = banner_color };
    state.waypoint_count += 1;
    return true;
}

pub const ExplorerMapCursor = struct {
    on_map_canvas: bool,
    pixel_u: u7,
    pixel_v: u7,
    off_edge_clamped: bool,
};

/// Projects a world position onto the 128x128 map, clamping distant positions
/// to the nearest border pixel.
pub fn computeExplorerMapPlayerCursor(map: CartographyMapState, player_x: i32, player_z: i32) ExplorerMapCursor {
    const side: i64 = map.zoom.blocksPerSide();
    const half = @divTrunc(side, 2);
    const dx: i64 = @as(i64, player_x) - map.center_x;
    const dz: i64 = @as(i64, player_z) - map.center_z;
    const on_canvas = dx >= -half and dx < half and dz >= -half and dz < half;
    const scale: i64 = map.zoom.blocksPerPixel();
    const raw_u = @divFloor(dx + half, scale);
    const raw_v = @divFloor(dz + half, scale);
    const u = @min(127, @max(0, raw_u));
    const v = @min(127, @max(0, raw_v));
    return .{ .on_map_canvas = on_canvas, .pixel_u = @intCast(u), .pixel_v = @intCast(v), .off_edge_clamped = !on_canvas };
}

test "zoom levels cover 128 through 2048 blocks at matching pixel scales" {
    const sides = [_]u16{ 128, 256, 512, 1024, 2048 };
    const scales = [_]u8{ 1, 2, 4, 8, 16 };
    for (0..5) |i| {
        const level: MapZoomLevel = @enumFromInt(i);
        try @import("std").testing.expectEqual(sides[i], level.blocksPerSide());
        try @import("std").testing.expectEqual(scales[i], level.blocksPerPixel());
        try @import("std").testing.expectEqual(@as(u16, 128), level.blocksPerSide() / level.blocksPerPixel());
    }
}

const std = @import("std");

fn testMap() CartographyMapState { return .{ .center_x = 0, .center_z = 0 }; }

test "one paper zooms one tier and stops at maximum" {
    var m = testMap();
    for (0..4) |_| try std.testing.expect(applyCartographyTableOperation(&m, .paper));
    try std.testing.expectEqual(MapZoomLevel.level_4_2048m, m.zoom);
    try std.testing.expect(!applyCartographyTableOperation(&m, .paper));
}

test "paper cannot mutate a locked map" {
    var m = testMap(); m.is_locked = true;
    try std.testing.expect(!applyCartographyTableOperation(&m, .paper));
    try std.testing.expectEqual(MapZoomLevel.level_0_128m, m.zoom);
}

test "glass pane locks map permanently" {
    var m = testMap();
    try std.testing.expect(applyCartographyTableOperation(&m, .glass_pane));
    try std.testing.expect(m.is_locked);
    try std.testing.expect(!applyCartographyTableOperation(&m, .glass_pane));
}

test "locked map accepts copy operation without mutation" {
    var m = testMap(); m.is_locked = true; m.zoom = .level_3_1024m;
    const before = m;
    try std.testing.expect(applyCartographyTableOperation(&m, .empty_map));
    try std.testing.expectEqualDeep(before, m);
}

test "compass upgrades non locator map" {
    var m = testMap(); m.has_tracking_compass = false;
    try std.testing.expect(applyCartographyTableOperation(&m, .compass));
    try std.testing.expect(m.has_tracking_compass);
    try std.testing.expect(!applyCartographyTableOperation(&m, .compass));
}

test "banner waypoint can be added with color" {
    var m = testMap();
    try std.testing.expect(toggleBannerMapWaypoint(&m, 12, -9, 5));
    try std.testing.expectEqual(@as(u4, 1), m.waypoint_count);
    try std.testing.expectEqual(@as(u4, 5), m.waypoints[0].color);
}

test "banner waypoint toggles off when repeated" {
    var m = testMap();
    try std.testing.expect(toggleBannerMapWaypoint(&m, 12, -9, 5));
    try std.testing.expect(toggleBannerMapWaypoint(&m, 12, -9, 2));
    try std.testing.expectEqual(@as(u4, 0), m.waypoint_count);
}

test "banner waypoint bounds include lower edge and exclude upper edge" {
    var m = testMap();
    try std.testing.expect(toggleBannerMapWaypoint(&m, -64, 0, 1));
    try std.testing.expect(!toggleBannerMapWaypoint(&m, 64, 0, 1));
    try std.testing.expect(!toggleBannerMapWaypoint(&m, 0, -65, 1));
}

test "banner marker capacity is eight" {
    var m = testMap();
    for (0..8) |i| try std.testing.expect(toggleBannerMapWaypoint(&m, @intCast(i), 0, 0));
    try std.testing.expect(!toggleBannerMapWaypoint(&m, 9, 0, 0));
}

test "cursor projects center to canvas center" {
    const c = computeExplorerMapPlayerCursor(testMap(), 0, 0);
    try std.testing.expect(c.on_map_canvas);
    try std.testing.expectEqual(@as(u7, 64), c.pixel_u);
    try std.testing.expectEqual(@as(u7, 64), c.pixel_v);
}

test "cursor projects map bounds to edge pixels" {
    const c = computeExplorerMapPlayerCursor(testMap(), -64, 63);
    try std.testing.expectEqual(@as(u7, 0), c.pixel_u);
    try std.testing.expectEqual(@as(u7, 127), c.pixel_v);
    try std.testing.expect(c.on_map_canvas);
}

test "distant explorer cursor clamps to border" {
    const c = computeExplorerMapPlayerCursor(testMap(), 10000, -10000);
    try std.testing.expect(!c.on_map_canvas);
    try std.testing.expect(c.off_edge_clamped);
    try std.testing.expectEqual(@as(u7, 127), c.pixel_u);
    try std.testing.expectEqual(@as(u7, 0), c.pixel_v);
}

test "cursor scaling remains correct at highest zoom" {
    var m = testMap(); m.zoom = .level_4_2048m;
    const c = computeExplorerMapPlayerCursor(m, 16, -16);
    try std.testing.expectEqual(@as(u7, 65), c.pixel_u);
    try std.testing.expectEqual(@as(u7, 63), c.pixel_v);
}

test "waypoints are independently colored" {
    var m = testMap();
    try std.testing.expect(toggleBannerMapWaypoint(&m, 1, 1, 3));
    try std.testing.expect(toggleBannerMapWaypoint(&m, 2, 2, 12));
    try std.testing.expectEqual(@as(u4, 3), m.waypoints[0].color);
    try std.testing.expectEqual(@as(u4, 12), m.waypoints[1].color);
}
