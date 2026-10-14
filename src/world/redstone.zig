const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

/// Max redstone signal strength (matches falloff: source emits 15, -1 per wire).
pub const max_strength: u4 = 15;

/// True when a block emits redstone power into adjacent wire.
pub fn isSource(b: BlockId) bool {
    return b == .pressure_plate_down or b == .lever_on or b == .repeater_on or b == .redstone_torch_on or b == .detector_rail or b == .redstone_comparator_on or b == .observer_on or b == .redstone_block;
}

/// True when a block conducts decaying signal (wire in either state).
pub fn isWire(b: BlockId) bool {
    return b == .redstone_wire_off or b == .redstone_wire_on;
}

/// One relaxation step: strength[i] rises toward (max neighbor strength) - 1.
/// `adj[i][6]` holds optional neighbor indices into the strength array, or null.
/// Returns true if any strength rose.
pub fn relaxStep(strength: []u4, adj: []const [6]?usize) bool {
    var rose = false;
    for (strength, 0..) |_, i| {
        var best: u4 = strength[i];
        for (adj[i]) |maybe_n| {
            const n = maybe_n orelse continue;
            if (strength[n] > 1) {
                const via: u4 = strength[n] - 1;
                if (via > best) best = via;
            }
        }
        if (best > strength[i]) {
            strength[i] = best;
            rose = true;
        }
    }
    return rose;
}

/// Relax until fixpoint (or `strength.len` passes cap). Seeds hold source
/// strength 15; wires start at 0. Afterward, strength[i] > 0 means powered.
pub fn relax(strength: []u4, adj: []const [6]?usize) void {
    var pass: usize = 0;
    while (pass < strength.len) : (pass += 1) {
        if (!relaxStep(strength, adj)) break;
    }
}

test "source emits 15, one wire takes 14" {
    var s = [_]u4{ 15, 0 };
    const adj = [_][6]?usize{ .{ 1, null, null, null, null, null }, .{ 0, null, null, null, null, null } };
    relax(&s, &adj);
    try std.testing.expectEqual(@as(u4, 15), s[0]);
    try std.testing.expectEqual(@as(u4, 14), s[1]);
}

test "chain of 16 wires from source: last goes dark" {
    var s = [_]u4{15} ++ [_]u4{0} ** 16;
    var adj = [_][6]?usize{[_]?usize{ null, null, null, null, null, null }} ** 17;
    var i: usize = 0;
    while (i < 17) : (i += 1) {
        if (i > 0) adj[i][0] = i - 1;
        if (i < 16) adj[i][1] = i + 1;
    }
    relax(&s, &adj);
    try std.testing.expectEqual(@as(u4, 15), s[0]);
    try std.testing.expectEqual(@as(u4, 14), s[1]);
    try std.testing.expectEqual(@as(u4, 1), s[14]);
    try std.testing.expectEqual(@as(u4, 0), s[15]);
    try std.testing.expectEqual(@as(u4, 0), s[16]);
}

test "order independence: reversed index layout converges the same" {
    var fwd = [_]u4{ 15, 0, 0, 0 };
    var rev = [_]u4{ 0, 0, 0, 15 };
    const adj_f = [_][6]?usize{
        .{ 1, null, null, null, null, null },
        .{ 0, 2, null, null, null, null },
        .{ 1, 3, null, null, null, null },
        .{ 2, null, null, null, null, null },
    };
    const adj_r = [_][6]?usize{
        .{ 1, null, null, null, null, null },
        .{ 0, 2, null, null, null, null },
        .{ 1, 3, null, null, null, null },
        .{ 2, null, null, null, null, null },
    };
    relax(&fwd, &adj_f);
    relax(&rev, &adj_r);
    try std.testing.expectEqual(fwd[0], rev[3]);
    try std.testing.expectEqual(fwd[1], rev[2]);
    try std.testing.expectEqual(fwd[2], rev[1]);
    try std.testing.expectEqual(fwd[3], rev[0]);
    try std.testing.expectEqual(@as(u4, 15), fwd[0]);
    try std.testing.expectEqual(@as(u4, 12), fwd[3]);
}

