const std = @import("std");

pub const max_tracked_copper: usize = 64;
pub const oxidation_stage_time: f32 = 45.0;

pub const OxidationStage = enum(u8) {
    clean = 0,
    exposed = 1,
    weathered = 2,
    oxidized = 3,
};

pub const CopperState = struct {
    x: i32,
    y: i32,
    z: i32,
    timer: f32 = 0.0,
    stage: OxidationStage = .clean,
    waxed: bool = false,
};

pub const spyglass_fov_multiplier: f32 = 0.25;
pub const spyglass_sensitivity_multiplier: f32 = 0.30;

pub fn nextStage(stage: OxidationStage) ?OxidationStage {
    return switch (stage) {
        .clean => .exposed,
        .exposed => .weathered,
        .weathered => .oxidized,
        .oxidized => null,
    };
}

pub fn prevStage(stage: OxidationStage) ?OxidationStage {
    return switch (stage) {
        .oxidized => .weathered,
        .weathered => .exposed,
        .exposed => .clean,
        .clean => null,
    };
}

pub fn tickOxidation(state: *CopperState, dt: f32) bool {
    if (state.waxed or state.stage == .oxidized) return false;
    state.timer += dt;
    if (state.timer >= oxidation_stage_time) {
        state.timer -= oxidation_stage_time;
        if (nextStage(state.stage)) |n| {
            state.stage = n;
        }
        return true;
    }
    return false;
}

pub fn applyWax(state: *CopperState) bool {
    if (state.waxed) return false;
    state.waxed = true;
    state.timer = 0.0;
    return true;
}

pub fn scrapeWithAxe(state: *CopperState) bool {
    if (state.waxed) {
        state.waxed = false;
        state.timer = 0.0;
        return true;
    }
    if (prevStage(state.stage)) |prev| {
        state.stage = prev;
        state.timer = 0.0;
        return true;
    }
    return false;
}

pub fn findCopper(items: []const CopperState, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, items.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const it = items[i];
        if (it.x == x and it.y == y and it.z == z) return i;
    }
    return null;
}

pub fn effectiveFov(base_fov: f32, is_scoping: bool) f32 {
    if (is_scoping) return base_fov * spyglass_fov_multiplier;
    return base_fov;
}

test "constants" {
    try std.testing.expectEqual(@as(usize, 64), max_tracked_copper);
    try std.testing.expectEqual(@as(f32, 45.0), oxidation_stage_time);
    try std.testing.expectEqual(@as(f32, 0.25), spyglass_fov_multiplier);
    try std.testing.expectEqual(@as(f32, 0.30), spyglass_sensitivity_multiplier);
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(OxidationStage.clean));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(OxidationStage.exposed));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(OxidationStage.weathered));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(OxidationStage.oxidized));
}

test "nextStage" {
    try std.testing.expectEqual(OxidationStage.exposed, nextStage(.clean).?);
    try std.testing.expectEqual(OxidationStage.weathered, nextStage(.exposed).?);
    try std.testing.expectEqual(OxidationStage.oxidized, nextStage(.weathered).?);
    try std.testing.expectEqual(@as(?OxidationStage, null), nextStage(.oxidized));
}

test "prevStage" {
    try std.testing.expectEqual(OxidationStage.weathered, prevStage(.oxidized).?);
    try std.testing.expectEqual(OxidationStage.exposed, prevStage(.weathered).?);
    try std.testing.expectEqual(OxidationStage.clean, prevStage(.exposed).?);
    try std.testing.expectEqual(@as(?OxidationStage, null), prevStage(.clean));
}

test "tickOxidation advances after stage time" {
    var s = CopperState{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!tickOxidation(&s, 44.0));
    try std.testing.expectEqual(OxidationStage.clean, s.stage);
    try std.testing.expect(tickOxidation(&s, 1.0));
    try std.testing.expectEqual(OxidationStage.exposed, s.stage);
    try std.testing.expectEqual(@as(f32, 0.0), s.timer);
}

test "tickOxidation carries remainder and eventually oxidizes" {
    var s = CopperState{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(tickOxidation(&s, 50.0));
    try std.testing.expectEqual(OxidationStage.exposed, s.stage);
    try std.testing.expectEqual(@as(f32, 5.0), s.timer);
    _ = tickOxidation(&s, oxidation_stage_time);
    _ = tickOxidation(&s, oxidation_stage_time);
    try std.testing.expectEqual(OxidationStage.oxidized, s.stage);
}

test "tickOxidation stops when oxidized" {
    var s = CopperState{ .x = 0, .y = 0, .z = 0, .stage = .oxidized };
    try std.testing.expect(!tickOxidation(&s, 1000.0));
    try std.testing.expectEqual(OxidationStage.oxidized, s.stage);
    try std.testing.expectEqual(@as(f32, 0.0), s.timer);
}

test "tickOxidation stops when waxed" {
    var s = CopperState{ .x = 0, .y = 0, .z = 0, .waxed = true };
    try std.testing.expect(!tickOxidation(&s, 1000.0));
    try std.testing.expectEqual(OxidationStage.clean, s.stage);
    try std.testing.expectEqual(@as(f32, 0.0), s.timer);
}

test "applyWax" {
    var s = CopperState{ .x = 0, .y = 0, .z = 0, .timer = 12.0 };
    try std.testing.expect(applyWax(&s));
    try std.testing.expect(s.waxed);
    try std.testing.expectEqual(@as(f32, 0.0), s.timer);
    try std.testing.expect(!applyWax(&s));
}

test "scrapeWithAxe removes wax first" {
    var s = CopperState{ .x = 0, .y = 0, .z = 0, .waxed = true, .timer = 3.0 };
    try std.testing.expect(scrapeWithAxe(&s));
    try std.testing.expect(!s.waxed);
    try std.testing.expectEqual(@as(f32, 0.0), s.timer);
    try std.testing.expectEqual(OxidationStage.clean, s.stage);
}

test "scrapeWithAxe regresses stage" {
    var s = CopperState{ .x = 0, .y = 0, .z = 0, .stage = .oxidized, .timer = 7.0 };
    try std.testing.expect(scrapeWithAxe(&s));
    try std.testing.expectEqual(OxidationStage.weathered, s.stage);
    try std.testing.expectEqual(@as(f32, 0.0), s.timer);
    try std.testing.expect(scrapeWithAxe(&s));
    try std.testing.expectEqual(OxidationStage.exposed, s.stage);
    try std.testing.expect(scrapeWithAxe(&s));
    try std.testing.expectEqual(OxidationStage.clean, s.stage);
    try std.testing.expect(!scrapeWithAxe(&s));
    try std.testing.expectEqual(OxidationStage.clean, s.stage);
}

test "findCopper" {
    var items = [_]CopperState{
        .{ .x = 1, .y = 2, .z = 3 },
        .{ .x = 4, .y = 5, .z = 6 },
        .{ .x = 7, .y = 8, .z = 9 },
    };
    try std.testing.expectEqual(@as(?usize, 1), findCopper(&items, items.len, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, 0), findCopper(&items, items.len, 1, 2, 3));
    try std.testing.expectEqual(@as(?usize, null), findCopper(&items, items.len, 0, 0, 0));
    try std.testing.expectEqual(@as(?usize, null), findCopper(&items, 1, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, null), findCopper(&items, 0, 1, 2, 3));
}

test "effectiveFov" {
    try std.testing.expectEqual(@as(f32, 70.0), effectiveFov(70.0, false));
    try std.testing.expectEqual(@as(f32, 17.5), effectiveFov(70.0, true));
    try std.testing.expectEqual(@as(f32, 0.0), effectiveFov(0.0, true));
}
