const std = @import("std");

// ============================================================================
// Core Constants
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;

/// Ambient hazard interval: 8.0 seconds = 160 game ticks.
pub const HAZARD_INTERVAL_TICKS: u32 = 160;
pub const HAZARD_INTERVAL_SECONDS: f32 = 8.0;

/// Lingering potion cloud physical dynamics constants.
pub const CLOUD_INITIAL_RADIUS: f32 = 3.0;
pub const CLOUD_INITIAL_DIAMETER: f32 = 6.0;
pub const CLOUD_SHRINK_PER_AFFLICTION: f32 = 0.5;
pub const CLOUD_MAX_LIFETIME_TICKS: u32 = 600; // 30.0 seconds
pub const CLOUD_MAX_LIFETIME_SECONDS: f32 = 30.0;
pub const CLOUD_MIN_HEIGHT_ABOVE_HEAD: f32 = 3.0;
pub const CLOUD_MAX_HEIGHT_ABOVE_HEAD: f32 = 5.0;

/// Projectile trap ceiling ejection constants.
pub const PROJECTILE_DOWNWARD_VELOCITY: [3]f32 = .{ 0.0, -0.6, 0.0 };
pub const WIND_CHARGE_BURST_RADIUS: f32 = 3.5;
pub const WIND_CHARGE_BURST_RADIUS_SQ: f32 = WIND_CHARGE_BURST_RADIUS * WIND_CHARGE_BURST_RADIUS; // 12.25
pub const WIND_CHARGE_KNOCKBACK_HORIZONTAL: f32 = 6.0;
pub const WIND_CHARGE_UPWARD_VELOCITY: f32 = 6.5;

// ============================================================================
// 1. Lingering Potion Hazard Payload Types
// ============================================================================

pub const LingeringPotionType = enum(u8) {
    poison = 0,
    slowness = 1,
    weaving = 2,
    oozing = 3,
    infested = 4,
    wind_charged = 5,

    /// Duration of the inflicted status effect in seconds.
    pub fn durationSeconds(self: LingeringPotionType) f32 {
        return switch (self) {
            .poison => 4.0, // Poison I, 4s duration
            .slowness => 8.0, // Slowness I, 8s duration
            .weaving => 12.0, // Weaving, 12s duration
            .oozing => 12.0, // Oozing, 12s duration
            .infested => 12.0, // Infested, 12s duration
            .wind_charged => 12.0, // Wind Charged, 12s duration
        };
    }

    /// Duration of the inflicted status effect in game ticks.
    pub fn durationTicks(self: LingeringPotionType) u32 {
        return switch (self) {
            .poison => 4 * TICKS_PER_SECOND, // 80 ticks
            .slowness => 8 * TICKS_PER_SECOND, // 160 ticks
            .weaving, .oozing, .infested, .wind_charged => 12 * TICKS_PER_SECOND, // 240 ticks
        };
    }

    /// User-facing display name of the effect.
    pub fn effectName(self: LingeringPotionType) []const u8 {
        return switch (self) {
            .poison => "Poison I",
            .slowness => "Slowness I",
            .weaving => "Weaving",
            .oozing => "Oozing",
            .infested => "Infested",
            .wind_charged => "Wind Charged",
        };
    }

    /// Effect amplifier level (0 = Level I).
    pub fn amplifier(self: LingeringPotionType) u8 {
        return switch (self) {
            .poison, .slowness, .weaving, .oozing, .infested, .wind_charged => 0,
        };
    }

    /// Ambient particle RGBA color components.
    pub fn particleColor(self: LingeringPotionType) [4]f32 {
        return switch (self) {
            .poison => .{ 0.31, 0.58, 0.19, 0.75 },
            .slowness => .{ 0.36, 0.43, 0.53, 0.75 },
            .weaving => .{ 0.75, 0.75, 0.75, 0.75 },
            .oozing => .{ 0.59, 0.85, 0.52, 0.75 },
            .infested => .{ 0.55, 0.60, 0.55, 0.75 },
            .wind_charged => .{ 0.78, 0.88, 0.95, 0.75 },
        };
    }
};

// ============================================================================
// 2. Lingering Potion Cloud Physical Dynamics
// ============================================================================

pub const LingeringCloud = struct {
    position: [3]f32,
    radius: f32 = CLOUD_INITIAL_RADIUS,
    initial_radius: f32 = CLOUD_INITIAL_RADIUS,
    potion_type: LingeringPotionType,
    age_ticks: u32 = 0,
    max_lifetime_ticks: u32 = CLOUD_MAX_LIFETIME_TICKS,
    active: bool = true,
    afflictions_count: u32 = 0,

    pub fn init(position: [3]f32, potion_type: LingeringPotionType) LingeringCloud {
        return .{
            .position = position,
            .radius = CLOUD_INITIAL_RADIUS,
            .initial_radius = CLOUD_INITIAL_RADIUS,
            .potion_type = potion_type,
            .age_ticks = 0,
            .max_lifetime_ticks = CLOUD_MAX_LIFETIME_TICKS,
            .active = true,
            .afflictions_count = 0,
        };
    }

    /// Diameter of the cloud (2 * radius).
    pub fn diameter(self: LingeringCloud) f32 {
        return self.radius * 2.0;
    }

    /// Initial diameter of the cloud (2 * initial_radius = 6.0m).
    pub fn initialDiameter(self: LingeringCloud) f32 {
        return self.initial_radius * 2.0;
    }

    /// Checks if the cloud has fully dissipated or expired.
    pub fn isExpired(self: LingeringCloud) bool {
        return !self.active or self.age_ticks >= self.max_lifetime_ticks or self.radius <= 0.0001;
    }

    /// Remaining lifetime in ticks.
    pub fn remainingTicks(self: LingeringCloud) u32 {
        if (self.isExpired()) return 0;
        return self.max_lifetime_ticks - self.age_ticks;
    }

    /// Remaining lifetime in seconds.
    pub fn remainingSeconds(self: LingeringCloud) f32 {
        return @as(f32, @floatFromInt(self.remainingTicks())) / @as(f32, @floatFromInt(TICKS_PER_SECOND));
    }

    /// Tests if a 3D point is within the spherical radius of the cloud.
    pub fn containsPoint(self: LingeringCloud, point: [3]f32) bool {
        if (!self.active or self.radius <= 0.0001) return false;
        const dx = point[0] - self.position[0];
        const dy = point[1] - self.position[1];
        const dz = point[2] - self.position[2];
        return (dx * dx + dy * dy + dz * dz) <= (self.radius * self.radius);
    }

    /// Tests if an entity (given bottom position and height) overlaps the cloud.
    pub fn containsEntity(self: LingeringCloud, entity_pos: [3]f32, entity_height: f32) bool {
        if (!self.active or self.radius <= 0.0001) return false;
        // Check feet
        if (self.containsPoint(entity_pos)) return true;
        // Check center
        const center = [3]f32{ entity_pos[0], entity_pos[1] + entity_height * 0.5, entity_pos[2] };
        if (self.containsPoint(center)) return true;
        // Check head
        const head = [3]f32{ entity_pos[0], entity_pos[1] + entity_height, entity_pos[2] };
        return self.containsPoint(head);
    }

    /// Inflicts status effect on entity and shrinks cloud by 0.5m.
    /// Returns true if entity was afflicted, false otherwise.
    pub fn afflictEntity(self: *LingeringCloud, entity: *TrialEntity) bool {
        if (self.isExpired()) return false;
        if (!self.containsEntity(entity.position, entity.height)) return false;

        entity.applyPotion(self.potion_type);
        self.radius -= CLOUD_SHRINK_PER_AFFLICTION;
        self.afflictions_count += 1;

        if (self.radius <= 0.0001) {
            self.radius = 0.0;
            self.active = false;
        }
        return true;
    }

    /// Ticks cloud lifetime by 1 tick (1/20 second).
    pub fn tick(self: *LingeringCloud) void {
        if (!self.active) return;
        self.age_ticks += 1;
        if (self.age_ticks >= self.max_lifetime_ticks) {
            self.active = false;
        }
    }

    /// Ticks cloud and attempts to afflict any overlapping entities.
    /// Returns the number of entities afflicted during this tick.
    pub fn tickWithEntities(self: *LingeringCloud, entities: []TrialEntity) u32 {
        self.tick();
        if (self.isExpired()) return 0;

        var count: u32 = 0;
        for (entities) |*entity| {
            if (self.isExpired()) break;
            if (self.afflictEntity(entity)) {
                count += 1;
            }
        }
        return count;
    }
};

