const std = @import("std");
const smelt_mod = @import("smelting.zig");
const sapling_mod = @import("sapling.zig");
const persistence_mod = @import("persistence.zig");
const Dimension = persistence_mod.Dimension;

pub const BLOCK_JOBS_MAGIC = [4]u8{ 'Z', 'J', 'O', 'B' };
pub const BLOCK_JOBS_VERSION: u32 = 1;
pub const HEADER_SIZE: usize = 20;
pub const FURNACE_RECORD_SIZE: usize = 20;
pub const SPROUT_RECORD_SIZE: usize = 16;
pub const MAX_SAVE_SIZE: usize = HEADER_SIZE +
    (smelt_mod.furnace_cap * 3 * FURNACE_RECORD_SIZE) +
    (sapling_mod.sprout_cap * SPROUT_RECORD_SIZE);

pub const BlockJobsData = struct {
    furnaces: [smelt_mod.furnace_cap]smelt_mod.FurnaceJob = [_]smelt_mod.FurnaceJob{.{ .x = 0, .y = 0, .z = 0, .t = 0, .fuel = 0, .input = 0 }} ** smelt_mod.furnace_cap,
    furnace_count: usize = 0,
    smokers: [smelt_mod.furnace_cap]smelt_mod.FurnaceJob = [_]smelt_mod.FurnaceJob{.{ .x = 0, .y = 0, .z = 0, .t = 0, .fuel = 0, .input = 0 }} ** smelt_mod.furnace_cap,
    smoker_count: usize = 0,
    blast_furnaces: [smelt_mod.furnace_cap]smelt_mod.FurnaceJob = [_]smelt_mod.FurnaceJob{.{ .x = 0, .y = 0, .z = 0, .t = 0, .fuel = 0, .input = 0 }} ** smelt_mod.furnace_cap,
    blast_furnace_count: usize = 0,
    sprouts: [sapling_mod.sprout_cap]sapling_mod.Sprout = [_]sapling_mod.Sprout{.{ .x = 0, .y = 0, .z = 0, .t = 0 }} ** sapling_mod.sprout_cap,
    sprout_count: usize = 0,
};

pub const LoadJobsResult = enum {
    ok,
    absent,
    corrupt,
};

/// Capture live job slices into a bounded BlockJobsData structure.
pub fn captureBlockJobs(
    furnaces: []const smelt_mod.FurnaceJob,
    furnace_count: usize,
    smokers: []const smelt_mod.FurnaceJob,
    smoker_count: usize,
    blast_furnaces: []const smelt_mod.FurnaceJob,
    blast_furnace_count: usize,
    sprouts: []const sapling_mod.Sprout,
    sprout_count: usize,
) BlockJobsData {
    var data = BlockJobsData{
        .furnace_count = @min(furnace_count, smelt_mod.furnace_cap),
        .smoker_count = @min(smoker_count, smelt_mod.furnace_cap),
        .blast_furnace_count = @min(blast_furnace_count, smelt_mod.furnace_cap),
        .sprout_count = @min(sprout_count, sapling_mod.sprout_cap),
    };
    for (0..data.furnace_count) |i| data.furnaces[i] = furnaces[i];
    for (0..data.smoker_count) |i| data.smokers[i] = smokers[i];
    for (0..data.blast_furnace_count) |i| data.blast_furnaces[i] = blast_furnaces[i];
    for (0..data.sprout_count) |i| data.sprouts[i] = sprouts[i];
    return data;
}

/// Apply loaded BlockJobsData back into live job arrays.
pub fn applyBlockJobs(
    data: *const BlockJobsData,
    furnaces: []smelt_mod.FurnaceJob,
    furnace_count: *usize,
    smokers: []smelt_mod.FurnaceJob,
    smoker_count: *usize,
    blast_furnaces: []smelt_mod.FurnaceJob,
    blast_furnace_count: *usize,
    sprouts: []sapling_mod.Sprout,
    sprout_count: *usize,
) void {
    const fc = @min(data.furnace_count, @min(furnaces.len, smelt_mod.furnace_cap));
    for (0..fc) |i| furnaces[i] = data.furnaces[i];
    furnace_count.* = fc;

    const sc = @min(data.smoker_count, @min(smokers.len, smelt_mod.furnace_cap));
    for (0..sc) |i| smokers[i] = data.smokers[i];
    smoker_count.* = sc;

    const bfc = @min(data.blast_furnace_count, @min(blast_furnaces.len, smelt_mod.furnace_cap));
    for (0..bfc) |i| blast_furnaces[i] = data.blast_furnaces[i];
    blast_furnace_count.* = bfc;

    const spc = @min(data.sprout_count, @min(sprouts.len, sapling_mod.sprout_cap));
    for (0..spc) |i| sprouts[i] = data.sprouts[i];
    sprout_count.* = spc;
}

