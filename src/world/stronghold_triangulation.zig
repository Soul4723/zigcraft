const std = @import("std");

pub const EYE_FLIGHT_DISTANCE: f32 = 12.0;
pub const EYE_VERTICAL_FLIGHT: f32 = 4.0;
pub const UNDERGROUND_DIVE_RADIUS: f32 = 16.0;
pub const EYE_HOVER_SECONDS: f32 = 3.0;
pub const END_PORTAL_FRAME_COUNT: usize = 12;

pub const EyeThrowResult = struct {
    hover_target_pos: [3]f32,
    yaw_rad: f32,
    shattered_on_drop: bool,
};

/// Tracks the three-second hover before returning the eye's drop outcome.
pub const EyeFlightState = struct {
    result: EyeThrowResult,
    hover_remaining_seconds: f32 = EYE_HOVER_SECONDS,

    /// Returns null while hovering, then whether the eye shattered on drop.
    pub fn tick(self: *EyeFlightState, dt: f32) ?bool {
        self.hover_remaining_seconds = @max(0.0, self.hover_remaining_seconds - @max(0.0, dt));
        if (self.hover_remaining_seconds > 0.0) return null;
        return self.result.shattered_on_drop;
    }
};

/// Aim an Eye toward the stronghold; yaw uses the usual X/Z unit direction
/// `(cos(yaw), sin(yaw))`. Near the target the eye dives toward the portal room.
pub fn throwEyeOfEnder(thrower_pos: [3]f32, stronghold_pos: [3]f32, shatter_roll_0_to_4: u8) EyeThrowResult {
    const dx = stronghold_pos[0] - thrower_pos[0];
    const dz = stronghold_pos[2] - thrower_pos[2];
    const horizontal_distance = @sqrt(dx * dx + dz * dz);
    const yaw = if (horizontal_distance == 0.0) 0.0 else std.math.atan2(dz, dx);
    const flight = @min(EYE_FLIGHT_DISTANCE, horizontal_distance);
    const scale = if (horizontal_distance == 0.0) 0.0 else flight / horizontal_distance;
    const vertical = if (horizontal_distance <= UNDERGROUND_DIVE_RADIUS) -EYE_VERTICAL_FLIGHT else EYE_VERTICAL_FLIGHT;
    return .{
        .hover_target_pos = .{ thrower_pos[0] + dx * scale, thrower_pos[1] + vertical, thrower_pos[2] + dz * scale },
        .yaw_rad = yaw,
        .shattered_on_drop = shatter_roll_0_to_4 == 0,
    };
}

/// Intersect two forward rays. Parallel or backward-only intersections are rejected.
pub fn triangulateStrongholdFromTwoThrows(pos1_xz: [2]f32, yaw1_rad: f32, pos2_xz: [2]f32, yaw2_rad: f32) ?[2]f32 {
    const d1 = [2]f32{ @cos(yaw1_rad), @sin(yaw1_rad) };
    const d2 = [2]f32{ @cos(yaw2_rad), @sin(yaw2_rad) };
    const det = d1[0] * d2[1] - d1[1] * d2[0];
    if (@abs(det) < 0.000001) return null;
    const delta = [2]f32{ pos2_xz[0] - pos1_xz[0], pos2_xz[1] - pos1_xz[1] };
    const t1 = (delta[0] * d2[1] - delta[1] * d2[0]) / det;
    const t2 = (delta[0] * d1[1] - delta[1] * d1[0]) / det;
    if (t1 < 0.0 or t2 < 0.0) return null;
    return .{ pos1_xz[0] + t1 * d1[0], pos1_xz[1] + t1 * d1[1] };
}

/// End portal ring with optional natural eyes; generation rolls use 0..9, with 0
/// representing the 10% pre-fill chance. `insertEye` returns true on activation.
pub const EndPortalRingState = struct {
    frames_filled: [END_PORTAL_FRAME_COUNT]bool = [_]bool{false} ** END_PORTAL_FRAME_COUNT,

    pub fn generated(rolls_0_to_9: [END_PORTAL_FRAME_COUNT]u8) EndPortalRingState {
        var state = EndPortalRingState{};
        for (rolls_0_to_9, 0..) |roll, i| state.frames_filled[i] = roll == 0;
        return state;
    }

    pub fn insertEye(self: *EndPortalRingState, frame_index: usize) bool {
        if (frame_index >= END_PORTAL_FRAME_COUNT or self.frames_filled[frame_index]) return self.isLit();
        self.frames_filled[frame_index] = true;
        return self.isLit();
    }

    pub fn isLit(self: *const EndPortalRingState) bool {
        for (self.frames_filled) |filled| if (!filled) return false;
        return true;
    }
};

