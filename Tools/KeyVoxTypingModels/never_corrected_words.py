"""The words the action model never replaces: the dictionary's words and, for English, SCOWL's
size-50 words of every spelling, or, for another language, its vocabulary's common part
(`language_build.common_words`)."""

import language_build
from words import clean


def never_corrected_words(paths, language):
    words = {line.split("\t", 1)[0] for line in
             paths.dictionary_unigrams.read_text(encoding="utf-8").splitlines()}
    if language.uses_english_text:
        words.update(clean(word) for word in
                     paths.protected_words.read_text(encoding="utf-8").splitlines())
    else:
        words.update(language_build.common_words(paths))
    return words
