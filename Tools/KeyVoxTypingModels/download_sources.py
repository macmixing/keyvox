"""Downloads every input of the typing models into a data directory, skipping files already
present, and records each file's SHA-256 in `<data_dir>/sources/checksums.txt`."""

import argparse
import hashlib
import shutil
import urllib.request
from pathlib import Path

import remote_zip
from sources import SOURCES


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def download(url: str, destination: Path) -> None:
    partial = destination.with_suffix(destination.suffix + ".part")
    print(f"downloading {destination.name}", flush=True)
    with urllib.request.urlopen(url) as response, partial.open("wb") as output:
        shutil.copyfileobj(response, output, length=1 << 20)
    partial.rename(destination)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir.resolve()

    written = []
    for source in SOURCES:
        for file in source.files:
            destination = data_dir / file.path
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists():
                download(file.url, destination)
            written.append(destination)
        missing = [entry for entry in source.members if not (data_dir / entry.path).exists()]
        if missing:
            members = remote_zip.catalog(source.archive_url, source.archive_size)
            for entry in missing:
                destination = data_dir / entry.path
                destination.parent.mkdir(parents=True, exist_ok=True)
                print(f"reading {entry.member} from {source.name}", flush=True)
                partial = destination.with_suffix(destination.suffix + ".part")
                partial.write_bytes(remote_zip.read_member(source.archive_url,
                                                           members[entry.member]))
                partial.rename(destination)
        written.extend(data_dir / entry.path for entry in source.members)

    checksums = data_dir / "sources" / "checksums.txt"
    with checksums.open("w", encoding="utf-8") as output:
        for path in written:
            output.write(f"{sha256(path)}  {path.relative_to(data_dir)}\n")
    print(f"wrote {checksums}")


if __name__ == "__main__":
    main()
