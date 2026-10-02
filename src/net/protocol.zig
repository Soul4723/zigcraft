const std = @import("std");

pub const MAGIC: u16 = 0x5A43; // 'ZC' (ZigCraft)
pub const HEADER_SIZE: usize = 5; // 2 magic + 1 type + 2 length
pub const MAX_PACKET_SIZE: usize = 256;

pub const MsgType = enum(u8) {
    join = 1,
    welcome = 2,
    position = 3,
    player_position = 4,
    block_edit = 5,
    player_block_edit = 6,
    player_leave = 7,
    chat = 8,
    player_chat = 9,
};

pub const JoinPacket = struct {
    name: [16]u8 = [_]u8{0} ** 16,
    name_len: u8 = 0,
};

pub const WelcomePacket = struct {
    player_id: u32,
    spawn_x: f32,
    spawn_y: f32,
    spawn_z: f32,
};

pub const PositionPacket = struct {
    x: f32,
    y: f32,
    z: f32,
    yaw: f32,
    pitch: f32,
};

pub const PlayerPositionPacket = struct {
    player_id: u32,
    x: f32,
    y: f32,
    z: f32,
    yaw: f32,
    pitch: f32,
};

pub const BlockEditPacket = struct {
    x: i32,
    y: i32,
    z: i32,
    block_id: u8,
};

pub const PlayerBlockEditPacket = struct {
    player_id: u32,
    x: i32,
    y: i32,
    z: i32,
    block_id: u8,
};

pub const PlayerLeavePacket = struct {
    player_id: u32,
};

pub const ChatPacket = struct {
    msg_len: u8 = 0,
    msg: [64]u8 = [_]u8{0} ** 64,
};

pub const PlayerChatPacket = struct {
    player_id: u32,
    msg_len: u8 = 0,
    msg: [64]u8 = [_]u8{0} ** 64,
};

pub const Packet = union(MsgType) {
    join: JoinPacket,
    welcome: WelcomePacket,
    position: PositionPacket,
    player_position: PlayerPositionPacket,
    block_edit: BlockEditPacket,
    player_block_edit: PlayerBlockEditPacket,
    player_leave: PlayerLeavePacket,
    chat: ChatPacket,
    player_chat: PlayerChatPacket,
};

fn parseMsgType(raw: u8) ?MsgType {
    inline for (std.meta.tags(MsgType)) |tag| {
        if (@intFromEnum(tag) == raw) return tag;
    }
    return null;
}

fn writeF32(dest: []u8, val: f32) void {
    const bits: u32 = @bitCast(val);
    std.mem.writeInt(u32, dest[0..4], bits, .big);
}

fn readF32(src: []const u8) f32 {
    const bits = std.mem.readInt(u32, src[0..4], .big);
    return @bitCast(bits);
}

fn writeI32(dest: []u8, val: i32) void {
    const u_val: u32 = @bitCast(val);
    std.mem.writeInt(u32, dest[0..4], u_val, .big);
}

fn readI32(src: []const u8) i32 {
    const u_val = std.mem.readInt(u32, src[0..4], .big);
    return @bitCast(u_val);
}

