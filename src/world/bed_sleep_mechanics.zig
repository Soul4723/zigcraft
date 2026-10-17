//! Bed 16 Dye Colors, Sleep Window & Monster Proximity Check, Phantom Timer Reset,
//! Nether/End Power-5.0 Explosion & 50% Bounce Cushion.
//!
//! Milestone 410: Implements Minecraft-accurate Bed gameplay mechanics:
//! - 16 dye color bed crafting & white bed re-dyeing (Java 1.12+ / 1.14+).
//! - Clear weather, rain, and thunderstorm sleep time windows.
//! - Player bed distance & nearby hostile monster proximity validation.
//! - Instant respawn anchor setting & Phantom insomnia timer reset on lie down.
//! - 5.05s (101 ticks) full sleep cycle advancing time to dawn (tick 0) and clearing rain/thunder.
//! - Nether & The End power 5.0 fiery explosion upon bed interaction.
//! - Bed cushion mechanics: 50% fall damage reduction and 66% upward bounce rebound.

const std = @import("std");
const BedModule = @This();

// ============================================================================
// 1. Bed Colors & Crafting
// ============================================================================

/// Canonical 16 Minecraft dye colors.
pub const DyeColor = enum(u4) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,

    pub fn name(self: DyeColor) []const u8 {
        return switch (self) {
            .white => "White",
            .orange => "Orange",
            .magenta => "Magenta",
            .light_blue => "Light Blue",
            .yellow => "Yellow",
            .lime => "Lime",
            .pink => "Pink",
            .gray => "Gray",
            .light_gray => "Light Gray",
            .cyan => "Cyan",
            .purple => "Purple",
            .blue => "Blue",
            .brown => "Brown",
            .green => "Green",
            .red => "Red",
            .black => "Black",
        };
    }

    pub fn bedName(self: DyeColor) []const u8 {
        return switch (self) {
            .white => "White Bed",
            .orange => "Orange Bed",
            .magenta => "Magenta Bed",
            .light_blue => "Light Blue Bed",
            .yellow => "Yellow Bed",
            .lime => "Lime Bed",
            .pink => "Pink Bed",
            .gray => "Gray Bed",
            .light_gray => "Light Gray Bed",
            .cyan => "Cyan Bed",
            .purple => "Purple Bed",
            .blue => "Blue Bed",
            .brown => "Brown Bed",
            .green => "Green Bed",
            .red => "Red Bed",
            .black => "Black Bed",
        };
    }
};

/// All 16 dye colors in enum declaration order.
pub const ALL_BED_COLORS = [16]DyeColor{
    .white, .orange, .magenta, .light_blue,
    .yellow, .lime, .pink, .gray,
    .light_gray, .cyan, .purple, .blue,
    .brown, .green, .red, .black,
};

/// Planks variant supported for bed base frame.
pub const WoodPlankType = enum {
    oak,
    spruce,
    birch,
    jungle,
    acacia,
    dark_oak,
    mangrove,
    cherry,
    bamboo,
    crimson,
    warped,
};

/// Represents a placed or item-form Bed.
pub const Bed = struct {
    color: DyeColor = .white,

    pub fn isWhite(self: Bed) bool {
        return self.color == .white;
    }

    pub fn name(self: Bed) []const u8 {
        return self.color.bedName();
    }
};

/// Re-dyes a bed. Only a white bed can be re-dyed into any of the 15 non-white colored beds.
/// Re-dyeing an already colored bed returns null.
/// Re-dyeing with white dye returns null (white bed is already white).
pub fn craftColoredBed(bed_input: anytype, dye: DyeColor) ?Bed {
    const T = @TypeOf(bed_input);
    const base_color: DyeColor = if (T == Bed)
        bed_input.color
    else if (T == *const Bed or T == *Bed)
        bed_input.color
    else if (T == DyeColor)
        bed_input
    else
        @compileError("craftColoredBed expects Bed, *Bed, *const Bed, or DyeColor");

    if (base_color != .white) return null;
    if (dye == .white) return null;

    return Bed{ .color = dye };
}

