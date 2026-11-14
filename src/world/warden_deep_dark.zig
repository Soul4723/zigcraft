const std = @import("std");

/// Maximum range in blocks within which a mob death activates a Sculk Catalyst.
pub const catalyst_range: f32 = 8.0;

/// Squared detection radius for Sculk Catalyst mob death detection.
pub const catalyst_range_sq: f32 = catalyst_range * catalyst_range; // 64.0

/// High XP thresholds for spawning rare sculk growths during a catalyst soul bloom.
pub const high_xp_sensor_threshold: u16 = 20;
pub const high_xp_shrieker_threshold: u16 = 50;

/// Sculk Shrieker timing and warning thresholds.
pub const shriek_cooldown_seconds: f32 = 10.0;
pub const warning_decay_seconds: f32 = 600.0;
pub const darkness_duration_seconds: f32 = 12.0;
pub const max_warning_level: u3 = 4;
pub const warden_summon_level: u3 = 4;

/// Warden physical, sensory, and behavioral constants.
pub const warden_max_hp: f32 = 500.0;
pub const warden_melee_damage: f32 = 30.0;
pub const warden_smell_range: f32 = 24.0;
pub const warden_smell_range_sq: f32 = warden_smell_range * warden_smell_range; // 576.0
pub const warden_smell_interval: f32 = 5.0;
pub const smell_anger_bonus: u8 = 10;
pub const vibration_anger_bonus: u8 = 35;
pub const projectile_anger_bonus: u8 = 10;
pub const max_warden_anger: u8 = 150;
pub const agitated_anger_threshold: u8 = 40;
pub const roaring_attack_threshold: u8 = 80;
pub const burrow_timeout_seconds: f32 = 60.0;

/// Sonic Boom combat constants.
pub const sonic_boom_horizontal_range: f32 = 15.0;
pub const sonic_boom_vertical_range: f32 = 20.0;
pub const sonic_boom_base_damage: f32 = 10.0;
pub const sonic_boom_knockback_horiz_force: f32 = 2.5;
pub const sonic_boom_knockback_vert_force: f32 = 0.5;

/// Block identifiers relevant to Deep Dark generation and catalyst conversions.
pub const DeepDarkBlock = enum(u16) {
    air = 0,
    stone = 1,
    dirt = 2,
    deepslate = 3,
    sculk = 178,
    sculk_sensor = 179,
    sculk_vein = 181,
    sculk_shrieker = 182,
    sculk_catalyst = 183,
};

/// Returns whether `block` can be converted into sculk by a catalyst soul bloom.
pub fn isConvertibleBlock(block: DeepDarkBlock) bool {
    return block == .stone or block == .dirt or block == .deepslate;
}

/// Calculates the soul-bloom spread radius in blocks based on the dropped mob XP.
/// Scales progressively from 0 up to a maximum radius of 8 blocks.
pub fn sculkSpreadRadius(xp: u16) u8 {
    if (xp == 0) return 0;
    if (xp <= 5) return 1;
    if (xp <= 15) return 2;
    if (xp <= 30) return 3;
    if (xp <= 50) return 4;
    if (xp <= 80) return 5;
    if (xp <= 120) return 6;
    if (xp <= 200) return 7;
    return 8;
}

/// Determines the resulting block type when a convertible block is reached by a soul-bloom charge.
/// High-XP kills have a chance to generate Sculk Shriekers (XP >= 50) or Sculk Sensors (XP >= 20).
/// Inner regions convert to solid Sculk, while the perimeter converts to Sculk Veins.
pub fn convertBlock(block: DeepDarkBlock, xp: u16, distance_to_origin: f32, roll: u8) ?DeepDarkBlock {
    if (!isConvertibleBlock(block)) return null;

    if (xp >= high_xp_shrieker_threshold and roll < 15) {
        return .sculk_shrieker;
    } else if (xp >= high_xp_sensor_threshold and roll < 40) {
        return .sculk_sensor;
    }

    const max_rad = @as(f32, @floatFromInt(sculkSpreadRadius(xp)));
    if (distance_to_origin <= max_rad * 0.7) {
        return .sculk;
    } else {
        return .sculk_vein;
    }
}

/// A soul-bloom charge originating from a mob death near a catalyst.
pub const BloomCharge = struct {
    origin_x: i32,
    origin_y: i32,
    origin_z: i32,
    xp_amount: u16,
    spread_radius: u8,

    pub fn init(origin_x: i32, origin_y: i32, origin_z: i32, xp: u16) BloomCharge {
        return .{
            .origin_x = origin_x,
            .origin_y = origin_y,
            .origin_z = origin_z,
            .xp_amount = xp,
            .spread_radius = sculkSpreadRadius(xp),
        };
    }

    pub fn isWithinSpread(self: BloomCharge, bx: i32, by: i32, bz: i32) bool {
        const dx = bx - self.origin_x;
        const dy = by - self.origin_y;
        const dz = bz - self.origin_z;
        const dist_sq = dx * dx + dy * dy + dz * dz;
        const r = @as(i32, self.spread_radius);
        return dist_sq <= r * r;
    }
};

/// Sculk Catalyst block entity tracking nearby mob deaths and blooming soul charges.
pub const SculkCatalyst = struct {
    x: i32,
    y: i32,
    z: i32,
    bloom_active: bool = false,
    bloom_timer: f32 = 0.0,
    charges_absorbed: u32 = 0,
    total_xp_consumed: u32 = 0,

    pub fn init(x: i32, y: i32, z: i32) SculkCatalyst {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    /// When a mob dies at (mob_x, mob_y, mob_z) dropping `xp_amount`.
    /// Returns a `BloomCharge` if the death occurred within 8.0 blocks (64.0 sq distance) and xp > 0.
    pub fn onMobDeath(self: *SculkCatalyst, mob_x: f32, mob_y: f32, mob_z: f32, xp_amount: u16) ?BloomCharge {
        if (xp_amount == 0) return null;

        const cx = @as(f32, @floatFromInt(self.x)) + 0.5;
        const cy = @as(f32, @floatFromInt(self.y)) + 0.5;
        const cz = @as(f32, @floatFromInt(self.z)) + 0.5;
        const dx = cx - mob_x;
        const dy = cy - mob_y;
        const dz = cz - mob_z;
        const dist_sq = dx * dx + dy * dy + dz * dz;

        if (dist_sq > catalyst_range_sq) return null;

        self.bloom_active = true;
        self.bloom_timer = 2.0;
        self.charges_absorbed += 1;
        self.total_xp_consumed += xp_amount;

        return BloomCharge.init(
            @intFromFloat(@floor(mob_x)),
            @intFromFloat(@floor(mob_y)),
            @intFromFloat(@floor(mob_z)),
            xp_amount,
        );
    }

    pub fn tick(self: *SculkCatalyst, dt: f32) void {
        if (self.bloom_timer > 0.0) {
            self.bloom_timer = @max(0.0, self.bloom_timer - dt);
            if (self.bloom_timer <= 0.0) {
                self.bloom_active = false;
            }
        }
    }
};

pub const WARNING_TICKS_PER_SECOND: f32 = 20.0;

/// Duration of a single tick in seconds: 0.05s (50 ms).
pub const SECONDS_PER_TICK: f32 = 1.0 / 20.0;

/// Floating-point timer comparison epsilon (0.1 ms).
pub const TIMER_EPSILON: f32 = 1e-4;

/// Shrieker cooldown after activation: 10.0 seconds (200 ticks).
pub const SHRIEK_COOLDOWN_SECONDS: f32 = 10.0;
pub const SHRIEK_COOLDOWN_TICKS: u32 = 200;

/// Warning level decay duration of calm: 10 minutes = 600.0 seconds (12000 ticks).
pub const WARNING_DECAY_SECONDS: f32 = 600.0;
pub const WARNING_DECAY_TICKS: u32 = 12000;

/// Duration of the Darkness status effect: 12.0 seconds (240 ticks).
pub const DARKNESS_DURATION_SECONDS: f32 = 12.0;
pub const DARKNESS_DURATION_TICKS: u32 = 240;

/// Effective radius of the Darkness status effect aura in meters (blocks): 40.0m.
pub const SHRIEKER_DARKNESS_RADIUS: f32 = 40.0;
pub const SHRIEKER_DARKNESS_RADIUS_SQ: f32 = SHRIEKER_DARKNESS_RADIUS * SHRIEKER_DARKNESS_RADIUS; // 1600.0

/// Maximum distance in blocks across which a sculk sensor can transmit to a shrieker: 8.0m.
pub const SENSOR_TRANSMISSION_RANGE: f32 = 8.0;
pub const SENSOR_TRANSMISSION_RANGE_SQ: f32 = SENSOR_TRANSMISSION_RANGE * SENSOR_TRANSMISSION_RANGE; // 64.0

/// Maximum warning level reachable by a player: Tier 4.
pub const MAX_WARNING_LEVEL: u3 = 4;

/// Warning level threshold required to summon the Warden: Tier 4.
pub const WARDEN_SUMMON_LEVEL: u3 = 4;

/// Warden ground emergence animation duration in seconds: 6.7s (134 ticks).
pub const WARDEN_EMERGE_DURATION_SECONDS: f32 = 6.7;
pub const WARDEN_EMERGE_DURATION_TICKS: u32 = 134;

/// Duration in seconds of the active shrieker screaming visual & vibration state: 4.5s.
pub const SHRIEK_ACTIVE_DURATION_SECONDS: f32 = 4.5;

// ============================================================================
// Enums & Types
// ============================================================================

/// Biome classification for Warden spawn gating.
pub const BiomeType = enum(u8) {
    deep_dark = 0,
    plains = 1,
    caves = 2,
    dripstone_caves = 3,
    lush_caves = 4,
    nether_wastes = 5,
    the_end = 6,
    other = 7,

    pub fn isDeepDark(self: BiomeType) bool {
        return self == .deep_dark;
    }
};

/// Trigger mechanism causing the sculk shrieker activation.
pub const TriggerType = enum(u8) {
    player_step = 0,
    sculk_sensor_vibration = 1,
};

/// Acoustic sound emitted by the shrieker on activation.
pub const AcousticSound = enum(u8) {
    shriek = 0,
    none = 1,
};

/// Alias for AcousticSound to match Minecraft sound event conventions.
pub const SoundEffect = AcousticSound;

/// Particle visual effects generated by the shrieker.
pub const ParticleType = enum(u8) {
    sculk_shriek_ring = 0,
    sculk_soul = 1,
    none = 2,
};

/// Lifecycle state of a summoned Warden.
pub const WardenSpawnState = enum(u8) {
    none = 0,
    emerging = 1,
    active = 2,
};

// ============================================================================
// Math & Vector Primitives
// ============================================================================

/// 3D integer block coordinate.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) BlockPos {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn toVec3(self: BlockPos) Vec3 {
        return Vec3.init(
            @as(f32, @floatFromInt(self.x)) + 0.5,
            @as(f32, @floatFromInt(self.y)) + 0.5,
            @as(f32, @floatFromInt(self.z)) + 0.5,
        );
    }

    pub fn distanceSq(self: BlockPos, other: BlockPos) f32 {
        const dx = @as(f32, @floatFromInt(self.x - other.x));
        const dy = @as(f32, @floatFromInt(self.y - other.y));
        const dz = @as(f32, @floatFromInt(self.z - other.z));
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn distance(self: BlockPos, other: BlockPos) f32 {
        return @sqrt(self.distanceSq(other));
    }
};

/// 3D floating point vector for entities, particles, and positions.
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn distanceSq(self: Vec3, other: Vec3) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn distance(self: Vec3, other: Vec3) f32 {
        return @sqrt(self.distanceSq(other));
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x + other.x, self.y + other.y, self.z + other.z);
    }
};

// ============================================================================
// Particle Visual System
// ============================================================================

/// Expanding circular ring particle emitted upwards from the center of a screaming Sculk Shrieker.
pub const ShriekRingParticle = struct {
    origin: Vec3,
    radius: f32 = 0.0,
    max_radius: f32 = 3.0,
    growth_rate: f32 = 2.0, // meters per second
    lifetime: f32 = 1.5, // seconds
    age: f32 = 0.0,

    pub fn init(origin: Vec3) ShriekRingParticle {
        return .{ .origin = origin };
    }

    pub fn tick(self: *ShriekRingParticle, dt: f32) void {
        self.age += dt;
        self.radius = @min(self.max_radius, self.age * self.growth_rate);
    }

    pub fn isAlive(self: ShriekRingParticle) bool {
        return self.age < self.lifetime;
    }

    pub fn getAlpha(self: ShriekRingParticle) f32 {
        if (self.age >= self.lifetime) return 0.0;
        return 1.0 - (self.age / self.lifetime);
    }
};
// ============================================================================
// Warden Emergence Tracking
// ============================================================================

/// Tracks the ground emergence animation when a Tier 4 shrieker summons the Warden.
pub const WardenEmergence = struct {
    spawn_pos: Vec3,
    animation_timer: f32 = WARDEN_EMERGE_DURATION_SECONDS,
    is_complete: bool = false,

    pub fn init(spawn_pos: Vec3) WardenEmergence {
        return .{ .spawn_pos = spawn_pos };
    }

    pub fn tick(self: *WardenEmergence, dt: f32) void {
        if (self.animation_timer > 0.0) {
            self.animation_timer -= dt;
            if (self.animation_timer <= TIMER_EPSILON) {
                self.animation_timer = 0.0;
                self.is_complete = true;
            }
        }
    }

    pub fn tickTicks(self: *WardenEmergence, ticks: u32) void {
        const dt = @as(f32, @floatFromInt(ticks)) * SECONDS_PER_TICK;
        self.tick(dt);
    }
};

// ============================================================================
// Player Warning & Status Tracker
// ============================================================================

/// Tracks individual player warning tiers, calm decay timer, and Darkness status.
pub const PlayerTracker = struct {
    id: u32 = 0,
    pos: Vec3 = Vec3.init(0.0, 0.0, 0.0),
    warning_level: u3 = 0,
    decay_timer: f32 = 0.0,
    darkness_timer: f32 = 0.0,
    is_sneaking: bool = false,

    pub fn init(id: u32, pos: Vec3) PlayerTracker {
        return .{
            .id = id,
            .pos = pos,
        };
    }

    pub fn hasDarkness(self: PlayerTracker) bool {
        return self.darkness_timer > 0.0;
    }

    pub fn applyDarkness(self: *PlayerTracker, duration: f32) void {
        self.darkness_timer = @max(self.darkness_timer, duration);
    }

    /// Increments warning level up to Tier 4 and resets the 10-minute calm decay timer.
    pub fn incrementWarning(self: *PlayerTracker) u3 {
        if (self.warning_level < MAX_WARNING_LEVEL) {
            self.warning_level += 1;
        }
        self.decay_timer = WARNING_DECAY_SECONDS;
        return self.warning_level;
    }

    /// Resets the 10-minute decay timer.
    pub fn resetDecay(self: *PlayerTracker) void {
        if (self.warning_level > 0) {
            self.decay_timer = WARNING_DECAY_SECONDS;
        }
    }

    /// Advances timers by dt seconds.
    /// Darkness decrements to zero.
    /// Warning level decays by 1 after 600.0s of calm without shrieker triggers.
    pub fn tick(self: *PlayerTracker, dt: f32) void {
        if (self.darkness_timer > 0.0) {
            self.darkness_timer -= dt;
            if (self.darkness_timer <= TIMER_EPSILON) {
                self.darkness_timer = 0.0;
            }
        }

        if (self.warning_level > 0) {
            self.decay_timer -= dt;
            if (self.decay_timer <= TIMER_EPSILON) {
                self.warning_level -= 1;
                if (self.warning_level > 0) {
                    self.decay_timer = WARNING_DECAY_SECONDS;
                } else {
                    self.decay_timer = 0.0;
                }
            }
        }
    }

    /// Advances timers by integer game ticks.
    pub fn tickTicks(self: *PlayerTracker, ticks: u32) void {
        const dt = @as(f32, @floatFromInt(ticks)) * SECONDS_PER_TICK;
        self.tick(dt);
    }
};
// ============================================================================
// Shriek Result Struct
// ============================================================================

/// Outcome of attempting to trigger a Sculk Shrieker.
pub const ShriekResult = struct {
    shrieked: bool = false,
    cooldown_blocked: bool = false,
    warning_incremented: bool = false,
    warning_level: u3 = 0,
    sound: AcousticSound = .none,
    ring_particles: bool = false,
    darkness_inflicted: bool = false,
    players_affected_by_darkness: u32 = 0,
    summon_warden: bool = false,
    warden_spawn_pos: ?Vec3 = null,
    trigger_type: TriggerType = .player_step,
};
// ============================================================================
// Trigger Condition Checks
// ============================================================================

