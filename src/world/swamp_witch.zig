const std = @import("std");

/// Duration of a witch's drinking animation/action.
pub const witch_drink_duration: f32 = 1.6;
/// Witches move at half speed while drinking a potion.
pub const witch_drinking_speed_multiplier: f32 = 0.5;
/// Chance to drop the currently consumed potion: 85 successful rolls in 1000.
pub const witch_drinking_potion_drop_chance_percent: f32 = 8.5;
/// Magic damage is reduced to 15% of its incoming amount.
pub const witch_magic_damage_multiplier: f32 = 0.15;
pub const witch_magic_resistance_percent: f32 = 85.0;
pub const witch_harming_damage: f32 = 6.0;
pub const swamp_hut_generates_cauldron: bool = true;

pub const WitchDrinkPotion = enum {
    none,
    water_breathing,
    fire_resistance,
    swiftness,
    healing,
};

/// Chooses a defensive/utility drink. Environmental danger takes priority,
/// then healing, then speed when the target is too far away.
pub fn selectWitchSelfPotion(
    underwater: bool,
    on_fire_or_in_lava: bool,
    dist_to_target: f32,
    health: f32,
    max_health: f32,
) WitchDrinkPotion {
    if (underwater) return .water_breathing;
    if (on_fire_or_in_lava) return .fire_resistance;
    if (health < max_health) return .healing;
    if (dist_to_target > 11.0) return .swiftness;
    return .none;
}

pub const WitchSplashAttack = enum {
    slowness,
    poison,
    weakness,
    harming,
};

/// Chooses the first applicable ranged/debuff attack in witch priority order.
pub fn selectWitchSplashThrow(
    dist_to_target: f32,
    target_health: f32,
    target_already_poisoned: bool,
    target_already_slowed: bool,
) WitchSplashAttack {
    if (dist_to_target >= 8.0 and !target_already_slowed) return .slowness;
    if (target_health >= 8.0 and !target_already_poisoned) return .poison;
    if (dist_to_target <= 3.0) return .weakness;
    return .harming;
}

/// Applies the witch's innate 85% mitigation to magic damage.
pub fn applyWitchMagicResistance(incoming_magic_damage: f32) f32 {
    return incoming_magic_damage * witch_magic_damage_multiplier;
}

/// A uniform roll in [0, 1000) succeeds on 85 values, exactly 8.5%.
pub fn dropsPotionWhileDrinking(roll: u16) bool {
    return roll < 85;
}

/// Returns the exact potion the witch was consuming when its drop roll succeeds.
pub fn potionDropWhileDrinking(drinking_potion: WitchDrinkPotion, roll: u16) ?WitchDrinkPotion {
    if (drinking_potion == .none or !dropsPotionWhileDrinking(roll)) return null;
    return drinking_potion;
}

pub const CatVariant = enum {
    tabby,
    black,
    red,
    siamese,
    british_shorthair,
    calico,
    persian,
    ragdoll,
    white,
    jellie,
    all_black,
};

/// Swamp hut cats are always the all-black variant, independent of moon phase.
pub fn swampHutCatVariant(is_full_moon: bool) CatVariant {
    _ = is_full_moon;
    return .all_black;
}

test "self potion prioritizes underwater breathing" {
    try std.testing.expectEqual(WitchDrinkPotion.water_breathing, selectWitchSelfPotion(true, false, 20, 5, 26));
}

test "self potion prioritizes underwater over fire" {
    try std.testing.expectEqual(WitchDrinkPotion.water_breathing, selectWitchSelfPotion(true, true, 20, 5, 26));
}

test "self potion selects fire resistance while burning" {
    try std.testing.expectEqual(WitchDrinkPotion.fire_resistance, selectWitchSelfPotion(false, true, 5, 26, 26));
}

test "self potion selects fire resistance in lava even when injured" {
    try std.testing.expectEqual(WitchDrinkPotion.fire_resistance, selectWitchSelfPotion(false, true, 5, 10, 26));
}

test "self potion heals any missing health" {
    try std.testing.expectEqual(WitchDrinkPotion.healing, selectWitchSelfPotion(false, false, 5, 25.99, 26));
}

test "self potion selects swiftness beyond eleven blocks" {
    try std.testing.expectEqual(WitchDrinkPotion.swiftness, selectWitchSelfPotion(false, false, 11.01, 26, 26));
}

test "self potion has no action at eleven blocks when healthy" {
    try std.testing.expectEqual(WitchDrinkPotion.none, selectWitchSelfPotion(false, false, 11, 26, 26));
}

test "self potion healing takes priority over distant target" {
    try std.testing.expectEqual(WitchDrinkPotion.healing, selectWitchSelfPotion(false, false, 20, 25, 26));
}

test "splash attack uses slowness at eight blocks when target is not slowed" {
    try std.testing.expectEqual(WitchSplashAttack.slowness, selectWitchSplashThrow(8, 20, false, false));
}

test "splash attack skips slowness when target is already slowed" {
    try std.testing.expectEqual(WitchSplashAttack.poison, selectWitchSplashThrow(8, 8, false, true));
}

test "splash attack poisons targets at eight health or more" {
    try std.testing.expectEqual(WitchSplashAttack.poison, selectWitchSplashThrow(5, 8, false, true));
}

test "splash attack skips poison when already poisoned" {
    try std.testing.expectEqual(WitchSplashAttack.weakness, selectWitchSplashThrow(3, 20, true, true));
}

test "splash attack uses weakness at close range" {
    try std.testing.expectEqual(WitchSplashAttack.weakness, selectWitchSplashThrow(2, 7.99, true, true));
}

test "splash attack uses harming as fallback" {
    try std.testing.expectEqual(WitchSplashAttack.harming, selectWitchSplashThrow(7, 7, true, true));
    try std.testing.expectEqual(@as(f32, 6.0), witch_harming_damage);
}

test "splash priority applies slowness before poison" {
    try std.testing.expectEqual(WitchSplashAttack.slowness, selectWitchSplashThrow(10, 20, false, false));
}

test "magic resistance reduces damage by eighty-five percent" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), applyWitchMagicResistance(10), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), applyWitchMagicResistance(0), 0.0001);
    try std.testing.expectEqual(@as(f32, 85.0), witch_magic_resistance_percent);
}

test "potion drop roll covers exactly 8.5 percent of a thousand outcomes" {
    try std.testing.expect(dropsPotionWhileDrinking(0));
    try std.testing.expect(dropsPotionWhileDrinking(84));
    try std.testing.expect(!dropsPotionWhileDrinking(85));
    try std.testing.expect(!dropsPotionWhileDrinking(999));
    try std.testing.expectEqual(@as(f32, 1.6), witch_drink_duration);
    try std.testing.expect(witch_drinking_speed_multiplier < 1.0);
}

test "witch drops the exact potion being consumed" {
    try std.testing.expectEqual(WitchDrinkPotion.fire_resistance, potionDropWhileDrinking(.fire_resistance, 84).?);
    try std.testing.expect(potionDropWhileDrinking(.healing, 85) == null);
    try std.testing.expect(potionDropWhileDrinking(.none, 0) == null);
}

test "swamp hut cat is all black regardless of moon phase" {
    try std.testing.expectEqual(CatVariant.all_black, swampHutCatVariant(true));
    try std.testing.expectEqual(CatVariant.all_black, swampHutCatVariant(false));
}

test "swamp hut generation includes a cauldron" {
    try std.testing.expect(swamp_hut_generates_cauldron);
}
