const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

// ============================================================================
// Constants
// ============================================================================

/// Maximum tether radius from the Creaking Heart (32 blocks).
pub const MAX_TETHER_RADIUS: f32 = 32.0;

/// Squared maximum tether radius (32.0 * 32.0 = 1024.0).
pub const MAX_TETHER_RADIUS_SQ: f32 = MAX_TETHER_RADIUS * MAX_TETHER_RADIUS;

/// Minecraft nocturnal window start tick (13000 = dusk).
pub const NOCTURNAL_START_TICK: u32 = 13000;

/// Minecraft nocturnal window end tick (23000 = dawn).
pub const NOCTURNAL_END_TICK: u32 = 23000;

/// Sky light level threshold for nocturnal activation (<= 7 is dark enough for Creaking).
pub const NOCTURNAL_SKY_LIGHT_THRESHOLD: u8 = 7;

/// Length of standard Minecraft day cycle in ticks (24000).
pub const TICKS_PER_DAY: u32 = 24000;

/// Default structural health of a Creaking Heart block (20.0 HP).
pub const DEFAULT_HEART_HEALTH: f32 = 20.0;

/// Dedicated structural durability hit points of a Creaking Heart block (5 hits).
pub const DEFAULT_HEART_DURABILITY: u32 = 5;

/// Movement speed of active Creaking puppet while stalking (0.25 blocks/tick = 5.0 blocks/sec).
pub const PUPPET_STALKING_SPEED: f32 = 0.25;

/// Base melee attack damage dealt by an active Creaking puppet (3.0 HP = 1.5 hearts).
pub const PUPPET_ATTACK_DAMAGE: f32 = 3.0;

/// Attack reach distance of the Creaking puppet (2.5 blocks).
pub const PUPPET_ATTACK_REACH: f32 = 2.5;

/// Minimum particle count along the damage redirection beam (8).
pub const BEAM_PARTICLE_MIN: u32 = 8;

/// Maximum particle count along the damage redirection beam (32).
pub const BEAM_PARTICLE_MAX: u32 = 32;

/// Resin extrusion cooldown after taking a strike (100 ticks = 5.0 seconds).
pub const RESIN_EXTRUSION_COOLDOWN_TICKS: u32 = 100;

/// Gaze freeze cosine field of view threshold (0.5 ~ 60 degree cone).
pub const DEFAULT_GAZE_COS_FOV: f32 = 0.5;

// ============================================================================
// Enums & Basic Types
// ============================================================================

/// Damage source type striking the Creaking puppet or heart.
pub const DamageType = enum(u8) {
    melee,
    arrow,
    projectile,
    explosion,
    fire,
    fall,
    magic,
    block_break,
    generic,
};

/// Tree log orientation axis.
pub const LogAxis = enum(u8) {
    y = 0,
    x = 1,
    z = 2,
};

/// Discrete puppet kinematic and behavioral states.
pub const PuppetState = enum(u8) {
    dormant, // Daylight or bright light: motionless, zero velocity, cannot attack
    active_stalking, // Night or dark: unobserved, pursuing target player
    active_frozen, // Night or dark: observed by player without pumpkin, frozen in place
    despawned, // Dismantled because heart was destroyed
};

/// Event representing incoming damage directed at an entity or block.
pub const DamageEvent = struct {
    damage_type: DamageType,
    amount: f32,
    source_pos: ?[3]f32 = null,
    attacker_id: ?u32 = null,
};

/// 3D discrete block coordinate position helper.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) BlockPos {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn toArray(self: BlockPos) [3]i32 {
        return .{ self.x, self.y, self.z };
    }

    pub fn fromArray(arr: [3]i32) BlockPos {
        return .{ .x = arr[0], .y = arr[1], .z = arr[2] };
    }

    pub fn toCenterVec3(self: BlockPos) [3]f32 {
        return .{
            @as(f32, @floatFromInt(self.x)) + 0.5,
            @as(f32, @floatFromInt(self.y)) + 0.5,
            @as(f32, @floatFromInt(self.z)) + 0.5,
        };
    }

    pub fn equals(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }
};

// ============================================================================
// Damage Redirection Beam
// ============================================================================

/// Trajectory and particle vector payload connecting the Creaking puppet to its linked Creaking Heart.
pub const DamageRedirectionBeam = struct {
    origin: [3]f32,
    target: [3]f32,
    delta: [3]f32,
    distance: f32,
    direction: [3]f32,
    particle_count: u32,
    resin_clump_positions: [3][3]i32,
    resin_clump_count: u8,

    /// Samples a 3D position along the beam vector for parameterized coordinate t in [0.0, 1.0].
    pub fn samplePoint(self: DamageRedirectionBeam, t: f32) [3]f32 {
        const clamped_t = @min(1.0, @max(0.0, t));
        return .{
            self.origin[0] + self.delta[0] * clamped_t,
            self.origin[1] + self.delta[1] * clamped_t,
            self.origin[2] + self.delta[2] * clamped_t,
        };
    }

    /// Computes the exact 3D position of the particle at step index `0 <= step_idx < particle_count`.
    pub fn particlePosition(self: DamageRedirectionBeam, step_idx: u32) [3]f32 {
        if (self.particle_count <= 1) return self.origin;
        const count_f = @as(f32, @floatFromInt(self.particle_count - 1));
        const step_f = @as(f32, @floatFromInt(@min(step_idx, self.particle_count - 1)));
        const t = step_f / count_f;
        return self.samplePoint(t);
    }
};

/// Result of striking a Creaking puppet entity.
pub const DamageRedirectionResult = struct {
    damage_type: DamageType,
    absorbed_damage: f32,
    effective_damage: f32 = 0.0,
    is_invulnerable: bool = true,
    puppet_survived: bool = true,
    beam: DamageRedirectionBeam,
};

