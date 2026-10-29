//! Milestone 532: Pale Moss Carpet & Pale Hanging Moss Spread Dynamics in Zigcraft
//!
//! Provides deterministic mechanics for:
//! 1. Pale Moss Carpet block:
//!    - Thin surface block: height 0.0625m (1 pixel / 1/16th block), non-solid walk-through.
//!    - Attachment: attaches to solid top faces (floor) or climbs up solid side faces (e.g. Pale Oak wood/logs).
//!    - Support validation: breaks and drops 1 pale moss carpet item if underlying/supporting block is removed.
//!    - Flammability: combustible, ignites and burns from adjacent fire or lava contact.
//! 2. Pale Hanging Moss block:
//!    - Vertical downward hanging plant with tip growth (length 1 to 8 blocks).
//!    - Support rule: hangs from underside of solid blocks or leaves, or from another pale hanging moss block directly above.
//!    - Cascade breaking physics: breaking any segment in a hanging moss column instantly breaks all dependent hanging moss blocks below it.
//!    - Harvesting with Shears: right-clicking or breaking with Shears yields Pale Hanging Moss item (100% chance) and consumes 1 shears durability.
//!    - Bare hand breaking: 0% drop chance (drops nothing) and consumes 0 shears durability.
//! 3. Bonemeal Growth Reaction on Pale Moss Block:
//!    - Applies bonemeal to a Pale Moss Block (`pale_moss_block`).
//!    - Consumes 1 bonemeal item and emits green and white sparkle bonemeal particles.
//!    - Radiates spread outwards across solid floor blocks within a 5-block horizontal radius (dx^2 + dz^2 <= 25.0).
//!    - Generates Pale Moss Carpet on eligible solid top faces.
//!    - Climbs vertically up side faces of Pale Oak wood/logs (up to 2 blocks high).
//!    - Generates downward hanging Pale Hanging Moss beneath adjacent Pale Oak leaf blocks (1 to 3 blocks length).

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Thickness / height of Pale Moss Carpet in meters: 1/16th of a block (0.0625m = 1 pixel).
pub const CARPET_HEIGHT: f32 = 0.0625;

/// Pale Moss Carpet is non-solid: entities walk through it without solid collision obstruction.
pub const CARPET_IS_SOLID: bool = false;

/// Pale Moss Carpet is combustible.
pub const CARPET_IS_FLAMMABLE: bool = true;

/// Minecraft flammability chance / catch rate (60).
pub const CARPET_FLAMMABILITY_CHANCE: u8 = 60;

/// Minecraft burn rate / decay odds (20).
pub const CARPET_BURN_ODDS: u8 = 20;

/// Maximum height Pale Moss Carpet can climb up Pale Oak log/wood trunks above the base floor (2 blocks).
pub const MAX_LOG_CLIMB_HEIGHT: u32 = 2;

/// Pale Hanging Moss is non-solid: entities walk through it.
pub const HANGING_MOSS_IS_SOLID: bool = false;

/// Pale Hanging Moss is combustible.
pub const HANGING_MOSS_IS_FLAMMABLE: bool = true;

/// Minimum length of a Pale Hanging Moss column (1 block).
pub const HANGING_MOSS_MIN_LENGTH: u32 = 1;

/// Maximum length of a Pale Hanging Moss column (8 blocks).
pub const HANGING_MOSS_MAX_LENGTH: u32 = 8;

/// Shears durability consumed per harvested Pale Hanging Moss segment.
pub const SHEARS_DURABILITY_COST: u16 = 1;

/// Item drop probability when harvesting Pale Hanging Moss with Shears (100%).
pub const SHEARS_HARVEST_DROP_CHANCE: f32 = 1.0;

/// Item drop probability when breaking Pale Hanging Moss with bare hands or non-shears (0%).
pub const BARE_HAND_HARVEST_DROP_CHANCE: f32 = 0.0;

/// Horizontal radius for bonemeal spread from a Pale Moss Block (5.0 blocks).
pub const BONEMEAL_SPREAD_RADIUS: f32 = 5.0;

/// Squared horizontal radius for bonemeal spread (5.0^2 = 25.0).
pub const BONEMEAL_SPREAD_RADIUS_SQ: f32 = 25.0;

/// Vertical search range for bonemeal surface spread (+/- 5 blocks to cover floors and canopy).
pub const BONEMEAL_VERTICAL_RANGE: i32 = 5;

/// Minimum length of Pale Hanging Moss generated under leaves via bonemeal (1 block).
pub const MIN_HANGING_MOSS_BONEMEAL_LENGTH: u32 = 1;

/// Maximum length of Pale Hanging Moss generated under leaves via bonemeal (3 blocks).
pub const MAX_HANGING_MOSS_BONEMEAL_LENGTH: u32 = 3;

// ============================================================================
// Enums & Types
// ============================================================================

/// Pale Garden & World block identifiers relevant to moss dynamics.
pub const PaleBlock = enum(u16) {
    air = 0,
    stone = 1,
    dirt = 2,
    grass_block = 3,
    water = 4,
    wood = 5,
    leaves = 6,
    wood_planks = 7,
    lava = 41,
    fire = 54,
    pale_oak_log = 420,
    creaking_heart = 421,
    pale_oak_wood = 423,
    pale_oak_planks = 424,
    pale_oak_leaves = 425,
    pale_moss_block = 426,
    pale_moss_carpet = 427,
    pale_hanging_moss = 428,

    /// Whether this block is full solid.
    pub fn isSolid(self: PaleBlock) bool {
        return switch (self) {
            .stone,
            .dirt,
            .grass_block,
            .wood,
            .wood_planks,
            .pale_oak_log,
            .creaking_heart,
            .pale_oak_wood,
            .pale_oak_planks,
            .pale_moss_block,
            => true,
            .air,
            .water,
            .leaves,
            .pale_oak_leaves,
            .lava,
            .fire,
            .pale_moss_carpet,
            .pale_hanging_moss,
            => false,
        };
    }

    /// Whether this block counts as Pale Oak wood/log for trunk climbing.
    pub fn isPaleOakLogOrWood(self: PaleBlock) bool {
        return self == .pale_oak_log or self == .pale_oak_wood;
    }

    /// Whether this block is leaf foliage supporting hanging moss.
    pub fn isLeaves(self: PaleBlock) bool {
        return self == .leaves or self == .pale_oak_leaves;
    }

    /// Whether this block can serve as ceiling support for the top of a Pale Hanging Moss column.
    pub fn canSupportHangingMossCeiling(self: PaleBlock) bool {
        return self.isSolid() or self.isLeaves();
    }

    /// Whether this block is combustible by fire or lava.
    pub fn isFlammable(self: PaleBlock) bool {
        return switch (self) {
            .wood,
            .leaves,
            .wood_planks,
            .pale_oak_log,
            .pale_oak_wood,
            .pale_oak_planks,
            .pale_oak_leaves,
            .pale_moss_carpet,
            .pale_hanging_moss,
            => true,
            else => false,
        };
    }

    /// Whether this block is an ignition hazard (fire or lava).
    pub fn isIgnitionHazard(self: PaleBlock) bool {
        return self == .fire or self == .lava;
    }
};

/// Items associated with Pale Garden harvesting and spread.
pub const PaleItem = enum(u16) {
    none = 0,
    bone_meal = 128,
    shears = 240,
    pale_moss_block = 426,
    pale_moss_carpet = 427,
    pale_hanging_moss = 428,
};

/// Tool types for player interactions.
pub const ToolKind = enum {
    bare_hand,
    shears,
    sword,
    pickaxe,
    axe,
    shovel,
    hoe,

    pub fn isShears(self: ToolKind) bool {
        return self == .shears;
    }
};

/// Sound cues for auditory feedback.
pub const SoundCue = enum {
    shears_snip,
    bonemeal_sparkle,
    carpet_place,
    carpet_break,
    moss_step,
    moss_break,
    fire_ignite,
    none,
};

/// Particle colors for bonemeal sparkles.
pub const ParticleColor = enum {
    green_sparkle,
    white_sparkle,
};

/// Particle emission event.
pub const ParticleEvent = struct {
    x: f32,
    y: f32,
    z: f32,
    color: ParticleColor,
    count: u8,
};

