const std = @import("std");

pub const DesertPyramidStepResult = struct {
    tnt_ignited: bool,
    chests_preserved: bool,
};

pub const DesertPyramidTrapState = struct {
    stone_pressure_plate_intact: bool = true,
    tnt_grid_3x3_count: u4 = 9,
    triggered: bool = false,
    fuse_timer: f32 = 4.0,
    chests_destroyed: bool = false,
    water_in_pit: bool = false,
};

/// Handles disarming the central plate or starting the pyramid's TNT fuse.
/// A triggered fuse advances only through `advanceDesertPyramidFuse`.
pub fn stepIntoDesertPyramidPit(
    state: *DesertPyramidTrapState,
    stepped_on_center_plate: bool,
    mined_plate_first: bool,
    water_placed_in_pit: bool,
) DesertPyramidStepResult {
    state.water_in_pit = state.water_in_pit or water_placed_in_pit;
    if (mined_plate_first and state.stone_pressure_plate_intact and !state.triggered) {
        state.stone_pressure_plate_intact = false;
        state.tnt_grid_3x3_count = 0;
        return .{ .tnt_ignited = false, .chests_preserved = true };
    }

    if (stepped_on_center_plate and state.stone_pressure_plate_intact and !state.triggered) {
        state.triggered = true;
        state.fuse_timer = 4.0;
        return .{ .tnt_ignited = true, .chests_preserved = true };
    }

    return .{ .tnt_ignited = false, .chests_preserved = !state.chests_destroyed };
}

/// Advances an armed fuse in seconds. Water protects the loot even when TNT detonates.
pub fn advanceDesertPyramidFuse(
    state: *DesertPyramidTrapState,
    delta_seconds: f32,
    water_placed_in_pit: bool,
) DesertPyramidStepResult {
    state.water_in_pit = state.water_in_pit or water_placed_in_pit;
    if (!state.triggered or state.chests_destroyed) {
        return .{ .tnt_ignited = false, .chests_preserved = !state.chests_destroyed };
    }

    state.fuse_timer = @max(0.0, state.fuse_timer - @max(0.0, delta_seconds));
    if (state.fuse_timer == 0.0 and !state.water_in_pit) {
        state.chests_destroyed = true;
    }
    return .{ .tnt_ignited = true, .chests_preserved = !state.chests_destroyed };
}

pub const JungleTempleLeverPuzzle = struct {
    levers: [3]bool = .{ false, false, false },
    step_progress: u2 = 0,
    solved: bool = false,
    treasure_chest_revealed: bool = false,
};

/// Applies the expected lever action. Lever indices are left=0, middle=1, right=2;
/// `down` is true for down and false for up. Incorrect moves reset the sequence.
pub fn toggleJungleTempleLever(
    puzzle: *JungleTempleLeverPuzzle,
    lever_index: u2,
    down: bool,
) bool {
    if (puzzle.solved) return true;

    const expected_index: u2 = switch (puzzle.step_progress) {
        0, 3 => 0,
        1, 2 => 2,
    };
    const expected_down = puzzle.step_progress < 2;
    if (lever_index != expected_index or down != expected_down) {
        puzzle.levers = .{ false, false, false };
        puzzle.step_progress = 0;
        return false;
    }

    puzzle.levers[lever_index] = down;
    if (puzzle.step_progress == 3) {
        puzzle.solved = true;
        puzzle.treasure_chest_revealed = true;
    } else {
        puzzle.step_progress += 1;
    }
    return puzzle.solved;
}

pub const JungleTripwireResult = struct {
    fired_arrow: bool,
    disarmed_safely: bool,
};

/// Shears disarm silently; walking into or breaking the string by hand fires once.
pub fn triggerJungleCorridorTripwire(
    walked_through_tripwire: bool,
    cut_with_shears: bool,
    broke_without_shears: bool,
    dispenser_arrows: *u8,
) JungleTripwireResult {
    if (cut_with_shears) return .{ .fired_arrow = false, .disarmed_safely = true };

    const triggered = walked_through_tripwire or broke_without_shears;
    if (triggered and dispenser_arrows.* > 0) {
        dispenser_arrows.* -= 1;
        return .{ .fired_arrow = true, .disarmed_safely = false };
    }
    return .{ .fired_arrow = false, .disarmed_safely = false };
}

