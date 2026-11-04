# Decision 022: Camel rules unification, gap striding, 1.5-block step height, and dash burst impulse integration

Accepted: 2026-11-04.

## Context
Camel mount mechanics, posture states, and navigation kinematics were duplicated across three overlapping modules in `src/world/`:
- `src/world/camel.zig`: Defined base camel state (`CamelState`), posture enum (`.standing`, `.sitting_down`, `.sitting`, `.standing_up`), cactus feeding and healing (+2.0 HP, 32.0 max health), baby camel growth acceleration (10% / 120s per cactus), breeding love mode, rider seat offsets (`driver_seat_standing`, `passenger_seat_standing`, `driver_seat_sitting`, `passenger_seat_sitting`), tall height melee attack reach thresholds (`canMeleeReachRider`), 1.5-block step height (`camel_step_height = 1.5`, `maxStepUpHeight`), 2-block gap stride (`max_gap_stride = 2`, `canCrossGap`), and dash impulse calculation (`max_dash_speed = 18.0`, `dash_hop_vy = 3.6`, `dash_cooldown_duration = 2.75s / 55 ticks`).
- `src/world/camel_mount_kinematics.zig`: Defined Milestone 446 desert camel kinematics: dual seating (`SeatSlot`, `DualSeating`, driver & passenger seat local vectors and yaw-rotated world coordinates), 1.5-block step height (`canStepOverObstacle`, `canClearFence`, `canClearWall`, `stepOverTerrain`), 2-block ravine striding without downward gravity dip (`canCrossGap`, `checkRavineStride`, `RavineStrideCheck`), dash charge and stamina recovery (`dash_initial_burst_velocity = 19.5`, `dash_max_distance = 12.0`, `dash_cooldown_duration = 2.75`, `dash_max_charge_time = 2.5`), posture transitions (`transition_sitting`, `transition_standing`, dismounted auto-sitting after 3.0s idle delay), rider input dispatching (`RiderInput`), and complete mount kinematics (`CamelMountKinematics`).
- `src/world/camel_step_dash.zig`: Defined step-assist and stamina mechanics: `STEP_HEIGHT = 1.5`, `MAX_STRIDE_GAP = 2.0`, `DASH_SPEED = 19.5`, `DASH_DISTANCE = 12.0`, `CHARGE_TICKS = 50`, `DASH_COOLDOWN_TICKS = 55`, `GRAVITY = 9.81`, obstacle step-over checks (`canStepOver`, `is_obstructed`), gap striding with height preservation (`canStrideGap`), constant gravity acceleration over wider gaps (`GapMotion`), and tick-based stamina charge/cooldown tracking (`DashState`).

In `src/main.zig`, unused imports `camel_mount_kinematics_mod` and `camel_step_dash_mod` were kept with discarded dummy calls:
- `_ = camel_mount_kinematics_mod.camel_step_height;`
- `_ = camel_step_dash_mod.canStrideGap(2.0);`

In live gameplay, right-clicking with a cactus fed the camel mount and right-clicking with a lead toggled camel posture, but dash stamina burst kinematics were not connected to player movement, and no dash saddle interaction existed.

## Decision
1. **Module ownership**: `src/world/camel.zig` is the single authoritative module for Camel mount kinematics, 2-player seating, 1.5-block step height, gap striding, posture states, and dash impulse mechanics.
   - Merged constants: `STEP_HEIGHT = 1.5`, `MAX_STRIDE_GAP = 2.0`, `DASH_SPEED = 19.5`, `DASH_DISTANCE = 12.0`, `DASH_COOLDOWN_TICKS = 55`, `CHARGE_TICKS = 50`, `GRAVITY = 9.81`, `TICK_SECONDS = 0.05`, `camel_step_height = 1.5`, `max_dash_speed = 18.0`, `dash_initial_burst_velocity = 19.5`, `dash_max_distance = 12.0`, `dash_cooldown_duration = 2.75`, `dash_cooldown_ticks = 55`, `dash_max_charge_time = 2.5`, `idle_sit_delay = 3.0`.
   - Merged structures and helper functions: `Vec3`, `SeatSlot`, `Seat`, `SeatOffset`, `Posture`, `CamelPosture`, `DashImpulse`, `computeDashImpulse`, `computeKinematicDashImpulse`, `canMeleeReachRider`, `maxStepUpHeight`, `canStepOver`, `is_obstructed`, `canStepOverObstacle`, `canClearFence`, `canClearWall`, `canStrideGap`, `canCrossGap`, `canCrossGapBlocks`, `RavineStrideCheck`, `checkRavineStride`, `TerrainStepResult`, `stepOverTerrain`, `GapMotion`, `rotateYaw`, `getSeatLocalPosition`, `getSeatOffset`, `computeWorldSeatCoords`, `computeWorldSeatPosition`, `DualSeating`, `DashState` (unified tick-based and time-based operations), `RiderInput`, `CamelMountKinematics`, and `CamelState`.
   - Retained all unit tests: 21 from `camel.zig`, 30 from `camel_step_dash.zig`, and 28 from `camel_mount_kinematics.zig` (79 unit tests total).
   - Removed duplicate modules `src/world/camel_mount_kinematics.zig` and `src/world/camel_step_dash.zig` using `git rm`, and removed both from `test_files` in `build.zig`.
2. **Gameplay integration in `src/renderer/particles.zig` and `src/main.zig`**:
   - Added `spawnDustParticles(self: *ParticleSystem, pos: [3]f32, count: usize)` to `src/renderer/particles.zig` to spawn sandy desert dust trail particles.
   - Removed unused imports `camel_mount_kinematics_mod` and `camel_step_dash_mod` and removed both discarded dummy calls in `src/main.zig`.
   - In camel right-click interaction in `src/main.zig`:
     - Added support for right-clicking with `ItemType.camel_dash_saddle` (or `saddle`).
     - Checks `if (camel_mount.canDash() and player.on_ground)`.
     - Triggers dash impulse: `const impulse = camel_mount.releaseDash(cam.yaw, true);`.
     - If triggered, adds horizontal impulse velocity to player momentum: `player.vel_x += imp.vx; player.vel_z += imp.vz;`.
     - Plays `.mob_growl` audio at 0.9 volume.
     - Spawns desert dust particles via `particles.spawnDustParticles(.{ player.pos.x, player.pos.y + 0.2, player.pos.z }, 10)`.
     - Starts the 2.75s stamina recovery cooldown.
     - Prints `camel dash released (v={d:.1}m/s)\n`.
     - Preserves existing cactus feeding (`feedCactus`) and lead posture toggling (`togglePosture`).
