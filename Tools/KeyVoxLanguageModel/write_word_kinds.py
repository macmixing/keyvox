"""Writes `<data_dir>/word_kinds.tsv`, each word's most common lexical class, the way the
language's `word_kinds` says: Apple's tagger (tag_word_kinds.swift) over the language's written
sentences from extract_sentences.py, or a treebank (write_treebank_word_kinds.py)."""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

from languages import LANGUAGES, AppleTaggerKinds, language_argument
from readers import source_paths

TOOLS = Path(__file__).resolve().parent


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    kinds = LANGUAGES[arguments.language].word_kinds
    output = arguments.data_dir / "word_kinds.tsv"

    if isinstance(kinds, AppleTaggerKinds):
        with tempfile.TemporaryDirectory() as scratch:
            tagger = Path(scratch) / "tag_word_kinds"
            subprocess.run(["xcrun", "swiftc", "-O", str(TOOLS / "tag_word_kinds.swift"), "-o", str(tagger)], check=True)
            language = ["--language", kinds.tagger_language] if kinds.tagger_language else []
            if kinds.elided_host:
                language.append("--elided-host")
            sentences = [str(arguments.data_dir / "sentences" / f"{name}.txt") for name in kinds.sentences]
            subprocess.run([str(tagger), *language, str(output), *sentences], check=True)
    else:
        treebank = [str(path) for path in source_paths(arguments.data_dir, kinds.treebank)]
        subprocess.run([sys.executable, str(TOOLS / "write_treebank_word_kinds.py"), str(output), *treebank], check=True)


if __name__ == "__main__":
    main()
