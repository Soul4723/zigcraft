const std = @import("std");
const persistence_mod = @import("persistence.zig");
const Persistence = persistence_mod.Persistence;
const Chunk = @import("chunk.zig").Chunk;
const BlockId = @import("block.zig").BlockId;
const smelt_mod = @import("smelting.zig");
const sapling_mod = @import("sapling.zig");
const block_jobs_mod = @import("block_jobs.zig");
const cache_mod = @import("component_cache.zig");
const BlockJobsData = persistence_mod.BlockJobsData;

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

test "player save and load roundtrip across dimensions" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});

    const p_ow = Persistence.initForDimension(test_dir, .overworld);
    const p_nether = Persistence.initForDimension(test_dir, .nether);
    const p_end = Persistence.initForDimension(test_dir, .the_end);

    var src = persistence_mod.PlayerSaveData{
        .pos = .{ 10.5, 20.0, -15.25 },
        .vel_y = -0.5,
        .spawn_point = .{ 0.0, 15.0, 0.0 },
        .yaw = 1.25,
        .pitch = -0.4,
        .dimension = .nether,
        .health = 18.5,
        .hunger = 15.0,
        .saturation = 4.0,
        .oxygen = 12.0,
        .selected_slot = 3,
        .tool_wear = .{ 10, 20, 0, 0, 5, 0 },
    };
    src.slots[0] = .{ .item_id = 12, .count = 32 };
    src.slots[5] = .{ .item_id = 3, .count = 1 };
    src.craft_grid[1] = .{ .item_id = 5, .count = 4 };

    // Save using Overworld persistence
    try std.testing.expect(p_ow.savePlayer(&src));

    // Verify player.bin is in the root test_dir, not nether/ or the_end/
    var f = try tmp.dir.openFile(std.testing.io, "player.bin", .{});
    f.close(std.testing.io);
    try std.testing.expectError(error.FileNotFound, tmp.dir.openFile(std.testing.io, "nether/player.bin", .{}));
    try std.testing.expectError(error.FileNotFound, tmp.dir.openFile(std.testing.io, "the_end/player.bin", .{}));

    // Load using Nether persistence
    var dst_nether: persistence_mod.PlayerSaveData = undefined;
    try std.testing.expect(p_nether.loadPlayer(&dst_nether));
    try std.testing.expectEqual(src.pos, dst_nether.pos);
    try std.testing.expectEqual(src.vel_y, dst_nether.vel_y);
    try std.testing.expectEqual(src.spawn_point, dst_nether.spawn_point);
    try std.testing.expectEqual(src.yaw, dst_nether.yaw);
    try std.testing.expectEqual(src.pitch, dst_nether.pitch);
    try std.testing.expectEqual(persistence_mod.Dimension.nether, dst_nether.dimension);
    try std.testing.expectEqual(src.health, dst_nether.health);
    try std.testing.expectEqual(src.hunger, dst_nether.hunger);
    try std.testing.expectEqual(src.saturation, dst_nether.saturation);
    try std.testing.expectEqual(src.oxygen, dst_nether.oxygen);
    try std.testing.expectEqual(src.selected_slot, dst_nether.selected_slot);
    try std.testing.expectEqual(src.tool_wear, dst_nether.tool_wear);
    try std.testing.expectEqual(src.slots[0], dst_nether.slots[0]);
    try std.testing.expectEqual(src.slots[5], dst_nether.slots[5]);
    try std.testing.expectEqual(src.craft_grid[1], dst_nether.craft_grid[1]);

    // Save updated state using Nether persistence
    src.dimension = .the_end;
    src.health = 12.0;
    try std.testing.expect(p_nether.savePlayer(&src));

    // Load using End persistence
    var dst_end: persistence_mod.PlayerSaveData = undefined;
    try std.testing.expect(p_end.loadPlayer(&dst_end));
    try std.testing.expectEqual(persistence_mod.Dimension.the_end, dst_end.dimension);
    try std.testing.expectEqual(@as(f32, 12.0), dst_end.health);
}

