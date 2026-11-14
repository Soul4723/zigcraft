const std = @import("std");

pub const shulker_closed_armor_points: f32 = 20.0;
pub const shulker_open_armor_points: f32 = 0.0;
pub const shulker_bullet_damage: f32 = 4.0;
pub const levitation_duration_seconds: f32 = 10.0;
pub const levitation_upward_velocity: f32 = 0.9;
pub const shulker_box_slot_count: usize = 27;
pub const shulker_duplication_nearby_limit: u8 = 5;

pub const ShulkerPeekState = enum {
    closed_shell,
    peeking,
    open_firing,
};

/// Closed and transitional shells retain full armor; the firing opening exposes
/// the Shulker with no armor.
pub fn armorPoints(state: ShulkerPeekState) f32 {
    return if (state == .open_firing) shulker_open_armor_points else shulker_closed_armor_points;
}

/// The simplified armor model used here applies the requested 80% reduction
/// while the shell is closed or peeking.
pub fn meleeDamageReduction(state: ShulkerPeekState) f32 {
    return if (armorPoints(state) == shulker_closed_armor_points) 0.8 else 0.0;
}

pub fn applyMeleeDamage(state: ShulkerPeekState, damage: f32) f32 {
    return @max(0.0, damage) * (1.0 - meleeDamageReduction(state));
}

/// Closed-shell Shulkers deflect all projectile hits, including arrows.
pub fn deflectsProjectile(state: ShulkerPeekState) bool {
    return state != .open_firing;
}

pub const Axis = enum(u2) { x, y, z };

/// Selects the axis with the greatest remaining distance (ties prefer X, then
/// Y, then Z) and returns a one-block step toward the target on only that axis.
/// A target less than one block away is reached exactly on the selected axis.
pub fn chooseNextAxisStep(position: [3]f32, target: [3]f32) [3]f32 {
    var axis: usize = 0;
    var greatest_distance = @abs(target[0] - position[0]);
    for (1..3) |candidate| {
        const distance = @abs(target[candidate] - position[candidate]);
        if (distance > greatest_distance) {
            greatest_distance = distance;
            axis = candidate;
        }
    }

    var next = position;
    if (greatest_distance == 0.0) return next;
    const delta = target[axis] - position[axis];
    next[axis] += if (delta > 0.0) @min(1.0, delta) else @max(-1.0, delta);
    return next;
}

pub const Levitation = struct {
    duration: f32 = levitation_duration_seconds,
    upward_velocity: f32 = levitation_upward_velocity,
    active: bool = true,

    pub fn tick(self: *Levitation, dt: f32) void {
        if (!self.active) return;
        if (dt <= 0.0) return;
        if (self.duration > dt) {
            self.duration -= dt;
        } else {
            self.duration = 0.0;
            self.active = false;
        }
    }
};

pub const ShulkerBullet = struct {
    position: [3]f32,
    target: [3]f32,
    alive: bool = true,

    pub fn init(position: [3]f32, target: [3]f32) ShulkerBullet {
        return .{ .position = position, .target = target };
    }

    /// Advance by one orthogonal grid step toward the current target.
    pub fn homeOneStep(self: *ShulkerBullet) [3]f32 {
        if (!self.alive) return self.position;
        self.position = chooseNextAxisStep(self.position, self.target);
        return self.position;
    }

    pub fn hasReachedTarget(self: ShulkerBullet) bool {
        return self.position[0] == self.target[0] and
            self.position[1] == self.target[1] and
            self.position[2] == self.target[2];
    }

    /// A successful hit consumes the bullet and applies fixed damage plus
    /// 10 seconds of upward Levitation. Subsequent hits do nothing.
    pub fn hitTarget(self: *ShulkerBullet) ?BulletHit {
        if (!self.alive) return null;
        self.alive = false;
        return .{ .damage = shulker_bullet_damage, .levitation = .{} };
    }

    /// A melee swat destroys the projectile before it can hit a target.
    pub fn swatWithMelee(self: *ShulkerBullet) bool {
        if (!self.alive) return false;
        self.alive = false;
        return true;
    }
};

pub const BulletHit = struct {
    damage: f32,
    levitation: Levitation,
};

pub const ShulkerBoxSlot = struct {
    item_id: u16 = 0,
    count: u8 = 0,
};

pub const ShulkerBoxContainer = struct {
    slots: [27]ShulkerBoxSlot = [_]ShulkerBoxSlot{.{}} ** shulker_box_slot_count,
    color: ?u4 = null,

    pub fn setSlot(self: *ShulkerBoxContainer, index: usize, item_id: u16, count: u8) bool {
        if (index >= shulker_box_slot_count) return false;
        self.slots[index] = .{ .item_id = item_id, .count = count };
        return true;
    }

    pub fn getSlot(self: ShulkerBoxContainer, index: usize) ?ShulkerBoxSlot {
        if (index >= shulker_box_slot_count) return null;
        const slot = self.slots[index];
        return .{ .item_id = slot.item_id, .count = slot.count };
    }

    /// Mining/picking up preserves every slot and the optional dye color in
    /// the returned item payload; no inventory serialization is discarded.
    pub fn mineAndPickUp(self: ShulkerBoxContainer) ShulkerBoxItem {
        return .{ .slots = self.slots, .color = self.color };
    }

    pub fn canInsertIntoShulkerBox(is_shulker_box_item: bool) bool {
        return !is_shulker_box_item;
    }
};

pub const ShulkerBoxItem = struct {
    slots: [27]ShulkerBoxSlot,
    color: ?u4,

    pub fn place(self: ShulkerBoxItem) ShulkerBoxContainer {
        return .{ .slots = self.slots, .color = self.color };
    }
};

pub const Shulker = struct {
    position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    alive: bool = true,
};

pub const ShulkerDuplicationResult = struct {
    triggered: bool = false,
    teleported: bool = false,
    spawned_shulker: bool = false,
    spawned_position: ?[3]f32 = null,
};

/// Models the mutual-hit duplication event. When a Shulker bullet hits another
/// Shulker and fewer than five Shulkers are nearby, the victim teleports to the
/// supplied destination and a new Shulker appears at its old position.
pub fn tryShulkerHitDuplication(
    victim: *Shulker,
    hit_by_shulker_bullet: bool,
    nearby_shulker_count: u8,
    teleport_destination: [3]f32,
) ShulkerDuplicationResult {
    if (!victim.alive or !hit_by_shulker_bullet or nearby_shulker_count >= shulker_duplication_nearby_limit) {
        return .{};
    }
    const spawn_position = victim.position;
    victim.position = teleport_destination;
    return .{
        .triggered = true,
        .teleported = true,
        .spawned_shulker = true,
        .spawned_position = spawn_position,
    };
}

pub const ItemType = enum(u16) {
    air = 0,
    shulker_shell = 160,
    shulker_box = 161,
    chest = 16,
    dye = 0xFFFE,
    stone = 1,
};

pub const SLOT_COUNT: usize = 27;
pub const DyeColor = enum(u4) { white, orange, magenta, light_blue, yellow, lime, pink, gray, light_gray, cyan, purple, blue, brown, green, red, black };
pub const ItemStack = struct {
    item: ItemType = .air,
    count: u8 = 0,
    pub fn empty(self: ItemStack) bool {
        return self.count == 0 or self.item == .air;
    }
};
pub const CraftOutput = struct { item: ItemType, color: ?DyeColor = null, count: u8 = 1 };
pub const BreakCause = enum { tool, explosion };
pub const PortableShulkerBoxItem = struct { item: ItemType = .shulker_box, contents: [SLOT_COUNT]ItemStack, color: ?DyeColor = null };
pub const MiningResult = struct { drop: PortableShulkerBoxItem, spilled_items: usize };

pub const ShulkerBox = struct {
    slots: [SLOT_COUNT]ItemStack = [_]ItemStack{.{}} ** SLOT_COUNT,
    color: ?DyeColor = null,
    pub fn canInsertItem(_: *const ShulkerBox, item: ItemType) bool {
        return item != .shulker_box;
    }
    pub fn insert(self: *ShulkerBox, index: usize, stack: ItemStack) bool {
        if (index >= SLOT_COUNT or stack.empty() or !self.canInsertItem(stack.item) or !self.slots[index].empty()) return false;
        self.slots[index] = stack;
        return true;
    }
    pub fn mine(self: ShulkerBox, _: BreakCause) MiningResult {
        return .{ .drop = .{ .contents = self.slots, .color = self.color }, .spilled_items = 0 };
    }
    pub fn comparatorSignal(self: *const ShulkerBox) u8 {
        var fullness: f64 = 0;
        for (self.slots) |slot| if (!slot.empty()) {
            fullness += @as(f64, @floatFromInt(slot.count)) / 64.0;
        };
        if (fullness == 0) return 0;
        return @intFromFloat(@min(15.0, @floor((fullness / @as(f64, @floatFromInt(SLOT_COUNT))) * 14.0) + 1.0));
    }
};

pub fn place(item: PortableShulkerBoxItem) ShulkerBox {
    return .{ .slots = item.contents, .color = item.color };
}
pub fn craftShulkerBox(shells: u8, chests: u8) ?CraftOutput {
    if (shells == 2 and chests == 1) return .{ .item = .shulker_box };
    return null;
}
pub fn craftDye(box: PortableShulkerBoxItem, color: DyeColor) PortableShulkerBoxItem {
    var result = box;
    result.color = color;
    return result;
}
pub fn washInWaterCauldron(item: PortableShulkerBoxItem, is_water_cauldron: bool) ?PortableShulkerBoxItem {
    if (!is_water_cauldron or item.color == null) return null;
    var washed = item;
    washed.color = null;
    return washed;
}


