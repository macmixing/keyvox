"""Keeps a Hunspell check reproducible: which words the installed hunspell accepts can change with
its version, so the words a language's pinned dictionary accepted are kept as a snapshot,
`<data_dir>/sources/spelling-snapshots/<identifier>_hunspell_accepted.txt`, one word per line in
code-point order, with its SHA-256 and the hunspell version that made it recorded in languages.py.

The snapshot is read when it is there, after checking its hash. Without it, hunspell runs afresh,
and the build fails unless the words it accepts hash to the recorded snapshot's."""

import hashlib
from collections.abc import Callable
from pathlib import Path


def _listing(words: set[str]) -> bytes:
    return "".join(word + "\n" for word in sorted(words)).encode("utf-8")


def snapshot_accepted(words: set[str], snapshot: Path, recorded_sha256: str, recorded_version: str,
                      installed_version: Callable[[], str],
                      accepted: Callable[[set[str]], set[str]]) -> set[str]:
    if snapshot.exists():
        listing = snapshot.read_bytes()
        if hashlib.sha256(listing).hexdigest() != recorded_sha256:
            raise SystemExit(f"{snapshot} does not match its recorded SHA-256 in languages.py")
        return set(listing.decode("utf-8").splitlines()) & words
    fresh = accepted(words)
    if hashlib.sha256(_listing(fresh)).hexdigest() != recorded_sha256:
        raise SystemExit(
            f"{snapshot} is missing, and hunspell {installed_version()} accepts other words than the "
            f"recorded snapshot, made with hunspell {recorded_version}; restore the snapshot rather "
            "than build with these words"
        )
    return fresh


def write_snapshot(words: set[str], snapshot: Path) -> str:
    """Writes the accepted words as a snapshot and returns its SHA-256, to record."""
    listing = _listing(words)
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_bytes(listing)
    return hashlib.sha256(listing).hexdigest()
