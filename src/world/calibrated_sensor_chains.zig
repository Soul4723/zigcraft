const std = @import("std");

// ============================================================================
// Milestone 523: Calibrated Sculk Sensor Resonance Chains & Frequency Redstone
// ============================================================================
//
// Calibrated Sculk Sensors (Minecraft 1.20+) are advanced redstone components
// crafted from a Sculk Sensor and 3 Amethyst Shards.
//
// Key Specifications & Mechanics:
// 1. Rear Input Calibration & Frequency Filtering (1..15):
//    - The calibration input face (located directly behind the sensor opposite
//      its facing direction) reads redstone signal strength S in [0, 15].
//    - Signal 0: The sensor is uncalibrated / disabled and rejects ALL vibrations.
//    - Signal S in [1, 15]: Accepts ONLY vibrations whose canonical frequency
//      matches S! Any frequency != S is rejected.
//    - Detection range is 16 blocks (2x the 8-block range of ordinary sculk sensors).
//    - Timing cycle: 10 game ticks (0.50s) active pulse outputting frequency S,
//      followed by 1 game tick (0.05s) recovery cooldown (total 11 ticks / 0.55s).
//
// 2. Amethyst Block Acoustic Resonance Chains:
//    - An Amethyst Block placed adjacent (face-sharing, 6 cardinal directions)
//      to a calibrated sculk sensor resonates upon vibration detection.
//    - The resonating Amethyst Block re-emits an acoustic vibration of the
//      identical canonical frequency up to 16 blocks away.
//    - Multi-hop repeater chains: allows transmitting silent vibration signals
//      across vast distances without redstone wire delay!
//
// ============================================================================

// ============================================================================
// 1. Constants & Timing
// ============================================================================

/// Number of game simulation ticks per second.
pub const TICKS_PER_SECOND: u32 = 20;

/// Duration of a single game tick in seconds (1/20s = 0.05s).
pub const TICK_DURATION_SECONDS: f32 = 0.05;

/// Detection radius of a Calibrated Sculk Sensor in blocks (16.0m).
pub const CALIBRATED_SENSOR_RANGE: f32 = 16.0;

/// Squared detection radius of a Calibrated Sculk Sensor (16^2 = 256.0).
pub const CALIBRATED_SENSOR_RANGE_SQ: f32 = 256.0;

/// Detection radius of an ordinary Sculk Sensor in blocks (8.0m).
pub const ORDINARY_SCULK_RANGE: f32 = 8.0;

/// Squared detection radius of an ordinary Sculk Sensor (8^2 = 64.0).
pub const ORDINARY_SCULK_RANGE_SQ: f32 = 64.0;

/// Transmission radius of an Amethyst Block acoustic resonance in blocks (16.0m).
pub const AMETHYST_RESONANCE_RANGE: f32 = 16.0;

/// Squared transmission radius of Amethyst Block resonance (16^2 = 256.0).
pub const AMETHYST_RESONANCE_RANGE_SQ: f32 = 256.0;

/// Active pulse duration in game ticks (10 ticks = 0.50s).
pub const ACTIVE_DURATION_TICKS: u32 = 10;

/// Active pulse duration in seconds (0.50s).
pub const ACTIVE_DURATION_SECONDS: f32 = 0.50;

/// Post-active recovery cooldown duration in game ticks (1 tick = 0.05s).
pub const RECOVERY_DURATION_TICKS: u32 = 1;

/// Post-active recovery cooldown duration in seconds (0.05s).
pub const RECOVERY_DURATION_SECONDS: f32 = 0.05;

/// Total cycle duration from activation to idle readiness in game ticks (10 + 1 = 11 ticks).
pub const TOTAL_CYCLE_TICKS: u32 = 11;

/// Total cycle duration from activation to idle readiness in seconds (0.55s).
pub const TOTAL_CYCLE_SECONDS: f32 = 0.55;

/// Minimum valid vibration frequency (1).
pub const MIN_FREQUENCY: u4 = 1;

/// Maximum valid vibration frequency (15).
pub const MAX_FREQUENCY: u4 = 15;

/// Maximum number of sensors in a chain network.
pub const MAX_CHAIN_SENSORS: usize = 64;

/// Maximum number of amethyst blocks in a chain network.
pub const MAX_CHAIN_AMETHYST: usize = 64;

/// Maximum depth of acoustic resonance propagation chain.
pub const MAX_RESONANCE_HOPS: u32 = 32;

// ============================================================================
// 2. Vibration Frequency Table & Events (1..15)
// ============================================================================

/// Canonical Minecraft 1.20+ Vibration Frequency Table (1..15).
pub const VibrationFrequency = enum(u4) {
    movement = 1,
    flap = 2,
    swim = 3,
    glide = 4,
    projectile_land = 5,
    splash = 6,
    projectile_shoot = 7,
    damage_hurt = 8,
    entity_equip = 9,
    entity_interact = 10,
    block_change = 11,
    block_destroy = 12,
    block_place = 13,
    entity_teleport = 14,
    death_explosion = 15,

    /// Returns the integer frequency (1..15).
    pub fn toFrequency(self: VibrationFrequency) u4 {
        return @intFromEnum(self);
    }

    /// Converts an integer 1..15 to a VibrationFrequency, or null if out of range.
    pub fn fromFrequency(freq: u4) ?VibrationFrequency {
        if (freq < MIN_FREQUENCY or freq > MAX_FREQUENCY) return null;
        return @enumFromInt(freq);
    }

    /// Human-readable descriptive name of the vibration category.
    pub fn description(self: VibrationFrequency) []const u8 {
        return switch (self) {
            .movement => "Movement (step, walk, sprint)",
            .flap => "Flap (elytra, bat)",
            .swim => "Swim",
            .glide => "Glide",
            .projectile_land => "Projectile Land (arrow hit, trident stick)",
            .splash => "Splash",
            .projectile_shoot => "Projectile Shoot (bow, crossbow)",
            .damage_hurt => "Damage / Hurt (entity hurt)",
            .entity_equip => "Entity Equip (armor equipped)",
            .entity_interact => "Entity Interact (shear, milk, trade)",
            .block_change => "Block Change (trapdoor, door, lever)",
            .block_destroy => "Block Destroy (break)",
            .block_place => "Block Place",
            .entity_teleport => "Entity Teleport (ender pearl, chorus fruit)",
            .death_explosion => "Death / Explosion",
        };
    }
};

