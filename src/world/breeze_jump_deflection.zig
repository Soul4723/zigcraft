const std = @import("std");

// ============================================================================
// Milestone 524: Breeze Wind Charge Rocket Jumps & Deflection Dynamics
// ============================================================================
// Specifications:
// 1. Wind Charge Rocket Jump Mechanics:
//    - Player right-clicking Wind Charge (ItemType.wind_charge):
//      * Consumes 1 wind charge from inventory.
//      * Launches projectile forward at 28.0 m/s from eye position.
//      * Resets accumulated fall distance to 0 at the moment of launch
//        (fall_distance = 0.0), allowing safe rocket jumping mid-fall.
//      * On ground impact near player (d <= 1.5m):
//        - Applies massive vertical self-boost velocity: vy = +9.5 m/s
//          (~5.5 blocks vertical height).
//        - Resets accumulated fall distance to 0 (fall_distance = 0.0).
// 2. Horizontal Rocket Dash:
//    - Aiming slightly behind or at angle: converts vertical impulse into
//      horizontal dash momentum (v_horiz = 7.0 m/s).
//    - Dash direction opposes aim's horizontal vector (propelling player forward
//      when aiming behind).
// 3. Breeze Entity Automatic Projectile Deflection:
//    - Any physical projectile (Arrow, Trident, Snowball, Egg, Splash Potion)
//      colliding with Breeze is automatically deflected:
//      v_reflected = -v * 0.8 + random_deflection
//    - Deals strictly 0 damage to Breeze entity (health untouched).
//    - Deflected projectile reflects toward shooter or nearby entities.
// ============================================================================

// ============================================================================
// Constants
// ============================================================================

/// Vertical boost velocity applied to player upon ground rocket jump (+9.5 m/s).
pub const VERTICAL_BOOST_VY: f32 = 9.5;

/// Horizontal dash velocity attained when converting rocket jump impulse (7.0 m/s).
pub const HORIZONTAL_DASH_SPEED: f32 = 7.0;

/// Maximum radial distance from ground impact to player for rocket jump trigger (1.5m).
pub const ROCKET_JUMP_RADIUS: f32 = 1.5;
pub const ROCKET_JUMP_RADIUS_SQ: f32 = ROCKET_JUMP_RADIUS * ROCKET_JUMP_RADIUS;
pub const ROCKET_JUMP_MAX_DISTANCE: f32 = ROCKET_JUMP_RADIUS;

/// Deflection damping multiplier on incoming velocity (-v * 0.8).
pub const DEFLECTION_DAMPING: f32 = 0.8;

/// Forward projectile launch speed of player-fired Wind Charge (28.0 m/s).
pub const WIND_CHARGE_LAUNCH_SPEED: f32 = 28.0;

/// Estimated jump apex height reached by +9.5 m/s vertical boost (~5.5 blocks).
pub const ESTIMATED_JUMP_HEIGHT_BLOCKS: f32 = 5.5;

/// Maximum health of a Breeze mob entity (30.0 HP / 15 hearts).
pub const BREEZE_MAX_HEALTH: f32 = 30.0;

/// Eye height offset above player base position (1.62m).
pub const PLAYER_EYE_HEIGHT: f32 = 1.62;

