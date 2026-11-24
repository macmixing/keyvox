"""Types a word the way ITE typists did: each letter tapped with the fitted touch spread for its
place in the word, plus the other kinds of mistakes `typo_kinds.py` sorts typing into.

ITE typists' mistakes bunch up: longer words get more per letter, and a word with one mistake
has a second far more often than independent mistakes would. So each word gets a sloppiness,
its length's factor times a draw from a gamma distribution of mean one: the word's mistake
rates are multiplied by it, and its taps spread wider by as much as makes them miss that many
times more often. The spreads, the rates, the length factors, and the gamma distribution's
shape come from `calibrate_typo_simulator.py`, which sets them so that the simulator's mistakes,
measured as ITE typists' were, match theirs.

For a word, in order:
1. Each pair of neighboring different letters is swapped at the transposition rate.
2. Each letter is left out at the omission rate for its place, or, the second of a double
   letter, at the undoubled rate; otherwise it is tapped (`touch_spread.py`), and then replaced
   by a farther key at the far-substitution rate.
3. After each letter, the letter typed is typed again at the doubled rate, and an extra key
   beside it and an extra farther letter are typed at their rates.
4. A word's apostrophe is left out at its rate, which no sloppiness changes.
Farther substitutions and extra letters are drawn from the ones ITE typists made at the same
letter, or from all of them for a letter they never made one at."""

import random
from bisect import bisect
from collections import defaultdict
from itertools import accumulate

import numpy as np

from touch_spread import TouchSpread
from typo_kinds import LETTERED_KINDS, LONGEST_COUNTED_LENGTH, POSITIONS, position_of

# The tap spread scales the miss-rate table covers.
SPREAD_SCALES = np.geomspace(0.2, 8.0, 160)


class LetterChoices:
    """Draws a letter from counts, given the letter it follows or replaces."""

    def __init__(self, pairs):
        by_context = defaultdict(dict)
        overall = defaultdict(int)
        for pair, count in pairs.items():
            context, produced = pair[0], pair[1:]
            by_context[context][produced] = count
            overall[produced] += count
        self.by_context = {context: self.table(counts) for context, counts in by_context.items()}
        self.overall = self.table(overall)

    @staticmethod
    def table(counts):
        letters = sorted(counts)
        return letters, list(accumulate(counts[letter] for letter in letters))

    def draw(self, context, rng, exclude=None):
        letters, totals = self.by_context.get(context, self.overall)
        if exclude is not None and letters == [exclude]:
            letters, totals = self.overall
        while True:
            letter = letters[bisect(totals, rng.random() * totals[-1])]
            if letter != exclude:
                return letter


class TypoSimulator:
    def __init__(self, layout, measurements, calibration, seed):
        self.rng = random.Random(seed)
        self.keys = layout.keys
        self.rates = calibration["rates"]
        self.length_factors = {int(length): factor
                               for length, factor in calibration["length_factors"].items()}
        self.shape = calibration["sloppiness_shape"]
        self.spreads = {}
        self.miss_ratios = {}
        for position in POSITIONS:
            values = calibration["spreads"][position]
            spread = TouchSpread(layout, values["across"], values["down"])
            letters = measurements["letters"][position]
            base = spread.miss_rate(letters)
            self.spreads[position] = spread
            self.miss_ratios[position] = np.asarray(
                [spread.miss_rate(letters, scale) / base for scale in SPREAD_SCALES])
        self.choices = {kind: LetterChoices(measurements["typos"]["letters"][kind])
                        for kind in LETTERED_KINDS}

    def spread_scale(self, position, misses):
        """The spread scale at which taps miss `misses` times as often as at the calibrated
        spreads."""
        return float(np.interp(misses, self.miss_ratios[position], SPREAD_SCALES))

    def type_word(self, word):
        """The letters typed for the word."""
        rng = self.rng
        apostrophe = word.find("'")
        letters = list(word.replace("'", ""))
        sloppiness = (self.length_factors[max(1, min(len(letters), LONGEST_COUNTED_LENGTH))]
                      * rng.gammavariate(self.shape, 1.0 / self.shape))

        def happens(kind):
            return rng.random() < self.rates[kind] * sloppiness

        index = 0
        while index + 1 < len(letters):
            if letters[index] != letters[index + 1] and happens("transposition"):
                letters[index], letters[index + 1] = letters[index + 1], letters[index]
                index += 2
            else:
                index += 1

        scales = {position: self.spread_scale(position, sloppiness) for position in POSITIONS}
        typed = []
        for index, letter in enumerate(letters):
            position = position_of(index, len(letters))
            if happens("undoubled") if index > 0 and letters[index - 1] == letter \
                    else happens(f"omission/{position}"):
                continue
            if letter not in self.keys:
                typed.append(letter)
                continue
            hit = self.spreads[position].tap(letter, rng, scales[position])
            if happens(f"substitution_far/{position}"):
                hit = self.choices["substitution_far"].draw(letter, rng, exclude=letter)
            typed.append(hit)
            if happens(f"doubled/{position}"):
                typed.append(hit)
            if happens(f"insertion_neighbor/{position}"):
                typed.append(self.choices["insertion_neighbor"].draw(letter, rng))
            if happens(f"insertion_far/{position}"):
                typed.append(self.choices["insertion_far"].draw(letter, rng))

        if apostrophe >= 0 and rng.random() >= self.rates["apostrophe_dropped"]:
            typed.insert(min(apostrophe, len(typed)), "'")
        return "".join(typed)
