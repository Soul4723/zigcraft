//! ============================================================================
//! Milestone 534: Resin Clump Smelting & Resin Brick Masonry Pipeline
//! ============================================================================
//!
//! This module implements the complete smelting, crafting, stonecutting, and
//! architectural masonry pipeline for Resin materials in Zigcraft:
//!
//! 1. Resin Clump Smelting Pipeline:
//!    - Smelting Resin Clumps into Resin Bricks in standard furnaces (200 ticks,
//!      10.0s) and blast furnaces (100 ticks, 5.0s, 2x speedup).
//!    - 0.1 XP experience reward per clump smelted (1.0 XP per 10 clumps).
//!    - Smokers and campfires reject non-culinary resin clumps.
//!    - Progressive tick-based smelting simulation with XP banking.
//!
//! 2. Resin Brick Block Crafting (2x2):
//!    - 4 Resin Bricks in a 2x2 grid yield 1 Block of Resin Bricks.
//!    - Hardness 1.5, blast resistance 6.0.
//!    - Mining tool requirement: wooden pickaxe or higher to drop itself;
//!      drops nothing when mined bare-handed or with non-pickaxes.
//!    - Fire-resistant: completely immune to fire spread and lava ignition.
//!
//! 3. Architectural Masonry Variations:
//!    - Resin Brick Stairs: 6 blocks -> 4 stairs; straight, inner left/right,
//!      and outer left/right corner shape states; lower and upper (upside-down) halves.
//!    - Resin Brick Slab: 3 blocks -> 6 slabs; bottom half (height 0.5m),
//!      top half (height 0.5m), and merging into double slab (height 1.0m).
//!    - Resin Brick Wall: 6 blocks -> 6 walls; post-and-side connections to
//!      adjacent solid blocks and walls; 1.5m jump-proof collision height.
//!    - Chiseled Resin Bricks: 2 slabs vertically stacked -> 1 chiseled block
//!      featuring a ceremonial carved medallion motif face.
//!
//! 4. Stonecutter 1:1 Recipes:
//!    - 1 Resin Bricks -> 1 Resin Brick Stairs
//!    - 1 Resin Bricks -> 2 Resin Brick Slabs
//!    - 1 Resin Bricks -> 1 Resin Brick Wall
//!    - 1 Resin Bricks -> 1 Chiseled Resin Bricks

const std = @import("std");

// ============================================================================
// Section 1: Constants & Tuning Parameters
// ============================================================================

/// Game tick rate: 20 ticks per second (50ms per tick).
pub const TICKS_PER_SECOND: u32 = 20;
pub const SECONDS_PER_TICK: f32 = 0.05;

/// Standard furnace smelting duration: 200 ticks (10.0 seconds).
pub const STANDARD_FURNACE_SMELT_TICKS: u32 = 200;
pub const STANDARD_FURNACE_SMELT_SECONDS: f32 = 10.0;

/// Blast furnace smelting duration: 100 ticks (5.0 seconds, 2x speed).
pub const BLAST_FURNACE_SMELT_TICKS: u32 = 100;
pub const BLAST_FURNACE_SMELT_SECONDS: f32 = 5.0;

/// Experience reward per resin clump smelted: 0.1 XP (1.0 XP per 10 clumps).
pub const SMELT_EXPERIENCE_PER_CLUMP: f32 = 0.1;

/// Physical attributes of Resin Bricks blocks.
pub const RESIN_BRICK_HARDNESS: f32 = 1.5;
pub const RESIN_BRICK_BLAST_RESISTANCE: f32 = 6.0;

/// Crafting ratios and requirements.
pub const BRICKS_PER_BLOCK_2X2: u32 = 4;
pub const STAIRS_CRAFT_INPUT_BLOCKS: u32 = 6;
pub const STAIRS_CRAFT_OUTPUT_COUNT: u32 = 4;
pub const SLABS_CRAFT_INPUT_BLOCKS: u32 = 3;
pub const SLABS_CRAFT_OUTPUT_COUNT: u32 = 6;
pub const WALLS_CRAFT_INPUT_BLOCKS: u32 = 6;
pub const WALLS_CRAFT_OUTPUT_COUNT: u32 = 6;
pub const CHISELED_CRAFT_INPUT_SLABS: u32 = 2;
pub const CHISELED_CRAFT_OUTPUT_COUNT: u32 = 1;

/// Dimensions & collision bounds (in meters/blocks).
pub const FULL_BLOCK_HEIGHT: f32 = 1.0;
pub const SLAB_HEIGHT: f32 = 0.5;
pub const DOUBLE_SLAB_HEIGHT: f32 = 1.0;
pub const WALL_COLLISION_HEIGHT: f32 = 1.5;
pub const WALL_VISUAL_HEIGHT: f32 = 1.0;
pub const STAIR_COLLISION_HEIGHT: f32 = 1.0;

/// Resin color palette: distinctive warm terracotta-amber orange.
pub const RESIN_ORANGE_HEX: u24 = 0xe05e26;
pub const RESIN_RGBA: [4]f32 = .{ 0.86, 0.42, 0.20, 0.95 };

// ============================================================================
// Section 2: Spatial & Taxonomy Enums
// ============================================================================

/// 6 Cardinal and vertical 3D spatial directions.
pub const Direction = enum(u3) {
    north = 0,
    south = 1,
    east = 2,
    west = 3,
    up = 4,
    down = 5,

    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
            .up => .down,
            .down => .up,
        };
    }

    pub fn isHorizontal(self: Direction) bool {
        return switch (self) {
            .north, .south, .east, .west => true,
            .up, .down => false,
        };
    }

    pub fn toOffset(self: Direction) [3]i32 {
        return switch (self) {
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
        };
    }
};

/// 3D discrete block coordinate.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) BlockPos {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn offset(self: BlockPos, dir: Direction) BlockPos {
        const d = dir.toOffset();
        return .{ .x = self.x + d[0], .y = self.y + d[1], .z = self.z + d[2] };
    }

    pub fn equals(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }
};

/// Item types involved in resin metallurgy and masonry architecture.
pub const ItemType = enum(u16) {
    none = 0,
    resin_clump = 411,
    resin_brick = 412,
    resin_bricks = 410,
    resin_brick_stairs = 435,
    resin_brick_slab = 434,
    resin_brick_wall = 436,
    chiseled_resin_bricks = 437,

    pub fn name(self: ItemType) []const u8 {
        return switch (self) {
            .none => "None",
            .resin_clump => "Resin Clump",
            .resin_brick => "Resin Brick",
            .resin_bricks => "Resin Bricks",
            .resin_brick_stairs => "Resin Brick Stairs",
            .resin_brick_slab => "Resin Brick Slab",
            .resin_brick_wall => "Resin Brick Wall",
            .chiseled_resin_bricks => "Chiseled Resin Bricks",
        };
    }

    pub fn maxStackSize(self: ItemType) u8 {
        return switch (self) {
            .none => 0,
            else => 64,
        };
    }

    pub fn toBlockId(self: ItemType) ?BlockId {
        return switch (self) {
            .resin_bricks => .resin_bricks,
            .resin_brick_stairs => .resin_brick_stairs,
            .resin_brick_slab => .resin_brick_slab,
            .resin_brick_wall => .resin_brick_wall,
            .chiseled_resin_bricks => .chiseled_resin_bricks,
            else => null,
        };
    }
};

/// Block identifiers for placed resin masonry structures.
pub const BlockId = enum(u16) {
    air = 0,
    resin_bricks = 245, // Matches global BlockId.resin_bricks
    resin_brick_stairs = 435,
    resin_brick_slab = 434,
    resin_brick_wall = 436,
    chiseled_resin_bricks = 437,
    double_resin_brick_slab = 438,
    other_solid = 1,

    pub fn name(self: BlockId) []const u8 {
        return switch (self) {
            .air => "Air",
            .resin_bricks => "Resin Bricks",
            .resin_brick_stairs => "Resin Brick Stairs",
            .resin_brick_slab => "Resin Brick Slab",
            .resin_brick_wall => "Resin Brick Wall",
            .chiseled_resin_bricks => "Chiseled Resin Bricks",
            .double_resin_brick_slab => "Double Resin Brick Slab",
            .other_solid => "Solid Block",
        };
    }

    pub fn isSolid(self: BlockId) bool {
        return self != .air;
    }

    pub fn hardness(self: BlockId) f32 {
        return switch (self) {
            .air => 0.0,
            .resin_bricks,
            .resin_brick_stairs,
            .resin_brick_slab,
            .resin_brick_wall,
            .chiseled_resin_bricks,
            .double_resin_brick_slab,
            => RESIN_BRICK_HARDNESS,
            .other_solid => 1.5,
        };
    }

    pub fn blastResistance(self: BlockId) f32 {
        return switch (self) {
            .air => 0.0,
            .resin_bricks,
            .resin_brick_stairs,
            .resin_brick_slab,
            .resin_brick_wall,
            .chiseled_resin_bricks,
            .double_resin_brick_slab,
            => RESIN_BRICK_BLAST_RESISTANCE,
            .other_solid => 6.0,
        };
    }

    pub fn isFireResistant(self: BlockId) bool {
        return switch (self) {
            .resin_bricks,
            .resin_brick_stairs,
            .resin_brick_slab,
            .resin_brick_wall,
            .chiseled_resin_bricks,
            .double_resin_brick_slab,
            => true,
            else => false,
        };
    }

    pub fn toItemType(self: BlockId) ItemType {
        return switch (self) {
            .resin_bricks => .resin_bricks,
            .resin_brick_stairs => .resin_brick_stairs,
            .resin_brick_slab => .resin_brick_slab,
            .resin_brick_wall => .resin_brick_wall,
            .chiseled_resin_bricks => .chiseled_resin_bricks,
            .double_resin_brick_slab => .resin_brick_slab, // Drops slab items
            else => .none,
        };
    }
};