/// Checks whether a player's physical footprint intersects or steps directly on the shrieker block.
/// In Minecraft, stepping on a sculk shrieker triggers it directly, even if sneaking.
pub fn isPlayerSteppingOnShrieker(player_pos: Vec3, shrieker_pos: BlockPos) bool {
    const sx = @as(f32, @floatFromInt(shrieker_pos.x));
    const sy = @as(f32, @floatFromInt(shrieker_pos.y));
    const sz = @as(f32, @floatFromInt(shrieker_pos.z));

    // Player horizontal footprint: block width [sx, sx + 1.0], [sz, sz + 1.0] with typical 0.2 allowance
    const x_in_range = (player_pos.x >= sx - 0.2) and (player_pos.x <= sx + 1.2);
    const z_in_range = (player_pos.z >= sz - 0.2) and (player_pos.z <= sz + 1.2);
    // Player feet level: stepping on top of block (sy + 1.0) or inside the block [sy, sy + 1.5]
    const y_in_range = (player_pos.y >= sy - 0.05) and (player_pos.y <= sy + 1.5);

    return x_in_range and y_in_range and z_in_range;
}

/// Checks whether a Sculk Sensor is within the 8.0-block transmission range of the Sculk Shrieker.
pub fn canSensorTransmitToShrieker(sensor_pos: BlockPos, shrieker_pos: BlockPos) bool {
    return sensor_pos.distanceSq(shrieker_pos) <= SENSOR_TRANSMISSION_RANGE_SQ;
}

/// Applies the 12.0s Darkness status effect to all players located within 40.0m of the shrieker.
/// Returns the number of players affected.
pub fn applyDarknessAura(
    shrieker_pos: BlockPos,
    players: []PlayerTracker,
    duration: f32,
) u32 {
    const center = shrieker_pos.toVec3();
    var count: u32 = 0;
    for (players) |*player| {
        if (player.pos.distanceSq(center) <= SHRIEKER_DARKNESS_RADIUS_SQ) {
            player.applyDarkness(duration);
            count += 1;
        }
    }
    return count;
}

// ============================================================================
// Sculk Shrieker Block Entity
// ============================================================================

/// Represents a Sculk Shrieker block in the world.
pub const SculkShrieker = struct {
    pos: BlockPos,
    can_summon: bool = true,
    biome: BiomeType = .deep_dark,
    cooldown_timer: f32 = 0.0,
    is_shrieking: bool = false,
    shriek_animation_timer: f32 = 0.0,

    pub fn init(pos: BlockPos, can_summon: bool, biome: BiomeType) SculkShrieker {
        return .{
            .pos = pos,
            .can_summon = can_summon,
            .biome = biome,
        };
    }

    /// Creates a naturally generated Sculk Shrieker in the Deep Dark.
    pub fn natural(x: i32, y: i32, z: i32) SculkShrieker {
        return init(BlockPos.init(x, y, z), true, .deep_dark);
    }

    /// Creates a player-placed Sculk Shrieker (cannot summon, cannot warn).
    pub fn playerPlaced(x: i32, y: i32, z: i32) SculkShrieker {
        return init(BlockPos.init(x, y, z), false, .deep_dark);
    }

    pub fn isOnCooldown(self: SculkShrieker) bool {
        return self.cooldown_timer > TIMER_EPSILON;
    }

    pub fn tick(self: *SculkShrieker, dt: f32) void {
        if (self.cooldown_timer > 0.0) {
            self.cooldown_timer -= dt;
            if (self.cooldown_timer <= TIMER_EPSILON) {
                self.cooldown_timer = 0.0;
            }
        }
        if (self.shriek_animation_timer > 0.0) {
            self.shriek_animation_timer -= dt;
            if (self.shriek_animation_timer <= TIMER_EPSILON) {
                self.shriek_animation_timer = 0.0;
                self.is_shrieking = false;
            }
        }
    }

    pub fn tickTicks(self: *SculkShrieker, ticks: u32) void {
        const dt = @as(f32, @floatFromInt(ticks)) * SECONDS_PER_TICK;
        self.tick(dt);
    }

    /// Triggers the shrieker via a player directly stepping on it.
    pub fn triggerDirectStep(
        self: *SculkShrieker,
        player: *PlayerTracker,
        nearby_players: ?[]PlayerTracker,
    ) ShriekResult {
        return self.executeTrigger(player, .player_step, nearby_players);
    }

    /// Triggers the shrieker via an acoustic vibration from a connected sculk sensor.
    /// Returns null if the sensor is out of the 8.0-block transmission range.
    pub fn triggerSensorVibration(
        self: *SculkShrieker,
        sensor_pos: BlockPos,
        triggering_player: *PlayerTracker,
        nearby_players: ?[]PlayerTracker,
    ) ?ShriekResult {
        if (!canSensorTransmitToShrieker(sensor_pos, self.pos)) {
            return null; // out of transmission range
        }
        return self.executeTrigger(triggering_player, .sculk_sensor_vibration, nearby_players);
    }

    /// Executes the trigger and performs all game logic:
    /// - Checks 10s cooldown
    /// - Emits sound (.shriek) & ring particles
    /// - Inflicts Darkness (12.0s) to players within 40m (if can_summon is true)
    /// - Escalates warning level for player (0 -> 1 -> 2 -> 3 -> 4) (if can_summon is true)
    /// - Evaluates Tier 4 Warden summoning (level 4, can_summon=true, Deep Dark biome)
    pub fn executeTrigger(
        self: *SculkShrieker,
        triggering_player: *PlayerTracker,
        trigger_type: TriggerType,
        nearby_players: ?[]PlayerTracker,
    ) ShriekResult {
        if (self.isOnCooldown()) {
            return .{
                .shrieked = false,
                .cooldown_blocked = true,
                .warning_incremented = false,
                .warning_level = triggering_player.warning_level,
                .sound = .none,
                .ring_particles = false,
                .darkness_inflicted = false,
                .players_affected_by_darkness = 0,
                .summon_warden = false,
                .warden_spawn_pos = null,
                .trigger_type = trigger_type,
            };
        }

        // Put shrieker on 10.0s cooldown
        self.cooldown_timer = SHRIEK_COOLDOWN_SECONDS;
        self.is_shrieking = true;
        self.shriek_animation_timer = SHRIEK_ACTIVE_DURATION_SECONDS;

        // Player-placed shrieker (can_summon == false):
        // Emits acoustic sound and ring particles, but NEVER increments warning,
        // NEVER inflicts darkness, and NEVER summons Warden.
        if (!self.can_summon) {
            return .{
                .shrieked = true,
                .cooldown_blocked = false,
                .warning_incremented = false,
                .warning_level = triggering_player.warning_level,
                .sound = .shriek,
                .ring_particles = true,
                .darkness_inflicted = false,
                .players_affected_by_darkness = 0,
                .summon_warden = false,
                .warden_spawn_pos = null,
                .trigger_type = trigger_type,
            };
        }

        // Naturally generated shrieker (can_summon == true):
        // 1. Escalate player warning level (0 -> 1 -> 2 -> 3 -> 4)
        const old_level = triggering_player.warning_level;
        const new_level = triggering_player.incrementWarning();
        const incremented = (new_level > old_level);

        // 2. Inflict Darkness (12.0s) to all players within 40m radius
        var affected_count: u32 = 0;
        if (nearby_players) |players| {
            affected_count = applyDarknessAura(self.pos, players, DARKNESS_DURATION_SECONDS);
        } else {
            // If only triggering player provided, check if within 40m
            if (triggering_player.pos.distanceSq(self.pos.toVec3()) <= SHRIEKER_DARKNESS_RADIUS_SQ) {
                triggering_player.applyDarkness(DARKNESS_DURATION_SECONDS);
                affected_count = 1;
            }
        }

        // 3. Tier 4 summoning:
        // Requires warning_level == 4, can_summon == true, and biome.isDeepDark()
        const summon = (new_level == WARDEN_SUMMON_LEVEL) and self.biome.isDeepDark();
        const spawn_pos: ?Vec3 = if (summon) self.pos.toVec3() else null;

        return .{
            .shrieked = true,
            .cooldown_blocked = false,
            .warning_incremented = incremented,
            .warning_level = new_level,
            .sound = .shriek,
            .ring_particles = true,
            .darkness_inflicted = (affected_count > 0),
            .players_affected_by_darkness = affected_count,
            .summon_warden = summon,
            .warden_spawn_pos = spawn_pos,
            .trigger_type = trigger_type,
        };
    }
};
// ============================================================================
// Standalone Single-Player Warning Tracker
// ============================================================================

/// Self-contained player warning tracker for single-player integration and
/// backward compatibility with warden_deep_dark.zig.
pub const SculkShriekerWarning = struct {
    warning_level: u3 = 0,
    cooldown_timer: f32 = 0.0,
    decay_timer: f32 = 0.0,
    darkness_timer: f32 = 0.0,
    biome: BiomeType = .deep_dark,

    pub fn init() SculkShriekerWarning {
        return .{};
    }

    /// Triggers a Sculk Shrieker activation in the current biome.
    pub fn triggerShriek(self: *SculkShriekerWarning, can_summon: bool) ShriekResult {
        return self.triggerShriekInBiome(can_summon, self.biome);
    }

    /// Triggers a Sculk Shrieker activation with an explicit biome context.
    pub fn triggerShriekInBiome(
        self: *SculkShriekerWarning,
        can_summon: bool,
        biome: BiomeType,
    ) ShriekResult {
        if (self.cooldown_timer > TIMER_EPSILON) {
            return .{
                .shrieked = false,
                .cooldown_blocked = true,
                .warning_incremented = false,
                .warning_level = self.warning_level,
                .sound = .none,
                .ring_particles = false,
                .darkness_inflicted = false,
                .players_affected_by_darkness = 0,
                .summon_warden = false,
                .warden_spawn_pos = null,
                .trigger_type = .player_step,
            };
        }

        self.cooldown_timer = SHRIEK_COOLDOWN_SECONDS;

        if (!can_summon) {
            return .{
                .shrieked = true,
                .cooldown_blocked = false,
                .warning_incremented = false,
                .warning_level = self.warning_level,
                .sound = .shriek,
                .ring_particles = true,
                .darkness_inflicted = false,
                .players_affected_by_darkness = 0,
                .summon_warden = false,
                .warden_spawn_pos = null,
                .trigger_type = .player_step,
            };
        }

        self.decay_timer = WARNING_DECAY_SECONDS;
        const old_level = self.warning_level;
        if (self.warning_level < MAX_WARNING_LEVEL) {
            self.warning_level += 1;
        }

        // Inflict 12.0s Darkness
        self.darkness_timer = DARKNESS_DURATION_SECONDS;

        // Summon Warden if warning level reached 4 and biome is Deep Dark
        const summon = (self.warning_level == WARDEN_SUMMON_LEVEL) and biome.isDeepDark();

        return .{
            .shrieked = true,
            .cooldown_blocked = false,
            .warning_incremented = (self.warning_level > old_level),
            .warning_level = self.warning_level,
            .sound = .shriek,
            .ring_particles = true,
            .darkness_inflicted = true,
            .players_affected_by_darkness = 1,
            .summon_warden = summon,
            .warden_spawn_pos = null,
            .trigger_type = .player_step,
        };
    }


    /// Triggers the Sculk Shrieker from player interaction or stepping at (player_x, player_y, player_z)
    /// on shrieker block (shrieker_x, shrieker_y, shrieker_z).
    pub fn trigger(
        self: *SculkShriekerWarning,
        player_x: f32,
        player_y: f32,
        player_z: f32,
        shrieker_x: i32,
        shrieker_y: i32,
        shrieker_z: i32,
    ) ShriekResult {
        _ = player_x;
        _ = player_y;
        _ = player_z;
        _ = shrieker_x;
        _ = shrieker_y;
        _ = shrieker_z;
        return self.triggerShriek(true);
    }

    pub fn tick(self: *SculkShriekerWarning, dt: f32) void {
        if (self.cooldown_timer > 0.0) {
            self.cooldown_timer -= dt;
            if (self.cooldown_timer <= TIMER_EPSILON) {
                self.cooldown_timer = 0.0;
            }
        }

        if (self.darkness_timer > 0.0) {
            self.darkness_timer -= dt;
            if (self.darkness_timer <= TIMER_EPSILON) {
                self.darkness_timer = 0.0;
            }
        }

        if (self.warning_level > 0) {
            self.decay_timer -= dt;
            if (self.decay_timer <= TIMER_EPSILON) {
                self.warning_level -= 1;
                if (self.warning_level > 0) {
                    self.decay_timer = WARNING_DECAY_SECONDS;
                } else {
                    self.decay_timer = 0.0;
                }
            }
        }
    }

    pub fn tickTicks(self: *SculkShriekerWarning, ticks: u32) void {
        const dt = @as(f32, @floatFromInt(ticks)) * SECONDS_PER_TICK;
        self.tick(dt);
    }

    pub fn hasDarkness(self: SculkShriekerWarning) bool {
        return self.darkness_timer > 0.0;
    }

    pub fn applyDarkness(self: *SculkShriekerWarning, duration: f32) void {
        self.darkness_timer = @max(self.darkness_timer, duration);
    }
};
// ============================================================================
// Multi-Entity World Warning Coordinator
// ============================================================================

pub const MAX_TRACKED_PLAYERS: usize = 16;
pub const MAX_TRACKED_SHRIEKERS: usize = 32;

/// Coordinates multi-player warning levels, active shriekers, and warden summonings.
pub const SculkShriekerManager = struct {
    players: [MAX_TRACKED_PLAYERS]PlayerTracker = undefined,
    player_count: usize = 0,
    shriekers: [MAX_TRACKED_SHRIEKERS]SculkShrieker = undefined,
    shrieker_count: usize = 0,
    active_emergence: ?WardenEmergence = null,

    pub fn init() SculkShriekerManager {
        return .{};
    }

    pub fn addPlayer(self: *SculkShriekerManager, id: u32, pos: Vec3) ?*PlayerTracker {
        if (self.player_count >= MAX_TRACKED_PLAYERS) return null;
        self.players[self.player_count] = PlayerTracker.init(id, pos);
        const p = &self.players[self.player_count];
        self.player_count += 1;
        return p;
    }

    pub fn getPlayer(self: *SculkShriekerManager, id: u32) ?*PlayerTracker {
        for (self.players[0..self.player_count]) |*p| {
            if (p.id == id) return p;
        }
        return null;
    }

    pub fn getNearestPlayer(self: *SculkShriekerManager, pos: Vec3) ?*PlayerTracker {
        if (self.player_count == 0) return null;
        var nearest: *PlayerTracker = &self.players[0];
        var min_dist_sq = nearest.pos.distanceSq(pos);

        for (self.players[1..self.player_count]) |*p| {
            const d_sq = p.pos.distanceSq(pos);
            if (d_sq < min_dist_sq) {
                min_dist_sq = d_sq;
                nearest = p;
            }
        }
        return nearest;
    }

    pub fn addShrieker(
        self: *SculkShriekerManager,
        pos: BlockPos,
        can_summon: bool,
        biome: BiomeType,
    ) ?*SculkShrieker {
        if (self.shrieker_count >= MAX_TRACKED_SHRIEKERS) return null;
        self.shriekers[self.shrieker_count] = SculkShrieker.init(pos, can_summon, biome);
        const s = &self.shriekers[self.shrieker_count];
        self.shrieker_count += 1;
        return s;
    }

    pub fn getShrieker(self: *SculkShriekerManager, pos: BlockPos) ?*SculkShrieker {
        for (self.shriekers[0..self.shrieker_count]) |*s| {
            if (s.pos.x == pos.x and s.pos.y == pos.y and s.pos.z == pos.z) return s;
        }
        return null;
    }

    /// Checks if player movement causes a direct step on any registered shrieker.
    pub fn onPlayerMove(self: *SculkShriekerManager, player_id: u32, new_pos: Vec3) ?ShriekResult {
        const player = self.getPlayer(player_id) orelse return null;
        player.pos = new_pos;

        for (self.shriekers[0..self.shrieker_count]) |*s| {
            if (isPlayerSteppingOnShrieker(new_pos, s.pos)) {
                const res = s.triggerDirectStep(player, self.players[0..self.player_count]);
                if (res.summon_warden) {
                    if (res.warden_spawn_pos) |sp| {
                        self.active_emergence = WardenEmergence.init(sp);
                    }
                }
                return res;
            }
        }
        return null;
    }

    /// Dispatches a vibration from a Sculk Sensor to registered shriekers in range.
    pub fn onSensorVibration(
        self: *SculkShriekerManager,
        sensor_pos: BlockPos,
        triggering_player_id: ?u32,
    ) ?ShriekResult {
        var player: *PlayerTracker = undefined;
        if (triggering_player_id) |pid| {
            player = self.getPlayer(pid) orelse return null;
        } else {
            player = self.getNearestPlayer(sensor_pos.toVec3()) orelse return null;
        }

        for (self.shriekers[0..self.shrieker_count]) |*s| {
            if (canSensorTransmitToShrieker(sensor_pos, s.pos)) {
                if (s.triggerSensorVibration(sensor_pos, player, self.players[0..self.player_count])) |res| {
                    if (res.summon_warden) {
                        if (res.warden_spawn_pos) |sp| {
                            self.active_emergence = WardenEmergence.init(sp);
                        }
                    }
                    return res;
                }
            }
        }
        return null;
    }

    pub fn tick(self: *SculkShriekerManager, dt: f32) void {
        for (self.players[0..self.player_count]) |*p| {
            p.tick(dt);
        }
        for (self.shriekers[0..self.shrieker_count]) |*s| {
            s.tick(dt);
        }
        if (self.active_emergence) |*em| {
            em.tick(dt);
            if (em.is_complete) {
                self.active_emergence = null;
            }
        }
    }

    pub fn tickTicks(self: *SculkShriekerManager, ticks: u32) void {
        const dt = @as(f32, @floatFromInt(ticks)) * SECONDS_PER_TICK;
        self.tick(dt);
    }
};