// ============================================================================
// Vectors & Mathematics
// ============================================================================

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn zero() Vec3 {
        return .{};
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn scale(a: Vec3, s: f32) Vec3 {
        return .{ .x = a.x * s, .y = a.y * s, .z = a.z * s };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn lengthSq(self: Vec3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn length(self: Vec3) f32 {
        return @sqrt(self.lengthSq());
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = self.length();
        if (len < 0.00001) return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
        return .{ .x = self.x / len, .y = self.y / len, .z = self.z / len };
    }

    pub fn distanceSq(a: Vec3, b: Vec3) f32 {
        return sub(a, b).lengthSq();
    }

    pub fn distance(a: Vec3, b: Vec3) f32 {
        return @sqrt(distanceSq(a, b));
    }
};

// ============================================================================
// Items & Inventory Management
// ============================================================================

/// ItemType mirroring inventory.zig discriminants for Wind Charge and projectile items.
pub const ItemType = enum(u16) {
    none = 0,
    snowball = 28,
    spectral_arrow = 96,
    arrow = 97,
    egg = 114,
    trident = 171,
    breeze_rod = 371,
    wind_charge = 372,
    heavy_core = 373,
    mace = 374,
    splash_potion = 453,
    other = 999,

    pub fn isWindCharge(self: ItemType) bool {
        return self == .wind_charge;
    }

    pub fn isPhysicalProjectileItem(self: ItemType) bool {
        return switch (self) {
            .arrow, .spectral_arrow, .trident, .snowball, .egg, .splash_potion => true,
            else => false,
        };
    }
};

pub const ItemStack = struct {
    item: ItemType = .none,
    count: u8 = 0,

    pub fn isEmpty(self: ItemStack) bool {
        return self.item == .none or self.count == 0;
    }

    pub fn decrement(self: *ItemStack, amount: u8) void {
        if (amount >= self.count) {
            self.item = .none;
            self.count = 0;
        } else {
            self.count -= amount;
        }
    }
};

pub const PlayerInventory = struct {
    pub const TOTAL_SLOTS: usize = 24;

    slots: [TOTAL_SLOTS]ItemStack = [_]ItemStack{.{}} ** TOTAL_SLOTS,
    selected_slot: usize = 0,

    pub fn init() PlayerInventory {
        return .{};
    }

    pub fn getHeldItem(self: *const PlayerInventory) ItemStack {
        if (self.selected_slot < self.slots.len) {
            return self.slots[self.selected_slot];
        }
        return .{};
    }

    pub fn countItem(self: *const PlayerInventory, item: ItemType) u32 {
        var total: u32 = 0;
        for (self.slots) |slot| {
            if (slot.item == item) total += slot.count;
        }
        return total;
    }

    pub fn consumeOne(self: *PlayerInventory, item: ItemType) bool {
        // Prefer consuming from active held slot
        if (self.selected_slot < self.slots.len and
            self.slots[self.selected_slot].item == item and
            self.slots[self.selected_slot].count > 0)
        {
            self.slots[self.selected_slot].decrement(1);
            return true;
        }

        // Otherwise scan inventory
        for (&self.slots) |*slot| {
            if (slot.item == item and slot.count > 0) {
                slot.decrement(1);
                return true;
            }
        }
        return false;
    }
};

// ============================================================================
// Projectiles & Breeze Deflection Mechanics
// ============================================================================

pub const ProjectileKind = enum {
    arrow,
    spectral_arrow,
    trident,
    snowball,
    egg,
    splash_potion,
    wind_charge,
    other,

    pub fn isPhysical(self: ProjectileKind) bool {
        return switch (self) {
            .arrow, .spectral_arrow, .trident, .snowball, .egg, .splash_potion => true,
            .wind_charge, .other => false,
        };
    }
};

pub const Projectile = struct {
    kind: ProjectileKind,
    position: Vec3 = .{},
    velocity: Vec3 = .{},
    shooter_id: ?u32 = null,
    is_deflected: bool = false,
    damage: f32 = 4.0,

    pub fn init(kind: ProjectileKind, pos: Vec3, vel: Vec3, shooter_id: ?u32) Projectile {
        return .{
            .kind = kind,
            .position = pos,
            .velocity = vel,
            .shooter_id = shooter_id,
            .is_deflected = false,
            .damage = defaultDamage(kind),
        };
    }

    pub fn defaultDamage(kind: ProjectileKind) f32 {
        return switch (kind) {
            .arrow, .spectral_arrow => 4.0,
            .trident => 9.0,
            .snowball, .egg => 0.0,
            .splash_potion => 6.0,
            .wind_charge => 1.0,
            .other => 2.0,
        };
    }

    pub fn advance(self: *Projectile, dt: f32) void {
        self.position = self.position.add(self.velocity.scale(dt));
    }
};

pub const DeflectionResult = struct {
    velocity: Vec3,
    is_deflected: bool,
    damage_applied_to_breeze: f32,
    target_pos: ?Vec3 = null,
};

/// Deflects incoming physical projectiles colliding with Breeze:
/// v_reflected = -v * 0.8 + random_deflection
/// Physical projectiles deal 0 damage to Breeze and are marked is_deflected = true.
/// Non-physical projectiles are not deflected and apply incoming damage.
pub fn deflectProjectileWithDamage(
    kind: ProjectileKind,
    incoming_vel: Vec3,
    random_deflection: Vec3,
    incoming_damage: f32,
) DeflectionResult {
    if (!kind.isPhysical()) {
        return .{
            .velocity = incoming_vel,
            .is_deflected = false,
            .damage_applied_to_breeze = incoming_damage,
        };
    }

    const reflected = Vec3{
        .x = -incoming_vel.x * DEFLECTION_DAMPING + random_deflection.x,
        .y = -incoming_vel.y * DEFLECTION_DAMPING + random_deflection.y,
        .z = -incoming_vel.z * DEFLECTION_DAMPING + random_deflection.z,
    };

    return .{
        .velocity = reflected,
        .is_deflected = true,
        .damage_applied_to_breeze = 0.0,
    };
}

/// Deflects incoming physical projectiles using default damage for the kind.
pub fn deflectProjectile(
    kind: ProjectileKind,
    incoming_vel: Vec3,
    random_deflection: Vec3,
) DeflectionResult {
    return deflectProjectileWithDamage(kind, incoming_vel, random_deflection, Projectile.defaultDamage(kind));
}

/// Deflects incoming physical projectile toward a specific target (shooter or nearby entity).
pub fn deflectTowardTarget(
    kind: ProjectileKind,
    incoming_vel: Vec3,
    breeze_pos: Vec3,
    target_pos: Vec3,
    random_deflection: Vec3,
) DeflectionResult {
    if (!kind.isPhysical()) {
        return .{
            .velocity = incoming_vel,
            .is_deflected = false,
            .damage_applied_to_breeze = Projectile.defaultDamage(kind),
        };
    }

    const to_target = target_pos.sub(breeze_pos);
    const dist = to_target.length();
    const speed = incoming_vel.length() * DEFLECTION_DAMPING;
    const base_vel = if (dist > 0.0001)
        to_target.normalize().scale(speed)
    else
        incoming_vel.scale(-DEFLECTION_DAMPING);

    return .{
        .velocity = base_vel.add(random_deflection),
        .is_deflected = true,
        .damage_applied_to_breeze = 0.0,
        .target_pos = target_pos,
    };
}

pub const BreezeEntity = struct {
    position: Vec3 = .{},
    health: f32 = BREEZE_MAX_HEALTH,
    max_health: f32 = BREEZE_MAX_HEALTH,
    is_alive: bool = true,
    deflected_count: u32 = 0,

    pub fn init(pos: Vec3) BreezeEntity {
        return .{
            .position = pos,
            .health = BREEZE_MAX_HEALTH,
            .max_health = BREEZE_MAX_HEALTH,
            .is_alive = true,
            .deflected_count = 0,
        };
    }

    pub fn handleProjectileCollision(
        self: *BreezeEntity,
        projectile: *Projectile,
        random_deflection: Vec3,
    ) DeflectionResult {
        const result = deflectProjectileWithDamage(projectile.kind, projectile.velocity, random_deflection, projectile.damage);
        if (result.is_deflected) {
            projectile.velocity = result.velocity;
            projectile.is_deflected = true;
            self.deflected_count += 1;
            // Zero damage applied to Breeze: health is untouched
        } else {
            self.takeDamage(result.damage_applied_to_breeze);
        }
        return result;
    }

    pub fn handleProjectileCollisionRedirect(
        self: *BreezeEntity,
        projectile: *Projectile,
        target_pos: Vec3,
        random_deflection: Vec3,
    ) DeflectionResult {
        const result = deflectTowardTarget(projectile.kind, projectile.velocity, self.position, target_pos, random_deflection);
        if (result.is_deflected) {
            projectile.velocity = result.velocity;
            projectile.is_deflected = true;
            self.deflected_count += 1;
        } else {
            self.takeDamage(result.damage_applied_to_breeze);
        }
        return result;
    }

    pub fn takeDamage(self: *BreezeEntity, amount: f32) void {
        if (amount <= 0.0 or !self.is_alive) return;
        self.health = @max(0.0, self.health - amount);
        if (self.health <= 0.0) {
            self.is_alive = false;
        }
    }
};

// ============================================================================
// Wind Charge Projectile Entity
// ============================================================================

pub const WindChargeProjectile = struct {
    position: Vec3,
    velocity: Vec3,
    owner_id: u32 = 0,
    active: bool = true,

    pub fn init(pos: Vec3, vel: Vec3, owner_id: u32) WindChargeProjectile {
        return .{
            .position = pos,
            .velocity = vel,
            .owner_id = owner_id,
            .active = true,
        };
    }

    pub fn advance(self: *WindChargeProjectile, dt: f32) void {
        if (!self.active) return;
        self.position = self.position.add(self.velocity.scale(dt));
    }

    pub fn checkGroundImpact(self: *WindChargeProjectile, ground_y: f32) ?Vec3 {
        if (self.position.y <= ground_y) {
            self.active = false;
            return Vec3.init(self.position.x, ground_y, self.position.z);
        }
        return null;
    }
};

// ============================================================================
// Rocket Jump & Horizontal Dash Kinematics
// ============================================================================

pub const RocketJumpImpulse = struct {
    vy: f32,
    v_horiz: f32,
    vx: f32 = 0.0,
    vz: f32 = 0.0,
    is_dash: bool = false,
};

/// Evaluates if ground impact point is within the <= 1.5m blast radius of player.
pub fn isWithinRocketJumpRadius(player_pos: Vec3, impact_pos: Vec3) bool {
    return player_pos.distanceSq(impact_pos) <= ROCKET_JUMP_RADIUS_SQ;
}

/// Calculates angle-dependent horizontal dash velocity (m/s) based on deviation
/// angle from straight downward aim (0° = straight down, 45° = angled rocket dash).
pub fn calculateAngleDashVelocity(angle_deg: f32) f32 {
    if (angle_deg <= 0.0) return 0.0;
    if (angle_deg >= 45.0) return HORIZONTAL_DASH_SPEED;
    return HORIZONTAL_DASH_SPEED * (angle_deg / 45.0);
}

/// Calculates angle-dependent horizontal dash velocity based on camera pitch in degrees
/// (-90° = straight down -> 0.0 m/s; -45° = angled dash -> 7.0 m/s).
pub fn calculateDashVelocityFromPitch(pitch_deg: f32) f32 {
    const angle_from_down = std.math.clamp(pitch_deg + 90.0, 0.0, 90.0);
    return calculateAngleDashVelocity(angle_from_down);
}

/// Calculates rocket jump impulse from aim angle or aiming behind.
/// When aiming slightly behind or at angle: converts vertical impulse into horizontal
/// dash momentum (v_horiz = 7.0 m/s).
pub fn calculateRocketJumpImpulse(pitch_deg: f32, is_aiming_behind: bool) RocketJumpImpulse {
    if (is_aiming_behind) {
        // Aiming behind converts vertical impulse into full 7.0 m/s horizontal dash momentum
        const v_horiz = HORIZONTAL_DASH_SPEED;
        const remaining_vy = VERTICAL_BOOST_VY * 0.55;
        return .{
            .vy = remaining_vy,
            .v_horiz = v_horiz,
            .is_dash = true,
        };
    }

    const angle_from_down = std.math.clamp(pitch_deg + 90.0, 0.0, 90.0);
    const v_horiz = calculateAngleDashVelocity(angle_from_down);
    const is_dash = v_horiz > 0.001;

    // Converted vertical impulse: reduces vy as horizontal momentum is gained
    const conversion_ratio = v_horiz / HORIZONTAL_DASH_SPEED;
    const remaining_vy = VERTICAL_BOOST_VY * (1.0 - 0.45 * conversion_ratio);

    return .{
        .vy = remaining_vy,
        .v_horiz = v_horiz,
        .is_dash = is_dash,
    };
}

/// Calculates rocket jump 3D velocity vectors from aim direction vector.
/// Blast thrust propels player away from impact direction.
pub fn calculateRocketJumpImpulseFromAim(aim_dir: Vec3, is_aiming_behind: bool) RocketJumpImpulse {
    const norm = aim_dir.normalize();

    // Horizontal aim components
    const h_sq = norm.x * norm.x + norm.z * norm.z;
    const h_len = @sqrt(h_sq);

    // If aiming behind is explicitly flagged or aim direction points backward
    if (is_aiming_behind) {
        const v_horiz = HORIZONTAL_DASH_SPEED;
        const vy = VERTICAL_BOOST_VY * 0.55;
        // Direction pushes away from aim horizontal component: if aim is behind (-Z), impulse is forward (+Z)
        const dir_x = if (h_len > 0.001) -norm.x / h_len else 0.0;
        const dir_z = if (h_len > 0.001) -norm.z / h_len else 1.0; // default forward if pure down
        return .{
            .vy = vy,
            .v_horiz = v_horiz,
            .vx = dir_x * v_horiz,
            .vz = dir_z * v_horiz,
            .is_dash = true,
        };
    }

    // Angle away from straight downward (0, -1, 0)
    const down_cos = std.math.clamp(-norm.y, -1.0, 1.0);
    const angle_rad = std.math.acos(down_cos);
    const angle_deg = std.math.radiansToDegrees(angle_rad);

    const v_horiz = calculateAngleDashVelocity(angle_deg);
    const conversion_ratio = v_horiz / HORIZONTAL_DASH_SPEED;
    const vy = VERTICAL_BOOST_VY * (1.0 - 0.45 * conversion_ratio);

    var vx: f32 = 0.0;
    var vz: f32 = 0.0;
    if (h_len > 0.001 and v_horiz > 0.0) {
        // Pushes player away from blast impact point
        vx = (-norm.x / h_len) * v_horiz;
        vz = (-norm.z / h_len) * v_horiz;
    }

    return .{
        .vy = vy,
        .v_horiz = v_horiz,
        .vx = vx,
        .vz = vz,
        .is_dash = v_horiz > 0.001,
    };
}

/// Resolves rocket jump impulse if ground impact is within 1.5m radius, null otherwise.
pub fn resolveRocketJump(
    player_pos: Vec3,
    impact_pos: Vec3,
    aim_dir: Vec3,
    is_aiming_behind: bool,
) ?RocketJumpImpulse {
    if (!isWithinRocketJumpRadius(player_pos, impact_pos)) {
        return null;
    }
    return calculateRocketJumpImpulseFromAim(aim_dir, is_aiming_behind);
}

/// Calculates estimated jump apex height for a vertical launch velocity (~5.5 blocks for 9.5 m/s).
pub fn estimateJumpHeight(vy: f32) f32 {
    const g_eff: f32 = (VERTICAL_BOOST_VY * VERTICAL_BOOST_VY) / (2.0 * ESTIMATED_JUMP_HEIGHT_BLOCKS);
    return (vy * vy) / (2.0 * g_eff);
}

// ============================================================================
// Player Controller & Action Handlers
// ============================================================================

pub const Player = struct {
    position: Vec3 = .{},
    velocity: Vec3 = .{},
    fall_distance: f32 = 0.0,
    pitch: f32 = -90.0,
    yaw: f32 = 0.0,
    inventory: PlayerInventory = .{},
    is_grounded: bool = true,

    pub fn init(pos: Vec3) Player {
        return .{
            .position = pos,
            .velocity = .{},
            .fall_distance = 0.0,
            .pitch = -90.0,
            .yaw = 0.0,
            .inventory = PlayerInventory.init(),
            .is_grounded = true,
        };
    }

    pub fn eyePosition(self: Player) Vec3 {
        return .{
            .x = self.position.x,
            .y = self.position.y + PLAYER_EYE_HEIGHT,
            .z = self.position.z,
        };
    }

    /// Player right-clicking Wind Charge:
    /// 1. Consumes 1 wind charge from player inventory.
    /// 2. Resets accumulated fall distance to 0 at the moment of launch (fall_distance = 0.0).
    /// 3. Launches Wind Charge projectile forward at 28.0 m/s.
    pub fn rightClickWindCharge(self: *Player, aim_dir: Vec3) ?WindChargeProjectile {
        if (!self.inventory.consumeOne(.wind_charge)) {
            return null;
        }

        // Resets accumulated fall distance to 0 at the moment of launch, allowing safe rocket jumping mid-fall
        self.fall_distance = 0.0;

        const launch_pos = self.eyePosition();
        const dir = aim_dir.normalize();
        const vel = dir.scale(WIND_CHARGE_LAUNCH_SPEED);

        return WindChargeProjectile.init(launch_pos, vel, 1);
    }

    /// Handles ground impact of wind charge near player (d <= 1.5m).
    /// Applies vertical boost vy = +9.5 m/s (or converted horizontal dash momentum),
    /// resets fall distance to 0.0, and sets airborne state.
    pub fn onGroundImpact(
        self: *Player,
        impact_pos: Vec3,
        aim_dir: Vec3,
        is_aiming_behind: bool,
    ) bool {
        const impulse = resolveRocketJump(self.position, impact_pos, aim_dir, is_aiming_behind) orelse return false;

        self.velocity.y = impulse.vy;
        self.velocity.x += impulse.vx;
        self.velocity.z += impulse.vz;
        self.fall_distance = 0.0;
        self.is_grounded = false;
        return true;
    }

    /// Pure vertical boost shortcut for straight down impact.
    pub fn applyVerticalBoost(self: *Player) void {
        self.velocity.y = VERTICAL_BOOST_VY;
        self.fall_distance = 0.0;
        self.is_grounded = false;
    }
};

/// Standalone helper for consuming 1 wind charge from inventory.
pub fn consumeWindCharge(inventory: *PlayerInventory) bool {
    return inventory.consumeOne(.wind_charge);
}

// ============================================================================
// Unit Tests (25+ Tests)
// ============================================================================

test "1. constants: vertical boost is 9.5 m/s, horizontal dash is 7.0 m/s, radius is 1.5m, deflection damping is 0.8" {
    try std.testing.expectApproxEqAbs(VERTICAL_BOOST_VY, 9.5, 0.0001);
    try std.testing.expectApproxEqAbs(HORIZONTAL_DASH_SPEED, 7.0, 0.0001);
    try std.testing.expectApproxEqAbs(ROCKET_JUMP_RADIUS, 1.5, 0.0001);
    try std.testing.expectApproxEqAbs(ROCKET_JUMP_RADIUS_SQ, 2.25, 0.0001);
    try std.testing.expectApproxEqAbs(DEFLECTION_DAMPING, 0.8, 0.0001);
    try std.testing.expectApproxEqAbs(WIND_CHARGE_LAUNCH_SPEED, 28.0, 0.0001);
    try std.testing.expectApproxEqAbs(ESTIMATED_JUMP_HEIGHT_BLOCKS, 5.5, 0.0001);
    try std.testing.expectApproxEqAbs(BREEZE_MAX_HEALTH, 30.0, 0.0001);
}

test "2. ground impact at 0.0m distance applies +9.5 m/s vertical self-boost" {
    var player = Player.init(Vec3.init(0.0, 64.0, 0.0));
    player.velocity.y = 0.0;

    const impact = Vec3.init(0.0, 64.0, 0.0);
    const triggered = player.onGroundImpact(impact, Vec3.init(0.0, -1.0, 0.0), false);

    try std.testing.expect(triggered);
    try std.testing.expectApproxEqAbs(player.velocity.y, 9.5, 0.001);
    try std.testing.expect(!player.is_grounded);
}

test "3. ground impact at 0.75m distance applies +9.5 m/s vertical self-boost" {
    var player = Player.init(Vec3.init(10.0, 64.0, 10.0));
    player.velocity.y = 0.0;

    const impact = Vec3.init(10.5, 64.0, 10.5); // dist = sqrt(0.5^2 + 0.5^2) ≈ 0.707m <= 1.5m
    const triggered = player.onGroundImpact(impact, Vec3.init(0.0, -1.0, 0.0), false);

    try std.testing.expect(triggered);
    try std.testing.expectApproxEqAbs(player.velocity.y, 9.5, 0.001);
}

test "4. ground impact at exact 1.5m boundary triggers rocket jump" {
    const player_pos = Vec3.init(0.0, 64.0, 0.0);
    const impact_pos = Vec3.init(1.5, 64.0, 0.0); // distance = exactly 1.5m

    try std.testing.expect(isWithinRocketJumpRadius(player_pos, impact_pos));

    var player = Player.init(player_pos);
    const triggered = player.onGroundImpact(impact_pos, Vec3.init(0.0, -1.0, 0.0), false);

    try std.testing.expect(triggered);
    try std.testing.expectApproxEqAbs(player.velocity.y, 9.5, 0.001);
}

test "5. ground impact at 1.51m outside threshold fails to trigger rocket jump" {
    const player_pos = Vec3.init(0.0, 64.0, 0.0);
    const impact_pos = Vec3.init(1.51, 64.0, 0.0); // distance = 1.51m > 1.5m

    try std.testing.expect(!isWithinRocketJumpRadius(player_pos, impact_pos));

    var player = Player.init(player_pos);
    player.velocity.y = 0.0;
    const triggered = player.onGroundImpact(impact_pos, Vec3.init(0.0, -1.0, 0.0), false);

    try std.testing.expect(!triggered);
    try std.testing.expectEqual(@as(f32, 0.0), player.velocity.y);
}

test "6. ground impact at 3.0m far away produces no rocket boost" {
    var player = Player.init(Vec3.init(0.0, 64.0, 0.0));
    player.velocity.y = 1.2;

    const impact = Vec3.init(3.0, 64.0, 0.0);
    const res = resolveRocketJump(player.position, impact, Vec3.init(0.0, -1.0, 0.0), false);

    try std.testing.expect(res == null);
    try std.testing.expect(!player.onGroundImpact(impact, Vec3.init(0.0, -1.0, 0.0), false));
    try std.testing.expectEqual(@as(f32, 1.2), player.velocity.y);
}

test "7. vertical self-boost reaches estimated ~5.5 blocks vertical height" {
    const apex_height = estimateJumpHeight(VERTICAL_BOOST_VY);
    try std.testing.expectApproxEqAbs(apex_height, 5.5, 0.01);
}

test "8. vertical boost overrides downward falling velocity" {
    var player = Player.init(Vec3.init(0.0, 70.0, 0.0));
    player.velocity.y = -15.0; // Rapid downward fall

    player.applyVerticalBoost();

    try std.testing.expectApproxEqAbs(player.velocity.y, 9.5, 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
}

test "9. fall distance resets to 0.0 at moment of wind charge launch" {
    var player = Player.init(Vec3.init(0.0, 80.0, 0.0));
    player.fall_distance = 25.4;
    player.inventory.slots[0] = .{ .item = .wind_charge, .count = 1 };

    const proj = player.rightClickWindCharge(Vec3.init(0.0, -1.0, 0.0));

    try std.testing.expect(proj != null);
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
}

test "10. fall distance resets to 0.0 when rocket jump boost applies" {
    var player = Player.init(Vec3.init(5.0, 64.0, 5.0));
    player.fall_distance = 18.2;

    const impact = Vec3.init(5.0, 64.0, 5.0);
    const ok = player.onGroundImpact(impact, Vec3.init(0.0, -1.0, 0.0), false);

    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
}

test "11. rocket jump mid-fall from 30m negates accumulated fall distance" {
    var player = Player.init(Vec3.init(0.0, 100.0, 0.0));
    player.fall_distance = 30.0; // Fatal fall height if uninterrupted
    player.inventory.slots[0] = .{ .item = .wind_charge, .count = 2 };

    // Fire downward mid-fall
    _ = player.rightClickWindCharge(Vec3.init(0.0, -1.0, 0.0));
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);

    // Simulate falling 1 meter before impact detonates
    player.fall_distance = 1.0;

    // Detonation at feet
    const impact = Vec3.init(0.0, 99.0, 0.0);
    const ok = player.onGroundImpact(impact, Vec3.init(0.0, -1.0, 0.0), false);

    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
    try std.testing.expectApproxEqAbs(player.velocity.y, 9.5, 0.001);
}

test "12. rocket jump straight down produces zero horizontal velocity" {
    const impulse = calculateRocketJumpImpulse(-90.0, false);

    try std.testing.expectApproxEqAbs(impulse.vy, 9.5, 0.001);
    try std.testing.expectApproxEqAbs(impulse.v_horiz, 0.0, 0.001);
    try std.testing.expect(!impulse.is_dash);
}

test "13. dash velocity is 0.0 m/s at 0 degrees tilt from downward" {
    const v = calculateAngleDashVelocity(0.0);
    try std.testing.expectApproxEqAbs(v, 0.0, 0.0001);
}

test "14. dash velocity scales with angle at 15 degrees tilt" {
    const v = calculateAngleDashVelocity(15.0);
    const expected = 7.0 * (15.0 / 45.0); // 2.333 m/s
    try std.testing.expectApproxEqAbs(v, expected, 0.001);
}

test "15. dash velocity scales with angle at 30 degrees tilt" {
    const v = calculateAngleDashVelocity(30.0);
    const expected = 7.0 * (30.0 / 45.0); // 4.666 m/s
    try std.testing.expectApproxEqAbs(v, expected, 0.001);
}

test "16. dash velocity reaches 7.0 m/s at 45 degrees tilt" {
    const v = calculateAngleDashVelocity(45.0);
    try std.testing.expectApproxEqAbs(v, 7.0, 0.0001);
}

test "17. dash velocity caps at 7.0 m/s for angles beyond 45 degrees" {
    try std.testing.expectApproxEqAbs(calculateAngleDashVelocity(60.0), 7.0, 0.0001);
    try std.testing.expectApproxEqAbs(calculateAngleDashVelocity(90.0), 7.0, 0.0001);
}

test "18. aiming slightly behind converts vertical impulse into 7.0 m/s horizontal dash" {
    const impulse = calculateRocketJumpImpulse(-80.0, true);

    try std.testing.expectApproxEqAbs(impulse.v_horiz, 7.0, 0.001);
    try std.testing.expect(impulse.is_dash);
    // Vertical velocity is partially converted into forward momentum
    try std.testing.expectApproxEqAbs(impulse.vy, 9.5 * 0.55, 0.001);
}

test "19. aiming behind pushes player forward in opposite horizontal direction" {
    // Player aims downward and backward along -Z: (0.0, -0.707, -0.707)
    const aim = Vec3.init(0.0, -0.707, -0.707);
    const impulse = calculateRocketJumpImpulseFromAim(aim, true);

    try std.testing.expect(impulse.is_dash);
    try std.testing.expectApproxEqAbs(impulse.v_horiz, 7.0, 0.01);
    // The horizontal impulse along Z must be POSITIVE (thrusting forward)
    try std.testing.expect(impulse.vz > 6.9);
    try std.testing.expectApproxEqAbs(impulse.vx, 0.0, 0.01);
}

test "20. horizontal dash converts vertical impulse into reduced upward velocity" {
    const pure_vertical = calculateRocketJumpImpulse(-90.0, false);
    const angled_dash = calculateRocketJumpImpulse(-45.0, false);

    try std.testing.expectApproxEqAbs(pure_vertical.vy, 9.5, 0.001);
    try std.testing.expectApproxEqAbs(angled_dash.v_horiz, 7.0, 0.001);
    try std.testing.expect(angled_dash.vy < pure_vertical.vy);
    try std.testing.expect(angled_dash.vy > 4.0);
}

test "21. pitch sweep: dash velocity monotonically increases from -90 to -45 degrees" {
    var last_v: f32 = -1.0;
    var pitch: f32 = -90.0;
    while (pitch <= -45.0) : (pitch += 5.0) {
        const v = calculateDashVelocityFromPitch(pitch);
        try std.testing.expect(v >= last_v);
        last_v = v;
    }
    try std.testing.expectApproxEqAbs(last_v, 7.0, 0.001);
}

test "22. arrow colliding with Breeze is automatically deflected with is_deflected true" {
    var breeze = BreezeEntity.init(Vec3.init(0.0, 10.0, 0.0));
    var arrow = Projectile.init(.arrow, Vec3.init(0.0, 10.0, -5.0), Vec3.init(0.0, 0.0, 20.0), 42);

    const result = breeze.handleProjectileCollision(&arrow, Vec3.zero());

    try std.testing.expect(result.is_deflected);
    try std.testing.expect(arrow.is_deflected);
    try std.testing.expectEqual(@as(u32, 1), breeze.deflected_count);
}

test "23. arrow deflection applies -v * 0.8 + random_deflection formula" {
    const incoming = Vec3.init(10.0, -2.0, 15.0);
    const random_deflection = Vec3.init(0.2, -0.1, 0.3);

    const result = deflectProjectile(.arrow, incoming, random_deflection);

    try std.testing.expect(result.is_deflected);
    try std.testing.expectApproxEqAbs(result.velocity.x, -10.0 * 0.8 + 0.2, 0.0001);
    try std.testing.expectApproxEqAbs(result.velocity.y, 2.0 * 0.8 - 0.1, 0.0001);
    try std.testing.expectApproxEqAbs(result.velocity.z, -15.0 * 0.8 + 0.3, 0.0001);
}

test "24. arrow deflection deals strictly 0 damage to Breeze entity (health remains 30.0)" {
    var breeze = BreezeEntity.init(Vec3.init(0.0, 5.0, 0.0));
    var arrow = Projectile.init(.arrow, Vec3.init(0.0, 5.0, 2.0), Vec3.init(0.0, 0.0, -25.0), 101);

    const result = breeze.handleProjectileCollision(&arrow, Vec3.zero());

    try std.testing.expectEqual(@as(f32, 0.0), result.damage_applied_to_breeze);
    try std.testing.expectEqual(@as(f32, 30.0), breeze.health);
    try std.testing.expect(breeze.is_alive);
}

test "25. spectral arrow deflects with 0 damage to Breeze" {
    var breeze = BreezeEntity.init(Vec3.zero());
    var arrow = Projectile.init(.spectral_arrow, Vec3.init(0.0, 0.0, 1.0), Vec3.init(0.0, 0.0, -10.0), null);

    const res = breeze.handleProjectileCollision(&arrow, Vec3.zero());

    try std.testing.expect(res.is_deflected);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_applied_to_breeze);
    try std.testing.expectEqual(@as(f32, 30.0), breeze.health);
}

test "26. trident colliding with Breeze deflects with 0.8 damping and 0 damage" {
    var breeze = BreezeEntity.init(Vec3.zero());
    var trident = Projectile.init(.trident, Vec3.init(0.0, 0.0, -4.0), Vec3.init(0.0, 0.0, 15.0), 99);

    const res = breeze.handleProjectileCollision(&trident, Vec3.zero());

    try std.testing.expect(res.is_deflected);
    try std.testing.expectApproxEqAbs(res.velocity.z, -12.0, 0.001); // -15.0 * 0.8
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_applied_to_breeze);
    try std.testing.expectEqual(@as(f32, 30.0), breeze.health);
}

