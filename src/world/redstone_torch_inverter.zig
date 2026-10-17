const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Game tick duration in seconds (1/20 second = 0.05s).
pub const game_tick_duration_seconds: f32 = 0.05;

/// Redstone tick duration in seconds (1/10 second = 0.10s = 2 game ticks).
pub const redstone_tick_duration_seconds: f32 = 0.10;

/// Number of game ticks per redstone tick (2 game ticks).
pub const game_ticks_per_redstone_tick: u8 = 2;

/// Redstone torch state transition delay in game ticks (2 game ticks = 1 redstone tick).
pub const torch_inversion_delay_game_ticks: u8 = 2;

/// Redstone torch state transition delay in redstone ticks (1 redstone tick).
pub const torch_inversion_delay_redstone_ticks: u8 = 1;

/// Maximum redstone signal strength emitted by an active redstone torch.
pub const max_redstone_signal: u4 = 15;

/// Minimum redstone signal strength (inactive / unpowered).
pub const min_redstone_signal: u4 = 0;

/// Light level emitted by an active (lit) redstone torch.
pub const lit_torch_light_level: u4 = 7;

/// Light level emitted by an inactive / burned-out (unlit) redstone torch.
pub const unlit_torch_light_level: u4 = 0;

/// Maximum extinguishes (toggles from ON to OFF) permitted before burnout triggers.
pub const max_toggles_before_burnout: u4 = 8;

/// Duration of the sliding burnout window in game ticks (60 ticks = 3.0 seconds).
pub const burnout_window_ticks: u8 = 60;

/// Duration of the sliding burnout window in seconds (3.0 seconds).
pub const burnout_window_seconds: f32 = 3.0;

// ============================================================================
// Spatial & Routing Enums
// ============================================================================

/// The attachment face mounting a redstone torch.
pub const AttachmentFace = enum {
    floor,
    wall_north,
    wall_south,
    wall_east,
    wall_west,

    pub fn isFloor(self: AttachmentFace) bool {
        return self == .floor;
    }

    pub fn isWall(self: AttachmentFace) bool {
        return self != .floor;
    }

    /// Offset from torch position to the solid block that supports it.
    pub fn getSupportingBlockOffset(self: AttachmentFace) [3]i32 {
        return switch (self) {
            .floor => .{ 0, -1, 0 },
            .wall_north => .{ 0, 0, -1 },
            .wall_south => .{ 0, 0, 1 },
            .wall_east => .{ 1, 0, 0 },
            .wall_west => .{ -1, 0, 0 },
        };
    }

    /// Cardinal or vertical direction toward the supporting attachment block.
    pub fn getAttachmentDirection(self: AttachmentFace) Direction {
        return switch (self) {
            .floor => .down,
            .wall_north => .north,
            .wall_south => .south,
            .wall_east => .east,
            .wall_west => .west,
        };
    }
};

/// 3D cardinal and vertical directions.
pub const Direction = enum {
    up,
    down,
    north,
    south,
    east,
    west,

    pub fn getOffset(self: Direction) [3]i32 {
        return switch (self) {
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
        };
    }

    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .up => .down,
            .down => .up,
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }
};

/// Degree of redstone power transmitted to an adjacent target block/component.
pub const PowerLevel = enum {
    none,
    weak,
    strong,
};

// ============================================================================
// Standalone Math & Inversion Helpers
// ============================================================================

/// Computes the steady-state redstone output signal for a redstone torch given
/// whether its supporting attachment block is powered (NOT gate logic).
/// Accepts either a boolean (`attachment_block_powered`) or a `RedstoneTorchInversion` instance.
pub fn computeTorchOutputSignal(arg: anytype) u4 {
    const T = @TypeOf(arg);
    if (T == bool) {
        return if (arg) min_redstone_signal else max_redstone_signal;
    } else if (T == RedstoneTorchInversion or T == *const RedstoneTorchInversion or T == *RedstoneTorchInversion) {
        return arg.output_signal;
    } else {
        @compileError("computeTorchOutputSignal expects bool or RedstoneTorchInversion");
    }
}

/// Computes steady-state output signal accounting for burnout status.
pub fn computeTorchOutputSignalWithBurnout(attachment_block_powered: bool, is_burned_out: bool) u4 {
    if (is_burned_out) return min_redstone_signal;
    return computeTorchOutputSignal(attachment_block_powered);
}

/// Returns the light level emitted based on lit state.
pub fn computeTorchLightLevel(is_lit: bool) u4 {
    return if (is_lit) lit_torch_light_level else unlit_torch_light_level;
}

/// Whether a redstone torch strongly powers the solid block directly above it.
/// Accepts a boolean (`is_lit`), `TorchPowerRouting`, or `RedstoneTorchInversion`.
pub fn powersBlockAboveStrongly(arg: anytype) bool {
    const T = @TypeOf(arg);
    if (T == bool) {
        return arg;
    } else if (T == TorchPowerRouting or T == *const TorchPowerRouting or T == *TorchPowerRouting) {
        return arg.is_lit;
    } else if (T == RedstoneTorchInversion or T == *const RedstoneTorchInversion or T == *RedstoneTorchInversion) {
        return arg.is_lit;
    } else {
        @compileError("powersBlockAboveStrongly expects bool, TorchPowerRouting, or RedstoneTorchInversion");
    }
}

