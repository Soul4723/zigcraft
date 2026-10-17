const std = @import("std");

/// Brewing stand constants
pub const max_fuel_charges: u5 = 20;
pub const charges_per_blaze_powder: u5 = 20;
pub const brew_time_seconds: f32 = 20.0;
pub const brew_time_ticks: u32 = 400;
pub const ticks_per_second: f32 = 20.0;
pub const seconds_per_tick: f32 = 0.05;

/// Potion effect durations (in seconds)
pub const standard_base_duration: f32 = 180.0;     // 3:00 (180s)
pub const standard_extended_duration: f32 = 480.0; // 8:00 (480s)
pub const standard_enhanced_duration: f32 = 90.0;  // 1:30 (90s)

pub const short_base_duration: f32 = 90.0;         // 1:30 (90s) for slowness / weakness
pub const short_extended_duration: f32 = 240.0;    // 4:00 (240s) for slowness / weakness

pub const turtle_master_base_duration: f32 = 20.0;
pub const turtle_master_extended_duration: f32 = 40.0;

/// Delivery vessel / bottle container type: drinkable, splash, or lingering.
pub const DeliveryVessel = enum {
    drinkable,
    splash,
    lingering,

    pub fn isDrinkable(self: DeliveryVessel) bool {
        return self == .drinkable;
    }

    pub fn isSplash(self: DeliveryVessel) bool {
        return self == .splash;
    }

    pub fn isLingering(self: DeliveryVessel) bool {
        return self == .lingering;
    }

    pub fn prefix(self: DeliveryVessel) []const u8 {
        return switch (self) {
            .drinkable => "Potion of ",
            .splash => "Splash Potion of ",
            .lingering => "Lingering Potion of ",
        };
    }
};

/// All standard potion types.
pub const PotionType = enum {
    water,
    awkward,
    mundane,
    thick,
    night_vision,
    invisibility,
    leaping,
    slowness,
    swiftness,
    fire_resistance,
    water_breathing,
    healing,
    harming,
    poison,
    regeneration,
    strength,
    weakness,
    slow_falling,
    turtle_master,

    pub const instant_health: PotionType = .healing;
    pub const instant_damage: PotionType = .harming;
    pub const speed: PotionType = .swiftness;
    pub const jump_boost: PotionType = .leaping;

    pub fn isInstantaneous(self: PotionType) bool {
        return self == .healing or self == .harming;
    }

    pub fn isBase(self: PotionType) bool {
        return self == .water or self == .awkward or self == .mundane or self == .thick;
    }

    pub fn supportsGlowstone(self: PotionType) bool {
        return switch (self) {
            .swiftness, .leaping, .strength, .healing, .harming, .poison, .regeneration => true,
            else => false,
        };
    }

    pub fn supportsRedstone(self: PotionType) bool {
        if (self.isInstantaneous() or self.isBase()) return false;
        return true;
    }

    pub fn name(self: PotionType) []const u8 {
        return switch (self) {
            .water => "Water",
            .awkward => "Awkward",
            .mundane => "Mundane",
            .thick => "Thick",
            .night_vision => "Night Vision",
            .invisibility => "Invisibility",
            .leaping => "Leaping",
            .slowness => "Slowness",
            .swiftness => "Swiftness",
            .fire_resistance => "Fire Resistance",
            .water_breathing => "Water Breathing",
            .healing => "Healing",
            .harming => "Harming",
            .poison => "Poison",
            .regeneration => "Regeneration",
            .strength => "Strength",
            .weakness => "Weakness",
            .slow_falling => "Slow Falling",
            .turtle_master => "Turtle Master",
        };
    }
};

/// Ingredients used in brewing and fueling.
pub const Ingredient = enum {
    nether_wart,
    fermented_spider_eye,
    redstone_dust,
    glowstone_dust,
    gunpowder,
    dragons_breath,
    sugar,
    rabbit_foot,
    blaze_powder,
    glistering_melon_slice,
    spider_eye,
    ghast_tear,
    magma_cream,
    pufferfish,
    golden_carrot,
    phantom_membrane,
    turtle_helmet,

    pub fn isFuel(self: Ingredient) bool {
        return self == .blaze_powder;
    }

    pub fn name(self: Ingredient) []const u8 {
        return switch (self) {
            .nether_wart => "Nether Wart",
            .fermented_spider_eye => "Fermented Spider Eye",
            .redstone_dust => "Redstone Dust",
            .glowstone_dust => "Glowstone Dust",
            .gunpowder => "Gunpowder",
            .dragons_breath => "Dragon's Breath",
            .sugar => "Sugar",
            .rabbit_foot => "Rabbit's Foot",
            .blaze_powder => "Blaze Powder",
            .glistering_melon_slice => "Glistering Melon Slice",
            .spider_eye => "Spider Eye",
            .ghast_tear => "Ghast Tear",
            .magma_cream => "Magma Cream",
            .pufferfish => "Pufferfish",
            .golden_carrot => "Golden Carrot",
            .phantom_membrane => "Phantom Membrane",
            .turtle_helmet => "Turtle Helmet",
        };
    }
};

/// Represents an individual brewed potion's properties.
pub const PotionState = struct {
    potion_type: PotionType = .water,
    vessel: DeliveryVessel = .drinkable,
    duration_seconds: f32 = 0.0,
    amplifier: u8 = 0,
    extended: bool = false,

    pub fn isInstantaneous(self: PotionState) bool {
        return self.potion_type.isInstantaneous();
    }

    pub fn isDrinkable(self: PotionState) bool {
        return self.vessel == .drinkable;
    }

    pub fn isSplash(self: PotionState) bool {
        return self.vessel == .splash;
    }

    pub fn isLingering(self: PotionState) bool {
        return self.vessel == .lingering;
    }

    pub fn isLevelTwo(self: PotionState) bool {
        return self.amplifier >= 1;
    }

    pub fn isExtended(self: PotionState) bool {
        return self.extended;
    }

    pub fn equals(self: PotionState, other: PotionState) bool {
        return self.potion_type == other.potion_type and
            self.vessel == other.vessel and
            @abs(self.duration_seconds - other.duration_seconds) < 0.001 and
            self.amplifier == other.amplifier and
            self.extended == other.extended;
    }

    pub fn createAoECloud(self: PotionState) ?AreaEffectCloud {
        if (self.vessel != .lingering) return null;
        return AreaEffectCloud.init(self);
    }
};

