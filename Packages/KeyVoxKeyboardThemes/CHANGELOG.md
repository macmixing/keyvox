# Changelog

All notable changes to `KeyVoxKeyboardThemes` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared keyboard theme data within the KeyVox monorepo.

---

## [2.0.0] - 2026-11-24

Swipe trail styles for each theme.

### Includes

- `KeyboardThemePalette.swipeTrail` (`KeyboardThemeSwipeTrail`): the trail a swipe leaves across the letter keys, with its stroke, head-dot, and glow colors and its width for the light and dark appearances, its nested glow layers, how long its tail lasts, how far it tapers, how its opacity falls off, and how far its bands overlap, the head dot's size, how long the tail retracts once the finger lifts and on what timing curve, and how the head dot grows and fades.
- The KeyVox theme draws it in indigo in light and lavender with a lighter head in dark; the Classic theme in the platform's system blue in light and white in dark.
- `KeyboardThemeSystemColor.blue`.

### Notes

- `2.0.0` changes public API: `KeyboardThemePalette`'s initializer takes the required `swipeTrail:`, and `KeyboardThemeSystemColor` gains `.blue`, so palettes built and exhaustive switches written for `1.0.0` need updating; key colors are unchanged.

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
