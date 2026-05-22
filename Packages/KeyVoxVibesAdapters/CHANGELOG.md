# Changelog

All notable changes to `KeyVoxVibesAdapters` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal Vibes adapter resource tracking within the KeyVox monorepo.

---

## [1.0.3] - 2026-05-22

Bundled Vibes adapter refresh for rating-formatting unlearn continuations and AP-backed number repair.

### Includes

- Updated the bundled Polished adapter resource to `polished-alpha-026-lora.gguf`.
- Updated the bundled Casual adapter resource to `casual-alpha-9-lora.gguf`.
- Updated the adapter catalog so Polished and Casual resolve to the promoted bundled adapter resources.
- Promoted continuation materials that remove explicit rating-formatting examples from the current adapters while preserving money, address, time, and spoken-year coverage.

### Notes

- `1.0.3` bumps the tracked adapter package version for the refreshed bundled Vibes adapter resources used with deterministic AP-style number repair.

---

## [1.0.2] - 2026-05-20

Bundled Vibes adapter promotion for Polished and Casual money boundary recognition.

### Includes

- Updated the bundled Polished adapter resource to `polished-alpha-025-lora.gguf`.
- Updated the bundled Casual adapter resource to `casual-alpha-5-lora.gguf`.
- Updated the adapter catalog so Polished and Casual resolve to the promoted bundled adapter resources.
- Documented the promoted adapter resources in package and app-facing notices.

### Notes

- `1.0.2` bumps the tracked adapter package version for the promoted Polished and Casual money-boundary resources.

---

## [1.0.1] - 2026-05-17

Bundled Vibes adapter refresh for spoken year recognition, Polished age-compound precision, and Polished and Casual money boundary handling.

### Includes

- Updated the bundled Polished adapter resource to ship `polished-alpha-025-lora.gguf` instead of the previously prepared `polished-alpha-024-lora.gguf`.
- Continued Polished from alpha-023 to preserve spoken year recognition while fixing the observed teen-number age compound regression, including `eighteen year old` becoming `18-year-old` instead of `8-year-old`.
- Continued Polished from alpha-024 to keep adjacent money and quantity phrases separated, including dollar amounts followed by day counts, price ratios, star rating counts, and math expressions with money operands.
- Added Polished guard coverage for adjacent teen age compounds, `8-year-old` versus `18-year-old`, `$180` versus `$1,800`, and the full 2010s spoken-year sweep.
- Added Polished live guard coverage for reported money/day, price-ratio, star-rating, and money-math boundary regressions.
- Updated the bundled Casual adapter resource to `casual-alpha-5-lora.gguf`.
- Continued Casual from alpha-4 to keep adjacent money and quantity phrases separated, including dollar amounts followed by day counts, price ratios, star rating counts, and math expressions with money operands.
- Updated the adapter catalog so Polished and Casual resolve to the refreshed bundled adapter resources.
- Documented the refreshed adapter resources in package and app-facing notices.

### Notes

- This entry extends the unshipped `1.0.1` adapter package notes so the shipped Polished resource is alpha-025 rather than alpha-024.

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