/// Item stack representation for inventories and recipe inputs/outputs.
pub const ItemStack = struct {
    item: ItemType = .none,
    count: u32 = 0,

    pub fn init(item: ItemType, count: u32) ItemStack {
        return .{ .item = item, .count = count };
    }

    pub fn isEmpty(self: ItemStack) bool {
        return self.item == .none or self.count == 0;
    }
};

// ============================================================================
// Section 3: Resin Clump Smelting Pipeline
// ============================================================================

/// Pyrometallurgy workstation classification.
pub const SmeltingWorkstation = enum(u8) {
    standard_furnace,
    blast_furnace,
    smoker,
    campfire,

    pub fn name(self: SmeltingWorkstation) []const u8 {
        return switch (self) {
            .standard_furnace => "Standard Furnace",
            .blast_furnace => "Blast Furnace",
            .smoker => "Smoker",
            .campfire => "Campfire",
        };
    }

    pub fn canSmeltResin(self: SmeltingWorkstation) bool {
        return switch (self) {
            .standard_furnace, .blast_furnace => true,
            .smoker, .campfire => false,
        };
    }

    pub fn cookTimeTicks(self: SmeltingWorkstation) ?u32 {
        return switch (self) {
            .standard_furnace => STANDARD_FURNACE_SMELT_TICKS,
            .blast_furnace => BLAST_FURNACE_SMELT_TICKS,
            .smoker, .campfire => null,
        };
    }

    pub fn cookTimeSeconds(self: SmeltingWorkstation) ?f32 {
        return switch (self) {
            .standard_furnace => STANDARD_FURNACE_SMELT_SECONDS,
            .blast_furnace => BLAST_FURNACE_SMELT_SECONDS,
            .smoker, .campfire => null,
        };
    }

    pub fn speedMultiplier(self: SmeltingWorkstation) u32 {
        return switch (self) {
            .standard_furnace => 1,
            .blast_furnace => 2,
            .smoker, .campfire => 0,
        };
    }
};

/// Outcome of a smelting operation.
pub const SmeltOutcome = struct {
    output_item: ItemType,
    output_count: u32,
    experience_yield: f32,
    cook_ticks_per_item: u32,
    total_cook_ticks: u32,
    workstation: SmeltingWorkstation,
};

/// Validates whether an item can be smelted in the specified workstation.
pub fn canSmelt(item: ItemType, workstation: SmeltingWorkstation) bool {
    if (item != .resin_clump) return false;
    return workstation.canSmeltResin();
}

/// Calculate the exact experience yield for a number of smelted resin clumps.
pub fn calculateSmeltExperience(clump_count: u32) f32 {
    return @as(f32, @floatFromInt(clump_count)) * SMELT_EXPERIENCE_PER_CLUMP;
}

/// Smelts Resin Clumps into Resin Bricks.
/// Standard Furnace: 200 ticks per clump.
/// Blast Furnace: 100 ticks per clump (2x speed).
/// Smoker/Campfire: Incompatible (returns null).
pub fn smeltResinClump(
    item: ItemType,
    count: u32,
    workstation: SmeltingWorkstation,
) ?SmeltOutcome {
    if (count == 0 or !canSmelt(item, workstation)) return null;

    const ticks_per_item = workstation.cookTimeTicks() orelse return null;

    return SmeltOutcome{
        .output_item = .resin_brick,
        .output_count = count,
        .experience_yield = calculateSmeltExperience(count),
        .cook_ticks_per_item = ticks_per_item,
        .total_cook_ticks = count * ticks_per_item,
        .workstation = workstation,
    };
}

/// Step-by-step progressive simulation for furnace and blast furnace cooking.
pub const SmeltingSimulation = struct {
    input_item: ItemType,
    input_count: u32,
    workstation: SmeltingWorkstation,
    cook_progress_ticks: u32 = 0,
    completed_items: u32 = 0,
    banked_xp: f32 = 0.0,

    pub fn init(item: ItemType, count: u32, workstation: SmeltingWorkstation) ?SmeltingSimulation {
        if (!canSmelt(item, workstation) or count == 0) return null;
        return .{
            .input_item = item,
            .input_count = count,
            .workstation = workstation,
            .cook_progress_ticks = 0,
            .completed_items = 0,
            .banked_xp = 0.0,
        };
    }

    pub fn isCooking(self: *const SmeltingSimulation) bool {
        return self.input_count > 0;
    }

    pub fn isFinished(self: *const SmeltingSimulation) bool {
        return self.input_count == 0 and self.cook_progress_ticks == 0;
    }

    pub fn getCookProgressFraction(self: *const SmeltingSimulation) f32 {
        const ticks_per_item = self.workstation.cookTimeTicks() orelse return 0.0;
        if (self.input_count == 0) return 0.0;
        return @as(f32, @floatFromInt(self.cook_progress_ticks)) / @as(f32, @floatFromInt(ticks_per_item));
    }

    /// Advances the simulation by `dt_ticks`. Returns the count of items finished during this update.
    pub fn tick(self: *SmeltingSimulation, dt_ticks: u32) u32 {
        if (self.input_count == 0) return 0;
        const ticks_per_item = self.workstation.cookTimeTicks() orelse return 0;

        self.cook_progress_ticks += dt_ticks;
        var finished_now: u32 = 0;

        while (self.cook_progress_ticks >= ticks_per_item and self.input_count > 0) {
            self.cook_progress_ticks -= ticks_per_item;
            self.input_count -= 1;
            self.completed_items += 1;
            self.banked_xp += SMELT_EXPERIENCE_PER_CLUMP;
            finished_now += 1;
        }

        if (self.input_count == 0) {
            self.cook_progress_ticks = 0;
        }

        return finished_now;
    }

    /// Claims all accumulated experience and resets the bank to 0.
    pub fn claimXp(self: *SmeltingSimulation) f32 {
        const xp = self.banked_xp;
        self.banked_xp = 0.0;
        return xp;
    }

    /// Claims and removes completed output items.
    pub fn claimCompletedItems(self: *SmeltingSimulation) u32 {
        const count = self.completed_items;
        self.completed_items = 0;
        return count;
    }
};

// ============================================================================
// Section 4: Physical Attributes, Mining & Fire Immunity
// ============================================================================

/// Mining tool category.
pub const ToolCategory = enum {
    bare_hand,
    pickaxe,
    axe,
    shovel,
    hoe,
    sword,
    shears,
};

/// Tool material tier.
pub const ToolTier = enum(u8) {
    none = 0,
    wooden = 1,
    stone = 2,
    iron = 3,
    golden = 4,
    diamond = 5,
    netherite = 6,

    pub fn isAtLeastWooden(self: ToolTier) bool {
        return @intFromEnum(self) >= @intFromEnum(ToolTier.wooden);
    }

    pub fn speedMultiplier(self: ToolTier) f32 {
        return switch (self) {
            .none => 1.0,
            .wooden => 2.0,
            .stone => 4.0,
            .iron => 6.0,
            .diamond => 8.0,
            .netherite => 9.0,
            .golden => 12.0,
        };
    }
};

/// Tool description for mining evaluation.
pub const MiningTool = struct {
    category: ToolCategory = .bare_hand,
    tier: ToolTier = .none,

    pub fn canHarvestResinBricks(self: MiningTool) bool {
        return self.category == .pickaxe and self.tier.isAtLeastWooden();
    }
};

/// Result of breaking a resin masonry block.
pub const MiningOutcome = struct {
    can_harvest: bool,
    drops_item: ItemType,
    drops_count: u8,
    mining_time_seconds: f32,
};

/// Full physical attribute specification for resin masonry blocks.
pub const PhysicalProperties = struct {
    hardness: f32 = RESIN_BRICK_HARDNESS,
    blast_resistance: f32 = RESIN_BRICK_BLAST_RESISTANCE,
    requires_tool: bool = true,
    required_tool_category: ToolCategory = .pickaxe,
    required_tool_tier: ToolTier = .wooden,
    is_flammable: bool = false,
    immune_to_fire_spread: bool = true,
    immune_to_lava_ignition: bool = true,
};

