const std = @import("std");

// ============================================================================
// Milestone 393: Amethyst Geode Three-Layer Shell, Unmovable Budding Amethyst,
// Four Crystal Growth Stages & Fortune Yield Math
// ============================================================================

// ============================================================================
// 1. Geode Shell Layers, Fissure Generation & Radius Distribution
// ============================================================================

/// Probability that a geode generates with an open cracked entrance fissure (95%).
pub const fissure_crack_chance: f32 = 0.95;
pub const fissure_chance: f32 = fissure_crack_chance;

/// Percentage of inner lining blocks that generate as budding amethyst (8.3%, ~1 in 12).
pub const budding_amethyst_chance: f32 = 0.083;
pub const budding_amethyst_ratio: f32 = budding_amethyst_chance;

/// Normalized radius cutoff thresholds from geode center (0.0) to outer boundary (1.0).
pub const hollow_radius_max: f32 = 0.45;
pub const inner_lining_radius_max: f32 = 0.70;
pub const middle_shell_radius_max: f32 = 0.88;
pub const outer_shell_radius_max: f32 = 1.00;

/// The concentric layers composing an amethyst geode:
/// - Outer shell: `.smooth_basalt`
/// - Middle shell: `.calcite`
/// - Inner hollow lining: `.amethyst_block` + 8.3% `.budding_amethyst`
/// - Hollow core: `.hollow` (air or water cavity where clusters grow)
/// - Outside boundary: `.outside` (natural host stone)
pub const GeodeShellLayer = enum {
    hollow,
    amethyst_block,
    budding_amethyst,
    calcite,
    smooth_basalt,
    outside,

    // Layer aliases for convenience
    pub const inner_lining = GeodeShellLayer.amethyst_block;
    pub const middle_shell = GeodeShellLayer.calcite;
    pub const outer_shell = GeodeShellLayer.smooth_basalt;

    pub fn isOuterShell(self: GeodeShellLayer) bool {
        return self == .smooth_basalt;
    }

    pub fn isMiddleShell(self: GeodeShellLayer) bool {
        return self == .calcite;
    }

    pub fn isInnerLining(self: GeodeShellLayer) bool {
        return self == .amethyst_block or self == .budding_amethyst;
    }

    pub fn isHollow(self: GeodeShellLayer) bool {
        return self == .hollow;
    }

    pub fn isOutside(self: GeodeShellLayer) bool {
        return self == .outside;
    }

    pub fn name(self: GeodeShellLayer) []const u8 {
        return switch (self) {
            .hollow => "Hollow Air Cavity",
            .amethyst_block => "Block of Amethyst",
            .budding_amethyst => "Budding Amethyst",
            .calcite => "Calcite",
            .smooth_basalt => "Smooth Basalt",
            .outside => "Host Rock",
        };
    }
};

/// Determines the structural geode layer for a normalized radius r in [0.0, 1.0].
/// - 0.00 <= r < 0.45: .hollow (cavity core)
/// - 0.45 <= r < 0.70: .amethyst_block (inner hollow lining)
/// - 0.70 <= r < 0.88: .calcite (middle shell)
/// - 0.88 <= r <= 1.00: .smooth_basalt (outer shell)
/// - r < 0.0 or r > 1.00: .outside
pub fn geodeLayerForNormalizedRadius(r_0_to_1: f32) GeodeShellLayer {
    if (r_0_to_1 < 0.0 or r_0_to_1 > outer_shell_radius_max) {
        return .outside;
    }
    if (r_0_to_1 < hollow_radius_max) {
        return .hollow;
    }
    if (r_0_to_1 < inner_lining_radius_max) {
        return .amethyst_block;
    }
    if (r_0_to_1 < middle_shell_radius_max) {
        return .calcite;
    }
    return .smooth_basalt;
}

/// Evaluates whether an inner lining block generates as rare budding amethyst (8.3% chance).
pub fn isBuddingAmethyst(random_roll: f32) bool {
    return random_roll < budding_amethyst_chance;
}

/// Resolves the specific inner lining block based on random distribution roll:
/// 8.3% chance of Budding Amethyst, otherwise standard Block of Amethyst.
pub fn resolveInnerLiningBlock(random_roll: f32) GeodeShellLayer {
    return if (isBuddingAmethyst(random_roll)) .budding_amethyst else .amethyst_block;
}

