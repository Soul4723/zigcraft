const std = @import("std");
const socket_mod = @import("socket.zig");
const proto = @import("protocol.zig");

pub const MAX_REMOTE_PLAYERS: usize = 16;

pub const RemotePlayer = struct {
    id: u32,
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    yaw: f32 = 0,
    pitch: f32 = 0,
    anim_time: f32 = 0,
    active: bool = false,
};

pub const IncomingBlockEdit = struct {
    player_id: u32,
    x: i32,
    y: i32,
    z: i32,
    block_id: u8,
};

pub const Client = struct {
    sock: socket_mod.Socket,
    player_id: ?u32 = null,
    remote_players: [MAX_REMOTE_PLAYERS]RemotePlayer,
    recv_buf: [2048]u8 = undefined,
    recv_len: usize = 0,
    send_buf: [256]u8 = undefined,
    pending_edits: std.ArrayList(IncomingBlockEdit),
    allocator: std.mem.Allocator,
    connected: bool = false,

    pub fn init(allocator: std.mem.Allocator) Client {
        var remotes: [MAX_REMOTE_PLAYERS]RemotePlayer = undefined;
        for (&remotes) |*r| {
            r.id = 0;
            r.active = false;
        }

        return .{
            .sock = socket_mod.Socket.invalid(),
            .player_id = null,
            .remote_players = remotes,
            .recv_len = 0,
            .pending_edits = std.ArrayList(IncomingBlockEdit).empty,
            .allocator = allocator,
            .connected = false,
        };
    }

    pub fn deinit(self: *Client) void {
        self.disconnect();
        self.pending_edits.deinit(self.allocator);
    }

    pub fn connect(self: *Client, host: [:0]const u8, port: u16) !void {
        self.sock = try socket_mod.Socket.connect(host, port);
        self.connected = true;
        self.recv_len = 0;

        // Send JoinPacket
        const join_pkt = proto.Packet{
            .join = .{
                .name_len = 6,
                .name = [_]u8{ 'P', 'l', 'a', 'y', 'e', 'r', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            },
        };
        const len = try proto.encode(join_pkt, &self.send_buf);
        _ = try self.sock.send(self.send_buf[0..len]);
    }

    pub fn disconnect(self: *Client) void {
        if (self.connected) {
            self.sock.close();
            self.connected = false;
        }
        for (&self.remote_players) |*r| {
            r.active = false;
        }
    }

    pub fn sendPosition(self: *Client, x: f32, y: f32, z: f32, yaw: f32, pitch: f32) !void {
        if (!self.connected) return;
        const pkt = proto.Packet{
            .position = .{
                .x = x,
                .y = y,
                .z = z,
                .yaw = yaw,
                .pitch = pitch,
            },
        };
        const len = try proto.encode(pkt, &self.send_buf);
        _ = try self.sock.send(self.send_buf[0..len]);
    }

    pub fn sendBlockEdit(self: *Client, x: i32, y: i32, z: i32, block_id: u8) !void {
        if (!self.connected) return;
        const pkt = proto.Packet{
            .block_edit = .{
                .x = x,
                .y = y,
                .z = z,
                .block_id = block_id,
            },
        };
        const len = try proto.encode(pkt, &self.send_buf);
        _ = try self.sock.send(self.send_buf[0..len]);
    }

    pub fn tick(self: *Client, dt: f32) void {
        if (!self.connected) return;

        // Advance remote player leg walk animations
        for (&self.remote_players) |*r| {
            if (r.active) {
                r.anim_time += dt * 8.0;
            }
        }

        // Recv incoming data
        if (self.recv_len < self.recv_buf.len) {
            const recvd = self.sock.recv(self.recv_buf[self.recv_len..]) catch {
                self.disconnect();
                return;
            };
            self.recv_len += recvd;
        }

        // Decode packets
        while (self.recv_len >= proto.HEADER_SIZE) {
            const decode_res = proto.decode(self.recv_buf[0..self.recv_len]) catch {
                self.disconnect();
                return;
            };

            if (decode_res) |res| {
                self.handlePacket(res.packet);

                const consumed = res.bytes_consumed;
                const remaining = self.recv_len - consumed;
                if (remaining > 0) {
                    std.mem.copyForwards(u8, self.recv_buf[0..remaining], self.recv_buf[consumed..self.recv_len]);
                }
                self.recv_len = remaining;
            } else {
                break;
            }
        }
    }

    fn handlePacket(self: *Client, packet: proto.Packet) void {
        switch (packet) {
            .welcome => |p| {
                self.player_id = p.player_id;
            },
            .player_position => |p| {
                var player = self.findRemote(p.player_id);
                if (player == null) {
                    player = self.allocateRemote(p.player_id);
                }
                if (player) |r| {
                    r.x = p.x;
                    r.y = p.y;
                    r.z = p.z;
                    r.yaw = p.yaw;
                    r.pitch = p.pitch;
                }
            },
            .player_block_edit => |p| {
                self.pending_edits.append(self.allocator, .{
                    .player_id = p.player_id,
                    .x = p.x,
                    .y = p.y,
                    .z = p.z,
                    .block_id = p.block_id,
                }) catch {};
            },
            .player_leave => |p| {
                if (self.findRemote(p.player_id)) |r| {
                    r.active = false;
                }
            },
            else => {},
        }
    }

    fn findRemote(self: *Client, id: u32) ?*RemotePlayer {
        for (&self.remote_players) |*r| {
            if (r.active and r.id == id) return r;
        }
        return null;
    }

    fn allocateRemote(self: *Client, id: u32) ?*RemotePlayer {
        for (&self.remote_players) |*r| {
            if (!r.active) {
                r.id = id;
                r.active = true;
                r.anim_time = 0;
                return r;
            }
        }
        return null;
    }

    pub fn activeRemoteCount(self: *const Client) usize {
        var count: usize = 0;
        for (&self.remote_players) |*r| {
            if (r.active) count += 1;
        }
        return count;
    }
};

test "client init and remote tracking" {
    var client = Client.init(std.testing.allocator);
    defer client.deinit();

    try std.testing.expectEqual(@as(usize, 0), client.activeRemoteCount());
    try std.testing.expect(!client.connected);
}

test "end-to-end client server position and block edit synchronization" {
    const server_mod = @import("server.zig");
    const posix_c = @cImport({
        @cInclude("unistd.h");
    });

    const port = 39126;
    var server = try server_mod.Server.init(port);
    defer server.deinit();

    var client1 = Client.init(std.testing.allocator);
    defer client1.deinit();
    try client1.connect("127.0.0.1", port);

    var client2 = Client.init(std.testing.allocator);
    defer client2.deinit();
    try client2.connect("127.0.0.1", port);

    // Tick server to accept and welcome both clients
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        _ = posix_c.usleep(1000);
        server.tick();
        client1.tick(0.016);
        client2.tick(0.016);
    }

    try std.testing.expect(client1.connected);
    try std.testing.expect(client2.connected);
    try std.testing.expectEqual(@as(usize, 2), server.activeClientCount());

    // Client 1 sends position update
    try client1.sendPosition(50.0, 64.0, 75.0, 1.2, -0.4);

    // Tick server and client 2
    i = 0;
    while (i < 5) : (i += 1) {
        _ = posix_c.usleep(1000);
        server.tick();
        client2.tick(0.016);
    }

    // Client 2 should now have remote player for Client 1
    try std.testing.expectEqual(@as(usize, 1), client2.activeRemoteCount());
    const r1 = &client2.remote_players[0];
    try std.testing.expect(r1.active);
    try std.testing.expectApproxEqAbs(r1.x, 50.0, 0.001);
    try std.testing.expectApproxEqAbs(r1.y, 64.0, 0.001);
    try std.testing.expectApproxEqAbs(r1.z, 75.0, 0.001);

    // Client 1 sends block edit
    try client1.sendBlockEdit(10, 20, 30, 2); // Dirt

    i = 0;
    while (i < 5) : (i += 1) {
        _ = posix_c.usleep(1000);
        server.tick();
        client2.tick(0.016);
    }

    // Client 2 should have received pending block edit
    try std.testing.expectEqual(@as(usize, 1), client2.pending_edits.items.len);
    const edit = client2.pending_edits.items[0];
    try std.testing.expectEqual(@as(i32, 10), edit.x);
    try std.testing.expectEqual(@as(i32, 20), edit.y);
    try std.testing.expectEqual(@as(i32, 30), edit.z);
    try std.testing.expectEqual(@as(u8, 2), edit.block_id);
}