/// Specific gameplay vibration events mapped to their canonical 1..15 frequencies.
pub const VibrationEvent = enum {
    step,
    walk,
    sprint,
    flap_elytra,
    flap_bat,
    swim,
    glide,
    projectile_land_arrow,
    projectile_land_trident,
    splash,
    projectile_shoot_bow,
    projectile_shoot_crossbow,
    entity_hurt,
    armor_equip,
    entity_shear,
    entity_milk,
    villager_trade,
    entity_interact,
    trapdoor_toggle,
    door_toggle,
    lever_flip,
    block_change,
    block_break,
    block_destroy,
    block_place,
    ender_pearl_teleport,
    chorus_fruit_teleport,
    entity_teleport,
    entity_death,
    explosion,

    /// Maps this event to its canonical 1..15 frequency.
    pub fn toFrequency(self: VibrationEvent) u4 {
        return switch (self) {
            .step, .walk, .sprint => 1,
            .flap_elytra, .flap_bat => 2,
            .swim => 3,
            .glide => 4,
            .projectile_land_arrow, .projectile_land_trident => 5,
            .splash => 6,
            .projectile_shoot_bow, .projectile_shoot_crossbow => 7,
            .entity_hurt => 8,
            .armor_equip => 9,
            .entity_shear, .entity_milk, .villager_trade, .entity_interact => 10,
            .trapdoor_toggle, .door_toggle, .lever_flip, .block_change => 11,
            .block_break, .block_destroy => 12,
            .block_place => 13,
            .ender_pearl_teleport, .chorus_fruit_teleport, .entity_teleport => 14,
            .entity_death, .explosion => 15,
        };
    }

    /// Converts this event into its VibrationFrequency enum counterpart.
    pub fn toVibrationFrequency(self: VibrationEvent) VibrationFrequency {
        return @enumFromInt(self.toFrequency());
    }
};

// ============================================================================
// 3. Directional & Spatial Geometry
// ============================================================================

/// 3D cardinal and vertical face directions.
pub const Direction = enum(u3) {
    down = 0,
    up = 1,
    north = 2,
    south = 3,
    west = 4,
    east = 5,

    /// Returns the opposite face direction.
    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .down => .up,
            .up => .down,
            .north => .south,
            .south => .north,
            .west => .east,
            .east => .west,
        };
    }
};

/// 3D floating-point position vector.
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
};

/// 3D discrete block coordinate position.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) BlockPos {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn equals(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub fn add(self: BlockPos, other: BlockPos) BlockPos {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn offset(self: BlockPos, dx: i32, dy: i32, dz: i32) BlockPos {
        return .{
            .x = self.x + dx,
            .y = self.y + dy,
            .z = self.z + dz,
        };
    }

    pub fn offsetDirection(self: BlockPos, dir: Direction) BlockPos {
        return switch (dir) {
            .down => self.offset(0, -1, 0),
            .up => self.offset(0, 1, 0),
            .north => self.offset(0, 0, -1),
            .south => self.offset(0, 0, 1),
            .west => self.offset(-1, 0, 0),
            .east => self.offset(1, 0, 0),
        };
    }

    /// Center of the block in floating-point coordinates.
    pub fn center(self: BlockPos) Vec3 {
        return .{
            .x = @as(f32, @floatFromInt(self.x)) + 0.5,
            .y = @as(f32, @floatFromInt(self.y)) + 0.5,
            .z = @as(f32, @floatFromInt(self.z)) + 0.5,
        };
    }

    /// Manhattan distance between two block coordinates.
    pub fn manhattanDistance(self: BlockPos, other: BlockPos) u32 {
        const dx = @abs(self.x - other.x);
        const dy = @abs(self.y - other.y);
        const dz = @abs(self.z - other.z);
        return @intCast(dx + dy + dz);
    }

    /// Returns true if other shares one of the 6 cardinal faces (Manhattan distance == 1).
    pub fn isAdjacent(self: BlockPos, other: BlockPos) bool {
        return self.manhattanDistance(other) == 1;
    }

    /// Squared Euclidean distance between block centers.
    pub fn distanceSq(self: BlockPos, other: BlockPos) f32 {
        return self.center().distanceSq(other.center());
    }

    /// Euclidean distance between block centers.
    pub fn distance(self: BlockPos, other: BlockPos) f32 {
        return self.center().distance(other.center());
    }

    /// Squared Euclidean distance from block center to a point in world coordinates.
    pub fn distanceToVec3Sq(self: BlockPos, pt: Vec3) f32 {
        return self.center().distanceSq(pt);
    }
};

// ============================================================================
// 4. Frequency Filtering Logic & Calibrated Sculk Sensor
// ============================================================================

/// Returns whether a vibration of `incoming_freq` passes a calibration filter of `rear_signal`.
///
/// Specification Rules:
/// - If rear signal is 0: rejects all vibrations (sensor remains uncalibrated / disabled).
/// - If rear signal is S in [1, 15]: accepts ONLY vibrations whose canonical frequency matches S!
///   (Rejects all frequencies != S).
pub fn matchesFilter(rear_signal: u4, incoming_freq: u4) bool {
    if (rear_signal < MIN_FREQUENCY or rear_signal > MAX_FREQUENCY) return false;
    if (incoming_freq < MIN_FREQUENCY or incoming_freq > MAX_FREQUENCY) return false;
    return rear_signal == incoming_freq;
}

/// Operational state phases of a calibrated sculk sensor.
pub const SensorPhase = enum {
    inactive, // Idle, ready to receive vibrations
    active, // Emitting redstone signal for 10 ticks (0.50s)
    cooldown, // 1-tick (0.05s) recovery phase before returning to inactive
};

