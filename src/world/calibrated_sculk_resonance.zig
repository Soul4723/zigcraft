const std = @import("std");

// ============================================================================
// Milestone 443: Calibrated Sculk Sensor Frequency Resonance & Amethyst Tuning
// ============================================================================
//
// Calibrated Sculk Sensors (introduced in Minecraft 1.20) are crafted using
// 1 Sculk Sensor and 3 Amethyst Shards. They introduce two core mechanics:
//
// 1. Frequency Filtering via Rear Redstone Input:
//    - The rear calibration input face (opposite facing direction) accepts a
//      redstone signal of strength 1..15.
//    - The sensor filters incoming acoustic vibrations and accepts ONLY
//      vibrations whose frequency exactly matches the calibration signal.
//    - Unpowered rear input (signal 0) or non-matching signals reject vibrations.
//    - Detection range is 16 blocks (2x the 8-block range of ordinary sensors).
//    - Timing cycle: 10 game ticks (0.50s) active pulse + 1 game tick (0.05s)
//      recovery cooldown (total 11 game ticks / 0.55s).
//
// 2. Amethyst Block Acoustic Resonance Repeater Networks:
//    - When an Amethyst Block is placed adjacent (face-sharing, 6 cardinal
//      directions) to a sculk sensor detecting a vibration, the amethyst block
//      resonates with a crystalline chime.
//    - The resonating Amethyst Block re-emits a vibration of the exact same
//      frequency up to 16 blocks away.
//    - Downstream calibrated sensors tuned to that frequency detect the re-emission,
//      activating and potentially triggering their own adjacent amethyst blocks.
//    - This forms an acoustic repeater network capable of wireless frequency-coded
//      data transmission across long distances without redstone wire decay.
//
// ============================================================================

// ============================================================================
// 1. Constants & Timing Configurations
// ============================================================================

/// Number of game simulation ticks per second (20 ticks/sec).
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

/// Active emission pulse duration for a calibrated sculk sensor in game ticks (10 ticks = 0.50s).
pub const ACTIVE_DURATION_TICKS: u32 = 10;

/// Active emission pulse duration in seconds (0.50s).
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

/// Maximum number of sensors in a simulation network.
pub const MAX_NETWORK_SENSORS: usize = 64;

/// Maximum number of amethyst blocks in a simulation network.
pub const MAX_NETWORK_AMETHYST: usize = 64;

/// Maximum depth of acoustic resonance propagation chain.
pub const MAX_RESONANCE_HOPS: u32 = 32;

// ============================================================================
// 2. Vibration Frequency Table (1..15)
// ============================================================================

