# Decision 024: Warden behavior, scent tracking, sonic boom kinematics unification, and Sculk Shrieker warning integration

Accepted: 2026-11-04.

## Context
Warden sensory behavior, scent tracking, sonic boom kinematics, and Sculk Shrieker warning rules were duplicated across three overlapping modules in `src/world/`:
- `src/world/warden_deep_dark.zig`: Defined base Deep Dark block conversions (`isConvertibleBlock`, `convertBlock`), Sculk Catalyst soul bloom spread radius (`sculkSpreadRadius`, `BloomCharge`, `SculkCatalyst`), Sculk Shrieker warning progression and cooldown (`SculkShriekerWarning`, `ShriekResult`), Darkness status effect fog calculation (`computeDarknessFogIntensity`, `computeDarknessFogDistances`), Warden anger tracking and smell/vibration state machine (`WardenAngerTracker`, `WardenState`), and basic Sonic Boom attack calculations (`isTargetInSonicBoomRange`, `computeSonicBoomAttack`).
- `src/world/warden_scent_blast.zig`: Defined 20 Hz periodic scent tracking cadence (`SCENT_INTERVAL_TICKS = 84`, `SCENT_RANGE = 16.0`, `SCENT_SUSPICION = 35`), multi-player suspicion accumulation (`Player`), suspicion thresholds (`CALM_SUSPICION_LIMIT = 40`, `ROAR_SUSPICION_LIMIT = 80`, `CHASE_SUSPICION_LIMIT = 150`), calm wander speed (`CALM_WANDER_SPEED = 1.0 m/s`), chase speed (`CHASE_SPEED = 4.2 m/s`), calm suspicion decay (`CALM_DECAY_INTERVAL_TICKS = 20`), and horizontal penetrating beam sonic blast (`resolveSonicBlast`, `hitPlayerWithSonicBlast`).
- `src/world/warden_sonic_boom.zig`: Defined Warden entity attributes (`WARDEN_MAX_HEALTH = 500.0`, `WARDEN_MELEE_DAMAGE = 30.0`), invulnerable emergence animation (`EMERGENCE_TICKS = 134`), quiet calm burrowing timeout (`CALM_BURROW_TICKS = 1200`), sonic boom charging and cooldown (`SONIC_BOOM_CHARGE_TICKS = 34`, `SONIC_BOOM_COOLDOWN_TICKS = 100`, `SONIC_BOOM_RANGE = 15.0`, `SONIC_BOOM_DAMAGE = 10.0`), 3D knockback impulse vector (`sonicBoomImpulse`, `SONIC_BOOM_VERTICAL_IMPULSE = 6.0`, `SONIC_BOOM_HORIZONTAL_IMPULSE = 8.0`), periodic Darkness aura pulsing (`DARKNESS_RADIUS = 20.0`, `DARKNESS_PULSE_TICKS = 120`), and combat hit application (`hitPlayerWithSonicBoom`).

In `src/main.zig`, unused imports `warden_scent_blast_mod` and `warden_sonic_boom_mod` were kept with discarded dummy calls:
- `_ = warden_sonic_boom_mod.SONIC_BOOM_RANGE;`
- `_ = warden_scent_blast_mod.SCENT_RANGE;`

In live gameplay, Sculk Shrieker blocks were not interactable and did not trigger warnings, sound, or darkness upon player contact or F-key use.

