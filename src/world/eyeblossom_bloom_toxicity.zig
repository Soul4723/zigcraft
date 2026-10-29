//! ============================================================================
//! Milestone 533: Eyeblossom Day/Night Bloom & Bee Poison Dynamics in Zigcraft
//! ============================================================================
//!
//! This module implements the mechanics of Eyeblossom flowers from the Pale Garden
//! biome:
//! 1. Eyeblossom State Machine & Nocturnal Transition:
//!    - Closed Eyeblossom (daytime ticks 0..12,999 or 23,001..24,000, or skylight > 7):
//!      Closed grey petals, no eye visible, non-emissive (emissive = 0.0).
//!    - Open Eyeblossom (nighttime ticks 13,000..23,000 or skylight <= 7):
//!      Petals bloom open revealing glowing orange iris, emissive glow (emissive = 0.6),
//!      emits ambient drifting orange eye sparkle particles.
//!    - Dusk opening transition (at tick 13,000 or darkness entry): snaps open,
//!      emits SoundEffect.eyeblossom_open.
//!    - Dawn closing transition (at tick 23,000 or light return): snaps shut,
//!      emits SoundEffect.eyeblossom_close.
//! 2. Bee Pollination & Toxicity Interaction:
//!    - Pollinating closed eyeblossom: gathers nectar safely without adverse effects
//!      (is_poisoned = false, is_angered = false).
//!    - Pollinating open eyeblossom: receives Poison status effect dealing 1.0 HP
//!      magic damage per second (duration 10.0 seconds / 200 ticks); bee becomes
//!      immediately agitated/angered (is_angered = true, eyes glow red, flying erratically).
//! 3. Suspicious Stew Crafting Synergy:
//!    - Crafting with Closed Eyeblossom: Suspicious Stew providing Speed I buff for 10.0s (200 ticks).
//!    - Crafting with Open Eyeblossom: Suspicious Stew inflicting Blindness I debuff for 10.0s (200 ticks).

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;
pub const DAY_TICKS_TOTAL: u32 = 24_000;

/// Dusk opening transition tick in standard 24,000-tick day cycle.
pub const DUSK_OPEN_TICK: u32 = 13_000;

/// Dawn closing transition tick in standard 24,000-tick day cycle.
pub const DAWN_CLOSE_TICK: u32 = 23_000;

/// Light level threshold for darkness: skylight <= 7 forces Eyeblossom open.
pub const DARKNESS_LIGHT_THRESHOLD: u8 = 7;

/// Light level threshold for daylight: skylight > 7 required for closed daytime state.
pub const DAYLIGHT_MIN_THRESHOLD: u8 = 8;

/// Emissive radiance when closed (non-emissive).
pub const CLOSED_EMISSIVE: f32 = 0.0;

/// Emissive radiance when open (glowing orange iris).
pub const OPEN_EMISSIVE: f32 = 0.6;

/// Poison duration on bee: 10.0 seconds = 200 game ticks.
pub const POISON_DURATION_TICKS: u32 = 200;
pub const POISON_DURATION_SECONDS: f32 = 10.0;

/// Poison damage rate: 1.0 HP magic damage per second (every 20 ticks).
pub const POISON_DAMAGE_INTERVAL_TICKS: u32 = 20;
pub const POISON_DAMAGE_PER_INTERVAL: f32 = 1.0;
pub const POISON_DAMAGE_RATE: f32 = 1.0;

/// Suspicious Stew Speed I buff duration: 10.0 seconds = 200 ticks.
pub const STEW_SPEED_DURATION_TICKS: u32 = 200;
pub const STEW_SPEED_DURATION_SECONDS: f32 = 10.0;

/// Suspicious Stew Blindness I debuff duration: 10.0 seconds = 200 ticks.
pub const STEW_BLINDNESS_DURATION_TICKS: u32 = 200;
pub const STEW_BLINDNESS_DURATION_SECONDS: f32 = 10.0;

/// Default bee maximum health (10.0 HP = 5 hearts).
pub const BEE_DEFAULT_MAX_HEALTH: f32 = 10.0;

/// Bee agitation / anger duration when poisoned: 400 ticks (20.0 seconds).
pub const BEE_ANGER_DURATION_TICKS: u32 = 400;

// ============================================================================
// Enums & Types
// ============================================================================

/// Eyeblossom flower open vs closed state.
pub const EyeblossomState = enum(u8) {
    closed = 0,
    open = 1,

    pub fn isOpen(self: EyeblossomState) bool {
        return self == .open;
    }

    pub fn isClosed(self: EyeblossomState) bool {
        return self == .closed;
    }

    pub fn emissive(self: EyeblossomState) f32 {
        return switch (self) {
            .closed => CLOSED_EMISSIVE,
            .open => OPEN_EMISSIVE,
        };
    }

    pub fn isEyeVisible(self: EyeblossomState) bool {
        return self == .open;
    }

    pub fn petalColorRgba(self: EyeblossomState) [4]f32 {
        return switch (self) {
            .closed => .{ 0.55, 0.55, 0.55, 1.0 }, // closed grey petals
            .open => .{ 0.85, 0.45, 0.15, 1.0 }, // bloom open petals
        };
    }

    pub fn irisColorRgba(self: EyeblossomState) ?[4]f32 {
        return switch (self) {
            .closed => null,
            .open => .{ 1.0, 0.48, 0.0, 1.0 }, // glowing orange iris
        };
    }

    pub fn description(self: EyeblossomState) []const u8 {
        return switch (self) {
            .closed => "closed grey petals, no eye visible, non-emissive",
            .open => "open petals with glowing orange iris, emissive glow, ambient drifting sparkles",
        };
    }
};

/// Sound cues emitted by Eyeblossom bloom and nocturnal state transitions.
pub const SoundEffect = enum(u8) {
    none = 0,
    eyeblossom_open = 1,
    eyeblossom_close = 2,
};

/// Kinematic transition type for bloom animation.
pub const TransitionType = enum(u8) {
    none = 0,
    snap_open = 1,
    snap_shut = 2,
};

/// Transition event emitted when Eyeblossom changes state.
pub const TransitionEvent = struct {
    previous_state: EyeblossomState,
    new_state: EyeblossomState,
    sound: SoundEffect,
    transition: TransitionType,
    emissive: f32,
    eye_visible: bool,
    sparkle_burst_count: u8,
};

