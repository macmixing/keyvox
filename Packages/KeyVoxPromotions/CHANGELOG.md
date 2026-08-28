# Changelog

All notable changes to `KeyVoxPromotions` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared promotion behavior within the KeyVox monorepo.

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
