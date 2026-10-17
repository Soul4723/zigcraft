const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

// ============================================================================
// Milestone 415: Wooden Fences, Fence Gates & Stone Walls
// ============================================================================
// Core mechanics implemented:
// 1. FenceAndGateRecipes:
//    - Wooden Fence: 4 planks + 2 sticks -> 3 wooden fences
//    - Fence Gate: 2 planks + 4 sticks -> 1 fence gate
//    - Stone/Brick Wall: 6 stone/brick blocks -> 6 walls (craftWalls)
//    - Nether Brick Fence: 4 nether bricks + 2 nether brick items -> 3 fences
// 2. CollisionHeightRule:
//    - Visual height: 1.0 block
//    - Physical collision box height: 1.5 blocks
//    - Carpet on top: reduces hurdle height to 1.0625 blocks
//    - Jump reach checks (player 1.252 blocked without carpet; jump boost, horse,
//      camel, goat can jump over)
// 3. FenceConnectionRule:
//    - All wooden fences connect horizontally to each other and to fence gates
//    - Nether brick fence connects only to nether brick fences and fence gates
//    - doFencesConnect(a_is_nether_brick, b_is_nether_brick) == (a == b)
//    - 0.75-block walkable gap between wooden & nether fences (player 0.6 fits,
//      mobs >= 0.8 blocked)
// 4. WallPillarPostRule:
//    - Straight line of 2+ connected walls forms smooth flush wall without center post
//    - End-caps, corners, T-junctions, cross-junctions raise center pillar post
//    - Block/torch/lantern directly above raises center pillar post
//    - Emits vertical block state change detectable by an Observer
// 5. FenceGateWallAlignment:
//    - Fence gate between stone walls lowers model by 3 pixels (0.1875 blocks)
//    - Aligns flush with stone wall side bars (13/16 = 0.8125 blocks)
// ============================================================================

// ============================================================================
// 1. FenceAndGateRecipes
// ============================================================================

