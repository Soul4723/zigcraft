const std = @import("std");
const latch = @import("copper_bulb_latch.zig");

pub const DISPLAY_WIDTH: u8 = 3;
pub const DISPLAY_HEIGHT: u8 = 5;
pub const DISPLAY_DEPTH: u8 = 1;
pub const BULB_COUNT: usize = 13;

pub const Segment = enum(u3) {
    segment_a,
    segment_b,
    segment_c,
    segment_d,
    segment_e,
    segment_f,
    segment_g,

    pub fn bit(self: Segment) u7 {
        return @as(u7, 1) << @intFromEnum(self);
    }
};

pub const segment_a: u7 = 0x01;
pub const segment_b: u7 = 0x02;
pub const segment_c: u7 = 0x04;
pub const segment_d: u7 = 0x08;
pub const segment_e: u7 = 0x10;
pub const segment_f: u7 = 0x20;
pub const segment_g: u7 = 0x40;
pub const ALL_SEGMENTS: u7 = 0x7f;

pub const Coord = struct { x: u8, y: u8, z: u8 = 0 };
pub const SegmentLayout = struct { coords: [3]Coord, len: u2 };

/// Horizontal bars have three bulbs; the 3-by-5 layout gives each vertical
/// segment one bulb between its adjacent horizontal bars.
pub const segment_layout = [_]SegmentLayout{
    .{ .coords = .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 2, .y = 0 } }, .len = 3 }, // a
    .{ .coords = .{ .{ .x = 2, .y = 1 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } }, .len = 1 }, // b
    .{ .coords = .{ .{ .x = 2, .y = 3 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } }, .len = 1 }, // c
    .{ .coords = .{ .{ .x = 0, .y = 4 }, .{ .x = 1, .y = 4 }, .{ .x = 2, .y = 4 } }, .len = 3 }, // d
    .{ .coords = .{ .{ .x = 0, .y = 3 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } }, .len = 1 }, // e
    .{ .coords = .{ .{ .x = 0, .y = 1 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } }, .len = 1 }, // f
    .{ .coords = .{ .{ .x = 0, .y = 2 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 } }, .len = 3 }, // g
};

pub const digit_masks = [_]u7{
    0x3f, 0x06, 0x5b, 0x4f, 0x66,
    0x6d, 0x7d, 0x07, 0x7f, 0x6f,
};

pub fn decodeDigit(digit: u8) ?u7 {
    if (digit >= digit_masks.len) return null;
    return digit_masks[digit];
}

/// Saturate values above 9 to 9 for callers that explicitly want clamping.
pub fn decodeDigitClamped(digit: u8) u7 {
    return digit_masks[@min(digit, 9)];
}

pub const Refresh = struct {
    changed_segments: u7 = 0,
    pulses: u8 = 0,
};

pub const DigitUpdate = struct {
    valid: bool,
    refresh: Refresh,
};

/// Matrix of individually oxidizing copper bulbs for one seven-segment digit.
pub const CopperBulbDisplay = struct {
    bulbs: [BULB_COUNT]latch.CopperBulb = [_]latch.CopperBulb{.{}} ** BULB_COUNT,
    current_mask: u7 = 0,

    pub fn setMask(self: *CopperBulbDisplay, desired_mask: u7) Refresh {
        const desired = desired_mask & ALL_SEGMENTS;
        const changed = desired ^ self.current_mask;
        var report = Refresh{ .changed_segments = changed };
        for (segment_layout, 0..) |layout, segment_index| {
            const bit: u7 = @as(u7, 1) << @intCast(segment_index);
            if ((changed & bit) == 0) continue;
            const start = segmentStart(segment_index);
            for (0..layout.len) |offset| {
                self.bulbs[start + offset].is_lit = (desired & bit) != 0;
                report.pulses += 1;
            }
        }
        self.current_mask = desired;
        return report;
    }

    /// Invalid digits blank the display and report `valid = false`.
    pub fn setDigit(self: *CopperBulbDisplay, digit: u8) DigitUpdate {
        if (decodeDigit(digit)) |mask| return .{ .valid = true, .refresh = self.setMask(mask) };
        return .{ .valid = false, .refresh = self.setMask(0) };
    }

    pub fn getLightLevel(self: CopperBulbDisplay, coord: Coord) ?u8 {
        for (self.bulbs, 0..) |bulb, index| {
            if (std.meta.eql(coord, bulbCoord(index))) return bulb.getLightLevel();
        }
        return null;
    }

    pub fn totalLightEmission(self: CopperBulbDisplay) u16 {
        var total: u16 = 0;
        for (self.bulbs) |bulb| total += bulb.getLightLevel();
        return total;
    }
};