/// 3D integer coordinate position.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) BlockPos {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn up(self: BlockPos) BlockPos {
        return .{ .x = self.x, .y = self.y + 1, .z = self.z };
    }

    pub fn down(self: BlockPos) BlockPos {
        return .{ .x = self.x, .y = self.y - 1, .z = self.z };
    }

    pub fn north(self: BlockPos) BlockPos {
        return .{ .x = self.x, .y = self.y, .z = self.z - 1 };
    }

    pub fn south(self: BlockPos) BlockPos {
        return .{ .x = self.x, .y = self.y, .z = self.z + 1 };
    }

    pub fn east(self: BlockPos) BlockPos {
        return .{ .x = self.x + 1, .y = self.y, .z = self.z };
    }

    pub fn west(self: BlockPos) BlockPos {
        return .{ .x = self.x - 1, .y = self.y, .z = self.z };
    }

    pub fn offset(self: BlockPos, dx: i32, dy: i32, dz: i32) BlockPos {
        return .{ .x = self.x + dx, .y = self.y + dy, .z = self.z + dz };
    }

    pub fn horizontalDistSq(self: BlockPos, other: BlockPos) f32 {
        const dx: f32 = @floatFromInt(self.x - other.x);
        const dz: f32 = @floatFromInt(self.z - other.z);
        return (dx * dx) + (dz * dz);
    }

    pub fn distSq(self: BlockPos, other: BlockPos) f32 {
        const dx: f32 = @floatFromInt(self.x - other.x);
        const dy: f32 = @floatFromInt(self.y - other.y);
        const dz: f32 = @floatFromInt(self.z - other.z);
        return (dx * dx) + (dy * dy) + (dz * dz);
    }

    pub fn eql(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }
};

/// Cardinal direction for wall climbing.
pub const CardinalSide = enum {
    north, // attached to block to north (z - 1)
    south, // attached to block to south (z + 1)
    east,  // attached to block to east (x + 1)
    west,  // attached to block to west (x - 1)
};

/// Attachment state of Pale Moss Carpet within its block space.
/// In Minecraft 1.21.4, Pale Moss Carpet can attach to the floor (bottom face)
/// and/or wrap up adjacent vertical faces (north, south, east, west) of solid blocks/logs.
pub const CarpetSides = struct {
    bottom: bool = true,
    north: bool = false,
    south: bool = false,
    east: bool = false,
    west: bool = false,

    pub fn hasAnyFace(self: CarpetSides) bool {
        return self.bottom or self.north or self.south or self.east or self.west;
    }

    pub fn faceCount(self: CarpetSides) u8 {
        var count: u8 = 0;
        if (self.bottom) count += 1;
        if (self.north) count += 1;
        if (self.south) count += 1;
        if (self.east) count += 1;
        if (self.west) count += 1;
        return count;
    }

    pub fn floorOnly() CarpetSides {
        return .{ .bottom = true, .north = false, .south = false, .east = false, .west = false };
    }

    pub fn wallOnly(side: CardinalSide) CarpetSides {
        var s = CarpetSides{ .bottom = false };
        switch (side) {
            .north => s.north = true,
            .south => s.south = true,
            .east => s.east = true,
            .west => s.west = true,
        }
        return s;
    }
};

/// Segment information for a Pale Hanging Moss block.
pub const HangingMossSegment = struct {
    pos: BlockPos,
    is_tip: bool,
    age_or_length: u32,
};

/// Result of harvesting a Pale Hanging Moss segment.
pub const HarvestResult = struct {
    success: bool,
    items_dropped: u32,
    dropped_item: PaleItem,
    shears_durability_consumed: u16,
    sound: SoundCue,
};

/// Result of cascade breaking a Pale Hanging Moss column.
pub const CascadeBreakResult = struct {
    total_segments_broken: u32,
    items_dropped: u32,
    dropped_item: PaleItem,
    shears_durability_consumed: u16,
    sound: SoundCue,
};

/// Result of applying Bonemeal to a Pale Moss Block.
pub const BonemealSpreadResult = struct {
    success: bool,
    bonemeal_consumed: bool,
    carpets_placed: u32,
    wall_carpets_placed: u32,
    hanging_moss_placed: u32,
    hanging_moss_columns_generated: u32,
    total_blocks_placed: u32,
    particles_emitted: u32,
    sound: SoundCue,
    particle_events: [16]ParticleEvent,
    particle_event_count: usize,
};

// ============================================================================
// Core Mechanics Functions
// ============================================================================

/// Returns the collision/visual height of Pale Moss Carpet (0.0625m = 1/16th block).
pub fn getCarpetHeight() f32 {
    return CARPET_HEIGHT;
}

/// Checks whether Pale Moss Carpet is non-solid.
pub fn isCarpetSolid() bool {
    return CARPET_IS_SOLID;
}

/// Checks whether Pale Hanging Moss is non-solid.
pub fn isHangingMossSolid() bool {
    return HANGING_MOSS_IS_SOLID;
}

/// Validates whether a Pale Moss Carpet placement is supported by neighbor solid blocks.
pub fn isCarpetSupported(
    sides: CarpetSides,
    block_below: PaleBlock,
    block_north: PaleBlock,
    block_south: PaleBlock,
    block_east: PaleBlock,
    block_west: PaleBlock,
) bool {
    if (!sides.hasAnyFace()) return false;

    // Floor face requires solid top face below
    if (sides.bottom and block_below.isSolid()) {
        return true;
    }

    // Wall faces require solid side blocks
    if (sides.north and block_north.isSolid()) return true;
    if (sides.south and block_south.isSolid()) return true;
    if (sides.east and block_east.isSolid()) return true;
    if (sides.west and block_west.isSolid()) return true;

    return false;
}

/// Validates whether a Pale Hanging Moss segment is supported from above.
/// The block directly above (y + 1) must be:
/// - A solid block OR leaves (if this is the top segment)
/// - Another Pale Hanging Moss block (if this is an attached lower segment)
pub fn isHangingMossSupported(block_above: PaleBlock) bool {
    return block_above.canSupportHangingMossCeiling() or block_above == .pale_hanging_moss;
}

/// Evaluates shears vs. bare hand / other tool harvest for Pale Hanging Moss.
pub fn harvestHangingMossWithTool(tool: ToolKind) HarvestResult {
    if (tool.isShears()) {
        return .{
            .success = true,
            .items_dropped = 1,
            .dropped_item = .pale_hanging_moss,
            .shears_durability_consumed = SHEARS_DURABILITY_COST,
            .sound = .shears_snip,
        };
    } else {
        return .{
            .success = true,
            .items_dropped = 0,
            .dropped_item = .none,
            .shears_durability_consumed = 0,
            .sound = .moss_break,
        };
    }
}

/// Checks if an adjacent neighbor is fire or lava, causing combustible moss to combust.
pub fn isCombustedByNeighbors(
    neighbors: [6]PaleBlock, // up, down, north, south, east, west
) bool {
    for (neighbors) |n| {
        if (n.isIgnitionHazard()) return true;
    }
    return false;
}

// ============================================================================
// Simulation World Container
// ============================================================================