test "unpowered stays dark, source classification" {
    try std.testing.expect(isSource(.lever_on));
    try std.testing.expect(isSource(.redstone_torch_on));
    try std.testing.expect(!isSource(.lever_off));
    try std.testing.expect(!isSource(.redstone_wire_on));
    try std.testing.expect(isWire(.redstone_wire_off));
    try std.testing.expect(isWire(.redstone_wire_on));
    try std.testing.expect(!isWire(.stone));
    var s = [_]u4{ 0, 0 };
    const adj = [_][6]?usize{ .{ 1, null, null, null, null, null }, .{ 0, null, null, null, null, null } };
    relax(&s, &adj);
    try std.testing.expectEqual(@as(u4, 0), s[0]);
    try std.testing.expectEqual(@as(u4, 0), s[1]);
}

/// Repeater delay in seconds for a 1-4 tick stage (each tick is 0.1s).
pub fn repeaterDelay(stage: u2) f32 {
    return 0.1 * @as(f32, @floatFromInt(@as(u8, stage) + 1));
}

test "repeater delay stages 0.1s to 0.4s" {
    try std.testing.expectEqual(@as(f32, 0.1), repeaterDelay(0));
    try std.testing.expectEqual(@as(f32, 0.2), repeaterDelay(1));
    try std.testing.expectEqual(@as(f32, 0.3), repeaterDelay(2));
    try std.testing.expectEqual(@as(f32, 0.4), repeaterDelay(3));
}

/// Warm lamp-spill glow at distance d blocks (matches chunk frag: 1/(1+0.35 d^2)).
pub fn lampGlow(d: f32) f32 {
    return 1.0 / (1.0 + d * d * 0.35);
}

test "lamp glow falls to ~0.06 at 6 blocks" {
    try std.testing.expect(lampGlow(0.0) > 0.99);
    const g6 = lampGlow(6.0);
    try std.testing.expect(g6 > 0.05 and g6 < 0.10);
    try std.testing.expect(lampGlow(3.0) > lampGlow(6.0));
}

/// Torch burnout: how many of the last-8 flip timestamps fall within `window` of now.
pub fn recentFlips(flips: [8]f32, now: f32, window: f32) u8 {
    var n: u8 = 0;
    for (flips) |ft| {
        if (now - ft < window) n += 1;
    }
    return n;
}

/// True when flip history trips burnout (8 flips within 3.2s).
pub fn torchBurnedOut(flips: [8]f32, now: f32) bool {
    return recentFlips(flips, now, 3.2) >= 8;
}

test "torch burnout trips on 8 rapid flips" {
    const now: f32 = 100.0;
    var flips = [_]f32{-100} ** 8;
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        flips[i] = now - @as(f32, @floatFromInt(i)) * 0.3;
    }
    try std.testing.expect(!torchBurnedOut(flips, now));
    flips[7] = now - 0.1;
    try std.testing.expect(torchBurnedOut(flips, now));
    try std.testing.expect(!torchBurnedOut(flips, now + 10.0));
}

pub fn isTorchBasePowered(get: *const fn (x: i32, y: i32, z: i32) BlockId, tx: i32, ty: i32, tz: i32) bool {
    const base_y = ty - 1;
    const adj_dirs = [_][3]i32{
        .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
        .{ 0, -1, 0 },
    };
    for (adj_dirs) |ad| {
        const nb = get(tx + ad[0], base_y + ad[1], tz + ad[2]);
        if (nb == .redstone_wire_on or nb == .lever_on or nb == .pressure_plate_down) {
            return true;
        }
    }
    return false;
}

pub const target_pulse_duration: f32 = 0.4; // 8 redstone game ticks

