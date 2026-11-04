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
pub const DASH_COOLDOWN_TICKS: u16 = 55;
pub const dash_charge_rate: f32 = 1.0; // full charge (0.0 -> 1.0) in 1.0s

/// Posture transition times.
pub const sit_transition_duration: f32 = 2.0; // 40 ticks
pub const sit_transition_ticks: u32 = 40;
pub const stand_transition_duration: f32 = 2.0; // 40 ticks
pub const stand_transition_ticks: u32 = 40;
pub const idle_sit_delay: f32 = 3.0; // idle dismounted time before auto-sitting

/// Movement & navigation stride capabilities.
pub const camel_step_height: f32 = 1.5; // step up over fences & 1.5-block walls without jumping
pub const STEP_HEIGHT: f32 = 1.5;
pub const standard_step_height: f32 = 0.6;
pub const horse_step_height: f32 = 1.0;
pub const fence_height: f32 = 1.5;
pub const wall_height: f32 = 1.5;
pub const max_gap_stride: u8 = 2; // stride directly over 1-block and 2-block ravines/gaps
pub const MAX_STRIDE_GAP: f32 = 2.0;
pub const max_ravine_stride_blocks: f32 = 2.0;
pub const max_gap_stride_blocks: u8 = 2;

/// Dash surge and stamina constants.
pub const DASH_SPEED: f32 = 19.5;
pub const dash_initial_burst_velocity: f32 = 19.5;
pub const DASH_DISTANCE: f32 = 12.0;
pub const dash_max_distance: f32 = 12.0;
pub const CHARGE_TICKS: u16 = 50;
pub const dash_max_charge_time: f32 = 2.5;
pub const dash_deceleration: f32 = (dash_initial_burst_velocity * dash_initial_burst_velocity) / (2.0 * dash_max_distance);
pub const GRAVITY: f32 = 9.81;
pub const TICK_SECONDS: f32 = 0.05;

/// Rider positioning offsets.
pub const standing_rider_y_offset: f32 = 2.3; // rider feet Y relative to camel feet
pub const sitting_rider_y_offset: f32 = 1.2;
pub const driver_seat_z_offset: f32 = 0.5; // front seat forward along facing axis
pub const passenger_seat_z_offset: f32 = -0.5; // rear seat backward along facing axis

/// Kinematic seating positions relative to camel base (standing)
pub const driver_seat_position: Vec3 = .{ .x = 0.0, .y = 1.85, .z = -0.35 };
pub const passenger_seat_position: Vec3 = .{ .x = 0.0, .y = 1.85, .z = 0.55 };
pub const sitting_rider_y_drop: f32 = 0.90;
pub const sitting_rider_y: f32 = 1.85 - sitting_rider_y_drop; // 0.95
pub const driver_seat_sitting_vec: Vec3 = .{ .x = 0.0, .y = sitting_rider_y, .z = -0.35 };
pub const passenger_seat_sitting_vec: Vec3 = .{ .x = 0.0, .y = sitting_rider_y, .z = 0.55 };

/// Melee reach thresholds for mobs attacking camel riders.
pub const max_melee_reach_up: f32 = 0.4; // max distance above attacker eye level mob can strike
pub const max_melee_reach_down: f32 = 2.5; // max distance below attacker eye level mob can strike

/// Breeding and growth constants.
pub const breeding_cooldown_duration: f32 = 300.0; // 5 minutes (6000 ticks)
pub const breeding_cooldown_ticks: u32 = 6000;
pub const baby_growth_duration: f32 = 1200.0; // 20 minutes (24000 ticks)
pub const baby_growth_ticks: u32 = 24000;
pub const baby_growth_step_reduction: f32 = 120.0; // 10% reduction per cactus fed (2400 ticks)

// ============================================================================
// 3D Vector Math
// ============================================================================

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const zero: Vec3 = .{ .x = 0.0, .y = 0.0, .z = 0.0 };

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn lengthSq(v: Vec3) f32 {
        return v.x * v.x + v.y * v.y + v.z * v.z;
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(v.lengthSq());
    }

    pub fn horizontalLength(v: Vec3) f32 {
        return @sqrt(v.x * v.x + v.z * v.z);
    }
};

/// Posture state of the camel.
pub const Posture = enum(u8) {
    standing = 0,
    sitting_down = 1,
    sitting = 2,
    standing_up = 3,
    transition_sitting = 4,
    transition_standing = 5,

    pub fn isStanding(self: Posture) bool {
        return self == .standing;
    }

    pub fn isSitting(self: Posture) bool {
        return self == .sitting;
    }

    pub fn isTransitioning(self: Posture) bool {
        return self == .sitting_down or self == .standing_up or self == .transition_sitting or self == .transition_standing;
    }

    pub fn canMove(self: Posture) bool {
        return self == .standing;
    }

    pub fn canDash(self: Posture) bool {
        return self == .standing;
    }
};
pub const CamelPosture = Posture;

/// Rider seat designation.
pub const SeatSlot = enum(u8) {
    driver = 0,
    passenger = 1,

    pub fn isDriver(self: SeatSlot) bool {
        return self == .driver;
    }

    pub fn isPassenger(self: SeatSlot) bool {
        return self == .passenger;
    }
};
pub const Seat = SeatSlot;

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
    speed: f32 = 0.0,
    charge_ratio: f32 = 0.0,
    max_distance: f32 = 0.0,
};

/// Computes the 3D dash impulse vector for a given charge level and yaw angle.
/// Horizontal burst reaches up to 18.0 m/s (propelling 12+ blocks), with a small vertical hop.
/// Charge is clamped to [0.0, 1.0]. Returns 0 impulse if charge <= 0.0.
pub fn computeDashImpulse(charge: f32, yaw: f32) DashImpulse {
    const c = std.math.clamp(charge, 0.0, 1.0);
    if (c <= 0.0) {
        return .{
            .vx = 0.0,
            .vy = 0.0,
            .vz = 0.0,
            .speed = 0.0,
            .charge_ratio = 0.0,
            .max_distance = 0.0,
        };
    }
    const h_speed = max_dash_speed * c;
    const burst_speed = DASH_SPEED * c;
    return .{
        .vx = @sin(yaw) * h_speed,
        .vy = dash_hop_vy * c,
        .vz = @cos(yaw) * h_speed,
        .speed = burst_speed,
        .charge_ratio = c,
        .max_distance = DASH_DISTANCE * c,
    };
}