// ============================================================================
// Constants & Configuration
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;
pub const TICK_DT: f32 = 1.0 / @as(f32, @floatFromInt(TICKS_PER_SECOND)); // 0.05 seconds
pub const CRUISE_SPEED: f32 = 0.50; // 0.50 m/s (slow, deliberate tracking)
pub const CRUISE_SPEED_PER_TICK: f32 = CRUISE_SPEED * TICK_DT; // 0.025 m/tick
pub const NAVIGATION_EVALUATION_INTERVAL_TICKS: u32 = 4;
pub const BULLET_DAMAGE: f32 = 4.0; // 4.0 HP (2 hearts)
pub const LEVITATION_DURATION_TICKS: u32 = 200; // 200 game ticks = 10.0 seconds
pub const LEVITATION_DURATION_SECONDS: f32 = 10.0;
pub const LEVITATION_LIFT_PER_TICK_PER_LEVEL: f32 = 0.05; // +0.05 * level blocks/tick
pub const LEVITATION_LIFT_SPEED_PER_LEVEL: f32 = 1.0; // +1.0 m/s per level
pub const BULLET_MAX_LIFETIME_TICKS: u32 = 1200; // 60 seconds = 1200 ticks
pub const BULLET_HITBOX_RADIUS: f32 = 0.3125; // 5/16 block
pub const DEFAULT_GRAVITY: f32 = 25.0; // m/s^2 downward gravity
pub const SHIELD_MAX_DURABILITY: u16 = 336;
pub const SHIELD_DEFAULT_DURABILITY_DAMAGE: u16 = 1;

// ============================================================================
// Enums & Types
// ============================================================================

/// Cardinal axes along which the Shulker Bullet navigates orthogonally.
pub const CardinalAxis = enum(u2) {
    x = 0,
    y = 1,
    z = 2,
};

/// Particle types emitted by missiles and impacts.
pub const ParticleType = enum(u8) {
    end_rod = 0,
    crit = 1,
    spark = 2,
};

/// Acoustic sound cues produced by bullet events and defense actions.
pub const SoundEffect = enum(u8) {
    shield_block_metallic_clang = 0,
    bullet_hit = 1,
    bullet_deflected = 2,
    bullet_destroyed = 3,
    milk_drink = 4,
    levitation_float = 5,
};

/// Alias for SoundEffect.
pub const Sound = SoundEffect;

/// Attack classifications capable of interacting with or deflecting missiles.
pub const AttackKind = enum(u8) {
    fist = 0,
    sword = 1,
    axe = 2,
    arrow = 3,
    projectile_other = 4,

    pub fn isMelee(self: AttackKind) bool {
        return self == .fist or self == .sword or self == .axe;
    }

    pub fn isProjectile(self: AttackKind) bool {
        return self == .arrow or self == .projectile_other;
    }
};

/// Particle data generated along the bullet trajectory.
pub const Particle = struct {
    particle_type: ParticleType = .end_rod,
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    color_rgba: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 }, // pure white
    lifetime_ticks: u16 = 20,
    scale: f32 = 1.0,
};

/// Shield state tracking block posture, orientation, and durability.
pub const ShieldState = struct {
    is_blocking: bool = false,
    durability: u16 = SHIELD_MAX_DURABILITY,
    facing_direction: [3]f32 = .{ 0.0, 0.0, 1.0 },

    pub fn damageShield(self: *ShieldState, amount: u16) void {
        if (self.durability > amount) {
            self.durability -= amount;
        } else {
            self.durability = 0;
            self.is_blocking = false;
        }
    }
};

/// Levitation status effect: applies constant upward vertical velocity and overrides gravity.
pub const LevitationEffect = struct {
    level: u8 = 1,
    duration_ticks: u32 = LEVITATION_DURATION_TICKS,
    active: bool = true,

    pub fn init(level: u8, duration_ticks: u32) LevitationEffect {
        return .{
            .level = level,
            .duration_ticks = duration_ticks,
            .active = duration_ticks > 0 and level > 0,
        };
    }

    /// Upward velocity in blocks per game tick: vy = +0.05 * level blocks/tick.
    pub fn upwardVelocityBlocksPerTick(self: LevitationEffect) f32 {
        if (!self.active) return 0.0;
        return LEVITATION_LIFT_PER_TICK_PER_LEVEL * @as(f32, @floatFromInt(self.level));
    }

    /// Upward velocity in meters per second: vy = +1.0 * level m/s.
    pub fn upwardVelocityMetersPerSecond(self: LevitationEffect) f32 {
        if (!self.active) return 0.0;
        return LEVITATION_LIFT_SPEED_PER_LEVEL * @as(f32, @floatFromInt(self.level));
    }

    /// Decrement duration by 1 tick and deactivate when expired.
    pub fn tick(self: *LevitationEffect) void {
        if (!self.active) return;
        if (self.duration_ticks > 0) {
            self.duration_ticks -= 1;
            if (self.duration_ticks == 0) {
                self.active = false;
            }
        } else {
            self.active = false;
        }
    }

    /// Drinking milk immediately cancels the effect.
    pub fn cureWithMilk(self: *LevitationEffect) void {
        self.active = false;
        self.duration_ticks = 0;
    }
};

/// Impact outcome from a Shulker Bullet collision with an entity.
pub const ImpactResult = struct {
    damage_dealt: f32,
    levitation_applied: bool,
    levitation_duration_ticks: u32,
    levitation_level: u8,
    shield_blocked: bool,
    sound_effect: ?SoundEffect,
    shield_durability_damage: u16,
    bullet_destroyed: bool,
};

/// Result of striking or deflecting an incoming Shulker Bullet.
pub const DeflectionResult = struct {
    is_deflected: bool,
    bullet_destroyed: bool,
    new_velocity: [3]f32,
    sound_effect: ?SoundEffect,
};

/// Entity kinematics representing a target (e.g. player or mob) experiencing gravity,
/// drag, levitation, and shield interactions.
pub const EntityKinematics = struct {
    position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    health: f32 = 20.0,
    on_ground: bool = false,
    levitation: ?LevitationEffect = null,
    shield: ShieldState = .{},
    gravity: f32 = DEFAULT_GRAVITY,
    horizontal_drag: f32 = 0.91,

    pub fn isLevitating(self: EntityKinematics) bool {
        if (self.levitation) |lev| {
            return lev.active and lev.duration_ticks > 0;
        }
        return false;
    }

    pub fn applyLevitation(self: *EntityKinematics, level: u8, duration_ticks: u32) void {
        self.levitation = LevitationEffect.init(level, duration_ticks);
        self.on_ground = false;
    }

    pub fn cureWithMilk(self: *EntityKinematics) void {
        if (self.levitation) |*lev| {
            lev.cureWithMilk();
        }
        self.levitation = null;
    }

    /// Advance entity physics for 1 game tick.
    pub fn tickPhysics(self: *EntityKinematics, input_move_xz: [2]f32) void {
        // Horizontal movement remains player-controllable and subject to drag
        self.velocity[0] = (self.velocity[0] + input_move_xz[0]) * self.horizontal_drag;
        self.velocity[2] = (self.velocity[2] + input_move_xz[1]) * self.horizontal_drag;

        if (self.isLevitating()) {
            const lev = &self.levitation.?;
            // Overrides normal gravity: applies constant vertical upward velocity
            self.velocity[1] = lev.upwardVelocityMetersPerSecond();
            self.on_ground = false;
            lev.tick();
            if (!lev.active) {
                self.levitation = null;
            }
        } else {
            // Normal downward gravity restores immediately
            self.velocity[1] -= self.gravity * TICK_DT;
            if (self.velocity[1] < -30.0) self.velocity[1] = -30.0;
        }

        self.position[0] += self.velocity[0] * TICK_DT;
        self.position[1] += self.velocity[1] * TICK_DT;
        self.position[2] += self.velocity[2] * TICK_DT;
    }
};

