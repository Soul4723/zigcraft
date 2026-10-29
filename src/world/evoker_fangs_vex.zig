const std = @import("std");

// ============================================================================
// Constants & Configuration
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;
pub const TICK_DT: f32 = 1.0 / @as(f32, @floatFromInt(TICKS_PER_SECOND)); // 0.05 seconds

/// Evoker Entity Attributes
pub const EVOKER_MAX_HEALTH: f32 = 24.0; // 24.0 HP (12 hearts)
pub const EVOKER_MAX_HEARTS: f32 = 12.0;

/// Evoker Spellcasting Animation Durations (in game ticks)
pub const EVOKER_CASTING_TICKS_FANGS: u32 = 40; // 40 ticks = 2.0s
pub const EVOKER_CASTING_TICKS_VEX: u32 = 100; // 100 ticks = 5.0s
pub const EVOKER_CASTING_TICKS_WOLOLO: u32 = 60; // 60 ticks = 3.0s

/// Evoker Spell Cooldowns (in game ticks)
pub const EVOKER_FANGS_COOLDOWN_TICKS: u32 = 100; // 5.0s
pub const EVOKER_VEX_COOLDOWN_TICKS: u32 = 340; // 17.0s
pub const EVOKER_WOLOLO_COOLDOWN_TICKS: u32 = 120; // 6.0s
pub const EVOKER_GLOBAL_SPELL_COOLDOWN_TICKS: u32 = 20; // 1.0s

/// Evoker AI & Spatial Thresholds
pub const EVOKER_FLEE_THRESHOLD_METERS: f32 = 3.0; // Flees player inside 3.0m
pub const EVOKER_FLEE_SPEED: f32 = 3.0; // 3.0 m/s flee velocity
pub const EVOKER_VEX_ACTIVE_CAP: u8 = 8; // Active Vex cap before switching to offensive line fangs
pub const WOLOLO_RANGE: f32 = 16.0; // 16.0m sheep conversion radius

/// Evoker Fangs Attack Kinematics & Lifecycle
pub const FANG_SNAP_DAMAGE: f32 = 6.0; // 6.0 HP (3 hearts) unmitigated magic damage
pub const FANG_WARNING_TICKS: u32 = 14; // 14 ticks = 0.7s warning emergence
pub const FANG_WARNING_SECONDS: f32 = 0.7;
pub const FANG_SNAP_TICKS: u32 = 6; // Active snap duration (0.3s)
pub const FANG_RETRACTION_TICKS: u32 = 20; // 20 ticks = 1.0s retraction phase
pub const FANG_TOTAL_LIFETIME_TICKS: u32 = FANG_WARNING_TICKS + FANG_RETRACTION_TICKS; // 34 ticks
pub const FANG_HITBOX_RADIUS: f32 = 1.0; // 1.0m horizontal radius
pub const FANG_HITBOX_HEIGHT: f32 = 1.5; // 1.5m vertical height

/// Fangs Formations
pub const OFFENSIVE_LINE_FANG_COUNT: usize = 16;
pub const OFFENSIVE_LINE_MAX_RANGE: f32 = 20.0; // Up to 20 blocks away
pub const OFFENSIVE_LINE_DEFAULT_SPACING: f32 = 1.25; // 16 * 1.25 = 20.0m
pub const OFFENSIVE_LINE_STAGGER_TICKS: u32 = 1; // 1 tick activation delay per fang

pub const DEFENSIVE_CIRCLE_TRIGGER_DIST: f32 = 3.0; // Summons circle when target <= 3.0m
pub const DEFENSIVE_INNER_RING_COUNT: usize = 8;
pub const DEFENSIVE_INNER_RING_RADIUS: f32 = 1.5; // 1.5m inner circle radius
pub const DEFENSIVE_OUTER_RING_COUNT: usize = 12;
pub const DEFENSIVE_OUTER_RING_RADIUS: f32 = 3.0; // 3.0m outer circle radius
pub const DEFENSIVE_CIRCLE_TOTAL_COUNT: usize = DEFENSIVE_INNER_RING_COUNT + DEFENSIVE_OUTER_RING_COUNT; // 20 fangs

/// Vex Entity Attributes & Flight Dynamics
pub const VEX_MAX_HEALTH: f32 = 14.0; // 14.0 HP (7 hearts)
pub const VEX_MAX_HEARTS: f32 = 7.0;
pub const VEX_MIN_SUMMON_COUNT: u8 = 2;
pub const VEX_MAX_SUMMON_COUNT: u8 = 4;
pub const VEX_CRUISE_SPEED: f32 = 3.0; // 3.0 m/s cruise flight speed
pub const VEX_CHARGE_SPEED: f32 = 8.0; // 8.0 m/s charge attack acceleration
pub const VEX_CHARGE_DURATION_TICKS: u32 = 40; // 2.0s charge lunge duration

/// Vex Iron Sword Melee Damage per Difficulty
pub const VEX_DAMAGE_EASY: f32 = 5.0; // 5.0 HP
pub const VEX_DAMAGE_NORMAL: f32 = 9.0; // 9.0 HP
pub const VEX_DAMAGE_HARD: f32 = 13.0; // 13.0 HP

/// Vex Life Decay (Starvation)
pub const VEX_MIN_DECAY_DELAY_SECONDS: f32 = 30.0;
pub const VEX_MAX_DECAY_DELAY_SECONDS: f32 = 119.0;
pub const VEX_MIN_DECAY_DELAY_TICKS: u32 = 600; // 30s * 20 ticks
pub const VEX_MAX_DECAY_DELAY_TICKS: u32 = 2380; // 119s * 20 ticks
pub const VEX_DECAY_RATE_PER_SECOND: f32 = 1.0; // 1.0 HP / second
pub const VEX_DECAY_RATE_PER_TICK: f32 = VEX_DECAY_RATE_PER_SECOND / @as(f32, @floatFromInt(TICKS_PER_SECOND)); // 0.05 HP / tick

// ============================================================================
// Enums & Core Types
// ============================================================================

/// Spell classifications channeled by the Evoker state machine.
pub const SpellType = enum(u8) {
    none = 0,
    fangs = 1,
    vex = 2,
    wololo = 3,

    pub fn warmupTicks(self: SpellType) u32 {
        return switch (self) {
            .none => 0,
            .fangs => EVOKER_CASTING_TICKS_FANGS,
            .vex => EVOKER_CASTING_TICKS_VEX,
            .wololo => EVOKER_CASTING_TICKS_WOLOLO,
        };
    }

    pub fn particleColor(self: SpellType) [4]f32 {
        return switch (self) {
            .none => .{ 0.0, 0.0, 0.0, 0.0 },
            .fangs => .{ 0.38, 0.15, 0.58, 1.0 }, // Dark purple swirl
            .vex => .{ 1.0, 1.0, 1.0, 1.0 }, // Pure white swirl
            .wololo => .{ 0.85, 0.65, 0.15, 1.0 }, // Orange-yellow swirl
        };
    }

    pub fn particleType(self: SpellType) ParticleType {
        return switch (self) {
            .none => .none,
            .fangs, .vex, .wololo => .spell_mob,
        };
    }
};

/// Fang emergence and retraction phases.
pub const FangPhase = enum(u8) {
    warning = 0, // 0..14 ticks: teeth emerge slightly from ground
    snap = 1, // tick 14: jaws snap shut with mechanical sound and damage
    retraction = 2, // 14..34 ticks: teeth retract into ground for 20 ticks
    expired = 3, // >= 34 ticks: despawned
};

/// Formation geometry for spawned fangs.
pub const FangFormationKind = enum(u8) {
    offensive_line = 0,
    defensive_circle = 1,
};

/// Combat difficulty level impacting mob attack damage.
pub const Difficulty = enum(u8) {
    peaceful = 0,
    easy = 1,
    normal = 2,
    hard = 3,
};

/// Particle visual classification.
pub const ParticleType = enum(u8) {
    none = 0,
    spell_mob = 1,
    crit = 2,
    smoke = 3,
};

