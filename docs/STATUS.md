# Status

Last updated: 2026-10-31.

This page is the current state of the project. Replace lines that stop being
true; do not append a new dated section per session. Older status text is in
Git history.

## Verification

| Check | Last result |
|-------|-------------|
| CI on `main` | 2026-10-30: hosted jobs run again on the public repository. `build-and-test` and `public-content` are required for an up-to-date PR, including for administrators, with no human review approval required. See [current main runs](https://github.com/Soul4723/zigcraft/actions/workflows/ci.yml?query=branch%3Amain) for job results. |
| Build and full test suite | 2026-10-30, Zig 0.16.0: build passed; 12,063 of 12,063 tests passed across 613 steps. Setup now pins the compiler locally; LLVM/LLD are selected for compatibility with recent Linux C runtime objects. |
| Running the game | 2026-10-30: the built executable initialized OpenGL and ran for 8 seconds before the smoke check stopped it. No crash was reported; gameplay was not checked. |

Zig 0.17 cannot compile `build.zig` (`b.args` no longer exists). Use 0.16.0.

## Connected to the game

These systems are driven by input or the frame loop in `src/main.zig` and
`src/chunk_manager.zig`:

- Window, OpenGL 3.3 core context, mouse capture and first-person camera.
- Terrain from a value-noise heightmap with caves, ores, trees, lakes,
  mineshafts and ocean monuments (`src/world/terrain.zig`). Separate Nether
  and End generators live in the same file.
- Chunk streaming in a 7×7 chunk area around the player, greedy meshing with
  ambient occlusion, frustum culling, procedural texture atlas.
- Block picking by voxel raycast, outline highlight, mining time by tool tier,
  tool wear, block placement.
- Player physics: gravity, collision, jumping, swimming, ladders, fall damage,
  suffocation, drowning, health and hunger shown on the HUD.
- 24-slot inventory with a 6-slot hotbar, a 2×2 crafting grid, chests and
  furnaces.
- Mobs from `src/entity/`: 25 types (for example sheep, pigs, wolves, zombies,
  skeletons, creepers, endermen, piglins, blazes, guardians and the Ender
  Dragon), with spawn rules, simple AI, pathfinding and box-model rendering.
- Redstone: wire with 15-block falloff, torches, repeaters, levers, pressure
  plates, lamps and iron doors, plus dispensers, droppers and hoppers.
- TNT, falling sand, water flow with levels, water washing away redstone.
- Nether portal and End portal travel, with dimension-specific terrain, sky
  and fog.
- Day and night cycle, sleeping, particles, procedural sound through ALSA.
- Chunk saving under `saves/` with per-dimension namespaces (blocks, water
  levels, repeater delays, torch burnout; Overworld in root, Nether and The
  End in subdirectories).

Much in-game feedback is printed to the terminal: `src/main.zig` has about
300 `std.debug.print` calls.

## Tested but not connected

`src/world/` has 288 files. `src/main.zig` imports about 280 of them, but
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
| Creaking | `pale_garden`, `creaking_heart_puppet`, `creaking_gaze_ai`, `creaking_damage_link` |
| Beacon | `beacon_aura`, `beacon_pyramid`, `beacon_status_pyramids` |
| Wind charge | `wind_charge`, `breeze_wind_charge`, `breeze_jump_deflection` |
| Camel | `camel`, `camel_mount_kinematics`, `camel_step_dash` |
| Pairs | `bundle_pouch` / `bundle_dyeing_nesting`, `totem` / `totem_undying_resurrection`, `ender_dragon_fight` / `ender_dragon_arena_fight`, `wither_boss` / `wither_boss_phases`, `strider_mount` / `strider_lava_mount` |

Other overlaps:

- `hunger_metabolism.zig` duplicates the hunger rules in `src/player.zig`;
  the player's rules are the ones in use.
- Mob rule modules (guardian, blaze, warden and others) do not drive the mobs
  in `src/entity/`, which have their own stats and AI.
- Some modules describe 3×3 recipes, but the inventory only has a 2×2 grid.

## Known problems

- The world is 16 blocks tall: chunks are 16×16×16 and there is one layer.
- The player, inventory, furnace jobs and growing saplings are not saved.
- `BlockId` is a `u8` and uses all 256 values. New blocks need a wider ID or
  a different block-state scheme first.
- `src/main.zig` is 7,105 lines; `main()` alone runs from line 363 to the
  end. `src/inventory.zig` is 12,972 lines.

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
