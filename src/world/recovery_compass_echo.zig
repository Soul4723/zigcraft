//! ============================================================================
//! Milestone 469: Recovery Compass Echo Shard Metallurgy & Death Location Lock
//! ============================================================================
//!
//! Overview:
//!   The Recovery Compass is an advanced navigational tool crafted from 8 Echo
//!   Shards surrounding a standard Compass. Unlike conventional compasses that
//!   point to world spawn or Lodestone compasses bound to physical blocks, the
//!   Recovery Compass tracks the exact coordinate [3]i32 where the holding player
//!   most recently perished.
//!
//! Key Behaviors & Specifications:
//!   1. Echo Shard Material & Loot Exclusivity:
//!      - Echo Shards (`ItemType.echo_shard`) generate exclusively in Ancient City
//!        chest loot (~29.8% chance, 1-3 shards per chest).
//!      - Non-Ancient-City chest loot pools disallow Echo Shard generation.
//!   2. Crafting Metallurgy:
//!      - 3x3 crafting grid: 1 Compass in the center slot (index 4) surrounded
//!        by 8 Echo Shards (slots 0, 1, 2, 3, 5, 6, 7, 8) produces 1 Recovery Compass.
//!      - Intrinsic enchanted glint: Recovery Compass has `hasGlint() = true`.
//!   3. Player Death Tracking & Coordinate Lock:
//!      - `PlayerDeathTracker` tracks the `[3]i32` coordinates and `Dimension` of
//!        each player's most recent death event (`onPlayerDeath`).
//!      - Never-died state: If the player has never died, the needle unlocks
//!        (`has_lock = false`, `is_spinning = true`) and spins erratically.
//!      - Interdimensional state: If the death dimension differs from current
//!        dimension, needle unlocks and spins erratically (`is_interdimensional = true`).
//!      - Same-dimension lock: If in the same dimension, needle locks onto the
//!        death coordinates (X, Z).
//!   4. Needle Azimuth & Kinematics:
//!      - Target azimuth from player to death coordinates.
//!      - Relative needle angle factoring in player heading yaw.
//!      - Spring-damper rotational smoothing modeling a jewel-bearing compass.
//!   5. Respawn & Death Overwrite:
//!      - Subsequent deaths overwrite previous death coordinates with newest position.

const std = @import("std");

// ============================================================================
// Mathematical Constants & Angle Helpers
// ============================================================================

pub const PI: f32 = std.math.pi;
pub const TWO_PI: f32 = std.math.pi * 2.0;
pub const HALF_PI: f32 = std.math.pi / 2.0;
pub const EPSILON: f32 = 1e-5;

pub const JEWEL_BEARING_SPRING_K: f32 = 42.0;
pub const JEWEL_BEARING_DAMPING: f32 = 7.0;
pub const MAX_NEEDLE_VELOCITY: f32 = 60.0;

/// Normalizes an angle in radians into the canonical interval [-pi, pi].
pub fn normalizeAngle(angle: f32) f32 {
    return std.math.atan2(@sin(angle), @cos(angle));
}

/// Computes the shortest angular difference from `from` to `to` in [-pi, pi].
/// Positive indicates clockwise/increasing rotation, negative counter-clockwise.
pub fn shortestAngleDiff(from: f32, to: f32) f32 {
    return normalizeAngle(to - from);
}

/// Interpolates an angle toward a target along the shortest arc.
pub fn interpolateAngle(current: f32, target: f32, step_fraction: f32) f32 {
    const diff = shortestAngleDiff(current, target);
    const clamped_frac = std.math.clamp(step_fraction, 0.0, 1.0);
    return normalizeAngle(current + diff * clamped_frac);
}

/// Exponential smoothing towards target angle over delta time dt.
pub fn smoothTurnNeedle(current: f32, target: f32, dt: f32, turn_speed: f32) f32 {
    const diff = shortestAngleDiff(current, target);
    const factor = 1.0 - @exp(-turn_speed * dt);
    return normalizeAngle(current + diff * std.math.clamp(factor, 0.0, 1.0));
}

// ============================================================================
// Canonical Dimensions
// ============================================================================

/// Canonical Minecraft dimensions.
pub const Dimension = enum(u8) {
    overworld = 0,
    nether = 1,
    the_end = 2,

    pub fn name(self: Dimension) []const u8 {
        return switch (self) {
            .overworld => "Overworld",
            .nether => "Nether",
            .the_end => "The End",
        };
    }

    pub fn id(self: Dimension) u8 {
        return @intFromEnum(self);
    }
};

// ============================================================================
// Item Types, Stacks, and Classification
// ============================================================================

/// Item IDs mirrored from inventory.zig so this world module remains self-contained.
pub const ItemType = enum(u16) {
    compass = 100,
    lodestone_compass = 101,
    sculk = 305,
    sculk_catalyst = 306,
    echo_shard = 307,
    recovery_compass = 308,
    warden_spawn_egg = 309,
    disc_fragment_5 = 310,
    music_disc_5 = 311,
    swift_sneak_book = 312,

    pub fn maxStackSize(self: ItemType) u8 {
        return switch (self) {
            .recovery_compass, .lodestone_compass, .music_disc_5, .swift_sneak_book => 1,
            else => 64,
        };
    }

    pub fn isTool(self: ItemType) bool {
        return switch (self) {
            .recovery_compass, .compass, .lodestone_compass => true,
            else => false,
        };
    }

    pub fn isCompass(self: ItemType) bool {
        return switch (self) {
            .recovery_compass, .compass, .lodestone_compass => true,
            else => false,
        };
    }

    pub fn hasGlint(self: ItemType) bool {
        return switch (self) {
            .recovery_compass, .lodestone_compass, .swift_sneak_book => true,
            else => false,
        };
    }

    pub fn name(self: ItemType) []const u8 {
        return switch (self) {
            .compass => "Compass",
            .lodestone_compass => "Lodestone Compass",
            .echo_shard => "Echo Shard",
            .recovery_compass => "Recovery Compass",
            .sculk => "Sculk",
            .sculk_catalyst => "Sculk Catalyst",
            .warden_spawn_egg => "Warden Spawn Egg",
            .disc_fragment_5 => "Disc Fragment 5",
            .music_disc_5 => "Music Disc 5",
            .swift_sneak_book => "Enchanted Book (Swift Sneak)",
        };
    }
};

