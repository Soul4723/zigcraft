//! Milestone 531: Creaking Heart Damage Link & Invulnerability Particles
//!
//! Provides deterministic mechanics for:
//! 1. Creaking Entity Invulnerability:
//!    - Mob entity cannot take direct damage (`is_invulnerable = true`).
//!    - Health never decreases from player melee, arrows, trident strikes, or explosions.
//!    - Direct attacks deal 0.0 damage to the Creaking puppet.
//! 2. Resonant Particle Damage Link:
//!    - Calculates the 3D trajectory vector between Creaking puppet position and bound Creaking Heart block (`heart_pos`).
//!    - Emits a resonant particle beam along that vector connecting puppet to heart with orange/amber resin particles (`resin_trail_particles`).
//!    - Redirects hit to Creaking Heart block: deals 1 damage point (Creaking Heart max health 5.0 HP).
//!    - Axe damage bonus: Axe strikes deal 2 damage points to the heart (breaking it faster).
//! 3. Heart Destruction & Puppet Dissolution:
//!    - When Creaking Heart health reaches 0 (or is mined/broken):
//!      - All Creaking puppets linked to that heart immediately dissolve (`is_dissolved = true`).
//!      - Emits puppet dissolution crumbling sound cue: `SoundEffect.creaking_crumble`.
//!      - Spawns crumbling resin/wood particle bursts.
//!      - Puppet drops 0 experience and 0 mob drops upon dissolution.
//! 4. Nocturnal Activation & Day Dormancy:
//!    - Creaking Heart activates at night (game tick 13,000..23,000 or skylight <= 7) and can spawn 1 Creaking within 32m if none active.
//!    - At dawn (tick 23,000 / day light > 7), heart goes dormant and active puppet automatically dissolves.

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Maximum health hit points of a Creaking Heart block (5.0 HP = 5 standard hits).
pub const CREAKING_HEART_MAX_HEALTH: f32 = 5.0;

/// Standard damage inflicted on a Creaking Heart from redirected strikes (1.0 HP).
pub const STANDARD_HEART_DAMAGE: f32 = 1.0;

/// Bonus damage inflicted on a Creaking Heart by axe weapon strikes (2.0 HP total).
pub const AXE_HEART_DAMAGE: f32 = 2.0;

/// Virtual health hit points of a Creaking puppet entity (1.0 HP; puppet never takes direct damage).
pub const CREAKING_PUPPET_VIRTUAL_HEALTH: f32 = 1.0;

/// Maximum tether radius from the Creaking Heart (32.0 blocks).
pub const MAX_TETHER_RADIUS: f32 = 32.0;

/// Squared maximum tether radius (32.0 * 32.0 = 1024.0 blocks^2).
pub const MAX_TETHER_RADIUS_SQ: f32 = MAX_TETHER_RADIUS * MAX_TETHER_RADIUS;

/// Minecraft nocturnal cycle start tick (13,000 = dusk).
pub const NOCTURNAL_START_TICK: u32 = 13000;

/// Minecraft nocturnal cycle end tick (23,000 = dawn).
pub const NOCTURNAL_END_TICK: u32 = 23000;

/// Length of standard Minecraft day cycle in game ticks (24,000 ticks).
pub const TICKS_PER_DAY: u32 = 24000;

/// Maximum skylight level allowing nocturnal Creaking Heart activation (skylight <= 7).
pub const NOCTURNAL_SKYLIGHT_THRESHOLD: u8 = 7;

/// Minimum particle count along the resonant damage redirection beam (8 particles).
pub const BEAM_PARTICLE_MIN: u32 = 8;

/// Maximum particle count along the resonant damage redirection beam (32 particles).
pub const BEAM_PARTICLE_MAX: u32 = 32;

/// Standard particle count emitted during puppet crumbling dissolution (40 particles).
pub const CRUMBLE_BURST_PARTICLE_COUNT: u32 = 40;

/// Wood particle count in crumbling burst.
pub const CRUMBLE_WOOD_PARTICLES: u32 = 20;

/// Resin particle count in crumbling burst.
pub const CRUMBLE_RESIN_PARTICLES: u32 = 20;

/// Experience points dropped on Creaking puppet dissolution (strictly 0 XP).
pub const XP_DROPS_ON_DISSOLUTION: u32 = 0;

/// Mob item drops count on Creaking puppet dissolution (strictly 0 drops).
pub const MOB_DROPS_COUNT_ON_DISSOLUTION: u32 = 0;

/// Orange/Amber color RGBA for resonant resin trail particles.
pub const RESIN_TRAIL_COLOR_RGBA: [4]f32 = .{ 1.0, 0.55, 0.05, 0.95 };

/// Pale oak wood crumble color RGBA.
pub const WOOD_CRUMBLE_COLOR_RGBA: [4]f32 = .{ 0.78, 0.74, 0.70, 1.0 };

/// Resin clump crumble color RGBA.
pub const RESIN_CRUMBLE_COLOR_RGBA: [4]f32 = .{ 0.95, 0.48, 0.05, 0.9 };

// ============================================================================
// Enums & Types
// ============================================================================

/// Incoming damage source type.
pub const DamageSourceType = enum(u8) {
    melee,
    arrow,
    trident,
    explosion,
    fire,
    fall,
    magic,
    block_break,
    generic,

    pub fn isDirectPlayerAttack(self: DamageSourceType) bool {
        return self == .melee or self == .arrow or self == .trident;
    }
};

/// Weapon category used by attacker.
pub const WeaponCategory = enum(u8) {
    unarmed,
    sword,
    axe,
    pickaxe,
    shovel,
    hoe,
    bow,
    crossbow,
    trident,
    other,

    pub fn isAxe(self: WeaponCategory) bool {
        return self == .axe;
    }
};

/// Sound effects emitted during Creaking and Creaking Heart events.
pub const SoundEffect = enum(u8) {
    none = 0,
    creaking_crumble, // Emitted upon puppet dissolution
    creaking_strike_redirect, // Emitted when puppet hit redirects to heart
    creaking_heart_hurt, // Emitted when heart takes damage
    creaking_heart_break, // Emitted when heart is destroyed or broken
    creaking_spawn, // Emitted when nocturnal puppet spawns
    resin_burst, // Emitted during particle burst
};

/// Particle classifications for Creaking mechanics.
pub const ParticleKind = enum(u8) {
    resin_trail_particles, // Orange/amber resin beam particles connecting puppet to heart
    resin_crumble, // Resin fragment particles on dissolution
    pale_oak_wood_crumble, // Wood splinters on dissolution
};

