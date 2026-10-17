const std = @import("std");

/// The shapeless End Crystal recipe: 7 glass, 1 Eye of Ender, and 1 Ghast Tear.
pub const EndCrystalRecipe = struct {
    pub const required_glass: u8 = 7;
    pub const required_eyes_of_ender: u8 = 1;
    pub const required_ghast_tears: u8 = 1;
    pub const output_per_batch: u8 = 1;

    /// Returns the number of complete End Crystal batches in the supplied stock.
    pub fn craftEndCrystal(glass: u8, eyes: u8, tears: u8) u8 {
        const batches = @min(glass / required_glass, @min(eyes / required_eyes_of_ender, tears / required_ghast_tears));
        return batches * output_per_batch;
    }

    pub fn canCraft(glass: u8, eyes: u8, tears: u8) bool {
        return glass >= required_glass and eyes >= required_eyes_of_ender and tears >= required_ghast_tears;
    }
};

/// Free-function form for callers that do not need the recipe namespace.
pub fn craftEndCrystal(glass: u8, eyes: u8, tears: u8) u8 {
    return EndCrystalRecipe.craftEndCrystal(glass, eyes, tears);
}

/// Placement rules for a newly placed End Crystal. The crystal occupies the
/// air column above its substrate, so both blocks above the substrate must be clear.
pub const EndCrystalPlacement = struct {
    pub fn canPlaceEndCrystalOn(
        substrate_is_obsidian_or_bedrock: bool,
        two_blocks_above_are_air: bool,
        no_overlapping_entities: bool,
    ) bool {
        return substrate_is_obsidian_or_bedrock and two_blocks_above_are_air and no_overlapping_entities;
    }
};

pub fn canPlaceEndCrystalOn(
    substrate_is_obsidian_or_bedrock: bool,
    two_blocks_above_are_air: bool,
    no_overlapping_entities: bool,
) bool {
    return EndCrystalPlacement.canPlaceEndCrystalOn(
        substrate_is_obsidian_or_bedrock,
        two_blocks_above_are_air,
        no_overlapping_entities,
    );
}

/// End Crystal blast constants. The six-block radius is the deterministic
/// gameplay envelope used by `computeEndCrystalBlastDamage`.
pub const EndCrystalExplosion = struct {
    pub const explosion_power: f32 = 6.0;
    pub const tnt_explosion_power: f32 = 4.0;
    pub const bed_explosion_power: f32 = 5.0;
    pub const blast_radius: f32 = 6.0;
    pub const point_blank_damage: f32 = 85.0;
    /// A block under the player's feet shields most of the lower hitbox.
    pub const feet_shield_damage_multiplier: f32 = 0.15;

    /// Any positive damage source destroys a crystal immediately; there is no fuse.
    pub fn detonatesFromDamage(damage: f32) bool {
        return damage > 0.0;
    }

    /// Computes direct blast damage, linearly attenuated through the six-block radius.
    /// A solid block under the target's feet reduces the exposed lower hitbox damage.
    pub fn computeBlastDamage(distance_m: f32, target_feet_shielded_by_block: bool) f32 {
        const distance = @max(0.0, distance_m);
        if (distance >= blast_radius) return 0.0;
        const attenuation = 1.0 - distance / blast_radius;
        const shield_multiplier = if (target_feet_shielded_by_block) feet_shield_damage_multiplier else 1.0;
        return point_blank_damage * attenuation * shield_multiplier;
    }
};

pub fn endCrystalDetonatesFromDamage(damage: f32) bool {
    return EndCrystalExplosion.detonatesFromDamage(damage);
}

pub fn computeEndCrystalBlastDamage(distance_m: f32, target_feet_shielded_by_block: bool) f32 {
    return EndCrystalExplosion.computeBlastDamage(distance_m, target_feet_shielded_by_block);
}

/// End Crystals are entities, not blocks: pistons can relocate them in any axis.
/// Relocation itself is safe and does not count as crystal damage.
pub const EndCrystalPistonRelocation = struct {
    pub fn canPistonPushEndCrystalSafely() bool {
        return true;
    }
};

