//! Respawn Anchor Charge & Nether Spawning Mechanics (Milestone 436)
//!
//! Covers:
//! 1. Respawn Anchor Charge State:
//!    - Charges 0..4: right-clicking with Glowstone block increments charge up to maximum 4.
//!    - Light level emitted: 0 charges = 0, 1 charge = 3, 2 charges = 7, 3 charges = 11, 4 charges = 15.
//!    - Comparator signal: outputs signal strength directly proportional to charges (0, 3, 7, 11, 15 or 0..4).
//! 2. Nether Respawn Binding:
//!    - Right-clicking charged anchor in Nether binds player spawn point.
//!    - On death in Nether, player respawns on safe neighboring block and anchor charge decrements by 1.
//!    - When charge hits 0, anchor is depleted and uncharged.
//! 3. Overworld & The End Explosive Failure:
//!    - Attempting to set spawn / use a charged anchor in Overworld or The End triggers catastrophic explosion.
//!    - Explosion power is 9.0 (exceeds TNT 4.0 and Creeper 3.0), breaking surrounding blocks,
//!      setting fires, and dealing lethal radial blast damage.

const std = @import("std");

// ============================================================================
// 1. Constants & Core Types
// ============================================================================

pub const MAX_CHARGES: u8 = 4;
pub const MIN_CHARGES: u8 = 0;

pub const RESPAWN_ANCHOR_EXPLOSION_POWER: f32 = 9.0;
pub const TNT_EXPLOSION_POWER: f32 = 4.0;
pub const CREEPER_EXPLOSION_POWER: f32 = 3.0;
pub const BED_EXPLOSION_POWER: f32 = 5.0;
pub const CHARGED_CREEPER_EXPLOSION_POWER: f32 = 6.0;
pub const END_CRYSTAL_EXPLOSION_POWER: f32 = 6.0;

pub const MAX_PLAYER_HEALTH: f32 = 20.0;

/// Emitted light levels indexed by charge count 0..4.
pub const CHARGE_LIGHT_LEVELS = [5]u8{ 0, 3, 7, 11, 15 };

/// Redstone comparator signal levels indexed by charge count 0..4 (vanilla Java Edition).
pub const CHARGE_COMPARATOR_SIGNALS = [5]u8{ 0, 3, 7, 11, 15 };

/// Dimension enum for dimension-specific mechanics.
pub const Dimension = enum {
    overworld,
    nether,
    the_end,

    pub fn isNether(self: Dimension) bool {
        return self == .nether;
    }

    pub fn allowsAnchorSpawn(self: Dimension) bool {
        return self == .nether;
    }

    pub fn shouldExplodeOnUse(self: Dimension) bool {
        return self != .nether;
    }
};

