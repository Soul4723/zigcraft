const std = @import("std");

// ============================================================================
// Dimensions
// ============================================================================

/// Canonical Minecraft dimensions.
pub const Dimension = enum {
    overworld,
    nether,
    the_end,

    pub fn name(self: Dimension) []const u8 {
        return switch (self) {
            .overworld => "Overworld",
            .nether => "Nether",
            .the_end => "The End",
        };
    }
};

// ============================================================================
// Recipe Constants & Crafting Functions
// ============================================================================

pub const LODESTONE_RECIPE_CHISELED_STONE_BRICKS: u32 = 8;
pub const LODESTONE_RECIPE_NETHERITE_INGOT: u32 = 1;
pub const LODESTONE_RECIPE_OUTPUT: u32 = 1;

pub const RECOVERY_COMPASS_COMPASS_REQUIRED: u32 = 1;
pub const RECOVERY_COMPASS_ECHO_SHARDS_REQUIRED: u32 = 8;
pub const RECOVERY_COMPASS_OUTPUT: u32 = 1;

pub const CLOCK_GOLD_INGOTS_REQUIRED: u32 = 4;
pub const CLOCK_REDSTONE_DUST_REQUIRED: u32 = 1;
pub const CLOCK_OUTPUT: u32 = 1;

pub const BED_ALLOWED_START_TICK: u32 = 12542;
pub const BED_ALLOWED_END_TICK: u32 = 23459;

/// Crafts a Lodestone from 8 chiseled stone bricks and 1 netherite ingot.
pub fn craftLodestone(chiseled_stone_bricks: u32, netherite_ingots: u32) ?u32 {
    if (chiseled_stone_bricks < LODESTONE_RECIPE_CHISELED_STONE_BRICKS or
        netherite_ingots < LODESTONE_RECIPE_NETHERITE_INGOT)
    {
        return null;
    }
    return @min(
        chiseled_stone_bricks / LODESTONE_RECIPE_CHISELED_STONE_BRICKS,
        netherite_ingots / LODESTONE_RECIPE_NETHERITE_INGOT,
    );
}

/// Crafts a Recovery Compass from 1 compass and 8 echo shards.
pub fn craftRecoveryCompass(compass_count: u32, echo_shards: u32) ?u32 {
    if (compass_count < RECOVERY_COMPASS_COMPASS_REQUIRED or
        echo_shards < RECOVERY_COMPASS_ECHO_SHARDS_REQUIRED)
    {
        return null;
    }
    return @min(
        compass_count / RECOVERY_COMPASS_COMPASS_REQUIRED,
        echo_shards / RECOVERY_COMPASS_ECHO_SHARDS_REQUIRED,
    );
}

/// Crafts a Clock from 4 gold ingots and 1 redstone dust.
pub fn craftClock(gold_ingots: u32, redstone_dust: u32) ?u32 {
    if (gold_ingots < CLOCK_GOLD_INGOTS_REQUIRED or
        redstone_dust < CLOCK_REDSTONE_DUST_REQUIRED)
    {
        return null;
    }
    return @min(
        gold_ingots / CLOCK_GOLD_INGOTS_REQUIRED,
        redstone_dust / CLOCK_REDSTONE_DUST_REQUIRED,
    );
}

// ============================================================================
// Needle Math & Reading Struct
// ============================================================================

/// Represents the instantaneous output state of a compass needle dial.
pub const NeedleReading = struct {
    /// Screen/camera-relative needle angle in radians.
    angle: f32,
    /// Whether the needle is wildly spinning instead of pointing to a target.
    is_spinning_randomly: bool,
    /// Enchanted visual glint (true for Lodestone Compass).
    has_glint: bool,
    /// True when the needle is locked onto a valid target block.
    points_to_target: bool,
};

/// Calculates screen-relative compass needle angle in radians towards target (x, z).
pub fn calculateNeedleAngle(
    target_x: f32,
    target_z: f32,
    player_x: f32,
    player_z: f32,
    cam_yaw: f32,
) f32 {
    const bearing = std.math.atan2(target_x - player_x, target_z - player_z);
    return bearing - (std.math.pi / 2.0 - cam_yaw);
}

/// Calculates pseudo-random chaotic fluctuating spin angle of an uncalibrated or broken compass needle.
pub fn calculateRandomSpinAngle(world_time: f32, cam_yaw: f32) f32 {
    const spin = world_time * 8.0 + @sin(world_time * 4.7) * 1.5;
    return spin - (std.math.pi / 2.0 - cam_yaw);
}

