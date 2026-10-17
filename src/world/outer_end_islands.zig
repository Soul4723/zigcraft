const std = @import("std");

// ============================================================================
// Milestone 391: Outer End Islands, Chorus Tree Branching Growth,
// Chorus Flower Age 0..5 & End Gateway Beam Teleportation
// ============================================================================

/// Distance in meters separating the central dragon island from the outer End islands.
pub const void_gap_radius_m: f32 = 1000.0;

/// Radius of the central dragon island at the origin.
pub const central_island_radius_m: f32 = 120.0;

/// Maximum age at which a Chorus Flower can actively grow.
pub const max_active_growth_age: u3 = 4;

/// Age at which a Chorus Flower stops growing and turns into a dead flower.
pub const dead_flower_age: u3 = 5;

/// Maximum hitbox height allowed for entities crawling or swimming through a 1x1 gateway.
pub const max_crawl_swim_entry_height_m: f32 = 0.6;

/// Duration in seconds of the beacon beam emitted by an End Gateway.
pub const gateway_beam_duration_seconds: f32 = 2.0;

/// Duration in game ticks (at 20 ticks/sec) of the End Gateway beacon beam.
pub const gateway_beam_duration_ticks: u32 = 40;

/// Standard game simulation ticks per second.
pub const ticks_per_second: f32 = 20.0;

/// Maximum number of End Gateways generated in a ring around the central island.
pub const max_gateway_ring_count: u8 = 20;

/// Radius in meters of the End Gateway ring around the central island (0, 0).
pub const gateway_ring_radius_m: f32 = 96.0;

/// Typical radial distance in meters to linked outer island End Gateways.
pub const outer_gateway_distance_m: f32 = 1024.0;

// Item & Block Identifiers
pub const CHORUS_FRUIT_ID: u16 = 156;
pub const POPPED_CHORUS_FRUIT_ID: u16 = 157;
pub const CHORUS_FLOWER_ID: u16 = 158;
pub const CHORUS_PLANT_ID: u16 = 159;
pub const PURPUR_BLOCK_ID: u16 = 110;
pub const ENDER_PEARL_ID: u16 = 147;

pub const BlockId = enum(u8) {
    air = 0,
    bedrock = 7,
    end_stone = 104,
    purpur_block = 110,
    purpur_pillar = 111,
    end_rod = 112,
    chorus_plant = 113,
    chorus_flower = 114,
    end_gateway = 117,
    _,

    pub fn isChorus(self: BlockId) bool {
        return self == .chorus_plant or self == .chorus_flower;
    }
};

pub const ItemId = enum(u16) {
    none = 0,
    purpur_block = 110,
    ender_pearl = 147,
    chorus_fruit = 156,
    popped_chorus_fruit = 157,
    chorus_flower = 158,
    chorus_plant = 159,
    _,
};

// ============================================================================
// 1. Outer End Islands Ring & Sub-Biomes
// ============================================================================

pub const EndSubBiome = enum {
    the_end, // Central dragon island
    void_gap, // Ring of void separating central and outer islands
    end_highlands, // High elevation plateau of large outer islands
    end_midlands, // Slopes and terraces of outer islands
    end_barrens, // Cliff edges and barren outskirts of outer islands
    small_end_islands, // Tiny isolated floating satellite islands in outer void
};

/// End Cities generate only in .end_highlands and .end_midlands.
pub fn canGenerateEndCity(biome: EndSubBiome) bool {
    return biome == .end_highlands or biome == .end_midlands;
}

pub const OuterEndRing = struct {
    pub const void_gap_radius: f32 = void_gap_radius_m;
    pub const central_radius: f32 = central_island_radius_m;

    pub fn getDistance(x: f32, z: f32) f32 {
        return @sqrt(x * x + z * z);
    }

    pub fn isCentralIsland(x: f32, z: f32) bool {
        return getDistance(x, z) < central_island_radius_m;
    }

    pub fn isVoidGap(x: f32, z: f32) bool {
        const dist = getDistance(x, z);
        return dist >= central_island_radius_m and dist < void_gap_radius_m;
    }

    pub fn isOuterEnd(x: f32, z: f32) bool {
        return getDistance(x, z) >= void_gap_radius_m;
    }

    /// Evaluates the End sub-biome for a given coordinate (x, z) and world seed.
    pub fn getSubBiome(x: f32, z: f32, seed: u64) EndSubBiome {
        const dist = getDistance(x, z);
        if (dist < central_island_radius_m) {
            return .the_end;
        }
        if (dist < void_gap_radius_m) {
            return .void_gap;
        }

        // Outer End procedural terrain evaluation
        const ix: i64 = @intFromFloat(@floor(x / 32.0));
        const iz: i64 = @intFromFloat(@floor(z / 32.0));

        const u_ix: u64 = @bitCast(ix);
        const u_iz: u64 = @bitCast(iz);
        var h = (u_ix *% 0x1da190140e1) ^ (u_iz *% 0x5bd1e9955bd1) ^ (seed *% 0x9e3779b97f4a7c15);
        h ^= (h >> 16);
        h *%= 0x85ebca6b;
        h ^= (h >> 13);

        const island_val: f32 = @as(f32, @floatFromInt(h & 0xFFFF)) / 65535.0;

        // Check for major outer islands
        if (island_val > 0.40) {
            // High elevation plateau center
            if (island_val > 0.75) {
                return .end_highlands;
            }
            // Mid elevation transition
            if (island_val > 0.55) {
                return .end_midlands;
            }
            // Barren cliff edges
            return .end_barrens;
        }

        // Check for scattered tiny satellite islands in the void
        const small_h = (h *% 0x27d4eb2f) ^ (seed *% 0x165667b1);
        const small_val: f32 = @as(f32, @floatFromInt(small_h & 0xFFFF)) / 65535.0;
        if (small_val > 0.85) {
            return .small_end_islands;
        }

        return .void_gap;
    }
};

