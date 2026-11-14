//! Unified Skeleton Variants: Standard Skeleton, Stray, Bogged, and Wither Skeleton
//!
//! Combines Powder Snow freeze conversion, arrow status payloads, Bogged poison & mushroom
//! shearing harvest, daylight burning, defeat drops, and Skeleton Trap horsemen.

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

// ============================================================================
// Bogged & Stray Variant Rules + Skeleton Trap Horsemen
// ============================================================================

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

// ============================================================================
// Bogged Poison Combat, Daylight Burn, Shearing Harvest & Defeat Drops
// ============================================================================

// ============================================================================
// Constants
// ============================================================================

/// Bogged max health in HP (8 hearts = 16.0 HP, weaker than standard 20.0 HP skeleton).
pub const BOGGED_MAX_HEALTH: f32 = 16.0;

/// Standard skeleton max health in HP (10 hearts = 20.0 HP).
pub const STANDARD_SKELETON_MAX_HEALTH: f32 = 20.0;

/// Standard game simulation ticks per second.
pub const TICKS_PER_SECOND: u32 = 20;

/// Bogged bow attack cooldown / fire interval in ticks (3.5 seconds at 20 ticks/sec).
pub const BOGGED_BOW_COOLDOWN_TICKS: u32 = 70;

/// Standard skeleton bow attack cooldown in ticks (2.0 seconds at 20 ticks/sec).
pub const STANDARD_SKELETON_BOW_COOLDOWN_TICKS: u32 = 40;

/// Poison I duration on Normal difficulty: 4.0 seconds = 80 ticks.
pub const POISON_DURATION_NORMAL_TICKS: u32 = 80;

/// Poison I duration on Hard difficulty: 5.0 seconds = 100 ticks.
pub const POISON_DURATION_HARD_TICKS: u32 = 100;

/// Poison I duration on Easy/Peaceful difficulty: 0 ticks (no poison effect applied).
pub const POISON_DURATION_EASY_TICKS: u32 = 0;

/// Interval between poison damage ticks: 25 ticks = 1.25 seconds.
pub const POISON_INTERVAL_TICKS: u32 = 25;

/// Magic damage inflicted per poison interval: 1.0 HP (half heart).
pub const POISON_DAMAGE_PER_INTERVAL: f32 = 1.0;

/// Poison minimum health floor: Poison cannot reduce target health below 1.0 HP (half heart).
pub const POISON_MIN_HEALTH_FLOOR: f32 = 1.0;

/// Daylight fire damage rate: 1.0 HP per second.
pub const DAYLIGHT_FIRE_DAMAGE_PER_SECOND: f32 = 1.0;

/// Experience points dropped on Bogged defeat.
pub const EXPERIENCE_POINTS_DROP: u32 = 5;

/// Base drop probability for Poison-tipped arrow on player kill (50%).
pub const POISON_ARROW_BASE_DROP_CHANCE: f32 = 0.50;

/// Looting bonus per level for Poison-tipped arrow (+10%).
pub const POISON_ARROW_LOOTING_STEP: f32 = 0.10;

/// Maximum capped drop chance for Poison-tipped arrow (80%).
pub const POISON_ARROW_MAX_DROP_CHANCE: f32 = 0.80;

/// Base drop probability for rare Bow drop (8.5%).
pub const BOW_BASE_DROP_CHANCE: f32 = 0.085;

/// Looting bonus per level for Bow drop (+1.0%).
pub const BOW_LOOTING_STEP: f32 = 0.010;

// ============================================================================
// Enums & Types
// ============================================================================

/// World gameplay difficulty setting.
pub const Difficulty = enum {
    peaceful,
    easy,
    normal,
    hard,
};

/// Weapon wielded by Bogged.
pub const WeaponType = enum {
    bow,
    unarmed,
    other,
};

/// Standalone mirrored item types for inventory and tool checks.
pub const ItemType = enum(u16) {
    shears = 240,
    bone = 144,
    arrow = 97,
    bow = 98,
    tipped_arrow_poison = 475,
    brown_mushroom = 39,
    red_mushroom = 40,
    iron_helmet = 241,
    other = 999,

    pub fn isShears(self: ItemType) bool {
        return self == .shears;
    }
};

/// Standalone tool category enum.
pub const ToolType = enum {
    shears,
    sword,
    pickaxe,
    axe,
    shovel,
    hoe,
    none,

    pub fn isShears(self: ToolType) bool {
        return self == .shears;
    }
};

/// Mushroom varieties dropped by Bogged shearing.
pub const MushroomType = enum {
    brown,
    red,
};

/// Sound effect cues emitted by Bogged interactions and events.
pub const SoundEffect = enum {
    shears_snip,
    bow_shoot,
    arrow_hit,
    bogged_ambient,
    bogged_hurt,
    bogged_death,
    burn_sizzle,
};

/// Particle types emitted by Bogged actions.
pub const ParticleType = enum {
    moss,
    mushroom_spore,
    poison_bubble,
    fire_flame,
    smoke,
};

/// Combat damage types.
pub const DamageType = enum {
    generic,
    physical,
    magic,
    poison,
    fire,
    fall,
    drowning,
};

/// Visual appearance configuration of the Bogged entity.
pub const BoggedAppearance = struct {
    has_mushrooms: bool = true,
    has_moss: bool = true,
    is_sheared: bool = false,

    pub fn mushroomCapVisible(self: BoggedAppearance) bool {
        return self.has_mushrooms and !self.is_sheared;
    }
};

/// Environmental lighting and weather conditions for daylight burning evaluation.
pub const EnvironmentalConditions = struct {
    is_daylight: bool = true,
    can_see_sky: bool = true,
    is_raining: bool = false,
    in_water: bool = false,
    in_powder_snow: bool = false,
    sky_light_level: u8 = 15,
};

/// Status reason for daylight burn check.
pub const DaylightBurnStatus = enum {
    burning,
    protected_by_helmet,
    protected_by_water,
    protected_by_powder_snow,
    protected_by_rain,
    protected_by_shade,
    protected_by_night,
    immune,
};

/// Result of daylight burning check.
pub const DaylightBurnResult = struct {
    is_burning: bool,
    damage_to_mob: f32 = 0.0,
    helmet_damaged: bool = false,
    helmet_broke: bool = false,
    sound_cue: ?SoundEffect = null,
    status: DaylightBurnStatus,
};

/// Particle burst emitted during shearing.
pub const ShearingParticles = struct {
    moss_count: u32 = 12,
    mushroom_count: u32 = 8,
    spread: f32 = 0.5,
};

/// Reason for shearing interaction failure.
pub const ShearingFailureReason = enum {
    none,
    already_sheared,
    invalid_tool,
};