/// Evaluates mining time and drops when breaking a resin masonry block.
/// Requires wooden pickaxe or higher to harvest drops.
/// With pickaxe: drops itself (or 2 slabs for a double slab).
/// Without pickaxe: drops nothing (0 items).
pub fn evaluateBlockMining(block: BlockId, tool: MiningTool) MiningOutcome {
    const is_resin_masonry = switch (block) {
        .resin_bricks,
        .resin_brick_stairs,
        .resin_brick_slab,
        .resin_brick_wall,
        .chiseled_resin_bricks,
        .double_resin_brick_slab,
        => true,
        else => false,
    };

    if (!is_resin_masonry) {
        return .{
            .can_harvest = false,
            .drops_item = .none,
            .drops_count = 0,
            .mining_time_seconds = 0.0,
        };
    }

    const can_harvest = tool.canHarvestResinBricks();
    const base_hardness = block.hardness();

    // Standard Minecraft mining duration formula:
    // With correct tool and harvest tier: (hardness * 1.5) / tool_speed
    // Without correct tool (bare hand or wrong tool): hardness * 5.0
    const time_sec: f32 = if (tool.category == .pickaxe)
        (base_hardness * 1.5) / tool.tier.speedMultiplier()
    else
        base_hardness * 5.0;

    if (!can_harvest) {
        return .{
            .can_harvest = false,
            .drops_item = .none,
            .drops_count = 0,
            .mining_time_seconds = time_sec,
        };
    }

    // Double slab drops 2 slab items when mined with a pickaxe
    const drop_item = block.toItemType();
    const drop_count: u8 = if (block == .double_resin_brick_slab) 2 else 1;

    return .{
        .can_harvest = true,
        .drops_item = drop_item,
        .drops_count = drop_count,
        .mining_time_seconds = time_sec,
    };
}

/// Checks whether a block is completely immune to fire spread.
pub fn isFireSpreadImmune(block: BlockId) bool {
    return block.isFireResistant();
}

/// Checks whether a block is immune to lava ignition.
pub fn isLavaIgnitionImmune(block: BlockId) bool {
    return block.isFireResistant();
}

// ============================================================================
// Section 5: 2x2 Crafting (Resin Bricks Block)
// ============================================================================

/// Outcome of a crafting or stonecutting operation.
pub const CraftResult = struct {
    output_item: ItemType,
    output_count: u32,
    consumed_count: u32,
    remainder_count: u32,
};

/// 2x2 Crafting: 4 Resin Bricks -> 1 Block of Resin Bricks.
pub fn craftResinBricks(resin_brick_count: u32) ?CraftResult {
    if (resin_brick_count < BRICKS_PER_BLOCK_2X2) return null;
    const crafted = resin_brick_count / BRICKS_PER_BLOCK_2X2;
    return .{
        .output_item = .resin_bricks,
        .output_count = crafted,
        .consumed_count = crafted * BRICKS_PER_BLOCK_2X2,
        .remainder_count = resin_brick_count % BRICKS_PER_BLOCK_2X2,
    };
}

/// Grid-based 2x2 crafting matcher.
/// All 4 slots must contain at least 1 Resin Brick.
pub fn craftGrid2x2(grid: [4]ItemStack) ?CraftResult {
    for (grid) |slot| {
        if (slot.item != .resin_brick or slot.count < 1) return null;
    }
    return .{
        .output_item = .resin_bricks,
        .output_count = 1,
        .consumed_count = 4,
        .remainder_count = 0,
    };
}

// ============================================================================
// Section 6: Architectural Masonry Variations
// ============================================================================

// ----------------------------------------------------------------------------
// 6.1 Resin Brick Stairs
// ----------------------------------------------------------------------------

/// Half state for stairs: lower half (normal) or upper half (upside-down).
pub const StairHalf = enum(u1) {
    bottom = 0, // Lower half
    top = 1,    // Upper half (upside down)
};

/// 5 distinct stair shape states based on neighboring stairs.
pub const StairShape = enum(u3) {
    straight = 0,
    inner_left = 1,
    inner_right = 2,
    outer_left = 3,
    outer_right = 4,

    pub fn name(self: StairShape) []const u8 {
        return switch (self) {
            .straight => "Straight",
            .inner_left => "Inner Left",
            .inner_right => "Inner Right",
            .outer_left => "Outer Left",
            .outer_right => "Outer Right",
        };
    }
};

/// Stair neighbor description for shape calculation.
pub const StairNeighbor = struct {
    is_stair: bool = false,
    facing: Direction = .north,
    half: StairHalf = .bottom,
};

/// Comprehensive stair state.
pub const StairState = struct {
    facing: Direction = .north,
    half: StairHalf = .bottom,
    shape: StairShape = .straight,

    pub fn getCollisionHeight(self: *const StairState) f32 {
        _ = self;
        return STAIR_COLLISION_HEIGHT;
    }
};

/// Determines stair shape based on Minecraft rules from relative neighbors.
/// `front` is the direction the stair descends towards (facing).
/// `back` is behind the stair (facing.opposite()).
/// `left` is 90 deg counter-clockwise.
/// `right` is 90 deg clockwise.
pub fn determineStairShape(
    facing: Direction,
    half: StairHalf,
    front: StairNeighbor,
    back: StairNeighbor,
    left: StairNeighbor,
    right: StairNeighbor,
) StairShape {
    // Check for inner corner connection to stair behind
    if (back.is_stair and back.half == half) {
        if (back.facing == getLeftDirection(facing)) {
            return .inner_left;
        } else if (back.facing == getRightDirection(facing)) {
            return .inner_right;
        }
    }

    // Check for outer corner connection to stair in front
    if (front.is_stair and front.half == half) {
        if (front.facing == getLeftDirection(facing)) {
            return .outer_left;
        } else if (front.facing == getRightDirection(facing)) {
            return .outer_right;
        }
    }

    _ = left;
    _ = right;
    return .straight;
}

fn getLeftDirection(dir: Direction) Direction {
    return switch (dir) {
        .north => .west,
        .west => .south,
        .south => .east,
        .east => .north,
        else => .north,
    };
}

fn getRightDirection(dir: Direction) Direction {
    return switch (dir) {
        .north => .east,
        .east => .south,
        .south => .west,
        .west => .north,
        else => .north,
    };
}

/// Helper to determine stair shape from cardinal neighbors (North, South, East, West).
pub fn determineStairShapeFromCardinals(
    facing: Direction,
    half: StairHalf,
    north: StairNeighbor,
    south: StairNeighbor,
    east: StairNeighbor,
    west: StairNeighbor,
) StairShape {
    const getNeighbor = struct {
        fn get(dir: Direction, n: StairNeighbor, s: StairNeighbor, e: StairNeighbor, w: StairNeighbor) StairNeighbor {
            return switch (dir) {
                .north => n,
                .south => s,
                .east => e,
                .west => w,
                else => .{},
            };
        }
    }.get;

    const front = getNeighbor(facing, north, south, east, west);
    const back = getNeighbor(facing.opposite(), north, south, east, west);
    const left = getNeighbor(getLeftDirection(facing), north, south, east, west);
    const right = getNeighbor(getRightDirection(facing), north, south, east, west);

    return determineStairShape(facing, half, front, back, left, right);
}

/// 3x3 Crafting: 6 Resin Bricks blocks -> 4 Resin Brick Stairs.
pub fn craftResinBrickStairs(resin_bricks_count: u32) ?CraftResult {
    if (resin_bricks_count < STAIRS_CRAFT_INPUT_BLOCKS) return null;
    const sets = resin_bricks_count / STAIRS_CRAFT_INPUT_BLOCKS;
    return .{
        .output_item = .resin_brick_stairs,
        .output_count = sets * STAIRS_CRAFT_OUTPUT_COUNT,
        .consumed_count = sets * STAIRS_CRAFT_INPUT_BLOCKS,
        .remainder_count = resin_bricks_count % STAIRS_CRAFT_INPUT_BLOCKS,
    };
}

/// Matches a standard 3x3 stair crafting grid.
/// Recognizes both left-facing L and right-facing L stair configurations (6 blocks).
pub fn craftStairsGrid3x3(grid: [9]ItemStack) ?CraftResult {
    // Pattern A (left-ascending):
    // [X, ., .]
    // [X, X, .]
    // [X, X, X]
    const pattern_a = [_]bool{
        true,  false, false,
        true,  true,  false,
        true,  true,  true,
    };

    // Pattern B (right-ascending):
    // [., ., X]
    // [., X, X]
    // [X, X, X]
    const pattern_b = [_]bool{
        false, false, true,
        false, true,  true,
        true,  true,  true,
    };

    var match_a = true;
    var match_b = true;

    for (grid, 0..) |slot, i| {
        const need_a = pattern_a[i];
        const is_brick_a = slot.item == .resin_bricks and slot.count >= 1;
        if (need_a != is_brick_a) match_a = false;

        const need_b = pattern_b[i];
        const is_brick_b = slot.item == .resin_bricks and slot.count >= 1;
        if (need_b != is_brick_b) match_b = false;
    }

    if (match_a or match_b) {
        return .{
            .output_item = .resin_brick_stairs,
            .output_count = STAIRS_CRAFT_OUTPUT_COUNT,
            .consumed_count = STAIRS_CRAFT_INPUT_BLOCKS,
            .remainder_count = 0,
        };
    }
    return null;
}