/// Namespace grouping bed crafting recipes and color variations.
pub const BedColorCrafting = struct {
    pub const WOOL_COUNT_REQUIRED: u8 = 3;
    pub const PLANKS_COUNT_REQUIRED: u8 = 3;
    pub const TOTAL_COLOR_VARIANTS: usize = 16;
    pub const REDYEABLE_COLOR_VARIANTS: usize = 15;

    /// Crafts a colored bed from 3 matching wool items and 3 planks of any wood type.
    pub fn craftBed(wool_color: DyeColor, wool_count: u8, planks_count: u8) ?Bed {
        if (wool_count < WOOL_COUNT_REQUIRED or planks_count < PLANKS_COUNT_REQUIRED) return null;
        return Bed{ .color = wool_color };
    }

    /// Crafts a colored bed from 3 individual wool slots and planks, ensuring all 3 wool colors match.
    pub fn craftFromMatchingWool(wool_slots: [3]DyeColor, planks_count: u8) ?Bed {
        if (planks_count < PLANKS_COUNT_REQUIRED) return null;
        if (wool_slots[0] != wool_slots[1] or wool_slots[1] != wool_slots[2]) return null;
        return Bed{ .color = wool_slots[0] };
    }

    /// Crafts a bed from a slice of wool colors and planks count.
    pub fn craftFromWoolSlice(wool_slice: []const DyeColor, planks_count: u8) ?Bed {
        if (wool_slice.len < WOOL_COUNT_REQUIRED or planks_count < PLANKS_COUNT_REQUIRED) return null;
        const target_color = wool_slice[0];
        for (wool_slice[1..WOOL_COUNT_REQUIRED]) |c| {
            if (c != target_color) return null;
        }
        return Bed{ .color = target_color };
    }

    /// Any white bed can be re-dyed into any of the 15 colored beds.
    pub fn craftColoredBed(bed_input: anytype, dye: DyeColor) ?Bed {
        return BedModule.craftColoredBed(bed_input, dye);
    }
};

pub const craftBed = BedColorCrafting.craftBed;
pub const craftFromMatchingWool = BedColorCrafting.craftFromMatchingWool;
pub const craftFromWoolSlice = BedColorCrafting.craftFromWoolSlice;

// ============================================================================
// 2. Bed Sleep Validation & Time Windows
// ============================================================================

pub const TICKS_PER_DAY: u16 = 24000;
pub const CLEAR_WEATHER_SLEEP_START_TICK: u16 = 12542;
pub const CLEAR_WEATHER_SLEEP_END_TICK: u16 = 23459;
pub const RAIN_SLEEP_START_TICK: u16 = 12010;
pub const RAIN_SLEEP_END_TICK: u16 = 23991;

pub const PLAYER_MAX_HORIZONTAL_DIST: f32 = 3.0;
pub const PLAYER_MAX_VERTICAL_DIST: f32 = 2.0;

pub const HOSTILE_MONSTER_MAX_HORIZONTAL_DIST: f32 = 8.0;
pub const HOSTILE_MONSTER_MAX_VERTICAL_DIST: f32 = 5.0;

pub const SLEEP_DURATION_SECONDS: f32 = 5.05;
pub const SLEEP_DURATION_TICKS: u16 = 101;
pub const DAWN_TICK: u16 = 0;

/// Checks if sleep is permitted at the specified time of day and weather condition.
/// - Clear weather: dusk to morning (12542..23459 ticks).
/// - Rain: earlier dusk to late night (12010..23991 ticks).
/// - Thunderstorm: any time during the day/night (0..23999 ticks).
pub fn canSleepAtTime(time_ticks: u16, is_raining: bool, is_thundering: bool) bool {
    const day_ticks = time_ticks % TICKS_PER_DAY;
    if (is_thundering) {
        return true;
    }
    if (is_raining) {
        return day_ticks >= RAIN_SLEEP_START_TICK and day_ticks <= RAIN_SLEEP_END_TICK;
    }
    return day_ticks >= CLEAR_WEATHER_SLEEP_START_TICK and day_ticks <= CLEAR_WEATHER_SLEEP_END_TICK;
}

/// Checks if a hostile monster is within 8.0 horizontal and 5.0 vertical blocks of the bed.
pub fn isBlockedByMonstersNearBed(nearest_hostile_dx: f32, nearest_hostile_dy: f32, nearest_hostile_dz: f32) bool {
    const horiz_dist_sq = nearest_hostile_dx * nearest_hostile_dx + nearest_hostile_dz * nearest_hostile_dz;
    const vert_dist = @abs(nearest_hostile_dy);
    return horiz_dist_sq <= (HOSTILE_MONSTER_MAX_HORIZONTAL_DIST * HOSTILE_MONSTER_MAX_HORIZONTAL_DIST) and
        vert_dist <= HOSTILE_MONSTER_MAX_VERTICAL_DIST;
}

