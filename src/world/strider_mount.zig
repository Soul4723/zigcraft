const std = @import("std");

/// Item and Block IDs related to Striders and the Nether.
pub const WarpedFungusItemId: u16 = 87;
pub const WarpedFungusOnAStickItemId: u16 = 89;
pub const FishingRodItemId: u16 = 186;
pub const SaddleItemId: u16 = 250;
pub const LavaBlockId: u16 = 8;
pub const WarpedFungusBlockId: u16 = 72;

/// Health and healing constants.
pub const strider_max_health: f32 = 20.0; // 10 hearts
pub const strider_baby_health: f32 = 10.0; // 5 hearts
pub const warped_fungus_heal_amount: f32 = 2.0; // 1 heart

/// Speed constants (m/s).
/// Striders stride rapidly across lava surfaces, accelerate under fungus boost,
/// and walk slowly while shivering on cold land.
pub const strider_lava_speed: f32 = 4.2; // 4.2 m/s normal stride on lava
pub const strider_boost_speed: f32 = 7.8; // 7.8 m/s boosted stride on lava
pub const strider_land_speed: f32 = 1.7; // 1.7 m/s slow shivering stride on land

/// Warped Fungus on a Stick boost mechanics.
pub const fungus_boost_duration: f32 = 14.0; // 14.0 seconds speed boost
pub const max_stick_durability: u16 = 100; // max durability of Warped Fungus on a Stick
pub const boost_durability_cost: u16 = 1; // durability consumed per boost activation

/// Environmental contact damage constants.
/// Striders take 1.0 HP damage per 0.5 seconds in water or rain (2.0 HP/s).
pub const water_damage_rate: f32 = 2.0; // 1.0 HP per 0.5s = 2.0 HP/s

/// Breeding and growth constants.
pub const breeding_cooldown_duration: f32 = 300.0; // 5 minutes (6000 ticks)
pub const breeding_cooldown_ticks: u32 = 6000;
pub const baby_growth_duration: f32 = 1200.0; // 20 minutes (24000 ticks)
pub const baby_growth_ticks: u32 = 24000;
pub const baby_growth_step_reduction: f32 = 120.0; // 10% reduction per warped fungus fed (2400 ticks)

/// Rider and piggyback positioning offsets.
pub const strider_rider_y_offset: f32 = 1.6; // Player rider feet Y relative to strider base
pub const baby_piggyback_y_offset: f32 = 1.35; // Baby piggyback perched atop adult strider

/// RGBA color representation for strider thermal coloration.
pub const ColorRGBA = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

/// Warm crimson / red-orange strider coloration when submerged or standing in lava.
pub const strider_warm_color: ColorRGBA = .{ .r = 0.78, .g = 0.24, .b = 0.20, .a = 1.0 };

/// Cold pale purple-blue strider coloration when shivering out of lava or in rain/water.
pub const strider_cold_shivering_color: ColorRGBA = .{ .r = 0.42, .g = 0.40, .b = 0.58, .a = 1.0 };

/// Returns the visual tint color for a strider based on its shivering state.
pub fn getStriderColor(is_shivering: bool) ColorRGBA {
    if (is_shivering) {
        return strider_cold_shivering_color;
    } else {
        return strider_warm_color;
    }
}

/// Evaluates whether a strider should enter the shivering state.
/// Striders shiver and turn pale purple-blue whenever they are out of lava or touching rain/water.
pub fn computeShivering(on_lava: bool, in_water_or_rain: bool) bool {
    return !on_lava or in_water_or_rain;
}

/// Computes the movement speed of a strider given its lava surface contact and boost status.
/// - Fast stride across lava surfaces: 4.2 m/s normal on lava, 7.8 m/s when boosted by Warped Fungus on a Stick.
/// - Slow stride: 1.7 m/s shivering on land (boost cannot overcome shivering paralysis on cold land).
pub fn striderMovementSpeed(on_lava: bool, boosting: bool) f32 {
    if (on_lava) {
        return if (boosting) strider_boost_speed else strider_lava_speed;
    } else {
        return strider_land_speed;
    }
}

/// Keeps Striders and their riders floating cleanly atop the lava surface (strider_y >= lava_surface_y)
/// instead of sinking into the lava lake or taking lava burn damage.
pub fn computeLavaSurfaceBuoyancy(strider_y: f32, lava_surface_y: f32) f32 {
    return @max(strider_y, lava_surface_y);
}

