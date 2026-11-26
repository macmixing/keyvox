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
| `swipe_vocabulary.txt` | `count_swipe_words.py`, `count_swiped_words.py`, `write_swipe_vocabulary.py` | Every source, through `source_texts.py`, the words swipe.futo.org's training split had people swipe, the dictionary's words and probabilities, and SCOWL's size 80 in every spelling |

The swipe vocabulary is built only for a language with a dictionary, so for English alone
today (see "Swipe vocabulary").

English's dictionary, rankers, and accent overlay, bundled beside these files, are built by
`Tools/KeyVoxTypingModels`.

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

Given `[dictionary-words]`, the language's dictionary words and probabilities (a word, a tab,
and a probability a line), it then builds the swipe vocabulary:

```bash
.venv/bin/python count_swipe_words.py --language <language> <data-dir>
.venv/bin/python count_swiped_words.py --language <language> <data-dir>
./scowl_words.sh 80 <output-dir>/spelling_list.txt A,B,Z,C,D
.venv/bin/python write_swipe_vocabulary.py --language <language> <data-dir> <dictionary-words> <output-dir>/spelling_list.txt <output-dir>/swipe_vocabulary.txt
```

Steps that read none of each other's files run side by side: after `download_sources.py`, the
vocabulary and the words spelled with capitals (`write_vocabulary.py`,
`write_capitalized_spellings.py`) and the swipe vocabulary's counts (`count_swipe_words.py`,
`count_swiped_words.py`, the spelling list) run beside `extract_sentences.py`; then the context model (`count_ngrams.py`,
`write_context_model.py`) beside the sentence openers (`write_word_kinds.py`,
`count_sentence_openers.py`, `write_sentence_openers.py`); then the two follower lists and the
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

The builds of November 24, 2026. Every context model fills the default limits (107,000 words,
800,000 pairs, 600,000 sequences), so each is 14,963,028 bytes, as English's is.

| Build | Words of text | Vocabulary | Capitalized spellings | Grammar words |
| --- | --- | --- | --- | --- |
| en | 528,779,799 | 109,172 (SCOWL size 60) | 18,144 | 152 |
| de | 118,350,701 | 209,470 | 146,689 | 220 |
| de-bundestag | 138,467,367 | 209,470 | 146,689 | 222 |
| es | 281,865,056 | 236,307 | 2,955 | 156 |
| fr | 393,698,831 | 165,093 | 19,021 | 195 |

Texts, sentences, and words each source gave after deduplication:

| Build | Source | Texts | Sentences | Words |
| --- | --- | --- | --- | --- |
| de | Tatoeba | 627,288 | 666,250 | 4,813,532 |
| de | OASST2 | 6,086 | 36,718 | 412,098 |
| de | WildChat | 29,581 | 52,602 | 386,654 |
| de | YODAS2 | 19,250 | 1,353,933 | 23,715,021 |
| de | YouTube-Commons | 41,435 | 175,889 | 89,023,396 |
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

| Language | Word list | Vocabulary | Written in lowercase by the spelling check |
| --- | --- | --- | --- |
| de | 205,887 words | 209,470 spellings | (no check) |
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
25, 2026:

| Rule | Leaves out | Forms |
| --- | --- | --- |
| Letters | A letter that is no letter key of the keyboard (the default letter layout `language.json` names, `letter_layouts/<layout>.json`) | 6,262 |
| One source | Fewer than two of the three sources write it as a word on its own | 693,651 |
| Joined | Written joined to other letters or digits more than half the time: URLs, hyphenated words, code | 125 |
| Misspelling | A dictionary form one edit away (a letter left out, added, or changed, or two neighbors swapped) is written on its own at least 50 times as often as it is | 4,188 |
| Kept | | 22,465 of 726,691 |

- Decoding HTML references and skipping Markdown code leaves 416 forms in a single source that
  were in two before, the largest "nbsp" (980,367 times before, 44 after); the others' only other
  source was code or HTML references in OASST2.
- The misspelling rule never leaves out a form SCOWL's size 80 lists in any spelling (American,
  British, Canadian, or Australian), which keeps 1,748 forms such as "colour", "yay", and
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
out. The counts are from the build of November 26, 2026:

| Rule | Leaves out | Forms |
| --- | --- | --- |
| Letters | A letter that is no letter key of the keyboard, as above | 0 |
| One swipe | Fewer than two records swipe it | 21,721 |
| Misspelling | As above, counting how often the sources write the form on its own (none for most), so a dictionary form one edit away that the sources write at all leaves it out | 129 |
| Kept | | 3,861 of 25,711 |

- The misspelling rule keeps its exceptions: a form SCOWL's size 80 lists, which keeps 201, or
  one the dataset's sentences write with capitals more often than in lowercase in the middle of
  a sentence, which keeps 559. It leaves out the dataset's own misspellings, such as "adpressed",
  "buildink", and "portraint", and words that would take a common word's swipes, such as
  "two-day" ("today"), and "ebook" and "focussed" as from the sources' words.
- The rules for one source and joined words count the sources' texts, which hardly write these
  words; a word the dataset writes joined, such as "well-known", is the whole word a person
  swipes, and 584 of the words kept are hyphenated.
- No word kept is on the profanity list `SwipeOffensiveTwinTests` reads.

Each kept form is written in its most common spelling, with its likeliest capitals when the
dataset's sentences write that spelling with capitals more often than in lowercase in the middle
of a sentence (2,857 of them), unless they are capitals in a row, which stay lowercase as above.
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