/// Validate that a furnace job has safe vertical coordinates (0..15), non-negative finite timer, and supported smeltable input tag.
pub fn isValidFurnaceJob(job: *const smelt_mod.FurnaceJob) bool {
    if (job.y < 0 or job.y >= 16) return false;
    if (!std.math.isFinite(job.t) or job.t < 0.0 or job.t > 3600.0) return false;
    if (job.input != smelt_mod.None and !smelt_mod.isSmeltable(job.input)) return false;
    return true;
}

/// Validate that a smoker job has safe vertical coordinates (0..15), non-negative finite timer, and supported food input tag.
pub fn isValidSmokerJob(job: *const smelt_mod.FurnaceJob) bool {
    if (job.y < 0 or job.y >= 16) return false;
    if (!std.math.isFinite(job.t) or job.t < 0.0 or job.t > 3600.0) return false;
    if (job.input != smelt_mod.None and (!smelt_mod.isSmeltable(job.input) or !smelt_mod.isFoodItem(job.input))) return false;
    return true;
}

/// Validate that a blast furnace job has safe vertical coordinates (0..15), non-negative finite timer, and supported ore input tag.
pub fn isValidBlastFurnaceJob(job: *const smelt_mod.FurnaceJob) bool {
    if (job.y < 0 or job.y >= 16) return false;
    if (!std.math.isFinite(job.t) or job.t < 0.0 or job.t > 3600.0) return false;
    if (job.input != smelt_mod.None and (!smelt_mod.isSmeltable(job.input) or !smelt_mod.isOreItem(job.input))) return false;
    return true;
}

/// Validate that a sprout has safe coordinates within world bounds (y in 0..13) and non-negative finite timer without arithmetic overflow.
pub fn isValidSprout(sprout: *const sapling_mod.Sprout) bool {
    if (sprout.y < 0 or sprout.y > 13) return false;
    if (!std.math.isFinite(sprout.t) or sprout.t < 0.0 or sprout.t > 3600.0) return false;
    return true;
}

/// Returns true if all blocks in the sapling tree canopy footprint are within loaded chunks.
pub fn isCanopyLoaded(world: anytype, sx: i32, sy: i32, sz: i32) bool {
    if (sy < 0 or sy > 13) return false;
    if (sx <= std.math.minInt(i32) + 1 or sx >= std.math.maxInt(i32) - 1) return false;
    if (sz <= std.math.minInt(i32) + 1 or sz >= std.math.maxInt(i32) - 1) return false;
    for (sapling_mod.tree_structure) |tb| {
        const by = sy + tb.dy;
        // Offsets beyond vertical bounds clip per established world height semantics
        if (by < 0 or by >= 16) continue;
        if (!world.isBlockLoaded(sx + tb.dx, by, sz + tb.dz)) return false;
    }
    return true;
}

