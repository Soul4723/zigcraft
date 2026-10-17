//! Ice Spikes Biome, Towering Packed-Ice Spires, Ice Slipperiness Tiers & Boat Highway Physics
//!
//! Milestone 388: Implementation of the rare Ice Spikes biome (a frosty variant of
//! Snowy Plains), towering procedural packed-ice spires, precise ice slipperiness
//! friction tiers, artificial light melting mechanics, 9:1 compression recipes,
//! and high-speed boat ice highway physics.

const std = @import("std");

// ============================================================================
// 1. Ice Kinds & Slipperiness / Friction Tiers
// ============================================================================

/// Normal block standard slipperiness factor in Minecraft physics.
pub const NORMAL_BLOCK_SLIPPERINESS: f32 = 0.6;

/// Regular ice slipperiness factor.
pub const REGULAR_ICE_SLIPPERINESS: f32 = 0.98;

/// Packed ice slipperiness factor (same friction as regular ice).
pub const PACKED_ICE_SLIPPERINESS: f32 = 0.98;

/// Blue ice slipperiness factor (super slick, used for extreme-speed transit).
pub const BLUE_ICE_SLIPPERINESS: f32 = 0.989;

/// Frosted ice slipperiness factor (created by Frost Walker enchantment).
pub const FROSTED_ICE_SLIPPERINESS: f32 = 0.98;

/// Types of ice blocks in the voxel engine.
pub const IceKind = enum {
    frosted_ice,
    regular_ice,
    packed_ice,
    blue_ice,

    /// Slipperiness factor affecting player walk/slide velocity and entity physics.
    pub fn slipperiness(self: IceKind) f32 {
        return switch (self) {
            .frosted_ice => FROSTED_ICE_SLIPPERINESS,
            .regular_ice => REGULAR_ICE_SLIPPERINESS,
            .packed_ice => PACKED_ICE_SLIPPERINESS,
            .blue_ice => BLUE_ICE_SLIPPERINESS,
        };
    }

    /// Friction factor is synonymous with slipperiness factor in Minecraft mechanics.
    pub fn friction(self: IceKind) f32 {
        return self.slipperiness();
    }

    /// Display name of the ice block.
    pub fn name(self: IceKind) []const u8 {
        return switch (self) {
            .frosted_ice => "Frosted Ice",
            .regular_ice => "Ice",
            .packed_ice => "Packed Ice",
            .blue_ice => "Blue Ice",
        };
    }

    /// Light emitted by this ice block. Blue ice emits a soft glow (light level 4).
    pub fn luminance(self: IceKind) u4 {
        return switch (self) {
            .blue_ice => 4,
            .regular_ice, .packed_ice, .frosted_ice => 0,
        };
    }

    /// Visual transparency: regular and frosted ice are translucent; packed and blue ice are opaque.
    pub fn isTransparent(self: IceKind) bool {
        return switch (self) {
            .regular_ice, .frosted_ice => true,
            .packed_ice, .blue_ice => false,
        };
    }

    /// All ice variants are solid blocks for collision purposes.
    pub fn isSolid(self: IceKind) bool {
        _ = self;
        return true;
    }
};

/// Returns the friction / slipperiness factor for a surface block.
/// Returns `0.6` for non-ice blocks (represented by `null`).
pub fn getBlockFriction(maybe_ice: ?IceKind) f32 {
    if (maybe_ice) |ice| {
        return ice.friction();
    }
    return NORMAL_BLOCK_SLIPPERINESS;
}

// ============================================================================
// 2. Ice Melting Mechanics
// ============================================================================

/// Light threshold for artificial light melting. Regular and frosted ice melt
/// when block light is at or above this value.
pub const MELT_LIGHT_THRESHOLD: u4 = 12;

/// Rules governing thermal phase changes of ice blocks.
pub const IceMeltingRule = struct {
    pub const threshold_light: u4 = MELT_LIGHT_THRESHOLD;

    /// Checks if an ice block melts at a given artificial block light level.
    ///
    /// .regular_ice and .frosted_ice melt into water when block light >= 12 (excluding sunlight).
    /// .packed_ice and .blue_ice NEVER melt from artificial light.
    pub fn meltsAtBlockLight(kind: IceKind, block_light: u4) bool {
        return switch (kind) {
            .regular_ice, .frosted_ice => block_light >= threshold_light,
            .packed_ice, .blue_ice => false,
        };
    }

    /// The outcome of an ice block melting.
    pub const MeltOutcome = enum {
        none,
        water,
        evaporated_to_air,
    };

    /// Evaluates the outcome of ice melting, accounting for the Nether dimension
    /// where water instantly vaporizes into air.
    pub fn evaluateMelting(kind: IceKind, block_light: u4, in_nether: bool) MeltOutcome {
        if (!IceMeltingRule.meltsAtBlockLight(kind, block_light)) return .none;
        if (in_nether) return .evaporated_to_air;
        return .water;
    }
};

