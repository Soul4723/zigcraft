const std = @import("std");

pub const inner_no_spawn_radius_m: f32 = 24.0;
pub const active_no_despawn_radius_m: f32 = 32.0;
pub const instant_despawn_radius_m: f32 = 128.0;
pub const no_damage_grace_ticks: u16 = 600;
pub const random_despawn_denominator: u16 = 800;
pub const base_hostile_mob_cap: u8 = 70;
pub const passive_mob_cap: u8 = 10;
pub const ambient_mob_cap: u8 = 15;
pub const water_creature_mob_cap: u8 = 5;
pub const water_ambient_mob_cap: u8 = 20;
pub const axolotl_mob_cap: u8 = 5;

pub const MobDistanceZone = enum {
    inner_no_spawn,
    active_no_despawn,
    random_despawn,
    instant_despawn,
};

/// Classifies a hostile mob by its distance from the nearest player.
pub fn zoneForDistance(dist_m: f32) MobDistanceZone {
    if (dist_m < inner_no_spawn_radius_m) return .inner_no_spawn;
    if (dist_m < active_no_despawn_radius_m) return .active_no_despawn;
    if (dist_m <= instant_despawn_radius_m) return .random_despawn;
    return .instant_despawn;
}

/// Natural hostile spawning is forbidden inside the 24-block safe sphere.
pub fn canNaturalHostileSpawnAtDistance(dist_m: f32) bool {
    return dist_m >= inner_no_spawn_radius_m;
}

/// Returns true when a non-persistent mob is removed on the next game tick.
pub fn shouldInstantDespawn(dist_m: f32, is_persistent: bool) bool {
    return !is_persistent and dist_m > instant_despawn_radius_m;
}

/// Returns whether the 1-in-800 random roll succeeds in the outer sphere.
/// `roll_0_to_1` must be a uniformly distributed value in [0, 1).
pub fn shouldRandomlyDespawn(dist_m: f32, ticks_since_damage: u16, roll_0_to_1: f32) bool {
    return zoneForDistance(dist_m) == .random_despawn and
        ticks_since_damage >= no_damage_grace_ticks and
        roll_0_to_1 >= 0.0 and roll_0_to_1 < (1.0 / @as(f32, @floatFromInt(random_despawn_denominator)));
}

/// Mobs in the random-despawn sphere stop active wandering after the grace period.
pub fn shouldStopWandering(dist_m: f32, ticks_since_damage: u16) bool {
    return zoneForDistance(dist_m) == .random_despawn and ticks_since_damage >= no_damage_grace_ticks;
}

pub const MobCapFormula = struct {
    pub fn computeScaledHostileCap(loaded_spawning_chunks: u16) u16 {
        const scaled: u32 = @as(u32, base_hostile_mob_cap) * @as(u32, loaded_spawning_chunks) / 289;
        return @intCast(@min(scaled, @as(u32, std.math.maxInt(u16))));
    }
};

/// Scales the single-player hostile cap (70) by loaded spawning chunks.
pub fn computeScaledHostileCap(loaded_spawning_chunks: u16) u16 {
    return MobCapFormula.computeScaledHostileCap(loaded_spawning_chunks);
}

pub const StructureGuard = enum {
    elder_guardian,
    evoker,
    vindicator,
    piglin_brute,
    shulker,
    warden,
};

pub fn isStructureGuardPersistent(guard: StructureGuard) bool {
    return switch (guard) {
        .elder_guardian, .evoker, .vindicator, .piglin_brute, .shulker => true,
        .warden => false,
    };
}

pub const PersistenceImmunity = struct {
    named_with_nametag: bool = false,
    picked_up_equipment: bool = false,
    in_boat_or_minecart: bool = false,
    generated_as_structure_guard: bool = false,

    pub fn persistenceRequired(self: PersistenceImmunity) bool {
        return self.named_with_nametag or self.picked_up_equipment or
            self.in_boat_or_minecart or self.generated_as_structure_guard;
    }
};

/// Nametagged or equipment-picking mobs are excluded from the hostile cap.
pub fn countsTowardHostileMobCap(is_persistent_from_nametag_or_pickup: bool) bool {
    return !is_persistent_from_nametag_or_pickup;
}

// Distance zones and their exact boundary behavior.
test "distance zones use safe, active, random, and instant spheres" {
    try std.testing.expectEqual(MobDistanceZone.inner_no_spawn, zoneForDistance(0.0));
    try std.testing.expectEqual(MobDistanceZone.inner_no_spawn, zoneForDistance(23.99));
    try std.testing.expectEqual(MobDistanceZone.active_no_despawn, zoneForDistance(24.0));
    try std.testing.expectEqual(MobDistanceZone.active_no_despawn, zoneForDistance(31.99));
    try std.testing.expectEqual(MobDistanceZone.random_despawn, zoneForDistance(32.0));
    try std.testing.expectEqual(MobDistanceZone.random_despawn, zoneForDistance(128.0));
    try std.testing.expectEqual(MobDistanceZone.instant_despawn, zoneForDistance(128.01));
}