/// A bounded 3D simulation volume for world interaction and test validation.
/// Coordinates are centered with bounds [-16..16] in x, z and [0..32] in y.
pub const PaleMossWorld = struct {
    pub const DIM_XZ: usize = 33;
    pub const DIM_Y: usize = 33;
    pub const OFFSET_XZ: i32 = 16;
    pub const OFFSET_Y: i32 = 0;

    blocks: [DIM_XZ][DIM_Y][DIM_XZ]PaleBlock,
    carpet_sides: [DIM_XZ][DIM_Y][DIM_XZ]CarpetSides,
    hanging_tip: [DIM_XZ][DIM_Y][DIM_XZ]bool,

    pub fn init() PaleMossWorld {
        var w = PaleMossWorld{
            .blocks = undefined,
            .carpet_sides = undefined,
            .hanging_tip = undefined,
        };
        w.clear();
        return w;
    }

    pub fn clear(self: *PaleMossWorld) void {
        for (0..DIM_XZ) |x| {
            for (0..DIM_Y) |y| {
                for (0..DIM_XZ) |z| {
                    self.blocks[x][y][z] = .air;
                    self.carpet_sides[x][y][z] = .{ .bottom = false };
                    self.hanging_tip[x][y][z] = false;
                }
            }
        }
    }

    fn toIndex(pos: BlockPos) ?struct { x: usize, y: usize, z: usize } {
        const ix = pos.x + OFFSET_XZ;
        const iy = pos.y + OFFSET_Y;
        const iz = pos.z + OFFSET_XZ;
        if (ix < 0 or ix >= @as(i32, @intCast(DIM_XZ))) return null;
        if (iy < 0 or iy >= @as(i32, @intCast(DIM_Y))) return null;
        if (iz < 0 or iz >= @as(i32, @intCast(DIM_XZ))) return null;
        return .{
            .x = @as(usize, @intCast(ix)),
            .y = @as(usize, @intCast(iy)),
            .z = @as(usize, @intCast(iz)),
        };
    }

    pub fn getBlock(self: *const PaleMossWorld, pos: BlockPos) PaleBlock {
        const idx = toIndex(pos) orelse return .air;
        return self.blocks[idx.x][idx.y][idx.z];
    }

    pub fn setBlock(self: *PaleMossWorld, pos: BlockPos, block: PaleBlock) bool {
        const idx = toIndex(pos) orelse return false;
        self.blocks[idx.x][idx.y][idx.z] = block;
        if (block != .pale_moss_carpet) {
            self.carpet_sides[idx.x][idx.y][idx.z] = .{ .bottom = false };
        }
        if (block != .pale_hanging_moss) {
            self.hanging_tip[idx.x][idx.y][idx.z] = false;
        }
        return true;
    }

    pub fn getCarpetSides(self: *const PaleMossWorld, pos: BlockPos) CarpetSides {
        const idx = toIndex(pos) orelse return .{ .bottom = false };
        return self.carpet_sides[idx.x][idx.y][idx.z];
    }

    pub fn isHangingTip(self: *const PaleMossWorld, pos: BlockPos) bool {
        const idx = toIndex(pos) orelse return false;
        return self.hanging_tip[idx.x][idx.y][idx.z];
    }

    /// Attempts to place Pale Moss Carpet at `pos`.
    /// If carpet already exists at `pos`, merges new sides into existing coverage.
    pub fn placeCarpet(self: *PaleMossWorld, pos: BlockPos, sides: CarpetSides) bool {
        const current = self.getBlock(pos);
        if (current != .air and current != .pale_moss_carpet) return false;

        const supported = isCarpetSupported(
            sides,
            self.getBlock(pos.down()),
            self.getBlock(pos.north()),
            self.getBlock(pos.south()),
            self.getBlock(pos.east()),
            self.getBlock(pos.west()),
        );
        if (!supported) return false;

        const idx = toIndex(pos) orelse return false;
        self.blocks[idx.x][idx.y][idx.z] = .pale_moss_carpet;

        if (current == .pale_moss_carpet) {
            var existing = self.carpet_sides[idx.x][idx.y][idx.z];
            if (sides.bottom) existing.bottom = true;
            if (sides.north) existing.north = true;
            if (sides.south) existing.south = true;
            if (sides.east) existing.east = true;
            if (sides.west) existing.west = true;
            self.carpet_sides[idx.x][idx.y][idx.z] = existing;
        } else {
            self.carpet_sides[idx.x][idx.y][idx.z] = sides;
        }
        return true;
    }

    /// Verifies if carpet at `pos` is still supported; if not, removes it and returns true (popped).
    pub fn updateCarpetSupport(self: *PaleMossWorld, pos: BlockPos) bool {
        if (self.getBlock(pos) != .pale_moss_carpet) return false;
        const sides = self.getCarpetSides(pos);
        const supported = isCarpetSupported(
            sides,
            self.getBlock(pos.down()),
            self.getBlock(pos.north()),
            self.getBlock(pos.south()),
            self.getBlock(pos.east()),
            self.getBlock(pos.west()),
        );
        if (!supported) {
            _ = self.setBlock(pos, .air);
            return true; // popped!
        }
        return false;
    }

    /// Breaks a block with a given tool, returning drops and durability consumption.
    pub fn breakBlock(
        self: *PaleMossWorld,
        pos: BlockPos,
        tool: ToolKind,
        shears_durability: ?*u16,
    ) HarvestResult {
        const block = self.getBlock(pos);
        switch (block) {
            .pale_moss_carpet => {
                _ = self.setBlock(pos, .air);
                return .{
                    .success = true,
                    .items_dropped = 1,
                    .dropped_item = .pale_moss_carpet,
                    .shears_durability_consumed = 0,
                    .sound = .carpet_break,
                };
            },
            .pale_hanging_moss => {
                const res = harvestHangingMossWithTool(tool);
                _ = self.setBlock(pos, .air);
                if (res.shears_durability_consumed > 0 and shears_durability != null) {
                    if (shears_durability.?.* >= res.shears_durability_consumed) {
                        shears_durability.?.* -= res.shears_durability_consumed;
                    } else {
                        shears_durability.?.* = 0;
                    }
                }
                return res;
            },
            else => {
                _ = self.setBlock(pos, .air);
                return .{
                    .success = true,
                    .items_dropped = 0,
                    .dropped_item = .none,
                    .shears_durability_consumed = 0,
                    .sound = .moss_break,
                };
            },
        }
    }

    /// Places a Pale Hanging Moss block at `pos`.
    pub fn placeHangingMoss(self: *PaleMossWorld, pos: BlockPos, is_tip: bool) bool {
        const current = self.getBlock(pos);
        if (current != .air and current != .pale_hanging_moss) return false;

        const block_above = self.getBlock(pos.up());
        if (!isHangingMossSupported(block_above)) return false;

        const idx = toIndex(pos) orelse return false;
        self.blocks[idx.x][idx.y][idx.z] = .pale_hanging_moss;
        self.hanging_tip[idx.x][idx.y][idx.z] = is_tip;
        return true;
    }

    /// Measures the length of the Pale Hanging Moss column starting at `start_pos` (any segment in column).
    pub fn getHangingMossColumnLength(self: *const PaleMossWorld, start_pos: BlockPos) u32 {
        if (self.getBlock(start_pos) != .pale_hanging_moss) return 0;

        // Traverse upwards to find top
        var curr = start_pos;
        while (self.getBlock(curr.up()) == .pale_hanging_moss) {
            curr = curr.up();
        }
        // Traverse downwards to count total segments
        var count: u32 = 0;
        while (self.getBlock(curr) == .pale_hanging_moss) {
            count += 1;
            curr = curr.down();
        }
        return count;
    }

    /// Finds the tip position of a Pale Hanging Moss column containing `any_pos`.
    pub fn getHangingMossTipPos(self: *const PaleMossWorld, any_pos: BlockPos) ?BlockPos {
        if (self.getBlock(any_pos) != .pale_hanging_moss) return null;
        var curr = any_pos;
        while (self.getBlock(curr.down()) == .pale_hanging_moss) {
            curr = curr.down();
        }
        return curr;
    }

    /// Ticks downward vertical tip growth for a hanging moss column.
    /// Extends the column downwards into air if length < 8.
    pub fn growHangingMossTip(self: *PaleMossWorld, any_pos: BlockPos) ?BlockPos {
        const tip_pos = self.getHangingMossTipPos(any_pos) orelse return null;
        const current_len = self.getHangingMossColumnLength(tip_pos);

        // Maximum length is 8 blocks
        if (current_len >= HANGING_MOSS_MAX_LENGTH) return null;

        // Space below must be air
        const new_pos = tip_pos.down();
        if (self.getBlock(new_pos) != .air) return null;

        // Demote previous tip to body segment
        const old_idx = toIndex(tip_pos) orelse return null;
        self.hanging_tip[old_idx.x][old_idx.y][old_idx.z] = false;

        // Place new tip segment below
        _ = self.placeHangingMoss(new_pos, true);
        return new_pos;
    }

    /// Cascade breaks all hanging moss segments below `broken_pos`.
    /// Segments above `broken_pos` remain attached if their upper support is intact.
    /// The surviving segment immediately above becomes the new bottom tip.
    pub fn cascadeBreakHangingMoss(
        self: *PaleMossWorld,
        broken_pos: BlockPos,
        harvest_tool: ToolKind,
    ) CascadeBreakResult {
        var broken_count: u32 = 0;
        var items_dropped: u32 = 0;
        var shears_used: u16 = 0;

        var curr = broken_pos;
        var is_first = true;

        while (self.getBlock(curr) == .pale_hanging_moss) {
            _ = self.setBlock(curr, .air);
            broken_count += 1;

            if (is_first) {
                // The directly targeted segment interacts with the tool
                if (harvest_tool.isShears()) {
                    items_dropped += 1;
                    shears_used += SHEARS_DURABILITY_COST;
                }
                is_first = false;
            }

            curr = curr.down();
        }

        // If a surviving segment exists directly above, promote it to tip
        if (self.getBlock(broken_pos.up()) == .pale_hanging_moss) {
            if (toIndex(broken_pos.up())) |up_idx| {
                self.hanging_tip[up_idx.x][up_idx.y][up_idx.z] = true;
            }
        }

        return .{
            .total_segments_broken = broken_count,
            .items_dropped = items_dropped,
            .dropped_item = if (items_dropped > 0) .pale_hanging_moss else .none,
            .shears_durability_consumed = shears_used,
            .sound = if (harvest_tool.isShears()) .shears_snip else .moss_break,
        };
    }

    /// Checks if a block at `pos` ignites from adjacent fire or lava and burns away.
    pub fn checkAndApplyFlammability(self: *PaleMossWorld, pos: BlockPos) bool {
        const block = self.getBlock(pos);
        if (!block.isFlammable()) return false;

        const neighbors = [6]PaleBlock{
            self.getBlock(pos.up()),
            self.getBlock(pos.down()),
            self.getBlock(pos.north()),
            self.getBlock(pos.south()),
            self.getBlock(pos.east()),
            self.getBlock(pos.west()),
        };

        if (isCombustedByNeighbors(neighbors)) {
            // Ignites and is consumed
            _ = self.setBlock(pos, .fire);
            return true;
        }
        return false;
    }

    /// Applies bonemeal to a Pale Moss Block at `target_pos`.
    /// Radiates spread outwards across solid floor blocks within a 5-block horizontal radius (dx^2 + dz^2 <= 25.0).
    /// - Generates Pale Moss Carpet on eligible solid top faces.
    /// - Climbs vertically up side faces of Pale Oak wood/logs (up to 2 blocks high).
    /// - Generates downward hanging Pale Hanging Moss beneath adjacent Pale Oak leaf blocks (1 to 3 blocks length).
    /// - Consumes 1 bonemeal and emits green/white sparkle particles.
    pub fn applyBonemeal(
        self: *PaleMossWorld,
        target_pos: BlockPos,
        bonemeal_available: *u32,
    ) BonemealSpreadResult {
        var res = BonemealSpreadResult{
            .success = false,
            .bonemeal_consumed = false,
            .carpets_placed = 0,
            .wall_carpets_placed = 0,
            .hanging_moss_placed = 0,
            .hanging_moss_columns_generated = 0,
            .total_blocks_placed = 0,
            .particles_emitted = 0,
            .sound = .none,
            .particle_events = undefined,
            .particle_event_count = 0,
        };

        // Must target a Pale Moss Block
        if (self.getBlock(target_pos) != .pale_moss_block) {
            return res;
        }

        // Must have at least 1 bonemeal item
        if (bonemeal_available.* == 0) {
            return res;
        }

        // Consume 1 bonemeal
        bonemeal_available.* -= 1;
        res.success = true;
        res.bonemeal_consumed = true;

        var carpets_placed: u32 = 0;
        var wall_carpets_placed: u32 = 0;
        var hanging_placed: u32 = 0;
        var hanging_cols: u32 = 0;

        // Radiate spread within 5-block horizontal radius: dx^2 + dz^2 <= 25.0
        var dx: i32 = -5;
        while (dx <= 5) : (dx += 1) {
            var dz: i32 = -5;
            while (dz <= 5) : (dz += 1) {
                const dist_sq: f32 = @floatFromInt((dx * dx) + (dz * dz));
                if (dist_sq > BONEMEAL_SPREAD_RADIUS_SQ) continue;

                const curr_x = target_pos.x + dx;
                const curr_z = target_pos.z + dz;

                // Search vertically for solid floor surfaces and canopies
                var dy: i32 = -BONEMEAL_VERTICAL_RANGE;
                while (dy <= BONEMEAL_VERTICAL_RANGE) : (dy += 1) {
                    const floor_pos = BlockPos.init(curr_x, target_pos.y + dy, curr_z);
                    const floor_block = self.getBlock(floor_pos);
                    const above_pos = floor_pos.up();
                    const above_block = self.getBlock(above_pos);

                    // 1. Floor carpet placement on solid top face
                    if (floor_block.isSolid() and above_block == .air) {
                        if (self.placeCarpet(above_pos, CarpetSides.floorOnly())) {
                            carpets_placed += 1;
                        }
                    }

                    // 2. Pale Oak log vertical wall climbing (up to 2 blocks high)
                    if (floor_block.isPaleOakLogOrWood() and (floor_pos.y == target_pos.y or !self.getBlock(floor_pos.down()).isPaleOakLogOrWood())) {
                        const cardinal_offsets = [_]struct { side: CardinalSide, pos: BlockPos }{
                            .{ .side = .north, .pos = floor_pos.south() }, // south of log -> north face
                            .{ .side = .south, .pos = floor_pos.north() }, // north of log -> south face
                            .{ .side = .east, .pos = floor_pos.west() },   // west of log -> east face
                            .{ .side = .west, .pos = floor_pos.east() },   // east of log -> west face
                        };

                        for (cardinal_offsets) |co| {
                            var climb_step: u32 = 1;
                            while (climb_step <= MAX_LOG_CLIMB_HEIGHT) : (climb_step += 1) {
                                const climb_pos = BlockPos.init(co.pos.x, floor_pos.y + @as(i32, @intCast(climb_step)), co.pos.z);
                                const adjacent_trunk = BlockPos.init(floor_pos.x, floor_pos.y + @as(i32, @intCast(climb_step)), floor_pos.z);

                                if (self.getBlock(adjacent_trunk).isPaleOakLogOrWood() and self.getBlock(climb_pos) == .air) {
                                    if (self.placeCarpet(climb_pos, CarpetSides.wallOnly(co.side))) {
                                        wall_carpets_placed += 1;
                                    }
                                }
                            }
                        }
                    }

                    // 3. Pale Oak leaf canopy: downward hanging Pale Hanging Moss (1 to 3 blocks)
                    if (floor_block.isLeaves()) {
                        const beneath_pos = floor_pos.down();
                        if (self.getBlock(beneath_pos) == .air) {
                            var gen_len: u32 = 0;
                            var moss_cursor = beneath_pos;
                            const target_length: u32 = 1 + (@as(u32, @intCast(@abs(dx + dz))) % 3); // 1..3 blocks

                            while (gen_len < target_length and self.getBlock(moss_cursor) == .air) {
                                const is_tip = (gen_len + 1 == target_length) or (self.getBlock(moss_cursor.down()) != .air);
                                if (self.placeHangingMoss(moss_cursor, is_tip)) {
                                    hanging_placed += 1;
                                    gen_len += 1;
                                }
                                moss_cursor = moss_cursor.down();
                            }
                            if (gen_len > 0) {
                                hanging_cols += 1;
                            }
                        }
                    }
                }
            }
        }

        res.carpets_placed = carpets_placed;
        res.wall_carpets_placed = wall_carpets_placed;
        res.hanging_moss_placed = hanging_placed;
        res.hanging_moss_columns_generated = hanging_cols;
        res.total_blocks_placed = carpets_placed + wall_carpets_placed + hanging_placed;
        res.particles_emitted = 40;
        res.sound = .bonemeal_sparkle;

        // Generate sample sparkle particles
        var pe_idx: usize = 0;
        const target_x_f: f32 = @floatFromInt(target_pos.x);
        const target_y_f: f32 = @floatFromInt(target_pos.y);
        const target_z_f: f32 = @floatFromInt(target_pos.z);

        while (pe_idx < 16) : (pe_idx += 1) {
            const angle: f32 = @as(f32, @floatFromInt(pe_idx)) * (std.math.pi / 8.0);
            const radius: f32 = 1.5;
            res.particle_events[pe_idx] = .{
                .x = target_x_f + 0.5 + (@cos(angle) * radius),
                .y = target_y_f + 1.0,
                .z = target_z_f + 0.5 + (@sin(angle) * radius),
                .color = if (pe_idx % 2 == 0) .green_sparkle else .white_sparkle,
                .count = 4,
            };
        }
        res.particle_event_count = 16;

        return res;
    }
};

