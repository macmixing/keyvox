"""Writes the emoji the KeyVox keyboards' suggestion bar offers for a word, from the emoji search's
own data (write_emoji_search.py), so the bar offers what a search for that word finds first.

A word gets, at most three:
0. KeyVox's own additions, emoji_prediction_additions.txt beside this script, for words the search
   data leaves out or gets wrong, in place of the rules below; an addition without emoji leaves its
   word, and the plurals that would take its emoji, without any;
1. otherwise the emoji the search data has the word among, whole, in the search data's order, as
   the emoji search finds them; none for a function word (a determiner, preposition, conjunction,
   pronoun, or particle, as KeyVox's word kinds class it), which the search data has only from the
   middle of emoji names;
2. otherwise, for a plural in the vocabulary, what the longest singular it can stand for gets
   ("dogs" what "dog" gets).
KeyVoxEmoji's EmojiSearch puts a word's emoji from here first, so the bar and the search agree.

A word is compared as KeyVoxEmoji's EmojiSearch compares words: decomposed for compatibility,
without nonspacing marks, lowercased.

Output, one line each, the words sorted:
    <word>\t<emoji>      a word and its emoji, separated by spaces, as the catalog has them

Usage: python3 -I write_emoji_predictions.py <emoji_search.txt> <emoji_catalog.txt> <word_kinds.tsv> <vocabulary.txt> <output>
"""

import os
import sys

# Run isolated (-I), Python leaves this folder off the import path; the search data's reading of
# words is shared from beside this script, without leaving compiled files here.
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from write_emoji_search import catalog_emoji, words  # noqa: E402

ADDITIONS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "emoji_prediction_additions.txt")
FUNCTION_KINDS = {"Determiner", "Preposition", "Conjunction", "Pronoun", "Particle"}
LIMIT = 3


def additions(catalog_texts):
    """KeyVox's own emoji for words, checked against the catalog."""
    added = {}
    for line in open(ADDITIONS, encoding="utf-8"):
        if not line.strip() or line.startswith("#"):
            continue
        word, emoji = line.rstrip("\n").split("\t")
        texts = emoji.split(" ") if emoji else []
        unknown = [text for text in texts if text not in catalog_texts]
        if unknown:
            sys.exit(f"{ADDITIONS}: {word} has emoji the catalog lacks: {' '.join(unknown)}")
        added[" ".join(words(word))] = texts
    return added


def singulars(word):
    """The singulars a plural may stand for."""
    for ending, replacement in (("ies", "y"), ("es", ""), ("s", "")):
        if word.endswith(ending) and len(word) - len(ending) >= 3:
            yield word[: -len(ending)] + replacement


def main(search_path, catalog_path, word_kinds_path, vocabulary_path, output_path):
    found = {}
    for line in open(search_path, encoding="utf-8"):
        emoji, search_words = line.rstrip("\n").split("\t")
        for word in search_words.split(" "):
            found.setdefault(word, []).append(emoji)
    kinds = dict(line.rstrip("\n").split("\t") for line in open(word_kinds_path, encoding="utf-8") if "\t" in line)
    emoji_by_word = {word: emoji[:LIMIT] for word, emoji in found.items() if kinds.get(word) not in FUNCTION_KINDS}
    emoji_by_word.update(additions({text for text, _ in catalog_emoji(catalog_path)}))
    vocabulary = {word for line in open(vocabulary_path, encoding="utf-8") for word in [line.strip()]
                  if word.isalpha() and word.islower()}
    plurals = {}
    for plural in sorted(vocabulary - emoji_by_word.keys()):
        singular = max((form for form in singulars(plural) if form in emoji_by_word), key=len, default=None)
        if singular:
            plurals[plural] = emoji_by_word[singular]
    emoji_by_word.update(plurals)
    written = sorted((word, emoji) for word, emoji in emoji_by_word.items() if emoji)
    with open(output_path, "w", encoding="utf-8") as output:
        output.write("".join(f"{word}\t{' '.join(emoji)}\n" for word, emoji in written))
    print(f"{len(written)} words with emoji", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    main(*sys.argv[1:])
