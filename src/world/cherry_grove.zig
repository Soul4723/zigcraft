const std = @import("std");

// ============================================================================
// Constants and Tags
// ============================================================================

/// Item and Block tag IDs for future registry integration.
pub const CherryLogTag: u16 = 400;
pub const StrippedCherryLogTag: u16 = 401;
pub const CherryPlanksTag: u16 = 402;
pub const CherryLeavesTag: u16 = 403;
pub const CherrySaplingTag: u16 = 404;
pub const PinkPetalsTag: u16 = 405;
pub const CherrySlabTag: u16 = 406;
pub const CherryStairsTag: u16 = 407;
pub const CherryDoorTag: u16 = 408;
pub const CherryTrapdoorTag: u16 = 409;
pub const CherryFenceTag: u16 = 410;
pub const CherryFenceGateTag: u16 = 411;
pub const CherryButtonTag: u16 = 412;
pub const CherryPressurePlateTag: u16 = 413;
pub const CherrySignTag: u16 = 414;
pub const CherryBoatTag: u16 = 415;

/// Cherry Grove biome environmental parameters.
pub const cherry_grove_temperature: f32 = 0.5;
pub const cherry_grove_downfall: f32 = 0.8;
pub const cherry_grove_min_elevation: usize = 10;
pub const cherry_tree_bee_nest_chance: f32 = 0.05;

// ============================================================================
// Pink Petals Cluster State Machine
// ============================================================================

pub const min_petals: u3 = 1;
pub const max_petals: u3 = 4;

/// Cardinal orientation of pink petal cluster on ground surface.
pub const PetalFacing = enum(u2) {
    north = 0,
    east = 1,
    south = 2,
    west = 3,
};

/// A placed pink petals cluster block in the world.
pub const PinkPetalsCluster = struct {
    x: i32,
    y: i32,
    z: i32,
    count: u3 = min_petals,
    facing: PetalFacing = .north,

    pub fn init(x: i32, y: i32, z: i32, count: u3, facing: PetalFacing) PinkPetalsCluster {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .count = @max(min_petals, @min(count, max_petals)),
            .facing = facing,
        };
    }
};

pub const BoneMealResult = struct {
    incremented: bool,
    dropped_petals: u8,
};

/// Applying bone meal to pink petals:
/// - If count < 4: increments petal count by 1 (no drop).
/// - If count == 4: cluster cannot hold more petals, so drops 1 extra pink petal item!
pub fn applyBoneMealToPetals(cluster: *PinkPetalsCluster) BoneMealResult {
    if (cluster.count < max_petals) {
        cluster.count += 1;
        return .{ .incremented = true, .dropped_petals = 0 };
    } else {
        return .{ .incremented = false, .dropped_petals = 1 };
    }
}

/// Player adds another pink petal item to an existing cluster.
/// Returns true if successful, false if cluster is already at maximum (4).
pub fn addPetalToCluster(cluster: *PinkPetalsCluster) bool {
    if (cluster.count < max_petals) {
        cluster.count += 1;
        return true;
    }
    return false;
}

/// Mining or breaking pink petals yields items equal to the petal cluster count (1..4).
pub fn harvestPetals(cluster: PinkPetalsCluster) u8 {
    return @as(u8, cluster.count);
}

/// Harvest yield when tool is taken into account.
/// Both mining (any tool/bare hand) and shearing drop petals equal to the cluster count.
pub fn harvestPetalYield(cluster: PinkPetalsCluster, is_shears: bool) u8 {
    _ = is_shears;
    return @as(u8, cluster.count);
}

/// Pink petals can only be placed on soil-class blocks (grass, dirt, moss, mud, etc.)
/// and must be placed on the upward-facing surface (hit_ny == 1).
pub fn canPlantPetalsOn(is_soil_or_moss: bool, hit_ny: i32) bool {
    return is_soil_or_moss and hit_ny == 1;
}

// ============================================================================
// Cherry Sapling Growth Rules
// ============================================================================

pub const sapling_grow_time: f32 = 30.0;
pub const sapling_min_light_level: u8 = 9;
pub const sapling_bone_meal_boost: f32 = 15.0;

pub const CherrySapling = struct {
    x: i32,
    y: i32,
    z: i32,
    growth_timer: f32 = 0.0,
    stage: u8 = 0,

    pub fn init(x: i32, y: i32, z: i32) CherrySapling {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .growth_timer = 0.0,
            .stage = 0,
        };
    }

    pub fn isReady(self: CherrySapling) bool {
        return self.growth_timer >= sapling_grow_time;
    }
};

