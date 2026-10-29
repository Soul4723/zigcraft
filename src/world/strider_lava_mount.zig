//! ============================================================================
//! Milestone 484: Strider Lava Walking & Warped Fungus on a Stick Steering
//! ============================================================================
//!
//! Overview:
//!   Striders are passive mobs indigenous to the Nether's vast lava oceans.
//!   Equipped with a saddle and guided by a Warped Fungus on a Stick, Striders
//!   serve as living mounts across hazardous lava lakes.
//!
//! Specifications & Rules:
//!   1. Target File: src/world/strider_lava_mount.zig
//!   2. Strider Entity Attributes & Thermal State Machine:
//!      - Max Health: 20.0 HP (10 hearts).
//!      - Thermal Temperature State:
//!        - ThermalState.warm: When walking on or submerged in lava (lava_source, flowing_lava).
//!          * Skin color: Vibrant warm red.
//!          * Base movement speed on lava: 4.17 m/s (fast stride across lava oceans).
//!          * Lava immunity: Completely immune to lava, fire, and heat damage (isImmuneToLava = true).
//!          * Surface walking: Floats on top of lava blocks without sinking.
//!        - ThermalState.freezing: When out of lava (on solid ground, in air, or in water).
//!          * Skin color: Cold shivering purple.
//!          * Ambient animation: Shivering / shuddering visual shake (is_shivering = true).
//!          * Movement penalty: Slows down by 70% (sluggish walk speed 1.25 m/s).
//!          * Water damage: Takes 4.0 HP damage per second when in water or rain!
//!   3. Saddle Equipping & Player Mounting:
//!      - Right-clicking an unsaddled Strider with a Saddle equips the saddle (is_saddled = true).
//!      - Right-clicking a saddled Strider mounts the player onto the Strider (is_mounted = true).
//!   4. Warped Fungus on a Stick Steering & Speed Boost:
//!      - ItemType.warped_fungus_on_a_stick (crafting: 1 Fishing Rod + 1 Warped Fungus, durability 100).
//!      - Steering: Strider steers toward the player's camera look direction while the player holds a Warped Fungus on a Stick.
//!      - Right-click Speed Boost (boostSpeed()):
//!        * Applies temporary speed surge (+100% boost: 8.34 m/s sprint on lava).
//!        * Boost duration: 200 game ticks (10.0 seconds).
//!        * Consumes 1 point of durability on the Warped Fungus on a Stick per boost.
//!        * When durability hits 0: reverts item to an ordinary Fishing Rod!
//!   5. Breeding & Baby Striders:
//!      - Feeding two adult Striders Warped Fungus triggers Love Mode, breeding a Baby Strider.
//! ============================================================================

const std = @import("std");

// ============================================================================
// Core Constants
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;
pub const TICK_DT: f32 = 1.0 / @as(f32, @floatFromInt(TICKS_PER_SECOND)); // 0.05 seconds

/// Health constants
pub const STRIDER_MAX_HEALTH: f32 = 20.0; // 10 hearts
pub const STRIDER_BABY_MAX_HEALTH: f32 = 10.0; // 5 hearts
pub const WARPED_FUNGUS_HEAL_AMOUNT: f32 = 2.0; // 1 heart

/// Speed constants (m/s)
pub const STRIDER_LAVA_SPEED: f32 = 4.17; // 4.17 m/s normal stride on lava
pub const STRIDER_LAND_SPEED: f32 = 1.25; // 1.25 m/s sluggish walk speed (70% penalty)
pub const STRIDER_BOOST_SPEED_LAVA: f32 = 8.34; // 8.34 m/s (+100% boost sprint on lava)
pub const STRIDER_BOOST_SPEED_LAND: f32 = 2.50; // boosted speed on land

pub const STRIDER_BOOST_SPEED: f32 = STRIDER_BOOST_SPEED_LAVA;
pub const BASE_SPEED_LAVA: f32 = STRIDER_LAVA_SPEED;
pub const SLUGGISH_SPEED_LAND: f32 = STRIDER_LAND_SPEED;

/// Warped Fungus on a Stick boost mechanics
pub const BOOST_DURATION_TICKS: u32 = 200; // 200 game ticks = 10.0 seconds
pub const BOOST_DURATION_SECONDS: f32 = 10.0;
pub const BOOST_DURABILITY_COST: u16 = 1;

/// Environmental hazard constants
pub const STRIDER_WATER_DAMAGE_PER_SECOND: f32 = 4.0; // 4.0 HP damage per second
pub const STRIDER_WATER_DAMAGE_PER_TICK: f32 = STRIDER_WATER_DAMAGE_PER_SECOND / @as(f32, @floatFromInt(TICKS_PER_SECOND)); // 0.2 HP/tick

/// Durability constants
pub const WARPED_FUNGUS_STICK_MAX_DURABILITY: u16 = 100;
pub const FISHING_ROD_MAX_DURABILITY: u16 = 64;

/// Breeding and growth constants
pub const LOVE_MODE_DURATION_TICKS: u32 = 600; // 30 seconds
pub const BREEDING_COOLDOWN_TICKS: u32 = 6000; // 5 minutes
pub const BABY_GROWTH_TICKS: u32 = 24000; // 20 minutes
pub const BABY_GROWTH_FEED_REDUCTION_TICKS: u32 = 2400; // 10% reduction per warped fungus

/// Offsets
pub const STRIDER_RIDER_Y_OFFSET: f32 = 1.60;
pub const BABY_PIGGYBACK_Y_OFFSET: f32 = 1.35;

// ============================================================================
// Math & Vector Structures
// ============================================================================

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const zero: Vec3 = .{ .x = 0.0, .y = 0.0, .z = 0.0 };

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn lengthSq(v: Vec3) f32 {
        return v.x * v.x + v.y * v.y + v.z * v.z;
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(v.lengthSq());
    }

    pub fn horizontalLengthSq(v: Vec3) f32 {
        return v.x * v.x + v.z * v.z;
    }

    pub fn horizontalLength(v: Vec3) f32 {
        return @sqrt(v.horizontalLengthSq());
    }

    pub fn normalize(v: Vec3) Vec3 {
        const l = v.length();
        if (l < 1e-6) return Vec3.zero;
        return .{ .x = v.x / l, .y = v.y / l, .z = v.z / l };
    }

    pub fn horizontalNormalize(v: Vec3) Vec3 {
        const hl = v.horizontalLength();
        if (hl < 1e-6) return Vec3.zero;
        return .{ .x = v.x / hl, .y = 0.0, .z = v.z / hl };
    }

    pub fn distanceSq(a: Vec3, b: Vec3) f32 {
        return a.sub(b).lengthSq();
    }

    pub fn distance(a: Vec3, b: Vec3) f32 {
        return @sqrt(a.distanceSq(b));
    }
};

// ============================================================================
// RGBA Color Representation
// ============================================================================

