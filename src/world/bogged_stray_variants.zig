const std = @import("std");

pub const bogged_max_health: f32 = 16.0;
pub const stray_max_health: f32 = 20.0;
pub const bogged_bow_cooldown_ticks: u32 = 70;
pub const stray_bow_cooldown_ticks: u32 = 40;
pub const bogged_poison_duration_seconds: f32 = 4.0;
pub const stray_slowness_duration_seconds: f32 = 30.0;
pub const stray_movement_speed_multiplier: f32 = 0.85;
pub const horse_trap_trigger_distance: f32 = 10.0;
pub const horse_trap_min_probability: f32 = 0.0075;
pub const horse_trap_max_probability: f32 = 0.075;
pub const horsemen_per_trap: u8 = 4;

pub const Variant = enum { bogged, stray };
pub const ArrowEffect = enum { poison_i, slowness_i };
pub const Mushroom = enum { red, brown };
pub const ShearingTool = enum { shears, other };

pub const VariantAppearance = struct {
    moss_and_vines: bool,
    mushroom_cap: bool,
    cloth_bandages: bool,
    icy_blue_eyes: bool,
};

pub fn appearance(variant: Variant) VariantAppearance {
    return switch (variant) {
        .bogged => .{ .moss_and_vines = true, .mushroom_cap = true, .cloth_bandages = false, .icy_blue_eyes = false },
        .stray => .{ .moss_and_vines = false, .mushroom_cap = false, .cloth_bandages = true, .icy_blue_eyes = true },
    };
}

pub const ArrowPayload = struct {
    effect: ArrowEffect,
    duration_seconds: f32,
    movement_speed_multiplier: f32 = 1.0,
};

pub fn maxHealth(variant: Variant) f32 {
    return switch (variant) { .bogged => bogged_max_health, .stray => stray_max_health };
}

pub fn bowCooldownTicks(variant: Variant) u32 {
    return switch (variant) { .bogged => bogged_bow_cooldown_ticks, .stray => stray_bow_cooldown_ticks };
}

pub fn arrowPayload(variant: Variant) ArrowPayload {
    return switch (variant) {
        .bogged => .{ .effect = .poison_i, .duration_seconds = bogged_poison_duration_seconds },
        .stray => .{ .effect = .slowness_i, .duration_seconds = stray_slowness_duration_seconds, .movement_speed_multiplier = stray_movement_speed_multiplier },
    };
}

pub const ShearResult = struct {
    success: bool = false,
    durability_used: u8 = 0,
    mushrooms: [2]Mushroom = .{ .red, .brown },
};

pub const BoggedState = struct {
    is_sheared: bool = false,

    pub fn mushroomCapVisible(self: BoggedState) bool {
        return !self.is_sheared;
    }
};

/// Shears wear by one point on a successful interaction. `red_first` chooses
/// the order of the red and brown mushrooms in the drop result.
pub fn shearBogged(state: *BoggedState, tool: ShearingTool, red_first: bool) ShearResult {
    if (tool != .shears or state.is_sheared) return .{};
    state.is_sheared = true;
    return .{
        .success = true,
        .durability_used = 1,
        .mushrooms = if (red_first) .{ .red, .brown } else .{ .brown, .red },
    };
}

pub fn strayImmuneToPowderSnowDamage() bool {
    return true;
}

pub fn strayImmuneToFreezing() bool {
    return true;
}

pub fn emitsShiveringFrostWisps() bool {
    return true;
}

pub fn trapSpawnProbability(regional_difficulty: f32) f32 {
    return std.math.clamp(regional_difficulty, 0.0, 1.0) *
        (horse_trap_max_probability - horse_trap_min_probability) + horse_trap_min_probability;
}

pub fn shouldSpawnSkeletonTrap(thunderstorm: bool, regional_difficulty: f32, random_roll: f32) bool {
    return thunderstorm and random_roll >= 0.0 and random_roll < trapSpawnProbability(regional_difficulty);
}

pub const TrapHorseState = struct {
    pos: [3]f32 = .{ 0.0, 0.0, 0.0 },
    triggered: bool = false,
};

pub const HorsemanSpawnResult = struct {
    lightning_struck: bool = false,
    horse_damaged: bool = false,
    horsemen_spawned: u8 = 0,
    enchanted_iron_helmets: bool = false,
    enchanted_bows: bool = false,
};

