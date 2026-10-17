const std = @import("std");

/// Rail shape variants matching Minecraft's rail track geometries.
pub const RailShape = enum(u4) {
    north_south = 0,
    east_west = 1,
    ascending_east = 2,
    ascending_west = 3,
    ascending_north = 4,
    ascending_south = 5,
    curved_south_east = 6,
    curved_south_west = 7,
    curved_north_west = 8,
    curved_north_east = 9,

    pub fn isCurved(self: RailShape) bool {
        return switch (self) {
            .curved_south_east,
            .curved_south_west,
            .curved_north_west,
            .curved_north_east,
            => true,
            else => false,
        };
    }

    pub fn isAscending(self: RailShape) bool {
        return switch (self) {
            .ascending_north,
            .ascending_south,
            .ascending_east,
            .ascending_west,
            => true,
            else => false,
        };
    }

    pub fn isStraight(self: RailShape) bool {
        return self == .north_south or self == .east_west;
    }

    pub fn connectsTo(self: RailShape, dir: Direction) bool {
        return switch (self) {
            .north_south => dir == .north or dir == .south,
            .east_west => dir == .east or dir == .west,
            .ascending_north => dir == .north or dir == .south,
            .ascending_south => dir == .north or dir == .south,
            .ascending_east => dir == .east or dir == .west,
            .ascending_west => dir == .east or dir == .west,
            .curved_south_east => dir == .south or dir == .east,
            .curved_south_west => dir == .south or dir == .west,
            .curved_north_west => dir == .north or dir == .west,
            .curved_north_east => dir == .north or dir == .east,
        };
    }
};

/// Types of rail blocks.
pub const RailType = enum {
    regular,
    powered,
    detector,
    activator,

    pub fn canCurve(self: RailType) bool {
        return self == .regular;
    }

    pub fn isSpecial(self: RailType) bool {
        return self != .regular;
    }
};

/// Powered Rails, Detector Rails, and Activator Rails CANNOT curve.
pub fn canSpecialRailCurve() bool {
    return false;
}

pub fn canSpecialRailCurveFor(rail_type: RailType) bool {
    return rail_type.canCurve();
}

/// Cardinal directions on the horizontal X-Z plane.
pub const Direction = enum {
    north,
    south,
    east,
    west,

    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }

    pub fn isNorthSouth(self: Direction) bool {
        return self == .north or self == .south;
    }

    pub fn isEastWest(self: Direction) bool {
        return self == .east or self == .west;
    }
};

/// Set of connected cardinal directions adjacent to a rail node.
pub const ConnectedDirections = struct {
    north: bool = false,
    south: bool = false,
    east: bool = false,
    west: bool = false,

    pub fn count(self: ConnectedDirections) usize {
        var c: usize = 0;
        if (self.north) c += 1;
        if (self.south) c += 1;
        if (self.east) c += 1;
        if (self.west) c += 1;
        return c;
    }

    pub fn has(self: ConnectedDirections, dir: Direction) bool {
        return switch (dir) {
            .north => self.north,
            .south => self.south,
            .east => self.east,
            .west => self.west,
        };
    }

    pub fn fromSlice(dirs: []const Direction) ConnectedDirections {
        var res = ConnectedDirections{};
        for (dirs) |d| {
            switch (d) {
                .north => res.north = true,
                .south => res.south = true,
                .east => res.east = true,
                .west => res.west = true,
            }
        }
        return res;
    }
};

