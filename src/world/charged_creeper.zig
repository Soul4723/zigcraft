const std = @import("std");

/// Maximum fuse timer in seconds before a Creeper detonates (1.5 seconds in Minecraft).
pub const max_fuse_seconds: f32 = 1.5;

/// Equivalent duration in standard Minecraft game ticks (30 ticks at 20 ticks/sec).
pub const max_fuse_ticks: u32 = 30;

/// Tolerance epsilon for floating point tick accumulation (e.g. 30 ticks of 0.05s).
pub const fuse_epsilon: f32 = 0.0001;

/// Radius in blocks within which a lightning strike or Channeling Trident charges a Creeper (4.0 blocks).
pub const lightning_charge_radius: f32 = 4.0;
pub const lightning_charge_radius_sq: f32 = lightning_charge_radius * lightning_charge_radius;

/// Distance threshold to ignite Creeper fuse when target is in line of sight (3.0 blocks).
pub const ignite_distance: f32 = 3.0;
pub const ignite_distance_sq: f32 = ignite_distance * ignite_distance;

/// Distance threshold beyond which an ignited Creeper loses tracking and defuses (7.0 blocks).
pub const defuse_distance: f32 = 7.0;
pub const defuse_distance_sq: f32 = defuse_distance * defuse_distance;

/// Radius in blocks within which Creepers flee in terror from Cats and Ocelots (6.0 blocks).
pub const cat_flee_distance: f32 = 6.0;
pub const cat_flee_distance_sq: f32 = cat_flee_distance * cat_flee_distance;

/// Standard Creeper explosion blast radius in blocks (3.0 blocks).
pub const standard_blast_radius: f32 = 3.0;

/// Standard Creeper maximum direct damage on Hard difficulty (43.0 damage).
pub const standard_max_damage: f32 = 43.0;

/// Charged Creeper explosion blast radius in blocks (6.0 blocks, exactly 2x standard radius).
pub const charged_blast_radius: f32 = 6.0;

/// Charged Creeper maximum direct damage on Hard difficulty (85.0 damage).
pub const charged_max_damage: f32 = 85.0;

/// Default maximum health of a Creeper (20.0 HP = 10 hearts).
pub const default_creeper_health: f32 = 20.0;

/// Entity state for a Creeper mob, tracking lightning charge, fuse timer, forced ignition, and health.
pub const CreeperState = struct {
    is_charged: bool = false,
    fuse_timer: f32 = 0.0,
    ignited_by_flint_and_steel: bool = false,
    health: f32 = default_creeper_health,

    /// Computes active blast radius based on charged state (3.0 standard, 6.0 charged).
    pub fn blastRadius(self: CreeperState) f32 {
        return if (self.is_charged) charged_blast_radius else standard_blast_radius;
    }

    /// Computes maximum explosion damage based on charged state (43.0 standard, 85.0 charged).
    pub fn maxDamage(self: CreeperState) f32 {
        return if (self.is_charged) charged_max_damage else standard_max_damage;
    }

    /// Returns true if the Creeper has been killed (health <= 0.0).
    pub fn isDead(self: CreeperState) bool {
        return self.health <= 0.0;
    }

    /// Manually ignites the Creeper using Flint and Steel (forced irreversible ignition).
    pub fn igniteFlintAndSteel(self: *CreeperState) void {
        self.ignited_by_flint_and_steel = true;
    }

    /// Charges the Creeper if a lightning strike or Channeling Trident hits within 4.0 blocks.
    pub fn strikeLightning(self: *CreeperState, distance_to_strike: f32) bool {
        if (distance_to_strike <= lightning_charge_radius) {
            self.is_charged = true;
            return true;
        }
        return false;
    }

    /// Applies damage to the Creeper, clamping health to a minimum of 0.0.
    pub fn applyDamage(self: *CreeperState, damage: f32) void {
        self.health = @max(0.0, self.health - damage);
    }

    /// Resets the Creeper fuse timer and forced ignition state.
    pub fn reset(self: *CreeperState) void {
        self.fuse_timer = 0.0;
        self.ignited_by_flint_and_steel = false;
    }

    /// Returns swell progress as a normalized ratio in 0.0..1.0.
    pub fn swellProgress(self: CreeperState) f32 {
        return @min(1.0, @max(0.0, self.fuse_timer / max_fuse_seconds));
    }
};

