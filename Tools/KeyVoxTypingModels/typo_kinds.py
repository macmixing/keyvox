"""Sorts the differences between an intended word and the letters typed for it into the kinds of
typing mistakes the typo simulator makes, and counts each kind's chances, so the simulator's
rates can be measured from real typing and its own output measured the same way.

A word typed so differently that it is no plausible typo of the intended word, more than four
edits or more than half its length, is a different word, not a typing mistake; it is counted as
replaced and nothing else is counted for it.

Kinds, each with the chances it had:
- `substitution_row`, `substitution_adjacent_row`, `substitution_far`: a letter typed as the key
  beside it in its row, as an overlapping key in the row above or below, or as any other key;
  per intended letter.
- `omission`: a letter left out; per intended letter. `undoubled`: one letter of a double
  letter left out; per double letter.
- `doubled`: a letter typed twice; `insertion_neighbor`: an extra key beside the letter before
  or after it; `insertion_far`: any other extra letter; per intended letter.
- `transposition`: two neighboring letters typed in swapped order; per pair of neighboring
  different letters.
- `apostrophe_dropped`: a word's apostrophe left out; per word with an apostrophe. An apostrophe
  typed where the word has none is not counted.

Words are also counted by how many letter mistakes they have, every kind but the apostrophe, in
all and by the intended word's length up to `LONGEST_COUNTED_LENGTH` letters, longer words
counted with those.

Letter kinds are counted by where the intended letter is in the word: first, last, or middle.
An extra letter is counted at the intended letter it follows, or at the first letter when it
comes before every letter. For the kinds a touch spread does not explain, `substitution_far`,
`insertion_neighbor`, and `insertion_far`, the letters are counted too: the intended letter and
the one typed for it, or the letter an extra one is counted at and the extra letter."""

from collections import Counter

from words import damerau_osa

LETTERED_KINDS = ("substitution_far", "insertion_neighbor", "insertion_far")
LETTER_KINDS = (
    "substitution_row", "substitution_adjacent_row", "substitution_far", "omission",
    "doubled", "insertion_neighbor", "insertion_far",
)
POSITIONS = ("first", "middle", "last")
LONGEST_COUNTED_LENGTH = 12


def position_of(index, length):
    if index <= 0:
        return "first"
    return "last" if index >= length - 1 else "middle"


def alignment(intended, typed):
    """The edits that turn the intended letters into the typed ones, with the fewest edits and
    swaps of neighbors counted as one, in order: (operation, intended index, typed index)."""
    rows, columns = len(intended) + 1, len(typed) + 1
    cost = [[0] * columns for _ in range(rows)]
    for row in range(rows):
        cost[row][0] = row
    for column in range(columns):
        cost[0][column] = column
    for row in range(1, rows):
        for column in range(1, columns):
            differs = intended[row - 1] != typed[column - 1]
            cost[row][column] = min(cost[row - 1][column] + 1, cost[row][column - 1] + 1,
                                    cost[row - 1][column - 1] + differs)
            if (row > 1 and column > 1 and intended[row - 1] == typed[column - 2]
                    and intended[row - 2] == typed[column - 1] and differs):
                cost[row][column] = min(cost[row][column], cost[row - 2][column - 2] + 1)
    edits = []
    row, column = len(intended), len(typed)
    while row > 0 or column > 0:
        here = cost[row][column]
        if row > 0 and column > 0 and intended[row - 1] == typed[column - 1] \
                and here == cost[row - 1][column - 1]:
            row, column = row - 1, column - 1
        elif row > 0 and column > 0 and here == cost[row - 1][column - 1] + 1:
            edits.append(("substitution", row - 1, column - 1))
            row, column = row - 1, column - 1
        elif (row > 1 and column > 1 and intended[row - 1] == typed[column - 2]
              and intended[row - 2] == typed[column - 1] and here == cost[row - 2][column - 2] + 1):
            edits.append(("transposition", row - 2, column - 2))
            row, column = row - 2, column - 2
        elif row > 0 and here == cost[row - 1][column] + 1:
            edits.append(("omission", row - 1, column))
            row -= 1
        else:
            edits.append(("insertion", row, column - 1))
            column -= 1
    return list(reversed(edits))


