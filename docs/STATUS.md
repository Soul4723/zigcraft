# Project Status

Last updated: 2026-10-02 (Session 013)

## What Works
- Zig 0.16.0 build system (`zig build`, `zig build run`, `zig build test`)
- GLFW window creation with OpenGL 3.3 core profile context
- Sky-blue clear color, escape-to-close, depth testing
- Procedural gradient sky dome rendered behind world with far-plane depth clamping
- Diffuse + ambient directional lighting in chunk shader
- First-person camera with mouse look and WASD movement
- Player physics with gravity, jump mechanics, and axis-separated AABB voxel collision snapping
- Block type system (air, stone, dirt, grass) with properties
- 4x4 procedural texture atlas (grass top, grass side, dirt, stone) with per-face UV assignment
- 16x16x16 chunk data structure with set/get/fillLayer
- Procedural fBm value noise heightmap terrain generator
- Dynamic chunk streaming manager: hash-mapped chunk storage, loads and unloads around player position (radius 3 = 49 chunks)
- Frustum culling using 6 extracted view-projection planes against chunk AABBs
- Block picking via fast voxel DDA raycast (aim debug reporting)
- Interactive block editing (left-click break, right-click place) with cross-chunk border re-meshing
- Chunk persistence (Milestone 18): binary serialization to disk (`c_{cx}_{cz}.bin`), auto-load on chunk spawn, auto-save modified chunks on purge/exit
- Real-time debug HUD reporting FPS, coordinates, chunk indices, loaded/drawn/culled chunk counts, and aim target
- 19 unit test suites across all subsystem modules passing

## Active Branch: feat/texture-atlas

Implements Milestone 5 (Texture atlas and multi-face block textures).

## What's Next

1. **Greedy meshing**: merge coplanar adjacent block faces to slash vertex buffer sizes and overdraw.
2. **Onscreen crosshair & block selection**: draw center crosshair and hotbar selection.

## Environment

- OS: CachyOS (Arch-based) on Wayland
- GPU: NVIDIA (OpenGL 3.3.0 NVIDIA 615.71.09)
- Zig: 0.16.0
- GLFW: 3.5.1