/// Return value from ticking a Creeper's fuse behavior.
pub const CreeperFuseResult = struct {
    exploded: bool,
    blast_radius: f32,
    max_damage: f32,
    fleeing_cat: bool,
};

/// Ticks a Creeper's swell fuse and AI response against targets and nearby cats:
/// - Ignites fuse when `dist_to_target <= 3.0` and `has_line_of_sight`.
/// - Defuses (`fuse_timer` rewinds at `-1.0x` rate) if target escapes beyond `7.0` blocks or breaks line of sight.
/// - Forced ignition via Flint and Steel (`ignited_by_flint_and_steel == true`) cannot be defused by distance, line of sight, or cats!
/// - Standard Creeper blast radius = `3.0` (`43.0` max damage); `ChargedCreeper` blast radius = `6.0` (`85.0` max damage).
/// - Creepers flee in terror when a Cat or Ocelot is within `6.0` blocks (`fleeing_cat = true`).
pub fn tickCreeperFuse(
    state: *CreeperState,
    dist_to_target: f32,
    has_line_of_sight: bool,
    cat_within_6_blocks: bool,
    dt: f32,
) CreeperFuseResult {
    // If Creeper is dead, it cannot swell or detonate
    if (state.health <= 0.0) {
        return .{
            .exploded = false,
            .blast_radius = state.blastRadius(),
            .max_damage = state.maxDamage(),
            .fleeing_cat = false,
        };
    }

    const blast_r = state.blastRadius();
    const max_dmg = state.maxDamage();
    var exploded = false;
    const fleeing_cat = cat_within_6_blocks;

    if (state.ignited_by_flint_and_steel) {
        // Forced ignition cannot be defused by escaping target, broken line of sight, or fleeing from cats!
        state.fuse_timer += dt;
        if (state.fuse_timer >= max_fuse_seconds - fuse_epsilon) {
            state.fuse_timer = max_fuse_seconds;
            state.health = 0.0;
            exploded = true;
        }
    } else if (fleeing_cat) {
        // Cat 6m flee priority: Creepers flee in terror when a Cat or Ocelot is within 6 blocks.
        // Fleeing rewinds active fuse at -1.0x rate down to 0.0.
        state.fuse_timer -= dt;
        if (state.fuse_timer < 0.0) state.fuse_timer = 0.0;
    } else {
        // Standard proximity and line-of-sight tracking
        if (has_line_of_sight) {
            if (dist_to_target <= ignite_distance) {
                // Target within 3.0 blocks with line of sight: ignite fuse
                state.fuse_timer += dt;
            } else if (state.fuse_timer > 0.0 and dist_to_target <= defuse_distance) {
                // Target has not escaped beyond 7.0 blocks with line of sight: continue swelling
                state.fuse_timer += dt;
            } else {
                // Target escaped beyond 7.0 blocks: defuse at -1.0x rate
                state.fuse_timer -= dt;
                if (state.fuse_timer < 0.0) state.fuse_timer = 0.0;
            }
        } else {
            // Line of sight broken: defuse at -1.0x rate
            state.fuse_timer -= dt;
            if (state.fuse_timer < 0.0) state.fuse_timer = 0.0;
        }

        if (state.fuse_timer >= max_fuse_seconds - fuse_epsilon) {
            state.fuse_timer = max_fuse_seconds;
            state.health = 0.0;
            exploded = true;
        }
    }

    return .{
        .exploded = exploded,
        .blast_radius = blast_r,
        .max_damage = max_dmg,
        .fleeing_cat = fleeing_cat,
    };
}

/// Standalone helper to trigger forced ignition with Flint and Steel.
pub fn igniteWithFlintAndSteel(state: *CreeperState) void {
    state.ignited_by_flint_and_steel = true;
}

