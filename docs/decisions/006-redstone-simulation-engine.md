# Decision 006: Stateless BFS Redstone Power Simulation and Delay Stages

## Status
Accepted (2026-10-06, Sessions 046-080)

## Context
Redstone mechanics require propagating power levels across networks of wire, repeaters, levers, and torches without incurring infinite loops, recursion depth overflows, or stale state synchronization bugs across chunk borders.

## Decision
1. **Stateless World BFS Evaluation:**
   - Power sources (levers, active torches, pressure plates) emit power 15 into adjacent wire cells.
   - Signal falloff is calculated with Breadth-First Search (BFS) capped at 15 steps (`falloff = power - 1` per wire hop).
2. **Component Rules:**
   - **Torches:** Inverters that power off when the attachment block is powered. Rapid cycling (>8 flips in 3.2s) induces burnout with a 30s recovery period persisted to `.rtb` sidecar state.
   - **Repeaters:** Directional diodes that boost power to 15 with selectable 1-4 tick delays.
   - **Lamps & Doors:** Actuated directly by adjacent powered blocks or live redstone wires.
