const std = @import("std");

pub const blaze_charge_duration: f32 = 3.0;
pub const blaze_volley_shots: u8 = 3;
pub const blaze_shot_interval: f32 = 0.3;
pub const blaze_idle_cooldown: f32 = 5.0;
pub const blaze_fireball_damage: f32 = 5.0;
pub const blaze_fireball_ignites_entities = true;
pub const blaze_fireball_ignites_blocks = true;
pub const blaze_snowball_damage: f32 = 3.0;
pub const blaze_splash_water_damage: f32 = 1.0;
pub const waterRainDamagePerSecond: f32 = 2.0;
pub const blaze_hover_height: f32 = 0.5;
pub const blaze_ascent_speed: f32 = 2.0;
pub const blaze_idle_descent_speed: f32 = -0.6;
pub const MAX_BREW_FUEL: u5 = 20;
pub const brew_batch_duration: f32 = 20.0;

pub const BlazeAttackPhase = enum {
    idle_cooldown,
    charging_on_fire,
    firing_volley,
};

/// Advances through cooldown, a visible-flame charge, and a three-shot volley.
/// The first shot fires as soon as the 3-second charge ends; later shots are
/// separated by 0.3 seconds. `tick` returns the number of shots fired this tick.
pub const BlazeAttackState = struct {
    phase: BlazeAttackPhase = .idle_cooldown,
    phase_timer: f32 = blaze_idle_cooldown,
    shots_fired: u8 = 0,

    pub fn tick(self: *BlazeAttackState, dt: f32) u8 {
        if (dt <= 0.0) return 0;
        var remaining = dt;
        var shots: u8 = 0;
        var transitions: u8 = 0;
        while (remaining > 0.0 and transitions < 8) {
            transitions += 1;
            if (self.phase_timer - remaining > 0.000001) {
                self.phase_timer -= remaining;
                break;
            }
            remaining = @max(0.0, remaining - self.phase_timer);
            switch (self.phase) {
                .idle_cooldown => {
                    self.phase = .charging_on_fire;
                    self.phase_timer = blaze_charge_duration;
                },
                .charging_on_fire => {
                    self.phase = .firing_volley;
                    self.shots_fired = 1;
                    shots += 1;
                    self.phase_timer = blaze_shot_interval;
                    if (self.shots_fired == blaze_volley_shots) {
                        self.phase = .idle_cooldown;
                        self.phase_timer = blaze_idle_cooldown;
                    }
                },
                .firing_volley => {
                    self.shots_fired += 1;
                    shots += 1;
                    if (self.shots_fired >= blaze_volley_shots) {
                        self.phase = .idle_cooldown;
                        self.phase_timer = blaze_idle_cooldown;
                    } else {
                        self.phase_timer = blaze_shot_interval;
                    }
                },
            }
        }
        return shots;
    }

    pub fn isVisuallyOnFire(self: BlazeAttackState) bool {
        return self.phase == .charging_on_fire or self.phase == .firing_volley;
    }
};

pub fn resolveSnowballOrWaterHitOnBlaze(is_snowball: bool, is_splash_water: bool) f32 {
    if (is_snowball) return blaze_snowball_damage;
    if (is_splash_water) return blaze_splash_water_damage;
    return 0.0;
}

/// Returns vertical velocity in m/s. While aggroed, only ascent is commanded
/// below the desired hover height; above it, the blaze gently glides downward.
pub fn computeBlazeHoverAscent(blaze_y: f32, target_y: f32, is_charging_or_firing: bool) f32 {
    if (is_charging_or_firing and blaze_y < target_y + blaze_hover_height)
        return blaze_ascent_speed;
    return blaze_idle_descent_speed;
}

pub const BrewingStandFuelState = struct {
    fuel_charges: u5 = 0,
    brew_timer: f32 = 0.0,

    /// A powder replenishes the stand to its 20-charge cap.
    pub fn addBlazePowder(self: *BrewingStandFuelState) void {
        self.fuel_charges = MAX_BREW_FUEL;
    }

    /// Starts one 3-bottle batch, consuming one fuel charge immediately.
    pub fn startBatch(self: *BrewingStandFuelState) bool {
        if (self.brew_timer > 0.0 or self.fuel_charges == 0) return false;
        self.fuel_charges -= 1;
        self.brew_timer = brew_batch_duration;
        return true;
    }

    /// Returns true exactly when an active batch completes.
    pub fn tick(self: *BrewingStandFuelState, dt: f32) bool {
        if (self.brew_timer <= 0.0 or dt <= 0.0) return false;
        if (dt >= self.brew_timer) {
            self.brew_timer = 0.0;
            return true;
        }
        self.brew_timer -= dt;
        return false;
    }
};

test "blaze starts in five second idle cooldown" {
    var state = BlazeAttackState{};
    try std.testing.expectEqual(BlazeAttackPhase.idle_cooldown, state.phase);
    try std.testing.expectEqual(@as(f32, 5.0), state.phase_timer);
    try std.testing.expectEqual(@as(u8, 0), state.tick(4.99));
}

test "cooldown transitions to visible fire charge at five seconds" {
    var state = BlazeAttackState{};
    try std.testing.expectEqual(@as(u8, 0), state.tick(5.0));
    try std.testing.expectEqual(BlazeAttackPhase.charging_on_fire, state.phase);
    try std.testing.expect(state.isVisuallyOnFire());
}

test "charge lasts three seconds without early shot" {
    var state = BlazeAttackState{ .phase = .charging_on_fire, .phase_timer = 3.0 };
    try std.testing.expectEqual(@as(u8, 0), state.tick(2.99));
    try std.testing.expectEqual(BlazeAttackPhase.charging_on_fire, state.phase);
}