/// Checks if the player is within 3.0 horizontal and 2.0 vertical blocks of the bed.
pub fn isPlayerNearBed(player_dx: f32, player_dy: f32, player_dz: f32) bool {
    const horiz_dist_sq = player_dx * player_dx + player_dz * player_dz;
    const vert_dist = @abs(player_dy);
    return horiz_dist_sq <= (PLAYER_MAX_HORIZONTAL_DIST * PLAYER_MAX_HORIZONTAL_DIST) and
        vert_dist <= PLAYER_MAX_VERTICAL_DIST;
}

/// Lying in a bed immediately resets the player's Phantom insomnia timer to 0.
pub fn resetsInsomniaTimerOnLieDown() bool {
    return true;
}

/// Block coordinates of a bed head/foot block.
pub const BedBlockPos = struct {
    x: i32,
    y: i32,
    z: i32,
};

/// Result of sleeping through the night.
pub const WorldSleepOutcome = struct {
    time_ticks: u16 = DAWN_TICK,
    is_raining: bool = false,
    is_thundering: bool = false,
};

/// Helper to simulate a full player sleep cycle.
pub const PlayerSleepSession = struct {
    is_in_bed: bool = false,
    ticks_slept: u16 = 0,
    respawn_set: bool = false,
    respawn_pos: ?BedBlockPos = null,
    insomnia_timer_ticks: u32 = 0,

    /// Lying down in bed immediately sets respawn point and resets insomnia timer to 0.
    pub fn lieDown(self: *PlayerSleepSession, bed_pos: BedBlockPos) void {
        self.is_in_bed = true;
        self.ticks_slept = 0;
        self.respawn_set = true;
        self.respawn_pos = bed_pos;
        if (BedModule.resetsInsomniaTimerOnLieDown()) {
            self.insomnia_timer_ticks = 0;
        }
    }

    /// Exiting bed early cancels sleeping, but keeps the respawn point and reset insomnia timer.
    pub fn leaveBed(self: *PlayerSleepSession) void {
        self.is_in_bed = false;
        self.ticks_slept = 0;
    }

    /// Ticks sleep progression. Returns true when 5.05s (101 ticks) of sleep have elapsed.
    pub fn tick(self: *PlayerSleepSession) bool {
        if (!self.is_in_bed) return false;
        self.ticks_slept += 1;
        return self.ticks_slept >= SLEEP_DURATION_TICKS;
    }

    /// Completes sleep, waking at dawn and clearing rain and thunderstorm.
    pub fn wakeAtDawn(self: *PlayerSleepSession) WorldSleepOutcome {
        self.is_in_bed = false;
        self.ticks_slept = 0;
        return .{
            .time_ticks = DAWN_TICK,
            .is_raining = false,
            .is_thundering = false,
        };
    }
};

/// Sleep validation status codes.
pub const SleepValidationResult = enum {
    ok,
    wrong_dimension,
    too_far_away,
    monsters_nearby,
    not_possible_now,
};

/// Namespace grouping sleep validation and condition checking.
pub const BedSleepValidation = struct {
    pub const canSleepAtTime = BedModule.canSleepAtTime;
    pub const isBlockedByMonstersNearBed = BedModule.isBlockedByMonstersNearBed;
    pub const isPlayerNearBed = BedModule.isPlayerNearBed;
    pub const resetsInsomniaTimerOnLieDown = BedModule.resetsInsomniaTimerOnLieDown;

    /// Validates all bed sleep conditions together.
    pub fn validateSleep(
        dimension: Dimension,
        time_ticks: u16,
        is_raining: bool,
        is_thundering: bool,
        player_dx: f32,
        player_dy: f32,
        player_dz: f32,
        nearest_hostile_coords: ?[3]f32,
    ) SleepValidationResult {
        if (BedModule.shouldBedExplodeInDimension(dimension)) {
            return .wrong_dimension;
        }
        if (!BedModule.isPlayerNearBed(player_dx, player_dy, player_dz)) {
            return .too_far_away;
        }
        if (nearest_hostile_coords) |h| {
            if (BedModule.isBlockedByMonstersNearBed(h[0], h[1], h[2])) {
                return .monsters_nearby;
            }
        }
        if (!BedModule.canSleepAtTime(time_ticks, is_raining, is_thundering)) {
            return .not_possible_now;
        }
        return .ok;
    }
};

