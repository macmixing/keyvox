# Changelog

All notable changes to `KeyVoxPromotions` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared promotion behavior within the KeyVox monorepo.

---

## [1.1.0] - 2026-09-12

Shared campaign delivery now supports Android alongside the existing Apple clients.

### Includes

- Added Android as a first-class promotion platform for manifest eligibility and campaign selection.
- Added Android campaign definitions to the bundled promotion manifest.
- Added configurable resource-bundle resolution so each client can provide the package resources from its own runtime layout.
- Moved promotion state publishing behind the shared cross-platform state abstraction while preserving native observation on Apple platforms.

### Notes

- `1.1.0` extends the existing campaign source of truth to Android without changing iOS or macOS campaign behavior.

---

## [1.0.0] - 2026-08-26

Initial shared campaign delivery and selection system for KeyVox on iOS and macOS.

### Includes

- JSON campaign models with platform, app-version, date, icon, action, and sharing metadata.
- Validated remote-manifest loading with a last-known-good local cache.
- Stable static or interval-based campaign selection in manifest order.
- Debug-only bundled-manifest and campaign-ID preview support without changing production selection state.
- Initial Compact Keys, KeyVox for Mac, and KeyVox Keyboard for iPhone campaigns.
- Deterministic regression coverage for manifest validation, eligibility, selection, caching, and preview behavior.

### Notes

- `1.0.0` establishes the UI-independent campaign source of truth consumed by the platform-native KeyVox app views.