/// Acoustic telemetry cues emitted during combat and spellcasting.
pub const SoundEffect = enum(u8) {
    evoker_cast_spell = 0,
    evoker_prepare_fangs = 1,
    evoker_prepare_vex = 2,
    evoker_prepare_wololo = 3,
    evoker_celebrate = 4,
    fang_snap = 5,
    vex_charge = 6,
    vex_ambient = 7,
    vex_hurt = 8,
    vex_death = 9,
    sheep_bleat = 10,
};

/// Minecraft 16 dye colors for sheep wool conversion.
pub const SheepColor = enum(u4) {
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
};

/// Vex weapon equip state.
pub const VexWeapon = enum(u8) {
    iron_sword = 0,
};

// ============================================================================
// Mathematical & Spatial Helper Functions
// ============================================================================

pub fn distance3D(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

pub fn distanceXZ(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dz * dz);
}

pub fn normalizeVector(vec: [3]f32) [3]f32 {
    const len_sq = vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2];
    if (len_sq > 0.000001) {
        const inv_len = 1.0 / @sqrt(len_sq);
        return .{ vec[0] * inv_len, vec[1] * inv_len, vec[2] * inv_len };
    }
    return .{ 0.0, 0.0, 1.0 };
}

// ============================================================================
// Combat Target & Damage Resolution
// ============================================================================

/// Represents an entity targeted by Evoker spells or fangs (e.g. Player, Villager, Golem).
pub const CombatTarget = struct {
    id: u32,
    is_illager: bool = false,
    position: [3]f32,
    health: f32 = 20.0,
    max_health: f32 = 20.0,
    armor_points: f32 = 0.0, // e.g. 20.0 for full diamond armor
    shield_blocking: bool = false, // true if holding up shield
    shield_durability: u16 = 336,
    is_alive: bool = true,

    pub fn takeDamage(self: *CombatTarget, amount: f32) void {
        if (self.health > amount) {
            self.health -= amount;
        } else {
            self.health = 0.0;
            self.is_alive = false;
        }
    }
};

/// Damage resolution telemetry confirming armor and shield bypass.
pub const DamageResult = struct {
    hit: bool,
    damage_dealt: f32,
    raw_damage: f32,
    armor_absorbed: f32,
    shield_bypassed: bool,
    target_health_after: f32,
    target_eliminated: bool,
};

// ============================================================================
// Evoker Entity & Spellcasting State Machine
// ============================================================================

pub const SpellCompletionEvent = struct {
    evoker_id: u32,
    spell: SpellType,
    position: [3]f32,
};

pub const EvokerEntity = struct {
    id: u32,
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    health: f32 = EVOKER_MAX_HEALTH,
    max_health: f32 = EVOKER_MAX_HEALTH,
    is_alive: bool = true,

    // Spellcasting State Machine
    current_spell: SpellType = .none,
    spell_warmup_remaining: u32 = 0,
    global_cooldown_ticks: u32 = 0,
    fangs_cooldown_ticks: u32 = 0,
    vex_cooldown_ticks: u32 = 0,
    wololo_cooldown_ticks: u32 = 0,

    arm_raising: bool = false,
    is_fleeing: bool = false,

    pub fn init(id: u32, pos: [3]f32) EvokerEntity {
        return .{
            .id = id,
            .position = pos,
            .health = EVOKER_MAX_HEALTH,
            .max_health = EVOKER_MAX_HEALTH,
            .is_alive = true,
        };
    }

    pub fn canCastSpell(self: *const EvokerEntity, spell: SpellType) bool {
        if (!self.is_alive) return false;
        if (self.current_spell != .none) return false;
        if (self.global_cooldown_ticks > 0) return false;
        return switch (spell) {
            .none => true,
            .fangs => self.fangs_cooldown_ticks == 0,
            .vex => self.vex_cooldown_ticks == 0,
            .wololo => self.wololo_cooldown_ticks == 0,
        };
    }

    pub fn startCasting(self: *EvokerEntity, spell: SpellType) bool {
        if (!self.canCastSpell(spell) or spell == .none) return false;
        self.current_spell = spell;
        self.spell_warmup_remaining = spell.warmupTicks();
        self.arm_raising = true;
        self.is_fleeing = false;
        return true;
    }

    pub fn interruptCasting(self: *EvokerEntity) void {
        self.current_spell = .none;
        self.spell_warmup_remaining = 0;
        self.arm_raising = false;
    }

    pub fn tick(self: *EvokerEntity) ?SpellCompletionEvent {
        if (!self.is_alive) return null;

        // Decrement cooldown timers
        if (self.global_cooldown_ticks > 0) self.global_cooldown_ticks -= 1;
        if (self.fangs_cooldown_ticks > 0) self.fangs_cooldown_ticks -= 1;
        if (self.vex_cooldown_ticks > 0) self.vex_cooldown_ticks -= 1;
        if (self.wololo_cooldown_ticks > 0) self.wololo_cooldown_ticks -= 1;

        // Active casting progress
        if (self.current_spell != .none) {
            if (self.spell_warmup_remaining > 0) {
                self.spell_warmup_remaining -= 1;
            }

            if (self.spell_warmup_remaining == 0) {
                const finished_spell = self.current_spell;
                self.current_spell = .none;
                self.arm_raising = false;

                // Set appropriate cooldowns upon spell execution
                self.global_cooldown_ticks = EVOKER_GLOBAL_SPELL_COOLDOWN_TICKS;
                switch (finished_spell) {
                    .fangs => self.fangs_cooldown_ticks = EVOKER_FANGS_COOLDOWN_TICKS,
                    .vex => self.vex_cooldown_ticks = EVOKER_VEX_COOLDOWN_TICKS,
                    .wololo => self.wololo_cooldown_ticks = EVOKER_WOLOLO_COOLDOWN_TICKS,
                    .none => {},
                }

                return SpellCompletionEvent{
                    .evoker_id = self.id,
                    .spell = finished_spell,
                    .position = self.position,
                };
            }
        }

        return null;
    }

    /// Evaluates environmental conditions to select the next optimal spell:
    /// 1. Close defense: if target is within 3.0m, cast defensive circle fangs.
    /// 2. Vex summoning: if active vexes < 8 and cooldown is 0, summon Vexes.
    /// 3. Ranged offensive: cast offensive line fangs.
    /// 4. Wololo: non-combat priority on blue sheep within 16.0m.
    pub fn selectSpell(
        self: *const EvokerEntity,
        target_pos: ?[3]f32,
        active_vex_count: u8,
        blue_sheep_pos: ?[3]f32,
        in_combat: bool,
    ) SpellType {
        if (!self.is_alive) return .none;
        if (self.current_spell != .none) return .none;
        if (self.global_cooldown_ticks > 0) return .none;

        if (in_combat) {
            if (target_pos) |tpos| {
                const dist = distanceXZ(self.position, tpos);

                // Priority 1: Close defensive circle fangs within 3.0m
                if (dist <= DEFENSIVE_CIRCLE_TRIGGER_DIST and self.fangs_cooldown_ticks == 0) {
                    return .fangs;
                }

                // Priority 2: Vex summoning if below active cap
                if (active_vex_count < EVOKER_VEX_ACTIVE_CAP and self.vex_cooldown_ticks == 0) {
                    return .vex;
                }

                // Priority 3: Ranged offensive line fangs
                if (self.fangs_cooldown_ticks == 0) {
                    return .fangs;
                }
            }
            return .none;
        } else {
            // Non-combat Wololo spell for blue sheep within 16.0m
            if (blue_sheep_pos) |spos| {
                const dist = distance3D(self.position, spos);
                if (dist <= WOLOLO_RANGE and self.wololo_cooldown_ticks == 0) {
                    return .wololo;
                }
            }
            return .none;
        }
    }

    /// Computes flee velocity directed away from a threatening target within 3.0m.
    pub fn computeFleeVelocity(self: *EvokerEntity, target_pos: [3]f32, flee_speed: f32) [3]f32 {
        const dx = self.position[0] - target_pos[0];
        const dz = self.position[2] - target_pos[2];
        const dist = @sqrt(dx * dx + dz * dz);
        if (dist > 0.0001) {
            self.is_fleeing = true;
            return .{
                (dx / dist) * flee_speed,
                0.0,
                (dz / dist) * flee_speed,
            };
        }
        self.is_fleeing = true;
        return .{ flee_speed, 0.0, 0.0 };
    }

    pub fn takeDamage(self: *EvokerEntity, amount: f32) void {
        if (self.health > amount) {
            self.health -= amount;
        } else {
            self.health = 0.0;
            self.is_alive = false;
            self.current_spell = .none;
            self.arm_raising = false;
        }
    }
};

