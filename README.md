<img src="Resources/logo.png" width="128" alt="KeyVox Logo">

# KeyVox

**KeyVox** is a local-first macOS dictation app. Hold a trigger key to record, release to transcribe with Whisper on-device, and insert text into the active app.

## Why KeyVox

KeyVox is built for low-latency, local transcription with deep macOS integration.

- Local Whisper inference (no cloud transcription path)
- Global modifier-key trigger workflow
- Accessibility-first text insertion with fallback behavior
- Menu bar-first UX with onboarding and settings

## Features

### Performance & AI
- **Local Whisper pipeline**: Uses `whisper.cpp` through the local `KeyVoxWhisper` package.
- **Model artifact**: Uses `ggml-base.bin` (plus CoreML encoder assets when available).
- **Automatic language detection**: Transcription runs with Whisper language `.auto`.
- **Model pre-warming**: Loads model early to reduce first-transcription delay.
- **Phonetic dictionary adherence**: Applies offline post-correction with bundled pronunciation data plus deterministic fallback encoding.

### Interaction
- **Configurable trigger binding**: Left/Right Option, Command, Control, or Fn.
- **Default trigger**: **Right Option (⌥)**.
- **Hands-free mode**: Hold **Shift** while releasing trigger to keep recording until trigger is pressed again.
- **Escape to cancel**: Press **Esc** during recording/transcribing to abort.

### Injection & Feedback
- **Accessibility-first insertion**: Attempts direct insertion in focused controls.
- **Fallback insertion**: Uses menu-bar Paste automation when direct insertion is unavailable.
- **Overlay feedback**: Floating recording/transcribing overlay with persisted position.
- **Audio cues**: Start/stop/cancel sounds (when enabled).

### App Operations
- **Onboarding flow**: Microphone, Accessibility, and model setup on first launch.
- **Update checks**: Manual and timer-based checks backed by GitHub Releases metadata via `Core/Services/AppUpdateService.swift`.
- **Warnings**: In-app warning overlays for missing model or permissions.

## Architecture

KeyVox is organized by responsibility:

- **`App/KeyVoxApp.swift`**: app entry point, menu bar scene, window lifecycle.
- **`Core/TranscriptionManager.swift`**: central recording/transcription state machine.
- **`Core/AudioRecorder.swift`**: 16kHz mono audio capture pipeline.
- **`Core/KeyboardMonitor.swift`**: global/local modifier and escape monitoring.
- **`Core/OverlayManager.swift`**: overlay lifecycle, drag persistence, display reconnection behavior.
- **`Core/Services/WhisperService.swift`**: model loading and local transcription.
- **`Core/AI/DictionaryMatcher.swift`**: offline n-gram custom-word matching with balanced scoring/guardrails.
- **`Core/Services/PasteService.swift`**: text insertion + fallback strategy.
- **`Core/Services/AppUpdateService.swift`**: GitHub Releases polling and update prompt triggers.
- **`Views/RecordingOverlay.swift` + `Views/Components/KeyVoxLogo.swift`**: branded visual identity layer.

### Contributor Notes
- Behavior and motion constants should stay close to their owning logic (file-local constants in managers/services/views).
- Branded visual tuning intentionally stays inside proprietary files like `Views/RecordingOverlay.swift` and `Views/Components/KeyVoxLogo.swift`.
- This split reduces fork confusion and keeps licensing boundaries clear without extra license bookkeeping.

## Update Service

`Core/Services/AppUpdateService.swift` is the single update source-of-truth integration.

- Fetches latest release metadata from the GitHub Releases "latest release" API endpoint configured in the service constants.
- Uses `tag_name` for version detection (normalizes `v1.2.3` -> `1.2.3` before comparison).
- Uses release `body` as the in-app update message/changelog text.
- Uses the first `.dmg` asset `browser_download_url` for the update button when available; otherwise falls back to release `html_url`.
- Keeps timer-based and manual checks, with silent failure behavior if the API is unavailable or payload decoding fails.

### KeyVoxWhisper Wrapper
`Packages/KeyVoxWhisper` is the project-local Swift wrapper around official `whisper.cpp` binaries. It isolates upstream compatibility churn behind a stable Swift interface used by app code.

## Pronunciation Resources

- Bundled pronunciation resources live in `Resources/Pronunciation/`.
- Runtime never downloads lexicon assets; matching is fully offline.
- Maintainers regenerate resources with `Tools/Pronunciation/build_lexicon.sh`.
- Source snapshot pins/checksums live in `Resources/Pronunciation/sources.lock.json`.
- Source/license attribution is tracked in `Resources/Pronunciation/LICENSES.md`.
- License/source policy check: `Tools/Pronunciation/verify_licenses.sh`.
- Quality gate check: `Tools/Pronunciation/benchmarks/run_quality_gates.sh`.
- Production targets:
  - `lexicon-v1.tsv` target: `240,000+` rows (allowed range: `240,000-450,000`).
  - `common-words-v1.txt` range: `10,000-15,000` rows.
  - coverage >= `95%`, correction hit-rate >= `90%` (`>=80%` if Phonetisaurus is unavailable and fallback G2P is used), false positives <= `1%`, median matcher latency <= `10ms`.

## Repository Structure

High-level layout:

- `App/`
- `Core/`
- `Views/`
- `Resources/`
- `Packages/`

For a detailed map of files and component responsibilities, see [`CODEMAP.md`](CODEMAP.md).

## Getting Started

### Prerequisites
- **macOS 15.6 or later**
- Apple Silicon recommended for best performance (Intel supported)

### Installation
1. Clone the repository: `git clone https://github.com/macmixing/keyvox.git`
2. Open `KeyVox.xcodeproj` in Xcode.
3. Build and run.
4. Complete onboarding to grant permissions and download model assets.

## Usage

1. **Configure**: Pick your trigger key in Settings (Default: **Right Option (⌥)**).
2. **Standard dictation**: Hold trigger -> speak -> release to transcribe and insert.
3. **Hands-free**: Hold trigger -> hold **Shift** -> release trigger -> press trigger again to stop.
4. **Cancel**: Press **Esc** to abort the active session.

## Troubleshooting

- **Model missing**: Open Settings and download/retry model setup.
- **No text insertion**: Verify Accessibility permission in System Settings.
- **No input audio**: Verify microphone permission and selected microphone in Settings.

## License

KeyVox uses a dual-license model:

- **Source code** is MIT-licensed.
- **Branding and specified visual assets** are excluded and remain proprietary.

See [`LICENSE.md`](LICENSE.md) for exact terms and the full list of excluded files/assets.