/// Computes the damage redirection beam from a puppet's hit position to the linked Creaking Heart.
pub fn computeDamageRedirectionBeam(puppet_hit_pos: [3]f32, heart_pos: [3]i32) DamageRedirectionBeam {
    const target = [3]f32{
        @as(f32, @floatFromInt(heart_pos[0])) + 0.5,
        @as(f32, @floatFromInt(heart_pos[1])) + 0.5,
        @as(f32, @floatFromInt(heart_pos[2])) + 0.5,
    };

    const dx = target[0] - puppet_hit_pos[0];
    const dy = target[1] - puppet_hit_pos[1];
    const dz = target[2] - puppet_hit_pos[2];
    const dist_sq = dx * dx + dy * dy + dz * dz;

    var distance: f32 = 0.0;
    var direction = [3]f32{ 0.0, 1.0, 0.0 };

    if (dist_sq > 0.000001) {
        distance = @sqrt(dist_sq);
        const inv = 1.0 / distance;
        direction = .{ dx * inv, dy * inv, dz * inv };
    }

    // Particle count: 8..32 particles flying from Creaking puppet to Creaking Heart
    const base_count = @as(u32, @intFromFloat(@round(distance * 0.75))) + BEAM_PARTICLE_MIN;
    const particle_count: u32 = @min(BEAM_PARTICLE_MAX, @max(BEAM_PARTICLE_MIN, base_count));

    // 3 adjacent block positions around the heart for resin clump extrusion
    const clump_positions = [3][3]i32{
        .{ heart_pos[0] + 1, heart_pos[1], heart_pos[2] },
        .{ heart_pos[0] - 1, heart_pos[1], heart_pos[2] },
        .{ heart_pos[0], heart_pos[1] + 1, heart_pos[2] },
    };

    return .{
        .origin = puppet_hit_pos,
        .target = target,
        .delta = .{ dx, dy, dz },
        .distance = distance,
        .direction = direction,
        .particle_count = particle_count,
        .resin_clump_positions = clump_positions,
        .resin_clump_count = 3,
    };
}

// ============================================================================
// Nocturnal State Machine Logic
// ============================================================================

/// Evaluates whether the current environment time/light conditions count as night / nocturnal window.
/// Active when world time ticks in 13000..23000 or sky light level <= 7.
pub fn isNight(world_time_ticks: u32, sky_light_level: u8) bool {
    const cycle_tick = world_time_ticks % TICKS_PER_DAY;
    const time_is_night = (cycle_tick >= NOCTURNAL_START_TICK and cycle_tick <= NOCTURNAL_END_TICK);
    const light_is_dark = (sky_light_level <= NOCTURNAL_SKY_LIGHT_THRESHOLD);
    return time_is_night or light_is_dark;
}

/// Evaluates whether the nocturnal window is active (is_night or active thunderstorm).
pub fn isNocturnal(world_time_ticks: u32, sky_light_level: u8, is_thunder: bool) bool {
    return isNight(world_time_ticks, sky_light_level) or is_thunder;
}

/// Checks whether an entity coordinate is within max tether radius of a heart coordinate.
pub fn isWithinTetherRadius(entity_pos: [3]f32, heart_pos: [3]i32, max_radius: f32) bool {
    const hx = @as(f32, @floatFromInt(heart_pos[0])) + 0.5;
    const hy = @as(f32, @floatFromInt(heart_pos[1])) + 0.5;
    const hz = @as(f32, @floatFromInt(heart_pos[2])) + 0.5;

    const dx = entity_pos[0] - hx;
    const dy = entity_pos[1] - hy;
    const dz = entity_pos[2] - hz;
    return (dx * dx + dy * dy + dz * dz) <= (max_radius * max_radius);
}

/// Determines whether a Creaking puppet is frozen by a player's gaze.
/// Wearing a Carved Pumpkin bypasses gaze freeze completely!
pub fn isCreakingFrozenByGaze(
    creaking_pos: [3]f32,
    player_eye_pos: [3]f32,
    player_look_dir: [3]f32,
    cos_fov_threshold: f32,
    wearing_carved_pumpkin: bool,
) bool {
    if (wearing_carved_pumpkin) {
        return false;
    }

    const dx = creaking_pos[0] - player_eye_pos[0];
    const dy = creaking_pos[1] - player_eye_pos[1];
    const dz = creaking_pos[2] - player_eye_pos[2];
    const dist_sq = dx * dx + dy * dy + dz * dz;

    if (dist_sq < 0.0001) {
        return true;
    }

    const inv_dist = 1.0 / @sqrt(dist_sq);
    const to_c_x = dx * inv_dist;
    const to_c_y = dy * inv_dist;
    const to_c_z = dz * inv_dist;

    const look_sq = player_look_dir[0] * player_look_dir[0] +
        player_look_dir[1] * player_look_dir[1] +
        player_look_dir[2] * player_look_dir[2];

    if (look_sq < 0.0001) {
        return false;
    }

    const inv_look = 1.0 / @sqrt(look_sq);
    const look_x = player_look_dir[0] * inv_look;
    const look_y = player_look_dir[1] * inv_look;
    const look_z = player_look_dir[2] * inv_look;

    const dot = to_c_x * look_x + to_c_y * look_y + to_c_z * look_z;
    return dot >= cos_fov_threshold;
}

// ============================================================================
// Creaking Puppet Entity
// ============================================================================