test "27. snowball colliding with Breeze deflects with 0 damage" {
    var breeze = BreezeEntity.init(Vec3.zero());
    var snowball = Projectile.init(.snowball, Vec3.init(2.0, 0.0, 0.0), Vec3.init(-10.0, 0.0, 0.0), 1);

    const res = breeze.handleProjectileCollision(&snowball, Vec3.zero());

    try std.testing.expect(res.is_deflected);
    try std.testing.expectApproxEqAbs(res.velocity.x, 8.0, 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_applied_to_breeze);
}

test "28. egg colliding with Breeze deflects with 0 damage" {
    var breeze = BreezeEntity.init(Vec3.zero());
    var egg = Projectile.init(.egg, Vec3.init(0.0, 2.0, 0.0), Vec3.init(0.0, -8.0, 0.0), 2);

    const res = breeze.handleProjectileCollision(&egg, Vec3.zero());

    try std.testing.expect(res.is_deflected);
    try std.testing.expectApproxEqAbs(res.velocity.y, 6.4, 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_applied_to_breeze);
}

test "29. splash potion colliding with Breeze deflects with 0 damage" {
    var breeze = BreezeEntity.init(Vec3.zero());
    var potion = Projectile.init(.splash_potion, Vec3.init(0.0, 1.0, 0.0), Vec3.init(0.0, -5.0, 0.0), 3);

    const res = breeze.handleProjectileCollision(&potion, Vec3.zero());

    try std.testing.expect(res.is_deflected);
    try std.testing.expectApproxEqAbs(res.velocity.y, 4.0, 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), res.damage_applied_to_breeze);
    try std.testing.expectEqual(@as(f32, 30.0), breeze.health);
}