// ============================================================================
// 3. Status Effects & Trial Entity Dynamics
// ============================================================================

pub const DeathTriggerResult = struct {
    has_cobwebs: bool = false,
    cobwebs_count: u8 = 0,
    has_slimes: bool = false,
    slimes_count: u8 = 0,
    has_wind_burst: bool = false,
    wind_burst_radius: f32 = 0.0,
    wind_burst_vy: f32 = 0.0,
};

pub const HurtTriggerResult = struct {
    silverfish_spawned: u8 = 0,
};

pub const TrialEntity = struct {
    id: u32 = 0,
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    health: f32 = 20.0,
    max_health: f32 = 20.0,
    height: f32 = 1.8,
    is_player: bool = false,
    is_dead: bool = false,

    // Active status effect durations in seconds
    poison_duration: f32 = 0.0,
    slowness_duration: f32 = 0.0,
    weaving_duration: f32 = 0.0,
    oozing_duration: f32 = 0.0,
    infested_duration: f32 = 0.0,
    wind_charged_duration: f32 = 0.0,

    poison_damage_timer: f32 = 0.0,

    pub fn init(id: u32, pos: [3]f32, is_player: bool) TrialEntity {
        return .{
            .id = id,
            .position = pos,
            .is_player = is_player,
        };
    }

    /// Applies lingering potion payload effect to this entity.
    pub fn applyPotion(self: *TrialEntity, potion: LingeringPotionType) void {
        const dur = potion.durationSeconds();
        switch (potion) {
            .poison => self.poison_duration = @max(self.poison_duration, dur),
            .slowness => self.slowness_duration = @max(self.slowness_duration, dur),
            .weaving => self.weaving_duration = @max(self.weaving_duration, dur),
            .oozing => self.oozing_duration = @max(self.oozing_duration, dur),
            .infested => self.infested_duration = @max(self.infested_duration, dur),
            .wind_charged => self.wind_charged_duration = @max(self.wind_charged_duration, dur),
        }
    }

    /// Checks if a status effect is currently active on this entity.
    pub fn hasEffect(self: TrialEntity, potion: LingeringPotionType) bool {
        return switch (potion) {
            .poison => self.poison_duration > 0.0,
            .slowness => self.slowness_duration > 0.0,
            .weaving => self.weaving_duration > 0.0,
            .oozing => self.oozing_duration > 0.0,
            .infested => self.infested_duration > 0.0,
            .wind_charged => self.wind_charged_duration > 0.0,
        };
    }

    /// Ticks status effect durations and periodic damage by dt seconds.
    pub fn tick(self: *TrialEntity, dt: f32) void {
        if (self.is_dead) return;
        self.poison_duration = @max(0.0, self.poison_duration - dt);
        self.slowness_duration = @max(0.0, self.slowness_duration - dt);
        self.weaving_duration = @max(0.0, self.weaving_duration - dt);
        self.oozing_duration = @max(0.0, self.oozing_duration - dt);
        self.infested_duration = @max(0.0, self.infested_duration - dt);
        self.wind_charged_duration = @max(0.0, self.wind_charged_duration - dt);

        if (self.poison_duration > 0.0) {
            self.poison_damage_timer += dt;
            // Poison I inflicts 1.0 damage every 1.25 seconds down to 1.0 HP
            if (self.poison_damage_timer >= 1.25) {
                self.poison_damage_timer = 0.0;
                if (self.health > 1.0) {
                    self.health = @max(1.0, self.health - 1.0);
                }
            }
        } else {
            self.poison_damage_timer = 0.0;
        }
    }

    /// Calculates movement speed multiplier factoring in Slowness and Weaving in cobwebs.
    pub fn movementSpeedMultiplier(self: TrialEntity, in_cobweb: bool) f32 {
        var speed: f32 = 1.0;
        if (self.slowness_duration > 0.0) {
            speed *= 0.85; // Slowness I: 15% reduction
        }
        if (in_cobweb) {
            if (self.weaving_duration > 0.0) {
                speed *= 0.50; // Weaving: doubles normal 0.25x speed to 0.50x
            } else {
                speed *= 0.25; // Normal cobweb 0.25x speed
            }
        }
        return speed;
    }

    /// Triggered when entity takes damage. Infested effect procs silverfish on 10% chance.
    pub fn onHurt(self: *TrialEntity, damage: f32, roll: u8) HurtTriggerResult {
        if (self.is_dead) return .{};
        self.health = @max(0.0, self.health - damage);
        if (self.health <= 0.0) {
            self.is_dead = true;
        }

        var result = HurtTriggerResult{};
        if (self.infested_duration > 0.0) {
            // 10% chance when hurt to spawn 1-2 Silverfish
            if ((roll % 10) == 0) {
                result.silverfish_spawned = 1 + ((roll / 10) % 2);
            }
        }
        return result;
    }

    /// Triggered when entity dies.
    /// Weaving spawns 2-3 cobwebs, Oozing spawns 2 medium slimes, Wind Charged triggers wind burst.
    pub fn onDeath(self: *TrialEntity, roll: u8) DeathTriggerResult {
        self.is_dead = true;
        self.health = 0.0;
        var result = DeathTriggerResult{};

        if (self.weaving_duration > 0.0) {
            result.has_cobwebs = true;
            result.cobwebs_count = 2 + (roll % 2); // 2 or 3 cobwebs
        }

        if (self.oozing_duration > 0.0) {
            result.has_slimes = true;
            result.slimes_count = 2; // 2 medium slimes
        }

        if (self.wind_charged_duration > 0.0) {
            result.has_wind_burst = true;
            result.wind_burst_radius = WIND_CHARGE_BURST_RADIUS;
            result.wind_burst_vy = WIND_CHARGE_UPWARD_VELOCITY;
        }

        return result;
    }
};