/// Reason for puppet dissolution.
pub const DissolutionReason = enum(u8) {
    heart_destroyed, // Heart health reduced to 0 by redirected strikes
    heart_broken, // Heart mined or block broken by player
    dawn_dormancy, // Day broke (time >= 23,000 or skylight > 7)
    command_clear, // Entity removed by world cleanup
};

/// Single resonant resin trail particle payload along the trajectory vector.
pub const ResinTrailParticle = struct {
    pos: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    color_rgba: [4]f32 = RESIN_TRAIL_COLOR_RGBA,
    lifetime_ticks: u16 = 20,
    scale: f32 = 0.25,
};

/// Single crumbling debris particle emitted during puppet dissolution.
pub const CrumbleParticle = struct {
    pos: [3]f32,
    velocity: [3]f32,
    particle_kind: ParticleKind,
    color_rgba: [4]f32,
    lifetime_ticks: u16 = 30,
    scale: f32 = 0.35,
};

/// Trajectory vector and resonant particle beam linking puppet to heart.
pub const TrajectoryParticleBeam = struct {
    origin: [3]f32, // Puppet position / hit position
    target: [3]f32, // Center of bound Creaking Heart block
    delta: [3]f32, // target - origin
    distance: f32, // Euclidean 3D distance
    direction: [3]f32, // Normalized unit vector
    particle_count: u32,
    particle_kind: ParticleKind = .resin_trail_particles,
    color_rgba: [4]f32 = RESIN_TRAIL_COLOR_RGBA,

    /// Samples a 3D coordinate along the trajectory vector for normalized scalar t in [0.0, 1.0].
    pub fn samplePoint(self: TrajectoryParticleBeam, t: f32) [3]f32 {
        const clamped_t = @min(1.0, @max(0.0, t));
        return .{
            self.origin[0] + self.delta[0] * clamped_t,
            self.origin[1] + self.delta[1] * clamped_t,
            self.origin[2] + self.delta[2] * clamped_t,
        };
    }

    /// Computes the exact 3D position of particle index `0 <= step_idx < particle_count`.
    pub fn particlePosition(self: TrajectoryParticleBeam, step_idx: u32) [3]f32 {
        if (self.particle_count <= 1) return self.origin;
        const total_steps = @as(f32, @floatFromInt(self.particle_count - 1));
        const current_step = @as(f32, @floatFromInt(@min(step_idx, self.particle_count - 1)));
        const t = current_step / total_steps;
        return self.samplePoint(t);
    }

    /// Constructs an individual resin trail particle at the given step index.
    pub fn getParticle(self: TrajectoryParticleBeam, step_idx: u32) ResinTrailParticle {
        const p_pos = self.particlePosition(step_idx);
        return .{
            .pos = p_pos,
            .velocity = .{
                self.direction[0] * 0.1,
                self.direction[1] * 0.1,
                self.direction[2] * 0.1,
            },
            .color_rgba = self.color_rgba,
            .lifetime_ticks = 20,
            .scale = 0.25,
        };
    }
};

/// Burst of resin and wood debris particles generated on puppet dissolution.
pub const CrumbleBurst = struct {
    center: [3]f32,
    wood_particles: u32 = CRUMBLE_WOOD_PARTICLES,
    resin_particles: u32 = CRUMBLE_RESIN_PARTICLES,
    total_particles: u32 = CRUMBLE_BURST_PARTICLE_COUNT,
    sound_effect: SoundEffect = .creaking_crumble,

    /// Generates a deterministic crumble particle at index `i`.
    pub fn sampleParticle(self: CrumbleBurst, index: u32) CrumbleParticle {
        const is_resin = (index % 2 == 0);
        const idx_f = @as(f32, @floatFromInt(index));
        const phi = idx_f * 2.399963; // golden ratio angle
        const vy = ((idx_f * 0.05) - 1.0) * 0.2 + 0.15;
        const vx = @cos(phi) * 0.25;
        const vz = @sin(phi) * 0.25;

        return .{
            .pos = .{
                self.center[0] + vx * 0.5,
                self.center[1] + 1.35 + vy * 0.5,
                self.center[2] + vz * 0.5,
            },
            .velocity = .{ vx, vy, vz },
            .particle_kind = if (is_resin) .resin_crumble else .pale_oak_wood_crumble,
            .color_rgba = if (is_resin) RESIN_CRUMBLE_COLOR_RGBA else WOOD_CRUMBLE_COLOR_RGBA,
            .lifetime_ticks = 30,
            .scale = if (is_resin) 0.3 else 0.4,
        };
    }
};

/// Outcome of striking a Creaking puppet entity.
pub const DamageLinkOutcome = struct {
    damage_source: DamageSourceType,
    weapon: WeaponCategory,
    raw_damage: f32,
    puppet_damage_taken: f32 = 0.0, // Strictly 0.0 (invulnerable)
    is_invulnerable: bool = true,
    puppet_survived: bool = true,
    puppet_dissolved: bool = false,
    heart_damage_dealt: f32, // 1.0 or 2.0 (axe bonus)
    heart_remaining_health: f32,
    heart_destroyed: bool = false,
    beam: TrajectoryParticleBeam,
    sound_cue: ?SoundEffect = null,
    crumble_burst: ?CrumbleBurst = null,
    experience_dropped: u32 = 0,
    drops_count: u32 = 0,
};

/// Outcome of a puppet dissolution event.
pub const DissolutionOutcome = struct {
    puppet_id: u32,
    reason: DissolutionReason,
    sound_cue: SoundEffect = .creaking_crumble,
    crumble_burst: CrumbleBurst,
    experience_dropped: u32 = XP_DROPS_ON_DISSOLUTION,
    drops_count: u32 = MOB_DROPS_COUNT_ON_DISSOLUTION,
};

// ============================================================================
// Math & Trajectory Helpers
// ============================================================================

/// Calculates the 3D trajectory vector between an entity position and a block coordinate center.
pub fn calculateTrajectory(from_pos: [3]f32, heart_block_pos: [3]i32) TrajectoryParticleBeam {
    const target = [3]f32{
        @as(f32, @floatFromInt(heart_block_pos[0])) + 0.5,
        @as(f32, @floatFromInt(heart_block_pos[1])) + 0.5,
        @as(f32, @floatFromInt(heart_block_pos[2])) + 0.5,
    };

    const dx = target[0] - from_pos[0];
    const dy = target[1] - from_pos[1];
    const dz = target[2] - from_pos[2];
    const dist_sq = dx * dx + dy * dy + dz * dz;

    var distance: f32 = 0.0;
    var direction = [3]f32{ 0.0, 1.0, 0.0 };

    if (dist_sq > 0.000001) {
        distance = @sqrt(dist_sq);
        const inv = 1.0 / distance;
        direction = .{ dx * inv, dy * inv, dz * inv };
    }

    // Particle count: 8..32 particles scaling with distance
    const base_count = @as(u32, @intFromFloat(@round(distance * 0.75))) + BEAM_PARTICLE_MIN;
    const particle_count: u32 = @min(BEAM_PARTICLE_MAX, @max(BEAM_PARTICLE_MIN, base_count));

    return .{
        .origin = from_pos,
        .target = target,
        .delta = .{ dx, dy, dz },
        .distance = distance,
        .direction = direction,
        .particle_count = particle_count,
        .particle_kind = .resin_trail_particles,
        .color_rgba = RESIN_TRAIL_COLOR_RGBA,
    };
}

