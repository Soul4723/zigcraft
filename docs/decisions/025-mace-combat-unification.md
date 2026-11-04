# Decision 025: Mace combat rules, aerial smash kinematics unification, and live gameplay integration

Accepted: 2026-11-04.

## Context
Mace combat mechanics, two-tier kinetic fall scaling, enchantment scaling (Density, Breach, Wind Burst), and aerial combo rules were previously spread across four overlapping modules in `src/world/`:
- `src/world/mace_combat.zig`: Contained baseline weapon damage (6), smash fall threshold (1.5 blocks), max smash damage clamp (50), two-tier height scaling (+4.0/m for first 3m, +2.0/m beyond), durability (500), and `shouldNegateFallOnSmash`. It existed only as test code without runtime imports.
- `src/world/mace_smash_kinematics.zig`: Contained weapon base damage (6.0), attack speed (0.6 Hz, 33 ticks cooldown), durability (500), smash threshold (1.5m), shockwave radius (2.5m), two-tier fall scaling, Density enchantment (+0.5/lvl/m), Breach armor reduction (15%/lvl up to 60%), Wind Burst vertical impulses (7.0, 10.0, 13.0 m/s), unbreaking durability wear, and knockback target filtering.
- `src/world/mace_aerial_combos.zig`: Contained aerial combo damage multipliers (1.0x to 2.0x, +0.25 per combo), Wind Burst III launch speed (13.0 m/s), shockwave horizontal knockback and vertical pop (3.5 m/s) over a 3.5m radius, fall damage negation, and ground contact combo reset.
- `src/world/mace_velocity_scaling.zig`: Contained raw height scaling formula, kinetic damage calculation, Density bonus calculation, Breach effective armor calculation and reduction ratio, Wind Burst impulse extraction, aerial combo state tracking (`MaceComboTracker`), vanilla unmitigated fall damage formula, and comprehensive strike outcome calculation (`executeAttack`).

In `src/main.zig`, unused imports `mace_aerial_combos_mod` and `mace_velocity_scaling_mod` were kept with discarded dummy calls:
- `_ = mace_smash_kinematics_mod.calculateSmashDamage(2.0, 0);`
- `_ = mace_aerial_combos_mod.damageMultiplier(1);`
- `_ = mace_velocity_scaling_mod.BASE_DAMAGE;`

In live gameplay, the mace smash attack only set `player.vel_y = 0.0` on hit, did not zero `player.fall_distance` to negate accumulated fall damage, did not provide Wind Burst upward rebound impulse to enable aerial chaining, and lacked shockwave firework particles and blast sound feedback.

## Decision
1. **Module ownership**: `src/world/mace_smash_kinematics.zig` is the single authoritative module for Mace combat rules, kinetic smash damage scaling, enchantment modifiers, aerial combos, and shockwave physics.
   - Merged constants: `BASE_DAMAGE = 6.0`, `base_damage = 6.0`, `mace_base_damage = 6`, `SMASH_MIN_FALL_DISTANCE = 1.5`, `smash_min_fall_distance = 1.5`, `smash_threshold_m = 1.5`, `smash_max_damage = 50`, `FIRST_TIER_HEIGHT_LIMIT = 3.0`, `FIRST_TIER_DAMAGE_RATE = 4.0`, `SECOND_TIER_DAMAGE_RATE = 2.0`, `MAX_COMBO_MULTIPLIER = 2.0`, `max_combo_multiplier = 2.0`, `max_damage_multiplier = 2.0`, `COMBO_MULTIPLIER_STEP = 0.25`, `DENSITY_FACTOR_PER_LEVEL = 0.5`, `MAX_DENSITY_LEVEL = 5`, `BREACH_REDUCTION_PER_LEVEL = 0.15`, `MAX_BREACH_LEVEL = 4`, `WIND_BURST_I_VELOCITY = 7.0`, `WIND_BURST_II_VELOCITY = 10.0`, `WIND_BURST_III_VELOCITY = 13.0`, `wind_burst_iii_launch_speed = 13.0`, `secondary_vertical_pop_speed = 3.5`, `DURABILITY = 500`, `durability = 500`, `mace_durability = 500`, `attack_speed = 0.6`, `attack_cooldown_seconds = 1.67`, `attack_cooldown_ticks = 33`, `shockwave_radius = 2.5`, `shockwave_radius_m = 3.5`, and `resetFallOnSmash = true`.
   - Merged structures and helpers: `ExclusiveEnchantment`, `WindBurstLevel` (with `impulse()`), `HitKind`, `FallState`, `KnockbackTarget`, `PlayerState`, `SmashOutcome`, `ShockwaveEffect`, `MaceComboTracker`, `MaceAttackConfig`, `SmashExecutionResult`, `isSmashAttack`, `calculateRawHeightScaling`, `calculateKineticDamage`, `densityDamageBonus` (alias `calculateDensityBonus`), `calculateSmashDamage`, `calculateMaceDamage`, `shouldNegateFallOnSmash`, `breachArmorReduction` (alias `breachReductionRatio`), `effectiveArmorDefense` (alias `calculateEffectiveArmor`), `hasExclusiveEnchantmentConflict`, `resetFallStateOnSmash`, `shouldKnockbackTarget`, `windBurstVerticalImpulse` (alias `getWindBurstImpulse`), `getWindBurstImpulseFromInt`, `damageMultiplier` (alias `calculateComboMultiplier`), `calculateSmashDamageWithEnchantments`, `landSmash`, `onGroundContact`, `shockwaveEffect`, `calculateUnmitigatedFallDamage`, `durabilityWear`, and `executeAttack`.
   - Retained all unit tests: 30 from original `mace_smash_kinematics.zig`, 8 from `mace_combat.zig`, 34 from `mace_aerial_combos.zig`, 50 from `mace_velocity_scaling.zig`, and 2 helper verification tests (128 unit tests total).
   - Removed duplicate modules `src/world/mace_combat.zig`, `src/world/mace_aerial_combos.zig`, and `src/world/mace_velocity_scaling.zig` via `git rm`, and removed all three from `test_files` in `build.zig`.
2. **Gameplay integration in `src/main.zig`**:
   - Removed unused imports `mace_aerial_combos_mod` and `mace_velocity_scaling_mod`, and deleted the three discarded dummy calls.
   - Connected live smash attack mechanics on mob strike when `held_weapon == .mace and mace_smash_kinematics_mod.isSmashAttack(fall_blocks)`:
     - Negates player fall damage: `player.fall_distance = 0.0`.
     - Applies Wind Burst upward rebound velocity pop: `player.vel_y = mace_smash_kinematics_mod.WIND_BURST_I_VELOCITY;` (+7.0 m/s vertical rebound allowing aerial chaining).
     - Plays `.anvil_clang` (1.0) and `.firework_blast` (0.85) audio.
     - Spawns radial shockwave particles at the target mob: `particles.spawnFireworkBurst(.{ hit_mob.pos.x, hit_mob.pos.y + 0.8, hit_mob.pos.z }, 32)`.
     - Logs smash impact telemetry: `std.debug.print("mace smash landed: {d} damage (fall={d:.1}m, rebound vy={d:.1})\n", .{ hit_dmg, fall_blocks, player.vel_y });`.