test "desert pyramid starts armed with nine TNT and a four second fuse" {
    const state = DesertPyramidTrapState{};
    try std.testing.expect(state.stone_pressure_plate_intact);
    try std.testing.expectEqual(@as(u4, 9), state.tnt_grid_3x3_count);
    try std.testing.expect(!state.triggered);
    try std.testing.expectEqual(@as(f32, 4.0), state.fuse_timer);
    try std.testing.expect(!state.chests_destroyed);
}

test "stepping on the plate ignites all nine TNT" {
    var state = DesertPyramidTrapState{};
    const result = stepIntoDesertPyramidPit(&state, true, false, false);
    try std.testing.expect(result.tnt_ignited);
    try std.testing.expect(result.chests_preserved);
    try std.testing.expect(state.triggered);
    try std.testing.expectEqual(@as(u4, 9), state.tnt_grid_3x3_count);
}

test "plate trigger starts a four second fuse" {
    var state = DesertPyramidTrapState{};
    _ = stepIntoDesertPyramidPit(&state, true, false, false);
    try std.testing.expectEqual(@as(f32, 4.0), state.fuse_timer);
}

test "fuse does not destroy chests before expiration" {
    var state = DesertPyramidTrapState{};
    _ = stepIntoDesertPyramidPit(&state, true, false, false);
    const result = advanceDesertPyramidFuse(&state, 3.99, false);
    try std.testing.expect(result.chests_preserved);
    try std.testing.expect(!state.chests_destroyed);
}

test "expired dry fuse destroys the four loot chests" {
    var state = DesertPyramidTrapState{};
    _ = stepIntoDesertPyramidPit(&state, true, false, false);
    const result = advanceDesertPyramidFuse(&state, 4.0, false);
    try std.testing.expect(!result.chests_preserved);
    try std.testing.expect(state.chests_destroyed);
}

test "water in the pit preserves chests when the fuse expires" {
    var state = DesertPyramidTrapState{};
    _ = stepIntoDesertPyramidPit(&state, true, false, false);
    const result = advanceDesertPyramidFuse(&state, 4.0, true);
    try std.testing.expect(result.chests_preserved);
    try std.testing.expect(!state.chests_destroyed);
}

test "water present at plate trigger still preserves the chests" {
    var state = DesertPyramidTrapState{};
    const result = stepIntoDesertPyramidPit(&state, true, false, true);
    try std.testing.expect(result.tnt_ignited);
    const after_fuse = advanceDesertPyramidFuse(&state, 4.0, true);
    try std.testing.expect(after_fuse.chests_preserved);
}

test "mining the center plate first disarms all nine TNT" {
    var state = DesertPyramidTrapState{};
    const result = stepIntoDesertPyramidPit(&state, false, true, false);
    try std.testing.expect(!result.tnt_ignited);
    try std.testing.expect(result.chests_preserved);
    try std.testing.expect(!state.stone_pressure_plate_intact);
    try std.testing.expectEqual(@as(u4, 0), state.tnt_grid_3x3_count);
    try std.testing.expect(!state.triggered);
}

test "mining the plate prevents a later step from igniting TNT" {
    var state = DesertPyramidTrapState{};
    _ = stepIntoDesertPyramidPit(&state, false, true, false);
    const result = stepIntoDesertPyramidPit(&state, true, false, false);
    try std.testing.expect(!result.tnt_ignited);
    try std.testing.expectEqual(@as(u4, 0), state.tnt_grid_3x3_count);
}

test "fuse remains armed until all four seconds elapse" {
    var state = DesertPyramidTrapState{};
    _ = stepIntoDesertPyramidPit(&state, true, false, false);
    _ = advanceDesertPyramidFuse(&state, 1.5, false);
    try std.testing.expectEqual(@as(f32, 2.5), state.fuse_timer);
    _ = advanceDesertPyramidFuse(&state, 2.5, false);
    try std.testing.expect(state.chests_destroyed);
}

