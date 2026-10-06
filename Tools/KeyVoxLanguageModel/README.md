# KeyVox Language Model

Builds the context model the predictive keyboard uses to judge how likely a word is
after the words before it (`context_artifact_800k.bin` in
`Packages/KeyVoxPredictiveKeyboard`). The model holds counts and probabilities of words,
word pairs, and three-word sequences; it contains no text.

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
