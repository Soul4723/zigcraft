const std = @import("std");

pub const powder_snow_shake_start_seconds: f32 = 7.0;
pub const powder_snow_conversion_seconds: f32 = 22.0;
pub const powder_snow_shake_start_ticks: u32 = 140;
pub const powder_snow_conversion_ticks: u32 = 440;
pub const skeleton_max_health: f32 = 20.0;
pub const wither_skeleton_height_blocks: f32 = 2.4;
pub const stray_slowness_seconds: f32 = 30.0;
pub const stray_slowness_speed_multiplier: f32 = 0.85;
pub const bogged_poison_seconds: f32 = 4.0;
pub const wither_skeleton_fire_seconds: f32 = 5.0;

pub const SkeletonVariant = enum {
    standard_skeleton,
    icy_stray,
    mossy_bogged,
    nether_wither_skeleton,
};

/// State for a single skeleton's continuous exposure to powder snow. Leaving the
/// snow or changing away from a standard skeleton resets the conversion timer.
pub const SkeletonFreezeConversionState = struct {
    variant: SkeletonVariant = .standard_skeleton,
    elapsed_seconds: f32 = 0.0,
    elapsed_ticks: u32 = 0,
    shaking: bool = false,
    converted: bool = false,
    health: f32 = skeleton_max_health,
};

/// Advances the powder-snow timer. Returns true exactly on the tick that the
/// skeleton converts; dt is elapsed seconds (normally 1/20 per game tick).
pub fn tickSkeletonPowderSnowConversion(
    state: *SkeletonFreezeConversionState,
    dt: f32,
    inside_powder_snow: bool,
) bool {
    if (state.converted) return false;
    if (!inside_powder_snow or state.variant != .standard_skeleton or dt <= 0.0) {
        if (!inside_powder_snow or state.variant != .standard_skeleton) {
            state.elapsed_seconds = 0.0;
            state.elapsed_ticks = 0;
            state.shaking = false;
        }
        return false;
    }

    const tick_delta: u32 = @intFromFloat(@round(dt * 20.0));
    state.elapsed_ticks +|= tick_delta;
    state.elapsed_seconds = @min(powder_snow_conversion_seconds, state.elapsed_seconds + dt);
    if (state.elapsed_ticks >= powder_snow_shake_start_ticks) state.shaking = true;
    if (state.elapsed_ticks >= powder_snow_conversion_ticks) {
        state.variant = .icy_stray;
        state.health = skeleton_max_health;
        state.converted = true;
        state.shaking = false;
        return true;
    }
    return false;
}

pub fn isStrayImmuneToPowderSnowFreeze() bool {
    return true;
}

pub const SkeletonArrowPayload = struct {
    base_damage: f32,
    slowness_seconds: f32,
    poison_seconds: f32,
    fire_seconds: f32,
    /// Multiplier to movement speed while the arrow's effect is active.
    movement_speed_multiplier: f32 = 1.0,
};

pub fn computeSkeletonArrowPayload(variant: SkeletonVariant) SkeletonArrowPayload {
    return switch (variant) {
        .standard_skeleton => .{
            .base_damage = 2.0,
            .slowness_seconds = 0.0,
            .poison_seconds = 0.0,
            .fire_seconds = 0.0,
        },
        .icy_stray => .{
            .base_damage = 2.0,
            .slowness_seconds = stray_slowness_seconds,
            .poison_seconds = 0.0,
            .fire_seconds = 0.0,
            .movement_speed_multiplier = stray_slowness_speed_multiplier,
        },
        .mossy_bogged => .{
            .base_damage = 2.0,
            .slowness_seconds = 0.0,
            .poison_seconds = bogged_poison_seconds,
            .fire_seconds = 0.0,
        },
        .nether_wither_skeleton => .{
            .base_damage = 2.0,
            .slowness_seconds = 0.0,
            .poison_seconds = 0.0,
            .fire_seconds = wither_skeleton_fire_seconds,
        },
    };
}

/// Strays drop Slowness Arrows when their arrow kills a player.
pub fn shouldDropSlownessArrowsOnPlayerKill(variant: SkeletonVariant, killed_player: bool) bool {
    return variant == .icy_stray and killed_player;
}

pub fn canEntityPassUnderCeiling(variant: SkeletonVariant, ceiling_clearance_blocks: f32) bool {
    return switch (variant) {
        .nether_wither_skeleton => ceiling_clearance_blocks >= wither_skeleton_height_blocks,
        else => true,
    };
}

pub fn shouldSkeletonFleeWolf(wolf_nearby: bool) bool {
    return wolf_nearby;
}

pub const SkeletonWeapon = enum { bow, stone_sword };

/// Wither Skeletons use a stone sword instead of a bow; other variants keep bows.
pub fn skeletonWeapon(variant: SkeletonVariant) SkeletonWeapon {
    return if (variant == .nether_wither_skeleton) .stone_sword else .bow;
}