pub const ColorRGBA = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,

    pub fn eql(self: ColorRGBA, other: ColorRGBA) bool {
        const eps: f32 = 0.01;
        return @abs(self.r - other.r) < eps and
            @abs(self.g - other.g) < eps and
            @abs(self.b - other.b) < eps and
            @abs(self.a - other.a) < eps;
    }
};

/// Vibrant warm red color when walking on or submerged in lava
pub const VIBRANT_WARM_RED: ColorRGBA = .{ .r = 0.81, .g = 0.22, .b = 0.17, .a = 1.0 };

/// Cold shivering purple color when out of lava
pub const COLD_SHIVERING_PURPLE: ColorRGBA = .{ .r = 0.42, .g = 0.38, .b = 0.55, .a = 1.0 };

// ============================================================================
// Enums & Environment Types
// ============================================================================

/// Thermal temperature states for the Strider
pub const ThermalState = enum {
    warm,
    freezing,

    pub fn isWarm(self: ThermalState) bool {
        return self == .warm;
    }

    pub fn isFreezing(self: ThermalState) bool {
        return self == .freezing;
    }

    pub fn skinColor(self: ThermalState) ColorRGBA {
        return switch (self) {
            .warm => VIBRANT_WARM_RED,
            .freezing => COLD_SHIVERING_PURPLE,
        };
    }
};

/// Block kinds relevant to Strider locomotion and hazards
pub const BlockType = enum {
    air,
    solid_ground,
    netherrack,
    basalt,
    blackstone,
    lava_source,
    flowing_lava,
    water_source,
    flowing_water,
    warped_fungus,

    pub fn isLava(self: BlockType) bool {
        return self == .lava_source or self == .flowing_lava;
    }

    pub fn isWater(self: BlockType) bool {
        return self == .water_source or self == .flowing_water;
    }

    pub fn isSolid(self: BlockType) bool {
        return self == .solid_ground or self == .netherrack or self == .basalt or self == .blackstone;
    }
};

/// Strider immediate environmental context
pub const StriderEnvironment = struct {
    block_at_feet: BlockType = .lava_source,
    block_at_body: BlockType = .air,
    is_raining: bool = false,
    lava_surface_y: ?f32 = null,

    pub fn isOnOrInLava(self: StriderEnvironment) bool {
        return self.block_at_feet.isLava() or self.block_at_body.isLava();
    }

    pub fn isInWaterOrRain(self: StriderEnvironment) bool {
        return self.block_at_feet.isWater() or self.block_at_body.isWater() or self.is_raining;
    }
};

/// Damage classifications
pub const DamageType = enum {
    lava,
    fire,
    fire_tick,
    water,
    rain,
    drowning,
    fall,
    player_attack,
    generic,

    pub fn isFireOrLava(self: DamageType) bool {
        return self == .lava or self == .fire or self == .fire_tick;
    }

    pub fn isWaterOrRain(self: DamageType) bool {
        return self == .water or self == .rain or self == .drowning;
    }
};

/// Audio sound cues
pub const SoundEvent = enum {
    strider_step,
    strider_ambient,
    strider_hurt,
    strider_death,
    strider_eat,
    strider_boost,
    strider_saddle,
    strider_shiver,
};

/// Visual particle cues
pub const ParticleEvent = enum {
    shivering_chill,
    lava_drip,
    heart_love,
    boost_smoke,
    water_splash,
};

/// Item inventory types
pub const ItemType = enum {
    none,
    saddle,
    warped_fungus,
    fishing_rod,
    warped_fungus_on_a_stick,
    stick,
    string,
    diamond,
    dirt,

    pub fn isWarpedFungus(self: ItemType) bool {
        return self == .warped_fungus;
    }

    pub fn isSaddle(self: ItemType) bool {
        return self == .saddle;
    }

    pub fn isWarpedFungusOnAStick(self: ItemType) bool {
        return self == .warped_fungus_on_a_stick;
    }
};

/// Stacked items with durability
pub const ItemStack = struct {
    item_type: ItemType = .none,
    count: u16 = 0,
    durability: u16 = 0,
    max_durability: u16 = 0,

    pub fn init(item_type: ItemType, count: u16) ItemStack {
        var dur: u16 = 0;
        var max_dur: u16 = 0;
        switch (item_type) {
            .warped_fungus_on_a_stick => {
                dur = WARPED_FUNGUS_STICK_MAX_DURABILITY;
                max_dur = WARPED_FUNGUS_STICK_MAX_DURABILITY;
            },
            .fishing_rod => {
                dur = FISHING_ROD_MAX_DURABILITY;
                max_dur = FISHING_ROD_MAX_DURABILITY;
            },
            else => {},
        }
        return .{
            .item_type = item_type,
            .count = count,
            .durability = dur,
            .max_durability = max_dur,
        };
    }

    pub fn consumeDurability(self: *ItemStack, amount: u16) bool {
        if (self.durability == 0) return false;
        if (self.durability <= amount) {
            self.durability = 0;
            if (self.item_type == .warped_fungus_on_a_stick) {
                // Revert to ordinary fishing rod when durability hits 0
                self.item_type = .fishing_rod;
                self.durability = FISHING_ROD_MAX_DURABILITY;
                self.max_durability = FISHING_ROD_MAX_DURABILITY;
                return true;
            }
            return true;
        } else {
            self.durability -= amount;
            return false;
        }
    }
};

/// Crafting function: 1 Fishing Rod + 1 Warped Fungus -> Warped Fungus on a Stick (durability 100)
pub fn craftWarpedFungusOnAStick(item_a: ItemStack, item_b: ItemStack) ?ItemStack {
    const is_match = (item_a.item_type == .fishing_rod and item_a.count >= 1 and item_b.item_type == .warped_fungus and item_b.count >= 1) or
        (item_b.item_type == .fishing_rod and item_b.count >= 1 and item_a.item_type == .warped_fungus and item_a.count >= 1);
    if (is_match) {
        return ItemStack.init(.warped_fungus_on_a_stick, 1);
    }
    return null;
}

/// Interaction result classifications
pub const InteractionResult = enum {
    none,
    saddled,
    mounted,
    dismounted,
    fed_fungus_love,
    fed_fungus_healed,
    fed_fungus_growth,
    boosted,
};

// ============================================================================
// Strider Entity State Machine
// ============================================================================

