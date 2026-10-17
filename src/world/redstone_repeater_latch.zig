const std = @import("std");

// ============================================================================
// 1. Repeater Recipe
// ============================================================================

/// Stone material types for crafting checks.
/// Repeaters in Minecraft strictly require smooth/regular stone, NOT cobblestone.
pub const StoneMaterial = enum {
    regular_stone, // Smelted cobblestone or silk-touched natural stone
    cobblestone,
    stone_bricks,
    smooth_stone_slab,
    deepslate,
    cobbled_deepslate,

    pub fn isAcceptedForRepeater(self: StoneMaterial) bool {
        return self == .regular_stone;
    }
};

/// Repeater crafting recipe:
/// 3 stone (regular smooth stone, NOT cobblestone!) + 2 redstone torches + 1 redstone dust -> 1 redstone repeater.
pub const RepeaterRecipe = struct {
    pub const stone_required: u8 = 3;
    pub const torches_required: u8 = 2;
    pub const dust_required: u8 = 1;
    pub const repeater_output: u8 = 1;

    /// Crafts redstone repeaters from ingredient counts.
    /// Calculates how many complete repeaters can be produced.
    pub fn craftRepeater(stone: u8, torches: u8, dust: u8) u8 {
        const batches = @min(
            stone / stone_required,
            @min(torches / torches_required, dust / dust_required),
        );
        return batches * repeater_output;
    }

    /// Cobblestone is explicitly rejected by vanilla Minecraft recipe rules.
    pub fn canCraftWithCobblestone(cobblestone_count: u8, torches: u8, dust: u8) bool {
        _ = cobblestone_count;
        _ = torches;
        _ = dust;
        return false;
    }

    /// Validates material kind and crafts repeaters only if stone is regular stone.
    pub fn craftWithMaterial(material: StoneMaterial, stone_count: u8, torches: u8, dust: u8) u8 {
        if (!material.isAcceptedForRepeater()) return 0;
        return RepeaterRecipe.craftRepeater(stone_count, torches, dust);
    }
};

/// Global alias for crafting redstone repeaters.
pub fn craftRepeater(stone: u8, torches: u8, dust: u8) u8 {
    return RepeaterRecipe.craftRepeater(stone, torches, dust);
}

// ============================================================================
// 2. Repeater Delay Settings (1..4 Redstone Ticks)
// ============================================================================

/// Delay settings for redstone repeaters.
/// Right-clicking cycles the movable torch through 4 discrete delay positions:
/// Position 1: 1 redstone tick  (2 game ticks / 0.10s)
/// Position 2: 2 redstone ticks (4 game ticks / 0.20s)
/// Position 3: 3 redstone ticks (6 game ticks / 0.30s)
/// Position 4: 4 redstone ticks (8 game ticks / 0.40s)
pub const RepeaterDelaySetting = struct {
    pub const min_delay_ticks: u3 = 1;
    pub const max_delay_ticks: u3 = 4;
    pub const default_delay_ticks: u3 = 1;

    pub const game_ticks_per_redstone_tick: u8 = 2;
    pub const seconds_per_redstone_tick: f32 = 0.10;

    /// Cycles the delay position on right-click: 1 -> 2 -> 3 -> 4 -> 1.
    /// Out-of-range inputs wrap safely to 1.
    pub fn cycleRepeaterDelay(current_1_to_4: u3) u3 {
        if (current_1_to_4 < 1 or current_1_to_4 >= 4) {
            return 1;
        }
        return current_1_to_4 + 1;
    }

    pub fn toGameTicks(delay_rticks: u3) u8 {
        return delayRedstoneTicksToGameTicks(delay_rticks);
    }

    pub fn toSeconds(delay_rticks: u3) f32 {
        return delayRedstoneTicksToSeconds(delay_rticks);
    }
};

/// Cycles the repeater delay from 1..4 ticks, wrapping back to 1.
pub fn cycleRepeaterDelay(current_1_to_4: u3) u3 {
    return RepeaterDelaySetting.cycleRepeaterDelay(current_1_to_4);
}

