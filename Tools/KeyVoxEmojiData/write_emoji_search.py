"""Writes the emoji search data the KeyVox keyboards bundle: for each emoji in the catalog
(write_emoji_catalog.py), the words that find it, from its Unicode name, its CLDR name and
keywords, and CLDR's derived annotations, with the emoji in Unicode's ranking of how often
emoji are used (unicode.org/emoji/frequency.html) and those it does not rank after them, in the
catalog's order.

Watching the system emoji keyboard's search (Tools/AppleKeyboardBaseline,
EmojiFrequentlyUsedProbeTests) showed the most used emoji first; of its first eight results for
twenty everyday searches, these words in this order find 92 of 147, 25 in the same place.

A word is a run of letters and digits, compared without case or accents: decomposed for
compatibility, without nonspacing marks, lowercased. KeyVoxEmoji's EmojiSearch reads a search the
same way. A word KeyVox's own bar emoji (emoji_prediction_additions.txt beside this script) give no
emoji finds none here either.

Output, one line each, the emoji in that order:
    <emoji>\t<words>      an emoji as the catalog has it and its words, separated by spaces

Usage: python3 -I write_emoji_search.py <emoji_catalog.txt> <annotations.json> <annotations-derived.json> <frequency.html> <output>
"""

import html
import json
import os
import re
import sys
import unicodedata

ADDITIONS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "emoji_prediction_additions.txt")
WORD = re.compile(r"[^\W_]+")
FREQUENCY_ROW = re.compile(r"<tr>\s*<td>(?:<span>)?\d+\+?(?:</span>)?</td>\s*<td>(.*?)</td>", re.S)


def key(emoji):
    return emoji.replace("️", "")


def words(phrase):
    decomposed = unicodedata.normalize("NFKD", phrase)
    folded = "".join(c for c in decomposed if unicodedata.category(c) != "Mn").lower()
    return WORD.findall(folded)


def words_without_emoji():
    """The words KeyVox's own bar emoji give no emoji."""
    lines = [line.rstrip("\n").split("\t") for line in open(ADDITIONS, encoding="utf-8")
             if line.strip() and not line.startswith("#")]
    return {" ".join(words(word)) for word, emoji in lines if not emoji}


def catalog_emoji(path):
    """Each emoji in the catalog and its Unicode name."""
    for line in open(path, encoding="utf-8"):
        if line.strip() and not line.startswith("@"):
            fields = line.split("\t")
            yield fields[0], fields[1]


def annotations(paths):
    """Each emoji's CLDR phrases, by emoji without variation selectors."""
    phrases = {}
    for path in paths:
        root = json.load(open(path, encoding="utf-8"))
        entries = next(iter(root.values()))["annotations"]
        for emoji, entry in entries.items():
            phrases.setdefault(key(emoji), []).extend(entry.get("tts", []) + entry.get("default", []))
    return phrases


def frequency_ranks(path):
    """Each emoji's place in Unicode's ranking, by emoji without variation selectors."""
    page = open(path, encoding="utf-8").read()
    ranks = {}
    for row in FREQUENCY_ROW.findall(page):
        for emoji in html.unescape(re.sub(r"<[^>]*>", "", row)).split():
            if emoji != "…":
                ranks.setdefault(key(emoji), len(ranks))
    return ranks


def main(catalog_path, annotations_path, derived_path, frequency_path, output_path):
    emoji = list(catalog_emoji(catalog_path))
    phrases = annotations([annotations_path, derived_path])
    ranks = frequency_ranks(frequency_path)
    unranked = len(ranks)
    left_out = words_without_emoji()
    ordered = sorted(enumerate(emoji), key=lambda item: (ranks.get(key(item[1][0]), unranked), item[0]))
    lines = []
    for _, (text, name) in ordered:
        found = sorted({word for phrase in [name] + phrases.get(key(text), []) for word in words(phrase)} - left_out)
        if found:
            lines.append(f"{text}\t{' '.join(found)}")
    with open(output_path, "w", encoding="utf-8") as output:
        output.write("\n".join(lines) + "\n")
    ranked = sum(1 for text, _ in emoji if key(text) in ranks)
    print(f"{len(lines)} of {len(emoji)} emoji searchable, {ranked} ranked", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    main(*sys.argv[1:])