pub const Strider = struct {
    id: u64,
    position: Vec3,
    velocity: Vec3 = Vec3.zero,
    facing_direction: Vec3 = .{ .x = 0.0, .y = 0.0, .z = 1.0 },
    yaw: f32 = 0.0,
    pitch: f32 = 0.0,

    health: f32 = STRIDER_MAX_HEALTH,
    max_health: f32 = STRIDER_MAX_HEALTH,
    is_alive: bool = true,

    // Thermal State Machine
    thermal_state: ThermalState = .warm,
    skin_color: ColorRGBA = VIBRANT_WARM_RED,
    is_shivering: bool = false,
    shiver_phase: f32 = 0.0,
    shiver_offset: f32 = 0.0,
    isImmuneToLava: bool = true, // Completely immune to lava, fire, and heat damage!
    is_surface_walking: bool = false,

    // Mounting & Saddling
    is_saddled: bool = false,
    is_mounted: bool = false,
    rider_id: ?u64 = null,

    // Speed boost state
    is_boosting: bool = false,
    boost_ticks_remaining: u32 = 0,

    // Breeding & Life Cycle
    in_love: bool = false,
    love_ticks: u32 = 0,
    breeding_cooldown_ticks: u32 = 0,
    is_baby: bool = false,
    growth_ticks_remaining: u32 = 0,
    scale: f32 = 1.0,

    // Piggyback passenger
    is_piggyback: bool = false,
    piggyback_parent_id: ?u64 = null,

    // Audio & Particle feedback
    last_sound: ?SoundEvent = null,
    last_particle: ?ParticleEvent = null,

    pub fn init(id: u64, pos: Vec3, is_baby: bool) Strider {
        const hp = if (is_baby) STRIDER_BABY_MAX_HEALTH else STRIDER_MAX_HEALTH;
        const growth = if (is_baby) BABY_GROWTH_TICKS else 0;
        const s: f32 = if (is_baby) 0.5 else 1.0;
        return .{
            .id = id,
            .position = pos,
            .is_baby = is_baby,
            .health = hp,
            .max_health = hp,
            .growth_ticks_remaining = growth,
            .scale = s,
            .thermal_state = .warm,
            .skin_color = VIBRANT_WARM_RED,
            .is_shivering = false,
            .isImmuneToLava = true,
            .is_surface_walking = false,
        };
    }

    pub fn setThermalState(self: *Strider, state: ThermalState) void {
        self.thermal_state = state;
        self.skin_color = state.skinColor();
        self.is_shivering = (state == .freezing);
        if (state == .warm) {
            self.shiver_phase = 0.0;
            self.shiver_offset = 0.0;
        }
    }

    pub fn updateThermalState(self: *Strider, env: StriderEnvironment) void {
        if (env.isOnOrInLava()) {
            self.setThermalState(.warm);
            self.is_surface_walking = true;
        } else {
            self.setThermalState(.freezing);
            self.is_surface_walking = false;
        }
    }

    pub fn getMovementSpeed(self: Strider) f32 {
        switch (self.thermal_state) {
            .warm => {
                if (self.is_boosting) {
                    return STRIDER_BOOST_SPEED_LAVA; // 8.34 m/s (+100% boost)
                } else {
                    return STRIDER_LAVA_SPEED; // 4.17 m/s
                }
            },
            .freezing => {
                if (self.is_boosting) {
                    return STRIDER_BOOST_SPEED_LAND; // 2.50 m/s
                } else {
                    return STRIDER_LAND_SPEED; // 1.25 m/s (70% sluggish penalty)
                }
            },
        }
    }

    pub fn getSpeed(self: Strider) f32 {
        return self.getMovementSpeed();
    }

    pub fn canTakeDamageFrom(self: Strider, source: DamageType) bool {
        _ = self;
        if (source.isFireOrLava()) {
            return false; // completely immune to lava, fire, and heat damage!
        }
        return true;
    }

    pub fn takeDamage(self: *Strider, amount: f32, source: DamageType) bool {
        if (!self.is_alive) return false;
        if (!self.canTakeDamageFrom(source)) return false;

        self.health = @max(0.0, self.health - amount);
        self.last_sound = if (self.health <= 0.0) .strider_death else .strider_hurt;
        if (self.health <= 0.0) {
            self.is_alive = false;
            self.is_mounted = false;
            self.rider_id = null;
            self.is_boosting = false;
        }
        return true;
    }

    pub fn heal(self: *Strider, amount: f32) void {
        if (!self.is_alive) return;
        self.health = @min(self.max_health, self.health + amount);
    }

    pub fn applyWaterHazardDamage(self: *Strider, dt_seconds: f32) f32 {
        const damage = STRIDER_WATER_DAMAGE_PER_SECOND * dt_seconds;
        _ = self.takeDamage(damage, .water);
        self.last_particle = .water_splash;
        return damage;
    }

    pub fn equipSaddle(self: *Strider, saddle_item: ?*ItemStack) bool {
        if (self.is_saddled) return false;
        if (self.is_baby) return false;
        if (saddle_item) |item| {
            if (item.item_type != .saddle or item.count == 0) return false;
            item.count -= 1;
        }
        self.is_saddled = true;
        self.last_sound = .strider_saddle;
        return true;
    }

    pub fn mount(self: *Strider, player_id: u64) bool {
        if (!self.is_saddled) return false;
        if (self.is_mounted) return false;
        if (self.is_baby) return false;
        self.is_mounted = true;
        self.rider_id = player_id;
        return true;
    }

    pub fn mountPlayer(self: *Strider, player_id: u64) bool {
        return self.mount(player_id);
    }

    pub fn dismount(self: *Strider) bool {
        if (!self.is_mounted) return false;
        self.is_mounted = false;
        self.rider_id = null;
        self.is_boosting = false;
        self.boost_ticks_remaining = 0;
        return true;
    }

    pub fn dismountPlayer(self: *Strider) bool {
        return self.dismount();
    }

    pub fn steer(self: *Strider, camera_look_vector: Vec3, holds_fungus_stick: bool) bool {
        if (!self.is_mounted or !holds_fungus_stick) return false;

        const horizontal_dir = Vec3.init(camera_look_vector.x, 0.0, camera_look_vector.z);
        if (horizontal_dir.lengthSq() < 0.0001) return false;

        const norm = horizontal_dir.normalize();
        self.facing_direction = norm;
        self.yaw = std.math.atan2(norm.x, norm.z);

        const speed = self.getMovementSpeed();
        self.velocity = norm.scale(speed);
        return true;
    }

    pub fn boostSpeed(self: *Strider, stick: *ItemStack) bool {
        if (!self.is_mounted) return false;
        if (stick.item_type != .warped_fungus_on_a_stick) return false;
        if (stick.durability == 0) return false;

        self.is_boosting = true;
        self.boost_ticks_remaining = BOOST_DURATION_TICKS;
        _ = stick.consumeDurability(BOOST_DURABILITY_COST);
        self.last_sound = .strider_boost;
        self.last_particle = .boost_smoke;

        // If currently moving, update velocity to new boosted speed
        if (self.velocity.horizontalLength() > 0.001) {
            self.velocity = self.facing_direction.scale(self.getMovementSpeed());
        }
        return true;
    }

    pub fn boost(self: *Strider, stick: *ItemStack) bool {
        return self.boostSpeed(stick);
    }

    pub fn activateBoost(self: *Strider, duration_ticks: u32) void {
        self.is_boosting = true;
        self.boost_ticks_remaining = duration_ticks;
        if (self.velocity.horizontalLength() > 0.001) {
            self.velocity = self.facing_direction.scale(self.getMovementSpeed());
        }
    }

    pub fn feedWarpedFungus(self: *Strider, fungus: *ItemStack) bool {
        if (fungus.item_type != .warped_fungus or fungus.count == 0) return false;

        if (self.is_baby) {
            fungus.count -= 1;
            self.last_sound = .strider_eat;
            if (self.growth_ticks_remaining <= BABY_GROWTH_FEED_REDUCTION_TICKS) {
                self.growth_ticks_remaining = 0;
                self.is_baby = false;
                self.scale = 1.0;
                self.max_health = STRIDER_MAX_HEALTH;
                self.health = STRIDER_MAX_HEALTH;
            } else {
                self.growth_ticks_remaining -= BABY_GROWTH_FEED_REDUCTION_TICKS;
                const progress = 1.0 - (@as(f32, @floatFromInt(self.growth_ticks_remaining)) / @as(f32, @floatFromInt(BABY_GROWTH_TICKS)));
                self.scale = 0.5 + 0.5 * progress;
            }
            return true;
        }

        // Adult:
        if (self.health < self.max_health) {
            self.heal(WARPED_FUNGUS_HEAL_AMOUNT);
            fungus.count -= 1;
            self.last_sound = .strider_eat;
            return true;
        }

        if (!self.in_love and self.breeding_cooldown_ticks == 0) {
            self.in_love = true;
            self.love_ticks = LOVE_MODE_DURATION_TICKS;
            fungus.count -= 1;
            self.last_sound = .strider_eat;
            self.last_particle = .heart_love;
            return true;
        }

        return false;
    }

    pub fn interact(self: *Strider, player_id: u64, held_item: ?*ItemStack) InteractionResult {
        if (!self.is_saddled) {
            if (held_item) |item| {
                if (item.item_type == .saddle) {
                    if (self.equipSaddle(item)) {
                        return .saddled;
                    }
                    return .none;
                }
                if (item.item_type == .warped_fungus) {
                    if (self.feedWarpedFungus(item)) {
                        if (self.is_baby) return .fed_fungus_growth;
                        if (self.in_love) return .fed_fungus_love;
                        return .fed_fungus_healed;
                    }
                    return .none;
                }
            }
            return .none;
        }

        // Saddled:
        if (!self.is_mounted) {
            if (held_item) |item| {
                if (item.item_type == .warped_fungus and !self.in_love and self.breeding_cooldown_ticks == 0) {
                    if (self.feedWarpedFungus(item)) {
                        return .fed_fungus_love;
                    }
                }
            }
            if (self.mount(player_id)) {
                return .mounted;
            }
            return .none;
        }

        // Mounted:
        if (self.rider_id == player_id) {
            if (held_item) |item| {
                if (item.item_type == .warped_fungus_on_a_stick) {
                    if (self.boostSpeed(item)) {
                        return .boosted;
                    }
                    return .none;
                }
            }
            if (self.dismount()) {
                return .dismounted;
            }
        }
        return .none;
    }

    pub fn mountPiggyback(self: *Strider, parent_id: u64) bool {
        if (!self.is_baby) return false;
        self.is_piggyback = true;
        self.piggyback_parent_id = parent_id;
        return true;
    }

    pub fn updatePiggybackPosition(self: *Strider, parent_pos: Vec3) void {
        if (self.is_piggyback) {
            self.position = Vec3.init(parent_pos.x, parent_pos.y + BABY_PIGGYBACK_Y_OFFSET, parent_pos.z);
        }
    }

    pub fn tick(self: *Strider, dt_ticks: u32, env: StriderEnvironment) void {
        if (!self.is_alive) return;

        const dt_sec = @as(f32, @floatFromInt(dt_ticks)) * TICK_DT;

        // 1. Update Thermal State
        self.updateThermalState(env);

        // 2. Water / Rain Hazard Damage
        if (env.isInWaterOrRain()) {
            _ = self.applyWaterHazardDamage(dt_sec);
            if (!self.is_alive) return;
        }

        // 3. Lava Surface Buoyancy / Surface Walking
        if (self.thermal_state == .warm and env.lava_surface_y != null) {
            if (self.position.y < env.lava_surface_y.?) {
                self.position.y = env.lava_surface_y.?;
                self.velocity.y = @max(0.0, self.velocity.y);
            }
        }

        // 4. Speed Boost Timer
        if (self.is_boosting) {
            if (self.boost_ticks_remaining <= dt_ticks) {
                self.boost_ticks_remaining = 0;
                self.is_boosting = false;
                if (self.velocity.horizontalLength() > 0.001) {
                    self.velocity = self.facing_direction.scale(self.getMovementSpeed());
                }
            } else {
                self.boost_ticks_remaining -= dt_ticks;
            }
        }

        // 5. Shivering Animation
        if (self.is_shivering) {
            self.shiver_phase += dt_sec * 25.0;
            self.shiver_offset = @sin(self.shiver_phase) * 0.05;
            if (self.last_particle == null) {
                self.last_particle = .shivering_chill;
            }
        } else {
            self.shiver_phase = 0.0;
            self.shiver_offset = 0.0;
        }

        // 6. Love Timer
        if (self.in_love) {
            if (self.love_ticks <= dt_ticks) {
                self.love_ticks = 0;
                self.in_love = false;
            } else {
                self.love_ticks -= dt_ticks;
            }
        }

        // 7. Breeding Cooldown
        if (self.breeding_cooldown_ticks > 0) {
            if (self.breeding_cooldown_ticks <= dt_ticks) {
                self.breeding_cooldown_ticks = 0;
            } else {
                self.breeding_cooldown_ticks -= dt_ticks;
            }
        }

        // 8. Baby Growth
        if (self.is_baby) {
            if (self.growth_ticks_remaining <= dt_ticks) {
                self.growth_ticks_remaining = 0;
                self.is_baby = false;
                self.scale = 1.0;
                self.max_health = STRIDER_MAX_HEALTH;
                self.health = STRIDER_MAX_HEALTH;
            } else {
                self.growth_ticks_remaining -= dt_ticks;
                const progress = 1.0 - (@as(f32, @floatFromInt(self.growth_ticks_remaining)) / @as(f32, @floatFromInt(BABY_GROWTH_TICKS)));
                self.scale = 0.5 + 0.5 * progress;
            }
        }

        // 9. Integration of horizontal position
        self.position = self.position.add(self.velocity.scale(dt_sec));
    }
};