pub const FenceAndGateRecipes = struct {
    pub const WOODEN_FENCE_PLANKS_COST: u16 = 4;
    pub const WOODEN_FENCE_STICKS_COST: u16 = 2;
    pub const WOODEN_FENCE_YIELD: u16 = 3;

    pub const FENCE_GATE_PLANKS_COST: u16 = 2;
    pub const FENCE_GATE_STICKS_COST: u16 = 4;
    pub const FENCE_GATE_YIELD: u16 = 1;

    pub const WALL_BLOCKS_COST: u8 = 6;
    pub const WALL_YIELD: u8 = 6;

    pub const NETHER_BRICK_FENCE_BLOCKS_COST: u16 = 4;
    pub const NETHER_BRICK_FENCE_ITEMS_COST: u16 = 2;
    pub const NETHER_BRICK_FENCE_YIELD: u16 = 3;

    pub const NETHER_BRICK_FENCE_LEGACY_BLOCKS_COST: u16 = 6;
    pub const NETHER_BRICK_FENCE_LEGACY_YIELD: u16 = 6;

    pub const WoodenFenceCraftResult = struct {
        fences: u16,
        planks_consumed: u16,
        sticks_consumed: u16,
        planks_remaining: u16,
        sticks_remaining: u16,
    };

    pub const FenceGateCraftResult = struct {
        gates: u16,
        planks_consumed: u16,
        sticks_consumed: u16,
        planks_remaining: u16,
        sticks_remaining: u16,
    };

    pub const WallCraftResult = struct {
        walls: u8,
        blocks_consumed: u8,
        blocks_remaining: u8,
    };

    pub const NetherBrickFenceCraftResult = struct {
        fences: u16,
        blocks_consumed: u16,
        items_consumed: u16,
        blocks_remaining: u16,
        items_remaining: u16,
    };

    /// Crafts wooden fences from planks and sticks:
    /// 4 planks + 2 sticks -> 3 wooden fences.
    pub fn craftWoodenFence(planks: u16, sticks: u16) u16 {
        const batches = @min(planks / WOODEN_FENCE_PLANKS_COST, sticks / WOODEN_FENCE_STICKS_COST);
        return batches * WOODEN_FENCE_YIELD;
    }

    /// Alias for craftWoodenFence.
    pub fn craftWoodenFences(planks: u16, sticks: u16) u16 {
        return FenceAndGateRecipes.craftWoodenFence(planks, sticks);
    }

    /// Crafts wooden fences with detailed breakdown of consumed and remaining ingredients.
    pub fn craftWoodenFenceDetailed(planks: u16, sticks: u16) WoodenFenceCraftResult {
        const batches = @min(planks / WOODEN_FENCE_PLANKS_COST, sticks / WOODEN_FENCE_STICKS_COST);
        const f_yield = batches * WOODEN_FENCE_YIELD;
        const p_used = batches * WOODEN_FENCE_PLANKS_COST;
        const s_used = batches * WOODEN_FENCE_STICKS_COST;
        return .{
            .fences = f_yield,
            .planks_consumed = p_used,
            .sticks_consumed = s_used,
            .planks_remaining = planks - p_used,
            .sticks_remaining = sticks - s_used,
        };
    }

    /// Crafts fence gates from planks and sticks:
    /// 2 planks + 4 sticks -> 1 fence gate.
    pub fn craftFenceGate(planks: u16, sticks: u16) u16 {
        const batches = @min(planks / FENCE_GATE_PLANKS_COST, sticks / FENCE_GATE_STICKS_COST);
        return batches * FENCE_GATE_YIELD;
    }

    /// Crafts fence gates with detailed breakdown of consumed and remaining ingredients.
    pub fn craftFenceGateDetailed(planks: u16, sticks: u16) FenceGateCraftResult {
        const batches = @min(planks / FENCE_GATE_PLANKS_COST, sticks / FENCE_GATE_STICKS_COST);
        const g_yield = batches * FENCE_GATE_YIELD;
        const p_used = batches * FENCE_GATE_PLANKS_COST;
        const s_used = batches * FENCE_GATE_STICKS_COST;
        return .{
            .gates = g_yield,
            .planks_consumed = p_used,
            .sticks_consumed = s_used,
            .planks_remaining = planks - p_used,
            .sticks_remaining = sticks - s_used,
        };
    }

    /// Crafts stone/brick/deepslate/sandstone walls:
    /// 6 blocks -> 6 walls.
    pub fn craftWalls(blocks: u8) u8 {
        const batches = blocks / WALL_BLOCKS_COST;
        return batches * WALL_YIELD;
    }

    /// Crafts walls with detailed breakdown of consumed and remaining blocks.
    pub fn craftWallsDetailed(blocks: u8) WallCraftResult {
        const batches = blocks / WALL_BLOCKS_COST;
        const w_yield = batches * WALL_YIELD;
        const b_used = batches * WALL_BLOCKS_COST;
        return .{
            .walls = w_yield,
            .blocks_consumed = b_used,
            .blocks_remaining = blocks - b_used,
        };
    }

    /// Modern recipe: 4 Nether Bricks (blocks) + 2 Nether Brick (items) -> 3 Nether Brick Fences.
    pub fn craftNetherBrickFences(nether_brick_blocks: u16, nether_brick_items: u16) u16 {
        const batches = @min(nether_brick_blocks / NETHER_BRICK_FENCE_BLOCKS_COST, nether_brick_items / NETHER_BRICK_FENCE_ITEMS_COST);
        return batches * NETHER_BRICK_FENCE_YIELD;
    }

    /// Modern recipe detailed breakdown.
    pub fn craftNetherBrickFencesDetailed(nether_brick_blocks: u16, nether_brick_items: u16) NetherBrickFenceCraftResult {
        const batches = @min(nether_brick_blocks / NETHER_BRICK_FENCE_BLOCKS_COST, nether_brick_items / NETHER_BRICK_FENCE_ITEMS_COST);
        const f_yield = batches * NETHER_BRICK_FENCE_YIELD;
        const b_used = batches * NETHER_BRICK_FENCE_BLOCKS_COST;
        const i_used = batches * NETHER_BRICK_FENCE_ITEMS_COST;
        return .{
            .fences = f_yield,
            .blocks_consumed = b_used,
            .items_consumed = i_used,
            .blocks_remaining = nether_brick_blocks - b_used,
            .items_remaining = nether_brick_items - i_used,
        };
    }

    /// Legacy / stonecutter recipe: 6 nether brick blocks -> 6 nether brick fences.
    pub fn craftNetherBrickFencesLegacy(nether_brick_blocks: u16) u16 {
        const batches = nether_brick_blocks / NETHER_BRICK_FENCE_LEGACY_BLOCKS_COST;
        return batches * NETHER_BRICK_FENCE_LEGACY_YIELD;
    }

    /// Validates if an input block is suitable for crafting stone/brick walls.
    pub fn isWallCraftableBlock(block: BlockId) bool {
        return switch (block) {
            .stone,
            .cobblestone,
            .sandstone,
            .brick,
            .nether_brick,
            .deepslate,
            .cobbled_deepslate,
            .polished_deepslate,
            .deepslate_bricks,
            .mud_bricks,
            .tuff,
            .polished_tuff,
            .tuff_bricks,
            => true,
            else => false,
        };
    }
};

// ============================================================================
// 2. CollisionHeightRule
// ============================================================================

