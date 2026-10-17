const std = @import("std");

// ============================================================================
// Biome Environmental Constants & Registry Item/Block Tags
// ============================================================================

pub const swamp_temperature: f32 = 0.8;
pub const swamp_downfall: f32 = 0.9;
pub const mangrove_marsh_temperature: f32 = 1.0;
pub const mangrove_marsh_downfall: f32 = 0.9;

pub const cold_biome_threshold_temp: f32 = 0.20;
pub const warm_biome_threshold_temp: f32 = 0.90;

pub const LilyPadItemTag: u16 = 111;
pub const LilyPadBlockTag: u16 = 111;
pub const FrogspawnItemTag: u16 = 227;
pub const FrogspawnBlockTag: u16 = 227;
pub const SlimeballItemTag: u16 = 206;
pub const BucketOfTadpoleItemTag: u16 = 335;
pub const WaterBucketItemTag: u16 = 326;
pub const BlueOrchidItemTag: u16 = 38;
pub const LightBlueDyeItemTag: u16 = 352;
pub const SuspiciousStewItemTag: u16 = 734;
pub const ClayBlockTag: u16 = 82;
pub const ClayBallTag: u16 = 337;
pub const DeadBushTag: u16 = 32;
pub const VineBlockTag: u16 = 106;
pub const OakLogTag: u16 = 17;
pub const OakLeavesTag: u16 = 18;

// ============================================================================
// 1. LilyPadPlacement & Boat Collision Mechanics
// ============================================================================

/// Height of a lily pad collision box: 1.5 pixels / 16 = 0.09375 blocks.
pub const lily_pad_height: f32 = 0.09375;

pub const LilyPadBoundingBox = struct {
    min_x: f32,
    min_y: f32,
    min_z: f32,
    max_x: f32,
    max_y: f32,
    max_z: f32,

    pub fn height(self: LilyPadBoundingBox) f32 {
        return self.max_y - self.min_y;
    }
};

pub const BoatLilyPadCollisionResult = struct {
    lily_pad_broken: bool,
    drops_item: bool,
    item_id: u16,
    boat_stopped: bool,
    preserved_speed: f32,
};

/// Evaluates if a lily pad can be placed:
/// Must be placed on top of stationary water source blocks or ice, with air at target position.
pub fn canPlaceLilyPad(below_is_source_water_or_ice: bool, target_space_is_air: bool) bool {
    return below_is_source_water_or_ice and target_space_is_air;
}

/// Returns the world-space bounding box for a lily pad at block coordinates (x, y, z).
pub fn getLilyPadCollisionBox(block_x: i32, block_y: i32, block_z: i32) LilyPadBoundingBox {
    const min_xf: f32 = @floatFromInt(block_x);
    const min_yf: f32 = @floatFromInt(block_y);
    const min_zf: f32 = @floatFromInt(block_z);
    return .{
        .min_x = min_xf,
        .min_y = min_yf,
        .min_z = min_zf,
        .max_x = min_xf + 1.0,
        .max_y = min_yf + lily_pad_height,
        .max_z = min_zf + 1.0,
    };
}

/// Moving boats colliding with lily pads instantly break the lily pad and drop its item
/// without stopping the boat. Stationary boats (speed <= 0.001) do not break the lily pad.
pub fn resolveBoatLilyPadCollision(boat_speed: f32) BoatLilyPadCollisionResult {
    const is_moving = @abs(boat_speed) > 0.001;
    if (is_moving) {
        return .{
            .lily_pad_broken = true,
            .drops_item = true,
            .item_id = LilyPadItemTag,
            .boat_stopped = false,
            .preserved_speed = boat_speed,
        };
    } else {
        return .{
            .lily_pad_broken = false,
            .drops_item = false,
            .item_id = 0,
            .boat_stopped = false,
            .preserved_speed = 0.0,
        };
    }
}

/// Namespace grouping for LilyPadPlacement
pub const LilyPadPlacement = struct {
    pub const height: f32 = lily_pad_height;
    pub const canPlaceLilyPad = @import("swamp_marsh.zig").canPlaceLilyPad;
    pub const getCollisionBox = @import("swamp_marsh.zig").getLilyPadCollisionBox;
    pub const resolveBoatLilyPadCollision = @import("swamp_marsh.zig").resolveBoatLilyPadCollision;

    pub fn allowsWalkingOverWater() bool {
        return true;
    }

    pub fn isSolidTop() bool {
        return true;
    }
};

// ============================================================================
// 2. FrogspawnMetamorphosis & Tadpole Maturation
// ============================================================================

