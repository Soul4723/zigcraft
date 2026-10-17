const std = @import("std");

pub const ghast_health: f32 = 10.0;
pub const reflected_fireball_damage: f32 = 1000.0;
pub const deflection_speed_multiplier: f32 = 2.0;
pub const ghast_sight_range: f32 = 64.0;
pub const ghast_sight_range_sq: f32 = ghast_sight_range * ghast_sight_range;
pub const ghast_fireball_blast_resistance_threshold: f32 = 3.5;

pub const GhastFireball = struct {
    pos: [3]f32,
    vel: [3]f32,
    was_deflected_by_player: bool = false,
    owner_ghast_id: u32,
};

/// Deflect a fireball toward the player's aim direction at twice its current speed.
/// A non-hit or already-deflected fireball is left unchanged.
pub fn deflectGhastFireball(
    fireball: *GhastFireball,
    player_aim_dir: [3]f32,
    hit_by_melee_or_arrow: bool,
) bool {
    if (!hit_by_melee_or_arrow or fireball.was_deflected_by_player) return false;

    const aim_len_sq = player_aim_dir[0] * player_aim_dir[0] +
        player_aim_dir[1] * player_aim_dir[1] +
        player_aim_dir[2] * player_aim_dir[2];
    if (aim_len_sq == 0.0) return false;

    const speed = @sqrt(fireball.vel[0] * fireball.vel[0] +
        fireball.vel[1] * fireball.vel[1] +
        fireball.vel[2] * fireball.vel[2]);
    const scale = deflection_speed_multiplier * speed / @sqrt(aim_len_sq);
    fireball.vel = .{
        player_aim_dir[0] * scale,
        player_aim_dir[1] * scale,
        player_aim_dir[2] * scale,
    };
    fireball.was_deflected_by_player = true;
    return true;
}

pub const FireballImpact = struct {
    damage_dealt: f32,
    return_to_sender_achievement: bool,
};

pub fn resolveFireballImpactOnGhast(fireball: GhastFireball, target_ghast_id: u32) FireballImpact {
    if (!fireball.was_deflected_by_player) {
        return .{ .damage_dealt = 0.0, .return_to_sender_achievement = false };
    }
    return .{
        .damage_dealt = reflected_fireball_damage,
        .return_to_sender_achievement = target_ghast_id == fireball.owner_ghast_id,
    };
}

/// A Ghast fireball (explosion power 1) cannot break blocks at resistance 3.5+.
pub fn canGhastFireballDestroyBlock(block_blast_resistance: f32) bool {
    return block_blast_resistance < ghast_fireball_blast_resistance_threshold;
}

/// Sight is spherical (64 blocks) and always requires an unobstructed raycast.
pub fn canGhastSeeTarget(dist_sq: f32, has_line_of_sight: bool) bool {
    return has_line_of_sight and dist_sq <= ghast_sight_range_sq;
}

fn sampleFireball() GhastFireball {
    return .{ .pos = .{ 0.0, 0.0, 0.0 }, .vel = .{ 3.0, 4.0, 0.0 }, .owner_ghast_id = 7 };
}

test "melee hit deflects fireball toward aim" {
    var fireball = sampleFireball();
    try std.testing.expect(deflectGhastFireball(&fireball, .{ 1.0, 0.0, 0.0 }, true));
    try std.testing.expect(fireball.was_deflected_by_player);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), fireball.vel[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), fireball.vel[1], 0.001);
}

test "arrow hit deflects fireball along diagonal aim" {
    var fireball = sampleFireball();
    try std.testing.expect(deflectGhastFireball(&fireball, .{ 1.0, 0.0, 1.0 }, true));
    try std.testing.expectApproxEqAbs(@as(f32, 10.0 / @sqrt(2.0)), fireball.vel[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0 / @sqrt(2.0)), fireball.vel[2], 0.001);
}

test "deflection doubles incoming speed" {
    var fireball = sampleFireball();
    _ = deflectGhastFireball(&fireball, .{ 0.0, 1.0, 0.0 }, true);
    const speed = @sqrt(fireball.vel[0] * fireball.vel[0] + fireball.vel[1] * fireball.vel[1] + fireball.vel[2] * fireball.vel[2]);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), speed, 0.001);
}