/// 3D integer coordinate representing a block in the world.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) BlockPos {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: BlockPos, dx: i32, dy: i32, dz: i32) BlockPos {
        return .{ .x = self.x + dx, .y = self.y + dy, .z = self.z + dz };
    }

    pub fn equals(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub fn distanceSq(self: BlockPos, other: BlockPos) i64 {
        const dx: i64 = @as(i64, self.x) - @as(i64, other.x);
        const dy: i64 = @as(i64, self.y) - @as(i64, other.y);
        const dz: i64 = @as(i64, self.z) - @as(i64, other.z);
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn distanceTo(self: BlockPos, other: BlockPos) f32 {
        const dx: f32 = @floatFromInt(self.x - other.x);
        const dy: f32 = @floatFromInt(self.y - other.y);
        const dz: f32 = @floatFromInt(self.z - other.z);
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

/// 3D floating-point vector for positions, velocities, and impulses.
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn distance(a: Vec3, b: Vec3) f32 {
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const dz = a.z - b.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

/// Standard Minecraft block blast resistances.
pub const StandardResistances = struct {
    pub const air: f32 = 0.0;
    pub const netherrack: f32 = 0.4;
    pub const dirt: f32 = 0.5;
    pub const sand: f32 = 0.5;
    pub const gravel: f32 = 0.6;
    pub const wood_planks: f32 = 2.0;
    pub const cobblestone: f32 = 6.0;
    pub const stone: f32 = 6.0;
    pub const blackstone: f32 = 6.0;
    pub const iron_block: f32 = 6.0;
    pub const obsidian: f32 = 1200.0;
    pub const crying_obsidian: f32 = 1200.0;
    pub const respawn_anchor: f32 = 1200.0;
    pub const bedrock: f32 = 3600000.0;
};

// ============================================================================
// 2. Respawn Anchor State & Charging
// ============================================================================

pub const ChargeResult = enum {
    success,
    already_full,
    invalid_item,
};

pub const RespawnAnchor = struct {
    pos: BlockPos,
    charges: u8 = 0,
    is_spawn_bound: bool = false,
    bound_player_id: ?u32 = null,

    pub fn init(pos: BlockPos) RespawnAnchor {
        return .{
            .pos = pos,
            .charges = 0,
            .is_spawn_bound = false,
            .bound_player_id = null,
        };
    }

    pub fn initWithCharges(pos: BlockPos, initial_charges: u8) RespawnAnchor {
        return .{
            .pos = pos,
            .charges = @min(initial_charges, MAX_CHARGES),
            .is_spawn_bound = false,
            .bound_player_id = null,
        };
    }

    /// Increments charge by 1 if below maximum 4 charges.
    pub fn addGlowstone(self: *RespawnAnchor) ChargeResult {
        if (self.charges >= MAX_CHARGES) {
            return .already_full;
        }
        self.charges += 1;
        return .success;
    }

    /// Charges anchor if player is holding glowstone.
    pub fn chargeWith(self: *RespawnAnchor, is_glowstone: bool) ChargeResult {
        if (!is_glowstone) return .invalid_item;
        return self.addGlowstone();
    }

    pub fn isFullyCharged(self: RespawnAnchor) bool {
        return self.charges >= MAX_CHARGES;
    }

    pub fn isUncharged(self: RespawnAnchor) bool {
        return self.charges == 0;
    }

    pub fn hasCharges(self: RespawnAnchor) bool {
        return self.charges > 0;
    }

    /// Emitted light level: 0 -> 0, 1 -> 3, 2 -> 7, 3 -> 11, 4 -> 15.
    pub fn lightLevel(self: RespawnAnchor) u8 {
        return getLightLevelForCharge(self.charges);
    }

    /// Vanilla Java Edition comparator signal: 0 -> 0, 1 -> 3, 2 -> 7, 3 -> 11, 4 -> 15.
    pub fn comparatorSignal(self: RespawnAnchor) u8 {
        return getComparatorSignalForCharge(self.charges);
    }

    /// Directly proportional signal: 0..4.
    pub fn proportionalComparatorSignal(self: RespawnAnchor) u8 {
        return getProportionalSignalForCharge(self.charges);
    }

    /// Decrements charge by 1 upon player respawn. Returns true if decremented, false if depleted.
    pub fn decrementCharge(self: *RespawnAnchor) bool {
        if (self.charges == 0) return false;
        self.charges -= 1;
        return true;
    }
};

/// Backward-compatible alias for existing anchor state references.
pub const RespawnAnchorState = RespawnAnchor;

pub fn getLightLevelForCharge(charges: u8) u8 {
    if (charges >= MAX_CHARGES) return CHARGE_LIGHT_LEVELS[4];
    return CHARGE_LIGHT_LEVELS[charges];
}

pub fn getComparatorSignalForCharge(charges: u8) u8 {
    if (charges >= MAX_CHARGES) return CHARGE_COMPARATOR_SIGNALS[4];
    return CHARGE_COMPARATOR_SIGNALS[charges];
}

pub fn getProportionalSignalForCharge(charges: u8) u8 {
    return @min(charges, MAX_CHARGES);
}

pub const chargeLevel = getLightLevelForCharge;

// ============================================================================
// 3. Candidate Neighbor Coordinates & Safe Spawn Selection
// ============================================================================

const Offset = struct { x: i32, y: i32, z: i32 };

/// Ordered search offsets around a respawn anchor.
/// Evaluates nearest horizontal cardinal neighbors first, then diagonals,
/// followed by elevation shifts (+1, -1) and extended radius.
pub const CANDIDATE_OFFSETS = [_]Offset{
    // 1. Same level cardinal neighbors (distance = 1)
    .{ .x = 1, .y = 0, .z = 0 },
    .{ .x = -1, .y = 0, .z = 0 },
    .{ .x = 0, .y = 0, .z = 1 },
    .{ .x = 0, .y = 0, .z = -1 },

    // 2. Same level diagonal neighbors (distance = sqrt(2))
    .{ .x = 1, .y = 0, .z = 1 },
    .{ .x = 1, .y = 0, .z = -1 },
    .{ .x = -1, .y = 0, .z = 1 },
    .{ .x = -1, .y = 0, .z = -1 },

    // 3. Step up (+1) cardinal neighbors
    .{ .x = 1, .y = 1, .z = 0 },
    .{ .x = -1, .y = 1, .z = 0 },
    .{ .x = 0, .y = 1, .z = 1 },
    .{ .x = 0, .y = 1, .z = -1 },

    // 4. Step up (+1) diagonal neighbors
    .{ .x = 1, .y = 1, .z = 1 },
    .{ .x = 1, .y = 1, .z = -1 },
    .{ .x = -1, .y = 1, .z = 1 },
    .{ .x = -1, .y = 1, .z = -1 },

    // 5. Step down (-1) cardinal neighbors
    .{ .x = 1, .y = -1, .z = 0 },
    .{ .x = -1, .y = -1, .z = 0 },
    .{ .x = 0, .y = -1, .z = 1 },
    .{ .x = 0, .y = -1, .z = -1 },

    // 6. Step down (-1) diagonal neighbors
    .{ .x = 1, .y = -1, .z = 1 },
    .{ .x = 1, .y = -1, .z = -1 },
    .{ .x = -1, .y = -1, .z = 1 },
    .{ .x = -1, .y = -1, .z = -1 },

    // 7. On top of anchor itself if all adjacent ground is unavailable
    .{ .x = 0, .y = 1, .z = 0 },

    // 8. Extended radius (2 blocks away)
    .{ .x = 2, .y = 0, .z = 0 },
    .{ .x = -2, .y = 0, .z = 0 },
    .{ .x = 0, .y = 0, .z = 2 },
    .{ .x = 0, .y = 0, .z = -2 },
};

fn checkIsSolid(world: anytype, x: i32, y: i32, z: i32) bool {
    const W = @TypeOf(world);
    if (@hasDecl(W, "isSolid")) {
        return world.isSolid(x, y, z);
    } else if (@hasDecl(W, "getBlock")) {
        const b = world.getBlock(x, y, z);
        const B = @TypeOf(b);
        if (@hasDecl(B, "is_solid")) {
            return b.is_solid();
        } else if (@hasDecl(B, "isSolid")) {
            return b.isSolid();
        } else {
            return b != .air and b != .water and b != .lava and b != .fire;
        }
    } else {
        return false;
    }
}

fn checkIsHazard(world: anytype, x: i32, y: i32, z: i32) bool {
    const W = @TypeOf(world);
    if (@hasDecl(W, "isHazard")) {
        return world.isHazard(x, y, z);
    } else if (@hasDecl(W, "getBlock")) {
        const b = world.getBlock(x, y, z);
        const B = @TypeOf(b);
        if (@hasDecl(B, "isHazard")) {
            return b.isHazard();
        } else {
            return b == .lava or b == .fire;
        }
    } else {
        return false;
    }
}

/// Validates whether `pos` offers a safe 2-block headroom standable space.
/// - Floor beneath feet (y - 1) must be solid and non-hazardous.
/// - Feet (y) and head (y + 1) must be passable (non-solid) and non-hazardous.
/// - Cannot spawn inside the respawn anchor itself.
pub fn isSafeSpawnLocation(world: anytype, pos: BlockPos, anchor_pos: BlockPos) bool {
    if (pos.equals(anchor_pos)) return false;

    // Floor below feet must be solid and safe
    const floor = pos.add(0, -1, 0);
    if (!checkIsSolid(world, floor.x, floor.y, floor.z)) return false;
    if (checkIsHazard(world, floor.x, floor.y, floor.z)) return false;

    // Feet space must be clear and safe
    if (checkIsSolid(world, pos.x, pos.y, pos.z)) return false;
    if (checkIsHazard(world, pos.x, pos.y, pos.z)) return false;

    // Head space must be clear and safe
    const head = pos.add(0, 1, 0);
    if (checkIsSolid(world, head.x, head.y, head.z)) return false;
    if (checkIsHazard(world, head.x, head.y, head.z)) return false;

    return true;
}

/// Finds the best safe adjacent block coordinate surrounding the anchor.
pub fn findSafeAdjacentRespawnPos(world: anytype, anchor_pos: BlockPos) ?BlockPos {
    for (CANDIDATE_OFFSETS) |offset| {
        const candidate = anchor_pos.add(offset.x, offset.y, offset.z);
        if (isSafeSpawnLocation(world, candidate, anchor_pos)) {
            return candidate;
        }
    }
    return null;
}

/// Finds safe spawn coordinates centered in world coordinates (x + 0.5, y, z + 0.5).
pub fn findSafeRespawnCoords(world: anytype, anchor_pos: BlockPos) ?Vec3 {
    const pos = findSafeAdjacentRespawnPos(world, anchor_pos) orelse return null;
    return Vec3{
        .x = @as(f32, @floatFromInt(pos.x)) + 0.5,
        .y = @as(f32, @floatFromInt(pos.y)),
        .z = @as(f32, @floatFromInt(pos.z)) + 0.5,
    };
}

// ============================================================================
// 4. Nether Respawn Execution
// ============================================================================

pub const RespawnFailureReason = enum {
    no_charges,
    wrong_dimension,
    no_safe_position,
};

pub const RespawnResult = struct {
    success: bool,
    spawn_pos: ?BlockPos = null,
    spawn_coords: ?Vec3 = null,
    charge_remaining: u8,
    depleted: bool,
    failure_reason: ?RespawnFailureReason = null,
};

/// Executes player respawn in the Nether:
/// - Verifies anchor has charges and is in Nether dimension.
/// - Finds safe neighboring block.
/// - Decrements anchor charge by 1 (depletes at 0).
/// - Returns safe spawn coordinates.
pub fn respawnPlayer(
    anchor: *RespawnAnchor,
    dimension: Dimension,
    world: anytype,
) RespawnResult {
    if (dimension != .nether) {
        return .{
            .success = false,
            .charge_remaining = anchor.charges,
            .depleted = (anchor.charges == 0),
            .failure_reason = .wrong_dimension,
        };
    }

    if (anchor.charges == 0) {
        return .{
            .success = false,
            .charge_remaining = 0,
            .depleted = true,
            .failure_reason = .no_charges,
        };
    }

    const safe_pos = findSafeAdjacentRespawnPos(world, anchor.pos);
    if (safe_pos) |pos| {
        anchor.charges -= 1;
        const depleted = (anchor.charges == 0);
        return .{
            .success = true,
            .spawn_pos = pos,
            .spawn_coords = Vec3{
                .x = @as(f32, @floatFromInt(pos.x)) + 0.5,
                .y = @as(f32, @floatFromInt(pos.y)),
                .z = @as(f32, @floatFromInt(pos.z)) + 0.5,
            },
            .charge_remaining = anchor.charges,
            .depleted = depleted,
            .failure_reason = null,
        };
    } else {
        // If obstructed, vanilla Minecraft does not consume charge
        return .{
            .success = false,
            .charge_remaining = anchor.charges,
            .depleted = false,
            .failure_reason = .no_safe_position,
        };
    }
}

// ============================================================================
// 5. Catastrophic Explosion Dynamics (Power 9.0)
// ============================================================================

pub const BlastImpulse = struct {
    vel_x: f32,
    vel_y: f32,
    vel_z: f32,
    magnitude: f32,
};

/// Calculates radial blast damage based on Minecraft explosion formula:
/// `damage = ((impact^2 + impact) / 2) * 8 * power + 1`
pub fn calculateRadialBlastDamage(distance: f32, power: f32) f32 {
    const max_radius = power * 2.0;
    if (distance >= max_radius or distance < 0.0) return 0.0;
    const impact = (max_radius - distance) / max_radius;
    const damage = ((impact * impact + impact) / 2.0) * 8.0 * power + 1.0;
    return damage;
}

/// Checks if blast damage exceeds standard player maximum health (20 HP).
pub fn isLethalDamage(damage: f32) bool {
    return damage >= MAX_PLAYER_HEALTH;
}

/// Checks whether damage at distance is lethal.
pub fn isDamageLethalAtDistance(distance: f32, power: f32) bool {
    return isLethalDamage(calculateRadialBlastDamage(distance, power));
}

/// Calculates radial blast impulse and knockback vector away from epicenter.
pub fn calculateBlastImpulse(target: Vec3, explosion_center: Vec3, power: f32) ?BlastImpulse {
    const max_radius = power * 2.0;
    const dx = target.x - explosion_center.x;
    const dy = target.y - explosion_center.y;
    const dz = target.z - explosion_center.z;
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);
    if (dist >= max_radius or dist <= 0.001) return null;

    const impact = (max_radius - dist) / max_radius;
    const factor = impact * power * 1.5;
    const dir_x = dx / dist;
    const dir_z = dz / dist;

    const vel_x = dir_x * factor;
    const vel_y = impact * power * 1.2 + 2.0;
    const vel_z = dir_z * factor;
    const mag = @sqrt(vel_x * vel_x + vel_y * vel_y + vel_z * vel_z);

    return .{
        .vel_x = vel_x,
        .vel_y = vel_y,
        .vel_z = vel_z,
        .magnitude = mag,
    };
}

/// Blast ray attenuation calculations matching modern Minecraft demolition physics:
/// ray step = 0.3m, air decay = 0.225, attenuation = (blast_res + 0.3) * 0.3.
pub const BlastRayAttenuation = struct {
    pub const ray_step_size: f32 = 0.3;
    pub const air_decay_per_step: f32 = 0.225;

    pub fn computeStepAttenuation(blast_resistance: f32) f32 {
        return (blast_resistance + 0.3) * 0.3;
    }

    pub fn stepRayPower(current_power: f32, blast_resistance: f32) f32 {
        const att = computeStepAttenuation(blast_resistance);
        const rem = current_power - att - air_decay_per_step;
        if (rem <= 0.0) return 0.0;
        return rem;
    }

    /// Counts how many blocks of given resistances the ray enters before exhaustion.
    pub fn countBreachedBlocks(initial_power: f32, resistances: []const f32) usize {
        var power = initial_power;
        var breached: usize = 0;
        for (resistances) |res| {
            if (power <= 0.0) break;
            breached += 1;
            power = stepRayPower(power, res);
        }
        return breached;
    }

    /// Counts how many blocks of given resistances are completely penetrated (power > 0 after passing through).
    pub fn countPenetratedBlocks(initial_power: f32, resistances: []const f32) usize {
        var power = initial_power;
        var penetrated: usize = 0;
        for (resistances) |res| {
            if (power <= 0.0) break;
            const next = stepRayPower(power, res);
            if (next > 0.0) {
                penetrated += 1;
                power = next;
            } else {
                break;
            }
        }
        return penetrated;
    }

    /// Evaluates if a block of given resistance at distance can be shattered.
    pub fn canShatterBlock(power: f32, blast_resistance: f32, distance: f32) bool {
        const max_radius = power * 2.0;
        if (distance >= max_radius) return false;
        // Obsidian and crying obsidian withstand blast
        if (blast_resistance >= 1000.0) return false;
        const remaining_power = power * (1.0 - distance / max_radius);
        const required_attenuation = computeStepAttenuation(blast_resistance);
        return remaining_power > required_attenuation;
    }

    /// Computes crater radius in meters for homogeneous block medium.
    pub fn computeCraterRadius(power: f32, blast_resistance: f32) f32 {
        if (blast_resistance >= 1000.0) return 0.0;
        const att = computeStepAttenuation(blast_resistance) + air_decay_per_step;
        if (att <= 0.0) return power * 2.0;
        const max_steps = power / att;
        return max_steps * ray_step_size;
    }
};

/// Fire ignition rules for catastrophic explosions.
pub const FirePlacement = struct {
    pub const ignition_chance: f32 = 0.333;

    pub fn shouldIgniteFire(roll: f32) bool {
        return roll < ignition_chance;
    }

    pub fn canSupportFire(floor_is_solid: bool, space_is_air: bool) bool {
        return floor_is_solid and space_is_air;
    }
};

/// Outcome data for catastrophic wrong-dimension anchor explosion.
pub const ExplosionOutcome = struct {
    epicenter: BlockPos,
    power: f32 = RESPAWN_ANCHOR_EXPLOSION_POWER,
    blast_radius: f32 = RESPAWN_ANCHOR_EXPLOSION_POWER * 2.0,
    destroys_anchor: bool = true,
    sets_fire: bool = true,
    damage_at_epicenter: f32,

    pub fn init(epicenter: BlockPos) ExplosionOutcome {
        return .{
            .epicenter = epicenter,
            .power = RESPAWN_ANCHOR_EXPLOSION_POWER,
            .blast_radius = RESPAWN_ANCHOR_EXPLOSION_POWER * 2.0,
            .destroys_anchor = true,
            .sets_fire = true,
            .damage_at_epicenter = calculateRadialBlastDamage(0.0, RESPAWN_ANCHOR_EXPLOSION_POWER),
        };
    }
};

pub const CatastrophicExplosion = struct {
    pub const power: f32 = RESPAWN_ANCHOR_EXPLOSION_POWER;
    pub const blast_radius: f32 = RESPAWN_ANCHOR_EXPLOSION_POWER * 2.0;
    pub const sets_fire: bool = true;
    pub const destroys_epicenter: bool = true;

    pub fn calculateDamage(distance: f32) f32 {
        return calculateRadialBlastDamage(distance, power);
    }

    pub fn isLethal(distance: f32) bool {
        return isDamageLethalAtDistance(distance, power);
    }

    pub fn calculateImpulse(target: Vec3, explosion_pos: Vec3) ?BlastImpulse {
        return calculateBlastImpulse(target, explosion_pos, power);
    }

    pub fn stepRay(current_power: f32, blast_resistance: f32) f32 {
        return BlastRayAttenuation.stepRayPower(current_power, blast_resistance);
    }

    pub fn countBreachedBlocks(resistances: []const f32) usize {
        return BlastRayAttenuation.countBreachedBlocks(power, resistances);
    }

    pub fn canShatter(blast_resistance: f32, distance: f32) bool {
        return BlastRayAttenuation.canShatterBlock(power, blast_resistance, distance);
    }

    pub fn craterRadius(blast_resistance: f32) f32 {
        return BlastRayAttenuation.computeCraterRadius(power, blast_resistance);
    }
};

// ============================================================================
// 6. Right-Click Interaction State Machine
// ============================================================================

pub const InteractionAction = enum {
    charge_success,
    charge_rejected_full,
    bind_spawn_success,
    bind_spawn_rejected_uncharged,
    catastrophic_explosion,
    fail_uncharged_in_wrong_dimension,
};

pub const InteractionResult = struct {
    action: InteractionAction,
    new_charges: u8,
    bound_spawn: bool = false,
    explosion: ?ExplosionOutcome = null,
};

/// Evaluates player right-click interaction with Respawn Anchor:
/// 1. If holding Glowstone:
///    - charges < 4: increments charge by 1.
///    - charges == 4: rejects overflow.
/// 2. If NOT holding Glowstone (attempting to set spawn / use anchor):
///    - In Nether:
///      - charges > 0: binds spawn point.
///      - charges == 0: rejects (uncharged).
///    - In Overworld or The End:
///      - charges > 0: CATASTROPHIC EXPLOSION (power 9.0)!
///      - charges == 0: fails safely (no explosion).
pub fn interact(
    anchor: *RespawnAnchor,
    dimension: Dimension,
    is_holding_glowstone: bool,
    player_id: ?u32,
) InteractionResult {
    if (is_holding_glowstone) {
        if (anchor.charges < MAX_CHARGES) {
            anchor.charges += 1;
            return .{
                .action = .charge_success,
                .new_charges = anchor.charges,
                .bound_spawn = anchor.is_spawn_bound,
                .explosion = null,
            };
        } else {
            return .{
                .action = .charge_rejected_full,
                .new_charges = anchor.charges,
                .bound_spawn = anchor.is_spawn_bound,
                .explosion = null,
            };
        }
    }

    if (dimension == .nether) {
        if (anchor.charges > 0) {
            anchor.is_spawn_bound = true;
            anchor.bound_player_id = player_id;
            return .{
                .action = .bind_spawn_success,
                .new_charges = anchor.charges,
                .bound_spawn = true,
                .explosion = null,
            };
        } else {
            return .{
                .action = .bind_spawn_rejected_uncharged,
                .new_charges = 0,
                .bound_spawn = false,
                .explosion = null,
            };
        }
    } else {
        // Overworld or The End
        if (anchor.charges > 0) {
            const explosion = ExplosionOutcome.init(anchor.pos);
            anchor.charges = 0;
            anchor.is_spawn_bound = false;
            anchor.bound_player_id = null;
            return .{
                .action = .catastrophic_explosion,
                .new_charges = 0,
                .bound_spawn = false,
                .explosion = explosion,
            };
        } else {
            return .{
                .action = .fail_uncharged_in_wrong_dimension,
                .new_charges = 0,
                .bound_spawn = false,
                .explosion = null,
            };
        }
    }
}

/// Standalone interaction evaluator without mutating state.
pub fn evaluateInteraction(
    charges: u8,
    dimension: Dimension,
    is_holding_glowstone: bool,
) InteractionAction {
    if (is_holding_glowstone) {
        return if (charges < MAX_CHARGES) .charge_success else .charge_rejected_full;
    }
    if (dimension == .nether) {
        return if (charges > 0) .bind_spawn_success else .bind_spawn_rejected_uncharged;
    }
    return if (charges > 0) .catastrophic_explosion else .fail_uncharged_in_wrong_dimension;
}

// ============================================================================
// 7. Test Helpers
// ============================================================================

pub const FlatNetherWorld = struct {
    floor_y: i32 = 63,

    pub fn isSolid(self: @This(), x: i32, y: i32, z: i32) bool {
        _ = x;
        _ = z;
        return y <= self.floor_y;
    }

    pub fn isHazard(self: @This(), x: i32, y: i32, z: i32) bool {
        _ = self;
        _ = x;
        _ = y;
        _ = z;
        return false;
    }
};

pub const MockWorld = struct {
    const Self = @This();

    pub const BlockKind = enum {
        air,
        netherrack,
        stone,
        cobblestone,
        dirt,
        lava,
        fire,
        respawn_anchor,
        obsidian,
    };

    blocks: std.AutoHashMap(BlockPos, BlockKind),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .blocks = std.AutoHashMap(BlockPos, BlockKind).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.blocks.deinit();
    }

    pub fn setBlock(self: *Self, x: i32, y: i32, z: i32, kind: BlockKind) !void {
        try self.blocks.put(BlockPos.init(x, y, z), kind);
    }

    pub fn getBlock(self: Self, x: i32, y: i32, z: i32) BlockKind {
        return self.blocks.get(BlockPos.init(x, y, z)) orelse .air;
    }

    pub fn isSolid(self: Self, x: i32, y: i32, z: i32) bool {
        const b = self.getBlock(x, y, z);
        return switch (b) {
            .netherrack, .stone, .cobblestone, .dirt, .respawn_anchor, .obsidian => true,
            .air, .lava, .fire => false,
        };
    }

    pub fn isHazard(self: Self, x: i32, y: i32, z: i32) bool {
        const b = self.getBlock(x, y, z);
        return b == .lava or b == .fire;
    }
};

// ============================================================================
// 8. Unit Test Suite (27 Comprehensive Tests)
// ============================================================================

test "1. RespawnAnchor: initial state is 0 charges, uncharged, and unlit" {
    const anchor = RespawnAnchor.init(BlockPos.init(0, 64, 0));
    try std.testing.expectEqual(@as(u8, 0), anchor.charges);
    try std.testing.expect(anchor.isUncharged());
    try std.testing.expect(!anchor.hasCharges());
    try std.testing.expect(!anchor.isFullyCharged());
    try std.testing.expectEqual(@as(u8, 0), anchor.lightLevel());
    try std.testing.expectEqual(@as(u8, 0), anchor.comparatorSignal());
    try std.testing.expectEqual(@as(u8, 0), anchor.proportionalComparatorSignal());
}

test "2. RespawnAnchor: glowstone charging increments 0 to 4 charges" {
    var anchor = RespawnAnchor.init(BlockPos.init(10, 64, 10));

    // Charge 1
    try std.testing.expectEqual(ChargeResult.success, anchor.addGlowstone());
    try std.testing.expectEqual(@as(u8, 1), anchor.charges);
    try std.testing.expect(anchor.hasCharges());
    try std.testing.expect(!anchor.isUncharged());

    // Charge 2
    try std.testing.expectEqual(ChargeResult.success, anchor.addGlowstone());
    try std.testing.expectEqual(@as(u8, 2), anchor.charges);

    // Charge 3
    try std.testing.expectEqual(ChargeResult.success, anchor.addGlowstone());
    try std.testing.expectEqual(@as(u8, 3), anchor.charges);

    // Charge 4 (maximum)
    try std.testing.expectEqual(ChargeResult.success, anchor.addGlowstone());
    try std.testing.expectEqual(@as(u8, 4), anchor.charges);
    try std.testing.expect(anchor.isFullyCharged());
}

test "3. RespawnAnchor: charge overflow rejection when already full at 4 charges" {
    var anchor = RespawnAnchor.initWithCharges(BlockPos.init(0, 64, 0), 4);
    try std.testing.expect(anchor.isFullyCharged());

    // 5th glowstone attempt is rejected
    try std.testing.expectEqual(ChargeResult.already_full, anchor.addGlowstone());
    try std.testing.expectEqual(@as(u8, 4), anchor.charges);

    // 6th attempt is also rejected
    try std.testing.expectEqual(ChargeResult.already_full, anchor.chargeWith(true));
    try std.testing.expectEqual(@as(u8, 4), anchor.charges);
}

test "4. RespawnAnchor: non-glowstone items cannot charge anchor" {
    var anchor = RespawnAnchor.init(BlockPos.init(0, 64, 0));
    try std.testing.expectEqual(ChargeResult.invalid_item, anchor.chargeWith(false));
    try std.testing.expectEqual(@as(u8, 0), anchor.charges);
}

test "5. RespawnAnchor: light levels emit 0, 3, 7, 11, 15 for charges 0..4" {
    const expected_levels = [_]u8{ 0, 3, 7, 11, 15 };
    for (expected_levels, 0..) |expected, charge| {
        const c: u8 = @intCast(charge);
        try std.testing.expectEqual(expected, getLightLevelForCharge(c));

        const anchor = RespawnAnchor.initWithCharges(BlockPos.init(0, 64, 0), c);
        try std.testing.expectEqual(expected, anchor.lightLevel());
    }

    // Beyond max charge clamps to 15
    try std.testing.expectEqual(@as(u8, 15), getLightLevelForCharge(5));
    try std.testing.expectEqual(@as(u8, 15), getLightLevelForCharge(10));
}

test "6. RespawnAnchor: comparator signal outputs 0, 3, 7, 11, 15 for charges 0..4" {
    const expected_signals = [_]u8{ 0, 3, 7, 11, 15 };
    for (expected_signals, 0..) |expected, charge| {
        const c: u8 = @intCast(charge);
        try std.testing.expectEqual(expected, getComparatorSignalForCharge(c));

        const anchor = RespawnAnchor.initWithCharges(BlockPos.init(0, 64, 0), c);
        try std.testing.expectEqual(expected, anchor.comparatorSignal());
    }

    // Clamps to 15
    try std.testing.expectEqual(@as(u8, 15), getComparatorSignalForCharge(99));
}

test "7. RespawnAnchor: proportional comparator signal outputs 0..4" {
    var c: u8 = 0;
    while (c <= 4) : (c += 1) {
        try std.testing.expectEqual(c, getProportionalSignalForCharge(c));
        const anchor = RespawnAnchor.initWithCharges(BlockPos.init(0, 64, 0), c);
        try std.testing.expectEqual(c, anchor.proportionalComparatorSignal());
    }
}

test "8. NetherSpawning: right-clicking charged anchor in Nether binds player spawn" {
    var anchor = RespawnAnchor.initWithCharges(BlockPos.init(100, 64, -50), 2);
    const result = interact(&anchor, .nether, false, 42);

    try std.testing.expectEqual(InteractionAction.bind_spawn_success, result.action);
    try std.testing.expect(result.bound_spawn);
    try std.testing.expect(anchor.is_spawn_bound);
    try std.testing.expectEqual(@as(?u32, 42), anchor.bound_player_id);
    try std.testing.expectEqual(@as(u8, 2), result.new_charges);
    try std.testing.expect(result.explosion == null);
}

test "9. NetherSpawning: right-clicking uncharged anchor in Nether rejects spawn binding" {
    var anchor = RespawnAnchor.init(BlockPos.init(100, 64, -50));
    const result = interact(&anchor, .nether, false, 42);

    try std.testing.expectEqual(InteractionAction.bind_spawn_rejected_uncharged, result.action);
    try std.testing.expect(!result.bound_spawn);
    try std.testing.expect(!anchor.is_spawn_bound);
    try std.testing.expectEqual(@as(?u32, null), anchor.bound_player_id);
    try std.testing.expect(result.explosion == null);
}

test "10. NetherSpawning: finds closest safe cardinal neighbor on flat terrain" {
    const world = FlatNetherWorld{ .floor_y = 63 };
    const anchor_pos = BlockPos.init(0, 64, 0);

    const safe_pos = findSafeAdjacentRespawnPos(world, anchor_pos);
    try std.testing.expect(safe_pos != null);

    const pos = safe_pos.?;
    // Should choose first cardinal neighbor (+1, 0, 0)
    try std.testing.expectEqual(BlockPos.init(1, 64, 0), pos);

    // World spawn coordinates should be centered at (+1.5, 64.0, +0.5)
    const coords = findSafeRespawnCoords(world, anchor_pos);
    try std.testing.expect(coords != null);
    try std.testing.expectEqual(@as(f32, 1.5), coords.?.x);
    try std.testing.expectEqual(@as(f32, 64.0), coords.?.y);
    try std.testing.expectEqual(@as(f32, 0.5), coords.?.z);
}

test "11. NetherSpawning: safe coordinate selection skips hazardous lava and fire blocks" {
    var mock = MockWorld.init(std.testing.allocator);
    defer mock.deinit();

    const anchor_pos = BlockPos.init(0, 64, 0);

    // Setup floor at y=63 everywhere
    var dx: i32 = -2;
    while (dx <= 2) : (dx += 1) {
        var dz: i32 = -2;
        while (dz <= 2) : (dz += 1) {
            try mock.setBlock(dx, 63, dz, .netherrack);
        }
    }
    try mock.setBlock(0, 64, 0, .respawn_anchor);

    // Place lava and fire on cardinal neighbors (+1, 0), (-1, 0), (0, +1)
    try mock.setBlock(1, 64, 0, .lava); // East has lava
    try mock.setBlock(-1, 64, 0, .fire); // West has fire
    try mock.setBlock(0, 64, 1, .lava); // South has lava

    // North (0, 64, -1) is clean air with solid floor!
    const safe_pos = findSafeAdjacentRespawnPos(mock, anchor_pos);
    try std.testing.expect(safe_pos != null);
    try std.testing.expectEqual(BlockPos.init(0, 64, -1), safe_pos.?);
}

test "12. NetherSpawning: safe coordinate selection skips suffocating obstructed blocks" {
    var mock = MockWorld.init(std.testing.allocator);
    defer mock.deinit();

    const anchor_pos = BlockPos.init(0, 64, 0);

    // Floor at y=63
    var dx: i32 = -2;
    while (dx <= 2) : (dx += 1) {
        var dz: i32 = -2;
        while (dz <= 2) : (dz += 1) {
            try mock.setBlock(dx, 63, dz, .netherrack);
        }
    }
    try mock.setBlock(0, 64, 0, .respawn_anchor);

    // Suffocate foot space at East (+1, 0, 0)
    try mock.setBlock(1, 64, 0, .netherrack);

    // Suffocate head space at West (-1, 65, 0)
    try mock.setBlock(-1, 65, 0, .netherrack);

    // Next candidate in priority is South (0, 64, 1) which is clear
    const safe_pos = findSafeAdjacentRespawnPos(mock, anchor_pos);
    try std.testing.expect(safe_pos != null);
    try std.testing.expectEqual(BlockPos.init(0, 64, 1), safe_pos.?);
}

test "13. NetherSpawning: finds safe diagonal or step-up neighbor when cardinals blocked" {
    var mock = MockWorld.init(std.testing.allocator);
    defer mock.deinit();

    const anchor_pos = BlockPos.init(0, 64, 0);

    // Floor at y=63
    var dx: i32 = -2;
    while (dx <= 2) : (dx += 1) {
        var dz: i32 = -2;
        while (dz <= 2) : (dz += 1) {
            try mock.setBlock(dx, 63, dz, .netherrack);
        }
    }
    try mock.setBlock(0, 64, 0, .respawn_anchor);

    // Block all 4 cardinals with solid stone
    try mock.setBlock(1, 64, 0, .stone);
    try mock.setBlock(-1, 64, 0, .stone);
    try mock.setBlock(0, 64, 1, .stone);
    try mock.setBlock(0, 64, -1, .stone);

    // First diagonal is (1, 64, 1)
    const safe_pos = findSafeAdjacentRespawnPos(mock, anchor_pos);
    try std.testing.expect(safe_pos != null);
    try std.testing.expectEqual(BlockPos.init(1, 64, 1), safe_pos.?);
}

test "14. NetherSpawning: reports failure when all adjacent locations are completely obstructed" {
    var mock = MockWorld.init(std.testing.allocator);
    defer mock.deinit();

    const anchor_pos = BlockPos.init(0, 64, 0);
    // Fill entire 5x5x5 volume with solid obsidian (encased in a tomb)
    var dx: i32 = -2;
    while (dx <= 2) : (dx += 1) {
        var dy: i32 = -2;
        while (dy <= 2) : (dy += 1) {
            var dz: i32 = -2;
            while (dz <= 2) : (dz += 1) {
                try mock.setBlock(dx, 64 + dy, dz, .obsidian);
            }
        }
    }

    const safe_pos = findSafeAdjacentRespawnPos(mock, anchor_pos);
    try std.testing.expect(safe_pos == null);

    var anchor = RespawnAnchor.initWithCharges(anchor_pos, 4);
    const respawn_res = respawnPlayer(&anchor, .nether, mock);
    try std.testing.expect(!respawn_res.success);
    try std.testing.expectEqual(RespawnFailureReason.no_safe_position, respawn_res.failure_reason.?);
    // Charge must NOT be consumed if obstructed
    try std.testing.expectEqual(@as(u8, 4), anchor.charges);
}

test "15. NetherSpawning: player respawn decrements anchor charge by 1" {
    const world = FlatNetherWorld{ .floor_y = 63 };
    var anchor = RespawnAnchor.initWithCharges(BlockPos.init(0, 64, 0), 4);

    // 1st death and respawn: 4 -> 3
    const res1 = respawnPlayer(&anchor, .nether, world);
    try std.testing.expect(res1.success);
    try std.testing.expectEqual(@as(u8, 3), anchor.charges);
    try std.testing.expectEqual(@as(u8, 3), res1.charge_remaining);
    try std.testing.expect(!res1.depleted);

    // 2nd respawn: 3 -> 2
    const res2 = respawnPlayer(&anchor, .nether, world);
    try std.testing.expect(res2.success);
    try std.testing.expectEqual(@as(u8, 2), anchor.charges);
    try std.testing.expectEqual(@as(u8, 2), res2.charge_remaining);
    try std.testing.expect(!res2.depleted);

    // 3rd respawn: 2 -> 1
    const res3 = respawnPlayer(&anchor, .nether, world);
    try std.testing.expect(res3.success);
    try std.testing.expectEqual(@as(u8, 1), anchor.charges);
    try std.testing.expectEqual(@as(u8, 1), res3.charge_remaining);
    try std.testing.expect(!res3.depleted);
}

test "16. NetherSpawning: anchor at charge 1 decrements to 0 and becomes depleted" {
    const world = FlatNetherWorld{ .floor_y = 63 };
    var anchor = RespawnAnchor.initWithCharges(BlockPos.init(0, 64, 0), 1);

    const res = respawnPlayer(&anchor, .nether, world);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u8, 0), anchor.charges);
    try std.testing.expectEqual(@as(u8, 0), res.charge_remaining);
    try std.testing.expect(res.depleted);
    try std.testing.expect(anchor.isUncharged());
}

