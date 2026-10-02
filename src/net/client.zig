const std = @import("std");
const socket_mod = @import("socket.zig");
const protocol_mod = @import("protocol.zig");
const Packet = protocol_mod.Packet;
const Endpoint = socket_mod.Endpoint;
const UdpSocket = socket_mod.UdpSocket;

pub const RemotePlayer = struct {
    id: u32,
    x: f32,
    y: f32,
    z: f32,
    yaw: f32,
    pitch: f32,
    last_update: f32,
    active: bool,
};

pub const RemoteBlockEdit = struct {
    x: i32,
    y: i32,
    z: i32,
    block_id: u8,
};

pub const Client = struct {
    pub const MAX_REMOTE_PLAYERS = 8;

    allocator: std.mem.Allocator,
    socket: UdpSocket,
    server_ep: Endpoint,
    player_id: ?u32,
    connected: bool,
    remote_players: [MAX_REMOTE_PLAYERS]RemotePlayer,
    pending_edits: std.ArrayList(RemoteBlockEdit),
    send_timer: f32,

    pub fn init(allocator: std.mem.Allocator, server_ip: []const u8, port: u16) !Client {
        var sock = try UdpSocket.init();
        errdefer sock.deinit();

        const ep = try Endpoint.init(server_ip, port);
        var c = Client{
            .allocator = allocator,
            .socket = sock,
            .server_ep = ep,
            .player_id = null,
            .connected = false,
            .remote_players = undefined,
            .pending_edits = std.ArrayList(RemoteBlockEdit).empty,
            .send_timer = 0.0,
        };
        c.pending_edits = try std.ArrayList(RemoteBlockEdit).initCapacity(allocator, 16);
        for (&c.remote_players) |*p| {
            p.active = false;
        }

        // Send handshake packet
        var buf: [64]u8 = undefined;
        const hs = Packet{
            .handshake = .{
                .version = protocol_mod.PROTOCOL_VERSION,
                .client_id = 1234,
            },
        };
        const sz = try hs.serialize(&buf);
        _ = try c.socket.sendTo(c.server_ep, buf[0..sz]);

        return c;
    }

    pub fn deinit(self: *Client) void {
        if (self.connected and self.player_id != null) {
            var buf: [64]u8 = undefined;
            const dc = Packet{ .disconnect = self.player_id.? };
            if (dc.serialize(&buf)) |sz| {
                _ = self.socket.sendTo(self.server_ep, buf[0..sz]) catch {};
            } else |_| {}
        }
        self.pending_edits.deinit(self.allocator);
        self.socket.deinit();
    }

    pub fn pollIncoming(self: *Client, current_time: f32) void {
        var buf: [512]u8 = undefined;
        var from: Endpoint = undefined;
        while (self.socket.recvFrom(&buf, &from)) |n| {
            const pkt = Packet.deserialize(buf[0..n]) catch continue;
            switch (pkt) {
                .handshake_ack => |ack| {
                    self.player_id = ack.assigned_player_id;
                    self.connected = true;
                },
                .player_pos => |pos| {
                    // Update remote player tracker
                    var found = false;
                    for (&self.remote_players) |*rp| {
                        if (rp.active and rp.id == pos.player_id) {
                            rp.x = pos.x;
                            rp.y = pos.y;
                            rp.z = pos.z;
                            rp.yaw = pos.yaw;
                            rp.pitch = pos.pitch;
                            rp.last_update = current_time;
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        for (&self.remote_players) |*rp| {
                            if (!rp.active) {
                                rp.id = pos.player_id;
                                rp.x = pos.x;
                                rp.y = pos.y;
                                rp.z = pos.z;
                                rp.yaw = pos.yaw;
                                rp.pitch = pos.pitch;
                                rp.last_update = current_time;
                                rp.active = true;
                                break;
                            }
                        }
                    }
                },
                .block_edit => |be| {
                    self.pending_edits.append(self.allocator, .{
                        .x = be.x,
                        .y = be.y,
                        .z = be.z,
                        .block_id = be.block_id,
                    }) catch {};
                },
                .disconnect => |id| {
                    for (&self.remote_players) |*rp| {
                        if (rp.active and rp.id == id) {
                            rp.active = false;
                            break;
                        }
                    }
                },
                else => {},
            }
        }

        // Timeout stale remote players (> 4.0s)
        for (&self.remote_players) |*rp| {
            if (rp.active and (current_time - rp.last_update > 4.0)) {
                rp.active = false;
            }
        }
    }

    pub fn sendPosition(self: *Client, x: f32, y: f32, z: f32, yaw: f32, pitch: f32) void {
        const pid = self.player_id orelse return;
        var buf: [64]u8 = undefined;
        const pkt = Packet{
            .player_pos = .{
                .player_id = pid,
                .x = x,
                .y = y,
                .z = z,
                .yaw = yaw,
                .pitch = pitch,
            },
        };
        if (pkt.serialize(&buf)) |sz| {
            _ = self.socket.sendTo(self.server_ep, buf[0..sz]) catch {};
        } else |_| {}
    }

    pub fn sendBlockEdit(self: *Client, x: i32, y: i32, z: i32, block_id: u8) void {
        const pid = self.player_id orelse return;
        var buf: [64]u8 = undefined;
        const pkt = Packet{
            .block_edit = .{
                .player_id = pid,
                .x = x,
                .y = y,
                .z = z,
                .block_id = block_id,
            },
        };
        if (pkt.serialize(&buf)) |sz| {
            _ = self.socket.sendTo(self.server_ep, buf[0..sz]) catch {};
        } else |_| {}
    }
};

test "client connects to server and transmits position" {
    var server = try @import("server.zig").Server.init(26003);
    defer server.deinit();

    var client = try Client.init(std.testing.allocator, "127.0.0.1", 26003);
    defer client.deinit();

    server.tick(0.016);
    client.pollIncoming(0.016);

    try std.testing.expect(client.connected);
    try std.testing.expect(client.player_id != null);

    // Send position from client
    client.sendPosition(10.0, 20.0, 30.0, 90.0, 0.0);
    server.tick(0.016);

    // Verify server has client updated
    try std.testing.expectEqual(server.clients[0].x, 10.0);
    try std.testing.expectEqual(server.clients[0].y, 20.0);
}
