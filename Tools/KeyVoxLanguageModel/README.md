# KeyVox Language Model

Builds the language data of each typing language: the files the predictive keyboard bundles
for English in `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/en`,
the capitalized spellings shared with dictation in `Packages/KeyVoxLinguistics/Sources/KeyVoxLinguistics/Resources`,
and the same files for German, Spanish, and French, each bundled in its own `PredictiveData/<language>`
but for the swipe vocabulary, which needs the language's swipe typing; Latin American Spanish
(`PredictiveData/es-419`) uses Spanish's ("Latin American Spanish"):

| File | Built by | Reads |
| --- | --- | --- |
| `context_model.bin` | `extract_sentences.py`, `count_ngrams.py`, `write_context_model.py` | Every source, through `extract_sentences.py` |
| `sentence_openers.txt` | `write_word_kinds.py`, `count_sentence_openers.py`, `write_sentence_openers.py` | Every source, through `source_texts.py`, and the written sources' sentences |
| `capitalized_spellings_<language>.txt` | `write_vocabulary.py`, `write_capitalized_spellings.py` | The vocabulary, the measured spellings, and OASST2 and Tatoeba through `readers.py` |
| `unknown_word_followers.txt` | `write_vocabulary.py`, `write_unknown_word_followers.py` | The vocabulary, `count_ngrams.py`'s counts, and OASST2 and Tatoeba's sentences |
| `word_followers.txt` | `write_vocabulary.py`, `write_word_followers.py` | The vocabulary, `count_ngrams.py`'s counts, and OASST2 and Tatoeba's sentences |
| `grammar_words.txt` | `write_word_kinds.py`, `write_grammar_words.py` | `count_ngrams.py`'s vocabulary and the word kinds |
| `swipe_vocabulary.txt` | `count_swipe_words.py`, `count_swiped_words.py`, `write_swipe_vocabulary.py` | Every source, through `source_texts.py`, the words swipe.futo.org's training split had people swipe, the dictionary's words and probabilities, and SCOWL's size 80 in every spelling |

The swipe vocabulary is built only for a language whose dictionary and letter layout the package
has, and is bundled with a swipe model, so for English alone today (see "Swipe vocabulary").

English's dictionary, rankers, and accent overlay, bundled beside these files, are built by
`Tools/KeyVoxTypingModels`, which builds German's, Spanish's, and French's from these builds'
vocabulary, counts, and sentences too (its "Other typing languages").

What differs between languages is in `languages.py`: each build's sources in the order they are
read, how much of each is read, how its text is split into words, its sentence-opener weights,
where its word kinds and its vocabulary come from. The sources themselves, with their versions,
licenses, and attributions, are pinned in `sources.py`.

The builders share the source readers (`readers.py`, `source_texts.py`, `names.py`) and
`normalize.py`, so a change made for one can change another's output. After changing any tool
here, rebuild every language, and for English see which bundled files change:

```bash
PYTHON=.venv/bin/python ./rebuild_bundled_data.sh <english-data-dir> <typing-data-dir> --check
```