/// Represents a Creaking puppet entity bound to a Creaking Heart block.
pub const CreakingPuppet = struct {
    puppet_id: u32,
    heart_pos: [3]i32,
    pos: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    is_invulnerable: bool = true,
    is_alive: bool = true,
    is_dormant: bool = false,
    destroyed_by_heart: bool = false,
    is_frozen: bool = false,
    health: f32 = 1.0, // Virtual HP; puppet takes 0 direct damage from hits
    state: PuppetState = .active_stalking,
    yaw: f32 = 0.0,
    pitch: f32 = 0.0,
    attack_reach: f32 = PUPPET_ATTACK_REACH,
    attack_damage: f32 = PUPPET_ATTACK_DAMAGE,
    can_attack: bool = true,

    /// Initializes a new Creaking puppet entity linked to a Creaking Heart.
    pub fn init(puppet_id: u32, heart_pos: [3]i32, spawn_pos: [3]f32) CreakingPuppet {
        return .{
            .puppet_id = puppet_id,
            .heart_pos = heart_pos,
            .pos = spawn_pos,
            .velocity = .{ 0.0, 0.0, 0.0 },
            .is_invulnerable = true,
            .is_alive = true,
            .is_dormant = false,
            .destroyed_by_heart = false,
            .is_frozen = false,
            .health = 1.0,
            .state = .active_stalking,
            .yaw = 0.0,
            .pitch = 0.0,
            .attack_reach = PUPPET_ATTACK_REACH,
            .attack_damage = PUPPET_ATTACK_DAMAGE,
            .can_attack = true,
        };
    }

    /// Checks if the puppet is within tether radius (32 blocks) of its heart.
    pub fn isWithinTether(self: *const CreakingPuppet) bool {
        return isWithinTetherRadius(self.pos, self.heart_pos, MAX_TETHER_RADIUS);
    }

    /// Computes straight-line distance to its linked Creaking Heart center.
    pub fn distanceToHeart(self: *const CreakingPuppet) f32 {
        const hx = @as(f32, @floatFromInt(self.heart_pos[0])) + 0.5;
        const hy = @as(f32, @floatFromInt(self.heart_pos[1])) + 0.5;
        const hz = @as(f32, @floatFromInt(self.heart_pos[2])) + 0.5;
        const dx = self.pos[0] - hx;
        const dy = self.pos[1] - hy;
        const dz = self.pos[2] - hz;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    /// Computes squared distance to its linked Creaking Heart center.
    pub fn distanceSqToHeart(self: *const CreakingPuppet) f32 {
        const hx = @as(f32, @floatFromInt(self.heart_pos[0])) + 0.5;
        const hy = @as(f32, @floatFromInt(self.heart_pos[1])) + 0.5;
        const hz = @as(f32, @floatFromInt(self.heart_pos[2])) + 0.5;
        const dx = self.pos[0] - hx;
        const dy = self.pos[1] - hy;
        const dz = self.pos[2] - hz;
        return dx * dx + dy * dy + dz * dz;
    }

    /// Applies an attack or damage event to the Creaking puppet.
    /// Because the puppet is completely invulnerable to direct weapon/melee/projectile damage,
    /// effective damage is 0.0 and a particle redirection beam is emitted pointing to the heart.
    pub fn applyDamage(
        self: *CreakingPuppet,
        damage_type: DamageType,
        raw_amount: f32,
        hit_pos: ?[3]f32,
    ) DamageRedirectionResult {
        const actual_hit_pos = hit_pos orelse self.pos;
        const beam = computeDamageRedirectionBeam(actual_hit_pos, self.heart_pos);

        // Puppet remains invulnerable: virtual health is preserved, effective damage is 0.0
        self.health = 1.0;

        return .{
            .damage_type = damage_type,
            .absorbed_damage = raw_amount,
            .effective_damage = 0.0,
            .is_invulnerable = self.is_invulnerable,
            .puppet_survived = self.is_alive,
            .beam = beam,
        };
    }

    /// Immediately dismantles and despawns the puppet when its linked heart is destroyed.
    pub fn dismantle(self: *CreakingPuppet) void {
        self.is_alive = false;
        self.destroyed_by_heart = true;
        self.velocity = .{ 0.0, 0.0, 0.0 };
        self.can_attack = false;
        self.health = 0.0;
        self.state = .despawned;
    }

    /// Updates day/night state: daylight causes dormancy (zero velocity, no attacks).
    pub fn updateNocturnalState(
        self: *CreakingPuppet,
        world_time_ticks: u32,
        sky_light_level: u8,
        is_thunder: bool,
    ) void {
        if (!self.is_alive) return;

        const active = isNocturnal(world_time_ticks, sky_light_level, is_thunder);
        if (active) {
            self.is_dormant = false;
            if (self.is_frozen) {
                self.state = .active_frozen;
                self.velocity = .{ 0.0, 0.0, 0.0 };
                self.can_attack = false;
            } else {
                self.state = .active_stalking;
                self.can_attack = true;
            }
        } else {
            // Daylight dormancy: zero velocity, no attacks
            self.is_dormant = true;
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.can_attack = false;
            self.state = .dormant;
        }
    }

    /// Updates gaze freeze: freezes completely when looked at by player without carved pumpkin.
    pub fn updateGaze(
        self: *CreakingPuppet,
        player_eye_pos: [3]f32,
        player_look_dir: [3]f32,
        cos_fov_threshold: f32,
        wearing_carved_pumpkin: bool,
    ) bool {
        if (!self.is_alive) return false;
        if (self.is_dormant) {
            self.is_frozen = false;
            return false;
        }

        const frozen = isCreakingFrozenByGaze(
            self.pos,
            player_eye_pos,
            player_look_dir,
            cos_fov_threshold,
            wearing_carved_pumpkin,
        );

        self.is_frozen = frozen;
        if (frozen) {
            self.state = .active_frozen;
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.can_attack = false;
        } else {
            self.state = .active_stalking;
            self.can_attack = true;
        }
        return frozen;
    }

    /// Updates puppet kinematics: stalking pursuit when active and unobserved, motionless when dormant/frozen.
    pub fn updateKinematics(
        self: *CreakingPuppet,
        dt_seconds: f32,
        target_pos: ?[3]f32,
    ) void {
        if (!self.is_alive) return;

        // Motionless while dormant or frozen
        if (self.is_dormant or self.is_frozen) {
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.can_attack = false;
            return;
        }

        self.can_attack = true;

        if (target_pos) |target| {
            const dx = target[0] - self.pos[0];
            const dy = target[1] - self.pos[1];
            const dz = target[2] - self.pos[2];
            const dist_sq = dx * dx + dy * dy + dz * dz;

            if (dist_sq > 0.0001) {
                const dist = @sqrt(dist_sq);
                const inv = 1.0 / dist;
                const dir_x = dx * inv;
                const dir_y = dy * inv;
                const dir_z = dz * inv;

                // Set velocity towards target
                self.velocity = .{
                    dir_x * PUPPET_STALKING_SPEED,
                    dir_y * PUPPET_STALKING_SPEED,
                    dir_z * PUPPET_STALKING_SPEED,
                };

                // Proposed new position
                const proposed_pos = [3]f32{
                    self.pos[0] + self.velocity[0] * (dt_seconds * 20.0),
                    self.pos[1] + self.velocity[1] * (dt_seconds * 20.0),
                    self.pos[2] + self.velocity[2] * (dt_seconds * 20.0),
                };

                // Clamp to 32m tether radius if proposed movement would exceed boundary
                const hx = @as(f32, @floatFromInt(self.heart_pos[0])) + 0.5;
                const hy = @as(f32, @floatFromInt(self.heart_pos[1])) + 0.5;
                const hz = @as(f32, @floatFromInt(self.heart_pos[2])) + 0.5;

                const to_heart_x = proposed_pos[0] - hx;
                const to_heart_y = proposed_pos[1] - hy;
                const to_heart_z = proposed_pos[2] - hz;
                const heart_dist_sq = to_heart_x * to_heart_x + to_heart_y * to_heart_y + to_heart_z * to_heart_z;

                if (heart_dist_sq > MAX_TETHER_RADIUS_SQ) {
                    const heart_dist = @sqrt(heart_dist_sq);
                    const scale = MAX_TETHER_RADIUS / heart_dist;
                    self.pos = .{
                        hx + to_heart_x * scale,
                        hy + to_heart_y * scale,
                        hz + to_heart_z * scale,
                    };
                    self.velocity = .{ 0.0, 0.0, 0.0 };
                } else {
                    self.pos = proposed_pos;
                }

                // Compute yaw
                self.yaw = std.math.atan2(dz, dx);
            } else {
                self.velocity = .{ 0.0, 0.0, 0.0 };
            }
        } else {
            self.velocity = .{ 0.0, 0.0, 0.0 };
        }
    }

    /// Attempts to strike a target entity. Fails if dormant, frozen, dead, or out of reach.
    pub fn tryAttack(self: *const CreakingPuppet, target_pos: [3]f32) ?f32 {
        if (!self.is_alive or self.is_dormant or self.is_frozen or !self.can_attack) {
            return null;
        }

        const dx = target_pos[0] - self.pos[0];
        const dy = target_pos[1] - self.pos[1];
        const dz = target_pos[2] - self.pos[2];
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        if (dist <= self.attack_reach) {
            return self.attack_damage;
        }
        return null;
    }
};

// ============================================================================
// Creaking Heart Block State
// ============================================================================

/// Represents a Creaking Heart block in the world and its soul link to a puppet.
pub const CreakingHeart = struct {
    pos: [3]i32,
    is_natural: bool = false,
    is_active: bool = false,
    is_destroyed: bool = false,
    health: f32 = DEFAULT_HEART_HEALTH,
    max_health: f32 = DEFAULT_HEART_HEALTH,
    durability: u32 = DEFAULT_HEART_DURABILITY,
    linked_puppet_id: ?u32 = null,
    spawned_puppet: ?CreakingPuppet = null,
    resin_cooldown_ticks: u32 = 0,

    /// Initializes a Creaking Heart block state.
    pub fn init(pos: [3]i32, is_natural: bool) CreakingHeart {
        return .{
            .pos = pos,
            .is_natural = is_natural,
            .is_active = false,
            .is_destroyed = false,
            .health = DEFAULT_HEART_HEALTH,
            .max_health = DEFAULT_HEART_HEALTH,
            .durability = DEFAULT_HEART_DURABILITY,
            .linked_puppet_id = null,
            .spawned_puppet = null,
            .resin_cooldown_ticks = 0,
        };
    }

    /// Evaluates whether the Creaking Heart can activate based on log placement and time.
    /// Hand-placed hearts require being placed between pale oak logs; natural hearts can activate directly.
    pub fn canActivate(
        above_is_pale_oak_log: bool,
        below_is_pale_oak_log: bool,
        is_natural: bool,
        is_night_time: bool,
        is_thunder: bool,
    ) bool {
        const log_ok = is_natural or (above_is_pale_oak_log and below_is_pale_oak_log);
        const time_ok = is_night_time or is_thunder;
        return log_ok and time_ok;
    }

    /// Evaluates activation with log axis orientation (vertical Y-axis alignment required for logs).
    pub fn canActivateWithAxis(
        above_is_pale_oak_log: bool,
        above_axis: LogAxis,
        below_is_pale_oak_log: bool,
        below_axis: LogAxis,
        is_natural: bool,
        is_night_time: bool,
        is_thunder: bool,
    ) bool {
        const axis_ok = is_natural or (above_axis == .y and below_axis == .y);
        return axis_ok and canActivate(above_is_pale_oak_log, below_is_pale_oak_log, is_natural, is_night_time, is_thunder);
    }

    /// Evaluates activation using world BlockId constants.
    pub fn canActivateBlocks(
        above: BlockId,
        below: BlockId,
        is_natural: bool,
        is_night_time: bool,
        is_thunder: bool,
    ) bool {
        const above_ok = (above == .pale_oak_log);
        const below_ok = (below == .pale_oak_log);
        return canActivate(above_ok, below_ok, is_natural, is_night_time, is_thunder);
    }

    /// Evaluates activation using world BlockId constants and log axes.
    pub fn canActivateBlocksWithAxis(
        above: BlockId,
        above_axis: LogAxis,
        below: BlockId,
        below_axis: LogAxis,
        is_natural: bool,
        is_night_time: bool,
        is_thunder: bool,
    ) bool {
        const above_ok = (above == .pale_oak_log);
        const below_ok = (below == .pale_oak_log);
        return canActivateWithAxis(above_ok, above_axis, below_ok, below_axis, is_natural, is_night_time, is_thunder);
    }

    /// Spawns a Creaking puppet bound to this heart at an optional offset.
    pub fn spawnPuppet(self: *CreakingHeart, puppet_id: u32, offset: ?[3]f32) *CreakingPuppet {
        const off = offset orelse [3]f32{ 0.0, 0.0, 4.0 };
        const sx = @as(f32, @floatFromInt(self.pos[0])) + off[0];
        const sy = @as(f32, @floatFromInt(self.pos[1])) + off[1];
        const sz = @as(f32, @floatFromInt(self.pos[2])) + off[2];

        self.linked_puppet_id = puppet_id;
        self.spawned_puppet = CreakingPuppet.init(puppet_id, self.pos, .{ sx, sy, sz });
        return &self.spawned_puppet.?;
    }

    /// Updates activation state and spawns/despawns the linked puppet accordingly.
    pub fn updateActivation(
        self: *CreakingHeart,
        above_is_pale_oak_log: bool,
        below_is_pale_oak_log: bool,
        world_time_ticks: u32,
        sky_light_level: u8,
        is_thunder: bool,
        spawn_offset: ?[3]f32,
    ) void {
        if (self.is_destroyed) return;

        const is_noct = isNocturnal(world_time_ticks, sky_light_level, is_thunder);
        const should_be_active = canActivate(above_is_pale_oak_log, below_is_pale_oak_log, self.is_natural, is_noct, false);

        if (should_be_active) {
            self.is_active = true;
            if (self.spawned_puppet == null or (self.spawned_puppet != null and !self.spawned_puppet.?.is_alive)) {
                const next_id = (self.linked_puppet_id orelse 100) + 1;
                _ = self.spawnPuppet(next_id, spawn_offset);
            } else if (self.spawned_puppet) |*puppet| {
                puppet.updateNocturnalState(world_time_ticks, sky_light_level, is_thunder);
            }
        } else {
            self.is_active = false;
            if (self.spawned_puppet) |*puppet| {
                puppet.updateNocturnalState(world_time_ticks, sky_light_level, is_thunder);
            }
        }
    }

    /// Inflicts structural damage directly to the Creaking Heart.
    /// Returns true if the heart was destroyed.
    pub fn damageHeart(self: *CreakingHeart, amount: f32) bool {
        if (self.is_destroyed) return true;

        self.health = @max(0.0, self.health - amount);
        if (self.durability > 0) {
            self.durability -|= 1;
        }

        if (self.health <= 0.0 or self.durability == 0) {
            self.destroyHeart();
            return true;
        }
        return false;
    }

    /// Handles a block break event on the Creaking Heart.
    pub fn breakHeart(self: *CreakingHeart) void {
        self.destroyHeart();
    }

    /// Destroys the Creaking Heart and immediately dismantles the linked puppet.
    pub fn destroyHeart(self: *CreakingHeart) void {
        self.is_destroyed = true;
        self.is_active = false;
        self.health = 0.0;
        self.durability = 0;

        if (self.spawned_puppet) |*puppet| {
            puppet.dismantle();
        }
        self.spawned_puppet = null;
        self.linked_puppet_id = null;
    }

    /// Destroys the heart and dismantles both the internal and an external puppet reference.
    pub fn destroyAndDismantle(self: *CreakingHeart, external_puppet: ?*CreakingPuppet) void {
        if (external_puppet) |puppet| {
            puppet.dismantle();
        }
        self.destroyHeart();
    }

    /// Advances heart cooldown ticks.
    pub fn tick(self: *CreakingHeart, dt_ticks: u32) void {
        if (self.resin_cooldown_ticks > dt_ticks) {
            self.resin_cooldown_ticks -= dt_ticks;
        } else {
            self.resin_cooldown_ticks = 0;
        }
    }

    /// Checks if resin extrusion is available (off cooldown).
    pub fn canExtrudeResin(self: *const CreakingHeart) bool {
        return self.resin_cooldown_ticks == 0;
    }

    /// Records resin extrusion and triggers cooldown.
    pub fn recordResinExtrusion(self: *CreakingHeart) void {
        self.resin_cooldown_ticks = RESIN_EXTRUSION_COOLDOWN_TICKS;
    }
};

// ============================================================================
// Comprehensive Unit Test Suite (26 Tests)
// ============================================================================

test "1. Creaking Heart placement between pale oak logs validates link creation" {
    // Placement between two pale oak logs enables heart activation
    try std.testing.expect(CreakingHeart.canActivate(true, true, false, true, false));
    // Missing top log disables activation
    try std.testing.expect(!CreakingHeart.canActivate(false, true, false, true, false));
    // Missing bottom log disables activation
    try std.testing.expect(!CreakingHeart.canActivate(true, false, false, true, false));
    // Missing both logs disables activation
    try std.testing.expect(!CreakingHeart.canActivate(false, false, false, true, false));
}

test "2. Creaking Heart vertical Y-axis alignment for pale oak logs" {
    // Vertical Y-axis logs allow activation
    try std.testing.expect(CreakingHeart.canActivateWithAxis(true, .y, true, .y, false, true, false));
    // Misaligned horizontal logs reject activation
    try std.testing.expect(!CreakingHeart.canActivateWithAxis(true, .x, true, .y, false, true, false));
    try std.testing.expect(!CreakingHeart.canActivateWithAxis(true, .y, true, .z, false, true, false));
    try std.testing.expect(!CreakingHeart.canActivateWithAxis(true, .x, true, .z, false, true, false));
}

test "3. Creaking Heart BlockId recognition validates log sandwich" {
    try std.testing.expect(CreakingHeart.canActivateBlocks(.pale_oak_log, .pale_oak_log, false, true, false));
    try std.testing.expect(!CreakingHeart.canActivateBlocks(.wood, .pale_oak_log, false, true, false));
    try std.testing.expect(!CreakingHeart.canActivateBlocks(.cherry_log, .pale_oak_log, false, true, false));
    try std.testing.expect(!CreakingHeart.canActivateBlocks(.pale_oak_log, .stone, false, true, false));
}

test "4. Natural Pale Garden generation enables link directly without log sandwich" {
    // Natural generation in Pale Garden is exempt from log sandwich requirement
    try std.testing.expect(CreakingHeart.canActivate(false, false, true, true, false));
    try std.testing.expect(CreakingHeart.canActivateWithAxis(false, .x, false, .z, true, true, false));
    try std.testing.expect(CreakingHeart.canActivateBlocks(.stone, .air, true, true, false));
}

test "5. Puppet-heart coordinate binding and link integrity" {
    var heart = CreakingHeart.init(.{ 100, 64, 200 }, false);
    try std.testing.expectEqual(@as([3]i32, .{ 100, 64, 200 }), heart.pos);
    try std.testing.expect(heart.spawned_puppet == null);
    try std.testing.expect(heart.linked_puppet_id == null);

    const puppet = heart.spawnPuppet(42, .{ 2.0, 0.0, 5.0 });
    try std.testing.expectEqual(@as(u32, 42), puppet.puppet_id);
    try std.testing.expectEqual(@as([3]i32, .{ 100, 64, 200 }), puppet.heart_pos);
    try std.testing.expectEqual(@as(f32, 102.0), puppet.pos[0]);
    try std.testing.expectEqual(@as(f32, 64.0), puppet.pos[1]);
    try std.testing.expectEqual(@as(f32, 205.0), puppet.pos[2]);
    try std.testing.expect(puppet.is_invulnerable);
    try std.testing.expect(puppet.is_alive);
    try std.testing.expect(!puppet.destroyed_by_heart);
    try std.testing.expectEqual(@as(?u32, 42), heart.linked_puppet_id);
}

test "6. Puppet invulnerability to melee weapon strikes" {
    var puppet = CreakingPuppet.init(1, .{ 0, 64, 0 }, .{ 0.0, 64.0, 10.0 });
    try std.testing.expect(puppet.is_invulnerable);

    // Strike with netherite sword (raw 12.0 damage)
    const result = puppet.applyDamage(.melee, 12.0, null);
    try std.testing.expect(result.is_invulnerable);
    try std.testing.expectEqual(@as(f32, 12.0), result.absorbed_damage);
    try std.testing.expectEqual(@as(f32, 0.0), result.effective_damage);
    try std.testing.expect(result.puppet_survived);
    try std.testing.expect(puppet.is_alive);
    try std.testing.expectEqual(@as(f32, 1.0), puppet.health);
}

test "7. Puppet invulnerability to arrows and projectile attacks" {
    var puppet = CreakingPuppet.init(2, .{ 10, 60, 10 }, .{ 10.0, 60.0, 20.0 });

    // Arrow projectile hit (raw 9.0 damage)
    const arrow_result = puppet.applyDamage(.arrow, 9.0, .{ 10.0, 61.5, 20.0 });
    try std.testing.expect(arrow_result.is_invulnerable);
    try std.testing.expectEqual(@as(f32, 0.0), arrow_result.effective_damage);
    try std.testing.expect(puppet.is_alive);

    // Generic projectile (raw 6.5 damage)
    const proj_result = puppet.applyDamage(.projectile, 6.5, null);
    try std.testing.expectEqual(@as(f32, 0.0), proj_result.effective_damage);
    try std.testing.expect(puppet.is_alive);
}

test "8. Puppet invulnerability to explosion damage" {
    var puppet = CreakingPuppet.init(3, .{ -5, 70, -5 }, .{ -5.0, 70.0, 5.0 });

    // Massive TNT explosion (raw 65.0 damage)
    const explosion_result = puppet.applyDamage(.explosion, 65.0, null);
    try std.testing.expect(explosion_result.is_invulnerable);
    try std.testing.expectEqual(@as(f32, 0.0), explosion_result.effective_damage);
    try std.testing.expectEqual(@as(f32, 65.0), explosion_result.absorbed_damage);
    try std.testing.expect(puppet.is_alive);
    try std.testing.expectEqual(@as(f32, 1.0), puppet.health);
}

test "9. Puppet invulnerability to environmental fire and falling damage" {
    var puppet = CreakingPuppet.init(4, .{ 50, 64, 50 }, .{ 50.0, 64.0, 60.0 });

    const fire_result = puppet.applyDamage(.fire, 4.0, null);
    try std.testing.expectEqual(@as(f32, 0.0), fire_result.effective_damage);
    try std.testing.expect(puppet.is_alive);

    const fall_result = puppet.applyDamage(.fall, 20.0, null);
    try std.testing.expectEqual(@as(f32, 0.0), fall_result.effective_damage);
    try std.testing.expect(puppet.is_alive);
}

test "10. Damage redirection beam vector connecting puppet hit to heart" {
    const heart_pos = [3]i32{ 0, 64, 0 };
    const puppet_pos = [3]f32{ 0.0, 64.0, 10.0 };

    const beam = computeDamageRedirectionBeam(puppet_pos, heart_pos);
    try std.testing.expectEqual(puppet_pos, beam.origin);
    try std.testing.expectEqual(@as(f32, 0.5), beam.target[0]);
    try std.testing.expectEqual(@as(f32, 64.5), beam.target[1]);
    try std.testing.expectEqual(@as(f32, 0.5), beam.target[2]);

    // Vector points from Z=10.0 towards Z=0.5 (delta Z = -9.5)
    try std.testing.expectEqual(@as(f32, 0.5), beam.delta[0]);
    try std.testing.expectEqual(@as(f32, 0.5), beam.delta[1]);
    try std.testing.expectEqual(@as(f32, -9.5), beam.delta[2]);
}

test "11. Damage redirection beam normalized unit direction and distance" {
    const heart_pos = [3]i32{ 10, 64, 20 };
    const puppet_pos = [3]f32{ 10.5, 64.5, 30.5 }; // Exactly 10 blocks along Z axis

    const beam = computeDamageRedirectionBeam(puppet_pos, heart_pos);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), beam.distance, 0.001);

    // Direction should be (0, 0, -1)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), beam.direction[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), beam.direction[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), beam.direction[2], 0.001);
}