/// Calculate redstone signal strength (1..15) emitted by a Target block based on hit distance from block face center.
/// Bullseye (distance <= 0.05) gives full 15 strength. Outer edge (distance >= 0.50) gives 1 strength.
pub fn targetSignalStrength(hit_x: f32, hit_y: f32, hit_z: f32, block_x: i32, block_y: i32, block_z: i32) u4 {
    const cx = @as(f32, @floatFromInt(block_x)) + 0.5;
    const cy = @as(f32, @floatFromInt(block_y)) + 0.5;
    const cz = @as(f32, @floatFromInt(block_z)) + 0.5;
    const dx = hit_x - cx;
    const dy = hit_y - cy;
    const dz = hit_z - cz;
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);

    // Bullseye check
    if (dist <= 0.08) return 15;
    if (dist >= 0.52) return 1;

    // Linear mapping from 0.08m (15) to 0.52m (1)
    const frac = (dist - 0.08) / (0.52 - 0.08); // 0.0 to 1.0
    const str_f = 15.0 - frac * 14.0;
    return @as(u4, @intCast(std.math.clamp(@as(i32, @intFromFloat(@round(str_f))), 1, 15)));
}

test "targetSignalStrength bullseye and edge scaling" {
    // Exact center -> 15
    try std.testing.expectEqual(@as(u4, 15), targetSignalStrength(10.5, 5.5, 20.5, 10, 5, 20));
    // Bullseye within 0.05m -> 15
    try std.testing.expectEqual(@as(u4, 15), targetSignalStrength(10.53, 5.5, 20.5, 10, 5, 20));
    // Outer edge >= 0.50m -> 1
    try std.testing.expectEqual(@as(u4, 1), targetSignalStrength(10.5, 6.02, 20.5, 10, 5, 20));
    // Midpoint ~0.30m -> ~8
    const mid_str = targetSignalStrength(10.5, 5.8, 20.5, 10, 5, 20);
    try std.testing.expect(mid_str >= 5 and mid_str <= 10);
}


pub fn isTargetHitPowered(is_hit_active: bool) bool {
    return is_hit_active;
}

pub fn isLampPowered(get: *const fn (x: i32, y: i32, z: i32) BlockId, lx: i32, ly: i32, lz: i32) bool {
    const adj_dirs = [_][3]i32{
        .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
        .{ 0, 1, 0 }, .{ 0, -1, 0 },
    };
    for (adj_dirs) |ad| {
        const nb = get(lx + ad[0], ly + ad[1], lz + ad[2]);
        if (nb == .redstone_wire_on or nb == .pressure_plate_down or nb == .lever_on or nb == .repeater_on or nb == .redstone_torch_on) {
            return true;
        }
    }
    return false;
}

pub fn isRepeaterInputPowered(get: *const fn (x: i32, y: i32, z: i32) BlockId, rx: i32, ry: i32, rz: i32) bool {
    const in_offsets = [_][3]i32{ .{ 0, 0, -1 }, .{ -1, 0, 0 }, .{ 0, -1, 0 } };
    for (in_offsets) |io| {
        const ib = get(rx + io[0], ry + io[1], rz + io[2]);
        if (ib == .redstone_wire_on or ib == .lever_on or ib == .pressure_plate_down or ib == .redstone_torch_on) {
            return true;
        }
    }
    return false;
}

fn mockDetectorWorld(x: i32, y: i32, z: i32) BlockId {
    if (x == 1 and y == 0 and z == 0) return .lever_on;
    if (x == 10 and y == 10 and z == 10) return .redstone_torch_on;
    if (x == 20 and y == 20 and z == 19) return .redstone_wire_on;
    return .air;
}

test "redstone power detector helpers" {
    // Torch at (0, 1, 0) has base block at (0, 0, 0).
    // mockDetectorWorld has lever_on at (1, 0, 0), which is adjacent to the base block.
    try std.testing.expect(isTorchBasePowered(&mockDetectorWorld, 0, 1, 0));
    try std.testing.expect(!isTorchBasePowered(&mockDetectorWorld, 5, 5, 5));

    // Lamp at (10, 9, 10) has redstone_torch_on above it at (10, 10, 10).
    try std.testing.expect(isLampPowered(&mockDetectorWorld, 10, 9, 10));
    try std.testing.expect(!isLampPowered(&mockDetectorWorld, 0, 5, 0));

    // Repeater at (20, 20, 20) checks (20, 20, 19) which is repeater_on in mock world.
    try std.testing.expect(isRepeaterInputPowered(&mockDetectorWorld, 20, 20, 20));
    try std.testing.expect(!isRepeaterInputPowered(&mockDetectorWorld, 0, 0, 0));
}