pub const Cascade = struct {
    tens: CopperBulbDisplay = .{},
    ones: CopperBulbDisplay = .{},

    /// Display values 0..99 as two digits. Out-of-range input blanks both.
    pub fn showNumber(self: *Cascade, value: u8) bool {
        if (value > 99) {
            _ = self.tens.setMask(0);
            _ = self.ones.setMask(0);
            return false;
        }
        _ = self.tens.setDigit(value / 10);
        _ = self.ones.setDigit(value % 10);
        return true;
    }
};

fn segmentStart(segment_index: usize) usize {
    return switch (segment_index) {
        0 => 0,
        1 => 3,
        2 => 4,
        3 => 5,
        4 => 8,
        5 => 9,
        6 => 10,
        else => unreachable,
    };
}

pub fn bulbCoord(index: usize) Coord {
    for (segment_layout, 0..) |layout, segment_index| {
        const start = segmentStart(segment_index);
        if (index >= start and index < start + layout.len) return layout.coords[index - start];
    }
    unreachable;
}

test "display bounds are three by five by one" {
    try std.testing.expectEqual(@as(u8, 3), DISPLAY_WIDTH);
    try std.testing.expectEqual(@as(u8, 5), DISPLAY_HEIGHT);
    try std.testing.expectEqual(@as(u8, 1), DISPLAY_DEPTH);
}

test "segment bits use a through g ordering" {
    try std.testing.expectEqual(@as(u7, 0x01), segment_a);
    try std.testing.expectEqual(@as(u7, 0x02), segment_b);
    try std.testing.expectEqual(@as(u7, 0x04), segment_c);
    try std.testing.expectEqual(@as(u7, 0x08), segment_d);
    try std.testing.expectEqual(@as(u7, 0x10), segment_e);
    try std.testing.expectEqual(@as(u7, 0x20), segment_f);
    try std.testing.expectEqual(@as(u7, 0x40), segment_g);
}

test "seven segments contain thirteen bulbs with unique coordinates" {
    try std.testing.expectEqual(@as(usize, 13), BULB_COUNT);
    for (0..BULB_COUNT) |i| for (i + 1..BULB_COUNT) |j| {
        try std.testing.expect(!std.meta.eql(bulbCoord(i), bulbCoord(j)));
    };
}

test "each segment lies within display bounds" {
    for (segment_layout) |layout| for (layout.coords[0..layout.len]) |coord| {
        try std.testing.expect(coord.x < DISPLAY_WIDTH);
        try std.testing.expect(coord.y < DISPLAY_HEIGHT);
        try std.testing.expect(coord.z < DISPLAY_DEPTH);
    };
}

test "top bar a occupies the top row" {
    for (segment_layout[0].coords) |coord| try std.testing.expectEqual(@as(u8, 0), coord.y);
}
test "segment b occupies upper right column" {
    for (segment_layout[1].coords[0..1]) |coord| try std.testing.expectEqual(@as(u8, 2), coord.x);
}
test "segment c occupies lower right column" {
    for (segment_layout[2].coords[0..1]) |coord| try std.testing.expectEqual(@as(u8, 2), coord.x);
}
test "segment d occupies bottom row" {
    for (segment_layout[3].coords) |coord| try std.testing.expectEqual(@as(u8, 4), coord.y);
}
test "segment e occupies lower left column" {
    for (segment_layout[4].coords[0..1]) |coord| try std.testing.expectEqual(@as(u8, 0), coord.x);
}
test "segment f occupies upper left column" {
    for (segment_layout[5].coords[0..1]) |coord| try std.testing.expectEqual(@as(u8, 0), coord.x);
}
test "segment g occupies center row" {
    for (segment_layout[6].coords) |coord| try std.testing.expectEqual(@as(u8, 2), coord.y);
}

test "decoder returns zero mask" { try std.testing.expectEqual(@as(?u7, 0x3f), decodeDigit(0)); }
test "decoder returns one mask" { try std.testing.expectEqual(@as(?u7, 0x06), decodeDigit(1)); }
test "decoder returns two mask" { try std.testing.expectEqual(@as(?u7, 0x5b), decodeDigit(2)); }
test "decoder returns three mask" { try std.testing.expectEqual(@as(?u7, 0x4f), decodeDigit(3)); }
test "decoder returns four mask" { try std.testing.expectEqual(@as(?u7, 0x66), decodeDigit(4)); }
test "decoder returns five mask" { try std.testing.expectEqual(@as(?u7, 0x6d), decodeDigit(5)); }
test "decoder returns six mask" { try std.testing.expectEqual(@as(?u7, 0x7d), decodeDigit(6)); }
test "decoder returns seven mask" { try std.testing.expectEqual(@as(?u7, 0x07), decodeDigit(7)); }
test "decoder returns eight mask" { try std.testing.expectEqual(@as(?u7, 0x7f), decodeDigit(8)); }
test "decoder returns nine mask" { try std.testing.expectEqual(@as(?u7, 0x6f), decodeDigit(9)); }
test "decoder rejects values outside decimal digits" { try std.testing.expectEqual(@as(?u7, null), decodeDigit(10)); }
test "clamped decoder saturates invalid values to nine" { try std.testing.expectEqual(@as(u7, 0x6f), decodeDigitClamped(255)); }