pub fn encode(packet: Packet, dest: []u8) !usize {
    if (dest.len < HEADER_SIZE) return error.BufferTooSmall;

    std.mem.writeInt(u16, dest[0..2], MAGIC, .big);
    dest[2] = @intFromEnum(packet);

    const payload = dest[HEADER_SIZE..];
    const len: u16 = switch (packet) {
        .join => |p| blk: {
            if (payload.len < 17) return error.BufferTooSmall;
            payload[0] = p.name_len;
            @memcpy(payload[1..17], &p.name);
            break :blk 17;
        },
        .welcome => |p| blk: {
            if (payload.len < 16) return error.BufferTooSmall;
            std.mem.writeInt(u32, payload[0..4], p.player_id, .big);
            writeF32(payload[4..8], p.spawn_x);
            writeF32(payload[8..12], p.spawn_y);
            writeF32(payload[12..16], p.spawn_z);
            break :blk 16;
        },
        .position => |p| blk: {
            if (payload.len < 20) return error.BufferTooSmall;
            writeF32(payload[0..4], p.x);
            writeF32(payload[4..8], p.y);
            writeF32(payload[8..12], p.z);
            writeF32(payload[12..16], p.yaw);
            writeF32(payload[16..20], p.pitch);
            break :blk 20;
        },
        .player_position => |p| blk: {
            if (payload.len < 24) return error.BufferTooSmall;
            std.mem.writeInt(u32, payload[0..4], p.player_id, .big);
            writeF32(payload[4..8], p.x);
            writeF32(payload[8..12], p.y);
            writeF32(payload[12..16], p.z);
            writeF32(payload[16..20], p.yaw);
            writeF32(payload[20..24], p.pitch);
            break :blk 24;
        },
        .block_edit => |p| blk: {
            if (payload.len < 13) return error.BufferTooSmall;
            writeI32(payload[0..4], p.x);
            writeI32(payload[4..8], p.y);
            writeI32(payload[8..12], p.z);
            payload[12] = p.block_id;
            break :blk 13;
        },
        .player_block_edit => |p| blk: {
            if (payload.len < 17) return error.BufferTooSmall;
            std.mem.writeInt(u32, payload[0..4], p.player_id, .big);
            writeI32(payload[4..8], p.x);
            writeI32(payload[8..12], p.y);
            writeI32(payload[12..16], p.z);
            payload[16] = p.block_id;
            break :blk 17;
        },
        .player_leave => |p| blk: {
            if (payload.len < 4) return error.BufferTooSmall;
            std.mem.writeInt(u32, payload[0..4], p.player_id, .big);
            break :blk 4;
        },
        .chat => |p| blk: {
            if (payload.len < 65) return error.BufferTooSmall;
            payload[0] = p.msg_len;
            @memcpy(payload[1..65], &p.msg);
            break :blk 65;
        },
        .player_chat => |p| blk: {
            if (payload.len < 69) return error.BufferTooSmall;
            std.mem.writeInt(u32, payload[0..4], p.player_id, .big);
            payload[4] = p.msg_len;
            @memcpy(payload[5..69], &p.msg);
            break :blk 69;
        },
    };

    std.mem.writeInt(u16, dest[3..5], len, .big);
    return HEADER_SIZE + len;
}

pub const DecodeResult = struct {
    packet: Packet,
    bytes_consumed: usize,
};

pub fn decode(src: []const u8) !?DecodeResult {
    if (src.len < HEADER_SIZE) return null;

    const magic = std.mem.readInt(u16, src[0..2], .big);
    if (magic != MAGIC) return error.InvalidMagic;

    const msg_type = parseMsgType(src[2]) orelse return error.UnknownMessageType;

    const len = std.mem.readInt(u16, src[3..5], .big);
    const total_len = HEADER_SIZE + len;
    if (src.len < total_len) return null;

    const payload = src[HEADER_SIZE..total_len];

    const packet: Packet = switch (msg_type) {
        .join => blk: {
            if (payload.len < 17) return error.MalformedPayload;
            var p = JoinPacket{
                .name_len = payload[0],
            };
            @memcpy(&p.name, payload[1..17]);
            break :blk .{ .join = p };
        },
        .welcome => blk: {
            if (payload.len < 16) return error.MalformedPayload;
            break :blk .{
                .welcome = .{
                    .player_id = std.mem.readInt(u32, payload[0..4], .big),
                    .spawn_x = readF32(payload[4..8]),
                    .spawn_y = readF32(payload[8..12]),
                    .spawn_z = readF32(payload[12..16]),
                },
            };
        },
        .position => blk: {
            if (payload.len < 20) return error.MalformedPayload;
            break :blk .{
                .position = .{
                    .x = readF32(payload[0..4]),
                    .y = readF32(payload[4..8]),
                    .z = readF32(payload[8..12]),
                    .yaw = readF32(payload[12..16]),
                    .pitch = readF32(payload[16..20]),
                },
            };
        },
        .player_position => blk: {
            if (payload.len < 24) return error.MalformedPayload;
            break :blk .{
                .player_position = .{
                    .player_id = std.mem.readInt(u32, payload[0..4], .big),
                    .x = readF32(payload[4..8]),
                    .y = readF32(payload[8..12]),
                    .z = readF32(payload[12..16]),
                    .yaw = readF32(payload[16..20]),
                    .pitch = readF32(payload[20..24]),
                },
            };
        },
        .block_edit => blk: {
            if (payload.len < 13) return error.MalformedPayload;
            break :blk .{
                .block_edit = .{
                    .x = readI32(payload[0..4]),
                    .y = readI32(payload[4..8]),
                    .z = readI32(payload[8..12]),
                    .block_id = payload[12],
                },
            };
        },
        .player_block_edit => blk: {
            if (payload.len < 17) return error.MalformedPayload;
            break :blk .{
                .player_block_edit = .{
                    .player_id = std.mem.readInt(u32, payload[0..4], .big),
                    .x = readI32(payload[4..8]),
                    .y = readI32(payload[8..12]),
                    .z = readI32(payload[12..16]),
                    .block_id = payload[16],
                },
            };
        },
        .player_leave => blk: {
            if (payload.len < 4) return error.MalformedPayload;
            break :blk .{
                .player_leave = .{
                    .player_id = std.mem.readInt(u32, payload[0..4], .big),
                },
            };
        },
        .chat => blk: {
            if (payload.len < 65) return error.MalformedPayload;
            var p = ChatPacket{
                .msg_len = payload[0],
            };
            @memcpy(&p.msg, payload[1..65]);
            break :blk .{ .chat = p };
        },
        .player_chat => blk: {
            if (payload.len < 69) return error.MalformedPayload;
            var p = PlayerChatPacket{
                .player_id = std.mem.readInt(u32, payload[0..4], .big),
                .msg_len = payload[4],
            };
            @memcpy(&p.msg, payload[5..69]);
            break :blk .{ .player_chat = p };
        },
    };

    return .{
        .packet = packet,
        .bytes_consumed = total_len,
    };
}