test "30. deflected projectile velocity reverses along incoming vector toward shooter" {
    // Arrow fired from (0, 10, -20) toward Breeze at (0, 10, 0)
    const shooter_pos = Vec3.init(0.0, 10.0, -20.0);
    const breeze_pos = Vec3.init(0.0, 10.0, 0.0);
    const incoming_vel = Vec3.init(0.0, 0.0, 20.0);

    const res = deflectTowardTarget(.arrow, incoming_vel, breeze_pos, shooter_pos, Vec3.zero());

    try std.testing.expect(res.is_deflected);
    // Direction points back along -Z toward shooter
    try std.testing.expect(res.velocity.z < -15.0);
    try std.testing.expectApproxEqAbs(res.velocity.length(), 16.0, 0.001); // 20 * 0.8
}

test "31. deflected projectile can be redirected toward nearby entity" {
    const breeze_pos = Vec3.init(0.0, 10.0, 0.0);
    const nearby_pos = Vec3.init(10.0, 10.0, 0.0); // +X entity
    const incoming_vel = Vec3.init(0.0, 0.0, 20.0);

    const res = deflectTowardTarget(.arrow, incoming_vel, breeze_pos, nearby_pos, Vec3.zero());

    try std.testing.expect(res.is_deflected);
    try std.testing.expectApproxEqAbs(res.velocity.x, 16.0, 0.001); // Directed along +X
    try std.testing.expectApproxEqAbs(res.velocity.z, 0.0, 0.001);
}