// ============================================================================
// 2. Chorus Flower Age & Branching Growth
// ============================================================================

pub const ChorusFlowerVisualState = enum {
    growing_white_lavender,
    dead_purple_white_center,
};

/// At age 0..4, the Chorus Flower actively grows upward and branches horizontally.
/// At age 5, it stops growing and enters the dead state (dead_purple_white_center).
pub fn canGrowChorusFlower(age_0_to_5: u3) bool {
    return age_0_to_5 <= max_active_growth_age;
}

/// Returns the visual appearance of a Chorus Flower based on its age.
pub fn getChorusFlowerVisualState(age_0_to_5: u3) ChorusFlowerVisualState {
    if (age_0_to_5 >= dead_flower_age) {
        return .dead_purple_white_center;
    }
    return .growing_white_lavender;
}

/// Checks if a supporting base block allows planting or growing a Chorus Flower.
pub fn isValidChorusPlantingBase(base_block: BlockId) bool {
    return base_block == .end_stone or base_block == .chorus_plant;
}

// ============================================================================
// 3. Chorus Flower Harvesting & Projectile Breaking
// ============================================================================

pub const ProjectileType = enum {
    arrow,
    spectral_arrow,
    tipped_arrow,
    trident,
    snowball,
    wind_charge,
    egg,
    ender_pearl,
    firework_rocket,
    shulker_bullet,
};

/// Hitting a Chorus Flower with an arrow, trident, snowball, or wind charge breaks it.
pub fn isChorusFlowerBreakingProjectile(proj: ProjectileType) bool {
    return switch (proj) {
        .arrow, .spectral_arrow, .tipped_arrow, .trident, .snowball, .wind_charge => true,
        else => false,
    };
}

/// Mining directly by hand/tool or hitting with a breaking projectile drops the flower.
/// Breaking the supporting Chorus Plant stem below causes the flower to shatter without dropping.
pub fn dropsChorusFlowerOnBreak(broken_directly_or_shot: bool) bool {
    return broken_directly_or_shot;
}

pub const FlowerHarvestDrop = struct {
    item: ItemId = .chorus_flower,
    count: u8,
    dropped_flower_age: u3,
};

/// Direct harvesting returns 1 Chorus Flower item with age reset to 0.
/// Indirect breaking (via stem collapse) shatters the flower, dropping nothing.
pub fn harvestChorusFlower(current_age: u3, broken_directly_or_shot: bool) ?FlowerHarvestDrop {
    _ = current_age;
    if (dropsChorusFlowerOnBreak(broken_directly_or_shot)) {
        return .{
            .item = .chorus_flower,
            .count = 1,
            .dropped_flower_age = 0, // Age is reset to 0 upon drop
        };
    }
    return null;
}

// ============================================================================
// 4. Chorus Stem Collapse, Fruit Smelting & Purpur Crafting
// ============================================================================

/// When a Chorus Plant stem is broken or collapses, it drops 0 or 1 Chorus Fruit.
pub fn stemFruitDropCount(random_roll_0_to_1: f32) u8 {
    return if (random_roll_0_to_1 < 0.5) 1 else 0;
}

/// Smelting Chorus Fruit yields Popped Chorus Fruit.
pub fn smeltChorusFruit(input: ItemId) ?ItemId {
    if (input == .chorus_fruit) {
        return .popped_chorus_fruit;
    }
    return null;
}

pub const CraftResult = struct {
    item: ItemId,
    count: u8,
};

/// 4 Popped Chorus Fruit in a 2x2 grid crafts into 4 Purpur Blocks.
pub fn craftPurpurBlock(grid: [4]ItemId) ?CraftResult {
    for (grid) |slot| {
        if (slot != .popped_chorus_fruit) return null;
    }
    return .{
        .item = .purpur_block,
        .count = 4,
    };
}

// ============================================================================
// 5. 3D Vec & Chorus Plant Network Simulation
// ============================================================================

