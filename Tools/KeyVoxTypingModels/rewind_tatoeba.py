"""Writes Tatoeba's English sentences as they were at the pinned cutoff to
`<data_dir>/work/tatoeba_eng_sentences_at_cutoff.tsv.bz2`, in the export's format.

Starts from the current English export and, for every sentence the contribution log touched
after the cutoff, puts back its state as of the cutoff: sentences added since are dropped,
edited ones get their earlier text, and deleted ones return. Sentences the log did not touch
after the cutoff stay exactly as exported, so older gaps in the log do not matter. Last, the
sentences `sources.py` lists as hidden or shown at the cutoff are taken out or put back."""

import argparse
import bz2
import re
import tarfile
from pathlib import Path

from sources import (
    TATOEBA_CUTOFF, TATOEBA_HIDDEN_AT_CUTOFF, TATOEBA_SHOWN_AT_CUTOFF,
    tatoeba_contributions_path, tatoeba_export_path, tatoeba_path,
)

# A log row is user, time, action, kind, sentence ID, language, translation ID, text; text
# that holds line breaks continues on the following lines.
ROW_START = re.compile(r"^[^\t]*\t\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\t(insert|update|delete)\t\w+\t")


def contribution_rows(path):
    with tarfile.open(path, "r|bz2") as archive:
        for member in archive:
            if not member.name.endswith("contributions.csv"):
                continue
            row = None
            for raw in archive.extractfile(member):
                line = raw.decode("utf-8", errors="replace").rstrip("\n")
                if ROW_START.match(line):
                    if row:
                        yield row
                    row = line.split("\t", 7)
                    row.extend([""] * (8 - len(row)))
                elif row is not None:
                    row[7] += "\n" + line
            if row:
                yield row
            return
    raise RuntimeError(f"{path}: contributions.csv not found")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir

    state_at_cutoff = {}
    touched_after = set()
    for _, when, action, kind, sentence, language, _, text in contribution_rows(
            tatoeba_contributions_path(data_dir)):
        if kind != "sentence":
            continue
        if when > TATOEBA_CUTOFF:
            touched_after.add(sentence)
        elif action == "delete":
            state_at_cutoff.pop(sentence, None)
        else:
            state_at_cutoff[sentence] = (language, text)

    sentences = {}
    with bz2.open(tatoeba_export_path(data_dir), "rt", encoding="utf-8") as source:
        for line in source:
            fields = line.rstrip("\n").split("\t")
            sentences[fields[0]] = fields[2] if len(fields) >= 3 else ""
    for sentence in touched_after:
        sentences.pop(sentence, None)
        language, text = state_at_cutoff.get(sentence, (None, None))
        if language == "eng":
            sentences[sentence] = text
    for sentence in TATOEBA_HIDDEN_AT_CUTOFF:
        if sentences.pop(sentence, None) is None:
            raise RuntimeError(f"sentence {sentence} listed as hidden is not in the sentences")
    for sentence in TATOEBA_SHOWN_AT_CUTOFF:
        language, text = state_at_cutoff.get(sentence, (None, None))
        if language != "eng" or sentence in sentences:
            raise RuntimeError(f"sentence {sentence} listed as shown is not a missing English one")
        sentences[sentence] = text

    output = tatoeba_path(data_dir)
    output.parent.mkdir(parents=True, exist_ok=True)
    with bz2.open(output, "wt", encoding="utf-8") as target:
        for sentence in sorted(sentences, key=int):
            target.write(f"{sentence}\teng\t{sentences[sentence]}\n")
    print(f"{output}: {len(sentences)} sentences as of {TATOEBA_CUTOFF} "
          f"({len(touched_after)} touched after it)")


if __name__ == "__main__":
    main()
