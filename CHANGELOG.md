# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

## [1.0.2] - 2026-03-11

### Added

- Added macOS iCloud sync for dictionary entries plus synced settings for trigger binding, auto paragraphs, and list formatting.
- Added weekly word stats sync so current-week totals can converge across devices.
- Added the `KeyVoxCore` Swift package to own shared transcription, normalization, dictionary, list, audio, Whisper, and pronunciation resource logic.
- Added thousands-grouping normalization for quantity-like four-digit numbers while protecting dates, years, versions, and phone numbers.
- Added a dedicated bug report issue template for more consistent incoming issue reports.

### Changed

- Moved reusable engine code, package resources, and core-focused test coverage into `KeyVoxCore` while keeping app-specific wiring in the app target.
- Tightened paragraph and list boundary detection to reduce accidental list rendering and awkward post-processing splits.
- Refactored the macOS recording overlay around a shared audio indicator driver and unified branded logo presentation through `LogoBarView`.
- Updated onboarding window sizing so the macOS onboarding flow grows with expanded content such as model download progress and errors.
- Moved weekly word-count persistence responsibilities out of `AppSettingsStore` into a dedicated store.

### Fixed

- Reduced dictionary false positives for stylized split-join and single-token corrections on long shared-prefix matches.
- Prevented prose number ranges and trailing commentary from being reformatted as lists while preserving terminal punctuation on longer list items.
- Preserved persisted dictionary freshness and empty dictionary snapshots during macOS iCloud bootstrap and reconciliation.
- Prefixed newly generated mac weekly-stats installation identifiers with `mac:` for more reliable device grouping.
- Hardened dictionary durability, audio post-processing, Whisper request cleanup, and regression coverage across sync and formatting edge cases.

## [1.0.1] - 2026-03-05

### Changed

- Replaced static TLD checks with shared domain heuristics in `WebsiteNormalizer`.
- Delegated ambiguous domain/prose-dot disambiguation from `SentenceCapitalizationNormalizer` to `WebsiteNormalizer`.

### Fixed

- Preserved sentence-boundary capitalization when prose periods are not domain separators.
- Made `WebsiteNormalizer.nextWord` composed-character safe to avoid surrogate-pair splitting.
- Prevented compressed-tail 3-token dictionary fallback false positives that could rewrite unrelated prose spans (#24).
- Added regression tests for long-TLD domain handling, sentence-boundary behavior, and compressed-tail dictionary matching.

## [1.0.0] - 2026-03-04

Initial public release of KeyVox.

### Added

- Local-first dictation system powered by on-device Whisper (`ggml-base`).
- Push-to-talk recording overlay triggered by a held key.
- Deterministic post-processing pipeline for formatting and cleanup.
- Custom dictionary system with phonetic-aware correction.
- Pronunciation lexicon pipeline and tooling.
- Automatic paragraph detection from silence windows.
- List rendering and spoken-number list parsing.
- Spoken math normalization with symbol conversion.
- Email literal normalization and punctuation repair.
- Website/domain casing normalization.
- Time expression normalization.
- Character spam cleanup and laughter normalization.
- Caps Lock override mode for full uppercase output.
- Clipboard-safe paste injection with restoration guarantees.
- Floating recording overlay with persistence and motion handling.
- GitHub-based update check system with local override capability.
- Maintainer tooling for diagnostics, pronunciation resources, and quality gates.
- Unit testing and coverage gates for core subsystems.

### Security

- No telemetry.
- No background speech collection.
- No network usage during transcription.

### Notes

KeyVox is designed as a deterministic, local-first dictation tool.  
All speech processing occurs on-device and no user speech data is transmitted or stored remotely.