// ----------------------------------------------------------------------------
// 6.2 Resin Brick Slab
// ----------------------------------------------------------------------------

/// Half state for slab placement.
pub const SlabHalf = enum(u1) {
    bottom = 0, // Lower half: Y in [0.0, 0.5]
    top = 1,    // Upper half: Y in [0.5, 1.0]
};

/// Discrete state of a placed slab block: bottom, top, or merged double slab.
pub const SlabState = enum(u2) {
    bottom = 0,
    top = 1,
    double_slab = 2,

    pub fn height(self: SlabState) f32 {
        return switch (self) {
            .bottom, .top => SLAB_HEIGHT,
            .double_slab => DOUBLE_SLAB_HEIGHT,
        };
    }

    pub fn yMin(self: SlabState) f32 {
        return switch (self) {
            .bottom, .double_slab => 0.0,
            .top => 0.5,
        };
    }

    pub fn yMax(self: SlabState) f32 {
        return switch (self) {
            .bottom => 0.5,
            .top, .double_slab => 1.0,
        };
    }

    pub fn isDouble(self: SlabState) bool {
        return self == .double_slab;
    }
};

/// Slab placement outcome.
pub const SlabPlacementResult = enum {
    placed_new_slab,
    combined_into_double_slab,
    rejected_occupied,
};

/// Simulates placing a slab item into a voxel space.
/// Placing a slab on a matching existing half-slab merges it into a double slab block.
pub fn placeSlab(
    current_state: ?SlabState,
    target_half: SlabHalf,
) struct { outcome: SlabPlacementResult, new_state: SlabState } {
    if (current_state == null) {
        return .{
            .outcome = .placed_new_slab,
            .new_state = if (target_half == .bottom) .bottom else .top,
        };
    }

    const existing = current_state.?;
    switch (existing) {
        .bottom => {
            // Placing into the upper half of a bottom slab completes a double slab
            return .{
                .outcome = .combined_into_double_slab,
                .new_state = .double_slab,
            };
        },
        .top => {
            // Placing into the lower half of a top slab completes a double slab
            return .{
                .outcome = .combined_into_double_slab,
                .new_state = .double_slab,
            };
        },
        .double_slab => {
            // Already a full solid block; cannot place another slab here
            return .{
                .outcome = .rejected_occupied,
                .new_state = .double_slab,
            };
        },
    }
}

/// Crafting: 3 Resin Bricks blocks (horizontal row) -> 6 Slabs.
pub fn craftResinBrickSlabs(resin_bricks_count: u32) ?CraftResult {
    if (resin_bricks_count < SLABS_CRAFT_INPUT_BLOCKS) return null;
    const sets = resin_bricks_count / SLABS_CRAFT_INPUT_BLOCKS;
    return .{
        .output_item = .resin_brick_slab,
        .output_count = sets * SLABS_CRAFT_OUTPUT_COUNT,
        .consumed_count = sets * SLABS_CRAFT_INPUT_BLOCKS,
        .remainder_count = resin_bricks_count % SLABS_CRAFT_INPUT_BLOCKS,
    };
}

/// Matches a 3x3 crafting grid containing 3 Resin Bricks in any horizontal row.
pub fn craftSlabsGrid3x3(grid: [9]ItemStack) ?CraftResult {
    const rows = [_][3]usize{
        .{ 0, 1, 2 }, // Top row
        .{ 3, 4, 5 }, // Middle row
        .{ 6, 7, 8 }, // Bottom row
    };

    for (rows) |row| {
        var row_match = true;
        for (grid, 0..) |slot, idx| {
            const in_row = (idx == row[0] or idx == row[1] or idx == row[2]);
            const is_brick = (slot.item == .resin_bricks and slot.count >= 1);
            if (in_row != is_brick) {
                row_match = false;
                break;
            }
        }
        if (row_match) {
            return .{
                .output_item = .resin_brick_slab,
                .output_count = SLABS_CRAFT_OUTPUT_COUNT,
                .consumed_count = SLABS_CRAFT_INPUT_BLOCKS,
                .remainder_count = 0,
            };
        }
    }
    return null;
}

// ----------------------------------------------------------------------------
// 6.3 Resin Brick Wall
// ----------------------------------------------------------------------------

/// Wall side connection state: none, low (1.0m wall), or tall (1.5m solid connection).
pub const WallConnection = enum(u2) {
    none = 0,
    low = 1,
    tall = 2,

    pub fn isConnected(self: WallConnection) bool {
        return self != .none;
    }
};

/// Surrounding context for computing wall connections.
pub const CardinalNeighbors = struct {
    north_solid_or_wall: bool = false,
    south_solid_or_wall: bool = false,
    east_solid_or_wall: bool = false,
    west_solid_or_wall: bool = false,
    above_solid: bool = false,
};

/// Wall geometry state including center post and 4 cardinal connections.
pub const WallState = struct {
    post: bool = true,
    north: WallConnection = .none,
    south: WallConnection = .none,
    east: WallConnection = .none,
    west: WallConnection = .none,

    pub fn hasConnections(self: WallState) bool {
        return self.north.isConnected() or self.south.isConnected() or
            self.east.isConnected() or self.west.isConnected();
    }

    /// Wall collision height is 1.5 blocks (jump-proof boundary).
    pub fn getCollisionHeight(self: *const WallState) f32 {
        _ = self;
        return WALL_COLLISION_HEIGHT;
    }

    /// Wall visual geometry base height is 1.0 block.
    pub fn getVisualHeight(self: *const WallState) f32 {
        _ = self;
        return WALL_VISUAL_HEIGHT;
    }
};

/// Computes cardinal post-and-side connections for a Resin Brick Wall.
/// Connects to adjacent solid blocks and walls.
/// In straight 2-way connections without a block above, center post is lowered.
pub fn computeWallConnections(neighbors: CardinalNeighbors) WallState {
    var state = WallState{};

    state.north = if (neighbors.north_solid_or_wall)
        (if (neighbors.above_solid) .tall else .low)
    else
        .none;

    state.south = if (neighbors.south_solid_or_wall)
        (if (neighbors.above_solid) .tall else .low)
    else
        .none;

    state.east = if (neighbors.east_solid_or_wall)
        (if (neighbors.above_solid) .tall else .low)
    else
        .none;

    state.west = if (neighbors.west_solid_or_wall)
        (if (neighbors.above_solid) .tall else .low)
    else
        .none;

    // Straight line connections (North-South only or East-West only) lower the post
    // unless there is a solid block directly above
    const straight_ns = (state.north != .none and state.south != .none and state.east == .none and state.west == .none);
    const straight_ew = (state.east != .none and state.west != .none and state.north == .none and state.south == .none);

    if ((straight_ns or straight_ew) and !neighbors.above_solid) {
        state.post = false;
    } else {
        state.post = true;
    }

    return state;
}

/// Crafting: 6 Resin Bricks blocks (2 rows of 3) -> 6 Walls.
pub fn craftResinBrickWalls(resin_bricks_count: u32) ?CraftResult {
    if (resin_bricks_count < WALLS_CRAFT_INPUT_BLOCKS) return null;
    const sets = resin_bricks_count / WALLS_CRAFT_INPUT_BLOCKS;
    return .{
        .output_item = .resin_brick_wall,
        .output_count = sets * WALLS_CRAFT_OUTPUT_COUNT,
        .consumed_count = sets * WALLS_CRAFT_INPUT_BLOCKS,
        .remainder_count = resin_bricks_count % WALLS_CRAFT_INPUT_BLOCKS,
    };
}

/// Matches a 3x3 crafting grid containing two full rows of 3 Resin Bricks (6 blocks total).
pub fn craftWallsGrid3x3(grid: [9]ItemStack) ?CraftResult {
    // Option 1: Top two rows (0..5)
    var match_top = true;
    for (grid, 0..) |slot, idx| {
        const in_pattern = (idx < 6);
        const is_brick = (slot.item == .resin_bricks and slot.count >= 1);
        if (in_pattern != is_brick) {
            match_top = false;
            break;
        }
    }
    if (match_top) {
        return .{
            .output_item = .resin_brick_wall,
            .output_count = WALLS_CRAFT_OUTPUT_COUNT,
            .consumed_count = WALLS_CRAFT_INPUT_BLOCKS,
            .remainder_count = 0,
        };
    }

    // Option 2: Bottom two rows (3..8)
    var match_bottom = true;
    for (grid, 0..) |slot, idx| {
        const in_pattern = (idx >= 3);
        const is_brick = (slot.item == .resin_bricks and slot.count >= 1);
        if (in_pattern != is_brick) {
            match_bottom = false;
            break;
        }
    }
    if (match_bottom) {
        return .{
            .output_item = .resin_brick_wall,
            .output_count = WALLS_CRAFT_OUTPUT_COUNT,
            .consumed_count = WALLS_CRAFT_INPUT_BLOCKS,
            .remainder_count = 0,
        };
    }

    return null;
}