/// Soil and vertical space check for planting a cherry sapling.
pub fn canPlantSapling(is_soil_or_moss: bool, hit_ny: i32, py: i32, max_world_height: i32) bool {
    // Cherry trees need at least 6 blocks of overhead clearance
    return is_soil_or_moss and hit_ny == 1 and (py + 6 < max_world_height);
}

/// Saplings require adequate light (>= 9) to accumulate growth.
pub fn canSaplingGrow(light_level: u8) bool {
    return light_level >= sapling_min_light_level;
}

/// Ticks sapling growth by dt seconds if lighting allows.
/// Returns true when the sapling reaches full maturity and is ready to generate a tree.
pub fn tickSapling(sapling: *CherrySapling, dt: f32, light_level: u8) bool {
    if (!canSaplingGrow(light_level)) return false;
    sapling.growth_timer += dt;
    if (sapling.growth_timer >= sapling_grow_time / 2.0 and sapling.stage == 0) {
        sapling.stage = 1;
    }
    return sapling.isReady();
}

/// Applies bone meal to accelerate cherry sapling growth.
/// Returns true if light permits bone meal to take effect.
pub fn applyBoneMealToSapling(sapling: *CherrySapling, light_level: u8) bool {
    if (!canSaplingGrow(light_level)) return false;
    sapling.growth_timer += sapling_bone_meal_boost;
    if (sapling.growth_timer >= sapling_grow_time / 2.0 and sapling.stage == 0) {
        sapling.stage = 1;
    }
    return true;
}

// ============================================================================
// Procedural Cherry Blossom Canopy Generator
// ============================================================================

pub const CherryTreeBlockType = enum(u8) {
    trunk_log = 0,
    branch_log = 1,
    leaves = 2,
    bee_nest = 3,
};

pub const TreeBlock = struct {
    dx: i32,
    dy: i32,
    dz: i32,
    block_type: CherryTreeBlockType,
};

pub const TreeBounds = struct {
    min_x: i32 = 0,
    max_x: i32 = 0,
    min_y: i32 = 0,
    max_y: i32 = 0,
    min_z: i32 = 0,
    max_z: i32 = 0,

    pub fn width(self: TreeBounds) i32 {
        return self.max_x - self.min_x + 1;
    }
    pub fn height(self: TreeBounds) i32 {
        return self.max_y - self.min_y + 1;
    }
    pub fn depth(self: TreeBounds) i32 {
        return self.max_z - self.min_z + 1;
    }
};

pub const TreeConfig = struct {
    trunk_height: u8 = 6,
    bend_dir_x: i8 = 1,
    bend_dir_z: i8 = 0,
    canopy_radius: u8 = 3,
    has_bee_nest: bool = false,
};

pub const TreeGenerationResult = struct {
    count: usize,
    trunk_count: usize,
    branch_count: usize,
    leaf_count: usize,
    has_nest: bool,
    bounds: TreeBounds,
};

fn updateBounds(bounds: *TreeBounds, x: i32, y: i32, z: i32) void {
    bounds.min_x = @min(bounds.min_x, x);
    bounds.max_x = @max(bounds.max_x, x);
    bounds.min_y = @min(bounds.min_y, y);
    bounds.max_y = @max(bounds.max_y, y);
    bounds.min_z = @min(bounds.min_z, z);
    bounds.max_z = @max(bounds.max_z, z);
}