test "encode and decode position packet" {
    var buf: [128]u8 = undefined;
    const original = Packet{
        .position = .{
            .x = 12.5,
            .y = 34.75,
            .z = -56.125,
            .yaw = 1.57,
            .pitch = -0.25,
        },
    };

    const written = try encode(original, &buf);
    try std.testing.expectEqual(@as(usize, HEADER_SIZE + 20), written);

    const res = (try decode(buf[0..written])).?;
    try std.testing.expectEqual(written, res.bytes_consumed);

    switch (res.packet) {
        .position => |p| {
            try std.testing.expectApproxEqAbs(p.x, 12.5, 0.0001);
            try std.testing.expectApproxEqAbs(p.y, 34.75, 0.0001);
            try std.testing.expectApproxEqAbs(p.z, -56.125, 0.0001);
            try std.testing.expectApproxEqAbs(p.yaw, 1.57, 0.0001);
            try std.testing.expectApproxEqAbs(p.pitch, -0.25, 0.0001);
        },
        else => return error.UnexpectedPacketType,
    }
}

test "encode and decode block edit packet" {
    var buf: [128]u8 = undefined;
    const original = Packet{
        .block_edit = .{
            .x = -15,
            .y = 64,
            .z = 100,
            .block_id = 3,
        },
    };

    const written = try encode(original, &buf);
    try std.testing.expectEqual(@as(usize, HEADER_SIZE + 13), written);

    const res = (try decode(buf[0..written])).?;
    switch (res.packet) {
        .block_edit => |p| {
            try std.testing.expectEqual(p.x, -15);
            try std.testing.expectEqual(p.y, 64);
            try std.testing.expectEqual(p.z, 100);
            try std.testing.expectEqual(p.block_id, 3);
        },
        else => return error.UnexpectedPacketType,
    }
}

test "partial packet decode returns null" {
    var buf: [128]u8 = undefined;
    const original = Packet{
        .player_leave = .{ .player_id = 42 },
    };

    const written = try encode(original, &buf);
    // Passing only header or partial payload returns null
    const partial1 = try decode(buf[0..3]);
    try std.testing.expect(partial1 == null);

    const partial2 = try decode(buf[0 .. written - 1]);
    try std.testing.expect(partial2 == null);

    const complete = try decode(buf[0..written]);
    try std.testing.expect(complete != null);
}