pub const ItemStack = struct {
    item: ItemType,
    count: u8 = 1,
};

// ============================================================================
// Chest Loot & Ancient City Exclusivity
// ============================================================================

pub const LootSource = enum {
    ancient_city_chest,
    dungeon_chest,
    mineshaft_chest,
    nether_bridge_chest,
    stronghold_corridor_chest,
    bastion_treasure_chest,
    buried_treasure_chest,
    end_city_chest,
    village_chest,
    desert_pyramid_chest,
    jungle_temple_chest,
    shipwreck_chest,
    pillager_outpost_chest,
    woodland_mansion_chest,
};

/// Returns true if an item is permitted to appear in the specified loot source.
/// Echo Shard (`ItemType.echo_shard`) is exclusively found in Ancient City chest loot.
pub fn isItemAllowedInLootSource(source: LootSource, item: ItemType) bool {
    if (item == .echo_shard) {
        return source == .ancient_city_chest;
    }
    return true;
}

/// Returns true if the item is exclusive to Ancient City loot.
pub fn isAncientCityExclusive(item: ItemType) bool {
    return item == .echo_shard;
}

pub const AncientCityLootPool = struct {
    pub const ECHO_SHARD_MIN: u8 = 1;
    pub const ECHO_SHARD_MAX: u8 = 3;
    pub const ECHO_SHARD_CHANCE: f32 = 0.298; // ~29.8% in Minecraft Ancient City chests

    pub fn rollEchoShards(roll_chance: f32, count_roll: f32) ?ItemStack {
        if (roll_chance < ECHO_SHARD_CHANCE) {
            const range = ECHO_SHARD_MAX - ECHO_SHARD_MIN + 1;
            const count: u8 = ECHO_SHARD_MIN + @as(u8, @intFromFloat(std.math.clamp(count_roll, 0.0, 0.999) * @as(f32, @floatFromInt(range))));
            return .{
                .item = .echo_shard,
                .count = std.math.clamp(count, ECHO_SHARD_MIN, ECHO_SHARD_MAX),
            };
        }
        return null;
    }
};

// ============================================================================
// 3x3 Crafting Grid & Metallurgy Recipe
// ============================================================================

pub const RECIPE_GRID_SLOTS: usize = 9;
pub const RECIPE_GRID_SIZE: usize = 3;
pub const CENTER_SLOT: usize = 4;
pub const SURROUNDING_SLOTS = [_]usize{ 0, 1, 2, 3, 5, 6, 7, 8 };

pub const RECOVERY_COMPASS_COMPASS_REQUIRED: u32 = 1;
pub const RECOVERY_COMPASS_ECHO_SHARDS_REQUIRED: u32 = 8;
pub const RECOVERY_COMPASS_OUTPUT_COUNT: u32 = 1;

/// Validates whether a 3x3 pattern of item types forms the Recovery Compass recipe:
/// 1 Compass surrounded by 8 Echo Shards.
pub fn isRecoveryCompassRecipe(grid: [9]?ItemType) bool {
    const center = grid[CENTER_SLOT] orelse return false;
    if (center != .compass) return false;

    for (SURROUNDING_SLOTS) |idx| {
        const item = grid[idx] orelse return false;
        if (item != .echo_shard) return false;
    }
    return true;
}

/// Matches 3x3 item type array and returns output stack if valid.
pub fn matchCraftingRecipe(grid: [9]?ItemType) ?ItemStack {
    if (isRecoveryCompassRecipe(grid)) {
        return .{ .item = .recovery_compass, .count = 1 };
    }
    return null;
}

/// Bulk crafting calculation helper.
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

/// Stateful 3x3 crafting grid structure.
pub const CraftingGrid = struct {
    slots: [9]?ItemStack = [_]?ItemStack{null} ** 9,

    pub fn init() CraftingGrid {
        return .{};
    }

    pub fn setSlot(self: *CraftingGrid, index: usize, item: ItemType, count: u8) void {
        if (index < 9) {
            self.slots[index] = .{ .item = item, .count = count };
        }
    }

    pub fn clear(self: *CraftingGrid) void {
        self.slots = [_]?ItemStack{null} ** 9;
    }

    pub fn matchesRecipe(self: CraftingGrid) bool {
        const center = self.slots[CENTER_SLOT] orelse return false;
        if (center.item != .compass or center.count < 1) return false;

        for (SURROUNDING_SLOTS) |idx| {
            const slot = self.slots[idx] orelse return false;
            if (slot.item != .echo_shard or slot.count < 1) return false;
        }
        return true;
    }

    pub fn craft(self: *CraftingGrid) ?ItemStack {
        if (!self.matchesRecipe()) return null;

        // Consume 1 compass
        if (self.slots[CENTER_SLOT]) |*center| {
            if (center.count <= 1) {
                self.slots[CENTER_SLOT] = null;
            } else {
                center.count -= 1;
            }
        }

        // Consume 1 echo shard from each surrounding slot
        for (SURROUNDING_SLOTS) |idx| {
            if (self.slots[idx]) |*slot| {
                if (slot.count <= 1) {
                    self.slots[idx] = null;
                } else {
                    slot.count -= 1;
                }
            }
        }

        return .{ .item = .recovery_compass, .count = 1 };
    }
};

// ============================================================================
// Kinematics, Azimuth Math & Erratic Spinning
// ============================================================================

/// World-space target center coordinates (X+0.5, Z+0.5).
pub fn deathCenterX(pos: [3]i32) f32 {
    return @as(f32, @floatFromInt(pos[0])) + 0.5;
}

