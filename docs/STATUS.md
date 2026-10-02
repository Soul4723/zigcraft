# Project Status

Last updated: 2026-10-02 (Session 017)

## What Works
- Zig 0.16.0 build system (`zig build`, `zig build run`, `zig build test`)
- GLFW window creation with OpenGL 3.3 core profile context
- Sky-blue clear color, escape-to-close, depth testing
- Procedural gradient sky dome rendered behind world with far-plane depth clamping
- Diffuse + ambient directional lighting in chunk shader
- First-person camera with mouse look and WASD movement
- Player physics with gravity, jump mechanics, and axis-separated AABB voxel collision snapping
- Block type system (air, stone, dirt, grass, water, wood, leaves) with distinct properties
- 4x4 procedural texture atlas (grass top/side, dirt, stone, translucent water, wood bark/rings, leaves)
- 16x16x16 chunk data structure with set/get/fillLayer
- Greedy chunk mesher (Milestone 21): 2D slice-swept quad merger delivering up to ~99% vertex count reductions on planar voxel surfaces
- Procedural fBm value noise heightmap terrain generator with sea-level water lakes (`SEA_LEVEL = 5`) and natural tree generation (wood trunk + leaf canopy)
- Dynamic chunk streaming manager: hash-mapped chunk storage, loads and unloads around player position (radius 3 = 49 chunks)
- Frustum culling using 6 extracted view-projection planes against chunk AABBs
- Block picking via fast voxel DDA raycast (aim debug reporting)
- Interactive block editing (left-click break, right-click place) with cross-chunk border re-meshing
- Hotbar block selection (1=stone, 2=dirt, 3=grass, 4=water, 5=wood, 6=leaves) with dynamic HUD highlighting and selected-type block placement
- 2D UI overlay renderer: alpha-blended crosshair reticle and on-screen hotbar slots
- Chunk persistence (Milestone 18): binary serialization to disk (`c_{cx}_{cz}.bin`), auto-load on chunk spawn, auto-save modified chunks on purge/exit
- Real-time debug HUD reporting FPS, coordinates, chunk indices, loaded/drawn/culled chunk counts, and aim target
- 20 unit test suites across all subsystem modules passing

## Active Branch: feat/trees-and-foliage

Implements Milestone 25 (Procedural trees, wood, and leaves).

## What's Next

1. **Voxel ambient occlusion** (Milestone 26): calculate corner occlusion factors to shade block corners and crevices realistically.
2. **Day / Night cycle**: animate directional sun vector and sky dome colors over time.

## Environment

- OS: CachyOS (Arch-based) on Wayland
- GPU: NVIDIA (OpenGL 3.3.0 NVIDIA 615.71.09)
- Zig: 0.16.0
- GLFW: 3.5.1