/// Charges a Creeper if lightning strikes within 4.0 blocks.
pub fn chargeFromLightning(state: *CreeperState, distance_to_lightning: f32) bool {
    if (distance_to_lightning <= lightning_charge_radius) {
        state.is_charged = true;
        return true;
    }
    return false;
}

/// Charges a Creeper if a Channeling Trident strikes within 4.0 blocks.
pub fn chargeFromChannelingTrident(state: *CreeperState, distance_to_strike: f32) bool {
    return chargeFromLightning(state, distance_to_strike);
}

/// Charges a Creeper if a lightning strike at (strike_x, strike_y, strike_z) is within 4.0 blocks.
pub fn chargeFromLightningCoords(
    state: *CreeperState,
    creeper_x: f32,
    creeper_y: f32,
    creeper_z: f32,
    strike_x: f32,
    strike_y: f32,
    strike_z: f32,
) bool {
    const dx = creeper_x - strike_x;
    const dy = creeper_y - strike_y;
    const dz = creeper_z - strike_z;
    const dist_sq = dx * dx + dy * dy + dz * dz;
    if (dist_sq <= lightning_charge_radius_sq) {
        state.is_charged = true;
        return true;
    }
    return false;
}

/// Mob victim kinds eligible for mob head trophy drops when killed by a Charged Creeper explosion.
pub const MobTrophyVictim = enum {
    zombie,
    skeleton,
    wither_skeleton,
    creeper,
    piglin,
    other,

    pub fn name(self: MobTrophyVictim) []const u8 {
        return switch (self) {
            .zombie => "Zombie",
            .skeleton => "Skeleton",
            .wither_skeleton => "Wither Skeleton",
            .creeper => "Creeper",
            .piglin => "Piglin",
            .other => "Other",
        };
    }
};

/// Mob Head / Skull trophy drops resulting from Charged Creeper explosions.
pub const MobHeadDrop = enum {
    zombie_head,
    skeleton_skull,
    wither_skeleton_skull,
    creeper_head,
    piglin_head,

    pub fn displayName(self: MobHeadDrop) []const u8 {
        return switch (self) {
            .zombie_head => "Zombie Head",
            .skeleton_skull => "Skeleton Skull",
            .wither_skeleton_skull => "Wither Skeleton Skull",
            .creeper_head => "Creeper Head",
            .piglin_head => "Piglin Head",
        };
    }
};

/// Resolves mob head trophy drop when a mob is killed by a Creeper explosion:
/// - When a Charged Creeper explosion kills a Zombie, Skeleton, Wither Skeleton, Creeper, or Piglin,
///   it drops 1 matching Mob Head / Skull.
/// - Uncharged creepers NEVER drop mob heads.
/// - At most 1 head drops per Charged Creeper explosion (`already_dropped_head_this_blast == true` returns null).
pub fn resolveChargedCreeperTrophyDrop(
    creeper_is_charged: bool,
    victim_kind: MobTrophyVictim,
    already_dropped_head_this_blast: bool,
) ?MobHeadDrop {
    if (!creeper_is_charged) return null;
    if (already_dropped_head_this_blast) return null;

    return switch (victim_kind) {
        .zombie => .zombie_head,
        .skeleton => .skeleton_skull,
        .wither_skeleton => .wither_skeleton_skull,
        .creeper => .creeper_head,
        .piglin => .piglin_head,
        .other => null,
    };
}

/// Helper resolving trophy drops across a list of blast casualties, guaranteeing at most 1 head drop.
pub fn resolveBlastTrophyDrops(
    creeper_is_charged: bool,
    victims: []const MobTrophyVictim,
) ?struct { victim_index: usize, drop: MobHeadDrop } {
    if (!creeper_is_charged) return null;
    for (victims, 0..) |v, idx| {
        if (resolveChargedCreeperTrophyDrop(true, v, false)) |drop| {
            return .{ .victim_index = idx, .drop = drop };
        }
    }
    return null;
}