/// Converts redstone tick delay (1..4) to engine game ticks (2, 4, 6, 8).
pub fn delayRedstoneTicksToGameTicks(delay_rticks: u3) u8 {
    const clamped: u8 = if (delay_rticks < 1) 1 else if (delay_rticks > 4) 4 else delay_rticks;
    return clamped * RepeaterDelaySetting.game_ticks_per_redstone_tick;
}

/// Converts redstone tick delay (1..4) to real-time seconds (0.10s, 0.20s, 0.30s, 0.40s).
pub fn delayRedstoneTicksToSeconds(delay_rticks: u3) f32 {
    const clamped: f32 = if (delay_rticks < 1) 1.0 else if (delay_rticks > 4) 4.0 else @floatFromInt(delay_rticks);
    return clamped * RepeaterDelaySetting.seconds_per_redstone_tick;
}

/// Computes cumulative delay in redstone ticks across a chain of repeaters.
pub fn totalChainDelayRedstoneTicks(repeater_delays: []const u3) u32 {
    var total: u32 = 0;
    for (repeater_delays) |d| {
        const clamped: u32 = if (d < 1) 1 else if (d > 4) 4 else d;
        total += clamped;
    }
    return total;
}

/// Computes cumulative delay in seconds across a chain of repeaters.
pub fn totalChainDelaySeconds(repeater_delays: []const u3) f32 {
    return @as(f32, @floatFromInt(totalChainDelayRedstoneTicks(repeater_delays))) * RepeaterDelaySetting.seconds_per_redstone_tick;
}

// ============================================================================
// 3. Signal Amplification and One-Way Diode Isolation
// ============================================================================

/// Signal regeneration and diode isolation mechanics.
/// Repeaters act as diodes: signals enter only from the back and exit at the front.
/// Any input signal >= 1 is boosted to maximum strength 15.
/// Reverse flow (front to back) and lateral conduction (side to front/back) are blocked.
pub const SignalAmplificationAndDiode = struct {
    pub const max_strength: u4 = 15;
    pub const min_strength: u4 = 0;
    pub const trigger_threshold: u4 = 1;

    /// Repeaters are always one-way directional diodes.
    pub fn isOneWayDiode() bool {
        return true;
    }

    /// Front output produces full strength 15 if repeater is active, else 0.
    pub fn frontOutputSignal(is_active: bool) u4 {
        return if (is_active) max_strength else min_strength;
    }

    /// Regenerates any input signal >= 1 to maximum strength 15.
    pub fn amplifySignal(back_signal_0_to_15: u4) u4 {
        return if (back_signal_0_to_15 >= trigger_threshold) max_strength else min_strength;
    }

    /// One-way diode check: signals cannot pass backward from the front.
    pub fn canSignalPassBackward(front_signal: u4) bool {
        _ = front_signal;
        return false;
    }

    /// Signals entering from the sides cannot conduct to front or back.
    pub fn canSideSignalConduct(side_signal: u4) bool {
        _ = side_signal;
        return false;
    }
};

pub const isOneWayDiode = SignalAmplificationAndDiode.isOneWayDiode;
pub const frontOutputSignal = SignalAmplificationAndDiode.frontOutputSignal;
pub const amplifySignal = SignalAmplificationAndDiode.amplifySignal;

// ============================================================================
// 4. Side-Repeater Bedrock Latch Locking (Hardware 1-Bit D-Latch)
// ============================================================================

/// Redstone component types that may point into the side of a repeater.
/// In Minecraft, ONLY a powered repeater or powered comparator facing into
/// the side can lock a target repeater. Dust, torches, and levers cannot.
pub const SideComponentKind = enum {
    repeater,
    comparator,
    redstone_wire,
    redstone_torch,
    redstone_block,
    lever,
    pressure_plate,
    observer,
    other,

    pub fn canLockRepeater(self: SideComponentKind) bool {
        return self == .repeater or self == .comparator;
    }
};

/// Relative side of the target repeater.
pub const RepeaterSide = enum {
    left,
    right,
};

/// Evaluates whether a side component faces into the target repeater.
pub fn doesSideComponentFaceIntoRepeater(
    target_facing: HorizontalFacing,
    side: RepeaterSide,
    component_facing: HorizontalFacing,
) bool {
    const required_facing = switch (side) {
        // Component on the left side must face right (toward the target repeater)
        .left => target_facing.right(),
        // Component on the right side must face left (toward the target repeater)
        .right => target_facing.left(),
    };
    return component_facing == required_facing;
}

