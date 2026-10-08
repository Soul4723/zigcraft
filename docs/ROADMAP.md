# Roadmap

Rough priority order. Completed milestones marked **[x]**.
> **Core engine in place.** Next focus: Textures, Visual Polish & Gameplay Depth.

## Phase 1: Window and Rendering Foundation

1. [x] **Window creation** — Open a window with a title using GLFW via Zig's C interop
2. [x] **OpenGL context** — Initialize OpenGL, clear to a sky-blue color
3. [x] **Triangle on screen** — Shader pipeline, VAO/VBO, draw a colored triangle
4. [x] **Camera** — First-person camera with mouse look and WASD movement
5. [x] **Textured quad / atlas** — Texture atlas with distinct block face textures (#33)

## Phase 2: Voxel World Basics

6. [x] **Block type system** — Define block types (air, dirt, grass, stone, water, wood, leaves)
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

## Phase 5: Optimization & Gameplay

21. [x] **Greedy meshing** — Merge coplanar faces across chunk to reduce vertex buffer sizes (#36)
22. [x] **Crosshair & Screen UI** — 2D viewport quad crosshair (#34)
23. [x] **Block inventory & selection** — Hotbar slots 1-6 to choose block type for placement (#34, #35, #37)
24. [x] **Water / fluid simulation** — Translucent water blocks and sea-level terrain lakes (#35)
25. [x] **Biomes & tree generation** — Height-dependent terrain and procedural trees/foliage (#37)
26. [x] **Voxel ambient occlusion** — Per-vertex corner occlusion in chunk shader (#38)
27. [x] **Day/Night cycle** — Animated sun orbit, directional light vector, and dusk/dawn sky dome colors (#39)
28. [x] **Sound / Audio system** — Procedural synthesizer & ALSA backend for footsteps, break, and place (#40)

## Phase 6: Gameplay Depth, Visual Polish & Content

29. [x] **Mobs / Entities** — Simple wandering voxel entity with AABB physics and rendering (#41)
30. [x] **Crafting & Inventory GUI** — Full inventory screen ('E'), 2x2 crafting grid, recipes, item consumption & drop collection (#42)
31. [x] **Handcrafted Voxel Textures (procedural pixel-art pass)** — Upgrade from flat procedural noise to authentic, detailed pixel-art textures (stone, cobblestone, ores, dirt, grass, wood, planks, leaves, crafting table).
32. [x] **Tool System & Block Hardness** — Mining speed tiers (bare hand vs pickaxe), tool durability, block hardness tables, and tool-dependent drops (stone requires pickaxe).
33. [x] **More Blocks, Ores & Underground Caves** — Coal, iron, 3D cave tunnels cutting through heightmap terrain.
34. [x] **Block Highlight Outline** — Wireframe bounding box rendering around the aimed voxel face.
35. [x] **Particle Effects** — Block break and placement voxel debris particles.

## Phase 7: Redstone, Environmental Physics & Survival Hazards

36. [x] **Redstone Mechanics** — Redstone wire signal decay (15 blocks), torches, repeaters (1-4 tick delays), levers, pressure plates, lamps with night glow, iron doors (#67-#82)
37. [x] **Falling Block Physics** — Unsupported sand blocks drop, crush non-solid cells, deal falling damage, splash into water (#85, #90, #91, #99)
38. [x] **Fluid Interactions** — Flowing water washes away floor redstone, torches, repeaters into drops (#92, #93, #94, #97, #98)
39. [x] **Player Suffocation Damage** — Damage tick when player head/eyes are buried inside solid blocks (#100)
40. [x] **Environmental Hazards** — Cactus contact damage, campfire burn damage (#104-#107)
41. [x] **Water Flow Simulation** — Finite levels with lateral decay, film drainage, persistence v2, shallow-water mesh heights, and non-source depletion (#150, #155, #157).
42. [x] **Hostile Mob Spawning & Pathfinding** — Cave wolf spawns (#153), water avoidance steering (#152), unified spawn safety (#149), and bounded A* obstacle pathfinding (#158).

## Phase 8: Survival Depth & Environmental Physics

43. [x] **Water Physics & Swimming** — Buoyancy, reduced gravity in water, jump swimming, water drag, water fall damage dampening (#159).
44. [x] **Oxygen & Drowning Hazard** — Oxygen depletion underwater, drowning damage tick when depleted, oxygen recovery on surface, breath bar on HUD (#160).
45. [x] **Underwater Visual Effects** — Blue ambient tinting, distance depth fog, aquatic sky dome colors when submerged (#161).
46. [x] **Underwater Bubble Particles** — Buoyant bubble particles trailing while swimming and bursting on drowning damage (#162).
47. [x] **Underwater Submersion Audio & Splash Sounds** — Synthesized splash on water entry/exit and resonant submerge plunge thud (#163).
48. [x] **Water Current Push Physics** — Lateral current velocity pushing players and mobs towards downstream open edges (#164).
49. [x] **Water Splash Particle Bursts** — Upward velocity-scaled droplet spray on water entry and falling block splash (#167).
50. [x] **Spatial Audio Distance Attenuation** — 3D positioned audio rolloff for mob calls, plate triggers, and distant explosions (#168).
51. [x] **Surface Breath Recovery & Gasp Mist** — Breath recovery gasp mist puff and audio trigger upon surfacing with low oxygen (#169).
52. [x] **Entity Swimming Floatation & Head Bobbing** — Mob water paddle buoyancy physics and snout-elevating head bob mesh rendering (#170).
53. [x] **Boat Crafting & Water Surface Navigation** — Wooden boat crafting recipe, water boarding/dismounting, surface hydroplaning, and cruising speed scale (#171).
54. [x] **Boat Wake & Bow Spray Particles** — Foaming lateral wake spread and forward spray particles when cruising in wooden boat (#172).
55. [x] **Lava Mechanics & Obsidian Reactions** — Lava liquid fluid, high heat burn damage (8 hp/s), glowing emissive light, and water-lava contact crystallization into obsidian/cobblestone (#173).
56. [x] **Lava Bubbling Audio & Smoke Ember Particles** — Synthesized lava pop/bubble sounds with 3D spatial attenuation, rising fiery embers and dark smoke particles (#174).
57. [x] **Nether Portal Frame Detection & Activation** — 2x3 obsidian frame detection (along X or Z axis), flint ignition activation, portal block rendering, ambient choir drone hum, and ethereal purple swirling particles (#175).
58. [x] **Portal Transit & Dimension Shift Mechanics** — Sustained portal dwell charge (3s), 8:1 Overworld/Nether spatial coordinate scaling, post-warp immunity cooldown (4s), swirling portal charge particles, and synthesized vortex warp audio (#176).
59. [x] **Nether Dimension World Generation** — Netherrack cavern ceilings & floors, vast lava seas at y<=4, and soul sand shorelines (#177).
60. [x] **Soul Sand Drag & Bubble Column Elevator Physics** — 40% movement deceleration drag on soul sand, vertical bubble elevator surge (6.5 m/s) in water above soul sand, and continuous bubble stream particles (#178).
61. [x] **Magma Blocks & Downward Whirlpool Drag** — Magma block contact heat damage (2 hp/s), 0.7 night emissive glow, and downward whirlpool water drag (-7.0 m/s) (#179).
62. [x] **Mob Bubble Column & Whirlpool Dynamics** — Soul sand upward elevator launch (6.5 m/s) and magma whirlpool downward suction (-7.0 m/s) for mobs (#180).
63. [x] **Mob Contact Heat Hazard & Damage Ticks** — Magma block, campfire, and lava contact heat damage (1 hp/s) and death removal for mobs (#181).
64. [x] **Burn Sizzle & Scald Audio Synthesis** — High-frequency burning contact sizzle/hiss synthesizer (`.burn_sizzle`) with 3D attenuation for players and entities (#182).
65. [x] **Burn Sparks & Hot Surface Debris Particles** — Upward spraying brilliant fiery sparks (`spawnBurnSparks`) on magma and campfire contact (#183).
66. [x] **Fire Resistance Status Effect & Potion Crafting** — Fire resistance potion recipe (magma + apple/glass), 3-minute buff (`180s`), and complete immunity to lava, magma, and campfire burn hazards (#184).
67. [x] **Fire Resistance HUD Indicator Bar** — Dynamic amber-gold status effect progress bar above player health on HUD (#185).
68. [x] **Nether Portal Orbital Vortex Particle Ring** — Contracting swirling particle vortex ring (`spawnPortalVortex`) during transit dwell charge (#186).
69. [x] **Portal Disorient Camera Wobble & Tilt** — Camera roll disorientation oscillation (`viewMatrixWithRoll`) scaling with transit dwell charge (#187).
70. [x] **Portal Transit HUD Vignette Overlay** — Full-screen peripheral purple overlay vignette (`drawPortalVignette`) scaling with portal dwell charge (#188).
71. [x] **Portal Warp Dimensional Flash Overlay** — Full-screen vibrant purple dimensional stabilization flash (`drawPortalFlash`) decaying upon portal exit warp (#189).
