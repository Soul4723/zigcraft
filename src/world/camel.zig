const std = @import("std");

/// Block and Item IDs related to camels.
pub const CactusBlockId: u16 = 39;
pub const CactusItemId: u16 = 45;

/// Health and healing constants.
pub const camel_max_health: f32 = 32.0; // 16 hearts
pub const cactus_heal_amount: f32 = 2.0; // 1 heart

/// Dash mechanics constants.
pub const max_dash_speed: f32 = 18.0; // horizontal speed burst at 1.0 charge (covers 12+ blocks)
pub const dash_hop_vy: f32 = 3.6; // vertical hop impulse on ground release
pub const dash_cooldown_duration: f32 = 2.75; // 2.75 seconds
pub const dash_cooldown_ticks: u32 = 55; // 55 ticks at 20 ticks/sec
pub const dash_charge_rate: f32 = 1.0; // full charge (0.0 -> 1.0) in 1.0s

/// Posture transition times.
pub const sit_transition_duration: f32 = 2.0; // 40 ticks
pub const sit_transition_ticks: u32 = 40;
pub const stand_transition_duration: f32 = 2.0; // 40 ticks
pub const stand_transition_ticks: u32 = 40;

/// Movement & navigation stride capabilities.
pub const camel_step_height: f32 = 1.5; // step up over fences & 1.5-block walls without jumping
pub const standard_step_height: f32 = 0.6;
pub const horse_step_height: f32 = 1.0;
pub const max_gap_stride: u8 = 2; // stride directly over 1-block and 2-block ravines/gaps

/// Rider positioning offsets.
pub const standing_rider_y_offset: f32 = 2.3; // rider feet Y relative to camel feet
pub const sitting_rider_y_offset: f32 = 1.2;
pub const driver_seat_z_offset: f32 = 0.5; // front seat forward along facing axis
pub const passenger_seat_z_offset: f32 = -0.5; // rear seat backward along facing axis

/// Melee reach thresholds for mobs attacking camel riders.
pub const max_melee_reach_up: f32 = 0.4; // max distance above attacker eye level mob can strike
pub const max_melee_reach_down: f32 = 2.5; // max distance below attacker eye level mob can strike

/// Breeding and growth constants.
pub const breeding_cooldown_duration: f32 = 300.0; // 5 minutes (6000 ticks)
pub const breeding_cooldown_ticks: u32 = 6000;
pub const baby_growth_duration: f32 = 1200.0; // 20 minutes (24000 ticks)
pub const baby_growth_ticks: u32 = 24000;
pub const baby_growth_step_reduction: f32 = 120.0; // 10% reduction per cactus fed (2400 ticks)

/// Posture state of the camel.
pub const Posture = enum(u8) {
    standing = 0,
    sitting_down = 1,
    sitting = 2,
    standing_up = 3,
};
pub const CamelPosture = Posture;

/// Rider seat designation.
pub const Seat = enum(u8) {
    driver = 0,
    passenger = 1,
};

/// 3D offset relative to camel origin.
pub const SeatOffset = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const driver_seat_standing: SeatOffset = .{ .x = 0.0, .y = standing_rider_y_offset, .z = driver_seat_z_offset };
pub const passenger_seat_standing: SeatOffset = .{ .x = 0.0, .y = standing_rider_y_offset, .z = passenger_seat_z_offset };
pub const driver_seat_sitting: SeatOffset = .{ .x = 0.0, .y = sitting_rider_y_offset, .z = driver_seat_z_offset };
pub const passenger_seat_sitting: SeatOffset = .{ .x = 0.0, .y = sitting_rider_y_offset, .z = passenger_seat_z_offset };

/// Structure returned by dash impulse calculation.
pub const DashImpulse = struct {
    vx: f32,
    vy: f32,
    vz: f32,
};

/// Computes the 3D dash impulse vector for a given charge level and yaw angle.
/// Horizontal burst reaches up to 18.0 m/s (propelling 12+ blocks), with a small vertical hop.
/// Charge is clamped to [0.0, 1.0]. Returns 0 impulse if charge <= 0.0.
pub fn computeDashImpulse(charge: f32, yaw: f32) DashImpulse {
    const c = std.math.clamp(charge, 0.0, 1.0);
    if (c <= 0.0) {
        return .{ .vx = 0.0, .vy = 0.0, .vz = 0.0 };
    }
    const speed = max_dash_speed * c;
    return .{
        .vx = @sin(yaw) * speed,
        .vy = dash_hop_vy * c,
        .vz = @cos(yaw) * speed,
    };
}

