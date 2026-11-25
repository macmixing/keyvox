"""Taps aimed at a letter key, drawn from a two-dimensional Gaussian around the key's center with
one spread across and one down, in key pitches, and the letter key each tap lands on.

This is the touch model Fowler et al. simulate typing with in "Effects of Language Modeling and
its Personalization on Touchscreen Typing Performance" (CHI 2015,
https://research.google/pubs/pub43272): each tap from a 2D Gaussian centered on the intended key,
and a tap outside every key drawn again. They set the spreads to 1.97 mm across and 1.88 mm down
on Nexus 5 keys 6.16 mm wide and 9.42 mm tall, about 0.32 and 0.20 key pitches, for every tap
before any fix. The simulator fits its spreads to the mistakes ITE typists left in their text
instead (`fit_touch_spread.py`)."""

import math

from scipy.special import ndtr


class TouchSpread:
    def __init__(self, layout, across, down):
        self.layout = layout
        self.across = across
        self.down = down
        self.rows = {}
        for letter, (left, row) in layout.keys.items():
            self.rows.setdefault(row, []).append((left, letter))
        for keys in self.rows.values():
            keys.sort()

    def key_at(self, x, y):
        """The letter key under the tap, or None when it lands outside every letter key."""
        row = math.floor(y)
        keys = self.rows.get(row)
        if keys is None:
            return None
        column = math.floor(x - keys[0][0])
        return keys[column][1] if 0 <= column < len(keys) else None

    def tap(self, letter, rng, scale=1.0):
        """The letter a tap aimed at the letter's key lands on, with both spreads times
        `scale`."""
        center_x, center_y = self.layout.center(letter)
        across, down = self.across * scale, self.down * scale
        while True:
            hit = self.key_at(rng.gauss(center_x, across), rng.gauss(center_y, down))
            if hit is not None:
                return hit

    def hit_probabilities(self, letter, scale=1.0):
        """How likely a tap aimed at the letter lands on each letter key, exactly: each key's
        share of the Gaussian's mass over the letter keys."""
        center_x, center_y = self.layout.center(letter)
        across_spread, down_spread = self.across * scale, self.down * scale
        masses = {}
        for other in self.layout.letters:
            left, right, top, bottom = self.layout.bounds(other)
            across = (ndtr((right - center_x) / across_spread)
                      - ndtr((left - center_x) / across_spread))
            down = ndtr((bottom - center_y) / down_spread) - ndtr((top - center_y) / down_spread)
            masses[other] = across * down
        total = sum(masses.values())
        return {other: mass / total for other, mass in masses.items()}

    def miss_rate(self, letter_counts, scale=1.0):
        """How often a tap lands on another key than the intended one, over the letters."""
        total = sum(letter_counts.values())
        return sum(count * (1.0 - self.hit_probabilities(letter, scale)[letter])
                   for letter, count in letter_counts.items()) / total