pub fn deathCenterZ(pos: [3]i32) f32 {
    return @as(f32, @floatFromInt(pos[2])) + 0.5;
}

/// Absolute target azimuth in radians from player position to target coordinates.
/// Coordinate convention (Minecraft standard):
///   North is -Z (azimuth = 0.0)
///   East  is +X (azimuth = +pi/2)
///   South is +Z (azimuth = +pi)
///   West  is -X (azimuth = -pi/2)
pub fn calculateTargetAzimuth(player_x: f32, player_z: f32, target_x: f32, target_z: f32) f32 {
    const dx = target_x - player_x;
    const dz = target_z - player_z;
    if (@abs(dx) < EPSILON and @abs(dz) < EPSILON) {
        return 0.0;
    }
    return std.math.atan2(dx, -dz);
}

/// Relative needle azimuth angle factoring in player heading yaw (0 = North, pi/2 = East).
/// Returns angle in [-pi, pi], where 0 is straight ahead, +pi/2 is 90 deg right, -pi/2 is 90 deg left.
pub fn calculateRelativeAzimuth(target_azimuth: f32, player_yaw: f32) f32 {
    return normalizeAngle(target_azimuth - player_yaw);
}

/// Converts camera yaw into player heading yaw.
pub fn cameraYawToHeading(cam_yaw: f32) f32 {
    return normalizeAngle(cam_yaw + HALF_PI);
}

/// Calculates high-frequency multi-harmonic chaotic needle spin when unlocked or interdimensional.
pub fn calculateErraticSpinAngle(world_time: f32, player_yaw: f32) f32 {
    const base_spin = world_time * 18.0;
    const wobble1 = @sin(world_time * 5.7) * 2.8;
    const wobble2 = @cos(world_time * 13.3) * 1.6;
    const wobble3 = @sin(world_time * 27.1) * 0.9;
    return normalizeAngle(base_spin + wobble1 + wobble2 + wobble3 - player_yaw);
}

// ============================================================================
// Physical Needle Kinematics (Spring-Damper Jewel-Bearing Model)
// ============================================================================

/// Models the physical rotational kinematics of a jeweled compass needle with restoring spring & damping.
pub const NeedleKinematics = struct {
    angle: f32 = 0.0,
    velocity: f32 = 0.0,
    spring_k: f32 = JEWEL_BEARING_SPRING_K,
    damping: f32 = JEWEL_BEARING_DAMPING,
    max_velocity: f32 = MAX_NEEDLE_VELOCITY,

    pub fn init() NeedleKinematics {
        return .{};
    }

    pub fn initWithParams(spring_k: f32, damping: f32) NeedleKinematics {
        return .{
            .spring_k = spring_k,
            .damping = damping,
        };
    }

    /// Advances the spring-damper simulation toward target_angle over dt seconds.
    pub fn update(self: *NeedleKinematics, target_angle: f32, dt: f32) void {
        const diff = shortestAngleDiff(self.angle, target_angle);
        const spring_torque = diff * self.spring_k;
        const damping_torque = -self.velocity * self.damping;
        const accel = spring_torque + damping_torque;

        self.velocity += accel * dt;
        self.velocity = std.math.clamp(self.velocity, -self.max_velocity, self.max_velocity);
        self.angle = normalizeAngle(self.angle + self.velocity * dt);
    }

    pub fn setAngleImmediate(self: *NeedleKinematics, target_angle: f32) void {
        self.angle = normalizeAngle(target_angle);
        self.velocity = 0.0;
    }

    pub fn reset(self: *NeedleKinematics) void {
        self.angle = 0.0;
        self.velocity = 0.0;
    }
};

// ============================================================================
// Needle Reading State
// ============================================================================

/// Output reading emitted by a Recovery Compass needle.
pub const NeedleReading = struct {
    /// Angle in radians relative to player heading in [-pi, pi].
    angle: f32,
    /// True when compass has a confirmed lock on the player's death coordinates in the same dimension.
    has_lock: bool,
    /// Alias for has_lock matching common compass status interfaces.
    is_locked: bool,
    /// True when needle is spinning erratically (never died or wrong dimension).
    is_spinning: bool,
    /// True when player has died, but in a dimension differing from their current dimension.
    is_interdimensional: bool,
    /// Intrinsic enchanted glint (always true for Recovery Compass in Minecraft).
    has_glint: bool = true,
    /// Recorded death coordinates if player has died.
    death_pos: ?[3]i32 = null,
    /// Recorded death dimension if player has died.
    death_dimension: ?Dimension = null,

    pub fn hasGlint(self: NeedleReading) bool {
        return self.has_glint;
    }
};

// ============================================================================
// Player Death Tracking System
// ============================================================================

pub const MAX_TRACKED_PLAYERS: usize = 128;

pub const PlayerDeath = struct {
    player_id: u64,
    pos: [3]i32,
    dimension: Dimension,
    valid: bool = true,
};

