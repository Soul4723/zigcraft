const std = @import("std");

/// Time spent at each oxidation stage before advancing to the next stage.
pub const oxidation_stage_time: f32 = 45.0;
/// Copper golems look for another copper button after this interval.
pub const button_search_interval: f32 = 1.0;

pub const OxidationStage = enum(u8) {
    unoxidized = 0,
    exposed = 1,
    weathered = 2,
    oxidized_statue = 3,
};

pub const CopperGolemState = struct {
    oxidation_stage: OxidationStage = .unoxidized,
    is_waxed: bool = false,
    oxidation_timer: f32 = 0.0,
    button_search_cooldown: f32 = 0.0,
    held_item_id: u16 = 0,
    held_item_count: u8 = 0,
    statue_pose: u2 = 0,
};

pub const CopperGolemTickResult = struct {
    pressed_copper_button: bool,
    became_statue: bool,
};

/// A copper golem is summoned by a copper block, carved pumpkin, and
/// lightning rod stacked from bottom to top.
pub fn canSummonCopperGolem(
    bottom_is_copper_block: bool,
    middle_is_carved_pumpkin: bool,
    top_is_lightning_rod: bool,
) bool {
    return bottom_is_copper_block and middle_is_carved_pumpkin and top_is_lightning_rod;
}

fn nextStage(stage: OxidationStage) ?OxidationStage {
    return switch (stage) {
        .unoxidized => .exposed,
        .exposed => .weathered,
        .weathered => .oxidized_statue,
        .oxidized_statue => null,
    };
}

/// Returns the comparator output emitted by a frozen statue, or zero while
/// the golem is active. The four poses therefore produce signals 1 through 4.
pub fn statueComparatorSignal(state: CopperGolemState) u4 {
    if (state.oxidation_stage != .oxidized_statue) return 0;
    return @as(u4, state.statue_pose) + 1;
}

/// Alias useful to callers that describe the output as a signal rather than
/// a comparator reading.
pub const getStatueComparatorSignal = statueComparatorSignal;

/// Scraping with an axe wakes a statue and removes one oxidation stage. Wax
/// is removed first, matching ordinary copper scraping behavior.
pub fn scrapeWithAxe(state: *CopperGolemState) bool {
    if (state.is_waxed) {
        state.is_waxed = false;
        state.oxidation_timer = 0.0;
        return true;
    }
    if (state.oxidation_stage == .oxidized_statue) {
        state.oxidation_stage = .weathered;
        state.oxidation_timer = 0.0;
        return true;
    }
    return false;
}

pub const scrapeCopperGolemWithAxe = scrapeWithAxe;

/// Advance oxidation and button searching. Lightning completely de-oxidizes
/// a statue and returns it to an active, unoxidized golem.
pub fn tickCopperGolem(
    state: *CopperGolemState,
    dt: f32,
    struck_by_lightning: bool,
) CopperGolemTickResult {
    var result = CopperGolemTickResult{ .pressed_copper_button = false, .became_statue = false };

    if (struck_by_lightning and state.oxidation_stage == .oxidized_statue) {
        state.oxidation_stage = .unoxidized;
        state.oxidation_timer = 0.0;
        state.statue_pose = 0;
    }

    if (state.oxidation_stage != .oxidized_statue) {
        if (!state.is_waxed and dt > 0.0) {
            state.oxidation_timer += dt;
            while (state.oxidation_timer >= oxidation_stage_time) {
                state.oxidation_timer -= oxidation_stage_time;
                if (nextStage(state.oxidation_stage)) |next| {
                    state.oxidation_stage = next;
                    if (next == .oxidized_statue) {
                        // Pose is deterministic and stable for a given held
                        // item, while still allowing all four poses to occur.
                        const pose_seed = @as(u32, state.held_item_id) + state.held_item_count;
                        state.statue_pose = @truncate(pose_seed % 4);
                        result.became_statue = true;
                        break;
                    }
                } else break;
            }
        }

        if (dt > 0.0) {
            state.button_search_cooldown -= dt;
            if (state.button_search_cooldown <= 0.0) {
                result.pressed_copper_button = true;
                state.button_search_cooldown = button_search_interval;
            }
        }
    }

    return result;
}

/// Copper chests accept any item when empty, otherwise only the sample item.
pub fn canSortItemIntoCopperChest(
    golem_item_id: u16,
    chest_sample_item_id: u16,
    chest_is_empty: bool,
) bool {
    return chest_is_empty or golem_item_id == chest_sample_item_id;
}

test "copper golem totem accepts the complete structure" {
    try std.testing.expect(canSummonCopperGolem(true, true, true));
}