test "12. Damage redirection beam particle count scales with distance (8..32)" {
    const heart_pos = [3]i32{ 0, 64, 0 };

    // Hit at heart center (0 blocks away) -> clamped to minimum 8 particles
    const beam_min = computeDamageRedirectionBeam(.{ 0.5, 64.5, 0.5 }, heart_pos);
    try std.testing.expectEqual(BEAM_PARTICLE_MIN, beam_min.particle_count);

    // Close hit (1 block away) -> 9 particles
    const beam_close = computeDamageRedirectionBeam(.{ 0.5, 64.5, 1.5 }, heart_pos);
    try std.testing.expectEqual(@as(u32, 9), beam_close.particle_count);

    // Far hit (32+ blocks away) -> clamped to maximum 32 particles
    const beam_far = computeDamageRedirectionBeam(.{ 0.5, 64.5, 40.5 }, heart_pos);
    try std.testing.expectEqual(BEAM_PARTICLE_MAX, beam_far.particle_count);
}

test "13. Damage redirection beam particle trail interpolation points" {
    const heart_pos = [3]i32{ 0, 0, 0 };
    const puppet_pos = [3]f32{ 10.5, 0.5, 0.5 };
    const beam = computeDamageRedirectionBeam(puppet_pos, heart_pos);

    // Start point t=0.0 matches origin
    const p_start = beam.samplePoint(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), p_start[0], 0.001);

    // Mid point t=0.5 is halfway between 10.5 and 0.5 -> 5.5
    const p_mid = beam.samplePoint(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 5.5), p_mid[0], 0.001);

    // End point t=1.0 matches heart center 0.5
    const p_end = beam.samplePoint(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), p_end[0], 0.001);

    // First and last particle indices
    const first_part = beam.particlePosition(0);
    try std.testing.expectApproxEqAbs(puppet_pos[0], first_part[0], 0.001);
    const last_part = beam.particlePosition(beam.particle_count - 1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), last_part[0], 0.001);
}

