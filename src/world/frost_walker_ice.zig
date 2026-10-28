const std = @import("std");
const block_mod = @import("block.zig");
pub const BlockId = block_mod.BlockId;

/// Milestone 433: Frost Walker Ice Crystallization & Melting
///
/// Implements the full Minecraft-style Frost Walker enchantment mechanics:
/// 1. Freeze radius calculation around the player:
///    - Formula: radius = @as(u8, 2 + level) (Level 1: 3 blocks, Level 2: 4 blocks).
///    - Affects still water source blocks with air directly above.
///    - Flowing water is unaffected.
/// 2. Frosted ice 4-stage melting lifecycle:
///    - Blocks track `age` from 0 to 3 (stages 0, 1, 2, 3).
///    - When block light level > 11, frosted ice ticks and ages.
///    - At age >= 4, block melts back to still water source (`.water`).
///    - In darkness or at night (block light level <= 11), frosted ice is stable and never melts.
/// 3. Heat & contact hazard immunity:
///    - Wearing boots enchanted with Frost Walker negates all magma block contact
///      damage and campfire burn damage (regular and soul campfire).

// ============================================================================
// 1. Frost Walker Freeze Radius & Geometry Constants
// ============================================================================

/// Maximum standard enchantment level for Frost Walker.
pub const MAX_FROST_WALKER_LEVEL: u8 = 2;

/// Freeze radius for Frost Walker I: 2 + 1 = 3 blocks.
pub const FROST_WALKER_I_RADIUS: u8 = 3;

/// Freeze radius for Frost Walker II: 2 + 2 = 4 blocks.
pub const FROST_WALKER_II_RADIUS: u8 = 4;

/// Returns the freeze radius around a player on water:
/// `radius = @as(u8, 2 + level)` (Level 1: 3 blocks, Level 2: 4 blocks).
/// Returns 0 if level == 0 (no Frost Walker enchantment).
pub fn freezeRadius(level: u8) u8 {
    if (level == 0) return 0;
    return @as(u8, 2 + level);
}

/// Convenience alias for `freezeRadius`.
pub fn getFreezeRadius(level: u8) u8 {
    return freezeRadius(level);
}

/// Checks if an offset `(dx, dz)` lies within the horizontal circular freeze radius.
/// Uses Euclidean distance squared: `dx^2 + dz^2 <= radius^2`.
pub fn isWithinFreezeRadius(dx: i32, dz: i32, level: u8) bool {
    const r = freezeRadius(level);
    if (r == 0) return false;
    const r_i32 = @as(i32, r);
    return (dx * dx + dz * dz) <= (r_i32 * r_i32);
}

/// Checks if an offset `(dx, dz)` lies within Chebyshev distance (square boundary).
pub fn isWithinChebyshevRadius(dx: i32, dz: i32, level: u8) bool {
    const r = freezeRadius(level);
    if (r == 0) return false;
    const r_i32 = @as(i32, r);
    return @max(@abs(dx), @abs(dz)) <= r_i32;
}

/// Checks if an offset `(dx, dz)` lies within Manhattan taxicab distance.
pub fn isWithinManhattanRadius(dx: i32, dz: i32, level: u8) bool {
    const r = freezeRadius(level);
    if (r == 0) return false;
    const dist = @as(u32, @intCast(@abs(dx))) + @as(u32, @intCast(@abs(dz)));
    return dist <= @as(u32, r);
}

// ============================================================================
// 2. Water Crystallization Eligibility
// ============================================================================

/// Flow status of a water block.
pub const WaterFlowState = enum {
    still_source,
    flowing,
};

/// Evaluates if water is eligible for Frost Walker crystallization:
/// - Must be a still water source block (flowing water is unaffected).
/// - Must have air directly above (y + 1).
pub fn canCrystallizeWater(is_still_source: bool, above_is_air: bool) bool {
    return is_still_source and above_is_air;
}

/// Evaluates water eligibility using the `WaterFlowState` enum and the above block ID.
pub fn canFreezeWaterState(water_state: WaterFlowState, above_block: BlockId) bool {
    return water_state == .still_source and above_block == .air;
}

/// Complete block-level check verifying that the target block is water,
/// is a stationary source block, and has air directly above.
pub fn isWaterEligibleForFreezing(block: BlockId, is_source: bool, block_above: BlockId) bool {
    return block == .water and is_source and block_above == .air;
}