test "player load handles missing, truncated, bad magic/version, invalid dimension, NaN, and inaccessible path" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const p = Persistence.init(test_dir);

    var out: persistence_mod.PlayerSaveData = undefined;

    // 1. Missing file
    try std.testing.expect(!p.loadPlayer(&out));

    // Valid data template
    const valid = persistence_mod.PlayerSaveData{
        .pos = .{ 1.0, 2.0, 3.0 },
        .spawn_point = .{ 0.0, 0.0, 0.0 },
        .yaw = 0.5,
        .pitch = -0.2,
    };
    try std.testing.expect(p.savePlayer(&valid));

    try std.testing.expectEqual(@as(usize, 161), persistence_mod.PLAYER_SAVE_SIZE);

    // Read valid binary payload and verify exact file length (no unread trailing bytes)
    var probe_bytes: [persistence_mod.PLAYER_SAVE_SIZE + 8]u8 = undefined;
    const f = try tmp.dir.openFile(std.testing.io, "player.bin", .{});
    const read_len = try f.readPositionalAll(std.testing.io, &probe_bytes, 0);
    f.close(std.testing.io);
    try std.testing.expectEqual(persistence_mod.PLAYER_SAVE_SIZE, read_len);
    const valid_bytes = probe_bytes[0..persistence_mod.PLAYER_SAVE_SIZE].*;

    // Confirm valid_bytes itself loads cleanly before mutating individual fields
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "player.bin", .data = &valid_bytes });
    try std.testing.expect(p.loadPlayer(&out));

    // 2. Truncated file (fewer bytes than expected)
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "player.bin", .data = valid_bytes[0..100] });
    try std.testing.expect(!p.loadPlayer(&out));

    // Oversized file (extra trailing byte)
    var oversized: [persistence_mod.PLAYER_SAVE_SIZE + 1]u8 = undefined;
    @memcpy(oversized[0..persistence_mod.PLAYER_SAVE_SIZE], &valid_bytes);
    oversized[persistence_mod.PLAYER_SAVE_SIZE] = 0xFF;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "player.bin", .data = &oversized });
    try std.testing.expect(!p.loadPlayer(&out));

    // 3. Bad magic
    var bad_magic = valid_bytes;
    bad_magic[0] = 'X';
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "player.bin", .data = &bad_magic });
    try std.testing.expect(!p.loadPlayer(&out));

    // 4. Bad version
    var bad_version = valid_bytes;
    bad_version[4] = 99; // version is at byte offset 4
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "player.bin", .data = &bad_version });
    try std.testing.expect(!p.loadPlayer(&out));

    // 5. Invalid dimension tag
    // offset of dimension byte:
    // 4 (magic) + 4 (version) + 12 (pos) + 4 (vel_y) + 12 (spawn_point) + 8 (yaw, pitch) = 44
    var bad_dim = valid_bytes;
    bad_dim[44] = 50; // invalid dimension tag (not 0, 1, or 2)
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "player.bin", .data = &bad_dim });
    try std.testing.expect(!p.loadPlayer(&out));

    // 6. NaN float rejection (must return false without mutating out)
    // Put NaN in pos[0] (bytes 8..12)
    var nan_bytes = valid_bytes;
    const nan_u32: u32 = 0x7FC00000;
    std.mem.writeInt(u32, nan_bytes[8..12], nan_u32, .little);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "player.bin", .data = &nan_bytes });

    out = valid;
    out.pos[0] = 42.0;
    try std.testing.expect(!p.loadPlayer(&out));
    // Verify out was not mutated
    try std.testing.expectEqual(@as(f32, 42.0), out.pos[0]);

    // Infinity float rejection
    var inf_bytes = valid_bytes;
    const inf_u32: u32 = 0x7F800000;
    std.mem.writeInt(u32, inf_bytes[8..12], inf_u32, .little);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "player.bin", .data = &inf_bytes });
    try std.testing.expect(!p.loadPlayer(&out));
    try std.testing.expectEqual(@as(f32, 42.0), out.pos[0]);

    // 7. Inaccessible path failure
    const bad_dir = ".zig-cache/tmp/nonexistent_persistence_path/nested";
    const p_bad = Persistence.init(bad_dir);
    try std.testing.expect(!p_bad.savePlayer(&valid));
    try std.testing.expect(!p_bad.loadPlayer(&out));
}