// ============================================================================
// Evoker Fangs Formations & Lifecycle Kinematics
// ============================================================================

pub const FangSnapEvent = struct {
    fang_id: u32,
    caster_id: u32,
    position: [3]f32,
    sound: SoundEffect = .fang_snap,
    damage: f32 = FANG_SNAP_DAMAGE,
};

pub const EvokerFang = struct {
    id: u32,
    caster_id: u32,
    position: [3]f32,
    yaw: f32 = 0.0,
    formation: FangFormationKind = .offensive_line,
    index_in_formation: u8 = 0,
    warmup_delay_ticks: u32 = 0, // Staggered activation delay
    ticks_alive: u32 = 0,
    phase: FangPhase = .warning,
    damage: f32 = FANG_SNAP_DAMAGE,
    has_snapped: bool = false,
    has_dealt_damage: bool = false,
    is_active: bool = true,

    pub fn init(
        id: u32,
        caster_id: u32,
        pos: [3]f32,
        yaw: f32,
        formation: FangFormationKind,
        index: u8,
        warmup_delay: u32,
    ) EvokerFang {
        return .{
            .id = id,
            .caster_id = caster_id,
            .position = pos,
            .yaw = yaw,
            .formation = formation,
            .index_in_formation = index,
            .warmup_delay_ticks = warmup_delay,
            .ticks_alive = 0,
            .phase = .warning,
            .damage = FANG_SNAP_DAMAGE,
            .has_snapped = false,
            .has_dealt_damage = false,
            .is_active = true,
        };
    }

    /// Advance fang lifecycle by one tick.
    /// Warning phase: 14 ticks. Snap phase: tick 14. Retraction phase: 20 ticks.
    /// Disappears after total duration.
    pub fn tick(self: *EvokerFang) ?FangSnapEvent {
        if (!self.is_active) return null;

        var snap_event: ?FangSnapEvent = null;

        if (self.ticks_alive < self.warmup_delay_ticks) {
            self.ticks_alive += 1;
            return null;
        }

        const active_age = self.ticks_alive - self.warmup_delay_ticks;

        if (active_age < FANG_WARNING_TICKS) {
            self.phase = .warning;
        } else if (active_age == FANG_WARNING_TICKS) {
            self.phase = .snap;
            self.has_snapped = true;
            snap_event = FangSnapEvent{
                .fang_id = self.id,
                .caster_id = self.caster_id,
                .position = self.position,
                .sound = .fang_snap,
                .damage = self.damage,
            };
        } else if (active_age <= FANG_WARNING_TICKS + FANG_RETRACTION_TICKS) {
            self.phase = .retraction;
        } else {
            self.phase = .expired;
            self.is_active = false;
        }

        self.ticks_alive += 1;
        return snap_event;
    }

    /// Deal unmitigated magic damage to target, completely bypassing armor and shields.
    pub fn dealDamageToTarget(self: *EvokerFang, target: *CombatTarget) DamageResult {
        // Do not damage summoning Evoker or allied illagers
        if (target.id == self.caster_id or target.is_illager) {
            return .{
                .hit = false,
                .damage_dealt = 0.0,
                .raw_damage = self.damage,
                .armor_absorbed = 0.0,
                .shield_bypassed = false,
                .target_health_after = target.health,
                .target_eliminated = false,
            };
        }

        // Hitbox spatial evaluation (cylinder: horizontal radius 1.0m, height 1.5m)
        const dx = target.position[0] - self.position[0];
        const dy = target.position[1] - self.position[1];
        const dz = target.position[2] - self.position[2];
        const h_dist = @sqrt(dx * dx + dz * dz);

        if (h_dist <= FANG_HITBOX_RADIUS and dy >= -0.5 and dy <= FANG_HITBOX_HEIGHT) {
            const raw = self.damage;
            // Evoker fangs deal pure unmitigated magic damage:
            // 1. Armor absorption is 0% regardless of armor points
            const armor_absorbed: f32 = 0.0;
            // 2. Shield blocking is completely bypassed (no damage blocked, no shield durability lost)
            const shield_bypassed = target.shield_blocking;
            const actual_damage = raw;

            target.takeDamage(actual_damage);
            self.has_dealt_damage = true;

            return .{
                .hit = true,
                .damage_dealt = actual_damage,
                .raw_damage = raw,
                .armor_absorbed = armor_absorbed,
                .shield_bypassed = shield_bypassed,
                .target_health_after = target.health,
                .target_eliminated = !target.is_alive,
            };
        }

        return .{
            .hit = false,
            .damage_dealt = 0.0,
            .raw_damage = self.damage,
            .armor_absorbed = 0.0,
            .shield_bypassed = false,
            .target_health_after = target.health,
            .target_eliminated = false,
        };
    }
};

/// Computes Offensive Line Formation:
/// Summons a row of 16 fangs extending in a straight line toward target up to 20 blocks away.
pub fn computeOffensiveLineFangs(
    caster_id: u32,
    evoker_pos: [3]f32,
    target_pos: [3]f32,
) [OFFENSIVE_LINE_FANG_COUNT]EvokerFang {
    var fangs: [OFFENSIVE_LINE_FANG_COUNT]EvokerFang = undefined;

    const dx = target_pos[0] - evoker_pos[0];
    const dz = target_pos[2] - evoker_pos[2];
    const horiz_dist = @sqrt(dx * dx + dz * dz);

    const dir_x = if (horiz_dist > 0.0001) dx / horiz_dist else 0.0;
    const dir_z = if (horiz_dist > 0.0001) dz / horiz_dist else 1.0;
    const yaw = std.math.atan2(dir_z, dir_x);

    // Spacing: 1.25m per fang along line, covering up to 20.0 blocks (16 * 1.25 = 20.0m)
    const spacing = OFFENSIVE_LINE_DEFAULT_SPACING;

    for (0..OFFENSIVE_LINE_FANG_COUNT) |i| {
        const step = @as(f32, @floatFromInt(i + 1)) * spacing;
        const fang_pos = [3]f32{
            evoker_pos[0] + dir_x * step,
            evoker_pos[1],
            evoker_pos[2] + dir_z * step,
        };
        const warmup = @as(u32, @intCast(i)) * OFFENSIVE_LINE_STAGGER_TICKS;
        fangs[i] = EvokerFang.init(
            @as(u32, @intCast(i + 1)),
            caster_id,
            fang_pos,
            yaw,
            .offensive_line,
            @as(u8, @intCast(i)),
            warmup,
        );
    }

    return fangs;
}