/// Particle data for ambient drifting orange eye sparkle particles.
pub const EyeSparkleParticle = struct {
    pos: [3]f32,
    velocity: [3]f32,
    color_rgba: [4]f32 = .{ 1.0, 0.48, 0.0, 0.9 }, // glowing orange
    lifetime_ticks: u32 = 40,
    age_ticks: u32 = 0,
    is_alive: bool = true,

    pub fn tick(self: *EyeSparkleParticle) void {
        if (!self.is_alive) return;
        self.pos[0] += self.velocity[0];
        self.pos[1] += self.velocity[1];
        self.pos[2] += self.velocity[2];
        self.age_ticks += 1;
        if (self.age_ticks >= self.lifetime_ticks) {
            self.is_alive = false;
        }
    }
};

/// Suspicious stew effect kind.
pub const StewEffectType = enum(u8) {
    speed = 0,
    blindness = 1,

    pub fn name(self: StewEffectType) []const u8 {
        return switch (self) {
            .speed => "Speed I",
            .blindness => "Blindness I",
        };
    }

    pub fn isBuff(self: StewEffectType) bool {
        return self == .speed;
    }

    pub fn isDebuff(self: StewEffectType) bool {
        return self == .blindness;
    }
};

/// Suspicious Stew item outcome with duration and status effect.
pub const SuspiciousStew = struct {
    flower_used: EyeblossomState,
    effect: StewEffectType,
    amplifier: u8 = 0, // Level I has amplifier 0
    duration_ticks: u32 = 200, // 10.0s = 200 ticks
    duration_seconds: f32 = 10.0,
    hunger_restoration: f32 = 6.0,
    saturation_restoration: f32 = 7.2,

    pub fn isBuff(self: SuspiciousStew) bool {
        return self.effect.isBuff();
    }

    pub fn isDebuff(self: SuspiciousStew) bool {
        return self.effect.isDebuff();
    }
};

// ============================================================================
// State Evaluation & Transition Logic
// ============================================================================

/// Determines if the given world time tick is within nighttime (13,000..23,000 ticks).
pub fn isNightTime(world_time_ticks: u32) bool {
    const tod = world_time_ticks % DAY_TICKS_TOTAL;
    return tod >= DUSK_OPEN_TICK and tod <= DAWN_CLOSE_TICK;
}

/// Determines if the given world time tick is within daytime (0..12,999 or 23,001..24,000 ticks).
pub fn isDayTime(world_time_ticks: u32) bool {
    return !isNightTime(world_time_ticks);
}

/// Evaluates Eyeblossom state machine:
/// - Open if nighttime (13,000..23,000) OR skylight <= 7.
/// - Closed if daytime (0..12,999 or 23,001..24,000) AND skylight > 7.
pub fn evaluateEyeblossomState(world_time_ticks: u32, skylight: u8) EyeblossomState {
    if (isNightTime(world_time_ticks) or skylight <= DARKNESS_LIGHT_THRESHOLD) {
        return .open;
    } else {
        return .closed;
    }
}

pub fn shouldEyeblossomOpen(world_time_ticks: u32, skylight: u8) bool {
    return evaluateEyeblossomState(world_time_ticks, skylight) == .open;
}

pub fn shouldEyeblossomClose(world_time_ticks: u32, skylight: u8) bool {
    return evaluateEyeblossomState(world_time_ticks, skylight) == .closed;
}

/// Evaluates transition between an old and a new Eyeblossom state.
pub fn evaluateTransition(old_state: EyeblossomState, new_state: EyeblossomState) ?TransitionEvent {
    if (old_state == .closed and new_state == .open) {
        return TransitionEvent{
            .previous_state = .closed,
            .new_state = .open,
            .sound = .eyeblossom_open,
            .transition = .snap_open,
            .emissive = OPEN_EMISSIVE,
            .eye_visible = true,
            .sparkle_burst_count = 12,
        };
    } else if (old_state == .open and new_state == .closed) {
        return TransitionEvent{
            .previous_state = .open,
            .new_state = .closed,
            .sound = .eyeblossom_close,
            .transition = .snap_shut,
            .emissive = CLOSED_EMISSIVE,
            .eye_visible = false,
            .sparkle_burst_count = 0,
        };
    }
    return null;
}

// ============================================================================
// Eyeblossom Entity / Block Representation
// ============================================================================

/// Represents a single Eyeblossom flower block in the world.
pub const Eyeblossom = struct {
    pos: [3]i32 = .{ 0, 0, 0 },
    state: EyeblossomState = .closed,
    skylight: u8 = 15,
    last_world_time: u32 = 6000,

    pub fn init(pos: [3]i32, initial_state: EyeblossomState) Eyeblossom {
        return .{
            .pos = pos,
            .state = initial_state,
            .skylight = if (initial_state == .open) 4 else 15,
            .last_world_time = if (initial_state == .open) 18000 else 6000,
        };
    }

    pub fn initWithConditions(pos: [3]i32, world_time_ticks: u32, skylight: u8) Eyeblossom {
        const st = evaluateEyeblossomState(world_time_ticks, skylight);
        return .{
            .pos = pos,
            .state = st,
            .skylight = skylight,
            .last_world_time = world_time_ticks,
        };
    }

    pub fn emissive(self: *const Eyeblossom) f32 {
        return self.state.emissive();
    }

    pub fn isEyeVisible(self: *const Eyeblossom) bool {
        return self.state.isEyeVisible();
    }

    /// Updates flower state based on world time and local block skylight.
    /// Returns a TransitionEvent if the state changed, or null if unchanged.
    pub fn update(self: *Eyeblossom, world_time_ticks: u32, skylight: u8) ?TransitionEvent {
        self.last_world_time = world_time_ticks;
        self.skylight = skylight;
        const next_state = evaluateEyeblossomState(world_time_ticks, skylight);
        const maybe_event = evaluateTransition(self.state, next_state);
        self.state = next_state;
        return maybe_event;
    }

    /// Emits ambient drifting orange eye sparkle particles when open.
    /// When closed, emits 0 particles.
    pub fn emitAmbientParticles(self: *const Eyeblossom, seed: u64, buffer: []EyeSparkleParticle) usize {
        if (self.state != .open or buffer.len == 0) return 0;

        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        const count = @min(buffer.len, 4);
        var i: usize = 0;
        const base_x = @as(f32, @floatFromInt(self.pos[0])) + 0.5;
        const base_y = @as(f32, @floatFromInt(self.pos[1])) + 0.6;
        const base_z = @as(f32, @floatFromInt(self.pos[2])) + 0.5;

        while (i < count) : (i += 1) {
            const rx = (random.float(f32) - 0.5) * 0.4;
            const ry = random.float(f32) * 0.2;
            const rz = (random.float(f32) - 0.5) * 0.4;

            const vx = (random.float(f32) - 0.5) * 0.02;
            const vy = 0.015 + random.float(f32) * 0.02; // upward drift
            const vz = (random.float(f32) - 0.5) * 0.02;

            buffer[i] = EyeSparkleParticle{
                .pos = .{ base_x + rx, base_y + ry, base_z + rz },
                .velocity = .{ vx, vy, vz },
                .color_rgba = .{ 1.0, 0.48, 0.0, 0.9 },
                .lifetime_ticks = 30 + random.uintLessThan(u32, 20),
                .age_ticks = 0,
                .is_alive = true,
            };
        }
        return count;
    }
};

