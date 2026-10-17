//! Mountain Peaks Biomes, Calcite Strips, High-Altitude Emerald & Iron Ore Scaling, and Freeze Line
//!
//! Milestone 402: Implementation of Mountain Peak sub-biomes (Meadow, Grove,
//! Snowy Slopes, Jagged Peaks, Frozen Peaks, Stony Peaks), Stony Peaks Calcite
//! striping (preventing powder snow hazards while preserving mountain ore density),
//! Mountain Emerald triangular distribution peaking at Y=232 with deepslate
//! emerald ore below Y=0, high-altitude iron and coal generation with air-exposure
//! rules, and altitude temperature lapse freezing mechanics.

const std = @import("std");

// ============================================================================
// 1. Mountain Peak Sub-Biomes & Surface Blocks
// ============================================================================

/// Sub-biomes forming the mountain biome family introduced in Minecraft 1.18.
pub const MountainPeakSubBiome = enum {
    meadow,
    grove,
    snowy_slopes,
    jagged_peaks,
    frozen_peaks,
    stony_peaks,

    /// Base temperature at sea level (Y <= 80) for this sub-biome.
    pub fn baseTemperature(self: MountainPeakSubBiome) f32 {
        return switch (self) {
            .meadow => 0.5,
            .grove => -0.2,
            .snowy_slopes => -0.3,
            .jagged_peaks => -0.7,
            .frozen_peaks => -0.7,
            .stony_peaks => 1.0,
        };
    }

    /// True if this sub-biome represents a high mountain summit.
    pub fn isPeak(self: MountainPeakSubBiome) bool {
        return switch (self) {
            .jagged_peaks, .frozen_peaks, .stony_peaks => true,
            .meadow, .grove, .snowy_slopes => false,
        };
    }

    /// True if this sub-biome represents lower mountain slopes or foot.
    pub fn isSlopeOrBase(self: MountainPeakSubBiome) bool {
        return !self.isPeak();
    }

    /// Whether this sub-biome naturally contains powder snow pockets and hazards.
    pub fn hasPowderSnow(self: MountainPeakSubBiome) bool {
        return switch (self) {
            .grove, .snowy_slopes, .jagged_peaks, .frozen_peaks => true,
            .meadow, .stony_peaks => false,
        };
    }

    /// Whether snow and ice are dominant surface materials in this sub-biome.
    pub fn hasSnowAndIce(self: MountainPeakSubBiome) bool {
        return switch (self) {
            .stony_peaks => false,
            .grove, .snowy_slopes, .jagged_peaks, .frozen_peaks => true,
            .meadow => false,
        };
    }

    /// User-friendly display name.
    pub fn displayName(self: MountainPeakSubBiome) []const u8 {
        return switch (self) {
            .meadow => "Meadow",
            .grove => "Grove",
            .snowy_slopes => "Snowy Slopes",
            .jagged_peaks => "Jagged Peaks",
            .frozen_peaks => "Frozen Peaks",
            .stony_peaks => "Stony Peaks",
        };
    }
};

/// Mountain materials and ore block types.
pub const MountainBlock = enum {
    air,
    stone,
    calcite,
    grass_block,
    dirt,
    snow_block,
    powder_snow,
    ice,
    packed_ice,
    coal_ore,
    iron_ore,
    emerald_ore,
    deepslate_emerald_ore,
    deepslate,
    water,
};

// ============================================================================
// 2. Stony Peaks Calcite Strips
// ============================================================================

/// Stony Peaks mechanics: Replaces surface snow, powder snow, and ice with
/// exposed stone and horizontal bands of calcite. Powder snow hazards are
/// prevented while rich mountain ore generation is completely preserved.
pub const StonyPeaksCalciteStrip = struct {
    pub const CALCITE_BAND_PERIOD: i32 = 16;
    pub const CALCITE_BAND_THICKNESS: i32 = 4;

    /// Checks if a sub-biome generates calcite strip strata.
    pub fn hasCalciteStrips(biome: MountainPeakSubBiome) bool {
        return biome == .stony_peaks;
    }

    /// Evaluates whether a given altitude Y falls within a calcite horizontal band.
    pub fn isCalciteBand(y: i32, seed_offset: i32) bool {
        const offset_y = y +% seed_offset;
        const mod_y = @mod(offset_y, CALCITE_BAND_PERIOD);
        return mod_y < CALCITE_BAND_THICKNESS;
    }

    /// Powder snow hazards are permitted in snowy slopes, groves, and cold peaks,
    /// but strictly forbidden in Stony Peaks.
    pub fn allowsPowderSnow(biome: MountainPeakSubBiome) bool {
        return switch (biome) {
            .stony_peaks => false,
            .grove, .snowy_slopes, .jagged_peaks, .frozen_peaks => true,
            .meadow => false,
        };
    }

    /// Replaces snowy and icy surface blocks in Stony Peaks with stone and calcite bands,
    /// while leaving other biomes and non-ice blocks unaffected.
    pub fn resolveSurfaceBlock(
        biome: MountainPeakSubBiome,
        y: i32,
        seed_offset: i32,
        default_block: MountainBlock,
    ) MountainBlock {
        if (biome != .stony_peaks) return default_block;

        const is_snow_or_ice = switch (default_block) {
            .snow_block, .powder_snow, .ice, .packed_ice => true,
            else => false,
        };

        if (is_snow_or_ice or default_block == .stone) {
            if (isCalciteBand(y, seed_offset)) {
                return .calcite;
            } else {
                return .stone;
            }
        }

        return default_block;
    }
};