test "14. Damage redirection beam resin clump coordinates on adjacent logs" {
    const heart_pos = [3]i32{ 15, 70, -20 };
    const beam = computeDamageRedirectionBeam(.{ 15.0, 70.0, -10.0 }, heart_pos);

    try std.testing.expectEqual(@as(u8, 3), beam.resin_clump_count);
    try std.testing.expectEqual(@as([3]i32, .{ 16, 70, -20 }), beam.resin_clump_positions[0]);
    try std.testing.expectEqual(@as([3]i32, .{ 14, 70, -20 }), beam.resin_clump_positions[1]);
    try std.testing.expectEqual(@as([3]i32, .{ 15, 71, -20 }), beam.resin_clump_positions[2]);
}

test "15. Creaking Heart structural durability degradation upon direct damage" {
    var heart = CreakingHeart.init(.{ 0, 64, 0 }, true);
    try std.testing.expectEqual(DEFAULT_HEART_HEALTH, heart.health);
    try std.testing.expectEqual(DEFAULT_HEART_DURABILITY, heart.durability);

    // Strike 1: dealt 4.0 damage
    const destroyed1 = heart.damageHeart(4.0);
    try std.testing.expect(!destroyed1);
    try std.testing.expectEqual(@as(f32, 16.0), heart.health);
    try std.testing.expectEqual(@as(u32, 4), heart.durability);

    // Strike 2: dealt 6.0 damage
    const destroyed2 = heart.damageHeart(6.0);
    try std.testing.expect(!destroyed2);
    try std.testing.expectEqual(@as(f32, 10.0), heart.health);
    try std.testing.expectEqual(@as(u32, 3), heart.durability);
}