/// Procedural Cherry Blossom tree and canopy generator:
/// - Curved trunk: begins vertically, bends diagonally/horizontally from mid-height
/// - Branching: outward branch splitting off near apex
/// - Wide flat canopy: broad horizontal leaf disk (radius 3..4) with shallow height (2..3 layers)
/// - Optional bee nest beneath branch
pub fn generateCherryTree(buffer: []TreeBlock, config: TreeConfig) TreeGenerationResult {
    var count: usize = 0;
    var trunk_count: usize = 0;
    var branch_count: usize = 0;
    var leaf_count: usize = 0;
    var has_nest: bool = false;

    var bounds = TreeBounds{
        .min_x = 0,
        .max_x = 0,
        .min_y = 0,
        .max_y = 0,
        .min_z = 0,
        .max_z = 0,
    };

    const th: i32 = @as(i32, config.trunk_height);
    const bend_start: i32 = @divTrunc(th, 2);

    // 1. Curved Trunk:
    var cur_x: i32 = 0;
    var cur_z: i32 = 0;
    var y: i32 = 0;
    while (y < th) : (y += 1) {
        if (y >= bend_start) {
            cur_x += config.bend_dir_x;
            cur_z += config.bend_dir_z;
        }
        if (count < buffer.len) {
            buffer[count] = .{ .dx = cur_x, .dy = y, .dz = cur_z, .block_type = .trunk_log };
            count += 1;
            trunk_count += 1;
            updateBounds(&bounds, cur_x, y, cur_z);
        }
    }

    const apex_x = cur_x;
    const apex_y = th - 1;
    const apex_z = cur_z;

    // 2. Outward Branch:
    const branch_y = @max(1, apex_y - 1);
    const branch_dx: i32 = if (config.bend_dir_z != 0) 1 else (if (config.bend_dir_x == 0) 1 else -config.bend_dir_x);
    const branch_dz: i32 = if (config.bend_dir_x != 0) 1 else (if (config.bend_dir_z == 0) 1 else -config.bend_dir_z);

    var b_step: i32 = 1;
    while (b_step <= 2) : (b_step += 1) {
        const bx = apex_x + branch_dx * b_step;
        const by = branch_y + (b_step - 1);
        const bz = apex_z + branch_dz * b_step;
        if (count < buffer.len) {
            buffer[count] = .{ .dx = bx, .dy = by, .dz = bz, .block_type = .branch_log };
            count += 1;
            branch_count += 1;
            updateBounds(&bounds, bx, by, bz);
        }
    }

    // Optional bee nest under branch or apex
    if (config.has_bee_nest and count < buffer.len) {
        const nest_x = apex_x;
        const nest_y = branch_y - 1;
        const nest_z = apex_z;
        buffer[count] = .{ .dx = nest_x, .dy = nest_y, .dz = nest_z, .block_type = .bee_nest };
        count += 1;
        has_nest = true;
        updateBounds(&bounds, nest_x, nest_y, nest_z);
    }

    // 3. Wide Flat Leaf Canopy:
    // Cherry tree crowns are wide, umbrella-like disks with rounded corners
    const rad: i32 = @as(i32, config.canopy_radius);

    var layer_dy: i32 = 0;
    while (layer_dy <= 2) : (layer_dy += 1) {
        const ly = apex_y + layer_dy;
        const layer_radius: i32 = switch (layer_dy) {
            0 => rad - 1, // Lower perimeter
            1 => rad,     // Main wide flat disk
            else => @max(1, rad - 1), // Top cap
        };
        const layer_rad_sq = layer_radius * layer_radius;

        var lx = -layer_radius;
        while (lx <= layer_radius) : (lx += 1) {
            var lz = -layer_radius;
            while (lz <= layer_radius) : (lz += 1) {
                // Circular / rounded pruning to form smooth petal canopy
                if (lx * lx + lz * lz > layer_rad_sq + 1) continue;

                const world_lx = apex_x + lx;
                const world_lz = apex_z + lz;

                // Avoid overwriting trunk/branch/nest blocks
                var occupied = false;
                for (buffer[0..count]) |b| {
                    if (b.dx == world_lx and b.dy == ly and b.dz == world_lz) {
                        occupied = true;
                        break;
                    }
                }

                if (!occupied and count < buffer.len) {
                    buffer[count] = .{
                        .dx = world_lx,
                        .dy = ly,
                        .dz = world_lz,
                        .block_type = .leaves,
                    };
                    count += 1;
                    leaf_count += 1;
                    updateBounds(&bounds, world_lx, ly, world_lz);
                }
            }
        }
    }

    return .{
        .count = count,
        .trunk_count = trunk_count,
        .branch_count = branch_count,
        .leaf_count = leaf_count,
        .has_nest = has_nest,
        .bounds = bounds,
    };
}

// ============================================================================
// Falling Cherry Petal Particle Spawn Rate
// ============================================================================

/// Base rate of falling pink petal particles per exposed leaf block per second.
pub const base_petal_particle_rate_per_leaf: f32 = 0.08;

/// Computes the total particle spawn rate (particles/second) for a group of cherry leaves.
/// air_exposed_ratio: fraction (0.0 .. 1.0) of leaves that have open air beneath them.
pub fn calculatePetalParticleSpawnRate(leaf_count: usize, air_exposed_ratio: f32) f32 {
    const clamped_ratio = @max(0.0, @min(air_exposed_ratio, 1.0));
    const effective_leaves = @as(f32, @floatFromInt(leaf_count)) * clamped_ratio;
    return effective_leaves * base_petal_particle_rate_per_leaf;
}

