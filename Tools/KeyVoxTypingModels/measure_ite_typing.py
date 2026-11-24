"""Measures, from ITE phone typists the harness never scores on, what the typo simulator
reproduces, and writes it to `<data_dir>/work/simulation/ite_typing.json`:

- how often each kind of typing mistake happened per chance (`typo_kinds.py`), over the words
  typed with autocorrection and suggestions off (`ite_copied_typing.py`), and how often each
  letter was meant there at each place in a word, which the touch spread is fitted over;
- the same for the typos typists left for the logged keyboards to autocorrect, the ones the
  correction ranker learns from (`ite_records.plausible_corrections` of every typist's
  autocorrections, right and wrong): what kinds of mistakes a typo the keyboard must fix is
  made of, without how often words are typed with one, which these records cannot tell;
- how many letters typists had typed when they picked a suggested completion, by the length of
  the word they picked."""

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

from ite_copied_typing import copied_sentences, is_tuning_typist, section_participants
from ite_records import completion_records, plausible_corrections, read_records
from letter_layout import LetterLayout
from paths import DataPaths
from typo_kinds import TypoCounts, position_of

LANGUAGE = "en"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir
    paths = DataPaths(data_dir)
    layout = LetterLayout.for_language(LANGUAGE)

    counts = TypoCounts()
    letters = defaultdict(Counter)
    typists = set()
    sections = 0
    for participant, intended, typed in copied_sentences(data_dir):
        sections += 1
        typists.add(participant)
        for intended_word, typed_word in zip(intended, typed):
            counts.add(intended_word, typed_word, layout)
            plain = intended_word.replace("'", "")
            for index, letter in enumerate(plain):
                if letter in layout.keys:
                    letters[position_of(index, len(plain))][letter] += 1

    participants = section_participants(data_dir)
    autocorrected = TypoCounts()
    for name, harm in (("ac_success_calibration", False), ("ac_success_holdout", False),
                       ("ac_harm_holdout", True)):
        for record in plausible_corrections(read_records(paths.ite_split(name), harm=harm)):
            participant = participants.get(record["participant"])
            if participant is not None and is_tuning_typist(participant):
                autocorrected.add(record["expected"], record["typed"], layout)

    prefixes = defaultdict(Counter)
    for record in completion_records(data_dir):
        participant = participants.get(record["participant"])
        if participant is None or not is_tuning_typist(participant):
            continue
        prefixes[len(record["expected"])][len(record["typed"])] += 1

    measurements = {
        "language": LANGUAGE,
        "sections": sections,
        "typists": len(typists),
        "typos": counts.summary(),
        "autocorrected_typos": autocorrected.summary(),
        "letters": {position: dict(sorted(by_letter.items()))
                    for position, by_letter in sorted(letters.items())},
        "completion_prefix_lengths": {
            str(length): {str(typed): count for typed, count in sorted(prefixes[length].items())}
            for length in sorted(prefixes)
        },
    }
    paths.typing_measurements.parent.mkdir(parents=True, exist_ok=True)
    paths.typing_measurements.write_text(json.dumps(measurements, indent=2), encoding="utf-8")
    words = counts.words
    print(f"{sections:,} sections from {len(typists):,} typists: {words['counted']:,} words "
          f"measured, {words['replaced']:,} typed as a different word; "
          f"{autocorrected.words['counted']:,} autocorrected typos; "
          f"{sum(sum(row.values()) for row in prefixes.values()):,} completions")


if __name__ == "__main__":
    main()
