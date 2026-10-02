# Decision 004: Lightweight Voxel Entity System with Segmented Box Meshing

## Status
Accepted (2026-10-02, Session 021)

## Context
Milestone 29 calls for introducing mobs and entities into Zigcraft. The system requires physics (gravity, collision with world voxels, obstacle stepping), simple wandering AI, and 3D textured voxel rendering that fits naturally into the Minecraft-style aesthetic.

## Options Considered

1. **Entity-Component-System (ECS) Framework**
   - Full ECS architecture (archetypes, systems, sparse sets).
   - High complexity overhead for small initial mob populations (5-20 entities).
   - Unnecessary indirection at current project phase.

2. **Custom Modular Entity Struct + Dynamic Instanced/Segmented Voxel Meshing**
   - Simple `Mob` struct with position, velocity, rotation (`yaw`), animation timer, and state machine.
   - Segmented multi-box renderer (`body`, `head`, `legs`) textured via procedural atlas tiles.
   - Dynamic batching into a single GPU buffer per frame.
   - Shared AABB collision logic with player physics (`collideAxis`).

## Decision
Implement the modular entity model and segmented box mesher:
- `src/entity/mob.zig`: Core entity physics, wandering AI, step-up obstacle navigation, and limb swing animations.
- `src/entity/mob_renderer.zig`: Segmented multi-box geometry generator with limb animation transforms rendered through standard chunk/textured shaders.
- `src/entity/mob_manager.zig`: Herd population manager that dynamically populates the local world around the player.
