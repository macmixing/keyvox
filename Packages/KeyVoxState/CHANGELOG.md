# Changelog

All notable changes to `KeyVoxState` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for shared observable-state behavior within the KeyVox monorepo.

---

## [1.0.0] - 2026-09-12

Initial cross-platform state publication package for KeyVox state owners.

### Includes

- Added a shared state-owner protocol that maps to native observation on Apple platforms without requiring Combine on portable platforms.
- Added a concurrency-safe state channel with current-value access and asynchronous update streams.
- Added read-only state update handles so consumers can observe changes without taking ownership of mutation.
- Added platform-neutral verification and probe targets for clients outside Apple application targets.

### Notes

- `1.0.0` establishes the shared state publication boundary used by Core and Promotions.
