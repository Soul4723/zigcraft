const std = @import("std");

// ============================================================================
// Biome Environmental Constants & Registry Tags
// ============================================================================

/// Ambient temperature for standard Savanna and Savanna Plateau biomes.
pub const savanna_temperature: f32 = 1.2;
pub const savanna_plateau_temperature: f32 = 1.1;

/// Downfall (rainfall/humidity) constant for Savanna (arid/dry).
pub const savanna_downfall: f32 = 0.0;

/// Default elevation constants for Savanna Plateau terrain generation.
pub const plateau_base_y: i32 = 68;
pub const plateau_top_y: i32 = 96;
pub const plateau_elevation_step: i32 = plateau_top_y - plateau_base_y; // 28 blocks

/// Minimum vertical clearance required for an Acacia tree to grow.
pub const acacia_min_clearance: u32 = 7;

/// Item and Block tag IDs for future registry integration.
pub const AcaciaLogTag: u16 = 440;
pub const StrippedAcaciaLogTag: u16 = 441;
pub const AcaciaPlanksTag: u16 = 442;
pub const AcaciaLeavesTag: u16 = 443;
pub const AcaciaSaplingTag: u16 = 444;
pub const AcaciaSlabTag: u16 = 445;
pub const AcaciaStairsTag: u16 = 446;
pub const AcaciaDoorTag: u16 = 447;
pub const AcaciaTrapdoorTag: u16 = 448;
pub const AcaciaFenceTag: u16 = 449;
pub const AcaciaFenceGateTag: u16 = 450;
pub const AcaciaButtonTag: u16 = 451;
pub const AcaciaPressurePlateTag: u16 = 452;
pub const AcaciaSignTag: u16 = 453;
pub const AcaciaBoatTag: u16 = 454;
pub const CoarseDirtTag: u16 = 455;
pub const TermiteMoundTag: u16 = 456;
pub const TermiteClayTag: u16 = 457;
pub const OstrichEggTag: u16 = 458;
pub const OstrichFeatherTag: u16 = 459;

// ============================================================================
// Savanna Weather Rule (Rain Suppression & Dry Thunderstorms)
// ============================================================================

pub const SavannaWeatherRule = struct {
    pub const warm_biome_temperature: f32 = 1.2;
    pub const rain_suppressed: bool = true;

    /// In Savanna, rain is suppressed due to high temperature and 0.0 downfall.
    pub fn canRainInSavanna() bool {
        return false;
    }

    /// Evaluates whether rain can fall given temperature and biome downfall.
    pub fn canRain(temperature: f32, downfall: f32) bool {
        if (temperature >= 0.95 or downfall <= 0.0) return false;
        return true;
    }

    /// During a thunderstorm, lightning strikes are permitted even in rainless biomes.
    pub fn lightningAllowedDuringStorm() bool {
        return true;
    }

    /// Whether lightning can strike at a given coordinate during a thunderstorm.
    pub fn canStrikeLightning(is_thunderstorm: bool) bool {
        return is_thunderstorm and SavannaWeatherRule.lightningAllowedDuringStorm();
    }

    /// Savannas never produce snowfall (snow requires temperature < 0.15).
    pub fn canSnow(temperature: f32) bool {
        return temperature < 0.15;
    }
};

pub fn canRainInSavanna() bool {
    return SavannaWeatherRule.canRainInSavanna();
}

pub fn lightningAllowedDuringStorm() bool {
    return SavannaWeatherRule.lightningAllowedDuringStorm();
}

pub const warm_biome_temperature: f32 = SavannaWeatherRule.warm_biome_temperature;

// ============================================================================
// Acacia Wood Family
// ============================================================================

pub const AcaciaWoodItem = enum(u16) {
    acacia_log = AcaciaLogTag,
    stripped_acacia_log = StrippedAcaciaLogTag,
    acacia_planks = AcaciaPlanksTag,
    acacia_leaves = AcaciaLeavesTag,
    acacia_sapling = AcaciaSaplingTag,
    acacia_slab = AcaciaSlabTag,
    acacia_stairs = AcaciaStairsTag,
    acacia_door = AcaciaDoorTag,
    acacia_trapdoor = AcaciaTrapdoorTag,
    acacia_fence = AcaciaFenceTag,
    acacia_fence_gate = AcaciaFenceGateTag,
    acacia_button = AcaciaButtonTag,
    acacia_pressure_plate = AcaciaPressurePlateTag,
    acacia_sign = AcaciaSignTag,
    acacia_boat = AcaciaBoatTag,
};

pub const AcaciaWoodFamily = struct {
    pub const acacia_log = AcaciaWoodItem.acacia_log;
    pub const stripped_acacia_log = AcaciaWoodItem.stripped_acacia_log;
    pub const acacia_planks = AcaciaWoodItem.acacia_planks;
    pub const acacia_sapling = AcaciaWoodItem.acacia_sapling;
    pub const plank_yield_multiplier: u32 = 4;

    /// Strips an acacia log with an axe. Only unstripped logs can be stripped.
    pub fn stripLog(item: AcaciaWoodItem) ?AcaciaWoodItem {
        return if (item == .acacia_log) .stripped_acacia_log else null;
    }

    /// 1 log yields 4 planks.
    pub fn craftPlanks(logs: u32) u32 {
        return logs * plank_yield_multiplier;
    }

    /// 3 planks -> 6 slabs (yields 2 slabs per plank).
    pub fn craftSlabs(planks: u32) struct { slabs: u32, remainder_planks: u32 } {
        const recipes = planks / 3;
        return .{
            .slabs = recipes * 6,
            .remainder_planks = planks % 3,
        };
    }

    /// 6 planks -> 4 stairs.
    pub fn craftStairs(planks: u32) struct { stairs: u32, remainder_planks: u32 } {
        const recipes = planks / 6;
        return .{
            .stairs = recipes * 4,
            .remainder_planks = planks % 6,
        };
    }

    /// 6 planks -> 3 doors.
    pub fn craftDoors(planks: u32) struct { doors: u32, remainder_planks: u32 } {
        const recipes = planks / 6;
        return .{
            .doors = recipes * 3,
            .remainder_planks = planks % 6,
        };
    }

    /// 6 planks -> 2 trapdoors.
    pub fn craftTrapdoors(planks: u32) struct { trapdoors: u32, remainder_planks: u32 } {
        const recipes = planks / 6;
        return .{
            .trapdoors = recipes * 2,
            .remainder_planks = planks % 6,
        };
    }

    /// 4 planks + 2 sticks -> 3 fences.
    pub fn craftFences(planks: u32, sticks: u32) struct { fences: u32, remainder_planks: u32, remainder_sticks: u32 } {
        const batches = @min(planks / 4, sticks / 2);
        return .{
            .fences = batches * 3,
            .remainder_planks = planks - batches * 4,
            .remainder_sticks = sticks - batches * 2,
        };
    }

    /// 2 planks + 4 sticks -> 1 fence gate.
    pub fn craftFenceGate(planks: u32, sticks: u32) struct { gates: u32, remainder_planks: u32, remainder_sticks: u32 } {
        const batches = @min(planks / 2, sticks / 4);
        return .{
            .gates = batches * 1,
            .remainder_planks = planks - batches * 2,
            .remainder_sticks = sticks - batches * 4,
        };
    }

    /// 1 plank -> 1 button.
    pub fn craftButton(planks: u32) u32 {
        return planks;
    }

    /// 2 planks -> 1 pressure plate.
    pub fn craftPressurePlate(planks: u32) struct { plates: u32, remainder_planks: u32 } {
        return .{
            .plates = planks / 2,
            .remainder_planks = planks % 2,
        };
    }

    /// 6 planks + 1 stick -> 3 signs.
    pub fn craftSigns(planks: u32, sticks: u32) struct { signs: u32, remainder_planks: u32, remainder_sticks: u32 } {
        const batches = @min(planks / 6, sticks / 1);
        return .{
            .signs = batches * 3,
            .remainder_planks = planks - batches * 6,
            .remainder_sticks = sticks - batches * 1,
        };
    }

    /// 5 planks -> 1 boat.
    pub fn craftBoat(planks: u32) struct { boats: u32, remainder_planks: u32 } {
        return .{
            .boats = planks / 5,
            .remainder_planks = planks % 5,
        };
    }
};