/// A Calibrated Sculk Sensor placed at discrete block coordinates.
pub const CalibratedSculkSensor = struct {
    pos: BlockPos,
    facing: Direction = .north,
    rear_signal: u4 = 0,
    phase: SensorPhase = .inactive,
    active_ticks: u32 = 0,
    recovery_ticks: u32 = 0,
    output_signal: u4 = 0,
    detected_freq: u4 = 0,
    total_activations: u32 = 0,

    pub fn init(pos: BlockPos, facing: Direction, rear_signal: u4) CalibratedSculkSensor {
        return .{
            .pos = pos,
            .facing = facing,
            .rear_signal = @min(15, rear_signal),
        };
    }

    /// Sets the rear calibration redstone input strength (0..15).
    pub fn setRearSignal(self: *CalibratedSculkSensor, signal: u4) void {
        self.rear_signal = @min(15, signal);
    }

    /// Returns the block face that receives the rear calibration redstone signal.
    /// The calibration face is opposite the facing direction.
    pub fn getCalibrationFace(self: CalibratedSculkSensor) Direction {
        return self.facing.opposite();
    }

    /// Returns the block coordinate directly behind the calibration face.
    pub fn getRearBlockPos(self: CalibratedSculkSensor) BlockPos {
        return self.pos.offsetDirection(self.getCalibrationFace());
    }

    /// Reads redstone signal strength from the block directly behind its calibration face.
    pub fn readRearInput(self: *CalibratedSculkSensor, signal_strength: u4) void {
        self.setRearSignal(signal_strength);
    }

    /// Checks if this sensor accepts a vibration of given frequency.
    pub fn acceptsFrequency(self: CalibratedSculkSensor, freq: u4) bool {
        return matchesFilter(self.rear_signal, freq);
    }

    /// Checks if this sensor can currently be triggered by a vibration of given frequency.
    pub fn canTrigger(self: CalibratedSculkSensor, freq: u4) bool {
        if (self.phase != .inactive) return false;
        return self.acceptsFrequency(freq);
    }

    /// Activates the sensor with the detected frequency for 10 game ticks.
    pub fn activate(self: *CalibratedSculkSensor, freq: u4) void {
        self.phase = .active;
        self.active_ticks = ACTIVE_DURATION_TICKS;
        self.recovery_ticks = 0;
        self.output_signal = freq;
        self.detected_freq = freq;
        self.total_activations += 1;
    }

    /// Attempts to trigger this sensor from a world coordinate vibration (vx, vy, vz).
    /// Returns true if accepted and activated, false if rejected (out of range, mismatched filter, or busy).
    pub fn triggerAt(self: *CalibratedSculkSensor, vx: f32, vy: f32, vz: f32, freq: u4) bool {
        if (!self.canTrigger(freq)) return false;

        const dist_sq = self.pos.distanceToVec3Sq(.{ .x = vx, .y = vy, .z = vz });
        if (dist_sq > CALIBRATED_SENSOR_RANGE_SQ) return false;

        self.activate(freq);
        return true;
    }

    /// Attempts to trigger this sensor from a vibration originating at another block.
    pub fn triggerFromBlock(self: *CalibratedSculkSensor, origin: BlockPos, freq: u4) bool {
        const c = origin.center();
        return self.triggerAt(c.x, c.y, c.z, freq);
    }

    /// Advances this sensor by one game tick (0.05s).
    /// Returns true if a state transition occurred.
    pub fn tick(self: *CalibratedSculkSensor) bool {
        switch (self.phase) {
            .inactive => return false,
            .active => {
                if (self.active_ticks > 0) {
                    self.active_ticks -= 1;
                }
                if (self.active_ticks == 0) {
                    // Transition to 1-tick cooldown recovery
                    self.phase = .cooldown;
                    self.recovery_ticks = RECOVERY_DURATION_TICKS;
                    self.output_signal = 0;
                    return true;
                }
                return false;
            },
            .cooldown => {
                if (self.recovery_ticks > 0) {
                    self.recovery_ticks -= 1;
                }
                if (self.recovery_ticks == 0) {
                    // Recovered to inactive readiness
                    self.phase = .inactive;
                    self.output_signal = 0;
                    return true;
                }
                return false;
            },
        }
    }

    /// Advances this sensor by `dt` wall-clock seconds in discrete 0.05s tick steps.
    pub fn tickSeconds(self: *CalibratedSculkSensor, dt: f32) bool {
        var changed = false;
        var t = dt;
        while (t >= TICK_DURATION_SECONDS) : (t -= TICK_DURATION_SECONDS) {
            if (self.tick()) changed = true;
        }
        return changed;
    }

    pub fn isActive(self: CalibratedSculkSensor) bool {
        return self.phase == .active;
    }

    pub fn isCoolingDown(self: CalibratedSculkSensor) bool {
        return self.phase == .cooldown;
    }

    pub fn isInactive(self: CalibratedSculkSensor) bool {
        return self.phase == .inactive;
    }

    pub fn getOutputSignal(self: CalibratedSculkSensor) u4 {
        return self.output_signal;
    }

    pub fn reset(self: *CalibratedSculkSensor) void {
        self.phase = .inactive;
        self.active_ticks = 0;
        self.recovery_ticks = 0;
        self.output_signal = 0;
        self.detected_freq = 0;
    }
};

/// Alias for CalibratedSculkSensor.
pub const CalibratedSensor = CalibratedSculkSensor;

// ============================================================================
// 5. Amethyst Block Acoustic Resonance
// ============================================================================

/// Represents a resonant acoustic vibration re-emitted by an Amethyst Block.
pub const ResonantVibration = struct {
    origin_pos: BlockPos,
    frequency: u4,
    range: f32 = AMETHYST_RESONANCE_RANGE,
    is_resonance: bool = true,

    /// Returns whether this vibration reaches the target block within its 16-block radius.
    pub fn canReachBlock(self: ResonantVibration, target: BlockPos) bool {
        return self.origin_pos.distanceSq(target) <= (self.range * self.range);
    }

    /// Returns whether this vibration reaches a world coordinate point.
    pub fn canReachVec3(self: ResonantVibration, pt: Vec3) bool {
        return self.origin_pos.distanceToVec3Sq(pt) <= (self.range * self.range);
    }
};

/// An Amethyst Block placed in the world capable of acoustic resonance.
pub const AmethystBlock = struct {
    pos: BlockPos,
    is_resonating: bool = false,
    resonance_frequency: u4 = 0,
    resonance_ticks: u32 = 0,
    total_resonances: u32 = 0,

    pub fn init(pos: BlockPos) AmethystBlock {
        return .{ .pos = pos };
    }

    /// Checks if this amethyst block is face-adjacent to a sculk sensor at `sensor_pos`.
    pub fn isAdjacentTo(self: AmethystBlock, sensor_pos: BlockPos) bool {
        return self.pos.isAdjacent(sensor_pos);
    }

    /// Triggers acoustic resonance at `freq`. Emits a resonant vibration of identical frequency.
    pub fn resonate(self: *AmethystBlock, freq: u4) ResonantVibration {
        self.is_resonating = true;
        self.resonance_frequency = freq;
        self.resonance_ticks = ACTIVE_DURATION_TICKS;
        self.total_resonances += 1;

        return ResonantVibration{
            .origin_pos = self.pos,
            .frequency = freq,
            .range = AMETHYST_RESONANCE_RANGE,
            .is_resonance = true,
        };
    }

    /// Advances resonance state by one game tick.
    pub fn tick(self: *AmethystBlock) bool {
        if (self.resonance_ticks > 0) {
            self.resonance_ticks -= 1;
            if (self.resonance_ticks == 0) {
                self.is_resonating = false;
                self.resonance_frequency = 0;
                return true;
            }
        }
        return false;
    }

    pub fn reset(self: *AmethystBlock) void {
        self.is_resonating = false;
        self.resonance_frequency = 0;
        self.resonance_ticks = 0;
    }
};

// ============================================================================
// 6. Resonance Chains & Multi-Hop Network Simulation
// ============================================================================

/// Result summary of an acoustic vibration emission.
pub const EmissionResult = struct {
    sensors_triggered: u32 = 0,
    amethyst_resonated: u32 = 0,
    first_sensor_idx: ?usize = null,
};

/// Result summary of multi-hop acoustic resonance propagation chain.
pub const PropagationSummary = struct {
    total_sensors_triggered: u32 = 0,
    total_resonances: u32 = 0,
    hops_completed: u32 = 0,
    terminated_by_mismatch: bool = false,
    terminated_by_range: bool = false,
    final_hop_reached: u32 = 0,
    max_distance_reached: f32 = 0.0,
};

/// Tick advancement summary across a network.
pub const TickSummary = struct {
    sensors_active: u32 = 0,
    sensors_cooldown: u32 = 0,
    sensors_inactive: u32 = 0,
    amethysts_resonating: u32 = 0,
};

