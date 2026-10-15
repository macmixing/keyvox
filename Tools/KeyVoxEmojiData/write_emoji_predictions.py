"""Writes the emoji the KeyVox keyboards' suggestion bar offers for a word, from public Unicode data
only: an emoji's CLDR name (its Unicode name when CLDR has none), the CLDR keywords of the most used
emoji in Unicode's ranking (unicode.org/emoji/frequency.html), and the catalog
(write_emoji_catalog.py).

A word gets, at most three, in this order:
0. KeyVox's own additions, emoji_prediction_additions.txt beside this script, for words Unicode's
   data leaves out;
1. emoji whose name is the word, then emoji whose name is the word with "face" or "flag" left out
   ("dog face", "flag: Cuba"), by Unicode's ranking;
2. the person, woman, and man versions of such a name ("woman guard"), in the catalog's order;
3. emoji that have the word among their CLDR keywords, by Unicode's ranking: the most used (the first
   MOST_USED of the ranking) for any word, and those further down to the first FEW_FOUND_RANK for a
   word at most FEW_FOUND emoji have among their keywords, after the emoji of rules 0 to 2.
A plural in the vocabulary without emoji of its own by rules 0 to 2 or the most used emoji's
keywords gets what its singular gets ("dogs" what "dog" gets), then its own from rule 3.

A wrong emoji costs the bar its third word, so a keyword shared by many emoji counts only for the
most used: scored against the system keyboard's bar, watched with Tools/AppleKeyboardBaseline
(CorrectionMemoryProbeTests, once an emoji was typed, as the bar offers none before), trusting
every keyword gave about one wrong word for each right one, while a keyword few emoji share
usually names what the word means.

A word is compared as KeyVoxEmoji's EmojiSearch compares words: decomposed for compatibility,
without nonspacing marks, lowercased.

Output, one line each, the words sorted:
    <word>\t<emoji>      a word and its emoji, separated by spaces, as the catalog has them

Usage: python3 -I write_emoji_predictions.py <emoji_catalog.txt> <annotations.json> <annotations-derived.json> <frequency.html> <vocabulary.txt> <output>
"""

import json
import os
import sys

# Run isolated (-I), Python leaves this folder off the import path; the search data's reading of
# words, names, and ranks is shared from beside this script, without leaving compiled files here.
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from write_emoji_search import catalog_emoji, frequency_ranks, key, words  # noqa: E402

ADDITIONS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "emoji_prediction_additions.txt")
MOST_USED = 25
FEW_FOUND = 2
FEW_FOUND_RANK = 300
LEFT_OUT = {"face", "flag"}
PEOPLE = {"person", "woman", "man"}
LIMIT = 3


def entries(path):
    root = json.load(open(path, encoding="utf-8"))
    return next(iter(root.values()))["annotations"]


def additions(catalog_texts):
    """KeyVox's own emoji for words, checked against the catalog."""
    added = {}
    for line in open(ADDITIONS, encoding="utf-8"):
        if not line.strip() or line.startswith("#"):
            continue
        word, emoji = line.rstrip("\n").split("\t")
        unknown = [text for text in emoji.split(" ") if text not in catalog_texts]
        if unknown:
            sys.exit(f"{ADDITIONS}: {word} has emoji the catalog lacks: {' '.join(unknown)}")
        added[key(word)] = emoji.split(" ")
    return added


def singulars(word):
    """The singulars a plural may stand for."""
    for ending, replacement in (("ies", "y"), ("es", ""), ("s", "")):
        if word.endswith(ending) and len(word) - len(ending) >= 3:
            yield word[: -len(ending)] + replacement


def main(catalog_path, annotations_path, derived_path, frequency_path, vocabulary_path, output_path):
    plain = entries(annotations_path)
    derived = entries(derived_path)
    ranks = frequency_ranks(frequency_path)
    unranked = len(ranks)
    found = {}
    catalog = list(catalog_emoji(catalog_path))
    keywords = {}
    for text, _ in catalog:
        entry = plain.get(key(text)) or derived.get(key(text)) or {}
        keywords[text] = {word for phrase in entry.get("default", []) for word in words(phrase)}
    emoji_count = {}
    for found_words in keywords.values():
        for word in found_words:
            emoji_count[word] = emoji_count.get(word, 0) + 1
    for order, (text, unicode_name) in enumerate(catalog):
        entry = plain.get(key(text)) or derived.get(key(text)) or {}
        name = words(" ".join(entry.get("tts", [])) or unicode_name)
        rank = ranks.get(key(text), unranked)
        shortened = [word for word in name if word not in LEFT_OUT]
        without_people = [word for word in shortened if word not in PEOPLE] or shortened
        matches = []
        if len(name) == 1:
            matches.append((name[0], (0, rank)))
        elif len(shortened) == 1:
            matches.append((shortened[0], (1, rank)))
        elif len(without_people) == 1:
            matches.append((without_people[0], (2, order)))
        for keyword in keywords[text]:
            if rank < MOST_USED:
                matches.append((keyword, (3, rank)))
            elif rank < FEW_FOUND_RANK and emoji_count[keyword] <= FEW_FOUND:
                matches.append((keyword, (4, rank)))
        for word, place in matches:
            found.setdefault(word, []).append((place, text))
    # The most used emoji's matches first, the few-found keyword matches after them.
    emoji_by_word, few_found = {}, {}
    for word, places in found.items():
        for target, kept in ((emoji_by_word, [p for p in places if p[0][0] < 4]),
                             (few_found, [p for p in places if p[0][0] == 4])):
            chosen = []
            for _, text in sorted(kept):
                if text not in chosen:
                    chosen.append(text)
            if chosen:
                target[word] = chosen[:LIMIT]
    for word, emoji in additions({text for text, _ in catalog}).items():
        emoji_by_word[word] = (emoji + [text for text in emoji_by_word.get(word, []) if text not in emoji])[:LIMIT]

    def extended(word, emoji):
        return (emoji + [text for text in few_found.get(word, []) if text not in emoji])[:LIMIT]

    with_few_found = {word: extended(word, emoji_by_word.get(word, [])) for word in emoji_by_word.keys() | few_found.keys()}
    vocabulary = {word for line in open(vocabulary_path, encoding="utf-8") for word in [line.strip()]
                  if word.isalpha() and word.islower()}
    plurals = {}
    for plural in sorted(vocabulary - emoji_by_word.keys()):
        singular = next((form for form in singulars(plural) if form in with_few_found), None)
        if singular:
            plurals[plural] = extended(plural, with_few_found[singular])
    emoji_by_word = {**with_few_found, **plurals}
    with open(output_path, "w", encoding="utf-8") as output:
        output.write("".join(f"{word}\t{' '.join(emoji)}\n" for word, emoji in sorted(emoji_by_word.items())))
    print(f"{len(emoji_by_word)} words with emoji", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 7:
        sys.exit(__doc__)
    main(*sys.argv[1:])