/// Determines the exact geode block at normalized radius r, factoring in the 8.3%
/// chance of Budding Amethyst in the inner hollow lining.
pub fn geodeBlockForNormalizedRadius(r_0_to_1: f32, budding_roll: f32) GeodeShellLayer {
    const layer = geodeLayerForNormalizedRadius(r_0_to_1);
    if (layer == .amethyst_block and isBuddingAmethyst(budding_roll)) {
        return .budding_amethyst;
    }
    return layer;
}

/// Returns true if a random roll in [0.0, 1.0) indicates the geode generates with
/// a cracked entrance fissure (95% chance).
pub fn hasCrackedFissure(random_roll: f32) bool {
    return random_roll < fissure_crack_chance;
}

/// Alias for cracked fissure determination.
pub fn hasFissure(random_roll: f32) bool {
    return hasCrackedFissure(random_roll);
}

// ============================================================================
// 2. Budding Amethyst In-Situ Mechanics & Piston Destruction Rules
// ============================================================================

/// Piston interaction behaviors for blocks.
pub const PistonPushBehavior = enum {
    normal,
    destroy_on_push,
    block,
    push_only,
};

pub const PistonBehavior = PistonPushBehavior;

/// Behavioral rules governing Budding Amethyst:
/// - Cannot be obtained even with Silk Touch (`dropsWhenMined(has_silk_touch) == false`).
/// - Breaks immediately if pushed by a Piston or Sticky Piston (`pistonBehavior() == .destroy_on_push`).
/// - Crystals must be farmed in-situ within the natural geode.
pub const BuddingAmethystRules = struct {
    pub const drops_item_on_mining: bool = false;
    pub const silk_touch_effective: bool = false;
    pub const requires_in_situ_farming: bool = true;

    /// Budding Amethyst drops nothing when mined, regardless of Silk Touch enchantment.
    pub fn dropsWhenMined(has_silk_touch: bool) bool {
        _ = has_silk_touch;
        return false;
    }

    /// Budding Amethyst shatters and breaks immediately when pushed by a piston.
    pub fn pistonBehavior() PistonPushBehavior {
        return .destroy_on_push;
    }

    /// Cannot be moved into an automated movable flying machine or displaced by pistons.
    pub fn canBeMovedByPiston() bool {
        return false;
    }

    /// Requires in-situ farming inside the geode.
    pub fn requiresInSituFarming() bool {
        return true;
    }

    /// Shattering by piston drops nothing.
    pub fn dropsOnPistonPush() bool {
        return false;
    }
};

/// Module-level wrapper for Budding Amethyst mining drops.
pub fn dropsWhenMined(has_silk_touch: bool) bool {
    return BuddingAmethystRules.dropsWhenMined(has_silk_touch);
}

/// Module-level wrapper for Budding Amethyst piston push behavior.
pub fn pistonBehavior() PistonPushBehavior {
    return BuddingAmethystRules.pistonBehavior();
}

// ============================================================================
// 3. Four Amethyst Crystal Growth Stages & Face Growth Mechanics
// ============================================================================

/// The 6 orthogonal block faces where amethyst crystals can grow.
pub const GrowthFace = enum(u3) {
    down = 0,
    up = 1,
    north = 2,
    south = 3,
    west = 4,
    east = 5,

    pub fn offset(self: GrowthFace) [3]i32 {
        return switch (self) {
            .down => .{ 0, -1, 0 },
            .up => .{ 0, 1, 0 },
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .west => .{ -1, 0, 0 },
            .east => .{ 1, 0, 0 },
        };
    }
};

pub const all_growth_faces: [6]GrowthFace = .{
    .down, .up, .north, .south, .west, .east,
};

