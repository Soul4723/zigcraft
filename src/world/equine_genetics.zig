const std = @import("std");

pub const HorseCoatColor = enum(u8) { white, creamy, chestnut, brown, black, gray, dark_brown };
pub const HorseMarking = enum(u8) { none, white_stockings, white_field, white_dots, black_dots };

pub const Coat = struct { color: HorseCoatColor, marking: HorseMarking };
pub const coat_color_count = 7;
pub const marking_count = 5;
pub const coat_combination_count = coat_color_count * marking_count;
pub const mutation_denominator = 9;

/// One of nine equally likely outcomes mutates to a uniformly selected coat.
/// mutation_roll must be in 0...8; random indexes are clamped by modulo.
pub fn breedHorseCoat(parent_a: Coat, parent_b: Coat, mutation_roll: u8, random_color_index: u8, random_marking_index: u8) Coat {
    if (mutation_roll % mutation_denominator == 0) return .{
        .color = @enumFromInt(random_color_index % coat_color_count),
        .marking = @enumFromInt(random_marking_index % marking_count),
    };
    return .{
        .color = if (mutation_roll % 2 == 0) parent_a.color else parent_b.color,
        .marking = if (mutation_roll % 2 == 0) parent_a.marking else parent_b.marking,
    };
}

pub const EquineStats = struct { foal_speed: f32, foal_jump: f32, foal_hp: f32 };
pub const min_horse_speed: f32 = 4.7;
pub const max_horse_speed: f32 = 14.23;
pub const min_horse_jump: f32 = 1.0;
pub const max_horse_jump: f32 = 5.25;
pub const min_horse_hp: f32 = 15.0;
pub const max_horse_hp: f32 = 30.0;

fn inherited(a: f32, b: f32, roll: f32, min: f32, max: f32) f32 {
    const sample = min + (std.math.clamp(roll, -1.0, 1.0) + 1.0) * 0.5 * (max - min);
    return std.math.clamp((a + b + sample) / 3.0, min, max);
}

pub fn breedEquineStats(parent_a_speed: f32, parent_b_speed: f32, parent_a_jump: f32, parent_b_jump: f32, parent_a_hp: f32, parent_b_hp: f32, random_variation_neg1_to_pos1: f32) EquineStats {
    return .{
        .foal_speed = inherited(parent_a_speed, parent_b_speed, random_variation_neg1_to_pos1, min_horse_speed, max_horse_speed),
        .foal_jump = inherited(parent_a_jump, parent_b_jump, random_variation_neg1_to_pos1, min_horse_jump, max_horse_jump),
        .foal_hp = inherited(parent_a_hp, parent_b_hp, random_variation_neg1_to_pos1, min_horse_hp, max_horse_hp),
    };
}

pub const TemperResult = struct { tamed: bool, bucked_rider_off: bool };
/// A failed attempt raises temper by five. Feeding sugar, apples, or golden carrots
/// may raise temper before this call; this helper deliberately owns only ride attempts.
pub fn tryTameWildHorse(current_temper_0_to_100: *u7, roll_0_to_99: u7) TemperResult {
    const temper = @min(current_temper_0_to_100.*, 100);
    if (roll_0_to_99 < temper) return .{ .tamed = true, .bucked_rider_off = false };
    current_temper_0_to_100.* = @intCast(@min(100, @as(u16, temper) + 5));
    return .{ .tamed = false, .bucked_rider_off = true };
}

pub const jump_sweet_spot_bonus: f32 = 0.25;
/// Linear charge curve, with an extra sweet-spot bonus at full charge.
pub fn computeHorseJumpHeight(jump_strength: f32, charge_bar_0_to_1: f32) f32 {
    const charge = std.math.clamp(charge_bar_0_to_1, 0.0, 1.0);
    return jump_strength * charge * (1.0 + if (charge == 1.0) jump_sweet_spot_bonus else 0.0);
}

pub const ChestSaddlebag = struct { slots: [15]?u16 = [_]?u16{null} ** 15 };
pub const Mule = struct { sterile: bool = true, saddlebag: ChestSaddlebag = .{} };
pub fn breedHorseWithDonkey() Mule {
    return .{};
}

pub const SkeletonHorseman = struct {
    has_skeleton: bool = true,
    enchanted_iron_helmet: bool = true,
    enchanted_bow: bool = true,
    rides_tamed_skeleton_horse: bool = true,
};
pub const SkeletonHorseTrap = struct { active: bool = true };
pub const SkeletonHorsemen = struct { horsemen: [4]SkeletonHorseman };
pub fn lightningStrikeTrap(trap: *SkeletonHorseTrap, thunderstorm: bool) ?SkeletonHorsemen {
    if (!thunderstorm or !trap.active) return null;
    trap.active = false;
    return .{ .horsemen = [_]SkeletonHorseman{.{}} ** 4 };
}
pub fn skeletonHorsesCanWalkUnderwater() bool {
    return true;
}

test "35 coat combinations are represented by all color-marking pairs" {
    try std.testing.expectEqual(@as(usize, 35), coat_combination_count);
    var seen: [7][5]bool = [_][5]bool{[_]bool{false} ** 5} ** 7;
    for (0..7) |c| for (0..5) |m| {
        const coat = Coat{ .color = @enumFromInt(c), .marking = @enumFromInt(m) };
        seen[@intFromEnum(coat.color)][@intFromEnum(coat.marking)] = true;
    };
    for (seen) |row| for (row) |present| try std.testing.expect(present);
}