/// Breeding two adult Striders in Love Mode produces a Baby Strider
pub fn breed(parent_a: *Strider, parent_b: *Strider, baby_id: u64) ?Strider {
    if (!parent_a.is_alive or !parent_b.is_alive) return null;
    if (parent_a.is_baby or parent_b.is_baby) return null;
    if (!parent_a.in_love or !parent_b.in_love) return null;
    if (parent_a.id == parent_b.id) return null;

    parent_a.in_love = false;
    parent_a.love_ticks = 0;
    parent_a.breeding_cooldown_ticks = BREEDING_COOLDOWN_TICKS;

    parent_b.in_love = false;
    parent_b.love_ticks = 0;
    parent_b.breeding_cooldown_ticks = BREEDING_COOLDOWN_TICKS;

    parent_a.last_particle = .heart_love;
    parent_b.last_particle = .heart_love;

    const spawn_pos = parent_a.position.add(parent_b.position).scale(0.5);
    var baby = Strider.init(baby_id, spawn_pos, true);
    baby.thermal_state = parent_a.thermal_state;
    baby.skin_color = baby.thermal_state.skinColor();
    baby.is_shivering = baby.thermal_state.isFreezing();
    return baby;
}

// ============================================================================
// Multi-Strider Simulation World
// ============================================================================

