const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

// ============================================================================
// 1. Scaffolding Crafting Recipe
// ============================================================================
// 6 bamboo + 1 string -> 6 scaffolding

pub const ScaffoldingRecipe = struct {
    pub const bamboo_cost: u16 = 6;
    pub const string_cost: u16 = 1;
    pub const yield: u16 = 6;

    pub const CraftResult = struct {
        scaffolding: u16,
        bamboo_consumed: u16,
        string_consumed: u16,
        bamboo_remaining: u16,
        string_remaining: u16,
    };

    /// Crafts scaffolding from bamboo and string, returning the number of scaffolding items produced.
    /// 6 bamboo + 1 string -> 6 scaffolding.
    pub fn craftScaffolding(bamboo: u16, string: u16) u16 {
        const batches = @min(bamboo / bamboo_cost, string / string_cost);
        return batches * yield;
    }

    /// Crafts scaffolding and returns a detailed breakdown of consumed and remaining ingredients.
    pub fn craft(bamboo: u16, string: u16) CraftResult {
        const batches = @min(bamboo / bamboo_cost, string / string_cost);
        const scaf = batches * yield;
        const b_used = batches * bamboo_cost;
        const s_used = batches * string_cost;
        return .{
            .scaffolding = scaf,
            .bamboo_consumed = b_used,
            .string_consumed = s_used,
            .bamboo_remaining = bamboo - b_used,
            .string_remaining = string - s_used,
        };
    }

    /// Returns the maximum number of full crafting batches possible with given inventory.
    pub fn maxBatches(bamboo: u16, string: u16) u16 {
        return @min(bamboo / bamboo_cost, string / string_cost);
    }
};

/// Free function for crafting scaffolding: 6 bamboo + 1 string -> 6 scaffolding.
pub fn craftScaffolding(bamboo: u16, string: u16) u16 {
    return ScaffoldingRecipe.craftScaffolding(bamboo, string);
}

// ============================================================================
// 2. Scaffolding Cantilever Mechanics
// ============================================================================
// Horizontal distance tracking: 0 when vertically supported, +1 per horizontal step.
// Max horizontal cantilever: 6 blocks. Beyond distance 6 (7th block), it falls.

pub const ScaffoldingCantilever = struct {
    /// Maximum number of scaffolding blocks that can extend horizontally from support.
    pub const max_horizontal_cantilever: u3 = 6;
    /// Distance threshold at and above which scaffolding detaches and falls.
    pub const detachment_distance: u8 = 7;

    /// Distance from the nearest vertically supported column (0 = directly supported).
    horizontal_distance_from_support: u3 = 0,
    /// Whether this block has vertical support directly underneath.
    is_bottom_supported: bool = false,

    pub fn init(distance: u3, bottom_supported: bool) ScaffoldingCantilever {
        return .{
            .horizontal_distance_from_support = distance,
            .is_bottom_supported = bottom_supported,
        };
    }

    /// Determines if a scaffolding block at the given distance from support should fall.
    /// Up to 6 blocks can extend horizontally; a 7th block placed beyond distance 6 detaches and falls.
    pub fn shouldScaffoldingFall(distance_from_support: u8) bool {
        return distance_from_support > max_horizontal_cantilever;
    }

    /// Returns true if the given distance is within the stable cantilever range (0..6).
    pub fn isSupported(distance_from_support: u8) bool {
        return distance_from_support <= max_horizontal_cantilever;
    }

    /// Computes the resulting distance from support given vertical support and adjacent neighbor distance.
    pub fn calculateDistance(has_vertical_support: bool, min_neighbor_distance: ?u8) u8 {
        if (has_vertical_support) return 0;
        if (min_neighbor_distance) |neighbor_dist| {
            if (neighbor_dist < 7) {
                return neighbor_dist + 1;
            }
        }
        return 7;
    }

    pub const PlacementAction = enum {
        place_stable,
        detach_and_fall,
    };

    pub const PlacementOutcome = struct {
        action: PlacementAction,
        distance: u8,
    };

    /// Evaluates placement of a new scaffolding block.
    pub fn evaluatePlacement(has_vertical_support: bool, min_neighbor_distance: ?u8) PlacementOutcome {
        const dist = calculateDistance(has_vertical_support, min_neighbor_distance);
        if (ScaffoldingCantilever.shouldScaffoldingFall(dist)) {
            return .{
                .action = .detach_and_fall,
                .distance = dist,
            };
        } else {
            return .{
                .action = .place_stable,
                .distance = dist,
            };
        }
    }
};