// ============================================================================
// 3. Frosted Ice 4-Stage Melting Lifecycle
// ============================================================================

/// The light level threshold for frosted ice stability.
/// In darkness or at night (light level <= 11), frosted ice is stable and never melts.
pub const MELT_LIGHT_THRESHOLD: u8 = 11;

/// Maximum age stage of intact frosted ice (ages 0 to 3).
pub const MAX_FROSTED_ICE_AGE: u8 = 3;

/// The age threshold at which frosted ice melts back into still water source (age >= 4).
pub const MELT_THRESHOLD_AGE: u8 = 4;

/// Total number of distinct solid stages in the frosted ice lifecycle (0, 1, 2, 3).
pub const LIFECYCLE_STAGES_COUNT: u8 = 4;

/// Frosted ice lifecycle stages:
/// - stage_0: Age 0 - Freshly crystallized ice, pristine.
/// - stage_1: Age 1 - Initial fine hairline surface cracks.
/// - stage_2: Age 2 - Pronounced fracture fissures.
/// - stage_3: Age 3 - Severe structural cracking, about to shatter.
/// - melted:  Age 4+ - Phase-changed back to still water source.
pub const FrostedIceStage = enum(u8) {
    stage_0 = 0,
    stage_1 = 1,
    stage_2 = 2,
    stage_3 = 3,
    melted = 4,

    pub fn isMelted(self: FrostedIceStage) bool {
        return self == .melted;
    }

    /// Normalized visual cracking factor from 0.0 (pristine) to 1.0 (maximum crack).
    pub fn crackFactor(self: FrostedIceStage) f32 {
        return switch (self) {
            .stage_0 => 0.0,
            .stage_1 => 0.33333334,
            .stage_2 => 0.6666667,
            .stage_3 => 1.0,
            .melted => 0.0,
        };
    }
};

/// Returns whether frosted ice will tick and age at the given block light level.
/// When block light level > 11, frosted ice ticks and ages.
pub fn willFrostedIceAge(block_light_level: u8) bool {
    return block_light_level > MELT_LIGHT_THRESHOLD;
}

/// Returns whether frosted ice is stable and will not melt.
/// In darkness or at night (block light level <= 11), frosted ice is stable and never melts.
pub fn isFrostedIceStable(block_light_level: u8) bool {
    return block_light_level <= MELT_LIGHT_THRESHOLD;
}

/// Outcome of a single frosted ice lifecycle tick.
pub const FrostedIceTickOutcome = struct {
    next_age: u8,
    melted: bool,
    resulting_block: BlockId,
    stage: FrostedIceStage,
};

/// Evaluates a single tick transition for frosted ice given current age and block light level:
/// - If current_age is already >= 4, it remains melted water.
/// - If light > 11: ages by 1. At age >= 4, melts back to still water source (`.water`).
/// - If light <= 11: stable, age does not change.
pub fn tickFrostedIceLifecycle(current_age: u8, block_light_level: u8) FrostedIceTickOutcome {
    if (current_age >= MELT_THRESHOLD_AGE) {
        return .{
            .next_age = current_age,
            .melted = true,
            .resulting_block = .water,
            .stage = .melted,
        };
    }

    if (willFrostedIceAge(block_light_level)) {
        const next_age = current_age + 1;
        const melted = next_age >= MELT_THRESHOLD_AGE;
        return .{
            .next_age = next_age,
            .melted = melted,
            .resulting_block = if (melted) .water else .ice,
            .stage = if (melted) .melted else @enumFromInt(next_age),
        };
    } else {
        return .{
            .next_age = current_age,
            .melted = false,
            .resulting_block = .ice,
            .stage = @enumFromInt(current_age),
        };
    }
}