/// Computes kinematic dash impulse with horizontal sprint speed 19.5 m/s.
pub fn computeKinematicDashImpulse(charge_ratio: f32, yaw: f32) DashImpulse {
    const ratio = std.math.clamp(charge_ratio, 0.0, 1.0);
    if (ratio <= 0.0) {
        return .{
            .vx = 0.0,
            .vy = 0.0,
            .vz = 0.0,
            .speed = 0.0,
            .charge_ratio = 0.0,
            .max_distance = 0.0,
        };
    }
    const speed = dash_initial_burst_velocity * ratio;
    const distance = dash_max_distance * ratio;
    const sin_y = @sin(yaw);
    const cos_y = @cos(yaw);

    return .{
        .vx = sin_y * speed,
        .vy = 0.0,
        .vz = -cos_y * speed,
        .speed = speed,
        .charge_ratio = ratio,
        .max_distance = distance,
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

pub fn canStepOver(block_height: f32) bool {
    return block_height <= STEP_HEIGHT;
}

pub fn is_obstructed(block_height: f32) bool {
    return block_height > STEP_HEIGHT;
}

pub fn canStepOverObstacle(obstacle_height: f32) bool {
    return obstacle_height <= camel_step_height and obstacle_height >= 0.0;
}

pub fn canClearFence() bool {
    return canStepOverObstacle(fence_height);
}

pub fn canClearWall() bool {
    return canStepOverObstacle(wall_height);
}

pub fn canStrideGap(width: f32) bool {
    return width <= MAX_STRIDE_GAP;
}

pub fn canCrossGap(gap: anytype) bool {
    const T = @TypeOf(gap);
    if (T == f32 or T == f64 or @typeInfo(T) == .float) {
        return gap <= max_ravine_stride_blocks and gap >= 0.0;
    } else {
        return gap <= max_gap_stride;
    }
}

pub fn canCrossGapBlocks(gap_blocks: u8) bool {
    return gap_blocks <= max_gap_stride_blocks;
}

pub const RavineStrideCheck = struct {
    can_stride: bool,
    gravity_dip_applied: bool,
    fell_into_ravine: bool,
    vertical_drop: f32,
};

pub fn checkRavineStride(gap_width: f32) RavineStrideCheck {
    if (canCrossGap(gap_width)) {
        return .{
            .can_stride = true,
            .gravity_dip_applied = false,
            .fell_into_ravine = false,
            .vertical_drop = 0.0,
        };
    } else {
        return .{
            .can_stride = false,
            .gravity_dip_applied = true,
            .fell_into_ravine = true,
            .vertical_drop = 1.0,
        };
    }
}

pub const TerrainStepResult = struct {
    cleared: bool,
    new_y: f32,
    gravity_dip: f32,
    fell_into_ravine: bool,
};

pub fn stepOverTerrain(
    current_y: f32,
    target_height_delta: f32,
    gap_width: f32,
    gravity: f32,
    dt: f32,
) TerrainStepResult {
    if (gap_width > 0.0) {
        if (gap_width <= max_ravine_stride_blocks) {
            // Effortlessly bridged without downward gravity dip
            if (target_height_delta > 0.0) {
                if (target_height_delta <= camel_step_height) {
                    return .{
                        .cleared = true,
                        .new_y = current_y + target_height_delta,
                        .gravity_dip = 0.0,
                        .fell_into_ravine = false,
                    };
                } else {
                    return .{
                        .cleared = false,
                        .new_y = current_y,
                        .gravity_dip = 0.0,
                        .fell_into_ravine = false,
                    };
                }
            } else {
                return .{
                    .cleared = true,
                    .new_y = current_y + target_height_delta,
                    .gravity_dip = 0.0,
                    .fell_into_ravine = false,
                };
            }
        } else {
            // Gap > 2.0 blocks: camel falls into ravine
            const dip = 0.5 * gravity * dt * dt + gravity * dt;
            return .{
                .cleared = false,
                .new_y = current_y - dip,
                .gravity_dip = dip,
                .fell_into_ravine = true,
            };
        }
    }

    if (target_height_delta > 0.0) {
        if (target_height_delta <= camel_step_height) {
            return .{
                .cleared = true,
                .new_y = current_y + target_height_delta,
                .gravity_dip = 0.0,
                .fell_into_ravine = false,
            };
        } else {
            return .{
                .cleared = false,
                .new_y = current_y,
                .gravity_dip = 0.0,
                .fell_into_ravine = false,
            };
        }
    } else {
        return .{
            .cleared = true,
            .new_y = current_y + target_height_delta,
            .gravity_dip = 0.0,
            .fell_into_ravine = false,
        };
    }
}

pub const GapMotion = struct {
    y: f32 = 0.0,
    vertical_velocity: f32 = 0.0,

    /// Advances a camel crossing a gap. Strideable gaps preserve height; wider
    /// gaps use ordinary constant downward acceleration.
    pub fn advance(self: *GapMotion, width: f32, dt: f32) void {
        if (canStrideGap(width)) return;
        self.y += self.vertical_velocity * dt - 0.5 * GRAVITY * dt * dt;
        self.vertical_velocity -= GRAVITY * dt;
    }
};

pub fn rotateYaw(offset: Vec3, yaw: f32) Vec3 {
    const cos_y = @cos(yaw);
    const sin_y = @sin(yaw);
    return .{
        .x = offset.x * cos_y + offset.z * sin_y,
        .y = offset.y,
        .z = -offset.x * sin_y + offset.z * cos_y,
    };
}

pub fn getSeatLocalPosition(slot: SeatSlot, is_sitting: bool) Vec3 {
    return switch (slot) {
        .driver => if (is_sitting) driver_seat_sitting_vec else driver_seat_position,
        .passenger => if (is_sitting) passenger_seat_sitting_vec else passenger_seat_position,
    };
}

pub fn getSeatOffset(seat: SeatSlot, is_sitting: bool) SeatOffset {
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

pub fn computeWorldSeatCoords(cx: f32, cy: f32, cz: f32, yaw: f32, seat: SeatSlot, is_sitting: bool) struct { x: f32, y: f32, z: f32 } {
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

pub fn computeWorldSeatPosition(camel_pos: Vec3, yaw: f32, slot: SeatSlot, is_sitting: bool) Vec3 {
    const local = getSeatLocalPosition(slot, is_sitting);
    const rotated = rotateYaw(local, yaw);
    return .{
        .x = camel_pos.x + rotated.x,
        .y = camel_pos.y + rotated.y,
        .z = camel_pos.z + rotated.z,
    };
}

pub fn applyCactusHeal(current_hp: f32, max_hp: f32) f32 {
    return @min(max_hp, current_hp + cactus_heal_amount);
}

pub fn accelerateBabyGrowth(remaining_time: f32) f32 {
    return @max(0.0, remaining_time - baby_growth_step_reduction);
}

pub const DualSeating = struct {
    driver: ?u64 = null,
    passenger: ?u64 = null,

    pub fn init() DualSeating {
        return .{};
    }

    pub fn riderCount(self: DualSeating) u8 {
        var count: u8 = 0;
        if (self.driver != null) count += 1;
        if (self.passenger != null) count += 1;
        return count;
    }

    pub fn isFull(self: DualSeating) bool {
        return self.driver != null and self.passenger != null;
    }

    pub fn isEmpty(self: DualSeating) bool {
        return self.driver == null and self.passenger == null;
    }

    pub fn isDismounted(self: DualSeating) bool {
        return self.isEmpty();
    }

    pub fn hasDriver(self: DualSeating) bool {
        return self.driver != null;
    }

    pub fn hasPassenger(self: DualSeating) bool {
        return self.passenger != null;
    }

    pub fn mountRider(self: *DualSeating, entity_id: u64) ?SeatSlot {
        // Driver seat preferred, then passenger seat
        if (self.driver == null) {
            self.driver = entity_id;
            return .driver;
        } else if (self.passenger == null) {
            self.passenger = entity_id;
            return .passenger;
        }
        return null;
    }

    pub fn mountSlot(self: *DualSeating, slot: SeatSlot, entity_id: u64) bool {
        switch (slot) {
            .driver => {
                if (self.driver != null) return false;
                self.driver = entity_id;
                return true;
            },
            .passenger => {
                if (self.passenger != null) return false;
                self.passenger = entity_id;
                return true;
            },
        }
    }

    pub fn dismountRider(self: *DualSeating, entity_id: u64) ?SeatSlot {
        if (self.driver != null and self.driver.? == entity_id) {
            self.driver = null;
            return .driver;
        }
        if (self.passenger != null and self.passenger.? == entity_id) {
            self.passenger = null;
            return .passenger;
        }
        return null;
    }

    pub fn dismountSlot(self: *DualSeating, slot: SeatSlot) ?u64 {
        switch (slot) {
            .driver => {
                const prev = self.driver;
                self.driver = null;
                return prev;
            },
            .passenger => {
                const prev = self.passenger;
                self.passenger = null;
                return prev;
            },
        }
    }

    pub fn canControl(self: DualSeating, entity_id: u64) bool {
        return self.driver != null and self.driver.? == entity_id;
    }

    pub fn isPassivePassenger(self: DualSeating, entity_id: u64) bool {
        return self.passenger != null and self.passenger.? == entity_id;
    }
};

pub const DashState = struct {
    // Tick-based fields (camel_step_dash.zig)
    charge_ticks: u16 = 0,
    cooldown_ticks: u16 = 0,
    dash_distance: f32 = 0.0,
    dash_velocity: f32 = 0.0,
    dashing: bool = false,
    jump_was_held: bool = false,

    // Time-based fields (camel_mount_kinematics.zig)
    charge_timer: f32 = 0.0,
    cooldown_timer: f32 = 0.0,
    is_dashing: bool = false,
    dash_distance_traveled: f32 = 0.0,
    current_burst_speed: f32 = 0.0,

    pub fn init() DashState {
        return .{};
    }

    // Tick-based methods
    pub fn chargeRatio(self: DashState) f32 {
        return @as(f32, @floatFromInt(self.charge_ticks)) / @as(f32, @floatFromInt(CHARGE_TICKS));
    }

    pub fn canCharge(self: DashState) bool {
        return self.cooldown_ticks == 0 and !self.dashing and self.cooldown_timer <= 0.0001 and !self.is_dashing;
    }

    pub fn updateTick(self: *DashState, jump_held: bool) void {
        const locked_at_tick_start = self.cooldown_ticks > 0;
        if (self.cooldown_ticks > 0) self.cooldown_ticks -= 1;

        if (self.dashing) self.advanceDash(TICK_SECONDS);

        if (!locked_at_tick_start and self.cooldown_ticks == 0 and !self.dashing) {
            if (jump_held) {
                if (self.charge_ticks < CHARGE_TICKS) self.charge_ticks += 1;
            } else if (self.jump_was_held and self.charge_ticks > 0) {
                self.startDash();
            }
        }
        self.jump_was_held = jump_held;
    }

    fn startDash(self: *DashState) void {
        self.dashing = true;
        self.dash_velocity = DASH_SPEED;
        self.dash_distance = 0.0;
        self.charge_ticks = 0;
        self.cooldown_ticks = DASH_COOLDOWN_TICKS;
    }

    fn advanceDash(self: *DashState, dt: f32) void {
        const deceleration = DASH_SPEED * DASH_SPEED / (2.0 * DASH_DISTANCE);
        const step_time = @min(dt, self.dash_velocity / deceleration);
        const travel = self.dash_velocity * step_time - 0.5 * deceleration * step_time * step_time;
        self.dash_distance += travel;
        self.dash_velocity = @max(0.0, self.dash_velocity - deceleration * step_time);
        if (self.dash_distance >= DASH_DISTANCE or self.dash_velocity == 0.0) {
            self.dash_distance = DASH_DISTANCE;
            self.dash_velocity = 0.0;
            self.dashing = false;
        }
    }

    // Time-based methods
    pub fn getChargeRatio(self: DashState) f32 {
        return std.math.clamp(self.charge_timer / dash_max_charge_time, 0.0, 1.0);
    }

    pub fn canDash(self: DashState) bool {
        return self.cooldown_timer <= 0.0001 and self.getChargeRatio() > 0.0;
    }

    pub fn charge(self: *DashState, dt: f32) void {
        if (!self.canCharge()) return;
        self.charge_timer = @min(dash_max_charge_time, self.charge_timer + dt);
    }

    pub fn setCharge(self: *DashState, ratio: f32) void {
        if (!self.canCharge()) return;
        self.charge_timer = std.math.clamp(ratio, 0.0, 1.0) * dash_max_charge_time;
    }

    pub fn releaseDash(self: *DashState, yaw: f32, on_ground: bool) ?DashImpulse {
        if (!on_ground or !self.canDash()) {
            self.charge_timer = 0.0;
            return null;
        }

        const ratio = self.getChargeRatio();
        const impulse = computeKinematicDashImpulse(ratio, yaw);

        self.is_dashing = true;
        self.dash_distance_traveled = 0.0;
        self.current_burst_speed = impulse.speed;
        self.charge_timer = 0.0;
        self.cooldown_timer = dash_cooldown_duration;

        return impulse;
    }

    pub fn update(self: *DashState, dt: f32) void {
        if (self.cooldown_timer > 0.0) {
            self.cooldown_timer -= dt;
            if (self.cooldown_timer < 0.0001) {
                self.cooldown_timer = 0.0;
            }
        }

        if (self.is_dashing) {
            const step_dist = self.current_burst_speed * dt;
            if (self.dash_distance_traveled + step_dist >= dash_max_distance) {
                self.dash_distance_traveled = dash_max_distance;
                self.is_dashing = false;
                self.current_burst_speed = 0.0;
            } else {
                self.dash_distance_traveled += step_dist;
                self.current_burst_speed = @max(0.0, self.current_burst_speed - dash_deceleration * dt);
                if (self.current_burst_speed <= 0.001) {
                    self.is_dashing = false;
                    self.current_burst_speed = 0.0;
                }
            }
        }
    }
};

pub const RiderInput = struct {
    forward: f32 = 0.0,      // -1.0 to 1.0
    strafe: f32 = 0.0,       // -1.0 to 1.0
    yaw_delta: f32 = 0.0,    // steering adjustment (radians)
    jump_held: bool = false, // spacebar / jump button held
};

pub const CamelMountKinematics = struct {
    pos: Vec3 = Vec3.zero,
    vel: Vec3 = Vec3.zero,
    yaw: f32 = 0.0,
    pitch: f32 = 0.0,
    on_ground: bool = true,
    step_height: f32 = camel_step_height,
    posture: Posture = .standing,
    posture_timer: f32 = 0.0,
    idle_timer: f32 = 0.0,
    auto_sit_enabled: bool = true,
    auto_sit_delay: f32 = idle_sit_delay,
    seating: DualSeating = DualSeating.init(),
    dash: DashState = DashState.init(),

    const epsilon: f32 = 0.0001;

    pub fn init() CamelMountKinematics {
        return .{};
    }

    pub fn initWithPosition(pos: Vec3, yaw: f32) CamelMountKinematics {
        return .{
            .pos = pos,
            .yaw = yaw,
        };
    }

    // Seating operations
    pub fn mountRider(self: *CamelMountKinematics, entity_id: u64) ?SeatSlot {
        const slot = self.seating.mountRider(entity_id);
        if (slot != null) {
            self.idle_timer = 0.0;
            // If sitting, mounting wakes camel to begin standing up
            if (self.posture == .sitting) {
                _ = self.startStanding();
            }
        }
        return slot;
    }

    pub fn mountSlot(self: *CamelMountKinematics, slot: SeatSlot, entity_id: u64) bool {
        const ok = self.seating.mountSlot(slot, entity_id);
        if (ok) {
            self.idle_timer = 0.0;
            if (self.posture == .sitting) {
                _ = self.startStanding();
            }
        }
        return ok;
    }

    pub fn dismountRider(self: *CamelMountKinematics, entity_id: u64) ?SeatSlot {
        const slot = self.seating.dismountRider(entity_id);
        if (slot != null) {
            self.idle_timer = 0.0;
        }
        return slot;
    }

    pub fn dismountSlot(self: *CamelMountKinematics, slot: SeatSlot) ?u64 {
        const prev = self.seating.dismountSlot(slot);
        if (prev != null) {
            self.idle_timer = 0.0;
        }
        return prev;
    }

    pub fn hasDriver(self: CamelMountKinematics) bool {
        return self.seating.hasDriver();
    }

    pub fn hasPassenger(self: CamelMountKinematics) bool {
        return self.seating.hasPassenger();
    }

    pub fn riderCount(self: CamelMountKinematics) u8 {
        return self.seating.riderCount();
    }

    pub fn isFull(self: CamelMountKinematics) bool {
        return self.seating.isFull();
    }

    pub fn isDismounted(self: CamelMountKinematics) bool {
        return self.seating.isDismounted();
    }

    pub fn canControl(self: CamelMountKinematics, entity_id: u64) bool {
        return self.seating.canControl(entity_id);
    }

    pub fn isPassivePassenger(self: CamelMountKinematics, entity_id: u64) bool {
        return self.seating.isPassivePassenger(entity_id);
    }

    pub fn getSeatWorldPosition(self: CamelMountKinematics, slot: SeatSlot) Vec3 {
        const is_sit = self.posture == .sitting or self.posture == .transition_sitting or self.posture == .sitting_down;
        return computeWorldSeatPosition(self.pos, self.yaw, slot, is_sit);
    }

    // Posture operations
    pub fn isStanding(self: CamelMountKinematics) bool {
        return self.posture == .standing;
    }

    pub fn isSitting(self: CamelMountKinematics) bool {
        return self.posture == .sitting;
    }

    pub fn isTransitioning(self: CamelMountKinematics) bool {
        return self.posture.isTransitioning();
    }

    pub fn canMove(self: CamelMountKinematics) bool {
        return self.posture.canMove();
    }

    pub fn canDash(self: CamelMountKinematics) bool {
        return self.posture.canDash() and self.dash.canDash() and self.on_ground;
    }

    pub fn canChargeDash(self: CamelMountKinematics) bool {
        return self.posture.canDash() and self.dash.canCharge();
    }

    pub fn startSitting(self: *CamelMountKinematics) bool {
        if (self.posture != .standing) return false;
        self.posture = .transition_sitting;
        self.posture_timer = sit_transition_duration;
        self.dash.charge_timer = 0.0;
        self.idle_timer = 0.0;
        return true;
    }

    pub fn startStanding(self: *CamelMountKinematics) bool {
        if (self.posture != .sitting) return false;
        self.posture = .transition_standing;
        self.posture_timer = stand_transition_duration;
        self.idle_timer = 0.0;
        return true;
    }

    pub fn togglePosture(self: *CamelMountKinematics) bool {
        return switch (self.posture) {
            .standing => self.startSitting(),
            .sitting => self.startStanding(),
            .transition_sitting, .transition_standing, .sitting_down, .standing_up => false,
        };
    }

    // Dash operations
    pub fn chargeDash(self: *CamelMountKinematics, dt: f32) void {
        if (!self.canChargeDash()) return;
        self.dash.charge(dt);
        self.idle_timer = 0.0;
    }

    pub fn setDashCharge(self: *CamelMountKinematics, ratio: f32) void {
        if (!self.canChargeDash()) return;
        self.dash.setCharge(ratio);
        self.idle_timer = 0.0;
    }

    pub fn getDashChargeRatio(self: CamelMountKinematics) f32 {
        return self.dash.getChargeRatio();
    }

    pub fn getDashCooldown(self: CamelMountKinematics) f32 {
        return self.dash.cooldown_timer;
    }

    pub fn releaseDash(self: *CamelMountKinematics) ?DashImpulse {
        if (!self.posture.canDash()) {
            self.dash.charge_timer = 0.0;
            return null;
        }
        const impulse = self.dash.releaseDash(self.yaw, self.on_ground);
        if (impulse != null) {
            self.vel.x = impulse.?.vx;
            self.vel.z = impulse.?.vz;
            self.idle_timer = 0.0;
        }
        return impulse;
    }

    // Kinematics and input processing
    pub fn applyDriverInput(self: *CamelMountKinematics, entity_id: u64, input: RiderInput, dt: f32) bool {
        // Only driver controls steering, movement, and dash; passenger rides along passively
        if (!self.canControl(entity_id)) {
            return false;
        }

        self.idle_timer = 0.0;

        // If sitting, any movement or jump input wakes camel to stand up
        if (self.posture == .sitting) {
            if (input.forward != 0.0 or input.strafe != 0.0 or input.jump_held) {
                _ = self.startStanding();
            }
            return true;
        }

        // If transitioning, cannot move or dash yet
        if (self.isTransitioning()) {
            return true;
        }

        // Standing posture: process steering, movement, and dash
        self.yaw += input.yaw_delta;

        // Jump held charges dash; releasing triggers dash
        if (input.jump_held) {
            self.chargeDash(dt);
        } else if (self.dash.getChargeRatio() > 0.0) {
            _ = self.releaseDash();
        }

        // Horizontal walking velocity when not dashing
        if (!self.dash.is_dashing) {
            const walk_speed: f32 = 2.8; // normal walk speed in m/s
            const sin_y = @sin(self.yaw);
            const cos_y = @cos(self.yaw);

            // Forward vector: (sin(yaw), 0, -cos(yaw))
            // Strafe right vector: (cos(yaw), 0, sin(yaw))
            const fwd_x = sin_y * input.forward;
            const fwd_z = -cos_y * input.forward;
            const str_x = cos_y * input.strafe;
            const str_z = sin_y * input.strafe;

            self.vel.x = (fwd_x + str_x) * walk_speed;
            self.vel.z = (fwd_z + str_z) * walk_speed;
        }

        return true;
    }

    // Step height obstacle clearing check
    pub fn canStepOver(self: CamelMountKinematics, obstacle_height: f32) bool {
        _ = self;
        return canStepOverObstacle(obstacle_height);
    }

    // Ravine stride gap check
    pub fn canCrossRavine(self: CamelMountKinematics, gap_width: f32) bool {
        _ = self;
        return canCrossGap(gap_width);
    }

    // State update
    pub fn update(self: *CamelMountKinematics, dt: f32) void {
        // 1. Posture state machine timer
        switch (self.posture) {
            .transition_sitting, .sitting_down => {
                self.posture_timer -= dt;
                if (self.posture_timer <= epsilon) {
                    self.posture = .sitting;
                    self.posture_timer = 0.0;
                }
            },
            .transition_standing, .standing_up => {
                self.posture_timer -= dt;
                if (self.posture_timer <= epsilon) {
                    self.posture = .standing;
                    self.posture_timer = 0.0;
                }
            },
            .standing => {
                // Camel sits down when idle and dismounted
                if (self.auto_sit_enabled and self.isDismounted()) {
                    self.idle_timer += dt;
                    if (self.idle_timer >= self.auto_sit_delay) {
                        _ = self.startSitting();
                    }
                } else {
                    self.idle_timer = 0.0;
                }
            },
            .sitting => {
                self.idle_timer = 0.0;
            },
        }

        // 2. Dash state update
        self.dash.update(dt);

        // 3. Update velocity from dash if currently dashing
        if (self.dash.is_dashing) {
            const sin_y = @sin(self.yaw);
            const cos_y = @cos(self.yaw);
            self.vel.x = sin_y * self.dash.current_burst_speed;
            self.vel.z = -cos_y * self.dash.current_burst_speed;
        }

        // 4. Position update
        self.pos.x += self.vel.x * dt;
        self.pos.y += self.vel.y * dt;
        self.pos.z += self.vel.z * dt;
    }

    pub fn tick(self: *CamelMountKinematics) void {
        self.update(0.05);
    }
};

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
        return self.posture.isTransitioning();
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
            .sitting_down, .standing_up, .transition_sitting, .transition_standing => false,
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
        if (!on_ground or self.posture != .standing or self.dash_cooldown > timer_epsilon) {
            self.dash_charge = 0.0;
            return null;
        }
        const charge = if (self.dash_charge > 0.0) self.dash_charge else 1.0;
        const impulse = computeDashImpulse(charge, yaw);
        self.dash_charge = 0.0;
        self.dash_cooldown = dash_cooldown_duration;
        return impulse;
    }

    /// Mounts a rider into the next available seat (driver preferred, then passenger).
    pub fn mountRider(self: *CamelState) ?SeatSlot {
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
    pub fn dismountRider(self: *CamelState, seat: SeatSlot) void {
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
    pub fn getSeat(self: CamelState, seat: SeatSlot) SeatOffset {
        return getSeatOffset(seat, self.posture == .sitting or self.posture == .sitting_down or self.posture == .transition_sitting);
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
            .sitting_down, .transition_sitting => {
                self.transition_timer -= dt;
                if (self.transition_timer <= timer_epsilon) {
                    self.posture = .sitting;
                    self.transition_timer = 0.0;
                }
            },
            .standing_up, .transition_standing => {
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
    const pos_north = computeWorldSeatCoords(10.0, 64.0, 20.0, 0.0, .driver, false);
    try std.testing.expectApproxEqAbs(pos_north.x, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(pos_north.y, 66.3, 0.001);
    try std.testing.expectApproxEqAbs(pos_north.z, 20.5, 0.001);

    // Camel facing +X (yaw = pi/2)
    const pos_east = computeWorldSeatCoords(10.0, 64.0, 20.0, std.math.pi * 0.5, .driver, false);
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


test "step height is exactly 1.5 meters" {
    try std.testing.expectEqual(@as(f32, 1.5), STEP_HEIGHT);
}

test "fence height is passable without jumping" {
    try std.testing.expect(canStepOver(1.5));
}

test "fence gate height is passable without jumping" {
    try std.testing.expect(canStepOver(1.5));
}

test "cobblestone wall height is passable without jumping" {
    try std.testing.expect(canStepOver(1.5));
}

test "stone brick wall height is passable without jumping" {
    try std.testing.expect(canStepOver(1.5));
}

test "1.5 block elevation change is passable" {
    try std.testing.expect(canStepOver(1.5));
}

test "lower steps are passable" {
    try std.testing.expect(canStepOver(1.0));
}

test "1.5001 meter obstacle exceeds step assist" {
    try std.testing.expect(!canStepOver(1.5001));
}

test "2 meter obstacle blocks forward motion" {
    try std.testing.expect(is_obstructed(2.0));
}

test "1.5 meter obstacle does not obstruct" {
    try std.testing.expect(!is_obstructed(1.5));
}

test "two block gap can be strided" {
    try std.testing.expect(canStrideGap(2.0));
}

test "narrow gap can be strided" {
    try std.testing.expect(canStrideGap(1.0));
}

test "gap wider than two blocks cannot be strided" {
    try std.testing.expect(!canStrideGap(2.01));
}

test "two block stride preserves height and vertical velocity" {
    var motion = GapMotion{ .y = 64.0, .vertical_velocity = 0.0 };
    motion.advance(2.0, 0.5);
    try std.testing.expectEqual(@as(f32, 64.0), motion.y);
    try std.testing.expectEqual(@as(f32, 0.0), motion.vertical_velocity);
}

test "wider gap accelerates downward under gravity" {
    var motion = GapMotion{ .y = 64.0 };
    motion.advance(2.1, 0.5);
    try std.testing.expect(motion.y < 64.0);
    try std.testing.expect(motion.vertical_velocity < 0.0);
}

test "gravity displacement follows half g t squared" {
    var motion = GapMotion{};
    motion.advance(3.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, -4.905), motion.y, 0.0001);
}

test "dash starts with zero charge" {
    try std.testing.expectEqual(@as(f32, 0.0), DashState.init().chargeRatio());
}

test "first held tick charges two percent" {
    var dash = DashState.init();
    dash.updateTick(true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.02), dash.chargeRatio(), 0.0001);
}

test "25 held ticks charge halfway" {
    var dash = DashState.init();
    for (0..25) |_| dash.updateTick(true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), dash.chargeRatio(), 0.0001);
}

test "50 held ticks fully charge stamina" {
    var dash = DashState.init();
    for (0..50) |_| dash.updateTick(true);
    try std.testing.expectEqual(@as(f32, 1.0), dash.chargeRatio());
}

test "charging clamps at full after 50 ticks" {
    var dash = DashState.init();
    for (0..60) |_| dash.updateTick(true);
    try std.testing.expectEqual(@as(f32, 1.0), dash.chargeRatio());
}

test "releasing a charged jump launches the dash" {
    var dash = DashState.init();
    for (0..50) |_| dash.updateTick(true);
    dash.updateTick(false);
    try std.testing.expect(dash.dashing);
}

test "dash launch velocity is 19.5 meters per second" {
    var dash = DashState.init();
    dash.updateTick(true);
    dash.updateTick(false);
    try std.testing.expectEqual(@as(f32, 19.5), dash.dash_velocity);
}

test "dash launch sets a 12 block travel limit" {
    try std.testing.expectEqual(@as(f32, 12.0), DASH_DISTANCE);
}

test "dash eventually surges the full 12 blocks" {
    var dash = DashState.init();
    dash.updateTick(true);
    dash.updateTick(false);
    for (0..100) |_| dash.updateTick(false);
    try std.testing.expectEqual(@as(f32, 12.0), dash.dash_distance);
    try std.testing.expect(!dash.dashing);
}

test "dash release locks stamina for 55 ticks" {
    var dash = DashState.init();
    dash.updateTick(true);
    dash.updateTick(false);
    try std.testing.expectEqual(@as(u16, 55), dash.cooldown_ticks);
}

test "cooldown blocks charge on the first locked tick" {
    var dash = DashState.init();
    dash.updateTick(true);
    dash.updateTick(false);
    dash.updateTick(true);
    try std.testing.expectEqual(@as(u16, 54), dash.cooldown_ticks);
    try std.testing.expectEqual(@as(f32, 0.0), dash.chargeRatio());
}

test "cooldown expires after 55 ticks" {
    var dash = DashState.init();
    dash.updateTick(true);
    dash.updateTick(false);
    for (0..55) |_| dash.updateTick(false);
    try std.testing.expectEqual(@as(u16, 0), dash.cooldown_ticks);
    try std.testing.expect(dash.canCharge());
}

test "holding jump during cooldown does not begin charging afterward" {
    var dash = DashState.init();
    dash.updateTick(true);
    dash.updateTick(false);
    for (0..55) |_| dash.updateTick(true);
    try std.testing.expectEqual(@as(u16, 0), dash.charge_ticks);
    dash.updateTick(false);
    dash.updateTick(true);
    try std.testing.expectEqual(@as(u16, 1), dash.charge_ticks);
}

test "an uncharged jump release does not dash" {
    var dash = DashState.init();
    dash.updateTick(true);
    dash.charge_ticks = 0;
    dash.updateTick(false);
    try std.testing.expect(!dash.dashing);
}


// ============================================================================
// Unit Tests (28 Comprehensive Tests)
// ============================================================================

test "1. Seating: driver seat front and passenger seat rear coordinates" {
    try std.testing.expectEqual(@as(f32, 0.0), driver_seat_position.x);
    try std.testing.expectEqual(@as(f32, 1.85), driver_seat_position.y);
    try std.testing.expectEqual(@as(f32, -0.35), driver_seat_position.z);

    try std.testing.expectEqual(@as(f32, 0.0), passenger_seat_position.x);
    try std.testing.expectEqual(@as(f32, 1.85), passenger_seat_position.y);
    try std.testing.expectEqual(@as(f32, 0.55), passenger_seat_position.z);

    // Front seat has negative Z (-0.35), rear seat has positive Z (0.55)
    try std.testing.expect(driver_seat_position.z < passenger_seat_position.z);
}

test "2. Seating: sequential mounting assigns driver first then passenger" {
    var camel = CamelMountKinematics.init();
    try std.testing.expectEqual(@as(u8, 0), camel.riderCount());
    try std.testing.expect(!camel.hasDriver());
    try std.testing.expect(!camel.hasPassenger());

    // First rider gets driver seat
    const seat1 = camel.mountRider(101);
    try std.testing.expect(seat1 != null);
    try std.testing.expectEqual(SeatSlot.driver, seat1.?);
    try std.testing.expectEqual(@as(u8, 1), camel.riderCount());
    try std.testing.expect(camel.hasDriver());
    try std.testing.expect(!camel.hasPassenger());

    // Second rider gets passenger seat
    const seat2 = camel.mountRider(102);
    try std.testing.expect(seat2 != null);
    try std.testing.expectEqual(SeatSlot.passenger, seat2.?);
    try std.testing.expectEqual(@as(u8, 2), camel.riderCount());
    try std.testing.expect(camel.hasDriver());
    try std.testing.expect(camel.hasPassenger());
    try std.testing.expect(camel.isFull());
}

test "3. Seating: occupancy rejects third rider when full" {
    var camel = CamelMountKinematics.init();
    _ = camel.mountRider(101);
    _ = camel.mountRider(102);
    try std.testing.expect(camel.isFull());

    // Third rider rejected
    const seat3 = camel.mountRider(103);
    try std.testing.expect(seat3 == null);
    try std.testing.expectEqual(@as(u8, 2), camel.riderCount());
}

test "4. Seating: dismount rider reclaims vacated slot" {
    var camel = CamelMountKinematics.init();
    _ = camel.mountRider(101);
    _ = camel.mountRider(102);

    // Dismount driver
    const dismounted_slot = camel.dismountRider(101);
    try std.testing.expectEqual(SeatSlot.driver, dismounted_slot.?);
    try std.testing.expectEqual(@as(u8, 1), camel.riderCount());
    try std.testing.expect(!camel.hasDriver());
    try std.testing.expect(camel.hasPassenger());

    // New rider claims the vacated driver seat
    const new_driver = camel.mountRider(103);
    try std.testing.expectEqual(SeatSlot.driver, new_driver.?);
    try std.testing.expect(camel.hasDriver());
}

test "5. Seating: driver has control authority, passenger rides passively" {
    var camel = CamelMountKinematics.init();
    _ = camel.mountRider(101); // Driver
    _ = camel.mountRider(102); // Passenger

    try std.testing.expect(camel.canControl(101));
    try std.testing.expect(!camel.canControl(102));
    try std.testing.expect(!camel.isPassivePassenger(101));
    try std.testing.expect(camel.isPassivePassenger(102));

    // Passenger input is rejected and ignored
    const passenger_input = RiderInput{ .forward = 1.0, .yaw_delta = 0.5, .jump_held = true };
    const accepted_pas = camel.applyDriverInput(102, passenger_input, 0.05);
    try std.testing.expect(!accepted_pas);
    try std.testing.expectEqual(@as(f32, 0.0), camel.yaw);
    try std.testing.expectEqual(@as(f32, 0.0), camel.getDashChargeRatio());

    // Driver input is accepted and steers / charges dash
    const driver_input = RiderInput{ .forward = 1.0, .yaw_delta = 0.25, .jump_held = true };
    const accepted_drv = camel.applyDriverInput(101, driver_input, 0.05);
    try std.testing.expect(accepted_drv);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), camel.yaw, 0.001);
    try std.testing.expect(camel.getDashChargeRatio() > 0.0);
}

test "6. Seating: world seat position calculation rotates with yaw" {
    const camel_pos = Vec3.init(10.0, 64.0, 20.0);

    // Yaw = 0 (facing -Z)
    const drv_pos_0 = computeWorldSeatPosition(camel_pos, 0.0, .driver, false);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), drv_pos_0.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 65.85), drv_pos_0.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 19.65), drv_pos_0.z, 0.001);

    const pas_pos_0 = computeWorldSeatPosition(camel_pos, 0.0, .passenger, false);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pas_pos_0.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 65.85), pas_pos_0.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.55), pas_pos_0.z, 0.001);

    // Yaw = pi/2 (turned 90 deg clockwise)
    const drv_pos_90 = computeWorldSeatPosition(camel_pos, std.math.pi * 0.5, .driver, false);
    try std.testing.expectApproxEqAbs(@as(f32, 9.65), drv_pos_90.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 65.85), drv_pos_90.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), drv_pos_90.z, 0.001);
}