/// Four distinct crystal growth stages:
/// - `.small_bud`: stage 1, emits light level 1
/// - `.medium_bud`: stage 2, emits light level 2
/// - `.large_bud`: stage 3, emits light level 4
/// - `.amethyst_cluster`: stage 4 (final), emits light level 5
pub const AmethystGrowthStage = enum(u8) {
    small_bud = 0,
    medium_bud = 1,
    large_bud = 2,
    amethyst_cluster = 3,

    /// Emitted block light level for this growth stage.
    pub fn lightLevel(self: AmethystGrowthStage) u4 {
        return switch (self) {
            .small_bud => 1,
            .medium_bud => 2,
            .large_bud => 4,
            .amethyst_cluster => 5,
        };
    }

    pub fn emittedLight(self: AmethystGrowthStage) u4 {
        return self.lightLevel();
    }

    /// Next sequential growth stage, or null if fully matured into an amethyst cluster.
    pub fn next(self: AmethystGrowthStage) ?AmethystGrowthStage {
        return switch (self) {
            .small_bud => .medium_bud,
            .medium_bud => .large_bud,
            .large_bud => .amethyst_cluster,
            .amethyst_cluster => null,
        };
    }

    pub fn isFullyGrown(self: AmethystGrowthStage) bool {
        return self == .amethyst_cluster;
    }

    pub fn isCluster(self: AmethystGrowthStage) bool {
        return self == .amethyst_cluster;
    }

    pub fn isBud(self: AmethystGrowthStage) bool {
        return self != .amethyst_cluster;
    }

    pub fn name(self: AmethystGrowthStage) []const u8 {
        return switch (self) {
            .small_bud => "Small Amethyst Bud",
            .medium_bud => "Medium Amethyst Bud",
            .large_bud => "Large Amethyst Bud",
            .amethyst_cluster => "Amethyst Cluster",
        };
    }
};

/// Buds can sprout or grow on any of the 6 faces of a `budding_amethyst` block
/// provided that the adjacent face block is air or water source.
pub fn canGrowAmethystOnFace(adjacent_is_air_or_water: bool) bool {
    return adjacent_is_air_or_water;
}

/// Advances growth on a budding amethyst face if the environment permits.
pub fn progressGrowthOnFace(
    current_stage: ?AmethystGrowthStage,
    adjacent_is_air_or_water: bool,
) ?AmethystGrowthStage {
    if (!canGrowAmethystOnFace(adjacent_is_air_or_water)) {
        return current_stage;
    }
    if (current_stage) |stage| {
        return stage.next() orelse stage;
    } else {
        return .small_bud;
    }
}

// ============================================================================
// 4. Amethyst Harvest Yield Math & Fortune Pickaxe Distribution
// ============================================================================

/// Harvest item drops from amethyst buds and clusters.
pub const AmethystDropItem = enum {
    none,
    amethyst_shard,
    small_bud,
    medium_bud,
    large_bud,
    amethyst_cluster,
};

pub const DropItem = AmethystDropItem;

/// Yield result containing item kind, drop count, and shard count.
pub const AmethystHarvestYield = struct {
    item: AmethystDropItem = .none,
    count: u8 = 0,
    shard_count: u8 = 0,
    drops_self: bool = false,

    /// Calculates harvest drops for an amethyst growth stage:
    /// - Breaking small/medium/large bud without Silk Touch drops 0 shards (nothing).
    /// - Breaking small/medium/large bud with Silk Touch drops the bud item itself.
    /// - Breaking amethyst_cluster with Silk Touch drops the amethyst cluster item itself.
    /// - Breaking amethyst_cluster with any pickaxe drops 4 shards base (affected by Fortune).
    /// - Breaking amethyst_cluster by hand, piston, or non-pickaxe drops 2 shards.
    pub fn calculate(
        stage: AmethystGrowthStage,
        is_pickaxe: bool,
        has_silk_touch: bool,
        fortune_level: u8,
        random_roll: f32,
    ) AmethystHarvestYield {
        if (has_silk_touch) {
            return switch (stage) {
                .small_bud => .{ .item = .small_bud, .count = 1, .shard_count = 0, .drops_self = true },
                .medium_bud => .{ .item = .medium_bud, .count = 1, .shard_count = 0, .drops_self = true },
                .large_bud => .{ .item = .large_bud, .count = 1, .shard_count = 0, .drops_self = true },
                .amethyst_cluster => .{ .item = .amethyst_cluster, .count = 1, .shard_count = 0, .drops_self = true },
            };
        }

        // Buds drop nothing without Silk Touch
        if (stage != .amethyst_cluster) {
            return .{ .item = .none, .count = 0, .shard_count = 0, .drops_self = false };
        }

        // Amethyst cluster without pickaxe (hand, piston, etc.) drops 2 shards
        if (!is_pickaxe) {
            return .{ .item = .amethyst_shard, .count = 2, .shard_count = 2, .drops_self = false };
        }

        // Cluster mined with a pickaxe (base 4, multiplied by Fortune)
        const shards = clusterShardFortuneYield(fortune_level, random_roll);
        return .{
            .item = .amethyst_shard,
            .count = shards,
            .shard_count = shards,
            .drops_self = false,
        };
    }

    /// Shard yield from an amethyst cluster broken with pickaxe or non-pickaxe.
    pub fn clusterShardYield(is_pickaxe: bool, fortune_level: u8, random_roll: f32) u8 {
        if (!is_pickaxe) return 2;
        return clusterShardFortuneYield(fortune_level, random_roll);
    }

    /// Base shard yield from an amethyst cluster (4 with pickaxe, 2 without).
    pub fn baseShardYield(is_pickaxe: bool) u8 {
        return if (is_pickaxe) 4 else 2;
    }

    /// Expected theoretical average shard yield for an amethyst cluster:
    /// - Non-pickaxe: 2.0
    /// - Pickaxe Fortune 0: 4.0
    /// - Pickaxe Fortune I: 16/3 = ~5.333
    /// - Pickaxe Fortune II: 7.0
    /// - Pickaxe Fortune III: 44/5 = 8.8
    pub fn expectedClusterShards(is_pickaxe: bool, fortune_level: u8) f32 {
        if (!is_pickaxe) return 2.0;
        if (fortune_level == 0) return 4.0;
        const L: f32 = @floatFromInt(fortune_level);
        const bonus_mult = (L * (L + 1.0)) / (2.0 * (L + 2.0));
        return 4.0 * (1.0 + bonus_mult);
    }

    /// Maximum possible shard drop for an amethyst cluster with given tool and Fortune level.
    pub fn maxClusterShards(is_pickaxe: bool, fortune_level: u8) u8 {
        if (!is_pickaxe) return 2;
        const multiplier: u8 = 1 + fortune_level;
        return 4 * multiplier;
    }

    /// Minimum possible shard drop for an amethyst cluster.
    pub fn minClusterShards(is_pickaxe: bool) u8 {
        return if (is_pickaxe) 4 else 2;
    }
};