// ============================================================================
// Bee Entity & Pollination Toxicity Dynamics
// ============================================================================

/// Represents a Bee entity interacting with flowers and the environment.
pub const Bee = struct {
    pos: [3]f32 = .{ 0.0, 0.0, 0.0 },
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    health: f32 = BEE_DEFAULT_MAX_HEALTH,
    max_health: f32 = BEE_DEFAULT_MAX_HEALTH,
    is_alive: bool = true,
    has_nectar: bool = false,
    is_poisoned: bool = false,
    poison_duration_ticks: u32 = 0,
    poison_timer_ticks: u32 = 0,
    poison_damage_rate: f32 = POISON_DAMAGE_RATE,
    is_angered: bool = false,
    anger_duration_ticks: u32 = 0,
    eyes_glowing_red: bool = false,
    flying_erratically: bool = false,

    pub fn init(pos: [3]f32) Bee {
        return .{
            .pos = pos,
            .velocity = .{ 0.0, 0.0, 0.0 },
            .health = BEE_DEFAULT_MAX_HEALTH,
            .max_health = BEE_DEFAULT_MAX_HEALTH,
            .is_alive = true,
            .has_nectar = false,
            .is_poisoned = false,
            .poison_duration_ticks = 0,
            .poison_timer_ticks = 0,
            .poison_damage_rate = POISON_DAMAGE_RATE,
            .is_angered = false,
            .anger_duration_ticks = 0,
            .eyes_glowing_red = false,
            .flying_erratically = false,
        };
    }
};

/// Result of a pollination interaction between a bee and an Eyeblossom flower.
pub const PollinationOutcome = struct {
    success: bool,
    gathered_nectar: bool,
    is_poisoned: bool,
    is_angered: bool,
    eyes_glowing_red: bool,
    flying_erratically: bool,
    poison_duration_ticks: u32,
    poison_damage_rate: f32,
};

/// Pollinates an Eyeblossom flower with a bee:
/// - Closed Eyeblossom: Bee gathers nectar safely without adverse effects
///   (is_poisoned = false, is_angered = false).
/// - Open Eyeblossom: Bee attempting to pollinate receives Poison status effect:
///   1.0 HP magic damage per second (duration 10.0 seconds / 200 ticks).
///   Bee becomes immediately agitated/angered (is_angered = true, eyes glow red, flying erratically).
fn pollinateClosed(bee: *Bee) PollinationOutcome {
    bee.has_nectar = true;
    bee.is_poisoned = false;
    bee.poison_duration_ticks = 0;
    bee.poison_timer_ticks = 0;
    bee.is_angered = false;
    bee.anger_duration_ticks = 0;
    bee.eyes_glowing_red = false;
    bee.flying_erratically = false;
    return .{
        .success = true,
        .gathered_nectar = true,
        .is_poisoned = false,
        .is_angered = false,
        .eyes_glowing_red = false,
        .flying_erratically = false,
        .poison_duration_ticks = 0,
        .poison_damage_rate = 0.0,
    };
}

fn pollinateOpen(bee: *Bee) PollinationOutcome {
    bee.is_poisoned = true;
    bee.poison_duration_ticks = POISON_DURATION_TICKS;
    bee.poison_timer_ticks = 0;
    bee.poison_damage_rate = POISON_DAMAGE_RATE;
    bee.is_angered = true;
    bee.anger_duration_ticks = BEE_ANGER_DURATION_TICKS;
    bee.eyes_glowing_red = true;
    bee.flying_erratically = true;
    return .{
        .success = false,
        .gathered_nectar = false,
        .is_poisoned = true,
        .is_angered = true,
        .eyes_glowing_red = true,
        .flying_erratically = true,
        .poison_duration_ticks = POISON_DURATION_TICKS,
        .poison_damage_rate = POISON_DAMAGE_RATE,
    };
}

/// Pollinates an Eyeblossom flower with a bee:
/// - Closed Eyeblossom: Bee gathers nectar safely without adverse effects
///   (is_poisoned = false, is_angered = false).
/// - Open Eyeblossom: Bee attempting to pollinate receives Poison status effect:
///   1.0 HP magic damage per second (duration 10.0 seconds / 200 ticks); bee becomes
///   immediately agitated/angered (is_angered = true, eyes glow red, flying erratically).
pub fn interactBeeWithEyeblossom(bee: *Bee, flower_state: EyeblossomState) PollinationOutcome {
    return switch (flower_state) {
        .closed => pollinateClosed(bee),
        .open => pollinateOpen(bee),
    };
}

/// Result of ticking poison on a bee.
pub const BeePoisonTickResult = struct {
    damage_dealt: f32,
    ticks_elapsed: u32,
    remaining_poison_ticks: u32,
    still_poisoned: bool,
    bee_died: bool,
};

