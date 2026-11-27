# KeyVox Typing Models

Builds the typing models the predictive keyboard bundles for a typing language: those of its
English typing language in
`Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/en`, and the
same files for German, Spanish, and French, which are built but not bundled yet (see "Other typing
languages"). English's:

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
| `write_dictionary_inputs.py`, then `bin/write_latinime_dictionary` | `work/dictionary_unigrams.tsv` and `work/dictionary_ngrams.tsv`, every word and sequence counted, which the later steps and `Tools/KeyVoxLanguageModel` read, and `work/counted_dictionary/`, compiled from them, which the caches ask with `--as-bundled`; `work/dictionary_kept_*.tsv`, the same less the words `offensive_words.txt` matches and every sequence holding one, and `built/dictionary/`, compiled from those with the language's locale and header attributes (`typing_languages.py`) |
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
after everything it typed for the letters before it.

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

`calibrate_typo_simulator.py` sets the simulator so that its mistakes, measured with
`typo_kinds.py`, match two of ITE's measurements: how often a word of each length is mistyped,
from text typed without autocorrection, the only typing that shows it; and what a typo is made
of, each kind's events per typo and the share with a second mistake, from the typos left for
autocorrection. Typists who rely on autocorrection leave far more slips of a finger than typists
who fix their own: neighbor-key substitutions are 67% of a typo's mistakes there, and 45% of
the mistakes in text typed without it. Twelve rounds of typing the ITE words, measuring, and
moving each setting by its gap give spreads of 0.186 to 0.197 key pitches across and 0.153 to
0.170 down, a gamma shape of 0.069, and length factors of 0.47 for two letters, 0.54 for four,
1.16 for eight, and 2.83 for twelve or more (2.57 for one letter). Measured with another seed,
every kind seen at least 200 times among the autocorrected typos is within 10% of its events per
typo there but three of the rarest: a first letter left out, 0.24 per hundred typos and 0.42
simulated; an extra key beside the first letter, 0.17 and 0.23; and an extra key beside the
last letter, 0.21 and 0.19. A second mistake is in 18.4% of the simulated typos with a letter
mistake, and the share of words mistyped at each length is within 6% of ITE's, but for
one-letter words, 0.09% and 0.10%.

A first simulator matched the kinds of mistakes in text typed without autocorrection instead.
Its typos had 42% neighbor-key substitutions and 12% with a second mistake, and rankers trained
on them missed two such typos on the 400-sentence plan, "amf" for "and" and "rge" for "the":
1,163 mistyped words fixed against the bundled rankers' 1,165, and 18 changed to another word
against 16.

### What is simulated

`simulation_sentences.py` picks one in ten of the Tatoeba sentences and OASST1 message
fragments the counts are made from, by a hash of their words, never one ITE typists copied:
222,814 sentences. `write_simulated_records.py` types each three times, as three typists:

- 196,366 words typed differently from the word meant, the corrections;
- 87,110 words typed as meant that no dictionary or SCOWL size-50 word spells, which the action
  model learns to leave alone;
- 196,748 completions: words picked at random, typed as far as ITE typists had typed a word of
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
| Final words correct | 80 sentences, noise 0.3 (`compare`) | 96.1% (909/946) | 96.1% (909) | 96.3% (911) | 96.1% (909) |
| Final words correct | 400 sentences, noise 0.25 (`evaluate`) | 98.7% | 98.6% | 98.7% | 98.6% |
| Mistyped words fixed | 400 | 94.7% (1,165/1,230) | 94.6% (1,163) | 94.9% (1,167) | 94.6% (1,164) |
| Mistyped words changed to a different word | 400 | 1.3% (16) | 1.5% (18) | 1.1% (14) | 1.4% (17) |
| Correctly typed words wrongly changed | 400 | 0.0% (0/3,760) | 0.0% | 0.0% | 0.0% |
| Completion offered within 2 letters | 400 | 50.5% | 51.5% | 58.8% | 58.9% |
| Completion keystroke savings | 400 | 39.9% | 40.7% | 41.9% | 41.8% |
| Suggestion bar shows the word within 3 letters | 400 | 85.3% | 85.3% | 85.7% | 85.6% |
| Next word first / in top 3 | 400 | 9.0% / 21.3% | same | same | same |
| Final words correct | ITE held-out typists, 3,000 sentences (`evaluate`) | 98.2% (`compare`: 98.3%) | same | same | same |
| Mistyped words fixed | ITE | 55.9% (326/583) | same | same | same |
| Mistyped words changed to a different word | ITE | 10.1% (59) | same | same | same |
| Correctly typed words wrongly changed | ITE | 0.5% (97/21,130) | same | same | same |
| Completion offered within 2 letters | ITE | 51.6% | 51.9% | 61.4% | 60.1% |
| Completion keystroke savings | ITE | 37.6% | 37.7% | 40.5% | 40.0% |
| Suggestion bar shows the word within 3 letters | ITE | 84.8% | 84.8% | 84.7% | 84.8% |
| Next word first / in top 3 | ITE | 15.5% / 26.5% | same | same | same |

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

## Other typing languages

`typing_languages.py` lists the typing languages and what differs between them; every step that
depends on the language takes `--language` (default `en`), and `--language-file` to read the
language's `language.json` from outside the package, for a language the package does not ship yet.
From that file the tools read the default letter layout, whose keys the suggestion reader and the
typo simulator tap, and the vowels the action model's rule for short words uses. German, Spanish,
and French are built from what `Tools/KeyVoxLanguageModel` built for them, and their rankers learn
from simulated typing alone, as no typing dataset like ITE exists for them:

| | English | German, Spanish, French |
| --- | --- | --- |
| Dictionary words | SCOWL size 60, American | The language build's vocabulary (`built/vocabulary.txt`: the AOSP LatinIME word list with its capitals settled), in lowercase |
| Probabilities, pairs, and sequences | Tatoeba and OASST1, less the sentences ITE typists copied | The language build's `counts.npz`, of every source it reads, less the held-out simulation sentences |
| Words never corrected | The dictionary's and SCOWL size 50's | The dictionary's and the vocabulary's common part (`built/common_vocabulary.txt`) |
| Words left out | The profanity list's English terms (`offensive_words.py`) | None: the pinned profanity list has English terms alone |
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
`sources/checksums.txt`. `<english-sim-dir>` is an English data directory after the simulator's
steps of "Training on simulated typing" through `compare_simulated_typing.py`, whose
`work/simulation` holds `ite_typing.json` and `typo_calibration.json`. In place of the English
ranker steps, the build then runs, with `--language`:

| Step | Writes |
| --- | --- |
| `measure_accent_typing.py` | `work/simulation/accent_typing.json`: how often each letter without a key is typed plain |
| `write_simulated_records.py --calibration <data-dir>/sources/typo-calibration` | `work/simulation/corrections.tsv`, `preserves.tsv`, `completions.tsv`, and `typed_words.json`, the words typed and mistyped in each bucket |
| `write_feature_context_model.py` | `work/feature_context_800k.bin`, from the language build's counts less every simulation sentence |
| the caches and the trainers | as for English, with `--source sim`, which they default to for another language |

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
  typed with a long press on its base letter's key, so the simulator taps that key: a tap landing
  on it types the letter, or its plain spelling at the measured rate ("e" for "é", "ss" for German
  "ß"), and a tap on another key types that key's letter. The rate is measured in the language
  build's WildChat turns, the one source of text people typed in every language, over the
  dictionary words with one such letter whose plain spelling is no dictionary word: how often
  WildChat writes each spelling. A letter seen fewer than 200 times takes the rate of every such
  letter together.

Letters with a key of their own, German "ü", "ö", and "ä" and Spanish "ñ", are tapped as any other
key: WildChat leaves them plain in 0.8% to 2.7% of their words, while it leaves out a missing key's
accent far more often.

| Language | Letters without a key, typed plain in WildChat |
| --- | --- |
| de | "ß" as "ss" 9.1% of 1,002 words; the others together 11.3% |
| es | "á" 43.2%, "é" 45.9%, "í" 45.3%, "ó" 36.9%, "ú" 50.2%; the others together 41.8% |
| fr | "é" 14.7%, "è" 15.4%, "ê" 15.4%, "ç" 19.2%, "à" 19.6%, "ô" 18.8%, "â" 41.7%, "û" 37.5%, "ï" 54.8%; the others together 15.6% |

WildChat is typed mostly on computers, whose German and French keyboards have keys for most of
these letters; 88milSMS, French text messages typed on phones in 2011, leaves "é" plain in 32.3%
of its words and "ç" in 44.9%, so the French rates may be low for phone typing.

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
`AZERTY-French`, with their accented vowels as vowels); each build took about 13 minutes. None is
bundled.

