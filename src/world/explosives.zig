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