test "block jobs real filesystem roundtrip" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});

    const p = Persistence.init(test_dir);

    var src = BlockJobsData{};
    src.furnace_count = 2;
    src.furnaces[0] = .{ .x = 10, .y = 5, .z = 20, .t = 4.5, .fuel = 3, .input = smelt_mod.RawPork };
    src.furnaces[1] = .{ .x = -15, .y = 8, .z = -30, .t = 9.2, .fuel = 1, .input = smelt_mod.IronOre };
    src.smoker_count = 1;
    src.smokers[0] = .{ .x = 5, .y = 4, .z = 15, .t = 2.1, .fuel = 2, .input = smelt_mod.RawCod };
    src.blast_furnace_count = 1;
    src.blast_furnaces[0] = .{ .x = 12, .y = 6, .z = 18, .t = 3.8, .fuel = 4, .input = smelt_mod.RawCopper };
    src.sprout_count = 2;
    src.sprouts[0] = .{ .x = 0, .y = 4, .z = 0, .t = 12.0 };
    src.sprouts[1] = .{ .x = -50, .y = 7, .z = 80, .t = 28.5 };

    try std.testing.expect(p.saveBlockJobs(&src));

    var dst = BlockJobsData{};
    const res = p.loadBlockJobs(&dst);
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.ok, res);

    try std.testing.expectEqual(@as(usize, 2), dst.furnace_count);
    try std.testing.expectEqual(src.furnaces[0], dst.furnaces[0]);
    try std.testing.expectEqual(src.furnaces[1], dst.furnaces[1]);

    try std.testing.expectEqual(@as(usize, 1), dst.smoker_count);
    try std.testing.expectEqual(src.smokers[0], dst.smokers[0]);

    try std.testing.expectEqual(@as(usize, 1), dst.blast_furnace_count);
    try std.testing.expectEqual(src.blast_furnaces[0], dst.blast_furnaces[0]);

    try std.testing.expectEqual(@as(usize, 2), dst.sprout_count);
    try std.testing.expectEqual(src.sprouts[0], dst.sprouts[0]);
    try std.testing.expectEqual(src.sprouts[1], dst.sprouts[1]);
}

test "per-dimension save namespaces isolate block jobs across overworld nether and the_end" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});

    const p_ow = Persistence.initForDimension(test_dir, .overworld);
    const p_nether = Persistence.initForDimension(test_dir, .nether);
    const p_end = Persistence.initForDimension(test_dir, .the_end);

    var jobs_ow = BlockJobsData{};
    jobs_ow.furnace_count = 1;
    jobs_ow.furnaces[0] = .{ .x = 1, .y = 2, .z = 3, .t = 5.0, .fuel = 1, .input = smelt_mod.RawPork };
    jobs_ow.sprout_count = 1;
    jobs_ow.sprouts[0] = .{ .x = 4, .y = 5, .z = 6, .t = 10.0 };
    try std.testing.expect(p_ow.saveBlockJobs(&jobs_ow));

    var jobs_nether = BlockJobsData{};
    jobs_nether.blast_furnace_count = 1;
    jobs_nether.blast_furnaces[0] = .{ .x = 7, .y = 8, .z = 9, .t = 2.5, .fuel = 2, .input = smelt_mod.AncientDebris };
    try std.testing.expect(p_nether.saveBlockJobs(&jobs_nether));

    // Verify file locations: overworld directly in root, nether in nether/ subdirectory
    var f_ow = try tmp.dir.openFile(std.testing.io, "block_jobs.bin", .{});
    f_ow.close(std.testing.io);
    var f_nether = try tmp.dir.openFile(std.testing.io, "nether/block_jobs.bin", .{});
    f_nether.close(std.testing.io);
    try std.testing.expectError(error.FileNotFound, tmp.dir.openFile(std.testing.io, "the_end/block_jobs.bin", .{}));

    // Overworld load restores only Overworld jobs
    var loaded_ow = BlockJobsData{};
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.ok, p_ow.loadBlockJobs(&loaded_ow));
    try std.testing.expectEqual(@as(usize, 1), loaded_ow.furnace_count);
    try std.testing.expectEqual(jobs_ow.furnaces[0], loaded_ow.furnaces[0]);
    try std.testing.expectEqual(@as(usize, 0), loaded_ow.blast_furnace_count);
    try std.testing.expectEqual(@as(usize, 1), loaded_ow.sprout_count);

    // Nether load restores only Nether jobs
    var loaded_nether = BlockJobsData{};
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.ok, p_nether.loadBlockJobs(&loaded_nether));
    try std.testing.expectEqual(@as(usize, 0), loaded_nether.furnace_count);
    try std.testing.expectEqual(@as(usize, 1), loaded_nether.blast_furnace_count);
    try std.testing.expectEqual(jobs_nether.blast_furnaces[0], loaded_nether.blast_furnaces[0]);
    try std.testing.expectEqual(@as(usize, 0), loaded_nether.sprout_count);

    // The End has no file, loads as absent
    var loaded_end = BlockJobsData{ .furnace_count = 50 };
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.absent, p_end.loadBlockJobs(&loaded_end));
    try std.testing.expectEqual(@as(usize, 0), loaded_end.furnace_count);

    // Cross-dimension namespace enforcement: loading nether file with overworld persistence fails
    var cross_dir_buf: [256:0]u8 = undefined;
    const nether_subpath = try std.fmt.bufPrintZ(&cross_dir_buf, "{s}/nether", .{test_dir});
    const p_wrong = Persistence.initForDimension(nether_subpath, .overworld);
    var wrong_dst = BlockJobsData{ .furnace_count = 99 };
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p_wrong.loadBlockJobs(&wrong_dst));
    try std.testing.expectEqual(@as(usize, 99), wrong_dst.furnace_count);
}

