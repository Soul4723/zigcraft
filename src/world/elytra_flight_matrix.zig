const std = @import("std");

pub const max_durability: u16 = 432;
pub const broken_durability: u16 = 1;
pub const ticks_per_second: u32 = 20;
pub const base_wear_probability: f32 = 1.0;
pub const stall_angle_degrees: f32 = 35.0;
pub const stall_speed_mps: f32 = 6.0;
pub const stall_recovery_speed_mps: f32 = 8.0;
pub const stalled_lift_multiplier: f32 = 0.1;
pub const terminal_dive_speed_mps: f32 = 67.5;
pub const dive_acceleration_mps2: f32 = 9.81;
pub const mending_durability_per_xp: u16 = 2;

/// A roll is supplied by the caller once per 20-tick wear interval, keeping
/// this rules module deterministic and leaving random number ownership outside.
pub fn wearProbability(unbreaking_level: u8) f32 {
    return 1.0 / (@as(f32, @floatFromInt(unbreaking_level)) + 1.0);
}

pub fn shouldConsumeWear(unbreaking_level: u8, random_roll: f32) bool {
    if (random_roll < 0.0 or random_roll >= 1.0) return false;
    return random_roll < wearProbability(unbreaking_level);
}

/// Nominal expected full-durability flight duration. The broken-at-one rule
/// means an individual new Elytra stops after 431 successful wear events.
pub fn expectedFlightSeconds(unbreaking_level: u8) f32 {
    return @as(f32, @floatFromInt(max_durability)) / wearProbability(unbreaking_level);
}

pub const DurabilityState = struct {
    durability: u16 = max_durability,
    equipped: bool = true,
    has_mending: bool = false,
    is_flying: bool = false,

    pub fn isBroken(self: DurabilityState) bool {
        return self.durability <= broken_durability;
    }

    pub fn canFly(self: DurabilityState) bool {
        return self.equipped and !self.isBroken();
    }

    pub fn startFlight(self: *DurabilityState) bool {
        if (!self.canFly()) return false;
        self.is_flying = true;
        return true;
    }

    /// Call once for each 20 ticks of active flight.
    pub fn tickFlightWear(self: *DurabilityState, unbreaking_level: u8, random_roll: f32) bool {
        if (!self.is_flying or !self.canFly()) {
            self.is_flying = false;
            return false;
        }
        if (!shouldConsumeWear(unbreaking_level, random_roll)) return false;
        self.durability -= 1;
        if (self.isBroken()) self.is_flying = false;
        return true;
    }

    /// Directly absorbed XP points restore two durability apiece with Mending.
    /// The caller must only invoke this for an orb absorbed while equipped.
    pub fn absorbExperience(self: *DurabilityState, xp_points: u16) u16 {
        if (!self.equipped or !self.has_mending or xp_points == 0) return 0;
        const missing = max_durability -| self.durability;
        const restored: u32 = @min(@as(u32, missing), @as(u32, xp_points) * mending_durability_per_xp);
        self.durability += @intCast(restored);
        return @intCast(restored);
    }
};

pub const AerodynamicState = struct {
    airspeed_mps: f32 = 0.0,
    is_stalled: bool = false,

    pub fn setAirspeed(self: *AerodynamicState, speed_mps: f32) void {
        self.airspeed_mps = @max(0.0, speed_mps);
    }
};

pub const FlightFrame = struct {
    airspeed_mps: f32,
    requested_pitch_degrees: f32,
    effective_pitch_degrees: f32,
    lift_coefficient: f32,
    is_stalled: bool,
    nose_down_tumble: bool,
};

/// Steps stall hysteresis and dive acceleration. Pitch uses the existing
/// convention: -90 degrees is a vertical dive, while positive pitch is climb.
pub fn stepAerodynamics(state: *AerodynamicState, pitch_degrees: f32, dt_seconds: f32) FlightFrame {
    if (dt_seconds > 0.0) {
        if (state.is_stalled) {
            if (state.airspeed_mps >= stall_recovery_speed_mps) state.is_stalled = false;
        } else if (pitch_degrees > stall_angle_degrees and state.airspeed_mps < stall_speed_mps) {
            state.is_stalled = true;
        }

        const tumbling = state.is_stalled;
        const effective_pitch = if (tumbling) -90.0 else pitch_degrees;
        if (effective_pitch <= -90.0) {
            state.airspeed_mps = @min(terminal_dive_speed_mps, state.airspeed_mps + dive_acceleration_mps2 * dt_seconds);
        }
        if (state.is_stalled and state.airspeed_mps >= stall_recovery_speed_mps) {
            state.is_stalled = false;
        }
    }
    const tumbling = state.is_stalled;
    return .{
        .airspeed_mps = state.airspeed_mps,
        .requested_pitch_degrees = pitch_degrees,
        .effective_pitch_degrees = if (tumbling) -90.0 else pitch_degrees,
        .lift_coefficient = if (tumbling) stalled_lift_multiplier else 1.0,
        .is_stalled = tumbling,
        .nose_down_tumble = tumbling,
    };
}