// ============================================================================
// 3. Wrong Dimension Bed Explosion (Nether / The End)
// ============================================================================

/// Canonical Minecraft dimensions.
pub const Dimension = enum {
    overworld,
    nether,
    the_end,

    pub fn name(self: Dimension) []const u8 {
        return switch (self) {
            .overworld => "Overworld",
            .nether => "The Nether",
            .the_end => "The End",
        };
    }
};

/// Power of the fiery explosion triggered by beds in the Nether or The End.
pub const bed_explosion_power: f32 = 5.0;

/// Whether the wrong-dimension bed explosion ignites surrounding blocks.
pub const setsSurroundingBlocksOnFire: bool = true;

/// Returns true if attempting to use a bed in the given dimension explodes.
pub fn shouldBedExplodeInDimension(dim: Dimension) bool {
    return dim == .nether or dim == .the_end;
}

/// Alias for compatibility with dimensional anchor nomenclature.
pub fn doesBedExplodeInDimension(dim: Dimension) bool {
    return shouldBedExplodeInDimension(dim);
}

/// Detailed outcome of interacting with a bed in any dimension.
pub const BedDimensionInteractionResult = struct {
    explodes: bool,
    destroys_bed: bool,
    power: f32,
    sets_fire: bool,
    can_sleep: bool,
};

/// Namespace for wrong dimension bed explosions.
pub const WrongDimensionBedExplosion = struct {
    pub const bed_explosion_power: f32 = 5.0;
    pub const setsSurroundingBlocksOnFire: bool = true;

    pub fn shouldBedExplodeInDimension(dim: Dimension) bool {
        return BedModule.shouldBedExplodeInDimension(dim);
    }

    pub fn doesBedExplodeInDimension(dim: Dimension) bool {
        return BedModule.shouldBedExplodeInDimension(dim);
    }

    pub fn trigger(dim: Dimension) BedDimensionInteractionResult {
        if (BedModule.shouldBedExplodeInDimension(dim)) {
            return .{
                .explodes = true,
                .destroys_bed = true,
                .power = WrongDimensionBedExplosion.bed_explosion_power,
                .sets_fire = WrongDimensionBedExplosion.setsSurroundingBlocksOnFire,
                .can_sleep = false,
            };
        }
        return .{
            .explodes = false,
            .destroys_bed = false,
            .power = 0.0,
            .sets_fire = false,
            .can_sleep = true,
        };
    }
};

// ============================================================================
// 4. Bed Bounce Cushion & Fall Damage Reduction
// ============================================================================

pub const BED_FALL_DAMAGE_MULTIPLIER: f32 = 0.5;
pub const BED_BOUNCE_REBOUND_RATIO: f32 = 0.66;

/// Landing on a Bed reduces fall damage by 50% (damage * 0.5).
pub fn computeBedFallDamage(raw_fall_damage: f32) f32 {
    if (raw_fall_damage <= 0.0) return 0.0;
    return raw_fall_damage * BED_FALL_DAMAGE_MULTIPLIER;
}

/// Landing on a Bed rebounds the entity upward with 66% (0.66) of its downward impact speed.
pub fn computeBedBounceVy(impact_vy: f32) f32 {
    const downward_speed = @abs(impact_vy);
    return downward_speed * BED_BOUNCE_REBOUND_RATIO;
}

/// Namespace for bed bounce and fall damage mechanics.
pub const BedBounceCushion = struct {
    pub const fall_damage_multiplier: f32 = BED_FALL_DAMAGE_MULTIPLIER;
    pub const bounce_rebound_ratio: f32 = BED_BOUNCE_REBOUND_RATIO;

    pub fn computeBedFallDamage(raw_fall_damage: f32) f32 {
        return BedModule.computeBedFallDamage(raw_fall_damage);
    }

    pub fn computeBedBounceVy(impact_vy: f32) f32 {
        return BedModule.computeBedBounceVy(impact_vy);
    }
};

// ============================================================================
// Unit Tests (At least 12 comprehensive test blocks)
// ============================================================================

