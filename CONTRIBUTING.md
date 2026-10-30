# Contributing

This is the workflow for every change, whether an agent or a person makes
it. Agents run it end to end without waiting for a human; see
[AGENTS.md](AGENTS.md). Build requirements are in [README.md](README.md#build-and-run).

## Workflow

Development also needs Git, the GitHub CLI, Python 3, curl, tar and
sha256sum. Authenticate the GitHub CLI before starting autonomous sessions.

### 1. Start

Read [docs/STATUS.md](docs/STATUS.md), [docs/ROADMAP.md](docs/ROADMAP.md)
and [docs/sessions/README.md](docs/sessions/README.md). Then see what other
sessions are doing:

```bash
git fetch --prune origin
gh pr list --limit 1000
```

Take the highest unblocked roadmap item that no open pull request covers.
Record an external blocker once and continue with the next item. If code on
`main` is broken, fix that first.

### 2. Branch and set up

Start from freshly fetched `origin/main` in a clean checkout. When another
session may be using the checkout, work in your own worktree instead of
switching its branch:

```bash
git worktree add ../zigcraft-<name> -b <type>/<name> origin/main
cd ../zigcraft-<name>
bash scripts/setup.sh
export PATH="$PWD/.local/bin:$PATH"
```

Run `bash scripts/setup.sh` once in every new clone or worktree, and again if
a hook reports that Gitleaks or the hooks are missing. It installs a pinned
Zig 0.16.0 and Gitleaks into the ignored `.local/`, turns on the hooks in `.githooks/`,
and sets this checkout's Git identity to `Zigcraft contributors` with a
GitHub noreply address. It supports Linux x86_64 only; on other platforms it
prints what to install by hand.

Branch types: `feat/`, `fix/`, `refactor/`, `docs/`, `build/`, `test/`.
See [docs/PARALLEL-SESSIONS.md](docs/PARALLEL-SESSIONS.md) for files that
conflict often.

### 3. Change

Make one concern per branch, and run `zig build` after each meaningful change.

Before writing a new module, search for one that already covers the
mechanic, and extend it instead of adding a second one:

```bash
rg --files src/world | rg -i '<word>'
rg -n -i '<word>' src/
```

[docs/STATUS.md](docs/STATUS.md) lists mechanics that already have
duplicate modules. Do not add to that list.

A gameplay change is done only when all of these hold:

1. A player action (a key or mouse button) or the frame loop reaches the new
   code during normal play.
2. Its result changes game state (blocks, an entity, the player, the
   inventory) or what the player sees or hears.
3. A test checks the rule.
4. You ran the game and saw it work, or the pull request says you could not.

A call whose value and side effects never reach the game, a module that only
has tests, or an item that cannot be obtained or used is not done. Ignoring a
return value is fine when the function changes state that the game uses.

Update the documentation listed below in the same pull request before
checking and committing the change.

### 4. Check

```bash
bash scripts/check.sh
```

This runs the content-check tests, the content check on all tracked files,
`zig build` and `zig build test`. It uses the project compiler installed by
setup, or Zig 0.16.0 on `PATH`. Set
`ZIG=/path/to/zig` when 0.16.0 is not the `zig` on your `PATH`. For a change a
player can see, also run `zig build run` and try it.

### 5. Review your own diff

Read `git diff origin/main` in full, and read each untracked file listed by
`git status --short`. Check:

- The diff matches the branch's one concern, with no unrelated files.
- For gameplay work, every item under step 3's done list holds.
- Returned slices borrow live caller-owned storage or an owned allocation,
  never an array in a by-value receiver.
- No commented-out code, no `@panic` where an error can be returned, no
  hard-coded machine paths.
- New files with tests are listed in `test_files` in `build.zig`.
- The documentation listed below matches the change.

Fix what you find before committing.

### 6. Commit

Everything committed becomes public. Stage named paths rather than the whole
tree:

```bash
git add <paths>
git diff --cached
git commit -m "<type>: <description>"
```

The pre-commit hook checks the staged content, the commit identity and, with
Gitleaks, staged secrets. If it fails, fix the cause; do not bypass it.
[docs/PUBLICATION.md](docs/PUBLICATION.md) says what must stay out of the
repository and what to do about a leak.

Commit types: `feat`, `fix`, `refactor`, `docs`, `build`, `test`. Keep each
commit to one logical change that builds.

### 7. Open and merge the pull request

```bash
git push -u origin <branch>
python3 scripts/check_public_content.py --text /tmp/zigcraft-pr.md
.local/bin/gitleaks stdin --redact --ignore-gitleaks-allow < /tmp/zigcraft-pr.md
gh pr create --base main --title "<type>: <title>" --body-file /tmp/zigcraft-pr.md
```

The pre-push hook blocks pushes to `main` and scans all refs for secrets. The
pull request body says what changed, how it was checked, and what was not
checked. Write it to `/tmp/zigcraft-pr.md` before the commands above and use
that file with `--body-file`. Check edited descriptions and other public
text the same way before publishing them.

Before the final check, fetch and ensure the branch includes current main:

```bash
git fetch origin
git merge-base --is-ancestor origin/main HEAD
```

If it does not, rebase on `origin/main`, resolve conflicts, check again and
push. Before merging, the checkout must be clean and `git rev-parse HEAD`
must equal the PR's `headRefOid`. Fetch again; if main moved, repeat this
check. GitHub does not enforce checks or auto-merge here, so inspect the
head commit and its checks yourself:

```bash
gh pr view <number> --json headRefOid,statusCheckRollup
```

Merge only when every check for that head commit has passed, and pin the
merge to that commit:

```bash
gh pr merge <number> --squash --match-head-commit <headRefOid> --author-email zigcraft@users.noreply.github.com
```

Verify the PR is merged. GitHub deletes its remote branch. From another
checkout, remove your task worktree, delete its local branch, and fetch with
`--prune`. With squash merges `git branch -D <branch>` may be needed; use it
only after verifying that branch's exact head was merged.

An empty `statusCheckRollup` means no check ran. Wait for running checks and
fix failures caused by the change.

If GitHub cannot start jobs, inspect the run:

```bash
gh run view <run-id> --json jobs --jq '.jobs[]|{name,conclusion,steps:(.steps|length)}'
```

The local fallback applies only when all jobs stopped before any step ran
and the run's annotation confirms an external service restriction. A code
or test failure does not qualify. On the clean, current PR head, run:

```bash
bash scripts/check.sh
bash scripts/check_commits.sh origin/main..HEAD
python3 scripts/check_public_content.py --staged
git diff --check
```

If the PR changes checks, hooks or their configuration, also run the base
branch's available privacy scanner, scanner tests and Gitleaks configuration
against the proposed change from temporary files. Review the checker diff;
do not let the change disable its own gate. For the initial introduction,
where the base has no checker, use independent review and failure-case tests.

Merge only if all checks pass and the PR records the head SHA, base SHA,
commands, results and observed service failure. Check the new main once
after a fallback merge. Use hosted checks again when they are available.

If neither check route succeeds, leave the pull request open with its
blocker recorded in the description; the next session finds it with
`gh pr list`.

## Documentation to update before committing

In the same pull request as the change:

- [docs/STATUS.md](docs/STATUS.md): replace what changed in what works,
  what is only tested, and known problems.
- [docs/ROADMAP.md](docs/ROADMAP.md): remove finished items, add new ones.
- [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md): when
  structure changes.
- [docs/sessions/README.md](docs/sessions/README.md): one line for the
  session.
- `docs/decisions/NNN-<topic>.md`: a new decision record for a new
  architectural choice or dependency.
- `docs/learnings/`: anything about Zig or the libraries a later session
  would otherwise rediscover.

If the work does not fit one session, merge what is complete and working and
put the rest in ROADMAP.md.

## Decisions

Decisions in `docs/decisions/` stand until there is concrete evidence
against them. When two approaches look equally good, pick one, record it in
a decision record, and continue. Adding a library needs a decision record
that names the alternatives.

## Code conventions

- `camelCase` for functions and variables, `PascalCase` for types,
  `snake_case` for files. Descriptive names: `chunk_mesh`, not `cm`.
- Return errors with error unions; do not discard them silently. Print a
  message where the error is handled.
- Keep new code out of `main()` in `src/main.zig`. Put state and rules in a
  module that owns them, and keep `main.zig` to input and dispatch.
- Keep files focused on one mechanic. `src/main.zig` and `src/inventory.zig`
  are far too large; shrink them, do not grow them.
- Put a doc comment on each new public function.
- C interop: one `@cImport` per file that needs it. For OpenGL, use
  `GL_GLEXT_PROTOTYPES` with `GL/glcorearb.h` (GLEW does not work on
  Wayland):

  ```zig
  const c = @cImport({
      @cDefine("GL_GLEXT_PROTOTYPES", "1");
      @cInclude("GL/glcorearb.h");
      @cInclude("GLFW/glfw3.h");
  });
  ```

## Zig 0.16 gotchas

Model training data mostly covers older Zig. Check APIs against the standard
library source of the Zig 0.16.0 install (the `std` folder in the `lib_dir`
that `zig env` prints) and [docs/learnings/zig-0.16-changes.md](docs/learnings/zig-0.16-changes.md).

- **Imports outside a test target's directory fail.** A standalone test
  target rooted at `src/world/foo.zig` cannot `@import("../bar.zig")`
  ("import of file outside module path"). Keep files that import each other
  in one directory, or pass callbacks and duck-typed parameters.
- **Imported files' tests are not collected.** `b.addTest` on the executable
  module runs only the test blocks in `src/main.zig`. Each file with tests
  needs its own entry in `test_files` in `build.zig`.
- **Each `@cImport` makes distinct opaque types.** A `*c.GLFWwindow` from one
  file is a different type in another file. Do GLFW calls in the file that
  owns the window and pass plain values such as `c_int` key codes, which are
  the same type everywhere.
