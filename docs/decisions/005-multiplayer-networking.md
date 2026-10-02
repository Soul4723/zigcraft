# Decision 005: Non-blocking TCP Transport and Protocol for Multiplayer

## Status
Accepted (2026-10-02, Session 022)

## Context
Milestone 30 calls for multiplayer networking: synchronized player positions and orientations, real-time block destruction and placement updates, and remote player rendering.

In Zig 0.16.0, `std.net` was refactored into `std.Io.net` and requires the new `std.Io` event loop architecture. Because the project links libc and GLFW on POSIX/Linux, POSIX socket syscalls (`socket`, `bind`, `listen`, `accept`, `connect`, `send`, `recv`, `fcntl`, `setsockopt`) provide zero-allocation, direct, non-blocking network I/O with complete control over buffer sliding and packet framing.

## Options Considered

1. **UDP / ENet / Custom unreliable packet layer**
   - Lower latency for high-frequency position packets.
   - High complexity: requires implementing packet acknowledgment, sequence numbering, retransmission of critical block edits, and connection handshake.

2. **Non-blocking TCP socket stream with binary packet protocol**
   - Guaranteed, ordered delivery of block edit events and join/leave notifications.
   - Low complexity: non-blocking sockets integrated into the client render tick and server polling loop with `TCP_NODELAY`.
   - Native support for both dedicated headless servers and graphical clients with remote player rendering.

## Decision
Implement a non-blocking TCP binary packet protocol:
- `src/net/protocol.zig`: Binary message framing (`MAGIC: 0x5A43`, type tag, 16-bit length, payload) for `join`, `welcome`, `position`, `player_position`, `block_edit`, `player_block_edit`, and `player_leave`.
- `src/net/socket.zig`: Clean POSIX socket wrapper supporting non-blocking listen, connect, accept, send, and recv.
- `src/net/server.zig`: Multi-client server tracking up to 16 players, broadcasting positions and block modifications.
- `src/net/client.zig`: Non-blocking game loop client with incoming packet parsing and pending block edit queue.
- `src/net/player_renderer.zig`: 3D voxel remote player humanoid geometry (head, torso, animated walking legs).
- `src/main.zig`: CLI support for `--server --port <port>` dedicated mode and `--connect <ip> --port <port>` multiplayer client mode.