test "totem rejects missing copper block" {
    try std.testing.expect(!canSummonCopperGolem(false, true, true));
}

test "totem rejects non carved pumpkin" {
    try std.testing.expect(!canSummonCopperGolem(true, false, true));
}

test "totem rejects missing lightning rod" {
    try std.testing.expect(!canSummonCopperGolem(true, true, false));
}

test "oxidation advances one stage after forty five seconds" {
    var state = CopperGolemState{};
    const result = tickCopperGolem(&state, oxidation_stage_time, false);
    try std.testing.expectEqual(OxidationStage.exposed, state.oxidation_stage);
    try std.testing.expect(!result.became_statue);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.oxidation_timer, 0.001);
}

test "oxidation carries remainder" {
    var state = CopperGolemState{};
    _ = tickCopperGolem(&state, 50.0, false);
    try std.testing.expectEqual(OxidationStage.exposed, state.oxidation_stage);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), state.oxidation_timer, 0.001);
}

test "oxidation reaches frozen statue" {
    var state = CopperGolemState{};
    const result = tickCopperGolem(&state, oxidation_stage_time * 3.0, false);
    try std.testing.expect(result.became_statue);
    try std.testing.expectEqual(OxidationStage.oxidized_statue, state.oxidation_stage);
}

test "waxing prevents oxidation" {
    var state = CopperGolemState{ .is_waxed = true };
    _ = tickCopperGolem(&state, oxidation_stage_time * 4.0, false);
    try std.testing.expectEqual(OxidationStage.unoxidized, state.oxidation_stage);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.oxidation_timer, 0.001);
}

test "statue stops oxidizing" {
    var state = CopperGolemState{ .oxidation_stage = .oxidized_statue };
    const result = tickCopperGolem(&state, 1000.0, false);
    try std.testing.expect(!result.became_statue);
    try std.testing.expectEqual(OxidationStage.oxidized_statue, state.oxidation_stage);
}

test "lightning revives statue" {
    var state = CopperGolemState{ .oxidation_stage = .oxidized_statue, .statue_pose = 3 };
    _ = tickCopperGolem(&state, 0.0, true);
    try std.testing.expectEqual(OxidationStage.unoxidized, state.oxidation_stage);
    try std.testing.expectEqual(@as(u2, 0), state.statue_pose);
}

test "axe scraping revives statue" {
    var state = CopperGolemState{ .oxidation_stage = .oxidized_statue };
    try std.testing.expect(scrapeWithAxe(&state));
    try std.testing.expectEqual(OxidationStage.weathered, state.oxidation_stage);
}

test "axe scraping removes wax before changing stage" {
    var state = CopperGolemState{ .oxidation_stage = .weathered, .is_waxed = true };
    try std.testing.expect(scrapeWithAxe(&state));
    try std.testing.expect(!state.is_waxed);
    try std.testing.expectEqual(OxidationStage.weathered, state.oxidation_stage);
}

test "statue poses emit comparator signals one through four" {
    var pose: usize = 0;
    while (pose < 4) : (pose += 1) {
        const state = CopperGolemState{ .oxidation_stage = .oxidized_statue, .statue_pose = @intCast(pose) };
        try std.testing.expectEqual(@as(u4, @intCast(pose)) + 1, statueComparatorSignal(state));
    }
}

test "active golem emits no statue comparator signal" {
    try std.testing.expectEqual(@as(u4, 0), statueComparatorSignal(CopperGolemState{}));
}

test "button is pressed when search cooldown expires" {
    var state = CopperGolemState{};
    const result = tickCopperGolem(&state, 0.1, false);
    try std.testing.expect(result.pressed_copper_button);
    try std.testing.expectApproxEqAbs(button_search_interval, state.button_search_cooldown, 0.001);
}

test "button search cooldown delays subsequent presses" {
    var state = CopperGolemState{};
    _ = tickCopperGolem(&state, 0.1, false);
    try std.testing.expect(!tickCopperGolem(&state, 0.5, false).pressed_copper_button);
    try std.testing.expect(tickCopperGolem(&state, 0.5, false).pressed_copper_button);
}

test "statues do not press buttons" {
    var state = CopperGolemState{ .oxidation_stage = .oxidized_statue };
    try std.testing.expect(!tickCopperGolem(&state, 2.0, false).pressed_copper_button);
}

test "empty copper chest accepts every item" {
    try std.testing.expect(canSortItemIntoCopperChest(12, 99, true));
}

test "copper chest accepts matching item" {
    try std.testing.expect(canSortItemIntoCopperChest(12, 12, false));
}

test "copper chest rejects mismatched item" {
    try std.testing.expect(!canSortItemIntoCopperChest(12, 13, false));
}
