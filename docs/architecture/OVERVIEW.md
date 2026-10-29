# Architecture Overview

Last updated: 2026-10-29 (Session 387)

## Project Structure

```
zigcraft/
├── AGENTS.md                    # AI developer instructions
├── CONTRIBUTING.md              # AI workflow guide, guard rails, patterns
├── build.zig                    # Zig build configuration & test registry
├── build.zig.zon                # Package manifest
├── README.md
├── src/
│   ├── main.zig                 # Game loop, GLFW window setup, input & tick dispatch
│   ├── math.zig                 # Vec3, Mat4, Ray math primitives
│   ├── camera.zig               # First-person camera (WASD, mouse look)
│   ├── player.zig               # Player physics, AABB collision, ladder climbing
│   ├── pick.zig                 # Fast DDA voxel raycasting for block targeting
│   ├── sky.zig                  # Sky dome and sun orbit lighting calculations
│   ├── inventory.zig            # Slot inventory, item definitions, 2x2 crafting
│   ├── entity.zig               # Base entity interface
│   ├── entity/                  # Mobs, sheep, pigs, hostile wolves, mob rendering
│   ├── audio/                   # ALSA backend, procedural waveform synthesizer
│   ├── renderer/
│   │   ├── shader.zig           # Shader compile & uniforms
│   │   ├── mesh.zig             # OpenGL VAO/VBO wrappers
│   │   ├── texture.zig          # Atlas generation & binding
│   │   ├── ui.zig               # 2D crosshair, hotbar, and toast pills
│   │   ├── particles.zig        # 3D voxel physics debris & splash emitters
│   │   └── highlight.zig        # Wireframe block selection box
│   └── world/
│       ├── block.zig            # BlockId definitions & block attributes
│       ├── chunk.zig            # 16x16x16 chunk storage
│       ├── chunk_mesh.zig       # Greedy chunk meshing with ambient occlusion
│       ├── terrain.zig          # fBm heightmap terrain & cave generation
│       ├── fluid_wash.zig       # Water wash rules and staged nearby flow ticks
│       ├── redstone.zig         # Wire BFS logic, delay stages, power propagation
│       ├── farming.zig          # Wheat crop growth stages, hydration, bone meal & harvest yield
│       ├── trading.zig          # Emerald workstation bartering professions, offers & tier XP
│       ├── apiary.zig           # Beehive pollination, honey harvesting & honey block physics
│       ├── copper.zig           # Copper oxidation stages, waxing, axe scraping & spyglass zoom
│       ├── amethyst.zig         # Budding amethyst crystal growth, chime pitch & bell alarm range
│       ├── campfire_cook.zig    # Fuel-free campfire roast rack cooking & hay bale smoke signals
│       ├── sculk.zig            # Sculk sensor acoustic vibration range, wool occlusion & signal decay
│       ├── golem.zig            # Snow & Iron Golem totem detection, repair & tribute math
│       ├── cake.zig             # 7-slice placed cake consumption & comparator fullness signal
│       ├── dripstone.zig        # Stalactite impact damage, stalagmite fall multiplier & cauldron drip
│       ├── lush_caves.zig       # Moss conversion, glow berry vines & night vision ambient boost
│       ├── totem.zig            # Totem of Undying fatal-damage resurrection & regeneration potion
│       ├── ice_physics.zig      # Ice/Packed Ice/Blue Ice speed multipliers & powder snow frostbite
│       ├── scaffolding.zig      # Scaffolding tower top placement & sweet berry bush prickle damage
│       ├── alchemy_buffs.zig    # Swiftness, Strength & Leaping potion timers and combat/speed buffs
│       ├── ender_chest.zig      # Global quantum EnderVault deposit & withdrawal mechanics
│       ├── beacon_aura.zig      # Beacon mineral pyramid verification, Haste & Regeneration aura
│       ├── archaeology.zig      # Suspicious sand brush relic excavation & Copper Bulb latch
│       ├── wind_charge.zig      # Wind Charge self-boost rocket jump & radial knockback impulse
│       ├── mace_combat.zig      # Mace smash attack fall-velocity damage scaling & fall reset
│       ├── autocrafter.zig      # Crafter batch autocrafting & Trial Vault key loot tables
│       ├── calibrated_sculk.zig # Calibrated sculk sensor acoustic frequency filtering & resonance
│       ├── frog.zig             # Frog predation drops, froglight variants & lily pad jump velocity
│       ├── goat_horn.zig        # Goat horn 64m acoustic broadcast, cooldown & ramming impulse
│       └── persistence.zig      # Binary chunk serialization
└── docs/
    ├── STATUS.md                # Real-time state of the project
    ├── ROADMAP.md               # Milestones & planned systems
    ├── PARALLEL-SESSIONS.md     # Multi-agent collaboration rules
    ├── architecture/            # Architectural blueprints
    ├── decisions/               # ADR decision logs
    ├── learnings/               # Zig 0.16.0 API discoveries
    └── sessions/                # Chronological session logs
```

