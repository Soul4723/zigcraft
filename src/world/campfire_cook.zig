const std = @import("std");

pub const max_campfire_racks: usize = 32;
pub const campfire_cook_time: f32 = 15.0;

pub const RawPorkTag: u16 = 18;
pub const RawMuttonTag: u16 = 19;
pub const CookedPorkTag: u16 = 20;
pub const CookedMuttonTag: u16 = 21;
pub const RawCodTag: u16 = 184;
pub const CookedCodTag: u16 = 185;
pub const KelpTag: u16 = 187;
pub const DriedKelpTag: u16 = 188;
pub const RawSalmonTag: u16 = 191;
pub const CookedSalmonTag: u16 = 192;

pub const NoneTag: u16 = 0;

pub const CampfireRack = struct {
    x: i32,
    y: i32,
    z: i32,
    input_tag: u16 = NoneTag,
    timer: f32 = 0.0,
    signal_fire: bool = false,
};

pub fn isCampfireCookable(tag: u16) bool {
    return switch (tag) {
        RawPorkTag, RawMuttonTag, RawCodTag, RawSalmonTag, KelpTag => true,
        else => false,
    };
}

pub fn cookedOutput(tag: u16) u16 {
    return switch (tag) {
        RawPorkTag => CookedPorkTag,
        RawMuttonTag => CookedMuttonTag,
        RawCodTag => CookedCodTag,
        RawSalmonTag => CookedSalmonTag,
        KelpTag => DriedKelpTag,
        else => NoneTag,
    };
}

pub fn mountItem(rack: *CampfireRack, tag: u16) bool {
    if (rack.input_tag != NoneTag or !isCampfireCookable(tag)) return false;
    rack.input_tag = tag;
    rack.timer = 0.0;
    return true;
}

pub fn tickRack(rack: *CampfireRack, dt: f32) ?u16 {
    if (rack.input_tag == NoneTag) return null;
    rack.timer += dt;
    if (rack.timer >= campfire_cook_time) {
        const out = cookedOutput(rack.input_tag);
        rack.input_tag = NoneTag;
        rack.timer = 0.0;
        return if (out != NoneTag) out else null;
    }
    return null;
}

pub fn findRack(racks: []const CampfireRack, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, racks.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const r = racks[i];
        if (r.x == x and r.y == y and r.z == z) return i;
    }
    return null;
}

pub fn smokePlumeCount(signal_fire: bool) usize {
    return if (signal_fire) 10 else 4;
}

test "campfire constants" {
    try std.testing.expectEqual(@as(usize, 32), max_campfire_racks);
    try std.testing.expectEqual(@as(f32, 15.0), campfire_cook_time);
    try std.testing.expectEqual(@as(u16, 18), RawPorkTag);
    try std.testing.expectEqual(@as(u16, 19), RawMuttonTag);
    try std.testing.expectEqual(@as(u16, 20), CookedPorkTag);
    try std.testing.expectEqual(@as(u16, 21), CookedMuttonTag);
    try std.testing.expectEqual(@as(u16, 184), RawCodTag);
    try std.testing.expectEqual(@as(u16, 185), CookedCodTag);
    try std.testing.expectEqual(@as(u16, 187), KelpTag);
    try std.testing.expectEqual(@as(u16, 188), DriedKelpTag);
    try std.testing.expectEqual(@as(u16, 191), RawSalmonTag);
    try std.testing.expectEqual(@as(u16, 192), CookedSalmonTag);
    try std.testing.expectEqual(@as(u16, 0), NoneTag);
}

test "isCampfireCookable" {
    try std.testing.expect(isCampfireCookable(RawPorkTag));
    try std.testing.expect(isCampfireCookable(RawMuttonTag));
    try std.testing.expect(isCampfireCookable(RawCodTag));
    try std.testing.expect(isCampfireCookable(RawSalmonTag));
    try std.testing.expect(isCampfireCookable(KelpTag));
    try std.testing.expect(!isCampfireCookable(NoneTag));
    try std.testing.expect(!isCampfireCookable(CookedPorkTag));
    try std.testing.expect(!isCampfireCookable(99));
}

