const std = @import("std");

/// ============================================================================
/// Milestone 401: Sunflower Plains East-Facing Heliotropism,
/// Flower Forest Positional Gradient & Two-Block Tall Flower Bone-Meal Duplication
/// ============================================================================
///
/// In Minecraft:
/// 1. Sunflower Heliotropism:
///    Sunflowers (2-block-tall flowers) always have their upper head bloom facing
///    true East (+X sunrise direction) regardless of player placement orientation
///    or time of day, acting as an immutable natural compass in the Overworld.
///
/// 2. Two-Block Tall Flower Bone-Meal Duplication:
///    Applying bone meal directly to any 2-block-tall flower (sunflower, lilac,
///    rose bush, peony) drops 1 item copy of that tall flower as an item entity,
///    making renewable dye farms possible (yielding 2 dyes per flower item).
///    Ancient sniffer flowers (pitcher plant, torchflower) cannot be duplicated.
///
/// 3. Flower Forest Coordinate Gradient:
///    In the Flower Forest biome, applying bone meal to grass generates flowers
///    strictly deterministically based on the block's (x, z) world coordinate noise
///    gradient, smoothly cycling through 11 distinct flower species:
///    dandelion, poppy, allium, azure bluet, red tulip, orange tulip,
///    white tulip, pink tulip, oxeye daisy, cornflower, and lily of the valley.
///
/// 4. Meadow & Flower Forest Bee Nest Rule:
///    Every Oak or Birch tree generated or grown in a Meadow biome has a 100%
///    guaranteed chance (1.0) to generate with a bee nest containing 2..3 bees.
///    In Flower Forest and Plains biomes, trees generate nests with a high 5% chance.
/// ============================================================================

// ============================================================================
// 1. Cardinal Directions & Sunflower Heliotropism
// ============================================================================

/// Cardinal and vertical facings for directional blocks.
pub const Direction = enum(u3) {
    north = 0,
    south = 1,
    west = 2,
    east = 3,
    up = 4,
    down = 5,

    pub fn toVector(self: Direction) [3]i32 {
        return switch (self) {
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .west => .{ -1, 0, 0 },
            .east => .{ 1, 0, 0 }, // +X sunrise direction
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
        };
    }

    pub fn isEast(self: Direction) bool {
        return self == .east;
    }

    pub fn isHorizontal(self: Direction) bool {
        return switch (self) {
            .north, .south, .west, .east => true,
            .up, .down => false,
        };
    }
};

pub const Facing = Direction;

/// Tall plants consist of two block halves stacked vertically.
pub const TallPlantHalf = enum(u1) {
    lower = 0,
    upper = 1,
};

/// Sunflower heliotropism constants and mechanics.
pub const SunflowerHeliotropism = struct {
    pub const facing: Direction = .east;
    pub const normal_vector: [3]i32 = .{ 1, 0, 0 };
    pub const height: u8 = 2;

    /// The upper head block ALWAYS faces east (+X sunrise direction).
    pub fn sunflowerFacingDirection() Direction {
        return .east;
    }

    /// Provides an unbreakable natural compass in the Overworld.
    pub fn canOrientPlayerEast() bool {
        return true;
    }

    /// Sunflower orientation is fixed regardless of player placement facing.
    pub fn facingFromPlacement(player_look: Direction) Direction {
        _ = player_look;
        return .east;
    }

    /// Sunflower orientation remains east at any time of day (morning, noon, sunset, night).
    pub fn facingAtTime(world_ticks: u32) Direction {
        _ = world_ticks;
        return .east;
    }

    /// Returns the unit vector in world space for the head facing (+X).
    pub fn facingVector() [3]i32 {
        return normal_vector;
    }
};

/// Top-level function: returns the direction a sunflower faces (always .east).
pub const sunflowerFacingDirection = SunflowerHeliotropism.sunflowerFacingDirection;

/// Top-level function: confirms sunflowers act as a natural Overworld compass orienting East.
pub const canOrientPlayerEast = SunflowerHeliotropism.canOrientPlayerEast;

