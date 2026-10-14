const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

pub const HazardType = enum {
    none,
    suffocation,
    cactus,
    drowning,
};

pub fn checkSuffocation(eye_block: BlockId) bool {
    return eye_block.is_solid() and eye_block != .leaves and eye_block != .glass;
}

pub const burn_rate: f32 = 2.0;
pub const contact_rate: f32 = 1.0;
pub const max_oxygen: f32 = 15.0;
pub const drown_rate: f32 = 2.0;
pub const oxygen_recovery_rate: f32 = 6.0;

pub fn checkDrowning(eye_block: BlockId) bool {
    return eye_block == .water;
}

pub fn tickOxygen(oxygen: f32, is_underwater: bool, dt: f32) f32 {
    return tickOxygenRespiration(oxygen, is_underwater, false, false, dt);
}

pub fn tickOxygenRespiration(oxygen: f32, is_underwater: bool, has_respiration: bool, has_water_breathing: bool, dt: f32) f32 {
    if (is_underwater) {
        // Water breathing buff completely prevents oxygen depletion
        if (has_water_breathing) return oxygen;
        // Netherite helmet respiration cuts oxygen consumption in half (2x breath duration)
        const drain = if (has_respiration) dt * 0.5 else dt;
        return @max(0.0, oxygen - drain);
    } else {
        return @min(max_oxygen, oxygen + oxygen_recovery_rate * dt);
    }
}


/// Check if surfacing from underwater warrants a breath gasp and droplet puff.
/// Returns true when player was submerged, has now surfaced, and oxygen had depleted below threshold (<= 10.0).
pub fn shouldGaspOnSurface(was_underwater: bool, is_underwater: bool, current_oxygen: f32) bool {
    return was_underwater and !is_underwater and current_oxygen <= 10.0;
}

pub fn calculateDrowningDamage(oxygen: f32, dt: f32) f32 {
    if (oxygen <= 0.0) {
        return drown_rate * dt;
    }
    return 0.0;
}


pub const lava_burn_rate: f32 = 8.0;

pub fn checkLavaHazard(block: BlockId) bool {
    return block == .lava;
}

pub fn checkBurnContact(block: BlockId) bool {
    return block == .campfire or block == .soul_campfire or block == .tnt or block == .magma;
}

pub const BubbleColumnType = enum {
    none,
    upward,   // soul sand elevator
    downward, // magma whirlpool
};

/// Scan downward through contiguous water column from start_y to detect bubble source (soul sand or magma)
pub fn detectBubbleColumn(is_block_at_fn: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, start_y: i32, z: i32) BubbleColumnType {
    if (is_block_at_fn(x, start_y, z) != .water) return .none;
    var by = start_y;
    while (by >= 0) : (by -= 1) {
        const b = is_block_at_fn(x, by, z);
        if (b == .soul_sand) return .upward;
        if (b == .magma) return .downward;
        if (b != .water) return .none;
    }
    return .none;
}

pub fn checkCactusContact(is_block_at_fn: *const fn (x: i32, y: i32, z: i32) BlockId, px: i32, py: i32, pz: i32) bool {
    var dy: i32 = 0;
    while (dy <= 1) : (dy += 1) {
        var dx: i32 = -1;
        while (dx <= 1) : (dx += 1) {
            var dz: i32 = -1;
            while (dz <= 1) : (dz += 1) {
                if (is_block_at_fn(px + dx, py + dy, pz + dz) == .cactus) {
                    return true;
                }
            }
        }
    }
    return false;
}

test "suffocation hazard checks" {
    try std.testing.expect(checkSuffocation(.stone));
    try std.testing.expect(checkSuffocation(.dirt));
    try std.testing.expect(!checkSuffocation(.air));
    try std.testing.expect(!checkSuffocation(.leaves));
    try std.testing.expect(!checkSuffocation(.glass));
}

fn mockBlockStone(_: i32, _: i32, _: i32) BlockId {
    return .stone;
}

fn mockBlockCactus(x: i32, _: i32, _: i32) BlockId {
    if (x == 1) return .cactus;
    return .air;
}

test "cactus proximity check" {
    try std.testing.expect(!checkCactusContact(&mockBlockStone, 0, 0, 0));
    try std.testing.expect(checkCactusContact(&mockBlockCactus, 0, 0, 0));
}

test "burn hazard checks" {
    try std.testing.expect(checkBurnContact(.campfire));
    try std.testing.expect(checkBurnContact(.soul_campfire));
    try std.testing.expect(!checkBurnContact(.stone));
    try std.testing.expect(!checkBurnContact(.air));
    try std.testing.expectEqual(burn_rate, 2.0);
    try std.testing.expectEqual(contact_rate, 1.0);
}

test "drowning hazard checks" {
    try std.testing.expect(checkDrowning(.water));
    try std.testing.expect(!checkDrowning(.air));
    try std.testing.expect(!checkDrowning(.stone));

    // tick oxygen down when underwater
    const oxy1 = tickOxygen(10.0, true, 2.0);
    try std.testing.expectEqual(@as(f32, 8.0), oxy1);

    // tick oxygen clamped to 0
    const oxy0 = tickOxygen(0.5, true, 1.0);
    try std.testing.expectEqual(@as(f32, 0.0), oxy0);

    // tick oxygen recover when surfaced
    const oxy_rec = tickOxygen(8.0, false, 1.0);
    try std.testing.expectEqual(@as(f32, 14.0), oxy_rec);

    // tick oxygen recover clamped to max_oxygen
    const oxy_max = tickOxygen(14.0, false, 1.0);
    try std.testing.expectEqual(max_oxygen, oxy_max);

    // calculate drowning damage
    try std.testing.expectEqual(@as(f32, 0.0), calculateDrowningDamage(1.0, 1.0));
    try std.testing.expectEqual(@as(f32, 2.0), calculateDrowningDamage(0.0, 1.0));
}