/// A redstone torch never directly powers its own supporting attachment block.
pub fn powersAttachmentBlock() bool {
    return false;
}

// ============================================================================
// Torch Power Routing
// ============================================================================

/// Models the directional power distribution of a redstone torch.
/// - Strongly powers the solid block directly ABOVE it (`powersBlockAboveStrongly() == true`).
/// - Weakly powers adjacent redstone dust / components in all directions except the attachment block.
/// - Does NOT power its attachment block (`powersAttachmentBlock() == false`).
pub const TorchPowerRouting = struct {
    attachment: AttachmentFace = .floor,
    is_lit: bool = true,

    pub fn init(attachment: AttachmentFace, is_lit: bool) TorchPowerRouting {
        return .{
            .attachment = attachment,
            .is_lit = is_lit,
        };
    }

    /// A lit redstone torch strongly powers the block directly above it.
    pub fn powersBlockAboveStrongly(self: TorchPowerRouting) bool {
        return self.is_lit;
    }

    /// A redstone torch never directly powers the block to which it is attached.
    pub fn powersAttachmentBlock(self: TorchPowerRouting) bool {
        _ = self;
        return false;
    }

    /// Returns the power level delivered in a given direction.
    pub fn getPowerLevelTo(self: TorchPowerRouting, dir: Direction) PowerLevel {
        if (!self.is_lit) return .none;
        if (dir == .up) return .strong;
        if (dir == self.attachment.getAttachmentDirection()) return .none;
        return .weak;
    }

    /// Returns whether any redstone power (weak or strong) is transmitted in direction `dir`.
    pub fn canPowerDirection(self: TorchPowerRouting, dir: Direction) bool {
        return self.getPowerLevelTo(dir) != .none;
    }

    /// Evaluates if an external redstone wire loop routes power back into the supporting block.
    pub fn evaluateFeedbackLoop(self: TorchPowerRouting, wire_connected_to_attachment_block: bool) bool {
        return self.is_lit and wire_connected_to_attachment_block;
    }
};

// ============================================================================
// Torch Burnout Protection
// ============================================================================

/// Sliding-window burnout protection:
/// If a redstone torch toggles from ON to OFF 8 or more times within a 60-game-tick
/// (3.0s) window, it burns out, emits smoke and a hiss sound, and stays OFF until
/// the window cools down or receives a block update.
pub const TorchBurnoutProtection = struct {
    pub const max_toggles_before_burnout: u4 = 8;
    pub const burnout_window_ticks: u8 = 60;
    pub const burnout_window_seconds: f32 = 3.0;

    /// History of extinguish (ON -> OFF) game tick timestamps.
    toggle_history: [@This().max_toggles_before_burnout]u64 = [_]u64{0} ** @This().max_toggles_before_burnout,
    history_count: usize = 0,
    history_head: usize = 0,

    is_burned_out: bool = false,
    smoke_puff_particles: bool = false,
    plays_hiss_sound: bool = false,
    burnout_tick: ?u64 = null,

    pub fn isBurnedOut(self: TorchBurnoutProtection) bool {
        return self.is_burned_out;
    }

    /// Prunes events older than `burnout_window_ticks` relative to `current_game_tick`.
    pub fn pruneOldEvents(self: *TorchBurnoutProtection, current_game_tick: u64) void {
        while (self.history_count > 0) {
            const oldest_tick = self.toggle_history[self.history_head];
            if (current_game_tick >= oldest_tick and (current_game_tick - oldest_tick) >= @This().burnout_window_ticks) {
                self.history_head = (self.history_head + 1) % @This().max_toggles_before_burnout;
                self.history_count -= 1;
            } else {
                break;
            }
        }
    }

    /// Returns the number of extinguishing events currently inside the sliding 60-tick window.
    pub fn countActiveFlips(self: TorchBurnoutProtection, current_game_tick: u64) usize {
        var count: usize = 0;
        var i: usize = 0;
        while (i < self.history_count) : (i += 1) {
            const idx = (self.history_head + i) % @This().max_toggles_before_burnout;
            const event_tick = self.toggle_history[idx];
            if (current_game_tick >= event_tick and (current_game_tick - event_tick) < @This().burnout_window_ticks) {
                count += 1;
            }
        }
        return count;
    }

    /// Records an extinguishing toggle (transition from ON to OFF) at `current_game_tick`.
    /// Returns true if this event triggered burnout.
    pub fn recordExtinguish(self: *TorchBurnoutProtection, current_game_tick: u64) bool {
        self.pruneOldEvents(current_game_tick);

        if (self.history_count < @This().max_toggles_before_burnout) {
            const idx = (self.history_head + self.history_count) % @This().max_toggles_before_burnout;
            self.toggle_history[idx] = current_game_tick;
            self.history_count += 1;
        } else {
            self.toggle_history[self.history_head] = current_game_tick;
            self.history_head = (self.history_head + 1) % @This().max_toggles_before_burnout;
        }

        if (self.history_count >= @This().max_toggles_before_burnout) {
            self.is_burned_out = true;
            self.smoke_puff_particles = true;
            self.plays_hiss_sound = true;
            self.burnout_tick = current_game_tick;
            return true;
        }
        return false;
    }

    /// Advances simulation time by 1 game tick.
    pub fn tick(self: *TorchBurnoutProtection, current_game_tick: u64) void {
        if (self.burnout_tick) |bt| {
            if (current_game_tick > bt) {
                self.smoke_puff_particles = false;
                self.plays_hiss_sound = false;
            }
        }

        self.pruneOldEvents(current_game_tick);

        // Once the sliding window cools down (events age out), burnout is cleared.
        if (self.is_burned_out and self.history_count < @This().max_toggles_before_burnout) {
            self.is_burned_out = false;
        }
    }

    /// Processes an external block update, allowing a burned-out torch to recover.
    pub fn onBlockUpdate(self: *TorchBurnoutProtection, current_game_tick: u64) bool {
        self.pruneOldEvents(current_game_tick);
        if (self.is_burned_out) {
            self.is_burned_out = false;
            return true;
        }
        return false;
    }

    /// Resets all burnout tracking state.
    pub fn reset(self: *TorchBurnoutProtection) void {
        self.history_count = 0;
        self.history_head = 0;
        self.is_burned_out = false;
        self.smoke_puff_particles = false;
        self.plays_hiss_sound = false;
        self.burnout_tick = null;
    }
};

