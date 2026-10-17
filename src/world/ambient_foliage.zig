const std = @import("std");

pub const leaf_litter_burn_seconds: f32 = 5.0;
pub const min_cluster_stage: u3 = 1;
pub const max_cluster_stage: u3 = 4;
pub const wildflower_yellow_dye_yield: u8 = 1;
pub const wildflower_white_dye_yield: u8 = 1;
pub const cactus_flower_pink_dye_yield: u8 = 1;

/// A swamp or riverbank shrub supporting fireflies and night-time insect ambience.
pub const FireflyBushState = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    is_waterlogged: bool = false,

    pub fn init(x: i32, y: i32, z: i32, is_waterlogged: bool) FireflyBushState {
        return .{ .x = x, .y = y, .z = z, .is_waterlogged = is_waterlogged };
    }

    pub fn shouldEmitFireflies(is_night: bool, light_level: u4) bool {
        return is_night and light_level <= 9;
    }

    pub fn fireflySpawnCount(bush_count: u8, dt: f32) u8 {
        if (bush_count == 0 or dt <= 0.0) return 0;
        // One particle per bush per second on average, with fractional time
        // accumulated by callers across ticks.
        const count = @as(f32, @floatFromInt(bush_count)) * dt;
        return @intFromFloat(@min(count, 255.0));
    }

    /// Crickets and soft wing-whirr pulses occur at night or under a dark canopy.
    pub fn shouldEmitAmbientPulse(is_night: bool, light_level: u4) bool {
        return is_night or light_level <= 9;
    }

    /// Bone meal spreads to adjacent shoreline or waterlogged cells only.
    pub fn boneMealPropagationCount(adjacent_waterlogged_or_shore_tiles: u8) u8 {
        return adjacent_waterlogged_or_shore_tiles;
    }
};

/// A dry forest-floor layer, represented as one to four accumulated quarters.
pub const LeafLitterCluster = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    stage: u3 = min_cluster_stage,

    pub fn init(x: i32, y: i32, z: i32, stage: u3) LeafLitterCluster {
        return .{ .x = x, .y = y, .z = z, .stage = clampStage(stage) };
    }

    pub fn addLeafLitter(self: *LeafLitterCluster) bool {
        if (self.stage >= max_cluster_stage) return false;
        self.stage += 1;
        return true;
    }

    /// Each smelted leaf block yields one leaf-litter item.
    pub fn smeltLeavesToLeafLitter(leaf_block_count: u8) u8 {
        return leaf_block_count;
    }

    /// Returns crisp rustling intensity, scaled by layer depth and movement speed.
    pub fn rustleVolume(cluster_stage: u3, speed: f32) f32 {
        if (speed <= 0.0) return 0.0;
        const stage = clampStage(cluster_stage);
        const normalized_stage = @as(f32, @floatFromInt(stage)) / 4.0;
        return @min(1.0, normalized_stage * @min(speed, 1.0));
    }

    pub fn burnSeconds(self: LeafLitterCluster) f32 {
        _ = self;
        return leaf_litter_burn_seconds;
    }
};

/// Birch/meadow flower patch containing yellow and white blooms.
pub const WildflowerCluster = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    count: u3 = min_cluster_stage,
    yellow_count: u3 = 1,

    pub fn init(x: i32, y: i32, z: i32, count: u3, yellow_count: u3) WildflowerCluster {
        const clamped_count = clampStage(count);
        return .{
            .x = x,
            .y = y,
            .z = z,
            .count = clamped_count,
            .yellow_count = @min(yellow_count, clamped_count),
        };
    }

    /// Adds one flower when possible; the new flower alternates color according
    /// to the current patch balance, beginning with yellow.
    pub fn applyBoneMeal(self: *WildflowerCluster) bool {
        if (self.count >= max_cluster_stage) return false;
        self.count += 1;
        if (self.yellow_count < (self.count + 1) / 2) self.yellow_count += 1;
        return true;
    }

    pub fn addFlower(self: *WildflowerCluster, is_yellow: bool) bool {
        if (self.count >= max_cluster_stage) return false;
        self.count += 1;
        if (is_yellow) self.yellow_count += 1;
        return true;
    }

    pub fn dyeYield(self: WildflowerCluster) WildflowerDyeYield {
        const yellow: u8 = @intCast(self.yellow_count);
        const white: u8 = @intCast(self.count - self.yellow_count);
        return .{ .yellow = yellow * wildflower_yellow_dye_yield, .white = white * wildflower_white_dye_yield };
    }
};