/// Standalone helper matching the exact required signature:
/// `meltsAtBlockLight(kind: IceKind, block_light: u4) bool`
pub fn meltsAtBlockLight(kind: IceKind, block_light: u4) bool {
    return IceMeltingRule.meltsAtBlockLight(kind, block_light);
}

// ============================================================================
// 3. Ice Compression Recipes (9:1 Crafting)
// ============================================================================

/// 9-to-1 crafting compression recipes for packed ice and blue ice.
pub const IceCompressionRecipe = struct {
    pub const regular_per_packed: u32 = 9;
    pub const packed_per_blue: u32 = 9;
    pub const regular_per_blue: u32 = 81; // 9 * 9 = 81 regular ice per blue ice

    /// Crafts packed ice from regular ice (9:1 ratio).
    pub fn craftPackedIce(regular_ice_count: u32) u32 {
        return regular_ice_count / regular_per_packed;
    }

    /// Remainder of regular ice after crafting packed ice.
    pub fn regularIceRemainder(regular_ice_count: u32) u32 {
        return regular_ice_count % regular_per_packed;
    }

    /// Crafts blue ice from packed ice (9:1 ratio).
    pub fn craftBlueIce(packed_ice_count: u32) u32 {
        return packed_ice_count / packed_per_blue;
    }

    /// Remainder of packed ice after crafting blue ice.
    pub fn packedIceRemainder(packed_ice_count: u32) u32 {
        return packed_ice_count % packed_per_blue;
    }

    /// Direct conversion from regular ice to blue ice (81:1 ratio).
    pub fn craftBlueIceFromRegular(regular_ice_count: u32) u32 {
        return regular_ice_count / regular_per_blue;
    }

    /// Remainder of regular ice when crafting directly to blue ice.
    pub fn regularIceRemainderForBlue(regular_ice_count: u32) u32 {
        return regular_ice_count % regular_per_blue;
    }

    /// Generic compression result.
    pub const CompressionResult = struct {
        output: IceKind,
        output_count: u32,
        remainder: u32,
    };

    /// Compresses ice of a given kind into the next tier.
    pub fn compress(source: IceKind, count: u32) ?CompressionResult {
        return switch (source) {
            .regular_ice => .{
                .output = .packed_ice,
                .output_count = count / regular_per_packed,
                .remainder = count % regular_per_packed,
            },
            .packed_ice => .{
                .output = .blue_ice,
                .output_count = count / packed_per_blue,
                .remainder = count % packed_per_blue,
            },
            .blue_ice, .frosted_ice => null,
        };
    }

    /// Validates a 3x3 (9-slot) crafting table grid.
    /// Returns the crafted ice kind if all 9 slots contain the same compressible ice.
    pub fn craftGrid(grid: [9]?IceKind) ?IceKind {
        var base_kind: ?IceKind = null;
        for (grid) |slot| {
            const kind = slot orelse return null;
            if (base_kind) |expected| {
                if (kind != expected) return null;
            } else {
                base_kind = kind;
            }
        }
        const k = base_kind orelse return null;
        return switch (k) {
            .regular_ice => .packed_ice,
            .packed_ice => .blue_ice,
            else => null,
        };
    }
};

// ============================================================================
// 4. Boat Ice Highway Speeds & Kinematics
// ============================================================================

/// Kinematics and terminal speeds for boats on various surfaces.
/// In Minecraft, boat ice highways allow ultra-rapid travel across worlds.
pub const BoatIceHighwaySpeed = struct {
    /// Top boat speed on water: 8.0 m/s (blocks/second).
    pub const water_speed: f32 = 8.0;

    /// Top boat speed on regular ice and packed ice: 40.0 m/s.
    pub const regular_ice_speed: f32 = 40.0;
    pub const packed_ice_speed: f32 = 40.0;

    /// Top boat speed on blue ice: 72.73 m/s.
    pub const blue_ice_speed: f32 = 72.73;

    /// Overland boat speed on non-slippery ground (dirt, stone, grass).
    pub const land_speed: f32 = 1.4;

    /// Surface types that a boat can navigate.
    pub const Surface = enum {
        water,
        regular_ice,
        packed_ice,
        blue_ice,
        frosted_ice,
        land,
    };

    /// Returns top terminal velocity in meters per second for the specified surface.
    pub fn topSpeedForSurface(surface: Surface) f32 {
        return switch (surface) {
            .water => water_speed,
            .regular_ice, .packed_ice, .frosted_ice => regular_ice_speed,
            .blue_ice => blue_ice_speed,
            .land => land_speed,
        };
    }

    /// Returns top boat speed given an optional `IceKind` (null defaults to water).
    pub fn topSpeedForIce(ice: ?IceKind) f32 {
        if (ice) |k| {
            return switch (k) {
                .regular_ice, .packed_ice, .frosted_ice => regular_ice_speed,
                .blue_ice => blue_ice_speed,
            };
        }
        return water_speed;
    }

    /// Computes travel duration in seconds to traverse a distance in meters at top speed.
    pub fn travelTimeSeconds(distance_meters: f32, surface: Surface) f32 {
        const speed = topSpeedForSurface(surface);
        if (speed <= 0.0) return std.math.inf(f32);
        return distance_meters / speed;
    }

    /// Relative speed multiplier compared to navigating on open water.
    pub fn speedMultiplierOverWater(surface: Surface) f32 {
        return topSpeedForSurface(surface) / water_speed;
    }

    /// Advances boat speed along a highway for a time step `dt` towards terminal speed.
    pub fn stepVelocity(current_speed: f32, surface: Surface, dt: f32) f32 {
        const target = topSpeedForSurface(surface);
        const accel: f32 = switch (surface) {
            .blue_ice => 36.0,
            .regular_ice, .packed_ice, .frosted_ice => 24.0,
            .water => 8.0,
            .land => 2.0,
        };
        if (current_speed < target) {
            return @min(target, current_speed + accel * dt);
        } else if (current_speed > target) {
            const decel: f32 = 16.0;
            return @max(target, current_speed - decel * dt);
        }
        return current_speed;
    }
};

