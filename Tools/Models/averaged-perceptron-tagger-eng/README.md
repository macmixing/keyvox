# Optional grammatical model

These are unchanged, MIT-licensed NLTK averaged-perceptron JSON model assets.
`sources.lock.json` identifies the immutable archive, explicit upstream license
declaration, full license text, and individual file hashes. The original model
publication describes WSJ training; no training corpus is incorporated here.

This model supports English only. Its language declaration belongs to the model,
not to the shared engine. Hosts must explicitly choose both this model and a
compatible processing language. Other languages receive Unicode word boundaries
without grammatical predictions. Existing Apple applications retain their Apple
analyzer unless a host explicitly supplies this alternative.

The Swift predictor follows the model's feature schema. Input segmentation uses
Unicode word boundaries, which differ from the Penn Treebank tokenization used
for training, particularly for contractions, possessives, and hyphenated text.
Prediction context currently spans the complete input rather than restarting at
sentence boundaries. These differences limit accuracy; this is not a claim of
Apple or Treebank linguistic parity.

Only supported grammatical roles and word boundaries are reported. Ambiguous
`IN` and `TO` labels produce no semantic role. Proper-noun labels do not establish
named entities. Lemmas and named entities are unavailable.

To use the model in the speech harness, deploy this directory alongside the
executable and set `KEYVOX_LINGUISTIC_MODEL` to its absolute path. Supply a matching
processing language as the final command argument. The model is not included in
Swift package resources or downloaded automatically.

Distributions including these assets must retain `LICENSE.txt`. Distributions
including the Swift predictor must also retain the package's bundled
`PERCEPTRON-LICENSE.txt`. No Python runtime or additional model dependency is
required.