// ============================================================================
// 4. Projectile Trap Ceiling Ejection & Impact Dynamics
// ============================================================================

pub const ProjectileTrapType = enum(u8) {
    fire_charge = 0,
    wind_charge = 1,

    pub fn name(self: ProjectileTrapType) []const u8 {
        return switch (self) {
            .fire_charge => "Fire Charge",
            .wind_charge => "Wind Charge",
        };
    }
};

pub const CopperFixtureKind = enum(u8) {
    copper_door = 0,
    copper_trapdoor = 1,

    pub fn isDoorOrTrapdoor(self: CopperFixtureKind) bool {
        return self == .copper_door or self == .copper_trapdoor;
    }
};

pub const CopperFixture = struct {
    kind: CopperFixtureKind,
    position: [3]f32,
    is_open: bool = false,

    pub fn init(kind: CopperFixtureKind, position: [3]f32, is_open: bool) CopperFixture {
        return .{
            .kind = kind,
            .position = position,
            .is_open = is_open,
        };
    }

    /// Toggles open/closed state.
    pub fn toggle(self: *CopperFixture) void {
        self.is_open = !self.is_open;
    }
};

pub const BlockType = enum(u16) {
    air = 0,
    stone = 1,
    wood = 2,
    wood_planks = 3,
    leaves = 4,
    wool = 5,
    soul_sand = 6,
    deepslate = 7,
    tuff = 8,
    copper_block = 9,
    chiseled_copper = 10,

    /// Returns true if the block is combustible / flammable.
    pub fn isFlammable(self: BlockType) bool {
        return switch (self) {
            .wood, .wood_planks, .leaves, .wool, .soul_sand => true,
            else => false,
        };
    }
};

pub const FlameKind = enum {
    regular_fire,
    soul_fire,
};

pub const ImpactResult = struct {
    projectile_kind: ProjectileTrapType,
    impact_position: [3]f32,
    // Wind charge burst effects
    wind_burst_triggered: bool = false,
    wind_burst_radius: f32 = 0.0,
    knocked_entities_count: u32 = 0,
    doors_toggled_count: u32 = 0,
    trapdoors_toggled_count: u32 = 0,
    // Fire charge ignition effects
    fire_ignited: bool = false,
    ignited_block_position: ?[3]i32 = null,
    ignited_flame_kind: ?FlameKind = null,
};

pub const CeilingProjectile = struct {
    kind: ProjectileTrapType,
    position: [3]f32,
    velocity: [3]f32 = PROJECTILE_DOWNWARD_VELOCITY, // [3]f32{ 0.0, -0.6, 0.0 }
    active: bool = true,
    has_impacted: bool = false,

    pub fn init(kind: ProjectileTrapType, spawn_pos: [3]f32) CeilingProjectile {
        return .{
            .kind = kind,
            .position = spawn_pos,
            .velocity = PROJECTILE_DOWNWARD_VELOCITY,
            .active = true,
            .has_impacted = false,
        };
    }

    /// Advances projectile downward along its trajectory.
    pub fn tick(self: *CeilingProjectile) void {
        if (!self.active) return;
        self.position[0] += self.velocity[0];
        self.position[1] += self.velocity[1];
        self.position[2] += self.velocity[2];
    }

    /// Checks if projectile has collided with ground surface at ground_y.
    pub fn checkGroundCollision(self: *CeilingProjectile, ground_y: f32) bool {
        if (!self.active) return false;
        if (self.position[1] <= ground_y + 0.001) {
            self.position[1] = ground_y;
            self.active = false;
            self.has_impacted = true;
            return true;
        }
        return false;
    }

    /// Resolves ground impact effects:
    /// - Wind charge triggers 3.5m burst, radial knockback, and toggles copper doors/trapdoors.
    /// - Fire charge ignites flammable ground blocks (regular fire, or soul fire on soul sand).
    pub fn resolveImpact(
        self: *CeilingProjectile,
        ground_block: BlockType,
        entities: []TrialEntity,
        fixtures: []CopperFixture,
    ) ImpactResult {
        self.active = false;
        self.has_impacted = true;

        var result = ImpactResult{
            .projectile_kind = self.kind,
            .impact_position = self.position,
        };

        switch (self.kind) {
            .wind_charge => {
                result.wind_burst_triggered = true;
                result.wind_burst_radius = WIND_CHARGE_BURST_RADIUS;

                // Radial knockback and upward velocity to entities within 3.5m burst radius
                for (entities) |*entity| {
                    const dx = entity.position[0] - self.position[0];
                    const dy = entity.position[1] - self.position[1];
                    const dz = entity.position[2] - self.position[2];
                    const dist_sq = dx * dx + dy * dy + dz * dz;

                    if (dist_sq <= WIND_CHARGE_BURST_RADIUS_SQ) {
                        const dist_h = @sqrt(dx * dx + dz * dz);
                        if (dist_h > 0.001) {
                            entity.velocity[0] += (dx / dist_h) * WIND_CHARGE_KNOCKBACK_HORIZONTAL;
                            entity.velocity[2] += (dz / dist_h) * WIND_CHARGE_KNOCKBACK_HORIZONTAL;
                        }
                        entity.velocity[1] += WIND_CHARGE_UPWARD_VELOCITY;
                        result.knocked_entities_count += 1;
                    }
                }

                // Toggle copper doors and trapdoors within 3.5m burst radius
                for (fixtures) |*fixture| {
                    const dx = fixture.position[0] - self.position[0];
                    const dy = fixture.position[1] - self.position[1];
                    const dz = fixture.position[2] - self.position[2];
                    const dist_sq = dx * dx + dy * dy + dz * dz;

                    if (dist_sq <= WIND_CHARGE_BURST_RADIUS_SQ) {
                        fixture.toggle();
                        switch (fixture.kind) {
                            .copper_door => result.doors_toggled_count += 1,
                            .copper_trapdoor => result.trapdoors_toggled_count += 1,
                        }
                    }
                }
            },
            .fire_charge => {
                if (ground_block.isFlammable()) {
                    result.fire_ignited = true;
                    result.ignited_block_position = .{
                        @as(i32, @intFromFloat(@floor(self.position[0]))),
                        @as(i32, @intFromFloat(@floor(self.position[1]))),
                        @as(i32, @intFromFloat(@floor(self.position[2]))),
                    };
                    result.ignited_flame_kind = if (ground_block == .soul_sand) .soul_fire else .regular_fire;
                } else {
                    result.fire_ignited = false;
                }
            },
        }

        return result;
    }
};

