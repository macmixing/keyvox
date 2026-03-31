# KeyVoxParakeet

`KeyVoxParakeet` is KeyVox's local Swift wrapper around the Parakeet transcription runtime used for on-device Core ML inference.

It provides a package-owned API boundary for Parakeet model loading, runtime lifecycle, transcription, cancellation, and vocabulary-aware decoding without pushing Core ML runtime details into host targets.

## Why This Package Exists

- Keeps Parakeet-specific transcription behavior separate from app shell concerns and separate from `KeyVoxCore` pipeline orchestration.
- Provides a stable Swift surface for Parakeet-backed transcription through `Parakeet`, `ParakeetParams`, and `ParakeetSegment`.
- Isolates Core ML backend details, decoder logic, and vocabulary loading inside one package boundary.
- Keeps host integration simple: consumers can `import KeyVoxParakeet` instead of wiring backend internals directly.

## Design Goals

- Local-first: built for on-device transcription with local model assets.
- Thin public surface: expose a small stable Swift API while keeping backend details internal.
- Clear runtime ownership: model loading, request invalidation, cancellation, and unloading stay package-owned.
- Backend isolation: Core ML implementation details remain separate from package consumers.
- Testability: runtime behavior can be validated through package tests without app-target coupling.

## What Lives Here

`KeyVoxParakeet` is responsible for reusable Parakeet runtime behavior, including:

- public transcription entry points through `Parakeet`
- inference configuration through `ParakeetParams`
- runtime lifecycle and request invalidation through `ParakeetRuntime`
- Core ML backend loading and decoding under `ParakeetCoreML/`
- vocabulary loading and prompt tokenization through `ParakeetVocabulary`
- package-owned Parakeet error types and segment models

## What Does Not Live Here

This package intentionally does not own:

- dictation pipeline orchestration
- list formatting or text normalization
- dictionary correction or persistence
- audio capture, chunking, or silence policy
- UI, settings, overlays, or app lifecycle
- paste behavior or host integration policy

Those concerns belong in other package or app boundaries. `KeyVoxParakeet` stays focused on the Parakeet runtime layer itself.

## Package Layout

- `Package.swift`
  Declares the `KeyVoxParakeet` library product and supported platforms.
- `Sources/KeyVoxParakeet/Parakeet.swift`
  Public wrapper for loading a model, running transcription, cancelling, and unloading.
- `Sources/KeyVoxParakeet/ParakeetParams.swift`
  Public inference options such as language, initial prompt, timestamps, and alternatives.
- `Sources/KeyVoxParakeet/ParakeetRuntime.swift`
  Internal runtime ownership, backend selection, request invalidation, and unload behavior.
- `Sources/KeyVoxParakeet/ParakeetVocabulary.swift`
  Vocabulary loading, token classification, and prompt token support.
- `Sources/KeyVoxParakeet/ParakeetError.swift`
  Package-owned runtime and initialization errors.
- `Sources/KeyVoxParakeet/Segment.swift`
  Public transcription result models.
- `Sources/KeyVoxParakeet/ParakeetCoreML/`
  Internal Core ML backend implementation, support helpers, tensor bridging, inference, and decoding.
- `Tests/KeyVoxParakeetTests/ParakeetTests.swift`
  Package-owned regression coverage for runtime and vocabulary behavior.

## Main Entry Points

### `Parakeet`

`Parakeet` is the package's public runtime-facing wrapper.

It is responsible for:

- loading a model from a URL
- storing current `ParakeetParams`
- running transcription on audio frames
- exposing metadata-aware transcription results
- cancelling an active transcription
- unloading the runtime

### `ParakeetParams`

`ParakeetParams` holds public inference configuration for:

- `languageCode`
- `initialPrompt`
- `enableTimestamps`
- `maxAlternatives`

The package keeps these options package-owned so host code does not need to understand backend-specific request plumbing.

### `ParakeetRuntime`

`ParakeetRuntime` is the internal lifecycle owner for:

- backend construction
- request identity tracking
- stale request invalidation
- cancellation behavior
- runtime unload behavior
- deciding whether a model URL can produce a default backend

This keeps stateful runtime logic out of the public wrapper and out of host application code.

### `ParakeetCoreMLBackend`

The Core ML backend under `Sources/KeyVoxParakeet/ParakeetCoreML/` is responsible for:

- loading Parakeet model artifacts from a model directory
- handling tensor and `MLMultiArray` bridging
- running encoder and decoder inference
- applying decoding logic to produce transcription output

The package hides that implementation behind the internal runtime backend protocol so the public API remains stable.

### `ParakeetVocabulary`

`ParakeetVocabulary` loads the packaged vocabulary JSON from the model directory and supports:

- token lookup by ID
- ID lookup by token
- token classification
- greedy prompt tokenization

This keeps vocabulary logic out of the app layer and close to the Parakeet runtime that depends on it.

## Model Expectations

The default backend expects a model URL that resolves to a local directory. If the URL does not point to a local file URL, initialization fails. If the file system entry does not exist, initialization fails. If the entry is a file instead of a directory, the runtime currently treats that as unavailable for the default backend.

Vocabulary loading expects a Parakeet vocabulary JSON inside the model directory and supports the current canonical and fallback file names used by this package.

## Using The Package

Example:

```swift
import Foundation
import KeyVoxParakeet

func transcribe(audioFrames: [Float], modelURL: URL) async throws -> [ParakeetSegment] {
    let runtime = try Parakeet(
        fromModelURL: modelURL,
        withParams: ParakeetParams(
            languageCode: "en",
            initialPrompt: "",
            enableTimestamps: false,
            maxAlternatives: 1
        )
    )

    defer {
        runtime.unload()
    }

    return try await runtime.transcribe(audioFrames: audioFrames)
}
```

The package intentionally stops at the runtime boundary. Host code decides where audio came from, how model directories are resolved, and what happens with the resulting transcription.

## Testing

The package includes focused runtime coverage under `Tests/KeyVoxParakeetTests/`, including:

- initialization failure handling
- runtime unavailable behavior
- cancellation behavior
- metadata mapping
- decoder projection helpers
- vocabulary prompt tokenization

Run the package tests with:

```bash
swift test --package-path Packages/KeyVoxParakeet
```

## Platform Support

The package currently declares:

- macOS 13+
- iOS 18+

## Maintenance Notes

- Keep Parakeet runtime behavior package-owned and keep higher-level dictation orchestration elsewhere.
- Preserve the small public API surface when changing backend internals.
- Prefer backend-specific fixes inside this package instead of leaking them into host code.
- Add package regressions whenever runtime lifecycle, decoding, or vocabulary behavior changes.
