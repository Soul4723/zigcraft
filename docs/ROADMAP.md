# Roadmap

Last updated: 2026-11-04.

The project has far more rule modules than game. The next work makes
existing mechanics real in the game and removes duplicates. Adding another
standalone module is the lowest priority. [STATUS.md](STATUS.md) has the
evidence for each item.

Pick the highest unblocked item not already covered by an open pull request.
Record unavailable resources and continue; do not spend each session
re-diagnosing the same external blocker.
When an item is done, delete it here and update STATUS.md.

## 1. Restore a trusted baseline

- Required hosted checks protect `main`. Diagnose failed checks before
  adding work; leave externally blocked PRs open and take another task.
- Complete live checks of mob combat, walking from spawn to a natural portal,
  and a Nether return trip. Crafting consumption and outbound Nether travel
  with a test-positioned player have been checked; keep fixture-assisted
  verification distinct from normal exploration. Xvfb supports headless input.

## 2. Fix world and save correctness

- No active world or save correctness bugs recorded; continue monitoring multi-dimension container and automation persistence.

## 3. Connect or remove disconnected modules

Work one mechanic at a time:

1. Choose the module that will own the mechanic. Merge useful rules from the
   duplicates listed in STATUS.md into it, then delete the duplicates and
   their `build.zig` entries.
2. Connect it until it meets the done list in
   [CONTRIBUTING.md](../CONTRIBUTING.md#3-change).
3. Delete its discarded `_ = module.fn(...)` line from `src/main.zig`.

A module that cannot be connected yet because a needed system is missing
(for example 3×3 crafting, taller worlds or more block IDs) stays out of
`main.zig` and is listed under that system below.

Good first candidates are mechanics whose blocks, items or mobs already exist
in the game: mob rules for mobs already in `src/entity/`, and redstone parts.
Creaking puppet entity runtime is integrated with sandwiched Creaking Hearts;
Blaze combat rules and snowball vulnerability are unified in `blaze_fortress` and
connected to live gameplay; Guardian and Elder Guardian combat and spike thorns rules
are unified in `ocean_monument` and connected to live gameplay; Beacon pyramid geometry,
status powers, and payment activation are unified in `beacon_aura` with live dynamic aura
range, health regeneration, and supercharged Haste mining multiplier connected; Strider mount
and lava locomotion rules are unified into `strider_mount` with warped fungus boost and feeding
connected to gameplay; Wither boss rules are unified in `wither_boss` (with duplicate
`wither_boss_phases` removed) with spawn charging invulnerability, birth explosion detonation,
and HUD boss bar tracking connected to gameplay; Ender Dragon fight rules are unified into `ender_dragon_fight`
(with duplicate `ender_dragon_arena_fight` removed) with crystal tether healing, recoil backlash, and projectile perch
deflection connected to gameplay; Bundle pouch rules and 16 dye colors are unified in `bundle_pouch` (with duplicate `bundle_dyeing_nesting` removed) with cauldron washing and hotbar item insertion/extraction connected to gameplay (all duplicate pairs listed in STATUS.md are now resolved); Wind charge rocket jump and Breeze deflection rules are unified in wind_charge (with duplicate breeze_wind_charge and breeze_jump_deflection removed) with fall distance reset, horizontal dash momentum, burst knockback/damage, audio/particles connected to gameplay; Camel mount rules are unified into `camel` (with duplicate `camel_mount_kinematics` and `camel_step_dash` removed) with 1.5-block step height, 2-block gap striding, dual seating, and right-click saddle dash impulse with audio and dust particles connected to gameplay; Elytra glide aerodynamics and rocket propulsion rules are unified into `elytra_aerodynamics` (with duplicate `elytra_flight_matrix` and `elytra_rocket_propulsion` removed) with forward rocket acceleration impulse along camera look vector, stall kinematics, durability wear/tattered wing state, and solid-block kinetic crash damage connected to gameplay; Warden behavior, scent tracking, sonic boom kinematics, and Sculk Shrieker warning rules are unified into `warden_deep_dark` (with duplicate `warden_scent_blast` and `warden_sonic_boom` removed) with Sculk Shrieker F-key interaction and direct stepping, acoustic shriek audio, dark portal particles, darkness effect duration, and Tier 4 Warden emergence warning connected to live gameplay; Mace combat rules, aerial smash kinematics, Wind Burst rebound, and combo scaling are unified in `mace_smash_kinematics` (with duplicate `mace_combat`, `mace_aerial_combos`, and `mace_velocity_scaling` removed) with kinetic smash damage scaling, fall damage negation, Wind Burst upward rebound impulse pop (7.0 m/s), shockwave particles, and audio connected to live gameplay; remaining candidates include redstone parts.

## 4. Pay down structure debt

- Move subsystems out of `main()` in `src/main.zig` into modules that own
  their state, starting with redstone, fluids, projectiles and dimension
  travel. Keep behavior unchanged and covered by tests.
- Show important feedback on screen instead of only in the terminal.
- Test target aggregation: research showed Zig 0.16 collects tests across
  same-module imports via lazy semantic analysis, causing per-file test roots
  to duplicate shared module tests. Before any future test target aggregation
  or grouping is considered, require automated proof of exact collected-case
  identity equivalence against current per-target roots to prevent accidental
  test case omission.

## 5. Systems that unlock blocked mechanics

- Taller worlds: vertical chunk stacking.
- Block IDs beyond 256, or block states.
- A 3×3 crafting table.

## Done

Phases 1 to 7 built the engine: window and OpenGL, chunks and meshing,
terrain, streaming and culling, picking and editing, lighting and sky,
persistence, physics, inventory and crafting, sound, mobs, textures, tools,
particles, redstone, falling blocks, fluids, hazards and pathfinding.
Phase 8 (roadmap items 43 to 533) added swimming, oxygen and underwater
effects, then mostly standalone world modules in waves of about ten. The
full milestone list is in Git history.