`<typing-data-dir>` is a `Tools/KeyVoxTypingModels` data directory after its build, whose
`work/dictionary_unigrams.tsv` holds the words and probabilities the bundled dictionary is
compiled from; the swipe vocabulary reads them.

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
| [swipe.futo.org](https://huggingface.co/datasets/futo-org/swipe.futo.org) | The words of the sentences people swiped in its training split, read by the swipe vocabulary alone (see "Swipe vocabulary"); its validation and test splits measure the swipe decoder and are never read | en | MIT |

A German, Spanish, or French build leaves out a text another source, or the same one, already
gave (compared in lowercase with its spacing evened out), reading Tatoeba, OASST2, WildChat,
88milSMS, YODAS2, and YouTube-Commons in that order; no YODAS2 video is also in
YouTube-Commons. English reads its sources without deduplicating, as its bundled data was
built. The Leipzig corpora (news and web text) are formal writing and are not read.

## Building

```bash
python3.14 -m venv .venv
.venv/bin/pip install -r requirements.txt
PYTHON=.venv/bin/python ./build_language_data.sh <language> <data-dir> <output-dir> [dictionary-words]
```

`<language>` is `en`, `de`, `de-bundestag` (German with the Bundestag speeches), `es`, or `fr`.
Give each build its own data directory, with the shared sources linked in as
`<data-dir>/sources`, since a build writes its sentences and counts there. The script runs these
steps:

```bash
.venv/bin/python download_sources.py --language <language> <data-dir>
.venv/bin/python extract_sentences.py --language <language> <data-dir>
.venv/bin/python count_ngrams.py --language <language> <data-dir>
.venv/bin/python write_context_model.py --language <language> <data-dir> <output-dir>/context_model.bin
.venv/bin/python write_word_kinds.py --language <language> <data-dir>
.venv/bin/python count_sentence_openers.py --language <language> <data-dir>
.venv/bin/python write_sentence_openers.py --language <language> <data-dir> --output <output-dir>/sentence_openers.txt
.venv/bin/python write_vocabulary.py --language <language> <data-dir> <output-dir>/vocabulary.txt <output-dir>/common_vocabulary.txt
.venv/bin/python write_capitalized_spellings.py --language <language> <data-dir> <output-dir>/vocabulary.txt <output-dir>/common_vocabulary.txt <output-dir>/capitalized_spellings_<identifier>.txt
.venv/bin/python write_unknown_word_followers.py <data-dir> <output-dir>/vocabulary.txt <output-dir>/unknown_word_followers.txt
.venv/bin/python write_word_followers.py <data-dir> <output-dir>/vocabulary.txt <output-dir>/word_followers.txt
.venv/bin/python write_grammar_words.py <data-dir> <output-dir>/grammar_words.txt
```

Given `[dictionary-words]`, the language's dictionary words and probabilities (a word, a tab,
and a probability a line), it then builds the swipe vocabulary, leaving out the words that
`[left-out-words]`, a regular expression a line, matches (`Tools/KeyVoxTypingModels` writes
English's as `work/offensive_words.txt`):

```bash
.venv/bin/python count_swipe_words.py --language <language> <data-dir>
.venv/bin/python count_swiped_words.py --language <language> <data-dir>
./scowl_words.sh 80 <output-dir>/spelling_list.txt A,B,Z,C,D
.venv/bin/python write_swipe_vocabulary.py --language <language> <data-dir> <dictionary-words> <output-dir>/spelling_list.txt <output-dir>/swipe_vocabulary.txt --leave-out <left-out-words>
```

Steps that read none of each other's files run side by side: after `download_sources.py`, the
swipe vocabulary's counts (`count_swipe_words.py`, `count_swiped_words.py`, the spelling list) run
beside `extract_sentences.py`; then `count_ngrams.py` beside the sentence openers
(`write_word_kinds.py`, `count_sentence_openers.py`, `write_sentence_openers.py`), and once the
counts are written, `write_context_model.py` beside the vocabulary and the words spelled with
capitals (`write_vocabulary.py`, `write_capitalized_spellings.py`), since a vocabulary may add the
words the counts show its word list lacks (see "Vocabulary"); then the two follower lists and the
grammar words, once the counts, the vocabulary, and the word kinds are written; and last
`write_swipe_vocabulary.py`. Each step reads the same files it would read run alone, so the files
are the same; the memory of the steps running together adds up. Each step runs in a process group
of its own, and when one fails the build stops every step still running, with every program they
started, and fails at once, in the bash 3.2 macOS ships as in later ones.

`<identifier>` is the build's typing language (`de` for `de-bundestag`). The tools need Python
3.14 or later (for `compression.zstd`), Xcode's `swiftc` for Apple's tagger, and for Spanish the
`hunspell` command (`brew install hunspell`). Counting French's 394 million words took 10.5 GB of
memory at its peak; a build's data directory, without its sources, takes 2 to 6 GB.

`rebuild_bundled_data.sh` builds English into `<english-data-dir>/bundled` this way and compares
the files with the package's. Measure a new model with `Tools/KeyVoxTypingHarness` against the
bundled one before replacing it.

### Built data

The builds of November 24, 2026, German's of November 27, rebuilt with its `language.json`,
whose apostrophe and ordinal periods (see "Text in each language") leave 65,402 fewer sentences
than November 24's and 198 fewer words, and with the written lexicon words its vocabulary adds (see
"Vocabulary") and contractions, and Spanish's of November 27, with its `language.json`, its tuned
opener weights, its count weights, and its context model sizes (see "Context model"): its words of
text below are as counted once each. German's and Spanish's bundled files are these builds'.
Every other context model fills the default limits (107,000 words, 800,000 pairs, 600,000
sequences), so each is 14,963,028 bytes, as English's is; Spanish's holds 240,000 words, 2,000,000
pairs, and 2,000,000 sequences in 42,160,028 bytes.
Rebuilt on November 27, 2026 from the same sources, with French's `language.json` in the
package, French gave the same bytes in every file; those are the bundled French files.

| Build | Words of text | Vocabulary | Capitalized spellings | Grammar words |
| --- | --- | --- | --- | --- |
| en | 528,779,799 | 109,172 (SCOWL size 60) | 18,144 | 152 |
| de | 118,350,503 | 222,263 | 152,972 | 220 |
| de-bundestag | 138,467,367 | 209,470 | 146,689 | 222 |
| es | 281,865,056 | 236,307 | 2,955 | 156 |
| fr | 393,698,831 | 165,093 | 19,021 | 195 |

Texts, sentences, and words each source gave after deduplication:

