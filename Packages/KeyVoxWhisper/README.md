# KeyVoxWhisper

`KeyVoxWhisper` is KeyVox's local Swift wrapper around official [`whisper.cpp`](https://github.com/ggml-org/whisper.cpp) XCFramework binaries.

## Why This Package Exists

- Provides a project-owned Swift API for transcription (`Whisper`, `WhisperParams`, `Segment`).
- Avoids dependence on stale third-party wrappers.
- Centralizes compatibility fixes when upstream C API names evolve.
- Keeps app-side integration clean (`import KeyVoxWhisper`).

## Design Goals

- Thin wrapper: minimal logic on top of `whisper.cpp`.
- Stable app interface: isolate native API drift inside this package.
- Explicit pinning: binary URL + checksum in `Package.swift`.
- Local-first: no cloud transcription dependency at runtime.

## Package Layout

- `Package.swift`: binary target pin + wrapper target config.
- `Sources/KeyVoxWhisper/Whisper.swift`: context lifecycle + transcription calls.
- `Sources/KeyVoxWhisper/WhisperParams.swift`: decode params bridge + compatibility aliases.
- `Sources/KeyVoxWhisper/Segment.swift`: segment output model.
- `Sources/KeyVoxWhisper/WhisperLanguage.swift`: language enum.
- `Sources/KeyVoxWhisper/WhisperError.swift`: wrapper errors.

## Updating whisper.cpp

1. Pick a new `whisper.cpp` release artifact URL.
2. Download the zip and compute its checksum.
3. Update `Package.swift` URL + checksum.
4. Build KeyVox and run transcription regressions (including silence tests).
5. If upstream C field/function names changed, add compatibility mapping in this package rather than app code.

## Compatibility Policy

When possible, preserve the wrapper's Swift API even if upstream names change. Example: mapping old param names to new native fields in `WhisperParams.swift`.