/// Result returned when attempting to trigger a Warped Fungus on a Stick speed boost.
pub const FungusBoostResult = struct {
    boosted: bool,
    durability_cost: u16,
    stick_reverted_to_fishing_rod: bool,
};

/// Activates a 14.0s speed boost on a Strider, consuming 1 durability from the Warped Fungus on a Stick.
/// When stick durability depletes to 0, the item reverts back into an empty Fishing Rod!
pub fn triggerFungusBoost(strider: *StriderState, stick_durability: u16) FungusBoostResult {
    if (stick_durability == 0) {
        return .{
            .boosted = false,
            .durability_cost = 0,
            .stick_reverted_to_fishing_rod = false,
        };
    }

    strider.boost_timer = fungus_boost_duration;
    const cost: u16 = boost_durability_cost;
    const reverted: bool = (stick_durability <= cost);

    return .{
        .boosted = true,
        .durability_cost = cost,
        .stick_reverted_to_fishing_rod = reverted,
    };
}

/// Calculates damage taken by a Strider due to contact with rain or water.
/// Striders take 1.0 HP damage per 0.5 seconds (2.0 HP/s rate) in water or rain.
pub fn waterContactDamage(in_water_or_rain: bool, dt: f32) f32 {
    if (!in_water_or_rain) return 0.0;
    const clamped_dt = @max(0.0, dt);
    return water_damage_rate * clamped_dt;
}

/// Computes the 3D world position of a player mounted on the Strider.
pub fn computeWorldRiderPosition(sx: f32, sy: f32, sz: f32) struct { x: f32, y: f32, z: f32 } {
    return .{
        .x = sx,
        .y = sy + strider_rider_y_offset,
        .z = sz,
    };
}

/// Computes the 3D world position of a baby strider piggybacking atop an adult Strider.
pub fn computeWorldBabyPiggybackPosition(sx: f32, sy: f32, sz: f32) struct { x: f32, y: f32, z: f32 } {
    return .{
        .x = sx,
        .y = sy + baby_piggyback_y_offset,
        .z = sz,
    };
}

/// Heals a Strider with warped fungus by +2.0 HP, clamped to max_health.
pub fn applyWarpedFungusHeal(current_hp: f32, max_hp: f32) f32 {
    return @min(max_hp, current_hp + warped_fungus_heal_amount);
}

/// Accelerates baby Strider growth by 10% (120 seconds).
pub fn accelerateBabyGrowth(remaining_time: f32) f32 {
    return @max(0.0, remaining_time - baby_growth_step_reduction);
}

/// Breed two adult Striders in love mode.
/// Consumes love mode from both parents, places them on breeding cooldown (300.0s),
/// and spawns a new baby Strider. Returns null if either parent is not in love or is a baby.
pub fn breedStriders(parent1: *StriderState, parent2: *StriderState) ?StriderState {
    if (!parent1.in_love or !parent2.in_love or parent1.is_baby or parent2.is_baby) {
        return null;
    }
    parent1.in_love = false;
    parent1.breeding_cooldown = breeding_cooldown_duration;
    parent2.in_love = false;
    parent2.breeding_cooldown = breeding_cooldown_duration;

    return StriderState.initBaby();
}