/// Resonance chain network managing calibrated sensors and amethyst resonance blocks.
pub const ResonanceChainNetwork = struct {
    sensors: [MAX_CHAIN_SENSORS]CalibratedSculkSensor = undefined,
    sensor_count: usize = 0,
    amethyst_blocks: [MAX_CHAIN_AMETHYST]AmethystBlock = undefined,
    amethyst_count: usize = 0,

    pub fn init() ResonanceChainNetwork {
        return .{
            .sensor_count = 0,
            .amethyst_count = 0,
        };
    }

    /// Adds a calibrated sensor to the chain network.
    pub fn addSensor(self: *ResonanceChainNetwork, sensor: CalibratedSculkSensor) !usize {
        if (self.sensor_count >= MAX_CHAIN_SENSORS) return error.NetworkFull;
        const idx = self.sensor_count;
        self.sensors[idx] = sensor;
        self.sensor_count += 1;
        return idx;
    }

    /// Adds an amethyst block to the chain network.
    pub fn addAmethystBlock(self: *ResonanceChainNetwork, block: AmethystBlock) !usize {
        if (self.amethyst_count >= MAX_CHAIN_AMETHYST) return error.NetworkFull;
        const idx = self.amethyst_count;
        self.amethyst_blocks[idx] = block;
        self.amethyst_count += 1;
        return idx;
    }

    /// Adds a paired repeater unit: a calibrated sensor and an adjacent amethyst block.
    pub fn addRepeaterUnit(
        self: *ResonanceChainNetwork,
        sensor_pos: BlockPos,
        amethyst_pos: BlockPos,
        facing: Direction,
        rear_signal: u4,
    ) !struct { sensor_idx: usize, amethyst_idx: usize } {
        if (!amethyst_pos.isAdjacent(sensor_pos)) return error.BlocksNotAdjacent;
        const s_idx = try self.addSensor(CalibratedSculkSensor.init(sensor_pos, facing, rear_signal));
        const a_idx = try self.addAmethystBlock(AmethystBlock.init(amethyst_pos));
        return .{ .sensor_idx = s_idx, .amethyst_idx = a_idx };
    }

    /// Finds a sensor at block position (x, y, z).
    pub fn findSensorAt(self: *ResonanceChainNetwork, pos: BlockPos) ?*CalibratedSculkSensor {
        for (self.sensors[0..self.sensor_count]) |*s| {
            if (s.pos.equals(pos)) return s;
        }
        return null;
    }

    /// Finds an amethyst block at block position (x, y, z).
    pub fn findAmethystAt(self: *ResonanceChainNetwork, pos: BlockPos) ?*AmethystBlock {
        for (self.amethyst_blocks[0..self.amethyst_count]) |*a| {
            if (a.pos.equals(pos)) return a;
        }
        return null;
    }

    /// Finds an amethyst block adjacent to the given sensor position.
    pub fn findAdjacentAmethyst(self: *ResonanceChainNetwork, sensor_pos: BlockPos) ?*AmethystBlock {
        for (self.amethyst_blocks[0..self.amethyst_count]) |*a| {
            if (a.pos.isAdjacent(sensor_pos)) return a;
        }
        return null;
    }

    /// Emits a single vibration at world coordinates (vx, vy, vz).
    /// Triggers all eligible sensors in range and causes adjacent amethyst blocks to resonate.
    pub fn emitVibration(self: *ResonanceChainNetwork, vx: f32, vy: f32, vz: f32, freq: u4) EmissionResult {
        var res = EmissionResult{};

        for (self.sensors[0..self.sensor_count], 0..) |*s, idx| {
            if (s.triggerAt(vx, vy, vz, freq)) {
                res.sensors_triggered += 1;
                if (res.first_sensor_idx == null) {
                    res.first_sensor_idx = idx;
                }
                // Check for adjacent amethyst block
                if (self.findAdjacentAmethyst(s.pos)) |a| {
                    _ = a.resonate(freq);
                    res.amethyst_resonated += 1;
                }
            }
        }

        return res;
    }

    /// Emits a vibration from a block position.
    pub fn emitVibrationFromBlock(self: *ResonanceChainNetwork, origin: BlockPos, freq: u4) EmissionResult {
        const c = origin.center();
        return self.emitVibration(c.x, c.y, c.z, freq);
    }

    /// Simulates a multi-hop acoustic resonance propagation chain starting from an origin block.
    /// Resonant vibrations travel up to 16m from each vibrating amethyst block to downstream sensors.
    pub fn propagateResonanceChain(
        self: *ResonanceChainNetwork,
        origin: BlockPos,
        freq: u4,
        max_hops: u32,
    ) PropagationSummary {
        var summary = PropagationSummary{};
        const hop_limit = @min(max_hops, MAX_RESONANCE_HOPS);

        var current_vibrations: [MAX_CHAIN_AMETHYST]BlockPos = undefined;
        var next_vibrations: [MAX_CHAIN_AMETHYST]BlockPos = undefined;
        var current_count: usize = 0;
        var next_count: usize = 0;

        current_vibrations[0] = origin;
        current_count = 1;

        var hop: u32 = 0;
        while (hop < hop_limit and current_count > 0) : (hop += 1) {
            next_count = 0;
            var hop_triggered_any = false;

            for (current_vibrations[0..current_count]) |source_pos| {
                const c = source_pos.center();

                for (self.sensors[0..self.sensor_count]) |*s| {
                    if (s.canTrigger(freq)) {
                        const dist_sq = s.pos.distanceToVec3Sq(c);
                        if (dist_sq <= CALIBRATED_SENSOR_RANGE_SQ) {
                            s.activate(freq);
                            summary.total_sensors_triggered += 1;
                            hop_triggered_any = true;

                            const d = origin.distance(s.pos);
                            if (d > summary.max_distance_reached) {
                                summary.max_distance_reached = d;
                            }

                            // Check for adjacent amethyst block
                            if (self.findAdjacentAmethyst(s.pos)) |a| {
                                _ = a.resonate(freq);
                                summary.total_resonances += 1;

                                if (next_count < MAX_CHAIN_AMETHYST) {
                                    next_vibrations[next_count] = a.pos;
                                    next_count += 1;
                                }
                            }
                        }
                    }
                }
            }

            if (!hop_triggered_any) {
                // If there were vibrations queued but no sensor was triggered:
                // Check if any inactive sensors were rejected due to filter mismatch or were out of range.
                var found_mismatch = false;
                var found_out_of_range = false;
                for (current_vibrations[0..current_count]) |source_pos| {
                    const c = source_pos.center();
                    for (self.sensors[0..self.sensor_count]) |*s| {
                        if (s.isInactive()) {
                            const dist_sq = s.pos.distanceToVec3Sq(c);
                            if (dist_sq <= CALIBRATED_SENSOR_RANGE_SQ) {
                                if (!s.acceptsFrequency(freq)) {
                                    summary.terminated_by_mismatch = true;
                                    found_mismatch = true;
                                }
                            } else {
                                found_out_of_range = true;
                            }
                        }
                    }
                }
                if (!found_mismatch and found_out_of_range) {
                    summary.terminated_by_range = true;
                }
                break;
            }

            summary.hops_completed += 1;
            summary.final_hop_reached = hop + 1;

            for (next_vibrations[0..next_count], 0..) |pos, i| {
                current_vibrations[i] = pos;
            }
            current_count = next_count;
        }

        return summary;
    }

    /// Advances all sensors and amethyst blocks by one game tick (0.05s).
    pub fn tick(self: *ResonanceChainNetwork) TickSummary {
        var summary = TickSummary{};

        for (self.sensors[0..self.sensor_count]) |*s| {
            _ = s.tick();
            switch (s.phase) {
                .inactive => summary.sensors_inactive += 1,
                .active => summary.sensors_active += 1,
                .cooldown => summary.sensors_cooldown += 1,
            }
        }

        for (self.amethyst_blocks[0..self.amethyst_count]) |*a| {
            _ = a.tick();
            if (a.is_resonating) {
                summary.amethysts_resonating += 1;
            }
        }

        return summary;
    }

    /// Resets all network components to initial idle state.
    pub fn reset(self: *ResonanceChainNetwork) void {
        for (self.sensors[0..self.sensor_count]) |*s| {
            s.reset();
        }
        for (self.amethyst_blocks[0..self.amethyst_count]) |*a| {
            a.reset();
        }
    }
};