/// Shulker Bullet missile entity with cardinal axis guided navigation.
pub const GuidedShulkerBullet = struct {
    position: [3]f32,
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    target_entity_id: u32,
    target_position: [3]f32,

    cruise_speed: f32 = CRUISE_SPEED,
    alive: bool = true,
    is_deflected: bool = false,
    age_ticks: u32 = 0,
    max_lifetime_ticks: u32 = BULLET_MAX_LIFETIME_TICKS,

    current_axis: CardinalAxis = .x,
    current_direction: f32 = 1.0,
    ticks_since_evaluation: u32 = 0,

    pub fn init(position: [3]f32, target_entity_id: u32, target_position: [3]f32) GuidedShulkerBullet {
        var bullet = GuidedShulkerBullet{
            .position = position,
            .target_entity_id = target_entity_id,
            .target_position = target_position,
        };
        bullet.evaluateNavigation(target_position);
        return bullet;
    }

    /// Cardinal axis guided navigation: selects the primary axis (X, Y, or Z) with
    /// the greatest remaining distance toward the target and sets orthogonal velocity.
    pub fn evaluateNavigation(self: *GuidedShulkerBullet, target: [3]f32) void {
        self.target_position = target;
        const dx = target[0] - self.position[0];
        const dy = target[1] - self.position[1];
        const dz = target[2] - self.position[2];

        const abs_x = @abs(dx);
        const abs_y = @abs(dy);
        const abs_z = @abs(dz);

        if (abs_x == 0.0 and abs_y == 0.0 and abs_z == 0.0) {
            self.velocity = .{ 0.0, 0.0, 0.0 };
            self.ticks_since_evaluation = 0;
            return;
        }

        if (abs_x >= abs_y and abs_x >= abs_z) {
            self.current_axis = .x;
            self.current_direction = if (dx >= 0.0) 1.0 else -1.0;
        } else if (abs_y >= abs_z) {
            self.current_axis = .y;
            self.current_direction = if (dy >= 0.0) 1.0 else -1.0;
        } else {
            self.current_axis = .z;
            self.current_direction = if (dz >= 0.0) 1.0 else -1.0;
        }

        self.velocity = .{ 0.0, 0.0, 0.0 };
        switch (self.current_axis) {
            .x => self.velocity[0] = self.current_direction * self.cruise_speed,
            .y => self.velocity[1] = self.current_direction * self.cruise_speed,
            .z => self.velocity[2] = self.current_direction * self.cruise_speed,
        }
        self.ticks_since_evaluation = 0;
    }

    /// Advance bullet by 1 game tick, re-evaluating target offset direction every 4 game ticks.
    pub fn tick(self: *GuidedShulkerBullet, updated_target_pos: ?[3]f32) void {
        if (!self.alive) return;

        if (self.age_ticks >= self.max_lifetime_ticks) {
            self.alive = false;
            return;
        }

        if (updated_target_pos) |tgt| {
            self.target_position = tgt;
        }

        self.age_ticks += 1;
        self.ticks_since_evaluation += 1;

        // Re-evaluate target offset direction every 4 game ticks
        if (self.ticks_since_evaluation >= NAVIGATION_EVALUATION_INTERVAL_TICKS) {
            self.evaluateNavigation(self.target_position);
        }

        self.position[0] += self.velocity[0] * TICK_DT;
        self.position[1] += self.velocity[1] * TICK_DT;
        self.position[2] += self.velocity[2] * TICK_DT;

        if (self.age_ticks >= self.max_lifetime_ticks) {
            self.alive = false;
        }
    }

    /// Emits spinning white spiral swirling particles (`ParticleType.end_rod`).
    pub fn emitSpiralParticle(self: GuidedShulkerBullet) Particle {
        const angle = @as(f32, @floatFromInt(self.age_ticks)) * (std.math.pi * 0.5);
        const radius: f32 = 0.25;

        var offset = [3]f32{ 0.0, 0.0, 0.0 };
        switch (self.current_axis) {
            .x => {
                offset[1] = radius * @sin(angle);
                offset[2] = radius * @cos(angle);
            },
            .y => {
                offset[0] = radius * @cos(angle);
                offset[2] = radius * @sin(angle);
            },
            .z => {
                offset[0] = radius * @cos(angle);
                offset[1] = radius * @sin(angle);
            },
        }

        return .{
            .particle_type = .end_rod,
            .position = .{
                self.position[0] + offset[0],
                self.position[1] + offset[1],
                self.position[2] + offset[2],
            },
            .velocity = .{
                offset[0] * 0.1,
                offset[1] * 0.1,
                offset[2] * 0.1,
            },
            .color_rgba = .{ 1.0, 1.0, 1.0, 1.0 },
            .lifetime_ticks = 20,
        };
    }

    /// Striking the incoming bullet with melee (fist, sword, axe) or projectile (arrow)
    /// destroys the bullet or deflects it away, setting is_deflected = true.
    pub fn deflectWithAttack(self: *GuidedShulkerBullet, attack: AttackKind, deflection_aim_dir: ?[3]f32) DeflectionResult {
        _ = attack;
        if (!self.alive) {
            return .{
                .is_deflected = false,
                .bullet_destroyed = false,
                .new_velocity = self.velocity,
                .sound_effect = null,
            };
        }

        self.is_deflected = true;

        if (deflection_aim_dir) |aim| {
            const len_sq = aim[0] * aim[0] + aim[1] * aim[1] + aim[2] * aim[2];
            if (len_sq > 0.0001) {
                const inv_len = 1.0 / @sqrt(len_sq);
                const speed = self.cruise_speed * 1.5;
                self.velocity = .{
                    aim[0] * inv_len * speed,
                    aim[1] * inv_len * speed,
                    aim[2] * inv_len * speed,
                };
                return .{
                    .is_deflected = true,
                    .bullet_destroyed = false,
                    .new_velocity = self.velocity,
                    .sound_effect = .bullet_deflected,
                };
            }
        }

        self.alive = false;
        return .{
            .is_deflected = true,
            .bullet_destroyed = true,
            .new_velocity = .{ 0.0, 0.0, 0.0 },
            .sound_effect = .bullet_destroyed,
        };
    }

    /// A direct melee swat destroys the projectile and marks it deflected.
    pub fn swatWithMelee(self: *GuidedShulkerBullet) bool {
        if (!self.alive) return false;
        self.alive = false;
        self.is_deflected = true;
        return true;
    }

    pub fn destroy(self: *GuidedShulkerBullet) void {
        self.alive = false;
        self.is_deflected = true;
    }
};

// ============================================================================
// Impact & Shield Detection Helpers
// ============================================================================

/// Determines if the defender's shield is facing the incoming bullet vector.
pub fn isShieldFacingIncoming(defender_look: [3]f32, incoming_vector: [3]f32) bool {
    // Horizontal dot product (standard Minecraft 180-degree blocking arc)
    const dot_xz = defender_look[0] * incoming_vector[0] + defender_look[2] * incoming_vector[2];
    return dot_xz > 0.0;
}

/// Computes Euclidean 3D distance between two points.
pub fn distance3D(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

/// Resolves bullet impact on a targeted entity.
/// - Deflected bullets deal 0 damage.
/// - Blocked by shield: absorbs 100% of damage, negates Levitation, emits clang, wears shield.
/// - Unshielded: deals 4.0 HP damage, inflicts Levitation I for 200 ticks (10.0 seconds).
pub fn resolveImpact(bullet: *GuidedShulkerBullet, target: *EntityKinematics) ImpactResult {
    if (!bullet.alive) {
        return .{
            .damage_dealt = 0.0,
            .levitation_applied = false,
            .levitation_duration_ticks = 0,
            .levitation_level = 0,
            .shield_blocked = false,
            .sound_effect = null,
            .shield_durability_damage = 0,
            .bullet_destroyed = false,
        };
    }

    // A deflected bullet deals 0 damage to the player
    if (bullet.is_deflected) {
        bullet.alive = false;
        return .{
            .damage_dealt = 0.0,
            .levitation_applied = false,
            .levitation_duration_ticks = 0,
            .levitation_level = 0,
            .shield_blocked = false,
            .sound_effect = null,
            .shield_durability_damage = 0,
            .bullet_destroyed = true,
        };
    }

    const incoming_vector = [3]f32{
        bullet.position[0] - target.position[0],
        bullet.position[1] - target.position[1],
        bullet.position[2] - target.position[2],
    };

    const is_facing = isShieldFacingIncoming(target.shield.facing_direction, incoming_vector);
    const blocked_by_shield = target.shield.is_blocking and is_facing;

    if (blocked_by_shield) {
        bullet.alive = false;
        target.shield.damageShield(SHIELD_DEFAULT_DURABILITY_DAMAGE);
        return .{
            .damage_dealt = 0.0,
            .levitation_applied = false,
            .levitation_duration_ticks = 0,
            .levitation_level = 0,
            .shield_blocked = true,
            .sound_effect = .shield_block_metallic_clang,
            .shield_durability_damage = SHIELD_DEFAULT_DURABILITY_DAMAGE,
            .bullet_destroyed = true,
        };
    } else {
        bullet.alive = false;
        target.health = @max(0.0, target.health - BULLET_DAMAGE);
        target.applyLevitation(1, LEVITATION_DURATION_TICKS);
        return .{
            .damage_dealt = BULLET_DAMAGE,
            .levitation_applied = true,
            .levitation_duration_ticks = LEVITATION_DURATION_TICKS,
            .levitation_level = 1,
            .shield_blocked = false,
            .sound_effect = .bullet_hit,
            .shield_durability_damage = 0,
            .bullet_destroyed = true,
        };
    }
}

/// Helper to simulate drinking milk and curing levitation.
pub fn drinkMilkBucket(target: *EntityKinematics) SoundEffect {
    target.cureWithMilk();
    return .milk_drink;
}

/// Multi-tick flight simulation result.
pub const FlightSimulationResult = struct {
    ticks_elapsed: u32,
    hit: bool,
    timed_out: bool,
    final_position: [3]f32,
};

/// Simulates bullet flight for up to max_ticks toward a target entity.
pub fn simulateFlight(
    bullet: *GuidedShulkerBullet,
    target: *EntityKinematics,
    max_ticks: u32,
    hit_distance: f32,
) FlightSimulationResult {
    var t: u32 = 0;
    while (t < max_ticks and bullet.alive) : (t += 1) {
        if (distance3D(bullet.position, target.position) <= hit_distance) {
            _ = resolveImpact(bullet, target);
            return .{
                .ticks_elapsed = t,
                .hit = true,
                .timed_out = false,
                .final_position = bullet.position,
            };
        }
        bullet.tick(target.position);
    }
    return .{
        .ticks_elapsed = t,
        .hit = false,
        .timed_out = !bullet.alive or t >= max_ticks,
        .final_position = bullet.position,
    };
}

// ============================================================================
// Unit Tests (40+ comprehensive tests)
// ============================================================================



pub const TELEPORT_RANGE: f32 = 8.0;
pub const TELEPORT_RANGE_SQ: f32 = TELEPORT_RANGE * TELEPORT_RANGE;
pub const TELEPORT_CHANCE: f32 = 0.25;
pub const CLOSED_ARMOR_POINTS: f32 = 20.0;
pub const CLOSED_DAMAGE_REDUCTION: f32 = 0.8;
pub const SHULKER_SHELL_BASE_DROP_CHANCE: f32 = 0.5;
pub const SHULKER_SHELL_LOOTING_BONUS: f32 = 1.0 / 6.0;
pub const SHULKER_EXPERIENCE: u8 = 5;

pub const Direction = enum {
    up,
    down,
    north,
    south,
    east,
    west,

    pub fn offset(self: Direction) [3]i32 {
        return switch (self) {
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
        };
    }
};

pub const BlockPos = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn distanceSquared(self: BlockPos, other: BlockPos) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return dx * dx + dy * dy + dz * dz;
    }
};

