const std = @import("std");

pub const STEP_HEIGHT: f32 = 1.5;
pub const MAX_STRIDE_GAP: f32 = 2.0;
pub const CHARGE_TICKS: u16 = 50;
pub const DASH_COOLDOWN_TICKS: u16 = 55;
pub const DASH_SPEED: f32 = 19.5;
pub const DASH_DISTANCE: f32 = 12.0;
pub const GRAVITY: f32 = 9.81;
pub const TICK_SECONDS: f32 = 0.05;

pub fn canStepOver(block_height: f32) bool {
    return block_height <= STEP_HEIGHT;
}

pub fn is_obstructed(block_height: f32) bool {
    return block_height > STEP_HEIGHT;
}

pub fn canStrideGap(width: f32) bool {
    return width <= MAX_STRIDE_GAP;
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

pub const DashState = struct {
    charge_ticks: u16 = 0,
    cooldown_ticks: u16 = 0,
    dash_distance: f32 = 0.0,
    dash_velocity: f32 = 0.0,
    dashing: bool = false,
    jump_was_held: bool = false,

    pub fn init() DashState {
        return .{};
    }

    pub fn chargeRatio(self: DashState) f32 {
        return @as(f32, @floatFromInt(self.charge_ticks)) / @as(f32, @floatFromInt(CHARGE_TICKS));
    }

    pub fn canCharge(self: DashState) bool {
        return self.cooldown_ticks == 0 and !self.dashing;
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
        // Constant deceleration chosen so a full-speed launch stops at 12m.
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
};

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
