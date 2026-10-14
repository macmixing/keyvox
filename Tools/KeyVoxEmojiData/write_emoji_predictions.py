"""Writes the emoji the KeyVox keyboards' suggestion bar offers for a word, from public Unicode data
only: an emoji's CLDR name (its Unicode name when CLDR has none), the CLDR keywords of the most used
emoji in Unicode's ranking (unicode.org/emoji/frequency.html), and the catalog
(write_emoji_catalog.py).

A word gets, at most three, in this order:
1. emoji whose name is the word, then emoji whose name is the word with "face" or "flag" left out
   ("dog face", "flag: Cuba"), by Unicode's ranking;
2. the person, woman, and man versions of such a name ("woman guard"), in the catalog's order;
3. the most used emoji (the first MOST_USED of the ranking) that have the word among their CLDR
   keywords, by Unicode's ranking.
A plural in the vocabulary gets what its singular gets ("dogs" what "dog" gets).

Watching the system keyboard's bar for 320 words (Tools/AppleKeyboardBaseline,
CorrectionMemoryProbeTests; once an emoji was typed, as the bar offers none before) showed emoji
for 164 of them; this data gives emoji for 75 of those 164, and for 5 of the 156 it gave none.
Rules reaching further into CLDR's keywords got more of the 164 but about one wrong word for each
right one, and a wrong word costs the bar its third word.

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

MOST_USED = 25
LEFT_OUT = {"face", "flag"}
PEOPLE = {"person", "woman", "man"}
LIMIT = 3


def entries(path):
    root = json.load(open(path, encoding="utf-8"))
    return next(iter(root.values()))["annotations"]


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
    for order, (text, unicode_name) in enumerate(catalog_emoji(catalog_path)):
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
        if rank < MOST_USED:
            for keyword in {word for phrase in entry.get("default", []) for word in words(phrase)}:
                matches.append((keyword, (3, rank)))
        for word, place in matches:
            found.setdefault(word, []).append((place, text))
    emoji_by_word = {}
    for word, places in found.items():
        chosen = []
        for _, text in sorted(places):
            if text not in chosen:
                chosen.append(text)
        emoji_by_word[word] = chosen[:LIMIT]
    vocabulary = {word for line in open(vocabulary_path, encoding="utf-8") for word in [line.strip()]
                  if word.isalpha() and word.islower()}
    singular_emoji = dict(emoji_by_word)
    for plural in sorted(vocabulary - singular_emoji.keys()):
        singular = next((form for form in singulars(plural) if form in singular_emoji), None)
        if singular:
            emoji_by_word[plural] = singular_emoji[singular]
    with open(output_path, "w", encoding="utf-8") as output:
        output.write("".join(f"{word}\t{' '.join(emoji)}\n" for word, emoji in sorted(emoji_by_word.items())))
    print(f"{len(emoji_by_word)} words with emoji", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 7:
        sys.exit(__doc__)
    main(*sys.argv[1:])
