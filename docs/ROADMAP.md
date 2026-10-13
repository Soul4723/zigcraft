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
72. [x] **Nether Ambient Ash & Cinder Flake Particles** — Atmospheric drifting ash flakes and floating cinder embers (`spawnNetherAsh`) across Nether caverns (#190).
73. [x] **Nether Dimension Ambient Fog & Atmospheric Sky Palette** — Cavernous crimson sky dome, fiery horizon clear color, and distance depth fog shader transitions (`u_nether`, `calculateNetherFog`) (#191).
74. [x] **Nether Ambient Winds & Subterranean Drone Audio** — Synthesized ominous cavern winds, 55Hz subterranean rumble, and whistling breath audio (`.nether_wind`) (#192).
75. [x] **Nether Glowstone Stalactites & Magma Fissure Deposits** — Luminous ceiling glowstone clusters (`glowstone`, emissive 1.0) and shoreline magma block veins in Nether terrain generation (#193).
76. [x] **Nether Glowstone Dynamic Warm Ambient Light Spill** — Point illumination spill from hanging glowstone clusters onto cavern surfaces in Nether darkness (#194).
77. [x] **Nether Glowstone Shimmer & Glittering Dust Particles** — Radiant golden-amber sparkle glints and buoyant luminous dust (`spawnGlowstoneShimmer`) emitted by active glowstone (#195).
78. [x] **Nether Glowstone Crystalline Bell Chime Audio Synthesis** — Multi-harmonic pure bell chimes (880/1760/2640Hz) with 3D spatial attenuation (`.glowstone_chime`) (#196).
79. [x] **Nether Quartz Ore Veins & Mineral Harvesting** — Crystalline quartz ore veins embedded in netherrack (`nether_quartz_ore`), pickaxe harvest requirements, and raw quartz drops (`nether_quartz`) (#197).
80. [x] **Block of Quartz Crafting & Architectural Masonry** — 2x2 crafting recipe (4 nether quartz -> block of quartz), beveled marble texture, and building block mechanics (`quartz_block`) (#198).
81. [x] **Quartz Pillars & Chiseled Quartz Architectural Blocks** — Fluted columns (`quartz_pillar`), ceremonial glyph medallions (`chiseled_quartz_block`), and vertical stacking crafting recipes (#199).
82. [x] **Nether Bricks Crafting & Fortress Masonry** — 2x2 Netherrack masonry recipe (4 netherrack -> 4 nether bricks), dark purplish fiery running-bond texture atlas tile, and wooden pickaxe harvesting (#200).
83. [x] **Nether Fortress Procedural Ruins Generation** — Periodic cavern cross-spans, monumental bridges at y=7, perimeter safety balustrades (y=8), and heavy support pillars extending to cavern floors (#201).
84. [x] **Nether Brick Fence & Fortress Balustrade Railings** — Thin-post fence block (`nether_brick_fence`), post/rail atlas tile with transparent cutouts, vertical 2-brick crafting recipe -> 2 fences, and fortress y=8 perimeter balustrade placement (#202).
85. [x] **Nether Wart Crop Farming** — Soul-sand-gated planting, 60s ripening with mature bonus yield, wild shore patches in Nether gen (#203).
86. [x] **Emberbeast Nether Hostile Mob** — Fire-immune fortress hunter (8 HP, 2x bite), A* pack hunting, roar synth, Nether spawns (#204).
87. [x] **Nether Wart Brewing Hook** — Wart + glass vial brews Fire Resistance Potion; legacy magma path preserved (#205).
88. [x] **Fortress Loot Chest Alcoves** — Junction-corner chests with deterministic wart/quartz/iron loot on first open (#206).
89. [x] **Emberbeast Fireball Ranged Attack** — Aimed 3-dmg flame bolts with trail/burst, potion immunity (#207).
90. [x] **Fireball Block Ignition** — Fireball strikes ignite campfires atop flammable floors (#208).
91. [x] **Loot-Chest Emberbeast Guard Ambush** — 50% deterministic guard spawn with roar on fortress chest open (#209).
92. [x] **Ignited Campfire Flame Burnout** — Fireball flames expire after 45s; player campfires permanent (#210).
93. [x] **Fortress Emberbeast Spawner Pulse** — 20s reinforcement waves near player in Nether (max 2 near) (#211).
94. [x] **Emberbeast Kill Loot** — Coal + 0-2 wart bonus with flame burst on kill (#212).
95. [x] **Nether Fortress Compass** — C-key nearest-junction readout with distance in Nether (#213).
96. [x] **Live Fortress Compass Needle HUD** — Rotating crimson/gold needle above crosshair in Nether (#214).
97. [x] **Magma Cream Crafting & Potion Brewing** — Coal + wart crafts cream; brews Fire Resistance with glass vial (#215).
98. [x] **Throwable Fire Charge** — Magma cream + coal crafts 3x; thrown for 2-dmg + floor ignition (#216).
99. [x] **Fire Charge TNT Ignition** — Priming TNT via thrown direct hits or right-click consume (#217).
100. [x] **Soul Torches with Cyan Flame & Crafting** — Soul torches (block 55, item 64) with 0.7 emissive cyan lighting, ethereal turquoise atlas tile, and soul sand + torch crafting (#218).
101. [x] **Fortress Bridge Ambient Soul Torches** — Procedural Nether fortress bridge spans naturally illuminated with ambient soul torches mounted atop fence balustrades (y=9, 6-block interval) (#219).
102. [x] **Soul Campfire with Cyan Embers & Crafting** — Soul campfires (block 56, item 65) with 0.8 emissive cyan embers, dark soul-wood logs atlas tile (4,0), contact burn hazard, and soul sand + campfire crafting (#220).
103. [x] **Soul Sand Fireball Ignition into Soul Campfires** — Fireball and fire charge impacts on soul sand floors ignite soul campfires with 45s burnout tracking (#221).
104. [x] **Monster Spawner Cage Block & Fortress Alcoves** — Monster spawner block (block 57, item 66) with iron mesh grating atlas tile (5,0), glowing core (emissive 0.6), and procedural placement in fortress junction alcoves (#222).
105. [x] **Spawner Cage Mob Wave Anchoring** — Fortress reinforcement pulse detects nearby active spawner cages (16m activation radius) and spawns emberbeasts near the cage alcove (#223).
106. [x] **Spawner Cage Spinning Ember Particles** — Active player-placed spawner cages emit orbiting ember flames within 16m activation radius (#224).
107. [x] **Wither Skeleton Fortress Hunter** — Tall bone mob (10 HP, 1.5x bite, fire-immune) guarding fortress bridges with hunt AI and spawner waves (#225).
108. [x] **Wither Bite Status Effect** — Skeleton bites apply 8s poison (1 HP/s drain, cleared on respawn) with dark purple HUD indicator bar stacked above fire-res bar (#226).
109. [x] **Wither Healing Suppression** — Regen and passive hunger healing paused while withered; health bar darkens to bone-gray for readability (#227).
110. [x] **Wither Cure via Golden Apple** — Eating a golden apple cleanses wither poison; milk bucket deferred until cows exist (#228).
111. [x] **Wither Skeleton Skull Trophy** — Rare deterministic ~1/8 bone-white skull drop on wither skeleton kills (melee + fire-charge paths) (#229).
112. [x] **Placeable Wither Skull Trophy Block** — Skull places as non-solid display block with bone tile art; breaks back into skull via generic paths (#230).
113. [x] **Wither Champion Summon** — Completed soul-sand skull-T (either axis) consumes pattern, raises 30 HP wither skeleton champion with roar + flame burst (#231).
114. [x] **Nether Star & Champion Combat Scaling** — Wither champion deals 2.5x bite damage; defeat drops 1 Nether Star + 2 skulls across melee and fire-charge kill paths (#225).
115. [x] **Beacon Block & Nether Star Crafting** — 1 Nether Star + 1 Obsidian + 2 Glass crafts 1 Beacon block (1.0 emissive glow, obsidian footing + incandescent cyan star core) (#227).
116. [x] **Active Beacon Sky Beam & Regeneration Aura** — Unobstructed beacons emit ascending cyan/white sky beam particles (12-16 m/s) and grant a continuous 24m regeneration aura (#229).
117. [x] **Ancient Debris Generation & Netherite Scrap Smelting** — Rare ancient debris veins generate in deep Nether strata (y=2..4), mine with pickaxe, and smelt in furnaces into netherite scrap (#231).
118. [x] **Netherite Ingot Crafting & Netherite Pickaxe Upgrade** — 2 scraps + 2 iron ingots craft netherite ingots; upgrade iron pickaxes into netherite pickaxes (350 durability, 6.0x mining speed) (#233).
119. [x] **Netherite Sword Weapon Upgrade & Tier-4 Combat** — 1 Iron Sword + 1 Netherite Ingot upgrades into Netherite Sword (400 durability, 4 melee damage) (#235).
120. [x] **Respawn Anchor Block & Nether Spawn Anchoring** — 2 Obsidian + 2 Glowstone crafts Respawn Anchor (block 61, item 75, emissive 0.85, glowstone top / obsidian casing); right-click anchors player respawn point with portal hum and shimmer particles (#237).
121. [x] **Crying Obsidian Block, Nether Generation & Crafting** — Crying Obsidian (block 62, item 76, emissive 0.7 purple glow, tile 6,4); generated in deep Nether strata (y=3..5); 1 Obsidian + 1 Magma Cream crafts 1 Crying Obsidian; usable in Respawn Anchor recipe (#239).
122. [x] **Lodestone Block Crafting & Lodestone Compass Tracking** — 1 Netherite Ingot + 1 Chiseled Quartz/Stone crafts Lodestone (block 63, item 77, rune tile 7,3 top / 6,3 side); right-click binds compass needle to lodestone position across dimensions; C-key readout displays target coords & distance (#241).
123. [x] **Basalt Block Crafting & Nether Basalt Column Generation** — Basalt (block 64, item 78, hardness 2.5, polygonal cap tile 5,4 / column sides 4,4); 1 Cobblestone + 1 Soul Sand/Magma crafts 2 Basalt; vertical basalt columns generate across Nether lava deltas (y=4..11) (#243).
124. [x] **Blackstone Block Crafting & Bastion Remnant Generation** — Blackstone (block 65, item 79, hardness 3.0, charcoal masonry tile 2,5); 1 Basalt + 1 Coal/Basalt crafts 2 Blackstone; procedural 12x12 Bastion Remnant rampart ruins generate in Nether caverns (y=5..10) (#245).
125. [x] **Gilded Blackstone Block, Gold Drops & Bastion Veins** — Gilded Blackstone (block 66, item 80, gold seam tile 3,5); mining drops 1 Blackstone + 2 Gold Nuggets (item 81); 2 Apples + 2 Gold Nuggets crafts Golden Apple; procedural veins embed in Bastion rampart walls (#247).
126. [x] **Bastion Piglin Mob & Gold Bartering** — Piglin mob (10 HP, 1.5x sword dmg, gold nugget drop), bastion rampart guard spawns, gold pacification, right-click gold nugget bartering with Nether goods and golden toast flash (#249).
127. [x] **Weeping Vines Nether Vegetation & Climbing** — Weeping vines (block 67, item 82, emissive 0.35, crimson tile 6,1); vertical climbing physics (is_ladder), ceiling attachment rules, 2 nether wart crafting recipe, and procedural cavern ceiling tendril generation (#251).
128. [x] **Twisting Vines Nether Vegetation & Upward Growth** — Twisting vines (block 68, item 83, emissive 0.40, cyan tile 7,1); upward climbing physics (is_ladder), floor attachment rules, 1 weeping vine + 1 soul sand crafting, and procedural soul sand shore stalk generation (#253).
129. [x] **Target Block Crafting & Redstone Projectile Detection** — Target block (block 69, item 84, hardness 0.6, wood footstep, texture 3,3); 1 Redstone Dust + 1 Wood Planks crafts 1 Target block; projectile hits (snowballs, fire charges) trigger 0.4s (8-tick) redstone signal powering adjacent redstone wires (#255).
130. [x] **Hay Bale Block & Campfire Smoke Signals** — Hay bale block (block 70, item 85, hardness 0.5, grass footstep, golden straw texture 0,3 sides / 1,4 top); Recipe 51 (2 Wood Planks + 2 Saplings/Leaves -> 1 Hay Bale); 80% fall damage reduction when landing on hay bales; campfires emit rising smoke particles, boosted into high-altitude signal smoke when placed atop hay bales (#257).
131. [x] **Respawn Anchor Charging & Overworld Overcharge Detonation** — Respawn anchors charge up to 4x using Glowstone; Nether right-click sets spawn point and consumes charges upon respawning; Overworld interaction triggers violent overcharge crater explosion (#259).
132. [x] **Nether Portal Spatial Linking & Destination Search** — Portal activation caches active frame coordinates; dimension shifts search nearest active portal in target dimension within 128m search radius using 8:1 coordinate translation; players emerge directly inside matched portal frame (#261).
133. [x] **Nether Portal Frame Break & Water/Explosion Extinguish** — Breaking obsidian frame blocks, adjacent water wash contact, or TNT/anchor explosions extinguish active portal interior cells into air with portal particles and sizzle audio (#263).
134. [x] **Crimson & Warped Nether Fungi & Soul Soil Planting** — Crimson fungus (block 71, item 86, tile 6,1) and Warped fungus (block 72, item 87, emissive 0.35, tile 7,1); Recipe 52 (Nether Wart + Sapling -> 2 Crimson Fungus), Recipe 53 (Twisting Vines + Sapling -> 2 Warped Fungus); procedural Nether cavern floor and soul sand shore generation, solid floor planting (#265).
135. [x] **Warped Fungus Piglin Repulsion & Avoidance AI** — Piglins fear warped fungi within 8m or when player holds warped fungus; flee in opposite yaw direction and attacks are inhibited (#267).
