# Project Status

Last updated: 2026-10-08 (Session 188)

## What Works
- Zig 0.16.0 build system (`zig build`, `zig build run`, `zig build test`) with 921 passing unit tests
- Window creation, input handling, OpenGL 3.3 Core Profile context via GLFW
- Procedural sky dome with day/night orbital lighting and dynamic twilight
- First-person camera with mouse look, sprint, jumping, and ladder climbing
- Axis-aligned bounding box (AABB) collision and voxel step snapping
- Suffocation damage mechanics (when player eye position is inside solid blocks)
- Player fall damage on hard landings
- Environmental hazards: Cactus contact damage (1 hp/sec), campfire burn (2 hp/sec), lava contact burn (8 hp/sec), water-lava contact crystallization (obsidian / cobblestone), ambient lava bubbling sound & ember smoke emission, Nether portal frame detection & activation, portal transit charge (3s) with orbital vortex particle ring (1.0 -> 0.7m radius), camera roll disorientation wobble, purple portal HUD vignette overlay, dimensional warp exit flash overlay, Nether ambient ash & cinder flake particles, Nether ambient distance fog shader and cavernous sky palette, synthesized Nether subterranean ambient wind & drone audio, Nether glowstone stalactites & magma fissure generation, Nether glowstone dynamic warm ambient point light spill, luminous glowstone shimmer & sparkling dust particles, synthesized crystalline glowstone chime audio with 3D attenuation, Nether quartz ore veins & crystalline quartz drops, Block of Quartz crafting & architectural masonry, Quartz Pillars & Chiseled Quartz Blocks, Nether Bricks crafting & fortress masonry, procedural Nether Fortress ruin bridges & pillars, 8:1 Overworld/Nether coordinate warp, and synthesized warp audio, Nether dimension world generation, Soul sand drag & elevator lift, Magma blocks with contact heat hazard (2 hp/s) and downward water whirlpool vortex drag (-7.0 m/s), Mob bubble column physics with upward soul sand launch (6.5 m/s) and magma whirlpool downward suction (-7.0 m/s), Mob contact heat hazards (magma blocks, campfire, lava dealing 1 hp/s with flinching hop, death removal, and synthesized searing contact burn audio sizzle/hiss, fiery contact spark bursts on magma/campfire stepping, and Fire Resistance Potion buff (180s complete immunity to lava, magma, and campfire burn damage with dynamic amber-gold HUD status indicator bar))
- Procedural audio synthesizer via ALSA with 3D spatial attenuation & distance rolloff: footsteps (grass, stone, wood, dirt, sand), block break/place, mob sounds
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
- Main branch stable at commit 2d11bd3 (Phase 8: Survival Depth & Environmental Physics, Milestones 43-48)
- All tests passing (921/921 tests across 83 test steps)
- Remote and local branches pruned clean
