const std = @import("std");

// ============================================================================
// Milestone 477: Skeleton Trap Lightning Summoning & Four Horsemen Combat
// ============================================================================
// Core mechanics:
// 1. Skeleton Trap Horse Spawn & Triggering:
//    - Spawn conditions: Natural lightning strike during thunderstorm (0.75% to 7.5%
//      probability scaled by regional difficulty).
//    - Trap horse entity: Appears as a peaceful passive Skeleton Horse wandering in
//      a thunderstorm.
//    - Proximity Trigger: When any player approaches within 10.0 meters Euclidean
//      distance (TRIGGER_DISTANCE = 10.0):
//      * Triggers cosmetic lightning strike at horse's exact position (without
//        inflicting damage to horse or player).
//      * Instantly transforms the single trap horse into 4 mounted Skeleton Horsemen
//        (TheFourHorsemen).
// 2. Four Horsemen Entity Attributes:
//    - 4 Skeleton Riders mounted on 4 Skeleton Horses ([4]SkeletonHorseman).
//    - Skeleton Riders:
//      * Health: 20.0 HP.
//      * Equipment: Equipped with Enchanted Iron Helmet (prevents sunlight burn
//        damage!) and Enchanted Bow.
//      * Damage immunity: 3.0 seconds (60 ticks) damage immunity window upon initial
//        summoning.
//    - Skeleton Horses:
//      * Health: 53.0 HP (standard skeleton horse high health).
//      * Movement speed: fast sprint (up to 12.0 m/s), jumping capability up to 3.5m.
//      * Despawn timer: 15.0 minutes (18,000 ticks) if not engaged in combat by a player.
// 3. Mounted Combat Kinematics:
//    - Mounted archer AI: Circles player target at 8.0–16.0m standoff distance while
//      firing arrows.
//    - Separate entity destruction: Killing horse dismounts rider to fight on foot;
//      killing rider leaves tameable rideable skeleton horse for player!
// ============================================================================

// ============================================================================
// Constants
// ============================================================================

/// Proximity trigger radius in meters Euclidean distance (10.0m).
pub const TRIGGER_DISTANCE: f32 = 10.0;
pub const TRIGGER_DISTANCE_SQ: f32 = TRIGGER_DISTANCE * TRIGGER_DISTANCE;

/// Minimum spawn probability for skeleton trap from lightning strike (0.75%).
pub const MIN_SPAWN_PROBABILITY: f32 = 0.0075;

/// Maximum spawn probability for skeleton trap on max regional difficulty (7.5%).
pub const MAX_SPAWN_PROBABILITY: f32 = 0.075;

/// Damage immunity window for summoned skeleton riders in game ticks (60 ticks = 3.0s).
pub const SUMMON_INVULNERABILITY_TICKS: u32 = 60;
pub const SUMMON_INVULNERABILITY_SECONDS: f32 = 3.0;

/// Despawn countdown duration for skeleton trap horse and unengaged horsemen (18,000 ticks = 15.0 minutes).
pub const DESPAWN_TIMER_TICKS: u32 = 18_000;
pub const DESPAWN_TIMER_SECONDS: f32 = 900.0;

/// Base max health of Skeleton Rider entity (20.0 HP).
pub const SKELETON_RIDER_HEALTH: f32 = 20.0;

/// High max health of Skeleton Horse entity (53.0 HP).
pub const SKELETON_HORSE_HEALTH: f32 = 53.0;

/// Fast sprint maximum movement speed for Skeleton Horse (12.0 m/s).
pub const SKELETON_HORSE_MAX_SPEED: f32 = 12.0;

/// Jumping capability maximum height for Skeleton Horse (3.5 meters).
pub const SKELETON_HORSE_JUMP_HEIGHT: f32 = 3.5;

/// Standard unmounted pedestrian skeleton movement speed on foot (2.4 m/s).
pub const SKELETON_FOOT_SPEED: f32 = 2.4;

/// Minimum standoff distance for mounted archer AI (8.0m).
pub const MIN_STANDOFF_DISTANCE: f32 = 8.0;

/// Maximum standoff distance for mounted archer AI (16.0m).
pub const MAX_STANDOFF_DISTANCE: f32 = 16.0;

/// Total number of mounted horsemen summoned during transformation (4).
pub const HORSEMEN_COUNT: usize = 4;

/// Engine ticks per second.
pub const TICKS_PER_SECOND: u32 = 20;

/// Arrow firing cooldown in ticks between shots for mounted archers (30 ticks = 1.5s).
pub const DEFAULT_BOW_COOLDOWN_TICKS: u32 = 30;

/// Base damage of skeleton arrow (4.0 HP).
pub const ARROW_BASE_DAMAGE: f32 = 4.0;

/// Bonus damage dealt by enchanted bow Power enchantment (+2.0 HP).
pub const ARROW_ENCHANTED_BONUS: f32 = 2.0;

/// Arrow flight speed in m/s (25.0 m/s).
pub const ARROW_SPEED: f32 = 25.0;

/// Maximum arrow shooting range (24.0m).
pub const ARROW_MAX_RANGE: f32 = 24.0;

/// Standard iron helmet durability points (165 points).
pub const IRON_HELMET_MAX_DURABILITY: u16 = 165;