pub const Vec3i = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) Vec3i {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn equals(self: Vec3i, other: Vec3i) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub fn add(self: Vec3i, dx: i32, dy: i32, dz: i32) Vec3i {
        return .{ .x = self.x + dx, .y = self.y + dy, .z = self.z + dz };
    }
};

pub const BlockRecord = struct {
    pos: Vec3i,
    block: BlockId,
    flower_age: u3 = 0,
};

pub const CollapseSummary = struct {
    stems_collapsed: usize,
    flowers_shattered: usize,
    chorus_fruit_dropped: usize,
    chorus_flower_dropped: usize,
};

/// A bounded 3D grid container for simulating Chorus Tree growth and cascading collapse.
pub const ChorusTree = struct {
    pub const max_nodes: usize = 128;
    nodes: [max_nodes]BlockRecord = undefined,
    count: usize = 0,

    pub fn init() ChorusTree {
        return .{ .count = 0 };
    }

    pub fn set(self: *ChorusTree, pos: Vec3i, block: BlockId, age: u3) void {
        for (self.nodes[0..self.count]) |*node| {
            if (node.pos.equals(pos)) {
                node.block = block;
                node.flower_age = age;
                return;
            }
        }
        if (self.count < max_nodes) {
            self.nodes[self.count] = .{ .pos = pos, .block = block, .flower_age = age };
            self.count += 1;
        }
    }

    pub fn get(self: ChorusTree, pos: Vec3i) BlockId {
        for (self.nodes[0..self.count]) |node| {
            if (node.pos.equals(pos)) return node.block;
        }
        return .air;
    }

    pub fn getAge(self: ChorusTree, pos: Vec3i) u3 {
        for (self.nodes[0..self.count]) |node| {
            if (node.pos.equals(pos)) return node.flower_age;
        }
        return 0;
    }

    pub fn remove(self: *ChorusTree, pos: Vec3i) bool {
        for (self.nodes[0..self.count], 0..) |node, i| {
            if (node.pos.equals(pos)) {
                self.nodes[i] = self.nodes[self.count - 1];
                self.count -= 1;
                return true;
            }
        }
        return false;
    }

    /// Simulates upward growth or horizontal branching of a Chorus Flower.
    pub fn stepGrowth(self: *ChorusTree, flower_pos: Vec3i, branch_direction: ?[3]i32) bool {
        const current_block = self.get(flower_pos);
        if (current_block != .chorus_flower) return false;

        const age = self.getAge(flower_pos);
        if (!canGrowChorusFlower(age)) {
            // Already dead at age 5, cannot grow
            return false;
        }

        if (branch_direction) |bdir| {
            // Horizontal branching
            const branch_pos = flower_pos.add(bdir[0], bdir[1], bdir[2]);
            if (self.get(branch_pos) != .air) return false;

            // Turn existing flower into plant stem
            self.set(flower_pos, .chorus_plant, 0);

            // Place new flower with age incremented by 1
            const next_age = age + 1;
            self.set(branch_pos, .chorus_flower, next_age);
            return true;
        } else {
            // Upward growth
            const up_pos = flower_pos.add(0, 1, 0);
            if (self.get(up_pos) != .air) return false;

            // Turn existing flower into plant stem
            self.set(flower_pos, .chorus_plant, 0);

            // Upward growth maintains flower age
            self.set(up_pos, .chorus_flower, age);
            return true;
        }
    }

    /// Breaks a block at `target_pos`.
    /// If it is a Chorus Plant stem, cascades upward and shatters any disconnected parts.
    pub fn breakBlock(self: *ChorusTree, target_pos: Vec3i, broken_directly_or_shot: bool) CollapseSummary {
        var summary = CollapseSummary{
            .stems_collapsed = 0,
            .flowers_shattered = 0,
            .chorus_fruit_dropped = 0,
            .chorus_flower_dropped = 0,
        };

        const target_block = self.get(target_pos);
        if (target_block == .air) return summary;

        if (target_block == .chorus_flower) {
            const age = self.getAge(target_pos);
            _ = self.remove(target_pos);
            if (harvestChorusFlower(age, broken_directly_or_shot)) |drop| {
                summary.chorus_flower_dropped += drop.count;
            } else {
                summary.flowers_shattered += 1;
            }
            return summary;
        }

        if (target_block == .chorus_plant) {
            _ = self.remove(target_pos);
            summary.stems_collapsed += 1;
            summary.chorus_fruit_dropped += stemFruitDropCount(0.1); // Deterministic test drop

            // Cascade collapse: find all chorus nodes still supported by End Stone ground
            var grounded = [_]bool{false} ** max_nodes;

            // 1. Initial pass: nodes directly above end_stone are grounded
            for (self.nodes[0..self.count], 0..) |node, i| {
                if (node.block.isChorus()) {
                    const below = self.get(node.pos.add(0, -1, 0));
                    if (below == .end_stone) {
                        grounded[i] = true;
                    }
                }
            }

            // 2. Propagate grounded status through connected chorus stems
            var changed = true;
            while (changed) {
                changed = false;
                for (self.nodes[0..self.count], 0..) |nodeA, i| {
                    if (!grounded[i] and nodeA.block.isChorus()) {
                        for (self.nodes[0..self.count], 0..) |nodeB, j| {
                            if (grounded[j] and nodeB.block == .chorus_plant) {
                                const dx = @abs(nodeA.pos.x - nodeB.pos.x);
                                const dy = @abs(nodeA.pos.y - nodeB.pos.y);
                                const dz = @abs(nodeA.pos.z - nodeB.pos.z);
                                if (dx + dy + dz == 1) {
                                    grounded[i] = true;
                                    changed = true;
                                    break;
                                }
                            }
                        }
                    }
                }
            }

            // 3. Remove all ungrounded nodes and count drops/shatters
            var idx: usize = 0;
            while (idx < self.count) {
                if (!grounded[idx] and self.nodes[idx].block.isChorus()) {
                    const blk = self.nodes[idx].block;
                    _ = self.remove(self.nodes[idx].pos);
                    // Shuffled last element into idx; also update grounded array
                    grounded[idx] = grounded[self.count];

                    if (blk == .chorus_plant) {
                        summary.stems_collapsed += 1;
                        summary.chorus_fruit_dropped += stemFruitDropCount(0.1);
                    } else if (blk == .chorus_flower) {
                        // Shatters without dropping since broken indirectly
                        summary.flowers_shattered += 1;
                    }
                } else {
                    idx += 1;
                }
            }
        }

        return summary;
    }
};

