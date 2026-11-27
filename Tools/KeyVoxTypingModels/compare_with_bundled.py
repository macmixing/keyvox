"""Compares each file in `<data_dir>/built` with the one the package bundles in the language's
folder, `PredictiveData/<language>`, and exits with status 1 if any differ or the package does not
bundle the language.

A dictionary header holds the times it was written, so headers are compared without them."""

import argparse
import sys
from pathlib import Path

from letter_layout import PREDICTIVE_DATA
from paths import DataPaths
from typing_languages import add_language_arguments

# The header's attributes follow a 12-byte prefix (magic, version, flags, header size); each
# key and value ends with this byte.
HEADER_PREFIX = 12
ATTRIBUTE_END = b"\x1f"
WRITE_TIME_ATTRIBUTES = {b"date", b"LAST_DECAYED_TIME"}


def header_without_write_times(data):
    size = int.from_bytes(data[8:12], "big")
    fields = data[HEADER_PREFIX:size].split(ATTRIBUTE_END)
    attributes = dict(zip(fields[0::2], fields[1::2]))
    kept = {key: value for key, value in attributes.items() if key not in WRITE_TIME_ATTRIBUTES}
    return data[:8], kept, data[size:]


def same(built, bundled):
    if built.suffix == ".header":
        return header_without_write_times(built.read_bytes()) == header_without_write_times(
            bundled.read_bytes())
    return built.read_bytes() == bundled.read_bytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    add_language_arguments(parser)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)
    bundled_dir = PREDICTIVE_DATA / arguments.language
    if not (bundled_dir / "dictionary").is_dir():
        print(f"the package does not bundle {arguments.language}'s typing models")
        sys.exit(1)

    differ = False
    for built in paths.bundled_files:
        name = built.relative_to(paths.built)
        bundled = bundled_dir / name
        if not bundled.exists():
            print(f"{name}: not bundled")
            differ = True
        elif same(built, bundled):
            print(f"{name}: same as the bundled file")
        else:
            print(f"{name}: differs from the bundled file")
            differ = True
    sys.exit(1 if differ else 0)


if __name__ == "__main__":
    main()