test "7. Seating: sitting posture lowers rider seat height" {
    var camel = CamelMountKinematics.initWithPosition(Vec3.init(0.0, 64.0, 0.0), 0.0);
    _ = camel.mountRider(101);

    // Standing seat Y = 64.0 + 1.85 = 65.85
    const stand_seat = camel.getSeatWorldPosition(.driver);
    try std.testing.expectApproxEqAbs(@as(f32, 65.85), stand_seat.y, 0.001);

    // Transition to sitting
    _ = camel.startSitting();
    camel.update(sit_transition_duration);
    try std.testing.expect(camel.isSitting());

    // Sitting seat Y = 64.0 + 0.95 = 64.95
    const sit_seat = camel.getSeatWorldPosition(.driver);
    try std.testing.expectApproxEqAbs(@as(f32, 64.95), sit_seat.y, 0.001);
    try std.testing.expect(stand_seat.y > sit_seat.y);
}

test "8. Step height: 1.5 blocks allows stepping over 1.5m obstacle without jump" {
    const camel = CamelMountKinematics.init();
    try std.testing.expectEqual(@as(f32, 1.5), camel.step_height);

    try std.testing.expect(camel.canStepOver(0.5));
    try std.testing.expect(camel.canStepOver(1.0));
    try std.testing.expect(camel.canStepOver(1.5));
}