test "no melee or projectile hit does not deflect" {
    var fireball = sampleFireball();
    try std.testing.expect(!deflectGhastFireball(&fireball, .{ 1.0, 0.0, 0.0 }, false));
    try std.testing.expect(!fireball.was_deflected_by_player);
    try std.testing.expectEqual(@as(f32, 3.0), fireball.vel[0]);
}

test "zero aim direction cannot deflect" {
    var fireball = sampleFireball();
    try std.testing.expect(!deflectGhastFireball(&fireball, .{ 0.0, 0.0, 0.0 }, true));
    try std.testing.expect(!fireball.was_deflected_by_player);
}

test "deflected fireball cannot be repeatedly deflected" {
    var fireball = sampleFireball();
    try std.testing.expect(deflectGhastFireball(&fireball, .{ 1.0, 0.0, 0.0 }, true));
    try std.testing.expect(!deflectGhastFireball(&fireball, .{ 0.0, 0.0, 1.0 }, true));
    try std.testing.expectEqual(@as(f32, 10.0), fireball.vel[0]);
}

test "reflected fireball deals instant lethal damage" {
    var fireball = sampleFireball();
    _ = deflectGhastFireball(&fireball, .{ 1.0, 0.0, 0.0 }, true);
    const impact = resolveFireballImpactOnGhast(fireball, 99);
    try std.testing.expectEqual(@as(f32, 1000.0), impact.damage_dealt);
    try std.testing.expect(impact.damage_dealt >= ghast_health);
}

test "return to sender triggers for original owner" {
    var fireball = sampleFireball();
    _ = deflectGhastFireball(&fireball, .{ 1.0, 0.0, 0.0 }, true);
    const impact = resolveFireballImpactOnGhast(fireball, 7);
    try std.testing.expect(impact.return_to_sender_achievement);
}

test "return to sender does not trigger for another ghast" {
    var fireball = sampleFireball();
    _ = deflectGhastFireball(&fireball, .{ 1.0, 0.0, 0.0 }, true);
    const impact = resolveFireballImpactOnGhast(fireball, 8);
    try std.testing.expect(!impact.return_to_sender_achievement);
}

test "ordinary fireball does not damage ghast through reflected impact resolver" {
    const impact = resolveFireballImpactOnGhast(sampleFireball(), 7);
    try std.testing.expectEqual(@as(f32, 0.0), impact.damage_dealt);
    try std.testing.expect(!impact.return_to_sender_achievement);
}

test "cobblestone blast resistance prevents destruction" {
    try std.testing.expect(!canGhastFireballDestroyBlock(6.0));
}

test "stone bricks blast resistance prevents destruction" {
    try std.testing.expect(!canGhastFireballDestroyBlock(6.0));
}

test "basalt blast resistance prevents destruction" {
    try std.testing.expect(!canGhastFireballDestroyBlock(4.2));
}

test "obsidian blast resistance prevents destruction" {
    try std.testing.expect(!canGhastFireballDestroyBlock(1200.0));
}

test "netherrack blast resistance allows destruction" {
    try std.testing.expect(canGhastFireballDestroyBlock(0.4));
}

test "blast resistance threshold is inclusive" {
    try std.testing.expect(!canGhastFireballDestroyBlock(3.5));
    try std.testing.expect(canGhastFireballDestroyBlock(3.49));
}

test "ghast sees unobstructed target inside 64 block sphere" {
    try std.testing.expect(canGhastSeeTarget(64.0 * 64.0, true));
    try std.testing.expect(canGhastSeeTarget(40.0 * 40.0, true));
}

test "ghast cannot see target outside 64 block sphere" {
    try std.testing.expect(!canGhastSeeTarget(64.01 * 64.01, true));
}

test "ghast cannot see target through line of sight obstruction such as glass" {
    try std.testing.expect(!canGhastSeeTarget(10.0 * 10.0, false));
}