pub const DamageKind = enum { melee, arrow, projectile, fire, lava, other };

pub const ShulkerShell = struct {
    attachment: Direction = .down,
    peek_height: f32 = 0.0,

    pub const isImmuneToFire = true;
    pub const isImmuneToLava = true;

    pub fn init(attachment: Direction) ShulkerShell {
        return .{ .attachment = attachment };
    }

    pub fn setPeekHeight(self: *ShulkerShell, height: f32) void {
        self.peek_height = std.math.clamp(height, 0.0, 1.0);
    }

    pub fn isClosed(self: ShulkerShell) bool {
        return self.peek_height == 0.0;
    }

    pub fn armorPoints(self: ShulkerShell) f32 {
        return if (self.isClosed()) CLOSED_ARMOR_POINTS else 0.0;
    }

    pub fn damageReduction(self: ShulkerShell) f32 {
        return if (self.isClosed()) CLOSED_DAMAGE_REDUCTION else 0.0;
    }

    pub fn damageAfterArmor(self: ShulkerShell, damage: f32) f32 {
        return @max(0.0, damage) * (1.0 - self.damageReduction());
    }

    pub fn applyDamage(self: ShulkerShell, kind: DamageKind, damage: f32) DamageResult {
        if (self.isClosed() and (kind == .arrow or kind == .projectile)) {
            return .{ .damage_taken = 0.0, .is_deflected = true };
        }
        if ((kind == .fire and isImmuneToFire) or (kind == .lava and isImmuneToLava)) {
            return .{ .damage_taken = 0.0, .is_deflected = false };
        }
        return .{ .damage_taken = self.damageAfterArmor(damage), .is_deflected = false };
    }
};

pub const DamageResult = struct {
    damage_taken: f32,
    is_deflected: bool,
};

pub const BlockFace = struct {
    position: BlockPos,
    face: Direction,
    is_solid: bool = true,
};

/// Returns true for a roll in [0, 1) that succeeds at the 25% damage teleport chance.
pub fn shouldTeleportAfterDamage(roll: f32) bool {
    return roll >= 0.0 and roll < TELEPORT_CHANCE;
}

/// Selects uniformly from eligible solid faces within 8 blocks, using `selection_roll` in [0, 1).
pub fn chooseTeleportFace(origin: BlockPos, candidates: []const BlockFace, selection_roll: f32) ?BlockFace {
    if (!(selection_roll >= 0.0 and selection_roll < 1.0)) return null;
    var eligible_count: usize = 0;
    for (candidates) |candidate| {
        if (candidate.is_solid and origin.distanceSquared(candidate.position) <= TELEPORT_RANGE_SQ) {
            eligible_count += 1;
        }
    }
    if (eligible_count == 0) return null;

    const selected_index = @min(@as(usize, @intFromFloat(selection_roll * @as(f32, @floatFromInt(eligible_count)))), eligible_count - 1);
    var eligible_index: usize = 0;
    for (candidates) |candidate| {
        if (!candidate.is_solid or origin.distanceSquared(candidate.position) > TELEPORT_RANGE_SQ) continue;
        if (eligible_index == selected_index) return candidate;
        eligible_index += 1;
    }
    return null;
}

pub const TeleportResult = struct {
    teleported: bool = false,
    destination: ?BlockFace = null,
};

/// Applies the damage-triggered chance, then picks an eligible face if one exists.
pub fn teleportReaction(roll: f32, selection_roll: f32, origin: BlockPos, candidates: []const BlockFace) TeleportResult {
    if (!shouldTeleportAfterDamage(roll)) return .{};
    const destination = chooseTeleportFace(origin, candidates, selection_roll) orelse return .{};
    return .{ .teleported = true, .destination = destination };
}

pub fn shulkerShellDropChance(looting_level: u8) f32 {
    return @min(1.0, SHULKER_SHELL_BASE_DROP_CHANCE + SHULKER_SHELL_LOOTING_BONUS * @as(f32, @floatFromInt(looting_level)));
}

pub const DefeatDrops = struct {
    item: ItemType = .shulker_shell,
    shell_count: u8 = 0,
    experience: u8 = SHULKER_EXPERIENCE,
};

/// The shell roll is in [0, 1); Looting levels above III use the capped 100% chance.
pub fn rollDefeatDrops(shell_roll: f32, looting_level: u8) DefeatDrops {
    const chance = shulkerShellDropChance(looting_level);
    return .{
        .shell_count = if (shell_roll >= 0.0 and shell_roll < chance) 1 else 0,
    };
}

test "closed shell has 20 armor points and reduces melee damage by 80 percent" {
    try std.testing.expectEqual(@as(f32, 20.0), armorPoints(.closed_shell));
    try std.testing.expectEqual(@as(f32, 0.8), meleeDamageReduction(.closed_shell));
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), applyMeleeDamage(.closed_shell, 10.0), 0.0001);
}

test "closed shell completely deflects arrows and projectiles" {
    try std.testing.expect(deflectsProjectile(.closed_shell));
}

test "peeking shell keeps its armor and projectile deflection" {
    try std.testing.expectEqual(@as(f32, 20.0), armorPoints(.peeking));
    try std.testing.expect(deflectsProjectile(.peeking));
}

test "open firing shell has no armor or melee reduction" {
    try std.testing.expectEqual(@as(f32, 0.0), armorPoints(.open_firing));
    try std.testing.expectEqual(@as(f32, 0.0), meleeDamageReduction(.open_firing));
    try std.testing.expectEqual(@as(f32, 10.0), applyMeleeDamage(.open_firing, 10.0));
}

test "open firing shell is vulnerable to projectiles" {
    try std.testing.expect(!deflectsProjectile(.open_firing));
}

test "axis homing chooses largest remaining delta and changes only X" {
    const next = chooseNextAxisStep(.{ 0.0, 0.0, 0.0 }, .{ 3.0, 2.0, 1.0 });
    try std.testing.expectEqual([3]f32{ 1.0, 0.0, 0.0 }, next);
}

test "axis homing steps toward negative Y only" {
    const next = chooseNextAxisStep(.{ 2.0, 5.0, -1.0 }, .{ 2.0, 1.0, -1.0 });
    try std.testing.expectEqual([3]f32{ 2.0, 4.0, -1.0 }, next);
}

test "axis homing handles fractional final step" {
    const next = chooseNextAxisStep(.{ 0.0, 0.0, 0.0 }, .{ 0.25, 0.1, 0.0 });
    try std.testing.expectEqual([3]f32{ 0.25, 0.0, 0.0 }, next);
}

test "axis homing does not move when already at target" {
    const next = chooseNextAxisStep(.{ 1.0, 2.0, 3.0 }, .{ 1.0, 2.0, 3.0 });
    try std.testing.expectEqual([3]f32{ 1.0, 2.0, 3.0 }, next);
}

test "ShulkerBullet homes one axis per step until reaching target" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 1.0, 1.0 });
    _ = bullet.homeOneStep();
    try std.testing.expectEqual([3]f32{ 1.0, 0.0, 0.0 }, bullet.position);
    _ = bullet.homeOneStep();
    try std.testing.expectEqual([3]f32{ 1.0, 1.0, 0.0 }, bullet.position);
    _ = bullet.homeOneStep();
    try std.testing.expect(bullet.hasReachedTarget());
}

test "Shulker Bullet hit deals four damage and applies ten-second Levitation" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    const hit = bullet.hitTarget().?;
    try std.testing.expectEqual(@as(f32, 4.0), hit.damage);
    try std.testing.expectEqual(@as(f32, 10.0), hit.levitation.duration);
    try std.testing.expect(hit.levitation.active);
}

test "Levitation applies plus 0.9 meters per second upward float velocity" {
    const effect = Levitation{};
    try std.testing.expectEqual(@as(f32, 0.9), effect.upward_velocity);
}

test "Levitation expires after ten seconds" {
    var effect = Levitation{};
    effect.tick(9.5);
    try std.testing.expect(effect.active);
    try std.testing.expectEqual(@as(f32, 0.5), effect.duration);
    effect.tick(0.5);
    try std.testing.expect(!effect.active);
    try std.testing.expectEqual(@as(f32, 0.0), effect.duration);
}