// ============================================================================
// Redstone Torch Inversion State Machine
// ============================================================================

/// Full redstone torch simulation model with 2-game-tick inversion delay,
/// burnout protection, and directional power emission.
pub const RedstoneTorchInversion = struct {
    attachment: AttachmentFace = .floor,
    attachment_block_powered: bool = false,
    is_lit: bool = true,
    output_signal: u4 = max_redstone_signal,
    light_level: u4 = lit_torch_light_level,

    /// Remaining game ticks before the pending state change occurs.
    delay_ticks_remaining: u8 = 0,
    pending_lit_state: ?bool = null,

    burnout: TorchBurnoutProtection = .{},
    current_game_tick: u64 = 0,

    pub fn init(attachment: AttachmentFace, initial_attachment_powered: bool) RedstoneTorchInversion {
        const lit = !initial_attachment_powered;
        return .{
            .attachment = attachment,
            .attachment_block_powered = initial_attachment_powered,
            .is_lit = lit,
            .output_signal = if (lit) max_redstone_signal else min_redstone_signal,
            .light_level = if (lit) lit_torch_light_level else unlit_torch_light_level,
            .delay_ticks_remaining = 0,
            .pending_lit_state = null,
            .burnout = .{},
            .current_game_tick = 0,
        };
    }

    /// Updates whether the supporting attachment block is receiving redstone power.
    /// Schedules a state flip with a 2-game-tick (1 redstone tick = 0.10s) delay.
    pub fn setAttachmentBlockPowered(self: *RedstoneTorchInversion, powered: bool) void {
        self.attachment_block_powered = powered;
        const target_lit = !powered;

        if (self.burnout.isBurnedOut()) {
            // A burned out torch stays OFF until cooled down or updated.
            if (target_lit) {
                // Cannot turn on while burned out
                self.pending_lit_state = null;
                self.delay_ticks_remaining = 0;
                return;
            }
        }

        if (target_lit != self.is_lit) {
            // If already pending for this target state, do not reset the active countdown!
            if (self.pending_lit_state == target_lit) {
                return;
            }
            // Schedule inversion in 2 game ticks (1 redstone tick)
            self.pending_lit_state = target_lit;
            self.delay_ticks_remaining = torch_inversion_delay_game_ticks;
        } else {
            // Signal returned to match current state before delay elapsed (glitch suppression)
            self.pending_lit_state = null;
            self.delay_ticks_remaining = 0;
        }
    }

    /// Advances the torch simulation by 1 game tick (0.05 seconds).
    pub fn tickGame(self: *RedstoneTorchInversion) void {
        self.current_game_tick += 1;
        self.burnout.tick(self.current_game_tick);

        if (self.burnout.isBurnedOut()) {
            self.is_lit = false;
            self.output_signal = min_redstone_signal;
            self.light_level = unlit_torch_light_level;
            self.pending_lit_state = null;
            self.delay_ticks_remaining = 0;
            return;
        }

        if (self.delay_ticks_remaining > 0) {
            self.delay_ticks_remaining -= 1;
            if (self.delay_ticks_remaining == 0 and self.pending_lit_state != null) {
                const target = self.pending_lit_state.?;
                self.pending_lit_state = null;

                if (target != self.is_lit) {
                    if (!target) {
                        // Extinguish toggle (ON -> OFF)
                        const burned = self.burnout.recordExtinguish(self.current_game_tick);
                        if (burned) {
                            self.is_lit = false;
                            self.output_signal = min_redstone_signal;
                            self.light_level = unlit_torch_light_level;
                            return;
                        }
                    }

                    self.is_lit = target;
                    self.output_signal = if (target) max_redstone_signal else min_redstone_signal;
                    self.light_level = if (target) lit_torch_light_level else unlit_torch_light_level;
                }
            }
        }
    }

    /// Advances the torch simulation by 1 redstone tick (2 game ticks = 0.10 seconds).
    pub fn tickRedstone(self: *RedstoneTorchInversion) void {
        self.tickGame();
        self.tickGame();
    }

    /// Notifies the torch of an adjacent block update.
    pub fn triggerBlockUpdate(self: *RedstoneTorchInversion) void {
        const recovered = self.burnout.onBlockUpdate(self.current_game_tick);
        _ = recovered;
        // Re-evaluate target state
        self.setAttachmentBlockPowered(self.attachment_block_powered);
    }

    /// Returns the current redstone output signal level.
    pub fn computeTorchOutputSignal(self: RedstoneTorchInversion) u4 {
        return self.output_signal;
    }

    /// Returns whether the solid block directly above is strongly powered.
    pub fn powersBlockAboveStrongly(self: RedstoneTorchInversion) bool {
        return self.is_lit;
    }

    /// A redstone torch never powers its attachment block directly.
    pub fn powersAttachmentBlock(self: RedstoneTorchInversion) bool {
        _ = self;
        return false;
    }

    /// Returns whether this torch is currently burned out.
    pub fn isBurnedOut(self: RedstoneTorchInversion) bool {
        return self.burnout.isBurnedOut();
    }

    /// Gets power routing descriptor for this torch.
    pub fn getRouting(self: RedstoneTorchInversion) TorchPowerRouting {
        return TorchPowerRouting.init(self.attachment, self.is_lit);
    }
};

