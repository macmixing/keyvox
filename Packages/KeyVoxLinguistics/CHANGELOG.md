# Changelog

All notable changes to `KeyVoxLinguistics` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for shared linguistic-analysis behavior within the KeyVox monorepo.

---

## [1.0.1] - 2026-11-06

Shared capitalized spellings for every KeyVox surface that decides a word's capitals.

### Includes

- Added `CapitalizedSpellings`, the bundled list of words spelled only with capitals, such as `Monday`, `Sarah`, and `iPhone`, moved here from `KeyVoxPredictiveKeyboard` so the keyboard and dictation share one list.
- Bundled `capitalized_spellings.txt` as a package resource, so the list loads the same way on every platform.
- Added `KeyVoxLinguisticsResources.configure(bundleURL:)` so hosts outside an application bundle can point the package at its copied resources before first use.
- Tagged a word written with an attached `'s` as the word it is attached to in the portable analyzer, matching how its model was trained, so possessives of less common nouns read as nouns and contractions such as `that's` and `let's` read as their first word.

### Notes

- `1.0.1` adds public API for the shared capitalized spellings list.

---

## [1.0.0] - 2026-09-12

Initial shared linguistic-analysis package for native Apple and portable KeyVox clients.

### Includes

- Defined shared token, lexical-role, feature, grouping, and analysis types behind a platform-neutral analyzer interface.
- Added the Apple analyzer for native Natural Language framework evidence and a Unicode analyzer for portable word boundaries.
- Added portable English role inference backed by host-provided perceptron and WordNet resources.
- Added health evaluation that distinguishes valid empty analysis from missing lexical evidence within the caller’s requested range.
- Added health-routed analyzer construction that retains healthy platform results and uses a configured portable fallback only for a normalized matching language.
- Documented the licenses and notices required when distributing the supported linguistic resources.

### Notes

- `1.0.0` establishes the shared source of truth for linguistic capabilities and fallback routing.