pub fn canPistonPushEndCrystalSafely() bool {
    return EndCrystalPistonRelocation.canPistonPushEndCrystalSafely();
}

test "exact End Crystal recipe crafts one output" {
    try std.testing.expectEqual(@as(u8, 1), craftEndCrystal(7, 1, 1));
}

test "extra ingredients craft multiple End Crystals by the limiting item" {
    try std.testing.expectEqual(@as(u8, 2), craftEndCrystal(15, 2, 4));
    try std.testing.expectEqual(@as(u8, 3), EndCrystalRecipe.craftEndCrystal(21, 5, 3));
}

test "insufficient glass cannot craft an End Crystal" {
    try std.testing.expectEqual(@as(u8, 0), craftEndCrystal(6, 1, 1));
    try std.testing.expect(!EndCrystalRecipe.canCraft(6, 1, 1));
}

test "insufficient Eye of Ender or Ghast Tear cannot craft" {
    try std.testing.expectEqual(@as(u8, 0), craftEndCrystal(7, 0, 1));
    try std.testing.expectEqual(@as(u8, 0), craftEndCrystal(7, 1, 0));
}

test "End Crystal placement accepts obsidian with clear air and no overlap" {
    try std.testing.expect(canPlaceEndCrystalOn(true, true, true));
    try std.testing.expect(EndCrystalPlacement.canPlaceEndCrystalOn(true, true, true));
}

test "End Crystal placement rejects non obsidian or bedrock substrate" {
    try std.testing.expect(!canPlaceEndCrystalOn(false, true, true));
}

test "End Crystal placement rejects blocked upper space" {
    try std.testing.expect(!canPlaceEndCrystalOn(true, false, true));
}

test "End Crystal placement rejects overlapping entities" {
    try std.testing.expect(!canPlaceEndCrystalOn(true, true, false));
}

test "End Crystal takes any positive damage and detonates immediately" {
    try std.testing.expect(endCrystalDetonatesFromDamage(0.01));
    try std.testing.expect(EndCrystalExplosion.detonatesFromDamage(1.0));
}

test "zero or negative damage does not detonate an End Crystal" {
    try std.testing.expect(!endCrystalDetonatesFromDamage(0.0));
    try std.testing.expect(!endCrystalDetonatesFromDamage(-4.0));
}

test "End Crystal explosion uses power six and exceeds TNT and bed power" {
    try std.testing.expectEqual(@as(f32, 6.0), EndCrystalExplosion.explosion_power);
    try std.testing.expect(EndCrystalExplosion.explosion_power > EndCrystalExplosion.tnt_explosion_power);
    try std.testing.expect(EndCrystalExplosion.explosion_power > EndCrystalExplosion.bed_explosion_power);
}

test "point blank End Crystal blast reaches 85 HP" {
    try std.testing.expectEqual(@as(f32, 85.0), computeEndCrystalBlastDamage(0.0, false));
    try std.testing.expectEqual(@as(f32, 85.0), computeEndCrystalBlastDamage(-2.0, false));
}

test "blast damage attenuates linearly to zero at six blocks" {
    try std.testing.expectEqual(@as(f32, 42.5), computeEndCrystalBlastDamage(3.0, false));
    try std.testing.expectEqual(@as(f32, 0.0), computeEndCrystalBlastDamage(6.0, false));
    try std.testing.expectEqual(@as(f32, 0.0), computeEndCrystalBlastDamage(9.0, false));
}

test "feet shield dramatically reduces point blank self damage" {
    const unshielded = computeEndCrystalBlastDamage(0.0, false);
    const shielded = computeEndCrystalBlastDamage(0.0, true);
    try std.testing.expectApproxEqAbs(@as(f32, 12.75), shielded, 0.0001);
    try std.testing.expect(shielded < unshielded * 0.2);
}

test "feet shield applies after distance attenuation" {
    try std.testing.expectApproxEqAbs(@as(f32, 6.375), computeEndCrystalBlastDamage(3.0, true), 0.0001);
}

test "piston relocation is safe despite immovable placement substrates" {
    try std.testing.expect(canPistonPushEndCrystalSafely());
    try std.testing.expect(EndCrystalPistonRelocation.canPistonPushEndCrystalSafely());
}