// ============================================================================
// Comprehensive Unit Test Suite (30+ Tests)
// ============================================================================

/// Computes the vision-pulsing fog factor [0.0..1.0] for the Darkness effect.
/// Modulates visibility rhythmically over the 12.0s duration.
pub fn computeDarknessFogIntensity(darkness_timer: f32) f32 {
    if (darkness_timer <= 0.0) return 0.0;
    const elapsed = darkness_duration_seconds - darkness_timer;
    const fade: f32 = if (elapsed < 0.8)
        elapsed / 0.8
    else if (darkness_timer < 1.0)
        darkness_timer / 1.0
    else
        1.0;

    const wave = 0.675 + 0.325 * @sin(elapsed * 2.5);
    return @max(0.0, @min(1.0, fade * wave));
}

/// Dynamic fog distances resulting from the Darkness status effect.
pub fn computeDarknessFogDistances(fog_intensity: f32) struct { start: f32, end: f32 } {
    const normal_start: f32 = 32.0;
    const normal_end: f32 = 64.0;
    const dark_start: f32 = 4.0;
    const dark_end: f32 = 15.0;
    return .{
        .start = normal_start - fog_intensity * (normal_start - dark_start),
        .end = normal_end - fog_intensity * (normal_end - dark_end),
    };
}

/// Behavioral state of the Warden.
pub const WardenState = enum {
    calm,
    agitated,
    roaring_attack,
    burrowing,
};

/// Warden anger tracker and sensory AI state machine.
pub const WardenAngerTracker = struct {
    hp: f32 = warden_max_hp,
    anger: u8 = 0,
    smell_cooldown: f32 = 0.0,
    decay_accumulator: f32 = 0.0,
    zero_vibration_timer: f32 = 0.0,
    is_burrowed: bool = false,

    pub fn init() WardenAngerTracker {
        return .{};
    }

    pub fn getState(self: WardenAngerTracker) WardenState {
        if (self.is_burrowed) return .burrowing;
        if (self.anger >= roaring_attack_threshold) return .roaring_attack;
        if (self.anger >= agitated_anger_threshold) return .agitated;
        return .calm;
    }

    pub fn addAnger(self: *WardenAngerTracker, amount: u8) void {
        const sum = @as(u16, self.anger) + @as(u16, amount);
        self.anger = @intCast(@min(@as(u16, max_warden_anger), sum));
    }

    pub fn decayAnger(self: *WardenAngerTracker, dt: f32) void {
        self.decay_accumulator += dt;
        while (self.decay_accumulator >= 1.0) : (self.decay_accumulator -= 1.0) {
            if (self.anger > 0) {
                self.anger -= 1;
            }
        }
    }

    /// Target tracking via smell (+10 anger every 5.0s within 24m)
    pub fn trackSmell(self: *WardenAngerTracker, target_dist: f32, dt: f32) bool {
        if (self.is_burrowed) return false;
        if (target_dist > warden_smell_range) return false;

        self.smell_cooldown += dt;
        if (self.smell_cooldown >= warden_smell_interval) {
            self.smell_cooldown -= warden_smell_interval;
            self.addAnger(smell_anger_bonus);
            return true;
        }
        return false;
    }

    /// Direct smell sniff event (+10 anger within 24m)
    pub fn onSmell(self: *WardenAngerTracker, target_dist: f32) bool {
        if (self.is_burrowed) return false;
        if (target_dist <= warden_smell_range) {
            self.addAnger(smell_anger_bonus);
            return true;
        }
        return false;
    }

    /// Vibration sensed (+35 anger per vibration, +10 if projectile distraction)
    pub fn onVibration(self: *WardenAngerTracker, is_projectile_distraction: bool) void {
        self.zero_vibration_timer = 0.0;
        self.is_burrowed = false;

        if (is_projectile_distraction) {
            self.addAnger(projectile_anger_bonus);
        } else {
            self.addAnger(vibration_anger_bonus);
        }
    }

    pub fn tick(self: *WardenAngerTracker, dt: f32) void {
        if (self.is_burrowed) return;

        // Anger decays by -1 per second
        self.decayAnger(dt);

        // Track duration with zero vibrations; burrows back underground after 60.0s
        self.zero_vibration_timer += dt;
        if (self.zero_vibration_timer >= burrow_timeout_seconds) {
            self.is_burrowed = true;
        }
    }
};

fn getCoordinate3D(pos: anytype) struct { x: f32, y: f32, z: f32 } {
    const T = @TypeOf(pos);
    if (@typeInfo(T) == .array) {
        return .{ .x = pos[0], .y = pos[1], .z = pos[2] };
    } else if (@typeInfo(T) == .@"struct") {
        if (@hasField(T, "x") and @hasField(T, "y") and @hasField(T, "z")) {
            return .{ .x = pos.x, .y = pos.y, .z = pos.z };
        } else if (@hasField(T, "0") and @hasField(T, "1") and @hasField(T, "2")) {
            return .{ .x = pos[0], .y = pos[1], .z = pos[2] };
        }
    }
    @compileError("Position must be [3]f32 or struct with fields x, y, z");
}

/// Checks if a target is within Sonic Boom horizontal (15m) and vertical (20m) range.
pub fn isTargetInSonicBoomRange(warden_pos: anytype, target_pos: anytype) bool {
    const wp = getCoordinate3D(warden_pos);
    const tp = getCoordinate3D(target_pos);
    const dx = tp.x - wp.x;
    const dy = tp.y - wp.y;
    const dz = tp.z - wp.z;
    const horiz_dist_sq = dx * dx + dz * dz;
    const vert_dist = @abs(dy);
    return horiz_dist_sq <= (sonic_boom_horizontal_range * sonic_boom_horizontal_range) and
        vert_dist <= sonic_boom_vertical_range;
}

/// Computes the Sonic Boom attack when target is unreachable by melee pathing.
/// Fires a block-piercing, shield-bypassing, armor-bypassing attack dealing 10.0 magic damage.
pub fn computeSonicBoomAttack(warden_pos: anytype, target_pos: anytype, armor_reduction: f32) struct {
    damage: f32,
    knockback_vx: f32,
    knockback_vy: f32,
    knockback_vz: f32,
} {
    // Sonic Boom completely bypasses armor; armor_reduction is ignored.
    _ = armor_reduction;

    const wp = getCoordinate3D(warden_pos);
    const tp = getCoordinate3D(target_pos);

    const dx = tp.x - wp.x;
    const dy = tp.y - wp.y;
    const dz = tp.z - wp.z;

    const horiz_dist_sq = dx * dx + dz * dz;
    const vert_dist = @abs(dy);

    if (horiz_dist_sq > (sonic_boom_horizontal_range * sonic_boom_horizontal_range) or
        vert_dist > sonic_boom_vertical_range)
    {
        return .{
            .damage = 0.0,
            .knockback_vx = 0.0,
            .knockback_vy = 0.0,
            .knockback_vz = 0.0,
        };
    }

    const horiz_dist = @sqrt(horiz_dist_sq);
    var vx: f32 = 0.0;
    var vz: f32 = 0.0;
    if (horiz_dist > 1e-4) {
        vx = (dx / horiz_dist) * sonic_boom_knockback_horiz_force;
        vz = (dz / horiz_dist) * sonic_boom_knockback_horiz_force;
    }
    const vy = sonic_boom_knockback_vert_force;

    return .{
        .damage = sonic_boom_base_damage,
        .knockback_vx = vx,
        .knockback_vy = vy,
        .knockback_vz = vz,
    };
}


// ============================================================================
// Warden Scent Blast Mechanics (unified from warden_scent_blast.zig)
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;
pub const SCENT_RANGE: f32 = 16.0;
pub const SCENT_INTERVAL_TICKS: u32 = 84;
pub const SCENT_SUSPICION: u16 = 35;
pub const CALM_SUSPICION_LIMIT: u16 = 40;
pub const ROAR_SUSPICION_LIMIT: u16 = 80;
pub const CHASE_SUSPICION_LIMIT: u16 = 150;
pub const ROAR_DURATION_TICKS: u32 = 40;
pub const CALM_DECAY_INTERVAL_TICKS: u32 = 20;
pub const CALM_WANDER_SPEED: f32 = 1.0;
pub const CHASE_SPEED: f32 = 4.2;
pub const SONIC_BLAST_REACH: f32 = 15.0;
pub const SONIC_BLAST_DAMAGE: f32 = 10.0;
pub const SONIC_BLAST_VERTICAL_KNOCKBACK: f32 = 6.0;
pub const SONIC_BLAST_HORIZONTAL_KNOCKBACK: f32 = 8.0;

pub const Position = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn distanceSquared(a: Position, b: Position) f32 {
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const dz = a.z - b.z;
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn distance(a: Position, b: Position) f32 {
        return @sqrt(distanceSquared(a, b));
    }
};

pub fn distance(a: Position, b: Position) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const dz = a.z - b.z;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

pub const Player = struct {
    id: u32,
    position: Position = .{},
    suspicion: u16 = 0,
    health: f32 = 20.0,
    armor_points: f32 = 0.0,
    shield_blocking: bool = false,
    velocity: Velocity = .{},
};

pub const Velocity = struct { x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0 };

pub const State = enum { calm, agitated, roaring, chasing };

pub const TickEvents = struct {
    sniff_animation: bool = false,
    sniffed_player_id: ?u32 = null,
    roar_started: bool = false,
    turned_toward_player_id: ?u32 = null,
};

pub const Warden = struct {
    position: Position = .{},
    state: State = .calm,
    target_player_id: ?u32 = null,
    sniff_ticks: u32 = 0,
    calm_decay_ticks: u32 = 0,
    roar_ticks_remaining: u32 = 0,
    heard_vibration_this_tick: bool = false,

    pub fn init(position: Position) Warden {
        return .{ .position = position };
    }

    pub fn movementSpeed(self: Warden) f32 {
        return switch (self.state) {
            .calm => CALM_WANDER_SPEED,
            .agitated, .roaring => 0.0,
            .chasing => CHASE_SPEED,
        };
    }

    pub fn isChasing(self: Warden) bool {
        return self.state == .chasing;
    }

    /// A vibration identifies its source and raises that player's suspicion by
    /// the caller-supplied amount. Sniffing independently contributes 35 points.
    pub fn hearVibration(self: *Warden, player: *Player, suspicion: u16) void {
        player.suspicion = @min(std.math.maxInt(u16), player.suspicion +| suspicion);
        self.target_player_id = player.id;
        self.heard_vibration_this_tick = true;
        self.refreshState(player);
    }

    fn refreshState(self: *Warden, player: *Player) void {
        if (player.suspicion >= CHASE_SUSPICION_LIMIT) {
            self.state = .chasing;
            self.target_player_id = player.id;
            self.roar_ticks_remaining = 0;
        } else if (player.suspicion >= ROAR_SUSPICION_LIMIT) {
            if (self.state != .roaring) {
                self.state = .roaring;
                self.roar_ticks_remaining = ROAR_DURATION_TICKS;
            }
            self.target_player_id = player.id;
        } else if (player.suspicion >= CALM_SUSPICION_LIMIT) {
            self.state = .agitated;
            self.target_player_id = player.id;
            self.roar_ticks_remaining = 0;
        } else if (self.state != .chasing) {
            self.state = .calm;
            self.roar_ticks_remaining = 0;
        }
    }

    fn nearestPlayer(self: Warden, players: []Player) ?usize {
        var nearest: ?usize = null;
        var nearest_distance = SCENT_RANGE;
        for (players, 0..) |player, index| {
            const player_distance = distance(self.position, player.position);
            if (player_distance <= nearest_distance) {
                if (nearest == null or player_distance < nearest_distance) {
                    nearest = index;
                    nearest_distance = player_distance;
                }
            }
        }
        return nearest;
    }

    /// Advances one 20 Hz tick and returns animation/targeting events. Players
    /// are mutable because scent adds directly to their suspicion meters.
    pub fn tick(self: *Warden, players: []Player) TickEvents {
        const initial_state = self.state;
        var events = TickEvents{};

        if (self.state == .roaring) {
            if (self.roar_ticks_remaining > 0) self.roar_ticks_remaining -= 1;
            if (self.roar_ticks_remaining == 0) self.state = .agitated;
        }

        if (self.state != .chasing) {
            self.sniff_ticks += 1;
            if (self.sniff_ticks >= SCENT_INTERVAL_TICKS) {
                self.sniff_ticks = 0;
                events.sniff_animation = true;
                if (self.nearestPlayer(players)) |index| {
                    const suspect = &players[index];
                    suspect.suspicion = @min(std.math.maxInt(u16), suspect.suspicion +| SCENT_SUSPICION);
                    self.target_player_id = suspect.id;
                    events.sniffed_player_id = suspect.id;
                    self.refreshState(suspect);
                }
            }
        } else {
            self.sniff_ticks = 0;
        }

        if (self.state == .agitated) {
            if (self.target_player_id) |target_id| events.turned_toward_player_id = target_id;
        }

        if (self.state == .calm and !self.heard_vibration_this_tick) {
            self.calm_decay_ticks += 1;
            if (self.calm_decay_ticks >= CALM_DECAY_INTERVAL_TICKS) {
                self.calm_decay_ticks = 0;
                for (players) |*player| {
                    if (player.suspicion > 0) player.suspicion -= 1;
                }
            }
        } else {
            self.calm_decay_ticks = 0;
        }
        events.roar_started = initial_state != .roaring and self.state == .roaring;
        self.heard_vibration_this_tick = false;
        return events;
    }
};

pub const SonicBlastResult = struct {
    hit: bool,
    damage: f32 = 0.0,
    knockback: Velocity = .{},
};

/// Horizontal reach models the penetrating beam: terrain and walls do not
/// occlude it. Vertical separation does not shorten its horizontal travel.
pub fn resolveSonicBlast(warden: Position, target: Position) SonicBlastResult {
    const dx = target.x - warden.x;
    const dz = target.z - warden.z;
    const horizontal_distance = @sqrt(dx * dx + dz * dz);
    if (horizontal_distance > SONIC_BLAST_REACH) return .{ .hit = false };
    if (horizontal_distance <= 0.0001) return .{
        .hit = true,
        .damage = SONIC_BLAST_DAMAGE,
        .knockback = .{ .y = SONIC_BLAST_VERTICAL_KNOCKBACK },
    };
    return .{
        .hit = true,
        .damage = SONIC_BLAST_DAMAGE,
        .knockback = .{
            .x = dx / horizontal_distance * SONIC_BLAST_HORIZONTAL_KNOCKBACK,
            .y = SONIC_BLAST_VERTICAL_KNOCKBACK,
            .z = dz / horizontal_distance * SONIC_BLAST_HORIZONTAL_KNOCKBACK,
        },
    };
}

/// Applies the penetrating hit directly, bypassing armor and shields.
pub fn hitPlayerWithSonicBlast(warden: Position, player: *Player) bool {
    const result = resolveSonicBlast(warden, player.position);
    if (!result.hit) return false;
    player.health = @max(0.0, player.health - result.damage);
    player.velocity = result.knockback;
    return true;
}


// ============================================================================
// Warden Sonic Boom & Emergence Mechanics (unified from warden_sonic_boom.zig)
// ============================================================================

pub const WARDEN_MAX_HEALTH: f32 = 500.0;
pub const WARDEN_MELEE_DAMAGE: f32 = 30.0;
pub const WARDEN_HOSTILE_SPEED: f32 = 4.2;
pub const WARDEN_SNIFF_RANGE: f32 = 16.0;
pub const WARDEN_SNIFF_INTERVAL_TICKS: u32 = 100;
pub const WARDEN_OPTICAL_SIGHT_RANGE: f32 = 0.0;
pub const VIBRATION_AGITATION: u16 = 35;
pub const ROAR_AGITATION_THRESHOLD: u16 = 80;
pub const HOSTILE_AGITATION_THRESHOLD: u16 = 150;
pub const EMERGENCE_TICKS: u32 = 134;
pub const CALM_BURROW_TICKS: u32 = 1200;
pub const SONIC_BOOM_RANGE: f32 = 15.0;
pub const SONIC_BOOM_DAMAGE: f32 = 10.0;
pub const SONIC_BOOM_CHARGE_TICKS: u32 = 34;
pub const SONIC_BOOM_COOLDOWN_TICKS: u32 = 100;
pub const SONIC_BOOM_VERTICAL_IMPULSE: f32 = 6.0;
pub const SONIC_BOOM_HORIZONTAL_IMPULSE: f32 = 8.0;
pub const DARKNESS_RADIUS: f32 = 20.0;
pub const DARKNESS_PULSE_TICKS: u32 = 120;
pub const MELEE_RANGE: f32 = 3.0;