/// Ticks poison status effect on a bee:
/// Deals 1.0 HP magic damage every 20 ticks (1.0 second) over its 200-tick duration.
pub fn tickBeePoison(bee: *Bee, dt_ticks: u32) BeePoisonTickResult {
    if (!bee.is_alive or !bee.is_poisoned or bee.poison_duration_ticks == 0) {
        return .{
            .damage_dealt = 0.0,
            .ticks_elapsed = dt_ticks,
            .remaining_poison_ticks = 0,
            .still_poisoned = false,
            .bee_died = !bee.is_alive,
        };
    }

    const active_ticks = @min(dt_ticks, bee.poison_duration_ticks);
    bee.poison_duration_ticks -= active_ticks;
    bee.poison_timer_ticks += active_ticks;

    var total_damage: f32 = 0.0;
    while (bee.poison_timer_ticks >= POISON_DAMAGE_INTERVAL_TICKS) {
        bee.poison_timer_ticks -= POISON_DAMAGE_INTERVAL_TICKS;
        total_damage += POISON_DAMAGE_PER_INTERVAL;
        bee.health -= POISON_DAMAGE_PER_INTERVAL;
        if (bee.health <= 0.0) {
            bee.health = 0.0;
            bee.is_alive = false;
            break;
        }
    }

    if (bee.poison_duration_ticks == 0) {
        bee.is_poisoned = false;
        bee.poison_timer_ticks = 0;
    }

    return .{
        .damage_dealt = total_damage,
        .ticks_elapsed = active_ticks,
        .remaining_poison_ticks = bee.poison_duration_ticks,
        .still_poisoned = bee.is_poisoned,
        .bee_died = !bee.is_alive,
    };
}

/// Ticks erratic flight velocity jitter when bee is agitated or poisoned.
pub fn tickErraticFlight(bee: *Bee, random: *const std.Random) void {
    if (!bee.flying_erratically or !bee.is_alive) return;
    const jitter_x = (random.float(f32) - 0.5) * 0.8;
    const jitter_y = (random.float(f32) - 0.5) * 0.6;
    const jitter_z = (random.float(f32) - 0.5) * 0.8;
    bee.velocity[0] = jitter_x;
    bee.velocity[1] = jitter_y;
    bee.velocity[2] = jitter_z;
    bee.pos[0] += bee.velocity[0];
    bee.pos[1] += bee.velocity[1];
    bee.pos[2] += bee.velocity[2];
}

/// Comprehensive update for a bee across poison, anger, and kinematics.
pub fn tickBee(bee: *Bee, dt_ticks: u32, random: ?*const std.Random) BeePoisonTickResult {
    const poison_res = tickBeePoison(bee, dt_ticks);

    if (bee.is_angered and bee.anger_duration_ticks > 0) {
        const anger_dec = @min(dt_ticks, bee.anger_duration_ticks);
        bee.anger_duration_ticks -= anger_dec;
        if (bee.anger_duration_ticks == 0 and !bee.is_poisoned) {
            bee.is_angered = false;
            bee.eyes_glowing_red = false;
            bee.flying_erratically = false;
        }
    }

    if (random) |rng| {
        tickErraticFlight(bee, rng);
    }

    return poison_res;
}

/// Clears poison from a bee (e.g. by drinking honey or milk bucket).
pub fn cureBeePoison(bee: *Bee) void {
    bee.is_poisoned = false;
    bee.poison_duration_ticks = 0;
    bee.poison_timer_ticks = 0;
}

// ============================================================================
// Suspicious Stew Crafting Synergy
// ============================================================================

/// Crafts Suspicious Stew with an Eyeblossom:
/// - Closed Eyeblossom: Yields Suspicious Stew providing Speed I buff for 10.0s (200 ticks).
/// - Open Eyeblossom: Yields Suspicious Stew inflicting Blindness I debuff for 10.0s (200 ticks).
pub fn craftSuspiciousStew(flower: EyeblossomState) SuspiciousStew {
    return switch (flower) {
        .closed => .{
            .flower_used = .closed,
            .effect = .speed,
            .amplifier = 0,
            .duration_ticks = STEW_SPEED_DURATION_TICKS,
            .duration_seconds = STEW_SPEED_DURATION_SECONDS,
            .hunger_restoration = 6.0,
            .saturation_restoration = 7.2,
        },
        .open => .{
            .flower_used = .open,
            .effect = .blindness,
            .amplifier = 0,
            .duration_ticks = STEW_BLINDNESS_DURATION_TICKS,
            .duration_seconds = STEW_BLINDNESS_DURATION_SECONDS,
            .hunger_restoration = 6.0,
            .saturation_restoration = 7.2,
        },
    };
}

/// Verifies whether all 4 ingredients for Suspicious Stew crafting are present:
/// 1 Red Mushroom + 1 Brown Mushroom + 1 Bowl + 1 Flower.
pub fn canCraftSuspiciousStew(
    has_red_mushroom: bool,
    has_brown_mushroom: bool,
    has_bowl: bool,
    has_flower: bool,
) bool {
    return has_red_mushroom and has_brown_mushroom and has_bowl and has_flower;
}

/// Crafts Suspicious Stew from inventory items, validating full recipe requirements.
pub fn craftSuspiciousStewFromIngredients(
    has_red_mushroom: bool,
    has_brown_mushroom: bool,
    has_bowl: bool,
    flower: EyeblossomState,
) ?SuspiciousStew {
    if (!canCraftSuspiciousStew(has_red_mushroom, has_brown_mushroom, has_bowl, true)) {
        return null;
    }
    return craftSuspiciousStew(flower);
}

/// Player status model tracking food, speed, and blindness status effects.
pub const PlayerStatus = struct {
    hunger: f32 = 20.0,
    saturation: f32 = 5.0,
    speed_active: bool = false,
    speed_ticks_remaining: u32 = 0,
    speed_amplifier: u8 = 0,
    blindness_active: bool = false,
    blindness_ticks_remaining: u32 = 0,
    blindness_amplifier: u8 = 0,

    pub fn init() PlayerStatus {
        return .{};
    }

    /// Consumes Suspicious Stew and applies its buff or debuff.
    pub fn consumeStew(self: *PlayerStatus, stew: SuspiciousStew) void {
        self.hunger = @min(20.0, self.hunger + stew.hunger_restoration);
        self.saturation = @min(self.hunger, self.saturation + stew.saturation_restoration);
        switch (stew.effect) {
            .speed => {
                self.speed_active = true;
                self.speed_ticks_remaining = stew.duration_ticks;
                self.speed_amplifier = stew.amplifier;
            },
            .blindness => {
                self.blindness_active = true;
                self.blindness_ticks_remaining = stew.duration_ticks;
                self.blindness_amplifier = stew.amplifier;
            },
        }
    }

    /// Advances active effect timers by dt_ticks.
    pub fn tick(self: *PlayerStatus, dt_ticks: u32) void {
        if (self.speed_active) {
            if (self.speed_ticks_remaining > dt_ticks) {
                self.speed_ticks_remaining -= dt_ticks;
            } else {
                self.speed_ticks_remaining = 0;
                self.speed_active = false;
                self.speed_amplifier = 0;
            }
        }

        if (self.blindness_active) {
            if (self.blindness_ticks_remaining > dt_ticks) {
                self.blindness_ticks_remaining -= dt_ticks;
            } else {
                self.blindness_ticks_remaining = 0;
                self.blindness_active = false;
                self.blindness_amplifier = 0;
            }
        }
    }
};