/// Canonical Minecraft 1.20+ Vibration Frequency Table (1..15).
pub const VibrationFrequency = enum(u4) {
    movement = 1, // step, walk, sprint
    flap = 2, // elytra, bat
    swim = 3, // swim
    glide = 4, // glide
    projectile_land = 5, // arrow hit, trident stick
    splash = 6, // splash
    projectile_shoot = 7, // bow, crossbow
    damage_hurt = 8, // entity hurt
    entity_equip = 9, // armor equipped
    entity_interact = 10, // shear, milk, trade
    block_change = 11, // trapdoor, door, lever
    block_destroy = 12, // break
    block_place = 13, // place
    entity_teleport = 14, // ender pearl, chorus fruit
    death_explosion = 15, // death, explosion

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

    /// Center of the block in floating point coordinates.
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
// 4. Calibrated Sculk Sensor Filtering Logic
// ============================================================================

/// Returns whether a vibration of `incoming_freq` passes a calibration filter of `rear_signal`.
/// The rear redstone signal strength (1..15) filters received vibration frequencies.
/// Accepts ONLY vibrations whose frequency exactly matches the input signal; rejects all
/// non-matching frequencies and unpowered (0) signals.
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
    pub fn getCalibrationFace(self: CalibratedSculkSensor) Direction {
        return self.facing.opposite();
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

    /// Advances resonance animation/state by one game tick.
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
// 6. Acoustic Repeater Network Simulation
// ============================================================================

/// Summary of an acoustic emission event in a network.
pub const EmissionResult = struct {
    sensors_triggered: u32 = 0,
    amethyst_resonated: u32 = 0,
    first_sensor_idx: ?usize = null,
};

/// Summary of a multi-hop acoustic resonance propagation chain.
pub const PropagationSummary = struct {
    total_sensors_triggered: u32 = 0,
    total_resonances: u32 = 0,
    hops_completed: u32 = 0,
    terminated_by_mismatch: bool = false,
    terminated_by_range: bool = false,
};

/// Tick advancement summary across a network.
pub const TickSummary = struct {
    sensors_active: u32 = 0,
    sensors_cooldown: u32 = 0,
    sensors_inactive: u32 = 0,
    amethysts_resonating: u32 = 0,
};

/// Acoustic repeater network managing sensors and amethyst resonance blocks.
pub const AcousticRepeaterNetwork = struct {
    sensors: [MAX_NETWORK_SENSORS]CalibratedSculkSensor = undefined,
    sensor_count: usize = 0,
    amethyst_blocks: [MAX_NETWORK_AMETHYST]AmethystBlock = undefined,
    amethyst_count: usize = 0,

    pub fn init() AcousticRepeaterNetwork {
        return .{
            .sensor_count = 0,
            .amethyst_count = 0,
        };
    }

    /// Adds a calibrated sensor to the network.
    pub fn addSensor(self: *AcousticRepeaterNetwork, sensor: CalibratedSculkSensor) !usize {
        if (self.sensor_count >= MAX_NETWORK_SENSORS) return error.NetworkFull;
        const idx = self.sensor_count;
        self.sensors[idx] = sensor;
        self.sensor_count += 1;
        return idx;
    }

    /// Adds an amethyst block to the network.
    pub fn addAmethystBlock(self: *AcousticRepeaterNetwork, block: AmethystBlock) !usize {
        if (self.amethyst_count >= MAX_NETWORK_AMETHYST) return error.NetworkFull;
        const idx = self.amethyst_count;
        self.amethyst_blocks[idx] = block;
        self.amethyst_count += 1;
        return idx;
    }

    /// Finds a sensor at block position (x, y, z).
    pub fn findSensorAt(self: *AcousticRepeaterNetwork, pos: BlockPos) ?*CalibratedSculkSensor {
        for (self.sensors[0..self.sensor_count]) |*s| {
            if (s.pos.equals(pos)) return s;
        }
        return null;
    }

    /// Finds an amethyst block at block position (x, y, z).
    pub fn findAmethystAt(self: *AcousticRepeaterNetwork, pos: BlockPos) ?*AmethystBlock {
        for (self.amethyst_blocks[0..self.amethyst_count]) |*a| {
            if (a.pos.equals(pos)) return a;
        }
        return null;
    }

    /// Finds an amethyst block adjacent to the given sensor position.
    pub fn findAdjacentAmethyst(self: *AcousticRepeaterNetwork, sensor_pos: BlockPos) ?*AmethystBlock {
        for (self.amethyst_blocks[0..self.amethyst_count]) |*a| {
            if (a.pos.isAdjacent(sensor_pos)) return a;
        }
        return null;
    }

    /// Emits a single vibration at world coordinates (vx, vy, vz).
    /// Triggers all eligible sensors in range and causes adjacent amethyst blocks to resonate.
    pub fn emitVibration(self: *AcousticRepeaterNetwork, vx: f32, vy: f32, vz: f32, freq: u4) EmissionResult {
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
    pub fn emitVibrationFromBlock(self: *AcousticRepeaterNetwork, origin: BlockPos, freq: u4) EmissionResult {
        const c = origin.center();
        return self.emitVibration(c.x, c.y, c.z, freq);
    }

    /// Simulates a full acoustic repeater resonance chain starting from an origin block.
    /// Resonant vibrations travel up to 16m from each vibrating amethyst block to downstream sensors.
    pub fn propagateResonanceChain(
        self: *AcousticRepeaterNetwork,
        origin: BlockPos,
        freq: u4,
        max_hops: u32,
    ) PropagationSummary {
        var summary = PropagationSummary{};
        const hop_limit = @min(max_hops, MAX_RESONANCE_HOPS);

        // Queue of vibration sources for chain traversal
        var current_vibrations: [MAX_NETWORK_AMETHYST]BlockPos = undefined;
        var next_vibrations: [MAX_NETWORK_AMETHYST]BlockPos = undefined;
        var current_count: usize = 0;
        var next_count: usize = 0;

        // Initial emission from origin
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

                            // Check for adjacent amethyst block
                            if (self.findAdjacentAmethyst(s.pos)) |a| {
                                _ = a.resonate(freq);
                                summary.total_resonances += 1;

                                if (next_count < MAX_NETWORK_AMETHYST) {
                                    next_vibrations[next_count] = a.pos;
                                    next_count += 1;
                                }
                            }
                        }
                    }
                }
            }

            if (!hop_triggered_any and hop > 0) {
                // If there were vibrations queued but no sensor triggered:
                // Check if any sensors were within range but rejected due to filter mismatch
                var found_out_of_range = true;
                for (current_vibrations[0..current_count]) |source_pos| {
                    const c = source_pos.center();
                    for (self.sensors[0..self.sensor_count]) |*s| {
                        if (s.isInactive()) {
                            const dist_sq = s.pos.distanceToVec3Sq(c);
                            if (dist_sq <= CALIBRATED_SENSOR_RANGE_SQ) {
                                if (!s.acceptsFrequency(freq)) {
                                    summary.terminated_by_mismatch = true;
                                    found_out_of_range = false;
                                }
                            }
                        }
                    }
                }
                if (found_out_of_range) {
                    summary.terminated_by_range = true;
                }
                break;
            }

            summary.hops_completed += 1;

            // Copy next to current
            for (next_vibrations[0..next_count], 0..) |pos, i| {
                current_vibrations[i] = pos;
            }
            current_count = next_count;
        }

        return summary;
    }

    /// Advances all sensors and amethyst blocks by one game tick (0.05s).
    pub fn tick(self: *AcousticRepeaterNetwork) TickSummary {
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
    pub fn reset(self: *AcousticRepeaterNetwork) void {
        for (self.sensors[0..self.sensor_count]) |*s| {
            s.reset();
        }
        for (self.amethyst_blocks[0..self.amethyst_count]) |*a| {
            a.reset();
        }
    }
};