// ----------------------------------------------------------------------------
// 6.4 Chiseled Resin Bricks
// ----------------------------------------------------------------------------

/// Crafting: 2 Resin Brick Slabs stacked vertically in crafting grid -> 1 Chiseled Resin Bricks.
pub fn craftChiseledResinBricks(slab_count: u32) ?CraftResult {
    if (slab_count < CHISELED_CRAFT_INPUT_SLABS) return null;
    const crafted = slab_count / CHISELED_CRAFT_INPUT_SLABS;
    return .{
        .output_item = .chiseled_resin_bricks,
        .output_count = crafted * CHISELED_CRAFT_OUTPUT_COUNT,
        .consumed_count = crafted * CHISELED_CRAFT_INPUT_SLABS,
        .remainder_count = slab_count % CHISELED_CRAFT_INPUT_SLABS,
    };
}

/// Matches a 2-slot vertical column of slabs in a 2x2 crafting grid.
pub fn craftChiseledGrid2x2(grid: [4]ItemStack) ?CraftResult {
    // Left column: [0, 2]
    const match_left = (grid[0].item == .resin_brick_slab and grid[0].count >= 1 and
        grid[2].item == .resin_brick_slab and grid[2].count >= 1 and
        grid[1].isEmpty() and grid[3].isEmpty());

    // Right column: [1, 3]
    const match_right = (grid[1].item == .resin_brick_slab and grid[1].count >= 1 and
        grid[3].item == .resin_brick_slab and grid[3].count >= 1 and
        grid[0].isEmpty() and grid[2].isEmpty());

    if (match_left or match_right) {
        return .{
            .output_item = .chiseled_resin_bricks,
            .output_count = CHISELED_CRAFT_OUTPUT_COUNT,
            .consumed_count = CHISELED_CRAFT_INPUT_SLABS,
            .remainder_count = 0,
        };
    }
    return null;
}

// ============================================================================
// Section 7: Stonecutter 1:1 Recipes
// ============================================================================

/// Available stonecutter recipes for Resin Bricks.
pub const StonecutterRecipe = struct {
    target: ItemType,
    yield_multiplier: u32,
};

/// Master table of stonecutter conversions from 1 Block of Resin Bricks.
pub const STONECUTTER_RECIPES = [_]StonecutterRecipe{
    .{ .target = .resin_brick_stairs, .yield_multiplier = 1 },    // 1:1
    .{ .target = .resin_brick_slab, .yield_multiplier = 2 },      // 1:2
    .{ .target = .resin_brick_wall, .yield_multiplier = 1 },      // 1:1
    .{ .target = .chiseled_resin_bricks, .yield_multiplier = 1 }, // 1:1
};

/// Stonecutting conversion: converts 1 Block of Resin Bricks directly into architectural variants:
/// - 1 Resin Bricks -> 1 Resin Brick Stairs
/// - 1 Resin Bricks -> 2 Resin Brick Slabs
/// - 1 Resin Bricks -> 1 Resin Brick Wall
/// - 1 Resin Bricks -> 1 Chiseled Resin Bricks
pub fn stonecutResinBricks(target: ItemType, input_count: u32) ?CraftResult {
    if (input_count == 0) return null;

    const yield_mult: u32 = switch (target) {
        .resin_brick_stairs => 1,
        .resin_brick_slab => 2,
        .resin_brick_wall => 1,
        .chiseled_resin_bricks => 1,
        else => return null,
    };

    return .{
        .output_item = target,
        .output_count = input_count * yield_mult,
        .consumed_count = input_count,
        .remainder_count = 0,
    };
}

/// Generic stonecutter entrypoint checking input item.
pub fn stonecut(input_item: ItemType, input_count: u32, target: ItemType) ?CraftResult {
    if (input_item != .resin_bricks) return null;
    return stonecutResinBricks(target, input_count);
}

// ============================================================================
// Section 8: Comprehensive Unit Tests (50+ Tests)
// ============================================================================

test "1. Smelting: Standard furnace cook duration is exactly 200 ticks (10.0s)" {
    const outcome = smeltResinClump(.resin_clump, 1, .standard_furnace).?;
    try std.testing.expectEqual(@as(u32, 200), outcome.cook_ticks_per_item);
    try std.testing.expectEqual(@as(u32, 200), outcome.total_cook_ticks);
    try std.testing.expectEqual(SmeltingWorkstation.standard_furnace, outcome.workstation);
}

test "2. Smelting: Blast furnace cook duration is exactly 100 ticks (5.0s, 2x speed)" {
    const outcome = smeltResinClump(.resin_clump, 1, .blast_furnace).?;
    try std.testing.expectEqual(@as(u32, 100), outcome.cook_ticks_per_item);
    try std.testing.expectEqual(@as(u32, 100), outcome.total_cook_ticks);
    try std.testing.expectEqual(SmeltingWorkstation.blast_furnace, outcome.workstation);
}

test "3. Smelting: Smoker rejects Resin Clump" {
    try std.testing.expectEqual(false, canSmelt(.resin_clump, .smoker));
    try std.testing.expect(smeltResinClump(.resin_clump, 1, .smoker) == null);
}

test "4. Smelting: Campfire rejects Resin Clump" {
    try std.testing.expectEqual(false, canSmelt(.resin_clump, .campfire));
    try std.testing.expect(smeltResinClump(.resin_clump, 1, .campfire) == null);
}

test "5. Smelting: Non-resin clump items cannot be smelted" {
    try std.testing.expectEqual(false, canSmelt(.resin_brick, .standard_furnace));
    try std.testing.expectEqual(false, canSmelt(.resin_bricks, .standard_furnace));
    try std.testing.expectEqual(false, canSmelt(.none, .blast_furnace));
}

test "6. Smelting: Zero count returns null" {
    try std.testing.expect(smeltResinClump(.resin_clump, 0, .standard_furnace) == null);
    try std.testing.expect(smeltResinClump(.resin_clump, 0, .blast_furnace) == null);
}

test "7. Smelting: 1 Resin Clump yields 1 Resin Brick and 0.1 XP" {
    const outcome = smeltResinClump(.resin_clump, 1, .standard_furnace).?;
    try std.testing.expectEqual(ItemType.resin_brick, outcome.output_item);
    try std.testing.expectEqual(@as(u32, 1), outcome.output_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), outcome.experience_yield, 0.0001);
}

test "8. Smelting: 10 Resin Clumps yield 10 Resin Bricks and exactly 1.0 XP" {
    const outcome = smeltResinClump(.resin_clump, 10, .standard_furnace).?;
    try std.testing.expectEqual(ItemType.resin_brick, outcome.output_item);
    try std.testing.expectEqual(@as(u32, 10), outcome.output_count);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), outcome.experience_yield, 0.0001);
}

test "9. Smelting: Batch 64 clumps in Standard Furnace requires 12,800 ticks and yields 6.4 XP" {
    const outcome = smeltResinClump(.resin_clump, 64, .standard_furnace).?;
    try std.testing.expectEqual(@as(u32, 64), outcome.output_count);
    try std.testing.expectEqual(@as(u32, 12800), outcome.total_cook_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 6.4), outcome.experience_yield, 0.0001);
}

test "10. Smelting: Batch 64 clumps in Blast Furnace requires 6,400 ticks (2x speed) and yields 6.4 XP" {
    const outcome = smeltResinClump(.resin_clump, 64, .blast_furnace).?;
    try std.testing.expectEqual(@as(u32, 64), outcome.output_count);
    try std.testing.expectEqual(@as(u32, 6400), outcome.total_cook_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 6.4), outcome.experience_yield, 0.0001);
}

test "11. Smelting Simulation: Stepping by 199 ticks yields 0 completed items in Standard Furnace" {
    var sim = SmeltingSimulation.init(.resin_clump, 5, .standard_furnace).?;
    const done = sim.tick(199);
    try std.testing.expectEqual(@as(u32, 0), done);
    try std.testing.expectEqual(@as(u32, 0), sim.completed_items);
    try std.testing.expect(sim.isCooking());
    try std.testing.expectApproxEqAbs(@as(f32, 199.0 / 200.0), sim.getCookProgressFraction(), 0.001);
}

test "12. Smelting Simulation: Stepping by 200 ticks yields exactly 1 item in Standard Furnace" {
    var sim = SmeltingSimulation.init(.resin_clump, 3, .standard_furnace).?;
    const done = sim.tick(200);
    try std.testing.expectEqual(@as(u32, 1), done);
    try std.testing.expectEqual(@as(u32, 1), sim.completed_items);
    try std.testing.expectEqual(@as(u32, 2), sim.input_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), sim.banked_xp, 0.0001);
}

