---
name: session-start
description: >-
  Begin a new session. Read project state, decide what to work on,
  claim a branch. Run this at the start of every session.
---

Every session starts here. No exceptions.

## Steps

1. **Read project state.** Open and read:
   - `docs/STATUS.md` — what works, what's broken, what's in progress
   - `docs/ROADMAP.md` — what's next
   - `docs/architecture/OVERVIEW.md` — how the code is organized
   - The latest file in `docs/sessions/` — what the last session did
   - Any open GitHub Issues (`gh issue list`)

2. **Check for active branches.** Run `git branch -a` and `gh pr list`.
   If another session has an open PR or WIP branch, don't touch that work.
   Pick something else or continue on a different branch.

3. **Decide what to do.** Based on the project state, pick the highest-value
   work. Consider:
   - Is something broken? Fix it first.
   - Is a milestone partially done? Finish it.
   - Otherwise, take the next item from the roadmap.

4. **Create a branch.** Name it descriptively: `feat/window-creation`,
   `fix/build-warning`, `docs/update-architecture`, `refactor/chunk-mesh`.
   Branch from `main`.

5. **State your plan** in commentary before starting work. One or two sentences.

6. **Work.** Use other skills as needed (research, implement, etc).

7. **Before ending the session**, run the `session-end` steps:
   - Commit and push all work
   - Open a PR if the work is ready for merge (or leave as draft if WIP)
   - Write a session log to `docs/sessions/NNN.md`
   - Update `docs/STATUS.md` if anything changed
   - Update `docs/architecture/OVERVIEW.md` if the code structure changed