pub const CollisionHeightRule = struct {
    /// Visual block height in the world model (1.0 block).
    pub const visual_height: f32 = 1.0;

    /// Physical collision box height (1.5 blocks), preventing players and livestock from jumping over.
    pub const collision_height: f32 = 1.5;

    /// Thickness of carpet layer resting on top of fence (1/16th block).
    pub const carpet_thickness: f32 = 1.0 / 16.0; // 0.0625

    /// Effective collision top Y when a carpet is placed on top of a fence (1.0625 blocks).
    pub const carpet_top_y: f32 = CollisionHeightRule.visual_height + CollisionHeightRule.carpet_thickness; // 1.0625

    /// Standard player jump height in vanilla Minecraft (1.252 blocks).
    pub const player_standard_jump_height: f32 = 1.252;

    /// Player jump height with Jump Boost I (approx 1.95 blocks).
    pub const jump_boost_1_jump_height: f32 = 1.95;

    /// Player jump height with Jump Boost II (approx 2.50 blocks).
    pub const jump_boost_2_jump_height: f32 = 2.50;

    /// Livestock standard jump height (1.0 block).
    pub const livestock_jump_height: f32 = 1.0;

    /// Minimum horse jump height (1.5 blocks).
    pub const horse_min_jump_height: f32 = 1.5;

    /// Maximum horse jump height (5.25 blocks).
    pub const horse_max_jump_height: f32 = 5.25;

    /// Camel step height / clearance reach (1.5 blocks).
    pub const camel_step_reach: f32 = 1.5;

    /// Mountain goat jump height (up to 5.0 blocks).
    pub const goat_jump_height: f32 = 5.0;

    /// Rabbit jump height (approx 1.25 blocks).
    pub const rabbit_jump_height: f32 = 1.25;

    /// Returns the effective hurdle height of a fence/wall.
    /// If carpet is on top, collision height is capped at carpet_top_y (1.0625).
    /// Otherwise, it acts as full 1.5 collision height.
    pub fn getEffectiveHurdleHeight(has_carpet_on_top: bool) f32 {
        return if (has_carpet_on_top) CollisionHeightRule.carpet_top_y else CollisionHeightRule.collision_height;
    }

    /// Evaluates if an entity with given jump reach can jump over a fence or wall:
    /// - Standard player (1.252) cannot jump over 1.5 fence without carpet: false.
    /// - Standard player (1.252) CAN jump over fence with carpet (1.0625): true.
    /// - Entities with jump reach >= 1.5 (Jump Boost, Horse, Camel, Goat) can jump over without carpet.
    pub fn canEntityJumpOverFence(jump_reach: f32, has_carpet_on_top: bool) bool {
        const hurdle = CollisionHeightRule.getEffectiveHurdleHeight(has_carpet_on_top);
        return jump_reach >= hurdle;
    }

    /// Evaluates if an entity can clear a fence considering both jump reach and passive step height.
    pub fn canEntityClearFence(jump_reach: f32, step_height: f32, has_carpet_on_top: bool) bool {
        const hurdle = CollisionHeightRule.getEffectiveHurdleHeight(has_carpet_on_top);
        return (jump_reach >= hurdle) or (step_height >= hurdle);
    }
};

// ============================================================================
// 3. FenceConnectionRule
// ============================================================================

pub const FenceConnectionRule = struct {
    /// Width of player collision box (0.6 blocks).
    pub const player_width: f32 = 0.6;

    /// Center post width of a fence block (4/16 = 0.25 blocks).
    pub const fence_post_width: f32 = 4.0 / 16.0; // 0.25

    /// Center post min offset within block coordinate [0, 1] (6/16 = 0.375).
    pub const fence_post_min_offset: f32 = 6.0 / 16.0; // 0.375

    /// Center post max offset within block coordinate [0, 1] (10/16 = 0.625).
    pub const fence_post_max_offset: f32 = 10.0 / 16.0; // 0.625

    /// Walkable gap between unconnected wooden and nether brick fence posts (12/16 = 0.75 blocks).
    pub const fence_gap_width: f32 = 12.0 / 16.0; // 0.75

    /// Mob width threshold for being blocked by the nether-wood fence gap (0.8 blocks).
    pub const mob_blocked_width_threshold: f32 = 0.8;

    /// Fence connection rule:
    /// - Wooden fences connect to other wooden fences (regardless of species): true.
    /// - Nether brick fences connect to other nether brick fences: true.
    /// - Nether brick fences NEVER connect horizontally to wooden fences: false.
    /// Formula: a_is_nether_brick == b_is_nether_brick.
    pub fn doFencesConnect(a_is_nether_brick: bool, b_is_nether_brick: bool) bool {
        return a_is_nether_brick == b_is_nether_brick;
    }

    /// Fences (both wooden and nether brick) always connect to fence gates.
    pub fn doesFenceConnectToGate(fence_is_nether_brick: bool) bool {
        _ = fence_is_nether_brick;
        return true;
    }

    /// Evaluates if an entity of given collision width can squeeze through the 0.75-block gap
    /// formed between adjacent unconnected wooden and nether brick fences.
    /// - Player width 0.6 <= 0.75 -> true (can squeeze through).
    /// - Wider mobs (width >= 0.8) -> false (blocked).
    pub fn canEntitySqueezeThroughFenceGap(entity_width: f32) bool {
        return entity_width <= FenceConnectionRule.fence_gap_width;
    }

    /// Returns true if a mob is blocked by the nether-wood fence gap.
    pub fn isMobBlockedByFenceGap(mob_width: f32) bool {
        return !FenceConnectionRule.canEntitySqueezeThroughFenceGap(mob_width);
    }
};

// ============================================================================
// 4. WallPillarPostRule
// ============================================================================

pub const WallConnections = struct {
    north: bool = false,
    south: bool = false,
    east: bool = false,
    west: bool = false,

    /// Returns the number of horizontal connections (0 to 4).
    pub fn count(self: WallConnections) u8 {
        var c: u8 = 0;
        if (self.north) c += 1;
        if (self.south) c += 1;
        if (self.east) c += 1;
        if (self.west) c += 1;
        return c;
    }

    /// Returns true if connections form a straight collinear line of 2 walls:
    /// (North and South only) OR (East and West only).
    pub fn isStraightLine(self: WallConnections) bool {
        if (self.count() != 2) return false;
        const ns = self.north and self.south and !self.east and !self.west;
        const ew = !self.north and !self.south and self.east and self.west;
        return ns or ew;
    }

    /// Returns true if connections form a 2-way corner (e.g. North-East, North-West, etc.).
    pub fn isCorner(self: WallConnections) bool {
        return (self.count() == 2) and !self.isStraightLine();
    }

    /// Returns true if connections form an end-cap (only 1 connection).
    pub fn isEndCap(self: WallConnections) bool {
        return self.count() == 1;
    }

    /// Returns true if connections form a T-junction (3 connections).
    pub fn isTJunction(self: WallConnections) bool {
        return self.count() == 3;
    }

    /// Returns true if connections form a cross-junction (4 connections).
    pub fn isCrossJunction(self: WallConnections) bool {
        return self.count() == 4;
    }

    /// Returns true if isolated (0 connections).
    pub fn isIsolated(self: WallConnections) bool {
        return self.count() == 0;
    }
};