pub const torch_door_dirs = [_][3]i32{
    .{ 1, 0, 0 },
    .{ -1, 0, 0 },
    .{ 0, 0, 1 },
    .{ 0, 0, -1 },
    .{ 0, 1, 0 },
    .{ 0, -1, 0 },
};

pub fn targetDoorState(current: BlockId, torch_lit: bool) ?BlockId {
    if (torch_lit) {
        if (current == .wooden_door_closed) return .wooden_door_open;
        if (current == .iron_door_closed) return .iron_door_open;
        if (current == .wooden_trapdoor_closed) return .wooden_trapdoor_open;
        if (current == .iron_trapdoor_closed) return .iron_trapdoor_open;
    } else {
        if (current == .wooden_door_open) return .wooden_door_closed;
        if (current == .iron_door_open) return .iron_door_closed;
        if (current == .wooden_trapdoor_open) return .wooden_trapdoor_closed;
        if (current == .iron_trapdoor_open) return .iron_trapdoor_closed;
    }
    return null;
}

test "targetDoorState transitions" {
    // Torch ON opens closed doors and trapdoors
    try std.testing.expectEqual(BlockId.wooden_door_open, targetDoorState(.wooden_door_closed, true).?);
    try std.testing.expectEqual(BlockId.iron_door_open, targetDoorState(.iron_door_closed, true).?);
    try std.testing.expectEqual(BlockId.wooden_trapdoor_open, targetDoorState(.wooden_trapdoor_closed, true).?);
    try std.testing.expectEqual(BlockId.iron_trapdoor_open, targetDoorState(.iron_trapdoor_closed, true).?);
    try std.testing.expect(targetDoorState(.wooden_door_open, true) == null);
    try std.testing.expect(targetDoorState(.wooden_trapdoor_open, true) == null);

    // Torch OFF closes open doors and trapdoors
    try std.testing.expectEqual(BlockId.wooden_door_closed, targetDoorState(.wooden_door_open, false).?);
    try std.testing.expectEqual(BlockId.iron_door_closed, targetDoorState(.iron_door_open, false).?);
    try std.testing.expectEqual(BlockId.wooden_trapdoor_closed, targetDoorState(.wooden_trapdoor_open, false).?);
    try std.testing.expectEqual(BlockId.iron_trapdoor_closed, targetDoorState(.iron_trapdoor_open, false).?);
    try std.testing.expect(targetDoorState(.wooden_door_closed, false) == null);
    try std.testing.expect(targetDoorState(.wooden_trapdoor_closed, false) == null);

    // Non-doors ignored
    try std.testing.expect(targetDoorState(.stone, true) == null);
}

pub const LampUpdate = enum {
    none,
    turn_on,
    turn_off,
};

pub fn resolveLampState(is_lit: bool, power_in: bool) LampUpdate {
    if (power_in and !is_lit) return .turn_on;
    if (!power_in and is_lit) return .turn_off;
    return .none;
}

test "target block pulse helper" {
    try std.testing.expect(isTargetHitPowered(true));
    try std.testing.expect(!isTargetHitPowered(false));
    try std.testing.expectEqual(@as(f32, 0.4), target_pulse_duration);
}

test "resolveLampState transitions" {
    try std.testing.expectEqual(LampUpdate.turn_on, resolveLampState(false, true));
    try std.testing.expectEqual(LampUpdate.turn_off, resolveLampState(true, false));
    try std.testing.expectEqual(LampUpdate.none, resolveLampState(false, false));
    try std.testing.expectEqual(LampUpdate.none, resolveLampState(true, true));
}

