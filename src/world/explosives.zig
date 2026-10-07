const std = @import("std");

pub const Fuse = struct { x: i32, y: i32, z: i32, t: f32 };
pub const fuse_cap: usize = 16;
pub const fuse_time: f32 = 2.0;
pub const chain_fuse_time: f32 = 0.5;
pub const blast_radius_sq: i32 = 10;
pub const blast_radius: i32 = 3;
pub const mob_blast_radius_sq: f32 = 36.0;
pub const mob_blast_damage: u8 = 8;
pub const player_blast_radius: f32 = 7.0;
pub const player_blast_damage: f32 = 14.0;

pub fn inBlast(dx: i32, dy: i32, dz: i32) bool {
    return dx * dx + dy * dy + dz * dz <= blast_radius_sq;
}

pub fn blastFalloff(dist: f32) f32 {
    if (dist >= player_blast_radius or dist <= 0.1) return 0.0;
    return (player_blast_radius - dist) / player_blast_radius;
}

test "blast sphere membership" {
    try std.testing.expect(inBlast(0, 0, 0));
    try std.testing.expect(inBlast(3, 0, 0));
    try std.testing.expect(inBlast(2, 2, 1));
    try std.testing.expect(!inBlast(3, 3, 3));
    try std.testing.expect(!inBlast(0, 4, 0));
}

test "blast falloff curve" {
    try std.testing.expectEqual(blastFalloff(0.05), 0.0);
    try std.testing.expectEqual(blastFalloff(7.0), 0.0);
    try std.testing.expectEqual(blastFalloff(9.0), 0.0);
    const mid = blastFalloff(3.5);
    try std.testing.expect(mid > 0.4 and mid < 0.6);
    try std.testing.expect(blastFalloff(1.0) > blastFalloff(6.0));
}

pub fn findFuse(fuses: []const Fuse, x: i32, y: i32, z: i32) ?usize {
    for (fuses, 0..) |f, i| {
        if (f.x == x and f.y == y and f.z == z) return i;
    }
    return null;
}

test "findFuse returns index or null" {
    const list = [_]Fuse{
        .{ .x = 1, .y = 2, .z = 3, .t = 1.0 },
        .{ .x = 4, .y = 5, .z = 6, .t = 2.0 },
    };
    try std.testing.expectEqual(@as(?usize, 0), findFuse(&list, 1, 2, 3));
    try std.testing.expectEqual(@as(?usize, 1), findFuse(&list, 4, 5, 6));
    try std.testing.expectEqual(@as(?usize, null), findFuse(&list, 0, 0, 0));
}

pub const BlastImpulse = struct {
    damage: f32,
    vel_y: f32,
    push_x: f32,
    push_z: f32,
};

pub fn calculatePlayerBlastImpulse(player_x: f32, player_y: f32, player_z: f32, ex: i32, ey: i32, ez: i32) ?BlastImpulse {
    const pdx = player_x - @as(f32, @floatFromInt(ex));
    const pdy = player_y - @as(f32, @floatFromInt(ey));
    const pdz = player_z - @as(f32, @floatFromInt(ez));
    const pdist = @sqrt(pdx * pdx + pdy * pdy + pdz * pdz);
    const blast_force = blastFalloff(pdist);
    if (blast_force <= 0.0 or pdist <= 0.001) return null;
    return BlastImpulse{
        .damage = blast_force * player_blast_damage,
        .vel_y = blast_force * 12.0,
        .push_x = (pdx / pdist) * blast_force * 3.0,
        .push_z = (pdz / pdist) * blast_force * 3.0,
    };
}