/// Outcome of attempting to shear a Bogged.
pub const ShearingResult = struct {
    success: bool,
    durability_consumed: u16 = 0,
    mushrooms_dropped: [2]MushroomType = .{ .brown, .red },
    sound_cue: ?SoundEffect = null,
    particles: ShearingParticles = .{},
    reason: ShearingFailureReason = .none,
};

/// Result of a single tick of Poison status effect.
pub const PoisonTickOutcome = struct {
    damage_dealt: f32 = 0.0,
    poison_expired: bool = false,
    reached_floor: bool = false,
};

// ============================================================================
// Poison Status Effect Model
// ============================================================================

pub const PoisonStatusEffect = struct {
    active: bool = false,
    duration_ticks: u32 = 0,
    ticks_elapsed: u32 = 0,
    interval_counter: u32 = 0,

    /// Initialize a poison status effect with a total duration in ticks.
    pub fn init(duration_ticks: u32) PoisonStatusEffect {
        return .{
            .active = duration_ticks > 0,
            .duration_ticks = duration_ticks,
            .ticks_elapsed = 0,
            .interval_counter = 0,
        };
    }

    /// Advance poison by 1 tick and apply interval damage to target health.
    /// Preserves target health floor of 1.0 HP (cannot reduce below 1.0 HP).
    pub fn tick(self: *PoisonStatusEffect, target_health: *f32) PoisonTickOutcome {
        if (!self.active or self.duration_ticks == 0) {
            self.active = false;
            return .{ .poison_expired = true };
        }

        var outcome = PoisonTickOutcome{};
        self.ticks_elapsed += 1;
        self.interval_counter += 1;

        if (self.interval_counter >= POISON_INTERVAL_TICKS) {
            self.interval_counter = 0;
            if (target_health.* > POISON_MIN_HEALTH_FLOOR) {
                const max_allowable_damage = target_health.* - POISON_MIN_HEALTH_FLOOR;
                const dmg = @min(POISON_DAMAGE_PER_INTERVAL, max_allowable_damage);
                target_health.* -= dmg;
                outcome.damage_dealt = dmg;
                if (target_health.* <= POISON_MIN_HEALTH_FLOOR) {
                    outcome.reached_floor = true;
                }
            } else {
                outcome.reached_floor = true;
            }
        }

        if (self.ticks_elapsed >= self.duration_ticks) {
            self.active = false;
            outcome.poison_expired = true;
        }

        return outcome;
    }
};

/// Return poison duration in ticks for a given difficulty level.
pub fn poisonDurationForDifficulty(difficulty: Difficulty) u32 {
    return switch (difficulty) {
        .hard => POISON_DURATION_HARD_TICKS,
        .normal => POISON_DURATION_NORMAL_TICKS,
        .easy, .peaceful => POISON_DURATION_EASY_TICKS,
    };
}

// ============================================================================
// Arrow Kinematics & Projectiles
// ============================================================================

pub const PoisonArrow = struct {
    position: [3]f32,
    velocity: [3]f32,
    gravity: f32 = 0.05,
    drag: f32 = 0.99,
    base_damage: f32 = 4.0,
    poison_duration_ticks: u32,
    is_in_ground: bool = false,
    ticks_in_air: u32 = 0,

    /// Construct a new PoisonArrow projectile.
    pub fn init(origin: [3]f32, velocity: [3]f32, poison_duration_ticks: u32) PoisonArrow {
        return .{
            .position = origin,
            .velocity = velocity,
            .poison_duration_ticks = poison_duration_ticks,
        };
    }

    /// Advance arrow kinematics by 1 simulation tick.
    pub fn tick(self: *PoisonArrow) void {
        if (self.is_in_ground) return;
        self.position[0] += self.velocity[0];
        self.position[1] += self.velocity[1];
        self.position[2] += self.velocity[2];

        self.velocity[0] *= self.drag;
        self.velocity[1] = (self.velocity[1] - self.gravity) * self.drag;
        self.velocity[2] *= self.drag;

        self.ticks_in_air += 1;
    }

    /// Current velocity scalar magnitude (speed).
    pub fn getSpeed(self: PoisonArrow) f32 {
        const sq = self.velocity[0] * self.velocity[0] +
            self.velocity[1] * self.velocity[1] +
            self.velocity[2] * self.velocity[2];
        return @sqrt(sq);
    }
};

/// Calculate launch velocity vector towards target position with given scalar speed.
pub fn calculateLaunchVelocity(origin: [3]f32, target: [3]f32, speed: f32) [3]f32 {
    const dx = target[0] - origin[0];
    const dy = target[1] - origin[1];
    const dz = target[2] - origin[2];
    const dist_sq = dx * dx + dy * dy + dz * dz;
    if (dist_sq <= 0.0001) {
        return .{ 0.0, 0.0, speed };
    }
    const inv_dist = 1.0 / @sqrt(dist_sq);
    return .{
        dx * inv_dist * speed,
        dy * inv_dist * speed,
        dz * inv_dist * speed,
    };
}

/// Result of checking projectile impact with a target.
pub const ArrowImpactResult = struct {
    hit: bool,
    damage_dealt: f32 = 0.0,
    poison_applied: bool = false,
    poison_duration_ticks: u32 = 0,
    sound_cue: ?SoundEffect = null,
};

/// Check if arrow collides with cylindrical target bounding box and apply damage/poison.
pub fn checkAndApplyArrowHit(
    arrow: *PoisonArrow,
    target_pos: [3]f32,
    target_radius: f32,
    target_height: f32,
    target_health: *f32,
    target_poison: *PoisonStatusEffect,
) ArrowImpactResult {
    if (arrow.is_in_ground) return .{ .hit = false };

    const dx = arrow.position[0] - target_pos[0];
    const dz = arrow.position[2] - target_pos[2];
    const horiz_dist_sq = dx * dx + dz * dz;

    const in_horizontal = horiz_dist_sq <= (target_radius * target_radius);
    const in_vertical = (arrow.position[1] >= target_pos[1]) and (arrow.position[1] <= target_pos[1] + target_height);

    if (in_horizontal and in_vertical) {
        arrow.is_in_ground = true;
        const dmg = arrow.base_damage;
        target_health.* = @max(0.0, target_health.* - dmg);

        var poison_applied = false;
        if (arrow.poison_duration_ticks > 0 and target_health.* > 0.0) {
            target_poison.* = PoisonStatusEffect.init(arrow.poison_duration_ticks);
            poison_applied = true;
        }

        return .{
            .hit = true,
            .damage_dealt = dmg,
            .poison_applied = poison_applied,
            .poison_duration_ticks = arrow.poison_duration_ticks,
            .sound_cue = .arrow_hit,
        };
    }

    return .{ .hit = false };
}