| | de | es | fr |
| --- | --- | --- | --- |
| Dictionary words | 205,879 | 236,188 | 163,630 |
| Word pairs, three-word sequences | 160,000, 60,000 | 160,000, 60,000 | 160,000, 60,000 |
| `dictionary.body` | 9,780,366 bytes | 10,215,079 bytes | 8,533,339 bytes |
| `correction_ranker.kvtr`, `completion_ranker.kvtr`, `autocorrect_decision.kvtr` | 218,260, 218,260, 74,260 bytes | the same | the same |
| `accent_overlay.bin` | 12 bytes, no entries | the same | the same |
| Simulation sentences | 224,318 | 177,956 | 219,215 |
| Corrections, words typed as meant, completions simulated | 185,331, 142,998, 196,813 | 398,821, 164,851, 194,941 | 314,625, 52,926, 192,056 |

Measured on the held-out simulation sentences, buckets 8-9, by the trainers' reports
(`work/reports/correction_models.json` and `completion_ranker.json`), with English's ITE held-out
report from the bundled build beside them; English's is real typing and the others' simulated, so
the columns compare a language's simulated typing with English's real typing, not like with like.
Ranking is of the intended word among LatinIME's 8 candidates:

| Measure | de | es | fr | en (ITE) |
| --- | --- | --- | --- | --- |
| Correction: intended word among the 8 candidates | 91.7% | 95.2% | 95.9% | 97.9% |
| Correction: first, LatinIME's order / reranked | 76.6% / 82.5% | 89.5% / 91.3% | 86.2% / 90.7% | 85.3% / 90.1% |
| Correction: in the top 3, reranked | 91.0% | 94.9% | 95.6% | 96.9% |
| Completion: intended word among the 8 candidates | 61.7% | 48.6% | 52.6% | 83.4% |
| Completion: first, LatinIME's order / reranked | 23.1% / 43.7% | 16.5% / 35.6% | 19.5% / 40.3% | 38.6% / 55.4% |
| Completion: in the top 3, reranked | 57.9% | 45.5% | 50.2% | 76.5% |
| Plausible typos fixed by the action model at 0.9 | 36.6% | 50.4% | 59.3% | 45.2% |