## Testing
Module tests run through standalone targets registered in `build.zig`. Run with:
```bash
zig build test --summary all
```

## Water ticks

`main.zig` dispatches `fluid_wash.step` every 0.4 seconds. The step scans the
existing player-centered window (horizontal radius 7, vertical -3/+2, clipped
to world height), stages up to eight distinct destinations, then applies them
through `ChunkManager.editAndRemesh`. Reading before writing prevents new water
from spreading again during the same tick. Downward flow takes priority;
lateral flow accepts air over either ground or a ledge. Occupied cells remain
unchanged. This remains a source-copy model: finite levels and drainage require
persisted fluid metadata and remain an unfinished roadmap milestone.

### Wave 3 domain modules

Milestones 305–314 are implemented as standalone stateful mechanics under `src/world/` (`happy_ghast.zig`, `warden_deep_dark.zig`, `strider_mount.zig`, `axolotl.zig`, `banner_heraldry.zig`, `anvil_smithing.zig`, `copper_golem.zig`, `ambient_foliage.zig`, `ender_stasis.zig`, and `minecart_logistics.zig`). `main.zig` owns one active domain state per system and advances the tick-capable systems in the main frame loop; pure interaction/crafting helpers remain in their domain modules and are exercised by standalone tests.

### Wave 4 domain modules

Milestones 315–322 add `enchanting_grindstone.zig`, `village_raid.zig`,
`redstone_workstations.zig`, `shulker_end_city.zig`,
`elytra_aerodynamics.zig`, `sea_turtle.zig`, `taiga_fox.zig`, and
`conduit_frame.zig`. Domain rules and state remain in these focused modules.
`main.zig` owns and advances representative flight, raid, composter,
levitation, turtle-growth, and fox state; deterministic interaction helpers
remain directly callable from their modules. Each module has a standalone
test target.

Wave 4 adds representative `ItemType` values 440–447 in `inventory.zig`;
the existing `BlockId` registry is unchanged. Three 2x2 recipes cover
enchanted books, a Mending book, and a fox treat.

### Wave 5 domain modules

Milestones 323–330 add `enderman_ai.zig`, `piglin_bastion.zig`,
`charged_creeper.zig`, `swamp_witch.zig`, `blaze_fortress.zig`,
`ghast_deflection.zig`, `slime_mitosis.zig`, and `phantom_insomnia.zig`.
`main.zig` owns representative Enderman, Piglin barter, Creeper, Blaze, and
Phantom state and advances them in the frame loop; stateless interaction
rules from the Witch, Ghast, and Slime modules are queried there. `inventory.zig`
adds ItemTypes 448–455 for mob-head trophies and bottle/potion items without
changing `BlockId`. Gunpowder recipes produce splash water and harming potions.
Each module has a standalone test target.

### Wave 6 domain modules

Milestones 331–340 add `wither_boss.zig`, `ender_dragon_fight.zig`,
`villager_curing.zig`, `piston_adhesion.zig`, `fishing_treasure.zig`,
`shield_thorns_combat.zig`, `trident_enchantments.zig`,
`dimensional_anchors.zig`, `precision_redstone_sensors.zig`, and
`snow_golem_ai.zig`. `main.zig` owns representative Wither, Dragon Breath,
villager cure, shield, anchor, Observer, snow golem, and Loyalty trident
states, advances tick-capable states, and queries the stateless mechanic
helpers. Each module has its own `build.zig` test target.