// ============================================================================
// Bogged Entity State
// ============================================================================

pub const BoggedEntity = struct {
    id: u32 = 0,
    position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    health: f32 = BOGGED_MAX_HEALTH,
    max_health: f32 = BOGGED_MAX_HEALTH,
    weapon: WeaponType = .bow,
    attack_cooldown_ticks: u32 = 0,
    has_mushrooms: bool = true,
    is_sheared: bool = false,
    has_moss: bool = true,
    has_helmet: bool = false,
    helmet_durability: u16 = 0,
    burns_in_sunlight: bool = true,
    is_on_fire: bool = false,
    fire_ticks_remaining: u32 = 0,
    is_dead: bool = false,

    /// Create a naturally spawned Bogged entity.
    pub fn init(pos: [3]f32) BoggedEntity {
        return .{
            .position = pos,
            .health = BOGGED_MAX_HEALTH,
            .max_health = BOGGED_MAX_HEALTH,
            .weapon = .bow,
            .attack_cooldown_ticks = 0,
            .has_mushrooms = true,
            .is_sheared = false,
            .has_moss = true,
            .burns_in_sunlight = true,
        };
    }

    /// Whether the Bogged is currently ready to fire its bow.
    pub fn canShoot(self: BoggedEntity) bool {
        return !self.is_dead and self.weapon == .bow and self.attack_cooldown_ticks == 0;
    }

    /// Shoot a poison-tipped arrow towards the target position.
    pub fn shoot(self: *BoggedEntity, target_pos: [3]f32, difficulty: Difficulty) ?PoisonArrow {
        if (!self.canShoot()) return null;
        self.attack_cooldown_ticks = BOGGED_BOW_COOLDOWN_TICKS;
        const eye_height: f32 = 1.6;
        const origin = [3]f32{ self.position[0], self.position[1] + eye_height, self.position[2] };
        const launch_vel = calculateLaunchVelocity(origin, target_pos, 1.6);
        const duration = poisonDurationForDifficulty(difficulty);
        return PoisonArrow.init(origin, launch_vel, duration);
    }

    /// Tick cooldown timer.
    pub fn tickCooldown(self: *BoggedEntity, ticks: u32) void {
        if (self.attack_cooldown_ticks > 0) {
            self.attack_cooldown_ticks -= @min(self.attack_cooldown_ticks, ticks);
        }
    }

    /// Inflict direct damage to the entity.
    pub fn takeDamage(self: *BoggedEntity, amount: f32) void {
        if (self.is_dead) return;
        self.health = @max(0.0, self.health - amount);
        if (self.health <= 0.0) {
            self.is_dead = true;
        }
    }

    /// Return visual appearance flags.
    pub fn getAppearance(self: BoggedEntity) BoggedAppearance {
        return .{
            .has_mushrooms = self.has_mushrooms,
            .has_moss = self.has_moss,
            .is_sheared = self.is_sheared,
        };
    }
};

// ============================================================================
// Daylight Burning Logic
// ============================================================================

/// Evaluate daylight burning rules and apply damage/helmet wear.
fn checkEnvironmentProtection(bogged: *const BoggedEntity, env: EnvironmentalConditions) ?DaylightBurnResult {
    if (!bogged.burns_in_sunlight) return .{ .is_burning = false, .status = .immune };
    if (!env.is_daylight or env.sky_light_level < 12) return .{ .is_burning = false, .status = .protected_by_night };
    if (!env.can_see_sky) return .{ .is_burning = false, .status = .protected_by_shade };
    if (env.is_raining) return .{ .is_burning = false, .status = .protected_by_rain };
    if (env.in_water) return .{ .is_burning = false, .status = .protected_by_water };
    if (env.in_powder_snow) return .{ .is_burning = false, .status = .protected_by_powder_snow };
    return null;
}

fn applyHelmetSunlightProtection(bogged: *BoggedEntity) DaylightBurnResult {
    var helmet_broke = false;
    if (bogged.helmet_durability > 0) {
        bogged.helmet_durability -= 1;
        if (bogged.helmet_durability == 0) {
            bogged.has_helmet = false;
            helmet_broke = true;
        }
    }
    return .{
        .is_burning = false,
        .damage_to_mob = 0.0,
        .helmet_damaged = true,
        .helmet_broke = helmet_broke,
        .status = .protected_by_helmet,
    };
}

/// Evaluate daylight burning rules and apply damage/helmet wear.
pub fn checkDaylightBurn(bogged: *BoggedEntity, env: EnvironmentalConditions) DaylightBurnResult {
    if (checkEnvironmentProtection(bogged, env)) |protected_result| {
        return protected_result;
    }
    if (bogged.has_helmet) {
        return applyHelmetSunlightProtection(bogged);
    }

    const dmg = DAYLIGHT_FIRE_DAMAGE_PER_SECOND;
    bogged.health = @max(0.0, bogged.health - dmg);
    bogged.is_on_fire = true;
    bogged.fire_ticks_remaining = 160;
    if (bogged.health <= 0.0) {
        bogged.is_dead = true;
    }

    return .{
        .is_burning = true,
        .damage_to_mob = dmg,
        .sound_cue = .burn_sizzle,
        .status = .burning,
    };
}

// ============================================================================
// Mushroom Shearing Harvest
// ============================================================================

/// Determine mushroom drop from a uniform roll (50/50 probability).
pub fn rollMushroom(roll: f32) MushroomType {
    return if (roll < 0.5) .brown else .red;
}

/// Perform mushroom shearing harvest with explicitly provided random rolls.
pub fn shearBoggedWithRolls(bogged: *BoggedEntity, tool_is_shears: bool, roll0: f32, roll1: f32) ShearingResult {
    if (bogged.is_sheared or !bogged.has_mushrooms) {
        return .{
            .success = false,
            .durability_consumed = 0,
            .reason = .already_sheared,
        };
    }
    if (!tool_is_shears) {
        return .{
            .success = false,
            .durability_consumed = 0,
            .reason = .invalid_tool,
        };
    }

    bogged.has_mushrooms = false;
    bogged.is_sheared = true;

    return .{
        .success = true,
        .durability_consumed = 1,
        .mushrooms_dropped = .{ rollMushroom(roll0), rollMushroom(roll1) },
        .sound_cue = .shears_snip,
        .particles = .{ .moss_count = 12, .mushroom_count = 8, .spread = 0.5 },
        .reason = .none,
    };
}

/// Convenience wrapper using ItemType.
pub fn shearBoggedItem(bogged: *BoggedEntity, item: ItemType, roll0: f32, roll1: f32) ShearingResult {
    return shearBoggedWithRolls(bogged, item.isShears(), roll0, roll1);
}