// ============================================================================
// Unit Tests (45 Comprehensive Tests)
// ============================================================================

test "1. CARPET_HEIGHT constant is exactly 0.0625m (1/16th block = 1 pixel)" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0625), getCarpetHeight(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 16.0), CARPET_HEIGHT, 0.0001);
}

test "2. Pale Moss Carpet is non-solid and walk-through" {
    try std.testing.expect(!isCarpetSolid());
    try std.testing.expect(!PaleBlock.pale_moss_carpet.isSolid());
}

test "3. Pale Hanging Moss is non-solid and walk-through" {
    try std.testing.expect(!isHangingMossSolid());
    try std.testing.expect(!PaleBlock.pale_hanging_moss.isSolid());
}

test "4. Floor carpet placement succeeds on solid top face of stone, dirt, log, and moss block" {
    const solids = [_]PaleBlock{ .stone, .dirt, .grass_block, .pale_oak_log, .pale_oak_wood, .pale_oak_planks, .pale_moss_block };
    for (solids) |solid_floor| {
        const supported = isCarpetSupported(CarpetSides.floorOnly(), solid_floor, .air, .air, .air, .air);
        try std.testing.expect(supported);
    }
}

test "5. Floor carpet placement rejects air, water, and non-solid blocks beneath" {
    const non_solids = [_]PaleBlock{ .air, .water, .leaves, .pale_oak_leaves, .fire, .lava, .pale_moss_carpet, .pale_hanging_moss };
    for (non_solids) |non_solid_floor| {
        const supported = isCarpetSupported(CarpetSides.floorOnly(), non_solid_floor, .air, .air, .air, .air);
        try std.testing.expect(!supported);
    }
}