pub const stripLog = AcaciaWoodFamily.stripLog;
pub const craftPlanks = AcaciaWoodFamily.craftPlanks;

// ============================================================================
// Soil and Coarse Dirt Tilling Mechanics
// ============================================================================

pub const SoilType = enum(u8) {
    coarse_dirt = 0,
    dirt = 1,
    grass_block = 2,
    farmland = 3,
    other = 4,
};

pub const TillResult = struct {
    new_soil: SoilType,
    consumed_durability: bool,
};

pub const CoarseDirtTilling = struct {
    /// Hoe tilling coarse dirt converts it to regular dirt (not farmland directly) on first till.
    /// Tilling regular dirt or grass_block converts it to farmland.
    /// Tilling farmland or other invalid blocks does nothing (returns null).
    pub fn till(soil: SoilType) ?SoilType {
        return switch (soil) {
            .coarse_dirt => .dirt,
            .dirt => .farmland,
            .grass_block => .farmland,
            .farmland, .other => null,
        };
    }

    /// Simulates using a hoe on soil. Returns updated soil and decrements hoe durability by 1.
    pub fn tillWithHoe(soil: SoilType, hoe_durability: *u16) ?TillResult {
        if (hoe_durability.* == 0) return null;
        if (till(soil)) |next_soil| {
            hoe_durability.* -= 1;
            return .{
                .new_soil = next_soil,
                .consumed_durability = true,
            };
        }
        return null;
    }

    /// Crafting recipe for coarse dirt: 2 dirt + 2 gravel -> 4 coarse dirt.
    pub fn craftCoarseDirt(dirt_count: u32, gravel_count: u32) struct {
        coarse_dirt: u32,
        remainder_dirt: u32,
        remainder_gravel: u32,
    } {
        const batches = @min(dirt_count / 2, gravel_count / 2);
        return .{
            .coarse_dirt = batches * 4,
            .remainder_dirt = dirt_count - batches * 2,
            .remainder_gravel = gravel_count - batches * 2,
        };
    }
};

// ============================================================================
// Acacia Tree Growth & Diagonal Canopy Architecture
// ============================================================================

pub const TreeBlockType = enum(u8) {
    acacia_log = 0,
    acacia_leaves = 1,
};

pub const TreePlacement = struct {
    dx: i32,
    dy: i32,
    dz: i32,
    block_type: TreeBlockType,
};

pub const TreeBounds = struct {
    min_x: i32 = 0,
    max_x: i32 = 0,
    min_y: i32 = 0,
    max_y: i32 = 0,
    min_z: i32 = 0,
    max_z: i32 = 0,

    pub fn width(self: TreeBounds) i32 {
        return self.max_x - self.min_x + 1;
    }
    pub fn height(self: TreeBounds) i32 {
        return self.max_y - self.min_y + 1;
    }
    pub fn depth(self: TreeBounds) i32 {
        return self.max_z - self.min_z + 1;
    }
};

pub const TreeGenerationResult = struct {
    count: usize,
    trunk_count: usize,
    leaf_count: usize,
    top_trunk_x: i32,
    top_trunk_y: i32,
    top_trunk_z: i32,
    bounds: TreeBounds,
};

pub const AcaciaTreeConfig = struct {
    trunk_height: u32 = 7,         // total height (min 7)
    bend_start_height: u32 = 3,    // 3..5 blocks
    bend_dx: i32 = 1,              // -1..1
    bend_dz: i32 = 0,              // -1..1
    canopy_radius: u32 = 3,        // 2..3
    branch_fork: bool = false,     // secondary branch fork
    branch_dx: i32 = -1,           // -1..1
    branch_dz: i32 = 1,            // -1..1
    branch_canopy_radius: u32 = 2, // 2..3
};

