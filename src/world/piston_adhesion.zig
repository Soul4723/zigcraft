const std = @import("std");

pub const PistonBlockClass = enum {
    air,
    movable_normal,
    slime_block,
    honey_block,
    glazed_terracotta,
    immovable_obsidian_or_tile,
    crushable_plant_or_cobweb,
};

/// Slime and honey adhere only to their own kind and ordinary movable blocks.
/// Air, glazed terracotta, immovable blocks, and crushables are not adhesive.
pub fn doBlocksStickTogether(block_a: PistonBlockClass, block_b: PistonBlockClass) bool {
    return switch (block_a) {
        .slime_block => block_b == .slime_block or block_b == .movable_normal,
        .honey_block => block_b == .honey_block or block_b == .movable_normal,
        else => switch (block_b) {
            .slime_block => block_a == .movable_normal,
            .honey_block => block_a == .movable_normal,
            else => false,
        },
    };
}

/// Glazed terracotta can be pushed by a piston face, but is not pulled by sticky pistons.
pub fn canStickyPistonPull(block: PistonBlockClass) bool {
    return block != .air and block != .glazed_terracotta and
        block != .immovable_obsidian_or_tile and block != .crushable_plant_or_cobweb;
}

/// Whether a piston pushing into a block can affect it. Crushable plants and
/// cobwebs qualify because they break instead of joining the moved cluster.
pub fn canPistonPush(block: PistonBlockClass) bool {
    return block != .air and block != .immovable_obsidian_or_tile;
}

/// Plants and cobwebs are destroyed when a piston pushes into them.
pub fn isPistonCrushable(block: PistonBlockClass) bool {
    return block == .crushable_plant_or_cobweb;
}

pub const max_piston_push_limit: usize = 12;

/// Accept a cluster only if it contains no more than twelve movable blocks and
/// the search did not encounter an immovable block.
pub fn evaluatePushClusterLimit(cluster_block_count: usize, encountered_immovable: bool) bool {
    return cluster_block_count <= max_piston_push_limit and !encountered_immovable;
}

pub const EntityKinematics = struct { vx: f32, vy: f32, vz: f32 };

/// Slime launches pushed entities at 10 m/s along the piston direction.
/// Honey carries entities on top by one block displacement along that direction.
/// If both effects apply, slime launch takes precedence.
pub fn resolvePistonMovedEntityKinematics(
    pushed_by_slime: bool,
    dragged_on_top_of_honey: bool,
    piston_dir: [3]f32,
) EntityKinematics {
    const scale: f32 = if (pushed_by_slime) 10.0 else if (dragged_on_top_of_honey) 1.0 else 0.0;
    return .{
        .vx = piston_dir[0] * scale,
        .vy = piston_dir[1] * scale,
        .vz = piston_dir[2] * scale,
    };
}

test "slime adheres to slime and normal movable blocks" {
    try std.testing.expect(doBlocksStickTogether(.slime_block, .slime_block));
    try std.testing.expect(doBlocksStickTogether(.slime_block, .movable_normal));
    try std.testing.expect(doBlocksStickTogether(.movable_normal, .slime_block));
}

test "honey adheres to honey and normal movable blocks" {
    try std.testing.expect(doBlocksStickTogether(.honey_block, .honey_block));
    try std.testing.expect(doBlocksStickTogether(.honey_block, .movable_normal));
    try std.testing.expect(doBlocksStickTogether(.movable_normal, .honey_block));
}

test "slime and honey never adhere in either orientation" {
    try std.testing.expect(!doBlocksStickTogether(.slime_block, .honey_block));
    try std.testing.expect(!doBlocksStickTogether(.honey_block, .slime_block));
}

test "slime and honey do not adhere to glazed terracotta" {
    try std.testing.expect(!doBlocksStickTogether(.slime_block, .glazed_terracotta));
    try std.testing.expect(!doBlocksStickTogether(.glazed_terracotta, .slime_block));
    try std.testing.expect(!doBlocksStickTogether(.honey_block, .glazed_terracotta));
    try std.testing.expect(!doBlocksStickTogether(.glazed_terracotta, .honey_block));
}

test "ordinary blocks do not adhere to each other" {
    try std.testing.expect(!doBlocksStickTogether(.movable_normal, .movable_normal));
}

