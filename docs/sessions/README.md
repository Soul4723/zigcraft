# Session log

One line per session, newest first. Write yours in the same pull request as
the work: date, what changed, and anything the next session must know. Keep
the 15 newest lines and delete older ones; Git history keeps them. Details
belong in the pull request description, not in a separate file.

## Recent sessions

- 2026-11-02: Adapted viewport/projection to framebuffer size and inventory input to logical window size; zero sizes pause rendering. Parent live resize/click checks passed at 960×720 and 1500×720 with clean exit; real HiDPI/minimize behavior remains unverified.
- 2026-11-02: Added numeric stack counts to existing hotbar, inventory, crafting and cursor rendering. Quad batches handle all u8 counts; live frames showed 64 to 63 and 16 to 15 after placement. A resize exposed the existing fixed-aspect layout limitation.
- 2026-11-02: Persisted dimension-isolated hopper/dropper inventories and cooldown/power state, paused unloaded automation, and kept items on failed insertion. Worker live restart checks passed; a portal playthrough was not performed.
- 2026-11-02: Restored held-left timed mining while retaining press-only inventory, placement and melee actions. A fresh-build Xvfb run verified held mining, release, one placement, one inventory transfer and clean shutdown; crafting, mob combat and portal travel remain unchecked.
- 2026-11-02: Cleared temporary effects, flight and stale contact flags on respawn; regression tests cover post-respawn vitals/physics and retained equipment/navigation facts. Interactive death/respawn was not checked.
- 2026-11-02: Removed player blast-center immunity and kept center knockback finite; regression tests cover exact and near-center damage. In-game blasts were not observed.
- 2026-11-02: Persisted four-slot chest and shulker caches by dimension, including emptied fortress loot, enforced item stack limits, and cleaned destroyed container cache entries; hopper and dropper caches remain unsaved and not dimension-isolated.
- 2026-10-31: Persisted furnace, smoker, blast-furnace jobs and growing saplings in per-dimension block_jobs.bin files with offline/unloaded pausing, preflight transit rollback, and ENOENT missing-file checks.
- 2026-10-31: Corrected CONTRIBUTING documentation on Zig 0.16 lazy test collection, documented semantic analysis rules and minimal fixtures in learnings, and confirmed explicit test_files registration policy.
- 2026-10-31: Split inventory item definitions, recipe resolution and container logic into focused modules, preserving the original rules and test suite.
- 2026-10-31: Added natural Pale Oak hearts and F-key nighttime resin collection, protected active heart cooldowns, and removed five disconnected duplicate modules.
- 2026-10-31: Persisted player position, dimension, vitals, inventory, crafting grid, cursor stack, selected slot and tool wear in root-level player.bin across dimensions.
- 2026-10-31: Consolidated hunger exhaustion into Player, wired Left Control
  sprinting and activity exhaustion, and removed duplicate hunger_metabolism.zig.
- 2026-10-31: Connected standard furnace smelting from resin clumps to resin
  bricks and removed the raw-clump crafting shortcut; in-world resin drops
  remain unconnected.
- 2026-10-31: Isolated dimension save namespaces (Overworld in root, Nether and The End in subdirectories), added ChunkManager dimension switching with chunk flushing and headless mesh bypass, and wired portal transit.

## History

The numbered logs are in Git history; find them with
`git log --diff-filter=D --name-only -- docs/sessions/`.

- **Sessions 1 to 31, 2026-10-01 to 2026-10-05**: window and OpenGL context,
  camera, blocks and chunks, meshing, terrain, streaming, culling, picking and
  editing, lighting and sky, persistence, physics, inventory and crafting,
  sound, mobs.
- **Sessions 32 to about 170, 2026-10-05 to 2026-10-08**: tools and mining,
  food, furnaces, TNT, redstone (from session 45), falling blocks (61), water
  flow (67), hazards, pathfinding.
- **Sessions about 170 to 370, 2026-10-08 to 2026-10-16**: swimming and
  oxygen, the Nether (from session 174), the End and the Ender Dragon, ocean
  content, rails, and many blocks, items and recipes.
- **Sessions 371 to 430, 2026-10-17 to 2026-10-29**: waves of about ten
  standalone rule modules (roadmap items up to 533), each followed by an
  integration session that imported them into `main.zig`, mostly as calls
  whose results are discarded. See [STATUS.md](../STATUS.md).

## Caveats from past sessions

Still relevant; each line names the session that found it.

- **Zig 0.16 test targets** (session 2): cross-directory imports, lazy
  semantic analysis test collection, and distinct `@cImport` types; see
  [CONTRIBUTING.md](../../CONTRIBUTING.md#zig-016-gotchas).
- **GLEW fails on Wayland** (session 1): use `GL_GLEXT_PROTOTYPES` with
  `GL/glcorearb.h`.
- **Greedy-meshing UVs** (session 28): a merged quad of w × h blocks must
  repeat its atlas tile; stretching the UV range samples the neighboring
  tile.
- **Test directories** (session 31): the persistence tests write under
  `.zig-cache/`, because `mkdir` there creates no parent directories.
- **CI dependencies** (session 31): CI needs `libasound2-dev` as well as
  GLFW and GL.
- **Generator pass order** (session 203): Nether generation passes overwrite
  each other; a feature placed in one pass needs guards in the later passes.
- **Texture atlas** (session 204): the atlas rows were full; new blocks
  reused existing tiles.
- **Timer thresholds** (wave 9): `f32` timers built up from frame deltas can
  step past an exact threshold; compare with a small tolerance.
- **Zig cache size** (session 412): local Zig caches grow to several
  gigabytes. If a build fails for lack of disk space, use a fresh cache
  directory.
