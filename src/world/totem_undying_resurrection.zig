//! ============================================================================
//! Milestone 480: Totem of Undying Resurrection Mechanics & Visual Animation
//! ============================================================================
//!
//! Overview:
//!   The Totem of Undying is a legendary protective relic that cheats death.
//!   When a player sustains lethal fatal damage (HP <= 0.0) while holding a
//!   Totem of Undying in either the offhand or the main hand, the totem activates,
//!   cancelling the death event, restoring health to 1.0 HP (half a heart),
//!   cleansing all negative status effects, and granting a resurrection buff suite:
//!     - Regeneration II (45.0s / 900 ticks): 0.8 HP/s (+36 HP total)
//!     - Absorption II (5.0s / 100 ticks): +8.0 absorption HP (4 golden hearts)
//!     - Fire Resistance I (40.0s / 800 ticks): complete fire/lava immunity
//!   The activation is accompanied by screen-filling floating golden wings and
//!   emerald eyes totem visual animation, golden/emerald sparkle ring particle
//!   bursts, and the majestic totem activation chime audio event.
//!
//! Hand Priority & Exemption:
//!   - Slot check priority: Offhand is checked FIRST, then Main hand.
//!   - Exactly 1 totem item is consumed on activation.
//!   - Void death exemption: Falling into the void (Y < -64.0) or /kill commands
//!     bypass the totem completely; the player dies regardless.
//! ============================================================================

const std = @import("std");

// ============================================================================
// Core Constants
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;

/// Item IDs for Totem of Undying
pub const TOTEM_OF_UNDYING_ID: u16 = 449;
pub const TOTEM_OF_UNDYING_LEGACY_ID: u16 = 330;

/// Void damage threshold: Y coordinate at or below which void damage cannot be cheated
pub const VOID_DEATH_Y_THRESHOLD: f32 = -64.0;

/// Base health restored immediately upon totem resurrection (half heart = 1.0 HP)
pub const RESURRECTION_HEALTH_HP: f32 = 1.0;

/// Regeneration II parameters:
/// 45.0 seconds (900 ticks), 0.8 HP/s, +36.0 HP total recovery
pub const REGEN_II_DURATION_TICKS: u32 = 900;
pub const REGEN_II_DURATION_SECONDS: f32 = 45.0;
pub const REGEN_II_AMPLIFIER: u8 = 1; // Level II
pub const REGEN_II_RATE_HP_PER_SEC: f32 = 0.8;
pub const REGEN_II_TOTAL_HP: f32 = 36.0;
pub const REGEN_II_HP_PER_TICK: f32 = REGEN_II_RATE_HP_PER_SEC / @as(f32, @floatFromInt(TICKS_PER_SECOND));

/// Absorption II parameters:
/// 5.0 seconds (100 ticks), +8.0 absorption HP (4 golden hearts)
pub const ABSORPTION_II_DURATION_TICKS: u32 = 100;
pub const ABSORPTION_II_DURATION_SECONDS: f32 = 5.0;
pub const ABSORPTION_II_AMPLIFIER: u8 = 1; // Level II
pub const ABSORPTION_II_HEARTS: f32 = 4.0;
pub const ABSORPTION_II_HP: f32 = 8.0;

/// Fire Resistance I parameters:
/// 40.0 seconds (800 ticks), complete immunity to fire and lava damage
pub const FIRE_RESISTANCE_I_DURATION_TICKS: u32 = 800;
pub const FIRE_RESISTANCE_I_DURATION_SECONDS: f32 = 40.0;
pub const FIRE_RESISTANCE_I_AMPLIFIER: u8 = 0; // Level I

/// Visual animation duration: 30 ticks (1.5 seconds)
pub const ANIMATION_DURATION_TICKS: u32 = 30;
pub const ANIMATION_DURATION_SECONDS: f32 = 1.5;

/// Particle count in the sparkle burst ring
pub const SPARKLE_RING_PARTICLE_COUNT: usize = 32;

/// Particle RGBA Colors: Golden yellow and Emerald green
pub const GOLDEN_SPARKLE_RGBA: [4]f32 = .{ 1.0, 0.84, 0.0, 1.0 };
pub const EMERALD_SPARKLE_RGBA: [4]f32 = .{ 0.1, 0.9, 0.3, 1.0 };

// ============================================================================
// Enums & Classifications
// ============================================================================

/// Item types recognized by the resurrection system.
pub const ItemType = enum(u16) {
    none = 0,
    totem_of_undying = TOTEM_OF_UNDYING_ID,
    totem_legacy = TOTEM_OF_UNDYING_LEGACY_ID,
    diamond_sword = 276,
    iron_sword = 267,
    shield = 442,
    golden_apple = 322,
    enchanted_golden_apple = 466,
    bow = 261,
    crossbow = 471,
    mace = 472,
    potion = 373,

    pub fn isTotem(self: ItemType) bool {
        return self == .totem_of_undying or self == .totem_legacy or @intFromEnum(self) == TOTEM_OF_UNDYING_ID or @intFromEnum(self) == TOTEM_OF_UNDYING_LEGACY_ID;
    }
};

/// Hand slot holding an item.
pub const HandSlot = enum {
    offhand,
    main_hand,
    none,
};

/// Damage source type classifications.
pub const DamageType = enum {
    generic,
    combat,
    mob_attack,
    player_attack,
    fall,
    fire,
    lava,
    drowning,
    explosion,
    void,
    command_kill,
    magic,
    wither,
    starvation,
    suffocation,
    freeze,
    sonic_boom,
    lightning,

    pub fn isVoidOrKill(self: DamageType) bool {
        return self == .void or self == .command_kill;
    }

    pub fn isFireOrLava(self: DamageType) bool {
        return self == .fire or self == .lava;
    }
};

/// Status effect types recognized by the status cleansing and buff suites.
pub const StatusEffectType = enum {
    // Negative status effects cleansed upon resurrection:
    poison,
    fatal_poison,
    wither,
    slowness,
    weakness,
    mining_fatigue,
    levitation,
    darkness,
    bad_omen,

    // Additional negative effects:
    hunger,
    nausea,
    blindness,
    instant_damage,
    unluck,

    // Positive / neutral buff effects:
    regeneration,
    absorption,
    fire_resistance,
    speed,
    haste,
    strength,
    jump_boost,
    resistance,
    water_breathing,
    invisibility,
    night_vision,
    health_boost,
    saturation,
    glowing,
    slow_falling,
    conduit_power,
    dolphins_grace,
    hero_of_the_village,

    pub fn isNegative(self: StatusEffectType) bool {
        return switch (self) {
            .poison,
            .fatal_poison,
            .wither,
            .slowness,
            .weakness,
            .mining_fatigue,
            .levitation,
            .darkness,
            .bad_omen,
            .hunger,
            .nausea,
            .blindness,
            .instant_damage,
            .unluck,
            => true,
            else => false,
        };
    }
};