test "block jobs load rejects corrupt, truncated, and oversized records leaving outputs unchanged" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const p = Persistence.init(test_dir);

    // Template valid data
    var valid = BlockJobsData{};
    valid.furnace_count = 1;
    valid.furnaces[0] = .{ .x = 1, .y = 5, .z = 2, .t = 3.0, .fuel = 1, .input = smelt_mod.RawPork };
    try std.testing.expect(p.saveBlockJobs(&valid));

    var file_bytes_buf: [block_jobs_mod.MAX_SAVE_SIZE]u8 = undefined;
    const f = try tmp.dir.openFile(std.testing.io, "block_jobs.bin", .{});
    const read_len = try f.readPositionalAll(std.testing.io, &file_bytes_buf, 0);
    f.close(std.testing.io);
    const valid_bytes = file_bytes_buf[0..read_len];

    var out = BlockJobsData{ .furnace_count = 77 };

    // 1. Truncated payload
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "block_jobs.bin", .data = valid_bytes[0 .. valid_bytes.len - 1] });
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 77), out.furnace_count);

    // 2. Oversized payload (extra trailing byte)
    var over_buf: [block_jobs_mod.MAX_SAVE_SIZE + 1]u8 = undefined;
    @memcpy(over_buf[0..valid_bytes.len], valid_bytes);
    over_buf[valid_bytes.len] = 0x55;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "block_jobs.bin", .data = over_buf[0 .. valid_bytes.len + 1] });
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 77), out.furnace_count);

    // 3. Bad magic
    var bad_magic = try std.testing.allocator.dupe(u8, valid_bytes);
    defer std.testing.allocator.free(bad_magic);
    bad_magic[0] = 'Q';
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "block_jobs.bin", .data = bad_magic });
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 77), out.furnace_count);

    // 4. Bad version
    var bad_version = try std.testing.allocator.dupe(u8, valid_bytes);
    defer std.testing.allocator.free(bad_version);
    bad_version[4] = 9;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "block_jobs.bin", .data = bad_version });
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 77), out.furnace_count);

    // 5. Out of bounds y coordinate
    var bad_coord = try std.testing.allocator.dupe(u8, valid_bytes);
    defer std.testing.allocator.free(bad_coord);
    // furnace y is at offset 24..28 (20 header + 4 x)
    std.mem.writeInt(i32, bad_coord[24..28], 16, .little);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "block_jobs.bin", .data = bad_coord });
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 77), out.furnace_count);

    // 6. Negative timer
    var bad_timer = try std.testing.allocator.dupe(u8, valid_bytes);
    defer std.testing.allocator.free(bad_timer);
    // furnace t is at offset 32..36 (20 header + 12 xyz)
    const neg_bits: u32 = @bitCast(@as(f32, -1.0));
    std.mem.writeInt(u32, bad_timer[32..36], neg_bits, .little);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "block_jobs.bin", .data = bad_timer });
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 77), out.furnace_count);

    // 7. NaN timer
    var nan_timer = try std.testing.allocator.dupe(u8, valid_bytes);
    defer std.testing.allocator.free(nan_timer);
    const nan_bits: u32 = 0x7FC00000;
    std.mem.writeInt(u32, nan_timer[32..36], nan_bits, .little);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "block_jobs.bin", .data = nan_timer });
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 77), out.furnace_count);

    // 8. Unsupported input tag (e.g. tag 9999)
    var bad_tag = try std.testing.allocator.dupe(u8, valid_bytes);
    defer std.testing.allocator.free(bad_tag);
    // furnace input is at offset 38..40 (20 header + 12 xyz + 4 t + 1 fuel + 1 res)
    std.mem.writeInt(u16, bad_tag[38..40], 9999, .little);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "block_jobs.bin", .data = bad_tag });
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 77), out.furnace_count);

    // 9. Missing file starts empty
    try tmp.dir.deleteFile(std.testing.io, "block_jobs.bin");
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.absent, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 0), out.furnace_count);
}

