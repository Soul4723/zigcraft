# ADR 002: Camera Module Placement and C Interop Strategy

Date: 2026-10-01
Status: **Accepted**

## Context

The camera module (first-person camera with mouse look and WASD) needs both:
1. Math types (`Vec3`, `Mat4`) from `src/math.zig`
2. GLFW input constants (`GLFW_KEY_W`, `GLFW_PRESS`, etc.) from `@cImport`

Two constraints in Zig 0.16 forced a specific design:

1. **Cross-directory imports fail for standalone test targets.**
   A file at `src/renderer/camera.zig` cannot `@import("../math.zig")` when
   compiled as a standalone test in `build.zig`. The error is:
   ```
   error: import of file outside module path
   ```

2. **Each `@cImport` creates distinct opaque struct types.**
   If `main.zig` and `camera.zig` each call `@cImport` separately, their
   `GLFWwindow` types are incompatible. You cannot pass `*c.GLFWwindow` from
   one to the other.

## Options Considered

### Option A: Camera in src/renderer/, shared c.zig module
- Create `src/c.zig` with a shared `@cImport` block
- `main.zig` and `camera.zig` both `@import("../c.zig")`
- Problem: standalone test modules in `src/renderer/` cannot import `../c.zig`

### Option B: Camera in src/renderer/, own @cImport, pass GLFWwindow to camera
- `camera.zig` has its own `@cImport` block
- `main.zig` calls `cam.processInput(window: *c.GLFWwindow, dt)`
- Problem: `GLFWwindow` types differ across `@cImport` blocks → compile error

### Option C: Camera in src/ (same dir as math), own @cImport, do key polling in main
- `camera/zig` imports `math.zig` (same directory, no cross-dir issue)
- `camera.zig` has its own `@cImport` for GLFW constants
- `main.zig` polls keys with `glfwGetKey` and calls `cam.processKey(key, action, dt)`
  — `c_int` is a primitive (`i32`), universally compatible across `@cImport` blocks
- No C opaque types cross module boundaries

## Decision

**Option C.** Move `camera.zig` to `src/` (top-level, same directory as `math.zig`).

This solves both constraints:
- Same-directory import (`@import("math.zig")`) works for standalone tests
- No `@cImport` types cross module boundaries — only `c_int` primitives are passed

## Consequences

- `camera.zig` lives at `src/camera.zig`, not `src/renderer/camera.zig`
  as originally planned in the architecture overview. This is acceptable:
  the camera is game logic (uses math + GLFW input), not an OpenGL abstraction.
- `main.zig` owns the GLFW window handle and does all key polling.
  `camera.zig` only exposes `processKey` (accepts `c_int`) and `processMouse`
  (accepts `f32`).
- Each module keeps its own `@cImport` block. No shared `c.zig` module.
- All modules are testable as standalone targets in `build.zig`.