/// A placed Sunflower block structure with position and vertical half.
pub const Sunflower = struct {
    x: i32,
    y: i32,
    z: i32,
    half: TallPlantHalf,
    facing: Direction = .east,

    pub fn init(x: i32, y: i32, z: i32, half: TallPlantHalf) Sunflower {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .half = half,
            .facing = .east,
        };
    }

    pub fn getFacing(self: Sunflower) Direction {
        _ = self;
        return .east;
    }

    pub fn isCompassValid(self: Sunflower) bool {
        return self.facing == .east;
    }

    /// Returns true if placed on suitable soil (grass, dirt, podzol, coarse dirt, farmland).
    pub fn isValidSoil(soil_block_id: u16) bool {
        return soil_block_id >= 1 and soil_block_id <= 10;
    }
};

// ============================================================================
// 2. Two-Block Tall Flowers & Bone-Meal Duplication
// ============================================================================

/// Two-block-tall flowers that produce 2 dyes and can be duplicated with bone meal.
pub const TwoBlockTallFlower = enum(u2) {
    sunflower = 0,
    lilac = 1,
    rose_bush = 2,
    peony = 3,

    pub fn dyeColor(self: TwoBlockTallFlower) DyeColor {
        return switch (self) {
            .sunflower => .yellow_dye,
            .lilac => .magenta_dye,
            .rose_bush => .red_dye,
            .peony => .pink_dye,
        };
    }

    pub fn dyeYieldCount(self: TwoBlockTallFlower) u8 {
        _ = self;
        return 2;
    }

    pub fn dyeYield(self: TwoBlockTallFlower) DyeDrop {
        return .{
            .color = self.dyeColor(),
            .count = self.dyeYieldCount(),
        };
    }

    pub fn boneMealDropCount(self: TwoBlockTallFlower) u8 {
        return boneMealTallFlowerDropCount(self);
    }

    pub fn canDuplicate(self: TwoBlockTallFlower) bool {
        _ = self;
        return true;
    }
};

/// Dye color classification.
pub const DyeColor = enum {
    yellow_dye,
    magenta_dye,
    red_dye,
    pink_dye,
    white_dye,
    orange_dye,
    light_blue_dye,
    light_gray_dye,
    gray_dye,
    cyan_dye,
    purple_dye,
    blue_dye,
    brown_dye,
    green_dye,
    black_dye,
};

pub const DyeKind = DyeColor;

pub const DyeDrop = struct {
    color: DyeColor,
    count: u8,
};

/// Returns the dye color and count (2) obtained from crafting a 2-block tall flower.
pub fn dyeYieldForTallFlower(flower: TwoBlockTallFlower) DyeDrop {
    return flower.dyeYield();
}

/// Applying Bone Meal directly to a 2-block-tall flower drops exactly 1 item copy.
pub fn boneMealTallFlowerDropCount(flower: TwoBlockTallFlower) u8 {
    _ = flower;
    return 1;
}

/// Ancient sniffer flowers (pitcher plant, torchflower) cannot be duplicated with bone meal.
pub fn canDuplicateWithBoneMeal(is_ancient_sniffer_flower: bool) bool {
    return !is_ancient_sniffer_flower;
}

/// Ancient sniffer plant species enumeration.
pub const AncientSnifferFlower = enum {
    pitcher_plant,
    torchflower,

    pub fn isAncient(self: AncientSnifferFlower) bool {
        _ = self;
        return true;
    }

    pub fn canDuplicateWithBoneMeal(self: AncientSnifferFlower) bool {
        _ = self;
        return false;
    }
};

/// Helper simulating a renewable tall flower dye farm.
pub const TallFlowerFarm = struct {
    flower: TwoBlockTallFlower,
    bone_meal_used: u32 = 0,
    flowers_harvested: u32 = 0,

    pub fn init(flower: TwoBlockTallFlower) TallFlowerFarm {
        return .{ .flower = flower };
    }

    /// Applies bone meal and collects dropped flower items.
    pub fn applyBoneMeal(self: *TallFlowerFarm, amount: u32) u32 {
        self.bone_meal_used += amount;
        const dropped = amount * boneMealTallFlowerDropCount(self.flower);
        self.flowers_harvested += dropped;
        return dropped;
    }

    /// Computes total dye yield from the harvested flowers (2x multiplier).
    pub fn totalDyeYield(self: TallFlowerFarm) u32 {
        return self.flowers_harvested * @as(u32, self.flower.dyeYieldCount());
    }
};