Wave 6 adds ItemTypes 456–461 for Wither Rose, Glazed Terracotta, Name Tag,
Saddle, and weighted pressure plates; `BlockId` remains at 255. Inventory
metadata covers names, colors, and stack limits. The 2x2 grid adds glazed
terracotta and light/heavy weighted plate recipes; Wither Rose, Name Tag, and
Saddle remain drop/loot-style items.

### Wave 7 domain modules

Milestones 341–350 add `allay_collector.zig`, `note_block_instruments.zig`,
`equine_genetics.zig`, `companion_pets.zig`, `panda_genetics.zig`,
`dolphin_navigation.zig`, `bee_pollination.zig`, `cartography_maps.zig`,
`processing_workstations.zig`, and `boots_and_armor_stands.zig`. The modules
own focused deterministic rules and standalone tests. `main.zig` imports them,
advances representative Allay, Dolphin, and Bee state, and queries the pure
interaction helpers from the frame loop; entity/world mutation remains owned
by the game systems that will connect those interactions.

Wave 7 adds ItemTypes 462–469 for locator/explorer maps, glass panes, horse
armor, and Frost Walker Boots. Inventory metadata includes names, colors,
stack limits, and armor durability/classification where relevant. The 2x2
grid creates locator maps, duplicates explorer maps, and crafts glass panes;
`BlockId` stays unchanged at 255.

### Wave 8 domain modules

Milestones 351–360 add `woodland_mansion.zig`, `ocean_monument.zig`,
`ancient_city.zig`, `temple_traps.zig`, `stronghold_triangulation.zig`,
`mushroom_island.zig`, `weather_lightning.zig`, `hunger_metabolism.zig`,
`experience_orbs.zig`, and `melee_sweep_crit.zig`. Each module has a
standalone test target. `main.zig` owns representative transient states and
ticks or queries domain rules through the frame loop; persistent world and
entity mutation stays with the systems that consume those results.

Wave 8 adds ItemTypes 470–474 for Swift Sneak and Sweeping Edge books,
Reinforced Deepslate, Milk Bucket, and Bottle o' Enchanting. Inventory
metadata includes display names, colors, and stack limits. The 2x2 grid adds
two representative book recipes. `BlockId` remains unchanged at 255.

### Wave 9 domain modules

Milestones 361–370 add `skeleton_variants.zig`, `zombie_conversions.zig`,
`spider_arachnids.zig`, `mountain_goat.zig`, `hoglin_zoglin.zig`,
`ranged_enchantments.zig`, `item_frames_paintings.zig`,
`armor_toughness_epf.zig`, `hopper_item_sorter.zig`, and
`beacon_pyramid.zig`. Each has a standalone test target. `main.zig` keeps
representative state for conversion, hoglin, frame, and hopper rules and
advances or queries all ten domains through the frame loop. These hooks provide
integration points; persistent entities, blocks, and container mutation remain
with the existing world systems.

Wave 9 adds ItemTypes 475–480 for Slowness Arrows, Item Frames, Glow Item
Frames, Paintings, Feather Falling Books, and Stained Glass; ItemType 481 is
the Slowness Potion ingredient used by the arrow recipe. Names, colors, and
stack limits are defined, along with six 2x2 recipes. `BlockId` remains 255.


### Wave 10 domain modules

Milestones 371–380 add `badlands_mesa.zig`, `concrete_masonry.zig`,
`igloo_snowy_plains.zig`, `jungle_canopy.zig`, `savanna_acacia.zig`,
`dark_forest_canopy.zig`, `shipwreck_treasure.zig`, `nether_biomes.zig`,
`firework_pyrotechnics.zig`, and `cauldron_fluids.zig`. Each has a standalone
test target in `build.zig`. `main.zig` imports all ten modules, advances
representative state (such as cauldron fill/comparator state), and queries
biome generation, pyrotechnic damage, and fluid mechanics through the frame
loop.

Wave 10 adds ItemTypes 482–489 for Red Sandstone, Concrete Powder, Concrete,
Buried Treasure Map, Heart of the Sea (64-stack), Firework Star, Acacia
Planks, and Dark Oak Planks. Inventory metadata defines names, colors, stack
limits, and seven 2x2 recipes (masonry, concrete hydration, star pyrotechnics,
treasure maps, and wood plank varieties). `BlockId` remains unchanged at 255.


### Wave 11 domain modules

