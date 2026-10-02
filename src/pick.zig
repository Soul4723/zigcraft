const std = @import("std");
const math = @import("math.zig");
const chunk_mod = @import("world/chunk.zig");

/// Result of a voxel raycast: world block coords + face normal of entry.
pub const Hit = struct {
    x: i32,
    y: i32,
    z: i32,
    nx: i32,
    ny: i32,
    nz: i32,
};

/// Amanatides & Woo DDA over a solid-test callback.
/// origin: ray start (world coords). dir must be normalized.
/// max_dist: abort after this travel. Returns first solid cell + entry face.
pub fn raycast(
    isSolid: *const fn (x: i32, y: i32, z: i32) bool,
    origin: math.Vec3,
    dir: math.Vec3,
    max_dist: f32,
) ?Hit {
    var x: i32 = @intFromFloat(@floor(origin.x));
    var y: i32 = @intFromFloat(@floor(origin.y));
    var z: i32 = @intFromFloat(@floor(origin.z));

    const step_x: i32 = if (dir.x > 0) 1 else if (dir.x < 0) -1 else 0;
    const step_y: i32 = if (dir.y > 0) 1 else if (dir.y < 0) -1 else 0;
    const step_z: i32 = if (dir.z > 0) 1 else if (dir.z < 0) -1 else 0;

    const t_delta_x: f32 = if (dir.x != 0) @abs(1 / dir.x) else std.math.inf(f32);
    const t_delta_y: f32 = if (dir.y != 0) @abs(1 / dir.y) else std.math.inf(f32);
    const t_delta_z: f32 = if (dir.z != 0) @abs(1 / dir.z) else std.math.inf(f32);

    var t_max_x: f32 = if (dir.x != 0)
        (if (step_x > 0) (@as(f32, @floatFromInt(x + 1)) - origin.x) else (origin.x - @as(f32, @floatFromInt(x)))) * t_delta_x
    else
        std.math.inf(f32);
    var t_max_y: f32 = if (dir.y != 0)
        (if (step_y > 0) (@as(f32, @floatFromInt(y + 1)) - origin.y) else (origin.y - @as(f32, @floatFromInt(y)))) * t_delta_y
    else
        std.math.inf(f32);
    var t_max_z: f32 = if (dir.z != 0)
        (if (step_z > 0) (@as(f32, @floatFromInt(z + 1)) - origin.z) else (origin.z - @as(f32, @floatFromInt(z)))) * t_delta_z
    else
        std.math.inf(f32);

    var nx: i32 = 0;
    var ny: i32 = 0;
    var nz: i32 = 0;
    var t: f32 = 0;

    // Check starting cell first (eye inside solid — shouldn't happen, but cheap).
    if (isSolid(x, y, z)) return .{ .x = x, .y = y, .z = z, .nx = 0, .ny = 0, .nz = 0 };

    while (t <= max_dist) {
        if (t_max_x < t_max_y and t_max_x < t_max_z) {
            x += step_x;
            t = t_max_x;
            t_max_x += t_delta_x;
            nx = -step_x;
            ny = 0;
            nz = 0;
        } else if (t_max_y < t_max_z) {
            y += step_y;
            t = t_max_y;
            t_max_y += t_delta_y;
            nx = 0;
            ny = -step_y;
            nz = 0;
        } else {
            z += step_z;
            t = t_max_z;
            t_max_z += t_delta_z;
            nx = 0;
            ny = 0;
            nz = -step_z;
        }
        if (t > max_dist) break;
        if (isSolid(x, y, z)) return .{ .x = x, .y = y, .z = z, .nx = nx, .ny = ny, .nz = nz };
    }
    return null;
}

// ---- test scaffolding: single chunk as the world ----

var test_chunk: chunk_mod.Chunk = undefined;

fn testSolid(x: i32, y: i32, z: i32) bool {
    if (x < 0 or y < 0 or z < 0 or x >= 16 or y >= 16 or z >= 16) return false;
    return test_chunk.getBlock(@intCast(x), @intCast(y), @intCast(z)).is_solid();
}

test "ray straight down hits floor" {
    test_chunk = chunk_mod.Chunk.init();
    test_chunk.fillLayer(0, .stone);
    const hit = raycast(&testSolid, math.Vec3.init(8, 10, 8), math.Vec3.init(0, -1, 0), 20);
    try std.testing.expect(hit != null);
    try std.testing.expectEqual(hit.?.y, 0);
    try std.testing.expectEqual(hit.?.ny, 1); // entered through top face
}

test "ray into empty sky misses" {
    test_chunk = chunk_mod.Chunk.init();
    const hit = raycast(&testSolid, math.Vec3.init(8, 10, 8), math.Vec3.init(0, 1, 0), 20);
    try std.testing.expect(hit == null);
}

test "ray respects max distance" {
    test_chunk = chunk_mod.Chunk.init();
    test_chunk.fillLayer(0, .stone);
    const hit = raycast(&testSolid, math.Vec3.init(8, 10, 8), math.Vec3.init(0, -1, 0), 5);
    try std.testing.expect(hit == null); // floor is 10 away
}

test "ray diagonal hits pillar side with face normal" {
    test_chunk = chunk_mod.Chunk.init();
    test_chunk.setBlock(8, 5, 8, .stone);
    const hit = raycast(&testSolid, math.Vec3.init(4, 5.5, 8.5), math.Vec3.init(1, 0, 0), 20);
    try std.testing.expect(hit != null);
    try std.testing.expectEqual(hit.?.x, 8);
    try std.testing.expectEqual(hit.?.nx, -1);
}

test "ray starting inside solid returns it" {
    test_chunk = chunk_mod.Chunk.init();
    test_chunk.fillLayer(5, .stone);
    const hit = raycast(&testSolid, math.Vec3.init(8, 5.5, 8), math.Vec3.init(0, 1, 0), 20);
    try std.testing.expect(hit != null);
    try std.testing.expectEqual(hit.?.y, 5);
}