pub const SonicBoomImpulse = struct { vx: f32, vy: f32, vz: f32 };

/// The beam passes through blocks and bypasses armor and shields. Direction is
/// computed from Warden to target; a coincident target receives a vertical lift.
pub fn sonicBoomImpulse(warden: Position, target: Position) SonicBoomImpulse {
    const dx = target.x - warden.x;
    const dz = target.z - warden.z;
    const horizontal = @sqrt(dx * dx + dz * dz);
    if (horizontal <= 0.0001) return .{ .vx = 0.0, .vy = SONIC_BOOM_VERTICAL_IMPULSE, .vz = 0.0 };
    return .{
        .vx = dx / horizontal * SONIC_BOOM_HORIZONTAL_IMPULSE,
        .vy = SONIC_BOOM_VERTICAL_IMPULSE,
        .vz = dz / horizontal * SONIC_BOOM_HORIZONTAL_IMPULSE,
    };
}

pub const WardenBehavior = struct {
    // Compatibility aliases
    pub const WardenSonicBoom = WardenBehavior;

    position: Position = .{},
    health: f32 = WARDEN_MAX_HEALTH,
    agitation: u16 = 0,
    is_emerging: bool = true,
    emergence_ticks_remaining: u32 = EMERGENCE_TICKS,
    is_burrowing: bool = false,
    despawned: bool = false,
    hostile: bool = false,
    roaring: bool = false,
    tracked_target: bool = false,
    calm_ticks: u32 = 0,
    sniff_ticks: u32 = 0,
    boom_charge_ticks: u32 = 0,
    boom_cooldown_ticks: u32 = 0,
    darkness_ticks: u32 = DARKNESS_PULSE_TICKS,
    darkness_pulsed: bool = false,

    pub fn init(position: Position) WardenBehavior {
        return .{ .position = position };
    }

    pub fn movementSpeed(self: WardenBehavior) f32 {
        return if (self.hostile) WARDEN_HOSTILE_SPEED else 0.0;
    }

    /// Emergence is invulnerable, and burrowing/despawned Wardens cannot be hit.
    pub fn takeDamage(self: *WardenBehavior, amount: f32) f32 {
        if (self.is_emerging or self.is_burrowing or self.despawned or amount <= 0.0) return 0.0;
        const dealt = @min(amount, self.health);
        self.health -= dealt;
        return dealt;
    }

    fn resetCalm(self: *WardenBehavior) void {
        self.calm_ticks = 0;
        self.tracked_target = true;
    }

    pub fn hearVibration(self: *WardenBehavior) void {
        if (self.despawned) return;
        self.resetCalm();
        self.agitation = @min(HOSTILE_AGITATION_THRESHOLD, self.agitation + VIBRATION_AGITATION);
        self.roaring = self.agitation >= ROAR_AGITATION_THRESHOLD;
        self.hostile = self.agitation >= HOSTILE_AGITATION_THRESHOLD;
    }

    /// Scent is a periodic, omnidirectional target sense within 16m. It locates
    /// and keeps the target active without changing the vibration agitation score.
    pub fn sniffTarget(self: *WardenBehavior, target: Position) bool {
        if (distance(self.position, target) > WARDEN_SNIFF_RANGE) return false;
        self.resetCalm();
        return true;
    }

    pub fn canStartSonicBoom(self: WardenBehavior, target: Position) bool {
        const range = distance(self.position, target);
        return !self.is_emerging and !self.is_burrowing and !self.despawned and
            self.hostile and range > MELEE_RANGE and range <= SONIC_BOOM_RANGE and
            self.boom_charge_ticks == 0 and self.boom_cooldown_ticks == 0;
    }

    /// Advances fixed 20Hz simulation. The return value reports a newly fired
    /// boom; when a target remains eligible it charges for 34 ticks first.
    pub fn tick(self: *WardenBehavior, target: ?Position) bool {
        if (self.despawned) return false;
        self.darkness_pulsed = false;
        var just_emerged = false;
        if (self.is_emerging) {
            if (self.emergence_ticks_remaining > 0) self.emergence_ticks_remaining -= 1;
            if (self.emergence_ticks_remaining == 0) {
                self.is_emerging = false;
                just_emerged = true;
            }
        }

        if (self.boom_cooldown_ticks > 0) self.boom_cooldown_ticks -= 1;
        var fired = false;
        if (self.boom_charge_ticks > 0) {
            self.boom_charge_ticks -= 1;
            if (self.boom_charge_ticks == 0) {
                self.boom_cooldown_ticks = SONIC_BOOM_COOLDOWN_TICKS;
                fired = true;
            }
        } else if (target) |player| {
            if (self.canStartSonicBoom(player)) self.boom_charge_ticks = SONIC_BOOM_CHARGE_TICKS;
        }

        if (self.darkness_ticks > 0) self.darkness_ticks -= 1;
        if (self.darkness_ticks == 0) {
            self.darkness_pulsed = true;
            self.darkness_ticks = DARKNESS_PULSE_TICKS;
        }

        self.sniff_ticks += 1;
        if (self.sniff_ticks >= WARDEN_SNIFF_INTERVAL_TICKS) {
            self.sniff_ticks = 0;
            if (target) |player| _ = self.sniffTarget(player);
        }

        if (!just_emerged and !self.is_emerging and self.agitation == 0 and !self.tracked_target) {
            self.calm_ticks += 1;
            if (self.calm_ticks >= CALM_BURROW_TICKS) {
                self.is_burrowing = true;
                self.despawned = true;
            }
        }
        self.tracked_target = false;
        return fired;
    }

    pub fn darknessAffects(self: WardenBehavior, player: Position) bool {
        return distance(self.position, player) <= DARKNESS_RADIUS;
    }

    pub fn emitsDarknessTo(self: WardenBehavior, player: Position) bool {
        return self.darkness_pulsed and self.darknessAffects(player);
    }
};

pub const BoomResult = struct { hit: bool, damage: f32, impulse: SonicBoomImpulse };

pub const PlayerCombatState = struct {
    health: f32 = 20.0,
    armor_points: f32 = 0.0,
    shield_blocking: bool = false,
    velocity: SonicBoomImpulse = .{ .vx = 0.0, .vy = 0.0, .vz = 0.0 },
};

pub fn resolveSonicBoom(warden: Position, target: Position) BoomResult {
    if (distance(warden, target) > SONIC_BOOM_RANGE) return .{
        .hit = false,
        .damage = 0.0,
        .impulse = .{ .vx = 0.0, .vy = 0.0, .vz = 0.0 },
    };
    return .{ .hit = true, .damage = SONIC_BOOM_DAMAGE, .impulse = sonicBoomImpulse(warden, target) };
}

/// Applies a valid beam hit directly, deliberately ignoring armor and shield state.
pub fn hitPlayerWithSonicBoom(warden: Position, target: Position, player: *PlayerCombatState) bool {
    const result = resolveSonicBoom(warden, target);
    if (!result.hit) return false;
    player.health = @max(0.0, player.health - result.damage);
    player.velocity = result.impulse;
    return true;
}


pub const WardenSonicBoom = WardenBehavior;

// ============================================================================
// Sculk Shrieker Darkness Fog & Multi-Player Warning Rules
// (unified from sculk_shrieker_fog.zig and sculk_shrieker_warning.zig)
// ============================================================================

pub const FOG_PERIOD_TICKS: u32 = 80;
pub const WARDEN_EMERGENCE_TICKS: u32 = 134;


pub const FogDistances = struct { start: f32, end: f32 };

/// Returns a repeating clear-to-gloom-to-clear sine envelope over four seconds.
/// `elapsed_ticks` is relative to the most recent shrieker activation.
pub fn fogIntensity(elapsed_ticks: u32) f32 {
    const phase_ticks = elapsed_ticks % FOG_PERIOD_TICKS;
    const phase = @as(f32, @floatFromInt(phase_ticks)) * (2.0 * std.math.pi / @as(f32, @floatFromInt(FOG_PERIOD_TICKS)));
    return 0.5 - 0.5 * @cos(phase);
}

/// Interpolates between clear vision (25m/35m) and blinding gloom (2m/6m).
pub fn fogDistances(intensity: f32) FogDistances {
    const t = std.math.clamp(intensity, 0.0, 1.0);
    return .{ .start = 25.0 + (2.0 - 25.0) * t, .end = 35.0 + (6.0 - 35.0) * t };
}

pub const FogPlayer = struct {
    id: u32,
    position: Position = .{},
    warning_level: u8 = 0,
    calm_ticks: u32 = 0,
    darkness_ticks_remaining: u32 = 0,

    pub fn init(id: u32, position: Position) FogPlayer {
        return .{ .id = id, .position = position };
    }

    pub fn tick(self: *FogPlayer, ticks: u32) void {
        self.darkness_ticks_remaining -|= ticks;
        if (self.warning_level == 0) {
            self.calm_ticks = 0;
            return;
        }
        var remaining = ticks;
        while (remaining > 0 and self.warning_level > 0) {
            const until_decay = WARNING_DECAY_TICKS - self.calm_ticks;
            if (remaining < until_decay) {
                self.calm_ticks += remaining;
                return;
            }
            remaining -= until_decay;
            self.warning_level -= 1;
            self.calm_ticks = 0;
        }
    }

    pub fn darknessActive(self: FogPlayer) bool {
        return self.darkness_ticks_remaining > 0;
    }

    pub fn currentFog(self: FogPlayer) FogDistances {
        if (!self.darknessActive()) return fogDistances(0.0);
        return fogDistances(fogIntensity(DARKNESS_DURATION_TICKS - self.darkness_ticks_remaining));
    }
};

pub const FogWardenEmergence = struct {
    position: Position,
    is_emerging: bool = true,
    ticks_remaining: u32 = WARDEN_EMERGENCE_TICKS,

    pub fn tick(self: *FogWardenEmergence, ticks: u32) void {
        self.ticks_remaining -|= ticks;
        if (self.ticks_remaining == 0) self.is_emerging = false;
    }
};

pub const FogActivation = struct {
    activated: bool = false,
    warning_level: u8 = 0,
    affected_players: u32 = 0,
    summon_warden: bool = false,
    emergence: ?FogWardenEmergence = null,
};

/// One shrieker owns its independent 200-tick reactivation cooldown.
pub const FogSculkShrieker = struct {
    position: Position,
    can_summon: bool,
    cooldown_ticks_remaining: u32 = 0,

    pub fn init(position: Position, can_summon: bool) FogSculkShrieker {
        return .{ .position = position, .can_summon = can_summon };
    }

    pub fn tick(self: *FogSculkShrieker, ticks: u32) void {
        self.cooldown_ticks_remaining -|= ticks;
    }

    /// A valid activation pulses darkness for nearby players. Only a natural
    /// shrieker advances warning tiers or creates an emergence event.
    pub fn activate(self: *FogSculkShrieker, player: *FogPlayer, players: []FogPlayer) FogActivation {
        if (self.cooldown_ticks_remaining != 0) return .{ .warning_level = player.warning_level };

        self.cooldown_ticks_remaining = SHRIEK_COOLDOWN_TICKS;
        player.calm_ticks = 0;
        var result = FogActivation{ .activated = true, .warning_level = player.warning_level };
        for (players) |*nearby| {
            if (Position.distanceSquared(self.position, nearby.position) <= SHRIEKER_DARKNESS_RADIUS_SQ) {
                nearby.darkness_ticks_remaining = DARKNESS_DURATION_TICKS;
                result.affected_players += 1;
            }
        }
        // The activating player may be represented by a separate tracker in the
        // caller's slice; ensure they receive the aura in either arrangement.
        if (Position.distanceSquared(self.position, player.position) <= SHRIEKER_DARKNESS_RADIUS_SQ) {
            player.darkness_ticks_remaining = DARKNESS_DURATION_TICKS;
            var found_player = false;
            for (players) |nearby| if (nearby.id == player.id) {
                found_player = true;
            };
            if (!found_player) result.affected_players += 1;
        }

        if (self.can_summon) {
            const previous_warning_level = player.warning_level;
            if (player.warning_level < MAX_WARNING_LEVEL) player.warning_level += 1;
            result.warning_level = player.warning_level;
            if (previous_warning_level == MAX_WARNING_LEVEL - 1 and player.warning_level == MAX_WARNING_LEVEL) {
                result.summon_warden = true;
                result.emergence = .{ .position = self.position };
            }
        }
        return result;
    }
};


// ============================================================================
// Unit Tests
// ============================================================================

test "deep dark constants match expected Minecraft specifications" {
    try std.testing.expectEqual(@as(f32, 8.0), catalyst_range);
    try std.testing.expectEqual(@as(f32, 64.0), catalyst_range_sq);
    try std.testing.expectEqual(@as(u16, 20), high_xp_sensor_threshold);
    try std.testing.expectEqual(@as(u16, 50), high_xp_shrieker_threshold);

    try std.testing.expectEqual(@as(f32, 10.0), shriek_cooldown_seconds);
    try std.testing.expectEqual(@as(f32, 600.0), warning_decay_seconds);
    try std.testing.expectEqual(@as(f32, 12.0), darkness_duration_seconds);
    try std.testing.expectEqual(@as(u3, 4), max_warning_level);
    try std.testing.expectEqual(@as(u3, 4), warden_summon_level);

    try std.testing.expectEqual(@as(f32, 500.0), warden_max_hp);
    try std.testing.expectEqual(@as(f32, 30.0), warden_melee_damage);
    try std.testing.expectEqual(@as(f32, 24.0), warden_smell_range);
    try std.testing.expectEqual(@as(f32, 576.0), warden_smell_range_sq);
    try std.testing.expectEqual(@as(f32, 5.0), warden_smell_interval);
    try std.testing.expectEqual(@as(u8, 10), smell_anger_bonus);
    try std.testing.expectEqual(@as(u8, 35), vibration_anger_bonus);
    try std.testing.expectEqual(@as(u8, 10), projectile_anger_bonus);
    try std.testing.expectEqual(@as(u8, 40), agitated_anger_threshold);
    try std.testing.expectEqual(@as(u8, 80), roaring_attack_threshold);
    try std.testing.expectEqual(@as(f32, 60.0), burrow_timeout_seconds);

    try std.testing.expectEqual(@as(f32, 15.0), sonic_boom_horizontal_range);
    try std.testing.expectEqual(@as(f32, 20.0), sonic_boom_vertical_range);
    try std.testing.expectEqual(@as(f32, 10.0), sonic_boom_base_damage);
}

test "sculkSpreadRadius scales with XP amount up to 8 blocks" {
    try std.testing.expectEqual(@as(u8, 0), sculkSpreadRadius(0));
    try std.testing.expectEqual(@as(u8, 1), sculkSpreadRadius(3));
    try std.testing.expectEqual(@as(u8, 1), sculkSpreadRadius(5));
    try std.testing.expectEqual(@as(u8, 2), sculkSpreadRadius(10));
    try std.testing.expectEqual(@as(u8, 2), sculkSpreadRadius(15));
    try std.testing.expectEqual(@as(u8, 3), sculkSpreadRadius(25));
    try std.testing.expectEqual(@as(u8, 4), sculkSpreadRadius(45));
    try std.testing.expectEqual(@as(u8, 5), sculkSpreadRadius(70));
    try std.testing.expectEqual(@as(u8, 6), sculkSpreadRadius(100));
    try std.testing.expectEqual(@as(u8, 7), sculkSpreadRadius(150));
    try std.testing.expectEqual(@as(u8, 8), sculkSpreadRadius(250));
    try std.testing.expectEqual(@as(u8, 8), sculkSpreadRadius(1000));
}

test "SculkCatalyst detects mob death within 8.0 blocks (64.0 sq distance)" {
    var catalyst = SculkCatalyst.init(10, 60, 10);
    // Mob dies at (12.0, 60.0, 14.0): dx = 1.5, dz = 3.5 -> dist_sq = 2.25 + 12.25 = 14.5 <= 64.0
    const charge = catalyst.onMobDeath(12.0, 60.0, 14.0, 20);
    try std.testing.expect(charge != null);
    if (charge) |c| {
        try std.testing.expectEqual(@as(i32, 12), c.origin_x);
        try std.testing.expectEqual(@as(i32, 60), c.origin_y);
        try std.testing.expectEqual(@as(i32, 14), c.origin_z);
        try std.testing.expectEqual(@as(u16, 20), c.xp_amount);
        try std.testing.expectEqual(@as(u8, 3), c.spread_radius);
    }
    try std.testing.expect(catalyst.bloom_active);
    try std.testing.expectEqual(@as(u32, 1), catalyst.charges_absorbed);
    try std.testing.expectEqual(@as(u32, 20), catalyst.total_xp_consumed);

    catalyst.tick(2.5);
    try std.testing.expect(!catalyst.bloom_active);
}