/// Represents an individual frosted ice block in the voxel world.
pub const FrostedIceBlock = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    age: u8 = 0,

    pub fn init(x: i32, y: i32, z: i32) FrostedIceBlock {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .age = 0,
        };
    }

    pub fn initWithAge(x: i32, y: i32, z: i32, initial_age: u8) FrostedIceBlock {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .age = initial_age,
        };
    }

    pub fn getStage(self: FrostedIceBlock) FrostedIceStage {
        if (self.age >= MELT_THRESHOLD_AGE) return .melted;
        return @enumFromInt(self.age);
    }

    pub fn isMelted(self: FrostedIceBlock) bool {
        return self.age >= MELT_THRESHOLD_AGE;
    }

    /// Ticks this frosted ice block with the specified block light level.
    /// If block light level > 11, age increments.
    /// Returns true if this tick caused the block to melt (or it was already melted).
    pub fn tick(self: *FrostedIceBlock, block_light_level: u8) bool {
        if (self.isMelted()) return true;
        if (willFrostedIceAge(block_light_level)) {
            self.age += 1;
            return self.isMelted();
        }
        return false;
    }

    /// Returns the current active block ID: `.ice` while intact (ages 0..3),
    /// or `.water` when melted (age >= 4).
    pub fn currentBlockId(self: FrostedIceBlock) BlockId {
        return if (self.isMelted()) .water else .ice;
    }
};

// ============================================================================
// 4. Heat & Contact Hazard Immunity
// ============================================================================

/// Contact damage rate for magma block (1.0 HP / s).
pub const MAGMA_CONTACT_DAMAGE_RATE: f32 = 1.0;

/// Burn damage rate for campfires (2.0 HP / s).
pub const CAMPFIRE_BURN_DAMAGE_RATE: f32 = 2.0;

/// Burn damage rate for soul campfires (2.0 HP / s).
pub const SOUL_CAMPFIRE_BURN_DAMAGE_RATE: f32 = 2.0;

/// Severe burn damage rate for lava contact (8.0 HP / s).
pub const LAVA_BURN_DAMAGE_RATE: f32 = 8.0;

/// Item type ID for Frost Walker boots from the item registry.
pub const FROST_WALKER_BOOTS_ITEM_ID: u16 = 469;

/// Identifies whether a hazard block's damage is negated by the Frost Walker enchantment.
/// Wearing boots enchanted with Frost Walker negates all magma block contact damage
/// and campfire burn damage (regular and soul campfire).
pub fn isHazardNegatedByFrostWalker(block: BlockId) bool {
    return block == .magma or block == .campfire or block == .soul_campfire;
}

/// Checks whether a player with the given Frost Walker enchantment level is immune
/// to the contact/burn damage of the specified block.
pub fn isPlayerImmuneToHazard(block: BlockId, frost_walker_level: u8) bool {
    return frost_walker_level > 0 and isHazardNegatedByFrostWalker(block);
}

/// Calculates hazard damage over duration `dt`, taking Frost Walker immunity into account.
/// Frost Walker negates magma contact and campfire burn damage, but DOES NOT protect
/// against lava or other non-floor hazards.
pub fn calculateHazardDamage(block: BlockId, frost_walker_level: u8, dt: f32) f32 {
    if (isPlayerImmuneToHazard(block, frost_walker_level)) {
        return 0.0;
    }
    return switch (block) {
        .magma => MAGMA_CONTACT_DAMAGE_RATE * dt,
        .campfire => CAMPFIRE_BURN_DAMAGE_RATE * dt,
        .soul_campfire => SOUL_CAMPFIRE_BURN_DAMAGE_RATE * dt,
        .lava => LAVA_BURN_DAMAGE_RATE * dt,
        else => 0.0,
    };
}

/// Applies contact hazard damage to a player's current health, clamped at 0.0 HP.
pub fn applyHazardContactDamage(current_health: f32, block: BlockId, frost_walker_level: u8, dt: f32) f32 {
    const damage = calculateHazardDamage(block, frost_walker_level, dt);
    return @max(0.0, current_health - damage);
}

/// Helper model for equipped boots.
pub const BootsEquipment = struct {
    frost_walker_level: u8 = 0,
    is_equipped: bool = true,

    pub fn hasFrostWalker(self: BootsEquipment) bool {
        return self.is_equipped and self.frost_walker_level > 0;
    }
};

/// Evaluates player contact damage using equipped boots.
pub fn evaluateBootsContactDamage(current_health: f32, block: BlockId, boots: BootsEquipment, dt: f32) f32 {
    const level = if (boots.is_equipped) boots.frost_walker_level else 0;
    return applyHazardContactDamage(current_health, block, level, dt);
}

// ============================================================================
// 5. Crystallization Tracker & Grid Simulation
// ============================================================================

