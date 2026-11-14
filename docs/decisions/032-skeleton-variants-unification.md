# Decision 032: Skeleton variants, Bogged poison/shearing, and Stray freeze unification

Accepted: 2026-11-14.

## Context
Skeleton variant rules, Bogged poison arrow combat and mushroom shearing, Stray slowness arrows, Powder Snow freeze conversion, and Skeleton Trap horsemen were previously split across three overlapping modules in `src/world/`:
- `src/world/skeleton_variants.zig`: Contained `SkeletonVariant` (`.standard_skeleton`, `.icy_stray`, `.mossy_bogged`, `.nether_wither_skeleton`), `SkeletonFreezeConversionState`, `tickSkeletonPowderSnowConversion` (7s shake, 22s conversion to `.icy_stray`), `computeSkeletonArrowPayload`, `shouldDropSlownessArrowsOnPlayerKill`, `canEntityPassUnderCeiling`, `shouldSkeletonFleeWolf`, and `skeletonWeapon`.
- `src/world/bogged_stray_variants.zig`: Contained `Variant` (`.bogged`, `.stray`), `VariantAppearance`, `ArrowPayload`, `maxHealth`, `bowCooldownTicks` (70 ticks for Bogged, 40 ticks for Stray), `BoggedState`, `shearBogged`, Stray freezing immunity, and Skeleton Trap horseman probability/trigger rules. It only had discarded calls in `src/main.zig`.
- `src/world/bogged_poison_harvest.zig`: Contained `BOGGED_MAX_HEALTH`, `Difficulty`-scaled `PoisonStatusEffect` ticking (1.0 HP per 25 ticks, 1.0 HP floor), `PoisonArrow` kinematics, `BoggedEntity`, `checkDaylightBurn`, `shearBoggedWithRolls` / `shearBoggedItem` / `shearBoggedTool` / `shearBoggedPrng` (single-shear restriction, 2 mushrooms, 1 durability, `.shears_snip`, particle bursts), and Looting defeat drop tables. It only had a discarded `BOGGED_MAX_HEALTH` reference in `src/main.zig`.

In live gameplay, `.skeleton` mobs fired plain arrows with a fixed 1.8s cooldown, did not convert in Powder Snow, and had no Bogged or Stray variant state, shearing, or status payloads.

## Decision
1. **Module ownership**: `src/world/skeleton_variants.zig` is the single authoritative module for all skeleton variant rules (Standard Skeleton, Stray, Bogged, and Wither Skeleton).
   - Merged all constants, types, functions, and unit tests from `bogged_stray_variants.zig` (36 tests) and `bogged_poison_harvest.zig` (68 tests) into `src/world/skeleton_variants.zig` alongside its original 14 tests (118 unit tests total).
   - Deleted `src/world/bogged_stray_variants.zig` and `src/world/bogged_poison_harvest.zig` via `git rm`, and removed both entries from `test_files` in `build.zig`.
2. **Entity, item, and player wiring**:
   - Added `.red_mushroom` (`649`) and `.brown_mushroom` (`650`) to `ItemType` in `src/items.zig` (and enabled them in `mushroom_stew` crafting in `src/recipes.zig`).
   - Added `slowness_timer` and `slowness_speed_multiplier` with `applySlowness`, `isSlowed`, and `effectiveSlownessMultiplier` to `Player` in `src/player.zig` (cleared on `drinkMilk` and `respawn`, decayed in `tickVitals`).
   - Added `skeleton_variant` and `freeze_conversion` (`SkeletonFreezeConversionState`) to `Mob` in `src/entity/mob.zig`, with `initSkeletonVariant`, `shearBogged`, and sheep-only wool regrowth so sheared Bogged mushrooms never regrow.
   - Added `spawnSkeletonVariant`, `tryShearBogged`, `takeStrayConversionPos`, cave variant spawning (`.mossy_bogged` / `.icy_stray` / `.standard_skeleton`), and per-tick `tickSkeletonPowderSnowConversion` inside `MobManager.tick` in `src/entity/mob_manager.zig`.
   - Updated `src/entity/mob_renderer.zig` to render mossy Bogged bodies with red/brown mushroom caps (hidden after `is_sheared`), frosted Stray cloaks, and freeze-conversion tremor while `shaking`.
3. **Gameplay integration in `src/main.zig`**:
   - Removed `bogged_stray_variants_mod` and `bogged_poison_harvest_mod` imports and all discarded `_ = ...` calls for `skeleton_variants_mod`, `bogged_stray_variants_mod`, and `bogged_poison_harvest_mod`.
   - Connected `.shears` right-click interaction on Bogged skeletons via `mob_manager.tryShearBogged` to grant `.red_mushroom` / `.brown_mushroom`, play `.shears_snip` and `.click_on`, spawn moss/mushroom debris particles, and wear shears.
   - Connected skeleton archery to record `arrow_variant` and variant bow cooldowns (3.5s Bogged, 2.0s Stray), and applied `computeSkeletonArrowPayload` on unblocked arrow hits (Poison I for Bogged, Slowness I reducing `walk_speed` via `player.effectiveSlownessMultiplier()` for Stray), plus Stray `.arrow_of_slowness` drops on defeat and Powder Snow conversion particle/toast feedback.