pub const WallPillarPostRule = struct {
    /// Wall Pillar Post Formation rule:
    /// - A straight line of 2+ connected stone walls forms a smooth flush wall
    ///   WITHOUT a center pillar post (returns false).
    /// - An end-cap wall (1 connection), corner wall (2 perpendicular connections),
    ///   T-junction (3 connections), cross-junction (4 connections), or isolated post (0 connections)
    ///   always raises a central pillar post (returns true).
    /// - If a block, torch, lantern, or other attachment is placed directly above it,
    ///   a central pillar post is ALWAYS raised (returns true).
    pub fn hasCenterPillarPost(connections: WallConnections, has_block_above: bool) bool {
        if (has_block_above) return true;
        if (connections.isStraightLine()) return false;
        return true;
    }

    /// Observer blockstate detection result.
    pub const ObserverTriggerResult = struct {
        state_changed: bool,
        observer_triggered: bool,
    };

    /// Evaluates if an Observer observing the wall detects a state change
    /// when the wall's center pillar post toggles.
    pub fn evaluateObserver(old_has_post: bool, new_has_post: bool) ObserverTriggerResult {
        const changed = (old_has_post != new_has_post);
        return .{
            .state_changed = changed,
            .observer_triggered = changed,
        };
    }

    /// Checks if a block placed above a wall raises its central pillar post.
    /// Torches, lanterns, chains, solid blocks, and other walls raise the post.
    pub fn doesBlockAboveRaisePost(block: BlockId) bool {
        return switch (block) {
            .air, .water, .lava => false,
            .torch,
            .soul_torch,
            .redstone_torch_on,
            .redstone_torch_off,
            .lantern,
            .soul_lantern,
            .chain,
            .iron_bars,
            .oak_fence,
            .nether_brick_fence,
            => true,
            else => block.is_solid(),
        };
    }
};

// ============================================================================
// 5. FenceGateWallAlignment
// ============================================================================

pub const FenceGateWallAlignment = struct {
    /// Distance in pixels that a fence gate is lowered when placed between stone walls (3.0 pixels).
    pub const lowering_pixels: f32 = 3.0;

    /// Lowering offset in blocks (3 / 16 = 0.1875 blocks).
    pub const lowering_offset: f32 = 3.0 / 16.0; // 0.1875

    /// Standard fence gate model height (1.0 block = 16 pixels).
    pub const standard_gate_height: f32 = 1.0;

    /// Stone wall side connection bar height (13 / 16 = 0.8125 blocks = 13 pixels).
    pub const wall_side_bar_height: f32 = 13.0 / 16.0; // 0.8125

    /// Top Y coordinate of a lowered fence gate model (1.0 - 0.1875 = 0.8125 blocks),
    /// which aligns flush with the top of adjacent stone wall bars!
    pub const lowered_gate_top_y: f32 = standard_gate_height - lowering_offset; // 0.8125

    /// Evaluates if a fence gate is lowered between walls:
    /// Returns true when connected_to_wall is true.
    pub fn isLoweredBetweenWalls(connected_to_wall: bool) bool {
        return connected_to_wall;
    }

    /// Returns the vertical Y offset for rendering the fence gate model:
    /// Returns -0.1875 if lowered between walls, otherwise 0.0.
    pub fn getGateYOffset(connected_to_wall: bool) f32 {
        return if (FenceGateWallAlignment.isLoweredBetweenWalls(connected_to_wall)) -lowering_offset else 0.0;
    }

    /// Returns the effective visual top Y coordinate of the fence gate:
    /// 0.8125 when lowered between walls (flush with 13/16 wall bar), 1.0 otherwise.
    pub fn getGateTopY(connected_to_wall: bool) f32 {
        return if (FenceGateWallAlignment.isLoweredBetweenWalls(connected_to_wall)) lowered_gate_top_y else standard_gate_height;
    }

    /// Evaluates gate lowering based on whether adjacent neighbors along the gate's hinge axis are stone walls.
    pub fn isLoweredFromNeighbors(side_a_is_wall: bool, side_b_is_wall: bool) bool {
        return side_a_is_wall or side_b_is_wall;
    }
};

// ============================================================================
// Bounding Box & Collision Representation
// ============================================================================

pub const BoundingBox = struct {
    min_x: f32,
    min_y: f32,
    min_z: f32,
    max_x: f32,
    max_y: f32,
    max_z: f32,

    pub fn height(self: BoundingBox) f32 {
        return self.max_y - self.min_y;
    }

    pub fn widthX(self: BoundingBox) f32 {
        return self.max_x - self.min_x;
    }

    pub fn widthZ(self: BoundingBox) f32 {
        return self.max_z - self.min_z;
    }

    pub fn intersects(self: BoundingBox, other: BoundingBox) bool {
        return (self.min_x < other.max_x and self.max_x > other.min_x) and
            (self.min_y < other.max_y and self.max_y > other.min_y) and
            (self.min_z < other.max_z and self.max_z > other.min_z);
    }
};