/// Fixed-capacity tracker for localized frosted ice blocks.
pub const FrostedIceTracker = struct {
    pub const MAX_BLOCKS: usize = 128;

    blocks: [MAX_BLOCKS]FrostedIceBlock = undefined,
    count: usize = 0,

    pub fn init() FrostedIceTracker {
        return .{ .count = 0 };
    }

    pub fn add(self: *FrostedIceTracker, block: FrostedIceBlock) bool {
        if (self.count >= MAX_BLOCKS) return false;
        self.blocks[self.count] = block;
        self.count += 1;
        return true;
    }

    pub fn findBlock(self: *FrostedIceTracker, x: i32, y: i32, z: i32) ?*FrostedIceBlock {
        for (self.blocks[0..self.count]) |*b| {
            if (b.x == x and b.y == y and b.z == z) return b;
        }
        return null;
    }

    /// Ticks all active frosted ice blocks. Returns the number of blocks that melted to water during this tick.
    pub fn tickAll(self: *FrostedIceTracker, block_light_level: u8) usize {
        var melted_count: usize = 0;
        for (self.blocks[0..self.count]) |*b| {
            if (!b.isMelted()) {
                const just_melted = b.tick(block_light_level);
                if (just_melted) melted_count += 1;
            }
        }
        return melted_count;
    }

    /// Counts how many blocks are currently at a given stage.
    pub fn countInStage(self: FrostedIceTracker, stage: FrostedIceStage) usize {
        var n: usize = 0;
        for (self.blocks[0..self.count]) |b| {
            if (b.getStage() == stage) n += 1;
        }
        return n;
    }

    /// Returns the number of blocks that have not yet melted to water.
    pub fn activeUnmeltedCount(self: FrostedIceTracker) usize {
        var n: usize = 0;
        for (self.blocks[0..self.count]) |b| {
            if (!b.isMelted()) n += 1;
        }
        return n;
    }
};

/// Crystallizes still water source blocks on surface `water_y` around player `(px, pz)` within the level's radius.
/// Uses callback functions to inspect the world environment.
pub fn crystallizeWaterPond(
    tracker: *FrostedIceTracker,
    px: i32,
    water_y: i32,
    pz: i32,
    level: u8,
    is_source_fn: *const fn (x: i32, y: i32, z: i32) bool,
    block_at_fn: *const fn (x: i32, y: i32, z: i32) BlockId,
) usize {
    const r = freezeRadius(level);
    if (r == 0) return 0;
    const r_i32 = @as(i32, r);

    var created: usize = 0;
    var dx = -r_i32;
    while (dx <= r_i32) : (dx += 1) {
        var dz = -r_i32;
        while (dz <= r_i32) : (dz += 1) {
            if (!isWithinFreezeRadius(dx, dz, level)) continue;

            const wx = px + dx;
            const wz = pz + dz;

            const block = block_at_fn(wx, water_y, wz);
            const above = block_at_fn(wx, water_y + 1, wz);
            const is_source = is_source_fn(wx, water_y, wz);

            if (isWaterEligibleForFreezing(block, is_source, above)) {
                if (tracker.findBlock(wx, water_y, wz) == null) {
                    if (tracker.add(FrostedIceBlock.init(wx, water_y, wz))) {
                        created += 1;
                    }
                }
            }
        }
    }
    return created;
}

// ============================================================================
// 6. Comprehensive Unit Test Suite (22 Tests)
// ============================================================================

test "1. freezeRadius: Level 1 calculates radius of 3 blocks" {
    try std.testing.expectEqual(@as(u8, 3), freezeRadius(1));
    try std.testing.expectEqual(@as(u8, 3), getFreezeRadius(1));
    try std.testing.expectEqual(@as(u8, 3), FROST_WALKER_I_RADIUS);
}

test "2. freezeRadius: Level 2 calculates radius of 4 blocks" {
    try std.testing.expectEqual(@as(u8, 4), freezeRadius(2));
    try std.testing.expectEqual(@as(u8, 4), getFreezeRadius(2));
    try std.testing.expectEqual(@as(u8, 4), FROST_WALKER_II_RADIUS);
}