// ============================================================================
// 3. Flower Forest Positional Gradient
// ============================================================================

/// The 11 distinct flower kinds generated along the Flower Forest positional gradient.
pub const FlowerKind = enum(u4) {
    dandelion = 0,
    poppy = 1,
    allium = 2,
    azure_bluet = 3,
    red_tulip = 4,
    orange_tulip = 5,
    white_tulip = 6,
    pink_tulip = 7,
    oxeye_daisy = 8,
    cornflower = 9,
    lily_of_the_valley = 10,

    pub fn dyeColor(self: FlowerKind) DyeColor {
        return switch (self) {
            .dandelion => .yellow_dye,
            .poppy, .red_tulip => .red_dye,
            .allium => .magenta_dye,
            .azure_bluet, .white_tulip, .oxeye_daisy => .light_gray_dye,
            .orange_tulip => .orange_dye,
            .pink_tulip => .pink_dye,
            .cornflower => .blue_dye,
            .lily_of_the_valley => .white_dye,
        };
    }

    pub fn dyeYieldCount(self: FlowerKind) u8 {
        _ = self;
        return 1;
    }
};

/// Ordered array of the 11 Flower Forest gradient flowers.
pub const flower_forest_flowers = [_]FlowerKind{
    .dandelion,
    .poppy,
    .allium,
    .azure_bluet,
    .red_tulip,
    .orange_tulip,
    .white_tulip,
    .pink_tulip,
    .oxeye_daisy,
    .cornflower,
    .lily_of_the_valley,
};

pub const flower_count: usize = flower_forest_flowers.len;

/// Maps a normalized noise value [0.0, 1.0) into the 11 flower kinds in order.
pub fn flowerForNoiseValue(noise: f32) FlowerKind {
    const clamped = std.math.clamp(noise, 0.0, 0.999999);
    const index = @as(usize, @intFromFloat(@floor(clamped * 11.0)));
    return flower_forest_flowers[index % 11];
}

/// Deterministic 2D coordinate hash for noise grid lattice points.
fn hashCoords(x: i32, z: i32) u32 {
    var h = @as(u32, @bitCast(x)) *% 374761393 +% @as(u32, @bitCast(z)) *% 668265263;
    h = (h ^ (h >> 13)) *% 1274126177;
    return h ^ (h >> 16);
}

/// Normalized float sample [0.0, 1.0) at integer grid coordinates.
fn sampleLattice(gx: i32, gz: i32) f32 {
    const h = hashCoords(gx, gz);
    return @as(f32, @floatFromInt(h & 0xFFFF)) / 65536.0;
}

/// Continuous 2D value noise with quintic smoothstep interpolation.
/// Produces coherent spatial bands that smoothly transition across coordinates.
pub fn flowerGradientNoise(x: i32, z: i32) f32 {
    // 16-block patch wavelength for natural flower forest groupings
    const scale: f32 = 1.0 / 16.0;
    const fx = @as(f32, @floatFromInt(x)) * scale;
    const fz = @as(f32, @floatFromInt(z)) * scale;

    const x0 = @as(i32, @intFromFloat(@floor(fx)));
    const z0 = @as(i32, @intFromFloat(@floor(fz)));
    const tx = fx - @floor(fx);
    const tz = fz - @floor(fz);

    // Quintic Hermite interpolant: 6t^5 - 15t^4 + 10t^3 (smoother derivatives)
    const sx = tx * tx * tx * (tx * (tx * 6.0 - 15.0) + 10.0);
    const sz = tz * tz * tz * (tz * (tz * 6.0 - 15.0) + 10.0);

    const v00 = sampleLattice(x0, z0);
    const v10 = sampleLattice(x0 + 1, z0);
    const v01 = sampleLattice(x0, z0 + 1);
    const v11 = sampleLattice(x0 + 1, z0 + 1);

    const nx0 = v00 * (1.0 - sx) + v10 * sx;
    const nx1 = v01 * (1.0 - sx) + v11 * sx;
    const val = nx0 * (1.0 - sz) + nx1 * sz;

    return std.math.clamp(val, 0.0, 0.999999);
}

