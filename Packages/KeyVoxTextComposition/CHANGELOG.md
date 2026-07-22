# Changelog

All notable changes to `KeyVoxTextComposition` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared text-composition behavior within the KeyVox monorepo.

---

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