test "32. non-physical projectile is not deflected and deals damage to Breeze" {
    var breeze = BreezeEntity.init(Vec3.zero());
    var other_proj = Projectile.init(.other, Vec3.zero(), Vec3.init(0.0, 0.0, 10.0), 5);
    other_proj.damage = 5.0;

    const res = breeze.handleProjectileCollision(&other_proj, Vec3.zero());

    try std.testing.expect(!res.is_deflected);
    try std.testing.expectEqual(@as(f32, 5.0), res.damage_applied_to_breeze);
    try std.testing.expectApproxEqAbs(breeze.health, 25.0, 0.001);
}

test "33. right-clicking wind charge consumes 1 item from player inventory" {
    var player = Player.init(Vec3.zero());
    player.inventory.slots[0] = .{ .item = .wind_charge, .count = 1 };

    const proj = player.rightClickWindCharge(Vec3.init(0.0, -1.0, 0.0));

    try std.testing.expect(proj != null);
    try std.testing.expectEqual(@as(u32, 0), player.inventory.countItem(.wind_charge));
    try std.testing.expect(player.inventory.slots[0].isEmpty());
}

test "34. right-clicking wind charge from stack of 64 leaves 63 items" {
    var player = Player.init(Vec3.zero());
    player.inventory.slots[0] = .{ .item = .wind_charge, .count = 64 };

    const proj = player.rightClickWindCharge(Vec3.init(0.0, -1.0, 0.0));

    try std.testing.expect(proj != null);
    try std.testing.expectEqual(@as(u32, 63), player.inventory.countItem(.wind_charge));
    try std.testing.expectEqual(@as(u8, 63), player.inventory.slots[0].count);
}