// ============================================================================
// 5. Ice Spikes & Spire Procedural Generation
// ============================================================================

/// Ice spike architectural classification.
pub const IceSpikeType = enum {
    /// Short thick spires: height 10..18, base radius 3..4.
    short_thick_spire,
    /// Tall thin needles: height 30..50, base radius 1..2.
    tall_thin_needle,

    pub const HeightRange = struct {
        min: u8,
        max: u8,
    };

    pub const RadiusRange = struct {
        min: u4,
        max: u4,
    };

    /// Allowed height range for this spike category.
    pub fn heightRange(self: IceSpikeType) HeightRange {
        return switch (self) {
            .short_thick_spire => .{ .min = 10, .max = 18 },
            .tall_thin_needle => .{ .min = 30, .max = 50 },
        };
    }

    /// Allowed base radius range for this spike category.
    pub fn baseRadiusRange(self: IceSpikeType) RadiusRange {
        return switch (self) {
            .short_thick_spire => .{ .min = 3, .max = 4 },
            .tall_thin_needle => .{ .min = 1, .max = 2 },
        };
    }

    /// Material composition of all ice spikes is 100% packed ice.
    pub fn composition(self: IceSpikeType) IceKind {
        _ = self;
        return .packed_ice;
    }

    /// Validates whether a given height is within the legal range.
    pub fn isValidHeight(self: IceSpikeType, h: u8) bool {
        const r = self.heightRange();
        return h >= r.min and h <= r.max;
    }

    /// Validates whether a given base radius is within the legal range.
    pub fn isValidBaseRadius(self: IceSpikeType, r: u4) bool {
        const range = self.baseRadiusRange();
        return r >= range.min and r <= range.max;
    }
};