test "coat breeding mutates on one of nine rolls and selects random coat" {
    const a = Coat{ .color = .white, .marking = .none };
    const b = Coat{ .color = .black, .marking = .black_dots };
    const mutation = breedHorseCoat(a, b, 0, 6, 4);
    try std.testing.expectEqual(HorseCoatColor.dark_brown, mutation.color);
    try std.testing.expectEqual(HorseMarking.black_dots, mutation.marking);
    try std.testing.expectEqual(b.color, breedHorseCoat(a, b, 1, 6, 4).color);
    var mutated: usize = 0;
    for (0..9) |roll| if (breedHorseCoat(a, b, @intCast(roll), 2, 3).color == .chestnut) { mutated += 1; };
    try std.testing.expectEqual(@as(usize, 1), mutated);
}

test "all coat enum variants can be selected by mutation" {
    for (0..7) |c| for (0..5) |m| {
        const result = breedHorseCoat(.{ .color = .white, .marking = .none }, .{ .color = .white, .marking = .none }, 0, @intCast(c), @intCast(m));
        try std.testing.expectEqual(c, @intFromEnum(result.color));
        try std.testing.expectEqual(m, @intFromEnum(result.marking));
    };
}

test "equine stats average parents and random sample" {
    const s = breedEquineStats(8, 11, 2, 4, 18, 24, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 9.488334), s.foal_speed, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.041667), s.foal_jump, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 21.5), s.foal_hp, 0.001);
}

test "equine stat inheritance clamps each attribute" {
    const low = breedEquineStats(-100, -100, -10, -10, -1, -1, -1);
    const high = breedEquineStats(100, 100, 10, 10, 100, 100, 1);
    try std.testing.expectEqual(min_horse_speed, low.foal_speed);
    try std.testing.expectEqual(min_horse_jump, low.foal_jump);
    try std.testing.expectEqual(min_horse_hp, low.foal_hp);
    try std.testing.expectEqual(max_horse_speed, high.foal_speed);
    try std.testing.expectEqual(max_horse_jump, high.foal_jump);
    try std.testing.expectEqual(max_horse_hp, high.foal_hp);
}

test "horse and donkey produce sterile mule with 15-slot chest saddlebag" {
    const mule = breedHorseWithDonkey();
    try std.testing.expect(mule.sterile);
    try std.testing.expectEqual(@as(usize, 15), mule.saddlebag.slots.len);
    for (mule.saddlebag.slots) |slot| try std.testing.expect(slot == null);
}

test "wild horse tames when roll is below temper" {
    var temper: u7 = 20;
    const result = tryTameWildHorse(&temper, 19);
    try std.testing.expect(result.tamed);
    try std.testing.expect(!result.bucked_rider_off);
    try std.testing.expectEqual(@as(u7, 20), temper);
}

test "failed ride bucks and increases temper by five" {
    var temper: u7 = 20;
    const result = tryTameWildHorse(&temper, 20);
    try std.testing.expect(!result.tamed);
    try std.testing.expect(result.bucked_rider_off);
    try std.testing.expectEqual(@as(u7, 25), temper);
}

test "temper increment caps at one hundred" {
    var temper: u7 = 99;
    _ = tryTameWildHorse(&temper, 99);
    try std.testing.expectEqual(@as(u7, 100), temper);
}

test "temper values above one hundred are treated as one hundred" {
    var temper: u7 = 100;
    const result = tryTameWildHorse(&temper, 99);
    try std.testing.expect(result.tamed);
}

test "jump charge curve clamps charge and rewards full charge" {
    try std.testing.expectEqual(@as(f32, 0), computeHorseJumpHeight(4, 0));
    try std.testing.expectEqual(@as(f32, 2), computeHorseJumpHeight(4, 0.5));
    try std.testing.expectEqual(@as(f32, 5), computeHorseJumpHeight(4, 1));
    try std.testing.expectEqual(@as(f32, 5), computeHorseJumpHeight(4, 2));
}

test "jump charge rises monotonically toward sweet spot" {
    const half = computeHorseJumpHeight(3, 0.5);
    const full = computeHorseJumpHeight(3, 1);
    try std.testing.expect(full > half);
    try std.testing.expectApproxEqAbs(@as(f32, 3.75), full, 0.0001);
}

test "skeleton horse trap splits into four equipped horsemen during storm" {
    var trap = SkeletonHorseTrap{};
    try std.testing.expect(lightningStrikeTrap(&trap, false) == null);
    const riders = lightningStrikeTrap(&trap, true).?;
    try std.testing.expectEqual(@as(usize, 4), riders.horsemen.len);
    for (riders.horsemen) |rider| {
        try std.testing.expect(rider.has_skeleton and rider.enchanted_iron_helmet and rider.enchanted_bow and rider.rides_tamed_skeleton_horse);
    }
    try std.testing.expect(lightningStrikeTrap(&trap, true) == null);
}

test "skeleton horses walk underwater" {
    try std.testing.expect(skeletonHorsesCanWalkUnderwater());
}
