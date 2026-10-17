const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Health and combat constants
pub const fox_max_health: f32 = 20.0; // 10 hearts
pub const fox_base_attack_damage: f32 = 2.0; // 1 heart
pub const totem_revive_health: f32 = 10.0; // Restored HP when Totem of Undying triggers

/// Pounce trajectory & leaping constants
pub const pounce_peak_height: f32 = 3.5; // 3.5 blocks high leap
pub const fence_height: f32 = 1.5; // 1.5 blocks fence height (fox clears easily)
pub const pounce_gravity: f32 = 20.0; // Gravitational acceleration (blocks/s^2)
pub const snow_stuck_duration: f32 = 2.0; // 2.0 seconds stuck head-first in snow on miss
pub const pounce_crouch_duration: f32 = 1.5; // Crouch preparation time before leaping

/// Chorus fruit & interaction constants
pub const chorus_warp_max_radius: f32 = 8.0; // Maximum distance for chorus fruit warp
pub const chorus_fruit_heal_amount: f32 = 4.0; // 2 hearts healed from chorus fruit
pub const sweet_berries_heal_amount: f32 = 2.0; // 1 heart healed from sweet berries
pub const wake_up_proximity_radius: f32 = 12.0; // Distance to wake sleeping fox if not sneaking

/// Item & tag constants matching Zigcraft / Minecraft definitions
pub const TotemOfUndyingItemId: u16 = 330;
pub const ChorusFruitItemId: u16 = 156;
pub const SweetBerriesItemId: u16 = 355;
pub const GlowBerriesItemId: u16 = 324;
pub const EmeraldItemId: u16 = 273;
pub const DiamondItemId: u16 = 221;
pub const IronSwordItemId: u16 = 31;
pub const DiamondSwordItemId: u16 = 220;
pub const RawChickenItemId: u16 = 365;
pub const CookedChickenItemId: u16 = 366;
pub const RawRabbitItemId: u16 = 411;
pub const CookedRabbitItemId: u16 = 412;
pub const RawCodItemId: u16 = 184;
pub const CookedCodItemId: u16 = 185;
pub const RawSalmonItemId: u16 = 191;
pub const CookedSalmonItemId: u16 = 192;
pub const AppleItemId: u16 = 29;
pub const BreadItemId: u16 = 11;

// ============================================================================
// Enums
// ============================================================================

/// Fox variant: Red Taiga or Snow / White Taiga.
pub const FoxVariant = enum(u8) {
    red_taiga = 0,
    white_snow_taiga = 1,

    pub fn name(self: FoxVariant) []const u8 {
        return switch (self) {
            .red_taiga => "Red Taiga",
            .white_snow_taiga => "White Snow Taiga",
        };
    }
};

/// Prey mob types that foxes hunt.
pub const FoxPrey = enum(u8) {
    chicken = 0,
    rabbit = 1,
    fish = 2,
    baby_turtle = 3,
};

// ============================================================================
// Trajectory & Result Structures
// ============================================================================

/// Output of pounce trajectory calculation.
pub const PounceArc = struct {
    vx: f32,
    vy: f32,
    vz: f32,
    can_clear_fence: bool,
};

/// Result of fatal damage evaluation for a Fox.
pub const FoxFatalDamageResult = struct {
    survived: bool,
    consumed_totem: bool,
};

/// Result of a pounce landing.
pub const PounceLandingResult = struct {
    stuck_in_snow: bool,
    stuck_timer: f32,
};

/// Result of eating a held mouth item (e.g. Chorus Fruit).
pub const FoxEatResult = struct {
    ate_food: bool,
    healed: f32,
    warped: bool,
    new_pos: [3]f32,
    consumed: bool,
};

// ============================================================================
// State
// ============================================================================

