const std = @import("std");

pub const SENSOR_RANGE: f32 = 8.0;
pub const ACTIVE_TICKS: u8 = 30;
pub const COOLDOWN_TICKS: u8 = 10;
pub const MAX_FREQUENCY: u8 = 15;

pub const Position = struct { x: f32, y: f32, z: f32 };
pub const BlockPosition = struct { x: i32, y: i32, z: i32 };
pub const BlockKind = enum { air, other, wool, wool_carpet };

pub const Sensor = struct {
    position: BlockPosition,
    is_waterlogged: bool = false,
    pending_vibration_ticks: u32 = 0,
    pending_frequency: u8 = 0,
    active_ticks: u8 = 0,
    cooldown_ticks: u8 = 0,
    redstone_signal: u8 = 0,

    pub fn isActive(self: Sensor) bool {
        return self.active_ticks > 0;
    }

    pub fn comparatorOutput(self: Sensor) u8 {
        return self.redstone_signal;
    }

    pub fn soundVolume(self: Sensor) f32 {
        return if (self.is_waterlogged and self.isActive()) 0.0 else if (self.isActive()) 1.0 else 0.0;
    }

    pub fn emitsSculkParticles(self: Sensor) bool {
        return self.isActive() and !self.is_waterlogged;
    }
};

pub const VibrationResult = struct {
    detected: bool = false,
    frequency: u8 = 0,
    delay_ticks: u32 = 0,
};

pub fn distance(a: Position, b: Position) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const dz = a.z - b.z;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

/// Sound travels one block per game tick, rounded up to the next whole tick.
pub fn arrivalDelayTicks(block_distance: f32) u32 {
    if (!std.math.isFinite(block_distance) or block_distance <= 0.0) return 0;
    return @intFromFloat(@ceil(block_distance));
}

fn floorBlock(value: f32) i32 {
    return @intFromFloat(@floor(value));
}

fn isWoolAt(blocks: []const BlockPosition, position: BlockPosition) bool {
    for (blocks) |block| {
        if (block.x == position.x and block.y == position.y and block.z == position.z) return true;
    }
    return false;
}

fn isWool(kind: BlockKind) bool {
    return kind == .wool or kind == .wool_carpet;
}

/// Tests wool cells intersected by the open source-to-sensor segment. The
/// source and sensor endpoint blocks are excluded from occlusion testing.
pub fn isWoolOccluded(source: Position, target: Position, wool_blocks: []const BlockPosition) bool {
    var cell = BlockPosition{ .x = floorBlock(source.x), .y = floorBlock(source.y), .z = floorBlock(source.z) };
    const end = BlockPosition{ .x = floorBlock(target.x), .y = floorBlock(target.y), .z = floorBlock(target.z) };
    const delta = [3]f32{ target.x - source.x, target.y - source.y, target.z - source.z };
    var current = [3]i32{ cell.x, cell.y, cell.z };
    const destination = [3]i32{ end.x, end.y, end.z };
    var step = [3]i32{ 0, 0, 0 };
    var t_max = [3]f32{ std.math.inf(f32), std.math.inf(f32), std.math.inf(f32) };
    var t_delta = [3]f32{ std.math.inf(f32), std.math.inf(f32), std.math.inf(f32) };

    for (0..3) |axis| {
        if (delta[axis] > 0.0) {
            step[axis] = 1;
            t_max[axis] = (@as(f32, @floatFromInt(current[axis] + 1)) - sourceComponent(source, axis)) / delta[axis];
            t_delta[axis] = 1.0 / delta[axis];
        } else if (delta[axis] < 0.0) {
            step[axis] = -1;
            t_max[axis] = (@as(f32, @floatFromInt(current[axis])) - sourceComponent(source, axis)) / delta[axis];
            t_delta[axis] = -1.0 / delta[axis];
        }
    }

    while (!sameCell(current, destination)) {
        const next_t = @min(t_max[0], @min(t_max[1], t_max[2]));
        if (next_t >= 1.0) break;
        for (0..3) |axis| {
            if (@abs(t_max[axis] - next_t) <= 1e-6) {
                current[axis] += step[axis];
                t_max[axis] += t_delta[axis];
            }
        }
        cell = .{ .x = current[0], .y = current[1], .z = current[2] };
        if (!sameCell(current, destination) and isWoolAt(wool_blocks, cell)) return true;
    }
    return false;
}

fn sourceComponent(position: Position, axis: usize) f32 {
    return switch (axis) { 0 => position.x, 1 => position.y, else => position.z };
}

fn sameCell(a: [3]i32, b: [3]i32) bool {
    return a[0] == b[0] and a[1] == b[1] and a[2] == b[2];
}