/// Area Effect Cloud created by Lingering Potions.
pub const AreaEffectCloud = struct {
    potion: PotionState,
    radius: f32 = DeliveryVesselUpgrade.lingering_cloud_radius,
    shrink_rate: f32 = DeliveryVesselUpgrade.lingering_radius_shrink_per_application,
    application_count: u32 = 0,
    duration_seconds: f32 = 30.0,

    pub fn init(potion: PotionState) AreaEffectCloud {
        return .{
            .potion = potion,
            .radius = DeliveryVesselUpgrade.lingering_cloud_radius,
            .shrink_rate = DeliveryVesselUpgrade.lingering_radius_shrink_per_application,
            .application_count = 0,
            .duration_seconds = 30.0,
        };
    }

    /// Applies cloud effect to an entity. Decreases radius by 0.5m.
    /// Returns true if applied, false if the cloud has already dissipated.
    pub fn applyToEntity(self: *AreaEffectCloud) bool {
        if (self.isDissipated()) return false;
        self.radius -= self.shrink_rate;
        if (self.radius < 0.0) self.radius = 0.0;
        self.application_count += 1;
        return true;
    }

    pub fn isDissipated(self: AreaEffectCloud) bool {
        return self.radius <= 0.0 or self.duration_seconds <= 0.0;
    }

    pub fn remainingApplications(self: AreaEffectCloud) u32 {
        if (self.radius <= 0.0) return 0;
        return @intFromFloat(@ceil(self.radius / self.shrink_rate));
    }

    pub fn tick(self: *AreaEffectCloud, dt: f32) void {
        self.duration_seconds = @max(0.0, self.duration_seconds - dt);
        if (self.duration_seconds <= 0.0) {
            self.radius = 0.0;
        }
    }
};

pub const AoECloud = AreaEffectCloud;

/// Distillation of base potions from water bottles.
pub const BasePotionDistillation = struct {
    pub fn distill(potion: PotionState, ingredient: Ingredient) ?PotionState {
        if (potion.potion_type != .water) return null;
        return switch (ingredient) {
            .nether_wart => PotionState{
                .potion_type = .awkward,
                .vessel = potion.vessel,
                .duration_seconds = 0.0,
                .amplifier = 0,
                .extended = false,
            },
            .fermented_spider_eye => PotionState{
                .potion_type = .weakness,
                .vessel = potion.vessel,
                .duration_seconds = short_base_duration,
                .amplifier = 0,
                .extended = false,
            },
            .redstone_dust => PotionState{
                .potion_type = .mundane,
                .vessel = potion.vessel,
                .duration_seconds = 0.0,
                .amplifier = 0,
                .extended = false,
            },
            .glowstone_dust => PotionState{
                .potion_type = .thick,
                .vessel = potion.vessel,
                .duration_seconds = 0.0,
                .amplifier = 0,
                .extended = false,
            },
            else => null,
        };
    }

    pub fn canDistill(potion: PotionState, ingredient: Ingredient) bool {
        return distill(potion, ingredient) != null;
    }

    pub fn waterBottle() PotionState {
        return .{
            .potion_type = .water,
            .vessel = .drinkable,
            .duration_seconds = 0.0,
            .amplifier = 0,
            .extended = false,
        };
    }

    pub fn awkwardPotion() PotionState {
        return .{
            .potion_type = .awkward,
            .vessel = .drinkable,
            .duration_seconds = 0.0,
            .amplifier = 0,
            .extended = false,
        };
    }

    pub fn mundanePotion() PotionState {
        return .{
            .potion_type = .mundane,
            .vessel = .drinkable,
            .duration_seconds = 0.0,
            .amplifier = 0,
            .extended = false,
        };
    }

    pub fn thickPotion() PotionState {
        return .{
            .potion_type = .thick,
            .vessel = .drinkable,
            .duration_seconds = 0.0,
            .amplifier = 0,
            .extended = false,
        };
    }

    pub fn potionOfWeakness() PotionState {
        return .{
            .potion_type = .weakness,
            .vessel = .drinkable,
            .duration_seconds = short_base_duration,
            .amplifier = 0,
            .extended = false,
        };
    }
};