/// Global helper to evaluate if a compass needle should spin randomly given dimensions and block state.
pub fn shouldNeedleSpinRandomly(
    target_dimension: Dimension,
    current_dimension: Dimension,
    lodestone_intact: bool,
) bool {
    if (!lodestone_intact) return true;
    if (target_dimension != current_dimension) return true;
    return false;
}

// ============================================================================
// Lodestone Compass & Pairing
// ============================================================================

/// A compass bound to a specific Lodestone block in any dimension.
pub const LodestoneCompass = struct {
    dimension: Dimension,
    x: i32,
    y: i32,
    z: i32,
    lodestone_intact: bool = true,

    /// Lodestone compasses always emit an enchanted purple-cyan glint.
    pub fn hasEnchantedGlint(self: LodestoneCompass) bool {
        _ = self;
        return true;
    }

    /// True if player is in another dimension OR the bound Lodestone has been broken.
    pub fn shouldNeedleSpinRandomly(self: LodestoneCompass, current_dimension: Dimension) bool {
        if (!self.lodestone_intact) return true;
        if (self.dimension != current_dimension) return true;
        return false;
    }

    /// World-space target center coordinates.
    pub fn targetX(self: LodestoneCompass) f32 {
        return @as(f32, @floatFromInt(self.x)) + 0.5;
    }

    pub fn targetY(self: LodestoneCompass) f32 {
        return @as(f32, @floatFromInt(self.y)) + 0.5;
    }

    pub fn targetZ(self: LodestoneCompass) f32 {
        return @as(f32, @floatFromInt(self.z)) + 0.5;
    }

    /// Evaluates current needle state.
    pub fn calculateReading(
        self: LodestoneCompass,
        current_dimension: Dimension,
        player_x: f32,
        player_z: f32,
        cam_yaw: f32,
        world_time: f32,
    ) NeedleReading {
        const needle = LodestoneCompassNeedle{ .compass = self };
        return needle.calculateReading(current_dimension, player_x, player_z, cam_yaw, world_time);
    }
};

/// Needle subsystem for a Lodestone Compass.
pub const LodestoneCompassNeedle = struct {
    compass: LodestoneCompass,

    pub fn shouldNeedleSpinRandomly(self: LodestoneCompassNeedle, current_dimension: Dimension) bool {
        return self.compass.shouldNeedleSpinRandomly(current_dimension);
    }

    pub fn hasEnchantedGlint(self: LodestoneCompassNeedle) bool {
        return self.compass.hasEnchantedGlint();
    }

    pub fn calculateReading(
        self: LodestoneCompassNeedle,
        current_dimension: Dimension,
        player_x: f32,
        player_z: f32,
        cam_yaw: f32,
        world_time: f32,
    ) NeedleReading {
        if (self.shouldNeedleSpinRandomly(current_dimension)) {
            return .{
                .angle = calculateRandomSpinAngle(world_time, cam_yaw),
                .is_spinning_randomly = true,
                .has_glint = true,
                .points_to_target = false,
            };
        }

        const angle = calculateNeedleAngle(
            self.compass.targetX(),
            self.compass.targetZ(),
            player_x,
            player_z,
            cam_yaw,
        );

        return .{
            .angle = angle,
            .is_spinning_randomly = false,
            .has_glint = true,
            .points_to_target = true,
        };
    }
};

/// Manages Lodestone crafting and right-click compass binding mechanics.
pub const LodestonePairing = struct {
    pub const CHISELED_STONE_BRICKS: u32 = LODESTONE_RECIPE_CHISELED_STONE_BRICKS;
    pub const NETHERITE_INGOT: u32 = LODESTONE_RECIPE_NETHERITE_INGOT;
    pub const OUTPUT_LODESTONE: u32 = LODESTONE_RECIPE_OUTPUT;

    pub fn craft(chiseled_bricks: u32, netherite_ingots: u32) ?u32 {
        return craftLodestone(chiseled_bricks, netherite_ingots);
    }

    /// Right-clicking a Lodestone with a regular Compass binds it into a LodestoneCompass
    /// storing (dimension, x, y, z). Works in Overworld, Nether, and The End!
    pub fn bindCompassToLodestone(dim: Dimension, x: i32, y: i32, z: i32) LodestoneCompass {
        return .{
            .dimension = dim,
            .x = x,
            .y = y,
            .z = z,
            .lodestone_intact = true,
        };
    }

    /// Handles interaction when player right-clicks with held item on a block.
    pub fn interact(
        held_is_regular_compass: bool,
        target_is_lodestone: bool,
        dimension: Dimension,
        x: i32,
        y: i32,
        z: i32,
    ) ?LodestoneCompass {
        if (!held_is_regular_compass or !target_is_lodestone) return null;
        return LodestonePairing.bindCompassToLodestone(dimension, x, y, z);
    }
};

