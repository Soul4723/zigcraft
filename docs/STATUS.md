# Project Status

Last updated: 2026-10-03 (Session 023)

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
- 4x4 procedural texture atlas (bladed grass top, jagged grass-side fringe, clod/pebble dirt, speckled+cracked stone, ridged oak bark with knots, ringed log tops, gapped leaf canopy, grained planks, framed crafting table, cobblestone cells, coal ore blobs, translucent water, mob wool/face)
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
- Inventory & Crafting GUI (Milestone 31): 24-slot inventory (6 hotbar, 18 main), 2x2 crafting grid with real-time recipe resolution (planks, sticks, crafting table, wooden pickaxe), full-screen 'E' UI with cursor item manipulation, block mining drops, and placement consumption
- Mob & Entity system (Milestone 29): wandering voxel sheep with AABB physics, obstacle jumping, animated limb swing walking cycles, and textured multi-box rendering
- Real-time debug HUD reporting FPS, coordinates, chunk indices, mob count, day/night state, loaded/drawn/culled chunk counts, and aim target
- Cobblestone + coal ore blocks with underground veins (y=1..3), mining drops, stone footsteps, inventory items
- Tool system: hold-to-mine hardness timing, wooden pickaxe 3x on stone-class, tier-gated drops, 25-use durability, HUD progress bar
- Aimed-block wireframe highlight with pulse
- 3D voxel block break and placement particle bursts with physics and gravity
- 3D underground cave tunnels carved via dual 3D noise isosurfaces
- Iron ore block + veins + inventory item
- 206 unit tests passing

## Active Branch: feat/voxel-texture-overhaul

Implements texture half of Milestone 31 (handcrafted voxel texture pass + cobblestone/coal ore blocks).

## What's Next

1. **Remaining texture polish**: atlas tiles (2,3) and (3,3) still reserved/transparent; optional: sand, glass, brick blocks to fill them.
2. **Block Mining Speed & Tool Utility**: Bare hands mine slowly; wooden pickaxe mines stone faster. Block hardness and tool durability.
3. **Block Selection Highlight**: Render 3D wireframe outline on aimed block face.

## Environment

- OS: CachyOS (Arch-based) on Wayland
- GPU: NVIDIA (OpenGL 3.3.0 NVIDIA 615.71.09)
- Audio: ALSA (44100Hz mono non-blocking)
- Zig: 0.16.0
- GLFW: 3.5.1