/// Alias for AcousticRepeaterNetwork compatibility.
pub const AcousticRepeaterNetwork = ResonanceChainNetwork;

// ============================================================================
// 7. Standalone Helper Functions
// ============================================================================

/// Standalone trigger function matching conventional module signatures.
pub fn triggerVibration(sensor: *CalibratedSculkSensor, vx: f32, vy: f32, vz: f32, freq: u4) bool {
    return sensor.triggerAt(vx, vy, vz, freq);
}

/// Standalone tick function matching conventional module signatures (advances by dt seconds).
pub fn tickSensor(sensor: *CalibratedSculkSensor, dt: f32) bool {
    return sensor.tickSeconds(dt);
}

/// Locates a sensor at coordinate (x, y, z) in a slice.
pub fn findSensor(sensors: []const CalibratedSculkSensor, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, sensors.len);
    for (sensors[0..n], 0..) |s, i| {
        if (s.pos.x == x and s.pos.y == y and s.pos.z == z) return i;
    }
    return null;
}

// ============================================================================
// 8. Unit Tests (30 Comprehensive Tests)
// ============================================================================

test "Milestone 523: All 15 canonical vibration frequencies are mapped and unique (1..15)" {
    try std.testing.expectEqual(@as(u4, 1), VibrationFrequency.movement.toFrequency());
    try std.testing.expectEqual(@as(u4, 2), VibrationFrequency.flap.toFrequency());
    try std.testing.expectEqual(@as(u4, 3), VibrationFrequency.swim.toFrequency());
    try std.testing.expectEqual(@as(u4, 4), VibrationFrequency.glide.toFrequency());
    try std.testing.expectEqual(@as(u4, 5), VibrationFrequency.projectile_land.toFrequency());
    try std.testing.expectEqual(@as(u4, 6), VibrationFrequency.splash.toFrequency());
    try std.testing.expectEqual(@as(u4, 7), VibrationFrequency.projectile_shoot.toFrequency());
    try std.testing.expectEqual(@as(u4, 8), VibrationFrequency.damage_hurt.toFrequency());
    try std.testing.expectEqual(@as(u4, 9), VibrationFrequency.entity_equip.toFrequency());
    try std.testing.expectEqual(@as(u4, 10), VibrationFrequency.entity_interact.toFrequency());
    try std.testing.expectEqual(@as(u4, 11), VibrationFrequency.block_change.toFrequency());
    try std.testing.expectEqual(@as(u4, 12), VibrationFrequency.block_destroy.toFrequency());
    try std.testing.expectEqual(@as(u4, 13), VibrationFrequency.block_place.toFrequency());
    try std.testing.expectEqual(@as(u4, 14), VibrationFrequency.entity_teleport.toFrequency());
    try std.testing.expectEqual(@as(u4, 15), VibrationFrequency.death_explosion.toFrequency());
}

test "Milestone 523: VibrationFrequency fromFrequency roundtrip and out-of-range bounds checking" {
    for (1..16) |f_idx| {
        const f: u4 = @intCast(f_idx);
        const enum_val = VibrationFrequency.fromFrequency(f);
        try std.testing.expect(enum_val != null);
        try std.testing.expectEqual(f, enum_val.?.toFrequency());
    }
    try std.testing.expect(VibrationFrequency.fromFrequency(0) == null);
}

test "Milestone 523: VibrationFrequency descriptive names and labels" {
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.movement.description(), "Movement") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.flap.description(), "Flap") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.swim.description(), "Swim") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.glide.description(), "Glide") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.projectile_land.description(), "Projectile Land") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.splash.description(), "Splash") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.projectile_shoot.description(), "Projectile Shoot") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.damage_hurt.description(), "Damage / Hurt") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.entity_equip.description(), "Entity Equip") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.entity_interact.description(), "Entity Interact") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.block_change.description(), "Block Change") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.block_destroy.description(), "Block Destroy") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.block_place.description(), "Block Place") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.entity_teleport.description(), "Entity Teleport") != null);
    try std.testing.expect(std.mem.indexOf(u8, VibrationFrequency.death_explosion.description(), "Death / Explosion") != null);
}

test "Milestone 523: VibrationEvent actions map to correct canonical 1..15 frequencies" {
    try std.testing.expectEqual(@as(u4, 1), VibrationEvent.step.toFrequency());
    try std.testing.expectEqual(@as(u4, 1), VibrationEvent.walk.toFrequency());
    try std.testing.expectEqual(@as(u4, 1), VibrationEvent.sprint.toFrequency());
    try std.testing.expectEqual(@as(u4, 2), VibrationEvent.flap_elytra.toFrequency());
    try std.testing.expectEqual(@as(u4, 2), VibrationEvent.flap_bat.toFrequency());
    try std.testing.expectEqual(@as(u4, 3), VibrationEvent.swim.toFrequency());
    try std.testing.expectEqual(@as(u4, 4), VibrationEvent.glide.toFrequency());
    try std.testing.expectEqual(@as(u4, 5), VibrationEvent.projectile_land_arrow.toFrequency());
    try std.testing.expectEqual(@as(u4, 5), VibrationEvent.projectile_land_trident.toFrequency());
    try std.testing.expectEqual(@as(u4, 6), VibrationEvent.splash.toFrequency());
    try std.testing.expectEqual(@as(u4, 7), VibrationEvent.projectile_shoot_bow.toFrequency());
    try std.testing.expectEqual(@as(u4, 7), VibrationEvent.projectile_shoot_crossbow.toFrequency());
    try std.testing.expectEqual(@as(u4, 8), VibrationEvent.entity_hurt.toFrequency());
    try std.testing.expectEqual(@as(u4, 9), VibrationEvent.armor_equip.toFrequency());
    try std.testing.expectEqual(@as(u4, 10), VibrationEvent.entity_shear.toFrequency());
    try std.testing.expectEqual(@as(u4, 10), VibrationEvent.villager_trade.toFrequency());
    try std.testing.expectEqual(@as(u4, 11), VibrationEvent.lever_flip.toFrequency());
    try std.testing.expectEqual(@as(u4, 11), VibrationEvent.door_toggle.toFrequency());
    try std.testing.expectEqual(@as(u4, 12), VibrationEvent.block_break.toFrequency());
    try std.testing.expectEqual(@as(u4, 13), VibrationEvent.block_place.toFrequency());
    try std.testing.expectEqual(@as(u4, 14), VibrationEvent.ender_pearl_teleport.toFrequency());
    try std.testing.expectEqual(@as(u4, 15), VibrationEvent.explosion.toFrequency());
}