/// Alias for AcousticRepeaterNetwork.
pub const ResonanceNetwork = AcousticRepeaterNetwork;

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
// 8. Unit Tests (25 Comprehensive Tests)
// ============================================================================

test "Milestone 443: All 15 canonical vibration frequencies are mapped and unique" {
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

test "Milestone 443: VibrationFrequency fromFrequency roundtrip and bounds checking" {
    for (1..16) |f_idx| {
        const f: u4 = @intCast(f_idx);
        const enum_val = VibrationFrequency.fromFrequency(f);
        try std.testing.expect(enum_val != null);
        try std.testing.expectEqual(f, enum_val.?.toFrequency());
    }
    // Out of bounds
    try std.testing.expect(VibrationFrequency.fromFrequency(0) == null);
}

test "Milestone 443: VibrationFrequency description labels for all 15 frequencies" {
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

test "Milestone 443: VibrationEvent granular actions map to correct 1..15 frequencies" {
    // 1: Movement
    try std.testing.expectEqual(@as(u4, 1), VibrationEvent.step.toFrequency());
    try std.testing.expectEqual(@as(u4, 1), VibrationEvent.walk.toFrequency());
    try std.testing.expectEqual(@as(u4, 1), VibrationEvent.sprint.toFrequency());
    // 2: Flap
    try std.testing.expectEqual(@as(u4, 2), VibrationEvent.flap_elytra.toFrequency());
    try std.testing.expectEqual(@as(u4, 2), VibrationEvent.flap_bat.toFrequency());
    // 3: Swim & 4: Glide
    try std.testing.expectEqual(@as(u4, 3), VibrationEvent.swim.toFrequency());
    try std.testing.expectEqual(@as(u4, 4), VibrationEvent.glide.toFrequency());
    // 5: Projectile Land
    try std.testing.expectEqual(@as(u4, 5), VibrationEvent.projectile_land_arrow.toFrequency());
    try std.testing.expectEqual(@as(u4, 5), VibrationEvent.projectile_land_trident.toFrequency());
    // 6: Splash & 7: Projectile Shoot
    try std.testing.expectEqual(@as(u4, 6), VibrationEvent.splash.toFrequency());
    try std.testing.expectEqual(@as(u4, 7), VibrationEvent.projectile_shoot_bow.toFrequency());
    try std.testing.expectEqual(@as(u4, 7), VibrationEvent.projectile_shoot_crossbow.toFrequency());
    // 8: Damage & 9: Equip
    try std.testing.expectEqual(@as(u4, 8), VibrationEvent.entity_hurt.toFrequency());
    try std.testing.expectEqual(@as(u4, 9), VibrationEvent.armor_equip.toFrequency());
    // 10: Entity Interact
    try std.testing.expectEqual(@as(u4, 10), VibrationEvent.entity_shear.toFrequency());
    try std.testing.expectEqual(@as(u4, 10), VibrationEvent.entity_milk.toFrequency());
    try std.testing.expectEqual(@as(u4, 10), VibrationEvent.villager_trade.toFrequency());
    // 11: Block Change
    try std.testing.expectEqual(@as(u4, 11), VibrationEvent.trapdoor_toggle.toFrequency());
    try std.testing.expectEqual(@as(u4, 11), VibrationEvent.door_toggle.toFrequency());
    try std.testing.expectEqual(@as(u4, 11), VibrationEvent.lever_flip.toFrequency());
    // 12: Block Destroy & 13: Block Place
    try std.testing.expectEqual(@as(u4, 12), VibrationEvent.block_break.toFrequency());
    try std.testing.expectEqual(@as(u4, 12), VibrationEvent.block_destroy.toFrequency());
    try std.testing.expectEqual(@as(u4, 13), VibrationEvent.block_place.toFrequency());
    // 14: Teleport & 15: Death / Explosion
    try std.testing.expectEqual(@as(u4, 14), VibrationEvent.ender_pearl_teleport.toFrequency());
    try std.testing.expectEqual(@as(u4, 14), VibrationEvent.chorus_fruit_teleport.toFrequency());
    try std.testing.expectEqual(@as(u4, 15), VibrationEvent.entity_death.toFrequency());
    try std.testing.expectEqual(@as(u4, 15), VibrationEvent.explosion.toFrequency());
}

test "Milestone 443: matchesFilter strictly accepts matching frequency for 1..15" {
    for (1..16) |s_idx| {
        const signal: u4 = @intCast(s_idx);
        try std.testing.expect(matchesFilter(signal, signal));
    }
}

test "Milestone 443: matchesFilter rejects non-matching frequencies" {
    try std.testing.expect(!matchesFilter(5, 4));
    try std.testing.expect(!matchesFilter(5, 6));
    try std.testing.expect(!matchesFilter(1, 15));
    try std.testing.expect(!matchesFilter(15, 1));
}

test "Milestone 443: matchesFilter rejects unpowered rear signal (signal 0)" {
    for (1..16) |f_idx| {
        const freq: u4 = @intCast(f_idx);
        try std.testing.expect(!matchesFilter(0, freq));
    }
}

test "Milestone 443: CalibratedSculkSensor initialization and calibration input" {
    const pos = BlockPos.init(10, 64, 20);
    var sensor = CalibratedSculkSensor.init(pos, .north, 5);

    try std.testing.expect(sensor.pos.equals(pos));
    try std.testing.expectEqual(Direction.north, sensor.facing);
    try std.testing.expectEqual(Direction.south, sensor.getCalibrationFace());
    try std.testing.expectEqual(@as(u4, 5), sensor.rear_signal);
    try std.testing.expectEqual(SensorPhase.inactive, sensor.phase);
    try std.testing.expectEqual(@as(u4, 0), sensor.output_signal);

    sensor.setRearSignal(11);
    try std.testing.expectEqual(@as(u4, 11), sensor.rear_signal);
}

test "Milestone 443: CalibratedSculkSensor accepts matching frequency and rejects non-matching" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 7);

    // Filter frequency is 7 (Projectile Shoot)
    try std.testing.expect(sensor.acceptsFrequency(7));
    try std.testing.expect(!sensor.acceptsFrequency(1));
    try std.testing.expect(!sensor.acceptsFrequency(6));
    try std.testing.expect(!sensor.acceptsFrequency(8));
    try std.testing.expect(!sensor.acceptsFrequency(15));
}