// ============================================================================
// Multi-Eyeblossom Garden Patch Simulation
// ============================================================================

/// Tracks a local garden cluster of Eyeblossom flowers.
pub const EyeblossomPatch = struct {
    flowers: [16]Eyeblossom = undefined,
    count: usize = 0,

    pub fn init() EyeblossomPatch {
        return .{
            .flowers = undefined,
            .count = 0,
        };
    }

    pub fn addFlower(self: *EyeblossomPatch, flower: Eyeblossom) bool {
        if (self.count >= self.flowers.len) return false;
        self.flowers[self.count] = flower;
        self.count += 1;
        return true;
    }

    /// Ticks the patch against world time and skylight, returning total open flowers
    /// and transition counts.
    pub fn update(
        self: *EyeblossomPatch,
        world_time_ticks: u32,
        skylight: u8,
        events_out: ?[]TransitionEvent,
    ) struct { open_count: usize, closed_count: usize, opened_transitions: usize, closed_transitions: usize } {
        var open_cnt: usize = 0;
        var closed_cnt: usize = 0;
        var opened_trans: usize = 0;
        var closed_trans: usize = 0;
        var event_idx: usize = 0;

        for (self.flowers[0..self.count]) |*fl| {
            const ev_opt = fl.update(world_time_ticks, skylight);
            if (ev_opt) |ev| {
                if (ev.transition == .snap_open) opened_trans += 1;
                if (ev.transition == .snap_shut) closed_trans += 1;
                if (events_out) |out| {
                    if (event_idx < out.len) {
                        out[event_idx] = ev;
                        event_idx += 1;
                    }
                }
            }

            if (fl.state == .open) {
                open_cnt += 1;
            } else {
                closed_cnt += 1;
            }
        }

        return .{
            .open_count = open_cnt,
            .closed_count = closed_cnt,
            .opened_transitions = opened_trans,
            .closed_transitions = closed_trans,
        };
    }
};

// ============================================================================
// Unit Tests (Milestone 533)
// ============================================================================

test "01. evaluateEyeblossomState: midday tick 6000 and skylight 15 evaluates to closed" {
    const state = evaluateEyeblossomState(6000, 15);
    try std.testing.expectEqual(EyeblossomState.closed, state);
    try std.testing.expect(state.isClosed());
    try std.testing.expect(!state.isOpen());
    try std.testing.expect(shouldEyeblossomClose(6000, 15));
    try std.testing.expect(!shouldEyeblossomOpen(6000, 15));
}

test "02. evaluateEyeblossomState: dusk boundary tick 13000 evaluates to open" {
    const state = evaluateEyeblossomState(13000, 15);
    try std.testing.expectEqual(EyeblossomState.open, state);
    try std.testing.expect(state.isOpen());
    try std.testing.expect(!state.isClosed());
    try std.testing.expect(shouldEyeblossomOpen(13000, 15));
}

test "03. evaluateEyeblossomState: midnight tick 18000 evaluates to open" {
    const state = evaluateEyeblossomState(18000, 4);
    try std.testing.expectEqual(EyeblossomState.open, state);
    try std.testing.expect(state.isOpen());
}

test "04. evaluateEyeblossomState: dawn boundary tick 23000 evaluates to open" {
    const state = evaluateEyeblossomState(23000, 4);
    try std.testing.expectEqual(EyeblossomState.open, state);
    try std.testing.expect(state.isOpen());
}

test "05. evaluateEyeblossomState: dawn tick 23001 with skylight 15 evaluates to closed" {
    const state = evaluateEyeblossomState(23001, 15);
    try std.testing.expectEqual(EyeblossomState.closed, state);
    try std.testing.expect(state.isClosed());
}

test "06. evaluateEyeblossomState: midday tick 6000 with cave darkness skylight 7 evaluates to open" {
    const state = evaluateEyeblossomState(6000, 7);
    try std.testing.expectEqual(EyeblossomState.open, state);
    try std.testing.expect(state.isOpen());
}

test "07. evaluateEyeblossomState: midday tick 6000 with complete darkness skylight 0 evaluates to open" {
    const state = evaluateEyeblossomState(6000, 0);
    try std.testing.expectEqual(EyeblossomState.open, state);
    try std.testing.expect(state.isOpen());
}

test "08. evaluateEyeblossomState: midday tick 6000 with skylight 8 evaluates to closed" {
    const state = evaluateEyeblossomState(6000, 8);
    try std.testing.expectEqual(EyeblossomState.closed, state);
    try std.testing.expect(state.isClosed());
}

test "09. evaluateEyeblossomState: tick 0 with daylight skylight 12 evaluates to closed" {
    const state = evaluateEyeblossomState(0, 12);
    try std.testing.expectEqual(EyeblossomState.closed, state);
    try std.testing.expect(state.isClosed());
}

test "10. evaluateEyeblossomState: tick 12999 with daylight skylight 14 evaluates to closed" {
    const state = evaluateEyeblossomState(12999, 14);
    try std.testing.expectEqual(EyeblossomState.closed, state);
    try std.testing.expect(state.isClosed());
}

test "11. evaluateEyeblossomState: multi-day modulo wrap tick 37000 (day 2 night) evaluates to open" {
    // 37000 % 24000 = 13000 (dusk of day 2)
    const state = evaluateEyeblossomState(37000, 10);
    try std.testing.expectEqual(EyeblossomState.open, state);
    try std.testing.expect(state.isOpen());
}