test "6. Floor carpet attachment breaks and pops when underlying floor block is removed" {
    var world = PaleMossWorld.init();
    const floor_pos = BlockPos.init(0, 10, 0);
    const carpet_pos = floor_pos.up();

    // Place stone floor and carpet atop it
    _ = world.setBlock(floor_pos, .stone);
    try std.testing.expect(world.placeCarpet(carpet_pos, CarpetSides.floorOnly()));
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, world.getBlock(carpet_pos));

    // Support check while intact
    try std.testing.expect(!world.updateCarpetSupport(carpet_pos));

    // Remove floor
    _ = world.setBlock(floor_pos, .air);

    // Carpet must pop off
    const popped = world.updateCarpetSupport(carpet_pos);
    try std.testing.expect(popped);
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(carpet_pos));
}

test "7. Wall-climbing carpet placement requires solid side block" {
    // North wall requires solid north
    try std.testing.expect(isCarpetSupported(CarpetSides.wallOnly(.north), .air, .pale_oak_log, .air, .air, .air));
    try std.testing.expect(!isCarpetSupported(CarpetSides.wallOnly(.north), .air, .air, .air, .air, .air));

    // South wall requires solid south
    try std.testing.expect(isCarpetSupported(CarpetSides.wallOnly(.south), .air, .air, .pale_oak_wood, .air, .air));
    try std.testing.expect(!isCarpetSupported(CarpetSides.wallOnly(.south), .air, .air, .water, .air, .air));

    // East wall requires solid east
    try std.testing.expect(isCarpetSupported(CarpetSides.wallOnly(.east), .air, .air, .air, .stone, .air));
    try std.testing.expect(!isCarpetSupported(CarpetSides.wallOnly(.east), .air, .air, .air, .air, .air));

    // West wall requires solid west
    try std.testing.expect(isCarpetSupported(CarpetSides.wallOnly(.west), .air, .air, .air, .air, .dirt));
    try std.testing.expect(!isCarpetSupported(CarpetSides.wallOnly(.west), .air, .air, .air, .air, .leaves));
}

test "8. Wall-climbing carpet breaks when supporting wall block is removed" {
    var world = PaleMossWorld.init();
    const trunk_pos = BlockPos.init(2, 5, 2);
    const wall_pos = trunk_pos.south(); // z + 1, attached to north face

    _ = world.setBlock(trunk_pos, .pale_oak_log);
    try std.testing.expect(world.placeCarpet(wall_pos, CarpetSides.wallOnly(.north)));
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, world.getBlock(wall_pos));

    // Remove trunk log
    _ = world.setBlock(trunk_pos, .air);

    // Carpet pops
    try std.testing.expect(world.updateCarpetSupport(wall_pos));
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(wall_pos));
}

test "9. CarpetSides helper validates face counts and individual sides" {
    var sides = CarpetSides.floorOnly();
    try std.testing.expect(sides.hasAnyFace());
    try std.testing.expectEqual(@as(u8, 1), sides.faceCount());
    try std.testing.expect(sides.bottom);
    try std.testing.expect(!sides.north);

    sides.north = true;
    sides.east = true;
    try std.testing.expectEqual(@as(u8, 3), sides.faceCount());

    const empty = CarpetSides{ .bottom = false };
    try std.testing.expect(!empty.hasAnyFace());
    try std.testing.expectEqual(@as(u8, 0), empty.faceCount());
}

test "10. Pale Moss Carpet drops 1 pale_moss_carpet item when harvested" {
    var world = PaleMossWorld.init();
    const floor = BlockPos.init(0, 5, 0);
    const carpet = floor.up();

    _ = world.setBlock(floor, .stone);
    _ = world.placeCarpet(carpet, CarpetSides.floorOnly());

    var shears_dur: u16 = 238;
    const res = world.breakBlock(carpet, .bare_hand, &shears_dur);

    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u32, 1), res.items_dropped);
    try std.testing.expectEqual(PaleItem.pale_moss_carpet, res.dropped_item);
    try std.testing.expectEqual(@as(u16, 0), res.shears_durability_consumed);
    try std.testing.expectEqual(SoundCue.carpet_break, res.sound);
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(carpet));
}

test "11. Carpet flammability: combustible and catches fire from adjacent fire" {
    var world = PaleMossWorld.init();
    const floor = BlockPos.init(0, 5, 0);
    const carpet = floor.up();
    const fire_pos = carpet.north();

    _ = world.setBlock(floor, .stone);
    _ = world.placeCarpet(carpet, CarpetSides.floorOnly());
    _ = world.setBlock(fire_pos, .fire);

    try std.testing.expect(world.checkAndApplyFlammability(carpet));
    try std.testing.expectEqual(PaleBlock.fire, world.getBlock(carpet));
}

test "12. Carpet flammability: combustible and catches fire from adjacent lava" {
    var world = PaleMossWorld.init();
    const floor = BlockPos.init(0, 5, 0);
    const carpet = floor.up();
    const lava_pos = carpet.east();

    _ = world.setBlock(floor, .stone);
    _ = world.placeCarpet(carpet, CarpetSides.floorOnly());
    _ = world.setBlock(lava_pos, .lava);

    try std.testing.expect(world.checkAndApplyFlammability(carpet));
    try std.testing.expectEqual(PaleBlock.fire, world.getBlock(carpet));
}

test "13. Carpet flammability: safe from stone, dirt, air, and water neighbors" {
    var world = PaleMossWorld.init();
    const floor = BlockPos.init(0, 5, 0);
    const carpet = floor.up();

    _ = world.setBlock(floor, .stone);
    _ = world.placeCarpet(carpet, CarpetSides.floorOnly());
    _ = world.setBlock(carpet.north(), .dirt);
    _ = world.setBlock(carpet.south(), .water);

    try std.testing.expect(!world.checkAndApplyFlammability(carpet));
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, world.getBlock(carpet));
}

test "14. Pale Hanging Moss ceiling support accepts solid blocks and leaves" {
    try std.testing.expect(isHangingMossSupported(.stone));
    try std.testing.expect(isHangingMossSupported(.pale_oak_log));
    try std.testing.expect(isHangingMossSupported(.pale_oak_wood));
    try std.testing.expect(isHangingMossSupported(.pale_oak_leaves));
    try std.testing.expect(isHangingMossSupported(.leaves));
}

test "15. Pale Hanging Moss ceiling support rejects air and fluids" {
    try std.testing.expect(!isHangingMossSupported(.air));
    try std.testing.expect(!isHangingMossSupported(.water));
    try std.testing.expect(!isHangingMossSupported(.lava));
}