Milestones 381–390 add `bastion_remnant.zig`, `ruined_portal.zig`,
`pillager_outpost.zig`, `ocean_ruins.zig`, `trail_ruins.zig`,
`netherite_metallurgy.zig`, `coral_reef.zig`, `ice_spikes_biome.zig`,
`swamp_marsh.zig`, and `book_quill_lectern.zig`. Each has a standalone test
target in `build.zig`. `main.zig` imports all ten modules, advances
representative state (such as lectern comparator signal and structure/biome
geometry checks), and queries structure bounds, archaeology excavation,
metallurgy, and fluid/slipperiness physics through the frame loop.

Wave 11 adds ItemTypes 490–500 for Music Disc Pigstep, Netherite Upgrade
Template, Sniffer Egg, Suspicious Gravel, Coral Block, Dead Coral Block,
Lily Pad, Frogspawn, Bucket of Tadpole, Book and Quill, and Written Book.
Inventory metadata defines names, colors, stack limits (stack 1 for discs,
tadpole buckets, and book & quill; stack 16 for written books; stack 64 for
others), and six 2x2 recipes (upgrade template duplication, book & quill,
written book signing, lily pads, coral blocks, and bucket of tadpoles).
`BlockId` remains unchanged at 255.


### Wave 12 domain modules

Milestones 391–400 add `outer_end_islands.zig`, `subterranean_fossils.zig`,
`amethyst_geode_budding.zig`, `azalea_lush_ecology.zig`,
`brewing_stand_alchemy.zig`, `fletching_tipped_arrows.zig`,
`scaffolding_bamboo.zig`, `navigation_timepieces.zig`,
`villager_professions.zig`, and `wandering_trader.zig`. Each module has a
standalone test target. `main.zig` imports all ten and queries representative
world, alchemy, navigation, trading, and structure rules each frame.

Wave 12 adds ItemTypes 501–510 for fossil/geode/lush-cave materials, potion
variants, and clocks. Inventory metadata includes names, RGBA colors, stack
limits, and six 2x2 recipes. `BlockId` remains unchanged at 255.


### Wave 13 domain modules

Milestones 401–410 add `flower_forest_plains.zig`, `mountain_peaks_ores.zig`,
`old_growth_taiga.zig`, `birch_forest.zig`, `dispenser_dropper_automation.zig`,
`rail_network_switching.zig`, `end_crystal_mechanics.zig`, `boat_watercraft.zig`,
`lead_leash_mechanics.zig`, and `bed_sleep_mechanics.zig`. Each is independently
tested and imported by `main.zig`, which queries representative deterministic
rules each frame while existing world/entity systems retain mutation ownership.

Wave 13 adds ItemTypes 511–521 for flowers, podzol/mossy cobblestone, birch and
spruce planks, chest boat, bamboo raft, and bed. Metadata includes names, RGBA
colors, and stack limits; six 2x2 recipes extend the crafting grid. `BlockId`
remains capped at 255.


### Wave 14 domain modules

Milestones 411–420 add `igneous_stone_masonry.zig`, `glazed_terracotta_mosaic.zig`,
`lighting_fixtures.zig`, `wooden_signs.zig`, `fences_gates_walls.zig`,
`doors_trapdoors_crawl.zig`, `sculk_growth_harvest.zig`, `anvil_repair_mechanics.zig`,
`loom_shield_banners.zig`, and `tnt_demolition_physics.zig`. Each has a standalone
test target and is imported by `main.zig`, which queries representative deterministic
rules through the frame loop while existing world/entity ownership remains unchanged.

Wave 14 adds ItemTypes 522–532 for igneous masonry, sign and lighting materials,
fence/wall components, and sculk veins. Inventory metadata defines names, colors,
stack limits, and six 2x2 recipes. `BlockId` remains capped at 255.


### Wave 15 domain modules

Milestones 421–430 add `chunk_loader_tickets.zig`, `redstone_torch_inverter.zig`,
`regional_difficulty_moon.zig`, `iron_golem_spawning.zig`, `mob_despawn_spheres.zig`,
`redstone_repeater_latch.zig`, `dropped_item_physics.zig`, `flying_machine_kinematics.zig`,
`zombie_reinforcements_siege.zig`, and `entity_cramming.zig`. Each has a standalone
test target and is imported by `main.zig`, which queries representative deterministic
rules through the frame loop while existing world/entity ownership remains unchanged.

