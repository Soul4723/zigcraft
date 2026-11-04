# Decision 023: Elytra flight aerodynamics unification, rocket propulsion vector, and kinetic crash damage integration

Accepted: 2026-11-04.

## Context
Elytra glide aerodynamics, firework rocket propulsion, durability wear, and kinetic wall collision damage were duplicated across three overlapping modules in `src/world/`:
- `src/world/elytra_aerodynamics.zig`: Defined base Elytra flight state (`ElytraFlightState`), deployment rules (`canDeployElytra`), maximum durability (`max_durability = 432`), tattered unusable threshold (`tattered_durability = 1`), phantom membrane repair (+108 durability per membrane, `repairWithPhantomMembrane`), 3D look vector computation (`computeLookVector`), aerodynamic dive acceleration and climb lift conversion (`stepElytraAerodynamics`), terminal dive airspeed (67.0 m/s), rocket boost speed (33.5 m/s), and kinetic wall impact damage (`computeKineticWallImpactDamage`).
- `src/world/elytra_flight_matrix.zig`: Defined wear probability scaling by Unbreaking enchantment level (`wearProbability`, `shouldConsumeWear`, `expectedFlightSeconds`), DurabilityState with Mending XP repair (`absorbExperience`), stall hysteresis kinematics (`stall_angle_degrees = 35.0`, `stall_speed_mps = 6.0`, `stall_recovery_speed_mps = 8.0`), nose-down vertical tumble on stall, and aerodynamic dive acceleration stepping (`stepAerodynamics`, `AerodynamicState`, `FlightFrame`).
- `src/world/elytra_rocket_propulsion.zig`: Defined Milestone 475 kinetic glide and firework rocket propulsion: flight state machine (`KinematicFlightState`: `.grounded`, `.falling`, `.gliding`, `.kinetic_impact`), firework rocket propulsion boost (`rocket_acceleration = 1.5 m/s²`, duration tiers 1..3, `FireworkRocketProps`, `computeRocketBoostDurationTicks`), explosive Firework Star blast damage (5.0 HP direct damage, `computeRocketBlastDamage`), kinetic crash collision damage (`computeKineticCrashDamage` at speed >= 10.0 m/s dealing `(v - 10.0) * 2.0` damage, resetting velocity and canceling flight), anvil membrane repair calculation (`calculateAnvilRepair`), and full controller simulation (`ElytraGlider`).

In `src/main.zig`, unused imports `elytra_flight_matrix_mod` and `elytra_rocket_propulsion_mod` were kept with discarded dummy calls:
- `_ = elytra_rocket_propulsion_mod.rocket_acceleration;`
- `_ = elytra_flight_matrix_mod.wearProbability(3);`

In live gameplay, mid-air spacebar triggered basic player gliding and right-clicking with a firework rocket initiated a timer, but rocket propulsion did not add forward directional impulse along the camera look vector (`cam.front()`), wing tattering at durability 1 did not halt flight, and high-speed collision with solid block walls (speed >= 10.0 m/s) did not inflict kinetic crash damage.

