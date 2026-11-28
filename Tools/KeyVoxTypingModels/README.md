# KeyVox Typing Models

Builds the typing models the predictive keyboard bundles for a typing language: those of its
English typing language in
`Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/en`, German's
in `PredictiveData/de`, Spanish's in `PredictiveData/es`, and French's in `PredictiveData/fr` (see
"Other typing languages"). English's:


| Bundled file | What it is | Built by |
| --- | --- | --- |
| `dictionary/` | LatinIME version 403 dictionary, in `dictionary.header` and `dictionary.body`: 106,907 words with probabilities, 93,372 word pairs, and 60,000 three-word sequences, without the words `offensive_words.py` matches | `write_dictionary_inputs.py`, `write_latinime_dictionary.cpp` |
| `correction_ranker.kvtr` | 220 gradient-boosted trees that score each correction candidate | `train_correction_models.py`, `export_tree_models.py` |
| `autocorrect_decision.kvtr` | 160 trees that score whether to replace the typed letters with the best correction | `train_correction_models.py`, `export_tree_models.py` |
| `completion_ranker.kvtr` | 220 trees that score each candidate while a word is still being typed | `train_completion_ranker.py`, `export_tree_models.py` |
| `accent_overlay.bin` | 262 accented words the dictionary lacks, by the plain letters that type them | `write_accent_words.py`, `write_accent_overlay.py` |

The context model, `context_model.bin`, and the word lists are built by
`Tools/KeyVoxLanguageModel`.

## Sources

Every input is pinned to a revision or a recorded SHA-256 in `sources.py` or
`scowl_word_list.sh`, and credited in `THIRD_PARTY_NOTICES.md`.

