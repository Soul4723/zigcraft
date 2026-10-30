# Public content

Everything in this repository, its commits and its pull requests can become
public. Keep them about the project.

## What stays out

- Credentials, tokens and keys, including test credentials. Local secrets go
  in the ignored `SECRETS.local.md`.
- Personal context: names, home-directory paths, machine names, private
  email addresses, account details.
- Text of private conversations or prompts.
- Local agent context and settings (`CLAUDE.local.md` and
  `.claude/settings.local.json`). These are ignored and blocked if forced
  into the Git index; shared project entry points remain tracked.
- Local artifacts: saves, caches, build output.

## Checks

`bash scripts/setup.sh` installs the pinned compiler and scanner, turns on the Git hooks and sets a project identity
(`Zigcraft contributors` with a GitHub noreply address).

GitHub creates squash commits itself, outside the hooks. Use the explicit
noreply author email in CONTRIBUTING's merge command, and inspect the merged
commit's author and committer. GitHub chooses the account display name;
local Git settings do not change it.
The merge email must belong to the authenticated GitHub account. A synthetic
project noreply address works for local Git commits but GitHub rejects it as
a squash author address.
The merging account must use a simple public account label or the project
label accepted by `valid_identity`. Verify this before its first automated
merge; do not silently change a person's account profile or weaken the
check. After merging, run the commit check from the checked base through
new main to verify the server-created commit too.

- The pre-commit hook runs `python3 scripts/check_public_content.py --staged`
  on the staged files, checks the commit identity, and runs Gitleaks on
  staged changes.
- The commit-message hook checks private content and credentials in messages.
- The pre-push hook blocks pushes to `main`, checks new commit identities,
  messages and changed files, and runs Gitleaks on all refs.
- CI runs the content check on tracked files and Gitleaks on reachable
  history, plus metadata, messages and changed files in new commits.
  On PRs, metadata checks use the proposed head; build and content checks
  use the merged tree. GitHub's temporary merge identity is not proposed
  commit metadata. Actual merged commits are checked again on main.
- Before publishing PR descriptions or other text, use `--text <file>` and
  Gitleaks on that file as CONTRIBUTING shows.

The content check looks for home-directory paths, personal email addresses,
private keys, private or generated file names, binary files and unusual Git
file modes. Gitleaks looks for credentials. Neither recognizes every kind of
personal context, so read your own diff and pull request text too. Changing
what the content check allows needs a narrow change to the script and its
tests in `scripts/test_public_content.py`.

## Existing history

Deleting a file or changing the Git identity affects only new commits. Commits
from before the cleanup carry their original author metadata and include a
local home-directory path that later commits removed. One pull request body
contained the same path; it has been edited, but GitHub can keep earlier
versions of edited text. Rewriting branches does not remove copies held in
pull requests or elsewhere. Historical contributor email addresses and local
file paths are retained; they do not by themselves block publication. This
does not permit credentials, private conversations or account details.
Changing repository visibility is a separate decision, not routine work.

The 2026-10-30 audit found no credential matches in reachable Git history
and no private conversation content in the inspected files. Earlier Actions
logs were checked where available; 135 downloads returned HTTP 404 and could
not be inspected. These are bounded checks, not proof that every historical
surface is free of private content.

## Public repository protections

The repository is public. GitHub secret scanning and push protection are
enabled in addition to the local hooks and CI scans. Main requires a PR,
an up-to-date branch, and passing `build-and-test` and `public-content`
checks, including for administrators. Force pushes and deletion of main are
blocked. Human review approval is not required; agents still review their
own diffs before merging. Local checks cannot bypass these protections.

## A suspected leak

1. Stop the push or merge.
2. If it is a credential, revoke it first.
3. Remove the private content from the change and check the branch's earlier
   commits.
4. If it reached GitHub, check the related pull requests, comments and
   Actions logs too.
5. Report the category and location only. Do not copy the private value into
   an issue, comment or commit.
