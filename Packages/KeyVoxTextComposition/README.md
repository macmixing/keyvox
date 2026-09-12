# KeyVoxTextComposition

Portable Swift policies for inserting processed text into surrounding text.
The engine does not depend on a presentation framework.

## Platform behavior

- Apple uses the existing Foundation link and date detectors.
- Non-Apple platforms recognize explicit URI syntax and DNS-shaped link prefixes,
  including email addresses and adjacent punctuation. Recognition does not verify
  domain registration, reachability or a public-suffix list. Syntactically valid
  domain-shaped text can therefore be recognized even when no destination exists.
- Calendar capitalization uses Foundation's locale data. Existing canonical month
  and spelled-number handling is shared. The non-Apple date boundary preserves
  full weekday names composed of letters. Abbreviated weekday expressions and
  general natural-language date recognition remain unresolved on non-Apple
  platforms; the fallback does not claim equivalent date-parser coverage.
- No third-party code, model, corpus or vocabulary dependency is added here.

`CompositionVerification` contains the shared portable behavior checks used by
the package tests and `CompositionProbe`. These targets are outside the library
product. They exercise structural links, punctuation boundaries, transcript
composition and locale-derived weekday names without bundling calendar words.