Wave 15 adds ItemTypes 533–542 for chunk loader tokens, redstone inverter cores,
moon phase talismans, golem effigies, mob despawn wards, repeater latch locks,
dropped item magnets, flying machine cores, zombie siege banners, and cramming
dispersers. Inventory metadata defines names, colors, stack limits, and six 2x2 recipes.
`BlockId` remains capped at 255.

### Wave 16 domain modules

Milestones 431–440 add `target_block_projectile.zig`, `lightning_redstone_deflection.zig`,
`frost_walker_ice.zig`, `soul_speed_kinematics.zig`, `swift_sneak_crouch.zig`,
`respawn_anchor_charge.zig`, `lodestone_compass_tracking.zig`, `composter_biofuel.zig`,
`specialized_furnace_smelting.zig`, and `tripwire_hook_circuit.zig`. Each has a standalone
test target and is imported by `main.zig`, which queries representative deterministic
rules through the frame loop while existing world/entity ownership remains unchanged.

Wave 16 adds ItemTypes 543–552 for target block cores, lightning deflectors,
frosted ice shards, soul speed talismans, swift sneak boots trims, respawn anchor
shards, lodestone trackers, composter catalysts, pyrometallurgy nozzles, and
tripwire tension gauges. Inventory metadata defines names, colors, stack limits,
and six 2x2 recipes. `BlockId` remains capped at 255.

### Wave 17 domain modules

Milestones 441–450 add `sculk_catalyst_bloom.zig`, `sculk_shrieker_warning.zig`,
`calibrated_sculk_resonance.zig`, `chiseled_bookshelf_storage.zig`,
`hanging_sign_mechanics.zig`, `camel_mount_kinematics.zig`,
`decorated_pot_storage.zig`, `creaking_heart_puppet.zig`, `creaking_gaze_ai.zig`,
and `resin_masonry.zig`. Each has a standalone test target and is imported by
`main.zig`, which queries representative deterministic domain rules each frame;
world and entity mutation stays with existing owners.

Wave 17 adds ItemTypes 553–562 for sculk, shrieker, calibrated sensor,
bookshelf, hanging sign, camel, decorated pot, Creaking, eyeblossom, and resin
materials. Inventory metadata includes names, RGBA colors, stack limits, and six
2x2 recipes. `wooden_slab` and `stone_bricks` ingredient types occupy 563–564.
`BlockId` remains capped at 255.

### Wave 18 domain modules

Milestones 451–460 add `sniffer_digging_flora.zig`, `trial_spawner_dynamics.zig`,
`vault_loot_dispenser.zig`, `breeze_wind_charge.zig`, `mace_smash_kinematics.zig`,
`crafter_automation.zig`, `copper_bulb_latch.zig`, `trial_chamber_generation.zig`,
`ominous_bottle_omen.zig`, and `bogged_stray_variants.zig`. All ten modules are
standalone test targets. `main.zig` imports them and queries representative
mechanics each frame; world and entity mutation remains with their existing owners.

Wave 18 adds ItemTypes 565–574 for ancient sniffer eggs, master trial keys,
breeze/mace/crafter/copper-bulb cores, a trial chamber map, an ominous bottle
catalyst, and a Bogged poison quiver. Inventory defines display names, RGBA
colors, and stack sizes, and its 2x2 grid supports six recipes. `BlockId` remains
capped at 255.

### Wave 19 domain modules

Milestones 461–470 add `armadillo_wolf_defense.zig`, `allay_amethyst_duplication.zig`,
`froglight_predation.zig`, `goat_horn_acoustics.zig`, `sculk_sensor_multiplexing.zig`,
`deepslate_mineralogy.zig`, `mangrove_mud_architecture.zig`, `warden_sonic_boom.zig`,
`recovery_compass_echo.zig`, and `archaeology_brush_excavation.zig`. All ten modules
are registered as standalone test targets in `build.zig`. `main.zig` imports each
module and wires representative per-frame query hooks keeping their deterministic
rules active; world and entity mutation stays with existing owners.