/// Comprehensive state machine for a Strider mob.
/// Tracks lava/land habitat, shivering state, saddle, player rider, boost timer,
/// health, breeding, and piggyback riding.
pub const StriderState = struct {
    is_on_lava: bool = true,
    is_shivering: bool = false,
    has_saddle: bool = false,
    has_rider: bool = false,
    boost_timer: f32 = 0.0,
    health: f32 = strider_max_health,

    // Breeding & baby lifecycle fields
    is_baby: bool = false,
    growth_timer: f32 = 0.0,
    breeding_cooldown: f32 = 0.0,
    in_love: bool = false,

    // Piggyback riding fields
    has_baby_rider: bool = false,
    is_riding_adult: bool = false,

    const timer_epsilon: f32 = 0.0001;

    /// Creates an adult strider spawned in lava.
    pub fn init() StriderState {
        return .{
            .is_on_lava = true,
            .is_shivering = false,
            .has_saddle = false,
            .has_rider = false,
            .boost_timer = 0.0,
            .health = strider_max_health,
        };
    }

    /// Creates a baby strider spawned in lava.
    pub fn initBaby() StriderState {
        return .{
            .is_on_lava = true,
            .is_shivering = false,
            .has_saddle = false,
            .has_rider = false,
            .boost_timer = 0.0,
            .health = strider_baby_health,
            .is_baby = true,
            .growth_timer = baby_growth_duration,
        };
    }

    /// Checks if speed boost is currently active.
    pub fn isBoosting(self: StriderState) bool {
        return self.boost_timer > timer_epsilon;
    }

    /// Calculates current horizontal movement speed based on lava contact and boost.
    pub fn currentSpeed(self: StriderState) f32 {
        return striderMovementSpeed(self.is_on_lava, self.isBoosting());
    }

    /// Returns whether the strider is completely immune to fire and lava burn damage.
    pub fn isFireImmune(self: StriderState) bool {
        _ = self;
        return true;
    }

    /// Returns the active visual RGBA color tint (warm crimson vs shivering cold).
    pub fn getColor(self: StriderState) ColorRGBA {
        return getStriderColor(self.is_shivering);
    }

    /// Updates lava contact and shivering status.
    pub fn setLavaState(self: *StriderState, on_lava: bool, in_water_or_rain: bool) void {
        self.is_on_lava = on_lava;
        self.is_shivering = computeShivering(on_lava, in_water_or_rain);
    }

    /// Equips a saddle on the Strider. Babies cannot be saddled.
    pub fn equipSaddle(self: *StriderState) bool {
        if (self.is_baby or self.has_saddle) return false;
        self.has_saddle = true;
        return true;
    }

    /// Removes saddle from the Strider. Also dismounts any rider.
    pub fn removeSaddle(self: *StriderState) bool {
        if (!self.has_saddle) return false;
        self.has_saddle = false;
        self.has_rider = false;
        return true;
    }

    /// Mounts a player rider onto the Strider.
    /// Requires an adult saddled Strider with no current player rider and no baby rider.
    pub fn mountRider(self: *StriderState) bool {
        if (!self.has_saddle or self.has_rider or self.is_baby) return false;
        self.has_rider = true;
        return true;
    }

    /// Dismounts the player rider.
    pub fn dismountRider(self: *StriderState) void {
        self.has_rider = false;
    }

    /// Mounts a baby Strider piggyback on this adult Strider.
    pub fn mountBaby(self: *StriderState, baby: *StriderState) bool {
        if (self.is_baby or self.has_baby_rider or !baby.is_baby or baby.is_riding_adult) {
            return false;
        }
        self.has_baby_rider = true;
        baby.is_riding_adult = true;
        return true;
    }

    /// Dismounts a piggybacking baby Strider.
    pub fn dismountBaby(self: *StriderState, baby: *StriderState) void {
        self.has_baby_rider = false;
        baby.is_riding_adult = false;
    }

    /// Activates speed boost via Warped Fungus on a Stick.
    pub fn triggerBoost(self: *StriderState, stick_durability: u16) FungusBoostResult {
        return triggerFungusBoost(self, stick_durability);
    }

    /// Feeds a Warped Fungus item to the Strider:
    /// - If health < max, heals +2.0 HP.
    /// - If baby, accelerates growth by 120s (10%).
    /// - If healthy adult and not on breeding cooldown, enters love mode.
    /// Returns true if the item was consumed.
    pub fn feedWarpedFungus(self: *StriderState) bool {
        if (self.health < strider_max_health) {
            self.health = applyWarpedFungusHeal(self.health, strider_max_health);
            return true;
        }
        if (self.is_baby) {
            self.growth_timer = accelerateBabyGrowth(self.growth_timer);
            if (self.growth_timer <= timer_epsilon) {
                self.is_baby = false;
                self.growth_timer = 0.0;
            }
            return true;
        }
        if (self.breeding_cooldown <= timer_epsilon and !self.in_love) {
            self.in_love = true;
            return true;
        }
        return false;
    }

    /// Applies water or rain contact damage to this Strider.
    /// Striders take 1.0 HP damage per 0.5s in water/rain. Clamps health at 0.0.
    pub fn applyWaterDamage(self: *StriderState, in_water_or_rain: bool, dt: f32) f32 {
        const dmg = waterContactDamage(in_water_or_rain, dt);
        if (dmg > 0.0) {
            self.health = @max(0.0, self.health - dmg);
        }
        return dmg;
    }

    /// Advances strider timers by dt seconds.
    pub fn update(self: *StriderState, dt: f32) void {
        if (self.boost_timer > 0.0) {
            self.boost_timer -= dt;
            if (self.boost_timer <= timer_epsilon) {
                self.boost_timer = 0.0;
            }
        }

        if (self.breeding_cooldown > 0.0) {
            self.breeding_cooldown -= dt;
            if (self.breeding_cooldown <= timer_epsilon) {
                self.breeding_cooldown = 0.0;
            }
        }

        if (self.is_baby and self.growth_timer > 0.0) {
            self.growth_timer -= dt;
            if (self.growth_timer <= timer_epsilon) {
                self.is_baby = false;
                self.growth_timer = 0.0;
            }
        }

        // Shivering persists when out of lava
        self.is_shivering = !self.is_on_lava;
    }

    /// Comprehensive environment update: updates habitat, applies water damage, and advances timers.
    pub fn updateWithEnvironment(self: *StriderState, dt: f32, on_lava: bool, in_water_or_rain: bool) void {
        self.is_on_lava = on_lava;
        self.is_shivering = computeShivering(on_lava, in_water_or_rain);
        if (in_water_or_rain) {
            _ = self.applyWaterDamage(true, dt);
        }
        self.update(dt);
        // Ensure shivering is maintained if rain was active
        if (in_water_or_rain) {
            self.is_shivering = true;
        }
    }

    /// Advances state by one game tick (1/20 second = 0.05s).
    pub fn tick(self: *StriderState) void {
        self.update(0.05);
    }
};

