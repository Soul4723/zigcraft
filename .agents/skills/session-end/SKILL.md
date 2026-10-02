---
name: session-end
description: End-of-session checklist. Run at the end of every session to commit work, document findings, and prepare for the next session.
---

Every session ends here. Do not skip any step.

## Steps

### 1. Verify everything builds and tests pass
```bash
zig build          # compiles
zig build test     # all tests pass
```
If either fails, fix it before committing.

### 2. Commit all work
```bash
git add -A
git status          # double-check what you are committing
git diff --cached --stat
git commit -m "<type>: <description>"
git push -u origin <branch>
```
Commit types: feat, fix, refactor, docs, build, test
Multiple logical changes = multiple commits. Each must build and test.

### 3. Open a PR (or update existing one)
```bash
gh pr create --title "<type>: <title>" --body-file /tmp/pr_body.md --base main
```
Or if PR exists, push updates it automatically.

### 4. Write a session log
Create `docs/sessions/NNN.md` with:
- Date
- Goal
- What was done
- Blockers/issues
- Next session should pick up

### 5. Update docs
- `docs/STATUS.md` if project state changed
- `docs/architecture/OVERVIEW.md` if structure changed
- `docs/decisions/NNN.md` for new decisions
- `docs/learnings/` for things future sessions should know

### 6. Final verification
- git status clean
- pushed to remote
- PR open (if applicable)
- Session log exists
- No temp files in repo