// ============================================================================
// 5. Ominous Spawner Hazard Timers & Selection Controller
// ============================================================================

pub const HazardCategory = enum {
    projectile,
    lingering_potion_cloud,
};

pub const HazardPayload = union(HazardCategory) {
    projectile: ProjectileTrapType,
    lingering_potion_cloud: LingeringPotionType,
};

pub const PlayerMode = enum { survival, adventure, creative, spectator };

pub const Player = struct {
    position: [3]f32,
    mode: PlayerMode = .survival,
    trial_omen: bool = false,
    height: f32 = 1.8,
};

pub const HazardEvent = struct {
    category: HazardCategory,
    payload: HazardPayload,
    spawn_position: [3]f32,
    velocity: [3]f32,
    target_player_index: usize,
    height_above_player: f32,

    pub fn isProjectile(self: HazardEvent) bool {
        return self.category == .projectile;
    }

    pub fn isLingeringCloud(self: HazardEvent) bool {
        return self.category == .lingering_potion_cloud;
    }

    /// Spawns a LingeringCloud if this event is a lingering potion hazard.
    pub fn spawnCloud(self: HazardEvent) ?LingeringCloud {
        if (self.category != .lingering_potion_cloud) return null;
        return LingeringCloud.init(self.spawn_position, self.payload.lingering_potion_cloud);
    }

    /// Spawns a CeilingProjectile if this event is a projectile trap hazard.
    pub fn spawnProjectile(self: HazardEvent) ?CeilingProjectile {
        if (self.category != .projectile) return null;
        return CeilingProjectile.init(self.payload.projectile, self.spawn_position);
    }
};

pub const OminousSpawnerHazardController = struct {
    is_ominous: bool = true,
    is_active: bool = true,
    hazard_timer: u32 = HAZARD_INTERVAL_TICKS,
    hazard_interval_ticks: u32 = HAZARD_INTERVAL_TICKS,
    total_hazards_triggered: u32 = 0,
    rng: std.Random.DefaultPrng,
    ceiling_height_above_player: f32 = 6.0,

    pub fn init(seed: u64) OminousSpawnerHazardController {
        return .{
            .hazard_timer = HAZARD_INTERVAL_TICKS,
            .hazard_interval_ticks = HAZARD_INTERVAL_TICKS,
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    /// Ticks the ambient hazard timer. Triggers every 160 ticks (8.0s) when active.
    pub fn tick(self: *OminousSpawnerHazardController, players: []const Player) ?HazardEvent {
        if (!self.is_active or !self.is_ominous or players.len == 0) return null;

        if (self.hazard_timer > 0) {
            self.hazard_timer -= 1;
        }

        if (self.hazard_timer == 0) {
            self.hazard_timer = self.hazard_interval_ticks;
            self.total_hazards_triggered += 1;
            return self.triggerRandomHazard(players);
        }

        return null;
    }

    /// Triggers a random hazard:
    /// 1. Ceiling Projectile Drop (Fire Charge or Wind Charge dropped straight down above player coordinates).
    /// 2. Lingering Potion Cloud Spawn (spawned 3–5 blocks directly above player head).
    pub fn triggerRandomHazard(self: *OminousSpawnerHazardController, players: []const Player) ?HazardEvent {
        if (players.len == 0) return null;
        const random = self.rng.random();

        const player_idx = random.uintLessThan(usize, players.len);
        const player = players[player_idx];

        const is_cloud = random.boolean();
        if (is_cloud) {
            // Spawned 3-5 blocks directly above player head
            const height_offset: f32 = CLOUD_MIN_HEIGHT_ABOVE_HEAD + random.float(f32) * (CLOUD_MAX_HEIGHT_ABOVE_HEAD - CLOUD_MIN_HEIGHT_ABOVE_HEAD);
            const potion_roll = random.uintLessThan(u8, 6);
            const potion_type: LingeringPotionType = @enumFromInt(potion_roll);

            const spawn_pos = [3]f32{
                player.position[0],
                player.position[1] + player.height + height_offset,
                player.position[2],
            };

            return HazardEvent{
                .category = .lingering_potion_cloud,
                .payload = .{ .lingering_potion_cloud = potion_type },
                .spawn_position = spawn_pos,
                .velocity = .{ 0.0, 0.0, 0.0 },
                .target_player_index = player_idx,
                .height_above_player = player.height + height_offset,
            };
        } else {
            // Ceiling projectile dropped straight down above player coordinates
            const is_wind = random.boolean();
            const proj_type: ProjectileTrapType = if (is_wind) .wind_charge else .fire_charge;
            const drop_height = self.ceiling_height_above_player;
            const spawn_pos = [3]f32{
                player.position[0],
                player.position[1] + drop_height,
                player.position[2],
            };

            return HazardEvent{
                .category = .projectile,
                .payload = .{ .projectile = proj_type },
                .spawn_position = spawn_pos,
                .velocity = PROJECTILE_DOWNWARD_VELOCITY,
                .target_player_index = player_idx,
                .height_above_player = drop_height,
            };
        }
    }

    /// Deterministic hazard selection helper for testing and scripted encounters.
    pub fn selectHazardDeterministic(
        category: HazardCategory,
        payload: HazardPayload,
        target_player_idx: usize,
        player_pos: [3]f32,
        height_offset: f32,
    ) HazardEvent {
        const vel = if (category == .projectile) PROJECTILE_DOWNWARD_VELOCITY else [3]f32{ 0.0, 0.0, 0.0 };
        return HazardEvent{
            .category = category,
            .payload = payload,
            .spawn_position = .{
                player_pos[0],
                player_pos[1] + height_offset,
                player_pos[2],
            },
            .velocity = vel,
            .target_player_index = target_player_idx,
            .height_above_player = height_offset,
        };
    }
};

// ============================================================================
// Unit Tests (25+ tests)
// ============================================================================

test "1: HAZARD_INTERVAL_TICKS is 160 (8.0 seconds at 20 ticks per second)" {
    try std.testing.expectEqual(@as(u32, 160), HAZARD_INTERVAL_TICKS);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), HAZARD_INTERVAL_SECONDS, 0.001);
    try std.testing.expectEqual(HAZARD_INTERVAL_TICKS, @as(u32, @intFromFloat(HAZARD_INTERVAL_SECONDS * @as(f32, @floatFromInt(TICKS_PER_SECOND)))));
}

