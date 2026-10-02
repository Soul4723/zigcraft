# Project Status

Last updated: 2026-10-02 (Session 003)

## What Works
- Zig 0.16.0 build system (zig build, zig build run, zig build test)
- 30 unit tests across 5 modules (all passing)
- 6 PRs open (code + docs + CI)
- CI workflow configured
- Full AI development infrastructure (skills, docs, research)

- Zig 0.16.0 build system (`zig build`, `zig build run`, `zig build test`)
- GLFW window creation with OpenGL 3.3 context
- Sky-blue clear color, escape-to-close, depth testing
- Colored triangle rendering with shader pipeline (VAO/VBO/EBO)
- Single chunk rendering: ChunkRenderer uploads meshed chunk to GPU, procedural 16x16 texture, demo scene in main loop (PR #14)
- MVP (Model-View-Projection) uniform matrix support
- First-person camera with mouse look and WASD movement
- Block type system (air, stone, dirt, grass) with properties
- 16x16x16 chunk data structure with set/get/fillLayer
- Naive per-face chunk mesh generator
- 33 unit tests across 7 test targets, all passing
- Full documentation and AI workflow infrastructure (skills, CONTRIBUTING, ROADMAP)

## Branch: feat/chunk-rendering

All milestone work from session 001 plus the camera feature is merged on the
`feat/camera` branch (local → pushed to origin). Individual PRs are open but
not yet merged into main:

- PR #1: Window creation + OpenGL context (`feat/window-creation`)
- PR #7: Project infrastructure docs (`docs/project-infrastructure`)
- PR #8: Block types + chunk data (`feat/block-types`)
- PR #9: Chunk mesh generation (`feat/chunk-meshing`)
- PR #10: Triangle rendering shader pipeline (`feat/triangle-rendering`)
- PR #11: GitHub Actions CI (`docs/ci-setup`)
- PR #12: Session 001 log + session-end skill (`docs/session-001-log`)
- PR #13: First-person camera (`feat/camera`)
- PR #14: Single chunk rendering (`feat/chunk-rendering`) ← just created

## What's Next

After PRs merge into main:
1. **Terrain generation** (Issue needed): value/simplex noise heightmap, fill chunk by column (research doc exists)
2. **Multiple chunks**: chunk manager, grid render with per-chunk model offset
2. **Terrain generation** (Research doc exists, implementation pending)
3. **Greedy meshing** upgrade (research doc exists, profiling needed first)

See GitHub Issues for scoped work items and `docs/ROADMAP.md` for milestones.

## Known Issues

- Sandbox environment can't install packages. System deps must be pre-installed.
- GLEW doesn't work on Wayland. Use `GL_GLEXT_PROTOTYPES` instead (documented).
- Cross-directory `@import` in Zig 0.16 fails for standalone test targets
  (e.g., a file in `src/renderer/` cannot import from `src/`). See session 002 log.
- Main module test (`addTest` with `root_module`) does not collect tests from
  imported modules. Use standalone test targets for each module.

## Environment

- OS: CachyOS (Arch-based) on Wayland
- GPU: NVIDIA (OpenGL 3.3.0 NVIDIA 615.71.09)
- Zig: 0.16.0
- GLFW: 3.5.1