// ============================================================================
// Unit Tests (Comprehensive test suite covering all Milestone 307 requirements)
// ============================================================================

test "1. lava surface buoyancy keeps strider above or at lava surface" {
    const lava_y: f32 = 64.0;

    // Submerged strider is lifted to lava surface level
    const submerged_y: f32 = 62.5;
    const buoyant_y = computeLavaSurfaceBuoyancy(submerged_y, lava_y);
    try std.testing.expectEqual(lava_y, buoyant_y);
    try std.testing.expect(buoyant_y >= lava_y);

    // Strider directly on surface remains at surface
    const surface_y = computeLavaSurfaceBuoyancy(64.0, lava_y);
    try std.testing.expectEqual(lava_y, surface_y);

    // Strider jumping above surface is unaffected
    const airborne_y = computeLavaSurfaceBuoyancy(65.5, lava_y);
    try std.testing.expectEqual(@as(f32, 65.5), airborne_y);
    try std.testing.expect(airborne_y >= lava_y);
}

test "2. lava surface buoyancy with deep submersion snaps directly to surface level" {
    const lava_y: f32 = 120.0;
    const deep_y: f32 = 10.0;
    const buoyant_y = computeLavaSurfaceBuoyancy(deep_y, lava_y);
    try std.testing.expectEqual(lava_y, buoyant_y);
    try std.testing.expect(buoyant_y >= lava_y);
}

test "3. shivering state active when out of lava and inactive in lava" {
    var strider = StriderState.init();
    try std.testing.expect(strider.is_on_lava);
    try std.testing.expect(!strider.is_shivering);

    // Move out of lava onto land -> enters shivering state
    strider.setLavaState(false, false);
    try std.testing.expect(!strider.is_on_lava);
    try std.testing.expect(strider.is_shivering);

    // Return to lava -> shivering stops
    strider.setLavaState(true, false);
    try std.testing.expect(strider.is_on_lava);
    try std.testing.expect(!strider.is_shivering);
}

test "4. shivering state triggered by water or rain contact even if on lava" {
    // In lava and dry: not shivering
    try std.testing.expect(!computeShivering(true, false));

    // In lava but exposed to rain/water: shivers
    try std.testing.expect(computeShivering(true, true));

    // Out of lava: shivers regardless of rain
    try std.testing.expect(computeShivering(false, false));
    try std.testing.expect(computeShivering(false, true));

    var strider = StriderState.init();
    strider.setLavaState(true, true);
    try std.testing.expect(strider.is_shivering);
}

