#!/usr/bin/env python3
"""Writes the character lists the iOS keyboard uses to delete a selection as a field that deletes
smartly does (KeyboardSmartDeletion), from SmartDeleteCharacterProbe's captures.

Each list holds one hexadecimal scalar or range of them per line. The script stops if a capture
shows the field removing anything but a plain space, or removing the space after a word that has a
space on both sides, since KeyboardSmartDeletion relies on neither happening.

    python3 write_smart_delete_characters.py --output "../../iOS/KeyVox Keyboard/Core/Input" \
        ~/KeyVoxLanguageData/apple-smart-delete/*.json
"""

import argparse
import json
import pathlib
import sys

SPACE = 0x20


def ranges(scalars):
    lines = []
    start = previous = None
    for scalar in sorted(scalars):
        if previous is not None and scalar == previous + 1:
            previous = scalar
            continue
        if start is not None:
            lines.append(line(start, previous))
        start = previous = scalar
    if start is not None:
        lines.append(line(start, previous))
    return lines


def line(start, end):
    return f"{start:04X}" if start == end else f"{start:04X}-{end:04X}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("captures", nargs="+", type=pathlib.Path)
    arguments = parser.parse_args()

    before_word = set()
    after_word = set()
    for capture in arguments.captures:
        content = json.loads(capture.read_text())
        if content["cursorAfterDeletingWordBetweenSpaces"] != 3:
            sys.exit(f"{capture}: the field kept the space before a word between two spaces")
        for record in content["records"]:
            scalar = record["scalar"]
            removed = record["isRemovedAfterWord"] or record["isRemovedBeforeWord"]
            if removed and scalar != SPACE:
                sys.exit(f"{capture}: the field removed {scalar:04X}, which is not a plain space")
            if record["removesSpaceAfterWordWhenBefore"]:
                before_word.add(scalar)
            if record["removesSpaceBeforeWordWhenAfter"]:
                after_word.add(scalar)

    for name, scalars in [
        ("smart_delete_before_word_characters", before_word),
        ("smart_delete_after_word_characters", after_word),
    ]:
        lines = ranges(scalars)
        (arguments.output / f"{name}.txt").write_text("\n".join(lines) + "\n")
        print(f"{name}: {len(scalars)} characters in {len(lines)} lines")


if __name__ == "__main__":
    main()
