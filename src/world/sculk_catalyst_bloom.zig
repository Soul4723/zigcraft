const std = @import("std");

// ============================================================================
// 1. Constants & Tuning Parameters
// ============================================================================

/// Detection radius in blocks within which a mob death activates a Sculk Catalyst.
pub const catalyst_radius: f32 = 8.0;

/// Squared detection radius for Euclidean distance checks (avoiding square root).
pub const catalyst_radius_sq: f32 = catalyst_radius * catalyst_radius; // 64.0

/// Maximum Manhattan distance in blocks for Manhattan radius checks.
pub const catalyst_manhattan_radius: i32 = 8;

/// Ambient light level emitted by a dormant Sculk Catalyst (0 = no light).
pub const light_level_dormant: u4 = 0;

/// Ambient light level emitted by an active / blooming Sculk Catalyst (light level 6).
pub const light_level_blooming: u4 = 6;

/// Ambient emissive shader intensity when dormant (0.0).
pub const emissive_dormant: f32 = 0.0;

/// Ambient emissive shader intensity when blooming (6 / 15 = 0.40).
pub const emissive_blooming: f32 = 6.0 / 15.0;

/// Default duration in game ticks that a catalyst remains in the blooming state.
pub const default_bloom_ticks: u32 = 20;

/// Charge consumed per converted substrate block (1 charge unit = 1 block).
pub const charge_decay_per_block: u32 = 1;

/// Maximum number of active charges a single catalyst tracks concurrently.
pub const max_active_charges: usize = 32;

/// Maximum number of sculk catalysts tracked in a world collection.
pub const max_tracked_catalysts: usize = 64;

// ============================================================================
// 2. Spatial Data Types & Directions
// ============================================================================

/// Cardinal and vertical 3D directions for grid traversal and charge propagation.
pub const Direction = enum(u3) {
    up = 0,
    down = 1,
    north = 2,
    south = 3,
    east = 4,
    west = 5,

    pub const all: [6]Direction = .{ .up, .down, .north, .south, .east, .west };

    pub fn getOffset(self: Direction) [3]i32 {
        return switch (self) {
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
        };
    }
};

/// 3D integer block coordinate with distance metrics and neighbor queries.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) BlockPos {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn equals(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub fn addOffset(self: BlockPos, dx: i32, dy: i32, dz: i32) BlockPos {
        return .{ .x = self.x + dx, .y = self.y + dy, .z = self.z + dz };
    }

    pub fn adjacent(self: BlockPos, dir: Direction) BlockPos {
        const off = dir.getOffset();
        return self.addOffset(off[0], off[1], off[2]);
    }

    pub fn neighbors(self: BlockPos) [6]BlockPos {
        return .{
            self.adjacent(.up),
            self.adjacent(.down),
            self.adjacent(.north),
            self.adjacent(.south),
            self.adjacent(.east),
            self.adjacent(.west),
        };
    }

    pub fn manhattanDistance(self: BlockPos, other: BlockPos) i32 {
        const dx = @abs(self.x - other.x);
        const dy = @abs(self.y - other.y);
        const dz = @abs(self.z - other.z);
        return @as(i32, @intCast(dx + dy + dz));
    }

    pub fn euclideanDistanceSq(self: BlockPos, other: BlockPos) f32 {
        const dx: f32 = @floatFromInt(self.x - other.x);
        const dy: f32 = @floatFromInt(self.y - other.y);
        const dz: f32 = @floatFromInt(self.z - other.z);
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn euclideanDistance(self: BlockPos, other: BlockPos) f32 {
        return @sqrt(self.euclideanDistanceSq(other));
    }

    pub fn chebyshevDistance(self: BlockPos, other: BlockPos) i32 {
        const dx = @as(i32, @intCast(@abs(self.x - other.x)));
        const dy = @as(i32, @intCast(@abs(self.y - other.y)));
        const dz = @as(i32, @intCast(@abs(self.z - other.z)));
        return @max(dx, @max(dy, dz));
    }
};

/// Distance measurement method for activation radius detection.
pub const DistanceMetric = enum {
    euclidean,
    manhattan,
    chebyshev,
};

// ============================================================================
// 3. Activation Radius Detection
// ============================================================================

/// Tests whether `target_pos` is within the 8.0-block Euclidean radius of `catalyst_pos`.
pub fn isWithinEuclideanRadius(catalyst_pos: BlockPos, target_pos: BlockPos) bool {
    return catalyst_pos.euclideanDistanceSq(target_pos) <= catalyst_radius_sq;
}

/// Tests whether floating-point coordinates are within the 8.0-block Euclidean radius.
pub fn isWithinEuclideanRadiusFloat(cx: f32, cy: f32, cz: f32, tx: f32, ty: f32, tz: f32) bool {
    const dx = cx - tx;
    const dy = cy - ty;
    const dz = cz - tz;
    return (dx * dx + dy * dy + dz * dz) <= catalyst_radius_sq;
}

/// Tests whether `target_pos` is within the 8-block Manhattan radius of `catalyst_pos`.
pub fn isWithinManhattanRadius(catalyst_pos: BlockPos, target_pos: BlockPos) bool {
    return catalyst_pos.manhattanDistance(target_pos) <= catalyst_manhattan_radius;
}

/// Tests whether floating-point coordinates are within the 8.0-block Manhattan radius.
pub fn isWithinManhattanRadiusFloat(cx: f32, cy: f32, cz: f32, tx: f32, ty: f32, tz: f32) bool {
    const dx = @abs(cx - tx);
    const dy = @abs(cy - ty);
    const dz = @abs(cz - tz);
    return (dx + dy + dz) <= catalyst_radius;
}

/// General activation range detection using the requested distance metric.
pub fn isWithinCatalystRange(catalyst_pos: BlockPos, target_pos: BlockPos, metric: DistanceMetric) bool {
    return switch (metric) {
        .euclidean => isWithinEuclideanRadius(catalyst_pos, target_pos),
        .manhattan => isWithinManhattanRadius(catalyst_pos, target_pos),
        .chebyshev => catalyst_pos.chebyshevDistance(target_pos) <= catalyst_manhattan_radius,
    };
}

