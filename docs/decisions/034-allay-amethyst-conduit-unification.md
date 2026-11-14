# Decision 034: Allay, Amethyst Geode, and Conduit unification

Accepted: 2026-11-14.

## Context
Three gameplay domains remained split across duplicate modules in `src/world/`:
- **Allay**: `src/world/allay_collector.zig` (19 tests: `AllayCollectorState`, note-block tethering, 32m collection, owner immunity, 2 HP/s regen) overlapped with `src/world/allay_amethyst_duplication.zig` (33 tests: `Allay`, `JukeboxSignal`, `DanceTick`, `feedAmethystShard`, 16m jukebox dancing, 6000-tick duplication cooldown, note-block delivery search).
- **Amethyst Geode & Budding**: `src/world/amethyst.zig` (14 tests: `BuddingNode`, `tickBuddingNode`, `findBuddingNode`, `clusterShardYield`, `isWithinBellHighlightRange`, `chimePitchMultiplier`) overlapped with `src/world/amethyst_geode_budding.zig` (15 tests: `GeodeShellLayer`, `BuddingAmethystRules`, `AmethystGrowthStage`, `GrowthFace`, `progressGrowthOnFace`, `AmethystHarvestYield`, `clusterShardFortuneYield`).
- **Conduit**: `src/world/conduit_frame.zig` (16 tests: `ConduitFrameBlock`, `evaluateConduitActivation`, `computeConduitPowerBuff`, `tickConduitHostileZap`) overlapped with `src/world/conduit_underwater_power.zig` (25 tests: `FrameBlock`, `countFrameBlocks`, `evaluateActivation`, `applyConduitPower`, `ZapState`, `tickHostileZap`).

In `src/main.zig`, unused imports `allay_amethyst_duplication_mod`, `amethyst_geode_budding_mod`, and `conduit_underwater_power_mod` existed only for discarded dummy calls, while the live Conduit pass bypassed water/frame validation, Amethyst budding/harvest rules were not wired, and Allay jukebox dancing and shard duplication were not connected.

## Decision
1. **Unify Allay rules in `src/world/allay_collector.zig`**:
   - Merged `Allay`, `AllayState`, `JukeboxSignal`, `DanceTick`, `NoteParticle`, `NoteBlockTarget`, `DuplicateResult`, `DuplicateOutcome`, `feedAmethystShard`, `distanceSq`, and `isJukeboxInDanceRange` alongside `AllayCollectorState` (52 module tests, 73 total including imported `jukebox_discs` tests).
   - Deleted `src/world/allay_amethyst_duplication.zig`.
2. **Unify Amethyst Geode and Budding rules in `src/world/amethyst.zig`**:
   - Merged `GeodeShellLayer`, `BuddingAmethystRules`, `AmethystGrowthStage`, `GrowthFace`, `all_growth_faces`, `progressGrowthOnFace`, `AmethystHarvestYield`, and `clusterShardFortuneYield` alongside `BuddingNode`, `tickBuddingNode`, `findBuddingNode`, `isWithinBellHighlightRange`, and `chimePitchMultiplier`.
   - Preserved `clusterShardYield(mined_with_pickaxe: bool)` and exposed the Fortune-aware wrapper as `clusterShardYieldWithFortune`, adding `findOrRegisterBuddingNode` and `advanceBuddingCluster` (30 tests total).
   - Deleted `src/world/amethyst_geode_budding.zig`.
3. **Unify Conduit rules in `src/world/conduit_frame.zig`**:
   - Merged `FrameBlock`, `countFrameBlocks`, `evaluateActivation`, `applyConduitPower`, `HostileAquaticMob`, `ZapEvent`, `ZapState`, and `tickHostileZap` alongside `evaluateConduitActivation`, `computeConduitPowerBuff`, and `tickConduitHostileZap`.
   - Added `ConduitCell`, `ConduitEnvironment`, and `scanConduitEnvironment` to verify the 3×3×3 water enclosure and count up to 42 valid frame materials across the three orthogonal 5×5 rings (42 tests total).
   - Deleted `src/world/conduit_underwater_power.zig`.
4. **Connect all three mechanics to live gameplay in `src/main.zig` and clean up `build.zig` / `src/items.zig`**:
   - Removed the 3 deleted files from `test_files` in `build.zig` and removed their imports and discarded calls from `src/main.zig`.
   - Connected Allay companion dancing to active playing jukeboxes (`.jukebox` F-key insertion now activates `active_jukebox` for the disc's full duration, note blocks tether `active_allay`), and right-clicking with `.amethyst_shard` calls `feedAmethystShard` to duplicate the dancing Allay with `.note_chime`/`.glowstone_chime` audio, shimmer/portal particles, and a 6000-tick cooldown.
   - Connected `.budding_amethyst` placement and F-key registration to `budding_nodes` growth ticks (`advanceBuddingCluster` maturing `.amethyst_cluster` onto open orthogonal faces), F-key chime resonance (`chimePitchMultiplier`), zero-drop `BuddingAmethystRules.dropsWhenMined`, and `.amethyst_cluster` shard yield (`calculateHarvestYield`: 2 by hand, 4 with pickaxe) in `src/main.zig` and `src/items.zig`.
   - Connected Conduit placement and F-key inspection to `scanConduitEnvironment`, `evaluateConduitActivation`, `computeConduitPowerBuff` (oxygen/water breathing, underwater night vision via `night_vision_timer`, and `1.167×` mining speed boost), and full-frame `tickConduitHostileZap` targeting underwater `.drowned`, `.guardian`, and `.elder_guardian` mobs within 8m every 2s.

## Consequences
- All three duplicate pairs are eliminated while keeping every existing test case and public API intact.
- Players can activate real Conduits with water + prismarine/sea lantern frames, farm Amethyst Clusters from Budding Amethyst without silk-touching the budding block, and dance/duplicate Allays with Jukeboxes and Amethyst Shards.
