# Changelog

All notable changes to `KeyVoxVoiceActivity` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for shared voice-activity runtime tracking within the KeyVox monorepo.

---

## [1.1.2] - 2026-11-21

The Apple speech runtime now loads its Metal kernels prebuilt instead of compiling them in each new process.

### Includes

- Replaced the downloaded upstream b5130 Apple XCFramework with one built from the same release source by `Artifacts/build-whisper-xcframework.sh`, vendored in `Artifacts/whisper.xcframework`.
- Compiled the Metal kernels ahead of time into `default.metallib` and `ggml-tensor.metallib` inside each framework slice, so a new process with empty caches no longer compiles the kernel source on its first whisper.cpp use, including the CPU-only voice activity detector.
- Left out the bfloat16 kernels, as ggml's own precompiled build does; whisper.cpp at this release creates no bfloat16 tensors.
- Kept every other upstream build option and the `ios-arm64`, `ios-arm64_x86_64-simulator`, and `macos-arm64_x86_64` slices.

### Notes

- `1.1.2` is a patch-level runtime packaging change and does not change the public `KeyVoxVoiceActivity` API.

---

## [1.1.1] - 2026-09-18

The Apple speech runtime now uses the upstream Whisper.cpp v1.9.4 engine.

### Includes

- Updated the bundled Apple Whisper XCFramework from v1.7.6 to upstream build b5130 for v1.9.4.
- Included upstream timestamp parsing and runtime corrections while preserving the existing package API and supported Apple platforms.

### Notes

- `1.1.1` is a patch-level dependency update and does not change the public `KeyVoxVoiceActivity` API.

---

## [1.1.0] - 2026-09-12

The shared speech runtime now supports portable Whisper and voice-activity consumers.

### Includes

- Added a portable C bridge for the speech runtime used by non-Apple builds.
- Kept the existing bundled Whisper binary conditional to Apple platforms while exposing the same `KeyVoxSpeechRuntime` product to portable clients.
- Preserved package ownership of the Silero voice-activity resources and documented their bundled license alongside the portable runtime.

### Notes

- `1.1.0` extends the existing shared voice-activity runtime to portable platform builds without changing Apple VAD behavior.

---

## [1.0.0] - 2026-08-22

Provider-neutral Silero voice activity detection shared by KeyVox transcription models.

### Includes

- Added package-owned Silero model resources, voice activity analysis types, detector lifecycle, and shared detection configuration.
- Exposed the underlying speech runtime from the same package so Whisper and voice activity detection consume one binary target with one owner.
- Enabled both Whisper and Parakeet integrations to use the same VAD implementation and thresholds without either model owning shared speech detection.
- Added regression coverage confirming that silent audio produces no detected speech segments.

### Notes

- `1.0.0` establishes `KeyVoxVoiceActivity` as the single owner of shared voice activity detection for transcription models.
