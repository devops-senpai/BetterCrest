#!/usr/bin/env python3
"""Merge two versions of Documentation/ReleaseNotes.json three ways.

The catalog is append-only: each side may add entries at the end and may never
change or remove one. The result keeps our entries in our order, then adds the
entries only upstream added, in upstream's order. Every other key, such as the
per-channel publication baselines, takes whichever side changed it, upstream
winning when both did, because upstream owns publication.

    merge-release-notes.py <base> <ours> <theirs> [--output <path>]

Without --output the result replaces <ours>, which is what a Git merge driver
(`%O %A %B`) expects. Exit status 0 means a clean merge; 1 means the two sides
changed the same entry or one removed an entry, which a person must settle.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import release_note_catalog  # noqa: E402

ENTRIES = "entries"


class MergeConflict(Exception):
    """The two sides disagree about an entry."""


def load(path: pathlib.Path) -> dict:
    return json.loads(path.read_text(), object_pairs_hook=release_note_catalog.unique_json_object)


def merge_entries(base: dict, ours: dict, theirs: dict) -> dict:
    for side_name, side in (("ours", ours), ("theirs", theirs)):
        removed = [identifier for identifier in base if identifier not in side]
        if removed:
            raise MergeConflict(f"{side_name} removed release-note entries: {', '.join(removed)}")
    merged = dict(ours)
    for identifier, entry in theirs.items():
        if identifier not in merged:
            merged[identifier] = entry
            continue
        if entry == merged[identifier]:
            continue
        if identifier in base and merged[identifier] == base[identifier]:
            merged[identifier] = entry
        elif identifier in base and entry == base[identifier]:
            continue
        else:
            raise MergeConflict(f"both sides changed release-note entry {identifier}")
    return merged


def merge_documents(base: dict, ours: dict, theirs: dict) -> dict:
    merged: dict = {}
    for key in list(theirs) + [key for key in ours if key not in theirs]:
        if key == ENTRIES:
            merged[key] = merge_entries(base.get(key, {}), ours.get(key, {}), theirs.get(key, {}))
        elif theirs.get(key) != base.get(key):
            merged[key] = theirs[key]
        else:
            merged[key] = ours.get(key, base.get(key))
    return merged


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("base", type=pathlib.Path)
    parser.add_argument("ours", type=pathlib.Path)
    parser.add_argument("theirs", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, help="where to write the result (default: over <ours>)")
    arguments = parser.parse_args()
    try:
        merged = merge_documents(load(arguments.base), load(arguments.ours), load(arguments.theirs))
        document = json.dumps(merged, indent=2, ensure_ascii=False) + "\n"
        release_note_catalog.parse_catalog_document(document, "merged release notes")
    except (MergeConflict, release_note_catalog.CatalogValidationError, json.JSONDecodeError, ValueError) as error:
        print(f"merge-release-notes: {error}", file=sys.stderr)
        return 1
    (arguments.output or arguments.ours).write_text(document)
    return 0


if __name__ == "__main__":
    sys.exit(main())