Every word of the held-out sentences, acting at each threshold (`held_out_words`): the words typed,
1,011,150 German, 997,230 Spanish, and 968,274 French, of which 3.7%, 8.0%, and 6.4% were mistyped,
and 5,211, 19,692, and 12,059 of those were typed as another word the action model never replaces,
such as Spanish "esta" for "está":

| Threshold | Measure | de | es | fr |
| --- | --- | --- | --- | --- |
| 0.9 | Final words correct | 97.54% | 95.78% | 97.01% |
| 0.9 | Mistyped words fixed (of those not typed as a word) | 34.1% (39.6%) | 48.4% (64.4%) | 54.2% (67.2%) |
| 0.9 | Mistyped words changed to another word | 0.38% | 0.28% | 0.44% |
| 0.9 | Correctly typed words wrongly changed | 0.034% | 0.121% | 0.041% |
| 0.95 | Final words correct | 97.18% | 94.76% | 96.63% |
| 0.95 | Mistyped words fixed (of those not typed as a word) | 23.7% (27.6%) | 35.0% (46.5%) | 48.1% (59.6%) |
| 0.95 | Mistyped words changed to another word | 0.13% | 0.09% | 0.19% |
| 0.95 | Correctly typed words wrongly changed | 0.017% | 0.064% | 0.025% |
| none | Final words correct, as typed | 96.32% | 92.03% | 93.56% |

These are the trainers' measures: the keyboard corrects with `NoisyChannelCorrector`, which reads
the rankers' choice of candidates but not the action model's probability (see "What the harness can
tell apart"), and `Tools/KeyVoxTypingHarness` scores English only. They show the rankers learn the
language, ranking the intended word first more often than LatinIME alone does, and give a baseline
to hold later builds to.

The German vocabulary lacks most words that begin with "ä", "ö", or "ü", as the AOSP German word
list it is built from does: "überhaupt" (52,006 times in the German build's counts), "ändern",
"öffnen", and "öffentlich" are not in the dictionary, nor 51 more such words written at least 1,000
times each, 255,706 times in all. The list holds only 44 lowercase words beginning with "ü".
