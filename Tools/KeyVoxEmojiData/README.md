# KeyVox Emoji Data

Writes the emoji data `Packages/KeyVoxEmoji` bundles in `Sources/KeyVoxEmoji/EmojiData`: the
catalog and the Frequently Used starters, shared by every language, and, for each typing
language, in a folder named by its identifier, the words that find each emoji in the emoji search
and the emoji the suggestion bar offers for a word.

| File | What it is | Written by |
| --- | --- | --- |
| `emoji_catalog.txt`, `emoji_starters.txt` | The emoji the system emoji keyboard shows, in its categories and order, with each emoji's Unicode name and skin-tone variants, and the emoji its Frequently Used section starts with | `write_emoji_catalog.py` |
| `<language>/emoji_search.txt` | Each emoji's words in the language, in the search's order | `write_emoji_search.py`, with `write_word_forms.py`'s noun forms |
| `<language>/emoji_predictions.txt` | Each word's suggestion-bar emoji, at most three | `write_emoji_predictions.py` |

The package reads a typing language's folder by the keyboard's identifier for the language; a
regional variant without a folder of its own reads its language's, so French (Canada), `fr-CA`,
reads `fr`. Each script's docstring states its rules.

## Sources

| Source | Used for | Pinned to | License |
| --- | --- | --- | --- |
| [Unicode emoji-test.txt](https://unicode.org/Public/emoji/latest/emoji-test.txt) | The catalog's emoji, names, and skin-tone variants | Emoji 18.0 | Unicode License v3 |
| [CLDR JSON](https://github.com/unicode-org/cldr-json) | Each language's emoji names and keywords, `cldr-annotations-full` and `cldr-annotations-derived-full`, and `cldr-core`'s `parentLocales.json` | Release 48.2.3, `cldr-48.2.3-json-full.zip`, SHA-256 `d580253a99baea84f7fc361b91a73023f2268331a1671244cf8180b4e008e0e4` | Unicode License v3 |
| [Unicode emoji frequency](https://www.unicode.org/emoji/frequency.html) | The search's order | The page as fetched on November 28, 2026, SHA-256 `84d1c48a5d2eca87d7b41ce47b90d9158f86ce5b05d5ea6bc6943edf3876129b` | Unicode License v3 |
| [Wikidata Lexemes](https://dumps.wikimedia.org/wikidatawiki/entities/20261118/wikidata-20261118-lexemes.json.gz) | The forms of German, Spanish, and French nouns | The dump of November 18, 2026, SHA-256 `90403d7d71f950d954b5639eb796b67fef8bc4f31bd68feba1edbbb1a3eee822` | CC0 1.0 |

The suggestion bar's data also reads each language's word kinds and vocabulary, as
`Tools/KeyVoxLanguageModel` builds them (`word_kinds.tsv`, `vocabulary.txt` in its data
directory), and the patterns of the words its typing data leaves out, as
`Tools/KeyVoxTypingModels/offensive_words.py` writes them (`work/offensive_words.txt`), so a word
the dictionary leaves out finds no emoji and offers none.

## Building

Every script runs on the system Python, isolated (`python3 -I`), without packages. With `<cldr>`
the folder `cldr-48.2.3-json-full.zip` unzips to, `<data>` the package's `EmojiData`, and
`<language-build>`, `<typing-data>` the language's data directories of the two tools above:

```bash
# English, with Unicode's English names, KeyVox's own bar emoji, and English plurals.
python3 -I write_emoji_search.py <data>/emoji_catalog.txt <cldr> en frequency.html <data>/en/emoji_search.txt \
  --names --additions emoji_prediction_additions.txt --leave-out <typing-data>/work/offensive_words.txt
python3 -I write_emoji_predictions.py <data>/en/emoji_search.txt <data>/emoji_catalog.txt \
  <language-build>/word_kinds.tsv <language-build>/vocabulary.txt <data>/en/emoji_predictions.txt \
  --additions emoji_prediction_additions.txt --leave-out <typing-data>/work/offensive_words.txt \
  --plural-endings ies:y es: s:

# Another language: its nouns' forms, then its search and bar data. German is Q188 and "de",
# Spanish Q1321 and "es", French Q150 and "fr"; Latin American Spanish, es-419, reads Spanish's
# forms, word kinds, vocabulary, and typing data with its own CLDR locale.
python3 -I write_word_forms.py wikidata-20261118-lexemes.json.gz Q188 de de_noun_forms.tsv
python3 -I write_emoji_search.py <data>/emoji_catalog.txt <cldr> de frequency.html <data>/de/emoji_search.txt \
  --forms de_noun_forms.tsv --leave-out <typing-data>/work/offensive_words.txt
python3 -I write_emoji_predictions.py <data>/de/emoji_search.txt <data>/emoji_catalog.txt \
  <language-build>/word_kinds.tsv <language-build>/vocabulary.txt <data>/de/emoji_predictions.txt \
  --leave-out <typing-data>/work/offensive_words.txt
```

English's search data rebuilds byte for byte with these commands. Its bar data was written
before English's word kinds were kept as a snapshot (`Tools/KeyVoxLanguageModel`, "Word kinds"),
which it needs to rebuild.

## Measured on the system keyboard

`Tools/AppleKeyboardBaseline`'s `EmojiLanguageProbeTests` watched the iOS 27.2 simulator's emoji
search with each language's keyboard. The search finds emoji by the words of the keyboard's
language, whatever the system language: an English word finds nothing on another language's
keyboard unless that language's own data has it, so each language's data holds its own words alone,
with no English names. It reads words without case or accents, finds a word still being typed, and
finds a noun by its other forms ("Katzen" what "Katze" finds, "perros" what "perro" finds), which
CLDR's keywords lack, so the search data adds them from Wikidata's lexemes.

The regional variants were measured against both their own and their language's CLDR data, by how
often the system's first result is among the first eight this data finds, over the same 106
Spanish and 90 French words. The Spanish (Latin America) keyboard's results follow CLDR's `es-419`
annotations (66 against 54 with Spanish's), and Spanish (Mexico)'s are the same as Latin
America's, so `es-419` has its own folder. The French (Canada) keyboard's follow French's (59 against
50 with CLDR's `fr-CA`), so `fr-CA` reads `fr`. The system's suggestion bar offered no emoji on the
simulator in any language, English included, so the bar keeps English's rule in every language.