/// Discrete Fortune multiplier calculation for amethyst clusters:
/// Standard Minecraft discrete uniform Fortune distribution:
/// For Fortune level L:
/// There are (L + 2) equal outcome bins.
/// - Bins 0 and 1 correspond to multiplier 1 (drop base 4 shards).
/// - Bin k (for k in 2..L+1) corresponds to multiplier k (drop 4 * k shards).
///
/// Yield outcomes:
/// - Fortune 0: multiplier = 1 -> 4 shards.
/// - Fortune I:  multiplier = 1 or 2 -> 4 or 8 shards (avg 5.333).
/// - Fortune II: multiplier = 1, 2, or 3 -> 4, 8, or 12 shards (avg 7.0).
/// - Fortune III: multiplier = 1, 2, 3, or 4 -> 4, 8, 12, or 16 shards (avg 8.8, max 16).
pub fn clusterShardFortuneYield(fortune_level: u8, random_roll: f32) u8 {
    if (fortune_level == 0) return 4;
    const clamped_roll = std.math.clamp(random_roll, 0.0, 0.999999);
    const bins: u32 = @as(u32, fortune_level) + 2;
    const bin_float = clamped_roll * @as(f32, @floatFromInt(bins));
    const bin: u32 = @intFromFloat(bin_float);
    const mult: u8 = if (bin <= 1) 1 else @as(u8, @intCast(bin));
    return 4 * mult;
}

/// Module-level wrapper for harvest drop calculation.
pub fn calculateHarvestYield(
    stage: AmethystGrowthStage,
    is_pickaxe: bool,
    has_silk_touch: bool,
    fortune_level: u8,
    random_roll: f32,
) AmethystHarvestYield {
    return AmethystHarvestYield.calculate(stage, is_pickaxe, has_silk_touch, fortune_level, random_roll);
}

/// Module-level wrapper for cluster shard yield.
pub fn clusterShardYield(is_pickaxe: bool, fortune_level: u8, random_roll: f32) u8 {
    return AmethystHarvestYield.clusterShardYield(is_pickaxe, fortune_level, random_roll);
}

/// Module-level wrapper for expected cluster shard yield.
pub fn expectedClusterShards(is_pickaxe: bool, fortune_level: u8) f32 {
    return AmethystHarvestYield.expectedClusterShards(is_pickaxe, fortune_level);
}

/// Module-level wrapper for maximum cluster shard yield.
pub fn maxClusterShards(is_pickaxe: bool, fortune_level: u8) u8 {
    return AmethystHarvestYield.maxClusterShards(is_pickaxe, fortune_level);
}