// ============================================================================
// 4. Block Types & Substrate Eligibility
// ============================================================================

/// Block identifiers relevant to sculk catalyst conversion and deep dark mechanics.
pub const BlockType = enum(u16) {
    air = 0,
    stone = 1,
    dirt = 2,
    grass = 3,
    deepslate = 4,
    cobblestone = 5,
    andesite = 6,
    diorite = 7,
    granite = 8,
    tuff = 9,
    glass = 20,
    obsidian = 49,
    bedrock = 50,
    sculk = 178,
    sculk_sensor = 179,
    sculk_vein = 181,
    sculk_catalyst = 252,
    sculk_shrieker = 253,
    water = 260,
    lava = 261,
    sand = 262,
    gravel = 263,
    other = 999,
};

/// Candidate solid substrate blocks eligible for conversion into Sculk:
/// Stone, dirt, grass, and deepslate (and related natural stone types) are convertible.
pub fn isConvertibleSubstrate(block: BlockType) bool {
    return switch (block) {
        .stone, .dirt, .grass, .deepslate, .cobblestone, .andesite, .diorite, .granite, .tuff => true,
        else => false,
    };
}

/// Blocks that are immune to sculk conversion and remain unaffected (air, glass, obsidian, bedrock, etc.).
pub fn isImmuneBlock(block: BlockType) bool {
    return switch (block) {
        .air, .glass, .obsidian, .bedrock, .water, .lava => true,
        else => !isConvertibleSubstrate(block) and !isSculkBlock(block),
    };
}

/// Blocks that belong to the sculk ecosystem.
pub fn isSculkBlock(block: BlockType) bool {
    return switch (block) {
        .sculk, .sculk_vein, .sculk_catalyst, .sculk_sensor, .sculk_shrieker => true,
        else => false,
    };
}

/// Blocks that conduct sculk bloom charges without consuming them.
pub fn isSculkConductor(block: BlockType) bool {
    return switch (block) {
        .sculk, .sculk_vein, .sculk_catalyst => true,
        else => false,
    };
}

// ============================================================================
// 5. Mob Categories & XP-to-Charge Conversion
// ============================================================================

/// Mob species categories and their typical baseline dropped experience points.
pub const MobCategory = enum {
    bat,          // 0 XP (no drops)
    chicken,      // 2 XP (passive livestock)
    cow,          // 2 XP
    pig,          // 2 XP
    sheep,        // 2 XP
    zombie,       // 5 XP (standard hostile)
    skeleton,     // 5 XP
    creeper,      // 5 XP
    spider,       // 5 XP
    enderman,     // 5 XP
    witch,        // 5 XP
    blaze,        // 10 XP (high hostile)
    guardian,     // 10 XP
    piglin_brute, // 20 XP (elite hostile)
    ravager,      // 20 XP (mini-boss)
    warden,       // 5 XP
    wither,       // 50 XP (boss)
    ender_dragon, // 500 XP (boss)
    custom,       // Custom user-specified XP
};

/// Returns standard XP dropped by a mob category upon defeat.
pub fn getMobDroppedXp(category: MobCategory) u32 {
    return switch (category) {
        .bat => 0,
        .chicken, .cow, .pig, .sheep => 2,
        .zombie, .skeleton, .creeper, .spider, .enderman, .witch, .warden => 5,
        .blaze, .guardian => 10,
        .piglin_brute, .ravager => 20,
        .wither => 50,
        .ender_dragon => 500,
        .custom => 0,
    };
}

/// Direct conversion of mob dropped experience into sculk charge units:
/// `charge = mob_dropped_xp`.
pub fn convertMobXpToCharge(mob_dropped_xp: u32) u32 {
    return mob_dropped_xp;
}

/// Converts a mob category death into sculk charge units.
pub fn convertMobCategoryToCharge(category: MobCategory, custom_xp: ?u32) u32 {
    if (category == .custom) {
        return convertMobXpToCharge(custom_xp orelse 0);
    }
    return convertMobXpToCharge(getMobDroppedXp(category));
}

/// Checks whether a mob death qualifies to activate a Sculk Catalyst (requires XP > 0).
pub fn canTriggerCatalyst(mob_dropped_xp: u32) bool {
    return mob_dropped_xp > 0;
}

// ============================================================================
// 6. Sculk Charge Cursor & Decay Mechanics
// ============================================================================

/// A mobile charge cursor propagating through the sculk network and converting substrates.
pub const SculkChargeCursor = struct {
    pos: BlockPos,
    charge: u32,
    active: bool = true,
    steps_taken: u32 = 0,
    blocks_converted: u32 = 0,

    pub fn init(pos: BlockPos, initial_charge: u32) SculkChargeCursor {
        return .{
            .pos = pos,
            .charge = initial_charge,
            .active = initial_charge > 0,
            .steps_taken = 0,
            .blocks_converted = 0,
        };
    }

    pub fn isExhausted(self: SculkChargeCursor) bool {
        return self.charge == 0 or !self.active;
    }

    /// Consumes one charge unit for converting a substrate block.
    /// Returns true if a unit was consumed, or false if already exhausted.
    pub fn consumeOne(self: *SculkChargeCursor) bool {
        if (self.charge == 0 or !self.active) {
            self.active = false;
            return false;
        }
        self.charge -= 1;
        self.blocks_converted += 1;
        if (self.charge == 0) {
            self.active = false;
        }
        return true;
    }

    /// Consumes a specified number of charge units, up to the remaining balance.
    pub fn consume(self: *SculkChargeCursor, amount: u32) u32 {
        const to_consume = @min(self.charge, amount);
        self.charge -= to_consume;
        self.blocks_converted += to_consume;
        if (self.charge == 0) {
            self.active = false;
        }
        return to_consume;
    }
};

// ============================================================================
// 7. World Grid Simulation
// ============================================================================

