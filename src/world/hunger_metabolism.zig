const std = @import("std");

pub const DifficultyMode = enum { easy, normal, hard, peaceful };

pub const ExhaustionActivity = enum {
    sprint_jump,
    jump,
    attack_melee,
    take_damage,
    swim_meter,
    sprint_meter,
    mine_block,
    natural_regen_1hp,
};

pub const MetabolismState = struct {
    food_level: u5 = 20,
    saturation: f32 = 5.0,
    exhaustion: f32 = 0.0,
    regen_timer: f32 = 0.0,
    starvation_timer: f32 = 0.0,
};

fn clampFoodLevel(state: *MetabolismState) void {
    state.food_level = @min(state.food_level, 20);
    state.saturation = @max(0.0, @min(state.saturation, @as(f32, @floatFromInt(state.food_level))));
}

fn applyExhaustion(state: *MetabolismState) void {
    while (state.exhaustion >= 4.0) {
        state.exhaustion -= 4.0;
        if (state.saturation > 0.0) {
            state.saturation = @max(0.0, state.saturation - 1.0);
        } else if (state.food_level > 0) {
            state.food_level -= 1;
        }
    }
    clampFoodLevel(state);
}

pub fn addActivityExhaustion(state: *MetabolismState, activity: ExhaustionActivity) void {
    const amount: f32 = switch (activity) {
        .sprint_jump => 0.20,
        .jump => 0.05,
        .attack_melee, .take_damage => 0.10,
        .swim_meter => 0.01,
        .sprint_meter => 0.10,
        .mine_block => 0.005,
        .natural_regen_1hp => 6.0,
    };
    state.exhaustion += amount;
    applyExhaustion(state);
}

fn canEatAtFull(food_shanks: u5, saturation_restored: f32) bool {
    // Values identify the four special foods accepted at a full food bar:
    // golden apples (4, 9.6), chorus fruit (4, 2.4), and honey bottles (6, 1.2).
    // Enchanted golden apples share the golden-apple nutrition values.
    return (food_shanks == 4 and (saturation_restored == 9.6 or saturation_restored == 2.4)) or
        (food_shanks == 6 and saturation_restored == 1.2);
}

pub fn eatFoodItem(state: *MetabolismState, food_shanks: u5, saturation_restored: f32) bool {
    clampFoodLevel(state);
    if (state.food_level == 20 and !canEatAtFull(food_shanks, saturation_restored)) return false;
    const restored: u6 = @as(u6, state.food_level) + @as(u6, food_shanks);
    state.food_level = @intCast(@min(restored, 20));
    state.saturation += saturation_restored;
    clampFoodLevel(state);
    return true;
}

pub const TickResult = struct { hp_delta: f32, can_sprint: bool };

pub fn tickMetabolismAndHealing(state: *MetabolismState, current_hp: f32, max_hp: f32, difficulty_mode: DifficultyMode, dt: f32) TickResult {
    clampFoodLevel(state);
    var hp_delta: f32 = 0.0;
    const can_sprint = state.food_level > 6;

    if (state.food_level == 20 and state.saturation > 0.0 and current_hp < max_hp) {
        state.regen_timer += dt;
        while (state.regen_timer >= 0.5 and current_hp + hp_delta < max_hp) {
            state.regen_timer -= 0.5;
            hp_delta += 1.0;
            addActivityExhaustion(state, .natural_regen_1hp);
        }
    } else if (state.food_level >= 18 and state.saturation == 0.0 and current_hp < max_hp) {
        state.regen_timer += dt;
        while (state.regen_timer >= 4.0 and current_hp + hp_delta < max_hp) {
            state.regen_timer -= 4.0;
            hp_delta += 1.0;
        }
    } else {
        state.regen_timer = 0.0;
    }

    if (state.food_level == 0 and difficulty_mode != .peaceful) {
        state.starvation_timer += dt;
        while (state.starvation_timer >= 4.0 and current_hp + hp_delta > starvationFloor(difficulty_mode)) {
            state.starvation_timer -= 4.0;
            hp_delta -= 1.0;
        }
    } else {
        state.starvation_timer = 0.0;
    }
    return .{ .hp_delta = hp_delta, .can_sprint = can_sprint };
}

fn starvationFloor(mode: DifficultyMode) f32 {
    return switch (mode) { .easy => 10.0, .normal => 1.0, .hard => 0.0, .peaceful => 0.0 };
}

test "defaults initialize a full food bar and hidden reserve" {
    const state = MetabolismState{};
    try std.testing.expectEqual(@as(u5, 20), state.food_level);
    try std.testing.expectEqual(@as(f32, 5.0), state.saturation);
    try std.testing.expectEqual(@as(f32, 0.0), state.exhaustion);
}

test "each activity adds its specified exhaustion" {
    const activities = [_]ExhaustionActivity{ .sprint_jump, .jump, .attack_melee, .take_damage, .swim_meter, .sprint_meter, .mine_block };
    const expected = [_]f32{ 0.20, 0.05, 0.10, 0.10, 0.01, 0.10, 0.005 };
    for (activities, expected) |activity, amount| {
        var state = MetabolismState{ .saturation = 20.0 };
        addActivityExhaustion(&state, activity);
        try std.testing.expectApproxEqAbs(amount, state.exhaustion, 0.0001);
    }
}