/// Procedural representation of a packed ice spike.
pub const IceSpike = struct {
    spike_type: IceSpikeType,
    height: u8,
    base_radius: u4,
    center_x: i32,
    center_y: i32,
    center_z: i32,
    composition: IceKind = .packed_ice,

    pub const InitError = error{
        InvalidHeight,
        InvalidRadius,
    };

    /// Creates and validates an ice spike.
    pub fn init(
        spike_type: IceSpikeType,
        height: u8,
        base_radius: u4,
        x: i32,
        y: i32,
        z: i32,
    ) InitError!IceSpike {
        if (!spike_type.isValidHeight(height)) return error.InvalidHeight;
        if (!spike_type.isValidBaseRadius(base_radius)) return error.InvalidRadius;
        return .{
            .spike_type = spike_type,
            .height = height,
            .base_radius = base_radius,
            .center_x = x,
            .center_y = y,
            .center_z = z,
            .composition = .packed_ice,
        };
    }

    /// Generates deterministic dimensions for an ice spike using a 64-bit seed and coordinates.
    pub fn generateDeterministic(
        spike_type: IceSpikeType,
        seed: u64,
        x: i32,
        y: i32,
        z: i32,
    ) IceSpike {
        // Simple fast integer mixing hash (splitmix64 style)
        var h = seed ^ (@as(u64, @bitCast(@as(i64, x))) *% 0x9E3779B97F4A7C15);
        h = (h ^ (h >> 30)) *% 0xBF58476D1CE4E5B9;
        h ^= (@as(u64, @bitCast(@as(i64, z))) *% 0x94D049BB133111EB);
        h = (h ^ (h >> 27)) *% 0x94D049BB133111EB;
        h ^= (h >> 31);

        const hr = spike_type.heightRange();
        const height_span = hr.max - hr.min + 1;
        const height: u8 = hr.min + @as(u8, @intCast(h % height_span));

        const rr = spike_type.baseRadiusRange();
        const rad_span = rr.max - rr.min + 1;
        const base_radius: u4 = rr.min + @as(u4, @intCast((h >> 16) % rad_span));

        return .{
            .spike_type = spike_type,
            .height = height,
            .base_radius = base_radius,
            .center_x = x,
            .center_y = y,
            .center_z = z,
            .composition = .packed_ice,
        };
    }

    /// Computes the cross-sectional radius at vertical offset `dy` (from 0 to `height`).
    /// Tapers linearly from `base_radius` at base (dy=0) down to 0 at tip (dy=height).
    pub fn radiusAt(self: IceSpike, dy: u8) f32 {
        if (dy >= self.height) return 0.0;
        const progress = @as(f32, @floatFromInt(dy)) / @as(f32, @floatFromInt(self.height));
        const base_r = @as(f32, @floatFromInt(self.base_radius));
        return base_r * (1.0 - progress);
    }

    /// Checks if a world block coordinate (bx, by, bz) is part of this spike.
    pub fn containsBlock(self: IceSpike, bx: i32, by: i32, bz: i32) bool {
        if (by < self.center_y or by >= self.center_y + @as(i32, @intCast(self.height))) {
            return false;
        }
        const dy: u8 = @intCast(by - self.center_y);
        const r = self.radiusAt(dy);
        const dx = @as(f32, @floatFromInt(bx - self.center_x));
        const dz = @as(f32, @floatFromInt(bz - self.center_z));
        // Cylindrical distance with half-block voxel tolerance
        return (dx * dx + dz * dz) <= (r * r + 0.25);
    }

    /// Counts total packed ice blocks making up the entire spire.
    pub fn countBlocks(self: IceSpike) usize {
        var count: usize = 0;
        var dy: u8 = 0;
        while (dy < self.height) : (dy += 1) {
            const r = self.radiusAt(dy);
            const ir: i32 = @intFromFloat(@ceil(r));
            var dx: i32 = -ir;
            while (dx <= ir) : (dx += 1) {
                var dz: i32 = -ir;
                while (dz <= ir) : (dz += 1) {
                    const fdx = @as(f32, @floatFromInt(dx));
                    const fdz = @as(f32, @floatFromInt(dz));
                    if (fdx * fdx + fdz * fdz <= (r * r + 0.25)) {
                        count += 1;
                    }
                }
            }
        }
        return count;
    }
};

// ============================================================================
// 6. Ice Spikes Biome Environmental Configuration
// ============================================================================

