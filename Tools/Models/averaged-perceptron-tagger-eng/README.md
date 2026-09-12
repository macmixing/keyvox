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

The Swift predictor follows the model's feature schema. KeyVox resolves the
subset of contextual grammatical roles, noun inflection, and name identity that
Core consumes. The Android host pairs it with the separately licensed WordNet
lexical indexes. This is a focused compatibility implementation, not a general
replacement for Apple's Natural Language API.

To use the model in the speech harness, deploy this directory alongside the
executable and set `KEYVOX_LINGUISTIC_MODEL` to its absolute path. Supply a matching
processing language as the final command argument. Model installation and asset
ownership remain the host's responsibility rather than Core's.

Distributions including these assets must retain `LICENSE.txt`. Distributions
including the Swift predictor must also retain the package's bundled
`PERCEPTRON-LICENSE.txt`. No Python runtime or additional model dependency is
required.
