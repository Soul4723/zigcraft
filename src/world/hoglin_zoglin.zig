const std = @import("std");

pub const hoglin_max_health: f32 = 40.0;
pub const hoglin_porkchop_min: u8 = 2;
pub const hoglin_porkchop_max: u8 = 4;
pub const hoglin_leather_min: u8 = 0;
pub const hoglin_leather_max: u8 = 1;
pub const hoglin_fungus_repulsion_radius: f32 = 7.0;
pub const hoglin_zombification_duration_seconds: f32 = 15.0;
pub const hoglin_zombification_ticks: u32 = 300;
pub const hoglin_tusk_launch_velocity: f32 = 6.5;

pub const HoglinState = struct {
    health: f32 = hoglin_max_health,
    zombify_timer_seconds: f32 = 0.0,
    is_zoglin: bool = false,

    pub fn init() HoglinState {
        return .{};
    }

    /// Pork chops are cooked when the Hoglin dies while burning. `pork_roll`
    /// and `leather_roll` provide deterministic inputs from the caller's RNG.
    pub fn deathDrops(_: HoglinState, is_burning: bool, pork_roll: u8, leather_roll: u8) HoglinDrops {
        return .{
            .porkchop_item = if (is_burning) "Cooked Porkchop" else "Raw Porkchop",
            .porkchop_count = hoglin_porkchop_min + @min(pork_roll, hoglin_porkchop_max - hoglin_porkchop_min),
            .leather_count = @min(leather_roll, hoglin_leather_max),
        };
    }
};

pub const HoglinDrops = struct {
    porkchop_item: []const u8,
    porkchop_count: u8,
    leather_count: u8,
};

/// `block_is_warped_fungus_or_portal_or_anchor` is true for a placed block,
/// including potted warped fungus; the caller supplies the nearest distance.
pub fn isHoglinRepelledByBlock(
    is_zoglin: bool,
    block_is_warped_fungus_or_portal_or_anchor: bool,
    dist_blocks: f32,
) bool {
    return !is_zoglin and block_is_warped_fungus_or_portal_or_anchor and
        dist_blocks >= 0.0 and dist_blocks <= hoglin_fungus_repulsion_radius;
}

pub const TuskFlingImpulse = struct {
    vx: f32,
    vy: f32,
    vz: f32,
    ignores_netherite_knockback_resistance_for_vy: bool,
};

/// Adult tusks launch targets upward. The vertical impulse is applied through
/// Netherite knockback resistance; babies deliver a weaker, non-launching hit.
pub fn computeTuskFlingImpulse(attacker_dir_xz: [2]f32, target_is_baby: bool) TuskFlingImpulse {
    const scale: f32 = if (target_is_baby) 0.5 else 1.0;
    return .{
        .vx = attacker_dir_xz[0] * scale,
        .vy = if (target_is_baby) 2.0 else hoglin_tusk_launch_velocity,
        .vz = attacker_dir_xz[1] * scale,
        .ignores_netherite_knockback_resistance_for_vy = !target_is_baby,
    };
}

/// Returns true on the transformation tick. The timer is frozen outside the
/// Overworld/End and clamped to the 15-second threshold.
pub fn tickHoglinOverworldZombification(in_overworld_or_end: bool, zombify_timer_seconds: *f32, dt: f32) bool {
    if (!in_overworld_or_end or dt <= 0.0) return false;
    zombify_timer_seconds.* = @min(
        hoglin_zombification_duration_seconds,
        zombify_timer_seconds.* + dt,
    );
    return zombify_timer_seconds.* >= hoglin_zombification_duration_seconds;
}

/// Zoglins attack every target except their own kind and Creepers.
pub fn shouldZoglinAttackEntity(entity_is_zoglin: bool, entity_is_creeper: bool, entity_is_ghast: bool) bool {
    _ = entity_is_ghast; // Ghasts are living mobs and are not an exception.
    return !entity_is_zoglin and !entity_is_creeper;
}

/// Hoglins breed only when fed Crimson Fungus; Zoglins cannot be bred.
pub fn canBreedHoglin(is_zoglin: bool, fed_crimson_fungus: bool) bool {
    return !is_zoglin and fed_crimson_fungus;
}

test "Hoglin has forty health and normal death drops raw pork" {
    const hoglin = HoglinState.init();
    try std.testing.expectEqual(@as(f32, 40.0), hoglin.health);
    const drops = hoglin.deathDrops(false, 0, 0);
    try std.testing.expectEqualStrings("Raw Porkchop", drops.porkchop_item);
    try std.testing.expectEqual(@as(u8, 2), drops.porkchop_count);
}