test "Milestone 443: CalibratedSculkSensor 16-block detection radius accepts vibrations within boundary" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 3);
    const center = sensor.pos.center();

    // At exact sensor center (dist 0)
    try std.testing.expect(sensor.triggerAt(center.x, center.y, center.z, 3));
    sensor.reset();

    // At distance 8.0m (ordinary sensor max range)
    try std.testing.expect(sensor.triggerAt(center.x + 8.0, center.y, center.z, 3));
    sensor.reset();

    // At distance 16.0m (calibrated sensor max boundary)
    try std.testing.expect(sensor.triggerAt(center.x + 16.0, center.y, center.z, 3));
    sensor.reset();

    // Along 3D diagonal within 16m radius: (9, 9, 9) -> 81 + 81 + 81 = 243 <= 256
    try std.testing.expect(sensor.triggerAt(center.x + 9.0, center.y + 9.0, center.z + 9.0, 3));
}

test "Milestone 443: CalibratedSculkSensor 16-block detection radius rejects vibrations outside range" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 3);
    const center = sensor.pos.center();

    // At distance 16.01m (just beyond 16.0m)
    try std.testing.expect(!sensor.triggerAt(center.x + 16.01, center.y, center.z, 3));
    try std.testing.expectEqual(SensorPhase.inactive, sensor.phase);

    // At distance 20.0m
    try std.testing.expect(!sensor.triggerAt(center.x + 20.0, center.y, center.z, 3));
    try std.testing.expectEqual(SensorPhase.inactive, sensor.phase);
}

