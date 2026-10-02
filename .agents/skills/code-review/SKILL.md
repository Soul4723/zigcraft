---
name: code-review
description: >-
  Review changes on the current branch before opening a PR.
---

## Run this before opening any PR

### 1. Get the diff

```bash
git diff main...HEAD
git log main..HEAD --oneline
```

### 2. Automated checks (all must pass)

```bash
zig build          # compiles?
zig build test     # tests pass?
```

### 3. Manual checklist

Go through each changed file:

- [ ] No commented-out code
- [ ] No `@panic` calls (use `return error.*` instead)
- [ ] No hardcoded paths
- [ ] No TODO/FIXME without a matching GitHub issue
- [ ] Error messages are descriptive
- [ ] Functions under 50 lines
- [ ] File under 300 lines
- [ ] C interop follows project pattern (`const c = @cImport(...)`)
- [ ] New public APIs have doc comments

### 4. Check scope

- Does the change match the branch name / issue?
- Did you accidentally change files unrelated to your task?
- Did you accidentally break an existing feature?

### 5. Report

List any issues found. Fix must-fix items before opening the PR.
Note should-fix items in the PR description.