test "9. Step height: fence and stone wall 1.5-block hurdles cleared effortlessly" {
    try std.testing.expect(canClearFence());
    try std.testing.expect(canClearWall());
    try std.testing.expect(canStepOverObstacle(fence_height));
    try std.testing.expect(canStepOverObstacle(wall_height));
}

test "10. Step height: obstacles higher than 1.5 blocks are obstructed" {
    const camel = CamelMountKinematics.init();
    try std.testing.expect(!camel.canStepOver(1.51));
    try std.testing.expect(!camel.canStepOver(1.75));
    try std.testing.expect(!camel.canStepOver(2.0));
    try std.testing.expect(!canStepOverObstacle(2.5));
}

test "11. Ravine stride: 2-block gap spans without downward gravity dip" {
    const check2 = checkRavineStride(2.0);
    try std.testing.expect(check2.can_stride);
    try std.testing.expect(!check2.gravity_dip_applied);
    try std.testing.expect(!check2.fell_into_ravine);
    try std.testing.expectEqual(@as(f32, 0.0), check2.vertical_drop);
}

test "12. Ravine stride: 1-block gap spans effortlessly without gravity dip" {
    const check1 = checkRavineStride(1.0);
    try std.testing.expect(check1.can_stride);
    try std.testing.expect(!check1.gravity_dip_applied);
    try std.testing.expect(!check1.fell_into_ravine);
    try std.testing.expectEqual(@as(f32, 0.0), check1.vertical_drop);

    try std.testing.expect(canCrossGapBlocks(1));
    try std.testing.expect(canCrossGapBlocks(2));
}

