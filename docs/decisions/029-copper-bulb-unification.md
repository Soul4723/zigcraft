# Decision 029: Copper Bulb rules unification and live gameplay integration

Accepted: 2026-11-14.

## Context
Copper Bulb and copper fixture mechanics were previously split across three modules in `src/world/`:
- `src/world/copper_fixtures.zig`: Tracked `CopperFixtureKind` (`.copper_door`, `.copper_trapdoor`, `.copper_grate`, `.chiseled_copper`, `.copper_bulb`), `CopperOxidationStage`, `CopperFixtureState` (oxidation timers, waxing, axe scraping, redstone edge-triggered T-flip-flop `updateRedstonePower`, oxidation light levels 15/12/8/4, comparator output 15/0, and spatial lookup `findFixture`).
- `src/world/copper_bulb_latch.zig`: Duplicated Copper Bulb oxidation stages (`OxidationStage`), light levels (15/12/8/4), waxing, axe scraping, indicator dot (`IndicatorDot`), particle effect metadata (`ParticleEffect`, `ScrapeResult`), and 2-tick delayed latch (`CopperBulb`, `GAME_TICKS_PER_TOGGLE`).
- `src/world/copper_bulb_display.zig`: Implemented a 13-bulb 7-segment `CopperBulbDisplay` and two-digit `Cascade` matrix on top of `copper_bulb_latch.zig`.

In `src/main.zig`:
- `copper_bulb_latch_mod` was imported and unused, and `copper_bulb_display_mod` was imported only for a discarded `_ = copper_bulb_display_mod.decodeDigit(9);` call.
- F-key interaction on `.copper_bulb_off` / `.copper_bulb_on` called `archaeology_mod.toggleCopperBulb`, bypassing `copper_fixtures_mod`, oxidation stages, waxing, axe scraping, and comparator output.
- Copper door/trapdoor F-key interactions appended duplicate `CopperFixtureState` entries instead of looking up existing fixtures, and Copper Bulbs were not driven by redstone rising edges in the frame loop.

## Decision
1. **Module ownership**: `src/world/copper_fixtures.zig` is the single authoritative module for Copper Bulb latch, oxidation, 7-segment display matrix, and copper fixture rules.
   - Unified `CopperOxidationStage` with `OxidationStage` alias, `lightLevel()`, and `previous()`.
   - Added `ensureFixture` to `src/world/copper_fixtures.zig` for idempotent coordinate-based tracking up to `max_tracked_fixtures` (64).
   - Merged `GAME_TICKS_PER_TOGGLE`, `IndicatorDot`, `ParticleEffect`, `ScrapeResult`, `CopperBulb`, `DISPLAY_WIDTH`, `DISPLAY_HEIGHT`, `DISPLAY_DEPTH`, `BULB_COUNT`, `Segment`, `segment_a..segment_g`, `ALL_SEGMENTS`, `Coord`, `SegmentLayout`, `segment_layout`, `digit_masks`, `decodeDigit`, `decodeDigitClamped`, `Refresh`, `DigitUpdate`, `CopperBulbDisplay`, `Cascade`, and `bulbCoord` into `src/world/copper_fixtures.zig`.
   - Retained all unit tests: 24 original `copper_fixtures.zig` tests, 30 `copper_bulb_latch.zig` tests, and 37 `copper_bulb_display.zig` tests (91 tests in `copper_fixtures.zig`, plus 12 imported from `copper.zig` = 103 executed by `zig test src/world/copper_fixtures.zig`).
   - Removed `src/world/copper_bulb_latch.zig` and `src/world/copper_bulb_display.zig` via `git rm` and removed their `test_files` entries from `build.zig`.
2. **Gameplay integration in `src/main.zig`, `src/world/redstone.zig`, and `src/world/component_cache.zig`**:
   - Removed `copper_bulb_latch_mod` and `copper_bulb_display_mod` imports and the discarded `_ = copper_bulb_display_mod.decodeDigit(9);` call.
   - Added `redstone_mod.isBlockPowered` (powered wire or any `redstone_mod.isSource`) and included `.copper_bulb_off` / `.copper_bulb_on` in `component_cache.isTrackedRedstoneComponent` so both placed and chunk-loaded Copper Bulbs are registered in `copper_fixtures`.
   - Connected Copper Bulb redstone rising-edge T-flip-flop toggling (`cf.updateRedstonePower(power_in)`) in the redstone tick loop, updating the block between `.copper_bulb_off` and `.copper_bulb_on`, updating adjacent `.redstone_comparator_off`/`.redstone_comparator_on` blocks from `cf.getComparatorOutput()`, playing `.click_on`/`.click_off`, spawning glowstone shimmer when lit, and logging oxidation stage, waxed status, light emission (15/12/8/4), and comparator output (15/0).
   - Enhanced F-key interaction on `.copper_bulb_off` / `.copper_bulb_on` (and deduplicated `.copper_door_*` / `.copper_trapdoor_*` via `ensureFixture`):
     - Holding `.honeycomb` calls `cf.applyHoneycomb()`, consumes 1 honeycomb, plays `.glowstone_chime`, spawns glowstone shimmer, and logs stage, light level, and comparator output.
     - Holding any axe calls `cf.scrapeWithAxe()`, applies tool wear, plays `.anvil_clang`, spawns glowstone shimmer, and logs updated stage, waxed state, light level, and comparator output.
     - Otherwise toggles the bulb and updates adjacent comparators, audio, particles, and telemetry.