/// T-Junction Redstone Switching & South-East Preference Rule.
///
/// At a 3-way rail T-junction:
/// - An unpowered regular rail defaults to the South-East preference rule:
///   * If choosing between South and North (stem is East or West), South is preferred.
///   * If choosing between East and West (stem is South or North), East is preferred.
/// - Powering the rail with Redstone flips the curved track to the alternate branch.
pub const TJunctionSwitchRule = struct {
    pub fn resolveTJunctionCurve(is_powered: bool, connected_dirs: anytype) RailShape {
        const cd: ConnectedDirections = blk: {
            if (@TypeOf(connected_dirs) == ConnectedDirections) {
                break :blk connected_dirs;
            } else if (@TypeOf(connected_dirs) == []const Direction or @TypeOf(connected_dirs) == []Direction) {
                break :blk ConnectedDirections.fromSlice(connected_dirs);
            } else {
                const info = @typeInfo(@TypeOf(connected_dirs));
                if (info == .pointer and @typeInfo(info.pointer.child) == .array) {
                    break :blk ConnectedDirections.fromSlice(connected_dirs);
                } else if (info == .array) {
                    break :blk ConnectedDirections.fromSlice(&connected_dirs);
                } else {
                    break :blk connected_dirs;
                }
            }
        };

        // 1. Stem is East, straight is North-South:
        // Choices: (South + East) vs (North + East).
        // South-East rule prefers South.
        if (cd.north and cd.south and cd.east and !cd.west) {
            return if (!is_powered) .curved_south_east else .curved_north_east;
        }

        // 2. Stem is West, straight is North-South:
        // Choices: (South + West) vs (North + West).
        // South-East rule prefers South.
        if (cd.north and cd.south and cd.west and !cd.east) {
            return if (!is_powered) .curved_south_west else .curved_north_west;
        }

        // 3. Stem is South, straight is East-West:
        // Choices: (South + East) vs (South + West).
        // South-East rule prefers East.
        if (cd.east and cd.west and cd.south and !cd.north) {
            return if (!is_powered) .curved_south_east else .curved_south_west;
        }

        // 4. Stem is North, straight is East-West:
        // Choices: (North + East) vs (North + West).
        // South-East rule prefers East.
        if (cd.east and cd.west and cd.north and !cd.south) {
            return if (!is_powered) .curved_north_east else .curved_north_west;
        }

        // Non-T-junction corner fallbacks based on South-East preference:
        if (cd.south and cd.east) return .curved_south_east;
        if (cd.south and cd.west) return .curved_south_west;
        if (cd.north and cd.west) return .curved_north_west;
        if (cd.north and cd.east) return .curved_north_east;
        if (cd.east and cd.west) return .east_west;
        return .north_south;
    }
};

pub const resolveTJunctionCurve = TJunctionSwitchRule.resolveTJunctionCurve;