/// Modifier rules for Redstone, Glowstone, and Fermented Spider Eye.
pub const PotionModifierRule = struct {
    /// In Minecraft alchemy, Redstone duration extension and Glowstone potency enhancement
    /// are strictly mutually exclusive: a potion cannot be both Level II and extended.
    pub fn areRedstoneAndGlowstoneMutuallyExclusive() bool {
        return true;
    }

    pub fn canApplyRedstone(potion: PotionState) bool {
        if (potion.potion_type.isInstantaneous()) return false;
        if (potion.amplifier > 0) return false;
        if (potion.extended) return false;
        if (potion.potion_type.isBase()) return false;
        return potion.potion_type.supportsRedstone();
    }

    pub fn applyRedstone(potion: PotionState) ?PotionState {
        if (!canApplyRedstone(potion)) return null;
        var result = potion;
        result.extended = true;
        result.duration_seconds = if (potion.potion_type == .weakness or potion.potion_type == .slowness)
            short_extended_duration
        else if (potion.potion_type == .turtle_master)
            turtle_master_extended_duration
        else
            standard_extended_duration;
        return result;
    }

    pub fn canApplyGlowstone(potion: PotionState) bool {
        if (potion.extended) return false;
        if (potion.amplifier > 0) return false;
        return potion.potion_type.supportsGlowstone();
    }

    pub fn applyGlowstone(potion: PotionState) ?PotionState {
        if (!canApplyGlowstone(potion)) return null;
        var result = potion;
        result.amplifier = 1;
        if (!potion.potion_type.isInstantaneous()) {
            result.duration_seconds = standard_enhanced_duration;
        }
        return result;
    }

    pub fn canApplyFermentedSpiderEye(potion: PotionState) bool {
        return switch (potion.potion_type) {
            .water, .healing, .poison, .swiftness, .leaping, .night_vision, .strength => true,
            else => false,
        };
    }

    pub fn applyFermentedSpiderEye(potion: PotionState) ?PotionState {
        if (!canApplyFermentedSpiderEye(potion)) return null;
        var result = potion;
        switch (potion.potion_type) {
            .water => {
                result.potion_type = .weakness;
                result.duration_seconds = short_base_duration;
                result.amplifier = 0;
                result.extended = false;
            },
            .healing, .poison => {
                result.potion_type = .harming;
                result.duration_seconds = 0.0;
                result.extended = false;
                // Preserves amplifier: Healing II -> Harming II, Poison II -> Harming II
            },
            .swiftness, .leaping => {
                result.potion_type = .slowness;
                if (potion.extended) {
                    result.duration_seconds = short_extended_duration;
                } else if (potion.amplifier > 0) {
                    result.duration_seconds = short_base_duration;
                    result.amplifier = 1;
                } else {
                    result.duration_seconds = short_base_duration;
                }
            },
            .night_vision => {
                result.potion_type = .invisibility;
                result.duration_seconds = if (potion.extended) standard_extended_duration else standard_base_duration;
            },
            .strength => {
                result.potion_type = .weakness;
                result.amplifier = 0;
                result.duration_seconds = if (potion.extended) short_extended_duration else short_base_duration;
            },
            else => return null,
        }
        return result;
    }
};

/// Delivery vessel transformations: Drinkable -> Splash (Gunpowder), Splash -> Lingering (Dragon's Breath).
pub const DeliveryVesselUpgrade = struct {
    pub const lingering_cloud_radius: f32 = 3.0;
    pub const lingering_radius_shrink_per_application: f32 = 0.5;

    pub fn canUpgrade(potion: PotionState, ingredient: Ingredient) bool {
        return switch (ingredient) {
            .gunpowder => potion.vessel == .drinkable,
            .dragons_breath => potion.vessel == .splash,
            else => false,
        };
    }

    pub fn upgrade(potion: PotionState, ingredient: Ingredient) ?PotionState {
        if (!canUpgrade(potion, ingredient)) return null;
        var result = potion;
        switch (ingredient) {
            .gunpowder => {
                result.vessel = .splash;
            },
            .dragons_breath => {
                result.vessel = .lingering;
            },
            else => return null,
        }
        return result;
    }
};

fn distillFromAwkward(potion: PotionState, ingredient: Ingredient) ?PotionState {
    if (potion.potion_type != .awkward) return null;
    const effect_type: PotionType = switch (ingredient) {
        .sugar => .swiftness,
        .rabbit_foot => .leaping,
        .blaze_powder => .strength,
        .glistering_melon_slice => .healing,
        .spider_eye => .poison,
        .ghast_tear => .regeneration,
        .magma_cream => .fire_resistance,
        .pufferfish => .water_breathing,
        .golden_carrot => .night_vision,
        .phantom_membrane => .slow_falling,
        .turtle_helmet => .turtle_master,
        else => return null,
    };

    const duration: f32 = switch (effect_type) {
        .healing => 0.0,
        .turtle_master => turtle_master_base_duration,
        else => standard_base_duration,
    };

    return PotionState{
        .potion_type = effect_type,
        .vessel = potion.vessel,
        .duration_seconds = duration,
        .amplifier = 0,
        .extended = false,
    };
}

/// Core function that resolves brewing any potion with an ingredient.
pub fn brewPotion(potion: PotionState, ingredient: Ingredient) ?PotionState {
    // 1. Delivery vessel upgrade (gunpowder, dragons_breath)
    if (ingredient == .gunpowder or ingredient == .dragons_breath) {
        return DeliveryVesselUpgrade.upgrade(potion, ingredient);
    }

    // 2. Base potion distillation from water bottle
    if (potion.potion_type == .water) {
        if (BasePotionDistillation.distill(potion, ingredient)) |res| {
            return res;
        }
    }

    // 3. Primary effect potion from awkward potion
    if (potion.potion_type == .awkward) {
        if (distillFromAwkward(potion, ingredient)) |res| {
            return res;
        }
    }

    // 4. Modifiers: redstone, glowstone, fermented spider eye
    return switch (ingredient) {
        .redstone_dust => PotionModifierRule.applyRedstone(potion),
        .glowstone_dust => PotionModifierRule.applyGlowstone(potion),
        .fermented_spider_eye => PotionModifierRule.applyFermentedSpiderEye(potion),
        else => null,
    };
}

pub fn canBrewPotion(potion: PotionState, ingredient: Ingredient) bool {
    return brewPotion(potion, ingredient) != null;
}

pub fn areRedstoneAndGlowstoneMutuallyExclusive() bool {
    return PotionModifierRule.areRedstoneAndGlowstoneMutuallyExclusive();
}

pub fn createWaterBottle() PotionState {
    return BasePotionDistillation.waterBottle();
}

pub fn createAwkwardPotion() PotionState {
    return BasePotionDistillation.awkwardPotion();
}

pub fn createMundanePotion() PotionState {
    return BasePotionDistillation.mundanePotion();
}

pub fn createThickPotion() PotionState {
    return BasePotionDistillation.thickPotion();
}

pub fn createWeaknessPotion() PotionState {
    return BasePotionDistillation.potionOfWeakness();
}

pub const waterBottle = createWaterBottle;
pub const awkwardPotion = createAwkwardPotion;
pub const mundanePotion = createMundanePotion;
pub const thickPotion = createThickPotion;
pub const potionOfWeakness = createWeaknessPotion;

