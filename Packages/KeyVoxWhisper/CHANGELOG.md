# Changelog

All notable changes to `KeyVoxWhisper` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal runtime tracking within the KeyVox monorepo.

---

## [1.0.1] - 2026-06-08

iOS 27 beta compatibility release for the Whisper Core ML runtime.

KeyVox observed an iOS-only regression on iOS 27.0 Seed 1 where Whisper speech-to-text failed during background execution while using the Apple Neural Engine path through Core ML. The same app, same downloaded Whisper model files, and same transcription flow continued to work on iOS 26.6 beta, and macOS 27 testing did not reproduce the failure. Device logs pointed at the Core ML / Apple Neural Engine prediction path rather than the audio path or the downloaded model artifacts.

This release keeps the Whisper model files unchanged and replaces the upstream remote `whisper.cpp` binary dependency with a KeyVox-built local runtime artifact. The local runtime is still based on `whisper.cpp` v1.7.5, but it changes the Core ML compute policy so iOS 27 and newer use CPU-only execution for the Whisper encoder while older iOS versions and macOS keep the previous behavior.

### Changed

- `1.0.1` bumps the tracked `KeyVoxWhisper` runtime version for the iOS 27 beta Core ML mitigation.
- Added a package-owned `whisper.xcframework` artifact so the app no longer depends on the upstream prebuilt runtime for this emergency compatibility path.
- Added a `KeyVoxWhisper` tool script that rebuilds the local runtime from upstream `whisper.cpp` and applies the iOS 27+ Core ML compute-unit policy.
- Updated `Package.swift` to use the committed local runtime artifact instead of the upstream remote binary target.

### Findings

- The failure is not currently treated as a Whisper model artifact problem; the same model files work on iOS 26.6 beta.
- The failure is not currently treated as a macOS regression; macOS 27 testing works.
- The strongest current read is an iOS 27 beta regression in Core ML / Apple Neural Engine prediction during background execution.
- Forcing the Whisper Core ML encoder away from ANE on iOS 27 restores transcription, so the local runtime patch is a scoped mitigation while Apple beta behavior is investigated.

### Notes

- This is intentionally a package-runtime fix rather than a downloaded model update.
- Apple Feedback was submitted for the iOS 27 beta Core ML / Apple Neural Engine regression.
- The local runtime artifact can be removed later if Apple fixes the beta regression or upstream `whisper.cpp` ships an equivalent compatibility policy.

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
