# Parallel sessions

Several agent sessions can work at once. The workflow in
[CONTRIBUTING.md](../CONTRIBUTING.md) already keeps them apart: each session
branches from fresh `origin/main`, uses its own worktree, and merges through
a pull request. This page covers how to avoid colliding.

## Before you start

Run `gh pr list --limit 1000` and look at what each open pull request changes
(`gh pr diff <number> --name-only`). Choose work that does not touch the
same files. To claim work early, open a draft pull request.

Never commit to, rebase or switch a branch that another session is using.

## Files that conflict often

| Path | Risk | Advice |
|------|------|--------|
| `src/main.zig` | High | Keep edits small and merge soon. Moving code out of it reduces future conflicts. |
| `src/inventory.zig` | High | Item IDs and recipes are appended at the end by many changes. |
| `build.zig` | High | `test_files` is one shared list. Rebase on `origin/main` just before merging. |
| `src/world/block.zig` | High | `BlockId` has no free values left. |
| `docs/STATUS.md`, `docs/ROADMAP.md` | Medium | Edit only the lines your change affects. |
| `docs/sessions/README.md` | Medium | Keep both session entries when rebasing simultaneous changes. |
| A new file in `src/world/` | Low | Check first that no existing module covers the mechanic. |

When a merge conflicts, the session that merges second resolves it.

## Branch names

`feat/<name>`, `fix/<name>`, `refactor/<area>`, `docs/<topic>`,
`build/<change>`, `test/<area>`, and `prototype/<question>` for throwaway
experiments that are never merged.