pub const FrogVariant = enum(u8) {
    temperate_orange = 0,
    warm_white = 1,
    cold_green = 2,

    pub fn name(self: FrogVariant) []const u8 {
        return switch (self) {
            .temperate_orange => "temperate_orange",
            .warm_white => "warm_white",
            .cold_green => "cold_green",
        };
    }
};

/// Evaluates which frog variant a tadpole matures into, based on biome temperature.
/// Biome temp < 0.20: .cold_green
/// Biome temp >= 0.90: .warm_white
/// Temperate range [0.20, 0.90): .temperate_orange
pub fn frogVariantForBiomeTemp(temp: f32) FrogVariant {
    if (temp < cold_biome_threshold_temp) {
        return .cold_green;
    } else if (temp >= warm_biome_threshold_temp) {
        return .warm_white;
    } else {
        return .temperate_orange;
    }
}

/// Frogspawn is a non-solid surface layer block laid on water.
pub fn isNonSolidSurfaceLayer() bool {
    return true;
}

pub const frogspawn_hatch_seconds: f32 = 600.0; // 10.0 minutes (12000 ticks)
pub const frogspawn_hatch_ticks: u32 = 12000;
pub const min_tadpoles_per_hatch: u8 = 2;
pub const max_tadpoles_per_hatch: u8 = 5;

pub const tadpole_growth_seconds: f32 = 1200.0; // 20.0 minutes (24000 ticks)
pub const tadpole_growth_ticks: u32 = 24000;
pub const tadpole_acceleration_per_slimeball_ratio: f32 = 0.10; // 10%

pub const FrogspawnState = struct {
    age_seconds: f32 = 0.0,
    hatch_duration: f32 = frogspawn_hatch_seconds,
    hatched: bool = false,

    pub fn isNonSolidSurfaceLayer() bool {
        return true;
    }

    pub fn tick(self: *FrogspawnState, dt: f32) bool {
        if (self.hatched) return false;
        self.age_seconds += dt;
        if (self.age_seconds >= self.hatch_duration) {
            self.hatched = true;
            return true;
        }
        return false;
    }

    /// Calculates deterministic tadpole count (2..5) based on a roll [0.0, 1.0).
    pub fn calculateHatchCount(roll_0_to_1: f32) u8 {
        const clamped = std.math.clamp(roll_0_to_1, 0.0, 0.9999);
        const count_span: f32 = @floatFromInt(max_tadpoles_per_hatch - min_tadpoles_per_hatch + 1);
        const offset: u8 = @intFromFloat(clamped * count_span);
        return min_tadpoles_per_hatch + offset;
    }
};

pub const FrogState = struct {
    variant: FrogVariant,
    health: f32 = 10.0,
    in_love: bool = false,
    love_timer: f32 = 0.0,
    breed_cooldown: f32 = 0.0,
    is_pregnant: bool = false,

    pub fn init(variant: FrogVariant) FrogState {
        return .{ .variant = variant };
    }

    pub fn feedSlimeball(self: *FrogState) bool {
        if (self.breed_cooldown > 0.0 or self.in_love or self.is_pregnant) return false;
        self.in_love = true;
        self.love_timer = 30.0;
        return true;
    }

    pub fn breedWith(self: *FrogState, partner: *FrogState) bool {
        if (self.in_love and partner.in_love and !self.is_pregnant and !partner.is_pregnant) {
            self.in_love = false;
            self.love_timer = 0.0;
            self.breed_cooldown = 300.0;

            partner.in_love = false;
            partner.love_timer = 0.0;
            partner.breed_cooldown = 300.0;

            // One frog becomes pregnant to lay frogspawn on water surface
            self.is_pregnant = true;
            return true;
        }
        return false;
    }

    pub fn layFrogspawn(self: *FrogState, water_below: bool, air_at_layer: bool) ?FrogspawnState {
        if (!self.is_pregnant) return null;
        if (water_below and air_at_layer) {
            self.is_pregnant = false;
            return FrogspawnState{};
        }
        return null;
    }
};