/// Calculates how many whole particles should spawn in a time step `dt` seconds.
pub fn calculateParticleSpawnCount(rate: f32, dt: f32) u32 {
    if (rate <= 0.0 or dt <= 0.0) return 0;
    const expected = rate * dt;
    return @intFromFloat(@floor(expected));
}

/// Stochastic particle check for an individual leaf block over time dt.
pub fn shouldSpawnSingleLeafParticle(random_val: f32, dt: f32) bool {
    const chance = 1.0 - std.math.exp(-base_petal_particle_rate_per_leaf * dt);
    return random_val < chance;
}

// ============================================================================
// Cherry Wood Family Conversion Helpers
// ============================================================================

pub const CherryWoodItem = enum(u8) {
    cherry_log = 0,
    stripped_cherry_log = 1,
    cherry_planks = 2,
    cherry_slab = 3,
    cherry_stairs = 4,
    cherry_door = 5,
    cherry_trapdoor = 6,
    cherry_fence = 7,
    cherry_fence_gate = 8,
    cherry_button = 9,
    cherry_pressure_plate = 10,
    cherry_sign = 11,
    cherry_boat = 12,
};

/// Strips the bark from a Cherry Log using an Axe, returning Stripped Cherry Log.
/// Stripped Cherry Log cannot be stripped again (returns null).
pub fn stripLog(item: CherryWoodItem) ?CherryWoodItem {
    return switch (item) {
        .cherry_log => .stripped_cherry_log,
        else => null,
    };
}

/// Checks if an item can be stripped with an axe tool.
pub fn canStripWithAxe(is_axe: bool, item: CherryWoodItem) bool {
    return is_axe and item == .cherry_log;
}

/// Tag-based log stripping helper.
pub fn stripLogTag(tag: u16) ?u16 {
    if (tag == CherryLogTag) return StrippedCherryLogTag;
    return null;
}

/// 1 Cherry Log (or Stripped Cherry Log) crafts 4 Cherry Planks.
pub fn planksFromLogs(log_count: u32) u32 {
    return log_count * 4;
}

pub const CraftResult = struct {
    output_count: u32,
    remainder_planks: u32,
};

/// 3 Cherry Planks -> 6 Cherry Slabs (yield: 2 slabs per plank).
pub fn craftSlabs(plank_count: u32) CraftResult {
    const batches = plank_count / 3;
    return .{
        .output_count = batches * 6,
        .remainder_planks = plank_count % 3,
    };
}

/// 6 Cherry Planks -> 4 Cherry Stairs.
pub fn craftStairs(plank_count: u32) CraftResult {
    const batches = plank_count / 6;
    return .{
        .output_count = batches * 4,
        .remainder_planks = plank_count % 6,
    };
}

/// 6 Cherry Planks -> 3 Cherry Doors.
pub fn craftDoors(plank_count: u32) CraftResult {
    const batches = plank_count / 6;
    return .{
        .output_count = batches * 3,
        .remainder_planks = plank_count % 6,
    };
}

/// 6 Cherry Planks -> 2 Cherry Trapdoors.
pub fn craftTrapdoors(plank_count: u32) CraftResult {
    const batches = plank_count / 6;
    return .{
        .output_count = batches * 2,
        .remainder_planks = plank_count % 6,
    };
}

pub const FenceCraftResult = struct {
    fences: u32,
    remainder_planks: u32,
    remainder_sticks: u32,
};

/// 4 Cherry Planks + 2 Sticks -> 3 Cherry Fences.
pub fn craftFences(plank_count: u32, stick_count: u32) FenceCraftResult {
    const plank_batches = plank_count / 4;
    const stick_batches = stick_count / 2;
    const batches = @min(plank_batches, stick_batches);
    return .{
        .fences = batches * 3,
        .remainder_planks = plank_count - (batches * 4),
        .remainder_sticks = stick_count - (batches * 2),
    };
}

/// 2 Cherry Planks + 4 Sticks -> 1 Cherry Fence Gate.
pub fn craftFenceGate(plank_count: u32, stick_count: u32) struct { gates: u32, remainder_planks: u32, remainder_sticks: u32 } {
    const plank_batches = plank_count / 2;
    const stick_batches = stick_count / 4;
    const batches = @min(plank_batches, stick_batches);
    return .{
        .gates = batches * 1,
        .remainder_planks = plank_count - (batches * 2),
        .remainder_sticks = stick_count - (batches * 4),
    };
}

/// 2 Cherry Planks -> 1 Cherry Pressure Plate.
pub fn craftPressurePlate(plank_count: u32) CraftResult {
    const batches = plank_count / 2;
    return .{
        .output_count = batches * 1,
        .remainder_planks = plank_count % 2,
    };
}

