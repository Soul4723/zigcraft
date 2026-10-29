const std = @import("std");

// ============================================================================
// Milestone 446: Desert Camel Kinematics: Ravine Stride, Dash Charge & Dual Seating
// ============================================================================
// Core mechanics:
// 1. Dual Passenger Seating:
//    - Driver seat (front position x=0.0, y=1.85, z=-0.35)
//    - Passenger seat (rear position x=0.0, y=1.85, z=0.55)
//    - Driver controls steering, movement, and dash; passenger rides along passively.
// 2. 1.5-Block Step Height & 2-Block Ravine Stride:
//    - Step height is 1.5 blocks (walks effortlessly over fences, walls, and 1.5m
//      elevation changes without jumping).
//    - Horizontal stride spans 2-block gaps/ravines without falling into them.
// 3. Dash Charge & Stamina Kinematics:
//    - Charging: holding jump/spacebar charges dash stamina over up to 2.5s (0.0..1.0).
//    - Dash surge: releasing triggers horizontal high-speed sprint across up to 12
//      blocks distance with initial burst velocity 19.5 m/s.
//    - Dash cooldown: 2.75s stamina recovery cooldown before another dash can be charged.
// 4. Posture State Machine:
//    - Postures: .standing, .sitting, .transition_sitting, .transition_standing.
//    - Camel sits down when idle and dismounted; standing up takes a 2.0s transition.
// ============================================================================

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

// ============================================================================
// Constants
// ============================================================================

// Seating positions relative to camel base (standing)
pub const driver_seat_position: Vec3 = .{ .x = 0.0, .y = 1.85, .z = -0.35 };
pub const passenger_seat_position: Vec3 = .{ .x = 0.0, .y = 1.85, .z = 0.55 };

// Sitting rider height drop
pub const sitting_rider_y_drop: f32 = 0.90;
pub const sitting_rider_y: f32 = 1.85 - sitting_rider_y_drop; // 0.95
pub const driver_seat_sitting: Vec3 = .{ .x = 0.0, .y = sitting_rider_y, .z = -0.35 };
pub const passenger_seat_sitting: Vec3 = .{ .x = 0.0, .y = sitting_rider_y, .z = 0.55 };

// Step height & ravine stride capabilities
pub const camel_step_height: f32 = 1.5; // step up over fences & 1.5-block walls without jumping
pub const standard_step_height: f32 = 0.6;
pub const horse_step_height: f32 = 1.0;
pub const fence_height: f32 = 1.5;
pub const wall_height: f32 = 1.5;
pub const max_ravine_stride_blocks: f32 = 2.0; // stride directly over 1-block & 2-block ravines/gaps
pub const max_gap_stride_blocks: u8 = 2;

// Dash charge and burst kinematics
pub const dash_max_charge_time: f32 = 2.5; // up to 2.5 seconds to reach 1.0 charge ratio
pub const dash_initial_burst_velocity: f32 = 19.5; // 19.5 m/s burst velocity at 1.0 charge
pub const dash_max_distance: f32 = 12.0; // horizontal high-speed sprint across up to 12 blocks
pub const dash_cooldown_duration: f32 = 2.75; // 2.75s stamina recovery cooldown
pub const dash_charge_rate: f32 = 1.0 / dash_max_charge_time; // 0.4 per second
pub const dash_deceleration: f32 = (dash_initial_burst_velocity * dash_initial_burst_velocity) / (2.0 * dash_max_distance); // 15.84375 m/s^2

// Posture transition times and idle sitting threshold
pub const stand_transition_duration: f32 = 2.0; // standing up takes a 2.0s transition
pub const sit_transition_duration: f32 = 2.0;   // sitting down transition duration
pub const idle_sit_delay: f32 = 3.0;            // idle dismounted time before auto-sitting

// ============================================================================
// 1. Dual Passenger Seating
// ============================================================================

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

pub fn getSeatLocalPosition(slot: SeatSlot, is_sitting: bool) Vec3 {
    return switch (slot) {
        .driver => if (is_sitting) driver_seat_sitting else driver_seat_position,
        .passenger => if (is_sitting) passenger_seat_sitting else passenger_seat_position,
    };
}