/// Route a vibration to a sensor. A successful result reports the travel
/// delay; callers can deliver it after that many game ticks.
pub fn routeVibration(sensor: *Sensor, source: Position, frequency: u8, wool_blocks: []const BlockPosition) VibrationResult {
    if (frequency == 0 or frequency > MAX_FREQUENCY) return .{};
    if (sensor.isActive() or sensor.cooldown_ticks > 0 or sensor.pending_frequency > 0) return .{};

    const center = Position{
        .x = @as(f32, @floatFromInt(sensor.position.x)) + 0.5,
        .y = @as(f32, @floatFromInt(sensor.position.y)) + 0.5,
        .z = @as(f32, @floatFromInt(sensor.position.z)) + 0.5,
    };
    const travel_distance = distance(source, center);
    if (travel_distance > SENSOR_RANGE or isWoolOccluded(source, center, wool_blocks)) return .{};

    const delay_ticks = arrivalDelayTicks(travel_distance);
    if (delay_ticks == 0) {
        sensor.active_ticks = ACTIVE_TICKS;
        sensor.redstone_signal = frequency;
    } else {
        sensor.pending_vibration_ticks = delay_ticks;
        sensor.pending_frequency = frequency;
    }
    return .{ .detected = true, .frequency = frequency, .delay_ticks = delay_ticks };
}

/// Advances one game tick. Active ticks are followed by ten unpowered ticks.
pub fn tick(sensor: *Sensor) void {
    if (sensor.pending_frequency > 0) {
        sensor.pending_vibration_ticks -= 1;
        if (sensor.pending_vibration_ticks == 0) {
            sensor.active_ticks = ACTIVE_TICKS;
            sensor.redstone_signal = sensor.pending_frequency;
            sensor.pending_frequency = 0;
        }
        return;
    }
    if (sensor.active_ticks > 0) {
        sensor.active_ticks -= 1;
        if (sensor.active_ticks == 0) {
            sensor.redstone_signal = 0;
            sensor.cooldown_ticks = COOLDOWN_TICKS;
        }
    } else if (sensor.cooldown_ticks > 0) {
        sensor.cooldown_ticks -= 1;
    }
}

pub fn comparatorSignal(frequency: u8) u8 {
    return if (frequency <= MAX_FREQUENCY) frequency else 0;
}

pub fn blockKindIsOccludingWool(kind: BlockKind) bool {
    return isWool(kind);
}