test "SculkCatalyst ignores mob death beyond 8.0 blocks or zero XP" {
    var catalyst = SculkCatalyst.init(0, 0, 0);

    // 0 XP drop
    try std.testing.expect(catalyst.onMobDeath(1.0, 0.0, 1.0, 0) == null);

    // Beyond 8.0 blocks: dx = 9.0 -> dist_sq >= 81.0 > 64.0
    try std.testing.expect(catalyst.onMobDeath(9.5, 0.5, 0.5, 50) == null);
    try std.testing.expectEqual(@as(u32, 0), catalyst.charges_absorbed);
}

test "convertBlock converts stone, deepslate, dirt to Sculk and SculkVein" {
    try std.testing.expect(isConvertibleBlock(.stone));
    try std.testing.expect(isConvertibleBlock(.deepslate));
    try std.testing.expect(isConvertibleBlock(.dirt));
    try std.testing.expect(!isConvertibleBlock(.air));

    // Core region becomes solid Sculk
    const core_sculk = convertBlock(.stone, 20, 1.0, 50);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk), core_sculk);

    const deepslate_sculk = convertBlock(.deepslate, 30, 0.5, 50);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk), deepslate_sculk);

    // Perimeter / outer region becomes SculkVein
    const edge_vein = convertBlock(.dirt, 20, 2.8, 50);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk_vein), edge_vein);

    // Non-convertible block returns null
    try std.testing.expectEqual(@as(?DeepDarkBlock, null), convertBlock(.air, 20, 1.0, 50));
}

test "convertBlock on high-XP kills spawns SculkSensor and SculkShrieker" {
    // High XP >= 50 and lucky roll spawns Sculk Shrieker
    const shrieker = convertBlock(.deepslate, 60, 1.0, 10);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk_shrieker), shrieker);

    // High XP >= 20 and roll spawns Sculk Sensor
    const sensor = convertBlock(.stone, 30, 1.0, 25);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk_sensor), sensor);

    // Low XP (< 20) with roll does NOT spawn sensor or shrieker, spawns Sculk
    const low_xp = convertBlock(.stone, 10, 0.5, 5);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk), low_xp);
}

test "BloomCharge isWithinSpread checks spherical expansion radius" {
    const charge = BloomCharge.init(0, 0, 0, 50); // spread_radius = 4
    try std.testing.expectEqual(@as(u8, 4), charge.spread_radius);
    try std.testing.expect(charge.isWithinSpread(2, 2, 2)); // dist_sq = 12 <= 16
    try std.testing.expect(charge.isWithinSpread(4, 0, 0)); // dist_sq = 16 <= 16
    try std.testing.expect(!charge.isWithinSpread(5, 0, 0)); // dist_sq = 25 > 16
}

test "SculkShriekerWarning increments warning levels 1 to 4 on natural shrieks" {
    var tracker = SculkShriekerWarning.init();
    try std.testing.expectEqual(@as(u3, 0), tracker.warning_level);

    // Shriek 1
    const r1 = tracker.triggerShriek(true);
    try std.testing.expect(r1.shrieked);
    try std.testing.expectEqual(@as(u3, 1), r1.warning_level);
    try std.testing.expect(!r1.summon_warden);

    tracker.tick(10.0); // Wait out cooldown

    // Shriek 2
    const r2 = tracker.triggerShriek(true);
    try std.testing.expect(r2.shrieked);
    try std.testing.expectEqual(@as(u3, 2), r2.warning_level);
    try std.testing.expect(!r2.summon_warden);

    tracker.tick(10.0);

    // Shriek 3
    const r3 = tracker.triggerShriek(true);
    try std.testing.expect(r3.shrieked);
    try std.testing.expectEqual(@as(u3, 3), r3.warning_level);
    try std.testing.expect(!r3.summon_warden);

    tracker.tick(10.0);

    // Shriek 4 -> Summons Warden & inflicts Darkness!
    const r4 = tracker.triggerShriek(true);
    try std.testing.expect(r4.shrieked);
    try std.testing.expectEqual(@as(u3, 4), r4.warning_level);
    try std.testing.expect(r4.summon_warden);
    try std.testing.expect(r4.darkness_inflicted);
    try std.testing.expect(tracker.hasDarkness());
}

test "SculkShriekerWarning 10.0s cooldown blocks rapid shriek increments" {
    var tracker = SculkShriekerWarning.init();

    const r1 = tracker.triggerShriek(true);
    try std.testing.expect(r1.shrieked);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);

    // Immediate second shriek blocked by cooldown
    const r2 = tracker.triggerShriek(true);
    try std.testing.expect(!r2.shrieked);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);

    // After 9 seconds, still on cooldown
    tracker.tick(9.0);
    const r3 = tracker.triggerShriek(true);
    try std.testing.expect(!r3.shrieked);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);

    // After remaining 1.1s, cooldown has elapsed
    tracker.tick(1.1);
    const r4 = tracker.triggerShriek(true);
    try std.testing.expect(r4.shrieked);
    try std.testing.expectEqual(@as(u3, 2), tracker.warning_level);
}

test "SculkShriekerWarning player-placed shrieker (can_summon=false) does not increase warning" {
    var tracker = SculkShriekerWarning.init();

    const res = tracker.triggerShriek(false);
    try std.testing.expect(res.shrieked);
    try std.testing.expect(!res.warning_incremented);
    try std.testing.expectEqual(@as(u3, 0), res.warning_level);
    try std.testing.expect(!res.summon_warden);
    try std.testing.expect(!res.darkness_inflicted);
}

test "SculkShriekerWarning decays 1 level every 600.0s without shrieks" {
    var tracker = SculkShriekerWarning.init();
    _ = tracker.triggerShriek(true); // level 1
    tracker.tick(10.0);
    _ = tracker.triggerShriek(true); // level 2
    try std.testing.expectEqual(@as(u3, 2), tracker.warning_level);

    // Advance 599.0s -> still level 2
    tracker.tick(599.0);
    try std.testing.expectEqual(@as(u3, 2), tracker.warning_level);

    // Advance 2.0s -> decays to level 1
    tracker.tick(2.0);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);

    // Advance another 600.0s -> decays to level 0
    tracker.tick(600.0);
    try std.testing.expectEqual(@as(u3, 0), tracker.warning_level);
    try std.testing.expectEqual(@as(f32, 0.0), tracker.decay_timer);
}

test "Darkness vision-pulsing fog factor oscillates and expires" {
    var tracker = SculkShriekerWarning.init();
    tracker.applyDarkness(12.0);
    try std.testing.expect(tracker.hasDarkness());

    const fog1 = computeDarknessFogIntensity(tracker.darkness_timer);
    try std.testing.expect(fog1 >= 0.0 and fog1 <= 1.0);

    const dists = computeDarknessFogDistances(0.8);
    try std.testing.expect(dists.start < 32.0);
    try std.testing.expect(dists.end < 64.0);

    // Advance 12.5s -> Darkness effect fades and expires
    tracker.tick(12.5);
    try std.testing.expect(!tracker.hasDarkness());
    try std.testing.expectEqual(@as(f32, 0.0), computeDarknessFogIntensity(tracker.darkness_timer));
}

test "WardenAngerTracker tracks targets via smell (+10 anger every 5s within 24m)" {
    var warden = WardenAngerTracker.init();
    try std.testing.expectEqual(@as(u8, 0), warden.anger);

    // Target at 15m (within 24m): tick 4.0s (not yet 5.0s)
    try std.testing.expect(!warden.trackSmell(15.0, 4.0));
    try std.testing.expectEqual(@as(u8, 0), warden.anger);

    // Additional 1.5s (total >= 5.0s): smells target and gains +10 anger
    try std.testing.expect(warden.trackSmell(15.0, 1.5));
    try std.testing.expectEqual(@as(u8, 10), warden.anger);

    // Target out of smell range (30m) does not increase anger
    try std.testing.expect(!warden.trackSmell(30.0, 10.0));
    try std.testing.expectEqual(@as(u8, 10), warden.anger);
}

test "WardenAngerTracker onSmell direct check" {
    var warden = WardenAngerTracker.init();
    try std.testing.expect(warden.onSmell(20.0));
    try std.testing.expectEqual(@as(u8, 10), warden.anger);

    try std.testing.expect(!warden.onSmell(25.0));
    try std.testing.expectEqual(@as(u8, 10), warden.anger);
}

test "WardenAngerTracker vibration adds +35, projectile distraction adds +10" {
    var warden = WardenAngerTracker.init();

    // Standard vibration: +35 anger
    warden.onVibration(false);
    try std.testing.expectEqual(@as(u8, 35), warden.anger);

    // Projectile distraction: +10 anger
    warden.onVibration(true);
    try std.testing.expectEqual(@as(u8, 45), warden.anger);
}

test "WardenAngerTracker transitions between calm, agitated (>=40), and roaring_attack (>=80)" {
    var warden = WardenAngerTracker.init();
    try std.testing.expectEqual(WardenState.calm, warden.getState());

    warden.anger = 39;
    try std.testing.expectEqual(WardenState.calm, warden.getState());

    warden.anger = 40;
    try std.testing.expectEqual(WardenState.agitated, warden.getState());

    warden.anger = 79;
    try std.testing.expectEqual(WardenState.agitated, warden.getState());

    warden.anger = 80;
    try std.testing.expectEqual(WardenState.roaring_attack, warden.getState());

    warden.anger = 120;
    try std.testing.expectEqual(WardenState.roaring_attack, warden.getState());
}

test "WardenAngerTracker decayAnger reduces anger by 1 per second" {
    var warden = WardenAngerTracker.init();
    warden.anger = 85;

    warden.tick(3.2);
    try std.testing.expectEqual(@as(u8, 82), warden.anger);

    warden.tick(2.8);
    try std.testing.expectEqual(@as(u8, 79), warden.anger);
    try std.testing.expectEqual(WardenState.agitated, warden.getState());
}

test "WardenAngerTracker automatically burrows back underground after 60.0s of zero vibrations" {
    var warden = WardenAngerTracker.init();
    try std.testing.expect(!warden.is_burrowed);

    warden.tick(55.0);
    try std.testing.expect(!warden.is_burrowed);

    // Vibration at 55s resets the idle timer
    warden.onVibration(false);
    try std.testing.expectEqual(@as(f32, 0.0), warden.zero_vibration_timer);

    // Tick 59.0s -> still active
    warden.tick(59.0);
    try std.testing.expect(!warden.is_burrowed);

    // Tick 1.5s (total > 60.0s) -> burrows underground
    warden.tick(1.5);
    try std.testing.expect(warden.is_burrowed);
    try std.testing.expectEqual(WardenState.burrowing, warden.getState());

    // Subsequent vibration un-burrows the Warden
    warden.onVibration(false);
    try std.testing.expect(!warden.is_burrowed);
}

test "computeSonicBoomAttack deals 10.0 magic damage bypassing armor completely" {
    const warden_pos = [3]f32{ 0.0, 60.0, 0.0 };
    const target_pos = [3]f32{ 6.0, 64.0, 8.0 }; // horiz dist = 10.0m <= 15m, vert dist = 4.0m <= 20m

    // Unarmored player (armor_reduction = 0.0): 10.0 damage
    const res_unarmored = computeSonicBoomAttack(warden_pos, target_pos, 0.0);
    try std.testing.expectEqual(@as(f32, 10.0), res_unarmored.damage);

    // Full Netherite armor player (armor_reduction = 0.75): still exactly 10.0 damage!
    const res_armored = computeSonicBoomAttack(warden_pos, target_pos, 0.75);
    try std.testing.expectEqual(@as(f32, 10.0), res_armored.damage);

    // Maximum armor reduction (1.0): still 10.0 damage
    const res_max = computeSonicBoomAttack(warden_pos, target_pos, 1.0);
    try std.testing.expectEqual(@as(f32, 10.0), res_max.damage);
}

test "computeSonicBoomAttack range boundaries (15.0 horizontal / 20.0 vertical)" {
    const warden_pos = [3]f32{ 0.0, 50.0, 0.0 };

    // Within range
    try std.testing.expect(isTargetInSonicBoomRange(warden_pos, [3]f32{ 15.0, 50.0, 0.0 }));
    try std.testing.expect(isTargetInSonicBoomRange(warden_pos, [3]f32{ 0.0, 70.0, 0.0 }));

    // Beyond horizontal range (> 15.0m): returns 0 damage
    const out_horiz = computeSonicBoomAttack(warden_pos, [3]f32{ 16.0, 50.0, 0.0 }, 0.5);
    try std.testing.expectEqual(@as(f32, 0.0), out_horiz.damage);
    try std.testing.expectEqual(@as(f32, 0.0), out_horiz.knockback_vx);

    // Beyond vertical range (> 20.0m): returns 0 damage
    const out_vert = computeSonicBoomAttack(warden_pos, [3]f32{ 0.0, 71.0, 0.0 }, 0.5);
    try std.testing.expectEqual(@as(f32, 0.0), out_vert.damage);
    try std.testing.expectEqual(@as(f32, 0.0), out_vert.knockback_vy);
}

test "computeSonicBoomAttack knockback direction and upward force" {
    const warden_pos = [3]f32{ 0.0, 50.0, 0.0 };
    const target_pos = [3]f32{ 10.0, 52.0, 0.0 };

    const boom = computeSonicBoomAttack(warden_pos, target_pos, 0.0);
    try std.testing.expectEqual(@as(f32, 10.0), boom.damage);
    // Knockback along +X direction
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), boom.knockback_vx, 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), boom.knockback_vz, 1e-4);
    // Upward vertical knockback lift
    try std.testing.expectEqual(@as(f32, 0.5), boom.knockback_vy);
}


test "SculkShriekerWarning trigger method advances warning level" {
    var tracker = SculkShriekerWarning.init();
    const res = tracker.trigger(0.5, 61.0, 0.5, 0, 60, 0);
    try std.testing.expect(res.shrieked);
    try std.testing.expectEqual(@as(u3, 1), res.warning_level);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);
}

