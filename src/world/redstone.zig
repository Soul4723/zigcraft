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