/// Sound cues emitted by the resurrection mechanics.
pub const SoundEffect = enum(u8) {
    totem_use = 0,
    player_hurt = 1,
    player_death = 2,
    none = 255,
};

/// Particle types emitted by totem burst.
pub const TotemParticleKind = enum {
    golden_sparkle,
    emerald_sparkle,
};

// ============================================================================
// Data Structures
// ============================================================================

/// Represents an item stack with an ItemType and count.
pub const ItemStack = struct {
    item: ItemType = .none,
    count: u8 = 0,

    pub fn isEmpty(self: ItemStack) bool {
        return self.item == .none or self.count == 0;
    }

    pub fn isTotem(self: ItemStack) bool {
        return !self.isEmpty() and self.item.isTotem();
    }

    pub fn decrement(self: *ItemStack, amount: u8) void {
        if (self.count <= amount) {
            self.count = 0;
            self.item = .none;
        } else {
            self.count -= amount;
        }
    }
};

/// Represents an active status effect on a player.
pub const ActiveEffect = struct {
    effect_type: StatusEffectType,
    amplifier: u8 = 0,
    ticks_remaining: u32 = 0,

    pub fn isExpired(self: ActiveEffect) bool {
        return self.ticks_remaining == 0;
    }
};

/// Fixed-capacity container for active status effects.
pub const StatusEffectContainer = struct {
    pub const MAX_EFFECTS: usize = 32;
    effects: [MAX_EFFECTS]?ActiveEffect = [_]?ActiveEffect{null} ** MAX_EFFECTS,

    pub fn addEffect(self: *StatusEffectContainer, effect: ActiveEffect) void {
        // If effect of same type exists, refresh or upgrade duration/amplifier
        for (&self.effects) |*slot| {
            if (slot.*) |*existing| {
                if (existing.effect_type == effect.effect_type) {
                    if (effect.amplifier >= existing.amplifier) {
                        existing.amplifier = effect.amplifier;
                        existing.ticks_remaining = @max(existing.ticks_remaining, effect.ticks_remaining);
                    } else if (existing.ticks_remaining < effect.ticks_remaining) {
                        existing.ticks_remaining = effect.ticks_remaining;
                    }
                    return;
                }
            }
        }
        // Insert in first free slot
        for (&self.effects) |*slot| {
            if (slot.* == null) {
                slot.* = effect;
                return;
            }
        }
    }

    pub fn removeEffect(self: *StatusEffectContainer, effect_type: StatusEffectType) bool {
        for (&self.effects) |*slot| {
            if (slot.*) |existing| {
                if (existing.effect_type == effect_type) {
                    slot.* = null;
                    return true;
                }
            }
        }
        return false;
    }

    pub fn hasEffect(self: StatusEffectContainer, effect_type: StatusEffectType) bool {
        for (self.effects) |slot| {
            if (slot) |existing| {
                if (existing.effect_type == effect_type) return true;
            }
        }
        return false;
    }

    pub fn getEffect(self: StatusEffectContainer, effect_type: StatusEffectType) ?ActiveEffect {
        for (self.effects) |slot| {
            if (slot) |existing| {
                if (existing.effect_type == effect_type) return existing;
            }
        }
        return null;
    }

    /// Cleanses all negative status effects (Poison, Fatal Poison, Wither, Slowness,
    /// Weakness, Mining Fatigue, Levitation, Darkness, Bad Omen, etc.)
    /// Returns the number of negative effects removed.
    pub fn cleanseNegativeEffects(self: *StatusEffectContainer) u32 {
        var count: u32 = 0;
        for (&self.effects) |*slot| {
            if (slot.*) |existing| {
                if (existing.effect_type.isNegative()) {
                    slot.* = null;
                    count += 1;
                }
            }
        }
        return count;
    }

    /// Advances all effect timers by the specified tick count and clears expired ones.
    pub fn tick(self: *StatusEffectContainer, ticks: u32) void {
        for (&self.effects) |*slot| {
            if (slot.*) |*existing| {
                if (existing.ticks_remaining <= ticks) {
                    slot.* = null;
                } else {
                    existing.ticks_remaining -= ticks;
                }
            }
        }
    }
};

/// Floating totem animation state:
/// Controls the screen-filling floating golden wings and emerald eyes totem asset overlay.
pub const FloatingTotemAnimation = struct {
    floating_totem_active: bool = false,
    ticks_remaining: u32 = 0,
    total_ticks: u32 = ANIMATION_DURATION_TICKS,

    // Overlay visual properties
    golden_wings_color: [4]f32 = GOLDEN_SPARKLE_RGBA,
    emerald_eyes_color: [4]f32 = EMERALD_SPARKLE_RGBA,

    pub fn start(self: *FloatingTotemAnimation) void {
        self.floating_totem_active = true;
        self.ticks_remaining = ANIMATION_DURATION_TICKS;
        self.total_ticks = ANIMATION_DURATION_TICKS;
    }

    pub fn tick(self: *FloatingTotemAnimation) void {
        if (self.ticks_remaining > 0) {
            self.ticks_remaining -= 1;
            if (self.ticks_remaining == 0) {
                self.floating_totem_active = false;
            }
        } else {
            self.floating_totem_active = false;
        }
    }

    pub fn progress(self: FloatingTotemAnimation) f32 {
        if (!self.floating_totem_active or self.total_ticks == 0) return 1.0;
        const elapsed = self.total_ticks - self.ticks_remaining;
        return @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(self.total_ticks));
    }

    /// Scale transform curve: starts at 0.5x, swells to 1.25x peak, settles around 1.0x
    pub fn scale(self: FloatingTotemAnimation) f32 {
        if (!self.floating_totem_active) return 0.0;
        const p = self.progress();
        if (p < 0.3) {
            // Expansion phase
            return 0.5 + (0.75 * (p / 0.3));
        } else {
            // Settling phase
            const t = (p - 0.3) / 0.7;
            return 1.25 - (0.25 * t);
        }
    }

    /// Alpha opacity curve: stays opaque (1.0) then fades out in the final 10 ticks
    pub fn alpha(self: FloatingTotemAnimation) f32 {
        if (!self.floating_totem_active) return 0.0;
        if (self.ticks_remaining <= 10) {
            return @as(f32, @floatFromInt(self.ticks_remaining)) / 10.0;
        }
        return 1.0;
    }

    /// Wing spread factor: smoothly opens from 0.0 to 1.0
    pub fn wingSpread(self: FloatingTotemAnimation) f32 {
        if (!self.floating_totem_active) return 0.0;
        const p = self.progress();
        return @min(1.0, p * 2.0);
    }
};