/// Free function to check if scaffolding should fall at the given horizontal distance.
pub fn shouldScaffoldingFall(distance_from_support: u8) bool {
    return ScaffoldingCantilever.shouldScaffoldingFall(distance_from_support);
}

/// Dynamic entity representing an unsupported scaffolding block falling under gravity.
pub const FallingScaffolding = struct {
    x: i32,
    y: f32,
    z: i32,
    velocity_y: f32 = 0.0,
    distance_from_support: u8 = 7,
    ticks_falling: u32 = 0,
    is_falling: bool = true,

    pub const gravity: f32 = 9.81; // Acceleration in m/s²
    pub const terminal_velocity: f32 = 39.2; // Max fall speed in m/s

    pub fn tick(self: *FallingScaffolding, dt: f32) void {
        if (!self.is_falling) return;
        self.velocity_y = @max(-terminal_velocity, self.velocity_y - gravity * dt);
        self.y += self.velocity_y * dt;
        self.ticks_falling += 1;
    }

    pub fn checkLanding(self: *FallingScaffolding, ground_y: f32) bool {
        if (self.y <= ground_y) {
            self.y = ground_y;
            self.velocity_y = 0.0;
            self.is_falling = false;
            return true;
        }
        return false;
    }
};

// ============================================================================
// 3. Scaffolding Tower Cascade & Base Stacking
// ============================================================================
// Breaking base collapses entire connected column/cantilever above it.
// Right clicking base stacks block onto the very top of the column.

pub const ScaffoldingTowerCascade = struct {
    /// Computes the total item drop count when breaking the bottom of a scaffolding tower.
    /// The entire tower and all attached cantilever blocks collapse into item drops.
    pub fn computeCascadeDropCount(tower_height: u16, attached_cantilever_blocks: u16) u16 {
        const total = @as(u32, tower_height) + @as(u32, attached_cantilever_blocks);
        return @intCast(@min(total, std.math.maxInt(u16)));
    }

    /// Computes the target Y level when right-clicking the base of a scaffolding column.
    /// Stacks the new scaffolding block onto the very top of the column.
    /// Returns null if the target position would exceed world max build height.
    pub fn targetPlacementYForColumn(base_y: i32, current_column_height: u16, max_build_y: i32) ?i32 {
        const height_i32: i32 = @intCast(current_column_height);
        const target_y, const overflow = @addWithOverflow(base_y, height_i32);
        if (overflow != 0) return null;
        if (target_y <= max_build_y) return target_y;
        return null;
    }

    /// State representation of a vertical scaffolding tower with optional attached cantilevers.
    pub const Tower = struct {
        base_x: i32,
        base_y: i32,
        base_z: i32,
        height: u16,
        attached_cantilevers: u16 = 0,

        pub fn init(x: i32, y: i32, z: i32, initial_height: u16) Tower {
            return .{
                .base_x = x,
                .base_y = y,
                .base_z = z,
                .height = initial_height,
                .attached_cantilevers = 0,
            };
        }

        /// Stacks a new block onto the top of the column by interacting with the base block.
        pub fn stack(self: *Tower, max_build_y: i32) ?i32 {
            if (ScaffoldingTowerCascade.targetPlacementYForColumn(self.base_y, self.height, max_build_y)) |target_y| {
                self.height += 1;
                return target_y;
            }
            return null;
        }

        /// Attaches cantilever blocks to this tower.
        pub fn attachCantilevers(self: *Tower, count: u16) void {
            self.attached_cantilevers = @intCast(@min(
                @as(u32, self.attached_cantilevers) + count,
                std.math.maxInt(u16),
            ));
        }

        /// Breaks the bottom-most supporting block, triggering a cascade collapse.
        /// Returns total items dropped and resets the tower.
        pub fn breakBottom(self: *Tower) u16 {
            const drops = ScaffoldingTowerCascade.computeCascadeDropCount(self.height, self.attached_cantilevers);
            self.height = 0;
            self.attached_cantilevers = 0;
            return drops;
        }
    };
};