/// Tracks the most recent death coordinates and dimension for players in the session.
pub const PlayerDeathTracker = struct {
    deaths: [MAX_TRACKED_PLAYERS]?PlayerDeath = [_]?PlayerDeath{null} ** MAX_TRACKED_PLAYERS,
    count: usize = 0,

    pub fn init() PlayerDeathTracker {
        return .{};
    }

    /// Records or overwrites a player's most recent death event.
    /// Subsequent deaths overwrite previous coordinates with the newest position.
    pub fn onPlayerDeath(
        self: *PlayerDeathTracker,
        player_id: u64,
        death_pos: [3]i32,
        death_dim: Dimension,
    ) void {
        // Overwrite existing record if present
        for (&self.deaths) |*entry| {
            if (entry.*) |*d| {
                if (d.player_id == player_id) {
                    d.pos = death_pos;
                    d.dimension = death_dim;
                    d.valid = true;
                    return;
                }
            }
        }

        // Insert into first available slot
        for (&self.deaths) |*entry| {
            if (entry.* == null) {
                entry.* = PlayerDeath{
                    .player_id = player_id,
                    .pos = death_pos,
                    .dimension = death_dim,
                    .valid = true,
                };
                self.count += 1;
                return;
            }
        }

        // Fallback: overwrite slot 0
        self.deaths[0] = PlayerDeath{
            .player_id = player_id,
            .pos = death_pos,
            .dimension = death_dim,
            .valid = true,
        };
    }

    pub fn onPlayerDeathPos(
        self: *PlayerDeathTracker,
        player_id: u64,
        x: i32,
        y: i32,
        z: i32,
        death_dim: Dimension,
    ) void {
        self.onPlayerDeath(player_id, .{ x, y, z }, death_dim);
    }

    /// Returns true if a player has died at least once in the session.
    pub fn hasDied(self: PlayerDeathTracker, player_id: u64) bool {
        for (self.deaths) |entry| {
            if (entry) |d| {
                if (d.player_id == player_id and d.valid) return true;
            }
        }
        return false;
    }

    /// Retrieves the most recent death record for the specified player.
    pub fn getPlayerDeath(self: PlayerDeathTracker, player_id: u64) ?PlayerDeath {
        for (self.deaths) |entry| {
            if (entry) |d| {
                if (d.player_id == player_id and d.valid) return d;
            }
        }
        return null;
    }

    /// Alias for getPlayerDeath.
    pub fn getLastDeath(self: PlayerDeathTracker, player_id: u64) ?PlayerDeath {
        return self.getPlayerDeath(player_id);
    }

    /// Clears death tracking for a player (e.g. on full reset or hardcore respawn).
    pub fn clearPlayerDeath(self: *PlayerDeathTracker, player_id: u64) bool {
        for (&self.deaths) |*entry| {
            if (entry.*) |d| {
                if (d.player_id == player_id) {
                    entry.* = null;
                    if (self.count > 0) self.count -= 1;
                    return true;
                }
            }
        }
        return false;
    }

    pub fn reset(self: *PlayerDeathTracker) void {
        self.deaths = [_]?PlayerDeath{null} ** MAX_TRACKED_PLAYERS;
        self.count = 0;
    }

    /// Evaluates needle reading directly for a player.
    pub fn getCompassReading(
        self: PlayerDeathTracker,
        player_id: u64,
        player_x: f32,
        player_z: f32,
        current_dim: Dimension,
        player_yaw: f32,
        world_time: f32,
    ) NeedleReading {
        const death_opt = self.getPlayerDeath(player_id);
        if (death_opt == null) {
            // Never died in session
            return .{
                .angle = calculateErraticSpinAngle(world_time, player_yaw),
                .has_lock = false,
                .is_locked = false,
                .is_spinning = true,
                .is_interdimensional = false,
                .has_glint = true,
                .death_pos = null,
                .death_dimension = null,
            };
        }

        const death = death_opt.?;
        if (death.dimension != current_dim) {
            // Interdimensional mismatch
            return .{
                .angle = calculateErraticSpinAngle(world_time, player_yaw),
                .has_lock = false,
                .is_locked = false,
                .is_spinning = true,
                .is_interdimensional = true,
                .has_glint = true,
                .death_pos = death.pos,
                .death_dimension = death.dimension,
            };
        }

        // Same dimension: Lock on target
        const target_x = deathCenterX(death.pos);
        const target_z = deathCenterZ(death.pos);
        const azimuth = calculateTargetAzimuth(player_x, player_z, target_x, target_z);
        const rel_angle = calculateRelativeAzimuth(azimuth, player_yaw);

        return .{
            .angle = rel_angle,
            .has_lock = true,
            .is_locked = true,
            .is_spinning = false,
            .is_interdimensional = false,
            .has_glint = true,
            .death_pos = death.pos,
            .death_dimension = death.dimension,
        };
    }
};

// ============================================================================
// Recovery Compass Object
// ============================================================================

/// Represents an individual Recovery Compass item instance.
pub const RecoveryCompass = struct {
    kinematics: NeedleKinematics = .{},
    current_needle_angle: f32 = 0.0,
    has_glint: bool = true,

    pub fn init() RecoveryCompass {
        return .{
            .kinematics = NeedleKinematics.init(),
            .current_needle_angle = 0.0,
            .has_glint = true,
        };
    }

    /// Intrinsic enchanted glint active at all times.
    pub fn hasGlint(self: RecoveryCompass) bool {
        _ = self;
        return true;
    }

    /// Calculates instantaneous reading without advancing physical kinematics.
    pub fn calculateReading(
        self: RecoveryCompass,
        tracker: *const PlayerDeathTracker,
        player_id: u64,
        player_x: f32,
        player_z: f32,
        current_dim: Dimension,
        player_yaw: f32,
        world_time: f32,
    ) NeedleReading {
        _ = self;
        return tracker.getCompassReading(player_id, player_x, player_z, current_dim, player_yaw, world_time);
    }

    pub fn calculateReadingPos(
        self: RecoveryCompass,
        tracker: *const PlayerDeathTracker,
        player_id: u64,
        player_pos: [3]f32,
        current_dim: Dimension,
        player_yaw: f32,
        world_time: f32,
    ) NeedleReading {
        return self.calculateReading(tracker, player_id, player_pos[0], player_pos[2], current_dim, player_yaw, world_time);
    }

    /// Advances the spring-damper physical simulation over delta time `dt`.
    pub fn update(
        self: *RecoveryCompass,
        tracker: *const PlayerDeathTracker,
        player_id: u64,
        player_x: f32,
        player_z: f32,
        current_dim: Dimension,
        player_yaw: f32,
        world_time: f32,
        dt: f32,
    ) NeedleReading {
        var reading = self.calculateReading(tracker, player_id, player_x, player_z, current_dim, player_yaw, world_time);
        if (reading.has_lock) {
            self.kinematics.update(reading.angle, dt);
            self.current_needle_angle = self.kinematics.angle;
            reading.angle = self.current_needle_angle;
        } else {
            self.kinematics.setAngleImmediate(reading.angle);
            self.current_needle_angle = reading.angle;
        }
        return reading;
    }

    pub fn updatePos(
        self: *RecoveryCompass,
        tracker: *const PlayerDeathTracker,
        player_id: u64,
        player_pos: [3]f32,
        current_dim: Dimension,
        player_yaw: f32,
        world_time: f32,
        dt: f32,
    ) NeedleReading {
        return self.update(tracker, player_id, player_pos[0], player_pos[2], current_dim, player_yaw, world_time, dt);
    }
};

