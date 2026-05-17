# Changelog

All notable changes to `KeyVoxVibesAdapters` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal Vibes adapter resource tracking within the KeyVox monorepo.

---

## [1.0.1] - 2026-05-17

Bundled Vibes adapter refresh for spoken year recognition and Polished age-compound precision.

### Includes

- Updated the bundled Polished adapter resource to ship `polished-alpha-024-lora.gguf` instead of the previously prepared `polished-alpha-023-lora.gguf`.
- Continued Polished from alpha-023 to preserve spoken year recognition while fixing the observed teen-number age compound regression, including `eighteen year old` becoming `18-year-old` instead of `8-year-old`.
- Added Polished guard coverage for adjacent teen age compounds, `8-year-old` versus `18-year-old`, `$180` versus `$1,800`, and the full 2010s spoken-year sweep.
- Updated the bundled Casual adapter resource to `casual-alpha-4-lora.gguf`.
- Updated the adapter catalog so Polished and Casual resolve to the refreshed bundled adapter resources.
- Documented the refreshed adapter resources in package and app-facing notices.

### Notes

- This entry extends the unshipped `1.0.1` adapter package notes so the shipped Polished resource is alpha-024 rather than alpha-023.

---

## [1.0.0] - 2026-05-13

Baseline tracked release of the KeyVox Vibes adapters package.

This entry establishes the first explicit package version for `KeyVoxVibesAdapters` and marks the current bundled adapter catalog as the starting point for future package-level release tracking inside the monorepo.

### Includes

- A package-owned adapter catalog through `KeyVoxVibesAdapterCatalog`.
- Public adapter kind cases for polished and casual Vibes adapters.
- Adapter descriptors with kind, adapter ID, bundled filename, compatible base model ID, resource name, and resource extension.
- Bundled GGUF LoRA adapter resources for `polished-alpha-023-lora.gguf` and `casual-alpha-4-lora.gguf`.
- A shared compatible base model identifier of `qwen2-5-0-5b-instruct` for the cataloged adapters.
- Descriptor lookup by adapter kind and bundled resource URL resolution through `Bundle.module`.
- Package coverage that verifies each cataloged adapter resolves to its bundled resource URL and that all cataloged adapters declare the same compatible base model.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxVibesAdapters`; this changelog does not attempt to describe adapter training history or quality claims that are not represented in the package source.
- Future entries should capture meaningful adapter catalog, bundled resource, compatible base model, descriptor schema, and resource resolution changes.