/// Convenience wrapper using ToolType.
pub fn shearBoggedTool(bogged: *BoggedEntity, tool: ToolType, roll0: f32, roll1: f32) ShearingResult {
    return shearBoggedWithRolls(bogged, tool.isShears(), roll0, roll1);
}

/// Shearing using a std.Random PRNG.
pub fn shearBoggedPrng(bogged: *BoggedEntity, tool_is_shears: bool, random: *std.Random) ShearingResult {
    const r0 = random.float(f32);
    const r1 = random.float(f32);
    return shearBoggedWithRolls(bogged, tool_is_shears, r0, r1);
}

// ============================================================================
// Drops on Defeat & Looting Scaling
// ============================================================================

/// Maximum bones dropped given Looting enchantment level (0..2 + looting).
pub fn maxBones(looting: u8) u8 {
    return 2 + looting;
}

/// Maximum arrows dropped given Looting enchantment level (0..2 + looting).
pub fn maxArrows(looting: u8) u8 {
    return 2 + looting;
}

/// Calculate Poison-tipped arrow drop chance.
/// Requires player kill; 50% base + 10% per Looting level, capped at 80%.
pub fn poisonArrowDropChance(looting: u8, is_player_kill: bool) f32 {
    if (!is_player_kill) return 0.0;
    const base: f32 = POISON_ARROW_BASE_DROP_CHANCE;
    const scaled = base + @as(f32, @floatFromInt(looting)) * POISON_ARROW_LOOTING_STEP;
    return @min(POISON_ARROW_MAX_DROP_CHANCE, scaled);
}

/// Calculate Bow rare drop chance (8.5% base + 1.0% per Looting level).
pub fn bowDropChance(looting: u8) f32 {
    return BOW_BASE_DROP_CHANCE + @as(f32, @floatFromInt(looting)) * BOW_LOOTING_STEP;
}

/// Structured defeat loot result.
pub const DefeatLoot = struct {
    bones: u8,
    arrows: u8,
    poison_arrows: u8,
    bows: u8,
    experience_points: u32 = EXPERIENCE_POINTS_DROP,
};

/// Roll defeat drops deterministically from provided normalized float values [0.0..1.0).
pub fn rollDefeatLoot(
    looting: u8,
    is_player_kill: bool,
    roll_bones: f32,
    roll_arrows: f32,
    roll_poison_arrow: f32,
    roll_bow: f32,
) DefeatLoot {
    const max_b = maxBones(looting);
    const max_a = maxArrows(looting);

    const b_clamped = std.math.clamp(roll_bones, 0.0, 0.999999);
    const bones = @as(u8, @intFromFloat(@floor(b_clamped * @as(f32, @floatFromInt(max_b + 1)))));

    const a_clamped = std.math.clamp(roll_arrows, 0.0, 0.999999);
    const arrows = @as(u8, @intFromFloat(@floor(a_clamped * @as(f32, @floatFromInt(max_a + 1)))));

    const poison_chance = poisonArrowDropChance(looting, is_player_kill);
    const poison_arrows: u8 = if (roll_poison_arrow < poison_chance) 1 else 0;

    const bow_chance = bowDropChance(looting);
    const bows: u8 = if (roll_bow < bow_chance) 1 else 0;

    return .{
        .bones = bones,
        .arrows = arrows,
        .poison_arrows = poison_arrows,
        .bows = bows,
        .experience_points = EXPERIENCE_POINTS_DROP,
    };
}

/// Roll defeat drops using standard PRNG.
pub fn rollDefeatLootWithPrng(
    looting: u8,
    is_player_kill: bool,
    random: *std.Random,
) DefeatLoot {
    return rollDefeatLoot(
        looting,
        is_player_kill,
        random.float(f32),
        random.float(f32),
        random.float(f32),
        random.float(f32),
    );
}


// ============================================================================
// Unit Tests (Milestone 529: Bogged Poison Combat & Mushroom Shearing Harvest)
// ============================================================================

test "01. Bogged max health is exactly 16.0 HP (8 hearts)" {
    const bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    try std.testing.expectEqual(@as(f32, 16.0), BOGGED_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 16.0), bogged.health);
    try std.testing.expectEqual(@as(f32, 16.0), bogged.max_health);
}

test "02. Bogged is weaker than standard skeleton (16.0 HP vs 20.0 HP)" {
    try std.testing.expect(BOGGED_MAX_HEALTH < STANDARD_SKELETON_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 20.0), STANDARD_SKELETON_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 4.0), STANDARD_SKELETON_MAX_HEALTH - BOGGED_MAX_HEALTH);
}

test "03. Bogged attack cooldown is 70 ticks (3.5 seconds)" {
    try std.testing.expectEqual(@as(u32, 70), BOGGED_BOW_COOLDOWN_TICKS);
    const seconds = @as(f32, @floatFromInt(BOGGED_BOW_COOLDOWN_TICKS)) / @as(f32, @floatFromInt(TICKS_PER_SECOND));
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), seconds, 0.001);
}

test "04. Bogged attack cooldown is slower than standard skeleton 40 ticks (2.0s)" {
    try std.testing.expect(BOGGED_BOW_COOLDOWN_TICKS > STANDARD_SKELETON_BOW_COOLDOWN_TICKS);
    try std.testing.expectEqual(@as(u32, 40), STANDARD_SKELETON_BOW_COOLDOWN_TICKS);
    try std.testing.expectEqual(@as(u32, 30), BOGGED_BOW_COOLDOWN_TICKS - STANDARD_SKELETON_BOW_COOLDOWN_TICKS);
}

test "05. Bogged default weapon is bow and naturally can shoot" {
    const bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    try std.testing.expectEqual(WeaponType.bow, bogged.weapon);
    try std.testing.expect(bogged.canShoot());
}

test "06. Shooting initiates 70-tick bow cooldown and blocks immediate consecutive shot" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const arrow = bogged.shoot(.{ 10.0, 0.0, 0.0 }, .normal);
    try std.testing.expect(arrow != null);
    try std.testing.expectEqual(@as(u32, 70), bogged.attack_cooldown_ticks);
    try std.testing.expect(!bogged.canShoot());

    // Immediate second shot must fail
    const second_shot = bogged.shoot(.{ 10.0, 0.0, 0.0 }, .normal);
    try std.testing.expect(second_shot == null);
}

test "07. Cooldown ticks down and restores ability to shoot after 70 ticks" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    _ = bogged.shoot(.{ 10.0, 0.0, 0.0 }, .normal);
    try std.testing.expect(!bogged.canShoot());

    bogged.tickCooldown(69);
    try std.testing.expectEqual(@as(u32, 1), bogged.attack_cooldown_ticks);
    try std.testing.expect(!bogged.canShoot());

    bogged.tickCooldown(1);
    try std.testing.expectEqual(@as(u32, 0), bogged.attack_cooldown_ticks);
    try std.testing.expect(bogged.canShoot());
}

