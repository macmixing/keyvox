# Third-Party Notices

This project is primarily licensed under MIT for source code (see [our license](https://github.com/macmixing/keyvox/blob/main/LICENSE.md)).
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

### NVIDIA Parakeet TDT v3 (downloaded model artifacts)
- Upstream model: <https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3>
- Apple-platform Core ML distribution: <https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml>
- License: CC BY 4.0
- License URL: <https://creativecommons.org/licenses/by/4.0/>
- Note: KeyVox downloads Core ML artifacts derived from NVIDIA's `parakeet-tdt-0.6b-v3` multilingual ASR model. The Apple-platform Core ML artifact source used by KeyVox is distributed via FluidInference.

Attribution: Based on NVIDIA's `parakeet-tdt-0.6b-v3` multilingual automatic speech recognition model. The Apple-platform Core ML conversion and distribution source used by KeyVox is FluidInference.

### Kyutai PocketTTS (downloaded model artifacts)
- Upstream model: <https://huggingface.co/kyutai/pocket-tts>
- Apple-platform Core ML distribution: <https://huggingface.co/FluidInference/pocket-tts-coreml>
- License: CC BY 4.0
- License URL: <https://creativecommons.org/licenses/by/4.0/>
- Note: KeyVox downloads PocketTTS Core ML runtime artifacts, voice prompt assets, and the tokenizer model at runtime for copied-text playback. The Apple-platform Core ML artifact source used by KeyVox is distributed via FluidInference and inherits the upstream PocketTTS model licensing.

Attribution: Based on Kyutai's `pocket-tts` text-to-speech model. The Apple-platform Core ML conversion and distribution source used by KeyVox is FluidInference.

### MIT License (applies to `whisper.cpp` and OpenAI Whisper above)

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
- Bundled file: `Resources/Kanit-Medium.ttf`, `Resources/Kanit-Light.ttf`

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
