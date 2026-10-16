const std = @import("std");

pub const resurrection_hp: f32 = 10.0;
pub const resurrection_hunger: f32 = 20.0;
pub const resurrection_fire_res_duration: f32 = 45.0;
pub const regeneration_potion_hp: f32 = 10.0;

pub const TotemActivation = struct {
    triggered: bool,
    new_hp: f32,
    new_hunger: f32,
    fire_res_timer: f32,
    clear_debuffs: bool,
};

pub fn evaluateFatalDamage(current_hp: f32, has_totem: bool, current_fire_res: f32) TotemActivation {
    if (current_hp > 0.0 or !has_totem) {
        return .{
            .triggered = false,
            .new_hp = current_hp,
            .new_hunger = 0.0,
            .fire_res_timer = current_fire_res,
            .clear_debuffs = false,
        };
    }
    return .{
        .triggered = true,
        .new_hp = resurrection_hp,
        .new_hunger = resurrection_hunger,
        .fire_res_timer = @max(current_fire_res, resurrection_fire_res_duration),
        .clear_debuffs = true,
    };
}

pub fn applyRegenerationPotion(current_hp: f32, max_hp: f32) f32 {
    return @min(max_hp, current_hp + regeneration_potion_hp);
}

test "constants have expected values" {
    try std.testing.expectEqual(@as(f32, 10.0), resurrection_hp);
    try std.testing.expectEqual(@as(f32, 20.0), resurrection_hunger);
    try std.testing.expectEqual(@as(f32, 45.0), resurrection_fire_res_duration);
    try std.testing.expectEqual(@as(f32, 10.0), regeneration_potion_hp);
}

test "no activation when alive" {
    const result = evaluateFatalDamage(5.0, true, 3.0);
    try std.testing.expect(!result.triggered);
    try std.testing.expectEqual(@as(f32, 5.0), result.new_hp);
    try std.testing.expectEqual(@as(f32, 0.0), result.new_hunger);
    try std.testing.expectEqual(@as(f32, 3.0), result.fire_res_timer);
    try std.testing.expect(!result.clear_debuffs);
}

test "no activation without totem at zero hp" {
    const result = evaluateFatalDamage(0.0, false, 7.0);
    try std.testing.expect(!result.triggered);
    try std.testing.expectEqual(@as(f32, 0.0), result.new_hp);
    try std.testing.expectEqual(@as(f32, 0.0), result.new_hunger);
    try std.testing.expectEqual(@as(f32, 7.0), result.fire_res_timer);
    try std.testing.expect(!result.clear_debuffs);
}

test "no activation without totem on negative hp" {
    const result = evaluateFatalDamage(-4.0, false, 0.0);
    try std.testing.expect(!result.triggered);
    try std.testing.expectEqual(@as(f32, -4.0), result.new_hp);
    try std.testing.expect(!result.clear_debuffs);
}

test "activation on fatal damage with totem" {
    const result = evaluateFatalDamage(0.0, true, 0.0);
    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(resurrection_hp, result.new_hp);
    try std.testing.expectEqual(resurrection_hunger, result.new_hunger);
    try std.testing.expectEqual(resurrection_fire_res_duration, result.fire_res_timer);
    try std.testing.expect(result.clear_debuffs);
}

test "activation keeps longer existing fire resistance" {
    const result = evaluateFatalDamage(-1.0, true, 90.0);
    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(@as(f32, 90.0), result.fire_res_timer);
}

test "activation when current fire resistance is shorter" {
    const result = evaluateFatalDamage(0.0, true, 10.0);
    try std.testing.expect(result.triggered);
    try std.testing.expectEqual(resurrection_fire_res_duration, result.fire_res_timer);
}

test "regeneration potion heals normally" {
    try std.testing.expectEqual(@as(f32, 12.0), applyRegenerationPotion(2.0, 20.0));
}

test "regeneration potion clamps to max hp" {
    try std.testing.expectEqual(@as(f32, 20.0), applyRegenerationPotion(15.0, 20.0));
}

test "regeneration potion at full hp stays full" {
    try std.testing.expectEqual(@as(f32, 20.0), applyRegenerationPotion(20.0, 20.0));
}

test "regeneration potion from zero hp" {
    try std.testing.expectEqual(regeneration_potion_hp, applyRegenerationPotion(0.0, 20.0));
}
