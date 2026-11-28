"""Writes the emoji search data the KeyVox keyboards bundle for a language: for each emoji in the
catalog (write_emoji_catalog.py), the words that find it, from CLDR's names and keywords and its
derived annotations in the language's locale, with Unicode's English names too when `--names` is
given, with the emoji in Unicode's ranking of how often emoji are used
(unicode.org/emoji/frequency.html) and those it does not rank after them, in the catalog's order.

With `--forms` (write_word_forms.py), an emoji is also found by every form of a noun among its
words, so "Katzen" finds what "Katze" finds, as the system keyboard's search finds them in every
language it was watched in (Tools/AppleKeyboardBaseline, EmojiLanguageProbeTests).

A locale's annotations are its own over those of the locales it inherits from, as CLDR inherits
them: each emoji's name and keywords come from the first locale that has them, the locale, then
its parent in CLDR's `parentLocales.json`, or, without one there, the locale less its last subtag,
down to its language.

Watching the system emoji keyboard's search (Tools/AppleKeyboardBaseline,
EmojiFrequentlyUsedProbeTests) showed the most used emoji first; of its first eight results for
twenty everyday English searches, these words in this order find 92 of 147, 25 in the same place.

A word is a run of letters and digits, compared without case or accents: decomposed for
compatibility, without nonspacing marks, case folded, so German "ß" reads as "ss".
KeyVoxEmoji's EmojiSearch reads a search the same way. A word the language's own bar emoji
(`--additions`, as write_emoji_predictions.py reads them) give no emoji finds none here either, and
neither does a word the language's typing data leaves out (`--leave-out`, the patterns Tools/KeyVoxTypingModels/offensive_words.py writes, each
matching a word's letter form whole: its letters only, case and accents folded).

Output, one line each, the emoji in that order:
    <emoji>\t<words>      an emoji as the catalog has it and its words, separated by spaces

Usage: python3 -I write_emoji_search.py <emoji_catalog.txt> <cldr-json> <locale> <frequency.html> <output>
           [--names] [--forms <forms.tsv>] [--additions <additions.txt>] [--leave-out <offensive_words.txt>]
<cldr-json> is the folder of CLDR's JSON packages, holding cldr-annotations-full,
cldr-annotations-derived-full, and cldr-core.
"""

import argparse
import html
import json
import os
import re
import sys
import unicodedata

WORD = re.compile(r"[^\W_]+")
FREQUENCY_ROW = re.compile(r"<tr>\s*<td>(?:<span>)?\d+\+?(?:</span>)?</td>\s*<td>(.*?)</td>", re.S)
ANNOTATION_SETS = (
    ("cldr-annotations-full", "annotations"),
    ("cldr-annotations-derived-full", "annotationsDerived"),
)
ANNOTATION_FIELDS = ("tts", "default")


def key(emoji):
    return emoji.replace("️", "")


def words(phrase):
    decomposed = unicodedata.normalize("NFKD", phrase)
    folded = "".join(c for c in decomposed if unicodedata.category(c) != "Mn").casefold()
    return WORD.findall(folded)


def additions(path):
    """Each word of the language's own bar emoji (`<word><tab><emoji>`, the emoji separated by
    spaces, none for a word that offers none), read as its words, or none without a file."""
    if path is None:
        return {}
    added = {}
    for line in open(path, encoding="utf-8"):
        if line.strip() and not line.startswith("#"):
            word, emoji = line.rstrip("\n").split("\t")
            added[" ".join(words(word))] = emoji.split(" ") if emoji else []
    return added


def noun_forms(path):
    """Each noun's other forms, by its lemma, read as words, from write_word_forms.py's output; none
    without a file."""
    forms = {}
    for line in open(path, encoding="utf-8") if path else []:
        form, lemma = (words(field) for field in line.rstrip("\n").split("\t"))
        if len(form) == 1 and len(lemma) == 1 and form != lemma:
            forms.setdefault(lemma[0], set()).add(form[0])
    return forms


