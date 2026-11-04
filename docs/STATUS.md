# Status

Last updated: 2026-11-04.

This page is the current state of the project. Replace lines that stop being
true; do not append a new dated section per session. Older status text is in
Git history.

## Verification

| Check | Last result |
|-------|-------------|
| CI on `main` | 2026-10-30: hosted jobs run again on the public repository. `build-and-test` and `public-content` are required for an up-to-date PR, including for administrators, with no human review approval required. See [current main runs](https://github.com/Soul4723/zigcraft/actions/workflows/ci.yml?query=branch%3Amain) for job results. |
| Build and full test suite | 2026-11-04, Zig 0.16.0: build passed; 12,689 of 12,689 tests passed across 597 steps. Setup pins the compiler locally; LLVM/LLD are selected for compatibility with recent Linux C runtime objects. |
| Running the game | 2026-11-02: A freshly built executable under Xvfb/software OpenGL mined dirt while left was held, stopped destruction after release, placed one block while right was held, transferred an inventory stack once while left was held, and shut down with exit 0. Live 2×2 crafting was additionally checked through save data (32 logs became 31 logs plus four planks). Nether travel was checked with a fixture frame and, separately, with a normally generated frame and test-positioned player; an end-to-end walk from spawn and live return trip remain unchecked. |

Zig 0.17 cannot compile `build.zig` (`b.args` no longer exists). Use 0.16.0.

## Connected to the game

These systems are driven by input or the frame loop in `src/main.zig` and
`src/chunk_manager.zig`:

- Window, OpenGL 3.3 core context, mouse capture and first-person camera. Viewport/projection follow framebuffer size; inventory cursor mapping uses logical window size, and zero-sized windows pause rendering.
- Terrain from a value-noise heightmap with caves, ores, trees, lakes,
  mineshafts, ocean monuments and deterministic dormant obsidian portal remnants (`src/world/terrain.zig`). Default seed 1337 has a frame at (44, 7, 44); F ignites it through the existing portal detector, including when aimed at the top lintel. A test-positioned Xvfb run verified top-edge ignition and saved all six portal cells. Separate Nether
  and End generators live in the same file.
- Chunk streaming in a 7×7 chunk area around the player, greedy meshing with
  ambient occlusion, frustum culling, procedural texture atlas. Dedicated obsidian and Nether portal tiles render a dark frame and purple interior; sheep faces and pressure plates retain their original materials. Xvfb runs checked a normally generated frame visually with side and top-edge ignition; the combined run saved six portal cells and exited cleanly.
- Block picking by voxel raycast, outline highlight, held-left mining time by tool tier,
  tool wear, block placement. Numeric stack counts are visible in the hotbar, inventory, crafting grid/output and held cursor stack.
- Death and respawn clear temporary status effects, flight/propulsion and stale ground/fluid contact; equipment-derived Soul Speed and navigation targets remain intact.
- Player physics: gravity, collision, jumping, sprinting, swimming, ladders,
  fall damage, suffocation, drowning, health and hunger shown on the HUD;
  activity exhaustion drains saturation before hunger.
- 24-slot inventory with a 6-slot hotbar, a 2×2 crafting grid, chests and
  furnaces. Pale Oak trees generate naturally with sandwiched Creaking Hearts
  that yield `resin_clump` items when interacted with using F at night (and
  drop bonus clumps when harvested with a tool while sandwiched), feeding the live `resin_clump` -> `resin_brick` furnace
  recipe.
- Mobs from `src/entity/`: 26 types (including sheep, pigs, wolves, zombies,
  skeletons, creepers, endermen, piglins, blazes, guardians, the Ender
  Dragon, and the nocturnal Creaking puppet entity), with spawn rules, simple AI, pathfinding and box-model rendering. Sandwiched Creaking Hearts spawn at most one Creaking at night within 32m, freezing under unobstructed upper-body gaze via DDA occlusion, dealing contact damage, and extruding resin on hit via shared cooldown. A carried carved pumpkin bypasses gaze freeze, following the inventory-based armor convention. A fixture-assisted Xvfb run observed nighttime appearance, stationary torso-gaze behavior, pursuit/contact attacks after looking away, and resin on puppet strike followed by heart cooldown rejection and later extrusion. Dawn and broken-heart despawn remain covered by unit tests; the live post-break view was inconclusive. Blaze combat is wired to `blaze_fortress` rules (`BlazeAttackState`): Blazes charge visibly on fire for 3s then fire a 3-fireball volley toward the player before entering a 5s cooldown, and take 3 damage from snowballs (`resolveSnowballOrWaterHitOnBlaze`) with sizzle audio and spark particles. Guardian and Elder Guardian combat is wired to `ocean_monument` rules (`GuardianLaserState`, `tickGuardianLaserBeam`): Guardians within 15m charge their laser with progressive visual cues (purple portal particles and cyan debris progressing through orange debris and flashing yellow shimmer) before firing an armor-piercing beam (6 physical + 1 magic damage for standard, 8 physical + 2 magic damage and Mining Fatigue for Elder Guardian) with splash and mob roar audio. Striking a Guardian or Elder Guardian in melee triggers defensive spike thorns retaliation (`evaluateGuardianSpikeThorns`), dealing 2 thorns damage to the player with orange spike particle debris and hurt audio.
- Wither boss spawn sequence and birth explosion: Wither summoning from placing the wither skull T-pattern activates the charging spawn sequence in `wither_boss` (`WitherBoss` starting in `.spawning_invulnerable` for 220 ticks), emitting smoke and flame charging particles around the summon site / champion mob, detonating with `.tnt_explode` audio, smoke/flame burst particles, and terminal announcement when the birth explosion completes and transitions to `.aerial_phase_1`. When active, the HUD boss bar renders the active wither champion's health fraction. Slain champions transition the boss state to `.defeated`.
- Strider mount, lava locomotion, and boost mechanics: Striders are wired to `strider_mount` rules (`StriderState`), updating lava and shivering state in the frame loop (striding swiftly at 4.2 m/s on lava lakes, and shivering at 1.7 m/s on cold land or in rain/water). Right-clicking with a Warped Fungus on a Stick while on lava activates a 14.0s speed boost surge to 7.8 m/s with lava pop audio and flame particles while consuming stick durability; right-clicking with a Warped Fungus feeds, heals, or breeds them.
- Beacon block placement and sky beam activation: Beacons activate when unobstructed to the sky and placed atop an iron, gold, diamond, or emerald mineral block (`beacon_aura`). Active beacons emit a continuous beam of luminous particles and project an aura (20m radius base level, expanding to 50m when supercharged). Right-clicking an active beacon with mineral payment (iron ingot, gold nugget, emerald, diamond, or netherite ingot) activates a 300s supercharge timer with chime audio and shimmer particles, providing active health regeneration and a live 1.40× Haste mining speed boost (`hasteMultiplier`) reducing mining time across all blocks.
- Ender Dragon combat rules, crystal tether healing, and recoil backlash: Ender Dragon fight rules are unified in `ender_dragon_fight` (with duplicate `ender_dragon_arena_fight` removed). In The End, the nearest alive end crystal within 32m heals the dragon at 2.0 HP/s (`tickDragonCrystalBeamHealing`), emitting particle beam vortex and glowstone shimmer effects between crystal and dragon. Shattering an end crystal (via mining or projectile hit) while the dragon is within 32m deals 10 recoil backlash damage (`CRYSTAL_SHATTER_RECOIL_DAMAGE`) to the dragon, accompanied by `.mob_roar` audio and flame/smoke particle bursts. When the dragon is perched on the central fountain altar, arrows and other projectiles are deflected (`canDamageDragonWithProjectile`), while melee attacks remain effective.
- Redstone: wire with 15-block falloff, torches, repeaters, levers, pressure
  plates, lamps and iron doors, plus dispensers, droppers and hoppers.
- TNT, falling sand, water flow with levels, water washing away redstone. Player explosion damage reaches its maximum at the blast center with finite upward knockback and zero horizontal push there.
- Nether portal and End portal travel, with dimension-specific terrain, sky
  and fog.
- Day and night cycle, sleeping, particles, procedural sound through ALSA.
- Chunk saving under `saves/` with per-dimension namespaces (blocks, water
  levels, repeater delays, torch burnout; Overworld in root, Nether and The
  End in subdirectories).
- Player position, velocity, spawn point, view, dimension, vitals, inventory,
  crafting grid, selected hotbar slot and tool wear persist in root-level
  `saves/player.bin` across dimensions.
- Chest and shulker-box four-slot contents, including opened empty fortress chests, persist in per-dimension `containers.bin` across restart and portal travel. Breaking or exploding chests, shulker boxes, hoppers, or droppers drains items into player inventory; when inventory lacks room, container destruction is aborted and remaining items stay in cache.
- Hoppers and droppers accept one held item with F or return a stack to an empty hand. Their contents, cooldown/power state and per-dimension isolation persist across restart and portal travel; failed insertion keeps its item.
- Furnace, smoker, blast-furnace jobs and growing saplings persist in
  per-dimension `block_jobs.bin` files across quit/restart and portal
  switches; offline dimension and unloaded-chunk simulation are paused
  without dropped items or duplicated outputs.

Much in-game feedback is printed to the terminal: `src/main.zig` has about
300 `std.debug.print` calls.

## Tested but not connected

`src/world/` has 287 files. `src/main.zig` imports about 280 of them, but
many imports exist only to call a helper with fixed inputs and discard its
result. Those calls do not implement a mechanic unless the result or side
effects reach game state, rendering or audio. Some ignored returns do have
real side effects, so inspect callers before removing them.

```bash
grep -cE '^\s*_ = [a-z0-9_]+_mod\.' src/main.zig   # 280 discarded calls on 2026-10-30
```

Treat a module as part of the game only when its result changes world state,
entities, the player, the inventory, rendering or audio. Many inventory items
and recipes (`src/inventory.zig`) exist only as items with names, colors and
stack sizes.

Several mechanics have more than one module, written by different sessions:

| Mechanic | Modules in `src/world/` |
|----------|-------------------------|
| Mace | `mace_combat` (tests only), `mace_smash_kinematics`, `mace_aerial_combos`, `mace_velocity_scaling` |
| Crafter | `autocrafter`, `crafter_automation`, `crafter_factory_clocking`, `crafter_pulsed_grid` |
| Elytra | `elytra_aerodynamics`, `elytra_flight_matrix`, `elytra_rocket_propulsion` |
| Warden and sculk | `warden_deep_dark`, `warden_scent_blast`, `warden_sonic_boom`, `sculk_shrieker_fog`, `sculk_shrieker_warning`, `calibrated_sculk`, `calibrated_sculk_resonance`, `calibrated_sensor_chains` |
| Trial chambers | `trial_spawner_dynamics`, `trial_spawner_waves`, `vault_loot_dispenser`, `vault_multiplayer_reset`, `trial_vault_reset`, `ominous_trial`, `ominous_bottle_omen`, `ominous_bottle_matrix` |
| Wind charge | `wind_charge`, `breeze_wind_charge`, `breeze_jump_deflection` |
| Camel | `camel`, `camel_mount_kinematics`, `camel_step_dash` |
| Pairs | `bundle_pouch` / `bundle_dyeing_nesting` |

Other overlaps:

- `pale_garden` Creaking Heart resin extrusion and Creaking mob entity runtime are connected to live gameplay; dynamic thunderstorm weather activation remains deferred while weather simulation is static clear sky.
- Mob rule modules (warden and others) do not drive the mobs
  in `src/entity/`, which have their own stats and AI; Blaze combat rules are unified in `blaze_fortress` and Guardian / Elder Guardian rules are unified in `ocean_monument`, both connected to live gameplay; Beacon pyramid geometry, status powers, and payment activation are unified in `beacon_aura` with live dynamic aura range, health regeneration, and supercharged Haste mining multiplier connected; Strider mount and lava locomotion rules are unified in `strider_mount` with warped fungus boost and feeding connected to gameplay; Wither boss rules are unified in `wither_boss` with spawn charging invulnerability, birth explosion detonation, and live HUD boss bar tracking connected to gameplay.
- Some modules describe 3×3 recipes, but the inventory only has a 2×2 grid.

## Known problems

- Chest and shulker caches share a limit of 16 entries per dimension and four slots per entry.
- Hopper and dropper caches each have a limit of 32 four-slot entries per dimension.
- The world is 16 blocks tall: chunks are 16×16×16 and there is one layer.
- `BlockId` is a `u8` and uses all 256 values. New blocks need a wider ID or
  a different block-state scheme first.
- `src/main.zig` is 7,105 lines; `main()` alone runs from line 363 to the
  end. `src/inventory.zig` was split into `items.zig`, `recipes.zig`,
  `inventory.zig` (~250 lines), and `inventory_test.zig`.
- `b.addTest` on `src/main.zig` executes zero tests because `main.zig` lacks test
  or comptime blocks, not because imported tests cannot be collected. Per-file
  test roots duplicate shared module tests (e.g. `block.zig`) via lazy Sema,
  while explicit `test_files` entries remain project policy for complete coverage.

## Legacy pull request triage

All 67 remaining legacy PRs were reviewed against `5d1db0d` on 2026-10-30.
65 were closed as superseded: their implementations and applicable runtime
changes were already on `main`. Later fixes and current item IDs were kept.

[Pale moss #362](https://github.com/Soul4723/zigcraft/pull/362) and
[resin masonry #363](https://github.com/Soul4723/zigcraft/pull/363) were not
adopted: they add isolated rule models without playable integration. Their
code and checked head SHAs remain in the closed PRs. Every closed PR has a
disposition note with source evidence.

No legacy PR remains open. The 67 PR branches, five source-identical orphan
branches and one superseded local branch were removed. Closing the PRs did
not connect the existing standalone modules to gameplay; the
[roadmap](ROADMAP.md) still prioritizes that work.
