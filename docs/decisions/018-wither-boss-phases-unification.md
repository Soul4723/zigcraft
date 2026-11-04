# Decision 018: Wither boss mechanics unification and spawn explosion integration

Accepted: 2026-11-04.

## Context
Wither boss mechanics were duplicated across two overlapping modules in `src/world/`:
- `src/world/wither_boss.zig`: Defined Wither boss phases (`WitherBossPhase`: `.spawning_invulnerable`, `.aerial_phase_1`, `.armored_phase_2_melee`, `.defeated`), `canSummonWitherBoss`, `WitherSkull` properties, aerial volleys, phase 2 flight/dash behaviors, and `WitherBoss` state tracking charging invulnerability over 220 ticks (`spawn_duration_ticks`), explosion radius, damage mitigation, and Nether Star drops.
- `src/world/wither_boss_phases.zig`: Milestone 485 duplicate containing parallel uppercase constant aliases (`MAX_HEALTH`, `PHASE_2_HEALTH`, `SPAWN_TICKS`, `BIRTH_EXPLOSION_POWER`, `BIRTH_BLAST_DAMAGE`, `DEATH_TICKS`, `DEFEAT_XP`, `NETHER_STAR_ITEM_ID`), pattern recognition types (`SummoningPattern`, `SummoningResult`, `checkSummoningPattern`), and duplicate combat simulation structures (`Boss`, `TickEvents`, `Target`, `SkullShot`).

In `src/main.zig`, an `active_wither` state was instantiated but initialized in its default invulnerable state without an active summon sequence or advance loop. When the wither skull T-pattern was placed, a champion mob was spawned, but `active_wither` was not triggered into its charging lifecycle, its birth explosion was never detonated, and two discarded dummy calls (`_ = wither_boss_mod.canSummonWitherBoss(...)` and `_ = wither_boss_phases_mod.SPAWN_TICKS;`) were executed each frame.

## Decision
1. **Module ownership**: `src/world/wither_boss.zig` is the single authoritative module for Wither boss summoning validation, phase transitions, charging invulnerability, skull projectiles, and defeat drops.
   - Merged uppercase constant aliases (`MAX_HEALTH`, `PHASE_2_HEALTH`, `SPAWN_TICKS`, `BIRTH_EXPLOSION_POWER`, `BIRTH_BLAST_DAMAGE`, `DEATH_TICKS`, `DEFEAT_XP`, `NETHER_STAR_ITEM_ID`, `TICKS_PER_SECOND`), pattern validation types (`SummoningPattern`, `SummoningResult`, `checkSummoningPattern`), and simulation types (`Boss`, `TickEvents`, `Target`, `SkullShot`, `SkullImpact`, `Projectile`, `NetherStarItemType`) into `wither_boss.zig`.
   - Added `startSpawning()` on `WitherBoss` to initialize the 220-tick invulnerable charging sequence.
   - Retained all tests from both files, yielding 56 comprehensive unit tests.
   - Removed duplicate module `src/world/wither_boss_phases.zig` using `git rm` and removed its entry from `test_files` in `build.zig`.
2. **Game loop and interaction integration**:
   - In `src/main.zig`, initialized `active_wither` with `.phase = .defeated` so it remains dormant until summoned.
   - Connected wither summoning: when the skull T-pattern is completed and the champion is spawned, `active_wither.startSpawning()` initiates the 220-tick invulnerable spawn charge and records the summon location.
   - Connected frame-loop spawn ticks: when `active_wither.phase == .spawning_invulnerable`, emits rising smoke and flame charging particles around the summon site/champion mob, and calls `advanceSpawnTick()`.
   - Connected birth explosion: when `advanceSpawnTick()` completes and transitions the phase to `.aerial_phase_1`, plays `.tnt_explode` concussive audio, emits explosive smoke and flame particle bursts, and logs `wither birth explosion detonated`.
   - Connected HUD boss bar: when `active_wither.phase != .defeated` and an active wither champion exists, renders its health fraction on the boss bar.
   - Defeating the champion sets `active_wither.phase = .defeated`, clearing the boss bar.
3. **Audio and VFX support**:
   - Added `tnt_explode` sound type and low-frequency concussive noise synthesizer in `src/audio/synth.zig`.
   - Added `spawnSmoke` dark particle generator in `src/renderer/particles.zig`.
4. **Discarded calls removed**: Removed unused import `wither_boss_phases_mod` and the discarded dummy calls `_ = wither_boss_mod.canSummonWitherBoss(...)` and `_ = wither_boss_phases_mod.SPAWN_TICKS;`.