/// Calculates damage applied to Creaking Heart: 2.0 HP for axes, 1.0 HP for other weapons/damage.
pub fn calculateHeartDamage(weapon: WeaponCategory) f32 {
    if (weapon.isAxe()) {
        return AXE_HEART_DAMAGE;
    }
    return STANDARD_HEART_DAMAGE;
}

/// Evaluates if the current world time and skylight conditions qualify as nocturnal active window.
/// Active when tick is within 13,000..23,000 OR skylight <= 7 (or thunderstorm).
pub fn isNocturnalActive(world_time_ticks: u32, sky_light: u8, is_thunder: bool) bool {
    const cycle_tick = world_time_ticks % TICKS_PER_DAY;
    const time_is_night = (cycle_tick >= NOCTURNAL_START_TICK and cycle_tick <= NOCTURNAL_END_TICK);
    const light_is_dark = (sky_light <= NOCTURNAL_SKYLIGHT_THRESHOLD);
    return time_is_night or light_is_dark or is_thunder;
}

/// Evaluates whether dawn has arrived (tick 23,000 / skylight > 7 with no thunderstorm).
pub fn isDawnDormancy(world_time_ticks: u32, sky_light: u8, is_thunder: bool) bool {
    return !isNocturnalActive(world_time_ticks, sky_light, is_thunder);
}

// ============================================================================
// Creaking Puppet Entity
// ============================================================================