/// Powered Rail Chain Propagation and Cart Dynamics.
///
/// A single redstone power source powers up to 9 connected Powered Rails in each direction
/// (8 blocks beyond the directly powered rail: `distance_from_source <= 8`).
/// Unpowered Powered Rails act as high-friction brakes (`unpoweredDecelerationFactor() < 0.5`),
/// whereas powered ones accelerate carts up to 8.0 m/s.
pub const PoweredRailChainPropagation = struct {
    pub const max_signal_distance: u8 = 8;
    pub const max_chain_blocks_single_direction: u8 = 9; // 1 source + 8 propagation
    pub const max_chain_blocks_bidirectional: u8 = 17; // 8 + 1 + 8
    pub const max_cart_speed: f32 = 8.0; // m/s
    pub const unpowered_deceleration_factor: f32 = 0.25; // < 0.5 friction multiplier
    pub const powered_acceleration_rate: f32 = 10.0; // m/s^2

    /// A single redstone power source powers up to 8 blocks beyond the source block.
    pub fn poweredRailSignalRange(distance_from_source: u8) bool {
        return distance_from_source <= max_signal_distance;
    }

    /// Friction braking multiplier for unpowered powered rail (must be < 0.5).
    pub fn unpoweredDecelerationFactor() f32 {
        return unpowered_deceleration_factor;
    }

    /// Propagates power along a continuous array of rails starting from a power source index.
    pub fn propagateSignal(rails: []const RailType, source_idx: usize, powered_out: []bool) void {
        @memset(powered_out, false);
        if (source_idx >= rails.len) return;
        if (rails[source_idx] != .powered) return;

        powered_out[source_idx] = true;

        // Forward propagation (up to 8 blocks beyond source)
        var forward_dist: u8 = 1;
        while (forward_dist <= max_signal_distance) : (forward_dist += 1) {
            const idx = source_idx + forward_dist;
            if (idx >= rails.len) break;
            if (rails[idx] != .powered) break;
            if (!PoweredRailChainPropagation.poweredRailSignalRange(forward_dist)) break;
            powered_out[idx] = true;
        }

        // Backward propagation (up to 8 blocks beyond source)
        var back_dist: u8 = 1;
        while (back_dist <= max_signal_distance) : (back_dist += 1) {
            if (source_idx < back_dist) break;
            const idx = source_idx - back_dist;
            if (rails[idx] != .powered) break;
            if (!PoweredRailChainPropagation.poweredRailSignalRange(back_dist)) break;
            powered_out[idx] = true;
        }
    }

    /// Applies powered rail acceleration or unpowered rail braking to cart velocity.
    pub fn stepCartVelocity(current_velocity: f32, is_powered: bool, dt: f32) f32 {
        if (is_powered) {
            if (current_velocity == 0.0) return 0.0;
            const sign: f32 = if (current_velocity > 0.0) 1.0 else -1.0;
            const speed = @abs(current_velocity) + powered_acceleration_rate * dt;
            return sign * @min(speed, max_cart_speed);
        } else {
            // Unpowered rail applies strong friction braking
            const brake_mult = std.math.pow(f32, unpowered_deceleration_factor, dt * 20.0);
            const new_vel = current_velocity * brake_mult;
            if (@abs(new_vel) < 0.05) return 0.0;
            return new_vel;
        }
    }
};

pub const poweredRailSignalRange = PoweredRailChainPropagation.poweredRailSignalRange;
pub const unpoweredDecelerationFactor = PoweredRailChainPropagation.unpoweredDecelerationFactor;

