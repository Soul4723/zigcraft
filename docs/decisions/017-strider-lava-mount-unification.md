# Decision 017: Strider lava mount unification and warped fungus boost integration

Accepted: 2026-11-04.

## Context
Strider mount mechanics were duplicated across two overlapping modules in `src/world/`:
- `src/world/strider_mount.zig`: Contained StriderState with lava surface buoyancy (`computeLavaSurfaceBuoyancy`), shivering state (`computeShivering`, `getStriderColor`), movement speed calculation (`striderMovementSpeed`), warped fungus boost triggers (`triggerFungusBoost`), water contact damage (`waterContactDamage`), rider positioning offsets (`computeWorldRiderPosition`), breeding and growth mechanics (`breedStriders`, `accelerateBabyGrowth`), and unit tests.
- `src/world/strider_lava_mount.zig`: Milestone 484 duplicate containing parallel definitions of speed constants, `ThermalState`, `SoundEvent`, `ParticleEvent`, `Strider` entity, crafting and steering mechanics, and tests.

In `src/main.zig`, an `active_strider` state was instantiated and had its lava state updated each frame, but `active_strider.update(dt)` was not advanced, right-clicking with `warped_fungus_on_a_stick` was not connected to trigger speed boosts, and a dummy discarded call `_ = strider_lava_mount_mod.Strider.init(0, .init(0.0, 0.0, 0.0), false).getMovementSpeed();` was executed each frame.

## Decision
1. **Module ownership**: `src/world/strider_mount.zig` is the single authoritative module for Strider lava navigation, saddle mounting, warped fungus boosting, and thermal shivering mechanics.
   - Merged `ThermalState` (warm vs freezing with skinColor mapping), `SoundEvent`, `ParticleEvent`, uppercase constant aliases (`STRIDER_LAVA_SPEED`, `STRIDER_BOOST_SPEED_LAVA`, `STRIDER_BOOST_SPEED`, `STRIDER_LAND_SPEED`, `STRIDER_MAX_HEALTH`, `STRIDER_BABY_MAX_HEALTH`, `WARPED_FUNGUS_HEAL_AMOUNT`, `BOOST_DURATION_SECONDS`, `BOOST_DURABILITY_COST`, `WARPED_FUNGUS_STICK_MAX_DURABILITY`), `RiderPosition`, and helper aliases `computeRiderPosition` and `Strider` into `strider_mount.zig`.
   - Instrumented `StriderState` actions (`equipSaddle`, `triggerBoost`, `feedWarpedFungus`, `applyWaterDamage`, `setLavaState`) with `last_sound` and `last_particle` telemetry.
   - Preserved all 21 existing tests and added 3 new comprehensive tests (24 tests total).
   - Deleted duplicate module `src/world/strider_lava_mount.zig` using `git rm` and removed its entry from `test_files` in `build.zig`.
2. **Game loop and interaction integration**:
   - In `src/main.zig`, advanced `active_strider.update(dt)` in the frame loop.
   - Connected right-click input when holding `ItemType.warped_fungus_on_a_stick`: when `active_strider.is_on_lava` or player is in/on lava, activates speed boost via `strider_mount_mod.triggerFungusBoost(&active_strider, 100)`, wears 1 durability on the stick (`tool_wear.use(selected_slot, 100)`), clears the slot and plays `break_block` audio if broken, plays `lava_pop` audio, spawns flame particles, and prints status.
   - Connected right-click input when holding `ItemType.warped_fungus` to call `_ = active_strider.feedWarpedFungus()`.
3. **Discarded calls removed**: Removed unused import `strider_lava_mount_mod` and the discarded dummy call `_ = strider_lava_mount_mod.Strider.init(...).getMovementSpeed();`.