/// Computes Defensive Circle Formation:
/// Summons two concentric rings of 8 and 12 fangs (total 20 fangs) surrounding the Evoker.
pub fn computeDefensiveCircleFangs(
    caster_id: u32,
    evoker_pos: [3]f32,
) [DEFENSIVE_CIRCLE_TOTAL_COUNT]EvokerFang {
    var fangs: [DEFENSIVE_CIRCLE_TOTAL_COUNT]EvokerFang = undefined;
    var idx: usize = 0;

    // Inner ring: 8 fangs at radius 1.5m
    const inner_count_f = @as(f32, @floatFromInt(DEFENSIVE_INNER_RING_COUNT));
    for (0..DEFENSIVE_INNER_RING_COUNT) |i| {
        const theta = (2.0 * std.math.pi * @as(f32, @floatFromInt(i))) / inner_count_f;
        const pos = [3]f32{
            evoker_pos[0] + DEFENSIVE_INNER_RING_RADIUS * @cos(theta),
            evoker_pos[1],
            evoker_pos[2] + DEFENSIVE_INNER_RING_RADIUS * @sin(theta),
        };
        fangs[idx] = EvokerFang.init(
            @as(u32, @intCast(idx + 1)),
            caster_id,
            pos,
            theta,
            .defensive_circle,
            @as(u8, @intCast(i)),
            0, // Inner ring begins warning immediately
        );
        idx += 1;
    }

    // Outer ring: 12 fangs at radius 3.0m
    const outer_count_f = @as(f32, @floatFromInt(DEFENSIVE_OUTER_RING_COUNT));
    for (0..DEFENSIVE_OUTER_RING_COUNT) |j| {
        const theta = (2.0 * std.math.pi * @as(f32, @floatFromInt(j))) / outer_count_f;
        const pos = [3]f32{
            evoker_pos[0] + DEFENSIVE_OUTER_RING_RADIUS * @cos(theta),
            evoker_pos[1],
            evoker_pos[2] + DEFENSIVE_OUTER_RING_RADIUS * @sin(theta),
        };
        fangs[idx] = EvokerFang.init(
            @as(u32, @intCast(idx + 1)),
            caster_id,
            pos,
            theta,
            .defensive_circle,
            @as(u8, @intCast(j)),
            1, // Outer ring ripples 1 tick later
        );
        idx += 1;
    }

    return fangs;
}

// ============================================================================
// Vex Entity Summoning & Flight Dynamics
// ============================================================================

pub const VexEntity = struct {
    id: u32,
    summoner_id: u32,
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    health: f32 = VEX_MAX_HEALTH,
    max_health: f32 = VEX_MAX_HEALTH,
    is_alive: bool = true,
    weapon: VexWeapon = .iron_sword,

    // Flight Dynamics & Charge State
    is_charging: bool = false,
    charge_timer_ticks: u32 = 0,
    target_pos: ?[3]f32 = null,

    // Life Decay (Starvation)
    life_decay_delay_ticks: u32 = VEX_MIN_DECAY_DELAY_TICKS,
    ticks_alive: u32 = 0,
    is_decaying: bool = false,
    summoner_alive: bool = true,

    pub fn init(id: u32, summoner_id: u32, pos: [3]f32, decay_delay_ticks: u32) VexEntity {
        const clamped_delay = std.math.clamp(
            decay_delay_ticks,
            VEX_MIN_DECAY_DELAY_TICKS,
            VEX_MAX_DECAY_DELAY_TICKS,
        );
        return .{
            .id = id,
            .summoner_id = summoner_id,
            .position = pos,
            .velocity = .{ 0.0, 0.0, 0.0 },
            .health = VEX_MAX_HEALTH,
            .max_health = VEX_MAX_HEALTH,
            .is_alive = true,
            .weapon = .iron_sword,
            .is_charging = false,
            .charge_timer_ticks = 0,
            .target_pos = null,
            .life_decay_delay_ticks = clamped_delay,
            .ticks_alive = 0,
            .is_decaying = false,
            .summoner_alive = true,
        };
    }

    /// Vexes ignore all block collision, phasing freely through solid walls, ceilings, and floors.
    pub fn canPhaseThroughBlocks() bool {
        return true;
    }

    pub fn collidesWithSolidBlock(self: *const VexEntity, block_pos: [3]i32, is_solid: bool) bool {
        _ = self;
        _ = block_pos;
        _ = is_solid;
        return false; // Phasing: never collides
    }

    /// Red-glow charging state: returns [3]u8{ 255, 0, 0 } when charging, null otherwise.
    pub fn glowColor(self: *const VexEntity) ?[3]u8 {
        return if (self.is_charging) .{ 255, 0, 0 } else null;
    }

    /// Iron Sword attack damage scaled by game difficulty.
    pub fn getAttackDamage(self: *const VexEntity, difficulty: Difficulty) f32 {
        _ = self;
        return switch (difficulty) {
            .peaceful => 0.0,
            .easy => VEX_DAMAGE_EASY,
            .normal => VEX_DAMAGE_NORMAL,
            .hard => VEX_DAMAGE_HARD,
        };
    }

    /// Initiates red-glow charge attack accelerating toward target at 8.0 m/s.
    pub fn startCharge(self: *VexEntity, target: [3]f32) void {
        self.is_charging = true;
        self.target_pos = target;
        self.charge_timer_ticks = VEX_CHARGE_DURATION_TICKS;

        const dir = normalizeVector([3]f32{
            target[0] - self.position[0],
            target[1] - self.position[1],
            target[2] - self.position[2],
        });
        self.velocity = [3]f32{
            dir[0] * VEX_CHARGE_SPEED,
            dir[1] * VEX_CHARGE_SPEED,
            dir[2] * VEX_CHARGE_SPEED,
        };
    }

    /// Terminates charging and reverts to cruising flight.
    pub fn stopCharge(self: *VexEntity) void {
        self.is_charging = false;
        self.target_pos = null;
        self.charge_timer_ticks = 0;

        const dir = normalizeVector(self.velocity);
        self.velocity = [3]f32{
            dir[0] * VEX_CRUISE_SPEED,
            dir[1] * VEX_CRUISE_SPEED,
            dir[2] * VEX_CRUISE_SPEED,
        };
    }

    /// When the summoning Evoker dies, Vex starvation begins immediately.
    pub fn summonerKilled(self: *VexEntity) void {
        self.summoner_alive = false;
        self.is_decaying = true;
    }

    /// Advance Vex flight kinematics and life decay timer.
    pub fn tick(self: *VexEntity, dt: f32) void {
        if (!self.is_alive) return;

        self.ticks_alive += 1;

        // Kinematics flight update (phasing through terrain freely)
        self.position[0] += self.velocity[0] * dt;
        self.position[1] += self.velocity[1] * dt;
        self.position[2] += self.velocity[2] * dt;

        // Charge duration update
        if (self.is_charging) {
            if (self.charge_timer_ticks > 0) {
                self.charge_timer_ticks -= 1;
            }
            if (self.charge_timer_ticks == 0) {
                self.stopCharge();
            }
        }

        // Life decay evaluation
        if (!self.summoner_alive or self.ticks_alive > self.life_decay_delay_ticks) {
            self.is_decaying = true;
        }

        if (self.is_decaying) {
            const decay_dmg = VEX_DECAY_RATE_PER_SECOND * dt;
            if (self.health > decay_dmg) {
                self.health -= decay_dmg;
            } else {
                self.health = 0.0;
                self.is_alive = false;
            }
        }
    }
};

/// Summons between 2 and 4 Vex entities.
pub fn summonVexCount(rng: anytype) u8 {
    return VEX_MIN_SUMMON_COUNT + rng.random().uintLessThan(u8, VEX_MAX_SUMMON_COUNT - VEX_MIN_SUMMON_COUNT + 1);
}

/// Summons a squadron of 2..4 Vex entities around the Evoker.
pub fn summonVexSquadron(
    summoner_id: u32,
    evoker_pos: [3]f32,
    count: u8,
    decay_delay_ticks: u32,
) [VEX_MAX_SUMMON_COUNT]?VexEntity {
    var squadron: [VEX_MAX_SUMMON_COUNT]?VexEntity = [_]?VexEntity{null} ** VEX_MAX_SUMMON_COUNT;
    const actual_count = std.math.clamp(count, VEX_MIN_SUMMON_COUNT, VEX_MAX_SUMMON_COUNT);

    for (0..actual_count) |i| {
        const angle = (2.0 * std.math.pi * @as(f32, @floatFromInt(i))) / @as(f32, @floatFromInt(actual_count));
        const spawn_pos = [3]f32{
            evoker_pos[0] + 1.0 * @cos(angle),
            evoker_pos[1] + 1.2,
            evoker_pos[2] + 1.0 * @sin(angle),
        };
        squadron[i] = VexEntity.init(
            @as(u32, @intCast(i + 100)),
            summoner_id,
            spawn_pos,
            decay_delay_ticks,
        );
    }

    return squadron;
}