test "08. Dead Bogged cannot shoot regardless of cooldown" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    bogged.is_dead = true;
    try std.testing.expect(!bogged.canShoot());
    try std.testing.expect(bogged.shoot(.{ 10.0, 0.0, 0.0 }, .normal) == null);
}

test "09. Poison arrow duration on Normal difficulty is 4.0 seconds (80 ticks)" {
    try std.testing.expectEqual(@as(u32, 80), POISON_DURATION_NORMAL_TICKS);
    try std.testing.expectEqual(@as(u32, 80), poisonDurationForDifficulty(.normal));
}

test "10. Poison arrow duration on Hard difficulty is 5.0 seconds (100 ticks)" {
    try std.testing.expectEqual(@as(u32, 100), POISON_DURATION_HARD_TICKS);
    try std.testing.expectEqual(@as(u32, 100), poisonDurationForDifficulty(.hard));
}

test "11. Poison arrow duration on Easy and Peaceful is 0 ticks (no poison)" {
    try std.testing.expectEqual(@as(u32, 0), POISON_DURATION_EASY_TICKS);
    try std.testing.expectEqual(@as(u32, 0), poisonDurationForDifficulty(.easy));
    try std.testing.expectEqual(@as(u32, 0), poisonDurationForDifficulty(.peaceful));
}

test "12. Arrow projectile kinematics updates position by velocity" {
    var arrow = PoisonArrow.init(.{ 0.0, 10.0, 0.0 }, .{ 1.0, 0.0, 0.0 }, 80);
    arrow.tick();
    try std.testing.expectEqual(@as(f32, 1.0), arrow.position[0]);
    try std.testing.expectApproxEqAbs(@as(f32, 0.99), arrow.velocity[0], 0.001);
    try std.testing.expectEqual(@as(u32, 1), arrow.ticks_in_air);
}

test "13. Arrow projectile applies gravity acceleration (0.05 per tick)" {
    var arrow = PoisonArrow.init(.{ 0.0, 10.0, 0.0 }, .{ 0.0, 0.0, 0.0 }, 80);
    arrow.tick();
    // velocity[1] = (0 - 0.05) * 0.99 = -0.0495
    try std.testing.expectApproxEqAbs(@as(f32, -0.0495), arrow.velocity[1], 0.001);
}

test "14. Arrow projectile applies drag (0.99 per tick) to reduce speed" {
    var arrow = PoisonArrow.init(.{ 0.0, 10.0, 0.0 }, .{ 2.0, 0.0, 0.0 }, 80);
    const initial_speed = arrow.getSpeed();
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), initial_speed, 0.001);
    arrow.tick();
    try std.testing.expectApproxEqAbs(@as(f32, 1.98), arrow.velocity[0], 0.001);
}

test "15. Trajectory velocity calculation computes normalized vector scaled by speed" {
    const origin = [3]f32{ 0.0, 0.0, 0.0 };
    const target = [3]f32{ 3.0, 4.0, 0.0 }; // distance = 5.0
    const vel = calculateLaunchVelocity(origin, target, 10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), vel[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), vel[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), vel[2], 0.001);
}

test "16. Arrow hit detection applies base damage and inflicts poison" {
    var arrow = PoisonArrow.init(.{ 5.0, 1.0, 5.0 }, .{ 0.0, 0.0, 0.0 }, 80);
    var target_health: f32 = 20.0;
    var target_poison = PoisonStatusEffect.init(0);

    const hit_res = checkAndApplyArrowHit(&arrow, .{ 5.0, 0.0, 5.0 }, 0.6, 1.8, &target_health, &target_poison);
    try std.testing.expect(hit_res.hit);
    try std.testing.expectEqual(@as(f32, 4.0), hit_res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 16.0), target_health);
    try std.testing.expect(hit_res.poison_applied);
    try std.testing.expectEqual(@as(u32, 80), hit_res.poison_duration_ticks);
    try std.testing.expect(target_poison.active);
    try std.testing.expect(arrow.is_in_ground);
}

test "17. Grounded arrow does not hit target again" {
    var arrow = PoisonArrow.init(.{ 5.0, 1.0, 5.0 }, .{ 0.0, 0.0, 0.0 }, 80);
    arrow.is_in_ground = true;
    var target_health: f32 = 20.0;
    var target_poison = PoisonStatusEffect.init(0);

    const hit_res = checkAndApplyArrowHit(&arrow, .{ 5.0, 0.0, 5.0 }, 0.6, 1.8, &target_health, &target_poison);
    try std.testing.expect(!hit_res.hit);
    try std.testing.expectEqual(@as(f32, 20.0), target_health);
}

test "18. Arrow hit on lethal damage does not apply poison" {
    var arrow = PoisonArrow.init(.{ 5.0, 1.0, 5.0 }, .{ 0.0, 0.0, 0.0 }, 80);
    var target_health: f32 = 2.0; // Less than arrow damage 4.0
    var target_poison = PoisonStatusEffect.init(0);

    const hit_res = checkAndApplyArrowHit(&arrow, .{ 5.0, 0.0, 5.0 }, 0.6, 1.8, &target_health, &target_poison);
    try std.testing.expect(hit_res.hit);
    try std.testing.expectEqual(@as(f32, 0.0), target_health);
    try std.testing.expect(!hit_res.poison_applied);
    try std.testing.expect(!target_poison.active);
}

test "19. Arrow hit with 0 poison duration (Easy/Peaceful) damages but skips poison" {
    var arrow = PoisonArrow.init(.{ 5.0, 1.0, 5.0 }, .{ 0.0, 0.0, 0.0 }, 0);
    var target_health: f32 = 20.0;
    var target_poison = PoisonStatusEffect.init(0);

    const hit_res = checkAndApplyArrowHit(&arrow, .{ 5.0, 0.0, 5.0 }, 0.6, 1.8, &target_health, &target_poison);
    try std.testing.expect(hit_res.hit);
    try std.testing.expectEqual(@as(f32, 16.0), target_health);
    try std.testing.expect(!hit_res.poison_applied);
    try std.testing.expect(!target_poison.active);
}

test "20. Poison I interval is exactly 25 ticks (1.25 seconds)" {
    try std.testing.expectEqual(@as(u32, 25), POISON_INTERVAL_TICKS);
    const interval_sec = @as(f32, @floatFromInt(POISON_INTERVAL_TICKS)) / @as(f32, @floatFromInt(TICKS_PER_SECOND));
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), interval_sec, 0.001);
}