/// Top-level helper function checking if a sub-biome has calcite strips.
pub fn hasCalciteStrips(biome: MountainPeakSubBiome) bool {
    return StonyPeaksCalciteStrip.hasCalciteStrips(biome);
}

// ============================================================================
// 3. Mountain Emerald Distribution
// ============================================================================

/// Emerald ore variant classification based on substrate layer.
pub const EmeraldOreType = enum {
    emerald_ore,
    deepslate_emerald_ore,
};

/// Mountain emerald distribution mechanics:
/// - Emerald Ore generates ONLY in mountain and windswept hills biomes.
/// - Valid vertical range: Y = -16..320.
/// - Peaks in triangular density at Y = 232.
/// - Below Y = 0 (Y = -16..-1), generates as rare deepslate_emerald_ore.
pub const MountainEmeraldDistribution = struct {
    pub const MIN_Y: i32 = -16;
    pub const PEAK_Y: i32 = 232;
    pub const MAX_Y: i32 = 320;
    pub const PEAK_WEIGHT: u8 = 100;

    /// Checks if a coordinate is within valid emerald ore generation range.
    pub fn canGenerateEmerald(in_mountain_biome: bool, y: i32) bool {
        if (!in_mountain_biome) return false;
        return y >= MIN_Y and y <= MAX_Y;
    }

    /// Calculates the triangular distribution weight (0..100) for Emerald Ore at altitude Y.
    /// Peaks at Y = 232 with weight 100.
    /// Returns 0 if not in a mountain biome or outside [-16..320].
    pub fn emeraldOreWeightForAltitude(in_mountain_biome: bool, y: i32) u8 {
        if (!in_mountain_biome) return 0;
        if (y < MIN_Y or y > MAX_Y) return 0;
        if (y == PEAK_Y) return PEAK_WEIGHT;

        if (y < PEAK_Y) {
            const span: f32 = @floatFromInt(PEAK_Y - MIN_Y); // 232 - (-16) = 248.0
            const dist: f32 = @floatFromInt(y - MIN_Y);
            const fraction = dist / span;
            const weight = @round(fraction * @as(f32, @floatFromInt(PEAK_WEIGHT)));
            return @intFromFloat(std.math.clamp(weight, 0.0, @as(f32, @floatFromInt(PEAK_WEIGHT))));
        } else {
            const span: f32 = @floatFromInt(MAX_Y - PEAK_Y); // 320 - 232 = 88.0
            const dist: f32 = @floatFromInt(MAX_Y - y);
            const fraction = dist / span;
            const weight = @round(fraction * @as(f32, @floatFromInt(PEAK_WEIGHT)));
            return @intFromFloat(std.math.clamp(weight, 0.0, @as(f32, @floatFromInt(PEAK_WEIGHT))));
        }
    }

    /// Normalized continuous density factor in range [0.0, 1.0].
    pub fn emeraldOreDensity(in_mountain_biome: bool, y: i32) f32 {
        const weight = MountainEmeraldDistribution.emeraldOreWeightForAltitude(in_mountain_biome, y);
        return @as(f32, @floatFromInt(weight)) / 100.0;
    }

    /// Determines the appropriate emerald ore variant:
    /// Returns .deepslate_emerald_ore below Y = 0 (Y = -16..-1),
    /// .emerald_ore for Y = 0..320, or null if outside generation bounds.
    pub fn emeraldOreTypeForAltitude(y: i32) ?EmeraldOreType {
        if (y < MIN_Y or y > MAX_Y) return null;
        if (y < 0) return .deepslate_emerald_ore;
        return .emerald_ore;
    }

    /// Returns corresponding MountainBlock enum.
    pub fn getEmeraldOreBlock(y: i32) ?MountainBlock {
        const variant = emeraldOreTypeForAltitude(y) orelse return null;
        return switch (variant) {
            .emerald_ore => .emerald_ore,
            .deepslate_emerald_ore => .deepslate_emerald_ore,
        };
    }

    /// Deepslate emerald ore is one of the rarest blocks in the game because
    /// mountain biomes rarely reach deep underground and triangular density
    /// is lowest near Y = -16.
    pub fn isDeepslateEmeraldZone(y: i32) bool {
        return y >= MIN_Y and y < 0;
    }
};

/// Top-level export of emeraldOreWeightForAltitude.
pub fn emeraldOreWeightForAltitude(in_mountain_biome: bool, y: i32) u8 {
    return MountainEmeraldDistribution.emeraldOreWeightForAltitude(in_mountain_biome, y);
}

// ============================================================================
// 4. High-Altitude Coal and Iron Ore Scaling
// ============================================================================