// ============================================================================
// Wololo Sheep Conversion Mechanics
// ============================================================================

pub const Sheep = struct {
    id: u32,
    position: [3]f32,
    color: SheepColor = .white,
};

pub const WololoResult = struct {
    chanted: bool,
    converted: bool,
    previous_color: SheepColor,
    new_color: SheepColor,
};

/// Converts blue sheep to red sheep within 16.0m of the Evoker!
pub fn wololoConvertSheep(evoker_pos: [3]f32, sheep: *Sheep) WololoResult {
    const dist = distance3D(evoker_pos, sheep.position);
    if (dist <= WOLOLO_RANGE and sheep.color == .blue) {
        const prev = sheep.color;
        sheep.color = .red;
        return .{
            .chanted = true,
            .converted = true,
            .previous_color = prev,
            .new_color = .red,
        };
    }
    return .{
        .chanted = false,
        .converted = false,
        .previous_color = sheep.color,
        .new_color = sheep.color,
    };
}

// ============================================================================
// Particle Swirl Generation
// ============================================================================

pub const Particle = struct {
    particle_type: ParticleType,
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    color_rgba: [4]f32,
    lifetime_ticks: u16 = 20,
};

/// Generates helical spell swirl particles centered around the Evoker during spellcasting.
pub fn generateSpellParticles(
    spell: SpellType,
    caster_pos: [3]f32,
    tick: u32,
    count: usize,
) [8]Particle {
    var particles: [8]Particle = undefined;
    const actual_count = @min(count, 8);
    const color = spell.particleColor();
    const p_type = spell.particleType();
    const tick_f = @as(f32, @floatFromInt(tick));

    for (0..actual_count) |i| {
        const i_f = @as(f32, @floatFromInt(i));
        const angle = tick_f * 0.3 + i_f * (std.math.pi * 2.0 / @as(f32, @floatFromInt(actual_count)));
        const radius: f32 = 0.6;
        const height_offset: f32 = 0.5 + 0.8 * @sin(tick_f * 0.1 + i_f);

        particles[i] = .{
            .particle_type = p_type,
            .position = .{
                caster_pos[0] + radius * @cos(angle),
                caster_pos[1] + height_offset,
                caster_pos[2] + radius * @sin(angle),
            },
            .velocity = .{
                -0.1 * @sin(angle),
                0.05,
                0.1 * @cos(angle),
            },
            .color_rgba = color,
            .lifetime_ticks = 20,
        };
    }

    // Fill remainder with dummy particles
    for (actual_count..8) |i| {
        particles[i] = .{
            .particle_type = .none,
            .position = caster_pos,
            .velocity = .{ 0.0, 0.0, 0.0 },
            .color_rgba = .{ 0.0, 0.0, 0.0, 0.0 },
            .lifetime_ticks = 0,
        };
    }

    return particles;
}

// ============================================================================
// Unit Tests (25+ Comprehensive Test Suite)
// ============================================================================

test "1. Evoker max health is exactly 24.0 HP (12 hearts)" {
    const evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    try std.testing.expectEqual(@as(f32, 24.0), evoker.health);
    try std.testing.expectEqual(@as(f32, 24.0), evoker.max_health);
    try std.testing.expectEqual(@as(f32, 12.0), EVOKER_MAX_HEARTS);
    try std.testing.expect(evoker.is_alive);
}

test "2. Evoker initial spellcasting state is SpellType.none with arms lowered" {
    const evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    try std.testing.expectEqual(SpellType.none, evoker.current_spell);
    try std.testing.expectEqual(@as(u32, 0), evoker.spell_warmup_remaining);
    try std.testing.expect(!evoker.arm_raising);
    try std.testing.expect(!evoker.is_fleeing);
}

test "3. SpellType.fangs requires 40 ticks (2.0s) arm-raising animation" {
    try std.testing.expectEqual(@as(u32, 40), EVOKER_CASTING_TICKS_FANGS);
    try std.testing.expectEqual(@as(u32, 40), SpellType.fangs.warmupTicks());
}

test "4. SpellType.vex requires 100 ticks (5.0s) arm-raising animation" {
    try std.testing.expectEqual(@as(u32, 100), EVOKER_CASTING_TICKS_VEX);
    try std.testing.expectEqual(@as(u32, 100), SpellType.vex.warmupTicks());
}

test "5. SpellType.wololo requires 60 ticks (3.0s) arm-raising animation" {
    try std.testing.expectEqual(@as(u32, 60), EVOKER_CASTING_TICKS_WOLOLO);
    try std.testing.expectEqual(@as(u32, 60), SpellType.wololo.warmupTicks());
}

test "6. SpellType.none has 0 warmup ticks" {
    try std.testing.expectEqual(@as(u32, 0), SpellType.none.warmupTicks());
}

test "7. Particle colors: fangs emits dark purple spell_mob particle swirls" {
    const color = SpellType.fangs.particleColor();
    try std.testing.expectEqual(ParticleType.spell_mob, SpellType.fangs.particleType());
    try std.testing.expectApproxEqAbs(@as(f32, 0.38), color[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.15), color[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.58), color[2], 0.01);
    try std.testing.expectEqual(@as(f32, 1.0), color[3]);
}

test "8. Particle colors: vex emits pure white spell_mob particle swirls" {
    const color = SpellType.vex.particleColor();
    try std.testing.expectEqual(ParticleType.spell_mob, SpellType.vex.particleType());
    try std.testing.expectEqual(@as(f32, 1.0), color[0]);
    try std.testing.expectEqual(@as(f32, 1.0), color[1]);
    try std.testing.expectEqual(@as(f32, 1.0), color[2]);
    try std.testing.expectEqual(@as(f32, 1.0), color[3]);
}

test "9. Particle colors: wololo emits orange/yellow spell_mob particle swirls" {
    const color = SpellType.wololo.particleColor();
    try std.testing.expectEqual(ParticleType.spell_mob, SpellType.wololo.particleType());
    try std.testing.expect(color[0] > 0.8); // High red
    try std.testing.expect(color[1] > 0.6); // Medium-high green (yellow/orange)
    try std.testing.expect(color[2] < 0.3); // Low blue
}

test "10. State machine: startCasting fangs sets arm_raising and warmup to 40 ticks" {
    var evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(evoker.startCasting(.fangs));
    try std.testing.expect(evoker.arm_raising);
    try std.testing.expectEqual(SpellType.fangs, evoker.current_spell);
    try std.testing.expectEqual(@as(u32, 40), evoker.spell_warmup_remaining);
}

test "11. State machine: startCasting vex sets arm_raising and warmup to 100 ticks" {
    var evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(evoker.startCasting(.vex));
    try std.testing.expect(evoker.arm_raising);
    try std.testing.expectEqual(SpellType.vex, evoker.current_spell);
    try std.testing.expectEqual(@as(u32, 100), evoker.spell_warmup_remaining);
}

test "12. State machine: startCasting wololo sets arm_raising and warmup to 60 ticks" {
    var evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(evoker.startCasting(.wololo));
    try std.testing.expect(evoker.arm_raising);
    try std.testing.expectEqual(SpellType.wololo, evoker.current_spell);
    try std.testing.expectEqual(@as(u32, 60), evoker.spell_warmup_remaining);
}

test "13. State machine: tick decrements warmup and fires completion event at tick 0" {
    var evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    _ = evoker.startCasting(.fangs);

    // 39 ticks: still casting
    for (0..39) |_| {
        const ev = evoker.tick();
        try std.testing.expectEqual(@as(?SpellCompletionEvent, null), ev);
        try std.testing.expect(evoker.arm_raising);
    }
    try std.testing.expectEqual(@as(u32, 1), evoker.spell_warmup_remaining);

    // 40th tick: spell completes!
    const finish_event = evoker.tick();
    try std.testing.expect(finish_event != null);
    try std.testing.expectEqual(SpellType.fangs, finish_event.?.spell);
    try std.testing.expect(!evoker.arm_raising);
    try std.testing.expectEqual(SpellType.none, evoker.current_spell);
    try std.testing.expectEqual(EVOKER_FANGS_COOLDOWN_TICKS, evoker.fangs_cooldown_ticks);
    try std.testing.expectEqual(EVOKER_GLOBAL_SPELL_COOLDOWN_TICKS, evoker.global_cooldown_ticks);
}