test "1. BedColorCrafting: 3 matching colored wool + 3 planks produces colored bed for all 16 colors" {
    for (ALL_BED_COLORS) |color| {
        const crafted = BedColorCrafting.craftBed(color, 3, 3);
        try std.testing.expect(crafted != null);
        try std.testing.expectEqual(color, crafted.?.color);
        try std.testing.expectEqualStrings(color.bedName(), crafted.?.name());
    }
}

test "2. BedColorCrafting: mismatched wool colors or insufficient materials fail crafting" {
    // Insufficient wool (only 2 wool)
    try std.testing.expectEqual(@as(?Bed, null), BedColorCrafting.craftBed(.red, 2, 3));
    // Insufficient planks (only 2 planks)
    try std.testing.expectEqual(@as(?Bed, null), BedColorCrafting.craftBed(.blue, 3, 2));

    // Mismatched wool colors in slots
    const mismatched_slots = [3]DyeColor{ .red, .red, .yellow };
    try std.testing.expectEqual(@as(?Bed, null), BedColorCrafting.craftFromMatchingWool(mismatched_slots, 3));

    // Matching wool slots succeed
    const matching_slots = [3]DyeColor{ .purple, .purple, .purple };
    const bed = BedColorCrafting.craftFromMatchingWool(matching_slots, 3).?;
    try std.testing.expectEqual(DyeColor.purple, bed.color);

    // Slice helper
    const mismatched_slice = [_]DyeColor{ .lime, .green, .lime };
    try std.testing.expectEqual(@as(?Bed, null), BedColorCrafting.craftFromWoolSlice(&mismatched_slice, 3));

    const matching_slice = [_]DyeColor{ .cyan, .cyan, .cyan, .black };
    const slice_bed = BedColorCrafting.craftFromWoolSlice(&matching_slice, 4).?;
    try std.testing.expectEqual(DyeColor.cyan, slice_bed.color);
}

test "3. BedColorCrafting: craftColoredBed re-dyes white bed into each of the 15 colored beds" {
    const white_bed = Bed{ .color = .white };
    try std.testing.expect(white_bed.isWhite());

    var re_dyed_count: usize = 0;
    for (ALL_BED_COLORS) |color| {
        if (color == .white) continue;
        const dyed = craftColoredBed(white_bed, color);
        try std.testing.expect(dyed != null);
        try std.testing.expectEqual(color, dyed.?.color);
        re_dyed_count += 1;
    }
    // Exactly 15 colored beds can be crafted from white bed
    try std.testing.expectEqual(@as(usize, 15), re_dyed_count);
    try std.testing.expectEqual(@as(usize, 15), BedColorCrafting.REDYEABLE_COLOR_VARIANTS);
}

test "4. BedColorCrafting: craftColoredBed rejects re-dyeing already colored beds or using white dye" {
    // Attempting to dye a red bed with blue dye fails
    const red_bed = Bed{ .color = .red };
    try std.testing.expectEqual(@as(?Bed, null), craftColoredBed(red_bed, .blue));

    // Attempting to dye a black bed with green dye fails
    const black_bed = Bed{ .color = .black };
    try std.testing.expectEqual(@as(?Bed, null), craftColoredBed(black_bed, .green));

    // Attempting to dye a white bed with white dye fails (white is already white, only 15 colored variants allowed)
    const white_bed = Bed{ .color = .white };
    try std.testing.expectEqual(@as(?Bed, null), craftColoredBed(white_bed, .white));

    // Works with pointers and DyeColor enum values directly
    try std.testing.expectEqual(DyeColor.orange, craftColoredBed(&white_bed, .orange).?.color);
    try std.testing.expectEqual(DyeColor.magenta, craftColoredBed(DyeColor.white, .magenta).?.color);
}

test "5. BedSleepValidation: canSleepAtTime enforces clear weather dusk/night window (12542..23459)" {
    // Clear weather: day ticks 0..12541 not allowed
    try std.testing.expect(!canSleepAtTime(0, false, false));
    try std.testing.expect(!canSleepAtTime(6000, false, false));
    try std.testing.expect(!canSleepAtTime(12000, false, false));
    try std.testing.expect(!canSleepAtTime(12541, false, false));

    // Clear weather: 12542..23459 allowed
    try std.testing.expect(canSleepAtTime(12542, false, false));
    try std.testing.expect(canSleepAtTime(18000, false, false)); // Midnight
    try std.testing.expect(canSleepAtTime(23459, false, false));

    // Clear weather: morning 23460..23999 not allowed
    try std.testing.expect(!canSleepAtTime(23460, false, false));
    try std.testing.expect(!canSleepAtTime(23999, false, false));

    // Wraps cleanly over multiple day cycles (24000 + 12542 = 36542)
    try std.testing.expect(canSleepAtTime(36542, false, false));
    try std.testing.expect(!canSleepAtTime(24000 + 6000, false, false));
}

