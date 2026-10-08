const std = @import("std");
const persistence_mod = @import("persistence.zig");
const Persistence = persistence_mod.Persistence;
const Chunk = @import("chunk.zig").Chunk;
const BlockId = @import("block.zig").BlockId;

test "save and load roundtrip" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});

    const p = Persistence.init(test_dir);

    var src = Chunk.init();
    src.setBlock(2, 3, 4, .stone);
    src.setBlock(15, 10, 0, .grass);

    try std.testing.expect(p.saveChunk(-5, 12, &src));

    var dst = Chunk.init();
    const loaded = p.loadChunk(-5, 12, &dst);
    try std.testing.expect(loaded);

    try std.testing.expectEqual(dst.getBlock(2, 3, 4), .stone);
    try std.testing.expectEqual(dst.getBlock(15, 10, 0), .grass);
    try std.testing.expectEqual(dst.getBlock(0, 0, 0), .air);

    // Non-existent chunk returns false
    var missing = Chunk.init();
    const found = p.loadChunk(99, 99, &missing);
    try std.testing.expect(!found);
}

test "water levels persist roundtrip" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const pp = Persistence.init(test_dir);
    var src = Chunk.init();
    src.setBlock(1, 1, 1, .water);
    src.setLevel(1, 1, 1, 7);
    src.setBlock(2, 2, 2, .water);
    src.setLevel(2, 2, 2, 3);
    try std.testing.expect(pp.saveChunk(4, 5, &src));
    var dst = Chunk.init();
    try std.testing.expect(pp.loadChunk(4, 5, &dst));
    try std.testing.expectEqual(@as(u4, 7), dst.getLevel(1, 1, 1));
    try std.testing.expectEqual(@as(u4, 3), dst.getLevel(2, 2, 2));
    try std.testing.expectEqual(@as(u4, 0), dst.getLevel(0, 0, 0));
}

test "repeater stages sidecar roundtrip" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const pp = Persistence.init(test_dir);
    const stages = [_][4]u8{ .{ 1, 5, 2, 3 }, .{ 15, 0, 0, 1 } };
    try std.testing.expect(pp.saveRepeaterStages(3, 7, &stages));
    var out = [_][4]u8{.{ 0, 0, 0, 0 }} ** 32;
    var slice: [][4]u8 = &out;
    const n = pp.loadRepeaterStages(3, 7, &slice);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(stages[0], out[0]);
    try std.testing.expectEqual(stages[1], out[1]);
    // missing sidecar -> 0
    var out2 = [_][4]u8{.{ 0, 0, 0, 0 }} ** 32;
    var slice2: [][4]u8 = &out2;
    try std.testing.expectEqual(@as(usize, 0), pp.loadRepeaterStages(77, 78, &slice2));
}

test "redstone block states persist roundtrip" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const pp = Persistence.init(test_dir);
    var src = Chunk.init();
    src.setBlock(1, 2, 3, .redstone_wire_on);
    src.setBlock(4, 5, 6, .repeater_on);
    src.setBlock(7, 8, 9, .redstone_lamp_on);
    src.setBlock(10, 11, 12, .redstone_torch_off);
    src.setBlock(13, 14, 15, .pressure_plate_down);
    src.setBlock(0, 0, 1, .lever_on);
    try std.testing.expect(pp.saveChunk(8, 9, &src));
    var dst = Chunk.init();
    try std.testing.expect(pp.loadChunk(8, 9, &dst));
    try std.testing.expectEqual(BlockId.redstone_wire_on, dst.getBlock(1, 2, 3));
    try std.testing.expectEqual(BlockId.repeater_on, dst.getBlock(4, 5, 6));
    try std.testing.expectEqual(BlockId.redstone_lamp_on, dst.getBlock(7, 8, 9));
    try std.testing.expectEqual(BlockId.redstone_torch_off, dst.getBlock(10, 11, 12));
    try std.testing.expectEqual(BlockId.pressure_plate_down, dst.getBlock(13, 14, 15));
    try std.testing.expectEqual(BlockId.lever_on, dst.getBlock(0, 0, 1));
}