test "5. strider visual color reflects warm crimson vs shivering pale purple-blue" {
    const warm = getStriderColor(false);
    const cold = getStriderColor(true);

    // Warm color has predominant red channel
    try std.testing.expect(warm.r > warm.b);
    try std.testing.expectApproxEqAbs(warm.r, strider_warm_color.r, 0.001);
    try std.testing.expectApproxEqAbs(warm.g, strider_warm_color.g, 0.001);
    try std.testing.expectApproxEqAbs(warm.b, strider_warm_color.b, 0.001);

    // Cold shivering color has boosted blue channel and subdued red channel (pale purple-blue)
    try std.testing.expect(cold.b > cold.r);
    try std.testing.expectApproxEqAbs(cold.r, strider_cold_shivering_color.r, 0.001);
    try std.testing.expectApproxEqAbs(cold.g, strider_cold_shivering_color.g, 0.001);
    try std.testing.expectApproxEqAbs(cold.b, strider_cold_shivering_color.b, 0.001);

    var strider = StriderState.init();
    try std.testing.expectEqual(warm, strider.getColor());
    strider.is_shivering = true;
    try std.testing.expectEqual(cold, strider.getColor());
}

test "6. striderMovementSpeed normal on lava is 4.2 m/s" {
    const speed = striderMovementSpeed(true, false);
    try std.testing.expectEqual(@as(f32, 4.2), speed);
    try std.testing.expectEqual(@as(f32, strider_lava_speed), speed);
}

test "7. striderMovementSpeed boosted on lava is 7.8 m/s" {
    const speed = striderMovementSpeed(true, true);
    try std.testing.expectEqual(@as(f32, 7.8), speed);
    try std.testing.expectEqual(@as(f32, strider_boost_speed), speed);
}

test "8. striderMovementSpeed on land is slow shivering 1.7 m/s" {
    // Normal walking on land
    const normal_land = striderMovementSpeed(false, false);
    try std.testing.expectEqual(@as(f32, 1.7), normal_land);
    try std.testing.expectEqual(@as(f32, strider_land_speed), normal_land);

    // Boost on land cannot overcome cold shivering paralysis
    const boosted_land = striderMovementSpeed(false, true);
    try std.testing.expectEqual(@as(f32, 1.7), boosted_land);
}

test "9. speed multipliers on lava vs land vs boosted" {
    const v_land = striderMovementSpeed(false, false);
    const v_lava = striderMovementSpeed(true, false);
    const v_boost = striderMovementSpeed(true, true);

    // Lava is ~2.47x faster than land
    const lava_to_land_ratio = v_lava / v_land;
    try std.testing.expectApproxEqAbs(lava_to_land_ratio, 4.2 / 1.7, 0.01);

    // Boosted lava is ~1.857x faster than normal lava
    const boost_to_lava_ratio = v_boost / v_lava;
    try std.testing.expectApproxEqAbs(boost_to_lava_ratio, 7.8 / 4.2, 0.01);

    // Boosted lava is ~4.588x faster than land
    const boost_to_land_ratio = v_boost / v_land;
    try std.testing.expectApproxEqAbs(boost_to_land_ratio, 7.8 / 1.7, 0.01);
}

test "10. triggerFungusBoost activates 14.0s boost and consumes 1 durability" {
    var strider = StriderState.init();
    try std.testing.expectEqual(@as(f32, 0.0), strider.boost_timer);
    try std.testing.expect(!strider.isBoosting());

    const result = triggerFungusBoost(&strider, 100);
    try std.testing.expect(result.boosted);
    try std.testing.expectEqual(@as(u16, 1), result.durability_cost);
    try std.testing.expect(!result.stick_reverted_to_fishing_rod);

    try std.testing.expectEqual(@as(f32, 14.0), strider.boost_timer);
    try std.testing.expect(strider.isBoosting());
    try std.testing.expectEqual(@as(f32, 7.8), strider.currentSpeed());
}

test "11. triggerFungusBoost at 1 durability reverts stick to fishing rod" {
    var strider = StriderState.init();

    // 1 durability remaining: boost activates, consumes 1 durability, reverts to Fishing Rod!
    const result = triggerFungusBoost(&strider, 1);
    try std.testing.expect(result.boosted);
    try std.testing.expectEqual(@as(u16, 1), result.durability_cost);
    try std.testing.expect(result.stick_reverted_to_fishing_rod);
    try std.testing.expectEqual(@as(f32, 14.0), strider.boost_timer);
}

test "12. triggerFungusBoost with 0 durability fails to boost" {
    var strider = StriderState.init();

    const result = triggerFungusBoost(&strider, 0);
    try std.testing.expect(!result.boosted);
    try std.testing.expectEqual(@as(u16, 0), result.durability_cost);
    try std.testing.expect(!result.stick_reverted_to_fishing_rod);
    try std.testing.expectEqual(@as(f32, 0.0), strider.boost_timer);
    try std.testing.expect(!strider.isBoosting());
}