/// 3D voxel grid for localized sculk propagation, substrate conversion, and tests.
pub const WorldGrid = struct {
    pub const DIM: usize = 33; // Spans coordinates -16 to +16
    pub const OFFSET: i32 = 16;

    blocks: [DIM][DIM][DIM]BlockType,

    pub fn init(fill: BlockType) WorldGrid {
        var grid: WorldGrid = undefined;
        for (0..DIM) |x| {
            for (0..DIM) |y| {
                for (0..DIM) |z| {
                    grid.blocks[x][y][z] = fill;
                }
            }
        }
        return grid;
    }

    pub fn isInBounds(x: i32, y: i32, z: i32) bool {
        const gx = x + OFFSET;
        const gy = y + OFFSET;
        const gz = z + OFFSET;
        return gx >= 0 and gx < DIM and gy >= 0 and gy < DIM and gz >= 0 and gz < DIM;
    }

    pub fn getBlock(self: *const WorldGrid, x: i32, y: i32, z: i32) BlockType {
        if (!isInBounds(x, y, z)) return .air;
        const gx: usize = @intCast(x + OFFSET);
        const gy: usize = @intCast(y + OFFSET);
        const gz: usize = @intCast(z + OFFSET);
        return self.blocks[gx][gy][gz];
    }

    pub fn setBlock(self: *WorldGrid, x: i32, y: i32, z: i32, block: BlockType) bool {
        if (!isInBounds(x, y, z)) return false;
        const gx: usize = @intCast(x + OFFSET);
        const gy: usize = @intCast(y + OFFSET);
        const gz: usize = @intCast(z + OFFSET);
        self.blocks[gx][gy][gz] = block;
        return true;
    }

    pub fn getBlockPos(self: *const WorldGrid, pos: BlockPos) BlockType {
        return self.getBlock(pos.x, pos.y, pos.z);
    }

    pub fn setBlockPos(self: *WorldGrid, pos: BlockPos, block: BlockType) bool {
        return self.setBlock(pos.x, pos.y, pos.z, block);
    }

    pub fn countBlocks(self: *const WorldGrid, block: BlockType) usize {
        var count: usize = 0;
        for (0..DIM) |x| {
            for (0..DIM) |y| {
                for (0..DIM) |z| {
                    if (self.blocks[x][y][z] == block) count += 1;
                }
            }
        }
        return count;
    }
};

// ============================================================================
// 8. BFS Traversal Helpers & Bloom Engine
// ============================================================================

pub const VisitedTracker = struct {
    pub const CAPACITY: usize = 256;
    items: [CAPACITY]BlockPos = undefined,
    count: usize = 0,

    pub fn init() VisitedTracker {
        return .{ .count = 0 };
    }

    pub fn contains(self: *const VisitedTracker, pos: BlockPos) bool {
        for (self.items[0..self.count]) |item| {
            if (item.equals(pos)) return true;
        }
        return false;
    }

    pub fn add(self: *VisitedTracker, pos: BlockPos) bool {
        if (self.contains(pos)) return false;
        if (self.count >= CAPACITY) return false;
        self.items[self.count] = pos;
        self.count += 1;
        return true;
    }
};

pub const PosQueue = struct {
    pub const CAPACITY: usize = 256;
    items: [CAPACITY]BlockPos = undefined,
    head: usize = 0,
    tail: usize = 0,

    pub fn init() PosQueue {
        return .{ .head = 0, .tail = 0 };
    }

    pub fn push(self: *PosQueue, pos: BlockPos) bool {
        const next_tail = (self.tail + 1) % CAPACITY;
        if (next_tail == self.head) return false;
        self.items[self.tail] = pos;
        self.tail = next_tail;
        return true;
    }

    pub fn pop(self: *PosQueue) ?BlockPos {
        if (self.head == self.tail) return null;
        const item = self.items[self.head];
        self.head = (self.head + 1) % CAPACITY;
        return item;
    }

    pub fn isEmpty(self: *const PosQueue) bool {
        return self.head == self.tail;
    }
};

/// Propagates a single charge decay step:
/// Finds the nearest reachable convertible substrate block connected through sculk conductors,
/// converts it to Sculk, consumes 1 charge unit, and advances the cursor position.
/// Returns 1 if a block was converted, or 0 if exhausted or no substrate reachable.
pub fn propagateStep(world: *WorldGrid, cursor: *SculkChargeCursor) u32 {
    if (cursor.charge == 0 or !cursor.active) {
        cursor.active = false;
        return 0;
    }

    cursor.steps_taken += 1;

    // Check if the cursor's current position itself is unconverted substrate
    const current_block = world.getBlockPos(cursor.pos);
    if (isConvertibleSubstrate(current_block)) {
        _ = world.setBlockPos(cursor.pos, .sculk);
        _ = cursor.consumeOne();
        return 1;
    }

    // Perform BFS through connected sculk conductors to locate candidate substrate
    var queue = PosQueue.init();
    var visited = VisitedTracker.init();

    _ = queue.push(cursor.pos);
    _ = visited.add(cursor.pos);

    while (queue.pop()) |curr| {
        const nbrs = curr.neighbors();
        for (nbrs) |nbr| {
            if (!WorldGrid.isInBounds(nbr.x, nbr.y, nbr.z)) continue;
            if (visited.contains(nbr)) continue;

            const block = world.getBlockPos(nbr);
            if (isConvertibleSubstrate(block)) {
                // Convert candidate substrate into sculk block
                _ = world.setBlockPos(nbr, .sculk);
                _ = cursor.consumeOne();
                cursor.pos = nbr;
                return 1;
            } else if (isSculkConductor(block)) {
                // Conduct charge through sculk/vein/catalyst
                _ = visited.add(nbr);
                _ = queue.push(nbr);
            } else {
                // Non-convertible and non-conductor: mark visited but do not traverse
                _ = visited.add(nbr);
            }
        }
    }

    // No reachable substrate blocks remain
    cursor.active = false;
    return 0;
}