test "Milestone 443: CalibratedSculkSensor range is exactly 2x ordinary sculk sensor (16m vs 8m)" {
    try std.testing.expectEqual(@as(f32, 16.0), CALIBRATED_SENSOR_RANGE);
    try std.testing.expectEqual(@as(f32, 8.0), ORDINARY_SCULK_RANGE);
    try std.testing.expectEqual(CALIBRATED_SENSOR_RANGE, ORDINARY_SCULK_RANGE * 2.0);
    try std.testing.expectEqual(@as(f32, 256.0), CALIBRATED_SENSOR_RANGE_SQ);
    try std.testing.expectEqual(@as(f32, 64.0), ORDINARY_SCULK_RANGE_SQ);
}

test "Milestone 443: CalibratedSculkSensor 10-tick (0.50s) active pulse duration and signal emission" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 12);
    const center = sensor.pos.center();

    try std.testing.expect(sensor.triggerAt(center.x, center.y, center.z, 12));
    try std.testing.expectEqual(SensorPhase.active, sensor.phase);
    try std.testing.expectEqual(@as(u4, 12), sensor.output_signal);
    try std.testing.expectEqual(@as(u32, 10), sensor.active_ticks);

    // Ticks 1 through 9 remain active and emitting signal strength 12
    var t: u32 = 1;
    while (t <= 9) : (t += 1) {
        _ = sensor.tick();
        try std.testing.expectEqual(SensorPhase.active, sensor.phase);
        try std.testing.expectEqual(@as(u4, 12), sensor.output_signal);
        try std.testing.expectEqual(10 - t, sensor.active_ticks);
    }
}

