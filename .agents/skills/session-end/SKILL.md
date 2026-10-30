---
name: session-end
description: Use at the end of every Zigcraft session, to commit, merge and hand over.
---

Follow [CONTRIBUTING.md](../../../CONTRIBUTING.md) steps 6 and 7:

1. Update the docs listed in CONTRIBUTING, including one line in
   `docs/sessions/README.md`.
2. Commit named paths. Let the hooks run; fix what they report.
3. Push, open the pull request, and apply step 7's merge rule to its exact
   head, including the verified local fallback if hosted jobs cannot start.
4. If it cannot be merged, comment on the pull request why it is waiting.

Done when the pull request is merged or has a comment saying why it waits, the
worktree is clean, and the session line is written.