/// 1 Cherry Plank -> 1 Cherry Button.
pub fn craftButton(plank_count: u32) u32 {
    return plank_count;
}

/// 6 Cherry Planks + 1 Stick -> 3 Cherry Signs.
pub fn craftSigns(plank_count: u32, stick_count: u32) struct { signs: u32, remainder_planks: u32, remainder_sticks: u32 } {
    const plank_batches = plank_count / 6;
    const stick_batches = stick_count / 1;
    const batches = @min(plank_batches, stick_batches);
    return .{
        .signs = batches * 3,
        .remainder_planks = plank_count - (batches * 6),
        .remainder_sticks = stick_count - batches,
    };
}

/// 5 Cherry Planks -> 1 Cherry Boat.
pub fn craftBoat(plank_count: u32) struct { boats: u32, remainder_planks: u32 } {
    const batches = plank_count / 5;
    return .{
        .boats = batches,
        .remainder_planks = plank_count % 5,
    };
}

// ============================================================================
// Unit Tests
// ============================================================================

test "constants have expected tags and biome properties" {
    try std.testing.expectEqual(@as(u16, 400), CherryLogTag);
    try std.testing.expectEqual(@as(u16, 401), StrippedCherryLogTag);
    try std.testing.expectEqual(@as(u16, 402), CherryPlanksTag);
    try std.testing.expectEqual(@as(u16, 403), CherryLeavesTag);
    try std.testing.expectEqual(@as(u16, 404), CherrySaplingTag);
    try std.testing.expectEqual(@as(u16, 405), PinkPetalsTag);
    try std.testing.expectEqual(@as(u16, 406), CherrySlabTag);
    try std.testing.expectEqual(@as(u16, 407), CherryStairsTag);
    try std.testing.expectEqual(@as(u16, 408), CherryDoorTag);
    try std.testing.expectEqual(@as(u16, 409), CherryTrapdoorTag);
    try std.testing.expectEqual(@as(u16, 410), CherryFenceTag);
    try std.testing.expectEqual(@as(f32, 0.5), cherry_grove_temperature);
    try std.testing.expectEqual(@as(f32, 0.8), cherry_grove_downfall);
}

test "pink petals cluster initialization stages 1-4 and clamping" {
    const p1 = PinkPetalsCluster.init(10, 64, -20, 1, .north);
    try std.testing.expectEqual(@as(u3, 1), p1.count);
    try std.testing.expectEqual(PetalFacing.north, p1.facing);

    const p4 = PinkPetalsCluster.init(0, 0, 0, 4, .south);
    try std.testing.expectEqual(@as(u3, 4), p4.count);
    try std.testing.expectEqual(PetalFacing.south, p4.facing);

    // Below min clamps to 1
    const p_under = PinkPetalsCluster.init(0, 0, 0, 0, .east);
    try std.testing.expectEqual(@as(u3, 1), p_under.count);

    // Above max clamps to 4
    const p_over = PinkPetalsCluster.init(0, 0, 0, 7, .west);
    try std.testing.expectEqual(@as(u3, 4), p_over.count);
}

test "pink petals stage progression via addPetalToCluster up to max 4" {
    var cluster = PinkPetalsCluster.init(1, 2, 3, 1, .north);
    try std.testing.expectEqual(@as(u3, 1), cluster.count);

    try std.testing.expect(addPetalToCluster(&cluster));
    try std.testing.expectEqual(@as(u3, 2), cluster.count);

    try std.testing.expect(addPetalToCluster(&cluster));
    try std.testing.expectEqual(@as(u3, 3), cluster.count);

    try std.testing.expect(addPetalToCluster(&cluster));
    try std.testing.expectEqual(@as(u3, 4), cluster.count);

    // Cannot add beyond 4
    try std.testing.expect(!addPetalToCluster(&cluster));
    try std.testing.expectEqual(@as(u3, 4), cluster.count);
}

test "pink petals bone meal increments cluster stage below max" {
    var cluster = PinkPetalsCluster.init(5, 70, 5, 1, .north);

    const res1 = applyBoneMealToPetals(&cluster);
    try std.testing.expect(res1.incremented);
    try std.testing.expectEqual(@as(u8, 0), res1.dropped_petals);
    try std.testing.expectEqual(@as(u3, 2), cluster.count);

    const res2 = applyBoneMealToPetals(&cluster);
    try std.testing.expect(res2.incremented);
    try std.testing.expectEqual(@as(u8, 0), res2.dropped_petals);
    try std.testing.expectEqual(@as(u3, 3), cluster.count);

    const res3 = applyBoneMealToPetals(&cluster);
    try std.testing.expect(res3.incremented);
    try std.testing.expectEqual(@as(u8, 0), res3.dropped_petals);
    try std.testing.expectEqual(@as(u3, 4), cluster.count);
}