pub const TadpoleState = struct {
    age_seconds: f32 = 0.0,
    growth_duration: f32 = tadpole_growth_seconds,
    health: f32 = 6.0, // 3 hearts
    in_water: bool = true,
    out_of_water_timer: f32 = 0.0,
    is_flopping: bool = false,
    is_suffocating: bool = false,
    in_bucket: bool = false,
    matured_variant: ?FrogVariant = null,

    pub fn init() TadpoleState {
        return .{};
    }

    /// Feeding a slimeball accelerates remaining growth duration by 10%.
    pub fn feedSlimeball(self: *TadpoleState) bool {
        if (self.in_bucket or self.health <= 0.0 or self.matured_variant != null) return false;
        const remaining = self.growth_duration - self.age_seconds;
        if (remaining > 0.0) {
            const acceleration = remaining * tadpole_acceleration_per_slimeball_ratio;
            self.age_seconds += acceleration;
            return true;
        }
        return false;
    }

    pub fn tick(self: *TadpoleState, dt: f32, biome_temperature: f32) void {
        if (self.in_bucket or self.health <= 0.0) return;

        if (!self.in_water) {
            self.is_flopping = true;
            self.out_of_water_timer += dt;
            if (self.out_of_water_timer >= tadpole_suffocation_duration_seconds) {
                self.is_suffocating = true;
                // Takes suffocation damage over time (1.0 HP / sec)
                self.health = @max(0.0, self.health - dt * 1.0);
            }
        } else {
            self.is_flopping = false;
            self.is_suffocating = false;
            self.out_of_water_timer = 0.0;
        }

        if (self.health > 0.0 and self.matured_variant == null) {
            self.age_seconds += dt;
            if (self.age_seconds >= self.growth_duration) {
                self.matured_variant = frogVariantForBiomeTemp(biome_temperature);
            }
        }
    }

    pub fn mature(self: *TadpoleState, biome_temperature: f32) ?FrogVariant {
        if (self.matured_variant) |v| return v;
        if (self.age_seconds >= self.growth_duration and self.health > 0.0) {
            const v = frogVariantForBiomeTemp(biome_temperature);
            self.matured_variant = v;
            return v;
        }
        return null;
    }
};

/// Namespace grouping for FrogspawnMetamorphosis
pub const FrogspawnMetamorphosis = struct {
    pub const hatch_seconds: f32 = frogspawn_hatch_seconds;
    pub const hatch_ticks: u32 = frogspawn_hatch_ticks;
    pub const min_tadpoles: u8 = min_tadpoles_per_hatch;
    pub const max_tadpoles: u8 = max_tadpoles_per_hatch;
    pub const acceleration_percent: f32 = 10.0;

    pub const isNonSolidSurfaceLayer = @import("swamp_marsh.zig").isNonSolidSurfaceLayer;
    pub const frogVariantForBiomeTemp = @import("swamp_marsh.zig").frogVariantForBiomeTemp;
};

// ============================================================================
// 3. TadpoleSurvival & Axolotl Predation
// ============================================================================

pub const tadpole_suffocation_duration_seconds: f32 = 5.0; // 5.0 seconds
pub const tadpole_suffocation_ticks: u32 = 100; // 100 ticks (20 tps * 5.0s)
pub const tadpole_max_health: f32 = 6.0;

/// Attempts to scoop a tadpole into a water bucket to create a Bucket of Tadpole.
/// Preserves the tadpole's maturation progress.
pub fn scoopTadpoleIntoBucket(tadpole: *TadpoleState, has_water_bucket: bool) ?u16 {
    if (!has_water_bucket or tadpole.in_bucket or tadpole.health <= 0.0) return null;
    tadpole.in_bucket = true;
    tadpole.is_flopping = false;
    tadpole.is_suffocating = false;
    tadpole.out_of_water_timer = 0.0;
    return BucketOfTadpoleItemTag;
}

/// Releases a tadpole from a Bucket of Tadpole back into the world.
pub fn releaseTadpoleFromBucket(tadpole: *TadpoleState, placed_in_water: bool) bool {
    if (!tadpole.in_bucket) return false;
    tadpole.in_bucket = false;
    tadpole.in_water = placed_in_water;
    tadpole.out_of_water_timer = 0.0;
    tadpole.is_flopping = !placed_in_water;
    return true;
}

/// Axolotls naturally hunt aquatic prey, including Tadpoles.
pub fn isHuntedByAxolotl(tadpole: TadpoleState) bool {
    // Axolotls target live tadpoles swimming in water
    return tadpole.health > 0.0 and tadpole.in_water and !tadpole.in_bucket;
}

/// Evaluates if an axolotl at axolotl_pos will target a tadpole at tadpole_pos.
pub fn canAxolotlDetectTadpole(axolotl_pos: [3]f32, tadpole_pos: [3]f32, detection_radius: f32) bool {
    const dx = axolotl_pos[0] - tadpole_pos[0];
    const dy = axolotl_pos[1] - tadpole_pos[1];
    const dz = axolotl_pos[2] - tadpole_pos[2];
    const dist_sq = dx * dx + dy * dy + dz * dz;
    return dist_sq <= (detection_radius * detection_radius);
}

