# Changelog

All notable changes to `KeyVoxVibesAdapters` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal Vibes adapter resource tracking within the KeyVox monorepo.

---

## [1.0.0] - 2026-05-13

Baseline tracked release of the KeyVox Vibes adapters package.

This entry establishes the first explicit package version for `KeyVoxVibesAdapters` and marks the current bundled adapter catalog as the starting point for future package-level release tracking inside the monorepo.

### Includes

- A package-owned adapter catalog through `KeyVoxVibesAdapterCatalog`.
- Public adapter kind cases for polished and casual Vibes adapters.
- Adapter descriptors with kind, adapter ID, bundled filename, compatible base model ID, resource name, and resource extension.
- Bundled GGUF LoRA adapter resources for `polished-alpha-021-lora.gguf` and `casual-alpha-3-lora.gguf`.
- A shared compatible base model identifier of `qwen2-5-0-5b-instruct` for the cataloged adapters.
- Descriptor lookup by adapter kind and bundled resource URL resolution through `Bundle.module`.
- Package coverage that verifies each cataloged adapter resolves to its bundled resource URL and that all cataloged adapters declare the same compatible base model.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxVibesAdapters`; this changelog does not attempt to describe adapter training history or quality claims that are not represented in the package source.
- Future entries should capture meaningful adapter catalog, bundled resource, compatible base model, descriptor schema, and resource resolution changes.
