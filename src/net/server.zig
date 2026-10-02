const std = @import("std");
const socket_mod = @import("socket.zig");
pub const protocol_mod = @import("protocol.zig");
const Packet = protocol_mod.Packet;
const Endpoint = socket_mod.Endpoint;
const UdpSocket = socket_mod.UdpSocket;

pub const ConnectedClient = struct {
    id: u32,
    endpoint: Endpoint,
    last_seen: f32,
    active: bool,
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    yaw: f32 = 0,
    pitch: f32 = 0,
};

pub const Server = struct {
    pub const MAX_CLIENTS = 8;
    pub const TIMEOUT_SEC = 5.0;

    socket: UdpSocket,
    clients: [MAX_CLIENTS]ConnectedClient,
    next_client_id: u32,
    current_time: f32,

    pub fn init(port: u16) !Server {
        var sock = try UdpSocket.init();
        errdefer sock.deinit();
        try sock.bind(Endpoint.any(port));

        var s = Server{
            .socket = sock,
            .clients = undefined,
            .next_client_id = 1,
            .current_time = 0,
        };
        for (&s.clients) |*c| {
            c.active = false;
        }
        return s;
    }

    pub fn deinit(self: *Server) void {
        self.socket.deinit();
    }

    pub fn tick(self: *Server, dt: f32) void {
        self.current_time += dt;

        // Check for client timeouts
        for (&self.clients) |*c| {
            if (c.active and (self.current_time - c.last_seen > TIMEOUT_SEC)) {
                c.active = false;
            }
        }

        // Process incoming UDP packets
        var buf: [512]u8 = undefined;
        var from: Endpoint = undefined;
        while (self.socket.recvFrom(&buf, &from)) |n| {
            const pkt = Packet.deserialize(buf[0..n]) catch continue;
            self.handlePacket(from, pkt);
        }
    }

    fn handlePacket(self: *Server, from: Endpoint, pkt: Packet) void {
        switch (pkt) {
            .handshake => |hs| {
                _ = hs;
                // Assign slot or re-use existing endpoint slot
                var client_idx: ?usize = null;
                for (&self.clients, 0..) |*c, idx| {
                    if (c.active and c.endpoint.equals(from)) {
                        client_idx = idx;
                        break;
                    }
                }
                if (client_idx == null) {
                    for (&self.clients, 0..) |*c, idx| {
                        if (!c.active) {
                            client_idx = idx;
                            break;
                        }
                    }
                }

                if (client_idx) |idx| {
                    const cid = self.next_client_id;
                    self.next_client_id += 1;
                    self.clients[idx] = .{
                        .id = cid,
                        .endpoint = from,
                        .last_seen = self.current_time,
                        .active = true,
                    };

                    // Send handshake ACK
                    var reply_buf: [64]u8 = undefined;
                    const ack_pkt = Packet{
                        .handshake_ack = .{
                            .server_version = protocol_mod.PROTOCOL_VERSION,
                            .assigned_player_id = cid,
                        },
                    };
                    if (ack_pkt.serialize(&reply_buf)) |sz| {
                        _ = self.socket.sendTo(from, reply_buf[0..sz]) catch {};
                    } else |_| {}
                }
            },
            .player_pos => |pos| {
                // Update client record and broadcast position to other clients
                for (&self.clients) |*c| {
                    if (c.active and c.id == pos.player_id) {
                        c.last_seen = self.current_time;
                        c.x = pos.x;
                        c.y = pos.y;
                        c.z = pos.z;
                        c.yaw = pos.yaw;
                        c.pitch = pos.pitch;
                        break;
                    }
                }
                self.broadcastExcept(pkt, pos.player_id);
            },
            .block_edit => |be| {
                // Broadcast block edit to all clients
                self.broadcastExcept(pkt, be.player_id);
            },
            .chat_message => |cm| {
                // Broadcast chat to all clients
                self.broadcastExcept(pkt, 0); // include all
                _ = cm;
            },
            .disconnect => |id| {
                for (&self.clients) |*c| {
                    if (c.active and c.id == id) {
                        c.active = false;
                        break;
                    }
                }
                self.broadcastExcept(pkt, id);
            },
            .handshake_ack => {},
        }
    }

    pub fn broadcastExcept(self: *Server, pkt: Packet, exclude_id: u32) void {
        var buf: [512]u8 = undefined;
        const sz = pkt.serialize(&buf) catch return;
        for (&self.clients) |*c| {
            if (c.active and c.id != exclude_id) {
                _ = self.socket.sendTo(c.endpoint, buf[0..sz]) catch {};
            }
        }
    }

    pub fn activeClientCount(self: *Server) usize {
        var count: usize = 0;
        for (&self.clients) |*c| {
            if (c.active) count += 1;
        }
        return count;
    }
};

test "server handles handshake and tracks client" {
    var server = try Server.init(26002);
    defer server.deinit();

    var client_sock = try UdpSocket.init();
    defer client_sock.deinit();
    const server_ep = try Endpoint.init("127.0.0.1", 26002);

    // Send handshake
    var buf: [64]u8 = undefined;
    const hs = Packet{ .handshake = .{ .version = protocol_mod.PROTOCOL_VERSION, .client_id = 999 } };
    const sz = try hs.serialize(&buf);
    _ = try client_sock.sendTo(server_ep, buf[0..sz]);

    // Tick server
    server.tick(0.016);

    try std.testing.expectEqual(server.activeClientCount(), 1);

    // Client receive ACK
    var recv_buf: [64]u8 = undefined;
    var from: Endpoint = undefined;
    const n = client_sock.recvFrom(&recv_buf, &from);
    try std.testing.expect(n != null);
    const reply = try Packet.deserialize(recv_buf[0..n.?]);
    try std.testing.expectEqual(reply.handshake_ack.server_version, protocol_mod.PROTOCOL_VERSION);
}
