# Roadmap

Last updated: 2026-10-31.

The project has far more rule modules than game. The next work makes
existing mechanics real in the game and removes duplicates. Adding another
standalone module is the lowest priority. [STATUS.md](STATUS.md) has the
evidence for each item.

Pick the highest unblocked item not already covered by an open pull request.
Record unavailable resources and continue; do not spend each session
re-diagnosing the same external blocker.
When an item is done, delete it here and update STATUS.md.

## 1. Restore a trusted baseline

- Required hosted checks protect `main`. Diagnose failed checks before
  adding work; leave externally blocked PRs open and take another task.
- Play the game and record in STATUS.md what works in the first minutes:
  spawn, mining, placing, crafting, mobs, a portal trip. The last run only
  checked that the game starts. If no display is available, record that
  limit and choose work that can be checked locally.

## 2. Fix world and save correctness

- Save placed container contents (chests, shulker boxes) across quit/restart and portal dimension switches, isolating container caches by dimension.

## 3. Connect or remove disconnected modules

Work one mechanic at a time:

1. Choose the module that will own the mechanic. Merge useful rules from the
   duplicates listed in STATUS.md into it, then delete the duplicates and
   their `build.zig` entries.
2. Connect it until it meets the done list in
   [CONTRIBUTING.md](../CONTRIBUTING.md#3-change).
3. Delete its discarded `_ = module.fn(...)` line from `src/main.zig`.

A module that cannot be connected yet because a needed system is missing
(for example 3×3 crafting, taller worlds or more block IDs) stays out of
`main.zig` and is listed under that system below.

Good first candidates are mechanics whose blocks, items or mobs already exist
in the game: mob rules for mobs already in `src/entity/`, and redstone parts.

## 4. Pay down structure debt

- Move subsystems out of `main()` in `src/main.zig` into modules that own
  their state, starting with redstone, fluids, projectiles and dimension
  travel. Keep behavior unchanged and covered by tests.
- Show important feedback on screen instead of only in the terminal.
- Test target aggregation: research showed Zig 0.16 collects tests across
  same-module imports via lazy semantic analysis, causing per-file test roots
  to duplicate shared module tests. Before any future test target aggregation
  or grouping is considered, require automated proof of exact collected-case
  identity equivalence against current per-target roots to prevent accidental
  test case omission.

## 5. Systems that unlock blocked mechanics

- Taller worlds: vertical chunk stacking.
- Block IDs beyond 256, or block states.
- A 3×3 crafting table.

## Done

Phases 1 to 7 built the engine: window and OpenGL, chunks and meshing,
terrain, streaming and culling, picking and editing, lighting and sky,
persistence, physics, inventory and crafting, sound, mobs, textures, tools,
particles, redstone, falling blocks, fluids, hazards and pathfinding.
Phase 8 (roadmap items 43 to 533) added swimming, oxygen and underwater
effects, then mostly standalone world modules in waves of about ten. The
full milestone list is in Git history.