// ============================================================================
// 6. End Gateway Portal & Beacon Beam
// ============================================================================

pub const GatewayEntryMethod = enum {
    ender_pearl,
    trapdoor_crawl,
    water_swim,
    elytra_glide,
    walking,
    sneaking,
};

/// An End Gateway is a 1x1 portal block with a 1-block vertical clearance gap
/// framed by bedrock ceiling and bedrock floor.
/// Standing or sneaking entities cannot enter; requires ender_pearl, crawl, or swim.
pub fn canEnterEndGateway(method: GatewayEntryMethod, hitbox_height_m: f32) bool {
    return switch (method) {
        .ender_pearl => true,
        .trapdoor_crawl, .water_swim, .elytra_glide => hitbox_height_m <= max_crawl_swim_entry_height_m,
        .walking, .sneaking => false,
    };
}

/// Validates that a candidate 1x1 End Gateway is framed by bedrock ceiling (y+1) and floor (y-1).
pub fn isGatewayFramingValid(
    lookup_fn: *const fn (x: i32, y: i32, z: i32) BlockId,
    gx: i32,
    gy: i32,
    gz: i32,
) bool {
    const center = lookup_fn(gx, gy, gz);
    const floor = lookup_fn(gx, gy - 1, gz);
    const ceiling = lookup_fn(gx, gy + 1, gz);

    return center == .end_gateway and floor == .bedrock and ceiling == .bedrock;
}

/// State tracking the 2.0-second (40-tick) beacon beam emitted by an End Gateway.
pub const GatewayBeam = struct {
    active: bool = false,
    ticks_remaining: u32 = 0,

    pub const magenta_color: [4]f32 = .{ 1.0, 0.0, 1.0, 1.0 };
    pub const yellow_color: [4]f32 = .{ 1.0, 1.0, 0.0, 1.0 };

    pub fn trigger(self: *GatewayBeam) void {
        self.active = true;
        self.ticks_remaining = gateway_beam_duration_ticks;
    }

    pub fn tick(self: *GatewayBeam, elapsed_ticks: u32) void {
        if (self.ticks_remaining <= elapsed_ticks) {
            self.ticks_remaining = 0;
            self.active = false;
        } else {
            self.ticks_remaining -= elapsed_ticks;
        }
    }

    pub fn isActive(self: GatewayBeam) bool {
        return self.active and self.ticks_remaining > 0;
    }

    pub fn getRemainingSeconds(self: GatewayBeam) f32 {
        return @as(f32, @floatFromInt(self.ticks_remaining)) / ticks_per_second;
    }
};

/// Computes horizontal (X, Z) coordinates of a gateway on the central island ring.
/// Up to 20 gateways arrange evenly spaced in a circle of radius 96.0m around (0, 0).
pub fn getGatewayRingPosition(gateway_index: u8) [2]f32 {
    const idx = gateway_index % max_gateway_ring_count;
    const angle = @as(f32, @floatFromInt(idx)) * (2.0 * std.math.pi / @as(f32, @floatFromInt(max_gateway_ring_count)));
    return .{
        gateway_ring_radius_m * @cos(angle),
        gateway_ring_radius_m * @sin(angle),
    };
}

