const std = @import("std");

pub const mega_tree_min_height: u8 = 20;
pub const mega_tree_max_height: u8 = 31;

pub const MegaJungleTreeGrowth = struct {
    can_grow: bool,
    trunk_height: u8,
};

/// Determines whether a northwest-aligned 2x2 sapling cluster can grow.
/// Available clearance selects the tallest allowed height, capped at 31 blocks.
pub fn canGrowMega2x2JungleTree(
    saplings_2x2_northwest_aligned: [4]bool,
    clearance_height_blocks: u8,
    northwest_adjacent_clear: bool,
) MegaJungleTreeGrowth {
    if (!saplings_2x2_northwest_aligned[0] or
        !saplings_2x2_northwest_aligned[1] or
        !saplings_2x2_northwest_aligned[2] or
        !saplings_2x2_northwest_aligned[3] or
        !northwest_adjacent_clear or
        clearance_height_blocks < mega_tree_min_height)
    {
        return .{ .can_grow = false, .trunk_height = 0 };
    }

    return .{
        .can_grow = true,
        .trunk_height = @min(clearance_height_blocks, mega_tree_max_height),
    };
}

pub const CocoaPodState = enum(u2) {
    stage_0_small_green = 0,
    stage_1_medium_tan = 1,
    stage_2_ripe_orange = 2,
};

pub fn canPlantCocoaPodOnSideFace(block_is_jungle_log_or_wood: bool, face_is_horizontal_cardinal: bool) bool {
    return block_is_jungle_log_or_wood and face_is_horizontal_cardinal;
}

pub fn harvestCocoaBeans(state: CocoaPodState) u8 {
    return if (state == .stage_2_ripe_orange) 3 else 1;
}

pub fn applyCocoaBoneMeal(state: CocoaPodState) CocoaPodState {
    return switch (state) {
        .stage_0_small_green => .stage_1_medium_tan,
        .stage_1_medium_tan, .stage_2_ripe_orange => .stage_2_ripe_orange,
    };
}

pub const OcelotTrustResult = struct {
    fled_away: bool,
    gained_trust: bool,
};

/// Roll values 0..2 model the one-in-three trust chance after a safe feeding.
pub fn tryGainOcelotTrust(
    player_moved_fast_or_rotated_sharply: bool,
    dist_within_6m: bool,
    fed_raw_cod_or_salmon: bool,
    roll_0_to_2: u2,
) OcelotTrustResult {
    if (player_moved_fast_or_rotated_sharply) return .{ .fled_away = true, .gained_trust = false };
    return .{
        .fled_away = false,
        .gained_trust = dist_within_6m and fed_raw_cod_or_salmon and roll_0_to_2 == 0,
    };
}

/// Hanging vines grow down only when the block below is air. String is non-air,
/// so it naturally stops downward growth.
pub fn canVineSpreadDownward(block_below_is_air: bool) bool {
    return block_below_is_air;
}

test "mega jungle tree requires all four saplings" {
    try std.testing.expect(canGrowMega2x2JungleTree(.{ true, true, true, true }, 20, true).can_grow);
    try std.testing.expect(!canGrowMega2x2JungleTree(.{ true, true, true, false }, 30, true).can_grow);
    try std.testing.expect(!canGrowMega2x2JungleTree(.{ false, true, true, true }, 30, true).can_grow);
}

test "mega jungle tree clearance and adjacent obstruction rules" {
    try std.testing.expect(!canGrowMega2x2JungleTree(.{ true, true, true, true }, 19, true).can_grow);
    try std.testing.expect(!canGrowMega2x2JungleTree(.{ true, true, true, true }, 31, false).can_grow);
    try std.testing.expect(!canGrowMega2x2JungleTree(.{ true, true, true, true }, 0, true).can_grow);
}

test "mega jungle tree height fits clearance and caps at 31" {
    try std.testing.expectEqual(@as(u8, 20), canGrowMega2x2JungleTree(.{ true, true, true, true }, 20, true).trunk_height);
    try std.testing.expectEqual(@as(u8, 27), canGrowMega2x2JungleTree(.{ true, true, true, true }, 27, true).trunk_height);
    try std.testing.expectEqual(@as(u8, 31), canGrowMega2x2JungleTree(.{ true, true, true, true }, 40, true).trunk_height);
    try std.testing.expectEqual(@as(u8, 0), canGrowMega2x2JungleTree(.{ true, true, true, true }, 19, true).trunk_height);
}

test "cocoa pods attach only to jungle wood horizontal sides" {
    try std.testing.expect(canPlantCocoaPodOnSideFace(true, true));
    try std.testing.expect(!canPlantCocoaPodOnSideFace(false, true));
    try std.testing.expect(!canPlantCocoaPodOnSideFace(true, false));
    try std.testing.expect(!canPlantCocoaPodOnSideFace(false, false));
}

test "cocoa pod states encode three growth stages" {
    try std.testing.expectEqual(@as(u2, 0), @intFromEnum(CocoaPodState.stage_0_small_green));
    try std.testing.expectEqual(@as(u2, 1), @intFromEnum(CocoaPodState.stage_1_medium_tan));
    try std.testing.expectEqual(@as(u2, 2), @intFromEnum(CocoaPodState.stage_2_ripe_orange));
}

test "cocoa pod ripening progresses by one stage with bone meal" {
    try std.testing.expectEqual(CocoaPodState.stage_1_medium_tan, applyCocoaBoneMeal(.stage_0_small_green));
    try std.testing.expectEqual(CocoaPodState.stage_2_ripe_orange, applyCocoaBoneMeal(.stage_1_medium_tan));
    try std.testing.expectEqual(CocoaPodState.stage_2_ripe_orange, applyCocoaBoneMeal(.stage_2_ripe_orange));
}

test "cocoa harvest yields three beans ripe and one unripe" {
    try std.testing.expectEqual(@as(u8, 1), harvestCocoaBeans(.stage_0_small_green));
    try std.testing.expectEqual(@as(u8, 1), harvestCocoaBeans(.stage_1_medium_tan));
    try std.testing.expectEqual(@as(u8, 3), harvestCocoaBeans(.stage_2_ripe_orange));
}

test "ocelot trusts slow approach and a successful feeding roll" {
    const result = tryGainOcelotTrust(false, true, true, 0);
    try std.testing.expect(!result.fled_away);
    try std.testing.expect(result.gained_trust);
}

test "ocelot flees sudden movement regardless of feeding" {
    const result = tryGainOcelotTrust(true, true, true, 0);
    try std.testing.expect(result.fled_away);
    try std.testing.expect(!result.gained_trust);
}

test "ocelot trust requires approaching within six meters" {
    const result = tryGainOcelotTrust(false, false, true, 0);
    try std.testing.expect(!result.fled_away);
    try std.testing.expect(!result.gained_trust);
}

test "ocelot trust requires raw cod or salmon" {
    const result = tryGainOcelotTrust(false, true, false, 0);
    try std.testing.expect(!result.gained_trust);
}

test "ocelot trust chance is one in three" {
    try std.testing.expect(tryGainOcelotTrust(false, true, true, 0).gained_trust);
    try std.testing.expect(!tryGainOcelotTrust(false, true, true, 1).gained_trust);
    try std.testing.expect(!tryGainOcelotTrust(false, true, true, 2).gained_trust);
}

test "vines hang downward into air without a backing wall" {
    try std.testing.expect(canVineSpreadDownward(true));
}

test "string or any non-air block stops hanging vine growth" {
    try std.testing.expect(!canVineSpreadDownward(false));
}
