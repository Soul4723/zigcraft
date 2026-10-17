const std = @import("std");

pub const shield_durability: u16 = 336;
pub const shield_raise_warmup_seconds: f32 = 0.25;
pub const shield_disabled_seconds: f32 = 5.0;

pub const ShieldBlockState = struct {
    is_raising: bool = false,
    raise_timer: f32 = 0.0,
    disabled_cooldown: f32 = 0.0,
    durability: u16 = shield_durability,
};

pub const ShieldHitResult = struct {
    damage_taken_by_defender: f32,
    shield_disabled_5s: bool,
    shield_durability_cost: u16,
};

pub const ThornsResult = struct {
    triggered: bool,
    retaliation_damage: u3,
    extra_armor_durability_cost: u2,
};

/// Updates shield raise and axe-disable timers. Releasing the shield resets its
/// warmup, so every new right-click must be held for the full quarter-second.
pub fn tickShieldBlockState(state: *ShieldBlockState, dt: f32) void {
    if (state.is_raising) {
        state.raise_timer += @max(0.0, dt);
    } else {
        state.raise_timer = 0.0;
    }
    state.disabled_cooldown = @max(0.0, state.disabled_cooldown - @max(0.0, dt));
}

pub fn setShieldRaising(state: *ShieldBlockState, is_raising: bool) void {
    state.is_raising = is_raising;
    if (!is_raising) state.raise_timer = 0.0;
}

/// The shield covers the front horizontal hemisphere; the boundary itself is
/// not covered, matching the strict positive-dot-product rule.
pub fn isAttackWithinShieldArc(defender_look_xz: [2]f32, attack_source_delta_xz: [2]f32) bool {
    return defender_look_xz[0] * attack_source_delta_xz[0] +
        defender_look_xz[1] * attack_source_delta_xz[1] > 0.0;
}

/// Reflects an arrow back along its incoming path. Called by the projectile
/// integration layer only after `resolveShieldHit` confirms a shield block.
pub fn deflectArrowVelocity(incoming_velocity: [3]f32) [3]f32 {
    return .{ -incoming_velocity[0], -incoming_velocity[1], -incoming_velocity[2] };
}

pub fn resolveShieldHit(
    state: *ShieldBlockState,
    incoming_damage: f32,
    attacker_used_axe: bool,
    in_front_hemisphere: bool,
) ShieldHitResult {
    const active = state.is_raising and
        state.raise_timer >= shield_raise_warmup_seconds and
        state.disabled_cooldown == 0.0;
    if (!active or !in_front_hemisphere) {
        return .{
            .damage_taken_by_defender = incoming_damage,
            .shield_disabled_5s = false,
            .shield_durability_cost = 0,
        };
    }

    var durability_cost: u16 = 0;
    if (incoming_damage >= 3.0 and state.durability > 0) {
        const floored_damage = @floor(incoming_damage);
        const bounded_damage = @min(floored_damage, 65534.0);
        const requested_cost: u16 = 1 + @as(u16, @intFromFloat(bounded_damage));
        durability_cost = @min(requested_cost, state.durability);
        state.durability -= durability_cost;
    }

    if (attacker_used_axe) state.disabled_cooldown = shield_disabled_seconds;
    return .{
        .damage_taken_by_defender = 0.0,
        .shield_disabled_5s = attacker_used_axe,
        .shield_durability_cost = durability_cost,
    };
}

pub fn evaluateThornsRetaliation(thorns_level: u2, roll_0_to_99: u8, damage_roll_1_to_4: u3) ThornsResult {
    if (thorns_level == 0 or roll_0_to_99 >= @as(u8, thorns_level) * 15) {
        return .{ .triggered = false, .retaliation_damage = 0, .extra_armor_durability_cost = 0 };
    }
    return .{
        .triggered = true,
        .retaliation_damage = @max(1, @min(damage_roll_1_to_4, 4)),
        .extra_armor_durability_cost = 2,
    };
}

test "shield raise requires five 0.05 second ticks before blocking" {
    var state = ShieldBlockState{};
    setShieldRaising(&state, true);
    for (0..4) |_| tickShieldBlockState(&state, 0.05);
    try std.testing.expect(state.raise_timer < shield_raise_warmup_seconds);
    try std.testing.expectEqual(@as(f32, 8.0), resolveShieldHit(&state, 8.0, false, true).damage_taken_by_defender);
    tickShieldBlockState(&state, 0.05);
    try std.testing.expectEqual(@as(f32, 0.0), resolveShieldHit(&state, 8.0, false, true).damage_taken_by_defender);
}

test "releasing shield resets its raise warmup" {
    var state = ShieldBlockState{ .is_raising = true, .raise_timer = 0.25 };
    setShieldRaising(&state, false);
    try std.testing.expectEqual(@as(f32, 0.0), state.raise_timer);
    try std.testing.expectEqual(@as(f32, 5.0), resolveShieldHit(&state, 5.0, false, true).damage_taken_by_defender);
}

test "front hemisphere blocks and backstab bypasses" {
    try std.testing.expect(isAttackWithinShieldArc(.{ 0, 1 }, .{ 0, 1 }));
    try std.testing.expect(!isAttackWithinShieldArc(.{ 0, 1 }, .{ 0, -1 }));
    try std.testing.expect(!isAttackWithinShieldArc(.{ 0, 1 }, .{ 1, 0 }));
    var state = ShieldBlockState{ .is_raising = true, .raise_timer = 0.25 };
    try std.testing.expectEqual(@as(f32, 6.0), resolveShieldHit(&state, 6.0, false, false).damage_taken_by_defender);
}