test "21. Poison I deals 0 damage during ticks 1 through 24" {
    var poison = PoisonStatusEffect.init(80);
    var target_health: f32 = 20.0;
    for (1..25) |_| {
        const res = poison.tick(&target_health);
        try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
        try std.testing.expectEqual(@as(f32, 20.0), target_health);
        try std.testing.expect(!res.poison_expired);
    }
}

test "22. Poison I deals exactly 1.0 HP damage at tick 25" {
    var poison = PoisonStatusEffect.init(80);
    var target_health: f32 = 20.0;
    for (1..25) |_| {
        _ = poison.tick(&target_health);
    }
    const tick25 = poison.tick(&target_health);
    try std.testing.expectEqual(@as(f32, 1.0), tick25.damage_dealt);
    try std.testing.expectEqual(@as(f32, 19.0), target_health);
}

test "23. Poison I deals damage at tick 25 and tick 50" {
    var poison = PoisonStatusEffect.init(80);
    var target_health: f32 = 20.0;
    var total_damage: f32 = 0.0;
    for (0..50) |_| {
        const res = poison.tick(&target_health);
        total_damage += res.damage_dealt;
    }
    try std.testing.expectEqual(@as(f32, 2.0), total_damage);
    try std.testing.expectEqual(@as(f32, 18.0), target_health);
}

test "24. Poison I Normal difficulty (80 ticks) deals 3.0 HP total and expires" {
    var poison = PoisonStatusEffect.init(80);
    var target_health: f32 = 20.0;
    var total_damage: f32 = 0.0;
    var expired = false;

    for (0..80) |_| {
        const res = poison.tick(&target_health);
        total_damage += res.damage_dealt;
        if (res.poison_expired) expired = true;
    }

    try std.testing.expectEqual(@as(f32, 3.0), total_damage); // ticks 25, 50, 75
    try std.testing.expectEqual(@as(f32, 17.0), target_health);
    try std.testing.expect(expired);
    try std.testing.expect(!poison.active);
}

test "25. Poison I Hard difficulty (100 ticks) deals 4.0 HP total and expires" {
    var poison = PoisonStatusEffect.init(100);
    var target_health: f32 = 20.0;
    var total_damage: f32 = 0.0;
    var expired = false;

    for (0..100) |_| {
        const res = poison.tick(&target_health);
        total_damage += res.damage_dealt;
        if (res.poison_expired) expired = true;
    }

    try std.testing.expectEqual(@as(f32, 4.0), total_damage); // ticks 25, 50, 75, 100
    try std.testing.expectEqual(@as(f32, 16.0), target_health);
    try std.testing.expect(expired);
    try std.testing.expect(!poison.active);
}

test "26. Poison minimum health floor: clamps damage at exactly 1.0 HP" {
    var poison = PoisonStatusEffect.init(80);
    var target_health: f32 = 1.5; // only 0.5 above floor
    for (1..25) |_| {
        _ = poison.tick(&target_health);
    }
    const res = poison.tick(&target_health);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), res.damage_dealt, 0.001);
    try std.testing.expectEqual(@as(f32, 1.0), target_health);
    try std.testing.expect(res.reached_floor);
}

test "27. Poison minimum health floor: deals 0 damage when target already at 1.0 HP" {
    var poison = PoisonStatusEffect.init(80);
    var target_health: f32 = 1.0;
    for (0..25) |_| {
        _ = poison.tick(&target_health);
    }
    try std.testing.expectEqual(@as(f32, 1.0), target_health);
}

test "28. Poison NEVER kills target: stays at 0.8 HP if started below floor" {
    var poison = PoisonStatusEffect.init(80);
    var target_health: f32 = 0.8;
    for (0..80) |_| {
        const res = poison.tick(&target_health);
        try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
    }
    try std.testing.expectEqual(@as(f32, 0.8), target_health);
}

test "29. Inactive poison tick reports expired immediately with 0 damage" {
    var poison = PoisonStatusEffect.init(0);
    var target_health: f32 = 20.0;
    const res = poison.tick(&target_health);
    try std.testing.expect(res.poison_expired);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
}

test "30. Bogged naturally spawns with mushrooms and unsheared state" {
    const bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    try std.testing.expect(bogged.has_mushrooms);
    try std.testing.expect(!bogged.is_sheared);
    try std.testing.expect(bogged.has_moss);

    const app = bogged.getAppearance();
    try std.testing.expect(app.has_mushrooms);
    try std.testing.expect(!app.is_sheared);
    try std.testing.expect(app.has_moss);
    try std.testing.expect(app.mushroomCapVisible());
}

test "31. Shearing with Shears succeeds and removes mushroom cap" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedItem(&bogged, .shears, 0.2, 0.7);

    try std.testing.expect(res.success);
    try std.testing.expect(!bogged.has_mushrooms);
    try std.testing.expect(bogged.is_sheared);
    try std.testing.expect(bogged.has_moss); // moss remains!
    try std.testing.expect(!bogged.getAppearance().mushroomCapVisible());
}

test "32. Shearing consumes exactly 1 shears durability" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedTool(&bogged, .shears, 0.1, 0.9);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u16, 1), res.durability_consumed);
}

test "33. Shearing emits SoundEffect.shears_snip cue" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedWithRolls(&bogged, true, 0.0, 0.0);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(SoundEffect.shears_snip, res.sound_cue.?);
}

test "34. Shearing produces cosmetic moss and mushroom particle bursts" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedWithRolls(&bogged, true, 0.0, 0.0);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u32, 12), res.particles.moss_count);
    try std.testing.expectEqual(@as(u32, 8), res.particles.mushroom_count);
    try std.testing.expectEqual(@as(f32, 0.5), res.particles.spread);
}

test "35. Shearing drops exactly 2 mushrooms" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedWithRolls(&bogged, true, 0.4, 0.6);
    try std.testing.expectEqual(@as(usize, 2), res.mushrooms_dropped.len);
}

test "36. Shearing drops 2 Brown Mushrooms when both rolls < 0.5" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedWithRolls(&bogged, true, 0.1, 0.3);
    try std.testing.expectEqual(MushroomType.brown, res.mushrooms_dropped[0]);
    try std.testing.expectEqual(MushroomType.brown, res.mushrooms_dropped[1]);
}

test "37. Shearing drops 2 Red Mushrooms when both rolls >= 0.5" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedWithRolls(&bogged, true, 0.7, 0.85);
    try std.testing.expectEqual(MushroomType.red, res.mushrooms_dropped[0]);
    try std.testing.expectEqual(MushroomType.red, res.mushrooms_dropped[1]);
}

