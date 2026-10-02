# Roadmap

Rough priority order. Completed milestones marked **[x]**.
> **Milestones 1 through 24 complete!** Next focus: Biomes, Trees, and Gameplay.

## Phase 1: Window and Rendering Foundation

1. [x] **Window creation** — Open a window with a title using GLFW via Zig's C interop
2. [x] **OpenGL context** — Initialize OpenGL, clear to a sky-blue color
3. [x] **Triangle on screen** — Shader pipeline, VAO/VBO, draw a colored triangle
4. [x] **Camera** — First-person camera with mouse look and WASD movement
5. [x] **Textured quad / atlas** — Texture atlas with distinct block face textures (#33)

## Phase 2: Voxel World Basics

6. [x] **Block type system** — Define block types (air, dirt, grass, stone, water) with properties
7. [x] **Chunk data structure** — 16×16×16 chunk storing block IDs
8. [x] **Chunk meshing** — Generate mesh from chunk data (greedy or per-face)
9. [x] **Single chunk rendering** — Render one chunk with block textures (PR #14)
10. [x] **Multiple chunks** — Chunk manager, render a grid of chunks (#18)

## Phase 3: World and Interaction

11. [x] **Terrain generation** — Value-noise fBm heightmap (#16)
12. [x] **Chunk loading/unloading** — Load chunks around the player, unload distant ones (#31)
13. [x] **Block picking** — DDA raycast aimed block, aim log (#22)
14. [x] **Block placement/destruction** — Click edit + remesh, cross-border fix (#24, #25)
15. [x] **Frustum culling** — Plane extraction + AABB test, draw stats (#20)

## Phase 4: Polish and Systems

16. [x] **Lighting** — Diffuse + ambient in chunk shader (#26)
17. [x] **Sky rendering** — Gradient dome, sun TBD (#27)
18. [x] **Chunk persistence** — Save/load chunks to disk (#32)
19. [x] **Player physics** — Gravity, AABB collision, jumping (#28)
20. [x] **UI overlay** — Debug HUD in log + title; on-screen text TBD (#29)

## Phase 5: Optimization & Gameplay (Upcoming)

21. [x] **Greedy meshing** — Merge coplanar faces across chunk to reduce vertex buffer sizes (#36)
22. [x] **Crosshair & Screen UI** — 2D viewport quad crosshair (#34)
23. [x] **Block inventory & selection** — Hotbar slots 1-4 to choose block type for placement (#34, #35)
24. [x] **Water / fluid simulation** — Translucent water blocks and sea-level terrain lakes (#35)
25. **Biomes & tree generation** — Height-dependent biomes and procedural trees/foliage ← next

## Long-term

- Multiplayer
- Sound
- Mobs/entities
- Crafting
- Advanced lighting (ambient occlusion, shadows)