test "Shulker Bullet can be swatted out of the air with melee" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, .{ 4.0, 2.0, 1.0 });
    try std.testing.expect(bullet.swatWithMelee());
    try std.testing.expect(!bullet.alive);
    try std.testing.expect(!bullet.swatWithMelee());
    try std.testing.expectEqual(@as(?BulletHit, null), bullet.hitTarget());
}

test "Shulker Box has 27 empty slots and optional color" {
    const box = ShulkerBoxContainer{};
    try std.testing.expectEqual(@as(usize, 27), box.slots.len);
    try std.testing.expectEqual(@as(?u4, null), box.color);
    for (box.slots) |slot| {
        try std.testing.expectEqual(@as(u16, 0), slot.item_id);
        try std.testing.expectEqual(@as(u8, 0), slot.count);
    }
}

test "Shulker Box retains all 27 stacks and color through mining and placement" {
    var box = ShulkerBoxContainer{ .color = 13 };
    for (0..shulker_box_slot_count) |i| {
        try std.testing.expect(box.setSlot(i, @intCast(i + 1), @intCast(i + 2)));
    }
    const item = box.mineAndPickUp();
    const placed = item.place();
    try std.testing.expectEqual(@as(?u4, 13), placed.color);
    for (0..shulker_box_slot_count) |i| {
        const slot = placed.getSlot(i).?;
        try std.testing.expectEqual(@as(u16, @intCast(i + 1)), slot.item_id);
        try std.testing.expectEqual(@as(u8, @intCast(i + 2)), slot.count);
    }
}

test "Shulker Box rejects nesting Shulker Box items" {
    try std.testing.expect(!ShulkerBoxContainer.canInsertIntoShulkerBox(true));
    try std.testing.expect(ShulkerBoxContainer.canInsertIntoShulkerBox(false));
}

test "Shulker Box slot access rejects indices outside 27 slots" {
    var box = ShulkerBoxContainer{};
    try std.testing.expect(!box.setSlot(27, 12, 1));
    try std.testing.expectEqual(@as(?ShulkerBoxSlot, null), box.getSlot(27));
}

test "Shulker bullet mutual hit teleports and duplicates below five nearby" {
    var victim = Shulker{ .position = .{ 1.0, 2.0, 3.0 } };
    const result = tryShulkerHitDuplication(&victim, true, 4, .{ 9.0, 8.0, 7.0 });
    try std.testing.expect(result.triggered and result.teleported and result.spawned_shulker);
    try std.testing.expectEqual([3]f32{ 9.0, 8.0, 7.0 }, victim.position);
    try std.testing.expectEqual([3]f32{ 1.0, 2.0, 3.0 }, result.spawned_position.?);
}

test "Shulker duplication is blocked at five nearby Shulkers" {
    var victim = Shulker{ .position = .{ 1.0, 2.0, 3.0 } };
    const result = tryShulkerHitDuplication(&victim, true, 5, .{ 9.0, 8.0, 7.0 });
    try std.testing.expect(!result.triggered);
    try std.testing.expectEqual([3]f32{ 1.0, 2.0, 3.0 }, victim.position);
}

test "Shulker duplication requires a Shulker bullet hit and living victim" {
    var victim = Shulker{ .position = .{ 1.0, 2.0, 3.0 } };
    try std.testing.expect(!tryShulkerHitDuplication(&victim, false, 1, .{ 9.0, 8.0, 7.0 }).triggered);
    victim.alive = false;
    try std.testing.expect(!tryShulkerHitDuplication(&victim, true, 1, .{ 9.0, 8.0, 7.0 }).triggered);
    try std.testing.expectEqual([3]f32{ 1.0, 2.0, 3.0 }, victim.position);
}

test "recipe crafts exactly two shells and one chest" {
    try std.testing.expect(craftShulkerBox(2, 1) != null);
}
test "recipe rejects one shell" {
    try std.testing.expect(craftShulkerBox(1, 1) == null);
}
test "recipe rejects three shells" {
    try std.testing.expect(craftShulkerBox(3, 1) == null);
}
test "recipe rejects two chests" {
    try std.testing.expect(craftShulkerBox(2, 2) == null);
}
test "recipe output is shulker box" {
    try std.testing.expectEqual(ItemType.shulker_box, craftShulkerBox(2, 1).?.item);
}
test "storage contains 27 empty slots" {
    const b = ShulkerBox{};
    try std.testing.expectEqual(@as(usize, 27), b.slots.len);
    for (b.slots) |s| try std.testing.expect(s.empty());
}
test "insert and read slot zero" {
    var b = ShulkerBox{};
    try std.testing.expect(b.insert(0, .{ .item = .stone, .count = 64 }));
    try std.testing.expectEqual(@as(u8, 64), b.slots[0].count);
}
test "insert works in last slot" {
    var b = ShulkerBox{};
    try std.testing.expect(b.insert(26, .{ .item = .stone, .count = 1 }));
}
test "rejects insertion outside slot range" {
    var b = ShulkerBox{};
    try std.testing.expect(!b.insert(27, .{ .item = .stone, .count = 1 }));
}
test "rejects empty stack insertion" {
    var b = ShulkerBox{};
    try std.testing.expect(!b.insert(0, .{}));
}
test "rejects occupied slot insertion" {
    var b = ShulkerBox{};
    _ = b.insert(0, .{ .item = .stone, .count = 1 });
    try std.testing.expect(!b.insert(0, .{ .item = .stone, .count = 2 }));
}
test "anti nesting canInsertItem rejects shulker box" {
    const b = ShulkerBox{};
    try std.testing.expect(!b.canInsertItem(.shulker_box));
}
test "anti nesting rejects shulker box in each of 27 slots" {
    var b = ShulkerBox{};
    for (0..SLOT_COUNT) |i| try std.testing.expect(!b.insert(i, .{ .item = .shulker_box, .count = 1 }));
}
test "other items remain insertable" {
    const b = ShulkerBox{};
    try std.testing.expect(b.canInsertItem(.stone));
}
test "tool mining preserves content with zero spill" {
    var b = ShulkerBox{};
    b.slots[0] = .{ .item = .stone, .count = 12 };
    const r = b.mine(.tool);
    try std.testing.expectEqual(@as(usize, 0), r.spilled_items);
    try std.testing.expectEqual(b.slots, r.drop.contents);
}
test "explosion mining preserves content with zero spill" {
    var b = ShulkerBox{};
    b.slots[26] = .{ .item = .stone, .count = 4 };
    const r = b.mine(.explosion);
    try std.testing.expectEqual(@as(usize, 0), r.spilled_items);
    try std.testing.expectEqual(b.slots, r.drop.contents);
}
test "mining drop is a shulker box item" {
    const r = (ShulkerBox{}).mine(.tool);
    try std.testing.expectEqual(ItemType.shulker_box, r.drop.item);
}
test "placement restores all saved stacks" {
    var b = ShulkerBox{};
    b.slots[0] = .{ .item = .stone, .count = 4 };
    b.slots[13] = .{ .item = .chest, .count = 2 };
    try std.testing.expectEqual(b.slots, place(b.mine(.tool).drop).slots);
}
test "placement retains box color" {
    const b = ShulkerBox{ .color = .cyan };
    try std.testing.expectEqual(b.color, place(b.mine(.tool).drop).color);
}
test "dye enum contains sixteen colors" {
    try std.testing.expectEqual(@as(usize, 16), @typeInfo(DyeColor).@"enum".fields.len);
}
test "all sixteen dye variants preserve contents" {
    var b = ShulkerBox{};
    b.slots[4] = .{ .item = .stone, .count = 37 };
    const payload = b.mine(.tool).drop;
    inline for (@typeInfo(DyeColor).@"enum".fields) |f| {
        const color: DyeColor = @enumFromInt(f.value);
        const dyed = craftDye(payload, color);
        try std.testing.expectEqual(payload.contents, dyed.contents);
        try std.testing.expectEqual(color, dyed.color.?);
    }
}
test "dye crafting preserves item identity" {
    const dyed = craftDye((ShulkerBox{}).mine(.tool).drop, .red);
    try std.testing.expectEqual(ItemType.shulker_box, dyed.item);
}
test "water cauldron washes dye" {
    const dyed = craftDye((ShulkerBox{}).mine(.tool).drop, .red);
    try std.testing.expect(washInWaterCauldron(dyed, true).?.color == null);
}
test "washing preserves contents" {
    var b = ShulkerBox{};
    b.slots[8] = .{ .item = .stone, .count = 9 };
    const washed = washInWaterCauldron(craftDye(b.mine(.tool).drop, .blue), true).?;
    try std.testing.expectEqual(b.slots, washed.contents);
}
test "nonwater cauldron does not wash" {
    const d = craftDye((ShulkerBox{}).mine(.tool).drop, .blue);
    try std.testing.expect(washInWaterCauldron(d, false) == null);
}
test "washing undyed box is a no-op" {
    const d = (ShulkerBox{}).mine(.tool).drop;
    try std.testing.expect(washInWaterCauldron(d, true) == null);
}
test "empty comparator signal is zero" {
    const b = ShulkerBox{};
    try std.testing.expectEqual(@as(u8, 0), b.comparatorSignal());
}
test "one item comparator signal is one" {
    var b = ShulkerBox{};
    b.slots[0] = .{ .item = .stone, .count = 1 };
    try std.testing.expectEqual(@as(u8, 1), b.comparatorSignal());
}
test "full comparator signal is fifteen" {
    var b = ShulkerBox{};
    for (&b.slots) |*s| s.* = .{ .item = .stone, .count = 64 };
    try std.testing.expectEqual(@as(u8, 15), b.comparatorSignal());
}
test "comparator output is bounded" {
    var b = ShulkerBox{};
    for (&b.slots, 0..) |*s, i| s.* = .{ .item = .stone, .count = @intCast(i + 1) };
    try std.testing.expect(b.comparatorSignal() <= 15);
}
test "last slot contributes to comparator signal" {
    var b = ShulkerBox{};
    b.slots[26] = .{ .item = .stone, .count = 64 };
    try std.testing.expectEqual(@as(u8, 1), b.comparatorSignal());
}