/// The 12 classic Minecraft Music Discs dropped when a Skeleton's arrow kills a Creeper.
pub const ClassicMusicDisc = enum(u8) {
    disc_13 = 1,
    cat = 2,
    blocks = 3,
    chirp = 4,
    far = 5,
    mall = 6,
    mellohi = 7,
    stal = 8,
    strad = 9,
    ward = 10,
    disc_11 = 11,
    wait = 12,

    pub fn title(self: ClassicMusicDisc) []const u8 {
        return switch (self) {
            .disc_13 => "13",
            .cat => "cat",
            .blocks => "blocks",
            .chirp => "chirp",
            .far => "far",
            .mall => "mall",
            .mellohi => "mellohi",
            .stal => "stal",
            .strad => "strad",
            .ward => "ward",
            .disc_11 => "11",
            .wait => "wait",
        };
    }
};

/// Resolves Music Disc drop when a Creeper dies:
/// - If killed by a Skeleton arrow (`killed_by_skeleton_arrow == true`), drops one of the 12 classic Music Discs (1..12).
/// - Non-skeleton arrow deaths return null.
pub fn resolveSkeletonKilledCreeperDisc(killed_by_skeleton_arrow: bool, roll: u8) ?u8 {
    if (!killed_by_skeleton_arrow) return null;
    return (roll % 12) + 1;
}

/// Returns the title of a classic music disc ID (1..12) or null if out of range.
pub fn classicDiscTitle(disc_id: u8) ?[]const u8 {
    if (disc_id < 1 or disc_id > 12) return null;
    const disc: ClassicMusicDisc = @enumFromInt(disc_id);
    return disc.title();
}

// ============================================================================
// UNIT TESTS (at least 14 required, 28 implemented)
// ============================================================================

test "1. CreeperState default initialization values" {
    const creeper = CreeperState{};
    try std.testing.expect(!creeper.is_charged);
    try std.testing.expectEqual(@as(f32, 0.0), creeper.fuse_timer);
    try std.testing.expect(!creeper.ignited_by_flint_and_steel);
    try std.testing.expectEqual(default_creeper_health, creeper.health);
    try std.testing.expectEqual(@as(f32, 3.0), creeper.blastRadius());
    try std.testing.expectEqual(@as(f32, 43.0), creeper.maxDamage());
    try std.testing.expect(!creeper.isDead());
}

test "2. Fuse ignition when target within 3.0 blocks with line of sight" {
    var creeper = CreeperState{};
    const res = tickCreeperFuse(&creeper, 2.5, true, false, 0.5);
    try std.testing.expect(!res.exploded);
    try std.testing.expectEqual(@as(f32, 0.5), creeper.fuse_timer);
    try std.testing.expect(!res.fleeing_cat);
    try std.testing.expectEqual(@as(f32, 3.0), res.blast_radius);
    try std.testing.expectEqual(@as(f32, 43.0), res.max_damage);
}

test "3. Fuse does not ignite when target within 3.0 blocks but has no line of sight" {
    var creeper = CreeperState{};
    const res = tickCreeperFuse(&creeper, 2.0, false, false, 0.5);
    try std.testing.expect(!res.exploded);
    try std.testing.expectEqual(@as(f32, 0.0), creeper.fuse_timer);
}

test "4. Fuse does not ignite when target outside 3.0 blocks initially" {
    var creeper = CreeperState{};
    const res = tickCreeperFuse(&creeper, 4.0, true, false, 0.5);
    try std.testing.expect(!res.exploded);
    try std.testing.expectEqual(@as(f32, 0.0), creeper.fuse_timer);
}

test "5. Fuse continues swelling when target is between 3.0m and 7.0m with line of sight once ignited" {
    var creeper = CreeperState{};
    // First ignite within 3.0m
    _ = tickCreeperFuse(&creeper, 2.0, true, false, 0.5);
    try std.testing.expectEqual(@as(f32, 0.5), creeper.fuse_timer);

    // Player steps back to 5.5m (within 7.0m defuse boundary) while maintaining line of sight
    const res = tickCreeperFuse(&creeper, 5.5, true, false, 0.3);
    try std.testing.expect(!res.exploded);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), creeper.fuse_timer, 0.001);
}