// ============================================================================
// Vertical Torch Tower Transmission
// ============================================================================

/// Computes the transmission delay of a vertical torch tower in game ticks
/// (each torch introduces 1 redstone tick = 2 game ticks = 0.10s delay).
pub fn computeTorchTowerDelayTicks(torch_count: u8) u16 {
    return @as(u16, torch_count) * game_ticks_per_redstone_tick;
}

/// Computes the transmission delay in seconds (0.10s per torch).
pub fn computeTorchTowerDelaySeconds(torch_count: u8) f32 {
    return @as(f32, @floatFromInt(torch_count)) * redstone_tick_duration_seconds;
}

/// A vertical torch tower inverts polarity when torch count is odd, and preserves it when even.
pub fn isTowerPolarityInverted(torch_count: u8) bool {
    return (torch_count % 2) != 0;
}

/// Computes the steady-state boolean output of a vertical torch tower given the base input.
pub fn computeTorchTowerOutput(input_signal_is_powered: bool, torch_count: u8) bool {
    if (torch_count == 0) return input_signal_is_powered;
    return if (isTowerPolarityInverted(torch_count)) !input_signal_is_powered else input_signal_is_powered;
}

/// Computes the steady-state redstone signal (15 or 0) of a vertical torch tower.
pub fn computeTorchTowerOutputSignal(input_signal_is_powered: bool, torch_count: u8) u4 {
    return if (computeTorchTowerOutput(input_signal_is_powered, torch_count)) max_redstone_signal else min_redstone_signal;
}

