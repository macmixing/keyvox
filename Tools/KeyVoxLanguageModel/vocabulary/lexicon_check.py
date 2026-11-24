"""Checks lowercase spellings against a lexicon's forms as written, where a word joined to an
elided form, as French joins an elided article or conjunction to the next word, is checked part
by part: the lexicon lists the elided forms themselves, ending in an apostrophe."""

_APOSTROPHE = "'"


def lexicon_accepted(words: set[str], forms: set[str]) -> set[str]:
    elided = {form.lower() for form in forms if form.endswith(_APOSTROPHE)}

    def accepts(word: str) -> bool:
        if word in forms:
            return True
        position = word.find(_APOSTROPHE)
        while position != -1:
            if word[:position + 1] in elided and accepts(word[position + 1:]):
                return True
            position = word.find(_APOSTROPHE, position + 1)
        return False

    return {word for word in words if accepts(word)}