| Build | Source | Texts | Sentences | Words |
| --- | --- | --- | --- | --- |
| de | Tatoeba | 627,288 | 665,043 | 4,813,527 |
| de | OASST2 | 6,086 | 36,146 | 412,098 |
| de | WildChat | 29,581 | 51,497 | 386,653 |
| de | YODAS2 | 19,250 | 1,314,138 | 23,714,836 |
| de | YouTube-Commons | 41,435 | 153,166 | 89,023,389 |
| de-bundestag | Open Discourse (besides de's) | 69,394 | 1,314,524 | 20,116,666 |
| es | Tatoeba | 378,560 | 391,930 | 2,695,083 |
| es | OASST2 | 27,962 | 198,026 | 2,674,964 |
| es | WildChat | 83,713 | 140,725 | 1,336,910 |
| es | YODAS2 | 31,807 | 789,767 | 31,351,845 |
| es | YouTube-Commons | 154,232 | 301,581 | 243,806,254 |
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
- `word-kinds/<identifier>_word_kinds.tsv`: the word-kind snapshots described under "Word kinds",
  and `spelling-snapshots/es_hunspell_accepted.txt`, the Hunspell snapshot described under
  "Vocabulary", kept from the builds that made them; they have no upstream to download from.
- `wikidata-lexemes/<code>_forms.tsv`: every form of the lexemes in German (Q188), Spanish
  (Q1321), or French (Q150) in the Wikidata lexemes dump of November 18, 2026: a header row, then
  a row per form with its form, lemma, lexical category, and grammatical features.

## Text in each language

`normalize.py` reads every language the same way: words are runs of Unicode letters with inner
apostrophes, so German "ß" and accented letters are letters, accents are kept, and a French elided
word stays one word with what follows it ("l'équipe", "qu'il"), as LatinIME's word lists write
them. A language's text rules in `languages.py` add, for German, Spanish, and French, composing
letters with their accents (NFC), and the language's quotation marks (from CLDR), where a
quotation can begin. Sentences end only at the shared ending marks and line breaks: Spanish "¿" and
"¡" are not word characters and neither end nor start a sentence, so a question after a comma stays
in its sentence, and one after a period already starts its own.

Two rules come from the language's `language.json` in the package, as the keyboard reads them
(`TypingTextRules`), and `Language` fills them in from it (`languages.py`): the language's closing
single quotation mark is its keyboard's apostrophe after a letter, so where that is no apostrophe
already it is read as one between two letters (German "geht‘s" is "geht's", as Apple's German
keyboard types it); and with `ordinalPeriods`, a period right after a digit writes an ordinal
number and ends no sentence ("Am 3. Juli" is one sentence), as on the keyboard. German has both;
English, Spanish, and French have neither, so their text is read as before.
`python -m unittest test_normalize` checks both rules and that English is unchanged.

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
spellings. The language's spelling check, where it has one, is then asked about each such word
spelled with capitals, in lowercase: the word is written in lowercase if the check accepts that,
as its capital was only the sentence's, and is otherwise kept as a name. The check never leaves a
word out: the word list is what Android offers the language's typists, loanwords and forms the
check lacks included. French's check is the lexicons, an elided word checked part by part
(`vocabulary/lexicon_check.py`); Spanish's is the [RLA-ES](https://github.com/sbosio/rla-es)
generic Spanish Hunspell dictionary with its affix rules (`hunspell -d` with its `.aff` and
`.dic`, `vocabulary/hunspell_check.py`). German has no spelling check. The vocabulary's
common part, which SCOWL's size 50 is for English, is the spellings the word list itself writes:
a spelling only the lexicons add is a rare sense, and does not keep the word's usual spelling with
a capital from the capitalized spellings.

AOSP's German word list leaves out common words: almost every lowercase word beginning with an
umlaut ("überhaupt", "ändern", "öffnen", "öffentlich"; 969 of its 209,470 spellings began with
"ä", "ö", or "ü", against 4,995 with "u"), and common forms such as "nimmst", "solltet", and
"sowas", which German's sentences write hundreds or thousands of times. So German's vocabulary
first adds the Wikidata Lexemes words the word list lacks that its sentences, as `count_ngrams.py`
counted them, write at least as often as the median word-list word they write at all, 17 times
(`adds_written_lexicon_words` in `languages.py`, `vocabulary/written_lexicon_words.py`): 12,352
words, in every spelling the lexicons write them in, as common words. A lexicon form the sentences
write less often, such as a rare inflection, stays out. They are 1,437 of the vocabulary's spellings
beginning with an umlaut, and add 6,283 nouns to the capitalized spellings; no capitalized spelling
is lost. `python -m unittest test_written_lexicon_words` checks the rule.

The list holds no contraction either, such as "geht's" or "gibt's", which German writes thousands of
times and Apple's German keyboard restores when the apostrophe is left out ("gehts" gives "geht’s",
measured on the iOS 27.2 simulator in `apple-languages/runs/sim-contractions-de_DE` of KeyVox's
language data). So German's vocabulary also adds the contractions its carefully written sources,
Tatoeba and OASST2 (`WRITTEN_SOURCES`), write at least as often as the median word-list word they
write, 3 times, whose part before the apostrophe is a word of the list
(`adds_written_contractions`, `vocabulary/written_contractions.py`): 115, from "geht's" (233 times)
and "gibt's" (171) to "stimmt's" and "du's". The speech transcripts are left out, as they write
other languages' contractions ("don't", "c'est") almost as often; the written sources still bring
a few ("don't", 15 times). `python -m unittest test_written_contractions` checks the rule.