/// Simulates a multi-tier vertical torch tower consisting of alternating
/// solid_block -> redstone_torch -> solid_block -> redstone_torch ...
pub const VerticalTorchTower = struct {
    pub const max_supported_torches: usize = 32;

    torch_count: u8,
    torches: [max_supported_torches]RedstoneTorchInversion,
    base_input_powered: bool,

    pub fn init(torch_count: u8, initial_input_powered: bool) VerticalTorchTower {
        std.debug.assert(torch_count <= max_supported_torches);

        var self = VerticalTorchTower{
            .torch_count = torch_count,
            .torches = undefined,
            .base_input_powered = initial_input_powered,
        };

        var current_input = initial_input_powered;
        var i: usize = 0;
        while (i < torch_count) : (i += 1) {
            self.torches[i] = RedstoneTorchInversion.init(.floor, current_input);
            // The block above this torch is strongly powered by the torch if the torch is lit
            current_input = self.torches[i].is_lit;
        }

        return self;
    }

    /// Sets the redstone power state fed into the base solid block of the tower.
    pub fn setInput(self: *VerticalTorchTower, powered: bool) void {
        self.base_input_powered = powered;
        if (self.torch_count > 0) {
            self.torches[0].setAttachmentBlockPowered(powered);
        }
    }

    /// Advances the simulation by 1 game tick across all tiers of the tower.
    pub fn tickGame(self: *VerticalTorchTower) void {
        if (self.torch_count == 0) return;

        // 1. Tick all torches in this game tick
        var i: usize = 0;
        while (i < self.torch_count) : (i += 1) {
            self.torches[i].tickGame();
        }

        // 2. Feed the updated block states to the next torch level
        i = 0;
        while (i + 1 < self.torch_count) : (i += 1) {
            const block_powered = self.torches[i].powersBlockAboveStrongly();
            self.torches[i + 1].setAttachmentBlockPowered(block_powered);
        }
    }

    /// Advances the simulation by 1 redstone tick (2 game ticks).
    pub fn tickRedstone(self: *VerticalTorchTower) void {
        self.tickGame();
        self.tickGame();
    }

    /// Returns whether the top torch in the tower is currently lit.
    pub fn getTopTorchLit(self: VerticalTorchTower) bool {
        if (self.torch_count == 0) return self.base_input_powered;
        return self.torches[self.torch_count - 1].is_lit;
    }

    /// Returns the redstone signal level emitted by the top of the tower.
    pub fn getOutputSignal(self: VerticalTorchTower) u4 {
        if (self.torch_count == 0) return if (self.base_input_powered) 15 else 0;
        return self.torches[self.torch_count - 1].computeTorchOutputSignal();
    }

    /// Checks if all torches in the tower have completed their scheduled transitions.
    pub fn isSettled(self: VerticalTorchTower) bool {
        var i: usize = 0;
        while (i < self.torch_count) : (i += 1) {
            if (self.torches[i].delay_ticks_remaining > 0) return false;
        }
        return true;
    }

    /// Static alias for computeTorchTowerDelayTicks
    pub fn computeTorchTowerDelayTicks(torch_count: u8) u16 {
        return @as(u16, torch_count) * game_ticks_per_redstone_tick;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "RedstoneTorchInversion: NOT gate truth table and computeTorchOutputSignal" {
    // Unpowered input -> full 15 signal, 7 light level
    try std.testing.expectEqual(@as(u4, 15), computeTorchOutputSignal(false));
    try std.testing.expectEqual(@as(u4, 7), computeTorchLightLevel(true));

    // Powered input -> 0 signal, 0 light level
    try std.testing.expectEqual(@as(u4, 0), computeTorchOutputSignal(true));
    try std.testing.expectEqual(@as(u4, 0), computeTorchLightLevel(false));

    // Burnout logic
    try std.testing.expectEqual(@as(u4, 15), computeTorchOutputSignalWithBurnout(false, false));
    try std.testing.expectEqual(@as(u4, 0), computeTorchOutputSignalWithBurnout(false, true));
    try std.testing.expectEqual(@as(u4, 0), computeTorchOutputSignalWithBurnout(true, false));
    try std.testing.expectEqual(@as(u4, 0), computeTorchOutputSignalWithBurnout(true, true));
}

test "RedstoneTorchInversion: initial state from floor and wall attachment" {
    const floor_torch = RedstoneTorchInversion.init(.floor, false);
    try std.testing.expect(floor_torch.attachment.isFloor());
    try std.testing.expect(!floor_torch.attachment.isWall());
    try std.testing.expectEqual([3]i32{ 0, -1, 0 }, floor_torch.attachment.getSupportingBlockOffset());
    try std.testing.expectEqual(Direction.down, floor_torch.attachment.getAttachmentDirection());
    try std.testing.expect(floor_torch.is_lit);
    try std.testing.expectEqual(@as(u4, 15), floor_torch.output_signal);
    try std.testing.expectEqual(@as(u4, 7), floor_torch.light_level);

    const wall_torch = RedstoneTorchInversion.init(.wall_north, true);
    try std.testing.expect(!wall_torch.attachment.isFloor());
    try std.testing.expect(wall_torch.attachment.isWall());
    try std.testing.expectEqual([3]i32{ 0, 0, -1 }, wall_torch.attachment.getSupportingBlockOffset());
    try std.testing.expectEqual(Direction.north, wall_torch.attachment.getAttachmentDirection());
    try std.testing.expect(!wall_torch.is_lit);
    try std.testing.expectEqual(@as(u4, 0), wall_torch.output_signal);
    try std.testing.expectEqual(@as(u4, 0), wall_torch.light_level);
}

test "RedstoneTorchInversion: 2-game-tick (1 redstone tick / 0.10s) delay when powering attachment block" {
    var torch = RedstoneTorchInversion.init(.floor, false);
    try std.testing.expect(torch.is_lit);
    try std.testing.expectEqual(@as(u4, 15), torch.computeTorchOutputSignal());

    // Power the attachment block
    torch.setAttachmentBlockPowered(true);
    try std.testing.expectEqual(@as(u8, 2), torch.delay_ticks_remaining);
    try std.testing.expect(torch.is_lit); // still lit immediately

    // Game tick 1 (0.05s)
    torch.tickGame();
    try std.testing.expectEqual(@as(u8, 1), torch.delay_ticks_remaining);
    try std.testing.expect(torch.is_lit); // still lit after 1 game tick
    try std.testing.expectEqual(@as(u4, 15), torch.computeTorchOutputSignal());

    // Game tick 2 (0.10s)
    torch.tickGame();
    try std.testing.expectEqual(@as(u8, 0), torch.delay_ticks_remaining);
    try std.testing.expect(!torch.is_lit); // turns OFF after 2 game ticks (1 redstone tick)
    try std.testing.expectEqual(@as(u4, 0), torch.computeTorchOutputSignal());
    try std.testing.expectEqual(@as(u4, 0), torch.light_level);
}

test "RedstoneTorchInversion: 2-game-tick (1 redstone tick / 0.10s) delay when unpowering attachment block" {
    var torch = RedstoneTorchInversion.init(.floor, true);
    try std.testing.expect(!torch.is_lit);
    try std.testing.expectEqual(@as(u4, 0), torch.computeTorchOutputSignal());

    // Unpower the attachment block
    torch.setAttachmentBlockPowered(false);
    try std.testing.expectEqual(@as(u8, 2), torch.delay_ticks_remaining);
    try std.testing.expect(!torch.is_lit);

    // Game tick 1
    torch.tickGame();
    try std.testing.expectEqual(@as(u8, 1), torch.delay_ticks_remaining);
    try std.testing.expect(!torch.is_lit);

    // Game tick 2
    torch.tickGame();
    try std.testing.expectEqual(@as(u8, 0), torch.delay_ticks_remaining);
    try std.testing.expect(torch.is_lit); // turns ON after 2 game ticks
    try std.testing.expectEqual(@as(u4, 15), torch.computeTorchOutputSignal());
    try std.testing.expectEqual(@as(u4, 7), torch.light_level);
}

test "RedstoneTorchInversion: tickRedstone advances by 2 game ticks (0.10s)" {
    var torch = RedstoneTorchInversion.init(.floor, false);
    try std.testing.expect(torch.is_lit);

    torch.setAttachmentBlockPowered(true);
    torch.tickRedstone(); // 1 redstone tick = 2 game ticks
    try std.testing.expect(!torch.is_lit);
    try std.testing.expectEqual(@as(u4, 0), torch.computeTorchOutputSignal());

    torch.setAttachmentBlockPowered(false);
    torch.tickRedstone();
    try std.testing.expect(torch.is_lit);
    try std.testing.expectEqual(@as(u4, 15), torch.computeTorchOutputSignal());
}

test "RedstoneTorchInversion: glitch pulse filtering (sub-2-tick pulses canceled)" {
    var torch = RedstoneTorchInversion.init(.floor, false);
    try std.testing.expect(torch.is_lit);

    // Power pulse lasting only 1 game tick
    torch.setAttachmentBlockPowered(true);
    try std.testing.expectEqual(@as(u8, 2), torch.delay_ticks_remaining);

    torch.tickGame(); // Tick 1: 1 tick remaining
    try std.testing.expectEqual(@as(u8, 1), torch.delay_ticks_remaining);

    // Power drops back to false before tick 2
    torch.setAttachmentBlockPowered(false);
    try std.testing.expectEqual(@as(u8, 0), torch.delay_ticks_remaining);
    try std.testing.expect(torch.pending_lit_state == null);

    torch.tickGame(); // Tick 2: torch was not extinguished
    try std.testing.expect(torch.is_lit);
    try std.testing.expectEqual(@as(u4, 15), torch.computeTorchOutputSignal());
}

test "TorchPowerRouting: lit torch strongly powers solid block directly above" {
    const lit_routing = TorchPowerRouting.init(.floor, true);
    try std.testing.expect(lit_routing.powersBlockAboveStrongly());
    try std.testing.expectEqual(PowerLevel.strong, lit_routing.getPowerLevelTo(.up));

    const unlit_routing = TorchPowerRouting.init(.floor, false);
    try std.testing.expect(!unlit_routing.powersBlockAboveStrongly());
    try std.testing.expectEqual(PowerLevel.none, unlit_routing.getPowerLevelTo(.up));

    // Standalone function check
    try std.testing.expect(powersBlockAboveStrongly(true));
    try std.testing.expect(!powersBlockAboveStrongly(false));
    try std.testing.expect(powersBlockAboveStrongly(lit_routing));
    try std.testing.expect(!powersBlockAboveStrongly(unlit_routing));
}

test "TorchPowerRouting: does NOT power attachment block directly" {
    // Floor torch: attachment is below
    const floor_routing = TorchPowerRouting.init(.floor, true);
    try std.testing.expect(!floor_routing.powersAttachmentBlock());
    try std.testing.expectEqual(PowerLevel.none, floor_routing.getPowerLevelTo(.down));
    try std.testing.expect(!floor_routing.canPowerDirection(.down));

    // North wall torch: attachment is to the north
    const north_routing = TorchPowerRouting.init(.wall_north, true);
    try std.testing.expect(!north_routing.powersAttachmentBlock());
    try std.testing.expectEqual(PowerLevel.none, north_routing.getPowerLevelTo(.north));
    try std.testing.expect(!north_routing.canPowerDirection(.north));

    // Standalone helper
    try std.testing.expect(!powersAttachmentBlock());
}

test "TorchPowerRouting: weakly powers adjacent blocks not in attachment direction" {
    // Floor torch: up is strong, down is none, north/south/east/west are weak
    const floor_routing = TorchPowerRouting.init(.floor, true);
    try std.testing.expectEqual(PowerLevel.weak, floor_routing.getPowerLevelTo(.north));
    try std.testing.expectEqual(PowerLevel.weak, floor_routing.getPowerLevelTo(.south));
    try std.testing.expectEqual(PowerLevel.weak, floor_routing.getPowerLevelTo(.east));
    try std.testing.expectEqual(PowerLevel.weak, floor_routing.getPowerLevelTo(.west));
    try std.testing.expect(floor_routing.canPowerDirection(.north));

    // Wall torch (attached to east block):
    // up is strong, east (attachment) is none, down/north/south/west are weak
    const wall_east = TorchPowerRouting.init(.wall_east, true);
    try std.testing.expectEqual(PowerLevel.strong, wall_east.getPowerLevelTo(.up));
    try std.testing.expectEqual(PowerLevel.none, wall_east.getPowerLevelTo(.east));
    try std.testing.expectEqual(PowerLevel.weak, wall_east.getPowerLevelTo(.down));
    try std.testing.expectEqual(PowerLevel.weak, wall_east.getPowerLevelTo(.north));
    try std.testing.expectEqual(PowerLevel.weak, wall_east.getPowerLevelTo(.south));
    try std.testing.expectEqual(PowerLevel.weak, wall_east.getPowerLevelTo(.west));
}

test "TorchPowerRouting: redstone wire feedback loop routes power back into attachment block" {
    const lit_routing = TorchPowerRouting.init(.floor, true);
    try std.testing.expect(lit_routing.evaluateFeedbackLoop(true));
    try std.testing.expect(!lit_routing.evaluateFeedbackLoop(false));

    const unlit_routing = TorchPowerRouting.init(.floor, false);
    try std.testing.expect(!unlit_routing.evaluateFeedbackLoop(true));
}

test "TorchBurnoutProtection: 7 rapid toggles within 60 ticks do not trigger burnout" {
    var burnout = TorchBurnoutProtection{};

    var tick_num: u64 = 2;
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        const burned = burnout.recordExtinguish(tick_num);
        try std.testing.expect(!burned);
        tick_num += 4; // every 4 ticks
    }

    try std.testing.expectEqual(@as(usize, 7), burnout.countActiveFlips(tick_num));
    try std.testing.expect(!burnout.isBurnedOut());
    try std.testing.expect(!burnout.smoke_puff_particles);
    try std.testing.expect(!burnout.plays_hiss_sound);
}

test "TorchBurnoutProtection: 8th toggle within 60-game-tick window triggers burnout with hiss and smoke" {
    var burnout = TorchBurnoutProtection{};

    var tick_num: u64 = 2;
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        _ = burnout.recordExtinguish(tick_num);
        tick_num += 4;
    }

    // 8th extinguish at tick_num (26 + 4 = 30)
    const burned = burnout.recordExtinguish(tick_num);
    try std.testing.expect(burned);
    try std.testing.expect(burnout.isBurnedOut());
    try std.testing.expect(burnout.smoke_puff_particles);
    try std.testing.expect(burnout.plays_hiss_sound);
    try std.testing.expectEqual(@as(u64, tick_num), burnout.burnout_tick.?);

    // After 1 game tick, one-shot sound/particle effects clear, but burnout persists
    burnout.tick(tick_num + 1);
    try std.testing.expect(!burnout.smoke_puff_particles);
    try std.testing.expect(!burnout.plays_hiss_sound);
    try std.testing.expect(burnout.isBurnedOut());
}