/// Namespace grouping for TadpoleSurvival
pub const TadpoleSurvival = struct {
    pub const suffocation_duration: f32 = tadpole_suffocation_duration_seconds;
    pub const suffocation_ticks: u32 = tadpole_suffocation_ticks;
    pub const max_health: f32 = tadpole_max_health;
    pub const scoopIntoBucket = @import("swamp_marsh.zig").scoopTadpoleIntoBucket;
    pub const releaseFromBucket = @import("swamp_marsh.zig").releaseTadpoleFromBucket;
    pub const isHuntedByAxolotl = @import("swamp_marsh.zig").isHuntedByAxolotl;
};

// ============================================================================
// 4. SwampFlora & Blue Orchid Crafting
// ============================================================================

pub const BiomeKind = enum {
    swamp,
    mangrove_marsh,
    plains,
    forest,
    dark_forest,
    desert,
    badlands,
    snowy_plains,
    jungle,
    ocean,
};

pub const SuspiciousStewEffect = enum {
    saturation,
    fire_resistance,
    blindness,
    jump_boost,
    poison,
    regeneration,
    night_vision,
};

pub const SuspiciousStewResult = struct {
    effect: SuspiciousStewEffect,
    duration_seconds: f32,
    duration_ticks: u32,
};

/// Blue Orchid generates naturally exclusively in Swamp biomes.
pub fn canGenerateBlueOrchid(biome: BiomeKind) bool {
    return biome == .swamp;
}

/// Crafting Blue Orchid into Light Blue Dye yields 1 dye per flower.
pub fn craftLightBlueDyeFromBlueOrchid(orchid_count: u32) u32 {
    return orchid_count;
}

/// Crafting Blue Orchid into Suspicious Stew grants Saturation for 0.35s (7 ticks).
pub fn craftSuspiciousStewFromBlueOrchid() SuspiciousStewResult {
    return .{
        .effect = .saturation,
        .duration_seconds = 0.35,
        .duration_ticks = 7,
    };
}

/// Water-edge clay patches generate along shallow swamp water borders.
pub const ClayPatch = struct {
    center_x: i32,
    center_y: i32,
    center_z: i32,
    radius: u8,
    depth: u8,

    pub fn blockCountEstimate(self: ClayPatch) u32 {
        const r: f32 = @floatFromInt(self.radius);
        const area = std.math.pi * r * r;
        return @intFromFloat(area * @as(f32, @floatFromInt(self.depth)));
    }
};

pub fn canGenerateClayPatch(water_depth: u32, is_near_water_edge: bool) bool {
    // Generates under shallow water (1..3 blocks deep) near shorelines/edges
    return water_depth >= 1 and water_depth <= 3 and is_near_water_edge;
}

pub fn generateClayPatch(center_x: i32, center_y: i32, center_z: i32, radius: u8, depth: u8) ClayPatch {
    return .{
        .center_x = center_x,
        .center_y = center_y,
        .center_z = center_z,
        .radius = radius,
        .depth = depth,
    };
}

/// Dead bushes can generate in swamps on dirt, coarse dirt, mud, or clay.
pub fn canGenerateDeadBushInSwamp(is_swamp_biome: bool, ground_is_dirt_mud_or_clay: bool) bool {
    return is_swamp_biome and ground_is_dirt_mud_or_clay;
}

/// Vine-draped oak tree feature generator for swamps.
pub const SwampFoliageBlock = enum {
    oak_log,
    oak_leaves,
    vine,
};

pub const PlacedFoliage = struct {
    dx: i8,
    dy: i8,
    dz: i8,
    block: SwampFoliageBlock,
};

pub const SwampOakTree = struct {
    trunk_height: u8,
    leaf_radius: u8,
    vines_hanging: bool,

    pub fn generate(trunk_height: u8, leaf_radius: u8) SwampOakTree {
        return .{
            .trunk_height = trunk_height,
            .leaf_radius = leaf_radius,
            .vines_hanging = true,
        };
    }

    /// Evaluates if vines should drape at a given distance from canopy edge.
    pub fn hasDrapedVineAtEdge(dist_from_trunk: u8, canopy_radius: u8) bool {
        return dist_from_trunk == canopy_radius;
    }
};