/// Complete runtime state for a Taiga Fox entity.
pub const FoxState = struct {
    variant: FoxVariant,
    mouth_item_id: u16 = 0,
    is_sleeping: bool = false,
    is_crouching_to_pounce: bool = false,
    stuck_head_in_snow_timer: f32 = 0.0,
    trusted_player_id: ?u32 = null,

    // Kinematic and biological tracking
    health: f32 = fox_max_health,
    pos: [3]f32 = .{ 0.0, 0.0, 0.0 },
    is_pouncing: bool = false,
    crouch_timer: f32 = 0.0,

    pub fn init(variant: FoxVariant, pos: [3]f32) FoxState {
        return .{
            .variant = variant,
            .mouth_item_id = 0,
            .is_sleeping = false,
            .is_crouching_to_pounce = false,
            .stuck_head_in_snow_timer = 0.0,
            .trusted_player_id = null,
            .health = fox_max_health,
            .pos = pos,
            .is_pouncing = false,
            .crouch_timer = 0.0,
        };
    }

    pub fn initBred(variant: FoxVariant, trusted_player_id: u32, pos: [3]f32) FoxState {
        var state = init(variant, pos);
        state.trusted_player_id = trusted_player_id;
        return state;
    }

    pub fn isStuckInSnow(self: FoxState) bool {
        return self.stuck_head_in_snow_timer > 0.0;
    }

    pub fn canMove(self: FoxState) bool {
        return !self.is_sleeping and !self.isStuckInSnow() and !self.is_crouching_to_pounce;
    }

    pub fn trustsPlayer(self: FoxState, player_id: u32) bool {
        if (self.trusted_player_id) |t_id| {
            return t_id == player_id;
        }
        return false;
    }

    pub fn wakeUp(self: *FoxState) void {
        self.is_sleeping = false;
    }

    pub fn startCrouching(self: *FoxState) void {
        if (self.is_sleeping or self.isStuckInSnow() or self.is_pouncing) return;
        self.is_crouching_to_pounce = true;
        self.crouch_timer = 0.0;
    }

    pub fn pickUpItem(self: *FoxState, item_id: u16) bool {
        if (item_id == 0) return false;
        if (self.mouth_item_id == 0) {
            self.mouth_item_id = item_id;
            return true;
        }
        if (shouldSwapMouthItemForFood(isFoodItem(self.mouth_item_id), isFoodItem(item_id))) {
            self.mouth_item_id = item_id;
            return true;
        }
        return false;
    }

    pub fn dropMouthItem(self: *FoxState) ?u16 {
        if (self.mouth_item_id == 0) return null;
        const dropped = self.mouth_item_id;
        self.mouth_item_id = 0;
        return dropped;
    }

    pub fn tick(self: *FoxState, dt: f32, is_day: bool, is_thunderstorm: bool, has_tree_shade: bool) void {
        if (self.stuck_head_in_snow_timer > 0.0) {
            self.stuck_head_in_snow_timer = @max(0.0, self.stuck_head_in_snow_timer - dt);
            self.is_sleeping = false;
            self.is_crouching_to_pounce = false;
            return;
        }

        if (self.is_pouncing) {
            self.is_sleeping = false;
            self.is_crouching_to_pounce = false;
            return;
        }

        if (shouldSleep(is_day, is_thunderstorm, has_tree_shade)) {
            self.is_sleeping = true;
            self.is_crouching_to_pounce = false;
            self.crouch_timer = 0.0;
        } else {
            self.is_sleeping = false;
        }

        if (self.is_crouching_to_pounce) {
            self.crouch_timer += dt;
        } else {
            self.crouch_timer = 0.0;
        }
    }
};

// ============================================================================
// Core Mechanics Functions
// ============================================================================

/// Food swap priority: Foxes always drop a non-food item (Emerald, Diamond, Sword)
/// to pick up a dropped food item (Sweet Berries, Chicken, etc.).
pub fn shouldSwapMouthItemForFood(current_mouth_is_food: bool, dropped_item_is_food: bool) bool {
    return dropped_item_is_food and !current_mouth_is_food;
}