/// Encode BlockJobsData into little-endian binary bytes.
pub fn encodeBlockJobs(data: *const BlockJobsData, dim: Dimension, out: []u8) !usize {
    const fc = @min(data.furnace_count, smelt_mod.furnace_cap);
    const sc = @min(data.smoker_count, smelt_mod.furnace_cap);
    const bfc = @min(data.blast_furnace_count, smelt_mod.furnace_cap);
    const spc = @min(data.sprout_count, sapling_mod.sprout_cap);

    const expected_len = HEADER_SIZE +
        fc * FURNACE_RECORD_SIZE +
        sc * FURNACE_RECORD_SIZE +
        bfc * FURNACE_RECORD_SIZE +
        spc * SPROUT_RECORD_SIZE;

    if (out.len < expected_len) return error.BufferTooSmall;

    var i: usize = 0;
    inline for (BLOCK_JOBS_MAGIC) |b| {
        out[i] = b;
        i += 1;
    }
    putInt(out, &i, BLOCK_JOBS_VERSION);
    out[i] = @intFromEnum(dim);
    i += 1;
    putInt(out, &i, @as(u16, @intCast(fc)));
    putInt(out, &i, @as(u16, @intCast(sc)));
    putInt(out, &i, @as(u16, @intCast(bfc)));
    putInt(out, &i, @as(u16, @intCast(spc)));
    out[i] = 0;
    out[i + 1] = 0;
    out[i + 2] = 0;
    i += 3;
    std.debug.assert(i == HEADER_SIZE);

    for (data.furnaces[0..fc]) |j| {
        putInt(out, &i, j.x);
        putInt(out, &i, j.y);
        putInt(out, &i, j.z);
        putFloat(out, &i, j.t);
        out[i] = j.fuel;
        out[i + 1] = 0;
        i += 2;
        putInt(out, &i, j.input);
    }

    for (data.smokers[0..sc]) |j| {
        putInt(out, &i, j.x);
        putInt(out, &i, j.y);
        putInt(out, &i, j.z);
        putFloat(out, &i, j.t);
        out[i] = j.fuel;
        out[i + 1] = 0;
        i += 2;
        putInt(out, &i, j.input);
    }

    for (data.blast_furnaces[0..bfc]) |j| {
        putInt(out, &i, j.x);
        putInt(out, &i, j.y);
        putInt(out, &i, j.z);
        putFloat(out, &i, j.t);
        out[i] = j.fuel;
        out[i + 1] = 0;
        i += 2;
        putInt(out, &i, j.input);
    }

    for (data.sprouts[0..spc]) |s| {
        putInt(out, &i, s.x);
        putInt(out, &i, s.y);
        putInt(out, &i, s.z);
        putFloat(out, &i, s.t);
    }

    std.debug.assert(i == expected_len);
    return i;
}

