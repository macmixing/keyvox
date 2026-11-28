# KeyVox Swipe Model

Trains, tunes, exports, and measures KeyVox's own swipe (gesture) typing model: a small
neural encoder that reads a finger path over any keyboard layout and scores that layout's
keys frame by frame, decoded into words of a typing language's swipe lexicon. The approach
follows the published description in *FUTO Swipe: Layout-Agnostic Neural Swipe Decoding*
(Miller and Kostarevas, arXiv 2606.25247); the code is KeyVox's own.

The bundled English model (`Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/en/swipe_encoder.kvsw`
and `swipe.json`, no decoder) is run `r3-ft2`: the width-144 encoder `r3-w144-aug50-extra`
after two ranking fine-tunes. Its `swipe_encoder.kvsw` is byte for byte the file
`export_weights.py` writes for `r3-ft2` (SHA-256 `6aea857c…cdc6`). On swipe.futo.org's
English test split it decodes 92.56% of swipes to the swiped word first (see "Results").
German, French, and Spanish bundle one encoder of their own, `r3-ft2` fine-tuned once more on
swipes moved onto the keyboard's other letter layouts (see "Other typing languages").

Data, trained weights, and results live in a data directory outside the repository, never
in it.

## Pipeline

| Step | Tool | Writes |
| --- | --- | --- |
| Download the pinned recordings | `download_sources.py` | `sources/`, `sources/manifest.json` |
| Resample every swipe | `prepare_swipes.py` | `prepared/{train,val,test,extra,layouts}.npz` |
| Train an encoder with CTC | `train.py` | `models/<run>/best.pt`, `log.jsonl` |
| Decode a split, cache candidates | `evaluate.py` | `models/<run>/candidates-<split>.npz`, `results-<split>.json` |
| Tune the rescoring weights | `tune_scoring.py` | `models/<run>/scoring.json` |
| Fine-tune with the ranking objective | `finetune_encoder.py` | a new run |
| Train the optional decoder | `train_decoder.py` | a decoder run |
| Export the weights | `export_weights.py` | `swipe_encoder.kvsw` (and `swipe_decoder.kvsd`) |
| Write the harness's input | `write_harness_swipes.py` | `<split>` swipes with the words before them |
| Move swipes onto other layouts | `warp_layout_swipes.py` | `prepared/<name>-{train,val}.npz` |
| Fine-tune for ranking on several layouts | `rank_layouts.py` | a new run |

The shared modules: `words.py` (letters and key paths), `layouts.py`, `lexicon.py` (word
list and key-path trie), `swipe_data.py`, `model.py`, `augment.py`, `ranking.py`,
`decode.py` with `beam_search.c`, `scoring.py`, `emissions.py`, `run_emissions.py`,
`run_settings.py`, `decoder_model.py`, `weights_format.py`, `exported_model.py`, `layout_warp.py`
(moving a swipe from one layout's keys to another's), and `layout_swipes.py` (swipes of several
layouts as tensors).

## Data

Every source is pinned in `sources.py` with its license and attribution;
`download_sources.py` records each file's size, SHA-256, and row count.