/// One-Way Slope Gate and Terminal Launcher.
///
/// A cart traveling UP an unpowered Powered Rail on a 45° slope stops if slow,
/// whereas a cart traveling DOWN coasts through due to gravity.
/// Placing a solid block at the back of a terminal Powered Rail launches a stationary
/// cart forward when powered (`canLaunchStationaryCart(has_solid_block_behind, is_powered)`).
pub const OneWaySlopeGate = struct {
    pub const slope_angle_degrees: f32 = 45.0;
    pub const gravity: f32 = 9.81;
    pub const slow_speed_threshold: f32 = 2.0; // m/s
    pub const terminal_launch_boost_speed: f32 = 4.0; // m/s initial launch impulse

    pub const TravelDirection = enum {
        up,
        down,
    };

    /// Placing a solid block at the back of a terminal Powered Rail launches a stationary
    /// cart forward when powered.
    pub fn canLaunchStationaryCart(has_solid_block_behind: bool, is_powered: bool) bool {
        return has_solid_block_behind and is_powered;
    }

    /// Determines the launched cart's initial velocity away from the terminal solid block.
    pub fn launchStationaryCart(has_solid_block_behind: bool, is_powered: bool) f32 {
        if (OneWaySlopeGate.canLaunchStationaryCart(has_solid_block_behind, is_powered)) {
            return terminal_launch_boost_speed;
        }
        return 0.0;
    }

    /// A cart traveling DOWN an unpowered Powered Rail on a 45° slope coasts through.
    pub fn canCoastDownhill(is_powered: bool) bool {
        _ = is_powered; // Downhill slope gravity ensures cart coasts through regardless
        return true;
    }

    /// A cart traveling UP an unpowered Powered Rail on a 45° slope stops if slow.
    pub fn willStopTravelingUp(cart_speed: f32, is_powered: bool) bool {
        if (is_powered) return false;
        return cart_speed <= slow_speed_threshold;
    }

    pub const SlopeSimulationResult = struct {
        final_speed: f32,
        stopped: bool,
        passed_through: bool,
    };

    /// Simulates passage through a 45° slope powered rail.
    pub fn simulateSlopePassage(
        dir: TravelDirection,
        initial_speed: f32,
        is_powered: bool,
        slope_length: f32,
    ) SlopeSimulationResult {
        if (dir == .down) {
            // Downhill: gravity assists movement (g * sin(45°) ~= 6.936 m/s^2)
            const g_downhill = gravity * 0.70710678;
            const net_accel = if (is_powered)
                g_downhill + PoweredRailChainPropagation.powered_acceleration_rate
            else
                g_downhill * (1.0 - PoweredRailChainPropagation.unpowered_deceleration_factor);
            const v_sq = initial_speed * initial_speed + 2.0 * net_accel * slope_length;
            const final_v = @min(@sqrt(v_sq), PoweredRailChainPropagation.max_cart_speed);
            return .{
                .final_speed = final_v,
                .stopped = false,
                .passed_through = true,
            };
        } else {
            // Uphill: unpowered rail acts as one-way gate stopping slow carts
            if (willStopTravelingUp(initial_speed, is_powered)) {
                return .{
                    .final_speed = 0.0,
                    .stopped = true,
                    .passed_through = false,
                };
            }
            if (is_powered) {
                const g_downhill = gravity * 0.70710678;
                const net_accel = PoweredRailChainPropagation.powered_acceleration_rate - g_downhill;
                const v_sq = initial_speed * initial_speed + 2.0 * net_accel * slope_length;
                if (v_sq <= 0.0) {
                    return .{ .final_speed = 0.0, .stopped = true, .passed_through = false };
                }
                const final_v = @min(@sqrt(v_sq), PoweredRailChainPropagation.max_cart_speed);
                return .{
                    .final_speed = final_v,
                    .stopped = false,
                    .passed_through = true,
                };
            } else {
                const brake = PoweredRailChainPropagation.unpowered_deceleration_factor;
                const final_v = initial_speed * brake;
                if (final_v <= slow_speed_threshold) {
                    return .{ .final_speed = 0.0, .stopped = true, .passed_through = false };
                }
                return .{
                    .final_speed = final_v,
                    .stopped = false,
                    .passed_through = true,
                };
            }
        }
    }
};

pub const canLaunchStationaryCart = OneWaySlopeGate.canLaunchStationaryCart;

