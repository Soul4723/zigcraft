# Decision 006: Non-Blocking UDP Binary Protocol for Multiplayer

## Status
Accepted (2026-10-03, Session 023)

## Context
Milestone 30 calls for multiplayer networking. Voxel games require frequent positional sync (15-20Hz) and real-time block edit replication without blocking the rendering or physics thread.

## Options Considered

1. **TCP / Stream Sockets**
   - Head-of-line blocking can cause gameplay stuttering during transient packet drops.
   - Unnecessary overhead for ephemeral position updates.

2. **Non-Blocking UDP Binary Protocol with Embedded Host Architecture**
   - High-throughput, low-latency UDP datagrams.
   - Position updates are sent loss-tolerant (latest packet supersedes older ones).
   - Block edits are sent as discrete action packets replicated to peers.
   - Dual-mode architecture: Singleplayer runs an embedded local host server (`127.0.0.1:25565`) while multiplayer connects to an external IP via `--connect <ip>`.

## Decision
Implement Option 2:
- `src/net/protocol.zig`: Minimal packed binary structs for handshakes, transforms, block edits, chat, and disconnects.
- `src/net/socket.zig`: POSIX non-blocking UDP socket abstraction.
- `src/net/server.zig`: Lightweight server maintaining client registry and packet broadcast.
- `src/net/client.zig`: Client network polling loop and remote entity tracker.
- `src/player_renderer.zig`: Segmented 3D voxel avatar renderer for remote players.
