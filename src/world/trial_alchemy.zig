const std = @import("std");

/// Duration for all Tricky Trials 1.21 potions (3 minutes = 180 seconds).
pub const trial_potion_duration: f32 = 180.0;
pub const infested_duration: f32 = 180.0;
pub const oozing_duration: f32 = 180.0;
pub const weaving_duration: f32 = 180.0;
pub const wind_charged_duration: f32 = 180.0;

/// Movement speed multipliers in cobwebs.
/// Normal movement speed is 0.25x; Weaving potion doubles it to 0.50x.
pub const cobweb_normal_speed_multiplier: f32 = 0.25;
pub const cobweb_weaving_speed_multiplier: f32 = 0.50;

/// Returns the cobweb movement speed multiplier: 0.50x when weaving is active, 0.25x otherwise.
pub fn cobwebSpeedMultiplier(has_weaving: bool) f32 {
    return if (has_weaving) cobweb_weaving_speed_multiplier else cobweb_normal_speed_multiplier;
}

/// Infested effect proc constants: 10% chance when hurt to spawn 1-2 Silverfish.
pub const infested_proc_chance_percent: u8 = 10;
pub const min_silverfish_spawn: u8 = 1;
pub const max_silverfish_spawn: u8 = 2;

/// Checks if an infested proc succeeds for a given roll.
/// A roll modulo 10 == 0 gives exactly a 10% proc rate across uniform integer rolls.
pub fn canProcSilverfish(roll: u8) bool {
    return (roll % 10) == 0;
}

/// Computes the number of silverfish spawned on a successful proc (1 or 2).
pub fn silverfishCountForRoll(roll: u8) u8 {
    return 1 + ((roll / 10) % 2);
}

/// Oozing effect death constants: 2 Medium Slimes in a 5x5x5 clear volume.
pub const oozing_slime_count: u8 = 2;
pub const oozing_volume_extent: u8 = 5;

pub const SlimeSize = enum {
    small,
    medium,
    large,
};
pub const oozing_slime_size: SlimeSize = .medium;

/// Checks if an offset (dx, dy, dz) lies within the 5x5x5 clear volume centered on the entity.
pub fn isWithinSlimeVolume(dx: i32, dy: i32, dz: i32) bool {
    return @abs(dx) <= 2 and @abs(dy) <= 2 and @abs(dz) <= 2;
}

/// Weaving effect death constants: 2-3 Cobweb blocks on death.
pub const min_weaving_death_cobwebs: u8 = 2;
pub const max_weaving_death_cobwebs: u8 = 3;

/// Wind Charged effect death constants: upward wind burst impulse and radial knockback.
pub const wind_charged_burst_radius: f32 = 3.5;
pub const wind_charged_burst_radius_sq: f32 = 12.25;
pub const wind_charged_upward_vy: f32 = 6.5;
pub const wind_charged_knockback_horizontal: f32 = 6.0;

pub const KnockbackImpulse = struct {
    vx: f32,
    vy: f32,
    vz: f32,
};

/// Computes the 3D knockback impulse emitted by a Wind Charged death burst.
pub fn calculateDeathBurstKnockback(bx: f32, bz: f32, tx: f32, tz: f32) KnockbackImpulse {
    const dx = tx - bx;
    const dz = tz - bz;
    const len = @max(0.25, @sqrt(dx * dx + dz * dz));
    return .{
        .vx = (dx / len) * wind_charged_knockback_horizontal,
        .vy = wind_charged_upward_vy,
        .vz = (dz / len) * wind_charged_knockback_horizontal,
    };
}

/// Checks if a target position is within the Wind Charged death burst radius.
pub fn isWithinBurstRadius(bx: f32, by: f32, bz: f32, tx: f32, ty: f32, tz: f32) bool {
    const dx = tx - bx;
    const dy = ty - by;
    const dz = tz - bz;
    return (dx * dx + dy * dy + dz * dz) <= wind_charged_burst_radius_sq;
}