/// Helper that checks swap priority using item IDs.
pub fn shouldSwapItems(current_item: u16, dropped_item: u16) bool {
    return shouldSwapMouthItemForFood(isFoodItem(current_item), isFoodItem(dropped_item));
}

/// Identifies whether an item ID is considered food by foxes.
pub fn isFoodItem(item_id: u16) bool {
    return switch (item_id) {
        SweetBerriesItemId,
        GlowBerriesItemId,
        ChorusFruitItemId,
        RawChickenItemId,
        CookedChickenItemId,
        RawRabbitItemId,
        CookedRabbitItemId,
        RawCodItemId,
        CookedCodItemId,
        RawSalmonItemId,
        CookedSalmonItemId,
        AppleItemId,
        BreadItemId,
        => true,
        else => false,
    };
}

/// Identifies whether an item ID can be used to breed foxes (Sweet Berries or Glow Berries).
pub fn isBreedingFood(item_id: u16) bool {
    return item_id == SweetBerriesItemId or item_id == GlowBerriesItemId;
}

/// If a Fox holds a Totem of Undying in its mouth when dealt fatal damage,
/// the Fox triggers the Totem and revives itself!
pub fn resolveFoxFatalDamage(
    state: *FoxState,
    fatal_damage: f32,
    mouth_holds_totem_of_undying: bool,
) FoxFatalDamageResult {
    const has_totem = mouth_holds_totem_of_undying or (state.mouth_item_id == TotemOfUndyingItemId);
    const would_be_fatal = (state.health - fatal_damage) <= 0.0;

    if (!would_be_fatal) {
        state.health -= fatal_damage;
        return .{
            .survived = true,
            .consumed_totem = false,
        };
    }

    if (has_totem) {
        state.health = totem_revive_health;
        state.mouth_item_id = 0;
        state.is_sleeping = false;
        state.stuck_head_in_snow_timer = 0.0;
        return .{
            .survived = true,
            .consumed_totem = true,
        };
    }

    state.health = @min(0.0, state.health - fatal_damage);
    state.is_sleeping = false;
    return .{
        .survived = false,
        .consumed_totem = false,
    };
}

/// Leaps 3.5 blocks high into the air over fences to pounce on chickens/rabbits/fish;
/// returns horizontal velocities vx, vz, vertical velocity vy, and whether it clears fences.
pub fn computeFoxPounceArc(fox_y: f32, target_dx: f32, target_dz: f32) PounceArc {
    _ = fox_y;
    // Apex vertical velocity: vy = sqrt(2 * g * h)
    const vy = @sqrt(2.0 * pounce_gravity * pounce_peak_height);
    // Flight time to apex: t_apex = vy / g
    // Total flight time to land at the same elevation: t_flight = 2 * t_apex
    const t_flight = 2.0 * (vy / pounce_gravity);
    const vx = if (t_flight > 0.0) target_dx / t_flight else 0.0;
    const vz = if (t_flight > 0.0) target_dz / t_flight else 0.0;
    const can_clear_fence = (pounce_peak_height > fence_height);

    return .{
        .vx = vx,
        .vy = vy,
        .vz = vz,
        .can_clear_fence = can_clear_fence,
    };
}

/// Handles landing after a pounce leap. If landing on snow and missing the target,
/// the fox gets stuck head-first in the snow for 2.0s!
pub fn resolvePounceLanding(state: *FoxState, hit_target: bool, landing_on_snow: bool) PounceLandingResult {
    state.is_pouncing = false;
    state.is_crouching_to_pounce = false;

    if (!hit_target and landing_on_snow) {
        state.stuck_head_in_snow_timer = snow_stuck_duration;
        return .{
            .stuck_in_snow = true,
            .stuck_timer = snow_stuck_duration,
        };
    }

    state.stuck_head_in_snow_timer = 0.0;
    return .{
        .stuck_in_snow = false,
        .stuck_timer = 0.0,
    };
}