/// Creaking mob entity bound to a Creaking Heart.
pub const CreakingPuppetEntity = struct {
    id: u32,
    heart_pos: [3]i32,
    pos: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    is_invulnerable: bool = true, // Creaking mob entity cannot take direct damage
    is_alive: bool = true,
    is_dissolved: bool = false, // True once dissolved
    is_dormant: bool = false,
    health: f32 = CREAKING_PUPPET_VIRTUAL_HEALTH, // Health never decreases from strikes
    experience_drop: u32 = XP_DROPS_ON_DISSOLUTION, // 0 XP
    drops_count: u32 = MOB_DROPS_COUNT_ON_DISSOLUTION, // 0 mob drops

    /// Creates a new Creaking puppet entity bound to a Creaking Heart coordinate.
    pub fn init(id: u32, heart_pos: [3]i32, pos: [3]f32) CreakingPuppetEntity {
        return .{
            .id = id,
            .heart_pos = heart_pos,
            .pos = pos,
            .velocity = .{ 0.0, 0.0, 0.0 },
            .is_invulnerable = true,
            .is_alive = true,
            .is_dissolved = false,
            .is_dormant = false,
            .health = CREAKING_PUPPET_VIRTUAL_HEALTH,
            .experience_drop = XP_DROPS_ON_DISSOLUTION,
            .drops_count = MOB_DROPS_COUNT_ON_DISSOLUTION,
        };
    }

    /// Evaluates if the puppet is within 32m maximum tether radius of its heart.
    pub fn isWithinTetherRadius(self: *const CreakingPuppetEntity) bool {
        const hx = @as(f32, @floatFromInt(self.heart_pos[0])) + 0.5;
        const hy = @as(f32, @floatFromInt(self.heart_pos[1])) + 0.5;
        const hz = @as(f32, @floatFromInt(self.heart_pos[2])) + 0.5;
        const dx = self.pos[0] - hx;
        const dy = self.pos[1] - hy;
        const dz = self.pos[2] - hz;
        return (dx * dx + dy * dy + dz * dz) <= MAX_TETHER_RADIUS_SQ;
    }

    /// Computes straight-line 3D Euclidean distance to heart center.
    pub fn distanceToHeart(self: *const CreakingPuppetEntity) f32 {
        const hx = @as(f32, @floatFromInt(self.heart_pos[0])) + 0.5;
        const hy = @as(f32, @floatFromInt(self.heart_pos[1])) + 0.5;
        const hz = @as(f32, @floatFromInt(self.heart_pos[2])) + 0.5;
        const dx = self.pos[0] - hx;
        const dy = self.pos[1] - hy;
        const dz = self.pos[2] - hz;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    /// Receives a direct attack strike.
    /// Puppet is completely invulnerable: deals 0.0 damage to puppet, health never decreases.
    pub fn receiveDirectAttack(
        self: *CreakingPuppetEntity,
        raw_damage: f32,
    ) f32 {
        _ = raw_damage;
        // Direct attacks deal 0.0 damage to the Creaking puppet.
        // Health is strictly maintained at its virtual maximum.
        self.health = CREAKING_PUPPET_VIRTUAL_HEALTH;
        return 0.0;
    }

    /// Immediately dissolves the puppet entity (heart destroyed/broken or dawn dormancy).
    pub fn dissolve(self: *CreakingPuppetEntity, reason: DissolutionReason) DissolutionOutcome {
        self.is_alive = false;
        self.is_dissolved = true;
        self.health = 0.0;
        self.velocity = .{ 0.0, 0.0, 0.0 };

        const burst = CrumbleBurst{
            .center = self.pos,
            .wood_particles = CRUMBLE_WOOD_PARTICLES,
            .resin_particles = CRUMBLE_RESIN_PARTICLES,
            .total_particles = CRUMBLE_BURST_PARTICLE_COUNT,
            .sound_effect = .creaking_crumble,
        };

        return .{
            .puppet_id = self.id,
            .reason = reason,
            .sound_cue = .creaking_crumble,
            .crumble_burst = burst,
            .experience_dropped = 0,
            .drops_count = 0,
        };
    }
};

// ============================================================================
// Creaking Heart Block
// ============================================================================

/// Creaking Heart block state machine and puppet controller.
pub const CreakingHeartBlock = struct {
    pos: [3]i32,
    health: f32 = CREAKING_HEART_MAX_HEALTH, // Max health 5.0 HP
    is_active: bool = false,
    is_broken: bool = false,
    is_dormant: bool = true,
    active_puppet: ?CreakingPuppetEntity = null,

    /// Initializes a Creaking Heart block at `pos`.
    pub fn init(pos: [3]i32, initially_active: bool) CreakingHeartBlock {
        return .{
            .pos = pos,
            .health = CREAKING_HEART_MAX_HEALTH,
            .is_active = initially_active,
            .is_broken = false,
            .is_dormant = !initially_active,
            .active_puppet = null,
        };
    }

    /// Evaluates if the Creaking Heart can spawn a puppet:
    /// Active, not broken, no active puppet, within nocturnal window.
    pub fn canSpawnPuppet(self: *const CreakingHeartBlock) bool {
        return self.is_active and !self.is_broken and (self.active_puppet == null or self.active_puppet.?.is_dissolved);
    }

    /// Spawns 1 Creaking puppet within 32m of the heart.
    /// If spawn position is beyond 32m, clamped or rejected.
    pub fn spawnPuppet(
        self: *CreakingHeartBlock,
        puppet_id: u32,
        relative_offset: [3]f32,
    ) ?CreakingPuppetEntity {
        if (!self.canSpawnPuppet()) return null;

        const offset_dist_sq = relative_offset[0] * relative_offset[0] +
            relative_offset[1] * relative_offset[1] +
            relative_offset[2] * relative_offset[2];

        if (offset_dist_sq > MAX_TETHER_RADIUS_SQ) {
            return null; // Beyond 32m spawn radius
        }

        const spawn_pos = [3]f32{
            @as(f32, @floatFromInt(self.pos[0])) + 0.5 + relative_offset[0],
            @as(f32, @floatFromInt(self.pos[1])) + relative_offset[1],
            @as(f32, @floatFromInt(self.pos[2])) + 0.5 + relative_offset[2],
        };

        const puppet = CreakingPuppetEntity.init(puppet_id, self.pos, spawn_pos);
        self.active_puppet = puppet;
        return puppet;
    }

    /// Strikes the linked Creaking puppet:
    /// - Deals 0.0 damage to the puppet (invulnerable).
    /// - Calculates 3D trajectory vector between puppet and heart.
    /// - Emits resonant particle beam with orange/amber resin particles.
    /// - Redirects damage to Creaking Heart: 1 damage point (or 2 with axe bonus).
    /// - If heart health reaches 0, heart breaks and all linked puppets dissolve with sound cue & particle burst.
    pub fn strikeLinkedPuppet(
        self: *CreakingHeartBlock,
        puppet: *CreakingPuppetEntity,
        damage_source: DamageSourceType,
        weapon: WeaponCategory,
        raw_damage: f32,
        hit_pos: ?[3]f32,
    ) DamageLinkOutcome {
        const actual_hit_pos = hit_pos orelse puppet.pos;

        // 1. Puppet invulnerability: takes 0.0 damage, health never decreases
        _ = puppet.receiveDirectAttack(raw_damage);

        // 2. Resonant particle damage link: calculate 3D trajectory vector connecting puppet to heart
        const beam = calculateTrajectory(actual_hit_pos, self.pos);

        // 3. Heart damage calculation (Axe deals 2.0, others deal 1.0)
        const heart_dmg = calculateHeartDamage(weapon);
        const prev_health = self.health;
        const new_health = @max(0.0, prev_health - heart_dmg);
        self.health = new_health;

        var heart_destroyed = false;
        var puppet_dissolved = false;
        var sound_cue: ?SoundEffect = .creaking_strike_redirect;
        var burst: ?CrumbleBurst = null;

        // 4. Heart destruction & Puppet dissolution
        if (self.health <= 0.0) {
            self.is_broken = true;
            self.is_active = false;
            heart_destroyed = true;

            const dissolution = puppet.dissolve(.heart_destroyed);
            puppet_dissolved = true;
            sound_cue = dissolution.sound_cue; // SoundEffect.creaking_crumble
            burst = dissolution.crumble_burst;

            if (self.active_puppet) |*p| {
                if (p.id == puppet.id) {
                    _ = p.dissolve(.heart_destroyed);
                }
            }
        }

        return .{
            .damage_source = damage_source,
            .weapon = weapon,
            .raw_damage = raw_damage,
            .puppet_damage_taken = 0.0,
            .is_invulnerable = puppet.is_invulnerable,
            .puppet_survived = !puppet_dissolved,
            .puppet_dissolved = puppet_dissolved,
            .heart_damage_dealt = heart_dmg,
            .heart_remaining_health = self.health,
            .heart_destroyed = heart_destroyed,
            .beam = beam,
            .sound_cue = sound_cue,
            .crumble_burst = burst,
            .experience_dropped = 0,
            .drops_count = 0,
        };
    }

    /// Direct mining / breaking of the Creaking Heart block.
    /// Immediately dissolves any linked puppets.
    pub fn mineOrBreakHeart(self: *CreakingHeartBlock) ?DissolutionOutcome {
        self.health = 0.0;
        self.is_broken = true;
        self.is_active = false;

        if (self.active_puppet) |*puppet| {
            if (puppet.is_alive) {
                return puppet.dissolve(.heart_broken);
            }
        }
        return null;
    }

    /// Advances the nocturnal day/night cycle:
    /// - Activates at night (13,000..23,000 or skylight <= 7).
    /// - At dawn (tick 23,000 / skylight > 7), goes dormant and dissolves active puppet.
    pub fn updateNocturnalCycle(
        self: *CreakingHeartBlock,
        world_time_ticks: u32,
        sky_light: u8,
        is_thunder: bool,
    ) ?DissolutionOutcome {
        if (self.is_broken) return null;

        const nocturnal = isNocturnalActive(world_time_ticks, sky_light, is_thunder);

        if (nocturnal) {
            self.is_active = true;
            self.is_dormant = false;
            if (self.active_puppet) |*puppet| {
                puppet.is_dormant = false;
            }
            return null;
        } else {
            // Dawn dormancy
            self.is_active = false;
            self.is_dormant = true;

            if (self.active_puppet) |*puppet| {
                if (puppet.is_alive) {
                    return puppet.dissolve(.dawn_dormancy);
                }
            }
            return null;
        }
    }
};

/// Dissolves all linked puppets in a provided slice when heart is destroyed or broken.
pub fn dissolveLinkedPuppets(
    puppets: []CreakingPuppetEntity,
    heart_pos: [3]i32,
    reason: DissolutionReason,
) u32 {
    var count: u32 = 0;
    for (puppets) |*p| {
        if (p.is_alive and p.heart_pos[0] == heart_pos[0] and
            p.heart_pos[1] == heart_pos[1] and
            p.heart_pos[2] == heart_pos[2])
        {
            _ = p.dissolve(reason);
            count += 1;
        }
    }
    return count;
}

// ============================================================================
// Unit Tests (48 Tests)
// ============================================================================

test "01. Puppet initializes with invulnerability and default virtual health" {
    const puppet = CreakingPuppetEntity.init(1, .{ 10, 64, 20 }, .{ 12.0, 64.0, 25.0 });
    try std.testing.expectEqual(@as(u32, 1), puppet.id);
    try std.testing.expectEqual(@as([3]i32, .{ 10, 64, 20 }), puppet.heart_pos);
    try std.testing.expect(puppet.is_invulnerable);
    try std.testing.expect(puppet.is_alive);
    try std.testing.expect(!puppet.is_dissolved);
    try std.testing.expect(!puppet.is_dormant);
    try std.testing.expectEqual(CREAKING_PUPPET_VIRTUAL_HEALTH, puppet.health);
    try std.testing.expectEqual(@as(u32, 0), puppet.experience_drop);
    try std.testing.expectEqual(@as(u32, 0), puppet.drops_count);
}

test "02. Direct melee strike deals 0.0 damage to puppet, preserving virtual health" {
    var puppet = CreakingPuppetEntity.init(2, .{ 0, 64, 0 }, .{ 2.0, 64.0, 2.0 });
    const dmg = puppet.receiveDirectAttack(10.0);
    try std.testing.expectEqual(@as(f32, 0.0), dmg);
    try std.testing.expectEqual(CREAKING_PUPPET_VIRTUAL_HEALTH, puppet.health);
    try std.testing.expect(puppet.is_alive);
    try std.testing.expect(puppet.is_invulnerable);
}

test "03. Direct arrow strike deals 0.0 damage to puppet, preserving virtual health" {
    var puppet = CreakingPuppetEntity.init(3, .{ 0, 64, 0 }, .{ 5.0, 64.0, 5.0 });
    const dmg = puppet.receiveDirectAttack(8.5);
    try std.testing.expectEqual(@as(f32, 0.0), dmg);
    try std.testing.expectEqual(CREAKING_PUPPET_VIRTUAL_HEALTH, puppet.health);
    try std.testing.expect(puppet.is_alive);
}

test "04. Direct trident strike deals 0.0 damage to puppet, preserving virtual health" {
    var puppet = CreakingPuppetEntity.init(4, .{ 0, 64, 0 }, .{ 3.0, 64.0, 3.0 });
    const dmg = puppet.receiveDirectAttack(11.0);
    try std.testing.expectEqual(@as(f32, 0.0), dmg);
    try std.testing.expectEqual(CREAKING_PUPPET_VIRTUAL_HEALTH, puppet.health);
    try std.testing.expect(puppet.is_alive);
}

test "05. Massive explosion damage deals 0.0 damage to puppet, preserving virtual health" {
    var puppet = CreakingPuppetEntity.init(5, .{ 0, 64, 0 }, .{ 1.0, 64.0, 1.0 });
    const dmg = puppet.receiveDirectAttack(65.0);
    try std.testing.expectEqual(@as(f32, 0.0), dmg);
    try std.testing.expectEqual(CREAKING_PUPPET_VIRTUAL_HEALTH, puppet.health);
    try std.testing.expect(puppet.is_alive);
}

test "06. Fire and fall damage deal 0.0 damage to puppet, preserving virtual health" {
    var puppet = CreakingPuppetEntity.init(6, .{ 0, 64, 0 }, .{ 0.0, 64.0, 1.0 });
    const fire_dmg = puppet.receiveDirectAttack(4.0);
    try std.testing.expectEqual(@as(f32, 0.0), fire_dmg);
    const fall_dmg = puppet.receiveDirectAttack(20.0);
    try std.testing.expectEqual(@as(f32, 0.0), fall_dmg);
    try std.testing.expectEqual(CREAKING_PUPPET_VIRTUAL_HEALTH, puppet.health);
}

test "07. Magic and generic damage deal 0.0 damage to puppet, preserving virtual health" {
    var puppet = CreakingPuppetEntity.init(7, .{ 0, 64, 0 }, .{ 0.0, 64.0, 2.0 });
    const magic_dmg = puppet.receiveDirectAttack(6.0);
    try std.testing.expectEqual(@as(f32, 0.0), magic_dmg);
    const generic_dmg = puppet.receiveDirectAttack(5.0);
    try std.testing.expectEqual(@as(f32, 0.0), generic_dmg);
    try std.testing.expectEqual(CREAKING_PUPPET_VIRTUAL_HEALTH, puppet.health);
}

test "08. Multiple consecutive strikes leave puppet virtual health at 1.0 with is_alive=true" {
    var puppet = CreakingPuppetEntity.init(8, .{ 0, 64, 0 }, .{ 0.0, 64.0, 3.0 });
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        _ = puppet.receiveDirectAttack(15.0);
        try std.testing.expectEqual(CREAKING_PUPPET_VIRTUAL_HEALTH, puppet.health);
        try std.testing.expect(puppet.is_alive);
    }
}