fn expectNear(actual: f32, expected: f32) !void {
    try std.testing.expect(@abs(actual - expected) < 0.001);
}

test "base durability is 432" {
    try std.testing.expectEqual(@as(u16, 432), max_durability);
}

test "wear interval is twenty ticks" {
    try std.testing.expectEqual(@as(u32, 20), ticks_per_second);
}

test "base wear chance is 100 percent" {
    try expectNear(wearProbability(0), 1.0);
}

test "Unbreaking I wear chance is 50 percent" {
    try expectNear(wearProbability(1), 0.5);
}

test "Unbreaking II wear chance is one third" {
    try expectNear(wearProbability(2), 1.0 / 3.0);
}

test "Unbreaking III wear chance is 25 percent" {
    try expectNear(wearProbability(3), 0.25);
}

test "Unbreaking I doubles nominal flight duration" {
    try expectNear(expectedFlightSeconds(1), 864.0);
}

test "Unbreaking II triples nominal flight duration" {
    try expectNear(expectedFlightSeconds(2), 1296.0);
}

test "Unbreaking III quadruples nominal flight duration" {
    try expectNear(expectedFlightSeconds(3), 1728.0);
}

test "base nominal flight is 7.2 minutes" {
    try expectNear(expectedFlightSeconds(0) / 60.0, 7.2);
}

test "Unbreaking III nominal flight is 28.8 minutes" {
    try expectNear(expectedFlightSeconds(3) / 60.0, 28.8);
}

test "wear occurs below probability threshold" {
    try std.testing.expect(shouldConsumeWear(1, 0.49));
}

test "wear does not occur at probability threshold" {
    try std.testing.expect(!shouldConsumeWear(1, 0.5));
}

test "Unbreaking II accepts a low wear roll" {
    try std.testing.expect(shouldConsumeWear(2, 0.1));
}

test "Unbreaking II rejects a high wear roll" {
    try std.testing.expect(!shouldConsumeWear(2, 0.34));
}

test "wear rejects negative random rolls" {
    try std.testing.expect(!shouldConsumeWear(0, -0.01));
}

test "wear rejects random rolls equal to one" {
    try std.testing.expect(!shouldConsumeWear(0, 1.0));
}

test "flight starts with usable Elytra" {
    var state = DurabilityState{};
    try std.testing.expect(state.startFlight());
    try std.testing.expect(state.is_flying);
}

test "one wear roll consumes one durability" {
    var state = DurabilityState{};
    try std.testing.expect(state.startFlight());
    try std.testing.expect(state.tickFlightWear(0, 0.5));
    try std.testing.expectEqual(@as(u16, 431), state.durability);
}

test "Unbreaking can skip the wear event" {
    var state = DurabilityState{};
    try std.testing.expect(state.startFlight());
    try std.testing.expect(!state.tickFlightWear(3, 0.5));
    try std.testing.expectEqual(max_durability, state.durability);
}

test "durability one is broken" {
    const state = DurabilityState{ .durability = 1 };
    try std.testing.expect(state.isBroken());
}

test "durability one prevents starting flight" {
    var state = DurabilityState{ .durability = 1 };
    try std.testing.expect(!state.startFlight());
}

test "wear reaching one stops flight" {
    var state = DurabilityState{ .durability = 2 };
    try std.testing.expect(state.startFlight());
    try std.testing.expect(state.tickFlightWear(0, 0.0));
    try std.testing.expectEqual(@as(u16, 1), state.durability);
    try std.testing.expect(!state.is_flying);
}

test "unequipped Elytra cannot fly" {
    var state = DurabilityState{ .equipped = false };
    try std.testing.expect(!state.startFlight());
}

test "five XP points repair ten durability with Mending" {
    var state = DurabilityState{ .durability = 100, .has_mending = true };
    try std.testing.expectEqual(@as(u16, 10), state.absorbExperience(5));
    try std.testing.expectEqual(@as(u16, 110), state.durability);
}

