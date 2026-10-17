const std = @import("std");

pub const ZombieVariant = enum {
    desert_husk,
    standard_zombie,
    aquatic_drowned,
    zombie_villager,
};

pub const conversion_shake_seconds: f32 = 30.0;
pub const conversion_finish_seconds: f32 = 15.0;
pub const converted_zombie_health: f32 = 20.0;

pub const ZombieSubmersionState = struct {
    variant: ZombieVariant,
    head_submerged_timer: f32 = 0.0,
    is_shaking: bool = false,
};

pub const ZombieConversionResult = struct {
    converted: bool = false,
    new_variant: ZombieVariant,
    dropped_worn_armor: bool = false,
};

/// Tracks the two-stage conversion. The timer resets when the head leaves water;
/// after 30 seconds continuously submerged, shaking begins for the final 15.
pub fn tickZombieUnderwaterConversion(state: *ZombieSubmersionState, head_in_water: bool, dt: f32) ZombieConversionResult {
    if (state.variant != .desert_husk and state.variant != .standard_zombie) {
        state.head_submerged_timer = 0.0;
        state.is_shaking = false;
        return .{ .new_variant = state.variant };
    }
    if (!head_in_water or dt <= 0.0) {
        if (!head_in_water) {
            state.head_submerged_timer = 0.0;
            state.is_shaking = false;
        }
        return .{ .new_variant = state.variant };
    }

    state.head_submerged_timer += dt;
    state.is_shaking = state.head_submerged_timer >= conversion_shake_seconds;
    const conversion_threshold = conversion_shake_seconds + conversion_finish_seconds;
    if (state.head_submerged_timer + 0.0001 < conversion_threshold) {
        return .{ .new_variant = state.variant };
    }

    const next: ZombieVariant = if (state.variant == .desert_husk) .standard_zombie else .aquatic_drowned;
    state.variant = next;
    state.head_submerged_timer = 0.0;
    state.is_shaking = false;
    return .{ .converted = true, .new_variant = next, .dropped_worn_armor = true };
}

pub const HuskMechanics = struct {
    pub fn isHuskBurningInSunlight() bool {
        return false;
    }

    /// Hunger duration for a bare-hand hit; regional difficulty is floored.
    pub fn huskMeleeHungerDurationSeconds(regional_difficulty: f32) f32 {
        if (regional_difficulty <= 0.0) return 0.0;
        return 7.0 * @floor(regional_difficulty);
    }
};

pub const DrownedSpawnEquipment = struct {
    pub const trident_spawn_chance: f32 = 0.0625;
    pub const nautilus_shell_spawn_chance: f32 = 0.03;
    pub const nautilus_shell_drop_chance: f32 = 1.0;
    pub const trident_ranged_attack_interval_seconds: f32 = 1.5;
    pub const trident_melee_switch_distance: f32 = 3.0;

    pub fn hasTrident(random_roll: f32) bool {
        return random_roll >= 0.0 and random_roll < trident_spawn_chance;
    }

    pub fn hasNautilusShell(random_roll: f32) bool {
        return random_roll >= 0.0 and random_roll < nautilus_shell_spawn_chance;
    }

    /// Trident-wielding drowned switch to melee during daytime only when the
    /// player is close and not swimming.
    pub fn shouldUseMeleeDuringDay(player_distance: f32, player_is_swimming: bool) bool {
        return player_distance <= trident_melee_switch_distance and !player_is_swimming;
    }
};

pub const wooden_door_break_seconds: f32 = 12.0;

/// Returns true once a Zombie has broken a targeted wooden door on Hard.
/// Callers should pass false for iron/copper doors and fence gates.
pub fn tickHardModeZombieDoorBreak(is_hard_difficulty: bool, targeting_wooden_door: bool, break_progress_seconds: *f32, dt: f32) bool {
    if (!is_hard_difficulty or !targeting_wooden_door) {
        break_progress_seconds.* = 0.0;
        return false;
    }
    if (dt > 0.0) break_progress_seconds.* += dt;
    if (break_progress_seconds.* < wooden_door_break_seconds) return false;
    break_progress_seconds.* = wooden_door_break_seconds;
    return true;
}

test "Husk conversion waits through shake and finish phases then becomes zombie" {
    var state = ZombieSubmersionState{ .variant = .desert_husk };
    const first = tickZombieUnderwaterConversion(&state, true, 30.0);
    try std.testing.expect(!first.converted);
    try std.testing.expect(state.is_shaking);
    const second = tickZombieUnderwaterConversion(&state, true, 14.99);
    try std.testing.expect(!second.converted);
    const third = tickZombieUnderwaterConversion(&state, true, 0.01);
    try std.testing.expect(third.converted);
    try std.testing.expectEqual(ZombieVariant.standard_zombie, state.variant);
    try std.testing.expect(third.dropped_worn_armor);
}

test "standard zombie converts to drowned after two stages" {
    var state = ZombieSubmersionState{ .variant = .standard_zombie };
    _ = tickZombieUnderwaterConversion(&state, true, 30.0);
    const result = tickZombieUnderwaterConversion(&state, true, 15.0);
    try std.testing.expect(result.converted);
    try std.testing.expectEqual(ZombieVariant.aquatic_drowned, result.new_variant);
}

test "Husk chain can continue from converted zombie into drowned" {
    var state = ZombieSubmersionState{ .variant = .desert_husk };
    _ = tickZombieUnderwaterConversion(&state, true, 45.0);
    _ = tickZombieUnderwaterConversion(&state, true, 30.0);
    const result = tickZombieUnderwaterConversion(&state, true, 15.0);
    try std.testing.expect(result.converted);
    try std.testing.expectEqual(ZombieVariant.aquatic_drowned, state.variant);
}