test "09. Trajectory vector delta calculation between puppet and heart center" {
    const heart_pos = [3]i32{ 10, 64, 20 };
    const puppet_pos = [3]f32{ 10.5, 64.5, 30.5 };
    const beam = calculateTrajectory(puppet_pos, heart_pos);

    // Heart block center is (10.5, 64.5, 20.5)
    try std.testing.expectEqual(puppet_pos, beam.origin);
    try std.testing.expectEqual(@as(f32, 10.5), beam.target[0]);
    try std.testing.expectEqual(@as(f32, 64.5), beam.target[1]);
    try std.testing.expectEqual(@as(f32, 20.5), beam.target[2]);

    // Delta from (10.5, 64.5, 30.5) to (10.5, 64.5, 20.5) is (0.0, 0.0, -10.0)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), beam.delta[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), beam.delta[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -10.0), beam.delta[2], 0.001);
}

test "10. Distance calculation matches 3D Euclidean distance along axes" {
    const heart_pos = [3]i32{ 0, 0, 0 };
    const puppet_pos = [3]f32{ 3.5, 4.5, 0.5 }; // Heart center is (0.5, 0.5, 0.5), delta is (3.0, 4.0, 0.0) -> dist = 5.0
    const beam = calculateTrajectory(puppet_pos, heart_pos);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), beam.distance, 0.001);
}

test "11. Unit direction vector is normalized correctly" {
    const heart_pos = [3]i32{ 0, 64, 0 };
    const puppet_pos = [3]f32{ 0.5, 64.5, 10.5 };
    const beam = calculateTrajectory(puppet_pos, heart_pos);

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), beam.direction[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), beam.direction[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), beam.direction[2], 0.001);
}

test "12. Particle count scales with distance, bounded within 8 to 32" {
    const heart_pos = [3]i32{ 0, 64, 0 };

    // At 10m: round(10 * 0.75) + 8 = 8 + 8 = 16
    const beam10 = calculateTrajectory(.{ 0.5, 64.5, 10.5 }, heart_pos);
    try std.testing.expectEqual(@as(u32, 16), beam10.particle_count);

    // At 20m: round(20 * 0.75) + 8 = 15 + 8 = 23
    const beam20 = calculateTrajectory(.{ 0.5, 64.5, 20.5 }, heart_pos);
    try std.testing.expectEqual(@as(u32, 23), beam20.particle_count);
}