/// Complete immunity to Sweet Berry Bush movement slow and prickle damage.
pub fn foxTakesBerryBushDamage() bool {
    return false;
}

/// Movement speed multiplier in sweet berry bushes (1.0 = no slowdown).
pub fn foxBerryBushSpeedMultiplier() f32 {
    return 1.0;
}

/// Complete berry bush immunity flag.
pub fn isImmuneToBerryBushes() bool {
    return true;
}

/// Prickle damage calculation for foxes in bushes (always 0.0).
pub fn calculateFoxBerryBushDamage(is_moving: bool, dt: f32) f32 {
    _ = is_moving;
    _ = dt;
    return 0.0;
}

/// Determines whether a fox should sleep.
/// Nocturnal behavior: sleeps curled up under tree shade during daytime unless thunderstorming; hunts at night.
pub fn shouldSleep(is_day: bool, is_thunderstorm: bool, has_tree_shade: bool) bool {
    if (!is_day) return false;
    if (is_thunderstorm) return false;
    return has_tree_shade;
}

/// Whether it is hunting time for the fox.
pub fn isHuntingTime(is_day: bool, is_thunderstorm: bool) bool {
    return !is_day or is_thunderstorm;
}

/// Determines if a disturbance (e.g. proximity of another entity or damage) wakes the sleeping fox.
/// Sneaking entities do not disturb sleeping foxes.
pub fn checkSleepDisturbance(dist_to_entity: f32, is_entity_sneaking: bool, took_damage: bool) bool {
    if (took_damage) return true;
    if (!is_entity_sneaking and dist_to_entity < wake_up_proximity_radius) return true;
    return false;
}

/// Bred foxes trust the player and defend them against attackers.
pub fn shouldDefendTrustedPlayer(state: FoxState, target_entity_id: u32, attacker_id: u32) bool {
    const trusted_id = state.trusted_player_id orelse return false;
    if (target_entity_id == trusted_id and attacker_id != trusted_id) {
        return true;
    }
    return false;
}

/// Computes attack damage. If carrying an Iron or Diamond Sword in its mouth,
/// the fox gains the sword's damage boost!
pub fn computeAttackDamage(state: FoxState) f32 {
    var dmg = fox_base_attack_damage;
    if (state.mouth_item_id == IronSwordItemId) {
        dmg += 6.0;
    } else if (state.mouth_item_id == DiamondSwordItemId) {
        dmg += 7.0;
    }
    return dmg;
}

/// Chorus Fruit mouth warp: If a Fox holds a Chorus Fruit in its mouth and eats it,
/// the fruit is consumed, the fox heals, and it teleports up to 8 blocks away!
pub fn resolveChorusFruitMouthWarp(
    state: *FoxState,
    current_pos: [3]f32,
    offset: [3]f32,
) FoxEatResult {
    if (state.mouth_item_id != ChorusFruitItemId) {
        return .{
            .ate_food = false,
            .healed = 0.0,
            .warped = false,
            .new_pos = current_pos,
            .consumed = false,
        };
    }

    const dist_sq = offset[0] * offset[0] + offset[1] * offset[1] + offset[2] * offset[2];
    if (dist_sq > chorus_warp_max_radius * chorus_warp_max_radius) {
        return .{
            .ate_food = false,
            .healed = 0.0,
            .warped = false,
            .new_pos = current_pos,
            .consumed = false,
        };
    }

    const target_pos = [3]f32{
        current_pos[0] + offset[0],
        current_pos[1] + offset[1],
        current_pos[2] + offset[2],
    };

    state.mouth_item_id = 0;
    state.health = @min(fox_max_health, state.health + chorus_fruit_heal_amount);
    state.pos = target_pos;

    return .{
        .ate_food = true,
        .healed = chorus_fruit_heal_amount,
        .warped = true,
        .new_pos = target_pos,
        .consumed = true,
    };
}

