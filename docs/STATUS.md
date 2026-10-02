# Project Status

Last updated: 2026-10-01 (Session 001)

## What Works

- Zig 0.16.0 build system (`zig build`, `zig build run`, `zig build test`)
- GLFW window creation with OpenGL 3.3 context (on `feat/window-creation` branch, PR #1)
- Sky-blue clear color, escape-to-close, depth testing
- Full documentation and AI workflow infrastructure

## In Progress

- PR #1: Window creation + OpenGL context — ready to merge

## What's Next

See GitHub Issues for scoped work items:
- Issue #2: Triangle rendering
- Issue #3: Camera
- Issue #4: Block types + chunk data (can run in parallel with #2 and #3)
- Issue #5: Chunk mesh generation
- Issue #6: Single chunk rendering

See `docs/ROADMAP.md` for the full milestone list.

## Known Issues

- Sandbox environment can't install packages. System deps must be pre-installed.
- GLEW doesn't work on Wayland. Use `GL_GLEXT_PROTOTYPES` instead (documented).

## Environment

- OS: CachyOS (Arch-based) on Wayland
- GPU: NVIDIA (OpenGL 3.3.0 NVIDIA 615.71.09)
- Zig: 0.16.0
- GLFW: 3.5.1