test "3. freezeRadius: Level 0 returns 0 radius (no enchantment active)" {
    try std.testing.expectEqual(@as(u8, 0), freezeRadius(0));
    try std.testing.expectEqual(@as(u8, 0), getFreezeRadius(0));
}

test "4. freezeRadius: obeys 2 + level scaling for all levels" {
    var lvl: u8 = 1;
    while (lvl <= 10) : (lvl += 1) {
        try std.testing.expectEqual(@as(u8, 2 + lvl), freezeRadius(lvl));
    }
}

test "5. isWithinFreezeRadius: Euclidean circular boundary checks for Level 1" {
    // Level 1 radius = 3.
    // Center:
    try std.testing.expect(isWithinFreezeRadius(0, 0, 1));
    // Cardinal axes at distance 3:
    try std.testing.expect(isWithinFreezeRadius(3, 0, 1));
    try std.testing.expect(isWithinFreezeRadius(-3, 0, 1));
    try std.testing.expect(isWithinFreezeRadius(0, 3, 1));
    try std.testing.expect(isWithinFreezeRadius(0, -3, 1));
    // Diagonals: (2, 2) has dist^2 = 8 <= 9 -> inside
    try std.testing.expect(isWithinFreezeRadius(2, 2, 1));
    try std.testing.expect(isWithinFreezeRadius(-2, 2, 1));
    // Outside: (3, 1) has dist^2 = 10 > 9 -> outside
    try std.testing.expect(!isWithinFreezeRadius(3, 1, 1));
    try std.testing.expect(!isWithinFreezeRadius(1, 3, 1));
    // Outside cardinal distance 4:
    try std.testing.expect(!isWithinFreezeRadius(4, 0, 1));
}

test "6. isWithinFreezeRadius: Euclidean circular boundary checks for Level 2" {
    // Level 2 radius = 4.
    // Cardinal axes at distance 4:
    try std.testing.expect(isWithinFreezeRadius(4, 0, 2));
    try std.testing.expect(isWithinFreezeRadius(-4, 0, 2));
    try std.testing.expect(isWithinFreezeRadius(0, 4, 2));
    try std.testing.expect(isWithinFreezeRadius(0, -4, 2));
    // Inside points: (2, 3) has dist^2 = 13 <= 16 -> inside
    try std.testing.expect(isWithinFreezeRadius(2, 3, 2));
    try std.testing.expect(isWithinFreezeRadius(3, 2, 2));
    // Outside points: (3, 3) has dist^2 = 18 > 16 -> outside
    try std.testing.expect(!isWithinFreezeRadius(3, 3, 2));
    // Outside points: (4, 1) has dist^2 = 17 > 16 -> outside
    try std.testing.expect(!isWithinFreezeRadius(4, 1, 2));
    try std.testing.expect(!isWithinFreezeRadius(5, 0, 2));
}

test "7. water eligibility: still water source with air directly above is eligible" {
    try std.testing.expect(isWaterEligibleForFreezing(.water, true, .air));
    try std.testing.expect(canCrystallizeWater(true, true));
    try std.testing.expect(canFreezeWaterState(.still_source, .air));
}

test "8. water eligibility: flowing water is unaffected and never freezes" {
    // Flowing water (is_source == false) must not crystallize even if air is above
    try std.testing.expect(!isWaterEligibleForFreezing(.water, false, .air));
    try std.testing.expect(!canCrystallizeWater(false, true));
    try std.testing.expect(!canFreezeWaterState(.flowing, .air));
}

test "9. water eligibility: still water without air directly above is not eligible" {
    // Water under solid blocks, under water, or under transparent non-air blocks cannot freeze
    try std.testing.expect(!isWaterEligibleForFreezing(.water, true, .stone));
    try std.testing.expect(!isWaterEligibleForFreezing(.water, true, .water));
    try std.testing.expect(!isWaterEligibleForFreezing(.water, true, .dirt));
    try std.testing.expect(!isWaterEligibleForFreezing(.water, true, .leaves));
    try std.testing.expect(!canCrystallizeWater(true, false));
    try std.testing.expect(!canFreezeWaterState(.still_source, .stone));
}

test "10. water eligibility: non-water blocks are never eligible" {
    try std.testing.expect(!isWaterEligibleForFreezing(.lava, true, .air));
    try std.testing.expect(!isWaterEligibleForFreezing(.stone, true, .air));
    try std.testing.expect(!isWaterEligibleForFreezing(.air, true, .air));
    try std.testing.expect(!isWaterEligibleForFreezing(.magma, true, .air));
}