test "17. NetherSpawning: depleted anchor with 0 charges cannot respawn player" {
    const world = FlatNetherWorld{ .floor_y = 63 };
    var anchor = RespawnAnchor.init(BlockPos.init(0, 64, 0));

    const res = respawnPlayer(&anchor, .nether, world);
    try std.testing.expect(!res.success);
    try std.testing.expectEqual(RespawnFailureReason.no_charges, res.failure_reason.?);
    try std.testing.expect(res.depleted);
    try std.testing.expectEqual(@as(u8, 0), anchor.charges);
}

test "18. ExplosiveFailure: right-clicking charged anchor in Overworld triggers catastrophic explosion" {
    var anchor = RespawnAnchor.initWithCharges(BlockPos.init(20, 70, -30), 3);
    const result = interact(&anchor, .overworld, false, null);

    try std.testing.expectEqual(InteractionAction.catastrophic_explosion, result.action);
    try std.testing.expectEqual(@as(u8, 0), anchor.charges);
    try std.testing.expect(!anchor.is_spawn_bound);
    try std.testing.expect(result.explosion != null);

    const boom = result.explosion.?;
    try std.testing.expectEqual(@as(f32, 9.0), boom.power);
    try std.testing.expectEqual(@as(f32, 18.0), boom.blast_radius);
    try std.testing.expect(boom.destroys_anchor);
    try std.testing.expect(boom.sets_fire);
    try std.testing.expect(boom.damage_at_epicenter > 70.0);
}

