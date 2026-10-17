const std = @import("std");

/// Computes movement speed as a fraction of normal walking speed.
/// Swift Sneak adds 0.15 to the 0.30 sneaking baseline for each level.
pub fn computeSwiftSneakSpeedMultiplier(is_sneaking_or_crawling: bool, swift_sneak_level: u2) f32 {
    if (!is_sneaking_or_crawling) return 1.0;
    return 0.30 + 0.15 * @as(f32, @floatFromInt(@min(swift_sneak_level, 3)));
}

/// Returns whether an action can activate a sculk sensor or shrieker.
/// The supplied flags describe the action/environment; wool surfaces and
/// wool placement/breaking suppress vibrations, while eating remains audible.
pub fn doesActionEmitSculkVibration(
    action_is_sneak_step: bool,
    walking_on_wool_or_carpet: bool,
    placing_or_breaking_wool: bool,
    eating_food: bool,
) bool {
    if (action_is_sneak_step or walking_on_wool_or_carpet or placing_or_breaking_wool) return false;
    return eating_food;
}

/// Models the comparator's two documented input paths to the concealed door.
/// `calibrated_note_pitch` is retained for the circuit interface; it does not
/// participate in the stated unlock condition.
pub fn evaluateAncientCityBasementDoorPuzzle(
    lectern_page_signal: u4,
    target_block_hit_signal: u4,
    calibrated_note_pitch: u5,
) bool {
    _ = calibrated_note_pitch;
    return lectern_page_signal == 8 or target_block_hit_signal >= 10;
}

/// Immutable properties for Ancient City's reinforced deepslate structure.
pub const ReinforcedDeepslateProps = struct {
    pub const hardness: f32 = 55.0;
    pub const mine_time_seconds: f32 = 82.5;
    pub const silk_touch_obtainable: bool = false;
    pub const piston_movable: bool = false;
    pub const wither_destroyable: bool = false;
    pub const ender_dragon_destroyable: bool = false;
};

test "Swift Sneak I, II, and III raise crouch speed by 0.15 each" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.45), computeSwiftSneakSpeedMultiplier(true, 1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), computeSwiftSneakSpeedMultiplier(true, 2), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), computeSwiftSneakSpeedMultiplier(true, 3), 0.0001);
}

test "ordinary crouch and crawling baseline is 0.30x" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), computeSwiftSneakSpeedMultiplier(true, 0), 0.0001);
}

test "Swift Sneak does not alter walking speed" {
    try std.testing.expectEqual(@as(f32, 1.0), computeSwiftSneakSpeedMultiplier(false, 0));
    try std.testing.expectEqual(@as(f32, 1.0), computeSwiftSneakSpeedMultiplier(false, 3));
}

test "sneak steps are silent" {
    try std.testing.expect(!doesActionEmitSculkVibration(true, false, false, false));
}

test "walking on wool is silent" {
    try std.testing.expect(!doesActionEmitSculkVibration(false, true, false, false));
}

test "jumping on wool represented by wool surface is silent" {
    try std.testing.expect(!doesActionEmitSculkVibration(false, true, false, false));
}

test "walking on carpet is silent" {
    try std.testing.expect(!doesActionEmitSculkVibration(false, true, false, false));
}

test "placing wool is silent" {
    try std.testing.expect(!doesActionEmitSculkVibration(false, false, true, false));
}

test "breaking wool is silent" {
    try std.testing.expect(!doesActionEmitSculkVibration(false, false, true, false));
}

test "eating without wool occlusion emits vibration" {
    try std.testing.expect(doesActionEmitSculkVibration(false, false, false, true));
}

test "wool surface suppresses eating vibration" {
    try std.testing.expect(!doesActionEmitSculkVibration(false, true, false, true));
}

test "lectern page signal 8 opens secret basement door" {
    try std.testing.expect(evaluateAncientCityBasementDoorPuzzle(8, 0, 0));
}

test "target block hit signal of at least 10 opens basement door" {
    try std.testing.expect(evaluateAncientCityBasementDoorPuzzle(0, 10, 0));
    try std.testing.expect(evaluateAncientCityBasementDoorPuzzle(0, 15, 31));
}

test "nonmatching comparator puzzle signals keep door locked" {
    try std.testing.expect(!evaluateAncientCityBasementDoorPuzzle(7, 9, 8));
}

test "reinforced deepslate has specified hardness and mining time" {
    try std.testing.expectEqual(@as(f32, 55.0), ReinforcedDeepslateProps.hardness);
    try std.testing.expectEqual(@as(f32, 82.5), ReinforcedDeepslateProps.mine_time_seconds);
}

test "reinforced deepslate cannot be obtained with silk touch" {
    try std.testing.expect(!ReinforcedDeepslateProps.silk_touch_obtainable);
}

test "reinforced deepslate is immovable by pistons" {
    try std.testing.expect(!ReinforcedDeepslateProps.piston_movable);
}

test "reinforced deepslate is immune to wither and dragon destruction" {
    try std.testing.expect(!ReinforcedDeepslateProps.wither_destroyable);
    try std.testing.expect(!ReinforcedDeepslateProps.ender_dragon_destroyable);
}