test "13. Minimum particle count clamp (8 particles for distance <= 0)" {
    const heart_pos = [3]i32{ 5, 64, 5 };
    const heart_center = [3]f32{ 5.5, 64.5, 5.5 };
    const beam = calculateTrajectory(heart_center, heart_pos);
    try std.testing.expectEqual(BEAM_PARTICLE_MIN, beam.particle_count);
}

test "14. Maximum particle count clamp (32 particles for distance >= 32)" {
    const heart_pos = [3]i32{ 0, 64, 0 };
    const beam = calculateTrajectory(.{ 0.5, 64.5, 40.5 }, heart_pos);
    try std.testing.expectEqual(BEAM_PARTICLE_MAX, beam.particle_count);
}

test "15. Trajectory particle sampling at t=0.0, t=0.5, t=1.0" {
    const heart_pos = [3]i32{ 0, 0, 0 };
    const puppet_pos = [3]f32{ 10.5, 0.5, 0.5 }; // delta is (-10.0, 0, 0)
    const beam = calculateTrajectory(puppet_pos, heart_pos);

    const p0 = beam.samplePoint(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), p0[0], 0.001);

    const p_mid = beam.samplePoint(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 5.5), p_mid[0], 0.001);

    const p1 = beam.samplePoint(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), p1[0], 0.001);

    const p_first = beam.particlePosition(0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), p_first[0], 0.001);

    const p_last = beam.particlePosition(beam.particle_count - 1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), p_last[0], 0.001);
}

test "16. Resin trail particles have orange/amber RGBA color and resin_trail_particles kind" {
    const heart_pos = [3]i32{ 0, 64, 0 };
    const beam = calculateTrajectory(.{ 0.5, 64.5, 5.5 }, heart_pos);
    try std.testing.expectEqual(ParticleKind.resin_trail_particles, beam.particle_kind);
    try std.testing.expectEqual(RESIN_TRAIL_COLOR_RGBA, beam.color_rgba);

    const p = beam.getParticle(2);
    try std.testing.expectEqual(RESIN_TRAIL_COLOR_RGBA, p.color_rgba);
    try std.testing.expect(p.scale > 0.0);
    try std.testing.expect(p.lifetime_ticks > 0);
}

test "17. Standard unarmed strike redirects 1.0 damage to heart (from 5.0 to 4.0 HP)" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(10, heart.pos, .{ 0.0, 64.0, 8.0 });

    const outcome = heart.strikeLinkedPuppet(&puppet, .melee, .unarmed, 4.0, null);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.puppet_damage_taken);
    try std.testing.expectEqual(@as(f32, 1.0), outcome.heart_damage_dealt);
    try std.testing.expectEqual(@as(f32, 4.0), outcome.heart_remaining_health);
    try std.testing.expectEqual(@as(f32, 4.0), heart.health);
    try std.testing.expect(!outcome.heart_destroyed);
    try std.testing.expect(outcome.puppet_survived);
    try std.testing.expect(!outcome.puppet_dissolved);
}

test "18. Sword strike redirects 1.0 damage to heart" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(11, heart.pos, .{ 0.0, 64.0, 8.0 });

    const outcome = heart.strikeLinkedPuppet(&puppet, .melee, .sword, 9.0, null);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.puppet_damage_taken);
    try std.testing.expectEqual(@as(f32, 1.0), outcome.heart_damage_dealt);
    try std.testing.expectEqual(@as(f32, 4.0), heart.health);
}

test "19. Arrow strike redirects 1.0 damage to heart" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(12, heart.pos, .{ 0.0, 64.0, 12.0 });

    const outcome = heart.strikeLinkedPuppet(&puppet, .arrow, .bow, 7.5, null);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.puppet_damage_taken);
    try std.testing.expectEqual(@as(f32, 1.0), outcome.heart_damage_dealt);
    try std.testing.expectEqual(@as(f32, 4.0), heart.health);
}

test "20. Trident strike redirects 1.0 damage to heart" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(13, heart.pos, .{ 0.0, 64.0, 15.0 });

    const outcome = heart.strikeLinkedPuppet(&puppet, .trident, .trident, 10.0, null);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.puppet_damage_taken);
    try std.testing.expectEqual(@as(f32, 1.0), outcome.heart_damage_dealt);
    try std.testing.expectEqual(@as(f32, 4.0), heart.health);
}

test "21. Axe strike deals 2.0 damage to heart (axe damage bonus)" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(14, heart.pos, .{ 0.0, 64.0, 5.0 });

    const outcome = heart.strikeLinkedPuppet(&puppet, .melee, .axe, 12.0, null);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.puppet_damage_taken);
    try std.testing.expectEqual(AXE_HEART_DAMAGE, outcome.heart_damage_dealt);
    try std.testing.expectEqual(@as(f32, 2.0), outcome.heart_damage_dealt);
    try std.testing.expectEqual(@as(f32, 3.0), outcome.heart_remaining_health);
    try std.testing.expectEqual(@as(f32, 3.0), heart.health);
}

test "22. Multiple axe strikes reduce heart from 5.0 to 3.0 to 1.0 to 0.0 HP (3 hits to destroy)" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(15, heart.pos, .{ 0.0, 64.0, 5.0 });

    // Hit 1: 5.0 -> 3.0
    const out1 = heart.strikeLinkedPuppet(&puppet, .melee, .axe, 10.0, null);
    try std.testing.expectEqual(@as(f32, 3.0), out1.heart_remaining_health);
    try std.testing.expect(!out1.heart_destroyed);
    try std.testing.expect(puppet.is_alive);

    // Hit 2: 3.0 -> 1.0
    const out2 = heart.strikeLinkedPuppet(&puppet, .melee, .axe, 10.0, null);
    try std.testing.expectEqual(@as(f32, 1.0), out2.heart_remaining_health);
    try std.testing.expect(!out2.heart_destroyed);
    try std.testing.expect(puppet.is_alive);

    // Hit 3: 1.0 -> 0.0 (overkill clamped to 0.0)
    const out3 = heart.strikeLinkedPuppet(&puppet, .melee, .axe, 10.0, null);
    try std.testing.expectEqual(@as(f32, 0.0), out3.heart_remaining_health);
    try std.testing.expect(out3.heart_destroyed);
    try std.testing.expect(out3.puppet_dissolved);
    try std.testing.expect(!puppet.is_alive);
    try std.testing.expect(puppet.is_dissolved);
}