/// Namespace grouping for SwampFlora
pub const SwampFlora = struct {
    pub const canGenerateBlueOrchid = @import("swamp_marsh.zig").canGenerateBlueOrchid;
    pub const craftLightBlueDye = @import("swamp_marsh.zig").craftLightBlueDyeFromBlueOrchid;
    pub const craftSuspiciousStew = @import("swamp_marsh.zig").craftSuspiciousStewFromBlueOrchid;
    pub const canGenerateClayPatch = @import("swamp_marsh.zig").canGenerateClayPatch;
    pub const canGenerateDeadBush = @import("swamp_marsh.zig").canGenerateDeadBushInSwamp;
};

// ============================================================================
// Unit Tests (Comprehensive 18 test blocks)
// ============================================================================

test "1. LilyPadPlacement: placement requires water source or ice below, air at target" {
    // Valid: water source below, air at target
    try std.testing.expect(canPlaceLilyPad(true, true));
    try std.testing.expect(LilyPadPlacement.canPlaceLilyPad(true, true));

    // Invalid: no water or ice below
    try std.testing.expect(!canPlaceLilyPad(false, true));

    // Invalid: target space is occupied (not air)
    try std.testing.expect(!canPlaceLilyPad(true, false));
    try std.testing.expect(!canPlaceLilyPad(false, false));
}

test "2. LilyPadPlacement: collision box height 0.09375 allows walking over water" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.09375), lily_pad_height, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.09375), LilyPadPlacement.height, 1e-5);

    const box = getLilyPadCollisionBox(10, 64, -5);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), box.min_x, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), box.max_x, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), box.min_y, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 64.09375), box.max_y, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, -5.0), box.min_z, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, -4.0), box.max_z, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.09375), box.height(), 1e-5);

    try std.testing.expect(LilyPadPlacement.allowsWalkingOverWater());
    try std.testing.expect(LilyPadPlacement.isSolidTop());
}

test "3. LilyPadPlacement: moving boat collision breaks lily pad, drops item, preserves speed" {
    const boat_forward_speed: f32 = 4.5;
    const result = resolveBoatLilyPadCollision(boat_forward_speed);

    try std.testing.expect(result.lily_pad_broken);
    try std.testing.expect(result.drops_item);
    try std.testing.expectEqual(LilyPadItemTag, result.item_id);
    try std.testing.expect(!result.boat_stopped); // Crucial: boat does NOT stop!
    try std.testing.expectApproxEqAbs(boat_forward_speed, result.preserved_speed, 1e-5);
}

test "4. LilyPadPlacement: stationary boat collision does not break lily pad" {
    const stationary_speed: f32 = 0.0;
    const result = resolveBoatLilyPadCollision(stationary_speed);

    try std.testing.expect(!result.lily_pad_broken);
    try std.testing.expect(!result.drops_item);
    try std.testing.expectEqual(@as(u16, 0), result.item_id);
    try std.testing.expect(!result.boat_stopped);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result.preserved_speed, 1e-5);
}

test "5. FrogspawnMetamorphosis: frog breeding with slimeball and egg laying on water" {
    var frog_a = FrogState.init(.temperate_orange);
    var frog_b = FrogState.init(.warm_white);

    // Initial state
    try std.testing.expect(!frog_a.in_love);
    try std.testing.expect(!frog_b.in_love);

    // Feed slimeballs
    try std.testing.expect(frog_a.feedSlimeball());
    try std.testing.expect(frog_b.feedSlimeball());
    try std.testing.expect(frog_a.in_love);
    try std.testing.expect(frog_b.in_love);

    // Breed frogs
    try std.testing.expect(frog_a.breedWith(&frog_b));
    try std.testing.expect(frog_a.is_pregnant);
    try std.testing.expect(!frog_a.in_love);
    try std.testing.expectEqual(@as(f32, 300.0), frog_a.breed_cooldown);
    try std.testing.expectEqual(@as(f32, 300.0), frog_b.breed_cooldown);

    // Cannot lay on dry land without water below
    try std.testing.expect(frog_a.layFrogspawn(false, true) == null);

    // Successfully lays frogspawn on water surface
    const spawn = frog_a.layFrogspawn(true, true);
    try std.testing.expect(spawn != null);
    try std.testing.expect(!frog_a.is_pregnant);
}

test "6. FrogspawnMetamorphosis: frogspawn is a non-solid surface layer" {
    try std.testing.expect(isNonSolidSurfaceLayer());
    try std.testing.expect(FrogspawnState.isNonSolidSurfaceLayer());
    try std.testing.expect(FrogspawnMetamorphosis.isNonSolidSurfaceLayer());
}

