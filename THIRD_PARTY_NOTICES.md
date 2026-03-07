# Third-Party Notices

This project is primarily licensed under MIT for source code (see `LICENSE.md`).
Third-party components, data, and fonts remain under their original licenses.

## Runtime Components

### whisper.cpp (binary XCFramework)
- Upstream: <https://github.com/ggml-org/whisper.cpp>
- License: MIT
- Note: bundled through `Packages/KeyVoxWhisper`

Copyright (c) The ggml authors

### OpenAI Whisper (code + model weights)
- Upstream: <https://github.com/openai/whisper>
- License: MIT
- Note: model artifacts are downloaded by the app at runtime

Copyright (c) 2022 OpenAI

### MIT License (applies to the two components above)

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

## Package-Owned Data Notices

Pronunciation-data notices for `KeyVoxCore` are bundled with the package resources:

- `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/LICENSES.md`
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/sources.lock.json`

## Bundled Font

### Kanit Font
- Upstream: <https://github.com/cadsondemak/kanit>
- License: SIL Open Font License 1.1 (OFL-1.1)
- Bundled file: `Resources/Kanit-Medium.ttf`

Full OFL text is bundled in `Resources/OFL.txt`.

## Build-Time Tooling (not shipped in app runtime)

### Phonetisaurus
- Upstream: <https://github.com/AdolfVonKleist/Phonetisaurus>
- License: BSD-3-Clause
- Use: maintainer-only lexicon generation path

### OpenFst
- Upstream: <https://www.openfst.org/>
- License: Apache-2.0
- Use: transitive build-time dependency for Phonetisaurus workflows
