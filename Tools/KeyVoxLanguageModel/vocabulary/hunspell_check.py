"""Checks spellings against a Hunspell dictionary packaged as a LibreOffice extension (.oxt),
such as RLA-ES: `hunspell -G` prints the words the dictionary accepts. Needs the hunspell
command (Homebrew: `brew install hunspell`)."""

import subprocess
import tempfile
import zipfile
from pathlib import Path


def hunspell_accepted(words: set[str], extension: Path) -> set[str]:
    with tempfile.TemporaryDirectory() as directory, zipfile.ZipFile(extension) as archive:
        affix = next(name for name in archive.namelist() if name.endswith(".aff"))
        dictionary = affix.removesuffix(".aff") + ".dic"
        for name in (affix, dictionary):
            (Path(directory) / Path(name).name).write_bytes(archive.read(name))
        stem = Path(directory) / Path(affix).stem
        result = subprocess.run(
            ["hunspell", "-d", str(stem), "-i", "UTF-8", "-G"],
            input="".join(word + "\n" for word in sorted(words)),
            capture_output=True, text=True, encoding="utf-8", check=True,
        )
    return set(result.stdout.splitlines()) & words