test "2: Ominous spawner hazard timer decrements every tick when active" {
    var controller = OminousSpawnerHazardController.init(42);
    try std.testing.expectEqual(@as(u32, 160), controller.hazard_timer);

    const players = [_]Player{.{ .position = .{ 0.0, 64.0, 0.0 } }};
    const maybe_hazard = controller.tick(&players);
    try std.testing.expect(maybe_hazard == null);
    try std.testing.expectEqual(@as(u32, 159), controller.hazard_timer);

    for (0..59) |_| {
        _ = controller.tick(&players);
    }
    try std.testing.expectEqual(@as(u32, 100), controller.hazard_timer);
}

test "3: Hazard timer does not decrement when spawner is inactive" {
    var controller = OminousSpawnerHazardController.init(42);
    controller.is_active = false;
    const players = [_]Player{.{ .position = .{ 0.0, 64.0, 0.0 } }};

    for (0..10) |_| {
        const hazard = controller.tick(&players);
        try std.testing.expect(hazard == null);
    }
    try std.testing.expectEqual(@as(u32, 160), controller.hazard_timer);
}

test "4: Hazard timer does not decrement when spawner is not ominous" {
    var controller = OminousSpawnerHazardController.init(42);
    controller.is_ominous = false;
    const players = [_]Player{.{ .position = .{ 0.0, 64.0, 0.0 } }};

    for (0..10) |_| {
        const hazard = controller.tick(&players);
        try std.testing.expect(hazard == null);
    }
    try std.testing.expectEqual(@as(u32, 160), controller.hazard_timer);
}

test "5: Hazard timer triggers exactly after 160 ticks and resets to 160" {
    var controller = OminousSpawnerHazardController.init(12345);
    const players = [_]Player{.{ .position = .{ 10.0, 64.0, 20.0 } }};

    // First 159 ticks: no hazard
    for (0..159) |_| {
        try std.testing.expect(controller.tick(&players) == null);
    }
    try std.testing.expectEqual(@as(u32, 1), controller.hazard_timer);

    // 160th tick: hazard triggers!
    const hazard = controller.tick(&players);
    try std.testing.expect(hazard != null);
    try std.testing.expectEqual(@as(u32, 160), controller.hazard_timer);
    try std.testing.expectEqual(@as(u32, 1), controller.total_hazards_triggered);
}

test "6: Hazard timer triggers repeatedly over multiple 160-tick cycles" {
    var controller = OminousSpawnerHazardController.init(999);
    const players = [_]Player{.{ .position = .{ 0.0, 64.0, 0.0 } }};

    var trigger_count: u32 = 0;
    for (0..480) |_| { // 3 cycles of 160 ticks
        if (controller.tick(&players) != null) {
            trigger_count += 1;
        }
    }
    try std.testing.expectEqual(@as(u32, 3), trigger_count);
    try std.testing.expectEqual(@as(u32, 3), controller.total_hazards_triggered);
    try std.testing.expectEqual(@as(u32, 160), controller.hazard_timer);
}

test "7: Random hazard selection produces both projectiles and lingering potion clouds" {
    var controller = OminousSpawnerHazardController.init(54321);
    const players = [_]Player{.{ .position = .{ 0.0, 64.0, 0.0 } }};

    var found_projectile = false;
    var found_cloud = false;

    for (0..50) |_| {
        const hazard = controller.triggerRandomHazard(&players).?;
        switch (hazard.category) {
            .projectile => found_projectile = true,
            .lingering_potion_cloud => found_cloud = true,
        }
    }

    try std.testing.expect(found_projectile);
    try std.testing.expect(found_cloud);
}

test "8: Projectile hazard rolls both fire charge and wind charge payloads" {
    var controller = OminousSpawnerHazardController.init(777);
    const players = [_]Player{.{ .position = .{ 0.0, 64.0, 0.0 } }};

    var found_fire = false;
    var found_wind = false;

    for (0..60) |_| {
        const hazard = controller.triggerRandomHazard(&players).?;
        if (hazard.category == .projectile) {
            switch (hazard.payload.projectile) {
                .fire_charge => found_fire = true,
                .wind_charge => found_wind = true,
            }
        }
    }

    try std.testing.expect(found_fire);
    try std.testing.expect(found_wind);
}

test "9: Lingering potion cloud hazard spawns 3-5 blocks above player head" {
    var controller = OminousSpawnerHazardController.init(10101);
    const player_pos = [3]f32{ 15.0, 64.0, -8.0 };
    const players = [_]Player{.{ .position = player_pos, .height = 1.8 }};

    for (0..30) |_| {
        const hazard = controller.triggerRandomHazard(&players).?;
        if (hazard.category == .lingering_potion_cloud) {
            // X and Z coordinates must align directly with the player
            try std.testing.expectApproxEqAbs(player_pos[0], hazard.spawn_position[0], 0.001);
            try std.testing.expectApproxEqAbs(player_pos[2], hazard.spawn_position[2], 0.001);

            // Height above player head must be between 3.0 and 5.0 blocks
            const head_y = player_pos[1] + 1.8;
            const height_above_head = hazard.spawn_position[1] - head_y;
            try std.testing.expect(height_above_head >= 3.0 - 0.001);
            try std.testing.expect(height_above_head <= 5.0 + 0.001);
        }
    }
}

test "10: LingeringPotionType duration specifications (4s poison, 8s slowness, 12s others)" {
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), LingeringPotionType.poison.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), LingeringPotionType.slowness.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), LingeringPotionType.weaving.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), LingeringPotionType.oozing.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), LingeringPotionType.infested.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), LingeringPotionType.wind_charged.durationSeconds(), 0.001);

    try std.testing.expectEqual(@as(u32, 80), LingeringPotionType.poison.durationTicks());
    try std.testing.expectEqual(@as(u32, 160), LingeringPotionType.slowness.durationTicks());
    try std.testing.expectEqual(@as(u32, 240), LingeringPotionType.weaving.durationTicks());
    try std.testing.expectEqual(@as(u32, 240), LingeringPotionType.oozing.durationTicks());
    try std.testing.expectEqual(@as(u32, 240), LingeringPotionType.infested.durationTicks());
    try std.testing.expectEqual(@as(u32, 240), LingeringPotionType.wind_charged.durationTicks());
}

