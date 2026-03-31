# Changelog

All notable changes to `KeyVoxWhisper` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal runtime tracking within the KeyVox monorepo.

---

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