test "13. Ravine stride: gaps exceeding 2 blocks cause gravity fall into ravine" {
    const check_over = checkRavineStride(2.1);
    try std.testing.expect(!check_over.can_stride);
    try std.testing.expect(check_over.gravity_dip_applied);
    try std.testing.expect(check_over.fell_into_ravine);

    const check3 = checkRavineStride(3.0);
    try std.testing.expect(!check3.can_stride);
    try std.testing.expect(check3.fell_into_ravine);

    try std.testing.expect(!canCrossGapBlocks(3));
    try std.testing.expect(!canCrossGapBlocks(4));
}

test "14. Dash charge: holding jump scales charge ratio linearly over 2.5 seconds" {
    var camel = CamelMountKinematics.init();
    try std.testing.expectEqual(@as(f32, 0.0), camel.getDashChargeRatio());

    // Charge for 1.25s (half of 2.5s)
    camel.chargeDash(1.25);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), camel.getDashChargeRatio(), 0.001);

    // Charge remaining 1.25s -> reaches 1.0 full charge
    camel.chargeDash(1.25);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), camel.getDashChargeRatio(), 0.001);
}

test "15. Dash charge: charge ratio clamped to 1.0 beyond 2.5 seconds" {
    var camel = CamelMountKinematics.init();
    camel.chargeDash(3.5);
    try std.testing.expectEqual(@as(f32, 1.0), camel.getDashChargeRatio());

    camel.setDashCharge(1.5);
    try std.testing.expectEqual(@as(f32, 1.0), camel.getDashChargeRatio());
}