pub fn relaxWireStrength(
    current_strength: u4,
    neighbors: []const u4,
) u4 {
    var best = current_strength;
    for (neighbors) |n| {
        if (n > 1) {
            const via = n - 1;
            if (via > best) best = via;
        }
    }
    return best;
}

test "relaxWireStrength signal decay" {
    // Current 0, neighbor 15 -> becomes 14
    try std.testing.expectEqual(@as(u4, 14), relaxWireStrength(0, &.{15}));
    // Neighbor 1 -> cannot power beyond (dies at 0)
    try std.testing.expectEqual(@as(u4, 0), relaxWireStrength(0, &.{1}));
    // Keeps higher existing strength
    try std.testing.expectEqual(@as(u4, 12), relaxWireStrength(12, &.{10}));
}

pub fn isDispenserPowered(get: *const fn (x: i32, y: i32, z: i32) BlockId, dx: i32, dy: i32, dz: i32) bool {
    const adj_dirs = [_][3]i32{
        .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
        .{ 0, 1, 0 }, .{ 0, -1, 0 },
    };
    for (adj_dirs) |ad| {
        const nb = get(dx + ad[0], dy + ad[1], dz + ad[2]);
        if (nb == .redstone_wire_on or nb == .pressure_plate_down or nb == .lever_on or nb == .repeater_on or nb == .redstone_torch_on) {
            return true;
        }
    }
    return false;
}

test "isDispenserPowered adjacent detection" {
    const mock = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (x == 10 and y == 5 and z == 21) return .redstone_wire_on;
            return .stone;
        }
    }.get;
    try std.testing.expect(isDispenserPowered(mock, 10, 5, 20));
    try std.testing.expect(!isDispenserPowered(mock, 10, 5, 10));
}

pub fn daylightSignalStrength(sun_y: f32, inverted: bool) u4 {
    if (!inverted) {
        // Standard daylight sensor: max strength (15) at high noon (sun_y >= 0.8), 0 when sun is below horizon
        if (sun_y <= 0.0) return 0;
        const normalized = @min(1.0, sun_y / 0.8);
        return @intFromFloat(@round(normalized * 15.0));
    } else {
        // Inverted daylight sensor: max strength (15) at dead of night (sun_y <= -0.8), 0 when sun is high
        if (sun_y >= 0.0) return 0;
        const normalized = @min(1.0, -sun_y / 0.8);
        return @intFromFloat(@round(normalized * 15.0));
    }
}

test "daylightSignalStrength day and inverted night scaling" {
    // High noon
    try std.testing.expectEqual(@as(u4, 15), daylightSignalStrength(0.9, false));
    try std.testing.expectEqual(@as(u4, 0), daylightSignalStrength(0.9, true));

    // Midday
    try std.testing.expect(daylightSignalStrength(0.4, false) >= 7);
    try std.testing.expect(daylightSignalStrength(0.4, false) <= 9);

    // Sunset / twilight
    try std.testing.expectEqual(@as(u4, 0), daylightSignalStrength(0.0, false));
    try std.testing.expectEqual(@as(u4, 0), daylightSignalStrength(0.0, true));

    // Midnight
    try std.testing.expectEqual(@as(u4, 0), daylightSignalStrength(-0.9, false));
    try std.testing.expectEqual(@as(u4, 15), daylightSignalStrength(-0.9, true));
}

pub const NoteInstrument = enum { harp, bass, snare, chime };

pub fn getNoteInstrument(floor_block: BlockId) NoteInstrument {
    return switch (floor_block) {
        .wood, .wood_planks, .crafting_table => .bass,
        .sand, .soul_sand => .snare,
        .glass, .glowstone, .beacon => .chime,
        else => .harp, // dirt, stone, air, etc. default to acoustic piano/harp
    };
}

pub fn notePitchFrequencyMultiplier(pitch_semitones: u5) f32 {
    // 24 semitones (2 full octaves): 2^(semitones / 12)
    const st = @as(f32, @floatFromInt(pitch_semitones));
    return @exp(st * 0.057762265); // ln(2)/12 = 0.057762265
}