test "23. Five standard strikes reduce heart from 5.0 to 0.0 HP (5 hits to destroy)" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(16, heart.pos, .{ 0.0, 64.0, 5.0 });

    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const out = heart.strikeLinkedPuppet(&puppet, .melee, .sword, 5.0, null);
        try std.testing.expectEqual(@as(f32, 1.0), out.heart_damage_dealt);
        try std.testing.expect(!out.heart_destroyed);
        try std.testing.expect(puppet.is_alive);
    }
    try std.testing.expectEqual(@as(f32, 1.0), heart.health);

    // 5th strike is lethal to heart
    const out5 = heart.strikeLinkedPuppet(&puppet, .melee, .sword, 5.0, null);
    try std.testing.expectEqual(@as(f32, 0.0), heart.health);
    try std.testing.expect(out5.heart_destroyed);
    try std.testing.expect(out5.puppet_dissolved);
    try std.testing.expect(puppet.is_dissolved);
}

test "24. Heart health reaching 0 marks heart broken and inactive" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(17, heart.pos, .{ 0.0, 64.0, 5.0 });

    _ = heart.strikeLinkedPuppet(&puppet, .melee, .axe, 10.0, null); // 5 -> 3
    _ = heart.strikeLinkedPuppet(&puppet, .melee, .axe, 10.0, null); // 3 -> 1
    _ = heart.strikeLinkedPuppet(&puppet, .melee, .axe, 10.0, null); // 1 -> 0

    try std.testing.expect(heart.is_broken);
    try std.testing.expect(!heart.is_active);
    try std.testing.expectEqual(@as(f32, 0.0), heart.health);
}

test "25. Reaching 0.0 heart HP immediately marks linked puppet dissolved and dead" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(18, heart.pos, .{ 0.0, 64.0, 5.0 });

    var i: usize = 0;
    while (i < 5) : (i += 1) {
        _ = heart.strikeLinkedPuppet(&puppet, .melee, .sword, 5.0, null);
    }

    try std.testing.expect(puppet.is_dissolved);
    try std.testing.expect(!puppet.is_alive);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.health);
}

test "26. Dissolution emits SoundEffect.creaking_crumble" {
    var puppet = CreakingPuppetEntity.init(19, .{ 0, 64, 0 }, .{ 0.0, 64.0, 5.0 });
    const dissolution = puppet.dissolve(.heart_destroyed);
    try std.testing.expectEqual(SoundEffect.creaking_crumble, dissolution.sound_cue);
}

test "27. Non-fatal strike redirect outcome includes SoundEffect.creaking_strike_redirect" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(20, heart.pos, .{ 0.0, 64.0, 5.0 });

    const outcome = heart.strikeLinkedPuppet(&puppet, .melee, .sword, 5.0, null);
    try std.testing.expectEqual(SoundEffect.creaking_strike_redirect, outcome.sound_cue.?);
}

test "28. Fatal strike redirect outcome transitions sound cue to SoundEffect.creaking_crumble" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    var puppet = CreakingPuppetEntity.init(21, heart.pos, .{ 0.0, 64.0, 5.0 });
    heart.health = 1.0; // 1 strike away from destruction

    const outcome = heart.strikeLinkedPuppet(&puppet, .melee, .sword, 5.0, null);
    try std.testing.expect(outcome.heart_destroyed);
    try std.testing.expectEqual(SoundEffect.creaking_crumble, outcome.sound_cue.?);
}

test "29. Dissolution spawns crumble particle burst with 40 particles (20 wood + 20 resin)" {
    var puppet = CreakingPuppetEntity.init(22, .{ 0, 64, 0 }, .{ 10.0, 64.0, 10.0 });
    const dissolution = puppet.dissolve(.heart_destroyed);
    const burst = dissolution.crumble_burst;

    try std.testing.expectEqual(CRUMBLE_BURST_PARTICLE_COUNT, burst.total_particles);
    try std.testing.expectEqual(CRUMBLE_WOOD_PARTICLES, burst.wood_particles);
    try std.testing.expectEqual(CRUMBLE_RESIN_PARTICLES, burst.resin_particles);
    try std.testing.expectEqual(SoundEffect.creaking_crumble, burst.sound_effect);

    // Verify particle sample properties
    const p_even = burst.sampleParticle(0); // Even index -> resin
    try std.testing.expectEqual(ParticleKind.resin_crumble, p_even.particle_kind);
    try std.testing.expectEqual(RESIN_CRUMBLE_COLOR_RGBA, p_even.color_rgba);

    const p_odd = burst.sampleParticle(1); // Odd index -> pale oak wood
    try std.testing.expectEqual(ParticleKind.pale_oak_wood_crumble, p_odd.particle_kind);
    try std.testing.expectEqual(WOOD_CRUMBLE_COLOR_RGBA, p_odd.color_rgba);
}

test "30. Dissolution yields strictly 0 experience points" {
    var puppet = CreakingPuppetEntity.init(23, .{ 0, 64, 0 }, .{ 0.0, 64.0, 5.0 });
    const dissolution = puppet.dissolve(.heart_destroyed);
    try std.testing.expectEqual(@as(u32, 0), dissolution.experience_dropped);
    try std.testing.expectEqual(XP_DROPS_ON_DISSOLUTION, dissolution.experience_dropped);
}

test "31. Dissolution yields strictly 0 mob item drops" {
    var puppet = CreakingPuppetEntity.init(24, .{ 0, 64, 0 }, .{ 0.0, 64.0, 5.0 });
    const dissolution = puppet.dissolve(.heart_destroyed);
    try std.testing.expectEqual(@as(u32, 0), dissolution.drops_count);
    try std.testing.expectEqual(MOB_DROPS_COUNT_ON_DISSOLUTION, dissolution.drops_count);
}

test "32. Direct mining or breaking of heart block immediately dissolves active puppet" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    const puppet = heart.spawnPuppet(25, .{ 0.0, 0.0, 5.0 });
    try std.testing.expect(puppet != null);
    try std.testing.expect(heart.active_puppet.?.is_alive);

    const break_res = heart.mineOrBreakHeart();
    try std.testing.expect(break_res != null);
    try std.testing.expect(heart.is_broken);
    try std.testing.expect(!heart.is_active);
    try std.testing.expectEqual(@as(f32, 0.0), heart.health);
    try std.testing.expect(heart.active_puppet.?.is_dissolved);
    try std.testing.expect(!heart.active_puppet.?.is_alive);
}

