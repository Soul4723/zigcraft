# Decision 027: Calibrated Sculk Sensor resonance and Sculk Shrieker fog/warning unification

Accepted: 2026-11-14.

## Context
Calibrated Sculk Sensor and Sculk Shrieker mechanics remained split across overlapping modules in `src/world/`:
- `src/world/calibrated_sculk.zig`: Defined `CalibratedSensor`, `VibrationFrequency` (u8), `matchesFilter` (0 = unfiltered), `triggerVibration`, `tickSensor`, and `findSensor` (14 tests).
- `src/world/calibrated_sculk_resonance.zig`: Defined canonical 1..15 vibration frequencies, `CalibratedSculkSensor` (`BlockPos`, 10-tick active + 1-tick cooldown), `AmethystBlock` cardinal adjacency resonance, and `AcousticRepeaterNetwork` (25 tests).
- `src/world/calibrated_sensor_chains.zig`: Defined the same 1..15 resonance model with `ResonanceChainNetwork`, `addRepeaterUnit`, `final_hop_reached`, and `max_distance_reached` (30 tests).
- `src/world/warden_deep_dark.zig`: Already unified Warden behavior, scent tracking, and sonic boom kinematics, plus `SculkShriekerWarning`, `ShriekResult`, `computeDarknessFogIntensity`, and `computeDarknessFogDistances` (96 tests).
- `src/world/sculk_shrieker_fog.zig`: Duplicated 40m Darkness aura pulsing, sine fog interpolation (`fogIntensity`, `fogDistances`), 200-tick shrieker cooldown, 12,000-tick calm decay, and 134-tick Warden emergence (`FogPlayer`, `FogSculkShrieker`, `FogWardenEmergence`, 34 tests).
- `src/world/sculk_shrieker_warning.zig`: Duplicated multi-player shrieker coordination (`SculkShriekerManager`), biome-gated Warden summoning (`BiomeType`, `SculkShrieker`, `PlayerTracker`), ring particles (`ShriekRingParticle`), and `SculkShriekerWarning.triggerShriekInBiome` (30 tests).

In `src/main.zig`, unused imports `sculk_shrieker_warning_mod`, `calibrated_sculk_resonance_mod`, `sculk_shrieker_fog_mod`, and `calibrated_sensor_chains_mod` were kept with 4 discarded calls, while `.calibrated_sculk_sensor` F-key interaction only played fixed audio and particles without calibrating frequencies, checking adjacent amethyst resonance, or driving redstone signal output.

## Decision
1. **Unify Calibrated Sculk Sensor mechanics in `src/world/calibrated_sculk.zig`**:
   - Preserved the existing `CalibratedSensor`, `VibrationFrequency`, `matchesFilter`, `triggerVibration`, `tickSensor`, and `findSensor` public API.
   - Added gameplay helpers `cycleFilterFrequency`, `comparatorSignal`, `findOrRegisterSensor`, `emitResonanceToNeighbors`, and `frequencyLabel`.
   - Merged the 1..15 canonical resonance table (`ResonanceFrequency`, `VibrationEvent`), `matchesRearFilter`, `CalibratedSculkSensor`, `AmethystBlock`, `ResonantVibration`, `ResonanceChainNetwork` (with `AcousticRepeaterNetwork` and `ResonanceNetwork` compatibility aliases), and standalone resonance helpers (`triggerResonanceVibration`, `tickResonanceSensor`, `findResonanceSensor`), retaining all 69 original tests plus 4 gameplay helper tests (73 tests total).
   - Removed duplicate `src/world/calibrated_sculk_resonance.zig` and `src/world/calibrated_sensor_chains.zig`.
2. **Unify Sculk Shrieker fog and warning rules in `src/world/warden_deep_dark.zig`**:
   - Preserved all existing `warden_deep_dark.zig` declarations and `SculkShriekerWarning.trigger` integration.
   - Upgraded `SculkShriekerWarning` and `ShriekResult` to include biome gating (`BiomeType`, `triggerShriekInBiome`) and tick helpers (`tickTicks`).
   - Merged `SculkShrieker`, `PlayerTracker`, `ShriekRingParticle`, `WardenEmergence`, `SculkShriekerManager`, `isPlayerSteppingOnShrieker`, `canSensorTransmitToShrieker`, `applyDarknessAura`, and the tick-based fog model (`FogPlayer`, `FogSculkShrieker`, `FogWardenEmergence`, `FogActivation`, `FogDistances`, `fogIntensity`, `fogDistances`, `SHRIEKER_DARKNESS_RADIUS = 40.0`), retaining all 160 unit tests (96 + 34 + 30).
   - Removed duplicate `src/world/sculk_shrieker_fog.zig` and `src/world/sculk_shrieker_warning.zig`.
3. **Connect `.calibrated_sculk_sensor` to live gameplay in `src/main.zig`**:
   - Removed the 4 unused imports and 4 discarded dummy calls, and removed the 4 deleted modules from `test_files` in `build.zig`.
   - Tracked live placed/interacted `.calibrated_sculk_sensor` instances in `calibrated_sensors`, ticking them every frame (`calibrated_sculk_mod.tickSensor`) and pruning broken sensors.
   - Connected F-key interaction to `cycleFilterFrequency` (1..15) and `triggerVibration`, plus live movement (freq 1), block break (freq 12), and block place (freq 13) vibrations.
   - Checked the 6 cardinal neighbors for `.amethyst_block` resonance: playing `.note_chime` + `.portal_hum`, spawning `particles.spawnGlowstoneShimmer` on both sensor and amethyst block, and relaying the vibration to downstream tuned sensors within 16m via `emitResonanceToNeighbors`.
   - Connected `calibrated_sculk_mod.comparatorSignal` into the redstone wire power pass so active calibrated sensors power adjacent redstone wire at signal strength 1..15.
