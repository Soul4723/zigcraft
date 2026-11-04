# Decision 014: Blaze combat unification and gameplay wiring

Accepted: 2026-11-04.

## Context
Blaze mechanics were fragmented across two disconnected modules: `src/world/blaze_fortress.zig` (which modeled `BlazeAttackState`, hover altitude adjustments, brewing fuel, and snowball/water damage) and `src/world/blaze_fireball_artillery.zig` (which duplicated constants, drop logic, and attack phases). Meanwhile, `src/main.zig` imported `blaze_fireball_artillery_mod` only to discard `CHARGE_TICKS`, ticked `active_blaze_attack` unconditionally regardless of whether any Blaze mob existed, and allowed Blazes to shoot single fireballs every 2.5s via the generic Emberbeast cooldown loop without charging cues or 3-shot bursts. Furthermore, snowballs hitting Blazes dealt default 1 damage rather than applying canonical Blaze snowball vulnerability (3 damage).

## Decision
1. **Module ownership**: `src/world/blaze_fortress.zig` is the single authoritative module for Blaze combat and fortress mechanics. Canonical Minecraft constants (`ROD_COUNT: usize = 12`, `CHARGE_TICKS: u16 = 60`, `VOLLEY_SHOTS: u8 = 3`, `SHOT_INTERVAL_TICKS: u8 = 6`, `VOLLEY_COOLDOWN_TICKS: u16 = 100`, `EXPERIENCE_DROP: u8 = 10`, `BLAZE_ROD_DROP_CHANCE: f32 = 0.5`, `MAX_BLAZE_ROD_DROP: u8 = 4`) and looting drop evaluation (`rollBlazeRodDrop`) were merged into `blaze_fortress.zig`. The duplicate `src/world/blaze_fireball_artillery.zig` was removed along with its test entry in `build.zig`.
2. **Attack state & fireball volleys**: In `src/main.zig`, the unconditional tick and discarded `CHARGE_TICKS` reference were deleted. Blazes were decoupled from the generic Emberbeast fireball loop. Instead, `active_blaze_attack` ticks when an active Blaze mob is within fireball range of the player:
   - While `active_blaze_attack.isVisuallyOnFire()`, charging/firing flame particles (`spawnFlame`) spawn around the mob.
   - When `active_blaze_attack.tick(dt)` returns shots > 0, the Blaze launches `shots` hostile fireballs aimed at the player using `proj_mod.fireballVelocity` with audio (`.lava_pop`) and flame bursts.
3. **Snowball vulnerability**: When a thrown snowball hits a Blaze mob in `src/main.zig`, damage is calculated via `blaze_fortress_mod.resolveSnowballOrWaterHitOnBlaze(true, false)` (3 damage, 3× ordinary projectile damage). Fiery sizzle audio (`.burn_sizzle`) and contact sparks (`spawnBurnSparks`) provide distinct audiovisual feedback.