test "charge completion immediately fires first volley shot" {
    var state = BlazeAttackState{ .phase = .charging_on_fire, .phase_timer = 3.0 };
    try std.testing.expectEqual(@as(u8, 1), state.tick(3.0));
    try std.testing.expectEqual(BlazeAttackPhase.firing_volley, state.phase);
    try std.testing.expectEqual(@as(u8, 1), state.shots_fired);
}

test "volley fires second shot after three tenths second" {
    var state = BlazeAttackState{ .phase = .firing_volley, .phase_timer = 0.3, .shots_fired = 1 };
    try std.testing.expectEqual(@as(u8, 0), state.tick(0.29));
    try std.testing.expectEqual(@as(u8, 1), state.tick(0.01));
    try std.testing.expectEqual(@as(u8, 2), state.shots_fired);
}

test "volley fires exactly three sequential shots" {
    var state = BlazeAttackState{ .phase = .firing_volley, .phase_timer = 0.3, .shots_fired = 1 };
    try std.testing.expectEqual(@as(u8, 2), state.tick(0.6));
    try std.testing.expectEqual(BlazeAttackPhase.idle_cooldown, state.phase);
}

test "completed volley begins full five second cooldown" {
    var state = BlazeAttackState{ .phase = .firing_volley, .phase_timer = 0.3, .shots_fired = 2 };
    try std.testing.expectEqual(@as(u8, 1), state.tick(0.3));
    try std.testing.expectEqual(@as(f32, 5.0), state.phase_timer);
    try std.testing.expectEqual(@as(u8, 0), state.tick(5.0));
    try std.testing.expectEqual(BlazeAttackPhase.charging_on_fire, state.phase);
}

test "large dt catches up through charge and all three volley shots" {
    var state = BlazeAttackState{ .phase = .charging_on_fire, .phase_timer = 3.0 };
    try std.testing.expectEqual(@as(u8, 3), state.tick(3.6));
    try std.testing.expectEqual(BlazeAttackPhase.idle_cooldown, state.phase);
}

test "blaze fireballs deal five damage and ignite entities and blocks" {
    try std.testing.expectEqual(@as(f32, 5.0), blaze_fireball_damage);
    try std.testing.expect(blaze_fireball_ignites_entities);
    try std.testing.expect(blaze_fireball_ignites_blocks);
}

test "snowball deals three damage and takes precedence over water flag" {
    try std.testing.expectEqual(@as(f32, 3.0), resolveSnowballOrWaterHitOnBlaze(true, false));
    try std.testing.expectEqual(@as(f32, 3.0), resolveSnowballOrWaterHitOnBlaze(true, true));
}

test "splash water deals one damage and no hit deals none" {
    try std.testing.expectEqual(@as(f32, 1.0), resolveSnowballOrWaterHitOnBlaze(false, true));
    try std.testing.expectEqual(@as(f32, 0.0), resolveSnowballOrWaterHitOnBlaze(false, false));
}

test "water rain damage rate is two hp per second" {
    try std.testing.expectEqual(@as(f32, 2.0), waterRainDamagePerSecond);
}

test "aggro blaze ascends toward hover height above target" {
    try std.testing.expectEqual(@as(f32, 2.0), computeBlazeHoverAscent(10.0, 10.0, true));
}

test "aggro blaze does not ascend at or above target hover height" {
    try std.testing.expectEqual(@as(f32, -0.6), computeBlazeHoverAscent(10.5, 10.0, true));
    try std.testing.expectEqual(@as(f32, -0.6), computeBlazeHoverAscent(12.0, 10.0, true));
}

test "idle blaze slow glides downward" {
    try std.testing.expectEqual(@as(f32, -0.6), computeBlazeHoverAscent(9.0, 10.0, false));
}

test "one blaze powder fuels twenty brewing batches" {
    var fuel = BrewingStandFuelState{};
    fuel.addBlazePowder();
    try std.testing.expectEqual(@as(u5, 20), fuel.fuel_charges);
    var batch: usize = 0;
    while (batch < 20) : (batch += 1) {
        try std.testing.expect(fuel.startBatch());
        try std.testing.expectEqual(@as(u5, @intCast(19 - batch)), fuel.fuel_charges);
        try std.testing.expectEqual(@as(f32, 20.0), fuel.brew_timer);
        try std.testing.expect(fuel.tick(20.0));
    }
    try std.testing.expectEqual(@as(u5, 0), fuel.fuel_charges);
    try std.testing.expect(!fuel.startBatch());
}

test "blaze powder cannot exceed twenty charges" {
    var fuel = BrewingStandFuelState{ .fuel_charges = 15 };
    fuel.addBlazePowder();
    try std.testing.expectEqual(MAX_BREW_FUEL, fuel.fuel_charges);
}

test "brewing batch consumes one charge and completes after twenty seconds" {
    var fuel = BrewingStandFuelState{ .fuel_charges = 2 };
    try std.testing.expect(fuel.startBatch());
    try std.testing.expectEqual(@as(u5, 1), fuel.fuel_charges);
    try std.testing.expect(!fuel.tick(19.0));
    try std.testing.expectEqual(@as(f32, 1.0), fuel.brew_timer);
    try std.testing.expect(fuel.tick(1.0));
}

test "brewing stand refuses overlapping batches" {
    var fuel = BrewingStandFuelState{ .fuel_charges = 2 };
    try std.testing.expect(fuel.startBatch());
    try std.testing.expect(!fuel.startBatch());
    try std.testing.expectEqual(@as(u5, 1), fuel.fuel_charges);
}