pub const AcaciaTreeGrowth = struct {
    pub const min_clearance: u32 = acacia_min_clearance; // 7 blocks
    pub const min_bend_start_height: u32 = 3;
    pub const max_bend_start_height: u32 = 5;
    pub const min_canopy_radius: u32 = 2;
    pub const max_canopy_radius: u32 = 3;

    /// Checks if sufficient vertical clearance exists above the planting spot.
    pub fn checkClearance(height_available: u32) bool {
        return height_available >= min_clearance;
    }

    /// Verifies if a given soil block can support an acacia sapling.
    pub fn canPlant(soil: SoilType) bool {
        return soil == .dirt or soil == .grass_block or soil == .coarse_dirt;
    }

    /// Computes the diagonal trunk bend offset from bend_start_height to trunk_height.
    pub fn calculateTrunkBend(bend_start_height: u32, trunk_height: u32, bend_dx: i32, bend_dz: i32) struct {
        bent_blocks: u32,
        total_dx: i32,
        total_dz: i32,
    } {
        if (trunk_height <= bend_start_height) {
            return .{ .bent_blocks = 0, .total_dx = 0, .total_dz = 0 };
        }
        const bent_blocks = trunk_height - bend_start_height;
        return .{
            .bent_blocks = bent_blocks,
            .total_dx = @as(i32, @intCast(bent_blocks)) * bend_dx,
            .total_dz = @as(i32, @intCast(bent_blocks)) * bend_dz,
        };
    }

    /// Updates axis-aligned bounding box for tree placement.
    fn updateBounds(bounds: *TreeBounds, x: i32, y: i32, z: i32) void {
        bounds.min_x = @min(bounds.min_x, x);
        bounds.max_x = @max(bounds.max_x, x);
        bounds.min_y = @min(bounds.min_y, y);
        bounds.max_y = @max(bounds.max_y, y);
        bounds.min_z = @min(bounds.min_z, z);
        bounds.max_z = @max(bounds.max_z, z);
    }

    /// Checks if a position already has a placed block (to prevent duplicate placements).
    fn hasBlock(buffer: []const TreePlacement, count: usize, x: i32, y: i32, z: i32) bool {
        for (buffer[0..count]) |b| {
            if (b.dx == x and b.dy == y and b.dz == z) return true;
        }
        return false;
    }

    /// Generates a flat umbrella leaf canopy centered at (center_x, center_y, center_z).
    /// Flat umbrella shape:
    /// - Main leaf layer at center_y with specified radius (2..3), corners rounded off.
    /// - Top accent layer at center_y + 1 with radius - 1.
    /// - Underside leaf ring at center_y - 1 with radius 1.
    fn generateUmbrellaCanopy(
        buffer: []TreePlacement,
        count: *usize,
        leaf_count: *usize,
        bounds: *TreeBounds,
        center_x: i32,
        center_y: i32,
        center_z: i32,
        radius: u32,
    ) void {
        const rad_i: i32 = @as(i32, @intCast(@min(max_canopy_radius, @max(min_canopy_radius, radius))));

        // 1. Main flat disc layer at center_y
        var rx: i32 = -rad_i;
        while (rx <= rad_i) : (rx += 1) {
            var rz: i32 = -rad_i;
            while (rz <= rad_i) : (rz += 1) {
                // Round off extreme corners to produce umbrella disc
                if (@abs(rx) == @as(u32, @intCast(rad_i)) and @abs(rz) == @as(u32, @intCast(rad_i))) {
                    continue;
                }
                const px = center_x + rx;
                const py = center_y;
                const pz = center_z + rz;

                if (!hasBlock(buffer, count.*, px, py, pz)) {
                    if (count.* < buffer.len) {
                        buffer[count.*] = .{ .dx = px, .dy = py, .dz = pz, .block_type = .acacia_leaves };
                        count.* += 1;
                        leaf_count.* += 1;
                        updateBounds(bounds, px, py, pz);
                    }
                }
            }
        }

        // 2. Top layer at center_y + 1 (radius - 1)
        const top_rad: i32 = rad_i - 1;
        rx = -top_rad;
        while (rx <= top_rad) : (rx += 1) {
            var rz: i32 = -top_rad;
            while (rz <= top_rad) : (rz += 1) {
                if (top_rad > 1 and @abs(rx) == @as(u32, @intCast(top_rad)) and @abs(rz) == @as(u32, @intCast(top_rad))) {
                    continue;
                }
                const px = center_x + rx;
                const py = center_y + 1;
                const pz = center_z + rz;

                if (!hasBlock(buffer, count.*, px, py, pz)) {
                    if (count.* < buffer.len) {
                        buffer[count.*] = .{ .dx = px, .dy = py, .dz = pz, .block_type = .acacia_leaves };
                        count.* += 1;
                        leaf_count.* += 1;
                        updateBounds(bounds, px, py, pz);
                    }
                }
            }
        }

        // 3. Underside ring at center_y - 1
        rx = -1;
        while (rx <= 1) : (rx += 1) {
            var rz: i32 = -1;
            while (rz <= 1) : (rz += 1) {
                if (rx == 0 and rz == 0) continue;
                const px = center_x + rx;
                const py = center_y - 1;
                const pz = center_z + rz;

                if (!hasBlock(buffer, count.*, px, py, pz)) {
                    if (count.* < buffer.len) {
                        buffer[count.*] = .{ .dx = px, .dy = py, .dz = pz, .block_type = .acacia_leaves };
                        count.* += 1;
                        leaf_count.* += 1;
                        updateBounds(bounds, px, py, pz);
                    }
                }
            }
        }
    }

    /// Procedurally generates an acacia tree into the provided buffer according to config.
    pub fn generate(buffer: []TreePlacement, config: AcaciaTreeConfig) ?TreeGenerationResult {
        // Enforce minimum clearance
        if (!checkClearance(config.trunk_height)) return null;

        var count: usize = 0;
        var trunk_count: usize = 0;
        var leaf_count: usize = 0;
        var bounds = TreeBounds{};

        const bend_start = @min(max_bend_start_height, @max(min_bend_start_height, config.bend_start_height));
        const b_dx = @min(@max(config.bend_dx, -1), 1);
        const b_dz = @min(@max(config.bend_dz, -1), 1);

        // 1. Build main trunk with diagonal bend after bend_start
        var cur_x: i32 = 0;
        var cur_z: i32 = 0;
        var top_x: i32 = 0;
        var top_y: i32 = 0;
        var top_z: i32 = 0;

        var y: u32 = 0;
        while (y < config.trunk_height) : (y += 1) {
            if (y >= bend_start) {
                cur_x += b_dx;
                cur_z += b_dz;
            }
            const py: i32 = @as(i32, @intCast(y));
            if (count < buffer.len) {
                buffer[count] = .{ .dx = cur_x, .dy = py, .dz = cur_z, .block_type = .acacia_log };
                count += 1;
                trunk_count += 1;
                updateBounds(&bounds, cur_x, py, cur_z);
                top_x = cur_x;
                top_y = py;
                top_z = cur_z;
            }
        }

        // 2. Generate flat umbrella canopy at top of main trunk
        generateUmbrellaCanopy(
            buffer,
            &count,
            &leaf_count,
            &bounds,
            top_x,
            top_y,
            top_z,
            config.canopy_radius,
        );

        // 3. Optional secondary branch fork
        if (config.branch_fork) {
            var branch_x: i32 = 0;
            var branch_z: i32 = 0;
            // Branch stems from bend_start
            const branch_dx = @min(@max(config.branch_dx, -1), 1);
            const branch_dz = @min(@max(config.branch_dz, -1), 1);

            var by: u32 = bend_start;
            var last_bx: i32 = branch_x;
            var last_by: i32 = @as(i32, @intCast(by));
            var last_bz: i32 = branch_z;

            while (by < config.trunk_height) : (by += 1) {
                branch_x += branch_dx;
                branch_z += branch_dz;
                const pby: i32 = @as(i32, @intCast(by));
                if (!hasBlock(buffer, count, branch_x, pby, branch_z)) {
                    if (count < buffer.len) {
                        buffer[count] = .{ .dx = branch_x, .dy = pby, .dz = branch_z, .block_type = .acacia_log };
                        count += 1;
                        trunk_count += 1;
                        updateBounds(&bounds, branch_x, pby, branch_z);
                        last_bx = branch_x;
                        last_by = pby;
                        last_bz = branch_z;
                    }
                }
            }

            // Secondary umbrella canopy
            generateUmbrellaCanopy(
                buffer,
                &count,
                &leaf_count,
                &bounds,
                last_bx,
                last_by,
                last_bz,
                config.branch_canopy_radius,
            );
        }

        return TreeGenerationResult{
            .count = count,
            .trunk_count = trunk_count,
            .leaf_count = leaf_count,
            .top_trunk_x = top_x,
            .top_trunk_y = top_y,
            .top_trunk_z = top_z,
            .bounds = bounds,
        };
    }
};

// ============================================================================
// Savanna Plateau Generation & Mob Spawning Eligibility
// ============================================================================

pub const SavannaMob = enum(u8) {
    llama = 0,
    armadillo = 1,
    horse = 2,
    ostrich = 3,
};