/// FlowerForestGradient namespace struct.
pub const FlowerForestGradient = struct {
    pub const flowers = flower_forest_flowers;
    pub const total_flowers: usize = flower_count;

    pub fn flowerForCoordinateGradient(x: i32, z: i32) FlowerKind {
        const noise = flowerGradientNoise(x, z);
        return flowerForNoiseValue(noise);
    }

    pub fn getNoise(x: i32, z: i32) f32 {
        return flowerGradientNoise(x, z);
    }

    pub fn getFlowerForNoise(noise: f32) FlowerKind {
        return flowerForNoiseValue(noise);
    }

    /// Simulates bone-mealing grass at (x, z) in a Flower Forest.
    pub fn bonemealGrass(x: i32, z: i32) FlowerKind {
        return FlowerForestGradient.flowerForCoordinateGradient(x, z);
    }
};

/// Deterministically resolves which flower grows at (x, z) in a Flower Forest biome.
pub const flowerForCoordinateGradient = FlowerForestGradient.flowerForCoordinateGradient;

// ============================================================================
// 4. Meadow & Flower Forest Bee Nest Rule
// ============================================================================

/// World biome categories.
pub const Biome = enum {
    meadow,
    flower_forest,
    sunflower_plains,
    plains,
    forest,
    birch_forest,
    dark_forest,
    swamp,
    desert,
    badlands,
    snowy_plains,
    savanna,
    jungle,
    ocean,
    other,
};

pub const BiomeKind = Biome;

/// Tree species for worldgen and sapling growth.
pub const TreeType = enum {
    oak,
    birch,
    spruce,
    jungle,
    acacia,
    dark_oak,
    cherry,
    pale_oak,
};

pub const TreeSpecies = TreeType;

pub const meadow_bee_nest_chance: f32 = 1.0; // 100% guaranteed in Meadow
pub const flower_forest_bee_nest_chance: f32 = 0.05; // 5% high chance in Flower Forest
pub const plains_bee_nest_chance: f32 = 0.05; // 5% in Plains
pub const sunflower_plains_bee_nest_chance: f32 = 0.05; // 5% in Sunflower Plains
pub const default_tree_bee_nest_chance: f32 = 0.002; // 0.2% in normal Forest

pub const min_nest_bees: u8 = 2;
pub const max_nest_bees: u8 = 3;

/// Only Oak and Birch trees naturally host bee nests upon generation or sapling growth.
pub fn isTreeEligibleForBeeNest(tree: TreeType) bool {
    return tree == .oak or tree == .birch;
}

/// A generated Bee Nest block holding 2..3 initial bees and honey stage 0..5.
pub const BeeNest = struct {
    x: i32,
    y: i32,
    z: i32,
    bee_count: u8,
    honey_level: u8 = 0,

    pub fn init(x: i32, y: i32, z: i32, bees: u8) BeeNest {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .bee_count = std.math.clamp(bees, min_nest_bees, max_nest_bees),
            .honey_level = 0,
        };
    }

    pub fn isFullOfBees(self: BeeNest) bool {
        return self.bee_count >= max_nest_bees;
    }
};

