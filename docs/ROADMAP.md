# Roadmap

Rough priority order. Completed milestones marked **[x]**.
> **Current milestone: 16 (Lighting).** Milestones 10–15 merged to main (#16, #18, #20, #22, #24). Each milestone is a meaningful increment — the project should
be buildable and runnable after each one.

## Phase 1: Window and Rendering Foundation

1. [x] **Window creation** — Open a window with a title using GLFW via Zig's C interop
2. [x] **OpenGL context** — Initialize OpenGL, clear to a sky-blue color
3. [x] **Triangle on screen** — Shader pipeline, VAO/VBO, draw a colored triangle
4. [x] **Camera** — First-person camera with mouse look and WASD movement
5. **Textured quad** — Load a PNG texture, render a textured quad

## Phase 2: Voxel World Basics

6. [x] **Block type system** — Define block types (air, dirt, grass, stone) with properties
7. [x] **Chunk data structure** — 16×16×16 chunk storing block IDs
8. [x] **Chunk meshing** — Generate mesh from chunk data (greedy or per-face)
9. [x] **Single chunk rendering** — Render one chunk with block textures (PR #14)
10. [x] **Multiple chunks** — Chunk manager, render a grid of chunks (#18)

## Phase 3: World and Interaction

11. [x] **Terrain generation** — Value-noise fBm heightmap (#16)
12. **Chunk loading/unloading** — Load chunks around the player, unload distant ones
13. [x] **Block picking** — DDA raycast aimed block, aim log (#22)
14. [x] **Block placement/destruction** — Click edit + remesh, cross-border fix (#24, #25)
15. [x] **Frustum culling** — Plane extraction + AABB test, draw stats (#20)

## Phase 4: Polish and Systems

16. **Lighting** — Basic ambient + directional lighting
17. **Sky rendering** — Gradient sky, sun position
18. **Chunk persistence** — Save/load chunks to disk
19. **Player physics** — Gravity, collision with blocks, jumping
20. **UI overlay** — Crosshair, debug info (FPS, position, chunk coords)

## Not Yet Planned

- Multiplayer
- Sound
- Mobs/entities
- Inventory
- Crafting
- Biomes
- Water/fluid simulation
- Advanced lighting (shadows, AO)

These are all in scope for the project long-term but not scheduled yet.
