const std = @import("std");

pub const insomnia_threshold_seconds: f32 = 3600.0;
pub const insomnia_threshold_ticks: u32 = 72_000;
pub const minimum_phantom_altitude: f32 = 20.0;
pub const maximum_phantom_altitude: f32 = 25.0;
pub const phantom_dive_speed: f32 = 20.0;
pub const phantom_bite_damage: f32 = 6.0;
pub const cat_hiss_range: f32 = 16.0;

pub const InsomniaTracker = struct {
    time_since_last_rest_seconds: f32 = 0.0,

    pub fn tick(self: *InsomniaTracker, elapsed_seconds: f32) void {
        self.time_since_last_rest_seconds = @max(0.0, self.time_since_last_rest_seconds + elapsed_seconds);
    }

    pub fn enterBed(self: *InsomniaTracker) void {
        self.time_since_last_rest_seconds = 0.0;
    }
};

pub const PhantomSpawnChance = struct { should_spawn: bool, pack_size: u3 };

pub fn evaluatePhantomSpawnChance(time_since_rest: f32, is_night_or_thunder: bool, player_above_sea_level: bool, sky_exposed: bool, roll_0_to_1: f32) PhantomSpawnChance {
    if (time_since_rest < insomnia_threshold_seconds or !is_night_or_thunder or !player_above_sea_level or !sky_exposed)
        return .{ .should_spawn = false, .pack_size = 0 };
    const probability = @min(1.0, (time_since_rest - insomnia_threshold_seconds) / time_since_rest);
    if (roll_0_to_1 < 0.0 or roll_0_to_1 >= probability)
        return .{ .should_spawn = false, .pack_size = 0 };
    const normalized_roll = @min(0.999999, @max(0.0, roll_0_to_1));
    const count: u3 = @intFromFloat(1.0 + @floor(normalized_roll * 4.0));
    return .{ .should_spawn = true, .pack_size = @min(count, 4) };
}

pub const PhantomFlightPhase = enum { circling_high_altitude, diving_swoop_attack, climbing_retreat };

pub const PhantomFlightState = struct {
    phase: PhantomFlightPhase = .circling_high_altitude,
    altitude_above_target: f32 = minimum_phantom_altitude,
    fleeing_cat_hiss: bool = false,

    pub fn beginDive(self: *PhantomFlightState, cat_nearby: bool) void {
        if (cat_nearby) {
            self.fleeing_cat_hiss = true;
            self.phase = .climbing_retreat;
        } else if (self.phase == .circling_high_altitude) {
            self.fleeing_cat_hiss = false;
            self.phase = .diving_swoop_attack;
        }
    }

    pub fn biteDamage(self: PhantomFlightState) f32 {
        return if (self.phase == .diving_swoop_attack) phantom_bite_damage else 0.0;
    }

    pub fn struckByMelee(self: *PhantomFlightState) void {
        if (self.phase == .diving_swoop_attack) self.phase = .climbing_retreat;
    }

    pub fn afterBiting(self: *PhantomFlightState) void {
        if (self.phase == .diving_swoop_attack) self.phase = .climbing_retreat;
    }

    pub fn climb(self: *PhantomFlightState, elapsed_seconds: f32) void {
        if (self.phase != .climbing_retreat) return;
        self.altitude_above_target = @min(maximum_phantom_altitude, self.altitude_above_target + phantom_dive_speed * elapsed_seconds);
        if (self.altitude_above_target >= minimum_phantom_altitude) self.phase = .circling_high_altitude;
    }
};

pub fn isBurningInDaylight(is_daylight: bool, sky_exposed: bool) bool {
    return is_daylight and sky_exposed;
}

pub fn resolveUndeadPotionInversion(is_healing_potion: bool, is_harming_potion: bool) f32 {
    if (is_harming_potion) return 4.0;
    if (is_healing_potion) return -4.0;
    return 0.0;
}

pub fn smiteBonusDamage(level: u8) f32 {
    return @as(f32, @floatFromInt(level)) * 2.5;
}

test "insomnia threshold is three days and no spawn before threshold" {
    try std.testing.expectEqual(@as(u32, 72_000), insomnia_threshold_ticks);
    try std.testing.expect(!evaluatePhantomSpawnChance(3599.99, true, true, true, 0.0).should_spawn);
    try std.testing.expect(!evaluatePhantomSpawnChance(3600.0, true, true, true, 0.0).should_spawn);
}