test "getNoteInstrument acoustic mapping" {
    try std.testing.expectEqual(NoteInstrument.bass, getNoteInstrument(.wood));
    try std.testing.expectEqual(NoteInstrument.bass, getNoteInstrument(.wood_planks));
    try std.testing.expectEqual(NoteInstrument.snare, getNoteInstrument(.sand));
    try std.testing.expectEqual(NoteInstrument.snare, getNoteInstrument(.soul_sand));
    try std.testing.expectEqual(NoteInstrument.chime, getNoteInstrument(.glass));
    try std.testing.expectEqual(NoteInstrument.chime, getNoteInstrument(.glowstone));
    try std.testing.expectEqual(NoteInstrument.harp, getNoteInstrument(.dirt));
    try std.testing.expectEqual(NoteInstrument.harp, getNoteInstrument(.stone));
}

test "notePitchFrequencyMultiplier two octave progression" {
    try std.testing.expectApproxEqAbs(notePitchFrequencyMultiplier(0), 1.0, 0.01);
    try std.testing.expectApproxEqAbs(notePitchFrequencyMultiplier(12), 2.0, 0.02);
    try std.testing.expectApproxEqAbs(notePitchFrequencyMultiplier(24), 4.0, 0.05);
}

test "detector rail is redstone source" {
    try std.testing.expect(isSource(.detector_rail));
    try std.testing.expect(!isSource(.activator_rail));
    try std.testing.expect(!isSource(.rail));
}


pub const ComparatorMode = enum {
    compare,
    subtract,
};

/// Evaluates redstone comparator output signal strength:
/// In compare mode: outputs input strength if input >= max(sideA, sideB), else 0.
/// In subtract mode: outputs max(0, input - max(sideA, sideB)).
pub fn evaluateComparatorSignal(input_strength: u4, side_a_strength: u4, side_b_strength: u4, mode: ComparatorMode) u4 {
    const max_side = @max(side_a_strength, side_b_strength);
    return switch (mode) {
        .compare => if (input_strength >= max_side) input_strength else 0,
        .subtract => if (input_strength > max_side) input_strength - max_side else 0,
    };
}

/// Evaluates container fullness to comparator signal strength (0..15).
/// Empty = 0, full = 15, non-empty partial = 1 + floor(14 * fullness).
pub fn containerComparatorSignal(filled_slots: usize, total_slots: usize) u4 {
    if (filled_slots == 0 or total_slots == 0) return 0;
    if (filled_slots >= total_slots) return 15;
    const fraction = @as(f32, @floatFromInt(filled_slots)) / @as(f32, @floatFromInt(total_slots));
    const signal: u4 = @intFromFloat(@floor(1.0 + fraction * 14.0));
    return @min(15, signal);
}


test "redstone comparator signal evaluation compare and subtract modes" {
    // Compare mode: input 10, sides 8 and 4 -> output 10
    try std.testing.expectEqual(@as(u4, 10), evaluateComparatorSignal(10, 8, 4, .compare));
    // Compare mode: input 10, side 12 -> output 0
    try std.testing.expectEqual(@as(u4, 0), evaluateComparatorSignal(10, 12, 4, .compare));
    // Compare mode: input == side -> output passes
    try std.testing.expectEqual(@as(u4, 10), evaluateComparatorSignal(10, 10, 0, .compare));

    // Subtract mode: input 15, max side 5 -> 10
    try std.testing.expectEqual(@as(u4, 10), evaluateComparatorSignal(15, 5, 3, .subtract));
    // Subtract mode: input 8, max side 10 -> 0 (clamped)
    try std.testing.expectEqual(@as(u4, 0), evaluateComparatorSignal(8, 10, 0, .subtract));
}

test "containerComparatorSignal inventory fill levels" {
    // Empty container
    try std.testing.expectEqual(@as(u4, 0), containerComparatorSignal(0, 27));
    // 1 item in large chest (27 slots) -> minimal signal 1
    try std.testing.expectEqual(@as(u4, 1), containerComparatorSignal(1, 27));
    // Half full (14/27) -> ~8
    try std.testing.expectEqual(@as(u4, 8), containerComparatorSignal(14, 27));
    // Completely full -> 15
    try std.testing.expectEqual(@as(u4, 15), containerComparatorSignal(27, 27));
}

