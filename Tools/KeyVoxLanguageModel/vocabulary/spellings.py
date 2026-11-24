"""Settles which spellings, with or without capitals, a vocabulary keeps of each word in its
keyboard word list.

A word the lexicons know is kept in every spelling they write it in, and in no other: a German
word that is both a noun and a verb keeps both spellings, a German noun the word list writes in
lowercase takes its capital, and a word the list capitalizes only for starting a sentence loses it.
A word the lexicons do not know, such as a name or a compound, keeps the word list's spellings.

Where the language has a spelling check, it is then asked about each word the lexicons do not
know, in lowercase: a spelling with capitals is written in lowercase if the check accepts that, as
its capital was only the sentence's, and is otherwise kept with its capitals, as a name, which
spelling dictionaries leave out. Where the check drops words (`drops_rejected`), a lowercase
spelling it rejects is left out; otherwise every lowercase spelling is kept."""

from collections import defaultdict
from collections.abc import Callable, Iterable


def settled_spellings(word_list: Iterable[str], lexicon: set[str],
                      spelling_check: Callable[[set[str]], set[str]] | None,
                      drops_rejected: bool = True) -> set[str]:
    by_word: defaultdict[str, set[str]] = defaultdict(set)
    for spelling in lexicon:
        by_word[spelling.lower()].add(spelling)
    kept: set[str] = set()
    for spelling in word_list:
        kept.update(by_word.get(spelling.lower()) or {spelling})
    if spelling_check is None:
        return kept
    unlisted = {spelling for spelling in kept if spelling not in lexicon}
    accepted = spelling_check({spelling.lower() for spelling in unlisted})
    settled = kept - unlisted
    for spelling in unlisted:
        if spelling.lower() in accepted:
            settled.add(spelling.lower())
        elif spelling != spelling.lower() or not drops_rejected:
            settled.add(spelling)
    return settled