// ============================================================================
// 5. Unit Tests (At least 12 comprehensive tests)
// ============================================================================

test "1. GeodeShellLayer enum tags, constants, and layer properties" {
    try std.testing.expectEqual(GeodeShellLayer.smooth_basalt, GeodeShellLayer.outer_shell);
    try std.testing.expectEqual(GeodeShellLayer.calcite, GeodeShellLayer.middle_shell);
    try std.testing.expectEqual(GeodeShellLayer.amethyst_block, GeodeShellLayer.inner_lining);

    try std.testing.expect(GeodeShellLayer.outer_shell.isOuterShell());
    try std.testing.expect(GeodeShellLayer.middle_shell.isMiddleShell());
    try std.testing.expect(GeodeShellLayer.inner_lining.isInnerLining());
    try std.testing.expect(GeodeShellLayer.budding_amethyst.isInnerLining());
    try std.testing.expect(GeodeShellLayer.hollow.isHollow());
    try std.testing.expect(GeodeShellLayer.outside.isOutside());

    try std.testing.expectEqualStrings("Block of Amethyst", GeodeShellLayer.amethyst_block.name());
    try std.testing.expectEqualStrings("Budding Amethyst", GeodeShellLayer.budding_amethyst.name());
    try std.testing.expectEqualStrings("Calcite", GeodeShellLayer.calcite.name());
    try std.testing.expectEqualStrings("Smooth Basalt", GeodeShellLayer.smooth_basalt.name());
}

test "2. geodeLayerForNormalizedRadius identifies shell layers accurately" {
    // Hollow interior
    try std.testing.expectEqual(GeodeShellLayer.hollow, geodeLayerForNormalizedRadius(0.0));
    try std.testing.expectEqual(GeodeShellLayer.hollow, geodeLayerForNormalizedRadius(0.20));
    try std.testing.expectEqual(GeodeShellLayer.hollow, geodeLayerForNormalizedRadius(0.44));

    // Inner hollow lining (Amethyst block)
    try std.testing.expectEqual(GeodeShellLayer.amethyst_block, geodeLayerForNormalizedRadius(0.45));
    try std.testing.expectEqual(GeodeShellLayer.amethyst_block, geodeLayerForNormalizedRadius(0.60));
    try std.testing.expectEqual(GeodeShellLayer.amethyst_block, geodeLayerForNormalizedRadius(0.699));

    // Middle shell (Calcite)
    try std.testing.expectEqual(GeodeShellLayer.calcite, geodeLayerForNormalizedRadius(0.70));
    try std.testing.expectEqual(GeodeShellLayer.calcite, geodeLayerForNormalizedRadius(0.80));
    try std.testing.expectEqual(GeodeShellLayer.calcite, geodeLayerForNormalizedRadius(0.879));

    // Outer shell (Smooth Basalt)
    try std.testing.expectEqual(GeodeShellLayer.smooth_basalt, geodeLayerForNormalizedRadius(0.88));
    try std.testing.expectEqual(GeodeShellLayer.smooth_basalt, geodeLayerForNormalizedRadius(0.95));
    try std.testing.expectEqual(GeodeShellLayer.smooth_basalt, geodeLayerForNormalizedRadius(1.00));

    // Outside host rock
    try std.testing.expectEqual(GeodeShellLayer.outside, geodeLayerForNormalizedRadius(1.01));
    try std.testing.expectEqual(GeodeShellLayer.outside, geodeLayerForNormalizedRadius(1.50));
    try std.testing.expectEqual(GeodeShellLayer.outside, geodeLayerForNormalizedRadius(-0.01));
}

test "3. geode cracked entrance fissure 95% generation chance" {
    try std.testing.expectEqual(@as(f32, 0.95), fissure_crack_chance);
    try std.testing.expect(hasCrackedFissure(0.0));
    try std.testing.expect(hasCrackedFissure(0.50));
    try std.testing.expect(hasCrackedFissure(0.9499));
    try std.testing.expect(!hasCrackedFissure(0.950));
    try std.testing.expect(!hasCrackedFissure(0.99));
}

