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

test "existing overworld saves in root dir_path load via init and initForDimension" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});

    const p_legacy = Persistence.init(test_dir);
    const p_overworld = Persistence.initForDimension(test_dir, .overworld);

    var src = Chunk.init();
    src.setBlock(3, 4, 5, .stone);
    src.setBlock(1, 1, 1, .water);
    src.setLevel(1, 1, 1, 7);
    try std.testing.expect(p_legacy.saveChunk(0, 0, &src));

    const stages = [_][4]u8{.{ 1, 2, 3, 2 }};
    try std.testing.expect(p_legacy.saveRepeaterStages(0, 0, &stages));

    const burnouts = [_][4]u8{.{ 4, 5, 6, 15 }};
    try std.testing.expect(p_legacy.saveTorchBurnout(0, 0, &burnouts));

    var check_file = try tmp.dir.openFile(std.testing.io, "c_0_0.bin", .{});
    check_file.close(std.testing.io);

    // Load via Persistence.init(dir_path)
    var dst_legacy = Chunk.init();
    try std.testing.expect(p_legacy.loadChunk(0, 0, &dst_legacy));
    try std.testing.expectEqual(BlockId.stone, dst_legacy.getBlock(3, 4, 5));
    try std.testing.expectEqual(@as(u4, 7), dst_legacy.getLevel(1, 1, 1));

    var stage_out: [64][4]u8 = undefined;
    var stage_slice: [][4]u8 = &stage_out;
    try std.testing.expectEqual(@as(usize, 1), p_legacy.loadRepeaterStages(0, 0, &stage_slice));
    try std.testing.expectEqual(stages[0], stage_out[0]);

    var burnout_out: [64][4]u8 = undefined;
    var burnout_slice: [][4]u8 = &burnout_out;
    try std.testing.expectEqual(@as(usize, 1), p_legacy.loadTorchBurnout(0, 0, &burnout_slice));
    try std.testing.expectEqual(burnouts[0], burnout_out[0]);

    // Load via Persistence.initForDimension(dir_path, .overworld)
    var dst_ow = Chunk.init();
    try std.testing.expect(p_overworld.loadChunk(0, 0, &dst_ow));
    try std.testing.expectEqual(BlockId.stone, dst_ow.getBlock(3, 4, 5));
    try std.testing.expectEqual(@as(u4, 7), dst_ow.getLevel(1, 1, 1));

    try std.testing.expectEqual(@as(usize, 1), p_overworld.loadRepeaterStages(0, 0, &stage_slice));
    try std.testing.expectEqual(stages[0], stage_out[0]);

    try std.testing.expectEqual(@as(usize, 1), p_overworld.loadTorchBurnout(0, 0, &burnout_slice));
    try std.testing.expectEqual(burnouts[0], burnout_out[0]);
}