test "leaving water resets conversion progress and shaking" {
    var state = ZombieSubmersionState{ .variant = .standard_zombie };
    _ = tickZombieUnderwaterConversion(&state, true, 35.0);
    _ = tickZombieUnderwaterConversion(&state, false, 0.1);
    try std.testing.expectEqual(@as(f32, 0.0), state.head_submerged_timer);
    try std.testing.expect(!state.is_shaking);
}

test "zombie villager never converts underwater" {
    var state = ZombieSubmersionState{ .variant = .zombie_villager };
    const result = tickZombieUnderwaterConversion(&state, true, 100.0);
    try std.testing.expect(!result.converted);
    try std.testing.expectEqual(ZombieVariant.zombie_villager, state.variant);
}

test "drowned never converts underwater" {
    var state = ZombieSubmersionState{ .variant = .aquatic_drowned };
    const result = tickZombieUnderwaterConversion(&state, true, 100.0);
    try std.testing.expect(!result.converted);
    try std.testing.expectEqual(ZombieVariant.aquatic_drowned, state.variant);
}

test "nonconverting variants clear stale submersion state" {
    var state = ZombieSubmersionState{ .variant = .aquatic_drowned, .head_submerged_timer = 20.0, .is_shaking = true };
    _ = tickZombieUnderwaterConversion(&state, true, 1.0);
    try std.testing.expectEqual(@as(f32, 0.0), state.head_submerged_timer);
    try std.testing.expect(!state.is_shaking);
}

test "conversion phase threshold is exactly thirty seconds" {
    var state = ZombieSubmersionState{ .variant = .desert_husk };
    _ = tickZombieUnderwaterConversion(&state, true, 29.99);
    try std.testing.expect(!state.is_shaking);
    _ = tickZombieUnderwaterConversion(&state, true, 0.01);
    try std.testing.expect(state.is_shaking);
}

test "converted Husk restores full zombie health constant" {
    try std.testing.expectEqual(@as(f32, 20.0), converted_zombie_health);
}

test "Husks are immune to sunlight burning" {
    try std.testing.expect(!HuskMechanics.isHuskBurningInSunlight());
}

test "Husk melee hunger floors regional difficulty" {
    try std.testing.expectEqual(@as(f32, 14.0), HuskMechanics.huskMeleeHungerDurationSeconds(2.9));
    try std.testing.expectEqual(@as(f32, 0.0), HuskMechanics.huskMeleeHungerDurationSeconds(0.9));
}

test "Husk hunger scales by whole regional difficulty levels" {
    try std.testing.expectEqual(@as(f32, 21.0), HuskMechanics.huskMeleeHungerDurationSeconds(3.0));
}

test "Drowned trident spawn chance is 6.25 percent" {
    try std.testing.expect(DrownedSpawnEquipment.hasTrident(0.0));
    try std.testing.expect(DrownedSpawnEquipment.hasTrident(0.0624));
    try std.testing.expect(!DrownedSpawnEquipment.hasTrident(0.0625));
    try std.testing.expectEqual(@as(f32, 1.5), DrownedSpawnEquipment.trident_ranged_attack_interval_seconds);
}

test "Drowned Nautilus Shell spawn chance and death drop are represented" {
    try std.testing.expect(DrownedSpawnEquipment.hasNautilusShell(0.029));
    try std.testing.expect(!DrownedSpawnEquipment.hasNautilusShell(0.03));
    try std.testing.expectEqual(@as(f32, 1.0), DrownedSpawnEquipment.nautilus_shell_drop_chance);
}

test "daytime trident drowned melee rule requires close non-swimming player" {
    try std.testing.expect(DrownedSpawnEquipment.shouldUseMeleeDuringDay(2.9, false));
    try std.testing.expect(!DrownedSpawnEquipment.shouldUseMeleeDuringDay(3.1, false));
    try std.testing.expect(!DrownedSpawnEquipment.shouldUseMeleeDuringDay(2.0, true));
    try std.testing.expectEqual(@as(f32, 3.0), DrownedSpawnEquipment.trident_melee_switch_distance);
}

test "Hard mode Zombie breaks wooden door after twelve seconds" {
    var progress: f32 = 0.0;
    try std.testing.expect(!tickHardModeZombieDoorBreak(true, true, &progress, 11.99));
    try std.testing.expect(tickHardModeZombieDoorBreak(true, true, &progress, 0.01));
    try std.testing.expectEqual(wooden_door_break_seconds, progress);
}

test "door breaking does not progress outside Hard or without a wooden door" {
    var progress: f32 = 4.0;
    try std.testing.expect(!tickHardModeZombieDoorBreak(false, true, &progress, 5.0));
    try std.testing.expectEqual(@as(f32, 0.0), progress);
    progress = 4.0;
    try std.testing.expect(!tickHardModeZombieDoorBreak(true, false, &progress, 5.0));
    try std.testing.expectEqual(@as(f32, 0.0), progress);
}

test "negative dt cannot advance conversion or door breaking" {
    var state = ZombieSubmersionState{ .variant = .standard_zombie, .head_submerged_timer = 4.0 };
    _ = tickZombieUnderwaterConversion(&state, true, -1.0);
    try std.testing.expectEqual(@as(f32, 4.0), state.head_submerged_timer);
    var progress: f32 = 2.0;
    try std.testing.expect(!tickHardModeZombieDoorBreak(true, true, &progress, -1.0));
    try std.testing.expectEqual(@as(f32, 2.0), progress);
}