test "16. Creaking Heart destruction dismantles and despawns puppet (is_alive=false, destroyed_by_heart=true)" {
    var heart = CreakingHeart.init(.{ 0, 64, 0 }, true);
    _ = heart.spawnPuppet(77, .{ 0.0, 0.0, 8.0 });
    try std.testing.expect(heart.spawned_puppet != null);
    try std.testing.expect(heart.spawned_puppet.?.is_alive);

    // Inflict fatal damage to heart (20.0 damage)
    const destroyed = heart.damageHeart(20.0);
    try std.testing.expect(destroyed);
    try std.testing.expect(heart.is_destroyed);
    try std.testing.expect(!heart.is_active);
    try std.testing.expect(heart.spawned_puppet == null);
    try std.testing.expect(heart.linked_puppet_id == null);
}

test "17. Heart block break event dismantles and despawns puppet" {
    var heart = CreakingHeart.init(.{ 10, 64, 10 }, true);
    var puppet = CreakingPuppet.init(99, heart.pos, .{ 10.0, 64.0, 15.0 });

    try std.testing.expect(puppet.is_alive);
    try std.testing.expect(!puppet.destroyed_by_heart);

    // Heart is mined/broken
    heart.destroyAndDismantle(&puppet);

    try std.testing.expect(heart.is_destroyed);
    try std.testing.expect(!puppet.is_alive);
    try std.testing.expect(puppet.destroyed_by_heart);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[2]);
    try std.testing.expect(!puppet.can_attack);
    try std.testing.expectEqual(PuppetState.despawned, puppet.state);
}