test "TorchBurnoutProtection: burned out torch stays OFF until 60-tick window cools down" {
    var burnout = TorchBurnoutProtection{};

    // Trigger burnout with 8 rapid flips: ticks 2, 6, 10, 14, 18, 22, 26, 30
    var t: u64 = 2;
    while (t <= 30) : (t += 4) {
        _ = burnout.recordExtinguish(t);
    }
    try std.testing.expect(burnout.isBurnedOut());

    // Advance to tick 60: oldest flip (tick 2) is 58 ticks ago -> still in 60-tick window
    burnout.tick(60);
    try std.testing.expect(burnout.isBurnedOut());

    // Advance to tick 63: flip at tick 2 is now 61 ticks old -> pruned!
    burnout.tick(63);
    // With 1 flip pruned, active flips = 7 < 8 -> cools down and clears burnout!
    try std.testing.expect(!burnout.isBurnedOut());
}

test "TorchBurnoutProtection: block update allows recovery from burnout" {
    var burnout = TorchBurnoutProtection{};

    var t: u64 = 2;
    while (t <= 30) : (t += 4) {
        _ = burnout.recordExtinguish(t);
    }
    try std.testing.expect(burnout.isBurnedOut());

    // Block update received at tick 35
    const recovered = burnout.onBlockUpdate(35);
    try std.testing.expect(recovered);
    try std.testing.expect(!burnout.isBurnedOut());
}