/// Evaluates whether a side component locks a repeater.
pub fn isSideLockActive(
    component: SideComponentKind,
    is_powered: bool,
    faces_into_target_side: bool,
) bool {
    return component.canLockRepeater() and is_powered and faces_into_target_side;
}

/// Resolved state of a repeater under potential D-latch locking.
pub const LockedRepeaterState = struct {
    is_locked: bool,
    output_active: bool,
    front_signal: u4,

    /// When locked, a bedrock bar replaces the secondary redstone torch.
    pub fn hasBedrockLockBar(self: LockedRepeaterState) bool {
        return self.is_locked;
    }

    pub fn isActive(self: LockedRepeaterState) bool {
        return self.output_active;
    }

    pub fn getFrontSignal(self: LockedRepeaterState) u4 {
        return self.front_signal;
    }
};

/// Bedrock latch locking namespace & state handler.
/// Implements a 1-bit D-latch:
/// Data input (D) = back input signal
/// Lock / Enable (CLK/E) = side repeater or comparator powered
/// Output (Q) = front output state
pub const RepeaterBedrockLatchLocking = struct {
    is_locked: bool = false,
    output_active: bool = false,
    front_signal: u4 = 0,

    pub fn hasBedrockLockBar(self: RepeaterBedrockLatchLocking) bool {
        return self.is_locked;
    }

    /// Resolves D-latch state:
    /// When side_repeater_or_comparator_powered is true:
    /// - is_locked = true
    /// - Output is FROZEN to current_output_active (all back input changes ignored)
    /// When side_repeater_or_comparator_powered is false:
    /// - is_locked = false
    /// - Output follows back input (active if back_signal >= 1)
    pub fn resolveLockedRepeaterState(
        current_output_active: bool,
        side_repeater_or_comparator_powered: bool,
        back_signal_0_to_15: anytype,
    ) LockedRepeaterState {
        const is_locked = side_repeater_or_comparator_powered;
        const back_powered = switch (@TypeOf(back_signal_0_to_15)) {
            bool => back_signal_0_to_15,
            else => back_signal_0_to_15 >= 1,
        };

        const output_active = if (is_locked) current_output_active else back_powered;
        return .{
            .is_locked = is_locked,
            .output_active = output_active,
            .front_signal = if (output_active) 15 else 0,
        };
    }
};

/// Resolves D-latch repeater state.
pub fn resolveLockedRepeaterState(
    current_output_active: bool,
    side_repeater_or_comparator_powered: bool,
    back_signal_0_to_15: anytype,
) LockedRepeaterState {
    return RepeaterBedrockLatchLocking.resolveLockedRepeaterState(
        current_output_active,
        side_repeater_or_comparator_powered,
        back_signal_0_to_15,
    );
}

/// Generic helper to check whether a bedrock lock bar is active.
/// Accepts either a bool (`is_locked`) or any struct with an `is_locked` field.
pub fn hasBedrockLockBar(arg: anytype) bool {
    const T = @TypeOf(arg);
    if (T == bool) {
        return arg;
    } else if (@hasField(T, "is_locked")) {
        return arg.is_locked;
    } else {
        @compileError("hasBedrockLockBar requires a bool or an object with field is_locked");
    }
}

// ============================================================================
// 5. Pulse Length Extension
// ============================================================================