test "18. Nocturnal active window: world time ticks 13000..23000" {
    // Dusk (tick 13000)
    try std.testing.expect(isNight(13000, 15));
    // Midnight (tick 18000)
    try std.testing.expect(isNight(18000, 15));
    // Dawn boundary (tick 23000)
    try std.testing.expect(isNight(23000, 15));

    // Midday (tick 6000) with bright sky light (15) is not night
    try std.testing.expect(!isNight(6000, 15));
    // Sunrise (tick 1000) is not night
    try std.testing.expect(!isNight(1000, 15));
    // Morning (tick 23500) is not night
    try std.testing.expect(!isNight(23500, 15));
}

test "19. Nocturnal active window: sky light level <= 7 enables active state at noon" {
    // Midday (tick 6000) but inside dark canopy / cave with sky light 7
    try std.testing.expect(isNight(6000, 7));
    try std.testing.expect(isNight(6000, 4));
    try std.testing.expect(isNight(6000, 0));

    // Midday with sky light 8 is not active
    try std.testing.expect(!isNight(6000, 8));
}

test "20. Nocturnal active window: thunderstorm enables active state in daylight" {
    // Daytime tick 6000 with sky light 10, but during thunderstorm
    try std.testing.expect(isNocturnal(6000, 10, true));
    // Without thunder, daytime tick 6000 is inactive
    try std.testing.expect(!isNocturnal(6000, 10, false));
}