// ============================================================================
// 3D Vector Math
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

    pub fn distanceSq(a: Vec3, b: Vec3) f32 {
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const dz = a.z - b.z;
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn distance(a: Vec3, b: Vec3) f32 {
        return @sqrt(distanceSq(a, b));
    }

    pub fn horizontalDistanceSq(a: Vec3, b: Vec3) f32 {
        const dx = a.x - b.x;
        const dz = a.z - b.z;
        return dx * dx + dz * dz;
    }

    pub fn horizontalDistance(a: Vec3, b: Vec3) f32 {
        return @sqrt(horizontalDistanceSq(a, b));
    }

    pub fn normalize(v: Vec3) Vec3 {
        const l = v.length();
        if (l < 1e-6) return Vec3.zero;
        const inv = 1.0 / l;
        return .{ .x = v.x * inv, .y = v.y * inv, .z = v.z * inv };
    }
};

// ============================================================================
// Spawning Probability & Weather
// ============================================================================

/// Calculates the skeleton trap spawn chance based on clamped regional difficulty [0.0, 1.0].
/// Yields 0.75% at 0.0 and 7.5% at 1.0.
pub fn calculateTrapSpawnChance(clamped_regional_difficulty: f32) f32 {
    const clamped = std.math.clamp(clamped_regional_difficulty, 0.0, 1.0);
    return MIN_SPAWN_PROBABILITY + (MAX_SPAWN_PROBABILITY - MIN_SPAWN_PROBABILITY) * clamped;
}

/// Evaluates if a skeleton trap horse should spawn upon natural lightning strike.
/// Requires an active thunderstorm and a roll strictly less than the regional difficulty chance.
pub fn shouldSpawnSkeletonTrap(
    is_thunderstorm: bool,
    roll_0_to_1: f32,
    clamped_regional_difficulty: f32,
) bool {
    if (!is_thunderstorm) return false;
    const chance = calculateTrapSpawnChance(clamped_regional_difficulty);
    return roll_0_to_1 < chance;
}

// ============================================================================
// Cosmetic Lightning Strike
// ============================================================================

/// Cosmetic lightning strike spawned during skeleton trap transformation.
/// Pure visual/audio effect that inflicts 0 damage to horse and player.
pub const CosmeticLightningStrike = struct {
    pos: Vec3,
    inflicts_damage: bool = false,
    damage_amount: f32 = 0.0,
    is_cosmetic: bool = true,

    pub fn init(pos: Vec3) CosmeticLightningStrike {
        return .{
            .pos = pos,
            .inflicts_damage = false,
            .damage_amount = 0.0,
            .is_cosmetic = true,
        };
    }

    /// Evaluates impact of cosmetic lightning. Verifies that 0 damage is dealt.
    pub fn applyStrike(self: CosmeticLightningStrike, horse_hp: *f32, player_hp: *f32) void {
        _ = self;
        _ = horse_hp;
        _ = player_hp;
    }
};

// ============================================================================
// Entity States: Trap Horse, Rider, Horse & Horseman
// ============================================================================

pub const DamageResult = struct {
    damage_dealt: f32,
    absorbed: bool,
    killed: bool,
};

pub const DaylightBurnResult = struct {
    burns: bool,
    durability_lost: u16,
    helmet_broken: bool,
};

pub const CombatKinematicsState = enum {
    idle,
    closing_in, // dist > 16.0m: closing distance
    retreating, // dist < 8.0m: kiting away
    circling, // 8.0m <= dist <= 16.0m: orbiting player
    on_foot, // horse defeated, fighting on foot
    pacified, // rider defeated, horse is tameable
};

pub const ArrowShot = struct {
    origin: Vec3,
    target: Vec3,
    velocity: Vec3,
    damage: f32,
    enchanted: bool,
};

/// Peaceful passive Skeleton Horse wandering in a thunderstorm before player proximity trigger.
pub const SkeletonTrapHorse = struct {
    id: u32 = 1,
    pos: Vec3,
    vel: Vec3 = Vec3.zero,
    health: f32 = SKELETON_HORSE_HEALTH,
    is_trap: bool = true,
    triggered: bool = false,
    despawn_ticks: u32 = DESPAWN_TIMER_TICKS,
    despawned: bool = false,
    is_peaceful: bool = true,

    pub fn init(pos: Vec3) SkeletonTrapHorse {
        return .{
            .id = 1,
            .pos = pos,
            .health = SKELETON_HORSE_HEALTH,
            .is_trap = true,
            .triggered = false,
            .despawn_ticks = DESPAWN_TIMER_TICKS,
            .despawned = false,
            .is_peaceful = true,
        };
    }

    pub fn tickTicks(self: *SkeletonTrapHorse, ticks: u32) void {
        if (self.triggered or self.despawned) return;
        if (self.despawn_ticks <= ticks) {
            self.despawn_ticks = 0;
            self.despawned = true;
        } else {
            self.despawn_ticks -= ticks;
        }
    }

    /// Checks proximity of a player. If within TRIGGER_DISTANCE (10.0m),
    /// fires cosmetic lightning and transforms into TheFourHorsemen.
    pub fn checkProximityTrigger(self: *SkeletonTrapHorse, player_pos: Vec3) ?TrapTriggerResult {
        if (self.triggered or self.despawned) return null;
        const dist_sq = Vec3.distanceSq(self.pos, player_pos);
        if (dist_sq <= TRIGGER_DISTANCE_SQ) {
            self.triggered = true;
            self.is_peaceful = false;
            const strike = CosmeticLightningStrike.init(self.pos);
            const horsemen = TheFourHorsemen.spawnAt(self.pos);
            return TrapTriggerResult{
                .lightning = strike,
                .horsemen = horsemen,
                .horse_damaged = false,
                .player_damaged = false,
            };
        }
        return null;
    }
};

