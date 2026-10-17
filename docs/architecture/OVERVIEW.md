# Architecture Overview

Last updated: 2026-10-17 (Session 375)

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