pub const InfestedStoneBreakResult = struct {
    spawned_silverfish: bool,
    awakened_nearby_silverfish_count: u8,
};

/// Silk Touch safely yields the ordinary block. A surviving spawned silverfish
/// awakens every nearby dormant silverfish; a one-hit kill prevents the cascade.
pub fn resolveInfestedStoneBreak(mined_with_silk_touch: bool, killed_silverfish_in_one_hit: bool, nearby_infested_blocks: u8) InfestedStoneBreakResult {
    if (mined_with_silk_touch) return .{ .spawned_silverfish = false, .awakened_nearby_silverfish_count = 0 };
    return .{
        .spawned_silverfish = true,
        .awakened_nearby_silverfish_count = if (killed_silverfish_in_one_hit) 0 else nearby_infested_blocks,
    };
}

test "eye flies exactly twelve horizontal blocks toward target" {
    const result = throwEyeOfEnder(.{ 0, 64, 0 }, .{ 100, 20, 0 }, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 12), result.hover_target_pos[0], 0.0001);
    try std.testing.expectEqual(@as(f32, 64 + 4), result.hover_target_pos[1]);
    try std.testing.expectEqual(@as(f32, 0), result.hover_target_pos[2]);
}

test "eye aims diagonally at stronghold" {
    const result = throwEyeOfEnder(.{ 1, 50, 2 }, .{ 101, 0, 102 }, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 12 / @sqrt(@as(f32, 2))), result.hover_target_pos[0] - 1, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 12 / @sqrt(@as(f32, 2))), result.hover_target_pos[2] - 2, 0.0001);
}

test "eye dives when within sixteen horizontal blocks" {
    const result = throwEyeOfEnder(.{ 0, 40, 0 }, .{ 10, 0, 0 }, 2);
    try std.testing.expectEqual(@as(f32, 36), result.hover_target_pos[1]);
}

test "eye dives at exact underground radius boundary" {
    const result = throwEyeOfEnder(.{ 0, 40, 0 }, .{ 16, 0, 0 }, 2);
    try std.testing.expectEqual(@as(f32, 36), result.hover_target_pos[1]);
}

test "eye climbs beyond underground radius" {
    const result = throwEyeOfEnder(.{ 0, 40, 0 }, .{ 16.01, 0, 0 }, 2);
    try std.testing.expectEqual(@as(f32, 44), result.hover_target_pos[1]);
}

test "eye yaw uses X Z direction" {
    const result = throwEyeOfEnder(.{ 0, 64, 0 }, .{ 0, 0, 10 }, 2);
    try std.testing.expectApproxEqAbs(std.math.pi / 2.0, result.yaw_rad, 0.0001);
}

test "eye shatters on roll zero" {
    try std.testing.expect(throwEyeOfEnder(.{ 0, 0, 0 }, .{ 20, 0, 0 }, 0).shattered_on_drop);
}

test "eye survives rolls one through four" {
    for (1..5) |roll| try std.testing.expect(!throwEyeOfEnder(.{ 0, 0, 0 }, .{ 20, 0, 0 }, @intCast(roll)).shattered_on_drop);
}

test "eye at target has finite origin target result" {
    const result = throwEyeOfEnder(.{ 2, 8, 3 }, .{ 2, 0, 3 }, 1);
    try std.testing.expectEqual([3]f32{ 2, 4, 3 }, result.hover_target_pos);
}

test "eye hovers for three seconds before dropping reusable item" {
    var flight = EyeFlightState{ .result = throwEyeOfEnder(.{ 0, 0, 0 }, .{ 30, 0, 0 }, 4) };
    try std.testing.expectEqual(@as(f32, 3.0), flight.hover_remaining_seconds);
    try std.testing.expect(flight.tick(2.9) == null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), flight.hover_remaining_seconds, 0.00001);
    try std.testing.expectEqual(false, flight.tick(0.1).?);
}