test "Milestone 443: CalibratedSculkSensor 1-tick (0.05s) recovery cooldown clears output signal" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 13);
    const center = sensor.pos.center();

    _ = sensor.triggerAt(center.x, center.y, center.z, 13);

    // Advance 9 ticks
    var i: u32 = 0;
    while (i < 9) : (i += 1) {
        _ = sensor.tick();
    }
    try std.testing.expectEqual(SensorPhase.active, sensor.phase);

    // 10th tick ends the active pulse and transitions into cooldown
    const transitioned = sensor.tick();
    try std.testing.expect(transitioned);
    try std.testing.expectEqual(SensorPhase.cooldown, sensor.phase);
    try std.testing.expectEqual(@as(u4, 0), sensor.output_signal);
    try std.testing.expectEqual(@as(u32, 1), sensor.recovery_ticks);
    try std.testing.expect(!sensor.canTrigger(13));
}

test "Milestone 443: CalibratedSculkSensor full 11-tick cycle returns to inactive and accepts new trigger" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 5);
    const center = sensor.pos.center();

    _ = sensor.triggerAt(center.x, center.y, center.z, 5);

    // Advance 10 ticks -> cooldown
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        _ = sensor.tick();
    }
    try std.testing.expectEqual(SensorPhase.cooldown, sensor.phase);

    // 11th tick completes recovery
    const recovered = sensor.tick();
    try std.testing.expect(recovered);
    try std.testing.expectEqual(SensorPhase.inactive, sensor.phase);
    try std.testing.expect(sensor.canTrigger(5));

    // Can immediately trigger again
    try std.testing.expect(sensor.triggerAt(center.x, center.y, center.z, 5));
    try std.testing.expectEqual(SensorPhase.active, sensor.phase);
}

test "Milestone 443: CalibratedSculkSensor blocks triggers while active or in recovery cooldown" {
    var sensor = CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 2);
    const center = sensor.pos.center();

    // Activate
    try std.testing.expect(sensor.triggerAt(center.x, center.y, center.z, 2));

    // While active, further triggers are blocked
    try std.testing.expect(!sensor.triggerAt(center.x, center.y, center.z, 2));
    try std.testing.expect(!sensor.canTrigger(2));

    // Tick to cooldown
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        _ = sensor.tick();
    }
    try std.testing.expectEqual(SensorPhase.cooldown, sensor.phase);

    // While in cooldown, further triggers are blocked
    try std.testing.expect(!sensor.triggerAt(center.x, center.y, center.z, 2));
    try std.testing.expect(!sensor.canTrigger(2));
}

test "Milestone 443: AmethystBlock 6-direction cardinal face adjacency detection" {
    const sensor_pos = BlockPos.init(10, 64, 10);

    // 6 cardinal neighbors are adjacent
    try std.testing.expect(sensor_pos.isAdjacent(sensor_pos.offset(0, 1, 0))); // up
    try std.testing.expect(sensor_pos.isAdjacent(sensor_pos.offset(0, -1, 0))); // down
    try std.testing.expect(sensor_pos.isAdjacent(sensor_pos.offset(0, 0, -1))); // north
    try std.testing.expect(sensor_pos.isAdjacent(sensor_pos.offset(0, 0, 1))); // south
    try std.testing.expect(sensor_pos.isAdjacent(sensor_pos.offset(-1, 0, 0))); // west
    try std.testing.expect(sensor_pos.isAdjacent(sensor_pos.offset(1, 0, 0))); // east

    // Diagonal blocks are NOT adjacent
    try std.testing.expect(!sensor_pos.isAdjacent(sensor_pos.offset(1, 1, 0)));
    try std.testing.expect(!sensor_pos.isAdjacent(sensor_pos.offset(1, 0, 1)));
    try std.testing.expect(!sensor_pos.isAdjacent(sensor_pos.offset(0, 1, 1)));
    try std.testing.expect(!sensor_pos.isAdjacent(sensor_pos.offset(1, 1, 1)));

    // Same block is not adjacent
    try std.testing.expect(!sensor_pos.isAdjacent(sensor_pos));
}

test "Milestone 443: AmethystBlock acoustic resonance re-emits identical vibration frequency" {
    var amethyst = AmethystBlock.init(BlockPos.init(5, 64, 5));

    try std.testing.expect(!amethyst.is_resonating);
    try std.testing.expectEqual(@as(u4, 0), amethyst.resonance_frequency);

    const resonance = amethyst.resonate(9); // Entity Equip frequency
    try std.testing.expect(amethyst.is_resonating);
    try std.testing.expectEqual(@as(u4, 9), amethyst.resonance_frequency);
    try std.testing.expectEqual(@as(u4, 9), resonance.frequency);
    try std.testing.expect(resonance.is_resonance);
    try std.testing.expect(resonance.origin_pos.equals(amethyst.pos));
}

