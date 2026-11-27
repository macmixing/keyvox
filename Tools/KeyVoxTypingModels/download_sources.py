"""Downloads every input of the English typing models into a data directory, skipping files
already present, and records each file's SHA-256 in `<data_dir>/sources/checksums.txt`.

Tatoeba's export and contribution log are only needed to rewind to the cutoff, so they are
skipped while the sentences as of the cutoff are there and match their recorded SHA-256.

Another language downloads nothing: its inputs are its language build, linked in as
`sources/language-build` (`language_build.py`), whose files are checked to be there and recorded."""

import argparse
import hashlib
import shutil
import urllib.request
from pathlib import Path

import language_build
import remote_zip
import tatoeba_snapshot
from paths import DataPaths
from sources import SOURCES, TATOEBA, tatoeba_path
from typing_languages import add_language_arguments, language_from


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


def language_build_files(data_dir: Path) -> list[Path]:
    """The language build's files the typing models read; exits naming any that is missing."""
    paths = DataPaths(data_dir)
    build = paths.language_build
    files = [build / "vocabulary.txt", build / "counts.npz", build / "built" / "vocabulary.txt",
             build / "built" / "common_vocabulary.txt", *language_build.sentence_paths(paths)]
    missing = [str(path.relative_to(build)) for path in files[:4] if not path.exists()]
    if len(files) == 4:
        missing.append("sentences/")
    if missing:
        raise SystemExit(f"{build}: link Tools/KeyVoxLanguageModel's build of the language here; "
                         f"missing {', '.join(missing)}")
    return files


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    add_language_arguments(parser)
    arguments = parser.parse_args()
    data_dir = arguments.data_dir.resolve()
    language = language_from(arguments)

    written = []
    if not language.uses_english_text:
        written = language_build_files(data_dir)
    for source in SOURCES if language.uses_english_text else ():
        if source is TATOEBA and tatoeba_snapshot.is_verified(data_dir):
            print(f"using the verified {tatoeba_path(data_dir).name}; Tatoeba is not downloaded")
            written.append(tatoeba_path(data_dir))
            continue
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
    checksums.parent.mkdir(parents=True, exist_ok=True)
    with checksums.open("w", encoding="utf-8") as output:
        for path in written:
            output.write(f"{sha256(path)}  {path.relative_to(data_dir)}\n")
    print(f"wrote {checksums}")


if __name__ == "__main__":
    main()
