const std = @import("std");

pub const PROTOCOL_VERSION: u32 = 1;
pub const DEFAULT_PORT: u16 = 25565;

pub const PacketType = enum(u8) {
    handshake = 1,
    handshake_ack = 2,
    player_pos = 3,
    block_edit = 4,
    chat_message = 5,
    disconnect = 6,
};

pub const HandshakePacket = extern struct {
    version: u32,
    client_id: u32,
};

pub const HandshakeAckPacket = extern struct {
    server_version: u32,
    assigned_player_id: u32,
};

pub const PlayerPosPacket = extern struct {
    player_id: u32,
    x: f32,
    y: f32,
    z: f32,
    yaw: f32,
    pitch: f32,
};

pub const BlockEditPacket = extern struct {
    player_id: u32,
    x: i32,
    y: i32,
    z: i32,
    block_id: u8,
};

pub const ChatMessagePacket = extern struct {
    player_id: u32,
    len: u8,
    msg: [64]u8,

    pub fn init(player_id: u32, text: []const u8) ChatMessagePacket {
        var pkt = ChatMessagePacket{
            .player_id = player_id,
            .len = @min(@as(u8, @intCast(text.len)), 63),
            .msg = [_]u8{0} ** 64,
        };
        @memcpy(pkt.msg[0..pkt.len], text[0..pkt.len]);
        return pkt;
    }

    pub fn slice(self: *const ChatMessagePacket) []const u8 {
        return self.msg[0..self.len];
    }
};

pub const Packet = union(PacketType) {
    handshake: HandshakePacket,
    handshake_ack: HandshakeAckPacket,
    player_pos: PlayerPosPacket,
    block_edit: BlockEditPacket,
    chat_message: ChatMessagePacket,
    disconnect: u32, // player_id

    pub fn serialize(self: Packet, buf: []u8) !usize {
        if (buf.len < 1) return error.BufferTooSmall;
        buf[0] = @intFromEnum(self);
        switch (self) {
            .handshake => |p| {
                const sz = @sizeOf(HandshakePacket);
                if (buf.len < 1 + sz) return error.BufferTooSmall;
                @memcpy(buf[1 .. 1 + sz], std.mem.asBytes(&p));
                return 1 + sz;
            },
            .handshake_ack => |p| {
                const sz = @sizeOf(HandshakeAckPacket);
                if (buf.len < 1 + sz) return error.BufferTooSmall;
                @memcpy(buf[1 .. 1 + sz], std.mem.asBytes(&p));
                return 1 + sz;
            },
            .player_pos => |p| {
                const sz = @sizeOf(PlayerPosPacket);
                if (buf.len < 1 + sz) return error.BufferTooSmall;
                @memcpy(buf[1 .. 1 + sz], std.mem.asBytes(&p));
                return 1 + sz;
            },
            .block_edit => |p| {
                const sz = @sizeOf(BlockEditPacket);
                if (buf.len < 1 + sz) return error.BufferTooSmall;
                @memcpy(buf[1 .. 1 + sz], std.mem.asBytes(&p));
                return 1 + sz;
            },
            .chat_message => |p| {
                const sz = @sizeOf(ChatMessagePacket);
                if (buf.len < 1 + sz) return error.BufferTooSmall;
                @memcpy(buf[1 .. 1 + sz], std.mem.asBytes(&p));
                return 1 + sz;
            },
            .disconnect => |id| {
                const sz = @sizeOf(u32);
                if (buf.len < 1 + sz) return error.BufferTooSmall;
                @memcpy(buf[1 .. 1 + sz], std.mem.asBytes(&id));
                return 1 + sz;
            },
        }
    }

    pub fn deserialize(buf: []const u8) !Packet {
        if (buf.len < 1) return error.EmptyPacket;
                const raw_tag = buf[0];
        if (raw_tag < 1 or raw_tag > 6) return error.InvalidPacketTag;
        const tag: PacketType = @enumFromInt(raw_tag);
        const payload = buf[1..];
        switch (tag) {
            .handshake => {
                if (payload.len < @sizeOf(HandshakePacket)) return error.TruncatedPacket;
                var p: HandshakePacket = undefined;
                @memcpy(std.mem.asBytes(&p), payload[0..@sizeOf(HandshakePacket)]);
                return .{ .handshake = p };
            },
            .handshake_ack => {
                if (payload.len < @sizeOf(HandshakeAckPacket)) return error.TruncatedPacket;
                var p: HandshakeAckPacket = undefined;
                @memcpy(std.mem.asBytes(&p), payload[0..@sizeOf(HandshakeAckPacket)]);
                return .{ .handshake_ack = p };
            },
            .player_pos => {
                if (payload.len < @sizeOf(PlayerPosPacket)) return error.TruncatedPacket;
                var p: PlayerPosPacket = undefined;
                @memcpy(std.mem.asBytes(&p), payload[0..@sizeOf(PlayerPosPacket)]);
                return .{ .player_pos = p };
            },
            .block_edit => {
                if (payload.len < @sizeOf(BlockEditPacket)) return error.TruncatedPacket;
                var p: BlockEditPacket = undefined;
                @memcpy(std.mem.asBytes(&p), payload[0..@sizeOf(BlockEditPacket)]);
                return .{ .block_edit = p };
            },
            .chat_message => {
                if (payload.len < @sizeOf(ChatMessagePacket)) return error.TruncatedPacket;
                var p: ChatMessagePacket = undefined;
                @memcpy(std.mem.asBytes(&p), payload[0..@sizeOf(ChatMessagePacket)]);
                return .{ .chat_message = p };
            },
            .disconnect => {
                if (payload.len < @sizeOf(u32)) return error.TruncatedPacket;
                var id: u32 = undefined;
                @memcpy(std.mem.asBytes(&id), payload[0..@sizeOf(u32)]);
                return .{ .disconnect = id };
            },
        }
    }
};

test "packet serialize and deserialize roundtrip" {
    var buf: [256]u8 = undefined;

    // Test player position
    const orig_pos = Packet{
        .player_pos = .{
            .player_id = 42,
            .x = 100.5,
            .y = 64.0,
            .z = -200.25,
            .yaw = 180.0,
            .pitch = -45.0,
        },
    };
    const sz_pos = try orig_pos.serialize(&buf);
    const deser_pos = try Packet.deserialize(buf[0..sz_pos]);
    try std.testing.expectEqual(deser_pos.player_pos.player_id, 42);
    try std.testing.expectEqual(deser_pos.player_pos.x, 100.5);
    try std.testing.expectEqual(deser_pos.player_pos.yaw, 180.0);

    // Test block edit
    const orig_block = Packet{
        .block_edit = .{
            .player_id = 7,
            .x = 10,
            .y = 15,
            .z = -5,
            .block_id = 3,
        },
    };
    const sz_block = try orig_block.serialize(&buf);
    const deser_block = try Packet.deserialize(buf[0..sz_block]);
    try std.testing.expectEqual(deser_block.block_edit.player_id, 7);
    try std.testing.expectEqual(deser_block.block_edit.x, 10);
    try std.testing.expectEqual(deser_block.block_edit.block_id, 3);

    // Test chat message
    const orig_chat = Packet{
        .chat_message = ChatMessagePacket.init(1, "Hello Zigcraft multiplayer!"),
    };
    const sz_chat = try orig_chat.serialize(&buf);
    const deser_chat = try Packet.deserialize(buf[0..sz_chat]);
    try std.testing.expectEqualStrings(deser_chat.chat_message.slice(), "Hello Zigcraft multiplayer!");
}
