# Changelog

All notable changes to `KeyVoxKeyboardThemes` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared keyboard theme data within the KeyVox monorepo.

---

## [1.0.0] - 2026-10-24

Initial shared keyboard themes for KeyVox keyboards.

### Includes

- Default theme with KeyVox's lavender and indigo keys.
- Classic theme with neutral keys that follow each platform's system keyboard.
- Theme colors for letter, special, and toolbar keys, their pressed states, key popups and their outline, characters, and selected-character highlight, the symbol of a toolbar key that is on, and the cancel key's border, with how strongly keys cover the keyboard backdrop in each appearance.
- Palettes defined per platform, starting with iOS, so each theme can follow a platform's own look.
- Saved theme lookup that falls back to the default theme.
