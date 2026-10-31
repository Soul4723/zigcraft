# Architecture overview

Last updated: 2026-10-31.

This page explains how the code is organized and how the parts connect.
What works and what does not is in [STATUS.md](../STATUS.md).

## Layout

```
build.zig            executable, `run` step, and the list of standalone test targets
src/
  main.zig           window, input, frame loop, and most gameplay glue
  chunk_manager.zig  loaded chunks, streaming, generation, saving, block access
  chunk_renderer.zig GPU buffers and draw call for one chunk mesh
  player.zig         player physics, vitals (health, hunger, oxygen) and status timers
  inventory.zig      item types, item metadata, inventory slots, 2×2 recipes, mob types
  camera.zig, math.zig, frustum.zig, pick.zig, sky.zig
  renderer/          shader, procedural texture atlas, HUD and inventory UI,
                     particles, block highlight, toast messages
  entity/            mobs: state and AI, spawning, pathfinding, box-model rendering
  audio/             ALSA output and procedural sound synthesis
  world/             blocks, chunks, meshing, terrain, persistence, and rule modules
docs/                status, roadmap, decisions, learnings, research
scripts/             setup, the full check, and the public-content check
.githooks/           pre-commit and pre-push checks, enabled by scripts/setup.sh
.agents/skills/      short workflow skills for agents
```

## Frame loop

`main()` in `src/main.zig` creates the window and every subsystem, then runs
one loop per frame:

1. Read keyboard and mouse state from GLFW.
2. Update the player (`player.zig`), camera and dimension travel.
3. Stream chunks around the player (`ChunkManager.update`).
4. Step mobs (`entity/mob_manager.zig`) and the gameplay systems kept as
   local state in `main()`: redstone parts, furnaces, fuses, falling blocks,
   projectiles, water ticks and more.
5. Apply block edits through `ChunkManager.editAndRemesh`, which marks the
   chunk and its neighbors for remeshing.
6. Draw sky, chunks, mobs, particles, highlight and HUD, and update audio.

Most gameplay state is local variables and fixed-size arrays inside `main()`.
Capacities and lookup helpers for those arrays are in
`src/world/component_cache.zig`.

## World data

- `world/block.zig` defines `BlockId` (`enum(u8)`, all 256 values used) and
  block properties.
- `world/chunk.zig` stores a 16×16×16 chunk: block IDs plus water levels.
  The world has one chunk layer, so it is 16 blocks tall.
- `world/terrain.zig` generates Overworld, Nether and End chunks from a seed.
- `world/chunk_mesh.zig` builds greedy-meshed vertices with ambient
  occlusion; `chunk_renderer.zig` uploads and draws them.
- `world/persistence.zig` writes one binary file per chunk, plus sidecar
  files for repeater delays and torch burnout, keeping Overworld files in
  `saves/` and Nether and End files in `saves/nether/` and `saves/the_end/`.
  `ChunkManager` saves modified chunks when they unload, when a portal
  switches dimensions, or when the game exits.

## Rule modules

Most of `src/world/` is rule modules: plain Zig with no OpenGL or GLFW
calls. A module holds the numbers and state machine for one mechanic and
returns results or events. The caller applies them to the world, mobs,
inventory, rendering or audio.

Because of how Zig 0.16 test targets work (see
[CONTRIBUTING.md](../../CONTRIBUTING.md#zig-016-gotchas)), modules in
`src/world/` import only files in the same directory. They take callbacks or
duck-typed `world` parameters instead of importing `chunk_manager.zig`.

A rule module only affects the game when `main.zig` or another runtime
system uses its result. Many do not yet; see STATUS.md.

## Tests

Setup installs Zig 0.16.0 locally. The build uses LLVM and LLD so recent
Linux C runtime objects link without altering system files.

`zig build test` runs:

- the test blocks in `src/main.zig`, through the executable's root module;
- one test executable per file listed in `test_files` in `build.zig`.

A file's tests run only if the file is in `test_files`; tests in imported
files are not collected through the root module. Add each new file with tests
to `test_files`.

## Decisions and background

- [decisions/](../decisions/): architecture decision records
- [learnings/zig-0.16-changes.md](../learnings/zig-0.16-changes.md): Zig 0.16 API notes
- [learnings/build-and-slice-lifetimes.md](../learnings/build-and-slice-lifetimes.md): compiler setup and borrowed-slice lifetimes
- [research/](../research/): meshing, rendering, terrain, math and C interop notes