/// Enum representing the 4 Tricky Trials potion variants.
pub const TrialPotionType = enum {
    infested,
    oozing,
    weaving,
    wind_charged,

    pub fn duration(self: TrialPotionType) f32 {
        _ = self;
        return trial_potion_duration;
    }

    pub fn name(self: TrialPotionType) []const u8 {
        return switch (self) {
            .infested => "Potion of Infested",
            .oozing => "Potion of Oozing",
            .weaving => "Potion of Weaving",
            .wind_charged => "Potion of Wind Charged",
        };
    }
};

/// Brewing ingredients that react with Awkward Potion to brew Trial Potions.
pub const TrialIngredient = enum {
    stone,
    slime_block,
    cobweb,
    breeze_rod,
};

/// Common item tag constants for brewing integration.
pub const AwkwardPotionTag: u16 = 400;
pub const StoneTag: u16 = 1;
pub const SlimeBlockTag: u16 = 207;
pub const CobwebTag: u16 = 139;
pub const BreezeRodTag: u16 = 371;

pub const PotionInfestedTag: u16 = 401;
pub const PotionOozingTag: u16 = 402;
pub const PotionWeavingTag: u16 = 403;
pub const PotionWindChargedTag: u16 = 404;

/// Resolves the brewed TrialPotionType from a brewing ingredient.
pub fn brewTrialPotion(ingredient: TrialIngredient) TrialPotionType {
    return switch (ingredient) {
        .stone => .infested,
        .slime_block => .oozing,
        .cobweb => .weaving,
        .breeze_rod => .wind_charged,
    };
}

/// Resolves brewing from Awkward Potion tag + reagent item tag.
pub fn brewFromAwkward(base_tag: u16, reagent_tag: u16) ?TrialPotionType {
    if (base_tag != AwkwardPotionTag) return null;
    return switch (reagent_tag) {
        StoneTag => .infested,
        SlimeBlockTag => .oozing,
        CobwebTag => .weaving,
        BreezeRodTag => .wind_charged,
        else => null,
    };
}

/// Resolves resulting potion item tag from Awkward Potion tag + reagent item tag.
pub fn brewPotionTag(base_tag: u16, reagent_tag: u16) ?u16 {
    const potion_type = brewFromAwkward(base_tag, reagent_tag) orelse return null;
    return switch (potion_type) {
        .infested => PotionInfestedTag,
        .oozing => PotionOozingTag,
        .weaving => PotionWeavingTag,
        .wind_charged => PotionWindChargedTag,
    };
}

/// Returns the brewing ingredient required to brew a specific TrialPotionType.
pub fn ingredientForPotion(potion: TrialPotionType) TrialIngredient {
    return switch (potion) {
        .infested => .stone,
        .oozing => .slime_block,
        .weaving => .cobweb,
        .wind_charged => .breeze_rod,
    };
}

/// Checks if an item tag is one of the 4 Tricky Trials brewing reagents.
pub fn isTrialIngredientTag(tag: u16) bool {
    return tag == StoneTag or tag == SlimeBlockTag or tag == CobwebTag or tag == BreezeRodTag;
}

/// Result of evaluating death triggers for an entity with active trial potion effects.
pub const DeathTriggerResult = struct {
    slimes: u8 = 0,
    cobwebs: u8 = 0,
    wind_burst: bool = false,

    // Aliases matching prompt naming
    slimes_to_spawn: u8 = 0,
    cobwebs_to_spawn: u8 = 0,

    // Specific trigger metadata
    slime_size: SlimeSize = .medium,
    slime_volume_extent: u8 = 5,
    wind_burst_vy: f32 = 0.0,
    wind_burst_radius: f32 = 0.0,

    pub fn hasSlimes(self: DeathTriggerResult) bool {
        return self.slimes > 0;
    }

    pub fn hasCobwebs(self: DeathTriggerResult) bool {
        return self.cobwebs > 0;
    }

    pub fn hasWindBurst(self: DeathTriggerResult) bool {
        return self.wind_burst;
    }
};