test "16. Pale Hanging Moss lower segment accepts pale_hanging_moss directly above" {
    try std.testing.expect(isHangingMossSupported(.pale_hanging_moss));
}

test "17. Pale Hanging Moss lower segment rejects air above without support" {
    var world = PaleMossWorld.init();
    const pos = BlockPos.init(0, 10, 0);
    // Directly in air with no ceiling
    try std.testing.expect(!world.placeHangingMoss(pos, true));
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(pos));
}

test "18. Pale Hanging Moss length limits: minimum 1, maximum 8" {
    try std.testing.expectEqual(@as(u32, 1), HANGING_MOSS_MIN_LENGTH);
    try std.testing.expectEqual(@as(u32, 8), HANGING_MOSS_MAX_LENGTH);
}

test "19. Pale Hanging Moss tip growth extends downward by 1 block into air" {
    var world = PaleMossWorld.init();
    const ceiling = BlockPos.init(0, 15, 0);
    const seg1 = ceiling.down(); // y = 14

    _ = world.setBlock(ceiling, .pale_oak_leaves);
    try std.testing.expect(world.placeHangingMoss(seg1, true));
    try std.testing.expectEqual(@as(u32, 1), world.getHangingMossColumnLength(seg1));

    // Grow downward
    const new_tip = world.growHangingMossTip(seg1);
    try std.testing.expect(new_tip != null);
    try std.testing.expect(new_tip.?.eql(seg1.down())); // y = 13
    try std.testing.expectEqual(@as(u32, 2), world.getHangingMossColumnLength(seg1));
    try std.testing.expectEqual(PaleBlock.pale_hanging_moss, world.getBlock(new_tip.?));
}

test "20. Tip growth updates tip flags: previous tip demoted, new bottom becomes tip" {
    var world = PaleMossWorld.init();
    const ceiling = BlockPos.init(0, 15, 0);
    const seg1 = ceiling.down();

    _ = world.setBlock(ceiling, .pale_oak_log);
    _ = world.placeHangingMoss(seg1, true);
    try std.testing.expect(world.isHangingTip(seg1));

    const seg2 = world.growHangingMossTip(seg1).?;
    try std.testing.expect(!world.isHangingTip(seg1));
    try std.testing.expect(world.isHangingTip(seg2));
}

test "21. Tip growth blocked when block below is solid or non-air" {
    var world = PaleMossWorld.init();
    const ceiling = BlockPos.init(0, 10, 0);
    const seg = ceiling.down(); // y = 9
    const obstacle = seg.down(); // y = 8

    _ = world.setBlock(ceiling, .pale_oak_leaves);
    _ = world.setBlock(obstacle, .stone);
    _ = world.placeHangingMoss(seg, true);

    const grown = world.growHangingMossTip(seg);
    try std.testing.expect(grown == null);
    try std.testing.expectEqual(@as(u32, 1), world.getHangingMossColumnLength(seg));
}

test "22. Tip growth halts when reaching maximum length of 8 blocks" {
    var world = PaleMossWorld.init();
    const ceiling = BlockPos.init(0, 20, 0);
    _ = world.setBlock(ceiling, .stone);

    // Initial segment at y = 19
    _ = world.placeHangingMoss(ceiling.down(), true);

    // Grow 7 more times to reach length 8
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        const next = world.growHangingMossTip(ceiling.down());
        try std.testing.expect(next != null);
    }
    try std.testing.expectEqual(@as(u32, 8), world.getHangingMossColumnLength(ceiling.down()));

    // 9th segment attempt must fail
    const blocked_growth = world.growHangingMossTip(ceiling.down());
    try std.testing.expect(blocked_growth == null);
    try std.testing.expectEqual(@as(u32, 8), world.getHangingMossColumnLength(ceiling.down()));
}

test "23. Cascade break: destroying ceiling block breaks all segments in column" {
    var world = PaleMossWorld.init();
    const ceiling = BlockPos.init(0, 15, 0);
    _ = world.setBlock(ceiling, .pale_oak_leaves);

    // Build 4-segment column
    _ = world.placeHangingMoss(BlockPos.init(0, 14, 0), false);
    _ = world.placeHangingMoss(BlockPos.init(0, 13, 0), false);
    _ = world.placeHangingMoss(BlockPos.init(0, 12, 0), false);
    _ = world.placeHangingMoss(BlockPos.init(0, 11, 0), true);

    try std.testing.expectEqual(@as(u32, 4), world.getHangingMossColumnLength(BlockPos.init(0, 14, 0)));

    // Destroy ceiling
    _ = world.setBlock(ceiling, .air);

    // Top segment loses support and cascades downward
    const cascade = world.cascadeBreakHangingMoss(BlockPos.init(0, 14, 0), .bare_hand);
    try std.testing.expectEqual(@as(u32, 4), cascade.total_segments_broken);
    try std.testing.expectEqual(@as(u32, 0), cascade.items_dropped);

    var y: i32 = 11;
    while (y <= 14) : (y += 1) {
        try std.testing.expectEqual(PaleBlock.air, world.getBlock(BlockPos.init(0, y, 0)));
    }
}

test "24. Cascade break: destroying middle block breaks all segments below while keeping segments above" {
    var world = PaleMossWorld.init();
    const ceiling = BlockPos.init(0, 20, 0);
    _ = world.setBlock(ceiling, .stone);

    // Column: y=19, 18, 17, 16, 15 (5 segments)
    _ = world.placeHangingMoss(BlockPos.init(0, 19, 0), false);
    _ = world.placeHangingMoss(BlockPos.init(0, 18, 0), false);
    _ = world.placeHangingMoss(BlockPos.init(0, 17, 0), false);
    _ = world.placeHangingMoss(BlockPos.init(0, 16, 0), false);
    _ = world.placeHangingMoss(BlockPos.init(0, 15, 0), true);

    // Shears break segment at y = 17 (3rd from top)
    const cascade = world.cascadeBreakHangingMoss(BlockPos.init(0, 17, 0), .shears);
    try std.testing.expectEqual(@as(u32, 3), cascade.total_segments_broken); // y=17, 16, 15
    try std.testing.expectEqual(@as(u32, 1), cascade.items_dropped);
    try std.testing.expectEqual(PaleItem.pale_hanging_moss, cascade.dropped_item);
    try std.testing.expectEqual(@as(u16, 1), cascade.shears_durability_consumed);

    // y=19 and y=18 survive
    try std.testing.expectEqual(PaleBlock.pale_hanging_moss, world.getBlock(BlockPos.init(0, 19, 0)));
    try std.testing.expectEqual(PaleBlock.pale_hanging_moss, world.getBlock(BlockPos.init(0, 18, 0)));
    try std.testing.expect(world.isHangingTip(BlockPos.init(0, 18, 0))); // promoted to tip!

    // y=17, 16, 15 broken to air
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(BlockPos.init(0, 17, 0)));
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(BlockPos.init(0, 16, 0)));
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(BlockPos.init(0, 15, 0)));
}

test "25. Cascade break: breaking bottom tip segment only removes tip, leaving upper column intact" {
    var world = PaleMossWorld.init();
    const ceiling = BlockPos.init(0, 10, 0);
    _ = world.setBlock(ceiling, .pale_oak_leaves);

    _ = world.placeHangingMoss(BlockPos.init(0, 9, 0), false);
    _ = world.placeHangingMoss(BlockPos.init(0, 8, 0), false);
    _ = world.placeHangingMoss(BlockPos.init(0, 7, 0), true);

    const cascade = world.cascadeBreakHangingMoss(BlockPos.init(0, 7, 0), .shears);
    try std.testing.expectEqual(@as(u32, 1), cascade.total_segments_broken);
    try std.testing.expectEqual(@as(u32, 1), cascade.items_dropped);

    // y=9 and y=8 remain intact
    try std.testing.expectEqual(PaleBlock.pale_hanging_moss, world.getBlock(BlockPos.init(0, 9, 0)));
    try std.testing.expectEqual(PaleBlock.pale_hanging_moss, world.getBlock(BlockPos.init(0, 8, 0)));
    try std.testing.expect(world.isHangingTip(BlockPos.init(0, 8, 0)));
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(BlockPos.init(0, 7, 0)));
}