/// Free function to compute the total cascade drop count.
pub fn computeCascadeDropCount(tower_height: u16, attached_cantilever_blocks: u16) u16 {
    return ScaffoldingTowerCascade.computeCascadeDropCount(tower_height, attached_cantilever_blocks);
}

/// Free function to calculate target Y level for stacking from the column base.
pub fn targetPlacementYForColumn(base_y: i32, current_column_height: u16, max_build_y: i32) ?i32 {
    return ScaffoldingTowerCascade.targetPlacementYForColumn(base_y, current_column_height, max_build_y);
}

// ============================================================================
// 4. Scaffolding Elevator Kinematics
// ============================================================================
// Inside: Jump ascends at +3.0 m/s; Sneak descends at -3.0 m/s.
// On top: Sneak descends through platform at -3.0 m/s; releasing keys rests at 0.0 m/s without fall damage.

pub const ScaffoldingElevatorKinematics = struct {
    pub const climb_speed: f32 = 3.0; // +3.0 m/s ascent
    pub const descend_speed: f32 = -3.0; // -3.0 m/s descent
    pub const rest_speed: f32 = 0.0; // 0.0 m/s resting on top platform

    pub const PositionMode = enum {
        inside,
        standing_on_top,
        outside,
    };

    pub const MovementInput = struct {
        jump: bool = false,
        sneak: bool = false,
    };

    /// Computes the vertical velocity for an entity based on its spatial relation to scaffolding and control inputs.
    pub fn computeVerticalVelocity(mode: PositionMode, jump: bool, sneak: bool) f32 {
        switch (mode) {
            .inside => {
                if (jump and !sneak) return climb_speed;
                if (sneak and !jump) return descend_speed;
                return rest_speed;
            },
            .standing_on_top => {
                if (sneak) return descend_speed; // descends through the top platform
                if (jump) return climb_speed;
                return rest_speed; // rests on top face without falling through
            },
            .outside => {
                return 0.0;
            },
        }
    }

    /// Overload taking boolean flags for convenience.
    pub fn computeVelocity(inside: bool, on_top: bool, jump: bool, sneak: bool) f32 {
        if (inside) {
            return computeVerticalVelocity(.inside, jump, sneak);
        } else if (on_top) {
            return computeVerticalVelocity(.standing_on_top, jump, sneak);
        }
        return 0.0;
    }

    /// Scaffolding absorbs fall impact completely; landing on scaffolding deals 0 damage regardless of height.
    pub fn calculateFallDamage(fall_distance: f32, lands_on_scaffolding: bool) f32 {
        if (lands_on_scaffolding) return 0.0;
        if (fall_distance <= 3.0) return 0.0;
        return fall_distance - 3.0;
    }

    /// Returns true if the entity is protected from fall damage by scaffolding.
    pub fn hasFallDamageImmunity(lands_on_scaffolding: bool) bool {
        return lands_on_scaffolding;
    }
};

/// Free function for calculating scaffolding elevator vertical velocity.
pub fn computeElevatorVelocity(inside: bool, on_top: bool, jump: bool, sneak: bool) f32 {
    return ScaffoldingElevatorKinematics.computeVelocity(inside, on_top, jump, sneak);
}

/// Free function for computing fall damage with scaffolding landing protection.
pub fn calculateFallDamage(fall_distance: f32, lands_on_scaffolding: bool) f32 {
    return ScaffoldingElevatorKinematics.calculateFallDamage(fall_distance, lands_on_scaffolding);
}

// ============================================================================
// 5. Bamboo Shoot Growth Mechanics
// ============================================================================
// Plantable on grass/dirt/sand/gravel/podzol/mud.
// Starts as non-solid bamboo_shoot, thickens into solid bamboo stalk (max_height: 12..16).
// Breaks instantly with a Sword (isInstantMineWithSword() == true).
// Smelts 0.25 items per bamboo (4 bamboo per smelted item).

