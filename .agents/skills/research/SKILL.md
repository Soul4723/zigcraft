---
name: research
description: >-
  Investigate a technical question and write findings to docs/research/.
  Use for Zig API questions, graphics programming patterns, voxel engine
  techniques, or anything that needs reading before coding.
---

Investigate the question against primary sources: official Zig docs,
OpenGL/Vulkan specs, library source code, reference implementations.

## Process

1. **Search primary sources.** Zig standard library source is at
   `/usr/lib/zig/std/`. GLFW and OpenGL headers are in system include paths.
   Use `rg` to search them. For broader questions, use web search.

2. **Write findings** to `docs/research/<topic>.md`. Include:
   - The question being answered
   - Key findings with source citations
   - Code examples if relevant (tested against Zig 0.16.0)
   - Open questions or uncertainties
   - Date of research

3. **Report** the key finding and file location. If the question is
   unanswered, say what's missing.

## Zig 0.16.0 Notes

Zig 0.16.0 has significant API changes from earlier versions. Always verify
against the actual installed standard library, not online examples which
may target older versions. Key known changes:

- `std.io` is now `std.Io` (capital I, different API)
- `std.debug.print` still works for stderr output
- Build API uses `b.createModule` for executables
- Package manifest uses `.name = .identifier` syntax
