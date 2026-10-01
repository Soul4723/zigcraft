# Architecture Overview

Last updated: 2026-10-01 (Session 001)

## Project Structure

```
zigcraft/
├── AGENTS.md              # AI developer instructions
├── build.zig              # Zig build configuration
├── build.zig.zon          # Package manifest
├── src/
│   └── main.zig           # Entry point
├── docs/
│   ├── STATUS.md           # Current project state
│   ├── ROADMAP.md          # Prioritized milestones
│   ├── architecture/       # How the codebase is organized
│   ├── decisions/          # ADRs — why things are the way they are
│   ├── research/           # Investigation notes on topics
│   ├── sessions/           # Per-session logs
│   └── learnings/          # Zig, graphics, voxel engine knowledge
└── .agents/
    └── skills/             # AI workflow definitions
```

## Planned Module Layout

As the codebase grows, `src/` will split into modules:

```
src/
├── main.zig                # Entry point, game loop
├── window.zig              # GLFW window management
├── renderer/
│   ├── gl.zig              # OpenGL bindings and state
│   ├── shader.zig          # Shader compilation and linking
│   ├── mesh.zig            # Vertex data and draw calls
│   └── camera.zig          # View/projection matrices
├── world/
│   ├── block.zig           # Block type definitions
│   ├── chunk.zig           # Chunk data structure
│   ├── chunk_mesh.zig      # Mesh generation from chunk data
│   └── world.zig           # Chunk manager, world-level operations
├── terrain/
│   └── noise.zig           # Noise functions for terrain generation
└── math/
    └── vec.zig             # Vector/matrix math (or use std library)
```

This is a plan, not a commitment. Modules get created when they're needed.

## Key Design Principles

- **Keep it simple until forced otherwise.** Start with naive implementations,
  optimize when profiling shows a need.
- **Zig-native.** Use Zig's standard library and build system. C interop only
  for external libraries (GLFW, OpenGL).
- **One thing at a time.** Each session tackles one milestone or a clear piece
  of one. Don't half-build two things.

## Dependencies

- **Zig 0.16.0** — compiler and build system
- **GLFW** — window creation, input handling (system package, linked via build.zig)
- **OpenGL** — rendering (system headers, linked via build.zig)
- **stb_image** — texture loading (vendored as a Zig C import, when needed)