pub const BambooShootGrowth = struct {
    pub const min_max_height: u8 = 12;
    pub const max_max_height: u8 = 16;
    pub const items_smelted_per_bamboo: f32 = 0.25;
    pub const bamboo_per_smelted_item: u16 = 4;
    pub const burn_time_ticks: u32 = 50;
    pub const burn_time_seconds: f32 = 2.5;

    pub const Soil = enum {
        grass,
        dirt,
        sand,
        gravel,
        podzol,
        mud,
        other,

        pub fn isPlantable(self: Soil) bool {
            return switch (self) {
                .grass, .dirt, .sand, .gravel, .podzol, .mud => true,
                .other => false,
            };
        }
    };

    pub const Stage = enum {
        bamboo_shoot,
        bamboo,

        pub fn isSolid(self: Stage) bool {
            return self == .bamboo;
        }
    };

    /// Returns true if the given soil is suitable for planting bamboo.
    pub fn isValidSoil(soil: Soil) bool {
        return soil.isPlantable();
    }

    /// Validates soil name strings: grass, dirt, sand, gravel, podzol, mud.
    pub fn isValidSoilName(name: []const u8) bool {
        const valid = [_][]const u8{ "grass", "dirt", "sand", "gravel", "podzol", "mud" };
        for (valid) |s| {
            if (std.mem.eql(u8, name, s)) return true;
        }
        return false;
    }

    /// Validates BlockId enum soil if applicable.
    pub fn isValidBlockIdSoil(block_id: BlockId) bool {
        return switch (block_id) {
            .grass, .dirt, .sand, .mud => true,
            else => false,
        };
    }

    /// Bamboo breaks instantly when mined with any sword.
    pub fn isInstantMineWithSword() bool {
        return true;
    }

    /// Rolls deterministic maximum height between 12 and 16 inclusive.
    pub fn rollMaxHeight(random_byte: u8) u8 {
        return min_max_height + (random_byte % (max_max_height - min_max_height + 1));
    }

    /// Computes fractional smelted items from bamboo count (0.25 items per bamboo).
    pub fn calculateSmeltYield(bamboo_count: u16) f32 {
        return @as(f32, @floatFromInt(bamboo_count)) * items_smelted_per_bamboo;
    }

    /// Computes the required bamboo count to smelt a given number of items (4 bamboo per item).
    pub fn bambooRequiredForSmelting(items_to_smelt: u16) u16 {
        return items_to_smelt * bamboo_per_smelted_item;
    }

    /// Computes the integer number of full items smelted by given bamboo fuel.
    pub fn itemsSmelted(bamboo_count: u16) u16 {
        return bamboo_count / bamboo_per_smelted_item;
    }
};

/// Free function checking if sword instantly mines bamboo.
pub fn isInstantMineWithSword() bool {
    return BambooShootGrowth.isInstantMineWithSword();
}