test "4. inner lining budding amethyst 8.3% distribution" {
    try std.testing.expectEqual(@as(f32, 0.083), budding_amethyst_chance);
    try std.testing.expect(isBuddingAmethyst(0.0));
    try std.testing.expect(isBuddingAmethyst(0.05));
    try std.testing.expect(isBuddingAmethyst(0.0829));
    try std.testing.expect(!isBuddingAmethyst(0.083));
    try std.testing.expect(!isBuddingAmethyst(0.50));

    try std.testing.expectEqual(GeodeShellLayer.budding_amethyst, resolveInnerLiningBlock(0.04));
    try std.testing.expectEqual(GeodeShellLayer.amethyst_block, resolveInnerLiningBlock(0.10));

    // Check geodeBlockForNormalizedRadius with budding amethyst
    try std.testing.expectEqual(GeodeShellLayer.budding_amethyst, geodeBlockForNormalizedRadius(0.55, 0.02));
    try std.testing.expectEqual(GeodeShellLayer.amethyst_block, geodeBlockForNormalizedRadius(0.55, 0.20));
    // Middle and outer layers are unaffected by budding amethyst roll
    try std.testing.expectEqual(GeodeShellLayer.calcite, geodeBlockForNormalizedRadius(0.75, 0.01));
    try std.testing.expectEqual(GeodeShellLayer.smooth_basalt, geodeBlockForNormalizedRadius(0.95, 0.01));
}

test "5. BuddingAmethystRules cannot be mined even with Silk Touch" {
    try std.testing.expectEqual(false, BuddingAmethystRules.dropsWhenMined(false));
    try std.testing.expectEqual(false, BuddingAmethystRules.dropsWhenMined(true));
    try std.testing.expectEqual(false, dropsWhenMined(false));
    try std.testing.expectEqual(false, dropsWhenMined(true));
}

test "6. BuddingAmethystRules piston behavior breaks on push requiring in-situ farming" {
    try std.testing.expectEqual(PistonPushBehavior.destroy_on_push, BuddingAmethystRules.pistonBehavior());
    try std.testing.expectEqual(PistonPushBehavior.destroy_on_push, pistonBehavior());
    try std.testing.expect(!BuddingAmethystRules.canBeMovedByPiston());
    try std.testing.expect(BuddingAmethystRules.requiresInSituFarming());
    try std.testing.expect(!BuddingAmethystRules.dropsOnPistonPush());
}

test "7. AmethystGrowthStage light levels and progression" {
    try std.testing.expectEqual(@as(u4, 1), AmethystGrowthStage.small_bud.lightLevel());
    try std.testing.expectEqual(@as(u4, 2), AmethystGrowthStage.medium_bud.lightLevel());
    try std.testing.expectEqual(@as(u4, 4), AmethystGrowthStage.large_bud.lightLevel());
    try std.testing.expectEqual(@as(u4, 5), AmethystGrowthStage.amethyst_cluster.lightLevel());

    try std.testing.expectEqual(AmethystGrowthStage.medium_bud, AmethystGrowthStage.small_bud.next().?);
    try std.testing.expectEqual(AmethystGrowthStage.large_bud, AmethystGrowthStage.medium_bud.next().?);
    try std.testing.expectEqual(AmethystGrowthStage.amethyst_cluster, AmethystGrowthStage.large_bud.next().?);
    try std.testing.expectEqual(@as(?AmethystGrowthStage, null), AmethystGrowthStage.amethyst_cluster.next());

    try std.testing.expect(AmethystGrowthStage.amethyst_cluster.isCluster());
    try std.testing.expect(!AmethystGrowthStage.large_bud.isCluster());
}

test "8. Amethyst growth face attachment on all 6 faces for air or water" {
    try std.testing.expect(canGrowAmethystOnFace(true));
    try std.testing.expect(!canGrowAmethystOnFace(false));

    // Verify all 6 orthogonal growth faces
    try std.testing.expectEqual(@as(usize, 6), all_growth_faces.len);
    for (all_growth_faces) |face| {
        const offset = face.offset();
        const dist_sq = offset[0] * offset[0] + offset[1] * offset[1] + offset[2] * offset[2];
        try std.testing.expectEqual(@as(i32, 1), dist_sq);
    }

    // Growth progression helper
    try std.testing.expectEqual(AmethystGrowthStage.small_bud, progressGrowthOnFace(null, true).?);
    try std.testing.expectEqual(null, progressGrowthOnFace(null, false));
    try std.testing.expectEqual(AmethystGrowthStage.medium_bud, progressGrowthOnFace(.small_bud, true).?);
    try std.testing.expectEqual(AmethystGrowthStage.small_bud, progressGrowthOnFace(.small_bud, false).?);
}

