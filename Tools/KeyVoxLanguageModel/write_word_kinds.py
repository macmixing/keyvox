"""Writes `<data_dir>/word_kinds.tsv`, each word's most common lexical class, the way the
language's `word_kinds` says: Apple's tagger (tag_word_kinds.swift) over the language's written
sentences from extract_sentences.py, or a treebank (write_treebank_word_kinds.py).

Apple's tagger can answer differently on another system, so a language with a recorded snapshot
(`AppleTaggerKinds.snapshot_sha256`) takes its word kinds from the snapshot in
`<data_dir>/sources/word-kinds`, after checking it against the hash. Without the snapshot, the
sentences are tagged afresh, and the build fails if the result differs from the recorded hash."""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from download_sources import sha256
from languages import LANGUAGES, AppleTaggerKinds, language_argument
from readers import source_paths

TOOLS = Path(__file__).resolve().parent


def tag(kinds: AppleTaggerKinds, data_dir: Path, output: Path) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        tagger = Path(scratch) / "tag_word_kinds"
        subprocess.run(["xcrun", "swiftc", "-O", str(TOOLS / "tag_word_kinds.swift"), "-o", str(tagger)], check=True)
        language = ["--language", kinds.tagger_language] if kinds.tagger_language else []
        if kinds.elided_host:
            language.append("--elided-host")
        sentences = [str(data_dir / "sentences" / f"{name}.txt") for name in kinds.sentences]
        subprocess.run([str(tagger), *language, str(output), *sentences], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    language = LANGUAGES[arguments.language]
    kinds = language.word_kinds
    output = arguments.data_dir / "word_kinds.tsv"

    if not isinstance(kinds, AppleTaggerKinds):
        treebank = [str(path) for path in source_paths(arguments.data_dir, kinds.treebank)]
        subprocess.run([sys.executable, str(TOOLS / "write_treebank_word_kinds.py"), str(output), *treebank], check=True)
        return
    if kinds.snapshot_sha256 is None:
        tag(kinds, arguments.data_dir, output)
        return

    snapshot = arguments.data_dir / "sources" / "word-kinds" / f"{language.identifier}_word_kinds.tsv"
    if snapshot.exists():
        if sha256(snapshot) != kinds.snapshot_sha256:
            raise SystemExit(f"{snapshot} does not match its recorded SHA-256 in languages.py")
        shutil.copyfile(snapshot, output)
        print(f"{output}: from the recorded snapshot {snapshot}")
        return
    tag(kinds, arguments.data_dir, output)
    if sha256(output) != kinds.snapshot_sha256:
        raise SystemExit(
            f"{snapshot} is missing, and this system's tagger labels words differently from the "
            "recorded snapshot; restore the snapshot rather than build with these word kinds"
        )
    print(f"{output}: tagged afresh, matching the recorded snapshot")


if __name__ == "__main__":
    main()