test "11: Status effect application: Poison I applies 4s duration and damages entity" {
    var entity = TrialEntity.init(1, .{ 0.0, 64.0, 0.0 }, false);
    entity.applyPotion(.poison);
    try std.testing.expect(entity.hasEffect(.poison));
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), entity.poison_duration, 0.001);

    // After 1.25s of poison, entity takes 1 damage
    entity.tick(1.25);
    try std.testing.expectApproxEqAbs(@as(f32, 19.0), entity.health, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.75), entity.poison_duration, 0.001);

    // Ticking past 4s total expires the poison
    entity.tick(3.0);
    try std.testing.expect(!entity.hasEffect(.poison));
    try std.testing.expectEqual(@as(f32, 0.0), entity.poison_duration);
}

test "12: Status effect application: Slowness I applies 8s duration and reduces speed" {
    var entity = TrialEntity.init(2, .{ 0.0, 64.0, 0.0 }, true);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), entity.movementSpeedMultiplier(false), 0.001);

    entity.applyPotion(.slowness);
    try std.testing.expect(entity.hasEffect(.slowness));
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), entity.slowness_duration, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), entity.movementSpeedMultiplier(false), 0.001);

    entity.tick(8.0);
    try std.testing.expect(!entity.hasEffect(.slowness));
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), entity.movementSpeedMultiplier(false), 0.001);
}

test "13: Status effect application: Weaving applies 12s duration, cobweb speed, and death cobwebs" {
    var entity = TrialEntity.init(3, .{ 0.0, 64.0, 0.0 }, false);
    entity.applyPotion(.weaving);
    try std.testing.expect(entity.hasEffect(.weaving));
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), entity.weaving_duration, 0.001);

    // In cobweb without weaving: 0.25x; with weaving: 0.50x
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), entity.movementSpeedMultiplier(true), 0.001);

    // On death: spawns 2-3 cobwebs
    const death_res_1 = entity.onDeath(0);
    try std.testing.expect(death_res_1.has_cobwebs);
    try std.testing.expectEqual(@as(u8, 2), death_res_1.cobwebs_count);

    const death_res_2 = entity.onDeath(1);
    try std.testing.expectEqual(@as(u8, 3), death_res_2.cobwebs_count);
}

test "14: Status effect application: Oozing applies 12s duration and spawns 2 medium slimes on death" {
    var entity = TrialEntity.init(4, .{ 0.0, 64.0, 0.0 }, false);
    entity.applyPotion(.oozing);
    try std.testing.expect(entity.hasEffect(.oozing));
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), entity.oozing_duration, 0.001);

    const death_res = entity.onDeath(0);
    try std.testing.expect(death_res.has_slimes);
    try std.testing.expectEqual(@as(u8, 2), death_res.slimes_count);
}

test "15: Status effect application: Infested applies 12s duration and spawns silverfish on damage" {
    var entity = TrialEntity.init(5, .{ 0.0, 64.0, 0.0 }, false);
    entity.applyPotion(.infested);
    try std.testing.expect(entity.hasEffect(.infested));
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), entity.infested_duration, 0.001);

    // Roll % 10 == 0 procs silverfish
    const proc_hurt = entity.onHurt(2.0, 10);
    try std.testing.expect(proc_hurt.silverfish_spawned >= 1 and proc_hurt.silverfish_spawned <= 2);

    // Roll % 10 != 0 does not proc
    const no_proc_hurt = entity.onHurt(2.0, 7);
    try std.testing.expectEqual(@as(u8, 0), no_proc_hurt.silverfish_spawned);
}

test "16: Status effect application: Wind Charged applies 12s duration and wind burst on death" {
    var entity = TrialEntity.init(6, .{ 0.0, 64.0, 0.0 }, false);
    entity.applyPotion(.wind_charged);
    try std.testing.expect(entity.hasEffect(.wind_charged));
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), entity.wind_charged_duration, 0.001);

    const death_res = entity.onDeath(0);
    try std.testing.expect(death_res.has_wind_burst);
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), death_res.wind_burst_radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), death_res.wind_burst_vy, 0.001);
}

test "17: Lingering cloud initial radius is 3.0 meters (diameter 6.0 meters)" {
    const cloud = LingeringCloud.init(.{ 0.0, 64.0, 0.0 }, .poison);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), cloud.radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), cloud.initial_radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), cloud.diameter(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), cloud.initialDiameter(), 0.001);
    try std.testing.expect(cloud.active);
    try std.testing.expect(!cloud.isExpired());
}

test "18: Lingering cloud shrinks by exactly 0.5m on entity contact and affliction" {
    var cloud = LingeringCloud.init(.{ 0.0, 64.0, 0.0 }, .slowness);
    var entity = TrialEntity.init(1, .{ 0.0, 64.0, 0.0 }, false);

    try std.testing.expectApproxEqAbs(@as(f32, 3.0), cloud.radius, 0.001);
    try std.testing.expectEqual(@as(u32, 0), cloud.afflictions_count);

    const afflicted = cloud.afflictEntity(&entity);
    try std.testing.expect(afflicted);
    try std.testing.expect(entity.hasEffect(.slowness));
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), cloud.radius, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), cloud.diameter(), 0.001);
    try std.testing.expectEqual(@as(u32, 1), cloud.afflictions_count);
}

test "19: Multiple entity contacts shrink cloud incrementally (-0.5m each)" {
    var cloud = LingeringCloud.init(.{ 0.0, 64.0, 0.0 }, .weaving);
    var entities = [_]TrialEntity{
        TrialEntity.init(1, .{ 0.0, 64.0, 0.0 }, false),
        TrialEntity.init(2, .{ 0.5, 64.0, 0.0 }, false),
        TrialEntity.init(3, .{ -0.5, 64.0, 0.0 }, false),
    };

    try std.testing.expect(cloud.afflictEntity(&entities[0]));
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), cloud.radius, 0.001);

    try std.testing.expect(cloud.afflictEntity(&entities[1]));
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), cloud.radius, 0.001);

    try std.testing.expect(cloud.afflictEntity(&entities[2]));
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), cloud.radius, 0.001);
    try std.testing.expectEqual(@as(u32, 3), cloud.afflictions_count);
}

test "20: Cloud fully dissipates when radius shrinks to 0.0 after 6 afflictions" {
    var cloud = LingeringCloud.init(.{ 0.0, 64.0, 0.0 }, .oozing);

    for (0..6) |i| {
        try std.testing.expect(cloud.active);
        try std.testing.expect(!cloud.isExpired());
        var entity = TrialEntity.init(@as(u32, @intCast(i + 1)), .{ 0.0, 64.0, 0.0 }, false);
        try std.testing.expect(cloud.afflictEntity(&entity));
    }

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), cloud.radius, 0.001);
    try std.testing.expect(!cloud.active);
    try std.testing.expect(cloud.isExpired());
    try std.testing.expectEqual(@as(u32, 6), cloud.afflictions_count);

    // 7th entity cannot be afflicted because cloud is gone
    var entity7 = TrialEntity.init(7, .{ 0.0, 64.0, 0.0 }, false);
    try std.testing.expect(!cloud.afflictEntity(&entity7));
}