pub const StriderLavaMountSimulation = struct {
    allocator: std.mem.Allocator,
    striders: std.ArrayList(Strider),
    next_id: u64 = 1,

    pub fn init(allocator: std.mem.Allocator) StriderLavaMountSimulation {
        return .{
            .allocator = allocator,
            .striders = std.ArrayList(Strider).empty,
            .next_id = 1,
        };
    }

    pub fn deinit(self: *StriderLavaMountSimulation) void {
        self.striders.deinit(self.allocator);
    }

    pub fn spawnStrider(self: *StriderLavaMountSimulation, pos: Vec3, is_baby: bool) !*Strider {
        const id = self.next_id;
        self.next_id += 1;
        try self.striders.append(self.allocator, Strider.init(id, pos, is_baby));
        return &self.striders.items[self.striders.items.len - 1];
    }

    pub fn getStrider(self: *StriderLavaMountSimulation, id: u64) ?*Strider {
        for (self.striders.items) |*s| {
            if (s.id == id) return s;
        }
        return null;
    }

    pub fn tick(self: *StriderLavaMountSimulation, dt_ticks: u32, default_env: StriderEnvironment) void {
        for (self.striders.items) |*s| {
            s.tick(dt_ticks, default_env);
        }
    }
};

// ============================================================================
// Unit Tests (45+ Comprehensive Tests)
// ============================================================================

test "1. Strider Attributes: Max Health is 20.0 HP (10 hearts) and starts alive" {
    const strider = Strider.init(1, Vec3.zero, false);
    try std.testing.expectEqual(STRIDER_MAX_HEALTH, strider.max_health);
    try std.testing.expectEqual(STRIDER_MAX_HEALTH, strider.health);
    try std.testing.expect(strider.is_alive);
    try std.testing.expect(!strider.is_baby);
    try std.testing.expectEqual(@as(f32, 1.0), strider.scale);
}

test "2. Strider Attributes: Baby Strider initializes with 10.0 HP and 0.5 scale" {
    const baby = Strider.init(2, Vec3.zero, true);
    try std.testing.expectEqual(STRIDER_BABY_MAX_HEALTH, baby.max_health);
    try std.testing.expectEqual(STRIDER_BABY_MAX_HEALTH, baby.health);
    try std.testing.expect(baby.is_baby);
    try std.testing.expectEqual(@as(f32, 0.5), baby.scale);
    try std.testing.expectEqual(BABY_GROWTH_TICKS, baby.growth_ticks_remaining);
}

test "3. Thermal State Machine: Warm state in lava source block" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.updateThermalState(.{ .block_at_feet = .lava_source });
    try std.testing.expectEqual(ThermalState.warm, strider.thermal_state);
    try std.testing.expect(strider.thermal_state.isWarm());
    try std.testing.expect(!strider.is_shivering);
    try std.testing.expect(strider.is_surface_walking);
}

test "4. Thermal State Machine: Warm state in flowing lava block" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.updateThermalState(.{ .block_at_feet = .flowing_lava });
    try std.testing.expectEqual(ThermalState.warm, strider.thermal_state);
    try std.testing.expect(strider.thermal_state.isWarm());
    try std.testing.expect(!strider.is_shivering);
}

test "5. Thermal State Machine: Warm state skin color is vibrant warm red" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.updateThermalState(.{ .block_at_feet = .lava_source });
    try std.testing.expect(strider.skin_color.eql(VIBRANT_WARM_RED));
    try std.testing.expectApproxEqAbs(@as(f32, 0.81), strider.skin_color.r, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.22), strider.skin_color.g, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.17), strider.skin_color.b, 0.01);
}

test "6. Thermal State Machine: Base movement speed on lava is exactly 4.17 m/s" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.updateThermalState(.{ .block_at_feet = .lava_source });
    try std.testing.expectEqual(STRIDER_LAVA_SPEED, strider.getMovementSpeed());
    try std.testing.expectEqual(@as(f32, 4.17), strider.getSpeed());
}

test "7. Lava Immunity: Strider is completely immune to lava, fire, and heat damage" {
    var strider = Strider.init(1, Vec3.zero, false);
    try std.testing.expect(strider.isImmuneToLava);

    // Lava damage attempt
    const damaged_lava = strider.takeDamage(10.0, .lava);
    try std.testing.expect(!damaged_lava);
    try std.testing.expectEqual(STRIDER_MAX_HEALTH, strider.health);

    // Fire damage attempt
    const damaged_fire = strider.takeDamage(5.0, .fire);
    try std.testing.expect(!damaged_fire);
    try std.testing.expectEqual(STRIDER_MAX_HEALTH, strider.health);

    // Fire tick damage attempt
    const damaged_fire_tick = strider.takeDamage(1.0, .fire_tick);
    try std.testing.expect(!damaged_fire_tick);
    try std.testing.expectEqual(STRIDER_MAX_HEALTH, strider.health);
}

test "8. Surface Walking: Strider floats on top of lava blocks without sinking" {
    var strider = Strider.init(1, Vec3.init(0.0, 30.0, 0.0), false);
    const env = StriderEnvironment{
        .block_at_feet = .lava_source,
        .lava_surface_y = 32.0,
    };

    // Before tick, strider is below lava surface (Y=30.0)
    strider.tick(1, env);
    try std.testing.expect(strider.is_surface_walking);
    // Floated up to lava surface level (Y=32.0)
    try std.testing.expectEqual(@as(f32, 32.0), strider.position.y);
    try std.testing.expect(strider.velocity.y >= 0.0);
}

test "9. Thermal State Machine: Freezing state when out of lava on solid ground" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.updateThermalState(.{ .block_at_feet = .solid_ground });
    try std.testing.expectEqual(ThermalState.freezing, strider.thermal_state);
    try std.testing.expect(strider.thermal_state.isFreezing());
    try std.testing.expect(strider.is_shivering);
    try std.testing.expect(!strider.is_surface_walking);
}

test "10. Thermal State Machine: Freezing state when in air" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.updateThermalState(.{ .block_at_feet = .air });
    try std.testing.expectEqual(ThermalState.freezing, strider.thermal_state);
    try std.testing.expect(strider.is_shivering);
}