/// Detector Rail and Redstone Comparator Weighting.
///
/// Detector rails emit a direct redstone signal of strength 15 when any cart is on top.
/// A redstone comparator reading a detector rail measures the contents/weight of the cart:
/// - Chest Minecart: 27 inventory slots (1728 items max capacity).
/// - Hopper Minecart: 5 inventory slots (320 items max capacity).
/// - Rideable Minecart: signal 1 when occupied by passenger, 0 when empty.
/// - Furnace Minecart: signal 0..15 proportional to remaining fuel.
/// - Command Block Minecart: signal 0..15 proportional to success count.
pub const DetectorRailComparator = struct {
    pub const chest_slots: u32 = 27;
    pub const hopper_slots: u32 = 5;
    pub const slot_stack_limit: u32 = 64;
    pub const max_chest_items: u32 = chest_slots * slot_stack_limit; // 1728
    pub const max_hopper_items: u32 = hopper_slots * slot_stack_limit; // 320
    pub const max_furnace_fuel_seconds: f32 = 1800.0;

    pub const MinecartKind = enum {
        rideable,
        chest,
        hopper,
        furnace,
        tnt,
        command_block,
    };

    pub const DetectorCartInfo = struct {
        kind: MinecartKind = .rideable,
        item_count: u32 = 0,
        has_passenger: bool = false,
        furnace_fuel_seconds: f32 = 0.0,
        command_success_count: u32 = 0,
    };

    /// Detector rail emits direct signal 15 whenever any minecart is present.
    pub fn detectorRailDirectSignal(has_cart: bool) u4 {
        return if (has_cart) 15 else 0;
    }

    /// Evaluates container fullness to comparator signal strength (0..15).
    /// Empty container outputs 0. Any items output 1 + (items * 14) / capacity up to 15.
    pub fn computeContainerSignal(total_items: u32, capacity: u32) u4 {
        if (total_items == 0 or capacity == 0) return 0;
        if (total_items >= capacity) return 15;
        const scaled: u32 = 1 + (total_items * 14) / capacity;
        return @as(u4, @intCast(@min(15, scaled)));
    }

    /// Evaluates furnace cart fuel to comparator signal strength (0..15).
    pub fn computeFurnaceSignal(fuel_seconds: f32) u4 {
        if (fuel_seconds <= 0.0) return 0;
        if (fuel_seconds >= max_furnace_fuel_seconds) return 15;
        const ratio = fuel_seconds / max_furnace_fuel_seconds;
        const signal: u32 = 1 + @as(u32, @intFromFloat(ratio * 14.0));
        return @as(u4, @intCast(@min(15, signal)));
    }

    /// Evaluates comparator signal output for a cart on a detector rail.
    pub fn computeComparatorSignal(cart: DetectorCartInfo) u4 {
        return switch (cart.kind) {
            .chest => computeContainerSignal(cart.item_count, max_chest_items),
            .hopper => computeContainerSignal(cart.item_count, max_hopper_items),
            .rideable => if (cart.has_passenger) 1 else 0,
            .furnace => computeFurnaceSignal(cart.furnace_fuel_seconds),
            .command_block => @as(u4, @intCast(@min(15, cart.command_success_count))),
            .tnt => 0,
        };
    }
};

pub const computeDetectorRailComparatorSignal = DetectorRailComparator.computeComparatorSignal;
pub const detectorRailDirectSignal = DetectorRailComparator.detectorRailDirectSignal;

// ============================================================================
// TESTS
// ============================================================================

test "1: RailShape enum and property classifications" {
    const curved = RailShape.curved_south_east;
    try std.testing.expect(curved.isCurved());
    try std.testing.expect(!curved.isAscending());
    try std.testing.expect(!curved.isStraight());
    try std.testing.expect(curved.connectsTo(.south));
    try std.testing.expect(curved.connectsTo(.east));
    try std.testing.expect(!curved.connectsTo(.north));
    try std.testing.expect(!curved.connectsTo(.west));

    const ascending = RailShape.ascending_north;
    try std.testing.expect(!ascending.isCurved());
    try std.testing.expect(ascending.isAscending());
    try std.testing.expect(!ascending.isStraight());
    try std.testing.expect(ascending.connectsTo(.north));
    try std.testing.expect(ascending.connectsTo(.south));

    const straight = RailShape.north_south;
    try std.testing.expect(straight.isStraight());
    try std.testing.expect(!straight.isCurved());
    try std.testing.expect(!straight.isAscending());

    const ew = RailShape.east_west;
    try std.testing.expect(ew.isStraight());
    try std.testing.expect(ew.connectsTo(.east));
    try std.testing.expect(ew.connectsTo(.west));
}

test "2: special rails cannot curve (canSpecialRailCurve == false)" {
    try std.testing.expectEqual(false, canSpecialRailCurve());
    try std.testing.expectEqual(false, canSpecialRailCurveFor(.powered));
    try std.testing.expectEqual(false, canSpecialRailCurveFor(.detector));
    try std.testing.expectEqual(false, canSpecialRailCurveFor(.activator));
    try std.testing.expectEqual(true, canSpecialRailCurveFor(.regular));
}

test "3: TJunctionSwitchRule unpowered South-East rule for N-S straight with East stem" {
    // 3-way junction with North, South, East connected
    const dirs = ConnectedDirections{ .north = true, .south = true, .east = true };
    // Unpowered: South preferred over North -> curved_south_east
    const unpowered_shape = resolveTJunctionCurve(false, dirs);
    try std.testing.expectEqual(RailShape.curved_south_east, unpowered_shape);

    // Powered: flips to alternate branch -> curved_north_east
    const powered_shape = resolveTJunctionCurve(true, dirs);
    try std.testing.expectEqual(RailShape.curved_north_east, powered_shape);
}

