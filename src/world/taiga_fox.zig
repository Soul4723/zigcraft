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

// ============================================================================
// Merged Sweet Berry, Pounce, and Lifecycle Rules (from fox_sweet_berry.zig)
// ============================================================================

pub const MAX_HEALTH: f32 = 10.0;
pub const WALK_SPEED: f32 = 3.0;
pub const SPRINT_SPEED: f32 = 6.0;
pub const PREY_BITE_DAMAGE: f32 = 2.0;
pub const POUNCE_MAX_DISTANCE: f32 = 5.0;
pub const POUNCE_MAX_HEIGHT: f32 = 2.5;
pub const POUNCE_GRAVITY: f32 = 20.0;
pub const AIM_TICKS: u16 = 30;
pub const SNOW_STUCK_TICKS: u16 = 40;
pub const SNOW_STUCK_CHANCE: f32 = 0.20;
pub const PLAYER_WAKE_DISTANCE: f32 = 3.0;
pub const FOOD_CONSUME_TICKS: u16 = 600;
pub const FOOD_HEAL: f32 = 4.0;

pub const BerryFoxVariant = enum { red, snow };
pub const Biome = enum { taiga, old_growth_taiga, snowy_taiga, snowy_plains, other };
pub const PreyType = enum { chicken, rabbit, cod, salmon, tropical_fish, other };
pub const ItemType = enum { sweet_berries, raw_chicken, cooked_chicken, raw_rabbit, cooked_rabbit, raw_cod, cooked_cod, raw_salmon, cooked_salmon, tropical_fish, other };

pub const ItemStack = struct {
    item: ItemType,
    count: u8 = 1,
};

pub const Fox = struct {
    variant: BerryFoxVariant,
    health: f32 = MAX_HEALTH,
    is_sleeping: bool = false,
    is_curled_up: bool = false,
    is_aiming: bool = false,
    is_pouncing: bool = false,
    is_stuck_in_snow: bool = false,
    is_baby: bool = false,
    isImmuneToBerryBush: bool = true,
    mouth_item: ?ItemStack = null,
    aim_ticks: u16 = 0,
    snow_stuck_ticks: u16 = 0,
    food_ticks: u16 = 0,
    love_mode_ticks: u16 = 0,

    pub fn init(variant: BerryFoxVariant) Fox {
        return .{ .variant = variant };
    }

    pub fn canSpawnIn(self: Fox, biome: Biome) bool {
        return switch (self.variant) {
            .red => biome == .taiga or biome == .old_growth_taiga,
            .snow => biome == .snowy_taiga or biome == .snowy_plains,
        };
    }

    pub fn tickDaylight(self: *Fox, daytime: bool, shaded: bool, light_level: u8) void {
        self.is_sleeping = daytime and shaded and light_level <= 7;
        self.is_curled_up = self.is_sleeping;
    }

    pub fn wakeForPlayer(self: *Fox, distance: f32, player_sneaking: bool) bool {
        if (self.is_sleeping and !player_sneaking and distance <= PLAYER_WAKE_DISTANCE) {
            self.is_sleeping = false;
            self.is_curled_up = false;
            return true;
        }
        return false;
    }

    pub fn startAim(self: *Fox) void {
        self.is_aiming = true;
        self.aim_ticks = 0;
    }

    pub fn tickAim(self: *Fox, ticks: u16) bool {
        if (!self.is_aiming) return false;
        self.aim_ticks = @min(AIM_TICKS, self.aim_ticks +| ticks);
        if (self.aim_ticks == AIM_TICKS) {
            self.is_aiming = false;
            self.is_pouncing = true;
            return true;
        }
        return false;
    }

    pub fn landPounce(self: *Fox, prey_hit: bool, landing_in_snow: bool, chance_roll: f32) f32 {
        self.is_pouncing = false;
        if (landing_in_snow and chance_roll < SNOW_STUCK_CHANCE) {
            self.is_stuck_in_snow = true;
            self.snow_stuck_ticks = SNOW_STUCK_TICKS;
        }
        return if (prey_hit) PREY_BITE_DAMAGE else 0.0;
    }

    pub fn tickSnowStuck(self: *Fox, ticks: u16) void {
        self.snow_stuck_ticks -|= ticks;
        self.is_stuck_in_snow = self.snow_stuck_ticks > 0;
    }

    pub fn pickUpItem(self: *Fox, stack: ItemStack) bool {
        if (stack.count == 0) return false;
        if (self.mouth_item == null or (isEdible(stack.item) and !isEdible(self.mouth_item.?.item))) {
            self.mouth_item = .{ .item = stack.item, .count = 1 };
            self.food_ticks = 0;
            return true;
        }
        return false;
    }

    pub fn tickFood(self: *Fox, ticks: u16) f32 {
        const held = self.mouth_item orelse return 0;
        if (!isEdible(held.item)) return 0;
        self.food_ticks = @min(FOOD_CONSUME_TICKS, self.food_ticks +| ticks);
        if (self.food_ticks < FOOD_CONSUME_TICKS) return 0;
        self.mouth_item = null;
        self.food_ticks = 0;
        const healed = @min(FOOD_HEAL, MAX_HEALTH - self.health);
        self.health += healed;
        return healed;
    }

    pub fn breedWith(self: *Fox, mate: *Fox, offered: ItemType) bool {
        if (offered != .sweet_berries or self.is_sleeping or mate.is_sleeping) return false;
        self.love_mode_ticks = 600;
        mate.love_mode_ticks = 600;
        return true;
    }

    pub fn produceBaby(self: *Fox, mate: *Fox, variant_roll: f32) ?Fox {
        if (self.love_mode_ticks == 0 or mate.love_mode_ticks == 0) return null;
        self.love_mode_ticks = 0;
        mate.love_mode_ticks = 0;
        var baby = Fox.init(babyBerryFoxVariant(self.variant, mate.variant, variant_roll));
        baby.is_baby = true;
        return baby;
    }
};

