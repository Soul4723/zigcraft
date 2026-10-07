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

pub fn applyDamageClamped(current_health: f32, rate: f32, dt: f32) f32 {
    return @max(0.0, current_health - rate * dt);
}

test "applyDamageClamped calculation" {
    try std.testing.expectEqual(@as(f32, 18.0), applyDamageClamped(20.0, 2.0, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), applyDamageClamped(1.0, 5.0, 1.0));
}