test "33. Mining heart emits SoundEffect.creaking_crumble and crumble particle burst" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    _ = heart.spawnPuppet(26, .{ 0.0, 0.0, 5.0 });

    const break_res = heart.mineOrBreakHeart().?;
    try std.testing.expectEqual(SoundEffect.creaking_crumble, break_res.sound_cue);
    try std.testing.expectEqual(DissolutionReason.heart_broken, break_res.reason);
    try std.testing.expectEqual(@as(u32, 40), break_res.crumble_burst.total_particles);
    try std.testing.expectEqual(@as(u32, 0), break_res.experience_dropped);
    try std.testing.expectEqual(@as(u32, 0), break_res.drops_count);
}

test "34. Multi-puppet dissolution: dissolveLinkedPuppets dissolves all puppets bound to heart" {
    var puppets = [_]CreakingPuppetEntity{
        CreakingPuppetEntity.init(101, .{ 10, 64, 10 }, .{ 12.0, 64.0, 15.0 }),
        CreakingPuppetEntity.init(102, .{ 10, 64, 10 }, .{ 8.0, 64.0, 5.0 }),
        CreakingPuppetEntity.init(103, .{ 10, 64, 10 }, .{ 15.0, 64.0, 12.0 }),
    };

    const dissolved_count = dissolveLinkedPuppets(&puppets, .{ 10, 64, 10 }, .heart_destroyed);
    try std.testing.expectEqual(@as(u32, 3), dissolved_count);
    for (puppets) |p| {
        try std.testing.expect(p.is_dissolved);
        try std.testing.expect(!p.is_alive);
    }
}

test "35. dissolveLinkedPuppets ignores puppets bound to a different heart coordinate" {
    var puppets = [_]CreakingPuppetEntity{
        CreakingPuppetEntity.init(201, .{ 10, 64, 10 }, .{ 12.0, 64.0, 15.0 }),
        CreakingPuppetEntity.init(202, .{ 50, 64, 50 }, .{ 52.0, 64.0, 55.0 }), // Different heart
    };

    const count = dissolveLinkedPuppets(&puppets, .{ 10, 64, 10 }, .heart_destroyed);
    try std.testing.expectEqual(@as(u32, 1), count);
    try std.testing.expect(puppets[0].is_dissolved);
    try std.testing.expect(!puppets[0].is_alive);
    try std.testing.expect(!puppets[1].is_dissolved);
    try std.testing.expect(puppets[1].is_alive);
}

test "36. Nocturnal window active at dusk: tick 13,000 (sky light 15)" {
    try std.testing.expect(isNocturnalActive(13000, 15, false));
}

test "37. Nocturnal window active at midnight: tick 18,000 (sky light 15)" {
    try std.testing.expect(isNocturnalActive(18000, 15, false));
}

test "38. Nocturnal window active at dawn boundary: tick 23,000 (sky light 15)" {
    try std.testing.expect(isNocturnalActive(23000, 15, false));
}

test "39. Nocturnal window active during daylight (tick 6,000) if skylight <= 7" {
    try std.testing.expect(isNocturnalActive(6000, 7, false));
    try std.testing.expect(isNocturnalActive(6000, 4, false));
    try std.testing.expect(isNocturnalActive(6000, 0, false));
}

test "40. Nocturnal window active during daylight if thunderstorm is active" {
    try std.testing.expect(isNocturnalActive(6000, 15, true));
}

test "41. Midday (tick 6,000, skylight 15, no thunder) is not nocturnal" {
    try std.testing.expect(!isNocturnalActive(6000, 15, false));
    try std.testing.expect(isDawnDormancy(6000, 15, false));
}

test "42. Transition to dawn sets heart dormant (is_active=false, is_dormant=true)" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    try std.testing.expect(heart.is_active);

    const outcome = heart.updateNocturnalCycle(23001, 15, false);
    try std.testing.expect(outcome == null); // No puppet to dissolve
    try std.testing.expect(!heart.is_active);
    try std.testing.expect(heart.is_dormant);
}

test "43. Dawn dormancy triggers automatic dissolution of active puppet" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    _ = heart.spawnPuppet(27, .{ 0.0, 0.0, 5.0 });
    try std.testing.expect(heart.active_puppet.?.is_alive);

    // Dawn arrives (tick 23,001, sky light 15)
    const outcome = heart.updateNocturnalCycle(23001, 15, false);
    try std.testing.expect(outcome != null);
    try std.testing.expectEqual(DissolutionReason.dawn_dormancy, outcome.?.reason);
    try std.testing.expect(heart.active_puppet.?.is_dissolved);
    try std.testing.expect(!heart.active_puppet.?.is_alive);
}

test "44. Dawn dissolution emits SoundEffect.creaking_crumble and crumble particle burst" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    _ = heart.spawnPuppet(28, .{ 0.0, 0.0, 5.0 });

    const outcome = heart.updateNocturnalCycle(23500, 15, false).?;
    try std.testing.expectEqual(SoundEffect.creaking_crumble, outcome.sound_cue);
    try std.testing.expectEqual(@as(u32, 40), outcome.crumble_burst.total_particles);
    try std.testing.expectEqual(@as(u32, 0), outcome.experience_dropped);
    try std.testing.expectEqual(@as(u32, 0), outcome.drops_count);
}

test "45. Heart cannot spawn a new puppet during dawn dormancy" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, false);
    _ = heart.updateNocturnalCycle(6000, 15, false);
    try std.testing.expect(heart.is_dormant);
    try std.testing.expect(!heart.canSpawnPuppet());

    const puppet = heart.spawnPuppet(29, .{ 0.0, 0.0, 5.0 });
    try std.testing.expect(puppet == null);
}

test "46. Heart spawns 1 Creaking within 32m tether radius during active nocturnal window" {
    var heart = CreakingHeartBlock.init(.{ 100, 64, 200 }, true);
    const puppet = heart.spawnPuppet(30, .{ 10.0, 0.0, 10.0 });
    try std.testing.expect(puppet != null);
    try std.testing.expect(puppet.?.isWithinTetherRadius());
    try std.testing.expect(puppet.?.distanceToHeart() <= MAX_TETHER_RADIUS);
}

test "47. Attempting to spawn beyond 32m tether radius returns null" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    // Relative offset of 35 blocks along Z is > 32m
    const puppet = heart.spawnPuppet(31, .{ 0.0, 0.0, 35.0 });
    try std.testing.expect(puppet == null);
}

test "48. Heart refuses to spawn a second puppet while an active puppet is already alive" {
    var heart = CreakingHeartBlock.init(.{ 0, 64, 0 }, true);
    const p1 = heart.spawnPuppet(32, .{ 2.0, 0.0, 2.0 });
    try std.testing.expect(p1 != null);
    try std.testing.expect(!heart.canSpawnPuppet());

    // Second spawn attempt fails
    const p2 = heart.spawnPuppet(33, .{ -2.0, 0.0, -2.0 });
    try std.testing.expect(p2 == null);
}