test "6. Fuse defuses at -1.0x rate when target escapes beyond 7.0 blocks" {
    var creeper = CreeperState{};
    // Swell up to 1.0s
    _ = tickCreeperFuse(&creeper, 2.0, true, false, 1.0);
    try std.testing.expectEqual(@as(f32, 1.0), creeper.fuse_timer);

    // Target flees to 8.5m (> 7.0m): fuse rewinds at -1.0x rate
    const res = tickCreeperFuse(&creeper, 8.5, true, false, 0.4);
    try std.testing.expect(!res.exploded);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), creeper.fuse_timer, 0.001);

    // After 1.0 more seconds beyond 7m, fuse rewinds completely to 0.0
    _ = tickCreeperFuse(&creeper, 8.5, true, false, 1.0);
    try std.testing.expectEqual(@as(f32, 0.0), creeper.fuse_timer);
}

test "7. Fuse defuses at -1.0x rate when target breaks line of sight" {
    var creeper = CreeperState{};
    // Swell up to 0.8s
    _ = tickCreeperFuse(&creeper, 2.0, true, false, 0.8);
    try std.testing.expectEqual(@as(f32, 0.8), creeper.fuse_timer);

    // Target ducks behind a wall: line of sight broken
    const res = tickCreeperFuse(&creeper, 2.0, false, false, 0.3);
    try std.testing.expect(!res.exploded);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), creeper.fuse_timer, 0.001);
}

test "8. Standard Creeper detonates at 1.5s (30 ticks) with 3.0 blast radius and 43.0 damage" {
    var creeper = CreeperState{};
    // Tick 30 times with dt = 0.05s (30 * 0.05 = 1.5s total)
    var exploded = false;
    var i: usize = 0;
    while (i < 30) : (i += 1) {
        const res = tickCreeperFuse(&creeper, 2.0, true, false, 0.05);
        if (res.exploded) {
            exploded = true;
            try std.testing.expectEqual(@as(f32, 3.0), res.blast_radius);
            try std.testing.expectEqual(@as(f32, 43.0), res.max_damage);
            break;
        }
    }
    try std.testing.expect(exploded);
    try std.testing.expectEqual(max_fuse_seconds, creeper.fuse_timer);
    try std.testing.expect(creeper.isDead());
}

test "9. Flint-and-Steel forced ignition cannot be defused when target escapes beyond 7.0 blocks" {
    var creeper = CreeperState{};
    igniteWithFlintAndSteel(&creeper);
    try std.testing.expect(creeper.ignited_by_flint_and_steel);

    // Target is 25 blocks away: forced ignition still ticks forward
    _ = tickCreeperFuse(&creeper, 25.0, true, false, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), creeper.fuse_timer, 0.001);

    // Advances to explosion despite target being far away
    const res = tickCreeperFuse(&creeper, 50.0, true, false, 1.0);
    try std.testing.expect(res.exploded);
    try std.testing.expectEqual(max_fuse_seconds, creeper.fuse_timer);
    try std.testing.expect(creeper.isDead());
}

test "10. Flint-and-Steel forced ignition cannot be defused when line of sight is broken" {
    var creeper = CreeperState{};
    creeper.igniteFlintAndSteel();

    // No line of sight: forced ignition still advances
    _ = tickCreeperFuse(&creeper, 1.0, false, false, 0.7);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), creeper.fuse_timer, 0.001);

    const res = tickCreeperFuse(&creeper, 1.0, false, false, 0.8);
    try std.testing.expect(res.exploded);
}

test "11. Flint-and-Steel forced ignition cannot be defused even when cat is within 6 blocks" {
    var creeper = CreeperState{};
    igniteWithFlintAndSteel(&creeper);

    // Cat is nearby (cat_within_6_blocks = true)
    const res1 = tickCreeperFuse(&creeper, 2.0, true, true, 0.6);
    try std.testing.expect(!res1.exploded);
    try std.testing.expect(res1.fleeing_cat);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), creeper.fuse_timer, 0.001);

    // Reaches explosion threshold despite cat
    const res2 = tickCreeperFuse(&creeper, 2.0, true, true, 0.9);
    try std.testing.expect(res2.exploded);
    try std.testing.expect(res2.fleeing_cat);
}

