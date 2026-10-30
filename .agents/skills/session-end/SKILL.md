---
name: session-end
description: Use at the end of every Zigcraft session, to commit, merge and hand over.
---

Follow [CONTRIBUTING.md](../../../CONTRIBUTING.md) steps 6 and 7:

1. Update the docs listed in CONTRIBUTING, including one line in
   `docs/sessions/README.md`.
2. Commit named paths. Let the hooks run; fix what they report.
3. Push, open the pull request, and apply step 7's merge rule to its exact
   head. Both required hosted checks must pass before merging.
4. If it cannot be merged, record the blocker in the PR description.

Done when the PR is merged and its task worktree removed, or its blocker
is recorded and unfinished work is committed and pushed. The session line
must be written in either case.