def left_out_test(path):
    """Whether the typing data leaves a word out: a pattern of the file at `path` matches its
    letter form whole, as Tools/KeyVoxTypingModels reads them; no word without a file."""
    lines = [line for line in open(path, encoding="utf-8").read().splitlines() if line] if path else []
    if not lines:
        return lambda word: False
    pattern = re.compile("|".join(f"(?:{line})" for line in lines))

    def letter_form(word):
        decomposed = unicodedata.normalize("NFD", word.casefold())
        return "".join(c for c in decomposed if unicodedata.category(c)[0] == "L")

    return lambda word: pattern.fullmatch(letter_form(word)) is not None


def catalog_emoji(path):
    """Each emoji in the catalog and its Unicode name."""
    for line in open(path, encoding="utf-8"):
        if line.strip() and not line.startswith("@"):
            fields = line.split("\t")
            yield fields[0], fields[1]


def inherited_locales(cldr, locale):
    """The locale and every locale it inherits annotations from, the locale first."""
    path = os.path.join(cldr, "cldr-core", "supplemental", "parentLocales.json")
    parents = json.load(open(path, encoding="utf-8"))["supplemental"]["parentLocales"]["parentLocale"]
    chain = [locale]
    while True:
        current = chain[-1]
        parent = parents.get(current) or (current.rsplit("-", 1)[0] if "-" in current else None)
        if parent is None or parent == "root":
            return chain
        chain.append(parent)


def annotations(cldr, locale):
    """Each emoji's CLDR phrases in the locale, by emoji without variation selectors."""
    chain = inherited_locales(cldr, locale)
    phrases = {}
    for package, folder in ANNOTATION_SETS:
        fields = {}
        for inherited in reversed(chain):
            path = os.path.join(cldr, package, folder, inherited, "annotations.json")
            if not os.path.exists(path):
                continue
            root = json.load(open(path, encoding="utf-8"))
            for emoji, entry in next(iter(root.values()))["annotations"].items():
                fields.setdefault(key(emoji), {}).update(
                    {field: entry[field] for field in ANNOTATION_FIELDS if field in entry})
        for emoji, entry in fields.items():
            phrases.setdefault(emoji, []).extend(
                phrase for field in ANNOTATION_FIELDS for phrase in entry.get(field, []))
    if not phrases:
        sys.exit(f"CLDR has no annotations for {locale} in {cldr}")
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


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("catalog")
    parser.add_argument("cldr")
    parser.add_argument("locale")
    parser.add_argument("frequency")
    parser.add_argument("output")
    parser.add_argument("--names", action="store_true", help="also find each emoji by its Unicode name")
    parser.add_argument("--forms", help="the forms of the language's nouns, from write_word_forms.py")
    parser.add_argument("--additions", help="the language's own bar emoji")
    parser.add_argument("--leave-out", help="the patterns of the words the typing data leaves out")
    arguments = parser.parse_args()

    emoji = list(catalog_emoji(arguments.catalog))
    phrases = annotations(arguments.cldr, arguments.locale)
    ranks = frequency_ranks(arguments.frequency)
    unranked = len(ranks)
    without_emoji = {word for word, added in additions(arguments.additions).items() if not added}
    is_left_out = left_out_test(arguments.leave_out)
    forms = noun_forms(arguments.forms)
    ordered = sorted(enumerate(emoji), key=lambda item: (ranks.get(key(item[1][0]), unranked), item[0]))
    lines = []
    for _, (text, name) in ordered:
        named = [name] if arguments.names else []
        found = {word for phrase in named + phrases.get(key(text), []) for word in words(phrase)}
        found |= {form for word in found for form in forms.get(word, ())}
        found = sorted(word for word in found - without_emoji if not is_left_out(word))
        if found:
            lines.append(f"{text}\t{' '.join(found)}")
    with open(arguments.output, "w", encoding="utf-8") as output:
        output.write("\n".join(lines) + "\n")
    ranked = sum(1 for text, _ in emoji if key(text) in ranks)
    print(f"{len(lines)} of {len(emoji)} emoji searchable, {ranked} ranked", file=sys.stderr)


if __name__ == "__main__":
    main()