test "natural hostile spawning is blocked inside 24 meters" {
    try std.testing.expect(!canNaturalHostileSpawnAtDistance(23.999));
    try std.testing.expect(canNaturalHostileSpawnAtDistance(24.0));
}

test "negative distance is safely inside the no-spawn sphere" {
    try std.testing.expectEqual(MobDistanceZone.inner_no_spawn, zoneForDistance(-10.0));
    try std.testing.expect(!canNaturalHostileSpawnAtDistance(-10.0));
}

test "active sphere never randomly despawns" {
    try std.testing.expect(!shouldRandomlyDespawn(24.0, no_damage_grace_ticks, 0.0));
    try std.testing.expect(!shouldRandomlyDespawn(31.99, 10_000, 0.0));
}

test "random despawn requires the six hundred tick grace period" {
    try std.testing.expect(!shouldStopWandering(64.0, no_damage_grace_ticks - 1));
    try std.testing.expect(shouldStopWandering(64.0, no_damage_grace_ticks));
    try std.testing.expect(!shouldRandomlyDespawn(64.0, no_damage_grace_ticks - 1, 0.0));
    try std.testing.expect(shouldRandomlyDespawn(64.0, no_damage_grace_ticks, 0.0));
}

test "random despawn is exactly one in eight hundred" {
    const chance = 1.0 / @as(f32, @floatFromInt(random_despawn_denominator));
    try std.testing.expect(shouldRandomlyDespawn(64.0, 600, chance * 0.5));
    try std.testing.expect(!shouldRandomlyDespawn(64.0, 600, chance));
    try std.testing.expect(!shouldRandomlyDespawn(64.0, 600, -0.01));
}

test "instant despawn is next tick only beyond 128 meters" {
    try std.testing.expect(shouldInstantDespawn(128.01, false));
    try std.testing.expect(!shouldInstantDespawn(128.0, false));
    try std.testing.expect(!shouldInstantDespawn(200.0, true));
}

test "hostile cap is seventy at the 289 chunk reference window" {
    try std.testing.expectEqual(@as(u16, 0), MobCapFormula.computeScaledHostileCap(0));
    try std.testing.expectEqual(@as(u16, 70), MobCapFormula.computeScaledHostileCap(289));
}

test "hostile cap scales with loaded spawning chunks" {
    try std.testing.expectEqual(@as(u16, 35), MobCapFormula.computeScaledHostileCap(145));
    try std.testing.expectEqual(@as(u16, 140), MobCapFormula.computeScaledHostileCap(578));
}

test "mob cap constants cover every category" {
    try std.testing.expectEqual(@as(u8, 70), base_hostile_mob_cap);
    try std.testing.expectEqual(@as(u8, 10), passive_mob_cap);
    try std.testing.expectEqual(@as(u8, 15), ambient_mob_cap);
    try std.testing.expectEqual(@as(u8, 5), water_creature_mob_cap);
    try std.testing.expectEqual(@as(u8, 20), water_ambient_mob_cap);
    try std.testing.expectEqual(@as(u8, 5), axolotl_mob_cap);
}

test "nametag grants persistence immunity" {
    const immunity = PersistenceImmunity{ .named_with_nametag = true };
    try std.testing.expect(immunity.persistenceRequired());
    try std.testing.expect(!countsTowardHostileMobCap(true));
}

test "picked up equipment grants persistence immunity" {
    const immunity = PersistenceImmunity{ .picked_up_equipment = true };
    try std.testing.expect(immunity.persistenceRequired());
    try std.testing.expect(!countsTowardHostileMobCap(true));
}

test "vehicles grant persistence immunity" {
    const immunity = PersistenceImmunity{ .in_boat_or_minecart = true };
    try std.testing.expect(immunity.persistenceRequired());
    try std.testing.expect(!shouldInstantDespawn(1000.0, immunity.persistenceRequired()));
}

test "structure guards grant persistence except the warden" {
    try std.testing.expect(isStructureGuardPersistent(.elder_guardian));
    try std.testing.expect(isStructureGuardPersistent(.evoker));
    try std.testing.expect(isStructureGuardPersistent(.vindicator));
    try std.testing.expect(isStructureGuardPersistent(.piglin_brute));
    try std.testing.expect(isStructureGuardPersistent(.shulker));
    try std.testing.expect(!isStructureGuardPersistent(.warden));
}

test "combined persistence flags are an OR of all causes" {
    const immunity = PersistenceImmunity{
        .named_with_nametag = false,
        .picked_up_equipment = false,
        .in_boat_or_minecart = false,
        .generated_as_structure_guard = true,
    };
    try std.testing.expect(immunity.persistenceRequired());
}

test "ordinary hostile mobs count toward the cap" {
    try std.testing.expect(countsTowardHostileMobCap(false));
}