/// Pulse length extension mechanics.
/// In Minecraft redstone, repeaters act as pulse lengtheners:
/// A short pulse of 1 redstone tick entering a repeater set to N (1..4) redstone ticks
/// is stretched so the output stays active for at least N redstone ticks.
/// If the input pulse is already longer than N ticks, its full duration is preserved.
pub const PulseLengthExtension = struct {
    /// Returns the resulting output pulse duration in redstone ticks.
    pub fn stretchPulseDurationTicks(input_pulse_rticks: u8, repeater_delay_1_to_4: u3) u8 {
        if (input_pulse_rticks == 0) return 0;
        const delay: u8 = if (repeater_delay_1_to_4 < 1) 1 else if (repeater_delay_1_to_4 > 4) 4 else repeater_delay_1_to_4;
        return @max(input_pulse_rticks, delay);
    }

    /// Returns the resulting output pulse duration in engine game ticks (2x redstone ticks).
    pub fn stretchPulseDurationGameTicks(input_pulse_gticks: u16, repeater_delay_1_to_4: u3) u16 {
        if (input_pulse_gticks == 0) return 0;
        const delay_gticks: u16 = @as(u16, if (repeater_delay_1_to_4 < 1) 1 else if (repeater_delay_1_to_4 > 4) 4 else repeater_delay_1_to_4) * 2;
        return @max(input_pulse_gticks, delay_gticks);
    }
};

pub const stretchPulseDurationTicks = PulseLengthExtension.stretchPulseDurationTicks;
pub const stretchPulseDurationGameTicks = PulseLengthExtension.stretchPulseDurationGameTicks;

// ============================================================================
// 6. Full Discrete Repeater Simulation Engine
// ============================================================================

/// Horizontal cardinal facing directions for repeater orientation.
pub const HorizontalFacing = enum(u2) {
    north = 0,
    east = 1,
    south = 2,
    west = 3,

    pub fn opposite(self: HorizontalFacing) HorizontalFacing {
        const val: u3 = @intFromEnum(self);
        return @enumFromInt(@as(u2, @intCast((val + 2) % 4)));
    }

    pub fn left(self: HorizontalFacing) HorizontalFacing {
        const val: u3 = @intFromEnum(self);
        return @enumFromInt(@as(u2, @intCast((val + 3) % 4)));
    }

    pub fn right(self: HorizontalFacing) HorizontalFacing {
        const val: u3 = @intFromEnum(self);
        return @enumFromInt(@as(u2, @intCast((val + 1) % 4)));
    }

    pub fn back(self: HorizontalFacing) HorizontalFacing {
        return self.opposite();
    }
};

/// Complete state and simulation for a single Redstone Repeater block.
pub const RedstoneRepeater = struct {
    facing: HorizontalFacing = .north,
    delay_ticks: u3 = 1,
    is_locked: bool = false,
    output_active: bool = false,
    front_signal: u4 = 0,

    // Internal scheduled countdown for redstone delay pipeline
    scheduled_target_active: ?bool = null,
    ticks_until_transition: u8 = 0,

    pub fn init(facing: HorizontalFacing, delay_ticks_1_to_4: u3) RedstoneRepeater {
        const d: u3 = if (delay_ticks_1_to_4 < 1) 1 else if (delay_ticks_1_to_4 > 4) 4 else delay_ticks_1_to_4;
        return .{
            .facing = facing,
            .delay_ticks = d,
            .is_locked = false,
            .output_active = false,
            .front_signal = 0,
            .scheduled_target_active = null,
            .ticks_until_transition = 0,
        };
    }

    /// Cycles delay: 1 -> 2 -> 3 -> 4 -> 1.
    pub fn cycleDelay(self: *RedstoneRepeater) u3 {
        self.delay_ticks = cycleRepeaterDelay(self.delay_ticks);
        return self.delay_ticks;
    }

    /// True if repeater is locked with a bedrock bar.
    pub fn hasBedrockLockBar(self: RedstoneRepeater) bool {
        return self.is_locked;
    }

    /// Returns front output signal (15 or 0).
    pub fn getFrontOutput(self: RedstoneRepeater) u4 {
        return frontOutputSignal(self.output_active);
    }

    pub fn getDelayGameTicks(self: RedstoneRepeater) u8 {
        return delayRedstoneTicksToGameTicks(self.delay_ticks);
    }

    pub fn getDelaySeconds(self: RedstoneRepeater) f32 {
        return delayRedstoneTicksToSeconds(self.delay_ticks);
    }

    /// Steps the repeater through one discrete redstone tick (0.10s / 2 game ticks).
    pub fn tickRedstone(
        self: *RedstoneRepeater,
        back_signal_0_to_15: u4,
        side_repeater_or_comparator_powered: bool,
    ) void {
        self.is_locked = side_repeater_or_comparator_powered;

        // When locked, freeze state completely: countdown paused and output unchanged!
        if (self.is_locked) {
            return;
        }

        const input_powered = (back_signal_0_to_15 >= 1);

        // If no transition is queued and output differs from input, start transition
        if (self.scheduled_target_active == null) {
            if (self.output_active != input_powered) {
                self.scheduled_target_active = input_powered;
                self.ticks_until_transition = self.delay_ticks;
            }
        }

        // Advance 1 redstone tick of delay
        if (self.scheduled_target_active) |target| {
            if (self.ticks_until_transition > 1) {
                self.ticks_until_transition -= 1;
            } else {
                // Countdown reached 0: transition fires
                self.output_active = target;
                self.front_signal = frontOutputSignal(self.output_active);
                self.scheduled_target_active = null;
                self.ticks_until_transition = 0;

                // If input still differs from newly set output (e.g. pulse stretching),
                // schedule next transition
                if (self.output_active != input_powered) {
                    self.scheduled_target_active = input_powered;
                    self.ticks_until_transition = self.delay_ticks;
                }
            }
        }
    }
};