pub const BarrierType = enum {
    wooden_fence,
    nether_brick_fence,
    fence_gate,
    stone_wall,
};

/// Computes the physical collision bounding box for a fence, gate, or wall block.
/// When a fence gate is open, its collision box is empty / disabled (returns null).
pub fn getBarrierCollisionBox(
    barrier: BarrierType,
    block_x: i32,
    block_y: i32,
    block_z: i32,
    is_gate_open: bool,
    has_carpet_on_top: bool,
) ?BoundingBox {
    if (barrier == .fence_gate and is_gate_open) {
        return null;
    }

    const xf: f32 = @floatFromInt(block_x);
    const yf: f32 = @floatFromInt(block_y);
    const zf: f32 = @floatFromInt(block_z);

    const h = CollisionHeightRule.getEffectiveHurdleHeight(has_carpet_on_top);

    return BoundingBox{
        .min_x = xf,
        .min_y = yf,
        .min_z = zf,
        .max_x = xf + 1.0,
        .max_y = yf + h,
        .max_z = zf + 1.0,
    };
}

// ============================================================================
// Root-Level Aliases & Exports
// ============================================================================

pub const craftWalls = FenceAndGateRecipes.craftWalls;
pub const craftWoodenFence = FenceAndGateRecipes.craftWoodenFence;
pub const craftWoodenFences = FenceAndGateRecipes.craftWoodenFences;
pub const craftFenceGate = FenceAndGateRecipes.craftFenceGate;
pub const craftNetherBrickFences = FenceAndGateRecipes.craftNetherBrickFences;

pub const visual_height = CollisionHeightRule.visual_height;
pub const collision_height = CollisionHeightRule.collision_height;
pub const canEntityJumpOverFence = CollisionHeightRule.canEntityJumpOverFence;
pub const getEffectiveHurdleHeight = CollisionHeightRule.getEffectiveHurdleHeight;

pub const doFencesConnect = FenceConnectionRule.doFencesConnect;
pub const doesFenceConnectToGate = FenceConnectionRule.doesFenceConnectToGate;
pub const player_width = FenceConnectionRule.player_width;
pub const canEntitySqueezeThroughFenceGap = FenceConnectionRule.canEntitySqueezeThroughFenceGap;
pub const isMobBlockedByFenceGap = FenceConnectionRule.isMobBlockedByFenceGap;

pub const hasCenterPillarPost = WallPillarPostRule.hasCenterPillarPost;
pub const evaluateObserver = WallPillarPostRule.evaluateObserver;

pub const isLoweredBetweenWalls = FenceGateWallAlignment.isLoweredBetweenWalls;
pub const getGateYOffset = FenceGateWallAlignment.getGateYOffset;
pub const getGateTopY = FenceGateWallAlignment.getGateTopY;

// ============================================================================
// Unit Tests (16 Comprehensive Tests)
// ============================================================================

test "1. FenceAndGateRecipes: wooden fence crafting (4 planks + 2 sticks -> 3 wooden fences)" {
    // Exact single batch: 4 planks + 2 sticks -> 3 fences
    try std.testing.expectEqual(@as(u16, 3), craftWoodenFence(4, 2));

    // Insufficient ingredients produce 0
    try std.testing.expectEqual(@as(u16, 0), craftWoodenFence(3, 2));
    try std.testing.expectEqual(@as(u16, 0), craftWoodenFence(4, 1));
    try std.testing.expectEqual(@as(u16, 0), craftWoodenFence(0, 0));

    // Multiple batches with remainders: 10 planks + 5 sticks -> 2 batches = 6 fences
    try std.testing.expectEqual(@as(u16, 6), craftWoodenFence(10, 5));

    // Detailed breakdown
    const detailed = FenceAndGateRecipes.craftWoodenFenceDetailed(10, 5);
    try std.testing.expectEqual(@as(u16, 6), detailed.fences);
    try std.testing.expectEqual(@as(u16, 8), detailed.planks_consumed);
    try std.testing.expectEqual(@as(u16, 4), detailed.sticks_consumed);
    try std.testing.expectEqual(@as(u16, 2), detailed.planks_remaining);
    try std.testing.expectEqual(@as(u16, 1), detailed.sticks_remaining);
}

test "2. FenceAndGateRecipes: fence gate crafting (2 planks + 4 sticks -> 1 fence gate)" {
    // Exact single batch: 2 planks + 4 sticks -> 1 gate
    try std.testing.expectEqual(@as(u16, 1), craftFenceGate(2, 4));

    // Insufficient ingredients produce 0
    try std.testing.expectEqual(@as(u16, 0), craftFenceGate(1, 4));
    try std.testing.expectEqual(@as(u16, 0), craftFenceGate(2, 3));
    try std.testing.expectEqual(@as(u16, 0), craftFenceGate(0, 0));

    // Multiple batches: 16 planks + 16 sticks -> min(16/2=8, 16/4=4) = 4 gates
    try std.testing.expectEqual(@as(u16, 4), craftFenceGate(16, 16));

    // Detailed breakdown
    const detailed = FenceAndGateRecipes.craftFenceGateDetailed(16, 16);
    try std.testing.expectEqual(@as(u16, 4), detailed.gates);
    try std.testing.expectEqual(@as(u16, 8), detailed.planks_consumed);
    try std.testing.expectEqual(@as(u16, 16), detailed.sticks_consumed);
    try std.testing.expectEqual(@as(u16, 8), detailed.planks_remaining);
    try std.testing.expectEqual(@as(u16, 0), detailed.sticks_remaining);
}