test "38. Shearing drops 1 Brown and 1 Red Mushroom (roll0 < 0.5, roll1 >= 0.5)" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedWithRolls(&bogged, true, 0.2, 0.8);
    try std.testing.expectEqual(MushroomType.brown, res.mushrooms_dropped[0]);
    try std.testing.expectEqual(MushroomType.red, res.mushrooms_dropped[1]);
}

test "39. Shearing drops 1 Red and 1 Brown Mushroom (roll0 >= 0.5, roll1 < 0.5)" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedWithRolls(&bogged, true, 0.9, 0.1);
    try std.testing.expectEqual(MushroomType.red, res.mushrooms_dropped[0]);
    try std.testing.expectEqual(MushroomType.brown, res.mushrooms_dropped[1]);
}

test "40. Single-shear restriction: already sheared Bogged rejects second shearing" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const first = shearBoggedWithRolls(&bogged, true, 0.2, 0.4);
    try std.testing.expect(first.success);

    const second = shearBoggedWithRolls(&bogged, true, 0.2, 0.4);
    try std.testing.expect(!second.success);
    try std.testing.expectEqual(ShearingFailureReason.already_sheared, second.reason);
    try std.testing.expectEqual(@as(u16, 0), second.durability_consumed);
}

test "41. Non-shears item fails interaction and does not consume durability" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedItem(&bogged, .bow, 0.1, 0.1);
    try std.testing.expect(!res.success);
    try std.testing.expectEqual(ShearingFailureReason.invalid_tool, res.reason);
    try std.testing.expectEqual(@as(u16, 0), res.durability_consumed);
    try std.testing.expect(bogged.has_mushrooms);
    try std.testing.expect(!bogged.is_sheared);
}

test "42. Non-shears tool category fails interaction" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const res = shearBoggedTool(&bogged, .sword, 0.5, 0.5);
    try std.testing.expect(!res.success);
    try std.testing.expectEqual(ShearingFailureReason.invalid_tool, res.reason);
    try std.testing.expectEqual(@as(u16, 0), res.durability_consumed);
}

test "43. Shearing with PRNG produces valid 2-mushroom output and consumes 1 durability" {
    var prng = std.Random.DefaultPrng.init(12345);
    var random = prng.random();
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });

    const res = shearBoggedPrng(&bogged, true, &random);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u16, 1), res.durability_consumed);
    try std.testing.expectEqual(@as(usize, 2), res.mushrooms_dropped.len);
}

test "44. Daylight burning: burns in direct daylight (skylight 15, clear sky, day)" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const env = EnvironmentalConditions{
        .is_daylight = true,
        .can_see_sky = true,
        .is_raining = false,
        .in_water = false,
        .in_powder_snow = false,
        .sky_light_level = 15,
    };
    const res = checkDaylightBurn(&bogged, env);
    try std.testing.expect(res.is_burning);
    try std.testing.expectEqual(@as(f32, 1.0), res.damage_to_mob);
    try std.testing.expectEqual(@as(f32, 15.0), bogged.health);
    try std.testing.expect(bogged.is_on_fire);
    try std.testing.expectEqual(SoundEffect.burn_sizzle, res.sound_cue.?);
    try std.testing.expectEqual(DaylightBurnStatus.burning, res.status);
}

test "45. Daylight burning rate is 1.0 HP fire damage per second" {
    try std.testing.expectEqual(@as(f32, 1.0), DAYLIGHT_FIRE_DAMAGE_PER_SECOND);
}

test "46. Daylight burning exemption: helmet equipped absorbs damage and protects mob" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    bogged.has_helmet = true;
    bogged.helmet_durability = 10;

    const env = EnvironmentalConditions{};
    const res = checkDaylightBurn(&bogged, env);

    try std.testing.expect(!res.is_burning);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_to_mob);
    try std.testing.expectEqual(@as(f32, 16.0), bogged.health); // No health loss
    try std.testing.expect(res.helmet_damaged);
    try std.testing.expect(!res.helmet_broke);
    try std.testing.expectEqual(@as(u16, 9), bogged.helmet_durability); // Lost 1 durability
    try std.testing.expectEqual(DaylightBurnStatus.protected_by_helmet, res.status);
}

test "47. Daylight burning exemption: helmet breaking exposes mob to subsequent daylight burning" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    bogged.has_helmet = true;
    bogged.helmet_durability = 1;

    const env = EnvironmentalConditions{};
    const res1 = checkDaylightBurn(&bogged, env);
    try std.testing.expect(!res1.is_burning);
    try std.testing.expect(res1.helmet_broke);
    try std.testing.expect(!bogged.has_helmet); // Helmet broke

    // Subsequent tick burns the mob!
    const res2 = checkDaylightBurn(&bogged, env);
    try std.testing.expect(res2.is_burning);
    try std.testing.expectEqual(@as(f32, 1.0), res2.damage_to_mob);
    try std.testing.expectEqual(@as(f32, 15.0), bogged.health);
}

test "48. Daylight burning exemption: submerged in water prevents burning" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const env = EnvironmentalConditions{ .in_water = true };
    const res = checkDaylightBurn(&bogged, env);
    try std.testing.expect(!res.is_burning);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_to_mob);
    try std.testing.expectEqual(DaylightBurnStatus.protected_by_water, res.status);
}

test "49. Daylight burning exemption: in powder snow prevents burning" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const env = EnvironmentalConditions{ .in_powder_snow = true };
    const res = checkDaylightBurn(&bogged, env);
    try std.testing.expect(!res.is_burning);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_to_mob);
    try std.testing.expectEqual(DaylightBurnStatus.protected_by_powder_snow, res.status);
}

test "50. Daylight burning exemption: rain prevents burning" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const env = EnvironmentalConditions{ .is_raining = true };
    const res = checkDaylightBurn(&bogged, env);
    try std.testing.expect(!res.is_burning);
    try std.testing.expectEqual(DaylightBurnStatus.protected_by_rain, res.status);
}

test "51. Daylight burning exemption: shade / roof (cannot see sky) prevents burning" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const env = EnvironmentalConditions{ .can_see_sky = false };
    const res = checkDaylightBurn(&bogged, env);
    try std.testing.expect(!res.is_burning);
    try std.testing.expectEqual(DaylightBurnStatus.protected_by_shade, res.status);
}

test "52. Daylight burning exemption: night time / low light prevents burning" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const env = EnvironmentalConditions{ .is_daylight = false, .sky_light_level = 4 };
    const res = checkDaylightBurn(&bogged, env);
    try std.testing.expect(!res.is_burning);
    try std.testing.expectEqual(DaylightBurnStatus.protected_by_night, res.status);
}