/// Skeleton Rider entity with enchanted iron helmet, enchanted bow, and summon invulnerability.
pub const SkeletonRider = struct {
    id: u32,
    pos: Vec3,
    health: f32 = SKELETON_RIDER_HEALTH,
    max_health: f32 = SKELETON_RIDER_HEALTH,
    is_alive: bool = true,
    has_iron_helmet: bool = true,
    helmet_enchanted: bool = true,
    helmet_durability: u16 = IRON_HELMET_MAX_DURABILITY,
    has_enchanted_bow: bool = true,
    bow_cooldown_ticks: u32 = 0,
    damage_immunity_ticks: u32 = SUMMON_INVULNERABILITY_TICKS,

    pub fn init(id: u32, pos: Vec3) SkeletonRider {
        return .{
            .id = id,
            .pos = pos,
            .health = SKELETON_RIDER_HEALTH,
            .max_health = SKELETON_RIDER_HEALTH,
            .is_alive = true,
            .has_iron_helmet = true,
            .helmet_enchanted = true,
            .helmet_durability = IRON_HELMET_MAX_DURABILITY,
            .has_enchanted_bow = true,
            .bow_cooldown_ticks = 0,
            .damage_immunity_ticks = SUMMON_INVULNERABILITY_TICKS,
        };
    }

    pub fn isDamageImmune(self: SkeletonRider) bool {
        return self.damage_immunity_ticks > 0;
    }

    pub fn tickImmunity(self: *SkeletonRider, ticks: u32) void {
        self.damage_immunity_ticks -|= ticks;
    }

    pub fn takeDamage(self: *SkeletonRider, amount: f32) DamageResult {
        if (!self.is_alive) return .{ .damage_dealt = 0.0, .absorbed = false, .killed = false };
        if (self.isDamageImmune()) {
            return .{
                .damage_dealt = 0.0,
                .absorbed = true,
                .killed = false,
            };
        }
        const dealt = @min(self.health, @max(0.0, amount));
        self.health -= dealt;
        if (self.health <= 0.0) {
            self.health = 0.0;
            self.is_alive = false;
            return .{ .damage_dealt = dealt, .absorbed = false, .killed = true };
        }
        return .{ .damage_dealt = dealt, .absorbed = false, .killed = false };
    }

    /// Evaluates sunlight fire damage. Iron helmet completely prevents daytime fire.
    /// Sunlight slowly wears helmet durability; if broken, skeleton starts burning.
    pub fn evaluateDaylightBurn(self: *SkeletonRider, is_daylight: bool, open_sky: bool) DaylightBurnResult {
        if (!self.is_alive) return .{ .burns = false, .durability_lost = 0, .helmet_broken = false };
        if (!is_daylight or !open_sky) {
            return .{ .burns = false, .durability_lost = 0, .helmet_broken = false };
        }
        if (self.has_iron_helmet and self.helmet_durability > 0) {
            self.helmet_durability -|= 1;
            var broken = false;
            if (self.helmet_durability == 0) {
                self.has_iron_helmet = false;
                broken = true;
            }
            return .{
                .burns = false,
                .durability_lost = 1,
                .helmet_broken = broken,
            };
        }
        return .{
            .burns = true,
            .durability_lost = 0,
            .helmet_broken = false,
        };
    }
};

/// Skeleton Horse entity with 53 HP, fast sprint, 3.5m jump, and despawn timer.
/// Becomes tameable and rideable for players once its rider is killed.
pub const SkeletonHorse = struct {
    id: u32,
    pos: Vec3,
    vel: Vec3 = Vec3.zero,
    health: f32 = SKELETON_HORSE_HEALTH,
    max_health: f32 = SKELETON_HORSE_HEALTH,
    is_alive: bool = true,
    max_speed: f32 = SKELETON_HORSE_MAX_SPEED,
    jump_height: f32 = SKELETON_HORSE_JUMP_HEIGHT,
    despawn_ticks: u32 = DESPAWN_TIMER_TICKS,
    despawned: bool = false,
    engaged_in_combat: bool = false,
    is_tameable: bool = false,
    is_tamed: bool = false,
    is_rideable: bool = false,
    has_player_passenger: bool = false,
    passenger_id: ?u32 = null,
    is_underwater_breathable: bool = true,

    pub fn init(id: u32, pos: Vec3) SkeletonHorse {
        return .{
            .id = id,
            .pos = pos,
            .health = SKELETON_HORSE_HEALTH,
            .max_health = SKELETON_HORSE_HEALTH,
            .is_alive = true,
            .max_speed = SKELETON_HORSE_MAX_SPEED,
            .jump_height = SKELETON_HORSE_JUMP_HEIGHT,
            .despawn_ticks = DESPAWN_TIMER_TICKS,
            .despawned = false,
            .engaged_in_combat = false,
            .is_tameable = false,
            .is_tamed = false,
            .is_rideable = false,
            .has_player_passenger = false,
            .passenger_id = null,
            .is_underwater_breathable = true,
        };
    }

    pub fn tickDespawn(self: *SkeletonHorse, ticks: u32) void {
        if (self.despawned or !self.is_alive) return;
        if (!self.engaged_in_combat) {
            if (self.despawn_ticks <= ticks) {
                self.despawn_ticks = 0;
                self.despawned = true;
            } else {
                self.despawn_ticks -= ticks;
            }
        }
    }

    pub fn setEngagedInCombat(self: *SkeletonHorse, engaged: bool) void {
        self.engaged_in_combat = engaged;
    }

    pub fn takeDamage(self: *SkeletonHorse, amount: f32) DamageResult {
        if (!self.is_alive or self.despawned) return .{ .damage_dealt = 0.0, .absorbed = false, .killed = false };
        const dealt = @min(self.health, @max(0.0, amount));
        self.health -= dealt;
        self.engaged_in_combat = true;
        if (self.health <= 0.0) {
            self.health = 0.0;
            self.is_alive = false;
            return .{ .damage_dealt = dealt, .absorbed = false, .killed = true };
        }
        return .{ .damage_dealt = dealt, .absorbed = false, .killed = false };
    }

    pub fn makeTameableForPlayer(self: *SkeletonHorse) void {
        self.is_tameable = true;
        self.is_tamed = true;
        self.is_rideable = true;
        self.engaged_in_combat = false;
    }

    pub fn mountPlayer(self: *SkeletonHorse, player_id: u32) bool {
        if (!self.is_rideable or !self.is_alive or self.despawned or self.has_player_passenger) {
            return false;
        }
        self.has_player_passenger = true;
        self.passenger_id = player_id;
        return true;
    }

    pub fn dismountPlayer(self: *SkeletonHorse) void {
        self.has_player_passenger = false;
        self.passenger_id = null;
    }
};

