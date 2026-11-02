"""Protect upstream selection, persistent build ownership, and publication gates."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / "control-plane"
sys.path.insert(0, str(SCRIPTS))
from chromium_fork import refresh_host_inputs, restore_host_base, select_update
from chromium_artifact import release_ready
from chromium_engine import asset_name, host_patch

spec = importlib.util.spec_from_file_location("publish_chromium_update", SCRIPTS / "publish-chromium-update.py")
publication = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publication)


class UpstreamSelectionTests(unittest.TestCase):
    def test_patch_releases_stay_eligible_after_the_next_milestone_ships(self):
        releases = ["157.0.8103.26", "156.0.8078.80", "156.0.8078.47", "unrecognized"]
        result = select_update("156.0.8078.47", releases)
        self.assertEqual(result["candidate"], "156.0.8078.80")
        self.assertEqual(result["latest"], "157.0.8103.26")
        self.assertTrue(result["majorReviewRequired"])
        self.assertEqual(select_update("156.0.8078.47", releases, True)["candidate"], "157.0.8103.26")

    def test_updates_advance_but_downgrades_and_equal_versions_do_not(self):
        releases = ["156.0.8078.80", "156.0.8078.79"]
        self.assertEqual(select_update("156.0.8078.79", releases)["candidate"], "156.0.8078.80")
        self.assertIsNone(select_update("156.0.8078.80", releases)["candidate"])


class WorkspaceTests(unittest.TestCase):
    def host(self, root, patches):
        repo = root / "repo"
        host = repo / "CrestEngines/Chromium"
        (host / "Patches").mkdir(parents=True)
        for name, text in patches.items():
            (host / "Patches" / name).write_text(text)
        (host / "Patches/series").write_text("# order\n" + "".join(f"{name}\n" for name in patches))
        return repo, host

    def test_host_refresh_requires_every_patch_hunk_and_preserves_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "src"
            patch = "--- a/sample.cc\n+++ b/sample.cc\n@@ -1,3 +1,3 @@\n context\n-old\n+new\n tail\n"
            repo, host = self.host(root, {"native-host.patch": patch})
            source.mkdir()
            original = "context\nold\ntail\n"
            (source / "sample.cc").write_text(original)
            refresh_host_inputs(repo, source)
            pinned = (host / "host-inputs.json").read_text()
            hashes = json.loads(pinned)["sample.cc"]
            self.assertNotEqual(hashes["before"], hashes["after"])
            self.assertEqual((source / "sample.cc").read_text(), original)
            installed = root / "host.json"
            installed.write_text(json.dumps({"patch": patch, "inputs": json.loads(pinned)}))
            (source / "sample.cc").write_text("context\nnew\ntail\n")
            refresh_host_inputs(repo, source, installed)
            self.assertEqual((host / "host-inputs.json").read_text(), pinned)
            self.assertEqual((source / "sample.cc").read_text(), "context\nnew\ntail\n")
            (source / "sample.cc").write_text("changed context\nold\ntail\n")
            with self.assertRaises(subprocess.CalledProcessError):
                refresh_host_inputs(repo, source)
            self.assertEqual((host / "host-inputs.json").read_text(), pinned)

    def test_a_file_two_patches_change_takes_them_in_order_and_restores_in_reverse(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "src"
            first = "--- a/sample.cc\n+++ b/sample.cc\n@@ -1,3 +1,3 @@\n a\n-b\n+B\n c\n"
            second = "--- a/sample.cc\n+++ b/sample.cc\n@@ -1,4 +1,4 @@\n a\n B\n-c\n+C\n d\n"
            repo, host = self.host(root, {"native-host.patch": first, "privacy.patch": second})
            source.mkdir()
            (source / "sample.cc").write_text("a\nb\nc\nd\n")
            refresh_host_inputs(repo, source)
            hashes = json.loads((host / "host-inputs.json").read_text())["sample.cc"]
            combined = host_patch(repo)
            subprocess.run(["patch", "--batch", "--fuzz=0", "-p1", "-s"], input=combined, text=True, cwd=source, check=True)
            self.assertEqual((source / "sample.cc").read_text(), "a\nB\nC\nd\n")
            self.assertEqual(hashlib.sha256((source / "sample.cc").read_bytes()).hexdigest(), hashes["after"])
            restore_host_base(source, {"patch": combined, "inputs": {"sample.cc": hashes}}, {})
            self.assertEqual((source / "sample.cc").read_text(), "a\nb\nc\nd\n")
            (host / "Patches/privacy.patch").write_text(second + second)
            with self.assertRaises(ValueError):
                host_patch(repo)


class PromotionTests(unittest.TestCase):
    def test_automatic_publication_requires_opt_in_and_development_on_main(self):
        policy = {"automaticChannel": "development", "integrationBranch": "main", "automaticMajorUpdates": False}
        arguments = dict(enabled="true", default_branch="main", major_update=False)
        self.assertTrue(publication.automatic_release_allowed(policy, **arguments))
        for name, value in (("enabled", "false"), ("enabled", None),
                            ("default_branch", "chromium-control-plane"), ("major_update", True)):
            with self.subTest(gate=name):
                self.assertFalse(publication.automatic_release_allowed(policy, **(arguments | {name: value})))
        for channel in ("stable", "experimental", "nightly"):
            with self.subTest(channel=channel):
                self.assertFalse(publication.automatic_release_allowed(policy | {"automaticChannel": channel}, **arguments))

    def test_engine_must_be_complete_and_match_the_full_key(self):
        key = "a" * 64
        asset = asset_name(key)
        release = {"draft": False, "body": f"Engine key `{key}`", "assets": [
            {"name": name, "size": 100, "state": "uploaded"} for name in (asset, f"{asset}.sha256")]}
        self.assertTrue(release_ready(release, key))
        self.assertFalse(release_ready(None, key))
        self.assertFalse(release_ready(release | {"draft": True}, key))
        for incomplete in (release | {"assets": release["assets"][:1]},
                           release | {"body": "a" * 16 + "b" * 48},
                           release | {"assets": [item | {"state": "new"} for item in release["assets"]]},
                           release | {"assets": [item | {"size": 0} for item in release["assets"]]}):
            with self.subTest(release=incomplete), self.assertRaises(ValueError):
                release_ready(incomplete, key)


class ReleaseNoteTests(unittest.TestCase):
    def test_update_note_is_its_own_entry_file_and_never_reuses_an_id(self):
        note = {"category": "fixed", "message": "Chromium is updated to 154.0.8037.97 with upstream fixes."}
        with tempfile.TemporaryDirectory() as directory:
            notes = Path(directory)
            path, text = publication.release_note_file(notes, "chromium-upstream-154", note)
            self.assertEqual(path, notes / "chromium-upstream-154.json")
            self.assertEqual(json.loads(text), note)
            path.write_text(text)
            with self.assertRaises(ValueError):
                publication.release_note_file(notes, "chromium-upstream-154", note)


class UpdateCommitTests(unittest.TestCase):
    def test_an_upstream_update_commits_its_entry_file_and_never_bumps_the_version(self):
        base_sha = "a" * 40
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            engine = repo / publication.ENGINE
            engine.mkdir(parents=True)
            (engine / "fork.json").write_text(json.dumps({
                "integrationBranch": "main", "automaticChannel": "development", "automaticMajorUpdates": False}))
            (engine / "source.lock.json").write_text(json.dumps({"chromium": {"version": "156.0.8078.80"}}))
            calls = []

            def run(*arguments, capture=False, cwd=None):
                calls.append(tuple(str(argument) for argument in arguments))
                if arguments[:3] == ("git", "diff", "--name-only"):
                    return f"{publication.ENGINE / 'source.lock.json'}\n"
                if arguments[:3] == ("git", "rev-parse", "HEAD"):
                    return base_sha
                if arguments[:3] == ("gh", "pr", "list"):
                    return "[]"
                if arguments[:3] == ("gh", "pr", "create"):
                    return "https://github.com/pauljoda/Crest/pull/1"
                if arguments[:2] == ("gh", "api"):
                    return json.dumps({"default_branch": "main"})
                return ""

            originals = (publication.REPO, publication.run, publication.chromium_engine.engine_key, sys.argv)
            publication.REPO = repo
            publication.run = run
            publication.chromium_engine.engine_key = lambda _: "0" * 64
            sys.argv = ["publish-chromium-update.py", "--source", "/src", "--ninja", "/ninja",
                        "--base-sha", base_sha, "--repository", "pauljoda/Crest"]
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    publication.main()
            finally:
                publication.REPO, publication.run, publication.chromium_engine.engine_key, sys.argv = originals

            entry = "chromium-upstream-156-0-8078-80-aaaaaaaaaaaa"
            note = json.loads((repo / "Documentation" / "ReleaseNotes" / f"{entry}.json").read_text())
            self.assertEqual(note["category"], "fixed")
            self.assertFalse(any("set-version.sh" in call[0] for call in calls))
            staged = next(call for call in calls if call[:2] == ("git", "add"))
            self.assertIn(f"Documentation/ReleaseNotes/{entry}.json", staged)
            self.assertNotIn("Config/Version.xcconfig", staged)
            self.assertNotIn("Documentation/ReleaseNotes.json", staged)
            checks = [call for call in calls if call[0].endswith("check-version.sh")]
            self.assertEqual(checks, [(str(repo / "Scripts/check-version.sh"), "--fix-commit")])
            self.assertLess(calls.index(staged), calls.index(checks[0]))


if __name__ == "__main__":
    unittest.main()
