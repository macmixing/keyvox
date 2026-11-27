"""How the typing-model builders read words: English's as plain ASCII letter words with at most
one inner apostrophe, casefolded as ITE's text is read, any language's typed and suggested words
lowercased without folding (`normalized`, which keeps German "ß"), and the edit distances they
compare words with."""

import re

WORD = re.compile(r"[A-Za-z]+(?:['’][A-Za-z]+)?")
WHOLE_WORD = re.compile(r"^[A-Za-z]+(?:['’][A-Za-z]+)?$")


def clean(value):
    return (value or "").replace("’", "'").casefold().strip()


def normalized(value):
    """A word as the keyboard's engine compares it: lowercase, with the ASCII apostrophe."""
    return (value or "").replace("’", "'").lower().strip()


def tokenize(text):
    return [clean(token) for token in WORD.findall((text or "").replace("’", "'"))]


def valid_word(text):
    return 1 <= len(text) <= 47 and WHOLE_WORD.fullmatch(text) is not None


def edit_distance(left, right):
    previous = list(range(len(right) + 1))
    for left_index, left_character in enumerate(left, 1):
        current = [left_index]
        for right_index, right_character in enumerate(right, 1):
            current.append(min(
                current[-1] + 1,
                previous[right_index] + 1,
                previous[right_index - 1] + (left_character != right_character),
            ))
        previous = current
    return previous[-1]


def damerau_osa(before, after):
    rows, columns = len(before) + 1, len(after) + 1
    matrix = [[0] * columns for _ in range(rows)]
    for row in range(rows):
        matrix[row][0] = row
    for column in range(columns):
        matrix[0][column] = column
    for row in range(1, rows):
        for column in range(1, columns):
            cost = 0 if before[row - 1] == after[column - 1] else 1
            matrix[row][column] = min(
                matrix[row - 1][column] + 1,
                matrix[row][column - 1] + 1,
                matrix[row - 1][column - 1] + cost,
            )
            if (row > 1 and column > 1 and before[row - 1] == after[column - 2]
                    and before[row - 2] == after[column - 1]):
                matrix[row][column] = min(matrix[row][column],
                                           matrix[row - 2][column - 2] + cost)
    return matrix[-1][-1]