/// Sparkle particle emitted during totem resurrection burst.
pub const TotemParticle = struct {
    particle_type: TotemParticleKind,
    position: [3]f32,
    velocity: [3]f32,
    color: [4]f32, // RGBA
    lifetime_ticks: u32,
    max_lifetime: u32,
    size: f32 = 0.25,

    pub fn isDead(self: TotemParticle) bool {
        return self.lifetime_ticks == 0;
    }

    pub fn tick(self: *TotemParticle) void {
        if (self.lifetime_ticks > 0) {
            self.lifetime_ticks -= 1;
            self.position[0] += self.velocity[0];
            self.position[1] += self.velocity[1];
            self.position[2] += self.velocity[2];
            // Drag deceleration and gentle upward float
            self.velocity[0] *= 0.92;
            self.velocity[1] = (self.velocity[1] * 0.92) + 0.005;
            self.velocity[2] *= 0.92;
        }
    }
};

/// Comprehensive player state for tracking health, items, status effects, and buffs.
pub const PlayerState = struct {
    health: f32 = 20.0,
    max_health: f32 = 20.0,
    absorption_health: f32 = 0.0,
    position: [3]f32 = .{ 0.0, 64.0, 0.0 },

    // Equipment slots
    main_hand: ItemStack = .{},
    offhand: ItemStack = .{},
    inventory: [36]ItemStack = [_]ItemStack{.{}} ** 36,

    // Progression & lifecycle state
    experience_points: u32 = 100,
    inventory_dropped: bool = false,
    experience_lost: bool = false,
    is_alive: bool = true,

    // Status effects and buff suite timers
    effects: StatusEffectContainer = .{},
    regeneration_ticks: u32 = 0,
    absorption_ticks: u32 = 0,
    fire_resistance_ticks: u32 = 0,

    // Visual animation
    floating_totem_active: bool = false,
    totem_animation: FloatingTotemAnimation = .{},

    pub fn init() PlayerState {
        return .{};
    }

    pub fn isHoldingTotem(self: PlayerState) bool {
        return self.offhand.isTotem() or self.main_hand.isTotem();
    }

    pub fn hasFireResistance(self: PlayerState) bool {
        return self.fire_resistance_ticks > 0 or self.effects.hasEffect(.fire_resistance);
    }
};

/// Result of evaluating damage and potential totem resurrection.
pub const ResurrectionResult = struct {
    triggered: bool = false,
    death_cancelled: bool = false,
    player_died: bool = false,
    is_consumed: bool = false,
    consumed_hand: HandSlot = .none,
    restored_hp: f32 = 0.0,
    absorption_hp_added: f32 = 0.0,
    cleansed_effects_count: u32 = 0,
    regeneration_ticks: u32 = 0,
    absorption_ticks: u32 = 0,
    fire_resistance_ticks: u32 = 0,
    floating_totem_active: bool = false,
    sound_effect: ?SoundEffect = null,
    particles_emitted: usize = 0,
    inventory_dropped: bool = false,
    experience_lost: bool = false,
    void_bypassed: bool = false,
};

// ============================================================================
// Resurrection Core Mechanics
// ============================================================================

/// Priority check for hands holding a Totem of Undying:
/// Offhand is checked FIRST, then Main hand.
pub fn checkHandsForTotem(offhand: *ItemStack, main_hand: *ItemStack) ?HandSlot {
    if (offhand.isTotem()) {
        return .offhand;
    }
    if (main_hand.isTotem()) {
        return .main_hand;
    }
    return null;
}

/// Generates a ring of sparkle particles expanding outward from the resurrection origin.
/// Particles alternate between golden sparkle bursts and emerald sparkle bursts.
pub fn generateSparkleRing(center: [3]f32, buffer: []TotemParticle) usize {
    const count = @min(buffer.len, SPARKLE_RING_PARTICLE_COUNT);
    const count_f = @as(f32, @floatFromInt(count));

    for (0..count) |i| {
        const i_f = @as(f32, @floatFromInt(i));
        const angle = i_f * (2.0 * std.math.pi / count_f);
        const cos_a = @cos(angle);
        const sin_a = @sin(angle);

        const is_emerald = (i % 2 == 1);
        const kind: TotemParticleKind = if (is_emerald) .emerald_sparkle else .golden_sparkle;
        const color = if (is_emerald) EMERALD_SPARKLE_RGBA else GOLDEN_SPARKLE_RGBA;

        const radial_speed: f32 = 0.18 + (@as(f32, @floatFromInt(i % 3)) * 0.04);
        const up_speed: f32 = 0.08 + (@as(f32, @floatFromInt(i % 4)) * 0.02);

        buffer[i] = .{
            .particle_type = kind,
            .position = .{
                center[0] + (cos_a * 0.4),
                center[1] + 1.0,
                center[2] + (sin_a * 0.4),
            },
            .velocity = .{
                cos_a * radial_speed,
                up_speed,
                sin_a * radial_speed,
            },
            .color = color,
            .lifetime_ticks = 30 + @as(u32, @intCast(i % 5)),
            .max_lifetime = 35,
            .size = 0.3,
        };
    }
    return count;
}