## Decision
1. **Module ownership**: `src/world/elytra_aerodynamics.zig` is the single authoritative module for Elytra glide aerodynamics, pitch conversion, kinetic wall crash damage, firework rocket propulsion boost, stall kinematics, and durability wear/repair rules.
   - Merged constants: `max_durability = 432`, `tattered_durability = 1`, `broken_durability = 1`, `membrane_repair_amount = 108`, `membrane_repair_percent = 25`, `max_horizontal_speed = 67.0`, `rocket_boost_speed = 33.5`, `rocket_acceleration = 1.5`, `default_rocket_duration = 1.5`, `kinetic_damage_threshold = 12.0`, `kinetic_damage_multiplier = 1.2`, `kinetic_crash_threshold = 10.0`, `kinetic_crash_multiplier = 2.0`, `firework_star_blast_damage = 5.0`, `dive_thrust_coefficient = 0.08`, `pitch_lift_coefficient = 0.06`, `drag_coefficient = 0.99`, `default_gravity = 0.05`, `ticks_per_second = 20`, `tier1_duration_ticks = 20`, `tier2_duration_ticks = 40`, `tier3_duration_ticks = 60`, `level_sink_speed = -1.2`, `glide_gravity = 9.81`, `horizontal_drag_coeff = 0.05`, `base_wear_probability = 1.0`, `stall_angle_degrees = 35.0`, `stall_speed_mps = 6.0`, `stall_recovery_speed_mps = 8.0`, `stalled_lift_multiplier = 0.1`, `terminal_dive_speed_mps = 67.5`, `dive_acceleration_mps2 = 9.81`, `mending_durability_per_xp = 2`.
   - Merged structures and helpers: `RocketBoostTier`, `FireworkRocketProps` (and alias `FireworkRocket`), `KineticCrashResult`, `evaluateKineticCrash`, `calculateKineticDamage`, `computeKineticCrashDamage`, `computeKineticWallImpactDamage`, `computeKineticWallImpactDamageFromVel`, `wearProbability`, `shouldConsumeWear`, `expectedFlightSeconds`, `DurabilityState`, `AerodynamicState`, `FlightFrame`, `stepAerodynamics`, `ElytraFlightState`, `canDeployElytra`, `canInitiateGlide`, `repairWithPhantomMembrane`, `calculateAnvilRepair`, `computeRocketBoostDurationTicks`, `computeRocketBlastDamage`, `Vec3`, `computeLookVector`, `computeLookVec3`, `computeRawPitchForces`, `computePitchAerodynamics`, `stepElytraAerodynamics`, `KinematicFlightState`, `FlightInput`, and `ElytraGlider` (with compatibility aliases `ElytraRocketPropulsion`, `ElytraKinematics`, and `ElytraFlightController`).
   - Retained all unit tests: 28 from `elytra_aerodynamics.zig`, 43 from `elytra_flight_matrix.zig`, and 35 from `elytra_rocket_propulsion.zig`, plus 3 unification helper tests (109 unit tests total).
   - Removed duplicate modules `src/world/elytra_flight_matrix.zig` and `src/world/elytra_rocket_propulsion.zig` using `git rm`, and removed both from `test_files` in `build.zig`.
2. **Gameplay integration in `src/main.zig`**:
   - Removed unused imports `elytra_flight_matrix_mod` and `elytra_rocket_propulsion_mod` and deleted both discarded dummy calls in `src/main.zig`.
   - Synchronized `active_elytra.deploy` on spacebar glide launch, checking `active_elytra.canFly()`.
   - In live gameplay when gliding and `active_elytra.rocket_boost_timer > 0.0`:
     - Computes forward camera vector `const cf = cam.front();`.
     - Applies forward propulsion vector along look direction with `boost_accel = elytra_aerodynamics_mod.rocket_acceleration * dt * 20.0`:
       `player.vel_x += cf.x * boost_accel;`
       `player.vel_z += cf.z * boost_accel;`
       `player.vel_y = @min(12.0, player.vel_y + cf.y * boost_accel);`
   - In live gameplay when gliding at high horizontal speed (intended horizontal speed >= 10.0 m/s) and colliding with a solid block face (kinetic crash):
     - Evaluates crash outcome using `elytra_aerodynamics_mod.evaluateKineticCrash(intended_h_speed)`.
     - Inflicts kinetic damage to `player.health`: `player.health = @max(0.0, player.health - crash.damage);`.
     - Halts horizontal velocity: `player.vel_x = 0.0; player.vel_z = 0.0;`.
     - Cancels gliding flight on both player and flight state: `player.stopGliding(); active_elytra.stopGliding();`.
     - Plays `.hurt` audio at 0.9 volume.
     - Logs `elytra kinetic crash: {d:.1} damage at {d:.1} m/s`.
   - Synchronizes `active_elytra.tick(dt)` durability wear and rocket boost timer with `player.rocket_boost_timer`, and ceases flight when wings tatter (`active_elytra.isTattered()`).