test "11. Thermal State Machine: Freezing state skin color is cold shivering purple" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.updateThermalState(.{ .block_at_feet = .netherrack });
    try std.testing.expect(strider.skin_color.eql(COLD_SHIVERING_PURPLE));
    try std.testing.expectApproxEqAbs(@as(f32, 0.42), strider.skin_color.r, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.38), strider.skin_color.g, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), strider.skin_color.b, 0.01);
}

test "12. Thermal State Machine: Ambient shivering animation oscillates visual shake" {
    var strider = Strider.init(1, Vec3.zero, false);
    const env = StriderEnvironment{ .block_at_feet = .solid_ground };

    strider.tick(10, env);
    try std.testing.expect(strider.is_shivering);
    try std.testing.expect(strider.shiver_phase > 0.0);
    try std.testing.expect(strider.shiver_offset != 0.0);
    try std.testing.expect(@abs(strider.shiver_offset) <= 0.05);
}

test "13. Movement Penalty: Freezing state slows down by 70% to sluggish 1.25 m/s" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.updateThermalState(.{ .block_at_feet = .basalt });
    try std.testing.expectEqual(STRIDER_LAND_SPEED, strider.getMovementSpeed());
    try std.testing.expectEqual(@as(f32, 1.25), strider.getMovementSpeed());

    // Verify 70% reduction relative to lava speed (4.17 * 0.30 = 1.251 ~ 1.25)
    const ratio = strider.getMovementSpeed() / STRIDER_LAVA_SPEED;
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), ratio, 0.01);
}

test "14. Thermal State Transitions: Stepping from lava onto land switches to freezing" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.tick(1, .{ .block_at_feet = .lava_source });
    try std.testing.expectEqual(ThermalState.warm, strider.thermal_state);
    try std.testing.expect(!strider.is_shivering);

    // Step onto blackstone land
    strider.tick(1, .{ .block_at_feet = .blackstone });
    try std.testing.expectEqual(ThermalState.freezing, strider.thermal_state);
    try std.testing.expect(strider.is_shivering);
    try std.testing.expect(strider.skin_color.eql(COLD_SHIVERING_PURPLE));
    try std.testing.expectEqual(@as(f32, 1.25), strider.getMovementSpeed());
}

test "15. Thermal State Transitions: Stepping from land into lava switches back to warm" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.tick(1, .{ .block_at_feet = .solid_ground });
    try std.testing.expectEqual(ThermalState.freezing, strider.thermal_state);

    // Step back into lava
    strider.tick(1, .{ .block_at_feet = .lava_source });
    try std.testing.expectEqual(ThermalState.warm, strider.thermal_state);
    try std.testing.expect(!strider.is_shivering);
    try std.testing.expect(strider.skin_color.eql(VIBRANT_WARM_RED));
    try std.testing.expectEqual(@as(f32, 4.17), strider.getMovementSpeed());
}

test "16. Water Hazard: Submerged in water source takes 4.0 HP damage per second" {
    var strider = Strider.init(1, Vec3.zero, false);
    const env = StriderEnvironment{ .block_at_feet = .water_source };

    // 1.0 second = 20 game ticks
    strider.tick(20, env);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), strider.health, 0.01);
    try std.testing.expectEqual(ParticleEvent.water_splash, strider.last_particle.?);
}

test "17. Water Hazard: Submerged in flowing water takes 4.0 HP damage per second" {
    var strider = Strider.init(1, Vec3.zero, false);
    const env = StriderEnvironment{ .block_at_feet = .flowing_water };

    strider.tick(20, env);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), strider.health, 0.01);
}

test "18. Water Hazard: Standing in rain takes 4.0 HP damage per second" {
    var strider = Strider.init(1, Vec3.zero, false);
    const env = StriderEnvironment{
        .block_at_feet = .solid_ground,
        .is_raining = true,
    };

    strider.tick(20, env);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), strider.health, 0.01);
}

test "19. Water Hazard: Single tick damage deals exactly 0.2 HP (4.0 HP / 20 TPS)" {
    var strider = Strider.init(1, Vec3.zero, false);
    const env = StriderEnvironment{ .block_at_feet = .water_source };

    strider.tick(1, env);
    try std.testing.expectApproxEqAbs(@as(f32, 19.80), strider.health, 0.001);
}

test "20. Water Hazard: Continuous 5 seconds of water contact is fatal (takes 20 HP damage)" {
    var strider = Strider.init(1, Vec3.zero, false);
    const env = StriderEnvironment{ .block_at_feet = .water_source };

    // 5 seconds = 100 ticks
    strider.tick(100, env);
    try std.testing.expectEqual(@as(f32, 0.0), strider.health);
    try std.testing.expect(!strider.is_alive);
    try std.testing.expectEqual(SoundEvent.strider_death, strider.last_sound.?);
}

test "21. Saddle Equipping: Right-clicking unsaddled adult with Saddle equips saddle" {
    var strider = Strider.init(1, Vec3.zero, false);
    var saddle_stack = ItemStack.init(.saddle, 1);

    try std.testing.expect(!strider.is_saddled);
    const res = strider.interact(100, &saddle_stack);
    try std.testing.expectEqual(InteractionResult.saddled, res);
    try std.testing.expect(strider.is_saddled);
    try std.testing.expectEqual(@as(u16, 0), saddle_stack.count);
    try std.testing.expectEqual(SoundEvent.strider_saddle, strider.last_sound.?);
}

test "22. Saddle Equipping: Cannot equip saddle on baby Strider" {
    var baby = Strider.init(1, Vec3.zero, true);
    var saddle_stack = ItemStack.init(.saddle, 1);

    const ok = baby.equipSaddle(&saddle_stack);
    try std.testing.expect(!ok);
    try std.testing.expect(!baby.is_saddled);
    try std.testing.expectEqual(@as(u16, 1), saddle_stack.count);
}

test "23. Saddle Equipping: Cannot equip saddle if already saddled" {
    var strider = Strider.init(1, Vec3.zero, false);
    var saddle1 = ItemStack.init(.saddle, 1);
    var saddle2 = ItemStack.init(.saddle, 1);

    try std.testing.expect(strider.equipSaddle(&saddle1));
    try std.testing.expect(!strider.equipSaddle(&saddle2));
    try std.testing.expectEqual(@as(u16, 1), saddle2.count);
}

test "24. Player Mounting: Right-clicking saddled Strider mounts the player" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;

    try std.testing.expect(!strider.is_mounted);
    const res = strider.interact(555, null);
    try std.testing.expectEqual(InteractionResult.mounted, res);
    try std.testing.expect(strider.is_mounted);
    try std.testing.expectEqual(@as(?u64, 555), strider.rider_id);
}

test "25. Player Mounting: Cannot mount unsaddled Strider" {
    var strider = Strider.init(1, Vec3.zero, false);
    try std.testing.expect(!strider.is_saddled);

    const mounted = strider.mount(555);
    try std.testing.expect(!mounted);
    try std.testing.expect(!strider.is_mounted);
    try std.testing.expectEqual(@as(?u64, null), strider.rider_id);
}

