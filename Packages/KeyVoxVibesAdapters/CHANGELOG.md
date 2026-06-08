# Changelog

All notable changes to `KeyVoxVibesAdapters` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal Vibes adapter resource tracking within the KeyVox monorepo.

---

## [1.0.4] - 2026-06-05

Bundled Polished adapter refresh for bad-rating meaning preservation.

### Includes

- Updated the bundled Polished adapter resource to `polished-alpha-027-lora.gguf`.
- Continued Polished from alpha-026 using the `alpha-027-continuation-meaning-preservation-ratings` dataset built from six bad Polished ratings.
- Added continuation coverage for negation, pronoun, uncertainty, `though`, duplicate-article, and invention-guard failures while replaying existing live-regression guards.
- Updated the adapter catalog so Polished resolves to the promoted bundled adapter resource.

### Notes

- `1.0.4` bumps the tracked adapter package version for the refreshed bundled Polished adapter resource.
- Casual remains on `casual-alpha-9-lora.gguf`.

---

## [1.0.3] - 2026-05-22

Bundled Vibes adapter refresh for rating-formatting unlearn continuations and AP-backed number repair.

### Includes

- Updated the bundled Polished adapter resource to `polished-alpha-026-lora.gguf`.
- Continued Polished from alpha-025 using the `alpha-026-continuation-rating-unlearn` dataset to remove the prior explicit rating-formatting examples from the adapter while retaining the money-boundary, age-compound, quantity, and spoken-year guard coverage promoted in alpha-025.
- Updated the bundled Casual adapter resource to `casual-alpha-9-lora.gguf`.
- Continued Casual from alpha-8 using the `casual-alpha-9-continuation-rating-unlearn` dataset, replaying the alpha-5 through alpha-8 money, time, address, spoken-year, and casual-voice continuations with the prior explicit rating-formatting examples removed.
- Updated the adapter catalog so Polished and Casual resolve to the promoted bundled adapter resources.
- Moved rating-formatting behavior out of the adapter training target and back into deterministic AP-style number repair.

### Notes

- `1.0.3` bumps the tracked adapter package version for the refreshed bundled Vibes adapter resources used with deterministic AP-style number repair.
- This release intentionally takes explicit rating-formatting examples away from both current adapters instead of adding more rating-specific adapter behavior.

---

## [1.0.2] - 2026-05-20

Bundled Vibes adapter promotion for Polished and Casual money boundary recognition.

### Includes

- Updated the bundled Polished adapter resource to `polished-alpha-025-lora.gguf`.
- Continued Polished from alpha-024 using the `alpha-025-continuation-money-boundaries` dataset to keep adjacent money and quantity phrases separated, including dollar amounts followed by day counts, price ratios, star rating counts, and math expressions with money operands.
- Updated the bundled Casual adapter resource to `casual-alpha-5-lora.gguf`.
- Continued Casual from alpha-4 using the `casual-alpha-5-continuation-money-boundaries` dataset to keep adjacent money and quantity phrases separated while preserving the Casual voice and spoken-year handling from alpha-4.
- Updated the adapter catalog so Polished and Casual resolve to the promoted bundled adapter resources.
- Documented the promoted adapter resources in package and app-facing notices.

### Notes

- `1.0.2` bumps the tracked adapter package version for the promoted Polished and Casual money-boundary resources.
- The package release promotes the alpha-025 and alpha-5 adapter lineages as the current shipped resources; later Casual alpha-6 through alpha-8 continuations were training-lineage work that did not become bundled resources until `1.0.3`.

---

## [1.0.1] - 2026-05-17

Bundled Vibes adapter refresh for spoken year recognition, Polished age-compound precision, and Polished and Casual money boundary handling.

### Includes

- Updated the bundled Polished adapter resource to ship `polished-alpha-025-lora.gguf` instead of the previously prepared `polished-alpha-024-lora.gguf`.
- Continued Polished from alpha-021 to alpha-023 with spoken 2010s year precision and quantity guards.
- Continued Polished from alpha-023 to preserve spoken year recognition while fixing the observed teen-number age compound regression, including `eighteen year old` becoming `18-year-old` instead of `8-year-old`.
- Continued Polished from alpha-024 to keep adjacent money and quantity phrases separated, including dollar amounts followed by day counts, price ratios, star rating counts, and math expressions with money operands.
- Added Polished guard coverage for adjacent teen age compounds, `8-year-old` versus `18-year-old`, `$180` versus `$1,800`, and the full 2010s spoken-year sweep.
- Added Polished live guard coverage for reported money/day, price-ratio, star-rating, and money-math boundary regressions.
- Updated the bundled Casual adapter resource to `casual-alpha-5-lora.gguf`.
- Continued Casual from alpha-3 to alpha-4 with spoken 2010s year precision and Casual voice guards.
- Continued Casual from alpha-4 to keep adjacent money and quantity phrases separated, including dollar amounts followed by day counts, price ratios, star rating counts, and math expressions with money operands.
- Updated the adapter catalog so Polished and Casual resolve to the refreshed bundled adapter resources.
- Documented the refreshed adapter resources in package and app-facing notices.

### Notes

- This entry extends the unshipped `1.0.1` adapter package notes so the shipped Polished resource is alpha-025 rather than alpha-024.
- Alpha-024 was an intermediate Polished continuation for teen-number age compounds; the shipped resource moved forward to alpha-025 before this package version was released.

---

## [1.0.0] - 2026-05-13

Baseline tracked release of the KeyVox Vibes adapters package.

This entry establishes the first explicit package version for `KeyVoxVibesAdapters` and marks the current bundled adapter catalog as the starting point for future package-level release tracking inside the monorepo.

### Includes

- A package-owned adapter catalog through `KeyVoxVibesAdapterCatalog`.
- Public adapter kind cases for polished and casual Vibes adapters.
- Adapter descriptors with kind, adapter ID, bundled filename, compatible base model ID, resource name, and resource extension.
- Bundled GGUF LoRA adapter resources for `polished-alpha-023-lora.gguf` and `casual-alpha-4-lora.gguf`.
- Polished alpha-023 represents the tracked Polished baseline after the alpha-017 `ain't` repair continuation, the rejected alpha-018 paragraph-preservation branch, alpha-019 numeric conversion reinforcement with paragraph guards, alpha-020 paragraph-meaning preservation, alpha-021 long numeric precision, and alpha-023 spoken-year precision.
- Casual alpha-4 represents the tracked Casual baseline after the alpha-1 base adapter, alpha-2 spoken-time continuation, alpha-3 time and money guard continuation, and alpha-4 spoken-year continuation with Casual voice guards.
- A shared compatible base model identifier of `qwen2-5-0-5b-instruct` for the cataloged adapters.
- Descriptor lookup by adapter kind and bundled resource URL resolution through `Bundle.module`.
- Package coverage that verifies each cataloged adapter resolves to its bundled resource URL and that all cataloged adapters declare the same compatible base model.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxVibesAdapters`; the alpha summaries above reflect the training manifests and lineage reports committed with the package source.
- Future entries should capture meaningful adapter catalog, bundled resource, compatible base model, descriptor schema, and resource resolution changes.