pub fn triggerSkeletonTrap(horse: *TrapHorseState, player_pos: [3]f32) HorsemanSpawnResult {
    if (horse.triggered) return .{};
    const dx = player_pos[0] - horse.pos[0];
    const dy = player_pos[1] - horse.pos[1];
    const dz = player_pos[2] - horse.pos[2];
    const distance_squared = dx * dx + dy * dy + dz * dz;
    if (distance_squared > horse_trap_trigger_distance * horse_trap_trigger_distance) return .{};
    horse.triggered = true;
    return .{
        .lightning_struck = true,
        .horse_damaged = false,
        .horsemen_spawned = horsemen_per_trap,
        .enchanted_iron_helmets = true,
        .enchanted_bows = true,
    };
}

test "bogged has 16 HP" { try std.testing.expectEqual(@as(f32, 16.0), maxHealth(.bogged)); }
test "stray has 20 HP" { try std.testing.expectEqual(@as(f32, 20.0), maxHealth(.stray)); }
test "bogged bow cooldown is 70 ticks" { try std.testing.expectEqual(@as(u32, 70), bowCooldownTicks(.bogged)); }
test "stray bow cooldown is 40 ticks" { try std.testing.expectEqual(@as(u32, 40), bowCooldownTicks(.stray)); }
test "bogged cooldown equals three and a half seconds" { try std.testing.expectEqual(@as(f32, 3.5), @as(f32, @floatFromInt(bowCooldownTicks(.bogged))) / 20.0); }
test "stray cooldown equals two seconds" { try std.testing.expectEqual(@as(f32, 2.0), @as(f32, @floatFromInt(bowCooldownTicks(.stray))) / 20.0); }
test "bogged arrow is Poison I" { try std.testing.expectEqual(ArrowEffect.poison_i, arrowPayload(.bogged).effect); }
test "bogged poison lasts four seconds" { try std.testing.expectEqual(@as(f32, 4.0), arrowPayload(.bogged).duration_seconds); }
test "bogged arrow has normal movement speed effect" { try std.testing.expectEqual(@as(f32, 1.0), arrowPayload(.bogged).movement_speed_multiplier); }
test "stray arrow is Slowness I" { try std.testing.expectEqual(ArrowEffect.slowness_i, arrowPayload(.stray).effect); }
test "stray slowness lasts thirty seconds" { try std.testing.expectEqual(@as(f32, 30.0), arrowPayload(.stray).duration_seconds); }
test "stray reduces movement speed by fifteen percent" { try std.testing.expectEqual(@as(f32, 0.85), arrowPayload(.stray).movement_speed_multiplier); }
test "bogged appearance has moss, vines, and mushroom cap" {
    const visual = appearance(.bogged);
    try std.testing.expect(visual.moss_and_vines and visual.mushroom_cap);
    try std.testing.expect(!visual.cloth_bandages and !visual.icy_blue_eyes);
}
test "stray appearance has bandages and icy blue eyes" {
    const visual = appearance(.stray);
    try std.testing.expect(visual.cloth_bandages and visual.icy_blue_eyes);
    try std.testing.expect(!visual.moss_and_vines and !visual.mushroom_cap);
}
test "unsheared bogged accepts shears" {
    var state = BoggedState{};
    try std.testing.expect(shearBogged(&state, .shears, false).success);
    try std.testing.expect(state.is_sheared);
}
test "shearing drops exactly two mushrooms" {
    var state = BoggedState{};
    const result = shearBogged(&state, .shears, false);
    try std.testing.expectEqual(@as(usize, 2), result.mushrooms.len);
}
test "shearing can drop one red and one brown mushroom" {
    var state = BoggedState{};
    const result = shearBogged(&state, .shears, false);
    try std.testing.expectEqual(Mushroom.brown, result.mushrooms[0]);
    try std.testing.expectEqual(Mushroom.red, result.mushrooms[1]);
}
test "shearing can randomly distribute mushroom drop order" {
    var state = BoggedState{};
    const result = shearBogged(&state, .shears, true);
    try std.testing.expectEqual(Mushroom.red, result.mushrooms[0]);
    try std.testing.expectEqual(Mushroom.brown, result.mushrooms[1]);
}
test "successful shearing consumes one shears durability" {
    var state = BoggedState{};
    try std.testing.expectEqual(@as(u8, 1), shearBogged(&state, .shears, false).durability_used);
}
test "shearing reports success only once" {
    var state = BoggedState{};
    try std.testing.expect(shearBogged(&state, .shears, false).success);
    try std.testing.expect(!shearBogged(&state, .shears, false).success);
}
test "already sheared bogged rejects another interaction" {
    var state = BoggedState{ .is_sheared = true };
    try std.testing.expectEqual(@as(u8, 0), shearBogged(&state, .shears, false).durability_used);
}
test "shearing removes the mushroom cap from the model state" {
    var state = BoggedState{};
    try std.testing.expect(state.mushroomCapVisible());
    _ = shearBogged(&state, .shears, false);
    try std.testing.expect(!state.mushroomCapVisible());
}
test "non-shears tool cannot shear bogged" {
    var state = BoggedState{};
    const result = shearBogged(&state, .other, false);
    try std.testing.expect(!result.success);
    try std.testing.expect(!state.is_sheared);
}
test "failed shearing does not wear shears" {
    var state = BoggedState{};
    try std.testing.expectEqual(@as(u8, 0), shearBogged(&state, .other, false).durability_used);
}
test "stray is immune to powder snow damage" { try std.testing.expect(strayImmuneToPowderSnowDamage()); }
test "stray is immune to freezing" { try std.testing.expect(strayImmuneToFreezing()); }
test "stray emits shivering frost wisps" { try std.testing.expect(emitsShiveringFrostWisps()); }
test "trap probability starts at 0.75 percent" { try std.testing.expectApproxEqAbs(@as(f32, 0.0075), trapSpawnProbability(0.0), 0.00001); }
test "trap probability reaches 7.5 percent" { try std.testing.expectApproxEqAbs(@as(f32, 0.075), trapSpawnProbability(1.0), 0.00001); }
test "regional difficulty trap probability is bounded" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0075), trapSpawnProbability(-1.0), 0.00001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.075), trapSpawnProbability(2.0), 0.00001);
}
test "skeleton trap spawning requires a thunderstorm and a successful roll" {
    try std.testing.expect(!shouldSpawnSkeletonTrap(false, 1.0, 0.0));
    try std.testing.expect(!shouldSpawnSkeletonTrap(true, 1.0, 0.075));
    try std.testing.expect(shouldSpawnSkeletonTrap(true, 1.0, 0.05));
}
test "trap does not activate beyond ten blocks" {
    var horse = TrapHorseState{};
    const result = triggerSkeletonTrap(&horse, .{ 10.01, 0.0, 0.0 });
    try std.testing.expectEqual(@as(u8, 0), result.horsemen_spawned);
    try std.testing.expect(!horse.triggered);
}
test "trap activates exactly ten blocks away" {
    var horse = TrapHorseState{};
    try std.testing.expectEqual(horsemen_per_trap, triggerSkeletonTrap(&horse, .{ 10.0, 0.0, 0.0 }).horsemen_spawned);
}
test "trap lightning summons four horsemen without damaging horse" {
    var horse = TrapHorseState{};
    const result = triggerSkeletonTrap(&horse, .{ 0.0, 0.0, 0.0 });
    try std.testing.expect(result.lightning_struck);
    try std.testing.expect(!result.horse_damaged);
    try std.testing.expectEqual(@as(u8, 4), result.horsemen_spawned);
}
test "trap horsemen have enchanted iron helmets and bows" {
    var horse = TrapHorseState{};
    const result = triggerSkeletonTrap(&horse, .{ 0.0, 0.0, 0.0 });
    try std.testing.expect(result.enchanted_iron_helmets);
    try std.testing.expect(result.enchanted_bows);
}
test "trap only triggers once" {
    var horse = TrapHorseState{};
    _ = triggerSkeletonTrap(&horse, .{ 0.0, 0.0, 0.0 });
    try std.testing.expectEqual(@as(u8, 0), triggerSkeletonTrap(&horse, .{ 0.0, 0.0, 0.0 }).horsemen_spawned);
}