test "exhaustion rollover drains saturation one point" {
    var state = MetabolismState{ .saturation = 3.0, .exhaustion = 3.99 };
    addActivityExhaustion(&state, .jump);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), state.saturation, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.04), state.exhaustion, 0.0001);
}

test "exhaustion rollover drains food after reserve is empty" {
    var state = MetabolismState{ .food_level = 4, .saturation = 0.0, .exhaustion = 3.95 };
    addActivityExhaustion(&state, .jump);
    try std.testing.expectEqual(@as(u5, 3), state.food_level);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), state.exhaustion, 0.0001);
}

test "large exhaustion processes every rollover" {
    var state = MetabolismState{ .food_level = 10, .saturation = 2.0, .exhaustion = 7.0 };
    addActivityExhaustion(&state, .sprint_jump);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), state.saturation, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.2), state.exhaustion, 0.0001);
}

test "saturation is strictly clamped to food level" {
    var state = MetabolismState{ .food_level = 3, .saturation = 12.0 };
    addActivityExhaustion(&state, .mine_block);
    try std.testing.expectEqual(@as(f32, 3.0), state.saturation);
}

test "food restoration clamps food to twenty and saturation to food level" {
    var state = MetabolismState{ .food_level = 18, .saturation = 2.0 };
    try std.testing.expect(eatFoodItem(&state, 6, 10.0));
    try std.testing.expectEqual(@as(u5, 20), state.food_level);
    try std.testing.expectEqual(@as(f32, 12.0), state.saturation);
}

test "golden carrot adds six hunger and clamps 14.4 saturation" {
    var state = MetabolismState{ .food_level = 10, .saturation = 0.0 };
    try std.testing.expect(eatFoodItem(&state, 6, 14.4));
    try std.testing.expectEqual(@as(u5, 16), state.food_level);
    try std.testing.expectEqual(@as(f32, 14.4), state.saturation);
}

test "special foods may be eaten at full food level" {
    var apple = MetabolismState{};
    try std.testing.expect(eatFoodItem(&apple, 4, 9.6));
    var chorus = MetabolismState{};
    try std.testing.expect(eatFoodItem(&chorus, 4, 2.4));
    var honey = MetabolismState{};
    try std.testing.expect(eatFoodItem(&honey, 6, 1.2));
}

test "ordinary foods cannot be eaten at full food level" {
    var state = MetabolismState{};
    try std.testing.expect(!eatFoodItem(&state, 4, 4.8));
}

test "sprinting requires food level strictly above six" {
    var state = MetabolismState{ .food_level = 6 };
    try std.testing.expect(!tickMetabolismAndHealing(&state, 20, 20, .normal, 1.0).can_sprint);
    state.food_level = 7;
    try std.testing.expect(tickMetabolismAndHealing(&state, 20, 20, .normal, 1.0).can_sprint);
}

test "saturation rapid healing delivers one hp each half second" {
    var state = MetabolismState{ .saturation = 5.0 };
    try std.testing.expectEqual(@as(f32, 0.0), tickMetabolismAndHealing(&state, 10, 20, .normal, 0.49).hp_delta);
    const result = tickMetabolismAndHealing(&state, 10, 20, .normal, 0.01);
    try std.testing.expectEqual(@as(f32, 1.0), result.hp_delta);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), state.saturation, 0.0001);
}

test "standard full belly healing delivers one hp every four seconds" {
    var state = MetabolismState{ .food_level = 18, .saturation = 0.0 };
    try std.testing.expectEqual(@as(f32, 0.0), tickMetabolismAndHealing(&state, 10, 20, .normal, 3.99).hp_delta);
    try std.testing.expectEqual(@as(f32, 1.0), tickMetabolismAndHealing(&state, 10, 20, .normal, 0.01).hp_delta);
}

test "healing never exceeds max hp" {
    var state = MetabolismState{ .saturation = 5.0 };
    try std.testing.expectEqual(@as(f32, 1.0), tickMetabolismAndHealing(&state, 19, 20, .normal, 5.0).hp_delta);
}

test "starvation respects easy normal and hard floors" {
    const modes = [_]DifficultyMode{ .easy, .normal, .hard };
    const hp = [_]f32{ 10.0, 1.0, 0.0 };
    for (modes, hp) |mode, expected_hp| {
        var state = MetabolismState{ .food_level = 0, .saturation = 0.0 };
        const result = tickMetabolismAndHealing(&state, 11.0, 20.0, mode, 44.0);
        try std.testing.expectEqual(expected_hp - 11.0, result.hp_delta);
    }
}

test "peaceful difficulty does not starve" {
    var state = MetabolismState{ .food_level = 0, .saturation = 0.0 };
    try std.testing.expectEqual(@as(f32, 0.0), tickMetabolismAndHealing(&state, 5, 20, .peaceful, 20).hp_delta);
}