test "21: Lingering cloud unconsumed expires at 600 ticks (30.0 seconds)" {
    var cloud = LingeringCloud.init(.{ 0.0, 64.0, 0.0 }, .infested);
    try std.testing.expectEqual(@as(u32, 600), cloud.remainingTicks());
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), cloud.remainingSeconds(), 0.001);

    for (0..599) |_| {
        cloud.tick();
        try std.testing.expect(cloud.active);
        try std.testing.expect(!cloud.isExpired());
    }
    try std.testing.expectEqual(@as(u32, 1), cloud.remainingTicks());

    // 600th tick reaches 30.0s lifetime
    cloud.tick();
    try std.testing.expect(!cloud.active);
    try std.testing.expect(cloud.isExpired());
    try std.testing.expectEqual(@as(u32, 0), cloud.remainingTicks());
    try std.testing.expectEqual(@as(f32, 0.0), cloud.remainingSeconds());
}

test "22: Lingering cloud retains full 3.0m radius if untriggered during lifetime" {
    var cloud = LingeringCloud.init(.{ 0.0, 64.0, 0.0 }, .wind_charged);
    for (0..300) |_| {
        cloud.tick();
    }
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), cloud.radius, 0.001);
    try std.testing.expectEqual(@as(u32, 300), cloud.age_ticks);
    try std.testing.expectEqual(@as(u32, 300), cloud.remainingTicks());
}

test "23: Entities outside spherical cloud radius are not afflicted" {
    var cloud = LingeringCloud.init(.{ 0.0, 64.0, 0.0 }, .poison);
    // Entity at distance 3.5m is outside 3.0m radius
    var far_entity = TrialEntity.init(10, .{ 3.5, 64.0, 0.0 }, false);

    const afflicted = cloud.afflictEntity(&far_entity);
    try std.testing.expect(!afflicted);
    try std.testing.expect(!far_entity.hasEffect(.poison));
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), cloud.radius, 0.001);
    try std.testing.expectEqual(@as(u32, 0), cloud.afflictions_count);
}

test "24: tickWithEntities batch afflicts entities within radius and shrinks cloud" {
    var cloud = LingeringCloud.init(.{ 0.0, 64.0, 0.0 }, .slowness);
    var entities = [_]TrialEntity{
        TrialEntity.init(1, .{ 0.0, 64.0, 0.0 }, false), // inside
        TrialEntity.init(2, .{ 1.0, 64.0, 0.0 }, false), // inside
        TrialEntity.init(3, .{ 5.0, 64.0, 0.0 }, false), // outside
    };

    const count = cloud.tickWithEntities(&entities);
    try std.testing.expectEqual(@as(u32, 2), count);
    try std.testing.expect(entities[0].hasEffect(.slowness));
    try std.testing.expect(entities[1].hasEffect(.slowness));
    try std.testing.expect(!entities[2].hasEffect(.slowness));
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), cloud.radius, 0.001);
}

test "25: Ceiling projectile launches with exact downward velocity [3]f32{0.0, -0.6, 0.0}" {
    const proj = CeilingProjectile.init(.fire_charge, .{ 5.0, 70.0, 5.0 });
    try std.testing.expectEqual(@as(f32, 0.0), proj.velocity[0]);
    try std.testing.expectApproxEqAbs(@as(f32, -0.6), proj.velocity[1], 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), proj.velocity[2]);
    try std.testing.expect(proj.active);
    try std.testing.expect(!proj.has_impacted);
}

test "26: Downward projectile trajectory updates position along Y axis per tick" {
    var proj = CeilingProjectile.init(.wind_charge, .{ 0.0, 70.0, 0.0 });

    proj.tick();
    try std.testing.expectApproxEqAbs(@as(f32, 69.4), proj.position[1], 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), proj.position[0]);
    try std.testing.expectEqual(@as(f32, 0.0), proj.position[2]);

    for (0..9) |_| {
        proj.tick();
    }
    // 10 ticks * -0.6 = -6.0 -> 64.0
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), proj.position[1], 0.001);
}

test "27: Ground collision detection stops projectile at ground_y" {
    var proj = CeilingProjectile.init(.fire_charge, .{ 0.0, 65.0, 0.0 });
    try std.testing.expect(!proj.checkGroundCollision(64.0));

    proj.tick(); // y = 64.4
    try std.testing.expect(!proj.checkGroundCollision(64.0));

    proj.tick(); // y = 63.8 <= 64.0
    try std.testing.expect(proj.checkGroundCollision(64.0));
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), proj.position[1], 0.001);
    try std.testing.expect(!proj.active);
    try std.testing.expect(proj.has_impacted);
}

test "28: Wind charge impact triggers 3.5m burst radius and radial knockback" {
    var proj = CeilingProjectile.init(.wind_charge, .{ 0.0, 64.0, 0.0 });
    var entities = [_]TrialEntity{
        TrialEntity.init(1, .{ 1.0, 64.0, 0.0 }, false), // 1.0m away -> inside burst
        TrialEntity.init(2, .{ 5.0, 64.0, 0.0 }, false), // 5.0m away -> outside burst
    };
    var fixtures = [_]CopperFixture{};

    const res = proj.resolveImpact(.stone, &entities, &fixtures);
    try std.testing.expect(res.wind_burst_triggered);
    try std.testing.expectApproxEqAbs(@as(f32, 3.5), res.wind_burst_radius, 0.001);
    try std.testing.expectEqual(@as(u32, 1), res.knocked_entities_count);

    // Entity 1 knocked horizontally in +X direction and vertically upward
    try std.testing.expect(entities[0].velocity[0] > 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), entities[0].velocity[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), entities[0].velocity[1], 0.001);

    // Entity 2 untouched
    try std.testing.expectEqual(@as(f32, 0.0), entities[1].velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), entities[1].velocity[1]);
}

test "29: Wind charge impact toggles closed copper door to open" {
    var proj = CeilingProjectile.init(.wind_charge, .{ 0.0, 64.0, 0.0 });
    var entities = [_]TrialEntity{};
    var fixtures = [_]CopperFixture{
        CopperFixture.init(.copper_door, .{ 1.0, 64.0, 0.0 }, false), // closed door at 1.0m
    };

    try std.testing.expect(!fixtures[0].is_open);
    const res = proj.resolveImpact(.stone, &entities, &fixtures);
    try std.testing.expectEqual(@as(u32, 1), res.doors_toggled_count);
    try std.testing.expect(fixtures[0].is_open); // Door toggled open!
}