test "4: TJunctionSwitchRule unpowered South-East rule for N-S straight with West stem" {
    // 3-way junction with North, South, West connected
    const dirs = ConnectedDirections{ .north = true, .south = true, .west = true };
    // Unpowered: South preferred over North -> curved_south_west
    const unpowered_shape = resolveTJunctionCurve(false, dirs);
    try std.testing.expectEqual(RailShape.curved_south_west, unpowered_shape);

    // Powered: flips to alternate branch -> curved_north_west
    const powered_shape = resolveTJunctionCurve(true, dirs);
    try std.testing.expectEqual(RailShape.curved_north_west, powered_shape);
}

test "5: TJunctionSwitchRule unpowered South-East rule for E-W straight with South stem" {
    // 3-way junction with East, West, South connected
    const dirs = ConnectedDirections{ .east = true, .west = true, .south = true };
    // Unpowered: East preferred over West -> curved_south_east
    const unpowered_shape = resolveTJunctionCurve(false, dirs);
    try std.testing.expectEqual(RailShape.curved_south_east, unpowered_shape);

    // Powered: flips to alternate branch -> curved_south_west
    const powered_shape = resolveTJunctionCurve(true, dirs);
    try std.testing.expectEqual(RailShape.curved_south_west, powered_shape);
}

test "6: TJunctionSwitchRule unpowered South-East rule for E-W straight with North stem" {
    // 3-way junction with East, West, North connected
    const dirs = ConnectedDirections{ .east = true, .west = true, .north = true };
    // Unpowered: East preferred over West -> curved_north_east
    const unpowered_shape = resolveTJunctionCurve(false, dirs);
    try std.testing.expectEqual(RailShape.curved_north_east, unpowered_shape);

    // Powered: flips to alternate branch -> curved_north_west
    const powered_shape = resolveTJunctionCurve(true, dirs);
    try std.testing.expectEqual(RailShape.curved_north_west, powered_shape);
}

test "7: TJunctionSwitchRule accepts slice and array representations" {
    const slice: []const Direction = &[_]Direction{ .north, .south, .east };
    try std.testing.expectEqual(RailShape.curved_south_east, resolveTJunctionCurve(false, slice));
    try std.testing.expectEqual(RailShape.curved_north_east, resolveTJunctionCurve(true, slice));

    const arr = [_]Direction{ .east, .west, .south };
    try std.testing.expectEqual(RailShape.curved_south_east, resolveTJunctionCurve(false, arr));
    try std.testing.expectEqual(RailShape.curved_south_west, resolveTJunctionCurve(true, arr));
}

test "8: PoweredRailChainPropagation signal range boundary up to 8 blocks beyond source" {
    // At source (distance 0): powered
    try std.testing.expect(poweredRailSignalRange(0));
    // Up to 8 blocks beyond source: powered
    var dist: u8 = 1;
    while (dist <= 8) : (dist += 1) {
        try std.testing.expect(poweredRailSignalRange(dist));
    }
    // 9 blocks beyond source and further: unpowered
    try std.testing.expect(!poweredRailSignalRange(9));
    try std.testing.expect(!poweredRailSignalRange(10));
    try std.testing.expect(!poweredRailSignalRange(16));
}

