# Contributing (AI Sessions)

You are an AI model working on this project. You have no memory of previous
sessions. This file tells you how to work effectively.

## First Thing Every Session

Read these files in this order:

1. `docs/STATUS.md` — what works right now
2. `docs/ROADMAP.md` — what to work on next
3. The latest file in `docs/sessions/` — what the last session did
4. `docs/architecture/OVERVIEW.md` — how the code is organized

Then run `git branch -a` and `gh issue list` to see if other sessions
are working on anything.

## Rules That Prevent Disasters

### Don't break the build
Run `zig build` before every commit. If it doesn't compile, don't commit.

### Don't work on main
Always create a branch. Always open a PR. Never push directly to main.

### Don't re-decide settled decisions
If `docs/decisions/` has an ADR about something, that decision is made.
Don't spend time reconsidering it unless you have concrete evidence it's wrong.

### Don't refactor what you're not working on
If your task is "add block types", don't also reorganize the renderer.
One branch, one concern.

### Don't guess at Zig 0.16 APIs
The standard library changed significantly in 0.16. Read the actual source
at `/usr/lib/zig/std/` instead of relying on your training data, which
likely covers 0.11-0.13. See `docs/learnings/zig-0.16-changes.md` for
known differences.

### Don't introduce dependencies without an ADR
If you want to add a library, write a decision doc in `docs/decisions/`
explaining why, what alternatives exist, and why this one wins.

## Code Patterns

### C Interop
All C imports go through a single `@cImport` block, typically at the top
of the file that uses them. For OpenGL:

```zig
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
```

GLEW does not work on Wayland. Use `GL_GLEXT_PROTOTYPES` with `glcorearb.h`.

### Error Handling
Use Zig's error unions. Return errors up, handle them at the appropriate level.
Don't silently discard errors. Use `std.debug.print` for error messages during
development.

```zig
// Good
const window = c.glfwCreateWindow(...) orelse {
    std.debug.print("failed to create window\n", .{});
    return error.WindowCreationFailed;
};

// Bad — crashes with no info
const window = c.glfwCreateWindow(...).?;
```

### File Organization
- One module per file, one concern per module
- Files under 300 lines — split when they grow
- C bindings isolated in dedicated files when they get complex
- Public API at the top of the file, private helpers below

### Naming
- `camelCase` for functions and variables
- `PascalCase` for types and structs
- `SCREAMING_SNAKE` for constants from C interop (leave them as-is)
- Descriptive names. `chunk_mesh` not `cm`. `block_type` not `bt`.

### Commits
Format: `<type>: <description>`

Types: `feat`, `fix`, `refactor`, `docs`, `build`, `test`

Keep commits small and focused. One logical change per commit.

## Build Commands

```bash
zig build              # Compile
zig build run          # Compile and run
zig build test         # Run tests
zig build -Doptimize=ReleaseFast  # Optimized build
```

## Zig 0.16 Module Gotchas

### Cross-directory imports fail for standalone tests
A file at `src/renderer/foo.zig` cannot do `@import("../bar.zig")` when compiled
as a standalone test target in `build.zig`. The test runner will reject it with
"import of file outside module path." Workaround: keep files that import each
other in the same directory, or test them only through the main module.

### addTest does not collect imported-module tests
`b.addTest(.{ .root_module = exe_mod })` only runs `test` blocks in the root
file. It does **not** collect tests from files reachable via `@import`. To test
an imported module, add it as a standalone test target with
`b.createModule(.{ .root_source_file = b.path("path/to/file.zig") })`.

### Each @cImport creates distinct opaque types
Two files with separate `@cImport` blocks get distinct `struct GLFWwindow` types.
You cannot pass a `*c.GLFWwindow` from main.zig to a function in renderer/camera.zig
if they have separate `@cImport` blocks. Workaround:
1. Share one `@cImport` in a common module (may require same-directory layout)
2. Avoid passing C opaque types between modules; pass primitive `c_int` values instead
3. Do GLFW window polling in the module that owns the window, call helpers with primitives

### Primitive C types are universal
`c_int`, `c_uint`, `c_float` map to Zig primitives (`i32`, `u32`, `f32`). These
are compatible across `@cImport` blocks. You can pass `c.GLFW_KEY_W` from any
module to any other because the value is an `i32`.

## System Dependencies

These must be installed via pacman before coding:
- `zig` (0.16.0)
- `glfw` (window + input)
- `mesa` (OpenGL)
- `vulkan-devel vulkan-headers` (future Vulkan support)
- `cmake` (some dependency builds)

The sandbox cannot install packages. If something is missing, note it in
the session log and work on something that doesn't need it.

## When You're Stuck

1. **Zig compile error you don't understand**: Search `/usr/lib/zig/std/` with
   `rg` for the actual API. Your training data is likely wrong for 0.16.
2. **Not sure what to work on**: Follow the roadmap. Pick the next unfinished item.
3. **Task is too big for one session**: Do what you can, write a clear session log
   about what's done and what remains, and create a GitHub issue for the rest.
4. **Two approaches seem equally good**: Pick one, write an ADR explaining why,
   move on. Don't stall.
5. **Something is broken**: Fix it before starting new work. Update STATUS.md.

## Continuous Execution Mandate
- Do not stop after minor steps or ask for confirmation on routine changes.
- Avoid micro-slicing work into trivial 10-line PRs unless explicitly constrained.
- Keep `src/main.zig` focused on game loop and input dispatch; extract game rules, hazards, and simulation mechanics into modular domain files under `src/world/`.
- Ensure new domain files are added to `test_files` in `build.zig`.