/// Combined mounted unit: Skeleton Rider mounted on a Skeleton Horse.
pub const SkeletonHorseman = struct {
    id: u32,
    rider: SkeletonRider,
    horse: SkeletonHorse,
    is_mounted: bool = true,
    circling_direction: f32 = 1.0, // +1.0 for clockwise, -1.0 for counter-clockwise
    state: CombatKinematicsState = .idle,

    pub fn init(id: u32, pos: Vec3, circling_dir: f32) SkeletonHorseman {
        return .{
            .id = id,
            .rider = SkeletonRider.init(id, pos),
            .horse = SkeletonHorse.init(id, pos),
            .is_mounted = true,
            .circling_direction = circling_dir,
            .state = .idle,
        };
    }

    pub fn getEffectivePosition(self: SkeletonHorseman) Vec3 {
        return if (self.is_mounted) self.horse.pos else self.rider.pos;
    }

    /// Damage the horse directly. If horse dies, rider dismounts to fight on foot.
    pub fn damageHorse(self: *SkeletonHorseman, amount: f32) DamageResult {
        if (!self.horse.is_alive) return .{ .damage_dealt = 0.0, .absorbed = false, .killed = false };
        const res = self.horse.takeDamage(amount);
        if (res.killed) {
            self.is_mounted = false;
            self.rider.pos = self.horse.pos;
            if (self.rider.is_alive) {
                self.state = .on_foot;
            }
        }
        return res;
    }

    /// Damage the rider directly. If rider dies, horse becomes tameable and rideable for player.
    pub fn damageRider(self: *SkeletonHorseman, amount: f32) DamageResult {
        if (!self.rider.is_alive) return .{ .damage_dealt = 0.0, .absorbed = false, .killed = false };
        const res = self.rider.takeDamage(amount);
        if (res.killed) {
            self.is_mounted = false;
            if (self.horse.is_alive) {
                self.horse.makeTameableForPlayer();
                self.state = .pacified;
            }
        }
        return res;
    }

    pub fn tick(self: *SkeletonHorseman, ticks: u32) void {
        self.rider.tickImmunity(ticks);
        self.horse.tickDespawn(ticks);
        self.rider.bow_cooldown_ticks -|= ticks;
    }

    /// Updates mounted archer kinematics AI and bow firing.
    pub fn updateAI(self: *SkeletonHorseman, player_pos: Vec3, dt: f32) ?ArrowShot {
        if (!self.rider.is_alive and !self.horse.is_alive) return null;
        if (!self.rider.is_alive) {
            self.state = .pacified;
            return null;
        }

        self.horse.engaged_in_combat = true;

        if (self.is_mounted and self.horse.is_alive) {
            const dist = Vec3.horizontalDistance(self.horse.pos, player_pos);

            if (dist > MAX_STANDOFF_DISTANCE) {
                // Too far: close distance towards player
                self.state = .closing_in;
                const to_player = Vec3.sub(player_pos, self.horse.pos);
                const horiz_dir = Vec3.normalize(.{ .x = to_player.x, .y = 0.0, .z = to_player.z });
                const move_vec = Vec3.scale(horiz_dir, SKELETON_HORSE_MAX_SPEED * dt);
                self.horse.pos = Vec3.add(self.horse.pos, move_vec);
                self.rider.pos = self.horse.pos;
            } else if (dist < MIN_STANDOFF_DISTANCE) {
                // Too close: retreat / kite away from player
                self.state = .retreating;
                const from_player = Vec3.sub(self.horse.pos, player_pos);
                const horiz_dir = Vec3.normalize(.{ .x = from_player.x, .y = 0.0, .z = from_player.z });
                const move_vec = Vec3.scale(horiz_dir, SKELETON_HORSE_MAX_SPEED * dt);
                self.horse.pos = Vec3.add(self.horse.pos, move_vec);
                self.rider.pos = self.horse.pos;
            } else {
                // Inside standoff window (8.0m - 16.0m): circle player
                self.state = .circling;
                const radial = Vec3.sub(self.horse.pos, player_pos);
                const r_norm = Vec3.normalize(.{ .x = radial.x, .y = 0.0, .z = radial.z });

                // Perpendicular tangent in XZ plane
                const tangent = if (self.circling_direction >= 0.0)
                    Vec3.init(-r_norm.z, 0.0, r_norm.x)
                else
                    Vec3.init(r_norm.z, 0.0, -r_norm.x);

                const move_vec = Vec3.scale(tangent, SKELETON_HORSE_MAX_SPEED * dt);
                self.horse.pos = Vec3.add(self.horse.pos, move_vec);
                self.rider.pos = self.horse.pos;
            }
        } else {
            // Fighting on foot
            self.state = .on_foot;
            const dist = Vec3.horizontalDistance(self.rider.pos, player_pos);
            if (dist > 10.0) {
                const to_player = Vec3.sub(player_pos, self.rider.pos);
                const horiz_dir = Vec3.normalize(.{ .x = to_player.x, .y = 0.0, .z = to_player.z });
                const move_vec = Vec3.scale(horiz_dir, SKELETON_FOOT_SPEED * dt);
                self.rider.pos = Vec3.add(self.rider.pos, move_vec);
            }
        }

        // Bow archery evaluation
        const current_pos = self.getEffectivePosition();
        const dist_to_player = Vec3.distance(current_pos, player_pos);

        if (dist_to_player <= ARROW_MAX_RANGE and self.rider.bow_cooldown_ticks == 0) {
            self.rider.bow_cooldown_ticks = DEFAULT_BOW_COOLDOWN_TICKS;
            const aim_dir = Vec3.normalize(Vec3.sub(player_pos, current_pos));
            const arrow_vel = Vec3.scale(aim_dir, ARROW_SPEED);
            const dmg = ARROW_BASE_DAMAGE + if (self.rider.has_enchanted_bow) ARROW_ENCHANTED_BONUS else 0.0;
            return ArrowShot{
                .origin = current_pos,
                .target = player_pos,
                .velocity = arrow_vel,
                .damage = dmg,
                .enchanted = self.rider.has_enchanted_bow,
            };
        }

        return null;
    }
};

