"""Writes the emoji the KeyVox keyboards' suggestion bar offers for a word, from the emoji search's
own data (write_emoji_search.py), so the bar offers what a search for that word finds first.

A word gets, at most three:
0. the language's own additions (`--additions`; English's are emoji_prediction_additions.txt beside
   this script), for words the search data leaves out or gets wrong, in place of the rules below; an
   addition without emoji leaves its word, and the plurals that would take its emoji, without any;
1. otherwise the emoji the search data has the word among, whole, in the search data's order, as
   the emoji search finds them; none for a function word (a determiner, preposition, conjunction,
   pronoun, or particle, as the language's word kinds class it: the word's own kind, or, for a word
   the kinds spell only with accents, the kind of the most common vocabulary word spelled so), which
   the search data has only from the middle of emoji names;
2. otherwise, for a plural in the vocabulary, what the longest singular it can stand for gets, by
   the language's plural endings (`--plural-endings`, each an ending and what replaces it in the
   singular, such as English's "ies:y", for which "puppies" gets what "puppy" gets), when it has
   any; a language whose search data holds its plurals itself (write_emoji_search.py `--forms`)
   needs none.
No word the language's typing data leaves out (`--leave-out`, as write_emoji_search.py reads it)
gets any. KeyVoxEmoji's EmojiSearch puts a word's emoji from here first, so the bar and the search
agree.

A word is compared as KeyVoxEmoji's EmojiSearch compares words: decomposed for compatibility,
without nonspacing marks, case folded.

Output, one line each, the words sorted:
    <word>\t<emoji>      a word and its emoji, separated by spaces, as the catalog has them

Usage: python3 -I write_emoji_predictions.py <emoji_search.txt> <emoji_catalog.txt> <word_kinds.tsv> <vocabulary.txt> <output>
           [--additions <additions.txt>] [--leave-out <offensive_words.txt>] [--plural-endings <ending:singular>...]
<word_kinds.tsv> and <vocabulary.txt> are the language's, as Tools/KeyVoxLanguageModel writes them.
"""

import argparse
import os
import sys

# Run isolated (-I), Python leaves this folder off the import path; the search data's reading of
# words is shared from beside this script, without leaving compiled files here.
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from write_emoji_search import additions, catalog_emoji, left_out_test, words  # noqa: E402

FUNCTION_KINDS = {"Determiner", "Preposition", "Conjunction", "Pronoun", "Particle"}
LIMIT = 3


def checked_additions(path, catalog_texts):
    """The language's own emoji for words, checked against the catalog."""
    added = additions(path)
    for word, texts in added.items():
        unknown = [text for text in texts if text not in catalog_texts]
        if unknown:
            sys.exit(f"{path}: {word} has emoji the catalog lacks: {' '.join(unknown)}")
    return added


def word_kinds(word_kinds_path, vocabulary):
    """Each word's kind by its spelling as the search data has it: the word's own, or the most common
    vocabulary word's of that spelling."""
    kinds = dict(line.rstrip("\n").split("\t") for line in open(word_kinds_path, encoding="utf-8") if "\t" in line)
    by_spelling = {}
    for word in vocabulary:
        if word in kinds:
            by_spelling.setdefault(" ".join(words(word)), kinds[word])
    by_spelling.update(kinds)
    return by_spelling


def singulars(word, endings):
    """The singulars a plural may stand for by `endings`, each an ending and its replacement."""
    for ending, replacement in endings:
        if word.endswith(ending) and len(word) - len(ending) >= 3:
            yield word[: -len(ending)] + replacement


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    for name in ("search", "catalog", "word_kinds", "vocabulary", "output"):
        parser.add_argument(name)
    parser.add_argument("--additions", help="the language's own bar emoji")
    parser.add_argument("--leave-out", help="the patterns of the words the typing data leaves out")
    parser.add_argument("--plural-endings", nargs="*", default=[], metavar="ENDING:SINGULAR",
                        help="the language's plural endings, each with what replaces it in the singular")
    arguments = parser.parse_args()

    found = {}
    for line in open(arguments.search, encoding="utf-8"):
        emoji, search_words = line.rstrip("\n").split("\t")
        for word in search_words.split(" "):
            found.setdefault(word, []).append(emoji)
    ordered_vocabulary = [line.strip() for line in open(arguments.vocabulary, encoding="utf-8")]
    kinds = word_kinds(arguments.word_kinds, ordered_vocabulary)
    emoji_by_word = {word: emoji[:LIMIT] for word, emoji in found.items() if kinds.get(word) not in FUNCTION_KINDS}
    emoji_by_word.update(checked_additions(arguments.additions, {text for text, _ in catalog_emoji(arguments.catalog)}))
    vocabulary = {word for word in ordered_vocabulary if word.isalpha() and word.islower()}
    endings = [tuple(rule.split(":", 1)) for rule in arguments.plural_endings]
    plurals = {}
    for plural in sorted(vocabulary - emoji_by_word.keys()):
        singular = max((form for form in singulars(plural, endings) if form in emoji_by_word), key=len, default=None)
        if singular:
            plurals[plural] = emoji_by_word[singular]
    emoji_by_word.update(plurals)
    is_left_out = left_out_test(arguments.leave_out)
    written = sorted((word, emoji) for word, emoji in emoji_by_word.items() if emoji and not is_left_out(word))
    with open(arguments.output, "w", encoding="utf-8") as output:
        output.write("".join(f"{word}\t{' '.join(emoji)}\n" for word, emoji in written))
    print(f"{len(written)} words with emoji", file=sys.stderr)


if __name__ == "__main__":
    main()
