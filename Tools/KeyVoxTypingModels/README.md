# KeyVox Typing Models

Builds the English typing models the predictive keyboard bundles in
`Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData`:

| Bundled file | What it is | Built by |
| --- | --- | --- |
| `candidate_v3_dict/` | LatinIME version 403 dictionary: 106,973 words with probabilities, 93,385 word pairs, and 60,000 three-word sequences | `write_dictionary_inputs.py`, `write_latinime_dictionary.cpp` |
| `production_ranker_800k.kvtr` | 220 gradient-boosted trees that score each correction candidate | `train_correction_models.py`, `export_tree_models.py` |
| `production_action_800k.kvtr` | 160 trees that score whether to replace the typed letters with the best correction | `train_correction_models.py`, `export_tree_models.py` |
| `production_completion_ranker_800k.kvtr` | 220 trees that score each candidate while a word is still being typed | `train_completion_ranker.py`, `export_tree_models.py` |
| `accent_overlay.bin` | 262 accented words the dictionary lacks, by the plain letters that type them | `write_accent_words.py`, `write_accent_overlay.py` |

The context model, `context_artifact_800k.bin`, and the word lists are built by
`Tools/KeyVoxLanguageModel`.

## Sources

Every input is pinned in `sources.py` or `scowl_word_list.sh` and credited in
`THIRD_PARTY_NOTICES.md`.