test "initial blank matrix sends no pulses" {
    var display = CopperBulbDisplay{};
    const report = display.setMask(0);
    try std.testing.expectEqual(@as(u8, 0), report.pulses);
    try std.testing.expectEqual(@as(u7, 0), report.changed_segments);
}
test "minimal toggle uses desired xor current mask" {
    var display = CopperBulbDisplay{};
    _ = display.setMask(segment_a | segment_b);
    const report = display.setMask(segment_a | segment_c);
    try std.testing.expectEqual(segment_b | segment_c, report.changed_segments);
    try std.testing.expectEqual(@as(u8, 2), report.pulses);
}
test "repeating the same mask sends no pulses" {
    var display = CopperBulbDisplay{};
    _ = display.setMask(digit_masks[8]);
    const report = display.setMask(digit_masks[8]);
    try std.testing.expectEqual(@as(u8, 0), report.pulses);
    try std.testing.expectEqual(@as(u7, 0), report.changed_segments);
}
test "all seven bits can be activated" {
    var display = CopperBulbDisplay{};
    _ = display.setMask(ALL_SEGMENTS);
    try std.testing.expectEqual(ALL_SEGMENTS, display.current_mask);
}
test "oxidation state is preserved when its bulb toggles" {
    var display = CopperBulbDisplay{};
    display.bulbs[0].oxidation_stage = .weathered;
    _ = display.setMask(segment_a);
    try std.testing.expectEqual(latch.OxidationStage.weathered, display.bulbs[0].oxidation_stage);
    _ = display.setMask(0);
    try std.testing.expectEqual(latch.OxidationStage.weathered, display.bulbs[0].oxidation_stage);
}
test "lit bulb light level follows oxidation tier" {
    const stages = [_]latch.OxidationStage{ .unoxidized, .exposed, .weathered, .oxidized };
    const levels = [_]u8{ 15, 12, 8, 4 };
    for (stages, levels) |stage, level| {
        var display = CopperBulbDisplay{};
        display.bulbs[0].oxidation_stage = stage;
        _ = display.setMask(segment_a);
        try std.testing.expectEqual(level, display.getLightLevel(bulbCoord(0)).?);
    }
}
test "unlit bulb contributes zero emission" {
    try std.testing.expectEqual(@as(u8, 0), (CopperBulbDisplay{}).getLightLevel(bulbCoord(0)).?);
}
test "unknown coordinate has no bulb light level" {
    try std.testing.expectEqual(@as(?u8, null), (CopperBulbDisplay{}).getLightLevel(.{ .x = 3, .y = 0 }));
}
test "aggregate light emission sums individually oxidized bulbs" {
    var display = CopperBulbDisplay{};
    display.bulbs[3].oxidation_stage = .oxidized;
    display.bulbs[4].oxidation_stage = .weathered;
    _ = display.setMask(segment_b | segment_c);
    try std.testing.expectEqual(@as(u16, 12), display.totalLightEmission());
}
test "invalid digit blanks active display" {
    var display = CopperBulbDisplay{};
    _ = display.setDigit(8);
    const update = display.setDigit(42);
    try std.testing.expect(!update.valid);
    try std.testing.expectEqual(@as(u7, 0), display.current_mask);
}
test "invalid digit on blank display does not pulse" {
    var display = CopperBulbDisplay{};
    const update = display.setDigit(10);
    try std.testing.expect(!update.valid);
    try std.testing.expectEqual(@as(u8, 0), update.refresh.pulses);
}
test "cascade renders every number from zero through ninety nine" {
    var cascade = Cascade{};
    for (0..100) |value| {
        try std.testing.expect(cascade.showNumber(@intCast(value)));
        try std.testing.expectEqual(digit_masks[value / 10], cascade.tens.current_mask);
        try std.testing.expectEqual(digit_masks[value % 10], cascade.ones.current_mask);
    }
}
test "cascade renders leading zero for single digit values" {
    var cascade = Cascade{};
    try std.testing.expect(cascade.showNumber(7));
    try std.testing.expectEqual(digit_masks[0], cascade.tens.current_mask);
    try std.testing.expectEqual(digit_masks[7], cascade.ones.current_mask);
}
test "cascade rejects and blanks values above ninety nine" {
    var cascade = Cascade{};
    _ = cascade.showNumber(42);
    try std.testing.expect(!cascade.showNumber(100));
    try std.testing.expectEqual(@as(u7, 0), cascade.tens.current_mask);
    try std.testing.expectEqual(@as(u7, 0), cascade.ones.current_mask);
}