| Source | Used for | Swipes |
| --- | --- | --- |
| [swipe.futo.org](https://huggingface.co/datasets/futo-org/swipe.futo.org) first run, `train.jsonl` | Training | 939,550 |
| swipe.futo.org first run, `dev.jsonl` | Validation: tuning and choosing | 54,269 |
| swipe.futo.org first run, `test.jsonl` | Test, measured once per final model | 49,970 |
| swipe.futo.org later runs, English on QWERTY, one finger | Extra training (`--extra`) | 128,112 kept |
| swipe.futo.org swipe-5, English on other layouts | Layout check, never trained on | 15,655 |
| [How We Swipe](https://osf.io/sj67f/) | Downloaded, not used | 1,338 session logs |

Both are MIT-licensed; swipe.futo.org is pinned to revision
`d71bf5fd7f45b3e7c2ed2d76a21b0dbd3b4ba566`.

- The first run's official splits are kept as released. Training never sees the validation or
  test swipes; validation chooses checkpoints and tunes weights, and test is measured only for
  a model chosen on validation.
- The later runs are released unfiltered. `prepare_swipes.py` keeps a swipe only when its
  `distance` is scored (the recordings mark unscored swipes with 100,000 or more) and at most
  the 99th percentile of the first run's scored training distances (134.7). Kept: swipe-2
  24,212 of 28,095, swipe-3 35,009 of 38,228, swipe-4 43,763 of 50,300, swipe-5 25,128 of
  56,539.
- The layout check holds swipe-5's English swipes on ClearFlow (11,503), Dvorak (2,250),
  KASROZ (1,047), QWERTZ (759), and AZERTY (96). swipe-5's German, French, and Spanish swipes
  are never trained on; `write_harness_swipes.py` writes them only to measure (see "Other typing
  languages").
- How We Swipe's logs give touch positions in pixels and the keyboard's size but not where
  its keys are, so they cannot be paired with a layout.

**Preparation.** `prepare_swipes.py` resamples every swipe to 64 points evenly spaced in time
by linear interpolation, in the keyboard's normalized frame (0 to 1 across and down), and keeps
the recorded word. Training uses every swipe whose word has a key path that fits the model's
32 output frames: 1,067,608 of the first run's training swipes and the extra ones together, and
54,268 validation swipes for the validation loss.

## Lexicon

A swipe draws letters only, so `words.py` reduces each word to its swipe form (letters only,
case folded, accents folded onto their base letter) and its key path, with consecutive
repeated keys collapsed into one by default. Spellings that share a form are one entry with
the highest probability.

The lexicon is the keyboard's: the bundled dictionary's words with their 0 to 255 probability
and the swipe vocabulary's words, written as a word list by the typing harness:

```bash
KeyVoxTypingHarness swipe-lexicon --output <swipe_lexicon.kvsl> --words <unigrams.tsv>
```

The bundled model was fine-tuned and its scoring tuned with the 129,438-word lexicon (106,973
dictionary words and 22,465 swipe-vocabulary words; 121,643 forms), which covers 96.51% of
validation swipes and 96.48% of test swipes. The bundled lexicon now has 133,226 words (125,443
forms): 3,860 words of swipe.futo.org's training sentences that the dictionary and the other
vocabulary words lacked were added (`Tools/KeyVoxLanguageModel/README.md`, "Swipe vocabulary"),
and the 73 words the dictionary and the swipe vocabulary leave out as offensive
(`Tools/KeyVoxTypingModels/offensive_words.py`) were taken out, the swiped word of no validation
swipe and of 2 test swipes. It covers 96.93% of validation swipes and 96.93% of test swipes. Every one of those 3,860 words is
a word of the training split's swipes; none comes from validation or test alone. They are the
swiped word of 227 validation swipes (0.42%) and 227 test swipes (0.45%), all words the
training split also has. The rest can never be decoded and count as misses.

## Model

**Input.** 64 points `(x, y)`. Inside the model a fixed 7-tap Savitzky-Golay filter adds
velocity, acceleration, speed, and turn rate, 8 features per point, followed by a batch norm.

**Encoder** (`model.py`, `EncoderConfig`). A convolution stem (8 to `width` channels, kernel 7,
batch norm, hardswish), then five residual blocks with dilations 1, 2, 3, 5, and 8. Each block
is a dilated depthwise convolution (kernel 7), batch norm, a 1x1 expansion to 4 x `width`
channels halved by a gated linear unit, global response normalization, a 1x1 projection back
to `width`, squeeze-and-excitation (reduction 8), and dropout 0.1 before the residual sum. A
stride-2 adapter (kernel 2, 256 channels, batch norm, hardswish) halves time to 32 frames. Two
zero-initialized heads give each frame 64 cosine coefficients and one gate value.

**Layout as input.** A key's score at a frame is the frame's 8 x 8 cosine surface at the key's
center, so the encoder scores whatever layout it is given:

```text
log p(key k, frame t) = log_softmax_k(c_t . basis(center_k)) + log sigmoid(g_t)
log p(blank, frame t) = log sigmoid(-g_t)
```

| Width | Parameters | Use |
| --- | --- | --- |
| 144 | 762,203 | the bundled model (`swipe_encoder.kvsw`: 759,963 fp16 values, 1,522,063 bytes) |
| 160 | 924,949 | run 4 |
| 168 | 1,012,322 | runs 5, 6, 7 |
| 224 | 1,735,933 | larger comparison run |
| 256 | 2,237,425 | larger comparison run |

The export folds batch norms into the convolutions they follow, which is why it holds fewer
values than the model has parameters.

**Decoder** (`decoder_model.py`, optional). Feedforward sequential memory blocks (256 wide,
a 64-wide memory, a 15-frame window) over the frozen encoder's emissions, coefficients, and
gate, added to the encoder's emissions. The bundled model has none (see "Results").

## Augmentation

`augment.py` moves the swipe and the keyboard's key centers together, so the encoder learns
how a path relates to the keys it is given. A sample is augmented with the run's probability:
vertical squeeze (0.75 to 1), horizontal squeeze (0.85 to 1), shear (up to 0.05), mirror flips
(each axis with probability 0.5), rotation about the swipe's centroid (kept only when the swipe
and keys stay inside the unit square), and a shift to a random spot where everything fits.
Separately, 10% of swipes play backwards with their word reversed (base training only).

## Training the bundled model

**Base: `r3-w144-aug50-extra`** (`train.py`).

| Setting | Value |
| --- | --- |
| Width | 144 (762,203 parameters) |
| Training swipes | first run's training split plus the extra runs (`--extra`) |
| Augmentation | probability 0.5, backwards 10% |
| Loss | CTC plus `0.05 * max(0, keys - sum of gate probabilities)^2` |
| Optimizer | AdamW, learning rate 1e-3, weight decay 1e-4, gradient clip 1 |
| Schedule | 5% linear warmup, then cosine to 2e-5 |
| Batch, epochs | 1024, 120 |
| Seed | 0 |
| Kept | `best.pt`, the epoch with the lowest validation CTC loss |

```bash
python train.py <data-dir> r3-w144-aug50-extra --extra --width 144 --augment-probability 0.5
```

Each epoch's order and every step's augmentation and dropout come from the seed, epoch, and
step, and `checkpoint.pt` is written every 200 steps (`--checkpoint-every`), so `--resume`
after an interruption continues with the same batches as an uninterrupted run.

**Fine-tune: `r3-ft`** (`finetune_encoder.py`, `ranking.py`). Each training swipe is decoded
once with the base encoder and its tuned scoring; its 16 best-scoring wrong candidates become
its hard negatives. The loss is a cross-entropy that puts the true word first among them, each
scored exactly as at decode time, plus 0.3 times the true word's CTC loss per key.

| Setting | Value |
| --- | --- |
| Base | `r3-w144-aug50-extra` |
| Lexicon | 129,438 words |
| Hard negatives | 16 per swipe |
| Augmentation | geometric, probability 0.5 (the base's), no backwards swipes |
| Optimizer | AdamW, learning rate 1e-4, weight decay 1e-4, gradient clip 1 |
| Schedule | 5% linear warmup, then cosine to 0 |
| Batch, epochs | 1024, 3 |
| Kept | the epoch with the best validation top-1: epoch 2 (91.81%, 91.86%, 91.89%) |

```bash
python finetune_encoder.py <data-dir> r3-w144-aug50-extra r3-ft <unigrams.tsv> --epochs 3
```

**Second fine-tune: `r3-ft2`**, the bundled model. The same objective from `r3-ft`, its hard
negatives mined afresh from `r3-ft` with `r3-ft`'s tuned scoring, 4 epochs at learning rate
5e-5, everything else as above. Kept: the epoch with the best validation top-1, the third
(92.00%, 92.01%, 92.03%, 92.03% in `evaluate.py`).

```bash
python finetune_encoder.py <data-dir> r3-ft r3-ft2 <unigrams.tsv> --epochs 4 --learning-rate 5e-5
```

**Scoring** (`tune_scoring.py`). On the validation split's cached candidates, a seeded random
search of 400 weight sets, then coordinate refinement, maximizes top-1 (top-3 breaks ties) for

```text
score = log p(word) / L^gamma + frequencyWeight * f + lengthBonus * L
```

with `L` the key-path length and `f` the dictionary probability. `r3-ft2`'s weights: `gamma`
0.205, `frequency_weight` 0.05, `length_bonus` 1.86925. `swipe.json` bundles its `gamma` and
`lengthBonus` with `frequencyWeight` 0.045, under its tuned 0.05: the heavier the frequency
and the words before weigh, the less the landing can say, and the keyboard's tests ask that a
swipe drawn from one key's center to another's give the word on those keys for every pair of
keys, however much likelier a word a key over is. That holds at 0.045 with the context weight
below, and on validation 0.045 measures the same as 0.05 (92.80% at both, with the context
weights scaled alike, at a beam of 100).

The keyboard adds on top, all in `swipe.json` and chosen on validation with
`KeyVoxTypingHarness swipe-accuracy` (`iOS/Docs/ENGINEERING.md`, swipe typing):

- `contextWeight`, 0.7, times how much likelier the words before make the word, and
  `samePathContextWeight`, 0.8, among words on one key path. With `r3-ft2`, `contextWeight` /
  `samePathContextWeight` of 0.655/1.233, 0.655/0.95, 0.75/0.95, 0.85/0.95, 0.75/0.8, 0.75/0.6,
  and 0.7/0.8 measured 92.80%, 92.84%, 92.85%, 92.85%, 92.88%, 92.87%, and 92.87%; at 0.75 a
  swipe from one key's center to another's gives the likelier word a key over for one pair,
  and at 0.7 for none.
- the landing: words whose key paths differ only in their first key trade places by where
  the swipe landed (`landing`), the words before counted `firstKeyContextWeight`, 3, among
  them (2.5, 3, and 3.5 measured 92.86%, 92.87%, and 92.86%).
- `pruning.beam`, 200 key-path prefixes, which measured 92.80% where 100 measured 92.77%, at a
  median decode of 5.0 ms where 100 takes 3.6 ms.

```bash
python evaluate.py <data-dir> r3-ft2 <unigrams.tsv> --split val
python tune_scoring.py <data-dir> r3-ft2 <unigrams.tsv>
```

## Exporting

```bash
python export_weights.py <data-dir> r3-ft2
```

writes `models/r3-ft2/swipe_encoder.kvsw`. To bundle it, copy it to
`PredictiveData/en/swipe_encoder.kvsw`, put the run's `scoring.json` values into
`swipe.json`'s `scoring` (`gamma`, `frequencyWeight`, `lengthBonus`), the frequency weight as
"Scoring" says to measure it with the landing, and, for a model with no
decoder, leave out `swipe_decoder.kvsd`. The context weights were tuned beside a frequency
weight, so a model with another one needs them measured again, and the package's parity
fixture holds the reference decoding of the bundled model with the bundled settings. The lexicon depends only on the letters and
`keepsDoubleLetters`, not on the weights.

## Measuring accuracy

Accuracy is measured the way the keyboard decodes, with `KeyVoxTypingHarness swipe-accuracy`
on a build of the bundled model, words before included:

```bash
python write_harness_swipes.py <data-dir> dev futo-dev-context.jsonl
python write_harness_swipes.py <data-dir> test futo-test-context.jsonl
KeyVoxTypingHarness swipe-accuracy --swipes futo-test-context.jsonl \
  --layout <data-dir>/sources/futo-swipe/swipe-5/layouts/qwerty.json
```

- Every swipe in the split counts, including words the lexicon lacks.
- Each swipe gets the words before it in its recording session, taken in session order: a
  session's records, merged across all three splits, are put in order by record number, and
  the previous words are the session's records right before the swipe, back to a word that
  ends a sentence, at most 3. Record numbers are one counter shared by every session, so a
  missing number is not a skipped word.
- A swipe is right when its first distinct candidate has the recorded word's swipe form;
  top-3 and top-10 count the first 3 and 10 distinct forms.
- `--no-context` measures without the words before.

`evaluate.py` measures the same splits in Python with the model tools' decoder, without the
words before and without the keyboard's doubled-letter rules; it chooses checkpoints and tunes
scoring, and its numbers are not the keyboard's.

## Results

Every figure in this section comes from `KeyVoxTypingHarness swipe-accuracy` with the words
before each swipe included, on the input `write_harness_swipes.py` writes, unless it names
`evaluate.py`.

### The bundled model

At `fix/swipe-landing-key` 75a6339a (133,299-word lexicon), `r3-ft2` with the settings above:

| Split | Swipes | Top-1 | Top-3 | Top-10 |
| --- | --- | --- | --- | --- |
| Validation | 54,269 | 92.87% | 95.92% | 96.60% |
| Test | 49,970 | 92.56% | 95.84% | 96.59% |

With the 133,226-word lexicon, without the words left out as offensive, every figure of the table
measures the same.

Of swipe.futo.org's training and validation swipes of "us", a word whose commoner neighbor
"is" starts a key over, 59 of 67 decode to it, and all 3 of "yo"; 591 of the first 600 of
"is" and 595 of the first 600 of "to" keep their word.

The model bundled before it, `r3-ft` with its own tuned scoring (`gamma` 0.4416782860196686,
`frequencyWeight` 0.029198906788676683, `lengthBonus` 0.9808640269387409), context weight
0.425, and a beam of 100, measured:

| Build | Validation top-1 | Test top-1 | "us" of 67 |
| --- | --- | --- | --- |
| 22ea8f14, no landing rule | 92.83% | 92.62% | not measured |
| dc7958e6, the landing counted only for swipes landing and lifting close to keys | 92.80% | 92.57% | 35 |
| this landing rule, its loss divided by the key-path length to the scoring `gamma`, context among first-key words at 0.8 | 92.67% | 92.39% | 55 |
| the same with `firstKeyContextWeight` 2 | 92.73% | not measured | 59 |

Real swipes that start on the key beside their word's first key are far more often a common
word swiped loosely than the word on the landing key, so a rule that gives "us" from the "u"
key costs swipe.futo.org accuracy; `r3-ft2`, its scoring, and the weights above make that up.
Two earlier forms of the first landing rule were measured on both splits and not kept (92.70%
and 92.79% validation, 92.43% and 92.55% test). At dd9e5a03, before the 3,861 added words (129,438-word lexicon), the same model measured
92.49% validation and 92.26% test top-1. At that commit the model bundled before it,
`r1-ft-dec6` (width 128, full augmentation, with a 6-block decoder), measured 92.35%
validation and 92.32% test top-1; `r3-ft` replaced it on validation, where it decodes 0.14
points more swipes first, while on test it decodes 0.06 points fewer.

### Experiments

Validation top-1 and top-3 at dd9e5a03, 129,438-word lexicon, each run with its own tuned
scoring. Every base run trains on the same swipes with the recipe above apart from what the
row names.

| Run | What changed | Top-1 | Top-3 |
| --- | --- | --- | --- |
| `r3-w144-aug50-extra` | base: width 144, augmentation 0.5 | 92.07% | 95.24% |
| `r4-w160-aug25-extra` | base: width 160, augmentation 0.25 | 92.11% | 95.17% |
| `r5-w168-aug25-extra` | base: width 168, augmentation 0.25 | 92.01% | 95.15% |
| `r6-w168-aug25-extra-240` | base: as r5, 240 epochs | 91.93% | 95.18% |
| `t1-w224-aug25-extra` | base: width 224, augmentation 0.25, best through epoch 51 of 120 | 91.97% | 95.08% |
| `t2-w256-aug25-extra` | base: width 256, augmentation 0.25, best through epoch 34 of 120 | 92.03% | 95.20% |
| `r3-ft` | r3 fine-tuned 3 epochs, 16 negatives, learning rate 1e-4 | 92.49% | 95.48% |
| `r3-ft2` (bundled) | r3-ft fine-tuned 4 more epochs, fresh negatives, 5e-5 | 92.49% | 95.50% |
| `r3-ft2-neg32` | r3-ft2 fine-tuned 2 epochs, 32 negatives, 5e-5 | 92.52% | 95.53% |
| `r3-ft2-neg64` | r3-ft2-neg32 fine-tuned 2 epochs, 64 negatives, 5e-5 | 92.52% | 95.53% |
| `r3-ft2-aug100` | r3-ft2 fine-tuned 3 epochs at augmentation 1.0, 5e-5 | 92.49% | 95.50% |
| `r3-noaug` | r3-ft2-neg32 fine-tuned 3 epochs with no augmentation, 16 negatives, 5e-5 | 92.59% | 95.52% |
| `r4-ft` | r4 fine-tuned 3 epochs, 16 negatives, 1e-4 | 92.45% | 95.38% |
| `r4-ft2-neg32` | r4-ft fine-tuned 4 epochs, 32 negatives, 5e-5 | 92.45% | 95.38% |
| `r5-ft` | r5 fine-tuned 3 epochs, 16 negatives, 1e-4 | 92.33% | 95.40% |
| `r5-ft2-neg32` | r5-ft fine-tuned 4 epochs, 32 negatives, 5e-5 | 92.33% | 95.40% |

- **Width.** The base encoders land within 0.18 points of each other: width 160 (r4) 0.04
  above width 144 (r3), width 168 (r5) 0.06 below it, and the 224 and 256 runs, still training
  when measured, 0.10 and 0.04 below it. Fine-tuned the same way, `r4-ft` and `r5-ft` stayed
  below `r3-ft`, by 0.04 and 0.16 points.
- **Longer training.** 240 epochs (r6) decoded 0.08 points fewer swipes first than 120 (r5).
- **Augmentation.** Base runs at 0.25 (r4, r5) and 0.5 (r3) decoded within 0.10 points of each
  other, with width differing too; a run at 0.1 (`r7-w168-aug10-extra`) was still training and
  is not measured here. In fine-tuning, no augmentation (`r3-noaug`) gave the best validation
  top-1 in the table, 0.07 points above its starting point `r3-ft2-neg32`; full augmentation
  (`r3-ft2-aug100`) lowered validation top-1 in every epoch (91.80%, 91.80%, 91.84% in
  `evaluate.py`), so that run kept its starting weights.
- **Fine-tune variants.** Four more epochs (`r3-ft2`) left top-1 unchanged, and 32 negatives
  (`r3-ft2-neg32`) added 0.03 points; `r3-ft2-neg64`, `r4-ft2-neg32`, and `r5-ft2-neg32` never
  beat their starting point and kept its weights.
- **Decoder.** A 6-block decoder over `r3-ft` (`r3-ft-dec6`) measured 92.43% validation top-1
  (95.44% top-3) against the encoder alone's 92.49%, so the bundled model has none.
- **Ensembling.** Averaging `r3-ft2-neg32`'s and `r4-ft`'s per-frame probabilities decoded
  91.97% to 92.01% of validation swipes first in `evaluate.py`, against 92.06% for
  `r3-ft2-neg32` alone, so neither ensembling nor distilling from it was pursued.
- **Context weight.** For `r3-ft2-neg32`, context weights of 0.3, 0.425, 0.55, 0.7, and 0.85
  gave 92.45%, 92.52%, 92.59%, 92.62%, and 92.61% validation top-1; the bundled `swipe.json`
  uses 0.7, chosen with `r3-ft2` ("Scoring").
- **`r3-noaug` is not bundled.** With the landing rule, its tuned scoring at frequency weight
  0.045, and context weights scaled to it, it measures 92.82% validation top-1, 0.05 below
  `r3-ft2`. It also reads a swipe from "a" to "s" that circles the "a" as "as", on those two
  keys, where the keyboard's tests pin two things that cannot both hold: one asks a circle
  there for "aas", and one asks that a circled word lose to a word on its keys written 50 times
  as often that doubles another letter, here "ass". `r3-ft` and `r3-ft2` read that swipe as
  "was", which neither test judges. `r3-ft2-neg32` reads it as "as" too.
- **Fine-tuning on first-key neighbors.** `r3-ft-fk`, `r3-ft` fine-tuned on the swipes of
  words with a neighbor that starts on the key beside theirs and has the same keys after
  (79,649 swipes, at most 200 of a word, and as many others, each swipe's hard negatives
  starting with its word's neighbors; learning rate 1e-4), measured with the landing rule 92.50% validation
  top-1 after 80 steps and 92.40% after 240, against `r3-ft`'s 92.67%, and without it 92.71%
  and 92.63% against 92.83%: it gives up swipes of common words as fast as the landing rule
  does, so it is not bundled and the fine-tune option was not kept.
- **Other rankings.** On validation candidates, letting words that differ only in their last
  key trade places by where the swipe lifts won 51 swipes and lost 143, and weighing the words
  before more among words differing in their last key, in one middle key, or by one key at the
  end won and lost about as many swipes at small weights and lost more at larger ones, so none
  was built. With `r3-noaug`, a beam of 400 measured 0.02 points above 200 at a median decode
  of 7.6 ms, and the pruning's `gamma` and `beta` and the number of candidates weighed in
  context changed nothing.
- **Other layouts.** Trained on QWERTY alone, the encoder carries over to layouts it never saw.
  On the layout check (`evaluate.py`, 129,438-word lexicon, top-1):

  | Run | All | ClearFlow | Dvorak | KASROZ | QWERTZ | AZERTY |
  | --- | --- | --- | --- | --- | --- | --- |
  | `r3-w144-aug50-extra` | 91.03% | 90.57% | 93.60% | 91.88% | 89.59% | 88.54% |
  | `r3-ft` | 92.35% | 91.88% | 95.33% | 92.36% | 90.65% | 91.67% |
  | `r3-ft2` (bundled) | 93.04% | 92.77% | 95.60% | 92.65% | 90.38% | 91.67% |

### Published numbers

| System | Measured on | Top-1 |
| --- | --- | --- |
| KeyVox, bundled model | swipe.futo.org English test split, all 49,970 swipes, `KeyVoxTypingHarness` at 75a6339a, words before included | 92.56% |
| FUTO Swipe, encoder only | swipe.futo.org English test split, paper's Table 3 | 92.54% |
| FUTO Swipe, encoder plus decoder | swipe.futo.org English test split, paper's Table 3 | 93.30% |
| FUTO Swipe (FUTO Keyboard v0.1.29) | "our public test set (filtered to first 20k non-single-letter swipes) in-emulator" | 92.62% |
| Gboard | same | 88.95% |
| iOS | same | 89.18% |
| Heliboard w/ Google library | same | 86.88% |

Sources:

- *FUTO Swipe: Layout-Agnostic Neural Swipe Decoding*, David Lee Miller and Aleksandras
  Kostarevas, arXiv 2606.25247, submitted 24 Jun 2026, Table 3 ("Optional fixed-layout decoder
  on the QWERTY layout"): test top-1 92.54% encoder only and 93.30% encoder plus decoder
  (validation 92.94% and 93.49%). <https://arxiv.org/html/2606.25247v1>
- FUTO Keyboard v0.1.29 release notes, error rates "tested on our public test set (filtered to
  first 20k non-single-letter swipes) in-emulator", where "Top-1 error is the rate at which the
  primary word was incorrect": FUTO Swipe 7.38%, Gboard 11.05%, iOS 10.82%, Heliboard w/
  Google library 13.12%. The top-1 accuracies above are 100% minus these.
  <https://github.com/futo-org/android-keyboard/releases/tag/0.1.29>

The setups differ, so these numbers are not a ranking:

- KeyVox counts all 49,970 test swipes, single letters included, and gives each swipe the words
  before it. The paper reports its English test split's size as 49,970 when it describes the
  splits and as 48,538 in a later table, and does not use context.
- The release notes measure on "our public test set (filtered to first 20k non-single-letter
  swipes) in-emulator", whose link points to the swipe.futo.org dataset on Hugging Face, and do
  not say which of its runs or splits that set is. Run in an emulator, they also measure each keyboard's own
  handling of the touches.
- The paper extends its decoding word list with the test split's words; KeyVox decodes only
  to its bundled lexicon, which lacks the words of 3.06% of test swipes, so those count as
  misses. KeyVox's lexicon includes words of the training split's sentences, which are
  Wikipedia sentences like the test split's.

## Other typing languages

French and Spanish swipe with one encoder of their own, German with another trained from it, and
each with its own lexicon; English keeps `r3-ft2` and its files unchanged.

### Letters

A language's `swipe.json` names its model's letters: the letters its default layout gives keys of
their own, German `abcdefghijklmnopqrstuvwxyzäöü` (QWERTZ-German), Spanish `…zñ`
(QWERTY-Spanish), French `a`-`z` (AZERTY-French draws an accent key, not letter keys). A word's
swipe form keeps the accents of those letters and folds every other accent onto its base letter,
so "für" swipes over the "ü" key and "café" over the "e" key; `spelledLetters` writes a letter
no key types as the letters people swipe for it, French `{"œ": "oe"}`: both of swipe.futo.org's
French swipes of a word with "œ" ("cœur", "contrecœur") pass the "o" key and then the "e" key.
A letter "ß" is case folded to "ss", as for English. On a layout without a key of its own for one
of the model's letters, such as German's QWERTZ, QWERTY, and AZERTY, the keyboard swipes that
letter on its base letter's key (`SwipeKeys` in the package). The lexicon is built from the
language's dictionary and its swipe vocabulary (`Tools/KeyVoxLanguageModel`, "Swipe vocabulary"),
with `KeyVoxTypingHarness swipe-lexicon --language <id>`:

| Language | Swipe vocabulary | Lexicon words | Trie nodes | `swipe_lexicon.kvsl` |
| --- | --- | --- | --- | --- |
| en | 26,319 | 133,226 | 270,724 | 6,306,824 bytes |
| de | 102,127 | 320,472 | 1,059,147 | 22,075,953 bytes |
| fr | 59,966 | 223,596 | 470,326 | 11,035,060 bytes |
| es | 74,670 | 310,858 | 579,330 | 14,390,581 bytes |

### Measuring

swipe.futo.org's fifth run holds German, French, and Spanish swipes, never trained on. They are
kept as the run's English ones are (one finger, a scored distance of at most 134.7) and split by
recording session: a session whose name's SHA-256 begins with an even byte is in the `tune` half,
which chooses models and settings, and the rest in the `test` half, measured once for the chosen
model, so no person's swipes are in both:

```bash
python write_harness_swipes.py <data-dir> swipe-5 de-german-test.jsonl --language de --layout german --half test
KeyVoxTypingHarness swipe-accuracy --language de --letter-layout QWERTZ-German \
  --swipes de-german-test.jsonl --layout <data-dir>/sources/futo-swipe/swipe-5/layouts/german.json
```

| Language | Layout (keyboard's) | Swipes | Tune | Test |
| --- | --- | --- | --- | --- |
| de | german (QWERTZ-German) | 2,407 | 1,048 | 1,359 |
| de | qwertz (QWERTZ) | 1,307 | 901 | 406 |
| de | qwerty (QWERTY) | 1,122 | 405 | 717 |
| fr | azerty (AZERTY-French) | 2,323 | 1,161 | 1,162 |
| fr | qwerty (QWERTY) | 479 | 272 | 207 |
| es | spanish (QWERTY-Spanish) | 1,841 | 966 | 875 |

swipe.futo.org's layout files place the letter keys where the keyboard's own layouts do (within
0.001 of the frame), but for its AZERTY's apostrophe key where AZERTY-French draws its accent key.
Each layout's swipes come from different people, and a half of a few hundred swipes moves a point
for a handful of them, so the figures below pool each language's layouts.

### Training French's and Spanish's model: `k1`

`r3-ft2` was trained on QWERTY alone. With the languages' lexicons, German's and French's swipes
on QWERTY decode within 2 points of English's test split, and those on QWERTZ-German, QWERTZ, and
AZERTY-French 5 to 7 points below it; Spanish's, on QWERTY-Spanish, decode above it (below).
`k1` fine-tunes it on English swipes moved onto those layouts:

- `warp_layout_swipes.py` gives each swipe of the first run's training split and the extra runs
  (1,067,609 whose letters all have keys) one of QWERTY, QWERTY, QWERTZ-German, QWERTZ,
  AZERTY-French, AZERTY, QWERTY-Spanish, QWERTY-Accents, and QWERTZ-Accents, drawn with seed 0,
  and moves it there (`layout_warp.py`): each key of the word's key path is matched to the point
  of the swipe closest to it, in order, and the swipe moves by how far each key's letter moves,
  blended linearly between matched points, keeping the person's own path around the keys (its
  mean distance from them is 0.047 before and 0.046 after, on 2,000 validation swipes). A swipe
  given QWERTY stays as recorded. The validation split is moved the same way.
- `rank_layouts.py` is `finetune_encoder.py`'s ranking fine-tune layout by layout: each swipe's
  16 hard negatives are mined with `r3-ft2` and its scoring on its own layout's key-path trie of
  the 129,438-word lexicon `r3-ft2` was fine-tuned with, every batch holds swipes of one layout,
  learning rate 5e-5, augmentation 0.5, batch 1,024, 3 epochs.

```bash
python warp_layout_swipes.py <data-dir> layouts \
  --layouts QWERTY,QWERTY,QWERTZ-German,QWERTZ,AZERTY-French,AZERTY,QWERTY-Spanish,QWERTY-Accents,QWERTZ-Accents
python rank_layouts.py <data-dir> r3-ft2 k1 <unigrams.tsv> --swipes layouts-train --validation layouts-val
python export_weights.py <data-dir> k1 --checkpoint epoch-0.pt
```

The moved validation swipes decoded 90.36% first before it and 91.58%, 91.68%, and 91.69% after
each epoch (`evaluate.py`'s decoder). The bundled encoder is the first epoch's, chosen on the tune
halves (93.37% top-1 against 93.04% after the third, with German's scoring then at frequency
weight 0.065 and length bonus 2.3); its `swipe_encoder.kvsw` (SHA-256 `dd7ad96e…9829`) is the same
file in `fr` and `es`. Their `swipe.json` is English's but for its letters: with `k1`,
English's frequency weight and length bonus (0.045, 1.869) measured 93.33% on the tune halves,
0.045 and 2.3 93.22%, 0.065 and 1.869 93.14%, and 0.065 and 2.3 93.23%.

### Training German's model: `g6`

With `k1`, German's test half decoded 2.4 points under French's and 2.5 under English's test split. Of its tune
half's 191 misses, 73 lost to another lexicon word, 45 to another form of the same word (such as
"den" for "dem" or "im" for "in"), 44 were words the lexicon lacks, 9 lost to an English
vocabulary word, 9 the beam dropped, and 9 lost to their umlaut twin on a layout without umlaut
keys ("würde" for "wurde"). English swipes moved onto German's layouts still trace English words,
so `g6` is trained on swipes of German words:

- `retarget_swipes.py` draws German words by how often German's texts write them on their own
  (`Tools/KeyVoxLanguageModel`'s `count_swipe_words.py` table), among the 287,654 of its
  1,057,670 words the German lexicon holds on every layout, and gives each one of QWERTZ-German,
  QWERTZ-German, QWERTZ, QWERTY, and AZERTY. Of 2,048 English swipes drawn with a key path as
  long on swipe.futo.org's QWERTY, the one whose keys lie nearest the word's, by mean distance,
  is moved key by key onto the word's keys on that layout (`layout_warp.py`); 2,000,000 training
  and 100,000 validation swipes, seed 2.
- `rank_layouts.py --language de` reads the German lexicon on each layout as the keyboard reads
  German there, its umlauts kept on QWERTZ-German and folded onto their base letter elsewhere, and
  runs the ranking fine-tune from `k1`'s first epoch for 3 epochs; `g6` is a second round from
  that run's third epoch, with fresh negatives, for 2 epochs.

```bash
python retarget_swipes.py <data-dir> de-near3 <swipe_word_counts.tsv> <unigrams.tsv> --language de \
  --layouts QWERTZ-German,QWERTZ-German,QWERTZ,QWERTY,AZERTY --swipes 2000000 --donors 2048 --seed 2
python rank_layouts.py <data-dir> k1e0 g5 <unigrams.tsv> --language de --swipes de-near3-train --validation de-near-val
python rank_layouts.py <data-dir> g5e2 g6 <unigrams.tsv> --language de --swipes de-near3-train \
  --validation de-near-val --epochs 2
python export_weights.py <data-dir> g6 --checkpoint epoch-0.pt
```

`k1e0` and `g5e2` hold `k1`'s first epoch and `g5`'s third as `best.pt`, with their settings and
scoring. The validation swipes (`de-near-val`, 20,000) decoded 91.23% first after `g5` and 91.64%
and 91.59% after `g6`'s epochs. The bundled encoder is `g6`'s first epoch, chosen on German's tune
half (92.69% with English's scoring, 92.52% after the second); its `swipe_encoder.kvsw` is SHA-256
`240c636e…afcf`. German's `swipe.json` then takes frequency weight 0.055 and length bonus 2.8,
chosen on the tune half from 0.035 to 0.065 and 1.6 to 3.6: 93.07%, against 92.69% at English's
and 92.90% to 93.07% from length bonus 2.2 to 3.2 at frequency weight 0.045 and 0.055.

### Results

`KeyVoxTypingHarness swipe-accuracy`, words before included, top-1 / top-3; "before" is `r3-ft2`
with the same lexicons and `swipe.json`:

| Language | Layout | Tune before | Tune `k1` | Test before | Test `k1` |
| --- | --- | --- | --- | --- | --- |
| de | german | 89.60 / 95.32 | 91.13 / 96.09 | 87.56 / 94.26 | 89.26 / 95.29 |
| de | qwertz | 90.68 / 95.89 | 92.12 / 96.78 | 85.96 / 95.07 | 87.68 / 95.81 |
| de | qwerty | 91.11 / 96.30 | 93.33 / 96.79 | 91.49 / 96.51 | 92.75 / 96.93 |
| de `g6` | german | | 92.94 / 97.23 | | 90.51 / 96.47 |
| de `g6` | qwertz | | 93.45 / 97.23 | | 89.90 / 95.81 |
| de `g6` | qwerty | | 92.59 / 97.04 | | 92.75 / 96.79 |
| fr | azerty | 89.06 / 95.43 | 92.85 / 97.76 | 86.66 / 94.15 | 92.77 / 97.42 |
| fr | qwerty | 95.59 / 98.16 | 95.96 / 98.16 | 90.82 / 96.14 | 90.34 / 97.58 |
| es | spanish | 95.76 / 98.55 | 96.69 / 98.86 | 93.71 / 97.60 | 95.20 / 98.40 |

Top-1 pooled by language:

| Language | Tune before | Tune `k1` | Test before | Test `k1` |
| --- | --- | --- | --- | --- |
| German | 90.27% | 91.89% | 88.43% | 90.01% |
| French | 90.30% | 93.44% | 87.29% | 92.40% |
| Spanish | 95.76% | 96.69% | 93.71% | 95.20% |
| All three | 91.40% | 93.33% | 89.08% | 91.66% |

German's bundled `g6` with its own scoring decodes 93.07% of its tune half and 91.06% of its test
half first; with French's and Spanish's `k1`, the three pool to 93.92% and 92.21%.

Beside them, English decodes 92.56% of its test split (95.84% top-3), and `r3-ft2` decodes
swipe-5's English swipes on QWERTZ 91.17% (759), AZERTY 94.79% (96), and Dvorak 96.98% (2,250),
the same run's people on layouts it never trained on. The German lexicon holds 97.86% to 98.24% of
the German swipes' words by layout, against English's 96.93% of its test split. A German word's key path needs
at most 32 frames in every test swipe. Swipes decode in a median 4.7 to 6.1 ms (95th percentile
8.8 to 10.7 ms) by layout, against English's 5.0 ms (9.7 ms).

Through the package, the process's physical footprint, the figure iOS limits app extensions by,
rose after loading the engine and decoding 300 swipes by 13.6 MB in English, 21.2 MB in German,
16.1 MB in French, and 13.2 MB in Spanish on a Mac; the beam search's per-node array is 4 bytes a
trie node, 4.0 MB of German's.

### Experiments not kept

Measured on the halves above; the scoring named is German's at the time.

- **German words from any English swipe** (`retarget_swipes.py` with one donor, a random English
  swipe with a key path as long): German's tune half fell from 91.89% to 89.51%, the swipes'
  paths bending where no person's do. Nearest of 256 donors (400,000 swipes) reached 92.22%,
  of 1,024 (800,000) 92.44%, and a second round from it 92.61%, all with English's scoring.
- **German scoring with `k1`.** Context weight 1.0 or 1.3 and same-path context weight 1.6 measured
  at most `k1`'s 91.89% on the tune half; a beam of 400, 92.02%.
- **The vocabulary without English's words** (`k1`): German's tune half 91.72%.
- **More German rounds and swipes**, with German's scoring: a third round from `g6` on 2,000,000
  fresh swipes (nearest of 4,096 donors, seed 3; `g7`) and one run from `k1`'s first epoch on both
  sets (`g8`) each reached 93.16% on German's tune half against `g6`'s 93.07%, and the mean of
  their weights 93.25%, which decoded 90.94% of the test half against `g6`'s 91.06%.
- **German scoring with `g6`.** A beam of 300 or 400 measured 93.16% and 93.20% on the tune half;
  context weight 0.5 or 0.9 with same-path context weight 0.6 or 1.0, at most 93.07%.
- **What `g6` still misses.** Of its tune half's 163 misses, 7 are "wurde" lost to "würde",
  which the dictionary ranks a step higher, of 15 swipes of it on QWERTZ and QWERTY, where both
  trace the same keys; on QWERTZ-German all 12 decode.
- **The vocabulary.** With `r3-ft2` and German's scoring at frequency weight 0.065 and length
  bonus 2.3, the German test half decoded 89.52% with the swipe vocabulary, 89.24% without the
  words of English's lexicon that German's word list and lexicons lack (such as "the" and "you",
  which the vocabulary has from YouTube-Commons), and 88.92% with the dictionary alone; the
  vocabulary is built by English's rules.
- **German scoring.** With `r3-ft2`, frequency weight 0.065 and length bonus 2.3 raised the
  German test half from 88.43% to 89.52%; with `k1` English's measured as well (above).
- **CTC on several layouts** (`train.py`'s loss on the moved swipes, learning rate 1e-4,
  3 epochs). With the tune halves' recorded swipes added 20 times each, the German test half went
  from 89.52% to 89.93%; on the moved swipes alone, the tune halves went from 91.67% to 91.90%
  after the first epoch and 91.60% after the third, French gaining and German losing up to a
  point, as the CTC loss gives up the ranking `r3-ft2` was fine-tuned for.
- **A second ranking round** (`k2`, from `k1`'s third epoch, fresh negatives): the moved
  validation swipes 91.69% to 91.72%, the tune halves 93.23%. On German's layouts alone (`k1`'s
  first epoch, 474,293 moved swipes, 2 epochs), German's tune half 91.84% against `k1`'s 91.97%.

## Setup

```bash
python3.14 -m venv <data-dir>/venv
<data-dir>/venv/bin/pip install -r requirements.txt
```

Training runs on the Apple GPU with the pinned PyTorch (macOS 14 or later). On macOS 13,
PyTorch 2.9 to 2.11 have no Apple GPU support and PyTorch 2.6 to 2.8 compute this model's
gradients incorrectly on the GPU. On the CPU, the depthwise convolutions run as shifted
multiply-adds, which PyTorch computes far faster there.

## Exported weights

`export_weights.py <data-dir> <run>` writes `swipe_encoder.kvsw`, and for a decoder run
also `swipe_decoder.kvsd`, into the run's directory. `exported_model.py` runs both files in
plain NumPy, operation by operation, and is the reference the keyboard's Accelerate
implementation is checked against; `evaluate.py --exported` measures accuracy from the
exported files.

Both files share one layout (`weights_format.py`), all little-endian:

| Field | Type |
| --- | --- |
| magic | 4 bytes: `KVSW` (encoder) or `KVSD` (decoder) |
| version | uint32, currently 1 |
| config count, then config values | uint32, then that many uint32 |
| tensor count | uint32 |
| per tensor: name length, name, rank, dimensions | uint16, ASCII, uint8, rank x uint32 |
| tensor values, in table order | fp16, row-major |

Encoder config values: points, width, expansion, kernel, head width, basis size, block
count, then each block's dilation (the bundled model: 64, 144, 4, 7, 256, 8, 5, 1, 2, 3, 5,
8). Tensors, in order, with `W` the width and `H` the head width:

| Tensor | Shape | Use |
| --- | --- | --- |
| `input.scale`, `input.shift` | [8] | `features * scale + shift` |
| `stem.weight`, `stem.bias` | [W, 8, 7], [W] | zero-padded convolution, then hardswish |
| `block{i}.depthwise.weight`, `.bias` | [W, 7], [W] | dilated depthwise convolution, zero padded |
| `block{i}.expand.weight`, `.bias` | [4W, W], [4W] | 1x1; first half times sigmoid of second half |
| `block{i}.response.gamma`, `.beta` | [2W] | `gamma * (x * n) + beta + x`, `n` = per-channel L2 over time / its channel mean + 1e-6 |
| `block{i}.project.weight`, `.bias` | [W, 2W], [W] | 1x1 |
| `block{i}.excite.reduce.weight`, `.bias` | [W/8, W], [W/8] | time mean, then ReLU |
| `block{i}.excite.expand.weight`, `.bias` | [W, W/8], [W] | sigmoid, scales channels; block output adds to its input |
| `adapter.weight`, `adapter.bias` | [H, W, 2], [H] | stride-2 convolution over frame pairs, then hardswish |
| `coefficients.weight`, `.bias` | [64, H], [64] | per-frame cosine coefficients |
| `gate.weight`, `gate.bias` | [1, H], [1] | per-frame gate logit |

Batch norms are folded into the convolutions they follow. The cosine basis for a key at
`(x, y)` is `cos(pi * u * x) * cos(pi * v * y)` for `u, v` in 0..7, `u` major.

Decoder config values: symbols, coefficients, width, bottleneck, blocks, memory. Its input
per frame is the encoder's log-emissions (blank first), coefficients, and gate
probability. Tensors: `project.weight`/`.bias` ([256, 92], [256], then ReLU); per block
`down.weight` ([64, 256]), `memory.weight` ([64, 15], zero-padded depthwise, added to its
input and to the previous block's memory), `up.weight`/`.bias` ([256, 64], [256], ReLU,
added to the block input); `head.weight`/`.bias` ([27, 256], [27]), added to the encoder's
log-emissions before a final log-softmax.
