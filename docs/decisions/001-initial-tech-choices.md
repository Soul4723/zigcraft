# ADR 001: Initial Technology Choices

Date: 2026-10-01

## Context

Starting a Minecraft clone from scratch in Zig. Need to choose rendering
API, windowing library, and approach to external dependencies.

## Decisions

### Rendering: OpenGL (initially)

OpenGL has simpler setup than Vulkan and well-documented C bindings that
Zig can call directly. Vulkan is better long-term for performance but adds
massive upfront complexity for zero visual benefit in early milestones.

Can migrate to Vulkan later if needed — the renderer will be isolated
behind a module boundary anyway.

### Windowing: GLFW

Standard choice. Already installed on the system (`pacman -Q glfw`).
Zig has good C interop, and GLFW's C API is minimal. Handles window
creation, input, and OpenGL context setup.

### Build System: Zig's built-in

No CMake, no Make. Zig's build system handles C interop natively via
`linkSystemLibrary`. Keeps the project pure-Zig tooling.

### No Engine, No Framework

Building from scratch. The point of this project is to learn Zig and
understand how a voxel engine works at every level.

## Alternatives Considered

- **Vulkan** — Too complex for early milestones. Revisit for Phase 4+.
- **SDL2** — Viable, but GLFW is lighter and more focused on what we need.
- **raylib** — Higher-level, but hides too much. We want to learn the stack.
- **Mach engine** — Zig-native game engine, but it's a framework with opinions.
  We want to build the opinions ourselves.