test "26. Shears harvest: breaking hanging moss with shears guarantees 100% item drop" {
    const res = harvestHangingMossWithTool(.shears);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u32, 1), res.items_dropped);
    try std.testing.expectEqual(PaleItem.pale_hanging_moss, res.dropped_item);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), SHEARS_HARVEST_DROP_CHANCE, 0.0001);
}

test "27. Shears harvest: consuming 1 shears durability and emitting shears_snip audio cue" {
    const res = harvestHangingMossWithTool(.shears);
    try std.testing.expectEqual(@as(u16, 1), res.shears_durability_consumed);
    try std.testing.expectEqual(SoundCue.shears_snip, res.sound);
}

test "28. Bare hand break: breaking hanging moss with bare hand yields 0 item drops and 0 shears wear" {
    const res = harvestHangingMossWithTool(.bare_hand);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u32, 0), res.items_dropped);
    try std.testing.expectEqual(PaleItem.none, res.dropped_item);
    try std.testing.expectEqual(@as(u16, 0), res.shears_durability_consumed);
    try std.testing.expectEqual(SoundCue.moss_break, res.sound);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), BARE_HAND_HARVEST_DROP_CHANCE, 0.0001);
}

test "29. Non-shears tools (sword, pickaxe, axe) break moss with 0 drops and 0 shears wear" {
    const tools = [_]ToolKind{ .sword, .pickaxe, .axe, .shovel, .hoe };
    for (tools) |t| {
        const res = harvestHangingMossWithTool(t);
        try std.testing.expect(res.success);
        try std.testing.expectEqual(@as(u32, 0), res.items_dropped);
        try std.testing.expectEqual(@as(u16, 0), res.shears_durability_consumed);
    }
}

test "30. Bonemeal application on non-pale-moss block fails without consuming bonemeal" {
    var world = PaleMossWorld.init();
    const pos = BlockPos.init(0, 5, 0);
    _ = world.setBlock(pos, .stone);

    var bonemeal: u32 = 10;
    const res = world.applyBonemeal(pos, &bonemeal);

    try std.testing.expect(!res.success);
    try std.testing.expect(!res.bonemeal_consumed);
    try std.testing.expectEqual(@as(u32, 10), bonemeal);
    try std.testing.expectEqual(@as(u32, 0), res.total_blocks_placed);
}

test "31. Bonemeal application with 0 bonemeal fails" {
    var world = PaleMossWorld.init();
    const pos = BlockPos.init(0, 5, 0);
    _ = world.setBlock(pos, .pale_moss_block);

    var bonemeal: u32 = 0;
    const res = world.applyBonemeal(pos, &bonemeal);

    try std.testing.expect(!res.success);
    try std.testing.expect(!res.bonemeal_consumed);
    try std.testing.expectEqual(@as(u32, 0), bonemeal);
}

test "32. Bonemeal application on Pale Moss Block consumes exactly 1 bonemeal" {
    var world = PaleMossWorld.init();
    const pos = BlockPos.init(0, 5, 0);
    _ = world.setBlock(pos, .pale_moss_block);

    var bonemeal: u32 = 5;
    const res = world.applyBonemeal(pos, &bonemeal);

    try std.testing.expect(res.success);
    try std.testing.expect(res.bonemeal_consumed);
    try std.testing.expectEqual(@as(u32, 4), bonemeal);
}

test "33. Bonemeal application emits green/white sparkle particles and sound cue" {
    var world = PaleMossWorld.init();
    const pos = BlockPos.init(0, 5, 0);
    _ = world.setBlock(pos, .pale_moss_block);

    var bonemeal: u32 = 1;
    const res = world.applyBonemeal(pos, &bonemeal);

    try std.testing.expect(res.success);
    try std.testing.expectEqual(SoundCue.bonemeal_sparkle, res.sound);
    try std.testing.expect(res.particles_emitted > 0);
    try std.testing.expect(res.particle_event_count > 0);

    var has_green = false;
    var has_white = false;
    for (res.particle_events[0..res.particle_event_count]) |pe| {
        if (pe.color == .green_sparkle) has_green = true;
        if (pe.color == .white_sparkle) has_white = true;
    }
    try std.testing.expect(has_green);
    try std.testing.expect(has_white);
}

test "34. Bonemeal radial spread adheres strictly to 5-block horizontal radius (dx^2 + dz^2 <= 25.0)" {
    var world = PaleMossWorld.init();
    const center = BlockPos.init(0, 5, 0);
    _ = world.setBlock(center, .pale_moss_block);

    // Lay a large stone plane from x = -8..8 and z = -8..8 at y = 5
    var x: i32 = -8;
    while (x <= 8) : (x += 1) {
        var z: i32 = -8;
        while (z <= 8) : (z += 1) {
            if (x == 0 and z == 0) continue;
            _ = world.setBlock(BlockPos.init(x, 5, z), .stone);
        }
    }

    var bonemeal: u32 = 1;
    const res = world.applyBonemeal(center, &bonemeal);
    try std.testing.expect(res.success);
    try std.testing.expect(res.carpets_placed > 0);

    // Verify carpet presence inside radius and absence outside radius
    var check_x: i32 = -8;
    while (check_x <= 8) : (check_x += 1) {
        var check_z: i32 = -8;
        while (check_z <= 8) : (check_z += 1) {
            const dist_sq = (check_x * check_x) + (check_z * check_z);
            const carpet_block = world.getBlock(BlockPos.init(check_x, 6, check_z));

            if (dist_sq <= 25) {
                // Inside radius 5: carpet placed!
                try std.testing.expectEqual(PaleBlock.pale_moss_carpet, carpet_block);
            } else {
                // Outside radius 5: strictly air!
                try std.testing.expectEqual(PaleBlock.air, carpet_block);
            }
        }
    }
}

test "35. Bonemeal radial spread places carpets on eligible solid floor faces within radius" {
    var world = PaleMossWorld.init();
    const center = BlockPos.init(0, 5, 0);
    _ = world.setBlock(center, .pale_moss_block);

    // Floor of dirt at y = 5, (1, 5, 1) and (2, 5, -2)
    _ = world.setBlock(BlockPos.init(1, 5, 1), .dirt);
    _ = world.setBlock(BlockPos.init(2, 5, -2), .dirt);

    var bonemeal: u32 = 1;
    const res = world.applyBonemeal(center, &bonemeal);

    try std.testing.expect(res.carpets_placed >= 2);
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, world.getBlock(BlockPos.init(1, 6, 1)));
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, world.getBlock(BlockPos.init(2, 6, -2)));
}

test "36. Bonemeal does not place carpet on non-solid or already occupied blocks" {
    var world = PaleMossWorld.init();
    const center = BlockPos.init(0, 5, 0);
    _ = world.setBlock(center, .pale_moss_block);

    // Water pool at (1, 5, 0)
    _ = world.setBlock(BlockPos.init(1, 5, 0), .water);

    var bonemeal: u32 = 1;
    _ = world.applyBonemeal(center, &bonemeal);

    // Carpet must not be placed on water
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(BlockPos.init(1, 6, 0)));
}

test "37. Bonemeal vertical trunk climb: generates wall carpet up Pale Oak log/wood up to 2 blocks high" {
    var world = PaleMossWorld.init();
    const center = BlockPos.init(0, 5, 0);
    _ = world.setBlock(center, .pale_moss_block);

    // Place a Pale Oak tree trunk at x = 2, z = 0 extending from y = 5 up to y = 9
    _ = world.setBlock(BlockPos.init(2, 5, 0), .pale_oak_log);
    _ = world.setBlock(BlockPos.init(2, 6, 0), .pale_oak_log);
    _ = world.setBlock(BlockPos.init(2, 7, 0), .pale_oak_log);
    _ = world.setBlock(BlockPos.init(2, 8, 0), .pale_oak_log);

    var bonemeal: u32 = 1;
    const res = world.applyBonemeal(center, &bonemeal);

    try std.testing.expect(res.wall_carpets_placed > 0);

    // Log side face at (1, 6, 0) - step 1
    const climb1 = world.getBlock(BlockPos.init(1, 6, 0));
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, climb1);

    // Log side face at (1, 7, 0) - step 2
    const climb2 = world.getBlock(BlockPos.init(1, 7, 0));
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, climb2);
}

