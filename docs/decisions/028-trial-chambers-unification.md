# Decision 028: Trial Chambers modules unification and live gameplay integration

Accepted: 2026-11-14.

## Context
Trial Chambers mechanics, including Bogged skeletons, Ominous Bottle drinking consumption, Bad Omen / Trial Omen / Raid Omen transformation matrices, Trial Spawner wave scaling and hazard dynamics, Vault loot dispensing, multi-player player unlock tracking, and Vault Reset Tokens, were previously scattered across eight overlapping modules in `src/world/`:
- `src/world/ominous_trial.zig`: Base module for Bogged mob stats and mushroom shearing, Bad Omen / Trial Omen durations and conversion, OminousTrialSpawner state progression and hazards, and OminousVault unlock logic with high-tier loot table.
- `src/world/ominous_bottle_omen.zig`: Contained OminousBottleTier (tiers 1..5), 32-tick bottle drinking cadence, Bad Omen 100-minute duration, Raid Omen 30s countdown, Trial Omen spawner proximity transmutation, and milk cleansing.
- `src/world/ominous_bottle_matrix.zig`: Contained comprehensive omen transformation state machines (`PlayerOmenStatus`, `OminousBottleMatrix`), village/spawner proximity boundaries (64m / 14m), raid difficulty wave scaling, and inventory stacking.
- `src/world/trial_spawner_dynamics.zig`: Contained TrialSpawner state machine, eligible player detection, mob scaling formulas, periodic hazard timing, reward ejection, and 5% reset token roll.
- `src/world/trial_spawner_waves.zig`: Contained dynamic mob wave scaling (`scaleTotalMobs`, `scaleSimultaneousMobs`), ominous mob equipment generation (Chainmail/Iron with Protection I and Sharpness I), 8 hazard varieties, and 30-minute cooldown locks.
- `src/world/vault_loot_dispenser.zig`: Contained standard/ominous VaultBlock, per-player unlock tracking, showcase item spinning animation, 40-tick ejection cycle, and comparator signal calculation.
- `src/world/vault_multiplayer_reset.zig`: Contained multiplayer Vault tracking up to 64 players, Vault Reset Token unlocking, 5% token drop probability (`dropsVaultResetToken`), comparator signal output (0..15), and deterministic dispersion velocities.
- `src/world/trial_vault_reset.zig`: Contained standalone Vault unlock and token reset interaction flows.

In `src/main.zig`, seven unused imports were maintained alongside 12 discarded calls across Wave 18 and Wave 25 domain check blocks:
- `trial_spawner_dynamics_mod.mobCategory`
- `trial_spawner_dynamics_mod.OMINOUS_RESET_TOKEN_CHANCE`
- `trial_spawner_waves_mod.scaleTotalMobs` (called twice)
- `trial_spawner_waves_mod.COOLDOWN_TICKS`
- `vault_loot_dispenser_mod.requiredKey`
- `trial_vault_reset_mod.dropsVaultResetToken`
- `vault_multiplayer_reset_mod.requiredKey` (called twice)
- `vault_multiplayer_reset_mod.dropsVaultResetToken`
- `ominous_bottle_omen_mod.amplifierForTier`
- `ominous_bottle_matrix_mod.DRINKING_DURATION_TICKS`

## Decision
1. **Module ownership**: `src/world/ominous_trial.zig` is the single authoritative module for all Trial Chambers systems.
   - Preserves base Bogged mob stats (`bogged_max_health = 16.0`, `bogged_fire_interval = 3.5`), mushroom shearing (`shearBogged`, `shearBoggedWithTypes`), Ominous Bottle and Omen duration calculations (`calculateTrialOmenDuration`), `OminousTrialSpawner`, and `OminousVault`.
   - Organizes merged subsystems into clean, public, scoped namespaces:
     - `pub const dynamics = struct { ... };` (from `trial_spawner_dynamics.zig`)
     - `pub const waves = struct { ... };` (from `trial_spawner_waves.zig`)
     - `pub const bottle_omen = struct { ... };` (from `ominous_bottle_omen.zig`)
     - `pub const bottle_matrix = struct { ... };` (from `ominous_bottle_matrix.zig`)
     - `pub const vault_dispenser = struct { ... };` (from `vault_loot_dispenser.zig`)
     - `pub const vault_multiplayer = struct { ... };` (from `vault_multiplayer_reset.zig`)
     - `pub const vault_reset = struct { ... };` (from `trial_vault_reset.zig`)
   - Exposes top-level canonical aliases for external callers (`scaleWaveMobs`, `scaleWaveSimultaneous`, `rollVaultResetToken`, `getRequiredVaultKey`, `spawnerMobCategory`, `ominousBottleAmplifier`, `ominousDrinkingTicks`).
   - Retains all 275 original unit tests plus 1 master declaration verification test (276 unit tests total), all passing cleanly under `zig test src/world/ominous_trial.zig`.
   - Removed duplicate files `src/world/ominous_bottle_omen.zig`, `src/world/ominous_bottle_matrix.zig`, `src/world/trial_spawner_dynamics.zig`, `src/world/trial_spawner_waves.zig`, `src/world/vault_loot_dispenser.zig`, `src/world/vault_multiplayer_reset.zig`, and `src/world/trial_vault_reset.zig` via `git rm`, and removed them from `test_files` in `build.zig`.
2. **Gameplay integration in `src/main.zig`**:
   - Removed all 7 unused imports and all 12 discarded calls.
   - Connected Vault keyhole states, player unlock tracking, comparator signals, and Vault Reset Tokens:
     - Unlocking `.vault` with `.trial_key` or `.ominous_vault` with `.ominous_trial_key` checks if player already unlocked the vault (`keyholeIsDark`). If unlocked, interaction is rejected without consuming key.
     - Interacting with `.vault` or `.ominous_vault` while holding a `.vault_reset_token` resets the player's lock, consuming one token and allowing the vault to be re-unlocked.
     - Unlocking an `.ominous_vault` rolls for the 5% bonus Vault Reset Token drop (`dropsVaultResetToken(true, roll)`).
     - Unlocking vaults calculates redstone comparator signal strength (`comparatorOutput`) for nearby players and logs feedback.
   - Connected Ominous Bottle consumption and Trial Spawner state progression:
     - Drinking `.ominous_bottle` applies 900.0s Trial Omen duration (`calculateTrialOmenDuration(1)`), upgrades `ominous_spawner` to ominous mode, scales total wave mobs with `waves.scaleTotalMobs(BASE_TOTAL_MOBS, 1)`, and activates the spawner.
     - Spawner hazard ticking (`tickHazardTimer(dt)`) emits periodic hazards (wind charges, fire charges, lingering potions) with particle bursts and sound feedback.
