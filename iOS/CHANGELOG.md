# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

## [1.0.0] Build 4 - TestFlight - 2026-03-19

Initial TestFlight release of KeyVox for iPhone.

### Added

- Native iOS custom keyboard extension for system-wide access to KeyVox dictation from any text field.
- Local-first dictation system powered by on-device Whisper (`ggml-base`) for absolute privacy and zero cloud dependency.
- iCloud sync ecosystem for custom dictionaries, weekly word stats, and core style preferences across Mac and iPhone.
- Live Activities and Dynamic Island support to track active dictation sessions with quick-stop system controls.
- Deterministic post-processing pipeline for automatic paragraph detection, list formatting, and cursor-aware smart capitalization.
- Native keyboard interactions including spacebar-trackpad cursor scrubbing, customizable key haptics, caps-lock persistence, and repeating delete.
- Custom phonetic dictionary system to teach KeyVox specific industry jargon, names, and email addresses.
- Smooth, interactive onboarding tour to guide keyboard installation and test your first dictation.
- Syncable weekly word stats tracking across all KeyVox devices.

### Security

- No telemetry.
- No background speech collection.
- No network usage during transcription.

### Notes

KeyVox is designed as a deterministic, local-first dictation tool.  
All speech processing occurs on-device and no user speech data is transmitted or stored remotely.