/// Environmental parameters of the Ice Spikes biome.
pub const IceSpikesBiome = struct {
    pub const id: []const u8 = "minecraft:ice_spikes";
    pub const name: []const u8 = "Ice Spikes";

    /// Freezing temperature (0.0).
    pub const temperature: f32 = 0.0;

    /// Downfall rating (0.5), falling entirely as snowfall.
    pub const downfall: f32 = 0.5;

    /// Precipitation falls as snow in this sub-zero biome.
    pub const snowfall: bool = true;

    /// Atmospheric colors (RGB packed integers).
    pub const sky_color: u32 = 0x7CAFC6;
    pub const fog_color: u32 = 0xC0D8FF;
    pub const water_color: u32 = 0x3938C9;
    pub const water_fog_color: u32 = 0x050533;

    /// Primary surface terrain material.
    pub const surface_block: []const u8 = "snow_block";
    pub const sub_surface_block: []const u8 = "dirt";
    pub const spire_block: []const u8 = "packed_ice";

    /// Approximately 2% (1 in 50) of generated spikes are towering needles.
    pub const tall_needle_chance_percent: u8 = 2;

    /// Chooses spike type based on a percentage roll in 0..99.
    pub fn selectSpikeType(roll_0_to_99: u8) IceSpikeType {
        if (roll_0_to_99 < tall_needle_chance_percent) {
            return .tall_thin_needle;
        }
        return .short_thick_spire;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "1. IceSpikeType short_thick_spire bounds (height 10..18, radius 3..4)" {
    const spike_type = IceSpikeType.short_thick_spire;
    const hr = spike_type.heightRange();
    const rr = spike_type.baseRadiusRange();

    try std.testing.expectEqual(@as(u8, 10), hr.min);
    try std.testing.expectEqual(@as(u8, 18), hr.max);
    try std.testing.expectEqual(@as(u4, 3), rr.min);
    try std.testing.expectEqual(@as(u4, 4), rr.max);

    try std.testing.expect(spike_type.isValidHeight(10));
    try std.testing.expect(spike_type.isValidHeight(14));
    try std.testing.expect(spike_type.isValidHeight(18));
    try std.testing.expect(!spike_type.isValidHeight(9));
    try std.testing.expect(!spike_type.isValidHeight(19));

    try std.testing.expect(spike_type.isValidBaseRadius(3));
    try std.testing.expect(spike_type.isValidBaseRadius(4));
    try std.testing.expect(!spike_type.isValidBaseRadius(2));
    try std.testing.expect(!spike_type.isValidBaseRadius(5));
}

test "2. IceSpikeType tall_thin_needle bounds (height 30..50, radius 1..2)" {
    const needle_type = IceSpikeType.tall_thin_needle;
    const hr = needle_type.heightRange();
    const rr = needle_type.baseRadiusRange();

    try std.testing.expectEqual(@as(u8, 30), hr.min);
    try std.testing.expectEqual(@as(u8, 50), hr.max);
    try std.testing.expectEqual(@as(u4, 1), rr.min);
    try std.testing.expectEqual(@as(u4, 2), rr.max);

    try std.testing.expect(needle_type.isValidHeight(30));
    try std.testing.expect(needle_type.isValidHeight(42));
    try std.testing.expect(needle_type.isValidHeight(50));
    try std.testing.expect(!needle_type.isValidHeight(29));
    try std.testing.expect(!needle_type.isValidHeight(51));

    try std.testing.expect(needle_type.isValidBaseRadius(1));
    try std.testing.expect(needle_type.isValidBaseRadius(2));
    try std.testing.expect(!needle_type.isValidBaseRadius(0));
    try std.testing.expect(!needle_type.isValidBaseRadius(3));
}

test "3. IceSpike composition is entirely packed_ice" {
    try std.testing.expectEqual(IceKind.packed_ice, IceSpikeType.short_thick_spire.composition());
    try std.testing.expectEqual(IceKind.packed_ice, IceSpikeType.tall_thin_needle.composition());

    const spike = try IceSpike.init(.short_thick_spire, 15, 3, 10, 64, 10);
    try std.testing.expectEqual(IceKind.packed_ice, spike.composition);
}

test "4. IceSpike init validation rejects invalid dimensions" {
    try std.testing.expectError(error.InvalidHeight, IceSpike.init(.short_thick_spire, 5, 3, 0, 64, 0));
    try std.testing.expectError(error.InvalidRadius, IceSpike.init(.short_thick_spire, 15, 2, 0, 64, 0));
    try std.testing.expectError(error.InvalidHeight, IceSpike.init(.tall_thin_needle, 25, 2, 0, 64, 0));
    try std.testing.expectError(error.InvalidRadius, IceSpike.init(.tall_thin_needle, 40, 3, 0, 64, 0));

    const valid = try IceSpike.init(.tall_thin_needle, 45, 2, 100, 64, 200);
    try std.testing.expectEqual(@as(u8, 45), valid.height);
    try std.testing.expectEqual(@as(u4, 2), valid.base_radius);
}

test "5. IceSpike geometry tapers from base to tip" {
    const spike = try IceSpike.init(.short_thick_spire, 16, 4, 0, 60, 0);

    // At base (dy = 0), radius is 4.0
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), spike.radiusAt(0), 0.001);
    // At mid-height (dy = 8), radius is 2.0
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), spike.radiusAt(8), 0.001);
    // At near top (dy = 12), radius is 1.0
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), spike.radiusAt(12), 0.001);
    // At tip (dy = 16), radius is 0.0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), spike.radiusAt(16), 0.001);

    // Center block at base is contained
    try std.testing.expect(spike.containsBlock(0, 60, 0));
    // Center block at tip height is contained (tip center)
    try std.testing.expect(spike.containsBlock(0, 75, 0));
    // Outside height bounds is not contained
    try std.testing.expect(!spike.containsBlock(0, 59, 0));
    try std.testing.expect(!spike.containsBlock(0, 76, 0));
    // Block far horizontally is not contained
    try std.testing.expect(!spike.containsBlock(10, 60, 0));
}

test "6. IceSpike deterministic generation produces legal spires" {
    var seed: u64 = 123456789;
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        seed +%= 0xDEADBEEF;
        const x: i32 = @intCast(@as(i64, @intCast(i)) * 32 - 100);
        const z: i32 = @intCast(@as(i64, @intCast(i)) * -48 + 50);

        const short_spire = IceSpike.generateDeterministic(.short_thick_spire, seed, x, 64, z);
        try std.testing.expect(IceSpikeType.short_thick_spire.isValidHeight(short_spire.height));
        try std.testing.expect(IceSpikeType.short_thick_spire.isValidBaseRadius(short_spire.base_radius));
        try std.testing.expectEqual(IceKind.packed_ice, short_spire.composition);

        const tall_needle = IceSpike.generateDeterministic(.tall_thin_needle, seed, x, 64, z);
        try std.testing.expect(IceSpikeType.tall_thin_needle.isValidHeight(tall_needle.height));
        try std.testing.expect(IceSpikeType.tall_thin_needle.isValidBaseRadius(tall_needle.base_radius));
        try std.testing.expectEqual(IceKind.packed_ice, tall_needle.composition);
    }
}

