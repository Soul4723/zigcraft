---
name: session-start
description: >-
  Mandatory start-of-session procedure. Read project state, claim work,
  create a branch. Do not skip any step.
---

## You must do all of these before writing any code

### 1. Read project state

```bash
cat docs/STATUS.md
cat docs/ROADMAP.md
cat docs/architecture/OVERVIEW.md
ls docs/sessions/           # then read the latest one
git fetch --prune origin
git branch --show-current
gh issue list
gh pr list
```

### 2. Check for conflicts

If another branch or PR touches the same files you'd need to change,
pick different work. Check with:

```bash
git log origin/<branch> --oneline --name-only
```

### 3. Decide what to do

Priority order:
1. Is something broken? (check STATUS.md) → fix it
2. Is a PR waiting for merge conflicts? → resolve them
3. Is a milestone partially done? → finish it
4. Otherwise → take the next roadmap item

### 4. Create a branch from main

```bash
git checkout main
git pull origin main
git checkout -b <type>/<name>
```

Branch types: `feat/`, `fix/`, `refactor/`, `docs/`, `build/`, `test/`,
`prototype/`, `research/`

### 5. State your plan

Before writing code, say what you're going to do in one or two sentences.

### 6. Before ending the session

Every session must end with:

```bash
# Commit all work
git add -A
git status  # verify what you're committing
zig build   # verify it compiles
git commit -m "<type>: <description>"
git push -u origin <branch>

# Open PR (or draft if WIP)
gh pr create --title "<type>: <title>" --body-file /tmp/pr_body.md --base main
```

Then update these files:
- Write `docs/sessions/NNN.md` (next number after the latest)
- Update `docs/STATUS.md` if project state changed
- Update `docs/architecture/OVERVIEW.md` if code structure changed
- Update `docs/ROADMAP.md` if a milestone was completed

Commit and push the doc updates as a separate commit.