test "cookedOutput" {
    try std.testing.expectEqual(CookedPorkTag, cookedOutput(RawPorkTag));
    try std.testing.expectEqual(CookedMuttonTag, cookedOutput(RawMuttonTag));
    try std.testing.expectEqual(CookedCodTag, cookedOutput(RawCodTag));
    try std.testing.expectEqual(CookedSalmonTag, cookedOutput(RawSalmonTag));
    try std.testing.expectEqual(DriedKelpTag, cookedOutput(KelpTag));
    try std.testing.expectEqual(NoneTag, cookedOutput(NoneTag));
    try std.testing.expectEqual(NoneTag, cookedOutput(99));
    try std.testing.expectEqual(NoneTag, cookedOutput(CookedPorkTag));
}

test "mountItem" {
    var rack = CampfireRack{ .x = 1, .y = 2, .z = 3 };
    try std.testing.expect(mountItem(&rack, RawPorkTag));
    try std.testing.expectEqual(RawPorkTag, rack.input_tag);
    try std.testing.expectEqual(@as(f32, 0.0), rack.timer);

    // Already occupied
    try std.testing.expect(!mountItem(&rack, RawCodTag));
    try std.testing.expectEqual(RawPorkTag, rack.input_tag);

    // Not cookable
    var empty = CampfireRack{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!mountItem(&empty, CookedPorkTag));
    try std.testing.expectEqual(NoneTag, empty.input_tag);

    // None not cookable
    try std.testing.expect(!mountItem(&empty, NoneTag));
}

test "tickRack empty" {
    var rack = CampfireRack{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expectEqual(@as(?u16, null), tickRack(&rack, 5.0));
    try std.testing.expectEqual(@as(f32, 0.0), rack.timer);
}

test "tickRack progress and completion" {
    var rack = CampfireRack{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(mountItem(&rack, RawSalmonTag));

    // Partial cook
    try std.testing.expectEqual(@as(?u16, null), tickRack(&rack, 10.0));
    try std.testing.expectEqual(@as(f32, 10.0), rack.timer);
    try std.testing.expectEqual(RawSalmonTag, rack.input_tag);

    // Complete at threshold
    try std.testing.expectEqual(@as(?u16, CookedSalmonTag), tickRack(&rack, 5.0));
    try std.testing.expectEqual(NoneTag, rack.input_tag);
    try std.testing.expectEqual(@as(f32, 0.0), rack.timer);

    // Empty rack after completion
    try std.testing.expectEqual(@as(?u16, null), tickRack(&rack, 15.0));
}

test "tickRack kelp yields dried kelp" {
    var rack = CampfireRack{ .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(mountItem(&rack, KelpTag));
    try std.testing.expectEqual(@as(?u16, DriedKelpTag), tickRack(&rack, 15.0));
}

test "findRack" {
    var racks = [_]CampfireRack{
        .{ .x = 0, .y = 0, .z = 0 },
        .{ .x = 5, .y = 6, .z = 7 },
        .{ .x = -1, .y = 2, .z = -3 },
    };
    try std.testing.expectEqual(@as(?usize, 1), findRack(&racks, racks.len, 5, 6, 7));
    try std.testing.expectEqual(@as(?usize, 2), findRack(&racks, racks.len, -1, 2, -3));
    try std.testing.expectEqual(@as(?usize, 0), findRack(&racks, racks.len, 0, 0, 0));
    try std.testing.expectEqual(@as(?usize, null), findRack(&racks, racks.len, 9, 9, 9));

    // count limits the search window
    try std.testing.expectEqual(@as(?usize, null), findRack(&racks, 1, 5, 6, 7));
    // count larger than slice is clamped
    try std.testing.expectEqual(@as(?usize, 1), findRack(&racks, 999, 5, 6, 7));
    // empty slice
    const empty = [_]CampfireRack{};
    try std.testing.expectEqual(@as(?usize, null), findRack(&empty, 0, 0, 0, 0));
}

test "smokePlumeCount" {
    try std.testing.expectEqual(@as(usize, 10), smokePlumeCount(true));
    try std.testing.expectEqual(@as(usize, 4), smokePlumeCount(false));
}