test "powder snow conversion starts shaking at 7 seconds and converts at 22" {
    var state = SkeletonFreezeConversionState{};
    var i: u32 = 0;
    while (i < powder_snow_shake_start_ticks) : (i += 1) {
        try std.testing.expect(!tickSkeletonPowderSnowConversion(&state, 0.05, true));
    }
    try std.testing.expect(state.shaking);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), state.elapsed_seconds, 0.0001);
    try std.testing.expectEqual(SkeletonVariant.standard_skeleton, state.variant);

    i = 0;
    while (i < 299) : (i += 1) {
        try std.testing.expect(!tickSkeletonPowderSnowConversion(&state, 0.05, true));
    }
    try std.testing.expect(tickSkeletonPowderSnowConversion(&state, 0.05, true));
    try std.testing.expectEqual(SkeletonVariant.icy_stray, state.variant);
    try std.testing.expectEqual(@as(f32, 20.0), state.health);
    try std.testing.expect(state.converted);
    try std.testing.expect(!state.shaking);
}

test "conversion timer resets when skeleton leaves powder snow" {
    var state = SkeletonFreezeConversionState{};
    _ = tickSkeletonPowderSnowConversion(&state, 6.0, true);
    _ = tickSkeletonPowderSnowConversion(&state, 0.05, false);
    try std.testing.expectEqual(@as(f32, 0.0), state.elapsed_seconds);
    try std.testing.expect(!state.shaking);
}

test "converted strays are immune to powder snow freeze" {
    try std.testing.expect(isStrayImmuneToPowderSnowFreeze());
    var state = SkeletonFreezeConversionState{ .variant = .icy_stray };
    try std.testing.expect(!tickSkeletonPowderSnowConversion(&state, 100.0, true));
    try std.testing.expectEqual(SkeletonVariant.icy_stray, state.variant);
}

test "standard skeleton arrows have no status effects" {
    const payload = computeSkeletonArrowPayload(.standard_skeleton);
    try std.testing.expectEqual(@as(f32, 2.0), payload.base_damage);
    try std.testing.expectEqual(@as(f32, 0.0), payload.slowness_seconds);
    try std.testing.expectEqual(@as(f32, 0.0), payload.poison_seconds);
    try std.testing.expectEqual(@as(f32, 0.0), payload.fire_seconds);
}

test "stray fires 30-second Slowness I arrows with 15 percent slow" {
    const payload = computeSkeletonArrowPayload(.icy_stray);
    try std.testing.expectEqual(@as(f32, 30.0), payload.slowness_seconds);
    try std.testing.expectEqual(@as(f32, 0.85), payload.movement_speed_multiplier);
    try std.testing.expectEqual(@as(f32, 0.0), payload.poison_seconds);
}

test "stray drops Slowness Arrows on player kills only" {
    try std.testing.expect(shouldDropSlownessArrowsOnPlayerKill(.icy_stray, true));
    try std.testing.expect(!shouldDropSlownessArrowsOnPlayerKill(.icy_stray, false));
    try std.testing.expect(!shouldDropSlownessArrowsOnPlayerKill(.standard_skeleton, true));
}

test "Bogged arrows apply four seconds of Poison I" {
    const payload = computeSkeletonArrowPayload(.mossy_bogged);
    try std.testing.expectEqual(@as(f32, 4.0), payload.poison_seconds);
    try std.testing.expectEqual(@as(f32, 0.0), payload.slowness_seconds);
}

test "Wither Skeleton bow arrows burn for five seconds" {
    const payload = computeSkeletonArrowPayload(.nether_wither_skeleton);
    try std.testing.expectEqual(@as(f32, 5.0), payload.fire_seconds);
}

test "Wither Skeleton switches bow for stone sword" {
    try std.testing.expectEqual(SkeletonWeapon.stone_sword, skeletonWeapon(.nether_wither_skeleton));
    try std.testing.expectEqual(SkeletonWeapon.bow, skeletonWeapon(.standard_skeleton));
    try std.testing.expectEqual(SkeletonWeapon.bow, skeletonWeapon(.icy_stray));
}

test "Wither Skeleton cannot pass under a two-block doorway" {
    try std.testing.expect(!canEntityPassUnderCeiling(.nether_wither_skeleton, 2.0));
    try std.testing.expect(!canEntityPassUnderCeiling(.nether_wither_skeleton, 2.39));
    try std.testing.expect(canEntityPassUnderCeiling(.nether_wither_skeleton, 2.4));
}

test "normal skeletons and player-height entities pass low ceilings" {
    try std.testing.expect(canEntityPassUnderCeiling(.standard_skeleton, 2.0));
    try std.testing.expect(canEntityPassUnderCeiling(.standard_skeleton, 1.99));
    try std.testing.expect(canEntityPassUnderCeiling(.icy_stray, 2.0));
}

test "all skeleton variants flee when a wolf is nearby" {
    inline for (.{ .standard_skeleton, .icy_stray, .mossy_bogged, .nether_wither_skeleton }) |variant| {
        _ = variant;
        try std.testing.expect(shouldSkeletonFleeWolf(true));
        try std.testing.expect(!shouldSkeletonFleeWolf(false));
    }
}

test "nonstandard variants do not convert in powder snow" {
    inline for (.{ .icy_stray, .mossy_bogged, .nether_wither_skeleton }) |variant| {
        var state = SkeletonFreezeConversionState{ .variant = variant };
        try std.testing.expect(!tickSkeletonPowderSnowConversion(&state, 22.0, true));
        try std.testing.expectEqual(variant, state.variant);
    }
}

test "negative time does not advance powder snow conversion" {
    var state = SkeletonFreezeConversionState{};
    try std.testing.expect(!tickSkeletonPowderSnowConversion(&state, -1.0, true));
    try std.testing.expectEqual(@as(f32, 0.0), state.elapsed_seconds);
}
