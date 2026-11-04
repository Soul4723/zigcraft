# Session log

One line per session, newest first. Write yours in the same pull request as
the work: date, what changed, and anything the next session must know. Keep
the 15 newest lines and delete older ones; Git history keeps them. Details
belong in the pull request description, not in a separate file.

## Recent sessions

- 2026-11-04: Unified Bundle pouch rules into src/world/bundle_pouch.zig and removed duplicate bundle_dyeing_nesting.zig. Connected cauldron washing for dyed bundles (reverting to undyed, consuming 1 water level, splash audio/VFX) and bundle item insertion from hotbar/cursor with .click_on audio to live gameplay in main.zig.
- 2026-11-04: Unified Ender Dragon fight rules into src/world/ender_dragon_fight.zig and removed duplicate ender_dragon_arena_fight.zig. Connected live crystal tether healing (2.0 HP/s, beam vortex/shimmer VFX), crystal shatter recoil backlash (10 damage within 32m, mob roar audio, flame/smoke VFX), and projectile perch deflection to gameplay in main.zig.
- 2026-11-04: Unified Wither boss mechanics into src/world/wither_boss.zig and removed duplicate wither_boss_phases.zig. Connected spawn invulnerability charging (220 ticks), charging smoke/flame VFX, birth explosion detonation with audio and particle burst, and live HUD boss bar tracking to gameplay in main.zig.
- 2026-11-04: Unified Strider mount and lava locomotion rules into src/world/strider_mount.zig and removed duplicate strider_lava_mount.zig. Connected active_strider update and right-click Warped Fungus on a Stick boost (speed surge to 7.8 m/s, durability wear, lava pop audio and flame VFX) and Warped Fungus feeding to live gameplay in main.zig.
- 2026-11-04: Unified Beacon pyramid geometry, status powers, and payment activation into beacon_aura.zig and removed duplicate beacon_pyramid.zig and beacon_status_pyramids.zig. Connected Haste mining speed boost (1.40× multiplier) and dynamic aura radius (20m base, 50m supercharged) to live gameplay in main.zig.
- 2026-11-04: Unified Guardian and Elder Guardian combat and drop rules in ocean_monument.zig and removed duplicate guardian_laser_spikes.zig and elder_guardian_curse.zig. Connected GuardianLaserState 15m laser beam tracking, progressive color cues, piercing beam damage, Elder Guardian Mining Fatigue, and melee spike thorns retaliation to live gameplay in main.zig.
- 2026-11-04: Unified Blaze combat rules in blaze_fortress.zig and removed duplicate blaze_fireball_artillery.zig. Connected BlazeAttackState 3-fireball volleys, charging flame VFX, and snowball vulnerability (3 damage with sizzle audio and sparks) to live gameplay in main.zig.
- 2026-11-04: Prevented container item loss on player inventory overflow during mining and explosions. Drained items are added to inventory; if overflow remains, container blocks and cached items survive without deletion or drops.
- 2026-11-02: Added dedicated dark obsidian and purple Nether portal tiles using a taller atlas, preserving existing sheep and pressure-plate materials. Xvfb runs visually checked a normally generated frame with side and top-edge ignition; the combined run saved all six portal cells and exited cleanly.
- 2026-11-02: Fixed F ignition from a portal top lintel by checking all six adjacent cells; both frame orientations have regression coverage. A normally generated frame ignited under top-edge aim in Xvfb and saved six portal cells; player positioning was supplied.
- 2026-11-02: Connected Creaking puppets to active hearts, repaired upper-body gaze, frozen gravity, hazard-free spawning and pumpkin handling; preserved shared resin cooldown and transit cleanup. Fixture-assisted live checks observed night appearance, torso-gaze stillness, pursuit/attacks and shared resin cooldown; dawn and broken-heart cleanup were not conclusively observed.
- 2026-11-02: Connected deterministic dormant obsidian frames to Overworld generation; default seed frame (44, 7, 44) uses the existing F ignition and Nether transit. Generated-chunk/detector tests pass; live transit used a test-positioned player, not an end-to-end walk.
- 2026-11-02: Adapted viewport/projection to framebuffer size and inventory input to logical window size; zero sizes pause rendering. Parent live resize/click checks passed at 960×720 and 1500×720 with clean exit; real HiDPI/minimize behavior remains unverified.
- 2026-11-02: Added numeric stack counts to existing hotbar, inventory, crafting and cursor rendering. Quad batches handle all u8 counts; live frames showed 64 to 63 and 16 to 15 after placement. A resize exposed the existing fixed-aspect layout limitation.
- 2026-11-02: Persisted dimension-isolated hopper/dropper inventories and cooldown/power state, paused unloaded automation, and kept items on failed insertion. Worker live restart checks passed; a portal playthrough was not performed.

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