/// MeadowBeeNestRule namespace struct.
pub const MeadowBeeNestRule = struct {
    pub const guaranteed_chance: f32 = meadow_bee_nest_chance;
    pub const high_chance: f32 = flower_forest_bee_nest_chance;
    pub const min_bees: u8 = min_nest_bees;
    pub const max_bees: u8 = max_nest_bees;

    /// Returns the probability (0.0 .. 1.0) of an Oak or Birch tree generating with a bee nest.
    pub fn beeNestChanceForBiome(biome: Biome) f32 {
        return switch (biome) {
            .meadow => meadow_bee_nest_chance,
            .flower_forest => flower_forest_bee_nest_chance,
            .sunflower_plains => sunflower_plains_bee_nest_chance,
            .plains => plains_bee_nest_chance,
            .forest, .birch_forest => default_tree_bee_nest_chance,
            else => 0.0,
        };
    }

    pub fn isBeeNestGuaranteed(biome: Biome) bool {
        return biome == .meadow;
    }

    pub fn isTreeEligible(tree: TreeType) bool {
        return isTreeEligibleForBeeNest(tree);
    }

    pub fn shouldGenerateBeeNest(tree: TreeType, biome: Biome, roll_0_to_1: f32) bool {
        if (!isTreeEligible(tree)) return false;
        const chance = MeadowBeeNestRule.beeNestChanceForBiome(biome);
        if (chance >= 1.0) return true;
        return roll_0_to_1 < chance;
    }

    /// Roll initial bee count: 2 or 3 bees.
    pub fn rollBeeCount(roll_0_to_1: f32) u8 {
        return if (roll_0_to_1 < 0.5) min_bees else max_bees;
    }

    /// Deterministically derive bee count (2 or 3) from coordinates and seed.
    pub fn beeCountFromCoords(seed: u64, x: i32, z: i32) u8 {
        var h = seed ^ (@as(u64, @bitCast(@as(i64, x))) *% 0x517cc1b727220a95);
        h ^= @as(u64, @bitCast(@as(i64, z))) *% 0x9e3779b97f4a7c15;
        h = (h ^ (h >> 30)) *% 0xbf58476d1ce4e5b9;
        return if ((h & 1) == 0) min_bees else max_bees;
    }
};

/// Top-level function: returns the probability (0.0 .. 1.0) of an Oak or Birch tree generating with a bee nest.
pub const beeNestChanceForBiome = MeadowBeeNestRule.beeNestChanceForBiome;

// ============================================================================
// Tests
// ============================================================================

test "1. SunflowerHeliotropism: always faces east (+X) and provides immutable compass" {
    try std.testing.expectEqual(Direction.east, sunflowerFacingDirection());
    try std.testing.expect(canOrientPlayerEast());

    // Verify struct functions match top-level functions
    try std.testing.expectEqual(Direction.east, SunflowerHeliotropism.sunflowerFacingDirection());
    try std.testing.expect(SunflowerHeliotropism.canOrientPlayerEast());

    // Verify direction vector points along +X axis
    const vec = sunflowerFacingDirection().toVector();
    try std.testing.expectEqual(@as(i32, 1), vec[0]); // +X
    try std.testing.expectEqual(@as(i32, 0), vec[1]); // Y
    try std.testing.expectEqual(@as(i32, 0), vec[2]); // Z
    try std.testing.expect(sunflowerFacingDirection().isEast());
}

test "2. SunflowerHeliotropism: orientation is invariant across player placement angles and time" {
    // Player facing directions during placement
    const angles = [_]Direction{ .north, .south, .west, .east, .up, .down };
    for (angles) |look| {
        try std.testing.expectEqual(Direction.east, SunflowerHeliotropism.facingFromPlacement(look));
    }

    // Time of day in world ticks: 0 (sunrise), 6000 (noon), 12000 (sunset), 18000 (midnight)
    const tick_times = [_]u32{ 0, 1000, 6000, 12000, 13000, 18000, 23000 };
    for (tick_times) |t| {
        try std.testing.expectEqual(Direction.east, SunflowerHeliotropism.facingAtTime(t));
    }
}

test "3. SunflowerHeliotropism: two-block tall structural hierarchy and state" {
    const bottom = Sunflower.init(100, 64, -200, .lower);
    const top = Sunflower.init(100, 65, -200, .upper);

    try std.testing.expectEqual(TallPlantHalf.lower, bottom.half);
    try std.testing.expectEqual(TallPlantHalf.upper, top.half);
    try std.testing.expectEqual(Direction.east, bottom.getFacing());
    try std.testing.expectEqual(Direction.east, top.getFacing());
    try std.testing.expect(bottom.isCompassValid());
    try std.testing.expect(top.isCompassValid());

    // Valid soil check
    try std.testing.expect(Sunflower.isValidSoil(1)); // grass
    try std.testing.expect(Sunflower.isValidSoil(2)); // dirt
    try std.testing.expect(!Sunflower.isValidSoil(0)); // air
    try std.testing.expect(!Sunflower.isValidSoil(49)); // obsidian
}

