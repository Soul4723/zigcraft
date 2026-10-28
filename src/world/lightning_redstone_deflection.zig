const std = @import("std");

pub const attraction_half_extent: i32 = 64;
pub const redstone_pulse_duration_ticks: u8 = 8;
pub const copper_shockwave_radius: f64 = 3.0;

pub const Point = [3]i32;
pub const OxidationStage = enum(u8) { unoxidized, exposed, weathered, oxidized };
pub const CopperBlock = struct { position: Point, stage: OxidationStage, waxed: bool = false };

pub const RodPulse = struct {
    ticks_remaining: u8 = 0,
    pub fn signalStrength(self: RodPulse) u4 {
        return if (self.ticks_remaining > 0) 15 else 0;
    }
    pub fn strike(self: *RodPulse) void {
        self.ticks_remaining = redstone_pulse_duration_ticks;
    }
    pub fn tick(self: *RodPulse) void {
        if (self.ticks_remaining > 0) self.ticks_remaining -= 1;
    }
};

pub fn isWithinAttractionBox(strike: Point, rod: Point) bool {
    const dx = @abs(@as(i64, strike[0]) - rod[0]);
    const dz = @abs(@as(i64, strike[2]) - rod[2]);
    return dx <= attraction_half_extent and dz <= attraction_half_extent;
}

pub fn horizontalDistanceSquared(a: Point, b: Point) u64 {
    const dx = @as(i64, a[0]) - b[0];
    const dz = @as(i64, a[2]) - b[2];
    return @intCast(dx * dx + dz * dz);
}

pub fn nearestAttractingRod(strike: Point, rods: []const Point) ?usize {
    var nearest: ?usize = null;
    var best: u64 = std.math.maxInt(u64);
    for (rods, 0..) |rod, index| {
        if (!isWithinAttractionBox(strike, rod)) continue;
        const distance = horizontalDistanceSquared(strike, rod);
        if (distance < best) {
            best = distance;
            nearest = index;
        }
    }
    return nearest;
}

pub fn copperWithinShockwave(a: Point, b: Point) bool {
    const dx = @as(i64, a[0]) - b[0];
    const dy = @as(i64, a[1]) - b[1];
    const dz = @as(i64, a[2]) - b[2];
    const manhattan = @abs(dx) + @abs(dy) + @abs(dz);
    const euclidean_squared = dx * dx + dy * dy + dz * dz;
    return manhattan <= 3 or euclidean_squared <= 9;
}

pub fn applyCopperShockwave(center: Point, blocks: []CopperBlock) usize {
    var changed: usize = 0;
    for (blocks) |*block| {
        if (!copperWithinShockwave(center, block.position)) continue;
        var did_change = false;
        if (block.waxed) {
            block.waxed = false;
            did_change = true;
        }
        switch (block.stage) {
            .oxidized => {
                block.stage = .weathered;
                did_change = true;
            },
            .weathered => {
                block.stage = .exposed;
                did_change = true;
            },
            .exposed => {
                block.stage = .unoxidized;
                did_change = true;
            },
            .unoxidized => {},
        }
        if (did_change) changed += 1;
    }
    return changed;
}

pub const ChannelingTarget = enum { entity, lightning_rod, other };
pub fn canChannelStrike(has_channeling: bool, weather: enum { clear, rain, thunderstorm }, target: ChannelingTarget, open_rain: bool) bool {
    return has_channeling and weather == .thunderstorm and open_rain and target != .other;
}

