const std = @import("std");
const socket_mod = @import("socket.zig");
const proto = @import("protocol.zig");

pub const MAX_CLIENTS: usize = 16;

pub const ConnectedClient = struct {
    id: u32,
    sock: socket_mod.Socket,
    recv_buf: [1024]u8 = undefined,
    recv_len: usize = 0,
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    yaw: f32 = 0,
    pitch: f32 = 0,
    active: bool = false,
};

pub const Server = struct {
    listen_sock: socket_mod.Socket,
    clients: [MAX_CLIENTS]ConnectedClient,
    next_client_id: u32 = 1,
    port: u16,

    pub fn init(port: u16) !Server {
        const listen_sock = try socket_mod.Socket.listen(port, 8);
        var clients: [MAX_CLIENTS]ConnectedClient = undefined;
        for (&clients) |*c| {
            c.id = 0;
            c.sock = socket_mod.Socket.invalid();
            c.recv_len = 0;
            c.active = false;
        }

        return .{
            .listen_sock = listen_sock,
            .clients = clients,
            .next_client_id = 1,
            .port = port,
        };
    }

    pub fn deinit(self: *Server) void {
        for (&self.clients) |*c| {
            if (c.active) {
                c.sock.close();
                c.active = false;
            }
        }
        self.listen_sock.close();
    }

    /// Accept any pending connections up to MAX_CLIENTS
    pub fn pollNewConnections(self: *Server) void {
        while (self.listen_sock.accept()) |new_sock| {
            var slot: ?*ConnectedClient = null;
            for (&self.clients) |*c| {
                if (!c.active) {
                    slot = c;
                    break;
                }
            }

            if (slot) |c| {
                const id = self.next_client_id;
                self.next_client_id += 1;
                c.id = id;
                c.sock = new_sock;
                c.recv_len = 0;
                c.x = 24.0;
                c.y = 20.0;
                c.z = 24.0;
                c.yaw = 0.0;
                c.pitch = 0.0;
                c.active = true;

                // Send WelcomePacket with assigned ID and spawn pos
                var buf: [64]u8 = undefined;
                const welcome = proto.Packet{
                    .welcome = .{
                        .player_id = id,
                        .spawn_x = c.x,
                        .spawn_y = c.y,
                        .spawn_z = c.z,
                    },
                };
                if (proto.encode(welcome, &buf)) |len| {
                    _ = c.sock.send(buf[0..len]) catch {};
                } else |_| {}

                // Send existing active players to newly joined client
                for (&self.clients) |*other| {
                    if (other.active and other.id != id) {
                        const other_pos = proto.Packet{
                            .player_position = .{
                                .player_id = other.id,
                                .x = other.x,
                                .y = other.y,
                                .z = other.z,
                                .yaw = other.yaw,
                                .pitch = other.pitch,
                            },
                        };
                        if (proto.encode(other_pos, &buf)) |pos_len| {
                            _ = c.sock.send(buf[0..pos_len]) catch {};
                        } else |_| {}
                    }
                }
            } else {
                var reject_sock = new_sock;
                reject_sock.close();
            }
        }
    }

    /// Read packets from each client and process them
    pub fn tick(self: *Server) void {
        self.pollNewConnections();

        for (&self.clients) |*c| {
            if (!c.active) continue;

            // Recv into client buffer
            if (c.recv_len < c.recv_buf.len) {
                const recvd = c.sock.recv(c.recv_buf[c.recv_len..]) catch {
                    self.disconnectClient(c);
                    continue;
                };

                c.recv_len += recvd;
            }

            // Parse packets from buffer
            while (c.recv_len >= proto.HEADER_SIZE) {
                const decode_res = proto.decode(c.recv_buf[0..c.recv_len]) catch {
                    // Corrupted stream: disconnect client
                    self.disconnectClient(c);
                    break;
                };

                if (decode_res) |res| {
                    self.handleClientPacket(c, res.packet);

                    // Slide unread bytes down
                    const consumed = res.bytes_consumed;
                    const remaining = c.recv_len - consumed;
                    if (remaining > 0) {
                        std.mem.copyForwards(u8, c.recv_buf[0..remaining], c.recv_buf[consumed..c.recv_len]);
                    }
                    c.recv_len = remaining;
                } else {
                    // Incomplete packet in buffer; await more data
                    break;
                }
            }
        }
    }

    fn handleClientPacket(self: *Server, sender: *ConnectedClient, packet: proto.Packet) void {
        switch (packet) {
            .position => |p| {
                sender.x = p.x;
                sender.y = p.y;
                sender.z = p.z;
                sender.yaw = p.yaw;
                sender.pitch = p.pitch;

                // Relay player_position packet to all OTHER clients
                var buf: [64]u8 = undefined;
                const relay = proto.Packet{
                    .player_position = .{
                        .player_id = sender.id,
                        .x = p.x,
                        .y = p.y,
                        .z = p.z,
                        .yaw = p.yaw,
                        .pitch = p.pitch,
                    },
                };
                if (proto.encode(relay, &buf)) |len| {
                    self.broadcastExcept(sender.id, buf[0..len]);
                } else |_| {}
            },
            .block_edit => |p| {
                // Relay player_block_edit to all other clients
                var buf: [64]u8 = undefined;
                const relay = proto.Packet{
                    .player_block_edit = .{
                        .player_id = sender.id,
                        .x = p.x,
                        .y = p.y,
                        .z = p.z,
                        .block_id = p.block_id,
                    },
                };
                if (proto.encode(relay, &buf)) |len| {
                    self.broadcastExcept(sender.id, buf[0..len]);
                } else |_| {}
            },
            .chat => |p| {
                var buf: [128]u8 = undefined;
                const relay = proto.Packet{
                    .player_chat = .{
                        .player_id = sender.id,
                        .msg_len = p.msg_len,
                        .msg = p.msg,
                    },
                };
                if (proto.encode(relay, &buf)) |len| {
                    self.broadcastAll(buf[0..len]);
                } else |_| {}
            },
            else => {},
        }
    }

    pub fn broadcastExcept(self: *Server, except_id: u32, data: []const u8) void {
        for (&self.clients) |*c| {
            if (c.active and c.id != except_id) {
                _ = c.sock.send(data) catch {};
            }
        }
    }

    pub fn broadcastAll(self: *Server, data: []const u8) void {
        for (&self.clients) |*c| {
            if (c.active) {
                _ = c.sock.send(data) catch {};
            }
        }
    }

    pub fn disconnectClient(self: *Server, c: *ConnectedClient) void {
        if (!c.active) return;
        const id = c.id;
        c.sock.close();
        c.active = false;
        c.recv_len = 0;

        // Broadcast player_leave
        var buf: [32]u8 = undefined;
        const leave = proto.Packet{
            .player_leave = .{ .player_id = id },
        };
        if (proto.encode(leave, &buf)) |len| {
            self.broadcastAll(buf[0..len]);
        } else |_| {}
    }

    pub fn activeClientCount(self: *const Server) usize {
        var count: usize = 0;
        for (&self.clients) |*c| {
            if (c.active) count += 1;
        }
        return count;
    }
};

test "server init and tick lifecycle" {
    var server = try Server.init(39125);
    defer server.deinit();

    try std.testing.expectEqual(@as(usize, 0), server.activeClientCount());

    server.tick();
    try std.testing.expectEqual(@as(usize, 0), server.activeClientCount());
}