test "16. Dash surge: full charge produces 19.5 m/s burst velocity" {
    var camel = CamelMountKinematics.init();
    camel.setDashCharge(1.0);

    const impulse = camel.releaseDash();
    try std.testing.expect(impulse != null);
    try std.testing.expectApproxEqAbs(@as(f32, 19.5), impulse.?.speed, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), impulse.?.charge_ratio, 0.001);
    try std.testing.expectEqual(@as(f32, 0.0), impulse.?.vy); // horizontal sprint
}

test "17. Dash surge: partial charge produces proportional burst velocity" {
    const half_impulse = computeDashImpulse(0.5, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 9.75), half_impulse.speed, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), half_impulse.charge_ratio, 0.001);

    const quarter_impulse = computeDashImpulse(0.25, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.875), quarter_impulse.speed, 0.001);
}

test "18. Dash kinematics: burst sprint covers up to 12 blocks distance" {
    const full_impulse = computeDashImpulse(1.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), full_impulse.max_distance, 0.001);

    const half_impulse = computeDashImpulse(0.5, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), half_impulse.max_distance, 0.001);

    // Integrated simulation of burst sprint deceleration
    var camel = CamelMountKinematics.init();
    camel.setDashCharge(1.0);
    _ = camel.releaseDash();

    // Advance 2.0s of sprint simulation
    var t: f32 = 0.0;
    while (t < 2.0) : (t += 0.05) {
        camel.update(0.05);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), camel.dash.dash_distance_traveled, 0.1);
    try std.testing.expect(!camel.dash.is_dashing);
}