// ============================================================================
// Unit Tests (36 Comprehensive Tests)
// ============================================================================

test "1. ItemType properties: stack sizes for recovery_compass, echo_shard, and compass" {
    try std.testing.expectEqual(@as(u8, 1), ItemType.recovery_compass.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.echo_shard.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.compass.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.lodestone_compass.maxStackSize());
}

test "2. ItemType properties: tool and compass classifications" {
    try std.testing.expect(ItemType.recovery_compass.isTool());
    try std.testing.expect(ItemType.recovery_compass.isCompass());
    try std.testing.expect(ItemType.compass.isTool());
    try std.testing.expect(ItemType.compass.isCompass());
    try std.testing.expect(!ItemType.echo_shard.isTool());
    try std.testing.expect(!ItemType.echo_shard.isCompass());
}

test "3. ItemType properties: intrinsic enchanted glint" {
    try std.testing.expect(ItemType.recovery_compass.hasGlint());
    try std.testing.expect(ItemType.lodestone_compass.hasGlint());
    try std.testing.expect(!ItemType.compass.hasGlint());
    try std.testing.expect(!ItemType.echo_shard.hasGlint());
}

test "4. ItemType properties: canonical naming" {
    try std.testing.expectEqualStrings("Echo Shard", ItemType.echo_shard.name());
    try std.testing.expectEqualStrings("Recovery Compass", ItemType.recovery_compass.name());
    try std.testing.expectEqualStrings("Compass", ItemType.compass.name());
}

test "5. Loot exclusivity: Echo Shard allowed exclusively in Ancient City chest loot" {
    try std.testing.expect(isItemAllowedInLootSource(.ancient_city_chest, .echo_shard));
    try std.testing.expect(isAncientCityExclusive(.echo_shard));
    try std.testing.expect(!isAncientCityExclusive(.compass));
}

test "6. Loot exclusivity: Echo Shard rejected from all other chest loot structures" {
    const non_ancient_sources = [_]LootSource{
        .dungeon_chest,
        .mineshaft_chest,
        .nether_bridge_chest,
        .stronghold_corridor_chest,
        .bastion_treasure_chest,
        .buried_treasure_chest,
        .end_city_chest,
        .village_chest,
        .desert_pyramid_chest,
        .jungle_temple_chest,
        .shipwreck_chest,
        .pillager_outpost_chest,
        .woodland_mansion_chest,
    };

    for (non_ancient_sources) |source| {
        try std.testing.expect(!isItemAllowedInLootSource(source, .echo_shard));
    }
}

test "7. Ancient City chest loot pool: rolls 1-3 Echo Shards when chance succeeds" {
    const drop = AncientCityLootPool.rollEchoShards(0.10, 0.5);
    try std.testing.expect(drop != null);
    try std.testing.expectEqual(ItemType.echo_shard, drop.?.item);
    try std.testing.expect(drop.?.count >= 1 and drop.?.count <= 3);

    // Roll with chance above threshold fails
    const no_drop = AncientCityLootPool.rollEchoShards(0.90, 0.5);
    try std.testing.expect(no_drop == null);
}

test "8. Crafting 3x3: valid recipe of 1 Compass surrounded by 8 Echo Shards yields 1 Recovery Compass" {
    const recipe_grid = [9]?ItemType{
        .echo_shard, .echo_shard, .echo_shard,
        .echo_shard, .compass,    .echo_shard,
        .echo_shard, .echo_shard, .echo_shard,
    };

    try std.testing.expect(isRecoveryCompassRecipe(recipe_grid));
    const result = matchCraftingRecipe(recipe_grid);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(ItemType.recovery_compass, result.?.item);
    try std.testing.expectEqual(@as(u8, 1), result.?.count);
}

test "9. Crafting 3x3: compass misplaced in corner slot 0 fails recipe match" {
    const recipe_grid = [9]?ItemType{
        .compass,    .echo_shard, .echo_shard,
        .echo_shard, .echo_shard, .echo_shard,
        .echo_shard, .echo_shard, .echo_shard,
    };

    try std.testing.expect(!isRecoveryCompassRecipe(recipe_grid));
    try std.testing.expect(matchCraftingRecipe(recipe_grid) == null);
}

test "10. Crafting 3x3: fewer than 8 Echo Shards (empty slot) fails recipe match" {
    var recipe_grid = [9]?ItemType{
        .echo_shard, .echo_shard, .echo_shard,
        .echo_shard, .compass,    .echo_shard,
        .echo_shard, .echo_shard, .echo_shard,
    };
    recipe_grid[0] = null; // 7 echo shards

    try std.testing.expect(!isRecoveryCompassRecipe(recipe_grid));
    try std.testing.expect(matchCraftingRecipe(recipe_grid) == null);
}

test "11. Crafting 3x3: empty center slot fails recipe match" {
    const recipe_grid = [9]?ItemType{
        .echo_shard, .echo_shard, .echo_shard,
        .echo_shard, null,        .echo_shard,
        .echo_shard, .echo_shard, .echo_shard,
    };

    try std.testing.expect(!isRecoveryCompassRecipe(recipe_grid));
    try std.testing.expect(matchCraftingRecipe(recipe_grid) == null);
}