## Decision
1. **Module ownership**: `src/world/warden_deep_dark.zig` is the single authoritative module for Warden behavior, scent tracking, sonic boom kinematics, Sculk Shrieker warnings, and Sculk Catalyst soul spreads.
   - Merged constants: `SONIC_BOOM_RANGE = 15.0`, `SONIC_BOOM_DAMAGE = 10.0`, `SCENT_RANGE = 16.0`, `SCENT_INTERVAL_TICKS = 84`, `SCENT_SUSPICION = 35`, `ROAR_DURATION_TICKS = 40`, `CALM_WANDER_SPEED = 1.0`, `CHASE_SPEED = 4.2`, `SONIC_BOOM_VERTICAL_IMPULSE = 6.0`, `SONIC_BOOM_HORIZONTAL_IMPULSE = 8.0`, `DARKNESS_RADIUS = 20.0`, `DARKNESS_PULSE_TICKS = 120`, `EMERGENCE_TICKS = 134`, `CALM_BURROW_TICKS = 1200`, `CALM_SUSPICION_LIMIT = 40`, `ROAR_SUSPICION_LIMIT = 80`, `CHASE_SUSPICION_LIMIT = 150`, `CALM_DECAY_INTERVAL_TICKS = 20`, `SONIC_BLAST_REACH = 15.0`, `SONIC_BLAST_DAMAGE = 10.0`, `SONIC_BLAST_VERTICAL_KNOCKBACK = 6.0`, `SONIC_BLAST_HORIZONTAL_KNOCKBACK = 8.0`, `WARDEN_MAX_HEALTH = 500.0`, `WARDEN_MELEE_DAMAGE = 30.0`, `WARDEN_HOSTILE_SPEED = 4.2`, `WARDEN_SNIFF_RANGE = 16.0`, `WARDEN_SNIFF_INTERVAL_TICKS = 100`, `WARDEN_OPTICAL_SIGHT_RANGE = 0.0`, `VIBRATION_AGITATION = 35`, `ROAR_AGITATION_THRESHOLD = 80`, `HOSTILE_AGITATION_THRESHOLD = 150`, `SONIC_BOOM_CHARGE_TICKS = 34`, `SONIC_BOOM_COOLDOWN_TICKS = 100`, `MELEE_RANGE = 3.0`.
   - Merged structures and helpers: `Position`, `distance`, `Velocity`, `Player`, `State`, `TickEvents`, `Warden`, `SonicBlastResult`, `resolveSonicBlast`, `hitPlayerWithSonicBlast`, `SonicBoomImpulse`, `sonicBoomImpulse`, `WardenBehavior` (with compatibility alias `WardenSonicBoom`), `BoomResult`, `PlayerCombatState`, `resolveSonicBoom`, `hitPlayerWithSonicBoom`, and `SculkShriekerWarning.trigger`.
   - Retained all unit tests: 21 from `warden_deep_dark.zig`, 37 from `warden_scent_blast.zig`, 37 from `warden_sonic_boom.zig`, and 1 integration trigger test (96 unit tests total).
   - Removed duplicate modules `src/world/warden_scent_blast.zig` and `src/world/warden_sonic_boom.zig` using `git rm`, and removed both from `test_files` in `build.zig`.
2. **Gameplay integration in `src/main.zig`**:
   - Removed unused imports `warden_scent_blast_mod` and `warden_sonic_boom_mod` and deleted both discarded dummy calls in `src/main.zig`.
   - Connected Sculk Shrieker block interaction (`target == .sculk_shrieker`) via F key and direct physical player stepping to `active_shrieker_warning.trigger(player.pos.x, player.pos.y, player.pos.z, hit_f.x, hit_f.y, hit_f.z)`.
   - On shrieker trigger:
     - Plays `.mob_roar` (volume 1.0) and `.portal_hum` (volume 0.9) audio.
     - Spawns mystical dark portal particles via `particles.spawnPortalParticles(.{ hit_f.x + 0.5, hit_f.y + 0.8, hit_f.z + 0.5 }, 12)`.
     - Logs `sculk shrieker shrieked (warning_level={d}/4)`.
     - If warning level reaches 4, activates a 3.0s HUD toast (`toast.color = .{ 0.1, 0.6, 0.8 }`), spawns portal vortex particles, and prints Warden emergence warning.
   - Synchronizes active Darkness effect in the frame loop with rhythmic portal particle emission around the player when `active_shrieker_warning.hasDarkness()` is active.