test "19. ExplosiveFailure: right-clicking charged anchor in The End triggers catastrophic explosion" {
    var anchor = RespawnAnchor.initWithCharges(BlockPos.init(0, 60, 0), 1);
    const result = interact(&anchor, .the_end, false, null);

    try std.testing.expectEqual(InteractionAction.catastrophic_explosion, result.action);
    try std.testing.expectEqual(@as(u8, 0), anchor.charges);
    try std.testing.expect(result.explosion != null);
    try std.testing.expectEqual(@as(f32, 9.0), result.explosion.?.power);
}

test "20. ExplosiveFailure: uncharged anchor in Overworld or The End does not explode" {
    var anchor = RespawnAnchor.init(BlockPos.init(0, 70, 0));

    // Overworld uncharged
    const ow_result = interact(&anchor, .overworld, false, null);
    try std.testing.expectEqual(InteractionAction.fail_uncharged_in_wrong_dimension, ow_result.action);
    try std.testing.expect(ow_result.explosion == null);

    // End uncharged
    const end_result = interact(&anchor, .the_end, false, null);
    try std.testing.expectEqual(InteractionAction.fail_uncharged_in_wrong_dimension, end_result.action);
    try std.testing.expect(end_result.explosion == null);
}

test "21. ExplosiveFailure: charging with glowstone in Overworld succeeds safely without exploding" {
    var anchor = RespawnAnchor.init(BlockPos.init(0, 70, 0));

    // Inserting glowstone in Overworld charges the anchor without detonating
    const res = interact(&anchor, .overworld, true, null);
    try std.testing.expectEqual(InteractionAction.charge_success, res.action);
    try std.testing.expectEqual(@as(u8, 1), anchor.charges);
    try std.testing.expect(res.explosion == null);

    // Interacting without glowstone now causes the detonation!
    const boom = interact(&anchor, .overworld, false, null);
    try std.testing.expectEqual(InteractionAction.catastrophic_explosion, boom.action);
}