/// Decode binary bytes into BlockJobsData. Returns false without mutating out on any error.
pub fn decodeBlockJobs(bytes: []const u8, expected_dim: Dimension, out: *BlockJobsData) bool {
    if (bytes.len < HEADER_SIZE) return false;
    if (!std.mem.eql(u8, bytes[0..4], &BLOCK_JOBS_MAGIC)) return false;

    var i: usize = 4;
    const version = getInt(u32, bytes, &i);
    if (version != BLOCK_JOBS_VERSION) return false;

    const dim_raw = bytes[i];
    i += 1;
    const dim = std.enums.fromInt(Dimension, dim_raw) orelse return false;
    if (dim != expected_dim) return false;

    const fc = getInt(u16, bytes, &i);
    const sc = getInt(u16, bytes, &i);
    const bfc = getInt(u16, bytes, &i);
    const spc = getInt(u16, bytes, &i);
    i += 3; // skip reserved 3 bytes
    std.debug.assert(i == HEADER_SIZE);

    if (fc > smelt_mod.furnace_cap) return false;
    if (sc > smelt_mod.furnace_cap) return false;
    if (bfc > smelt_mod.furnace_cap) return false;
    if (spc > sapling_mod.sprout_cap) return false;

    const expected_len = HEADER_SIZE +
        @as(usize, fc) * FURNACE_RECORD_SIZE +
        @as(usize, sc) * FURNACE_RECORD_SIZE +
        @as(usize, bfc) * FURNACE_RECORD_SIZE +
        @as(usize, spc) * SPROUT_RECORD_SIZE;

    // Full file length validation: exact match rejects truncated and oversized records
    if (bytes.len != expected_len) return false;

    var temp = BlockJobsData{
        .furnace_count = fc,
        .smoker_count = sc,
        .blast_furnace_count = bfc,
        .sprout_count = spc,
    };

    for (0..fc) |idx| {
        const x = getInt(i32, bytes, &i);
        const y = getInt(i32, bytes, &i);
        const z = getInt(i32, bytes, &i);
        const t = getFloat(bytes, &i);
        const fuel = bytes[i];
        i += 2; // fuel + reserved byte
        const input = getInt(u16, bytes, &i);
        const job = smelt_mod.FurnaceJob{ .x = x, .y = y, .z = z, .t = t, .fuel = fuel, .input = input };
        if (!isValidFurnaceJob(&job)) return false;
        temp.furnaces[idx] = job;
    }

    for (0..sc) |idx| {
        const x = getInt(i32, bytes, &i);
        const y = getInt(i32, bytes, &i);
        const z = getInt(i32, bytes, &i);
        const t = getFloat(bytes, &i);
        const fuel = bytes[i];
        i += 2;
        const input = getInt(u16, bytes, &i);
        const job = smelt_mod.FurnaceJob{ .x = x, .y = y, .z = z, .t = t, .fuel = fuel, .input = input };
        if (!isValidSmokerJob(&job)) return false;
        temp.smokers[idx] = job;
    }

    for (0..bfc) |idx| {
        const x = getInt(i32, bytes, &i);
        const y = getInt(i32, bytes, &i);
        const z = getInt(i32, bytes, &i);
        const t = getFloat(bytes, &i);
        const fuel = bytes[i];
        i += 2;
        const input = getInt(u16, bytes, &i);
        const job = smelt_mod.FurnaceJob{ .x = x, .y = y, .z = z, .t = t, .fuel = fuel, .input = input };
        if (!isValidBlastFurnaceJob(&job)) return false;
        temp.blast_furnaces[idx] = job;
    }

    for (0..spc) |idx| {
        const x = getInt(i32, bytes, &i);
        const y = getInt(i32, bytes, &i);
        const z = getInt(i32, bytes, &i);
        const t = getFloat(bytes, &i);
        const sprout = sapling_mod.Sprout{ .x = x, .y = y, .z = z, .t = t };
        if (!isValidSprout(&sprout)) return false;
        temp.sprouts[idx] = sprout;
    }

    std.debug.assert(i == expected_len);
    out.* = temp;
    return true;
}

fn putInt(bytes: []u8, index: *usize, value: anytype) void {
    const T = @TypeOf(value);
    std.mem.writeInt(T, bytes[index.*..][0..@sizeOf(T)], value, .little);
    index.* += @sizeOf(T);
}

fn putFloat(bytes: []u8, index: *usize, value: f32) void {
    std.mem.writeInt(u32, bytes[index.*..][0..4], @as(u32, @bitCast(value)), .little);
    index.* += 4;
}

fn getInt(comptime T: type, bytes: []const u8, index: *usize) T {
    const val = std.mem.readInt(T, bytes[index.*..][0..@sizeOf(T)], .little);
    index.* += @sizeOf(T);
    return val;
}

fn getFloat(bytes: []const u8, index: *usize) f32 {
    const bits = std.mem.readInt(u32, bytes[index.*..][0..4], .little);
    index.* += 4;
    return @bitCast(bits);
}