test "35. right-clicking wind charge with empty inventory fails and launches nothing" {
    var player = Player.init(Vec3.zero());
    player.inventory.slots[0] = .{ .item = .arrow, .count = 10 }; // no wind charge

    const proj = player.rightClickWindCharge(Vec3.init(0.0, -1.0, 0.0));

    try std.testing.expect(proj == null);
}

test "36. right-clicking wind charge spawns projectile at eye position with 28.0 m/s speed" {
    var player = Player.init(Vec3.init(10.0, 64.0, 20.0));
    player.inventory.slots[0] = .{ .item = .wind_charge, .count = 5 };

    const proj = player.rightClickWindCharge(Vec3.init(0.0, -1.0, 0.0)).?;

    try std.testing.expectApproxEqAbs(proj.position.x, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(proj.position.y, 64.0 + PLAYER_EYE_HEIGHT, 0.001);
    try std.testing.expectApproxEqAbs(proj.position.z, 20.0, 0.001);
    try std.testing.expectApproxEqAbs(proj.velocity.y, -28.0, 0.001);
}

test "37. full rocket jump cycle: launch wind charge, ground impact near player, 9.5 m/s boost and 0 fall distance" {
    var player = Player.init(Vec3.init(0.0, 64.0, 0.0));
    player.fall_distance = 15.0; // Falling
    player.inventory.slots[0] = .{ .item = .wind_charge, .count = 1 };

    // 1. Right click launches projectile forward and immediately resets fall distance
    var wind_charge = player.rightClickWindCharge(Vec3.init(0.0, -1.0, 0.0)).?;
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
    try std.testing.expectEqual(@as(u32, 0), player.inventory.countItem(.wind_charge));

    // 2. Projectile travels down and strikes ground at y = 64.0
    wind_charge.advance(0.1); // travels downward (vy = -28.0 m/s * 0.1s = -2.8m, reaching 65.62 - 2.8 = 62.82 <= 64.0)
    const impact = wind_charge.checkGroundImpact(64.0).?;
    try std.testing.expect(!wind_charge.active);

    // 3. Ground impact detonates at player feet (d <= 1.5m), applying +9.5 m/s self-boost
    const triggered = player.onGroundImpact(impact, Vec3.init(0.0, -1.0, 0.0), false);
    try std.testing.expect(triggered);
    try std.testing.expectApproxEqAbs(player.velocity.y, 9.5, 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), player.fall_distance);
    try std.testing.expect(!player.is_grounded);
}