test "19. Dash stamina: 2.75s recovery cooldown locks out dash and charge" {
    var camel = CamelMountKinematics.init();
    camel.setDashCharge(1.0);
    _ = camel.releaseDash();

    try std.testing.expectApproxEqAbs(@as(f32, 2.75), camel.getDashCooldown(), 0.001);
    try std.testing.expect(!camel.canDash());
    try std.testing.expect(!camel.canChargeDash());

    // Charging during cooldown is ignored
    camel.chargeDash(1.0);
    try std.testing.expectEqual(@as(f32, 0.0), camel.getDashChargeRatio());

    // Releasing during cooldown returns null
    const second_dash = camel.releaseDash();
    try std.testing.expect(second_dash == null);
}

test "20. Dash stamina: cooldown ticks down and restores dash capability" {
    var camel = CamelMountKinematics.init();
    camel.setDashCharge(1.0);
    _ = camel.releaseDash();

    // Tick forward 2.70 seconds (54 ticks at 0.05s)
    var i: usize = 0;
    while (i < 54) : (i += 1) {
        camel.tick();
    }
    try std.testing.expect(!camel.canChargeDash());

    // 55th tick (2.75s): cooldown completes
    camel.tick();
    try std.testing.expect(camel.canChargeDash());
    try std.testing.expectEqual(@as(f32, 0.0), camel.getDashCooldown());
}