pub const WildflowerDyeYield = struct { yellow: u8, white: u8 };

// Free-function entry points mirror the block-system helpers used by the
// integration worker, while the methods above make each state convenient to
// use from simulation code.
pub fn shouldEmitFireflies(is_night: bool, light_level: u4) bool {
    return FireflyBushState.shouldEmitFireflies(is_night, light_level);
}

pub fn fireflySpawnCount(bush_count: u8, dt: f32) u8 {
    return FireflyBushState.fireflySpawnCount(bush_count, dt);
}

pub fn addLeafLitter(cluster: *LeafLitterCluster) bool {
    return cluster.addLeafLitter();
}

pub fn smeltLeavesToLeafLitter(leaf_block_count: u8) u8 {
    return LeafLitterCluster.smeltLeavesToLeafLitter(leaf_block_count);
}

pub fn rustleVolume(cluster_stage: u3, speed: f32) f32 {
    return LeafLitterCluster.rustleVolume(cluster_stage, speed);
}

pub fn canGrowCactusFlower(cactus_column_height: u8, block_above_is_air: bool) bool {
    return CactusFlowerState.canGrowCactusFlower(cactus_column_height, block_above_is_air);
}

/// Pink blossom grown atop mature cactus columns; bees can pollinate it.
pub const CactusFlowerState = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    is_pollinated: bool = false,

    pub fn init(x: i32, y: i32, z: i32) CactusFlowerState {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn canGrowCactusFlower(cactus_column_height: u8, block_above_is_air: bool) bool {
        return cactus_column_height >= 3 and block_above_is_air;
    }

    pub fn attractBees(self: *CactusFlowerState) void {
        self.is_pollinated = true;
    }

    pub fn pinkDyeYield(self: CactusFlowerState) u8 {
        _ = self;
        return cactus_flower_pink_dye_yield;
    }
};

fn clampStage(stage: u3) u3 {
    return @max(min_cluster_stage, @min(stage, max_cluster_stage));
}

test "firefly bush emits only at night in low light" {
    try std.testing.expect(FireflyBushState.shouldEmitFireflies(true, 0));
    try std.testing.expect(FireflyBushState.shouldEmitFireflies(true, 9));
    try std.testing.expect(!FireflyBushState.shouldEmitFireflies(true, 10));
    try std.testing.expect(!FireflyBushState.shouldEmitFireflies(false, 0));
}

test "firefly spawn count scales with bushes and elapsed time" {
    try std.testing.expectEqual(@as(u8, 0), FireflyBushState.fireflySpawnCount(0, 2.0));
    try std.testing.expectEqual(@as(u8, 0), FireflyBushState.fireflySpawnCount(4, 0.0));
    try std.testing.expectEqual(@as(u8, 2), FireflyBushState.fireflySpawnCount(4, 0.5));
    try std.testing.expectEqual(@as(u8, 255), FireflyBushState.fireflySpawnCount(255, 2.0));
}

test "bush ambience sounds at night or in dark canopies" {
    try std.testing.expect(FireflyBushState.shouldEmitAmbientPulse(true, 15));
    try std.testing.expect(FireflyBushState.shouldEmitAmbientPulse(false, 9));
    try std.testing.expect(!FireflyBushState.shouldEmitAmbientPulse(false, 10));
}

test "bone meal propagation count reflects eligible shore tiles" {
    try std.testing.expectEqual(@as(u8, 3), FireflyBushState.boneMealPropagationCount(3));
    try std.testing.expectEqual(@as(u8, 0), FireflyBushState.boneMealPropagationCount(0));
}