| Language | Word list | Vocabulary | Written in lowercase by the spelling check |
| --- | --- | --- | --- |
| de | 205,887 words, 12,352 written lexicon words, and 115 written contractions | 222,263 spellings | (no check) |
| es | 236,193 words | 236,307 spellings | 2,146 words |
| fr | 163,631 single words | 165,093 spellings | 812 words |

RLA-ES's affix rules reject 12,825 of the Spanish word list's lowercase words that Wikidata
Lexemes do not list, most of them Spanish forms in use: of 40 drawn at random, 36 were Spanish
words, among them gerunds and infinitives with enclitic pronouns ("manteniéndolos",
"desestabilizarla", "arrojándole"), and 4 were not ("broadcast", "ione", "comintern", and "aunan"
for "aúnan"). Leaving them out would leave out "ayudándole" with them, so RLA-ES keeps every word.
Of the word list's capitalized words that Wikidata does not list, 3,462 stay capitalized, as RLA-ES
rejects them in lowercase; they are mostly names and acronyms.

Which words Hunspell accepts can change with the installed hunspell, so the words RLA-ES accepted
are kept as a snapshot, `<data-dir>/sources/spelling-snapshots/es_hunspell_accepted.txt` (2,146
words, one per line in code-point order), with its SHA-256 and the hunspell version that made it
recorded in `languages.py` (`spelling_snapshot_sha256`, `spelling_snapshot_hunspell`):
`d83ae2e0376e714d20428706c11e75dc54873a780a1e3964feba150247d802b1`, hunspell 1.7.6. A build reads
the snapshot after checking its hash, and fails if it does not match; without the snapshot it runs
hunspell afresh and fails unless the words accepted hash to the recorded snapshot's
(`vocabulary/hunspell_snapshot.py`). To change it on purpose, run `write_vocabulary.py` with
`--write-spelling-snapshot`, check the result, and record the hash and version it prints.

The French lexicons do not list 4,552 of the French word list's lowercase words. Of 50 drawn at
random, they are French words ("latrine", "surdéveloppé", "réouvrit", "royannaise"), loanwords
French typists use ("bike", "pharma", "boot"), other English words ("shearing", "crow"), and
names the word list writes in lowercase ("eunice", "larue"); all are kept.

License obligations of the vocabulary:

- AOSP LatinIME word lists, Apache 2.0: the vocabulary is a modified version of the word list;
  shipping it, or a file built from it, needs the Apache 2.0 license and the AOSP notice with it
  (`THIRD_PARTY_NOTICES.md`), and the modification stated, as here.
- Wikidata Lexemes, CC0: no conditions.
- Grammalecte, MPL 2.0: the French vocabulary holds spellings taken from the lexicon, so it, and a
  file made from it that ships, are covered by the MPL 2.0: they must carry its notice and be
  available in source form under it, which the repository and these tools provide.
- RLA-ES, under the MPL 1.1 or later (of its three license options): only its accepting or
  rejecting a spelling is used, to decide capitals, and none of its files are copied or shipped;
  it is credited all the same.

## Word kinds

`write_word_kinds.py` writes `<data-dir>/word_kinds.tsv`, each word's most common lexical class,
which the sentence openers and grammar words read. English, German, and French use Apple's
NaturalLanguage tagger over the Tatoeba and OASST2 sentences (`tag_word_kinds.swift`), German and
French with the tagger's language set, English in the language the tagger detects, as its bundled
data was built. The tagger gives a joined word its first part's class; French words joined to an
elided article or preposition ("l'homme", "d'argent") take the class of the word they are joined
to instead, so they are not counted as grammar words.

The tagger's answers can change from one system to another: the bundled English sentence openers were
built with word kinds tagged on October 8, 2026, and tagging the same sentences on macOS 27.2
classes 1,477 of the 114,496 words differently. So the word kinds each language's data was built
with are kept as a snapshot, `<data-dir>/sources/word-kinds/<identifier>_word_kinds.tsv`, with its
SHA-256 recorded in `languages.py` (`AppleTaggerKinds.snapshot_sha256`):

| Language | Snapshot | SHA-256 |
| --- | --- | --- |
| en | Tagged October 8, 2026 | `a46077a3b030c478fe39dc19d9b96a32f0934a9ac69e4aec551fb8a923d8ee3d` |
| de | Tagged November 24, 2026, macOS 27.2 | `e0814d62d7ae0f32a9c1fb30ef06c89d84c1c0ce97003ccede0d389494697280` |
| fr | Tagged November 24, 2026, macOS 27.2 | `eb82387afdbccf501cf3caeeb457c7b58a5fa7f1121381e3e98c81355982823e` |

`write_word_kinds.py` copies the snapshot after checking its hash, and fails if it does not match.
Without the snapshot it tags the sentences afresh and fails unless the result matches the recorded
hash, so a build never goes on with word kinds other than the recorded ones. To change a
language's word kinds on purpose, tag afresh, measure the result, and record the new file and its
hash together.