/// High-Altitude Iron Ore and Coal Ore distribution mechanics:
/// - Iron Ore has a high-altitude mountain triangular peak at Y = 232 (range Y = 80..320).
/// - Coal Ore has an upper generation band at Y = 136..320.
/// - Coal Ore never generates with air exposure at Y = 0..192, but exposed coal is
///   permitted on high mountain peaks (Y > 192).
pub const HighAltitudeCoalAndIron = struct {
    pub const IRON_MIN_Y: i32 = 80;
    pub const IRON_PEAK_Y: i32 = 232;
    pub const IRON_MAX_Y: i32 = 320;
    pub const IRON_PEAK_WEIGHT: u8 = 100;

    pub const COAL_LOWER_MIN_Y: i32 = 0;
    pub const COAL_NO_AIR_EXPOSURE_MAX_Y: i32 = 192;
    pub const COAL_UPPER_MIN_Y: i32 = 136;
    pub const COAL_MAX_Y: i32 = 320;

    /// Calculates high-altitude mountain triangular distribution weight (0..100) for Iron Ore.
    /// Range Y = 80..320, peaking at Y = 232.
    pub fn ironOreWeightForAltitude(y: i32) u8 {
        if (y < IRON_MIN_Y or y > IRON_MAX_Y) return 0;
        if (y == IRON_PEAK_Y) return IRON_PEAK_WEIGHT;

        if (y < IRON_PEAK_Y) {
            const span: f32 = @floatFromInt(IRON_PEAK_Y - IRON_MIN_Y); // 232 - 80 = 152.0
            const dist: f32 = @floatFromInt(y - IRON_MIN_Y);
            const fraction = dist / span;
            const weight = @round(fraction * @as(f32, @floatFromInt(IRON_PEAK_WEIGHT)));
            return @intFromFloat(std.math.clamp(weight, 0.0, @as(f32, @floatFromInt(IRON_PEAK_WEIGHT))));
        } else {
            const span: f32 = @floatFromInt(IRON_MAX_Y - IRON_PEAK_Y); // 320 - 232 = 88.0
            const dist: f32 = @floatFromInt(IRON_MAX_Y - y);
            const fraction = dist / span;
            const weight = @round(fraction * @as(f32, @floatFromInt(IRON_PEAK_WEIGHT)));
            return @intFromFloat(std.math.clamp(weight, 0.0, @as(f32, @floatFromInt(IRON_PEAK_WEIGHT))));
        }
    }

    /// Continuous density factor for high-altitude iron ore [0.0, 1.0].
    pub fn ironOreDensity(y: i32) f32 {
        const weight = ironOreWeightForAltitude(y);
        return @as(f32, @floatFromInt(weight)) / 100.0;
    }

    /// Checks if a position is eligible for high-altitude iron ore generation.
    pub fn canGenerateHighAltitudeIron(y: i32) bool {
        return y >= IRON_MIN_Y and y <= IRON_MAX_Y;
    }

    /// Evaluates Coal Ore generation taking altitude and air exposure into account:
    /// - Coal never generates with air exposure at Y = 0..192.
    /// - On mountain peaks (Y > 192), coal can generate with air exposure.
    /// - Valid vertical range: Y = 0..320.
    pub fn canGenerateCoalOre(y: i32, exposed_to_air: bool) bool {
        if (y < COAL_LOWER_MIN_Y or y > COAL_MAX_Y) return false;
        if (exposed_to_air and y <= COAL_NO_AIR_EXPOSURE_MAX_Y) return false;
        return true;
    }

    /// Upper band coal generation (Y = 136..320), respecting the air exposure boundary at Y = 192.
    pub fn canGenerateUpperBandCoal(y: i32, exposed_to_air: bool) bool {
        if (y < COAL_UPPER_MIN_Y or y > COAL_MAX_Y) return false;
        if (exposed_to_air and y <= COAL_NO_AIR_EXPOSURE_MAX_Y) return false;
        return true;
    }

    /// Returns true if altitude Y is within the upper coal generation band (136..320).
    pub fn isUpperCoalBand(y: i32) bool {
        return y >= COAL_UPPER_MIN_Y and y <= COAL_MAX_Y;
    }

    /// Returns true if coal at altitude Y is allowed to generate exposed to air.
    pub fn allowsCoalAirExposure(y: i32) bool {
        return y > COAL_NO_AIR_EXPOSURE_MAX_Y and y <= COAL_MAX_Y;
    }
};

// ============================================================================
// 5. Altitude Snow and Water Freeze Line
// ============================================================================

/// Atmospheric precipitation kind.
pub const Precipitation = enum {
    none,
    rain,
    snowfall,

    /// Constant alias for compatibility.
    pub const snow: Precipitation = .snowfall;
};

