"""Settles which spellings, with or without capitals, a vocabulary keeps of each word in its
keyboard word list.

A word the lexicons know is kept in every spelling they write it in, and in no other: a German
word that is both a noun and a verb keeps both spellings, a German noun the word list writes in
lowercase takes its capital, and a word the list capitalizes only for starting a sentence loses it.
A word the lexicons do not know, such as a name or a compound, keeps the word list's spellings.

Where the language has a spelling check, it is then asked about each capitalized word the lexicons
do not know, in lowercase: the word is written in lowercase if the check accepts that, as its
capital was only the sentence's, and is otherwise kept with its capitals, as a name, which spelling
dictionaries leave out. The check leaves out no word: the word list is what the language's typists
are offered, loanwords and forms the check lacks included."""

from collections import defaultdict
from collections.abc import Callable, Iterable


def settled_spellings(word_list: Iterable[str], lexicon: set[str],
                      spelling_check: Callable[[set[str]], set[str]] | None) -> set[str]:
    by_word: defaultdict[str, set[str]] = defaultdict(set)
    for spelling in lexicon:
        by_word[spelling.lower()].add(spelling)
    kept: set[str] = set()
    for spelling in word_list:
        kept.update(by_word.get(spelling.lower()) or {spelling})
    if spelling_check is None:
        return kept
    capitalized = {spelling for spelling in kept if spelling != spelling.lower() and spelling not in lexicon}
    accepted = spelling_check({spelling.lower() for spelling in capitalized})
    lowered = {spelling for spelling in capitalized if spelling.lower() in accepted}
    return (kept - lowered) | {spelling.lower() for spelling in lowered}
