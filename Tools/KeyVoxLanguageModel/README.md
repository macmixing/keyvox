# KeyVox Language Model

Builds the language data the predictive keyboard bundles in
`Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData`:

| Bundled file | Built by | Reads |
| --- | --- | --- |
| `context_artifact_800k.bin` | `extract_sentences.py`, `count_ngrams.py`, `write_context_model.py` | Every source, through `extract_sentences.py` |
| `sentence_openers.txt` | `tag_word_kinds.swift`, `count_sentence_openers.py`, `write_sentence_openers.py` | Every source, through `extract_sentences.py`'s readers and its sentences |
| `capitalized_spellings.txt` | `scowl_words.sh`, `write_capitalized_spellings.py` | SCOWL, `measured_spellings.txt`, and OASST2 and Tatoeba through `extract_sentences.py`'s readers |

The builders share the source readers (`extract_sentences.py`, `names.py`) and
`normalize.py`, so a change made for one can change another's output. After changing any
tool here, rebuild everything and see which bundled files change:

```bash
PYTHON=.venv/bin/python ./rebuild_bundled_data.sh <data-dir> --check
```

`--check` leaves the package alone and fails if a rebuilt file differs from the bundled one;
without it, the files that differ replace the bundled ones. Measure a changed context model
or sentence-opener list before shipping it, as described below.

The context model judges how likely a word is after the words before it. It holds counts
and probabilities of words, word pairs, and three-word sequences; it contains no text.

## Sources

Every source is pinned in `sources.py` with its license and required attribution, and
is credited in `THIRD_PARTY_NOTICES.md` once a model built from it ships.

| Source | Text | License |
| --- | --- | --- |
| [YouTube-Commons](https://huggingface.co/datasets/PleIAs/YouTube-Commons) | English transcripts of videos published under Creative Commons Attribution | CC BY 4.0 |
| [OpenAssistant OASST2](https://huggingface.co/datasets/OpenAssistant/oasst2) | English chat messages | Apache 2.0 |
| [Tatoeba](https://tatoeba.org/en/downloads) | English sentences | CC BY 2.0 FR |

## Building

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python download_sources.py <data-dir>
.venv/bin/python extract_sentences.py <data-dir>
.venv/bin/python count_ngrams.py <data-dir>
.venv/bin/python write_context_model.py <data-dir> <output.bin>
```

The data directory needs about 25 GB. Measure a new model with
`Tools/KeyVoxTypingHarness` against the bundled one before replacing it.

## Sentence openers

`sentence_openers.txt` holds the words the suggestion bar offers where a sentence begins.
It is built from the same data directory, after `extract_sentences.py`:

```bash
xcrun swiftc -O tag_word_kinds.swift -o <scratch>/tag_word_kinds
<scratch>/tag_word_kinds <data-dir>/word_kinds.tsv <data-dir>/sentences/tatoeba.txt <data-dir>/sentences/oasst2.txt
.venv/bin/python count_sentence_openers.py <data-dir>
.venv/bin/python write_sentence_openers.py <data-dir> --weight youtube-commons=0 --weight oasst2=0.3 --weight tatoeba=10 --output <output.txt>
```

## Words spelled with capitals

`capitalized_spellings.txt` holds the words the keyboard writes with their capitals, such as
"Jennifer" or "iPhone". It is built from SCOWL, the word list the dictionary comes from, and
the written sources in the data directory:

```bash
./scowl_words.sh 60 <scratch>/scowl-60.txt
./scowl_words.sh 50 <scratch>/scowl-50.txt
.venv/bin/python write_capitalized_spellings.py <data-dir> <scratch>/scowl-60.txt <scratch>/scowl-50.txt <output.txt>
```

Spellings with capitals in a row are left out, as the system keyboard leaves acronyms such
as "nasa" lowercase, except those listed in `measured_spellings.txt`, which the system
keyboard was measured writing as spelled (`Tools/AppleKeyboardBaseline`).