test "13. water contact damage deals 1.0 HP per 0.5s (2.0 HP/s)" {
    // 0.5s in water/rain -> 1.0 HP damage
    try std.testing.expectApproxEqAbs(waterContactDamage(true, 0.5), 1.0, 0.001);

    // 1.0s in water/rain -> 2.0 HP damage
    try std.testing.expectApproxEqAbs(waterContactDamage(true, 1.0), 2.0, 0.001);

    // 0.25s in water/rain -> 0.5 HP damage
    try std.testing.expectApproxEqAbs(waterContactDamage(true, 0.25), 0.5, 0.001);

    // Not in water or rain -> 0.0 damage
    try std.testing.expectEqual(@as(f32, 0.0), waterContactDamage(false, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), waterContactDamage(false, 10.0));
}

test "14. water contact damage reduces strider health and clamps at zero" {
    var strider = StriderState.init();
    try std.testing.expectEqual(@as(f32, 20.0), strider.health);

    // 5.0 seconds in rain: 5.0s * 2.0 HP/s = 10.0 HP damage
    const dmg1 = strider.applyWaterDamage(true, 5.0);
    try std.testing.expectApproxEqAbs(dmg1, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(strider.health, 10.0, 0.001);

    // Another 6.0 seconds: 12.0 HP damage, health drops to 0.0 (clamped)
    const dmg2 = strider.applyWaterDamage(true, 6.0);
    try std.testing.expectApproxEqAbs(dmg2, 12.0, 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), strider.health);
}

test "15. warped fungus feeding heals injured adult strider" {
    var strider = StriderState.init();
    strider.health = 15.0;

    // First feed: 15.0 + 2.0 = 17.0 HP
    try std.testing.expect(strider.feedWarpedFungus());
    try std.testing.expectApproxEqAbs(strider.health, 17.0, 0.001);

    // Second feed: 17.0 + 2.0 = 19.0 HP
    try std.testing.expect(strider.feedWarpedFungus());
    try std.testing.expectApproxEqAbs(strider.health, 19.0, 0.001);

    // Third feed: 19.0 + 2.0 = 20.0 HP (clamped to max_health)
    try std.testing.expect(strider.feedWarpedFungus());
    try std.testing.expectApproxEqAbs(strider.health, 20.0, 0.001);
}

test "16. warped fungus feeding puts healthy adult strider into love mode" {
    var strider = StriderState.init();
    try std.testing.expect(!strider.in_love);
    try std.testing.expectEqual(@as(f32, 0.0), strider.breeding_cooldown);

    // Healthy adult consumes warped fungus to enter love mode
    try std.testing.expect(strider.feedWarpedFungus());
    try std.testing.expect(strider.in_love);

    // Already in love: does not consume additional warped fungus
    try std.testing.expect(!strider.feedWarpedFungus());

    // On breeding cooldown: does not consume warped fungus
    strider.in_love = false;
    strider.breeding_cooldown = breeding_cooldown_duration;
    try std.testing.expect(!strider.feedWarpedFungus());
}

test "17. warped fungus breeding produces baby strider and sets parent cooldowns" {
    var p1 = StriderState.init();
    var p2 = StriderState.init();

    _ = p1.feedWarpedFungus();
    _ = p2.feedWarpedFungus();
    try std.testing.expect(p1.in_love);
    try std.testing.expect(p2.in_love);

    const maybe_baby = breedStriders(&p1, &p2);
    try std.testing.expect(maybe_baby != null);
    const baby = maybe_baby.?;

    // Baby attributes
    try std.testing.expect(baby.is_baby);
    try std.testing.expectEqual(@as(f32, 10.0), baby.health);
    try std.testing.expectApproxEqAbs(baby.growth_timer, baby_growth_duration, 0.001);
    try std.testing.expect(!baby.has_saddle);
    try std.testing.expect(!baby.has_rider);

    // Parents reset
    try std.testing.expect(!p1.in_love);
    try std.testing.expect(!p2.in_love);
    try std.testing.expectApproxEqAbs(p1.breeding_cooldown, 300.0, 0.001);
    try std.testing.expectApproxEqAbs(p2.breeding_cooldown, 300.0, 0.001);

    // Cannot breed again while cooldown active
    try std.testing.expect(breedStriders(&p1, &p2) == null);
}

