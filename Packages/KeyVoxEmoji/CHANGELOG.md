# Changelog

All notable changes to `KeyVoxEmoji` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared emoji data and behavior within the KeyVox monorepo.

---

## [2.0.0] - 2026-11-28

Emoji search and suggestion-bar emoji in every typing language the keyboard offers: English, German, Spanish (Spain and Latin America), and French (France and Canada).

### Includes

- `EmojiSearch.bundled(language:)` and `EmojiPredictions.bundled(language:)` read a typing language's data by its identifier, such as `de` or `es-419`; a regional variant without its own data reads its language's, so French (Canada) uses French's.
- Search and bar data for German, Spanish, Spanish (Latin America), and French from CLDR's annotations in each language, with every form of a noun finding the noun's emoji, as the system emoji search finds them with each language's keyboard. English's data is unchanged.
- Words are compared case folded as well as without accents, so German "ß" finds "ss".
- No word a language's typing data leaves out finds or offers emoji.

### Notes

- `2.0.0` replaces `EmojiSearch.bundled()` and `EmojiPredictions.bundled()` with `bundled(language:)`; keyboard hosts pass the language they type in.

---

## [1.0.1] - 2026-10-30

Frequently Used can now tell a host whether the user has used any emoji, so a keyboard can keep offering suggestion-bar emoji after it starts again.

### Includes

- `EmojiFrequentlyUsed.hasUses` reports whether any emoji was used, and stays true through saving and reading the ranking back.

### Notes

- `1.0.1` adds to the public API without changing it, so keyboard hosts need no changes.

---

## [1.0.0] - 2026-10-15

Initial shared emoji catalog, search, and suggestions for KeyVox keyboards, matched against the measured behavior of the iOS system emoji keyboard.

### Includes

- Emoji catalog in the system emoji keyboard's categories and order, with each emoji's name and skin-tone versions, including the twenty-five versions of emoji of two people.
- Frequently Used ranking as the system keyboard ranks it, starting from the emoji it shows before any are used.
- Emoji search by the words that describe each emoji, whole words first, ordered by Unicode's ranking of how often emoji are used, with a searched word's suggestion-bar emoji first so the bar and the search agree.
- Emoji for the suggestion bar by word, written from the search data: the first three emoji a search finds for the word as a whole word, leaving out function words, with a plural taking its singular's when it has none of its own, and the emoji used most first.
- KeyVox's own emoji for words the data leaves out or gets wrong, used in place of the data's.
- Two-person skin tones by each person's tone.
- Data writers in `Tools/KeyVoxEmojiData` for the catalog, search, and suggestion bar data, from Unicode's emoji list, CLDR annotations, and KeyVox's word kinds.

### Notes

- `1.0.0` establishes the UI-independent emoji source of truth consumed by the KeyVox keyboard hosts; search words and suggestions are English only.