test "30: Wind charge impact toggles open copper door to closed" {
    var proj = CeilingProjectile.init(.wind_charge, .{ 0.0, 64.0, 0.0 });
    var entities = [_]TrialEntity{};
    var fixtures = [_]CopperFixture{
        CopperFixture.init(.copper_door, .{ 1.0, 64.0, 0.0 }, true), // open door at 1.0m
    };

    try std.testing.expect(fixtures[0].is_open);
    const res = proj.resolveImpact(.stone, &entities, &fixtures);
    try std.testing.expectEqual(@as(u32, 1), res.doors_toggled_count);
    try std.testing.expect(!fixtures[0].is_open); // Door toggled closed!
}

test "31: Wind charge impact toggles copper trapdoors within 3.5m radius" {
    var proj = CeilingProjectile.init(.wind_charge, .{ 0.0, 64.0, 0.0 });
    var entities = [_]TrialEntity{};
    var fixtures = [_]CopperFixture{
        CopperFixture.init(.copper_trapdoor, .{ 0.0, 64.0, 2.0 }, false), // at 2.0m -> inside
        CopperFixture.init(.copper_trapdoor, .{ 0.0, 64.0, 4.0 }, false), // at 4.0m -> outside
    };

    const res = proj.resolveImpact(.stone, &entities, &fixtures);
    try std.testing.expectEqual(@as(u32, 1), res.trapdoors_toggled_count);
    try std.testing.expect(fixtures[0].is_open); // toggled!
    try std.testing.expect(!fixtures[1].is_open); // unaffected!
}

test "32: Fire charge impact on flammable wood floor sets regular fire" {
    var proj = CeilingProjectile.init(.fire_charge, .{ 2.0, 64.0, 3.0 });
    var entities = [_]TrialEntity{};
    var fixtures = [_]CopperFixture{};

    const res = proj.resolveImpact(.wood, &entities, &fixtures);
    try std.testing.expect(res.fire_ignited);
    try std.testing.expect(res.ignited_flame_kind.? == .regular_fire);
    try std.testing.expectEqual(@as(i32, 2), res.ignited_block_position.?[0]);
    try std.testing.expectEqual(@as(i32, 64), res.ignited_block_position.?[1]);
    try std.testing.expectEqual(@as(i32, 3), res.ignited_block_position.?[2]);
}

test "33: Fire charge impact on flammable planks, leaves, and wool sets fire" {
    var entities = [_]TrialEntity{};
    var fixtures = [_]CopperFixture{};

    var p1 = CeilingProjectile.init(.fire_charge, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(p1.resolveImpact(.wood_planks, &entities, &fixtures).fire_ignited);

    var p2 = CeilingProjectile.init(.fire_charge, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(p2.resolveImpact(.leaves, &entities, &fixtures).fire_ignited);

    var p3 = CeilingProjectile.init(.fire_charge, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(p3.resolveImpact(.wool, &entities, &fixtures).fire_ignited);
}

test "34: Fire charge impact on soul sand sets soul fire" {
    var proj = CeilingProjectile.init(.fire_charge, .{ 0.0, 64.0, 0.0 });
    var entities = [_]TrialEntity{};
    var fixtures = [_]CopperFixture{};

    const res = proj.resolveImpact(.soul_sand, &entities, &fixtures);
    try std.testing.expect(res.fire_ignited);
    try std.testing.expect(res.ignited_flame_kind.? == .soul_fire);
}

test "35: Fire charge impact on non-flammable stone/deepslate/copper does not set fire" {
    var entities = [_]TrialEntity{};
    var fixtures = [_]CopperFixture{};

    var p1 = CeilingProjectile.init(.fire_charge, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(!p1.resolveImpact(.stone, &entities, &fixtures).fire_ignited);

    var p2 = CeilingProjectile.init(.fire_charge, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(!p2.resolveImpact(.deepslate, &entities, &fixtures).fire_ignited);

    var p3 = CeilingProjectile.init(.fire_charge, .{ 0.0, 64.0, 0.0 });
    try std.testing.expect(!p3.resolveImpact(.copper_block, &entities, &fixtures).fire_ignited);
}

test "36: End-to-end ominous spawner hazard event spawns cloud and afflicts entity" {
    const hazard = OminousSpawnerHazardController.selectHazardDeterministic(
        .lingering_potion_cloud,
        .{ .lingering_potion_cloud = .wind_charged },
        0,
        .{ 5.0, 64.0, 5.0 },
        4.0,
    );

    try std.testing.expect(hazard.isLingeringCloud());
    var cloud = hazard.spawnCloud().?;
    try std.testing.expectEqual(LingeringPotionType.wind_charged, cloud.potion_type);
    try std.testing.expectApproxEqAbs(@as(f32, 68.0), cloud.position[1], 0.001);

    var entity = TrialEntity.init(1, .{ 5.0, 66.5, 5.0 }, true); // inside 3m radius
    try std.testing.expect(cloud.afflictEntity(&entity));
    try std.testing.expect(entity.hasEffect(.wind_charged));
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), cloud.radius, 0.001);
}

test "37: End-to-end ominous spawner hazard event spawns projectile and impacts ground" {
    const hazard = OminousSpawnerHazardController.selectHazardDeterministic(
        .projectile,
        .{ .projectile = .wind_charge },
        0,
        .{ 0.0, 64.0, 0.0 },
        6.0,
    );

    try std.testing.expect(hazard.isProjectile());
    var proj = hazard.spawnProjectile().?;
    try std.testing.expectEqual(ProjectileTrapType.wind_charge, proj.kind);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), proj.position[1], 0.001);

    // Simulate 10 ticks of descent: 70.0 - 6.0 = 64.0
    for (0..10) |_| {
        proj.tick();
    }
    try std.testing.expect(proj.checkGroundCollision(64.0));

    var entities = [_]TrialEntity{TrialEntity.init(1, .{ 0.5, 64.0, 0.5 }, false)};
    var fixtures = [_]CopperFixture{CopperFixture.init(.copper_door, .{ 0.0, 64.0, 1.0 }, false)};

    const impact = proj.resolveImpact(.stone, &entities, &fixtures);
    try std.testing.expect(impact.wind_burst_triggered);
    try std.testing.expectEqual(@as(u32, 1), impact.knocked_entities_count);
    try std.testing.expectEqual(@as(u32, 1), impact.doors_toggled_count);
    try std.testing.expect(fixtures[0].is_open);
}