test "13. Smelting Simulation: Blast Furnace yields 1 item at 100 ticks and 2 items at 200 ticks" {
    var sim = SmeltingSimulation.init(.resin_clump, 4, .blast_furnace).?;
    const done_100 = sim.tick(100);
    try std.testing.expectEqual(@as(u32, 1), done_100);
    try std.testing.expectEqual(@as(u32, 1), sim.completed_items);

    const done_another_100 = sim.tick(100);
    try std.testing.expectEqual(@as(u32, 1), done_another_100);
    try std.testing.expectEqual(@as(u32, 2), sim.completed_items);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), sim.banked_xp, 0.0001);
}

test "14. Smelting Simulation: Multiple items completed in large tick leap" {
    var sim = SmeltingSimulation.init(.resin_clump, 5, .standard_furnace).?;
    const done = sim.tick(450); // 2 full items (400 ticks) + 50 progress
    try std.testing.expectEqual(@as(u32, 2), done);
    try std.testing.expectEqual(@as(u32, 2), sim.completed_items);
    try std.testing.expectEqual(@as(u32, 3), sim.input_count);
    try std.testing.expectEqual(@as(u32, 50), sim.cook_progress_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), sim.banked_xp, 0.0001);
}

test "15. Smelting Simulation: Claiming banked XP resets accumulator" {
    var sim = SmeltingSimulation.init(.resin_clump, 10, .standard_furnace).?;
    _ = sim.tick(2000); // 10 items * 200 ticks = 2000 ticks
    try std.testing.expectEqual(@as(u32, 10), sim.completed_items);
    try std.testing.expect(sim.isFinished());

    const xp = sim.claimXp();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), xp, 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), sim.banked_xp);

    const claimed_items = sim.claimCompletedItems();
    try std.testing.expectEqual(@as(u32, 10), claimed_items);
    try std.testing.expectEqual(@as(u32, 0), sim.completed_items);
}

test "16. 2x2 Crafting: 4 Resin Bricks yield exactly 1 Block of Resin Bricks" {
    const res = craftResinBricks(4).?;
    try std.testing.expectEqual(ItemType.resin_bricks, res.output_item);
    try std.testing.expectEqual(@as(u32, 1), res.output_count);
    try std.testing.expectEqual(@as(u32, 4), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), res.remainder_count);
}

test "17. 2x2 Crafting: Less than 4 Resin Bricks cannot craft a block" {
    try std.testing.expect(craftResinBricks(0) == null);
    try std.testing.expect(craftResinBricks(1) == null);
    try std.testing.expect(craftResinBricks(2) == null);
    try std.testing.expect(craftResinBricks(3) == null);
}

test "18. 2x2 Crafting: Batch crafting with 17 bricks yields 4 blocks with 1 brick remainder" {
    const res = craftResinBricks(17).?;
    try std.testing.expectEqual(ItemType.resin_bricks, res.output_item);
    try std.testing.expectEqual(@as(u32, 4), res.output_count);
    try std.testing.expectEqual(@as(u32, 16), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 1), res.remainder_count);
}

test "19. 2x2 Crafting: Grid match with 4 valid Resin Bricks succeeds" {
    const grid = [_]ItemStack{
        ItemStack.init(.resin_brick, 1),
        ItemStack.init(.resin_brick, 1),
        ItemStack.init(.resin_brick, 1),
        ItemStack.init(.resin_brick, 1),
    };
    const res = craftGrid2x2(grid).?;
    try std.testing.expectEqual(ItemType.resin_bricks, res.output_item);
    try std.testing.expectEqual(@as(u32, 1), res.output_count);
    try std.testing.expectEqual(@as(u32, 4), res.consumed_count);
}

test "20. 2x2 Crafting: Grid with an empty or non-resin-brick slot fails" {
    const grid_empty = [_]ItemStack{
        ItemStack.init(.resin_brick, 1),
        ItemStack.init(.none, 0),
        ItemStack.init(.resin_brick, 1),
        ItemStack.init(.resin_brick, 1),
    };
    try std.testing.expect(craftGrid2x2(grid_empty) == null);

    const grid_clump = [_]ItemStack{
        ItemStack.init(.resin_brick, 1),
        ItemStack.init(.resin_clump, 1),
        ItemStack.init(.resin_brick, 1),
        ItemStack.init(.resin_brick, 1),
    };
    try std.testing.expect(craftGrid2x2(grid_clump) == null);
}

test "21. Architectural Crafting: 6 Resin Bricks blocks craft 4 Resin Brick Stairs" {
    const res = craftResinBrickStairs(6).?;
    try std.testing.expectEqual(ItemType.resin_brick_stairs, res.output_item);
    try std.testing.expectEqual(@as(u32, 4), res.output_count);
    try std.testing.expectEqual(@as(u32, 6), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), res.remainder_count);
}

test "22. Architectural Crafting: Less than 6 blocks cannot craft stairs" {
    try std.testing.expect(craftResinBrickStairs(5) == null);
    try std.testing.expect(craftResinBrickStairs(0) == null);
}

test "23. Architectural Crafting: Batch stairs crafting (24 blocks -> 16 stairs)" {
    const res = craftResinBrickStairs(24).?;
    try std.testing.expectEqual(@as(u32, 16), res.output_count);
    try std.testing.expectEqual(@as(u32, 24), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), res.remainder_count);
}

test "24. Architectural Crafting: 3 Resin Bricks blocks craft 6 Resin Brick Slabs" {
    const res = craftResinBrickSlabs(3).?;
    try std.testing.expectEqual(ItemType.resin_brick_slab, res.output_item);
    try std.testing.expectEqual(@as(u32, 6), res.output_count);
    try std.testing.expectEqual(@as(u32, 3), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), res.remainder_count);
}

test "25. Architectural Crafting: Less than 3 blocks cannot craft slabs" {
    try std.testing.expect(craftResinBrickSlabs(2) == null);
    try std.testing.expect(craftResinBrickSlabs(0) == null);
}

test "26. Architectural Crafting: Batch slabs crafting (10 blocks -> 18 slabs, 1 remainder)" {
    const res = craftResinBrickSlabs(10).?;
    try std.testing.expectEqual(@as(u32, 18), res.output_count);
    try std.testing.expectEqual(@as(u32, 9), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 1), res.remainder_count);
}

test "27. Architectural Crafting: 6 Resin Bricks blocks craft 6 Resin Brick Walls" {
    const res = craftResinBrickWalls(6).?;
    try std.testing.expectEqual(ItemType.resin_brick_wall, res.output_item);
    try std.testing.expectEqual(@as(u32, 6), res.output_count);
    try std.testing.expectEqual(@as(u32, 6), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), res.remainder_count);
}

test "28. Architectural Crafting: Less than 6 blocks cannot craft walls" {
    try std.testing.expect(craftResinBrickWalls(5) == null);
}

test "29. Architectural Crafting: Batch walls crafting (18 blocks -> 18 walls)" {
    const res = craftResinBrickWalls(18).?;
    try std.testing.expectEqual(@as(u32, 18), res.output_count);
    try std.testing.expectEqual(@as(u32, 18), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), res.remainder_count);
}

test "30. Architectural Crafting: 2 Resin Brick Slabs craft 1 Chiseled Resin Bricks block" {
    const res = craftChiseledResinBricks(2).?;
    try std.testing.expectEqual(ItemType.chiseled_resin_bricks, res.output_item);
    try std.testing.expectEqual(@as(u32, 1), res.output_count);
    try std.testing.expectEqual(@as(u32, 2), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), res.remainder_count);
}

test "31. Architectural Crafting: 1 slab cannot craft Chiseled Resin Bricks" {
    try std.testing.expect(craftChiseledResinBricks(1) == null);
    try std.testing.expect(craftChiseledResinBricks(0) == null);
}

test "32. Architectural Crafting: Batch chiseled crafting (9 slabs -> 4 chiseled blocks, 1 remainder)" {
    const res = craftChiseledResinBricks(9).?;
    try std.testing.expectEqual(@as(u32, 4), res.output_count);
    try std.testing.expectEqual(@as(u32, 8), res.consumed_count);
    try std.testing.expectEqual(@as(u32, 1), res.remainder_count);
}

test "33. 3x3 Grid Pattern: Left-ascending L-shape crafts Stairs" {
    const b = ItemStack.init(.resin_bricks, 1);
    const e = ItemStack{};
    const grid = [_]ItemStack{
        b, e, e,
        b, b, e,
        b, b, b,
    };
    const res = craftStairsGrid3x3(grid).?;
    try std.testing.expectEqual(ItemType.resin_brick_stairs, res.output_item);
    try std.testing.expectEqual(@as(u32, 4), res.output_count);
}