pub const SavannaPlateauGeneration = struct {
    pub const base_y: i32 = plateau_base_y; // 68
    pub const plateau_y: i32 = plateau_top_y; // 96
    pub const step_height: i32 = plateau_elevation_step; // 28

    /// Flat-topped plateau elevation calculation.
    /// Within plateau_radius, returns plateau_y (96).
    /// Outside plateau_radius + slope_width, returns base_y (68).
    /// Within transition zone, returns stepped cliff elevation.
    pub fn getElevation(
        x: i32,
        z: i32,
        center_x: i32,
        center_z: i32,
        plateau_radius: f32,
        slope_width: f32,
    ) i32 {
        const dx = @as(f32, @floatFromInt(x - center_x));
        const dz = @as(f32, @floatFromInt(z - center_z));
        const dist = @sqrt(dx * dx + dz * dz);

        if (dist <= plateau_radius) {
            return plateau_y;
        } else if (dist >= plateau_radius + slope_width) {
            return base_y;
        } else {
            // Stepped terrace transition
            const t = (dist - plateau_radius) / slope_width; // 0.0 to 1.0
            const steps: f32 = 4.0;
            const stepped_t = @floor(t * steps) / steps;
            const step_drop = @as(i32, @intFromFloat(stepped_t * @as(f32, @floatFromInt(step_height))));
            return plateau_y - step_drop;
        }
    }

    /// Determines whether a location is elevated onto the plateau.
    pub fn isPlateauElevation(y: i32) bool {
        return y >= plateau_y - 2;
    }

    /// Surface block determination:
    /// High plateau top has grass and coarse dirt patches.
    /// Plateau cliffs expose stone/terracotta.
    /// Low plains have savanna grass.
    pub fn getSurfaceBlock(y: i32, is_coarse_patch: bool) SoilType {
        if (y >= plateau_y - 1) {
            return if (is_coarse_patch) .coarse_dirt else .grass_block;
        } else if (y > base_y + 2) {
            return .other; // stone / cliff face
        } else {
            return .grass_block;
        }
    }

    /// Mob spawn eligibility rules for Savanna and Savanna Plateau:
    /// - Llama: Spawns in Savanna Plateau at high elevations (y >= 80), light >= 9, on grass/dirt/coarse dirt.
    pub fn canSpawnLlama(y: i32, soil: SoilType, light_level: u8, is_plateau: bool) bool {
        if (!is_plateau) return false;
        if (y < 80) return false;
        if (light_level < 9) return false;
        return (soil == .grass_block or soil == .dirt or soil == .coarse_dirt);
    }

    /// - Armadillo: Spawns in standard Savanna and Savanna Plateau on grass/dirt/coarse dirt in daylight (light >= 7).
    pub fn canSpawnArmadillo(soil: SoilType, light_level: u8) bool {
        if (light_level < 7) return false;
        return (soil == .grass_block or soil == .dirt or soil == .coarse_dirt);
    }

    /// - Horse: Spawns on grass blocks in open savanna plains and flat plateau tops (light >= 9).
    pub fn canSpawnHorse(soil: SoilType, light_level: u8) bool {
        if (light_level < 9) return false;
        return (soil == .grass_block);
    }

    /// - Ostrich: Savanna native large bird, spawns on grass/dirt/coarse dirt (light >= 8).
    pub fn canSpawnOstrich(soil: SoilType, light_level: u8) bool {
        if (light_level < 8) return false;
        return (soil == .grass_block or soil == .dirt or soil == .coarse_dirt);
    }

    /// Generic spawn checker for savanna fauna.
    pub fn isMobEligible(mob: SavannaMob, y: i32, soil: SoilType, light_level: u8, is_plateau: bool) bool {
        return switch (mob) {
            .llama => canSpawnLlama(y, soil, light_level, is_plateau),
            .armadillo => canSpawnArmadillo(soil, light_level),
            .horse => canSpawnHorse(soil, light_level),
            .ostrich => canSpawnOstrich(soil, light_level),
        };
    }
};

// ============================================================================
// Termite Mound Mechanics (Nest Spire, Wood Degradation & Termite Clay)
// ============================================================================

pub const TermiteMoundBlock = struct {
    dx: i32,
    dy: i32,
    dz: i32,
    is_core: bool,
};

pub const TermiteMound = struct {
    x: i32,
    y: i32,
    z: i32,
    height: u8 = 3,
    termite_count: u8 = 4,
    health: u16 = 20,
    activity_timer: f32 = 0.0,
    infestation_radius: f32 = 4.0,

    /// Ticking logic: simulates termite activity and wood consumption.
    pub fn tick(self: *TermiteMound, dt: f32, nearby_wood: bool) bool {
        self.activity_timer += dt;
        if (self.activity_timer >= 10.0) {
            self.activity_timer -= 10.0;
            if (nearby_wood and self.termite_count < 8) {
                self.termite_count += 1;
            }
            return true;
        }
        return false;
    }

    /// Degrades wood inside termite mound radius into porous dirt or hollow timber.
    pub fn degradeWood(self: *const TermiteMound, distance_to_wood: f32) ?SoilType {
        if (distance_to_wood <= self.infestation_radius) {
            return .dirt;
        }
        return null;
    }

    /// Harvesting termite mound drops termite clay.
    pub fn harvest(self: *TermiteMound, shovel_power: u16) u8 {
        if (self.health == 0) return 0;
        const damage = @min(self.health, shovel_power);
        self.health -= damage;
        return @as(u8, @intCast(@min(damage / 5, 4)));
    }
};

/// Procedurally generates a conical termite mound spire (tapered base to apex).
pub fn generateTermiteMound(buffer: []TermiteMoundBlock, height: u8) usize {
    var count: usize = 0;
    const h = @min(@as(u8, 5), @max(@as(u8, 2), height));

    var y: i32 = 0;
    while (y < h) : (y += 1) {
        // Base is 3x3 plus shape, top levels taper down to single column
        const rad: i32 = if (y == 0) 1 else if (y < h - 1) 1 else 0;

        var dx: i32 = -rad;
        while (dx <= rad) : (dx += 1) {
            var dz: i32 = -rad;
            while (dz <= rad) : (dz += 1) {
                // If rad == 1 and not center row/col on higher tiers, taper off
                if (y > 0 and (@abs(dx) == 1 and @abs(dz) == 1)) continue;

                if (count < buffer.len) {
                    buffer[count] = .{
                        .dx = dx,
                        .dy = y,
                        .dz = dz,
                        .is_core = (dx == 0 and dz == 0),
                    };
                    count += 1;
                }
            }
        }
    }
    return count;
}

// ============================================================================
// Ostrich Mob Mechanics (State Machine, Sprinting & Head-in-Sand Defense)
// ============================================================================

pub const OstrichState = enum(u8) {
    idle = 0,
    wandering = 1,
    sprinting = 2,
    head_in_sand = 3,
    tempted = 4,
    ridden = 5,
};

