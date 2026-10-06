# Decision 007: Discrete Tick Falling Block Simulation

## Status
Accepted (2026-10-06, Sessions 063-079)

## Context
Gravity-affected blocks like sand must fall when unsupported without requiring a full continuous rigid-body physics simulator.

## Decision
1. **Detection Window:**
   - On tick, scan blocks in player interaction radius. If block is sand and cell directly below is non-solid (air, water, torches, redstone components), convert block to active falling entity.
2. **Falling Resolution:**
   - Drop speed is stepped discretely.
   - Non-solid fragile blocks (torches, redstone wire, repeaters) are crushed and popped to air.
   - Water cells create splash particle bursts and replace water with sand.
   - Landing on a player or mob inflicts falling impact damage proportional to blocks fallen.