/// Checks whether an attacker can reach a rider on the camel with a melee attack.
/// Enforces the tall camel height advantage: standard 2-block-tall melee mobs (husks/zombies,
/// eye Y ~1.74 on level ground) cannot reach riders on a standing camel (rider_y = camel_base_y + 2.3),
/// but can reach riders when the camel is sitting (rider_y = camel_base_y + 1.2).
pub fn canMeleeReachRider(attacker_eye_y: f32, camel_base_y: f32, is_sitting: bool) bool {
    const rider_y = if (is_sitting) camel_base_y + sitting_rider_y_offset else camel_base_y + standing_rider_y_offset;
    const dy = rider_y - attacker_eye_y;
    return dy <= max_melee_reach_up and dy >= -max_melee_reach_down;
}

/// Returns the maximum step-up height. Camels can step up 1.5 blocks (clearing fences and walls),
/// whereas standard mobs/players step up 0.6 blocks.
pub fn maxStepUpHeight(is_camel: bool) f32 {
    if (is_camel) return camel_step_height;
    return standard_step_height;
}

/// Checks if a gap of the given block width can be strided over without falling.
/// Camels have a 2-block ravine/gap stride (supports width 0, 1, and 2).
pub fn canCrossGap(gap_width: u8) bool {
    return gap_width <= max_gap_stride;
}

/// Returns seat offset relative to camel base for the given seat and sitting status.
pub fn getSeatOffset(seat: Seat, is_sitting: bool) SeatOffset {
    if (is_sitting) {
        return switch (seat) {
            .driver => driver_seat_sitting,
            .passenger => passenger_seat_sitting,
        };
    } else {
        return switch (seat) {
            .driver => driver_seat_standing,
            .passenger => passenger_seat_standing,
        };
    }
}

/// Computes the absolute world coordinates of a rider seat given the camel's base position and yaw.
pub fn computeWorldSeatPosition(cx: f32, cy: f32, cz: f32, yaw: f32, seat: Seat, is_sitting: bool) struct { x: f32, y: f32, z: f32 } {
    const offset = getSeatOffset(seat, is_sitting);
    const sin_y = @sin(yaw);
    const cos_y = @cos(yaw);
    const forward_x = sin_y;
    const forward_z = cos_y;
    const right_x = cos_y;
    const right_z = -sin_y;

    return .{
        .x = cx + forward_x * offset.z + right_x * offset.x,
        .y = cy + offset.y,
        .z = cz + forward_z * offset.z + right_z * offset.x,
    };
}

/// Heals a camel with cactus by +2.0 HP, up to max_hp.
pub fn applyCactusHeal(current_hp: f32, max_hp: f32) f32 {
    return @min(max_hp, current_hp + cactus_heal_amount);
}

/// Accelerates baby camel growth by 10% (120 seconds).
pub fn accelerateBabyGrowth(remaining_time: f32) f32 {
    return @max(0.0, remaining_time - baby_growth_step_reduction);
}