pub const PounceVelocity = struct { vx: f32, vy: f32, vz: f32, flight_time: f32 };

pub fn pounceVelocity(dx: f32, dz: f32) PounceVelocity {
    const distance = @sqrt(dx * dx + dz * dz);
    const travel = @min(distance, POUNCE_MAX_DISTANCE);
    const scale = if (distance > 0) travel / distance else 0;
    const vy = @sqrt(2.0 * POUNCE_GRAVITY * POUNCE_MAX_HEIGHT);
    const flight = 2.0 * vy / POUNCE_GRAVITY;
    return .{ .vx = dx * scale / flight, .vy = vy, .vz = dz * scale / flight, .flight_time = flight };
}

pub fn isPrey(prey: PreyType) bool {
    return prey != .other;
}

pub fn isEdible(item: ItemType) bool {
    return switch (item) {
        .raw_chicken, .cooked_chicken, .raw_rabbit, .cooked_rabbit, .raw_cod, .cooked_cod, .raw_salmon, .cooked_salmon, .tropical_fish, .sweet_berries => true,
        .other => false,
    };
}

pub const BerryHarvest = struct { drops: u8, next_stage: u2 };

pub fn harvestBerryBush(stage: u2, drop_roll: u8) ?BerryHarvest {
    if (stage < 2) return null;
    return .{ .drops = 2 + @as(u8, @intCast(drop_roll % 2)), .next_stage = 1 };
}

pub fn berryBushDamage(fox: Fox, prick_damage: f32) f32 {
    return if (fox.isImmuneToBerryBush) 0 else prick_damage;
}

pub fn babyBerryFoxVariant(parent_a: BerryFoxVariant, parent_b: BerryFoxVariant, variant_roll: f32) BerryFoxVariant {
    if (variant_roll < 0.05) return if (parent_a == .snow) .red else .snow;
    return if (variant_roll < 0.5) parent_a else parent_b;
}