test "12. Crafting 3x3: foreign item in grid fails recipe match" {
    var recipe_grid = [9]?ItemType{
        .echo_shard, .echo_shard, .echo_shard,
        .echo_shard, .compass,    .echo_shard,
        .echo_shard, .echo_shard, .echo_shard,
    };
    recipe_grid[1] = .sculk;

    try std.testing.expect(!isRecoveryCompassRecipe(recipe_grid));
    try std.testing.expect(matchCraftingRecipe(recipe_grid) == null);
}

test "13. CraftingGrid.craft: consumes 1 compass and 8 echo shards from single-item slots" {
    var grid = CraftingGrid.init();
    grid.setSlot(4, .compass, 1);
    for (SURROUNDING_SLOTS) |idx| {
        grid.setSlot(idx, .echo_shard, 1);
    }

    try std.testing.expect(grid.matchesRecipe());
    const crafted = grid.craft();
    try std.testing.expect(crafted != null);
    try std.testing.expectEqual(ItemType.recovery_compass, crafted.?.item);
    try std.testing.expectEqual(@as(u8, 1), crafted.?.count);

    // All slots should now be empty
    for (0..9) |i| {
        try std.testing.expect(grid.slots[i] == null);
    }
}

test "14. CraftingGrid.craft: decrements counts correctly when slots contain larger stacks" {
    var grid = CraftingGrid.init();
    grid.setSlot(4, .compass, 5);
    for (SURROUNDING_SLOTS) |idx| {
        grid.setSlot(idx, .echo_shard, 64);
    }

    const crafted = grid.craft();
    try std.testing.expect(crafted != null);
    try std.testing.expectEqual(ItemType.recovery_compass, crafted.?.item);

    try std.testing.expectEqual(@as(u8, 4), grid.slots[4].?.count);
    for (SURROUNDING_SLOTS) |idx| {
        try std.testing.expectEqual(@as(u8, 63), grid.slots[idx].?.count);
    }
}

test "15. craftRecoveryCompass bulk helper yields correct maximum counts" {
    try std.testing.expectEqual(@as(?u32, 1), craftRecoveryCompass(1, 8));
    try std.testing.expectEqual(@as(?u32, 2), craftRecoveryCompass(2, 16));
    try std.testing.expectEqual(@as(?u32, 1), craftRecoveryCompass(1, 64)); // bottlenecked by compass
    try std.testing.expectEqual(@as(?u32, 2), craftRecoveryCompass(10, 19)); // 19 / 8 = 2
    try std.testing.expectEqual(@as(?u32, null), craftRecoveryCompass(1, 7)); // insufficient shards
    try std.testing.expectEqual(@as(?u32, null), craftRecoveryCompass(0, 16)); // no compass
}

test "16. PlayerDeathTracker initialization starts empty with zero deaths" {
    const tracker = PlayerDeathTracker.init();
    try std.testing.expectEqual(@as(usize, 0), tracker.count);
    try std.testing.expect(!tracker.hasDied(1));
    try std.testing.expect(tracker.getPlayerDeath(1) == null);
}

test "17. PlayerDeathTracker.onPlayerDeath records death coordinates and dimension" {
    var tracker = PlayerDeathTracker.init();
    const death_coords = [3]i32{ 150, 42, -320 };
    tracker.onPlayerDeath(42, death_coords, .overworld);

    try std.testing.expect(tracker.hasDied(42));
    const death = tracker.getPlayerDeath(42);
    try std.testing.expect(death != null);
    try std.testing.expectEqual(death_coords, death.?.pos);
    try std.testing.expectEqual(Dimension.overworld, death.?.dimension);
}

test "18. Never-died player state: needle unlocks and spins erratically" {
    const tracker = PlayerDeathTracker.init();
    const compass = RecoveryCompass.init();

    const reading = compass.calculateReading(&tracker, 101, 0.0, 0.0, .overworld, 0.0, 1.5);
    try std.testing.expect(!reading.has_lock);
    try std.testing.expect(!reading.is_locked);
    try std.testing.expect(reading.is_spinning);
    try std.testing.expect(!reading.is_interdimensional);
    try std.testing.expect(reading.has_glint);
    try std.testing.expect(reading.death_pos == null);
}

test "19. Never-died erratic spinning: needle angle sweeps across different angles over time" {
    const tracker = PlayerDeathTracker.init();
    const compass = RecoveryCompass.init();

    const r0 = compass.calculateReading(&tracker, 102, 0.0, 0.0, .overworld, 0.0, 0.0);
    const r1 = compass.calculateReading(&tracker, 102, 0.0, 0.0, .overworld, 0.0, 0.4);
    const r2 = compass.calculateReading(&tracker, 102, 0.0, 0.0, .overworld, 0.0, 0.9);

    try std.testing.expect(r0.angle != r1.angle);
    try std.testing.expect(r1.angle != r2.angle);
    try std.testing.expect(r0.is_spinning and r1.is_spinning and r2.is_spinning);
}

test "20. Interdimensional detection: Nether death with player in Overworld spins erratically" {
    var tracker = PlayerDeathTracker.init();
    tracker.onPlayerDeath(1, .{ 100, 60, 100 }, .nether);

    const compass = RecoveryCompass.init();
    const reading = compass.calculateReading(&tracker, 1, 0.0, 0.0, .overworld, 0.0, 2.0);

    try std.testing.expect(!reading.has_lock);
    try std.testing.expect(!reading.is_locked);
    try std.testing.expect(reading.is_spinning);
    try std.testing.expect(reading.is_interdimensional);
    try std.testing.expect(reading.has_glint);
    try std.testing.expectEqual(Dimension.nether, reading.death_dimension.?);
}

