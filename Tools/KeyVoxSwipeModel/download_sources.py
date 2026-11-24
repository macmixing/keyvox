"""Downloads every source file into a data directory, skipping files already present, and
writes each file's size, SHA-256, and line count to `sources/manifest.json`."""

import argparse
import hashlib
import json
import shutil
import urllib.request
from pathlib import Path

from sources import SOURCES


def _describe(path: Path) -> dict:
    digest = hashlib.sha256()
    lines = 0
    with open(path, "rb") as file:
        for block in iter(lambda: file.read(1 << 20), b""):
            digest.update(block)
            lines += block.count(b"\n")
    entry = {"bytes": path.stat().st_size, "sha256": digest.hexdigest()}
    if path.suffix == ".jsonl":
        entry["rows"] = lines
    return entry


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()

    manifest = {}
    for source in SOURCES:
        directory = arguments.data_dir / "sources" / source.name
        files = {}
        for file in source.files:
            destination = directory / file.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists():
                partial = destination.with_suffix(destination.suffix + ".part")
                print(f"downloading {source.name}/{file.name}", flush=True)
                with urllib.request.urlopen(file.url) as response, open(partial, "wb") as output:
                    shutil.copyfileobj(response, output, length=1 << 20)
                partial.rename(destination)
            files[file.name] = {"url": file.url, **_describe(destination)}
        manifest[source.name] = {
            "license": source.license,
            "license_url": source.license_url,
            "attribution": source.attribution,
            "files": files,
        }

    output = arguments.data_dir / "sources" / "manifest.json"
    output.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {output}")


if __name__ == "__main__":
    main()