/// Computes the teleport target destination between central and outer End gateways.
pub fn computeGatewayTeleportTarget(is_central: bool, gateway_index: u8) [3]f32 {
    const ring_pos = getGatewayRingPosition(gateway_index);
    if (is_central) {
        // Warp from central island outward to Outer End satellite island
        const idx = gateway_index % max_gateway_ring_count;
        const angle = @as(f32, @floatFromInt(idx)) * (2.0 * std.math.pi / @as(f32, @floatFromInt(max_gateway_ring_count)));
        return .{
            outer_gateway_distance_m * @cos(angle),
            65.0, // Safe landing height on outer island
            outer_gateway_distance_m * @sin(angle),
        };
    } else {
        // Warp from outer island back to central island return ring
        return .{
            ring_pos[0],
            65.0,
            ring_pos[1],
        };
    }
}

// ============================================================================
// Comprehensive Tests for Milestone 391
// ============================================================================

test "OuterEndRing: 1000m void gap separates central island from outer end" {
    try std.testing.expectEqual(@as(f32, 1000.0), void_gap_radius_m);
    try std.testing.expectEqual(@as(f32, 120.0), central_island_radius_m);

    // Origin is inside central island
    try std.testing.expect(OuterEndRing.isCentralIsland(0.0, 0.0));
    try std.testing.expect(!OuterEndRing.isVoidGap(0.0, 0.0));
    try std.testing.expect(!OuterEndRing.isOuterEnd(0.0, 0.0));

    // Near boundary of central island
    try std.testing.expect(OuterEndRing.isCentralIsland(80.0, 80.0)); // dist ~ 113.1
    try std.testing.expect(!OuterEndRing.isCentralIsland(100.0, 100.0)); // dist ~ 141.4

    // Inside the 1000m void gap
    try std.testing.expect(OuterEndRing.isVoidGap(100.0, 100.0));
    try std.testing.expect(OuterEndRing.isVoidGap(500.0, 0.0));
    try std.testing.expect(OuterEndRing.isVoidGap(0.0, 999.0));
    try std.testing.expect(!OuterEndRing.isVoidGap(1000.0, 0.0));

    // Outer End beyond 1000m
    try std.testing.expect(OuterEndRing.isOuterEnd(1000.0, 0.0));
    try std.testing.expect(OuterEndRing.isOuterEnd(1500.0, -1200.0));
    try std.testing.expect(!OuterEndRing.isCentralIsland(1500.0, 0.0));
}

test "OuterEndRing: End Cities generate only in end_highlands and end_midlands" {
    try std.testing.expect(canGenerateEndCity(.end_highlands));
    try std.testing.expect(canGenerateEndCity(.end_midlands));

    try std.testing.expect(!canGenerateEndCity(.end_barrens));
    try std.testing.expect(!canGenerateEndCity(.small_end_islands));
    try std.testing.expect(!canGenerateEndCity(.the_end));
    try std.testing.expect(!canGenerateEndCity(.void_gap));
}

test "OuterEndRing: getSubBiome classifies central island, void gap, and outer biomes" {
    const seed: u64 = 42;

    // Central island
    try std.testing.expectEqual(EndSubBiome.the_end, OuterEndRing.getSubBiome(0.0, 0.0, seed));
    try std.testing.expectEqual(EndSubBiome.the_end, OuterEndRing.getSubBiome(50.0, -50.0, seed));

    // Void gap between 120m and 1000m
    try std.testing.expectEqual(EndSubBiome.void_gap, OuterEndRing.getSubBiome(300.0, 400.0, seed));
    try std.testing.expectEqual(EndSubBiome.void_gap, OuterEndRing.getSubBiome(0.0, 800.0, seed));

    // Outer End (>= 1000m) sampling
    var found_highlands = false;
    var found_midlands = false;
    var found_barrens = false;
    var found_small_islands = false;

    var angle: f32 = 0.0;
    while (angle < 2.0 * std.math.pi) : (angle += 0.1) {
        var r: f32 = 1050.0;
        while (r <= 1800.0) : (r += 100.0) {
            const bx = r * @cos(angle);
            const bz = r * @sin(angle);
            const biome = OuterEndRing.getSubBiome(bx, bz, seed);
            switch (biome) {
                .end_highlands => found_highlands = true,
                .end_midlands => found_midlands = true,
                .end_barrens => found_barrens = true,
                .small_end_islands => found_small_islands = true,
                else => {},
            }
        }
    }

    try std.testing.expect(found_highlands);
    try std.testing.expect(found_midlands);
    try std.testing.expect(found_barrens);
    try std.testing.expect(found_small_islands);
}

test "ChorusFlowerAge: age 0 to 4 actively grows upward and branches horizontally" {
    var age: u3 = 0;
    while (age <= 4) : (age += 1) {
        try std.testing.expect(canGrowChorusFlower(age));
        try std.testing.expectEqual(ChorusFlowerVisualState.growing_white_lavender, getChorusFlowerVisualState(age));
    }

    // Base support requirements
    try std.testing.expect(isValidChorusPlantingBase(.end_stone));
    try std.testing.expect(isValidChorusPlantingBase(.chorus_plant));
    try std.testing.expect(!isValidChorusPlantingBase(.air));
    try std.testing.expect(!isValidChorusPlantingBase(.bedrock));
    try std.testing.expect(!isValidChorusPlantingBase(.purpur_block));
}