/// Active potion effect timers for an entity or player.
pub const TrialPotionEffects = struct {
    infested: f32 = 0.0,
    oozing: f32 = 0.0,
    weaving: f32 = 0.0,
    wind_charged: f32 = 0.0,

    pub fn init() TrialPotionEffects {
        return .{};
    }

    /// Ticks down all active trial potion timers by dt, clamping at zero.
    pub fn tickEffects(self: *TrialPotionEffects, dt: f32) void {
        self.infested = clampZero(self.infested - dt);
        self.oozing = clampZero(self.oozing - dt);
        self.weaving = clampZero(self.weaving - dt);
        self.wind_charged = clampZero(self.wind_charged - dt);
    }

    /// Evaluates Infested proc when entity takes damage.
    /// Returns 1-2 Silverfish to spawn if proc succeeds (10% chance on roll % 10 == 0); 0 otherwise.
    pub fn onEntityHurt(self: TrialPotionEffects, roll: u8) u8 {
        if (self.infested <= 0.0) return 0;
        if (!canProcSilverfish(roll)) return 0;
        return silverfishCountForRoll(roll);
    }

    /// Evaluates death triggers for all active effects with default roll.
    pub fn onEntityDeath(self: TrialPotionEffects) DeathTriggerResult {
        return self.onEntityDeathWithRoll(0);
    }

    /// Evaluates death triggers for all active effects with explicit roll for web variation (2-3 cobwebs).
    pub fn onEntityDeathWithRoll(self: TrialPotionEffects, roll: u8) DeathTriggerResult {
        var res = DeathTriggerResult{};
        if (self.oozing > 0.0) {
            res.slimes = oozing_slime_count;
            res.slimes_to_spawn = oozing_slime_count;
            res.slime_size = oozing_slime_size;
            res.slime_volume_extent = oozing_volume_extent;
        }
        if (self.weaving > 0.0) {
            const count: u8 = if ((roll % 2) == 0) min_weaving_death_cobwebs else max_weaving_death_cobwebs;
            res.cobwebs = count;
            res.cobwebs_to_spawn = count;
        }
        if (self.wind_charged > 0.0) {
            res.wind_burst = true;
            res.wind_burst_vy = wind_charged_upward_vy;
            res.wind_burst_radius = wind_charged_burst_radius;
        }
        return res;
    }

    /// Returns movement speed multiplier in cobwebs based on active weaving timer (0.50x if active, 0.25x otherwise).
    pub fn cobwebSpeedMultiplier(self: TrialPotionEffects) f32 {
        return cobwebSpeedMultiplierHelper(self.weaving > 0.0);
    }

    /// Applies a trial potion effect for standard 180s duration.
    pub fn apply(self: *TrialPotionEffects, potion: TrialPotionType) void {
        switch (potion) {
            .infested => self.infested = trial_potion_duration,
            .oozing => self.oozing = trial_potion_duration,
            .weaving => self.weaving = trial_potion_duration,
            .wind_charged => self.wind_charged = trial_potion_duration,
        }
    }

    /// Resets all timers to zero.
    pub fn clear(self: *TrialPotionEffects) void {
        self.infested = 0.0;
        self.oozing = 0.0;
        self.weaving = 0.0;
        self.wind_charged = 0.0;
    }

    pub fn hasInfested(self: TrialPotionEffects) bool {
        return self.infested > 0.0;
    }

    pub fn hasOozing(self: TrialPotionEffects) bool {
        return self.oozing > 0.0;
    }

    pub fn hasWeaving(self: TrialPotionEffects) bool {
        return self.weaving > 0.0;
    }

    pub fn hasWindCharged(self: TrialPotionEffects) bool {
        return self.wind_charged > 0.0;
    }
};