test "7. FrogspawnMetamorphosis: frogspawn hatch timer 10.0 minutes (600.0s / 12000 ticks)" {
    try std.testing.expectApproxEqAbs(@as(f32, 600.0), frogspawn_hatch_seconds, 1e-5);
    try std.testing.expectEqual(@as(u32, 12000), frogspawn_hatch_ticks);

    var spawn = FrogspawnState{};
    try std.testing.expect(!spawn.hatched);

    // Advance 599.0s -> not yet hatched
    const hatched_early = spawn.tick(599.0);
    try std.testing.expect(!hatched_early);
    try std.testing.expect(!spawn.hatched);

    // Advance remaining 1.0s -> reaches 600.0s and hatches
    const hatched = spawn.tick(1.0);
    try std.testing.expect(hatched);
    try std.testing.expect(spawn.hatched);

    // Subsequent tick does not hatch again
    try std.testing.expect(!spawn.tick(1.0));
}

test "8. FrogspawnMetamorphosis: frogspawn hatches into 2..5 tadpoles across random range" {
    try std.testing.expectEqual(@as(u8, 2), min_tadpoles_per_hatch);
    try std.testing.expectEqual(@as(u8, 5), max_tadpoles_per_hatch);

    // Lowest roll -> 2 tadpoles
    try std.testing.expectEqual(@as(u8, 2), FrogspawnState.calculateHatchCount(0.0));
    try std.testing.expectEqual(@as(u8, 2), FrogspawnState.calculateHatchCount(0.24));

    // Mid rolls -> 3 and 4 tadpoles
    try std.testing.expectEqual(@as(u8, 3), FrogspawnState.calculateHatchCount(0.26));
    try std.testing.expectEqual(@as(u8, 4), FrogspawnState.calculateHatchCount(0.55));

    // High roll -> 5 tadpoles
    try std.testing.expectEqual(@as(u8, 5), FrogspawnState.calculateHatchCount(0.85));
    try std.testing.expectEqual(@as(u8, 5), FrogspawnState.calculateHatchCount(0.99));
}

test "9. FrogspawnMetamorphosis: frogVariantForBiomeTemp maps cold, temperate, and warm biomes" {
    // Cold biomes (< 0.20): .cold_green
    try std.testing.expectEqual(FrogVariant.cold_green, frogVariantForBiomeTemp(-0.5));
    try std.testing.expectEqual(FrogVariant.cold_green, frogVariantForBiomeTemp(0.0));
    try std.testing.expectEqual(FrogVariant.cold_green, frogVariantForBiomeTemp(0.19));

    // Temperate biomes [0.20, 0.90): .temperate_orange
    try std.testing.expectEqual(FrogVariant.temperate_orange, frogVariantForBiomeTemp(0.20));
    try std.testing.expectEqual(FrogVariant.temperate_orange, frogVariantForBiomeTemp(0.50));
    try std.testing.expectEqual(FrogVariant.temperate_orange, frogVariantForBiomeTemp(0.70));
    try std.testing.expectEqual(FrogVariant.temperate_orange, frogVariantForBiomeTemp(swamp_temperature)); // 0.80

    // Warm biomes (>= 0.90): .warm_white
    try std.testing.expectEqual(FrogVariant.warm_white, frogVariantForBiomeTemp(0.90));
    try std.testing.expectEqual(FrogVariant.warm_white, frogVariantForBiomeTemp(mangrove_marsh_temperature)); // 1.0
    try std.testing.expectEqual(FrogVariant.warm_white, frogVariantForBiomeTemp(1.20)); // Savanna
    try std.testing.expectEqual(FrogVariant.warm_white, frogVariantForBiomeTemp(2.00)); // Desert
}

test "10. FrogspawnMetamorphosis: tadpole growth accelerated by 10% per slimeball fed" {
    var tadpole = TadpoleState.init();
    try std.testing.expectApproxEqAbs(@as(f32, 1200.0), tadpole.growth_duration, 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tadpole.age_seconds, 1e-4);

    // Initial remaining time: 1200.0s. 10% acceleration is +120.0s
    try std.testing.expect(tadpole.feedSlimeball());
    try std.testing.expectApproxEqAbs(@as(f32, 120.0), tadpole.age_seconds, 1e-3);

    // Now remaining time: 1080.0s. 10% acceleration is +108.0s -> age becomes 228.0s
    try std.testing.expect(tadpole.feedSlimeball());
    try std.testing.expectApproxEqAbs(@as(f32, 228.0), tadpole.age_seconds, 1e-3);
}