test "12. evaluateEyeblossomState: multi-day modulo wrap tick 30000 (day 2 noon) evaluates to closed" {
    // 30000 % 24000 = 6000 (noon of day 2)
    const state = evaluateEyeblossomState(30000, 15);
    try std.testing.expectEqual(EyeblossomState.closed, state);
    try std.testing.expect(state.isClosed());
}

test "13. Closed Eyeblossom visual properties: emissive 0.0, no eye, grey petals" {
    const state = EyeblossomState.closed;
    try std.testing.expectEqual(@as(f32, 0.0), state.emissive());
    try std.testing.expect(!state.isEyeVisible());
    try std.testing.expectEqual(@as(?[4]f32, null), state.irisColorRgba());
    const petals = state.petalColorRgba();
    try std.testing.expect(petals[0] == 0.55 and petals[1] == 0.55 and petals[2] == 0.55);
}

test "14. Open Eyeblossom visual properties: emissive 0.6, glowing orange iris" {
    const state = EyeblossomState.open;
    try std.testing.expectEqual(@as(f32, 0.6), state.emissive());
    try std.testing.expect(state.isEyeVisible());
    const iris = state.irisColorRgba().?;
    try std.testing.expect(iris[0] == 1.0 and iris[1] == 0.48 and iris[2] == 0.0);
}

test "15. Transition dusk: closed to open snaps open and emits SoundEffect.eyeblossom_open" {
    const ev = evaluateTransition(.closed, .open).?;
    try std.testing.expectEqual(EyeblossomState.closed, ev.previous_state);
    try std.testing.expectEqual(EyeblossomState.open, ev.new_state);
    try std.testing.expectEqual(SoundEffect.eyeblossom_open, ev.sound);
    try std.testing.expectEqual(TransitionType.snap_open, ev.transition);
    try std.testing.expectEqual(@as(f32, 0.6), ev.emissive);
    try std.testing.expect(ev.eye_visible);
    try std.testing.expect(ev.sparkle_burst_count > 0);
}

test "16. Transition dawn: open to closed snaps shut and emits SoundEffect.eyeblossom_close" {
    const ev = evaluateTransition(.open, .closed).?;
    try std.testing.expectEqual(EyeblossomState.open, ev.previous_state);
    try std.testing.expectEqual(EyeblossomState.closed, ev.new_state);
    try std.testing.expectEqual(SoundEffect.eyeblossom_close, ev.sound);
    try std.testing.expectEqual(TransitionType.snap_shut, ev.transition);
    try std.testing.expectEqual(@as(f32, 0.0), ev.emissive);
    try std.testing.expect(!ev.eye_visible);
    try std.testing.expectEqual(@as(u8, 0), ev.sparkle_burst_count);
}

test "17. Transition stability: closed remaining closed yields null event" {
    try std.testing.expectEqual(@as(?TransitionEvent, null), evaluateTransition(.closed, .closed));
}

test "18. Transition stability: open remaining open yields null event" {
    try std.testing.expectEqual(@as(?TransitionEvent, null), evaluateTransition(.open, .open));
}

test "19. Eyeblossom update: daylight entry into dark cave triggers SoundEffect.eyeblossom_open" {
    var flower = Eyeblossom.init(.{ 10, 64, 20 }, .closed);
    try std.testing.expectEqual(EyeblossomState.closed, flower.state);

    // Enter dark cave (skylight 4) during daytime tick 6000
    const ev = flower.update(6000, 4);
    try std.testing.expect(ev != null);
    try std.testing.expectEqual(SoundEffect.eyeblossom_open, ev.?.sound);
    try std.testing.expectEqual(EyeblossomState.open, flower.state);
    try std.testing.expectEqual(@as(f32, 0.6), flower.emissive());
}

test "20. Eyeblossom update: exiting dark cave into bright daylight triggers SoundEffect.eyeblossom_close" {
    var flower = Eyeblossom.init(.{ 10, 64, 20 }, .open);
    try std.testing.expectEqual(EyeblossomState.open, flower.state);

    // Exit into bright daylight (skylight 15) during daytime tick 6000
    const ev = flower.update(6000, 15);
    try std.testing.expect(ev != null);
    try std.testing.expectEqual(SoundEffect.eyeblossom_close, ev.?.sound);
    try std.testing.expectEqual(EyeblossomState.closed, flower.state);
    try std.testing.expectEqual(@as(f32, 0.0), flower.emissive());
}

test "21. Eyeblossom ambient particles: open eyeblossom emits orange eye sparkle particles" {
    const flower = Eyeblossom.init(.{ 0, 64, 0 }, .open);
    var particles: [8]EyeSparkleParticle = undefined;
    const count = flower.emitAmbientParticles(42, &particles);
    try std.testing.expect(count > 0);
    try std.testing.expect(particles[0].color_rgba[0] == 1.0 and particles[0].color_rgba[1] == 0.48);
    try std.testing.expect(particles[0].velocity[1] > 0.0); // upward drift
}

test "22. Eyeblossom ambient particles: closed eyeblossom emits 0 particles" {
    const flower = Eyeblossom.init(.{ 0, 64, 0 }, .closed);
    var particles: [8]EyeSparkleParticle = undefined;
    const count = flower.emitAmbientParticles(42, &particles);
    try std.testing.expectEqual(@as(usize, 0), count);
}

test "23. EyeSparkleParticle: particle ticks along velocity and expires at lifetime" {
    var p = EyeSparkleParticle{
        .pos = .{ 0.0, 1.0, 0.0 },
        .velocity = .{ 0.0, 0.1, 0.0 },
        .lifetime_ticks = 3,
        .age_ticks = 0,
        .is_alive = true,
    };
    p.tick();
    try std.testing.expectEqual(@as(f32, 1.1), p.pos[1]);
    try std.testing.expectEqual(@as(u32, 1), p.age_ticks);
    try std.testing.expect(p.is_alive);

    p.tick();
    p.tick();
    try std.testing.expectEqual(@as(u32, 3), p.age_ticks);
    try std.testing.expect(!p.is_alive);
}

test "24. Bee pollination on Closed Eyeblossom: safe gathering, nectar collected, not poisoned, not angered" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    const outcome = interactBeeWithEyeblossom(&bee, .closed);

    try std.testing.expect(outcome.success);
    try std.testing.expect(outcome.gathered_nectar);
    try std.testing.expect(!outcome.is_poisoned);
    try std.testing.expect(!outcome.is_angered);
    try std.testing.expect(bee.has_nectar);
    try std.testing.expect(!bee.is_poisoned);
    try std.testing.expect(!bee.is_angered);
}

