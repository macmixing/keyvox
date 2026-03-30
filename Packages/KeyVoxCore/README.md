# KeyVoxCore

`KeyVoxCore` is the shared engine package behind KeyVox's local-first dictation pipeline.

It holds the reusable transcription, dictionary, normalization, list-formatting, audio-processing, and pronunciation logic that can be wired into platform-specific hosts without moving product behavior into UI or app-lifecycle code.

## Why This Package Exists

- Keeps the speech engine separate from app shell concerns such as windows, settings presentation, overlay rendering, and platform lifecycle.
- Makes the core pipeline testable in isolation with deterministic unit coverage.
- Centralizes packaged resources such as pronunciation data so shared behavior does not depend on app-target-only file layout.
- Provides a stable package boundary for the engine code that KeyVox relies on across host environments.

## What Lives Here

`KeyVoxCore` is responsible for reusable engine behavior, including:

- Whisper-backed transcription orchestration through `WhisperService`.
- Dictation pipeline composition through `DictationPipeline`.
- Post-processing through `TranscriptionPostProcessor`.
- Custom dictionary persistence, indexing, correction, and hint-prompt generation.
- Deterministic list detection and rendering.
- Audio chunking, silence policy helpers, signal metrics, and capture post-processing.
- Pronunciation lexicon access, phonetic encoding, and replacement scoring.
- Shared packaged pronunciation resources loaded through `Bundle.module`.

## What Does Not Live Here

This package intentionally does not own host-application concerns:

- Window or scene lifecycle
- Settings UI
- Overlay visuals or branding
- Keyboard hooks or global event monitoring
- Paste injection strategy
- Update feeds or release checks
- Cloud sync coordinators or platform persistence policy outside the package's own local stores

That split is intentional. `KeyVoxCore` should stay focused on reusable engine behavior, while host targets remain responsible for integration seams and user-facing application structure.

## Design Goals

- Local-first: the engine is built for on-device transcription and deterministic text cleanup.
- Strict separation of concerns: package logic stays reusable and UI-agnostic.
- Predictable behavior: normalization and formatting are staged deliberately, not opportunistically.
- Fail-safe persistence: dictionary storage favors durability and explicit degraded-state reporting over silent loss.
- Testability: pure helpers and clear orchestration boundaries are preferred so behavior can be covered by package tests.

## Package Layout

- `Package.swift`
  Declares the `KeyVoxCore` library product and the local dependency on `KeyVoxWhisper`.
- `Sources/KeyVoxCore/Transcription/`
  High-level pipeline assembly and post-processing entry points.
- `Sources/KeyVoxCore/Services/Whisper/`
  Whisper model lifecycle, chunk transcription flow, and paragraph-aware chunk assembly.
- `Sources/KeyVoxCore/Language/`
  Dictionary models, matching, phonetic scoring, and pronunciation-lexicon access.
- `Sources/KeyVoxCore/Lists/`
  Spoken-list detection, run selection, trailing split handling, and rendering.
- `Sources/KeyVoxCore/Normalization/`
  Small focused text-normalization passes used by the post-processing pipeline.
- `Sources/KeyVoxCore/Audio/`
  Shared signal metrics, silence policy, capture classification, and frame post-processing helpers.
- `Sources/KeyVoxCore/Resources/Pronunciation/`
  Bundled lexicon data, common-word data, and source/license metadata.
- `Tests/KeyVoxCoreTests/`
  Package-owned regression coverage for engine behavior.

## Core Runtime Flow

At a high level, the package is designed to support this engine flow:

1. Audio frames are segmented conservatively with `AudioParagraphChunker` when paragraph-aware transcription is enabled.
2. `WhisperService` runs inference through `KeyVoxWhisper`, tracks request lifecycle, and reports likely no-speech outcomes.
3. `DictationPipeline` coordinates transcription, post-processing, word-count recording, and final text handoff to a host-provided paste boundary.
4. `TranscriptionPostProcessor` applies ordered cleanup stages, including dictionary correction, list formatting, and targeted normalization passes.
5. The host app remains responsible for where audio came from and what happens with the final text.

## Main Entry Points

### `WhisperService`

`WhisperService` is the package's inference-facing runtime service.

It is responsible for:

- Resolving the model path through an injected closure
- Warming and unloading the model
- Running transcription on frame buffers or audio files
- Managing dictionary hint prompts
- Tracking active requests so stale completions do not overwrite current state
- Reporting likely no-speech results for higher-level orchestration

This type is `@MainActor` because it exposes observable runtime state and is intended to be owned by a host coordinator.

### `DictationPipeline`

`DictationPipeline` is the package's clean orchestration boundary for:

- running transcription
- applying post-processing
- recording spoken-word totals through a host-provided callback
- handing final text back to the host through a paste callback

The pipeline does not know about windows, controls, or clipboard behavior. Those remain external integration details.

### `TranscriptionPostProcessor`

`TranscriptionPostProcessor` turns raw model output into final text suitable for insertion.

Its staged pipeline currently covers:

- email literal cleanup
- dictionary matching and correction
- idiom normalization
- colon and math normalization
- optional list formatting
- laughter cleanup
- character-spam cleanup
- time normalization
- website/domain normalization
- four-digit quantity grouping
- whitespace cleanup
- sentence capitalization
- terminal punctuation finishing
- optional all-caps override