test "red variant spawns in taiga biomes" {
    const fox = Fox.init(.red);
    try std.testing.expect(fox.canSpawnIn(.taiga));
    try std.testing.expect(fox.canSpawnIn(.old_growth_taiga));
    try std.testing.expect(!fox.canSpawnIn(.snowy_plains));
}
test "snow variant spawns in snowy biomes" {
    const fox = Fox.init(.snow);
    try std.testing.expect(fox.canSpawnIn(.snowy_taiga));
    try std.testing.expect(fox.canSpawnIn(.snowy_plains));
    try std.testing.expect(!fox.canSpawnIn(.taiga));
}
test "fox health is five hearts" { try std.testing.expectEqual(@as(f32, 10), Fox.init(.red).health); }
test "movement speed constants" { try std.testing.expectEqual(@as(f32, 3), WALK_SPEED); try std.testing.expectEqual(@as(f32, 6), SPRINT_SPEED); }
test "chickens are prey" { try std.testing.expect(isPrey(.chicken)); }
test "rabbits are prey" { try std.testing.expect(isPrey(.rabbit)); }
test "cod are prey" { try std.testing.expect(isPrey(.cod)); }
test "salmon are prey" { try std.testing.expect(isPrey(.salmon)); }
test "tropical fish are prey" { try std.testing.expect(isPrey(.tropical_fish)); }
test "other mobs are not prey" { try std.testing.expect(!isPrey(.other)); }
test "aim lasts thirty ticks before pounce" {
    var fox = Fox.init(.red); fox.startAim();
    try std.testing.expect(!fox.tickAim(29));
    try std.testing.expect(fox.is_aiming);
    try std.testing.expect(fox.tickAim(1));
    try std.testing.expect(fox.is_pouncing);
}
test "pounce launch velocity produces 2.5m apex" {
    const v = pounceVelocity(3, 4);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), v.vy * v.vy / (2 * POUNCE_GRAVITY), 0.001);
}
test "pounce covers five meters horizontally" {
    const v = pounceVelocity(6, 0);
    try std.testing.expectApproxEqAbs(POUNCE_MAX_DISTANCE, v.vx * v.flight_time, 0.001);
}
test "pounce velocity aims along target vector" {
    const v = pounceVelocity(3, 4);
    try std.testing.expectApproxEqAbs(@as(f32, 3), v.vx * v.flight_time, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4), v.vz * v.flight_time, 0.001);
}
test "landing bite deals two hp" { var fox = Fox.init(.red); try std.testing.expectEqual(PREY_BITE_DAMAGE, fox.landPounce(true, false, 1)); }
test "missed pounce deals no damage" { var fox = Fox.init(.red); try std.testing.expectEqual(@as(f32, 0), fox.landPounce(false, false, 1)); }
test "snow landing can stick head for forty ticks" { var fox = Fox.init(.snow); _ = fox.landPounce(false, true, 0.1); try std.testing.expectEqual(SNOW_STUCK_TICKS, fox.snow_stuck_ticks); }
test "snow landing avoids stick when roll misses chance" { var fox = Fox.init(.snow); _ = fox.landPounce(false, true, 0.2); try std.testing.expect(!fox.is_stuck_in_snow); }
test "snow stuck timer releases fox" { var fox = Fox.init(.snow); _ = fox.landPounce(false, true, 0); fox.tickSnowStuck(40); try std.testing.expect(!fox.is_stuck_in_snow); }
test "berry bush damage immunity blocks prick damage" { try std.testing.expectEqual(@as(f32, 0), berryBushDamage(Fox.init(.red), 1)); }
test "mature stage two bush drops two berries and regresses" { const harvest = harvestBerryBush(2, 0).?; try std.testing.expectEqual(@as(u8, 2), harvest.drops); try std.testing.expectEqual(@as(u2, 1), harvest.next_stage); }
test "mature stage three bush drops three berries and regresses" { const harvest = harvestBerryBush(3, 1).?; try std.testing.expectEqual(@as(u8, 3), harvest.drops); try std.testing.expectEqual(@as(u2, 1), harvest.next_stage); }
test "immature berry bush cannot be harvested" { try std.testing.expect(harvestBerryBush(1, 0) == null); }
test "fox holds one item stack in mouth" { var fox = Fox.init(.red); try std.testing.expect(fox.pickUpItem(.{ .item = .other, .count = 8 })); try std.testing.expectEqual(@as(u8, 1), fox.mouth_item.?.count); }
test "edible pickup can replace held nonfood item" { var fox = Fox.init(.red); _ = fox.pickUpItem(.{ .item = .other }); try std.testing.expect(fox.pickUpItem(.{ .item = .raw_chicken, .count = 3 })); try std.testing.expectEqual(ItemType.raw_chicken, fox.mouth_item.?.item); }
test "food heals after six hundred ticks" { var fox = Fox.init(.red); fox.health = 4; _ = fox.pickUpItem(.{ .item = .raw_chicken }); try std.testing.expectEqual(@as(f32, 0), fox.tickFood(599)); try std.testing.expectEqual(@as(f32, 4), fox.tickFood(1)); try std.testing.expectEqual(@as(f32, 8), fox.health); }
test "food healing clamps at maximum health" { var fox = Fox.init(.red); fox.health = 9; _ = fox.pickUpItem(.{ .item = .sweet_berries }); try std.testing.expectEqual(@as(f32, 1), fox.tickFood(600)); try std.testing.expectEqual(MAX_HEALTH, fox.health); }
test "daytime shaded low light causes curled sleep" { var fox = Fox.init(.red); fox.tickDaylight(true, true, 7); try std.testing.expect(fox.is_sleeping); try std.testing.expect(fox.is_curled_up); }
test "bright or unshaded daytime does not cause sleep" { var fox = Fox.init(.red); fox.tickDaylight(true, true, 8); try std.testing.expect(!fox.is_sleeping); fox.tickDaylight(true, false, 0); try std.testing.expect(!fox.is_sleeping); }
test "approaching player wakes fox at three meters" { var fox = Fox.init(.red); fox.is_sleeping = true; fox.is_curled_up = true; try std.testing.expect(fox.wakeForPlayer(3, false)); try std.testing.expect(!fox.is_sleeping); try std.testing.expect(!fox.is_curled_up); }
test "sneaking player does not wake fox" { var fox = Fox.init(.red); fox.is_sleeping = true; try std.testing.expect(!fox.wakeForPlayer(1, true)); try std.testing.expect(fox.is_sleeping); }
test "distant player does not wake fox" { var fox = Fox.init(.red); fox.is_sleeping = true; try std.testing.expect(!fox.wakeForPlayer(3.1, false)); }
test "sweet berries trigger love mode and produce baby fox" { var a = Fox.init(.red); var b = Fox.init(.snow); try std.testing.expect(a.breedWith(&b, .sweet_berries)); const baby = a.produceBaby(&b, 0.2).?; try std.testing.expect(baby.is_baby); try std.testing.expectEqual(BerryFoxVariant.red, baby.variant); }
test "non-berry food does not trigger breeding" { var a = Fox.init(.red); var b = Fox.init(.red); try std.testing.expect(!a.breedWith(&b, .raw_chicken)); }