test "attraction box includes inclusive horizontal edges and ignores altitude" {
    try std.testing.expect(isWithinAttractionBox(.{ 64, 10000, -64 }, .{ 0, -100, 0 }));
}
test "attraction box rejects east edge overflow" {
    try std.testing.expect(!isWithinAttractionBox(.{ 65, 0, 0 }, .{ 0, 0, 0 }));
}
test "attraction box rejects north edge overflow" {
    try std.testing.expect(!isWithinAttractionBox(.{ 0, 0, -65 }, .{ 0, 0, 0 }));
}
test "attraction box is square rather than circular" {
    try std.testing.expect(isWithinAttractionBox(.{ 64, 0, 64 }, .{ 0, 0, 0 }));
}
test "nearest rod compares horizontal distance" {
    const rods = [_]Point{ .{ 10, 0, 0 }, .{ 0, 1000, 5 } };
    try std.testing.expectEqual(@as(?usize, 1), nearestAttractingRod(.{ 0, 0, 0 }, &rods));
}
test "nearest rod ignores those outside box" {
    const rods = [_]Point{ .{ 65, 0, 0 }, .{ 12, 0, 0 } };
    try std.testing.expectEqual(@as(?usize, 1), nearestAttractingRod(.{ 0, 0, 0 }, &rods));
}
test "equal distance preserves first rod" {
    const rods = [_]Point{ .{ 2, 0, 0 }, .{ -2, 0, 0 } };
    try std.testing.expectEqual(@as(?usize, 0), nearestAttractingRod(.{ 0, 0, 0 }, &rods));
}
test "no rod returns null" {
    try std.testing.expectEqual(@as(?usize, null), nearestAttractingRod(.{ 0, 0, 0 }, &.{}));
}
test "distance squared uses X and Z" {
    try std.testing.expectEqual(@as(u64, 25), horizontalDistanceSquared(.{ 3, 100, 4 }, .{ 0, -100, 0 }));
}
test "pulse starts at strength fifteen for eight ticks" {
    var pulse = RodPulse{};
    pulse.strike();
    try std.testing.expectEqual(@as(u4, 15), pulse.signalStrength());
    try std.testing.expectEqual(@as(u8, 8), pulse.ticks_remaining);
}
test "pulse remains active through seven ticks" {
    var pulse = RodPulse{};
    pulse.strike();
    for (0..7) |_| pulse.tick();
    try std.testing.expectEqual(@as(u4, 15), pulse.signalStrength());
}
test "pulse expires on eighth tick" {
    var pulse = RodPulse{};
    pulse.strike();
    for (0..8) |_| pulse.tick();
    try std.testing.expectEqual(@as(u4, 0), pulse.signalStrength());
}
test "pulse countdown does not underflow" {
    var pulse = RodPulse{};
    pulse.tick();
    try std.testing.expectEqual(@as(u8, 0), pulse.ticks_remaining);
}
test "oxidized copper regresses to weathered" {
    var blocks = [_]CopperBlock{.{ .position = .{ 0, 0, 0 }, .stage = .oxidized }};
    _ = applyCopperShockwave(.{ 0, 0, 0 }, &blocks);
    try std.testing.expectEqual(OxidationStage.weathered, blocks[0].stage);
}
test "weathered copper regresses to exposed" {
    var blocks = [_]CopperBlock{.{ .position = .{ 0, 0, 0 }, .stage = .weathered }};
    _ = applyCopperShockwave(.{ 0, 0, 0 }, &blocks);
    try std.testing.expectEqual(OxidationStage.exposed, blocks[0].stage);
}
test "exposed copper regresses to unoxidized" {
    var blocks = [_]CopperBlock{.{ .position = .{ 0, 0, 0 }, .stage = .exposed }};
    _ = applyCopperShockwave(.{ 0, 0, 0 }, &blocks);
    try std.testing.expectEqual(OxidationStage.unoxidized, blocks[0].stage);
}
test "shockwave removes wax and oxidation in one burst" {
    var blocks = [_]CopperBlock{.{ .position = .{ 0, 0, 0 }, .stage = .oxidized, .waxed = true }};
    _ = applyCopperShockwave(.{ 0, 0, 0 }, &blocks);
    try std.testing.expect(!blocks[0].waxed);
    try std.testing.expectEqual(OxidationStage.weathered, blocks[0].stage);
}
test "shockwave includes Manhattan radius three" {
    try std.testing.expect(copperWithinShockwave(.{ 0, 0, 0 }, .{ 1, 1, 1 }));
}
test "shockwave includes Euclidean radius three" {
    try std.testing.expect(copperWithinShockwave(.{ 0, 0, 0 }, .{ 3, 0, 0 }));
}
test "shockwave excludes beyond radius" {
    try std.testing.expect(!copperWithinShockwave(.{ 0, 0, 0 }, .{ 4, 0, 0 }));
}
test "clean copper remains unchanged" {
    var blocks = [_]CopperBlock{.{ .position = .{ 0, 0, 0 }, .stage = .unoxidized }};
    try std.testing.expectEqual(@as(usize, 0), applyCopperShockwave(.{ 0, 0, 0 }, &blocks));
}
test "channeling entity target needs thunderstorm and open rain" {
    try std.testing.expect(canChannelStrike(true, .thunderstorm, .entity, true));
    try std.testing.expect(!canChannelStrike(true, .thunderstorm, .entity, false));
}
test "channeling rod target works in thunderstorm" {
    try std.testing.expect(canChannelStrike(true, .thunderstorm, .lightning_rod, true));
}
test "channeling rejects clear weather and ordinary rain" {
    try std.testing.expect(!canChannelStrike(true, .clear, .entity, true));
    try std.testing.expect(!canChannelStrike(true, .rain, .entity, true));
}
test "channeling requires enchantment and valid target" {
    try std.testing.expect(!canChannelStrike(false, .thunderstorm, .entity, true));
    try std.testing.expect(!canChannelStrike(true, .thunderstorm, .other, true));
}
