# Project Status

Last updated: 2026-10-02 (Session 021)

## What Works
- Zig 0.16.0 build system (`zig build`, `zig build run`, `zig build test`)
- GLFW window creation with OpenGL 3.3 core profile context
- Sky-blue clear color, escape-to-close, depth testing
- Procedural gradient sky dome with dynamic day/dusk/night color shifts
- Dynamic celestial sun orbit with shifting directional sunlight
- Diffuse + ambient directional lighting with per-vertex Voxel Ambient Occlusion (`FragAO`)
- First-person camera with mouse look and WASD movement
- Player physics with gravity, jump mechanics, and axis-separated AABB voxel collision snapping
- Block type system (air, stone, dirt, grass, water, wood, leaves) with distinct properties
- 4x4 procedural texture atlas (grass top/side, dirt, stone, translucent water, wood bark/rings, leaves, mob wool, mob face)
- 16x16x16 chunk data structure with set/get/fillLayer
- Greedy chunk mesher (Milestone 21) with corner & edge Ambient Occlusion calculation (Milestone 26)
- Procedural fBm value noise heightmap terrain generator with sea-level water lakes (`SEA_LEVEL = 5`) and natural tree generation (wood trunk + leaf canopy)
- Dynamic chunk streaming manager: hash-mapped chunk storage, loads and unloads around player position (radius 3 = 49 chunks)
- Frustum culling using 6 extracted view-projection planes against chunk AABBs
- Block picking via fast voxel DDA raycast (aim debug reporting)
- Interactive block editing (left-click break, right-click place) with cross-chunk border re-meshing
- Hotbar block selection (1=stone, 2=dirt, 3=grass, 4=water, 5=wood, 6=leaves) with dynamic HUD highlighting and selected-type block placement
- 2D UI overlay renderer: alpha-blended crosshair reticle and on-screen hotbar slots
- Procedural audio system (Milestone 28): multi-channel software synthesizer with ALSA backend for surface footsteps (grass, stone, wood, dirt), block destruction crunch, and block placement snap
- Chunk persistence (Milestone 18): binary serialization to disk (`c_{cx}_{cz}.bin`), auto-load on chunk spawn, auto-save modified chunks on purge/exit
- Mob & Entity system (Milestone 29): wandering voxel sheep with AABB physics, obstacle jumping, animated limb swing walking cycles, and textured multi-box rendering
- Real-time debug HUD reporting FPS, coordinates, chunk indices, mob count, day/night state, loaded/drawn/culled chunk counts, and aim target
- 174 unit tests across 20 subsystem modules passing

## Active Branch: feat/mobs-and-entities

Implements Milestone 29 (Mobs & Entities).

## What's Next

1. **Multiplayer** (Milestone 30): client-server networking or local loopback sync.
2. **Crafting & Inventory GUI** (Milestone 31): item slots, recipes, and UI interaction.

## Environment

- OS: CachyOS (Arch-based) on Wayland
- GPU: NVIDIA (OpenGL 3.3.0 NVIDIA 615.71.09)
- Audio: ALSA (44100Hz mono non-blocking)
- Zig: 0.16.0
- GLFW: 3.5.1