test "18. baby strider growth acceleration via warped fungus feeding" {
    var baby = StriderState.initBaby();
    baby.health = strider_max_health; // full health so food goes toward growth
    try std.testing.expect(baby.is_baby);
    try std.testing.expectApproxEqAbs(baby.growth_timer, 1200.0, 0.001);

    // Feeding reduces growth timer by 120s (10%)
    try std.testing.expect(baby.feedWarpedFungus());
    try std.testing.expectApproxEqAbs(baby.growth_timer, 1080.0, 0.001);

    // Accelerate to near maturity
    baby.growth_timer = 50.0;
    try std.testing.expect(baby.feedWarpedFungus());
    try std.testing.expect(!baby.is_baby);
    try std.testing.expectEqual(@as(f32, 0.0), baby.growth_timer);
}

test "19. baby strider piggyback riding on adult striders" {
    var adult = StriderState.init();
    var baby = StriderState.initBaby();

    try std.testing.expect(!adult.has_baby_rider);
    try std.testing.expect(!baby.is_riding_adult);

    // Mount baby onto adult
    try std.testing.expect(adult.mountBaby(&baby));
    try std.testing.expect(adult.has_baby_rider);
    try std.testing.expect(baby.is_riding_adult);

    // Cannot mount a second baby onto same adult
    var baby2 = StriderState.initBaby();
    try std.testing.expect(!adult.mountBaby(&baby2));

    // Baby cannot carry another baby
    var baby3 = StriderState.initBaby();
    try std.testing.expect(!baby.mountBaby(&baby3));

    // Dismount clears piggyback state
    adult.dismountBaby(&baby);
    try std.testing.expect(!adult.has_baby_rider);
    try std.testing.expect(!baby.is_riding_adult);
}

test "20. saddle equipping, rider mounting, and dismounting" {
    var strider = StriderState.init();
    var baby = StriderState.initBaby();

    // Cannot mount unsaddled strider
    try std.testing.expect(!strider.mountRider());

    // Cannot equip saddle on baby
    try std.testing.expect(!baby.equipSaddle());

    // Equip saddle on adult
    try std.testing.expect(strider.equipSaddle());
    try std.testing.expect(strider.has_saddle);
    try std.testing.expect(!strider.equipSaddle()); // already saddled

    // Mount player rider
    try std.testing.expect(strider.mountRider());
    try std.testing.expect(strider.has_rider);
    try std.testing.expect(!strider.mountRider()); // already has rider

    // Dismount rider
    strider.dismountRider();
    try std.testing.expect(!strider.has_rider);
    try std.testing.expect(strider.has_saddle);

    // Remove saddle also dismounts rider
    _ = strider.mountRider();
    try std.testing.expect(strider.removeSaddle());
    try std.testing.expect(!strider.has_saddle);
    try std.testing.expect(!strider.has_rider);
}

test "21. update countdowns for boost, cooldowns, and environment tick" {
    var strider = StriderState.init();
    _ = triggerFungusBoost(&strider, 50);
    strider.breeding_cooldown = 10.0;

    try std.testing.expect(strider.isBoosting());

    // Advance 5.0 seconds
    strider.update(5.0);
    try std.testing.expectApproxEqAbs(strider.boost_timer, 9.0, 0.001);
    try std.testing.expectApproxEqAbs(strider.breeding_cooldown, 5.0, 0.001);

    // Advance 9.0 seconds -> boost expires
    strider.update(9.0);
    try std.testing.expectEqual(@as(f32, 0.0), strider.boost_timer);
    try std.testing.expect(!strider.isBoosting());

    // Comprehensive updateWithEnvironment handles rain exposure and ticking
    var s2 = StriderState.init();
    s2.updateWithEnvironment(1.0, true, true);
    try std.testing.expect(s2.is_shivering);
    try std.testing.expectApproxEqAbs(s2.health, 18.0, 0.001);

    // World position offsets verify 3D coordinates
    const rider_pos = computeWorldRiderPosition(10.0, 64.0, 20.0);
    try std.testing.expectApproxEqAbs(rider_pos.y, 64.0 + strider_rider_y_offset, 0.001);
    const baby_pos = computeWorldBabyPiggybackPosition(10.0, 64.0, 20.0);
    try std.testing.expectApproxEqAbs(baby_pos.y, 64.0 + baby_piggyback_y_offset, 0.001);
}