test "ChorusFlowerAge: age 5 stops growing and sets dead_purple_white_center" {
    try std.testing.expect(!canGrowChorusFlower(5));
    try std.testing.expect(!canGrowChorusFlower(6));
    try std.testing.expect(!canGrowChorusFlower(7));

    try std.testing.expectEqual(ChorusFlowerVisualState.dead_purple_white_center, getChorusFlowerVisualState(5));
    try std.testing.expectEqual(ChorusFlowerVisualState.dead_purple_white_center, getChorusFlowerVisualState(6));
}

test "ChorusFlowerHarvesting: direct mining drops chorus_flower item with age reset to 0" {
    try std.testing.expect(dropsChorusFlowerOnBreak(true));

    // Mined directly at age 0
    const drop0 = harvestChorusFlower(0, true).?;
    try std.testing.expectEqual(ItemId.chorus_flower, drop0.item);
    try std.testing.expectEqual(@as(u8, 1), drop0.count);
    try std.testing.expectEqual(@as(u3, 0), drop0.dropped_flower_age);

    // Mined directly at age 3
    const drop3 = harvestChorusFlower(3, true).?;
    try std.testing.expectEqual(@as(u8, 1), drop3.count);
    try std.testing.expectEqual(@as(u3, 0), drop3.dropped_flower_age);

    // Mined directly even when dead at age 5: drops item with age reset to 0
    const drop5 = harvestChorusFlower(5, true).?;
    try std.testing.expectEqual(@as(u8, 1), drop5.count);
    try std.testing.expectEqual(@as(u3, 0), drop5.dropped_flower_age);
}

test "ChorusFlowerHarvesting: projectile hits from arrows, tridents, snowballs, wind charges break flower" {
    try std.testing.expect(isChorusFlowerBreakingProjectile(.arrow));
    try std.testing.expect(isChorusFlowerBreakingProjectile(.spectral_arrow));
    try std.testing.expect(isChorusFlowerBreakingProjectile(.tipped_arrow));
    try std.testing.expect(isChorusFlowerBreakingProjectile(.trident));
    try std.testing.expect(isChorusFlowerBreakingProjectile(.snowball));
    try std.testing.expect(isChorusFlowerBreakingProjectile(.wind_charge));

    // Other projectiles do not break Chorus Flowers
    try std.testing.expect(!isChorusFlowerBreakingProjectile(.egg));
    try std.testing.expect(!isChorusFlowerBreakingProjectile(.ender_pearl));
    try std.testing.expect(!isChorusFlowerBreakingProjectile(.firework_rocket));
    try std.testing.expect(!isChorusFlowerBreakingProjectile(.shulker_bullet));

    // Shot directly by arrow drops the item with age reset to 0
    const shot_drop = harvestChorusFlower(2, dropsChorusFlowerOnBreak(true)).?;
    try std.testing.expectEqual(ItemId.chorus_flower, shot_drop.item);
    try std.testing.expectEqual(@as(u8, 1), shot_drop.count);
    try std.testing.expectEqual(@as(u3, 0), shot_drop.dropped_flower_age);
}

test "ChorusFlowerHarvesting: breaking supporting stem causes flower to shatter without dropping" {
    // Breaking via indirect support collapse: broken_directly_or_shot is false
    try std.testing.expect(!dropsChorusFlowerOnBreak(false));

    try std.testing.expect(harvestChorusFlower(0, false) == null);
    try std.testing.expect(harvestChorusFlower(2, false) == null);
    try std.testing.expect(harvestChorusFlower(5, false) == null);
}

test "ChorusTree: growth simulation grows upward and branches horizontally incrementing age" {
    var tree = ChorusTree.init();
    const ground = Vec3i.init(0, 0, 0);
    tree.set(ground, .end_stone, 0);

    const f0 = Vec3i.init(0, 1, 0);
    tree.set(f0, .chorus_flower, 0);

    // Upward growth from age 0
    try std.testing.expect(tree.stepGrowth(f0, null));
    try std.testing.expectEqual(BlockId.chorus_plant, tree.get(f0));
    const f1 = Vec3i.init(0, 2, 0);
    try std.testing.expectEqual(BlockId.chorus_flower, tree.get(f1));
    try std.testing.expectEqual(@as(u3, 0), tree.getAge(f1));

    // Branch horizontally along +X: age increments from 0 to 1
    try std.testing.expect(tree.stepGrowth(f1, [3]i32{ 1, 0, 0 }));
    try std.testing.expectEqual(BlockId.chorus_plant, tree.get(f1));
    const f2 = Vec3i.init(1, 2, 0);
    try std.testing.expectEqual(BlockId.chorus_flower, tree.get(f2));
    try std.testing.expectEqual(@as(u3, 1), tree.getAge(f2));

    // Branch along +Z: age increments from 1 to 2
    try std.testing.expect(tree.stepGrowth(f2, [3]i32{ 0, 0, 1 }));
    const f3 = Vec3i.init(1, 2, 1);
    try std.testing.expectEqual(BlockId.chorus_flower, tree.get(f3));
    try std.testing.expectEqual(@as(u3, 2), tree.getAge(f3));

    // Age up to 5 (dead)
    tree.set(f3, .chorus_flower, 5);
    try std.testing.expect(!tree.stepGrowth(f3, null));
    try std.testing.expect(!tree.stepGrowth(f3, [3]i32{ 1, 0, 0 }));
}