test "pink petals bone meal at max 4 drops extra petal and keeps stage 4" {
    var cluster = PinkPetalsCluster.init(5, 70, 5, 4, .north);

    const res = applyBoneMealToPetals(&cluster);
    try std.testing.expect(!res.incremented);
    try std.testing.expectEqual(@as(u8, 1), res.dropped_petals);
    try std.testing.expectEqual(@as(u3, 4), cluster.count);

    // Repeated bone meal continues dropping 1 petal while remaining at stage 4
    const res2 = applyBoneMealToPetals(&cluster);
    try std.testing.expect(!res2.incremented);
    try std.testing.expectEqual(@as(u8, 1), res2.dropped_petals);
    try std.testing.expectEqual(@as(u3, 4), cluster.count);
}

test "pink petals harvest yield equals cluster count for all stages 1-4" {
    var stage: u3 = 1;
    while (stage <= 4) : (stage += 1) {
        const cluster = PinkPetalsCluster.init(0, 0, 0, stage, .north);
        try std.testing.expectEqual(@as(u8, stage), harvestPetals(cluster));
        try std.testing.expectEqual(@as(u8, stage), harvestPetalYield(cluster, false));
        try std.testing.expectEqual(@as(u8, stage), harvestPetalYield(cluster, true));
    }
}

test "pink petals planting soil and face orientation constraints" {
    // Valid on soil/moss with hit_ny == 1
    try std.testing.expect(canPlantPetalsOn(true, 1));
    // Invalid on non-soil (e.g. stone/air)
    try std.testing.expect(!canPlantPetalsOn(false, 1));
    // Invalid on side faces or bottom face
    try std.testing.expect(!canPlantPetalsOn(true, 0));
    try std.testing.expect(!canPlantPetalsOn(true, -1));
}

test "cherry sapling planting conditions and growth timing" {
    try std.testing.expect(canPlantSapling(true, 1, 64, 256));
    try std.testing.expect(!canPlantSapling(false, 1, 64, 256));
    try std.testing.expect(!canPlantSapling(true, 0, 64, 256));
    // Clearance check (py + 6 < max_world_height)
    try std.testing.expect(!canPlantSapling(true, 1, 252, 256));

    var sapling = CherrySapling.init(0, 64, 0);
    try std.testing.expect(!sapling.isReady());

    // Insufficient light prevents ticking
    try std.testing.expect(!tickSapling(&sapling, 10.0, 8));
    try std.testing.expectEqual(@as(f32, 0.0), sapling.growth_timer);

    // Sufficient light accumulates growth
    try std.testing.expect(!tickSapling(&sapling, 15.0, 9));
    try std.testing.expectEqual(@as(f32, 15.0), sapling.growth_timer);
    try std.testing.expectEqual(@as(u8, 1), sapling.stage);
    try std.testing.expect(!sapling.isReady());

    // Reaching 30s triggers ready
    try std.testing.expect(tickSapling(&sapling, 15.0, 12));
    try std.testing.expect(sapling.isReady());
}

test "cherry sapling bone meal boosts timer and transitions stage" {
    var sapling = CherrySapling.init(0, 64, 0);

    // Low light blocks bone meal
    try std.testing.expect(!applyBoneMealToSapling(&sapling, 7));
    try std.testing.expectEqual(@as(f32, 0.0), sapling.growth_timer);

    // First boost adds 15s -> stage 1
    try std.testing.expect(applyBoneMealToSapling(&sapling, 10));
    try std.testing.expectEqual(@as(f32, 15.0), sapling.growth_timer);
    try std.testing.expectEqual(@as(u8, 1), sapling.stage);
    try std.testing.expect(!sapling.isReady());

    // Second boost adds 15s -> 30s -> ready
    try std.testing.expect(applyBoneMealToSapling(&sapling, 10));
    try std.testing.expectEqual(@as(f32, 30.0), sapling.growth_timer);
    try std.testing.expect(sapling.isReady());
}

