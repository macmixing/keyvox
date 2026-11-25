"""Checks the Tatoeba English sentences as of the cutoff against the SHA-256 that `sources.py`
records for them, over their uncompressed text, so a change in Tatoeba can never change the
built files without being noticed."""

import bz2
import hashlib

from sources import TATOEBA_SNAPSHOT_SHA256, tatoeba_path


def text_sha256(path):
    digest = hashlib.sha256()
    with bz2.open(path, "rb") as source:
        for block in iter(lambda: source.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def is_verified(data_dir):
    """Whether the snapshot is in the data directory and matches the recorded SHA-256."""
    path = tatoeba_path(data_dir)
    return path.exists() and text_sha256(path) == TATOEBA_SNAPSHOT_SHA256
