# KeyVox Typing Models

Builds the typing models the predictive keyboard bundles for its English typing language in
`Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/en`:

| Bundled file | What it is | Built by |
| --- | --- | --- |
| `dictionary/` | LatinIME version 403 dictionary, in `dictionary.header` and `dictionary.body`: 106,973 words with probabilities, 93,385 word pairs, and 60,000 three-word sequences | `write_dictionary_inputs.py`, `write_latinime_dictionary.cpp` |
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

The built files land in `<data-dir>/built` under the names they have in `PredictiveData/en`,
and `compare_with_bundled.py` then says for each whether it is the same as the bundled one,
leaving out the write times in the dictionary header; with `--check` after the data directory,
the build fails if any differs. The package is left alone. The dictionary and the accent
overlay are the bundled bytes; the three `.kvtr` files are not, because the build now asks
LatinIME for every record the rankers read, each in a search of its own (see "How the bundled
rankers were trained"). Once the sources are
downloaded, the build takes about 12 minutes on an Apple silicon Mac. Set `OMP_NUM_THREADS` to
limit the cores the tree training uses.

`requirements.txt` pins the versions the bundled files were built with, on Python 3.14.
The LatinIME tools are compiled with the Xcode command line tools.

`latinime_suggestions.cpp` orders candidates of equal score with `std::sort`, which leaves
the order of ties to the C++ standard library. The rankers are trained on the order that Apple
clang 21.0.0 (clang-2100.3.34.1) with libc++ 220106 (macOS 27.2 SDK) gives;
`build_native_tools.sh` checks for exactly that compiler and libc++ version and stops with a
message naming both on any other toolchain. Apple clang 15.0.0 with libc++ 160006 (macOS 13),
for one, orders 8,485 of the July build's 84,720 correction queries' ties differently, and the
trained rankers differ. Every other step gives the same bytes on either.

Each query searches in a LatinIME session of its own. A session continues its last search when
the new typed letters start with the last ones, and keeps that search's previous words, so a
shared session answers a query for the one asked before it: "woll" after "we finished is" gets
"will" at 758,130 asked alone and at 547,122 asked right after "woll" after "korea's south".

## Steps

`build_typing_models.sh` runs them in this order:

| Step | Writes |
| --- | --- |
| `download_sources.py` | `sources/`, with each file's SHA-256 in `sources/checksums.txt` |
| `build_native_tools.sh` | `bin/write_latinime_dictionary`, `bin/latinime_suggestions` |
| `rewind_tatoeba.py` | `sources/tatoeba/eng_sentences_at_cutoff.tsv.bz2`, checked against its recorded SHA-256 |
| `scowl_word_list.sh` | `work/scowl-*.txt` |
| `write_dictionary_inputs.py`, then `bin/write_latinime_dictionary` | `work/dictionary_*.tsv`, `built/dictionary/` |
| `split_ite_events.py` | `work/ite/`: autocorrections, words left alone, and accepted predictions, split by typist |
| `write_feature_context_model.py` | `work/feature_context_800k.bin`: the word and word-pair counts the rankers train with |
| `cache_correction_candidates.py`, `cache_completion_candidates.py` | `work/*_candidates.pkl.gz`: LatinIME's candidates for every record `training_sets.py` gives the trainers |
| `train_correction_models.py`, `train_completion_ranker.py` | `work/*.pkl.gz` and held-out reports in `work/reports/` |
| `export_tree_models.py` | `built/*.kvtr`, checked against the trained models on 10,000 rows |
| `write_accent_words.py`, `write_accent_overlay.py` | `built/accent_overlay.bin` |
| `compare_with_bundled.py` | A line per built file: same as the bundled one or not |

The rankers train on records split by the sentence the typist was copying, so a sentence's
words are never on both sides of a training and test split. `training_sets.py` gives the
records each trainer reads, and the candidate caches ask for exactly those: buckets 0-4 train
the correction ranker, bucket 5 the action model, 0-7 the completion ranker, and 8-9 are held
out. The caches and the trainers take `--source`: `ite`, the default, trains on ITE's typing,
`sim` on simulated typing, and `sim+ite` on both (see "Training on simulated typing"); the
held-out reports are on ITE's buckets 8-9 whatever the source.

## How the bundled rankers were trained

The bundled rankers were trained in July 2026 by scripts that asked LatinIME for other records
than the trainers read, in one shared search session:

- The cache asked for a fifth of the calibration typists' plausible autocorrections, sampled
  after keeping the plausible ones (49,041 records). The trainer sampled a fifth first and kept
  the plausible ones after (49,196 records), so it read records the cache never asked for.
- The cache never asked for the held-out typists' wrong autocorrections, the records with the
  word the logged keyboard chose. The trainer read them, and only those whose query another
  record asked kept candidates.
- Every query searched in the same session, so 870 of the 84,720 correction queries and 218 of
  the 51,165 completion queries got the answer for the query asked before them; asked each in a
  session of its own, they answer differently.

A record whose query was never asked got no candidates and was left out, as was one whose
cached candidates were only the typed letters or two-word suggestions. What each set trained or
was measured on:

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

The build now asks for every record the trainers read, each in its own session, and leaves out
only records whose candidates are the typed letters or two-word suggestions:

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

The package keeps the July rankers: the rankers this build trains fix two fewer mistyped words
on the 400-sentence plan and change two more to another word (see "Results"), and replacing
them needs every headline measure at least as good.

## Training on simulated typing

German, Spanish, and French have no typing dataset like ITE, so their rankers have to learn from
simulated typing mistakes. English has both, so the method is proven on English: rankers
trained on simulated typing alone are scored against the ones trained on ITE.

The simulator is measured and calibrated against ITE, then types sentences from the pipeline's
own sources. Its steps are not part of `build_typing_models.sh`; after a build, in the same data
directory:

| Step | Writes |
| --- | --- |
| `measure_ite_typing.py` | `work/simulation/ite_typing.json`: ITE's typing mistakes, the letters typists meant, and how far they typed before picking a completion |
| `fit_touch_spread.py` | `work/simulation/touch_spread.json`: touch spreads that give ITE's substitutions of neighboring keys |
| `calibrate_typo_simulator.py` | `work/simulation/typo_calibration.json`: the simulator's spreads, rates, length factors, and sloppiness shape |
| `compare_simulated_typing.py` | `work/simulation/comparison.json`: the simulator's mistakes against ITE's, with another seed |
| `write_simulated_records.py` | `work/simulation/corrections.tsv`, `preserves.tsv`, `completions.tsv`: records in the shape `split_ite_events.py` writes |
| `write_feature_context_model.py --leave-out-simulation-sentences` | `work/feature_context_800k.bin` without the sentences the simulator types |

Then run the candidate caches, the trainers, and `export_tree_models.py` with `--source sim`
or `--source sim+ite`, in a copy of the data directory, since they write the same files as an
ITE build.

### What is measured

- Mistakes left in text: the 2,299,794 words of 312,804 phone sections typed with
  autocorrection and suggestions off, picked as `Tools/KeyVoxTypingHarness/Scripts/ite_typo_plan.py`
  picks the harness's ITE plan but only from the 42,913 typists that plan never holds out
  (`ite_copied_typing.py`). 2.57% of the words were typed with a letter wrong, left out, or
  extra; 3,496 typed as a
  different word, more than four edits or more than half the word, are not mistakes of typing
  and are left out. Longer words get more per letter: 1.2% of two-letter words, 2.2% of
  four-letter words, and 10.2% of words of twelve letters or more were mistyped.
- Typos left for autocorrection: the 248,603 plausible autocorrections of the same typists,
  the typos the logged keyboards fixed or tried to fix, the ones a correction ranker learns from.
- Completions: how many letters the same typists had typed when they picked a suggested
  completion, for each length of word, from 161,423 picked completions.

`typo_kinds.py` sorts each difference between a typed and an intended word into substitutions
of the key beside in the row, of an overlapping key in the row above or below, and of a farther
key, left-out letters, one letter of a double letter left out, doubled letters, extra keys
beside a letter and extra farther letters, swapped neighbors, and dropped apostrophes; letter
kinds by place in the word, first, middle, or last.

### The simulator

`letter_layout.py` reads a typing language's letter keys from its letter rows through one
function, `letter_rows`, today from the package's `language.json`: each key a square one key
pitch across and down, as `LetterKeyLayout` lays them out.

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

Mistakes bunch up: in text typed without autocorrection, 11.4% of the words with a letter
mistake have a second one, where independent mistakes at the measured rates give 1.5%, and
18.8% of the typos left for autocorrection do. So each word gets a sloppiness, its
length's factor times a draw from a gamma distribution of mean one; the word's mistake rates are
multiplied by it, and its taps spread wider by as much as makes them miss that many times more
often (`typo_simulator.py`). The other kinds happen at their own rates per chance, and farther
substitutions and extra letters are drawn from the ones ITE typists made at the same letter.

`calibrate_typo_simulator.py` sets the simulator so that its mistakes, measured with
`typo_kinds.py`, match two of ITE's measurements: how often a word of each length is mistyped,
from text typed without autocorrection, the only typing that shows it; and what a typo is made
of, each kind's events per typo and the share with a second mistake, from the typos left for
autocorrection. Typists who rely on autocorrection leave far more slips of a finger than typists
who fix their own: neighbor-key substitutions are 66% of a typo's mistakes there, and 46% of
the mistakes in text typed without it. Twelve rounds
of typing the ITE words, measuring, and moving each setting by its gap give spreads of 0.187 to
0.197 key pitches across and 0.154 to 0.169 down, a gamma shape of 0.069, and length factors of
0.49 for two letters, 0.55 for four, 1.19 for eight, and 2.6 for twelve or more (2.8 for one
letter). Measured with another seed, every kind seen at least 200 times among the autocorrected
typos is within 10% of its events per typo there but three of the rarest: a first letter left
out, 0.25 per hundred typos and 0.47 simulated; a doubled letter counted at the first letter,
0.08 and 0.12; and an extra key beside the last letter, 0.21 and 0.18. A second mistake is in
18.9% of the simulated typos with a letter mistake, and the share of words mistyped at each
length is within 5% of ITE's.

A first simulator matched the kinds of mistakes in text typed without autocorrection instead.
Its typos had 42% neighbor-key substitutions and 12% with a second mistake, and rankers trained
on them missed two such typos on the 400-sentence plan, "amf" for "and" and "rge" for "the":
1,163 mistyped words fixed against the bundled rankers' 1,165, and 18 changed to another word
against 16.

### What is simulated

`simulation_sentences.py` picks one in ten of the Tatoeba sentences and OASST1 message
fragments the counts are made from, by a hash of their words, never one ITE typists copied:
222,814 sentences. `write_simulated_records.py` types each three times, as three typists:

- 198,715 words typed differently from the word meant, the corrections;
- 86,936 words typed as meant that no dictionary or SCOWL size-50 word spells, which the action
  model learns to leave alone;
- 196,791 completions: words picked at random, typed as far as ITE typists had typed a word of
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

Built with the commands above, the dictionary and `accent_overlay.bin` are the bundled bytes,
apart from the write times in the dictionary header. The July dictionary held the same words,
word pairs, and three-word sequences with the same probabilities as this build; its bytes
differed only in the order entries were written, from a few sentences whose state in the July
export cannot be recovered, and the package now bundles this build's dictionary. Before the
caches asked for every record each in its own session, the three `.kvtr` files were the bundled
bytes too, and `Tools/KeyVoxTypingHarness` scored them the same as the July files on every
measure.

The harness scored the bundled rankers and three trained ones: on ITE's typing (`ite`), on
simulated typing alone (`sim`), and on both (`sim+ite`):

| Measure | Plan | Bundled | `ite` | `sim` | `sim+ite` |
| --- | --- | --- | --- | --- | --- |
| Final words correct | 80 sentences, noise 0.3 (`compare`) | 96.1% (909/946) | 96.1% (909) | 96.2% (910) | 96.1% (909) |
| Final words correct | 400 sentences, noise 0.25 (`evaluate`) | 98.7% | 98.6% | 98.7% | 98.6% |
| Mistyped words fixed | 400 | 94.7% (1,165/1,230) | 94.6% (1,163) | 94.8% (1,166) | 94.6% (1,164) |
| Mistyped words changed to a different word | 400 | 1.3% (16) | 1.5% (18) | 1.2% (15) | 1.4% (17) |
| Correctly typed words wrongly changed | 400 | 0.0% (0/3,760) | 0.0% | 0.0% | 0.0% |
| Completion offered within 2 letters | 400 | 50.5% | 51.5% | 57.5% | 57.8% |
| Completion keystroke savings | 400 | 39.9% | 40.7% | 42.3% | 41.5% |
| Suggestion bar shows the word within 3 letters | 400 | 85.3% | 85.3% | 85.6% | 85.7% |
| Next word first / in top 3 | 400 | 9.0% / 21.3% | same | same | same |
| Final words correct | ITE held-out typists, 3,000 sentences (`evaluate`) | 98.2% (`compare`: 98.3%) | same | same | same |
| Mistyped words fixed | ITE | 55.9% (326/583) | same | same | same |
| Mistyped words changed to a different word | ITE | 10.1% (59) | same | same | same |
| Correctly typed words wrongly changed | ITE | 0.5% (97/21,130) | same | same | same |
| Completion offered within 2 letters | ITE | 51.6% | 51.9% | 60.5% | 61.0% |
| Completion keystroke savings | ITE | 37.6% | 37.7% | 40.4% | 40.2% |
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