test "Milestone 523: matchesFilter strictly accepts equal frequency when rear signal is 1..15" {
    for (1..16) |s| {
        const sig: u4 = @intCast(s);
        try std.testing.expect(matchesFilter(sig, sig));
    }
}

test "Milestone 523: matchesFilter strictly rejects non-matching frequencies for all 1..15" {
    for (1..16) |s| {
        const sig: u4 = @intCast(s);
        for (1..16) |f| {
            const freq: u4 = @intCast(f);
            if (sig != freq) {
                try std.testing.expect(!matchesFilter(sig, freq));
            }
        }
    }
}

test "Milestone 523: matchesFilter rejects all vibrations when rear calibration signal is 0 (uncalibrated / disabled)" {
    for (0..16) |f| {
        const freq: u4 = @intCast(f);
        try std.testing.expect(!matchesFilter(0, freq));
    }
}

test "Milestone 523: matchesFilter rejects invalid frequencies (0 or outside 1..15)" {
    try std.testing.expect(!matchesFilter(5, 0));
}

test "Milestone 523: CalibratedSculkSensor initialization, facing direction, and rear block position" {
    const sensor_pos = BlockPos.init(10, 64, 20);
    var sensor = CalibratedSculkSensor.init(sensor_pos, .north, 5);

    try std.testing.expect(sensor.pos.equals(sensor_pos));
    try std.testing.expectEqual(Direction.north, sensor.facing);
    try std.testing.expectEqual(@as(u4, 5), sensor.rear_signal);
    try std.testing.expectEqual(SensorPhase.inactive, sensor.phase);
    try std.testing.expectEqual(Direction.south, sensor.getCalibrationFace());

    const rear_pos = sensor.getRearBlockPos();
    try std.testing.expectEqual(sensor_pos.x, rear_pos.x);
    try std.testing.expectEqual(sensor_pos.y, rear_pos.y);
    try std.testing.expectEqual(sensor_pos.z + 1, rear_pos.z);
}

test "Milestone 523: CalibratedSculkSensor rear input calibration reading and setting (0..15)" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 60, 0), .east, 0);
    try std.testing.expectEqual(@as(u4, 0), sensor.rear_signal);
    try std.testing.expect(!sensor.acceptsFrequency(7));

    // Read redstone signal 7 into rear calibration input
    sensor.readRearInput(7);
    try std.testing.expectEqual(@as(u4, 7), sensor.rear_signal);
    try std.testing.expect(sensor.acceptsFrequency(7));
    try std.testing.expect(!sensor.acceptsFrequency(6));
    try std.testing.expect(!sensor.acceptsFrequency(8));

    // Disable sensor by setting rear signal to 0
    sensor.setRearSignal(0);
    try std.testing.expectEqual(@as(u4, 0), sensor.rear_signal);
    try std.testing.expect(!sensor.acceptsFrequency(7));
}

test "Milestone 523: CalibratedSculkSensor 16-block detection radius boundary inclusive acceptance" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 12);

    // Vibration exactly at 16.0 blocks distance along X axis
    // sensor center: (0.5, 64.5, 0.5); target center: (16.5, 64.5, 0.5) -> distance = 16.0
    const source = BlockPos.init(16, 64, 0);
    try std.testing.expect(sensor.triggerFromBlock(source, 12));
    try std.testing.expectEqual(SensorPhase.active, sensor.phase);
    try std.testing.expectEqual(@as(u4, 12), sensor.output_signal);
}

test "Milestone 523: CalibratedSculkSensor 16-block detection radius boundary exclusive rejection (>16m)" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 12);

    // Vibration at 17 blocks away -> distance = 17.0m > 16.0m
    const source = BlockPos.init(17, 64, 0);
    try std.testing.expect(!sensor.triggerFromBlock(source, 12));
    try std.testing.expectEqual(SensorPhase.inactive, sensor.phase);
    try std.testing.expectEqual(@as(u4, 0), sensor.output_signal);
}

test "Milestone 523: CalibratedSculkSensor detection radius is exactly 2x standard sculk sensor (16m vs 8m)" {
    try std.testing.expectEqual(@as(f32, 16.0), CALIBRATED_SENSOR_RANGE);
    try std.testing.expectEqual(@as(f32, 8.0), ORDINARY_SCULK_RANGE);
    try std.testing.expectEqual(@as(f32, 2.0), CALIBRATED_SENSOR_RANGE / ORDINARY_SCULK_RANGE);
    try std.testing.expectEqual(@as(f32, 256.0), CALIBRATED_SENSOR_RANGE_SQ);
    try std.testing.expectEqual(@as(f32, 64.0), ORDINARY_SCULK_RANGE_SQ);
}

test "Milestone 523: CalibratedSculkSensor 10-tick active pulse maintains output signal S" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 9);
    try std.testing.expect(sensor.triggerAt(0.5, 64.5, 0.5, 9));

    try std.testing.expectEqual(SensorPhase.active, sensor.phase);
    try std.testing.expectEqual(@as(u4, 9), sensor.getOutputSignal());
    try std.testing.expectEqual(@as(u32, 10), sensor.active_ticks);

    // Tick for 9 ticks: sensor remains active and emits signal 9
    for (0..9) |tick_idx| {
        _ = tick_idx;
        _ = sensor.tick();
        try std.testing.expectEqual(SensorPhase.active, sensor.phase);
        try std.testing.expectEqual(@as(u4, 9), sensor.getOutputSignal());
    }

    // 10th tick: active phase ends, transitions to 1-tick cooldown
    const state_changed = sensor.tick();
    try std.testing.expect(state_changed);
    try std.testing.expectEqual(SensorPhase.cooldown, sensor.phase);
    try std.testing.expectEqual(@as(u4, 0), sensor.getOutputSignal());
    try std.testing.expectEqual(@as(u32, 1), sensor.recovery_ticks);
}

test "Milestone 523: CalibratedSculkSensor 1-tick recovery cooldown clears output signal" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 4);
    _ = sensor.triggerAt(0.5, 64.5, 0.5, 4);

    // Run through the 10 active ticks
    for (0..10) |_| {
        _ = sensor.tick();
    }
    try std.testing.expectEqual(SensorPhase.cooldown, sensor.phase);
    try std.testing.expectEqual(@as(u4, 0), sensor.getOutputSignal());

    // 11th tick: recovery cooldown elapses, returns to inactive
    const recovered = sensor.tick();
    try std.testing.expect(recovered);
    try std.testing.expectEqual(SensorPhase.inactive, sensor.phase);
    try std.testing.expectEqual(@as(u4, 0), sensor.getOutputSignal());
}

