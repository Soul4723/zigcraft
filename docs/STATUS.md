# Project Status

Last updated: 2026-10-07 (Session 119)

## What Works
- Zig 0.16.0 build system (`zig build`, `zig build run`, `zig build test`) with 703 passing unit tests
- Window creation, input handling, OpenGL 3.3 Core Profile context via GLFW
- Procedural sky dome with day/night orbital lighting and dynamic twilight
- First-person camera with mouse look, sprint, jumping, and ladder climbing
- Axis-aligned bounding box (AABB) collision and voxel step snapping
- Suffocation damage mechanics (when player eye position is inside solid blocks)
- Player fall damage on hard landings
- Environmental hazards: Cactus contact damage (1 hp/sec), campfire burn (2 hp/sec standing inside)
- Procedural audio synthesizer via ALSA: footsteps (grass, stone, wood, dirt, sand), block break/place, mob sounds
- 16x16x16 chunk data structures, greedy mesher with Ambient Occlusion (AO)
- Dynamic chunk streaming manager (load/unload radius around player) with frustum culling
- Chunk disk persistence (binary chunk files) with atomic replacement and write failure retention
- Block picking via fast DDA voxel raycasting and wireframe selection highlight
- Particle engine: 3D block-break physics debris, smoke puffs, spark/debris for levers, water splashes for falling sand
- Rich block palette (Air, Stone, Dirt, Grass, Water, Wood, Leaves, Cobblestone, Coal Ore, Iron Ore, Sand, Glass, Sandstone, Bricks, Snow, Torch, Chest, TNT, Ladders, Doors, Crafting Table, Furnace, Bed, Saplings)
- Redstone logic: Wire transmission with 15-block falloff, torches (NOT inverter with 30s burnout recovery), repeaters (1-4 tick delays), levers, pressure plates, lamps with night glow, iron doors
- Falling sand physics: unsupported sand drops, crushes non-solid cells, inflicts falling damage, splashes into water
- Fluid interactions: water washes floor redstone, torches, repeaters, dropping items into player inventory (helpers in `src/world/fluid_wash.zig`, redstone caches in `src/world/component_cache.zig`)
- Water spread: spreads over solid floors and ledges; staged ticks prevent scan-order cascades
- Mob system: wandering Sheep, Pigs (oink + meat drops), and hostile Wolves with tracking/attack AI
- 24-slot inventory, hotbar HUD, 2x2 crafting grid, chest storage containers, tool mining speed & durability system
- HUD toast warning queue for system notifications (cap overflows, redstone burnout)

## Active State
- Main branch stable at commit 62f64f3
- All tests passing (703/703)
- Remote branches pruned clean