// ============================================================================
// Live Berry Bush & Fox Gameplay State Helpers
// ============================================================================

pub const BERRY_BUSH_CAP: usize = 64;
pub const BERRY_BUSH_GROW_SECONDS: f32 = 15.0;

pub const BerryBushNode = struct {
    x: i32,
    y: i32,
    z: i32,
    stage: u2 = 2,
    grow_timer: f32 = 0.0,
};

pub const BerryBushTracker = struct {
    nodes: [BERRY_BUSH_CAP]BerryBushNode = undefined,
    count: usize = 0,

    pub fn getOrRegister(self: *BerryBushTracker, x: i32, y: i32, z: i32) *BerryBushNode {
        for (self.nodes[0..self.count]) |*n| {
            if (n.x == x and n.y == y and n.z == z) return n;
        }
        if (self.count < self.nodes.len) {
            self.nodes[self.count] = .{ .x = x, .y = y, .z = z, .stage = 2, .grow_timer = 0.0 };
            self.count += 1;
            return &self.nodes[self.count - 1];
        }
        // Evict oldest entry when capacity is full.
        self.nodes[0] = .{ .x = x, .y = y, .z = z, .stage = 2, .grow_timer = 0.0 };
        return &self.nodes[0];
    }

    pub fn harvestAt(self: *BerryBushTracker, x: i32, y: i32, z: i32, drop_roll: u8) ?BerryHarvest {
        const node = self.getOrRegister(x, y, z);
        const res = harvestBerryBush(node.stage, drop_roll) orelse return null;
        node.stage = res.next_stage;
        node.grow_timer = 0.0;
        return res;
    }

    pub fn applyBoneMealAt(self: *BerryBushTracker, x: i32, y: i32, z: i32) ?u2 {
        const node = self.getOrRegister(x, y, z);
        if (node.stage >= 3) return null;
        node.stage = if (node.stage < 2) 2 else 3;
        node.grow_timer = 0.0;
        return node.stage;
    }

    pub fn tickGrowth(self: *BerryBushTracker, dt: f32) void {
        if (dt <= 0.0) return;
        for (self.nodes[0..self.count]) |*n| {
            if (n.stage < 3) {
                n.grow_timer += dt;
                while (n.grow_timer >= BERRY_BUSH_GROW_SECONDS and n.stage < 3) {
                    n.grow_timer -= BERRY_BUSH_GROW_SECONDS;
                    n.stage += 1;
                }
            }
        }
    }

    pub fn removeAt(self: *BerryBushTracker, x: i32, y: i32, z: i32) void {
        var i: usize = 0;
        while (i < self.count) {
            if (self.nodes[i].x == x and self.nodes[i].y == y and self.nodes[i].z == z) {
                self.count -= 1;
                self.nodes[i] = self.nodes[self.count];
            } else {
                i += 1;
            }
        }
    }
};