/// Selects fox variant according to biome.
pub fn variantForBiome(is_snowy_biome: bool) FoxVariant {
    return if (is_snowy_biome) .white_snow_taiga else .red_taiga;
}

/// 50/50 kit variant inheritance when breeding red and snow foxes.
pub fn breedOffspringVariant(parent1: FoxVariant, parent2: FoxVariant, roll_fifty_fifty: bool) FoxVariant {
    if (parent1 == parent2) return parent1;
    return if (roll_fifty_fifty) parent1 else parent2;
}

// ============================================================================
// Unit Tests (21 Comprehensive Tests)
// ============================================================================

test "FoxVariant discriminants and string names" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(FoxVariant.red_taiga));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(FoxVariant.white_snow_taiga));
    try std.testing.expectEqualStrings("Red Taiga", FoxVariant.red_taiga.name());
    try std.testing.expectEqualStrings("White Snow Taiga", FoxVariant.white_snow_taiga.name());
}

test "variant selection from biome and genetics 50/50 inheritance" {
    try std.testing.expectEqual(FoxVariant.red_taiga, variantForBiome(false));
    try std.testing.expectEqual(FoxVariant.white_snow_taiga, variantForBiome(true));

    // Both parents same variant
    try std.testing.expectEqual(FoxVariant.red_taiga, breedOffspringVariant(.red_taiga, .red_taiga, true));
    try std.testing.expectEqual(FoxVariant.red_taiga, breedOffspringVariant(.red_taiga, .red_taiga, false));
    try std.testing.expectEqual(FoxVariant.white_snow_taiga, breedOffspringVariant(.white_snow_taiga, .white_snow_taiga, true));

    // Cross-breeding 50/50 roll
    try std.testing.expectEqual(FoxVariant.red_taiga, breedOffspringVariant(.red_taiga, .white_snow_taiga, true));
    try std.testing.expectEqual(FoxVariant.white_snow_taiga, breedOffspringVariant(.red_taiga, .white_snow_taiga, false));
}

test "nocturnal behavior: sleeps under tree shade during daytime" {
    // Daytime with tree shade and clear weather -> sleep curled up
    try std.testing.expect(shouldSleep(true, false, true));
    try std.testing.expect(!isHuntingTime(true, false));
}

test "nocturnal behavior: exposed to direct sun without tree shade does not sleep" {
    // Daytime without tree shade -> does not sleep (seeks shade)
    try std.testing.expect(!shouldSleep(true, false, false));
}

test "nocturnal behavior: thunderstorm keeps fox awake during daytime even in shade" {
    // Daytime during thunderstorm -> awake and alert
    try std.testing.expect(!shouldSleep(true, true, true));
    try std.testing.expect(isHuntingTime(true, true));
}

test "nocturnal behavior: nighttime is hunting time and fox does not sleep" {
    // Nighttime -> hunts, never sleeps
    try std.testing.expect(!shouldSleep(false, false, true));
    try std.testing.expect(!shouldSleep(false, false, false));
    try std.testing.expect(isHuntingTime(false, false));
}

test "sleep disturbance: disturbance and damage wake sleeping fox, sneaking avoids waking" {
    // Sneaking player nearby does not wake fox
    try std.testing.expect(!checkSleepDisturbance(4.0, true, false));
    // Non-sneaking player nearby wakes fox
    try std.testing.expect(checkSleepDisturbance(4.0, false, false));
    // Non-sneaking player far away (>12 blocks) does not wake fox
    try std.testing.expect(!checkSleepDisturbance(16.0, false, false));
    // Damage always wakes fox regardless of sneaking or distance
    try std.testing.expect(checkSleepDisturbance(50.0, true, true));
}

