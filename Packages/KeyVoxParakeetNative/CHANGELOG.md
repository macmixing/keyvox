# Changelog

All notable changes to `KeyVoxParakeetNative` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for native Parakeet runtime integration within the KeyVox monorepo.

---

## [1.0.0] - 2026-09-12

Initial native Parakeet backend for portable KeyVox clients.

### Includes

- Added the C bridge used to connect the package to a platform-provided native Parakeet runtime.
- Implemented the shared `ParakeetRuntimeBackend` interface for native model loading, transcription, and result delivery.
- Added explicit session ownership so native runtime resources remain valid for the complete inference lifecycle and are released deterministically.
- Kept native-library linking conditional to the platforms that provide the external Parakeet runtime.

### Notes

- `1.0.0` establishes the optional native implementation of the runtime boundary owned by `KeyVoxParakeet`.