test "torch burnout sidecar roundtrip" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const pp = Persistence.init(test_dir);
    const items = [_][4]u8{ .{ 2, 6, 3, 25 }, .{ 9, 1, 1, 7 } };
    try std.testing.expect(pp.saveTorchBurnout(4, 5, &items));
    var out = [_][4]u8{.{ 0, 0, 0, 0 }} ** 64;
    var slice: [][4]u8 = &out;
    const n = pp.loadTorchBurnout(4, 5, &slice);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(items[0], out[0]);
    try std.testing.expectEqual(items[1], out[1]);
}

test "atomic saves replace previous chunk and shorter sidecars" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const p = Persistence.init(dir);
    var src = Chunk.init();
    src.setBlock(1, 2, 3, .stone);
    try std.testing.expect(p.saveChunk(1, 2, &src));
    src.setBlock(1, 2, 3, .grass);
    try std.testing.expect(p.saveChunk(1, 2, &src));
    var dst = Chunk.init();
    try std.testing.expect(p.loadChunk(1, 2, &dst));
    try std.testing.expectEqual(BlockId.grass, dst.getBlock(1, 2, 3));
    const items = [_][4]u8{ .{ 1, 2, 3, 1 }, .{ 4, 5, 6, 2 } };
    try std.testing.expect(p.saveRepeaterStages(1, 2, &items));
    try std.testing.expect(p.saveRepeaterStages(1, 2, &.{}));
    try std.testing.expect(p.saveTorchBurnout(1, 2, &items));
    try std.testing.expect(p.saveTorchBurnout(1, 2, items[0..1]));
    var out: [64][4]u8 = undefined;
    var slice: [][4]u8 = &out;
    try std.testing.expectEqual(@as(usize, 0), p.loadRepeaterStages(1, 2, &slice));
    try std.testing.expectEqual(@as(usize, 1), p.loadTorchBurnout(1, 2, &slice));
    try std.testing.expectEqual(items[0], out[0]);
    var iter = tmp.dir.iterate();
    var count: usize = 0;
    while (try iter.next(std.testing.io)) |entry| {
        try std.testing.expect(std.mem.endsWith(u8, entry.name, ".bin") or
            std.mem.endsWith(u8, entry.name, ".rsp") or std.mem.endsWith(u8, entry.name, ".rtb"));
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "failed replacement preserves destination and removes temporary files" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    // A directory cannot be replaced by rename of a regular file.
    try tmp.dir.createDir(std.testing.io, "c_1_2.bin", .default_dir);
    try tmp.dir.createDir(std.testing.io, "c_1_2.rsp", .default_dir);
    try tmp.dir.createDir(std.testing.io, "c_1_2.rtb", .default_dir);
    const p = Persistence.init(dir);
    const chunk = Chunk.init();
    try std.testing.expect(!p.saveChunk(1, 2, &chunk));
    try std.testing.expect(!p.saveRepeaterStages(1, 2, &.{}));
    try std.testing.expect(!p.saveTorchBurnout(1, 2, &.{}));
    var iter = tmp.dir.iterate();
    var count: usize = 0;
    while (try iter.next(std.testing.io)) |entry| {
        try std.testing.expectEqual(std.Io.File.Kind.directory, entry.kind);
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "save reports inaccessible parent and oversized path" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}/missing/child", .{tmp.sub_path});
    const chunk = Chunk.init();
    try std.testing.expect(!Persistence.init(dir).saveChunk(0, 0, &chunk));
    const long_dir: [256:0]u8 = @splat('x');
    const p = Persistence.init(&long_dir);
    try std.testing.expect(!p.saveChunk(0, 0, &chunk));
    try std.testing.expect(!p.saveRepeaterStages(0, 0, &.{}));
    try std.testing.expect(!p.saveTorchBurnout(0, 0, &.{}));
}