/// Simulation entity for growing bamboo from shoot to mature stalk.
pub const BambooPlant = struct {
    soil: BambooShootGrowth.Soil,
    height: u8 = 1,
    max_height: u8,
    stage: BambooShootGrowth.Stage = .bamboo_shoot,

    /// Plants a new bamboo shoot on the specified soil.
    pub fn plant(soil: BambooShootGrowth.Soil, random_byte: u8) ?BambooPlant {
        if (!soil.isPlantable()) return null;
        return .{
            .soil = soil,
            .height = 1,
            .max_height = BambooShootGrowth.rollMaxHeight(random_byte),
            .stage = .bamboo_shoot,
        };
    }

    /// Returns true if the bamboo block at this stage has solid collision.
    /// Non-solid for bamboo_shoot, solid for bamboo stalk.
    pub fn isSolid(self: BambooPlant) bool {
        return self.stage.isSolid();
    }

    /// Checks if this bamboo plant can still grow higher.
    pub fn canGrow(self: BambooPlant) bool {
        return self.height < self.max_height;
    }

    /// Advances growth by one block. Thickens from shoot into solid bamboo stalk at height >= 2.
    pub fn grow(self: *BambooPlant) bool {
        if (self.height >= self.max_height) return false;
        self.height += 1;
        if (self.height >= 2) {
            self.stage = .bamboo;
        }
        return true;
    }

    /// Applies bone meal to accelerate bamboo growth by a specified number of blocks up to max_height.
    pub fn applyBoneMeal(self: *BambooPlant, boost_blocks: u8) u8 {
        var grown: u8 = 0;
        var i: u8 = 0;
        while (i < boost_blocks) : (i += 1) {
            if (self.grow()) {
                grown += 1;
            } else break;
        }
        return grown;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "1. ScaffoldingRecipe: exact single batch craft" {
    // 6 bamboo + 1 string -> 6 scaffolding
    try std.testing.expectEqual(@as(u16, 6), craftScaffolding(6, 1));
    try std.testing.expectEqual(@as(u16, 6), ScaffoldingRecipe.craftScaffolding(6, 1));

    const result = ScaffoldingRecipe.craft(6, 1);
    try std.testing.expectEqual(@as(u16, 6), result.scaffolding);
    try std.testing.expectEqual(@as(u16, 6), result.bamboo_consumed);
    try std.testing.expectEqual(@as(u16, 1), result.string_consumed);
    try std.testing.expectEqual(@as(u16, 0), result.bamboo_remaining);
    try std.testing.expectEqual(@as(u16, 0), result.string_remaining);
}

test "2. ScaffoldingRecipe: insufficient ingredients produce nothing" {
    try std.testing.expectEqual(@as(u16, 0), craftScaffolding(5, 1));
    try std.testing.expectEqual(@as(u16, 0), craftScaffolding(6, 0));
    try std.testing.expectEqual(@as(u16, 0), craftScaffolding(0, 0));

    const result = ScaffoldingRecipe.craft(5, 1);
    try std.testing.expectEqual(@as(u16, 0), result.scaffolding);
    try std.testing.expectEqual(@as(u16, 0), result.bamboo_consumed);
    try std.testing.expectEqual(@as(u16, 0), result.string_consumed);
    try std.testing.expectEqual(@as(u16, 5), result.bamboo_remaining);
    try std.testing.expectEqual(@as(u16, 1), result.string_remaining);
}

test "3. ScaffoldingRecipe: multiple batches and remainder handling" {
    // 20 bamboo + 5 string -> 3 batches = 18 scaffolding, consuming 18 bamboo + 3 string, leaving 2 bamboo + 2 string
    try std.testing.expectEqual(@as(u16, 18), craftScaffolding(20, 5));
    try std.testing.expectEqual(@as(u16, 3), ScaffoldingRecipe.maxBatches(20, 5));

    const res = ScaffoldingRecipe.craft(20, 5);
    try std.testing.expectEqual(@as(u16, 18), res.scaffolding);
    try std.testing.expectEqual(@as(u16, 18), res.bamboo_consumed);
    try std.testing.expectEqual(@as(u16, 3), res.string_consumed);
    try std.testing.expectEqual(@as(u16, 2), res.bamboo_remaining);
    try std.testing.expectEqual(@as(u16, 2), res.string_remaining);
}

test "4. ScaffoldingCantilever: max horizontal cantilever limit constant is 6" {
    try std.testing.expectEqual(@as(u3, 6), ScaffoldingCantilever.max_horizontal_cantilever);
    try std.testing.expectEqual(@as(u8, 7), ScaffoldingCantilever.detachment_distance);
}

test "5. ScaffoldingCantilever: shouldScaffoldingFall boundary evaluations" {
    // Supported within 0..6
    try std.testing.expect(!shouldScaffoldingFall(0));
    try std.testing.expect(!shouldScaffoldingFall(1));
    try std.testing.expect(!shouldScaffoldingFall(5));
    try std.testing.expect(!shouldScaffoldingFall(6));

    // Detaches and falls at distance 7 and above
    try std.testing.expect(shouldScaffoldingFall(7));
    try std.testing.expect(shouldScaffoldingFall(8));
    try std.testing.expect(shouldScaffoldingFall(255));

    // ScaffoldingCantilever method calls
    try std.testing.expect(ScaffoldingCantilever.isSupported(6));
    try std.testing.expect(!ScaffoldingCantilever.isSupported(7));
}

test "6. ScaffoldingCantilever: distance propagation and placement evaluation" {
    // Vertically supported directly -> distance 0
    try std.testing.expectEqual(@as(u8, 0), ScaffoldingCantilever.calculateDistance(true, null));
    try std.testing.expectEqual(@as(u8, 0), ScaffoldingCantilever.calculateDistance(true, 4));

    // Horizontal propagation from neighbor
    try std.testing.expectEqual(@as(u8, 1), ScaffoldingCantilever.calculateDistance(false, 0));
    try std.testing.expectEqual(@as(u8, 6), ScaffoldingCantilever.calculateDistance(false, 5));
    try std.testing.expectEqual(@as(u8, 7), ScaffoldingCantilever.calculateDistance(false, 6));

    // Unsupported (no neighbors, no bottom support)
    try std.testing.expectEqual(@as(u8, 7), ScaffoldingCantilever.calculateDistance(false, null));

    // Placement outcome checks
    const outcome_stable = ScaffoldingCantilever.evaluatePlacement(false, 2);
    try std.testing.expectEqual(ScaffoldingCantilever.PlacementAction.place_stable, outcome_stable.action);
    try std.testing.expectEqual(@as(u8, 3), outcome_stable.distance);

    const outcome_fall = ScaffoldingCantilever.evaluatePlacement(false, 6);
    try std.testing.expectEqual(ScaffoldingCantilever.PlacementAction.detach_and_fall, outcome_fall.action);
    try std.testing.expectEqual(@as(u8, 7), outcome_fall.distance);
}

test "7. ScaffoldingCantilever: falling block physics simulation" {
    var falling = FallingScaffolding{
        .x = 10,
        .y = 20.0,
        .z = 15,
        .velocity_y = 0.0,
    };

    // Step physics with 0.1s delta
    falling.tick(0.1);
    try std.testing.expect(falling.velocity_y < 0.0);
    try std.testing.expect(falling.y < 20.0);
    try std.testing.expect(falling.is_falling);

    // Simulate landing on ground at y=5.0
    falling.y = 4.8;
    const landed = falling.checkLanding(5.0);
    try std.testing.expect(landed);
    try std.testing.expectEqual(@as(f32, 5.0), falling.y);
    try std.testing.expectEqual(@as(f32, 0.0), falling.velocity_y);
    try std.testing.expect(!falling.is_falling);
}

test "8. ScaffoldingTowerCascade: computeCascadeDropCount arithmetic and safety" {
    // 1 block tower with 0 cantilevers -> 1 drop
    try std.testing.expectEqual(@as(u16, 1), computeCascadeDropCount(1, 0));
    // 20 block tower with 12 attached cantilevers -> 32 drops
    try std.testing.expectEqual(@as(u16, 32), computeCascadeDropCount(20, 12));
    // 0 height -> 0 drops
    try std.testing.expectEqual(@as(u16, 0), computeCascadeDropCount(0, 0));
    // Near maximum u16 overflow saturation
    try std.testing.expectEqual(@as(u16, 65535), computeCascadeDropCount(65530, 100));
}

test "9. ScaffoldingTowerCascade: targetPlacementYForColumn stacking calculations" {
    // Base at 64, current height 0 -> place at 64
    try std.testing.expectEqual(@as(?i32, 64), targetPlacementYForColumn(64, 0, 319));
    // Base at 64, current height 10 -> place at 74
    try std.testing.expectEqual(@as(?i32, 74), targetPlacementYForColumn(64, 10, 319));
    // Exact ceiling at 319
    try std.testing.expectEqual(@as(?i32, 319), targetPlacementYForColumn(300, 19, 319));
    // Beyond ceiling at 320 -> null
    try std.testing.expectEqual(@as(?i32, null), targetPlacementYForColumn(300, 20, 319));
    // Integer overflow protection
    try std.testing.expectEqual(@as(?i32, null), targetPlacementYForColumn(std.math.maxInt(i32), 1, std.math.maxInt(i32)));
}

test "10. ScaffoldingTowerCascade: complete tower stacking and base collapse simulation" {
    var tower = ScaffoldingTowerCascade.Tower.init(100, 64, 200, 5);

    // Initial state: height 5, base at 64
    try std.testing.expectEqual(@as(u16, 5), tower.height);

    // Stacking from base
    const placed_y = tower.stack(319);
    try std.testing.expectEqual(@as(?i32, 69), placed_y);
    try std.testing.expectEqual(@as(u16, 6), tower.height);

    // Attach 4 cantilever blocks
    tower.attachCantilevers(4);
    try std.testing.expectEqual(@as(u16, 4), tower.attached_cantilevers);

    // Break base -> entire column (6) + attached cantilevers (4) cascade collapse -> 10 drops
    const drops = tower.breakBottom();
    try std.testing.expectEqual(@as(u16, 10), drops);
    try std.testing.expectEqual(@as(u16, 0), tower.height);
    try std.testing.expectEqual(@as(u16, 0), tower.attached_cantilevers);
}

test "11. ScaffoldingElevatorKinematics: ascent and descent inside scaffolding" {
    // Jump ascends at +3.0 m/s
    const v_ascend = ScaffoldingElevatorKinematics.computeVerticalVelocity(.inside, true, false);
    try std.testing.expectEqual(@as(f32, 3.0), v_ascend);

    // Sneak descends at -3.0 m/s
    const v_descend = ScaffoldingElevatorKinematics.computeVerticalVelocity(.inside, false, true);
    try std.testing.expectEqual(@as(f32, -3.0), v_descend);

    // No input inside scaffolding rests at 0.0 m/s
    const v_rest = ScaffoldingElevatorKinematics.computeVerticalVelocity(.inside, false, false);
    try std.testing.expectEqual(@as(f32, 0.0), v_rest);

    // Both jump and sneak pressed cancels out to 0.0 m/s
    const v_cancel = ScaffoldingElevatorKinematics.computeVerticalVelocity(.inside, true, true);
    try std.testing.expectEqual(@as(f32, 0.0), v_cancel);
}

test "12. ScaffoldingElevatorKinematics: standing on top and sneak-descend through platform" {
    // Standing on top with no keys pressed rests on top face at 0.0 m/s
    const v_rest_top = ScaffoldingElevatorKinematics.computeVerticalVelocity(.standing_on_top, false, false);
    try std.testing.expectEqual(@as(f32, 0.0), v_rest_top);

    // Holding sneak descends through the top platform at -3.0 m/s
    const v_sneak_descend = ScaffoldingElevatorKinematics.computeVerticalVelocity(.standing_on_top, false, true);
    try std.testing.expectEqual(@as(f32, -3.0), v_sneak_descend);

    // Holding jump jumps/ascends off the top
    const v_jump_top = ScaffoldingElevatorKinematics.computeVerticalVelocity(.standing_on_top, true, false);
    try std.testing.expectEqual(@as(f32, 3.0), v_jump_top);

    // Convenience function check
    try std.testing.expectEqual(@as(f32, -3.0), computeElevatorVelocity(false, true, false, true));
    try std.testing.expectEqual(@as(f32, 3.0), computeElevatorVelocity(true, false, true, false));
}

test "13. ScaffoldingElevatorKinematics: fall damage absorption" {
    // Falling from 100 blocks onto scaffolding deals 0 damage
    try std.testing.expectEqual(@as(f32, 0.0), calculateFallDamage(100.0, true));
    try std.testing.expectEqual(@as(f32, 0.0), calculateFallDamage(10.0, true));
    try std.testing.expect(ScaffoldingElevatorKinematics.hasFallDamageImmunity(true));

    // Falling onto standard ground: 3 blocks is safe, 4 blocks deals 1 damage, 10 blocks deals 7 damage
    try std.testing.expectEqual(@as(f32, 0.0), calculateFallDamage(3.0, false));
    try std.testing.expectEqual(@as(f32, 1.0), calculateFallDamage(4.0, false));
    try std.testing.expectEqual(@as(f32, 7.0), calculateFallDamage(10.0, false));
}

test "14. BambooShootGrowth: soil planting compatibility" {
    // Valid soils: grass, dirt, sand, gravel, podzol, mud
    try std.testing.expect(BambooShootGrowth.isValidSoil(.grass));
    try std.testing.expect(BambooShootGrowth.isValidSoil(.dirt));
    try std.testing.expect(BambooShootGrowth.isValidSoil(.sand));
    try std.testing.expect(BambooShootGrowth.isValidSoil(.gravel));
    try std.testing.expect(BambooShootGrowth.isValidSoil(.podzol));
    try std.testing.expect(BambooShootGrowth.isValidSoil(.mud));

    // Invalid soils
    try std.testing.expect(!BambooShootGrowth.isValidSoil(.other));

    // String name checks
    try std.testing.expect(BambooShootGrowth.isValidSoilName("grass"));
    try std.testing.expect(BambooShootGrowth.isValidSoilName("sand"));
    try std.testing.expect(BambooShootGrowth.isValidSoilName("gravel"));
    try std.testing.expect(BambooShootGrowth.isValidSoilName("podzol"));
    try std.testing.expect(BambooShootGrowth.isValidSoilName("mud"));
    try std.testing.expect(!BambooShootGrowth.isValidSoilName("stone"));
    try std.testing.expect(!BambooShootGrowth.isValidSoilName("bedrock"));

    // BlockId checks
    try std.testing.expect(BambooShootGrowth.isValidBlockIdSoil(.grass));
    try std.testing.expect(BambooShootGrowth.isValidBlockIdSoil(.dirt));
    try std.testing.expect(BambooShootGrowth.isValidBlockIdSoil(.sand));
    try std.testing.expect(BambooShootGrowth.isValidBlockIdSoil(.mud));
    try std.testing.expect(!BambooShootGrowth.isValidBlockIdSoil(.stone));
}

test "15. BambooShootGrowth: shoot non-solid to stalk solid transition" {
    // Plant on fertile soil
    var plant = BambooPlant.plant(.grass, 0).?;

    // Starts at height 1 as non-solid bamboo_shoot
    try std.testing.expectEqual(@as(u8, 1), plant.height);
    try std.testing.expectEqual(BambooShootGrowth.Stage.bamboo_shoot, plant.stage);
    try std.testing.expect(!plant.isSolid());

    // Grow to height 2 -> thickens into solid bamboo stalk
    const grew = plant.grow();
    try std.testing.expect(grew);
    try std.testing.expectEqual(@as(u8, 2), plant.height);
    try std.testing.expectEqual(BambooShootGrowth.Stage.bamboo, plant.stage);
    try std.testing.expect(plant.isSolid());

    // Planting on invalid soil fails
    try std.testing.expect(BambooPlant.plant(.other, 0) == null);
}

test "16. BambooShootGrowth: max height range 12..16 and growth bounds" {
    // Verify rollMaxHeight returns values in [12, 16] for all 256 byte inputs
    var b: u16 = 0;
    while (b < 256) : (b += 1) {
        const h = BambooShootGrowth.rollMaxHeight(@intCast(b));
        try std.testing.expect(h >= 12 and h <= 16);
    }

    // Test a plant with max_height 12
    var plant = BambooPlant{
        .soil = .dirt,
        .height = 1,
        .max_height = 12,
        .stage = .bamboo_shoot,
    };

    // Bone meal growth up to 12
    const grown = plant.applyBoneMeal(20);
    try std.testing.expectEqual(@as(u8, 11), grown); // 1 + 11 = 12
    try std.testing.expectEqual(@as(u8, 12), plant.height);
    try std.testing.expect(!plant.canGrow());
    try std.testing.expect(!plant.grow());
}

test "17. BambooShootGrowth: instant mine with sword" {
    try std.testing.expect(isInstantMineWithSword());
    try std.testing.expect(BambooShootGrowth.isInstantMineWithSword());
}

test "18. BambooShootGrowth: smelting fuel value (0.25 items per bamboo, 4 per item)" {
    // 0.25 items smelted per bamboo
    try std.testing.expectEqual(@as(f32, 0.25), BambooShootGrowth.items_smelted_per_bamboo);
    try std.testing.expectEqual(@as(u16, 4), BambooShootGrowth.bamboo_per_smelted_item);
    try std.testing.expectEqual(@as(u32, 50), BambooShootGrowth.burn_time_ticks);
    try std.testing.expectEqual(@as(f32, 2.5), BambooShootGrowth.burn_time_seconds);

    // Yield calculations
    try std.testing.expectEqual(@as(f32, 0.25), BambooShootGrowth.calculateSmeltYield(1));
    try std.testing.expectEqual(@as(f32, 1.0), BambooShootGrowth.calculateSmeltYield(4));
    try std.testing.expectEqual(@as(f32, 2.5), BambooShootGrowth.calculateSmeltYield(10));
    try std.testing.expectEqual(@as(f32, 16.0), BambooShootGrowth.calculateSmeltYield(64));

    // Full integer items smelted
    try std.testing.expectEqual(@as(u16, 0), BambooShootGrowth.itemsSmelted(3));
    try std.testing.expectEqual(@as(u16, 1), BambooShootGrowth.itemsSmelted(4));
    try std.testing.expectEqual(@as(u16, 16), BambooShootGrowth.itemsSmelted(64));

    // Bamboo required for smelting items
    try std.testing.expectEqual(@as(u16, 4), BambooShootGrowth.bambooRequiredForSmelting(1));
    try std.testing.expectEqual(@as(u16, 32), BambooShootGrowth.bambooRequiredForSmelting(8));
    try std.testing.expectEqual(@as(u16, 256), BambooShootGrowth.bambooRequiredForSmelting(64));
}