test "11. frosted ice initial state: starts at age 0 in stage_0" {
    const block = FrostedIceBlock.init(10, 64, 20);
    try std.testing.expectEqual(@as(i32, 10), block.x);
    try std.testing.expectEqual(@as(i32, 64), block.y);
    try std.testing.expectEqual(@as(i32, 20), block.z);
    try std.testing.expectEqual(@as(u8, 0), block.age);
    try std.testing.expectEqual(FrostedIceStage.stage_0, block.getStage());
    try std.testing.expectEqual(@as(f32, 0.0), block.getStage().crackFactor());
    try std.testing.expect(!block.isMelted());
    try std.testing.expectEqual(BlockId.ice, block.currentBlockId());
}

test "12. light stability: light <= 11 is stable and frosted ice never melts" {
    var light: u8 = 0;
    while (light <= 11) : (light += 1) {
        try std.testing.expect(isFrostedIceStable(light));
        try std.testing.expect(!willFrostedIceAge(light));

        var block = FrostedIceBlock.init(0, 0, 0);
        const melted = block.tick(light);
        try std.testing.expect(!melted);
        try std.testing.expectEqual(@as(u8, 0), block.age);
        try std.testing.expect(!block.isMelted());
    }
}

test "13. light stability boundary: light 11 is stable vs light 12 triggers aging" {
    try std.testing.expect(isFrostedIceStable(11));
    try std.testing.expect(!willFrostedIceAge(11));

    try std.testing.expect(!isFrostedIceStable(12));
    try std.testing.expect(willFrostedIceAge(12));
}

test "14. 4-stage melting lifecycle: progression through ages 0, 1, 2, 3" {
    var block = FrostedIceBlock.init(5, 60, 5);

    // Initial: Age 0, stage 0
    try std.testing.expectEqual(@as(u8, 0), block.age);
    try std.testing.expectEqual(FrostedIceStage.stage_0, block.getStage());

    // Tick 1 at light 15 (bright daylight): Age -> 1
    const melted_1 = block.tick(15);
    try std.testing.expect(!melted_1);
    try std.testing.expectEqual(@as(u8, 1), block.age);
    try std.testing.expectEqual(FrostedIceStage.stage_1, block.getStage());
    try std.testing.expectEqual(BlockId.ice, block.currentBlockId());

    // Tick 2 at light 14: Age -> 2
    const melted_2 = block.tick(14);
    try std.testing.expect(!melted_2);
    try std.testing.expectEqual(@as(u8, 2), block.age);
    try std.testing.expectEqual(FrostedIceStage.stage_2, block.getStage());

    // Tick 3 at light 13: Age -> 3
    const melted_3 = block.tick(13);
    try std.testing.expect(!melted_3);
    try std.testing.expectEqual(@as(u8, 3), block.age);
    try std.testing.expectEqual(FrostedIceStage.stage_3, block.getStage());
    try std.testing.expect(!block.isMelted());
}

test "15. 4-stage melting lifecycle: melts back to still water source at age >= 4" {
    var block = FrostedIceBlock.initWithAge(5, 60, 5, 3);
    try std.testing.expectEqual(@as(u8, 3), block.age);
    try std.testing.expectEqual(FrostedIceStage.stage_3, block.getStage());

    // Tick 4 at light 12 (> 11): Age -> 4, triggers melt!
    const melted_4 = block.tick(12);
    try std.testing.expect(melted_4);
    try std.testing.expect(block.isMelted());
    try std.testing.expectEqual(@as(u8, 4), block.age);
    try std.testing.expectEqual(FrostedIceStage.melted, block.getStage());
    try std.testing.expectEqual(BlockId.water, block.currentBlockId());
}

test "16. frosted ice already melted remains still water source on subsequent ticks" {
    var block = FrostedIceBlock.initWithAge(0, 0, 0, 4);
    try std.testing.expect(block.isMelted());
    try std.testing.expectEqual(BlockId.water, block.currentBlockId());

    // Further ticks in light or dark remain melted
    try std.testing.expect(block.tick(15));
    try std.testing.expect(block.tick(0));
    try std.testing.expectEqual(BlockId.water, block.currentBlockId());
}

