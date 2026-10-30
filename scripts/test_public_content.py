#!/usr/bin/env python3
"""Publication-guard integration tests; every Git index is temporary."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCANNER = Path(__file__).with_name("check_public_content.py").resolve()
HOME_PATH = "/" + "home/" + "synthetic-user/project"
WINDOWS_PATH = "C:" + "\\" + "Users" + "\\" + "synthetic-user/project"
EMAIL = "synthetic-person" + "@" + "invalid.test"


class PublicContentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Zigcraft contributors")
        self.git("config", "user.email", "zigcraft@users.noreply.github.com")
        self.git("config", "core.hooksPath", os.devnull)
        self.put("readme.txt", "Public example\n")
        self.git("add", "readme.txt")

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, check=True,
                              capture_output=True).stdout

    def put(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content if isinstance(content, bytes) else content.encode())

    def check(self, *args, cwd=None, env=None):
        return subprocess.run([sys.executable, str(SCANNER), *args],
                              cwd=cwd or self.repo, env=env,
                              capture_output=True, text=True)

    def assert_blocked(self, result, category):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(category, result.stdout + result.stderr)
        for private in (HOME_PATH, WINDOWS_PATH, EMAIL):
            self.assertNotIn(private, result.stdout + result.stderr)

    def test_staged_bad_bytes_cannot_be_hidden_by_repaired_worktree(self):
        self.put("notes.txt", HOME_PATH)
        self.git("add", "notes.txt")
        self.put("notes.txt", "sanitized\n")
        self.assert_blocked(self.check("--staged"), "private home path")
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Inspected 2 files; 0 findings.", result.stdout)

    def test_staged_good_bytes_ignore_bad_worktree(self):
        self.put("notes.txt", "sanitized\n")
        self.git("add", "notes.txt")
        self.put("notes.txt", EMAIL)
        self.assertEqual(self.check("--staged").returncode, 0)
        self.assert_blocked(self.check(), "personal email")

    def test_paths_email_and_private_key_are_blocked(self):
        cases = [(HOME_PATH, "private home path"),
                 ("/" + "Users/" + "synthetic-user/file", "private home path"),
                 (WINDOWS_PATH, "private Windows path"),
                 (EMAIL, "personal email"),
                 ("-----BEGIN " + "RSA PRIVATE KEY-----", "private key")]
        for content, category in cases:
            with self.subTest(category=category):
                self.put("readme.txt", content)
                self.assert_blocked(self.check(), category)

    def test_private_and_generated_filenames_are_blocked(self):
        for name in ("SECRETS.local.md", ".env", ".env.production", "key.pem",
                     "key.key", "saves/world.txt", ".local/state.txt",
                     ".zig-cache/cache.txt", "zig-out/game", "build/file",
                     ".aws/credentials", ".netrc", "id_ed25519",
                     "CLAUDE.local.md", ".claude/settings.local.json"):
            with self.subTest(name=name):
                self.put(name, "placeholder\n")
                self.git("add", "-f", "--", name)
                self.assert_blocked(self.check("--staged"), "private or generated filename")
                self.git("rm", "--cached", "--", name)

    def test_safe_examples_and_unicode_space_names(self):
        self.put("example space 雪.txt", "Contact: demo" + "@" + "example.org\n"
                 + "42+demo" + "@" + "users.noreply.github.com\n")
        self.put(".env.example", '# Template\nTOKEN="<replace-me>"\nHOST=your_host\nEMPTY=\n')
        self.git("add", ".")
        result = self.check("--staged")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Inspected 3 files", result.stdout)
        self.put("example space 雪.txt", EMAIL)
        self.git("add", ".")
        result = self.check("--staged")
        self.assert_blocked(result, "personal email")
        self.assertIn("example space", result.stdout)

    def test_environment_example_requires_placeholders(self):
        self.put(".env.example", "TOKEN=unreviewed-value\n")
        self.git("add", ".")
        self.assert_blocked(self.check(), "unsanitized environment example")

    def test_staged_removal_and_worktree_deletion(self):
        self.put("removed.txt", HOME_PATH)
        self.git("add", "removed.txt")
        self.git("rm", "--cached", "removed.txt")
        self.assertEqual(self.check("--staged").returncode, 0)
        self.put("deleted.txt", HOME_PATH)
        self.git("add", "deleted.txt")
        (self.repo / "deleted.txt").unlink()
        self.assertEqual(self.check().returncode, 0)
        self.assert_blocked(self.check("--staged"), "private home path")

    def test_binary_and_symlink_are_blocked(self):
        self.put("readme.txt", b"binary\x00data")
        self.git("add", ".")
        for args in ((), ("--staged",)):
            self.assert_blocked(self.check(*args), "unsupported binary content")
        self.put("readme.txt", b"\xff")
        self.assert_blocked(self.check(), "unsupported binary content")
        self.put("readme.txt", "safe\n")
        (self.repo / "link").symlink_to("readme.txt")
        self.git("add", ".")
        self.assert_blocked(self.check("--staged"), "unsupported index mode")
        self.git("rm", "--cached", "link")
        (self.repo / "readme.txt").unlink()
        (self.repo / "readme.txt").symlink_to("outside")
        self.assert_blocked(self.check(), "unsupported working-tree file type")

    def test_submodule_and_conflict_are_blocked(self):
        oid = self.git("hash-object", "-w", "readme.txt").decode().strip()
        self.git("update-index", "--add", "--cacheinfo", "160000," + oid + ",module")
        self.assert_blocked(self.check("--staged"), "unsupported index mode")
        self.git("update-index", "--force-remove", "module")
        subprocess.run(["git", "update-index", "--index-info"], cwd=self.repo,
                       input=("100644 " + oid + " 1\tconflict.txt\n").encode(),
                       capture_output=True, check=True)
        self.assert_blocked(self.check("--staged"), "unsupported index mode or conflict")

    def test_empty_index_no_files_and_git_errors_fail_closed(self):
        self.git("rm", "--cached", "readme.txt")
        self.assert_blocked(self.check("--staged"), "empty index")
        self.git("add", "readme.txt")
        (self.repo / "readme.txt").unlink()
        self.assert_blocked(self.check(), "nothing inspected")
        outside = self.repo / "not-a-repo"
        outside.mkdir()
        environment = os.environ.copy()
        environment["PATH"] = str(outside)
        self.assert_blocked(self.check(env=environment), "git invocation failed")
        with tempfile.TemporaryDirectory() as directory:
            self.assert_blocked(self.check(cwd=directory), "git command failed")

    def test_subdirectory_still_scans_entire_repository(self):
        folder = self.repo / "nested"
        folder.mkdir()
        self.put("readme.txt", EMAIL)
        self.assert_blocked(self.check(cwd=folder), "personal email")

    def commit(self, message="Public change", **identity):
        environment = os.environ.copy()
        for role in ("AUTHOR", "COMMITTER"):
            environment["GIT_" + role + "_NAME"] = "Zigcraft contributors"
            environment["GIT_" + role + "_EMAIL"] = "zigcraft@users.noreply.github.com"
        environment.update(identity)
        self.git("add", "-A")
        subprocess.run(["git", "commit", "-q", "--allow-empty", "-m", message],
                       cwd=self.repo, env=environment, check=True, capture_output=True)
        return self.git("rev-parse", "HEAD").decode().strip()

    def test_commit_safe_root_and_public_account_metadata(self):
        oid = self.commit(GIT_AUTHOR_NAME="public-account", GIT_COMMITTER_NAME="GitHub",
                          GIT_COMMITTER_EMAIL="noreply@github.com")
        result = self.check("--commits", oid)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Inspected 1 commits, 1 unique file blobs; 0 findings.", result.stdout)

    def test_commit_rejects_author_and_committer_without_leaking_identity(self):
        base = self.commit()
        for role in ("AUTHOR", "COMMITTER"):
            for suffix, value in (("NAME", "Synthetic Private Person"), ("EMAIL", EMAIL)):
                with self.subTest(role=role, suffix=suffix):
                    oid = self.commit(**{"GIT_" + role + "_" + suffix: value})
                    result = self.check("--commits", base + ".." + oid)
                    self.assert_blocked(result, "nonpublic " + role.lower() + " identity")
                    self.assertNotIn("Synthetic Private Person", result.stdout + result.stderr)
                    base = oid

    def test_commit_message_is_scanned(self):
        base = self.commit()
        oid = self.commit("Details: " + HOME_PATH)
        self.assert_blocked(self.check("--commits", base + ".." + oid), "private home path")

    def test_intermediate_private_blob_is_rejected_after_revert(self):
        base = self.commit()
        self.put("readme.txt", HOME_PATH)
        self.commit()
        self.put("readme.txt", "Public example\n")
        head = self.commit()
        self.assertEqual(self.check("--staged").returncode, 0)
        self.assert_blocked(self.check("--commits", base + ".." + head), "private home path")

    def test_intermediate_forbidden_files_binary_and_symlink(self):
        base = self.commit()
        for name, content, category in (
                (".env", "placeholder", "private or generated filename"),
                ("image.bin", b"data\x00", "unsupported binary content"),
                ("link", None, "unsupported committed file mode")):
            with self.subTest(name=name):
                if content is None:
                    (self.repo / name).symlink_to("readme.txt")
                else:
                    self.put(name, content)
                self.commit()
                (self.repo / name).unlink()
                head = self.commit()
                self.assertEqual(self.check("--staged").returncode, 0)
                self.assert_blocked(self.check("--commits", base + ".." + head), category)
                base = head

    def test_commit_range_excludes_private_legacy_baseline_and_deletions(self):
        self.put("legacy.txt", HOME_PATH)
        baseline = self.commit(GIT_AUTHOR_EMAIL=EMAIL)
        self.put("new.txt", "Public content\n")
        head = self.commit()
        result = self.check("--commits", baseline + ".." + head)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("1 unique file blobs", result.stdout)
        (self.repo / "legacy.txt").unlink()
        head = self.commit()
        self.assertEqual(self.check("--commits", baseline + ".." + head).returncode, 0)

    def test_merge_commit_changes_are_scanned_from_subdirectory(self):
        base = self.commit()
        self.git("checkout", "-q", "-b", "side")
        self.put("side.txt", "Public side\n")
        side = self.commit()
        self.git("checkout", "-q", "-b", "mainline", base)
        self.put("main.txt", "Public main\n")
        main = self.commit()
        self.git("merge", "--no-commit", "--no-ff", side)
        self.put("merge-only.txt", "Public merge\n")
        safe_merge = self.commit()
        result = self.check("--commits", main + ".." + safe_merge)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.put("merge-only.txt", EMAIL)
        self.git("add", ".")
        self.git("commit", "--amend", "--no-edit", "-q")
        merge = self.git("rev-parse", "HEAD").decode().strip()
        folder = self.repo / "nested"
        folder.mkdir()
        self.assert_blocked(self.check("--commits", main + ".." + merge, cwd=folder), "personal email")
        self.git("rm", "merge-only.txt")
        fixed = self.commit()
        result = self.check("--commits", merge + ".." + fixed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_empty_invalid_and_option_like_commit_ranges(self):
        oid = self.commit()
        result = self.check("--commits", oid + ".." + oid)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("No new commits", result.stdout)
        self.assert_blocked(self.check("--commits", "missing..HEAD"), "git command failed")
        self.assert_blocked(self.check("--commits=--all"), "invalid commit range")
        self.assertEqual(self.check("--staged", "--commits", "HEAD").returncode, 2)

    def test_repeated_commit_blobs_are_deduplicated(self):
        base = self.commit()
        self.put("readme.txt", "Second public value\n")
        self.commit()
        self.put("readme.txt", "Third public value\n")
        self.commit()
        self.put("readme.txt", "Second public value\n")
        head = self.commit()
        result = self.check("--commits", base + ".." + head)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("3 commits, 2 unique file blobs", result.stdout)

    def test_unknown_option_is_an_error(self):
        self.assertEqual(self.check("--unknown").returncode, 2)

    def test_public_text_checks_untracked_descriptions_without_git(self):
        with tempfile.TemporaryDirectory() as directory:
            body = Path(directory) / "description.md"
            body.write_text(HOME_PATH)
            self.assert_blocked(self.check("--text", str(body), cwd=directory), "private home path")
            body.write_text("Checked public project change.\n")
            self.assertEqual(self.check("--text", str(body), cwd=directory).returncode, 0)
            body.write_text("")
            self.assert_blocked(self.check("--text", str(body)), "empty public text")
            body.unlink()
            self.assert_blocked(self.check("--text", str(body)), "cannot read public text")

    def test_public_agent_attribution_does_not_allow_personal_company_email(self):
        self.put("readme.txt", "Co-Authored-By: Agent <noreply@anthropic.com>\n")
        self.assertEqual(self.check().returncode, 0)
        self.put("readme.txt", "synthetic-person" + "@" + "anthropic.com")
        self.assert_blocked(self.check(), "personal email")


if __name__ == "__main__":
    unittest.main()
