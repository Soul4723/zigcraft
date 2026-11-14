# Decision 026: Crafter automation, factory clocking, and pulsed grid unification

Accepted: 2026-11-14.

## Context
Crafter rules, 9-slot grid toggling, round-robin hopper feeding, redstone rising-edge pulsing, factory clocking, and single-input autocrafting were previously spread across four overlapping modules in `src/world/`:
- `src/world/autocrafter.zig`: Contained single-input autocrafting (`autoCraftSingleInput`: logs to planks, planks to sticks, breeze rods to wind charges), Trial Vault loot rolls (`vaultLootForRoll`), and item tag constants.
- `src/world/crafter_automation.zig`: Contained `CrafterGrid`, 9-slot disabled/occupied bitmasks, `toggleSlot`, `setDisabled`, `insertFromHopper`, shaped offset recipe matching (`iron_block`, `crafting_table`, `torch`, `arrow`, `wooden_slab`), 8-game-tick cooldown (`cooldown_game_ticks = 8`), nozzle ejection velocity (`velocityFor`), mechanical failure click counting, and `0..9` comparator signal calculation. It had only a discarded dummy call `_ = crafter_automation_mod.slot_count;` in `src/main.zig`.
- `src/world/crafter_factory_clocking.zig`: Contained `ClockMode` (`one_redstone_tick = 2`, `four_redstone_ticks = 8`), `FactoryClock`, `ClockedCrafter` (`Crafter` with `0..15` proportional fullness comparator signal and 4-game-tick minimum craft delay), `HopperFeed` round-robin insertion with backpressure, and `FactoryPipeline` smelting-to-crafting throughput simulation. It had only a discarded dummy call `_ = crafter_factory_clocking_mod.ClockMode.four_redstone_ticks.periodGameTicks();` in `src/main.zig`.
- `src/world/crafter_pulsed_grid.zig`: Contained `Crafter` (9-slot pulsed grid supporting custom `Recipe` patterns or 9-ingot iron block crafting, `front_nozzle`, `NozzleOutput`, `directionVector`, `0..9` comparator signal), and `HopperRoundRobin`. It had only a discarded dummy call `_ = crafter_pulsed_grid_mod.slot_count;` in `src/main.zig`.

In live gameplay in `src/main.zig`, interacting with `.crafter` only ran `autoCraftSingleInput`, leaving the 9-slot grid, redstone rising-edge pulsing, factory clocking, comparator signal tracking, and directional nozzle feedback disconnected.

## Decision
1. **Module ownership**: `src/world/autocrafter.zig` is the single authoritative module for Crafter single-input autocrafting, 9-slot pulsed grid crafting, factory clocking, and round-robin hopper feeding.
   - Merged item enum `Item` (aliased as `ItemType`) and `Stack` (aliased as `ItemStack`) covering all variants across the four modules (`iron_ore`, `iron_ingot`, `iron_block`, `gold_ingot`, `gold_block`, `copper_ingot`, `copper_block`, `redstone`, `stick`, `torch`, `wood_planks`, `crafting_table`, `coal`, `flint`, `feather`, `arrow`, `wooden_slab`, `other`).
   - Kept all unified constants, types, and methods: `Crafter` and `HopperRoundRobin` (from `crafter_pulsed_grid.zig`), `CrafterGrid` and `GridCraftResult` / `EjectedItem` / `velocityFor` (from `crafter_automation.zig`), and `ClockMode`, `FactoryClock`, `ClockedCrafter`, `HopperFeed`, `PipelineReport`, and `FactoryPipeline` (from `crafter_factory_clocking.zig`), alongside `autoCraftSingleInput` and `vaultLootForRoll`.
   - Added `gridItemFromTag` and `tagFromGridItem` helpers to bridge inventory item tags in `src/items.zig` with `autocrafter.Item` cleanly without cross-directory imports.
   - Retained all unit tests across all four modules plus the new tag-mapping round-trip test (134 unit tests total in `src/world/autocrafter.zig`).
   - Removed duplicate modules `src/world/crafter_automation.zig`, `src/world/crafter_factory_clocking.zig`, and `src/world/crafter_pulsed_grid.zig` via `git rm`, and removed all three from `test_files` in `build.zig`.
2. **Gameplay integration in `src/main.zig`**:
   - Removed unused imports `crafter_automation_mod`, `crafter_factory_clocking_mod`, and `crafter_pulsed_grid_mod`, along with their three discarded dummy calls.
   - Added runtime state `active_crafter_grid`, `active_crafter_clock`, `active_crafter_pos`, and `crafter_tick_accum`.
   - Connected 20 Hz game-tick `FactoryClock` advancement and redstone rising-edge `CrafterGrid.tick` execution for the active `.crafter` block in the frame loop, ejecting crafted outputs to inventory with `.craft_item` / `.click_off` audio, nozzle-direction shimmer particles (`directionVector`), and comparator signal telemetry.
   - Enhanced F-key `.crafter` interaction to support single-input autocrafting (`autoCraftSingleInput`), manual grid loading (`gridItemFromTag` + `insertFromHopper`), and manual pulsing (empty hand, `redstone_dust`, `crafter_pulse_core`, or `crafter_pulsed_grid_controller`) with directional nozzle particles, audio, and `0..9` comparator signal reporting.