test "17. tickFrostedIceLifecycle functional evaluation handles all stages and thresholds" {
    // Night/darkness (light 10): no change
    const res_night = tickFrostedIceLifecycle(0, 10);
    try std.testing.expectEqual(@as(u8, 0), res_night.next_age);
    try std.testing.expect(!res_night.melted);
    try std.testing.expectEqual(BlockId.ice, res_night.resulting_block);
    try std.testing.expectEqual(FrostedIceStage.stage_0, res_night.stage);

    // Aging from stage 2 to stage 3
    const res_age3 = tickFrostedIceLifecycle(2, 14);
    try std.testing.expectEqual(@as(u8, 3), res_age3.next_age);
    try std.testing.expect(!res_age3.melted);
    try std.testing.expectEqual(BlockId.ice, res_age3.resulting_block);
    try std.testing.expectEqual(FrostedIceStage.stage_3, res_age3.stage);

    // Aging from stage 3 to melted water
    const res_melt = tickFrostedIceLifecycle(3, 14);
    try std.testing.expectEqual(@as(u8, 4), res_melt.next_age);
    try std.testing.expect(res_melt.melted);
    try std.testing.expectEqual(BlockId.water, res_melt.resulting_block);
    try std.testing.expectEqual(FrostedIceStage.melted, res_melt.stage);
}

test "18. hazard immunity: Frost Walker negates magma block contact damage" {
    // Unenchanted: magma causes 1.0 damage per second
    try std.testing.expect(!isPlayerImmuneToHazard(.magma, 0));
    try std.testing.expectEqual(@as(f32, 1.0), calculateHazardDamage(.magma, 0, 1.0));
    try std.testing.expectEqual(@as(f32, 19.0), applyHazardContactDamage(20.0, .magma, 0, 1.0));

    // Frost Walker I: immunity active, 0 damage!
    try std.testing.expect(isPlayerImmuneToHazard(.magma, 1));
    try std.testing.expectEqual(@as(f32, 0.0), calculateHazardDamage(.magma, 1, 1.0));
    try std.testing.expectEqual(@as(f32, 20.0), applyHazardContactDamage(20.0, .magma, 1, 1.0));

    // Frost Walker II: immunity active, 0 damage!
    try std.testing.expect(isPlayerImmuneToHazard(.magma, 2));
    try std.testing.expectEqual(@as(f32, 0.0), calculateHazardDamage(.magma, 2, 1.0));
    try std.testing.expectEqual(@as(f32, 20.0), applyHazardContactDamage(20.0, .magma, 2, 1.0));
}

test "19. hazard immunity: Frost Walker negates campfire burn damage" {
    // Campfire
    try std.testing.expect(!isPlayerImmuneToHazard(.campfire, 0));
    try std.testing.expectEqual(@as(f32, 2.0), calculateHazardDamage(.campfire, 0, 1.0));

    try std.testing.expect(isPlayerImmuneToHazard(.campfire, 1));
    try std.testing.expectEqual(@as(f32, 0.0), calculateHazardDamage(.campfire, 1, 1.0));
    try std.testing.expectEqual(@as(f32, 20.0), applyHazardContactDamage(20.0, .campfire, 1, 1.0));

    // Soul Campfire
    try std.testing.expect(!isPlayerImmuneToHazard(.soul_campfire, 0));
    try std.testing.expectEqual(@as(f32, 2.0), calculateHazardDamage(.soul_campfire, 0, 1.0));

    try std.testing.expect(isPlayerImmuneToHazard(.soul_campfire, 2));
    try std.testing.expectEqual(@as(f32, 0.0), calculateHazardDamage(.soul_campfire, 2, 1.0));
    try std.testing.expectEqual(@as(f32, 20.0), applyHazardContactDamage(20.0, .soul_campfire, 2, 1.0));
}

test "20. hazard immunity: lava damage is NOT negated by Frost Walker" {
    // Lava burns through Frost Walker boots completely
    try std.testing.expect(!isPlayerImmuneToHazard(.lava, 0));
    try std.testing.expect(!isPlayerImmuneToHazard(.lava, 1));
    try std.testing.expect(!isPlayerImmuneToHazard(.lava, 2));

    try std.testing.expectEqual(@as(f32, 8.0), calculateHazardDamage(.lava, 1, 1.0));
    try std.testing.expectEqual(@as(f32, 8.0), calculateHazardDamage(.lava, 2, 1.0));
    try std.testing.expectEqual(@as(f32, 12.0), applyHazardContactDamage(20.0, .lava, 2, 1.0));
}