test "11. FrogspawnMetamorphosis: tadpole matures into frog variant according to biome temperature" {
    // Tadpole in cold biome (e.g. snowy mountains / deep dark)
    var cold_tadpole = TadpoleState.init();
    cold_tadpole.age_seconds = 1200.0;
    const cold_frog = cold_tadpole.mature(0.0);
    try std.testing.expectEqual(FrogVariant.cold_green, cold_frog.?);

    // Tadpole in warm mangrove marsh
    var warm_tadpole = TadpoleState.init();
    warm_tadpole.age_seconds = 1200.0;
    const warm_frog = warm_tadpole.mature(mangrove_marsh_temperature);
    try std.testing.expectEqual(FrogVariant.warm_white, warm_frog.?);

    // Tadpole in temperate swamp
    var temperate_tadpole = TadpoleState.init();
    temperate_tadpole.age_seconds = 1200.0;
    const temperate_frog = temperate_tadpole.mature(swamp_temperature);
    try std.testing.expectEqual(FrogVariant.temperate_orange, temperate_frog.?);
}

test "12. TadpoleSurvival: out of water flopping and suffocation after 5.0 seconds (100 ticks)" {
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), tadpole_suffocation_duration_seconds, 1e-4);
    try std.testing.expectEqual(@as(u32, 100), tadpole_suffocation_ticks);

    var tadpole = TadpoleState.init();
    tadpole.in_water = false; // Landed on dry ground

    // Tick for 2.0s -> flopping, but not yet suffocating
    tadpole.tick(2.0, swamp_temperature);
    try std.testing.expect(tadpole.is_flopping);
    try std.testing.expect(!tadpole.is_suffocating);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), tadpole.health, 1e-4);

    // Tick another 3.0s (total 5.0s) -> suffocation begins!
    tadpole.tick(3.0, swamp_temperature);
    try std.testing.expect(tadpole.is_suffocating);

    // Tick 1.0s while suffocating -> takes damage
    tadpole.tick(1.0, swamp_temperature);
    try std.testing.expect(tadpole.health < 6.0);

    // Returned to water -> stops flopping and suffocating, timer resets
    tadpole.in_water = true;
    tadpole.tick(0.1, swamp_temperature);
    try std.testing.expect(!tadpole.is_flopping);
    try std.testing.expect(!tadpole.is_suffocating);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), tadpole.out_of_water_timer, 1e-4);
}

test "13. TadpoleSurvival: scooping into Bucket of Tadpole preserves age, releases back" {
    var tadpole = TadpoleState.init();
    tadpole.age_seconds = 450.0;

    // Cannot scoop without a water bucket
    try std.testing.expect(scoopTadpoleIntoBucket(&tadpole, false) == null);

    // Scoop with water bucket
    const bucket_tag = scoopTadpoleIntoBucket(&tadpole, true);
    try std.testing.expectEqual(BucketOfTadpoleItemTag, bucket_tag.?);
    try std.testing.expect(tadpole.in_bucket);
    try std.testing.expectApproxEqAbs(@as(f32, 450.0), tadpole.age_seconds, 1e-4); // Age preserved!

    // Tadpole in bucket does not tick or take damage
    tadpole.tick(10.0, swamp_temperature);
    try std.testing.expectApproxEqAbs(@as(f32, 450.0), tadpole.age_seconds, 1e-4);

    // Release from bucket back into water
    try std.testing.expect(releaseTadpoleFromBucket(&tadpole, true));
    try std.testing.expect(!tadpole.in_bucket);
    try std.testing.expect(tadpole.in_water);
    try std.testing.expectApproxEqAbs(@as(f32, 450.0), tadpole.age_seconds, 1e-4);
}

test "14. TadpoleSurvival: axolotl targets and hunts live tadpoles in water" {
    var tadpole = TadpoleState.init();
    try std.testing.expect(isHuntedByAxolotl(tadpole));

    // Dead tadpole is not hunted
    tadpole.health = 0.0;
    try std.testing.expect(!isHuntedByAxolotl(tadpole));

    // Tadpole in bucket is protected
    var bucket_tadpole = TadpoleState.init();
    _ = scoopTadpoleIntoBucket(&bucket_tadpole, true);
    try std.testing.expect(!isHuntedByAxolotl(bucket_tadpole));

    // Axolotl detection radius check
    const axolotl_pos = [3]f32{ 0.0, 60.0, 0.0 };
    const near_tadpole_pos = [3]f32{ 5.0, 60.0, 3.0 }; // ~5.8 blocks away
    const far_tadpole_pos = [3]f32{ 20.0, 60.0, 20.0 }; // ~28.2 blocks away

    try std.testing.expect(canAxolotlDetectTadpole(axolotl_pos, near_tadpole_pos, 16.0));
    try std.testing.expect(!canAxolotlDetectTadpole(axolotl_pos, far_tadpole_pos, 16.0));
}