test "21. Interdimensional detection: Overworld death with player in Nether spins erratically" {
    var tracker = PlayerDeathTracker.init();
    tracker.onPlayerDeath(2, .{ 200, 64, -150 }, .overworld);

    const compass = RecoveryCompass.init();
    const reading = compass.calculateReading(&tracker, 2, 50.0, 50.0, .nether, 0.0, 3.5);

    try std.testing.expect(!reading.has_lock);
    try std.testing.expect(reading.is_spinning);
    try std.testing.expect(reading.is_interdimensional);
    try std.testing.expectEqual(Dimension.overworld, reading.death_dimension.?);
}

test "22. Interdimensional detection: The End death with player in Overworld spins erratically" {
    var tracker = PlayerDeathTracker.init();
    tracker.onPlayerDeath(3, .{ 0, 70, 0 }, .the_end);

    const compass = RecoveryCompass.init();
    const reading = compass.calculateReading(&tracker, 3, 10.0, 10.0, .overworld, 0.0, 1.2);

    try std.testing.expect(!reading.has_lock);
    try std.testing.expect(reading.is_spinning);
    try std.testing.expect(reading.is_interdimensional);
}

test "23. Same-dimension lock: Overworld death with player in Overworld locks onto target" {
    var tracker = PlayerDeathTracker.init();
    tracker.onPlayerDeath(5, .{ 0, 64, -50 }, .overworld); // North of origin

    const compass = RecoveryCompass.init();
    // Player at origin (0, 0), facing North (yaw = 0.0)
    const reading = compass.calculateReading(&tracker, 5, 0.0, 0.0, .overworld, 0.0, 1.0);

    try std.testing.expect(reading.has_lock);
    try std.testing.expect(reading.is_locked);
    try std.testing.expect(!reading.is_spinning);
    try std.testing.expect(!reading.is_interdimensional);
    try std.testing.expect(reading.has_glint);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), reading.angle, 0.02);
}

test "24. Same-dimension lock: Nether death with player in Nether locks onto coordinates" {
    var tracker = PlayerDeathTracker.init();
    tracker.onPlayerDeath(6, .{ 50, 40, 0 }, .nether); // East of origin

    const compass = RecoveryCompass.init();
    // Player at (0, 0), facing North (yaw = 0.0). Target is East -> angle should be +pi/2
    const reading = compass.calculateReading(&tracker, 6, 0.0, 0.0, .nether, 0.0, 0.0);

    try std.testing.expect(reading.has_lock);
    try std.testing.expect(!reading.is_spinning);
    try std.testing.expect(!reading.is_interdimensional);
    try std.testing.expectApproxEqAbs(HALF_PI, reading.angle, 0.02);
}

test "25. Same-dimension lock: The End death with player in The End locks onto coordinates" {
    var tracker = PlayerDeathTracker.init();
    tracker.onPlayerDeath(7, .{ 0, 60, 100 }, .the_end); // South of origin

    const compass = RecoveryCompass.init();
    // Player at (0, 0), facing North (yaw = 0.0). Target is South -> angle should be pi
    const reading = compass.calculateReading(&tracker, 7, 0.0, 0.0, .the_end, 0.0, 0.0);

    try std.testing.expect(reading.has_lock);
    try std.testing.expect(!reading.is_spinning);
    try std.testing.expectApproxEqAbs(PI, @abs(reading.angle), 0.02);
}

test "26. Cardinal target azimuth calculations: North, East, South, West" {
    // North is -Z: azimuth 0.0
    const az_n = calculateTargetAzimuth(0.0, 0.0, 0.0, -10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), az_n, 0.001);

    // East is +X: azimuth +pi/2
    const az_e = calculateTargetAzimuth(0.0, 0.0, 10.0, 0.0);
    try std.testing.expectApproxEqAbs(HALF_PI, az_e, 0.001);

    // South is +Z: azimuth pi
    const az_s = calculateTargetAzimuth(0.0, 0.0, 0.0, 10.0);
    try std.testing.expectApproxEqAbs(PI, @abs(az_s), 0.001);

    // West is -X: azimuth -pi/2
    const az_w = calculateTargetAzimuth(0.0, 0.0, -10.0, 0.0);
    try std.testing.expectApproxEqAbs(-HALF_PI, az_w, 0.001);
}

test "27. Ordinal target azimuth calculations: NE, SE, SW, NW" {
    const az_ne = calculateTargetAzimuth(0.0, 0.0, 10.0, -10.0);
    try std.testing.expectApproxEqAbs(PI / 4.0, az_ne, 0.001);

    const az_se = calculateTargetAzimuth(0.0, 0.0, 10.0, 10.0);
    try std.testing.expectApproxEqAbs(3.0 * PI / 4.0, az_se, 0.001);

    const az_sw = calculateTargetAzimuth(0.0, 0.0, -10.0, 10.0);
    try std.testing.expectApproxEqAbs(-3.0 * PI / 4.0, az_sw, 0.001);

    const az_nw = calculateTargetAzimuth(0.0, 0.0, -10.0, -10.0);
    try std.testing.expectApproxEqAbs(-PI / 4.0, az_nw, 0.001);
}

test "28. Relative needle angle calculation across different player headings" {
    // Target is North (azimuth = 0.0)
    const target_az = 0.0;

    // Facing North (yaw = 0.0) -> pointing straight ahead (0.0)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), calculateRelativeAzimuth(target_az, 0.0), 0.001);

    // Facing East (yaw = +pi/2) -> target is 90 deg left (-pi/2)
    try std.testing.expectApproxEqAbs(-HALF_PI, calculateRelativeAzimuth(target_az, HALF_PI), 0.001);

    // Facing South (yaw = pi) -> target is directly behind (pi or -pi)
    try std.testing.expectApproxEqAbs(PI, @abs(calculateRelativeAzimuth(target_az, PI)), 0.001);

    // Facing West (yaw = -pi/2) -> target is 90 deg right (+pi/2)
    try std.testing.expectApproxEqAbs(HALF_PI, calculateRelativeAzimuth(target_az, -HALF_PI), 0.001);
}

test "29. Zero displacement handles standing on death spot without NaN or crash" {
    const az_zero = calculateTargetAzimuth(50.0, 50.0, 50.0, 50.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), az_zero, 0.001);
}