test "3. FenceAndGateRecipes: stone and brick wall crafting (craftWalls: 6 blocks -> 6 walls)" {
    // Exact single batch: 6 blocks -> 6 walls
    try std.testing.expectEqual(@as(u8, 6), craftWalls(6));

    // Less than 6 blocks produces 0
    try std.testing.expectEqual(@as(u8, 0), craftWalls(0));
    try std.testing.expectEqual(@as(u8, 0), craftWalls(5));

    // Multiple batches: 12 -> 12, 17 -> 12, 64 -> 60 (10 batches of 6)
    try std.testing.expectEqual(@as(u8, 12), craftWalls(12));
    try std.testing.expectEqual(@as(u8, 12), craftWalls(17));
    try std.testing.expectEqual(@as(u8, 60), craftWalls(64));

    // Detailed breakdown
    const detailed = FenceAndGateRecipes.craftWallsDetailed(64);
    try std.testing.expectEqual(@as(u8, 60), detailed.walls);
    try std.testing.expectEqual(@as(u8, 60), detailed.blocks_consumed);
    try std.testing.expectEqual(@as(u8, 4), detailed.blocks_remaining);

    // Wall craftable materials verification
    try std.testing.expect(FenceAndGateRecipes.isWallCraftableBlock(.stone));
    try std.testing.expect(FenceAndGateRecipes.isWallCraftableBlock(.cobblestone));
    try std.testing.expect(FenceAndGateRecipes.isWallCraftableBlock(.sandstone));
    try std.testing.expect(FenceAndGateRecipes.isWallCraftableBlock(.brick));
    try std.testing.expect(FenceAndGateRecipes.isWallCraftableBlock(.nether_brick));
    try std.testing.expect(FenceAndGateRecipes.isWallCraftableBlock(.deepslate));
    try std.testing.expect(!FenceAndGateRecipes.isWallCraftableBlock(.dirt));
    try std.testing.expect(!FenceAndGateRecipes.isWallCraftableBlock(.glass));
}

test "4. FenceAndGateRecipes: nether brick fence crafting (modern 4+2 and legacy 6)" {
    // Modern: 4 blocks + 2 items -> 3 fences
    try std.testing.expectEqual(@as(u16, 3), craftNetherBrickFences(4, 2));
    try std.testing.expectEqual(@as(u16, 6), craftNetherBrickFences(8, 4));
    try std.testing.expectEqual(@as(u16, 0), craftNetherBrickFences(3, 2));
    try std.testing.expectEqual(@as(u16, 0), craftNetherBrickFences(4, 1));

    // Legacy: 6 blocks -> 6 fences
    try std.testing.expectEqual(@as(u16, 6), FenceAndGateRecipes.craftNetherBrickFencesLegacy(6));
    try std.testing.expectEqual(@as(u16, 12), FenceAndGateRecipes.craftNetherBrickFencesLegacy(12));
    try std.testing.expectEqual(@as(u16, 0), FenceAndGateRecipes.craftNetherBrickFencesLegacy(5));
}

test "5. CollisionHeightRule: visual height 1.0 vs physical collision height 1.5" {
    // Fences and walls have visual height 1.0
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), visual_height, 0.0001);

    // Fences and walls have physical collision height 1.5
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), collision_height, 0.0001);

    // Default hurdle without carpet is 1.5
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), getEffectiveHurdleHeight(false), 0.0001);

    // Hurdle with carpet is 1.0625
    try std.testing.expectApproxEqAbs(@as(f32, 1.0625), getEffectiveHurdleHeight(true), 0.0001);
}

test "6. CollisionHeightRule: standard player jump (1.252) blocked without carpet" {
    const player_jump: f32 = CollisionHeightRule.player_standard_jump_height;
    try std.testing.expectApproxEqAbs(@as(f32, 1.252), player_jump, 0.0001);

    // Player jump 1.252 < 1.5 collision height -> cannot jump over!
    try std.testing.expect(!canEntityJumpOverFence(player_jump, false));
    try std.testing.expect(!CollisionHeightRule.canEntityClearFence(player_jump, 0.6, false));
}

test "7. CollisionHeightRule: carpet on top lowers hurdle to 1.0625, allowing player jump" {
    const player_jump: f32 = CollisionHeightRule.player_standard_jump_height;

    // With carpet: hurdle is 1.0625, player jump 1.252 >= 1.0625 -> can jump over!
    try std.testing.expect(canEntityJumpOverFence(player_jump, true));
    try std.testing.expect(CollisionHeightRule.canEntityClearFence(player_jump, 0.6, true));
}