Set to Spanish, Apple's tagger on macOS 27.2 marks every word as OtherWord (all 4,361 words of
3,000 Tatoeba sentences), so Spanish takes its word kinds from the
[UD Spanish AnCora](https://github.com/UniversalDependencies/UD_Spanish-AnCora) treebank (CC BY 4.0)
with `write_treebank_word_kinds.py`, in the same classes; a word the treebank splits ("del",
"dámelo") takes its first part's class, as Apple's tagger joins contractions, and the words after
it, in its sentence and the next ones, are read on their own.
`.venv/bin/python -m unittest test_write_treebank_word_kinds` checks that a sentence after one
with a split word keeps all its words.

## Context model

`count_ngrams.py` counts each source's sentences as many times as the language's `count_weights`
give it (`languages.py`, once for an unlisted source), and records the weights in `counts.npz`
(`source_names`, `source_weights`), so `Tools/KeyVoxTypingModels` takes a sentence out of the
counts as many times as it was counted. `write_context_model.py` keeps as many words, pairs, and
sequences as the language's `context_words`, `context_pairs`, and `context_sequences` give it.
Every language but Spanish counts each source once and keeps the default sizes, so its files are
unchanged.

Spanish counts Tatoeba, OASST2, and WildChat, the text people wrote, 20 times and the speech
transcripts once, and keeps 240,000 words, 2,000,000 pairs, and 2,000,000 sequences: its 282 million
words of text are 87% speech, and Spanish writes a word in many forms. Scored with
`Tools/KeyVoxTypingHarness` on the Spanish simulation sentences of the typing models' held-out
buckets 8-9 (400 sentences at noise 0.25 and 80 at noise 0.3), and on the 45 sentences typed into
Apple's Spanish keyboard, with context models counted from the sentence files less every one of
those sentences, so no measured sentence was counted (the typing models' README, "Measured on
simulated typing", gives every measure):

| Counts and sizes | Suggestion bar shows the word within 3 letters | Mistyped words fixed | Correctly typed words wrongly changed | Final words correct, 80 at 0.3 | Apple's 45 |
| --- | --- | --- | --- | --- | --- |
| Once each, default sizes | 73.8% | 806/877 | 17/2,718 | 706/764 | 251/264 |
| Once each, 2,000,000 pairs and sequences | 74.6% | 807 | 16 | 708 | 252 |
| Once each, 5,000,000 pairs and sequences | 75.0% | 807 | 16 | 705 | 252 |
| Written 5 times, 2,000,000 | 75.7% | 810 | 15 | 709 | 253 |
| Written 20 times, 2,000,000 | 76.2% | 813 | 11 | 712 | 253 |
| Written 50 times, 2,000,000 | 76.2% | 814 | 10 | 712 | 252 |
| Written text alone, 2,000,000 | 75.7% | 812 | 14 | 709 | 252 |

Each row replaces only the context model of files built from counts taking every source once; 20
times with 2,000,000 pairs and sequences is the best row that lowers no measure of another. Built
with those weights, the dictionary and rankers raise every measure further (the typing models'
README).

### Latin American Spanish

Latin American Spanish (`PredictiveData/es-419`) bundles no language data of its own: it uses
Spanish's (`sharedDataFolder`), as measurement showed no build counted toward Latin American text
types it better without typing something else worse.

WildChat gives each turn the country it was typed in. Its Spanish user turns typed in 19 Latin
American countries and in Spain were read and split as this build reads WildChat, and kept as test
sentences where every word is spelled as the user's own country spells it (that country's
[RLA-ES](https://github.com/sbosio/rla-es) Hunspell dictionary, release 2.9) and no sentence was
typed in both regions: 25,183 Latin American and 8,170 Spain sentences, of which 1,000 of each,
picked by a hash, were left out of every count and typed by `Tools/KeyVoxTypingHarness` (800 at
noise 0.25 with `evaluate`, 160 at 0.3 with `compare`). Spanish's own measures (the typing models'
held-out sentences, and the 45 Tatoeba sentences typed into Apple's Spanish (Latin America) keyboard)
were left out of the counts too.

With Spanish's data, Latin American sentences come out as well as Spain's: 94.8% of mistyped words
fixed (Spain 94.6%), 0.2% of correctly typed words wrongly changed (Spain 0.2%), and 93.8% of final
words correct (Spain 92.9%). The suggestion bar shows the word within 3 letters for 75.4% (Spain
78.1%); the Latin American sentences' words are longer (21.4% of 8 letters or more, Spain 19.6%).

Counting the Latin American turns more raised the Latin American measures but restored fewer accents
on Spanish's own sentences, which Apple's Latin American keyboard restores as Apple's Spain keyboard
does ("asi" to "así", "podra" to "podrá"): people in Latin American chats often type without accents,
so those spellings became everyday words. Each row replaces only the context model:

| WildChat's Latin American turns counted | Latin American: fixed, wrongly changed, final words, bar within 3 letters | Held-out 400: fixed | Held-out 80: final words | Apple's 45 |
| --- | --- | --- | --- | --- |
| 20 times, as the rest (Spanish's counts) | 1,856/1,957, 8/5,192, 1,441/1,537, 75.4% | 814/877 | 712/764 | 253/264 |
| 40 times | 1,853, 8, 1,440, 75.6% | 813 | 712 | 253 |
| 100 times | 1,858, 8, 1,444, 76.2% | 813 | 708 | 252 |
| 200 times | 1,861, 6, 1,449, 76.5% | 810 | 708 | 252 |
| 400 times | 1,862, 6, 1,453, 76.5% | 809 | 703 | 250 |
| 400 times where the vocabulary spells every word of the sentence, else 20 | 1,858, 10, 1,441, 76.2% | 811 | 710 | 253 |
| 800 times where the vocabulary spells every word, else 20 | 1,861, 10, 1,441, 76.3% | 810 | 707 | 253 |

Every row that counts them more lowers a measure of Spanish's or of the Latin American sentences, so
Latin American Spanish keeps Spanish's counts.

## Sentence openers

`sentence_openers.txt` holds the words the suggestion bar offers where a sentence begins.
Each language's source weights are in `languages.py`: English's were tuned against Apple's English
suggestion bars (youtube-commons 0, oasst2 0.3, tatoeba 10). German and French give the same
weights by kind of source, speech 0, chat and text messages 0.3, and Tatoeba 10.

German's were measured against Apple's German (Germany) bars after 53 sentences
(`apple-languages/sentence-openers/de_DE.json` in KeyVox's language data, read with `--apple`), over a
grid of 24 weightings (Tatoeba 1, 10, 30; OASST2 and WildChat 0, 0.3, 1, 3; speech 0, 0.1), and keep
those weights: no weighting with Tatoeba at 10 or 30 shares more words with Apple's bars, and the
few that share more, with Tatoeba at 1, show far fewer different bars than Apple's:

| Weights (Tatoeba, OASST2, WildChat, speech) | Words shared with Apple's bar | Different bars (Apple: 36) | Held out: Tatoeba | OASST2 | WildChat | YODAS2 | YouTube-Commons |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 10, 0.3, 0.3, 0 (German) | 1.26 of 3 | 17 | 29.3% | 8.6% | 5.0% | 17.6% | 15.8% |
| 10, 0.3, 0.3, 0.1 | 1.21 of 3 | 13 | 28.5% | 8.8% | 5.9% | 20.5% | 18.4% |
| 1, 0.3, 0.3, 0.1 | 1.30 of 3 | 8 | 27.8% | 8.9% | 6.4% | 21.5% | 20.2% |
| 30, 0.3, 0.3, 0 | 1.23 of 3 | 22 | 29.3% | 8.0% | 4.8% | 17.2% | 15.7% |

Apple's French (France) bars were captured after 52 sentences and in an empty field
(`apple-languages/sentence-openers/fr_FR.json` in KeyVox's language data, iOS 27.2 simulator).
With `--apple`, the bundled French openers share 1.15 of Apple's 3 words a bar and show 17
different bars to Apple's 37. Other weights move this little: Tatoeba 3 shares 1.23, Tatoeba 1
1.17, 88milSMS 3 1.15, 88milSMS 10 1.11, and Tatoeba 30 1.15, a few words over 53 bars, so
French keeps the weights the languages share.

Spanish's were tuned against Apple's Spanish (Spain) bars after 53 sentences
(`apple-languages/sentence-openers/es_ES.json` in KeyVox's language data, read with `--apple`):
the same weights but speech at 0.1, which share more words with Apple's bars and find the next
sentence's first word more often in every source's held-out texts:

| Weights (Tatoeba, OASST2, WildChat, speech) | Words shared with Apple's bar | Different bars (Apple: 45) | Held out: Tatoeba | OASST2 | WildChat | YODAS2 | YouTube-Commons |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 10, 0.3, 0.3, 0 | 0.91 of 3 | 16 | 15.1% | 8.0% | 5.7% | 8.3% | 8.4% |
| 10, 0.3, 0.3, 0.1 (Spanish) | 1.00 of 3 | 18 | 15.9% | 8.4% | 6.4% | 9.5% | 9.4% |

A grid of 96 weightings (Tatoeba 1, 10, 30; OASST2 and WildChat 0, 0.3, 1, 3; speech 0, 0.1)
shared at most 1.06 words (10, 0, 0.3, 0.1), at the cost of OASST2's held-out sentences (5.0%).
Ten of the 53 sentences end in a line break with no mark, after which Apple's bar offers
lowercase continuations rather than openers in every measured language; no weighting matches
those.

A sentence opened with one of the language's sentence opening marks (`sentenceOpeningMarks` in its
`language.json`, Spanish's "¿" and "¡") also counts its first word after that mark
(`count_sentence_openers.py`), and `sentence_openers.txt` gives every opener's log likelihood after
each such mark (`opening <mark>` lines), which the keyboard offers right after the mark where a
sentence starts: after "¿", Spanish's are "qué", "por", and "cómo", the three words Apple's Spanish
keyboard offers there (`apple-languages/runs/behavior-es_ES`); after "¡", "no", "qué", and "me",
where Apple offers "No", "Y", and "Si", its openers at the start of the text.

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

## Swipe vocabulary

`swipe_vocabulary.txt` holds the words people write that the English dictionary lacks, so a
swipe can decode to them: "haha", "hahaha", "omg", "lmao", "cuz", "anyways", British spellings
such as "centre", and names such as "Minecraft", then the words swipe.futo.org's training split
had people swipe that the dictionary and those words lack, such as "well-known" and
"Derbyshire" (see "Swiped words"). One word per line, its spelling, a tab, and its probability
on the dictionary's 0-255 scale, likeliest first. It holds no dictionary word, so the
dictionary stays the one source of every word it has, and the swipe lexicon is the dictionary's
words and these.

`count_swipe_words.py` counts each source's words, read from the texts the language data reads,
after decoding HTML character references and skipping Markdown code (`normalize.prose`). It
also counts how often each word is joined to other letters or digits in one run without spaces
(`normalize.joined_words`), and, in OASST2 and Tatoeba, how often it is written with capitals in
the middle of a sentence. `write_swipe_vocabulary.py` reads the counts by swipe form (letters
only, case and accents folded, as a swipe draws them). Each form no dictionary word spells is a
candidate, and these rules, in order, leave one out. The counts are from the build of November
27, 2026:

| Rule | Leaves out | Forms |
| --- | --- | --- |
| Offensive | A word the dictionary leaves out too: a pattern of `--leave-out` matches it whole (`Tools/KeyVoxTypingModels/offensive_words.py`) | 61 |
| Letters | A letter that is no letter key of the keyboard (the default letter layout `language.json` names, `letter_layouts/<layout>.json`) | 6,262 |
| One source | Fewer than two of the three sources write it as a word on its own | 693,597 |
| Joined | Written joined to other letters or digits more than half the time: URLs, hyphenated words, code | 125 |
| Misspelling | A dictionary form one edit away (a letter left out, added, or changed, or two neighbors swapped) is written on its own at least 50 times as often as it is | 4,187 |
| Kept | | 22,459 of 726,691 |

The dictionary's words that `--leave-out` matches still count as dictionary words here, as
`work/dictionary_unigrams.tsv` holds them, so they are never candidates and every other rule
and probability is as it would be with them in the dictionary.

- Decoding HTML references and skipping Markdown code leaves 416 forms in a single source that
  were in two before, the largest "nbsp" (980,367 times before, 44 after); the others' only other
  source was code or HTML references in OASST2.
- The misspelling rule never leaves out a form SCOWL's size 80 lists in any spelling (American,
  British, Canadian, or Australian), which keeps 1,747 forms such as "colour", "yay", and
  "cafe", or one the written sources write with capitals more often than in lowercase, as a
  name or an acronym (a misspelling of a lowercase word is lowercase), which keeps 2,830.
- Both sides of the misspelling rule count only the times a form is written on its own, so a
  fragment of longer tokens neither makes its neighbors misspellings nor is spared by its
  fragments: "th", written 145,719 times but 2,989 on its own, mostly in "5th" and the like,
  leaves "tbh" in.
- It still leaves out short chat words one edit from a much more common word: "idk" ("id"),
  "smh" ("sh"), "brb" ("bro"), "ngl" ("nfl"), "homie" ("home"), "hella" ("hell"), and "ebook"
  ("book"). How much more common the word is does not tell them from misspellings: "homie" is
  88 times rarer than "home", "occured" 409 times rarer than "occurred".
- Tatoeba's texts that mention its recurring invented characters are left out of the counts, as
  from the rest of the language data, or the characters' names would be kept.

Each kept form is written in its most common spelling ("tonight's", "i'mma"), with its likeliest
capitals when the written sources write it as a name (`names.is_written_as_name`), unless they
are capitals in a row, which stay lowercase as in the capitalized spellings ("json"). Its
probability is the median the dictionary gives its words that the sources write on their own
about as often (within a quarter of an octave), so an added word ranks as a dictionary word as
common would. `<data-dir>/swipe_vocabulary_report.tsv` lists every candidate with its counts, its outcome and
the rule or exception behind it, and a kept form's rank, spelling, and probability; a form the
swipe dataset swipes also has how many records swipe it, the outcome of the rules below, and its
spellings there, and a form only the dataset has is listed with the outcome "no source".

### Swiped words

swipe.futo.org's training split (`FUTO_SWIPE` in `sources.py`, `swiped_words` in `languages.py`)
is 939,550 swipes of the words of sentences taken from Wikipedia, each record with its word as
the sentence writes it and its place in the sentence. `count_swiped_words.py` counts each word
without the punctuation around it ("well-known", "Ed.D"), and apart, the times it is in the
middle of a sentence, neither first in the sentence nor right after where a sentence or quotation
can begin (`normalize.begins_written_run`). The dataset's validation and test splits are never
read.

The sources write most of these words too rarely for the rules above, so the words of the
dataset come after the sources' words, with rules of their own. Each form no dictionary word
spells and the list does not already hold is a candidate, and these rules, in order, leave one
out. The counts are from the build of November 27, 2026:

| Rule | Leaves out | Forms |
| --- | --- | --- |
| Offensive | As above | 1 |
| Letters | A letter that is no letter key of the keyboard, as above | 0 |
| One swipe | Fewer than two records swipe it | 21,721 |
| Misspelling | As above, counting how often the sources write the form on its own (none for most), so a dictionary form one edit away that the sources write at all leaves it out | 129 |
| Kept | | 3,860 of 25,711 |

- The misspelling rule keeps its exceptions: a form SCOWL's size 80 lists, which keeps 201, or
  one the dataset's sentences write with capitals more often than in lowercase in the middle of
  a sentence, which keeps 558. It leaves out the dataset's own misspellings, such as "adpressed",
  "buildink", and "portraint", and words that would take a common word's swipes, such as
  "two-day" ("today"), and "ebook" and "focussed" as from the sources' words.
- The rules for one source and joined words count the sources' texts, which hardly write these
  words; a word the dataset writes joined, such as "well-known", is the whole word a person
  swipes, and 584 of the words kept are hyphenated.

Each kept form is written in its most common spelling, with its likeliest capitals when the
dataset's sentences write that spelling with capitals more often than in lowercase in the middle
of a sentence (2,856 of them), unless they are capitals in a row, which stay lowercase as above.
The forms are ranked by how many records swipe them, each with the lowest probability the
sources' words get, 41.

### Measured accuracy

`Tools/KeyVoxTypingHarness swipe-accuracy` decoded swipe.futo.org's test and validation splits,
with the words before each swipe, through the keyboard's swipe path and the bundled swipe model,
before and after the swiped words were added (top-1, context weight 0.425):

| Split | Swipes | Without the swiped words | With them |
| --- | --- | --- | --- |
| Test | 49,970 | 92.26% | 92.62% |
| Validation | 54,269 | 92.49% | 92.83% |
| Validation, no words before | 54,269 | 91.84% | 92.18% |

On the validation split without the words before, 193 swipes decode to their word first that did
not, every one of them to an added word, and 4 that did no longer do, 3 of them to an added word.

The measurement below was made before the swiped words were added.

`Tools/KeyVoxSwipeModel` decoded the 54,269 swipes of swipe.futo.org's validation split with
`r1-ft-dec6`, the model bundled at the time, and that run's tuned scoring (`scoring.json`),
with the dictionary alone and with the first words of the swipe vocabulary added, by rank:

| Words added | Swipes whose word can be decoded | Top-1 | Top-3 | Top-10 |
| --- | --- | --- | --- | --- |
| None | 95.73% | 91.29% | 94.67% | 95.36% |
| 2,500 | 96.08% | 91.50% | 94.96% | 95.68% |
| 5,000 | 96.22% | 91.60% | 95.09% | 95.81% |
| 10,000 | 96.38% | 91.71% | 95.23% | 95.96% |
| 15,000 | 96.45% | 91.74% | 95.28% | 96.01% |
| 20,000 | 96.50% | 91.77% | 95.31% | 96.05% |
| 22,465 (all) | 96.51% | 91.79% | 95.33% | 96.07% |

Top-1 rises with every size, so every kept form is in the list. With all of them, 325 swipes
decode to their word first that did not, and 55 that did no longer do: 44 of those to an added
word, 11 of them a British spelling of the American word ("center" to "centre", "organized" to
"organised") and the rest look-alikes ("it" to "itu", "this" to "theos"). The split's one swipe of
"haha" decoded as "has" before and as "haha" now. The test split was not decoded. The measurement,
every row above with each swipe gained and lost and the SHA-256 of the list it measured, is kept
with KeyVox's language data as `swipe/vocabulary-build/swipe_accuracy_val-22465.json`.

### Why a list of its own

Added to the typing dictionary instead, the same words with the same probabilities change typing.
`Tools/KeyVoxTypingHarness` scored the dictionary with them against the bundled one, with the
bundled rankers:

| Measure | Plan | Bundled | With the swipe vocabulary |
| --- | --- | --- | --- |
| Final words correct | 80 sentences, noise 0.3 (`compare`) | 909/946 | 910 |
| Mistyped words fixed | 400 sentences, noise 0.25 (`evaluate`) | 1,165/1,230 | 1,173 |
| Completion offered within 2 letters | 400 | 50.5% | 49.9% |
| Final words correct | ITE held-out typists, 3,000 sentences (`compare`) | 21,651/22,034 | 21,650 |
| Mistyped words fixed | ITE | 326/583 | 325 |
| Completion offered within 2 letters | ITE | 51.6% | 51.3% |
| Correction call, 95th percentile | 400 | 4.18 ms | 8.23 ms |

Typing gets worse on some measures of every plan but the 80-sentence one, and a correction takes
up to twice as long, so the words stay out of the typing dictionary, and the swipe lexicon adds
them to the dictionary's words.