test "Mending repair requires equipped Elytra" {
    var state = DurabilityState{ .durability = 100, .equipped = false, .has_mending = true };
    try std.testing.expectEqual(@as(u16, 0), state.absorbExperience(5));
    try std.testing.expectEqual(@as(u16, 100), state.durability);
}

test "Mending repair requires the enchantment" {
    var state = DurabilityState{ .durability = 100, .equipped = true, .has_mending = false };
    try std.testing.expectEqual(@as(u16, 0), state.absorbExperience(5));
}

test "Mending repair caps at maximum durability" {
    var state = DurabilityState{ .durability = 430, .has_mending = true };
    try std.testing.expectEqual(@as(u16, 2), state.absorbExperience(5));
    try std.testing.expectEqual(max_durability, state.durability);
}

test "zero XP does not repair durability" {
    var state = DurabilityState{ .durability = 100, .has_mending = true };
    try std.testing.expectEqual(@as(u16, 0), state.absorbExperience(0));
}

test "stall angle threshold itself does not trigger stall" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    const frame = stepAerodynamics(&state, 35.0, 0.01);
    try std.testing.expect(!frame.is_stalled);
}

test "pitch above 35 degrees at low speed stalls" {
    var state = AerodynamicState{ .airspeed_mps = 5.9 };
    const frame = stepAerodynamics(&state, 35.1, 0.01);
    try std.testing.expect(frame.is_stalled);
}

test "pitch above stall angle at six m/s does not stall" {
    var state = AerodynamicState{ .airspeed_mps = 6.0 };
    const frame = stepAerodynamics(&state, 40.0, 0.01);
    try std.testing.expect(!frame.is_stalled);
}

test "pitch below stall angle does not stall at low speed" {
    var state = AerodynamicState{ .airspeed_mps = 2.0 };
    const frame = stepAerodynamics(&state, 35.0, 0.01);
    try std.testing.expect(!frame.is_stalled);
}

test "stall reduces lift coefficient by 90 percent" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    const frame = stepAerodynamics(&state, 40.0, 0.01);
    try expectNear(frame.lift_coefficient, 0.1);
}

test "stall enters nose-down vertical tumble" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    const frame = stepAerodynamics(&state, 45.0, 0.01);
    try std.testing.expect(frame.nose_down_tumble);
    try expectNear(frame.effective_pitch_degrees, -90.0);
}

test "stall stays active below eight m/s recovery speed" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    _ = stepAerodynamics(&state, 40.0, 0.01);
    state.setAirspeed(7.99);
    const frame = stepAerodynamics(&state, 0.0, 0.0);
    try std.testing.expect(frame.is_stalled);
}

test "stall recovers at eight m/s" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    _ = stepAerodynamics(&state, 40.0, 0.01);
    state.setAirspeed(8.0);
    const frame = stepAerodynamics(&state, 0.0, 0.01);
    try std.testing.expect(!frame.is_stalled);
    try std.testing.expect(!frame.nose_down_tumble);
}

test "nose-down tumble can recover during a dive step" {
    var state = AerodynamicState{ .airspeed_mps = 5.0 };
    _ = stepAerodynamics(&state, 40.0, 0.01);
    const frame = stepAerodynamics(&state, 0.0, 1.0);
    try std.testing.expect(!frame.is_stalled);
    try std.testing.expect(frame.airspeed_mps >= stall_recovery_speed_mps);
}

test "a dive accelerates by gravity over one second" {
    var state = AerodynamicState{ .airspeed_mps = 0.0 };
    const frame = stepAerodynamics(&state, -90.0, 1.0);
    try expectNear(frame.airspeed_mps, 9.81);
}

test "dive speed clamps at 67.5 meters per second" {
    var state = AerodynamicState{ .airspeed_mps = 67.0 };
    const frame = stepAerodynamics(&state, -90.0, 1.0);
    try expectNear(frame.airspeed_mps, 67.5);
}

test "dive at terminal velocity remains capped" {
    var state = AerodynamicState{ .airspeed_mps = terminal_dive_speed_mps };
    const frame = stepAerodynamics(&state, -90.0, 5.0);
    try expectNear(frame.airspeed_mps, terminal_dive_speed_mps);
}

test "zero duration does not change flight speed" {
    var state = AerodynamicState{ .airspeed_mps = 12.0 };
    _ = stepAerodynamics(&state, -90.0, 0.0);
    try expectNear(state.airspeed_mps, 12.0);
}

test "negative airspeed is clamped to zero" {
    var state = AerodynamicState{};
    state.setAirspeed(-4.0);
    try expectNear(state.airspeed_mps, 0.0);
}
