#!/usr/bin/env python3
"""Writes the web endings Apple's iOS keyboard offers in each locale, from its own keyboard files:
every `TextInput_<language>.bundle/Keyboard-<locale>.plist` in an iOS simulator runtime's
`System/Library/TextInput` that has a `UI-TopLevelDomain` entry, its `Strings` in their stored
order, by locale identifier, and how many of the region's endings Apple's keyboard places to the
right of the key's own (`ENDINGS_RIGHT_OF_KEY`), measured on the iOS 27.2 simulator in
`~/KeyVoxLanguageData/apple-languages/runs/sim-weburl-*` (summary: `sim-weburl-summary.md`). The
predictive keyboard reads the file as `PredictiveData/web_endings.json` (`WebEndings`).

    python3 write_web_endings.py "<runtime>/System/Library/TextInput" \
        ../../Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/web_endings.json
"""

import argparse
import json
import pathlib
import plistlib

KEY = "UI-TopLevelDomain"
PREFIX = "Keyboard-"
# Two on the right of the key's own ending whatever the list's length: en_US's five endings, and
# en_GB's seven, of which the sixth and seventh went left.
ENDINGS_RIGHT_OF_KEY = 2


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("text_input", type=pathlib.Path, help="the runtime's System/Library/TextInput")
    parser.add_argument("output", type=pathlib.Path)
    arguments = parser.parse_args()
    endings = {}
    for path in sorted(arguments.text_input.glob(f"TextInput_*.bundle/{PREFIX}*.plist")):
        with open(path, "rb") as file:
            entry = plistlib.load(file).get(KEY)
        if not entry or not entry.get("Strings"):
            continue
        locale = path.stem[len(PREFIX):]
        endings[locale] = entry["Strings"].split()
    file = {"endingsRightOfKey": ENDINGS_RIGHT_OF_KEY, "locales": endings}
    arguments.output.write_text(json.dumps(file, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{arguments.output}: {len(endings)} locales")


if __name__ == "__main__":
    main()