test "BlockJobsData capture and apply roundtrip" {
    var src_furnaces = [_]smelt_mod.FurnaceJob{.{ .x = 1, .y = 2, .z = 3, .t = 4.5, .fuel = 2, .input = smelt_mod.RawPork }} ** smelt_mod.furnace_cap;
    var src_smokers = [_]smelt_mod.FurnaceJob{.{ .x = 4, .y = 5, .z = 6, .t = 1.5, .fuel = 1, .input = smelt_mod.RawCod }} ** smelt_mod.furnace_cap;
    var src_blast = [_]smelt_mod.FurnaceJob{.{ .x = 7, .y = 8, .z = 9, .t = 3.0, .fuel = 4, .input = smelt_mod.IronOre }} ** smelt_mod.furnace_cap;
    var src_sprouts = [_]sapling_mod.Sprout{.{ .x = 10, .y = 4, .z = 12, .t = 15.0 }} ** sapling_mod.sprout_cap;

    const data = captureBlockJobs(&src_furnaces, 2, &src_smokers, 1, &src_blast, 1, &src_sprouts, 3);
    try std.testing.expectEqual(@as(usize, 2), data.furnace_count);
    try std.testing.expectEqual(@as(usize, 1), data.smoker_count);
    try std.testing.expectEqual(@as(usize, 1), data.blast_furnace_count);
    try std.testing.expectEqual(@as(usize, 3), data.sprout_count);

    var dst_furnaces: [smelt_mod.furnace_cap]smelt_mod.FurnaceJob = undefined;
    var dst_fc: usize = 0;
    var dst_smokers: [smelt_mod.furnace_cap]smelt_mod.FurnaceJob = undefined;
    var dst_sc: usize = 0;
    var dst_blast: [smelt_mod.furnace_cap]smelt_mod.FurnaceJob = undefined;
    var dst_bfc: usize = 0;
    var dst_sprouts: [sapling_mod.sprout_cap]sapling_mod.Sprout = undefined;
    var dst_spc: usize = 0;

    applyBlockJobs(&data, &dst_furnaces, &dst_fc, &dst_smokers, &dst_sc, &dst_blast, &dst_bfc, &dst_sprouts, &dst_spc);
    try std.testing.expectEqual(@as(usize, 2), dst_fc);
    try std.testing.expectEqual(@as(usize, 1), dst_sc);
    try std.testing.expectEqual(@as(usize, 1), dst_bfc);
    try std.testing.expectEqual(@as(usize, 3), dst_spc);
    try std.testing.expectEqual(src_furnaces[0], dst_furnaces[0]);
    try std.testing.expectEqual(src_smokers[0], dst_smokers[0]);
    try std.testing.expectEqual(src_blast[0], dst_blast[0]);
    try std.testing.expectEqual(src_sprouts[0], dst_sprouts[0]);
}

test "encode and decode block jobs valid binary format" {
    var data = BlockJobsData{};
    data.furnace_count = 1;
    data.furnaces[0] = .{ .x = 10, .y = 5, .z = -20, .t = 4.25, .fuel = 2, .input = smelt_mod.RawPork };
    data.smoker_count = 1;
    data.smokers[0] = .{ .x = 15, .y = 6, .z = -25, .t = 2.0, .fuel = 1, .input = smelt_mod.RawCod };
    data.blast_furnace_count = 1;
    data.blast_furnaces[0] = .{ .x = 20, .y = 7, .z = -30, .t = 3.5, .fuel = 5, .input = smelt_mod.IronOre };
    data.sprout_count = 1;
    data.sprouts[0] = .{ .x = -5, .y = 4, .z = 8, .t = 12.5 };

    var buf: [MAX_SAVE_SIZE]u8 = undefined;
    const len = try encodeBlockJobs(&data, .overworld, &buf);
    try std.testing.expectEqual(HEADER_SIZE + 3 * FURNACE_RECORD_SIZE + SPROUT_RECORD_SIZE, len);

    var decoded = BlockJobsData{};
    try std.testing.expect(decodeBlockJobs(buf[0..len], .overworld, &decoded));

    try std.testing.expectEqual(@as(usize, 1), decoded.furnace_count);
    try std.testing.expectEqual(data.furnaces[0], decoded.furnaces[0]);
    try std.testing.expectEqual(@as(usize, 1), decoded.smoker_count);
    try std.testing.expectEqual(data.smokers[0], decoded.smokers[0]);
    try std.testing.expectEqual(@as(usize, 1), decoded.blast_furnace_count);
    try std.testing.expectEqual(data.blast_furnaces[0], decoded.blast_furnaces[0]);
    try std.testing.expectEqual(@as(usize, 1), decoded.sprout_count);
    try std.testing.expectEqual(data.sprouts[0], decoded.sprouts[0]);
}