test "RedstoneTorchInversion: rapid clock feedback loop drives torch into burnout" {
    var torch = RedstoneTorchInversion.init(.floor, false);
    try std.testing.expect(torch.is_lit);

    // Simulate an inverter wired directly into its own base block (burnout clock).
    // Each cycle: 2 ticks lit, 2 ticks unlit -> 1 extinguish toggle every 4 ticks.
    // 8 toggles * 4 ticks = 32 ticks.
    var game_tick: u64 = 0;
    while (game_tick < 60) : (game_tick += 1) {
        const feedback = torch.powersBlockAboveStrongly();
        torch.setAttachmentBlockPowered(feedback);
        torch.tickGame();

        if (torch.isBurnedOut()) break;
    }

    try std.testing.expect(torch.isBurnedOut());
    try std.testing.expect(!torch.is_lit);
    try std.testing.expectEqual(@as(u4, 0), torch.output_signal);
    try std.testing.expectEqual(@as(u4, 0), torch.light_level);
}

test "VerticalTorchTower: delay calculations (computeTorchTowerDelayTicks & computeTorchTowerDelaySeconds)" {
    try std.testing.expectEqual(@as(u16, 0), computeTorchTowerDelayTicks(0));
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), computeTorchTowerDelaySeconds(0), 0.001);

    try std.testing.expectEqual(@as(u16, 2), computeTorchTowerDelayTicks(1));
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), computeTorchTowerDelaySeconds(1), 0.001);

    try std.testing.expectEqual(@as(u16, 6), computeTorchTowerDelayTicks(3));
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), computeTorchTowerDelaySeconds(3), 0.001);

    try std.testing.expectEqual(@as(u16, 10), computeTorchTowerDelayTicks(5));
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), computeTorchTowerDelaySeconds(5), 0.001);

    try std.testing.expectEqual(@as(u16, 32), computeTorchTowerDelayTicks(16));
    try std.testing.expectApproxEqAbs(@as(f32, 1.60), computeTorchTowerDelaySeconds(16), 0.001);
}