test "34. 3x3 Grid Pattern: Right-ascending L-shape crafts Stairs" {
    const b = ItemStack.init(.resin_bricks, 1);
    const e = ItemStack{};
    const grid = [_]ItemStack{
        e, e, b,
        e, b, b,
        b, b, b,
    };
    const res = craftStairsGrid3x3(grid).?;
    try std.testing.expectEqual(ItemType.resin_brick_stairs, res.output_item);
    try std.testing.expectEqual(@as(u32, 4), res.output_count);
}

test "35. 3x3 Grid Pattern: Horizontal 3-block row crafts Slabs" {
    const b = ItemStack.init(.resin_bricks, 1);
    const e = ItemStack{};
    // Middle row
    const grid = [_]ItemStack{
        e, e, e,
        b, b, b,
        e, e, e,
    };
    const res = craftSlabsGrid3x3(grid).?;
    try std.testing.expectEqual(ItemType.resin_brick_slab, res.output_item);
    try std.testing.expectEqual(@as(u32, 6), res.output_count);
}

test "36. 3x3 Grid Pattern: Two horizontal rows craft Walls" {
    const b = ItemStack.init(.resin_bricks, 1);
    const e = ItemStack{};
    // Top two rows
    const grid = [_]ItemStack{
        b, b, b,
        b, b, b,
        e, e, e,
    };
    const res = craftWallsGrid3x3(grid).?;
    try std.testing.expectEqual(ItemType.resin_brick_wall, res.output_item);
    try std.testing.expectEqual(@as(u32, 6), res.output_count);
}

test "37. 2x2 Grid Pattern: Vertical column of slabs crafts Chiseled Resin Bricks" {
    const s = ItemStack.init(.resin_brick_slab, 1);
    const e = ItemStack{};
    // Left column
    const grid = [_]ItemStack{
        s, e,
        s, e,
    };
    const res = craftChiseledGrid2x2(grid).?;
    try std.testing.expectEqual(ItemType.chiseled_resin_bricks, res.output_item);
    try std.testing.expectEqual(@as(u32, 1), res.output_count);
}

test "38. Stairs Shape: Straight stair with no neighbors" {
    const none_stair = StairNeighbor{};
    const shape = determineStairShape(.north, .bottom, none_stair, none_stair, none_stair, none_stair);
    try std.testing.expectEqual(StairShape.straight, shape);
}

test "39. Stairs Shape: Inner corner left based on neighbor stair behind facing left" {
    const back_stair = StairNeighbor{ .is_stair = true, .facing = .west, .half = .bottom };
    const shape = determineStairShape(.north, .bottom, .{}, back_stair, .{}, .{});
    try std.testing.expectEqual(StairShape.inner_left, shape);
}

test "40. Stairs Shape: Inner corner right based on neighbor stair behind facing right" {
    const back_stair = StairNeighbor{ .is_stair = true, .facing = .east, .half = .bottom };
    const shape = determineStairShape(.north, .bottom, .{}, back_stair, .{}, .{});
    try std.testing.expectEqual(StairShape.inner_right, shape);
}

test "41. Stairs Shape: Outer corner left based on neighbor stair in front facing left" {
    const front_stair = StairNeighbor{ .is_stair = true, .facing = .west, .half = .bottom };
    const shape = determineStairShape(.north, .bottom, front_stair, .{}, .{}, .{});
    try std.testing.expectEqual(StairShape.outer_left, shape);
}

test "42. Stairs Shape: Outer corner right based on neighbor stair in front facing right" {
    const front_stair = StairNeighbor{ .is_stair = true, .facing = .east, .half = .bottom };
    const shape = determineStairShape(.north, .bottom, front_stair, .{}, .{}, .{});
    try std.testing.expectEqual(StairShape.outer_right, shape);
}

test "43. Stairs Half: Lower half vs upper half upside down state" {
    const normal_stair = StairState{ .facing = .north, .half = .bottom, .shape = .straight };
    const upside_down = StairState{ .facing = .north, .half = .top, .shape = .straight };

    try std.testing.expectEqual(StairHalf.bottom, normal_stair.half);
    try std.testing.expectEqual(StairHalf.top, upside_down.half);
    try std.testing.expectEqual(@as(f32, 1.0), normal_stair.getCollisionHeight());
    try std.testing.expectEqual(@as(f32, 1.0), upside_down.getCollisionHeight());
}

test "44. Slab Half: Bottom slab height is 0.5m with Y bounds [0.0, 0.5]" {
    const slab = SlabState.bottom;
    try std.testing.expectEqual(@as(f32, 0.5), slab.height());
    try std.testing.expectEqual(@as(f32, 0.0), slab.yMin());
    try std.testing.expectEqual(@as(f32, 0.5), slab.yMax());
    try std.testing.expectEqual(false, slab.isDouble());
}

test "45. Slab Half: Top slab height is 0.5m with Y bounds [0.5, 1.0]" {
    const slab = SlabState.top;
    try std.testing.expectEqual(@as(f32, 0.5), slab.height());
    try std.testing.expectEqual(@as(f32, 0.5), slab.yMin());
    try std.testing.expectEqual(@as(f32, 1.0), slab.yMax());
    try std.testing.expectEqual(false, slab.isDouble());
}

test "46. Slab Combining: Placing slab on bottom slab combines into double slab (height 1.0m, [0.0, 1.0])" {
    const place_res = placeSlab(.bottom, .top);
    try std.testing.expectEqual(SlabPlacementResult.combined_into_double_slab, place_res.outcome);
    try std.testing.expectEqual(SlabState.double_slab, place_res.new_state);
    try std.testing.expectEqual(@as(f32, 1.0), place_res.new_state.height());
    try std.testing.expectEqual(@as(f32, 0.0), place_res.new_state.yMin());
    try std.testing.expectEqual(@as(f32, 1.0), place_res.new_state.yMax());
    try std.testing.expect(place_res.new_state.isDouble());
}

test "47. Slab Combining: Placing slab on top slab combines into double slab" {
    const place_res = placeSlab(.top, .bottom);
    try std.testing.expectEqual(SlabPlacementResult.combined_into_double_slab, place_res.outcome);
    try std.testing.expectEqual(SlabState.double_slab, place_res.new_state);
}

test "48. Slab Combining: Placing on existing double slab is rejected" {
    const place_res = placeSlab(.double_slab, .bottom);
    try std.testing.expectEqual(SlabPlacementResult.rejected_occupied, place_res.outcome);
    try std.testing.expectEqual(SlabState.double_slab, place_res.new_state);
}

test "49. Wall Connections: Isolated wall creates center pillar post" {
    const neighbors = CardinalNeighbors{};
    const wall = computeWallConnections(neighbors);
    try std.testing.expect(wall.post);
    try std.testing.expectEqual(WallConnection.none, wall.north);
    try std.testing.expectEqual(WallConnection.none, wall.south);
    try std.testing.expectEqual(WallConnection.none, wall.east);
    try std.testing.expectEqual(WallConnection.none, wall.west);
    try std.testing.expectEqual(false, wall.hasConnections());
}

test "50. Wall Connections: Straight North-South wall lowers center post" {
    const neighbors = CardinalNeighbors{
        .north_solid_or_wall = true,
        .south_solid_or_wall = true,
        .east_solid_or_wall = false,
        .west_solid_or_wall = false,
        .above_solid = false,
    };
    const wall = computeWallConnections(neighbors);
    try std.testing.expectEqual(false, wall.post); // lowered post
    try std.testing.expectEqual(WallConnection.low, wall.north);
    try std.testing.expectEqual(WallConnection.low, wall.south);
    try std.testing.expect(wall.hasConnections());
}

test "51. Wall Connections: Straight East-West wall lowers center post" {
    const neighbors = CardinalNeighbors{
        .north_solid_or_wall = false,
        .south_solid_or_wall = false,
        .east_solid_or_wall = true,
        .west_solid_or_wall = true,
        .above_solid = false,
    };
    const wall = computeWallConnections(neighbors);
    try std.testing.expectEqual(false, wall.post);
    try std.testing.expectEqual(WallConnection.low, wall.east);
    try std.testing.expectEqual(WallConnection.low, wall.west);
}

test "52. Wall Connections: Corner or T-junction keeps post raised" {
    const corner = CardinalNeighbors{
        .north_solid_or_wall = true,
        .east_solid_or_wall = true,
    };
    const wall = computeWallConnections(corner);
    try std.testing.expect(wall.post); // raised post at corners
    try std.testing.expectEqual(WallConnection.low, wall.north);
    try std.testing.expectEqual(WallConnection.low, wall.east);
}

test "53. Wall Connections: Solid block above creates tall connection and raises post" {
    const straight_with_roof = CardinalNeighbors{
        .north_solid_or_wall = true,
        .south_solid_or_wall = true,
        .above_solid = true,
    };
    const wall = computeWallConnections(straight_with_roof);
    try std.testing.expect(wall.post);
    try std.testing.expectEqual(WallConnection.tall, wall.north);
    try std.testing.expectEqual(WallConnection.tall, wall.south);
}

test "54. Wall Collision: Collision height is 1.5m (jump-proof)" {
    const wall = WallState{};
    try std.testing.expectEqual(@as(f32, 1.5), wall.getCollisionHeight());
    try std.testing.expectEqual(@as(f32, 1.0), wall.getVisualHeight());
}

