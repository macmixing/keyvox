# Changelog

All notable changes to `KeyVoxEmoji` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared emoji data and behavior within the KeyVox monorepo.

---

## [1.0.0] - 2026-10-14

Initial shared emoji catalog, search, and suggestions for KeyVox keyboards, matched against the measured behavior of the iOS system emoji keyboard.

### Includes

- Emoji catalog in the system emoji keyboard's categories and order, with each emoji's name and skin-tone versions, including the twenty-five versions of emoji of two people.
- Frequently Used ranking as the system keyboard ranks it, starting from the emoji it shows before any are used.
- Emoji search by the words that describe each emoji, whole words first, ordered by Unicode's ranking of how often emoji are used.
- Emoji for the suggestion bar by word, from public Unicode data, with the emoji last used first.
- Two-person skin tones by each person's tone.
- Data writers in `Tools/KeyVoxEmojiData` for the catalog, search, and suggestion bar data, from Unicode's emoji list and CLDR annotations.

### Notes

- `1.0.0` establishes the UI-independent emoji source of truth consumed by the KeyVox keyboard hosts; search words and suggestions are English only.