test "6. BedSleepValidation: canSleepAtTime enforces rain sleep window (12010..23991)" {
    // Rain: ticks before 12010 not allowed
    try std.testing.expect(!canSleepAtTime(0, true, false));
    try std.testing.expect(!canSleepAtTime(6000, true, false));
    try std.testing.expect(!canSleepAtTime(12009, true, false));

    // Rain: 12010..23991 allowed
    try std.testing.expect(canSleepAtTime(12010, true, false));
    try std.testing.expect(canSleepAtTime(12541, true, false)); // Allowed during rain though not in clear!
    try std.testing.expect(canSleepAtTime(18000, true, false));
    try std.testing.expect(canSleepAtTime(23991, true, false));

    // Rain: 23992..23999 not allowed
    try std.testing.expect(!canSleepAtTime(23992, true, false));
    try std.testing.expect(!canSleepAtTime(23999, true, false));
}

test "7. BedSleepValidation: canSleepAtTime permits sleep at any time during thunderstorm" {
    // Thunderstorm allows sleeping at ANY tick in 0..23999
    try std.testing.expect(canSleepAtTime(0, false, true));
    try std.testing.expect(canSleepAtTime(1000, true, true));
    try std.testing.expect(canSleepAtTime(6000, false, true)); // Noon
    try std.testing.expect(canSleepAtTime(12000, true, true));
    try std.testing.expect(canSleepAtTime(18000, false, true)); // Midnight
    try std.testing.expect(canSleepAtTime(23999, true, true));
}

test "8. BedSleepValidation: player proximity check requires <= 3.0 horizontal and <= 2.0 vertical blocks" {
    // At bed position
    try std.testing.expect(isPlayerNearBed(0.0, 0.0, 0.0));

    // Boundary on horizontal: exactly 3.0 away along X or Z
    try std.testing.expect(isPlayerNearBed(3.0, 0.0, 0.0));
    try std.testing.expect(isPlayerNearBed(0.0, 0.0, -3.0));
    try std.testing.expect(isPlayerNearBed(2.1, 0.0, 2.1)); // sqrt(4.41 + 4.41) = ~2.969 <= 3.0

    // Just outside horizontal boundary: > 3.0
    try std.testing.expect(!isPlayerNearBed(3.01, 0.0, 0.0));
    try std.testing.expect(!isPlayerNearBed(2.2, 0.0, 2.2)); // sqrt(4.84 + 4.84) = ~3.11 > 3.0

    // Vertical boundary: <= 2.0
    try std.testing.expect(isPlayerNearBed(0.0, 2.0, 0.0));
    try std.testing.expect(isPlayerNearBed(0.0, -2.0, 0.0));
    try std.testing.expect(!isPlayerNearBed(0.0, 2.01, 0.0));
    try std.testing.expect(!isPlayerNearBed(0.0, -2.01, 0.0));
}

test "9. BedSleepValidation: isBlockedByMonstersNearBed detects hostile monsters within 8.0 horizontal and 5.0 vertical" {
    // Monster right at bed
    try std.testing.expect(isBlockedByMonstersNearBed(0.0, 0.0, 0.0));

    // Monster within 8.0 horizontal and 5.0 vertical
    try std.testing.expect(isBlockedByMonstersNearBed(8.0, 0.0, 0.0));
    try std.testing.expect(isBlockedByMonstersNearBed(0.0, 0.0, -8.0));
    try std.testing.expect(isBlockedByMonstersNearBed(5.0, 5.0, 5.0)); // sqrt(25+25) = ~7.07 <= 8.0, dy=5.0 <= 5.0
    try std.testing.expect(isBlockedByMonstersNearBed(-5.6, -5.0, 5.6)); // sqrt(31.36+31.36) = ~7.91 <= 8.0

    // Monster beyond 8.0 horizontal
    try std.testing.expect(!isBlockedByMonstersNearBed(8.05, 0.0, 0.0));
    try std.testing.expect(!isBlockedByMonstersNearBed(6.0, 0.0, 6.0)); // sqrt(36+36) = ~8.48 > 8.0

    // Monster beyond 5.0 vertical
    try std.testing.expect(!isBlockedByMonstersNearBed(0.0, 5.05, 0.0));
    try std.testing.expect(!isBlockedByMonstersNearBed(0.0, -5.05, 0.0));
}