/// State for a Brewing Stand tile entity.
pub const BrewingStandState = struct {
    fuel_charges: u5 = 0,
    brew_timer_seconds: f32 = 0.0,
    bottle_slots: [3]?PotionState = .{ null, null, null },
    ingredient: ?Ingredient = null,

    pub fn init() BrewingStandState {
        return .{};
    }

    /// Adds 20 fuel charges from 1 Blaze Powder, capped at max_fuel_charges (20).
    /// Returns true if fuel was added, false if already at maximum.
    pub fn addBlazePowderFuel(self: *BrewingStandState) bool {
        if (self.fuel_charges >= max_fuel_charges) return false;
        self.fuel_charges = @min(max_fuel_charges, self.fuel_charges + charges_per_blaze_powder);
        return true;
    }

    pub fn addBlazePowder(self: *BrewingStandState) bool {
        return self.addBlazePowderFuel();
    }

    pub fn insertIngredient(self: *BrewingStandState, ingredient: Ingredient) void {
        self.ingredient = ingredient;
    }

    pub fn setBottle(self: *BrewingStandState, slot_idx: usize, potion: ?PotionState) void {
        if (slot_idx < 3) {
            self.bottle_slots[slot_idx] = potion;
        }
    }

    pub fn getBottle(self: BrewingStandState, slot_idx: usize) ?PotionState {
        if (slot_idx < 3) {
            return self.bottle_slots[slot_idx];
        }
        return null;
    }

    pub fn bottleCount(self: BrewingStandState) usize {
        var count: usize = 0;
        for (self.bottle_slots) |slot| {
            if (slot != null) count += 1;
        }
        return count;
    }

    /// Checks if brewing can proceed: must have fuel, an ingredient, and at least
    /// one bottle that can react with the ingredient.
    pub fn canBrew(self: BrewingStandState) bool {
        if (self.fuel_charges == 0) return false;
        const ing = self.ingredient orelse return false;
        for (self.bottle_slots) |maybe_slot| {
            if (maybe_slot) |potion| {
                if (canBrewPotion(potion, ing)) return true;
            }
        }
        return false;
    }

    pub fn isBrewing(self: BrewingStandState) bool {
        return self.canBrew() and self.brew_timer_seconds > 0.0;
    }

    pub fn getBrewProgress(self: BrewingStandState) f32 {
        return std.math.clamp(self.brew_timer_seconds / brew_time_seconds, 0.0, 1.0);
    }

    /// Advances the brewing stand by dt seconds.
    /// Returns true if a batch completed brewing in this tick.
    pub fn tick(self: *BrewingStandState, dt: f32) bool {
        if (!self.canBrew()) {
            self.brew_timer_seconds = 0.0;
            return false;
        }

        self.brew_timer_seconds += dt;
        if (self.brew_timer_seconds >= brew_time_seconds) {
            self.finishBrew();
            return true;
        }
        return false;
    }

    /// Advances the brewing stand by a fixed number of game ticks (20 ticks = 1.0 second).
    pub fn tickFixed(self: *BrewingStandState, ticks: u32) bool {
        const dt = @as(f32, @floatFromInt(ticks)) * seconds_per_tick;
        return self.tick(dt);
    }

    /// Completes the brewing cycle: consumes exactly 1 fuel charge, transforms all
    /// valid bottles simultaneously, consumes the ingredient, and resets the timer.
    pub fn finishBrew(self: *BrewingStandState) void {
        const ing = self.ingredient orelse return;
        if (self.fuel_charges == 0) return;

        var any_brewed = false;
        for (&self.bottle_slots) |*maybe_slot| {
            if (maybe_slot.*) |potion| {
                if (brewPotion(potion, ing)) |new_potion| {
                    maybe_slot.* = new_potion;
                    any_brewed = true;
                }
            }
        }

        if (any_brewed) {
            self.fuel_charges -= 1;
            self.ingredient = null;
        }
        self.brew_timer_seconds = 0.0;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "1. BrewingStandState default initialization and 20-charge blaze fuel mechanics" {
    var stand = BrewingStandState.init();
    try std.testing.expectEqual(@as(u5, 0), stand.fuel_charges);
    try std.testing.expectEqual(@as(f32, 0.0), stand.brew_timer_seconds);
    try std.testing.expectEqual(@as(usize, 0), stand.bottleCount());
    try std.testing.expect(stand.ingredient == null);
    try std.testing.expect(!stand.canBrew());

    // 1 Blaze Powder adds 20 fuel charges (max 20)
    try std.testing.expect(stand.addBlazePowderFuel());
    try std.testing.expectEqual(@as(u5, 20), stand.fuel_charges);

    // Adding more blaze powder when already at max 20 returns false and stays at 20
    try std.testing.expect(!stand.addBlazePowderFuel());
    try std.testing.expectEqual(@as(u5, 20), stand.fuel_charges);
}

test "2. BrewingStandState single fuel charge brews all 3 bottles simultaneously" {
    var stand = BrewingStandState.init();
    stand.fuel_charges = 1; // Exactly 1 fuel charge
    stand.bottle_slots[0] = waterBottle();
    stand.bottle_slots[1] = waterBottle();
    stand.bottle_slots[2] = waterBottle();
    stand.insertIngredient(.nether_wart);

    try std.testing.expect(stand.canBrew());
    try std.testing.expectEqual(@as(usize, 3), stand.bottleCount());

    // 20.0 seconds = 400 ticks per batch
    const completed = stand.tick(20.0);
    try std.testing.expect(completed);

    // A single fuel charge brews all 1..3 bottles simultaneously
    try std.testing.expectEqual(@as(u5, 0), stand.fuel_charges);
    try std.testing.expectEqual(@as(f32, 0.0), stand.brew_timer_seconds);
    try std.testing.expect(stand.ingredient == null);

    // All 3 slots transformed into awkward potion
    for (stand.bottle_slots) |slot| {
        try std.testing.expect(slot != null);
        try std.testing.expectEqual(PotionType.awkward, slot.?.potion_type);
        try std.testing.expectEqual(DeliveryVessel.drinkable, slot.?.vessel);
    }
}

test "3. BrewingStandState 1 or 2 bottles in arbitrary slots consume only 1 fuel charge" {
    // Test 1 bottle in slot 1 (slots 0 and 2 empty)
    var stand1 = BrewingStandState.init();
    stand1.fuel_charges = 10;
    stand1.setBottle(1, waterBottle());
    stand1.insertIngredient(.nether_wart);

    try std.testing.expect(stand1.tick(20.0));
    try std.testing.expectEqual(@as(u5, 9), stand1.fuel_charges);
    try std.testing.expect(stand1.bottle_slots[0] == null);
    try std.testing.expect(stand1.bottle_slots[1] != null);
    try std.testing.expectEqual(PotionType.awkward, stand1.bottle_slots[1].?.potion_type);
    try std.testing.expect(stand1.bottle_slots[2] == null);

    // Test 2 bottles in slot 0 and slot 2 (slot 1 empty)
    var stand2 = BrewingStandState.init();
    stand2.fuel_charges = 5;
    stand2.setBottle(0, waterBottle());
    stand2.setBottle(2, waterBottle());
    stand2.insertIngredient(.nether_wart);

    try std.testing.expect(stand2.tick(20.0));
    try std.testing.expectEqual(@as(u5, 4), stand2.fuel_charges);
    try std.testing.expect(stand2.bottle_slots[0] != null);
    try std.testing.expectEqual(PotionType.awkward, stand2.bottle_slots[0].?.potion_type);
    try std.testing.expect(stand2.bottle_slots[1] == null);
    try std.testing.expect(stand2.bottle_slots[2] != null);
    try std.testing.expectEqual(PotionType.awkward, stand2.bottle_slots[2].?.potion_type);
}

test "4. BasePotionDistillation all 4 fundamental water bottle transformations" {
    const water = waterBottle();

    // water_bottle + nether_wart -> awkward_potion (foundation for all effect potions)
    const awkward = BasePotionDistillation.distill(water, .nether_wart).?;
    try std.testing.expectEqual(PotionType.awkward, awkward.potion_type);
    try std.testing.expectEqual(@as(f32, 0.0), awkward.duration_seconds);
    try std.testing.expectEqual(@as(u8, 0), awkward.amplifier);
    try std.testing.expect(!awkward.extended);

    // water_bottle + fermented_spider_eye -> potion_of_weakness (direct brewing without nether wart!)
    const weakness = BasePotionDistillation.distill(water, .fermented_spider_eye).?;
    try std.testing.expectEqual(PotionType.weakness, weakness.potion_type);
    try std.testing.expectEqual(@as(f32, 90.0), weakness.duration_seconds);
    try std.testing.expectEqual(@as(u8, 0), weakness.amplifier);
    try std.testing.expect(!weakness.extended);

    // water_bottle + redstone_dust -> mundane_potion
    const mundane = BasePotionDistillation.distill(water, .redstone_dust).?;
    try std.testing.expectEqual(PotionType.mundane, mundane.potion_type);

    // water_bottle + glowstone_dust -> thick_potion
    const thick = BasePotionDistillation.distill(water, .glowstone_dust).?;
    try std.testing.expectEqual(PotionType.thick, thick.potion_type);
}

test "5. Primary effect brewing from awkward potion" {
    const awkward = awkwardPotion();

    // sugar -> swiftness (speed)
    const speed_pot = brewPotion(awkward, .sugar).?;
    try std.testing.expectEqual(PotionType.swiftness, speed_pot.potion_type);
    try std.testing.expectEqual(@as(f32, 180.0), speed_pot.duration_seconds);

    // rabbit_foot -> leaping (jump boost)
    const leap_pot = brewPotion(awkward, .rabbit_foot).?;
    try std.testing.expectEqual(PotionType.leaping, leap_pot.potion_type);
    try std.testing.expectEqual(@as(f32, 180.0), leap_pot.duration_seconds);

    // blaze_powder -> strength
    const str_pot = brewPotion(awkward, .blaze_powder).?;
    try std.testing.expectEqual(PotionType.strength, str_pot.potion_type);
    try std.testing.expectEqual(@as(f32, 180.0), str_pot.duration_seconds);

    // glistering_melon_slice -> healing (instant health)
    const heal_pot = brewPotion(awkward, .glistering_melon_slice).?;
    try std.testing.expectEqual(PotionType.healing, heal_pot.potion_type);
    try std.testing.expectEqual(@as(f32, 0.0), heal_pot.duration_seconds);

    // spider_eye -> poison
    const poison_pot = brewPotion(awkward, .spider_eye).?;
    try std.testing.expectEqual(PotionType.poison, poison_pot.potion_type);
    try std.testing.expectEqual(@as(f32, 180.0), poison_pot.duration_seconds);

    // golden_carrot -> night_vision
    const nv_pot = brewPotion(awkward, .golden_carrot).?;
    try std.testing.expectEqual(PotionType.night_vision, nv_pot.potion_type);
    try std.testing.expectEqual(@as(f32, 180.0), nv_pot.duration_seconds);
}

test "6. PotionModifierRule redstone extends duration and cannot apply to instant or Level II" {
    const awkward = awkwardPotion();
    const speed_pot = brewPotion(awkward, .sugar).?;

    // redstone_dust extends duration (180s -> 480s, 8:00)
    const extended_speed = PotionModifierRule.applyRedstone(speed_pot).?;
    try std.testing.expect(extended_speed.extended);
    try std.testing.expectEqual(@as(f32, 480.0), extended_speed.duration_seconds);
    try std.testing.expectEqual(@as(u8, 0), extended_speed.amplifier);

    // Redstone extends short base duration (90s -> 240s, 4:00)
    const weakness_pot = potionOfWeakness();
    const extended_weakness = PotionModifierRule.applyRedstone(weakness_pot).?;
    try std.testing.expect(extended_weakness.extended);
    try std.testing.expectEqual(@as(f32, 240.0), extended_weakness.duration_seconds);

    // Redstone CANNOT be applied to already extended potion
    try std.testing.expect(!PotionModifierRule.canApplyRedstone(extended_speed));

    // Redstone CANNOT be applied to instantaneous potions (Instant Health, Instant Damage)
    const heal_pot = brewPotion(awkward, .glistering_melon_slice).?;
    try std.testing.expect(!PotionModifierRule.canApplyRedstone(heal_pot));
    try std.testing.expect(PotionModifierRule.applyRedstone(heal_pot) == null);

    const harm_pot = PotionModifierRule.applyFermentedSpiderEye(heal_pot).?;
    try std.testing.expect(!PotionModifierRule.canApplyRedstone(harm_pot));

    // Redstone CANNOT be applied to Level II (Glowstone-enhanced) potion
    const speed_ii = PotionModifierRule.applyGlowstone(speed_pot).?;
    try std.testing.expect(!PotionModifierRule.canApplyRedstone(speed_ii));
    try std.testing.expect(PotionModifierRule.applyRedstone(speed_ii) == null);
}

test "7. PotionModifierRule glowstone upgrades potency to Level II with reduced duration" {
    const awkward = awkwardPotion();
    const speed_pot = brewPotion(awkward, .sugar).?;

    // glowstone_dust upgrades potency to Level II (amplifier = 1) at reduced duration (180s -> 90s)
    const speed_ii = PotionModifierRule.applyGlowstone(speed_pot).?;
    try std.testing.expectEqual(@as(u8, 1), speed_ii.amplifier);
    try std.testing.expectEqual(@as(f32, 90.0), speed_ii.duration_seconds);
    try std.testing.expect(!speed_ii.extended);

    // Instant Health upgrades to Instant Health II (duration stays 0.0s, amplifier = 1)
    const heal_pot = brewPotion(awkward, .glistering_melon_slice).?;
    const heal_ii = PotionModifierRule.applyGlowstone(heal_pot).?;
    try std.testing.expectEqual(@as(u8, 1), heal_ii.amplifier);
    try std.testing.expectEqual(@as(f32, 0.0), heal_ii.duration_seconds);

    // Glowstone CANNOT be applied if already Level II
    try std.testing.expect(!PotionModifierRule.canApplyGlowstone(speed_ii));

    // Glowstone CANNOT be applied to potions without Level II variants (e.g. Night Vision, Weakness)
    const nv_pot = brewPotion(awkward, .golden_carrot).?;
    try std.testing.expect(!PotionModifierRule.canApplyGlowstone(nv_pot));
    const weakness_pot = potionOfWeakness();
    try std.testing.expect(!PotionModifierRule.canApplyGlowstone(weakness_pot));
}

test "8. PotionModifierRule redstone and glowstone are strictly mutually exclusive" {
    try std.testing.expect(areRedstoneAndGlowstoneMutuallyExclusive());
    try std.testing.expect(PotionModifierRule.areRedstoneAndGlowstoneMutuallyExclusive());

    const awkward = awkwardPotion();
    const speed_pot = brewPotion(awkward, .sugar).?;

    // Path A: Extended first -> Glowstone blocked
    const extended_speed = PotionModifierRule.applyRedstone(speed_pot).?;
    try std.testing.expect(extended_speed.extended);
    try std.testing.expect(!PotionModifierRule.canApplyGlowstone(extended_speed));
    try std.testing.expect(brewPotion(extended_speed, .glowstone_dust) == null);

    // Path B: Level II first -> Redstone blocked
    const speed_ii = PotionModifierRule.applyGlowstone(speed_pot).?;
    try std.testing.expectEqual(@as(u8, 1), speed_ii.amplifier);
    try std.testing.expect(!PotionModifierRule.canApplyRedstone(speed_ii));
    try std.testing.expect(brewPotion(speed_ii, .redstone_dust) == null);
}

test "9. PotionModifierRule fermented spider eye corrupts positive potions to negative counterparts" {
    const awkward = awkwardPotion();

    // healing -> harming
    const heal_pot = brewPotion(awkward, .glistering_melon_slice).?;
    const harm_pot = PotionModifierRule.applyFermentedSpiderEye(heal_pot).?;
    try std.testing.expectEqual(PotionType.harming, harm_pot.potion_type);
    try std.testing.expectEqual(@as(f32, 0.0), harm_pot.duration_seconds);

    // poison -> harming
    const poison_pot = brewPotion(awkward, .spider_eye).?;
    const harm_from_poison = PotionModifierRule.applyFermentedSpiderEye(poison_pot).?;
    try std.testing.expectEqual(PotionType.harming, harm_from_poison.potion_type);

    // swiftness -> slowness
    const speed_pot = brewPotion(awkward, .sugar).?;
    const slow_from_speed = PotionModifierRule.applyFermentedSpiderEye(speed_pot).?;
    try std.testing.expectEqual(PotionType.slowness, slow_from_speed.potion_type);
    try std.testing.expectEqual(@as(f32, 90.0), slow_from_speed.duration_seconds);

    // leaping -> slowness
    const leap_pot = brewPotion(awkward, .rabbit_foot).?;
    const slow_from_leap = PotionModifierRule.applyFermentedSpiderEye(leap_pot).?;
    try std.testing.expectEqual(PotionType.slowness, slow_from_leap.potion_type);

    // night_vision -> invisibility
    const nv_pot = brewPotion(awkward, .golden_carrot).?;
    const invis_pot = PotionModifierRule.applyFermentedSpiderEye(nv_pot).?;
    try std.testing.expectEqual(PotionType.invisibility, invis_pot.potion_type);
    try std.testing.expectEqual(@as(f32, 180.0), invis_pot.duration_seconds);

    // strength -> weakness
    const str_pot = brewPotion(awkward, .blaze_powder).?;
    const weak_from_str = PotionModifierRule.applyFermentedSpiderEye(str_pot).?;
    try std.testing.expectEqual(PotionType.weakness, weak_from_str.potion_type);
    try std.testing.expectEqual(@as(f32, 90.0), weak_from_str.duration_seconds);

    // water_bottle -> weakness
    const water = waterBottle();
    const weak_from_water = PotionModifierRule.applyFermentedSpiderEye(water).?;
    try std.testing.expectEqual(PotionType.weakness, weak_from_water.potion_type);
}

test "10. PotionModifierRule fermented spider eye preserves potency amplifier and extended duration" {
    const awkward = awkwardPotion();

    // Healing II + Fermented Spider Eye -> Harming II (preserves amplifier = 1)
    const heal_pot = brewPotion(awkward, .glistering_melon_slice).?;
    const heal_ii = PotionModifierRule.applyGlowstone(heal_pot).?;
    const harm_ii = PotionModifierRule.applyFermentedSpiderEye(heal_ii).?;
    try std.testing.expectEqual(PotionType.harming, harm_ii.potion_type);
    try std.testing.expectEqual(@as(u8, 1), harm_ii.amplifier);

    // Night Vision Extended (480s) + Fermented Spider Eye -> Invisibility Extended (480s)
    const nv_pot = brewPotion(awkward, .golden_carrot).?;
    const nv_ext = PotionModifierRule.applyRedstone(nv_pot).?;
    const invis_ext = PotionModifierRule.applyFermentedSpiderEye(nv_ext).?;
    try std.testing.expectEqual(PotionType.invisibility, invis_ext.potion_type);
    try std.testing.expect(invis_ext.extended);
    try std.testing.expectEqual(@as(f32, 480.0), invis_ext.duration_seconds);

    // Swiftness Extended (480s) + Fermented Spider Eye -> Slowness Extended (240s)
    const speed_pot = brewPotion(awkward, .sugar).?;
    const speed_ext = PotionModifierRule.applyRedstone(speed_pot).?;
    const slow_ext = PotionModifierRule.applyFermentedSpiderEye(speed_ext).?;
    try std.testing.expectEqual(PotionType.slowness, slow_ext.potion_type);
    try std.testing.expect(slow_ext.extended);
    try std.testing.expectEqual(@as(f32, 240.0), slow_ext.duration_seconds);

    // Strength Extended (480s) + Fermented Spider Eye -> Weakness Extended (240s)
    const str_pot = brewPotion(awkward, .blaze_powder).?;
    const str_ext = PotionModifierRule.applyRedstone(str_pot).?;
    const weak_ext = PotionModifierRule.applyFermentedSpiderEye(str_ext).?;
    try std.testing.expectEqual(PotionType.weakness, weak_ext.potion_type);
    try std.testing.expect(weak_ext.extended);
    try std.testing.expectEqual(@as(f32, 240.0), weak_ext.duration_seconds);
}

test "11. DeliveryVesselUpgrade gunpowder converts any drinkable potion into splash" {
    // Drinkable water bottle -> Splash water bottle
    const water = waterBottle();
    try std.testing.expect(DeliveryVesselUpgrade.canUpgrade(water, .gunpowder));
    const splash_water = DeliveryVesselUpgrade.upgrade(water, .gunpowder).?;
    try std.testing.expectEqual(DeliveryVessel.splash, splash_water.vessel);
    try std.testing.expectEqual(PotionType.water, splash_water.potion_type);

    // Drinkable Swiftness II -> Splash Swiftness II
    const awkward = awkwardPotion();
    const speed_pot = brewPotion(awkward, .sugar).?;
    const speed_ii = PotionModifierRule.applyGlowstone(speed_pot).?;
    const splash_speed_ii = brewPotion(speed_ii, .gunpowder).?;
    try std.testing.expectEqual(DeliveryVessel.splash, splash_speed_ii.vessel);
    try std.testing.expectEqual(PotionType.swiftness, splash_speed_ii.potion_type);
    try std.testing.expectEqual(@as(u8, 1), splash_speed_ii.amplifier);
    try std.testing.expectEqual(@as(f32, 90.0), splash_speed_ii.duration_seconds);

    // Gunpowder CANNOT be applied to an already splash potion
    try std.testing.expect(!DeliveryVesselUpgrade.canUpgrade(splash_speed_ii, .gunpowder));
    try std.testing.expect(brewPotion(splash_speed_ii, .gunpowder) == null);
}

test "12. DeliveryVesselUpgrade dragon's breath converts splash into lingering only" {
    const awkward = awkwardPotion();
    const speed_pot = brewPotion(awkward, .sugar).?;
    const splash_speed = brewPotion(speed_pot, .gunpowder).?;

    // Splash -> Lingering with dragon's breath
    try std.testing.expect(DeliveryVesselUpgrade.canUpgrade(splash_speed, .dragons_breath));
    const lingering_speed = DeliveryVesselUpgrade.upgrade(splash_speed, .dragons_breath).?;
    try std.testing.expectEqual(DeliveryVessel.lingering, lingering_speed.vessel);
    try std.testing.expectEqual(PotionType.swiftness, lingering_speed.potion_type);

    // Dragon's breath CANNOT be applied directly to a drinkable potion!
    try std.testing.expect(!DeliveryVesselUpgrade.canUpgrade(speed_pot, .dragons_breath));
    try std.testing.expect(brewPotion(speed_pot, .dragons_breath) == null);

    // Dragon's breath CANNOT be applied to an already lingering potion
    try std.testing.expect(!DeliveryVesselUpgrade.canUpgrade(lingering_speed, .dragons_breath));
    try std.testing.expect(brewPotion(lingering_speed, .dragons_breath) == null);
}

test "13. Lingering potion AreaEffectCloud 3.0m initial radius shrinks by 0.5m per entity application" {
    const awkward = awkwardPotion();
    const heal_pot = brewPotion(awkward, .glistering_melon_slice).?;
    const splash_heal = brewPotion(heal_pot, .gunpowder).?;
    const lingering_heal = brewPotion(splash_heal, .dragons_breath).?;

    // Non-lingering potions cannot create AoE cloud
    try std.testing.expect(heal_pot.createAoECloud() == null);
    try std.testing.expect(splash_heal.createAoECloud() == null);

    // Lingering potion creates AreaEffectCloud with radius 3.0m
    var cloud = lingering_heal.createAoECloud().?;
    try std.testing.expectEqual(@as(f32, 3.0), cloud.radius);
    try std.testing.expectEqual(@as(u32, 6), cloud.remainingApplications());
    try std.testing.expect(!cloud.isDissipated());

    // Entity 1: radius shrinks to 2.5m
    try std.testing.expect(cloud.applyToEntity());
    try std.testing.expectEqual(@as(f32, 2.5), cloud.radius);
    try std.testing.expectEqual(@as(u32, 5), cloud.remainingApplications());

    // Entity 2: radius shrinks to 2.0m
    try std.testing.expect(cloud.applyToEntity());
    try std.testing.expectEqual(@as(f32, 2.0), cloud.radius);

    // Entity 3: radius shrinks to 1.5m
    try std.testing.expect(cloud.applyToEntity());
    try std.testing.expectEqual(@as(f32, 1.5), cloud.radius);

    // Entity 4: radius shrinks to 1.0m
    try std.testing.expect(cloud.applyToEntity());
    try std.testing.expectEqual(@as(f32, 1.0), cloud.radius);

    // Entity 5: radius shrinks to 0.5m
    try std.testing.expect(cloud.applyToEntity());
    try std.testing.expectEqual(@as(f32, 0.5), cloud.radius);

    // Entity 6: radius shrinks to 0.0m (cloud dissipates!)
    try std.testing.expect(cloud.applyToEntity());
    try std.testing.expectEqual(@as(f32, 0.0), cloud.radius);
    try std.testing.expect(cloud.isDissipated());
    try std.testing.expectEqual(@as(u32, 0), cloud.remainingApplications());

    // Entity 7: application fails because cloud has dissipated
    try std.testing.expect(!cloud.applyToEntity());
}

test "14. Brewing cycle timing 20.0 seconds / 400 ticks with reset on interruption" {
    var stand = BrewingStandState.init();
    stand.fuel_charges = 5;
    stand.setBottle(0, waterBottle());
    stand.insertIngredient(.nether_wart);

    // 200 ticks = 10.0 seconds (50% progress, not finished)
    const tick1_done = stand.tickFixed(200);
    try std.testing.expect(!tick1_done);
    try std.testing.expectEqual(@as(f32, 10.0), stand.brew_timer_seconds);
    try std.testing.expectEqual(@as(f32, 0.5), stand.getBrewProgress());
    try std.testing.expect(stand.isBrewing());

    // If ingredient is removed mid-cycle, timer resets to 0.0 and fuel is preserved
    stand.ingredient = null;
    const tick2_done = stand.tick(1.0);
    try std.testing.expect(!tick2_done);
    try std.testing.expectEqual(@as(f32, 0.0), stand.brew_timer_seconds);
    try std.testing.expectEqual(@as(u5, 5), stand.fuel_charges);

    // Re-insert ingredient and tick full 400 ticks (20.0s) -> finishes brewing
    stand.insertIngredient(.nether_wart);
    const tick3_done = stand.tickFixed(400);
    try std.testing.expect(tick3_done);
    try std.testing.expectEqual(@as(u5, 4), stand.fuel_charges);
    try std.testing.expectEqual(PotionType.awkward, stand.bottle_slots[0].?.potion_type);
    try std.testing.expectEqual(@as(f32, 0.0), stand.brew_timer_seconds);
}

test "15. Blaze powder 20-batch endurance: 1 powder powers exactly 20 batches" {
    var stand = BrewingStandState.init();
    try std.testing.expect(stand.addBlazePowderFuel());
    try std.testing.expectEqual(@as(u5, 20), stand.fuel_charges);

    // Run 20 consecutive single-batch brews
    var batch: usize = 0;
    while (batch < 20) : (batch += 1) {
        stand.setBottle(0, waterBottle());
        stand.insertIngredient(.nether_wart);
        try std.testing.expect(stand.canBrew());
        try std.testing.expect(stand.tick(20.0));
        try std.testing.expectEqual(@as(u5, @intCast(19 - batch)), stand.fuel_charges);
    }

    // After 20 batches, fuel_charges is exhausted (0)
    try std.testing.expectEqual(@as(u5, 0), stand.fuel_charges);

    // 21st batch cannot brew without new fuel
    stand.setBottle(0, waterBottle());
    stand.insertIngredient(.nether_wart);
    try std.testing.expect(!stand.canBrew());
    try std.testing.expect(!stand.tick(20.0));
}

test "16. Mixed bottle slots only compatible bottles brew and fuel is consumed once" {
    var stand = BrewingStandState.init();
    stand.fuel_charges = 3;

    // Slot 0: Water Bottle (compatible with Nether Wart)
    // Slot 1: Awkward Potion (incompatible with Nether Wart)
    // Slot 2: Water Bottle (compatible with Nether Wart)
    stand.setBottle(0, waterBottle());
    stand.setBottle(1, awkwardPotion());
    stand.setBottle(2, waterBottle());
    stand.insertIngredient(.nether_wart);

    try std.testing.expect(stand.canBrew());
    try std.testing.expect(stand.tick(20.0));

    // Consumed exactly 1 fuel charge for the batch
    try std.testing.expectEqual(@as(u5, 2), stand.fuel_charges);

    // Slots 0 and 2 converted to Awkward, Slot 1 remained untouched
    try std.testing.expectEqual(PotionType.awkward, stand.bottle_slots[0].?.potion_type);
    try std.testing.expectEqual(PotionType.awkward, stand.bottle_slots[1].?.potion_type);
    try std.testing.expectEqual(PotionType.awkward, stand.bottle_slots[2].?.potion_type);
    try std.testing.expect(stand.ingredient == null);
}