test "9. Amethyst bud harvesting drops 0 shards without Silk Touch" {
    const stages = [_]AmethystGrowthStage{ .small_bud, .medium_bud, .large_bud };
    for (stages) |stage| {
        const yield_pickaxe = calculateHarvestYield(stage, true, false, 0, 0.5);
        try std.testing.expectEqual(AmethystDropItem.none, yield_pickaxe.item);
        try std.testing.expectEqual(@as(u8, 0), yield_pickaxe.count);
        try std.testing.expectEqual(@as(u8, 0), yield_pickaxe.shard_count);
        try std.testing.expect(!yield_pickaxe.drops_self);

        const yield_hand = calculateHarvestYield(stage, false, false, 0, 0.5);
        try std.testing.expectEqual(AmethystDropItem.none, yield_hand.item);
        try std.testing.expectEqual(@as(u8, 0), yield_hand.count);
        try std.testing.expectEqual(@as(u8, 0), yield_hand.shard_count);
    }
}

test "10. Amethyst bud harvesting with Silk Touch drops the bud item itself" {
    const yield_small = calculateHarvestYield(.small_bud, true, true, 0, 0.0);
    try std.testing.expectEqual(AmethystDropItem.small_bud, yield_small.item);
    try std.testing.expectEqual(@as(u8, 1), yield_small.count);
    try std.testing.expectEqual(@as(u8, 0), yield_small.shard_count);
    try std.testing.expect(yield_small.drops_self);

    const yield_medium = calculateHarvestYield(.medium_bud, true, true, 0, 0.0);
    try std.testing.expectEqual(AmethystDropItem.medium_bud, yield_medium.item);
    try std.testing.expectEqual(@as(u8, 1), yield_medium.count);
    try std.testing.expect(yield_medium.drops_self);

    const yield_large = calculateHarvestYield(.large_bud, true, true, 0, 0.0);
    try std.testing.expectEqual(AmethystDropItem.large_bud, yield_large.item);
    try std.testing.expectEqual(@as(u8, 1), yield_large.count);
    try std.testing.expect(yield_large.drops_self);

    const yield_cluster = calculateHarvestYield(.amethyst_cluster, true, true, 0, 0.0);
    try std.testing.expectEqual(AmethystDropItem.amethyst_cluster, yield_cluster.item);
    try std.testing.expectEqual(@as(u8, 1), yield_cluster.count);
    try std.testing.expect(yield_cluster.drops_self);
}

test "11. Amethyst cluster base drops with pickaxe vs non-pickaxe" {
    // Pickaxe without fortune drops 4 shards
    const yield_pickaxe = calculateHarvestYield(.amethyst_cluster, true, false, 0, 0.0);
    try std.testing.expectEqual(AmethystDropItem.amethyst_shard, yield_pickaxe.item);
    try std.testing.expectEqual(@as(u8, 4), yield_pickaxe.count);
    try std.testing.expectEqual(@as(u8, 4), yield_pickaxe.shard_count);

    // Non-pickaxe (hand, piston, etc.) drops 2 shards
    const yield_hand = calculateHarvestYield(.amethyst_cluster, false, false, 0, 0.0);
    try std.testing.expectEqual(AmethystDropItem.amethyst_shard, yield_hand.item);
    try std.testing.expectEqual(@as(u8, 2), yield_hand.count);
    try std.testing.expectEqual(@as(u8, 2), yield_hand.shard_count);

    // Non-pickaxe with Fortune still drops only 2 shards
    const yield_hand_fortune = calculateHarvestYield(.amethyst_cluster, false, false, 3, 0.99);
    try std.testing.expectEqual(@as(u8, 2), yield_hand_fortune.count);
}

test "12. Fortune I pickaxe cluster drop distribution and average 5.33" {
    // Fortune I yields 4 shards for roll in [0.0, 2/3) and 8 shards for roll in [2/3, 1.0)
    try std.testing.expectEqual(@as(u8, 4), clusterShardFortuneYield(1, 0.0));
    try std.testing.expectEqual(@as(u8, 4), clusterShardFortuneYield(1, 0.50));
    try std.testing.expectEqual(@as(u8, 4), clusterShardFortuneYield(1, 0.66));
    try std.testing.expectEqual(@as(u8, 8), clusterShardFortuneYield(1, 0.67));
    try std.testing.expectEqual(@as(u8, 8), clusterShardFortuneYield(1, 0.99));

    // Expected average: 4 * (2/3) + 8 * (1/3) = 16/3 = 5.333333...
    const expected = expectedClusterShards(true, 1);
    const target: f32 = 16.0 / 3.0;
    try std.testing.expect(std.math.approxEqAbs(f32, target, expected, 0.001));
    try std.testing.expect(expected > 5.33 and expected < 5.34);
}

