const std = @import("std");

pub const multishot_arrow_count: u8 = 3;
pub const multishot_crossbow_durability_cost: u8 = 3;

/// `power_level` is the displayed enchantment level (0 means unenchanted).
/// Power I adds 50%; Power V adds 150% to a fully charged base hit.
pub fn computePowerBowDamage(base_full_charge_damage: f32, power_level_0_to_5: u3) f32 {
    if (power_level_0_to_5 == 0) return base_full_charge_damage;
    const multiplier = 1.0 + 0.25 * (@as(f32, @floatFromInt(power_level_0_to_5)) + 1.0);
    return base_full_charge_damage * multiplier;
}

/// Returns whether firing consumes the ammunition item. Infinity preserves
/// only a regular, untipped arrow; spectral and tipped arrows are consumed.
pub fn resolveBowInfinityArrowConsumption(has_infinity: bool, arrow_is_regular_untipped: bool) bool {
    return !(has_infinity and arrow_is_regular_untipped);
}

pub fn canCombineInfinityAndMending() bool {
    return false;
}

pub fn computeCrossbowReloadSeconds(quick_charge_level_0_to_3: u2) f32 {
    return 1.25 - 0.25 * @as(f32, @floatFromInt(quick_charge_level_0_to_3));
}

/// Multishot emits a three-arrow fan; without it, only the center arrow fires.
pub fn computeMultishotFanAnglesDeg(has_multishot: bool) [3]f32 {
    if (has_multishot) return .{ -10.0, 0.0, 10.0 };
    return .{ 0.0, 0.0, 0.0 };
}

pub fn canCombineMultishotAndPiercing() bool {
    return false;
}

pub const CrossbowPiercingHit = struct {
    bypasses_shield_completely: bool,
    max_entities_pierced: u3,
    recoverable_after_piercing: bool,
};

pub fn resolveCrossbowPiercingHit(piercing_level_0_to_4: u3, target_blocking_with_shield: bool) CrossbowPiercingHit {
    // Shield state is included in the query context; Piercing bypass is a
    // property of the projectile even when this particular target is not guarding.
    _ = target_blocking_with_shield;
    return .{
        .bypasses_shield_completely = piercing_level_0_to_4 > 0,
        .max_entities_pierced = piercing_level_0_to_4 + 1,
        .recoverable_after_piercing = true,
    };
}

test "Power I through V add 50 to 150 percent damage" {
    const expected = [_]f32{ 15.0, 17.5, 20.0, 22.5, 25.0 };
    for (expected, 0..) |damage, index| {
        const level: u3 = @intCast(index + 1);
        try std.testing.expectApproxEqAbs(damage, computePowerBowDamage(10.0, level), 0.001);
    }
    try std.testing.expectEqual(@as(f32, 10.0), computePowerBowDamage(10.0, 0));
}

test "Infinity preserves only regular untipped arrows" {
    try std.testing.expect(!resolveBowInfinityArrowConsumption(true, true));
    try std.testing.expect(resolveBowInfinityArrowConsumption(true, false));
    try std.testing.expect(resolveBowInfinityArrowConsumption(false, true));
    try std.testing.expect(resolveBowInfinityArrowConsumption(false, false));
}

test "Infinity and Mending cannot be combined" {
    try std.testing.expect(!canCombineInfinityAndMending());
}

test "Quick Charge I through III shorten reload by quarter seconds" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), computeCrossbowReloadSeconds(1), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), computeCrossbowReloadSeconds(2), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), computeCrossbowReloadSeconds(3), 0.001);
}

test "unenchanted crossbow reload is 1.25 seconds" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), computeCrossbowReloadSeconds(0), 0.001);
}

test "Multishot fires a -10 0 +10 degree fan" {
    const angles = computeMultishotFanAnglesDeg(true);
    try std.testing.expectEqual([3]f32{ -10.0, 0.0, 10.0 }, angles);
    try std.testing.expectEqual(multishot_arrow_count, 3);
    try std.testing.expectEqual(multishot_crossbow_durability_cost, 3);
}

test "without Multishot only the center lane is used" {
    try std.testing.expectEqual([3]f32{ 0.0, 0.0, 0.0 }, computeMultishotFanAnglesDeg(false));
}

test "Multishot and Piercing cannot be combined" {
    try std.testing.expect(!canCombineMultishotAndPiercing());
}

test "Piercing I bypasses a raised shield and pierces two entities" {
    const hit = resolveCrossbowPiercingHit(1, true);
    try std.testing.expect(hit.bypasses_shield_completely);
    try std.testing.expectEqual(@as(u3, 2), hit.max_entities_pierced);
    try std.testing.expect(hit.recoverable_after_piercing);
}

test "Piercing II bypasses shields and pierces three entities" {
    const hit = resolveCrossbowPiercingHit(2, true);
    try std.testing.expect(hit.bypasses_shield_completely);
    try std.testing.expectEqual(@as(u3, 3), hit.max_entities_pierced);
}

test "Piercing III bypasses shields and pierces four entities" {
    const hit = resolveCrossbowPiercingHit(3, true);
    try std.testing.expect(hit.bypasses_shield_completely);
    try std.testing.expectEqual(@as(u3, 4), hit.max_entities_pierced);
}

test "Piercing IV bypasses shields and pierces five entities" {
    const hit = resolveCrossbowPiercingHit(4, true);
    try std.testing.expect(hit.bypasses_shield_completely);
    try std.testing.expectEqual(@as(u3, 5), hit.max_entities_pierced);
    try std.testing.expect(hit.recoverable_after_piercing);
}

test "ordinary crossbow projectile does not bypass a shield" {
    const hit = resolveCrossbowPiercingHit(0, true);
    try std.testing.expect(!hit.bypasses_shield_completely);
    try std.testing.expectEqual(@as(u3, 1), hit.max_entities_pierced);
    try std.testing.expect(hit.recoverable_after_piercing);
}

test "Piercing remains a shield-bypassing projectile when target is not blocking" {
    const hit = resolveCrossbowPiercingHit(2, false);
    try std.testing.expect(hit.bypasses_shield_completely);
    try std.testing.expectEqual(@as(u3, 3), hit.max_entities_pierced);
}
