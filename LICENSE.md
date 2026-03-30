# KeyVox License

## Source Code License (MIT)

Copyright (c) 2026 Dominic Esposito

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---
## Third-Party Components and Data

This repository includes third-party components and data that are **not**
licensed under this repository's MIT terms and remain under their original
licenses.

Notable third-party items include:

- `whisper.cpp` (MIT)
- OpenAI Whisper code/model weights (MIT)
- NVIDIA `parakeet-tdt-0.6b-v3` model artifacts downloaded by the app (CC BY 4.0), using Apple-platform Core ML artifacts distributed via FluidInference
- Pronunciation data derived from CMUdict (BSD-2-Clause style notice/disclaimer)
- Pronunciation data derived from SCOWL (custom permissive notice text)
- Kanit font (`OFL-1.1`)

For full third-party notices, see `THIRD_PARTY_NOTICES.md` and
`Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/LICENSES.md`.

---
## Excluded Proprietary Assets and Branding

The MIT License applies to all source code in this repository **except** for the files and assets explicitly listed below.

The following files and assets are **NOT licensed under the MIT License** and remain the exclusive property of Dominic Esposito. They may not be used, copied, modified, or redistributed in any commercial or public-facing project without explicit written permission.

### Excluded Files and Assets

1. `macOS/Resources/Assets.xcassets/`  
   `iOS/KeyVox iOS/Resources/Assets.xcassets`
   `iOS/KeyVox Widget/Assets.xcassets`
   `iOS/KeyVox iOS/Resources/ReturnToHost.mov`
   `iOS/LaunchLogo.png`
   Includes all App Icons, instructional assets, the KeyVox logo, and related brand imagery.

2. `macOS/Views/Components/LogoBarView.swift`  
   `iOS/KeyVox iOS/Views/Components/LogoBarView.swift`
   `iOS/KeyVox Keyboard/Views/Components/KeyboardLogoBarView.swift`
   The proprietary KeyVox logo system implementation, including the standalone logo treatment and the recording-overlay audio-reactive visual identity.

3. `macOS/Resources/keyvox.icon/`  
   `iOS/KeyVox iOS/Resources/keyvox.icon/`
   The proprietary app icon package and source imagery.

4. `macOS/Resources/logo.png`  
   The standalone KeyVox logo artwork used in repository branding.

These visual elements represent the unique brand identity of KeyVox and are reserved for current and future commercial use.

---

## Condition of Redistribution

You are free to use, study, modify, and commercially distribute the MIT-licensed source code in this repository.

However, if you fork or redistribute this project, you **must remove** all excluded proprietary assets listed above and replace them with your own original branding, including:

- A unique application name  
- A unique icon  
- A distinct visual identity  

Your fork may not use branding, visual elements, or design elements that could reasonably be confused with KeyVox.

---

## Trademark Notice

"KeyVox", its logos, and related brand elements are reserved.  
This license does not grant any rights to use the KeyVox name or marks in a manner that suggests affiliation, endorsement, or origin.