test "decode rejects invalid magic, version, dimension mismatch" {
    var data = BlockJobsData{};
    var buf: [MAX_SAVE_SIZE]u8 = undefined;
    const len = try encodeBlockJobs(&data, .nether, &buf);

    var out = BlockJobsData{ .furnace_count = 99 };

    // Bad magic
    var bad_magic = buf;
    bad_magic[0] = 'X';
    try std.testing.expect(!decodeBlockJobs(bad_magic[0..len], .nether, &out));
    try std.testing.expectEqual(@as(usize, 99), out.furnace_count);

    // Bad version
    var bad_ver = buf;
    bad_ver[4] = 2;
    try std.testing.expect(!decodeBlockJobs(bad_ver[0..len], .nether, &out));
    try std.testing.expectEqual(@as(usize, 99), out.furnace_count);

    // Dimension mismatch (saved in nether, loaded in overworld)
    try std.testing.expect(!decodeBlockJobs(buf[0..len], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 99), out.furnace_count);
}

test "decode rejects count exceeding capacity" {
    var data = BlockJobsData{};
    var buf: [MAX_SAVE_SIZE]u8 = undefined;
    const len = try encodeBlockJobs(&data, .the_end, &buf);

    var out = BlockJobsData{ .furnace_count = 77 };

    // Set furnace count to 17 (> 16 cap)
    var bad_count = buf;
    std.mem.writeInt(u16, bad_count[9..11], 17, .little);
    try std.testing.expect(!decodeBlockJobs(bad_count[0..len], .the_end, &out));
    try std.testing.expectEqual(@as(usize, 77), out.furnace_count);
}

test "decode rejects sprout with i32 max or min y without arithmetic overflow panic" {
    var data = BlockJobsData{};
    data.sprout_count = 1;
    data.sprouts[0] = .{ .x = 10, .y = 5, .z = 10, .t = 1.0 };
    var buf: [MAX_SAVE_SIZE]u8 = undefined;
    const len = try encodeBlockJobs(&data, .overworld, &buf);

    var out = BlockJobsData{ .sprout_count = 99 };

    // Mutate sprout y to std.math.maxInt(i32)
    var max_y_buf = buf;
    std.mem.writeInt(i32, max_y_buf[24..28], std.math.maxInt(i32), .little);
    try std.testing.expect(!decodeBlockJobs(max_y_buf[0..len], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 99), out.sprout_count);

    // Mutate sprout y to std.math.minInt(i32)
    var min_y_buf = buf;
    std.mem.writeInt(i32, min_y_buf[24..28], std.math.minInt(i32), .little);
    try std.testing.expect(!decodeBlockJobs(min_y_buf[0..len], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 99), out.sprout_count);
}

test "decode rejects out of bounds coordinates" {
    var data = BlockJobsData{};
    data.furnace_count = 1;
    data.furnaces[0] = .{ .x = 0, .y = 16, .z = 0, .t = 1.0, .fuel = 1, .input = smelt_mod.None };

    var buf: [MAX_SAVE_SIZE]u8 = undefined;
    const len = try encodeBlockJobs(&data, .overworld, &buf);

    var out = BlockJobsData{ .furnace_count = 88 };
    try std.testing.expect(!decodeBlockJobs(buf[0..len], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 88), out.furnace_count);
}

test "decode rejects negative or NaN timer" {
    var data = BlockJobsData{};
    data.furnace_count = 1;
    data.furnaces[0] = .{ .x = 0, .y = 5, .z = 0, .t = -0.5, .fuel = 1, .input = smelt_mod.None };

    var buf: [MAX_SAVE_SIZE]u8 = undefined;
    const len = try encodeBlockJobs(&data, .overworld, &buf);

    var out = BlockJobsData{ .furnace_count = 55 };
    try std.testing.expect(!decodeBlockJobs(buf[0..len], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 55), out.furnace_count);

    // Test NaN
    var nan_buf = buf;
    const nan_bits: u32 = 0x7FC00000;
    std.mem.writeInt(u32, nan_buf[32..36], nan_bits, .little);
    try std.testing.expect(!decodeBlockJobs(nan_buf[0..len], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 55), out.furnace_count);
}