pub fn applyDamageClamped(current_health: f32, rate: f32, dt: f32) f32 {
    return @max(0.0, current_health - rate * dt);
}

test "applyDamageClamped calculation" {
    try std.testing.expectEqual(@as(f32, 18.0), applyDamageClamped(20.0, 2.0, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), applyDamageClamped(1.0, 5.0, 1.0));
}

test "surface gasp trigger logic" {
    // Surfacing with low oxygen -> triggers gasp
    try std.testing.expect(shouldGaspOnSurface(true, false, 5.0));
    try std.testing.expect(shouldGaspOnSurface(true, false, 10.0));
    // Surfacing with near-full oxygen -> no gasp
    try std.testing.expect(!shouldGaspOnSurface(true, false, 14.0));
    // Still underwater -> no gasp
    try std.testing.expect(!shouldGaspOnSurface(true, true, 2.0));
    // Already surfaced earlier -> no gasp
    try std.testing.expect(!shouldGaspOnSurface(false, false, 2.0));
}

test "lava contact hazard check" {
    try std.testing.expect(checkLavaHazard(.lava));
    try std.testing.expect(!checkLavaHazard(.water));
    try std.testing.expect(!checkLavaHazard(.air));
    try std.testing.expectEqual(@as(f32, 8.0), lava_burn_rate);
}

fn mockColumnWorld(x: i32, y: i32, z: i32) BlockId {
    _ = z;
    if (x == 0) {
        if (y == 0) return .soul_sand;
        if (y <= 5) return .water;
    } else if (x == 1) {
        if (y == 0) return .magma;
        if (y <= 5) return .water;
    }
    return .air;
}

test "detectBubbleColumn identifies soul sand and magma columns" {
    try std.testing.expectEqual(BubbleColumnType.upward, detectBubbleColumn(&mockColumnWorld, 0, 4, 0));
    try std.testing.expectEqual(BubbleColumnType.downward, detectBubbleColumn(&mockColumnWorld, 1, 4, 0));
    try std.testing.expectEqual(BubbleColumnType.none, detectBubbleColumn(&mockColumnWorld, 2, 4, 0));
}

/// Fireball ignition: flammable floor blocks that catch a campfire flame when struck.
pub fn isFlammable(block: BlockId) bool {
    return block == .wood or block == .leaves or block == .wood_planks or block == .soul_sand;
}

/// Ignite flame block: soul sand ignites as soul campfire; wood/leaves as campfire.
pub fn ignitedFlameBlock(floor: BlockId) BlockId {
    if (floor == .soul_sand) return .soul_campfire;
    return .campfire;
}

test "fireball ignition fuel classification" {
    try std.testing.expect(isFlammable(.wood));
    try std.testing.expect(isFlammable(.leaves));
    try std.testing.expect(isFlammable(.wood_planks));
    try std.testing.expect(isFlammable(.soul_sand));
    try std.testing.expect(!isFlammable(.stone));
    try std.testing.expect(!isFlammable(.netherrack));

    try std.testing.expectEqual(BlockId.soul_campfire, ignitedFlameBlock(.soul_sand));
    try std.testing.expectEqual(BlockId.campfire, ignitedFlameBlock(.wood));
    try std.testing.expectEqual(BlockId.campfire, ignitedFlameBlock(.wood_planks));
}

/// Ignited campfire flame lifetime before burnout (player-placed campfires are permanent).
pub const ignited_flame_life: f32 = 45.0;

test "ignited flame lifetime is positive and bounded" {
    try std.testing.expect(ignited_flame_life > 0.0);
    try std.testing.expect(ignited_flame_life <= 120.0);
}

test "tickOxygenRespiration halves oxygen drain when wearing netherite helmet" {
    // Normal drain: 15.0 - 2.0 = 13.0
    try std.testing.expectEqual(@as(f32, 13.0), tickOxygenRespiration(15.0, true, false, false, 2.0));
    // Respiration drain: 15.0 - 1.0 = 14.0
    try std.testing.expectEqual(@as(f32, 14.0), tickOxygenRespiration(15.0, true, true, false, 2.0));
    // Water breathing: no drain
    try std.testing.expectEqual(@as(f32, 15.0), tickOxygenRespiration(15.0, true, false, true, 2.0));
}

pub const CloudEffect = enum {
    dragons_breath,
    lingering_poison,
    lingering_weakness,
};

pub const VaporCloud = struct {
    pos: [3]f32,
    radius: f32,
    life: f32,
    max_life: f32,
    effect: CloudEffect,

    pub fn isInside(self: VaporCloud, px: f32, py: f32, pz: f32) bool {
        const dx = px - self.pos[0];
        const dy = py - self.pos[1];
        const dz = pz - self.pos[2];
        return (dx * dx + dy * dy + dz * dz) <= (self.radius * self.radius);
    }
};

test "VaporCloud bounding sphere and effect classification" {
    const cloud = VaporCloud{
        .pos = .{ 10.0, 5.0, 10.0 },
        .radius = 3.0,
        .life = 10.0,
        .max_life = 10.0,
        .effect = .dragons_breath,
    };
    try std.testing.expect(cloud.isInside(10.5, 5.0, 10.5));
    try std.testing.expect(cloud.isInside(12.0, 5.0, 10.0));
    try std.testing.expect(!cloud.isInside(14.0, 5.0, 10.0));
    try std.testing.expectEqual(cloud.effect, .dragons_breath);
}