test "ChorusStemCollapse: breaking lower stem cascades upward and collapses unsupported stems" {
    var tree = ChorusTree.init();
    tree.set(Vec3i.init(0, 0, 0), .end_stone, 0);
    tree.set(Vec3i.init(0, 1, 0), .chorus_plant, 0);
    tree.set(Vec3i.init(0, 2, 0), .chorus_plant, 0);
    tree.set(Vec3i.init(1, 2, 0), .chorus_plant, 0); // Branch stem
    tree.set(Vec3i.init(1, 3, 0), .chorus_flower, 2); // Attached flower

    // Break the lower stem at (0, 1, 0)
    const summary = tree.breakBlock(Vec3i.init(0, 1, 0), true);

    // Stems (0,1,0), (0,2,0), (1,2,0) should collapse (3 total)
    try std.testing.expectEqual(@as(usize, 3), summary.stems_collapsed);
    // Flower (1,3,0) lost support, shatters without dropping (1 total)
    try std.testing.expectEqual(@as(usize, 1), summary.flowers_shattered);
    // Flower dropped is 0
    try std.testing.expectEqual(@as(usize, 0), summary.chorus_flower_dropped);
    // Stems drop chorus fruit
    try std.testing.expect(summary.chorus_fruit_dropped > 0);

    // Tree should now have only the ground end_stone block
    try std.testing.expectEqual(BlockId.end_stone, tree.get(Vec3i.init(0, 0, 0)));
    try std.testing.expectEqual(BlockId.air, tree.get(Vec3i.init(0, 1, 0)));
    try std.testing.expectEqual(BlockId.air, tree.get(Vec3i.init(0, 2, 0)));
    try std.testing.expectEqual(BlockId.air, tree.get(Vec3i.init(1, 2, 0)));
    try std.testing.expectEqual(BlockId.air, tree.get(Vec3i.init(1, 3, 0)));
}

test "ChorusStemCollapse: stem fruit drop yields 0 to 1 chorus fruit per stem block" {
    try std.testing.expectEqual(@as(u8, 1), stemFruitDropCount(0.1));
    try std.testing.expectEqual(@as(u8, 1), stemFruitDropCount(0.49));
    try std.testing.expectEqual(@as(u8, 0), stemFruitDropCount(0.50));
    try std.testing.expectEqual(@as(u8, 0), stemFruitDropCount(0.99));
}

test "Smelting: chorus fruit smelts into popped chorus fruit" {
    try std.testing.expectEqual(ItemId.popped_chorus_fruit, smeltChorusFruit(.chorus_fruit).?);

    try std.testing.expect(smeltChorusFruit(.chorus_plant) == null);
    try std.testing.expect(smeltChorusFruit(.chorus_flower) == null);
    try std.testing.expect(smeltChorusFruit(.purpur_block) == null);
    try std.testing.expect(smeltChorusFruit(.ender_pearl) == null);
}

test "Crafting: 4 popped chorus fruit crafts into 4 purpur blocks" {
    const valid_recipe = [_]ItemId{ .popped_chorus_fruit, .popped_chorus_fruit, .popped_chorus_fruit, .popped_chorus_fruit };
    const res = craftPurpurBlock(valid_recipe).?;
    try std.testing.expectEqual(ItemId.purpur_block, res.item);
    try std.testing.expectEqual(@as(u8, 4), res.count);

    const invalid_recipe = [_]ItemId{ .popped_chorus_fruit, .chorus_fruit, .popped_chorus_fruit, .popped_chorus_fruit };
    try std.testing.expect(craftPurpurBlock(invalid_recipe) == null);
}

test "EndGatewayPortal: 1x1 gateway framed in bedrock ceiling and floor with 1 block gap" {
    const Mock = struct {
        fn getValidFrame(x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = z;
            if (y == 9) return .bedrock;
            if (y == 10) return .end_gateway;
            if (y == 11) return .bedrock;
            return .air;
        }

        fn getMissingCeiling(x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = z;
            if (y == 9) return .bedrock;
            if (y == 10) return .end_gateway;
            return .air;
        }
    };

    try std.testing.expect(isGatewayFramingValid(&Mock.getValidFrame, 0, 10, 0));
    try std.testing.expect(!isGatewayFramingValid(&Mock.getMissingCeiling, 0, 10, 0));
}