test "9: PoweredRailChainPropagation linear array propagation and blocking by non-powered rail" {
    const rails = [_]RailType{
        .powered, .powered, .powered, .powered, .powered,
        .powered, .powered, .powered, .powered, .powered,
        .powered,
    };
    var powered_states: [11]bool = undefined;

    // Source at index 0: should power up to index 8 (0 + 8 = 8 blocks beyond source, 9 blocks total)
    PoweredRailChainPropagation.propagateSignal(&rails, 0, &powered_states);
    for (0..9) |i| {
        try std.testing.expect(powered_states[i]);
    }
    // Indices 9 and 10 exceed the 8-block propagation limit
    try std.testing.expect(!powered_states[9]);
    try std.testing.expect(!powered_states[10]);

    // Test non-powered rail interruption:
    const mixed_rails = [_]RailType{
        .powered, .powered, .regular, .powered, .powered,
    };
    var mixed_states: [5]bool = undefined;
    PoweredRailChainPropagation.propagateSignal(&mixed_rails, 0, &mixed_states);
    try std.testing.expect(mixed_states[0]);
    try std.testing.expect(mixed_states[1]);
    try std.testing.expect(!mixed_states[2]); // regular rail stops propagation
    try std.testing.expect(!mixed_states[3]); // unreachable
    try std.testing.expect(!mixed_states[4]); // unreachable
}

test "10: PoweredRailChainPropagation unpowered rail high-friction brake and powered acceleration to max 8.0 m/s" {
    try std.testing.expect(unpoweredDecelerationFactor() < 0.5);

    // Unpowered rail applies high friction brake
    const initial_speed: f32 = 6.0;
    const braked_speed = PoweredRailChainPropagation.stepCartVelocity(initial_speed, false, 0.1);
    try std.testing.expect(braked_speed < initial_speed);

    // Powered rail accelerates cart up to max 8.0 m/s
    var speed: f32 = 4.0;
    for (0..10) |_| {
        speed = PoweredRailChainPropagation.stepCartVelocity(speed, true, 0.1);
    }
    try std.testing.expectEqual(@as(f32, 8.0), speed);

    // Stationary cart on flat powered rail without directional push remains stationary
    try std.testing.expectEqual(@as(f32, 0.0), PoweredRailChainPropagation.stepCartVelocity(0.0, true, 0.1));
}

test "11: OneWaySlopeGate stationary cart launch requires solid block behind and power" {
    // Unpowered: cannot launch regardless of block behind
    try std.testing.expect(!canLaunchStationaryCart(true, false));
    try std.testing.expect(!canLaunchStationaryCart(false, false));

    // Powered but no solid block behind: cannot launch (direction ambiguous)
    try std.testing.expect(!canLaunchStationaryCart(false, true));

    // Solid block behind AND powered: launches cart!
    try std.testing.expect(canLaunchStationaryCart(true, true));
    try std.testing.expect(OneWaySlopeGate.launchStationaryCart(true, true) > 0.0);
}

test "12: OneWaySlopeGate 45-degree slope coasts downhill and stops uphill when slow" {
    // Downhill: always coasts through
    try std.testing.expect(OneWaySlopeGate.canCoastDownhill(false));
    try std.testing.expect(OneWaySlopeGate.canCoastDownhill(true));

    const downhill_sim = OneWaySlopeGate.simulateSlopePassage(.down, 1.0, false, 2.0);
    try std.testing.expect(downhill_sim.passed_through);
    try std.testing.expect(!downhill_sim.stopped);
    try std.testing.expect(downhill_sim.final_speed > 1.0);

    // Uphill: slow cart stops if unpowered
    try std.testing.expect(OneWaySlopeGate.willStopTravelingUp(1.5, false));
    const uphill_stop = OneWaySlopeGate.simulateSlopePassage(.up, 1.5, false, 2.0);
    try std.testing.expect(uphill_stop.stopped);
    try std.testing.expect(!uphill_stop.passed_through);
    try std.testing.expectEqual(@as(f32, 0.0), uphill_stop.final_speed);

    // Uphill: powered rail allows ascending
    try std.testing.expect(!OneWaySlopeGate.willStopTravelingUp(1.5, true));
    const uphill_powered = OneWaySlopeGate.simulateSlopePassage(.up, 4.0, true, 2.0);
    try std.testing.expect(uphill_powered.passed_through);
    try std.testing.expect(!uphill_powered.stopped);
}