test "25. Bee pollination on Closed Eyeblossom: eyes do not glow red, flight is not erratic" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    const outcome = interactBeeWithEyeblossom(&bee, .closed);

    try std.testing.expect(!outcome.eyes_glowing_red);
    try std.testing.expect(!outcome.flying_erratically);
    try std.testing.expect(!bee.eyes_glowing_red);
    try std.testing.expect(!bee.flying_erratically);
}

test "26. Bee pollination on Open Eyeblossom: poison applied, nectar NOT collected" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    const outcome = interactBeeWithEyeblossom(&bee, .open);

    try std.testing.expect(!outcome.success);
    try std.testing.expect(!outcome.gathered_nectar);
    try std.testing.expect(outcome.is_poisoned);
    try std.testing.expect(!bee.has_nectar);
    try std.testing.expect(bee.is_poisoned);
}

test "27. Bee pollination on Open Eyeblossom: poison duration is exactly 200 ticks (10.0 seconds)" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    const outcome = interactBeeWithEyeblossom(&bee, .open);

    try std.testing.expectEqual(@as(u32, 200), outcome.poison_duration_ticks);
    try std.testing.expectEqual(@as(u32, 200), bee.poison_duration_ticks);
}

test "28. Bee pollination on Open Eyeblossom: bee becomes immediately angered" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    const outcome = interactBeeWithEyeblossom(&bee, .open);

    try std.testing.expect(outcome.is_angered);
    try std.testing.expect(bee.is_angered);
    try std.testing.expect(bee.anger_duration_ticks > 0);
}

test "29. Bee pollination on Open Eyeblossom: bee eyes glow red" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    const outcome = interactBeeWithEyeblossom(&bee, .open);

    try std.testing.expect(outcome.eyes_glowing_red);
    try std.testing.expect(bee.eyes_glowing_red);
}

test "30. Bee pollination on Open Eyeblossom: bee flies erratically" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    const outcome = interactBeeWithEyeblossom(&bee, .open);

    try std.testing.expect(outcome.flying_erratically);
    try std.testing.expect(bee.flying_erratically);
}

test "31. Bee poison damage rate: deals 1.0 HP magic damage per second" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    _ = interactBeeWithEyeblossom(&bee, .open);

    // 20 ticks = 1 second
    const res = tickBeePoison(&bee, 20);
    try std.testing.expectEqual(@as(f32, 1.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 9.0), bee.health);
}

test "32. Bee poison damage over 10 seconds: deals 10.0 HP total over 200 ticks" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    _ = interactBeeWithEyeblossom(&bee, .open);

    var total_damage: f32 = 0.0;
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const res = tickBeePoison(&bee, 20);
        total_damage += res.damage_dealt;
    }

    try std.testing.expectEqual(@as(f32, 10.0), total_damage);
    try std.testing.expectEqual(@as(f32, 0.0), bee.health);
    try std.testing.expect(!bee.is_alive);
}

test "33. Bee poison tick interval: no damage dealt before 20 ticks elapse" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    _ = interactBeeWithEyeblossom(&bee, .open);

    const res = tickBeePoison(&bee, 19);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 10.0), bee.health);
}

test "34. Bee poison tick interval: exactly 1.0 HP damage dealt at tick 20" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    _ = interactBeeWithEyeblossom(&bee, .open);

    _ = tickBeePoison(&bee, 19);
    const res = tickBeePoison(&bee, 1);
    try std.testing.expectEqual(@as(f32, 1.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 9.0), bee.health);
}

test "35. Bee poison tick interval: exactly 2.0 HP damage dealt at 40 ticks" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    _ = interactBeeWithEyeblossom(&bee, .open);

    const res = tickBeePoison(&bee, 40);
    try std.testing.expectEqual(@as(f32, 2.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 8.0), bee.health);
}

test "36. Bee poison expiration: at tick 200, poison duration reaches 0 and is_poisoned is false" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    bee.health = 20.0; // Higher health to survive full poison
    _ = interactBeeWithEyeblossom(&bee, .open);

    const res = tickBeePoison(&bee, 200);
    try std.testing.expectEqual(@as(u32, 0), res.remaining_poison_ticks);
    try std.testing.expect(!res.still_poisoned);
    try std.testing.expect(!bee.is_poisoned);
}

test "37. Bee lethal poison: bee with 10 HP dies after full 200 ticks" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    _ = interactBeeWithEyeblossom(&bee, .open);

    const res = tickBeePoison(&bee, 200);
    try std.testing.expect(res.bee_died);
    try std.testing.expect(!bee.is_alive);
    try std.testing.expectEqual(@as(f32, 0.0), bee.health);
}

test "38. Bee erratic flight simulation: updates velocity with erratic offsets when agitated" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    _ = interactBeeWithEyeblossom(&bee, .open);

    var prng = std.Random.DefaultPrng.init(1234);
    const rng = prng.random();

    tickErraticFlight(&bee, &rng);
    try std.testing.expect(bee.velocity[0] != 0.0 or bee.velocity[1] != 0.0 or bee.velocity[2] != 0.0);
}

test "39. Bee cure poison: milk or cure clears poison duration and flag" {
    var bee = Bee.init(.{ 0.0, 1.0, 0.0 });
    _ = interactBeeWithEyeblossom(&bee, .open);
    try std.testing.expect(bee.is_poisoned);

    cureBeePoison(&bee);
    try std.testing.expect(!bee.is_poisoned);
    try std.testing.expectEqual(@as(u32, 0), bee.poison_duration_ticks);
}

test "40. Suspicious Stew craft with Closed Eyeblossom: yields Speed I effect" {
    const stew = craftSuspiciousStew(.closed);
    try std.testing.expectEqual(StewEffectType.speed, stew.effect);
    try std.testing.expect(stew.isBuff());
    try std.testing.expect(!stew.isDebuff());
}

test "41. Suspicious Stew craft with Closed Eyeblossom: duration is exactly 200 ticks (10.0 seconds)" {
    const stew = craftSuspiciousStew(.closed);
    try std.testing.expectEqual(@as(u32, 200), stew.duration_ticks);
    try std.testing.expectEqual(@as(f32, 10.0), stew.duration_seconds);
}