test "leaf litter initializes and adds one through four quarters" {
    var cluster = LeafLitterCluster.init(1, 2, 3, 1);
    try std.testing.expectEqual(@as(u3, 1), cluster.stage);
    try std.testing.expect(cluster.addLeafLitter());
    try std.testing.expect(cluster.addLeafLitter());
    try std.testing.expect(cluster.addLeafLitter());
    try std.testing.expectEqual(@as(u3, 4), cluster.stage);
    try std.testing.expect(!cluster.addLeafLitter());
}

test "leaf litter stage clamps to the supported one to four range" {
    try std.testing.expectEqual(@as(u3, 1), LeafLitterCluster.init(0, 0, 0, 0).stage);
    try std.testing.expectEqual(@as(u3, 4), LeafLitterCluster.init(0, 0, 0, 7).stage);
}

test "smelting leaves yields leaf litter" {
    try std.testing.expectEqual(@as(u8, 0), LeafLitterCluster.smeltLeavesToLeafLitter(0));
    try std.testing.expectEqual(@as(u8, 5), LeafLitterCluster.smeltLeavesToLeafLitter(5));
}

test "leaf litter rustle scales with stage and speed" {
    try std.testing.expectEqual(@as(f32, 0.0), LeafLitterCluster.rustleVolume(4, 0.0));
    try std.testing.expectEqual(@as(f32, 0.25), LeafLitterCluster.rustleVolume(1, 1.0));
    try std.testing.expectEqual(@as(f32, 0.5), LeafLitterCluster.rustleVolume(4, 0.5));
    try std.testing.expectEqual(@as(f32, 1.0), LeafLitterCluster.rustleVolume(4, 2.0));
}

test "leaf litter is five second furnace fuel" {
    const cluster = LeafLitterCluster.init(0, 0, 0, 1);
    try std.testing.expectEqual(@as(f32, 5.0), cluster.burnSeconds());
    try std.testing.expectEqual(@as(f32, 5.0), leaf_litter_burn_seconds);
}

test "wildflower cluster supports stages one through four" {
    var flowers = WildflowerCluster.init(0, 0, 0, 1, 1);
    try std.testing.expectEqual(@as(u3, 1), flowers.count);
    try std.testing.expect(flowers.applyBoneMeal());
    try std.testing.expect(flowers.applyBoneMeal());
    try std.testing.expect(flowers.applyBoneMeal());
    try std.testing.expectEqual(@as(u3, 4), flowers.count);
    try std.testing.expect(!flowers.applyBoneMeal());
}

test "wildflower initialization clamps count and color count" {
    const flowers = WildflowerCluster.init(0, 0, 0, 7, 7);
    try std.testing.expectEqual(@as(u3, 4), flowers.count);
    try std.testing.expectEqual(@as(u3, 4), flowers.yellow_count);
}

test "wildflowers yield yellow and white dye by bloom color" {
    var flowers = WildflowerCluster.init(0, 0, 0, 2, 1);
    const yield = flowers.dyeYield();
    try std.testing.expectEqual(@as(u8, 1), yield.yellow);
    try std.testing.expectEqual(@as(u8, 1), yield.white);
    try std.testing.expect(flowers.addFlower(false));
    const expanded_yield = flowers.dyeYield();
    try std.testing.expectEqual(@as(u8, 1), expanded_yield.yellow);
    try std.testing.expectEqual(@as(u8, 2), expanded_yield.white);
}

test "cactus flower requires three block mature cactus and air above" {
    try std.testing.expect(!CactusFlowerState.canGrowCactusFlower(2, true));
    try std.testing.expect(CactusFlowerState.canGrowCactusFlower(3, true));
    try std.testing.expect(CactusFlowerState.canGrowCactusFlower(4, true));
    try std.testing.expect(!CactusFlowerState.canGrowCactusFlower(3, false));
}

test "bees pollinate cactus flowers and blossom crafts to pink dye" {
    var flower = CactusFlowerState.init(1, 5, 2);
    try std.testing.expect(!flower.is_pollinated);
    flower.attractBees();
    try std.testing.expect(flower.is_pollinated);
    try std.testing.expectEqual(@as(u8, 1), flower.pinkDyeYield());
}