pub fn rotateYaw(offset: Vec3, yaw: f32) Vec3 {
    const cos_y = @cos(yaw);
    const sin_y = @sin(yaw);
    // Standard rotation around Y-axis:
    // x' = x * cos(yaw) + z * sin(yaw)
    // z' = -x * sin(yaw) + z * cos(yaw)
    return .{
        .x = offset.x * cos_y + offset.z * sin_y,
        .y = offset.y,
        .z = -offset.x * sin_y + offset.z * cos_y,
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

// ============================================================================
// 2. 1.5-Block Step Height & 2-Block Ravine Stride
// ============================================================================

pub fn canStepOverObstacle(obstacle_height: f32) bool {
    return obstacle_height <= camel_step_height and obstacle_height >= 0.0;
}

pub fn canClearFence() bool {
    return canStepOverObstacle(fence_height);
}

pub fn canClearWall() bool {
    return canStepOverObstacle(wall_height);
}

pub fn canCrossGap(gap_width: f32) bool {
    return gap_width <= max_ravine_stride_blocks and gap_width >= 0.0;
}

pub fn canCrossGapBlocks(gap_blocks: u8) bool {
    return gap_blocks <= max_gap_stride_blocks;
}

pub const RavineStrideCheck = struct {
    can_stride: bool,
    gravity_dip_applied: bool, // false when 2-block gap is strided over effortlessly
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

// ============================================================================
// 3. Dash Charge & Stamina Kinematics
// ============================================================================

pub const DashImpulse = struct {
    vx: f32,
    vy: f32,
    vz: f32,
    speed: f32,
    charge_ratio: f32,
    max_distance: f32,
};

pub fn computeDashImpulse(charge_ratio: f32, yaw: f32) DashImpulse {
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

    // Forward direction corresponding to yaw:
    // With forward vector along -Z at yaw 0:
    return .{
        .vx = sin_y * speed,
        .vy = 0.0,
        .vz = -cos_y * speed,
        .speed = speed,
        .charge_ratio = ratio,
        .max_distance = distance,
    };
}

pub const DashState = struct {
    charge_timer: f32 = 0.0,
    cooldown_timer: f32 = 0.0,
    is_dashing: bool = false,
    dash_distance_traveled: f32 = 0.0,
    current_burst_speed: f32 = 0.0,

    pub fn init() DashState {
        return .{};
    }

    pub fn getChargeRatio(self: DashState) f32 {
        return std.math.clamp(self.charge_timer / dash_max_charge_time, 0.0, 1.0);
    }

    pub fn canCharge(self: DashState) bool {
        return self.cooldown_timer <= 0.0001 and !self.is_dashing;
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
        const impulse = computeDashImpulse(ratio, yaw);

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
                // Deceleration drag across 12 blocks
                self.current_burst_speed = @max(0.0, self.current_burst_speed - dash_deceleration * dt);
                if (self.current_burst_speed <= 0.001) {
                    self.is_dashing = false;
                    self.current_burst_speed = 0.0;
                }
            }
        }
    }
};

// ============================================================================
// 4. Posture State Machine
// ============================================================================

pub const Posture = enum(u8) {
    standing = 0,
    sitting = 1,
    transition_sitting = 2,
    transition_standing = 3,

    pub fn isStanding(self: Posture) bool {
        return self == .standing;
    }

    pub fn isSitting(self: Posture) bool {
        return self == .sitting;
    }

    pub fn isTransitioning(self: Posture) bool {
        return self == .transition_sitting or self == .transition_standing;
    }

    pub fn canMove(self: Posture) bool {
        return self == .standing;
    }

    pub fn canDash(self: Posture) bool {
        return self == .standing;
    }
};

// ============================================================================
// 5. Rider Input
// ============================================================================

pub const RiderInput = struct {
    forward: f32 = 0.0,      // -1.0 to 1.0
    strafe: f32 = 0.0,       // -1.0 to 1.0
    yaw_delta: f32 = 0.0,    // steering adjustment (radians)
    jump_held: bool = false, // spacebar / jump button held
};

// ============================================================================
// 6. Complete Camel Mount Kinematics System
// ============================================================================

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
        const is_sit = self.posture == .sitting or self.posture == .transition_sitting;
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
            .transition_sitting, .transition_standing => false,
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
            .transition_sitting => {
                self.posture_timer -= dt;
                if (self.posture_timer <= epsilon) {
                    self.posture = .sitting;
                    self.posture_timer = 0.0;
                }
            },
            .transition_standing => {
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