test "player blast impulse calculation" {
    // Player at distance 3.5m (halfway within 7m radius)
    const imp = calculatePlayerBlastImpulse(3.5, 0.0, 0.0, 0, 0, 0);
    try std.testing.expect(imp != null);
    if (imp) |val| {
        try std.testing.expect(val.damage > 0.0 and val.damage <= player_blast_damage);
        try std.testing.expect(val.vel_y > 0.0);
        try std.testing.expect(val.push_x > 0.0);
        try std.testing.expectEqual(@as(f32, 0.0), val.push_z);
    }

    // Player far outside blast radius
    try std.testing.expect(calculatePlayerBlastImpulse(10.0, 0.0, 0.0, 0, 0, 0) == null);
}

pub const MobBlastHit = struct {
    damage: u8,
    knockback: [3]f32,
};

pub fn calculateMobBlastHit(mx: f32, my: f32, mz: f32, ex: i32, ey: i32, ez: i32) ?MobBlastHit {
    const mdx = mx - @as(f32, @floatFromInt(ex));
    const mdy = my - @as(f32, @floatFromInt(ey));
    const mdz = mz - @as(f32, @floatFromInt(ez));
    const dist_sq = mdx * mdx + mdy * mdy + mdz * mdz;
    if (dist_sq < mob_blast_radius_sq) {
        return MobBlastHit{
            .damage = mob_blast_damage,
            .knockback = .{ mdx, mdy + 2.0, mdz },
        };
    }
    return null;
}

test "mob blast hit calculation" {
    // Within 6 blocks (dist_sq < 36)
    const hit = calculateMobBlastHit(2.0, 1.0, 2.0, 0, 0, 0);
    try std.testing.expect(hit != null);
    if (hit) |h| {
        try std.testing.expectEqual(mob_blast_damage, h.damage);
        try std.testing.expectEqual(@as(f32, 2.0), h.knockback[0]);
        try std.testing.expectEqual(@as(f32, 3.0), h.knockback[1]);
        try std.testing.expectEqual(@as(f32, 2.0), h.knockback[2]);
    }

    // Outside blast radius
    try std.testing.expect(calculateMobBlastHit(10.0, 0.0, 0.0, 0, 0, 0) == null);
}

pub const BlastBlockAction = enum {
    chain_tnt,
    destroy_chest,
    destroy_block,
    ignore,
};

pub fn evaluateBlastBlock(block: @import("block.zig").BlockId, y: i32) BlastBlockAction {
    if (y <= 0) return .ignore;
    return switch (block) {
        .tnt => .chain_tnt,
        .chest => .destroy_chest,
        .air => .ignore,
        else => .destroy_block,
    };
}

test "evaluateBlastBlock classification" {
    try std.testing.expectEqual(BlastBlockAction.ignore, evaluateBlastBlock(.stone, 0));
    try std.testing.expectEqual(BlastBlockAction.ignore, evaluateBlastBlock(.air, 5));
    try std.testing.expectEqual(BlastBlockAction.chain_tnt, evaluateBlastBlock(.tnt, 5));
    try std.testing.expectEqual(BlastBlockAction.destroy_chest, evaluateBlastBlock(.chest, 5));
    try std.testing.expectEqual(BlastBlockAction.destroy_block, evaluateBlastBlock(.dirt, 5));
}

pub fn canChainFuse(fuses: []const Fuse, x: i32, y: i32, z: i32, max_fuses: usize) bool {
    return findFuse(fuses, x, y, z) == null and fuses.len < max_fuses;
}

test "canChainFuse helper" {
    const list = [_]Fuse{.{ .x = 1, .y = 2, .z = 3, .t = 1.0 }};
    try std.testing.expect(canChainFuse(&list, 2, 2, 2, 4));
    try std.testing.expect(!canChainFuse(&list, 1, 2, 3, 4));
    try std.testing.expect(!canChainFuse(&list, 2, 2, 2, 1));
}

pub fn isDetonated(fuse_timer: f32) bool {
    return fuse_timer <= 0.0;
}

test "isDetonated check" {
    try std.testing.expect(isDetonated(0.0));
    try std.testing.expect(isDetonated(-0.1));
    try std.testing.expect(!isDetonated(0.5));
}