test "10. BedSleepValidation: insomnia timer reset and respawn point persistence even on early exit" {
    try std.testing.expect(resetsInsomniaTimerOnLieDown());

    var session = PlayerSleepSession{
        .insomnia_timer_ticks = 72000, // 1 hour of insomnia (phantoms would spawn)
    };

    const bed_pos = BedBlockPos{ .x = 100, .y = 64, .z = -200 };
    session.lieDown(bed_pos);

    // Immediately on lie down, respawn point is set and insomnia timer is cleared to 0
    try std.testing.expect(session.is_in_bed);
    try std.testing.expect(session.respawn_set);
    try std.testing.expectEqual(bed_pos, session.respawn_pos.?);
    try std.testing.expectEqual(@as(u32, 0), session.insomnia_timer_ticks);

    // Player exits bed early before morning
    session.leaveBed();
    try std.testing.expect(!session.is_in_bed);

    // Respawn point remains set, and insomnia timer remains reset at 0!
    try std.testing.expect(session.respawn_set);
    try std.testing.expectEqual(bed_pos, session.respawn_pos.?);
    try std.testing.expectEqual(@as(u32, 0), session.insomnia_timer_ticks);
}

test "11. BedSleepValidation: completing 101 ticks (5.05s) of sleep advances time to dawn (tick 0) and clears weather" {
    try std.testing.expectEqual(@as(u16, 101), SLEEP_DURATION_TICKS);
    try std.testing.expectApproxEqAbs(@as(f32, 5.05), SLEEP_DURATION_SECONDS, 0.001);

    var session = PlayerSleepSession{};
    session.lieDown(.{ .x = 0, .y = 70, .z = 0 });

    // Ticking 100 ticks is not yet complete
    var t: u16 = 0;
    while (t < 100) : (t += 1) {
        try std.testing.expect(!session.tick());
    }
    try std.testing.expectEqual(@as(u16, 100), session.ticks_slept);

    // 101st tick completes sleep
    try std.testing.expect(session.tick());
    try std.testing.expectEqual(@as(u16, 101), session.ticks_slept);

    // Waking up resets world time to dawn (tick 0) and clears rain/thunder
    const outcome = session.wakeAtDawn();
    try std.testing.expectEqual(DAWN_TICK, outcome.time_ticks);
    try std.testing.expect(!outcome.is_raining);
    try std.testing.expect(!outcome.is_thundering);
    try std.testing.expect(!session.is_in_bed);
}

test "12. WrongDimensionBedExplosion: bed explodes with power 5.0 and fire in Nether and The End, safe in Overworld" {
    try std.testing.expect(!shouldBedExplodeInDimension(.overworld));
    try std.testing.expect(shouldBedExplodeInDimension(.nether));
    try std.testing.expect(shouldBedExplodeInDimension(.the_end));

    try std.testing.expectEqual(@as(f32, 5.0), bed_explosion_power);
    try std.testing.expect(setsSurroundingBlocksOnFire);

    // Overworld interaction is safe
    const overworld_result = WrongDimensionBedExplosion.trigger(.overworld);
    try std.testing.expect(!overworld_result.explodes);
    try std.testing.expect(!overworld_result.destroys_bed);
    try std.testing.expectEqual(@as(f32, 0.0), overworld_result.power);
    try std.testing.expect(overworld_result.can_sleep);

    // Nether explodes immediately
    const nether_result = WrongDimensionBedExplosion.trigger(.nether);
    try std.testing.expect(nether_result.explodes);
    try std.testing.expect(nether_result.destroys_bed);
    try std.testing.expectEqual(@as(f32, 5.0), nether_result.power);
    try std.testing.expect(nether_result.sets_fire);
    try std.testing.expect(!nether_result.can_sleep);

    // The End explodes immediately
    const end_result = WrongDimensionBedExplosion.trigger(.the_end);
    try std.testing.expect(end_result.explodes);
    try std.testing.expect(end_result.destroys_bed);
    try std.testing.expectEqual(@as(f32, 5.0), end_result.power);
    try std.testing.expect(end_result.sets_fire);
    try std.testing.expect(!end_result.can_sleep);
}

