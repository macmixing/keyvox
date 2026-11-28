"""Types the simulation sentences (`simulation_sentences.py`) with the typo simulator and writes
the records the rankers and the action model train on, in `<data_dir>/work/simulation/`:

- `corrections.tsv`: every word typed differently from the word meant;
- `preserves.tsv`: every word typed as meant that the action model could replace, one that no
  dictionary or SCOWL size-50 word spells (`never_corrected_words.py`);
- `completions.tsv`: about `COMPLETIONS` words, picked at random, typed partway: as many letters
  as ITE typists had typed when they picked a completion for a word of that length, drawn from
  how often they had typed each number, and kept when those letters complete the word as ITE's
  completions are kept (`ite_records.completes`). A length fewer than `FEWEST_COMPLETIONS` ITE
  completions had takes the counts of the longest length below it that had that many.

Each sentence is typed by `TYPISTS` simulated typists, each word drawn by the simulator from the
stream of the sentence, the typist, and the word's place in the sentence. A line is the sentence's
section, the typed letters, the intended word, then up to three previous words of the sentence,
newest first, as `split_ite_events.py` writes ITE's; every typist's records of a sentence share its
section, so the rankers' split by sentence keeps them together. `typed_words.json` counts, by bucket
(`training_sets.py`), the words typed, how many were mistyped, and how many of those were typed
as another word the action model never replaces.

The simulator types on the language's default letter layout (`--language`). Its measurements and
calibration, `ite_typing.json` and `typo_calibration.json`, are read from `--calibration`, by
default the data directory's own `work/simulation`: for another language than English, an English
data directory's `work/simulation` after the steps that measure and calibrate it on ITE's typing.
Typists' fingers are the same in every language, so its touch spreads, rates, and sloppiness carry
over; what differs is measured for the language: how often each letter is meant at each place in a
word, from its simulation sentences, and how often a letter without a key is typed plain
(`accent_typing.json`, from `measure_accent_typing.py`)."""

import argparse
import json
import random
from bisect import bisect
from collections import Counter
from itertools import accumulate
from pathlib import Path

from ite_records import completes, stable_bucket
from letter_layout import LetterLayout
from never_corrected_words import never_corrected_words
from paths import DataPaths
from simulation_sentences import section as sentence_section, simulation_sentences
from typing_languages import add_language_arguments, language_from
from typo_kinds import POSITIONS, position_of
from typo_simulator import TypoSimulator

TYPISTS = 3
COMPLETIONS = 200_000
FEWEST_COMPLETIONS = 50
SEED = 20261124
BUCKETS = 10


class PrefixLengths:
    """Draws how many letters of a word to type before picking its completion."""

    def __init__(self, counts_by_length):
        self.tables = {}
        for length, counts in sorted(counts_by_length.items(), key=lambda item: int(item[0])):
            if sum(counts.values()) >= FEWEST_COMPLETIONS:
                typed = sorted(int(count) for count in counts)
                self.tables[int(length)] = (typed, list(accumulate(counts[str(count)]
                                                                   for count in typed)))
        self.lengths = sorted(self.tables)

    def draw(self, length, rng):
        usable = self.lengths[max(0, bisect(self.lengths, length) - 1)]
        typed, totals = self.tables[usable]
        return typed[bisect(totals, rng.random() * totals[-1])]


def meant_letters(sentences, layout, accents):
    """How often each letter key is meant at each place in a word of the sentences, a letter
    without a key counted at the key that types it."""
    counts = {position: Counter() for position in POSITIONS}
    for sentence in sentences:
        for word in sentence:
            plain = word.replace("'", "")
            for index, letter in enumerate(plain):
                key = letter if letter in layout.keys else accents.get(letter, {}).get("key")
                if key in layout.keys:
                    counts[position_of(index, len(plain))][key] += 1
    return {position: dict(sorted(by_letter.items())) for position, by_letter in counts.items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("--calibration", type=Path,
                        help="the directory of ite_typing.json and typo_calibration.json "
                             "(default: <data_dir>/work/simulation)")
    add_language_arguments(parser)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)
    language = language_from(arguments)
    calibration_dir = arguments.calibration or paths.simulation
    measurements = json.loads((calibration_dir / paths.typing_measurements.name).read_text(
        encoding="utf-8"))
    calibration = json.loads((calibration_dir / paths.typo_calibration.name).read_text(
        encoding="utf-8"))
    measured_layout = LetterLayout.for_language(measurements["language"])
    sentences = list(simulation_sentences(paths, language))
    if language.identifier == measurements["language"]:
        layout, letters, accents = measured_layout, None, None
    else:
        layout = LetterLayout(language.letter_rows())
        accents = json.loads(paths.accent_typing.read_text(encoding="utf-8"))["letters"]
        letters = meant_letters(sentences, layout, accents)
    simulator = TypoSimulator(layout, measurements, calibration, SEED, letters=letters,
                              accents=accents, measured_layout=measured_layout)
    rng = random.Random(SEED + 1)
    prefix_lengths = PrefixLengths(measurements["completion_prefix_lengths"])
    never_corrected = never_corrected_words(paths, language)

    words = sum(len(sentence) for sentence in sentences) * TYPISTS
    completion_share = COMPLETIONS / words
    paths.simulation.mkdir(parents=True, exist_ok=True)
    written = dict.fromkeys(("corrections", "preserves", "completions"), 0)
    targets = {name: paths.simulated_records(name).open("w", encoding="utf-8")
               for name in written}

    def write(name, section, typed, intended, previous):
        targets[name].write("\t".join((section, typed, intended, *previous)) + "\n")
        written[name] += 1

    typed_words = {bucket: Counter() for bucket in range(BUCKETS)}
    for index, sentence in enumerate(sentences):
        section = sentence_section(index)
        counted = typed_words[stable_bucket(section)]
        joined = " ".join(sentence)
        for typist in range(TYPISTS):
            for position, word in enumerate(sentence):
                previous = sentence[max(0, position - 3):position][::-1]
                typed = simulator.type_word(word, f"{joined}\t{typist}\t{position}")
                counted["words"] += 1
                if typed != word:
                    counted["mistyped"] += 1
                    counted["mistyped_as_a_word"] += typed in never_corrected
                    write("corrections", section, typed, word, previous)
                elif word not in never_corrected:
                    write("preserves", section, typed, word, previous)
                if rng.random() < completion_share:
                    letters = typed[:prefix_lengths.draw(len(word), rng)]
                    if letters and language.valid_word(letters) and completes(letters, word):
                        write("completions", section, letters, word, previous)
    for target in targets.values():
        target.close()
    paths.simulated_typed_words.write_text(json.dumps({"buckets": {
        str(bucket): {name: counts[name] for name in ("words", "mistyped", "mistyped_as_a_word")}
        for bucket, counts in typed_words.items()}}, indent=2), encoding="utf-8")
    print(f"{len(sentences):,} sentences typed {TYPISTS} times, {words:,} words: "
          + ", ".join(f"{count:,} {name}" for name, count in written.items()))


if __name__ == "__main__":
    main()