const cobwebSpeedMultiplierHelper = cobwebSpeedMultiplier;

/// Top-level function for ticking potion timers on a TrialPotionEffects struct.
pub fn tickEffects(effects: *TrialPotionEffects, dt: f32) void {
    effects.tickEffects(dt);
}

/// Top-level function for evaluating hurt proc on Infested effect.
pub fn onEntityHurt(effects: TrialPotionEffects, roll: u8) u8 {
    return effects.onEntityHurt(roll);
}

/// Top-level function for evaluating entity death triggers across active trial potions.
pub fn onEntityDeath(effects: TrialPotionEffects) DeathTriggerResult {
    return effects.onEntityDeath();
}

/// Top-level function for evaluating entity death triggers with explicit roll.
pub fn onEntityDeathWithRoll(effects: TrialPotionEffects, roll: u8) DeathTriggerResult {
    return effects.onEntityDeathWithRoll(roll);
}

fn clampZero(value: f32) f32 {
    return if (value < 0.0) 0.0 else value;
}

// =========================================================================
// UNIT TESTS (Comprehensive coverage of all Milestone 301 requirements)
// =========================================================================

test "constants have expected values" {
    try std.testing.expectEqual(@as(f32, 180.0), trial_potion_duration);
    try std.testing.expectEqual(@as(f32, 180.0), infested_duration);
    try std.testing.expectEqual(@as(f32, 180.0), oozing_duration);
    try std.testing.expectEqual(@as(f32, 180.0), weaving_duration);
    try std.testing.expectEqual(@as(f32, 180.0), wind_charged_duration);
    try std.testing.expectEqual(@as(f32, 0.25), cobweb_normal_speed_multiplier);
    try std.testing.expectEqual(@as(f32, 0.50), cobweb_weaving_speed_multiplier);
    try std.testing.expectEqual(@as(u8, 10), infested_proc_chance_percent);
    try std.testing.expectEqual(@as(u8, 2), oozing_slime_count);
    try std.testing.expectEqual(@as(u8, 5), oozing_volume_extent);
    try std.testing.expectEqual(SlimeSize.medium, oozing_slime_size);
    try std.testing.expectEqual(@as(u8, 2), min_weaving_death_cobwebs);
    try std.testing.expectEqual(@as(u8, 3), max_weaving_death_cobwebs);
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), wind_charged_burst_radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), wind_charged_upward_vy, 0.001);
}

test "brewing recipe ingredient enum mapping" {
    try std.testing.expectEqual(TrialPotionType.infested, brewTrialPotion(.stone));
    try std.testing.expectEqual(TrialPotionType.oozing, brewTrialPotion(.slime_block));
    try std.testing.expectEqual(TrialPotionType.weaving, brewTrialPotion(.cobweb));
    try std.testing.expectEqual(TrialPotionType.wind_charged, brewTrialPotion(.breeze_rod));
}

test "brewFromAwkward with item tags" {
    try std.testing.expectEqual(TrialPotionType.infested, brewFromAwkward(AwkwardPotionTag, StoneTag).?);
    try std.testing.expectEqual(TrialPotionType.oozing, brewFromAwkward(AwkwardPotionTag, SlimeBlockTag).?);
    try std.testing.expectEqual(TrialPotionType.weaving, brewFromAwkward(AwkwardPotionTag, CobwebTag).?);
    try std.testing.expectEqual(TrialPotionType.wind_charged, brewFromAwkward(AwkwardPotionTag, BreezeRodTag).?);
}

test "brewFromAwkward rejects non-awkward base and unknown reagents" {
    // Water bottle / glass vial (non-awkward) base rejected
    try std.testing.expect(brewFromAwkward(15, StoneTag) == null);
    try std.testing.expect(brewFromAwkward(0, SlimeBlockTag) == null);
    // Unknown reagent rejected
    try std.testing.expect(brewFromAwkward(AwkwardPotionTag, 999) == null);
    try std.testing.expect(brewFromAwkward(AwkwardPotionTag, 14) == null);
}