test "Hoglin pork drops span two through four" {
    const hoglin = HoglinState.init();
    try std.testing.expectEqual(@as(u8, 2), hoglin.deathDrops(false, 0, 0).porkchop_count);
    try std.testing.expectEqual(@as(u8, 3), hoglin.deathDrops(false, 1, 0).porkchop_count);
    try std.testing.expectEqual(@as(u8, 4), hoglin.deathDrops(false, 2, 0).porkchop_count);
    try std.testing.expectEqual(@as(u8, 4), hoglin.deathDrops(false, 255, 0).porkchop_count);
}

test "burning Hoglin drops cooked porkchops" {
    const drops = HoglinState.init().deathDrops(true, 2, 0);
    try std.testing.expectEqualStrings("Cooked Porkchop", drops.porkchop_item);
    try std.testing.expectEqual(@as(u8, 4), drops.porkchop_count);
}

test "Hoglin leather drop is zero or one" {
    const hoglin = HoglinState.init();
    try std.testing.expectEqual(@as(u8, 0), hoglin.deathDrops(false, 0, 0).leather_count);
    try std.testing.expectEqual(@as(u8, 1), hoglin.deathDrops(false, 0, 1).leather_count);
    try std.testing.expectEqual(@as(u8, 1), hoglin.deathDrops(false, 0, 255).leather_count);
}

test "Hoglin flees warped fungus at seven blocks including boundary" {
    try std.testing.expect(isHoglinRepelledByBlock(false, true, 0.0));
    try std.testing.expect(isHoglinRepelledByBlock(false, true, 7.0));
    try std.testing.expect(!isHoglinRepelledByBlock(false, true, 7.01));
}

test "Hoglin flees portal blocks within seven blocks" {
    try std.testing.expect(isHoglinRepelledByBlock(false, true, 6.5));
}

test "Hoglin flees respawn anchors within seven blocks" {
    try std.testing.expect(isHoglinRepelledByBlock(false, true, 1.0));
}

test "Hoglin is not repelled beyond range or by unrelated blocks" {
    try std.testing.expect(!isHoglinRepelledByBlock(false, true, 7.1));
    try std.testing.expect(!isHoglinRepelledByBlock(false, false, 1.0));
    try std.testing.expect(!isHoglinRepelledByBlock(false, true, -1.0));
}

test "Zoglins ignore warped fungus and other repellent blocks" {
    try std.testing.expect(!isHoglinRepelledByBlock(true, true, 0.0));
}

test "adult tusk fling launches upward through Netherite resistance" {
    const impulse = computeTuskFlingImpulse(.{ 1.0, 0.0 }, false);
    try std.testing.expectEqual(@as(f32, 1.0), impulse.vx);
    try std.testing.expectEqual(@as(f32, 6.5), impulse.vy);
    try std.testing.expectEqual(@as(f32, 0.0), impulse.vz);
    try std.testing.expect(impulse.ignores_netherite_knockback_resistance_for_vy);
}

test "baby targets receive a weaker tusk impulse" {
    const impulse = computeTuskFlingImpulse(.{ 0.0, 1.0 }, true);
    try std.testing.expectEqual(@as(f32, 0.5), impulse.vz);
    try std.testing.expectEqual(@as(f32, 2.0), impulse.vy);
    try std.testing.expect(!impulse.ignores_netherite_knockback_resistance_for_vy);
}

test "Overworld zombification takes exactly fifteen seconds" {
    var timer: f32 = 0.0;
    try std.testing.expect(!tickHoglinOverworldZombification(true, &timer, 14.9));
    try std.testing.expect(!tickHoglinOverworldZombification(true, &timer, 0.09));
    try std.testing.expect(tickHoglinOverworldZombification(true, &timer, 0.01));
    try std.testing.expectEqual(@as(f32, 15.0), timer);
    try std.testing.expectEqual(@as(u32, 300), hoglin_zombification_ticks);
}

test "Nether timer is frozen and nonpositive delta does not advance" {
    var timer: f32 = 3.0;
    try std.testing.expect(!tickHoglinOverworldZombification(false, &timer, 5.0));
    try std.testing.expect(!tickHoglinOverworldZombification(true, &timer, 0.0));
    try std.testing.expectEqual(@as(f32, 3.0), timer);
}

test "Zoglins attack piglins, skeletons, zombies, golems and ghasts" {
    try std.testing.expect(shouldZoglinAttackEntity(false, false, false));
    try std.testing.expect(shouldZoglinAttackEntity(false, false, true));
}

test "Zoglins exclude other Zoglins and Creepers" {
    try std.testing.expect(!shouldZoglinAttackEntity(true, false, false));
    try std.testing.expect(!shouldZoglinAttackEntity(false, true, false));
}

test "Crimson Fungus breeds Hoglins but not Zoglins" {
    try std.testing.expect(canBreedHoglin(false, true));
    try std.testing.expect(!canBreedHoglin(false, false));
    try std.testing.expect(!canBreedHoglin(true, true));
}