// ============================================================================
// Unit Tests (At least 12 comprehensive test blocks)
// ============================================================================

test "RepeaterRecipe: exact ingredients 3 stone, 2 torches, 1 dust crafts 1 repeater" {
    const output = craftRepeater(3, 2, 1);
    try std.testing.expectEqual(@as(u8, 1), output);
    try std.testing.expectEqual(@as(u8, 1), RepeaterRecipe.craftRepeater(3, 2, 1));
}

test "RepeaterRecipe: multi-batch crafting scales with bottleneck ingredient" {
    // 9 stone, 4 torches, 5 dust -> limited by torches (4 / 2 = 2 repeaters)
    const output1 = craftRepeater(9, 4, 5);
    try std.testing.expectEqual(@as(u8, 2), output1);

    // 12 stone, 10 torches, 3 dust -> limited by dust (3 / 1 = 3 repeaters)
    const output2 = craftRepeater(12, 10, 3);
    try std.testing.expectEqual(@as(u8, 3), output2);

    // 6 stone, 6 torches, 6 dust -> limited by stone (6 / 3 = 2 repeaters)
    const output3 = craftRepeater(6, 6, 6);
    try std.testing.expectEqual(@as(u8, 2), output3);
}

test "RepeaterRecipe: missing ingredients or cobblestone yields 0 repeaters" {
    // Missing ingredients
    try std.testing.expectEqual(@as(u8, 0), craftRepeater(2, 2, 1)); // Not enough stone
    try std.testing.expectEqual(@as(u8, 0), craftRepeater(3, 1, 1)); // Not enough torches
    try std.testing.expectEqual(@as(u8, 0), craftRepeater(3, 2, 0)); // No dust
    try std.testing.expectEqual(@as(u8, 0), craftRepeater(0, 0, 0));

    // Cobblestone is rejected
    try std.testing.expect(!RepeaterRecipe.canCraftWithCobblestone(64, 64, 64));
    try std.testing.expectEqual(@as(u8, 0), RepeaterRecipe.craftWithMaterial(.cobblestone, 3, 2, 1));
    try std.testing.expectEqual(@as(u8, 0), RepeaterRecipe.craftWithMaterial(.cobbled_deepslate, 3, 2, 1));
    try std.testing.expectEqual(@as(u8, 1), RepeaterRecipe.craftWithMaterial(.regular_stone, 3, 2, 1));
}

test "RepeaterDelaySetting: cycleRepeaterDelay cycles 1 -> 2 -> 3 -> 4 -> 1" {
    var delay: u3 = 1;
    delay = cycleRepeaterDelay(delay);
    try std.testing.expectEqual(@as(u3, 2), delay);
    delay = cycleRepeaterDelay(delay);
    try std.testing.expectEqual(@as(u3, 3), delay);
    delay = cycleRepeaterDelay(delay);
    try std.testing.expectEqual(@as(u3, 4), delay);
    delay = cycleRepeaterDelay(delay);
    try std.testing.expectEqual(@as(u3, 1), delay);
}