test "13: DetectorRailComparator chest and hopper cart fullness weighting" {
    // Empty chest cart outputs 0
    const empty_chest = DetectorRailComparator.DetectorCartInfo{ .kind = .chest, .item_count = 0 };
    try std.testing.expectEqual(@as(u4, 0), computeDetectorRailComparatorSignal(empty_chest));

    // Single item outputs 1
    const single_item_chest = DetectorRailComparator.DetectorCartInfo{ .kind = .chest, .item_count = 1 };
    try std.testing.expectEqual(@as(u4, 1), computeDetectorRailComparatorSignal(single_item_chest));

    // Half capacity (864 items) outputs 8
    const half_chest = DetectorRailComparator.DetectorCartInfo{ .kind = .chest, .item_count = 864 };
    try std.testing.expectEqual(@as(u4, 8), computeDetectorRailComparatorSignal(half_chest));

    // Full chest (1728 items) outputs 15
    const full_chest = DetectorRailComparator.DetectorCartInfo{ .kind = .chest, .item_count = 1728 };
    try std.testing.expectEqual(@as(u4, 15), computeDetectorRailComparatorSignal(full_chest));

    // Hopper cart: 320 items capacity
    const empty_hopper = DetectorRailComparator.DetectorCartInfo{ .kind = .hopper, .item_count = 0 };
    try std.testing.expectEqual(@as(u4, 0), computeDetectorRailComparatorSignal(empty_hopper));

    const half_hopper = DetectorRailComparator.DetectorCartInfo{ .kind = .hopper, .item_count = 160 };
    try std.testing.expectEqual(@as(u4, 8), computeDetectorRailComparatorSignal(half_hopper));

    const full_hopper = DetectorRailComparator.DetectorCartInfo{ .kind = .hopper, .item_count = 320 };
    try std.testing.expectEqual(@as(u4, 15), computeDetectorRailComparatorSignal(full_hopper));
}

test "14: DetectorRailComparator rideable, furnace, command block, and direct signal" {
    // Direct signal from detector rail: 15 when cart present, 0 when empty
    try std.testing.expectEqual(@as(u4, 15), detectorRailDirectSignal(true));
    try std.testing.expectEqual(@as(u4, 0), detectorRailDirectSignal(false));

    // Rideable cart: 0 when empty, 1 when occupied
    const empty_rideable = DetectorRailComparator.DetectorCartInfo{ .kind = .rideable, .has_passenger = false };
    try std.testing.expectEqual(@as(u4, 0), computeDetectorRailComparatorSignal(empty_rideable));
    const occupied_rideable = DetectorRailComparator.DetectorCartInfo{ .kind = .rideable, .has_passenger = true };
    try std.testing.expectEqual(@as(u4, 1), computeDetectorRailComparatorSignal(occupied_rideable));

    // Furnace cart: scales with fuel
    const cold_furnace = DetectorRailComparator.DetectorCartInfo{ .kind = .furnace, .furnace_fuel_seconds = 0.0 };
    try std.testing.expectEqual(@as(u4, 0), computeDetectorRailComparatorSignal(cold_furnace));
    const full_furnace = DetectorRailComparator.DetectorCartInfo{ .kind = .furnace, .furnace_fuel_seconds = 1800.0 };
    try std.testing.expectEqual(@as(u4, 15), computeDetectorRailComparatorSignal(full_furnace));

    // Command block cart: clamps to 15
    const cmd_cart = DetectorRailComparator.DetectorCartInfo{ .kind = .command_block, .command_success_count = 10 };
    try std.testing.expectEqual(@as(u4, 10), computeDetectorRailComparatorSignal(cmd_cart));
    const cmd_overflow = DetectorRailComparator.DetectorCartInfo{ .kind = .command_block, .command_success_count = 100 };
    try std.testing.expectEqual(@as(u4, 15), computeDetectorRailComparatorSignal(cmd_overflow));
}
