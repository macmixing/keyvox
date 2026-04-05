# KeyVoxTTS

`KeyVoxTTS` is KeyVox's local Swift package for PocketTTS runtime loading, text preparation, chunk planning, and streamed audio frame generation.

It provides a package-owned API boundary for local TTS inference, asset layout, compute-mode coordination, and sentence-piece tokenization without pushing PocketTTS runtime details into host targets.

## Why This Package Exists

- Keeps PocketTTS-specific runtime behavior separate from app shell concerns and separate from higher-level playback orchestration.
- Provides a stable Swift surface for local TTS through `KeyVoxPocketTTSRuntime`, `KeyVoxTTSVoice`, and `KeyVoxTTSAudioFrame`.
- Isolates Core ML inference, asset loading, text normalization, and chunk planning inside one package boundary.
- Keeps host integration simple: consumers can `import KeyVoxTTS` instead of wiring model layout and inference internals directly.

## Design Goals

- Local-first: built for on-device speech generation with local PocketTTS assets.
- Thin public surface: expose a small stable Swift API while keeping runtime internals package-owned.
- Clear asset expectations: model layout, asset loading, and validation stay close to the runtime that depends on them.
- Deterministic preparation: text normalization and chunk planning remain package-owned so host behavior stays consistent.
- Testability: text preparation and chunk planning behavior can be validated through package tests without app-target coupling.

## What Lives Here

`KeyVoxTTS` is responsible for reusable PocketTTS runtime behavior, including:

- public runtime loading and streaming entry points through `KeyVoxPocketTTSRuntime`
- local asset layout and model loading through `KeyVoxTTSAssetLayout` and `PocketTTSAssetLoader`
- streamed audio frame models through `KeyVoxTTSAudioFrame`
- voice and error modeling through `KeyVoxTTSVoice` and `KeyVoxTTSError`
- text normalization and chunk planning through `PocketTTSTextNormalizer` and `PocketTTSChunkPlanner`
- Core ML inference utilities for Mimi, Flow, and KV-cache model execution
- sentence-piece parsing and tokenization support
- package-owned compute-mode coordination for foreground and background-safe runtime preparation

## What Does Not Live Here

This package intentionally does not own:

- app playback orchestration
- replay caching or transport UI
- download catalogs, install flows, or model repair UI
- unlock logic, monetization, or settings presentation
- app lifecycle routing or scene coordination
- transcript UI or transport copy

Those concerns belong in host application targets. `KeyVoxTTS` stays focused on the PocketTTS runtime layer itself.

## Package Layout

- `Package.swift`
  Declares the `KeyVoxTTS` library product and supported platforms.
- `Sources/KeyVoxTTS/KeyVoxPocketTTSRuntime/KeyVoxPocketTTSRuntime.swift`
  Public runtime wrapper for loading assets and generating streamed audio.
- `Sources/KeyVoxTTS/KeyVoxPocketTTSRuntime/KeyVoxPocketTTSRuntime+Assets.swift`
  Runtime asset preparation helpers and model loading support.
- `Sources/KeyVoxTTS/KeyVoxPocketTTSRuntime/KeyVoxPocketTTSComputeModeController.swift`
  Package-owned compute-mode coordination for runtime preparation.
- `Sources/KeyVoxTTS/KeyVoxPocketTTSRuntime/KeyVoxPocketTTSStreamGenerator.swift`
  Stream generation support for producing `KeyVoxTTSAudioFrame` output.
- `Sources/KeyVoxTTS/KeyVoxTTSAssetLayout.swift`
  Canonical PocketTTS asset path and layout helpers.
- `Sources/KeyVoxTTS/KeyVoxTTSAudioFrame.swift`
  Public audio frame model used by host playback layers.
- `Sources/KeyVoxTTS/KeyVoxTTSError.swift`
  Package-owned runtime and asset-loading errors.
- `Sources/KeyVoxTTS/KeyVoxTTSVoice.swift`
  Voice metadata surface for installed PocketTTS voices.
- `Sources/KeyVoxTTS/PocketTTSAssetLoader.swift`
  Internal asset-loading helpers.
- `Sources/KeyVoxTTS/PocketTTSChunkPlanner.swift`
  Package-owned text chunk planning for long-form synthesis.
- `Sources/KeyVoxTTS/PocketTTSTextNormalizer.swift`
  Package-owned text normalization before synthesis.
- `Sources/KeyVoxTTS/PocketTTS*.swift`
  Internal inference helpers, constants, and model execution support.
- `Sources/KeyVoxTTS/SentencePiece*.swift`
  Sentence-piece parsing and tokenization support used by the runtime.
- `Tests/KeyVoxTTSTests/PocketTTSChunkPlannerTests.swift`
  Package-owned regression coverage for text normalization and chunk planning behavior.

## Main Entry Points

### `KeyVoxPocketTTSRuntime`

`KeyVoxPocketTTSRuntime` is the package's public runtime-facing wrapper.

It is responsible for:

- loading a PocketTTS asset directory
- preparing model assets for inference
- coordinating compute mode
- generating streamed audio frames
- keeping runtime-level TTS behavior package-owned

### `KeyVoxTTSAssetLayout`

`KeyVoxTTSAssetLayout` defines the expected asset shape for PocketTTS model directories and keeps path resolution consistent across host targets.

### `PocketTTSTextNormalizer`

`PocketTTSTextNormalizer` performs package-owned text cleanup before synthesis, including normalization needed for chunk planning and sentence preparation.

### `PocketTTSChunkPlanner`

`PocketTTSChunkPlanner` breaks prepared text into synthesis-friendly chunks for short-form and long-form generation while preserving more natural boundaries where possible.

### `KeyVoxTTSAudioFrame`

`KeyVoxTTSAudioFrame` is the package-owned public model used to hand synthesized audio frames to host playback layers.

## Asset Expectations

The runtime expects a valid PocketTTS asset directory with the model artifacts required by the current package layout. Asset loading, path resolution, and runtime preparation are package-owned so host applications do not need to understand internal PocketTTS file structure.

## Using The Package

Example:

```swift
import Foundation
import KeyVoxTTS

func makeRuntime(assetDirectoryURL: URL) throws -> KeyVoxPocketTTSRuntime {
    try KeyVoxPocketTTSRuntime(assetDirectoryURL: assetDirectoryURL)
}
```

The package intentionally stops at the runtime boundary. Host code decides where text comes from, how assets are installed, and how generated audio frames are played.

## Testing

The package includes focused coverage under `Tests/KeyVoxTTSTests/`, including:

- text normalization behavior
- chunk planning behavior
- long-form chunk sizing behavior
- punctuation-preserving boundary behavior

Run the package tests with:

```bash
swift test --package-path Packages/KeyVoxTTS
```

## Platform Support

The package currently declares:

- macOS 13+
- iOS 18+

## Maintenance Notes

- Keep PocketTTS runtime behavior package-owned and keep host playback orchestration elsewhere.
- Preserve the small public API surface when changing inference internals.
- Prefer package-level fixes for normalization, chunking, and runtime behavior instead of leaking them into app targets.
- Add package regressions whenever text preparation, chunk planning, asset loading, or runtime behavior changes.
