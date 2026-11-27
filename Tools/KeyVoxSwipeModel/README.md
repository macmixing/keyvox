# KeyVox Swipe Model

Trains, tunes, exports, and measures KeyVox's own swipe (gesture) typing model: a small
neural encoder that reads a finger path over any keyboard layout and scores that layout's
keys frame by frame, decoded into words of KeyVox's English swipe lexicon. The approach
follows the published description in *FUTO Swipe: Layout-Agnostic Neural Swipe Decoding*
(Miller and Kostarevas, arXiv 2606.25247); the code is KeyVox's own.

The bundled English model (`Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/en/swipe_encoder.kvsw`
and `swipe.json`, no decoder) is run `r3-ft`: the width-144 encoder `r3-w144-aug50-extra`
after one ranking fine-tune. Its `swipe_encoder.kvsw` is byte for byte the file
`export_weights.py` writes for `r3-ft` (SHA-256 `b369dfd6…2e04`). On swipe.futo.org's
English test split it decodes 92.55% of swipes to the swiped word first (see "Results").

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

The shared modules: `words.py` (letters and key paths), `layouts.py`, `lexicon.py` (word
list and key-path trie), `swipe_data.py`, `model.py`, `augment.py`, `ranking.py`,
`decode.py` with `beam_search.c`, `scoring.py`, `emissions.py`, `run_emissions.py`,
`run_settings.py`, `decoder_model.py`, `weights_format.py`, and `exported_model.py`.

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
  are never written anywhere.
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
validation swipes and 96.48% of test swipes. The bundled lexicon now has 133,299 words (125,504
forms), after 3,861 words of swipe.futo.org's training sentences that the dictionary and the
other vocabulary words lacked (`Tools/KeyVoxLanguageModel/README.md`, "Swipe vocabulary"). It
covers 96.93% of validation swipes and 96.94% of test swipes. Every one of those 3,861 words is
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

**Scoring** (`tune_scoring.py`). On the validation split's cached candidates, a seeded random
search of 400 weight sets, then coordinate refinement, maximizes top-1 (top-3 breaks ties) for

```text
score = log p(word) / L^gamma + frequencyWeight * f + lengthBonus * L
```

with `L` the key-path length and `f` the dictionary probability. `r3-ft`'s weights, as bundled
in `swipe.json`: `gamma` 0.4416782860196686, `frequencyWeight` 0.029198906788676683,
`lengthBonus` 0.9808640269387409. The keyboard adds context on top: `swipe.json`'s
`contextWeight`, 0.425, times how much likelier the words before make the word, and ranks
words whose key paths differ only in their first key by where the swipe landed, with
`swipe.json`'s `landing` settings (`iOS/Docs/ENGINEERING.md`, swipe typing).

```bash
python evaluate.py <data-dir> r3-ft <unigrams.tsv> --split val
python tune_scoring.py <data-dir> r3-ft <unigrams.tsv>
```

## Exporting

```bash
python export_weights.py <data-dir> r3-ft
```

writes `models/r3-ft/swipe_encoder.kvsw`. To bundle it, copy it to
`PredictiveData/en/swipe_encoder.kvsw`, put the run's `scoring.json` values into
`swipe.json`'s `scoring` (`gamma`, `frequencyWeight`, `lengthBonus`), and, for a model with no
decoder, leave out `swipe_decoder.kvsd`. The lexicon depends only on the letters and
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

At `fix/swipe-landing-key` ecfd9637 (133,299-word lexicon):

| Split | Swipes | Top-1 | Top-3 | Top-10 |
| --- | --- | --- | --- | --- |
| Validation | 54,269 | 92.79% | 95.84% | 96.49% |
| Test | 49,970 | 92.55% | 95.77% | 96.50% |

At 22ea8f14, before the keyboard ranked words that differ only in their first key by where
the swipe landed, the same model measured 92.83% validation (95.87% top-3, 96.51% top-10)
and 92.62% test top-1 (95.82%, 96.53%); the landing settings were chosen on validation
together with the swipes recorded from one key to another on the simulator
(`iOS/Docs/ENGINEERING.md`, swipe typing). A wider setting measured first, the loss counted
among all words rather than those differing only in their first key, with `weight` 6.5 and
`careReach` 0.42 on the lift alone, gave 92.70% validation and 92.43% test top-1 and was not
kept. At dd9e5a03, before the 3,861 added words (129,438-word lexicon), the same model measured
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
| `r3-ft` (bundled) | r3 fine-tuned 3 epochs, 16 negatives, learning rate 1e-4 | 92.49% | 95.48% |
| `r3-ft2` | r3-ft fine-tuned 4 more epochs, fresh negatives, 5e-5 | 92.49% | 95.50% |
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
  uses 0.425.
- **`r3-noaug` is not bundled.** At 22ea8f14 it measures 92.93% validation top-1 against the
  bundled model's 92.83%, but with it the keyboard loses two doubled-letter behaviors its tests
  pin: `SwipeDoubledLetterTests.testTheSameSwipeIsTooOrToAsTheWordsBeforeCallForIt` gives "to"
  where the words before call for "too", and
  `testACircleDoublesALetterButNeverTriplesItWhereAllThreeAreWords` gives "as" where a circle
  asks for "aas". Both pass with the bundled model.
- **Other layouts.** Trained on QWERTY alone, the encoder carries over to layouts it never saw.
  On the layout check (`evaluate.py`, 129,438-word lexicon, top-1):

  | Run | All | ClearFlow | Dvorak | KASROZ | QWERTZ | AZERTY |
  | --- | --- | --- | --- | --- | --- | --- |
  | `r3-w144-aug50-extra` | 91.03% | 90.57% | 93.60% | 91.88% | 89.59% | 88.54% |
  | `r3-ft` (bundled) | 92.35% | 91.88% | 95.33% | 92.36% | 90.65% | 91.67% |
  | `r3-ft2` | 93.04% | 92.77% | 95.60% | 92.65% | 90.38% | 91.67% |

### Published numbers

| System | Measured on | Top-1 |
| --- | --- | --- |
| KeyVox, bundled model | swipe.futo.org English test split, all 49,970 swipes, `KeyVoxTypingHarness` at ecfd9637, words before included | 92.55% |
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