/// Binds a regular Compass to a Lodestone at the given coordinates and dimension.
pub fn bindCompassToLodestone(dim: Dimension, x: i32, y: i32, z: i32) LodestoneCompass {
    return LodestonePairing.bindCompassToLodestone(dim, x, y, z);
}

// ============================================================================
// Recovery Compass
// ============================================================================

/// Tracks the player's last death location across dimensions.
pub const RecoveryCompass = struct {
    has_last_death: bool = false,
    death_dimension: Dimension = .overworld,
    death_x: i32 = 0,
    death_y: i32 = 0,
    death_z: i32 = 0,

    pub const COMPASS_REQUIRED: u32 = RECOVERY_COMPASS_COMPASS_REQUIRED;
    pub const ECHO_SHARDS_REQUIRED: u32 = RECOVERY_COMPASS_ECHO_SHARDS_REQUIRED;
    pub const OUTPUT_COUNT: u32 = RECOVERY_COMPASS_OUTPUT;

    pub fn craft(compass_count: u32, echo_shards: u32) ?u32 {
        return craftRecoveryCompass(compass_count, echo_shards);
    }

    /// Records the player's death event coordinates and dimension.
    pub fn recordDeath(self: *RecoveryCompass, dim: Dimension, x: i32, y: i32, z: i32) void {
        self.has_last_death = true;
        self.death_dimension = dim;
        self.death_x = x;
        self.death_y = y;
        self.death_z = z;
    }

    /// Clears the last death point (e.g., world reset or command).
    pub fn clearDeath(self: *RecoveryCompass) void {
        self.has_last_death = false;
    }

    /// Returns true if the player hasn't died yet, or is currently in a different dimension than their death.
    pub fn shouldNeedleSpinRandomly(self: RecoveryCompass, current_dimension: Dimension) bool {
        if (!self.has_last_death) return true;
        if (self.death_dimension != current_dimension) return true;
        return false;
    }

    pub fn targetX(self: RecoveryCompass) f32 {
        return @as(f32, @floatFromInt(self.death_x)) + 0.5;
    }

    pub fn targetY(self: RecoveryCompass) f32 {
        return @as(f32, @floatFromInt(self.death_y)) + 0.5;
    }

    pub fn targetZ(self: RecoveryCompass) f32 {
        return @as(f32, @floatFromInt(self.death_z)) + 0.5;
    }

    /// Calculates needle reading pointing to last death location, or spinning randomly.
    pub fn calculateReading(
        self: RecoveryCompass,
        current_dimension: Dimension,
        player_x: f32,
        player_z: f32,
        cam_yaw: f32,
        world_time: f32,
    ) NeedleReading {
        if (self.shouldNeedleSpinRandomly(current_dimension)) {
            return .{
                .angle = calculateRandomSpinAngle(world_time, cam_yaw),
                .is_spinning_randomly = true,
                .has_glint = false,
                .points_to_target = false,
            };
        }

        const angle = calculateNeedleAngle(
            self.targetX(),
            self.targetZ(),
            player_x,
            player_z,
            cam_yaw,
        );

        return .{
            .angle = angle,
            .is_spinning_randomly = false,
            .has_glint = false,
            .points_to_target = true,
        };
    }
};

// ============================================================================
// Clock Dial & Day Phase Rules
// ============================================================================

/// In the Nether and The End, clocks spin rapidly and cannot be used to tell time.
pub fn doesClockSpinWildlyInDimension(dimension: Dimension) bool {
    return dimension != .overworld;
}

/// Checks whether the player is permitted to sleep in a bed during Overworld time.
/// In Minecraft, bed sleep is permitted during dusk and night from tick 12542 to 23459.
pub fn isBedAllowed(time_of_day_ticks: u32) bool {
    const norm = time_of_day_ticks % 24000;
    return norm >= BED_ALLOWED_START_TICK and norm <= BED_ALLOWED_END_TICK;
}