test "8. CollisionHeightRule: high-jump entities clear 1.5 fence without carpet" {
    // Jump Boost I (1.95 blocks)
    try std.testing.expect(canEntityJumpOverFence(CollisionHeightRule.jump_boost_1_jump_height, false));

    // Jump Boost II (2.50 blocks)
    try std.testing.expect(canEntityJumpOverFence(CollisionHeightRule.jump_boost_2_jump_height, false));

    // Horse min jump (1.50 blocks) and max jump (5.25 blocks)
    try std.testing.expect(canEntityJumpOverFence(CollisionHeightRule.horse_min_jump_height, false));
    try std.testing.expect(canEntityJumpOverFence(CollisionHeightRule.horse_max_jump_height, false));

    // Camel step clearance reach (1.50 blocks)
    try std.testing.expect(canEntityJumpOverFence(CollisionHeightRule.camel_step_reach, false));
    try std.testing.expect(CollisionHeightRule.canEntityClearFence(1.0, CollisionHeightRule.camel_step_reach, false));

    // Mountain Goat (5.0 blocks)
    try std.testing.expect(canEntityJumpOverFence(CollisionHeightRule.goat_jump_height, false));

    // Rabbit (1.25 blocks < 1.5 hurdle) -> cannot clear fence without carpet
    try std.testing.expect(!canEntityJumpOverFence(CollisionHeightRule.rabbit_jump_height, false));
    // Rabbit (1.25 >= 1.0625) -> can clear fence with carpet!
    try std.testing.expect(canEntityJumpOverFence(CollisionHeightRule.rabbit_jump_height, true));
}

test "9. CollisionHeightRule: livestock (cow, sheep, pig) remain penned" {
    const livestock_jump = CollisionHeightRule.livestock_jump_height; // 1.0
    const livestock_step: f32 = 0.6;

    // Livestock cannot jump over fence (1.0 < 1.5)
    try std.testing.expect(!canEntityJumpOverFence(livestock_jump, false));
    try std.testing.expect(!CollisionHeightRule.canEntityClearFence(livestock_jump, livestock_step, false));

    // Even with carpet on top, standard 1.0 jump reach is below 1.0625 carpet hurdle!
    try std.testing.expect(!canEntityJumpOverFence(livestock_jump, true));
}

test "10. CollisionHeightRule: fence gate collision box disabled when open and 1.5 when closed" {
    // Closed fence gate has 1.5 collision box
    const closed_box = getBarrierCollisionBox(.fence_gate, 10, 64, 10, false, false);
    try std.testing.expect(closed_box != null);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), closed_box.?.height(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), closed_box.?.min_y, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 65.5), closed_box.?.max_y, 0.0001);

    // Open fence gate has NO collision box (players and mobs walk right through)
    const open_box = getBarrierCollisionBox(.fence_gate, 10, 64, 10, true, false);
    try std.testing.expect(open_box == null);

    // Closed gate with carpet on top has 1.0625 collision box
    const carpet_box = getBarrierCollisionBox(.fence_gate, 10, 64, 10, false, true);
    try std.testing.expect(carpet_box != null);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0625), carpet_box.?.height(), 0.0001);
}

test "11. FenceConnectionRule: wooden fences connect to wooden fences and fence gates" {
    // Wooden to wooden: always connects
    try std.testing.expect(doFencesConnect(false, false));

    // Wooden fence connects to fence gate
    try std.testing.expect(doesFenceConnectToGate(false));
}

test "12. FenceConnectionRule: nether brick fences connect to nether brick fences and fence gates" {
    // Nether brick to nether brick: always connects
    try std.testing.expect(doFencesConnect(true, true));

    // Nether brick fence connects to fence gate
    try std.testing.expect(doesFenceConnectToGate(true));
}

test "13. FenceConnectionRule: wooden fence NEVER connects to nether brick fence" {
    // Wooden fence to nether brick fence: NEVER connects!
    try std.testing.expect(!doFencesConnect(false, true));

    // Nether brick fence to wooden fence: NEVER connects!
    try std.testing.expect(!doFencesConnect(true, false));
}

test "14. FenceConnectionRule: 0.75-block gap allows player (0.6) but blocks mobs (>= 0.8)" {
    // Exact post gap width is 0.75 blocks (12 pixels)
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), FenceConnectionRule.fence_gap_width, 0.0001);

    // Player width 0.6 fits through
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), player_width, 0.0001);
    try std.testing.expect(canEntitySqueezeThroughFenceGap(player_width));
    try std.testing.expect(!isMobBlockedByFenceGap(player_width));

    // Zombie / Skeleton (width 0.6) can squeeze through
    try std.testing.expect(canEntitySqueezeThroughFenceGap(0.6));

    // Livestock and wider mobs (width >= 0.8) are blocked:
    // Cow (width 0.9)
    try std.testing.expect(!canEntitySqueezeThroughFenceGap(0.9));
    try std.testing.expect(isMobBlockedByFenceGap(0.9));

    // Sheep (width 0.9)
    try std.testing.expect(!canEntitySqueezeThroughFenceGap(0.9));
    try std.testing.expect(isMobBlockedByFenceGap(0.9));

    // Pig (width 0.9)
    try std.testing.expect(!canEntitySqueezeThroughFenceGap(0.9));
    try std.testing.expect(isMobBlockedByFenceGap(0.9));

    // Horse (width 1.396)
    try std.testing.expect(!canEntitySqueezeThroughFenceGap(1.396));
    try std.testing.expect(isMobBlockedByFenceGap(1.396));

    // Spider (width 1.4)
    try std.testing.expect(!canEntitySqueezeThroughFenceGap(1.4));
    try std.testing.expect(isMobBlockedByFenceGap(1.4));

    // Hoglin (width 1.4)
    try std.testing.expect(!canEntitySqueezeThroughFenceGap(1.4));
    try std.testing.expect(isMobBlockedByFenceGap(1.4));
}

