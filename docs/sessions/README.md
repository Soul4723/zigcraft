# Session log

One line per session, newest first. Write yours in the same pull request as
the work: date, what changed, and anything the next session must know. Keep
the 15 newest lines and delete older ones; Git history keeps them. Details
belong in the pull request description, not in a separate file.

## Recent sessions

- 2026-10-31: Connected standard furnace smelting from resin clumps to resin
  bricks and removed the raw-clump crafting shortcut; in-world resin drops
  remain unconnected.
- 2026-10-31: Isolated dimension save namespaces (Overworld in root, Nether and The End in subdirectories), added ChunkManager dimension switching with chunk flushing and headless mesh bypass, and wired portal transit.
- 2026-10-30: Public final pass. Added Gemini and Claude entry points that
  import AGENTS.md, enabled required hosted checks and native secret/push
  protection, removed the obsolete local merge fallback, and clarified
  external-PR handling and parallel-session descriptions. Corrected CI's
  metadata range to exclude GitHub's temporary PR merge identity, and
  blocked local agent context/settings from publication.
- 2026-10-30: Triaged all 67 remaining legacy PRs: 65 superseded, two
  disconnected proposals declined with their code retained in closed PRs.
  Removed 72 remote branches and one local branch. Retained historical
  emails and paths; refreshed publication checks and the roadmap.
- 2026-10-30: Public cleanup. Rewrote the README, workflow and status docs;
  added pinned tools, commit/content checks, hooks, the MIT license and a
  publication guide; removed the bootstrap mesh renderer and corrected
  three dangling slice accessors exposed by LLVM. Closed 31 integrated PRs
  and removed 40 remote and 5 local redundant branches. Replaced numbered
  logs `001.md` to `430.md` with this page.
- 2026-10-29, sessions 428 and 430: Creaking damage-link and eyeblossom rule
  modules (milestones 531 and 533). No log exists for session 429.
- 2026-10-29, session 427: Wave 25 integration (milestones 521 to 530):
  imports and discarded per-frame calls in `main.zig`, plus items and 2×2
  recipes.
- 2026-10-29, sessions 421 to 426: Trial spawner, mace, vault, crafter,
  bogged and ominous bottle rule modules (milestones 525 to 530).
- 2026-10-29, sessions 415 to 420: Elder guardian, Nether portal
  scaling and dragon respawn modules; waves 23 and 24 integrated the same way.

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

- **Zig 0.16 test targets** (session 2): cross-directory imports, uncollected
  tests and distinct `@cImport` types; see
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