/// Summary of a full bloom propagation run.
pub const BloomResult = struct {
    initial_charge: u32,
    remaining_charge: u32,
    blocks_converted: u32,
    charges_exhausted: bool,
};

/// Propagates sculk bloom from `start_pos` until the initial charge is depleted or no reachable substrate remains.
pub fn propagateBloom(world: *WorldGrid, start_pos: BlockPos, initial_charge: u32) BloomResult {
    var cursor = SculkChargeCursor.init(start_pos, initial_charge);
    var converted: u32 = 0;

    while (cursor.active and cursor.charge > 0) {
        const n = propagateStep(world, &cursor);
        if (n == 0) break;
        converted += n;
    }

    return .{
        .initial_charge = initial_charge,
        .remaining_charge = cursor.charge,
        .blocks_converted = converted,
        .charges_exhausted = cursor.charge == 0,
    };
}

// ============================================================================
// 9. Sculk Catalyst State & Light Emission
// ============================================================================

/// Operating state of a Sculk Catalyst.
pub const CatalystState = enum {
    dormant,
    blooming,
};

/// Sculk Catalyst entity controller handling mob death detection, XP-to-charge conversion,
/// charge queueing, bloom decay, and light emission state transitions.
pub const SculkCatalyst = struct {
    pos: BlockPos,
    state: CatalystState = .dormant,
    bloom_ticks_remaining: u32 = 0,
    charges: [max_active_charges]SculkChargeCursor = undefined,
    charge_count: usize = 0,
    total_xp_absorbed: u64 = 0,
    total_blocks_converted: u64 = 0,

    pub fn init(pos: BlockPos) SculkCatalyst {
        return .{
            .pos = pos,
            .state = .dormant,
            .bloom_ticks_remaining = 0,
            .charge_count = 0,
            .total_xp_absorbed = 0,
            .total_blocks_converted = 0,
        };
    }

    /// Emits ambient light level 6 when blooming / actively processing charges; 0 when dormant.
    pub fn getLightLevel(self: SculkCatalyst) u4 {
        return switch (self.state) {
            .blooming => light_level_blooming,
            .dormant => light_level_dormant,
        };
    }

    /// Emissive shader float value: 0.40 (6/15) when blooming, 0.0 when dormant.
    pub fn getEmissive(self: SculkCatalyst) f32 {
        return switch (self.state) {
            .blooming => emissive_blooming,
            .dormant => emissive_dormant,
        };
    }

    pub fn isBlooming(self: SculkCatalyst) bool {
        return self.state == .blooming;
    }

    pub fn isDormant(self: SculkCatalyst) bool {
        return self.state == .dormant;
    }

    pub fn isWithinRange(self: SculkCatalyst, death_pos: BlockPos, metric: DistanceMetric) bool {
        return isWithinCatalystRange(self.pos, death_pos, metric);
    }

    /// Processes a mob death near the catalyst.
    /// Checks activation range and positive dropped XP.
    /// If valid, switches to blooming state (light level 6), creates a sculk charge,
    /// queues the charge cursor, and returns true.
    pub fn onMobDeath(
        self: *SculkCatalyst,
        death_pos: BlockPos,
        dropped_xp: u32,
        metric: DistanceMetric,
    ) bool {
        if (!self.isWithinRange(death_pos, metric)) return false;
        if (!canTriggerCatalyst(dropped_xp)) return false;

        const charge = convertMobXpToCharge(dropped_xp);
        self.state = .blooming;
        self.bloom_ticks_remaining = default_bloom_ticks;
        self.total_xp_absorbed += dropped_xp;

        if (self.charge_count < max_active_charges) {
            self.charges[self.charge_count] = SculkChargeCursor.init(self.pos, charge);
            self.charge_count += 1;
        }
        return true;
    }

    /// Convenience wrapper accepting a MobCategory.
    pub fn onMobCategoryDeath(
        self: *SculkCatalyst,
        death_pos: BlockPos,
        mob: MobCategory,
        custom_xp: ?u32,
        metric: DistanceMetric,
    ) bool {
        const xp = convertMobCategoryToCharge(mob, custom_xp);
        return self.onMobDeath(death_pos, xp, metric);
    }

    /// Sets the catalyst directly to the blooming state with an optional tick timer.
    pub fn setBlooming(self: *SculkCatalyst, ticks: u32) void {
        self.state = .blooming;
        self.bloom_ticks_remaining = ticks;
    }

    /// Deactivates the catalyst back to dormant with light level 0 and clears charges.
    pub fn setDormant(self: *SculkCatalyst) void {
        self.state = .dormant;
        self.bloom_ticks_remaining = 0;
        self.charge_count = 0;
    }

    /// Advances the catalyst simulation by one tick.
    /// If a WorldGrid is supplied, processes one conversion step per active charge.
    /// When charges are exhausted and bloom animation expires, transitions back to dormant.
    pub fn tick(self: *SculkCatalyst, world: ?*WorldGrid) void {
        var any_charge_active = false;

        if (world) |w| {
            var i: usize = 0;
            while (i < self.charge_count) {
                if (self.charges[i].active and self.charges[i].charge > 0) {
                    const converted = propagateStep(w, &self.charges[i]);
                    self.total_blocks_converted += converted;
                    if (self.charges[i].active and self.charges[i].charge > 0) {
                        any_charge_active = true;
                    }
                }
                i += 1;
            }
        } else {
            for (self.charges[0..self.charge_count]) |c| {
                if (c.active and c.charge > 0) {
                    any_charge_active = true;
                    break;
                }
            }
        }

        if (!any_charge_active) {
            if (self.bloom_ticks_remaining > 0) {
                self.bloom_ticks_remaining -= 1;
            }
            if (self.bloom_ticks_remaining == 0) {
                self.state = .dormant;
                self.charge_count = 0;
            }
        } else {
            self.state = .blooming;
        }
    }

    /// Flushes all queued charges immediately into the given world until depleted.
    pub fn flushBloom(self: *SculkCatalyst, world: *WorldGrid) u32 {
        var total_converted: u32 = 0;
        for (self.charges[0..self.charge_count]) |*cursor| {
            while (cursor.active and cursor.charge > 0) {
                const converted = propagateStep(world, cursor);
                if (converted == 0) {
                    cursor.active = false;
                    break;
                }
                total_converted += converted;
            }
        }
        self.total_blocks_converted += total_converted;
        self.charge_count = 0;
        return total_converted;
    }
};