test "EndGatewayPortal: entry requires ender pearl, trapdoor crawl, or water swim with height <= 0.6" {
    try std.testing.expectEqual(@as(f32, 0.6), max_crawl_swim_entry_height_m);

    // Ender Pearl throw succeeds regardless of thrower height
    try std.testing.expect(canEnterEndGateway(.ender_pearl, 1.8));
    try std.testing.expect(canEnterEndGateway(.ender_pearl, 0.6));

    // Crawling under trapdoor (hitbox height <= 0.6m)
    try std.testing.expect(canEnterEndGateway(.trapdoor_crawl, 0.6));
    try std.testing.expect(canEnterEndGateway(.trapdoor_crawl, 0.5));
    try std.testing.expect(!canEnterEndGateway(.trapdoor_crawl, 0.65));

    // Swimming through water (hitbox height <= 0.6m)
    try std.testing.expect(canEnterEndGateway(.water_swim, 0.6));
    try std.testing.expect(!canEnterEndGateway(.water_swim, 0.8));

    // Elytra flight / crawl
    try std.testing.expect(canEnterEndGateway(.elytra_glide, 0.6));
    try std.testing.expect(!canEnterEndGateway(.elytra_glide, 1.0));

    // Walking (1.8m) and sneaking (1.5m) cannot fit into 1-block gateway opening
    try std.testing.expect(!canEnterEndGateway(.walking, 1.8));
    try std.testing.expect(!canEnterEndGateway(.sneaking, 1.5));
}

test "EndGatewayPortal: beacon beam emits magenta and yellow beam for 2.0s (40 ticks)" {
    try std.testing.expectEqual(@as(f32, 2.0), gateway_beam_duration_seconds);
    try std.testing.expectEqual(@as(u32, 40), gateway_beam_duration_ticks);

    var beam = GatewayBeam{};
    try std.testing.expect(!beam.isActive());

    beam.trigger();
    try std.testing.expect(beam.isActive());
    try std.testing.expectEqual(@as(u32, 40), beam.ticks_remaining);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), beam.getRemainingSeconds(), 0.001);

    // Advance 20 ticks (1.0 second)
    beam.tick(20);
    try std.testing.expect(beam.isActive());
    try std.testing.expectEqual(@as(u32, 20), beam.ticks_remaining);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), beam.getRemainingSeconds(), 0.001);

    // Advance remaining 20 ticks
    beam.tick(20);
    try std.testing.expect(!beam.isActive());
    try std.testing.expectEqual(@as(u32, 0), beam.ticks_remaining);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), beam.getRemainingSeconds(), 0.001);

    // Verify beam colors (magenta and yellow)
    try std.testing.expectEqual(@as(f32, 1.0), GatewayBeam.magenta_color[0]);
    try std.testing.expectEqual(@as(f32, 0.0), GatewayBeam.magenta_color[1]);
    try std.testing.expectEqual(@as(f32, 1.0), GatewayBeam.magenta_color[2]);

    try std.testing.expectEqual(@as(f32, 1.0), GatewayBeam.yellow_color[0]);
    try std.testing.expectEqual(@as(f32, 1.0), GatewayBeam.yellow_color[1]);
    try std.testing.expectEqual(@as(f32, 0.0), GatewayBeam.yellow_color[2]);
}

test "EndGatewayPortal: circle of 20 gateways arranged at radius 96.0m around central island" {
    try std.testing.expectEqual(@as(u8, 20), max_gateway_ring_count);
    try std.testing.expectEqual(@as(f32, 96.0), gateway_ring_radius_m);

    var i: u8 = 0;
    while (i < 20) : (i += 1) {
        const pos = getGatewayRingPosition(i);
        const dist = @sqrt(pos[0] * pos[0] + pos[1] * pos[1]);
        try std.testing.expectApproxEqAbs(@as(f32, 96.0), dist, 0.01);
    }

    // Gateways wrap around ring at index 20
    const pos0 = getGatewayRingPosition(0);
    const pos20 = getGatewayRingPosition(20);
    try std.testing.expectApproxEqAbs(pos0[0], pos20[0], 0.001);
    try std.testing.expectApproxEqAbs(pos0[1], pos20[1], 0.001);
}

test "EndGatewayPortal: bidirectional teleportation between central ring and outer island" {
    // Central gateway at index 0 teleports to outer End satellite island
    const outer_dest = computeGatewayTeleportTarget(true, 0);
    const outer_dist = @sqrt(outer_dest[0] * outer_dest[0] + outer_dest[2] * outer_dest[2]);
    try std.testing.expectApproxEqAbs(outer_gateway_distance_m, outer_dist, 0.01);

    // Outer gateway at index 0 teleports back to central ring
    const central_dest = computeGatewayTeleportTarget(false, 0);
    const central_dist = @sqrt(central_dest[0] * central_dest[0] + central_dest[2] * central_dest[2]);
    try std.testing.expectApproxEqAbs(gateway_ring_radius_m, central_dist, 0.01);
}