test "shouldSwapMouthItemForFood prioritizes food over non-food items" {
    // Non-food in mouth and food dropped -> SWAP!
    try std.testing.expect(shouldSwapMouthItemForFood(false, true));
    // Already holding food and food dropped -> NO SWAP (keeps current food)
    try std.testing.expect(!shouldSwapMouthItemForFood(true, true));
    // Holding non-food and non-food dropped -> NO SWAP
    try std.testing.expect(!shouldSwapMouthItemForFood(false, false));
    // Holding food and non-food dropped -> NO SWAP
    try std.testing.expect(!shouldSwapMouthItemForFood(true, false));
}

test "shouldSwapItems handles concrete item IDs (Emerald dropped for Sweet Berries or Chicken)" {
    // Fox holding an Emerald drops it for Sweet Berries
    try std.testing.expect(shouldSwapItems(EmeraldItemId, SweetBerriesItemId));
    // Fox holding a Diamond Sword drops it for Raw Chicken
    try std.testing.expect(shouldSwapItems(DiamondSwordItemId, RawChickenItemId));
    // Fox holding Sweet Berries does NOT drop them for an Emerald
    try std.testing.expect(!shouldSwapItems(SweetBerriesItemId, EmeraldItemId));
    // Fox holding Sweet Berries does NOT drop them for Raw Chicken
    try std.testing.expect(!shouldSwapItems(SweetBerriesItemId, RawChickenItemId));
}

test "resolveFoxFatalDamage: Totem of Undying in mouth revives fox upon fatal damage" {
    var fox = FoxState.init(.red_taiga, .{ 0, 64, 0 });
    fox.health = 5.0;
    fox.mouth_item_id = TotemOfUndyingItemId;
    fox.is_sleeping = true;

    const result = resolveFoxFatalDamage(&fox, 15.0, true);

    try std.testing.expect(result.survived);
    try std.testing.expect(result.consumed_totem);
    try std.testing.expectEqual(@as(u16, 0), fox.mouth_item_id);
    try std.testing.expectEqual(totem_revive_health, fox.health);
    try std.testing.expect(!fox.is_sleeping);
}

test "resolveFoxFatalDamage: non-fatal damage does not consume Totem" {
    var fox = FoxState.init(.white_snow_taiga, .{ 10, 70, -5 });
    fox.health = 20.0;
    fox.mouth_item_id = TotemOfUndyingItemId;

    const result = resolveFoxFatalDamage(&fox, 6.0, true);

    try std.testing.expect(result.survived);
    try std.testing.expect(!result.consumed_totem);
    try std.testing.expectEqual(TotemOfUndyingItemId, fox.mouth_item_id);
    try std.testing.expectEqual(@as(f32, 14.0), fox.health);
}

test "resolveFoxFatalDamage: fatal damage without Totem kills fox" {
    var fox = FoxState.init(.red_taiga, .{ 0, 64, 0 });
    fox.health = 6.0;
    fox.mouth_item_id = EmeraldItemId;

    const result = resolveFoxFatalDamage(&fox, 12.0, false);

    try std.testing.expect(!result.survived);
    try std.testing.expect(!result.consumed_totem);
    try std.testing.expect(fox.health <= 0.0);
}

test "computeFoxPounceArc calculates 3.5 block leap velocity and clears 1.5 block fence" {
    const arc = computeFoxPounceArc(64.0, 4.0, 3.0);

    // Fence clearance
    try std.testing.expect(arc.can_clear_fence);

    // Vertical apex velocity check: vy^2 / (2 * g) must equal 3.5 blocks
    const calculated_peak = (arc.vy * arc.vy) / (2.0 * pounce_gravity);
    try std.testing.expectApproxEqAbs(pounce_peak_height, calculated_peak, 0.001);

    // Horizontal velocities must cover target_dx and target_dz in total flight time
    const t_flight = 2.0 * (arc.vy / pounce_gravity);
    const covered_x = arc.vx * t_flight;
    const covered_z = arc.vz * t_flight;
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), covered_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), covered_z, 0.001);
}