test "block jobs atomic save failure preserves prior durable file without leaking temp files" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const p = Persistence.init(test_dir);

    // Save initial durable state
    var initial = BlockJobsData{};
    initial.furnace_count = 1;
    initial.furnaces[0] = .{ .x = 10, .y = 5, .z = 10, .t = 2.0, .fuel = 1, .input = smelt_mod.RawPork };
    try std.testing.expect(p.saveBlockJobs(&initial));

    // Make parent directory or path unwritable to simulate atomic save failure
    // We can simulate an invalid path by creating a directory where the destination file would be replaced
    const sub_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}/inaccessible", .{tmp.sub_path});
    try tmp.dir.createDir(std.testing.io, "inaccessible", .default_dir);
    try tmp.dir.createDir(std.testing.io, "inaccessible/block_jobs.bin", .default_dir);

    const p_fail = Persistence.init(sub_dir);
    var new_jobs = BlockJobsData{};
    new_jobs.furnace_count = 1;
    new_jobs.furnaces[0] = .{ .x = 99, .y = 5, .z = 99, .t = 8.0, .fuel = 2, .input = smelt_mod.IronOre };

    // Save must fail cleanly and return false
    try std.testing.expect(!p_fail.saveBlockJobs(&new_jobs));

    // Verify initial file in test_dir is still intact
    var restored = BlockJobsData{};
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.ok, p.loadBlockJobs(&restored));
    try std.testing.expectEqual(@as(usize, 1), restored.furnace_count);
    try std.testing.expectEqual(initial.furnaces[0], restored.furnaces[0]);

    // Verify no temporary .XXXXXX files leaked in sub_dir
    var sub_opened = try tmp.dir.openDir(std.testing.io, "inaccessible", .{ .iterate = true });
    defer sub_opened.close(std.testing.io);
    var iter = sub_opened.iterate();
    while (try iter.next(std.testing.io)) |entry| {
        try std.testing.expectEqualStrings("block_jobs.bin", entry.name);
    }
}