test "1. GuidedShulkerBullet initialization sets position, target entity id, and cruise speed" {
    const bullet = GuidedShulkerBullet.init(.{ 0.0, 10.0, 0.0 }, 42, .{ 10.0, 10.0, 0.0 });
    try std.testing.expectEqual([3]f32{ 0.0, 10.0, 0.0 }, bullet.position);
    try std.testing.expectEqual(@as(u32, 42), bullet.target_entity_id);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.cruise_speed, 0.0001);
    try std.testing.expect(bullet.alive);
    try std.testing.expect(!bullet.is_deflected);
}

test "2. GuidedShulkerBullet cruise speed per tick is 0.025 blocks (0.50 m/s at 20 ticks/sec)" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.025), CRUISE_SPEED_PER_TICK, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), CRUISE_SPEED, 0.0001);
}

test "3. Cardinal axis navigation: selects +X axis when positive X offset is largest" {
    const bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 10.0, 2.0, 1.0 });
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.velocity[0], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[2]);
}

test "4. Cardinal axis navigation: selects -X axis when negative X offset is largest" {
    const bullet = GuidedShulkerBullet.init(.{ 5.0, 0.0, 0.0 }, 1, .{ -5.0, 1.0, 0.0 });
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);
    try std.testing.expectApproxEqAbs(@as(f32, -0.50), bullet.velocity[0], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[1]);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[2]);
}

test "5. Cardinal axis navigation: selects +Y axis when vertical Y offset is largest" {
    const bullet = GuidedShulkerBullet.init(.{ 0.0, 2.0, 0.0 }, 1, .{ 1.0, 15.0, 2.0 });
    try std.testing.expectEqual(CardinalAxis.y, bullet.current_axis);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.velocity[1], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[2]);
}

test "6. Cardinal axis navigation: selects -Y axis when negative Y offset is largest" {
    const bullet = GuidedShulkerBullet.init(.{ 0.0, 20.0, 0.0 }, 1, .{ 1.0, 5.0, 2.0 });
    try std.testing.expectEqual(CardinalAxis.y, bullet.current_axis);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
    try std.testing.expectApproxEqAbs(@as(f32, -0.50), bullet.velocity[1], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[2]);
}

test "7. Cardinal axis navigation: selects +Z axis when Z offset is largest" {
    const bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 1.0, 2.0, 8.0 });
    try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[1]);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.velocity[2], 0.0001);
}

test "8. Cardinal axis navigation: selects -Z axis when negative Z offset is largest" {
    const bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 10.0 }, 1, .{ 1.0, 2.0, 0.0 });
    try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[1]);
    try std.testing.expectApproxEqAbs(@as(f32, -0.50), bullet.velocity[2], 0.0001);
}

test "9. Cardinal axis navigation: orthogonal stepping has exactly one non-zero velocity component" {
    const bullet = GuidedShulkerBullet.init(.{ 1.0, 2.0, 3.0 }, 1, .{ 10.0, 8.0, 5.0 });
    var non_zero_count: usize = 0;
    for (bullet.velocity) |v| {
        if (@abs(v) > 0.0001) non_zero_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), non_zero_count);
}

test "10. Cardinal axis navigation: re-evaluates target offset direction every 4 game ticks" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 10.0, 0.0, 0.0 });
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);

    // Change target position to vertical offset (Y dominant)
    const new_target = [3]f32{ 0.0, 20.0, 0.0 };

    // Ticks 1, 2, 3: does not re-evaluate, stays on X axis
    bullet.tick(new_target); // tick 1
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);
    bullet.tick(new_target); // tick 2
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);
    bullet.tick(new_target); // tick 3
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);

    // Tick 4: 4th tick boundary re-evaluates and switches to Y axis!
    bullet.tick(new_target); // tick 4
    try std.testing.expectEqual(CardinalAxis.y, bullet.current_axis);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), bullet.velocity[1], 0.0001);
    try std.testing.expectEqual(@as(f32, 0.0), bullet.velocity[0]);
}

test "11. Cardinal axis navigation: maintains current axis during intermediate ticks 1, 2, 3" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 10.0 });
    try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);

    for (0..3) |_| {
        bullet.tick(.{ 50.0, 0.0, 0.0 });
        try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);
    }
}

test "12. Cardinal axis navigation: switches to Z axis when Z becomes dominant on tick 4" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 10.0, 0.0, 0.0 });
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);

    for (0..3) |_| {
        bullet.tick(.{ 0.0, 0.0, 50.0 });
    }
    try std.testing.expectEqual(CardinalAxis.x, bullet.current_axis);

    bullet.tick(.{ 0.0, 0.0, 50.0 });
    try std.testing.expectEqual(CardinalAxis.z, bullet.current_axis);
}

test "13. Cardinal axis navigation: sets velocity to zero when coincident with target" {
    const bullet = GuidedShulkerBullet.init(.{ 5.0, 5.0, 5.0 }, 1, .{ 5.0, 5.0, 5.0 });
    try std.testing.expectEqual([3]f32{ 0.0, 0.0, 0.0 }, bullet.velocity);
}

test "14. Particle emission: emits spinning ParticleType.end_rod particles" {
    const bullet = GuidedShulkerBullet.init(.{ 0.0, 10.0, 0.0 }, 1, .{ 10.0, 10.0, 0.0 });
    const p = bullet.emitSpiralParticle();
    try std.testing.expectEqual(ParticleType.end_rod, p.particle_type);
}

test "15. Particle emission: spiral particles swirl with tick-based angular advance" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 10.0, 0.0, 0.0 });
    const p0 = bullet.emitSpiralParticle();
    bullet.tick(null);
    const p1 = bullet.emitSpiralParticle();

    // Position offset must have changed due to angular rotation around X axis
    try std.testing.expect(p0.position[1] != p1.position[1] or p0.position[2] != p1.position[2]);
}

test "16. Particle emission: particle color is pure white rgba(1, 1, 1, 1)" {
    const bullet = GuidedShulkerBullet.init(.{ 2.0, 3.0, 4.0 }, 1, .{ 5.0, 3.0, 4.0 });
    const p = bullet.emitSpiralParticle();
    try std.testing.expectEqual([4]f32{ 1.0, 1.0, 1.0, 1.0 }, p.color_rgba);
}

test "17. Impact physics: unshielded entity hit deals 4.0 HP damage (2 hearts)" {
    var bullet = GuidedShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{ .health = 20.0 };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), result.damage_dealt, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), target.health, 0.0001);
}

test "18. Impact physics: unshielded entity hit inflicts Levitation I for 200 ticks (10.0 seconds)" {
    var bullet = GuidedShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{};

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(result.levitation_applied);
    try std.testing.expectEqual(@as(u32, 200), result.levitation_duration_ticks);
    try std.testing.expectEqual(@as(u8, 1), result.levitation_level);
    try std.testing.expect(target.isLevitating());
    try std.testing.expectEqual(@as(u32, 200), target.levitation.?.duration_ticks);
}

test "19. Impact physics: unshielded entity hit consumes bullet (alive = false)" {
    var bullet = GuidedShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{};

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(result.bullet_destroyed);
    try std.testing.expect(!bullet.alive);
}

test "20. Impact physics: subsequent hit on dead bullet deals 0 damage" {
    var bullet = GuidedShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{};

    _ = resolveImpact(&bullet, &target);
    const second = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(f32, 0.0), second.damage_dealt);
    try std.testing.expect(!second.levitation_applied);
}

test "21. Shield deflection: blocking shield facing bullet incoming vector absorbs 100% damage (0 HP dealt)" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 5.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .health = 20.0,
        .shield = .{
            .is_blocking = true,
            .facing_direction = .{ 0.0, 0.0, 1.0 }, // facing +Z toward incoming bullet
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(result.shield_blocked);
    try std.testing.expectEqual(@as(f32, 0.0), result.damage_dealt);
    try std.testing.expectEqual(@as(f32, 20.0), target.health);
}

test "22. Shield deflection: blocking shield completely negates Levitation effect (0 ticks applied)" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 5.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .shield = .{
            .is_blocking = true,
            .facing_direction = .{ 0.0, 0.0, 1.0 },
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(!result.levitation_applied);
    try std.testing.expectEqual(@as(u32, 0), result.levitation_duration_ticks);
    try std.testing.expect(!target.isLevitating());
}