The ordering is deliberate. Earlier stages stabilize structure, while later stages clean up residual model output without fighting the structural passes that came before them.

### `DictionaryStore`

`DictionaryStore` is the package-owned persistence layer for custom vocabulary.

It provides:

- local add, update, delete, and replace-all operations
- duplicate protection based on normalized phrase comparison
- disk-backed persistence with backup recovery
- degraded durability reporting when backup writes fail
- persisted snapshot freshness metadata
- prompt generation through `whisperHintPrompt(...)` for vocabulary-aware inference

This store is intentionally conservative. Invalid sync snapshots are rejected, corrupted files are quarantined, and recovery paths are surfaced through observable warnings instead of being hidden.

### `DictionaryMatcher`

`DictionaryMatcher` owns correction logic for custom phrases and dictionary-backed email recovery.

Internally it uses:

- normalized tokenization
- phonetic and textual scoring
- overlap resolution
- split-join evaluation
- stylized-match guards
- common-word protection

The goal is to preserve valid dictionary corrections without letting ordinary prose collapse into false positives.

### List Formatting Types

The list subsystem is built from focused reusable pieces:

- `ListPatternDetector`
- `ListPatternRunSelector`
- `ListPatternTrailingSplitter`
- `ListRenderer`
- `ListFormattingEngine`

Public supporting models such as `DetectedList`, `DetectedListItem`, and `ListRenderMode` make the behavior usable outside the package's internal pipeline when needed.

### Audio Helpers

The audio utilities in this package are intentionally narrow and reusable:

- `AudioParagraphChunker` finds conservative chunk boundaries from silence windows.
- `AudioSignalMetrics` provides pure signal metrics such as RMS and peak values.
- `AudioSilenceGatePolicy` defines shared silence thresholds.
- `AudioCaptureClassifier` applies shared capture-quality heuristics.
- `AudioPostProcessing` keeps reusable frame-cleanup behavior out of host-specific recorder code.

## Pronunciation Resources

`KeyVoxCore` packages pronunciation assets under:

- `Sources/KeyVoxCore/Resources/Pronunciation/lexicon-v1.tsv`
- `Sources/KeyVoxCore/Resources/Pronunciation/common-words-v1.txt`
- `Sources/KeyVoxCore/Resources/Pronunciation/LICENSES.md`
- `Sources/KeyVoxCore/Resources/Pronunciation/sources.lock.json`

These resources are loaded through `Bundle.module`, which keeps resource access package-owned instead of depending on the host application's bundle layout.

`PronunciationLexicon` and `KeyVoxCoreResourceText` provide the package-facing access points for these bundled assets.

## Dependency

`KeyVoxCore` depends on the local `KeyVoxWhisper` package for the Swift wrapper around `whisper.cpp`.

That dependency boundary is deliberate:

- `KeyVoxWhisper` handles the native transcription bridge.
- `KeyVoxCore` handles engine behavior built around that bridge.

## Using The Package

The exact host wiring will vary, but the intended layering looks like this:

1. The host provides a model-path resolver and owns a `WhisperService`.
2. The host owns a `DictionaryStore` rooted at its chosen base directory.
3. The host creates a `TranscriptionPostProcessor`.
4. The host builds a `DictationPipeline` by injecting:
   - a transcription provider
   - dictionary entry access
   - formatting and capitalization settings
   - word-count recording behavior
   - final text insertion behavior
5. The host passes captured audio frames into the pipeline and reacts to the result.

Example:

```swift
import Foundation
import KeyVoxCore

@MainActor
func makePipeline(baseDirectoryURL: URL, modelURL: URL) -> DictationPipeline {
    let dictionaryStore = DictionaryStore(baseDirectoryURL: baseDirectoryURL)
    let postProcessor = TranscriptionPostProcessor()
    let whisperService = WhisperService(modelPathResolver: { modelURL.path })

    return DictationPipeline(
        transcriptionProvider: whisperService,
        postProcessor: postProcessor,
        dictionaryEntriesProvider: { dictionaryStore.entries },
        autoParagraphsEnabledProvider: { true },
        listFormattingEnabledProvider: { true },
        capsLockEnabledProvider: { false },
        listRenderModeProvider: { .multiline },
        recordSpokenWords: { _ in },
        pasteText: { finalText in
            print(finalText)
        }
    )
}
```

The package intentionally stops at the engine boundary. The host decides how audio is captured, how settings are stored, and how final text is delivered.

## Testing

The package ships with focused unit coverage under `Tests/KeyVoxCoreTests/`, including:

- transcription pipeline behavior
- dictionary matching and persistence
- normalization regressions
- list detection and rendering
- pronunciation and scoring helpers
- Whisper chunking and request-state safety
- audio post-processing and silence heuristics

Run the package tests with:

```bash
swift test --package-path Packages/KeyVoxCore
```

## Platform Support

The package currently declares:

- macOS 13+

That platform declaration reflects the package manifest today. The package itself is structured as shared engine code and is intentionally kept separate from host-application UI concerns.

## Maintenance Notes

- Keep reusable behavior in this package and host-specific integration outside it.
- Prefer small focused helper types over large cross-cutting utility files.
- Preserve deterministic pipeline ordering when adjusting post-processing.
- Treat pronunciation resources and dictionary behavior as package-owned engine data, not app-owned presentation details.
- Add regressions for edge cases whenever matcher, normalization, or chunking behavior changes.