test "decode rejects unsupported input items for furnace, smoker, blast furnace" {
    var out = BlockJobsData{ .furnace_count = 33 };

    // 1. Furnace with invalid item tag 9999
    var d1 = BlockJobsData{};
    d1.furnace_count = 1;
    d1.furnaces[0] = .{ .x = 0, .y = 5, .z = 0, .t = 1.0, .fuel = 1, .input = 9999 };
    var buf1: [MAX_SAVE_SIZE]u8 = undefined;
    const l1 = try encodeBlockJobs(&d1, .overworld, &buf1);
    try std.testing.expect(!decodeBlockJobs(buf1[0..l1], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 33), out.furnace_count);

    // 2. Smoker with ore input (IronOre is not food)
    var d2 = BlockJobsData{};
    d2.smoker_count = 1;
    d2.smokers[0] = .{ .x = 0, .y = 5, .z = 0, .t = 1.0, .fuel = 1, .input = smelt_mod.IronOre };
    var buf2: [MAX_SAVE_SIZE]u8 = undefined;
    const l2 = try encodeBlockJobs(&d2, .overworld, &buf2);
    try std.testing.expect(!decodeBlockJobs(buf2[0..l2], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 33), out.furnace_count);

    // 3. Blast furnace with food input (RawPork is not ore)
    var d3 = BlockJobsData{};
    d3.blast_furnace_count = 1;
    d3.blast_furnaces[0] = .{ .x = 0, .y = 5, .z = 0, .t = 1.0, .fuel = 1, .input = smelt_mod.RawPork };
    var buf3: [MAX_SAVE_SIZE]u8 = undefined;
    const l3 = try encodeBlockJobs(&d3, .overworld, &buf3);
    try std.testing.expect(!decodeBlockJobs(buf3[0..l3], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 33), out.furnace_count);
}

test "decode rejects truncated and oversized payloads without mutating out" {
    var data = BlockJobsData{};
    data.furnace_count = 1;
    data.furnaces[0] = .{ .x = 1, .y = 2, .z = 3, .t = 1.0, .fuel = 1, .input = smelt_mod.Sand };

    var buf: [MAX_SAVE_SIZE]u8 = undefined;
    const len = try encodeBlockJobs(&data, .overworld, &buf);

    var out = BlockJobsData{ .furnace_count = 12 };

    // Truncated (len - 1)
    try std.testing.expect(!decodeBlockJobs(buf[0 .. len - 1], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 12), out.furnace_count);

    // Truncated header (< 20)
    try std.testing.expect(!decodeBlockJobs(buf[0..10], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 12), out.furnace_count);

    // Oversized (extra byte appended)
    var over_buf: [MAX_SAVE_SIZE + 1]u8 = undefined;
    @memcpy(over_buf[0..len], buf[0..len]);
    over_buf[len] = 0xAA;
    try std.testing.expect(!decodeBlockJobs(over_buf[0 .. len + 1], .overworld, &out));
    try std.testing.expectEqual(@as(usize, 12), out.furnace_count);
}

test "isCanopyLoaded allows upper-Y sprout growth with vertical clipping" {
    const MockWorld = struct {
        pub fn isBlockLoaded(_: @This(), _: i32, y: i32, _: i32) bool {
            return y >= 0 and y < 16;
        }
    };
    const w = MockWorld{};
    // Sapling planted at y=13: dy=1 and dy=2 are in range 0..15; dy=3 and dy=4 clip at y=16 and y=17
    // Must return true rather than permanently pausing the sprout!
    try std.testing.expect(isCanopyLoaded(w, 8, 13, 8));
}

test "canopyChunksLoaded detects unloaded boundary chunks" {
    const MockWorld = struct {
        loaded_cx: i32,
        loaded_cz: i32,
        pub fn isBlockLoaded(self: @This(), x: i32, y: i32, z: i32) bool {
            if (y < 0 or y >= 16) return false;
            return @divFloor(x, 16) == self.loaded_cx and @divFloor(z, 16) == self.loaded_cz;
        }
    };

    // Tree at center of chunk (cx=0, cz=0) at (8, 4, 8) -> canopy dx: -1..1, dz: -1..1 stays within chunk 0, 0
    const w1 = MockWorld{ .loaded_cx = 0, .loaded_cz = 0 };
    try std.testing.expect(isCanopyLoaded(w1, 8, 4, 8));

    // Tree at edge of chunk (cx=0, cz=0) at (0, 4, 8) -> canopy dx=-1 crosses into chunk cx=-1, which is unloaded!
    try std.testing.expect(!isCanopyLoaded(w1, 0, 4, 8));
}