test "per-dimension save namespaces isolate overworld nether and the_end without collision" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});

    const p_ow = Persistence.initForDimension(test_dir, .overworld);
    const p_nether = Persistence.initForDimension(test_dir, .nether);
    const p_end = Persistence.initForDimension(test_dir, .the_end);

    var chunk_ow = Chunk.init();
    chunk_ow.setBlock(2, 3, 4, .grass);
    chunk_ow.setBlock(0, 0, 0, .water);
    chunk_ow.setLevel(0, 0, 0, 5);
    const stages_ow = [_][4]u8{.{ 1, 1, 1, 1 }};
    const burnout_ow = [_][4]u8{.{ 2, 2, 2, 10 }};

    var chunk_nether = Chunk.init();
    chunk_nether.setBlock(2, 3, 4, .netherrack);
    chunk_nether.setBlock(0, 0, 0, .lava);
    const stages_nether = [_][4]u8{.{ 3, 3, 3, 2 }};
    const burnout_nether = [_][4]u8{.{ 4, 4, 4, 20 }};

    var chunk_end = Chunk.init();
    chunk_end.setBlock(2, 3, 4, .end_stone);
    chunk_end.setBlock(0, 0, 0, .purpur_block);
    const stages_end = [_][4]u8{.{ 5, 5, 5, 3 }};
    const burnout_end = [_][4]u8{.{ 6, 6, 6, 30 }};

    // Save (0, 0) chunks and sidecars in all three dimensions
    try std.testing.expect(p_ow.saveChunk(0, 0, &chunk_ow));
    try std.testing.expect(p_ow.saveRepeaterStages(0, 0, &stages_ow));
    try std.testing.expect(p_ow.saveTorchBurnout(0, 0, &burnout_ow));

    try std.testing.expect(p_nether.saveChunk(0, 0, &chunk_nether));
    try std.testing.expect(p_nether.saveRepeaterStages(0, 0, &stages_nether));
    try std.testing.expect(p_nether.saveTorchBurnout(0, 0, &burnout_nether));

    try std.testing.expect(p_end.saveChunk(0, 0, &chunk_end));
    try std.testing.expect(p_end.saveRepeaterStages(0, 0, &stages_end));
    try std.testing.expect(p_end.saveTorchBurnout(0, 0, &burnout_end));

    // Verify file locations: overworld directly in root, nether and the_end in subdirectories
    var f1 = try tmp.dir.openFile(std.testing.io, "c_0_0.bin", .{});
    f1.close(std.testing.io);
    var f2 = try tmp.dir.openFile(std.testing.io, "nether/c_0_0.bin", .{});
    f2.close(std.testing.io);
    var f3 = try tmp.dir.openFile(std.testing.io, "the_end/c_0_0.bin", .{});
    f3.close(std.testing.io);

    // Verify Overworld roundtrip
    var dst_ow = Chunk.init();
    try std.testing.expect(p_ow.loadChunk(0, 0, &dst_ow));
    try std.testing.expectEqual(BlockId.grass, dst_ow.getBlock(2, 3, 4));
    try std.testing.expectEqual(BlockId.water, dst_ow.getBlock(0, 0, 0));
    try std.testing.expectEqual(@as(u4, 5), dst_ow.getLevel(0, 0, 0));

    var stage_buf: [64][4]u8 = undefined;
    var stage_slice: [][4]u8 = &stage_buf;
    try std.testing.expectEqual(@as(usize, 1), p_ow.loadRepeaterStages(0, 0, &stage_slice));
    try std.testing.expectEqual(stages_ow[0], stage_buf[0]);

    var burnout_buf: [64][4]u8 = undefined;
    var burnout_slice: [][4]u8 = &burnout_buf;
    try std.testing.expectEqual(@as(usize, 1), p_ow.loadTorchBurnout(0, 0, &burnout_slice));
    try std.testing.expectEqual(burnout_ow[0], burnout_buf[0]);

    // Verify Nether roundtrip
    var dst_nether = Chunk.init();
    try std.testing.expect(p_nether.loadChunk(0, 0, &dst_nether));
    try std.testing.expectEqual(BlockId.netherrack, dst_nether.getBlock(2, 3, 4));
    try std.testing.expectEqual(BlockId.lava, dst_nether.getBlock(0, 0, 0));
    try std.testing.expectEqual(@as(u4, 0), dst_nether.getLevel(0, 0, 0));

    try std.testing.expectEqual(@as(usize, 1), p_nether.loadRepeaterStages(0, 0, &stage_slice));
    try std.testing.expectEqual(stages_nether[0], stage_buf[0]);

    try std.testing.expectEqual(@as(usize, 1), p_nether.loadTorchBurnout(0, 0, &burnout_slice));
    try std.testing.expectEqual(burnout_nether[0], burnout_buf[0]);

    // Verify The End roundtrip (also testing withDimension)
    const p_end_with = p_ow.withDimension(.the_end);
    var dst_end = Chunk.init();
    try std.testing.expect(p_end_with.loadChunk(0, 0, &dst_end));
    try std.testing.expectEqual(BlockId.end_stone, dst_end.getBlock(2, 3, 4));
    try std.testing.expectEqual(BlockId.purpur_block, dst_end.getBlock(0, 0, 0));

    try std.testing.expectEqual(@as(usize, 1), p_end_with.loadRepeaterStages(0, 0, &stage_slice));
    try std.testing.expectEqual(stages_end[0], stage_buf[0]);

    try std.testing.expectEqual(@as(usize, 1), p_end_with.loadTorchBurnout(0, 0, &burnout_slice));
    try std.testing.expectEqual(burnout_end[0], burnout_buf[0]);
}