test "eye hover expiry reports shatter roll result" {
    var flight = EyeFlightState{ .result = throwEyeOfEnder(.{ 0, 0, 0 }, .{ 30, 0, 0 }, 0) };
    try std.testing.expectEqual(true, flight.tick(3.0).?);
}

test "two throws triangulate a forward ray intersection" {
    const hit = triangulateStrongholdFromTwoThrows(.{ 0, 0 }, 0, .{ 10, -10 }, std.math.pi / 2.0);
    try std.testing.expect(hit != null);
    try std.testing.expectApproxEqAbs(@as(f32, 10), hit.?[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), hit.?[1], 0.0001);
}

test "triangulation supports arbitrary intersecting headings" {
    const hit = triangulateStrongholdFromTwoThrows(.{ -4, 3 }, std.math.pi / 4.0, .{ 8, 3 }, 3 * std.math.pi / 4.0);
    try std.testing.expect(hit != null);
    try std.testing.expectApproxEqAbs(@as(f32, 2), hit.?[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 9), hit.?[1], 0.0001);
}

test "parallel rays return null" {
    try std.testing.expect(triangulateStrongholdFromTwoThrows(.{ 0, 0 }, 0, .{ 0, 1 }, 0) == null);
}

test "backward intersection is rejected" {
    try std.testing.expect(triangulateStrongholdFromTwoThrows(.{ 0, 0 }, 0, .{ -1, 1 }, std.math.pi / 2.0) == null);
}

test "generated End portal ring has ten percent roll chance" {
    const state = EndPortalRingState.generated([_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 9 });
    try std.testing.expect(state.frames_filled[0]);
    try std.testing.expect(!state.frames_filled[1]);
    try std.testing.expect(state.frames_filled[10]);
    try std.testing.expect(!state.isLit());
}

test "End portal activates only when twelfth frame receives eye" {
    var state = EndPortalRingState{};
    for (0..11) |i| try std.testing.expect(!state.insertEye(i));
    try std.testing.expect(state.insertEye(11));
    try std.testing.expect(state.isLit());
}

test "duplicate or invalid eye insertion cannot alter an incomplete ring" {
    var state = EndPortalRingState{};
    try std.testing.expect(!state.insertEye(0));
    try std.testing.expect(!state.insertEye(0));
    try std.testing.expect(!state.insertEye(12));
    try std.testing.expectEqual(@as(usize, 1), filledFrameCount(&state));
}

fn filledFrameCount(state: *const EndPortalRingState) usize {
    var count: usize = 0;
    for (state.frames_filled) |filled| if (filled) { count += 1; };
    return count;
}

test "all naturally filled frames represent a lit portal" {
    const state = EndPortalRingState.generated([_]u8{0} ** END_PORTAL_FRAME_COUNT);
    try std.testing.expect(state.isLit());
}

test "Silk Touch prevents silverfish spawn and awakening" {
    const result = resolveInfestedStoneBreak(true, false, 12);
    try std.testing.expect(!result.spawned_silverfish);
    try std.testing.expectEqual(@as(u8, 0), result.awakened_nearby_silverfish_count);
}

test "breaking infested stone spawns one silverfish without nearby blocks" {
    const result = resolveInfestedStoneBreak(false, true, 0);
    try std.testing.expect(result.spawned_silverfish);
    try std.testing.expectEqual(@as(u8, 0), result.awakened_nearby_silverfish_count);
}

test "one-hit silverfish kill prevents swarm cascade" {
    const result = resolveInfestedStoneBreak(false, true, 37);
    try std.testing.expect(result.spawned_silverfish);
    try std.testing.expectEqual(@as(u8, 0), result.awakened_nearby_silverfish_count);
}

test "nonlethal silverfish awakens every nearby infested block" {
    const result = resolveInfestedStoneBreak(false, false, 37);
    try std.testing.expect(result.spawned_silverfish);
    try std.testing.expectEqual(@as(u8, 37), result.awakened_nearby_silverfish_count);
}
