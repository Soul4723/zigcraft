# Project Status

Last updated: 2026-10-29 (Session 420, Phase 8: Milestones 511–520)

Wave 24 integration completes Milestones 511–520. All ten domain modules are
registered once as standalone test targets in `build.zig`, imported by
`main.zig`, and queried from representative frame-loop hooks. The Dragon
Respawn Ritual advances at 20 ticks per second in the existing simulation.
ItemTypes 628–637 add the Wave 24 materials with display names, RGBA colors,
and requested stack limits; six 2x2 recipes are available through
`Inventory.updateCrafting()`. `glass_bottle` is added at ID 638 as a missing
ingredient for the Dragon's Breath Vial recipe. `BlockId` remains within its
8-bit capacity. Verification passes 11,520 tests across 591 build/test steps.

## Wave 24 Integration (Milestones 511–520)

- Integrated chorus teleportation/purpur masonry, End Gateway transit, Shulker shell defense, Shulker Box storage, Elytra flight, Dragon Head acoustics, Dragon's Breath alchemy, End City layout, End Ship vault, and Dragon Respawn Ritual.
- The ten modules are each registered exactly once as standalone test targets; all are imported and queried each frame, using existing Elytra wear and 20 Hz ritual simulation hooks where those rules already run.
- ItemTypes 628–637 define Chorus Teleport Matrix, End Gateway Shard, Shulker Shell Armor Plate, Quantum Shulker Core, Elytra Mending Wing, Dragon Skull Horn, Dragon's Breath Vial, End City Vault Key, End Ship Figurehead, and Dragon Respawn Crystal. Six 2x2 recipes craft the matrix, armor plate, core, mending wing, horn, and vial. The inventory test checks IDs, stack limits, display names, RGBA channels, all six outputs, and `BlockId` capacity.
- Verification: `ZIG_GLOBAL_CACHE_DIR=/tmp/zig-cache ZIG_LOCAL_CACHE_DIR=/tmp/zig-local-cache zig build` passes; the same environment with `zig build test --summary all` passes 11,520/11,520 tests across 591 steps.

## Wave 24 (Milestone 520)

- Added the four-crystal Ender Dragon respawn ritual and caller-applied events.
- Verification: the ritual module passes all 40 focused tests (162 total including imported block tests).

---

Last updated: 2026-10-29 (Session 418, Phase 8: Milestones 501–510)

Wave 23 integration completes Milestones 501–510. All ten domain modules are
registered once as standalone test targets, imported into `main.zig`, and
queried from representative frame-loop hooks. ItemTypes 618–627 add the Wave
23 materials with display names, RGBA colors, requested stack limits, and six
2x2 recipes. `BlockId` remains within its 8-bit capacity. Verification passes
10,791 tests across 571 build/test steps.

## Wave 23 Integration (Milestones 501–510)

- Integrated Blaze artillery, Magma Cube splitting, Ghast fireball tennis, Wither Skeleton effect, Wither boss phases, Beacon status pyramids, Conduit underwater power, Guardian laser/spikes, Elder Guardian curse, and Nether portal coordinate scaling.
- The ten modules were already registered exactly once in `build.zig`; all are now imported and queried once per frame from representative domain hooks in `main.zig`.
- ItemTypes 618–627 define the Wave 23 core, catalyst, essence, relic, talisman, orb, emitter, sponge, and compass materials. Item metadata defines display names, RGBA colors, and requested stack sizes. Six 2x2 recipes produce the Blaze Artillery Core, Magma Cream Catalyst, Ghast Tear Essence, Wither Skull Relic, Nether Star Core, and Conduit Power Orb. The inventory unit test checks the item IDs, stack limits, names, valid colors, recipe outputs, and `BlockId` capacity.
- Verification: `ZIG_GLOBAL_CACHE_DIR=/tmp/zig-cache ZIG_LOCAL_CACHE_DIR=/tmp/zig-local-cache zig build` passes; `ZIG_GLOBAL_CACHE_DIR=/tmp/zig-cache ZIG_LOCAL_CACHE_DIR=/tmp/zig-local-cache zig build test --summary all` passes 10,791/10,791 tests across 571 build/test steps.

Last updated: 2026-10-29 (Session 416, Milestone 509)

Milestone 509 adds `src/world/elder_guardian_curse.zig`: 80 HP/2.8m/1.8 m/s
Elder Guardian stats, three monument room assignments, 50m entry curse event,
30-tick phantom, 6,000-tick Mining Fatigue III with a 0.001 mining-speed
multiplier and milk cleansing, two-HP spikes retaliation, guaranteed Wet
Sponge, 20% Tide template, 10 XP, and an eight-Gold-Block apex vault. All 46
focused tests pass. The standalone API is registered for tests; live rendering,
audio playback, effect plumbing, and procedural apex vault placement remain
runtime integration work.

Last updated: 2026-10-29 (Session 416, Milestone 510)

Milestone 510 adds `src/world/nether_portal_scaling.zig` with floor-based 1:8
Overworld/Nether coordinates, clamped Y coordinates, 128-block horizontal
portal selection using 3D closest distance, safety-scored generated frames,
minimum obsidian-frame validation, and player/entity transit ticks with an
80-tick player trigger and 300-tick return cooldown. It is registered as a
standalone test target; dimension changes and applying generated blocks remain
with the game loop and world owners. All 31 focused tests pass.

Last updated: 2026-10-29 (Session 415, Milestone 508)

Milestone 508 adds `src/world/guardian_laser_spikes.zig`, a standalone Guardian
domain model with 30 HP, smooth 2.4 m/s swimming, awkward land hops and a
half-second suffocation pulse, a visible-target 60-tick laser with 15m
acquisition, 16m tracking, line-of-sight cancellation and difficulty-scaled
unmitigated magic damage, plus twelve orange retractable spikes and 2 HP
thorns retaliation. Prismarine Shards, Prismarine Crystals, and Raw Cod are
exposed as drops. The module is registered as a standalone test target; its
events leave rendering and live entity damage application with their existing
owners. All 39 focused tests pass.

Last updated: 2026-10-29 (Session 412, Milestone 505)