pub const Ostrich = struct {
    health: f32 = 20.0,
    max_health: f32 = 20.0,
    speed: f32 = 4.5,
    state: OstrichState = .idle,
    head_in_sand_timer: f32 = 0.0,
    egg_lay_timer: f32 = 0.0,
    is_saddled: bool = false,
    has_rider: bool = false,
    love_timer: f32 = 0.0,

    pub const walk_speed: f32 = 4.5;
    pub const sprint_speed: f32 = 9.0;
    pub const ridden_speed: f32 = 10.0;
    pub const head_in_sand_duration: f32 = 4.0;
    pub const egg_lay_interval: f32 = 300.0;

    /// Reacts to threats.
    /// When standing on sand, dirt, or coarse dirt, ostrich buries its head in the sand!
    /// On stone or hard surfaces, it sprints away at high speed!
    pub fn reactToThreat(self: *Ostrich, is_soft_ground: bool) void {
        if (self.has_rider) return; // Rider controls ostrich

        if (is_soft_ground) {
            self.state = .head_in_sand;
            self.head_in_sand_timer = head_in_sand_duration;
            self.speed = 0.0;
        } else {
            self.state = .sprinting;
            self.speed = sprint_speed;
        }
    }

    /// Ticking entity update. Returns true when an egg is laid.
    pub fn tick(self: *Ostrich, dt: f32) bool {
        var laid_egg = false;

        // Egg laying timer
        self.egg_lay_timer += dt;
        if (self.egg_lay_timer >= egg_lay_interval) {
            self.egg_lay_timer -= egg_lay_interval;
            laid_egg = true;
        }

        // Head-in-sand defense timer
        if (self.state == .head_in_sand) {
            self.head_in_sand_timer -= dt;
            if (self.head_in_sand_timer <= 0.0) {
                self.head_in_sand_timer = 0.0;
                self.state = .idle;
                self.speed = walk_speed;
            }
        }

        // Love timer countdown
        if (self.love_timer > 0.0) {
            self.love_timer = @max(0.0, self.love_timer - dt);
        }

        return laid_egg;
    }

    /// Feed seeds to ostrich (wheat, melon, pumpkin).
    pub fn feedSeeds(self: *Ostrich) bool {
        if (self.love_timer > 0.0) return false;
        self.love_timer = 30.0;
        if (self.health < self.max_health) {
            self.health = @min(self.max_health, self.health + 2.0);
        }
        return true;
    }

    /// Equip a saddle onto the ostrich.
    pub fn equipSaddle(self: *Ostrich) bool {
        if (self.is_saddled) return false;
        self.is_saddled = true;
        return true;
    }

    /// Mount the ostrich.
    pub fn mount(self: *Ostrich) bool {
        if (!self.is_saddled or self.has_rider) return false;
        self.has_rider = true;
        self.state = .ridden;
        self.speed = ridden_speed;
        return true;
    }

    /// Dismount the ostrich.
    pub fn dismount(self: *Ostrich) void {
        self.has_rider = false;
        self.state = .idle;
        self.speed = walk_speed;
    }
};

// ============================================================================
// Unit Tests (16 Comprehensive Tests)
// ============================================================================

test "SavannaWeatherRule rain suppression, lightning during storm, and warm temperature" {
    // Rain is suppressed in Savanna
    try std.testing.expect(!canRainInSavanna());
    try std.testing.expect(!SavannaWeatherRule.canRainInSavanna());
    try std.testing.expect(!SavannaWeatherRule.canRain(1.2, 0.0));
    try std.testing.expect(!SavannaWeatherRule.canRain(1.0, 0.5));
    try std.testing.expect(SavannaWeatherRule.canRain(0.7, 0.8));

    // Lightning is allowed during thunderstorms
    try std.testing.expect(lightningAllowedDuringStorm());
    try std.testing.expect(SavannaWeatherRule.lightningAllowedDuringStorm());
    try std.testing.expect(SavannaWeatherRule.canStrikeLightning(true));
    try std.testing.expect(!SavannaWeatherRule.canStrikeLightning(false));

    // Temperature constant is 1.2
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), warm_biome_temperature, 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), SavannaWeatherRule.warm_biome_temperature, 1e-4);

    // Snow is impossible at savanna temperature
    try std.testing.expect(!SavannaWeatherRule.canSnow(warm_biome_temperature));
    try std.testing.expect(SavannaWeatherRule.canSnow(0.0));
}

test "AcaciaWoodFamily log stripping with axe" {
    // Stripping an acacia log produces stripped acacia log
    try std.testing.expectEqual(AcaciaWoodItem.stripped_acacia_log, stripLog(.acacia_log).?);
    try std.testing.expectEqual(AcaciaWoodItem.stripped_acacia_log, AcaciaWoodFamily.stripLog(.acacia_log).?);

    // Stripping already stripped logs or planks returns null
    try std.testing.expectEqual(@as(?AcaciaWoodItem, null), stripLog(.stripped_acacia_log));
    try std.testing.expectEqual(@as(?AcaciaWoodItem, null), stripLog(.acacia_planks));
    try std.testing.expectEqual(@as(?AcaciaWoodItem, null), stripLog(.acacia_leaves));
}

test "AcaciaWoodFamily plank conversion yield (logs * 4) and crafting recipes" {
    // 1 log -> 4 planks
    try std.testing.expectEqual(@as(u32, 4), craftPlanks(1));
    try std.testing.expectEqual(@as(u32, 4), AcaciaWoodFamily.craftPlanks(1));

    // 5 logs -> 20 planks
    try std.testing.expectEqual(@as(u32, 20), craftPlanks(5));

    // 64 logs -> 256 planks
    try std.testing.expectEqual(@as(u32, 256), craftPlanks(64));

    // 0 logs -> 0 planks
    try std.testing.expectEqual(@as(u32, 0), craftPlanks(0));
}

test "AcaciaWoodFamily furniture and redstone crafting (slabs, stairs, fences, gates, doors)" {
    // Slabs: 3 planks -> 6 slabs
    const s1 = AcaciaWoodFamily.craftSlabs(3);
    try std.testing.expectEqual(@as(u32, 6), s1.slabs);
    try std.testing.expectEqual(@as(u32, 0), s1.remainder_planks);

    const s2 = AcaciaWoodFamily.craftSlabs(7);
    try std.testing.expectEqual(@as(u32, 12), s2.slabs);
    try std.testing.expectEqual(@as(u32, 1), s2.remainder_planks);

    // Stairs: 6 planks -> 4 stairs
    const st1 = AcaciaWoodFamily.craftStairs(7);
    try std.testing.expectEqual(@as(u32, 4), st1.stairs);
    try std.testing.expectEqual(@as(u32, 1), st1.remainder_planks);

    // Doors: 6 planks -> 3 doors
    const d1 = AcaciaWoodFamily.craftDoors(12);
    try std.testing.expectEqual(@as(u32, 6), d1.doors);
    try std.testing.expectEqual(@as(u32, 0), d1.remainder_planks);

    // Trapdoors: 6 planks -> 2 trapdoors
    const td1 = AcaciaWoodFamily.craftTrapdoors(6);
    try std.testing.expectEqual(@as(u32, 2), td1.trapdoors);
    try std.testing.expectEqual(@as(u32, 0), td1.remainder_planks);

    // Fences: 4 planks + 2 sticks -> 3 fences
    const f1 = AcaciaWoodFamily.craftFences(4, 2);
    try std.testing.expectEqual(@as(u32, 3), f1.fences);
    try std.testing.expectEqual(@as(u32, 0), f1.remainder_planks);
    try std.testing.expectEqual(@as(u32, 0), f1.remainder_sticks);

    // Fence Gate: 2 planks + 4 sticks -> 1 gate
    const g1 = AcaciaWoodFamily.craftFenceGate(2, 4);
    try std.testing.expectEqual(@as(u32, 1), g1.gates);
    try std.testing.expectEqual(@as(u32, 0), g1.remainder_planks);
    try std.testing.expectEqual(@as(u32, 0), g1.remainder_sticks);

    // Buttons, Pressure Plates, Signs, Boats
    try std.testing.expectEqual(@as(u32, 4), AcaciaWoodFamily.craftButton(4));

    const pp = AcaciaWoodFamily.craftPressurePlate(5);
    try std.testing.expectEqual(@as(u32, 2), pp.plates);
    try std.testing.expectEqual(@as(u32, 1), pp.remainder_planks);

    const signs = AcaciaWoodFamily.craftSigns(6, 1);
    try std.testing.expectEqual(@as(u32, 3), signs.signs);
    try std.testing.expectEqual(@as(u32, 0), signs.remainder_planks);
    try std.testing.expectEqual(@as(u32, 0), signs.remainder_sticks);

    const boat = AcaciaWoodFamily.craftBoat(11);
    try std.testing.expectEqual(@as(u32, 2), boat.boats);
    try std.testing.expectEqual(@as(u32, 1), boat.remainder_planks);
}

