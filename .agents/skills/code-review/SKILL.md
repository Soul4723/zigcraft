---
name: code-review
description: Use before opening or merging a Zigcraft pull request.
---

1. Run `bash scripts/check.sh`; it must pass.
2. Read the whole diff against `origin/main` and go through the checklist in
   [CONTRIBUTING.md](../../../CONTRIBUTING.md) step 5.
3. For each `_ = module.fn(...)` line, new module or new item in the diff,
   find where its result or side effects change the game. If there is none, connect it or
   remove it.
4. Fix every problem found, then run step 1 again.

Done when the check passes after the last fix and every checklist item holds.