test "RepeaterDelaySetting: out-of-range inputs cycle cleanly to 1" {
    try std.testing.expectEqual(@as(u3, 1), cycleRepeaterDelay(0));
    try std.testing.expectEqual(@as(u3, 1), cycleRepeaterDelay(5));
    try std.testing.expectEqual(@as(u3, 1), cycleRepeaterDelay(7));
}

test "RepeaterDelaySetting: delay conversion to game ticks and seconds" {
    // 1 redstone tick = 2 game ticks = 0.10s
    try std.testing.expectEqual(@as(u8, 2), delayRedstoneTicksToGameTicks(1));
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), delayRedstoneTicksToSeconds(1), 0.001);

    // 2 redstone ticks = 4 game ticks = 0.20s
    try std.testing.expectEqual(@as(u8, 4), delayRedstoneTicksToGameTicks(2));
    try std.testing.expectApproxEqAbs(@as(f32, 0.20), delayRedstoneTicksToSeconds(2), 0.001);

    // 3 redstone ticks = 6 game ticks = 0.30s
    try std.testing.expectEqual(@as(u8, 6), delayRedstoneTicksToGameTicks(3));
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), delayRedstoneTicksToSeconds(3), 0.001);

    // 4 redstone ticks = 8 game ticks = 0.40s
    try std.testing.expectEqual(@as(u8, 8), delayRedstoneTicksToGameTicks(4));
    try std.testing.expectApproxEqAbs(@as(f32, 0.40), delayRedstoneTicksToSeconds(4), 0.001);
}

test "RepeaterDelaySetting: chain of repeaters sums delay correctly" {
    const delays = [_]u3{ 1, 4, 2, 3 }; // 1 + 4 + 2 + 3 = 10 redstone ticks
    try std.testing.expectEqual(@as(u32, 10), totalChainDelayRedstoneTicks(&delays));
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), totalChainDelaySeconds(&delays), 0.001);
}

test "SignalAmplificationAndDiode: weak signals 1..14 amplified to 15, 0 remains 0" {
    try std.testing.expectEqual(@as(u4, 0), frontOutputSignal(false));
    try std.testing.expectEqual(@as(u4, 15), frontOutputSignal(true));

    try std.testing.expectEqual(@as(u4, 0), amplifySignal(0));
    var signal: u4 = 1;
    while (signal <= 15) : (signal += 1) {
        try std.testing.expectEqual(@as(u4, 15), amplifySignal(signal));
        if (signal == 15) break;
    }
}

test "SignalAmplificationAndDiode: one-way diode prevents backward and side propagation" {
    try std.testing.expect(isOneWayDiode());
    try std.testing.expect(SignalAmplificationAndDiode.isOneWayDiode());
    try std.testing.expect(!SignalAmplificationAndDiode.canSignalPassBackward(15));
    try std.testing.expect(!SignalAmplificationAndDiode.canSignalPassBackward(1));
    try std.testing.expect(!SignalAmplificationAndDiode.canSideSignalConduct(15));
}

test "RepeaterBedrockLatchLocking: side repeater or comparator powers lock bar" {
    // Only repeater and comparator can lock
    try std.testing.expect(isSideLockActive(.repeater, true, true));
    try std.testing.expect(isSideLockActive(.comparator, true, true));

    // Unpowered repeater/comparator does NOT lock
    try std.testing.expect(!isSideLockActive(.repeater, false, true));
    try std.testing.expect(!isSideLockActive(.comparator, false, true));

    // Facing away does NOT lock
    try std.testing.expect(!isSideLockActive(.repeater, true, false));

    // Other components do NOT lock
    try std.testing.expect(!isSideLockActive(.redstone_wire, true, true));
    try std.testing.expect(!isSideLockActive(.redstone_torch, true, true));
    try std.testing.expect(!isSideLockActive(.redstone_block, true, true));
    try std.testing.expect(!isSideLockActive(.lever, true, true));
}