/// Overworld daylight cycle phase shown on the clock dial.
pub const ClockDialPhase = enum {
    morning,
    noon,
    dusk_bed_allowed,
    midnight,

    pub const GOLD_INGOTS_REQUIRED: u32 = CLOCK_GOLD_INGOTS_REQUIRED;
    pub const REDSTONE_DUST_REQUIRED: u32 = CLOCK_REDSTONE_DUST_REQUIRED;
    pub const OUTPUT_COUNT: u32 = CLOCK_OUTPUT;

    pub fn doesClockSpinWildlyInDimension(dim: Dimension) bool {
        return dim != .overworld;
    }

    pub fn craft(gold_ingots: u32, redstone_dust: u32) ?u32 {
        return craftClock(gold_ingots, redstone_dust);
    }

    /// Maps Overworld time_of_day_ticks (0..23999) to:
    /// - .morning:          0..5999
    /// - .noon:             6000..12541
    /// - .dusk_bed_allowed: 12542..17999 (exact bed entry permitted at 12542)
    /// - .midnight:         18000..23999
    pub fn fromTicks(time_of_day_ticks: u32) ClockDialPhase {
        const norm = time_of_day_ticks % 24000;
        if (norm < 6000) {
            return .morning;
        } else if (norm < BED_ALLOWED_START_TICK) {
            return .noon;
        } else if (norm < 18000) {
            return .dusk_bed_allowed;
        } else {
            return .midnight;
        }
    }

    /// True if the phase is part of the night bed-permitted period.
    pub fn isBedAllowed(self: ClockDialPhase) bool {
        return switch (self) {
            .dusk_bed_allowed, .midnight => true,
            .morning, .noon => false,
        };
    }

    pub fn name(self: ClockDialPhase) []const u8 {
        return switch (self) {
            .morning => "Morning",
            .noon => "Noon",
            .dusk_bed_allowed => "Dusk (Bed Allowed)",
            .midnight => "Midnight",
        };
    }
};

/// Maps Overworld time of day ticks to ClockDialPhase.
pub fn getClockDialPhase(time_of_day_ticks: u32) ClockDialPhase {
    return ClockDialPhase.fromTicks(time_of_day_ticks);
}

/// Evaluates ClockDialPhase in the given dimension.
/// Returns null in the Nether and The End where the clock dial spins wildly.
pub fn getClockPhaseInDimension(dimension: Dimension, time_of_day_ticks: u32) ?ClockDialPhase {
    if (doesClockSpinWildlyInDimension(dimension)) return null;
    return ClockDialPhase.fromTicks(time_of_day_ticks);
}

/// Calculates clock dial rotational angle (in radians).
/// In the Overworld, maps 0..23999 linearly to 0..2*pi.
/// In the Nether and The End, spins rapidly and erratically.
pub fn calculateClockDialAngle(
    dimension: Dimension,
    time_of_day_ticks: u32,
    world_time: f32,
) f32 {
    if (doesClockSpinWildlyInDimension(dimension)) {
        return world_time * 18.0 + @sin(world_time * 7.9) * 2.5;
    }
    const norm = time_of_day_ticks % 24000;
    return (@as(f32, @floatFromInt(norm)) / 24000.0) * (std.math.pi * 2.0);
}

// ============================================================================
// Comprehensive Unit Tests (>= 12 tests)
// ============================================================================

test "1. Lodestone crafting requires 8 chiseled stone bricks and 1 netherite ingot" {
    // Valid recipe
    const result = craftLodestone(8, 1);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u32, 1), result.?);

    // Batch craft
    const batch = LodestonePairing.craft(16, 2);
    try std.testing.expect(batch != null);
    try std.testing.expectEqual(@as(u32, 2), batch.?);

    // Insufficient chiseled stone bricks
    try std.testing.expectEqual(@as(?u32, null), craftLodestone(7, 1));

    // Insufficient netherite ingot
    try std.testing.expectEqual(@as(?u32, null), craftLodestone(8, 0));
}