/// Evaluates incoming damage against a player.
/// Handles absorption damage deduction, lethal damage detection, void damage exemption,
/// totem activation from offhand or main hand, death cancellation, health restoration to 1.0 HP,
/// negative effect cleansing, buff suite application, and visual/audio triggers.
pub fn evaluateDamage(player: *PlayerState, raw_damage: f32, damage_type: DamageType) ResurrectionResult {
    var damage = raw_damage;

    // 1. Fire Resistance immunity check
    if (player.hasFireResistance() and damage_type.isFireOrLava()) {
        damage = 0.0;
    }

    if (damage <= 0.0) {
        return .{
            .triggered = false,
            .death_cancelled = false,
            .player_died = false,
            .is_consumed = false,
        };
    }

    // 2. Absorption heart damage deduction
    if (player.absorption_health > 0.0) {
        if (damage <= player.absorption_health) {
            player.absorption_health -= damage;
            damage = 0.0;
            return .{
                .triggered = false,
                .death_cancelled = false,
                .player_died = false,
                .is_consumed = false,
            };
        } else {
            damage -= player.absorption_health;
            player.absorption_health = 0.0;
        }
    }

    // 3. Deduct health
    player.health -= damage;

    // 4. Non-fatal damage check
    if (player.health > 0.0) {
        return .{
            .triggered = false,
            .death_cancelled = false,
            .player_died = false,
            .is_consumed = false,
        };
    }

    // 5. Fatal damage sustained (HP <= 0.0)
    // Void Death Exemption: Void damage (Y < -64) or /kill cannot be prevented
    if (damage_type.isVoidOrKill() or player.position[1] < VOID_DEATH_Y_THRESHOLD) {
        player.is_alive = false;
        player.inventory_dropped = true;
        player.experience_lost = true;
        player.experience_points = 0;
        return .{
            .triggered = false,
            .death_cancelled = false,
            .player_died = true,
            .is_consumed = false,
            .inventory_dropped = true,
            .experience_lost = true,
            .void_bypassed = true,
        };
    }

    // 6. Check hands for Totem of Undying (Offhand FIRST, then Main hand)
    const totem_hand_opt = checkHandsForTotem(&player.offhand, &player.main_hand);
    if (totem_hand_opt == null) {
        // No totem held in either hand - player dies!
        player.is_alive = false;
        player.inventory_dropped = true;
        player.experience_lost = true;
        player.experience_points = 0;
        return .{
            .triggered = false,
            .death_cancelled = false,
            .player_died = true,
            .is_consumed = false,
            .inventory_dropped = true,
            .experience_lost = true,
            .void_bypassed = false,
        };
    }

    const hand = totem_hand_opt.?;

    // 7. Consume exactly 1 Totem of Undying
    switch (hand) {
        .offhand => player.offhand.decrement(1),
        .main_hand => player.main_hand.decrement(1),
        .none => unreachable,
    }

    // 8. Cancel death event & restore health
    player.is_alive = true;
    player.inventory_dropped = false;
    player.experience_lost = false;
    player.health = RESURRECTION_HEALTH_HP; // Exactly 1.0 HP (half heart)

    // 9. Status Cleansing: Immediately remove all negative status effects
    const cleansed_count = player.effects.cleanseNegativeEffects();

    // 10. Resurrection Buff Suite:
    // a. Regeneration II (45.0s / 900 ticks) -> 0.8 HP/s, +36.0 HP total
    player.regeneration_ticks = REGEN_II_DURATION_TICKS;
    player.effects.addEffect(.{
        .effect_type = .regeneration,
        .amplifier = REGEN_II_AMPLIFIER,
        .ticks_remaining = REGEN_II_DURATION_TICKS,
    });

    // b. Absorption II (5.0s / 100 ticks) -> +8.0 absorption HP (4 golden hearts)
    player.absorption_ticks = ABSORPTION_II_DURATION_TICKS;
    player.absorption_health = ABSORPTION_II_HP;
    player.effects.addEffect(.{
        .effect_type = .absorption,
        .amplifier = ABSORPTION_II_AMPLIFIER,
        .ticks_remaining = ABSORPTION_II_DURATION_TICKS,
    });

    // c. Fire Resistance I (40.0s / 800 ticks) -> immune to fire/lava
    player.fire_resistance_ticks = @max(player.fire_resistance_ticks, FIRE_RESISTANCE_I_DURATION_TICKS);
    player.effects.addEffect(.{
        .effect_type = .fire_resistance,
        .amplifier = FIRE_RESISTANCE_I_AMPLIFIER,
        .ticks_remaining = player.fire_resistance_ticks,
    });

    // 11. Visual & Audio Resurrection Feedback:
    player.totem_animation.start();
    player.floating_totem_active = true;

    return .{
        .triggered = true,
        .death_cancelled = true,
        .player_died = false,
        .is_consumed = true,
        .consumed_hand = hand,
        .restored_hp = RESURRECTION_HEALTH_HP,
        .absorption_hp_added = ABSORPTION_II_HP,
        .cleansed_effects_count = cleansed_count,
        .regeneration_ticks = REGEN_II_DURATION_TICKS,
        .absorption_ticks = ABSORPTION_II_DURATION_TICKS,
        .fire_resistance_ticks = player.fire_resistance_ticks,
        .floating_totem_active = true,
        .sound_effect = .totem_use,
        .particles_emitted = SPARKLE_RING_PARTICLE_COUNT,
        .inventory_dropped = false,
        .experience_lost = false,
        .void_bypassed = false,
    };
}

/// Ticks player status effects, regeneration healing, absorption expiration,
/// fire resistance duration, and visual totem overlay animation.
pub fn tickPlayer(player: *PlayerState, dt: f32) void {
    const ticks: u32 = @intFromFloat(@max(1.0, dt * @as(f32, @floatFromInt(TICKS_PER_SECOND))));
    tickPlayerTicks(player, ticks);
}

/// Advances player timers by a discrete number of game ticks (20 ticks = 1 second).
pub fn tickPlayerTicks(player: *PlayerState, ticks: u32) void {
    for (0..ticks) |_| {
        // 1. Tick floating totem animation
        player.totem_animation.tick();
        player.floating_totem_active = player.totem_animation.floating_totem_active;

        // 2. Tick Regeneration II (0.8 HP/s = 0.04 HP/tick)
        if (player.regeneration_ticks > 0) {
            player.regeneration_ticks -= 1;
            player.health = @min(player.max_health, player.health + REGEN_II_HP_PER_TICK);
        }

        // 3. Tick Absorption II (expires after 100 ticks = 5.0 seconds)
        if (player.absorption_ticks > 0) {
            player.absorption_ticks -= 1;
            if (player.absorption_ticks == 0) {
                player.absorption_health = 0.0;
            }
        }

        // 4. Tick Fire Resistance I
        if (player.fire_resistance_ticks > 0) {
            player.fire_resistance_ticks -= 1;
        }

        // 5. Tick active status effects container
        player.effects.tick(1);
    }
}


// ============================================================================
// Unit Tests (45 Tests)
// ============================================================================

test "01. Offhand trigger: lethal damage activates totem held in offhand" {
    var player = PlayerState.init();
    player.health = 10.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.main_hand = .{ .item = .diamond_sword, .count = 1 };

    const result = evaluateDamage(&player, 15.0, .mob_attack);

    try std.testing.expect(result.triggered);
    try std.testing.expect(result.death_cancelled);
    try std.testing.expect(!result.player_died);
    try std.testing.expect(result.is_consumed);
    try std.testing.expectEqual(HandSlot.offhand, result.consumed_hand);
    try std.testing.expectEqual(RESURRECTION_HEALTH_HP, player.health);
    try std.testing.expect(player.offhand.isEmpty());
    try std.testing.expectEqual(@as(u8, 1), player.main_hand.count);
    try std.testing.expectEqual(ItemType.diamond_sword, player.main_hand.item);
}

test "02. Main hand trigger: lethal damage activates totem held in main hand" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .shield, .count = 1 };
    player.main_hand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 20.0, .generic);

    try std.testing.expect(result.triggered);
    try std.testing.expect(result.death_cancelled);
    try std.testing.expect(!result.player_died);
    try std.testing.expect(result.is_consumed);
    try std.testing.expectEqual(HandSlot.main_hand, result.consumed_hand);
    try std.testing.expectEqual(RESURRECTION_HEALTH_HP, player.health);
    try std.testing.expect(player.main_hand.isEmpty());
    try std.testing.expectEqual(ItemType.shield, player.offhand.item);
    try std.testing.expectEqual(@as(u8, 1), player.offhand.count);
}