| Source | Used for | Pinned to | License |
| --- | --- | --- | --- |
| [SCOWL](https://github.com/en-wl/wordlist) | The dictionary's words (size 60, American, variant level 2), accented words (size 60, every spelling), and, with the dictionary's words, words never corrected (size 50, every spelling) | Commit `1e5b7d3a72f47a71da5d28686c1dd4b397178485`, archive SHA-256 checked | ESDB permissive notice |
| [Tatoeba](https://tatoeba.org/en/downloads) | Word, word-pair, and three-word counts | The English sentences as of the 2026-07-18 06:00 export, rewound from today's export and contribution log and checked against their recorded SHA-256 | CC BY 2.0 FR |
| [OpenAssistant OASST1](https://huggingface.co/datasets/OpenAssistant/oasst1) | Word, word-pair, and three-word counts | Revision `fdf72ae0827c1cda404aff25b6603abec9e3399b` | Apache 2.0 |
| [Aalto ITE Typing dataset](https://doi.org/10.5281/zenodo.12528163) | The typing events the rankers learn from, and the sentences left out of the counts | Zenodo record 12528163; five files are read from the archive by byte range | CC BY 4.0 |
| [AOSP LatinIME](https://android.googlesource.com/platform/packages/inputmethods/LatinIME/) | Writing and reading the dictionary | The native sources bundled in `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveNative/latinime`, compiled unchanged | Apache 2.0 |
| [Profanity List](https://github.com/dsojevic/profanity-list) | The words the dictionary and the swipe vocabulary leave out: its English terms tagged racial or anti-LGBTQ, or religious at strong severity or above (`offensive_words.py`) | Commit `c27924319aa9bd6f917e3782b4f4b6604a50b652` | MIT |
| [Multilingual HateCheck](https://huggingface.co/datasets/Paul/hatecheck-german) | The words German and French dictionaries leave out: the slurs of its slur test cases that target the groups English's left-out tags name (see "Words left out") | German revision `5229a5cc475f36c08d03ca52f0ccb005705e60d2`, French `5d3085f2129139abc10d2b58becd4d4f2978e5d5` | CC BY 4.0 |

Tatoeba publishes only its current export, which changes every week. `rewind_tatoeba.py` turns
it back into the export of the cutoff `sources.py` pins: every sentence the contribution log
added, edited, or deleted after the cutoff gets its state as of the cutoff. Rewinding the 2026-11-21 export to 2026-10-03 this way
matched the real 2026-10-03 export with no sentence missing or changed, and kept 7 sentences
beyond its 2,038,137, because the export also hides sentences for reasons the log does not
record. `sources.py` lists the sentences hidden or shown at the
cutoff other than the log implies: the ones the bundled dictionary's probabilities point
to. The probabilities cannot tell "He is sure of success." from "He is sure of winning.";
either gives the same probabilities, and the listed one gives the results below.

The rewound sentences, 2,031,914 of them, must match the SHA-256 `sources.py` records over
their uncompressed text. They are kept in `sources/tatoeba/eng_sentences_at_cutoff.tsv.bz2`, and
while that file is there and matches, later builds use it as it is and do not download
Tatoeba. When it is missing, today's export and log are rewound again; if Tatoeba has since
changed in a way the log does not undo, or a listed sentence no longer fits, the build stops
with a message saying Tatoeba has drifted and leaves the rewound sentences in
`eng_sentences_at_cutoff.unverified.tsv.bz2` to compare.

## Building

The data directory needs about 1 GB, plus the Python environment.

```bash
python3.14 -m venv <data-dir>/venv
<data-dir>/venv/bin/pip install -r requirements.txt
PYTHON=<data-dir>/venv/bin/python ./build_typing_models.sh <data-dir>
```

The built files land in `<data-dir>/built` under the names they have in the language's folder,
`PredictiveData/en` for English, and `compare_with_bundled.py` then says for each whether it is
the same as the bundled one, leaving out the write times in the dictionary header; with `--check`
after the data directory, the build fails if any differs. The package is left alone. The build runs the candidate caches
with `--as-bundled`, which asks LatinIME the queries the bundled rankers learned from as the
July caches asked them, so every built file is the bundled one (see "How the bundled rankers
were trained"). Once the sources are
downloaded, the build takes about 12 minutes on an Apple silicon Mac. Set `OMP_NUM_THREADS` to
limit the cores the tree training uses.

`requirements.txt` pins the versions the bundled files were built with, on Python 3.14.
The LatinIME tools are compiled with the Xcode command line tools.

`latinime_suggestions.cpp` orders candidates of equal score with `std::sort`, which leaves
the order of ties to the C++ standard library. The rankers are trained on the order that Apple
clang 21.0.0 (clang-2100.3.34.1) with libc++ 220106 (macOS 27.2 SDK) gives, and Apple clang
21.0.0 (clang-2100.3.33.1) and Apple clang 21.0.0 (clang-2100.4.1.1) with the same libc++ rebuild
every bundled file the same;
`build_native_tools.sh` checks for one of those compilers and that libc++ version and stops with
a message naming them on any other toolchain. Apple clang 15.0.0 with libc++ 160006 (macOS 13),
for one, orders 8,485 of the July build's 84,720 correction queries' ties differently, and the
trained rankers differ. Every other step gives the same bytes on either.

Each query searches in a LatinIME session of its own. A session continues its last search when
the new typed letters start with the last ones, and keeps that search's previous words, so a
shared session answers a query for the one asked before it: "woll" after "we finished is" gets
"will" at 758,130 asked alone and at 547,122 asked right after "woll" after "korea's south".
With `--as-bundled`, the reader keeps one session for every query (`--shared-session`), as the
July caches did.

## Steps

`build_typing_models.sh` runs them in this order for English; another language skips the English
sources' steps and trains its rankers on simulated typing (see "Other typing languages"):

| Step | Writes |
| --- | --- |
| `download_sources.py` | `sources/`, with each file's SHA-256 in `sources/checksums.txt`; for another language, the SHA-256 of its language build's files |
| `build_native_tools.sh` | `bin/write_latinime_dictionary`, `bin/latinime_suggestions` |
| `rewind_tatoeba.py` | `sources/tatoeba/eng_sentences_at_cutoff.tsv.bz2`, checked against its recorded SHA-256 |
| `scowl_word_list.sh` | `work/scowl-*.txt` |
| `offensive_words.py` | `work/offensive_words.txt`: a pattern a line of the words the dictionary leaves out |
| `write_dictionary_inputs.py`, then `bin/write_latinime_dictionary` | `work/dictionary_unigrams.tsv` and `work/dictionary_ngrams.tsv`, every word and sequence counted, which the later steps and `Tools/KeyVoxLanguageModel` read, and `work/counted_dictionary/`, compiled from them, which the caches ask with `--as-bundled`, and always for another language; `work/dictionary_kept_*.tsv`, the same less the words `offensive_words.txt` matches and every sequence holding one, and `built/dictionary/`, compiled from those with the language's locale and header attributes (`typing_languages.py`) |
| `split_ite_events.py` | `work/ite/`: autocorrections, words left alone, and accepted predictions, split by typist |
| `write_feature_context_model.py` | `work/feature_context_800k.bin`: the word and word-pair counts the rankers train with |
| `cache_correction_candidates.py`, `cache_completion_candidates.py` | `work/*_candidates.pkl.gz`: LatinIME's candidates, typed on the keys of the language's letter layout; with `--as-bundled`, as the build runs them, for the queries the bundled rankers learned from (`bundled_queries.py`), otherwise for every record `training_sets.py` gives the trainers |
| `train_correction_models.py`, `train_completion_ranker.py` | `work/*.pkl.gz` and held-out reports in `work/reports/` |
| `export_tree_models.py` | `built/*.kvtr`, checked against the trained models on 10,000 rows |
| `write_accent_words.py`, `write_accent_overlay.py` | `built/accent_overlay.bin` |
| `compare_with_bundled.py` | A line per built file: same as the bundled one or not |

The rankers train on records split by the sentence the typist was copying, so a sentence's
words are never on both sides of a training and test split. `training_sets.py` gives the
records each trainer reads, and the candidate caches without `--as-bundled` ask for exactly
those: buckets 0-4 train
the correction ranker, bucket 5 the action model, 0-7 the completion ranker, and 8-9 are held
out. The caches and the trainers take `--source`: `ite`, the default, trains on ITE's typing,
`sim` on simulated typing, and `sim+ite` on both (see "Training on simulated typing"); the
held-out reports are on ITE's buckets 8-9 whatever the source.

## How the bundled rankers were trained

The bundled rankers were trained in July 2026 by scripts that asked LatinIME for other records
than the trainers read, in one shared search session. `bundled_queries.py` keeps those
queries in their order, and the caches ask them that way with `--as-bundled`, so the build
rebuilds the bundled rankers:

- The cache asked for a fifth of the calibration typists' plausible autocorrections, sampled
  after keeping the plausible ones (49,041 records). The trainer sampled a fifth first and kept
  the plausible ones after (49,196 records), so it read records the cache never asked for.
- The cache never asked for the held-out typists' wrong autocorrections, the records with the
  word the logged keyboard chose. The trainer read them, and only those whose query another
  record asked kept candidates.
- Every query searched in the same session, so 870 of the 84,720 correction queries and 218 of
  the 51,165 completion queries got the answer for the query asked before them; asked each in a
  session of its own, they answer differently.

A record whose query was never asked gets no candidates and is left out, as is one whose
cached candidates are only the typed letters or two-word suggestions; `candidate_groups` prints
both counts for every set of records it makes. What each set trains or is measured on, from a
build's printout:

| Set (sentence buckets) | Records | Kept | Never asked | No candidates | Trained on |
| --- | --- | --- | --- | --- | --- |
| Correction ranker training (0-4) | 58,285 | 45,938 | 12,086 | 261 | 286,616 candidate rows from the 44,890 kept records whose candidates include the intended word |
| Action model training, typos (5) | 11,548 | 8,990 | 2,511 | 47 | with the next row, 7,220 rows: the kept records whose best candidate may replace the typed letters |
| Action model training, words typed as meant (5) | 5,797 | 5,775 | 0 | 22 | |
| Held-out typos (8-9) | 22,983 | 18,028 | 4,848 | 107 | measured only |
| Held-out words typed as meant (8-9) | 10,851 | 10,726 | 0 | 125 | measured only |
| Copied-sentence and expressive words | 12,124 | 11,974 | 0 | 150 | measured only |
| Completion ranker training (0-7) | 160,959 | 160,769 | 0 | 190 | 916,690 candidate rows from the 132,501 kept records whose candidates include the intended word |
| Held-out completions (8-9) | 40,625 | 40,575 | 0 | 50 | measured only |

Of the 12,086 correction ranker records never asked, 9,563 came from the different calibration
samples and 2,523 were wrong autocorrections; of the 2,992 wrong autocorrections in that set,
469 kept candidates.

Without `--as-bundled`, the caches ask for every record the trainers read, each in its own
session, and only records whose candidates are the typed letters or two-word suggestions are
left out:

| Set (sentence buckets) | Records | Kept | No candidates | Trained on |
| --- | --- | --- | --- | --- |
| Correction ranker training (0-4) | 58,285 | 57,849 | 436 | 352,748 candidate rows |
| Action model training, typos (5) | 11,548 | 11,471 | 77 | with the next row, 9,206 rows |
| Action model training, words typed as meant (5) | 5,797 | 5,775 | 22 | |
| Held-out typos (8-9) | 22,983 | 22,809 | 174 | measured only |
| Held-out words typed as meant (8-9) | 10,851 | 10,726 | 125 | measured only |
| Copied-sentence and expressive words | 12,124 | 11,974 | 150 | measured only |
| Completion ranker training (0-7) | 160,959 | 160,769 | 190 | 916,693 candidate rows |
| Held-out completions (8-9) | 40,625 | 40,575 | 50 | measured only |

The package keeps the July rankers: the rankers trained that way fix two fewer mistyped words
on the 400-sentence plan and change two more to another word (see "Results"), and replacing
them needs every headline measure at least as good.

## Training on simulated typing

German, Spanish, and French have no typing dataset like ITE, so their rankers have to learn from
simulated typing mistakes. English has both, so the method is proven on English: rankers
trained on simulated typing alone are scored against the ones trained on ITE.

The simulator is measured and calibrated against ITE, then types sentences from the pipeline's
own sources. For English, its steps are not part of `build_typing_models.sh`, and they and the
training steps write into the data directory they are given, over files a build wrote there. So
after a build, copy its data directory and run them in the copy; the build's own files are never
replaced. For `sim+ite`, use another copy and `--source sim+ite`. The copy's `work/simulation` is
also the calibration every other language's build reads (see "Other typing languages"):

```bash
cp -R <data-dir> <sim-dir>
cd Tools/KeyVoxTypingModels
for step in measure_ite_typing.py fit_touch_spread.py calibrate_typo_simulator.py \
    compare_simulated_typing.py write_simulated_records.py; do
  <data-dir>/venv/bin/python "$step" <sim-dir>
done
<data-dir>/venv/bin/python write_feature_context_model.py <sim-dir> --leave-out-simulation-sentences
<data-dir>/venv/bin/python cache_correction_candidates.py <sim-dir> --source sim
<data-dir>/venv/bin/python cache_completion_candidates.py <sim-dir> --source sim
<data-dir>/venv/bin/python train_correction_models.py <sim-dir> --source sim
<data-dir>/venv/bin/python train_completion_ranker.py <sim-dir> --source sim
<data-dir>/venv/bin/python export_tree_models.py <sim-dir>
```

| Step | Writes in the copy |
| --- | --- |
| `measure_ite_typing.py` | `work/simulation/ite_typing.json`: ITE's typing mistakes, the letters typists meant, and how far they typed before picking a completion |
| `fit_touch_spread.py` | `work/simulation/touch_spread.json`: touch spreads that give ITE's substitutions of neighboring keys |
| `calibrate_typo_simulator.py` | `work/simulation/typo_calibration.json`: the simulator's spreads, rates, length factors, and sloppiness shape |
| `compare_simulated_typing.py` | `work/simulation/comparison.json`: the simulator's mistakes against ITE's, with another seed |
| `write_simulated_records.py` | `work/simulation/corrections.tsv`, `preserves.tsv`, `completions.tsv`: records in the shape `split_ite_events.py` writes |
| `write_feature_context_model.py --leave-out-simulation-sentences` | `work/feature_context_800k.bin` without the sentences the simulator types |
| the caches, without `--as-bundled`, and the trainers, with `--source` | `work/*_candidates.pkl.gz`, `work/*.pkl.gz`, and `work/reports/` |
| `export_tree_models.py` | `built/*.kvtr` |

`python -m unittest test_typo_simulator` checks that the simulator types a word's apostrophe
after everything it typed for the letters before it, that it types a letter without a key on
that letter's key, as spelled or plain at its rate, that on another layout than ITE's it adds
extra keys beside a letter on that layout, and that a word is typed the same whatever was typed
before it. `python -m unittest test_letter_keys` checks which key types a letter
(`letter_keys.py`), and `python -m unittest test_hatecheck_slurs` how the slurs are read from a
dataset's cases and turned into the patterns the dictionary leaves out (`hatecheck_slurs.py`).

### What is measured

Every measurement is from the typists the harness's ITE plan never holds out, and from
sentences outside the buckets the rankers are measured on, 8-9, so the held-out reports never
measure rankers on sentences the simulator was calibrated with.

- Mistakes left in text: the 1,852,615 words of 252,039 phone sections typed with
  autocorrection and suggestions off, picked as `Tools/KeyVoxTypingHarness/Scripts/ite_typo_plan.py`
  picks the harness's ITE plan but only from the 42,073 typists that plan never holds out
  (`ite_copied_typing.py`). 2.55% of the words were typed with a letter wrong, left out, or
  extra; 2,788 typed as a different word, more than four edits or more than half the word, are
  not mistakes of typing and are left out. Longer words get more per letter: 1.2% of two-letter words, 2.2% of
  four-letter words, and 10.2% of words of twelve letters or more were mistyped.
- Typos left for autocorrection: the 199,080 plausible autocorrections of the same typists,
  the typos the logged keyboards fixed or tried to fix, the ones a correction ranker learns from.
- Completions: how many letters the same typists had typed when they picked a suggested
  completion, for each length of word, from 129,052 picked completions.

`typo_kinds.py` sorts each difference between a typed and an intended word into substitutions
of the key beside in the row, of an overlapping key in the row above or below, and of a farther
key, left-out letters, one letter of a double letter left out, doubled letters, extra keys
beside a letter and extra farther letters, swapped neighbors, and dropped apostrophes; letter
kinds by place in the word, first, middle, or last.

### The simulator

`letter_layout.py` reads a typing language's letter keys from its default letter layout through
one function, `letter_rows`: the layout the language's `language.json` names (`defaultLetterLayout`,
from the package or the file `--language-file` names), read from the package's
`letter_layouts/<layout>.json`, each row's letters starting after the widths of the keys and
padding before them, each key a square one key pitch across and down, as `LetterKeyLayout` lays
them out. The suggestion reader taps the same keys.

Each letter is tapped with a two-dimensional Gaussian around its key's center, and the key the
tap lands on is the letter typed; a tap outside every letter key is drawn again
(`touch_spread.py`). That is the touch model of Fowler et al., "Effects of Language Modeling and
its Personalization on Touchscreen Typing Performance" (CHI 2015,
https://research.google/pubs/pub43272), which draws taps with spreads of 1.97 mm across and
1.88 mm down on Nexus 5 keys 6.16 mm wide and 9.42 mm tall: 0.32 and 0.20 key pitches, a 12.8%
miss rate for every tap before any fix. Typists fix most of those misses themselves, so the
spreads are fitted to the misses ITE typists left instead: 0.166 to 0.176 key pitches across and
0.145 to 0.155 down, by place in the word, give exactly the measured rates of neighbor
substitutions in text typed without autocorrection.

Mistakes bunch up: in text typed without autocorrection, 11.5% of the words with a letter
mistake have a second one, and 18.7% of the typos left for autocorrection do. So each word gets a sloppiness, its
length's factor times a draw from a gamma distribution of mean one; the word's mistake rates are
multiplied by it, and its taps spread wider by as much as makes them miss that many times more
often (`typo_simulator.py`). The other kinds happen at their own rates per chance, and farther
substitutions and extra letters are drawn from the ones ITE typists made at the same letter.
Each word draws its randomness from a stream of its own, seeded by the simulator's seed and the
word's sentence, typist, and place in the sentence (`write_simulated_records.py`), so a change to
how one letter is typed re-draws no other word; it moves another only through how often each key
is meant, which the spreads' miss rates are weighed over.

`calibrate_typo_simulator.py` sets the simulator so that its mistakes, measured with
`typo_kinds.py`, match two of ITE's measurements: how often a word of each length is mistyped,
from text typed without autocorrection, the only typing that shows it; and what a typo is made
of, each kind's events per typo and the share with a second mistake, from the typos left for
autocorrection. Typists who rely on autocorrection leave far more slips of a finger than typists
who fix their own: neighbor-key substitutions are 67% of a typo's mistakes there, and 45% of
the mistakes in text typed without it. Twelve rounds of typing the ITE words, measuring, and
moving each setting by its gap give spreads of 0.186 to 0.197 key pitches across and 0.154 to
0.170 down, a gamma shape of 0.069, and length factors of 0.48 for two letters, 0.54 for four,
1.19 for eight, and 3.07 for twelve or more (2.30 for one letter). Measured with another seed,
every kind seen at least 200 times among the autocorrected typos is within 10% of its events per
typo there but four: a first letter left out, 0.24 per hundred typos and 0.45 simulated; an
extra key beside the first letter, 0.17 and 0.22; an extra farther letter in the middle, 0.46
and 0.39; and an extra farther letter last, 1.19 and 1.33. A second mistake is in 18.8% of the
simulated typos with a letter mistake, and the share of words mistyped at each length is within
5% of ITE's.

A first simulator matched the kinds of mistakes in text typed without autocorrection instead.
Its typos had 42% neighbor-key substitutions and 12% with a second mistake, and rankers trained
on them missed two such typos on the 400-sentence plan, "amf" for "and" and "rge" for "the":
1,163 mistyped words fixed against the bundled rankers' 1,165, and 18 changed to another word
against 16.

### What is simulated

`simulation_sentences.py` picks one in ten of the Tatoeba sentences and OASST1 message
fragments the counts are made from, by a hash of their words, never one ITE typists copied:
222,814 sentences. `write_simulated_records.py` types each three times, as three typists:

- 196,156 words typed differently from the word meant, the corrections;
- 87,026 words typed as meant that no dictionary or SCOWL size-50 word spells, which the action
  model learns to leave alone;
- 196,738 completions: words picked at random, typed as far as ITE typists had typed a word of
  that length when they picked its completion, mistakes included.

The counts the rankers train with leave out the sentences ITE typists copied, so a typed word's
context is as new to them as it is to the keyboard. Trained on simulated typing they leave out
the simulated sentences the same way; the LatinIME dictionary, which the keyboard bundles,
still counts them.

### What the harness can tell apart

The keyboard's correction does not follow the correction ranker's order:
`NoisyChannelCorrector` scores every candidate itself. The ranker only picks which 8 of LatinIME's
up to 32 candidates and the single-edit candidates the corrector sees, and the candidate caches
ask LatinIME for 8. Nothing in the package reads the autocorrect decision model's probability.
So the correction measures move only when a ranker keeps or drops the intended word from those
8, a few words a plan; the completion ranker's order is what the suggestion bar shows.

## Results

Built with the commands above, the three `.kvtr` files and `accent_overlay.bin` are the same
bytes as the ones built in July 2026 that the package bundles, and the dictionary is the
bundled one apart from the write times in its header. The July dictionary held the same words,
word pairs, and three-word sequences with the same probabilities as this build; its bytes
differed only in the order entries were written, from a few sentences whose state in the July
export cannot be recovered, and the package now bundles this build's dictionary.
`Tools/KeyVoxTypingHarness` scored the built files the same as the July files on every measure.

The harness scored the bundled rankers and three trained with caches asked without
`--as-bundled`: on ITE's typing (`ite`), on simulated typing alone (`sim`), and on both
(`sim+ite`):

| Measure | Plan | Bundled | `ite` | `sim` | `sim+ite` |
| --- | --- | --- | --- | --- | --- |
| Final words correct | 80 sentences, noise 0.3 (`compare`) | 96.1% (909/946) | 96.1% (909) | 96.3% (911)† | 96.1% (909)† |
| Final words correct | 400 sentences, noise 0.25 (`evaluate`) | 98.7% | 98.6% | 98.7%† | 98.6%† |
| Mistyped words fixed | 400 | 94.7% (1,165/1,230) | 94.6% (1,163) | 94.9% (1,167)† | 94.6% (1,164)† |
| Mistyped words changed to a different word | 400 | 1.3% (16) | 1.5% (18) | 1.1% (14)† | 1.4% (17)† |
| Correctly typed words wrongly changed | 400 | 0.0% (0/3,760) | 0.0% | 0.0%† | 0.0%† |
| Completion offered within 2 letters | 400 | 50.5% | 51.5% | 58.8%† | 58.9%† |
| Completion keystroke savings | 400 | 39.9% | 40.7% | 41.9%† | 41.8%† |
| Suggestion bar shows the word within 3 letters | 400 | 85.3% | 85.3% | 85.7%† | 85.6%† |
| Next word first / in top 3 | 400 | 9.0% / 21.3% | same | same† | same† |
| Final words correct | ITE held-out typists, 3,000 sentences (`evaluate`) | 98.2% (`compare`: 98.3%) | same | same | same |
| Mistyped words fixed | ITE | 55.9% (326/583) | same | same | same |
| Mistyped words changed to a different word | ITE | 10.1% (59) | same | same | same |
| Correctly typed words wrongly changed | ITE | 0.5% (97/21,130) | same | same | same |
| Completion offered within 2 letters | ITE | 51.6% | 51.9% | 60.6% | 60.8% |
| Completion keystroke savings | ITE | 37.6% | 37.7% | 40.4% | 40.2% |
| Suggestion bar shows the word within 3 letters | ITE | 84.8% | 84.8% | 84.7% | 84.8% |
| Next word first / in top 3 | ITE | 15.5% / 26.5% | same | same | same |

† Rankers trained on the simulator before each word drew its randomness from a stream of its own;
the rankers trained on the current simulator score the same as those on every ITE measure above
but the completion lines, which moved by at most 0.8 points.

Only the speed lines differ between runs. The rankers trained on ITE fix two fewer mistyped
words on the 400-sentence plan than the bundled ones and change two more to another word, so
the package keeps the bundled ones. The rankers trained on simulated typing alone fix as many
mistyped words and wrongly change as few correct ones as the bundled rankers on both plans that
count them, and offer completions sooner; the suggestion bar shows the word within 3 letters on 0.1 points fewer
of ITE's words. That proves the simulator for training other languages' rankers.

To score built files, copy the harness's release build and put the built files in the copy's
`KeyVoxPredictiveKeyboard_KeyVoxPredictiveKeyboard.bundle/Contents/Resources/PredictiveData/en`;
the copy reads its own bundle. The ITE plan is made with
`Tools/KeyVoxTypingHarness/Scripts/ite_typo_plan.py <data-dir>/sources/ite/processed2020/english <plan.json> --split holdout --max-sentences 3000`.

## Checking typing changes

The harness plans above, of 80 to 3,000 sentences, measure accuracy when a model is trained or
retuned. They are not how a change to typing is verified: that is the typing regression check in
`KeyVoxPredictiveKeyboard`'s package tests (`iOS/Docs/ENGINEERING.md`, "Typing Regression
Check"), a small fixed set of typing cases for every bundled typing language, typed through the
typing session as `compare` types a plan, which fails naming the case and the word or suggestion
bar that came out differently:

```bash
cd Packages/KeyVoxPredictiveKeyboard
swift test --scratch-path /tmp/keyvox-predictive-keyboard-test-clean --filter TypingRegressionTests
```

When a change is meant to change typing, such as built files replacing bundled ones, record the
new outcomes and review the diff of each language's `expected.jsonl`, one line per case:

```bash
KEYVOX_RECORD_TYPING_REGRESSION=1 swift test --scratch-path /tmp/keyvox-predictive-keyboard-test-clean --filter TypingRegressionTests
```

## Other typing languages

`typing_languages.py` lists the typing languages and what differs between them; every step that
depends on the language takes `--language` (default `en`), and `--language-file` to read the
language's `language.json` from outside the package, for a language the package does not ship yet.
From that file the tools read the default letter layout, whose keys the suggestion reader and the
typo simulator tap, and the vowels the action model's rule for short words uses, and from the
`held_key_characters.txt` beside it, when the language has one, the letters each key offers on a
long press. German, Spanish, and French are built from what `Tools/KeyVoxLanguageModel` built for
them, and their rankers learn from simulated typing alone, as no typing dataset like ITE exists for
them:

| | English | German, Spanish, French |
| --- | --- | --- |
| Dictionary words | SCOWL size 60, American | The language build's vocabulary (`built/vocabulary.txt`: the AOSP LatinIME word list with its capitals settled), in lowercase |
| Probabilities, pairs, and sequences | Tatoeba and OASST1, less the sentences ITE typists copied | The language build's `counts.npz`, of every source it reads, less the held-out simulation sentences |
| Words never corrected | The dictionary's and SCOWL size 50's | The dictionary's and the vocabulary's common part (`built/common_vocabulary.txt`) |
| Words left out | The profanity list's English terms (`offensive_words.py`) | German and French: Multilingual HateCheck's slurs; Spanish: none yet (see "Words left out") |
| Accent overlay | 262 accented SCOWL words the dictionary lacks | Empty: the dictionary holds the accented words, and LatinIME finds them from their plain letters |
| Dictionary header | Locale `en_US` | Locale `de`, `es`, or `fr`, as the AOSP word list's header; German also asks for umlaut processing, as AOSP's German list does, so "ue" types "ü" |
| Typing the rankers learn from | ITE | Simulated on the language's sentences and letter layout, with the English calibration |
| Held out | ITE's sentence buckets 8-9 | The simulated sentence buckets 8-9, which the dictionary and the rankers' word counts leave out |

A language's data directory links in two directories, besides the Python environment:

```bash
mkdir -p <data-dir>/sources
ln -s <language-build> <data-dir>/sources/language-build
ln -s <english-sim-dir>/work/simulation <data-dir>/sources/typo-calibration
PYTHON=<venv>/bin/python ./build_typing_models.sh <data-dir> --language de \
  --language-file <language.json>
```

`<language-build>` is the data directory of `Tools/KeyVoxLanguageModel`'s build of the language,
with its `vocabulary.txt`, `counts.npz`, `sentences/`, and `built/vocabulary.txt` and
`built/common_vocabulary.txt`; `download_sources.py` records their SHA-256 in
`sources/checksums.txt`, beside the language's Multilingual HateCheck dataset, if it has one, which
it downloads. `<english-sim-dir>` is an English data directory after the simulator's
steps of "Training on simulated typing" through `compare_simulated_typing.py`, whose
`work/simulation` holds `ite_typing.json` and `typo_calibration.json`. In place of the English
ranker steps, the build then runs, with `--language`:

| Step | Writes |
| --- | --- |
| `measure_accent_typing.py` | `work/simulation/accent_typing.json`: how often each letter without a key is typed plain |
| `write_simulated_records.py --calibration <data-dir>/sources/typo-calibration` | `work/simulation/corrections.tsv`, `preserves.tsv`, `completions.tsv`, and `typed_words.json`, the words typed and mistyped in each bucket |
| `write_feature_context_model.py` | `work/feature_context_800k.bin`, from the language build's counts less every simulation sentence |
| the caches and the trainers | as for English, with `--source sim`, which they default to for another language; the caches ask `work/counted_dictionary/` |

The steps hold the language build's counts in memory: French's dictionary inputs took 13 GB at
their peak.

### What the simulator types

`simulation_sentences.py` picks a third of the sentences of the language build's Tatoeba and
OASST2 sentences, the written sources spelled with care, as English's are Tatoeba and OASST1, by
the same hash of their words. Each is typed three times, as for English.

ITE's typists' fingers are taken to be anyone's: the touch spreads, mistake rates, length factors,
and sloppiness calibrated on ITE carry over, in key pitches, to the language's letter layout. What
is the language's own is measured:

- How often each letter is meant at each place in a word, which the spread's miss rates are
  weighed over, from the simulation sentences.
- Where an extra key beside a letter sits: on another layout than ITE's QWERTY, the extra key is
  drawn by where ITE's extra keys beside a letter sat from it, among the places the layout has a
  key, so QWERTY's extra "x" after "z" is a "u" on German's QWERTZ.
- How often a letter without a key is typed plain (`measure_accent_typing.py`). Such a letter is
  typed with a long press on the key whose long-press list offers it, from the language's
  `held_key_characters.txt`, as the keyboard aims a popup letter at the key that offers it; a
  letter no list offers, or a language without the file, takes the first key of its plain
  spelling. A letter's plain spelling comes from Unicode: its base letters with its accents left
  off ("e" for "é"), or, for a letter with no accent to leave off, its case folding ("ss" for
  German "ß"). The simulator taps that key: a tap landing on it types the letter, or its plain
  spelling at the measured rate, and a tap on another key types that key's letter. A letter
  neither gives a key, such as French "œ" without a long-press list, is typed as spelled. The rule
  is one, `letter_keys.py`, so the suggestion reader taps such a letter on the same key
  (`--key-for`), and a letter it gives no key at the origin, as the keyboard's engine taps a letter
  its keys lack when it is given no touches. The rate is measured in the language build's WildChat
  turns, the one source of text people typed in every language, over the dictionary words with one
  such letter whose plain spelling is no dictionary word: how often WildChat writes each spelling. A
  letter seen fewer than 200 times takes the rate of every such letter together.

Letters with a key of their own, German "ü", "ö", and "ä" and Spanish "ñ", are tapped as any other
key: WildChat leaves them plain in 0.8% to 2.7% of their words, while it leaves out a missing key's
accent far more often.

| Language | Letters without a key, typed plain in WildChat |
| --- | --- |
| de | "ß" as "ss" 9.1% of 1,002 words; the others together 11.3% |
| es | "á" 43.2%, "é" 45.9%, "í" 45.3%, "ó" 36.9%, "ú" 50.2%; the others together 41.8% |
| fr | "é" 14.7%, "è" 15.4%, "ê" 15.4%, "ç" 19.2%, "à" 19.6%, "ô" 18.8%, "â" 41.7%, "û" 37.5%, "ï" 54.8%; the others together 15.5% |

WildChat is typed mostly on computers, whose German and French keyboards have keys for most of
these letters; 88milSMS, French text messages typed on phones in 2011, leaves "é" plain in 32.3%
of its words and "ç" in 44.9%, so the French rates may be low for phone typing.

### Words left out

German and French dictionaries leave out the slurs of the language's Multilingual HateCheck
dataset, the test cases of hateful sentences built around a slur (`slur_h`), each tagged
with the group its slur targets (`hatecheck_slurs.py`). The groups left out are the ones English's
left-out tags name: Black, immigrant, Indigenous, gay, trans, Jewish, and Muslim people
(`offensive_words.LEFT_OUT_TARGETS`). Slurs against women and disabled people stay, as English's
list tags them apart. A case whose template marks its slur, `[SLR_S]` or `[SLR_P]`, gives the slur
as the words the placeholder stands for; the other cases of a template differ only in their slur
and the article or adjective before it, so a case's slur is its word where they differ most. Each
form the cases write, singular and plural, is a pattern of its own, so the forms come from the
dataset and no ending is added; a form is matched as English's are, by its letter form, so an
unaccented spelling of a slur is left out with it. Slurs of several words are left aside, as no
word is one.

Spanish leaves no word out yet: its dataset's slurs for those groups include words in everyday use,
some written thousands of times in the Spanish build's text, and no data source tells those apart
from the slurs.

| Language | Forms the dataset gives | Dictionary words left out |
| --- | --- | --- |
| de | 12 | 4 |
| fr | 20 | 10, and the 3 word pairs that hold one |

The forms come from the pinned datasets (`sources.py`) and are written, as patterns, to
`work/offensive_words.txt` at build time; this README does not repeat them. The other forms are no
dictionary word. The datasets give no case of a slur used as an everyday word: their only
non-hateful cases with a slur quote it or speak against it (`counter_quote_nh`, `counter_ref_nh`),
for every slur alike.

German's capitalized spellings (`Tools/KeyVoxLanguageModel`, "Words spelled with capitals") leave
out the same words, read from this build's `work/offensive_words.txt` with `--leave-out`.

The dictionary leaves out the words, and the caches ask the dictionary as counted, with them, so
the rankers are as they would be without the list, as English's bundled rankers are; the
measures below are the same with and without it.

### Features of letters outside ASCII

The keyboard's engine computes the rankers' and the action model's features over the words' UTF-8
bytes: lengths, edit distances, shared beginnings and endings, first and last letters, and repeated
letters (`KeyVoxPredictiveNative.cpp`). `ranker_features.py` computes them the same way, so a
letter such as "é" counts two bytes in both; for English's ASCII words bytes and letters are the
same. Only the rule that a word of four letters or fewer needs a vowel counts letters, with the
language's `vowels`.

### Measured on simulated typing

Built on November 27, 2026 from the language builds of November 24, with `language.json` files
kept outside the package (German on `QWERTZ-German`, Spanish on `QWERTY-Spanish`, French on
`AZERTY-French`, with their accented vowels as vowels); each build took about 15 minutes, with the
others running beside it. German's, Spanish's, and French's bundled files are later builds (see
"German", "Spanish's bundled files", and "French through the keyboard").


| | de | es | fr |
| --- | --- | --- | --- |
| Dictionary words | 205,875 | 236,188 | 163,620 |
| Word pairs, three-word sequences | 160,000, 60,000 | 160,000, 60,000 | 159,997, 60,000 |
| `dictionary.body` | 9,780,288 bytes | 10,215,079 bytes | 8,533,024 bytes |
| `correction_ranker.kvtr`, `completion_ranker.kvtr`, `autocorrect_decision.kvtr` | 218,260, 218,260, 74,260 bytes | the same | the same |
| `accent_overlay.bin` | 12 bytes, no entries | the same | the same |
| Simulation sentences | 224,318 | 177,956 | 219,215 |
| Corrections, words typed as meant, completions simulated | 187,302, 142,845, 196,814 | 400,497, 164,733, 194,895 | 313,951, 52,778, 192,085 |

Measured on the held-out simulation sentences, buckets 8-9, by the trainers' reports
(`work/reports/correction_models.json` and `completion_ranker.json`), with English's ITE held-out
report from the bundled build beside them; English's is real typing and the others' simulated, so
the columns compare a language's simulated typing with English's real typing, not like with like.
Ranking is of the intended word among LatinIME's 8 candidates:

| Measure | de | es | fr | en (ITE) |
| --- | --- | --- | --- | --- |
| Correction: intended word among the 8 candidates | 91.9% | 95.1% | 96.2% | 97.9% |
| Correction: first, LatinIME's order / reranked | 77.2% / 83.0% | 89.4% / 91.2% | 86.3% / 91.0% | 85.3% / 90.1% |
| Correction: in the top 3, reranked | 91.3% | 94.9% | 95.8% | 96.9% |
| Completion: intended word among the 8 candidates | 61.7% | 48.7% | 52.5% | 83.4% |
| Completion: first, LatinIME's order / reranked | 23.1% / 43.8% | 16.6% / 35.7% | 19.4% / 40.1% | 38.6% / 55.4% |
| Completion: in the top 3, reranked | 57.8% | 45.7% | 50.1% | 76.5% |
| Plausible typos fixed by the action model at 0.9 | 36.3% | 50.9% | 58.8% | 45.2% |

Every word of the held-out sentences, acting at each threshold (`held_out_words`): the words typed,
1,011,150 German, 997,230 Spanish, and 968,274 French, of which 3.7%, 8.0%, and 6.4% were mistyped,
and 5,138, 19,613, and 11,727 of those were typed as another word the action model never replaces,
such as Spanish "esta" for "está":

| Threshold | Measure | de | es | fr |
| --- | --- | --- | --- | --- |
| 0.9 | Final words correct | 97.51% | 95.78% | 96.99% |
| 0.9 | Mistyped words fixed (of those not typed as a word) | 33.7% (39.0%) | 48.8% (64.7%) | 53.7% (66.2%) |
| 0.9 | Mistyped words changed to another word | 0.39% | 0.27% | 0.42% |
| 0.9 | Correctly typed words wrongly changed | 0.036% | 0.125% | 0.041% |
| 0.95 | Final words correct | 97.14% | 94.81% | 96.63% |
| 0.95 | Mistyped words fixed (of those not typed as a word) | 23.3% (27.0%) | 36.1% (47.9%) | 47.9% (59.0%) |
| 0.95 | Mistyped words changed to another word | 0.15% | 0.09% | 0.25% |
| 0.95 | Correctly typed words wrongly changed | 0.017% | 0.075% | 0.027% |
| none | Final words correct, as typed | 96.29% | 91.98% | 93.59% |

These are the trainers' measures: the keyboard corrects with `NoisyChannelCorrector`, which reads
the rankers' choice of candidates but not the action model's probability (see "What the harness can
tell apart"), and `Tools/KeyVoxTypingHarness` scored English only at the time (see "German" for
the keyboard's own scores). They show the rankers learn the
language, ranking the intended word first more often than LatinIME alone does, and give a baseline
to hold later builds to.

### French through the keyboard

`Tools/KeyVoxTypingHarness` typed French through the bundled French files and the typing session,
with `--language fr`, on November 27, 2026. Its corpus is the Tatoeba texts of the French simulation
sentences in held-out buckets 8-9, which the dictionary's counts and the rankers leave out, as Tatoeba
writes them (41,622 sentences); its plans are 400 sentences at noise 0.25 and 80 at noise 0.3, seed 1,
and a zero-noise plan of the 45 Tatoeba sentences Apple's French keyboard was measured typing, with
Apple's results beside them. English's bundled measures from "Results" are beside French's; their
sentences differ, so the columns compare the languages, not like with like.

| Measure | Plan | fr | en |
| --- | --- | --- | --- |
| Final words correct | 80 sentences, noise 0.3 (`compare`) | 92.7% (458/494) | 96.1% (909/946) |
| Final words correct | 400 sentences, noise 0.25 (`compare`) | 97.0% (2,732/2,817) | |
| Final words correct | 400 (`evaluate`) | 97.7% | 98.7% |
| Mistyped words fixed | 400 | 93.2% (613/658) | 94.7% (1,165/1,230) |
| Mistyped words changed to a different word | 400 | 3.2% (21) | 1.3% (16) |
| Correctly typed words wrongly changed | 400 | 0.4% (9/2,004) | 0.0% (0/3,760) |
| Contractions typed without the apostrophe, restored | 400 | 92.9% (144/155) | |
| Completion offered within 2 letters | 400 | 60.5% | 50.5% |
| Completion keystroke savings | 400 | 41.3% | 39.9% |
| Suggestion bar shows the word within 3 letters | 400 | 80.0% | 85.3% |
| Next word first / in top 3 | 400 | 12.4% / 23.7% | 9.0% / 21.3% |
| Final words correct, Apple / KeyVox | Apple's 45 French Tatoeba sentences, no noise (`compare --apple`) | 93.6% / 94.6% (277 / 280 of 296) | |

In `compare`, the plan's taps that land on the AZERTY-French accent key, beside "n", type what the
keyboard's accent key would, or the letter beside it when the contested-tap rule gives the tap to the
letter; an apostrophe the accent key types records its tap, as on the keyboard, so an elided word's
taps keep lining up with its letters. `evaluate` types each letter on the letter key nearest its tap, as it does beside every
other key, so its taps never reach the accent key, and the engine is handed the letter keys alone,
as the keyboard hands them. A letter picked from a popup is tapped on the key held to pick it, as the
keyboard records it.

The weights of the contested-tap rule and of the corrector were also searched on French plans of
300 sentences at noise 0.3 from the corpus less the measured plans' sentences: no value of the
contested-tap weights moved 4,282 words by more than 10, and the corrector's tuned weights gained one
word of 2,153 on the plan held out, so French keeps the shared weights. Of the French words of those
plans and the 80-sentence plan, 0.9% have their first letter tapped onto the space bar, as 0.85% of
English's do, which a space before a word keeps as a space in every language, and 1.9% a later
letter, 1.3% of English's.

French's bundled dictionary was built again on November 28, 2026 with these tools and French's
`language.json` in the package, so it leaves out the Multilingual HateCheck slurs (see "Words left
out"): 163,620 words, 10 fewer, and 3 fewer word pairs. French's bundled rankers, autocorrect
decision model, and accent overlay are the ones built before, whose rankers were trained on typing
the simulator drew before it drew each word's randomness from a stream of its own (see "The
simulator"). The harness typed the bundled files with the new dictionary and with the earlier one on
plans of the same kind, from a corpus of the 41,179 Tatoeba texts that are each one French
simulation sentence of buckets 8-9: 400 sentences at noise 0.25 and 80 at noise 0.3, seed 1, and 400
at noise 0.3, seed 2, each with `--language fr` and with `--language fr-CA`. Every measure was the
same with either dictionary.

Rankers trained again with these tools, which draw each word's randomness from its own stream, moved
a few measures down on the same plans, so the bundled rankers were kept:

| Measure | Plan | Bundled rankers | Trained again |
| --- | --- | --- | --- |
| Final words correct | `fr`, 400 sentences, noise 0.3, seed 2 (`compare`) | 94.1% (2,685/2,854) | 94.0% (2,682) |
| Completion offered within 2 letters | `fr`, 400 sentences, noise 0.25 (`evaluate`) | 60.8% | 60.7% |
| Top-3 completions show the word before space | `fr`, 400 | 91.2% | 91.1% |
| Completion offered within 2 / 3 letters | `fr-CA`, 400 sentences, noise 0.25 (`evaluate`) | 60.5% / 76.9% | 60.2% / 76.6% |
| Top-3 completions show the word before space | `fr-CA`, 400 | 91.1% | 91.0% |
| Suggestion bar shows the word within 2 letters | `fr-CA`, 400 | 62.5% | 62.4% |

On the other plans they typed one word more correctly or the same, and on `fr-CA`'s 400-sentence
`evaluate` fixed one more mistyped word and changed one fewer to another word.

On November 28, 2026 the harness was corrected to type the accent key as the keyboard does (above),
which changes what `evaluate` types, so its measures since are a new baseline. With the corrected
harness, the keyboard and package from before the accent key's fixes, an apostrophe it typed
recording no tap as that keyboard did, and from after them typed the same plans: every `evaluate`
measure was the same, and every `compare` plan the same but `fr`'s 400 sentences at noise 0.3, seed 2,
where the fixed keyboard typed one word more correctly (2,685 of 2,854 against 2,684). The baseline,
with the bundled files above:

| Measure | Plan | `fr` | `fr-CA` |
| --- | --- | --- | --- |
| Final words correct | 400 sentences, noise 0.25 (`compare`) | 97.0% (2,883/2,971) | 97.0% (2,882/2,971) |
| Final words correct | 80 sentences, noise 0.3 (`compare`) | 92.6% (560/605) | 91.4% (553/605) |
| Final words correct | 400 sentences, noise 0.3, seed 2 (`compare`) | 94.1% (2,685/2,854) | 93.9% (2,681/2,854) |
| Final words correct | 400, noise 0.25 (`evaluate`) | 97.8% | 97.7% |
| Mistyped words fixed | 400 | 93.3% (643/689) | 92.8% (646/696) |
| Mistyped words changed to a different word | 400 | 3.5% (24) | 3.9% (27) |
| Correctly typed words wrongly changed | 400 | 0.5% (10/2,133) | 0.5% (10/2,126) |
| Contractions typed without the apostrophe, restored | 400 | 94.0% (140/149) | 94.6% (141/149) |
| Completion offered within 2 letters | 400 | 60.8% | 60.5% |
| Completion keystroke savings | 400 | 41.3% | 41.3% |
| Top-3 completions show the word before space | 400 | 91.2% | 91.0% |
| Suggestion bar shows the word within 3 letters | 400 | 79.7% | 79.5% |
| Next word first / in top 3 | 400 | 12.7% / 22.8% | 12.7% / 22.8% |

### French (Canada) through the keyboard

French (Canada) (`PredictiveData/fr-CA`) types with France's dictionary, rankers, autocorrect
decision model, and word lists (`sharedDataFolder`), on Apple's French (Canada) default layout,
QWERTY-Accents. Whether it needs data of its own was measured on November 27, 2026 on Canadian
French the models never saw: the Leipzig Corpora Collection's `fra-ca_web_2020_1M` (CC BY), web
text crawled from Canadian sites in 2020, beside its France counterpart `fra-fr_web_2013_1M`, both
filtered the same way to sentences a phone user could type as written (4 to 20 words; letters,
apostrophes, hyphens, and `, . ? ! ; :` only; a capital first and `.`, `?`, or `!` last; at least two
common French words; no word in capitals throughout): 350,587 Canadian and 376,738 France sentences.

France's dictionary holds 98.25% of the Canadian text's words and 97.41% of the France text's, read
as the keyboard reads words (an apostrophe inside, a hyphen between). Of the 410 words written at
least eight times as often in the Canadian text, 55 are not in it, most of them crawl artifacts and
place names; Canadian words such as "courriel", "cégep", "magasiner", and "dépanneur" are in it,
while "condo", "locateur", and "postsecondaire" are in the language build's vocabulary but below the
dictionary's cut.

The harness typed the same plans, seed 1 and seed 2, with `--language fr-CA` and with the same taps
as `fr` on AZERTY-French:

| Measure | Plan | fr-CA | same taps as fr |
| --- | --- | --- | --- |
| Final words correct | Canadian, 400 sentences, noise 0.25 (`compare`) | 96.9% (5,203/5,369) | 97.0% (5,207/5,369) |
| Final words correct | Canadian, 80 sentences, noise 0.3 | 93.1% (938/1,007) | 93.3% (940/1,007) |
| Final words correct | Canadian, 400 sentences, noise 0.3, seed 2 | 93.4% (4,952/5,300) | 93.2% (4,937/5,300) |
| Final words correct | French's Tatoeba plan, 400 sentences, noise 0.25 | 97.1% (2,736/2,817) | 97.0% (2,732/2,817) |
| Final words correct | French's Tatoeba plan, 80 sentences, noise 0.3 | 91.5% (452/494) | 92.7% (458/494) |
| Final words correct | Tatoeba, 400 sentences, noise 0.3, seed 2 | 93.6% (2,699/2,884) | 93.5% (2,696/2,884) |
| Final words correct | Canadian, 400 (`evaluate`) | 97.4% | 97.6% |
| Mistyped words fixed | Canadian, 400 | 93.2% (1,382/1,483) | 93.6% (1,383/1,478) |
| Correctly typed words wrongly changed | Canadian, 400 | 0.5% (19/3,675) | 0.5% (18/3,682) |
| Contractions typed without the apostrophe, restored | Canadian, 400 | 91.9% (194/211) | 92.8% (194/209) |
| Completion keystroke savings | Canadian, 400 | 42.4% | 42.2% |
| Next word first / in top 3 | Canadian, 400 | 12.2% / 22.1% | 12.2% / 22.1% |

The same finger offsets fall on other neighboring keys on QWERTY-Accents than on AZERTY-French, so
the two columns differ by which slips are made (`evaluate` draws 1,483 and 1,478 mistyped words), not
by the data; the words each gets wrong differ both ways, and on the 400-sentence plans neither layout
leads by more than 0.2 points. France typed `fr`'s plans of its own web text at 96.2% (noise 0.25) and
91.4% (noise 0.3), below its Canadian results, so French (Canada) keeps France's data.

The German vocabulary of that build lacks most words that begin with "ä", "ö", or "ü", as the AOSP
German word list it is built from does: "überhaupt" (52,006 times in the German build's counts),
"ändern", "öffnen", and "öffentlich" are not in its dictionary, nor 51 more such words written at
least 1,000 times each, 255,706 times in all. The list holds only 44 lowercase words beginning with
"ü". German's vocabulary now adds the lexicon words its sentences write as often as the list's own
words (`Tools/KeyVoxLanguageModel`, "Vocabulary").

### German

The bundled German files (`PredictiveData/de`) are built from the German language build of November
27, 2026, which reads German's `language.json` in the package and adds the written lexicon words and
contractions, with the typo calibration of "Training on simulated typing" (`typo_calibration.json`
of its calibrated run). The dictionary was built later that day with these tools, so it leaves out
the 4 dictionary words Multilingual HateCheck's German slurs match ("Words left out"). The
correction and completion rankers, the autocorrect decision model, and the accent overlay are those
of the build of November 27, whose typo simulator drew every word's mistakes from one stream of
randomness, before it drew each word's from a stream of its own:

| | de |
| --- | --- |
| Dictionary words | 218,341 |
| Word pairs, three-word sequences | 160,000, 60,000 |
| `dictionary.body` | 10,154,232 bytes |
| `accent_overlay.bin` | 12 bytes, no entries |
| Simulation sentences | 224,023 |
| Corrections, words typed as meant, completions simulated | 184,877, 82,573, 196,849 |

The rankers learn from the dictionary as counted, with the words it leaves out ("Words left out"),
so the dictionary without them leaves every measure below the same: with the earlier dictionary and
with this one, the bundled rankers type every plan below word for word alike. These tools, with the
simulator's single stream put back, rebuild the bundled correction and completion rankers byte for
byte. Retrained with the simulator as it is now, each word's own stream gives the rankers other
mistakes to learn from, and the measures below move by a few words or a few tenths of a point either
way. Of 12 retrained draws (`write_simulated_records.py`'s seed), none matched the bundled rankers
on every measure, on the plans below or on 2,500 more held-out sentences outside them, so the
bundled rankers were kept. A German build with these tools therefore writes the bundled dictionary,
while `compare_with_bundled.py` reports the three rankers as different.

`Tools/KeyVoxTypingHarness` scored them through the keyboard's own typing path (`--language de`) on
plans of German Tatoeba sentences from the held-out simulation buckets 8-9, which the dictionary and
the rankers never counted, mapped back to their Tatoeba originals for their capitals: 39,596
sentences, of which a plan takes 80, 400, or 3,000 at random (seed 1, or 7 for 3,000). The
dictionary without the written lexicon words (the vocabulary of 209,470 spellings) is beside it:

| Measure | Plan | Without the written lexicon words | Bundled |
| --- | --- | --- | --- |
| Final words correct | 80 sentences, noise 0.3 (`compare`) | 91.2% (560/614) | 93.2% (572) |
| Final words correct | 400 sentences, noise 0.25 (`compare`) | 95.9% (2,706/2,822) | 96.8% (2,731) |
| Final words correct | 400 (`evaluate`) | 96.5% | 97.1% |
| Mistyped words fixed | 400 | 88.8% (660/743) | 90.8% (675) |
| Mistyped words changed to a different word | 400 | 5.8% (43) | 3.9% (29) |
| Correctly typed words wrongly changed | 400 | 0.6% (13/2,077) | 0.7% (14) |
| Completion offered within 2 letters | 400 | 62.7% | 63.2% |
| Completion keystroke savings | 400 | 42.0% | 42.8% |
| Suggestion bar shows the word within 3 letters | 400 | 75.5% | 76.3% |
| Next word first / in top 3 | 400 | 9.7% / 18.7% | 10.4% / 19.5% |
| Words the corpus capitalizes after a sentence's first, written so | 400 (`compare`) | 82.7% (386/467) | 82.7% (392/474) |
| Words the corpus writes in lowercase, capitalized | 400 (`compare`) | 0.1% (1/1,851) | 0.1% (1/1,868) |
| Contractions typed without the apostrophe, restored | 400 (`evaluate`) | 0 of 2 | 2 of 2 |
| Final words correct | 3,000 sentences, noise 0.25 (`compare`) | | 97.0% (21,263/21,914) |
| Mistyped words fixed / changed to a different word | 3,000 (`evaluate`) | | 93.0% / 2.6% (of 6,365) |
| Correctly typed words wrongly changed | 3,000 | | 0.6% (91/15,542) |
| Contractions typed without the apostrophe, restored | 3,000 | | 6 of 7 |
| Completion offered within 2 letters / keystroke savings | 3,000 | | 61.9% / 42.7% |

With the contractions the dictionary now holds (`Tools/KeyVoxLanguageModel`, "Vocabulary"), the
3,000-sentence plan restores 6 of its 7 contractions typed without their apostrophe, from none, and
fixes 2 more mistyped words, while completions come within 2 letters on 61.9% of its words, from
62.4%. The bundled column is with the touch scorer aiming a letter that has a key of its own, as German's
umlauts do, at that key; the other column was measured before, when every umlaut was aimed at its
plain vowel's key, which also turned a correctly tapped sentence-first "über" into "aber".

On the 45 Tatoeba sentences Apple's German keyboard was measured typing on the iOS 27.2 simulator,
typed as Apple's were, at the keys' centers and in lowercase, both keyboards end with 308 of the 309
words right: Apple writes "Charkiw" as "Charlie", and KeyVox "ungekocht" as "gekocht". KeyVox writes
55 of the 61 words capitalized after a sentence's first with their capitals, and capitalizes 1 of
the 202 written in lowercase; Apple writes 56 of its 60 such words with their capitals and
capitalizes none of the 203 lowercase ones. Those sentences are in the language data the context
model is counted from, so KeyVox knows their words' contexts.

### Spanish's bundled files

The Spanish files bundled in `PredictiveData/es`, which Latin American Spanish (`PredictiveData/es-419`)
uses too, were built on November 27, 2026 with the package's own `es/language.json`, from a Spanish
language build whose counts take the written sources 20 times (`count_weights` in
`Tools/KeyVoxLanguageModel/languages.py`; `language_build.Counts` takes the held-out sentences out as
many times). Their rankers were trained by the simulator before it drew each word's randomness from a
stream of its own.

Rebuilt on November 28 with the current tools, the dictionary came out with the same words, counts,
and bytes but for the build time in its header, and the accent overlay the same. The retrained
rankers moved each measure by a word or a tenth of a point either way, as each typing draw does:
across the default draw and fifteen others, none scored as well as the bundled rankers on every
measure of the plans below and of two selection plans drawn from the held-out sentences the plans
leave out (2,000 sentences at noise 0.25 and 500 at noise 0.3). The bundled dictionary, rankers, and
accent overlay were kept.

`Tools/KeyVoxTypingHarness` scored the bundled files through the keyboard's engine, typed from the
Spanish simulation sentences of the held-out buckets 8-9 (35,575 sentences, which the dictionary and
the rankers leave out), from WildChat sentences typed in Latin America and in Spain
(`Tools/KeyVoxLanguageModel/README.md`, "Latin American Spanish"), and from the 45 Tatoeba sentences
typed into Apple's Spanish (Spain) and Spanish (Latin America) keyboards on an iOS 27.2 simulator, as
Apple was given them: accents left out, lowercase, inverted marks left out. Noise is the touch spread
in key pitches. Every plan was scored with a context model counted from the language build's text
less every measured sentence, as the bundled context model has seen them:

| Measure | Plan | es | es-419 |
| --- | --- | --- | --- |
| Final words correct | Held-out, 80 sentences, noise 0.3 (`compare`) | 93.2% (712/764) | |
| Mistyped words fixed | Held-out, 400 sentences, noise 0.25 (`evaluate`) | 92.8% (814/877) | |
| Mistyped words changed to a different word | Held-out, 400 | 3.3% (29) | |
| Correctly typed words wrongly changed | Held-out, 400 | 0.4% (11/2,718) | |
| Completion offered within 2 letters / keystroke savings | Held-out, 400 | 54.1% / 40.9% | |
| Suggestion bar shows the word within 3 letters | Held-out, 400 | 76.7% | |
| Next word first / in top 3 | Held-out, 400 | 15.3% / 26.7% | |
| Final words correct | Apple's 45 sentences, no noise (`compare --apple`) | 95.8% (253/264); Apple's Spain keyboard 97.3% (257/264) | 95.8% (253/264); Apple's Latin American keyboard 97.0% (256/264) |
| Final words correct | Latin America, 160 sentences, noise 0.3 | 93.8% (1,441/1,537) | the same |
| Mistyped words fixed / changed to a different word | Latin America, 800 sentences, noise 0.25 | 94.8% (1,856/1,957) / 2.9% (56) | the same |
| Correctly typed words wrongly changed | Latin America, 800 | 0.2% (8/5,192) | the same |
| Completion offered within 2 letters / bar within 3 letters | Latin America, 800 | 52.7% / 75.4% | the same |
| Final words correct | Spain, 160 sentences, noise 0.3 | 92.9% (1,478/1,591) | |
| Mistyped words fixed / changed to a different word | Spain, 800 sentences, noise 0.25 | 94.6% (1,920/2,029) / 3.0% (60) | |

Latin American Spanish types with the same files and rules for words, so it scores as Spanish does on
every plan it was typed on.