test "CoarseDirtTilling two-step tilling progression: coarse dirt -> dirt -> farmland" {
    // First till: coarse dirt converts to regular dirt (NOT farmland directly!)
    const step1 = CoarseDirtTilling.till(.coarse_dirt);
    try std.testing.expectEqual(SoilType.dirt, step1.?);

    // Second till: regular dirt converts to farmland
    const step2 = CoarseDirtTilling.till(.dirt);
    try std.testing.expectEqual(SoilType.farmland, step2.?);

    // Grass block directly converts to farmland
    const grass_till = CoarseDirtTilling.till(.grass_block);
    try std.testing.expectEqual(SoilType.farmland, grass_till.?);

    // Farmland cannot be retilled
    try std.testing.expectEqual(@as(?SoilType, null), CoarseDirtTilling.till(.farmland));

    // Other non-soil blocks cannot be tilled
    try std.testing.expectEqual(@as(?SoilType, null), CoarseDirtTilling.till(.other));
}

test "CoarseDirtTilling hoe durability consumption and invalid soil rejection" {
    var durability: u16 = 10;

    // Tilling coarse dirt consumes 1 durability and yields dirt
    const res1 = CoarseDirtTilling.tillWithHoe(.coarse_dirt, &durability);
    try std.testing.expect(res1 != null);
    try std.testing.expectEqual(SoilType.dirt, res1.?.new_soil);
    try std.testing.expect(res1.?.consumed_durability);
    try std.testing.expectEqual(@as(u16, 9), durability);

    // Tilling dirt consumes 1 durability and yields farmland
    const res2 = CoarseDirtTilling.tillWithHoe(.dirt, &durability);
    try std.testing.expect(res2 != null);
    try std.testing.expectEqual(SoilType.farmland, res2.?.new_soil);
    try std.testing.expectEqual(@as(u16, 8), durability);

    // Tilling stone/other fails and consumes zero durability
    const res3 = CoarseDirtTilling.tillWithHoe(.other, &durability);
    try std.testing.expectEqual(@as(?TillResult, null), res3);
    try std.testing.expectEqual(@as(u16, 8), durability);

    // Broken hoe (durability = 0) cannot till
    var broken_durability: u16 = 0;
    try std.testing.expectEqual(@as(?TillResult, null), CoarseDirtTilling.tillWithHoe(.dirt, &broken_durability));

    // Crafting coarse dirt: 4 dirt + 4 gravel -> 8 coarse dirt
    const craft = CoarseDirtTilling.craftCoarseDirt(4, 4);
    try std.testing.expectEqual(@as(u32, 8), craft.coarse_dirt);
    try std.testing.expectEqual(@as(u32, 0), craft.remainder_dirt);
    try std.testing.expectEqual(@as(u32, 0), craft.remainder_gravel);
}

test "AcaciaTreeGrowth diagonal trunk bend calculation after bend_start_height" {
    // 7 height, bend_start = 3, bend_dx = 1, bend_dz = 0:
    // blocks before bend: 3 (y=0,1,2). Blocks bent: 4 (y=3,4,5,6).
    const b1 = AcaciaTreeGrowth.calculateTrunkBend(3, 7, 1, 0);
    try std.testing.expectEqual(@as(u32, 4), b1.bent_blocks);
    try std.testing.expectEqual(@as(i32, 4), b1.total_dx);
    try std.testing.expectEqual(@as(i32, 0), b1.total_dz);

    // 8 height, bend_start = 4, bend_dx = -1, bend_dz = 1:
    const b2 = AcaciaTreeGrowth.calculateTrunkBend(4, 8, -1, 1);
    try std.testing.expectEqual(@as(u32, 4), b2.bent_blocks);
    try std.testing.expectEqual(@as(i32, -4), b2.total_dx);
    try std.testing.expectEqual(@as(i32, 4), b2.total_dz);

    // When trunk_height <= bend_start_height: zero bend
    const b3 = AcaciaTreeGrowth.calculateTrunkBend(5, 5, 1, 1);
    try std.testing.expectEqual(@as(u32, 0), b3.bent_blocks);
    try std.testing.expectEqual(@as(i32, 0), b3.total_dx);
    try std.testing.expectEqual(@as(i32, 0), b3.total_dz);
}

test "AcaciaTreeGrowth clearance check rejects insufficient vertical space (< 7 blocks)" {
    // Minimum clearance is 7 blocks
    try std.testing.expect(!AcaciaTreeGrowth.checkClearance(0));
    try std.testing.expect(!AcaciaTreeGrowth.checkClearance(6));
    try std.testing.expect(AcaciaTreeGrowth.checkClearance(7));
    try std.testing.expect(AcaciaTreeGrowth.checkClearance(12));

    // Soil planting eligibility
    try std.testing.expect(AcaciaTreeGrowth.canPlant(.dirt));
    try std.testing.expect(AcaciaTreeGrowth.canPlant(.grass_block));
    try std.testing.expect(AcaciaTreeGrowth.canPlant(.coarse_dirt));
    try std.testing.expect(!AcaciaTreeGrowth.canPlant(.farmland));
    try std.testing.expect(!AcaciaTreeGrowth.canPlant(.other));

    // Generator rejects config with trunk_height < 7
    var buf: [128]TreePlacement = undefined;
    const invalid_cfg = AcaciaTreeConfig{ .trunk_height = 6 };
    try std.testing.expectEqual(@as(?TreeGenerationResult, null), AcaciaTreeGrowth.generate(&buf, invalid_cfg));
}

