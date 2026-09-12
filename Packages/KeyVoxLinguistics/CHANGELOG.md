# Changelog

All notable changes to `KeyVoxLinguistics` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for shared linguistic-analysis behavior within the KeyVox monorepo.

---

## [1.0.0] - 2026-09-12

Initial shared linguistic-analysis package for native Apple and portable KeyVox clients.

### Includes

- Defined shared token, lexical-role, feature, grouping, and analysis types behind a platform-neutral analyzer interface.
- Added the Apple analyzer for native Natural Language framework evidence and a Unicode analyzer for portable word boundaries.
- Added portable English role inference backed by host-provided perceptron and WordNet resources.
- Added health evaluation that distinguishes valid empty analysis from missing lexical evidence within the caller’s requested range.
- Added health-routed analyzer construction that retains healthy platform results and uses a configured portable fallback only for a normalized matching language.
- Documented the licenses and notices required when distributing the supported linguistic resources.

### Notes

- `1.0.0` establishes the shared source of truth for linguistic capabilities and fallback routing.