// ============================================================================
// The Four Horsemen Group Encounter
// ============================================================================

pub const TrapTriggerResult = struct {
    lightning: CosmeticLightningStrike,
    horsemen: TheFourHorsemen,
    horse_damaged: bool = false,
    player_damaged: bool = false,
};

/// The collective four horsemen encounter spawned upon trap horse trigger.
pub const TheFourHorsemen = struct {
    horsemen: [HORSEMEN_COUNT]SkeletonHorseman,
    center_pos: Vec3,

    pub fn spawnAt(center: Vec3) TheFourHorsemen {
        const offsets = [_]Vec3{
            Vec3.init(1.5, 0.0, 0.0),
            Vec3.init(-1.5, 0.0, 0.0),
            Vec3.init(0.0, 0.0, 1.5),
            Vec3.init(0.0, 0.0, -1.5),
        };
        const dirs = [_]f32{ 1.0, -1.0, 1.0, -1.0 };
        var arr: [HORSEMEN_COUNT]SkeletonHorseman = undefined;
        for (0..HORSEMEN_COUNT) |i| {
            const p = Vec3.add(center, offsets[i]);
            arr[i] = SkeletonHorseman.init(@intCast(i + 1), p, dirs[i]);
        }
        return .{
            .horsemen = arr,
            .center_pos = center,
        };
    }

    pub fn tick(self: *TheFourHorsemen, ticks: u32) void {
        for (&self.horsemen) |*h| {
            h.tick(ticks);
        }
    }

    pub fn updateAI(self: *TheFourHorsemen, player_pos: Vec3, dt: f32) [HORSEMEN_COUNT]?ArrowShot {
        var shots: [HORSEMEN_COUNT]?ArrowShot = [_]?ArrowShot{null} ** HORSEMEN_COUNT;
        for (&self.horsemen, 0..) |*h, i| {
            shots[i] = h.updateAI(player_pos, dt);
        }
        return shots;
    }

    pub fn aliveRidersCount(self: TheFourHorsemen) usize {
        var count: usize = 0;
        for (self.horsemen) |h| {
            if (h.rider.is_alive) count += 1;
        }
        return count;
    }

    pub fn aliveHorsesCount(self: TheFourHorsemen) usize {
        var count: usize = 0;
        for (self.horsemen) |h| {
            if (h.horse.is_alive) count += 1;
        }
        return count;
    }

    pub fn mountedCount(self: TheFourHorsemen) usize {
        var count: usize = 0;
        for (self.horsemen) |h| {
            if (h.is_mounted and h.rider.is_alive and h.horse.is_alive) count += 1;
        }
        return count;
    }

    pub fn tameableHorsesCount(self: TheFourHorsemen) usize {
        var count: usize = 0;
        for (self.horsemen) |h| {
            if (h.horse.is_alive and h.horse.is_tameable) count += 1;
        }
        return count;
    }
};

// ============================================================================
// Unit Tests (25+ Tests)
// ============================================================================