test "21. Daylight dormancy: time < 13000 or > 23000 with sky light > 7 enters dormant state" {
    var puppet = CreakingPuppet.init(10, .{ 0, 64, 0 }, .{ 0.0, 64.0, 5.0 });

    // Daytime tick 6000, sky light 15 -> enters dormancy
    puppet.updateNocturnalState(6000, 15, false);
    try std.testing.expect(puppet.is_dormant);
    try std.testing.expectEqual(PuppetState.dormant, puppet.state);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[2]);
    try std.testing.expect(!puppet.can_attack);

    // Night falls (tick 14000) -> exits dormancy
    puppet.updateNocturnalState(14000, 15, false);
    try std.testing.expect(!puppet.is_dormant);
    try std.testing.expectEqual(PuppetState.active_stalking, puppet.state);
    try std.testing.expect(puppet.can_attack);
}

test "22. Daylight dormancy enforces zero velocity and disables attacks" {
    var puppet = CreakingPuppet.init(11, .{ 0, 64, 0 }, .{ 0.0, 64.0, 5.0 });
    puppet.updateNocturnalState(5000, 15, false); // Enter dormancy

    // Attempt kinematics update toward target at (0, 64, 6)
    puppet.updateKinematics(0.05, .{ 0.0, 64.0, 6.0 });
    // Velocity must remain strictly zero
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[2]);
    // Position must not have changed
    try std.testing.expectEqual(@as(f32, 5.0), puppet.pos[2]);

    // Attack attempt must fail
    const attack = puppet.tryAttack(.{ 0.0, 64.0, 5.5 });
    try std.testing.expect(attack == null);
}

test "23. Kinematics: active unobserved puppet stalks towards target player" {
    var puppet = CreakingPuppet.init(12, .{ 0, 64, 0 }, .{ 0.0, 64.0, 5.0 });
    puppet.updateNocturnalState(18000, 4, false); // Nighttime active

    // Target player at (0, 64, 15)
    puppet.updateKinematics(0.05, .{ 0.0, 64.0, 15.0 });

    // Puppet moves along +Z direction
    try std.testing.expect(puppet.velocity[2] > 0.0);
    try std.testing.expect(puppet.pos[2] > 5.0);
    try std.testing.expect(puppet.can_attack);

    // Attack within reach (target 1 block away)
    const attack = puppet.tryAttack(.{ 0.0, 64.0, puppet.pos[2] + 1.0 });
    try std.testing.expect(attack != null);
    try std.testing.expectEqual(PUPPET_ATTACK_DAMAGE, attack.?);
}

test "24. Kinematics: player looking at puppet freezes it in place with zero velocity" {
    var puppet = CreakingPuppet.init(13, .{ 0, 64, 0 }, .{ 0.0, 1.6, 10.0 });
    puppet.updateNocturnalState(18000, 4, false); // Nighttime active

    const player_eye = [3]f32{ 0.0, 1.6, 0.0 };
    const player_look = [3]f32{ 0.0, 0.0, 1.0 }; // Looking directly at puppet

    const frozen = puppet.updateGaze(player_eye, player_look, DEFAULT_GAZE_COS_FOV, false);
    try std.testing.expect(frozen);
    try std.testing.expect(puppet.is_frozen);
    try std.testing.expectEqual(PuppetState.active_frozen, puppet.state);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.velocity[2]);
    try std.testing.expect(!puppet.can_attack);

    // Kinematics update while frozen should not move
    puppet.updateKinematics(0.05, player_eye);
    try std.testing.expectEqual(@as(f32, 10.0), puppet.pos[2]);
}

test "25. Kinematics: carved pumpkin bypasses gaze freeze allowing stalking" {
    var puppet = CreakingPuppet.init(14, .{ 0, 64, 0 }, .{ 0.0, 1.6, 10.0 });
    puppet.updateNocturnalState(18000, 4, false); // Nighttime active

    const player_eye = [3]f32{ 0.0, 1.6, 0.0 };
    const player_look = [3]f32{ 0.0, 0.0, 1.0 }; // Looking directly at puppet

    // Player wearing carved pumpkin: freeze is bypassed!
    const frozen = puppet.updateGaze(player_eye, player_look, DEFAULT_GAZE_COS_FOV, true);
    try std.testing.expect(!frozen);
    try std.testing.expect(!puppet.is_frozen);
    try std.testing.expectEqual(PuppetState.active_stalking, puppet.state);
    try std.testing.expect(puppet.can_attack);
}

test "26. Kinematics: puppet movement is clamped to 32-block tether radius" {
    var puppet = CreakingPuppet.init(15, .{ 0, 64, 0 }, .{ 0.0, 64.0, 31.5 });
    puppet.updateNocturnalState(18000, 4, false);

    // Try to move far beyond 32m radius (target at 100m)
    puppet.updateKinematics(1.0, .{ 0.0, 64.0, 100.0 });

    // Distance to heart must not exceed 32.0m + small epsilon
    const dist = puppet.distanceToHeart();
    try std.testing.expect(dist <= MAX_TETHER_RADIUS + 0.01);
    try std.testing.expect(puppet.isWithinTether());
}

test "27. Creaking Heart resin extrusion cooldown ticks and resets" {
    var heart = CreakingHeart.init(.{ 0, 64, 0 }, true);
    try std.testing.expect(heart.canExtrudeResin());

    // Record extrusion
    heart.recordResinExtrusion();
    try std.testing.expect(!heart.canExtrudeResin());
    try std.testing.expectEqual(RESIN_EXTRUSION_COOLDOWN_TICKS, heart.resin_cooldown_ticks);

    // Tick 40 ticks
    heart.tick(40);
    try std.testing.expect(!heart.canExtrudeResin());
    try std.testing.expectEqual(@as(u32, 60), heart.resin_cooldown_ticks);

    // Tick 60 ticks -> resets
    heart.tick(60);
    try std.testing.expect(heart.canExtrudeResin());
    try std.testing.expectEqual(@as(u32, 0), heart.resin_cooldown_ticks);
}