// ============================================================================
// 10. Multi-Catalyst Collection Tracker
// ============================================================================

/// Collection tracker managing multiple Sculk Catalysts across the world.
pub const SculkCatalystTracker = struct {
    catalysts: [max_tracked_catalysts]SculkCatalyst = undefined,
    count: usize = 0,

    pub fn init() SculkCatalystTracker {
        return .{ .count = 0 };
    }

    pub fn addCatalyst(self: *SculkCatalystTracker, pos: BlockPos) ?*SculkCatalyst {
        if (self.count >= max_tracked_catalysts) return null;
        self.catalysts[self.count] = SculkCatalyst.init(pos);
        const ptr = &self.catalysts[self.count];
        self.count += 1;
        return ptr;
    }

    /// Finds the closest catalyst within activation range of `pos`.
    pub fn findNearbyCatalyst(
        self: *SculkCatalystTracker,
        pos: BlockPos,
        metric: DistanceMetric,
    ) ?*SculkCatalyst {
        var best_catalyst: ?*SculkCatalyst = null;
        var min_dist_sq: f32 = std.math.floatMax(f32);

        for (self.catalysts[0..self.count]) |*cat| {
            if (cat.isWithinRange(pos, metric)) {
                const dist_sq = cat.pos.euclideanDistanceSq(pos);
                if (dist_sq < min_dist_sq) {
                    min_dist_sq = dist_sq;
                    best_catalyst = cat;
                }
            }
        }
        return best_catalyst;
    }

    /// Dispatches a mob death event to the nearest catalyst within range.
    pub fn onMobDeath(
        self: *SculkCatalystTracker,
        pos: BlockPos,
        xp: u32,
        metric: DistanceMetric,
    ) ?*SculkCatalyst {
        if (self.findNearbyCatalyst(pos, metric)) |cat| {
            if (cat.onMobDeath(pos, xp, metric)) {
                return cat;
            }
        }
        return null;
    }

    /// Ticks all catalysts in the tracker.
    pub fn tickAll(self: *SculkCatalystTracker, world: ?*WorldGrid) void {
        for (self.catalysts[0..self.count]) |*cat| {
            cat.tick(world);
        }
    }
};

// ============================================================================
// 11. Unit Test Suite (25 Tests)
// ============================================================================

test "activation radius: Euclidean detection within 8.0 blocks" {
    const catalyst_pos = BlockPos.init(0, 0, 0);

    // Cardinal axes at exactly 8 blocks
    try std.testing.expect(isWithinEuclideanRadius(catalyst_pos, BlockPos.init(8, 0, 0)));
    try std.testing.expect(isWithinEuclideanRadius(catalyst_pos, BlockPos.init(0, 8, 0)));
    try std.testing.expect(isWithinEuclideanRadius(catalyst_pos, BlockPos.init(0, 0, 8)));

    // Diagonal distances within sqrt(64) = 8
    // (4, 4, 4) -> 16 + 16 + 16 = 48 <= 64
    try std.testing.expect(isWithinEuclideanRadius(catalyst_pos, BlockPos.init(4, 4, 4)));

    // (5, 5, 0) -> 25 + 25 = 50 <= 64
    try std.testing.expect(isWithinEuclideanRadius(catalyst_pos, BlockPos.init(5, 5, 0)));
}

test "activation radius: Euclidean boundary and out-of-range rejection" {
    const catalyst_pos = BlockPos.init(0, 0, 0);

    // Float coordinates at 8.0 vs 8.01
    try std.testing.expect(isWithinEuclideanRadiusFloat(0, 0, 0, 8.0, 0, 0));
    try std.testing.expect(!isWithinEuclideanRadiusFloat(0, 0, 0, 8.01, 0, 0));

    // Integer coordinates outside radius
    // (9, 0, 0) -> 81 > 64
    try std.testing.expect(!isWithinEuclideanRadius(catalyst_pos, BlockPos.init(9, 0, 0)));

    // (6, 6, 0) -> 36 + 36 = 72 > 64
    try std.testing.expect(!isWithinEuclideanRadius(catalyst_pos, BlockPos.init(6, 6, 0)));

    // (5, 5, 5) -> 25 + 25 + 25 = 75 > 64
    try std.testing.expect(!isWithinEuclideanRadius(catalyst_pos, BlockPos.init(5, 5, 5)));

    // Distant mob death
    try std.testing.expect(!isWithinEuclideanRadius(catalyst_pos, BlockPos.init(15, 10, 5)));
}

test "activation radius: Manhattan detection within 8 blocks" {
    const catalyst_pos = BlockPos.init(0, 0, 0);

    // Axis at 8 blocks
    try std.testing.expect(isWithinManhattanRadius(catalyst_pos, BlockPos.init(8, 0, 0)));

    // Manhattan combinations totaling 8
    try std.testing.expect(isWithinManhattanRadius(catalyst_pos, BlockPos.init(3, 3, 2)));
    try std.testing.expect(isWithinManhattanRadius(catalyst_pos, BlockPos.init(4, 2, 2)));
    try std.testing.expect(isWithinManhattanRadius(catalyst_pos, BlockPos.init(1, 1, 6)));

    // Float coordinates
    try std.testing.expect(isWithinManhattanRadiusFloat(0, 0, 0, 4.0, 2.0, 2.0));
    try std.testing.expect(!isWithinManhattanRadiusFloat(0, 0, 0, 4.0, 2.0, 2.1));

    // Manhattan distance > 8 rejected
    try std.testing.expect(!isWithinManhattanRadius(catalyst_pos, BlockPos.init(4, 3, 2)));
    try std.testing.expect(!isWithinManhattanRadius(catalyst_pos, BlockPos.init(9, 0, 0)));
}