test "spawn probability scales from 0.75% to 7.5% with regional difficulty" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0075), calculateTrapSpawnChance(0.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.075), calculateTrapSpawnChance(1.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.04125), calculateTrapSpawnChance(0.5), 1e-5);
}

test "spawn probability clamps out-of-range regional difficulty values" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0075), calculateTrapSpawnChance(-0.5), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.075), calculateTrapSpawnChance(2.5), 1e-5);
}

test "spawn evaluation requires an active thunderstorm" {
    try std.testing.expect(!shouldSpawnSkeletonTrap(false, 0.001, 1.0));
    try std.testing.expect(shouldSpawnSkeletonTrap(true, 0.001, 1.0));
    try std.testing.expect(!shouldSpawnSkeletonTrap(true, 0.08, 1.0));
}

test "trap horse initial attributes are peaceful and untriggered" {
    const horse = SkeletonTrapHorse.init(Vec3.init(100.0, 64.0, 200.0));
    try std.testing.expect(horse.is_trap);
    try std.testing.expect(!horse.triggered);
    try std.testing.expect(horse.is_peaceful);
    try std.testing.expectEqual(@as(f32, 53.0), horse.health);
    try std.testing.expectEqual(DESPAWN_TIMER_TICKS, horse.despawn_ticks);
    try std.testing.expect(!horse.despawned);
}

test "proximity trigger activates within 10.0m Euclidean distance" {
    var horse = SkeletonTrapHorse.init(Vec3.init(0.0, 0.0, 0.0));
    const trigger = horse.checkProximityTrigger(Vec3.init(6.0, 0.0, 8.0)); // 6^2 + 8^2 = 100 -> dist = 10.0m
    try std.testing.expect(trigger != null);
    try std.testing.expect(horse.triggered);
    try std.testing.expect(!horse.is_peaceful);
}

test "proximity trigger activates inside 10.0m radius (e.g. 5.0m)" {
    var horse = SkeletonTrapHorse.init(Vec3.init(10.0, 64.0, 10.0));
    const trigger = horse.checkProximityTrigger(Vec3.init(10.0, 64.0, 15.0)); // 5.0m
    try std.testing.expect(trigger != null);
}

test "proximity trigger does not activate beyond 10.0m Euclidean distance" {
    var horse = SkeletonTrapHorse.init(Vec3.init(0.0, 0.0, 0.0));
    const trigger = horse.checkProximityTrigger(Vec3.init(6.0, 0.0, 8.1)); // dist > 10.0m
    try std.testing.expect(trigger == null);
    try std.testing.expect(!horse.triggered);
    try std.testing.expect(horse.is_peaceful);
}

test "proximity trigger only fires once" {
    var horse = SkeletonTrapHorse.init(Vec3.init(0.0, 0.0, 0.0));
    const first = horse.checkProximityTrigger(Vec3.init(1.0, 0.0, 0.0));
    try std.testing.expect(first != null);
    const second = horse.checkProximityTrigger(Vec3.init(1.0, 0.0, 0.0));
    try std.testing.expect(second == null);
}

test "cosmetic lightning strike deals zero damage to horse and player" {
    var horse = SkeletonTrapHorse.init(Vec3.init(50.0, 64.0, 50.0));
    var player_hp: f32 = 20.0;
    const res = horse.checkProximityTrigger(Vec3.init(52.0, 64.0, 50.0)).?;

    try std.testing.expect(res.lightning.is_cosmetic);
    try std.testing.expect(!res.lightning.inflicts_damage);
    try std.testing.expectEqual(@as(f32, 0.0), res.lightning.damage_amount);
    try std.testing.expectEqual(horse.pos.x, res.lightning.pos.x);
    try std.testing.expectEqual(horse.pos.y, res.lightning.pos.y);
    try std.testing.expectEqual(horse.pos.z, res.lightning.pos.z);

    res.lightning.applyStrike(&horse.health, &player_hp);
    try std.testing.expectEqual(@as(f32, 53.0), horse.health);
    try std.testing.expectEqual(@as(f32, 20.0), player_hp);
}

test "transformation spawns exactly 4 mounted skeleton horsemen" {
    var horse = SkeletonTrapHorse.init(Vec3.init(0.0, 64.0, 0.0));
    const res = horse.checkProximityTrigger(Vec3.init(2.0, 64.0, 2.0)).?;
    try std.testing.expectEqual(@as(usize, 4), res.horsemen.horsemen.len);
    try std.testing.expectEqual(@as(usize, 4), res.horsemen.mountedCount());
    try std.testing.expectEqual(@as(usize, 4), res.horsemen.aliveRidersCount());
    try std.testing.expectEqual(@as(usize, 4), res.horsemen.aliveHorsesCount());
}

test "the four horsemen spawn spread around the central trigger position" {
    const center = Vec3.init(100.0, 64.0, 100.0);
    const four = TheFourHorsemen.spawnAt(center);

    for (four.horsemen) |h| {
        try std.testing.expect(Vec3.distance(h.horse.pos, center) > 0.5);
        try std.testing.expect(Vec3.distance(h.horse.pos, center) < 3.0);
    }
}

