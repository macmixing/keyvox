# KeyVoxLinguistics

Engine-owned linguistic results: original UTF-16 word ranges, grammatical roles,
lemmas and ordinary-word/name identity. Providers report which requested features
their resolved language supports. A missing classification is not manufactured
from capitalization, suffixes or a bundled vocabulary.

Apple's adapter retains its word tokenizer, lexical/name/lemma analysis and
named-phrase grouping. Core consumes these semantic values without importing
NaturalLanguage. The postprocessor owns its selected analyzer for its lifetime and
restores that context on its processing queue, including dictionary indexing.
Independent hosts can supply a `LinguisticAnalyzing` implementation; language and
model selection belong to that implementation and its caller.

## Current status

- Apple: FUNCTIONAL, with system analysis and Core regression coverage.
- Non-Apple default analyzer: STUBBED. It returns no tokens and explicitly reports
  no available features. A verified portable analyzer must be supplied before
  claiming linguistic or complete Core processing parity. This temporary boundary
  exposes the remaining build blockers; it is not a working NLP replacement.
- No third-party model, corpus, lexicon or package is introduced. The implementation
  is original KeyVox code under the repository's MIT license.
- Windows/Linux: the protocol and result types have no Apple types. They can use
  the same future portable provider or a platform provider without engine changes.

Package coverage compares Apple lexical/lemma results and UTF-16 offset lookups
against system analysis of locale-generated text. Core also verifies provider
ownership across synchronous and asynchronous processing.