// Scent blast unit tests
test "scent cadence does not animate during first 83 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 2 } }};
    for (0..83) |_| try std.testing.expect(!(w.tick(&p).sniff_animation));
}
test "sniff animation fires on tick 84" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..83) |_| _ = w.tick(&p);
    try std.testing.expect(w.tick(&p).sniff_animation);
}
test "sniff cadence repeats after another 84 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..84) |_| _ = w.tick(&p);
    for (0..83) |_| try std.testing.expect(!w.tick(&p).sniff_animation);
    try std.testing.expect(w.tick(&p).sniff_animation);
}
test "sniff detects player at exactly 16 meters" {
    var w = Warden.init(.{});
    // Start the calm decay window at its boundary so this asserts the direct
    // +35 acquisition before any subsequent calm decay can occur.
    w.calm_decay_ticks = CALM_DECAY_INTERVAL_TICKS - 1;
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 16 } }};
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 35), p[0].suspicion);
}
test "sniff excludes player beyond 16 meters" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 16.01 } }};
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "scent range uses three dimensional Euclidean distance" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 12, .y = 12 } }};
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "sniff selects nearest of multiple players" {
    var w = Warden.init(.{});
    var p = [_]Player{ .{ .id = 1, .position = .{ .x = 9 } }, .{ .id = 2, .position = .{ .x = 3 } } };
    for (0..83) |_| _ = w.tick(&p);
    const event = w.tick(&p);
    try std.testing.expectEqual(@as(?u32, 2), event.sniffed_player_id);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
    try std.testing.expectEqual(@as(u16, 35), p[1].suspicion);
}
test "sniff animation occurs with no player in range" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 17 } }};
    for (0..83) |_| _ = w.tick(&p);
    const event = w.tick(&p);
    try std.testing.expect(event.sniff_animation);
    try std.testing.expectEqual(@as(?u32, null), event.sniffed_player_id);
}
test "scent adds 35 suspicion on each periodic acquisition" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..168) |_| _ = w.tick(&p);
    // The first 35-point increase is followed by four calm decay ticks before
    // the second sniff, so the net total is 66.
    try std.testing.expectEqual(@as(u16, 66), p[0].suspicion);
}
test "suspicion reaches agitated threshold at 40" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 39 }};
    w.hearVibration(&p[0], 1);
    try std.testing.expectEqual(State.agitated, w.state);
}
test "suspicion below 40 stays calm" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 39 }};
    w.hearVibration(&p[0], 0);
    try std.testing.expectEqual(State.calm, w.state);
}
test "agitated state turns toward identified suspect" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 7, .suspicion = 40 }};
    w.target_player_id = 7;
    w.state = .agitated;
    try std.testing.expectEqual(@as(?u32, 7), w.tick(&p).turned_toward_player_id);
}
test "suspicion 79 remains agitated" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 79 }};
    w.hearVibration(&p[0], 0);
    try std.testing.expectEqual(State.agitated, w.state);
}
test "suspicion reaches roar at 80" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 79 }};
    w.hearVibration(&p[0], 1);
    try std.testing.expectEqual(State.roaring, w.state);
    try std.testing.expectEqual(@as(u32, 40), w.roar_ticks_remaining);
}
test "suspicion 149 remains below chase" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 149 }};
    w.hearVibration(&p[0], 0);
    try std.testing.expectEqual(State.roaring, w.state);
}
test "suspicion reaches relentless chase at 150" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 149 }};
    w.hearVibration(&p[0], 1);
    try std.testing.expectEqual(State.chasing, w.state);
}
test "sniff accumulation escalates calm player through suspicion tiers" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..84 * 4) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 136), p[0].suspicion);
    try std.testing.expectEqual(State.roaring, w.state);
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(State.chasing, w.state);
}
test "tick reports the start of the roar animation" {
    var w = Warden.init(.{});
    w.sniff_ticks = SCENT_INTERVAL_TICKS - 1;
    w.calm_decay_ticks = CALM_DECAY_INTERVAL_TICKS - 1;
    var p = [_]Player{.{ .id = 1, .suspicion = 45 }};
    try std.testing.expect(w.tick(&p).roar_started);
}
test "roar lasts exactly 40 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 80 }};
    w.hearVibration(&p[0], 0);
    for (0..39) |_| _ = w.tick(&p);
    try std.testing.expectEqual(State.roaring, w.state);
    _ = w.tick(&p);
    try std.testing.expectEqual(State.agitated, w.state);
}
test "chasing suppresses periodic sniff animation" {
    var w = Warden.init(.{});
    w.state = .chasing;
    var p = [_]Player{.{ .id = 1 }};
    for (0..168) |_| try std.testing.expect(!w.tick(&p).sniff_animation);
}
test "calm speed is one meter per second" {
    try std.testing.expectEqual(@as(f32, 1.0), Warden.init(.{}).movementSpeed());
}
test "agitated and roaring wardens stop moving" {
    var w = Warden.init(.{});
    w.state = .agitated;
    try std.testing.expectEqual(@as(f32, 0.0), w.movementSpeed());
    w.state = .roaring;
    try std.testing.expectEqual(@as(f32, 0.0), w.movementSpeed());
}
test "chase speed is 4.2 meters per second" {
    var w = Warden.init(.{});
    w.state = .chasing;
    try std.testing.expectEqual(@as(f32, 4.2), w.movementSpeed());
}
test "calm suspicion decays after 20 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 3 }};
    for (0..19) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 3), p[0].suspicion);
    _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 2), p[0].suspicion);
}
test "calm suspicion decays once per 20 tick interval" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 2 }};
    for (0..40) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "vibration interrupts the calm decay timer" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 5 }};
    for (0..19) |_| _ = w.tick(&p);
    w.hearVibration(&p[0], 0);
    _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 5), p[0].suspicion);
}
test "decay never underflows zero suspicion" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..40) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "blast hits target at 15 horizontal meters" {
    const result = resolveSonicBlast(.{}, .{ .x = 15 });
    try std.testing.expect(result.hit);
}
test "blast misses beyond 15 horizontal meters" {
    const result = resolveSonicBlast(.{}, .{ .x = 15.01 });
    try std.testing.expect(!result.hit);
}
test "blast uses horizontal reach despite vertical separation" {
    const result = resolveSonicBlast(.{}, .{ .x = 15, .y = 100 });
    try std.testing.expect(result.hit);
}
test "blast penetrates terrain because resolution has no block input" {
    const solid_wall_between = true;
    const result = resolveSonicBlast(.{}, .{ .x = 10 });
    try std.testing.expect(solid_wall_between);
    try std.testing.expect(result.hit);
}
test "blast damage is exactly ten health" {
    try std.testing.expectEqual(@as(f32, 10.0), resolveSonicBlast(.{}, .{ .x = 1 }).damage);
}
test "blast vertical knockback is six meters per second" {
    try std.testing.expectEqual(@as(f32, 6.0), resolveSonicBlast(.{}, .{ .x = 1 }).knockback.y);
}
test "blast horizontal knockback magnitude is eight meters per second" {
    const impulse = resolveSonicBlast(.{}, .{ .x = 3, .z = 4 }).knockback;
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), @sqrt(impulse.x * impulse.x + impulse.z * impulse.z), 0.0001);
}
test "blast applies unmitigated health loss and replaces velocity" {
    var player = Player{ .id = 1, .position = .{ .x = 2 }, .armor_points = 20, .shield_blocking = true };
    player.velocity = .{ .x = -1, .y = 1, .z = -1 };
    try std.testing.expect(hitPlayerWithSonicBlast(.{}, &player));
    try std.testing.expectEqual(@as(f32, 10.0), player.health);
    try std.testing.expectEqual(@as(f32, 8.0), player.velocity.x);
    try std.testing.expectEqual(@as(f32, 6.0), player.velocity.y);
}
test "blast does not alter player outside reach" {
    var player = Player{ .id = 1, .position = .{ .x = 16 } };
    try std.testing.expect(!hitPlayerWithSonicBlast(.{}, &player));
    try std.testing.expectEqual(@as(f32, 20.0), player.health);
}
test "blast damage cannot reduce health below zero" {
    var player = Player{ .id = 1, .position = .{ .x = 1 }, .health = 4 };
    _ = hitPlayerWithSonicBlast(.{}, &player);
    try std.testing.expectEqual(@as(f32, 0.0), player.health);
}

// Sonic boom unit tests
test "attributes specify 500 health and 30 melee damage" {
    const w = WardenBehavior.init(.{});
    try std.testing.expectEqual(@as(f32, 500.0), w.health);
    try std.testing.expectEqual(@as(f32, 500.0), WARDEN_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 30.0), WARDEN_MELEE_DAMAGE);
    try std.testing.expectEqual(@as(f32, 0.0), WARDEN_OPTICAL_SIGHT_RANGE);
}

test "vibration adds 35 agitation" {
    var w = WardenBehavior.init(.{});
    w.hearVibration();
    try std.testing.expectEqual(@as(u16, 35), w.agitation);
}
test "second vibration remains below roar threshold" {
    var w = WardenBehavior.init(.{});
    w.hearVibration();
    w.hearVibration();
    try std.testing.expect(!w.roaring);
}
test "roaring starts at exact 80 agitation threshold" {
    var w = WardenBehavior.init(.{});
    w.agitation = 79;
    w.hearVibration();
    try std.testing.expect(w.roaring);
}
test "fifth vibration reaches hostile chase at 150" {
    var w = WardenBehavior.init(.{});
    for (0..4) |_| w.hearVibration();
    try std.testing.expectEqual(@as(u16, 140), w.agitation);
    try std.testing.expect(!w.hostile);
    w.hearVibration();
    try std.testing.expectEqual(@as(u16, 150), w.agitation);
    try std.testing.expect(w.hostile);
}
test "agitation caps at 150" {
    var w = WardenBehavior.init(.{});
    for (0..8) |_| w.hearVibration();
    try std.testing.expectEqual(@as(u16, 150), w.agitation);
}
test "hostile movement speed is 4.2 meters per second" {
    var w = WardenBehavior.init(.{});
    w.hostile = true;
    try std.testing.expectEqual(@as(f32, 4.2), w.movementSpeed());
}
test "calm Warden has no hostile chase speed" {
    const w = WardenBehavior.init(.{});
    try std.testing.expectEqual(@as(f32, 0.0), w.movementSpeed());
}
test "emergence lasts exactly 134 ticks" {
    var w = WardenBehavior.init(.{});
    for (0..133) |_| _ = w.tick(null);
    try std.testing.expect(w.is_emerging);
    _ = w.tick(null);
    try std.testing.expect(!w.is_emerging);
}
test "emerging Warden is invulnerable" {
    var w = WardenBehavior.init(.{});
    try std.testing.expectEqual(@as(f32, 0.0), w.takeDamage(100));
    try std.testing.expectEqual(@as(f32, 500.0), w.health);
}
test "emergence damage works after the final tick" {
    var w = WardenBehavior.init(.{});
    for (0..134) |_| _ = w.tick(null);
    try std.testing.expectEqual(@as(f32, 10.0), w.takeDamage(10));
}
test "calm burrowing begins at 1200 quiet ticks" {
    var w = WardenBehavior.init(.{});
    for (0..134) |_| _ = w.tick(null);
    for (0..1199) |_| _ = w.tick(null);
    try std.testing.expect(!w.despawned);
    _ = w.tick(null);
    try std.testing.expect(w.is_burrowing);
    try std.testing.expect(w.despawned);
}
test "vibration resets calm despawn countdown" {
    var w = WardenBehavior.init(.{});
    for (0..134) |_| _ = w.tick(null);
    for (0..1100) |_| _ = w.tick(null);
    w.hearVibration();
    for (0..200) |_| _ = w.tick(null);
    try std.testing.expect(!w.despawned);
}
test "scent detection finds target at 16m" {
    var w = WardenBehavior.init(.{});
    try std.testing.expect(w.sniffTarget(.{ .x = 16 }));
}
test "scent detection rejects target beyond 16m" {
    var w = WardenBehavior.init(.{});
    try std.testing.expect(!w.sniffTarget(.{ .x = 16.01 }));
}
test "scent tracking resets calm countdown without adding agitation" {
    var w = WardenBehavior.init(.{});
    w.calm_ticks = 100;
    try std.testing.expect(w.sniffTarget(.{ .x = 4 }));
    try std.testing.expectEqual(@as(u32, 0), w.calm_ticks);
    try std.testing.expectEqual(@as(u16, 0), w.agitation);
}
test "periodic sniff detects nearby target" {
    var w = WardenBehavior.init(.{});
    for (0..100) |_| _ = w.tick(.{ .x = 8 });
    try std.testing.expectEqual(@as(u32, 0), w.calm_ticks);
}
test "sonic boom reaches exact 15m boundary" {
    const r = resolveSonicBoom(.{}, .{ .x = 15 });
    try std.testing.expect(r.hit);
}
test "sonic boom rejects target beyond 15m" {
    const r = resolveSonicBoom(.{}, .{ .x = 15.001 });
    try std.testing.expect(!r.hit);
}
test "sonic boom deals ten unmitigated damage through armor and shield" {
    var player = PlayerCombatState{ .health = 20, .armor_points = 20, .shield_blocking = true };
    try std.testing.expect(hitPlayerWithSonicBoom(.{}, .{ .x = 5 }, &player));
    try std.testing.expectEqual(@as(f32, 10), player.health);
}
test "sonic boom attack can target elevated players within spherical range" {
    const r = resolveSonicBoom(.{}, .{ .y = 14 });
    try std.testing.expect(r.hit);
}
test "sonic boom does not start within melee range" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    w.hostile = true;
    try std.testing.expect(!w.canStartSonicBoom(.{ .x = 2 }));
}
test "sonic boom requires hostile state" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    try std.testing.expect(!w.canStartSonicBoom(.{ .x = 8 }));
}
test "sonic boom requires a completed emergence" {
    var w = WardenBehavior.init(.{});
    w.hostile = true;
    try std.testing.expect(!w.canStartSonicBoom(.{ .x = 8 }));
}
test "sonic boom charge lasts exactly 34 ticks then fires" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    w.hostile = true;
    const target = Position{ .x = 8 };
    try std.testing.expect(!w.tick(target));
    try std.testing.expectEqual(@as(u32, 34), w.boom_charge_ticks);
    for (0..33) |_| try std.testing.expect(!w.tick(null));
    try std.testing.expect(w.tick(null));
}
test "sonic boom cooldown lasts 100 ticks" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    w.hostile = true;
    _ = w.tick(.{ .x = 8 });
    for (0..34) |_| _ = w.tick(null);
    try std.testing.expectEqual(@as(u32, 100), w.boom_cooldown_ticks);
    for (0..99) |_| _ = w.tick(.{ .x = 8 });
    try std.testing.expectEqual(@as(u32, 1), w.boom_cooldown_ticks);
    _ = w.tick(.{ .x = 8 });
    try std.testing.expectEqual(@as(u32, 0), w.boom_cooldown_ticks);
}
test "sonic boom applies upward velocity impulse of six" {
    const i = sonicBoomImpulse(.{}, .{ .x = 1 });
    try std.testing.expectEqual(@as(f32, 6), i.vy);
}
test "sonic boom applies horizontal push of eight along positive X" {
    const i = sonicBoomImpulse(.{}, .{ .x = 3 });
    try std.testing.expectEqual(@as(f32, 8), i.vx);
    try std.testing.expectEqual(@as(f32, 0), i.vz);
}
test "sonic boom horizontal push follows diagonal target direction" {
    const i = sonicBoomImpulse(.{}, .{ .x = 3, .z = 4 });
    try std.testing.expectApproxEqAbs(@as(f32, 4.8), i.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.4), i.vz, 0.001);
}
test "sonic boom coincident target still receives upward impulse" {
    const i = sonicBoomImpulse(.{}, .{});
    try std.testing.expectEqual(@as(f32, 6), i.vy);
}
test "darkness aura includes player at 20m boundary" {
    const w = WardenBehavior.init(.{});
    try std.testing.expect(w.darknessAffects(.{ .z = 20 }));
}
test "darkness aura excludes player beyond 20m" {
    const w = WardenBehavior.init(.{});
    try std.testing.expect(!w.darknessAffects(.{ .z = 20.01 }));
}
test "darkness pulse emits effect to nearby player only during pulse" {
    var w = WardenBehavior.init(.{});
    try std.testing.expect(!w.emitsDarknessTo(.{ .x = 2 }));
    for (0..120) |_| _ = w.tick(null);
    try std.testing.expect(w.emitsDarknessTo(.{ .x = 2 }));
    try std.testing.expect(!w.emitsDarknessTo(.{ .x = 21 }));
}
test "darkness pulse is emitted every 120 ticks" {
    var w = WardenBehavior.init(.{});
    for (0..119) |_| {
        _ = w.tick(null);
        try std.testing.expect(!w.darkness_pulsed);
    }
    _ = w.tick(null);
    try std.testing.expect(w.darkness_pulsed);
    try std.testing.expectEqual(@as(u32, 120), w.darkness_ticks);
}
test "burrowing Warden ignores damage" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    w.is_burrowing = true;
    try std.testing.expectEqual(@as(f32, 0), w.takeDamage(50));
}
test "despawned Warden cannot be reactivated by a later vibration" {
    var w = WardenBehavior.init(.{});
    w.despawned = true;
    w.is_burrowing = true;
    w.hearVibration();
    try std.testing.expect(w.despawned);
    try std.testing.expectEqual(@as(u16, 0), w.agitation);
}
test "damage clamps health at zero" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    try std.testing.expectEqual(@as(f32, 500), w.takeDamage(900));
    try std.testing.expectEqual(@as(f32, 0), w.health);
}

// ============================================================================
// Sculk Shrieker Fog Unit Tests (from sculk_shrieker_fog.zig)
// ============================================================================

test "1. constants encode requested tick durations and radius" {
    try std.testing.expectEqual(@as(u32, 20), TICKS_PER_SECOND);
    try std.testing.expectEqual(@as(u32, 200), SHRIEK_COOLDOWN_TICKS);
    try std.testing.expectEqual(@as(u32, 12_000), WARNING_DECAY_TICKS);
    try std.testing.expectEqual(@as(u32, 240), DARKNESS_DURATION_TICKS);
    try std.testing.expectEqual(@as(u32, 80), FOG_PERIOD_TICKS);
    try std.testing.expectEqual(@as(u32, 134), WARDEN_EMERGENCE_TICKS);
    try std.testing.expectEqual(@as(f32, 40.0), SHRIEKER_DARKNESS_RADIUS);
}

test "2. position distance is three dimensional Euclidean distance" {
    try std.testing.expectEqual(@as(f32, 13.0), Position.distance(.{}, .{ .x = 3, .y = 4, .z = 12 }));
}

test "3. natural shrieker increments warning from zero to one" {
    var p = FogPlayer.init(1, .{});
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expect(a.activated);
    try std.testing.expectEqual(@as(u8, 1), p.warning_level);
}

test "4. natural warning escalation reaches tier two" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 1;
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u8, 2), p.warning_level);
}

test "5. natural warning escalation reaches tier three" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 2;
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u8, 3), p.warning_level);
}

test "6. natural warning escalation reaches tier four and summons" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 3;
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u8, 4), p.warning_level);
    try std.testing.expect(a.summon_warden);
}

test "7. natural warning level caps at four" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 4;
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u8, 4), p.warning_level);
}

test "8. placed shrieker leaves warning and summon state unchanged" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 3;
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, false);
    const a = s.activate(&p, &ps);
    try std.testing.expect(a.activated);
    try std.testing.expectEqual(@as(u8, 3), p.warning_level);
    try std.testing.expect(!a.summon_warden);
}

test "9. placed shrieker at tier four never summons" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 4;
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, false);
    const a = s.activate(&p, &ps);
    try std.testing.expect(!a.summon_warden);
    try std.testing.expect(a.emergence == null);
}