test "23. Shield deflection: blocking shield emits metallic clang sound effect" {
    var bullet = GuidedShulkerBullet.init(.{ 3.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .shield = .{
            .is_blocking = true,
            .facing_direction = .{ 1.0, 0.0, 0.0 },
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(SoundEffect.shield_block_metallic_clang, result.sound_effect.?);
}

test "24. Shield deflection: blocking shield suffers durability wear" {
    var bullet = GuidedShulkerBullet.init(.{ 3.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .shield = .{
            .is_blocking = true,
            .durability = SHIELD_MAX_DURABILITY,
            .facing_direction = .{ 1.0, 0.0, 0.0 },
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(u16, 1), result.shield_durability_damage);
    try std.testing.expectEqual(@as(u16, SHIELD_MAX_DURABILITY - 1), target.shield.durability);
}

test "25. Shield deflection: shield facing away (dot <= 0) fails to block, taking full 4.0 damage and Levitation" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 5.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .health = 20.0,
        .shield = .{
            .is_blocking = true,
            .facing_direction = .{ 0.0, 0.0, -1.0 }, // facing opposite direction
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(!result.shield_blocked);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), result.damage_dealt, 0.0001);
    try std.testing.expect(result.levitation_applied);
}

test "26. Shield deflection: unraised shield fails to block, taking full 4.0 damage and Levitation" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 5.0 }, 1, .{ 0.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 0.0, 0.0, 0.0 },
        .health = 20.0,
        .shield = .{
            .is_blocking = false, // shield lowered
            .facing_direction = .{ 0.0, 0.0, 1.0 },
        },
    };

    const result = resolveImpact(&bullet, &target);
    try std.testing.expect(!result.shield_blocked);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), result.damage_dealt, 0.0001);
    try std.testing.expect(result.levitation_applied);
}

test "27. Attack deflection: striking bullet with fist deflects and destroys bullet (is_deflected = true, 0 player damage)" {
    var bullet = GuidedShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    const res = bullet.deflectWithAttack(.fist, null);
    try std.testing.expect(res.is_deflected);
    try std.testing.expect(res.bullet_destroyed);
    try std.testing.expect(bullet.is_deflected);
    try std.testing.expect(!bullet.alive);

    var target = EntityKinematics{};
    const impact = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(f32, 0.0), impact.damage_dealt);
}

test "28. Attack deflection: striking bullet with sword deflects bullet (is_deflected = true, 0 player damage)" {
    var bullet = GuidedShulkerBullet.init(.{ 2.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    const res = bullet.deflectWithAttack(.sword, null);
    try std.testing.expect(res.is_deflected);
    try std.testing.expect(bullet.is_deflected);
}

test "29. Attack deflection: striking bullet with axe deflects bullet (is_deflected = true, 0 player damage)" {
    var bullet = GuidedShulkerBullet.init(.{ 2.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    const res = bullet.deflectWithAttack(.axe, null);
    try std.testing.expect(res.is_deflected);
    try std.testing.expect(bullet.is_deflected);
}

test "30. Attack deflection: striking bullet with projectile arrow deflects bullet away with redirected velocity" {
    var bullet = GuidedShulkerBullet.init(.{ 2.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    const aim = [3]f32{ 0.0, 1.0, 0.0 }; // deflected upward
    const res = bullet.deflectWithAttack(.arrow, aim);
    try std.testing.expect(res.is_deflected);
    try std.testing.expect(!res.bullet_destroyed);
    try std.testing.expect(bullet.velocity[1] > 0.0);
}

test "31. Attack deflection: deflected bullet deals 0 damage to player on subsequent collision" {
    var bullet = GuidedShulkerBullet.init(.{ 1.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    _ = bullet.deflectWithAttack(.arrow, .{ 1.0, 0.0, 0.0 });
    try std.testing.expect(bullet.is_deflected);

    var target = EntityKinematics{ .health = 20.0 };
    const res = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
    try std.testing.expect(!res.levitation_applied);
    try std.testing.expectEqual(@as(f32, 20.0), target.health);
}

test "32. Attack deflection: swatWithMelee immediately destroys bullet and marks is_deflected" {
    var bullet = GuidedShulkerBullet.init(.{ 3.0, 0.0, 0.0 }, 1, .{ 0.0, 0.0, 0.0 });
    try std.testing.expect(bullet.swatWithMelee());
    try std.testing.expect(bullet.is_deflected);
    try std.testing.expect(!bullet.alive);
    try std.testing.expect(!bullet.swatWithMelee());
}

test "33. Levitation kinematics: Levitation I applies constant vertical upward velocity of +0.05 blocks/tick (+1.0 m/s)" {
    const lev = LevitationEffect.init(1, 200);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), lev.upwardVelocityBlocksPerTick(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), lev.upwardVelocityMetersPerSecond(), 0.0001);
}

test "34. Levitation kinematics: Levitation II applies +0.10 blocks/tick (+2.0 m/s)" {
    const lev = LevitationEffect.init(2, 200);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), lev.upwardVelocityBlocksPerTick(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), lev.upwardVelocityMetersPerSecond(), 0.0001);
}

test "35. Levitation kinematics: overrides downward gravity and floats entity smoothly upward" {
    var entity = EntityKinematics{
        .position = .{ 0.0, 10.0, 0.0 },
        .velocity = .{ 0.0, 0.0, 0.0 },
    };
    entity.applyLevitation(1, 200);

    // Run 20 ticks (1 second) of physics with zero movement inputs
    for (0..20) |_| {
        entity.tickPhysics(.{ 0.0, 0.0 });
    }

    // In 1 second at +1.0 m/s, position should rise by ~1.0 meter
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), entity.position[1], 0.01);
    // Vertical velocity should remain held at +1.0 m/s
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), entity.velocity[1], 0.001);
}

test "36. Levitation kinematics: horizontal movement remains controllable with input and air drag" {
    var entity = EntityKinematics{};
    entity.applyLevitation(1, 200);

    // Player inputs forward X acceleration
    entity.tickPhysics(.{ 2.0, 0.0 });
    try std.testing.expect(entity.velocity[0] > 0.0);
    try std.testing.expect(entity.position[0] > 0.0);

    // Levitation remains intact vertically
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), entity.velocity[1], 0.001);
}

test "37. Levitation kinematics: milk bucket drinking immediately clears Levitation effect" {
    var entity = EntityKinematics{};
    entity.applyLevitation(1, 200);
    try std.testing.expect(entity.isLevitating());

    const sound = drinkMilkBucket(&entity);
    try std.testing.expectEqual(SoundEffect.milk_drink, sound);
    try std.testing.expect(!entity.isLevitating());
}

test "38. Levitation kinematics: milk drinking immediately restores normal downward gravity acceleration" {
    var entity = EntityKinematics{
        .position = .{ 0.0, 20.0, 0.0 },
        .velocity = .{ 0.0, 1.0, 0.0 },
    };
    entity.applyLevitation(1, 200);

    // Drink milk bucket to cure levitation
    _ = drinkMilkBucket(&entity);

    // Advance 1 tick: normal downward gravity must accelerate entity downward
    entity.tickPhysics(.{ 0.0, 0.0 });
    // vy = 1.0 - 25.0 * 0.05 = -0.25 m/s
    try std.testing.expect(entity.velocity[1] < 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, -0.25), entity.velocity[1], 0.001);
}

test "39. Levitation kinematics: effect expiration after 200 ticks immediately restores normal downward gravity" {
    var entity = EntityKinematics{
        .position = .{ 0.0, 20.0, 0.0 },
    };
    entity.applyLevitation(1, 200);

    // Tick for 200 game ticks
    for (0..200) |_| {
        entity.tickPhysics(.{ 0.0, 0.0 });
    }

    try std.testing.expect(!entity.isLevitating());

    // Tick 201: downward gravity is applied
    const vy_before = entity.velocity[1];
    entity.tickPhysics(.{ 0.0, 0.0 });
    try std.testing.expect(entity.velocity[1] < vy_before);
}

test "40. Flight simulation: multi-tick trajectory simulation successfully homes and hits target" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 1.0, 0.0, 0.0 });
    var target = EntityKinematics{
        .position = .{ 1.0, 0.0, 0.0 },
        .health = 20.0,
    };

    const sim = simulateFlight(&bullet, &target, 100, 0.5);
    try std.testing.expect(sim.hit);
    try std.testing.expect(!sim.timed_out);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), target.health, 0.0001);
    try std.testing.expect(target.isLevitating());
}

test "41. Timeout despawn: bullet despawns after 60 seconds (1200 ticks) of flight" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 1000.0, 0.0, 0.0 });
    try std.testing.expect(bullet.alive);

    for (0..1200) |_| {
        bullet.tick(null);
    }

    try std.testing.expect(!bullet.alive);
    try std.testing.expectEqual(@as(u32, 1200), bullet.age_ticks);
}

test "42. Despawned bullet stops advancing and cannot deal damage" {
    var bullet = GuidedShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, 1, .{ 100.0, 0.0, 0.0 });
    bullet.alive = false;

    const pos_before = bullet.position;
    bullet.tick(null);
    try std.testing.expectEqual(pos_before, bullet.position);

    var target = EntityKinematics{ .health = 20.0 };
    const res = resolveImpact(&bullet, &target);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_dealt);
    try std.testing.expectEqual(@as(f32, 20.0), target.health);
}

test "all six cardinal faces can be attachment orientations" {
    const faces = [_]Direction{ .up, .down, .north, .south, .east, .west };
    for (faces) |face| try std.testing.expectEqual(face, ShulkerShell.init(face).attachment);
}