class TypoCounts:
    """How often each kind happened and how many chances it had, over many words."""

    def __init__(self):
        self.events = Counter()
        self.chances = Counter()
        self.words = Counter()
        self.edits_per_word = Counter()
        self.by_length = {length: Counter() for length in range(1, LONGEST_COUNTED_LENGTH + 1)}
        self.letters = {kind: Counter() for kind in LETTERED_KINDS}

    def add(self, intended, typed, layout):
        longest = max(len(intended), len(typed))
        distance = damerau_osa(intended, typed)
        if distance > 4 or distance / max(1, longest) > 0.5:
            self.words["replaced"] += 1
            return
        self.words["counted"] += 1
        self.words["mistyped"] += typed != intended
        kinds = 0
        if "'" in intended:
            self.chances["apostrophe_dropped"] += 1
            if "'" not in typed:
                self.events["apostrophe_dropped"] += 1
        letters = intended.replace("'", "")
        typed_letters = typed.replace("'", "")
        for index in range(len(letters)):
            position = position_of(index, len(letters))
            for kind in LETTER_KINDS:
                self.chances[(kind, position)] += 1
            if index and letters[index] == letters[index - 1]:
                self.chances["undoubled"] += 1
            elif index:
                self.chances["transposition"] += 1
        for operation, intended_index, typed_index in alignment(letters, typed_letters):
            kind = self.kind(operation, intended_index, typed_index, letters, typed_letters, layout)
            kinds += 1
            if kind in ("undoubled", "transposition"):
                self.events[kind] += 1
                continue
            anchor = max(0, intended_index if operation != "insertion" else intended_index - 1)
            self.events[(kind, position_of(anchor, len(letters)))] += 1
            if kind in LETTERED_KINDS:
                self.letters[kind][(letters[anchor], typed_letters[typed_index])] += 1
        self.edits_per_word[min(kinds, 3)] += 1
        self.by_length[max(1, min(len(letters), LONGEST_COUNTED_LENGTH))][min(kinds, 2)] += 1

    @staticmethod
    def kind(operation, intended_index, typed_index, letters, typed, layout):
        if operation == "transposition":
            return "transposition"
        if operation == "substitution":
            intended_letter, typed_letter = letters[intended_index], typed[typed_index]
            if intended_letter not in layout.keys or typed_letter not in layout.keys:
                return "substitution_far"
            return "substitution_" + layout.relation(intended_letter, typed_letter)
        if operation == "omission":
            letter = letters[intended_index]
            doubled = ((intended_index > 0 and letters[intended_index - 1] == letter)
                       or (intended_index + 1 < len(letters)
                           and letters[intended_index + 1] == letter))
            return "undoubled" if doubled else "omission"
        extra = typed[typed_index]
        if ((typed_index > 0 and typed[typed_index - 1] == extra)
                or (typed_index + 1 < len(typed) and typed[typed_index + 1] == extra)):
            return "doubled"
        around = [letters[index] for index in (intended_index - 1, intended_index)
                  if 0 <= index < len(letters)]
        if extra in layout.keys and any(letter in layout.keys and extra in layout.neighbors(letter)
                                        for letter in around):
            return "insertion_neighbor"
        return "insertion_far"

    def rates(self):
        """Each kind's rate per chance, letter kinds by position."""
        result = {}
        for key, chances in sorted(self.chances.items(), key=str):
            name = key if isinstance(key, str) else f"{key[0]}/{key[1]}"
            result[name] = self.events[key] / chances if chances else 0.0
        return result

    def summary(self):
        return {
            "words": {kind: self.words[kind] for kind in ("counted", "mistyped", "replaced")},
            "words_by_mistake_count": {str(count): self.edits_per_word[count]
                                       for count in range(4)},
            "words_by_length": {str(length): {str(count): counts[count] for count in range(3)}
                                for length, counts in self.by_length.items()},
            "events": {(key if isinstance(key, str) else f"{key[0]}/{key[1]}"): count
                       for key, count in sorted(self.events.items(), key=str)},
            "chances": {(key if isinstance(key, str) else f"{key[0]}/{key[1]}"): count
                        for key, count in sorted(self.chances.items(), key=str)},
            "rates": self.rates(),
            "letters": {kind: {f"{context}{produced}": count
                               for (context, produced), count in sorted(pairs.items())}
                        for kind, pairs in self.letters.items()},
        }