test "22. ExplosionPhysics: anchor blast power 9.0 exceeds TNT 4.0, Creeper 3.0, and Bed 5.0" {
    try std.testing.expectEqual(@as(f32, 9.0), RESPAWN_ANCHOR_EXPLOSION_POWER);
    try std.testing.expect(RESPAWN_ANCHOR_EXPLOSION_POWER > TNT_EXPLOSION_POWER);
    try std.testing.expect(RESPAWN_ANCHOR_EXPLOSION_POWER > CREEPER_EXPLOSION_POWER);
    try std.testing.expect(RESPAWN_ANCHOR_EXPLOSION_POWER > BED_EXPLOSION_POWER);
    try std.testing.expect(RESPAWN_ANCHOR_EXPLOSION_POWER > CHARGED_CREEPER_EXPLOSION_POWER);

    // Exact ratios
    try std.testing.expectApproxEqAbs(@as(f32, 2.25), RESPAWN_ANCHOR_EXPLOSION_POWER / TNT_EXPLOSION_POWER, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), RESPAWN_ANCHOR_EXPLOSION_POWER / CREEPER_EXPLOSION_POWER, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.8), RESPAWN_ANCHOR_EXPLOSION_POWER / BED_EXPLOSION_POWER, 0.001);
}

test "23. ExplosionPhysics: deals lethal radial blast damage exceeding 20 HP" {
    const power = RESPAWN_ANCHOR_EXPLOSION_POWER;

    // Epicenter (0m): ~73 HP damage (>3.6x lethal)
    const dmg_0m = calculateRadialBlastDamage(0.0, power);
    try std.testing.expect(dmg_0m >= 73.0);
    try std.testing.expect(isLethalDamage(dmg_0m));
    try std.testing.expect(isDamageLethalAtDistance(0.0, power));

    // 3m: ~56 HP damage (lethal)
    const dmg_3m = calculateRadialBlastDamage(3.0, power);
    try std.testing.expect(dmg_3m >= 55.0);
    try std.testing.expect(isDamageLethalAtDistance(3.0, power));

    // 6m: ~41 HP damage (lethal)
    const dmg_6m = calculateRadialBlastDamage(6.0, power);
    try std.testing.expect(dmg_6m >= 40.0);
    try std.testing.expect(isDamageLethalAtDistance(6.0, power));

    // 10m: ~24 HP damage (still lethal to 20 HP player!)
    const dmg_10m = calculateRadialBlastDamage(10.0, power);
    try std.testing.expect(dmg_10m >= 20.0);
    try std.testing.expect(isDamageLethalAtDistance(10.0, power));

    // 14m: ~11 HP damage (non-lethal, player survives)
    const dmg_14m = calculateRadialBlastDamage(14.0, power);
    try std.testing.expect(dmg_14m < 20.0 and dmg_14m > 0.0);
    try std.testing.expect(!isDamageLethalAtDistance(14.0, power));

    // Beyond 18m blast radius: 0 damage
    try std.testing.expectEqual(@as(f32, 0.0), calculateRadialBlastDamage(18.0, power));
    try std.testing.expectEqual(@as(f32, 0.0), calculateRadialBlastDamage(25.0, power));
}

