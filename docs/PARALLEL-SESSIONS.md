# Parallel Sessions

Multiple AI sessions can work on this project concurrently. This document
defines how to avoid conflicts and coordinate effectively.

## Rules

1. **One branch per session.** Every session creates its own branch from the
   current integration point. Never work directly on `main`.

2. **Check for active work first.** Before starting, run:
   ```bash
   git branch -a
   gh pr list
   gh issue list
   ```
   If another session has an open branch/PR touching the same files, pick
   different work.

3. **Claim work via GitHub Issues.** Before starting a milestone:
   - Check if an issue exists for it
   - If not, create one
   - Assign it yourself (or note in a comment you're working on it)
   - This prevents two sessions building the same feature

4. **Start from the right base.** `origin/main` on GitHub may lag behind local
   development (PRs are open but not yet merged). Always create your branch
   from the latest local branch that contains the work you need. Check
   `git log --oneline` to see what's available.

5. **Merge via PR.** When done, open a PR. Another session (or the user)
   merges it. If you hit conflicts, the session finishing second resolves them.

6. **Session logs don't conflict.** Each session gets its own numbered log file
   in `docs/sessions/`. Use the next available number.

7. **Commit docs separately.** Always commit code changes first (with
   `zig build` passing), then commit documentation updates as a second commit.

## Branch Naming

```
feat/<feature-name>     # New feature
fix/<bug-description>   # Bug fix
refactor/<area>         # Code restructuring
docs/<topic>            # Documentation only
prototype/<question>     # Throwaway prototype (never merge)
research/<topic>        # Research branch (may have scratch code)
build/<change>          # Build system changes
```

## Safe to Work on in Parallel

| Area | Conflict Risk | Notes |
|------|--------------|-------|
| New module in src/ | Low | As long as it's a new file |
| docs/research/ | None | Each file is independent |
| docs/sessions/ | None | Numbered, no overlap |
| build.zig | High | Only one session should touch this at a time. Coordinate via issues. |
| src/main.zig | High | Central file — coordinate changes via issues. |
| Existing module | Medium | Check diff before merging |
| Renderer + World | Low | Different directories, different concerns |

## Module Boundaries for Parallel Work

Good parallel splits follow module boundaries. Check `docs/architecture/OVERVIEW.md`
for the current module layout.

- **Camera** (`src/camera.zig`) + **Math** (`src/math.zig`): Camera depends on math.
  If working on camera, you'll need math to be finalized first.
- **Renderer** (`src/renderer/`): shader.zig and mesh.zig are independent of each
  other. Can be worked on in parallel.
- **World** (`src/world/`): block.zig → chunk.zig → chunk_mesh.zig form a dependency
  chain. block types can be done independently; chunk and meshing depend on blocks.

## Known Zig 0.16 Constraints (Affect Parallel Work)

1. **Cross-directory imports fail for standalone tests.** A file at `src/renderer/foo.zig`
   cannot `@import("../bar.zig")` when compiled as a standalone test target. Plan module
   placement so cross-module imports stay within the same directory.

2. **`addTest` does not collect imported-module tests in Zig 0.16.** Use standalone
   test targets for each module that has tests. See `docs/learnings/zig-0.16-changes.md`.

3. **Each `@cImport` creates distinct opaque types.** Two files with separate `@cImport`
   blocks get different `GLFWwindow` types. Avoid passing C opaque types between modules.
   See `CONTRIBUTING.md` → "Zig 0.16 Module Gotchas".
