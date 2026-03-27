# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

## [1.0.0] Build 6 - TestFlight - 2026-03-26

Polishes the iOS keyboard release with newline-aware capitalization, a unified keyboard geometry system, steadier delete behavior in single-line fields, and more natural dictionary entry capitalization.

### Added

- Newline-aware capitalization handling for iOS keyboard insertions so sentence starts stay capitalized after pressing return, including when indentation follows.
- A dedicated `KeyboardLayoutGeometry` owner for live keyboard sizing rules across the key grid and bottom toolbar rows.
- Regression coverage for newline-start capitalization behavior and repeat-delete handling in single-line host fields.
- A custom microphone toolbar icon asset for the iOS keyboard.

### Changed

- Unified keyboard layout geometry so measured key widths drive third-row, bottom-row, and landscape special-key sizing consistently.
- Refined special-key presentation by hiding the visible space-bar label, replacing the return text label with the return symbol, and tuning special-key typography.
- Refreshed the keyboard toolbar microphone presentation with updated icon treatment, glow styling, and speaking-meter gain.
- Changed dictionary entry autocapitalization from word-based behavior to sentence-based behavior for more natural phrase entry.

### Fixed

- Stabilized repeat delete in single-line host fields by tolerating transient empty-context states and avoiding repeated fallback haptics during phantom-empty proxy reads.
- Preserved leading capitalization at new line starts in the iOS keyboard capitalization heuristics.

## [1.0.0] Build 5 - TestFlight - 2026-03-21

Refines the iOS keyboard release with active-call safety messaging, consistent symbol popup alignment, and a lower-memory full access instructions flow.

### Added

- Active phone call detection in the iOS keyboard using a CallKit-backed observer.
- A toolbar warning state that blocks dictation while a phone call is active and preserves warning precedence alongside full access and microphone permission states.
- Keyboard toolbar test coverage for active-call warning behavior and precedence.
- An app version and build footer in the iOS Settings tab.

### Changed

- Shared symbol baseline-offset styling between keyboard keys and popup labels so symbol pages render consistently.
- Updated iOS code map and engineering notes to document the keyboard warning toolbar behavior.

### Fixed

- Full access instructions are now created only when the instructions screen is presented instead of being built hidden during keyboard launch.
- Removed hidden launch-time full-screen instructions view work from the keyboard path to reduce extension memory pressure on affected devices.


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
