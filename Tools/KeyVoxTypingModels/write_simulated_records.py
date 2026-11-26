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

Each sentence is typed by `TYPISTS` simulated typists. A line is the sentence's section, the
typed letters, the intended word, then up to three previous words of the sentence, newest first,
as `split_ite_events.py` writes ITE's; every typist's records of a sentence share its section, so
the rankers' split by sentence keeps them together."""

import argparse
import json
import random
from bisect import bisect
from itertools import accumulate
from pathlib import Path

from ite_records import completes
from letter_layout import LetterLayout
from never_corrected_words import never_corrected_words
from paths import DataPaths
from simulation_sentences import simulation_sentences
from typo_simulator import TypoSimulator
from words import valid_word

TYPISTS = 3
COMPLETIONS = 200_000
FEWEST_COMPLETIONS = 50
SEED = 20261124


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


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    paths = DataPaths(parser.parse_args().data_dir)
    measurements = json.loads(paths.typing_measurements.read_text(encoding="utf-8"))
    calibration = json.loads(paths.typo_calibration.read_text(encoding="utf-8"))
    layout = LetterLayout.for_language(measurements["language"])
    simulator = TypoSimulator(layout, measurements, calibration, SEED)
    rng = random.Random(SEED + 1)
    prefix_lengths = PrefixLengths(measurements["completion_prefix_lengths"])
    never_corrected = never_corrected_words(paths)

    sentences = list(simulation_sentences(paths.root))
    words = sum(len(sentence) for sentence in sentences) * TYPISTS
    completion_share = COMPLETIONS / words
    paths.simulation.mkdir(parents=True, exist_ok=True)
    written = dict.fromkeys(("corrections", "preserves", "completions"), 0)
    targets = {name: paths.simulated_records(name).open("w", encoding="utf-8")
               for name in written}

    def write(name, section, typed, intended, previous):
        targets[name].write("\t".join((section, typed, intended, *previous)) + "\n")
        written[name] += 1

    for index, sentence in enumerate(sentences):
        section = f"sim{index}"
        for _ in range(TYPISTS):
            for position, word in enumerate(sentence):
                previous = sentence[max(0, position - 3):position][::-1]
                typed = simulator.type_word(word)
                if typed != word:
                    write("corrections", section, typed, word, previous)
                elif word not in never_corrected:
                    write("preserves", section, typed, word, previous)
                if rng.random() < completion_share:
                    letters = typed[:prefix_lengths.draw(len(word), rng)]
                    if letters and valid_word(letters) and completes(letters, word):
                        write("completions", section, letters, word, previous)
    for target in targets.values():
        target.close()
    print(f"{len(sentences):,} sentences typed {TYPISTS} times, {words:,} words: "
          + ", ".join(f"{count:,} {name}" for name, count in written.items()))


if __name__ == "__main__":
    main()