pub const PistonFacing = enum(u3) {
    up = 0,
    down = 1,
    north = 2,
    south = 3,
    west = 4,
    east = 5,

    pub fn offset(self: PistonFacing) [3]i32 {
        return switch (self) {
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .west => .{ -1, 0, 0 },
            .east => .{ 1, 0, 0 },
        };
    }
};

pub const max_piston_push_limit: usize = 12;

/// Checks if a block is immovable by pistons (obsidian, bedrock, portals, command blocks, beacons).
pub fn isPistonImmovable(b: block_mod.BlockId) bool {
    return b == .obsidian or b == .crying_obsidian or b == .respawn_anchor or b == .nether_portal or b == .end_portal or b == .end_portal_frame or b == .end_portal_frame_filled or b == .end_gateway or b == .beacon;
}

pub const PistonPushPlan = struct {
    can_push: bool,
    block_count: usize,
    blocks: [max_piston_push_limit][3]i32,
};

/// Evaluates linear block displacement in the piston push direction.
/// Returns push plan with blocks to displace, or can_push = false if obstructed or exceeds 12 blocks.
pub fn calculatePistonPush(
    piston_x: i32,
    piston_y: i32,
    piston_z: i32,
    facing: PistonFacing,
    world_fn: *const fn (x: i32, y: i32, z: i32) block_mod.BlockId,
) PistonPushPlan {
    const off = facing.offset();
    var plan = PistonPushPlan{
        .can_push = false,
        .block_count = 0,
        .blocks = undefined,
    };

    var cur_x = piston_x + off[0];
    var cur_y = piston_y + off[1];
    var cur_z = piston_z + off[2];

    while (plan.block_count < max_piston_push_limit) {
        const b = world_fn(cur_x, cur_y, cur_z);
        if (b == .air) {
            plan.can_push = true;
            return plan;
        }
        if (isPistonImmovable(b)) {
            plan.can_push = false;
            return plan;
        }
        plan.blocks[plan.block_count] = .{ cur_x, cur_y, cur_z };
        plan.block_count += 1;
        cur_x += off[0];
        cur_y += off[1];
        cur_z += off[2];
    }

    // Next must be air to allow moving the 12 blocks
    const final_b = world_fn(cur_x, cur_y, cur_z);
    plan.can_push = (final_b == .air);
    return plan;
}

/// Evaluates block retracted by a sticky piston. Returns coordinates of block pulled back if sticky and movable.
pub fn calculateStickyRetract(
    head_x: i32,
    head_y: i32,
    head_z: i32,
    facing: PistonFacing,
    world_fn: *const fn (x: i32, y: i32, z: i32) block_mod.BlockId,
) ?[3]i32 {
    const off = facing.offset();
    const target_x = head_x + off[0];
    const target_y = head_y + off[1];
    const target_z = head_z + off[2];
    const b = world_fn(target_x, target_y, target_z);
    if (b == .air or isPistonImmovable(b)) return null;
    return .{ target_x, target_y, target_z };
}

test "piston push calculation and limit enforcement" {
    const MockWorld = struct {
        fn getBlock(x: i32, y: i32, z: i32) block_mod.BlockId {
            _ = y; _ = z;
            // Stone at x = 1, 2, 3; air at x >= 4
            if (x >= 1 and x <= 3) return .stone;
            return .air;
        }
        fn getImmovable(x: i32, y: i32, z: i32) block_mod.BlockId {
            _ = y; _ = z;
            if (x == 1) return .obsidian;
            return .air;
        }
    };

    // Piston at x=0 pushing east towards x=1..3
    const plan = calculatePistonPush(0, 0, 0, .east, &MockWorld.getBlock);
    try std.testing.expect(plan.can_push);
    try std.testing.expectEqual(@as(usize, 3), plan.block_count);
    try std.testing.expectEqual(@as(i32, 1), plan.blocks[0][0]);
    try std.testing.expectEqual(@as(i32, 2), plan.blocks[1][0]);
    try std.testing.expectEqual(@as(i32, 3), plan.blocks[2][0]);

    // Piston blocked by immovable obsidian
    const plan_blocked = calculatePistonPush(0, 0, 0, .east, &MockWorld.getImmovable);
    try std.testing.expect(!plan_blocked.can_push);
}