test "2. Lodestone pairing binds compass to lodestone coordinates in Overworld" {
    const compass = bindCompassToLodestone(.overworld, 150, 64, -300);
    try std.testing.expectEqual(Dimension.overworld, compass.dimension);
    try std.testing.expectEqual(@as(i32, 150), compass.x);
    try std.testing.expectEqual(@as(i32, 64), compass.y);
    try std.testing.expectEqual(@as(i32, -300), compass.z);
    try std.testing.expect(compass.lodestone_intact);
    try std.testing.expect(compass.hasEnchantedGlint());
}

test "3. Lodestone pairing works in the Nether and The End" {
    // Nether binding
    const nether_compass = bindCompassToLodestone(.nether, 25, 48, 80);
    try std.testing.expectEqual(Dimension.nether, nether_compass.dimension);
    try std.testing.expectEqual(@as(i32, 25), nether_compass.x);
    try std.testing.expectEqual(@as(i32, 48), nether_compass.y);
    try std.testing.expectEqual(@as(i32, 80), nether_compass.z);

    // The End binding
    const end_compass = LodestonePairing.bindCompassToLodestone(.the_end, 0, 70, 0);
    try std.testing.expectEqual(Dimension.the_end, end_compass.dimension);
    try std.testing.expectEqual(@as(i32, 0), end_compass.x);
    try std.testing.expectEqual(@as(i32, 70), end_compass.y);
    try std.testing.expectEqual(@as(i32, 0), end_compass.z);
}

test "4. Lodestone interaction right-click logic requires regular compass and lodestone block" {
    const success = LodestonePairing.interact(true, true, .overworld, 10, 65, 20);
    try std.testing.expect(success != null);
    try std.testing.expectEqual(@as(i32, 10), success.?.x);

    // Held item is not a compass
    const fail_held = LodestonePairing.interact(false, true, .overworld, 10, 65, 20);
    try std.testing.expectEqual(@as(?LodestoneCompass, null), fail_held);

    // Target block is not a lodestone
    const fail_target = LodestonePairing.interact(true, false, .overworld, 10, 65, 20);
    try std.testing.expectEqual(@as(?LodestoneCompass, null), fail_target);
}

test "5. LodestoneCompass needle points directly at target in same dimension when intact" {
    const compass = bindCompassToLodestone(.overworld, 0, 64, 10);
    const needle = LodestoneCompassNeedle{ .compass = compass };

    // Player in same dimension, lodestone intact
    try std.testing.expect(!compass.shouldNeedleSpinRandomly(.overworld));
    try std.testing.expect(!needle.shouldNeedleSpinRandomly(.overworld));
    try std.testing.expect(needle.hasEnchantedGlint());

    // Reading directly north: target (0.5, 10.5), player (0.5, 0.5), cam_yaw = -pi/2
    const reading = compass.calculateReading(.overworld, 0.5, 0.5, -std.math.pi / 2.0, 1.0);
    try std.testing.expect(!reading.is_spinning_randomly);
    try std.testing.expect(reading.points_to_target);
    try std.testing.expect(reading.has_glint);
    try std.testing.expectApproxEqAbs(@as(f32, -std.math.pi), reading.angle, 0.001);
}

test "6. LodestoneCompass needle spins randomly when player is in different dimension" {
    const compass = bindCompassToLodestone(.nether, 100, 50, 100);

    // Player is in Overworld, compass bound to Nether
    try std.testing.expect(compass.shouldNeedleSpinRandomly(.overworld));
    try std.testing.expect(shouldNeedleSpinRandomly(.nether, .overworld, true));

    const reading = compass.calculateReading(.overworld, 0.0, 0.0, 0.0, 2.5);
    try std.testing.expect(reading.is_spinning_randomly);
    try std.testing.expect(!reading.points_to_target);
    try std.testing.expect(reading.has_glint);
}

test "7. LodestoneCompass needle spins randomly when bound lodestone block is broken" {
    var compass = bindCompassToLodestone(.overworld, 40, 70, 80);
    try std.testing.expect(!compass.shouldNeedleSpinRandomly(.overworld));

    // Break the lodestone block
    compass.lodestone_intact = false;
    try std.testing.expect(compass.shouldNeedleSpinRandomly(.overworld));
    try std.testing.expect(shouldNeedleSpinRandomly(.overworld, .overworld, false));

    const needle = LodestoneCompassNeedle{ .compass = compass };
    try std.testing.expect(needle.shouldNeedleSpinRandomly(.overworld));

    const reading = needle.calculateReading(.overworld, 40.5, 0.0, 0.0, 3.0);
    try std.testing.expect(reading.is_spinning_randomly);
    try std.testing.expect(!reading.points_to_target);
    try std.testing.expect(reading.has_glint);
}