test "13. Fortune II pickaxe cluster drop distribution and average 7.0" {
    // Fortune II yields 4 shards for [0.0, 0.50), 8 shards for [0.50, 0.75), 12 shards for [0.75, 1.0)
    try std.testing.expectEqual(@as(u8, 4), clusterShardFortuneYield(2, 0.0));
    try std.testing.expectEqual(@as(u8, 4), clusterShardFortuneYield(2, 0.49));
    try std.testing.expectEqual(@as(u8, 8), clusterShardFortuneYield(2, 0.50));
    try std.testing.expectEqual(@as(u8, 8), clusterShardFortuneYield(2, 0.74));
    try std.testing.expectEqual(@as(u8, 12), clusterShardFortuneYield(2, 0.75));
    try std.testing.expectEqual(@as(u8, 12), clusterShardFortuneYield(2, 0.99));

    // Expected average: 4 * 0.5 + 8 * 0.25 + 12 * 0.25 = 2.0 + 2.0 + 3.0 = 7.0
    const expected = expectedClusterShards(true, 2);
    try std.testing.expectEqual(@as(f32, 7.0), expected);
    try std.testing.expectEqual(@as(u8, 12), maxClusterShards(true, 2));
}

test "14. Fortune III pickaxe cluster drop distribution, max 16, and average 8.8" {
    // Fortune III yields:
    // [0.0, 0.40) -> 4 shards
    // [0.40, 0.60) -> 8 shards
    // [0.60, 0.80) -> 12 shards
    // [0.80, 1.00) -> 16 shards
    try std.testing.expectEqual(@as(u8, 4), clusterShardFortuneYield(3, 0.0));
    try std.testing.expectEqual(@as(u8, 4), clusterShardFortuneYield(3, 0.39));
    try std.testing.expectEqual(@as(u8, 8), clusterShardFortuneYield(3, 0.40));
    try std.testing.expectEqual(@as(u8, 8), clusterShardFortuneYield(3, 0.59));
    try std.testing.expectEqual(@as(u8, 12), clusterShardFortuneYield(3, 0.60));
    try std.testing.expectEqual(@as(u8, 12), clusterShardFortuneYield(3, 0.79));
    try std.testing.expectEqual(@as(u8, 16), clusterShardFortuneYield(3, 0.80));
    try std.testing.expectEqual(@as(u8, 16), clusterShardFortuneYield(3, 0.99));

    // Max 16 shards
    try std.testing.expectEqual(@as(u8, 16), maxClusterShards(true, 3));

    // Expected average: 4 * 0.4 + 8 * 0.2 + 12 * 0.2 + 16 * 0.2 = 1.6 + 1.6 + 2.4 + 3.2 = 8.8
    const expected = expectedClusterShards(true, 3);
    const target: f32 = 44.0 / 5.0;
    try std.testing.expect(std.math.approxEqAbs(f32, target, expected, 0.001));
    try std.testing.expectEqual(@as(f32, 8.8), expected);
}

test "15. Full geode radial traversal and material profiling" {
    const radial_samples = [_]struct { r: f32, expected_layer: GeodeShellLayer }{
        .{ .r = 0.0, .expected_layer = .hollow },
        .{ .r = 0.25, .expected_layer = .hollow },
        .{ .r = 0.50, .expected_layer = .amethyst_block },
        .{ .r = 0.65, .expected_layer = .amethyst_block },
        .{ .r = 0.75, .expected_layer = .calcite },
        .{ .r = 0.85, .expected_layer = .calcite },
        .{ .r = 0.92, .expected_layer = .smooth_basalt },
        .{ .r = 1.00, .expected_layer = .smooth_basalt },
        .{ .r = 1.15, .expected_layer = .outside },
    };

    for (radial_samples) |sample| {
        const layer = geodeLayerForNormalizedRadius(sample.r);
        try std.testing.expectEqual(sample.expected_layer, layer);
    }
}