test "55. Stonecutter: 1 Resin Bricks -> 1 Resin Brick Stairs" {
    const res = stonecutResinBricks(.resin_brick_stairs, 1).?;
    try std.testing.expectEqual(ItemType.resin_brick_stairs, res.output_item);
    try std.testing.expectEqual(@as(u32, 1), res.output_count);
    try std.testing.expectEqual(@as(u32, 1), res.consumed_count);
}

test "56. Stonecutter: 1 Resin Bricks -> 2 Resin Brick Slabs" {
    const res = stonecutResinBricks(.resin_brick_slab, 1).?;
    try std.testing.expectEqual(ItemType.resin_brick_slab, res.output_item);
    try std.testing.expectEqual(@as(u32, 2), res.output_count);
    try std.testing.expectEqual(@as(u32, 1), res.consumed_count);
}

test "57. Stonecutter: 1 Resin Bricks -> 1 Resin Brick Wall" {
    const res = stonecutResinBricks(.resin_brick_wall, 1).?;
    try std.testing.expectEqual(ItemType.resin_brick_wall, res.output_item);
    try std.testing.expectEqual(@as(u32, 1), res.output_count);
    try std.testing.expectEqual(@as(u32, 1), res.consumed_count);
}

test "58. Stonecutter: 1 Resin Bricks -> 1 Chiseled Resin Bricks" {
    const res = stonecutResinBricks(.chiseled_resin_bricks, 1).?;
    try std.testing.expectEqual(ItemType.chiseled_resin_bricks, res.output_item);
    try std.testing.expectEqual(@as(u32, 1), res.output_count);
    try std.testing.expectEqual(@as(u32, 1), res.consumed_count);
}

test "59. Stonecutter: Batch stonecutting yields correct proportional counts" {
    const slabs = stonecutResinBricks(.resin_brick_slab, 10).?;
    try std.testing.expectEqual(@as(u32, 20), slabs.output_count);

    const stairs = stonecutResinBricks(.resin_brick_stairs, 5).?;
    try std.testing.expectEqual(@as(u32, 5), stairs.output_count);

    const walls = stonecutResinBricks(.resin_brick_wall, 7).?;
    try std.testing.expectEqual(@as(u32, 7), walls.output_count);

    const chiseled = stonecutResinBricks(.chiseled_resin_bricks, 3).?;
    try std.testing.expectEqual(@as(u32, 3), chiseled.output_count);
}

test "60. Stonecutter: Rejects invalid target items or 0 count" {
    try std.testing.expect(stonecutResinBricks(.resin_brick, 1) == null);
    try std.testing.expect(stonecutResinBricks(.resin_clump, 1) == null);
    try std.testing.expect(stonecutResinBricks(.resin_brick_stairs, 0) == null);
}

test "61. Block Physical Attributes: Hardness 1.5 and blast resistance 6.0 across all variants" {
    const variants = [_]BlockId{
        .resin_bricks,
        .resin_brick_stairs,
        .resin_brick_slab,
        .resin_brick_wall,
        .chiseled_resin_bricks,
        .double_resin_brick_slab,
    };
    for (variants) |v| {
        try std.testing.expectEqual(@as(f32, 1.5), v.hardness());
        try std.testing.expectEqual(@as(f32, 6.0), v.blastResistance());
        try std.testing.expect(v.isSolid());
    }
}

test "62. Tool Requirement: Wooden pickaxe or higher harvests Resin Bricks" {
    const wooden_pick = MiningTool{ .category = .pickaxe, .tier = .wooden };
    const outcome = evaluateBlockMining(.resin_bricks, wooden_pick);
    try std.testing.expect(outcome.can_harvest);
    try std.testing.expectEqual(ItemType.resin_bricks, outcome.drops_item);
    try std.testing.expectEqual(@as(u8, 1), outcome.drops_count);
}

test "63. Tool Requirement: Higher tiered pickaxes (Stone, Iron, Diamond, Netherite, Gold) harvest drops" {
    const tiers = [_]ToolTier{ .stone, .iron, .diamond, .netherite, .golden };
    for (tiers) |tier| {
        const pick = MiningTool{ .category = .pickaxe, .tier = tier };
        const outcome = evaluateBlockMining(.resin_bricks, pick);
        try std.testing.expect(outcome.can_harvest);
        try std.testing.expectEqual(ItemType.resin_bricks, outcome.drops_item);
        try std.testing.expectEqual(@as(u8, 1), outcome.drops_count);
    }
}

test "64. Tool Requirement: Bare hand breaks block but drops 0 items" {
    const bare_hand = MiningTool{ .category = .bare_hand, .tier = .none };
    const outcome = evaluateBlockMining(.resin_bricks, bare_hand);
    try std.testing.expectEqual(false, outcome.can_harvest);
    try std.testing.expectEqual(ItemType.none, outcome.drops_item);
    try std.testing.expectEqual(@as(u8, 0), outcome.drops_count);
}

test "65. Tool Requirement: Non-pickaxe tools (Axe, Shovel, Hoe, Sword, Shears) drop 0 items" {
    const categories = [_]ToolCategory{ .axe, .shovel, .hoe, .sword, .shears };
    for (categories) |cat| {
        const tool = MiningTool{ .category = cat, .tier = .diamond };
        const outcome = evaluateBlockMining(.resin_bricks, tool);
        try std.testing.expectEqual(false, outcome.can_harvest);
        try std.testing.expectEqual(ItemType.none, outcome.drops_item);
        try std.testing.expectEqual(@as(u8, 0), outcome.drops_count);
    }
}

test "66. Double Slab Drops: Mining double slab with pickaxe drops 2 slab items" {
    const pick = MiningTool{ .category = .pickaxe, .tier = .iron };
    const outcome = evaluateBlockMining(.double_resin_brick_slab, pick);
    try std.testing.expect(outcome.can_harvest);
    try std.testing.expectEqual(ItemType.resin_brick_slab, outcome.drops_item);
    try std.testing.expectEqual(@as(u8, 2), outcome.drops_count);
}

test "67. Fire Resistance: All resin brick variants are immune to fire spread and lava ignition" {
    const variants = [_]BlockId{
        .resin_bricks,
        .resin_brick_stairs,
        .resin_brick_slab,
        .resin_brick_wall,
        .chiseled_resin_bricks,
        .double_resin_brick_slab,
    };
    for (variants) |v| {
        try std.testing.expect(v.isFireResistant());
        try std.testing.expect(isFireSpreadImmune(v));
        try std.testing.expect(isLavaIgnitionImmune(v));
    }
}

test "68. End-to-end Pipeline: Raw Clumps -> Smelt -> Craft Blocks -> Masonry & Stonecutting" {
    // 1. Smelt 40 Resin Clumps in blast furnace (100 ticks each = 4000 ticks)
    const smelt_res = smeltResinClump(.resin_clump, 40, .blast_furnace).?;
    try std.testing.expectEqual(ItemType.resin_brick, smelt_res.output_item);
    try std.testing.expectEqual(@as(u32, 40), smelt_res.output_count);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), smelt_res.experience_yield, 0.0001);

    // 2. Craft 40 bricks in 2x2 grid into 10 Block of Resin Bricks
    const craft_res = craftResinBricks(smelt_res.output_count).?;
    try std.testing.expectEqual(ItemType.resin_bricks, craft_res.output_item);
    try std.testing.expectEqual(@as(u32, 10), craft_res.output_count);

    // 3. Stonecut 2 blocks into 2 Stairs
    const stairs = stonecutResinBricks(.resin_brick_stairs, 2).?;
    try std.testing.expectEqual(@as(u32, 2), stairs.output_count);

    // 4. Stonecut 2 blocks into 4 Slabs
    const slabs = stonecutResinBricks(.resin_brick_slab, 2).?;
    try std.testing.expectEqual(@as(u32, 4), slabs.output_count);

    // 5. Craft 2 of the slabs into 1 Chiseled Resin Bricks block
    const chiseled = craftChiseledResinBricks(2).?;
    try std.testing.expectEqual(@as(u32, 1), chiseled.output_count);

    // 6. Stonecut 2 blocks into 2 Walls
    const walls = stonecutResinBricks(.resin_brick_wall, 2).?;
    try std.testing.expectEqual(@as(u32, 2), walls.output_count);

    // 7. Place 2 remaining slabs into a double slab and harvest with diamond pickaxe
    const merge = placeSlab(.bottom, .top);
    try std.testing.expect(merge.new_state.isDouble());

    const mine_outcome = evaluateBlockMining(.double_resin_brick_slab, .{ .category = .pickaxe, .tier = .diamond });
    try std.testing.expect(mine_outcome.can_harvest);
    try std.testing.expectEqual(@as(u8, 2), mine_outcome.drops_count);
    try std.testing.expectEqual(ItemType.resin_brick_slab, mine_outcome.drops_item);
}