test "26. Player Mounting: Cannot mount when already occupied by another rider" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;

    try std.testing.expect(strider.mount(101));
    // Second player attempts mounting
    try std.testing.expect(!strider.mount(102));
    try std.testing.expectEqual(@as(?u64, 101), strider.rider_id);
}

test "27. Player Dismounting: Right-clicking while mounted dismounts rider" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;
    _ = strider.mount(555);

    try std.testing.expect(strider.is_mounted);
    const res = strider.interact(555, null);
    try std.testing.expectEqual(InteractionResult.dismounted, res);
    try std.testing.expect(!strider.is_mounted);
    try std.testing.expectEqual(@as(?u64, null), strider.rider_id);
}

test "28. Warped Fungus on a Stick: Crafting 1 Fishing Rod + 1 Warped Fungus yields 100 durability" {
    const rod = ItemStack.init(.fishing_rod, 1);
    const fungus = ItemStack.init(.warped_fungus, 1);

    const crafted = craftWarpedFungusOnAStick(rod, fungus);
    try std.testing.expect(crafted != null);
    try std.testing.expectEqual(ItemType.warped_fungus_on_a_stick, crafted.?.item_type);
    try std.testing.expectEqual(@as(u16, 1), crafted.?.count);
    try std.testing.expectEqual(WARPED_FUNGUS_STICK_MAX_DURABILITY, crafted.?.durability);
    try std.testing.expectEqual(WARPED_FUNGUS_STICK_MAX_DURABILITY, crafted.?.max_durability);
}

test "29. Warped Fungus on a Stick: Non-matching recipe items fail crafting" {
    const dirt = ItemStack.init(.dirt, 1);
    const fungus = ItemStack.init(.warped_fungus, 1);

    const crafted = craftWarpedFungusOnAStick(dirt, fungus);
    try std.testing.expectEqual(@as(?ItemStack, null), crafted);
}

test "30. Steering: Strider steers toward camera look direction when holding Warped Fungus on a Stick" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;
    _ = strider.mount(555);
    strider.updateThermalState(.{ .block_at_feet = .lava_source });

    // Camera pointing positive X
    const look_vec = Vec3.init(1.0, 0.0, 0.0);
    const steered = strider.steer(look_vec, true);
    try std.testing.expect(steered);

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), strider.facing_direction.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), strider.facing_direction.z, 0.001);
    try std.testing.expectApproxEqAbs(STRIDER_LAVA_SPEED, strider.velocity.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), strider.velocity.z, 0.001);
}

test "31. Steering: Yaw angle updates to match camera look heading" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;
    _ = strider.mount(555);

    // Look pointing positive Z
    _ = strider.steer(Vec3.init(0.0, 0.0, 1.0), true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), strider.yaw, 0.01);

    // Look pointing positive X
    _ = strider.steer(Vec3.init(1.0, 0.0, 0.0), true);
    try std.testing.expectApproxEqAbs(std.math.pi / 2.0, strider.yaw, 0.01);
}

test "32. Steering: Pitch angle in camera vector is projected onto horizontal plane" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;
    _ = strider.mount(555);
    strider.updateThermalState(.{ .block_at_feet = .lava_source });

    // Look vector angled 45 degrees downward
    const pitched_look = Vec3.init(0.0, -1.0, 1.0);
    _ = strider.steer(pitched_look, true);

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), strider.velocity.y, 0.001);
    try std.testing.expectApproxEqAbs(STRIDER_LAVA_SPEED, strider.velocity.z, 0.001);
}

test "33. Steering Rejection: Strider does not steer when not holding Warped Fungus on a Stick" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;
    _ = strider.mount(555);

    const steered = strider.steer(Vec3.init(1.0, 0.0, 0.0), false);
    try std.testing.expect(!steered);
    try std.testing.expectEqual(@as(f32, 0.0), strider.velocity.x);
    try std.testing.expectEqual(@as(f32, 0.0), strider.velocity.z);
}

test "34. Speed Boost: Right-click applies temporary speed surge (+100% boost: 8.34 m/s sprint on lava)" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;
    _ = strider.mount(555);
    strider.updateThermalState(.{ .block_at_feet = .lava_source });

    var stick = ItemStack.init(.warped_fungus_on_a_stick, 1);
    const boosted = strider.boostSpeed(&stick);
    try std.testing.expect(boosted);
    try std.testing.expect(strider.is_boosting);
    try std.testing.expectEqual(BOOST_DURATION_TICKS, strider.boost_ticks_remaining);
    try std.testing.expectEqual(STRIDER_BOOST_SPEED_LAVA, strider.getMovementSpeed());
    try std.testing.expectEqual(@as(f32, 8.34), strider.getMovementSpeed());
    try std.testing.expectEqual(SoundEvent.strider_boost, strider.last_sound.?);
    try std.testing.expectEqual(ParticleEvent.boost_smoke, strider.last_particle.?);
}

test "35. Speed Boost: Boost duration lasts exactly 200 game ticks (10.0 seconds)" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;
    _ = strider.mount(555);
    strider.updateThermalState(.{ .block_at_feet = .lava_source });

    var stick = ItemStack.init(.warped_fungus_on_a_stick, 1);
    _ = strider.boostSpeed(&stick);

    const env = StriderEnvironment{ .block_at_feet = .lava_source };
    // Tick 100 ticks (5.0s)
    strider.tick(100, env);
    try std.testing.expect(strider.is_boosting);
    try std.testing.expectEqual(@as(u32, 100), strider.boost_ticks_remaining);
    try std.testing.expectEqual(@as(f32, 8.34), strider.getMovementSpeed());

    // Tick 99 ticks (total 199 ticks)
    strider.tick(99, env);
    try std.testing.expect(strider.is_boosting);
    try std.testing.expectEqual(@as(u32, 1), strider.boost_ticks_remaining);

    // Final 200th tick
    strider.tick(1, env);
    try std.testing.expect(!strider.is_boosting);
    try std.testing.expectEqual(@as(u32, 0), strider.boost_ticks_remaining);
    try std.testing.expectEqual(STRIDER_LAVA_SPEED, strider.getMovementSpeed());
    try std.testing.expectEqual(@as(f32, 4.17), strider.getMovementSpeed());
}

test "36. Speed Boost: Durability is consumed by 1 point per boost activation" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;
    _ = strider.mount(555);

    var stick = ItemStack.init(.warped_fungus_on_a_stick, 1);
    try std.testing.expectEqual(@as(u16, 100), stick.durability);

    _ = strider.boostSpeed(&stick);
    try std.testing.expectEqual(@as(u16, 99), stick.durability);

    _ = strider.boostSpeed(&stick);
    try std.testing.expectEqual(@as(u16, 98), stick.durability);
}