/// Altitude snow line and water freezing mechanics:
/// In temperate/cold mountain transitions, exposed stationary water freezes into ice
/// and rain turns into snowfall above the biome's temperature-adjusted altitude freeze line.
/// Temperature drops by 0.00125 per block above Y = 80.
/// Freezing occurs when adjusted temperature falls below 0.15.
pub const AltitudeSnowAndFreezeLine = struct {
    pub const BASE_ALTITUDE_Y: i32 = 80;
    pub const TEMP_DROP_PER_BLOCK: f32 = 0.00125;
    pub const FREEZE_THRESHOLD_TEMP: f32 = 0.15;
    pub const MAX_FREEZE_BLOCK_LIGHT: u4 = 12; // Light level 13+ prevents freezing

    /// Calculates temperature adjusted for altitude Y:
    /// - For Y <= 80: temperature equals base_temp.
    /// - For Y > 80: temperature drops by 0.00125 per block above Y = 80.
    pub fn adjustedTemperature(base_temp: f32, y: i32) f32 {
        if (y <= BASE_ALTITUDE_Y) return base_temp;
        const altitude_above_base: f32 = @floatFromInt(y - BASE_ALTITUDE_Y);
        return base_temp - altitude_above_base * TEMP_DROP_PER_BLOCK;
    }

    /// Determines whether position Y is above the snow/freeze line for a biome with base_temp.
    /// Freezing occurs when adjusted temperature is strictly below 0.15.
    pub fn isAboveSnowLine(base_temp: f32, y: i32) bool {
        return adjustedTemperature(base_temp, y) < FREEZE_THRESHOLD_TEMP;
    }

    /// Computes the exact integer Y level where the snow line begins for a given base_temp.
    /// If base_temp is already below 0.15, returns BASE_ALTITUDE_Y (snow line at or below sea level).
    pub fn calculateSnowLineAltitude(base_temp: f32) i32 {
        if (base_temp < FREEZE_THRESHOLD_TEMP) return BASE_ALTITUDE_Y;
        const delta = base_temp - FREEZE_THRESHOLD_TEMP;
        const height_offset = @ceil(delta / TEMP_DROP_PER_BLOCK);
        return BASE_ALTITUDE_Y + @as(i32, @intFromFloat(height_offset));
    }

    /// Determines whether exposed stationary water freezes into ice:
    /// Requires:
    /// 1. Position is above the snow/freeze line (adjusted temp < 0.15).
    /// 2. Water is stationary (flowing water does not freeze).
    /// 3. Water is exposed directly to the sky.
    /// 4. Block light level is <= 12 (heat from torches, lanterns, glowstone prevents freezing).
    pub fn canWaterFreeze(
        base_temp: f32,
        y: i32,
        is_stationary_water: bool,
        exposed_to_sky: bool,
        block_light: u4,
    ) bool {
        if (!is_stationary_water) return false;
        if (!exposed_to_sky) return false;
        if (block_light > MAX_FREEZE_BLOCK_LIGHT) return false;
        return AltitudeSnowAndFreezeLine.isAboveSnowLine(base_temp, y);
    }

    /// Resolves precipitation type at altitude Y given whether rain/weather is active.
    /// When active:
    /// - Above snow line: rain turns into snowfall.
    /// - Below snow line: falls as rain.
    pub fn resolvePrecipitation(base_temp: f32, y: i32, is_raining: bool) Precipitation {
        if (!is_raining) return .none;
        if (AltitudeSnowAndFreezeLine.isAboveSnowLine(base_temp, y)) return .snowfall;
        return .rain;
    }
};

/// Top-level export of isAboveSnowLine.
pub fn isAboveSnowLine(base_temp: f32, y: i32) bool {
    return AltitudeSnowAndFreezeLine.isAboveSnowLine(base_temp, y);
}

// ============================================================================
// Tests
// ============================================================================

test "1. MountainPeakSubBiome: enum values, classifications, and powder snow presence" {
    const meadow = MountainPeakSubBiome.meadow;
    const grove = MountainPeakSubBiome.grove;
    const snowy_slopes = MountainPeakSubBiome.snowy_slopes;
    const jagged_peaks = MountainPeakSubBiome.jagged_peaks;
    const frozen_peaks = MountainPeakSubBiome.frozen_peaks;
    const stony_peaks = MountainPeakSubBiome.stony_peaks;

    // Peak classification
    try std.testing.expect(jagged_peaks.isPeak());
    try std.testing.expect(frozen_peaks.isPeak());
    try std.testing.expect(stony_peaks.isPeak());
    try std.testing.expect(!meadow.isPeak());
    try std.testing.expect(!grove.isPeak());
    try std.testing.expect(!snowy_slopes.isPeak());

    // Slope / base classification
    try std.testing.expect(meadow.isSlopeOrBase());
    try std.testing.expect(grove.isSlopeOrBase());
    try std.testing.expect(snowy_slopes.isSlopeOrBase());
    try std.testing.expect(!jagged_peaks.isSlopeOrBase());

    // Powder snow hazards
    try std.testing.expect(grove.hasPowderSnow());
    try std.testing.expect(snowy_slopes.hasPowderSnow());
    try std.testing.expect(jagged_peaks.hasPowderSnow());
    try std.testing.expect(frozen_peaks.hasPowderSnow());
    try std.testing.expect(!meadow.hasPowderSnow());
    try std.testing.expect(!stony_peaks.hasPowderSnow());

    // Snow and ice dominance
    try std.testing.expect(!stony_peaks.hasSnowAndIce());
    try std.testing.expect(jagged_peaks.hasSnowAndIce());
    try std.testing.expect(frozen_peaks.hasSnowAndIce());
}

test "2. StonyPeaksCalciteStrip: hasCalciteStrips returns true ONLY for stony_peaks" {
    try std.testing.expect(hasCalciteStrips(.stony_peaks));
    try std.testing.expect(StonyPeaksCalciteStrip.hasCalciteStrips(.stony_peaks));

    try std.testing.expect(!hasCalciteStrips(.meadow));
    try std.testing.expect(!hasCalciteStrips(.grove));
    try std.testing.expect(!hasCalciteStrips(.snowy_slopes));
    try std.testing.expect(!hasCalciteStrips(.jagged_peaks));
    try std.testing.expect(!hasCalciteStrips(.frozen_peaks));
}