test "03. Hand priority: offhand totem consumed first when both hands hold totems" {
    var player = PlayerState.init();
    player.health = 8.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.main_hand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 12.0, .combat);

    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(HandSlot.offhand, result.consumed_hand);
    try std.testing.expect(player.offhand.isEmpty());
    // Main hand totem must remain unconsumed!
    try std.testing.expectEqual(ItemType.totem_of_undying, player.main_hand.item);
    try std.testing.expectEqual(@as(u8, 1), player.main_hand.count);
}

test "04. Hand priority: main hand totem preserved when offhand totem activates" {
    var player = PlayerState.init();
    player.health = 2.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.main_hand = .{ .item = .totem_of_undying, .count = 3 };

    const result = evaluateDamage(&player, 10.0, .explosion);

    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(HandSlot.offhand, result.consumed_hand);
    try std.testing.expect(player.offhand.isEmpty());
    try std.testing.expectEqual(@as(u8, 3), player.main_hand.count);
}

test "05. Inventory check: totem in inventory slots but neither hand does not save player" {
    var player = PlayerState.init();
    player.health = 10.0;
    player.offhand = .{ .item = .shield, .count = 1 };
    player.main_hand = .{ .item = .diamond_sword, .count = 1 };
    player.inventory[0] = .{ .item = .totem_of_undying, .count = 1 };
    player.inventory[1] = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 25.0, .mob_attack);

    try std.testing.expect(!result.triggered);
    try std.testing.expect(!result.death_cancelled);
    try std.testing.expect(result.player_died);
    try std.testing.expect(!result.is_consumed);
    try std.testing.expect(result.inventory_dropped);
    try std.testing.expect(result.experience_lost);
    try std.testing.expect(!player.is_alive);
    // Totems in inventory remain untouched
    try std.testing.expectEqual(@as(u8, 1), player.inventory[0].count);
}

test "06. Empty hands: lethal damage kills player when neither hand holds totem" {
    var player = PlayerState.init();
    player.health = 10.0;
    player.offhand = .{};
    player.main_hand = .{};

    const result = evaluateDamage(&player, 15.0, .fall);

    try std.testing.expect(!result.triggered);
    try std.testing.expect(!result.death_cancelled);
    try std.testing.expect(result.player_died);
    try std.testing.expect(!player.is_alive);
    try std.testing.expect(player.inventory_dropped);
    try std.testing.expect(player.experience_lost);
    try std.testing.expectEqual(@as(u32, 0), player.experience_points);
}

test "07. Non-totem items: lethal damage kills player holding sword and shield" {
    var player = PlayerState.init();
    player.health = 4.0;
    player.offhand = .{ .item = .shield, .count = 1 };
    player.main_hand = .{ .item = .iron_sword, .count = 1 };

    const result = evaluateDamage(&player, 10.0, .combat);

    try std.testing.expect(!result.triggered);
    try std.testing.expect(result.player_died);
    try std.testing.expect(!player.is_alive);
}

test "08. Consumption: stack of 1 totem consumed becomes empty none slot" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 10.0, .generic);

    try std.testing.expect(result.is_consumed);
    try std.testing.expect(player.offhand.isEmpty());
    try std.testing.expectEqual(ItemType.none, player.offhand.item);
    try std.testing.expectEqual(@as(u8, 0), player.offhand.count);
}

test "09. Consumption: stack of 2 totems decrements to 1 totem remaining" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 2 };

    const result = evaluateDamage(&player, 10.0, .generic);

    try std.testing.expect(result.is_consumed);
    try std.testing.expectEqual(ItemType.totem_of_undying, player.offhand.item);
    try std.testing.expectEqual(@as(u8, 1), player.offhand.count);
}

test "10. Health reset: exact 1.0 HP restoration from fatal negative HP" {
    var player = PlayerState.init();
    player.health = 1.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    // Massive damage (1000 HP) reducing HP far below 0
    const result = evaluateDamage(&player, 1000.0, .explosion);

    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);
    try std.testing.expectEqual(RESURRECTION_HEALTH_HP, result.restored_hp);
}

test "11. Health reset: exact 1.0 HP restoration from exact 0.0 HP" {
    var player = PlayerState.init();
    player.health = 10.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    // Exact damage equal to health
    const result = evaluateDamage(&player, 10.0, .combat);

    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);
    try std.testing.expectEqual(RESURRECTION_HEALTH_HP, result.restored_hp);
}

test "12. Death cancellation: death_cancelled is true and player does not die" {
    var player = PlayerState.init();
    player.health = 6.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 12.0, .mob_attack);

    try std.testing.expect(result.death_cancelled);
    try std.testing.expect(!result.player_died);
    try std.testing.expect(player.is_alive);
}

test "13. Inventory retention: inventory is not dropped on totem resurrection" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.inventory[0] = .{ .item = .diamond_sword, .count = 1 };
    player.inventory[1] = .{ .item = .golden_apple, .count = 64 };

    const result = evaluateDamage(&player, 15.0, .generic);

    try std.testing.expect(!result.inventory_dropped);
    try std.testing.expect(!player.inventory_dropped);
    try std.testing.expectEqual(ItemType.diamond_sword, player.inventory[0].item);
    try std.testing.expectEqual(@as(u8, 64), player.inventory[1].count);
}

test "14. Experience retention: experience points are not lost on totem resurrection" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.experience_points = 5500;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 20.0, .fall);

    try std.testing.expect(!result.experience_lost);
    try std.testing.expect(!player.experience_lost);
    try std.testing.expectEqual(@as(u32, 5500), player.experience_points);
}

test "15. Status cleansing: clears Poison, Fatal Poison, and Wither" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    player.effects.addEffect(.{ .effect_type = .poison, .amplifier = 1, .ticks_remaining = 300 });
    player.effects.addEffect(.{ .effect_type = .fatal_poison, .amplifier = 0, .ticks_remaining = 200 });
    player.effects.addEffect(.{ .effect_type = .wither, .amplifier = 2, .ticks_remaining = 400 });

    try std.testing.expect(player.effects.hasEffect(.poison));
    try std.testing.expect(player.effects.hasEffect(.fatal_poison));
    try std.testing.expect(player.effects.hasEffect(.wither));

    const result = evaluateDamage(&player, 10.0, .wither);

    try std.testing.expect(result.triggered);
    try std.testing.expect(!player.effects.hasEffect(.poison));
    try std.testing.expect(!player.effects.hasEffect(.fatal_poison));
    try std.testing.expect(!player.effects.hasEffect(.wither));
    try std.testing.expect(result.cleansed_effects_count >= 3);
}