test "AcaciaTreeGrowth procedural umbrella canopy shape and radius bounds" {
    var buffer: [256]TreePlacement = undefined;
    const config = AcaciaTreeConfig{
        .trunk_height = 7,
        .bend_start_height = 3,
        .bend_dx = 1,
        .bend_dz = 0,
        .canopy_radius = 3,
    };

    const res = AcaciaTreeGrowth.generate(&buffer, config).?;
    try std.testing.expectEqual(@as(usize, 7), res.trunk_count);
    try std.testing.expect(res.leaf_count >= 20);

    // Verify trunk geometry:
    // Base is at (0, 0, 0)
    // Bent steps along +X starting at y=3
    var found_base = false;
    var found_top = false;
    for (buffer[0..res.count]) |b| {
        if (b.block_type == .acacia_log) {
            if (b.dy == 0 and b.dx == 0 and b.dz == 0) found_base = true;
            if (b.dy == 6 and b.dx == 4 and b.dz == 0) found_top = true;
        }
    }
    try std.testing.expect(found_base);
    try std.testing.expect(found_top);

    // Top trunk position returned in result
    try std.testing.expectEqual(@as(i32, 4), res.top_trunk_x);
    try std.testing.expectEqual(@as(i32, 6), res.top_trunk_y);
    try std.testing.expectEqual(@as(i32, 0), res.top_trunk_z);

    // Bounding box: umbrella canopy radius 3 produces width and depth >= 5
    const b = res.bounds;
    try std.testing.expect(b.width() >= 5);
    try std.testing.expect(b.depth() >= 5);
    try std.testing.expectEqual(@as(i32, 0), b.min_y);
    try std.testing.expect(b.max_y >= 7); // leaves reach top_trunk_y + 1 = 7
}

test "AcaciaTreeGrowth branching acacia tree with dual canopy generation" {
    var buffer: [512]TreePlacement = undefined;
    const config = AcaciaTreeConfig{
        .trunk_height = 8,
        .bend_start_height = 3,
        .bend_dx = 1,
        .bend_dz = 0,
        .canopy_radius = 3,
        .branch_fork = true,
        .branch_dx = -1,
        .branch_dz = 1,
        .branch_canopy_radius = 2,
    };

    const res = AcaciaTreeGrowth.generate(&buffer, config).?;
    // Main trunk (8) + branch fork logs (5) = 13 logs
    try std.testing.expect(res.trunk_count >= 12);
    // Both canopies populated
    try std.testing.expect(res.leaf_count >= 40);

    // Check branching coordinates: main trunk leans +x, branch leans -x and +z
    var found_main_top = false;
    var found_branch_top = false;
    for (buffer[0..res.count]) |b| {
        if (b.block_type == .acacia_log) {
            if (b.dx > 3 and b.dy == 7) found_main_top = true;
            if (b.dx < -3 and b.dz > 3 and b.dy == 7) found_branch_top = true;
        }
    }
    try std.testing.expect(found_main_top);
    try std.testing.expect(found_branch_top);
}

test "SavannaPlateauGeneration flat-topped plateau step elevation (base 68, plateau 96)" {
    const center_x: i32 = 100;
    const center_z: i32 = 100;
    const plateau_radius: f32 = 50.0;
    const slope_width: f32 = 20.0;

    // Inside plateau radius: flat top at plateau_y (96)
    const top_elevation = SavannaPlateauGeneration.getElevation(center_x, center_z, center_x, center_z, plateau_radius, slope_width);
    try std.testing.expectEqual(@as(i32, 96), top_elevation);

    const edge_top = SavannaPlateauGeneration.getElevation(center_x + 40, center_z, center_x, center_z, plateau_radius, slope_width);
    try std.testing.expectEqual(@as(i32, 96), edge_top);

    // Far outside plateau radius: base ground level at base_y (68)
    const base_elevation = SavannaPlateauGeneration.getElevation(center_x + 80, center_z, center_x, center_z, plateau_radius, slope_width);
    try std.testing.expectEqual(@as(i32, 68), base_elevation);

    // Mid-slope: stepped elevation strictly between 68 and 96
    const mid_elevation = SavannaPlateauGeneration.getElevation(center_x + 60, center_z, center_x, center_z, plateau_radius, slope_width);
    try std.testing.expect(mid_elevation >= 68 and mid_elevation <= 96);

    // Step elevation difference
    try std.testing.expectEqual(@as(i32, 28), SavannaPlateauGeneration.step_height);
    try std.testing.expect(SavannaPlateauGeneration.isPlateauElevation(96));
    try std.testing.expect(!SavannaPlateauGeneration.isPlateauElevation(68));

    // Surface blocks: plateau top has coarse dirt patches
    try std.testing.expectEqual(SoilType.coarse_dirt, SavannaPlateauGeneration.getSurfaceBlock(96, true));
    try std.testing.expectEqual(SoilType.grass_block, SavannaPlateauGeneration.getSurfaceBlock(96, false));
    try std.testing.expectEqual(SoilType.other, SavannaPlateauGeneration.getSurfaceBlock(80, false)); // cliff
    try std.testing.expectEqual(SoilType.grass_block, SavannaPlateauGeneration.getSurfaceBlock(68, false));
}

test "SavannaPlateauGeneration mob spawn eligibility (llama, armadillo, horse, ostrich)" {
    // 1. Llama: Savanna Plateau only, y >= 80, light >= 9, grass/dirt/coarse dirt
    try std.testing.expect(SavannaPlateauGeneration.canSpawnLlama(96, .grass_block, 10, true));
    try std.testing.expect(SavannaPlateauGeneration.canSpawnLlama(96, .coarse_dirt, 9, true));
    try std.testing.expect(!SavannaPlateauGeneration.canSpawnLlama(96, .grass_block, 10, false)); // not plateau
    try std.testing.expect(!SavannaPlateauGeneration.canSpawnLlama(70, .grass_block, 10, true)); // y too low
    try std.testing.expect(!SavannaPlateauGeneration.canSpawnLlama(96, .grass_block, 8, true)); // light too low
    try std.testing.expect(!SavannaPlateauGeneration.canSpawnLlama(96, .other, 10, true)); // stone/cliff

    // 2. Armadillo: Savanna and Plateau, light >= 7, grass/dirt/coarse dirt
    try std.testing.expect(SavannaPlateauGeneration.canSpawnArmadillo(.grass_block, 7));
    try std.testing.expect(SavannaPlateauGeneration.canSpawnArmadillo(.coarse_dirt, 12));
    try std.testing.expect(!SavannaPlateauGeneration.canSpawnArmadillo(.grass_block, 6)); // light too low
    try std.testing.expect(!SavannaPlateauGeneration.canSpawnArmadillo(.other, 10));

    // 3. Horse: grass blocks, light >= 9
    try std.testing.expect(SavannaPlateauGeneration.canSpawnHorse(.grass_block, 9));
    try std.testing.expect(SavannaPlateauGeneration.canSpawnHorse(.grass_block, 15));
    try std.testing.expect(!SavannaPlateauGeneration.canSpawnHorse(.coarse_dirt, 10)); // horses need grass
    try std.testing.expect(!SavannaPlateauGeneration.canSpawnHorse(.grass_block, 8)); // light too low

    // 4. Ostrich: grass/dirt/coarse dirt, light >= 8
    try std.testing.expect(SavannaPlateauGeneration.canSpawnOstrich(.grass_block, 8));
    try std.testing.expect(SavannaPlateauGeneration.canSpawnOstrich(.coarse_dirt, 12));
    try std.testing.expect(!SavannaPlateauGeneration.canSpawnOstrich(.grass_block, 7)); // light too low

    // Generic mob checker
    try std.testing.expect(SavannaPlateauGeneration.isMobEligible(.llama, 96, .grass_block, 10, true));
    try std.testing.expect(!SavannaPlateauGeneration.isMobEligible(.llama, 68, .grass_block, 10, false));
    try std.testing.expect(SavannaPlateauGeneration.isMobEligible(.armadillo, 68, .grass_block, 8, false));
    try std.testing.expect(SavannaPlateauGeneration.isMobEligible(.horse, 68, .grass_block, 10, false));
    try std.testing.expect(SavannaPlateauGeneration.isMobEligible(.ostrich, 96, .coarse_dirt, 10, true));
}

