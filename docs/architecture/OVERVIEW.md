# Architecture Overview

Last updated: 2026-10-01 (Session 001)

## Project Structure

```
zigcraft/
├── AGENTS.md                    # AI developer instructions
├── CONTRIBUTING.md              # AI workflow guide, guard rails, patterns
├── build.zig                    # Zig build configuration
├── build.zig.zon                # Package manifest
├── README.md
├── src/
│   ├── main.zig                 # Entry point, game loop, window setup
│   └── world/
│       ├── block.zig            # BlockId enum, block properties
│       ├── chunk.zig            # 16×16×16 chunk data structure
│       └── chunk_mesh.zig       # Mesh generation from chunk data
├── docs/
│   ├── STATUS.md                # Current project state
│   ├── ROADMAP.md               # Prioritized milestones
│   ├── PARALLEL-SESSIONS.md     # Rules for concurrent development
│   ├── RESEARCH-NOTES.md        # Notes on ongoing research
│   ├── architecture/
│   │   └── OVERVIEW.md          # This file
│   ├── decisions/
│   │   └── 001-initial-tech-choices.md
│   ├── learnings/
│   │   └── zig-0.16-changes.md  # API differences verified by compiling
│   ├── research/
│   │   ├── opengl-rendering-pipeline.md
│   │   ├── linear-algebra.md
│   │   ├── chunk-meshing.md
│   │   ├── terrain-generation.md
│   │   └── zig-c-interop.md
│   └── sessions/
│       └── 001.md
└── .agents/
    └── skills/                  # AI workflow definitions
        ├── session-start/
        ├── research/
        ├── implement/
        ├── code-review/
        └── prototype/
```

## Module Layout (Current)

The `src/world/` module is the first domain area. As rendering and other
systems are added, the structure will grow to:

```
src/
├── main.zig              # Entry point, game loop
├── renderer/             # OpenGL abstraction (future)
│   ├── shader.zig
│   └── camera.zig
├── world/                # Voxel world systems (current)
│   ├── block.zig         # Block types
│   ├── chunk.zig         # Chunk data structure
│   └── chunk_mesh.zig    # Mesh generation (naive per-face)
├── math/                 # Math primitives (future)
│   └── vec.zig
└── terrain/              # Terrain generation (future)
    └── noise.zig
```

Each module is self-contained with its own tests. The build system
runs all tests via `zig build test`.

## Key Design Principles

- **Keep it simple until forced otherwise.** Start with naive implementations.
  The meshing code is deliberately naive (per-face, no greedy meshing).
  Optimize only after profiling shows it's needed.
- **Zig-native.** Standard library + C interop only. No external Zig packages.
- **One thing at a time.** Each branch implements one issue from GitHub.

## Dependencies

System dependencies (installed via pacman, not managed in-repo):
- **Zig 0.16.0** — compiler and build system
- **GLFW** — window creation, input handling
- **GL (Mesa)** — OpenGL implementation
- **GLEW** — NOT needed, avoid due to Wayland incompatibility

## Build Commands

```bash
zig build              # Compile
zig build run          # Compile and run
zig build test         # Run all tests
zig build -Doptimize=ReleaseFast  # Optimized build
```

## Testing

Tests are embedded in source files and run via `zig build test`:
- `src/world/block.zig` — 4 tests (is_solid, is_transparent, properties, count)
- `src/world/chunk.zig` — 4 tests (default, set/get, fillLayer, boundaries)
- `src/world/chunk_mesh.zig` — 8 tests (face vertices, normals, empty mesh,
  single block, center block, adjacent blocks, fillLayer face count, air blocks)

Total: 16 unit tests, all passing.