test "procedural cherry tree generator produces curved trunk and branch" {
    var buffer: [128]TreeBlock = undefined;
    const config = TreeConfig{
        .trunk_height = 6,
        .bend_dir_x = 1,
        .bend_dir_z = 0,
        .canopy_radius = 3,
        .has_bee_nest = false,
    };

    const res = generateCherryTree(&buffer, config);
    try std.testing.expect(res.trunk_count == 6);
    try std.testing.expect(res.branch_count >= 2);
    try std.testing.expect(res.leaf_count > 0);
    try std.testing.expect(!res.has_nest);

    // Verify trunk curve: base at dx=0, top trunk bent along +x
    var found_base = false;
    var found_bent = false;
    for (buffer[0..res.count]) |b| {
        if (b.block_type == .trunk_log) {
            if (b.dy == 0 and b.dx == 0) found_base = true;
            if (b.dy >= 3 and b.dx > 0) found_bent = true;
        }
    }
    try std.testing.expect(found_base);
    try std.testing.expect(found_bent);
}

test "procedural cherry tree canopy generates wide flat leaf crown and valid bounds" {
    var buffer: [256]TreeBlock = undefined;
    const config = TreeConfig{
        .trunk_height = 6,
        .bend_dir_x = 0,
        .bend_dir_z = 1,
        .canopy_radius = 4,
        .has_bee_nest = true,
    };

    const res = generateCherryTree(&buffer, config);
    try std.testing.expect(res.has_nest);
    try std.testing.expect(res.leaf_count >= 30);

    // Bounding box dimensions
    const b = res.bounds;
    try std.testing.expect(b.width() >= 7); // canopy radius 4 produces wide disk
    try std.testing.expect(b.depth() >= 7);
    try std.testing.expect(b.height() >= 7);
    try std.testing.expect(b.max_y >= 7);
    try std.testing.expectEqual(@as(i32, 0), b.min_y);
}

test "falling cherry petal particle spawn rate and count calculations" {
    // 50 leaves with 80% air exposure -> effective 40 leaves
    // 40 * 0.08 = 3.2 particles/sec
    const rate = calculatePetalParticleSpawnRate(50, 0.8);
    try std.testing.expectApproxEqAbs(@as(f32, 3.2), rate, 1e-4);

    // Zero air exposure produces zero rate
    try std.testing.expectEqual(@as(f32, 0.0), calculatePetalParticleSpawnRate(50, 0.0));

    // Particle count in dt = 2.0s: floor(3.2 * 2.0) = 6 particles
    try std.testing.expectEqual(@as(u32, 6), calculateParticleSpawnCount(rate, 2.0));
    try std.testing.expectEqual(@as(u32, 0), calculateParticleSpawnCount(rate, 0.0));

    // Stochastic single leaf trigger helper
    try std.testing.expect(shouldSpawnSingleLeafParticle(0.001, 1.0));
    try std.testing.expect(!shouldSpawnSingleLeafParticle(0.999, 1.0));
}

test "cherry wood log stripping with axe" {
    try std.testing.expectEqual(CherryWoodItem.stripped_cherry_log, stripLog(.cherry_log).?);
    try std.testing.expectEqual(@as(?CherryWoodItem, null), stripLog(.stripped_cherry_log));
    try std.testing.expectEqual(@as(?CherryWoodItem, null), stripLog(.cherry_planks));

    try std.testing.expect(canStripWithAxe(true, .cherry_log));
    try std.testing.expect(!canStripWithAxe(false, .cherry_log));
    try std.testing.expect(!canStripWithAxe(true, .stripped_cherry_log));

    try std.testing.expectEqual(@as(?u16, StrippedCherryLogTag), stripLogTag(CherryLogTag));
    try std.testing.expectEqual(@as(?u16, null), stripLogTag(StrippedCherryLogTag));
}

test "cherry planks crafting from logs" {
    try std.testing.expectEqual(@as(u32, 4), planksFromLogs(1));
    try std.testing.expectEqual(@as(u32, 16), planksFromLogs(4));
    try std.testing.expectEqual(@as(u32, 256), planksFromLogs(64));
    try std.testing.expectEqual(@as(u32, 0), planksFromLogs(0));
}

test "cherry slab crafting ratio and plank remainder" {
    // 3 planks -> 6 slabs
    const r1 = craftSlabs(3);
    try std.testing.expectEqual(@as(u32, 6), r1.output_count);
    try std.testing.expectEqual(@as(u32, 0), r1.remainder_planks);

    // 5 planks -> 6 slabs, 2 remainder
    const r2 = craftSlabs(5);
    try std.testing.expectEqual(@as(u32, 6), r2.output_count);
    try std.testing.expectEqual(@as(u32, 2), r2.remainder_planks);

    // 2 planks -> 0 slabs, 2 remainder
    const r3 = craftSlabs(2);
    try std.testing.expectEqual(@as(u32, 0), r3.output_count);
    try std.testing.expectEqual(@as(u32, 2), r3.remainder_planks);
}

