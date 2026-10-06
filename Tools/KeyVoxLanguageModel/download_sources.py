"""Downloads every source file into a data directory, skipping files already present."""

import argparse
import shutil
import urllib.request
from pathlib import Path

from sources import SOURCES


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()

    for source in SOURCES:
        directory = arguments.data_dir / "sources" / source.name
        directory.mkdir(parents=True, exist_ok=True)
        for file in source.files:
            destination = directory / file.name
            if destination.exists():
                continue
            partial = destination.with_suffix(destination.suffix + ".part")
            print(f"downloading {source.name}/{file.name}", flush=True)
            with urllib.request.urlopen(file.url) as response, open(partial, "wb") as output:
                shutil.copyfileobj(response, output, length=1 << 20)
            partial.rename(destination)


if __name__ == "__main__":
    main()