test "brewPotionTag returns expected potion tags" {
    try std.testing.expectEqual(PotionInfestedTag, brewPotionTag(AwkwardPotionTag, StoneTag).?);
    try std.testing.expectEqual(PotionOozingTag, brewPotionTag(AwkwardPotionTag, SlimeBlockTag).?);
    try std.testing.expectEqual(PotionWeavingTag, brewPotionTag(AwkwardPotionTag, CobwebTag).?);
    try std.testing.expectEqual(PotionWindChargedTag, brewPotionTag(AwkwardPotionTag, BreezeRodTag).?);
    try std.testing.expect(brewPotionTag(AwkwardPotionTag, 26) == null);
}

test "ingredientForPotion maps each potion back to reagent" {
    try std.testing.expectEqual(TrialIngredient.stone, ingredientForPotion(.infested));
    try std.testing.expectEqual(TrialIngredient.slime_block, ingredientForPotion(.oozing));
    try std.testing.expectEqual(TrialIngredient.cobweb, ingredientForPotion(.weaving));
    try std.testing.expectEqual(TrialIngredient.breeze_rod, ingredientForPotion(.wind_charged));
}

test "isTrialIngredientTag identification" {
    try std.testing.expect(isTrialIngredientTag(StoneTag));
    try std.testing.expect(isTrialIngredientTag(SlimeBlockTag));
    try std.testing.expect(isTrialIngredientTag(CobwebTag));
    try std.testing.expect(isTrialIngredientTag(BreezeRodTag));
    try std.testing.expect(!isTrialIngredientTag(14)); // Sand
    try std.testing.expect(!isTrialIngredientTag(26)); // Iron Ingot
}

test "TrialPotionType names and durations" {
    try std.testing.expectEqualStrings("Potion of Infested", TrialPotionType.infested.name());
    try std.testing.expectEqualStrings("Potion of Oozing", TrialPotionType.oozing.name());
    try std.testing.expectEqualStrings("Potion of Weaving", TrialPotionType.weaving.name());
    try std.testing.expectEqualStrings("Potion of Wind Charged", TrialPotionType.wind_charged.name());
    try std.testing.expectEqual(@as(f32, 180.0), TrialPotionType.infested.duration());
    try std.testing.expectEqual(@as(f32, 180.0), TrialPotionType.oozing.duration());
}

test "TrialPotionEffects default state is inactive and zero" {
    const effects = TrialPotionEffects.init();
    try std.testing.expectEqual(@as(f32, 0.0), effects.infested);
    try std.testing.expectEqual(@as(f32, 0.0), effects.oozing);
    try std.testing.expectEqual(@as(f32, 0.0), effects.weaving);
    try std.testing.expectEqual(@as(f32, 0.0), effects.wind_charged);
    try std.testing.expect(!effects.hasInfested());
    try std.testing.expect(!effects.hasOozing());
    try std.testing.expect(!effects.hasWeaving());
    try std.testing.expect(!effects.hasWindCharged());
}

test "tickEffects decrements all active timers" {
    var effects = TrialPotionEffects{
        .infested = 180.0,
        .oozing = 120.0,
        .weaving = 60.0,
        .wind_charged = 30.0,
    };
    tickEffects(&effects, 15.0);
    try std.testing.expectApproxEqAbs(@as(f32, 165.0), effects.infested, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 105.0), effects.oozing, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 45.0), effects.weaving, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), effects.wind_charged, 0.001);
}

test "tickEffects clamps to zero and never goes negative" {
    var effects = TrialPotionEffects{
        .infested = 2.0,
        .oozing = 1.0,
        .weaving = 0.5,
        .wind_charged = 0.1,
    };
    effects.tickEffects(10.0);
    try std.testing.expectEqual(@as(f32, 0.0), effects.infested);
    try std.testing.expectEqual(@as(f32, 0.0), effects.oozing);
    try std.testing.expectEqual(@as(f32, 0.0), effects.weaving);
    try std.testing.expectEqual(@as(f32, 0.0), effects.wind_charged);
}