test "cherry stairs crafting ratio and plank remainder" {
    // 6 planks -> 4 stairs
    const r1 = craftStairs(6);
    try std.testing.expectEqual(@as(u32, 4), r1.output_count);
    try std.testing.expectEqual(@as(u32, 0), r1.remainder_planks);

    // 14 planks -> 2 batches (8 stairs), 2 remainder
    const r2 = craftStairs(14);
    try std.testing.expectEqual(@as(u32, 8), r2.output_count);
    try std.testing.expectEqual(@as(u32, 2), r2.remainder_planks);
}

test "cherry door and trapdoor crafting conversions" {
    // 6 planks -> 3 doors
    const d1 = craftDoors(6);
    try std.testing.expectEqual(@as(u32, 3), d1.output_count);
    try std.testing.expectEqual(@as(u32, 0), d1.remainder_planks);

    // 13 planks -> 6 doors, 1 remainder
    const d2 = craftDoors(13);
    try std.testing.expectEqual(@as(u32, 6), d2.output_count);
    try std.testing.expectEqual(@as(u32, 1), d2.remainder_planks);

    // 6 planks -> 2 trapdoors
    const t1 = craftTrapdoors(6);
    try std.testing.expectEqual(@as(u32, 2), t1.output_count);
    try std.testing.expectEqual(@as(u32, 0), t1.remainder_planks);

    // 12 planks -> 4 trapdoors
    const t2 = craftTrapdoors(12);
    try std.testing.expectEqual(@as(u32, 4), t2.output_count);
    try std.testing.expectEqual(@as(u32, 0), t2.remainder_planks);
}

test "cherry fence and fence gate crafting with sticks and planks" {
    // 4 planks + 2 sticks -> 3 fences
    const f1 = craftFences(4, 2);
    try std.testing.expectEqual(@as(u32, 3), f1.fences);
    try std.testing.expectEqual(@as(u32, 0), f1.remainder_planks);
    try std.testing.expectEqual(@as(u32, 0), f1.remainder_sticks);

    // 9 planks + 5 sticks -> 2 batches (6 fences), 1 plank rem, 1 stick rem
    const f2 = craftFences(9, 5);
    try std.testing.expectEqual(@as(u32, 6), f2.fences);
    try std.testing.expectEqual(@as(u32, 1), f2.remainder_planks);
    try std.testing.expectEqual(@as(u32, 1), f2.remainder_sticks);

    // 2 planks + 4 sticks -> 1 fence gate
    const g1 = craftFenceGate(2, 4);
    try std.testing.expectEqual(@as(u32, 1), g1.gates);
    try std.testing.expectEqual(@as(u32, 0), g1.remainder_planks);
    try std.testing.expectEqual(@as(u32, 0), g1.remainder_sticks);
}

test "cherry button, pressure plate, sign, and boat crafting" {
    try std.testing.expectEqual(@as(u32, 5), craftButton(5));

    const pp = craftPressurePlate(5);
    try std.testing.expectEqual(@as(u32, 2), pp.output_count);
    try std.testing.expectEqual(@as(u32, 1), pp.remainder_planks);

    const signs = craftSigns(13, 3);
    try std.testing.expectEqual(@as(u32, 6), signs.signs);
    try std.testing.expectEqual(@as(u32, 1), signs.remainder_planks);
    try std.testing.expectEqual(@as(u32, 1), signs.remainder_sticks);

    const boat = craftBoat(11);
    try std.testing.expectEqual(@as(u32, 2), boat.boats);
    try std.testing.expectEqual(@as(u32, 1), boat.remainder_planks);
}

test "edge cases: zero counts and small buffer capacity" {
    // Zero materials craft zero products
    try std.testing.expectEqual(@as(u32, 0), craftSlabs(0).output_count);
    try std.testing.expectEqual(@as(u32, 0), craftStairs(0).output_count);
    try std.testing.expectEqual(@as(u32, 0), craftDoors(0).output_count);
    try std.testing.expectEqual(@as(u32, 0), craftTrapdoors(0).output_count);
    try std.testing.expectEqual(@as(u32, 0), craftFences(0, 0).fences);

    // Buffer smaller than full tree fills safely without overflow
    var small_buf: [4]TreeBlock = undefined;
    const res = generateCherryTree(&small_buf, .{});
    try std.testing.expectEqual(@as(usize, 4), res.count);
}