test "Milestone 523: CalibratedSculkSensor full 11-tick cycle returns to inactive and ready for new trigger" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 3);
    try std.testing.expect(sensor.isInactive());

    // Trigger 1
    try std.testing.expect(sensor.triggerAt(0.5, 64.5, 0.5, 3));
    try std.testing.expectEqual(@as(u32, 1), sensor.total_activations);

    // Advance 11 ticks (0.55s)
    for (0..11) |_| {
        _ = sensor.tick();
    }
    try std.testing.expect(sensor.isInactive());

    // Trigger 2 after full recovery
    try std.testing.expect(sensor.triggerAt(0.5, 64.5, 0.5, 3));
    try std.testing.expectEqual(@as(u32, 2), sensor.total_activations);
}

test "Milestone 523: CalibratedSculkSensor blocks triggers while active" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 8);
    try std.testing.expect(sensor.triggerAt(0.5, 64.5, 0.5, 8));

    // During active phase, secondary vibration is rejected
    try std.testing.expect(!sensor.triggerAt(0.5, 64.5, 0.5, 8));
    try std.testing.expectEqual(@as(u32, 1), sensor.total_activations);
}

test "Milestone 523: CalibratedSculkSensor blocks triggers during recovery cooldown" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 8);
    _ = sensor.triggerAt(0.5, 64.5, 0.5, 8);

    // Advance through 10 active ticks into cooldown
    for (0..10) |_| {
        _ = sensor.tick();
    }
    try std.testing.expect(sensor.isCoolingDown());

    // Vibration rejected during cooldown
    try std.testing.expect(!sensor.triggerAt(0.5, 64.5, 0.5, 8));
    try std.testing.expectEqual(@as(u32, 1), sensor.total_activations);
}

test "Milestone 523: AmethystBlock 6 cardinal face adjacency detection with sensor" {
    const sensor_pos = BlockPos.init(10, 64, 10);

    const down_pos = BlockPos.init(10, 63, 10);
    const up_pos = BlockPos.init(10, 65, 10);
    const north_pos = BlockPos.init(10, 64, 9);
    const south_pos = BlockPos.init(10, 64, 11);
    const west_pos = BlockPos.init(9, 64, 10);
    const east_pos = BlockPos.init(11, 64, 10);

    try std.testing.expect(AmethystBlock.init(down_pos).isAdjacentTo(sensor_pos));
    try std.testing.expect(AmethystBlock.init(up_pos).isAdjacentTo(sensor_pos));
    try std.testing.expect(AmethystBlock.init(north_pos).isAdjacentTo(sensor_pos));
    try std.testing.expect(AmethystBlock.init(south_pos).isAdjacentTo(sensor_pos));
    try std.testing.expect(AmethystBlock.init(west_pos).isAdjacentTo(sensor_pos));
    try std.testing.expect(AmethystBlock.init(east_pos).isAdjacentTo(sensor_pos));
}

test "Milestone 523: AmethystBlock non-adjacent positions (diagonal or separated) are not adjacent" {
    const sensor_pos = BlockPos.init(10, 64, 10);

    const diag1 = BlockPos.init(11, 65, 10); // diagonal (manhattan = 2)
    const diag2 = BlockPos.init(11, 64, 11); // diagonal (manhattan = 2)
    const far = BlockPos.init(12, 64, 10); // 2 blocks away (manhattan = 2)

    try std.testing.expect(!AmethystBlock.init(diag1).isAdjacentTo(sensor_pos));
    try std.testing.expect(!AmethystBlock.init(diag2).isAdjacentTo(sensor_pos));
    try std.testing.expect(!AmethystBlock.init(far).isAdjacentTo(sensor_pos));
}

test "Milestone 523: AmethystBlock acoustic resonance re-emits identical frequency with 16m range" {
    var amethyst = AmethystBlock.init(BlockPos.init(20, 64, 20));
    try std.testing.expect(!amethyst.is_resonating);

    const resonant_wave = amethyst.resonate(11);
    try std.testing.expect(amethyst.is_resonating);
    try std.testing.expectEqual(@as(u4, 11), amethyst.resonance_frequency);
    try std.testing.expectEqual(@as(u32, 1), amethyst.total_resonances);

    // Verify re-emitted wave properties
    try std.testing.expect(resonant_wave.is_resonance);
    try std.testing.expectEqual(@as(u4, 11), resonant_wave.frequency);
    try std.testing.expectEqual(amethyst.pos.x, resonant_wave.origin_pos.x);
    try std.testing.expectEqual(amethyst.pos.y, resonant_wave.origin_pos.y);
    try std.testing.expectEqual(amethyst.pos.z, resonant_wave.origin_pos.z);
    try std.testing.expectEqual(@as(f32, 16.0), resonant_wave.range);
}

test "Milestone 523: AmethystBlock resonance 10-tick active duration and state reset" {
    var amethyst = AmethystBlock.init(BlockPos.init(0, 64, 0));
    _ = amethyst.resonate(5);
    try std.testing.expect(amethyst.is_resonating);
    try std.testing.expectEqual(@as(u32, 10), amethyst.resonance_ticks);

    for (0..9) |_| {
        _ = amethyst.tick();
        try std.testing.expect(amethyst.is_resonating);
    }

    const ended = amethyst.tick();
    try std.testing.expect(ended);
    try std.testing.expect(!amethyst.is_resonating);
    try std.testing.expectEqual(@as(u4, 0), amethyst.resonance_frequency);
}

test "Milestone 523: ResonanceChainNetwork single-hop vibration detection and amethyst resonance" {
    var net = ResonanceChainNetwork.init();

    // Sensor at (0, 64, 0) tuned to frequency 6
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 6));
    // Adjacent amethyst at (1, 64, 0)
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 64, 0)));

    const result = net.emitVibration(0.5, 64.5, 0.5, 6);
    try std.testing.expectEqual(@as(u32, 1), result.sensors_triggered);
    try std.testing.expectEqual(@as(u32, 1), result.amethyst_resonated);

    const a = net.findAmethystAt(BlockPos.init(1, 64, 0)).?;
    try std.testing.expect(a.is_resonating);
    try std.testing.expectEqual(@as(u4, 6), a.resonance_frequency);
}