test "bed rest resets accumulated insomnia" {
    var tracker = InsomniaTracker{};
    tracker.tick(3600.0);
    tracker.enterBed();
    try std.testing.expectEqual(@as(f32, 0.0), tracker.time_since_last_rest_seconds);
}

test "tracker accumulates elapsed seconds" {
    var tracker = InsomniaTracker{};
    tracker.tick(120.0);
    try std.testing.expectEqual(@as(f32, 120.0), tracker.time_since_last_rest_seconds);
}

test "spawn requires night or thunderstorm" {
    try std.testing.expect(!evaluatePhantomSpawnChance(7200, false, true, true, 0).should_spawn);
}

test "spawn requires player above sea level" {
    try std.testing.expect(!evaluatePhantomSpawnChance(7200, true, false, true, 0).should_spawn);
}

test "spawn requires exposed sky" {
    try std.testing.expect(!evaluatePhantomSpawnChance(7200, true, true, false, 0).should_spawn);
}

test "spawn probability follows insomnia fraction" {
    const chance = evaluatePhantomSpawnChance(7200, true, true, true, 0.40);
    try std.testing.expect(chance.should_spawn);
    try std.testing.expectEqual(@as(u3, 2), chance.pack_size);
    try std.testing.expect(!evaluatePhantomSpawnChance(7200, true, true, true, 0.5).should_spawn);
}

test "pack sizes stay between one and four" {
    const small = evaluatePhantomSpawnChance(10_000, true, true, true, 0.0);
    const large = evaluatePhantomSpawnChance(10_000, true, true, true, 0.001);
    try std.testing.expect(small.pack_size >= 1 and small.pack_size <= 4);
    try std.testing.expect(large.pack_size >= 1 and large.pack_size <= 4);
}

test "phantom begins circling high above target" {
    const state = PhantomFlightState{};
    try std.testing.expectEqual(PhantomFlightPhase.circling_high_altitude, state.phase);
    try std.testing.expect(state.altitude_above_target >= 20 and state.altitude_above_target <= 25);
}

test "circle transitions into dive and deals six bite damage" {
    var state = PhantomFlightState{};
    state.beginDive(false);
    try std.testing.expectEqual(PhantomFlightPhase.diving_swoop_attack, state.phase);
    try std.testing.expectEqual(@as(f32, 20.0), phantom_dive_speed);
    try std.testing.expectEqual(@as(f32, 6.0), state.biteDamage());
    state.afterBiting();
    try std.testing.expectEqual(PhantomFlightPhase.climbing_retreat, state.phase);
}

test "melee strike during dive aborts to climb" {
    var state = PhantomFlightState{};
    state.beginDive(false);
    state.struckByMelee();
    try std.testing.expectEqual(PhantomFlightPhase.climbing_retreat, state.phase);
}

test "cat within sixteen blocks hisses and repels phantom" {
    var state = PhantomFlightState{};
    state.beginDive(true);
    try std.testing.expect(state.fleeing_cat_hiss);
    try std.testing.expectEqual(PhantomFlightPhase.climbing_retreat, state.phase);
    try std.testing.expectEqual(@as(f32, 16.0), cat_hiss_range);
}

test "climbing retreat returns to circling altitude" {
    var state = PhantomFlightState{ .phase = .climbing_retreat, .altitude_above_target = 10.0 };
    state.climb(0.5);
    try std.testing.expectEqual(PhantomFlightPhase.circling_high_altitude, state.phase);
    try std.testing.expectEqual(@as(f32, 20.0), state.altitude_above_target);
}

test "phantom burns in exposed daylight only" {
    try std.testing.expect(isBurningInDaylight(true, true));
    try std.testing.expect(!isBurningInDaylight(false, true));
    try std.testing.expect(!isBurningInDaylight(true, false));
}

test "undead potion effects invert healing and harming" {
    try std.testing.expect(resolveUndeadPotionInversion(true, false) < 0);
    try std.testing.expect(resolveUndeadPotionInversion(false, true) > 0);
    try std.testing.expectEqual(@as(f32, 0), resolveUndeadPotionInversion(false, false));
}

test "phantom receives bonus smite damage" {
    try std.testing.expect(smiteBonusDamage(2) > 0);
}
