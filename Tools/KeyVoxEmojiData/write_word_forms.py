"""Writes the forms of a language's nouns from Wikidata's lexemes, for the emoji search
(write_emoji_search.py `--forms`): every form a noun lexeme of the language writes, other than its
lemma, with that lemma, so a search for a plural or another form of a noun finds what the noun
finds, as the system emoji keyboard's search was seen finding "Katzen" by "Katze"
(Tools/AppleKeyboardBaseline, EmojiLanguageProbeTests).

A lexeme is the language's when its language is the item given (Q188 for German), and its lemma and
forms are those written in the representation code given ("de"). A noun is a lexeme of the lexical
category noun (Q1084).

Output, one line each, sorted:
    <form>\t<lemma>      a form and its lemma, as the lexeme writes them

Usage: python3 -I write_word_forms.py <lexemes.json.gz> <language-item> <representation-code> <output>
"""

import gzip
import json
import sys

NOUN = "Q1084"


def lexemes(path):
    """Each lexeme of the dump, a JSON array with an entity a line."""
    with gzip.open(path, "rt", encoding="utf-8") as lines:
        for line in lines:
            line = line.strip().rstrip(",")
            if line.startswith("{"):
                yield json.loads(line)


def main(dump_path, language_item, code, output_path):
    pairs = set()
    for lexeme in lexemes(dump_path):
        if lexeme.get("language") != language_item or lexeme.get("lexicalCategory") != NOUN:
            continue
        lemma = lexeme.get("lemmas", {}).get(code, {}).get("value")
        if not lemma:
            continue
        for form in lexeme.get("forms", []):
            written = form.get("representations", {}).get(code, {}).get("value")
            if written and written != lemma:
                pairs.add((written, lemma))
    with open(output_path, "w", encoding="utf-8") as output:
        output.write("".join(f"{form}\t{lemma}\n" for form, lemma in sorted(pairs)))
    print(f"{len(pairs)} forms of {len({lemma for _, lemma in pairs})} nouns", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    main(*sys.argv[1:])