test "Milestone 443: AmethystBlock 16-block resonance transmission range" {
    const amethyst_pos = BlockPos.init(0, 64, 0);
    const resonance = ResonantVibration{
        .origin_pos = amethyst_pos,
        .frequency = 4,
        .range = AMETHYST_RESONANCE_RANGE,
    };

    // Sensor within 16 blocks (e.g. 15 blocks along +X)
    const target_close = BlockPos.init(15, 64, 0);
    try std.testing.expect(resonance.canReachBlock(target_close));

    // Sensor at exact 16 blocks boundary
    const target_boundary = BlockPos.init(16, 64, 0);
    try std.testing.expect(resonance.canReachBlock(target_boundary));

    // Sensor at 17 blocks (beyond 16m)
    const target_far = BlockPos.init(17, 64, 0);
    try std.testing.expect(!resonance.canReachBlock(target_far));
}

test "Milestone 443: Acoustic repeater network 2-hop resonance propagation" {
    var network = AcousticRepeaterNetwork.init();

    // Node 1: Sensor at (0, 64, 0) + adjacent Amethyst at (1, 64, 0)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 6));
    _ = try network.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 64, 0)));

    // Node 2: Sensor at (16, 64, 0), 15 blocks from Amethyst 1 (within 16m)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(16, 64, 0), .north, 6));

    // Emit splash vibration (frequency 6) at origin (0, 64, 0)
    const summary = network.propagateResonanceChain(BlockPos.init(0, 64, 0), 6, 4);

    try std.testing.expectEqual(@as(u32, 2), summary.total_sensors_triggered);
    try std.testing.expectEqual(@as(u32, 1), summary.total_resonances);
    try std.testing.expect(network.sensors[0].isActive());
    try std.testing.expect(network.sensors[1].isActive());
    try std.testing.expectEqual(@as(u4, 6), network.sensors[0].output_signal);
    try std.testing.expectEqual(@as(u4, 6), network.sensors[1].output_signal);
}

test "Milestone 443: Acoustic repeater network rejects propagation when downstream frequency does not match" {
    var network = AcousticRepeaterNetwork.init();

    // Node 1: Sensor tuned to 11 (Block Change) + Amethyst at (1, 64, 0)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 11));
    _ = try network.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 64, 0)));

    // Node 2: Sensor tuned to 3 (Swim), placed 12 blocks away
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(13, 64, 0), .north, 3));

    // Emit vibration 11
    const summary = network.propagateResonanceChain(BlockPos.init(0, 64, 0), 11, 4);

    // Sensor 1 fired and Amethyst 1 resonated, but Sensor 2 rejected it!
    try std.testing.expectEqual(@as(u32, 1), summary.total_sensors_triggered);
    try std.testing.expectEqual(@as(u32, 1), summary.total_resonances);
    try std.testing.expect(summary.terminated_by_mismatch);
    try std.testing.expect(network.sensors[0].isActive());
    try std.testing.expect(network.sensors[1].isInactive());
}

test "Milestone 443: Acoustic repeater network drops vibration when distance exceeds 16 blocks" {
    var network = AcousticRepeaterNetwork.init();

    // Node 1: Sensor at (0, 64, 0) + Amethyst at (1, 64, 0)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 64, 0), .north, 8));
    _ = try network.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 64, 0)));

    // Node 2: Sensor at (20, 64, 0) -> distance from Amethyst (1, 64, 0) is 19 blocks (> 16m)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(20, 64, 0), .north, 8));

    const summary = network.propagateResonanceChain(BlockPos.init(0, 64, 0), 8, 4);

    try std.testing.expectEqual(@as(u32, 1), summary.total_sensors_triggered);
    try std.testing.expect(summary.terminated_by_range);
    try std.testing.expect(network.sensors[0].isActive());
    try std.testing.expect(network.sensors[1].isInactive());
}