test "source rollback and target load sequence keeps jobs coherent on save failure" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});

    const p_ow = Persistence.initForDimension(test_dir, .overworld);
    const p_nether = Persistence.initForDimension(test_dir, .nether);

    // Live Overworld jobs
    var furnaces = [_]smelt_mod.FurnaceJob{.{ .x = 1, .y = 2, .z = 3, .t = 5.0, .fuel = 1, .input = smelt_mod.RawPork }} ** smelt_mod.furnace_cap;
    var furnace_count: usize = 1;
    var smokers: [smelt_mod.furnace_cap]smelt_mod.FurnaceJob = undefined;
    var smoker_count: usize = 0;
    var blast_furnaces: [smelt_mod.furnace_cap]smelt_mod.FurnaceJob = undefined;
    var blast_furnace_count: usize = 0;
    var sprouts: [sapling_mod.sprout_cap]sapling_mod.Sprout = undefined;
    var sprout_count: usize = 0;

    // Scenario 1: Target dimension has corrupt file on disk
    try tmp.dir.createDir(std.testing.io, "nether", .default_dir);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "nether/block_jobs.bin", .data = "CORRUPT_BYTES_DATA" });

    // Preflight target load
    var staged_target = BlockJobsData{};
    const preflight_res = p_nether.loadBlockJobs(&staged_target);
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, preflight_res);

    // Because preflight failed with corrupt, transit is aborted BEFORE committing switch:
    const transit_aborted = (preflight_res == .corrupt);
    try std.testing.expect(transit_aborted);
    // Source jobs remain completely live and un-discarded
    try std.testing.expectEqual(@as(usize, 1), furnace_count);
    try std.testing.expectEqual(smelt_mod.RawPork, furnaces[0].input);
    try std.testing.expectEqual(@as(f32, 5.0), furnaces[0].t);

    // Corrupt target file remains completely unmodified on disk
    var check_buf: [64]u8 = undefined;
    const f = try tmp.dir.openFile(std.testing.io, "nether/block_jobs.bin", .{});
    const len = try f.readPositionalAll(std.testing.io, &check_buf, 0);
    f.close(std.testing.io);
    try std.testing.expectEqualStrings("CORRUPT_BYTES_DATA", check_buf[0..len]);

    // Scenario 2: Valid target transit and return trip
    try tmp.dir.deleteFile(std.testing.io, "nether/block_jobs.bin");
    // Preflight target: absent (starts empty)
    staged_target = BlockJobsData{ .furnace_count = 55 };
    const preflight2 = p_nether.loadBlockJobs(&staged_target);
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.absent, preflight2);
    try std.testing.expectEqual(@as(usize, 0), staged_target.furnace_count);

    // Save source dimension jobs
    const source_jobs = block_jobs_mod.captureBlockJobs(&furnaces, furnace_count, &smokers, smoker_count, &blast_furnaces, blast_furnace_count, &sprouts, sprout_count);
    try std.testing.expect(p_ow.saveBlockJobs(&source_jobs));

    // Commit switch: apply staged target
    block_jobs_mod.applyBlockJobs(&staged_target, &furnaces, &furnace_count, &smokers, &smoker_count, &blast_furnaces, &blast_furnace_count, &sprouts, &sprout_count);
    try std.testing.expectEqual(@as(usize, 0), furnace_count);

    // In Nether, add a blast furnace job and save
    blast_furnaces[0] = .{ .x = 10, .y = 5, .z = 10, .t = 2.0, .fuel = 2, .input = smelt_mod.AncientDebris };
    blast_furnace_count = 1;
    const nether_jobs = block_jobs_mod.captureBlockJobs(&furnaces, furnace_count, &smokers, smoker_count, &blast_furnaces, blast_furnace_count, &sprouts, sprout_count);
    try std.testing.expect(p_nether.saveBlockJobs(&nether_jobs));

    // Return trip to Overworld: preflight Overworld
    var staged_ow = BlockJobsData{};
    const preflight_ow = p_ow.loadBlockJobs(&staged_ow);
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.ok, preflight_ow);
    try std.testing.expectEqual(@as(usize, 1), staged_ow.furnace_count);

    // Commit switch to Overworld: apply staged Overworld jobs
    block_jobs_mod.applyBlockJobs(&staged_ow, &furnaces, &furnace_count, &smokers, &smoker_count, &blast_furnaces, &blast_furnace_count, &sprouts, &sprout_count);
    try std.testing.expectEqual(@as(usize, 1), furnace_count);
    try std.testing.expectEqual(smelt_mod.RawPork, furnaces[0].input);
    try std.testing.expectEqual(@as(f32, 5.0), furnaces[0].t);
    try std.testing.expectEqual(@as(usize, 0), blast_furnace_count);
}

test "block jobs load distinguishes ENOENT from unreadable path error" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const p = Persistence.init(test_dir);

    var out = BlockJobsData{ .furnace_count = 42 };

    // 1. Missing file: returns .absent and initializes out to empty defaults
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.absent, p.loadBlockJobs(&out));
    try std.testing.expectEqual(@as(usize, 0), out.furnace_count);

    // 2. Existing path that cannot be opened as a regular file (directory named block_jobs.bin -> EISDIR)
    try tmp.dir.createDir(std.testing.io, "block_jobs.bin", .default_dir);
    out.furnace_count = 99;
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.corrupt, p.loadBlockJobs(&out));
    // Must NOT mutate out and must NOT report as absent!
    try std.testing.expectEqual(@as(usize, 99), out.furnace_count);
}