/// Complete camel state machine managing posture, dash meter, cooldown, riders, and feeding.
pub const CamelState = struct {
    posture: Posture = .standing,
    transition_timer: f32 = 0.0,
    dash_charge: f32 = 0.0,
    dash_cooldown: f32 = 0.0,
    health: f32 = camel_max_health,
    is_baby: bool = false,
    growth_timer: f32 = 0.0,
    breeding_cooldown: f32 = 0.0,
    in_love: bool = false,
    has_driver: bool = false,
    has_passenger: bool = false,

    const timer_epsilon: f32 = 0.0001;

    pub fn init() CamelState {
        return .{};
    }

    pub fn initBaby() CamelState {
        return .{
            .is_baby = true,
            .growth_timer = baby_growth_duration,
            .health = camel_max_health * 0.5,
        };
    }

    pub fn isStanding(self: CamelState) bool {
        return self.posture == .standing;
    }

    pub fn isSitting(self: CamelState) bool {
        return self.posture == .sitting;
    }

    pub fn isTransitioning(self: CamelState) bool {
        return self.posture == .sitting_down or self.posture == .standing_up;
    }

    pub fn canMove(self: CamelState) bool {
        return self.posture == .standing;
    }

    pub fn canDash(self: CamelState) bool {
        return self.posture == .standing and self.dash_cooldown <= timer_epsilon;
    }

    /// Initiates sitting down transition if standing.
    pub fn startSitting(self: *CamelState) bool {
        if (self.posture != .standing) return false;
        self.posture = .sitting_down;
        self.transition_timer = sit_transition_duration;
        self.dash_charge = 0.0;
        return true;
    }

    /// Initiates standing up transition if sitting.
    pub fn startStanding(self: *CamelState) bool {
        if (self.posture != .sitting) return false;
        self.posture = .standing_up;
        self.transition_timer = stand_transition_duration;
        return true;
    }

    /// Toggles between standing and sitting. Returns false if currently transitioning.
    pub fn togglePosture(self: *CamelState) bool {
        return switch (self.posture) {
            .standing => self.startSitting(),
            .sitting => self.startStanding(),
            .sitting_down, .standing_up => false,
        };
    }

    /// Accumulates dash charge over time (0.0 to 1.0).
    pub fn chargeDash(self: *CamelState, dt: f32) void {
        if (self.posture != .standing or self.dash_cooldown > timer_epsilon) return;
        self.dash_charge = @min(1.0, self.dash_charge + dt * dash_charge_rate);
    }

    /// Sets dash charge explicitly clamped to [0.0, 1.0].
    pub fn setDashCharge(self: *CamelState, charge: f32) void {
        if (self.posture != .standing or self.dash_cooldown > timer_epsilon) {
            self.dash_charge = 0.0;
            return;
        }
        self.dash_charge = std.math.clamp(charge, 0.0, 1.0);
    }

    /// Releases a dash burst if the camel is standing, on ground, not on cooldown, and has charge.
    /// Returns the impulse vector and puts dash on cooldown (2.75s / 55 ticks).
    pub fn releaseDash(self: *CamelState, yaw: f32, on_ground: bool) ?DashImpulse {
        if (!on_ground or self.posture != .standing or self.dash_cooldown > timer_epsilon or self.dash_charge <= 0.0) {
            self.dash_charge = 0.0;
            return null;
        }
        const impulse = computeDashImpulse(self.dash_charge, yaw);
        self.dash_charge = 0.0;
        self.dash_cooldown = dash_cooldown_duration;
        return impulse;
    }

    /// Mounts a rider into the next available seat (driver preferred, then passenger).
    pub fn mountRider(self: *CamelState) ?Seat {
        if (!self.has_driver) {
            self.has_driver = true;
            return .driver;
        }
        if (!self.has_passenger) {
            self.has_passenger = true;
            return .passenger;
        }
        return null;
    }

    /// Dismounts a rider from the specified seat.
    pub fn dismountRider(self: *CamelState, seat: Seat) void {
        switch (seat) {
            .driver => self.has_driver = false,
            .passenger => self.has_passenger = false,
        }
    }

    /// Returns the count of mounted riders (0, 1, or 2).
    pub fn riderCount(self: CamelState) u8 {
        var count: u8 = 0;
        if (self.has_driver) count += 1;
        if (self.has_passenger) count += 1;
        return count;
    }

    /// Returns relative seat offset based on current posture.
    pub fn getSeat(self: CamelState, seat: Seat) SeatOffset {
        return getSeatOffset(seat, self.posture == .sitting or self.posture == .sitting_down);
    }

    /// Feeds a cactus item to the camel:
    /// - If health < max, heals +2.0 HP.
    /// - If baby, accelerates growth by 120s (10%).
    /// - If healthy adult and not on breeding cooldown, enters love mode.
    /// Returns true if the cactus was consumed.
    pub fn feedCactus(self: *CamelState) bool {
        if (self.health < camel_max_health) {
            self.health = applyCactusHeal(self.health, camel_max_health);
            return true;
        }
        if (self.is_baby) {
            self.growth_timer = accelerateBabyGrowth(self.growth_timer);
            if (self.growth_timer <= timer_epsilon) {
                self.is_baby = false;
                self.growth_timer = 0.0;
            }
            return true;
        }
        if (self.breeding_cooldown <= timer_epsilon and !self.in_love) {
            self.in_love = true;
            return true;
        }
        return false;
    }

    /// Advances timers by delta time dt (in seconds).
    pub fn update(self: *CamelState, dt: f32) void {
        switch (self.posture) {
            .sitting_down => {
                self.transition_timer -= dt;
                if (self.transition_timer <= timer_epsilon) {
                    self.posture = .sitting;
                    self.transition_timer = 0.0;
                }
            },
            .standing_up => {
                self.transition_timer -= dt;
                if (self.transition_timer <= timer_epsilon) {
                    self.posture = .standing;
                    self.transition_timer = 0.0;
                }
            },
            .standing, .sitting => {},
        }

        if (self.dash_cooldown > 0.0) {
            self.dash_cooldown -= dt;
            if (self.dash_cooldown <= timer_epsilon) {
                self.dash_cooldown = 0.0;
            }
        }

        if (self.breeding_cooldown > 0.0) {
            self.breeding_cooldown -= dt;
            if (self.breeding_cooldown <= timer_epsilon) {
                self.breeding_cooldown = 0.0;
            }
        }

        if (self.is_baby and self.growth_timer > 0.0) {
            self.growth_timer -= dt;
            if (self.growth_timer <= timer_epsilon) {
                self.is_baby = false;
                self.growth_timer = 0.0;
            }
        }
    }

    /// Advances state by one game tick (1/20 second = 0.05s).
    pub fn tick(self: *CamelState) void {
        self.update(0.05);
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "dash charge scales impulse proportionally from 0 to 1" {
    const yaw = 0.0;
    const impulse_half = computeDashImpulse(0.5, yaw);
    const impulse_full = computeDashImpulse(1.0, yaw);

    try std.testing.expectApproxEqAbs(impulse_half.vz, 9.0, 0.001);
    try std.testing.expectApproxEqAbs(impulse_half.vy, 1.8, 0.001);
    try std.testing.expectApproxEqAbs(impulse_half.vx, 0.0, 0.001);

    try std.testing.expectApproxEqAbs(impulse_full.vz, 18.0, 0.001);
    try std.testing.expectApproxEqAbs(impulse_full.vy, 3.6, 0.001);
    try std.testing.expectApproxEqAbs(impulse_full.vx, 0.0, 0.001);
}

test "dash impulse zero on zero charge and clamped at max charge" {
    const zero = computeDashImpulse(0.0, 0.0);
    try std.testing.expectEqual(@as(f32, 0.0), zero.vx);
    try std.testing.expectEqual(@as(f32, 0.0), zero.vy);
    try std.testing.expectEqual(@as(f32, 0.0), zero.vz);

    const negative = computeDashImpulse(-0.5, 0.0);
    try std.testing.expectEqual(@as(f32, 0.0), negative.vx);
    try std.testing.expectEqual(@as(f32, 0.0), negative.vy);
    try std.testing.expectEqual(@as(f32, 0.0), negative.vz);

    const overcharged = computeDashImpulse(1.5, 0.0);
    const normal_full = computeDashImpulse(1.0, 0.0);
    try std.testing.expectApproxEqAbs(overcharged.vz, normal_full.vz, 0.001);
    try std.testing.expectApproxEqAbs(overcharged.vy, normal_full.vy, 0.001);
}

test "dash impulse direction matches yaw angles" {
    // Facing +X (yaw = pi/2)
    const east = computeDashImpulse(1.0, std.math.pi * 0.5);
    try std.testing.expectApproxEqAbs(east.vx, 18.0, 0.001);
    try std.testing.expectApproxEqAbs(east.vz, 0.0, 0.001);

    // Facing -X (yaw = -pi/2)
    const west = computeDashImpulse(1.0, -std.math.pi * 0.5);
    try std.testing.expectApproxEqAbs(west.vx, -18.0, 0.001);
    try std.testing.expectApproxEqAbs(west.vz, 0.0, 0.001);

    // Facing -Z (yaw = pi)
    const south = computeDashImpulse(1.0, std.math.pi);
    try std.testing.expectApproxEqAbs(south.vx, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(south.vz, -18.0, 0.001);
}

test "dash cooldown lockout prevents dashing until expired" {
    var camel = CamelState.init();
    camel.setDashCharge(1.0);

    // First dash succeeds
    const imp1 = camel.releaseDash(0.0, true);
    try std.testing.expect(imp1 != null);
    try std.testing.expectApproxEqAbs(camel.dash_cooldown, 2.75, 0.001);
    try std.testing.expect(!camel.canDash());

    // Charging during cooldown is ignored
    camel.chargeDash(1.0);
    try std.testing.expectEqual(@as(f32, 0.0), camel.dash_charge);

    // Release during cooldown fails
    const imp2 = camel.releaseDash(0.0, true);
    try std.testing.expect(imp2 == null);

    // Tick forward 54 ticks (2.70s): still locked out
    var tick_i: usize = 0;
    while (tick_i < 54) : (tick_i += 1) {
        camel.tick();
    }
    try std.testing.expect(!camel.canDash());

    // 55th tick: cooldown elapses completely
    camel.tick();
    try std.testing.expect(camel.canDash());
    try std.testing.expectEqual(@as(f32, 0.0), camel.dash_cooldown);
}

test "dash release requires on_ground and standing posture" {
    var camel = CamelState.init();
    camel.setDashCharge(1.0);

    // In mid-air: fails and resets charge
    const air_release = camel.releaseDash(0.0, false);
    try std.testing.expect(air_release == null);
    try std.testing.expectEqual(@as(f32, 0.0), camel.dash_charge);

    // While sitting: cannot dash
    _ = camel.startSitting();
    camel.update(sit_transition_duration);
    try std.testing.expect(camel.isSitting());

    camel.setDashCharge(1.0);
    try std.testing.expectEqual(@as(f32, 0.0), camel.dash_charge);
    const sit_release = camel.releaseDash(0.0, true);
    try std.testing.expect(sit_release == null);
}

test "posture transitions standing to sitting_down to sitting" {
    var camel = CamelState.init();
    try std.testing.expect(camel.isStanding());

    try std.testing.expect(camel.startSitting());
    try std.testing.expectEqual(Posture.sitting_down, camel.posture);
    try std.testing.expect(camel.isTransitioning());
    try std.testing.expect(!camel.canMove());

    // Advance 1.0s (halfway)
    camel.update(1.0);
    try std.testing.expectEqual(Posture.sitting_down, camel.posture);

    // Advance remaining 1.0s -> sitting
    camel.update(1.0);
    try std.testing.expect(camel.isSitting());
    try std.testing.expect(!camel.isTransitioning());
}

test "posture transitions sitting to standing_up to standing" {
    var camel = CamelState.init();
    _ = camel.startSitting();
    camel.update(sit_transition_duration);
    try std.testing.expect(camel.isSitting());

    try std.testing.expect(camel.startStanding());
    try std.testing.expectEqual(Posture.standing_up, camel.posture);
    try std.testing.expect(camel.isTransitioning());

    // Advance 40 ticks -> standing
    var t: usize = 0;
    while (t < stand_transition_ticks) : (t += 1) {
        camel.tick();
    }
    try std.testing.expect(camel.isStanding());
    try std.testing.expect(camel.canMove());
}

test "posture toggle rejects mid-transition interruptions" {
    var camel = CamelState.init();
    try std.testing.expect(camel.togglePosture()); // starts sitting_down
    try std.testing.expectEqual(Posture.sitting_down, camel.posture);

    // Attempting to toggle while transitioning fails
    try std.testing.expect(!camel.togglePosture());
    try std.testing.expect(!camel.startStanding());
    try std.testing.expect(!camel.startSitting());

    // After sitting completes, toggle stands up
    camel.update(sit_transition_duration);
    try std.testing.expect(camel.isSitting());
    try std.testing.expect(camel.togglePosture());
    try std.testing.expectEqual(Posture.standing_up, camel.posture);
}

test "canMeleeReachRider blocks standard 2-block melee mobs when standing" {
    const camel_base_y: f32 = 64.0;
    // Standard husk/zombie eye level on ground (base 64.0 + eye 1.74 = 65.74)
    const zombie_eye_y: f32 = 65.74;

    // Standing camel rider Y = 64.0 + 2.3 = 66.3.
    // dy = 66.3 - 65.74 = 0.56 > max_melee_reach_up (0.4) -> Immune!
    try std.testing.expect(!canMeleeReachRider(zombie_eye_y, camel_base_y, false));

    // Even slightly taller mob eye (1.80) cannot reach standing rider (0.50 > 0.4)
    try std.testing.expect(!canMeleeReachRider(camel_base_y + 1.80, camel_base_y, false));
}

test "canMeleeReachRider allows standard 2-block melee mobs when sitting" {
    const camel_base_y: f32 = 64.0;
    const zombie_eye_y: f32 = 65.74;

    // Sitting camel rider Y = 64.0 + 1.2 = 65.2.
    // dy = 65.2 - 65.74 = -0.54, within downward reach [-2.5, 0.4] -> Can hit!
    try std.testing.expect(canMeleeReachRider(zombie_eye_y, camel_base_y, true));
}

test "canMeleeReachRider allows elevated melee mobs to hit standing rider" {
    const camel_base_y: f32 = 64.0;
    // Zombie standing on a 1-block ledge above camel: eye = 65.0 + 1.74 = 66.74
    const elevated_zombie_eye_y: f32 = 66.74;

    // dy = 66.3 - 66.74 = -0.44 -> within [-2.5, 0.4] reach window!
    try std.testing.expect(canMeleeReachRider(elevated_zombie_eye_y, camel_base_y, false));
}

test "canMeleeReachRider blocks deep pit melee mobs" {
    const camel_base_y: f32 = 64.0;
    // Zombie trapped 3 blocks below: eye Y = 61.0 + 1.74 = 62.74
    const pit_zombie_eye_y: f32 = 62.74;

    // Sitting rider Y = 65.2, dy = 65.2 - 62.74 = 2.46 > 0.4 -> Cannot reach!
    try std.testing.expect(!canMeleeReachRider(pit_zombie_eye_y, camel_base_y, true));
    try std.testing.expect(!canMeleeReachRider(pit_zombie_eye_y, camel_base_y, false));
}

test "maxStepUpHeight gives 1.5 blocks for camel and 0.6 for standard" {
    try std.testing.expectEqual(@as(f32, 1.5), maxStepUpHeight(true));
    try std.testing.expectEqual(@as(f32, 0.6), maxStepUpHeight(false));
}

test "canCrossGap allows 1 and 2 block gaps, blocks 3+ gaps" {
    try std.testing.expect(canCrossGap(0));
    try std.testing.expect(canCrossGap(1));
    try std.testing.expect(canCrossGap(2));
    try std.testing.expect(!canCrossGap(3));
    try std.testing.expect(!canCrossGap(4));
    try std.testing.expect(!canCrossGap(10));
}

test "cactus feeding heals injured camel by +2.0 hp clamped to max" {
    var camel = CamelState.init();
    camel.health = 25.0;

    try std.testing.expect(camel.feedCactus());
    try std.testing.expectApproxEqAbs(camel.health, 27.0, 0.001);

    camel.health = 31.5;
    try std.testing.expect(camel.feedCactus());
    try std.testing.expectApproxEqAbs(camel.health, camel_max_health, 0.001);

    // Standalone function check
    try std.testing.expectApproxEqAbs(applyCactusHeal(10.0, 32.0), 12.0, 0.001);
    try std.testing.expectApproxEqAbs(applyCactusHeal(31.0, 32.0), 32.0, 0.001);
}

test "cactus feeding accelerates baby camel growth by 10%" {
    var baby = CamelState.initBaby();
    baby.health = camel_max_health; // full health so cactus goes to growth
    try std.testing.expect(baby.is_baby);
    try std.testing.expectApproxEqAbs(baby.growth_timer, baby_growth_duration, 0.001);

    // Feed one cactus -> reduces by 120s
    try std.testing.expect(baby.feedCactus());
    try std.testing.expectApproxEqAbs(baby.growth_timer, baby_growth_duration - 120.0, 0.001);

    // Feed until mature
    baby.growth_timer = 50.0;
    try std.testing.expect(baby.feedCactus());
    try std.testing.expect(!baby.is_baby);
    try std.testing.expectEqual(@as(f32, 0.0), baby.growth_timer);
}

test "cactus feeding enters love mode on full health adult" {
    var camel = CamelState.init();
    try std.testing.expect(!camel.in_love);
    try std.testing.expectEqual(@as(f32, 0.0), camel.breeding_cooldown);

    try std.testing.expect(camel.feedCactus());
    try std.testing.expect(camel.in_love);

    // Second cactus while already in love is not consumed
    try std.testing.expect(!camel.feedCactus());

    // When breeding cooldown is active, cactus is not consumed
    camel.in_love = false;
    camel.breeding_cooldown = breeding_cooldown_duration;
    try std.testing.expect(!camel.feedCactus());
}

test "dual-rider seat offsets provide front driver and rear passenger seats" {
    const drv_stand = getSeatOffset(.driver, false);
    const pas_stand = getSeatOffset(.passenger, false);
    try std.testing.expectEqual(@as(f32, 0.0), drv_stand.x);
    try std.testing.expectEqual(@as(f32, standing_rider_y_offset), drv_stand.y);
    try std.testing.expectEqual(@as(f32, driver_seat_z_offset), drv_stand.z);

    try std.testing.expectEqual(@as(f32, 0.0), pas_stand.x);
    try std.testing.expectEqual(@as(f32, standing_rider_y_offset), pas_stand.y);
    try std.testing.expectEqual(@as(f32, passenger_seat_z_offset), pas_stand.z);

    // Driver is in front of passenger
    try std.testing.expect(drv_stand.z > pas_stand.z);
}

test "dual-rider seat offsets adjust Y between standing and sitting" {
    const drv_sit = getSeatOffset(.driver, true);
    const pas_sit = getSeatOffset(.passenger, true);

    try std.testing.expectEqual(@as(f32, sitting_rider_y_offset), drv_sit.y);
    try std.testing.expectEqual(@as(f32, sitting_rider_y_offset), pas_sit.y);
    try std.testing.expect(standing_rider_y_offset > sitting_rider_y_offset);
}

test "world seat positions rotate correctly with camel yaw" {
    // Camel at (10, 64, 20) facing +Z (yaw = 0)
    const pos_north = computeWorldSeatPosition(10.0, 64.0, 20.0, 0.0, .driver, false);
    try std.testing.expectApproxEqAbs(pos_north.x, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(pos_north.y, 66.3, 0.001);
    try std.testing.expectApproxEqAbs(pos_north.z, 20.5, 0.001);

    // Camel facing +X (yaw = pi/2)
    const pos_east = computeWorldSeatPosition(10.0, 64.0, 20.0, std.math.pi * 0.5, .driver, false);
    try std.testing.expectApproxEqAbs(pos_east.x, 10.5, 0.001);
    try std.testing.expectApproxEqAbs(pos_east.y, 66.3, 0.001);
    try std.testing.expectApproxEqAbs(pos_east.z, 20.0, 0.001);
}

test "mounting and dismounting dual riders manages seat occupancy" {
    var camel = CamelState.init();
    try std.testing.expectEqual(@as(u8, 0), camel.riderCount());

    // First rider gets driver seat
    const seat1 = camel.mountRider();
    try std.testing.expectEqual(Seat.driver, seat1.?);
    try std.testing.expectEqual(@as(u8, 1), camel.riderCount());

    // Second rider gets passenger seat
    const seat2 = camel.mountRider();
    try std.testing.expectEqual(Seat.passenger, seat2.?);
    try std.testing.expectEqual(@as(u8, 2), camel.riderCount());

    // Third rider cannot mount (full)
    const seat3 = camel.mountRider();
    try std.testing.expect(seat3 == null);

    // Dismount driver
    camel.dismountRider(.driver);
    try std.testing.expectEqual(@as(u8, 1), camel.riderCount());
    try std.testing.expect(!camel.has_driver);
    try std.testing.expect(camel.has_passenger);

    // Next mount takes vacated driver seat
    const seat4 = camel.mountRider();
    try std.testing.expectEqual(Seat.driver, seat4.?);
    try std.testing.expectEqual(@as(u8, 2), camel.riderCount());
}
