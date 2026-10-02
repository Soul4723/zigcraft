const std = @import("std");

const c = @cImport({
    @cInclude("sys/types.h");
    @cInclude("sys/socket.h");
    @cInclude("netinet/in.h");
    @cInclude("arpa/inet.h");
    @cInclude("fcntl.h");
    @cInclude("unistd.h");
    @cInclude("errno.h");
});

pub const Endpoint = struct {
    addr: c.sockaddr_in,

    pub fn init(ip_str: []const u8, port: u16) !Endpoint {
        var addr: c.sockaddr_in = std.mem.zeroes(c.sockaddr_in);
        addr.sin_family = c.AF_INET;
        addr.sin_port = c.htons(port);

        var null_term_buf: [32]u8 = undefined;
        if (ip_str.len >= null_term_buf.len) return error.IpTooLong;
        @memcpy(null_term_buf[0..ip_str.len], ip_str);
        null_term_buf[ip_str.len] = 0;

        const res = c.inet_pton(c.AF_INET, null_term_buf[0..ip_str.len :0], &addr.sin_addr);
        if (res <= 0) return error.InvalidIpAddress;

        return Endpoint{ .addr = addr };
    }

    pub fn any(port: u16) Endpoint {
        var addr: c.sockaddr_in = std.mem.zeroes(c.sockaddr_in);
        addr.sin_family = c.AF_INET;
        addr.sin_port = c.htons(port);
        addr.sin_addr.s_addr = c.INADDR_ANY;
        return Endpoint{ .addr = addr };
    }

    pub fn equals(self: Endpoint, other: Endpoint) bool {
        return self.addr.sin_port == other.addr.sin_port and
            self.addr.sin_addr.s_addr == other.addr.sin_addr.s_addr;
    }
};

pub const UdpSocket = struct {
    fd: c_int,

    pub fn init() !UdpSocket {
        const fd = c.socket(c.AF_INET, c.SOCK_DGRAM, 0);
        if (fd < 0) return error.SocketCreationFailed;

        // Set non-blocking mode
        const zero: c_int = 0;
        const flags = c.fcntl(fd, c.F_GETFL, zero);
        if (flags < 0 or c.fcntl(fd, c.F_SETFL, flags | c.O_NONBLOCK) < 0) {
            _ = c.close(fd);
            return error.SetNonBlockingFailed;
        }

        // Enable SO_REUSEADDR
        var opt: c_int = 1;
        _ = c.setsockopt(fd, c.SOL_SOCKET, c.SO_REUSEADDR, &opt, @sizeOf(c_int));

        return UdpSocket{ .fd = fd };
    }

    pub fn bind(self: *UdpSocket, endpoint: Endpoint) !void {
        if (c.bind(self.fd, @ptrCast(&endpoint.addr), @sizeOf(c.sockaddr_in)) != 0) {
            return error.BindFailed;
        }
    }

    pub fn sendTo(self: *UdpSocket, endpoint: Endpoint, data: []const u8) !usize {
        const sent = c.sendto(
            self.fd,
            data.ptr,
            data.len,
            0,
            @ptrCast(&endpoint.addr),
            @sizeOf(c.sockaddr_in),
        );
        if (sent < 0) {
            return error.SendFailed;
        }
        return @intCast(sent);
    }

    pub fn recvFrom(self: *UdpSocket, buf: []u8, from: *Endpoint) ?usize {
        var addr: c.sockaddr_in = undefined;
        var addr_len: c.socklen_t = @sizeOf(c.sockaddr_in);

        const recvd = c.recvfrom(
            self.fd,
            buf.ptr,
            buf.len,
            0,
            @ptrCast(&addr),
            &addr_len,
        );

        if (recvd < 0) {
            // Non-blocking read returned EAGAIN / EWOULDBLOCK
            return null;
        }

        from.* = Endpoint{ .addr = addr };
        return @intCast(recvd);
    }

    pub fn deinit(self: *UdpSocket) void {
        if (self.fd >= 0) {
            _ = c.close(self.fd);
            self.fd = -1;
        }
    }
};

test "udp socket nonblocking local transmission" {
    var server = try UdpSocket.init();
    defer server.deinit();
    const s_ep = try Endpoint.init("127.0.0.1", 26001);
    try server.bind(s_ep);

    var client = try UdpSocket.init();
    defer client.deinit();

    const test_msg = "VOXEL_PACKET_SYNC";
    _ = try client.sendTo(s_ep, test_msg);

    var recv_buf: [128]u8 = undefined;
    var from_ep: Endpoint = undefined;
    const n = server.recvFrom(&recv_buf, &from_ep);
    try std.testing.expect(n != null);
    try std.testing.expectEqualStrings(test_msg, recv_buf[0..n.?]);
}