test "Milestone 443: Acoustic repeater chain multi-hop propagation over 48+ blocks" {
    var network = AcousticRepeaterNetwork.init();

    // 4-Node repeater chain spaced by 16 blocks from each amethyst resonator:
    // Node 0: Sensor (0, 0, 0) + Amethyst (1, 0, 0)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 14));
    _ = try network.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 0, 0)));

    // Node 1: Sensor (17, 0, 0) (16m from Amethyst 0, 17m from origin) + Amethyst (18, 0, 0)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(17, 0, 0), .north, 14));
    _ = try network.addAmethystBlock(AmethystBlock.init(BlockPos.init(18, 0, 0)));

    // Node 2: Sensor (34, 0, 0) (16m from Amethyst 1) + Amethyst (35, 0, 0)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(34, 0, 0), .north, 14));
    _ = try network.addAmethystBlock(AmethystBlock.init(BlockPos.init(35, 0, 0)));

    // Node 3: Sensor (51, 0, 0) (16m from Amethyst 2)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(51, 0, 0), .north, 14));

    // Teleport vibration (frequency 14) at (0, 0, 0)
    const summary = network.propagateResonanceChain(BlockPos.init(0, 0, 0), 14, 8);

    try std.testing.expectEqual(@as(u32, 4), summary.total_sensors_triggered);
    try std.testing.expectEqual(@as(u32, 3), summary.total_resonances);
    try std.testing.expectEqual(@as(u32, 4), summary.hops_completed);

    // All 4 sensors in the 51-block line activated with frequency 14
    for (network.sensors[0..4]) |s| {
        try std.testing.expect(s.isActive());
        try std.testing.expectEqual(@as(u4, 14), s.output_signal);
    }
}

test "Milestone 443: Acoustic repeater network branching resonance to multiple tuned sensors" {
    var network = AcousticRepeaterNetwork.init();

    // Central transmitter: Sensor at (0, 0, 0) + Amethyst at (0, 1, 0) (above sensor)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 10));
    _ = try network.addAmethystBlock(AmethystBlock.init(BlockPos.init(0, 1, 0)));

    // Branch North: 10 blocks north, tuned to 10
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 1, -10), .south, 10));

    // Branch South: 10 blocks south, tuned to 10
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 1, 10), .north, 10));

    // Branch East: 10 blocks east, but tuned to 5 (mismatched)
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(10, 1, 0), .west, 5));

    const summary = network.propagateResonanceChain(BlockPos.init(0, 0, 0), 10, 4);

    // Central + North + South should trigger (3 total). East should reject.
    try std.testing.expectEqual(@as(u32, 3), summary.total_sensors_triggered);
    try std.testing.expect(network.sensors[0].isActive());
    try std.testing.expect(network.sensors[1].isActive());
    try std.testing.expect(network.sensors[2].isActive());
    try std.testing.expect(network.sensors[3].isInactive());
}

test "Milestone 443: Acoustic repeater network full tick cycle simulation and reset" {
    var network = AcousticRepeaterNetwork.init();
    _ = try network.addSensor(CalibratedSculkSensor.init(BlockPos.init(0, 0, 0), .north, 1));
    _ = try network.addAmethystBlock(AmethystBlock.init(BlockPos.init(1, 0, 0)));

    _ = network.emitVibrationFromBlock(BlockPos.init(0, 0, 0), 1);
    try std.testing.expect(network.sensors[0].isActive());
    try std.testing.expect(network.amethyst_blocks[0].is_resonating);

    // Tick 10 times -> transitions to cooldown
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        _ = network.tick();
    }
    try std.testing.expect(network.sensors[0].isCoolingDown());
    try std.testing.expect(!network.amethyst_blocks[0].is_resonating);

    // Tick 11th time -> inactive
    _ = network.tick();
    try std.testing.expect(network.sensors[0].isInactive());

    // Reset clears everything
    network.reset();
    try std.testing.expectEqual(@as(u4, 0), network.sensors[0].output_signal);
}