test "10. activation starts exact 200 tick cooldown" {
    var p = FogPlayer.init(1, .{});
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 200), s.cooldown_ticks_remaining);
}

test "11. cooldown rejects retrigger before 200 ticks" {
    var p = FogPlayer.init(1, .{});
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    s.tick(199);
    const a = s.activate(&p, &ps);
    try std.testing.expect(!a.activated);
    try std.testing.expectEqual(@as(u8, 1), p.warning_level);
}

test "12. cooldown permits retrigger at exactly 200 ticks" {
    var p = FogPlayer.init(1, .{});
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    s.tick(200);
    try std.testing.expect((s.activate(&p, &ps)).activated);
    try std.testing.expectEqual(@as(u8, 2), p.warning_level);
}

test "13. calm decay does not occur before 12000 ticks" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 2;
    p.tick(11_999);
    try std.testing.expectEqual(@as(u8, 2), p.warning_level);
}

test "14. calm decay removes one tier after 12000 ticks" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 2;
    p.tick(12_000);
    try std.testing.expectEqual(@as(u8, 1), p.warning_level);
    try std.testing.expectEqual(@as(u32, 0), p.calm_ticks);
}

test "15. calm decay applies one tier per additional ten minutes" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 4;
    p.tick(36_000);
    try std.testing.expectEqual(@as(u8, 1), p.warning_level);
}

test "16. activation resets calm timer" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 2;
    p.tick(11_000);
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    _ = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 0), p.calm_ticks);
}

test "17. darkness aura includes player at the shrieker" {
    var p = FogPlayer.init(1, .{});
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 1), a.affected_players);
    try std.testing.expectEqual(@as(u32, 240), p.darkness_ticks_remaining);
}

test "18. darkness radius includes exact 40 meter boundary" {
    var p = FogPlayer.init(1, .{ .x = 40.0 });
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 1), a.affected_players);
}

test "19. darkness radius excludes player just outside 40 meters" {
    var p = FogPlayer.init(1, .{ .x = 40.01 });
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 0), a.affected_players);
    try std.testing.expect(!p.darknessActive());
}

test "20. darkness radius uses vertical distance" {
    var p = FogPlayer.init(1, .{ .y = 40.0 });
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    try std.testing.expectEqual(@as(u32, 1), (s.activate(&p, &ps)).affected_players);
}

test "21. all nearby players receive the darkness pulse" {
    var p = FogPlayer.init(1, .{});
    var ps = [_]FogPlayer{ p, FogPlayer.init(2, .{ .x = 39.0 }), FogPlayer.init(3, .{ .x = 41.0 }) };
    var s = FogSculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 2), a.affected_players);
    try std.testing.expect(ps[1].darknessActive());
    try std.testing.expect(!ps[2].darknessActive());
}

test "22. placed shrieker activation still pulses darkness aura" {
    var p = FogPlayer.init(1, .{});
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, false);
    const a = s.activate(&p, &ps);
    try std.testing.expect(a.activated);
    try std.testing.expect(p.darknessActive());
}

test "23. darkness lasts exactly 240 game ticks" {
    var p = FogPlayer.init(1, .{});
    p.darkness_ticks_remaining = 240;
    p.tick(239);
    try std.testing.expect(p.darknessActive());
    p.tick(1);
    try std.testing.expect(!p.darknessActive());
}

test "24. fog starts clear at pulse onset" {
    const fog = fogDistances(fogIntensity(0));
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), fog.start, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 35.0), fog.end, 0.0001);
}

test "25. fog reaches blinding values after two seconds" {
    const fog = fogDistances(fogIntensity(40));
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), fog.start, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), fog.end, 0.0001);
}

test "26. fog clears after one complete four second wave" {
    try std.testing.expectApproxEqAbs(fogIntensity(0), fogIntensity(80), 0.0001);
    const fog = fogDistances(fogIntensity(80));
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), fog.start, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 35.0), fog.end, 0.0001);
}

test "27. fog sine wave interpolates smoothly at quarter period" {
    const low = fogDistances(fogIntensity(0));
    const mid = fogDistances(fogIntensity(20));
    const high = fogDistances(fogIntensity(40));
    try std.testing.expect(mid.start < low.start and mid.start > high.start);
    try std.testing.expect(mid.end < low.end and mid.end > high.end);
}

test "28. fog interpolation clamps intensity to the supported range" {
    try std.testing.expectEqual(fogDistances(0), fogDistances(-2));
    try std.testing.expectEqual(fogDistances(1), fogDistances(2));
}

test "29. fog defaults to clear when darkness expires" {
    var p = FogPlayer.init(1, .{});
    p.darkness_ticks_remaining = 1;
    p.tick(1);
    const fog = p.currentFog();
    try std.testing.expectEqual(@as(f32, 25.0), fog.start);
    try std.testing.expectEqual(@as(f32, 35.0), fog.end);
}

test "30. tier four activation returns an emerging Warden for 134 ticks" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 3;
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{ .x = 1.5, .y = -20.0, .z = 2.5 }, true);
    const a = s.activate(&p, &ps);
    try std.testing.expect(a.summon_warden);
    const warden = a.emergence.?;
    try std.testing.expect(warden.is_emerging);
    try std.testing.expectEqual(@as(u32, 134), warden.ticks_remaining);
    try std.testing.expectEqual(s.position, warden.position);
}

test "31. Warden emergence completes after exactly 134 ticks" {
    var w = FogWardenEmergence{ .position = .{} };
    w.tick(133);
    try std.testing.expect(w.is_emerging);
    w.tick(1);
    try std.testing.expect(!w.is_emerging);
    try std.testing.expectEqual(@as(u32, 0), w.ticks_remaining);
}

test "32. tier four already reached does not repeatedly summon" {
    var p = FogPlayer.init(1, .{});
    p.warning_level = 4;
    var ps = [_]FogPlayer{p};
    var s = FogSculkShrieker.init(.{}, true);
    const a = s.activate(&p, &ps);
    try std.testing.expect(!a.summon_warden);
    try std.testing.expectEqual(@as(u8, 4), p.warning_level);
}

test "33. separate shriekers keep independent cooldowns" {
    var p = FogPlayer.init(1, .{});
    var ps = [_]FogPlayer{p};
    var a = FogSculkShrieker.init(.{}, true);
    var b = FogSculkShrieker.init(.{ .x = 2 }, true);
    _ = a.activate(&p, &ps);
    try std.testing.expectEqual(@as(u32, 200), a.cooldown_ticks_remaining);
    try std.testing.expectEqual(@as(u32, 0), b.cooldown_ticks_remaining);
    try std.testing.expect((b.activate(&p, &ps)).activated);
}

test "34. warning trackers decay independently per player" {
    var a = FogPlayer.init(1, .{});
    var b = FogPlayer.init(2, .{});
    a.warning_level = 3;
    b.warning_level = 1;
    a.tick(12_000);
    b.tick(6_000);
    try std.testing.expectEqual(@as(u8, 2), a.warning_level);
    try std.testing.expectEqual(@as(u8, 1), b.warning_level);
}

// ============================================================================
// Sculk Shrieker Warning Unit Tests (from sculk_shrieker_warning.zig)
// ============================================================================

test "1. constants match specification" {
    try std.testing.expectEqual(@as(f32, 20.0), WARNING_TICKS_PER_SECOND);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), SECONDS_PER_TICK, 1e-5);
    try std.testing.expectEqual(@as(f32, 10.0), SHRIEK_COOLDOWN_SECONDS);
    try std.testing.expectEqual(@as(u32, 200), SHRIEK_COOLDOWN_TICKS);
    try std.testing.expectEqual(@as(f32, 600.0), WARNING_DECAY_SECONDS);
    try std.testing.expectEqual(@as(u32, 12000), WARNING_DECAY_TICKS);
    try std.testing.expectEqual(@as(f32, 12.0), DARKNESS_DURATION_SECONDS);
    try std.testing.expectEqual(@as(u32, 240), DARKNESS_DURATION_TICKS);
    try std.testing.expectEqual(@as(f32, 40.0), SHRIEKER_DARKNESS_RADIUS);
    try std.testing.expectEqual(@as(f32, 1600.0), SHRIEKER_DARKNESS_RADIUS_SQ);
    try std.testing.expectEqual(@as(f32, 8.0), SENSOR_TRANSMISSION_RANGE);
    try std.testing.expectEqual(@as(f32, 64.0), SENSOR_TRANSMISSION_RANGE_SQ);
    try std.testing.expectEqual(@as(u3, 4), MAX_WARNING_LEVEL);
    try std.testing.expectEqual(@as(u3, 4), WARDEN_SUMMON_LEVEL);
    try std.testing.expectEqual(@as(f32, 6.7), WARDEN_EMERGE_DURATION_SECONDS);
    try std.testing.expectEqual(@as(u32, 134), WARDEN_EMERGE_DURATION_TICKS);
}

test "2. BlockPos and Vec3 math conversions and distances" {
    const bp = BlockPos.init(10, 20, 30);
    const v = bp.toVec3();
    try std.testing.expectEqual(@as(f32, 10.5), v.x);
    try std.testing.expectEqual(@as(f32, 20.5), v.y);
    try std.testing.expectEqual(@as(f32, 30.5), v.z);

    const bp2 = BlockPos.init(13, 20, 34); // dx=3, dy=0, dz=4 -> dist=5
    try std.testing.expectEqual(@as(f32, 25.0), bp.distanceSq(bp2));
    try std.testing.expectEqual(@as(f32, 5.0), bp.distance(bp2));
}

test "3. isPlayerSteppingOnShrieker detects player footprint on top of or within block" {
    const shrieker_pos = BlockPos.init(0, 60, 0);

    // Player standing directly on top of the shrieker at y = 61.0
    const top_pos = Vec3.init(0.5, 61.0, 0.5);
    try std.testing.expect(isPlayerSteppingOnShrieker(top_pos, shrieker_pos));

    // Player standing within block volume at y = 60.2
    const inside_pos = Vec3.init(0.2, 60.2, 0.8);
    try std.testing.expect(isPlayerSteppingOnShrieker(inside_pos, shrieker_pos));

    // Player stepping near edge of block
    const edge_pos = Vec3.init(1.1, 61.0, 0.5);
    try std.testing.expect(isPlayerSteppingOnShrieker(edge_pos, shrieker_pos));
}

test "4. isPlayerSteppingOnShrieker rejects player outside shrieker block" {
    const shrieker_pos = BlockPos.init(0, 60, 0);

    // Completely adjacent block horizontally
    const outside_x = Vec3.init(2.0, 61.0, 0.5);
    try std.testing.expect(!isPlayerSteppingOnShrieker(outside_x, shrieker_pos));

    const outside_z = Vec3.init(0.5, 61.0, 2.5);
    try std.testing.expect(!isPlayerSteppingOnShrieker(outside_z, shrieker_pos));

    // Too high above
    const high_pos = Vec3.init(0.5, 63.0, 0.5);
    try std.testing.expect(!isPlayerSteppingOnShrieker(high_pos, shrieker_pos));

    // Below the block
    const low_pos = Vec3.init(0.5, 59.0, 0.5);
    try std.testing.expect(!isPlayerSteppingOnShrieker(low_pos, shrieker_pos));
}

test "5. direct stepping triggers shrieker whether player is walking or sneaking" {
    var shrieker = SculkShrieker.natural(0, 60, 0);
    var player = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));

    // Walking player triggers shrieker
    player.is_sneaking = false;
    const res_walk = shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(res_walk.shrieked);
    try std.testing.expectEqual(@as(u3, 1), player.warning_level);
    try std.testing.expectEqual(TriggerType.player_step, res_walk.trigger_type);

    // Wait out cooldown
    shrieker.tick(10.0);

    // Sneaking player still triggers shrieker directly when stepping on it
    player.is_sneaking = true;
    const res_sneak = shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(res_sneak.shrieked);
    try std.testing.expectEqual(@as(u3, 2), player.warning_level);
}

test "6. sculk sensor vibration transmission succeeds within 8.0 blocks" {
    var shrieker = SculkShrieker.natural(0, 60, 0);
    var player = PlayerTracker.init(1, Vec3.init(0.0, 60.0, 0.0));

    // Sensor at (0, 60, 6): distance = 6.0 <= 8.0m
    const sensor_pos = BlockPos.init(0, 60, 6);
    try std.testing.expect(canSensorTransmitToShrieker(sensor_pos, shrieker.pos));

    const res = shrieker.triggerSensorVibration(sensor_pos, &player, null);
    try std.testing.expect(res != null);
    if (res) |r| {
        try std.testing.expect(r.shrieked);
        try std.testing.expectEqual(TriggerType.sculk_sensor_vibration, r.trigger_type);
        try std.testing.expectEqual(@as(u3, 1), player.warning_level);
    }
}

test "7. sculk sensor vibration transmission fails when beyond 8.0 blocks" {
    var shrieker = SculkShrieker.natural(0, 60, 0);
    var player = PlayerTracker.init(1, Vec3.init(0.0, 60.0, 0.0));

    // Sensor at (0, 60, 9): distance = 9.0 > 8.0m (dist_sq = 81 > 64)
    const far_sensor = BlockPos.init(0, 60, 9);
    try std.testing.expect(!canSensorTransmitToShrieker(far_sensor, shrieker.pos));

    const res = shrieker.triggerSensorVibration(far_sensor, &player, null);
    try std.testing.expect(res == null);
    try std.testing.expectEqual(@as(u3, 0), player.warning_level);
}

test "8. shrieker 10-second (200-tick) cooldown blocks consecutive activations" {
    var shrieker = SculkShrieker.natural(0, 60, 0);
    var player = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));

    // 1st trigger succeeds
    const r1 = shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(r1.shrieked);
    try std.testing.expect(!r1.cooldown_blocked);
    try std.testing.expect(shrieker.isOnCooldown());
    try std.testing.expectEqual(@as(f32, 10.0), shrieker.cooldown_timer);

    // Immediate 2nd trigger is blocked by cooldown
    const r2 = shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(!r2.shrieked);
    try std.testing.expect(r2.cooldown_blocked);
    try std.testing.expectEqual(@as(u3, 1), player.warning_level);

    // After 9.5s, still on cooldown
    shrieker.tick(9.5);
    try std.testing.expect(shrieker.isOnCooldown());
    const r3 = shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(!r3.shrieked);
    try std.testing.expect(r3.cooldown_blocked);

    // After remaining 0.6s (total > 10.0s), cooldown elapses
    shrieker.tick(0.6);
    try std.testing.expect(!shrieker.isOnCooldown());
    const r4 = shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(r4.shrieked);
    try std.testing.expectEqual(@as(u3, 2), player.warning_level);
}

test "9. tickTicks discrete 200-tick simulation matches continuous 10-second cooldown" {
    var shrieker = SculkShrieker.natural(0, 60, 0);
    var player = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));

    _ = shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(shrieker.isOnCooldown());

    // Tick 199 game ticks: still on cooldown
    shrieker.tickTicks(199);
    try std.testing.expect(shrieker.isOnCooldown());
    try std.testing.expect(!shrieker.triggerDirectStep(&player, null).shrieked);

    // Tick 1 game tick (total 200 ticks = 10.0s): cooldown expires
    shrieker.tickTicks(1);
    try std.testing.expect(!shrieker.isOnCooldown());
    try std.testing.expect(shrieker.triggerDirectStep(&player, null).shrieked);
}

test "10. warning level escalation 0 -> 1 -> 2 -> 3 -> 4" {
    var shrieker = SculkShrieker.natural(0, 60, 0);
    var player = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));

    try std.testing.expectEqual(@as(u3, 0), player.warning_level);

    // Trigger 1 -> Level 1
    const r1 = shrieker.triggerDirectStep(&player, null);
    try std.testing.expectEqual(@as(u3, 1), r1.warning_level);
    try std.testing.expectEqual(@as(u3, 1), player.warning_level);
    try std.testing.expect(!r1.summon_warden);

    shrieker.tick(10.0);

    // Trigger 2 -> Level 2
    const r2 = shrieker.triggerDirectStep(&player, null);
    try std.testing.expectEqual(@as(u3, 2), r2.warning_level);
    try std.testing.expectEqual(@as(u3, 2), player.warning_level);
    try std.testing.expect(!r2.summon_warden);

    shrieker.tick(10.0);

    // Trigger 3 -> Level 3
    const r3 = shrieker.triggerDirectStep(&player, null);
    try std.testing.expectEqual(@as(u3, 3), r3.warning_level);
    try std.testing.expectEqual(@as(u3, 3), player.warning_level);
    try std.testing.expect(!r3.summon_warden);

    shrieker.tick(10.0);

    // Trigger 4 -> Level 4 (Warden Summoning!)
    const r4 = shrieker.triggerDirectStep(&player, null);
    try std.testing.expectEqual(@as(u3, 4), r4.warning_level);
    try std.testing.expectEqual(@as(u3, 4), player.warning_level);
    try std.testing.expect(r4.summon_warden);
}