test "16. Status cleansing: clears Slowness and Weakness" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    player.effects.addEffect(.{ .effect_type = .slowness, .amplifier = 0, .ticks_remaining = 500 });
    player.effects.addEffect(.{ .effect_type = .weakness, .amplifier = 0, .ticks_remaining = 600 });

    const result = evaluateDamage(&player, 10.0, .combat);

    try std.testing.expect(result.triggered);
    try std.testing.expect(!player.effects.hasEffect(.slowness));
    try std.testing.expect(!player.effects.hasEffect(.weakness));
}

test "17. Status cleansing: clears Mining Fatigue, Levitation, Darkness, and Bad Omen" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    player.effects.addEffect(.{ .effect_type = .mining_fatigue, .amplifier = 2, .ticks_remaining = 1000 });
    player.effects.addEffect(.{ .effect_type = .levitation, .amplifier = 0, .ticks_remaining = 200 });
    player.effects.addEffect(.{ .effect_type = .darkness, .amplifier = 0, .ticks_remaining = 400 });
    player.effects.addEffect(.{ .effect_type = .bad_omen, .amplifier = 4, .ticks_remaining = 12000 });

    const result = evaluateDamage(&player, 10.0, .generic);

    try std.testing.expect(result.triggered);
    try std.testing.expect(!player.effects.hasEffect(.mining_fatigue));
    try std.testing.expect(!player.effects.hasEffect(.levitation));
    try std.testing.expect(!player.effects.hasEffect(.darkness));
    try std.testing.expect(!player.effects.hasEffect(.bad_omen));
}

test "18. Status cleansing: all 9 negative effects simultaneously cleansed" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    // Apply all 9 specified negative effects:
    player.effects.addEffect(.{ .effect_type = .poison, .amplifier = 1, .ticks_remaining = 100 });
    player.effects.addEffect(.{ .effect_type = .fatal_poison, .amplifier = 0, .ticks_remaining = 100 });
    player.effects.addEffect(.{ .effect_type = .wither, .amplifier = 1, .ticks_remaining = 100 });
    player.effects.addEffect(.{ .effect_type = .slowness, .amplifier = 1, .ticks_remaining = 100 });
    player.effects.addEffect(.{ .effect_type = .weakness, .amplifier = 0, .ticks_remaining = 100 });
    player.effects.addEffect(.{ .effect_type = .mining_fatigue, .amplifier = 2, .ticks_remaining = 100 });
    player.effects.addEffect(.{ .effect_type = .levitation, .amplifier = 0, .ticks_remaining = 100 });
    player.effects.addEffect(.{ .effect_type = .darkness, .amplifier = 0, .ticks_remaining = 100 });
    player.effects.addEffect(.{ .effect_type = .bad_omen, .amplifier = 0, .ticks_remaining = 100 });

    const result = evaluateDamage(&player, 20.0, .generic);

    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(@as(u32, 9), result.cleansed_effects_count);
    try std.testing.expect(!player.effects.hasEffect(.poison));
    try std.testing.expect(!player.effects.hasEffect(.fatal_poison));
    try std.testing.expect(!player.effects.hasEffect(.wither));
    try std.testing.expect(!player.effects.hasEffect(.slowness));
    try std.testing.expect(!player.effects.hasEffect(.weakness));
    try std.testing.expect(!player.effects.hasEffect(.mining_fatigue));
    try std.testing.expect(!player.effects.hasEffect(.levitation));
    try std.testing.expect(!player.effects.hasEffect(.darkness));
    try std.testing.expect(!player.effects.hasEffect(.bad_omen));
}

test "19. Status preservation: positive buffs like Speed and Strength are preserved" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    player.effects.addEffect(.{ .effect_type = .speed, .amplifier = 1, .ticks_remaining = 600 });
    player.effects.addEffect(.{ .effect_type = .strength, .amplifier = 0, .ticks_remaining = 800 });
    player.effects.addEffect(.{ .effect_type = .poison, .amplifier = 0, .ticks_remaining = 300 });

    const result = evaluateDamage(&player, 10.0, .generic);

    try std.testing.expect(result.triggered);
    // Negative poison cleansed
    try std.testing.expect(!player.effects.hasEffect(.poison));
    // Positive buffs preserved
    try std.testing.expect(player.effects.hasEffect(.speed));
    try std.testing.expect(player.effects.hasEffect(.strength));
    try std.testing.expectEqual(@as(u32, 600), player.effects.getEffect(.speed).?.ticks_remaining);
    try std.testing.expectEqual(@as(u32, 800), player.effects.getEffect(.strength).?.ticks_remaining);
}

test "20. Regeneration II: 45.0s (900 ticks) duration and +36.0 HP total healing" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.max_health = 100.0; // High max health to avoid clamping
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 10.0, .combat);

    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(REGEN_II_DURATION_TICKS, result.regeneration_ticks);
    try std.testing.expectEqual(@as(u32, 900), player.regeneration_ticks);

    // Initial health is 1.0 HP
    try std.testing.expectEqual(@as(f32, 1.0), player.health);

    // Tick full 900 ticks
    tickPlayerTicks(&player, 900);

    // Regeneration duration should now be exhausted
    try std.testing.expectEqual(@as(u32, 0), player.regeneration_ticks);
    // Total HP recovered should be exactly 1.0 + 36.0 = 37.0 HP!
    try std.testing.expectApproxEqAbs(@as(f32, 37.0), player.health, 1e-2);
}

test "21. Regeneration II: continuous rate of 0.8 HP/s correctly advances health" {
    var player = PlayerState.init();
    player.health = 2.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    _ = evaluateDamage(&player, 5.0, .generic);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);

    // Advance 1 second = 20 ticks (should heal 0.8 HP)
    tickPlayerTicks(&player, 20);
    try std.testing.expectApproxEqAbs(@as(f32, 1.8), player.health, 1e-4);

    // Advance another 4 seconds = 80 ticks (total 5s = 100 ticks -> 4.0 HP healed total)
    tickPlayerTicks(&player, 80);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), player.health, 1e-4);
}

test "22. Regeneration II: health clamped to max_health during regeneration" {
    var player = PlayerState.init();
    player.health = 1.0;
    player.max_health = 20.0; // Standard vanilla max health
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    _ = evaluateDamage(&player, 10.0, .generic);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);

    // 900 ticks would heal 36 HP, but max_health is 20.0
    tickPlayerTicks(&player, 900);
    try std.testing.expectEqual(@as(f32, 20.0), player.health);
}

test "23. Absorption II: 5.0s (100 ticks) duration and +8.0 absorption HP (4 golden hearts)" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 10.0, .generic);

    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(ABSORPTION_II_DURATION_TICKS, result.absorption_ticks);
    try std.testing.expectEqual(@as(u32, 100), player.absorption_ticks);
    try std.testing.expectEqual(ABSORPTION_II_HP, result.absorption_hp_added);
    try std.testing.expectEqual(@as(f32, 8.0), player.absorption_health);
}