test "3. StonyPeaksCalciteStrip: horizontal bands repeat periodically and shift with seed" {
    // Period is 16, thickness is 4 (mod 0..3 are calcite, 4..15 are stone)
    const seed: i32 = 0;
    try std.testing.expect(StonyPeaksCalciteStrip.isCalciteBand(0, seed));
    try std.testing.expect(StonyPeaksCalciteStrip.isCalciteBand(1, seed));
    try std.testing.expect(StonyPeaksCalciteStrip.isCalciteBand(2, seed));
    try std.testing.expect(StonyPeaksCalciteStrip.isCalciteBand(3, seed));
    try std.testing.expect(!StonyPeaksCalciteStrip.isCalciteBand(4, seed));
    try std.testing.expect(!StonyPeaksCalciteStrip.isCalciteBand(15, seed));

    // Next cycle at Y = 16..19
    try std.testing.expect(StonyPeaksCalciteStrip.isCalciteBand(16, seed));
    try std.testing.expect(StonyPeaksCalciteStrip.isCalciteBand(19, seed));
    try std.testing.expect(!StonyPeaksCalciteStrip.isCalciteBand(20, seed));

    // High mountain Y = 232: 232 % 16 = 8 -> stone
    try std.testing.expect(!StonyPeaksCalciteStrip.isCalciteBand(232, 0));
    // Y = 240: 240 % 16 = 0 -> calcite band!
    try std.testing.expect(StonyPeaksCalciteStrip.isCalciteBand(240, 0));

    // Seed offset shifts the bands
    try std.testing.expect(StonyPeaksCalciteStrip.isCalciteBand(4, -4)); // (4 - 4) % 16 = 0
}

test "4. StonyPeaksCalciteStrip: surface replacement replaces snow/ice and prevents powder snow" {
    // Powder snow hazard check
    try std.testing.expect(!StonyPeaksCalciteStrip.allowsPowderSnow(.stony_peaks));
    try std.testing.expect(StonyPeaksCalciteStrip.allowsPowderSnow(.snowy_slopes));
    try std.testing.expect(StonyPeaksCalciteStrip.allowsPowderSnow(.jagged_peaks));

    // In stony peaks, snow_block in a calcite band becomes calcite
    const calcite_y: i32 = 0; // mod 16 = 0 -> calcite
    const stone_y: i32 = 8; // mod 16 = 8 -> stone

    const b1 = StonyPeaksCalciteStrip.resolveSurfaceBlock(.stony_peaks, calcite_y, 0, .snow_block);
    try std.testing.expectEqual(MountainBlock.calcite, b1);

    const b2 = StonyPeaksCalciteStrip.resolveSurfaceBlock(.stony_peaks, stone_y, 0, .snow_block);
    try std.testing.expectEqual(MountainBlock.stone, b2);

    // Powder snow replaced by stone/calcite
    const b3 = StonyPeaksCalciteStrip.resolveSurfaceBlock(.stony_peaks, calcite_y, 0, .powder_snow);
    try std.testing.expectEqual(MountainBlock.calcite, b3);

    const b4 = StonyPeaksCalciteStrip.resolveSurfaceBlock(.stony_peaks, stone_y, 0, .powder_snow);
    try std.testing.expectEqual(MountainBlock.stone, b4);

    // In jagged_peaks, snow and powder snow are preserved
    const b5 = StonyPeaksCalciteStrip.resolveSurfaceBlock(.jagged_peaks, calcite_y, 0, .powder_snow);
    try std.testing.expectEqual(MountainBlock.powder_snow, b5);
}

test "5. MountainEmeraldDistribution: emeraldOreWeightForAltitude returns 0 outside mountain biomes or outside Y bounds" {
    // In non-mountain biome: weight is always 0
    try std.testing.expectEqual(@as(u8, 0), emeraldOreWeightForAltitude(false, 232));
    try std.testing.expectEqual(@as(u8, 0), emeraldOreWeightForAltitude(false, 100));
    try std.testing.expectEqual(@as(u8, 0), emeraldOreWeightForAltitude(false, -10));

    // In mountain biome but outside Y bounds [-16..320]
    try std.testing.expectEqual(@as(u8, 0), emeraldOreWeightForAltitude(true, -17));
    try std.testing.expectEqual(@as(u8, 0), emeraldOreWeightForAltitude(true, -64));
    try std.testing.expectEqual(@as(u8, 0), emeraldOreWeightForAltitude(true, 321));
    try std.testing.expectEqual(@as(u8, 0), emeraldOreWeightForAltitude(true, 400));
}