test "14. State machine: cannot start casting while already channeling a spell" {
    var evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(evoker.startCasting(.fangs));
    try std.testing.expect(!evoker.startCasting(.vex));
    try std.testing.expect(!evoker.startCasting(.wololo));
}

test "15. Evoker fleeing behavior: computes flee velocity away from target inside 3.0m" {
    var evoker = EvokerEntity.init(1, .{ 10.0, 64.0, 10.0 });
    const player_pos = [3]f32{ 11.0, 64.0, 10.0 }; // Player 1.0m to the right (+X)
    const flee_vel = evoker.computeFleeVelocity(player_pos, EVOKER_FLEE_SPEED);

    try std.testing.expect(evoker.is_fleeing);
    try std.testing.expect(flee_vel[0] < -2.9); // Fleeing in -X direction
    try std.testing.expectEqual(@as(f32, 0.0), flee_vel[1]);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), flee_vel[2], 0.001);
}

test "16. Spell selection AI: selects defensive circle fangs when target within 3.0m" {
    const evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    const close_target = [3]f32{ 2.5, 64.0, 0.0 }; // 2.5m <= 3.0m
    const spell = evoker.selectSpell(close_target, 0, null, true);
    try std.testing.expectEqual(SpellType.fangs, spell);
}

test "17. Spell selection AI: selects vex summoning when target > 3.0m and vex count < cap" {
    const evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    const target = [3]f32{ 10.0, 64.0, 0.0 }; // 10.0m > 3.0m
    const spell = evoker.selectSpell(target, 2, null, true); // active vexes = 2 < 8
    try std.testing.expectEqual(SpellType.vex, spell);
}

test "18. Spell selection AI: selects offensive line fangs when target > 3.0m and vex count at cap" {
    const evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    const target = [3]f32{ 10.0, 64.0, 0.0 };
    const spell = evoker.selectSpell(target, EVOKER_VEX_ACTIVE_CAP, null, true); // at cap 8
    try std.testing.expectEqual(SpellType.fangs, spell);
}

test "19. Spell selection AI: selects wololo when not in combat and blue sheep within 16.0m" {
    const evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    const blue_sheep_pos = [3]f32{ 8.0, 64.0, 8.0 }; // dist ~ 11.3m <= 16.0m
    const spell = evoker.selectSpell(null, 0, blue_sheep_pos, false);
    try std.testing.expectEqual(SpellType.wololo, spell);
}

test "20. Spell selection AI: suppresses spells when on global cooldown" {
    var evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    evoker.global_cooldown_ticks = 10;
    const target = [3]f32{ 2.0, 64.0, 0.0 };
    try std.testing.expectEqual(SpellType.none, evoker.selectSpell(target, 0, null, true));
}

test "21. Offensive line fangs: generates exactly 16 fangs" {
    const evoker_pos = [3]f32{ 0.0, 64.0, 0.0 };
    const target_pos = [3]f32{ 20.0, 64.0, 0.0 };
    const fangs = computeOffensiveLineFangs(1, evoker_pos, target_pos);

    try std.testing.expectEqual(@as(usize, 16), fangs.len);
    try std.testing.expectEqual(@as(usize, 16), OFFENSIVE_LINE_FANG_COUNT);
}

test "22. Offensive line fangs: extends up to 20.0 blocks along straight line" {
    const evoker_pos = [3]f32{ 0.0, 64.0, 0.0 };
    const target_pos = [3]f32{ 20.0, 64.0, 0.0 };
    const fangs = computeOffensiveLineFangs(1, evoker_pos, target_pos);

    // Final fang (index 15) must reach exactly 20.0m along X
    const first_fang = fangs[0];
    const last_fang = fangs[15];

    try std.testing.expectApproxEqAbs(@as(f32, 1.25), first_fang.position[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), last_fang.position[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), last_fang.position[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), last_fang.position[2], 0.001);
}

test "23. Offensive line fangs: spacing between consecutive fangs is exactly 1.25m" {
    const evoker_pos = [3]f32{ 0.0, 64.0, 0.0 };
    const target_pos = [3]f32{ 0.0, 64.0, 20.0 };
    const fangs = computeOffensiveLineFangs(1, evoker_pos, target_pos);

    for (0..15) |i| {
        const d = distance3D(fangs[i].position, fangs[i + 1].position);
        try std.testing.expectApproxEqAbs(@as(f32, 1.25), d, 0.001);
    }
}

test "24. Offensive line fangs: sequential activation delay increments by 1 tick per fang" {
    const evoker_pos = [3]f32{ 0.0, 64.0, 0.0 };
    const target_pos = [3]f32{ 15.0, 64.0, 0.0 };
    const fangs = computeOffensiveLineFangs(1, evoker_pos, target_pos);

    for (0..16) |i| {
        try std.testing.expectEqual(@as(u32, @intCast(i)), fangs[i].warmup_delay_ticks);
    }
}

test "25. Offensive line fangs: yaw aligns with vector from evoker to target" {
    const evoker_pos = [3]f32{ 10.0, 64.0, 10.0 };
    const target_pos = [3]f32{ 10.0, 64.0, 30.0 }; // Along +Z
    const fangs = computeOffensiveLineFangs(1, evoker_pos, target_pos);

    // dir_z > 0, dir_x = 0 -> atan2(1, 0) = pi / 2
    try std.testing.expectApproxEqAbs(std.math.pi * 0.5, fangs[0].yaw, 0.001);
}

test "26. Defensive circle fangs: generates exactly 20 fangs in total" {
    const evoker_pos = [3]f32{ 50.0, 64.0, 50.0 };
    const fangs = computeDefensiveCircleFangs(1, evoker_pos);

    try std.testing.expectEqual(@as(usize, 20), fangs.len);
    try std.testing.expectEqual(@as(usize, 20), DEFENSIVE_CIRCLE_TOTAL_COUNT);
}

test "27. Defensive circle fangs: inner ring contains exactly 8 fangs at radius 1.5m" {
    const evoker_pos = [3]f32{ 50.0, 64.0, 50.0 };
    const fangs = computeDefensiveCircleFangs(1, evoker_pos);

    for (0..8) |i| {
        const d = distanceXZ(evoker_pos, fangs[i].position);
        try std.testing.expectApproxEqAbs(@as(f32, 1.5), d, 0.001);
        try std.testing.expectEqual(FangFormationKind.defensive_circle, fangs[i].formation);
    }
}

test "28. Defensive circle fangs: outer ring contains exactly 12 fangs at radius 3.0m" {
    const evoker_pos = [3]f32{ 50.0, 64.0, 50.0 };
    const fangs = computeDefensiveCircleFangs(1, evoker_pos);

    for (8..20) |j| {
        const d = distanceXZ(evoker_pos, fangs[j].position);
        try std.testing.expectApproxEqAbs(@as(f32, 3.0), d, 0.001);
        try std.testing.expectEqual(FangFormationKind.defensive_circle, fangs[j].formation);
    }
}

test "29. Defensive circle fangs: rings are concentric around evoker position" {
    const evoker_pos = [3]f32{ 120.0, 70.0, -80.0 };
    const fangs = computeDefensiveCircleFangs(1, evoker_pos);

    for (fangs) |fang| {
        try std.testing.expectEqual(@as(f32, 70.0), fang.position[1]);
        const d = distanceXZ(evoker_pos, fang.position);
        const is_inner = std.math.approxEqAbs(f32, d, 1.5, 0.01);
        const is_outer = std.math.approxEqAbs(f32, d, 3.0, 0.01);
        try std.testing.expect(is_inner or is_outer);
    }
}