test "12. Cat 6m flee priority: Creeper flees (fleeing_cat = true) and defuses when cat is within 6.0m" {
    var creeper = CreeperState{};
    // Swell to 1.0s first
    _ = tickCreeperFuse(&creeper, 2.0, true, false, 1.0);
    try std.testing.expectEqual(@as(f32, 1.0), creeper.fuse_timer);

    // Cat arrives within 6 blocks: fleeing_cat = true and fuse rewinds at -1.0x rate
    const res = tickCreeperFuse(&creeper, 2.0, true, true, 0.4);
    try std.testing.expect(!res.exploded);
    try std.testing.expect(res.fleeing_cat);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), creeper.fuse_timer, 0.001);
}

test "13. Cat outside 6.0m does not trigger fleeing or prevent ignition" {
    var creeper = CreeperState{};
    const res = tickCreeperFuse(&creeper, 2.0, true, false, 0.5);
    try std.testing.expect(!res.fleeing_cat);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), creeper.fuse_timer, 0.001);
}

test "14. Lightning strike within 4.0 blocks charges Creeper" {
    var creeper = CreeperState{};
    try std.testing.expect(!creeper.is_charged);

    // Lightning strike 2.5m away (<= 4.0m)
    const charged = chargeFromLightning(&creeper, 2.5);
    try std.testing.expect(charged);
    try std.testing.expect(creeper.is_charged);
    try std.testing.expectEqual(@as(f32, 6.0), creeper.blastRadius());
    try std.testing.expectEqual(@as(f32, 85.0), creeper.maxDamage());
}

test "15. Lightning strike beyond 4.0 blocks does not charge Creeper" {
    var creeper = CreeperState{};
    const charged = chargeFromLightning(&creeper, 4.1);
    try std.testing.expect(!charged);
    try std.testing.expect(!creeper.is_charged);
}

test "16. Channeling Trident strike within 4.0 blocks charges Creeper" {
    var creeper = CreeperState{};
    const charged = chargeFromChannelingTrident(&creeper, 3.8);
    try std.testing.expect(charged);
    try std.testing.expect(creeper.is_charged);
}

test "17. 3D coordinates lightning strike charge calculation" {
    var creeper = CreeperState{};
    // Creeper at (10, 64, 10), lightning strike at (12, 64, 12): dx=2, dz=2, dist=sqrt(8)=2.83m <= 4.0m
    try std.testing.expect(chargeFromLightningCoords(&creeper, 10.0, 64.0, 10.0, 12.0, 64.0, 12.0));
    try std.testing.expect(creeper.is_charged);

    var creeper2 = CreeperState{};
    // Creeper at (0, 0, 0), lightning strike at (5, 0, 0): dist = 5.0m > 4.0m
    try std.testing.expect(!chargeFromLightningCoords(&creeper2, 0.0, 0.0, 0.0, 5.0, 0.0, 0.0));
    try std.testing.expect(!creeper2.is_charged);
}

test "18. Charged Creeper detonation has 2x blast radius (6.0) and 85.0 max damage" {
    var charged_creeper = CreeperState{ .is_charged = true };
    const res = tickCreeperFuse(&charged_creeper, 2.0, true, false, 1.5);
    try std.testing.expect(res.exploded);
    try std.testing.expectEqual(@as(f32, 6.0), res.blast_radius);
    try std.testing.expectEqual(@as(f32, 85.0), res.max_damage);
    try std.testing.expect(charged_creeper.isDead());
}

test "19. Charged Creeper explosion drops Zombie Head when killing Zombie" {
    const drop = resolveChargedCreeperTrophyDrop(true, .zombie, false);
    try std.testing.expect(drop != null);
    try std.testing.expectEqual(MobHeadDrop.zombie_head, drop.?);
    try std.testing.expectEqualStrings("Zombie Head", drop.?.displayName());
}