test "6. MountainEmeraldDistribution: triangular density peaks at Y=232 and falls toward Y=-16 and Y=320" {
    // Peak at Y = 232 gives maximum weight 100
    const peak = emeraldOreWeightForAltitude(true, 232);
    try std.testing.expectEqual(@as(u8, 100), peak);

    // Boundary at Y = -16 gives weight 0
    try std.testing.expectEqual(@as(u8, 0), emeraldOreWeightForAltitude(true, -16));

    // Boundary at Y = 320 gives weight 0
    try std.testing.expectEqual(@as(u8, 0), emeraldOreWeightForAltitude(true, 320));

    // Lower slope midpoint: Y = 108: (108 - (-16)) / 248 = 124 / 248 = 0.5 -> weight 50
    try std.testing.expectEqual(@as(u8, 50), emeraldOreWeightForAltitude(true, 108));

    // Upper slope midpoint: Y = 276: (320 - 276) / 88 = 44 / 88 = 0.5 -> weight 50
    try std.testing.expectEqual(@as(u8, 50), emeraldOreWeightForAltitude(true, 276));

    // Monotonicity check below peak: weights increase strictly with altitude
    const w_neg8 = emeraldOreWeightForAltitude(true, -8);
    const w_0 = emeraldOreWeightForAltitude(true, 0);
    const w_64 = emeraldOreWeightForAltitude(true, 64);
    const w_128 = emeraldOreWeightForAltitude(true, 128);
    const w_192 = emeraldOreWeightForAltitude(true, 192);

    try std.testing.expect(w_neg8 < w_0);
    try std.testing.expect(w_0 < w_64);
    try std.testing.expect(w_64 < w_128);
    try std.testing.expect(w_128 < w_192);
    try std.testing.expect(w_192 < peak);

    // Monotonicity check above peak: weights decrease strictly with altitude
    const w_250 = emeraldOreWeightForAltitude(true, 250);
    const w_290 = emeraldOreWeightForAltitude(true, 290);
    try std.testing.expect(peak > w_250);
    try std.testing.expect(w_250 > w_290);
    try std.testing.expect(w_290 > 0);
}

test "7. MountainEmeraldDistribution: deepslate emerald ore generated strictly below Y=0" {
    // Deepslate emerald below Y = 0
    try std.testing.expectEqual(EmeraldOreType.deepslate_emerald_ore, MountainEmeraldDistribution.emeraldOreTypeForAltitude(-1).?);
    try std.testing.expectEqual(EmeraldOreType.deepslate_emerald_ore, MountainEmeraldDistribution.emeraldOreTypeForAltitude(-16).?);
    try std.testing.expectEqual(MountainBlock.deepslate_emerald_ore, MountainEmeraldDistribution.getEmeraldOreBlock(-10).?);

    // Regular emerald at and above Y = 0
    try std.testing.expectEqual(EmeraldOreType.emerald_ore, MountainEmeraldDistribution.emeraldOreTypeForAltitude(0).?);
    try std.testing.expectEqual(EmeraldOreType.emerald_ore, MountainEmeraldDistribution.emeraldOreTypeForAltitude(232).?);
    try std.testing.expectEqual(EmeraldOreType.emerald_ore, MountainEmeraldDistribution.emeraldOreTypeForAltitude(320).?);
    try std.testing.expectEqual(MountainBlock.emerald_ore, MountainEmeraldDistribution.getEmeraldOreBlock(232).?);

    // Null outside bounds
    try std.testing.expect(MountainEmeraldDistribution.emeraldOreTypeForAltitude(-17) == null);
    try std.testing.expect(MountainEmeraldDistribution.emeraldOreTypeForAltitude(321) == null);

    // Deepslate zone check
    try std.testing.expect(MountainEmeraldDistribution.isDeepslateEmeraldZone(-5));
    try std.testing.expect(!MountainEmeraldDistribution.isDeepslateEmeraldZone(0));
    try std.testing.expect(!MountainEmeraldDistribution.isDeepslateEmeraldZone(-20));

    // Rarity: deepslate emerald weight is small (< 7 at Y < 0)
    const max_deepslate_weight = emeraldOreWeightForAltitude(true, -1);
    try std.testing.expect(max_deepslate_weight <= 6);
}

test "8. HighAltitudeCoalAndIron: Iron Ore high-altitude triangular peak at Y=232 in range Y=80..320" {
    // Out of bounds checks
    try std.testing.expectEqual(@as(u8, 0), HighAltitudeCoalAndIron.ironOreWeightForAltitude(79));
    try std.testing.expectEqual(@as(u8, 0), HighAltitudeCoalAndIron.ironOreWeightForAltitude(0));
    try std.testing.expectEqual(@as(u8, 0), HighAltitudeCoalAndIron.ironOreWeightForAltitude(321));

    // Peak at Y = 232 gives 100
    try std.testing.expectEqual(@as(u8, 100), HighAltitudeCoalAndIron.ironOreWeightForAltitude(232));

    // Boundaries at Y = 80 and Y = 320 give 0
    try std.testing.expectEqual(@as(u8, 0), HighAltitudeCoalAndIron.ironOreWeightForAltitude(80));
    try std.testing.expectEqual(@as(u8, 0), HighAltitudeCoalAndIron.ironOreWeightForAltitude(320));

    // Lower span midpoint: Y = 156: (156 - 80) / 152 = 76 / 152 = 0.5 -> weight 50
    try std.testing.expectEqual(@as(u8, 50), HighAltitudeCoalAndIron.ironOreWeightForAltitude(156));

    // Upper span midpoint: Y = 276: (320 - 276) / 88 = 44 / 88 = 0.5 -> weight 50
    try std.testing.expectEqual(@as(u8, 50), HighAltitudeCoalAndIron.ironOreWeightForAltitude(276));

    // Eligibility check
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateHighAltitudeIron(80));
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateHighAltitudeIron(232));
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateHighAltitudeIron(320));
    try std.testing.expect(!HighAltitudeCoalAndIron.canGenerateHighAltitudeIron(70));
}