test "24. ExplosionPhysics: blast impulse applies radial knockback and vertical velocity" {
    const center = Vec3.init(0.0, 64.0, 0.0);
    const target = Vec3.init(3.0, 64.0, 0.0);

    const impulse = calculateBlastImpulse(target, center, RESPAWN_ANCHOR_EXPLOSION_POWER);
    try std.testing.expect(impulse != null);

    const imp = impulse.?;
    // Target is +3 on X, so push must be positive on X and 0 on Z
    try std.testing.expect(imp.vel_x > 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), imp.vel_z, 0.001);
    // Vertical lift component launches entity upward
    try std.testing.expect(imp.vel_y > 5.0);
    try std.testing.expect(imp.magnitude > 10.0);
}

test "25. ExplosionPhysics: blast ray shatters dirt and stone while obsidian withstands" {
    const power = RESPAWN_ANCHOR_EXPLOSION_POWER;

    // Dirt layers (resistance 0.5) breached by power 9.0 ray vs power 4.0 TNT ray
    const dirt_layers = [_]f32{StandardResistances.dirt} ** 25;
    const anchor_dirt_breached = BlastRayAttenuation.countBreachedBlocks(power, &dirt_layers);
    const tnt_dirt_breached = BlastRayAttenuation.countBreachedBlocks(TNT_EXPLOSION_POWER, &dirt_layers);

    try std.testing.expect(anchor_dirt_breached >= 19);
    try std.testing.expect(tnt_dirt_breached <= 9);
    try std.testing.expect(anchor_dirt_breached > tnt_dirt_breached * 2);

    // Stone layers (resistance 6.0)
    const stone_layers = [_]f32{StandardResistances.stone} ** 10;
    const anchor_stone_breached = BlastRayAttenuation.countBreachedBlocks(power, &stone_layers);
    const tnt_stone_breached = BlastRayAttenuation.countBreachedBlocks(TNT_EXPLOSION_POWER, &stone_layers);

    try std.testing.expectEqual(@as(usize, 5), anchor_stone_breached);
    try std.testing.expectEqual(@as(usize, 2), tnt_stone_breached);

    // Obsidian layers (resistance 1200.0) stops blast ray on the first block
    const obsidian_layers = [_]f32{StandardResistances.obsidian} ** 5;
    const penetrated = BlastRayAttenuation.countPenetratedBlocks(power, &obsidian_layers);
    try std.testing.expectEqual(@as(usize, 0), penetrated);

    // canShatterBlock evaluation
    try std.testing.expect(BlastRayAttenuation.canShatterBlock(power, StandardResistances.dirt, 5.0));
    try std.testing.expect(BlastRayAttenuation.canShatterBlock(power, StandardResistances.stone, 5.0));
    try std.testing.expect(!BlastRayAttenuation.canShatterBlock(power, StandardResistances.obsidian, 1.0));
    try std.testing.expect(!BlastRayAttenuation.canShatterBlock(power, StandardResistances.bedrock, 1.0));
}

