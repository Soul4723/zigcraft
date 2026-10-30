#!/usr/bin/env python3
"""Bounded publication guard; use a dedicated secret scanner as well.

Default: tracked working-tree files. --staged: all index blobs, never worktree
contents. --commits RANGE: new commit metadata and changed blobs. Binary files and unusual Git modes require review before publication.
"""
import argparse
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


class ScanError(Exception):
    pass


def git(*args):
    try:
        result = subprocess.run(["git", *args], capture_output=True, check=False)
    except OSError as exc:
        raise ScanError("git invocation failed") from exc
    if result.returncode:
        raise ScanError("git command failed")
    return result.stdout


PATTERNS = {
    "private home path": re.compile(r"/(?:home|Users)/[A-Za-z0-9_.-]+(?:/|\b)"),
    "private Windows path": re.compile(r"[A-Za-z]:[\\/]+Users[\\/]+[A-Za-z0-9_.-]+", re.I),
    "personal email": re.compile(r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+)"),
    "private key": re.compile(r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----"),
}
DENIED_DIRS = {
    "saves", ".local", ".cache", "__pycache__", ".zig-cache", "zig-cache",
    "zig-out", "node_modules", "build", "dist", ".aws", ".ssh", ".gnupg",
}
DENIED_NAMES = {
    "secrets.local.md", "claude.local.md", ".env", ".netrc", "_netrc", ".npmrc", ".pypirc",
    "credentials", "credentials.json", "service-account.json", "id_rsa",
    "id_dsa", "id_ecdsa", "id_ed25519",
}


def filename_category(path):
    parts = path.lower().split("/")
    name = parts[-1]
    if (any(part in DENIED_DIRS for part in parts[:-1]) or name in DENIED_NAMES
            or parts[-2:] == [".claude", "settings.local.json"]
            or name.endswith((".pem", ".key", ".p12", ".pfx", ".pyc"))
            or (name.startswith(".env.") and name != ".env.example")):
        return "private or generated filename"
    return None


def findings(path, data):
    category = filename_category(path)
    if category:
        yield 1, category
    try:
        content = data.decode("utf-8")
    except UnicodeDecodeError:
        yield 1, "unsupported binary content"
        return
    if any(ord(char) < 32 and char not in "\n\r\t" for char in content):
        yield 1, "unsupported binary content"
        return
    for number, line in enumerate(content.splitlines(), 1):
        for category, pattern in PATTERNS.items():
            for match in pattern.finditer(line):
                if category == "personal email":
                    domain = match.group(1).lower()
                    if match.group(0).lower() in {"noreply@github.com", "noreply@anthropic.com"} or domain in {"example.com", "example.org", "example.net", "users.noreply.github.com", "noreply.github.com"}:
                        continue
                yield number, category
                break
        if Path(path).name.lower() == ".env.example":
            value_line = line.strip()
            if not value_line or value_line.startswith("#"):
                continue
            assignment = re.fullmatch(r"(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=\s*(.*)", value_line)
            value = assignment.group(1).strip().strip("\"'") if assignment else None
            if value is None or not re.fullmatch(r"(?i)(?:|example|placeholder|changeme|replace_me|your_[A-Za-z0-9_]+|<[^<>]+>)", value):
                yield number, "unsanitized environment example"


def scan(staged=False):
    root = Path(os.fsdecode(git("rev-parse", "--show-toplevel").rstrip(b"\n")))
    records = git("-C", str(root), "ls-files", "--stage", "-z").split(b"\0")
    entries = [record for record in records if record]
    if not entries:
        raise ScanError("empty index; nothing inspected")
    inspected = errors = 0
    for entry in entries:
        metadata, raw_path = entry.split(b"\t", 1)
        mode, oid, stage = metadata.split()
        path = os.fsdecode(raw_path)
        display = json.dumps(path, ensure_ascii=True)
        if stage != b"0" or mode not in {b"100644", b"100755"}:
            print(f"{display}:1: unsupported index mode or conflict")
            errors += 1
            continue
        if staged:
            data = git("-C", str(root), "cat-file", "blob", oid.decode("ascii"))
        else:
            source = root / path
            try:
                info = source.lstat()
                if not stat.S_ISREG(info.st_mode):
                    print(f"{display}:1: unsupported working-tree file type")
                    errors += 1
                    continue
                data = source.read_bytes()
            except FileNotFoundError:
                continue  # Tracked deletions do not publish bytes.
            except OSError as exc:
                raise ScanError("cannot read tracked file") from exc
        inspected += 1
        for number, category in findings(path, data):
            print(f"{display}:{number}: {category}")
            errors += 1
    print(f"Inspected {inspected} files; {errors} findings.")
    if not inspected and not errors:
        raise ScanError("nothing inspected")
    return 1 if errors else 0


def valid_identity(name, email):
    """Accept only public account labels paired with GitHub noreply addresses."""
    return bool((name == "Zigcraft contributors" or re.fullmatch(r"[A-Za-z0-9-]+", name))
                and (email == "noreply@github.com" or re.fullmatch(
                    r"[A-Za-z0-9+_-]+@users\.noreply\.github\.com", email)))


def scan_commits(commit_range):
    if not commit_range or commit_range.startswith("-"):
        raise ScanError("invalid commit range")
    root = os.fsdecode(git("rev-parse", "--show-toplevel").rstrip(b"\n"))
    def repo_git(*args):
        return git("-C", root, *args)
    commits = repo_git("rev-list", commit_range, "--").splitlines()
    if not commits:
        print("No new commits; inspected 0 commits, 0 files; 0 findings.")
        return 0
    errors = 0
    blobs = {}
    for commit in commits:
        oid = commit.decode("ascii")
        label = oid[:12]
        metadata = repo_git("show", "-s", "--format=%an%x00%ae%x00%cn%x00%ce%x00%B", oid)
        author, author_email, committer, committer_email, message = metadata.split(b"\0", 4)
        for role, name, email in (("author", author, author_email),
                                  ("committer", committer, committer_email)):
            if not valid_identity(name.decode("utf-8"), email.decode("utf-8")):
                print(f"{label}:identity:1: nonpublic {role} identity")
                errors += 1
        for number, category in findings("commit-message", message):
            print(f"{label}:commit-message:{number}: {category}")
            errors += 1
        changed = set(repo_git("diff-tree", "--no-commit-id", "--name-only", "-r", "-m",
                               "--root", "--no-renames", "--diff-filter=ACMT", "-z", oid, "--").split(b"\0"))
        for entry in repo_git("ls-tree", "-r", "-z", "--full-tree", oid).split(b"\0"):
            if not entry:
                continue
            info, raw_path = entry.split(b"\t", 1)
            if raw_path not in changed:
                continue
            mode, kind, blob = info.split()
            path = os.fsdecode(raw_path)
            display = f"{label}:{json.dumps(path, ensure_ascii=True)}"
            categories = []
            if mode not in {b"100644", b"100755"} or kind != b"blob":
                categories.append((1, "unsupported committed file mode"))
            else:
                category = filename_category(path)
                if category:
                    categories.append((1, category))
                example = Path(path).name.lower() == ".env.example"
                key = (blob, example)
                if key not in blobs:
                    data = repo_git("cat-file", "blob", blob.decode("ascii"))
                    blobs[key] = list(findings(".env.example" if example else "content", data))
                categories.extend(blobs[key])
            for number, category in categories:
                print(f"{display}:{number}: {category}")
                errors += 1
    print(f"Inspected {len(commits)} commits, {len(blobs)} unique file blobs; {errors} findings.")
    return 1 if errors else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--staged", action="store_true", help="inspect the complete Git index")
    modes.add_argument("--commits", metavar="RANGE", help="inspect every new commit in a Git revision range")
    modes.add_argument("--text", metavar="FILE", help="inspect a proposed PR description or other public text")
    args = parser.parse_args()
    try:
        if args.text is not None:
            data = Path(args.text).read_bytes()
            if not data:
                raise ScanError("empty public text; nothing inspected")
            errors = list(findings("publication-text", data))
            for number, category in errors:
                print(f"publication-text:{number}: {category}")
            print(f"Inspected 1 public text; {len(errors)} findings.")
            return 1 if errors else 0
        return scan_commits(args.commits) if args.commits is not None else scan(args.staged)
    except OSError:
        print("Public content check failed: cannot read public text", file=sys.stderr)
        return 1
    except (ScanError, ValueError) as exc:
        print(f"Public content check failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