test "7. IceKind slipperiness and friction factors match exact specifications" {
    try std.testing.expectEqual(@as(f32, 0.98), IceKind.regular_ice.slipperiness());
    try std.testing.expectEqual(@as(f32, 0.98), IceKind.packed_ice.slipperiness());
    try std.testing.expectEqual(@as(f32, 0.989), IceKind.blue_ice.slipperiness());
    try std.testing.expectEqual(@as(f32, 0.98), IceKind.frosted_ice.slipperiness());

    // Friction synonym check
    try std.testing.expectEqual(IceKind.regular_ice.slipperiness(), IceKind.regular_ice.friction());
    try std.testing.expectEqual(IceKind.packed_ice.slipperiness(), IceKind.packed_ice.friction());
    try std.testing.expectEqual(IceKind.blue_ice.slipperiness(), IceKind.blue_ice.friction());
    try std.testing.expectEqual(IceKind.frosted_ice.slipperiness(), IceKind.frosted_ice.friction());

    // Blue ice is strictly more slippery than packed/regular ice
    try std.testing.expect(IceKind.blue_ice.slipperiness() > IceKind.packed_ice.slipperiness());
    try std.testing.expect(IceKind.packed_ice.slipperiness() > NORMAL_BLOCK_SLIPPERINESS);
}

test "8. Normal block slipperiness is 0.6 and getBlockFriction fallback" {
    try std.testing.expectEqual(@as(f32, 0.6), NORMAL_BLOCK_SLIPPERINESS);
    try std.testing.expectEqual(@as(f32, 0.6), getBlockFriction(null));
    try std.testing.expectEqual(@as(f32, 0.98), getBlockFriction(.regular_ice));
    try std.testing.expectEqual(@as(f32, 0.98), getBlockFriction(.packed_ice));
    try std.testing.expectEqual(@as(f32, 0.989), getBlockFriction(.blue_ice));
    try std.testing.expectEqual(@as(f32, 0.98), getBlockFriction(.frosted_ice));
}

test "9. IceMeltingRule: regular and frosted ice melt at block light >= 12" {
    // Tests levels 12 through 15
    var light: u4 = 12;
    while (true) {
        try std.testing.expect(IceMeltingRule.meltsAtBlockLight(.regular_ice, light));
        try std.testing.expect(IceMeltingRule.meltsAtBlockLight(.frosted_ice, light));
        try std.testing.expect(meltsAtBlockLight(.regular_ice, light));
        try std.testing.expect(meltsAtBlockLight(.frosted_ice, light));
        if (light == 15) break;
        light += 1;
    }
}

test "10. IceMeltingRule: regular and frosted ice stay solid below block light 12" {
    // Tests levels 0 through 11
    var light: u4 = 0;
    while (light < 12) : (light += 1) {
        try std.testing.expect(!IceMeltingRule.meltsAtBlockLight(.regular_ice, light));
        try std.testing.expect(!IceMeltingRule.meltsAtBlockLight(.frosted_ice, light));
        try std.testing.expect(!meltsAtBlockLight(.regular_ice, light));
        try std.testing.expect(!meltsAtBlockLight(.frosted_ice, light));
    }
}

test "11. IceMeltingRule: packed and blue ice NEVER melt at any light level" {
    var light: u4 = 0;
    while (true) {
        try std.testing.expect(!IceMeltingRule.meltsAtBlockLight(.packed_ice, light));
        try std.testing.expect(!IceMeltingRule.meltsAtBlockLight(.blue_ice, light));
        try std.testing.expect(!meltsAtBlockLight(.packed_ice, light));
        try std.testing.expect(!meltsAtBlockLight(.blue_ice, light));
        if (light == 15) break;
        light += 1;
    }
}

test "12. IceMeltingRule: evaluateMelting handles overworld water vs Nether air" {
    // Regular ice in Overworld at light 14 melts to water
    try std.testing.expectEqual(IceMeltingRule.MeltOutcome.water, IceMeltingRule.evaluateMelting(.regular_ice, 14, false));
    // Regular ice in Nether at light 14 evaporates to air
    try std.testing.expectEqual(IceMeltingRule.MeltOutcome.evaporated_to_air, IceMeltingRule.evaluateMelting(.regular_ice, 14, true));
    // Below threshold yields .none
    try std.testing.expectEqual(IceMeltingRule.MeltOutcome.none, IceMeltingRule.evaluateMelting(.regular_ice, 10, false));
    // Packed ice never melts anywhere
    try std.testing.expectEqual(IceMeltingRule.MeltOutcome.none, IceMeltingRule.evaluateMelting(.packed_ice, 15, false));
    try std.testing.expectEqual(IceMeltingRule.MeltOutcome.none, IceMeltingRule.evaluateMelting(.blue_ice, 15, true));
}