test "26. ExplosionPhysics: fire placement and ignition conditions in blast zone" {
    // 1 in 3 chance ignition
    try std.testing.expect(FirePlacement.shouldIgniteFire(0.1));
    try std.testing.expect(FirePlacement.shouldIgniteFire(0.3));
    try std.testing.expect(!FirePlacement.shouldIgniteFire(0.5));
    try std.testing.expect(!FirePlacement.shouldIgniteFire(0.9));

    // Fire requires solid floor and air space
    try std.testing.expect(FirePlacement.canSupportFire(true, true));
    try std.testing.expect(!FirePlacement.canSupportFire(false, true)); // Cannot burn in mid-air
    try std.testing.expect(!FirePlacement.canSupportFire(true, false)); // Cannot burn inside solid block
}

test "27. FullLifecycle: complete charging, nether spawn binding, respawns to depletion, and overworld blast" {
    const world = FlatNetherWorld{ .floor_y = 63 };
    var anchor = RespawnAnchor.init(BlockPos.init(0, 64, 0));

    // 1. Charge to 4 with glowstone
    for (0..4) |_| {
        const res = interact(&anchor, .nether, true, null);
        try std.testing.expectEqual(InteractionAction.charge_success, res.action);
    }
    try std.testing.expectEqual(@as(u8, 4), anchor.charges);
    try std.testing.expectEqual(@as(u8, 15), anchor.lightLevel());
    try std.testing.expectEqual(@as(u8, 15), anchor.comparatorSignal());

    // 2. Bind spawn point
    const bind_res = interact(&anchor, .nether, false, 101);
    try std.testing.expectEqual(InteractionAction.bind_spawn_success, bind_res.action);
    try std.testing.expect(anchor.is_spawn_bound);

    // 3. Four successive player deaths and respawns
    var deaths: usize = 0;
    while (deaths < 4) : (deaths += 1) {
        const respawn_res = respawnPlayer(&anchor, .nether, world);
        try std.testing.expect(respawn_res.success);
        try std.testing.expect(respawn_res.spawn_pos != null);
    }

    // Anchor is now depleted
    try std.testing.expect(anchor.isUncharged());
    try std.testing.expectEqual(@as(u8, 0), anchor.lightLevel());
    try std.testing.expectEqual(@as(u8, 0), anchor.comparatorSignal());

    // Next respawn attempt fails
    const fail_respawn = respawnPlayer(&anchor, .nether, world);
    try std.testing.expect(!fail_respawn.success);
    try std.testing.expectEqual(RespawnFailureReason.no_charges, fail_respawn.failure_reason.?);

    // 4. Recharge to 1 and place in Overworld -> detonation
    _ = interact(&anchor, .overworld, true, null);
    try std.testing.expectEqual(@as(u8, 1), anchor.charges);

    const boom = interact(&anchor, .overworld, false, null);
    try std.testing.expectEqual(InteractionAction.catastrophic_explosion, boom.action);
    try std.testing.expectEqual(@as(u8, 0), anchor.charges);
}