test "TermiteMound generation, conical shape, and wood degradation ticking" {
    var buf: [32]TermiteMoundBlock = undefined;
    const count = generateTermiteMound(&buf, 4);
    try std.testing.expect(count > 0);

    // Verify core and taper
    var core_count: usize = 0;
    for (buf[0..count]) |b| {
        if (b.is_core) core_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 4), core_count); // 1 core block per vertical level

    // Termite Mound entity mechanics
    var mound = TermiteMound{
        .x = 10,
        .y = 68,
        .z = 10,
        .height = 4,
        .termite_count = 3,
        .infestation_radius = 4.0,
    };

    // Ticking mound with wood nearby grows termite colony
    _ = mound.tick(5.0, true);
    try std.testing.expectEqual(@as(u8, 3), mound.termite_count); // not yet 10s
    _ = mound.tick(5.0, true);
    try std.testing.expectEqual(@as(u8, 4), mound.termite_count); // reached 10s -> incremented

    // Wood degradation within infestation radius
    try std.testing.expectEqual(SoilType.dirt, mound.degradeWood(2.5).?);
    try std.testing.expectEqual(SoilType.dirt, mound.degradeWood(4.0).?);
    try std.testing.expectEqual(@as(?SoilType, null), mound.degradeWood(4.5)); // outside radius

    // Harvesting mound drops termite clay
    const clay = mound.harvest(15);
    try std.testing.expectEqual(@as(u8, 3), clay);
    try std.testing.expectEqual(@as(u16, 5), mound.health);
}

test "Ostrich mob behavioral state machine: sprint, head-in-sand defense, egg laying" {
    var ostrich = Ostrich{};
    try std.testing.expectEqual(OstrichState.idle, ostrich.state);
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), ostrich.speed, 1e-4);

    // Threat on soft ground (sand/dirt): buries head in sand
    ostrich.reactToThreat(true);
    try std.testing.expectEqual(OstrichState.head_in_sand, ostrich.state);
    try std.testing.expectEqual(@as(f32, 0.0), ostrich.speed);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), ostrich.head_in_sand_timer, 1e-4);

    // Ticking 2 seconds: remains in head_in_sand
    _ = ostrich.tick(2.0);
    try std.testing.expectEqual(OstrichState.head_in_sand, ostrich.state);

    // Ticking another 2 seconds: timer expires, resets to idle
    _ = ostrich.tick(2.0);
    try std.testing.expectEqual(OstrichState.idle, ostrich.state);
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), ostrich.speed, 1e-4);

    // Threat on hard ground (stone/wood): sprints away
    ostrich.reactToThreat(false);
    try std.testing.expectEqual(OstrichState.sprinting, ostrich.state);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), ostrich.speed, 1e-4);

    // Egg laying timer: ticking 300s lays an egg
    try std.testing.expect(!ostrich.tick(100.0));
    try std.testing.expect(ostrich.tick(200.0)); // Total 300s elapsed
}

test "Ostrich mount and saddle mechanics with seed temptation and breeding" {
    var ostrich = Ostrich{};

    // Cannot mount without saddle
    try std.testing.expect(!ostrich.mount());
    try std.testing.expect(!ostrich.has_rider);

    // Equip saddle
    try std.testing.expect(ostrich.equipSaddle());
    try std.testing.expect(ostrich.is_saddled);
    try std.testing.expect(!ostrich.equipSaddle()); // already saddled

    // Mount saddled ostrich
    try std.testing.expect(ostrich.mount());
    try std.testing.expect(ostrich.has_rider);
    try std.testing.expectEqual(OstrichState.ridden, ostrich.state);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), ostrich.speed, 1e-4);

    // Threats do not trigger head_in_sand while ridden
    ostrich.reactToThreat(true);
    try std.testing.expectEqual(OstrichState.ridden, ostrich.state);

    // Dismount
    ostrich.dismount();
    try std.testing.expect(!ostrich.has_rider);
    try std.testing.expectEqual(OstrichState.idle, ostrich.state);
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), ostrich.speed, 1e-4);

    // Feeding seeds enters love mode and heals
    ostrich.health = 16.0;
    try std.testing.expect(ostrich.feedSeeds());
    try std.testing.expectApproxEqAbs(@as(f32, 18.0), ostrich.health, 1e-4);
    try std.testing.expect(ostrich.love_timer > 0.0);
    try std.testing.expect(!ostrich.feedSeeds()); // on love cooldown
}

test "Edge cases: zero crafting counts, small buffer capacity, boundary coordinate handling" {
    // Zero materials craft zero products
    try std.testing.expectEqual(@as(u32, 0), craftPlanks(0));
    try std.testing.expectEqual(@as(u32, 0), AcaciaWoodFamily.craftSlabs(0).slabs);
    try std.testing.expectEqual(@as(u32, 0), AcaciaWoodFamily.craftStairs(0).stairs);
    try std.testing.expectEqual(@as(u32, 0), AcaciaWoodFamily.craftDoors(0).doors);
    try std.testing.expectEqual(@as(u32, 0), AcaciaWoodFamily.craftTrapdoors(0).trapdoors);
    try std.testing.expectEqual(@as(u32, 0), AcaciaWoodFamily.craftFences(0, 0).fences);
    try std.testing.expectEqual(@as(u32, 0), AcaciaWoodFamily.craftFenceGate(0, 0).gates);
    try std.testing.expectEqual(@as(u32, 0), AcaciaWoodFamily.craftBoat(0).boats);

    // Buffer smaller than full tree fills safely without overflow
    var small_buf: [5]TreePlacement = undefined;
    const res = AcaciaTreeGrowth.generate(&small_buf, .{}).?;
    try std.testing.expectEqual(@as(usize, 5), res.count);

    // Small buffer for termite mound
    var small_mound_buf: [2]TermiteMoundBlock = undefined;
    const mound_count = generateTermiteMound(&small_mound_buf, 4);
    try std.testing.expectEqual(@as(usize, 2), mound_count);

    // Soil tilling on stone returns null
    try std.testing.expectEqual(@as(?SoilType, null), CoarseDirtTilling.till(.other));
}