test "30. Defensive circle fangs: circular angles are evenly distributed around 360 degrees" {
    const evoker_pos = [3]f32{ 0.0, 64.0, 0.0 };
    const fangs = computeDefensiveCircleFangs(1, evoker_pos);

    // Inner ring spacing: 2*pi / 8 = pi / 4 radians (45 degrees)
    const inner_0 = std.math.atan2(fangs[0].position[2], fangs[0].position[0]);
    const inner_1 = std.math.atan2(fangs[1].position[2], fangs[1].position[0]);
    var diff = inner_1 - inner_0;
    if (diff < 0) diff += 2.0 * std.math.pi;
    try std.testing.expectApproxEqAbs(std.math.pi * 0.25, diff, 0.001);
}

test "31. Fang lifecycle: warning phase lasts 14 ticks (0.7s)" {
    var fang = EvokerFang.init(1, 10, .{ 0, 64, 0 }, 0.0, .offensive_line, 0, 0);

    for (0..14) |_| {
        try std.testing.expectEqual(FangPhase.warning, fang.phase);
        const ev = fang.tick();
        try std.testing.expectEqual(@as(?FangSnapEvent, null), ev);
    }
}

test "32. Fang lifecycle: transitions to snap phase at tick 14 and fires snap event" {
    var fang = EvokerFang.init(1, 10, .{ 0, 64, 0 }, 0.0, .offensive_line, 0, 0);

    for (0..14) |_| {
        _ = fang.tick();
    }

    // At tick 14 (15th call to tick()): snap triggers!
    const snap_ev = fang.tick();
    try std.testing.expect(snap_ev != null);
    try std.testing.expectEqual(SoundEffect.fang_snap, snap_ev.?.sound);
    try std.testing.expectEqual(@as(f32, 6.0), snap_ev.?.damage);
    try std.testing.expect(fang.has_snapped);
}

test "33. Fang lifecycle: retraction phase lasts 20 ticks (1.0s)" {
    var fang = EvokerFang.init(1, 10, .{ 0, 64, 0 }, 0.0, .offensive_line, 0, 0);

    // Warning (14) + Snap (1) = 15 ticks
    for (0..15) |_| {
        _ = fang.tick();
    }

    // Next 20 ticks: in retraction phase
    for (0..20) |_| {
        _ = fang.tick();
        try std.testing.expectEqual(FangPhase.retraction, fang.phase);
    }
}

test "34. Fang lifecycle: disappears and marks expired after total duration" {
    var fang = EvokerFang.init(1, 10, .{ 0, 64, 0 }, 0.0, .offensive_line, 0, 0);

    // Warning (14) + Snap (1) + Retraction (20) = 35 ticks
    for (0..35) |_| {
        _ = fang.tick();
    }

    // Next tick: expired
    _ = fang.tick();
    try std.testing.expectEqual(FangPhase.expired, fang.phase);
    try std.testing.expect(!fang.is_active);
}

test "35. Fang snap damage: deals 6.0 HP unmitigated damage to unarmored target" {
    var fang = EvokerFang.init(1, 10, .{ 5.0, 64.0, 5.0 }, 0.0, .offensive_line, 0, 0);
    var player = CombatTarget{
        .id = 99,
        .position = .{ 5.2, 64.0, 5.1 },
        .health = 20.0,
        .armor_points = 0.0,
        .shield_blocking = false,
    };

    const res = fang.dealDamageToTarget(&player);
    try std.testing.expect(res.hit);
    try std.testing.expectEqual(@as(f32, 6.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 14.0), player.health);
    try std.testing.expect(fang.has_dealt_damage);
}

test "36. Fang snap damage: bypasses armor points completely (20 armor points takes full 6.0 HP)" {
    var fang = EvokerFang.init(1, 10, .{ 5.0, 64.0, 5.0 }, 0.0, .offensive_line, 0, 0);
    var full_diamond_player = CombatTarget{
        .id = 99,
        .position = .{ 5.0, 64.0, 5.0 },
        .health = 20.0,
        .armor_points = 20.0, // Full diamond armor
        .shield_blocking = false,
    };

    const res = fang.dealDamageToTarget(&full_diamond_player);
    try std.testing.expect(res.hit);
    try std.testing.expectEqual(@as(f32, 6.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 0.0), res.armor_absorbed); // 0% reduction!
    try std.testing.expectEqual(@as(f32, 14.0), full_diamond_player.health);
}

test "37. Fang snap damage: bypasses shield blocks completely without shield durability loss" {
    var fang = EvokerFang.init(1, 10, .{ 5.0, 64.0, 5.0 }, 0.0, .offensive_line, 0, 0);
    var blocking_player = CombatTarget{
        .id = 99,
        .position = .{ 5.0, 64.0, 5.0 },
        .health = 20.0,
        .armor_points = 20.0,
        .shield_blocking = true, // Holding shield
        .shield_durability = 336,
    };

    const res = fang.dealDamageToTarget(&blocking_player);
    try std.testing.expect(res.hit);
    try std.testing.expect(res.shield_bypassed);
    try std.testing.expectEqual(@as(f32, 6.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 14.0), blocking_player.health);
    try std.testing.expectEqual(@as(u16, 336), blocking_player.shield_durability); // Shield unharmed
}

test "38. Fang friendly fire immunity: does not damage summoning evoker or illagers" {
    var fang = EvokerFang.init(1, 10, .{ 0.0, 64.0, 0.0 }, 0.0, .defensive_circle, 0, 0);
    var summoner = CombatTarget{
        .id = 10, // Same as caster_id
        .position = .{ 0.0, 64.0, 0.0 },
        .health = 24.0,
        .is_illager = true,
    };

    const res = fang.dealDamageToTarget(&summoner);
    try std.testing.expect(!res.hit);
    try std.testing.expectEqual(@as(f32, 24.0), summoner.health);
}

test "39. Vex summoning: summonVexCount returns between 2 and 4 entities" {
    var prng = std.Random.DefaultPrng.init(12345);
    for (0..50) |_| {
        const count = summonVexCount(&prng);
        try std.testing.expect(count >= 2);
        try std.testing.expect(count <= 4);
    }
}

test "40. Vex squadron spawning: creates valid entities with 14.0 HP around evoker" {
    const squadron = summonVexSquadron(1, .{ 10.0, 64.0, 10.0 }, 3, 1000);
    try std.testing.expect(squadron[0] != null);
    try std.testing.expect(squadron[1] != null);
    try std.testing.expect(squadron[2] != null);
    try std.testing.expect(squadron[3] == null); // 4th is null

    try std.testing.expectEqual(@as(f32, 14.0), squadron[0].?.health);
    try std.testing.expectEqual(@as(f32, 14.0), squadron[0].?.max_health);
}

test "41. Vex attributes: initial health is 14.0 HP (7 hearts)" {
    const vex = VexEntity.init(100, 1, .{ 0, 64, 0 }, 1000);
    try std.testing.expectEqual(@as(f32, 14.0), vex.health);
    try std.testing.expectEqual(@as(f32, 7.0), VEX_MAX_HEARTS);
    try std.testing.expectEqual(VexWeapon.iron_sword, vex.weapon);
    try std.testing.expect(vex.is_alive);
}

test "42. Vex flight phasing: vex ignores block collision, phasing through solid blocks" {
    const vex = VexEntity.init(100, 1, .{ 0, 64, 0 }, 1000);
    try std.testing.expect(VexEntity.canPhaseThroughBlocks());
    try std.testing.expect(!vex.collidesWithSolidBlock(.{ 0, 64, 1 }, true));
    try std.testing.expect(!vex.collidesWithSolidBlock(.{ 0, 63, 0 }, true)); // Floor
}

test "43. Vex weapon damage: deals 9.0 HP on Normal difficulty" {
    const vex = VexEntity.init(100, 1, .{ 0, 64, 0 }, 1000);
    try std.testing.expectEqual(@as(f32, 9.0), vex.getAttackDamage(.normal));
}

test "44. Vex weapon damage: deals 13.0 HP on Hard difficulty" {
    const vex = VexEntity.init(100, 1, .{ 0, 64, 0 }, 1000);
    try std.testing.expectEqual(@as(f32, 13.0), vex.getAttackDamage(.hard));
}

