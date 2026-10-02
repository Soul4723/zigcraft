const std = @import("std");
const posix_c = @cImport({
    @cInclude("sys/types.h");
    @cInclude("sys/socket.h");
    @cInclude("netinet/in.h");
    @cInclude("netinet/tcp.h");
    @cInclude("arpa/inet.h");
    @cInclude("unistd.h");
    @cInclude("fcntl.h");
    @cInclude("errno.h");
    @cInclude("poll.h");
});

pub const Socket = struct {
    fd: c_int,

    pub fn invalid() Socket {
        return .{ .fd = -1 };
    }

    pub fn isValid(self: Socket) bool {
        return self.fd >= 0;
    }

    pub fn close(self: *Socket) void {
        if (self.fd >= 0) {
            _ = posix_c.close(self.fd);
            self.fd = -1;
        }
    }

    pub fn setNonBlocking(self: Socket) !void {
        const flags = posix_c.fcntl(self.fd, posix_c.F_GETFL, @as(c_int, 0));
        if (flags < 0) return error.FcntlFailed;
        if (posix_c.fcntl(self.fd, posix_c.F_SETFL, flags | posix_c.O_NONBLOCK) < 0) {
            return error.FcntlFailed;
        }
    }

    pub fn setNoDelay(self: Socket) !void {
        var opt: c_int = 1;
        if (posix_c.setsockopt(self.fd, posix_c.IPPROTO_TCP, posix_c.TCP_NODELAY, &opt, @sizeOf(c_int)) < 0) {
            return error.SetSockOptFailed;
        }
    }

    pub fn setReuseAddr(self: Socket) !void {
        var opt: c_int = 1;
        if (posix_c.setsockopt(self.fd, posix_c.SOL_SOCKET, posix_c.SO_REUSEADDR, &opt, @sizeOf(c_int)) < 0) {
            return error.SetSockOptFailed;
        }
    }

    pub fn listen(port: u16, backlog: c_int) !Socket {
        const fd = posix_c.socket(posix_c.AF_INET, posix_c.SOCK_STREAM, 0);
        if (fd < 0) return error.SocketCreationFailed;

        const sock = Socket{ .fd = fd };
        try sock.setReuseAddr();

        var addr: posix_c.sockaddr_in = undefined;
        @memset(std.mem.asBytes(&addr), 0);
        addr.sin_family = @intCast(posix_c.AF_INET);
        addr.sin_port = posix_c.htons(port);
        addr.sin_addr.s_addr = posix_c.htonl(posix_c.INADDR_ANY);

        if (posix_c.bind(fd, @ptrCast(&addr), @sizeOf(posix_c.sockaddr_in)) < 0) {
            _ = posix_c.close(fd);
            return error.BindFailed;
        }

        if (posix_c.listen(fd, backlog) < 0) {
            _ = posix_c.close(fd);
            return error.ListenFailed;
        }

        try sock.setNonBlocking();
        return sock;
    }

    pub fn connect(host_ip: [:0]const u8, port: u16) !Socket {
        const fd = posix_c.socket(posix_c.AF_INET, posix_c.SOCK_STREAM, 0);
        if (fd < 0) return error.SocketCreationFailed;

        var addr: posix_c.sockaddr_in = undefined;
        @memset(std.mem.asBytes(&addr), 0);
        addr.sin_family = @intCast(posix_c.AF_INET);
        addr.sin_port = posix_c.htons(port);

        if (posix_c.inet_pton(posix_c.AF_INET, host_ip.ptr, &addr.sin_addr) <= 0) {
            _ = posix_c.close(fd);
            return error.InvalidAddress;
        }

        if (posix_c.connect(fd, @ptrCast(&addr), @sizeOf(posix_c.sockaddr_in)) < 0) {
            _ = posix_c.close(fd);
            return error.ConnectFailed;
        }

        const sock = Socket{ .fd = fd };
        try sock.setNoDelay();
        try sock.setNonBlocking();
        return sock;
    }

    pub fn accept(self: Socket) ?Socket {
        var client_addr: posix_c.sockaddr_in = undefined;
        var addr_len: posix_c.socklen_t = @sizeOf(posix_c.sockaddr_in);

        const client_fd = posix_c.accept(self.fd, @ptrCast(&client_addr), &addr_len);
        if (client_fd < 0) return null;

        const sock = Socket{ .fd = client_fd };
        sock.setNoDelay() catch {};
        sock.setNonBlocking() catch {};
        return sock;
    }

    pub fn send(self: Socket, data: []const u8) !usize {
        const sent = posix_c.send(self.fd, data.ptr, data.len, 0);
        if (sent < 0) {
            const errno = std.c._errno().*;
            if (errno == posix_c.EAGAIN or errno == posix_c.EWOULDBLOCK) {
                return 0;
            }
            return error.SendFailed;
        }
        return @intCast(sent);
    }

    pub fn recv(self: Socket, buf: []u8) !usize {
        const recvd = posix_c.recv(self.fd, buf.ptr, buf.len, 0);
        if (recvd < 0) {
            const errno = std.c._errno().*;
            if (errno == posix_c.EAGAIN or errno == posix_c.EWOULDBLOCK) {
                return 0;
            }
            return error.RecvFailed;
        }
        return @intCast(recvd);
    }
};

test "Socket listen, accept and nonblocking transfer" {
    var server = try Socket.listen(39124, 4);
    defer server.close();

    var client = try Socket.connect("127.0.0.1", 39124);
    defer client.close();

    var peer = server.accept();
    try std.testing.expect(peer != null);
    defer peer.?.close();

    const msg = "network_packet_test";
    const sent = try client.send(msg);
    try std.testing.expectEqual(msg.len, sent);

    var buf: [64]u8 = undefined;
    var recvd: usize = 0;
    var tries: usize = 0;
    while (recvd == 0 and tries < 50) : (tries += 1) {
        recvd = try peer.?.recv(&buf);
        if (recvd == 0) _ = posix_c.usleep(1000); // 1ms
    }

    try std.testing.expectEqual(msg.len, recvd);
    try std.testing.expectEqualStrings(msg, buf[0..recvd]);
}