test "one block of travel takes one game tick" { try std.testing.expectEqual(@as(u32, 1), arrivalDelayTicks(1.0)); }
test "fractional travel rounds up to next tick" { try std.testing.expectEqual(@as(u32, 2), arrivalDelayTicks(1.01)); }
test "zero distance has no travel delay" { try std.testing.expectEqual(@as(u32, 0), arrivalDelayTicks(0.0)); }
test "negative distance has no travel delay" { try std.testing.expectEqual(@as(u32, 0), arrivalDelayTicks(-1.0)); }
test "non-finite distance has no travel delay" { try std.testing.expectEqual(@as(u32, 0), arrivalDelayTicks(std.math.inf(f32))); }
test "three dimensional distance uses Euclidean length" { try std.testing.expectApproxEqAbs(@as(f32, 5.0), distance(.{ .x = 0, .y = 0, .z = 0 }, .{ .x = 3, .y = 4, .z = 0 }), 1e-5); }
test "sensor range constant is eight blocks" { try std.testing.expectEqual(@as(f32, 8), SENSOR_RANGE); }
test "source at eight blocks is detected" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; const r = routeVibration(&s, .{ .x = 8.5, .y = 0.5, .z = 0.5 }, 7, &.{}); try std.testing.expect(r.detected); }
test "source just beyond eight blocks is rejected" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; const r = routeVibration(&s, .{ .x = 8.501, .y = 0.5, .z = 0.5 }, 7, &.{}); try std.testing.expect(!r.detected); }
test "source within eight blocks is detected" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; try std.testing.expect(routeVibration(&s, .{ .x = 4.5, .y = 0.5, .z = 0.5 }, 3, &.{}).detected); }
test "wool cell blocks direct line of sight" { const wool = [_]BlockPosition{.{ .x = 2, .y = 0, .z = 0 }}; try std.testing.expect(isWoolOccluded(.{ .x = 0.5, .y = 0.5, .z = 0.5 }, .{ .x = 4.5, .y = 0.5, .z = 0.5 }, &wool)); }
test "wool carpet cell blocks direct line of sight" { const wool = [_]BlockPosition{.{ .x = 2, .y = 0, .z = 0 }}; try std.testing.expect(isWoolOccluded(.{ .x = 0.5, .y = 0.5, .z = 0.5 }, .{ .x = 4.5, .y = 0.5, .z = 0.5 }, &wool)); try std.testing.expect(blockKindIsOccludingWool(.wool_carpet)); }
test "other blocks do not count as wool occlusion" { try std.testing.expect(!isWoolOccluded(.{ .x = 0.5, .y = 0.5, .z = 0.5 }, .{ .x = 4.5, .y = 0.5, .z = 0.5 }, &.{})); try std.testing.expect(!blockKindIsOccludingWool(.other)); }
test "diagonal raycast detects wool on diagonal voxel path" { const wool = [_]BlockPosition{.{ .x = 2, .y = 2, .z = 0 }}; try std.testing.expect(isWoolOccluded(.{ .x = 0.5, .y = 0.5, .z = 0.5 }, .{ .x = 4.5, .y = 4.5, .z = 0.5 }, &wool)); }
test "diagonal raycast avoids off-path wool" { const wool = [_]BlockPosition{.{ .x = 2, .y = 1, .z = 0 }}; try std.testing.expect(!isWoolOccluded(.{ .x = 0.5, .y = 0.5, .z = 0.5 }, .{ .x = 4.5, .y = 4.5, .z = 0.5 }, &wool)); }
test "wool dampens vibration to frequency zero" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; const wool = [_]BlockPosition{.{ .x = 2, .y = 0, .z = 0 }}; const r = routeVibration(&s, .{ .x = 4.5, .y = 0.5, .z = 0.5 }, 12, &wool); try std.testing.expect(!r.detected); try std.testing.expectEqual(@as(u8, 0), r.frequency); }
test "source endpoint wool is not between source and sensor" { const wool = [_]BlockPosition{.{ .x = 0, .y = 0, .z = 0 }}; try std.testing.expect(!isWoolOccluded(.{ .x = 0.5, .y = 0.5, .z = 0.5 }, .{ .x = 4.5, .y = 0.5, .z = 0.5 }, &wool)); }
test "target endpoint wool is not between source and sensor" { const wool = [_]BlockPosition{.{ .x = 4, .y = 0, .z = 0 }}; try std.testing.expect(!isWoolOccluded(.{ .x = 0.5, .y = 0.5, .z = 0.5 }, .{ .x = 4.5, .y = 0.5, .z = 0.5 }, &wool)); }
test "waterlogged activation keeps redstone but suppresses sound and particles" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 }, .is_waterlogged = true }; _ = routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 9, &.{}); try std.testing.expectEqual(@as(u8, 9), s.redstone_signal); try std.testing.expectEqual(@as(f32, 0), s.soundVolume()); try std.testing.expect(!s.emitsSculkParticles()); }
test "ordinary activation emits sound and sculk particles" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; _ = routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 1, &.{}); try std.testing.expectEqual(@as(f32, 1), s.soundVolume()); try std.testing.expect(s.emitsSculkParticles()); }
test "sensor activates for exactly thirty ticks" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; _ = routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 1, &.{}); var i: usize = 0; while (i < 29) : (i += 1) tick(&s); try std.testing.expectEqual(@as(u8, 1), s.active_ticks); try std.testing.expectEqual(@as(u8, 1), s.redstone_signal); tick(&s); try std.testing.expectEqual(@as(u8, 0), s.active_ticks); try std.testing.expectEqual(@as(u8, 0), s.redstone_signal); }
test "sensor cooldown lasts ten unpowered ticks" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 }, .cooldown_ticks = COOLDOWN_TICKS }; var i: usize = 0; while (i < 9) : (i += 1) tick(&s); try std.testing.expectEqual(@as(u8, 1), s.cooldown_ticks); tick(&s); try std.testing.expectEqual(@as(u8, 0), s.cooldown_ticks); }
test "cooldown begins when active phase ends" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; _ = routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 4, &.{}); var i: usize = 0; while (i < ACTIVE_TICKS) : (i += 1) tick(&s); try std.testing.expectEqual(COOLDOWN_TICKS, s.cooldown_ticks); }
test "sensor rejects vibration while active" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; _ = routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 4, &.{}); try std.testing.expect(!routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 8, &.{}).detected); }
test "sensor rejects vibration during recovery cooldown" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 }, .cooldown_ticks = 1 }; try std.testing.expect(!routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 4, &.{}).detected); }
test "comparator maps each frequency one through fifteen" { var f: u8 = 1; while (f <= 15) : (f += 1) try std.testing.expectEqual(f, comparatorSignal(f)); }
test "comparator rejects frequencies above fifteen" { try std.testing.expectEqual(@as(u8, 0), comparatorSignal(16)); }
test "frequency zero is not a vibration detection" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; try std.testing.expect(!routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 0, &.{}).detected); }
test "frequency above fifteen is rejected" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; try std.testing.expect(!routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 16, &.{}).detected); }
test "routed vibration reports frequency and travel delay" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; const r = routeVibration(&s, .{ .x = 2.5, .y = 0.5, .z = 0.5 }, 11, &.{}); try std.testing.expect(r.detected); try std.testing.expectEqual(@as(u8, 11), r.frequency); try std.testing.expectEqual(@as(u32, 2), r.delay_ticks); }
test "redstone signal equals vibration frequency" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; _ = routeVibration(&s, .{ .x = 0.5, .y = 0.5, .z = 0.5 }, 15, &.{}); try std.testing.expectEqual(@as(u8, 15), s.comparatorOutput()); }
test "vibration activates sensor only after its travel delay" { var s = Sensor{ .position = .{ .x = 0, .y = 0, .z = 0 } }; const r = routeVibration(&s, .{ .x = 2.5, .y = 0.5, .z = 0.5 }, 6, &.{}); try std.testing.expectEqual(@as(u32, 2), r.delay_ticks); try std.testing.expect(!s.isActive()); tick(&s); try std.testing.expect(!s.isActive()); tick(&s); try std.testing.expect(s.isActive()); try std.testing.expectEqual(@as(u8, 6), s.redstone_signal); }
