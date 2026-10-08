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
    if (is_underwater) {
        return @max(0.0, oxygen - dt);
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
    return block == .campfire or block == .tnt;
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
