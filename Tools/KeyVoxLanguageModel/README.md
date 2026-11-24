# KeyVox Language Model

Builds the language data of each typing language: the files the predictive keyboard bundles
for English in `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/en`,
the capitalized spellings shared with dictation in `Packages/KeyVoxLinguistics/Sources/KeyVoxLinguistics/Resources`,
and the same files for German, Spanish, and French, which are built but not bundled yet:

| File | Built by | Reads |
| --- | --- | --- |
| `context_model.bin` | `extract_sentences.py`, `count_ngrams.py`, `write_context_model.py` | Every source, through `extract_sentences.py` |
| `sentence_openers.txt` | `write_word_kinds.py`, `count_sentence_openers.py`, `write_sentence_openers.py` | Every source, through `source_texts.py`, and the written sources' sentences |
| `capitalized_spellings_<language>.txt` | `write_vocabulary.py`, `write_capitalized_spellings.py` | The vocabulary, the measured spellings, and OASST2 and Tatoeba through `readers.py` |
| `unknown_word_followers.txt` | `write_vocabulary.py`, `write_unknown_word_followers.py` | The vocabulary, `count_ngrams.py`'s counts, and OASST2 and Tatoeba's sentences |
| `word_followers.txt` | `write_vocabulary.py`, `write_word_followers.py` | The vocabulary, `count_ngrams.py`'s counts, and OASST2 and Tatoeba's sentences |
| `grammar_words.txt` | `write_word_kinds.py`, `write_grammar_words.py` | `count_ngrams.py`'s vocabulary and the word kinds |

What differs between languages is in `languages.py`: each build's sources in the order they are
read, how much of each is read, how its text is split into words, its sentence-opener weights,
where its word kinds and its vocabulary come from. The sources themselves, with their versions,
licenses, and attributions, are pinned in `sources.py`.

The builders share the source readers (`readers.py`, `source_texts.py`, `names.py`) and
`normalize.py`, so a change made for one can change another's output. After changing any tool
here, rebuild every language, and for English see which bundled files change:

```bash
PYTHON=.venv/bin/python ./rebuild_bundled_data.sh <english-data-dir> --check
```

`--check` leaves the package alone and fails if a rebuilt file differs from the bundled one;
without it, the files that differ replace the bundled ones. Measure a changed context model
or sentence-opener list before shipping it, as described below.

The context model judges how likely a word is after the words before it. It holds counts
and probabilities of words, word pairs, and three-word sequences; it contains no text.

## Sources

Every source is pinned in `sources.py` with its license and required attribution, and is
credited in `THIRD_PARTY_NOTICES.md`.

