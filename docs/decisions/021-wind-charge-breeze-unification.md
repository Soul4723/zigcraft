# Decision 021: Wind Charge and Breeze rules unification, fall distance reset, and horizontal dash momentum integration

Accepted: 2026-11-04.

## Context
Wind Charge and Breeze mob mechanics were duplicated across three overlapping modules in `src/world/`:
- `src/world/wind_charge.zig`: Defined basic wind charge launch speed (28.0 m/s), burst radius (3.5m, radius squared 12.25), self boost vertical velocity (9.5 m/s looking down, 5.225 m/s partial boost), knockback impulse (6.0 horizontal, 6.5 vertical), 1 wind damage, and distance checking functions.
- `src/world/breeze_wind_charge.zig`: Defined Breeze mob entity stats (30.0 HP, 0.6 friction, 1.8 eye height, 0.35 swirl), ballistic leap arcs (`calculateLeap`, `leapPosition`, max 15.0m distance, 5.0m height, 9.8 gravity), water damage susceptibility (`takesWaterDamage`), projectile reflection (`deflectProjectile`, 0.8 damping), linear wind charge attack with 40-tick cooldown (`WindCharge`, `BreezeAttack`), wind burst actuation on interactive blocks (buttons, levers, doors, trapdoors via `actuateByWind`), and Breeze rod drops (`breezeRodDrops`, tag 371).
- `src/world/breeze_jump_deflection.zig`: Defined Milestone 524 rocket jump kinematics and Breeze deflection dynamics: vertical boost (+9.5 m/s), horizontal dash speed (7.0 m/s), 1.5m blast radius for rocket jump triggering, aim-dependent horizontal dash momentum conversion, player fall distance reset to 0.0 preventing fall damage upon rocket jumping, automatic physical projectile deflection with 0 damage to Breeze and redirect toward shooter/targets (`deflectTowardTarget`, `BreezeEntity`), and inventory wind charge consumption.

In `src/main.zig`, unused imports `breeze_jump_deflection_mod` and `breeze_wind_charge_mod` were kept with discarded dummy calls:
- `_ = breeze_wind_charge_mod.takesWaterDamage(false);`
- `_ = breeze_jump_deflection_mod.VERTICAL_BOOST_VY;`

In live gameplay, right-clicking with a Wind Charge applied self boost vertical velocity and knockback to nearby mobs, but did not reset player fall distance (`player.fall_distance = 0.0`), did not apply horizontal dash momentum when angled, did not deal 1 wind damage to mobs, and did not use portal particles.

## Decision
1. **Module ownership**: `src/world/wind_charge.zig` is the single authoritative module for Wind Charge rocket jumping, burst radii, Breeze mob jump arcs, and projectile deflection rules.
   - Merged constants (`VERTICAL_BOOST_VY = 9.5`, `HORIZONTAL_DASH_SPEED = 7.0`, `ROCKET_JUMP_RADIUS = 1.5`, `DEFLECTION_DAMPING = 0.8`, `WIND_CHARGE_LAUNCH_SPEED = 28.0`, `wind_charge_speed = 28.0`, `wind_burst_radius = 3.5`, `wind_burst_radius_sq = 12.25`, `self_boost_vy = 9.5`, `mob_knockback_vy = 6.5`, `BREEZE_MAX_HEALTH = 30.0`, `max_health = 30.0`, `breeze_rod_tag = 371`).
   - Merged structures and helper functions: `BreezeEntity`, `EntityState`, `calculateLeap`, `leapPosition`, `takesWaterDamage`, `ProjectileKind`, `isPhysicalProjectile`, `Projectile`, `deflectProjectileWithDamage`, `deflectProjectile`, `deflectTowardTarget`, `DeflectionResult`, `WindCharge`, `BreezeAttack`, `BurstHit`, `resolveWindBurst`, `InteractiveBlock`, `actuateByWind`, `breezeRodDrops`, `ItemType`, `ItemStack`, `PlayerInventory`, `consumeWindCharge`, `WindChargeProjectile`, `RocketJumpImpulse`, `isWithinRocketJumpRadius`, `calculateAngleDashVelocity`, `calculateDashVelocityFromPitch`, `calculateRocketJumpImpulse`, `calculateRocketJumpImpulseFromAim`, `resolveRocketJump`, `estimateJumpHeight`, and `Player` test model.
   - Retained all 10 unit tests from `src/world/wind_charge.zig`, all 40 unit tests from `src/world/breeze_wind_charge.zig`, and all 37 unit tests from `src/world/breeze_jump_deflection.zig` (87 unit tests total, 209 including imported block tests).
   - Removed duplicate modules `src/world/breeze_wind_charge.zig` and `src/world/breeze_jump_deflection.zig` using `git rm`, and removed both from `test_files` in `build.zig`.
2. **Gameplay integration in `src/player.zig` and `src/main.zig`**:
   - Added `fall_distance: f32 = 0.0`, `vel_x: f32 = 0.0`, and `vel_z: f32 = 0.0` to the live `Player` struct in `src/player.zig`, with physics updates consuming and damping `vel_x`/`vel_z` and accumulating/resetting `fall_distance`.
   - Removed unused imports `breeze_jump_deflection_mod` and `breeze_wind_charge_mod` and removed both discarded dummy calls in `src/main.zig`.
   - In `wind_charge` right-click interaction in `src/main.zig`:
     - Decrements wind charge inventory count (`inventory.slots[selected_slot].decrement(1);`).
     - Resets accumulated player fall distance to zero (`player.fall_distance = 0.0;`), preventing self-fall damage upon rocket jumping.
     - Calculates self boost vertical velocity via `wind_charge_mod.calculateSelfBoostVy(player.vel_y, cam.pitch)`.
     - When pitch is above -70°, adds horizontal dash momentum: `player.vel_x += cam.front().x * 7.0; player.vel_z += cam.front().z * 7.0;`.
     - Applies knockback impulse and 1 wind damage to any nearby mobs within the 3.5m burst radius via `wind_charge_mod.isWithinBurstRadius` and `calculateKnockbackImpulse`.
     - Plays `.firework_blast` audio at 0.85 volume and spawns portal particles (`particles.spawnPortalParticles(.{ player.pos.x, player.pos.y, player.pos.z }, 12)`).
     - Prints `wind charge detonated (vy={d:.1})\n`.