test "each face has a distinct cardinal support offset" {
    try std.testing.expectEqual([3]i32{ 0, 1, 0 }, Direction.up.offset());
    try std.testing.expectEqual([3]i32{ 0, -1, 0 }, Direction.down.offset());
    try std.testing.expectEqual([3]i32{ 0, 0, -1 }, Direction.north.offset());
    try std.testing.expectEqual([3]i32{ 0, 0, 1 }, Direction.south.offset());
    try std.testing.expectEqual([3]i32{ 1, 0, 0 }, Direction.east.offset());
    try std.testing.expectEqual([3]i32{ -1, 0, 0 }, Direction.west.offset());
}

test "default peek height is closed" {
    const shulker = ShulkerShell{};
    try std.testing.expectEqual(@as(f32, 0.0), shulker.peek_height);
    try std.testing.expect(shulker.isClosed());
}

test "peek height zero remains closed" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(0.0);
    try std.testing.expect(shulker.isClosed());
}

test "any positive peek height opens the shell" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(0.001);
    try std.testing.expect(!shulker.isClosed());
}

test "peek height can be fully open" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), shulker.peek_height);
}

test "peek height clamps below zero" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(-1.0);
    try std.testing.expectEqual(@as(f32, 0.0), shulker.peek_height);
}

test "peek height clamps above one" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(2.0);
    try std.testing.expectEqual(@as(f32, 1.0), shulker.peek_height);
}

test "closed shell has twenty armor points" {
    try std.testing.expectEqual(CLOSED_ARMOR_POINTS, (ShulkerShell{}).armorPoints());
}

test "closed shell reduces damage by eighty percent" {
    try std.testing.expectEqual(@as(f32, 0.8), (ShulkerShell{}).damageReduction());
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), (ShulkerShell{}).damageAfterArmor(10.0), 0.0001);
}

test "closed shell damage cannot become negative" {
    try std.testing.expectEqual(@as(f32, 0.0), (ShulkerShell{}).damageAfterArmor(-5.0));
}

test "peeking shell has zero armor" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(0.5);
    try std.testing.expectEqual(@as(f32, 0.0), shulker.armorPoints());
}

test "peeking shell takes full melee damage" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(0.25);
    const result = shulker.applyDamage(.melee, 7.0);
    try std.testing.expectEqual(@as(f32, 7.0), result.damage_taken);
    try std.testing.expect(!result.is_deflected);
}

test "fully open shell takes full melee damage" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(1.0);
    try std.testing.expectEqual(@as(f32, 4.0), shulker.applyDamage(.melee, 4.0).damage_taken);
}

test "closed shell deflects arrows with zero damage" {
    const result = (ShulkerShell{}).applyDamage(.arrow, 20.0);
    try std.testing.expect(result.is_deflected);
    try std.testing.expectEqual(@as(f32, 0.0), result.damage_taken);
}

test "closed shell deflects other projectiles with zero damage" {
    const result = (ShulkerShell{}).applyDamage(.projectile, 9.0);
    try std.testing.expect(result.is_deflected);
    try std.testing.expectEqual(@as(f32, 0.0), result.damage_taken);
}

test "peeking shell receives arrow damage normally" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(0.1);
    const result = shulker.applyDamage(.arrow, 6.0);
    try std.testing.expect(!result.is_deflected);
    try std.testing.expectEqual(@as(f32, 6.0), result.damage_taken);
}

test "open shell receives projectile damage normally" {
    var shulker = ShulkerShell{};
    shulker.setPeekHeight(1.0);
    const result = shulker.applyDamage(.projectile, 8.0);
    try std.testing.expect(!result.is_deflected);
    try std.testing.expectEqual(@as(f32, 8.0), result.damage_taken);
}

test "shulker is fire immune" {
    try std.testing.expect(ShulkerShell.isImmuneToFire);
    try std.testing.expectEqual(@as(f32, 0.0), (ShulkerShell{}).applyDamage(.fire, 12.0).damage_taken);
}

test "shulker is lava immune" {
    try std.testing.expect(ShulkerShell.isImmuneToLava);
    try std.testing.expectEqual(@as(f32, 0.0), (ShulkerShell{}).applyDamage(.lava, 20.0).damage_taken);
}

test "teleport chance is exactly one quarter of unit interval" {
    try std.testing.expect(shouldTeleportAfterDamage(0.0));
    try std.testing.expect(shouldTeleportAfterDamage(0.2499));
    try std.testing.expect(!shouldTeleportAfterDamage(0.25));
    try std.testing.expect(!shouldTeleportAfterDamage(0.9999));
}

test "teleport rejects rolls outside the unit interval" {
    try std.testing.expect(!shouldTeleportAfterDamage(-0.01));
    try std.testing.expect(!shouldTeleportAfterDamage(1.0));
}

test "eligible teleport face can be selected at origin" {
    const candidates = [_]BlockFace{.{ .position = .{}, .face = .north }};
    try std.testing.expectEqual(Direction.north, chooseTeleportFace(.{}, &candidates, 0.0).?.face);
}

test "teleport face exactly eight blocks away is eligible" {
    const candidates = [_]BlockFace{.{ .position = .{ .x = 8.0 }, .face = .east }};
    try std.testing.expect(chooseTeleportFace(.{}, &candidates, 0.0) != null);
}

test "teleport face beyond eight blocks is rejected" {
    const candidates = [_]BlockFace{.{ .position = .{ .x = 8.01 }, .face = .east }};
    try std.testing.expect(chooseTeleportFace(.{}, &candidates, 0.0) == null);
}

test "teleport range uses three dimensional distance" {
    const candidates = [_]BlockFace{.{ .position = .{ .x = 6.0, .y = 6.0 }, .face = .up }};
    try std.testing.expect(chooseTeleportFace(.{}, &candidates, 0.0) == null);
}

test "teleport ignores non-solid faces" {
    const candidates = [_]BlockFace{.{ .position = .{ .x = 1.0 }, .face = .west, .is_solid = false }};
    try std.testing.expect(chooseTeleportFace(.{}, &candidates, 0.0) == null);
}

test "teleport selects uniformly indexed eligible faces" {
    const candidates = [_]BlockFace{
        .{ .position = .{ .x = 1.0 }, .face = .north },
        .{ .position = .{ .x = 2.0 }, .face = .south },
        .{ .position = .{ .x = 9.0 }, .face = .up },
    };
    try std.testing.expectEqual(Direction.north, chooseTeleportFace(.{}, &candidates, 0.0).?.face);
    try std.testing.expectEqual(Direction.south, chooseTeleportFace(.{}, &candidates, 0.75).?.face);
}

test "damage teleport reaction requires chance and valid destination" {
    const candidates = [_]BlockFace{.{ .position = .{ .z = 3.0 }, .face = .south }};
    try std.testing.expect(teleportReaction(0.1, 0.5, .{}, &candidates).teleported);
    try std.testing.expect(!teleportReaction(0.3, 0.5, .{}, &candidates).teleported);
}

test "damage teleport reaction stays put if no solid face is nearby" {
    const candidates = [_]BlockFace{.{ .position = .{ .z = 9.0 }, .face = .south }};
    try std.testing.expect(!teleportReaction(0.1, 0.5, .{}, &candidates).teleported);
}

test "one thousand teleport trials demonstrate the 25 percent threshold" {
    var successful: usize = 0;
    for (0..1000) |i| {
        const roll = @as(f32, @floatFromInt(i)) / 1000.0;
        if (shouldTeleportAfterDamage(roll)) successful += 1;
    }
    try std.testing.expectEqual(@as(usize, 250), successful);
}

test "base shulker shell drop chance is fifty percent" {
    try std.testing.expectEqual(@as(f32, 0.5), shulkerShellDropChance(0));
}

test "Looting increases shell chance by one sixth per level" {
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 3.0), shulkerShellDropChance(1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0 / 6.0), shulkerShellDropChance(2), 0.0001);
}

test "Looting three guarantees a shell drop" {
    try std.testing.expectEqual(@as(f32, 1.0), shulkerShellDropChance(3));
    try std.testing.expectEqual(@as(u8, 1), rollDefeatDrops(0.9999, 3).shell_count);
}

test "shell drop chance stays capped at one above Looting three" {
    try std.testing.expectEqual(@as(f32, 1.0), shulkerShellDropChance(10));
}

test "shell drop roll produces zero or one shulker shell" {
    const missed = rollDefeatDrops(0.5, 0);
    const dropped = rollDefeatDrops(0.499, 0);
    try std.testing.expectEqual(@as(u8, 0), missed.shell_count);
    try std.testing.expectEqual(@as(u8, 1), dropped.shell_count);
    try std.testing.expectEqual(ItemType.shulker_shell, dropped.item);
}

test "defeat grants five experience regardless of shell roll" {
    try std.testing.expectEqual(@as(u8, 5), rollDefeatDrops(0.99, 0).experience);
}

test "shell drop frequency matches the base half chance" {
    var dropped: usize = 0;
    for (0..1000) |i| {
        const roll = @as(f32, @floatFromInt(i)) / 1000.0;
        if (rollDefeatDrops(roll, 0).shell_count == 1) dropped += 1;
    }
    try std.testing.expectEqual(@as(usize, 500), dropped);
}

test "shell drop frequency reaches certainty at Looting three" {
    var dropped: usize = 0;
    for (0..1000) |i| {
        const roll = @as(f32, @floatFromInt(i)) / 1000.0;
        if (rollDefeatDrops(roll, 3).shell_count == 1) dropped += 1;
    }
    try std.testing.expectEqual(@as(usize, 1000), dropped);
}
