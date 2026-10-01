# Architecture Overview

Last updated: 2026-10-01 (Session 002)

## Project Structure

```
zigcraft/
├── AGENTS.md                    # AI developer instructions
├── CONTRIBUTING.md              # AI workflow guide, guard rails, patterns
├── build.zig                    # Zig build configuration
├── build.zig.zon                # Package manifest
├── README.md
├── src/
│   ├── main.zig                 # Entry point, game loop, input handling
│   ├── math.zig                 # Vec3, Mat4 — math primitives for rendering
│   ├── camera.zig               # First-person camera (mouse look, WASD)
│   ├── c.zig                    # (removed) — see Decisions
│   ├── renderer/
│   │   ├── shader.zig           # Shader compilation, MVP uniforms
│   │   └── mesh.zig             # VAO/VBO/EBO mesh wrapper, triangle test mesh
│   └── world/
│       ├── block.zig            # BlockId enum, block properties
│       ├── chunk.zig            # 16×16×16 chunk data structure
│       └── chunk_mesh.zig       # Mesh generation from chunk data (naive per-face)
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
│       ├── 001.md               # Bootstrap + infrastructure
│       └── 002.md               # First-person camera
└── .agents/
    └── skills/                  # AI workflow definitions
        ├── session-start/
        ├── research/
        ├── implement/
        ├── code-review/
        └── prototype/
```

## Module Layout (Current)

```
src/
├── main.zig              # Entry point, game loop, GLFW input polling
├── math.zig              # Vec3 + Mat4 with tests (10 tests)
├── camera.zig            # First-person camera with tests (5 tests)
├── renderer/
│   ├── shader.zig        # OpenGL shader compile/link, MVP uniform (1 test)
│   └── mesh.zig          # GPU mesh wrapper, triangle test (1 test)
├── world/
│   ├── block.zig         # Block types, properties (4 tests)
│   ├── chunk.zig         # Chunk data structure (4 tests)
│   └── chunk_mesh.zig    # Naive per-face mesh generator (8 tests)
```

## How Modules Connect

- `main.zig` imports `math.zig`, `camera.zig`, `renderer/shader.zig`,
  `renderer/mesh.zig` — orchestrates the render loop and input handling.
- `camera.zig` imports `math.zig` — uses Vec3/Mat4 for view/projection.
- `renderer/shader.zig` and `renderer/mesh.zig` each have their own
  `@cImport` block for OpenGL/GLFW headers. They do not import each other.
- `world/chunk_mesh.zig` imports `chunk.zig` and `block.zig` for block data.

## Module Placement Decision: camera.zig in src/ (not src/renderer/)

The camera module lives at `src/camera.zig` (top-level), not `src/renderer/`.
This decision was driven by two Zig 0.16 constraints:

1. **Cross-directory imports fail in standalone tests.** A file at
   `src/renderer/camera.zig` cannot `@import("../math.zig")` when compiled
   as a standalone test target. Placing `camera.zig` in `src/` (same
   directory as `math.zig`) keeps the import local: `@import("math.zig")`.
2. **Each `@cImport` creates distinct opaque types.** If main.zig and
   camera.zig both need GLFW types (`GLFWwindow`), they can't share them
   unless they import from the same `@cImport` call. Rather than creating
   a shared `c.zig` module (which has the same cross-directory issue),
   camera.zig has its own `@cImport` and main.zig does the key polling,
   passing only primitive `c_int` values to `Camera.processKey()`.

## Key Design Principles

- **Keep it simple until forced otherwise.** Start with naive implementations.
  The meshing code is deliberately naive (per-face, no greedy meshing).
  Optimize only after profiling shows it's needed.
- **Zig-native.** Standard library + C interop only. No external Zig packages.
- **One thing at a time.** Each branch implements one issue from GitHub.
- **Tests through standalone targets.** Each module has its own test target
  in `build.zig`. The main module test (`addTest` with `root_module`) does
  NOT collect tests from imported modules in Zig 0.16, so every module
  with tests must have its own entry in `test_files`.

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

Tests are embedded in source files and run via `zig build test`.
Each module with tests has a standalone test target in `build.zig`.

| Module | Test File | Tests |
|--------|-----------|-------|
| math | `src/math.zig` | 10 (4 Vec3 + 6 Mat4) |
| camera | `src/camera.zig` | 5 (includes 10 math tests via import) |
| shader | `src/renderer/shader.zig` | 1 |
| mesh | `src/renderer/mesh.zig` | 1 |
| block | `src/world/block.zig` | 4 |
| chunk | `src/world/chunk.zig` | 4 (includes 4 block tests via import) |
| chunk_mesh | `src/world/chunk_mesh.zig` | 8 (includes 4 chunk + 4 block via import) |

Total: 33 test results across 7 targets (some tests run multiple times
due to transitive imports).
