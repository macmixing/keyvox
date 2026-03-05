# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

## [1.0.0] - 2026-03-05

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