test "Milestone 523: ResonanceChainNetwork 2-hop repeater transmission across 16 blocks" {
    var net = ResonanceChainNetwork.init();

    // Node 0: Sensor at (0, 64, 0), Amethyst at (1, 64, 0), tuned to 8
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 8));
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 64, 0)));

    // Node 1: Sensor at (16, 64, 0) tuned to 8
    // Distance from Amethyst (1, 64, 0) to Sensor (16, 64, 0) is 15 blocks (<= 16m)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(16, 64, 0), .north, 8));

    // Origin vibration at (-2, 64, 0) of frequency 8
    const summary = net.propagateResonanceChain(BlockPos.init(-2, 64, 0), 8, 5);

    try std.testing.expectEqual(@as(u32, 2), summary.hops_completed);
    try std.testing.expectEqual(@as(u32, 2), summary.total_sensors_triggered);
    try std.testing.expectEqual(@as(u32, 1), summary.total_resonances);
    try std.testing.expect(!summary.terminated_by_mismatch);
    try std.testing.expect(!summary.terminated_by_range);
}

test "Milestone 523: ResonanceChainNetwork multi-hop repeater chain simulation across 3+ hops (48m)" {
    var net = ResonanceChainNetwork.init();

    // Setup 3 hops spaced 15 blocks apart (within 16m detection limit)
    // Node 1: Sensor at (0, 64, 0), Amethyst at (1, 64, 0)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 5));
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 64, 0)));

    // Node 2: Sensor at (16, 64, 0), Amethyst at (17, 64, 0) (distance from (1,64,0) is 15 blocks)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(16, 64, 0), .north, 5));
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(17, 64, 0)));

    // Node 3: Sensor at (32, 64, 0), Amethyst at (33, 64, 0) (distance from (17,64,0) is 15 blocks)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(32, 64, 0), .north, 5));
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(33, 64, 0)));

    // Initial acoustic vibration at origin (-5, 64, 0)
    const summary = net.propagateResonanceChain(BlockPos.init(-5, 64, 0), 5, 10);

    try std.testing.expectEqual(@as(u32, 3), summary.hops_completed);
    try std.testing.expectEqual(@as(u32, 3), summary.total_sensors_triggered);
    try std.testing.expectEqual(@as(u32, 3), summary.total_resonances);
    try std.testing.expect(summary.max_distance_reached >= 37.0);
}

test "Milestone 523: ResonanceChainNetwork multi-hop repeater chain simulation across 4+ hops (64m)" {
    var net = ResonanceChainNetwork.init();

    // 4 repeater nodes along X axis, each 15 blocks apart, all calibrated to frequency 14
    for (0..4) |i| {
        const x_base: i32 = @intCast(i * 16);
        _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(x_base, 64, 0), .north, 14));
        _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(x_base + 1, 64, 0)));
    }

    const summary = net.propagateResonanceChain(BlockPos.init(-2, 64, 0), 14, 10);

    try std.testing.expectEqual(@as(u32, 4), summary.hops_completed);
    try std.testing.expectEqual(@as(u32, 4), summary.total_sensors_triggered);
    try std.testing.expectEqual(@as(u32, 4), summary.total_resonances);
}

test "Milestone 523: ResonanceChainNetwork chain termination when downstream sensor filter mismatches" {
    var net = ResonanceChainNetwork.init();

    // Node 1: Sensor calibrated to 7, adjacent amethyst
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 7));
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 64, 0)));

    // Node 2: Sensor calibrated to 3 (MISMATCH! Expecting 7), adjacent amethyst
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(15, 64, 0), .north, 3));
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(16, 64, 0)));

    // Propagate vibration 7
    const summary = net.propagateResonanceChain(BlockPos.init(-1, 64, 0), 7, 5);

    // Hop 1 succeeds at Node 1; Hop 2 terminates because Node 2 filter rejects 7
    try std.testing.expectEqual(@as(u32, 1), summary.hops_completed);
    try std.testing.expectEqual(@as(u32, 1), summary.total_sensors_triggered);
    try std.testing.expect(summary.terminated_by_mismatch);
    try std.testing.expect(!summary.terminated_by_range);
}

test "Milestone 523: ResonanceChainNetwork chain termination when inter-node distance exceeds 16m" {
    var net = ResonanceChainNetwork.init();

    // Node 1: Sensor at (0, 64, 0), Amethyst at (1, 64, 0)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 10));
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 64, 0)));

    // Node 2: Sensor at (20, 64, 0) -> distance from (1, 64, 0) is 19 blocks (> 16m!)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(20, 64, 0), .north, 10));
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(21, 64, 0)));

    const summary = net.propagateResonanceChain(BlockPos.init(-1, 64, 0), 10, 5);

    try std.testing.expectEqual(@as(u32, 1), summary.hops_completed);
    try std.testing.expectEqual(@as(u32, 1), summary.total_sensors_triggered);
    try std.testing.expect(summary.terminated_by_range);
    try std.testing.expect(!summary.terminated_by_mismatch);
}

test "Milestone 523: ResonanceChainNetwork branching repeater transmission to multiple tuned sensors" {
    var net = ResonanceChainNetwork.init();

    // Central transmitter: Sensor at (0, 64, 0), Amethyst at (0, 64, 1)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 2));
    _ = try net.addAmethystBlock(AmethystBlock.init(BlockPos.init(0, 64, 1)));

    // Branch A: Sensor at (12, 64, 6) tuned to 2 (13 blocks from Amethyst, 20 blocks from Origin)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(12, 64, 6), .north, 2));
    // Branch B: Sensor at (-12, 64, 6) tuned to 2 (13 blocks from Amethyst, 20 blocks from Origin)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(-12, 64, 6), .north, 2));
    // Branch C: Sensor at (0, 64, 14) tuned to 2 (13 blocks from Amethyst, 24 blocks from Origin)
    _ = try net.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 14), .north, 2));

    // Origin vibration at (0, 64, -10) -> reaches ONLY central sensor on hop 0 (dist = 10 <= 16)
    const summary = net.propagateResonanceChain(BlockPos.init(0, 64, -10), 2, 5);

    // Initial sensor triggered, then 3 branch sensors triggered on hop 1
    try std.testing.expectEqual(@as(u32, 4), summary.total_sensors_triggered);
    try std.testing.expectEqual(@as(u32, 2), summary.hops_completed);
}

test "Milestone 523: ResonanceChainNetwork tick cycle synchronization and full network reset" {
    var net = ResonanceChainNetwork.init();

    _ = try net.addRepeaterUnit(
        BlockPos.init(0, 64, 0),
        BlockPos.init(1, 64, 0),
        .north,
        15,
    );

    const emission = net.emitVibrationFromBlock(BlockPos.init(0, 64, 0), 15);
    try std.testing.expectEqual(@as(u32, 1), emission.sensors_triggered);
    try std.testing.expectEqual(@as(u32, 1), emission.amethyst_resonated);

    var tick_res = net.tick();
    try std.testing.expectEqual(@as(u32, 1), tick_res.sensors_active);
    try std.testing.expectEqual(@as(u32, 1), tick_res.amethysts_resonating);

    // Full reset clears all states
    net.reset();
    tick_res = net.tick();
    try std.testing.expectEqual(@as(u32, 1), tick_res.sensors_inactive);
    try std.testing.expectEqual(@as(u32, 0), tick_res.sensors_active);
    try std.testing.expectEqual(@as(u32, 0), tick_res.amethysts_resonating);
}