test "15. SwampFlora: exclusive natural generation of Blue Orchid in swamp biomes" {
    try std.testing.expect(canGenerateBlueOrchid(.swamp));
    try std.testing.expect(SwampFlora.canGenerateBlueOrchid(.swamp));

    // Not in plains, forest, desert, badlands, or other biomes
    try std.testing.expect(!canGenerateBlueOrchid(.plains));
    try std.testing.expect(!canGenerateBlueOrchid(.forest));
    try std.testing.expect(!canGenerateBlueOrchid(.dark_forest));
    try std.testing.expect(!canGenerateBlueOrchid(.desert));
    try std.testing.expect(!canGenerateBlueOrchid(.badlands));
    try std.testing.expect(!canGenerateBlueOrchid(.snowy_plains));
    try std.testing.expect(!canGenerateBlueOrchid(.jungle));
    try std.testing.expect(!canGenerateBlueOrchid(.ocean));
}

test "16. SwampFlora: Blue Orchid crafts into Light Blue Dye and Saturation Suspicious Stew" {
    // 3 orchids craft into 3 Light Blue Dyes
    try std.testing.expectEqual(@as(u32, 3), craftLightBlueDyeFromBlueOrchid(3));
    try std.testing.expectEqual(@as(u32, 1), SwampFlora.craftLightBlueDye(1));

    // Blue Orchid yields Suspicious Stew with Saturation effect (0.35s / 7 ticks)
    const stew = craftSuspiciousStewFromBlueOrchid();
    try std.testing.expectEqual(SuspiciousStewEffect.saturation, stew.effect);
    try std.testing.expectApproxEqAbs(@as(f32, 0.35), stew.duration_seconds, 1e-4);
    try std.testing.expectEqual(@as(u32, 7), stew.duration_ticks);

    const stew_ns = SwampFlora.craftSuspiciousStew();
    try std.testing.expectEqual(SuspiciousStewEffect.saturation, stew_ns.effect);
    try std.testing.expectApproxEqAbs(@as(f32, 0.35), stew_ns.duration_seconds, 1e-4);
}

test "17. SwampFlora: water-edge clay patch generation and depth constraints" {
    // Valid: shallow water (depth 1..3) near edge
    try std.testing.expect(canGenerateClayPatch(1, true));
    try std.testing.expect(canGenerateClayPatch(2, true));
    try std.testing.expect(canGenerateClayPatch(3, true));
    try std.testing.expect(SwampFlora.canGenerateClayPatch(2, true));

    // Invalid: too deep (> 3) or not near water edge
    try std.testing.expect(!canGenerateClayPatch(4, true));
    try std.testing.expect(!canGenerateClayPatch(2, false));
    try std.testing.expect(!canGenerateClayPatch(0, true)); // depth 0 is dry land

    const patch = generateClayPatch(12, 62, -40, 3, 2);
    try std.testing.expectEqual(@as(i32, 12), patch.center_x);
    try std.testing.expectEqual(@as(u8, 3), patch.radius);
    try std.testing.expectEqual(@as(u8, 2), patch.depth);
    try std.testing.expect(patch.blockCountEstimate() > 40);
}

test "18. SwampFlora: dead bushes and vine-draped oak tree foliage generation" {
    // Dead bushes in swamp on dirt/mud/clay
    try std.testing.expect(canGenerateDeadBushInSwamp(true, true));
    try std.testing.expect(SwampFlora.canGenerateDeadBush(true, true));
    try std.testing.expect(!canGenerateDeadBushInSwamp(true, false));
    try std.testing.expect(!canGenerateDeadBushInSwamp(false, true));

    // Vine-draped swamp oak tree structure
    const tree = SwampOakTree.generate(6, 3);
    try std.testing.expectEqual(@as(u8, 6), tree.trunk_height);
    try std.testing.expectEqual(@as(u8, 3), tree.leaf_radius);
    try std.testing.expect(tree.vines_hanging);

    // Vines hang from perimeter of canopy
    try std.testing.expect(SwampOakTree.hasDrapedVineAtEdge(3, 3));
    try std.testing.expect(!SwampOakTree.hasDrapedVineAtEdge(1, 3));
}