pub const MouthSwapOutcome = struct {
    accepted: bool,
    dropped_previous: ?u16 = null,
};

/// Offers an item to a FoxState using mouth-item food priority rules.
/// Returns any non-food item that the fox dropped to accept food.
pub fn offerMouthItem(state: *FoxState, item_id: u16) MouthSwapOutcome {
    if (item_id == 0) return .{ .accepted = false };
    if (state.mouth_item_id == 0) {
        state.mouth_item_id = item_id;
        return .{ .accepted = true };
    }
    if (shouldSwapItems(state.mouth_item_id, item_id)) {
        const prev = state.mouth_item_id;
        state.mouth_item_id = item_id;
        return .{ .accepted = true, .dropped_previous = prev };
    }
    return .{ .accepted = false };
}

test "BerryBushTracker harvests mature bush, regresses stage, and regrows" {
    var tracker = BerryBushTracker{};
    const first = tracker.harvestAt(4, 5, 6, 1).?;
    try std.testing.expectEqual(@as(u8, 3), first.drops);
    try std.testing.expectEqual(@as(u2, 1), first.next_stage);
    try std.testing.expect(tracker.harvestAt(4, 5, 6, 0) == null);

    tracker.tickGrowth(BERRY_BUSH_GROW_SECONDS);
    const second = tracker.harvestAt(4, 5, 6, 0).?;
    try std.testing.expectEqual(@as(u8, 2), second.drops);
}

test "BerryBushTracker bone meal fertilizes immature bush" {
    var tracker = BerryBushTracker{};
    _ = tracker.harvestAt(1, 2, 3, 0);
    const stage = tracker.applyBoneMealAt(1, 2, 3).?;
    try std.testing.expectEqual(@as(u2, 2), stage);
    try std.testing.expect(tracker.harvestAt(1, 2, 3, 0) != null);
}

test "offerMouthItem drops emerald when offered sweet berries" {
    var fox = FoxState.init(.red_taiga, .{ 0, 64, 0 });
    const r1 = offerMouthItem(&fox, EmeraldItemId);
    try std.testing.expect(r1.accepted);
    try std.testing.expect(r1.dropped_previous == null);

    const r2 = offerMouthItem(&fox, SweetBerriesItemId);
    try std.testing.expect(r2.accepted);
    try std.testing.expectEqual(@as(?u16, EmeraldItemId), r2.dropped_previous);
    try std.testing.expectEqual(SweetBerriesItemId, fox.mouth_item_id);
}
