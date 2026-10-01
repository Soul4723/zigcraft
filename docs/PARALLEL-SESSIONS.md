# Parallel Sessions

Multiple AI sessions can work on this project concurrently. This doc
defines how to avoid conflicts.

## Rules

1. **One branch per session.** Every session creates its own branch from `main`.
   Never work directly on `main`.

2. **Check for active work first.** Before starting, run:
   ```
   git branch -a
   gh pr list
   gh issue list
   ```
   If another session has an open branch or PR, don't touch the same files.

3. **Claim work via GitHub Issues.** Before starting a milestone:
   - Check if an issue exists for it
   - If not, create one
   - Assign it to yourself (or note in a comment that you're working on it)
   - This prevents two sessions from building the same feature

4. **Independent work streams.** Good parallel splits follow the module
   boundaries in `docs/architecture/OVERVIEW.md`:
   - Session A: `feat/window-creation` (window.zig)
   - Session B: `feat/block-types` (world/block.zig)
   - Session C: `docs/research-noise-algorithms` (docs only)

   Bad parallel splits touch the same files:
   - Session A and B both modifying `main.zig`
   - Session A and B both changing `build.zig`

5. **Merge via PR.** When done, open a PR. The other session (or the user)
   merges it. If there are conflicts, the session that finishes second
   resolves them.

6. **Session logs don't conflict.** Each session gets its own numbered log
   file in `docs/sessions/`. Use the next available number.

## Branch Naming

```
feat/<feature-name>     # New feature
fix/<bug-description>   # Bug fix
refactor/<area>         # Code restructuring
docs/<topic>            # Documentation only
prototype/<question>    # Throwaway prototype (never merge)
research/<topic>        # Research branch (may have scratch code)
build/<change>          # Build system changes
```

## What's Safe to Work on in Parallel

| Area | Conflict Risk | Notes |
|------|--------------|-------|
| New module in src/ | Low | As long as it's a new file |
| docs/research/ | None | Each file is independent |
| docs/sessions/ | None | Numbered, no overlap |
| build.zig | High | Only one session should touch this at a time |
| main.zig | High | Central file, coordinate changes |
| Existing module | Medium | Check the diff before merging |