test "skeleton riders start with 20.0 HP and equipment" {
    const rider = SkeletonRider.init(1, Vec3.init(0.0, 0.0, 0.0));
    try std.testing.expectEqual(@as(f32, 20.0), rider.health);
    try std.testing.expectEqual(@as(f32, 20.0), rider.max_health);
    try std.testing.expect(rider.is_alive);
    try std.testing.expect(rider.has_iron_helmet);
    try std.testing.expect(rider.helmet_enchanted);
    try std.testing.expect(rider.has_enchanted_bow);
}

test "skeleton horses start with 53.0 HP, 12 m/s speed, and 3.5m jump" {
    const horse = SkeletonHorse.init(1, Vec3.init(0.0, 0.0, 0.0));
    try std.testing.expectEqual(@as(f32, 53.0), horse.health);
    try std.testing.expectEqual(@as(f32, 53.0), horse.max_health);
    try std.testing.expectEqual(SKELETON_HORSE_MAX_SPEED, horse.max_speed);
    try std.testing.expectEqual(SKELETON_HORSE_JUMP_HEIGHT, horse.jump_height);
    try std.testing.expect(horse.is_alive);
    try std.testing.expect(!horse.is_tameable);
}

test "summon invulnerability absorbs damage during initial 60 ticks" {
    var rider = SkeletonRider.init(1, Vec3.init(0.0, 0.0, 0.0));
    try std.testing.expect(rider.isDamageImmune());
    try std.testing.expectEqual(@as(u32, 60), rider.damage_immunity_ticks);

    const dmg_res = rider.takeDamage(10.0);
    try std.testing.expect(dmg_res.absorbed);
    try std.testing.expectEqual(@as(f32, 0.0), dmg_res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 20.0), rider.health);
}

test "damage immunity counts down and expires after 60 ticks" {
    var rider = SkeletonRider.init(1, Vec3.init(0.0, 0.0, 0.0));
    rider.tickImmunity(30);
    try std.testing.expectEqual(@as(u32, 30), rider.damage_immunity_ticks);
    try std.testing.expect(rider.isDamageImmune());

    rider.tickImmunity(30);
    try std.testing.expectEqual(@as(u32, 0), rider.damage_immunity_ticks);
    try std.testing.expect(!rider.isDamageImmune());

    const dmg_res = rider.takeDamage(8.0);
    try std.testing.expect(!dmg_res.absorbed);
    try std.testing.expectEqual(@as(f32, 8.0), dmg_res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 12.0), rider.health);
}

test "iron helmet protects skeleton rider from daylight fire" {
    var rider = SkeletonRider.init(1, Vec3.init(0.0, 0.0, 0.0));
    const burn_res = rider.evaluateDaylightBurn(true, true);
    try std.testing.expect(!burn_res.burns);
    try std.testing.expectEqual(@as(u16, 1), burn_res.durability_lost);
    try std.testing.expectEqual(@as(u16, IRON_HELMET_MAX_DURABILITY - 1), rider.helmet_durability);
}

test "skeleton rider without helmet burns in daylight under open sky" {
    var rider = SkeletonRider.init(1, Vec3.init(0.0, 0.0, 0.0));
    rider.has_iron_helmet = false;
    const burn_res = rider.evaluateDaylightBurn(true, true);
    try std.testing.expect(burn_res.burns);
}

test "skeleton rider does not burn at night or sheltered indoors" {
    var rider = SkeletonRider.init(1, Vec3.init(0.0, 0.0, 0.0));
    rider.has_iron_helmet = false;

    // At night: no burn
    try std.testing.expect(!rider.evaluateDaylightBurn(false, true).burns);

    // Sheltered from sky: no burn
    try std.testing.expect(!rider.evaluateDaylightBurn(true, false).burns);
}

test "iron helmet durability depletion breaks helmet and triggers daylight burn" {
    var rider = SkeletonRider.init(1, Vec3.init(0.0, 0.0, 0.0));
    rider.helmet_durability = 1;

    const break_res = rider.evaluateDaylightBurn(true, true);
    try std.testing.expect(!break_res.burns);
    try std.testing.expect(break_res.helmet_broken);
    try std.testing.expect(!rider.has_iron_helmet);

    // Subsequent tick burns in sunlight
    const next_burn = rider.evaluateDaylightBurn(true, true);
    try std.testing.expect(next_burn.burns);
}

test "unengaged skeleton horse despawn timer counts down from 18,000 ticks" {
    var horse = SkeletonHorse.init(1, Vec3.init(0.0, 0.0, 0.0));
    try std.testing.expectEqual(DESPAWN_TIMER_TICKS, horse.despawn_ticks);
    try std.testing.expect(!horse.despawned);

    horse.tickDespawn(6000); // 5 minutes elapsed
    try std.testing.expectEqual(@as(u32, 12000), horse.despawn_ticks);
    try std.testing.expect(!horse.despawned);

    horse.tickDespawn(12000); // Remaining 10 minutes elapsed
    try std.testing.expectEqual(@as(u32, 0), horse.despawn_ticks);
    try std.testing.expect(horse.despawned);
}

test "engaging in combat halts despawn timer countdown" {
    var horse = SkeletonHorse.init(1, Vec3.init(0.0, 0.0, 0.0));
    horse.setEngagedInCombat(true);

    horse.tickDespawn(18000);
    try std.testing.expectEqual(DESPAWN_TIMER_TICKS, horse.despawn_ticks);
    try std.testing.expect(!horse.despawned);
}