test "24. Absorption II: absorption health absorbs incoming damage before real health" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    _ = evaluateDamage(&player, 10.0, .generic);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);
    try std.testing.expectEqual(@as(f32, 8.0), player.absorption_health);

    // Deal 5.0 non-fire damage - absorbed by absorption health
    const next_result = evaluateDamage(&player, 5.0, .combat);
    try std.testing.expect(!next_result.triggered);
    try std.testing.expect(!next_result.player_died);
    try std.testing.expectEqual(@as(f32, 3.0), player.absorption_health);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);
}

test "25. Absorption II: absorption health expires to 0 after 100 ticks" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    _ = evaluateDamage(&player, 10.0, .generic);
    try std.testing.expectEqual(@as(f32, 8.0), player.absorption_health);

    // Tick 99 ticks -> still active
    tickPlayerTicks(&player, 99);
    try std.testing.expectEqual(@as(u32, 1), player.absorption_ticks);
    try std.testing.expect(player.absorption_health > 0.0);

    // Tick 1 more tick (total 100 ticks) -> expires
    tickPlayerTicks(&player, 1);
    try std.testing.expectEqual(@as(u32, 0), player.absorption_ticks);
    try std.testing.expectEqual(@as(f32, 0.0), player.absorption_health);
}

test "26. Fire Resistance I: 40.0s (800 ticks) duration and fire/lava damage immunity" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 10.0, .combat);

    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(FIRE_RESISTANCE_I_DURATION_TICKS, result.fire_resistance_ticks);
    try std.testing.expectEqual(@as(u32, 800), player.fire_resistance_ticks);
    try std.testing.expect(player.hasFireResistance());
}

test "27. Fire Resistance I: preserves longer existing fire resistance duration" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.fire_resistance_ticks = 1500; // 75 seconds already active
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 10.0, .combat);

    try std.testing.expect(result.triggered);
    // Preserves the 1500 ticks since 1500 > 800
    try std.testing.expectEqual(@as(u32, 1500), player.fire_resistance_ticks);
    try std.testing.expectEqual(@as(u32, 1500), result.fire_resistance_ticks);
}

test "28. Fire Resistance I: completely prevents fire and lava damage" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    _ = evaluateDamage(&player, 10.0, .combat);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);

    // Inflict fire damage
    const fire_result = evaluateDamage(&player, 50.0, .fire);
    try std.testing.expect(!fire_result.player_died);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);

    // Inflict lava damage
    const lava_result = evaluateDamage(&player, 50.0, .lava);
    try std.testing.expect(!lava_result.player_died);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);
}

test "29. Void exemption: DamageType.void kills player and bypasses totem" {
    var player = PlayerState.init();
    player.health = 20.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.position = .{ 0.0, 10.0, 0.0 };

    const result = evaluateDamage(&player, 50.0, .void);

    try std.testing.expect(!result.triggered);
    try std.testing.expect(!result.death_cancelled);
    try std.testing.expect(result.player_died);
    try std.testing.expect(result.void_bypassed);
    try std.testing.expect(!result.is_consumed);
    try std.testing.expect(!player.is_alive);
    try std.testing.expect(player.inventory_dropped);
    try std.testing.expect(player.experience_lost);
    // Totem must NOT be consumed on void death!
    try std.testing.expectEqual(@as(u8, 1), player.offhand.count);
    try std.testing.expectEqual(ItemType.totem_of_undying, player.offhand.item);
}

test "30. Void exemption: DamageType.command_kill (/kill) kills player and bypasses totem" {
    var player = PlayerState.init();
    player.health = 20.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.main_hand = .{ .item = .totem_of_undying, .count = 1 };
    player.position = .{ 0.0, 64.0, 0.0 };

    const result = evaluateDamage(&player, 1000.0, .command_kill);

    try std.testing.expect(!result.triggered);
    try std.testing.expect(!result.death_cancelled);
    try std.testing.expect(result.player_died);
    try std.testing.expect(result.void_bypassed);
    try std.testing.expect(!result.is_consumed);
    try std.testing.expect(!player.is_alive);
    // Totems unconsumed
    try std.testing.expectEqual(@as(u8, 1), player.offhand.count);
    try std.testing.expectEqual(@as(u8, 1), player.main_hand.count);
}

test "31. Void exemption: position Y < -64 in the void kills player and bypasses totem" {
    var player = PlayerState.init();
    player.health = 10.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.position = .{ 0.0, -65.0, 0.0 }; // Below Y = -64

    // Generic damage while in the void
    const result = evaluateDamage(&player, 20.0, .generic);

    try std.testing.expect(!result.triggered);
    try std.testing.expect(!result.death_cancelled);
    try std.testing.expect(result.player_died);
    try std.testing.expect(result.void_bypassed);
    try std.testing.expect(!result.is_consumed);
    try std.testing.expect(!player.is_alive);
}

test "32. Void boundary: position Y = -64.0 triggers void death exemption" {
    var player = PlayerState.init();
    player.health = 10.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.position = .{ 0.0, -64.1, 0.0 };

    const result = evaluateDamage(&player, 20.0, .generic);

    try std.testing.expect(!result.triggered);
    try std.testing.expect(result.player_died);
    try std.testing.expect(result.void_bypassed);
}

test "33. Void boundary: position Y = -63.99 triggers totem resurrection safely" {
    var player = PlayerState.init();
    player.health = 10.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.position = .{ 0.0, -63.99, 0.0 }; // Above -64.0 threshold

    const result = evaluateDamage(&player, 20.0, .fall);

    try std.testing.expect(result.triggered);
    try std.testing.expect(result.death_cancelled);
    try std.testing.expect(!result.player_died);
    try std.testing.expect(!result.void_bypassed);
    try std.testing.expect(player.is_alive);
}

test "34. Void exemption preserves totem: totem is not consumed when void kills player" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.position = .{ 0.0, -70.0, 0.0 };

    const result = evaluateDamage(&player, 10.0, .generic);

    try std.testing.expect(result.player_died);
    try std.testing.expect(!result.is_consumed);
    try std.testing.expectEqual(@as(u8, 1), player.offhand.count);
    try std.testing.expectEqual(ItemType.totem_of_undying, player.offhand.item);
}

test "35. Zero damage: 0.0 damage leaves totem unconsumed and player alive" {
    var player = PlayerState.init();
    player.health = 10.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 0.0, .generic);

    try std.testing.expect(!result.triggered);
    try std.testing.expect(!result.player_died);
    try std.testing.expect(!result.is_consumed);
    try std.testing.expectEqual(@as(f32, 10.0), player.health);
    try std.testing.expectEqual(@as(u8, 1), player.offhand.count);
}