test "VerticalTorchTower: polarity inversion (odd inverts, even preserves)" {
    // Odd torch count inverts
    try std.testing.expect(isTowerPolarityInverted(1));
    try std.testing.expect(isTowerPolarityInverted(3));
    try std.testing.expect(isTowerPolarityInverted(5));
    try std.testing.expect(isTowerPolarityInverted(7));

    // Even torch count preserves
    try std.testing.expect(!isTowerPolarityInverted(0));
    try std.testing.expect(!isTowerPolarityInverted(2));
    try std.testing.expect(!isTowerPolarityInverted(4));
    try std.testing.expect(!isTowerPolarityInverted(6));

    // Steady state output calculations
    // 1 torch (odd): inverts
    try std.testing.expectEqual(false, computeTorchTowerOutput(true, 1));
    try std.testing.expectEqual(true, computeTorchTowerOutput(false, 1));
    try std.testing.expectEqual(@as(u4, 0), computeTorchTowerOutputSignal(true, 1));
    try std.testing.expectEqual(@as(u4, 15), computeTorchTowerOutputSignal(false, 1));

    // 2 torches (even): preserves
    try std.testing.expectEqual(true, computeTorchTowerOutput(true, 2));
    try std.testing.expectEqual(false, computeTorchTowerOutput(false, 2));
    try std.testing.expectEqual(@as(u4, 15), computeTorchTowerOutputSignal(true, 2));
    try std.testing.expectEqual(@as(u4, 0), computeTorchTowerOutputSignal(false, 2));

    // 3 torches (odd): inverts
    try std.testing.expectEqual(false, computeTorchTowerOutput(true, 3));
    try std.testing.expectEqual(true, computeTorchTowerOutput(false, 3));

    // 4 torches (even): preserves
    try std.testing.expectEqual(true, computeTorchTowerOutput(true, 4));
    try std.testing.expectEqual(false, computeTorchTowerOutput(false, 4));
}

test "VerticalTorchTower: upward signal propagation with exact tick delays" {
    // 4-tier vertical tower initialized with input = false
    var tower = VerticalTorchTower.init(4, false);
    try std.testing.expect(tower.torches[0].is_lit); // tier 0: unpowered base -> lit
    try std.testing.expect(!tower.torches[1].is_lit); // tier 1: powered by torch 0 -> unlit
    try std.testing.expect(tower.torches[2].is_lit); // tier 2: unpowered -> lit
    try std.testing.expect(!tower.torches[3].is_lit); // tier 3: powered -> unlit
    try std.testing.expect(!tower.getTopTorchLit());
    try std.testing.expectEqual(@as(u4, 0), tower.getOutputSignal());

    // Switch input at base from false to true
    tower.setInput(true);

    // Tick 1 (game tick 1)
    tower.tickGame();
    try std.testing.expect(tower.torches[0].is_lit); // still lit

    // Tick 2 (game tick 2): torch 0 flips to false!
    tower.tickGame();
    try std.testing.expect(!tower.torches[0].is_lit);
    try std.testing.expect(!tower.torches[1].is_lit); // torch 1 just scheduled

    // Tick 3 (game tick 3)
    tower.tickGame();
    try std.testing.expect(!tower.torches[1].is_lit);

    // Tick 4 (game tick 4): torch 1 flips to true!
    tower.tickGame();
    try std.testing.expect(tower.torches[1].is_lit);
    try std.testing.expect(tower.torches[2].is_lit); // torch 2 just scheduled

    // Tick 5 (game tick 5)
    tower.tickGame();
    try std.testing.expect(tower.torches[2].is_lit);

    // Tick 6 (game tick 6): torch 2 flips to false!
    tower.tickGame();
    try std.testing.expect(!tower.torches[2].is_lit);
    try std.testing.expect(!tower.torches[3].is_lit); // torch 3 just scheduled

    // Tick 7 (game tick 7)
    tower.tickGame();
    try std.testing.expect(!tower.torches[3].is_lit);

    // Tick 8 (game tick 8): torch 3 flips to true!
    tower.tickGame();
    try std.testing.expect(tower.torches[3].is_lit);
    try std.testing.expect(tower.getTopTorchLit());
    try std.testing.expectEqual(@as(u4, 15), tower.getOutputSignal());
    try std.testing.expect(tower.isSettled());

    // Exactly 8 ticks = 4 torches * 2 ticks
    try std.testing.expectEqual(@as(u16, 8), computeTorchTowerDelayTicks(4));
}
