# Changelog

All notable changes to `KeyVoxWhisper` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal runtime tracking within the KeyVox monorepo.

---

## [1.1.0] - 2026-07-27

Complete language identifiers and bundled voice-activity detection for shared Whisper clients.

### Includes

- Expanded `WhisperLanguage` from Auto Detect and English to the complete language set recognized by the pinned `whisper.cpp` runtime.
- Added iterable language metadata so shared clients can derive model-specific language catalogs without maintaining duplicate platform lists.
- Preserved the existing Auto Detect default and raw language-code mapping used by Whisper transcription parameters.
- Bundled the official Silero `v5.1.2` voice-activity model used by the pinned `whisper.cpp` runtime so clients do not require a separate model download.
- Added a package-owned voice-activity detector that exposes frame probabilities and detected speech ranges without coupling clients directly to the upstream C API.
- Added configurable speech probability, minimum speech duration, minimum silence duration, and speech-padding inputs for conservative whole-capture analysis.

### Notes

- `1.1.0` bumps the tracked minor runtime version for `KeyVoxWhisper` to cover reusable explicit-language selection and bundled voice-activity detection.

---

## [1.0.1] - 2026-07-16

Updates the bundled `whisper.cpp` runtime to prevent the ends of dictations from being skipped when less than one second of audio remains after the final decoded segment.

### Changed

- Updated the pinned `whisper.cpp` XCFramework from `v1.7.5` to `v1.7.6`.
- Adopted the upstream decoder fix that reduces the unprocessed end-of-audio threshold from one second to 100 milliseconds.

## [1.0.0] - 2026-03-30

Baseline tracked release of the KeyVox Whisper runtime wrapper package.

This entry establishes the first explicit package version for `KeyVoxWhisper` and marks the current Whisper bridge behavior as the starting point for future package-level release tracking inside the monorepo.

### Includes

- A package-owned Swift wrapper around the pinned `whisper.cpp` XCFramework runtime used by KeyVox.
- Shared transcription entry points through `Whisper`, along with package-owned parameter mapping, transcription result models, language handling, and runtime error surfaces.
- Compatibility-layer ownership for upstream `whisper.cpp` naming or C API drift so those adjustments remain isolated inside the package.
- Explicit upstream binary pinning through `Package.swift`, including the current release URL and checksum used by the monorepo.
- Package regression coverage for wrapper behavior, parameter compatibility, and core transcription expectations.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxWhisper`; this changelog does not attempt to backfill earlier internal wrapper history prior to formal package versioning.
- Future entries should focus on meaningful runtime, compatibility, pinning, and wrapper-behavior changes that affect the shipped Whisper layer.