Milestone 505 adds \`src/world/wither_boss_phases.zig\`, a standalone Wither
domain model for X/Z-axis soul sand/soil T-frame summoning, a 220-tick zero-to-
300 HP invulnerable birth charge and power-7 explosion, three independently
timed skull heads, the 150 HP armor transition with projectile immunity and
ground melee, and a 200-tick defeat animation with one blast-proof Nether Star
and 50 XP. The module is registered as a standalone test target; its events
leave rendering, world block mutation, projectile application, and inventory
changes with their existing owners. All 36 focused tests pass.

Last updated: 2026-10-29 (Session 411, Milestone 503)

Milestone 503 adds the standalone Ghast artillery and fireball tennis domain in
`src/world/ghast_fireball_tennis.zig`: 10 HP and 4m dimensions, fire/lava and
fall immunity, 0.5–1.5 m/s gravity-free flight, visible-target 64m detection,
10-tick charge, 20 m/s power-1 fireballs, player attack deflection, lethal
Return to Sender hits, Ghast loot, and 47 focused tests. The module is registered
as a standalone test target; rendering, sound playback, and world block/entity
mutation remain with their existing owners.

Last updated: 2026-10-29 (Session 411, Milestone 504)

Milestone 504 adds Wither Skeleton attributes and the Wither I debuff in
`src/world/wither_skeleton_effect.zig`: 2.4m height, 20 HP, 3.6m/s sprint,
stone sword, fire/lava immunity, 5/8/12 HP difficulty hits, 200-tick Wither I
with black hearts and lethal 1 HP/40-tick drain, milk cleansing, 2.5% base
skull drops with Looting scaling, charged Creeper guaranteed skull, bones/coal,
and 5 XP (35 focused tests). Runtime mob attributes, player debuff timing,
milk use, Wither HUD color, and the coordinate-stable base skull chance were
aligned with those values.

Charged Creeper attribution and Looting-aware runtime kill plumbing remain
represented by the standalone domain API; the current game loop does not yet
provide those kill-context/enchantment inputs.

Last updated: 2026-10-29 (Session 410, Milestone 501)

Milestone 501 adds the standalone Blaze artillery domain in
`src/world/blaze_fireball_artillery.zig`: 20 HP fire/lava immunity, water and
rain damage, altitude holding and twelve rotating rods with smoke/flame
particles, a 60-tick charge and three fireballs six ticks apart, five-second
target ignition, 100-tick volley cooldown, blaze rod/Looting drops, XP, and
fortress spawner activation data (41 focused tests).

Last updated: 2026-10-29 (Session 409, Milestone 500)

Last updated: 2026-10-29 (Session 410, Phase 8: Milestones 491–500)

Wave 22 integration completes Milestones 491–500. All ten domain modules are
registered once as standalone tests, imported into `main.zig`, and queried each
frame. ItemTypes 608–617 define the Wave 22 materials with RGBA colors, display
names, stack limits, and six 2x2 recipes. `BlockId` remains within its 8-bit
capacity. Verification passes 10,278 tests across 551 build/test steps.

Milestone 500 adds a 200 HP Ender Dragon arena fight with four combat phases, fireballs and breath, 10-crystal healing tethers, perch projectile immunity, a 200-tick death sequence, 12,000 XP reward, and central End portal/Dragon Egg activation data in `src/world/ender_dragon_arena_fight.zig` (44 focused tests). The module is registered as a standalone test target and advanced at 20 ticks per second from the frame loop; it returns events for world rendering and block mutation owners.

Last updated: 2026-10-29 (Session 408, Milestone 498)

Milestone 498 adds 1- and 4-redstone-tick factory clocks, rising-edge iron-block crafting with a 4-game-tick minimum delay, enabled-slot round-robin hopper feed with backpressure, comparator fullness, and an ore-to-ingot-to-block throughput simulator in `src/world/crafter_factory_clocking.zig` (37 focused tests).

Milestone 492 adds standalone 3D radius-8 sculk bloom propagation, charge-limited substrate conversion, exposed-face vein masks, 85/15 branch rolls, and a 20-tick light state in `src/world/sculk_bloom_geometry.zig` (38 focused tests).

Last updated: 2026-10-29 (Session 404)

Wave 21 integration completes Milestones 481–490. The ten domain modules are
registered as standalone tests, imported and queried from the frame loop, and
represented by ItemTypes 596–605 with six 2x2 recipes. `gold_ingot` is added
as an ingredient item (606), since it was not previously declared. `BlockId`
capacity remains at 255.

Last updated: 2026-10-29 (Session 390)

## What Works
- Standalone sea turtle lifecycle rules: seagrass breeding, home-beach egg laying/incubation, baby maturation scute drops, five-scute helmet recipe matching, and water-breathing refresh logic (29 focused tests)
- Zig 0.16.0 build system (`zig build`, `zig build run`, `zig build test`) with 10,278 passing unit tests across 551 build/test steps
- Window creation, input handling, OpenGL 3.3 Core Profile context via GLFW
- Procedural sky dome with day/night orbital lighting and dynamic twilight
- First-person camera with mouse look, sprint, jumping, and ladder climbing
- Axis-aligned bounding box (AABB) collision and voxel step snapping
- Suffocation damage mechanics (when player eye position is inside solid blocks)
- Player fall damage on hard landings
- Environmental hazards: Cactus contact damage (1 hp/sec), campfire burn (2 hp/sec), lava contact burn (8 hp/sec), water-lava contact crystallization (obsidian / cobblestone), ambient lava bubbling sound & ember smoke emission, Nether portal frame detection & activation, portal transit charge (3s) with orbital vortex particle ring (1.0 -> 0.7m radius), camera roll disorientation wobble, purple portal HUD vignette overlay, dimensional warp exit flash overlay, Nether ambient ash & cinder flake particles, Nether ambient distance fog shader and cavernous sky palette, synthesized Nether subterranean ambient wind & drone audio, Nether glowstone stalactites & magma fissure generation, Nether glowstone dynamic warm ambient point light spill, luminous glowstone shimmer & sparkling dust particles, synthesized crystalline glowstone chime audio with 3D attenuation, Nether quartz ore veins & crystalline quartz drops, Block of Quartz crafting & architectural masonry, Quartz Pillars & Chiseled Quartz Blocks, Nether Bricks crafting & fortress masonry, procedural Nether Fortress ruin bridges & pillars, Nether Brick Fence thin-post railings with transparent cutouts + vertical crafting recipe, farmable Nether wart crop (soul-sand planting, 60s ripening, mature bonus, wild shore patches), fire-immune Emberbeast fortress hunter with roar audio and 2x bite damage, wart + vial potion brewing, fortress junction loot chests (wart/quartz/iron), emberbeast fireball ranged attack with flame trail, potion resist, and flammable-floor ignition, loot-chest emberbeast guard ambush, ignited flame 45s burnout, fortress spawner reinforcement pulse, emberbeast coal/wart kill loot, fortress compass readout + live HUD needle, magma cream crafting and potion brewing, throwable fire charges (2-dmg mob hit + ignition + TNT priming), Soul Torches with 0.7 emissive cyan glow and soul-sand crafting, Fortress Bridge ambient soul torches on fence balustrades, Soul Campfire with 0.8 emissive cyan embers and crafting, Soul sand fireball ignition into soul campfires, Monster Spawner Cage block with iron grating and fortress junction alcove placement, Spawner cage mob wave anchoring (16m activation radius), spinning ember particles on active cages, wither skeleton fortress hunter (10 HP, 1.5x bite, fire-immune, hunt AI, spawner waves), wither bite status effect (8s poison 1 HP/s with dark purple HUD bar), 8:1 Overworld/Nether coordinate warp, and synthesized warp audio, Nether dimension world generation, The End dimension procedural generation (radius 40 central End Stone island, colossal obsidian monolith pillars, purple void sky dome, End Portal transit & obsidian spawn platform), Ender Dragon boss encounter (200 HP, 6-box wyrm geometry with flapping wings, synthesized .dragon_roar audio, 3D aerial patrol kinematics, End Crystal healing & defeat drops), Soul sand drag & elevator lift, Magma blocks with contact heat hazard (2 hp/s) and downward water whirlpool vortex drag (-7.0 m/s), Mob bubble column physics with upward soul sand launch (6.5 m/s) and magma whirlpool downward suction (-7.0 m/s), Mob contact heat hazards (magma blocks, campfire, lava dealing 1 hp/s with flinching hop, death removal, and synthesized searing contact burn audio sizzle/hiss, fiery contact spark bursts on magma/campfire stepping, and Fire Resistance Potion buff (180s complete immunity to lava, magma, and campfire burn damage with dynamic amber-gold HUD status indicator bar), Elder Guardian marine boss (80 HP, 7-box pale-ivory geometry with defense spikes and tail fin, 6-damage laser attack, Overworld boss health bar, sponge drop), Mining Fatigue debuff (-70% mining speed, 24m Ocean Monument awakening curse), Sponge and Wet Sponge blocks & items with 3-block spherical water absorption physics, furnace sponge drying, and Ocean Monument apex sponge vault generation, Dolphin marine mob variant with playful swimming animations, 8m Dolphin's Grace proximity swim speed aura, Fishing Rod tool crafting, right-click water line casting, and Raw/Cooked Cod dietary pipeline, Trident Riptide propulsion surge in water with spiraling aquatic vortex VFX and high-speed directional launch, Kelp plant blocks with vertical ladder swimming physics, procedural seafloor kelp forest generation, Dried Kelp rapid food item, and Dried Kelp Block dense fuel packing/unpacking pipeline, and bioluminescent Sea Pickle blocks with underwater radiant lighting and procedural seafloor colonies, Marine Fish species diversity with weighted fishing catch loot tables, Salmon roasting, and toxic Pufferfish Water Breathing potion alchemy, and Nautilus Shell rare fishing treasure & Drowned mob drops powering Conduit crafting, and Rails, Powered Rails, Minecart vehicles, and rail transit acceleration, and procedural subterranean Abandoned Mineshaft corridor generation with rails, timber support arches, and loot chests, and Cave Spider mob variant with venomous poison bites and mineshaft spawner cage nests, and Detector Rails with redstone power emission and Activator Rails with automatic cart passenger ejection, and Chest/Furnace/TNT/Hopper Minecart vehicle variants with track fuse detonation, and Redstone Comparators with compare/subtract modes, container fullness signal measurement, and Recipe 148 crafting pipeline, and Slime mob entities with gelatinous bouncy leaping, Slimeball drops, Slime Blocks with Recipes 149/150, and 80% fall impact rebound bounce kinematics, and Pistons & Sticky Pistons with 12-block linear displacement push/retract kinematics and Recipes 151/152, and Observer blocks with block update detection, 0.10s pulse emission, and Recipe 153 crafting, and Wooden & Iron Trapdoors with physical interaction, redstone actuation, and Recipes 154/155, and Block of Redstone permanent power source with bidirectional packing Recipes 156/157, and Redstone Ore subterranean veins with dynamic luminescent activation and 4-dust drops, and Tripwire line blocks with hook tension circuit scanning and string placement, and Gold Ore subterranean veins and Block of Gold packing Recipes 158/159, and Diamond gemstone, Diamond Ore subterranean veins, and Block of Diamond packing Recipes 160/161, and Diamond Sword and Diamond Pickaxe tool crafting Recipes 162/163 with tiered combat and harvesting, and Diamond Armor suit crafting Recipes 164-167 with 40%/65% defense absorption and Netherite upgrade pipeline, and Flint and Flint and Steel fire starter tool crafting Recipes 168/169 with ignition durability wear, and Wooden/Iron/Diamond/Netherite Axe tool crafting Recipes 170-173 with 3.0x-6.0x woodchopping acceleration, and Wooden/Iron/Diamond/Netherite Shovel tool crafting Recipes 174-177 with 3.0x-6.0x soil excavation speed, and Wooden/Iron/Diamond/Netherite Hoe tool crafting Recipes 178-181 with 3.0x-6.0x foliage harvesting speed, and Shears tool crafting Recipe 182 with 15x cobweb cutting, sheep wool shearing, dynamic shorn rendering, and synthesized .shears_snip audio, and Iron Armor suit crafting Recipes 183-186 with 25%/50% defense absorption and Diamond upgrade pipeline, and Golden Armor suit crafting Recipes 187-190 with 15%/35% defense absorption and Piglin pacification aura, and Stone Tool arsenal crafting Recipes 191-195 with 3.5x mining multipliers and 2-damage Stone Sword, and Golden Tool arsenal Recipes 196-200 with 7.0x ultra-speed harvesting and ItemType u16 expansion, and Wooden Sword, Leather, and Leather Armor suit Recipes 201-206 with 10%/28% defense absorption, and Farmland tilling, Wheat Crop growth, Wheat Seeds, Wheat, and Bread baking Recipes 207-209, and Paper, Book, Bookshelf, and Lectern Recipes 210-213 with Enchantment Table bookshelf power synergy, and Emerald, Emerald Ore, Block of Emerald Recipes 214-215 with 5-profession workstation bartering, and Lapis Lazuli, Lapis Ore/Block, Beehive apiary, Honeycomb, poison-curing Honey Bottle, and Honey Block Recipes 216-220, and Copper Ore/Ingot/Block with 4-stage oxidation, Honeycomb waxing, Axe scraping, Lightning Rod, and Spyglass Recipes 221-225, and Amethyst Geodes, Amethyst Shards, Tinted Glass, and Village Bell mob-highlighting alarm Recipes 226-228, and Campfire 15s fuel-free culinary cooking with Hay Bale signal fires, and Sugar Cane, Sugar, Pumpkin, Carved Pumpkin, Jack o'Lantern, and Pumpkin Pie Recipes 229-232, and Sculk, Sculk Sensor acoustic vibration detection, Echo Shard, and Recovery Compass Recipes 233-234, and Deepslate, Cobbled/Polished Deepslate, and Deepslate Bricks Recipes 235-236, and Block of Iron with Snow/Iron Golem totem summoning Recipes 237-238, and 7-slice Cake feast, Melon, Glistering Melon, Potion of Healing, and Barrel Recipes 239-243, and Pointed Dripstone, Dripstone Block, Lush Caves Moss Block/Carpet, climbable Cave Vines, and Glow Berries Recipes 244-246, and Clay, Clay Ball, Terracotta, Brick item, and Flower Pot Recipes 247-249, and Totem of Undying fatal-damage resurrection, Carrot, Golden Carrot, Potion of Night Vision, Ghast Tear, and Potion of Regeneration Recipes 250-253, and Ice, Packed Ice, Blue Ice, Powder Snow frostbite hazard, Bamboo, and climbable Scaffolding Recipes 254-258, and Potato, Baked Potato, Beetroot Soup, Mushroom Stew, Potions of Swiftness/Strength/Leaping, Cookies, and Sweet Berry Bush Recipes 259-265, and Ender Chest global quantum vault, Beacon pyramid Haste/Regeneration aura, Chainmail Armor suit (20%/42% absorption), Mud/Packed Mud/Mud Bricks, Copper Bulb T-flip-flop, Chiseled Copper, Copper Grate, Archaeology Brush, Suspicious Sand, Pottery Sherds, and Decorated Pot Recipes 266-278, and Breeze Rod, Wind Charge rocket-jump & radial knockback, Heavy Core, Mace smash-attack weapon, Crafter block, Trial Spawner, Trial Key, Vault treasure dispensing, Enchanted Golden Apple, Suspicious Stew, and Tuff/Polished Tuff/Tuff Bricks/Chiseled Tuff Recipes 279-286, and Calibrated Sculk Sensor frequency filtering, Ochre/Verdant/Pearlescent Froglights, Mangrove wood/roots/propagules, triumphant Goat Horn acoustics, Armor Trim templates, and Torchflower/Pitcher Plant paleobotany Recipes 287-290, and Cherry Grove biome with cherry wood family/pink petals/saplings, Chiseled Bookshelf 6-slot storage with face UV targeting & comparator output, Hanging Signs with dual-sided text/dye/waxing/chain mounts & Bamboo Mosaic woodworking, Desert Camel mount with dash charge/posture state machine/2-block ravine stride, Decorated Pot 4-facet sherd assembly with single-stack storage/wobble animation/shattering, and Pale Garden with Creaking Heart nocturnal puppet link/gaze-freeze AI/eyeblossom day-night resonance/resin masonry Recipes 291-296, and Armadillo roll-up defense, scute brushing & dyable wolf armor, Bogged swamp skeleton, Ominous Bottle, Trial Omen & Ominous Spawner/Vault with Recipes 298-299, Tricky Trials Alchemy Potions of Infested/Oozing/Weaving/Wind-Charged with Recipe 300, Bundles of Bravery with 64-weight math/scroll selection/16 dye colors with Recipe 301, Copper Doors & Trapdoors with hand/redstone/wind-charge toggle, oxidation parity & waxing with Recipes 302-303, and Jukebox Music Discs 1..15 comparator outputs, Disc 5 fragment assembly Recipe 304 & Allay duplication dance)
- Procedural audio synthesizer via ALSA with 3D spatial attenuation & distance rolloff: footsteps (grass, stone, wood, dirt, sand), block break/place, mob sounds
- 16x16x16 chunk data structures, greedy mesher with Ambient Occlusion (AO)
- Dynamic chunk streaming manager (load/unload radius around player) with frustum culling
- Chunk disk persistence (binary chunk files) with atomic replacement and write failure retention
- Block picking via fast DDA voxel raycasting and wireframe selection highlight
- Particle engine: 3D block-break physics debris, smoke puffs, spark/debris for levers, water splashes for falling sand
- Rich block palette (Air, Stone, Dirt, Grass, Water, Wood, Leaves, Cobblestone, Coal Ore, Iron Ore, Sand, Glass, Sandstone, Bricks, Snow, Torch, Chest, TNT, Ladders, Doors, Crafting Table, Furnace, Bed, Saplings, End Stone, End Portal Frame, End Portal, End Crystal, Dragon Egg, Purpur Block, Purpur Pillar, End Rod, Chorus Plant, Chorus Flower, Shulker Box)
- Redstone logic: Wire transmission with 15-block falloff, torches (NOT inverter with 30s burnout recovery), repeaters (1-4 tick delays), levers, pressure plates, lamps with night glow, iron doors
- Falling sand physics: unsupported sand drops, crushes non-solid cells, inflicts falling damage, splashes into water
- Fluid interactions: water washes floor redstone, torches, repeaters, dropping items into player inventory (helpers in `src/world/fluid_wash.zig`, redstone caches in `src/world/component_cache.zig`)
- Water spread: spreads over solid floors and ledges; staged ticks prevent scan-order cascades
- Mob system: wandering Sheep, Pigs (oink + meat drops), and hostile Wolves with tracking/attack AI
- 24-slot inventory, hotbar HUD, 2x2 crafting grid, chest storage containers, tool mining speed & durability system
- HUD toast warning queue for system notifications (cap overflows, redstone burnout)

## Wave 3 Integration
- Milestones 305–314 are integrated on `main`: Happy Ghast, Warden Deep Dark, Strider, Axolotl, Banner Heraldry, Anvil/Smithing, Copper Golem, Ambient Foliage, Ender Stasis, and Minecart Logistics.
- Representative Wave 3 blocks occupy BlockIds 251–255; corresponding ItemTypes 430–439 include block roundtrips, names/colors, stack properties, and 2x2 recipes.
- Each new world module has a standalone build test target and is ticked or queried from the main game loop through its domain state hook.

## Wave 4 Integration
- Milestones 315–322 are integrated on `main`: Enchanting/Grindstone, Village Raids, Redstone Workstations, Shulkers/End Cities, Elytra Aerodynamics, Sea Turtles, Taiga Foxes, and Conduit Frame.
- The eight modules have standalone test targets. Main owns and advances the applicable mechanic states through its frame loop; deterministic rules remain in their domain modules.
- ItemTypes 440–447 provide representative enchanted book, raid, turtle, potion, and fox-treat items with names, colors, stack rules, and three 2x2 recipes. `BlockId` remains unchanged.

## Wave 5 Integration
- Milestones 323–330 are integrated on `main`: Enderman AI, Piglin Bastion, Charged Creeper, Swamp Witch, Blaze Fortress, Ghast Deflection, Slime Mitosis, and Phantom Insomnia.
- All eight modules have standalone build/test targets; `main.zig` imports and advances representative states or queries domain rules.
- ItemTypes 448–455 add four mob-head trophies and water/harming bottle variants with names, colors, stack rules, and two 2x2 splash-potion recipes. `BlockId` remains unchanged.

## Wave 6 Integration
- Milestones 331–340 are integrated on `main`: Wither Boss, Ender Dragon Fight, Villager Curing, Piston Adhesion, Fishing Treasure, Shield/Thorns Combat, Trident Enchantments, Dimensional Anchors, Precision Redstone Sensors, and Snow Golem AI.
- All ten world modules have standalone build/test targets and are imported into `main.zig`, where stateful timers and representative domain/interaction hooks are advanced or queried.
- ItemTypes 456–461 add Wither Rose, Glazed Terracotta, Name Tag, Saddle, and Light/Heavy Weighted Pressure Plates with metadata and 2x2 recipes for glazed terracotta and weighted plates. `BlockId` remains unchanged at 255.

## Wave 7 Integration
- Milestones 341–350 are integrated on `main`: Allay Collector, Note Block Instruments, Equine Genetics, Companion Pets, Panda Genetics, Dolphin Navigation, Bee Pollination, Cartography Maps, Processing Workstations, and Boots/Armor Stands.
- All ten world modules have standalone test targets and are imported by `main.zig`; representative transient state is ticked and deterministic mechanics are queried through the frame loop.
- ItemTypes 462–469 add locator/explorer maps, glass panes, four horse armor types, and Frost Walker Boots with names, colors, and stack limits. The 2x2 crafting grid supports locator-map creation, explorer-map duplication, and glass panes. `BlockId` remains unchanged at 255.

## Wave 8 Integration
- Milestones 351–360 are integrated on `main`: Woodland Mansion Illagers, Ocean Monument Guardians, Ancient City, Temple Traps, Stronghold Triangulation, Mushroom Fields, Weather/Lightning, Hunger Metabolism, Experience Orbs, and Melee Sweep/Critical Combat.
- All ten modules have standalone build/test targets and are imported in `main.zig`, which advances representative state and queries each module's domain rules in the frame loop.
- ItemTypes 470–474 add Swift Sneak Book, Reinforced Deepslate, Milk Bucket, Bottle o' Enchanting, and Sweeping Edge Book with names, colors, and stack limits. Two 2x2 book recipes are covered by inventory tests; `BlockId` remains unchanged at 255.

## Wave 9 Integration
- Milestones 361–370 are integrated on `main`: Skeleton Variants, Zombie Conversions, Arachnids, Mountain Goats, Hoglins/Zoglins, Ranged Enchantments, Item Frames/Paintings, Armor Toughness/EPF, Hopper Item Sorters, and Beacon Pyramids.
- All ten modules have standalone test targets and representative frame-loop hooks in `main.zig`; transient state is advanced where applicable, while entity/world mutation remains owned by the consuming systems.
- ItemTypes 475–480 cover Slowness Arrows, Item Frames, Glow Item Frames, Paintings, Feather Falling Books, and Stained Glass. ItemType 481 adds the Slowness Potion ingredient for the arrow recipe. Metadata and six 2x2 crafting recipes are tested; `BlockId` remains unchanged at 255.
- Zombie underwater conversion uses a small floating-point tolerance at the 45-second threshold to avoid missing a conversion due to accumulated `f32` rounding.

## Wave 10 Integration
- Milestones 371–380 are integrated on `main`: Badlands Mesa, Concrete & Masonry, Snowy Plains & Igloo Laboratory, Jungle Canopy Ecology, Savanna & Acacia Mechanics, Dark Forest Canopy, Shipwreck & Buried Treasure, Nether Biomes & Basalt Generator, Firework Pyrotechnics, and Cauldron Fluid Mechanics.
- All ten modules have standalone build/test targets and representative frame-loop hooks in `main.zig`; domain rules and transient state are queried or advanced each tick without altering block/entity ownership boundaries.
- ItemTypes 482–489 cover Red Sandstone, Concrete Powder, Concrete, Buried Treasure Map, Heart of the Sea (relocated to 486 with 64-stack limit), Firework Star, Acacia Planks, and Dark Oak Planks. Metadata, colors, stack sizes, and seven 2x2 recipes are covered by unit tests; `BlockId` remains unchanged at 255.

## Wave 11 Integration
- Milestones 381–390 are integrated on `main`: Bastion Remnants, Ruined Portals, Pillager Outpost, Ocean Ruins & Sniffer Eggs, Trail Ruins & Archaeology, Netherite Metallurgy & Ancient Debris, Coral Reef Ecosystem, Ice Spikes Biome, Swamp Marsh & Frog Ecology, and Book & Quill & Lectern Mechanics.
- All ten world modules have standalone test targets in `build.zig` and representative frame-loop hooks in `main.zig`, where domain mechanics and state queries are advanced each frame without perturbing entity/world boundaries.
- ItemTypes 490–500 cover Music Disc Pigstep, Netherite Upgrade Template, Sniffer Egg, Suspicious Gravel, Coral Block, Dead Coral Block, Lily Pad, Frogspawn, Bucket of Tadpole, Book and Quill, and Written Book. Metadata, colors, stack limits (stack 1 for discs, tadpole buckets, and book & quill; stack 16 for written books; stack 64 for others), and six 2x2 recipes are covered by unit tests; `BlockId` remains unchanged at 255.

## Wave 12 Integration
- Milestones 391–400 are integrated on `main`: Outer End Islands, Subterranean Fossils, Amethyst Geode Budding, Azalea Lush Ecology, Brewing Stand Alchemy, Fletching & Tipped Arrows, Scaffolding & Bamboo, Navigation Timepieces, Villager Professions, and Wandering Trader.
- All ten Wave 12 world modules have standalone test targets in `build.zig` and representative frame-loop hooks in `main.zig`; deterministic domain logic remains in the modules.
- ItemTypes 501–510 cover Bone Block, Calcite, Smooth Basalt, Rooted Dirt, Hanging Roots, Big Dripleaf, Spore Blossom, Awkward Potion, Potion of Invisibility, and Clock. Metadata and six 2x2 recipes are covered; `BlockId` remains unchanged at 255.

## Active State
- Main branch stable (Phase 8: Milestones 491–500)
- All tests passing (10,278/10,278 tests across 551 build/test steps)
- Remote and local branches pruned clean


## Wave 13 Integration
- Milestones 401–410 are integrated on `main`: Flower Forest & Plains, Mountain Peaks & Ores, Old-Growth Taiga, Birch Forest, Dispenser & Dropper Automation, Rail Network Switching, End Crystal Mechanics, Boat Watercraft, Lead & Leash Mechanics, and Bed Sleep Mechanics.
- All ten Wave 13 world modules have standalone test targets in `build.zig`, imports and lightweight representative frame-loop hooks in `main.zig`.
- ItemTypes 511–521 add flowers, terrain/wood materials, chest boat, bamboo raft, and bed with names, RGBA colors, stack limits, and six 2x2 recipes. `BlockId` remains unchanged at 255.


## Wave 14 Integration
- Milestones 411–420 are integrated on `main`: Igneous Stone Masonry, Glazed Terracotta Mosaic, Lighting Fixtures, Wooden Signs, Fences/Gates/Walls, Doors/Trapdoors/Crawl, Sculk Growth/Harvest, Anvil Repair, Loom/Shield Banners, and TNT Demolition Physics.
- All ten Wave 14 world modules have standalone test targets in `build.zig`, imports, and lightweight representative frame-loop hooks in `main.zig`.
- ItemTypes 522–532 add igneous stones, polished masonry, wooden signs, glow ink, fence gates, cobblestone walls, and sculk veins with metadata and six 2x2 recipes. `BlockId` remains unchanged at 255.


## Wave 15 Integration
- Milestones 421–430 are integrated on `main`: Chunk Loader Tickets, Redstone Torch Inverter, Regional Difficulty & Moon Phase, Iron Golem Spawning, Mob Despawn Spheres, Redstone Repeater Latch, Dropped Item Physics, Flying Machine Kinematics, Zombie Reinforcements & Siege, and Entity Cramming.
- All ten Wave 15 world modules have standalone test targets in `build.zig`, imports, and lightweight representative frame-loop hooks in `main.zig`.
- ItemTypes 533–542 add chunk loader token, redstone inverter core, moon phase talisman, iron golem effigy, mob despawn ward, repeater latch lock, dropped item magnet, flying machine core, zombie siege banner, and cramming disperser with metadata and six 2x2 recipes. `BlockId` remains unchanged at 255.

## Wave 16 Integration
- Milestones 431–440 are integrated on `main`: Target Block Projectile Detection, Lightning Redstone Deflection, Frost Walker Ice Crystallization, Soul Speed Kinematics, Swift Sneak Crouch Kinematics, Respawn Anchor Charge & Nether Spawning, Lodestone Compass Tracking, Composter Biofuel & Bone Meal Pipeline, Specialized Furnace Smelting, and Tripwire Hook Circuit.
- All ten Wave 16 world modules have standalone test targets in `build.zig`, imports, and lightweight representative frame-loop hooks in `main.zig`.
- ItemTypes 543–552 add target block core, lightning deflector, frosted ice shard, soul speed talisman, swift sneak boots trim, respawn anchor shard, lodestone tracker, composter catalyst, pyrometallurgy nozzle, and tripwire tension gauge with metadata and six 2x2 recipes. `BlockId` remains unchanged at 255.

## Wave 17 Integration
- Milestones 441–450 are integrated: Sculk Catalyst Bloom, Sculk Shrieker Warning, Calibrated Sculk Resonance, Chiseled Bookshelf Storage, Hanging Sign Mechanics, Camel Mount Kinematics, Decorated Pot Storage, Creaking Heart Puppet, Creaking Gaze AI, and Resin Masonry.
- All ten Wave 17 modules have standalone test targets and are imported in `main.zig`; the frame loop queries representative domain rules while existing world/entity systems retain mutation ownership.
- ItemTypes 553–562 add sculk bloom catalyst, shrieker alarm core, calibrated sensor tuner, chiseled bookshelf slot, hanging chain mount, camel bridle saddle, decorated pot motif, creaking heart core, eyeblossom resin bloom, and resin brick masonry. Their RGBA metadata, stack limits, and six 2x2 recipes are tested; `wooden_slab` and `stone_bricks` are ingredient ItemTypes 563–564. `BlockId` remains capped at 255.

## Wave 18 Integration
- Milestones 451–460 are integrated: Sniffer Digging & Ancient Flora, Trial Spawner Dynamics, Vault Loot Dispenser, Breeze & Wind Charge, Mace Smash Kinematics, Crafter Automation, Copper Bulb Latch, Trial Chamber Generation, Ominous Bottle & Trial Omen, and Bogged & Stray Variants.
- All ten modules are registered once as standalone test targets in `build.zig`, imported in `main.zig`, and queried through representative frame-loop hooks. Existing world/entity systems retain mutation ownership.
- ItemTypes 565–574 add the ten Wave 18 materials with display names, RGBA colors, stack limits, and six 2x2 recipes. Metadata and recipes are covered by an inventory unit test; `BlockId` remains capped at 255.
- Verification: `zig build` passes; `zig build test --summary all` passes 8407/8407 tests across 471 build/test steps.

## Wave 19 Integration
- Milestones 461–470 are integrated: Armadillo Rolling Defense & Wolf Armor, Allay Amethyst Duplication & Jukebox Dance, Froglight Bio-Luminescence & Predation, Goat Horn Resonance & Screamer Call Acoustics, Sculk Sensor Multiplexing & Vibration Occlusion, Deepslate Mineralogy & Blast Containment, Mangrove Prop Roots & Mud Architecture, Warden Agitation & Sonic Boom, Recovery Compass Echo Shard Metallurgy, and Archaeology Brush & Excavation.
- All ten modules are registered as standalone test targets in `build.zig`, imported in `main.zig`, and queried through representative per-frame domain hooks. World and entity mutation ownership remains with existing systems.
- ItemTypes 575–584 add the ten Wave 19 materials (Armadillo Scute Core, Allay Amethyst Resonator, Froglight Catalyst, Screamer Goat Horn, Sculk Multiplexer Node, Reinforced Deepslate Core, Mud Brick Masonry, Warden Sonic Core, Recovery Compass Talisman, and Archaeology Brush Relic) alongside Glowstone Dust (585). Their display names, RGBA colors, stack limits, and six 2x2 crafting recipes are covered by unit tests; `BlockId` capacity is preserved (<= 255).
- Disambiguation: Single Echo Shard + Compass crafts `recovery_compass_talisman` in 2x2 crafting; multiple Echo Shards (count >= 2) preserve legacy Recipe 234 `recovery_compass`, matching the Wave 17 calibrated sensor precedent.
- Verification: `zig build` passes; `zig build test --summary all` passes 8911/8911 tests across 491 build/test steps.

## Wave 20 Integration
- Milestones 471–480 are integrated: Trial Chamber Traps & Ominous Spawner, Bundle Dyeing, Nesting & Cauldron Washing, Netherite Smithing Pipeline & Lava Buoyancy, Shulker Bullet Guided Tracking & Levitation, Elytra Kinetic Glide & Firework Rocket Propulsion, Riptide Trident Water/Rain Surge & Kinetic Impact, Skeleton Trap Lightning Summoning & Four Horsemen Combat, Witch Potion Throwing AI & Raid Healing Mechanics, Evoker Fangs & Vex Phasing Kinematics, and Totem of Undying Resurrection & Visual Animation.
- All ten modules are registered as standalone test targets in `build.zig`, imported in `main.zig`, and queried through representative per-frame domain hooks. World and entity mutation ownership remains with existing systems.
- ItemTypes 586–595 add the ten Wave 20 materials (Ominous Trap Core, Dyed Bundle Package, Netherite Smithing Core, Shulker Levitation Orb, Elytra Propulsion Core, Riptide Vortex Shard, Four Horsemen Crest, Witch Brewing Cauldron, Evoker Fangs Talisman, and Totem Resurrection Effigy). Their display names, RGBA colors, stack limits, and six 2x2 crafting recipes are covered by unit tests; `BlockId` capacity is preserved (<= 255).
- Disambiguation: Single String + Leather (count = 1) crafts `dyed_bundle_package` in 2x2 crafting; multiple Leather (count >= 2) preserves legacy Recipe 301 `bundle`, matching the Wave 17 calibrated sensor and Wave 19 recovery compass precedents.
- Verification: `zig build` passes; `zig build test --summary all` passes 9349/9349 tests across 511 build/test steps.

## Wave 21 Integration (Milestones 481–490)
- Integrated Piglin barter and Bastion defense, Zombified Piglin swarm alarms, Strider lava mounting, Nether fungus forest growth, Hoglin repellent behavior, lead tension physics, fox berry predation, turtle scute and helmet rules, and panda genetics variants.
- All ten modules are registered once in `build.zig`, imported by `main.zig`, and queried through representative frame-loop hooks; entity and world mutation remains with their existing owners.
- ItemTypes 596–605 define the ten requested materials with display names, RGBA colors, and configured stack limits. Six 2x2 recipes create the barter token, brute armband, strider harness, fungus spores, reinforced lead, and berry basket. The test checks IDs, stack sizes, names, color channels, recipe outputs, and `BlockId` capacity.
- `gold_ingot` did not exist in `ItemType`; it is now declared as ingredient ID 606 with normal stack behavior, name, and color.
- Verification: `ZIG_GLOBAL_CACHE_DIR=/tmp/zig-cache ZIG_LOCAL_CACHE_DIR=/tmp/zig-local-cache zig build` passes; `ZIG_GLOBAL_CACHE_DIR=/tmp/zig-cache ZIG_LOCAL_CACHE_DIR=/tmp/zig-local-cache zig build test --summary all` passes 9727/9727 tests across 531 build/test steps.

## Wave 22 Integration (Milestones 491–500)
- Integrated copper horn acoustics, sculk bloom geometry, camel dash movement, bookshelf secret latches, brushing particles, trial vault reset rules, mace aerial combos, crafter factory clocking, copper bulb display decoding, and the Ender Dragon arena fight.
- All ten modules are registered once for standalone tests and queried from the frame loop. The copper bulb display was the only domain missing its import and query; the other nine already had representative hooks.
- ItemTypes 608–617 add Copper Horn Instrument, Sculk Bloom Core, Camel Dash Saddle, Secret Bookshelf Mechanism, Brush Plume Fiber, Vault Reset Token, Mace Combo Catalyst, Factory Clock Regulator, Copper Bulb Display Module, and Dragon Fountain Essence. Inventory metadata defines names, RGBA colors, and stack limits; six 2x2 recipes are covered by the Wave 22 inventory test. `BlockId` remains capped at 255.
- `ZIG_GLOBAL_CACHE_DIR=/tmp/zig-cache ZIG_LOCAL_CACHE_DIR=/tmp/zig-local-cache zig build` passes; `zig build test --summary all` passes 10,278/10,278 tests across 551 build/test steps.

## Milestone 471 — Trial Chambers Spawner Ominous Potion Spawning & Projectile Traps
- Added standalone `src/world/trial_chamber_traps.zig` with 8-second (160 ticks) ambient hazard timer, random hazard selection (ceiling projectile drop vs lingering cloud 3-5 blocks above player head), 6 lingering potion payload types (poison, slowness, weaving, oozing, infested, wind_charged), cloud physical dynamics (3.0m radius, -0.5m shrink per affliction, 600 ticks / 30s timeout, spherical affliction), ceiling downward projectile ejection ([3]f32{0.0, -0.6, 0.0}), 3.5m wind charge burst with copper door/trapdoor toggling and knockback, and fire charge ground ignition.
- Registered in `build.zig` for isolated tests.
- Verification: `zig test src/world/trial_chamber_traps.zig` passes 37/37; `zig build test` passes.

## Milestone 475 — Elytra Kinetic Glide & Firework Rocket Propulsion
- Added standalone `src/world/elytra_rocket_propulsion.zig` implementing Elytra flight kinematics state machine (`.grounded`, `.falling`, `.gliding`, `.kinetic_impact`), dive/climb aerodynamics (`v_horiz += -0.08 * sin(theta)`, `vy += 0.06 * sin(theta) - gravity`, 0.99 drag decay), Firework Rocket propulsion boost (1.5 m/s^2 forward acceleration along look vector, flight duration tiers 1–3, 5.0 HP firework star explosion hazard), kinetic wall crash collision damage (`(v - 10.0) * 2.0`), durability wear (1/s, broken state at 1 point), and Anvil Phantom Membrane restoration (+108/membrane).
- Registered in `build.zig` test runner.
- Verification: 35/35 tests in `src/world/elytra_rocket_propulsion.zig` passed; `zig build test` passed cleanly.

## Milestone 476 — Riptide Trident Water/Rain Kinematics & Kinetic Impact
- Added standalone `src/world/riptide_trident_kinematics.zig` implementing Riptide Level I-III activation prerequisites (submerged in still/flowing/bubble water or exposed to rain/thunderstorm under open sky, rejection in dry air or indoor rain shelter), mutual exclusivity with Loyalty and Channeling, charge kinematics (10 ticks / 0.5s minimum threshold, 20 ticks full charge), directional launch velocity along camera look vector (`6.0 + 3.0 * level m/s`: 9.0, 12.0, 15.0 m/s), spinning hydrodynamic vortex animation (`is_spinning = true`, 20 ticks duration), swirling bubble and splash particle generation, kinetic collision damage (9.0 HP base melee + `speed * 0.5` kinetic velocity scaling), radial AOE splash damage (9.0 HP) to hostile mobs within 2.0m radius, outward radial knockback impulse, fall damage mitigation (`fall_distance = 0.0` at launch), and durability consumption (1 point per launch).
- Registered in `build.zig` test runner.
- Verification: 49/49 tests in `src/world/riptide_trident_kinematics.zig` passed; `zig build test` passed cleanly.

## Milestone 477 Integration
- Skeleton Trap Horse & Four Horsemen combat mechanics (`src/world/skeleton_trap_combat.zig`):
  - Natural lightning strike spawn evaluation (0.75% to 7.5% probability scaled by regional difficulty).
  - Peaceful passive wandering skeleton trap horse entity with 15-minute (18,000-tick) unengaged despawn timer.
  - Proximity trigger at 10.0m Euclidean distance triggering zero-damage cosmetic lightning and summoning `TheFourHorsemen`.
  - Four mounted Skeleton Horsemen with 20.0 HP riders and 53.0 HP horses.
  - Rider equipment: Enchanted Iron Helmet (prevents daylight fire) and Enchanted Bow.
  - 60-tick (3.0s) initial summon damage immunity window.
  - Mounted archer kinematics AI: closes distance if > 16.0m, kites away if < 8.0m, circles tangentially between 8.0m and 16.0m while firing arrows.
  - Separate entity destruction: horse defeat dismounts rider to fight on foot; rider defeat pacifies skeleton horse into a tameable, rideable mount (12.0 m/s sprint, 3.5m jump, underwater traversal).

## Milestone 478 — Witch Potion Throwing AI & Raid Healing Mechanics
- Added standalone `src/world/witch_potion_combat.zig` implementing Witch combat AI attributes (26.0 HP max health, 85% magic damage resistance, complete poison immunity), defensive self-drinking state machine (32-tick / 1.6s drinking animation pausing movement; priority: fire -> Fire Resistance 3 min, drowning -> Water Breathing 3 min, low health < 11.0 HP -> Healing I +4.0 HP, far target > 11.0m -> Swiftness I +20% speed 3 min), offensive splash potion projectile selection (40-tick / 2.0s cooldown, 10.0m throw range; priority: <= 8.0m and not slowed -> Slowness I, health >= 8.0 HP and not poisoned -> Poison I, < 3.0m close combat 25% chance -> Weakness I, < 8.0 HP -> Harming I 6.0 direct magic damage), village raid medic healing behavior (scans wounded allies within 10.0m at < 80% HP, throws Splash Healing I / Regeneration I at cluster centroid restoring all allies in 3.0m splash radius), and defeat drops (0–2 of glass bottles, glowstone dust, redstone dust, gunpowder, sugar, spider eyes, sticks scaled by Looting; guaranteed drop of consumed potion if killed while drinking).
- Registered in `build.zig` test runner.
- Verification: 38/38 tests in `src/world/witch_potion_combat.zig` passed; `zig build test` passed cleanly.

## Milestone 479 — Evoker Vex Summoning & Fangs Attack Kinematics
- Added standalone `src/world/evoker_fangs_vex.zig` implementing Evoker entity attributes (24.0 HP / 12 hearts), spellcasting state machine (`SpellType.none`, `.fangs`, `.vex`, `.wololo`), arm-raising casting animations with spell particle swirls (dark purple `spell_mob` for fangs, pure white for vex, orange-yellow for wololo), AI spell selection and 3.0m fleeing behavior.
- Implemented Evoker Fangs formations: Offensive Line (16 fangs extending up to 20 blocks with 1.25m spacing and sequential 1-tick activation stagger) and Defensive Circle (2 concentric rings of 8 inner fangs at radius 1.5m and 12 outer fangs at radius 3.0m, totaling 20 fangs when target <= 3.0m).
- Implemented Fang lifecycle: 14 ticks warning emergence, snap phase dealing 6.0 HP unmitigated magic damage bypassing armor and shield blocks completely without shield durability loss, and 20 ticks retraction phase.
- Implemented Vex summoning (2..4 Vexes) with 14.0 HP, Iron Sword damage scaling (9.0 HP on Normal, 13.0 on Hard, 5.0 on Easy), block collision phasing, 8.0 m/s red-glow charge attack, and life decay timer (30..119s / 600..2380 ticks, 1.0 HP/s starvation, immediate decay on summoner death).
- Implemented Wololo sheep color conversion (blue sheep to red sheep within 16.0m).
- Registered in `build.zig` test runner.
- Verification: 55/55 tests in `src/world/evoker_fangs_vex.zig` passed; `zig build test` passed cleanly.

## Milestone 480 — Totem of Undying Resurrection Mechanics & Visual Animation
- Added standalone `src/world/totem_undying_resurrection.zig` implementing complete Totem of Undying death cheat mechanics:
  - Slot check & Hand Priority: evaluates fatal lethal damage (HP <= 0.0); checks offhand slot FIRST, then main hand slot.
  - Item consumption: exactly 1 Totem of Undying (`ItemType.totem_of_undying` / ID 449, or legacy ID 330) is consumed (`is_consumed = true`).
  - Death cancellation: prevents player demise, retains entire inventory without dropping, and preserves all accumulated experience points (`death_cancelled = true`).
  - Immediate health reset: resets player health to exactly 1.0 HP (half a heart).
  - Status Cleansing: immediately cleanses all 9 negative status effects: Poison, Fatal Poison, Wither, Slowness, Weakness, Mining Fatigue, Levitation, Darkness, and Bad Omen, while preserving active positive buffs (Speed, Strength, Haste).
  - Resurrection Buff Suite:
    - **Regeneration II** for 45.0 seconds (900 ticks): restores 0.8 HP/s (0.04 HP/tick, total +36.0 HP recovery, capped at max health).
    - **Absorption II** for 5.0 seconds (100 ticks): adds 4 extra golden absorption hearts (+8.0 absorption HP) that absorb incoming damage before regular health and expire at 100 ticks.
    - **Fire Resistance I** for 40.0 seconds (800 ticks): completely prevents fire and lava damage, preserving any existing longer fire resistance timer.
  - Visual & Audio Resurrection Feedback:
    - Floating Totem Animation: 30-tick (1.5s) screen-filling overlay with golden wings (`[4]f32{ 1.0, 0.84, 0.0, 1.0 }`), emerald eyes (`[4]f32{ 0.1, 0.9, 0.3, 1.0 }`), progress, scaling curve (0.5x to 1.25x peak), fade-out alpha, and wing spread.
    - Particle Burst: emits 32 golden and emerald sparkle ring particles (`TotemParticle`) expanding radially with upward drift and drag decay.
    - Sound Event: emits majestic `SoundEffect.totem_use` chime cue.
  - Void Death Exemption:
    - Void damage (Y < -64.0 in the Void) and `/kill` commands (`DamageType.command_kill`) bypass the Totem of Undying entirely; player perishes, drops inventory, loses experience, and the totem is preserved unconsumed in the inventory.
- Registered in `build.zig` test runner.
- Verification: 45/45 tests in `src/world/totem_undying_resurrection.zig` passed; `zig build test` passed cleanly.

## Milestone 481 — Piglin Bartering & Gold Ingot Economy
- Added standalone `src/world/piglin_bartering_economy.zig` implementing complete Piglin gold pacification, hostility provocation, 120-tick bartering inspection lifecycle, and nether barter loot dispensing:
  - Gold Armor Pacification:
    - Player wearing at least 1 piece of golden armor (golden_helmet, golden_chestplate, golden_leggings, golden_boots) pacifies standard Piglins (`is_pacified = true`, `is_hostile = false`, `is_charging = false`).
    - Players without golden armor leave Piglins hostile (`is_hostile = true`, charges with golden sword or crossbow).
    - Piglin Brutes ignore armor and are never pacified.
  - Hostility Triggers (breaks pacification regardless of golden armor):
    - Attacking any Piglin or Piglin Brute provokes all Piglins within 16 blocks for 600 ticks (30s).
    - Opening guarded containers (chest, trapped chest, shulker box, ender chest, barrel) within 16 blocks breaks pacification.
    - Breaking guarded gold blocks (gold block, gilded blackstone, gold ore, nether gold ore, deepslate gold ore, raw gold block) within 16 blocks breaks pacification.
    - Emits angry sound (`SoundEvent.piglin_angry`) and angry villager particles (`ParticleEvent.angry_villager`).
  - Bartering Interaction & Inspection Phase:
    - Right-clicking Piglin with Gold Ingot (`ItemType.gold_ingot`) or throwing Gold Ingot within 3.5m starts 120 game ticks (6.0 seconds) inspection.
    - While inspecting: Piglin stops moving, holds ingot in hand, and ignores distractions.
    - Non-gold items (iron ingot, diamond, dirt, stone, gold nugget, gold block) are rejected and do not trigger bartering.
    - Hostility during inspection immediately aborts bartering and drops the ingot.
  - Bartering Loot Dispensing:
    - At the completion of 120 ticks: consumes the gold ingot (`consumed_gold_ingot = true`), drops 1 bartered loot item at Piglin position with upward pop velocity (`vy = 0.30`).
    - Emits barter completion sound (`SoundEvent.piglin_barter_complete`) and sparkle particles (`ParticleEvent.barter_sparkle`).
    - Complete 15-entry Nether loot pool with nominal probabilities and count ranges:
      - Soul Speed Enchanted Book (1.09%, count 1)
      - Iron Boots with Soul Speed (1.89%, count 1)
      - Potion of Fire Resistance (2.18%, count 1) / Splash Potion (2.18%, count 1)
      - Ender Pearl (4.36%, count 2..4)
      - Crying Obsidian (8.71%, count 1..3)
      - Obsidian (8.71%, count 1)
      - Fire Charge (8.71%, count 1)
      - Nether Quartz (4.36%, count 5..12)
      - String (4.36%, count 3..9)
      - Magma Cream (4.36%, count 1)
      - Leather (8.71%, count 2..4)
      - Soul Sand (8.71%, count 2..8)
      - Gravel (8.71%, count 8..16)
      - Iron Nugget (2.18%, count 10..36)
    - Baby Piglins confiscate the gold ingot upon inspection completion without dropping loot.
  - Multi-Piglin Bastion Simulation:
    - `PiglinBarterEconomy` simulator managing selective anger radius, broadcasted container and mining triggers, and world-wide loot tick updates.
- Registered in `build.zig` test runner.
- Verification: 45/45 tests in `src/world/piglin_bartering_economy.zig` passed; `zig build test` passed cleanly.

## Milestone 482 — Piglin Brute & Bastion Defense Tactics
- Added standalone `src/world/piglin_brute_bastion.zig` implementing Piglin Brute entity attributes (50.0 HP / 25 hearts, >3x standard piglin health), 13.0 HP Golden Axe heavy blow damage, visual traits (golden arm band, scarred blind eye, two-handed Golden Axe stance), non-respawning Bastion Remnant generation persistence, total gold distraction and pacification immunity (attacks on sight regardless of full gold armor, ignores barter ingots/blocks), 16.0m Bastion defense alarm broadcast breaking nearby standard Piglin pacification, Overworld/End 300-tick zombification, and defeat drops (8.5% Golden Axe scaled by Looting, 20 XP).
- Registered in `build.zig` test runner.
- Verification: 37/37 tests passed cleanly; `zig build test` passed.

## Milestone 483 — Zombified Piglin Neutrality & Group Alarm Swarm
- Added standalone `src/world/zombified_piglin_swarm.zig` implementing complete Zombified Piglin pack behavior and mechanics:
  - Zombified Piglin State Machine: `.neutral`, `.angered`, `.calming` with 20.0 HP max health (10 hearts) and Golden Sword weapon.
  - Natural Neutrality: passively wanders Nether at 3.0 m/s neutral walk speed ignoring players until provoked or struck.
  - 40-Block Group Alarm Swarm Propagation: when provoked, emits piercing screech (`SoundEffect.zombified_piglin_screech`) and broadcasts alarm across a 40.0m Euclidean radius (`SWARM_ALARM_RADIUS = 40.0`). Line-of-sight is NOT required: penetrates solid walls, netherrack, and caves. All alerted piglins enter `.angered` targeting the provoker player and sprint at 4.35 m/s (+45% speed boost).
  - Anger Duration & Calming Cycle: uniformly sampled anger timer between 400 and 799 game ticks (20.0 to 39.95s). Continuous pursuit re-aggro resets timer while player is in line-of-sight within 16.0m Euclidean radius. Upon timer expiration without seeing player, transitions to `.calming` (20 ticks) then `.neutral` (anger forgiven).
  - Undead Fire & Lava Immunity: completely immune to fire, lava, and burning damage (`isImmuneToLava = true`, `isImmuneToFire = true`, `is_undead = true`).
  - Reinforcement Summoning: taking damage has a 10% chance (`REINFORCEMENT_CHANCE = 0.10`) to summon an angered reinforcement piglin within 16 blocks (`REINFORCEMENT_RADIUS = 16.0`).
  - Drops on Defeat: Rotten Flesh (0–1 base, scaled by Looting), Gold Nuggets (0–1 base, scaled by Looting), Golden Sword (8.5% base chance, +1.0% per Looting level), and 5 Experience Points (`EXPERIENCE_POINTS_DROP = 5`).
- Registered in `build.zig` test runner.
- Verification: 44/44 tests in `src/world/zombified_piglin_swarm.zig` passed; `zig build test` passed cleanly.

## Milestone 525 — Trial Spawner Waves & Dynamic Ominous Potion Hazards
- Added standalone `src/world/trial_spawner_waves.zig` implementing:
  - Dynamic player scaling for total mob waves: $N = \lfloor\text{base} \times (1.0 + 0.5 \times (P - 1))\rfloor$.
  - Dynamic player scaling for simultaneous mob cap: $M = \lfloor\text{base} \times (1.0 + 0.5 \times (P - 1))\rfloor$.
  - 14.0m Euclidean radius detection boundary for Survival and Adventure players.
  - Ominous transformation (`is_ominous = true`) triggered by approaching players with the `trial_omen` effect.
  - Ominous mob equipment: Chainmail/Iron armor with Protection I and weapons with Sharpness I.
  - 160-tick (8.0-second) periodic ominous hazard timer dropping lingering potion clouds (Poison, Slowness, Weaving, Oozing, Infested, Wind Charged) or downward projectile drops (Fire Charges, Wind Charges) directly above players.
  - Loot bundle ejection on wave completion with 50% Trial Key and 30% Ominous Key drop probabilities.
  - 30-minute (36,000-tick) cooldown lock venting grey smoke particles.
- Registered in `build.zig` test runner and connected representative frame-loop queries in `src/main.zig`.
- Verification: 47/47 tests in `src/world/trial_spawner_waves.zig` passed; `zig build` and `zig build test` passed cleanly (11,638/11,638 tests).

## Milestone 521 — Warden Scent Tracking & Sonic Blast
- Added standalone `src/world/warden_scent_blast.zig` implementing:
  - 500 HP Warden boss attributes, sniffing animation, smell-based scent suspicion accumulation, and pathing.
  - Horizontal target tracking across dark subterranean biomes.
  - Wall-penetrating 30 HP unmitigated sonic blast attack with 15m knockback impulse.
- Registered in `build.zig` test runner.
- Verification: 37/37 tests passed cleanly; `zig build` and `zig build test` passed.

## Milestone 522 — Sculk Shrieker Warning & Darkness Fog
- Added standalone `src/world/sculk_shrieker_fog.zig` implementing:
  - 4 progressive warning levels (0..3) with 10-second cooldown between trigger shrieks.
  - Darkness pulsing effect inflicting 12-second fog blindness on nearby players.
  - Fourth shriek summoning the Warden within 48 blocks.
- Registered in `build.zig` test runner.
- Verification: 34/34 tests passed cleanly; `zig build` and `zig build test` passed.

## Milestone 523 — Calibrated Sensor Resonance Chains
- Added standalone `src/world/calibrated_sensor_chains.zig` implementing:
  - Rear input redstone signal calibration filtering vibrations to specific frequency (1..15).
  - 16-meter acoustic detection radius (2x standard sensor range).
  - 10-tick active pulse output followed by 1-tick cooldown.
  - Adjacent Amethyst block resonance re-emission creating multi-hop vibration repeaters across 48m+.
- Registered in `build.zig` test runner.
- Verification: 30/30 tests passed cleanly; `zig build` and `zig build test` passed.

## Milestone 524 — Breeze Wind Charge Rocket Jumps & Deflection Dynamics
- Added standalone `src/world/breeze_jump_deflection.zig` implementing:
  - Wind charge projectile consumption and launch kinematics (28.0 m/s).
  - Ground blast radius within 1.5m applying +9.5 m/s vertical self-boost (~5.5 block apex rise).
  - Mid-air fall distance reset on launch and blast detonation.
  - Angle-dependent horizontal dash conversion (up to 7.0 m/s at 45° pitch).
  - Breeze automatic projectile deflection with inverted velocity vector and zero damage.
- Registered in `build.zig` test runner.
- Verification: 37/37 tests passed cleanly; `zig build` and `zig build test` passed.

## Milestone 526 — Mace Smash Attack Height Velocity Scaling & Combos
- Added standalone `src/world/mace_velocity_scaling.zig` implementing:
  - 1.5m minimum fall distance threshold required to activate smash attacks.
  - Two-tier kinetic damage formula: +4.0 dmg/m for first 3m ($0 \le h \le 3.0$), +2.0 dmg/m beyond 3m ($h > 3.0$).
  - Density enchantment (Levels I–V): adds $+0.5 \times \text{level} \times h$ damage per meter fallen.
  - Breach enchantment (Levels I–IV): reduces target armor defense by $15\% \times \text{level}$ (up to 60%).
  - Wind Burst enchantment (Levels I–III): triggers vertical launch impulses of +7.0, +10.0, and +13.0 m/s on smash hit.
  - Aerial combo multiplier progression: increments on successive airborne smash hits ($1.0\times, 1.25\times, 1.50\times \dots \le 2.0\times$).
  - Ground contact combo reset and fall damage complete negation on hit.
- Registered in `build.zig` test runner.
- Verification: 50/50 tests passed cleanly; `zig build` and `zig build test` passed (11,755/11,755 tests).

## Milestone 527 — Vault & Ominous Vault Multi-Player Key Unlocking & Reset Tokens
- Added standalone `src/world/vault_multiplayer_reset.zig` implementing:
  - Standard Vault unlocked with Standard Trial Key (`trial_key`), dispenses standard trial rewards (diamonds, emeralds, iron ingots, golden apples, breeze rods, food).
  - Ominous Vault unlocked with Ominous Trial Key (`ominous_trial_key`), dispenses exclusive ominous rewards (Heavy Core 2.2% chance, Flow/Bolt armor trims, Wind Burst enchanted books, Flow banner pattern).
  - Per-Player Lock Tracking: maintains up to 64 independent player unlock IDs (`unlocked_players`); player-specific display preview rendering spinning showcase items only to eligible players; already unlocked players see a dark keyhole and cannot insert keys.
  - Single Vault Reset Token consumption clears an individual player's lock (`resetPlayerLock(player_id)`), returning `.reset` and allowing that player to unlock the vault again.
  - Item Ejection Physics: ejects 3 to 6 items upward with velocity $v_y \in [0.35, 0.55]$ m/s and randomized radial horizontal dispersion covering all $2\pi$ radians.
  - Redstone Comparator Integration: outputs signal strength 15 for the nearest eligible player, 0 if the nearest player has unlocked, and 0 when no players are in range.
- Registered in `build.zig` test runner and connected representative frame-loop queries in `src/main.zig`.
- Verification: 37/37 tests in `src/world/vault_multiplayer_reset.zig` passed; `zig build` and `zig build test` passed cleanly (11,792/11,792 tests).

## Milestone 528 — Crafter 9-Slot Pulsed Automation & Hopper Round-Robin
- Added standalone `src/world/crafter_pulsed_grid.zig` implementing:
  - 3x3 slot grid with player-toggleable disabled states (`u9` mask). Disabling an occupied slot ejects/clears its contents, and disabled slots refuse direct or hopper item insertion.
  - Rising edge redstone pulse execution consuming 1 item per enabled slot, crafting configured recipes, and ejecting through 6-direction front nozzle.
  - Minimum 4-tick craft delay between consecutive craft operations (`craft_delay_ticks = 4`).
  - `HopperRoundRobin` sequential distribution advancing across enabled slots, skipping disabled/full slots, wrapping 8 to 0, and handling backpressure when all enabled slots are saturated.
  - Redstone comparator fullness formula: $\min(9, \text{count}(\text{disabled}) + \text{count}(\text{occupied}))$ yielding output range $0..9$ as `u4`.
- Registered in `build.zig` test runner.
- Verification: 49/49 tests in `src/world/crafter_pulsed_grid.zig` passed; `zig build` and `zig build test` passed cleanly (11,841/11,841 tests).

## Milestone 529 — Bogged Poison Combat & Mushroom Shearing Harvest
- Added standalone `src/world/bogged_poison_harvest.zig` implementing:
  - Bogged entity attributes: 16.0 HP max health (8 hearts, weaker than 20.0 HP skeleton), bow weapon, 70-tick attack cooldown (3.5s at 20 ticks/sec vs 40-tick standard skeleton).
  - Poison I-tipped arrow ranged combat: ballistic velocity trajectory kinematics (gravity 0.05, drag 0.99), difficulty-scaled poison duration (4.0s / 80 ticks on Normal, 5.0s / 100 ticks on Hard, 0 on Easy/Peaceful).
  - Poison status effect mechanics: 1.0 HP magic damage every 25 ticks (1.25s), strictly preserving 1.0 HP minimum health floor (never kills player or target).
  - Environmental vulnerabilities: 1.0 HP/s daylight burning when exposed to direct sun, with daylight exemptions for helmets (absorbs damage with durability wear), water submersion, powder snow, rain, shade/roof, and night time.
  - Mushroom shearing harvest: Bogged naturally spawns with mushroom cap growth (`has_mushrooms = true`, `is_sheared = false`); shearing with shears drops 2 mushrooms (Brown/Red 50/50 probability per slot), consumes 1 shears durability, emits `SoundEffect.shears_snip` and moss/mushroom particle bursts, and transitions appearance (`has_mushrooms = false`, `is_sheared = true`); subsequent shearing attempts fail.
  - Defeat loot scaling: bones (0..2 + Looting), arrows (0..2 + Looting), player-kill poison-tipped arrow (50% base + 10%/level Looting up to 80% max cap; 0 on non-player kill), rare bow drop (8.5% base + 1.0%/level Looting), and 5 XP points.
- Registered in `build.zig` test runner.
- Verification: 68/68 tests in `src/world/bogged_poison_harvest.zig` passed; `zig build` and `zig build test` passed cleanly (11,909/11,909 tests across 609 steps).

## Milestone 530 — Ominous Bottle Consumption & Bad Omen / Trial Omen Transformation Matrix
- Added standalone `src/world/ominous_bottle_matrix.zig` implementing:
  - 5 Ominous Bottle tiers (Tier I through Tier V) mapping to amplifiers 0..4 via `tier - 1`.
  - 32-tick (1.6s) drinking consumption duration consuming 1 ominous bottle, yielding 1 empty glass bottle (`ItemType.glass_bottle`), and emitting `SoundEffect.potion_drink`.
  - Bad Omen status effect duration of 120,000 game ticks (100 minutes) with tier stacking rules: higher or equal tier updates amplifier and resets duration to 120,000 ticks, while lower tier preserves existing higher amplifier and duration without downgrading.
  - Village boundary 64.0m Euclidean proximity detection transmuting Bad Omen into Raid Omen, preserving amplifier, initiating a 600-tick (30s) countdown timer, emitting `SoundEffect.raid_horn`, and triggering a scaled Village Raid upon expiration.
  - Trial Spawner 14.0m Euclidean proximity detection transmuting Bad Omen into Trial Omen, preserving amplifier, setting duration formula $\text{duration\_ticks} = 18,000 \times (\text{amplifier} + 1)$, emitting `SoundEffect.trial_omen_transmute` and ominous particle vortex, and signaling nearby active trial spawners to upgrade to ominous.
  - Milk Bucket (`ItemType.milk_bucket`) cleansing: drinking milk immediately cleanses Bad Omen, Raid Omen (canceling raid trigger), and Trial Omen, reverting state to neutral and returning an empty bucket.
- Registered in `build.zig` test runner.
- Verification: 53/53 tests in `src/world/ominous_bottle_matrix.zig` passed cleanly; `zig build` and `zig build test` passed cleanly.

## Wave 25 Integration (Milestones 521–530)
- Verified all ten Wave 25 modules registered in `build.zig` (once each).
- Connected representative frame-loop queries in `src/main.zig` for all ten domains:
  - `warden_scent_blast_mod.SCENT_RANGE`
  - `sculk_shrieker_fog_mod.DARKNESS_RADIUS`
  - `calibrated_sensor_chains_mod.CALIBRATED_SENSOR_RANGE`
  - `breeze_jump_deflection_mod.VERTICAL_BOOST_VY`
  - `trial_spawner_waves_mod.scaleTotalMobs`
  - `mace_velocity_scaling_mod.BASE_DAMAGE`
  - `vault_multiplayer_reset_mod.requiredKey`
  - `crafter_pulsed_grid_mod.slot_count`
  - `bogged_poison_harvest_mod.BOGGED_MAX_HEALTH`
  - `ominous_bottle_matrix_mod.DRINKING_DURATION_TICKS`
- Added ItemTypes 639–648 to `src/inventory.zig` with maximum stack limits, display names, and RGBA colors:
  - `warden_sonic_pulse_matrix = 639`
  - `shrieker_darkness_fog_relic = 640`
  - `calibrated_resonance_matrix = 641`
  - `wind_charge_rocket_booster = 642`
  - `ominous_wave_hazard_core = 643`
  - `mace_velocity_impact_relic = 644`
  - `vault_reset_token_matrix = 645`
  - `crafter_pulsed_grid_controller = 646`
  - `bogged_poison_harvest_quiver = 647`
  - `ominous_omen_transmutation_matrix = 648`
- Implemented `wave25CraftingRecipe` providing six unique 2x2 recipes:
  - `echo_shard` + `sculk_catalyst` -> `warden_sonic_pulse_matrix`
  - `sculk` + `bone` -> `shrieker_darkness_fog_relic`
  - `amethyst_shard` + `copper_ingot` -> `calibrated_resonance_matrix`
  - `wind_charge` + `gunpowder` -> `wind_charge_rocket_booster`
  - `mace` + `breeze_rod` -> `mace_velocity_impact_relic`
  - `crafter` + `iron_ingot` -> `crafter_pulsed_grid_controller`
- Verification: 611/611 build test steps succeeded, 11,963/11,963 tests passed cleanly.

## Milestone 532: Pale Moss Carpet & Pale Hanging Moss Spread Dynamics
- Implemented `src/world/pale_moss_spread.zig` providing comprehensive domain logic for Pale Garden moss:
  - Pale Moss Carpet block physics: height 0.0625m (1 pixel / 1/16th block), non-solid walk-through collision.
  - Placement and support rules: floor attachment requiring solid top face below; wall-climbing attachment on solid vertical side faces (Pale Oak log/wood trunks); detachment/pop rules when support is removed.
  - Carpet flammability: combustible property with adjacent fire and lava ignition.
  - Pale Hanging Moss block physics: vertical downward hanging plant with tip growth (length 1 to 8 blocks).
  - Ceiling support rule: hangs from underside of solid blocks or leaves, or from another pale hanging moss block directly above.
  - Cascade breaking physics: breaking any segment in a hanging moss column instantly breaks all dependent hanging moss blocks below it, while preserving segments above and promoting the new lowest segment to tip.
  - Tool harvest mechanics: breaking with Shears guarantees 100% Pale Hanging Moss drop, consumes 1 shears durability, and emits `shears_snip` audio cue; breaking with bare hands or other tools yields 0% drop and 0 shears wear.
  - Bonemeal radial spread reaction: when applied to a Pale Moss Block, consumes 1 bonemeal, emits green/white sparkle particles, radiates across solid floor blocks within a 5-block horizontal radius ($dx^2 + dz^2 \le 25.0$), generates carpet on solid top faces, climbs vertically up Pale Oak wood/logs up to 2 blocks high, and generates downward hanging moss under Pale Oak leaves (1 to 3 blocks length).
- Registered `src/world/pale_moss_spread.zig` in `build.zig`.
- Verification: 45/45 unit tests passed in `pale_moss_spread.zig`; 613/613 build test steps succeeded, 12,008/12,008 tests passed cleanly.
