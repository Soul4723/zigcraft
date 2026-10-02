# Roadmap

Rough priority order. Completed milestones marked **[x]**.
> **Current milestone: 11 (Terrain generation).** Milestone 9 done on `feat/chunk-rendering` (PR #14).
All Phase 1 milestones except #5 (textured quad) are done on the `feat/camera` branch. Each milestone is a meaningful increment — the project should
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
10. **Multiple chunks** — Chunk manager, render a grid of chunks

## Phase 3: World and Interaction

11. **Terrain generation** — Simplex/Perlin noise for terrain heightmap
12. **Chunk loading/unloading** — Load chunks around the player, unload distant ones
13. **Block picking** — Raycast to highlight the block the player is looking at
14. **Block placement/destruction** — Add and remove blocks, remesh affected chunk
15. **Frustum culling** — Don't render chunks outside the camera frustum

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