test "activation radius: negative coordinates in all octants" {
    const catalyst_pos = BlockPos.init(0, 0, 0);

    try std.testing.expect(isWithinEuclideanRadius(catalyst_pos, BlockPos.init(-8, 0, 0)));
    try std.testing.expect(isWithinEuclideanRadius(catalyst_pos, BlockPos.init(0, -8, 0)));
    try std.testing.expect(isWithinEuclideanRadius(catalyst_pos, BlockPos.init(0, 0, -8)));

    // (-4, -4, -4) -> 48 <= 64
    try std.testing.expect(isWithinEuclideanRadius(catalyst_pos, BlockPos.init(-4, -4, -4)));

    // Out of range negative coordinates
    try std.testing.expect(!isWithinEuclideanRadius(catalyst_pos, BlockPos.init(-9, 0, 0)));
    try std.testing.expect(!isWithinEuclideanRadius(catalyst_pos, BlockPos.init(-6, -6, 0)));
}

test "activation: mob death out-of-range rejection on catalyst" {
    var catalyst = SculkCatalyst.init(BlockPos.init(10, 60, 20));

    // Mob dies 15 blocks away (out of range)
    const out_pos = BlockPos.init(25, 60, 20);
    const result = catalyst.onMobDeath(out_pos, 5, .euclidean);

    try std.testing.expect(!result);
    try std.testing.expect(catalyst.isDormant());
    try std.testing.expectEqual(@as(u4, 0), catalyst.getLightLevel());
    try std.testing.expectEqual(@as(usize, 0), catalyst.charge_count);
    try std.testing.expectEqual(@as(u64, 0), catalyst.total_xp_absorbed);
}

test "activation: zero XP mob death produces zero charge and remains dormant" {
    var catalyst = SculkCatalyst.init(BlockPos.init(0, 0, 0));

    // Bat dies right next to catalyst with 0 XP
    const near_pos = BlockPos.init(1, 0, 0);
    const result = catalyst.onMobCategoryDeath(near_pos, .bat, null, .euclidean);

    try std.testing.expect(!result);
    try std.testing.expect(catalyst.isDormant());
    try std.testing.expectEqual(@as(u4, 0), catalyst.getLightLevel());
    try std.testing.expectEqual(@as(usize, 0), catalyst.charge_count);
    try std.testing.expectEqual(@as(u64, 0), catalyst.total_xp_absorbed);
}

test "XP-to-charge conversion: standard hostile mobs" {
    // Standard hostiles drop 5 XP -> 5 sculk charges
    try std.testing.expectEqual(@as(u32, 5), convertMobCategoryToCharge(.zombie, null));
    try std.testing.expectEqual(@as(u32, 5), convertMobCategoryToCharge(.skeleton, null));
    try std.testing.expectEqual(@as(u32, 5), convertMobCategoryToCharge(.creeper, null));
    try std.testing.expectEqual(@as(u32, 5), convertMobCategoryToCharge(.spider, null));
    try std.testing.expectEqual(@as(u32, 5), convertMobCategoryToCharge(.enderman, null));
    try std.testing.expectEqual(@as(u32, 5), convertMobCategoryToCharge(.witch, null));
}

test "XP-to-charge conversion: passive and livestock mobs" {
    // Livestock drops 2 XP -> 2 sculk charges
    try std.testing.expectEqual(@as(u32, 2), convertMobCategoryToCharge(.chicken, null));
    try std.testing.expectEqual(@as(u32, 2), convertMobCategoryToCharge(.cow, null));
    try std.testing.expectEqual(@as(u32, 2), convertMobCategoryToCharge(.pig, null));
    try std.testing.expectEqual(@as(u32, 2), convertMobCategoryToCharge(.sheep, null));
    try std.testing.expectEqual(@as(u32, 0), convertMobCategoryToCharge(.bat, null));
}

test "XP-to-charge conversion: high-tier hostiles and mini-bosses" {
    // High-tier and mini-boss hostiles
    try std.testing.expectEqual(@as(u32, 10), convertMobCategoryToCharge(.blaze, null));
    try std.testing.expectEqual(@as(u32, 10), convertMobCategoryToCharge(.guardian, null));
    try std.testing.expectEqual(@as(u32, 20), convertMobCategoryToCharge(.piglin_brute, null));
    try std.testing.expectEqual(@as(u32, 20), convertMobCategoryToCharge(.ravager, null));
}

test "XP-to-charge conversion: boss mobs and custom XP values" {
    // Bosses and custom arbitrary XP values
    try std.testing.expectEqual(@as(u32, 50), convertMobCategoryToCharge(.wither, null));
    try std.testing.expectEqual(@as(u32, 500), convertMobCategoryToCharge(.ender_dragon, null));
    try std.testing.expectEqual(@as(u32, 42), convertMobCategoryToCharge(.custom, 42));
    try std.testing.expectEqual(@as(u32, 1234), convertMobXpToCharge(1234));
}

test "substrate eligibility: stone converts to sculk" {
    try std.testing.expect(isConvertibleSubstrate(.stone));

    var world = WorldGrid.init(.air);
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);
    _ = world.setBlock(1, 0, 0, .stone);

    const bloom = propagateBloom(&world, BlockPos.init(0, 0, 0), 1);
    try std.testing.expectEqual(@as(u32, 1), bloom.blocks_converted);
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(1, 0, 0));
}

test "substrate eligibility: dirt and grass convert to sculk" {
    try std.testing.expect(isConvertibleSubstrate(.dirt));
    try std.testing.expect(isConvertibleSubstrate(.grass));

    var world = WorldGrid.init(.air);
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);
    _ = world.setBlock(1, 0, 0, .dirt);
    _ = world.setBlock(-1, 0, 0, .grass);

    const bloom = propagateBloom(&world, BlockPos.init(0, 0, 0), 2);
    try std.testing.expectEqual(@as(u32, 2), bloom.blocks_converted);
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(1, 0, 0));
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(-1, 0, 0));
}

