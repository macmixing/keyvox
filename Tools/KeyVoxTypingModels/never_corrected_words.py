"""The words the action model never replaces: the dictionary's words and SCOWL's size-50 words
of every spelling."""

from words import clean


def never_corrected_words(paths):
    words = {line.split("\t", 1)[0] for line in
             paths.dictionary_unigrams.read_text(encoding="utf-8").splitlines()}
    words.update(clean(word) for word in
                 paths.protected_words.read_text(encoding="utf-8").splitlines())
    return words