test "killing horse dismounts rider to fight on foot" {
    var horseman = SkeletonHorseman.init(1, Vec3.init(0.0, 0.0, 0.0), 1.0);
    try std.testing.expect(horseman.is_mounted);

    const hit = horseman.damageHorse(60.0);
    try std.testing.expect(hit.killed);
    try std.testing.expect(!horseman.horse.is_alive);
    try std.testing.expect(!horseman.is_mounted);
    try std.testing.expect(horseman.rider.is_alive);
    try std.testing.expectEqual(CombatKinematicsState.on_foot, horseman.state);
}

test "killing rider leaves horse alive, tameable and rideable for player" {
    var horseman = SkeletonHorseman.init(1, Vec3.init(0.0, 0.0, 0.0), 1.0);
    horseman.rider.damage_immunity_ticks = 0; // Bypass immunity

    const hit = horseman.damageRider(25.0);
    try std.testing.expect(hit.killed);
    try std.testing.expect(!horseman.rider.is_alive);
    try std.testing.expect(!horseman.is_mounted);
    try std.testing.expect(horseman.horse.is_alive);
    try std.testing.expect(horseman.horse.is_tameable);
    try std.testing.expect(horseman.horse.is_tamed);
    try std.testing.expect(horseman.horse.is_rideable);
    try std.testing.expectEqual(CombatKinematicsState.pacified, horseman.state);
}

test "player can mount and ride a pacified skeleton horse" {
    var horseman = SkeletonHorseman.init(1, Vec3.init(0.0, 0.0, 0.0), 1.0);
    horseman.rider.damage_immunity_ticks = 0;
    _ = horseman.damageRider(20.0);

    const mounted = horseman.horse.mountPlayer(42);
    try std.testing.expect(mounted);
    try std.testing.expect(horseman.horse.has_player_passenger);
    try std.testing.expectEqual(@as(?u32, 42), horseman.horse.passenger_id);

    horseman.horse.dismountPlayer();
    try std.testing.expect(!horseman.horse.has_player_passenger);
    try std.testing.expectEqual(@as(?u32, null), horseman.horse.passenger_id);
}

test "skeleton horse is water-traversable without drowning" {
    const horse = SkeletonHorse.init(1, Vec3.init(0.0, 0.0, 0.0));
    try std.testing.expect(horse.is_underwater_breathable);
}

test "mounted archer AI closes distance when beyond 16.0m standoff" {
    var horseman = SkeletonHorseman.init(1, Vec3.init(0.0, 0.0, 0.0), 1.0);
    const player_pos = Vec3.init(30.0, 0.0, 0.0); // 30m away > 16m
    _ = horseman.updateAI(player_pos, 0.1);

    try std.testing.expectEqual(CombatKinematicsState.closing_in, horseman.state);
    try std.testing.expect(horseman.horse.pos.x > 0.0);
}

test "mounted archer AI kites away when closer than 8.0m standoff" {
    var horseman = SkeletonHorseman.init(1, Vec3.init(5.0, 0.0, 0.0), 1.0);
    const player_pos = Vec3.init(0.0, 0.0, 0.0); // 5m away < 8m
    _ = horseman.updateAI(player_pos, 0.1);

    try std.testing.expectEqual(CombatKinematicsState.retreating, horseman.state);
    try std.testing.expect(horseman.horse.pos.x > 5.0);
}

test "mounted archer AI circles player within 8.0m - 16.0m standoff window" {
    var horseman = SkeletonHorseman.init(1, Vec3.init(10.0, 0.0, 0.0), 1.0);
    const player_pos = Vec3.init(0.0, 0.0, 0.0); // 10m away (in 8m-16m window)
    _ = horseman.updateAI(player_pos, 0.1);

    try std.testing.expectEqual(CombatKinematicsState.circling, horseman.state);
    // Tangent movement in Z direction
    try std.testing.expect(horseman.horse.pos.z != 0.0);
}

test "mounted archer AI fires enchanted bow at player within range" {
    var horseman = SkeletonHorseman.init(1, Vec3.init(12.0, 0.0, 0.0), 1.0);
    const player_pos = Vec3.init(0.0, 0.0, 0.0);

    const shot = horseman.updateAI(player_pos, 0.05);
    try std.testing.expect(shot != null);
    const arrow = shot.?;
    try std.testing.expect(arrow.enchanted);
    try std.testing.expectEqual(@as(f32, 6.0), arrow.damage); // 4.0 base + 2.0 enchanted
    try std.testing.expect(arrow.velocity.x < 0.0); // Aiming towards player at x=0
    try std.testing.expectEqual(DEFAULT_BOW_COOLDOWN_TICKS, horseman.rider.bow_cooldown_ticks);
}

test "four horsemen group encounter tracks alive riders and horses" {
    var four = TheFourHorsemen.spawnAt(Vec3.init(0.0, 0.0, 0.0));
    try std.testing.expectEqual(@as(usize, 4), four.aliveRidersCount());
    try std.testing.expectEqual(@as(usize, 4), four.aliveHorsesCount());
    try std.testing.expectEqual(@as(usize, 0), four.tameableHorsesCount());

    four.horsemen[0].rider.damage_immunity_ticks = 0;
    _ = four.horsemen[0].damageRider(20.0);
    try std.testing.expectEqual(@as(usize, 3), four.aliveRidersCount());
    try std.testing.expectEqual(@as(usize, 4), four.aliveHorsesCount());
    try std.testing.expectEqual(@as(usize, 1), four.tameableHorsesCount());
}
