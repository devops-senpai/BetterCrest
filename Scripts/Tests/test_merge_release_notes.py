#!/usr/bin/env python3
"""Contract coverage for the three-way merge of the release-note catalog."""

from __future__ import annotations

import json
import pathlib
import subprocess
import tempfile
import unittest


REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[2]
MERGE_SCRIPT = REPOSITORY_ROOT / "Scripts" / "merge-release-notes.py"


def catalog(baselines: dict, entries: dict) -> dict:
    return {"schemaVersion": 2, "publicationBaselines": baselines, "entries": entries}


def entry(message: str, category: str = "fixed") -> dict:
    return {"category": category, "message": message}


class MergeReleaseNotesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.directory = pathlib.Path(self.temporary_directory.name)
        self.baselines = {"stable": "first", "development": "first", "nightly": "first"}
        self.base = catalog(self.baselines, {"first": entry("The first change.", "internal")})

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def merge(self, ours: dict, theirs: dict) -> subprocess.CompletedProcess[str]:
        for name, document in (("base", self.base), ("ours", ours), ("theirs", theirs)):
            (self.directory / f"{name}.json").write_text(json.dumps(document, indent=2) + "\n")
        return subprocess.run(
            ["python3", str(MERGE_SCRIPT), *(str(self.directory / f"{name}.json") for name in ("base", "ours", "theirs"))],
            check=False, capture_output=True, text=True,
        )

    def merged(self) -> dict:
        return json.loads((self.directory / "ours.json").read_text())

    def test_our_entries_come_first_then_the_ones_only_upstream_added(self) -> None:
        ours = catalog(self.baselines, {**self.base["entries"], "fork-fix": entry("Our fix.")})
        theirs = catalog(
            {**self.baselines, "stable": "upstream-one"},
            {**self.base["entries"], "upstream-one": entry("Their first."), "upstream-two": entry("Their second.")},
        )
        result = self.merge(ours, theirs)
        self.assertEqual(result.returncode, 0, result.stderr)
        merged = self.merged()
        self.assertEqual(list(merged["entries"]), ["first", "fork-fix", "upstream-one", "upstream-two"])
        self.assertEqual(merged["publicationBaselines"]["stable"], "upstream-one")

    def test_the_same_entry_changed_on_both_sides_is_refused(self) -> None:
        ours = catalog(self.baselines, {"first": entry("Our wording.", "internal")})
        theirs = catalog(self.baselines, {"first": entry("Their wording.", "internal")})
        result = self.merge(ours, theirs)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("first", result.stderr)

    def test_a_removed_entry_is_refused(self) -> None:
        ours = catalog(self.baselines, {})
        theirs = catalog(self.baselines, {**self.base["entries"], "upstream-one": entry("Their first.")})
        result = self.merge(ours, theirs)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("removed", result.stderr)


if __name__ == "__main__":
    unittest.main()