// Mock world for crystallization tests
fn mockIsSourceWater(x: i32, y: i32, z: i32) bool {
    _ = y;
    // Source water pond from x: -3..3, z: -3..3, except (1, 1) which is flowing water
    if (x == 1 and z == 1) return false;
    return (x >= -4 and x <= 4 and z >= -4 and z <= 4);
}

fn mockPondBlockAt(x: i32, y: i32, z: i32) BlockId {
    if (y == 63) {
        // Water surface
        if (x == 3 and z == 3) return .stone; // shoreline stone
        return .water;
    }
    if (y == 64) {
        // Air above surface, except at (-2, 0) where a wooden bridge plank obstructs
        if (x == -2 and z == 0) return .wood_planks;
        return .air;
    }
    return .stone;
}

test "21. crystallizeWaterPond: freezes still source water with air above within radius" {
    var tracker = FrostedIceTracker.init();

    // Player stands at (0, 64, 0) with Frost Walker I (radius = 3)
    const created = crystallizeWaterPond(
        &tracker,
        0,
        63,
        0,
        1,
        &mockIsSourceWater,
        &mockPondBlockAt,
    );

    try std.testing.expect(created > 0);
    // Center block (0, 63, 0) should be frosted ice
    try std.testing.expect(tracker.findBlock(0, 63, 0) != null);
    // Flowing water at (1, 63, 1) must NOT be crystallized
    try std.testing.expect(tracker.findBlock(1, 63, 1) == null);
    // Water under wooden plank at (-2, 63, 0) must NOT be crystallized (no air above)
    try std.testing.expect(tracker.findBlock(-2, 63, 0) == null);
    // Stone at (3, 63, 3) must NOT be crystallized
    try std.testing.expect(tracker.findBlock(3, 63, 3) == null);
    // Outside radius (e.g. at distance 4: (4, 63, 0)) must NOT be crystallized
    try std.testing.expect(tracker.findBlock(4, 63, 0) == null);
}

test "22. FrostedIceTracker: simulates entire thaw lifecycle across day/night cycles" {
    var tracker = FrostedIceTracker.init();

    _ = tracker.add(FrostedIceBlock.init(0, 63, 0));
    _ = tracker.add(FrostedIceBlock.init(1, 63, 0));
    _ = tracker.add(FrostedIceBlock.init(0, 63, 1));

    try std.testing.expectEqual(@as(usize, 3), tracker.activeUnmeltedCount());
    try std.testing.expectEqual(@as(usize, 3), tracker.countInStage(.stage_0));

    // Night phase: light level 4 (moonlight) -> no melting or aging occurs
    const night_melted = tracker.tickAll(4);
    try std.testing.expectEqual(@as(usize, 0), night_melted);
    try std.testing.expectEqual(@as(usize, 3), tracker.countInStage(.stage_0));

    // Morning sun: light level 14
    // Day tick 1: ages to stage_1
    _ = tracker.tickAll(14);
    try std.testing.expectEqual(@as(usize, 3), tracker.countInStage(.stage_1));

    // Day tick 2: ages to stage_2
    _ = tracker.tickAll(14);
    try std.testing.expectEqual(@as(usize, 3), tracker.countInStage(.stage_2));

    // Day tick 3: ages to stage_3
    _ = tracker.tickAll(14);
    try std.testing.expectEqual(@as(usize, 3), tracker.countInStage(.stage_3));

    // Day tick 4: ages to 4 -> all 3 blocks melt back to water!
    const day_melted = tracker.tickAll(14);
    try std.testing.expectEqual(@as(usize, 3), day_melted);
    try std.testing.expectEqual(@as(usize, 0), tracker.activeUnmeltedCount());
    try std.testing.expectEqual(@as(usize, 3), tracker.countInStage(.melted));

    // All blocks now report water
    try std.testing.expectEqual(BlockId.water, tracker.findBlock(0, 63, 0).?.currentBlockId());
}