test "13. BedBounceCushion: landing on bed reduces fall damage by exactly 50%" {
    // 0 or negative raw damage returns 0
    try std.testing.expectEqual(@as(f32, 0.0), computeBedFallDamage(0.0));
    try std.testing.expectEqual(@as(f32, 0.0), computeBedFallDamage(-5.0));

    // Positive fall damage reduced by 50%
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), computeBedFallDamage(5.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), computeBedFallDamage(10.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), computeBedFallDamage(20.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), computeBedFallDamage(100.0), 0.001);

    // Namespace consistency
    try std.testing.expectEqual(computeBedFallDamage(14.0), BedBounceCushion.computeBedFallDamage(14.0));
    try std.testing.expectEqual(@as(f32, 0.5), BedBounceCushion.fall_damage_multiplier);
}

test "14. BedBounceCushion: upward rebound velocity is 66% of downward impact speed" {
    // Zero impact returns 0
    try std.testing.expectEqual(@as(f32, 0.0), computeBedBounceVy(0.0));

    // Downward impact velocity (-10.0 m/s) rebounds upward with +6.6 m/s
    try std.testing.expectApproxEqAbs(@as(f32, 6.6), computeBedBounceVy(-10.0), 0.001);

    // Positive magnitude speed input (10.0 m/s) also rebounds upward with +6.6 m/s
    try std.testing.expectApproxEqAbs(@as(f32, 6.6), computeBedBounceVy(10.0), 0.001);

    // Higher downward speed (-20.0 m/s) rebounds with +13.2 m/s
    try std.testing.expectApproxEqAbs(@as(f32, 13.2), computeBedBounceVy(-20.0), 0.001);

    // Namespace consistency
    try std.testing.expectEqual(computeBedBounceVy(-15.0), BedBounceCushion.computeBedBounceVy(-15.0));
    try std.testing.expectEqual(@as(f32, 0.66), BedBounceCushion.bounce_rebound_ratio);
}

test "15. BedSleepValidation: comprehensive validateSleep() status check for all conditions" {
    // Valid night sleep in overworld
    const ok_res = BedSleepValidation.validateSleep(
        .overworld,
        18000,
        false,
        false,
        1.0,
        0.5,
        1.0,
        null,
    );
    try std.testing.expectEqual(SleepValidationResult.ok, ok_res);

    // Wrong dimension (.nether)
    const nether_res = BedSleepValidation.validateSleep(
        .nether,
        18000,
        false,
        false,
        1.0,
        0.5,
        1.0,
        null,
    );
    try std.testing.expectEqual(SleepValidationResult.wrong_dimension, nether_res);

    // Too far away from bed (horizontal dx = 4.0 > 3.0)
    const far_res = BedSleepValidation.validateSleep(
        .overworld,
        18000,
        false,
        false,
        4.0,
        0.0,
        0.0,
        null,
    );
    try std.testing.expectEqual(SleepValidationResult.too_far_away, far_res);

    // Hostile monster nearby (dx = 3.0, dy = 1.0, dz = 2.0 <= 8.0 horiz, 5.0 vert)
    const monster_res = BedSleepValidation.validateSleep(
        .overworld,
        18000,
        false,
        false,
        1.0,
        0.0,
        1.0,
        .{ 3.0, 1.0, 2.0 },
    );
    try std.testing.expectEqual(SleepValidationResult.monsters_nearby, monster_res);

    // Daytime in clear weather (tick 6000)
    const daytime_res = BedSleepValidation.validateSleep(
        .overworld,
        6000,
        false,
        false,
        1.0,
        0.0,
        1.0,
        null,
    );
    try std.testing.expectEqual(SleepValidationResult.not_possible_now, daytime_res);

    // Daytime during thunderstorm (tick 6000) -> Allowed!
    const thunder_res = BedSleepValidation.validateSleep(
        .overworld,
        6000,
        false,
        true,
        1.0,
        0.0,
        1.0,
        null,
    );
    try std.testing.expectEqual(SleepValidationResult.ok, thunder_res);
}