test "front hemisphere is independent of attack type" {
    // Melee, projectile and explosion damage all use the same source-arc test.
    try std.testing.expect(isAttackWithinShieldArc(.{ 1, 0 }, .{ 2, 1 }));
    try std.testing.expect(isAttackWithinShieldArc(.{ 1, 0 }, .{ 0.1, -8 }));
    try std.testing.expect(!isAttackWithinShieldArc(.{ 1, 0 }, .{ -1, 0 }));
}

test "shield durability only costs on hits of at least three damage" {
    var state = ShieldBlockState{ .is_raising = true, .raise_timer = 0.25 };
    const small = resolveShieldHit(&state, 2.99, false, true);
    try std.testing.expectEqual(@as(u16, 0), small.shield_durability_cost);
    const threshold = resolveShieldHit(&state, 3.0, false, true);
    try std.testing.expectEqual(@as(u16, 4), threshold.shield_durability_cost);
    try std.testing.expectEqual(@as(u16, 332), state.durability);
}

test "shield durability cost floors damage and subtracts one extra point" {
    var state = ShieldBlockState{ .is_raising = true, .raise_timer = 0.25 };
    const hit = resolveShieldHit(&state, 7.9, false, true);
    try std.testing.expectEqual(@as(u16, 8), hit.shield_durability_cost);
    try std.testing.expectEqual(@as(u16, 328), state.durability);
}

test "shield durability cost cannot exceed remaining durability" {
    var state = ShieldBlockState{ .is_raising = true, .raise_timer = 0.25, .durability = 2 };
    const hit = resolveShieldHit(&state, 40.0, false, true);
    try std.testing.expectEqual(@as(u16, 2), hit.shield_durability_cost);
    try std.testing.expectEqual(@as(u16, 0), state.durability);
}

test "axe strike blocks current hit and starts five second disable" {
    var state = ShieldBlockState{ .is_raising = true, .raise_timer = 0.25 };
    const hit = resolveShieldHit(&state, 5.0, true, true);
    try std.testing.expectEqual(@as(f32, 0.0), hit.damage_taken_by_defender);
    try std.testing.expect(hit.shield_disabled_5s);
    try std.testing.expectEqual(@as(f32, 5.0), state.disabled_cooldown);
    try std.testing.expectEqual(@as(f32, 5.0), resolveShieldHit(&state, 5.0, false, true).damage_taken_by_defender);
}

test "axe lockout expires after one hundred 0.05 second ticks" {
    var state = ShieldBlockState{ .is_raising = true, .raise_timer = 0.25, .disabled_cooldown = 5.0 };
    for (0..99) |_| tickShieldBlockState(&state, 0.05);
    try std.testing.expect(state.disabled_cooldown > 0.0);
    tickShieldBlockState(&state, 0.05);
    try std.testing.expectEqual(@as(f32, 0.0), state.disabled_cooldown);
    try std.testing.expectEqual(@as(f32, 0.0), resolveShieldHit(&state, 5.0, false, true).damage_taken_by_defender);
}

test "axe behind defender does not trigger shield disable" {
    var state = ShieldBlockState{ .is_raising = true, .raise_timer = 0.25 };
    const hit = resolveShieldHit(&state, 5.0, true, false);
    try std.testing.expect(!hit.shield_disabled_5s);
    try std.testing.expectEqual(@as(f32, 0.0), state.disabled_cooldown);
}

test "arrows bounce back by reversing their velocity" {
    try std.testing.expectEqual([_]f32{ 1.5, -2.0, 4.0 }, deflectArrowVelocity(.{ -1.5, 2.0, -4.0 }));
}

test "Thorns I has a fifteen percent trigger chance" {
    try std.testing.expect(evaluateThornsRetaliation(1, 0, 1).triggered);
    try std.testing.expect(evaluateThornsRetaliation(1, 14, 4).triggered);
    try std.testing.expect(!evaluateThornsRetaliation(1, 15, 4).triggered);
    try std.testing.expect(!evaluateThornsRetaliation(1, 99, 4).triggered);
}

test "Thorns II has a thirty percent trigger chance" {
    try std.testing.expect(evaluateThornsRetaliation(2, 0, 1).triggered);
    try std.testing.expect(evaluateThornsRetaliation(2, 29, 4).triggered);
    try std.testing.expect(!evaluateThornsRetaliation(2, 30, 4).triggered);
}

test "Thorns III has a forty-five percent trigger chance" {
    try std.testing.expect(evaluateThornsRetaliation(3, 0, 1).triggered);
    try std.testing.expect(evaluateThornsRetaliation(3, 44, 4).triggered);
    try std.testing.expect(!evaluateThornsRetaliation(3, 45, 4).triggered);
}

test "triggered Thorns returns one to four damage and costs two durability" {
    for (1..5) |amount| {
        const result = evaluateThornsRetaliation(3, 0, @intCast(amount));
        try std.testing.expect(result.triggered);
        try std.testing.expectEqual(@as(u3, @intCast(amount)), result.retaliation_damage);
        try std.testing.expectEqual(@as(u2, 2), result.extra_armor_durability_cost);
    }
}

test "no Thorns has no retaliation or durability penalty" {
    const result = evaluateThornsRetaliation(0, 0, 4);
    try std.testing.expect(!result.triggered);
    try std.testing.expectEqual(@as(u3, 0), result.retaliation_damage);
    try std.testing.expectEqual(@as(u2, 0), result.extra_armor_durability_cost);
}