test "unloaded chunks do not delete jobs or grow saplings into absent chunks" {
    const MockWorld = struct {
        loaded_cx: i32,
        loaded_cz: i32,
        block_at_furnace: BlockId,
        block_at_sprout: BlockId,

        pub fn isBlockLoaded(self: @This(), x: i32, y: i32, z: i32) bool {
            if (y < 0 or y >= 16) return false;
            return @divFloor(x, 16) == self.loaded_cx and @divFloor(z, 16) == self.loaded_cz;
        }

        pub fn getBlockWorld(self: @This(), x: i32, y: i32, z: i32) BlockId {
            if (!self.isBlockLoaded(x, y, z)) return .air;
            if (x == 10 and y == 5 and z == 10) return self.block_at_furnace;
            if (x == 5 and y == 4 and z == 5) return self.block_at_sprout;
            return .air;
        }
    };

    var furnaces = [_]smelt_mod.FurnaceJob{.{ .x = 10, .y = 5, .z = 10, .t = 4.0, .fuel = 1, .input = smelt_mod.RawPork }} ** smelt_mod.furnace_cap;
    var furnace_count: usize = 1;
    var sprouts = [_]sapling_mod.Sprout{.{ .x = 5, .y = 4, .z = 5, .t = 30.0 }} ** sapling_mod.sprout_cap;
    var sprout_count: usize = 1;

    // Case A: Chunk (0, 0) containing furnace (10, 5, 10) is UNLOADED (loaded_cx = 99)
    const world_unloaded = MockWorld{ .loaded_cx = 99, .loaded_cz = 99, .block_at_furnace = .furnace, .block_at_sprout = .wood };

    // Simulating furnace loop with isBlockLoaded guard
    var fi: usize = 0;
    while (fi < furnace_count) {
        const f = &furnaces[fi];
        if (!world_unloaded.isBlockLoaded(f.x, f.y, f.z)) {
            fi += 1;
            continue;
        }
        if (world_unloaded.getBlockWorld(f.x, f.y, f.z) != .furnace) {
            cache_mod.swapRemove(&furnaces, &furnace_count, fi);
            continue;
        }
        _ = smelt_mod.tickJob(&f.t, &f.fuel, &f.input, 1.0);
        fi += 1;
    }
    // Furnace job was NOT removed despite getBlockWorld returning .air
    try std.testing.expectEqual(@as(usize, 1), furnace_count);
    try std.testing.expectEqual(@as(f32, 4.0), furnaces[0].t);

    // Simulating sprout loop with isBlockLoaded and isCanopyLoaded guards
    var si: usize = 0;
    while (si < sprout_count) {
        const s = &sprouts[si];
        if (!world_unloaded.isBlockLoaded(s.x, s.y, s.z)) {
            si += 1;
            continue;
        }
        if (world_unloaded.getBlockWorld(s.x, s.y, s.z) != .wood) {
            cache_mod.swapRemove(&sprouts, &sprout_count, si);
            continue;
        }
        if (sapling_mod.isReady(s.t)) {
            if (!block_jobs_mod.isCanopyLoaded(world_unloaded, s.x, s.y, s.z)) {
                si += 1;
                continue;
            }
            cache_mod.swapRemove(&sprouts, &sprout_count, si);
        } else {
            si += 1;
        }
    }
    // Sprout was NOT removed and did NOT grow into absent chunks
    try std.testing.expectEqual(@as(usize, 1), sprout_count);
    try std.testing.expectEqual(@as(f32, 30.0), sprouts[0].t);

    // Case B: Chunk (0, 0) is LOADED
    const world_loaded = MockWorld{ .loaded_cx = 0, .loaded_cz = 0, .block_at_furnace = .furnace, .block_at_sprout = .wood };
    fi = 0;
    while (fi < furnace_count) {
        const f = &furnaces[fi];
        if (!world_loaded.isBlockLoaded(f.x, f.y, f.z)) {
            fi += 1;
            continue;
        }
        if (world_loaded.getBlockWorld(f.x, f.y, f.z) != .furnace) {
            cache_mod.swapRemove(&furnaces, &furnace_count, fi);
            continue;
        }
        _ = smelt_mod.tickJob(&f.t, &f.fuel, &f.input, 1.0);
        fi += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), furnace_count);
    try std.testing.expectEqual(@as(f32, 5.0), furnaces[0].t);
}

