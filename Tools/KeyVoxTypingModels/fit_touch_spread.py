"""Fits the typo simulator's touch spreads to the mistakes ITE typists made, and writes them to
`<data_dir>/work/simulation/touch_spread.json`.

For each place in a word, first, middle, and last, it finds the spreads across and down, in key
pitches, at which a tap lands on the key beside the intended one in its row, and on an
overlapping key in the row above or below, exactly as often as `measure_ite_typing.py` measured,
over the letters typists meant there. Fowler et al.'s spreads, about 0.32 and 0.20 key pitches,
describe taps before any fix; the mistakes typists left in their text are far fewer, so these
spreads are narrower.

A tap rarely lands on a farther key. The measured rate of farther substitutions beyond what the
spreads give is written as `far_substitution`, which the simulator adds as its own kind."""

import argparse
import json
import math
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

from letter_layout import LetterLayout
from paths import DataPaths
from touch_spread import TouchSpread
from typo_kinds import POSITIONS

RELATIONS = ("row", "adjacent_row", "far")


def landing_rates(layout, letter_counts, across, down):
    """How often a tap lands on a key of each relation to the intended one, over the letters."""
    spread = TouchSpread(layout, across, down)
    total = sum(letter_counts.values())
    rates = dict.fromkeys(RELATIONS, 0.0)
    for letter, count in letter_counts.items():
        for other, probability in spread.hit_probabilities(letter).items():
            if other != letter:
                rates[layout.relation(letter, other)] += probability * count / total
    return rates


def fit(layout, letter_counts, row_rate, adjacent_row_rate):
    def residuals(log_spreads):
        across, down = np.exp(log_spreads)
        rates = landing_rates(layout, letter_counts, across, down)
        return [math.log(rates["row"] / row_rate),
                math.log(rates["adjacent_row"] / adjacent_row_rate)]

    solution = least_squares(residuals, x0=np.log([0.2, 0.15]), xtol=1e-12, ftol=1e-12)
    across, down = (float(value) for value in np.exp(solution.x))
    return across, down, landing_rates(layout, letter_counts, across, down)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    paths = DataPaths(parser.parse_args().data_dir)
    measurements = json.loads(paths.typing_measurements.read_text(encoding="utf-8"))
    layout = LetterLayout.for_language(measurements["language"])
    rates = measurements["typos"]["rates"]

    spreads = {}
    for position in POSITIONS:
        measured = {relation: rates[f"substitution_{relation}/{position}"]
                    for relation in RELATIONS}
        across, down, fitted = fit(layout, measurements["letters"][position],
                                   measured["row"], measured["adjacent_row"])
        spreads[position] = {
            "across": across, "down": down,
            "measured": measured, "from_spread": fitted,
            "far_substitution": max(0.0, measured["far"] - fitted["far"]),
        }
        print(f"{position}: across {across:.4f}, down {down:.4f} key pitches; row "
              f"{fitted['row']:.5f} (measured {measured['row']:.5f}), adjacent row "
              f"{fitted['adjacent_row']:.5f} (measured {measured['adjacent_row']:.5f}), far "
              f"{fitted['far']:.6f} of measured {measured['far']:.5f}")
    paths.touch_spread.write_text(json.dumps({"language": measurements["language"],
                                              "positions": spreads}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