test "9. HighAltitudeCoalAndIron: Coal Ore upper generation band at Y=136..320" {
    // Upper coal band boundaries
    try std.testing.expect(HighAltitudeCoalAndIron.isUpperCoalBand(136));
    try std.testing.expect(HighAltitudeCoalAndIron.isUpperCoalBand(200));
    try std.testing.expect(HighAltitudeCoalAndIron.isUpperCoalBand(320));
    try std.testing.expect(!HighAltitudeCoalAndIron.isUpperCoalBand(135));
    try std.testing.expect(!HighAltitudeCoalAndIron.isUpperCoalBand(321));

    // Unexposed generation within upper band
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateUpperBandCoal(136, false));
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateUpperBandCoal(250, false));
    try std.testing.expect(!HighAltitudeCoalAndIron.canGenerateUpperBandCoal(100, false));
}

test "10. HighAltitudeCoalAndIron: Coal air exposure rules - forbidden at Y=0..192 vs allowed on peaks Y>192" {
    // Air exposure forbidden at Y = 0..192
    try std.testing.expect(!HighAltitudeCoalAndIron.canGenerateCoalOre(0, true));
    try std.testing.expect(!HighAltitudeCoalAndIron.canGenerateCoalOre(64, true));
    try std.testing.expect(!HighAltitudeCoalAndIron.canGenerateCoalOre(128, true));
    try std.testing.expect(!HighAltitudeCoalAndIron.canGenerateCoalOre(192, true));

    // Air exposure allowed above Y = 192 on high mountain peaks
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateCoalOre(193, true));
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateCoalOre(232, true));
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateCoalOre(320, true));

    // Upper band coal with air exposure check
    try std.testing.expect(!HighAltitudeCoalAndIron.canGenerateUpperBandCoal(150, true));
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateUpperBandCoal(200, true));

    // Unexposed coal generates throughout Y = 0..320
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateCoalOre(64, false));
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateCoalOre(192, false));
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateCoalOre(250, false));

    // Negative Y or above Y=320 never generates coal
    try std.testing.expect(!HighAltitudeCoalAndIron.canGenerateCoalOre(-1, false));
    try std.testing.expect(!HighAltitudeCoalAndIron.canGenerateCoalOre(321, false));
}

test "11. AltitudeSnowAndFreezeLine: temperature drops by 0.00125 per block above Y=80" {
    const base: f32 = 0.5;

    // At or below Y = 80, temperature is unchanged
    try std.testing.expectApproxEqAbs(base, AltitudeSnowAndFreezeLine.adjustedTemperature(base, 80), 0.0001);
    try std.testing.expectApproxEqAbs(base, AltitudeSnowAndFreezeLine.adjustedTemperature(base, 64), 0.0001);
    try std.testing.expectApproxEqAbs(base, AltitudeSnowAndFreezeLine.adjustedTemperature(base, 0), 0.0001);

    // 80 blocks above: Y = 160 -> drop of 80 * 0.00125 = 0.10 -> 0.40
    try std.testing.expectApproxEqAbs(@as(f32, 0.40), AltitudeSnowAndFreezeLine.adjustedTemperature(base, 160), 0.0001);

    // 160 blocks above: Y = 240 -> drop of 160 * 0.00125 = 0.20 -> 0.30
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), AltitudeSnowAndFreezeLine.adjustedTemperature(base, 240), 0.0001);

    // 280 blocks above: Y = 360 -> drop of 280 * 0.00125 = 0.35 -> 0.15
    try std.testing.expectApproxEqAbs(@as(f32, 0.15), AltitudeSnowAndFreezeLine.adjustedTemperature(base, 360), 0.0001);
}

test "12. AltitudeSnowAndFreezeLine: isAboveSnowLine threshold calculation across diverse biomes" {
    // 1. Cold Biome (base_temp = 0.2, e.g. Taiga):
    // Needs drop of (0.2 - 0.15) = 0.05 -> 0.05 / 0.00125 = 40 blocks above Y = 80 -> Y = 120 gives exactly 0.15.
    // At Y = 120, temp is 0.15 (not strictly below). At Y = 121, temp is < 0.15 -> above snow line!
    try std.testing.expect(!isAboveSnowLine(0.2, 120));
    try std.testing.expect(isAboveSnowLine(0.2, 121));
    try std.testing.expect(isAboveSnowLine(0.2, 200));

    // 2. Temperate Meadow (base_temp = 0.5):
    // Needs drop of (0.5 - 0.15) = 0.35 -> 280 blocks above 80 -> Y = 360 gives 0.15.
    try std.testing.expect(!isAboveSnowLine(0.5, 360));
    try std.testing.expect(isAboveSnowLine(0.5, 361));

    // 3. Sub-zero biomes (e.g. Snowy Slopes base_temp = -0.3, Jagged Peaks base_temp = -0.7):
    // Already < 0.15 at all altitudes
    try std.testing.expect(isAboveSnowLine(-0.3, 80));
    try std.testing.expect(isAboveSnowLine(-0.3, 64));
    try std.testing.expect(isAboveSnowLine(-0.7, 232));

    // 4. Hot biome (base_temp = 1.0, e.g. Stony Peaks):
    // Needs drop of (1.0 - 0.15) = 0.85 -> 680 blocks above 80 -> Y = 760!
    // At normal peak heights (Y <= 320), Stony Peaks never reaches the snow line!
    try std.testing.expect(!isAboveSnowLine(1.0, 320));
}