test "8. RecoveryCompass crafting requires 1 compass and 8 echo shards" {
    // 1 compass + 8 echo shards -> 1 recovery compass
    const result = craftRecoveryCompass(1, 8);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u32, 1), result.?);

    // Multiple craft
    const batch = RecoveryCompass.craft(2, 16);
    try std.testing.expect(batch != null);
    try std.testing.expectEqual(@as(u32, 2), batch.?);

    // Insufficient shards
    try std.testing.expectEqual(@as(?u32, null), craftRecoveryCompass(1, 7));

    // Missing compass
    try std.testing.expectEqual(@as(?u32, null), craftRecoveryCompass(0, 8));
}

test "9. RecoveryCompass spins randomly before player has ever died" {
    const compass = RecoveryCompass{};
    try std.testing.expect(!compass.has_last_death);

    // Needle spins randomly in all dimensions
    try std.testing.expect(compass.shouldNeedleSpinRandomly(.overworld));
    try std.testing.expect(compass.shouldNeedleSpinRandomly(.nether));
    try std.testing.expect(compass.shouldNeedleSpinRandomly(.the_end));

    const reading = compass.calculateReading(.overworld, 0.0, 0.0, 0.0, 1.0);
    try std.testing.expect(reading.is_spinning_randomly);
    try std.testing.expect(!reading.points_to_target);
    try std.testing.expect(!reading.has_glint);
}

test "10. RecoveryCompass points to death location when in same dimension" {
    var compass = RecoveryCompass{};
    compass.recordDeath(.nether, 100, 32, -200);

    try std.testing.expect(compass.has_last_death);
    try std.testing.expectEqual(Dimension.nether, compass.death_dimension);
    try std.testing.expectEqual(@as(i32, 100), compass.death_x);
    try std.testing.expectEqual(@as(i32, 32), compass.death_y);
    try std.testing.expectEqual(@as(i32, -200), compass.death_z);

    // When player is in Nether, needle tracks target
    try std.testing.expect(!compass.shouldNeedleSpinRandomly(.nether));

    const reading = compass.calculateReading(.nether, 100.5, 0.0, 0.0, 1.0);
    try std.testing.expect(!reading.is_spinning_randomly);
    try std.testing.expect(reading.points_to_target);
    try std.testing.expect(!reading.has_glint);
}

test "11. RecoveryCompass spins randomly when player is in different dimension from death" {
    var compass = RecoveryCompass{};
    compass.recordDeath(.the_end, 50, 60, -50);

    // Player respawns in Overworld
    try std.testing.expect(compass.shouldNeedleSpinRandomly(.overworld));
    try std.testing.expect(compass.shouldNeedleSpinRandomly(.nether));
    try std.testing.expect(!compass.shouldNeedleSpinRandomly(.the_end));

    const reading = compass.calculateReading(.overworld, 0.0, 0.0, 0.0, 2.0);
    try std.testing.expect(reading.is_spinning_randomly);
    try std.testing.expect(!reading.points_to_target);

    // Clearing death point resets tracking
    compass.clearDeath();
    try std.testing.expect(!compass.has_last_death);
    try std.testing.expect(compass.shouldNeedleSpinRandomly(.the_end));
}

test "12. Clock crafting requires 4 gold ingots and 1 redstone dust" {
    // 4 gold ingots + 1 redstone dust -> 1 clock
    const result = craftClock(4, 1);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u32, 1), result.?);

    // Batch craft
    const batch = ClockDialPhase.craft(8, 3);
    try std.testing.expect(batch != null);
    try std.testing.expectEqual(@as(u32, 2), batch.?);

    // Insufficient gold ingots
    try std.testing.expectEqual(@as(?u32, null), craftClock(3, 1));

    // Insufficient redstone dust
    try std.testing.expectEqual(@as(?u32, null), craftClock(4, 0));
}