test "4. TwoBlockTallFlower: dye yields match 2x dye for all 4 tall flower varieties" {
    // .sunflower -> yellow_dye x2
    const sun_dye = dyeYieldForTallFlower(.sunflower);
    try std.testing.expectEqual(DyeColor.yellow_dye, sun_dye.color);
    try std.testing.expectEqual(@as(u8, 2), sun_dye.count);

    // .lilac -> magenta_dye x2
    const lilac_dye = dyeYieldForTallFlower(.lilac);
    try std.testing.expectEqual(DyeColor.magenta_dye, lilac_dye.color);
    try std.testing.expectEqual(@as(u8, 2), lilac_dye.count);

    // .rose_bush -> red_dye x2
    const rose_dye = dyeYieldForTallFlower(.rose_bush);
    try std.testing.expectEqual(DyeColor.red_dye, rose_dye.color);
    try std.testing.expectEqual(@as(u8, 2), rose_dye.count);

    // .peony -> pink_dye x2
    const peony_dye = dyeYieldForTallFlower(.peony);
    try std.testing.expectEqual(DyeColor.pink_dye, peony_dye.color);
    try std.testing.expectEqual(@as(u8, 2), peony_dye.count);
}

test "5. TwoBlockTallFlower: bone meal application drops exactly 1 tall flower item copy" {
    const flowers = [_]TwoBlockTallFlower{ .sunflower, .lilac, .rose_bush, .peony };
    for (flowers) |f| {
        try std.testing.expectEqual(@as(u8, 1), boneMealTallFlowerDropCount(f));
        try std.testing.expectEqual(@as(u8, 1), f.boneMealDropCount());
        try std.testing.expect(f.canDuplicate());
    }
}

test "6. TwoBlockTallFlower: ancient sniffer flowers cannot be duplicated with bone meal" {
    // Required exact boolean signature: canDuplicateWithBoneMeal(is_ancient_sniffer_flower: bool)
    try std.testing.expectEqual(false, canDuplicateWithBoneMeal(true));
    try std.testing.expectEqual(true, canDuplicateWithBoneMeal(false));

    // Enum checks
    const pitcher = AncientSnifferFlower.pitcher_plant;
    const torch = AncientSnifferFlower.torchflower;
    try std.testing.expect(pitcher.isAncient());
    try std.testing.expect(torch.isAncient());
    try std.testing.expect(!pitcher.canDuplicateWithBoneMeal());
    try std.testing.expect(!torch.canDuplicateWithBoneMeal());
}

test "7. TwoBlockTallFlower: renewable dye farm simulator accumulates drops and dye yields" {
    var farm = TallFlowerFarm.init(.sunflower);
    const drop1 = farm.applyBoneMeal(10);
    try std.testing.expectEqual(@as(u32, 10), drop1);
    try std.testing.expectEqual(@as(u32, 10), farm.bone_meal_used);
    try std.testing.expectEqual(@as(u32, 10), farm.flowers_harvested);
    // 10 flowers * 2 yellow dye = 20 dyes
    try std.testing.expectEqual(@as(u32, 20), farm.totalDyeYield());

    // Additional 15 bone meal
    _ = farm.applyBoneMeal(15);
    try std.testing.expectEqual(@as(u32, 25), farm.flowers_harvested);
    try std.testing.expectEqual(@as(u32, 50), farm.totalDyeYield());

    // Rose bush farm
    var rose_farm = TallFlowerFarm.init(.rose_bush);
    _ = rose_farm.applyBoneMeal(7);
    try std.testing.expectEqual(@as(u32, 14), rose_farm.totalDyeYield());
}

test "8. FlowerForestGradient: noise gradient produces deterministic flower for coordinates" {
    const coords = [_][2]i32{
        .{ 0, 0 },
        .{ 15, 32 },
        .{ -48, 112 },
        .{ 256, -512 },
        .{ -1024, -2048 },
        .{ 77, -13 },
    };

    for (coords) |c| {
        const f1 = flowerForCoordinateGradient(c[0], c[1]);
        const f2 = flowerForCoordinateGradient(c[0], c[1]);
        try std.testing.expectEqual(f1, f2);

        const f_struct = FlowerForestGradient.flowerForCoordinateGradient(c[0], c[1]);
        try std.testing.expectEqual(f1, f_struct);
    }
}