| Source | Used for | Pinned to | License |
| --- | --- | --- | --- |
| [SCOWL](https://github.com/en-wl/wordlist) | The dictionary's words (size 60, American, variant level 2), accented words (size 60, every spelling), and words never corrected (size 50, every spelling) | Commit `1e5b7d3a72f47a71da5d28686c1dd4b397178485`, archive SHA-256 checked | ESDB permissive notice |
| [Tatoeba](https://tatoeba.org/en/downloads) | Word, word-pair, and three-word counts | The English export and the contribution log, rewound to the export of 2026-07-18 06:00 | CC BY 2.0 FR |
| [OpenAssistant OASST1](https://huggingface.co/datasets/OpenAssistant/oasst1) | Word, word-pair, and three-word counts | Revision `fdf72ae0827c1cda404aff25b6603abec9e3399b` | Apache 2.0 |
| [Aalto ITE Typing dataset](https://doi.org/10.5281/zenodo.12528163) | The typing events the rankers learn from, and the sentences left out of the counts | Zenodo record 12528163; five files are read from the archive by byte range | CC BY 4.0 |
| [AOSP LatinIME](https://android.googlesource.com/platform/packages/inputmethods/LatinIME/) | Writing and reading the dictionary | The native sources bundled in `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveNative/latinime`, compiled unchanged | Apache 2.0 |

Tatoeba publishes only its current export. `rewind_tatoeba.py` turns it back into the export
of the pinned cutoff: every sentence the contribution log added, edited, or deleted after the
cutoff gets its state as of the cutoff. Rewinding the 2026-11-21 export to 2026-10-03 this way
matched the real 2026-10-03 export with no sentence missing or changed, and kept 7 sentences
beyond its 2,038,137, because the export also hides sentences for reasons the log does not
record. `sources.py` lists the sentences hidden or shown at the
pinned cutoff other than the log implies: the ones the bundled dictionary's probabilities point
to. The probabilities cannot tell "He is sure of success." from "He is sure of winning.";
either gives the same probabilities, and the pinned one gives the results below.

## Building

The data directory needs about 1 GB, plus the Python environment.

```bash
python3.14 -m venv <data-dir>/venv
<data-dir>/venv/bin/pip install -r requirements.txt
PYTHON=<data-dir>/venv/bin/python ./build_typing_models.sh <data-dir>
```

The built files land in `<data-dir>/built`; the package is left alone. Once the sources are
downloaded, the build takes about 12 minutes on an Apple silicon Mac. Set `OMP_NUM_THREADS` to
limit the cores the tree training uses.

`requirements.txt` pins the versions the bundled files were built with, on Python 3.14.
The LatinIME tools are compiled with the Xcode command line tools.

`latinime_suggestions.cpp` orders candidates of equal score with `std::sort`, which leaves
the order of ties to the C++ standard library. With Apple clang 21 (macOS 27) the candidates
come out in the order the bundled rankers were trained on; Apple clang 15 (macOS 13) orders
8,485 of the 84,720 correction queries' ties differently, and the trained rankers differ.
Every other step gives the same bytes on either.

## Steps

`build_typing_models.sh` runs them in this order:

| Step | Writes |
| --- | --- |
| `download_sources.py` | `sources/`, with each file's SHA-256 in `sources/checksums.txt` |
| `build_native_tools.sh` | `bin/write_latinime_dictionary`, `bin/latinime_suggestions` |
| `rewind_tatoeba.py` | `work/tatoeba_eng_sentences_at_cutoff.tsv.bz2` |
| `scowl_word_list.sh` | `work/scowl-*.txt` |
| `write_dictionary_inputs.py`, then `bin/write_latinime_dictionary` | `work/dictionary_*.tsv`, `built/candidate_v3_dict/` |
| `split_ite_events.py` | `work/ite/`: autocorrections, words left alone, and accepted predictions, split by typist |
| `write_feature_context_model.py` | `work/feature_context_800k.bin`: the word and word-pair counts the rankers train with |
| `cache_correction_candidates.py`, `cache_completion_candidates.py` | `work/*_candidates.pkl.gz`: LatinIME's candidates for every training query |
| `train_correction_models.py`, `train_completion_ranker.py` | `work/*.pkl.gz` and held-out reports in `work/reports/` |
| `export_tree_models.py` | `built/*.kvtr`, checked against the trained models on 10,000 rows |
| `write_accent_words.py`, `write_accent_overlay.py` | `built/accent_overlay.bin` |

The rankers train on records split by the sentence the typist was copying, so a sentence's
words are never on both sides of a training and test split.

## Results

Built with the commands above, the three `.kvtr` files and `accent_overlay.bin` are the same
bytes as the ones built in July 2026 that the package bundles. The July dictionary held the
same words, word pairs, and three-word sequences with the same probabilities as this build;
its bytes differed only in the order entries were written, from a few sentences whose state in
the July export cannot be recovered. The package now bundles this build's dictionary, so a
rebuild writes the same body, with new write times in its header.

`Tools/KeyVoxTypingHarness` scored the built files the same as the July files on every
measure:

| Measure | 80 sentences, noise 0.3 (`compare`) | 400 sentences, noise 0.25 (`evaluate`) | ITE held-out typists, 3,000 sentences (`evaluate`) |
| --- | --- | --- | --- |
| Final words correct | 96.1% | 98.7% | 98.2% (`compare`: 98.3%) |
| Mistyped words fixed | | 94.7% | 55.9% |
| Mistyped words changed to a different word | | 1.3% | 10.1% |
| Correctly typed words wrongly changed | | 0.0% | 0.5% |
| Completion offered within 2 letters | | 50.5% | 51.6% |
| Completion keystroke savings | | 39.9% | 37.6% |
| Suggestion bar shows the word within 3 letters | | 85.3% | 84.8% |
| Next word first / in top 3 | | 9.0% / 21.3% | 15.5% / 26.5% |

Only the speed lines differ between runs.

To score built files, copy the harness's release build and put the built files in the copy's
`KeyVoxPredictiveKeyboard_KeyVoxPredictiveKeyboard.bundle/Contents/Resources/PredictiveData`;
the copy reads its own bundle. The ITE plan is made with
`Tools/KeyVoxTypingHarness/Scripts/ite_typo_plan.py <data-dir>/sources/ite/processed2020/english <plan.json> --split holdout --max-sentences 3000`.
