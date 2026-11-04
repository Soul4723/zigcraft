# Decision 016: Beacon pyramid, aura, power, and supercharge unification

Accepted: 2026-11-04.

## Context
Beacon mechanics were fragmented across three overlapping modules:
- `src/world/beacon_aura.zig` (which modeled `supercharge_duration`, `hasteMultiplier`, `tickBeaconRegen`, and mineral base block tag checks `isBeaconBaseBlock`).
- `src/world/beacon_pyramid.zig` (which modeled pyramid geometry `validateBeaconPyramidTier`, power unlocks `validateBeaconPowerSelection`, beam occlusion `canBeaconBeamPassThroughBlock`, and stained glass color blending `blendBeaconBeamStainedGlassColors`).
- `src/world/beacon_status_pyramids.zig` (which modeled layer-by-layer structure validation `validatePyramid`, tier properties `tierProperties`, primary/secondary power selection `selectPowers`, mineral payment consumption `activate`, spherical aura bounds `isWithinEffectRadius`, and pulse timing `PulseClock`).

In `src/main.zig`, `beacon_pyramid_mod` and `beacon_status_pyramids_mod` were imported only to make discarded dummy calls (`_ = beacon_pyramid_mod.validateBeaconPyramidTier(...)` and `_ = beacon_status_pyramids_mod.tierProperties(.four)`). While right-clicking an active beacon with payment initiated a 300-second supercharge timer and health regeneration, the Haste effect did not accelerate mining speed, and the aura radius was hardcoded to a static 24m sphere regardless of pyramid tier or supercharge status.

## Decision
1. **Module ownership**: `src/world/beacon_aura.zig` is the single authoritative module for Beacon pyramid structure, aura, power selection, and supercharge mechanics.
   - Merged `BeaconPyramid`, `validateBeaconPyramidTier`, `BeaconEffect`, `BeaconPowerSelection`, `validateBeaconPowerSelection`, `canBeaconBeamPassThroughBlock`, and `blendBeaconBeamStainedGlassColors` from `beacon_pyramid.zig`.
   - Merged `Tier`, `TierProperties`, `tierProperties`, `MineralBlock`, `PaymentItem`, `PrimaryPower`, `SecondaryPower`, `validatePyramid`, `selectPowers`, `activate`, `isWithinEffectRadius`, `effectDurationSeconds`, and `PulseClock` from `beacon_status_pyramids.zig`.
   - Retained all tests from all three modules (73 tests total) in `beacon_aura.zig`.
   - Deleted duplicate modules `src/world/beacon_pyramid.zig` and `src/world/beacon_status_pyramids.zig` and removed their entries from `test_files` in `build.zig`.
2. **Haste mining multiplier connected**: In `src/main.zig`, during held-left mining progress calculations (`need = block_mod.mineTime(...)`), when `beacon_supercharge_timer > 0.0`, mining time is scaled down by Haste tier 2 multiplier (`need /= beacon_aura_mod.hasteMultiplier(1, true);`, reducing time needed by 1.40×).
3. **Dynamic aura radius connected**: In `src/main.zig`, during the beacon tick loop, the base block beneath the beacon is validated with `beacon_aura_mod.isBeaconBaseBlock(@intFromEnum(base_b))`. The aura effect radius dynamically evaluates to `beacon_aura_mod.auraRadiusForLevel(1)` (20m) for normal base beacons and `beacon_aura_mod.auraRadiusForLevel(4)` (50m) when supercharged.
4. **Discarded calls removed**: Removed imports `beacon_pyramid_mod` and `beacon_status_pyramids_mod` and their dummy discarded calls from `src/main.zig`.
