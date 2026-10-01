---
name: implement
description: >-
  Implement a feature or fix. Build, test, verify before committing.
---

## Process

1. **Understand the goal.** Read the relevant roadmap item, issue, or
   decision doc. If the approach isn't clear, do research first.

2. **Write the code.** Follow existing patterns in the codebase.
   Keep changes focused — one feature or fix per branch.

3. **Build frequently.** Run `zig build` after meaningful changes.
   Zig's compiler errors are precise — read them carefully.

4. **Test.** Run `zig build test` for unit tests. For visual/runtime
   features, run `zig build run` and verify behavior.

5. **Commit.** Small, meaningful commits. Message format:
   `<type>: <description>` where type is feat, fix, refactor, docs, build.

## Zig Conventions for This Project

- Use `std.debug.print` for debug output
- Error handling: use `try` and return errors, don't silently swallow
- Naming: camelCase for functions/variables, PascalCase for types
- Keep files under ~300 lines; split into modules when they grow
- C interop: isolate C bindings in dedicated files (e.g., `gl.zig`)

## Build Commands

- `zig build` — compile
- `zig build run` — compile and run
- `zig build test` — run tests
- `zig build -Doptimize=ReleaseFast` — optimized build