test "RepeaterBedrockLatchLocking: side alignment check calculates correct facing" {
    // Target repeater faces North
    // Left side is West. A component at West pointing East faces into target!
    try std.testing.expect(doesSideComponentFaceIntoRepeater(.north, .left, .east));
    try std.testing.expect(!doesSideComponentFaceIntoRepeater(.north, .left, .north));

    // Right side is East. A component at East pointing West faces into target!
    try std.testing.expect(doesSideComponentFaceIntoRepeater(.north, .right, .west));
    try std.testing.expect(!doesSideComponentFaceIntoRepeater(.north, .right, .south));
}

test "RepeaterBedrockLatchLocking: resolveLockedRepeaterState freezes active ON state" {
    // Repeater is ON (current = true).
    // Side lock becomes active (side_repeater_or_comparator_powered = true).
    // Back signal drops to 0. Output MUST remain frozen at ON (15).
    const locked_state = resolveLockedRepeaterState(true, true, 0);
    try std.testing.expect(locked_state.is_locked);
    try std.testing.expect(locked_state.output_active);
    try std.testing.expectEqual(@as(u4, 15), locked_state.front_signal);
    try std.testing.expect(locked_state.hasBedrockLockBar());

    // Once unlocked, back signal 0 turns output OFF
    const unlocked_state = resolveLockedRepeaterState(true, false, 0);
    try std.testing.expect(!unlocked_state.is_locked);
    try std.testing.expect(!unlocked_state.output_active);
    try std.testing.expectEqual(@as(u4, 0), unlocked_state.front_signal);
    try std.testing.expect(!unlocked_state.hasBedrockLockBar());
}

test "RepeaterBedrockLatchLocking: resolveLockedRepeaterState freezes inactive OFF state" {
    // Repeater is OFF (current = false).
    // Side lock becomes active. Back signal rises to 15. Output MUST stay frozen at OFF (0).
    const locked_state = resolveLockedRepeaterState(false, true, 15);
    try std.testing.expect(locked_state.is_locked);
    try std.testing.expect(!locked_state.output_active);
    try std.testing.expectEqual(@as(u4, 0), locked_state.front_signal);
    try std.testing.expect(locked_state.hasBedrockLockBar());

    // Once unlocked, back signal 15 turns output ON
    const unlocked_state = resolveLockedRepeaterState(false, false, 15);
    try std.testing.expect(!unlocked_state.is_locked);
    try std.testing.expect(unlocked_state.output_active);
    try std.testing.expectEqual(@as(u4, 15), unlocked_state.front_signal);
    try std.testing.expect(!unlocked_state.hasBedrockLockBar());
}

test "RepeaterBedrockLatchLocking: hasBedrockLockBar returns true only when locked" {
    // Direct boolean
    try std.testing.expect(hasBedrockLockBar(true));
    try std.testing.expect(!hasBedrockLockBar(false));

    // Via LockedRepeaterState struct
    const state_locked = LockedRepeaterState{ .is_locked = true, .output_active = true, .front_signal = 15 };
    const state_unlocked = LockedRepeaterState{ .is_locked = false, .output_active = true, .front_signal = 15 };
    try std.testing.expect(hasBedrockLockBar(state_locked));
    try std.testing.expect(!hasBedrockLockBar(state_unlocked));
    try std.testing.expect(state_locked.hasBedrockLockBar());
    try std.testing.expect(!state_unlocked.hasBedrockLockBar());

    // Via RedstoneRepeater struct
    var rep = RedstoneRepeater.init(.north, 1);
    try std.testing.expect(!rep.hasBedrockLockBar());
    rep.is_locked = true;
    try std.testing.expect(rep.hasBedrockLockBar());
    try std.testing.expect(hasBedrockLockBar(rep));
}

test "PulseLengthExtension: 1-tick pulse extended to repeater delay (1..4 ticks)" {
    // A 1-tick pulse entering a repeater set to 1..4 ticks is stretched to at least 1..4 ticks
    try std.testing.expectEqual(@as(u8, 1), stretchPulseDurationTicks(1, 1));
    try std.testing.expectEqual(@as(u8, 2), stretchPulseDurationTicks(1, 2));
    try std.testing.expectEqual(@as(u8, 3), stretchPulseDurationTicks(1, 3));
    try std.testing.expectEqual(@as(u8, 4), stretchPulseDurationTicks(1, 4));

    // Zero input pulse produces 0
    try std.testing.expectEqual(@as(u8, 0), stretchPulseDurationTicks(0, 3));
}

