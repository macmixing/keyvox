# Engineering Notes

This document contains implementation and maintainer-focused details that are intentionally kept out of the top-level README.

## Architecture Overview

KeyVox is organized by responsibility:

- `App/KeyVoxApp.swift`: App entry point, menu bar scene, and window lifecycle.
- `App/AppSettingsStore.swift`: Central persisted settings owner.
- `Core/TranscriptionManager.swift`: Recording/transcription state orchestration.
- `Core/Audio/AudioRecorder.swift`: Recorder state holder and public start/stop flow.
- `Core/Audio/AudioRecorder+Session.swift`: Capture session/device lifecycle.
- `Core/Audio/AudioRecorder+Streaming.swift`: Sample conversion/downsampling and live signal state.
- `Core/Audio/AudioRecorder+PostProcessing.swift`: Stop-time gap removal/normalization/classification.
- `Core/Audio/AudioRecorder+Thresholds.swift`: Input-volume-based threshold calibration.
- `Core/Audio/AudioCaptureClassification.swift`: Capture confidence/silence classification.
- `Core/Audio/AudioSilencePolicy.swift`: Shared silence-gate policy rules/constants.
- `Core/Audio/AudioSignalMetrics.swift`: Pure RMS/peak/window-ratio metrics.
- `Core/KeyboardMonitor.swift`: Global/local modifier and escape monitoring.
- `Core/AudioDeviceManager.swift`: Microphone discovery/selection and active device resolution.
- `Core/Overlay/OverlayManager.swift`: Overlay lifecycle orchestration and visibility state.
- `Core/Overlay/OverlayMotionController.swift`: Fling/reset motion sequencing.
- `Core/Overlay/OverlayScreenPersistence.swift`: Per-display origin persistence and clamping.
- `Core/Overlay/OverlayPanel.swift`: Drag sampling, double-click reset, release velocity capture.
- `Core/Overlay/OverlayFlingPhysics.swift`: Pure fling impact/reflection/duration calculations.
- `Core/Services/WhisperService.swift`: Local model loading and transcription.
- `Core/TranscriptionPostProcessor.swift`: Post-transcription pipeline orchestration.
- `Core/AI/Dictionary/*`: Dictionary storage and matcher internals.
- `Core/TextProcessing/ListFormattingEngine.swift`: Deterministic list detection/rendering.
- `Core/Services/Paste/PasteService.swift`: AX insertion, menu fallback, clipboard restore orchestration.
- `Core/Services/Paste/PasteMenuFallbackExecutor.swift`: Menu fallback execution and verification (AX-delta first, undo-state fallback when AX context is unavailable).
- `Core/Services/Paste/PasteFailureRecoveryCoordinator.swift`: Paste failure-recovery lifecycle.
- `Core/Services/AppUpdateService.swift`: GitHub Releases polling and update prompt logic.
- `Core/Services/UpdateFeedConfig.swift`: Tracked update feed config + local override resolution.
- `Core/Services/AppUpdateLogic.swift`: Pure update parsing/version/host validation helpers.

## Platform Compatibility

- Supported macOS range: Ventura (macOS 13.5) and newer.

For the full file-level map, see [`CODEMAP.md`](CODEMAP.md).

## Inference Model

- KeyVox uses Whisper's multilingual base model (`ggml-base`) for on-device transcription.

## Post-Processing Order

1. Whisper returns raw transcript text.
2. Dictionary correction applies custom-word adherence.
3. List formatting applies numeric list rendering when confident.
4. Final text is inserted via the paste service.

## Update Feed and Release Checks

`Core/Services/AppUpdateService.swift` is the update source-of-truth.

- Reads latest release metadata from GitHub Releases.
- Normalizes release tags such as `v1.2.3` to `1.2.3`.
- Uses release body as update prompt text.
- Prefers first `.dmg` asset URL, then falls back to release page URL.
- Enforces host allowlist checks before opening update links.

### Local Override Workflow

Maintainers can override the update feed locally without changing tracked defaults.

- Override file path:
  `~/Library/Application Support/KeyVox/update-feed.override.json`
- Helper script:
  `Tools/UpdateFeed/configure_local_feed.sh`
- Example template:
  `Tools/UpdateFeed/update-feed.override.example.json`

## Testing and Quality Gates

- App tests:
  `xcodebuild -project KeyVox.xcodeproj -scheme "KeyVox DEBUG" -configuration Debug -destination 'platform=macOS' -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -resultBundlePath /tmp/keyvox-tests.xcresult test`
- Package tests:
  `swift test --package-path Packages/KeyVoxWhisper`
- Core coverage gate:
  `Tools/Quality/check_core_coverage.sh /tmp/keyvox-tests.xcresult`

## Tooling

- Tooling guide:
  `Tools/README.md`
- Frontmost-app AX diagnostics:
  `Tools/ExploreAX.swift`
- Multi-app AX diagnostics:
  `Tools/ExploreAXApps.swift`
- Pronunciation pipeline/regeneration scripts:
  `Tools/Pronunciation/*`
- Update-feed local override helper:
  `Tools/UpdateFeed/configure_local_feed.sh`

### Integration-Only Exclusions

- Audio capture hardware/runtime integration paths
- Global keyboard hook behavior
- Overlay window rendering/interaction details

These remain integration/manual-test territory by design.

## Pronunciation Pipeline

- Runtime pronunciation resources:
  `Resources/Pronunciation/`
- Lexicon build script:
  `Tools/Pronunciation/build_lexicon.sh`
- Source/checksum lock:
  `Resources/Pronunciation/sources.lock.json`
- Source/license verification:
  `Tools/Pronunciation/verify_licenses.sh`
- Quality gates:
  `Tools/Pronunciation/benchmarks/run_quality_gates.sh`

## Contributor Notes

- Keep behavior/motion constants close to owning logic.
- Keep branded visual tuning inside branded view files.
- Prefer deterministic pure helpers for unit-test coverage.
- Preserve behavior when doing structural refactors unless explicitly changing product behavior.