test "30. Respawn and death overwrite: subsequent death updates coordinates to newest position" {
    var tracker = PlayerDeathTracker.init();

    // 1st death: at (100, 64, 100)
    tracker.onPlayerDeath(10, .{ 100, 64, 100 }, .overworld);
    try std.testing.expectEqual([3]i32{ 100, 64, 100 }, tracker.getPlayerDeath(10).?.pos);

    // 2nd death: at (-300, 32, 500)
    tracker.onPlayerDeath(10, .{ -300, 32, 500 }, .overworld);
    try std.testing.expectEqual([3]i32{ -300, 32, 500 }, tracker.getPlayerDeath(10).?.pos);

    // Compass tracking reflects the NEW location
    const compass = RecoveryCompass.init();
    const reading = compass.calculateReading(&tracker, 10, -300.0, 450.0, .overworld, 0.0, 0.0);
    // Target is South (+Z from 450 to 500.5)
    try std.testing.expectApproxEqAbs(PI, @abs(reading.angle), 0.05);
}

test "31. Respawn and dimension overwrite: subsequent death in different dimension updates dimension" {
    var tracker = PlayerDeathTracker.init();

    // 1st death in Overworld
    tracker.onPlayerDeath(11, .{ 10, 64, 10 }, .overworld);
    try std.testing.expectEqual(Dimension.overworld, tracker.getPlayerDeath(11).?.dimension);

    // 2nd death in Nether
    tracker.onPlayerDeath(11, .{ 20, 50, -30 }, .nether);
    try std.testing.expectEqual(Dimension.nether, tracker.getPlayerDeath(11).?.dimension);

    const compass = RecoveryCompass.init();
    // When player respawns in Overworld, compass should now be interdimensional!
    const reading_ow = compass.calculateReading(&tracker, 11, 0.0, 0.0, .overworld, 0.0, 0.0);
    try std.testing.expect(reading_ow.is_interdimensional);

    // When player enters Nether, compass locks onto Nether death pos
    const reading_nether = compass.calculateReading(&tracker, 11, 20.0, 0.0, .nether, 0.0, 0.0);
    try std.testing.expect(reading_nether.has_lock);
    try std.testing.expect(!reading_nether.is_interdimensional);
}

test "32. clearPlayerDeath resets player to never-died spinning state" {
    var tracker = PlayerDeathTracker.init();
    tracker.onPlayerDeath(12, .{ 50, 64, 50 }, .overworld);
    try std.testing.expect(tracker.hasDied(12));

    const cleared = tracker.clearPlayerDeath(12);
    try std.testing.expect(cleared);
    try std.testing.expect(!tracker.hasDied(12));

    const compass = RecoveryCompass.init();
    const reading = compass.calculateReading(&tracker, 12, 0.0, 0.0, .overworld, 0.0, 1.0);
    try std.testing.expect(!reading.has_lock);
    try std.testing.expect(reading.is_spinning);
    try std.testing.expect(!reading.is_interdimensional);
}

test "33. Multi-player tracking: independent tracking for distinct player IDs" {
    var tracker = PlayerDeathTracker.init();
    tracker.onPlayerDeath(1001, .{ 10, 64, 10 }, .overworld);
    tracker.onPlayerDeath(1002, .{ -50, 40, 200 }, .nether);

    const d1 = tracker.getPlayerDeath(1001).?;
    const d2 = tracker.getPlayerDeath(1002).?;

    try std.testing.expectEqual([3]i32{ 10, 64, 10 }, d1.pos);
    try std.testing.expectEqual(Dimension.overworld, d1.dimension);

    try std.testing.expectEqual([3]i32{ -50, 40, 200 }, d2.pos);
    try std.testing.expectEqual(Dimension.nether, d2.dimension);
}

test "34. Spring-damper kinematics: damped spring converges smoothly to target angle" {
    var kinematics = NeedleKinematics.init();
    kinematics.setAngleImmediate(0.0);

    const target_angle: f32 = 1.0;
    const dt: f32 = 0.05;

    // Simulate 30 steps (1.5 seconds)
    var step: usize = 0;
    while (step < 30) : (step += 1) {
        kinematics.update(target_angle, dt);
    }

    try std.testing.expectApproxEqAbs(target_angle, kinematics.angle, 0.02);
}

test "35. Spring-damper kinematics: boundary wrap-around across +/- pi takes shortest arc" {
    var kinematics = NeedleKinematics.init();
    kinematics.setAngleImmediate(3.0); // Near +pi (~3.14)

    // Target is -3.0 (near -pi). Shortest difference is +0.283 radians across boundary, NOT -6.0 radians!
    const target_angle: f32 = -3.0;
    const diff = shortestAngleDiff(kinematics.angle, target_angle);
    try std.testing.expect(diff > 0.0); // Positive indicates crossing the boundary forward
    try std.testing.expect(diff < 0.5);

    // Update for several ticks; angle should cross into negative without taking full circle
    var step: usize = 0;
    while (step < 25) : (step += 1) {
        kinematics.update(target_angle, 0.05);
    }

    try std.testing.expectApproxEqAbs(target_angle, kinematics.angle, 0.05);
}

test "36. RecoveryCompass instance hasGlint and update smoothing" {
    var compass = RecoveryCompass.init();
    try std.testing.expect(compass.hasGlint());

    var tracker = PlayerDeathTracker.init();
    tracker.onPlayerDeath(99, .{ 0, 64, -100 }, .overworld); // North

    // Player at origin, facing East (yaw = pi/2). Target North is -pi/2 relative
    const dt: f32 = 0.05;
    var step: usize = 0;
    while (step < 30) : (step += 1) {
        _ = compass.update(&tracker, 99, 0.0, 0.0, .overworld, HALF_PI, 0.0, dt);
    }

    try std.testing.expectApproxEqAbs(-HALF_PI, compass.current_needle_angle, 0.05);
}