test "21. Posture: standing to transition_sitting to sitting state machine" {
    var camel = CamelMountKinematics.init();
    try std.testing.expect(camel.isStanding());

    try std.testing.expect(camel.startSitting());
    try std.testing.expectEqual(Posture.transition_sitting, camel.posture);
    try std.testing.expect(camel.isTransitioning());
    try std.testing.expect(!camel.canMove());
    try std.testing.expect(!camel.canDash());

    // Halfway (1.0s)
    camel.update(1.0);
    try std.testing.expectEqual(Posture.transition_sitting, camel.posture);

    // Remaining (1.0s) -> sitting
    camel.update(1.0);
    try std.testing.expect(camel.isSitting());
    try std.testing.expect(!camel.isTransitioning());
}

test "22. Posture: standing up transition takes exactly 2.0 seconds" {
    var camel = CamelMountKinematics.init();
    _ = camel.startSitting();
    camel.update(sit_transition_duration);
    try std.testing.expect(camel.isSitting());

    try std.testing.expect(camel.startStanding());
    try std.testing.expectEqual(Posture.transition_standing, camel.posture);
    try std.testing.expectEqual(@as(f32, 2.0), stand_transition_duration);

    // Advance 1.9s: still transition_standing
    camel.update(1.9);
    try std.testing.expectEqual(Posture.transition_standing, camel.posture);

    // Advance 0.1s (total 2.0s): standing complete
    camel.update(0.1);
    try std.testing.expect(camel.isStanding());
    try std.testing.expect(camel.canMove());
}

test "23. Posture: dismounted idle camel automatically begins sitting down" {
    var camel = CamelMountKinematics.init();
    try std.testing.expect(camel.isDismounted());
    try std.testing.expect(camel.isStanding());

    // Advance 2.9s: still standing
    camel.update(2.9);
    try std.testing.expect(camel.isStanding());

    // 3.0s elapsed: triggers auto-sit transition
    camel.update(0.1);
    try std.testing.expectEqual(Posture.transition_sitting, camel.posture);

    // Another 2.0s: fully sitting
    camel.update(2.0);
    try std.testing.expect(camel.isSitting());
}

test "24. Posture: mounted camel does not auto-sit when idle" {
    var camel = CamelMountKinematics.init();
    _ = camel.mountRider(101); // Driver mounted

    // Idle for 10.0s: camel remains standing
    camel.update(10.0);
    try std.testing.expect(camel.isStanding());
    try std.testing.expect(!camel.isSitting());
}

test "25. Posture: movement and dash prohibited while sitting or transitioning" {
    var camel = CamelMountKinematics.init();
    _ = camel.startSitting();

    // In transition_sitting
    try std.testing.expect(!camel.canMove());
    try std.testing.expect(!camel.canDash());

    camel.update(sit_transition_duration);
    // In sitting
    try std.testing.expect(!camel.canMove());
    try std.testing.expect(!camel.canDash());

    _ = camel.startStanding();
    // In transition_standing
    try std.testing.expect(!camel.canMove());
    try std.testing.expect(!camel.canDash());
}

test "26. Dash release requires on_ground and standing posture" {
    var camel = CamelMountKinematics.init();
    camel.setDashCharge(1.0);

    // In mid-air (on_ground = false): release fails and clears charge
    camel.on_ground = false;
    const air_release = camel.releaseDash();
    try std.testing.expect(air_release == null);
    try std.testing.expectEqual(@as(f32, 0.0), camel.getDashChargeRatio());

    // While sitting: release fails
    camel.on_ground = true;
    _ = camel.startSitting();
    camel.update(sit_transition_duration);
    camel.setDashCharge(1.0);
    const sit_release = camel.releaseDash();
    try std.testing.expect(sit_release == null);
}

test "27. Terrain stepping: 1.5m step up succeeds, 1.6m step up blocked" {
    // 1.5m step up succeeds
    const res_15 = stepOverTerrain(64.0, 1.5, 0.0, 9.8, 0.05);
    try std.testing.expect(res_15.cleared);
    try std.testing.expectApproxEqAbs(@as(f32, 65.5), res_15.new_y, 0.001);

    // 1.6m step up blocked
    const res_16 = stepOverTerrain(64.0, 1.6, 0.0, 9.8, 0.05);
    try std.testing.expect(!res_16.cleared);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), res_16.new_y, 0.001);

    // 2-block ravine crossed without gravity dip
    const res_ravine = stepOverTerrain(64.0, 0.0, 2.0, 9.8, 0.05);
    try std.testing.expect(res_ravine.cleared);
    try std.testing.expectEqual(@as(f32, 0.0), res_ravine.gravity_dip);
    try std.testing.expect(!res_ravine.fell_into_ravine);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), res_ravine.new_y, 0.001);
}

test "28. Integrated camel mount simulation: driver input, dash burst, cooldown" {
    var camel = CamelMountKinematics.init();

    // 1. Mount driver and passenger
    _ = camel.mountRider(201);
    _ = camel.mountRider(202);
    try std.testing.expectEqual(@as(u8, 2), camel.riderCount());

    // 2. Driver charges dash for 2.5s
    var t: f32 = 0.0;
    while (t < 2.5) : (t += 0.05) {
        _ = camel.applyDriverInput(201, .{ .jump_held = true }, 0.05);
        camel.update(0.05);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), camel.getDashChargeRatio(), 0.01);

    // 3. Driver releases jump -> dash burst surges at 19.5 m/s
    _ = camel.applyDriverInput(201, .{ .jump_held = false }, 0.05);
    try std.testing.expect(camel.dash.is_dashing);
    try std.testing.expectApproxEqAbs(@as(f32, 19.5), camel.dash.current_burst_speed, 0.1);

    // 4. Dash cooldown is active for 2.75s
    try std.testing.expectApproxEqAbs(@as(f32, 2.75), camel.getDashCooldown(), 0.1);

    // 5. Simulate 3.0s (sprint finishes 12m and cooldown expires)
    t = 0.0;
    while (t < 3.0) : (t += 0.05) {
        camel.update(0.05);
    }
    try std.testing.expect(!camel.dash.is_dashing);
    try std.testing.expectEqual(@as(f32, 0.0), camel.getDashCooldown());
    try std.testing.expect(camel.canChargeDash());

    // 6. Dismount riders
    _ = camel.dismountRider(201);
    _ = camel.dismountRider(202);
    try std.testing.expect(camel.isDismounted());

    // 7. Camel idles for 3.0s and auto-sits down
    t = 0.0;
    while (t < 3.0) : (t += 0.05) {
        camel.update(0.05);
    }
    try std.testing.expectEqual(Posture.transition_sitting, camel.posture);

    // Finish 2.0s transition to sitting
    t = 0.0;
    while (t < 2.0) : (t += 0.05) {
        camel.update(0.05);
    }
    try std.testing.expect(camel.isSitting());
}