test "13. Clock dial maps Overworld day-phases correctly" {
    // 0..5999 -> .morning
    try std.testing.expectEqual(ClockDialPhase.morning, getClockDialPhase(0));
    try std.testing.expectEqual(ClockDialPhase.morning, getClockDialPhase(1000));
    try std.testing.expectEqual(ClockDialPhase.morning, getClockDialPhase(5999));

    // 6000..12541 -> .noon
    try std.testing.expectEqual(ClockDialPhase.noon, getClockDialPhase(6000));
    try std.testing.expectEqual(ClockDialPhase.noon, getClockDialPhase(9000));
    try std.testing.expectEqual(ClockDialPhase.noon, getClockDialPhase(12541));

    // 12542..17999 -> .dusk_bed_allowed
    try std.testing.expectEqual(ClockDialPhase.dusk_bed_allowed, getClockDialPhase(12542));
    try std.testing.expectEqual(ClockDialPhase.dusk_bed_allowed, getClockDialPhase(15000));
    try std.testing.expectEqual(ClockDialPhase.dusk_bed_allowed, getClockDialPhase(17999));

    // 18000..23999 -> .midnight
    try std.testing.expectEqual(ClockDialPhase.midnight, getClockDialPhase(18000));
    try std.testing.expectEqual(ClockDialPhase.midnight, getClockDialPhase(20000));
    try std.testing.expectEqual(ClockDialPhase.midnight, getClockDialPhase(23999));

    // Day wraparound modulo 24000
    try std.testing.expectEqual(ClockDialPhase.morning, getClockDialPhase(24000));
    try std.testing.expectEqual(ClockDialPhase.noon, getClockDialPhase(30000));
}

test "14. Overworld bed allowed interval spans exactly 12542 to 23459 ticks" {
    // Before dusk bed allowed
    try std.testing.expect(!isBedAllowed(0));
    try std.testing.expect(!isBedAllowed(6000));
    try std.testing.expect(!isBedAllowed(12541));

    // Bed allowed interval (12542..23459)
    try std.testing.expect(isBedAllowed(12542));
    try std.testing.expect(isBedAllowed(15000));
    try std.testing.expect(isBedAllowed(18000));
    try std.testing.expect(isBedAllowed(23459));

    // Morning wake-up at 23460
    try std.testing.expect(!isBedAllowed(23460));
    try std.testing.expect(!isBedAllowed(23999));

    // Enum phase bed allowed query
    try std.testing.expect(!ClockDialPhase.morning.isBedAllowed());
    try std.testing.expect(!ClockDialPhase.noon.isBedAllowed());
    try std.testing.expect(ClockDialPhase.dusk_bed_allowed.isBedAllowed());
    try std.testing.expect(ClockDialPhase.midnight.isBedAllowed());
}

test "15. Clock dial spins wildly in Nether and The End but tells time in Overworld" {
    // Dimension check
    try std.testing.expect(!doesClockSpinWildlyInDimension(.overworld));
    try std.testing.expect(doesClockSpinWildlyInDimension(.nether));
    try std.testing.expect(doesClockSpinWildlyInDimension(.the_end));
    try std.testing.expect(ClockDialPhase.doesClockSpinWildlyInDimension(.nether));

    // Phase retrieval in dimension
    try std.testing.expectEqual(ClockDialPhase.morning, getClockPhaseInDimension(.overworld, 1000).?);
    try std.testing.expectEqual(@as(?ClockDialPhase, null), getClockPhaseInDimension(.nether, 1000));
    try std.testing.expectEqual(@as(?ClockDialPhase, null), getClockPhaseInDimension(.the_end, 1000));

    // Overworld clock dial angle is linear
    const angle_0 = calculateClockDialAngle(.overworld, 0, 0.0);
    const angle_noon = calculateClockDialAngle(.overworld, 6000, 0.0);
    const angle_midnight = calculateClockDialAngle(.overworld, 18000, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), angle_0, 0.001);
    try std.testing.expectApproxEqAbs(std.math.pi * 0.5, angle_noon, 0.001);
    try std.testing.expectApproxEqAbs(std.math.pi * 1.5, angle_midnight, 0.001);

    // Nether clock dial angle spins wildly over time
    const nether_spin_1 = calculateClockDialAngle(.nether, 6000, 1.0);
    const nether_spin_2 = calculateClockDialAngle(.nether, 6000, 2.0);
    try std.testing.expect(nether_spin_1 != nether_spin_2);
}

test "16. Needle random spin angle varies with world time" {
    const s1 = calculateRandomSpinAngle(1.0, 0.0);
    const s2 = calculateRandomSpinAngle(2.5, 0.0);
    try std.testing.expect(s1 != s2);
}