test "substrate eligibility: deepslate converts to sculk" {
    try std.testing.expect(isConvertibleSubstrate(.deepslate));

    var world = WorldGrid.init(.air);
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);
    _ = world.setBlock(0, -1, 0, .deepslate);

    const bloom = propagateBloom(&world, BlockPos.init(0, 0, 0), 1);
    try std.testing.expectEqual(@as(u32, 1), bloom.blocks_converted);
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(0, -1, 0));
}

test "substrate eligibility: air is unaffected and never converted" {
    try std.testing.expect(!isConvertibleSubstrate(.air));
    try std.testing.expect(isImmuneBlock(.air));

    var world = WorldGrid.init(.air);
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);

    const bloom = propagateBloom(&world, BlockPos.init(0, 0, 0), 5);
    try std.testing.expectEqual(@as(u32, 0), bloom.blocks_converted);
    try std.testing.expectEqual(BlockType.air, world.getBlock(1, 0, 0));
    try std.testing.expectEqual(BlockType.air, world.getBlock(0, 1, 0));
}

test "substrate eligibility: glass is unaffected and never converted" {
    try std.testing.expect(!isConvertibleSubstrate(.glass));
    try std.testing.expect(isImmuneBlock(.glass));

    var world = WorldGrid.init(.glass);
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);

    const bloom = propagateBloom(&world, BlockPos.init(0, 0, 0), 5);
    try std.testing.expectEqual(@as(u32, 0), bloom.blocks_converted);
    try std.testing.expectEqual(BlockType.glass, world.getBlock(1, 0, 0));
    try std.testing.expectEqual(BlockType.glass, world.getBlock(0, 1, 0));
}

test "substrate eligibility: obsidian and bedrock are unaffected" {
    try std.testing.expect(!isConvertibleSubstrate(.obsidian));
    try std.testing.expect(isImmuneBlock(.obsidian));
    try std.testing.expect(!isConvertibleSubstrate(.bedrock));
    try std.testing.expect(isImmuneBlock(.bedrock));

    var world = WorldGrid.init(.obsidian);
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);
    _ = world.setBlock(0, -1, 0, .bedrock);

    const bloom = propagateBloom(&world, BlockPos.init(0, 0, 0), 10);
    try std.testing.expectEqual(@as(u32, 0), bloom.blocks_converted);
    try std.testing.expectEqual(BlockType.obsidian, world.getBlock(1, 0, 0));
    try std.testing.expectEqual(BlockType.bedrock, world.getBlock(0, -1, 0));
}

test "charge decay: step-by-step consumption until exhaustion" {
    var world = WorldGrid.init(.air);
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);
    // Create a 5-block chain of stone
    _ = world.setBlock(1, 0, 0, .stone);
    _ = world.setBlock(2, 0, 0, .stone);
    _ = world.setBlock(3, 0, 0, .stone);
    _ = world.setBlock(4, 0, 0, .stone);
    _ = world.setBlock(5, 0, 0, .stone);

    var cursor = SculkChargeCursor.init(BlockPos.init(0, 0, 0), 5);
    try std.testing.expectEqual(@as(u32, 5), cursor.charge);
    try std.testing.expect(!cursor.isExhausted());

    // Step 1: converts (1, 0, 0), charge 5 -> 4
    const s1 = propagateStep(&world, &cursor);
    try std.testing.expectEqual(@as(u32, 1), s1);
    try std.testing.expectEqual(@as(u32, 4), cursor.charge);
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(1, 0, 0));

    // Step 2: converts (2, 0, 0), charge 4 -> 3
    const s2 = propagateStep(&world, &cursor);
    try std.testing.expectEqual(@as(u32, 1), s2);
    try std.testing.expectEqual(@as(u32, 3), cursor.charge);
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(2, 0, 0));

    // Step 3: converts (3, 0, 0), charge 3 -> 2
    const s3 = propagateStep(&world, &cursor);
    try std.testing.expectEqual(@as(u32, 1), s3);
    try std.testing.expectEqual(@as(u32, 2), cursor.charge);
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(3, 0, 0));

    // Step 4: converts (4, 0, 0), charge 2 -> 1
    const s4 = propagateStep(&world, &cursor);
    try std.testing.expectEqual(@as(u32, 1), s4);
    try std.testing.expectEqual(@as(u32, 1), cursor.charge);
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(4, 0, 0));

    // Step 5: converts (5, 0, 0), charge 1 -> 0 (exhaustion)
    const s5 = propagateStep(&world, &cursor);
    try std.testing.expectEqual(@as(u32, 1), s5);
    try std.testing.expectEqual(@as(u32, 0), cursor.charge);
    try std.testing.expect(cursor.isExhausted());
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(5, 0, 0));

    // Step 6: exhausted, no-op
    const s6 = propagateStep(&world, &cursor);
    try std.testing.expectEqual(@as(u32, 0), s6);
}

test "charge decay: bloom stops when charge is exhausted in large substrate" {
    var world = WorldGrid.init(.stone); // 33x33x33 of solid stone
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);

    // Initial charge of 7 units
    const bloom = propagateBloom(&world, BlockPos.init(0, 0, 0), 7);

    try std.testing.expectEqual(@as(u32, 7), bloom.blocks_converted);
    try std.testing.expectEqual(@as(u32, 0), bloom.remaining_charge);
    try std.testing.expect(bloom.charges_exhausted);

    // Sculk catalyst remains intact, exactly 7 sculk blocks created
    try std.testing.expectEqual(@as(usize, 7), world.countBlocks(.sculk));
    try std.testing.expectEqual(BlockType.sculk_catalyst, world.getBlock(0, 0, 0));
}

