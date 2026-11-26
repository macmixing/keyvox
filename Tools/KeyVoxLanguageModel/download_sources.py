"""Downloads every source file a language's build reads into a data directory, skipping files
already present, and checks each file that has a pinned SHA-256. A file without a URL must
already be prepared, as the README's "Preparing the multilingual sources" describes."""

import argparse
import hashlib
import shutil
import urllib.request
from pathlib import Path

from languages import LANGUAGES, TreebankKinds, language_argument


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        for block in iter(lambda: file.read(1 << 22), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    language = LANGUAGES[arguments.language]

    sources = [use.source for use in language.sources]
    if language.vocabulary:
        sources += [language.vocabulary.word_list, *language.vocabulary.lexicons]
        if language.vocabulary.spelling_dictionary:
            sources.append(language.vocabulary.spelling_dictionary)
    if isinstance(language.word_kinds, TreebankKinds):
        sources.append(language.word_kinds.treebank)

    for source in sources:
        directory = arguments.data_dir / "sources" / source.name
        for file in source.files:
            destination = directory / file.name
            if not destination.exists():
                if file.url is None:
                    raise SystemExit(f"{destination} is missing: prepare it from {source.upstream} (see README)")
                destination.parent.mkdir(parents=True, exist_ok=True)
                partial = destination.with_suffix(destination.suffix + ".part")
                print(f"downloading {source.name}/{file.name}", flush=True)
                with urllib.request.urlopen(file.url) as response, open(partial, "wb") as output:
                    shutil.copyfileobj(response, output, length=1 << 20)
                partial.rename(destination)
            if file.sha256 and sha256(destination) != file.sha256:
                raise SystemExit(f"{destination} does not match its pinned SHA-256")


if __name__ == "__main__":
    main()
