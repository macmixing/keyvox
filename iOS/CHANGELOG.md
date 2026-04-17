# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

## [1.0.3] - 2026-04-17

Fixes onboarding progression when users complete keyboard setup out of the expected step order while working through app settings.

### Fixed

- Fixed an onboarding state where users could complete microphone access, enable the KeyVox keyboard, and allow Full Access during the same Settings trip, then return to a fully checked setup screen with no way to continue.
- Fixed onboarding so users who enable the KeyVox keyboard before the dictation model finishes downloading are automatically advanced into the keyboard tour once the model is ready.

## [1.0.2] - 2026-04-09

Adds release-branch update enforcement so unsupported installs can be blocked behind a required App Store upgrade, while preserving spoken version phrases during dictation cleanup.

### Added

- Added App Store update enforcement backed by a minimum-supported-version policy manifest, including shared forced-update state that can gate keyboard usage when an upgrade is required.

### Fixed

- Fixed dictation list detection so spoken semantic-version phrases such as `one point zero point two` stay as prose instead of being reformatted as numbered-list content.

## [1.0.1] Build 3 - App Store - 2026-04-09

Polishes the iOS release branch with a more stable first-open keyboard layout, fully visible symbol popups on compact devices, and more responsive live input meter updates during recording startup.

### Changed

- Updated keyboard symbol popup sizing to account for rendered label content and shared popup padding instead of relying on key width alone.
- Moved shared live meter publication to the audio tap path before the recorder's `MainActor` UI update hop.

### Fixed

- Fixed symbol popup placement so edge keys such as `@` stay fully visible instead of clipping against the keyboard bounds on compact devices.
- Fixed the initial iOS keyboard presentation so first-open layout state applies cleanly and the cancel control visibility no longer destabilizes the release keyboard layout.
- Fixed stale live meter samples during cold-start recording handoff so the keyboard indicator receives live input updates sooner.

## [1.0.0] Build 11 - TestFlight - 2026-04-01

Improves iOS keyboard launch stability by removing a crash-prone microphone logo rendering path that could prevent the keyboard from appearing for some users.

### Changed

- Updated the branded keyboard logo bar to rasterize its microphone asset before display instead of relying on live vector template styling during keyboard layout.
- Switched the keyboard logo bar appearance refresh path to the iOS 17 trait change registration API.

### Fixed

- Fixed a keyboard extension crash in `KeyboardLogoBarView` triggered while rendering the toolbar microphone image during layout.
- Fixed a failure mode where affected users could not bring up the KeyVox keyboard because the extension crashed before presentation completed.

## [1.0.0] Build 10 - TestFlight - 2026-04-01

Refines the iOS onboarding and settings experience by keeping the keyboard tour input anchored to the screen width, surfacing clearer model download sizes, and splitting model-management UI into a dedicated settings extension.

### Changed

- Extracted the release-facing `Active Model` settings section into `SettingsTabView+Models.swift` to keep `SettingsTabView` lighter and easier to maintain.
- Added approximate uninstalled model size labels in Settings for Whisper Base and Parakeet TDT v3.
- Updated the iOS code map and engineering notes to reflect the extracted settings model-management surface.

### Fixed

- Fixed the onboarding keyboard tour input bar so long dictated text no longer expands the field beyond the screen width.
- Fixed `AutoFocusTextField` sizing behavior in SwiftUI layouts by removing unwanted horizontal intrinsic-width pressure.

## [1.0.0] Build 9 - TestFlight - 2026-03-31

Stabilizes the iOS keyboard presentation lifecycle so repeated globe-key swaps no longer accumulate retained keyboard trees, while preserving the active keyboard when the host app backgrounds and returns.

### Changed

- Refactored the iOS keyboard controller so presentation-tree creation, teardown, and host lifecycle handling are owned by dedicated presentation lifecycle helpers instead of being spread across the main controller file.
- Updated the keyboard lifecycle to create its presentation tree only on the real appearance path instead of during controller preload.
- Added controller-scoped debug lifecycle counters and regression seams for validating keyboard presentation creation and teardown behavior.
- Updated the iOS engineering notes and codemap to document the keyboard’s presentation-scoped lifecycle rules and host background/foreground behavior.

### Fixed

- Fixed a keyboard extension memory leak where repeated globe-key hide/show cycles could retain full keyboard presentation trees and steadily increase extension memory usage.
- Fixed retained keyboard key-grid, blur-view, and controller accumulation during repeated presentation swaps in the iOS keyboard extension.
- Fixed a regression where backgrounding the host app with the keyboard visible could leave the keyboard blank when returning to the foreground until the user cycled input modes again.

## [1.0.0] Build 8 - TestFlight - 2026-03-30

Improves iPhone dictation accuracy and reliability with better spoken-number, date, list, colon, math, and Parakeet runtime handling across the shared package layer used by the beta.

### Changed

- Improved spoken large-number normalization so thousand-scale quantities are cleaned up earlier in post-processing and read more naturally in sentence context.
- Improved month-led date normalization and protected spoken years from being regrouped into large-number output.
- Refined colon association handling for title-and-subtitle style dictation phrases such as labels, announcements, and headings.
- Tightened list detection so ordinary prose is less likely to be reformatted as a numbered list, while genuine dictated lists continue to format more reliably.
- Improved list trailing-text splitting so reminder-style sentences after a list item break out more naturally instead of being folded into the last item.
- Improved Parakeet runtime tensor handling and decoder projection normalization for steadier Core ML transcription behavior in the shared runtime layer.
- Hardened half-precision Parakeet tensor storage handling in the shared runtime package.

### Fixed

- Fixed false list formatting for spoken prose patterns that contained incidental number words but were not intended to be lists.
- Fixed cases where spoken time phrases such as `five PM` could interfere with list detection.
- Fixed cases where short final list items could fail to split cleanly before trailing commentary or reminder text.
- Fixed a regression where conjunctions such as `and` could be dropped before normalized thousand-scale quantities.
- Fixed several spoken math-equation normalization regressions involving compound numbers and exponent phrasing.

## [1.0.0] Build 7 - TestFlight - 2026-03-30

Adds model-managed Parakeet support to the iOS beta, including active model selection, per-model downloads, and a refreshed settings flow for managing on-device dictation models.

### Added

- On-device Parakeet TDT v3 as an installable dictation model alongside Whisper Base.
- A new `Active Model` settings section for choosing the installed dictation model and managing model downloads directly in the app.
- Model-aware iOS download, repair, and removal flows for Whisper Base and Parakeet TDT v3.
- Local active-model persistence so iPhone dictation can reopen with the user’s selected installed model.
- iOS migration support for moving existing Whisper installs into the new rooted `Models/whisper` layout.

### Changed

- Refactored iOS model management around model IDs instead of a single Whisper-only install path.
- Updated iOS transcription routing to follow the selected active dictation model while keeping onboarding Whisper-first.
- Replaced the previous debug-only model controls in Settings with the new release-facing model management UI.
- Updated keyboard model availability checks to follow the rooted model layout and active installed model state.

### Fixed

- Restored compatibility for older iOS model install manifests during app upgrades.
- Tightened installed-model validation so incomplete Whisper installs are no longer treated as ready.
- Prevented model delete, repair, and download flows from racing active background download jobs or starting a second model install mid-download.
- Improved first-use Parakeet loading behavior so model selection stays responsive and heavy preload work no longer blocks the settings interaction.

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
