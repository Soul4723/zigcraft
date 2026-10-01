# Project Status

Last updated: 2026-10-01

## What Works
- Zig 0.16.0 build system (zig build, zig build run, zig build test)
- 30 unit tests across 5 modules (all passing)
- 6 PRs open (code + docs + CI)
- CI workflow configured
- Full AI development infrastructure (skills, docs, research)

## PRs Open
| # | Title | Status |
|---|-------|--------|
| 1 | Window creation + OpenGL context | Ready to merge |
| 7 | Project infrastructure | Ready to merge |
| 8 | Block types + chunk data | Ready to merge |
| 9 | Chunk mesh generation | Ready to merge |
| 10 | Triangle rendering | Ready to merge |
| 11 | GitHub Actions CI | Ready to merge |

## In Progress
Nothing — all work committed in branches waiting for PR merge.

## Next
After PRs merge:
1. Issue #3: First-person camera (src/math.zig, src/camera.zig)
2. Issue #6: Single chunk rendering (integration of all modules)
3. Phase 1 Item 5: Textures (block texture atlas)
4. Phase 2: Terrain generation, multiple chunks

## Known Issues
- Sandbox can't install system packages
- CI uses Zig 0.14.0 (GitHub runners don't have 0.16.0 yet)
- GLEW doesn't work on Wayland (documented in CONTRIBUTING.md)
