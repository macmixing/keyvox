# Changelog

All notable changes to `KeyVoxModels` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for shared model-artifact metadata within the KeyVox monorepo.

---

## [1.0.0] - 2026-09-12

Initial shared model-artifact definitions and integrity verification for KeyVox clients.

### Includes

- Added reusable SHA-256 file-integrity verification for downloaded and bundled model artifacts.
- Added the shared Whisper Base model artifact definition previously owned by Core.
- Added Whisper encoder artifact metadata for clients that install optional platform-specific acceleration assets.

### Notes

- `1.0.0` establishes one package-owned source of truth for model identity and integrity metadata.