test "38. Bonemeal vertical trunk climb: stops climbing beyond 2 blocks high" {
    var world = PaleMossWorld.init();
    const center = BlockPos.init(0, 5, 0);
    _ = world.setBlock(center, .pale_moss_block);

    // Tall Pale Oak trunk at x = 2, z = 0 from y = 5 up to y = 12
    var y: i32 = 5;
    while (y <= 12) : (y += 1) {
        _ = world.setBlock(BlockPos.init(2, y, 0), .pale_oak_log);
    }

    var bonemeal: u32 = 1;
    _ = world.applyBonemeal(center, &bonemeal);

    // y = 8 is 3 blocks above ground level y = 5 -> must NOT be carpet
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(BlockPos.init(1, 8, 0)));
    try std.testing.expectEqual(PaleBlock.air, world.getBlock(BlockPos.init(3, 8, 0)));
}

test "39. Bonemeal canopy interaction: generates downward hanging moss under Pale Oak leaves (1 to 3 blocks)" {
    var world = PaleMossWorld.init();
    const center = BlockPos.init(0, 5, 0);
    _ = world.setBlock(center, .pale_moss_block);

    // Canopy leaves at x = 1, z = 1, y = 8
    const leaf_pos = BlockPos.init(1, 8, 1);
    _ = world.setBlock(leaf_pos, .pale_oak_leaves);

    var bonemeal: u32 = 1;
    const res = world.applyBonemeal(center, &bonemeal);

    try std.testing.expect(res.hanging_moss_placed > 0);
    try std.testing.expect(res.hanging_moss_columns_generated > 0);

    // Check segment directly below leaves
    const hang1 = world.getBlock(leaf_pos.down()); // y = 7
    try std.testing.expectEqual(PaleBlock.pale_hanging_moss, hang1);
}

test "40. Bonemeal canopy interaction: avoids hanging moss if space beneath leaves is obstructed" {
    var world = PaleMossWorld.init();
    const center = BlockPos.init(0, 5, 0);
    _ = world.setBlock(center, .pale_moss_block);

    // Canopy leaves at x = 1, z = 1, y = 8, with solid stone directly beneath at y = 7
    const leaf_pos = BlockPos.init(1, 8, 1);
    _ = world.setBlock(leaf_pos, .pale_oak_leaves);
    _ = world.setBlock(leaf_pos.down(), .stone);

    var bonemeal: u32 = 1;
    const res = world.applyBonemeal(center, &bonemeal);

    // Hanging moss could not be placed beneath obstructed leaves
    try std.testing.expectEqual(@as(u32, 0), res.hanging_moss_columns_generated);
}

test "41. BlockPos distance calculations and directional navigation" {
    const p1 = BlockPos.init(1, 2, 3);
    const p2 = BlockPos.init(4, 6, 3);

    // horizontal dx = 3, dz = 0 -> 9.0
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), p1.horizontalDistSq(p2), 0.0001);

    // total dx = 3, dy = 4, dz = 0 -> 9 + 16 = 25.0
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), p1.distSq(p2), 0.0001);

    try std.testing.expect(p1.up().eql(BlockPos.init(1, 3, 3)));
    try std.testing.expect(p1.down().eql(BlockPos.init(1, 1, 3)));
    try std.testing.expect(p1.north().eql(BlockPos.init(1, 2, 2)));
    try std.testing.expect(p1.south().eql(BlockPos.init(1, 2, 4)));
    try std.testing.expect(p1.east().eql(BlockPos.init(2, 2, 3)));
    try std.testing.expect(p1.west().eql(BlockPos.init(0, 2, 3)));
}

test "42. PaleBlock classification predicates and support checks" {
    try std.testing.expect(PaleBlock.pale_oak_log.isPaleOakLogOrWood());
    try std.testing.expect(PaleBlock.pale_oak_wood.isPaleOakLogOrWood());
    try std.testing.expect(!PaleBlock.pale_oak_planks.isPaleOakLogOrWood());

    try std.testing.expect(PaleBlock.pale_oak_leaves.isLeaves());
    try std.testing.expect(PaleBlock.leaves.isLeaves());
    try std.testing.expect(!PaleBlock.pale_oak_log.isLeaves());

    try std.testing.expect(PaleBlock.fire.isIgnitionHazard());
    try std.testing.expect(PaleBlock.lava.isIgnitionHazard());
    try std.testing.expect(!PaleBlock.water.isIgnitionHazard());

    try std.testing.expect(PaleBlock.pale_moss_carpet.isFlammable());
    try std.testing.expect(PaleBlock.pale_hanging_moss.isFlammable());
    try std.testing.expect(!PaleBlock.stone.isFlammable());
}

test "43. Full lifecycle: bonemeal growth -> trunk climb -> leaf hanging moss -> shears harvest -> cascade break" {
    var world = PaleMossWorld.init();

    // 1. Setup scene: moss block in center, trunk at (2, 5, 0), leaves at (0, 9, 2)
    const center = BlockPos.init(0, 5, 0);
    _ = world.setBlock(center, .pale_moss_block);
    _ = world.setBlock(BlockPos.init(1, 5, 0), .dirt);

    // Trunk
    _ = world.setBlock(BlockPos.init(2, 5, 0), .pale_oak_log);
    _ = world.setBlock(BlockPos.init(2, 6, 0), .pale_oak_log);
    _ = world.setBlock(BlockPos.init(2, 7, 0), .pale_oak_log);

    // Canopy leaf
    _ = world.setBlock(BlockPos.init(0, 9, 2), .pale_oak_leaves);

    // 2. Apply bonemeal
    var bonemeal: u32 = 1;
    const spread = world.applyBonemeal(center, &bonemeal);

    try std.testing.expect(spread.success);
    try std.testing.expect(spread.bonemeal_consumed);
    try std.testing.expect(spread.carpets_placed > 0);
    try std.testing.expect(spread.wall_carpets_placed > 0);
    try std.testing.expect(spread.hanging_moss_placed > 0);

    // 3. Verify carpet placed on dirt floor
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, world.getBlock(BlockPos.init(1, 6, 0)));

    // 4. Verify wall carpet climbed up trunk
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, world.getBlock(BlockPos.init(1, 6, 0)));
    try std.testing.expectEqual(PaleBlock.pale_moss_carpet, world.getBlock(BlockPos.init(1, 7, 0)));

    // 5. Verify hanging moss under leaves at (0, 8, 2)
    const moss_top = BlockPos.init(0, 8, 2);
    try std.testing.expectEqual(PaleBlock.pale_hanging_moss, world.getBlock(moss_top));

    // 6. Harvest top hanging moss with shears
    var shears_dur: u16 = 100;
    const harvest = world.breakBlock(moss_top, .shears, &shears_dur);
    try std.testing.expect(harvest.success);
    try std.testing.expectEqual(@as(u32, 1), harvest.items_dropped);
    try std.testing.expectEqual(PaleItem.pale_hanging_moss, harvest.dropped_item);
    try std.testing.expectEqual(@as(u16, 99), shears_dur);

    // 7. Dependent segments below cascade break to air
    if (world.getBlock(moss_top.down()) == .pale_hanging_moss) {
        _ = world.cascadeBreakHangingMoss(moss_top.down(), .bare_hand);
        try std.testing.expectEqual(PaleBlock.air, world.getBlock(moss_top.down()));
    }
}

test "44. Shears durability floor: durability never underflows below 0" {
    var world = PaleMossWorld.init();
    const ceiling = BlockPos.init(0, 10, 0);
    const moss = ceiling.down();

    _ = world.setBlock(ceiling, .stone);
    _ = world.placeHangingMoss(moss, true);

    var shears_dur: u16 = 0; // completely broken shears
    const res = world.breakBlock(moss, .shears, &shears_dur);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u16, 0), shears_dur);
}

test "45. Wall carpet placement with CarpetSides.wallOnly on each cardinal side" {
    const north_wall = CarpetSides.wallOnly(.north);
    try std.testing.expect(north_wall.north);
    try std.testing.expect(!north_wall.bottom);

    const south_wall = CarpetSides.wallOnly(.south);
    try std.testing.expect(south_wall.south);

    const east_wall = CarpetSides.wallOnly(.east);
    try std.testing.expect(east_wall.east);

    const west_wall = CarpetSides.wallOnly(.west);
    try std.testing.expect(west_wall.west);
}
