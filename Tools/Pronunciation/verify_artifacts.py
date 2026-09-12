#!/usr/bin/env python3
"""Verify bundled pronunciation artifact and complete upstream-notice identity."""

import hashlib
import json
from pathlib import Path
import sys


def verify(root: Path) -> None:
    root = root.resolve()
    resources = root / "Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation"
    sources = json.loads((resources / "sources.lock.json").read_text())
    licenses = json.loads((resources / "licenses.lock.json").read_text())
    revisions = {source["id"]: source["revision"] for source in sources["sources"]}
    notices = licenses["notices"]
    if {notice["source_id"] for notice in notices} != set(revisions):
        raise ValueError("Every incorporated source must have a complete pinned notice")
    for notice in notices:
        if revisions[notice["source_id"]] not in notice["url"]:
            raise ValueError("Notice URL does not match its pinned source revision")
    for artifact in sources["artifacts"] + notices:
        path = (root / artifact["path"]).resolve()
        path.relative_to(root)
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != artifact["sha256"]:
            raise ValueError(f"SHA-256 mismatch: {artifact['path']}")
        if "rows" in artifact and len(data.splitlines()) != artifact["rows"]:
            raise ValueError(f"Row-count mismatch: {artifact['path']}")


if __name__ == "__main__":
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
    try:
        verify(root)
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(str(error))
    print("Pronunciation artifact and complete-notice hashes verified.")
