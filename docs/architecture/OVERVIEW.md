# Architecture Overview

Last updated: 2026-10-07 (Session 112)

## Project Structure

```
zigcraft/
├── AGENTS.md                    # AI developer instructions
├── CONTRIBUTING.md              # AI workflow guide, guard rails, patterns
├── build.zig                    # Zig build configuration & test registry
├── build.zig.zon                # Package manifest
├── README.md
├── src/
│   ├── main.zig                 # Game loop, GLFW window setup, input & tick dispatch
│   ├── math.zig                 # Vec3, Mat4, Ray math primitives
│   ├── camera.zig               # First-person camera (WASD, mouse look)
│   ├── player.zig               # Player physics, AABB collision, ladder climbing
│   ├── pick.zig                 # Fast DDA voxel raycasting for block targeting
│   ├── sky.zig                  # Sky dome and sun orbit lighting calculations
│   ├── inventory.zig            # Slot inventory, item definitions, 2x2 crafting
│   ├── entity.zig               # Base entity interface
│   ├── entity/                  # Mobs, sheep, pigs, hostile wolves, mob rendering
│   ├── audio/                   # ALSA backend, procedural waveform synthesizer
│   ├── renderer/
│   │   ├── shader.zig           # Shader compile & uniforms
│   │   ├── mesh.zig             # OpenGL VAO/VBO wrappers
│   │   ├── texture.zig          # Atlas generation & binding
│   │   ├── ui.zig               # 2D crosshair, hotbar, and toast pills
│   │   ├── particles.zig        # 3D voxel physics debris & splash emitters
│   │   └── highlight.zig        # Wireframe block selection box
│   └── world/
│       ├── block.zig            # BlockId definitions & block attributes
│       ├── chunk.zig            # 16x16x16 chunk storage
│       ├── chunk_mesh.zig       # Greedy chunk meshing with ambient occlusion
│       ├── terrain.zig          # fBm heightmap terrain & cave generation
│       ├── fluid_wash.zig       # Water wash rules and staged nearby flow ticks
│       ├── redstone.zig         # Wire BFS logic, delay stages, power propagation
│       └── persistence.zig      # Binary chunk serialization
└── docs/
    ├── STATUS.md                # Real-time state of the project
    ├── ROADMAP.md               # Milestones & planned systems
    ├── PARALLEL-SESSIONS.md     # Multi-agent collaboration rules
    ├── architecture/            # Architectural blueprints
    ├── decisions/               # ADR decision logs
    ├── learnings/               # Zig 0.16.0 API discoveries
    └── sessions/                # Chronological session logs
```

## Testing
Module tests run through standalone targets registered in `build.zig`. Run with:
```bash
zig build test --summary all
```

## Water ticks

`main.zig` dispatches `fluid_wash.step` every 0.4 seconds. The step scans the
existing player-centered window (horizontal radius 7, vertical -3/+2, clipped
to world height), stages up to eight distinct destinations, then applies them
through `ChunkManager.editAndRemesh`. Reading before writing prevents new water
from spreading again during the same tick. Downward flow takes priority;
lateral flow accepts air over either ground or a ledge. Occupied cells remain
unchanged. This remains a source-copy model: finite levels and drainage require
persisted fluid metadata and remain an unfinished roadmap milestone.