test "42. Suspicious Stew craft with Closed Eyeblossom: amplifier is 0 (Tier I)" {
    const stew = craftSuspiciousStew(.closed);
    try std.testing.expectEqual(@as(u8, 0), stew.amplifier);
    try std.testing.expectEqualStrings("Speed I", stew.effect.name());
}

test "43. Suspicious Stew craft with Open Eyeblossom: yields Blindness I effect" {
    const stew = craftSuspiciousStew(.open);
    try std.testing.expectEqual(StewEffectType.blindness, stew.effect);
    try std.testing.expect(stew.isDebuff());
    try std.testing.expect(!stew.isBuff());
}

test "44. Suspicious Stew craft with Open Eyeblossom: duration is exactly 200 ticks (10.0 seconds)" {
    const stew = craftSuspiciousStew(.open);
    try std.testing.expectEqual(@as(u32, 200), stew.duration_ticks);
    try std.testing.expectEqual(@as(f32, 10.0), stew.duration_seconds);
}

test "45. Suspicious Stew craft with Open Eyeblossom: amplifier is 0 (Tier I)" {
    const stew = craftSuspiciousStew(.open);
    try std.testing.expectEqual(@as(u8, 0), stew.amplifier);
    try std.testing.expectEqualStrings("Blindness I", stew.effect.name());
}

test "46. Suspicious Stew recipe validation: missing ingredients fails crafting" {
    try std.testing.expect(!canCraftSuspiciousStew(false, true, true, true)); // missing red mushroom
    try std.testing.expect(!canCraftSuspiciousStew(true, false, true, true)); // missing brown mushroom
    try std.testing.expect(!canCraftSuspiciousStew(true, true, false, true)); // missing bowl
    try std.testing.expect(!canCraftSuspiciousStew(true, true, true, false)); // missing flower

    const stew_opt = craftSuspiciousStewFromIngredients(false, true, true, .closed);
    try std.testing.expectEqual(@as(?SuspiciousStew, null), stew_opt);
}

test "47. Suspicious Stew recipe validation: all 4 ingredients crafts successfully" {
    try std.testing.expect(canCraftSuspiciousStew(true, true, true, true));

    const stew_closed = craftSuspiciousStewFromIngredients(true, true, true, .closed);
    try std.testing.expect(stew_closed != null);
    try std.testing.expectEqual(StewEffectType.speed, stew_closed.?.effect);

    const stew_open = craftSuspiciousStewFromIngredients(true, true, true, .open);
    try std.testing.expect(stew_open != null);
    try std.testing.expectEqual(StewEffectType.blindness, stew_open.?.effect);
}

test "48. Player consume Closed Eyeblossom stew: gains Speed I buff for 200 ticks" {
    var player = PlayerStatus.init();
    player.hunger = 10.0;
    const stew = craftSuspiciousStew(.closed);

    player.consumeStew(stew);
    try std.testing.expect(player.speed_active);
    try std.testing.expectEqual(@as(u32, 200), player.speed_ticks_remaining);
    try std.testing.expectEqual(@as(u8, 0), player.speed_amplifier);
    try std.testing.expect(!player.blindness_active);
    try std.testing.expectEqual(@as(f32, 16.0), player.hunger);
}

test "49. Player consume Open Eyeblossom stew: suffers Blindness I debuff for 200 ticks" {
    var player = PlayerStatus.init();
    const stew = craftSuspiciousStew(.open);

    player.consumeStew(stew);
    try std.testing.expect(player.blindness_active);
    try std.testing.expectEqual(@as(u32, 200), player.blindness_ticks_remaining);
    try std.testing.expectEqual(@as(u8, 0), player.blindness_amplifier);
    try std.testing.expect(!player.speed_active);
}

test "50. Player status tick: buff and debuff tick down and expire after duration" {
    var player = PlayerStatus.init();
    const stew_spd = craftSuspiciousStew(.closed);
    player.consumeStew(stew_spd);
    try std.testing.expect(player.speed_active);

    player.tick(150);
    try std.testing.expect(player.speed_active);
    try std.testing.expectEqual(@as(u32, 50), player.speed_ticks_remaining);

    player.tick(50);
    try std.testing.expect(!player.speed_active);
    try std.testing.expectEqual(@as(u32, 0), player.speed_ticks_remaining);
}

test "51. EyeblossomGarden patch simulation: synchronized dusk opening across multiple flowers" {
    var patch = EyeblossomPatch.init();
    _ = patch.addFlower(Eyeblossom.init(.{ 0, 64, 0 }, .closed));
    _ = patch.addFlower(Eyeblossom.init(.{ 1, 64, 0 }, .closed));
    _ = patch.addFlower(Eyeblossom.init(.{ 2, 64, 0 }, .closed));
    try std.testing.expectEqual(@as(usize, 3), patch.count);

    // Dusk transition (tick 13000, skylight 10)
    var events: [8]TransitionEvent = undefined;
    const res = patch.update(13000, 10, &events);

    try std.testing.expectEqual(@as(usize, 3), res.open_count);
    try std.testing.expectEqual(@as(usize, 0), res.closed_count);
    try std.testing.expectEqual(@as(usize, 3), res.opened_transitions);
    try std.testing.expectEqual(@as(usize, 0), res.closed_transitions);
    try std.testing.expectEqual(SoundEffect.eyeblossom_open, events[0].sound);
}

test "52. EyeblossomGarden patch simulation: synchronized dawn closing across multiple flowers" {
    var patch = EyeblossomPatch.init();
    _ = patch.addFlower(Eyeblossom.init(.{ 0, 64, 0 }, .open));
    _ = patch.addFlower(Eyeblossom.init(.{ 1, 64, 0 }, .open));
    try std.testing.expectEqual(@as(usize, 2), patch.count);

    // Dawn transition (tick 23001, skylight 15)
    var events: [8]TransitionEvent = undefined;
    const res = patch.update(23001, 15, &events);

    try std.testing.expectEqual(@as(usize, 0), res.open_count);
    try std.testing.expectEqual(@as(usize, 2), res.closed_count);
    try std.testing.expectEqual(@as(usize, 2), res.closed_transitions);
    try std.testing.expectEqual(SoundEffect.eyeblossom_close, events[0].sound);
}