test "20. Charged Creeper explosion drops Skeleton Skull, Wither Skeleton Skull, Creeper Head, Piglin Head" {
    try std.testing.expectEqual(MobHeadDrop.skeleton_skull, resolveChargedCreeperTrophyDrop(true, .skeleton, false).?);
    try std.testing.expectEqual(MobHeadDrop.wither_skeleton_skull, resolveChargedCreeperTrophyDrop(true, .wither_skeleton, false).?);
    try std.testing.expectEqual(MobHeadDrop.creeper_head, resolveChargedCreeperTrophyDrop(true, .creeper, false).?);
    try std.testing.expectEqual(MobHeadDrop.piglin_head, resolveChargedCreeperTrophyDrop(true, .piglin, false).?);
}

test "21. Charged Creeper explosion drops at most 1 head per blast" {
    // First victim drops head
    const first_drop = resolveChargedCreeperTrophyDrop(true, .zombie, false);
    try std.testing.expectEqual(MobHeadDrop.zombie_head, first_drop.?);

    // Subsequent victims in same blast return null because already_dropped_head_this_blast is true
    const second_drop = resolveChargedCreeperTrophyDrop(true, .skeleton, true);
    try std.testing.expect(second_drop == null);

    const third_drop = resolveChargedCreeperTrophyDrop(true, .creeper, true);
    try std.testing.expect(third_drop == null);
}

test "22. Standard (uncharged) Creeper explosion never drops Mob Head" {
    try std.testing.expect(resolveChargedCreeperTrophyDrop(false, .zombie, false) == null);
    try std.testing.expect(resolveChargedCreeperTrophyDrop(false, .skeleton, false) == null);
    try std.testing.expect(resolveChargedCreeperTrophyDrop(false, .wither_skeleton, false) == null);
    try std.testing.expect(resolveChargedCreeperTrophyDrop(false, .creeper, false) == null);
    try std.testing.expect(resolveChargedCreeperTrophyDrop(false, .piglin, false) == null);
}

test "23. Charged Creeper explosion returns null for non-trophy mob victim (.other)" {
    try std.testing.expect(resolveChargedCreeperTrophyDrop(true, .other, false) == null);
}

test "24. resolveBlastTrophyDrops selects first eligible victim from group casualty" {
    const victims = [_]MobTrophyVictim{ .other, .skeleton, .zombie };
    const result = resolveBlastTrophyDrops(true, &victims);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 1), result.?.victim_index);
    try std.testing.expectEqual(MobHeadDrop.skeleton_skull, result.?.drop);
}

test "25. Skeleton arrow killing Creeper drops one of the 12 classic music discs (1..12)" {
    // Test various rolls
    try std.testing.expectEqual(@as(?u8, 1), resolveSkeletonKilledCreeperDisc(true, 0));
    try std.testing.expectEqual(@as(?u8, 2), resolveSkeletonKilledCreeperDisc(true, 1));
    try std.testing.expectEqual(@as(?u8, 12), resolveSkeletonKilledCreeperDisc(true, 11));
    try std.testing.expectEqual(@as(?u8, 1), resolveSkeletonKilledCreeperDisc(true, 12));
    try std.testing.expectEqual(@as(?u8, 7), resolveSkeletonKilledCreeperDisc(true, 6)); // mellohi
}

test "26. Non-skeleton kill of Creeper does not drop a music disc" {
    try std.testing.expect(resolveSkeletonKilledCreeperDisc(false, 0) == null);
    try std.testing.expect(resolveSkeletonKilledCreeperDisc(false, 5) == null);
    try std.testing.expect(resolveSkeletonKilledCreeperDisc(false, 255) == null);
}

test "27. All 12 classic discs are mapped with correct titles" {
    var disc_id: u8 = 1;
    while (disc_id <= 12) : (disc_id += 1) {
        const title = classicDiscTitle(disc_id);
        try std.testing.expect(title != null);
        try std.testing.expect(title.?.len > 0);
    }
    // Out of range discs return null
    try std.testing.expect(classicDiscTitle(0) == null);
    try std.testing.expect(classicDiscTitle(13) == null);
}

test "28. Dead creeper does not tick fuse or explode" {
    var creeper = CreeperState{ .health = 0.0 };
    const res = tickCreeperFuse(&creeper, 2.0, true, false, 2.0);
    try std.testing.expect(!res.exploded);
    try std.testing.expectEqual(@as(f32, 0.0), creeper.fuse_timer);
}