test "45. Vex weapon damage: deals 5.0 HP on Easy difficulty" {
    const vex = VexEntity.init(100, 1, .{ 0, 64, 0 }, 1000);
    try std.testing.expectEqual(@as(f32, 5.0), vex.getAttackDamage(.easy));
}

test "46. Vex red charge attack: activates red glow and accelerates to 8.0 m/s" {
    var vex = VexEntity.init(100, 1, .{ 0.0, 64.0, 0.0 }, 1000);
    try std.testing.expectEqual(@as(?[3]u8, null), vex.glowColor());

    vex.startCharge(.{ 8.0, 64.0, 0.0 });
    try std.testing.expect(vex.is_charging);
    try std.testing.expectEqual(@as(?[3]u8, .{ 255, 0, 0 }), vex.glowColor());

    // Velocity should be 8.0 m/s along +X
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), vex.velocity[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), vex.velocity[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), vex.velocity[2], 0.001);
}

test "47. Vex red charge attack: reverts to cruise speed (3.0 m/s) and clears glow on completion" {
    var vex = VexEntity.init(100, 1, .{ 0.0, 64.0, 0.0 }, 1000);
    vex.startCharge(.{ 0.0, 64.0, 10.0 });

    // Tick for 40 ticks (2.0s)
    for (0..40) |_| {
        vex.tick(TICK_DT);
    }

    try std.testing.expect(!vex.is_charging);
    try std.testing.expectEqual(@as(?[3]u8, null), vex.glowColor());
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), vex.velocity[2], 0.001);
}

test "48. Vex life decay: delay is clamped between 30 and 119 seconds (600..2380 ticks)" {
    const vex_low = VexEntity.init(1, 1, .{ 0, 0, 0 }, 10); // Below 600
    const vex_high = VexEntity.init(2, 1, .{ 0, 0, 0 }, 5000); // Above 2380
    const vex_mid = VexEntity.init(3, 1, .{ 0, 0, 0 }, 1200);

    try std.testing.expectEqual(@as(u32, 600), vex_low.life_decay_delay_ticks);
    try std.testing.expectEqual(@as(u32, 2380), vex_high.life_decay_delay_ticks);
    try std.testing.expectEqual(@as(u32, 1200), vex_mid.life_decay_delay_ticks);
}

test "49. Vex life decay: takes 1.0 HP/s (0.05 HP/tick) after delay expires" {
    var vex = VexEntity.init(1, 1, .{ 0, 0, 0 }, 600); // 600 ticks delay

    // Fast-forward 600 ticks
    for (0..600) |_| {
        vex.tick(TICK_DT);
    }
    try std.testing.expectEqual(@as(f32, 14.0), vex.health);

    // Next 20 ticks (1.0s): health decreases by 1.0 HP
    for (0..20) |_| {
        vex.tick(TICK_DT);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 13.0), vex.health, 0.001);
}

test "50. Vex life decay: dies naturally when health reaches 0.0" {
    var vex = VexEntity.init(1, 1, .{ 0, 0, 0 }, 600);
    vex.ticks_alive = 600;
    vex.is_decaying = true;

    // 14 seconds of decay: 14 * 20 = 280 ticks
    for (0..280) |_| {
        vex.tick(TICK_DT);
    }

    try std.testing.expectEqual(@as(f32, 0.0), vex.health);
    try std.testing.expect(!vex.is_alive);
}

test "51. Vex life decay: killing summoner immediately initiates life decay" {
    var vex = VexEntity.init(1, 1, .{ 0, 0, 0 }, 2380);
    try std.testing.expect(!vex.is_decaying);

    vex.summonerKilled();
    try std.testing.expect(vex.is_decaying);
    try std.testing.expect(!vex.summoner_alive);

    // Decays immediately on next tick
    vex.tick(TICK_DT);
    try std.testing.expect(vex.health < 14.0);
}

test "52. Wololo sheep conversion: converts blue sheep to red sheep within 16.0m" {
    const evoker_pos = [3]f32{ 0.0, 64.0, 0.0 };
    var blue_sheep = Sheep{ .id = 1, .position = .{ 10.0, 64.0, 5.0 }, .color = .blue };

    const res = wololoConvertSheep(evoker_pos, &blue_sheep);
    try std.testing.expect(res.chanted);
    try std.testing.expect(res.converted);
    try std.testing.expectEqual(SheepColor.blue, res.previous_color);
    try std.testing.expectEqual(SheepColor.red, res.new_color);
    try std.testing.expectEqual(SheepColor.red, blue_sheep.color);
}

test "53. Wololo sheep conversion: blue sheep beyond 16.0m is not converted" {
    const evoker_pos = [3]f32{ 0.0, 64.0, 0.0 };
    var far_sheep = Sheep{ .id = 2, .position = .{ 17.0, 64.0, 0.0 }, .color = .blue }; // 17.0m > 16.0m

    const res = wololoConvertSheep(evoker_pos, &far_sheep);
    try std.testing.expect(!res.chanted);
    try std.testing.expect(!res.converted);
    try std.testing.expectEqual(SheepColor.blue, far_sheep.color);
}

test "54. Wololo sheep conversion: non-blue sheep are not converted" {
    const evoker_pos = [3]f32{ 0.0, 64.0, 0.0 };
    var white_sheep = Sheep{ .id = 3, .position = .{ 5.0, 64.0, 0.0 }, .color = .white };

    const res = wololoConvertSheep(evoker_pos, &white_sheep);
    try std.testing.expect(!res.chanted);
    try std.testing.expect(!res.converted);
    try std.testing.expectEqual(SheepColor.white, white_sheep.color);
}

test "55. Integrated combat simulation: defensive circle, offensive line, vex charging and phasing" {
    // 1. Evoker spawns
    var evoker = EvokerEntity.init(1, .{ 0.0, 64.0, 0.0 });
    var player = CombatTarget{
        .id = 999,
        .position = .{ 2.0, 64.0, 0.0 }, // Player is within 3m
        .health = 20.0,
        .armor_points = 20.0,
        .shield_blocking = true,
    };

    // Close defense triggers fangs
    const spell = evoker.selectSpell(player.position, 0, null, true);
    try std.testing.expectEqual(SpellType.fangs, spell);
    try std.testing.expect(evoker.startCasting(spell));

    // Fast forward 40 ticks casting animation
    for (0..40) |_| {
        _ = evoker.tick();
    }

    // Defensive circle spawns 20 fangs
    var circle_fangs = computeDefensiveCircleFangs(evoker.id, evoker.position);
    try std.testing.expectEqual(@as(usize, 20), circle_fangs.len);

    // Fang warning phase (14 ticks)
    for (0..14) |_| {
        for (&circle_fangs) |*fang| {
            _ = fang.tick();
        }
    }

    // Snap phase: snaps and deals damage through player's shield and armor!
    for (&circle_fangs) |*fang| {
        const snap_ev = fang.tick();
        if (snap_ev != null) {
            _ = fang.dealDamageToTarget(&player);
        }
    }

    // Player took 6.0 HP unmitigated damage through shield
    try std.testing.expectEqual(@as(f32, 14.0), player.health);

    // Evoker summons Vex squadron
    const vexes = summonVexSquadron(evoker.id, evoker.position, 2, 600);
    var vex = vexes[0].?;

    // Vex phases through a solid wall between (0,64,0) and (10,64,0)
    try std.testing.expect(VexEntity.canPhaseThroughBlocks());
    try std.testing.expect(!vex.collidesWithSolidBlock(.{ 5, 64, 0 }, true));

    // Vex charges player at 8.0 m/s with red glow
    vex.startCharge(player.position);
    try std.testing.expect(vex.is_charging);
    try std.testing.expectEqual(@as(?[3]u8, .{ 255, 0, 0 }), vex.glowColor());
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), @sqrt(vex.velocity[0]*vex.velocity[0] + vex.velocity[1]*vex.velocity[1] + vex.velocity[2]*vex.velocity[2]), 0.001);
}