test "36. Non-lethal damage: damage leaving HP > 0 leaves totem unconsumed" {
    var player = PlayerState.init();
    player.health = 20.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 8.0, .combat);

    try std.testing.expect(!result.triggered);
    try std.testing.expect(!result.player_died);
    try std.testing.expect(!result.is_consumed);
    try std.testing.expectEqual(@as(f32, 12.0), player.health);
    try std.testing.expectEqual(@as(u8, 1), player.offhand.count);
}

test "37. Visual animation: floating totem active for 30 ticks (1.5s) overlay" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 10.0, .combat);

    try std.testing.expect(result.triggered);
    try std.testing.expect(result.floating_totem_active);
    try std.testing.expect(player.floating_totem_active);
    try std.testing.expect(player.totem_animation.floating_totem_active);
    try std.testing.expectEqual(ANIMATION_DURATION_TICKS, player.totem_animation.ticks_remaining);
    try std.testing.expectEqual(@as(u32, 30), player.totem_animation.ticks_remaining);
}

test "38. Visual animation: animation ticks down to 0 and deactivates" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    _ = evaluateDamage(&player, 10.0, .combat);
    try std.testing.expect(player.floating_totem_active);

    // Tick 29 ticks
    tickPlayerTicks(&player, 29);
    try std.testing.expect(player.floating_totem_active);
    try std.testing.expectEqual(@as(u32, 1), player.totem_animation.ticks_remaining);

    // Tick final 30th tick
    tickPlayerTicks(&player, 1);
    try std.testing.expect(!player.floating_totem_active);
    try std.testing.expect(!player.totem_animation.floating_totem_active);
    try std.testing.expectEqual(@as(u32, 0), player.totem_animation.ticks_remaining);
}

test "39. Visual animation: golden wings and emerald eyes colors and transform curves" {
    var anim = FloatingTotemAnimation{};
    anim.start();

    try std.testing.expect(anim.floating_totem_active);
    try std.testing.expectEqual(GOLDEN_SPARKLE_RGBA, anim.golden_wings_color);
    try std.testing.expectEqual(EMERALD_SPARKLE_RGBA, anim.emerald_eyes_color);

    // Progress at start is 0.0
    try std.testing.expectEqual(@as(f32, 0.0), anim.progress());
    try std.testing.expect(anim.scale() > 0.0);
    try std.testing.expectEqual(@as(f32, 1.0), anim.alpha());

    // Advance 25 ticks (5 ticks remaining -> in fadeout zone)
    for (0..25) |_| anim.tick();
    try std.testing.expectEqual(@as(u32, 5), anim.ticks_remaining);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), anim.alpha(), 1e-4);
}

test "40. Particle emission: emits 32 golden and emerald sparkle ring particles" {
    var particles_buf: [SPARKLE_RING_PARTICLE_COUNT]TotemParticle = undefined;
    const count = generateSparkleRing(.{ 10.0, 64.0, 10.0 }, &particles_buf);

    try std.testing.expectEqual(@as(usize, 32), count);
    for (particles_buf) |p| {
        try std.testing.expect(!p.isDead());
        try std.testing.expect(p.lifetime_ticks > 0);
        try std.testing.expect(p.size > 0.0);
    }
}

test "41. Particle emission: alternating golden yellow and emerald green RGBA bursts" {
    var particles_buf: [SPARKLE_RING_PARTICLE_COUNT]TotemParticle = undefined;
    _ = generateSparkleRing(.{ 0.0, 0.0, 0.0 }, &particles_buf);

    var gold_count: usize = 0;
    var emerald_count: usize = 0;

    for (particles_buf) |p| {
        switch (p.particle_type) {
            .golden_sparkle => {
                gold_count += 1;
                try std.testing.expectEqual(GOLDEN_SPARKLE_RGBA, p.color);
            },
            .emerald_sparkle => {
                emerald_count += 1;
                try std.testing.expectEqual(EMERALD_SPARKLE_RGBA, p.color);
            },
        }
    }

    try std.testing.expectEqual(@as(usize, 16), gold_count);
    try std.testing.expectEqual(@as(usize, 16), emerald_count);
}

test "42. Particle kinematics: sparkle particles advance with velocity and drag decay" {
    var particles_buf: [1]TotemParticle = undefined;
    _ = generateSparkleRing(.{ 0.0, 0.0, 0.0 }, &particles_buf);

    var p = particles_buf[0];
    const initial_pos = p.position;
    const initial_life = p.lifetime_ticks;

    p.tick();

    try std.testing.expectEqual(initial_life - 1, p.lifetime_ticks);
    // Position must have moved
    try std.testing.expect(p.position[0] != initial_pos[0] or p.position[1] != initial_pos[1] or p.position[2] != initial_pos[2]);
}

test "43. Audio event: emits SoundEffect.totem_use chime event" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };

    const result = evaluateDamage(&player, 10.0, .generic);

    try std.testing.expect(result.triggered);
    try std.testing.expect(result.sound_effect != null);
    try std.testing.expectEqual(SoundEffect.totem_use, result.sound_effect.?);
}

test "44. Chained resurrection: second lethal hit triggers second totem from main hand" {
    var player = PlayerState.init();
    player.health = 10.0;
    player.offhand = .{ .item = .totem_of_undying, .count = 1 };
    player.main_hand = .{ .item = .totem_of_undying, .count = 1 };

    // First lethal hit
    const r1 = evaluateDamage(&player, 20.0, .combat);
    try std.testing.expect(r1.triggered);
    try std.testing.expectEqual(HandSlot.offhand, r1.consumed_hand);
    try std.testing.expect(player.offhand.isEmpty());
    try std.testing.expectEqual(@as(u8, 1), player.main_hand.count);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);

    // Second lethal hit
    const r2 = evaluateDamage(&player, 50.0, .explosion);
    try std.testing.expect(r2.triggered);
    try std.testing.expectEqual(HandSlot.main_hand, r2.consumed_hand);
    try std.testing.expect(player.main_hand.isEmpty());
    try std.testing.expectEqual(@as(f32, 1.0), player.health);
    try std.testing.expect(player.is_alive);

    // Third lethal hit with no more totems
    const r3 = evaluateDamage(&player, 10.0, .mob_attack);
    try std.testing.expect(!r3.triggered);
    try std.testing.expect(r3.player_died);
    try std.testing.expect(!player.is_alive);
}

test "45. Legacy item ID 330 compatibility: activates properly" {
    var player = PlayerState.init();
    player.health = 5.0;
    player.offhand = .{ .item = .totem_legacy, .count = 1 };

    const result = evaluateDamage(&player, 10.0, .generic);

    try std.testing.expect(result.triggered);
    try std.testing.expect(result.death_cancelled);
    try std.testing.expectEqual(@as(f32, 1.0), player.health);
    try std.testing.expect(player.offhand.isEmpty());
}