test "53. Daylight burning: immune mob does not burn" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    bogged.burns_in_sunlight = false;
    const env = EnvironmentalConditions{};
    const res = checkDaylightBurn(&bogged, env);
    try std.testing.expect(!res.is_burning);
    try std.testing.expectEqual(DaylightBurnStatus.immune, res.status);
}

test "54. Defeat drops: bones range 0..2 at Looting 0" {
    try std.testing.expectEqual(@as(u8, 2), maxBones(0));
}

test "55. Defeat drops: arrows range 0..2 at Looting 0" {
    try std.testing.expectEqual(@as(u8, 2), maxArrows(0));
}

test "56. Defeat drops: Looting increments max bones and arrows by +1 per level" {
    try std.testing.expectEqual(@as(u8, 3), maxBones(1));
    try std.testing.expectEqual(@as(u8, 4), maxBones(2));
    try std.testing.expectEqual(@as(u8, 5), maxBones(3));

    try std.testing.expectEqual(@as(u8, 3), maxArrows(1));
    try std.testing.expectEqual(@as(u8, 4), maxArrows(2));
    try std.testing.expectEqual(@as(u8, 5), maxArrows(3));
}

test "57. Defeat drops: Poison arrow base drop chance is 50% on player kill" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), poisonArrowDropChance(0, true), 0.001);
}

test "58. Defeat drops: Poison arrow chance scales +10% per Looting level" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), poisonArrowDropChance(1, true), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.70), poisonArrowDropChance(2, true), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.80), poisonArrowDropChance(3, true), 0.001);
}

test "59. Defeat drops: Poison arrow chance is capped at 80% for Looting >= 3" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.80), poisonArrowDropChance(4, true), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.80), poisonArrowDropChance(5, true), 0.001);
}

test "60. Defeat drops: Non-player kill never drops Poison-tipped arrow (0% chance)" {
    try std.testing.expectEqual(@as(f32, 0.0), poisonArrowDropChance(0, false));
    try std.testing.expectEqual(@as(f32, 0.0), poisonArrowDropChance(1, false));
    try std.testing.expectEqual(@as(f32, 0.0), poisonArrowDropChance(3, false));
}

test "61. Defeat drops: Bow rare drop base chance is 8.5%" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.085), bowDropChance(0), 0.0001);
}

test "62. Defeat drops: Bow rare drop scales +1.0% per Looting level" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.095), bowDropChance(1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.105), bowDropChance(2), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.115), bowDropChance(3), 0.0001);
}

test "63. Defeat drops: Experience reward is exactly 5 XP points" {
    try std.testing.expectEqual(@as(u32, 5), EXPERIENCE_POINTS_DROP);
    const loot = rollDefeatLoot(0, true, 0.5, 0.5, 0.1, 0.9);
    try std.testing.expectEqual(@as(u32, 5), loot.experience_points);
}

test "64. Deterministic defeat loot roll yields expected item counts" {
    // roll_bones = 0.999 -> max bones (2 at Looting 0)
    // roll_arrows = 0.0 -> 0 arrows
    // roll_poison = 0.30 -> succeeds at Looting 0 (chance 0.50) -> 1 poison arrow
    // roll_bow = 0.05 -> succeeds at Looting 0 (chance 0.085) -> 1 bow
    const loot = rollDefeatLoot(0, true, 0.999, 0.0, 0.30, 0.05);
    try std.testing.expectEqual(@as(u8, 2), loot.bones);
    try std.testing.expectEqual(@as(u8, 0), loot.arrows);
    try std.testing.expectEqual(@as(u8, 1), loot.poison_arrows);
    try std.testing.expectEqual(@as(u8, 1), loot.bows);
    try std.testing.expectEqual(@as(u32, 5), loot.experience_points);
}

test "65. Non-player kill roll yields 0 poison arrows even with low roll" {
    const loot = rollDefeatLoot(3, false, 0.5, 0.5, 0.01, 0.9);
    try std.testing.expectEqual(@as(u8, 0), loot.poison_arrows);
}

test "66. Defeat loot roll with PRNG produces valid bounded loot" {
    var prng = std.Random.DefaultPrng.init(54321);
    var random = prng.random();

    for (0..20) |_| {
        const loot = rollDefeatLootWithPrng(2, true, &random);
        try std.testing.expect(loot.bones <= maxBones(2));
        try std.testing.expect(loot.arrows <= maxArrows(2));
        try std.testing.expect(loot.poison_arrows <= 1);
        try std.testing.expect(loot.bows <= 1);
        try std.testing.expectEqual(@as(u32, 5), loot.experience_points);
    }
}

test "67. Taking damage reduces health and flags death at 0 HP" {
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    bogged.takeDamage(6.0);
    try std.testing.expectEqual(@as(f32, 10.0), bogged.health);
    try std.testing.expect(!bogged.is_dead);

    bogged.takeDamage(10.0);
    try std.testing.expectEqual(@as(f32, 0.0), bogged.health);
    try std.testing.expect(bogged.is_dead);

    // Further damage when dead does nothing
    bogged.takeDamage(5.0);
    try std.testing.expectEqual(@as(f32, 0.0), bogged.health);
}

test "68. Full combat integration: shot, hit, poison ticking, shearing, and daylight burn" {
    // 1. Bogged shoots player
    var bogged = BoggedEntity.init(.{ 0.0, 0.0, 0.0 });
    const player_pos = [3]f32{ 5.0, 0.0, 0.0 };
    var arrow = bogged.shoot(player_pos, .normal).?;
    // Arrow flies to target position
    arrow.position = .{ 5.0, 1.0, 0.0 };

    // 2. Arrow hits player
    var player_health: f32 = 20.0;
    var player_poison = PoisonStatusEffect.init(0);
    const hit = checkAndApplyArrowHit(&arrow, player_pos, 0.6, 1.8, &player_health, &player_poison);
    try std.testing.expect(hit.hit);
    try std.testing.expectEqual(@as(f32, 16.0), player_health);
    try std.testing.expect(player_poison.active);

    // 3. Poison ticks for 80 ticks on player
    for (0..80) |_| {
        _ = player_poison.tick(&player_health);
    }
    try std.testing.expectEqual(@as(f32, 13.0), player_health); // -3.0 HP from poison
    try std.testing.expect(!player_poison.active);

    // 4. Player shears Bogged
    const shear_res = shearBoggedItem(&bogged, .shears, 0.2, 0.8);
    try std.testing.expect(shear_res.success);
    try std.testing.expect(bogged.is_sheared);

    // 5. Sun rises, Bogged burns
    const env = EnvironmentalConditions{};
    const burn_res = checkDaylightBurn(&bogged, env);
    try std.testing.expect(burn_res.is_burning);
    try std.testing.expectEqual(@as(f32, 15.0), bogged.health);
}