test "13. AltitudeSnowAndFreezeLine: exposed stationary water freezing rules with light and sky access" {
    const cold_temp: f32 = 0.0; // Always below snow line
    const y: i32 = 100;

    // Stationary exposed water with low light freezes into ice
    try std.testing.expect(AltitudeSnowAndFreezeLine.canWaterFreeze(cold_temp, y, true, true, 0));
    try std.testing.expect(AltitudeSnowAndFreezeLine.canWaterFreeze(cold_temp, y, true, true, 12));

    // Flowing water does NOT freeze
    try std.testing.expect(!AltitudeSnowAndFreezeLine.canWaterFreeze(cold_temp, y, false, true, 0));

    // Water blocked from sky does NOT freeze
    try std.testing.expect(!AltitudeSnowAndFreezeLine.canWaterFreeze(cold_temp, y, true, false, 0));

    // High artificial block light (>= 13, e.g. torch nearby) prevents freezing
    try std.testing.expect(!AltitudeSnowAndFreezeLine.canWaterFreeze(cold_temp, y, true, true, 13));
    try std.testing.expect(!AltitudeSnowAndFreezeLine.canWaterFreeze(cold_temp, y, true, true, 15));

    // Warm biome below snow line does NOT freeze
    try std.testing.expect(!AltitudeSnowAndFreezeLine.canWaterFreeze(0.8, 80, true, true, 0));
}

test "14. AltitudeSnowAndFreezeLine: rain turns to snowfall across the freeze line" {
    const base_temp: f32 = 0.2; // Snow line is at Y = 121

    // Clear weather yields no precipitation
    try std.testing.expectEqual(Precipitation.none, AltitudeSnowAndFreezeLine.resolvePrecipitation(base_temp, 100, false));
    try std.testing.expectEqual(Precipitation.none, AltitudeSnowAndFreezeLine.resolvePrecipitation(base_temp, 200, false));

    // Below snow line during rain -> rain
    try std.testing.expectEqual(Precipitation.rain, AltitudeSnowAndFreezeLine.resolvePrecipitation(base_temp, 80, true));
    try std.testing.expectEqual(Precipitation.rain, AltitudeSnowAndFreezeLine.resolvePrecipitation(base_temp, 120, true));

    // Above snow line during rain -> snowfall!
    try std.testing.expectEqual(Precipitation.snowfall, AltitudeSnowAndFreezeLine.resolvePrecipitation(base_temp, 121, true));
    try std.testing.expectEqual(Precipitation.snowfall, AltitudeSnowAndFreezeLine.resolvePrecipitation(base_temp, 232, true));
    try std.testing.expectEqual(Precipitation.snow, AltitudeSnowAndFreezeLine.resolvePrecipitation(base_temp, 232, true));
}

test "15. Integrated mountain generation workflow: sample altitude, biome, surface block, and ore generation" {
    // Column 1: Stony Peaks summit at Y = 240
    const stony = MountainPeakSubBiome.stony_peaks;
    try std.testing.expect(hasCalciteStrips(stony));
    try std.testing.expect(!stony.hasPowderSnow());

    // Surface block in calcite band is calcite, not snow
    const surf_block = StonyPeaksCalciteStrip.resolveSurfaceBlock(stony, 240, 0, .snow_block);
    try std.testing.expectEqual(MountainBlock.calcite, surf_block);

    // Ore generation at Y = 232 summit in Stony Peaks:
    // Emerald ore weight is 100 (peak)
    try std.testing.expectEqual(@as(u8, 100), emeraldOreWeightForAltitude(true, 232));
    // High-altitude iron ore weight is 100 (peak)
    try std.testing.expectEqual(@as(u8, 100), HighAltitudeCoalAndIron.ironOreWeightForAltitude(232));
    // Exposed coal on peaks is permitted
    try std.testing.expect(HighAltitudeCoalAndIron.canGenerateCoalOre(232, true));

    // Column 2: Jagged Peaks summit at Y = 232
    const jagged = MountainPeakSubBiome.jagged_peaks;
    try std.testing.expect(!hasCalciteStrips(jagged));
    try std.testing.expect(jagged.hasPowderSnow());
    try std.testing.expect(isAboveSnowLine(jagged.baseTemperature(), 232));

    // Column 3: Deep underground mountain root at Y = -10
    // Generates rare deepslate emerald ore
    const emerald_type = MountainEmeraldDistribution.emeraldOreTypeForAltitude(-10);
    try std.testing.expectEqual(EmeraldOreType.deepslate_emerald_ore, emerald_type.?);
    try std.testing.expect(emeraldOreWeightForAltitude(true, -10) > 0);
    try std.testing.expect(emeraldOreWeightForAltitude(true, -10) <= 6);
    // High-altitude iron does not generate deep underground
    try std.testing.expectEqual(@as(u8, 0), HighAltitudeCoalAndIron.ironOreWeightForAltitude(-10));
}
