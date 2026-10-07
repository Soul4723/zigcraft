const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

/// Max redstone signal strength (matches falloff: source emits 15, -1 per wire).
pub const max_strength: u4 = 15;

/// True when a block emits redstone power into adjacent wire.
pub fn isSource(b: BlockId) bool {
    return b == .pressure_plate_down or b == .lever_on or b == .repeater_on or b == .redstone_torch_on;
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
    } else {
        if (current == .wooden_door_open) return .wooden_door_closed;
        if (current == .iron_door_open) return .iron_door_closed;
    }
    return null;
}

test "targetDoorState transitions" {
    // Torch ON opens closed doors
    try std.testing.expectEqual(BlockId.wooden_door_open, targetDoorState(.wooden_door_closed, true).?);
    try std.testing.expectEqual(BlockId.iron_door_open, targetDoorState(.iron_door_closed, true).?);
    try std.testing.expect(targetDoorState(.wooden_door_open, true) == null);

    // Torch OFF closes open doors
    try std.testing.expectEqual(BlockId.wooden_door_closed, targetDoorState(.wooden_door_open, false).?);
    try std.testing.expectEqual(BlockId.iron_door_closed, targetDoorState(.iron_door_open, false).?);
    try std.testing.expect(targetDoorState(.wooden_door_closed, false) == null);

    // Non-doors ignored
    try std.testing.expect(targetDoorState(.stone, true) == null);
}