test "tickEffects leaves zero timers at zero" {
    var effects = TrialPotionEffects{};
    tickEffects(&effects, 5.0);
    try std.testing.expectEqual(@as(f32, 0.0), effects.infested);
    try std.testing.expectEqual(@as(f32, 0.0), effects.oozing);
    try std.testing.expectEqual(@as(f32, 0.0), effects.weaving);
    try std.testing.expectEqual(@as(f32, 0.0), effects.wind_charged);
}

test "tickEffects expires full 180s duration exactly" {
    var effects = TrialPotionEffects{};
    effects.apply(.infested);
    try std.testing.expectEqual(@as(f32, 180.0), effects.infested);
    try std.testing.expect(effects.hasInfested());
    tickEffects(&effects, 180.0);
    try std.testing.expectEqual(@as(f32, 0.0), effects.infested);
    try std.testing.expect(!effects.hasInfested());
}

test "Infested onEntityHurt procs 1-2 silverfish on 10% chance" {
    const effects = TrialPotionEffects{ .infested = 180.0 };
    // roll 0 mod 10 == 0 -> proc, (0 / 10) % 2 == 0 -> 1 silverfish
    try std.testing.expectEqual(@as(u8, 1), effects.onEntityHurt(0));
    // roll 10 mod 10 == 0 -> proc, (10 / 10) % 2 == 1 -> 2 silverfish
    try std.testing.expectEqual(@as(u8, 2), effects.onEntityHurt(10));
    // roll 20 mod 10 == 0 -> proc, (20 / 10) % 2 == 0 -> 1 silverfish
    try std.testing.expectEqual(@as(u8, 1), effects.onEntityHurt(20));
    // roll 30 mod 10 == 0 -> proc, (30 / 10) % 2 == 1 -> 2 silverfish
    try std.testing.expectEqual(@as(u8, 2), effects.onEntityHurt(30));
}

test "Infested onEntityHurt yields zero when proc fails" {
    const effects = TrialPotionEffects{ .infested = 180.0 };
    // Non-multiples of 10 do not proc (90% of rolls)
    try std.testing.expectEqual(@as(u8, 0), effects.onEntityHurt(1));
    try std.testing.expectEqual(@as(u8, 0), effects.onEntityHurt(2));
    try std.testing.expectEqual(@as(u8, 0), effects.onEntityHurt(5));
    try std.testing.expectEqual(@as(u8, 0), effects.onEntityHurt(9));
    try std.testing.expectEqual(@as(u8, 0), effects.onEntityHurt(17));
    try std.testing.expectEqual(@as(u8, 0), effects.onEntityHurt(99));
}

test "Infested onEntityHurt yields zero when effect is inactive or expired" {
    const inactive = TrialPotionEffects{ .infested = 0.0 };
    try std.testing.expectEqual(@as(u8, 0), inactive.onEntityHurt(0));
    try std.testing.expectEqual(@as(u8, 0), inactive.onEntityHurt(10));

    const negative = TrialPotionEffects{ .infested = -5.0 };
    try std.testing.expectEqual(@as(u8, 0), negative.onEntityHurt(0));
}

test "Oozing onEntityDeath spawns 2 medium slimes in 5x5x5 volume" {
    const effects = TrialPotionEffects{ .oozing = 180.0 };
    const res = effects.onEntityDeath();
    try std.testing.expect(res.hasSlimes());
    try std.testing.expectEqual(@as(u8, 2), res.slimes);
    try std.testing.expectEqual(@as(u8, 2), res.slimes_to_spawn);
    try std.testing.expectEqual(SlimeSize.medium, res.slime_size);
    try std.testing.expectEqual(@as(u8, 5), res.slime_volume_extent);
    try std.testing.expectEqual(@as(u8, 0), res.cobwebs);
    try std.testing.expect(!res.wind_burst);
}