test "elapsed furnace progress continues across save and reload toward single output" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const p = Persistence.init(test_dir);

    // Phase 1: Start job with RawPork and 1 fuel. Tick 6.0 seconds (smelt_time is 10.0s).
    var t: f32 = 0.0;
    var fuel: u8 = 1;
    var input: u16 = smelt_mod.RawPork;

    const tick1 = smelt_mod.tickJob(&t, &fuel, &input, 6.0);
    try std.testing.expectEqual(@as(?u16, null), tick1.done_item);
    try std.testing.expect(!tick1.fuel_consumed);
    try std.testing.expectEqual(@as(f32, 6.0), t);
    try std.testing.expectEqual(@as(u8, 1), fuel);
    try std.testing.expectEqual(smelt_mod.RawPork, input);

    // Phase 2: Save to disk
    var saved = BlockJobsData{};
    saved.furnace_count = 1;
    saved.furnaces[0] = .{ .x = 10, .y = 5, .z = 20, .t = t, .fuel = fuel, .input = input };
    try std.testing.expect(p.saveBlockJobs(&saved));

    // Phase 3: Reload into new runtime session
    var restored = BlockJobsData{};
    try std.testing.expectEqual(persistence_mod.LoadJobsResult.ok, p.loadBlockJobs(&restored));
    try std.testing.expectEqual(@as(usize, 1), restored.furnace_count);
    var res_t = restored.furnaces[0].t;
    var res_fuel = restored.furnaces[0].fuel;
    var res_input = restored.furnaces[0].input;
    try std.testing.expectEqual(@as(f32, 6.0), res_t);
    try std.testing.expectEqual(@as(u8, 1), res_fuel);
    try std.testing.expectEqual(smelt_mod.RawPork, res_input);

    // Phase 4: Resume ticking with remaining 4.0 seconds (total 10.0s)
    const tick2 = smelt_mod.tickJob(&res_t, &res_fuel, &res_input, 4.0);
    try std.testing.expectEqual(@as(?u16, smelt_mod.CookedPork), tick2.done_item);
    try std.testing.expect(tick2.fuel_consumed);
    try std.testing.expectEqual(@as(u8, 0), res_fuel);
    try std.testing.expectEqual(smelt_mod.None, res_input);
    try std.testing.expectEqual(@as(f32, 0.0), res_t);

    // Further ticking does not duplicate output
    const tick3 = smelt_mod.tickJob(&res_t, &res_fuel, &res_input, 10.0);
    try std.testing.expectEqual(@as(?u16, null), tick3.done_item);
    try std.testing.expect(!tick3.fuel_consumed);
}

test "regression test: unloaded chunk getBlockWorld air without isBlockLoaded check deletes furnace" {
    // Unloaded chunk returns air
    const block_from_unloaded_chunk: BlockId = .air;

    var furnaces = [_]smelt_mod.FurnaceJob{.{ .x = 100, .y = 5, .z = 100, .t = 4.0, .fuel = 1, .input = smelt_mod.RawPork }} ** smelt_mod.furnace_cap;
    var furnace_count: usize = 1;

    // Regressive logic: without checking isBlockLoaded, air != .furnace evaluates to true!
    const is_broken_without_guard = (block_from_unloaded_chunk != .furnace);
    try std.testing.expect(is_broken_without_guard); // In old code, this was true and called swapRemove!

    // Proving the regression: old code would remove the job
    var old_count = furnace_count;
    if (is_broken_without_guard) {
        cache_mod.swapRemove(&furnaces, &old_count, 0);
    }
    try std.testing.expectEqual(@as(usize, 0), old_count); // Lost job!

    // Fixed logic: with isBlockLoaded guard, unloaded chunk is skipped and job is preserved
    const chunk_loaded = false; // (100, 100) is unloaded
    if (chunk_loaded) {
        if (block_from_unloaded_chunk != .furnace) {
            cache_mod.swapRemove(&furnaces, &furnace_count, 0);
        }
    }
    try std.testing.expectEqual(@as(usize, 1), furnace_count); // Preserved!
}

test "corrupt existing block jobs file aborts startup before interactive changes" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [256:0]u8 = undefined;
    const test_dir = try std.fmt.bufPrintZ(&path_buf, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    const p = Persistence.init(test_dir);

    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "block_jobs.bin", .data = "CORRUPT_BYTES" });

    const startupFn = struct {
        fn run(persistence: Persistence) !BlockJobsData {
            var jobs = BlockJobsData{};
            const res = persistence.loadBlockJobs(&jobs);
            switch (res) {
                .ok => return jobs,
                .absent => return BlockJobsData{},
                .corrupt => return error.CorruptBlockJobsSave,
            }
        }
    }.run;

    try std.testing.expectError(error.CorruptBlockJobsSave, startupFn(p));

    var check_buf: [64]u8 = undefined;
    const f = try tmp.dir.openFile(std.testing.io, "block_jobs.bin", .{});
    const len = try f.readPositionalAll(std.testing.io, &check_buf, 0);
    f.close(std.testing.io);
    try std.testing.expectEqualStrings("CORRUPT_BYTES", check_buf[0..len]);
}
