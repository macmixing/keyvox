# Changelog

All notable changes to `KeyVoxKeyboardThemes` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared keyboard theme data within the KeyVox monorepo.

---

## [1.0.0] - 2026-10-24

Initial shared keyboard themes for KeyVox keyboards.

### Includes

- KeyVox theme with KeyVox's lavender and indigo keys, used unless another theme is chosen.
- Classic theme with neutral keys that follow each platform's system keyboard.
- Key colors for letter, special, and toolbar keys, including their pressed and disabled states and outline.
- How strongly keys cover the keyboard backdrop, set separately for light and dark appearances.
- Colors for a toolbar key that is on, and for its symbol and title.
- Key popup colors for the fill, outline, characters, and the highlight under a held key's selected character.
- The cancel key's border and the microphone button's background.
- Theme colors given as explicit values or as a platform's system colors, separately for light and dark appearances.
- Palettes defined per platform, starting with iOS, so each theme can follow a platform's own look.
- Saved theme lookup that falls back to the KeyVox theme.