test "Oozing clear volume check bounds 5x5x5 volume centered on entity" {
    // Within 5x5x5 centered: dx, dy, dz in -2..+2
    try std.testing.expect(isWithinSlimeVolume(0, 0, 0));
    try std.testing.expect(isWithinSlimeVolume(2, 2, 2));
    try std.testing.expect(isWithinSlimeVolume(-2, -2, -2));
    try std.testing.expect(isWithinSlimeVolume(1, 0, -1));
    // Outside 5x5x5
    try std.testing.expect(!isWithinSlimeVolume(3, 0, 0));
    try std.testing.expect(!isWithinSlimeVolume(0, -3, 0));
    try std.testing.expect(!isWithinSlimeVolume(0, 0, 3));
}

test "Oozing onEntityDeath inactive yields no slimes" {
    const inactive = TrialPotionEffects{ .oozing = 0.0 };
    const res = inactive.onEntityDeath();
    try std.testing.expect(!res.hasSlimes());
    try std.testing.expectEqual(@as(u8, 0), res.slimes);
}

test "Weaving cobwebSpeedMultiplier doubles traversal speed" {
    // Without weaving: 0.25x normal speed
    try std.testing.expectEqual(@as(f32, 0.25), cobwebSpeedMultiplier(false));
    // With weaving: 0.50x normal speed (doubled)
    try std.testing.expectEqual(@as(f32, 0.50), cobwebSpeedMultiplier(true));
    try std.testing.expectEqual(@as(f32, 2.0), cobwebSpeedMultiplier(true) / cobwebSpeedMultiplier(false));

    // Via TrialPotionEffects method
    const active = TrialPotionEffects{ .weaving = 100.0 };
    try std.testing.expectEqual(@as(f32, 0.50), active.cobwebSpeedMultiplier());
    const inactive = TrialPotionEffects{ .weaving = 0.0 };
    try std.testing.expectEqual(@as(f32, 0.25), inactive.cobwebSpeedMultiplier());
}

test "Weaving onEntityDeath spawns 2-3 cobweb blocks" {
    const effects = TrialPotionEffects{ .weaving = 180.0 };
    const res_default = effects.onEntityDeath();
    try std.testing.expect(res_default.hasCobwebs());
    try std.testing.expect(res_default.cobwebs >= 2 and res_default.cobwebs <= 3);

    // Explicit rolls produce 2 or 3 webs
    const res_roll0 = effects.onEntityDeathWithRoll(0);
    try std.testing.expectEqual(@as(u8, 2), res_roll0.cobwebs);
    try std.testing.expectEqual(@as(u8, 2), res_roll0.cobwebs_to_spawn);

    const res_roll1 = effects.onEntityDeathWithRoll(1);
    try std.testing.expectEqual(@as(u8, 3), res_roll1.cobwebs);
    try std.testing.expectEqual(@as(u8, 3), res_roll1.cobwebs_to_spawn);
}

test "Weaving onEntityDeath inactive yields zero cobwebs" {
    const inactive = TrialPotionEffects{ .weaving = 0.0 };
    const res = inactive.onEntityDeath();
    try std.testing.expect(!res.hasCobwebs());
    try std.testing.expectEqual(@as(u8, 0), res.cobwebs);
}

test "Wind Charged onEntityDeath emits upward wind burst impulse" {
    const effects = TrialPotionEffects{ .wind_charged = 180.0 };
    const res = effects.onEntityDeath();
    try std.testing.expect(res.hasWindBurst());
    try std.testing.expect(res.wind_burst);
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), res.wind_burst_vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), res.wind_burst_radius, 0.001);
    try std.testing.expectEqual(@as(u8, 0), res.slimes);
    try std.testing.expectEqual(@as(u8, 0), res.cobwebs);
}