test "9. FlowerForestGradient: flowerForNoiseValue cycles through all 11 flowers in exact order" {
    const expected_sequence = [_]FlowerKind{
        .dandelion,
        .poppy,
        .allium,
        .azure_bluet,
        .red_tulip,
        .orange_tulip,
        .white_tulip,
        .pink_tulip,
        .oxeye_daisy,
        .cornflower,
        .lily_of_the_valley,
    };

    try std.testing.expectEqual(@as(usize, 11), expected_sequence.len);

    var i: usize = 0;
    while (i < 11) : (i += 1) {
        // Sample in the center of interval i / 11.0
        const sample_val = (@as(f32, @floatFromInt(i)) + 0.5) / 11.0;
        const result_flower = flowerForNoiseValue(sample_val);
        try std.testing.expectEqual(expected_sequence[i], result_flower);
    }
}

test "10. FlowerForestGradient: spatial scanning verifies all 11 flower kinds are reachable in world space" {
    var seen_mask: u16 = 0;

    // Scan an area with 4-block stride to sample across gradient cells
    var x: i32 = -128;
    while (x <= 128) : (x += 4) {
        var z: i32 = -128;
        while (z <= 128) : (z += 4) {
            const flower = flowerForCoordinateGradient(x, z);
            const bit = @as(u16, 1) << @intFromEnum(flower);
            seen_mask |= bit;
        }
    }

    // All 11 flower kinds (bits 0..10) must be discovered
    const all_11_mask: u16 = (1 << 11) - 1;
    try std.testing.expectEqual(all_11_mask, seen_mask & all_11_mask);
}

test "11. FlowerForestGradient: single flower dye crafting yields single dye" {
    try std.testing.expectEqual(DyeColor.yellow_dye, FlowerKind.dandelion.dyeColor());
    try std.testing.expectEqual(DyeColor.red_dye, FlowerKind.poppy.dyeColor());
    try std.testing.expectEqual(DyeColor.magenta_dye, FlowerKind.allium.dyeColor());
    try std.testing.expectEqual(DyeColor.light_gray_dye, FlowerKind.azure_bluet.dyeColor());
    try std.testing.expectEqual(DyeColor.red_dye, FlowerKind.red_tulip.dyeColor());
    try std.testing.expectEqual(DyeColor.orange_dye, FlowerKind.orange_tulip.dyeColor());
    try std.testing.expectEqual(DyeColor.light_gray_dye, FlowerKind.white_tulip.dyeColor());
    try std.testing.expectEqual(DyeColor.pink_dye, FlowerKind.pink_tulip.dyeColor());
    try std.testing.expectEqual(DyeColor.light_gray_dye, FlowerKind.oxeye_daisy.dyeColor());
    try std.testing.expectEqual(DyeColor.blue_dye, FlowerKind.cornflower.dyeColor());
    try std.testing.expectEqual(DyeColor.white_dye, FlowerKind.lily_of_the_valley.dyeColor());

    for (flower_forest_flowers) |f| {
        try std.testing.expectEqual(@as(u8, 1), f.dyeYieldCount());
    }
}

test "12. MeadowBeeNestRule: meadow tree generation has 100% guaranteed bee nest chance" {
    try std.testing.expectEqual(@as(f32, 1.0), beeNestChanceForBiome(.meadow));
    try std.testing.expect(MeadowBeeNestRule.isBeeNestGuaranteed(.meadow));
    try std.testing.expect(!MeadowBeeNestRule.isBeeNestGuaranteed(.flower_forest));
    try std.testing.expect(!MeadowBeeNestRule.isBeeNestGuaranteed(.plains));

    // Even with roll = 0.999, Meadow generates a bee nest
    try std.testing.expect(MeadowBeeNestRule.shouldGenerateBeeNest(.oak, .meadow, 0.999));
    try std.testing.expect(MeadowBeeNestRule.shouldGenerateBeeNest(.birch, .meadow, 0.999));
}