test "13. IceCompressionRecipe: 9 regular ice craft 1 packed ice" {
    try std.testing.expectEqual(@as(u32, 0), IceCompressionRecipe.craftPackedIce(8));
    try std.testing.expectEqual(@as(u32, 8), IceCompressionRecipe.regularIceRemainder(8));

    try std.testing.expectEqual(@as(u32, 1), IceCompressionRecipe.craftPackedIce(9));
    try std.testing.expectEqual(@as(u32, 0), IceCompressionRecipe.regularIceRemainder(9));

    try std.testing.expectEqual(@as(u32, 2), IceCompressionRecipe.craftPackedIce(20));
    try std.testing.expectEqual(@as(u32, 2), IceCompressionRecipe.regularIceRemainder(20));

    try std.testing.expectEqual(@as(u32, 7), IceCompressionRecipe.craftPackedIce(64));
    try std.testing.expectEqual(@as(u32, 1), IceCompressionRecipe.regularIceRemainder(64));
}

test "14. IceCompressionRecipe: 9 packed ice craft 1 blue ice" {
    try std.testing.expectEqual(@as(u32, 0), IceCompressionRecipe.craftBlueIce(8));
    try std.testing.expectEqual(@as(u32, 8), IceCompressionRecipe.packedIceRemainder(8));

    try std.testing.expectEqual(@as(u32, 1), IceCompressionRecipe.craftBlueIce(9));
    try std.testing.expectEqual(@as(u32, 0), IceCompressionRecipe.packedIceRemainder(9));

    try std.testing.expectEqual(@as(u32, 5), IceCompressionRecipe.craftBlueIce(49));
    try std.testing.expectEqual(@as(u32, 4), IceCompressionRecipe.packedIceRemainder(49));
}

test "15. IceCompressionRecipe: 81 regular ice per blue ice transitive ratio" {
    try std.testing.expectEqual(@as(u32, 81), IceCompressionRecipe.regular_per_blue);
    try std.testing.expectEqual(@as(u32, 0), IceCompressionRecipe.craftBlueIceFromRegular(80));
    try std.testing.expectEqual(@as(u32, 80), IceCompressionRecipe.regularIceRemainderForBlue(80));

    try std.testing.expectEqual(@as(u32, 1), IceCompressionRecipe.craftBlueIceFromRegular(81));
    try std.testing.expectEqual(@as(u32, 0), IceCompressionRecipe.regularIceRemainderForBlue(81));

    try std.testing.expectEqual(@as(u32, 2), IceCompressionRecipe.craftBlueIceFromRegular(163));
    try std.testing.expectEqual(@as(u32, 1), IceCompressionRecipe.regularIceRemainderForBlue(163));
}

test "16. IceCompressionRecipe: 3x3 crafting grid compression" {
    const regular_grid = [_]?IceKind{.regular_ice} ** 9;
    try std.testing.expectEqual(IceKind.packed_ice, IceCompressionRecipe.craftGrid(regular_grid).?);

    const packed_grid = [_]?IceKind{.packed_ice} ** 9;
    try std.testing.expectEqual(IceKind.blue_ice, IceCompressionRecipe.craftGrid(packed_grid).?);

    // Incomplete grid (one empty slot) cannot craft
    var incomplete_grid = regular_grid;
    incomplete_grid[4] = null;
    try std.testing.expect(IceCompressionRecipe.craftGrid(incomplete_grid) == null);

    // Mixed grid cannot craft
    var mixed_grid = regular_grid;
    mixed_grid[0] = .packed_ice;
    try std.testing.expect(IceCompressionRecipe.craftGrid(mixed_grid) == null);

    // Blue ice cannot compress further
    const blue_grid = [_]?IceKind{.blue_ice} ** 9;
    try std.testing.expect(IceCompressionRecipe.craftGrid(blue_grid) == null);
}

test "17. BoatIceHighwaySpeed: exact top speeds across surfaces" {
    try std.testing.expectEqual(@as(f32, 8.0), BoatIceHighwaySpeed.water_speed);
    try std.testing.expectEqual(@as(f32, 40.0), BoatIceHighwaySpeed.regular_ice_speed);
    try std.testing.expectEqual(@as(f32, 40.0), BoatIceHighwaySpeed.packed_ice_speed);
    try std.testing.expectEqual(@as(f32, 72.73), BoatIceHighwaySpeed.blue_ice_speed);

    try std.testing.expectEqual(@as(f32, 8.0), BoatIceHighwaySpeed.topSpeedForSurface(.water));
    try std.testing.expectEqual(@as(f32, 40.0), BoatIceHighwaySpeed.topSpeedForSurface(.regular_ice));
    try std.testing.expectEqual(@as(f32, 40.0), BoatIceHighwaySpeed.topSpeedForSurface(.packed_ice));
    try std.testing.expectEqual(@as(f32, 72.73), BoatIceHighwaySpeed.topSpeedForSurface(.blue_ice));
    try std.testing.expectEqual(@as(f32, 1.4), BoatIceHighwaySpeed.topSpeedForSurface(.land));

    try std.testing.expectEqual(@as(f32, 40.0), BoatIceHighwaySpeed.topSpeedForIce(.regular_ice));
    try std.testing.expectEqual(@as(f32, 40.0), BoatIceHighwaySpeed.topSpeedForIce(.packed_ice));
    try std.testing.expectEqual(@as(f32, 72.73), BoatIceHighwaySpeed.topSpeedForIce(.blue_ice));
    try std.testing.expectEqual(@as(f32, 8.0), BoatIceHighwaySpeed.topSpeedForIce(null));
}