test "pounce landing on snow with missed target gets stuck head-first for 2.0s" {
    var fox = FoxState.init(.white_snow_taiga, .{ 0, 64, 0 });
    fox.is_pouncing = true;

    const landing = resolvePounceLanding(&fox, false, true);

    try std.testing.expect(landing.stuck_in_snow);
    try std.testing.expectEqual(snow_stuck_duration, landing.stuck_timer);
    try std.testing.expectEqual(snow_stuck_duration, fox.stuck_head_in_snow_timer);
    try std.testing.expect(!fox.is_pouncing);
    try std.testing.expect(fox.isStuckInSnow());
    try std.testing.expect(!fox.canMove());
}

test "pounce landing on non-snow or hit target does not get stuck" {
    var fox = FoxState.init(.red_taiga, .{ 0, 64, 0 });

    // Missed on grass/dirt
    const landing_dirt = resolvePounceLanding(&fox, false, false);
    try std.testing.expect(!landing_dirt.stuck_in_snow);
    try std.testing.expectEqual(@as(f32, 0.0), fox.stuck_head_in_snow_timer);

    // Hit target on snow
    const landing_hit = resolvePounceLanding(&fox, true, true);
    try std.testing.expect(!landing_hit.stuck_in_snow);
    try std.testing.expectEqual(@as(f32, 0.0), fox.stuck_head_in_snow_timer);
}

test "stuck in snow timer ticks down and un-freezes fox" {
    var fox = FoxState.init(.white_snow_taiga, .{ 0, 64, 0 });
    fox.stuck_head_in_snow_timer = 2.0;

    // Tick 1.0 second
    fox.tick(1.0, true, false, false);
    try std.testing.expectEqual(@as(f32, 1.0), fox.stuck_head_in_snow_timer);
    try std.testing.expect(fox.isStuckInSnow());
    try std.testing.expect(!fox.canMove());

    // Tick remaining 1.0 second
    fox.tick(1.0, true, false, false);
    try std.testing.expectEqual(@as(f32, 0.0), fox.stuck_head_in_snow_timer);
    try std.testing.expect(!fox.isStuckInSnow());
    try std.testing.expect(fox.canMove());
}

test "berry bush immunity: zero damage and normal movement speed" {
    try std.testing.expect(!foxTakesBerryBushDamage());
    try std.testing.expect(isImmuneToBerryBushes());
    try std.testing.expectEqual(@as(f32, 1.0), foxBerryBushSpeedMultiplier());
    try std.testing.expectEqual(@as(f32, 0.0), calculateFoxBerryBushDamage(true, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), calculateFoxBerryBushDamage(false, 0.5));
}

test "trusted player defense: defends trusted player against hostile attacker" {
    var bred_fox = FoxState.initBred(.red_taiga, 101, .{ 0, 64, 0 });
    try std.testing.expect(bred_fox.trustsPlayer(101));
    try std.testing.expect(!bred_fox.trustsPlayer(999));

    // Attacker 202 attacks trusted player 101 -> fox defends!
    try std.testing.expect(shouldDefendTrustedPlayer(bred_fox, 101, 202));

    // Trusted player 101 attacks someone -> fox does NOT attack player 101
    try std.testing.expect(!shouldDefendTrustedPlayer(bred_fox, 101, 101));

    // Another player attacked -> fox does not defend non-trusted player
    try std.testing.expect(!shouldDefendTrustedPlayer(bred_fox, 303, 202));

    // Wild fox without trusted player defends no one
    const wild_fox = FoxState.init(.white_snow_taiga, .{ 0, 64, 0 });
    try std.testing.expect(!shouldDefendTrustedPlayer(wild_fox, 101, 202));
}