| Source | Text | Languages | License |
| --- | --- | --- | --- |
| [YouTube-Commons](https://huggingface.co/datasets/PleIAs/YouTube-Commons) | Transcripts of videos published under Creative Commons Attribution, in the language the video was spoken in | en, de, es, fr | CC BY 4.0 |
| [YODAS2](https://huggingface.co/datasets/espnet/yodas2) | Captions written by hand for videos published under Creative Commons licenses | de, es, fr | CC BY 3.0 |
| [OpenAssistant OASST2](https://huggingface.co/datasets/OpenAssistant/oasst2) | Chat messages | en, de, es, fr | Apache 2.0 |
| [WildChat-4.8M](https://huggingface.co/datasets/allenai/WildChat-4.8M) | What people wrote to a chat assistant, turns of up to 50 words (longer ones are mostly pasted documents) | de, es, fr | ODC-By 1.0 |
| [Tatoeba](https://tatoeba.org/en/downloads) | Sentences | en, de, es, fr | CC BY 2.0 FR |
| [88milSMS](https://hdl.handle.net/11403/comere/cmr-88milsms/cmr-88milsms-tei-v1) | Text messages written in France in 2011 | fr | CC BY 4.0 |
| [Open Discourse](https://doi.org/10.7910/DVN/FIKIBO) | Bundestag speeches from 2000 on, the year its record took up the reformed spelling; a quarter of them | de-bundestag | CC0 1.0 |

A German, Spanish, or French build leaves out a text another source, or the same one, already
gave (compared in lowercase with its spacing evened out), reading Tatoeba, OASST2, WildChat,
88milSMS, YODAS2, and YouTube-Commons in that order; no YODAS2 video is also in
YouTube-Commons. English reads its sources without deduplicating, as its bundled data was
built. The Leipzig corpora (news and web text) are formal writing and are not read.

## Building

```bash
python3.14 -m venv .venv
.venv/bin/pip install -r requirements.txt
PYTHON=.venv/bin/python ./build_language_data.sh <language> <data-dir> <output-dir>
```

`<language>` is `en`, `de`, `de-bundestag` (German with the Bundestag speeches), `es`, or `fr`.
Give each build its own data directory, with the shared sources linked in as
`<data-dir>/sources`, since a build writes its sentences and counts there. The script runs, in
order:

```bash
.venv/bin/python download_sources.py --language <language> <data-dir>
.venv/bin/python extract_sentences.py --language <language> <data-dir>
.venv/bin/python count_ngrams.py <data-dir>
.venv/bin/python write_context_model.py <data-dir> <output-dir>/context_model.bin
.venv/bin/python write_word_kinds.py --language <language> <data-dir>
.venv/bin/python count_sentence_openers.py --language <language> <data-dir>
.venv/bin/python write_sentence_openers.py --language <language> <data-dir> --output <output-dir>/sentence_openers.txt
.venv/bin/python write_vocabulary.py --language <language> <data-dir> <output-dir>/vocabulary.txt <output-dir>/common_vocabulary.txt
.venv/bin/python write_capitalized_spellings.py --language <language> <data-dir> <output-dir>/vocabulary.txt <output-dir>/common_vocabulary.txt <output-dir>/capitalized_spellings_<identifier>.txt
.venv/bin/python write_unknown_word_followers.py <data-dir> <output-dir>/vocabulary.txt <output-dir>/unknown_word_followers.txt
.venv/bin/python write_word_followers.py <data-dir> <output-dir>/vocabulary.txt <output-dir>/word_followers.txt
.venv/bin/python write_grammar_words.py <data-dir> <output-dir>/grammar_words.txt
```

`<identifier>` is the build's typing language (`de` for `de-bundestag`). The tools need Python
3.14 or later (for `compression.zstd`), Xcode's `swiftc` for Apple's tagger, and for Spanish the
`hunspell` command (`brew install hunspell`). Counting French's 394 million words took 10.5 GB of
memory at its peak; a build's data directory, without its sources, takes 2 to 6 GB.

`rebuild_bundled_data.sh` builds English into `<english-data-dir>/bundled` this way and compares
the files with the package's. Measure a new model with `Tools/KeyVoxTypingHarness` against the
bundled one before replacing it.

### Built data

The builds of November 24, 2026. Every context model fills the default limits (107,000 words,
800,000 pairs, 600,000 sequences), so each is 14,963,028 bytes, as English's is.

| Build | Words of text | Vocabulary | Capitalized spellings | Grammar words |
| --- | --- | --- | --- | --- |
| en | 528,779,799 | 109,172 (SCOWL size 60) | 18,144 | 152 |
| de | 118,350,701 | 209,470 | 146,689 | 220 |
| de-bundestag | 138,467,367 | 209,470 | 146,689 | 222 |
| es | 281,865,056 | 223,482 | 2,955 | 158 |
| fr | 393,698,831 | 160,541 | 19,021 | 195 |

Texts, sentences, and words each source gave after deduplication:

| Build | Source | Texts | Sentences | Words |
| --- | --- | --- | --- | --- |
| de | Tatoeba | 627,288 | 666,250 | 4,813,532 |
| de | OASST2 | 6,086 | 36,718 | 412,098 |
| de | WildChat | 29,581 | 52,602 | 386,654 |
| de | YODAS2 | 19,250 | 1,353,933 | 23,715,021 |
| de | YouTube-Commons | 41,435 | 175,889 | 89,023,396 |
| de-bundestag | Open Discourse (besides de's) | 69,394 | 1,314,524 | 20,116,666 |
| es | Tatoeba | 378,560 | 395,561 | 2,695,083 |
| es | OASST2 | 27,962 | 200,168 | 2,674,964 |
| es | WildChat | 83,713 | 142,155 | 1,336,910 |
| es | YODAS2 | 31,807 | 829,271 | 31,351,845 |
| es | YouTube-Commons | 154,232 | 305,293 | 243,806,254 |
| fr | Tatoeba | 643,367 | 663,079 | 4,746,195 |
| fr | OASST2 | 3,779 | 17,590 | 249,029 |
| fr | WildChat | 84,681 | 137,789 | 1,196,874 |
| fr | 88milSMS | 85,093 | 148,140 | 1,125,870 |
| fr | YODAS2 | 21,672 | 861,262 | 24,016,720 |
| fr | YouTube-Commons | 150,870 | 408,441 | 362,364,143 |

Tatoeba's counts are after its sentences that mention a name are left out.

## Preparing the multilingual sources

The German, Spanish, and French sources without a download address in `sources.py` are prepared
once from their upstream sources; `download_sources.py` checks each against its pinned SHA-256.
Under `<data-dir>/sources`:

- `youtube-commons/multilingual/<code>_original_transcripts.jsonl.zst`: every file of
  YouTube-Commons at the pinned revision, each checked against the dataset's SHA-256, keeping the
  rows whose `original_language` (the language spoken) and `transcription_language` (the
  language of the row's text) are both the language; the other rows are machine translations.
  One JSON line per video (`video_id`, `channel`, `date`, `language`, `word_count`, `text`), a
  repeated video ID kept once.
- `yodas2/<code>_manual_captions.jsonl.zst`: the text files of YODAS2's shard `<code>000`, whose
  leading 0 marks captions written by hand (1 marks automatic captions), each checked against the
  dataset's SHA-256 or blob ID, packed unchanged as one JSON line per video (`audio_id`, `text`:
  each caption by its utterance ID).
- `wildchat/<code>_user_turns.jsonl`: every turn of WildChat-4.8M with role `user` and a detected
  `language` of German, Spanish, or French, each shard checked against the dataset's SHA-256. One
  JSON line per turn (`conversation_hash`, `turn_identifier`, `turn_index`, `language`,
  `word_count` split at whitespace, `text`).
- `open-discourse/de_bundestag_speeches.jsonl.zst`: `speeches.feather` of Open Discourse
  version 4.0 (MD5 `2b0dd85a8f5ae8c8c071d9b2bef2bbc3`), one JSON line per speech with text (`id`,
  `date`, `text`).
- `aosp-latinime/<code>_wordlist.combined.gz`: LatinIME's `dictionaries/<code>_wordlist.combined.gz`
  at the pinned commit, which googlesource serves base64-encoded with `?format=TEXT`, decoded.
- `wikidata-lexemes/<code>_forms.tsv`: every form of the lexemes in German (Q188), Spanish
  (Q1321), or French (Q150) in the Wikidata lexemes dump of November 18, 2026: a header row, then
  a row per form with its form, lemma, lexical category, and grammatical features.

## Text in each language

`normalize.py` reads every language the same way: words are runs of Unicode letters with inner
apostrophes, so German "ß" and accented letters are letters, accents are kept, and a French elided
word stays one word with what follows it ("l'équipe", "qu'il"), as LatinIME's word lists write
them. A language's text rules in `languages.py` add, for German, Spanish, and French, composing
letters with their accents (NFC); the marks that open a sentence where they stand, Spanish "¿" and
"¡", which are not word characters; and the language's quotation marks (from CLDR), where a
quotation can begin.

## Vocabulary

`write_vocabulary.py` writes a language's vocabulary, its words with their capitals, one per line:
the dictionary's word list for the capitalized spellings and the follower lists, as SCOWL's size-60
list is English's. For German, Spanish, and French it is built from:

- the language's [AOSP LatinIME](https://android.googlesource.com/platform/packages/inputmethods/LatinIME/)
  word list, the words Android's keyboard offers (Apache 2.0), without the entries it marks as no
  word, and keeping only single words as the keyboard reads them (so not "E-Mail" or the French
  hyphenated words);
- [Wikidata Lexemes](https://www.wikidata.org/wiki/Wikidata:Lexicographical_data) forms (CC0), in
  every language, and for French also the
  [Grammalecte](https://grammalecte.net/) lexicon's inflected forms (MPL 2.0).

A word the lexicons know is kept in every spelling they write it in, and in no other
(`vocabulary/spellings.py`): German "Leben" and "leben" are both kept, a German noun the word list
writes in lowercase takes its capital, and a word the list capitalizes only for starting a sentence
loses it. A word the lexicons do not know, such as a name or a compound, keeps the word list's
spellings. Such a word must then pass the language's spelling check, where it has one: a
lowercase spelling is kept only if the check accepts it, and a spelling with capitals is written
in lowercase if the check accepts that, as its capital was only the sentence's, and is otherwise
kept as a name. The check is, for Spanish, the [RLA-ES](https://github.com/sbosio/rla-es) generic
Spanish Hunspell dictionary (`vocabulary/hunspell_check.py`), and for French, the lexicons, an
elided word checked part by part (`vocabulary/lexicon_check.py`). German has no spelling check. The vocabulary's
common part, which SCOWL's size 50 is for English, is the spellings the word list itself writes:
a spelling only the lexicons add is a rare sense, and does not keep the word's usual spelling with
a capital from the capitalized spellings.

| Language | Word list | Vocabulary | Left out by the spelling check |
| --- | --- | --- | --- |
| de | 205,887 words | 209,470 spellings | (no check) |
| es | 236,193 words | 223,482 spellings | 12,825 words |
| fr | 163,631 single words | 160,541 spellings | 4,552 words |

Besides foreign words, RLA-ES's generic dictionary rejects some Spanish forms in use, such as
"ayudándole", "deshizo", and "recalculó"; such a form stays in the vocabulary only where Wikidata
Lexemes list it.

License obligations of the vocabulary:

- AOSP LatinIME word lists, Apache 2.0: the vocabulary is a modified version of the word list;
  shipping it, or a file built from it, needs the Apache 2.0 license and the AOSP notice with it
  (`THIRD_PARTY_NOTICES.md`), and the modification stated, as here.
- Wikidata Lexemes, CC0: no conditions.
- Grammalecte, MPL 2.0: the French vocabulary holds spellings taken from the lexicon, so it, and a
  file made from it that ships, are covered by the MPL 2.0: they must carry its notice and be
  available in source form under it, which the repository and these tools provide.
- RLA-ES, under the MPL 1.1 or later (of its three license options): only its accepting or
  rejecting a spelling is used, and none of its files are copied or shipped; it is credited all
  the same.

## Word kinds

`write_word_kinds.py` writes `<data-dir>/word_kinds.tsv`, each word's most common lexical class,
which the sentence openers and grammar words read. English, German, and French use Apple's
NaturalLanguage tagger over the Tatoeba and OASST2 sentences (`tag_word_kinds.swift`), German and
French with the tagger's language set, English in the language the tagger detects, as its bundled
data was built. The tagger gives a joined word its first part's class; French words joined to an
elided article or preposition ("l'homme", "d'argent") take the class of the word they are joined
to instead, so they are not counted as grammar words.

The tagger's answers can change: the bundled English sentence openers were built with word kinds
tagged on October 8, 2026, and tagging the same sentences on macOS 27.2 classes 1,477 of the
114,496 words differently, which adds one line to a rebuilt `sentence_openers.txt`; the other five
English files rebuild identically.

Set to Spanish, Apple's tagger on macOS 27.2 marks every word as OtherWord (all 4,361 words of
3,000 Tatoeba sentences), so Spanish takes its word kinds from the
[UD Spanish AnCora](https://github.com/UniversalDependencies/UD_Spanish-AnCora) treebank (CC BY 4.0)
with `write_treebank_word_kinds.py`, in the same classes; a word the treebank splits ("del",
"dámelo") takes its first part's class, as Apple's tagger joins contractions.

## Sentence openers

`sentence_openers.txt` holds the words the suggestion bar offers where a sentence begins.
Each language's source weights are in `languages.py`: English's were tuned against Apple's English
suggestion bars (youtube-commons 0, oasst2 0.3, tatoeba 10). German, Spanish, and French give the
same weights by kind of source, speech 0, chat and text messages 0.3, and Tatoeba 10, with no
captures of Apple's bars in those languages to tune them against yet.

## Words spelled with capitals

`capitalized_spellings_<language>.txt` holds the words the keyboard and dictation write with their
capitals, such as "Jennifer" or "iPhone", and in German its nouns. English's is bundled in
`Packages/KeyVoxLinguistics`. It is built from the vocabulary and the written sources.

Spellings with capitals in a row are left out, as the system keyboard leaves acronyms such
as "nasa" lowercase, except those listed in `measured_spellings.txt`, which the English system
keyboard was measured writing as spelled (`Tools/AppleKeyboardBaseline`).

Tatoeba's sentences that mention a name are left out of the language data (`source_texts.py`), as
Tatoeba reuses a few invented characters. A name is a word Tatoeba nearly always capitalizes in the
middle of a sentence (`names.py`), other than the language's always-capitalized words in its
`language.json` and the words its Wikidata lexemes write with a capital without being proper nouns,
such as German nouns.

## Words after an unknown word

`unknown_word_followers.txt` holds the words the suggestion bar offers right after a word the
dictionary does not know, such as a name or a word the keyboard learned, by the word before
it. It is built from `count_ngrams.py`'s counts and the written sentences. The builders share
`followers.py`, which takes off the sentence starts transcripts count as followers.

## Words after a common word

`word_followers.txt` holds the words that most often follow each common word, which the
suggestion bar adds to the dictionary's few next words while the user picks its words in a row.

## Grammar words

`grammar_words.txt` holds the determiners, pronouns, prepositions, conjunctions, and particles
among the most common words, which the suggestion bar lets come back while the user picks its
words in a row.