test "18. BoatIceHighwaySpeed: travel time over 1000m highway" {
    const dist: f32 = 1000.0;
    const water_time = BoatIceHighwaySpeed.travelTimeSeconds(dist, .water);
    const packed_time = BoatIceHighwaySpeed.travelTimeSeconds(dist, .packed_ice);
    const blue_time = BoatIceHighwaySpeed.travelTimeSeconds(dist, .blue_ice);

    // 1000m / 8 m/s = 125 seconds
    try std.testing.expectApproxEqAbs(@as(f32, 125.0), water_time, 0.01);
    // 1000m / 40 m/s = 25 seconds (5x faster than water!)
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), packed_time, 0.01);
    // 1000m / 72.73 m/s ~= 13.75 seconds (> 9x faster than water!)
    try std.testing.expectApproxEqAbs(@as(f32, 13.749484), blue_time, 0.01);

    try std.testing.expect(blue_time < packed_time);
    try std.testing.expect(packed_time < water_time);
}

test "19. BoatIceHighwaySpeed: speed multiplier and velocity stepping" {
    // 40 / 8 = 5.0x
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), BoatIceHighwaySpeed.speedMultiplierOverWater(.packed_ice), 0.001);
    // 72.73 / 8 ~= 9.09x
    try std.testing.expectApproxEqAbs(@as(f32, 9.09125), BoatIceHighwaySpeed.speedMultiplierOverWater(.blue_ice), 0.001);

    // Acceleration step
    var v: f32 = 0.0;
    v = BoatIceHighwaySpeed.stepVelocity(v, .blue_ice, 1.0);
    try std.testing.expect(v > 0.0);
    try std.testing.expect(v <= 72.73);

    // Deceleration down to land speed when sliding off ice
    v = 40.0;
    v = BoatIceHighwaySpeed.stepVelocity(v, .land, 1.0);
    try std.testing.expect(v < 40.0);
    try std.testing.expect(v >= 1.4);
}

test "20. IceSpikesBiome environmental configuration & type distribution" {
    try std.testing.expectEqualStrings("minecraft:ice_spikes", IceSpikesBiome.id);
    try std.testing.expectEqualStrings("Ice Spikes", IceSpikesBiome.name);
    try std.testing.expectEqual(@as(f32, 0.0), IceSpikesBiome.temperature);
    try std.testing.expectEqual(@as(f32, 0.5), IceSpikesBiome.downfall);
    try std.testing.expect(IceSpikesBiome.snowfall);

    try std.testing.expectEqualStrings("snow_block", IceSpikesBiome.surface_block);
    try std.testing.expectEqualStrings("packed_ice", IceSpikesBiome.spire_block);

    // Rare 2% rolls produce tall needles, 98% rolls produce short thick spires
    try std.testing.expectEqual(IceSpikeType.tall_thin_needle, IceSpikesBiome.selectSpikeType(0));
    try std.testing.expectEqual(IceSpikeType.tall_thin_needle, IceSpikesBiome.selectSpikeType(1));
    try std.testing.expectEqual(IceSpikeType.short_thick_spire, IceSpikesBiome.selectSpikeType(2));
    try std.testing.expectEqual(IceSpikeType.short_thick_spire, IceSpikesBiome.selectSpikeType(50));
    try std.testing.expectEqual(IceSpikeType.short_thick_spire, IceSpikesBiome.selectSpikeType(99));
}

test "21. IceSpike countBlocks yields positive packed ice count" {
    const spire = try IceSpike.init(.short_thick_spire, 10, 3, 0, 60, 0);
    const count = spire.countBlocks();
    // A 10-block high spire with base radius 3 contains substantial volume
    try std.testing.expect(count > 20);
    try std.testing.expect(count < 500);

    const needle = try IceSpike.init(.tall_thin_needle, 30, 1, 0, 60, 0);
    const needle_count = needle.countBlocks();
    // A thin needle has smaller radius but greater height
    try std.testing.expect(needle_count > 10);
}
