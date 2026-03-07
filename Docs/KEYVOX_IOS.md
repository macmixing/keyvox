# KeyVox iOS — Full Implementation Plan

> **Purpose**: End-to-end blueprint for building the iOS version of KeyVox as a custom keyboard extension + containing app. Written for blind handoff to any agent or developer who has access to the KeyVox macOS codebase.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Reusable Code Inventory](#2-reusable-code-inventory)
3. [New Code Required](#3-new-code-required)
4. [Phase 1 — Core Package Extraction & macOS Parity](#phase-1--core-package-extraction--macos-parity)
5. [Phase 2 — Audio Capture (Containing App)](#phase-2--audio-capture-containing-app)
6. [Phase 3 — Transcription Pipeline Integration](#phase-3--transcription-pipeline-integration)
7. [Phase 4 — Keyboard Extension](#phase-4--keyboard-extension)
8. [Phase 5 — App ↔ Extension IPC](#phase-5--app--extension-ipc)
9. [Phase 6 — Model Management](#phase-6--model-management)
10. [Phase 7 — Dictionary & Settings](#phase-7--dictionary--settings)
11. [Phase 8 — UI/UX (Containing App)](#phase-8--uiux-containing-app)
12. [Phase 9 — UI/UX (Keyboard Extension)](#phase-9--uiux-keyboard-extension)
13. [Phase 10 — Testing](#phase-10--testing)
14. [Phase 11 — Polish & Ship](#phase-11--polish--ship)
15. [Platform Constraints & Gotchas](#platform-constraints--gotchas)
16. [File-by-File Portability Reference](#file-by-file-portability-reference)

---

## 1. Architecture Overview

### Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    KEYBOARD EXTENSION                       │
│  ┌─────────────┐                                            │
│  │  Mic Button  │── tap ──▶ URL Scheme / Darwin Notify ──┐  │
│  └─────────────┘                                         │  │
│                                                          │  │
│  ┌─────────────┐                                         │  │
│  │ insertText() │◀── read shared UserDefaults/file ◀──┐  │  │
│  └─────────────┘                                      │  │  │
└───────────────────────────────────────────────────────┼──┼──┘
                                                        │  │
┌───────────────────────────────────────────────────────┼──┼──┐
│                    CONTAINING APP                     │  │  │
│                                                       │  │  │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────┐  │  │  │
│  │ AVAudioEngine│──▶│ PostProcessor │──▶│ SharedOut │──┘  │  │
│  │  (capture)   │    │ (14 stages)  │    │(defaults)│     │  │
│  └─────────────┘    └──────────────┘    └──────────┘     │  │
│        ▲                    ▲                              │  │
│        │                    │                              │  │
│  ┌─────┘              ┌────┘                              │  │
│  │ start/stop    ┌────┴─────┐                             │  │
│  │ commands      │ Whisper  │                             │  │
│  │ from ext ─────│ Service  │                             │  │
│  │               └──────────┘                             │  │
└───────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

| Decision | Rationale |
|---|---|
| **Transcription in containing app, not extension** | Keyboard extensions have ~50 MB memory limit. Whisper base model alone is ~142 MB in memory. The containing app has no such limit. |
| **AVAudioEngine in containing app** | Keyboard extensions cannot record audio directly. The containing app owns the `AVAudioSession` and microphone. |
| **App Groups for shared data** | `UserDefaults(suiteName:)` and shared container directory are the official IPC mechanism between an extension and its containing app. |
| **Darwin Notifications for real-time signaling** | `CFNotificationCenterGetDarwinNotifyCenter()` provides cross-process signaling without requiring the app to be in foreground. |
| **KeyVoxWhisper as-is** | The SPM package already builds for iOS (whisper.cpp ships iOS XCFrameworks). No changes needed. |
| **Background audio mode** | With `UIBackgroundModes: audio`, the containing app stays alive and can record/transcribe while backgrounded. The user never has to leave their current app. |

### App Lifecycle & Background Audio (Critical UX)

There are two distinct flows depending on whether the containing app is already running:

#### Flow A: Seamless (App Already Running — 95% of the time)

This is the **ideal flow**. The user never leaves their current app:

```
User in Messages → taps mic in KeyVox keyboard
  │
  ├── Extension sends Darwin notification (com.keyvox.startRecording)
  │
  ├── KeyVox app (backgrounded) receives notification
  │   ├── AVAudioEngine starts recording (background audio mode)
  │   └── Extension shows "Listening..." indicator
  │
  ├── User taps mic again
  │   ├── Extension sends Darwin notification (com.keyvox.stopRecording)
  │   └── App transcribes in background → writes to shared UserDefaults
  │
  ├── Extension receives Darwin notification (com.keyvox.transcriptionReady)
  │   ├── Reads text from shared UserDefaults
  │   └── textDocumentProxy.insertText(text)
  │
  └── User sees formatted text appear in Messages. Never left the app.
```

#### Flow B: Cold Start (App Was Killed — First Use or After Memory Pressure)

The app was terminated by iOS. The extension must wake it up:

```
User in Messages → taps mic in KeyVox keyboard
  │
  ├── Extension checks: is app alive? (poll shared UserDefaults heartbeat)
  │   └── App is NOT alive → must open it
  │
  ├── Extension opens URL: keyvox://record?returnTo=messages
  │   └── iOS opens KeyVox app (user briefly sees it)
  │
  ├── KeyVox app handles URL:
  │   1. Starts recording immediately
  │   2. Shows minimal recording UI (5-bar waveform)
  │   3. Stores returnTo app identifier
  │
  ├── User taps stop in KeyVox app (or auto-stop on silence)
  │   1. Transcribes audio
  │   2. Writes text to shared UserDefaults
  │   3. Opens returnTo URL to bounce user back
  │      └── OR: User manually switches back
  │
  └── Extension picks up transcription on next activation
```

#### Implementation: Background Audio Keep-Alive

Add to the containing app's `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

In the containing app, configure the audio session to allow background recording:

```swift
// In iOSTranscriptionManager or AppDelegate
func configureBackgroundAudio() {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    } catch {
        // Handle error
    }
}
```

#### Implementation: App Heartbeat for Extension Liveness Check

The containing app writes a heartbeat timestamp every few seconds while running:

```swift
// Containing app — write heartbeat
Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
    UserDefaults(suiteName: "group.com.keyvox.shared")?
        .set(Date().timeIntervalSince1970, forKey: "appHeartbeat")
}

// Keyboard extension — check if app is alive
func isContainingAppAlive() -> Bool {
    guard let heartbeat = UserDefaults(suiteName: "group.com.keyvox.shared")?
        .double(forKey: "appHeartbeat") else { return false }
    let age = Date().timeIntervalSince1970 - heartbeat
    return age < 5.0  // App is alive if heartbeat was within 5 seconds
}
```

#### Implementation: Cold Start URL Scheme with Return-To

Register a URL scheme in the containing app's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>keyvox</string>
        </array>
    </dict>
</array>
```

Handle incoming URL in the containing app:

```swift
// KeyVoxiOSApp.swift
@main
struct KeyVoxiOSApp: App {
    @StateObject var transcriptionManager = iOSTranscriptionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "keyvox" else { return }
        
        if url.host == "record" {
            // Start recording immediately
            transcriptionManager.startRecording()
            
            // After transcription completes, return to the calling app
            transcriptionManager.onTranscriptionComplete = {
                // Attempt to return to previous app
                // Option 1: Open the calling app's URL scheme if known
                // Option 2: Use a short background task then resign active
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIControl().sendAction(
                        #selector(URLSessionTask.suspend),
                        to: UIApplication.shared, for: nil
                    )
                    // This suspends the app, returning to the previous app
                }
            }
        }
    }
}
```

> [!WARNING]
> The "return to previous app" on cold start is inherently imperfect on iOS. There is no official API to programmatically switch back to the previous app. The `suspend` trick works but may be rejected by App Store review. Alternatives:
> 1. **Show a "Go Back" button** that the user taps manually
> 2. **Use a PiP-style compact recording overlay** so the user can switch back themselves while recording continues in background
> 3. **Minimize the cold start pain** by using the app heartbeat strategy to keep the app alive as much as possible, making cold starts extremely rare

> [!TIP]
> **Priority: Make Flow A the default.** If onboarding instructs the user to launch KeyVox once and leave it running, the app will stay backgrounded indefinitely (thanks to the audio background mode). Cold start (Flow B) should only happen after a device restart or extreme memory pressure. Design the UX around Flow A being the normal experience.

---

## 2. Reusable Code Inventory

Every file below is pure Swift (Foundation only) and compiles on iOS with zero changes. These now form the extracted `Packages/KeyVoxCore` shared package, which was validated against the existing macOS app before any iOS project work.

### Language Engine (10 files — copy verbatim)

| File | Path | Purpose |
|---|---|---|
| `DictionaryMatcher.swift` | `Core/Language/Dictionary/` | Main matcher with overlap resolution, clause boundaries |
| `DictionaryMatcher+Models.swift` | `Core/Language/Dictionary/` | `CompiledEntry`, `ProposedReplacement`, tokenizer types |
| `DictionaryMatcher+OverlapResolver.swift` | `Core/Language/Dictionary/` | Non-overlapping selection with scoring |
| `DictionaryMatcher+Tokenizer.swift` | `Core/Language/Dictionary/` | NaturalLanguage tokenization with fallback |
| `DictionaryEntry.swift` | `Core/Language/Dictionary/` | `Codable` entry model |
| `DictionaryTextNormalization.swift` | `Core/Language/Dictionary/` | Case-aware replacement helpers |
| `PhoneticEncoder.swift` | `Core/Language/` | 8-char phonetic code generation |
| `PronunciationLexicon.swift` | `Core/Language/` | Static lexicon for common words |
| `ReplacementScorer.swift` | `Core/Language/` | Multi-signal scoring (text + phonetic + context) |
| `DictionaryStore.swift` | `Core/Language/Dictionary/` | Persistence with backup/quarantine logic |

### Email Resolution (5 files — copy verbatim)

| File | Path | Purpose |
|---|---|---|
| `DictionaryEmailEntry.swift` | `Core/Language/Dictionary/Email/` | Email-specific entry model |
| `DictionaryMatcher+EmailResolution.swift` | `Core/Language/Dictionary/Email/` | Email address matching orchestrator |
| `DictionaryMatcher+EmailNormalization.swift` | `Core/Language/Dictionary/Email/` | Domain + local-part normalization |
| `DictionaryMatcher+EmailParsing.swift` | `Core/Language/Dictionary/Email/` | Email span extraction |
| `DictionaryMatcher+EmailDomainResolution.swift` | `Core/Language/Dictionary/Email/` | Domain suffix matching |

### Normalization Pipeline (12 files — copy verbatim)

| File | Path | Purpose |
|---|---|---|
| `TranscriptionPostProcessor.swift` | `Core/Transcription/` | 14-stage pipeline orchestrator with debug logging |
| `EmailAddressNormalizer.swift` | `Core/Normalization/` | "john at gmail dot com" → `john@gmail.com` |
| `WebsiteNormalizer.swift` | `Core/Normalization/` | "example dot com" → `example.com` |
| `TimeExpressionNormalizer.swift` | `Core/Normalization/` | "two thirty pm" → `2:30 PM` |
| `MathExpressionNormalizer.swift` | `Core/Normalization/` | "five plus three" → `5 + 3` |
| `ColonNormalizer.swift` | `Core/Normalization/` | Colon spacing normalization |
| `SentenceCapitalizationNormalizer.swift` | `Core/Normalization/` | Sentence-start capitalization |
| `TerminalPunctuationNormalizer.swift` | `Core/Normalization/` | Trailing period for time expressions |
| `AllCapsOverrideNormalizer.swift` | `Core/Normalization/` | Force all caps when caps lock is on |
| `WhitespaceNormalizer.swift` | `Core/Normalization/` | Collapse whitespace, preserve list structure |
| `LaughterNormalizer.swift` | `Core/Normalization/` | Normalize laughter artifacts |
| `CharacterSpamNormalizer.swift` | `Core/Normalization/` | Collapse repeated character spam |

### List Formatting (7 files — copy verbatim)

| File | Path | Purpose |
|---|---|---|
| `ListFormattingEngine.swift` | `Core/Lists/` | List detection + formatting orchestrator |
| `ListFormattingTypes.swift` | `Core/Lists/` | `ListRenderMode` enum, formatting types |
| `ListPatternDetector.swift` | `Core/Lists/` | Ordinal/bullet/letter detection with locale fallback |
| `ListPatternMarker.swift` | `Core/Lists/` | Marker types (numbered, lettered, bulleted) |
| `ListPatternMarkerParser.swift` | `Core/Lists/` | Locale-aware marker parsing |
| `ListPatternRunSelector.swift` | `Core/Lists/` | Best-run selection with delimiter scoring |
| `ListPatternTrailingSplitter.swift` | `Core/Lists/` | Trailing text splitting for markers |
| `ListRenderer.swift` | `Core/Lists/` | Render list to multiline or inline format |

### Whisper Service (4 files — copy verbatim)

| File | Path | Purpose |
|---|---|---|
| `WhisperService.swift` | `Core/Services/Whisper/` | State, cancellation, dictionary hint prompt |
| `WhisperService+TranscriptionCore.swift` | `Core/Services/Whisper/` | Chunked transcription, retry logic, no-speech detection |
| `WhisperService+ModelLifecycle.swift` | `Core/Services/Whisper/` | Warmup, unload, model path resolution |
| `WhisperAudioParagraphChunker.swift` | `Core/Services/Whisper/` | Silence-aware audio chunking |

> [!IMPORTANT]
> `WhisperService+ModelLifecycle.swift` should resolve the model path through an injected closure. In Phase 1, macOS uses the existing Application Support path through `AppServiceRegistry`; later, iOS should inject the App Group shared container path. This remains the only platform-specific seam required in these 4 files.

### Pipeline Orchestration (2 files — copy verbatim)

| File | Path | Purpose |
|---|---|---|
| `DictationPipeline.swift` | `Core/Transcription/` | Transcription → post-processing → output pipeline |
| `DictationPromptEchoGuard.swift` | `Core/Transcription/` | Suppress hallucinated dictionary echoes |

### Audio Signal Processing (3 files — copy verbatim)

| File | Path | Purpose |
|---|---|---|
| `AudioSignalMetrics.swift` | `Core/Audio/` | RMS, peak, percentile, windowed analysis |
| `AudioSilencePolicy.swift` | `Core/Audio/` | Silence gate thresholds and policies |
| `AudioCaptureClassification.swift` | `Core/Audio/` | Multi-signal capture classification |

### SPM Package (entire package — use as-is)

| Package | Path | Purpose |
|---|---|---|
| `KeyVoxWhisper` | `Packages/KeyVoxWhisper/` | whisper.cpp XCFramework wrapper. Already supports iOS targets. |

### Audio Post-Processing (partial reuse)

| File | Path | Reusability |
|---|---|---|
| `AudioRecorder+PostProcessing.swift` | `Core/Audio/` | The `removeInternalGaps()` and `normalizeForTranscription()` functions are **pure Swift math** operating on `[Float]`. Extract these into standalone functions in the shared framework. They do not depend on `AudioRecorder`. |

### Phase 1 additions already extracted

| File | Path | Purpose |
|---|---|---|
| `AudioPostProcessing.swift` | `Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/` | Shared home for `removeInternalGaps()` and `normalizeForTranscription()` extracted from `AudioRecorder+PostProcessing.swift` |
| `DictionaryHintPromptGate.swift` | `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/` | Shared hint-prompt decision logic extracted from `TranscriptionManager.shouldUseDictionaryHintPrompt(...)` |

**Total reusable: ~43 files, ~12,000+ lines of tested, production code.**

---

## 3. New Code Required

### Must Build From Scratch

| Component | Estimated Lines | Why |
|---|---|---|
| `KeyVoxKeyboardExtension` (UIInputViewController) | ~300 | iOS keyboard extension entry point. Mic button, state display. |
| `iOSAudioRecorder` (AVAudioEngine-based) | ~250 | Replace `AVCaptureSession` macOS recorder with `AVAudioEngine` for iOS. |
| `AppExtensionIPCManager` | ~200 | Darwin notifications + App Group shared container for bidirectional signaling. |
| `iOSTranscriptionManager` | ~250 | iOS-specific orchestrator (replaces macOS's `TranscriptionManager` which uses `KeyboardMonitor`, `OverlayManager`, `NSSound`, `AXIsProcessTrusted()`). |
| `iOSModelDownloader` (adapt) | ~80 | Adapt `ModelDownloader` for App Group paths + `BGProcessingTask` for background downloads. |
| `ContainingApp UI` (SwiftUI) | ~600 | Onboarding, settings, dictionary editor, model download, recording visualization. |
| `KeyboardExtension UI` (SwiftUI) | ~200 | Mic button, recording indicator, status feedback. |

**Total new code: ~1,880 lines.**

### Must NOT Port (macOS-Only)

| Component | Why |
|---|---|
| `PasteService` + entire `Paste/` tree (10 files) | Uses `AXUIElement`, `NSPasteboard`, `CGEvent`. iOS keyboard extensions use `UITextDocumentProxy.insertText()` — a single method call. |
| `OverlayManager` + `Overlay/` tree (6 files) | Uses `NSPanel`, `NSScreen`. iOS UI is entirely different. |
| `KeyboardMonitor` | Uses `CGEvent` taps for global hotkey. iOS uses keyboard extension button instead. |
| `AudioDeviceManager` (432 lines) | Uses `CoreAudio` device enumeration. iOS has `AVAudioSession.currentRoute`. |
| `AudioRecorder+Session.swift` | Uses `AVCaptureSession` + `AVCaptureDevice`. Replaced by `AVAudioEngine`. |
| `AudioRecorder+Streaming.swift` | `AVCaptureAudioDataOutputSampleBufferDelegate`. Replaced by `AVAudioEngine` tap. |
| `AudioRecorder+Thresholds.swift` | Uses `CoreAudio` `AudioObjectGetPropertyData`. iOS uses `AVAudioSession.inputGain`. |
| `AppUpdateService` / `UpdateFeedConfig` | Sparkle framework for macOS updates. iOS uses TestFlight/App Store. |

---

## Phase 1 — Core Package Extraction & macOS Parity

Phase 1 is now the extraction and validation pass we already completed. The goal here is to create a real shared package, wire the existing macOS app to it, preserve behavior, and defer all iOS project creation until parity is proven.

### 1.1 Repository Shape for Phase 1

Do **not** move the existing repo into `macOS/` or create an `iOS/` folder yet. Keep the current root layout and add the shared package in place:

```
KeyVox/
├── App/
├── Core/
├── Views/
├── KeyVox.xcodeproj
├── KeyVoxTests/
├── Docs/
├── Packages/
│   ├── KeyVoxCore/             (New local Swift package)
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   │   └── KeyVoxCore/
│   │   └── Tests/
│   │       └── KeyVoxCoreTests/
│   └── KeyVoxWhisper/
```

This keeps commit history clean and lets the existing macOS target prove parity before any iOS shell exists.

### 1.2 The Single Source of Truth (`KeyVoxCore` Swift Package)

This part is implemented. `KeyVoxCore` is now a local Swift package at `Packages/KeyVoxCore`, and the reusable engine code was moved there instead of into a new `SharedCore/` root.

1. **Create the Package**: `Packages/KeyVoxCore/Package.swift`
2. **Migrate the Code**: Move the reusable source files into `Packages/KeyVoxCore/Sources/KeyVoxCore/` and move the reusable tests into `Packages/KeyVoxCore/Tests/KeyVoxCoreTests/`.
3. **The `public` Refactor (Crucial)**: Add `public` access control to the package APIs the app targets need to consume, including `DictionaryStore`, `DictionaryMatcher`, `TranscriptionPostProcessor`, `DictationPipeline`, `WhisperService`, `WhisperAudioParagraphChunker`, `AudioSilencePolicy`, `AudioCaptureClassification`, `AudioPostProcessing`, and `DictionaryHintPromptGate`.
4. **Relink the Existing macOS Project**: Remove migrated files from direct app/test target compilation and link the local `KeyVoxCore` package into the existing macOS app and test targets.
5. **Defer iOS Project Wiring**: Do not create or link an iOS project in this phase. That happens only after parity is proven.

This preserves a single engine implementation while keeping the current app working exactly as before.

### 1.3 App Boundary Cleanup

The macOS app remains the integration layer in Phase 1.

1. Add `App/AppServiceRegistry.swift` to own app-specific construction of shared services.
2. Keep filesystem paths and singleton lifetime decisions in the app layer, not in the package.
3. Refactor `TranscriptionManager` so it consumes injected `DictionaryStore`, `WhisperService`, `TranscriptionPostProcessor`, and `DictationPipeline`.
4. Replace the local dictionary-hint gate logic with `DictionaryHintPromptGate.shouldUseHintPrompt(...)`.

This gives iOS a clean future seam without forcing any iOS code into the repo yet.

### 1.4 Defer iOS App Group and Project Setup

The old App Group and project-creation work is **not** part of Phase 1 anymore.

1. Do not create the `iOS/` directory yet.
2. Do not create the containing app target yet.
3. Do not create the keyboard extension target yet.
4. Do not add App Group entitlements yet.

All of that moves to the next milestone, after package extraction and macOS parity are verified.

### 1.5 Extract Audio Math into `KeyVoxCore`

This part is implemented. In `Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/AudioPostProcessing.swift`, extract `removeInternalGaps()` and `normalizeForTranscription()` from `AudioRecorder+PostProcessing.swift` into standalone shared functions:

```swift
// Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/AudioPostProcessing.swift
import Foundation

public enum AudioPostProcessing {
    public static func removeInternalGaps(
        from samples: [Float],
        gapRemovalRMSThreshold: Float
    ) -> [Float] {
        // Copy the exact implementation from AudioRecorder+PostProcessing.swift
    }

    public static func normalizeForTranscription(
        _ samples: [Float],
        targetPeak: Float = 0.9,
        maxGain: Float = 3.0
    ) -> [Float] {
        // Copy exact implementation
    }
}
```

The macOS `AudioRecorder` should call into these helpers so the audio math lives in the shared package.

### 1.6 Fix Model Path via Injection, Not iOS Hardcoding

Do **not** hardcode the iOS App Group path in Phase 1. Instead, make model path resolution injectable so the package stays platform-neutral:

```swift
public init(modelPathResolver: @escaping () -> String?)
```

Use the injected resolver inside `WhisperService+ModelLifecycle.swift`. For macOS, have `AppServiceRegistry` supply the existing Application Support model path. For iOS later, inject the App Group container path from the iOS app target.

### 1.7 Add `KeyVoxWhisper` to `KeyVoxCore`

Add the existing `Packages/KeyVoxWhisper/` as a local SPM dependency of the `KeyVoxCore` package. The whisper.cpp XCFramework already includes iOS slices, but in Phase 1 it is consumed through `KeyVoxCore` while parity is being verified on macOS.

---

## Phase 2 — Audio Capture (Containing App)

Phase 2 is complete.

This phase intentionally focused on recording plumbing only. No transcription, keyboard extension implementation, IPC, or real UI work was added here.

### 2.1 Implemented app-layer routing

Completed files:

- `iOS/KeyVox iOS/App/KeyVoxiOSApp.swift`
- `iOS/KeyVox iOS/App/iOSAppServiceRegistry.swift`
- `iOS/KeyVox iOS/App/KeyVoxURLRoute.swift`
- `iOS/KeyVox iOS/App/KeyVoxURLRouter.swift`

Implemented behavior:

- the containing app launches idle with no active recording session
- the app owns a long-lived `iOSTranscriptionManager`
- incoming URLs are parsed and routed through:
  - `keyvoxios://record/start`
  - `keyvoxios://record/stop`
- invalid routes are ignored safely

### 2.2 Implemented iOS audio capture

Completed files:

- `iOS/KeyVox iOS/Core/Audio/LiveInputSignalState.swift`
- `iOS/KeyVox iOS/Core/Audio/iOSAudioRecorder.swift`
- `iOS/KeyVox iOS/Core/Audio/iOSAudioRecorder+Session.swift`
- `iOS/KeyVox iOS/Core/Audio/iOSAudioRecorder+Streaming.swift`
- `iOS/KeyVox iOS/Core/Audio/iOSAudioRecorder+StopPipeline.swift`

Implemented behavior:

- recording uses `AVAudioSession` + `AVAudioEngine`
- microphone permission is requested through the iOS 17+ `AVAudioApplication` API
- capture is converted to:
  - mono
  - `Float32`
  - `16 kHz`
- the recorder publishes the same capture metadata contract used by the macOS app:
  - `lastCaptureWasAbsoluteSilence`
  - `lastCaptureHadActiveSignal`
  - `lastCaptureWasLikelySilence`
  - `lastCaptureWasLongTrueSilence`
  - `lastCaptureDuration`
  - `lastCaptureHadNonDeadSignal`
  - `maxActiveSignalRunDuration`
- the recorder remains inactive between recordings even though the containing app and manager stay alive

### 2.3 Reused shared core post-processing

Phase 2 reuses `KeyVoxCore` for the stop pipeline instead of duplicating logic in the iOS app.

Implemented behavior:

- raw capture snapshot is passed through `AudioPostProcessing.removeInternalGaps(...)`
- stop-time classification uses `AudioCaptureClassifier.classify(...)`
- accepted captures are normalized with `AudioPostProcessing.normalizeForTranscription(...)`
- silence / likely-silence rejection behavior matches the shared macOS contract

### 2.4 Added verification artifact writing

Completed files:

- `iOS/KeyVox iOS/Core/Audio/Phase2CaptureArtifact.swift`
- `iOS/KeyVox iOS/Core/Audio/Phase2CaptureArtifactWriter.swift`

Implemented behavior:

- every stop writes verification artifacts to app-local `Application Support/Phase2Verification/`
- files written:
  - `latest-snapshot.wav`
  - `latest-transcription-input.wav` when speech is accepted
  - `latest-metadata.json`
- WAV output is:
  - mono
  - `16 kHz`
  - PCM 16-bit

### 2.5 Added iOS orchestration without transcription

Completed file:

- `iOS/KeyVox iOS/Core/Transcription/iOSTranscriptionManager.swift`

Implemented behavior:

- manager states:
  - `.idle`
  - `.recording`
  - `.processingCapture`
- start commands are idempotent
- stop commands are idempotent
- artifact-write failures surface through `lastErrorMessage`
- no `WhisperService`, `DictationPipeline`, dictionary integration, or output insertion work is mixed into this phase

### 2.6 Test and device verification completed

Automated coverage added:

- `iOS/KeyVoxiOSTests/App/KeyVoxURLRouteTests.swift`
- `iOS/KeyVoxiOSTests/Core/Audio/Phase2CaptureArtifactWriterTests.swift`
- `iOS/KeyVoxiOSTests/Core/Audio/iOSStoppedCaptureProcessorTests.swift`
- `iOS/KeyVoxiOSTests/Core/Transcription/iOSTranscriptionManagerTests.swift`

Verified outcomes:

- the iOS app target builds
- the iOS test target passes
- real-device URL-driven recording was verified successfully
- speech capture produced:
  - non-zero snapshot frames
  - non-zero output frames
  - `hadActiveSignal = yes`
  - `absoluteSilence = no`
  - `likelySilence = no`
  - `longTrueSilence = no`
  - snapshot WAV present
  - transcription-input WAV present
  - metadata JSON present

### 2.7 Phase 2 acceptance status

Phase 2 is considered done because all of the following are now true:

- app launches idle
- `keyvoxios://record/start` starts recording
- `keyvoxios://record/stop` stops recording and runs the shared stop pipeline
- internal capture format is mono `Float32 @ 16 kHz`
- verification artifacts are written
- repeated commands are safe
- the architecture remains aligned with the mac app:
  - `App/`
  - `Core/`
  - `Views/`

Phase 3 now begins from a proven recording lifecycle rather than a scaffold.

---

## Phase 3 — Transcription Pipeline Integration

Phase 3 is complete.

This phase extended the working Phase 2 recording path into a real containing-app transcription pipeline without adding keyboard-extension IPC, output insertion, settings UI, or product UI work.

### 3.1 Implemented shared-path and service seams

Completed files:

- `iOS/KeyVox iOS/App/iOSSharedPaths.swift`
- `iOS/KeyVox iOS/App/iOSAppServiceRegistry.swift`
- `iOS/KeyVox iOS/Core/Transcription/iOSDictationService.swift`
- `iOS/KeyVox iOS/Core/Transcription/iOSTranscriptionDebugSnapshot.swift`

Implemented behavior:

- the App Group path seam is now centralized in `iOSSharedPaths`
- the containing app resolves:
  - App Group container URL
  - model path
  - dictionary base directory
- `iOSAppServiceRegistry` now owns iOS-side construction of:
  - `DictionaryStore`
  - `WhisperService`
  - `TranscriptionPostProcessor`
  - `Phase2CaptureArtifactWriter`
  - `iOSTranscriptionManager`
  - `KeyVoxURLRouter`
- the app stays bootable even if the App Group container or model is unavailable

### 3.2 Implemented `iOSTranscriptionManager`

Completed file:

- `iOS/KeyVox iOS/Core/Transcription/iOSTranscriptionManager.swift`

Implemented behavior:

- `iOSTranscriptionManager` now owns the full Phase 3 containing-app pipeline
- state model now includes:
  - `.idle`
  - `.recording`
  - `.processingCapture`
  - `.transcribing`
- accepted capture output now flows through:
  - `WhisperService`
  - `DictationPipeline`
  - `TranscriptionPostProcessor`
- the manager publishes:
  - `lastCaptureArtifact`
  - `lastTranscriptionSnapshot`
  - `lastErrorMessage`
  - `isModelAvailable`
- repeated start/stop commands during recording, processing, or transcription remain safe no-ops

### 3.3 Implemented dictionary and hint-prompt wiring

Implemented behavior:

- the iOS app now instantiates a real `DictionaryStore`
- `TranscriptionPostProcessor` stays synchronized with current dictionary entries
- `WhisperService` stays synchronized with the current dictionary hint prompt
- `DictionaryHintPromptGate` is used before transcription to decide whether hint prompting should be enabled for the capture

This matches the macOS architectural seam while keeping the iOS implementation app-local.

### 3.4 Preserved the Phase 2 artifact pipeline

Phase 3 keeps the Phase 2 verification outputs intact:

- snapshot WAV
- transcription-input WAV when accepted
- metadata JSON

These artifacts are still written before transcription completion is considered done, so recording proof remains available even when:

- capture is rejected
- the model is unavailable
- transcription produces a likely-no-speech result

### 3.5 Implemented debug-state verification instead of UI work

Phase 3 intentionally does **not** add real transcription UI.

Verification for this phase happens through manager debug state:

- `lastTranscriptionSnapshot.rawText`
- `lastTranscriptionSnapshot.finalText`
- `lastTranscriptionSnapshot.wasLikelyNoSpeech`
- `lastTranscriptionSnapshot.inferenceDuration`
- `lastTranscriptionSnapshot.pasteDuration`
- `lastTranscriptionSnapshot.usedDictionaryHintPrompt`
- `lastTranscriptionSnapshot.captureDuration`
- `lastTranscriptionSnapshot.outputFrameCount`

`AppRootView` remains minimal and is not treated as a Phase 3 UI surface.

### 3.6 Phase 3 acceptance status

Phase 3 is considered done because all of the following are now true:

1. The Phase 2 recording flow still works.
2. `iOSTranscriptionManager` owns a real transcription path instead of stopping at capture verification.
3. `WhisperService` is injected through `iOSAppServiceRegistry`.
4. `DictionaryStore` is instantiated in the iOS app and wired into `TranscriptionPostProcessor` and `WhisperService`.
5. Accepted capture output flows into `DictationPipeline`.
6. Successful or suppressed transcription results publish `lastTranscriptionSnapshot`.
7. Missing-model behavior returns to `.idle` cleanly with an explicit error.
8. Silence and likely-no-speech paths do not crash and do not pretend success.
9. No keyboard extension implementation or IPC handoff was mixed into this phase.
10. No real UI/polish work was mixed into this phase.

### 3.7 Known note before Phase 4

During manual validation, the log message below was observed when the app was backgrounded and foregrounded:

`Potential Structural Swift Concurrency Issue: unsafeForcedSync called from Swift Concurrent context.`

This is **not** currently being treated as a Phase 3 blocker. The current evidence points to this being an OS/accessibility-subsystem warning rather than a proven app-specific pipeline bug, and the containing-app record → stop → transcribe flow still completed successfully.

Phase 4 begins from a working containing-app transcription path rather than a recording-only scaffold.

---

## Phase 4 — Keyboard Extension

### 4.1 Create `KeyboardViewController`

```swift
// KeyVoxKeyboard/KeyboardViewController.swift
import UIKit
import KeyVoxCore

class KeyboardViewController: UIInputViewController {
    private let ipcManager = AppExtensionIPCManager()
    private var micButton: UIButton!
    private var isRecording = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupIPCListeners()
    }
    
    private func setupUI() {
        // Create mic button with KeyVox 5-bar identity
        micButton = UIButton(type: .system)
        micButton.setImage(UIImage(systemName: "mic"), for: .normal)
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        
        // Layout with Auto Layout
        view.addSubview(micButton)
        micButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            micButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 60),
            micButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    @objc private func micTapped() {
        if isRecording {
            ipcManager.sendStopCommand()
            isRecording = false
            updateUI(recording: false)
        } else {
            // Open containing app or signal it
            ipcManager.sendStartCommand()
            isRecording = true
            updateUI(recording: true)
        }
    }
    
    private func setupIPCListeners() {
        ipcManager.onTranscriptionReady = { [weak self] text in
            guard let self else { return }
            // Insert text at cursor via UITextDocumentProxy
            self.textDocumentProxy.insertText(text)
            self.isRecording = false
            self.updateUI(recording: false)
        }
        
        ipcManager.onNoSpeech = { [weak self] in
            self?.isRecording = false
            self?.updateUI(recording: false)
        }
    }
    
    private func updateUI(recording: Bool) {
        let imageName = recording ? "mic.fill" : "mic"
        micButton.setImage(UIImage(systemName: imageName), for: .normal)
        micButton.tintColor = recording ? .systemRed : .systemBlue
    }
}
```

> [!IMPORTANT]
> `textDocumentProxy.insertText(text)` is the iOS equivalent of the entire macOS `PasteService`. One method call. No AX injection, no menu fallback, no clipboard snapshot/restore. This is a massive simplification.

### 4.2 Configure Info.plist for Keyboard Extension

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>IsASCIICapable</key>
        <false/>
        <key>PrefersRightToLeft</key>
        <false/>
        <key>PrimaryLanguage</key>
        <string>en-US</string>
        <key>RequestsOpenAccess</key>
        <true/>  <!-- Required for App Group access -->
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.keyboard-service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).KeyboardViewController</string>
</dict>
```

> [!WARNING]
> `RequestsOpenAccess` must be `true` for the extension to read from the App Group container. The user must enable "Allow Full Access" in Settings → Keyboards. The onboarding flow must guide them through this step.

---

## Phase 5 — App ↔ Extension IPC

### 5.1 Create `AppExtensionIPCManager`

This handles bidirectional communication between the keyboard extension and the containing app.

```swift
// KeyVoxCore/IPC/AppExtensionIPCManager.swift
import Foundation

class AppExtensionIPCManager {
    private let appGroupID = "group.com.keyvox.shared"
    
    // Darwin notification names
    private let startRecordingNotification = "com.keyvox.startRecording"
    private let stopRecordingNotification = "com.keyvox.stopRecording"
    private let recordingStartedNotification = "com.keyvox.recordingStarted"
    private let transcriptionReadyNotification = "com.keyvox.transcriptionReady"
    private let noSpeechNotification = "com.keyvox.noSpeech"
    
    // Shared UserDefaults keys
    private let transcriptionKey = "latestTranscription"
    private let stateKey = "recordingState"
    
    // Callbacks
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    var onTranscriptionReady: ((String) -> Void)?
    var onNoSpeech: (() -> Void)?
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    init() {
        registerDarwinObservers()
    }
    
    // MARK: - Extension → App signals
    func sendStartCommand() {
        postDarwinNotification(startRecordingNotification)
    }
    
    func sendStopCommand() {
        postDarwinNotification(stopRecordingNotification)
    }
    
    // MARK: - App → Extension signals
    func notifyExtensionRecordingStarted() {
        sharedDefaults?.set("recording", forKey: stateKey)
        postDarwinNotification(recordingStartedNotification)
    }
    
    func writeTranscription(_ text: String) {
        sharedDefaults?.set(text, forKey: transcriptionKey)
        sharedDefaults?.set("ready", forKey: stateKey)
        postDarwinNotification(transcriptionReadyNotification)
    }
    
    func notifyExtensionTranscriptionComplete() {
        postDarwinNotification(transcriptionReadyNotification)
    }
    
    func notifyExtensionNoSpeech() {
        sharedDefaults?.set("idle", forKey: stateKey)
        postDarwinNotification(noSpeechNotification)
    }
    
    func readLatestTranscription() -> String? {
        let text = sharedDefaults?.string(forKey: transcriptionKey)
        // Clear after reading to prevent stale reuse
        sharedDefaults?.removeObject(forKey: transcriptionKey)
        return text
    }
    
    // MARK: - Darwin Notification Helpers
    private func postDarwinNotification(_ name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(name as CFString), nil, nil, true)
    }
    
    private func registerDarwinObservers() {
        registerDarwinObserver(startRecordingNotification) { [weak self] in
            self?.onStartRecording?()
        }
        registerDarwinObserver(stopRecordingNotification) { [weak self] in
            self?.onStopRecording?()
        }
        registerDarwinObserver(transcriptionReadyNotification) { [weak self] in
            guard let text = self?.readLatestTranscription(), !text.isEmpty else { return }
            self?.onTranscriptionReady?(text)
        }
        registerDarwinObserver(noSpeechNotification) { [weak self] in
            self?.onNoSpeech?()
        }
    }
    
    private func registerDarwinObserver(_ name: String, callback: @escaping () -> Void) {
        // Use CFNotificationCenter with a callback bridge
        // Implementation requires Objective-C bridging or a static callback with context
    }
}
```

### 5.2 Alternative: Shared File-Based IPC

If Darwin notifications prove unreliable for your use case, use a shared file in the App Group container with polling:

```swift
// Write (app side)
let data = text.data(using: .utf8)
try data?.write(to: sharedContainerURL.appendingPathComponent("transcription.txt"))

// Read (extension side, poll every 100ms when waiting)
let text = try String(contentsOf: sharedContainerURL.appendingPathComponent("transcription.txt"))
textDocumentProxy.insertText(text)
try FileManager.default.removeItem(at: sharedContainerURL.appendingPathComponent("transcription.txt"))
```

> [!NOTE]
> Darwin notifications are fire-and-forget with no payload. That's why the transcription text is written to shared `UserDefaults` and the notification just signals "go read it."

---

## Phase 6 — Model Management

### 6.1 Adapt `ModelDownloader` for iOS

The existing `ModelDownloader` is **90% reusable**. Changes needed:

1. **Storage path**: Use the App Group container instead of `~/Library/Application Support/KeyVox/`
2. **Model payload**: Install **both**:
   - `ggml-base.bin`
   - `ggml-base-encoder.mlmodelc`
3. **CoreML unzip**: `Process()` is not available on iOS. Use `ZIPFoundation` SPM package or custom `zlib` wrapper.
4. **Background download**: Use `BGProcessingTask` for downloads that may take a while.

```swift
// Override model URL provider for iOS
let modelURLProvider: () -> URL = {
    guard let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.cueit.keyvox"
    ) else {
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("Models/ggml-base.bin")
    }
    return container
        .appendingPathComponent("Models")
        .appendingPathComponent("ggml-base.bin")
}
```

Verified real-device behavior:

- `WhisperService` successfully loaded `ggml-base.bin` from the App Group container on-device
- whisper.cpp then attempted to load the CoreML encoder from:
  - `<App Group Container>/Models/ggml-base-encoder.mlmodelc`
- if that bundle is missing, transcription still works, but whisper.cpp logs a CoreML load failure and falls back without the CoreML encoder path

So the Phase 6 implementation must treat the CoreML encoder bundle as part of the real model install, not as an optional afterthought.

### 6.2 Remove CoreML Zip Extraction via Process()

The macOS version uses `/usr/bin/unzip` via `Process()`. On iOS, replace with:

```swift
import ZIPFoundation  // SPM: https://github.com/weichsel/ZIPFoundation

private func unzipCoreML(at url: URL) throws {
    let destinationURL = url.deletingLastPathComponent()
    try FileManager.default.unzipItem(at: url, to: destinationURL)
    try FileManager.default.removeItem(at: url)
}
```

> [!IMPORTANT]
> CoreML on iOS might not provide the same acceleration as on macOS for Whisper. However, real-device validation already confirmed that whisper.cpp **does** look for `ggml-base-encoder.mlmodelc` in the App Group `Models/` directory when `ggml-base.bin` is present. If the bundle is missing, the pipeline still functions, but the app logs a CoreML load failure and falls back. Phase 6 should therefore:
> 1. install both the GGML file and the CoreML encoder bundle correctly,
> 2. verify the expected bundle path on-device, and
> 3. only consider dropping the CoreML asset if benchmarking shows no meaningful benefit.

---

## Phase 7 — Dictionary & Settings

### 7.1 Dictionary Store

`DictionaryStore.swift` is **fully reusable**. Only change: inject the App Group base directory:

```swift
```swift
let store = DictionaryStore(
    baseDirectoryURL: FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.keyvox.shared"
    )!
)
```

This ensures dictionary entries are accessible to both the containing app (for editing) and could be read by the extension if needed.

### 7.2 Settings Store

Create a minimal `iOSAppSettingsStore` backed by shared `UserDefaults`:

```swift
class iOSAppSettingsStore: ObservableObject {
    private let defaults: UserDefaults
    
    init(suiteName: String = "group.com.keyvox.shared") {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }
    
    @Published var autoParagraphsEnabled: Bool {
        didSet { defaults.set(autoParagraphsEnabled, forKey: "autoParagraphsEnabled") }
    }
    
    // ... other settings
}
```

### 7.3 iCloud Syncing (`NSUbiquitousKeyValueStore`)

To create a seamless cross-platform experience between Mac and iPhone, sync the Dictionary and Settings via iCloud.

#### Enable iCloud Key-Value Storage
1. In both the macOS and iOS Xcode projects, add the **iCloud** capability.
2. Check **Key-value storage**.

#### The Sync Coordinator

Create a sync manager that observes the ubiquitous store and pushes/pulls changes:

```swift
// SharedCore/Settings/iCloudSyncCoordinator.swift
import Foundation
import Combine

class iCloudSyncCoordinator {
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let localDefaults: UserDefaults
    private let dictionaryStore: DictionaryStore
    private var cancellables = Set<AnyCancellable>()
    
    init(localDefaults: UserDefaults, dictionaryStore: DictionaryStore) {
        self.localDefaults = localDefaults
        self.dictionaryStore = dictionaryStore
        
        // Listen for remote changes from iCloud
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        
        // Push local dict changes to iCloud
        dictionaryStore.$entries
            .dropFirst() // Skip initial load
            .sink { [weak self] entries in
                self?.pushDictionaryToiCloud(entries)
            }
            .store(in: &cancellables)
            
        ubiquitousStore.synchronize()
    }
    
    @objc private func iCloudDataDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }
        
        // If the dictionary changed remotely
        if changedKeys.contains("keyvox_dictionary_v1") {
            pullDictionaryFromiCloud()
        }
        
        // Sync generic settings (auto-paragraphs, list formatting, etc)
        for key in changedKeys where key.starts(with: "kv_setting_") {
            let localKey = String(key.dropFirst("kv_setting_".count))
            if let value = ubiquitousStore.object(forKey: key) {
                localDefaults.set(value, forKey: localKey)
            }
        }
    }
    
    private func pushDictionaryToiCloud(_ entries: [DictionaryEntry]) {
        // Encode entries and save to ubiquitous store
        if let data = try? JSONEncoder().encode(entries) {
            ubiquitousStore.set(data, forKey: "keyvox_dictionary_v1")
            ubiquitousStore.synchronize() // Force push
        }
    }
    
    private func pullDictionaryFromiCloud() {
        guard let data = ubiquitousStore.data(forKey: "keyvox_dictionary_v1"),
              let remoteEntries = try? JSONDecoder().decode([DictionaryEntry].self, from: data) else {
            return
        }
        
        // Simple merge strategy (or replace entirely if assuming last-writer-wins)
        // You could get fancy here with timestamps, but last-writer-wins is usually fine
        // for personal dictionary apps.
        DispatchQueue.main.async {
            // Write to disk using DictionaryStore
            try? self.dictionaryStore.saveAll(entries: remoteEntries)
        }
    }
}
```

> [!TIP]
> `NSUbiquitousKeyValueStore` has a total storage limit of 1 MB per user. Since your dictionary entries are just small JSON structs containing custom vocabulary phrases (the `DictionaryEntry` model), you can easily fit thousands of custom vocabulary entries in this limit. This is completely free for you as the developer—it uses the user's iCloud storage implicitly.

---

## Phase 8 — UI/UX (Containing App)

### 8.1 Screens Required

| Screen | Purpose | Complexity |
|---|---|---|
| **Onboarding** | Microphone permission, keyboard enable, full access enable, model download | High — must guide through Settings app |
| **Home / Recording** | Live recording with 5-bar waveform, transcription display | Medium |
| **Dictionary Editor** | Add/edit/delete custom words (reuse from macOS) | Low |
| **Settings** | Auto-paragraphs, list formatting, model management | Low |
| **Model Download** | Progress bar, error handling (reuse `ModelDownloader` state) | Low |

### 8.2 Five-Bar Waveform (Brand Identity)

Port the RecordingOverlay's five-bar visualization from macOS. The SwiftUI animation code from `RecordingOverlay.swift` is already SwiftUI — it ports directly:

```swift
// The 5-bar visualization from RecordingOverlay.swift
// audioLevel drives bar heights, same formula as macOS
ForEach(0..<5) { index in
    RoundedRectangle(cornerRadius: 2)
        .fill(isRecording ? Color.red : Color.gray)
        .frame(width: 4, height: barHeight(for: index, audioLevel: audioLevel))
        .animation(.easeInOut(duration: 0.1), value: audioLevel)
}
```

### 8.3 Onboarding Flow

iOS onboarding is more complex than macOS because enabling a custom keyboard requires manual user steps:

```
Step 1: Microphone Permission
  └─ Request AVAudioSession.requestRecordPermission()
  └─ Show guidance if denied

Step 2: Enable Keyboard
  └─ Guide user to: Settings → General → Keyboard → Keyboards → Add New Keyboard → KeyVox
  └─ Show screenshot or animation of the path
  └─ Poll for keyboard availability

Step 3: Allow Full Access
  └─ Guide user to: Settings → General → Keyboard → Keyboards → KeyVox → Allow Full Access
  └─ Required for App Group communication
  └─ Show privacy assurance: "Full Access lets KeyVox communicate between the keyboard
     and the app. No data is sent to any server."

Step 4: Download Model
  └─ Reuse ModelDownloader UI
  └─ Show progress, handle errors
```

> [!CAUTION]
> iOS custom keyboard onboarding has high drop-off rates because it requires navigating to system Settings. Make each step crystal clear with visual guidance. Consider using deep links where possible (`UIApplication.shared.open(URL(string: "App-Prefs:")!)`).

---

## Phase 9 — UI/UX (Keyboard Extension)

### 9.1 Overview: Two-State Keyboard

The keyboard extension has **two distinct states** that the entire view transitions between:

| State | Description |
|---|---|
| **Keyboard State** | Numbers & symbols layout, mic button top-right, ABC cycle button bottom-left |
| **Recording State** | Full-keyboard-height `KeyVoxRecordingView` waveform — the entire keyboard "becomes" the signal visualizer |

The transition between states is an animated swap, **not** a navigation push. The keyboard layout fades/scales out, the recording overlay scales in with the same spring pop-in animation from `RecordingOverlay.swift`.

---

### 9.2 Keyboard State Layout (Numbers & Symbols)

At rest, the keyboard extension renders a full **numbers and special characters layout** — mirroring exactly what the user would see pressing `123` on the standard iOS keyboard. This gives the extension a complete, usable keyboard while staying out of the way of the system ABC keyboard.

```
┌──────────────────────────────────────────────────────────┐
│                                               [ 🎤 mic ]  │
├──────────────────────────────────────────────────────────┤
│   1    2    3    4    5    6    7    8    9    0           │
│   -    /    :    ;    (    )    $    &    @    "           │
│  [#+=]  .   ,    ?    !    '            [⌫ delete]        │
│  [ABC]       [        space        ]       [return]        │
└──────────────────────────────────────────────────────────┘
```

**Key elements:**
- **Mic button — top right corner**: The KeyVox entry point. Tapping it triggers the state transition to Recording State.
- **Numbers row (1–0)**: Standard iOS numbers row.
- **Symbols row**: `-  /  :  ;  (  )  $  &  @  "` — mirrors the iOS `123` view exactly.
- **`[#+=]` button**: Swaps to the alternate symbols sub-view within the extension: `[ ] { } # % ^ * + = | ~ < > € £ ¥ ·`
- **`[⌫]` delete**: Calls `textDocumentProxy.deleteBackward()`.
- **ABC button — bottom left**: Calls `advanceToNextInputMode()` — cycles to the next keyboard in the user's list, taking them back to the system ABC keyboard. No custom logic, Apple provides this API to all keyboard extensions.
- **Space bar and Return**: `textDocumentProxy.insertText(" ")` and `textDocumentProxy.insertText("\n")` respectively.

> [!NOTE]
> All number/symbol key taps call `textDocumentProxy.insertText("1")` etc. The entire key layout is a SwiftUI grid — no UIKit text field involved.

---

### 9.3 Recording State Layout (`KeyVoxRecordingView` Full-Bleed)

When the user taps the mic button, the keyboard layout **transitions out** and the entire extension view becomes a full-bleed `KeyVoxRecordingView` that fills the keyboard height.

```
┌──────────────────────────────────────────────────────────┐
│                                              [ ⏹ stop ]  │
│                                                           │
│                                                           │
│            █    ██   ███   ██    █                        │
│      (5-bar indigo waveform, full width, centered)        │
│                                                           │
│                   "Listening..."                          │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

**When transcribing:**
```
┌──────────────────────────────────────────────────────────┐
│                                                           │
│            ─    ──   ───   ──    ─                        │
│          (bars in traveling ripple / processing wave)     │
│                   "Transcribing..."                       │
└──────────────────────────────────────────────────────────┘
```

**Elements:**
- **Stop button — top right** (same corner as the mic was): Tapping sends the stop command. Muscle memory stays at the same corner.
- **5-bar waveform centered full-width**: The `BarView` component from `RecordingOverlay.swift`, used verbatim. Same indigo gradient bars, same yellow glow shadow, same spring animation, same ripple/quiet/active signal logic. Scaled up since the entire keyboard canvas is available.
- **Status label**: "Listening…" during recording, "Transcribing…" while the model runs.
- **Tapping anywhere on the waveform** also triggers stop — mirrors the macOS circular overlay tap behavior.

---

### 9.4 `KeyVoxRecordingView` — Port of `RecordingOverlay.swift`

This SwiftUI view lives in `SharedCore/Views/` — it uses no AppKit, no NSPanel, no platform-specific code. It is a **size-adapted port** of `RecordingOverlay.swift` without the circular clip. The macOS `RecordingOverlay` imports `BarView` from SharedCore; `KeyVoxRecordingView` does the same.

```swift
// SharedCore/Views/KeyVoxRecordingView.swift
import SwiftUI

/// iOS port of RecordingOverlay — fills any frame, removes circular constraint.
/// BarView is imported from SharedCore/Views/BarView.swift (shared with macOS).
struct KeyVoxRecordingView: View {
    private static let phaseStep: Double = 0.1
    private static let quietPhaseStep: Double = 0.06

    var audioLevel: Double
    var isTranscribing: Bool
    var signalState: LiveInputSignalState
    var statusLabel: String?
    var onStop: (() -> Void)?

    @State private var ripplePhase: Double = 0
    @State private var quietPhase: Double = 0
    @State private var rippleTimer: Timer?
    @State private var scale: CGFloat = 0.12
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)

            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button(action: { onStop?() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 10)
                }

                Spacer()

                HStack(spacing: 10) {
                    ForEach(0..<5) { index in
                        BarView(
                            value: audioLevel,
                            index: index,
                            isTranscribing: isTranscribing,
                            signalState: signalState,
                            ripplePhase: ripplePhase,
                            quietPhase: quietPhase,
                            oversized: false   // Use the normal-size bar constants; scaling applied below
                        )
                        .scaleEffect(CGSize(width: 2.5, height: 2.5))
                    }
                }

                if let label = statusLabel {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                }

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onStop?() }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear { popIn() }
        .onDisappear { stopRipple() }
    }

    private func popIn() {
        opacity = 1.0
        withAnimation(.easeOut(duration: 0.1)) { scale = 0.92 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { scale = 1.08 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { scale = 1.0 }
        }
        startRipple()
    }

    private func startRipple() {
        guard rippleTimer == nil else { return }
        rippleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            ripplePhase += Self.phaseStep
            quietPhase += Self.quietPhaseStep
            if ripplePhase >= .pi * 2 { ripplePhase -= .pi * 2 }
            if quietPhase >= .pi * 2 { quietPhase -= .pi * 2 }
        }
    }

    private func stopRipple() {
        rippleTimer?.invalidate()
        rippleTimer = nil
    }
}
```

> [!CAUTION]
> **Proprietary Asset — Licensing Critical**: `RecordingOverlay.swift` and `BarView` are explicitly listed as **proprietary assets** in `LICENSE.md` under "Excluded Proprietary Assets and Branding" (item 3: *"The proprietary 'Audio-Reactive Wave' animation, which is a derivative of the KeyVox brand identity"*). They are **NOT** MIT-licensed. They cannot be copied, forked, or redistributed by third parties.
>
> **This is NOT a blocker for the iOS app.** Dominic Esposito owns both the macOS KeyVox app and the iOS app. As the rights holder, he can use `BarView` and `KeyVoxRecordingView` across both products freely. This is identical to how a company uses its own brand assets across multiple products.
>
> **What the executing agent MUST do:**
> 1. When moving `BarView` into `SharedCore/Views/BarView.swift`, the file **must retain the proprietary notice header** — do NOT add an MIT file header to it.
> 2. `SharedCore/Views/` should contain a `PROPRIETARY_NOTICE.md` (or inline comment) making clear that the Views subfolder is NOT covered by the MIT license that governs the rest of SharedCore.
> 3. `LICENSE.md` in the root repo must be updated to add `SharedCore/Views/BarView.swift` and `SharedCore/Views/KeyVoxRecordingView.swift` to the Excluded Proprietary Assets list alongside `Views/RecordingOverlay.swift`.
> 4. Do not treat BarView as generic open-source utility code. It is the KeyVox brand identity.

---

### 9.5 State Machine in `KeyboardViewController`

```swift
enum KeyboardDisplayState {
    case keyboard      // Numbers/symbols layout
    case recording     // Full-bleed waveform, live signal
    case transcribing  // Full-bleed waveform, processing ripple
}
```

**Transitions:**

```
[keyboard] ─── mic tapped ─────────────────▶ sendStartCommand() → [recording]
[recording] ── stop tapped / tap anywhere ─▶ sendStopCommand()  → [transcribing]
[transcribing] ─ transcription received ───▶ insertText() → [keyboard]
[transcribing] ─ noSpeech received ────────▶ [keyboard]
```

Use a single `UIHostingController` with a SwiftUI root view that conditionally renders based on `@Published var displayState: KeyboardDisplayState`. SwiftUI's `if/else` with `.transition(.opacity)` or `.transition(.scale.combined(with: .opacity))` handles the animated swap cleanly.

---

### 9.6 The ABC Button — `advanceToNextInputMode()`

Zero custom logic needed. Apple provides this for all keyboard extensions:

```swift
@objc private func abcButtonTapped() {
    advanceToNextInputMode()
}
```

This cycles through the user's enabled keyboards — straight back to the system ABC keyboard. No URL scheme, no IPC, no implementation required.

---

### 9.7 Extension Height

The keyboard extension view height stays **constant across both states** — this is critical to avoid layout reflow in the host app:

```swift
override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 260)
}
```

`260pt` is the standard iPhone keyboard height. The `KeyVoxRecordingView` fills exactly this space. No jarring resize, no scroll offset jump in the host text view.

---

## Phase 10 — Testing

### 10.1 Reuse Existing Tests

This work is now split across two suites:

1. `Packages/KeyVoxCore/Tests/KeyVoxCoreTests/` for the extracted reusable logic
2. `KeyVoxTests/` for macOS-only integration and platform behavior

The reusable tests were moved into the package rather than copied into a future iOS target:

| Test Directory | File Count | Covers |
|---|---|---|
| `KeyVoxTests/Language/` | 5 dirs | Dictionary matcher, phonetic encoder, scorer, email resolution |
| `KeyVoxTests/Lists/` | 3 files | List formatting, pattern detection, rendering |
| `KeyVoxTests/Services/Whisper/` | Multiple | Chunker, suspicious result detection, retry logic |
| `KeyVoxTests/Core/` | 13 files | Audio classification, silence policy, pipeline, echo guard |

Phase 1 verification result:

- `swift test --package-path /Users/domesposito/Projects/KeyVox/Packages/KeyVoxCore` → `276 tests, 0 failures`
- `xcodebuild -project /Users/domesposito/Projects/KeyVox/KeyVox.xcodeproj -scheme "KeyVox DEBUG" -configuration Debug -destination 'platform=macOS' -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -resultBundlePath /tmp/keyvox-phase1-rerun3.xcresult test` → `136 tests, 0 failures`

The lower Xcode test count is expected because the reusable tests now run under SwiftPM instead of the app test target.

### 10.2 New Tests Required

| Test | Purpose |
|---|---|
| `KeyVoxCore DictationPipelineTests` | Verify the extracted pipeline runs correctly with stub providers and closure-based sinks |
| `KeyVoxCore DictionaryHintPromptGateTests` | Verify the extracted prompt-gate logic independently of `TranscriptionManager` |
| `iOSAudioRecorderTests` | Verify `AVAudioEngine` tap produces mono Float32 @ 16kHz |
| `AppExtensionIPCTests` | Verify shared `UserDefaults` read/write cycle |
| `ModelPathResolutionTests` | Verify App Group container path resolution |
| `KeyboardExtensionInsertionTests` | UITextDocumentProxy insertion verification |

### 10.3 Manual QA Checklist

- [ ] Dictate "check out example dot com" → verify `example.com` appears
- [ ] Dictate "email john at gmail dot com" → verify `john@gmail.com` appears
- [ ] Dictate "meeting at two thirty pm" → verify `2:30 PM` appears
- [ ] Dictate "first buy milk second get eggs" → verify numbered list
- [ ] Dictate with custom dictionary word → verify phonetic matching
- [ ] Hold silence for 5 seconds → verify no-speech detection
- [ ] Test in Notes, Messages, Safari, Slack → verify insertion works
- [ ] Kill containing app → verify extension handles gracefully
- [ ] Model not downloaded → verify onboarding prompt

---

## Phase 11 — Polish & Ship

### 11.1 App Store Considerations

- **Privacy Nutrition Labels**: KeyVox collects NO data. Audio is processed on-device. No analytics, no crash reporting, no network calls except model download from Hugging Face.
- **Review Guidelines**: Custom keyboards that request Full Access require privacy justification. State: "Full Access is used exclusively for inter-process communication between the keyboard extension and the containing app via App Groups. No data is transmitted externally."
- **Size**: The GGML base model is ~142 MB. Consider whether to bundle it in the app or download on first launch (download is better for App Store size limits).

### 11.2 Performance Targets

| Metric | Target | Notes |
|---|---|---|
| Cold model load | < 3s | First warmup after app launch |
| Warm inference (5s audio) | < 2s | Whisper base on A15+ |
| Normalization pipeline | < 5ms | Already measured on macOS |
| Extension → App → Extension roundtrip | < 100ms | Darwin notification latency |
| Total stop-to-text | < 3s | Comparable to macOS |

---

## Platform Constraints & Gotchas

| Constraint | Impact | Mitigation |
|---|---|---|
| **Extension memory limit (~50 MB)** | Cannot load Whisper model in extension | All inference happens in containing app |
| **Extension background execution** | Extension is killed when keyboard dismissed | Keep extension stateless; app maintains session |
| **App must be running** | AVAudioEngine requires app to be active | Display instruction to user when app not running |
| **No `Process()` on iOS** | Cannot shell out to unzip | Use ZIPFoundation SPM package |
| **No `CoreAudio` device enumeration** | Cannot read input volume scalar | Use `AVAudioSession.inputGain` or skip adaptive thresholds (use defaults) |
| **No `AXUIElement`** | Cannot inspect target text field | Don't need to — `UITextDocumentProxy` handles everything |
| **No global hotkey** | Cannot intercept system-wide key events | Use keyboard extension button instead |
| **`NSSound` not available** | Cannot play start/stop sounds | Use `AudioServicesPlaySystemSound()` or `AVAudioPlayer` |
| **App suspension** | iOS may suspend the app while recording | Use `AVAudioSession` background mode and `beginBackgroundTask()` |

---

## File-by-File Portability Reference

### ✅ Extracted Into `Packages/KeyVoxCore`

```
Core/Language/Dictionary/DictionaryMatcher.swift
Core/Language/Dictionary/DictionaryMatcher+Models.swift
Core/Language/Dictionary/DictionaryMatcher+OverlapResolver.swift
Core/Language/Dictionary/DictionaryMatcher+Tokenizer.swift
Core/Language/Dictionary/DictionaryEntry.swift
Core/Language/Dictionary/DictionaryTextNormalization.swift
Core/Language/Dictionary/DictionaryStore.swift
Core/Language/Dictionary/Email/DictionaryEmailEntry.swift
Core/Language/Dictionary/Email/DictionaryMatcher+EmailResolution.swift
Core/Language/Dictionary/Email/DictionaryMatcher+EmailNormalization.swift
Core/Language/Dictionary/Email/DictionaryMatcher+EmailParsing.swift
Core/Language/Dictionary/Email/DictionaryMatcher+EmailDomainResolution.swift
Core/Language/PhoneticEncoder.swift
Core/Language/PronunciationLexicon.swift
Core/Language/ReplacementScorer.swift
Core/Normalization/EmailAddressNormalizer.swift
Core/Normalization/WebsiteNormalizer.swift
Core/Normalization/TimeExpressionNormalizer.swift
Core/Normalization/MathExpressionNormalizer.swift
Core/Normalization/ColonNormalizer.swift
Core/Normalization/SentenceCapitalizationNormalizer.swift
Core/Normalization/TerminalPunctuationNormalizer.swift
Core/Normalization/AllCapsOverrideNormalizer.swift
Core/Normalization/WhitespaceNormalizer.swift
Core/Normalization/LaughterNormalizer.swift
Core/Normalization/CharacterSpamNormalizer.swift
Core/Lists/ListFormattingEngine.swift
Core/Lists/ListFormattingTypes.swift
Core/Lists/ListPatternDetector.swift
Core/Lists/ListPatternMarker.swift
Core/Lists/ListPatternMarkerParser.swift
Core/Lists/ListPatternRunSelector.swift
Core/Lists/ListPatternTrailingSplitter.swift
Core/Lists/ListRenderer.swift
Core/Transcription/TranscriptionPostProcessor.swift
Core/Transcription/DictationPipeline.swift
Core/Transcription/DictationPromptEchoGuard.swift
Core/Services/Whisper/WhisperService.swift
Core/Services/Whisper/WhisperService+TranscriptionCore.swift
Core/Services/Whisper/WhisperService+ModelLifecycle.swift  (use injected modelPathResolver)
Core/Services/Whisper/WhisperAudioParagraphChunker.swift
Core/Audio/AudioSignalMetrics.swift
Core/Audio/AudioSilencePolicy.swift
Core/Audio/AudioCaptureClassification.swift
Packages/KeyVoxWhisper/  (entire package as SPM dependency)
Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/AudioPostProcessing.swift
Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictionaryHintPromptGate.swift
```

### ⚠️ Extract Logic (already done in Phase 1)

```
Core/Audio/AudioRecorder+PostProcessing.swift
  → Extract removeInternalGaps() and normalizeForTranscription() into standalone functions
```

### ❌ Do Not Port (18 files)

```
Core/Services/Paste/PasteService.swift
Core/Services/Paste/Accessibility/PasteAXInspector.swift
Core/Services/Paste/Accessibility/PasteAXLiveSession.swift
Core/Services/Paste/Accessibility/PasteAccessibilityInjector.swift
Core/Services/Paste/Clipboard/PasteClipboardSnapshot.swift
Core/Services/Paste/Clipboard/PasteFailureRecoveryCoordinator.swift
Core/Services/Paste/Heuristics/PasteSpacingHeuristics.swift
Core/Services/Paste/MenuFallback/PasteMenuFallbackCoordinator.swift
Core/Services/Paste/MenuFallback/PasteMenuFallbackExecutor.swift
Core/Services/Paste/MenuFallback/PasteMenuScanner.swift
Core/Services/Paste/Pipeline/PasteModels.swift
Core/Services/Paste/Pipeline/PastePolicies.swift
Core/Overlay/OverlayPanel.swift
Core/Overlay/OverlayMotionController.swift
Core/Overlay/OverlayScreenPersistence.swift
Core/Overlay/OverlayManager.swift
Core/KeyboardMonitor.swift
Core/AudioDeviceManager.swift
```

---

## Summary

| Metric | Value |
|---|---|
| **Reusable files** | 43 source files + 1 SPM package |
| **Reusable lines** | ~12,000+ tested production lines |
| **New code needed** | ~1,880 lines |
| **Reuse ratio** | ~85% |
| **Estimated effort** | 2–3 weeks for an experienced iOS developer |
| **Risk level** | Low — core pipeline is proven, only platform shell is new |

The hard part — phonetic engine, dictionary matching, normalization pipeline, Whisper integration, chunking, retry, no-speech detection — is done. Ship the shell.
