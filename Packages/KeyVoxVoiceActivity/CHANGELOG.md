# Changelog

All notable changes to `KeyVoxVoiceActivity` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for shared voice-activity runtime tracking within the KeyVox monorepo.

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
