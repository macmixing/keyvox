"""Sets the typo simulator's spreads and rates so that its mistakes, measured as ITE typists'
were, match theirs, and writes them to `<data_dir>/work/simulation/typo_calibration.json`.

Two of `measure_ite_typing.py`'s measurements are matched. How often a word of each length is
typed with a mistake comes from the words typed with autocorrection off, the only ones that
show it. What a typo is made of, how often each kind of mistake is in one and how often it has
a second mistake, comes from the typos typists left for the logged keyboards to autocorrect,
the kind the correction ranker has to fix: typists who rely on autocorrection leave far more
slips of a finger than typists who fix their own mistakes.

Measuring a mistake is not the same as making it: a doubled letter can be counted at the letter
before the one doubled, mistakes in one word can be counted as other kinds, and a sloppy word's
wider taps land on the rows above and below more often than the row's neighbors. So the
simulator types every word the ITE typists copied with autocorrection off, its mistakes are
measured with `typo_kinds.py`, and each setting is moved by how far the measurement is from
ITE's, for `ROUNDS` rounds:
- each kind's rate by its share of the autocorrected typos, events per typo, over its share of
  the simulator's typos;
- each place's spreads refitted (`fit_touch_spread.py`) to rates of substitutions of the key
  beside in the row and of an overlapping key in the row above or below that are each moved
  the same way;
- each length's factor by the share of words of that length typed with a mistake with
  autocorrection off over the simulator's;
- the sloppiness shape by the simulator's share of mistyped words with a second mistake over
  the autocorrected typos', a smaller shape making second mistakes likelier.
The rounds start from the rates measured with autocorrection off, the fitted spreads and their
far substitutions, no length factors, and a shape of one. Every round types the words with the
same seed."""

import argparse
import json
from pathlib import Path

from fit_touch_spread import fit
from ite_copied_typing import copied_sentences
from letter_layout import LetterLayout
from paths import DataPaths
from typo_kinds import LONGEST_COUNTED_LENGTH, POSITIONS, TypoCounts
from typo_simulator import TypoSimulator

ROUNDS = 12
SEED = 7
TOUCH_KINDS = ("substitution_row", "substitution_adjacent_row")


def mistyped_shares(summary):
    """The share of words with a mistake by length, and the share of those with a second."""
    by_length = {}
    mistyped = second = 0
    for length, counts in summary["words_by_length"].items():
        total = sum(counts.values())
        by_length[int(length)] = (counts["1"] + counts["2"]) / total if total else 0.0
        mistyped += counts["1"] + counts["2"]
        second += counts["2"]
    return by_length, second / mistyped


def shares(summary):
    """Each kind's events per mistyped word."""
    mistyped = summary["words"]["mistyped"]
    return {kind: summary["events"].get(kind, 0) / mistyped for kind in summary["rates"]}


def ratio(target, value):
    return target / value if value > 0 else 1.0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    paths = DataPaths(parser.parse_args().data_dir)
    measurements = json.loads(paths.typing_measurements.read_text(encoding="utf-8"))
    spread = json.loads(paths.touch_spread.read_text(encoding="utf-8"))
    layout = LetterLayout.for_language(measurements["language"])
    measured = measurements["typos"]
    autocorrected = measurements["autocorrected_typos"]
    words = [word for _, intended, _ in copied_sentences(paths.root) for word in intended]
    target_by_length, _ = mistyped_shares(measured)
    _, target_second = mistyped_shares(autocorrected)
    target_shares = shares(autocorrected)

    rates = dict(measured["rates"])
    touch_targets = {}
    for position in POSITIONS:
        rates[f"substitution_far/{position}"] = spread["positions"][position]["far_substitution"]
        for kind in TOUCH_KINDS:
            touch_targets[f"{kind}/{position}"] = rates.pop(f"{kind}/{position}")
    calibration = {
        "rates": rates,
        "spreads": {position: {"across": spread["positions"][position]["across"],
                               "down": spread["positions"][position]["down"]}
                    for position in POSITIONS},
        "length_factors": {str(length): 1.0 for length in range(1, LONGEST_COUNTED_LENGTH + 1)},
        "sloppiness_shape": 1.0,
    }
    rounds = []
    for round_number in range(ROUNDS + 1):
        simulator = TypoSimulator(layout, measurements, calibration, SEED)
        counts = TypoCounts()
        for word in words:
            counts.add(word, simulator.type_word(word), layout)
        simulated = counts.summary()
        simulated_shares = shares(simulated)
        by_length, second = mistyped_shares(simulated)
        gaps = {kind: simulated_shares[kind] / value - 1.0
                for kind, value in target_shares.items()
                if autocorrected["events"].get(kind, 0) >= 200}
        largest = max(gaps, key=lambda kind: abs(gaps[kind]))
        rounds.append({"largest_kind_gap": [largest, gaps[largest]],
                       "second_mistake_share": second})
        print(f"round {round_number}: largest share gap of a kind seen 200 times {largest} "
              f"{gaps[largest]:+.3f}; second mistakes {second:.4f} (ITE {target_second:.4f})",
              flush=True)
        if round_number == ROUNDS:
            break

        for kind in rates:
            rates[kind] *= ratio(target_shares[kind], simulated_shares[kind])
        for kind in touch_targets:
            touch_targets[kind] *= ratio(target_shares[kind], simulated_shares[kind])
        for position in POSITIONS:
            across, down, _ = fit(layout, measurements["letters"][position],
                                  touch_targets[f"substitution_row/{position}"],
                                  touch_targets[f"substitution_adjacent_row/{position}"])
            calibration["spreads"][position] = {"across": across, "down": down}
        factors = calibration["length_factors"]
        for length in factors:
            factors[length] *= ratio(target_by_length[int(length)], by_length[int(length)])
        calibration["sloppiness_shape"] *= ratio(second, target_second)

    calibration["rounds"] = rounds
    paths.typo_calibration.write_text(json.dumps(calibration, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