test "charge decay: bloom handles insufficient substrate gracefully" {
    // Air world with catalyst and only 3 stone blocks
    var world = WorldGrid.init(.air);
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);
    _ = world.setBlock(1, 0, 0, .stone);
    _ = world.setBlock(0, 1, 0, .stone);
    _ = world.setBlock(0, 0, 1, .stone);
    _ = world.setBlock(-1, 0, 0, .obsidian);

    // Initial charge of 10 units (more than available substrate)
    const bloom = propagateBloom(&world, BlockPos.init(0, 0, 0), 10);

    // Only 3 blocks converted, obsidian untouched
    try std.testing.expectEqual(@as(u32, 3), bloom.blocks_converted);
    try std.testing.expectEqual(BlockType.obsidian, world.getBlock(-1, 0, 0));
    try std.testing.expect(!bloom.charges_exhausted);
    try std.testing.expectEqual(@as(u32, 7), bloom.remaining_charge);
}

test "catalyst light emission: dormant catalyst emits 0 light level" {
    const catalyst = SculkCatalyst.init(BlockPos.init(0, 64, 0));

    try std.testing.expect(catalyst.isDormant());
    try std.testing.expect(!catalyst.isBlooming());
    try std.testing.expectEqual(light_level_dormant, catalyst.getLightLevel());
    try std.testing.expectEqual(@as(u4, 0), catalyst.getLightLevel());
    try std.testing.expectEqual(emissive_dormant, catalyst.getEmissive());
    try std.testing.expectEqual(@as(f32, 0.0), catalyst.getEmissive());
}

test "catalyst light emission: mob death activates blooming and emits light level 6" {
    var catalyst = SculkCatalyst.init(BlockPos.init(0, 64, 0));

    // Zombie dies 3 blocks away
    const mob_pos = BlockPos.init(3, 64, 0);
    const triggered = catalyst.onMobCategoryDeath(mob_pos, .zombie, null, .euclidean);

    try std.testing.expect(triggered);
    try std.testing.expect(catalyst.isBlooming());
    try std.testing.expect(!catalyst.isDormant());
    try std.testing.expectEqual(light_level_blooming, catalyst.getLightLevel());
    try std.testing.expectEqual(@as(u4, 6), catalyst.getLightLevel());
    try std.testing.expectEqual(emissive_blooming, catalyst.getEmissive());
    try std.testing.expectApproxEqAbs(@as(f32, 0.40), catalyst.getEmissive(), 0.001);
}

test "catalyst light emission: state transitions back to dormant when finished" {
    var world = WorldGrid.init(.air);
    _ = world.setBlock(0, 64, 0, .sculk_catalyst);
    _ = world.setBlock(1, 64, 0, .stone);

    var catalyst = SculkCatalyst.init(BlockPos.init(0, 64, 0));

    // Chicken dies with 2 XP
    _ = catalyst.onMobDeath(BlockPos.init(1, 64, 0), 2, .euclidean);
    try std.testing.expectEqual(@as(u4, 6), catalyst.getLightLevel());

    // Flush bloom charges immediately
    _ = catalyst.flushBloom(&world);

    // Tick down remaining bloom animation ticks
    while (catalyst.isBlooming()) {
        catalyst.tick(&world);
    }

    try std.testing.expect(catalyst.isDormant());
    try std.testing.expectEqual(@as(u4, 0), catalyst.getLightLevel());
    try std.testing.expectEqual(@as(f32, 0.0), catalyst.getEmissive());
}

test "propagation: charge travels through connected sculk conductors" {
    var world = WorldGrid.init(.air);
    _ = world.setBlock(0, 0, 0, .sculk_catalyst);
    _ = world.setBlock(1, 0, 0, .sculk_vein); // sculk vein conductor
    _ = world.setBlock(2, 0, 0, .sculk);      // sculk block conductor
    _ = world.setBlock(3, 0, 0, .deepslate);  // target substrate 3 blocks away

    const bloom = propagateBloom(&world, BlockPos.init(0, 0, 0), 1);

    try std.testing.expectEqual(@as(u32, 1), bloom.blocks_converted);
    try std.testing.expectEqual(BlockType.sculk_vein, world.getBlock(1, 0, 0));
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(2, 0, 0));
    try std.testing.expectEqual(BlockType.sculk, world.getBlock(3, 0, 0));
}

test "catalyst statistics: tracks total XP absorbed and blocks converted" {
    var world = WorldGrid.init(.stone);
    var catalyst = SculkCatalyst.init(BlockPos.init(0, 0, 0));

    _ = catalyst.onMobDeath(BlockPos.init(1, 0, 0), 5, .euclidean);
    _ = catalyst.onMobDeath(BlockPos.init(0, 1, 0), 10, .euclidean);
    _ = catalyst.onMobDeath(BlockPos.init(0, 0, 1), 2, .euclidean);

    try std.testing.expectEqual(@as(u64, 17), catalyst.total_xp_absorbed);
    try std.testing.expectEqual(@as(usize, 3), catalyst.charge_count);

    const converted = catalyst.flushBloom(&world);
    try std.testing.expectEqual(@as(u32, 17), converted);
    try std.testing.expectEqual(@as(u64, 17), catalyst.total_blocks_converted);
}

test "catalyst multi-charge queue capacity and tracker coordination" {
    var tracker = SculkCatalystTracker.init();
    const cat1 = tracker.addCatalyst(BlockPos.init(0, 0, 0)).?;
    _ = tracker.addCatalyst(BlockPos.init(20, 0, 0)).?;

    // Mob dies close to cat1
    const nearest = tracker.onMobDeath(BlockPos.init(2, 0, 0), 5, .euclidean);
    try std.testing.expect(nearest != null);
    try std.testing.expectEqual(cat1, nearest.?);
    try std.testing.expect(cat1.isBlooming());
    try std.testing.expectEqual(@as(u4, 6), cat1.getLightLevel());

    // Mob dies in the middle of nowhere (out of range of both catalysts)
    const none = tracker.onMobDeath(BlockPos.init(10, 0, 0), 5, .euclidean);
    try std.testing.expect(none == null);
}
