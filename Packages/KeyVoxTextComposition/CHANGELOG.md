# Changelog

All notable changes to `KeyVoxTextComposition` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared text-composition behavior within the KeyVox monorepo.

---

## [1.0.3] - 2026-08-21

Preserved punctuation immediately following replaced text during dictation insertion.

### Includes

- Removed an incoming model-added period when punctuation already follows the selected text.
- Replaced existing punctuation when processed dictation explicitly ends with a question mark or exclamation point.
- Shared the punctuation-boundary decision across macOS and iOS composition paths.
- Added regression coverage for periods, question marks, exclamation points, commas, semicolons, colons, parentheses, dashes, and ellipses.

### Notes

- `1.0.3` bumps the tracked patch version for punctuation-aware selected-text composition.

## [1.0.2] - 2026-08-08

Generalized capitalization and spacing around punctuation and symbol boundaries.

### Includes

- Preserved incoming capitalization at document starts and after terminal punctuation followed by punctuation or symbol delimiters, including trailing whitespace.
- Kept ordinary continuation text lowercase after non-terminal delimiters across Unicode punctuation and symbol categories.
- Added a leading separator after an existing ampersand.
- Added regression coverage for delimiter, whitespace, document-start, and ampersand composition cases.

### Notes

- `1.0.2` bumps the tracked patch version for shared punctuation- and symbol-aware text-composition behavior.

## [1.0.1] - 2026-08-03

Emoji-aware capitalization and spacing at text-composition boundaries.

### Includes

- Preserved incoming capitalization after emoji at document starts, line starts, and sentence boundaries while continuing lowercase continuation text after emoji following ordinary prose.
- Added a leading separator after an emoji when the incoming text does not already begin with whitespace.
- Added debug diagnostics for the capitalization and spacing payloads returned by the package, including the relevant preceding-character context.
- Added regression coverage for emoji capitalization, spacing, and combined composed payloads.

### Notes

- `1.0.1` bumps the tracked patch version for shared emoji-aware text-composition behavior.

## [1.0.0] - 2026-07-21

Initial shared text-composition policy for joining dictated text to existing editor content.

### Includes

- Shared leading-capitalization behavior for sentence starts and continuations.
- Shared leading-spacing behavior around words, punctuation, delimiters, and quotation marks.
- Opening and closing classification for straight and curly single and double quotation marks.
- Sentence-boundary recognition when terminal punctuation appears immediately before a closing quotation mark.
- Context and policy APIs that remain independent of macOS Accessibility, iOS document proxies, clipboards, and insertion transports.

### Notes

- `1.0.0` establishes the package boundary for deterministic text composition while each app continues to own editor-context collection and text insertion.
