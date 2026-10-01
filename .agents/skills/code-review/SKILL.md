---
name: code-review
description: >-
  Review changes on the current branch against main. Check for correctness,
  style, and whether the code matches its intended goal.
---

## Process

1. **Get the diff.** `git diff main...HEAD` for the full change.
   `git log main..HEAD --oneline` for the commit list.

2. **Check correctness.**
   - Does it compile? (`zig build`)
   - Do tests pass? (`zig build test`)
   - Does it run without crashing? (`zig build run`)
   - Are error paths handled?

3. **Check style.**
   - Follows Zig naming conventions (camelCase functions, PascalCase types)
   - No dead code or commented-out blocks
   - Functions under ~50 lines
   - Files under ~300 lines
   - C interop isolated in dedicated files

4. **Check intent.**
   - Does the change do what the commit messages / issue say it does?
   - Any scope creep?
   - Anything missing?

5. **Report findings.** List issues by severity:
   - **Must fix** — bugs, crashes, missing error handling
   - **Should fix** — style violations, unclear naming
   - **Consider** — suggestions, future improvements