test "Wind Charged knockback impulse calculations" {
    const impulse = calculateDeathBurstKnockback(0.0, 0.0, 3.0, 4.0);
    // (3/5)*6.0 = 3.6, (4/5)*6.0 = 4.8, vy = 6.5
    try std.testing.expectApproxEqAbs(@as(f32, 3.6), impulse.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), impulse.vy, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.8), impulse.vz, 0.001);
}

test "Wind Charged burst radius check" {
    // Center and within 3.5m radius
    try std.testing.expect(isWithinBurstRadius(0, 0, 0, 0, 0, 0));
    try std.testing.expect(isWithinBurstRadius(0, 0, 0, 2.0, 1.0, 1.0));
    try std.testing.expect(isWithinBurstRadius(0, 0, 0, 3.5, 0, 0));
    // Outside 3.5m radius
    try std.testing.expect(!isWithinBurstRadius(0, 0, 0, 3.51, 0, 0));
    try std.testing.expect(!isWithinBurstRadius(0, 0, 0, 3.0, 3.0, 0));
}

test "Wind Charged onEntityDeath inactive emits no burst" {
    const inactive = TrialPotionEffects{ .wind_charged = 0.0 };
    const res = inactive.onEntityDeath();
    try std.testing.expect(!res.hasWindBurst());
    try std.testing.expect(!res.wind_burst);
    try std.testing.expectEqual(@as(f32, 0.0), res.wind_burst_vy);
}

test "DeathTriggerResult combines multiple active death effects simultaneously" {
    var effects = TrialPotionEffects{
        .oozing = 180.0,
        .weaving = 180.0,
        .wind_charged = 180.0,
    };
    const res = effects.onEntityDeathWithRoll(1);
    try std.testing.expect(res.hasSlimes());
    try std.testing.expect(res.hasCobwebs());
    try std.testing.expect(res.hasWindBurst());
    try std.testing.expectEqual(@as(u8, 2), res.slimes);
    try std.testing.expectEqual(@as(u8, 3), res.cobwebs);
    try std.testing.expect(res.wind_burst);
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), res.wind_burst_vy, 0.001);
}

test "DeathTriggerResult empty when no effects are active" {
    const effects = TrialPotionEffects.init();
    const res = effects.onEntityDeath();
    try std.testing.expect(!res.hasSlimes());
    try std.testing.expect(!res.hasCobwebs());
    try std.testing.expect(!res.hasWindBurst());
    try std.testing.expectEqual(@as(u8, 0), res.slimes);
    try std.testing.expectEqual(@as(u8, 0), res.cobwebs);
    try std.testing.expect(!res.wind_burst);
}

test "TrialPotionEffects apply and clear helpers" {
    var effects = TrialPotionEffects.init();
    effects.apply(.infested);
    effects.apply(.oozing);
    try std.testing.expect(effects.hasInfested());
    try std.testing.expect(effects.hasOozing());
    try std.testing.expect(!effects.hasWeaving());
    try std.testing.expect(!effects.hasWindCharged());

    effects.clear();
    try std.testing.expect(!effects.hasInfested());
    try std.testing.expect(!effects.hasOozing());
    try std.testing.expectEqual(@as(f32, 0.0), effects.infested);
    try std.testing.expectEqual(@as(f32, 0.0), effects.oozing);
}

test "top-level function wrappers delegate to TrialPotionEffects methods" {
    var effects = TrialPotionEffects{
        .infested = 100.0,
        .oozing = 50.0,
        .weaving = 25.0,
        .wind_charged = 10.0,
    };
    tickEffects(&effects, 5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 95.0), effects.infested, 0.001);
    try std.testing.expectEqual(@as(u8, 1), onEntityHurt(effects, 0));
    const death_res = onEntityDeath(effects);
    try std.testing.expect(death_res.hasSlimes());
    try std.testing.expect(death_res.hasCobwebs());
    try std.testing.expect(death_res.hasWindBurst());
}
