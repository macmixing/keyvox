# Changelog

All notable changes to `KeyVoxTextComposition` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared text-composition behavior within the KeyVox monorepo.

---

## [1.0.4] - 2026-09-04

Preserved sentence-start capitalization when dictation follows a numbered hyphen sequence.

### Includes

- Treated one or more trailing hyphens after a number as a sentence boundary, with or without spaces between the number and hyphens.
- Kept ordinary hyphens after non-numeric text as lowercase continuation boundaries.
- Evaluated the complete trailing hyphen sequence so additional hyphens no longer hide the preceding number.
- Added regression coverage for single- and multi-digit numbers, spaced and compact hyphens, repeated hyphens, and ordinary text continuations.

### Notes

- `1.0.4` bumps the tracked patch version for numbered hyphen-sequence capitalization.

## [1.0.3] - 2026-08-23

Improved dictated capitalization, punctuation, and spacing around colons, standalone months, hyphens, terminal marks, URLs, line boundaries, and surrounding text.

### Includes

- Removed an incoming model-added period when supported non-quote punctuation already follows the selected text.
- Removed an incoming model-added period when the next existing non-whitespace character is a lowercase letter.
- Preserved an incoming model-added period when the following content begins on a new line or with a URL.
- Reused a matching question mark or exclamation point and replaced differing supported non-quote punctuation when processed dictation explicitly ends with either mark.
- Left incoming terminal punctuation unchanged before straight or curly quotation marks.
- Added one leading space when incoming text would otherwise run directly into a preceding hyphen.
- Added one trailing space when dictated text would otherwise run into an existing letter, number, or emoji.
- Left trailing spacing unchanged before punctuation, symbols, whitespace, or no following text, and when the dictated text already ends in whitespace.
- Preserved incoming capitalization after a colon.
- Preserved locale-canonical month capitalization when used alone, plus month and weekday capitalization for detected dates and spoken-number dates, while allowing relative date labels to follow normal continuation casing.
- Shared the punctuation-boundary decision across macOS and iOS composition paths.
- Added regression coverage for colon and hyphen boundaries, standalone months, locale-canonical calendar names, relative date labels, spoken-number dates, model periods, explicit question marks and exclamation points, supported non-quote punctuation, quotation-mark boundaries, new lines, URLs, and missing separators.

### Notes

- `1.0.3` bumps the tracked patch version for locale-aware capitalization, punctuation-aware composition across line and URL boundaries, and missing trailing separators.

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