test "negative fuse delta does not accelerate the countdown" {
    var state = DesertPyramidTrapState{};
    _ = stepIntoDesertPyramidPit(&state, true, false, false);
    _ = advanceDesertPyramidFuse(&state, -1.0, false);
    try std.testing.expectEqual(@as(f32, 4.0), state.fuse_timer);
}

test "jungle puzzle begins with all levers raised" {
    const puzzle = JungleTempleLeverPuzzle{};
    try std.testing.expectEqual([3]bool{ false, false, false }, puzzle.levers);
    try std.testing.expectEqual(@as(u2, 0), puzzle.step_progress);
    try std.testing.expect(!puzzle.treasure_chest_revealed);
}

test "canonical jungle lever sequence reveals treasure" {
    var puzzle = JungleTempleLeverPuzzle{};
    try std.testing.expect(!toggleJungleTempleLever(&puzzle, 0, true));
    try std.testing.expect(!toggleJungleTempleLever(&puzzle, 2, true));
    try std.testing.expect(!toggleJungleTempleLever(&puzzle, 2, false));
    try std.testing.expect(toggleJungleTempleLever(&puzzle, 0, false));
    try std.testing.expect(puzzle.solved);
    try std.testing.expect(puzzle.treasure_chest_revealed);
}

test "wrong jungle lever action resets combination progress" {
    var puzzle = JungleTempleLeverPuzzle{};
    _ = toggleJungleTempleLever(&puzzle, 0, true);
    try std.testing.expect(!toggleJungleTempleLever(&puzzle, 1, true));
    try std.testing.expectEqual(@as(u2, 0), puzzle.step_progress);
    try std.testing.expectEqual([3]bool{ false, false, false }, puzzle.levers);
}

test "solved jungle puzzle remains solved" {
    var puzzle = JungleTempleLeverPuzzle{};
    _ = toggleJungleTempleLever(&puzzle, 0, true);
    _ = toggleJungleTempleLever(&puzzle, 2, true);
    _ = toggleJungleTempleLever(&puzzle, 2, false);
    _ = toggleJungleTempleLever(&puzzle, 0, false);
    try std.testing.expect(toggleJungleTempleLever(&puzzle, 1, true));
    try std.testing.expect(puzzle.treasure_chest_revealed);
}

test "shears silently disarm jungle tripwire" {
    var arrows: u8 = 4;
    const result = triggerJungleCorridorTripwire(false, true, false, &arrows);
    try std.testing.expect(!result.fired_arrow);
    try std.testing.expect(result.disarmed_safely);
    try std.testing.expectEqual(@as(u8, 4), arrows);
}

test "walking through tripwire fires a dispenser arrow" {
    var arrows: u8 = 4;
    const result = triggerJungleCorridorTripwire(true, false, false, &arrows);
    try std.testing.expect(result.fired_arrow);
    try std.testing.expect(!result.disarmed_safely);
    try std.testing.expectEqual(@as(u8, 3), arrows);
}

test "breaking tripwire without shears fires an arrow" {
    var arrows: u8 = 2;
    const result = triggerJungleCorridorTripwire(false, false, true, &arrows);
    try std.testing.expect(result.fired_arrow);
    try std.testing.expectEqual(@as(u8, 1), arrows);
}

test "tripwire does not fire twice after arrows are depleted" {
    var arrows: u8 = 0;
    const result = triggerJungleCorridorTripwire(true, false, false, &arrows);
    try std.testing.expect(!result.fired_arrow);
    try std.testing.expect(!result.disarmed_safely);
    try std.testing.expectEqual(@as(u8, 0), arrows);
}

test "shears take precedence if the tripwire is simultaneously walked through" {
    var arrows: u8 = 4;
    const result = triggerJungleCorridorTripwire(true, true, false, &arrows);
    try std.testing.expect(result.disarmed_safely);
    try std.testing.expect(!result.fired_arrow);
    try std.testing.expectEqual(@as(u8, 4), arrows);
}