test "13. MeadowBeeNestRule: flower forest and plains tree generation has high bee nest chance (5%)" {
    try std.testing.expectEqual(@as(f32, 0.05), beeNestChanceForBiome(.flower_forest));
    try std.testing.expectEqual(@as(f32, 0.05), beeNestChanceForBiome(.plains));
    try std.testing.expectEqual(@as(f32, 0.05), beeNestChanceForBiome(.sunflower_plains));
    try std.testing.expectEqual(@as(f32, 0.002), beeNestChanceForBiome(.forest));
    try std.testing.expectEqual(@as(f32, 0.0), beeNestChanceForBiome(.desert));

    // In Flower Forest, roll < 0.05 succeeds, roll >= 0.05 fails
    try std.testing.expect(MeadowBeeNestRule.shouldGenerateBeeNest(.oak, .flower_forest, 0.02));
    try std.testing.expect(!MeadowBeeNestRule.shouldGenerateBeeNest(.oak, .flower_forest, 0.08));
}

test "14. MeadowBeeNestRule: only oak and birch trees can generate bee nests" {
    try std.testing.expect(isTreeEligibleForBeeNest(.oak));
    try std.testing.expect(isTreeEligibleForBeeNest(.birch));

    try std.testing.expect(!isTreeEligibleForBeeNest(.spruce));
    try std.testing.expect(!isTreeEligibleForBeeNest(.jungle));
    try std.testing.expect(!isTreeEligibleForBeeNest(.acacia));
    try std.testing.expect(!isTreeEligibleForBeeNest(.dark_oak));
    try std.testing.expect(!isTreeEligibleForBeeNest(.cherry));
    try std.testing.expect(!isTreeEligibleForBeeNest(.pale_oak));

    // In Meadow, non-eligible tree never generates nest
    try std.testing.expect(!MeadowBeeNestRule.shouldGenerateBeeNest(.spruce, .meadow, 0.0));
    try std.testing.expect(!MeadowBeeNestRule.shouldGenerateBeeNest(.acacia, .meadow, 0.0));
}

test "15. MeadowBeeNestRule: bee nest initializes with 2..3 bees" {
    const nest_2 = BeeNest.init(10, 68, -40, 2);
    try std.testing.expectEqual(@as(u8, 2), nest_2.bee_count);
    try std.testing.expect(!nest_2.isFullOfBees());

    const nest_3 = BeeNest.init(10, 68, -40, 3);
    try std.testing.expectEqual(@as(u8, 3), nest_3.bee_count);
    try std.testing.expect(nest_3.isFullOfBees());

    // Out of range values are clamped to 2..3
    const nest_under = BeeNest.init(0, 0, 0, 1);
    try std.testing.expectEqual(@as(u8, 2), nest_under.bee_count);

    const nest_over = BeeNest.init(0, 0, 0, 5);
    try std.testing.expectEqual(@as(u8, 3), nest_over.bee_count);

    // Roll helper
    try std.testing.expectEqual(@as(u8, 2), MeadowBeeNestRule.rollBeeCount(0.1));
    try std.testing.expectEqual(@as(u8, 3), MeadowBeeNestRule.rollBeeCount(0.9));

    // Deterministic coord hash always returns 2 or 3
    const c1 = MeadowBeeNestRule.beeCountFromCoords(12345, 10, 20);
    const c2 = MeadowBeeNestRule.beeCountFromCoords(12345, 11, 20);
    try std.testing.expect(c1 >= 2 and c1 <= 3);
    try std.testing.expect(c2 >= 2 and c2 <= 3);
}

test "16. MeadowBeeNestRule: simulated worldgen tree placement across biomes" {
    // In Meadow, 100 oak trees should all have nests
    var meadow_nests: usize = 0;
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const roll = @as(f32, @floatFromInt(i)) / 100.0;
        if (MeadowBeeNestRule.shouldGenerateBeeNest(.oak, .meadow, roll)) {
            meadow_nests += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 100), meadow_nests);

    // In Flower Forest, exactly 5 out of 100 uniform rolls are < 0.05
    var ff_nests: usize = 0;
    i = 0;
    while (i < 100) : (i += 1) {
        const roll = @as(f32, @floatFromInt(i)) / 100.0;
        if (MeadowBeeNestRule.shouldGenerateBeeNest(.birch, .flower_forest, roll)) {
            ff_nests += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 5), ff_nests);
}
