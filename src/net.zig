const std = @import("std");

pub const protocol = @import("net/protocol.zig");
pub const socket = @import("net/socket.zig");
pub const server = @import("net/server.zig");
pub const client = @import("net/client.zig");

test {
    std.testing.refAllDecls(protocol);
    std.testing.refAllDecls(socket);
    std.testing.refAllDecls(server);
    std.testing.refAllDecls(client);
}
pub const player_renderer = @import("net/player_renderer.zig");

test {
    std.testing.refAllDecls(player_renderer);
}