test "PulseLengthExtension: pulse longer than delay retains full duration" {
    // A 5-tick pulse through a 2-tick repeater stays 5 ticks
    try std.testing.expectEqual(@as(u8, 5), stretchPulseDurationTicks(5, 2));
    // A 3-tick pulse through a 1-tick repeater stays 3 ticks
    try std.testing.expectEqual(@as(u8, 3), stretchPulseDurationTicks(3, 1));

    // Game tick conversion test: 2 game ticks (1 redstone tick) through a 4-tick repeater -> 8 game ticks
    try std.testing.expectEqual(@as(u16, 8), stretchPulseDurationGameTicks(2, 4));
}

test "RedstoneRepeater: simulation 1-to-4 tick propagation delay for rising and falling edges" {
    // Create repeater with 2 redstone ticks delay (4 game ticks)
    var rep = RedstoneRepeater.init(.north, 2);
    try std.testing.expectEqual(@as(u4, 0), rep.getFrontOutput());

    // Tick 1: Apply input 15
    rep.tickRedstone(15, false);
    try std.testing.expectEqual(@as(u4, 0), rep.getFrontOutput()); // Delay tick 1 of 2

    // Tick 2: Input remains 15
    rep.tickRedstone(15, false);
    try std.testing.expectEqual(@as(u4, 15), rep.getFrontOutput()); // Output activates after 2 ticks!

    // Tick 3: Input drops to 0
    rep.tickRedstone(0, false);
    try std.testing.expectEqual(@as(u4, 15), rep.getFrontOutput()); // Output stays on during falling delay

    // Tick 4: Input remains 0
    rep.tickRedstone(0, false);
    try std.testing.expectEqual(@as(u4, 0), rep.getFrontOutput()); // Output turns off after 2 ticks!
}

test "RedstoneRepeater: simulation 1-bit D-latch freezes output across ticks until unlocked" {
    var rep = RedstoneRepeater.init(.north, 1);

    // Power up repeater (1 tick delay)
    rep.tickRedstone(15, false);
    try std.testing.expectEqual(@as(u4, 15), rep.getFrontOutput());

    // Lock repeater while ON
    rep.tickRedstone(0, true);
    try std.testing.expect(rep.hasBedrockLockBar());
    try std.testing.expectEqual(@as(u4, 15), rep.getFrontOutput());

    // Multiple ticks pass with input = 0 while locked; output must remain 15!
    for (0..5) |_| {
        rep.tickRedstone(0, true);
        try std.testing.expectEqual(@as(u4, 15), rep.getFrontOutput());
    }

    // Unlock repeater with input = 0; output turns off
    rep.tickRedstone(0, false);
    try std.testing.expect(!rep.hasBedrockLockBar());
    try std.testing.expectEqual(@as(u4, 0), rep.getFrontOutput());
}

test "RedstoneRepeater: simulation pulse stretching extends short input pulse" {
    // 3-tick delay repeater
    var rep = RedstoneRepeater.init(.north, 3);

    // Tick 1: 1-tick pulse arrives (input 15)
    rep.tickRedstone(15, false);
    try std.testing.expectEqual(@as(u4, 0), rep.getFrontOutput());

    // Tick 2: Input drops back to 0 immediately
    rep.tickRedstone(0, false);
    try std.testing.expectEqual(@as(u4, 0), rep.getFrontOutput());

    // Tick 3: Still waiting to activate
    rep.tickRedstone(0, false);
    try std.testing.expectEqual(@as(u4, 15), rep.getFrontOutput()); // Output turns ON at tick 3!

    // Tick 4: Output remains ON (pulse stretching)
    rep.tickRedstone(0, false);
    try std.testing.expectEqual(@as(u4, 15), rep.getFrontOutput());

    // Tick 5: Output remains ON
    rep.tickRedstone(0, false);
    try std.testing.expectEqual(@as(u4, 15), rep.getFrontOutput());

    // Tick 6: Output turns OFF after 3 ticks of active duration!
    rep.tickRedstone(0, false);
    try std.testing.expectEqual(@as(u4, 0), rep.getFrontOutput());
}