Wave 19 adds ItemTypes 575–584:
- 575: `armadillo_scute_core` (stack 64)
- 576: `allay_amethyst_resonator` (stack 16)
- 577: `froglight_catalyst` (stack 64)
- 578: `screamer_goat_horn` (stack 1)
- 579: `sculk_multiplexer_node` (stack 64)
- 580: `reinforced_deepslate_core` (stack 64)
- 581: `mud_brick_masonry` (stack 64)
- 582: `warden_sonic_core` (stack 16)
- 583: `recovery_compass_talisman` (stack 1)
- 584: `archaeology_brush_relic` (stack 1)
- 585: `glowstone_dust` (stack 64, ingredient)

Inventory defines display names, RGBA colors, and stack sizes, and its 2x2 grid
supports six recipes (`armadillo_scute_core`, `allay_amethyst_resonator`,
`froglight_catalyst`, `screamer_goat_horn`, `mud_brick_masonry`, and
`recovery_compass_talisman`). Disambiguation preserves legacy Recipe 234
`recovery_compass` when multiple echo shards (count >= 2) are supplied. `BlockId`
remains capped at 255.


### Wave 20 domain modules

Milestones 471–480 add `trial_chamber_traps.zig`, `bundle_dyeing_nesting.zig`,
`netherite_smithing_pipeline.zig`, `shulker_bullet_levitation.zig`,
`elytra_rocket_propulsion.zig`, `riptide_trident_kinematics.zig`,
`skeleton_trap_combat.zig`, `witch_potion_combat.zig`, `evoker_fangs_vex.zig`,
and `totem_undying_resurrection.zig`. All ten modules are registered as standalone
test targets in `build.zig`. `main.zig` imports each module and wires
representative per-frame query hooks keeping their deterministic rules active;
world and entity mutation stays with existing owners.

Wave 20 adds ItemTypes 586–595:
- 586: `ominous_trap_core` (stack 64)
- 587: `dyed_bundle_package` (stack 1)
- 588: `netherite_smithing_core` (stack 16)
- 589: `shulker_levitation_orb` (stack 16)
- 590: `elytra_propulsion_core` (stack 1)
- 591: `riptide_vortex_shard` (stack 16)
- 592: `four_horsemen_crest` (stack 1)
- 593: `witch_brewing_cauldron` (stack 1)
- 594: `evoker_fangs_talisman` (stack 16)
- 595: `totem_resurrection_effigy` (stack 1)

Inventory defines display names, RGBA colors, and stack sizes, and its 2x2 grid
supports six recipes (`ominous_trap_core`, `dyed_bundle_package`,
`netherite_smithing_core`, `shulker_levitation_orb`, `elytra_propulsion_core`,
and `totem_resurrection_effigy`). Disambiguation preserves legacy Recipe 301
`bundle` when multiple leather (count >= 2) is supplied. `BlockId` remains
capped at 255.

Milestone 489 adds `turtle_scute_helmet.zig` as a standalone lifecycle module
with breeding, home-beach egg laying and incubation, baby growth/scute drops,
helmet recipe matching, and water-breathing timer rules. Its API is covered by
an isolated build/test target; world entity mutation remains with consumers.

### Wave 21 domain modules

Milestones 481–490 add standalone domain modules for Piglin bartering and
Bastion defense, zombified Piglin swarm alarms, Strider lava mounting, Nether
fungus forest growth, Hoglin repellent behavior, lead tension, fox berry
predation, turtle scute and helmet rules, and panda genetics variants. Each is
registered as a standalone test target in `build.zig`; `main.zig` imports all
ten and queries representative rules in the frame loop. Entity and world
mutation remains with their existing owners.

Inventory adds ItemTypes 596–605 with display names, RGBA colors, and stack
sizes. Its 2x2 grid supports six Wave 21 recipes. `gold_ingot` is added as an
ingredient item at 606 because no gold ingot item type existed; `BlockId` stays
within its `u8` capacity.

### Crafter factory clocking

`crafter_factory_clocking.zig` owns deterministic factory timing and item flow:
2/8-game-tick pulse clocks, rising-edge recipe execution, nine-slot round-robin
hopper insertion, backpressure, comparator fullness, and a Blast Furnace to
Crafter to output-chest throughput simulation. It is registered as a standalone
test module and referenced by the frame loop; actual world containers and item
entity mutation remain with their existing owners.