test "37. Durability Depletion: At 0 durability, Warped Fungus on a Stick reverts to ordinary Fishing Rod" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.is_saddled = true;
    _ = strider.mount(555);

    var stick = ItemStack.init(.warped_fungus_on_a_stick, 1);
    stick.durability = 1; // 1 boost left

    const boosted = strider.boostSpeed(&stick);
    try std.testing.expect(boosted);
    // Depleted: item reverted to fishing rod!
    try std.testing.expectEqual(ItemType.fishing_rod, stick.item_type);
    try std.testing.expectEqual(FISHING_ROD_MAX_DURABILITY, stick.durability);
    try std.testing.expectEqual(FISHING_ROD_MAX_DURABILITY, stick.max_durability);

    // Further attempts to boost with reverted rod fail
    const boosted_again = strider.boostSpeed(&stick);
    try std.testing.expect(!boosted_again);
}

test "38. Breeding: Feeding Warped Fungus triggers Love Mode" {
    var strider = Strider.init(1, Vec3.zero, false);
    var fungus = ItemStack.init(.warped_fungus, 2);

    try std.testing.expect(!strider.in_love);
    const fed = strider.feedWarpedFungus(&fungus);
    try std.testing.expect(fed);
    try std.testing.expect(strider.in_love);
    try std.testing.expectEqual(LOVE_MODE_DURATION_TICKS, strider.love_ticks);
    try std.testing.expectEqual(@as(u16, 1), fungus.count);
    try std.testing.expectEqual(SoundEvent.strider_eat, strider.last_sound.?);
    try std.testing.expectEqual(ParticleEvent.heart_love, strider.last_particle.?);
}

test "39. Breeding: Two adult Striders in Love Mode breed a Baby Strider" {
    var parent1 = Strider.init(10, Vec3.init(0.0, 64.0, 0.0), false);
    var parent2 = Strider.init(20, Vec3.init(2.0, 64.0, 0.0), false);

    var fungus = ItemStack.init(.warped_fungus, 2);
    _ = parent1.feedWarpedFungus(&fungus);
    _ = parent2.feedWarpedFungus(&fungus);

    try std.testing.expect(parent1.in_love);
    try std.testing.expect(parent2.in_love);

    const maybe_baby = breed(&parent1, &parent2, 30);
    try std.testing.expect(maybe_baby != null);
    const baby = maybe_baby.?;

    try std.testing.expect(baby.is_baby);
    try std.testing.expectEqual(@as(u64, 30), baby.id);
    try std.testing.expectEqual(@as(f32, 1.0), baby.position.x); // Midpoint between 0.0 and 2.0
    try std.testing.expectEqual(@as(f32, 64.0), baby.position.y);
    try std.testing.expectEqual(@as(f32, 0.5), baby.scale);

    // Parents love mode reset and placed on 5-minute cooldown
    try std.testing.expect(!parent1.in_love);
    try std.testing.expect(!parent2.in_love);
    try std.testing.expectEqual(BREEDING_COOLDOWN_TICKS, parent1.breeding_cooldown_ticks);
    try std.testing.expectEqual(BREEDING_COOLDOWN_TICKS, parent2.breeding_cooldown_ticks);
}

test "40. Breeding Rejection: Strider on breeding cooldown rejects love mode" {
    var strider = Strider.init(1, Vec3.zero, false);
    strider.breeding_cooldown_ticks = 1000;

    var fungus = ItemStack.init(.warped_fungus, 1);
    const fed = strider.feedWarpedFungus(&fungus);
    try std.testing.expect(!fed);
    try std.testing.expect(!strider.in_love);
    try std.testing.expectEqual(@as(u16, 1), fungus.count);
}

test "41. Baby Growth: Feeding Warped Fungus accelerates growth by 2400 ticks (10%)" {
    var baby = Strider.init(2, Vec3.zero, true);
    try std.testing.expectEqual(BABY_GROWTH_TICKS, baby.growth_ticks_remaining);

    var fungus = ItemStack.init(.warped_fungus, 1);
    const fed = baby.feedWarpedFungus(&fungus);
    try std.testing.expect(fed);
    try std.testing.expectEqual(BABY_GROWTH_TICKS - BABY_GROWTH_FEED_REDUCTION_TICKS, baby.growth_ticks_remaining);
    try std.testing.expect(baby.scale > 0.5);
}

test "42. Baby Maturation: Completing growth timer matures baby into adult Strider" {
    var baby = Strider.init(2, Vec3.zero, true);
    baby.growth_ticks_remaining = 10;

    baby.tick(10, .{ .block_at_feet = .lava_source });
    try std.testing.expect(!baby.is_baby);
    try std.testing.expectEqual(@as(f32, 1.0), baby.scale);
    try std.testing.expectEqual(STRIDER_MAX_HEALTH, baby.max_health);
    try std.testing.expectEqual(STRIDER_MAX_HEALTH, baby.health);
}

test "43. Baby Piggyback: Baby can mount adult Strider and follow parent position" {
    const adult = Strider.init(1, Vec3.init(10.0, 32.0, 10.0), false);
    var baby = Strider.init(2, Vec3.zero, true);

    try std.testing.expect(baby.mountPiggyback(adult.id));
    try std.testing.expect(baby.is_piggyback);
    try std.testing.expectEqual(@as(?u64, 1), baby.piggyback_parent_id);

    baby.updatePiggybackPosition(adult.position);
    try std.testing.expectEqual(@as(f32, 10.0), baby.position.x);
    try std.testing.expectEqual(@as(f32, 32.0 + BABY_PIGGYBACK_Y_OFFSET), baby.position.y);
    try std.testing.expectEqual(@as(f32, 10.0), baby.position.z);
}

test "44. Healing: Feeding Warped Fungus restores 2.0 HP to injured adult Strider" {
    var strider = Strider.init(1, Vec3.zero, false);
    _ = strider.takeDamage(8.0, .generic);
    try std.testing.expectEqual(@as(f32, 12.0), strider.health);

    var fungus = ItemStack.init(.warped_fungus, 1);
    const fed = strider.feedWarpedFungus(&fungus);
    try std.testing.expect(fed);
    try std.testing.expectEqual(@as(f32, 14.0), strider.health);
}

test "45. Simulation World: Spawns, ticks, and manages multiple Striders" {
    var sim = StriderLavaMountSimulation.init(std.testing.allocator);
    defer sim.deinit();

    const s1 = try sim.spawnStrider(Vec3.init(0.0, 32.0, 0.0), false);
    const s2 = try sim.spawnStrider(Vec3.init(10.0, 32.0, 0.0), true);

    try std.testing.expectEqual(@as(usize, 2), sim.striders.items.len);
    try std.testing.expectEqual(@as(u64, 1), s1.id);
    try std.testing.expectEqual(@as(u64, 2), s2.id);

    sim.tick(1, .{ .block_at_feet = .lava_source });
    try std.testing.expectEqual(ThermalState.warm, sim.striders.items[0].thermal_state);
    try std.testing.expectEqual(ThermalState.warm, sim.striders.items[1].thermal_state);
}
