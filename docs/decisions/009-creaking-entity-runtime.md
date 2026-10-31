# Decision 009: Creaking Entity Lifecycle and Runtime Integration

## Status
Accepted (2026-10-31)

## Context
Following the integration of natural Creaking Hearts and resin extrusion (PR 371), the Creaking mob entity required connection to live gameplay. The mechanic entails nocturnal spawning from sandwiched Creaking Hearts, pursuit of nearby players within a 32-block tether radius, complete gaze-freeze when watched under unobstructed line of sight, direct hit invulnerability, and shared resin extrusion cooldowns between puppet strikes and in-world heart interaction.

## Options Considered

1. **Standalone Duplicate Rule Modules**
   - Reintroduce separate state trackers and rule scripts (similar to the deleted `creaking_heart_puppet.zig` and `creaking_damage_link.zig`).
   - Rejected: Re-creates duplicate code, fragments mob lifecycle outside `MobManager`, and desynchronizes heart tracking from live gameplay.

2. **Index or Pointer-Based Linkage**
   - Store array indices or pointers linking `CreakingHeartTracker` slots to items in `MobManager.mobs`.
   - Rejected: `MobManager.mobs` is a dynamic `std.ArrayList(Mob)` subject to `swapRemove` and capacity reallocations. Indices shift on any despawn or mob death, and pointers dangle, leading to stale reference bugs.

3. **Direct Coordinate Link on Mob + Consolidated Cooldown Authority**
   - Store optional `creaking_heart_pos: ?[3]i32` on the `Mob` struct.
   - `MobManager` owns mob lifecycle, movement, and one-puppet-per-heart enforcement.
   - `CreakingHeartTracker` owns strictly the 5-second per-heart resin cooldown, shared by both direct puppet strikes and F-key heart interactions.
   - `pale_garden` owns gaze cone dot-product checks and 3D DDA voxel occlusion raycasting (`isLineOfSightClear`).
   - Chosen: Zero heap overhead, immune to `swapRemove` array shifts, and integrates cleanly into existing entity and world systems.

## Decision
Adopt Option 3:
- **Lifecycle & Identity**: `MobManager` scans loaded chunks on a rate-limited 1-second interval, spawning at most one Creaking per natural sandwiched heart in the Overworld at night.
- **Gaze & Occlusion**: `isCreakingObserved` in `pale_garden.zig` computes FOV cone alignment and traverses intervening voxels via Amanatides & Woo 3D DDA. The Creaking freezes only when line of sight is unobstructed by opaque blocks and the player is not wearing a carved pumpkin.
- **Invulnerability & Shared Resin Cooldown**: Direct attacks against the Creaking deal 0 damage to puppet HP and trigger resin extrusion through the shared `CreakingHeartTracker` cooldown.
- **Removal**: The puppet is cleanly removed at dawn, upon heart destruction or log unalignment, when tether radius exceeds 32 blocks, or on successful dimension transitions.
- **Weather Deferral**: Daytime thunderstorm heart activation is structurally supported in `canActivateBlocks`, but runtime activation defaults to nighttime since weather simulation is currently static clear sky.