test "sticky piston retract target block" {
    const MockWorld = struct {
        fn getBlock(x: i32, y: i32, z: i32) block_mod.BlockId {
            _ = y; _ = z;
            if (x == 2) return .wood_planks;
            return .air;
        }
    };
    // Head at x=1 facing east; target at x=2 is wood_planks
    const pull = calculateStickyRetract(1, 0, 0, .east, &MockWorld.getBlock);
    try std.testing.expect(pull != null);
    try std.testing.expectEqual(@as(i32, 2), pull.?[0]);
}

pub const observer_pulse_duration: f32 = 0.10; // 1 redstone tick (0.1s / 2 game ticks)

pub const ObserverState = struct {
    x: i32,
    y: i32,
    z: i32,
    facing: PistonFacing,
    observed_last: block_mod.BlockId,
    pulse_timer: f32 = 0.0,
};

/// Updates an observer state: if observed block in front changes, triggers 0.10s pulse.
/// Returns whether observer output is currently energized (observer_on).
pub fn tickObserver(
    obs: *ObserverState,
    current_observed: block_mod.BlockId,
    dt: f32,
) bool {
    if (obs.pulse_timer > 0.0) {
        obs.pulse_timer = @max(0.0, obs.pulse_timer - dt);
        obs.observed_last = current_observed;
        return obs.pulse_timer > 0.0;
    }

    if (current_observed != obs.observed_last) {
        obs.observed_last = current_observed;
        obs.pulse_timer = observer_pulse_duration;
        return true;
    }

    return false;
}

test "observer pulse emission and block update detection" {
    try std.testing.expect(isSource(.observer_on));
    try std.testing.expect(!isSource(.observer_off));
    try std.testing.expect(isSource(.redstone_block));

    var obs = ObserverState{
        .x = 0,
        .y = 5,
        .z = 0,
        .facing = .north,
        .observed_last = .stone,
        .pulse_timer = 0.0,
    };

    // No change: stone remains stone -> unpowered
    try std.testing.expect(!tickObserver(&obs, .stone, 0.05));

    // Block update: stone broken to air -> triggers pulse!
    try std.testing.expect(tickObserver(&obs, .air, 0.05));
    try std.testing.expect(obs.pulse_timer > 0.0);

    // Pulse continues during 0.1s window (consumed 0.04s, 0.06s left)
    try std.testing.expect(tickObserver(&obs, .air, 0.04));

    // Pulse expires after remaining duration (consumed 0.07s -> 0.0s)
    _ = tickObserver(&obs, .air, 0.07);
    try std.testing.expect(!tickObserver(&obs, .air, 0.01));
}

/// Convert redstone ore to lit redstone ore on strike/step, or tick back to unlit after decay.
pub fn updateRedstoneOreState(current: BlockId, interact_or_step: bool) ?BlockId {
    if (interact_or_step) {
        if (current == .redstone_ore) return .lit_redstone_ore;
    } else {
        if (current == .lit_redstone_ore) return .redstone_ore;
    }
    return null;
}

test "updateRedstoneOreState lighting and decay" {
    try std.testing.expectEqual(BlockId.lit_redstone_ore, updateRedstoneOreState(.redstone_ore, true).?);
    try std.testing.expect(updateRedstoneOreState(.lit_redstone_ore, true) == null);
    try std.testing.expectEqual(BlockId.redstone_ore, updateRedstoneOreState(.lit_redstone_ore, false).?);
    try std.testing.expect(updateRedstoneOreState(.redstone_ore, false) == null);
    try std.testing.expect(updateRedstoneOreState(.stone, true) == null);
}