test "mouth item carrying: holding sword in mouth increases attack damage" {
    var fox = FoxState.init(.red_taiga, .{ 0, 64, 0 });
    try std.testing.expectEqual(fox_base_attack_damage, computeAttackDamage(fox));

    fox.mouth_item_id = IronSwordItemId;
    try std.testing.expectEqual(@as(f32, 8.0), computeAttackDamage(fox));

    fox.mouth_item_id = DiamondSwordItemId;
    try std.testing.expectEqual(@as(f32, 9.0), computeAttackDamage(fox));
}

test "Chorus fruit warp: eating chorus fruit teleports fox within 8-block radius and heals" {
    var fox = FoxState.init(.red_taiga, .{ 10.0, 64.0, 20.0 });
    fox.health = 12.0;
    fox.mouth_item_id = ChorusFruitItemId;

    const offset: [3]f32 = .{ 4.0, 1.0, -3.0 };
    const result = resolveChorusFruitMouthWarp(&fox, fox.pos, offset);

    try std.testing.expect(result.warped);
    try std.testing.expect(result.consumed);
    try std.testing.expectEqual(chorus_fruit_heal_amount, result.healed);
    try std.testing.expectEqual(@as(u16, 0), fox.mouth_item_id);
    try std.testing.expectEqual(@as(f32, 16.0), fox.health);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), fox.pos[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 65.0), fox.pos[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 17.0), fox.pos[2], 0.001);

    // Rejects warp beyond 8 blocks radius
    fox.mouth_item_id = ChorusFruitItemId;
    const far_offset: [3]f32 = .{ 9.0, 0.0, 0.0 };
    const invalid_result = resolveChorusFruitMouthWarp(&fox, fox.pos, far_offset);
    try std.testing.expect(!invalid_result.warped);
    try std.testing.expect(!invalid_result.consumed);
    try std.testing.expectEqual(ChorusFruitItemId, fox.mouth_item_id);
}

test "FoxState tick updates sleeping state based on daytime, weather, and shade" {
    var fox = FoxState.init(.red_taiga, .{ 0, 64, 0 });

    // Tick under day and shade -> falls asleep
    fox.tick(0.5, true, false, true);
    try std.testing.expect(fox.is_sleeping);

    // Thunderstorm begins -> wakes up immediately
    fox.tick(0.5, true, true, true);
    try std.testing.expect(!fox.is_sleeping);

    // Weather clears, but shade is gone -> stays awake
    fox.tick(0.5, true, false, false);
    try std.testing.expect(!fox.is_sleeping);

    // Crouch timer increments while crouching
    fox.startCrouching();
    try std.testing.expect(fox.is_crouching_to_pounce);
    fox.tick(0.25, false, false, false);
    try std.testing.expectEqual(@as(f32, 0.25), fox.crouch_timer);
}

test "FoxState mouth item pickup and drop" {
    var fox = FoxState.init(.red_taiga, .{ 0, 64, 0 });
    try std.testing.expectEqual(@as(u16, 0), fox.mouth_item_id);
    try std.testing.expect(fox.dropMouthItem() == null);

    // Pick up Emerald
    try std.testing.expect(fox.pickUpItem(EmeraldItemId));
    try std.testing.expectEqual(EmeraldItemId, fox.mouth_item_id);

    // Dropping Emerald for Sweet Berries (food priority)
    try std.testing.expect(fox.pickUpItem(SweetBerriesItemId));
    try std.testing.expectEqual(SweetBerriesItemId, fox.mouth_item_id);

    // Cannot swap food for Emerald
    try std.testing.expect(!fox.pickUpItem(EmeraldItemId));
    try std.testing.expectEqual(SweetBerriesItemId, fox.mouth_item_id);

    // Drop mouth item
    const dropped = fox.dropMouthItem();
    try std.testing.expectEqual(@as(?u16, SweetBerriesItemId), dropped);
    try std.testing.expectEqual(@as(u16, 0), fox.mouth_item_id);
}