test "adhesion excludes air, immovables, and crushables" {
    try std.testing.expect(!doBlocksStickTogether(.slime_block, .air));
    try std.testing.expect(!doBlocksStickTogether(.honey_block, .immovable_obsidian_or_tile));
    try std.testing.expect(!doBlocksStickTogether(.movable_normal, .crushable_plant_or_cobweb));
}

test "glazed terracotta is pushable but not sticky-pullable" {
    try std.testing.expect(canPistonPush(.glazed_terracotta));
    try std.testing.expect(!canStickyPistonPull(.glazed_terracotta));
}

test "ordinary and sticky blocks are pushable by a piston face" {
    try std.testing.expect(canPistonPush(.movable_normal));
    try std.testing.expect(canPistonPush(.slime_block));
    try std.testing.expect(canPistonPush(.honey_block));
}

test "air and immovable blocks cannot be pushed" {
    try std.testing.expect(!canPistonPush(.air));
    try std.testing.expect(!canPistonPush(.immovable_obsidian_or_tile));
}

test "sticky piston can pull ordinary and slime or honey blocks" {
    try std.testing.expect(canStickyPistonPull(.movable_normal));
    try std.testing.expect(canStickyPistonPull(.slime_block));
    try std.testing.expect(canStickyPistonPull(.honey_block));
}

test "sticky piston cannot pull air immovable or crushable classes" {
    try std.testing.expect(!canStickyPistonPull(.air));
    try std.testing.expect(!canStickyPistonPull(.immovable_obsidian_or_tile));
    try std.testing.expect(!canStickyPistonPull(.crushable_plant_or_cobweb));
}

test "push cluster accepts exact twelve block limit" {
    try std.testing.expect(evaluatePushClusterLimit(12, false));
}

test "push cluster rejects thirteen blocks" {
    try std.testing.expect(!evaluatePushClusterLimit(13, false));
}

test "push cluster rejects immovable blocker even below limit" {
    try std.testing.expect(!evaluatePushClusterLimit(4, true));
}

test "push cluster rejects immovable blocker at limit" {
    try std.testing.expect(!evaluatePushClusterLimit(12, true));
}

test "slime launches entity at ten meters per second along piston direction" {
    const velocity = resolvePistonMovedEntityKinematics(true, false, .{ 1.0, 0.0, -1.0 });
    try std.testing.expectEqual(@as(f32, 10.0), velocity.vx);
    try std.testing.expectEqual(@as(f32, 0.0), velocity.vy);
    try std.testing.expectEqual(@as(f32, -10.0), velocity.vz);
}

test "honey drags entity by one block along piston direction" {
    const velocity = resolvePistonMovedEntityKinematics(false, true, .{ 0.0, 1.0, 0.0 });
    try std.testing.expectEqual(@as(f32, 0.0), velocity.vx);
    try std.testing.expectEqual(@as(f32, 1.0), velocity.vy);
    try std.testing.expectEqual(@as(f32, 0.0), velocity.vz);
}

test "slime launch takes precedence over honey drag" {
    const velocity = resolvePistonMovedEntityKinematics(true, true, .{ 1.0, 0.0, 0.0 });
    try std.testing.expectEqual(@as(f32, 10.0), velocity.vx);
}

test "unaffected entity has zero piston kinematics" {
    const velocity = resolvePistonMovedEntityKinematics(false, false, .{ 1.0, 0.0, 0.0 });
    try std.testing.expectEqual(@as(f32, 0.0), velocity.vx);
    try std.testing.expectEqual(@as(f32, 0.0), velocity.vy);
    try std.testing.expectEqual(@as(f32, 0.0), velocity.vz);
}

test "crushable plants and cobwebs break on piston push" {
    try std.testing.expect(canPistonPush(.crushable_plant_or_cobweb));
    try std.testing.expect(isPistonCrushable(.crushable_plant_or_cobweb));
    try std.testing.expect(!isPistonCrushable(.movable_normal));
    try std.testing.expect(!isPistonCrushable(.glazed_terracotta));
    try std.testing.expect(!canStickyPistonPull(.crushable_plant_or_cobweb));
    try std.testing.expect(!doBlocksStickTogether(.slime_block, .crushable_plant_or_cobweb));
}