test "15. WallPillarPostRule: straight 2+ wall line forms smooth flush wall without center post" {
    // North-South straight wall: no center pillar post
    const straight_ns = WallConnections{ .north = true, .south = true, .east = false, .west = false };
    try std.testing.expect(straight_ns.isStraightLine());
    try std.testing.expect(!hasCenterPillarPost(straight_ns, false));

    // East-West straight wall: no center pillar post
    const straight_ew = WallConnections{ .north = false, .south = false, .east = true, .west = true };
    try std.testing.expect(straight_ew.isStraightLine());
    try std.testing.expect(!hasCenterPillarPost(straight_ew, false));
}

test "16. WallPillarPostRule: end-caps, corners, T-junctions, and cross-junctions raise center post" {
    // Isolated post (0 connections)
    const isolated = WallConnections{};
    try std.testing.expect(isolated.isIsolated());
    try std.testing.expect(hasCenterPillarPost(isolated, false));

    // End-cap (1 connection)
    const endcap_n = WallConnections{ .north = true };
    try std.testing.expect(endcap_n.isEndCap());
    try std.testing.expect(hasCenterPillarPost(endcap_n, false));

    const endcap_e = WallConnections{ .east = true };
    try std.testing.expect(endcap_e.isEndCap());
    try std.testing.expect(hasCenterPillarPost(endcap_e, false));

    // Corner (2 perpendicular connections)
    const corner_ne = WallConnections{ .north = true, .east = true };
    try std.testing.expect(corner_ne.isCorner());
    try std.testing.expect(!corner_ne.isStraightLine());
    try std.testing.expect(hasCenterPillarPost(corner_ne, false));

    const corner_sw = WallConnections{ .south = true, .west = true };
    try std.testing.expect(corner_sw.isCorner());
    try std.testing.expect(hasCenterPillarPost(corner_sw, false));

    // T-junction (3 connections)
    const tjunction = WallConnections{ .north = true, .south = true, .east = true, .west = false };
    try std.testing.expect(tjunction.isTJunction());
    try std.testing.expect(hasCenterPillarPost(tjunction, false));

    // Cross-junction (4 connections)
    const cross = WallConnections{ .north = true, .south = true, .east = true, .west = true };
    try std.testing.expect(cross.isCrossJunction());
    try std.testing.expect(hasCenterPillarPost(cross, false));
}

test "17. WallPillarPostRule: block/torch/lantern above straight wall raises post and triggers Observer" {
    const straight_ns = WallConnections{ .north = true, .south = true, .east = false, .west = false };

    // Initially straight wall has no center pillar post
    const initial_post = hasCenterPillarPost(straight_ns, false);
    try std.testing.expect(!initial_post);

    // Placing a block or torch on top raises the center pillar post!
    const updated_post = hasCenterPillarPost(straight_ns, true);
    try std.testing.expect(updated_post);

    // Observer detects this vertical block state change and emits a pulse!
    const observer_result = evaluateObserver(initial_post, updated_post);
    try std.testing.expect(observer_result.state_changed);
    try std.testing.expect(observer_result.observer_triggered);

    // Removing the block triggers the Observer again (state flips from true to false)
    const observer_removal = evaluateObserver(updated_post, initial_post);
    try std.testing.expect(observer_removal.state_changed);
    try std.testing.expect(observer_removal.observer_triggered);

    // No change in state produces no Observer pulse
    const observer_no_change = evaluateObserver(updated_post, updated_post);
    try std.testing.expect(!observer_no_change.state_changed);
    try std.testing.expect(!observer_no_change.observer_triggered);

    // Blocks above verification
    try std.testing.expect(WallPillarPostRule.doesBlockAboveRaisePost(.torch));
    try std.testing.expect(WallPillarPostRule.doesBlockAboveRaisePost(.soul_torch));
    try std.testing.expect(WallPillarPostRule.doesBlockAboveRaisePost(.lantern));
    try std.testing.expect(WallPillarPostRule.doesBlockAboveRaisePost(.stone));
    try std.testing.expect(!WallPillarPostRule.doesBlockAboveRaisePost(.air));
}

test "18. FenceGateWallAlignment: fence gate between stone walls lowers model by 3 pixels (0.1875 blocks)" {
    // Distance lowered is exactly 3 pixels / 0.1875 blocks
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), FenceGateWallAlignment.lowering_pixels, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1875), FenceGateWallAlignment.lowering_offset, 0.0001);

    // isLoweredBetweenWalls returns true when connected to wall
    try std.testing.expect(isLoweredBetweenWalls(true));
    try std.testing.expect(!isLoweredBetweenWalls(false));

    // Lowered Y offset is -0.1875
    try std.testing.expectApproxEqAbs(@as(f32, -0.1875), getGateYOffset(true), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getGateYOffset(false), 0.0001);

    // Lowered top Y is 0.8125 blocks (13/16), aligning flush with stone wall side bars
    try std.testing.expectApproxEqAbs(@as(f32, 0.8125), getGateTopY(true), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getGateTopY(false), 0.0001);

    // Lowered top Y matches stone wall side bar height exactly
    try std.testing.expectApproxEqAbs(FenceGateWallAlignment.wall_side_bar_height, getGateTopY(true), 0.0001);

    // Neighbor connectivity helper
    try std.testing.expect(FenceGateWallAlignment.isLoweredFromNeighbors(true, false));
    try std.testing.expect(FenceGateWallAlignment.isLoweredFromNeighbors(false, true));
    try std.testing.expect(FenceGateWallAlignment.isLoweredFromNeighbors(true, true));
    try std.testing.expect(!FenceGateWallAlignment.isLoweredFromNeighbors(false, false));
}