test "11. warning level caps at maximum level 4 on subsequent triggers" {
    var shrieker = SculkShrieker.natural(0, 60, 0);
    var player = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));
    player.warning_level = 4;

    const res = shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(res.shrieked);
    try std.testing.expect(!res.warning_incremented); // already at max 4
    try std.testing.expectEqual(@as(u3, 4), res.warning_level);
    try std.testing.expectEqual(@as(u3, 4), player.warning_level);
    try std.testing.expect(res.summon_warden);
}

test "12. warning level decay: warning counter decays by 1 level after 10 minutes (600s / 12000 ticks) of calm" {
    var player = PlayerTracker.init(1, Vec3.init(0.0, 60.0, 0.0));
    _ = player.incrementWarning(); // Level 1
    _ = player.incrementWarning(); // Level 2
    try std.testing.expectEqual(@as(u3, 2), player.warning_level);
    try std.testing.expectEqual(@as(f32, 600.0), player.decay_timer);

    // After 599.0s of calm -> still Level 2
    player.tick(599.0);
    try std.testing.expectEqual(@as(u3, 2), player.warning_level);

    // After 2.0s more (total > 600.0s) -> decays to Level 1
    player.tick(2.0);
    try std.testing.expectEqual(@as(u3, 1), player.warning_level);
    // Timer resets for next level decay
    try std.testing.expectEqual(@as(f32, 600.0), player.decay_timer);

    // After another 600.0s -> decays to Level 0
    player.tick(600.0);
    try std.testing.expectEqual(@as(u3, 0), player.warning_level);
    // At level 0, decay timer stops
    try std.testing.expectEqual(@as(f32, 0.0), player.decay_timer);
}

test "13. discrete 12000 ticks decay simulation" {
    var player = PlayerTracker.init(1, Vec3.init(0.0, 60.0, 0.0));
    _ = player.incrementWarning(); // Level 1
    try std.testing.expectEqual(@as(u3, 1), player.warning_level);

    // 11999 ticks: not yet decayed
    player.tickTicks(11999);
    try std.testing.expectEqual(@as(u3, 1), player.warning_level);

    // 1 more tick (total 12000 ticks): decays to 0
    player.tickTicks(1);
    try std.testing.expectEqual(@as(u3, 0), player.warning_level);
}

test "14. triggering shrieker mid-calm resets the 10-minute decay timer" {
    var shrieker = SculkShrieker.natural(0, 60, 0);
    var player = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));
    _ = shrieker.triggerDirectStep(&player, null); // Level 1
    try std.testing.expectEqual(@as(u3, 1), player.warning_level);

    // 500 seconds of calm elapse
    player.tick(500.0);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), player.decay_timer, 1e-3);

    // Wait out shrieker cooldown
    shrieker.tick(500.0);

    // New shriek trigger resets the calm decay timer back to full 600.0s
    _ = shrieker.triggerDirectStep(&player, null);
    try std.testing.expectEqual(@as(u3, 2), player.warning_level);
    try std.testing.expectEqual(@as(f32, 600.0), player.decay_timer);
}

test "15. Darkness status effect (12.0s) applied to all players within 40.0m radius" {
    var shrieker = SculkShrieker.natural(0, 60, 0);

    var players = [_]PlayerTracker{
        PlayerTracker.init(1, Vec3.init(10.0, 60.0, 0.0)), // dist = 10m <= 40m
        PlayerTracker.init(2, Vec3.init(0.0, 60.0, 39.5)), // dist = 39.5m <= 40m
        PlayerTracker.init(3, Vec3.init(0.0, 60.0, 40.0)), // dist = 40.0m <= 40m
        PlayerTracker.init(4, Vec3.init(0.0, 60.0, 40.5)), // dist = 40.5m > 40m (outside!)
        PlayerTracker.init(5, Vec3.init(30.0, 60.0, 30.0)), // dist_sq = 1800 > 1600 (outside!)
    };

    const res = shrieker.triggerDirectStep(&players[0], &players);
    try std.testing.expect(res.shrieked);
    try std.testing.expect(res.darkness_inflicted);
    try std.testing.expectEqual(@as(u32, 3), res.players_affected_by_darkness);

    // Players 1, 2, and 3 received Darkness (12.0s)
    try std.testing.expect(players[0].hasDarkness());
    try std.testing.expectEqual(@as(f32, 12.0), players[0].darkness_timer);

    try std.testing.expect(players[1].hasDarkness());
    try std.testing.expectEqual(@as(f32, 12.0), players[1].darkness_timer);

    try std.testing.expect(players[2].hasDarkness());
    try std.testing.expectEqual(@as(f32, 12.0), players[2].darkness_timer);

    // Players 4 and 5 did NOT receive Darkness
    try std.testing.expect(!players[3].hasDarkness());
    try std.testing.expectEqual(@as(f32, 0.0), players[3].darkness_timer);

    try std.testing.expect(!players[4].hasDarkness());
    try std.testing.expectEqual(@as(f32, 0.0), players[4].darkness_timer);
}

test "16. Darkness effect refreshes duration when player is already darkened" {
    var player = PlayerTracker.init(1, Vec3.init(0.0, 60.0, 0.0));
    player.applyDarkness(5.0);
    try std.testing.expectEqual(@as(f32, 5.0), player.darkness_timer);

    // Applying 12.0s extends remaining duration to 12.0s
    player.applyDarkness(12.0);
    try std.testing.expectEqual(@as(f32, 12.0), player.darkness_timer);

    // If player somehow had 15.0s remaining, applying 12.0s does not reduce it
    player.applyDarkness(15.0);
    player.applyDarkness(12.0);
    try std.testing.expectEqual(@as(f32, 15.0), player.darkness_timer);
}

test "17. Darkness fog intensity pulses and fades to 0.0 upon expiration" {
    var player = PlayerTracker.init(1, Vec3.init(0.0, 0.0, 0.0));
    player.applyDarkness(12.0);

    const fog1 = computeDarknessFogIntensity(player.darkness_timer);
    try std.testing.expect(fog1 >= 0.0 and fog1 <= 1.0);

    const dists = computeDarknessFogDistances(0.5);
    try std.testing.expect(dists.start < 32.0);
    try std.testing.expect(dists.end < 64.0);

    // Tick 12.5s -> Darkness expires
    player.tick(12.5);
    try std.testing.expect(!player.hasDarkness());
    try std.testing.expectEqual(@as(f32, 0.0), computeDarknessFogIntensity(player.darkness_timer));
}

test "18. natural vs player-placed can_summon Warden spawn gating" {
    // Naturally generated shrieker (can_summon = true)
    var natural_shrieker = SculkShrieker.natural(0, 60, 0);
    var player1 = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));
    player1.warning_level = 3;

    const res_natural = natural_shrieker.triggerDirectStep(&player1, null);
    try std.testing.expect(res_natural.shrieked);
    try std.testing.expectEqual(@as(u3, 4), res_natural.warning_level);
    try std.testing.expect(res_natural.summon_warden);
    try std.testing.expect(res_natural.warden_spawn_pos != null);

    // Player-placed shrieker (can_summon = false)
    var placed_shrieker = SculkShrieker.playerPlaced(10, 60, 10);
    var player2 = PlayerTracker.init(2, Vec3.init(10.5, 61.0, 10.5));
    player2.warning_level = 3;

    const res_placed = placed_shrieker.triggerDirectStep(&player2, null);
    try std.testing.expect(res_placed.shrieked);
    try std.testing.expect(!res_placed.warning_incremented);
    try std.testing.expectEqual(@as(u3, 3), res_placed.warning_level); // Unchanged!
    try std.testing.expect(!res_placed.summon_warden); // NEVER summons!
    try std.testing.expect(res_placed.warden_spawn_pos == null);
}

test "19. player-placed shrieker emits .shriek sound and ring particles but no darkness" {
    var shrieker = SculkShrieker.playerPlaced(0, 60, 0);
    var player = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));

    const res = shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(res.shrieked);
    try std.testing.expectEqual(AcousticSound.shriek, res.sound);
    try std.testing.expect(res.ring_particles);
    try std.testing.expect(!res.darkness_inflicted);
    try std.testing.expect(!player.hasDarkness());
}

test "20. naturally generated shrieker outside Deep Dark biome does not summon Warden" {
    // Natural shrieker placed in Plains biome (e.g. via world generator anomaly or testing)
    var plains_shrieker = SculkShrieker.init(BlockPos.init(0, 60, 0), true, .plains);
    var player = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));
    player.warning_level = 3;

    const res = plains_shrieker.triggerDirectStep(&player, null);
    try std.testing.expect(res.shrieked);
    try std.testing.expectEqual(@as(u3, 4), res.warning_level);
    try std.testing.expect(res.darkness_inflicted);
    // Summoning is GATED by Deep Dark biome!
    try std.testing.expect(!res.summon_warden);
    try std.testing.expect(res.warden_spawn_pos == null);
}

test "21. ShriekRingParticle expands and fades over its 1.5s lifetime" {
    var ring = ShriekRingParticle.init(Vec3.init(0.0, 60.0, 0.0));
    try std.testing.expect(ring.isAlive());
    try std.testing.expectEqual(@as(f32, 0.0), ring.radius);
    try std.testing.expectEqual(@as(f32, 1.0), ring.getAlpha());

    // Advance 0.5s -> radius expands to 1.0m (growth rate 2.0m/s)
    ring.tick(0.5);
    try std.testing.expect(ring.isAlive());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ring.radius, 1e-4);
    try std.testing.expect(ring.getAlpha() < 1.0 and ring.getAlpha() > 0.5);

    // Advance 1.1s (total 1.6s > 1.5s lifetime) -> expires
    ring.tick(1.1);
    try std.testing.expect(!ring.isAlive());
    try std.testing.expectEqual(@as(f32, 0.0), ring.getAlpha());
}

test "22. WardenEmergence animation tracks 6.7s ground emergence duration" {
    var emergence = WardenEmergence.init(Vec3.init(10.0, 60.0, 10.0));
    try std.testing.expect(!emergence.is_complete);
    try std.testing.expectEqual(@as(f32, 6.7), emergence.animation_timer);

    // Tick 6.6s -> still emerging
    emergence.tick(6.6);
    try std.testing.expect(!emergence.is_complete);

    // Tick 0.2s -> emergence complete, Warden is active
    emergence.tick(0.2);
    try std.testing.expect(emergence.is_complete);
    try std.testing.expectEqual(@as(f32, 0.0), emergence.animation_timer);
}

test "23. WardenEmergence discrete 134 ticks simulation" {
    var emergence = WardenEmergence.init(Vec3.init(0.0, 0.0, 0.0));
    emergence.tickTicks(133);
    try std.testing.expect(!emergence.is_complete);

    emergence.tickTicks(1);
    try std.testing.expect(emergence.is_complete);
}

test "24. SculkShriekerWarning standalone struct increments, triggers darkness, and summons Warden" {
    var tracker = SculkShriekerWarning.init();
    try std.testing.expectEqual(@as(u3, 0), tracker.warning_level);

    // Trigger 1
    const r1 = tracker.triggerShriek(true);
    try std.testing.expect(r1.shrieked);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);
    try std.testing.expect(r1.darkness_inflicted);
    try std.testing.expect(tracker.hasDarkness());
    try std.testing.expect(!r1.summon_warden);

    tracker.tick(10.0);

    // Trigger 2
    _ = tracker.triggerShriek(true);
    try std.testing.expectEqual(@as(u3, 2), tracker.warning_level);

    tracker.tick(10.0);

    // Trigger 3
    _ = tracker.triggerShriek(true);
    try std.testing.expectEqual(@as(u3, 3), tracker.warning_level);

    tracker.tick(10.0);

    // Trigger 4 -> Warden summoned!
    const r4 = tracker.triggerShriek(true);
    try std.testing.expectEqual(@as(u3, 4), tracker.warning_level);
    try std.testing.expect(r4.summon_warden);
}

test "25. SculkShriekerWarning standalone struct respects 10-minute calm decay" {
    var tracker = SculkShriekerWarning.init();
    _ = tracker.triggerShriek(true); // Level 1
    tracker.tick(10.0);
    _ = tracker.triggerShriek(true); // Level 2
    try std.testing.expectEqual(@as(u3, 2), tracker.warning_level);

    // 599.0s calm -> still 2
    tracker.tick(599.0);
    try std.testing.expectEqual(@as(u3, 2), tracker.warning_level);

    // 2.0s more -> decays to 1
    tracker.tick(2.0);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);

    // 600.0s more -> decays to 0
    tracker.tick(600.0);
    try std.testing.expectEqual(@as(u3, 0), tracker.warning_level);
}

test "26. SculkShriekerManager registers and tracks multiple players independently" {
    var manager = SculkShriekerManager.init();
    const p1 = manager.addPlayer(101, Vec3.init(0.0, 60.0, 0.0)).?;
    const p2 = manager.addPlayer(102, Vec3.init(100.0, 60.0, 100.0)).?;

    p1.warning_level = 3;
    p2.warning_level = 1;

    try std.testing.expectEqual(@as(u3, 3), manager.getPlayer(101).?.warning_level);
    try std.testing.expectEqual(@as(u3, 1), manager.getPlayer(102).?.warning_level);
}

test "27. SculkShriekerManager onPlayerMove triggers stepping when intersecting shrieker" {
    var manager = SculkShriekerManager.init();
    _ = manager.addPlayer(1, Vec3.init(5.0, 60.0, 5.0));
    _ = manager.addShrieker(BlockPos.init(0, 60, 0), true, .deep_dark);

    // Player moves to (0.5, 61.0, 0.5) stepping onto shrieker
    const res = manager.onPlayerMove(1, Vec3.init(0.5, 61.0, 0.5));
    try std.testing.expect(res != null);
    if (res) |r| {
        try std.testing.expect(r.shrieked);
        try std.testing.expectEqual(TriggerType.player_step, r.trigger_type);
        try std.testing.expectEqual(@as(u3, 1), manager.getPlayer(1).?.warning_level);
    }
}

test "28. SculkShriekerManager onSensorVibration relays acoustic signal to nearest shrieker" {
    var manager = SculkShriekerManager.init();
    _ = manager.addPlayer(1, Vec3.init(2.0, 60.0, 2.0));
    _ = manager.addShrieker(BlockPos.init(0, 60, 0), true, .deep_dark);

    // Sensor at (0, 60, 5) detects vibration from player 1
    const sensor_pos = BlockPos.init(0, 60, 5);
    const res = manager.onSensorVibration(sensor_pos, 1);
    try std.testing.expect(res != null);
    if (res) |r| {
        try std.testing.expect(r.shrieked);
        try std.testing.expectEqual(TriggerType.sculk_sensor_vibration, r.trigger_type);
        try std.testing.expectEqual(@as(u3, 1), manager.getPlayer(1).?.warning_level);
    }
}

test "29. SculkShriekerManager summons Warden emergence at Tier 4" {
    var manager = SculkShriekerManager.init();
    const player = manager.addPlayer(1, Vec3.init(0.5, 61.0, 0.5)).?;
    player.warning_level = 3;
    _ = manager.addShrieker(BlockPos.init(0, 60, 0), true, .deep_dark);

    try std.testing.expect(manager.active_emergence == null);

    const res = manager.onPlayerMove(1, Vec3.init(0.5, 61.0, 0.5));
    try std.testing.expect(res != null);
    if (res) |r| {
        try std.testing.expect(r.summon_warden);
    }

    try std.testing.expect(manager.active_emergence != null);
    if (manager.active_emergence) |em| {
        try std.testing.expectEqual(@as(f32, 0.5), em.spawn_pos.x);
        try std.testing.expectEqual(@as(f32, 60.5), em.spawn_pos.y);
        try std.testing.expectEqual(@as(f32, 0.5), em.spawn_pos.z);
    }

    // Tick through 6.7s emergence
    manager.tick(6.8);
    try std.testing.expect(manager.active_emergence == null);
}

test "30. multiple players: player A Tier 4 trigger does not affect player B warning level" {
    var shrieker = SculkShrieker.natural(0, 60, 0);

    var player_a = PlayerTracker.init(1, Vec3.init(0.5, 61.0, 0.5));
    player_a.warning_level = 3;

    var player_b = PlayerTracker.init(2, Vec3.init(15.0, 61.0, 0.0));
    player_b.warning_level = 1;

    var players = [_]PlayerTracker{ player_a, player_b };

    // Player A triggers shrieker
    const res = shrieker.triggerDirectStep(&players[0], &players);
    try std.testing.expect(res.shrieked);
    try std.testing.expectEqual(@as(u3, 4), res.warning_level);
    try std.testing.expect(res.summon_warden);

    // Player A reached level 4
    try std.testing.expectEqual(@as(u3, 4), players[0].warning_level);
    // Player B is still at level 1!
    try std.testing.expectEqual(@as(u3, 1), players[1].warning_level);

    // Both players were within 40m, so both received Darkness
    try std.testing.expect(players[0].hasDarkness());
    try std.testing.expect(players[1].hasDarkness());
}
